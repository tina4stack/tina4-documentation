---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "Tina4"
  text: "Documentation"
  tagline: One framework, four languages, fifty-five features, zero runtime dependencies.
  image:
    src: '/images/tina4-animated.svg'
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
      details: Python, Node.js, PHP, and Ruby share the same project structure, CLI, template syntax, route patterns, and .env variables. Learn one, know all four.
    - icon: 🧭
      title: One CLI to Rule the Stack
      details: The Rust-based `tina4` CLI detects the language, compiles SCSS, watches files, and delegates to the framework. `tina4 init`, `tina4 serve`, `tina4 migrate` — same commands across Python, PHP, Ruby, and Node.js.
    - icon: 📦
      title: Zero Runtime Dependencies
      details: Every Tina4 backend runs on the standard library. No native addons, no node-gyp, no vendor tree. Your requirements.txt / composer.json / Gemfile / package.json each hold one entry.
    - icon: 🛣️
      title: Convention-Based Routing
      details: Drop a file in `src/routes/`. The framework registers it. Typed path params (`{id:int}`, `{slug:slug}`, `{id:uuid}`) reject bad input with 404 before your handler runs.
    - icon: 🔌
      title: Built-in WebSocket + SSE
      details: Real-time bidirectional comms and server-sent events across all backends. Redis backplane for horizontal scaling. The same `WebSocketServer` API in every language.
    - icon: 🎨
      title: Frond (Twig) Templating
      details: One Twig-compatible engine. Variables, loops, template inheritance with `{{ parent() }}`, macros, filters. Write your layout once, render it in any language.
    - icon: 🗃️
      title: Six Databases, One ORM
      details: SQLite, PostgreSQL, MySQL, MSSQL, Firebird, MongoDB. `Database::create("sqlite:///app.db")` works anywhere. `sqlite:///path` is relative to your project root — same convention across all four frameworks.
    - icon: 🔐
      title: Secure by Default
      details: GET routes are public, POST/PUT/PATCH/DELETE require a bearer token. JWT (HS256/RS256), PBKDF2 password hashing, rate limiting, CSRF form tokens — all built in, nothing to configure.
    - icon: 📋
      title: Swagger at /swagger
      details: Add an `@description` decorator to your route. Visit `/swagger`. Your API docs appear — typed, grouped, ready for your team.
    - icon: 🪢
      title: GraphQL Included
      details: Zero-dependency GraphQL engine. Point it at your ORM models, get a full schema with queries, mutations, and a GraphiQL IDE. `POST /graphql` in one line.
    - icon: 📬
      title: Queues + Background Work
      details: File-backed by default, RabbitMQ/Kafka/MongoDB when you scale. Producer/consumer/dead-letter semantics consistent across languages. Periodic tasks via `background(fn, interval)` — no threads.
    - icon: 🛠️
      title: Dev Dashboard on /__dev
      details: Routes, requests, SQL runner, queue monitor, mailbox, WebSocket inspector, error tracker, AI chat — shared SPA across all four frameworks. `TINA4_DEBUG=true` turns it on.
---

## What's new

**v3.12.3 (2026-05-05)** — [full notes](/python/36-releases.md)

Cross-framework parity sweep. ResponseCache public surface is now middleware-only across all four frameworks — lookup / store / get methods moved private. Ruby's Container predicate gained the `?` suffix (`has?`) to match Python's `has()` semantically. Every framework's CLAUDE.md and book chapter 33 env-var table grounded in source — Ruby gained 98 lines of newly-documented variables, Node 113. Side fixes: Ruby `ai.rb` UTF-8 encoding crash and Node `serverParity.test.ts` runner pattern.

**v3.12.2** — Firebird URL auto-detect. Five equivalent forms (`//abs/path`, `/abs/path`, `/C:/Drive`, URL-encoded colon, alias) all resolve transparently — pick whichever reads best. New `TINA4_DATABASE_FIREBIRD_PATH` env override for Windows backslash paths and split-config setups. PHP also picks up a `mysqli` `localhost`+port quirk fix where Docker container connections were silently falling through to the Unix socket lookup.

**v3.12.0** — *Breaking change*. Every framework env var now requires the `TINA4_` prefix. The boot guard refuses to start when it spots legacy un-prefixed names (`DATABASE_URL`, `SECRET`, `SMTP_HOST`, `HOST_NAME`, etc.) and prints the rename map. Run `tina4 env --migrate` to rewrite your `.env` in place. Bundled with bug fixes #38 (Postgres UUID-PK transaction abort) and #39 (template auto-routing tightening).

## How Tina4 reads

Pick a language. Each book stands on its own — you can read Python cover-to-cover, then pick up the PHP book later and recognise every pattern.

- **[Understanding Tina4](/general/index.md)** — Architecture, philosophy, the four-language promise. Read this first if you want the why.
- **[Python](/python/index.md)** — The reference implementation. Every feature lands here first.
- **[Node.js](/nodejs/index.md)** — TypeScript-first, native `node:http`, file-based routing, ESM-only.
- **[PHP](/php/index.md)** — PHP 8.5, `stream_select` server, zero composer deps in core.
- **[Ruby](/ruby/index.md)** — Rack 3, Puma in production, WEBrick in dev.
- **[tina4-js](/js/index.md)** — The 1.5 KB reactive frontend. Signals, Web Components, router, API client, WebSocket, PWA, SSE.
- **[Delphi](/delphi/index.md)** — FireMonkey cross-platform, FireDAC, REST client, and Twig templates.

Every book has a printable PDF with a clickable table of contents. Every chapter stays in sync with the code — release notes, version numbers, and example output are regenerated with every point release.
