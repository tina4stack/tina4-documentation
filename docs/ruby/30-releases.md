# Chapter 30: Release Notes

Tina4 Ruby follows semantic versioning. The major version (3) marks the ground-up rewrite from v2. Minor versions (3.1, 3.2, etc.) introduce features and non-breaking API additions. Patch versions carry bug fixes and small improvements.

This chapter covers every v3 release from the initial launch through the current stable line. Each section groups releases by minor version, highlights the changes that affect your code, and shows migration steps for anything that breaks.

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** — second WEBrick on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **CORS fix** — returns empty string when origin not allowed (not *)
- **ORM DATABASE_URL discovery** — auto-connect from env
- **QueryBuilder docs** — added to ORM chapter

---

## v3.10.48 — April 2, 2026

### Bug Fixes

**Puma requires `--production` flag** — Puma no longer auto-selected when `TINA4_DEBUG=false`. Use `tina4ruby serve --production` to enable Puma. Added FakeData (46), Gallery (16), and DevReload (37) tests.

---

## v3.10.46 — April 1, 2026

### Test Coverage

344 new tests added across cache (56), ORM (19), Frond (28), database drivers (85), auth (21), SCSS (10), dotenv (30), queue backends (10), migration (10), session handlers (11), router (14), log (13), CSRF middleware (17). Fixed session handler DB key bug (symbol vs string). Ruby now at 2,274 tests with full parity across all 49 core areas.

---

## v3.10.45 — April 1, 2026

### Notes

Version bump for parity with PHP CLI serve fix. No Ruby-specific changes.

---

## v3.10.44 — April 1, 2026

### New Features

**Database tab redesign** — Split-screen layout with tables navigation on the left and query editor + results on the right. Click-to-select table highlighting.

**Copy CSV / Copy JSON** — Copy query results to clipboard in CSV or JSON format.

**Paste data** — Modal for pasting JSON arrays or CSV/tab-separated data. Auto-generates INSERT statements targeting the selected table, or prompts for a new table name with CREATE TABLE generation. SQL input passes through unchanged.

**Multi-statement execution** — Query runner handles batched SQL statements in a transaction.

**Database badge on load** — Table count shows immediately without clicking the Database tab.

**Star wiggle animation** — Empty star (☆) on the landing page with delayed wiggle animation at random intervals.

### Bug Fixes

**Default port** — Ruby default port set to 7147 (PHP=7145, Python=7146, Ruby=7147, Node=7148).

**SQLite LIMIT fix** — Prevents double-LIMIT errors in the database browser.

**browseTable quote escaping** — Fixed table name click handlers.

**ORM table name pluralization** — Fixed default table name resolution. Table names are now pluralized by default (adding "s" suffix), only skipping when `ORM_PLURAL_TABLE_NAMES` is explicitly set to false.

**QueryBuilder closed-connection detection** — `ensure_db!` now checks if the resolved database connection is still open, raising a proper error instead of crashing with `ArgumentError: prepare called on a closed database`.

**Metrics directory validation** — `quick_metrics` and `full_analysis` now check directory existence before `_resolve_root` fallback, so missing-directory errors are raised correctly.

### Test Coverage

88 new tests added (DevMailbox 40, Static files 18, CLI scaffolding 30), plus 13 v3.10.44 feature specs and 60 pre-existing ORM/metrics bug fixes. 1,913 tests passing, 0 failures.

---

## v3.10.40 — April 1, 2026

### Bug Fixes

**Dev overlay version check** — Fixed misleading "You are up to date" message when running a version ahead of what's published on RubyGems. The overlay now shows a purple "ahead of RubyGems" message. Also added a breaking changes warning (red banner with changelog link) when a major or minor version update is available.

---

## v3.10.39 — April 1, 2026

### New Features

**`Container.singleton(name, &block)`** — Register a memoized factory. The block is called once on first `resolve()` and the same instance is returned on all subsequent calls. `register()` with a block is now always transient (new instance per call), matching Python's behavior.

