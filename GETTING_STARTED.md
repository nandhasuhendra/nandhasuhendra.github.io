---
layout: page
title: Getting Started
description: Quick start guide for your new Jekyll website
---

## Welcome to Your New Jekyll Website! 🎉

This guide will help you get started with your production-ready personal website.

## First Steps

### 1. Update Site Configuration

Edit [\_config.yml](_config.yml) and update:

```yaml
title: Your Name
tagline: Your Role/Tagline
description: Your site description
url: "https://yourusername.github.io"

author:
  name: Your Name
  email: your.email@example.com
  bio: Your professional bio
  social:
    github: yourusername
    twitter: yourusername
    linkedin: yourprofile
```

### 2. Customize About Page

Edit [about/index.md](about/index.md) with your:

- Professional background
- Skills and expertise
- Work experience
- Education
- Contact information

### 3. Remove Example Content

Delete or customize:

- `_posts/2026-01-02-welcome-to-jekyll.markdown` (default Jekyll post)
- `_posts/2025-12-28-jekyll-tutorial.md` (example tutorial)
- `_posts/2026-01-02-web-performance-optimization.md` (example article)
- `_drafts/react-hooks-comparison.md` (example draft)
- `_projects/portfolio-website.md` (example project)
- `_projects/seo-analyzer.md` (example project)

### 4. Add Your Content

Create your first blog post:

```bash
make post title="My First Post"
```

Edit the generated file in `_drafts/`, then publish:

```bash
make publish title="my-first-post"
```

### 5. Add Your Projects

```bash
make project title="My Cool Project"
```

Edit the file in `_projects/` with your project details.

## Local Development

### Install Dependencies

```bash
bundle install
```

### Run Development Server

```bash
make serve
# or
bundle exec jekyll serve --drafts --livereload
```

Visit: http://localhost:4000

### Build for Production

```bash
make build
# or
bundle exec jekyll build
```

## Content Workflow

### Writing a Blog Post

1. **Create Draft:**

   ```bash
   make post title="Understanding Web Components"
   ```

2. **Edit:** Open `_drafts/understanding-web-components.md`

3. **Preview:** Run `make serve` and check http://localhost:4000

4. **Publish:**
   ```bash
   make publish title="understanding-web-components"
   ```

### Blog Post Structure

Refer to [BLOG_TEMPLATES.md](BLOG_TEMPLATES.md) for:

- Technical Article template
- Tutorial/How-To template
- Comparison Article template

### Front Matter Checklist

```yaml
---
title: "Clear, Descriptive Title"
description: "SEO-friendly 120-160 character description"
date: 2026-01-02
last_modified_at: 2026-01-02
author: Your Name
categories:
  - Main Category
  - Sub Category
tags:
  - relevant-tag
  - another-tag
cover_image: /assets/images/posts/image.jpg
canonical_url: # Optional: for syndicated content
draft: false
---
```

## Customization

### Update Colors

Edit [assets/css/main.css](assets/css/main.css):

```css
:root {
  --primary: #2563eb; /* Your brand color */
  --primary-dark: #1d4ed8;
  --accent: #ec4899;
}
```

### Add Images

1. Place images in `assets/images/`
2. Reference in Markdown:
   ```markdown
   ![Alt text](/assets/images/my-image.jpg)
   ```

### Modify Navigation

Edit [\_includes/header.html](_includes/header.html) to add/remove menu items.

### Update Footer

Edit [\_includes/footer.html](_includes/footer.html) with your information.

## Deployment

### GitHub Pages (Automatic)

1. Create repository named: `username.github.io`
2. Push your code:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/username/username.github.io.git
   git push -u origin main
   ```
3. Enable GitHub Pages in Settings → Pages
4. GitHub Actions will automatically deploy

Your site will be live at: `https://username.github.io`

### Custom Domain (Optional)

1. Add file `CNAME` with your domain:

   ```
   yourdomain.com
   ```

2. Configure DNS:

   ```
   A Record: 185.199.108.153
   A Record: 185.199.109.153
   A Record: 185.199.110.153
   A Record: 185.199.111.153
   ```

3. Wait for DNS propagation (up to 24 hours)

## SEO Optimization

### Essential Tasks

- [x] ✅ Meta tags configured
- [x] ✅ Open Graph tags added
- [x] ✅ Twitter Cards enabled
- [x] ✅ Sitemap.xml generated
- [x] ✅ Robots.txt configured
- [x] ✅ RSS feed available
- [x] ✅ Structured data (JSON-LD)

### Submit to Search Engines

1. **Google Search Console:** https://search.google.com/search-console

   - Submit sitemap: `https://yourdomain.com/sitemap.xml`

2. **Bing Webmaster Tools:** https://www.bing.com/webmasters
   - Submit sitemap

### Monitor Performance

- **Google Analytics:** Add tracking ID to `_config.yml`
- **Google PageSpeed Insights:** Test your pages
- **Lighthouse:** Check scores in Chrome DevTools

## Makefile Commands

| Command                      | Description          |
| ---------------------------- | -------------------- |
| `make help`                  | Show all commands    |
| `make install`               | Install dependencies |
| `make serve`                 | Run dev server       |
| `make build`                 | Build site           |
| `make post title="Title"`    | Create new post      |
| `make publish title="slug"`  | Publish draft        |
| `make project title="Title"` | Create new project   |
| `make drafts`                | List all drafts      |
| `make posts`                 | List published posts |
| `make clean`                 | Clean build files    |

## Troubleshooting

### Port 4000 Already in Use

```bash
# Kill the process
lsof -ti:4000 | xargs kill -9

# Or use a different port
bundle exec jekyll serve --port 4001
```

### Bundle Install Fails

```bash
# Update bundler
gem install bundler

# Try again
bundle install
```

### Changes Not Showing

1. Stop server (Ctrl+C)
2. Clear cache: `make clean`
3. Restart: `make serve`

### GitHub Pages Not Building

1. Check `.github/workflows/deploy.yml` exists
2. Enable GitHub Actions in Settings
3. Check Actions tab for error logs

## Resources

### Documentation

- [Jekyll Docs](https://jekyllrb.com/docs/)
- [GitHub Pages](https://docs.github.com/en/pages)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Alpine.js](https://alpinejs.dev/)

### Tools

- [Markdown Guide](https://www.markdownguide.org/)
- [Front Matter](https://jekyllrb.com/docs/front-matter/)
- [Liquid Templates](https://shopify.github.io/liquid/)

### Inspiration

- [Jekyll Themes](https://jekyllthemes.io/)
- [GitHub Pages Examples](https://github.com/collections/github-pages-examples)

## Next Steps

1. ✅ Update `_config.yml` with your information
2. ✅ Customize `about/index.md`
3. ✅ Remove example content
4. ✅ Write your first post
5. ✅ Add your projects
6. ✅ Deploy to GitHub Pages
7. ✅ Submit sitemap to search engines
8. ✅ Share your website!

## Support

Need help? Check:

- [README.md](README.md) - Full documentation
- [BLOG_TEMPLATES.md](BLOG_TEMPLATES.md) - Content templates
- [Jekyll Documentation](https://jekyllrb.com/docs/)

---

Happy blogging! 🚀
