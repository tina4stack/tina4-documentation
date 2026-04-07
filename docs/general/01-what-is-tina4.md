# Chapter 1: What Is Tina4?

## The AI Framework Philosophy

**TINA4 — The Intelligent Native Application 4ramework.**

Four words. Each one carries weight.

**Intelligent.** The framework understands AI. Every project ships with a CLAUDE.md file that gives AI assistants complete knowledge of the framework's conventions, API, and structure. Your AI writes correct code on the first try because the framework told it how.

**Native.** Zero third-party dependencies. Every feature — the template engine, the JWT library, the SCSS compiler, the queue system, the GraphQL parser — is built from scratch using the language's standard library. No supply chain risk. No version conflicts. No surprises.

**Application.** This builds real production applications. Routing, ORM, authentication, queues, WebSocket, email, GraphQL, SOAP — 44 features, all included. One package. One install. Ship today.

**4ramework.** Four languages. One API. Python, PHP, Ruby, Node.js — learn the conventions once, build in any of them. The "4" is both the number and "for" — a framework *for* developers who value their time.

Here is a complete API endpoint:

```php
<?php
// src/routes/greeting.php

Router::get("/api/greeting/{name}", function ($request, $response) {
    return $response->json([
        "message" => "Hello, " . $request->params["name"]
    ]);
});
```

No base controller. No service provider. No bootstrapping ritual. Drop that file into `src/routes/`, start the server, and it works. Your AI assistant knows this too — it reads the same conventions you do.

The philosophy fits in one sentence: **the framework that gets out of the way — for humans AND for AI.**

Routes go in `src/routes/`. Templates go in `src/templates/`. Models go in `src/orm/`. Learn the convention once. Your AI learns it once. Neither of you thinks about it again.

A decade of watching developers waste afternoons on configuration files, dependency conflicts, and framework upgrades that break everything. Then AI arrived and made the problem worse — every framework's ambiguity became the AI's confusion. Tina4 was born from both frustrations. One structure. One way to do things. The AI never guesses wrong because there is only one right answer.

---

## Why Zero Dependencies Matters

Tina4 v3 has **zero third-party dependencies** for its core features. The template engine, the JWT library, the SCSS compiler, the queue system, the GraphQL parser, the logger, the rate limiter — every piece is built from scratch using the language's standard library.

This is a survival strategy — for you and for your AI assistant.

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

**Core Web**
- HTTP router with path parameters, typed params, middleware, and auth guards
- Request and Response objects with full HTTP access
- Static file serving, CORS, rate limiting, health checks
- Graceful shutdown, request ID tracking, structured logging
- Response compression, ETag support

**Data Layer**
- SQL-first ORM with Active Record pattern
- Five database drivers: SQLite, PostgreSQL, MySQL, MSSQL, Firebird
- Relationships: hasOne, hasMany, belongsTo with eager loading
- Migrations with rollback, seeders with 50+ fake data generators
- Query result caching with TTL, paginated results

**Template and Frontend**
- Frond: a Twig-compatible template engine with 55+ filters
- Template inheritance, includes, macros, pre-compilation
- SCSS compiler, tina4css (built-in CSS framework), frond.js (frontend helpers)

**Auth and Sessions**
- JWT (HS256/RS256) built from scratch
- Four session backends: file, Redis, Valkey, MongoDB
- CSRF protection, password hashing

**Integration**
- Queue system with retry, dead letters, and four backends (SQLite, RabbitMQ, Kafka, MongoDB)
- GraphQL parser and executor
- WebSocket server
- SOAP/WSDL support, HTTP API client, email messenger, i18n

**Developer Experience**
- Rust-based unified CLI with scaffolding, migrations, and testing
- Dev admin dashboard with 11 panels
- Error overlay with source code and stack traces
- Interactive gallery with 7 deployable examples
- Live reload, AI tool integration

All of this fits in a single package per language, with zero runtime dependencies. The biggest component — the Frond template engine — runs about 1,500 lines. Most features need fewer than 200.

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
