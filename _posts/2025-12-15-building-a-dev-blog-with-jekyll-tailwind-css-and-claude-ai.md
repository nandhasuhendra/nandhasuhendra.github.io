---
title: "Building a Dev Blog with Jekyll, Tailwind CSS, and Claude AI"
description: "A practical guide to building a personal developer blog with Jekyll and GitHub Pages — and how I used Claude AI to skip the boring parts and ship faster."
date: 2025-12-15
last_modified_at: 2025-12-15
author: Nanda Suhendra
categories:
  - General
tags:
  - Jekyll
  - Tailwind CSS
  - GitHub Pages
  - AI
  - Claude
draft: false
---

Every developer has that moment. You open someone else's blog, read a great article, and think: *"I should start writing too."* Then you close the tab, open your editor, stare at a blank file, and realize you have no idea where to start — not for the content, but for the blog itself.

That was me. For years I had bookmarked "how to start a dev blog" articles without actually starting one. The excuses were always there: too busy, don't know what to write, can't pick a platform. The classic developer trap of over-engineering the setup before writing a single word.

This time, I decided to just build the thing. And I let AI help me do it faster than I ever could alone.

---

### Why Jekyll?

The first question was the platform. WordPress? Too heavy. Medium? I want to own my content. Dev.to? Great for reach, but I wanted a personal space. Ghost? Beautiful, but overkill for a side project.

Jekyll kept coming up. It's a static site generator — you write your posts in Markdown, Jekyll compiles everything into plain HTML, and you get a fast, lightweight site with zero database, zero server to manage, and zero hosting cost when paired with GitHub Pages.

As a software engineer who deals with production incidents at work, the last thing I wanted was another service to keep alive on weekends. No databases to back up. No servers to patch. Just files in a Git repository. That simplicity was the dealbreaker.

```bash
# This is all it takes to start locally
gem install jekyll bundler
jekyll new my-blog
bundle exec jekyll serve
```

Thirty seconds and you have a running site at `localhost:4000`. Beautiful.

---

### The Stack

Once I settled on Jekyll, I needed to make decisions about the rest of the stack. Here's what I landed on and why:

**Tailwind CSS** — I didn't want to write a CSS file from scratch. Tailwind's utility classes let me design directly in HTML. More importantly, it meant I could ask AI to generate components and they'd just work — no custom class names to explain.

**Lucide Icons** — Clean, consistent, open-source icon set. Drop a `<script>` tag, add `data-lucide="github"` to any element, call `lucide.createIcons()` and you're done. No icon font bloat, no sprite sheets.

**GitHub Pages** — Free hosting for static sites tied to your GitHub repository. Every push to `main` triggers an automatic build and deploy. My CI/CD pipeline is literally just `git push`.

**Google Analytics 4** — To know if anyone's actually reading (spoiler: it's mostly me and a few bots at the start, and that's fine).

---

### Letting AI Do the Heavy Lifting

Here's the honest part. I know Ruby on Rails well. I know Go. I do not enjoy writing HTML and CSS from scratch. It's not that I can't — it's that I'd rather spend that time on the content and the architecture decisions.

So I paired up with Claude AI and treated it like a senior frontend engineer sitting next to me.

The workflow was simple:

1. I described what I wanted — *"a hero section with my name, tagline, and social links"*
2. AI generated the markup and Tailwind classes
3. I reviewed, adjusted, and moved on

What would have taken me a few hours of Googling, tweaking, and frustration took maybe 20 minutes per section. The AI knew Tailwind's utility classes better than I did, suggested accessibility improvements I'd have missed, and even caught icon names that didn't exist in the Lucide library.

Was every suggestion perfect? No. I had to push back on a few things — overly complex markup, unnecessary abstractions, wrong brand colors. But that's the same as working with any developer. You review, you give feedback, and the output improves.

