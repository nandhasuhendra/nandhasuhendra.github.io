---
title: "Data-Driven Themes: Managing Multiple Templates with JSON and ViewComponent in Rails"
description: "How to build a multi-theme storefront in a Rails app using JSON configs and ViewComponent, without duplicating views."
date: 2026-07-24
last_modified_at: 2026-07-24
author: Nanda Suhendra
categories:
  - Architecture
tags:
  - Ruby on Rails
  - ViewComponent
  - Architecture
  - Themes
cover_image:
canonical_url:
draft: false
---

If you are building a SaaS platform that gives each customer a public storefront, you will face a problem: customers want their own unique design. They want different layouts, colors, and content blocks on their homepage.

The common way to do this in Rails is to create a new folder for each theme in `app/views`: `theme_a/home.html.erb`, `theme_b/home.html.erb`, and so on. But when you have many themes, this becomes very hard to maintain. You will repeat the same code in many ERB files. If you change a core feature, you have to update many files.

In my recent project, I built a `storefront` Rails Engine that solves this using a **data-driven design approach**. But first, let's talk about why standard Rails tools are not enough.

### Why not use ActionPack Variants (Active Variant)?

Rails has a built-in feature to show different templates for the same action: **Variants** (using `request.variant`). You might know this feature from building mobile views (`request.variant = :phone`, which automatically looks for `home.html+phone.erb`).

You *could* set the variant to the user's chosen theme:

```ruby
def set_theme_variant
  request.variant = current_tenant.theme_name.to_sym
end
```

Then you would create files like `home.html+minimalism.erb` and `home.html+modern.erb`. 

While this looks simple, it causes problems for multi-tenant apps:
1. **Too many files**: You don't just manage one view. You have to create `layouts/application.html+theme_name.erb`, `pages/home.html+theme_name.erb`, and every partial for each theme.
2. **Repeating Code**: You end up repeating the same database queries and HTML loops in every variant file. If you add a new query, you have to update all variant templates.
3. **Needs a Developer**: To create a new theme, a developer must write new Ruby/ERB code and deploy the app. Designers or non-technical staff cannot easily create or test a new theme by themselves.

To really solve this, we need to stop writing HTML templates for themes. Instead, themes should be saved as data and rendered dynamically using [ViewComponent](https://viewcomponent.org/).

Here is how it works.

---

## 1. Themes as JSON Configuration

Instead of writing HTML, we define a theme in a JSON file. This file contains **design tokens** (colors, fonts, borders) and **page configurations** (which blocks go where).

Here is an example of `config/themes/core_minimalism.json`:

```json
{
  "name": "Core Minimalism",
  "version": "1.0.0",
  "design_tokens": {
    "primary": "#000000",
    "bg": "#ffffff",
    "font_sans": "Inter, system-ui, sans-serif"
  },
  "pages": {
    "home": {
      "seo": {
        "title": "Essentials",
        "description": "Less, but better."
      },
      "blocks": [
        {
          "type": "hero",
          "settings": {
            "title": "Less, but better.",
            "align": "center",
            "button_text": "View Collection"
          }
        },
        {
          "type": "product_preview",
          "settings": {
            "limit": 3,
            "layout": "strict_grid"
          }
        }
      ]
    }
  }
}
```

Notice that the `home` page is just a list of `blocks`. The JSON tells us *what* should be on the page, but not *how* to show it.

---

## 2. The Themes Loader

To make this fast, we read the JSON files and cache them. A simple `Loader` class handles this:

```ruby
module Storefront
  module Themes
    class Loader
      def self.for(theme_name)
        new(theme_name).load
      end

      def initialize(theme_name)
        @config     = Themes.configuration
        @theme_name = theme_name.presence || @config.default_theme
      end

      def load
        file_path   = @config.config_path.join("#{@theme_name}.json")
        fingerprint = Digest::MD5.hexdigest(File.read(file_path))
        cache_key   = "storefront/themes/#{@theme_name}/#{fingerprint}"

        Rails.cache.fetch(cache_key, expires_in: 7.days) do
          JSON.parse(File.read(file_path))
        end
      end
    end
  end
end
```

In the `ApplicationController`, we check the user's chosen theme and load its config:

```ruby
def load_theme_config
  tenant_template = @storefront_settings["template"]
  @theme_name   = params[:theme].presence || tenant_template || "core_minimalism"
  @theme_config = Storefront::Themes::Loader.for(@theme_name)
end

def set_page_config(page_key)
  @page_config = @theme_config.dig("pages", page_key)
end
```

---

## 3. Mapping Blocks to ViewComponents

The magic happens when we connect the JSON `type` (like `"hero"` or `"product_preview"`) to a Ruby class. I use a simple registry to save these connections:

```ruby
Storefront::Themes.configure do |config|
  config.register :hero,            Storefront::Blocks::HeroComponent
  config.register :product_preview, Storefront::Blocks::ProductPreviewComponent
end
```

Each component is a normal `ViewComponent` that receives the block settings. It knows how to render its own HTML.

---

## 4. The Universal View Template

Because the JSON controls the layout and the registry provides the component, the actual ERB view becomes very simple. In fact, `app/views/storefront/pages/index.html.erb` only has one line:

```erb
<%= render "storefront/pages/blocks" %>
```

And `_blocks.html.erb` just loops through the JSON array and calls the registered ViewComponent:

```erb
<% (@page_config&.dig("blocks") || []).each do |block| %>
  <%= render Storefront::Themes::Registry.resolve(block["type"]).new(
        block: block, 
        theme: @theme_name, 
        tenant: current_tenant, 
        storefront_settings: @storefront_settings
      ) %>
<% end %>
```

---

## Why This Approach Wins

1. **No Duplicated Code:** There is only one `_blocks.html.erb` file. The logic for getting products is written only once in the `ProductPreviewComponent`.
2. **Easy Theme Creation:** Adding a new theme does not require writing any Ruby code or HTML. A designer can simply copy a JSON file, move the blocks around, change the colors, and a new theme is ready.
3. **Safe Customization:** If you want customers to customize their storefronts, you don't give them access to raw HTML or ERB (which is dangerous). You just give them a UI form that updates the JSON data.

By treating templates as data instead of code, you separate the design from the logic. This keeps your Rails code clean and makes your app easy to scale for thousands of unique storefronts.
