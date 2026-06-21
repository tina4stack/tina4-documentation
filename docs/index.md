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
      details: The Rust-based `tina4` CLI detects the language, compiles SCSS, watches files, and delegates to the framework. `tina4 init`, `tina4 serve`, and `tina4 migrate` run the same across Python, PHP, Ruby, and Node.js.
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
      details: SQLite, PostgreSQL, MySQL, MSSQL, Firebird, MongoDB. `Database::create("sqlite:///app.db")` works anywhere. `sqlite:///path` is relative to your project root, the same convention across all four frameworks.
    - icon: 🔐
      title: Secure by Default
      details: GET routes are public, POST/PUT/PATCH/DELETE require a bearer token. JWT (HS256/RS256), PBKDF2 password hashing, rate limiting, CSRF form tokens, all built in, nothing to configure.
    - icon: 📋
      title: Swagger at /swagger
      details: Add an `@description` decorator to your route. Visit `/swagger`. Your API docs appear, typed, grouped, ready for your team.
    - icon: 🪢
      title: GraphQL Included
      details: Zero-dependency GraphQL engine. Point it at your ORM models, get a full schema with queries, mutations, and a GraphiQL IDE. `POST /graphql` in one line.
    - icon: 📬
      title: Queues + Background Work
      details: File-backed by default, RabbitMQ/Kafka/MongoDB when you scale. Producer/consumer/dead-letter semantics consistent across languages. Periodic tasks via `background(fn, interval)`, no threads.
    - icon: 🛠️
      title: Dev Dashboard on /__dev
      details: Routes, requests, SQL runner, queue monitor, mailbox, WebSocket inspector, error tracker, AI chat, a shared SPA across all four frameworks. `TINA4_DEBUG=true` turns it on.
---

## What's new

**v3.13.39 (2026-06-21)** - [full notes](/python/36-releases.md)

Auto-run migrations on startup (`TINA4_AUTO_MIGRATE`), a unified first-class `critical` log level, fail-loud ORM contracts (`save`, `create`, and `QueryBuilder` stop swallowing errors), and per-route WebSocket authentication on the upgrade. Plus a uniform `TINA4_` env manifest, an `Api` client that strips auth headers on cross-origin redirects, and sharper `tina4 metrics` coverage detection. Breaking: `critical` is now a top-level severity, and on Node.js `TINA4_CORS_CREDENTIALS` now defaults to `false`.

**v3.13.38 (2026-06-19)** - Coordinated security and robustness release. The WebSocket and SSE backplane is wired for real with an origin allow-list and idle reaper, a SOAP DTD reject and a GraphQL depth guard close the XML and query-depth attack surfaces, `htmlElement` escapes child content, and the new `tina4 metrics` command reports the top code-health offenders.

**Highlights since v3.12.3** - the v3.13 line unified the cache backend (memory, file, redis, valkey, memcached, mongodb, database), gave queues a full lifecycle (priority pop, retry backoff, automatic dead-lettering), added a request-scoped query cache, shipped live dev tooling over WebSocket and the `/__dev/mcp` endpoint, hardened the ORM and database layer to fail loud, and ran a broad security pass. See the [full release notes](/python/36-releases.md) for every version.

## How Tina4 reads

Pick a language. Each book stands on its own: you can read Python cover-to-cover, then pick up the PHP book later and recognise every pattern.

- **[Understanding Tina4](/general/index.md)** - Architecture, philosophy, the four-language promise. Read this first if you want the why.
- **[Python](/python/index.md)** - The reference implementation. Every feature lands here first.
- **[Node.js](/nodejs/index.md)** - TypeScript-first, native `node:http`, file-based routing, ESM-only.
- **[PHP](/php/index.md)** - PHP 8.5, `stream_select` server, zero composer deps in core.
- **[Ruby](/ruby/index.md)** - Rack 3, Puma in production, WEBrick in dev.
- **[tina4-js](/js/index.md)** - The 1.5 KB reactive frontend. Signals, Web Components, router, API client, WebSocket, PWA, SSE.
- **[Delphi](/delphi/index.md)** - FireMonkey cross-platform, FireDAC, REST client, and Twig templates.

Every book has a printable PDF with a clickable table of contents. Every chapter stays in sync with the code: release notes, version numbers, and example output are regenerated with every point release.
