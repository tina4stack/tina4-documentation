---
# tina4press home layout (config: tina4press.config.mjs)
layout: home

hero:
  name: "Tina4"
  text: "Documentation"
  tagline: One framework, four languages, 140 features, zero runtime dependencies.
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


---

<link rel="stylesheet" href="/ask-hero.css">

<div class="tp-ask-hero">
  <form class="tp-ask-hero-form" role="search" autocomplete="off">
    <input class="tp-ask-hero-input" type="search" name="q" aria-label="Ask Tina4" placeholder="Ask Tina4: how do I define a route?">
    <button class="tp-ask-hero-go" type="submit">Ask Tina4</button>
  </form>
</div>

<div class="tp-ask-pills"></div>

<div class="tp-ask-answer" hidden></div>

<script src="/ask-hero.js" defer></script>

## Install

::: tabs
== macOS / Linux
```bash
curl -fsSL https://tina4.com/install.sh | sh
tina4 setup
```
== Windows
```powershell
irm https://tina4.com/install.ps1 | iex
tina4 setup
```
:::

::: tip Review your code with the Tina4 Code Viewer
A lightweight, read-only desktop reviewer that understands your Tina4 layout, lets you leave line-anchored comments grounded against the Tina4 RAG, and exports a portable bundle any AI agent can act on. It views and comments, it never edits your code. Signed builds for macOS, Windows, and Linux.

<a class="tp-cta" href="/download/code-viewer/">Download the Code Viewer →</a>
:::

## Current framework release: 3.13.138

Python, PHP, Ruby, and Node.js are aligned on 3.13.138. This release strengthens request and
template boundaries, corrects database and ORM behavior, isolates pooled transactions, and
updates the skills to estimate time from measured work. Package checksums, SPDX inventories,
and build provenance accompany the release. [Read the release notes](/python/36-releases.md).



## Your AI doesn't know Tina4 yet. Give it 30 seconds.

Copy this into Claude, Cursor, Copilot, or whatever you already have open. It reads the bootstrap protocol, installs what it needs, and hands you a running REST API with JWT auth. Same prompt, four languages.

::: tabs
== Python
```text
Read https://tina4.com/llms.txt and build me a REST API with a Todo model and JWT auth in Python.
```
== PHP
```text
Read https://tina4.com/llms.txt and build me a REST API with a Todo model and JWT auth in PHP.
```
== Ruby
```text
Read https://tina4.com/llms.txt and build me a REST API with a Todo model and JWT auth in Ruby.
```
== Node.js
```text
Read https://tina4.com/llms.txt and build me a REST API with a Todo model and JWT auth in Node.js.
```
:::

No signup, no plugin. [llms.txt](/llms.txt) is a bootstrap protocol written for machines: it tells your assistant to drive the `tina4` CLI, generate the scaffold, and use the built-ins instead of inventing them. That last part is why the output runs.

## What's new

**v3.13.138 (2026-09-24)** - Request and template hardening, exclusive database connection ownership, ORM and service fixes, measured-time skills, and verifiable release artifacts. [full notes](/python/36-releases.md)

[Full changelog](/python/36-releases.md)

## How Tina4 reads

Pick a language. Each book stands on its own: you can read Python cover-to-cover, then pick up the PHP book later and recognise every pattern.

- **[Understanding Tina4](/general/index.md)** - Architecture, philosophy, the four-language promise. Read this first if you want the why.
- **[Python](/python/index.md)** - The reference implementation. Every feature lands here first.
- **[Node.js](/nodejs/index.md)** - TypeScript-first, native `node:http`, file-based routing, ESM-only.
- **[PHP](/php/index.md)** - PHP 8.5, `stream_select` server, zero composer deps in core.
- **[Ruby](/ruby/index.md)** - its own HTTP server in dev and production; Puma if your app installs it.
- **[tina4-js](/js/index.md)** - The 1.5 KB reactive frontend. Signals, Web Components, router, API client, WebSocket, PWA, SSE.

Every book has a printable PDF with a clickable table of contents. Every chapter stays in sync with the code: release notes, version numbers, and example output are regenerated with every point release.

::: cards
== 🌐 Four Languages, One API
Python, Node.js, PHP, and Ruby share the same project structure, CLI, template syntax, route patterns, and .env variables. Learn one, know all four.
== 🧭 One CLI to Rule the Stack
The Rust-based `tina4` CLI detects the language, compiles SCSS, watches files, and delegates to the framework. `tina4 init`, `tina4 serve`, and `tina4 migrate` run the same across Python, PHP, Ruby, and Node.js.
== 📦 Zero Runtime Dependencies
Every Tina4 backend runs on the standard library. No native addons, no node-gyp, no vendor tree. Your requirements.txt / composer.json / Gemfile / package.json each hold one entry.
== 🛣️ Convention-Based Routing
Drop a file in `src/routes/`. The framework registers it. Typed path params (`{id:int}`, `{slug:slug}`, `{id:uuid}`) reject bad input with 404 before your handler runs.
== 🔌 Built-in WebSocket + SSE
Real-time bidirectional comms and server-sent events across all backends. Redis backplane for horizontal scaling. The same `WebSocketServer` API in every language.
== 🎨 Frond (Twig) Templating
One Twig-compatible engine. Variables, loops, template inheritance with `{{ parent() }}`, macros, filters. Write your layout once, render it in any language.
== 🗃️ Six Databases, One ORM
SQLite, PostgreSQL, MySQL, MSSQL, Firebird, MongoDB. `Database::create("sqlite:///app.db")` works anywhere. `sqlite:///path` is relative to your project root, the same convention across all four frameworks.
== 🔐 Secure by Default
GET routes are public, POST/PUT/PATCH/DELETE require a bearer token. JWT (HS256/RS256), PBKDF2 password hashing, rate limiting, CSRF form tokens, all built in, nothing to configure.
== 📋 Swagger at /swagger
Add an `@description` decorator to your route. Visit `/swagger`. Your API docs appear, typed, grouped, ready for your team.
== 🪢 GraphQL Included
Zero-dependency GraphQL engine. Point it at your ORM models, get a full schema with queries, mutations, and a GraphiQL IDE. `POST /graphql` in one line.
== 📬 Queues + Background Work
File-backed by default, RabbitMQ/Kafka/MongoDB when you scale. Producer/consumer/dead-letter semantics consistent across languages. Periodic tasks via `background(fn, interval)`, no threads.
== 🛠️ Dev Dashboard on /__dev
Routes, requests, SQL runner, queue monitor, mailbox, WebSocket inspector, error tracker, AI chat, a shared SPA across all four frameworks. `TINA4_DEBUG=true` turns it on.
:::
