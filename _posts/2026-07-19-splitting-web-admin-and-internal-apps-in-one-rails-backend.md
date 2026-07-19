---
title: "One Rails Backend, Three Apps: Splitting Web, Admin, and Internal with Rails Engines"
description: "How a single Rails app serves a public marketing site, an internal admin panel, and the actual product workspace without any of them stepping on each other, using isolated Rails Engines per surface and one shared backend engine underneath."
date: 2026-07-19
last_modified_at: 2026-07-19
author: Nanda Suhendra
categories:
  - General
tags:
  - Ruby on Rails
  - Architecture
  - Rails Engine
  - Dry-rb
cover_image:
canonical_url:
draft: false
---

In my [modular monolith series]({% post_url 2026-06-11-modular-monolith-in-rails-rails-engine-dry-rb-and-ddd-in-practice %}), I wrote about splitting a Rails app into domain engines like booking, CRM, and checkout. That solved coupling between business domains. But there is a second kind of coupling that shows up just as often, and it is not about domains at all: it is about **surfaces**.

A typical product needs a public marketing site, an internal admin panel for staff, an actual workspace for customers, and often a JSON API for mobile or integrations. These four things have almost nothing in common. The marketing site is public and SEO-heavy. The admin panel is staff-only. The workspace requires a signed-in user and an active tenant. The API returns JSON and does not render a single view. If you build all of this inside one `app/controllers` and `app/views`, you end up with layouts fighting each other, one bloated JavaScript bundle shipped to every page, and authentication checks scattered as ad-hoc `before_action` calls that are easy to get wrong.

The fix is the same tool as before, Rails Engines, just applied to a different axis: one engine per surface, plus one shared engine that holds all the business logic underneath.

---

## One Backend Engine, Four Presentation Engines

The app is split into five engines:

```
engines/
├── backend/  # Shared domain and business logic (models, operations, jobs)
├── web/      # Public marketing site
├── admin/    # Staff-only admin panel
├── internal/ # The actual product workspace, used by customers
└── api/      # JSON API
```

`backend` is the same kind of domain engine I covered in the modular monolith series: models, `Dry::Struct` entities, repositories, and operations built on `dry-monads`. The other four are presentation engines. None of them define a model or touch the database directly. Their entire job is routing, controllers, views, and talking to `backend`.

`config/routes.rb` mounts all five, with a comment about how this changes in production:

```ruby
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"

  # In production, route by subdomain instead of path prefix:
  #
  #   constraints subdomain: "admin" do
  #     mount Admin::Engine, at: "/"
  #   end
  #
  # For local development all engines share localhost via path-based mounting.

  mount Admin::Engine,      at: "/admin",      as: :admin_engine
  mount Internal::Engine,   at: "/workspace",  as: :internal_engine
  mount Api::Engine,        at: "/api",        as: :api_engine

  # Web engine last, public-facing root (landing pages, marketing).
  mount Web::Engine, at: "/", as: :web_engine
end
```

Locally, path prefixes are enough to keep things separate and let every engine share one `localhost:3000` during development. In production the plan is to swap to subdomain constraints (`admin.example.com`, `app.example.com`) so each surface gets a clean URL, without touching a single controller.

Each engine still calls `isolate_namespace` so its routes, controllers, and helpers do not leak into anyone else's:

```ruby
# engines/admin/lib/admin/engine.rb
module Admin
  class Engine < ::Rails::Engine
    isolate_namespace Admin

    config.autoload_paths += %W[#{root}/app/components]
  end
end
```

`web`, `internal`, and `admin` all follow this exact shape. `api` is even simpler since it has no view components to autoload. `backend` is the odd one out, it registers `app/domain`, `app/operations`, `app/infrastructure`, and `app/jobs` as extra autoload paths, and wires up the dry-rb container and event subscribers on boot. It is the only engine that is not a "presentation surface," so it earns the extra setup.

---

## Each Engine Gets Its Own Front Door

Because each engine is isolated, each one gets its own `ApplicationController` with its own layout and its own rules. This is where the surfaces actually stop being able to interfere with each other.

The public web engine is fully open:

