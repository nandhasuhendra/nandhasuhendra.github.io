---
title: "Building a Modular Monolith in Rails Using Rails Engine and Dry-rb with Strict DDD"
description: "How I structured a production Rails app into isolated domain engines with Dry-rb dependency injection, typed entities, and Result monads without reaching for microservices."
date: 2026-06-11
last_modified_at: 2026-06-11
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

A few months ago, I was looking at a Rails app that had grown way beyond what a standard MVC structure could handle well. We had a booking system, a CRM, inventory management, payment processing, and multi-tenancy, all living in the same `app/models`, `app/services`, and `app/controllers` folders. Cross-domain dependencies were everywhere, and changing one thing would often break something else in an unexpected place.

The first idea that came to mind was "let's break this into microservices." But microservices come with a lot of extra work: distributed transactions, service discovery, network latency, and complex deployments. For our team size, that was not the right move yet.

The answer was a **Modular Monolith**. It is still one deployed application, but with clear domain boundaries that are enforced by Rails Engines and Dry-rb's dependency injection tools.

Here is what I learned while building it.

---

## What Is a Modular Monolith and Why Should You Care?

A Modular Monolith is a single deployable application where each business domain is kept separate from the others. You still get the simplicity of a monolith like one database, one deploy, and direct method calls. But you also get the discipline of microservices like explicit interfaces and no domain bleeding.

The real problem with a big monolith is not that it runs as one process. The problem is **coupling**. If you can enforce the same boundaries you would have across services, but inside one codebase, you get the benefits without any network overhead.

In Rails, **Rails Engines** are the right tool for this job. Each domain becomes an engine with its own models, controllers, routes, migrations, and business logic. The main app becomes a thin shell that just mounts all the engines.

---

## Mapping Out the Domains

The first step is deciding your domain boundaries based on business needs, not technical layers. In our app, we ended up with 13 domain engines:

```
domains/
├── core/            # Foundation: base classes, DI container, error handling
├── identity_access/ # Authentication, sessions, OTP
├── tenant/          # Multi-tenancy, staff management
├── crm/             # Customers
├── catalog/         # Products, inventory, stock
├── booking/         # Booking lifecycle
├── checkout/        # Payment processing
├── transaction/     # Invoices, expenses
├── report/          # Analytics
├── notification/    # Multi-channel messaging
├── subscription/    # Billing and trials
├── auditable/       # Audit trail
└── ui/              # Shared ViewComponent library
```

Each engine is a self-contained Ruby gem. It has a `gemspec`, its own `lib/` folder for business logic, an `app/` folder for Rails artifacts, its own migrations, and its own test suite.

The main app's `Gemfile` just loads all of them like this:

```ruby
gem "core",            path: "domains/core"
gem "identity_access", path: "domains/identity_access"
gem "crm",             path: "domains/crm"
gem "booking",         path: "domains/booking"
# ... and so on
```

And `config/routes.rb` mounts each engine under a namespace:

```ruby
Rails.application.routes.draw do
  namespace :app do
    mount IdentityAccess::Engine => "/auth"
    mount Crm::Engine            => "/crm"
    mount Booking::Engine        => "/bookings"
    mount Checkout::Engine       => "/checkout"
    # ...
  end
end
```

---

## Setting Up a Rails Engine

Each engine follows the same basic structure. Here is what the engine file looks like:

```ruby
# domains/booking/lib/booking/engine.rb
module Booking
  class Engine < ::Rails::Engine
    isolate_namespace Booking
  end
end
```

The `isolate_namespace` line is the most important part here. It prevents the engine's constants and routes from mixing with the main app's namespace.

Every engine also gets its own `ApplicationRecord` that adds a prefix to all table names:

```ruby
# domains/booking/app/models/booking/application_record.rb
module Booking
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "booking_"
  end
end
```

