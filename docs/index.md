---
# tina4press home layout (config: tina4press.config.mjs)
layout: home

hero:
  name: "Tina4"
  text: "Documentation"
  tagline: One framework, four languages, 138 features, zero runtime dependencies.
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


---

<link rel="stylesheet" href="/ask-hero.css">

<div class="tp-ask-hero">
  <form class="tp-ask-hero-form" role="search" autocomplete="off">
    <input class="tp-ask-hero-input" type="search" name="q" aria-label="Ask Tina4" placeholder="Ask Tina4: how do I define a route?">
    <button class="tp-ask-hero-go" type="submit">Ask Tina4</button>
  </form>
  <a class="tp-cta tp-ask-hero-cta" href="https://profile.tina4.com">Register Now</a>
</div>

<div class="tp-ask-pills"></div>

<div class="tp-ask-answer" hidden></div>

<script src="/ask-hero.js" defer></script>

## Current framework release: 3.13.113

Python, PHP, Ruby, and Node.js are aligned on 3.13.113. AI streaming got typed:
`Ai.chat(stream=true)` now yields a discriminated `AiEvent` union
(`text_delta`, `tool_call`, `done`, `error`) instead of raw strings, so an
agent loop can see tool calls and finish reasons. Tool calls arrive whole
(the client buffers argument fragments across deltas and emits one aggregated
event when the JSON parses), text still streams per chunk for typewriter UX,
and mid-stream failure surfaces as one `error` event that replaces `done`.
`message.content` accepts multimodal parts (`{type:'text',text}` and
`{type:'image', source}`) with providers getting their native shape internally.
Three new `Api.stream_bytes` / `stream_lines` / `stream_sse` primitives replace
the hand-rolled HTTP-streaming boilerplate every consumer used to write;
`Ai.chat` streaming rides on `Api.stream_sse` per language. **Breaking** for
callers of `Ai.chat(stream=true)`; non-streaming callers are unaffected.
Feature 140 / ADR-0060.

[Read the release notes](/python/36-releases.md)

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

## Install and register

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

::: tip Save your paid tokens for the hard parts
Let Tina4's own AI coder handle the boilerplate. Register for a free profile to get started.

<a class="tp-cta" href="https://profile.tina4.com">Register Now →</a>
:::

::: tip Review your code with the Tina4 Code Viewer
A lightweight, read-only desktop reviewer that understands your Tina4 layout, lets you leave line-anchored comments grounded against the Tina4 RAG, and exports a portable bundle any AI agent can act on. It views and comments, it never edits your code. Signed builds for macOS, Windows, and Linux.

<a class="tp-cta" href="/download/code-viewer/">Download the Code Viewer →</a>
:::

## What's new

**v3.13.113 (2026-08-22)** - [full notes](/python/36-releases.md)

AI streaming got typed. `Ai.chat(stream=true)` yields a discriminated `AiEvent` union (`text_delta`, `tool_call`, `done`, `error`) instead of raw strings. Tool calls arrive whole (client buffers argument fragments across deltas and emits one aggregated event when the JSON parses), text still streams per chunk, and mid-stream failure surfaces as one `error` event that replaces `done`. `message.content` accepts multimodal parts (`{type:'text',text}` and `{type:'image', source}`) with providers getting their native shape internally. Three new `Api.stream_bytes` / `stream_lines` / `stream_sse` primitives replace the hand-rolled HTTP-streaming boilerplate every consumer used to write; `Ai.chat` streaming is implemented on top of `Api.stream_sse` per language, one SSE reader serves both consumers. Contract fixture at parity across all four backends. **Breaking** for `Ai.chat(stream=true)` callers; migrate `for chunk in stream:` to `for event in stream: if event.type == "text_delta": ...`. Non-streaming callers unaffected. Feature 140 / ADR-0060.

**v3.13.112 (2026-08-22)** - [full notes](/python/36-releases.md)

CSP-clean dev toolbar, at parity across Python, PHP, Ruby, and Node. The toolbar's CSS and JS move out of the injected HTML into external `/__dev/toolbar.css` and `/__dev/toolbar.js` routes, every event is wired with `addEventListener`, and the live reloader is gated on a `data-reload` attribute (suppressed on the AI port). So the injected toolbar renders styled and functional under the framework's default `default-src 'self'` CSP, instead of rendering unstyled with the console full of CSP violations. A shared contract invariant locks the no-inline property in all four. Issue #115.

