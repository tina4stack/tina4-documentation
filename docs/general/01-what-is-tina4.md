# Chapter 1: What Is Tina4?

## The "Not a Framework" Philosophy

You install a framework. It pulls 70 packages. It creates 14 configuration files. It generates a folder structure that looks like an architect had a breakdown. Twenty minutes later, you still haven't written a line of your own code.

Tina4 is a toolkit. One package. One folder structure. Zero configuration files beyond a `.env`. You write your code, drop it in the right folder, and the framework discovers it.

Here is a complete API endpoint in Tina4:

```php
<?php
// src/routes/greeting.php

Router::get("/api/greeting/{name}", function ($request, $response) {
    return $response->json([
        "message" => "Hello, " . $request->params["name"]
    ]);
});
```

No base controller. No service provider. No bootstrapping ritual. Drop that file into `src/routes/`, start the server, and it works.

The philosophy fits in one sentence: **you write code, Tina4 stays out of the way.**

Routes go in `src/routes/`. Templates go in `src/templates/`. Models go in `src/orm/`. Learn the convention once. Never think about it again.

This is not laziness. This is a decade of watching developers waste entire afternoons on configuration files, dependency conflicts, and framework upgrades that break everything. Tina4 was born from that frustration.

---

## Why Zero Dependencies Matters

Tina4 v3 has **zero third-party dependencies** for its core features. The template engine, the JWT library, the SCSS compiler, the queue system, the GraphQL parser, the logger, the rate limiter — every piece is built from scratch using the language's standard library.

This is not showing off. It is a survival strategy.

### Security

Every dependency is an attack surface. When a package in your dependency tree gets compromised — and it will, ask the teams who trusted `event-stream`, `colors.js`, or `ua-parser-js` — your application is exposed.

Tina4's attack surface is the language runtime and your code. Nothing else sits between you and your users.

### Size

A Laravel installation pulls in 70+ packages. A Rails app starts with 40+ gems. A Next.js project's `node_modules` folder is measured in hundreds of megabytes.

Tina4 installs **one package**. The framework runs to roughly **~26,000 lines of code** per language (Python ~26,000 | PHP ~35,000 | Ruby ~24,000 | Node.js ~32,000), all of it standard-library code you can read and audit. The Docker image fits in **40-80MB**. Your production container ships with what it needs. Nothing else tags along.

### Portability

Zero dependencies means zero compatibility conflicts. You will never see this with Tina4:

```
Your requirements could not be resolved to an installable set of packages.
  Problem 1
    - package-a v2.1 requires other-package ^3.0
    - package-b v1.4 requires other-package ^2.0
```

No diamond dependency problem. No dependency tree to untangle. No Friday afternoon emergency because a transitive dependency released a breaking change.

### Upgrades

Upgrading Tina4 means upgrading one package. No cascade of breaking changes. The framework team controls every line, so when something breaks, the fix lives in one place.

### The One Exception

Database drivers are the exception. You cannot talk to PostgreSQL without a PostgreSQL driver. These are native connectors to external systems. They are optional — install only what you need. SQLite works out of the box with every language's standard library.

---

## 44 Features at 100% Parity

Tina4 ships with everything you need to build a production web application. 44 features, all implemented identically across Python, PHP, Ruby, and Node.js. 9,311 tests across 280 test files. Here is what every installation includes:

**Core Web (17)**
- HTTP router with path parameters, typed params, wildcard routes, route groups
- Request and Response objects with full HTTP access
- Static file serving, CORS (proper origin matching), rate limiting, health checks
- Security headers middleware (CSP, HSTS, X-Frame-Options, Referrer-Policy)
- noauth/secured decorators, auth guards on write routes by default
- Graceful shutdown, request ID tracking, structured logging
- --production flag, TINA4_NO_BROWSER, TINA4_NO_RELOAD
- Auto test port at port+1000 (stable for user testing, no hot-reload)

**Data Layer (14)**
- SQL-first ORM with Active Record pattern, field types, soft delete
- Seven database drivers: SQLite, PostgreSQL, MySQL, MSSQL, Firebird, MongoDB, ODBC
- Relationships: hasOne, hasMany, belongsTo with eager loading (declarative + imperative)
- QueryBuilder with fluent API, toMongo() for NoSQL query generation
- AutoCRUD: REST endpoints from ORM models (GET, POST, PUT, DELETE with pagination)
- Migrations with rollback, seeders with 50+ fake data generators
- Connection pooling, query result caching with TTL, race-safe ID generation
- DATABASE_URL auto-discovery, autoMap for Firebird/Oracle uppercase columns
- Cross-engine SQL translation (LIMIT, OFFSET, RETURNING, boolean, ILIKE)

**Template Engine — Frond (14)**
- Twig-compatible syntax with 55+ filters, custom filters/globals/tests
- Template inheritance (extends/block), parent()/super(), includes, macros
- Import-as syntax, fragment caching, sandbox mode, SafeString
- SCSS compiler (zero-dep), tina4css (built-in CSS framework), frond.js
- Pre-compilation for 2.8x render improvement, dev mode cache bypass

**Auth and Sessions (8)**
- JWT (HS256/RS256) built from scratch, password hashing
- Five session backends: file, database, Redis, Valkey, MongoDB
- Session TTL and garbage collection, SameSite cookie control
- CSRF middleware with form tokens, API key authentication

