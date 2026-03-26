---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "Tina4"
  text: "Documentation"
  tagline: This is not a framework - v3
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
    - title: Four Languages, One API
      details: Python, Node.js, PHP, and Ruby share the same project structure, CLI commands, template syntax, and .env variables. Learn one, know all four.
    - title: Sub-3KB Reactive Frontend
      details: Signals, tagged template literals, and Web Components. The entire frontend framework fits under 3KB gzipped. No virtual DOM. No build step. No complexity.
    - title: Zero-Dependency Node.js
      details: Tina4 Node.js ships with zero runtime dependencies. No native addons, no node-gyp, no platform binaries. SQLite runs through Node 22's built-in module.
    - title: Routing in Every Language
      details: Define a route. Return a response. The framework handles the rest. ASGI in Python, HTTP in Node.js, PHP, and Ruby. Same patterns across all four.
    - title: Built-in WebSocket Support
      details: Real-time communication across all backends. Connect a client, send a message, receive a response. Chat apps, live dashboards, notifications -- all handled.
    - title: Twig Templating Everywhere
      details: One template engine across Python, Node.js, PHP, and Ruby. Variables, loops, inheritance, macros. Write your layout once and render it in any language.
    - title: One-Line CRUD Generation
      details: Define an ORM model. The framework generates CRUD interfaces and migrations for SQLite, PostgreSQL, or MySQL. No boilerplate. No ceremony.
    - title: Swagger at /swagger
      details: Add a description decorator to your route. Visit /swagger. Your API documentation appears -- typed, grouped, and ready for your team to use.
    - title: JWT Authentication Built In
      details: Token-based auth, session management, and middleware. GET routes are public. POST, PUT, PATCH, and DELETE require a bearer token. Security by default.
---