```ruby
Tina4::Container.singleton(:db) { Tina4::Database.new(ENV["DATABASE_URL"]) }
db1 = Tina4::Container.resolve(:db)  # creates instance
db2 = Tina4::Container.resolve(:db)  # same instance
```

**`Router.match(path, method)`** — alias for `find_route()` (parity with Python, PHP, Node.js).

**`Router.get_routes` and `Router.list_routes`** — explicit listing methods (remove ambiguous `routes` alias).

**AI installer** — `ai_spec.rb` and smoke tests updated to reflect the menu-based API (`installed?`, `install_selected`, `install_all`, `generate_context`).

---

## v3.10.38 -- April 1, 2026

### Code Metrics & Bubble Chart

The dev dashboard (`/__dev`) now includes a **Code Metrics** tab with a PHPMetrics-style bubble chart visualization. Files appear as animated bubbles sized by LOC and colored by maintainability index. Click any bubble to drill down into per-function cyclomatic complexity.

The metrics engine uses `Ripper` (Ruby stdlib) for zero-dependency static analysis covering cyclomatic complexity, Halstead volume, maintainability index, coupling, and violation detection. File analysis is sorted worst-first. Results are cached for 60 seconds.

### AI Context Installer

`tina4ruby ai` now presents a simple numbered menu instead of auto-detection. Select tools by number, comma-separated or `all`. Already-installed tools show green. Generated context includes the full skills table.

### Dashboard Improvements

Full-width layout, sticky header/tabs, full-screen overlay.

### Cleanup

Removed `demo/` directory. Removed old `plan/` spec documents, replaced with `PARITY.md` and `TESTS.md`. Central parity matrix added to tina4-book.

---

## v3.10.x -- Previous Releases

**Released:** March 28 -- 30, 2026

The v3.10 line is the most active release series. It delivered Auto-CRUD, ORM transaction safety, Frond template engine hardening, and full cross-language parity with the Python, PHP, and Node.js implementations.

### v3.10.29 -- Version Parity (March 30)

Version parity release. All four Tina4 frameworks now share the same version number and feature set.

### v3.10.27 -- Frond Macro HTML Escaping Fix (March 30)

**Bug fix:** Macro output was HTML-escaped when used inside `{{ }}` expressions. Characters like `<`, `>`, and `"` rendered as `&lt;`, `&gt;`, `&amp;quot;` instead of raw HTML. Nested macro calls double-escaped.

```ruby
# BEFORE (broken): macro output escaped
# Template: {{ my_macro() }}
# Rendered: &lt;div class=&quot;card&quot;&gt;...&lt;/div&gt;

# AFTER (fixed): macro output treated as safe HTML
# Template: {{ my_macro() }}
# Rendered: <div class="card">...</div>
```

### v3.10.25 -- ORM Transaction Fix (March 30)

**Bug fix:** ORM `save` and `delete` called `commit` without an active transaction on SQLite. This raised `cannot commit -- no transaction is active` errors.

```ruby
# BEFORE (broken):
user = User.new(name: "Alice")
user.save  # => RuntimeError: cannot commit

# AFTER (fixed): save/delete wrap operations in a transaction block
user = User.new(name: "Alice")
user.save  # => works on all database engines
```

### v3.10.22 -- Unique Form Tokens (March 30)

Form tokens now include a nonce in the JWT payload. Each token is unique per form render, which prevents replay attacks.

```ruby
# In your Frond template:
<input type="hidden" name="formToken" value="{{ formTokenValue() }}">
```

### v3.10.18 -- Frond Ternary Parser Fix (March 29)

**Bug fix:** The Frond template ternary/inline-if parser failed on quoted strings containing special characters.

```ruby
# BEFORE (broken):
# {{ status == "active" ? "Yes" : "No" }}  =>  parse error

# AFTER (fixed):
# {{ status == "active" ? "Yes" : "No" }}  =>  "Yes"
```

