---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "Tina4"
  text: "Documentation"
  tagline: The Intelligent Native Application 4ramework
  image:
    src: './logo.svg'
  actions:
    - theme: brand
      text: Get Started
      link: get-started.md
    - theme: alt
      text: tina4-js
      link: /js/index.md
    - theme: alt
      text: Python
      link: /python/index.md
    - theme: alt
      text: Node.js
      link: /nodejs/index.md
    - theme: alt
      text: PHP
      link: /php/index.md
    - theme: alt
      text: Ruby
      link: /ruby/index.md
    - theme: alt
      text: Delphi
      link: /delphi/index.md
    - theme: alt
      text: Comparisons
      link: /comparisons.md


features:
    - icon: 🌐
      title: Four Languages, One API
      details: Python, Node.js, PHP, and Ruby share the same project structure, CLI commands, template syntax, and .env variables. Learn one, know all four.
    - icon: ⚡
      title: 1.5KB Reactive Core
      details: Signals, tagged template literals, and Web Components in a 1.5KB gzipped core. The full tina4-js framework with router, API client, WebSocket, and PWA ships under 6KB gzipped.
    - icon: 📦
      title: Zero Runtime Dependencies
      details: Every Tina4 backend runs on the standard library alone. No native addons, no node-gyp, no platform binaries. Pure language, nothing else.
    - icon: 🛣️
      title: Convention-Based Routing
      details: Drop a file in src/routes/. The framework registers it. Return a response. ASGI in Python, native HTTP in Node.js, PHP, and Ruby. Same pattern everywhere.
    - icon: 🔌
      title: Built-in WebSocket Support
      details: Real-time communication across all backends. Connect, send, receive. Chat apps, live dashboards, notifications. Redis backplane for horizontal scaling.
    - icon: 🎨
      title: Frond (Twig) Templating
      details: One Twig-compatible template engine across Python, Node.js, PHP, and Ruby. Variables, loops, inheritance, macros. Write your layout once and render it in any language.
    - icon: 🗃️
      title: One-Line CRUD Generation
      details: Define an ORM model. The framework generates REST endpoints and migrations for SQLite, PostgreSQL, MySQL, MSSQL, Firebird, and MongoDB.
    - icon: 📋
      title: Swagger at /swagger
      details: Add a description decorator to your route. Visit /swagger. Your API documentation appears -- typed, grouped, and ready for your team to use.
    - icon: 🔐
      title: JWT Authentication Built In
      details: Token-based auth, session management, and middleware. GET routes are public. POST, PUT, PATCH, and DELETE require a bearer token. Security by default.
---