So `Booking::Appointment` maps to the `booking_appointments` table and `Crm::Customer` maps to `crm_customers`. This creates a clear schema boundary inside a shared database without needing a separate database for each domain.

---

## Where Dry-rb Comes In

Rails Engines give you structural separation, but you still need something to manage dependencies between classes inside a domain, enforce types, and handle errors in a consistent way. This is where **Dry-rb** helps a lot.

Here are the core gems we use:

- `dry-system` for dependency injection container with auto-loading
- `dry-auto_inject` to inject registered components by key
- `dry-struct` for typed and immutable value objects and entities
- `dry-validation` for input validation contracts
- `dry-monads` for `Success` and `Failure` result types

### Setting Up the Container

Each domain defines its own `Dry::System::Container`. Here is what the booking domain's container looks like:

```ruby
# domains/booking/lib/booking/container.rb
require "dry/system/container"

module Booking
  class Container < Dry::System::Container
    configure do |config|
      config.root = Pathname.new(__dir__).join("../../")

      config.component_dirs.add "lib" do |dir|
        dir.namespaces.add "booking", key: nil
        dir.add_to_load_path = true
      end

      config.component_dirs.add "app" do |dir|
        dir.namespaces.add "booking", key: nil
        dir.add_to_load_path = true
      end
    end

    # ActiveRecord models cannot be auto-resolved, so we register them manually
    register(:booking_appointment_model) { Booking::Appointment }
  end
end
```

Then we set up the injector:

```ruby
# domains/booking/lib/booking/injector.rb
require "dry/auto_inject"
require_relative "container"

module Booking
  Import = Dry::AutoInject(Container)
end
```

With this setup, any file placed under `lib/booking/services/create_booking_service.rb` is automatically registered as `"services.create_booking_service"` in the container. No manual wiring needed.

---

## The DDD Building Blocks

### Entities

Entities are **typed and immutable domain objects**. They never hold an ActiveRecord instance. The base class inherits from `Dry::Struct`:

```ruby
# domains/core/lib/core/entity.rb
module Core
  class Entity < Dry::Struct
    schema schema.strict(false)
    transform_keys(&:to_sym)
  end
end
```

Here is a real example from the CRM domain:

```ruby
# domains/crm/lib/crm/entities/customer_entity.rb
module Crm
  module Entities
    class CustomerEntity < Core::Entity
      attribute  :id,            Core::Types::Integer
      attribute  :tenant_id,     Core::Types::Integer
      attribute  :name,          Core::Types::String
      attribute? :email_address, Core::Types::String.optional
      attribute? :phone_code,    Core::Types::String.optional
      attribute? :phone_number,  Core::Types::String.optional
      attribute  :status,        Core::Types::String
      attribute? :created_at,    Core::Types::Timestamp
    end
  end
end
```

Attributes marked with `?` are optional. Everything else is required. If you try to build a `CustomerEntity` without a `name`, you get an error right at construction time, not later when you are trying to use it somewhere deep in your code. That early failure is exactly what you want.

One rule I follow strictly: **ActiveRecord objects never leave the repository layer**. Everything above that layer, like services, commands, queries, controllers, and views, only ever works with entities.

### Repositories

Repositories are the only layer that touches ActiveRecord. They inject the AR model, run the queries, and convert the records into entities:

```ruby
# domains/crm/lib/crm/repositories/customer_repository.rb
module Crm
  module Repositories
    class CustomerRepository < Core::Repository
      include Import[:crm_customer_model]

      def find(id:)
        record = crm_customer_model.find_by(id: id)
        return nil unless record
        to_entity(record)
      end

      def find_all_by_tenant(params)
        scope = crm_customer_model
          .where(tenant_id: params.tenant_id)
          .order(created_at: :desc)

        scope = scope.where("name ILIKE ?", "%#{params.search}%") if params.search.present?

        records = scope.limit(params.limit).offset(params.offset)
        records.map { |r| to_entity(r) }
      end

      private

      def to_entity(record)
        Entities::CustomerEntity.new(record.attributes)
      end
    end
  end
end
```

