# Tina4 v3.0 Feature Implementation Matrix

> **Last updated:** 2026-07-31 (variant groups expressed; counts below are stale)
> **Status:** every member of every variant group is present in all four. That is
> NOT the same as 100% parity, and this document used to say it was.
> **Test totals:** stale (dated 2026-04-03). Do not quote them; the four CLAUDE.md
> files and the release notes carry current numbers.
> **Unified CLI:** Rust-based `tina4` CLI drives all 4 frameworks with identical commands

**Read this before trusting a tick.** From 2026-04-03 to 2026-07-30 the header of
this file claimed 100% parity on 93 rows. In that window: memcached was missing as
a session backend in all four, the seven cache backends had no row at all, and one
row hid four queue backends. The claim was not a lie about the rows it tracked; it
was a claim about a smaller thing than it appeared to describe. A tick means "this
row exists in this framework", never "this subsystem is verified equivalent". The
feature audit (`98-feature-audit.md`) is what upgrades a tick into a verdict, and
it has re-opened roughly a third of the rows it has reached so far.

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
| Database adapters | SQLite, PostgreSQL, MySQL, MSSQL, Firebird, ODBC, MongoDB | 4.1-4.7 | grouped 2026-07-31 (was 4 + 21-26) |
| Session handling | file, Redis, Valkey, MongoDB, database, memcached | 42.1-42.6 | grouped 2026-07-30 |
| Cache backends | memory, file, Redis, Valkey, memcached, MongoDB, database | 43.1-43.7 | grouped 2026-07-31 (was absent) |
| Queue backends | file/lite, RabbitMQ, Kafka, MongoDB | 48.1-48.4 | grouped 2026-07-31 (was one flat row) |
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

### How the members were counted

Every member list below was read from the source in all four frameworks on
2026-07-31, not copied from a previous version of this document. That matters:
the group tables are the parity evidence, so a member list taken on trust would
launder a claim into a fact, which is the failure this matrix already made once.

| group | how it was enumerated |
| --- | --- |
| Database adapters | `tina4_python/database/`, `Tina4/Database/`, `lib/tina4/drivers/`, `packages/orm/src/adapters/` |
| Session handling | the handler `switch`/`elif` in `session.ts` / `session/__init__.py`, plus `session_handlers/` + `Tina4/Session/` |
| Cache backends | the backend classes in `cache/__init__.py` and `cache.ts`, plus `Tina4/Cache/` + `lib/tina4/cache_backends/` |
| Queue backends | `queue/` + `queue_backends/`, `Tina4/Queue/`, `lib/tina4/queue_backends/`, `packages/core/src/queueBackends/` |

### What grouping exposed

Three of the four variant groups were unreadable before, and expressing them
found one drift the flat list could not show:

1. **Cache backends were absent from the matrix entirely.** All four ship seven
   and all four document them, yet not one had a feature row. The matrix
   reported 100% parity on a subsystem it did not track. Now group 43.
2. **Queue backends hid behind one row.** Row 48 read "Queue (DB-backed,
   zero-dep)" while the frameworks ship four backends. A backend could go
   missing in one language and the row would still show a tick. Now group 48.
3. **Database adapters were the same shape as sessions** (seven interchangeable
   engines against one contract) but were spread across rows 4 and 21-26, so an
   eighth engine would renumber the matrix. Now group 4; rows 21-26 are retired
   rather than reused, because reusing a retired number is how a matrix starts
   lying about its own history.
4. **NEW: Node ships a second MECHANISM for session backend 42.2.** All four
   have Redis sessions and 42.2 is genuinely green in all four, so this is not a
   member gap. But Node alone offers `TINA4_SESSION_BACKEND=redis-npm`
   (`RedisNpmSessionHandler`), which drives Redis through the optional `redis`
   npm package instead of the raw-TCP RESP client every framework uses. It is
   NOT a 42.7: a driver choice is not a backend, and giving it a member number
   would show a phantom parity hole in the other three. See the note under
   group 42 for why it is still worth a decision.

A structural finding that is not a member gap, recorded because it is the kind of
drift these groups exist to make visible: **the cache backends are one file per
backend in PHP and Ruby, and one large file in Python and Node**
(`cache/__init__.py` 1164 lines, `cache.ts` 1449 lines, seven backend classes
each). Same outcome, same seven members, opposite layout, and the large-file side
contradicts ADR-0009 (one folder per feature). Queue and session backends are
already one-file-per-backend in all four, so cache is the outlier rather than the
convention. Not fixed here; this document is the wrong place to fix it.