### v3.10.16 -- Template Filters: to_json, js_escape (March 28)

Three new Frond template filters for working with data in JavaScript contexts.

```ruby
# Convert a Ruby hash to JSON inside a template:
<script>
  const data = {{ user|to_json }};
  const name = "{{ user.name|js_escape }}";
</script>
```

### v3.10.15 -- Replace Filter Backslash Fix (March 28)

**Bug fix:** The `|replace` filter mishandled backslash characters in replacement strings.

```twig
{# Before (broken) — backslash produced corrupted output #}
{{ "hello\\world"|replace("\\\\", "/") }}
{# rendered: helo/world (ate a character) #}

{# After (fixed) — backslash escaping works correctly #}
{{ "hello\\world"|replace("\\\\", "/") }}
{# renders: hello/world #}
```

### v3.10.14 -- get_next_id() (March 28)

Pre-generate the next primary key before inserting a record. The method detects your database engine and uses the correct sequence or auto-increment mechanism.

```ruby
next_id = User.get_next_id
user = User.new(id: next_id, name: "Alice")
user.save
```

### v3.10.13 -- ORM Auto-Commit on Write (March 28)

Write operations (`save`, `delete`) now auto-commit by default. No more forgotten `commit` calls leaving data uncommitted.

### v3.10.12 -- Session GC and NATS Backplane (March 28)

- Session garbage collection runs on a configurable interval
- NATS added as a WebSocket backplane option alongside Redis

### v3.10.11 -- Frond Variable Key Access (March 28)

**Bug fix:** Accessing a hash value with a variable key (`dict[variable_key]`) failed in Frond templates.

```ruby
# BEFORE (broken):
# {% set key = "name" %}
# {{ user[key] }}  =>  empty

# AFTER (fixed):
# {% set key = "name" %}
# {{ user[key] }}  =>  "Alice"
```

### v3.10.10 -- Firebird Migration Runner Fixes (March 28)

Firebird migrations now use generators and `VARCHAR` instead of `AUTOINCREMENT` and `TEXT`. The migration tracking table uses a proper Firebird sequence (`GEN_TINA4_MIGRATION_ID`).

### v3.10.6 -- WSDL/SOAP Rewrite (March 28)

Complete rewrite of the WSDL/SOAP module. Frond templates now support dotted function names in expressions.

### v3.10.5 -- Frond Quote-Aware Operator Matching (March 28)

**Bug fix:** Operators inside quoted strings were incorrectly parsed as expression operators. The Frond engine now respects quote boundaries.

### v3.10.4 -- Auto-CRUD REST Endpoint Generator (March 28)

Generate a complete CRUD interface from a single method call. The generator creates searchable, sortable, paginated HTML tables with create/edit/delete modals, plus REST API routes for POST, PUT, and DELETE.

```ruby
Tina4::Router.get("/admin/users") do |request, response|
  Tina4::CRUD.to_crud(request, model: User, fields: [:name, :email, :role])
end
```

### v3.10.2 -- Frond Hash Method Calls (March 28)

Frond templates can now call methods on Hash and object values inside expressions.

### v3.10.1 -- autoMap and Case Conversion (March 28)

- `auto_map` class attribute added to ORM for cross-language API parity (no-op in Ruby since `snake_case` is native)
- `Tina4.snake_to_camel("my_field")` returns `"myField"`
- `Tina4.camel_to_snake("myField")` returns `"my_field"`

### v3.10.0 -- Optimized For-Loops (March 28)

The Frond template engine rewrote its for-loop renderer. Templates with large iteration counts render faster.

---

## v3.9.x

**Released:** March 26 -- 27, 2026

### v3.9.0 -- QueryBuilder, Sessions, Path Injection (March 26)

Three features arrived together.

**QueryBuilder.** A fluent SQL builder that integrates with the ORM.

