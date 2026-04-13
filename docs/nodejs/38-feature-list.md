# Chapter 37: Complete Feature List

This chapter catalogs all 45 features in Tina4 for Node.js, grouped by category. Use it as a reference when starting a project or auditing what you need.

---

## 1. Routing and HTTP

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 1 | **HTTP Routing** | `Router.get/post/put/delete/patch/all` | 2 |
| 2 | **Route Parameters** | `req.params.id`, `{id:int}`, `{slug}` | 2 |
| 3 | **Request & Response** | `req.body`, `req.query`, `res.json`, `res.render`, `res.status` | 3 |
| 4 | **Middleware** | Route-level string middleware, `"auth"`, `"ResponseCache:300"` | 10 |
| 5 | **Static Files** | Served from `public/` automatically | 1 |
| 6 | **CORS** | `TINA4_CORS_ORIGIN`, `TINA4_CORS_HEADERS` env vars | 10 |

---

## 2. Templating

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 7 | **Frond Templates** | `res.render("page.frond", data)` | 4 |
| 8 | **Template Variables** | `{{variable}}`, `{{nested.field}}` | 4 |
| 9 | **Template Includes** | `{{> partial.frond}}` | 4 |
| 10 | **Template Helpers** | `{{#if}}`, `{{#each}}`, `{{#unless}}` | 4 |

---

## 3. Database and ORM

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 11 | **Database Connection** | `Database.getConnection()`, `.env` config | 5 |
| 12 | **Raw Queries** | `db.fetchAll`, `db.fetchOne`, `db.execute` | 5 |
| 13 | **Named Parameters** | `:paramName` in SQL, bound from object | 5 |
| 14 | **ORM Models** | `class Product extends Model` | 6 |
| 15 | **ORM CRUD** | `Model.find`, `.save`, `.delete`, `.load` | 6 |
| 16 | **Query Builder** | `db.select().fromTable().where().limit().fetch()` | 7 |
| 17 | **Migrations** | Auto-migrations from model definitions | 5 |
| 18 | **Sequence / next_id** | `Database.get_next_id("table")` | 5 |
| 19 | **Multi-DB Support** | SQLite, PostgreSQL, MySQL, MSSQL | 5 |

---

## 4. Authentication and Sessions

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 20 | **JWT Authentication** | `auth` middleware, `req.user` | 8 |
| 21 | **Login / Logout** | `POST /api/login`, `POST /api/logout` | 8 |
| 22 | **Password Hashing** | `hashPassword`, `verifyPassword` | 8 |
| 23 | **Sessions** | `req.session.get/set`, file/Redis/DB backends | 9 |
| 24 | **Cookies** | `res.cookie`, `req.cookies`, signed cookies | 9 |
| 25 | **CSRF Protection** | `CSRF` middleware, `csrfToken` | 10 |

---

## 5. Background Processing

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 26 | **Queue System** | `Queue.push`, `.consume`, `.pop`, `.retry` | 12 |
| 27 | **Queue Backends** | File (default), RabbitMQ, Kafka, MongoDB | 12 |
| 28 | **Service Runner** | `Service`, `ServiceRunner` | 26 |
| 29 | **Scheduled Services** | `interval`, `runOnStart`, `restartDelay` | 26 |

---

## 6. Caching

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 30 | **Response Cache** | `"ResponseCache:300"` middleware | 11 |
| 31 | **Cache API** | `cacheGet`, `cacheSet`, `cacheDelete` | 11 |
| 32 | **Cache Backends** | Memory (default), Redis, file | 11 |
| 33 | **Cache Statistics** | `cacheStats()` | 11 |

---

## 7. Communication

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 34 | **Email (SMTP)** | `Messenger` class | 16 |
| 35 | **WebSocket** | `WebSocket` server, `ws.on`, `ws.send` | 23 |
| 36 | **Events System** | `Events.on`, `.emit`, `.once`, `.off`, `.clear` | 13 |
| 37 | **SSE / Streaming** | `response.stream(generator)` for Server-Sent Events | — |

---

## 8. Utilities and Services

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 38 | **Structured Logging** | `Log.info/debug/warn/error`, `TINA4_LOG_LEVEL` | 15 |
| 39 | **Localization** | `I18n`, JSON locale files, `t(key, vars)` | 14 |
| 40 | **API Client** | `api` singleton, `get/post/put/delete` | 21 |
| 41 | **DI Container** | `Container`, `register`, `singleton`, `get`, `has` | 25 |
| 42 | **WSDL / SOAP** | `WSDL.load`, `wsdl_operation`, SOAP server | 24 |
| 43 | **GraphQL** | Schema, resolvers, `Router.graphql` | 22 |

---

## 9. Developer Experience

| # | Feature | Class / Function | Chapter |
|---|---------|-----------------|---------|
| 44 | **Swagger / OpenAPI** | Auto-generated from JSDoc `@noauth`, `@path` | 20 |
| 45 | **Dev Dashboard** | `/__dev` — routes, queues, cache, logs | 29 |

