---
title: "Data-Driven Storefront Themes in Rails: JSON, ViewComponent, and Per-Tenant Configuration"
description: "How I manage configurable multi-tenant storefront themes in Rails using JSON theme blueprints, tenant-scoped JSONB, ViewComponent, a component registry, and a safe content editor."
date: 2026-07-24
last_modified_at: 2026-08-25
author: Nanda Suhendra
categories:
  - Architecture
tags:
  - Ruby on Rails
  - ViewComponent
  - Architecture
  - Themes
  - Multi-Tenancy
cover_image:
canonical_url:
draft: false
---

If you are building a SaaS platform that gives every customer a public storefront, theme management becomes more complicated than changing a few colors.

Customers may want different typography, layouts, section ordering, hero content, buttons, catalog previews, booking flows, and other presentation details. In a multi-tenant application, they also need to customize their own storefront without affecting another tenant.

The first solution that usually comes to mind in Rails is separate templates:

```text
app/views/storefront/themes/minimal/home.html.erb
app/views/storefront/themes/modern/home.html.erb
app/views/storefront/themes/classic/home.html.erb
```

That works for a small number of themes, but it does not scale well. Every new storefront feature can require changes across several theme-specific views and partials.

In Mebook, I ended up with a different model: **themes are mostly data, while Rails components own the rendering behavior**.

The current architecture looks roughly like this:

```text
Theme JSON files
      |
      v
Theme Catalog
      |
      v
Tenant theme records (JSONB)
      |
      v
RequestContext resolves active theme
      |
      v
Theme -> templates -> sections -> blocks
      |
      v
Component Registry
      |
      v
ViewComponent
      |
      v
Storefront HTML
```

There is also a second path for customization:

```text
Tenant theme JSONB
      |
      v
Internal content editor
      |
      v
Validated content-only patch
      |
      v
Live preview / persisted customization
```

This gives me multiple themes, tenant-specific configuration, reusable rendering code, and a safer editing model without allowing tenants to write ERB or arbitrary HTML.

---

## Why I Did Not Use Rails Variants

Rails already has request variants, which are useful when the same action needs a different template for a device or another small presentation difference:

```ruby
request.variant = :phone
```

Rails can then resolve something such as:

```text
show.html+phone.erb
```

I could technically use the same mechanism for storefront themes:

```ruby
request.variant = current_tenant.theme_name.to_sym
```

But that would make the number of templates grow with the number of themes.

For a storefront, the problem is larger than selecting one different view. A theme can affect:

- global colors and typography
- header and footer behavior
- page structure
- section ordering
- component variants
- editable content
- nested calls to action
- catalog and booking sections

Variants would move theme selection into Rails template lookup, but they would not solve the configuration problem. I wanted the structure of a theme to be inspectable and editable as data.

---

## 1. Theme Files Are Blueprints

The base themes live as JSON files. In Mebook, the catalog currently contains definitions such as `essential`, `neo-studio`, and `timeless`.

A simplified theme looks like this:

```json
{
  "id": "essential",
  "name": "Essential",
  "version": "1.0.0",
  "enable": true,
  "default": true,
  "settings": {
    "colors": {
      "primary": "#1A1A1A",
      "background": "#F7F7F6",
      "surface": "#FFFFFF",
      "foreground": "#1A1A1A"
    },
    "typography": {
      "body": {
        "family": "Plus Jakarta Sans",
        "fallback": "sans-serif"
      }
    }
  },
  "template_order": [
    "home",
    "catalog",
    "about",
    "contact",
    "cart",
    "booking"
  ],
  "templates": {
    "home": {
      "seo": {
        "title": "Home"
      },
      "sections": [
        {
          "id": "hero",
          "type": "hero",
          "content": {
            "eyebrow": "Your Sanctuary",
            "heading": "Sanctuary for refined care.",
            "text": "Thoughtful services and products designed around your everyday wellbeing."
          },
          "settings": {
            "variant": "centered",
            "show_location": true
          },
          "blocks": [
            {
              "id": "booking-action",
              "type": "button",
              "content": {
                "label": "Reserve Session"
              },
              "settings": {
                "variant": "outline",
                "action": "booking"
              },
              "blocks": []
            }
          ]
        }
      ]
    }
  }
}
```

