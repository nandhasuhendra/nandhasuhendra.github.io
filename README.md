# Jekyll Personal Website

A production-ready personal website built with Jekyll, featuring a flat design aesthetic, strong SEO foundations, and excellent developer experience.

## Features

- ✨ **Flat Design:** Clean, minimalist aesthetic with solid colors and strong typography
- 🚀 **Performance Optimized:** Minimal JavaScript, lazy-loaded images, cache-friendly
- 🔍 **SEO Ready:** Comprehensive meta tags, structured data, sitemap, RSS feed
- 📱 **Responsive:** Mobile-first design that works on all devices
- 🎨 **Dark Mode:** Automatic theme switching via `prefers-color-scheme`
- 🛠️ **Developer Tools:** Makefile commands for easy content management
- 🔄 **Auto Deploy:** GitHub Actions workflow for automatic deployment

## Tech Stack

- **Jekyll** - Static site generator
- **Tailwind CSS** - Utility-first CSS framework (via CDN)
- **Alpine.js** - Lightweight JavaScript framework (via CDN)
- **GitHub Pages** - Free hosting
- **GitHub Actions** - CI/CD pipeline

## Quick Start

### Prerequisites

- Ruby 2.7+ and Bundler
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/blog.git
cd blog

# Install dependencies
make install
# or
bundle install

# Run development server
make serve
# or
bundle exec jekyll serve --drafts
```

Visit `http://localhost:4000` in your browser.

## Developer Commands

The included Makefile provides convenient commands:

```bash
# Create new blog post (in _drafts)
make post title="My New Post"

# Publish a draft
make publish title="my-new-post"

# Create new project
make project title="My Project"

# List all drafts
make drafts

# List all posts
make posts

# List all projects
make projects-list

# Update last_modified_at date
make update file="_posts/2026-01-02-my-post.md"

# Build site
make build

# Clean generated files
make clean

# Show all commands
make help
```

## Project Structure

```
blog/
├── _config.yml              # Site configuration
├── _layouts/                # Page layouts
│   ├── default.html
│   ├── page.html
│   ├── post.html
│   └── project.html
├── _includes/               # Reusable components
│   ├── head.html
│   ├── header.html
│   ├── footer.html
│   ├── post-card.html
│   ├── project-card.html
│   ├── seo.html
│   └── json-ld.html
├── _posts/                  # Published blog posts
├── _drafts/                 # Draft posts
├── _projects/               # Project pages
├── assets/
│   ├── css/
│   │   └── main.css        # Custom CSS
│   └── images/
├── posts/                   # Blog index
│   └── index.html
├── projects/                # Projects index
│   └── index.html
├── about/                   # About page
│   └── index.md
├── index.html               # Homepage
├── sitemap.xml              # SEO sitemap
├── robots.txt               # Robots file
├── feed.xml                 # RSS feed
├── Makefile                 # Developer commands
└── .github/
    └── workflows/
        └── deploy.yml       # GitHub Actions workflow
```

## Content Management

### Creating a Blog Post

1. Create draft:

   ```bash
   make post title="Understanding Web Performance"
   ```

2. Edit the file in `_drafts/understanding-web-performance.md`

3. Add content using Markdown

4. Preview with drafts:

   ```bash
   make serve
   ```

5. Publish when ready:
   ```bash
   make publish title="understanding-web-performance"
   ```

### Blog Post Front Matter

```yaml
---
title: "Your Post Title"
description: "SEO-friendly description"
date: 2026-01-02
last_modified_at: 2026-01-02
author: Your Name
categories:
  - Web Development
  - Performance
tags:
  - javascript
  - optimization
cover_image: /assets/images/posts/my-image.jpg
canonical_url: https://example.com/original-post
draft: false
---
```

### Creating a Project

```bash
make project title="My Awesome Project"
```

Edit `_projects/my-awesome-project.md`:

```yaml
---
title: "My Awesome Project"
description: "Project description"
tech_stack:
  - React
  - TypeScript
  - Tailwind CSS
repo_url: https://github.com/username/project
live_url: https://project.example.com
status: Active
featured: true
---
```

## Customization

### Update Site Information

Edit `_config.yml`:

```yaml
title: Your Name
tagline: Your Role/Tagline
description: Your site description
url: "https://yourusername.github.io"

author:
  name: Your Name
  email: your.email@example.com
  bio: Your bio
  social:
    github: yourusername
    twitter: yourusername
    linkedin: yourprofile
```

### Modify Colors

Edit `assets/css/main.css`:

```css
:root {
  --primary: #2563eb; /* Primary color */
  --primary-dark: #1d4ed8; /* Hover state */
  --accent: #ec4899; /* Accent color */
}
```

## Deployment

### GitHub Pages

1. Create repository: `username.github.io`
2. Push your code
3. Enable GitHub Pages in repository settings
4. GitHub Actions will automatically build and deploy

### Custom Domain (Optional)

1. Add `CNAME` file with your domain
2. Configure DNS records
3. Enable HTTPS in GitHub Pages settings

## SEO Optimization

The site includes:

- ✅ Meta tags (title, description, keywords)
- ✅ Open Graph tags for social sharing
- ✅ Twitter Cards
- ✅ JSON-LD structured data
- ✅ Canonical URLs
- ✅ Sitemap.xml
- ✅ Robots.txt
- ✅ RSS feed
- ✅ Semantic HTML5
- ✅ Optimized heading hierarchy

## Performance

Best practices implemented:

- Minimal JavaScript (Alpine.js only)
- CSS via CDN with proper caching
- Lazy-loaded images
- No render-blocking resources
- Browser caching headers (via GitHub Pages)
- Responsive images
- Dark mode via CSS (no JS flash)

Expected Lighthouse scores: 95-100 across all metrics.

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Contributing

Feel free to fork this template and customize it for your needs!

## License

MIT License - feel free to use this template for your personal website.

## Support

For issues or questions:

- Create an issue on GitHub
- Check Jekyll documentation: https://jekyllrb.com/docs/
- Review GitHub Pages docs: https://docs.github.com/en/pages

---

Built with ❤️ using Jekyll
