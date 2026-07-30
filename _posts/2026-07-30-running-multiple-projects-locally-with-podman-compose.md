---
title: "How I Run Several Projects Locally With Podman Compose"
description: "My actual setup for running multiple Rails projects on one machine without them fighting over ports, databases, or file permissions, using Podman Compose split into an infra file, a dev file, and a Makefile."
date: 2026-07-30
last_modified_at: 2026-07-30
author: Nanda Suhendra
categories:
  - General
tags:
  - Docker
  - Podman
  - Ruby on Rails
  - Developer Tools
cover_image:
canonical_url:
draft: false
---

I work on several projects at the same time, my own Rails app plus a couple of client projects, all on the same laptop. At some point I got tired of one project's Postgres fighting another project's Postgres over port 5432, and node_modules built for one machine breaking on another. So I set up a small system with Podman Compose. One file for shared infrastructure, one file for the actual project containers, and a Makefile so I do not have to remember flags every time. This post is that setup, using my real files.

---

## Two compose files, not one

I split everything into `docker-compose.infra.yml` and `docker-compose.dev.yml`.

`infra.yml` holds the things that stay running in the background and rarely change: Postgres, Redis, MongoDB, and a WhatsApp gateway called Evolution API that I use for testing integrations. These get started once and mostly just sit there.

`dev.yml` holds one service per project, the actual Rails app containers I am editing code in day to day. These get rebuilt often, since a Gemfile or package.json change means rebuilding the image.

Splitting them means I can restart a project's container without touching Postgres, and I can restart Postgres without every project's container restarting with it. Keeping the two lifecycles apart was the whole point.

---

## One shared network so containers can find each other

Both files reference the same external network:

```yaml
networks:
  local_dev_network:
    external: true
```

`external: true` means Podman will not create this network itself, I have to create it once ahead of time:

```bash
podman network create local_dev_network
```

Because every service from both files joins this same network, a project container can reach Postgres just by using the container name as the hostname, like `infra-postgres:5432`, no matter which compose file started which container. Without a shared network, each compose file would get its own isolated network by default, and the dev containers would have no way to reach the infra containers at all.

---

## YAML anchors, so I stop repeating myself

Both files use the same trick to avoid retyping the same settings for every service, a YAML anchor:

```yaml
x-setup: &setup
  userns_mode: "keep-id"
  tty: true
  stdin_open: true
  working_dir: /app
  environment:
    - DISABLE_SPRING=1
  networks:
    - local_dev_network

services:
  app-mebook:
    <<: *setup
    # ...
```

`x-setup` is not a real service, the leading `x-` tells Compose to ignore it as a service definition. It exists purely to be merged in with `<<: *setup`. Every service in `dev.yml` gets the same `userns_mode`, `tty`, `working_dir`, and network settings without me typing them three times. `infra.yml` does the same thing for its own shared settings, memory limits, CPU limits, and log rotation.

---

## keep-id, or why my files are not all owned by root

This one took me a while to get right. Podman by default runs containers rootless, which is good for security, but it means the container's "root" user maps to some other UID on the host, not your actual user. Any file the container creates inside a bind mount ends up owned by a UID that is not you, which is annoying when you go to edit those files from your editor outside the container.

The fix is `userns_mode: "keep-id"` inside the shared anchor. It maps the container's user to your actual host UID and GID, so files created inside the container, generated migrations, installed gems, compiled assets, come out owned by you on the host, not by some random mapped root. I do not have to `chown` anything after running a bundle install anymore.

---

## Volumes, and why there are so many of them per project

Here is one project's volumes in full:

```yaml
volumes:
  - ./projects/project-two:/app:Z

  # Explicitly mapped dependency folders (to protect binaries)
  - ./projects/project-two/node_modules:/app/node_modules:Z
  - ./projects/project-two/frontend/node_modules:/app/frontend/node_modules:Z

  # Explicitly mapped caches for all user's caches
  - ./docker/caches/project-two/user_cache:/home/developer/.cache:Z

  # Explicitly mapped caches for Ruby, Yarn, and npm
  - ./docker/caches/project-two/bundle_data:/usr/local/bundle:Z
  - ./docker/caches/project-two/yarn_data:/usr/local/yarn-cache:Z
  - ./docker/caches/project-two/npm_data:/usr/local/npm-global:Z

  # Explicitly mapped caches for Python
  - ./docker/caches/project-two/python_local:/home/developer/.local:Z
```

The whole project folder gets mounted at `/app` so my editor changes show up instantly inside the container, that part is normal. What is less obvious is why `node_modules`, the bundle cache, and the yarn and npm caches each get their own separate volume instead of just living inside that same `/app` mount.

The reason is that `node_modules` and installed gems contain compiled native binaries. If the project folder is mounted straight from the host and the container installs dependencies into it, those binaries get written back onto the host folder, built for the container's OS and architecture. That folder is also what my editor and any host side tooling touches, so now I have binaries on my host that only work inside the container, or the other way around, host binaries that break when the container tries to use them. Giving each of those folders its own dedicated volume keeps compiled dependencies fully inside the container's own storage, separate from the source code volume, so neither side steps on the other.

The same reasoning applies to `./docker/caches/project-two/bundle_data` and the yarn, npm, and Python cache folders. These persist across rebuilds, so `podman compose up --build` does not mean redownloading every gem and package from scratch every single time. Rebuild the image, keep the cache, only fetch what actually changed.

