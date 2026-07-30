# Tina4 v3.0 — Feature Implementation Matrix

> **Last updated:** 2026-04-03
> **Status:** ALL 4 FRAMEWORKS AT 100% PARITY — v3.10.67
> **Test totals:** Python 2,149 | PHP ~2,200 | Ruby 2,400 | Node.js 2,580 | tina4-js 238 | **Grand total: ~9,567 tests**
> **Unified CLI:** Rust-based `tina4` CLI v3.8.4 drives all 4 frameworks with identical commands

## Legend
- [x] Fully implemented

---

## Feature groups

The phases below are DELIVERY order. This is the orthogonal view: capabilities
that have several interchangeable implementations, where the group is the
feature and each implementation is a feature inside it.

Why it matters: adding memcached sessions as a flat row 47 would have pushed
Swagger to 48 and renumbered every row after it. Sub-numbering inside a group
absorbs a new backend without touching anything else. It also makes a gap
obvious: a group with five backends in one language and three in another is a
parity hole you can see at a glance, which a flat list hides.

| Group | Members | Numbering | Status |
|-------|---------|-----------|--------|
| Session handling | file, Redis, Valkey, MongoDB, database, memcached | 42.1-42.6 | grouped |
| Database adapters | SQLite, PostgreSQL, MySQL, MSSQL, Firebird, ODBC, MongoDB | 4, 21-26 | NOT grouped - separate flat rows |
| Cache backends | memory, file, Redis, Valkey, memcached, MongoDB, database | none | NOT IN THE MATRIX AT ALL |
| Queue backends | file, RabbitMQ, Kafka, MongoDB | 48 | NOT grouped - one row hides four backends |
| Frond engine | lexer, parser, compiler, runtime, filters, tags, tests, functions, extensibility, escaping, sandbox, template cache, fragment cache | 28-40 | components, not variants |
| ORM | base class, soft delete, relationships, scopes, field mapping, pagination, caching, validation | 13-20 | components, not variants |
| CLI | init, serve, migrate, seed, test, routes | 59-64 | subcommands |

Two kinds of group appear here and they are not the same thing:

- **Variant groups** - interchangeable implementations of one contract
  (sessions, database adapters, cache backends, queue backends). Every member
  satisfies the SAME contract, so a member missing in one language is a parity
  bug. These are the ones worth sub-numbering.
- **Component groups** - parts that together make one feature (Frond, ORM, CLI).
  A member is not interchangeable with its siblings, and "3 of 13" means an
  unfinished feature rather than a missing variant.

### Gaps this view exposes

1. **Cache backends are absent from the matrix.** All four frameworks ship seven
   (`TINA4_CACHE_BACKEND`: memory, file, redis, valkey, memcached, mongodb,
   database) and all four document them, but not one has a feature row. The
   matrix reports 100% parity on a subsystem it does not track.
2. **Queue backends hide behind one row.** Row 48 reads "Queue (DB-backed,
   zero-dep)" while the frameworks actually ship file, RabbitMQ, Kafka and
   MongoDB. A backend could be missing in one language and the matrix would
   still show a tick.
3. **Database adapters are the same shape as sessions** - seven interchangeable
   engines against one contract - but are spread across rows 4 and 21-26 rather
   than grouped, so adding an eighth engine renumbers the matrix.

Sessions (42) are the only variant group currently expressed as one. The other
three should follow; that is a documentation change, not a code change, and it
is not done yet.

## Phase 1: Foundation (Zero-Dep Core)

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 1 | DotEnv parser (.env loading) | [x] | [x] | [x] | [x] |
| 2 | Structured logger (JSON/text, rotation) | [x] | [x] | [x] | [x] |
| 3 | Database adapter interface | [x] | [x] | [x] | [x] |
| 4 | SQLite adapter | [x] | [x] | [x] | [x] |
| 5 | DATABASE_URL parser | [x] | [x] | [x] | [x] |
| 6 | Router (pattern matching, params) | [x] | [x] | [x] | [x] |
| 7 | Middleware pipeline | [x] | [x] | [x] | [x] |
| 8 | Health check endpoint (/health) | [x] | [x] | [x] | [x] |
| 9 | Graceful shutdown (signals) | [x] | [x] | [x] | [x] |
| 10 | CORS middleware (declarative) | [x] | [x] | [x] | [x] |
| 11 | Rate limiter (sliding window) | [x] | [x] | [x] | [x] |
| 12 | Response types (json/html/xml/file/redirect) | [x] | [x] | [x] | [x] |