The important distinction is between three kinds of data:

- `content` contains tenant-facing copy such as headings, labels, and text.
- `settings` controls behavior and presentation such as a variant, color scheme, or whether a field is visible.
- `blocks` allows sections to contain smaller nested pieces such as buttons or statistics.

The JSON describes **what should be rendered**, not the Ruby implementation that renders it.

---

## 2. Converting JSON Into a Theme Object

Passing plain nested hashes everywhere quickly becomes noisy:

```ruby
theme.dig("templates", "home", "sections")
```

So the theme loader converts nested hashes into a small `Theme` object based on `ActiveSupport::HashWithIndifferentAccess`.

Conceptually, it works like this:

```ruby
class Theme < ActiveSupport::HashWithIndifferentAccess
  def self.construct_from(value)
    case value
    when Hash
      new(value)
    when Array
      value.map { |item| construct_from(item) }
    else
      value
    end
  end

  def []=(key, value)
    super(key, self.class.construct_from(value))
  end
end
```

Because nested hashes are recursively converted, the rest of the storefront can work with objects such as:

```ruby
theme.settings
theme.templates.home.sections
section.content
section.settings
section.blocks
```

The loader also caches file-based theme definitions using the file modification time in the cache key:

```ruby
mtime     = File.mtime(file_path).to_i
cache_key = "storefront/themes/#{@theme_name}/#{mtime}"

raw_json = Rails.cache.fetch(cache_key, expires_in: @config.cache_expires_in) do
  JSON.parse(File.read(file_path))
end
```

This makes the JSON files useful as application-level theme blueprints while keeping access cheap.

---

## 3. The Catalog Is Not the Tenant's Theme State

This is one of the biggest changes from my original design.

I do not render every tenant directly from the JSON file on disk. The JSON files are the **theme catalog**, but each tenant gets its own stored copy.

The table is roughly:

```ruby
create_table :settings_storefront_themes, id: :uuid do |t|
  t.references :tenant, null: false, type: :uuid
  t.string :theme_id, null: false
  t.jsonb :data, null: false, default: {}
  t.boolean :enable, null: false, default: false
  t.boolean :active, null: false, default: false
  t.datetime :deleted_at
  t.timestamps
end
```

There is also a partial unique index that ensures a tenant can have only one active non-deleted theme.

When themes are initialized for a tenant, the repository reads the catalog and creates tenant-scoped records:

```ruby
catalog.each do |theme_id, data|
  theme = model.for_tenant(tenant_id).find_or_initialize_by(theme_id: theme_id)

  if theme.new_record?
    theme.data   = data
    theme.enable = data.fetch("enable", false)
    theme.active = theme_id == default_id && theme.enable?
  end

  theme.save!
end
```

This separation is important:

```text
JSON file              = product-level theme blueprint
settings_storefront_themes.data = tenant-level theme state
```

A tenant can customize its stored JSON without changing the original theme or another tenant's storefront.

There is also an architectural consequence worth calling out: once a tenant theme has been seeded, changing the catalog JSON does not automatically overwrite that tenant's stored copy. That protects tenant customization, but it means theme schema changes need an explicit migration or versioning strategy.

That trade-off is much safer than silently replacing customized production data.

---

## 4. Enabling and Activating Themes Are Separate Concepts

A theme can exist in the catalog without being available to tenants yet.

For example:

```json
{
  "id": "neo-studio",
  "enable": false,
  "default": false
}
```

The stored theme keeps both `enable` and `active` flags.

This lets the system distinguish:

```text
exists in catalog
    !=
available for selection
    !=
currently active for this tenant
```