```ruby
module Web
  class ApplicationController < ActionController::Base
    layout "web/application"

    protect_from_forgery with: :exception

    # Marketing pages are fully public, but the same session cookie is shared
    # with the internal engine, which lets the primary CTA switch to "Open App"
    # for a visitor who's already signed in, without requiring auth here.
    include Backend::Authentication

    before_action :set_locale
  end
end
```

The admin panel requires an authenticated staff account:

```ruby
module Admin
  class ApplicationController < ActionController::Base
    layout "admin/application"

    protect_from_forgery with: :exception

    include Backend::Authentication

    before_action :set_locale
    before_action :require_authentication
    before_action :require_admin

    private

    def require_admin
      return if current_user&.is_admin?

      redirect_to "/", alert: I18n.t("admin.errors.not_authorized")
    end
  end
end
```

The internal workspace, the one customers actually use every day, needs the most rules: an authenticated user, an active tenant, and a check that blocks writes if the tenant's subscription is suspended:

```ruby
module Internal
  class ApplicationController < ActionController::Base
    layout "internal/application"

    protect_from_forgery with: :exception

    include Backend::Authentication
    include Backend::TenantScope
    include Internal::HandlesOperationErrors

    before_action :set_locale
    before_action :require_authentication
    before_action :require_tenant
    before_action :set_subscription_banner
    before_action :block_mutations_for_suspended_tenant

    private

    # Suspended tenants keep read access to every page but can't create,
    # update, or delete anything, resolving the suspension is an admin
    # action, not something they can self-serve their way out of.
    def block_mutations_for_suspended_tenant
      return if request.get? || request.head?
      return unless tenant_selected?
      return unless current_tenant.status == Backend::Tenants::Constants::STATUSES[:suspended]

      redirect_back fallback_location: root_path, alert: t("internal.subscription_banner.suspended.action_blocked")
    end
  end
end
```

And the API engine does not render HTML at all, so it inherits from `ActionController::API` instead and only ever returns JSON errors:

```ruby
module Api
  class ApplicationController < ActionController::API
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: :render_bad_request

    private

    def render_error(message, status:)
      render json: { error: { message: message } }, status: status
    end
  end
end
```

Four `ApplicationController` classes, four completely different sets of rules, and none of them can accidentally affect another because they live in different isolated engines.

---

## One Shared Login, Enforced Differently Per Surface

Since this is still one Rails app under the hood, all four engines share the same session cookie. That is exactly what makes the "already signed in" CTA on the marketing site possible without any cross-app token exchange. What is shared is the session mechanics, not the access rules.

`Backend::Authentication` is a controller concern that lives in the `backend` engine and gets included wherever it is needed:

```ruby
module Backend
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :set_current_user
      helper_method :current_user, :user_signed_in?
    end

    private

    def current_user
      Backend::Current.user
    end

    def require_authentication
      return if user_signed_in?

      session[:return_to_after_sign_in] = request.url
      redirect_to unauthenticated_redirect_path, alert: I18n.t("auth.sign_in_required")
    end

    # Override in each engine's ApplicationController to point at the correct sign-in route.
    def unauthenticated_redirect_path
      sign_in_path
    end

    def set_current_user
      return unless session[:user_id]

      result = Backend::Container["identity_access.users_repository"].find(session[:user_id])
      Backend::Current.user = result.value_or(nil)
    end
  end
end
```

`require_authentication` is the same method everywhere, but `unauthenticated_redirect_path` is overridden per engine. Web does not need it at all, since nothing there requires a login. Admin redirects unauthorized staff back to the marketing home page. Internal redirects to its own sign-in screen and remembers where the visitor was headed. One concern, one behavior, four different outcomes depending on which engine calls it.

Tenant scoping works the same way, as a separate concern (`Backend::TenantScope`) that only the `internal` engine includes, since only the workspace has the concept of "which tenant am I currently acting as." Admin and web never need to know a tenant exists.

---

## Assets Do Not Leak Either

The other place surfaces used to bleed into each other was the asset bundle. Before this split, every page shipped the CSS and JS for every feature, whether it needed it or not. Now each presentation engine owns its own Tailwind build and its own JS entry point:

```json
"scripts": {
  "build": "esbuild app/javascript/*.* engines/internal/app/javascript/internal.js engines/admin/app/javascript/admin.js engines/web/app/javascript/web.js --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets --entry-names=[name]",
  "build:css:web":      "tailwindcss -i ./engines/web/app/assets/stylesheets/web.tailwind.css -o ./app/assets/builds/web.css --minify",
  "build:css:internal": "tailwindcss -i ./engines/internal/app/assets/stylesheets/internal.tailwind.css -o ./app/assets/builds/internal.css --minify",
  "build:css:admin":    "tailwindcss -i ./engines/admin/app/assets/stylesheets/admin.tailwind.css -o ./app/assets/builds/admin.css --minify"
}
```

`Procfile.dev` runs a separate Tailwind watcher per surface during development, so a change to the workspace's stylesheet never triggers a rebuild of the marketing site's CSS:

```
css.web:      yarn tailwindcss -i ./engines/web/app/assets/stylesheets/web.tailwind.css -o ./app/assets/builds/web.css --watch
css.internal: yarn tailwindcss -i ./engines/internal/app/assets/stylesheets/internal.tailwind.css -o ./app/assets/builds/internal.css --watch
css.admin:    yarn tailwindcss -i ./engines/admin/app/assets/stylesheets/admin.tailwind.css -o ./app/assets/builds/admin.css --watch
```

Each engine's layout then only loads its own bundle:

```erb
<%# engines/admin/app/views/layouts/admin/application.html.erb %>
<%= stylesheet_link_tag "admin", "data-turbo-track": "reload" %>
<%= javascript_include_tag "admin", "data-turbo-track": "reload", type: "module" %>
```

The API engine loads none of this, since it never renders a layout in the first place. A visitor on the marketing site never downloads the workspace's chart library, and a customer in the workspace never downloads the marketing site's SEO scripts.

---

## Presentation Engines Never Touch the Database Directly

This is the rule that makes the whole thing hold together: none of `web`, `admin`, `internal`, or `api` define a model, and none of them run a query directly against ActiveRecord. Every read and write goes through `backend`, either through its dependency injection container for simple lookups, or through an operation object for anything that is actually a business action.

Here is what that looks like in a real controller, recording an expense in the internal workspace:

```ruby
module Internal
  class ExpensesController < ApplicationController
    def create
      result = Backend::Transaction::RecordExpenseOperation::Service.call(
        {
          tenant_id:    current_tenant.id,
          category:     params[:category].presence,
          total_amount: params[:total_amount].presence,
          incurred_at:  params[:incurred_at].presence,
          vendor_name:  params[:vendor_name].presence,
          description:  params[:description].presence
        }.compact
      )

      if result.success?
        redirect_to expense_path(result.value!), notice: t("internal.expenses.create.success")
      else
        extract_errors(result)
        render :new, status: :unprocessable_entity
      end
    end
  end
end
```

The controller never sees an `Expense` model. It builds a plain hash, hands it to `Backend::Transaction::RecordExpenseOperation::Service`, and gets back a `dry-monads` `Success` or `Failure`. Simpler read-only lookups go through the same container, just without the operation wrapper:

```ruby
Backend::Container["catalog.services_repository"].all_categories_for_tenant(current_tenant.id).value_or([])
```

If the admin panel ever needs to record an expense too, it calls the exact same operation. There is no second copy of that business rule sitting inside the admin engine, waiting to drift out of sync with the one in internal.

---

## What This Buys Me

**Adding a new surface is cheap.** If I need a partner portal next, it is a new engine mounted at its own path, its own `ApplicationController` with whatever auth rules it needs, and its own asset bundle. Zero business logic gets duplicated, because all of it already lives in `backend`.

**Each surface can evolve its dependencies independently.** The workspace can pull in a charting library and a date-range picker without the marketing site's bundle getting a single byte heavier.

**Auth mistakes stay contained.** A missing `before_action` in one engine cannot expose a route in another, because the engines are not aware of each other's controllers at all.

**Tests run fast and stay honest.** Each engine's request specs boot only that engine's routes and controllers. A spec for the admin panel cannot accidentally pass because some unrelated internal-workspace helper leaked into scope.

The combination of the two splits, domain engines inside `backend`, presentation engines around it, is really one idea applied twice: draw the boundary where the coupling actually is, and let the framework enforce it instead of trusting everyone to remember it by convention.