The `:Z` at the end of every mount is for SELinux. It tells the container engine to relabel the mount with a private label just for this container. If your distro enforces SELinux, skipping this means the container gets a permission denied error trying to read its own bind mounts. If SELinux is not enforcing on your machine, it is harmless, just leave it there.

---

## Ports, one block per project

Each project's dev service claims its own little range of ports:

```yaml
app-mebook:
  ports:
    - 3000:3000
    - 12345:12345

project-two:
  ports:
    - 3001:3000
    - 5173:5173
    - 12346:12345
```

Rails listens on 3000 inside every container, so the left side of each mapping, the host port, has to be different per project, or the second container just fails to start with a port already in use error. I keep a simple pattern: main app port starting at 3000 and counting up per project, Vite's dev server on 5173 for whichever project has a Vue frontend, and a debug port in the 1234x range for whichever debugger I have attached that day. Nothing fancy, just consistent enough that I do not have to think about it when I add a new project.

---

## The Makefile, so I stop typing the same flags

Podman Compose commands get long fast, so I wrapped the ones I actually use into a Makefile:

```makefile
infra-start-all:
	@podman compose -f docker-compose.infra.yml up -d

infra-stop-all:
	@podman compose -f docker-compose.infra.yml stop

dev-start-all:
	@podman compose --in-pod=0 -f docker-compose.dev.yml up -d

dev-stop-all:
	@podman compose --in-pod=0 -f docker-compose.dev.yml stop

dev-start:
	@podman compose --in-pod=0 -f docker-compose.dev.yml up -d ${NAME}

dev-stop:
	@podman compose --in-pod=0 -f docker-compose.dev.yml stop ${NAME}
```

So starting everything is just `make infra-start-all` followed by `make dev-start-all`. Starting just one project is `make dev-start NAME=project-two`. I do not have to remember the compose file name or any flags, just the make target and, when I need it, the project name.

The `--in-pod=0` flag on the dev commands tells Podman Compose not to group all the dev containers under one shared pod. By default Podman Compose puts every service from a compose file into a single pod sharing one network namespace. With three unrelated projects in the same file, I want to be able to stop or rebuild one of them without touching the others, so each dev container gets its own independent lifecycle instead of being bundled together.

---

## Rebuilding one project without touching the rest

The target I use the most is this one:

```makefile
dev-rebuild:
	@if [ -n "$$(podman ps -a -q --filter "name=${NAME}")" ]; then \
		echo "Container for service '${NAME}' exists. Rebuilding..."; \
		podman compose --in-pod=0 -f docker-compose.dev.yml down ${NAME}; \
	else \
		echo "Container for service '${NAME}' does not exist. Skipping."; \
	fi
	@podman compose --in-pod=0 -f docker-compose.dev.yml up -d --build ${NAME}
```

`make dev-rebuild NAME=project-two` checks if a container with that name already exists using `podman ps -a -q --filter`. If it does, it tears it down first with `down`. Either way, it finishes with `up -d --build`, forcing a fresh image build. This is the one I reach for after pulling a branch that changed the Dockerfile or added a new gem, rebuild just that one project, everything else keeps running untouched.

`infra-rebuild` is the same idea for infra services, useful for the rare time I bump the Postgres image version and need that one container rebuilt without restarting Redis or Mongo along with it.

---

## What is actually sitting in infra

Postgres, Redis, and MongoDB are the plain, expected ones:

```yaml
postgres:
  image: postgres:alpine
  container_name: infra-postgres
  ports:
    - "5432:5432"
  environment:
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
  volumes:
    - ./docker/infra/postgres:/var/lib/postgresql:Z
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 10s
    timeout: 5s
    retries: 5
```

One Postgres instance, one Redis, one Mongo, shared by every project through the same network. Every project's database config just points at `infra-postgres` as the host, with its own database name, so there is no need to run a separate Postgres container per project.

The healthcheck matters more than it looks. Postgres's container can report as "started" before it is actually ready to accept connections, and if a Rails container tries to migrate the moment it starts, it can fail against a database that has not finished booting yet. `pg_isready` gives Compose an actual signal to check instead of guessing based on timing.

Each infra service also gets memory and CPU limits from the shared anchor, `mem_limit`, `mem_reservation`, `cpus`, plus log rotation with `max-size` and `max-file`. None of this matters much when everything is healthy, but on a laptop running several databases plus a handful of app containers at once, one runaway container logging forever, or one service quietly eating all the RAM, is the kind of thing that grinds the whole machine to a halt. The limits are just a guardrail against that.

---

## Wrapping up

None of this is complicated on its own, splitting infra from dev, one shared network, anchors to avoid repetition, careful volumes, a Makefile on top. What made it worth writing down is that each piece solved one specific annoyance I actually hit: containers that could not see each other until I added the shared network, files owned by the wrong user until `keep-id`, gems reinstalling from scratch on every rebuild until I gave the caches their own volumes, and one project's container going down when I only meant to touch another until `--in-pod=0`.

If you are running more than one project locally with Podman or Docker, my advice is to start with the two file split, infra separate from dev, before anything else. Everything else in this setup exists to solve a problem that split created room for.