**Integration (8)**
- Queue system with retry, dead letters, and four backends (file, RabbitMQ, Kafka, MongoDB)
- GraphQL parser and executor with ORM auto-generation
- WebSocket server with Redis pub/sub backplane for horizontal scaling
- SOAP/WSDL support, HTTP API client, email messenger (SMTP/IMAP), i18n

**Infrastructure (12)**
- Events system (observer pattern with priority and one-shot listeners)
- DI container with transient and singleton registration
- Response cache middleware with TTL
- Service runner, error overlay with syntax-highlighted stack traces
- HtmlElement programmatic HTML builder
- Inline testing framework (attach assertions to functions)
- MCP server (JSON-RPC 2.0 dev tools, auto-start in debug mode)

**Developer Experience (9)**
- Rust-based unified CLI: init, serve, doctor, docs, books, generate, migrate, test, ai
- Dev admin dashboard with database tab, metrics bubble chart, request inspector
- Code metrics: complexity, maintainability index, coupling analysis, dependency graph
- Interactive gallery with 7 deployable examples, dev mailbox for email capture
- Live reload with file watcher, AI tool context scaffolding (7 tools supported)

**CLI Tools (5)**
- tina4 init (scaffold for Python, PHP, Ruby, Node.js, tina4js)
- tina4 doctor (environment check, port scan, CLI detection)
- tina4 docs (framework-specific book chapters to .tina4-docs/)
- tina4 generate (model, route, migration, middleware, crud, test, form, view, auth)
- tina4 update (self-update with prebuilt binaries for macOS, Linux, Windows)

**Static Assets (3)**
- Minified CSS (tina4.min.css), JS (tina4.min.js, frond.min.js)
- HtmlElement builder for programmatic HTML generation
- Scaffold copies framework assets into project on init

---

## Convention Over Configuration

Tina4 projects follow a predictable structure. Run `tina4 init` and you get:

```
my-project/
├── .env                    # Configuration
├── src/
│   ├── routes/             # Route handlers (auto-discovered)
│   ├── orm/                # ORM models (auto-discovered)
│   ├── templates/          # Frond templates
│   ├── public/             # Static files (served directly)
│   │   ├── css/
│   │   ├── js/
│   │   └── images/
│   └── scss/               # SCSS source files (auto-compiled)
├── migrations/             # SQL migration files
├── data/                   # SQLite databases (gitignored)
├── logs/                   # Log files with rotation (gitignored)
└── tests/                  # Test files
```

Five rules. No exceptions:

1. **Routes** go in `src/routes/`. Name the files however you want. Tina4 reads the route definitions inside them.
2. **Models** go in `src/orm/`. Same auto-discovery.
3. **Templates** go in `src/templates/`. Call `response.render("products/list.twig", data)` and Tina4 finds it.
4. **Static files** go in `src/public/`. A file at `src/public/css/style.css` serves at `/css/style.css`.
5. **Configuration** goes in `.env`. One file. Key-value pairs. No YAML. No TOML. No JSON config.

No routing table to maintain. No service container to wire up. No middleware stack to arrange in the right order. Drop files in the right directories. They work.

---

## The Four-Language Paradigm

Tina4 is not one framework. It is four:

- **tina4-python** — Python 3.12+
- **tina4-php** — PHP 8.2+
- **tina4-ruby** — Ruby 3.1+
- **tina4-nodejs** — Node.js 20+ (TypeScript)

All four share the same project structure, the same `.env` variables, the same template syntax, the same CLI commands, and the same API contracts.

The only difference is naming convention:

| Concept | Python / Ruby | PHP / Node.js |
|---------|--------------|---------------|
| Method names | `snake_case` | `camelCase` |
| Fetch one row | `fetch_one()` | `fetchOne()` |
| Soft delete | `soft_delete()` | `softDelete()` |

A team can prototype in Python and deploy in PHP without relearning the framework. Frontend developers using frond.js never need to know which backend language is running. DevOps deploys the same Docker structure, the same `.env`, the same health checks — regardless of language.

One Rust-based CLI binary auto-detects the project language and dispatches to the correct runtime:

```bash
tina4 init python ./my-app    # Scaffold a Python project
tina4 serve                   # Start dev server
tina4 generate model User     # Generate an ORM model
tina4 migrate                 # Run pending migrations
tina4 test                    # Run the test suite
```

---

## What Tina4 Is Not

Tina4 does not replace Laravel, Django, Rails, or Next.js. Those are excellent frameworks for teams that want a full-stack opinion on everything.

Tina4 is for developers who want:

- **Control** — you see every line of code that runs your application
- **Simplicity** — one package, one import, predictable behaviour
- **Speed** — sub-millisecond framework overhead
- **Portability** — switch languages without switching paradigms
- **Security** — no supply chain risk from transitive dependencies

If you want a batteries-included platform with an ecosystem of plugins and a marketplace of themes, Tina4 is the wrong tool. If you want a sharp, minimal toolkit that does what you tell it and nothing else — keep reading.

The code you don't write is the code that never breaks.

---

## Summary

| Aspect | Tina4 |
|--------|-------|
| Philosophy | Toolkit, not a cathedral |
| Dependencies | Zero (core features) |
| Framework size | ~26,000 lines per language (avg) |
| Languages | Python, PHP, Ruby, Node.js |
| Configuration | `.env` file only |
| Discovery | Automatic (routes, models, templates) |
| CLI | Unified Rust binary |
| Tests | 9,311 across all four frameworks |
| Features | 44 at 100% parity |
