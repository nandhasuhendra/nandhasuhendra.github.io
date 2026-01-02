---
title: "The Case of the Duplicated Jobs: A Tech Detective Story"
description: "Debugging background job issue after added new oberserver gems"
date: 2026-01-02
last_modified_at: 2026-01-02
author: Nanda Suhendra
categories:
  - General
tags:
  - Sidekiq
  - Ruby on Rails
  - OpenTelemetry
  - Background Job
cover_image:
canonical_url:
draft: false
---

You know that weird feeling of deja vu? When you're sure you've seen or done something before? Well, our system was having a serious case of it back in May. Our background job processor, Sidekiq, started duplicating jobs. Imports, exports, and our recalculation job—they were running twice, causing all sorts of headaches and data inconsistencies.

![image-1.webp](/assets/images/posts/2025-10-13-the-case-of-the-duplicated-jobs-a-tech-detective-story/image-1.webp)

### The First "Fix" and a New Problem

Our first move was a hotfix that seemed to calm things down. The culprit appeared to be OpenTelemetry, a tool we use to monitor what's happening inside our app. So, we disabled it. The duplicated jobs stopped, and we all breathed a sigh of relief.

But not for long.

A few days later, another team reached out. Their jobs, specifically a key data processing job, had slowed down significantly since our "fix." It turned out they _really_ needed OpenTelemetry to keep things running smoothly. We were stuck between a rock and a hard place: turn it on and risk the duplicates, or leave it off and deal with slow jobs.

We decided to flip the switch back on. And boy, did the deja vu return with a vengeance. The duplication issue was back, and it was worse than ever.

![image-2.webp](/assets/images/posts/2025-10-13-the-case-of-the-duplicated-jobs-a-tech-detective-story/image-2.webp)

---

### Digging for the Real Culprit

It was clear our first fix was just a band-aid. We had to go deeper. This is where the real detective work began. We knew the problem started the moment we re-enabled OpenTelemetry, but why?

Here's what our investigation uncovered:

1. **The Overly Eager Helper:** We had enabled OpenTelemetry with a single line of code: `require 'opentelemetry/instrumentations/all'`. This little line tells OpenTelemetry to instrument _everything_ it possibly can. It was like hiring a helper for one task, and they decided to reorganize your entire house, garage, and backyard.
2. **Too Many Cooks in the Kitchen:** This "instrument everything" approach meant OpenTelemetry was digging into all our dependencies, including a gem called `ConcurrentRuby` that our Sidekiq-Pro relies on for multi-threading.
3. **The Conflict:** Here was the "aha!" moment. OpenTelemetry was now trying to apply its own instrumentation to both Sidekiq and `ConcurrentRuby`. These two instrumentations started clashing. It was like two people trying to shove their way through the same doorway at the same time—nothing gets through cleanly, and chaos ensues. This conflict was the true root cause of our duplicated jobs.

### The Real Solution

Once we found the real problem, the solution was surprisingly simple. Instead of telling OpenTelemetry to instrument everything, we just gave it a specific list of the things we actually needed it to watch. No more, no less.

Here’s what that change looked like in our code:

### **Before (The Problem Code):**

```ruby
# config/initializers/opentelemetry.rb

# This one line loaded EVERY instrumentation,
# which caused the conflict.
require 'opentelemetry/instrumentations/all'
```

### **After (The Fix):**

```ruby
# config/initializers/opentelemetry.rb

# We replaced the 'all' command with just the ones we needed.
# This avoided the conflict altogether.
require 'opentelemetry/instrumentation/rails'
require 'opentelemetry/instrumentation/sidekiq'
require 'opentelemetry/instrumentation/net_http'
# ... plus a few other specific instrumentations our app uses.
```

We rolled out the change on July 24th and held our breath. After a few days of monitoring, we confirmed it: the issue was gone. Duplication jobs dropped dramatically, and the other team's job latency went back to normal. A true win-win!

![image-3.webp](/assets/images/posts/2025-10-13-the-case-of-the-duplicated-jobs-a-tech-detective-story/image-3.webp)

So, what's the moral of the story? Sometimes, the easy, all-in-one command isn't the best solution. Being specific and understanding how your tools interact with each other can save you from a massive headache and a serious case of system deja vu.

---

**Summary:** Our system started duplicating background jobs in Sidekiq, leading to data inconsistencies. The root cause was a conflict between OpenTelemetry's auto-instrumentation for Sidekiq and a core dependency, `ConcurrentRuby`. This was triggered by using a generic command to load all instrumentations. The fix was to replace this catch-all command with a specific list of required instrumentations, resolving the conflict without disabling our monitoring.