## Phase 1: Foundation (Zero-Dep Core)

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 1 | DotEnv parser (.env loading) | [x] | [x] | [x] | [x] |
| 2 | Structured logger (JSON/text, rotation) | [x] | [x] | [x] | [x] |
| 3 | Database adapter interface | [x] | [x] | [x] | [x] |
| 4 | **Database adapters** (group, see below) | [x] | [x] | [x] | [x] |
| 5 | DATABASE_URL parser | [x] | [x] | [x] | [x] |
| 6 | Router (pattern matching, params) | [x] | [x] | [x] | [x] |
| 7 | Middleware pipeline | [x] | [x] | [x] | [x] |
| 8 | Health check endpoint (/health) | [x] | [x] | [x] | [x] |
| 9 | Graceful shutdown (signals) | [x] | [x] | [x] | [x] |
| 10 | CORS middleware (declarative) | [x] | [x] | [x] | [x] |
| 11 | Rate limiter (sliding window) | [x] | [x] | [x] | [x] |
| 12 | Response types (json/html/xml/file/redirect) | [x] | [x] | [x] | [x] |

### 4. Database adapters (feature group)

A GROUP, not a flat row. Seven interchangeable engines behind one contract
(feature 3, the adapter interface). Each engine is a feature INSIDE the group,
so an eighth engine is 4.8 and renumbers nothing. Previously this was row 4
(SQLite) plus flat rows 21-26; **21-26 are retired, not reused.**

Every adapter implements the same contract and the same write-path semantics:
a write returns a result carrying `affected_rows` and `last_id`, a filterless
`update()` takes the primary key out of the data (and raises if it cannot),
`delete()` with no filter raises, and `truncate()` is the explicit whole-table
spelling. Primary keys are introspected as a LIST, because a key may span
several columns and every key column belongs in the WHERE.

| # | Engine | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 4.1 | SQLite (default) | [x] | [x] | [x] | [x] |
| 4.2 | PostgreSQL | [x] | [x] | [x] | [x] |
| 4.3 | MySQL | [x] | [x] | [x] | [x] |
| 4.4 | MSSQL / SQL Server | [x] | [x] | [x] | [x] |
| 4.5 | Firebird | [x] | [x] | [x] | [x] |
| 4.6 | ODBC | [x] | [x] | [x] | [x] |
| 4.7 | MongoDB (SQL translation) | [x] | [x] | [x] | [x] |

**PHP carries three extra adapter CLASSES for the same seven engines**
(`PdoSqliteAdapter`, `PdoPostgresAdapter`, `PdoFirebirdAdapter` behind
`PdoAdapterTrait`). That is a runtime tax, not a parity gap: a PHP install may
ship `ext-sqlite3` or `pdo_sqlite` and the framework cannot know which, while
Python, Ruby and Node each have one canonical binding. Recorded here so a later
reader does not "simplify" it back into a bug.

**Ticks are per-engine existence, not per-engine verification.** The write-path
contract runs green on 4.1-4.4 in all four frameworks (2026-07-31, live
engines). 4.5-4.7 are not covered by it yet, and that gap is real: Ruby's
firebird, odbc and mongodb drivers still expose no `affected_rows`.

**Phase 1 totals:** Python 12/12 | PHP 12/12 | Ruby 12/12 | Node.js 12/12
(group 4 counts once; its seven engines are present in all four)

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
| 27 | Migrations (run + create + rollback) | [x] | [x] | [x] | [x] |

**Rows 21-26 are RETIRED.** They were the PostgreSQL, MySQL, MSSQL, Firebird,
ODBC and MongoDB adapters as six flat rows. They moved into **group 4.2-4.7** on
2026-07-31 so that adding an engine stops renumbering the matrix. The numbers
stay dead rather than being handed to new features: a reused number makes every
older reference to "feature 24" silently mean something else.

**Phase 2 totals:** Python 9/9 | PHP 9/9 | Ruby 9/9 | Node.js 9/9
(was 15/15 across rows 13-27; six of those rows are now group 4)

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

## Phase 4: Auth, Sessions & Cache

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 41 | JWT (zero-dep, HS256/RS256) | [x] | [x] | [x] | [x] |
| 42 | **Session handling** (group, see below) | [x] | [x] | [x] | [x] |
| 43 | **Cache backends** (group, see below) | [x] | [x] | [x] | [x] |
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

**42.2 has two mechanisms in Node, one everywhere else.** Every framework talks
to Redis over a hand-rolled raw-TCP RESP client, which is what keeps the backend
zero-dependency. Node ALSO exposes `TINA4_SESSION_BACKEND=redis-npm`
(`RedisNpmSessionHandler`), which uses the optional `redis` npm package and
falls back to raw TCP when it is absent. The member is green in all four either
way, so this is a mechanism question, not a gap. Two reasons it still needs an
owner call rather than a shrug: it is the only session path in any framework
that reaches for a third-party driver, and it drives that driver with
`execFileSync` per command, which is the exact pattern measured as the cause of
the sessionHandlers flakiness and replaced everywhere else by the persistent
worker connection (p50 80ms to 10.5ms). Either it is a documented Node runtime
gift that the other three cannot copy, or it is drift with a performance
regression attached. Not decided here.

**42.6 memcached** was added 2026-07-30. It had been one of the seven CACHE
backends in all four frameworks since v3, but was a session backend in NONE of
them, even though it is the classic PHP session store. Zero-dependency text
protocol in all four. Memcached has no persistence and no replication, so a
restart drops every session; that is a deliberate trade (it is a cache) and is
why file/database remain the defaults.