**v3.13.111 (2026-08-21)** - [full notes](/python/36-releases.md)

Graph database layer, at parity across all four frameworks and proven live on Ultipa, Neo4j, Memgraph, and ArangoDB. `GraphDatabase.create(url)` and `fromEnv()` pick the engine from the URL scheme, and one portable surface (`add_node`, `add_edge`, `get_node`, `update_node`, `delete_node`, `neighbors`, `traverse`) works identically on every engine, with `query` and `execute` passing native GQL, Cypher, or AQL straight through. Neutral `GraphNode`, `GraphEdge`, and `GraphResult` shapes, modelled exactly on the relational Database layer. The engine driver is an optional, lazy-loaded dependency, so the core stays zero-dependency. Feature 139 / ADR-0059.

**v3.13.110 (2026-08-21)** - [full notes](/python/36-releases.md)

Skills release. The Tina4 skills that teach an AI assistant the framework are pinned to the release, so an assistant fetches the version that matches the framework you run.

**v3.13.109 (2026-08-20)** - [full notes](/python/36-releases.md)

Security, at parity: the response cache never serves one session's authenticated response to another caller. The isolation fix shipped for Python in 3.13.108 and lands here for PHP, Ruby, and Node.

**v3.13.108 (2026-08-20)** - [full notes](/python/36-releases.md)