---

## 2. Feature Details

### Routing and HTTP

**HTTP Routing** — Define routes with `Router.get("/path", handler)`. Handlers are async functions that receive `(req, res)`. Supports all HTTP methods. Routes are auto-loaded from `src/routes/`.

**Route Parameters** — Typed parameters in curly braces: `{id}` is a string, `{id:int}` is an integer, `{slug}` matches URL-safe strings. Parameters are available as `req.params.id`.

**Request and Response** — `req.body` is the parsed JSON request body. `req.query` holds query string values. `res.json(data)` sends JSON. `res.render("template.frond", data)` renders a template. `res.status(404).json({})` chains status and body.

**Middleware** — Applied as a string in the route definition: `Router.get("/path", handler, "auth,ResponseCache:300")`. Multiple middleware separated by commas. Custom middleware registered with `Router.middleware("name", fn)`.

**Static Files** — Everything in the `public/` directory is served automatically. `/public/logo.png` is available at `/logo.png`.

**CORS** — Set `TINA4_CORS_ORIGIN=*` (or a specific domain) and `TINA4_CORS_HEADERS` to control which headers are allowed. Preflight `OPTIONS` requests are handled automatically.

---

### Templating

**Frond Templates** — Tina4's built-in templating language. Files use the `.frond` extension. No separate template engine to install.

**Template Variables** — `{{variable}}` renders a string. `{{user.name}}` accesses nested properties. `{{price | currency}}` applies a filter.

**Template Includes** — `{{> header.frond}}` includes another template. Included templates share the same variable scope.

**Template Helpers** — `{{#if condition}}...{{/if}}` for conditionals. `{{#each items}}...{{/each}}` for loops. `{{#unless condition}}` for negation.

---

### Database and ORM

**Database Connection** — Configured via `.env`: `TINA4_DB_DSN`. Supports SQLite (`sqlite:./data/app.db`), PostgreSQL (`pgsql:host=...`), MySQL, and MSSQL. Accessed via `Database.getConnection()`.

**Raw Queries** — `db.fetchAll(sql, params)` returns an array of rows. `db.fetchOne(sql, params)` returns one row or null. `db.execute(sql, params)` runs a non-returning statement.

**Named Parameters** — Use `:name` in SQL. Pass values as `{ name: value }`. Never interpolate user input directly into SQL -- always use named parameters.

**ORM Models** — Extend `Model`, declare fields. Tina4 generates the table if it does not exist. `Product.find({ category: "Electronics" })` queries without SQL.

**Query Builder** — Chainable: `.select("name", "price").fromTable("products").where("active", true).orderBy("name").limit(20).fetch()`. Composes complex queries without raw SQL.

**Migrations** — Tina4 compares the model definition to the live table schema and adds missing columns on startup. No migration files needed for additive changes.

**Sequence / next_id** — `Database.get_next_id("invoices")` returns a race-safe, monotonically increasing ID using a sequence table. Safe for concurrent requests.

**Multi-DB Support** — Switch databases by changing `TINA4_DB_DSN`. Application code is unchanged.

---

### Authentication and Sessions

**JWT Authentication** — `POST /api/login` with `{ username, password }` returns a JWT. Include it as `Authorization: Bearer <token>`. Protected routes use the `"auth"` middleware string.

**Login and Logout** — Built-in login/logout routes. Customize by overriding the handlers. `POST /api/logout` invalidates the session.

**Password Hashing** — `hashPassword(plain)` returns a bcrypt hash. `verifyPassword(plain, hash)` validates. Never store plain passwords.

**Sessions** — `req.session.set("key", value)` and `req.session.get("key")`. Backend: file (default), Redis (`TINA4_SESSION_BACKEND=redis`), or database.

**Cookies** — `res.cookie("name", "value", { httpOnly: true, secure: true })` sets a cookie. `req.cookies.name` reads it.

**CSRF Protection** — The `CSRF` middleware validates a token on mutating requests. Include the token from `req.csrfToken()` in forms or AJAX calls.

---

### Background Processing

**Queue System** — `queue.push(payload)` enqueues a job. `queue.consume("topic")` is a generator that yields jobs. Call `job.complete()` or `job.fail()` after each.

**Queue Backends** — File-based by default (`TINA4_QUEUE_BACKEND=file`). Switch to RabbitMQ, Kafka, or MongoDB with one env var change. No code changes.

**Service Runner** — `ServiceRunner` manages multiple `Service` instances. Each runs its `run()` method on an interval. Crashes restart automatically.

**Scheduled Services** — Control timing with `interval` (ms), `runOnStart` (boolean), `restartDelay` (ms), and `maxRestarts`.

---

### Caching

**Response Cache** — `"ResponseCache:300"` as middleware caches the entire HTTP response for 300 seconds. Cache key includes the full URL with query parameters.

