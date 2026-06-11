---
title: "QWikidata"
description: "Internal data management web application for managing and structuring operational data. Built for Firegent with a focus on reliability, role-based access, and a clean user interface."
tech_stack:
  - Ruby on Rails
  - PostgreSQL
  - Tailwind CSS
  - Hotwire
  - Docker
live_url: https://qwikidata.firegent.com/
status: Active
featured: true
---

## Overview

QWikidata is an internal web application for managing structured operational data at Firegent. It provides a centralised interface for data entry, review, and access control across the organisation.

## Key Features

- **Data Management**: Create, update, and organise structured records with a clean UI
- **Authentication**: Secure sign-in with email/password and session management
- **Role-based Access**: Scoped permissions to control what each user can view or edit
- **Reliability**: Built with Rails conventions and tested for production robustness

## Tech Highlights

- Ruby on Rails as the core framework
- PostgreSQL for relational data storage
- Hotwire (Turbo + Stimulus) for reactive UI without heavy JavaScript
- Tailwind CSS for fast, consistent styling
- Deployed and containerised with Docker
