.POSIX:
SHELL := /bin/sh

# Variables
POSTS_DIR := _posts
DRAFTS_DIR := _drafts
PROJECTS_DIR := _projects
DATE := $(shell date +%Y-%m-%d)
TIMESTAMP := $(shell date +"%Y-%m-%d %H:%M:%S %z")

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

.PHONY: help post publish project serve build clean install

help: ## Show this help message
	@echo "Makefile commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

install: ## Install dependencies
	@echo "$(YELLOW)Installing dependencies...$(NC)"
	@bundle install
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

serve: ## Run development server with drafts
	@echo "$(YELLOW)Starting development server...$(NC)"
	@bundle exec jekyll serve --drafts --livereload

build: ## Build the site
	@echo "$(YELLOW)Building site...$(NC)"
	@bundle exec jekyll build
	@echo "$(GREEN)✓ Site built successfully$(NC)"

clean: ## Clean generated files
	@echo "$(YELLOW)Cleaning generated files...$(NC)"
	@bundle exec jekyll clean
	@echo "$(GREEN)✓ Cleaned$(NC)"

post: ## Create a new blog post (Usage: make post title="My Post Title")
	@if [ -z "$(title)" ]; then \
		echo "$(RED)Error: title is required$(NC)"; \
		echo "Usage: make post title=\"My Post Title\""; \
		exit 1; \
	fi
	@slug=$$(echo "$(title)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-'); \
	filename="$(DRAFTS_DIR)/$$slug.md"; \
	if [ -f "$$filename" ]; then \
		echo "$(RED)Error: Draft '$$filename' already exists$(NC)"; \
		exit 1; \
	fi; \
	mkdir -p "$(DRAFTS_DIR)"; \
	echo "---" > "$$filename"; \
	echo "title: \"$(title)\"" >> "$$filename"; \
	echo "description: \"\"" >> "$$filename"; \
	echo "date: $(DATE)" >> "$$filename"; \
	echo "last_modified_at: $(DATE)" >> "$$filename"; \
	echo "author: Your Name" >> "$$filename"; \
	echo "categories:" >> "$$filename"; \
	echo "  - General" >> "$$filename"; \
	echo "tags:" >> "$$filename"; \
	echo "  - tag1" >> "$$filename"; \
	echo "  - tag2" >> "$$filename"; \
	echo "cover_image:" >> "$$filename"; \
	echo "canonical_url:" >> "$$filename"; \
	echo "draft: true" >> "$$filename"; \
	echo "---" >> "$$filename"; \
	echo "" >> "$$filename"; \
	echo "## Introduction" >> "$$filename"; \
	echo "" >> "$$filename"; \
	echo "Write your introduction here..." >> "$$filename"; \
	echo "" >> "$$filename"; \
	echo "$(GREEN)✓ Created draft: $$filename$(NC)"

publish: ## Publish a draft post (Usage: make publish title="my-post-title")
	@if [ -z "$(title)" ]; then \
		echo "$(RED)Error: title is required$(NC)"; \
		echo "Usage: make publish title=\"my-post-title\""; \
		exit 1; \
	fi
	@slug=$$(echo "$(title)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-'); \
	draft_file="$(DRAFTS_DIR)/$$slug.md"; \
	if [ ! -f "$$draft_file" ]; then \
		echo "$(RED)Error: Draft '$$draft_file' not found$(NC)"; \
		exit 1; \
	fi; \
	post_file="$(POSTS_DIR)/$(DATE)-$$slug.md"; \
	if [ -f "$$post_file" ]; then \
		echo "$(RED)Error: Post '$$post_file' already exists$(NC)"; \
		exit 1; \
	fi; \
	mkdir -p "$(POSTS_DIR)"; \
	sed -e "s/^date: .*/date: $(DATE)/" \
	    -e "s/^last_modified_at: .*/last_modified_at: $(DATE)/" \
	    -e "s/^draft: true/draft: false/" \
	    "$$draft_file" > "$$post_file"; \
	rm "$$draft_file"; \
	echo "$(GREEN)✓ Published: $$post_file$(NC)"

project: ## Create a new project (Usage: make project title="My Project")
	@if [ -z "$(title)" ]; then \
		echo "$(RED)Error: title is required$(NC)"; \
		echo "Usage: make project title=\"My Project\""; \
		exit 1; \
	fi
	@slug=$$(echo "$(title)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-'); \
	filename="$(PROJECTS_DIR)/$$slug.md"; \
	if [ -f "$$filename" ]; then \
		echo "$(RED)Error: Project '$$filename' already exists$(NC)"; \
		exit 1; \
	fi; \
	mkdir -p "$(PROJECTS_DIR)"; \
	echo "---" > "$$filename"; \
	echo "title: \"$(title)\"" >> "$$filename"; \
	echo "description: \"\"" >> "$$filename"; \
	echo "tech_stack:" >> "$$filename"; \
	echo "  - Technology 1" >> "$$filename"; \
	echo "  - Technology 2" >> "$$filename"; \
	echo "repo_url:" >> "$$filename"; \
	echo "live_url:" >> "$$filename"; \
	echo "status: Active" >> "$$filename"; \
	echo "featured: false" >> "$$filename"; \
	echo "---" >> "$$filename"; \
	echo "" >> "$$filename"; \
	echo "## Overview" >> "$$filename"; \
	echo "" >> "$$filename"; \
	echo "Describe your project here..." >> "$$filename"; \
	echo "" >> "$$filename"; \
	echo "$(GREEN)✓ Created project: $$filename$(NC)"

update: ## Update a post's last_modified_at date (Usage: make update file="path/to/post.md")
	@if [ -z "$(file)" ]; then \
		echo "$(RED)Error: file is required$(NC)"; \
		echo "Usage: make update file=\"path/to/post.md\""; \
		exit 1; \
	fi
	@if [ ! -f "$(file)" ]; then \
		echo "$(RED)Error: File '$(file)' not found$(NC)"; \
		exit 1; \
	fi
	@sed -i.bak "s/^last_modified_at: .*/last_modified_at: $(DATE)/" "$(file)"
	@rm "$(file).bak"
	@echo "$(GREEN)✓ Updated last_modified_at in $(file)$(NC)"

drafts: ## List all draft posts
	@echo "$(YELLOW)Draft posts:$(NC)"
	@if [ -d "$(DRAFTS_DIR)" ]; then \
		ls -1 "$(DRAFTS_DIR)" 2>/dev/null || echo "  No drafts found"; \
	else \
		echo "  No drafts directory"; \
	fi

posts: ## List all published posts
	@echo "$(YELLOW)Published posts:$(NC)"
	@if [ -d "$(POSTS_DIR)" ]; then \
		ls -1 "$(POSTS_DIR)" 2>/dev/null || echo "  No posts found"; \
	else \
		echo "  No posts directory"; \
	fi

projects-list: ## List all projects
	@echo "$(YELLOW)Projects:$(NC)"
	@if [ -d "$(PROJECTS_DIR)" ]; then \
		ls -1 "$(PROJECTS_DIR)" 2>/dev/null || echo "  No projects found"; \
	else \
		echo "  No projects directory"; \
	fi