### 43. Cache backends (feature group)

A GROUP, and **new to the matrix on 2026-07-31** - this subsystem had no feature
row at all while the matrix reported 100% parity, which is the single worst
instrument failure this document has made. All four ship seven backends selected
by `TINA4_CACHE_BACKEND`, and all four document them.

The number 43 reuses a hole freed when sessions collapsed from five flat rows
into group 42, so nothing after it renumbers. Cache sits beside sessions because
they are the same shape: pluggable storage behind one contract, sharing six of
seven members.

| # | Backend | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 43.1 | memory (default) | [x] | [x] | [x] | [x] |
| 43.2 | file | [x] | [x] | [x] | [x] |
| 43.3 | Redis | [x] | [x] | [x] | [x] |
| 43.4 | Valkey | [x] | [x] | [x] | [x] |
| 43.5 | memcached | [x] | [x] | [x] | [x] |
| 43.6 | MongoDB | [x] | [x] | [x] | [x] |
| 43.7 | database | [x] | [x] | [x] | [x] |

Every backend falls back to **file** (a real persistent cache, never a silent
no-op) when its driver or service is unreachable. Two bugs fixed 2026-07-30 are
worth keeping visible here, because both were invisible while this group had no
row: memcached `size` read the GLOBAL `curr_items` and counted other tenants'
keys, and `clear()` sent `flush_all` and wiped the whole shared server.

**Phase 4 totals:** Python 4/4 | PHP 4/4 | Ruby 4/4 | Node.js 4/4
(groups 42 and 43 count once each; all thirteen members are green in all four)

---

## Phase 5: Extended Features

| # | Feature | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 48 | **Queue backends** (group, see below) | [x] | [x] | [x] | [x] |
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

### 48. Queue backends (feature group)

A GROUP. Row 48 used to read "Queue (DB-backed, zero-dep)" as one flat tick
while the frameworks shipped four backends, so a backend could go missing in one
language and the row would still be green.

| # | Backend | Python | PHP | Ruby | Node.js |
|---|---------|--------|-----|------|---------|
| 48.1 | lite (file / DB-backed, default) | [x] | [x] | [x] | [x] |
| 48.2 | RabbitMQ | [x] | [x] | [x] | [x] |
| 48.3 | Kafka | [x] | [x] | [x] | [x] |
| 48.4 | MongoDB | [x] | [x] | [x] | [x] |

**Reservation and visibility timeout is a 48.1/48.4 concern only.** A popped job
is reserved for `TINA4_QUEUE_VISIBILITY_TIMEOUT` seconds (default 300) so a
consumer that dies before `complete()`/`fail()` does not strand it. 48.2 and
48.3 delegate redelivery to the broker, which is a runtime gift, not a gap.

**Python layers this group in two directories and that is deliberate.**
`tina4_python/queue/*_backend.py` holds the Queue-facing backend; the wire
protocol lives in `tina4_python/queue_backends/*Connector`. They are not
duplicates - checked, they differ by design.

**Phase 5 totals:** Python 11/11 | PHP 11/11 | Ruby 11/11 | Node.js 11/11
(group 48 counts once; its four backends are green in all four)

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

Grouping changes the arithmetic, so here is what it does and does not settle.

| | count | note |
|---|:---:|---|
| rows before grouping | 93 | the number this file published since 2026-04-03 |
| retired (21-26 into group 4) | -6 | numbers stay dead, never reused |
| added (cache backends, group 43) | +1 | a subsystem that had no row at all |
| **top-level rows now** | **88** | of which 4 are variant groups |
| members inside those 4 groups | 24 | 7 adapters + 6 session + 7 cache + 4 queue |
| **capabilities actually tracked** | **108** | 84 flat rows + 24 group members |

**88 is not the published feature count and 108 is not either.** Settling that
number is the feature audit's job, not this restructure's: `feature-recount.md`
found four conflicting published numbers and concluded the true count is HIGHER
than any of them, because a large amount of shipped 3.13.x work is enumerated
nowhere. Realtime collab, the MCP server, DocStore, Metrics, Validator,
TestClient, the i18n module, static-asset revalidation, per-route WebSocket auth,
MQTT and the live API index still have no row here. What grouping fixed is the
shape, so those rows can land without renumbering anything.

All 4 backend frameworks use **zero third-party dependencies** for core features.
tina4-js is also zero-dep (1.5KB core gzipped). One exception is now visible and
undecided: Node's `redis-npm` session mechanism reaches for an optional npm
driver (see group 42).

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

### Milestone

88 top-level backend rows (108 capabilities once variant-group members are
counted) + 11 frontend features across Python, PHP, Ruby, Node.js and tina4-js.
Every group member enumerated on 2026-07-31 is present in all four. The old
"feature parity is at 100%" line is removed rather than restated: this file
tracks presence, and the audit tracks equivalence.

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
