---
title: "Building a Modern Blog with Jekyll: Complete Tutorial"
description: "Step-by-step guide to creating a production-ready blog using Jekyll with SEO optimization, performance best practices, and developer-friendly workflows."
date: 2025-12-28
last_modified_at: 2026-01-01
author: Your Name
categories:
  - Tutorial
  - Static Sites
tags:
  - jekyll
  - tutorial
  - static-site-generator
  - github-pages
cover_image: /assets/images/posts/jekyll-tutorial.jpg
canonical_url:
draft: false
---

## What You'll Learn

By the end of this tutorial, you'll have:

- A fully functional Jekyll blog
- SEO-optimized structure
- Responsive design with Tailwind CSS
- Automated deployment to GitHub Pages
- Developer-friendly content workflows

## Prerequisites

Before starting, ensure you have:

- Ruby 2.7+ installed
- Basic HTML/CSS knowledge
- Git and GitHub account
- Text editor (VS Code recommended)

## Step 1: Install Jekyll

First, install Jekyll and Bundler:

```bash
gem install jekyll bundler
```

Verify installation:

```bash
jekyll --version
# Output: jekyll 4.3.2
```

## Step 2: Create Your Project

Generate a new Jekyll site:

```bash
jekyll new my-blog
cd my-blog
```

Your project structure should look like:

```
my-blog/
├── _config.yml
├── _posts/
├── _layouts/
├── _includes/
├── assets/
├── Gemfile
└── index.html
```

## Step 3: Configure Your Site

Edit `_config.yml` with your site information:

```yaml
title: My Awesome Blog
tagline: Web Developer & Technical Writer
description: >-
  Personal blog about web development, tutorials, and tech insights

url: "https://yourusername.github.io"
baseurl: ""

author:
  name: Your Name
  email: your.email@example.com

markdown: kramdown
permalink: /:categories/:year/:month/:day/:title/

plugins:
  - jekyll-feed
  - jekyll-sitemap
  - jekyll-seo-tag
```

## Step 4: Create Custom Layouts

### Default Layout

Create `_layouts/default.html`:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{% raw %}{{ page.title }} | {{ site.title }}{% endraw %}</title>

    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body>
    {% raw %}{% include header.html %}{% endraw %}

    <main>{% raw %}{{ content }}{% endraw %}</main>

    {% raw %}{% include footer.html %}{% endraw %}
  </body>
</html>
```

### Post Layout

Create `_layouts/post.html`:

```html
---
layout: default
---

<article>
  <header>
    <h1>{% raw %}{{ page.title }}{% endraw %}</h1>
    <time>{% raw %}{{ page.date | date: "%B %d, %Y" }}{% endraw %}</time>
  </header>

  {% raw %}{{ content }}{% endraw %}
</article>
```

## Step 5: Add Includes

Create reusable components in `_includes/`:

### Header

`_includes/header.html`:

```html
<header>
  <nav>
    <a href="/">Home</a>
    <a href="/posts/">Posts</a>
    <a href="/about/">About</a>
  </nav>
</header>
```

### Footer

`_includes/footer.html`:

```html
<footer>
  <p>&copy; {% raw %}{{ site.time | date: '%Y' }} {{ site.title }}{% endraw %}</p>
</footer>
```

## Step 6: Write Your First Post

Create `_posts/2026-01-02-my-first-post.md`:

```markdown
---
title: "My First Blog Post"
description: "Getting started with Jekyll blogging"
date: 2026-01-02
categories:
  - General
tags:
  - jekyll
  - blogging
---

## Hello World!

This is my first post using Jekyll. Here's what I learned...
```

## Step 7: Build and Test Locally

Run the development server:

```bash
bundle exec jekyll serve
```

Visit `http://localhost:4000` in your browser.

## Step 8: Add SEO Optimization

Install SEO plugins:

```ruby
# Gemfile
group :jekyll_plugins do
  gem "jekyll-seo-tag"
  gem "jekyll-sitemap"
  gem "jekyll-feed"
end
```

Add to `_includes/head.html`:

```html
{% raw %}{% seo %}{% endraw %}
```

## Step 9: Deploy to GitHub Pages

### Create Repository

1. Create new repo: `username.github.io`
2. Push your code:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/username/username.github.io.git
git push -u origin main
```

### Configure GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.1
          bundler-cache: true

      - name: Build site
        run: bundle exec jekyll build

      - name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: {% raw %}${{ secrets.GITHUB_TOKEN }}{% endraw %}
          publish_dir: ./_site
```

## Step 10: Create Content Workflow

Add a Makefile for easy content management:

```makefile
.PHONY: post draft publish

post:
	@read -p "Enter post title: " title; \
	slug=$$(echo "$$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'); \
	date=$$(date +%Y-%m-%d); \
	echo "---\ntitle: \"$$title\"\ndate: $$date\n---\n" > _posts/$$date-$$slug.md

serve:
	bundle exec jekyll serve --drafts

build:
	bundle exec jekyll build
```

Usage:

```bash
make post        # Create new post
make serve       # Run dev server
make build       # Build site
```

## Common Pitfalls

### 1. Incorrect Front Matter

❌ **Wrong:**

```yaml
title: My Post
date: 01-02-2026
```

✅ **Correct:**

```yaml
title: "My Post"
date: 2026-01-02
```

### 2. Missing Dependencies

Always run `bundle install` after updating Gemfile.

### 3. Broken Links

Use Liquid tags for internal links:

```liquid
[About]({% raw %}{{ '/about/' | relative_url }}{% endraw %})
```

## Final Result

You now have:

- ✅ Production-ready Jekyll blog
- ✅ SEO optimization
- ✅ Automated deployment
- ✅ Content workflow tools
- ✅ Responsive design

## Summary

Jekyll is powerful for static blogging because:

1. **Fast:** No database queries
2. **Secure:** No server-side code
3. **Free Hosting:** GitHub Pages
4. **Version Control:** Git-based workflow
5. **SEO-Friendly:** Static HTML

Next steps:

- Customize your theme
- Add analytics
- Implement comments (Disqus, Utterances)
- Create custom plugins

---

_Questions? Check the [Jekyll documentation](https://jekyllrb.com/docs/) or [reach out](/about/)!_
