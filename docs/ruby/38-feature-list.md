# Chapter 37: Complete Feature List

A reference of all 45 features in Tina4 Ruby, grouped by category.

---

## 1. Core Server

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 1 | HTTP Server | `Tina4::Server` | Zero-dependency HTTP server. Starts with `tina4 server` or `ruby app.rb`. |
| 2 | Routing | `Tina4::Router.get/post/put/patch/delete` | Declarative route definitions with path params, wildcards, and middleware. |
| 3 | Request Object | `request.body`, `request.params`, `request.headers`, `request.cookies` | Parsed inbound request. Handles JSON, form data, and multipart bodies. |
| 4 | Response Object | `response.json`, `response.html`, `response.render`, `response.redirect` | Structured response builder with status codes and headers. |
| 5 | Middleware | `middleware: ["Name:arg"]` | Per-route or global middleware pipeline. Built-in: `ResponseCache`, `RequestLogger`, `CORS`, `RateLimit`. |

---

## 2. Database

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 6 | Database Connection | `Tina4::Database.new(url)` | Single connection via `DATABASE_URL`. Supports SQLite, PostgreSQL, MySQL, MSSQL, Oracle. |
| 7 | Raw SQL | `db.query(sql)`, `db.execute(sql)` | Execute raw SQL. `query` returns rows. `execute` returns affected row count or last insert ID. |
| 8 | Query Builder | `Tina4::QueryBuilder` | Chainable `.where`, `.select`, `.order`, `.limit`, `.offset`, `.join`. |
| 9 | ORM | `Tina4::ORM` | ActiveRecord-style base class. `find`, `save`, `delete`, `all`, `where`. |
| 10 | Migrations | `Tina4::Migration` | Version-controlled schema changes. `tina4 migrate` applies pending migrations. |
| 11 | get_next_id | `Database.get_next_id(table)` | Race-safe sequence generator using a dedicated sequence table. |

---

## 3. Authentication and Sessions

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 12 | JWT Authentication | `Tina4::Auth` | Token-based auth. Protects routes by default. Bypass with `# @noauth` comment. |
| 13 | Session Management | `Tina4::Session` | Server-side sessions stored in file, memory, or database backends. |
| 14 | Cookie Handling | `request.cookies`, `response.set_cookie` | Read and write cookies with expiry, domain, secure, and HttpOnly flags. |

---

## 4. Templates and Frontend

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 15 | Frond Templates | `response.render("page.html", data)` | Tina4's zero-dependency template engine. `{variable}`, `{if}`, `{each}`, `{include}`. |
| 16 | Static Files | `public/` directory | Files in `public/` are served directly without a route. CSS, JS, images. |
| 17 | Frontend Integration | `tina4-js` | The companion 13.6KB reactive frontend library. Signals, components, routing. |

---

## 5. Caching

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 18 | Response Cache | `middleware: ["ResponseCache:ttl"]` | Caches complete HTTP responses. Memory or file backend. |
| 19 | Cache API | `Tina4::Cache.get/set/delete/flush` | Direct cache read/write with TTL. Backends: memory, file, Redis, Memcached. |
| 20 | Query Caching | `db.cache(ttl) { query }` | Caches database query results for a given TTL. |

---

## 6. Background Processing

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 21 | Queue System | `Tina4::Queue` | File-based queue by default. `push`, `pop`, `consume`, `retry`. Backends: file, RabbitMQ, Kafka, MongoDB. |
| 22 | Job Lifecycle | `job.complete`, `job.fail`, `job.retry` | Explicit job state transitions: PENDING → RESERVED → COMPLETED / FAILED / DEAD LETTER. |
| 23 | Service Runner | `Tina4::ServiceRunner` | Manages long-running background threads. Auto-restart on crash with exponential backoff. |

---

## 7. Events

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 24 | Event Bus | `Tina4::Events` | In-process synchronous event system. |
| 25 | Listener Registration | `Events.on(event, priority:)` | Register a listener block. Priority controls execution order. |
| 26 | One-Shot Listeners | `Events.once(event)` | Registers a listener that fires exactly once then removes itself. |
| 27 | Listener Removal | `Events.off(event, listener)`, `Events.clear` | Remove specific or all listeners. |