```ruby
# Through the ORM:
admins = User.query
  .where("role = ?", ["admin"])
  .order_by("name")
  .limit(10)
  .get

# Standalone:
rows = Tina4::QueryBuilder.from("users")
  .where("active = ?", [true])
  .select("name", "email")
  .get
```

The builder supports `where`, `or_where`, `join`, `left_join`, `group_by`, `having`, `order_by`, `limit`, `first`, `count`, `exists`, and `to_sql`.

**Path parameter injection.** Route handlers receive path parameters as named arguments.

```ruby
Tina4::Router.get("/users/{id:int}") do |request, response, id|
  user = User.find(id)
  response.json(user.to_hash)
end
```

**Auto-start sessions.** Every route handler has access to `request.session` with zero configuration. The session API includes `get`, `set`, `delete`, `has`, `clear`, `destroy`, `save`, `regenerate`, `flash`, `get_flash`, and `all`.

### v3.9.1 -- Security Defaults (March 27)

**Breaking change:** POST, PUT, PATCH, and DELETE routes now require authentication by default.

```ruby
# BEFORE (v3.8.x): all routes open
Tina4::Router.post("/api/users") do |request, response|
  # anyone could call this
end

# AFTER (v3.9.1): unauthenticated requests get 401
# To allow public access, add .public:
Tina4::Router.post("/api/users").public do |request, response|
  # open to all
end
```

This release also added:

- CSRF middleware with session-bound form tokens
- Standardized environment variables for CORS headers, session TTL, token limits
- Queue parity: `push` with priority/delay, `size(status)`, `message.retry`

### v3.9.2 -- NoSQL QueryBuilder, WebSocket Backplane (March 27)

- QueryBuilder works with MongoDB
- WebSocket backplane support for multi-process deployments
- `SameSite=Lax` set as the default cookie policy

---

## v3.8.x

**Released:** March 25 -- 26, 2026

### v3.8.0 -- Base64 Filters, Template Cache (March 25)

- `base64encode` and `base64decode` filters in Frond templates
- Production template cache: single filesystem scan at startup, O(1) lookups after

### v3.8.1 -- Security Headers Middleware (March 25)

A built-in middleware that sets `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy`, and `X-Content-Type-Options` on every response.

```ruby
# In your .env:
TINA4_MAX_UPLOAD_SIZE=10485760  # 10 MB (default)
```

Upload size limits and input validation also landed in this release.

### v3.8.2 -- Connection Pooling (March 26)

Database connections now pool. Pass `pool: N` to the constructor for round-robin, mutex-protected pooling.

```ruby
db = Tina4::Database.new("sqlite://data.db", pool: 5)
```

### v3.8.3 -- Claude Code Commands (March 26)

Seventeen `.claude/commands/` slash commands shipped for AI-assisted development.

### v3.8.7 -- Benchmark and Stability (March 26)

- Keyword argument fix for `run!()`: `port:`, `host:`, and `debug:` no longer crash the environment loader
- Updated benchmarks against Roda, Sinatra, and Rails

---

## v3.7.x

**Released:** March 25, 2026

### v3.7.0 -- Template Auto-Serve, Firebird Migrations (March 25)

The framework serves `index.html` or `index.twig` from `src/templates/` at `/` without a route definition. User-registered `GET /` routes take priority.

Firebird migrations now check `RDB$RELATION_FIELDS` before executing `ALTER TABLE ADD`. Columns that exist are skipped.

### v3.7.1 -- Full Template Auto-Serve (March 25)

Any `.twig` or `.html` file in `src/templates/` is now browsable by URL path. `/hello` serves `src/templates/hello.twig`. Production mode caches the lookup table at startup.

---

## v3.6.x

**Released:** March 25, 2026

### v3.6.0 -- Architectural Parity (March 25)

**Breaking change:** `fetch(skip:)` is replaced by `fetch(offset:)`. No alias.

