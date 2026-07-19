---
title: "Modular Monolith in Rails: Cross-Domain Communication and Lessons Learned (Part 2)"
description: "Part 2 of the modular monolith series: how isolated Rails Engine domains talk to each other through a PublicApi and an event bus, plus what I learned running this architecture in production."
date: 2026-06-12
last_modified_at: 2026-06-12
author: Nanda Suhendra
categories:
  - General
tags:
  - Ruby on Rails
  - Domain-Driven Design
  - Architecture
  - Dry-rb
cover_image:
canonical_url:
draft: false
---

This is part 2 of a two-part series on building a modular monolith in Rails. In [part 1]({% post_url 2026-06-11-modular-monolith-in-rails-rails-engine-dry-rb-and-ddd-in-practice %}), I covered how domains are structured as Rails Engines and the DDD building blocks like entities, repositories, services, and validation contracts. Here I cover how those isolated domains actually talk to each other, and what I learned running this in production.

---

## How Domains Talk to Each Other

This is the most important rule in the whole setup: **no domain can directly call another domain's repositories, services, or models**. All communication between domains goes through a `PublicApi` module that returns JSON strings.

Why JSON strings and not Ruby objects? Because a JSON string is just data. If you return a Ruby object, you are still sharing behavior across the domain boundary. The other domain can call methods on it and it brings its own dependencies along. A JSON string forces a clean cut.

```ruby
# domains/crm/lib/crm/public_api.rb
module Crm
  module PublicApi
    def self.find_customer(id:)
      repo = Crm::Container["repositories.customer_repository"]
      customer = repo.find(id: id.to_i)
      return { status: "error", code: "customer_not_found" }.to_json unless customer
      { status: "success", data: customer.to_h }.to_json
    end
  end
end
```

And here is how the booking domain calls it:

```ruby
raw = ::Crm::PublicApi.find_customer(id: payload[:customer_id])
response = JSON.parse(raw, symbolize_names: true)

if response[:status] == "error"
  yield Failure(Core::Error.new(domain: :booking, code: response[:code].to_sym))
end

customer_snapshot = response[:data]
```

Yes, this looks more verbose than a direct method call. But there is a big benefit here. If you ever need to extract the CRM into its own service, you only need to change the `PublicApi` implementation. The calling code in the booking domain does not change at all.

---

## Events for Async Cross-Domain Work

For reactions that do not need to happen immediately, we use an in-process event bus. Services publish events at the end of a successful operation, and listeners in other domains react to them.

Each domain defines its event constants with a clear naming pattern:

```ruby
# domains/booking/lib/booking/constant.rb
module Booking
  module Constant
    module Event
      CREATED   = "booking.booking.created"
      UPDATED   = "booking.booking.updated"
      COMPLETED = "booking.booking.completed"
    end
  end
end
```

Events and their listeners are wired up in a Rails initializer:

```ruby
# config/initializers/event_bus.rb
Rails.application.config.after_initialize do
  adapter = Core::Events::Adapters::InProcessAdapter.new
  Core::Events::EventBus.configure(adapter: adapter)

  [
    Booking::Constant::Event::CREATED,
    Booking::Constant::Event::COMPLETED,
    Checkout::Constant::Event::PAYMENT_SUCCESS,
  ].each { |evt| Core::Events::EventBus.register_event(evt) }

  Core::Events::EventBus.subscribe(Transaction::Listeners::BookingCompletedListener.new)
  Core::Events::EventBus.subscribe(Auditable::Listeners::BookingListener.new)
  Core::Events::EventBus.subscribe(Notification::Listeners::BookingCreatedListener.new)
end
```

A listener in the `transaction` domain can react to a booking completion event without knowing anything about the booking domain's internals:

```ruby
# domains/transaction/lib/transaction/listeners/booking_completed_listener.rb
module Transaction
  module Listeners
    class BookingCompletedListener < Core::Events::BaseListener
      def on_booking_booking_completed(event)
        handle_event(event, ::Booking::Constant::Event::COMPLETED) do
          param = Services::CreateInvoiceService::Param.new(
            booking_id:   payload[:booking_id],
            total_amount: payload[:total_amount],
            tenant_id:    data.metadata[:tenant_id]
          )
          Transaction::Container["services.create_invoice_service"].call(param: param)
        end
      end
    end
  end
end
```