Activating a theme is handled transactionally:

```ruby
model.transaction do
  theme = model.for_tenant(tenant_id).find_by!(theme_id: theme_id)
  raise ArgumentError, "theme is disabled" unless theme.enable?

  model.for_tenant(tenant_id).update_all(active: false)
  theme.update!(active: true)
end
```

I also keep a database constraint around the one-active-theme rule instead of trusting application code alone.

---

## 5. Resolving the Theme Once Per Request

The storefront should not repeatedly ask controllers and views which theme is active.

I use a `RequestContext` service that resolves the tenant, storefront settings, active theme name, and active theme configuration together:

```ruby
Context.new(
  tenant: tenant,
  storefront_settings: storefront_settings(tenant.id),
  theme_name: theme_name(tenant.id),
  theme_config: theme_config(tenant.id)
)
```

The important part is the active theme lookup:

```ruby
def theme_record(tenant_id)
  @theme_record ||= themes_repository.active_for(tenant_id).value_or(nil)
end

def theme_config(tenant_id)
  record = theme_record(tenant_id)
  return record.config if record

  Backend::Storefront::Themes::Loader.for(theme_name(tenant_id))
end
```

If the tenant has an active stored theme, the storefront renders that tenant-specific configuration. Otherwise it falls back to the default file-based theme.

The controller concern then exposes a stable interface to views:

```ruby
def theme_page_sections
  theme_page_settings[:sections] || []
end
```

The rest of the storefront does not need to know whether the configuration came from PostgreSQL or a JSON file.

---

## 6. Sections Are Mapped to ViewComponents

JSON should never contain Ruby class names.

Instead, I keep a registry from a stable public section type to a component class:

```ruby
Backend::Storefront::Themes.configure do |config|
  config.register "hero", Storefront::Sections::HeroComponent
  config.register "button", Storefront::Sections::ButtonComponent
  config.register "product_preview", Storefront::Sections::ProductPreviewComponent
  config.register "service_preview", Storefront::Sections::ServicePreviewComponent
  config.register "tenant_profile", Storefront::Sections::TenantProfileComponent
end
```

The renderer resolves the JSON type through that registry:

```ruby
component_class = Backend::Storefront::Themes::Registry.resolve(section.type)

component_class.new(
  section: section,
  render_context: storefront_render_context
)
```

This boundary is useful for a few reasons.

First, JSON remains data. It cannot instantiate an arbitrary Ruby class.

Second, the allowed section vocabulary is explicit. If I introduce a new section type such as `testimonials`, I intentionally create and register a `TestimonialsComponent`.

Third, multiple themes can reuse the same component with different data, variants, ordering, and styling.

A component can stay focused on behavior:

```ruby
class HeroComponent < ApplicationComponent
  def heading
    content["heading"]
  end

  def text
    content["text"]
  end

  def actions
    blocks.select { |block| block.type == "button" }
  end
end
```

The JSON decides which hero configuration is used. The component decides how a hero behaves and renders.

---

## 7. The Page Views Become Generic

With this setup, the page view does not know which theme is active.

The current home view is essentially:

```erb
<%= render partial: "storefront/shared/section_block",
           locals: { sections: theme_page_sections } %>
```

The shared renderer loops through whatever sections the active theme defines:

```erb
<% sections.each do |section| %>
  <%= render storefront_section_component(section,
        services: @services,
        products: @products,
        service_entries: @service_entries,
        product_entries: @product_entries,
        estimated_total: @estimated_total,
        page_context: @page_context) %>
<% end %>
```

This is the part that removes most theme-specific ERB duplication.

A theme can change the ordering from:

```text
hero -> tenant profile -> service preview -> product preview
```

to:

```text
hero -> product preview -> service preview -> contact
```

without creating another `index.html.erb`.

---

## 8. Theme Tokens Drive the Shared Layout

The theme does more than choose page sections.

Global settings are converted into CSS variables in the shared storefront layout:

```erb
<style>
  :root {
    --theme-primary: <%= theme_layout_color("primary", "#1A1A1A") %>;
    --theme-bg: <%= theme_layout_color("background", "#F7F7F6") %>;
    --theme-surface: <%= theme_layout_surface_color %>;
    --theme-text: <%= theme_layout_color("foreground", "#1A1A1A") %>;
    --theme-font-sans: <%= theme_layout_body_font %>;
    --theme-radius: <%= theme_layout_radius %>;
  }
</style>
```

The body is also scoped by theme:

```erb
<body class="theme--<%= theme_layout_scope %>">
```

and the layout can load a theme stylesheet:

```erb
<%= stylesheet_link_tag "storefront/themes/#{theme_layout_stylesheet_name}" %>
```

This gives me two levels of theming:

1. **Data-driven tokens** for values such as colors, fonts, shape, and component settings.
2. **Theme-scoped CSS** when a design needs stronger visual differences that cannot be expressed cleanly as tokens alone.

This is an important correction to the simplistic idea that "adding a theme requires no code at all".

If a new theme only changes existing tokens, sections, content, and supported variants, it can be mostly JSON. If it needs a completely new visual treatment, I may add theme-specific CSS. If it introduces a new semantic section type, I add a new ViewComponent and registry entry.

The goal is not zero code. The goal is **keeping theme-specific code small and keeping business behavior reusable**.

---

## 9. The Same JSON Schema Generates the Content Editor

Making themes configurable is where this design becomes especially useful.

The internal storefront editor does not maintain a separate hard-coded form for every theme. It walks through the selected theme's sections and nested blocks.

For a node, editable fields are derived from its `content` object:

```ruby
content_fields = node.fetch("content", {}).reject do |key, _value|
  key.to_s.end_with?("_source")
end
```

The form names include the stable node ID:

```erb
<% field_name = "content[nodes][#{node["id"]}][#{field}]" %>
```

So a submitted payload can look like:

```ruby
{
  "nodes" => {
    "hero" => {
      "heading" => "A better way to book",
      "text" => "Choose your service and preferred schedule."
    },
    "booking-action" => {
      "label" => "Book now"
    }
  }
}
```

Because each node has a stable ID, the editor does not need to depend on array positions.

Nested blocks are handled recursively, so the same editor can work with a hero containing buttons, statistics, or other nested content.

---

## 10. Tenant Customization Is Intentionally Limited

I do not trust the browser to send back an entire theme JSON document.

The update operation starts from the stored theme structure and only replaces keys that are already declared as editable content:

```ruby
def update_nodes(nodes, submitted_nodes)
  Array(nodes).map do |node|
    updated = node.deep_dup
    submitted = submitted_nodes.fetch(node["id"].to_s, {})

    editable_keys = node
      .fetch("content", {})
      .keys
      .reject { |key| key.to_s.end_with?("_source") }

    content = submitted
      .slice(*editable_keys)
      .transform_values(&:to_s)

    updated["content"] = node.fetch("content", {}).merge(content)
    updated["blocks"] = update_nodes(node["blocks"], submitted_nodes)
    updated
  end
end
```

That means a tenant can change something like:

```text
hero.heading
```

but cannot inject an arbitrary field to change:

```text
hero.type
hero.settings.variant
hero.settings.action
some_internal_source
```

unless the application explicitly exposes that configuration later.

This is a much better boundary than accepting raw theme JSON from the UI.

The theme configuration is flexible, but the application still controls the schema and rendering capabilities.

---

## 11. Preview Draft Changes Without Saving Them

The content editor also supports a theme preview endpoint.

The preview controller copies the requested tenant theme into memory:

```ruby
@theme_config = Backend::Storefront::Themes::Theme.new(
  requested_theme.config.deep_dup
)
```

It then applies the submitted draft content to that copy using the same recursive content rules.

Nothing needs to be written to the database just to preview a heading change.