**Phase 1 totals:** Python 12/12 | PHP 12/12 | Ruby 12/12 | Node.js 12/12

---

## Phase 2: ORM & Data Layer

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 13 | ORM base class (SQL-first) | [x] | [x] | [x] | [x] |
| 14 | Soft delete (deleted_at, restore, withTrashed) | [x] | [x] | [x] | [x] |
| 15 | Relationships (hasOne, hasMany, eager load) | [x] | [x] | [x] | [x] |
| 16 | Scopes (reusable query filters) | [x] | [x] | [x] | [x] |
| 17 | Field mapping (property to column) | [x] | [x] | [x] | [x] |
| 18 | Paginated results (standardized format) | [x] | [x] | [x] | [x] |
| 19 | Result/ORM caching (in-memory, TTL) | [x] | [x] | [x] | [x] |
| 20 | Input validation (from field defs) | [x] | [x] | [x] | [x] |
| 21 | PostgreSQL adapter | [x] | [x] | [x] | [x] |
| 22 | MySQL adapter | [x] | [x] | [x] | [x] |
| 23 | MSSQL adapter | [x] | [x] | [x] | [x] |
| 24 | Firebird adapter | [x] | [x] | [x] | [x] |
| 25 | ODBC adapter | [x] | [x] | [x] | [x] |
| 26 | MongoDB adapter (SQL translation) | [x] | [x] | [x] | [x] |
| 27 | Migrations (run + create + rollback) | [x] | [x] | [x] | [x] |

**Phase 2 totals:** Python 15/15 | PHP 15/15 | Ruby 15/15 | Node.js 15/15

---

## Phase 3: Frond Template Engine (Zero-Dep)

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 28 | Lexer (tokenize Frond syntax) | [x] | [x] | [x] | [x] |
| 29 | Parser (build AST) | [x] | [x] | [x] | [x] |
| 30 | Compiler (to closures/functions) | [x] | [x] | [x] | [x] |
| 31 | Runtime (execute with context) | [x] | [x] | [x] | [x] |
| 32 | Filters (~55 filters) | [x] | [x] | [x] | [x] |
| 33 | Tags (for, if, block, extends, etc.) | [x] | [x] | [x] | [x] |
| 34 | Tests (defined, empty, odd, even, etc.) | [x] | [x] | [x] | [x] |
| 35 | Functions (range, cycle, etc.) | [x] | [x] | [x] | [x] |
| 36 | Extensibility API (addFilter/Function/Tag) | [x] | [x] | [x] | [x] |
| 37 | Auto-escaping (html/js/css/url) | [x] | [x] | [x] | [x] |
| 38 | Sandboxing (restrict template access) | [x] | [x] | [x] | [x] |
| 39 | Template caching (compiled cache) | [x] | [x] | [x] | [x] |
| 40 | Fragment caching ({% cache %} tag) | [x] | [x] | [x] | [x] |

**Phase 3 totals:** Python 13/13 | PHP 13/13 | Ruby 13/13 | Node.js 13/13

---

## Phase 4: Auth & Sessions

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 41 | JWT (zero-dep, HS256/RS256) | [x] | [x] | [x] | [x] |
| 42 | **Session handling** (group, see below) | [x] | [x] | [x] | [x] |
| 47 | Swagger/OpenAPI generation | [x] | [x] | [x] | [x] |

### 42. Session handling (feature group)

A GROUP, not a flat row. Session handling is one capability with one contract;
each storage backend is a feature INSIDE it. They are sub-numbered so adding a
backend does not renumber every feature after it. Adding memcached as a flat
row 47 would have pushed Swagger to 48 and shifted the remaining ~50 rows, which
is why the group exists.

Every backend implements the SAME contract (`read` / `write` / `destroy` / `gc`)
and the same backend-failure policy: a genuine key miss is silent, a TRANSPORT
failure raises so the Session layer can log-loud and degrade. Collapsing those
two is how a dead backend silently logs every user out.

