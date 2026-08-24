---
title: "Mebook"
description: "A multi-tenant business management and booking platform for salons, barbershops, spas, and small businesses, with customer-facing storefronts and WhatsApp integration."
tech_stack:
  - Ruby on Rails
  - PostgreSQL
  - Hotwire
  - ViewComponent
  - Tailwind CSS
live_url: https://mebookapp.com/
status: In Development
featured: true
---

## Overview

Mebook is a multi-tenant SaaS application for managing day-to-day business operations in one place. It is designed for service businesses that currently rely on scattered WhatsApp chats, spreadsheets, or paper notes.

## Key Features

- **Booking Management**: Manage appointments and customer bookings
- **CRM**: Keep customer information and history organised
- **Catalog & Inventory**: Manage services, products, and stock
- **Transactions & Reports**: Track business income, expenses, and operational reports
- **Storefront**: Give each business its own configurable customer-facing storefront
- **WhatsApp Integration**: Support customer communication and notifications through WhatsApp

## Tech Highlights

- Ruby on Rails modular monolith using isolated Rails Engines
- PostgreSQL for application data
- Hotwire and ViewComponent for the UI
- JSON-driven configurable storefront themes
- Background processing with Sidekiq and Redis/Valkey
- Production deployment with Docker, Kamal, and Ansible