---

## 8. Localization

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 28 | I18n | `Tina4::I18n.new(locale:, path:)` | Loads JSON locale files. Dot-notation key lookup. |
| 29 | Translation | `i18n.t("key", field: value)` | Translates a key with `{placeholder}` interpolation. |
| 30 | Fallback Locale | `fallback: "en"` | Falls back to a default locale when a key is missing. |
| 31 | Locale Switching | `i18n.locale = "fr"` | Switch the active locale at runtime. |

---

## 9. Logging

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 32 | Structured Logger | `Tina4::Log.info/debug/warning/error/fatal` | Structured log entries with timestamp, level, message, and keyword fields. |
| 33 | Log Level Control | `TINA4_LOG_LEVEL` env var | Filter output by minimum severity. Values: debug, info, warning, error, fatal. |
| 34 | JSON Output | `TINA4_LOG_FORMAT=json` | Emit NDJSON for log aggregators (Datadog, Elastic, CloudWatch). |
| 35 | File Logging | `TINA4_LOG_FILE=path` | Write logs to a file in addition to stdout. |

---

## 10. API and Integrations

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 36 | API Client | `Tina4::Api.new(base_url, headers)` | HTTP client for calling external REST APIs. `get`, `post`, `put`, `delete`. |
| 37 | WSDL / SOAP Server | `Tina4::WSDL`, `wsdl_operation` | Define SOAP operations with auto-generated WSDL. |
| 38 | SOAP Client | `Tina4::WSDL::Client.new(wsdl_url)` | Call remote SOAP services by parsing their WSDL. |
| 39 | GraphQL | `Tina4::GraphQL` | Schema-first GraphQL endpoint. Types, queries, mutations, subscriptions. |
| 40 | WebSocket | `Tina4::WebSocket` | Real-time bidirectional communication. `on_message`, `broadcast`, `rooms`. |
| 41 | SSE / Streaming | `response.stream` | Server-Sent Events for real-time data push via `response.stream(generator)`. |

---

## 11. Developer Tools

| # | Feature | Class / Method | Description |
|---|---------|---------------|-------------|
| 42 | Swagger / OpenAPI | `Tina4::Swagger` | Auto-generates OpenAPI 3.0 docs from route comments. `/swagger` serves the UI. |
| 43 | DI Container | `Tina4::Container` | Register, resolve, and replace services. `registered?`, `clear!`. |
| 44 | CLI | `tina4` command | `new`, `server`, `migrate`, `scaffold`, `routes`, `version`. |
| 45 | MCP Dev Tools | `Tina4::MCP` | Model Context Protocol server for AI assistant integration. |

---

## Feature Summary by Version

| Version | Features Added |
|---------|---------------|
| 3.0.0 | Core server, routing, request/response, templates, database, ORM, auth, sessions |
| 3.1.0 | Queue system, caching, middleware pipeline |
| 3.5.0 | GraphQL, WebSocket, Swagger |
| 3.8.0 | Service Runner, Events, MCP dev tools |
| 3.10.0 | API client, WSDL/SOAP, DI container |
| 3.10.20 | get_next_id, race-safe sequences |
| 3.11.0 | Localization, structured logging, log level control |

---

## Quick Reference: Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | — | Database connection string |
| `TINA4_ENV` | `development` | Environment: development, production, test |
| `TINA4_PORT` | `7147` | HTTP server port |
| `TINA4_LOG_LEVEL` | `info` | Minimum log level |
| `TINA4_LOG_FORMAT` | `text` | Log format: text or json |
| `TINA4_LOG_FILE` | — | Log file path (optional) |
| `TINA4_QUEUE_BACKEND` | `file` | Queue backend: file, rabbitmq, kafka, mongodb |
| `TINA4_QUEUE_PATH` | `./queue` | File queue storage directory |
| `TINA4_QUEUE_URL` | — | Queue broker URL (RabbitMQ, Kafka, MongoDB) |
| `TINA4_CACHE_BACKEND` | `memory` | Cache backend: memory, file, redis, memcached |
| `TINA4_SECRET_KEY` | — | JWT signing secret |
| `TINA4_TOKEN_EXPIRY` | `3600` | JWT expiry in seconds |