| # | Backend | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 42.1 | file (default) | [x] | [x] | [x] | [x] |
| 42.2 | Redis | [x] | [x] | [x] | [x] |
| 42.3 | Valkey | [x] | [x] | [x] | [x] |
| 42.4 | MongoDB | [x] | [x] | [x] | [x] |
| 42.5 | database | [x] | [x] | [x] | [x] |
| 42.6 | memcached | [x] | [x] | [x] | [x] |

**42.6 memcached** was added 2026-07-30. It had been one of the seven CACHE
backends in all four frameworks since v3, but was a session backend in NONE of
them, even though it is the classic PHP session store. Zero-dependency text
protocol in all four. Memcached has no persistence and no replication, so a
restart drops every session; that is a deliberate trade (it is a cache) and is
why file/database remain the defaults.

**Phase 4 totals:** Python 3/3 | PHP 3/3 | Ruby 3/3 | Node.js 3/3
(group 42 counts once; its six backends are all green in all four)

---

## Phase 5: Extended Features

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 48 | Queue (DB-backed, zero-dep) | [x] | [x] | [x] | [x] |
| 49 | SCSS compiler (zero-dep) | [x] | [x] | [x] | [x] |
| 50 | API client (stdlib HTTP) | [x] | [x] | [x] | [x] |
| 51 | GraphQL (zero-dep parser) | [x] | [x] | [x] | [x] |
| 52 | WebSocket (zero-dep) | [x] | [x] | [x] | [x] |
| 53 | WSDL/SOAP | [x] | [x] | [x] | [x] |
| 54 | Localization/i18n (JSON translations) | [x] | [x] | [x] | [x] |
| 55 | Email/Messenger (SMTP) | [x] | [x] | [x] | [x] |
| 56 | Seeder/FakeData (50+ generators) | [x] | [x] | [x] | [x] |
| 57 | Auto-CRUD (from models) | [x] | [x] | [x] | [x] |
| 58 | Event/listener system (priority, async) | [x] | [x] | [x] | [x] |

**Phase 5 totals:** Python 11/11 | PHP 11/11 | Ruby 11/11 | Node.js 11/11

---

## Phase 6: CLI & Developer Experience

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 59 | CLI: init (scaffold project) | [x] | [x] | [x] | [x] |
| 60 | CLI: serve (dev server + hot reload) | [x] | [x] | [x] | [x] |
| 61 | CLI: migrate (run/create/rollback) | [x] | [x] | [x] | [x] |
| 62 | CLI: seed (run/create) | [x] | [x] | [x] | [x] |
| 63 | CLI: test (run tests) | [x] | [x] | [x] | [x] |
| 64 | CLI: routes (list all routes) | [x] | [x] | [x] | [x] |
| 65 | Debug overlay (dev mode injection) | [x] | [x] | [x] | [x] |
| 66 | Dev admin dashboard (11 tabs) | [x] | [x] | [x] | [x] |
| 67 | Configurable error pages (404/500/etc.) | [x] | [x] | [x] | [x] |
| 68 | Request ID tracking | [x] | [x] | [x] | [x] |
| 69 | AI tool integration | [x] | [x] | [x] | [x] |
| 70 | Carbonah benchmarks | [x] | [x] | [x] | [x] |

**Phase 6 totals:** Python 12/12 | PHP 12/12 | Ruby 12/12 | Node.js 12/12

---

## Phase 7: Testing

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 71 | Comprehensive test suite | [x] 2,149 tests | [x] ~2,200 tests | [x] 2,400 tests | [x] 2,580 tests |
| 72 | Frond template tests | [x] | [x] | [x] | [x] |
| 73 | ORM tests (CRUD, soft delete, relations) | [x] | [x] | [x] | [x] |
| 74 | Database driver tests (per driver) | [x] | [x] | [x] | [x] |
| 75 | Router tests (patterns, middleware) | [x] | [x] | [x] | [x] |
| 76 | Auth tests (JWT, sessions) | [x] | [x] | [x] | [x] |

**Phase 7 totals:** Python 6/6 | PHP 6/6 | Ruby 6/6 | Node.js 6/6

---

## Frontend (shared across all backends)

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 77 | frond.js / tina4helper.js | [x] | [x] | [x] | [x] |
| 78 | tina4css | [x] | [x] | [x] | [x] |

