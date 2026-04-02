# Chapter 37: Complete Feature List

## 1. What Tina4 Covers

Tina4 is four implementations of the same framework: Python, PHP, Ruby, and Node.js. Every feature listed here ships in all four. The same behaviour. The same API shape. The same test expectations.

**9,311 tests across 280 files** verify parity. A feature that works in Python works identically in PHP, Ruby, and Node.js.

---

## 2. Foundations

| # | Feature | Description |
|---|---------|-------------|
| 01 | **Router** | Decorator-based routing with `@get`, `@post`, `@put`, `@patch`, `@delete` |
| 02 | **Request / Response** | Typed request object (params, body, headers, session) and fluent response builder |
| 03 | **Middleware** | Per-route and global middleware pipeline with named middleware registry |
| 04 | **Static Files** | Automatic serving of `src/public/` with configurable root |
| 05 | **Environment Config** | `.env` loading via `TINA4_*` prefix with type coercion and validation |
| 06 | **Dev Dashboard** | Built-in `/__dev` panel showing routes, logs, cache, queue, and request trace |
| 07 | **Hot Reload** | File watcher restarts the server on source change during development |

---

## 3. Templates

| # | Feature | Description |
|---|---------|-------------|
| 08 | **Frond Templates** | Tina4's own template engine: `{{ var }}`, `{% if %}`, `{% for %}`, partials, layouts |
| 09 | **Template Caching** | Compiled templates cached in memory; TTL configurable via `TINA4_TEMPLATE_CACHE_TTL` |
| 10 | **Asset Helpers** | `css()`, `js()`, `image()` helpers with cache-busting query strings |

---

## 4. Database

| # | Feature | Description |
|---|---------|-------------|
| 11 | **Database** | Raw SQL execution: `execute`, `fetch_one`, `fetch_all`, parameterised queries |
| 12 | **Multi-Database** | Multiple simultaneous connections; switch via `Database.use("secondary")` |
| 13 | **ORM** | Active record pattern: `save()`, `find()`, `find_all()`, `delete()`, soft deletes |
| 14 | **Query Builder** | Fluent query API: `select`, `where`, `join`, `order_by`, `limit`, `paginate` |
| 15 | **Migrations** | Version-controlled schema changes via `migrate up`, `migrate down`, auto-runner |
| 16 | **Transactions** | `db.begin()`, `db.commit()`, `db.rollback()` with context manager support |
| 17 | **Sequence / Next ID** | `Database.get_next_id(table)` — race-safe sequence via a dedicated sequence table |

---

## 5. Authentication and Security

| # | Feature | Description |
|---|---------|-------------|
| 18 | **Authentication** | JWT-based auth middleware; `@require_auth` decorator; token decode helpers |
| 19 | **Sessions** | Server-side sessions with cookie binding; memory, file, and Redis backends |
| 20 | **CSRF Protection** | Token generation, form injection, and validation middleware |
| 21 | **Rate Limiting** | Per-IP and per-route request limits via `RateLimit:n` middleware |
| 22 | **CORS** | Configurable origin, method, and header policy via `TINA4_CORS_*` env vars |
| 23 | **Security Headers** | Helmet-style middleware: CSP, X-Frame-Options, HSTS, Referrer-Policy |

---

## 6. Performance

| # | Feature | Description |
|---|---------|-------------|
| 24 | **Response Cache** | HTTP-level response caching via `ResponseCache:ttl` middleware |
| 25 | **Cache API** | `cache_get`, `cache_set`, `cache_delete`; memory, Redis, and file backends |
| 26 | **DB Query Cache** | Automatic caching of identical database queries; `TINA4_DB_CACHE=true` |
| 27 | **Compression** | Gzip/Brotli response compression via `Compress` middleware |

---

## 7. Background Processing

| # | Feature | Description |
|---|---------|-------------|
| 28 | **Queues** | Push/pop/consume pattern; file, RabbitMQ, Kafka, and MongoDB backends |
| 29 | **Job Lifecycle** | Pending → Reserved → Completed/Failed → Dead Letter; retry with `retry_failed()` |
| 30 | **Service Runner** | Long-running background services with start/stop lifecycle and thread management |