```ruby
# BEFORE (v3.5.x):
users = User.fetch(limit: 10, skip: 20)

# AFTER (v3.6.0):
users = User.fetch(limit: 10, offset: 20)
```

Other changes:

- Source directories follow the `src/` prefix convention across all languages
- `TINA4_LOCALE` is the only supported locale environment variable (other names removed)
- Migration file paths standardized to `src/migrations/`

---

## v3.5.x

**Released:** March 24, 2026

### v3.5.0 -- Bundled Frontend, Swagger CRUD, Middleware (March 24)

- `tina4js.min.js` (13.6 KB) ships inside the gem. The reactive frontend library loads without a CDN or npm install
- Auto-CRUD routes now include Swagger metadata
- Middleware standardized to `before_*` and `after_*` naming with three built-in middlewares

---

## v3.4.x

**Released:** March 24, 2026

### v3.4.0 -- Auth, WebSocket, DatabaseResult (March 24)

**Breaking change:** Auth method names changed. The old names remain as aliases.

```ruby
# BEFORE (v3.3.x):
token = auth.create_token(payload)
valid = auth.validate_token(token)

# AFTER (v3.4.0 -- preferred):
token = auth.get_token(payload)
valid = auth.valid_token(token)

# Old names still work but are deprecated.
```

**HS256 authentication.** Set `TINA4_AUTH_SECRET` in your `.env` and auth uses HS256. Provide RSA key files and it uses RS256. The framework picks the right algorithm.

```ruby
# .env for HS256:
TINA4_AUTH_SECRET=my-secret-key

# .env for RS256:
TINA4_AUTH_PRIVATE_KEY=keys/private.pem
TINA4_AUTH_PUBLIC_KEY=keys/public.pem
```

**Bug fix:** Base64url padding in HS256 tokens caused validation failures. Fixed.

**WebSocket improvements:**

- `Router.websocket("/ws/chat")` for route-based WebSocket handlers
- Path-scoped broadcast: messages sent to `/ws/chat` reach only clients connected to that path
- `send_text` renamed to `send` on `WebSocketConnection` (`send_text` kept as alias)

**DatabaseResult enhancements:**

- `columns` returns column names
- `column_info` provides schema metadata (type, nullable, default) on demand
- `to_paginate` formats results for paginated responses

**Frond template additions:**

- Ternary-with-filter: `{{ value ? value|upper : "default" }}`
- `data_uri` filter for inline file display in templates

---

## v3.3.x

**Released:** March 24, 2026

### v3.3.0 -- Queue API, Route Chaining (March 24)

**Breaking change:** `Producer` and `Consumer` classes removed. Use `queue.produce()` and `queue.consume()` directly.

```ruby
# BEFORE (v3.2.x):
producer = Tina4::Producer.new(queue)
producer.send(message)
consumer = Tina4::Consumer.new(queue)
consumer.listen { |msg| handle(msg) }

# AFTER (v3.3.0):
queue.produce("channel", { data: "payload" })
queue.consume("channel") do |job|
  handle(job)
  job.complete
end
```

**Route chaining.** Mark routes as authenticated or cached with chainable modifiers.

```ruby
Tina4::Router.get("/dashboard").secure do |request, response|
  response.html("<h1>Dashboard</h1>")
end

Tina4::Router.get("/static-page").cache(ttl: 3600) do |request, response|
  response.html("<h1>Cached for one hour</h1>")
end
```

Other additions:

- MongoDB queue backend
- Database session handler for full backend parity
- Valkey added to session handler options
- Migration parity: advanced SQL splitting, status tracking, rollback via CLI
- Auto-increment port if the default is in use; browser opens on startup

---

## v3.2.x

**Released:** March 23, 2026

### v3.2.0 -- Flexible Route Handlers (March 23)

Route handlers now accept zero, one, or two parameters. The framework detects what your block expects and provides the right objects.