Two things worth noting here. First, `find` returns `nil` when a record is not found instead of raising `ActiveRecord::RecordNotFound`. Second, `to_entity` converts the AR record into an entity right at the boundary. Everything above this point only works with pure domain objects.

### Services and Commands

All business logic lives in `Services`, `Commands`, and `Queries`. They all inherit from a base `Operation` class that includes `Dry::Monads`:

```ruby
# domains/core/lib/core/operation.rb
module Core
  class Operation
    include Dry::Monads[:result, :do]

    def call(*)
      raise NotImplementedError
    end
  end
end
```

A service uses `yield` from the do notation for early exit when something fails, and wraps everything in a database transaction:

```ruby
# domains/booking/lib/booking/services/create_booking_service.rb
module Booking
  module Services
    class CreateBookingService < Core::Service
      include Import[
        "contracts.create_booking_contract",
        "repositories.booking_repository"
      ]

      class Param < Core::Params
        attribute? :tenant_id,    Core::Types::Any
        attribute? :customer_id,  Core::Types::Any
        attribute? :booking_date, Core::Types::Any
        attribute? :booking_time, Core::Types::Any
        attribute? :items,        Core::Types::Any
        attribute? :user_id,      Core::Types::Any.optional
      end

      def call(param:)
        ActiveRecord::Base.transaction do
          payload   = yield validate(param.to_h)
          snapshots = yield build_snapshots(payload)
          items     = yield prepare_items(payload)

          booking = booking_repository.create(payload, snapshots, items)

          publish_event(
            Constant::Event::CREATED,
            payload: { booking_id: booking.id },
            metadata: { tenant_id: payload[:tenant_id], actor_id: payload[:user_id] }
          )

          Success(booking)
        end
      rescue Dry::Monads::Do::Halt => e
        e.result
      rescue => e
        Core::Logger.error(self.class, "Booking creation failed", exception: e)
        Failure(Core::Error.new(domain: :booking, code: :creation_failed))
      end

      private

      def validate(params)
        result = create_booking_contract.call(params)
        return Success(result.to_h) if result.success?
        Failure(Core::Error.new(domain: :booking, code: :validation_failed, errors: result.error_symbols))
      end

      def build_snapshots(payload)
        customer = Crm::PublicApi.find_customer(id: payload[:customer_id])
        customer_data = JSON.parse(customer, symbolize_names: true)
        return Failure(Core::Error.new(domain: :booking, code: :customer_not_found)) if customer_data[:status] == "error"
        Success(customer: customer_data[:data])
      end
    end
  end
end
```

The `yield` pattern is the key piece. If `validate` returns a `Failure`, execution stops right there and the failure goes back to the caller. No more nested `if result.success?` blocks. The `rescue Dry::Monads::Do::Halt` at the bottom catches it cleanly when it exits the transaction block.

Every service returns either `Success(value)` or `Failure(Core::Error.new(...))`. The caller never has to rescue exceptions from business logic.

### Validation Contracts

Input validation is kept separate from business logic using `Dry::Validation::Contract`:

```ruby
# domains/booking/lib/booking/contracts/create_booking_contract.rb
module Booking
  module Contracts
    class CreateBookingContract < Core::Contract
      params do
        required(:tenant_id).filled(:integer)
        required(:customer_id).filled(:integer)
        required(:booking_date).filled(:string)
        required(:booking_time).filled(:string)
        required(:items).filled(:array)
      end

      rule(:booking_date) do
        key.failure(:invalid_format) unless Date.parse(value) rescue false
      end
    end
  end
end
```

Contracts always run before the service. If they fail, we build a `Core::Error` with field-level error codes and return early. The service never gets called.

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

---

What has your experience been with large Rails apps? Have you tried Engines before, or do you use a different approach to manage growth? I would love to hear about it in the comments.