---

## Phase 8: v3.10.x Additions (since 2026-03-20)

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 79 | Route groups (nested prefixes) | [x] | [x] | [x] | [x] |
| 80 | Imperative relationships (query_has_one/many/belongs_to) | [x] | [x] | [x] | [x] |
| 81 | DI container | [x] | [x] | [x] | [x] |
| 82 | Service runner | [x] | [x] | [x] | [x] |
| 83 | HtmlElement builder | [x] | [x] | [x] | [x] |
| 84 | tina4 console (REPL) | [x] | [x] | [x] | [x] |
| 85 | tina4 env (interactive config) | [x] | [x] | [x] | [x] |
| 86 | Dual test port (port+1000, no hot reload) | [x] | [x] | [x] | [x] |
| 87 | Port kill-and-take-over | [x] | [x] | [x] | [x] |
| 88 | Metrics (bubble chart, 3-stage test detection) | [x] | [x] | [x] | [x] |
| 89 | Metrics file detail (scan root tracking) | [x] | [x] | [x] | [x] |
| 90 | Database.get_next_id (race-safe sequences) | [x] | [x] | [x] | [x] |
| 91 | Dynamic version (read from package metadata) | [x] | [x] | [x] | [x] |
| 92 | File upload standard (raw bytes, no base64) | [x] | [x] | [x] | [x] |
| 93 | load() instance method (selectOne, returns bool) | [x] | [x] | [x] | [x] |

**Phase 8 totals:** Python 15/15 | PHP 15/15 | Ruby 15/15 | Node.js 15/15

---

## tina4-js (Frontend Framework)

| # | Feature | Status |
|---|---------|--------|
| F1 | Signals (reactive state) | [x] |
| F2 | Computed / effect / batch | [x] |
| F3 | html tagged template (fine-grained DOM patching) | [x] |
| F4 | Web Components (Tina4Element) | [x] |
| F5 | Router ({param} syntax, guards, async) | [x] |
| F6 | API client (get/post/put/patch/delete) | [x] |
| F7 | api.upload() (multipart FormData) | [x] |
| F8 | WebSocket client (auto-reconnect, signal integration) | [x] |
| F9 | PWA (service worker, cache strategies) | [x] |
| F10 | Debug overlay | [x] |
| F11 | Islands architecture (IIFE bundle) | [x] |

**tina4-js totals:** 11/11 features | 238 tests | v1.0.15 on npm

---

## Grand Summary

| Framework | Done | Total Features | Tests | Completeness |
|-----------|:----:|:--------------:|:-----:|:------------:|
| **Python** | **93** | 93 | 2,149 | **100%** |
| **PHP** | **93** | 93 | ~2,200 | **100%** |
| **Ruby** | **93** | 93 | 2,400 | **100%** |
| **Node.js** | **93** | 93 | 2,580 | **100%** |
| **tina4-js** | **11** | 11 | 238 | **100%** |

All 4 backend frameworks use **zero third-party dependencies** for core features. tina4-js is also zero-dep (1.5KB core gzipped).

### Rust Unified CLI

A single Rust-based `tina4` CLI binary auto-detects the project language and dispatches to the correct framework runtime. Commands are identical across all 4 frameworks:

```
tina4 init [dir]        # Scaffold a new project
tina4 serve [port]      # Start dev server (default 7145)
tina4 migrate           # Run pending migrations
tina4 migrate:create    # Create new migration
tina4 migrate:rollback  # Rollback last migration
tina4 seed              # Run seeders
tina4 test              # Run test suite
tina4 routes            # List all routes
```

### Milestone Complete

93 backend features + 11 frontend features implemented and tested across Python, PHP, Ruby, Node.js, and tina4-js with a combined ~9,567 tests. Feature parity is at 100%.

### Rust Unified CLI v3.8.4

Additional commands since v3.0:
```
tina4 console           # Interactive REPL with framework loaded
tina4 env               # Interactive .env configuration wizard
tina4 env --sync        # Scan code + update .env with missing vars
tina4 env --example     # Generate .env.example (65+ vars)
tina4 env --list        # List all env vars found in project
tina4 doctor            # Check framework health and dependencies
```