```ruby
# Zero params -- just return a response:
Tina4::Router.get("/health") { "OK" }

# One param -- response only:
Tina4::Router.get("/hello") { |response| response.html("Hello") }

# Two params -- request and response:
Tina4::Router.get("/echo") do |request, response|
  response.json({ body: request.body })
end

# Named :request or :req -- single param receives the request:
Tina4::Router.post("/submit") { |request| process(request.body) }
```

**Bug fix:** The 500 error overlay crashed because it did not receive the Rack environment. Fixed.

---

## v3.1.x

**Released:** March 21 -- 22, 2026

### v3.1.0 -- ORM Relationships, Caching, Queues (March 22)

The largest feature release after the initial launch. Fourteen capabilities landed in one version.

**ORM relationships.** Define `has_many`, `has_one`, and `belongs_to` with eager loading.

```ruby
class User < Tina4::ORM
  has_many :posts
  has_one :profile
end

class Post < Tina4::ORM
  belongs_to :user
end

user = User.find(1)
user.posts  # => eager-loaded array of Post objects
```

**Caching.** Switch between memory, Redis, and file cache by setting one environment variable.

```ruby
# .env:
TINA4_CACHE=redis
TINA4_CACHE_REDIS_URL=redis://localhost:6379

# Code stays the same:
Tina4::Cache.set("key", "value", ttl: 300)
Tina4::Cache.get("key")
```

**Database query caching.** Set `TINA4_DB_CACHE=true` for transparent query result caching.

**Queue system.** Switch between SQLite, RabbitMQ, and Kafka via `.env` without changing code.

**Messenger.** Unified messaging driven by environment configuration.

**Scaffolding.** `tina4 generate model User`, `tina4 generate route api/users`, `tina4 generate migration create_users`, `tina4 generate middleware auth`.

**Frond template engine.** `raw`/`endraw` blocks and `from` imports.

**Performance.** Frond pre-compilation caches parsed tokens. File rendering runs faster.

**Other additions:**

- Production server auto-detection (Puma, cluster mode)
- GitHub Actions CI/CD
- Error pages: clean 404/500/403 without branding
- `numeric_field` type in ORM
- `truthy?()` helper method
- Log rotation

### v3.1.1 -- DevMailbox Fix (March 22)

**Bug fix:** DevMailbox timestamp precision was insufficient for reliable sort ordering.

### v3.1.2 -- Documentation Fixes (March 22)

README code examples updated to match the actual v3 API. Quick start guide added.

---

## v3.0.x

**Released:** March 21, 2026

### v3.0.0 -- Initial Release (March 21)

The ground-up rewrite. Zero gem dependencies. Everything the framework needs -- HTTP server, template engine, ORM, migrations, auth, queue, GraphQL, WebSocket, WSDL -- ships inside a single gem.

**Core features:**

- Rack-based HTTP server (compatible with Puma, Thin, WEBrick)
- Frond template engine (Twig-compatible syntax)
- ORM with support for SQLite, PostgreSQL, MySQL, MSSQL, and Firebird
- JWT authentication (RS256)
- Queue system
- GraphQL endpoint
- WebSocket server
- WSDL/SOAP service generation
- DevAdmin dashboard with developer tooling
- AI coding tool integration (auto-detect and install context for seven tools)
- Full test suite passing

**Quick start:**

```ruby
require "tina4"

Tina4::Router.get("/") { |request, response| response.html("<h1>Hello Tina4!</h1>") }

Tina4::App.new.run
```

```bash
gem install tina4-ruby
```

The server starts on port 7147 by default. Set `host: "0.0.0.0"` for Docker deployments.

---

## Pre-Release (v0.x)

**Released:** March 18, 2026

Versions v0.4.0 through v0.5.2 were development previews. They established the gem structure and basic routing but lacked the ORM, template engine, and queue system. If you used a v0.x release, upgrade directly to v3.0.0 -- there is no migration path from v0.x.