Three fixes. The response cache keys on the session so it cannot replay one caller's response to another (#117). The database connect timeout compares against the driver's own monotonic clock, so a slow connect times out cleanly instead of hanging or firing early (#119). A class-based service's `stop` hook runs on shutdown (#118).

**v3.13.107 (2026-08-20)** - [full notes](/python/36-releases.md)

RBAC: role and permission guards, at parity across Python, PHP, Ruby, and Node. `role("admin")` and `can("posts.delete")` read the cryptographically verified `roles` and `permissions` claims from the signed token: several names in one guard are OR, stacking or chaining guards is AND, and granted permissions may carry a wildcard on the dot boundary (`posts.*` satisfies `posts.delete`, a bare `*` satisfies everything) while the required side stays concrete. A guarded route implies auth: no or invalid token returns 401, an authenticated caller missing the role or permission returns 403, and the handler never runs on a miss. Roles and permissions are independent signed claims - the core never expands a role into permissions, and a legacy singular `role` claim is coerced to a list. Feature 138 / ADR-0058.

**v3.13.106 (2026-08-20)** - [full notes](/python/36-releases.md)

`@websocket` is callable from the package name. `from tina4_python import websocket` no longer raises `TypeError: 'module' object is not callable`, so auto-discovery stops dropping the rest of that route file. Python-only: the import-machinery collision has no equivalent in PHP, Ruby, or Node, which keep the shared version bump unchanged.

**v3.13.105 (2026-08-19)** - [full notes](/python/36-releases.md)

Cross-API invariants, honest logs, portable tests. Five queue and ORM audit bugs closed in the seams where two spellings of the same intent quietly disagreed: `Model.clear_cache()` now cascades to the DB layer under `TINA4_DB_CACHE=true`, `Queue.retry()` revives every dead letter (no more `any()` short-circuit), `Job.retry()` unlinks the dead-letter file, and MongoDB's `retry_job(id)` + `purge(status)` actually find and count what they claim. Route inspection stops booting the app. `@noauth()` / `@secured()` emit a corrective startup log so the log stops lying. Hot reload reaches every module that captured a changed one. Firebird's migration ledger tolerates any case the driver hands back. And every framework developer skill gained a spine: it announces every step before taking it, and it warns with 💩 when a newer skill is published.

**v3.13.104 (2026-08-17)** - [full notes](/python/36-releases.md)

GIS points now store longitude-first coordinates in PostGIS, build GiST
indexes, calculate distances in metres, and return GeoJSON. Configuration-first
SSO adds OpenID Connect discovery, Authorization Code with PKCE, Session
handoff, refresh, logout, secured-route identity, and Swagger integration. The
runtime stays provider-neutral. The documentation includes Keycloak as an
implementation example, not as a framework requirement. No runtime package
dependency was added.

**v3.13.103 (2026-08-16)** - [full notes](/python/36-releases.md)

Metrics you can trust, and releases that cannot lie. Version 3.13.102 was a skills-only release, so framework runtime packages correctly remained at 3.13.101. Version 3.13.103 is the next framework release. Dev-admin now hands code-health analysis to the signed Tina4 client, `has_referencing_test` means exactly that a test refers to the source file, and framework release workflows reject tags that disagree with package versions. Tina4 skills lead with `tina4 init` and `tina4 serve`. No runtime packages were added; language extensions remain extensions, not dependencies.

**v3.13.101 (2026-08-14)** - [full notes](/python/36-releases.md)

One AI client across all four backends. Applications can call local models, OpenAI, and Anthropic through the same three operations: chat, complete, and embed. Streaming returns ordered text deltas; timeouts and retries are bounded; failures do not expose keys, prompts, or provider response bodies. The client uses each language's built-in HTTP support, so it adds no runtime package dependency. This release also moves code-health analysis fully into the native `tina4 metrics` command while the dev dashboard consumes its JSON output.

**v3.13.100 (2026-08-14)** - [full notes](/python/36-releases.md)

Frond keeps the whole page. A second `{% extends %}` now fails with a clear error, nested root blocks keep their content, and Ruby resolves multi-level inheritance without recursing through the same child. Bounded template, fragment, and expression caches stop long-running workers from collecting stale entries. Skill downloads retry transient failures, and release-version guards now keep every package and guide on the same number.

**v3.13.99 (2026-08-13)** - [full notes](/python/36-releases.md)

Stability, parity, and secure by default. About thirty breaking changes, and every one is a security, parity, or correctness fix: security headers and CSP on by default, CSRF actually enforced, the dev server bound to `127.0.0.1`, Mongo's mass-delete footgun closed, and `request.params` now holding route params only instead of merging in client input. Two conformance grids, logging and database adapters, are fully proven against real services in all four frameworks. See "Possible breaking" in the full notes before you upgrade.

**v3.13.98 (2026-08-11)** - [full notes](/python/36-releases.md)

A maintenance release, no app behaviour changed. The bundled AI coding skills moved onto one shared plan discipline (one plan format; a checkbox ticks only on verified-green work, never on a claim), and the framework shed internal dead code (duplicate design-system source that was never compiled or served). Re-run `tina4.com/install-skills.sh` for the skills.

**v3.13.97 (2026-08-07)** - [full notes](/python/36-releases.md)

Behaviour corrections. Force-delete no longer throws instead of deleting the row. Queue `clear()` and `purge()` on a broker refuse by name instead of a silent no-op or draining the live queue. Session `destroy()` no longer lets a later write resurrect the session, and `flash(key, null)` reads instead of storing null. DocStore `distinct()` dedups dates by value. A small, safe bug-fix release on the road to 3.14 stable.

**v3.13.96 (2026-08-07)** - [full notes](/python/36-releases.md)

One paginate envelope, one message shape. Pagination returns a single seven-key envelope with a true total, and the AutoCrud REST list matches it. The Messenger IMAP path returns one message shape, addresses mail by a real IMAP UID, and hands back attachments you can write straight to disk. `Api.send()` becomes `Api.send_request()`. Swagger advertises `/` and only the response codes the framework really returns. The framework SCSS compilers are gone; the Rust CLI owns SCSS.

**v3.13.95 (2026-08-06)** - [full notes](/python/36-releases.md)

Parity: the same call now means the same thing in Python, PHP, Ruby and Node. Queues moved to one layout, so a job written by one framework is where the others look for it, and queue operations act on the backend you configured rather than a local file store. Logging settled on one format, one file layout and one input contract, with an explicit argument beating the environment everywhere. Every database connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT`, so an unreachable host fails instead of hanging forever. An unknown connection scheme or session backend now raises at startup instead of quietly falling back to SQLite or to local disk. PHP gained a choice of production runtime through `tina4 deploy docker --runtime cli|fpm|swoole`, and a working Swoole integration. See the "Possible breaking" section in the full notes: method shapes and inputs did not change, so only an app relying on the previous wrong result is affected.

**v3.13.57 - v3.13.94** - [full notes](/python/36-releases.md)

Thirty-eight releases of hardening between the entry above and the one below: write-path safety (a write with no filter is an error, not a full-table operation), the `DatabaseResult` contract on insert, update and delete, HS512 token verification, a race-safe `get_next_id()`, Frond expression parity across all four, and a test suite moved onto live services with no mocks.

**v3.13.56 (2026-07-08)** - [full notes](/python/36-releases.md)

The AI skills now tell your assistant how to report themselves when they drift. Every skill, and every project context file the installer writes (CLAUDE.md, .cursorules, copilot-instructions, and the rest), carries one line: if Tina4 behaves differently from the skill, that is a bug in the skill, so tell the developer and report it at [tina4.com/report-a-skill](/report-a-skill). This release also corrects the skills themselves (ORM soft-delete now names the real `is_deleted` column, the tina4-js persistence reference ships with the skill, and the per-framework copies are back in sync). The framework runtime is unchanged; refresh your skills with `curl -fsSL https://tina4.com/install-skills.sh | sh`.

**v3.13.55 (2026-07-07)** - [full notes](/python/36-releases.md)

The `tina4_migration` bookkeeping table now uses one schema on every framework and every engine: an auto-increment `id`, a unique `migration_name`, a `description`, a `batch`, an `executed_at` timestamp, and a `passed` flag. The auto-increment and column types follow the engine (`AUTOINCREMENT` on SQLite, `SERIAL` on PostgreSQL, `AUTO_INCREMENT` on MySQL, `IDENTITY(1,1)` on SQL Server, a generator on Firebird). Existing installs upgrade in place: the runner adds `migration_name`, copies the old name column across (`migration_id` in Python, `migration` in PHP, `name` in Node; Ruby already matched), and no already-applied migration re-runs. Shipped across all four frameworks.

**v3.13.54 (2026-07-07)** - [full notes](/python/36-releases.md)

Migrations now honour the Firebird `SET TERM` directive. A trigger or stored procedure whose body ends its inner statements with a semicolon used to split apart on that punctuation and fail; wrapping it in `SET TERM` switches the active terminator so the whole block travels as one statement, and the directive itself never reaches the engine. PHP and Ruby also repair the Firebird v2 to v3 migration-tracking upgrade, which read column names in the wrong case and re-ran every applied migration. Shipped across all four frameworks.

**v3.13.53 (2026-07-06)** - A model field can now hold a JSON document. Declare it (`JSONField` in Python, an `array`-typed property in PHP, `json_field` in Ruby, `{ type: "json" }` in Node) and the ORM stores an object or array in a JSON column: JSONB on PostgreSQL, JSON on MySQL, NVARCHAR(MAX) on SQL Server, a text BLOB on Firebird, and TEXT on SQLite. It encodes to JSON on write and decodes back to native data on read, so the attribute is never a raw string, and a value that cannot be encoded makes `save()` fail loud instead of writing a half-formed row.

**Recent releases (v3.13.40 - v3.13.52)** - Frond gained live blocks (`{% live %}` regions that render on the server and refresh over polling, Server-Sent Events, or a WebSocket you own); `pgsql://` returned as a PostgreSQL connection scheme; the built-in SCSS compiler learned the colour functions (`rgba(#hex, a)`, `rgb()`, `mix()`, `lighten()`, `darken()`); the dev MCP server moved to the current Streamable HTTP transport over a single `/__dev/mcp` endpoint, with the legacy HTTP+SSE handshake kept for older clients; Swagger gained per-route security and reusable component schemas; queues were unified on one lifecycle across all four frameworks, with a reservation and visibility timeout so a dead consumer never strands a job; the test suite moved onto real services (no mocks) and caught a batch of live database, broker, and Firebird bugs; and i18n was hardened with partial interpolation that never throws.

**Highlights since v3.12.3** - the v3.13 line unified the cache backend (memory, file, redis, valkey, memcached, mongodb, database), gave queues a full lifecycle (priority pop, retry backoff, automatic dead-lettering), added a request-scoped query cache, shipped live dev tooling over WebSocket and a Streamable HTTP `/__dev/mcp` endpoint, hardened the ORM and database layer to fail loud, and ran a broad security pass. See the [full release notes](/python/36-releases.md) for every version.

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