The preview response is marked `no-store`, embedded into the internal editor, and disables normal storefront interactions. This makes the preview useful as a design surface rather than behaving like the real booking storefront.

The flow becomes:

```text
Edit form
   |
   v
Draft node content
   |
   v
Preview controller
   |
   v
Deep-copied theme config
   |
   v
Normal storefront renderer
```

That last part matters: the preview does not have a separate rendering implementation. It exercises the same components and layout as the real storefront.

---

## The Resulting Responsibilities

After iterating on this architecture, I think about each layer like this:

| Layer | Responsibility |
| --- | --- |
| Theme JSON | Product-level theme blueprint and schema |
| `Catalog` | Discovers available theme definitions |
| `Loader` | Parses and caches file-based themes |
| `Theme` | Provides a convenient nested configuration object |
| `settings_storefront_themes` | Stores tenant-specific theme state and customization |
| `StorefrontThemesRepository` | Seeds, updates, enables, and activates tenant themes |
| `RequestContext` | Resolves the tenant's effective theme for a request |
| `Registry` | Maps safe section type names to ViewComponents |
| Section ViewComponents | Own reusable rendering behavior |
| Shared page renderer | Renders sections in the configured order |
| Layout helpers | Convert theme settings into global tokens and styling |
| Internal editor | Derives editable inputs from theme content |
| Update operation | Applies safe content-only patches |
| Preview controller | Renders draft changes without persistence |

This separation is what makes the system manageable. Theme selection, content customization, rendering, and persistence are related, but they do not need to be the same abstraction.

---

## What I Would Watch as the System Grows

A data-driven theme system solves a lot of duplication, but it introduces new problems that are easy to ignore at the beginning.

### Theme schema versioning

Because tenant themes are stored snapshots, changing the JSON blueprint does not automatically migrate existing tenant data. The `version` field should eventually become part of a real migration strategy.

For example:

```text
essential 1.0.0
    |
    v
migration
    |
    v
essential 1.1.0
```

A migration can add a new section or setting while preserving tenant-edited content.

### Validation

As the schema grows, relying only on runtime access becomes risky. I would add stronger validation around theme files before deployment so invalid section types, duplicate node IDs, missing templates, or unsupported variants fail early.

### Stable node IDs

The content editor uses node IDs as the customization key. Changing `hero` to `main-hero` is therefore not just a cosmetic refactor. It can break the mapping to existing tenant customization unless it is migrated.

### Component compatibility

JSON gives themes freedom to compose supported components, but a component still has runtime data requirements. A `product_preview` component, for example, needs catalog data. The render context and page loading logic need to keep those dependencies explicit.

### Do not turn JSON into a programming language

It is tempting to keep adding conditions, loops, expressions, dynamic queries, and arbitrary actions to theme JSON.

I try to keep the boundary simple:

```text
JSON = configuration and composition
Ruby = behavior and business logic
ViewComponent = rendering
```

Once the JSON starts behaving like executable code, the safety and maintainability benefits disappear.

---

## Final Thoughts

My original goal was to avoid duplicating a complete Rails view hierarchy for every storefront theme.

The solution became more than a JSON loader.

A production-friendly configurable theme system needs to separate:

- the **theme blueprint** shipped by the application
- the **tenant's stored copy** of that theme
- the **active theme selection**
- the **rendering components**
- the **editable subset** of the configuration
- the **preview path**

The biggest benefit is not that designers can create unlimited themes without developers. That would be an unrealistic promise once themes become sophisticated.

The benefit is that most storefront differences become declarative while shared behavior stays in Ruby.

For my Rails application, that gives me a much better scaling model:

```text
new layout composition -> JSON
new tenant copy/content -> JSONB
new visual tokens -> JSON
new supported component variant -> shared component/CSS
new semantic behavior -> Ruby/ViewComponent
```

That is the boundary I want: configuration remains flexible, while application behavior stays controlled, testable, and reusable.
