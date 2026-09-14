# What Is Tina4?

## The AI Framework Philosophy

**TINA4: The Intelligent Native Application 4ramework.**

Four words, and each one earns its place.

**Intelligent.** The framework understands AI. Every project ships with a CLAUDE.md file that hands an AI assistant the whole of the framework's conventions, API and structure. Your assistant writes correct code on the first try, because the framework already told it how.

**Native.** Zero third-party dependencies. Every feature - the template engine, the JWT library, the SCSS compiler, the queue, the GraphQL parser - is built from scratch on the language's standard library. No supply chain to trust. No version conflicts. No surprises.

**Application.** This builds real production applications. Routing, ORM, authentication, queues, WebSocket, email, GraphQL, SOAP, 140 features, all of it in the box. One package. One install.

**4ramework.** Four languages, one API. Python, PHP, Ruby, Node.js: learn the conventions once, build in any of them. The "4" is the number and it's "for" - a framework *for* developers who guard their time.

Here is a whole API endpoint:

```php
<?php
// src/routes/greeting.php

Router::get("/api/greeting/{name}", function ($request, $response) {
    return $response->json([
        "message" => "Hello, " . $request->params["name"]
    ]);
});
```

No base controller. No service provider. No bootstrapping ritual. Drop that file into `src/routes/`, start the server, and it answers. Your AI assistant knows this too, it reads the same conventions you do.

The philosophy fits in one sentence: the framework gets out of the way, for humans and for AI alike.

Routes go in `src/routes/`. Templates go in `src/templates/`. Models go in `src/orm/`. You learn the convention once, your assistant learns it once, and neither of you thinks about it again.

Behind it sits a decade of watching developers lose afternoons to configuration files, dependency conflicts, and upgrades that break everything. Then AI arrived and made it worse: every framework's ambiguity became the assistant's confusion. Tina4 grew out of both frustrations. One structure, one way to do things, and the assistant never guesses wrong because there's only one right answer.

---

## Why Zero Dependencies Matters

Tina4 v3 carries **zero third-party dependencies** for its core. The template engine, the JWT library, the SCSS compiler, the queue, the GraphQL parser, the logger, the rate limiter: every piece is built from scratch on the language's standard library.

It's a survival strategy, for you and for your assistant.

### Security

Every dependency is an attack surface. When a package in your tree is compromised, and one will be - ask the teams who trusted `event-stream`, `colors.js` or `ua-parser-js` - your application goes down with it.

Tina4's attack surface is the language runtime and your own code. Nothing else sits between you and your users.

### Size

Tina4 installs **one package**. The framework runs to roughly **~26,000 lines of code** per language (Python ~26,000 | PHP ~35,000 | Ruby ~24,000 | Node.js ~32,000), and every line is standard-library code you can read in an afternoon and audit. The Docker image fits in **40-80MB**. Your production container ships with what it needs, and nothing else tags along.

### Portability

Zero dependencies means zero compatibility conflicts. You'll never meet this with Tina4:

```
Your requirements could not be resolved to an installable set of packages.
  Problem 1
    - package-a v2.1 requires other-package ^3.0
    - package-b v1.4 requires other-package ^2.0
```

No diamond dependency problem. No tree to untangle. No Friday-afternoon emergency because a transitive dependency shipped a breaking change.

### Upgrades

Upgrading Tina4 means upgrading one package. There's no cascade of breaking changes. The framework team owns every line, so when something breaks the fix lives in one place.

### The One Exception

Database drivers are the exception. You can't talk to PostgreSQL without a PostgreSQL driver, and these are native connectors to external systems. They're optional: install only what you need. SQLite works out of the box on every language's standard library.

---

## 140 Catalogued Features

Tina4 keeps 140 numbered catalogue entries across Python, PHP, Ruby, Node.js, the shared CLI, and selected integrations. The catalogue is the family's implementation and audit inventory. It doesn't claim that every entry ships in every package or has reached parity, each feature list and audit packet records its own owner and status.

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

Each language packages these capabilities in its native format. A dependency means an extra package the package manager installs; a language or runtime extension doesn't count. Python and PHP core declare no required third-party packages. Ruby declares runtime gems, while Node's root package installs optional provider packages by default. The biggest component, the Frond template engine, runs about 1,500 lines. Most features need fewer than 200.

---

## Convention Over Configuration

Tina4 projects follow a predictable structure. Run `tina4 init` and you get:

```
my-project/
|-- .env                    # Configuration
|-- src/
|   |-- routes/             # Route handlers (auto-discovered)
|   |-- orm/                # ORM models (auto-discovered)
|   |-- templates/          # Frond templates
|   |-- public/             # Static files (served directly)
|   |   |-- css/
|   |   |-- js/
|   |   `-- images/
|   `-- scss/               # SCSS source files (auto-compiled)
|-- migrations/             # SQL migration files
|-- data/                   # SQLite databases (gitignored)
|-- logs/                   # Log files with rotation (gitignored)
`-- tests/                  # Test files
```

Five rules, no exceptions:

1. **Routes** go in `src/routes/`. Name the files however you want. Tina4 reads the route definitions inside them.
2. **Models** go in `src/orm/`. Same auto-discovery.
3. **Templates** go in `src/templates/`. Call `response.render("products/list.twig", data)` and Tina4 finds it.
4. **Static files** go in `src/public/`. A file at `src/public/css/style.css` serves at `/css/style.css`.
5. **Configuration** goes in `.env`. One file. Key-value pairs. No YAML. No TOML. No JSON config.

No routing table to maintain. No service container to wire up. No middleware stack to arrange in the right order. You drop the files in the right directories, and they work.

---

## The Four-Language Paradigm

Tina4 is one framework with four backend implementations:

- **tina4-python** - Python 3.12+
- **tina4-php** - PHP 8.2+
- **tina4-ruby** - Ruby 3.1+
- **tina4-nodejs** - Node.js 22+ (TypeScript)

All four target the same project structure, `.env` variables, template syntax, CLI commands, and API contracts. The audit records the gaps until fixtures prove those contracts in every implementation.

Each implementation follows its language's naming convention:

| Concept | Python / Ruby | PHP / Node.js |
|---------|--------------|---------------|
| Method names | `snake_case` | `camelCase` |
| Fetch one row | `fetch_one()` | `fetchOne()` |
| Soft delete | `soft_delete()` | `softDelete()` |

A team can prototype in Python and deploy in PHP without relearning the framework. Frontend developers on frond.js never need to know which backend language is running. DevOps deploys the same Docker structure, the same `.env`, the same health checks, whichever language runs underneath.

One Rust-based CLI binary detects the project language and dispatches to the correct runtime:

```bash
tina4 init python ./my-app    # Scaffold a Python project
tina4 serve                   # Start dev server
tina4 generate model User     # Generate an ORM model
tina4 migrate                 # Run pending migrations
tina4 test                    # Run the test suite
```

---

## What Tina4 Is Not

Tina4 doesn't replace Laravel, Django, Rails or Next.js. Those are fine frameworks for a team that wants a full-stack opinion on everything.

Tina4 is for developers who want:

- **Control** - you see every line that runs your application
- **Simplicity** - one package, one import, behaviour you can predict
- **Speed** - sub-millisecond framework overhead
- **Portability** - switch languages without switching paradigms
- **Security** - no supply chain risk riding in on a transitive dependency

If you want a platform with a library of plugins and a marketplace of themes, Tina4 is the wrong tool. If you want a sharp, minimal toolkit that does what you tell it and nothing more, you're already home.

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
| Features | 140 catalogued entries |