The most useful thing AI helped me with was the parts I find genuinely boring: SEO meta tags, JSON-LD structured data, Open Graph tags, RSS feeds. Stuff that matters for discoverability but requires no creative thought. I just said *"add proper SEO support"* and got back a complete `_includes/seo.html` and `_includes/json-ld.html` that I'd have spent half a day copying from Stack Overflow otherwise.

```html
<!-- AI generated this. I would not have written it from scratch. -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Person",
  "name": "{{ site.author.name }}",
  "jobTitle": "Software Engineer",
  "worksFor": {
    "@type": "Organization",
    "name": "Dropsuite"
  }
}
</script>
```

---

### The Parts That Took Real Thought

AI was great at generating boilerplate. But the decisions that made this blog *mine* required actual thinking:

**Content structure** — How do I organize posts? What's the URL format? Should I have categories, tags, or both? Jekyll's front matter gives you full control, but you have to decide how to use it.

**What to actually write about** — No AI can tell you what experiences matter. The post about [debugging duplicate Sidekiq jobs](/general/2025/10/13/the-case-of-the-duplicated-jobs-a-tech-detective-story/) came from a real incident at work. That story is mine. The lesson learned is mine. AI can help format it, but it can't live it.

**The tools page** — I made a deliberate decision to list only the tools I actually use, not aspirational ones. It's tempting to add Kubernetes when you've only touched it once. Honesty builds more trust than a polished resume.

---

### How the Site Works

Here's a quick tour of the final structure for anyone curious about replicating it:

```
├── _config.yml          # Site-wide settings, author info, social links
├── _includes/           # Reusable HTML partials
│   ├── head.html        # Meta tags, scripts, Analytics
│   ├── header.html      # Navigation bar
│   ├── footer.html      # Footer with social icons
│   └── post-card.html   # Card component for post listings
├── _layouts/
│   ├── default.html     # Base layout with header + footer
│   └── post.html        # Blog post layout
├── _posts/              # Markdown blog posts
├── _projects/           # Project collection files
├── posts/index.html     # Posts listing page with search + filter
├── projects/index.html  # Projects showcase
├── tools/index.html     # My developer tools page
└── index.html           # Homepage
```

Everything in `_config.yml` drives the entire site. Author name, bio, social links — change them once and they update everywhere. No hunting through templates.

---

### Deployment: The Best Part

```bash
git add .
git commit -m "feat: add new post"
git push origin main
# done. live in ~60 seconds.
```

GitHub Actions picks up the push, runs the Jekyll build, and deploys to `https://nandhasuhendra.github.io`. No dashboards to log into. No deploy buttons to click. Just Git.

The entire setup costs **zero dollars** per month. For a personal blog with a reasonable amount of traffic, you will never need anything more.

---

### What I Learned

A few things I wish I had known at the start:

- **Start with content, not design.** I spent too long perfecting the homepage before writing a single post. The design is secondary — one reader who learns something from your writing is worth more than a pixel-perfect hero section nobody reads.
- **AI is a multiplier, not a replacement.** It made me faster on the parts I find tedious. It didn't replace the judgment calls, the writing, or the experience behind each post.
- **Keep it boring.** No JavaScript frameworks, no complex build pipelines, no external databases. The simpler the stack, the longer it stays alive without maintenance.
- **Own your content.** Every post I write here is a Markdown file in a Git repo. I can take it anywhere. Platform lock-in is a tax you pay forever.

---

### What's Next

The blog is live and the foundation is solid. Now the actual work begins — writing consistently. I want to cover more real production stories, deep dives into Rails internals, and notes on picking up Go as a Rails developer.

If you're sitting on the fence about starting your own — just pick a stack, accept that it won't be perfect on day one, and ship it. The blog you have is infinitely better than the blog you're still planning.

---

**Summary:** I built this blog using Jekyll for static site generation, Tailwind CSS for styling, and GitHub Pages for free zero-maintenance hosting. Claude AI handled the boilerplate — SEO markup, icon setup, component layouts — while I focused on architecture decisions and content. The result is a fast, simple site that costs nothing to run and deploys with a single `git push`. The most important lesson: start before you're ready, keep the stack boring, and write the thing.