**Cache API** — `cacheSet(key, value, ttlSeconds)`, `cacheGet(key)`, `cacheDelete(key)`. Use for custom caching logic: cache-aside, write-through, event-based invalidation.

**Cache Backends** — Memory (default), Redis (`TINA4_CACHE_BACKEND=redis`), file (`TINA4_CACHE_BACKEND=file`). Backend is transparent to application code.

**Cache Statistics** — `cacheStats()` returns hits, misses, hit rate, entry count, and memory usage. Visible in the dev dashboard.

---

### Communication

**Email** — `Messenger` reads SMTP config from `.env`. `mailer.send({ to, subject, html, text })`. Attachments supported. Dev mode intercepts emails and shows them in the dashboard.

**WebSocket** — Real-time bidirectional communication. `Router.ws("/ws/chat", handler)`. `ws.on("message", fn)`, `ws.send(data)`, `ws.broadcast(data)`.

**Events System** — In-process publish/subscribe. `Events.on("event", handler, priority)`. `Events.emit("event", payload)`. `Events.once` for one-shot listeners. `Events.off` and `Events.clear` for cleanup.

---

### Utilities and Services

**Structured Logging** — `Log.info/debug/warn/error(message, context)`. Outputs JSON. Level controlled by `TINA4_LOG_LEVEL` env var. Context fields merged into every log entry.

**Localization** — `I18n` loads JSON locale files from `locales/`. `i18n.t("key", { variable: "value" })` with interpolation. Automatic fallback to default locale for missing keys.

**API Client** — `api` singleton from `@tina4/core`. `api.configure({ baseUrl, headers, timeout })`. Methods: `api.get`, `api.post`, `api.put`, `api.patch`, `api.delete`. Consistent response: `{ ok, status, data, error }`.

**DI Container** — `Container` with `register(name, factory)` (transient) and `singleton(name, factory)`. Resolve with `get<Type>(name)`. `has(name)` for existence checks. `reset()` for test cleanup.

**WSDL / SOAP** — Consume SOAP with `WSDL.load(url)` and `client.call(operation, params)`. Publish SOAP with `wsdl_operation` decorator and `WSDL` server class. Auto WSDL document generation.

**GraphQL** — Schema-first or code-first. Resolvers registered with `Router.graphql`. Introspection enabled in development. Playground available at `/graphql`.

---

### Developer Experience

**Swagger / OpenAPI** — Routes annotated with JSDoc comments generate an OpenAPI 3.0 spec automatically. Swagger UI available at `/swagger`. `@noauth` marks public endpoints. `@path`, `@query`, and `@body` document parameters.

**Dev Dashboard** — Available at `/__dev` in development mode. Shows: registered routes, active queue jobs, cache entries and hit rates, recent log output, registered services and their status, environment variable summary.

---

## 3. Environment Variables Reference

```bash
# Server
TINA4_PORT=7145
TINA4_ENV=development

# Database
TINA4_DB_DSN=sqlite:./data/app.db

# Cache
TINA4_CACHE_BACKEND=memory
TINA4_CACHE_HOST=localhost
TINA4_CACHE_PORT=6379

# Queue
TINA4_QUEUE_BACKEND=file
TINA4_QUEUE_PATH=./data/queue

# Session
TINA4_SESSION_BACKEND=file
TINA4_SESSION_SECRET=your-secret-here

# Email
TINA4_MAIL_SMTP_HOST=smtp.example.com
TINA4_MAIL_SMTP_PORT=587
TINA4_MAIL_SMTP_USERNAME=noreply@example.com
TINA4_MAIL_SMTP_PASSWORD=your-app-password
TINA4_MAIL_SMTP_ENCRYPTION=tls

# Auth
TINA4_JWT_SECRET=your-jwt-secret
TINA4_JWT_EXPIRY=86400

# Logging
TINA4_LOG_LEVEL=info

# CORS
TINA4_CORS_ORIGIN=*
TINA4_CORS_HEADERS=Content-Type,Authorization
```

---

## 4. Package Imports Reference

```typescript
// Core framework
import { Tina4, Router } from "tina4-nodejs";

// Database and ORM
import { Database } from "tina4-nodejs/orm";
import { Model } from "tina4-nodejs/orm";

// Auth
import { hashPassword, verifyPassword } from "tina4-nodejs";

// Cache
import { cacheGet, cacheSet, cacheDelete, cacheStats } from "tina4-nodejs";

// Queue
import { Queue } from "tina4-nodejs";

// Events
import { Events } from "tina4-nodejs";

// Logging
import { Log } from "tina4-nodejs";

// Localization
import { I18n } from "tina4-nodejs";

// Email
import { Messenger } from "tina4-nodejs";

// DI Container
import { Container } from "tina4-nodejs";

// Service Runner
import { Service, ServiceRunner } from "tina4-nodejs";

// WSDL / SOAP
import { WSDL, wsdl_operation } from "tina4-nodejs";

// API Client
import { api } from "@tina4/core";
```
