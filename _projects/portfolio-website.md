---
title: "Personal Portfolio Website"
description: "A modern, responsive portfolio website built with HTML, CSS, and vanilla JavaScript. Features smooth animations, dark mode, and mobile-first design."
tech_stack:
  - HTML5
  - CSS3
  - JavaScript
  - Tailwind CSS
repo_url: https://github.com/yourusername/portfolio
live_url: https://yourusername.github.io/portfolio
status: Completed
featured: true
---

## Overview

A clean, professional portfolio website showcasing my work and skills. Built with performance and accessibility in mind.

## Key Features

- **Responsive Design:** Mobile-first approach ensures perfect rendering on all devices
- **Dark Mode:** Automatic theme switching based on system preferences
- **Performance Optimized:** Lighthouse score of 100 across all metrics
- **Accessibility:** WCAG 2.1 AA compliant

## Technical Implementation

### Architecture

The site uses a component-based architecture with vanilla JavaScript:

- Modular CSS with utility-first approach
- Progressive enhancement for JavaScript features
- Lazy loading for images and off-screen content

### Performance Optimizations

```javascript
// Intersection Observer for lazy loading
const imageObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      const img = entry.target
      img.src = img.dataset.src
      imageObserver.unobserve(img)
    }
  })
})
```

## Challenges & Solutions

### Challenge: Smooth scroll performance

**Solution:** Used CSS `scroll-behavior` with `will-change` optimization

### Challenge: Dark mode flicker

**Solution:** Inline script in `<head>` to set theme before render

## Results

- **Lighthouse Score:** 100/100 (Performance, Accessibility, Best Practices, SEO)
- **First Contentful Paint:** < 0.8s
- **Time to Interactive:** < 1.2s
- **Bundle Size:** < 50KB total

## Lessons Learned

1. Vanilla JavaScript is often sufficient for small sites
2. CSS Grid and Flexbox eliminate need for layout frameworks
3. Aggressive caching strategies matter
4. Accessibility should be built in, not bolted on

## Future Improvements

- [ ] Add blog section
- [ ] Implement contact form with serverless function
- [ ] Add animation library for micro-interactions
- [ ] Create case study pages for projects

---

[View Live Site](https://yourusername.github.io/portfolio) • [View Source Code](https://github.com/yourusername/portfolio)