The method name follows a convention: `on_{domain}_{aggregate}_{action}`. This maps directly to the event name string like `"booking.booking.completed"`, so the event bus can find the right handler automatically.

---

## The Full Data Flow

Here is what actually happens when a booking is created, going through all the layers:

```
Controller receives params
  |
  v
CreateBookingContract validates shape and types
  |
  v
CreateBookingService#call(param:) runs the operation
  |-- yield validate(params)         -> Success or Failure, exit early if failed
  |-- yield build_snapshots(payload) -> calls Crm::PublicApi (JSON)
  |-- yield prepare_items(payload)   -> calls Catalog::PublicApi (JSON)
  |-- booking_repository.create(...) -> writes to DB, returns BookingEntity
  |-- publish_event(CREATED, ...)   -> async listeners react
  |
  v
Success(BookingEntity) returned to controller
  |
  v
BookingPresenter formats for the view
  |
  v
View renders
```

No ActiveRecord objects escape the repository. No domain knows about another domain's internals. Errors always travel as typed `Core::Error` values, not as raw exceptions.

---

## Dependency Injection in Controllers

The controller layer gets its dependencies from the container through a custom `inject` helper:

```ruby
# domains/booking/app/controllers/booking/appointments_controller.rb
module Booking
  class AppointmentsController < ApplicationController
    inject :create_booking_service,
           :create_booking_contract,
           container: Booking::Container

    def create
      validation = create_booking_contract.(booking_params.to_h)
      unless validation.success?
        error = Core::Error.new(domain: :booking, code: :validation_failed, errors: validation.error_symbols)
        render_error(error) and return
      end

      param = Services::CreateBookingService::Param.new(**validation.to_h)
      result = create_booking_service.(param: param)

      if result.success?
        redirect_to booking_path(result.value!.id)
      else
        render_error(result.failure)
      end
    end
  end
end
```

The `inject` helper resolves the key convention automatically. So `:create_booking_service` becomes `"services.create_booking_service"` in the container lookup. This also makes the controller easy to test because you can swap the container in your test setup.

---

## Things I Would Do Differently

After running this in production for a while, here are a few things I have learned:

**The PublicApi JSON round-trip adds overhead.** For calls that happen very often, parsing JSON on every request can add up. You can reduce this by caching parsed responses or using a Ruby object interface for those specific high-frequency calls, as long as you keep a clear internal convention around it.

**Auto-loading order is more important than you think.** With 13 engines and `Dry::System` auto-registration, you will eventually run into circular dependency issues. The fix is to be explicit about which components need manual registration in the container.

**Keep the `core` domain lean.** It is very tempting to put shared-ish logic into `core`. Try to resist that. The `core` domain should only hold abstract base classes and infrastructure code, never business logic. If two domains need the same business concept, that concept probably deserves its own domain.

**Testing gets much faster.** Each domain's spec suite can run on its own. You can test the booking domain without starting up the checkout domain at all. This keeps your feedback loops short as the app grows.

---

## Is This Worth the Effort?

Honestly, it depends. If you have a simple CRUD app with a handful of models, this setup is overkill and will just slow you down.

But if you are building something where different parts of the business have their own rules, their own teams, and their own pace of change, then yes, the investment in clear domain boundaries pays off quickly. You stop spending time wondering where a piece of code should live and start thinking about what each domain actually needs.

Using Rails Engines for structure, Dry-rb for typed boundaries and explicit dependencies, and Monads for predictable error handling gives you a codebase where you can focus on one domain at a time without worrying about what you might accidentally break somewhere else. That is a real win when things get complex.

Domain boundaries are only half of it, though. The same app also has to serve a public marketing site, a staff admin panel, and the actual customer workspace without any of those bleeding into each other. I cover that split in [One Rails Backend, Three Apps]({% post_url 2026-07-19-splitting-web-admin-and-internal-apps-in-one-rails-backend %}).

---

What has your experience been with large Rails apps? Have you tried Engines before, or do you use a different approach to manage growth? I would love to hear about it in the comments.