---

## 8. Events and Messaging

| # | Feature | Description |
|---|---------|-------------|
| 31 | **Events** | `emit` / `on` / `once` / `off`; priority ordering; async via `emit_async` |
| 32 | **Email (Messenger)** | SMTP email with HTML bodies, attachments, cc/bcc; dev interception mode |
| 33 | **WebSocket** | `@ws` route decorator; broadcast, rooms, ping/pong; `tina4-js` client library |

---

## 9. APIs

| # | Feature | Description |
|---|---------|-------------|
| 34 | **Swagger / OpenAPI** | Auto-generated OpenAPI 3.0 spec and Swagger UI at `/swagger` |
| 35 | **GraphQL** | Schema-first GraphQL with resolvers via `@graphql_query` and `@graphql_mutation` |
| 36 | **API Client** | Outbound HTTP: `Api.get/post/put/patch/delete`; auth headers, SSL, timeout |
| 37 | **WSDL / SOAP** | SOAP 1.1 service with `@wsdl_operation`; auto WSDL at `?wsdl` |

---

## 10. Tooling and Developer Experience

| # | Feature | Description |
|---|---------|-------------|
| 38 | **Scaffolding** | `tina4 new`, `tina4 make:route`, `tina4 make:model`, `tina4 make:migration` |
| 39 | **Testing** | Built-in test client with `client.get/post/put/delete`; fixture helpers |
| 40 | **Localization** | JSON locale files; `t()` function; `{placeholder}` interpolation; fallback chain |
| 41 | **Structured Logging** | `Log.info/debug/warning/error`; log levels; file output with rotation |
| 42 | **DI Container** | `Container.register` (transient) and `Container.singleton` (cached) |
| 43 | **Frontend (tina4-js)** | Sub-3KB reactive JS: signals, templating, routing, WebSocket client |
| 44 | **MCP Dev Tools** | Model Context Protocol integration: route inspection, ORM access, log streaming |

---

## 11. Cross-Language Parity

Every feature in the table above ships in all four Tina4 implementations:

| Implementation | Language | Package |
|----------------|----------|---------|
| tina4-python | Python 3.12+ | `pip install tina4-python` |
| tina4-php | PHP 8.2+ | `composer require tina4/tina4-php` |
| tina4-ruby | Ruby 3.3+ | `gem install tina4-ruby` |
| tina4-nodejs | Node.js 20+ | `npm install tina4-nodejs` |

**What parity means in practice:**

- A route defined in Python with `@get("/api/users")` works identically in PHP as `#[Get("/api/users")]`, in Ruby as `get "/api/users"`, and in Node as `router.get("/api/users")`.
- A Frond template written once renders correctly when served by any of the four implementations.
- A test written against the Python test client can be ported line-for-line to the PHP, Ruby, or Node equivalent with only syntax changes.
- `TINA4_*` environment variables are honoured by all four implementations with the same semantics.

---

## 12. Test Coverage Summary

| Metric | Value |
|--------|-------|
| Total tests | 9,311 |
| Test files | 280 |
| Cross-language parity tests | 44 feature × 4 implementations |
| Minimum coverage per feature | 100% (all four languages) |

Parity is enforced by the CI pipeline. A feature is not considered shipped until tests pass in all four languages. A bug fix must be applied to all four before it is closed.

---

## 13. What Is Not in Tina4

Tina4 is deliberately minimal:

- **No ORM magic / active record inflation**: Queries are explicit; the ORM maps rows to objects, it does not generate SQL automatically from relationships.
- **No dependency scanning**: The DI container is explicit. You register what you want, not what a scanner finds.
- **No bundled frontend framework**: `tina4-js` is a separate 3KB library you opt into. Tina4 itself is backend-only.
- **No cloud vendor lock-in**: Queues, cache, sessions, and email are backend-agnostic. The backend is a config variable.

The goal is a framework you can understand completely in a weekend and build on confidently for years.
