# Chapter 30: Release Notes

## Version History

Tina4 Python follows semantic versioning. The major version (3) marks the ground-up rewrite from v2. Minor versions (3.1, 3.2, ...) introduce features. Patch versions fix bugs and polish edges.

Every release ships through PyPI. Upgrade with:

```bash
uv add tina4-python@latest

# or with pip
pip install --upgrade tina4-python
```

Check your current version:

```python
import tina4_python
print(tina4_python.__version__)
```

---

## v3.10.48 — April 2, 2026

### Bug Fixes

**Production server explicit opt-in** — All frameworks now require an explicit `--production` flag to use production servers (Puma for Ruby, FrankenPHP for PHP, cluster mode for Node.js). Previously, production servers activated automatically when `TINA4_DEBUG=false`, which was surprising behaviour. Now `tina4 serve` always uses the dev server unless `--production` is passed.

**Python `--no-browser`** — The `run()` function now accepts `no_browser=True` and respects the `TINA4_NO_BROWSER` env var to prevent browser auto-opening on server start.

### Test Coverage

Python: 2,132. PHP: 1,992. Ruby: 2,387. Node.js: 2,546. Total: 9,057 tests, 0 failures.

---

## v3.10.46 — April 1, 2026

### Test Coverage

Massive test parity push across all 4 frameworks. CSRF middleware tests expanded to 29+ per framework. Dedicated test suites added for FakeData, Cache, DevMailbox, Static files, Metrics, CLI scaffolding, and all remaining gap areas. Python: 2,132 tests. PHP: 1,937. Ruby: 2,274. Node.js: 2,546. Total: 8,889 tests, 0 failures, 49 core areas with full parity.

---

## v3.10.45 — April 1, 2026

### Bug Fixes

**PHP CLI serve hijack** — When `index.php` calls `App::run()`, the CLI `serve` command now sets a `TINA4_CLI_SERVE` constant so `run()` returns early, letting the CLI manage the server lifecycle (port, debug mode, browser open). Previously, `index.php`'s `run()` would start its own server and block the CLI's serve logic.

---

## v3.10.44 — April 1, 2026

### New Features

**Database tab redesign** — The dev admin Database panel now uses a split-screen layout. Tables are listed on the left as a navigation sidebar with click-to-select highlighting. The query editor, toolbar, and results occupy the right panel. Results render immediately below the query box with no gap.

**Copy CSV / Copy JSON** — Two new buttons in the database toolbar copy query results to the clipboard. CSV uses proper comma-separated format with quoting; JSON copies a formatted array of objects.

**Paste data** — A new Paste button opens a modal where you can paste JSON arrays or CSV/tab-separated data. The tool auto-detects the format and generates INSERT statements. If a table is selected on the left, it targets that table. If no table is selected, it prompts for a name and generates a CREATE TABLE statement for new tables. If you paste SQL directly, it passes through to the query box unchanged.

**Multi-statement execution** — The query runner now handles multiple SQL statements separated by semicolons. CREATE TABLE + INSERT batches run in a single transaction with automatic rollback on error.

**Database badge on load** — The Database tab count badge now shows the table count immediately when the dev admin opens, without needing to click the tab first.

**Star wiggle animation** — The GitHub star button on the landing page uses an empty star (☆) with a playful wiggle animation: 3-second delay on page load, then wiggles at random 3–18 second intervals.

### Bug Fixes

**Default port** — Python default port changed from 7145 to 7146 to avoid clashes when running multiple Tina4 frameworks (PHP=7145, Python=7146, Ruby=7147, Node=7148).

**SQLite LIMIT fix** — The SQLite adapter now checks if a query already contains a LIMIT clause before appending one, preventing double-LIMIT errors in the database browser.

**browseTable quote escaping** — Fixed broken onclick handlers for table names in the database panel. Now uses `addEventListener` instead of inline onclick with escaped quotes.

**Migration UP/DOWN separation** — Migration generator no longer puts DOWN SQL in the .sql file. UP SQL stays in the .sql file; DOWN SQL goes in the separate .down.sql file.

### Test Coverage

Major test expansion across all 4 frameworks — 8,107 total tests (up from ~5,200), with full parity across 49 core feature areas. New dedicated test suites added for FakeData, Cache, DevMailbox, Static files, Metrics, and CLI scaffolding.

Python: 2,132 tests passing (12 skipped).

---

## v3.10.40 — April 1, 2026

### Bug Fixes

**Dev overlay version check** — Fixed misleading "You are up to date" message when running a version ahead of what's published on PyPI (e.g. running v3.10.39 locally while PyPI still has v3.10.24). The overlay now shows a purple "ahead of PyPI" message. Also added a breaking changes warning (red banner with changelog link) when a major or minor version update is available, so developers know to check for breaking changes before upgrading.

---

## v3.10.39 — April 1, 2026

### Breaking Changes

This release aligns the Python framework with the other three Tina4 implementations. Two breaking changes affect existing code:

**`Auth.check_password()` parameter order reversed**

```python
# BEFORE (v3.10.38 and earlier)
Auth.check_password(hashed, password)

# AFTER (v3.10.39+)
Auth.check_password(password, hashed)  # password first — matches PHP, Ruby, Node.js
```

**`Router.all()` removed — use `get_routes()` or `list_routes()`**

```python
# BEFORE
routes = Router.all()

# AFTER
routes = Router.get_routes()   # or Router.list_routes()
```

### New Features

**`Auth.validate_api_key(provided, expected=None)`**

Compare API keys with constant-time comparison. Optionally pass `expected`; if omitted, reads `TINA4_API_KEY` (or `API_KEY`) from environment.

```python
Auth.validate_api_key("sk-abc123")              # check against env
Auth.validate_api_key("sk-abc123", "sk-abc123") # check against explicit value
```

**`Auth.authenticate_request(headers)`**

One-call header authentication: checks Bearer JWT, Bearer API key, and Basic auth in order.

```python
payload = Auth.authenticate_request(request.headers)
# Returns: dict on success, None on failure
```

**`ORM.find_by_id(pk)` with `find()` and `load()` as aliases**

`find_by_id()` is now the explicit primary method. Both `find()` and `load()` continue to work as aliases, ensuring backward compatibility.

### Test Coverage

2,054 tests passing (up from 2,051 in v3.10.38).

---

## v3.10.38 — April 1, 2026

### Code Metrics & Bubble Chart

The dev dashboard (`/__dev`) now includes a **Code Metrics** tab with a PHPMetrics-style bubble chart visualization. Files are represented as animated bubbles — sized by lines of code, colored by maintainability index (green = healthy, red = needs attention). Click any bubble to drill down into per-function cyclomatic complexity.

The metrics engine uses Python's `ast` module for zero-dependency static analysis:
- Cyclomatic complexity per function
- Halstead volume and maintainability index
- Afferent/efferent coupling and instability
- Violation detection (CC > 20, LOC > 500, MI < 20)

File analysis is sorted worst-first so problem areas surface immediately. Results are cached for 60 seconds with mtime-based invalidation.

### AI Context Installer

The `tina4python ai` command now presents a simple numbered menu instead of unreliable auto-detection:

```
  1. Claude Code        CLAUDE.md              [installed]
  2. Cursor             .cursorules
  3. GitHub Copilot     copilot-instructions.md
  ...
  8. Install tina4-ai tools (requires Python)
```

Select by number (comma-separated or `all`). Already-installed tools show green. The generated context now includes the full skills table across all frameworks.

### Dashboard Improvements

- Full-width layout (removed 1400px max-width constraint)
- Sticky header and tab bar when scrolling
- Dashboard overlay fills the screen (was constrained to 1200px)

### Cleanup

- Removed `demo/` directories from all framework repos (demos live in documentation)
- Removed old `plan/` spec documents, replaced with `PARITY.md` and `TESTS.md`
- Removed junk sample files (broken migrations, test templates)
- Central parity matrix added to tina4-book

---

## v3.10.x — Previous Releases (March 28-31, 2026)

The v3.10 line carries the most patches of any minor release. It refined the Frond template engine, hardened the ORM, and completed cross-framework parity.

### Highlights

- **Singleton Frond engine** (v3.10.0). The template engine creates one instance and reuses it. Previous versions spawned a new engine per render call. This cut template rendering overhead across the board.

- **ORM `auto_map` flag** (v3.10.1). Models translate between `snake_case` and `camelCase` column names without manual mapping.

```python
from tina4_python import ORM

class UserProfile(ORM):
    auto_map = True  # created_at ↔ createdAt handled for you
    table_name = "user_profiles"
```

- **Frond method calls and slice syntax** (v3.10.2). Templates gained the ability to call methods on objects and use Python slice syntax.

```html
<!-- Method calls on template variables -->
{{ user.get_display_name() }}

<!-- Slice syntax -->
{{ long_text[:100] }}...
```

- **Frond quote-aware operator matching** (v3.10.5). Operators inside quoted strings no longer break the parser. Before this fix, a string containing `>=` or `==` could confuse the template engine.

- **ORM auto-commit on write operations** (v3.10.13). Save, delete, and update operations commit their transactions without an explicit call.

- **`to_json` and `js_escape` filters** (v3.10.16). Templates gained filters for safe JSON embedding and JavaScript string escaping.

```html
<script>
  const config = {{ settings|to_json }};
  const message = "{{ user_input|js_escape }}";
</script>
```

- **`formTokenValue()` helper** (v3.10.23). CSRF tokens gained a dedicated template function for cleaner form markup.

```html
<form method="post">
  <input type="hidden" name="form_token" value="{{ formTokenValue() }}">
  <!-- form fields -->
</form>
```

- **MCP server and TestClient parity** (v3.10.32). The built-in MCP server and integration test client reached feature parity with the PHP and Ruby implementations.

- **Arithmetic in `{% set %}` and expressions** (v3.10.31). The template engine handles math operations inside assignment blocks.

```html
{% set total = price * quantity + shipping %}
```

### Bug Fixes

**Middleware not applied to routes (fixed in v3.10.1).** Middleware functions registered with `@middleware` were silently skipped during route dispatch. Routes ran without their middleware.

```python
# Before (broken) — middleware was silently skipped
@app.middleware
def log_request(request, response):
    print(f"Request: {request.method} {request.url}")
    return request, response

@app.get("/users")
def get_users(request, response):
    # middleware never ran
    return response("OK")
```

```python
# After (fixed in v3.10.1) — middleware runs on every matching route
@app.middleware
def log_request(request, response):
    print(f"Request: {request.method} {request.url}")
    return request, response

@app.get("/users")
def get_users(request, response):
    # log_request fires before this handler
    return response("OK")
```

**Wildcard route matching (fixed in v3.10.1).** Routes with wildcard segments failed to match incoming requests. The router now handles wildcards as expected.

**`Auth.valid_token` reference error (fixed in v3.10.9).** The internal server module referenced the wrong attribute name when calling token validation, which caused a `TypeError` on every secured request. The fix resolved the reference so `Auth.valid_token` works as expected.

**Frond `dict[variable_key]` access (fixed in v3.10.11).** Accessing a dictionary with a variable key inside templates raised a `KeyError`. The engine now resolves the variable before the lookup.

```html
<!-- Before (broken) — raised KeyError -->
{% set key = "name" %}
{{ user[key] }}

<!-- After (fixed in v3.10.11) — resolves variable, then looks up the key -->
{% set key = "name" %}
{{ user[key] }}  <!-- now outputs user["name"] -->
```

**ORM transaction errors on SQLite (fixed in v3.10.25).** Calling `save()` or `delete()` on an ORM model raised `"cannot commit -- no transaction is active"` on SQLite. The ORM now wraps every write operation in a proper `start_transaction` / `commit` / `rollback` cycle.

```python
# Before (broken on SQLite)
user = User()
user.name = "Alice"
user.save()  # raised "cannot commit -- no transaction is active"

# After (fixed in v3.10.25) — save() wraps in a transaction automatically
user = User()
user.name = "Alice"
user.save()  # works on all database engines including SQLite
```

**Stale templates in dev mode (fixed in v3.10.24).** The dev server cached rendered templates and did not pick up file changes until restart. Templates now reload on every request in debug mode.

**Macro output HTML escaping (fixed in v3.10.27).** Frond macros returned raw strings that the auto-escaper then double-escaped. Macro output now wraps in `SafeString` to preserve the intended HTML.

**DevReload performance (fixed in v3.10.28).** The live-reload watcher polled too fast and triggered duplicate reloads. It now uses a 3-second default interval with debouncing.

### Breaking Changes

**`@noauth` and `@secured` decorator behavior (v3.10.1).** Before this fix, these decorators did not update the route's auth flags. If you relied on the broken behavior (routes ignoring auth decorators), your routes will now enforce authentication as intended.

```python
# Before (broken) — decorator had no effect
@app.get("/public")
@noauth
def public_page(response):
    return response("Open to all")  # still required auth

# After (fixed in v3.10.1) — decorator works as expected
@app.get("/public")
@noauth
def public_page(response):
    return response("Open to all")  # accessible without token
```

---

## v3.9.x — QueryBuilder and Sessions (March 26-27, 2026)

### Features

**QueryBuilder with fluent API (v3.9.0).** SQL construction through method chaining, integrated with the ORM.

```python
from tina4_python import ORM

class User(ORM):
    table_name = "users"

# Fluent query through the ORM
admins = User.query() \
    .where("role = ?", ["admin"]) \
    .order_by("name") \
    .limit(10) \
    .get()

# Standalone query
from tina4_python import QueryBuilder

results = QueryBuilder.table("orders") \
    .select("customer_id", "SUM(total) as revenue") \
    .where("status = ?", ["completed"]) \
    .group_by("customer_id") \
    .having("revenue > ?", [1000]) \
    .get()
```

**Path parameter injection (v3.9.0).** Route handlers receive path parameters as named function arguments. No more digging through `request.params`.

```python
# Before v3.9.0
@app.get("/users/{id}")
def get_user(request, response):
    user_id = request.params["id"]
    return response(f"User {user_id}")

# v3.9.0 and later
@app.get("/users/{id:int}")
def get_user(id, request, response):
    return response(f"User {id}")  # id is already an int
```

**Auto-start sessions (v3.9.0).** Every route handler receives `request.session` with zero configuration. The session API covers `get`, `set`, `delete`, `has`, `clear`, `destroy`, `regenerate`, `flash`, and `get_flash`.

```python
@app.get("/dashboard")
def dashboard(request, response):
    visits = request.session.get("visits", 0)
    request.session.set("visits", visits + 1)
    return response(f"Visit #{visits + 1}")
```

**CSRF middleware and form tokens (v3.9.1).** Session-bound CSRF tokens protect forms by default. Toggle with the `TINA4_CSRF_ENABLED` environment variable.

```python
# CSRF is on by default in v3.9.1+
# Disable for API-only apps:
# TINA4_CSRF_ENABLED=false
```

**File-based queue backend (v3.9.1).** Replaced the SQLite queue with a JSON file-based backend. Zero dependencies. Full cross-platform parity with the PHP and Ruby implementations.

**NoSQL QueryBuilder (v3.9.2).** The fluent API gained `to_mongo()` to generate MongoDB queries from the same builder syntax.

```python
query = QueryBuilder.table("users") \
    .where("age > ?", [21]) \
    .order_by("name") \
    .limit(10) \
    .to_mongo()
# Returns a MongoDB-compatible query dict
```

**WebSocket backplane (v3.9.2).** Redis pub/sub for scaling WebSocket broadcast across multiple server instances.

**SameSite cookie default (v3.9.2).** Session cookies default to `SameSite=Lax`. Override with the `TINA4_SESSION_SAMESITE` environment variable.

### Breaking Changes

**Session API rename (v3.9.0).** The `unset()` method became `delete()` for cross-framework parity. `unset()` still works as an alias but will show a deprecation warning in future releases.

```python
# Before
request.session.unset("cart")

# After
request.session.delete("cart")
```

**Environment variable standardization (v3.9.1).** All framework environment variables now follow the `TINA4_*` naming convention. `TOKEN_LIMIT` became `TINA4_TOKEN_LIMIT`. Check your `.env` file and rename any bare variables.

**Queue backend change (v3.9.1).** The SQLite queue backend no longer exists. If you used it, the file-based backend is a drop-in replacement. Queue data from the old SQLite store must be migrated manually.

---

## v3.8.x — Pooling, Validation, and Security (March 25-26, 2026)

### Features

**Connection pooling (v3.8.1).** Pass `pool=N` to the `Database` constructor for round-robin, thread-safe connection pooling.

```python
from tina4_python import Database

db = Database("sqlite:///app.db", pool=4)
# Four connections rotate across requests
```

**Validator class (v3.8.1).** Input validation with an error response envelope.

```python
from tina4_python import Validator

errors = Validator.validate(request.body, {
    "email": "required|email",
    "age": "required|integer|min:18"
})

if errors:
    return response({"errors": errors}, 422)
```

**Upload size limit (v3.8.1).** The `TINA4_MAX_UPLOAD_SIZE` environment variable caps file uploads. Set it in bytes.

**TestClient for integration tests (v3.8.1).** Test your routes without starting the server.

```python
from tina4_python import TestClient

client = TestClient(app)
result = client.get("/api/users")
assert result.status_code == 200
```

**SecurityHeadersMiddleware (v3.8.1).** One import adds `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy`, and `X-Content-Type-Options` to every response.

```python
from tina4_python import SecurityHeadersMiddleware

app.use(SecurityHeadersMiddleware())
```

**Zero core dependencies (v3.8.x).** Database drivers, queue backends, and session handlers became optional installs. The core framework runs on Python's standard library alone.

---

## v3.7.x — Template Auto-Serve and Firebird Fixes (March 25, 2026)

### Features

**Template auto-serve at `/` (v3.7.0).** Place an `index.html` or `index.twig` in `src/templates/` and the framework serves it at the root path. User-registered `GET /` routes take priority.

```
src/
  templates/
    index.html   ← served at / with no route needed
```

**Firebird idempotent migrations (v3.7.0).** `ALTER TABLE ADD` statements on Firebird check `RDB$RELATION_FIELDS` before executing. Columns that already exist are skipped. Other databases and statement types are not affected.

---

## v3.6.x — API Parity (March 24, 2026)

### Breaking Changes

**Auth method renames (v3.6.0).** The authentication API aligned with the PHP, Ruby, and Node.js implementations.

```python
# Before v3.6.0
from tina4_python import Auth

token = Auth.create_token(payload)       # old name
valid = Auth.validate_token(token)       # old name
```

```python
# v3.6.0 and later
from tina4_python import Auth

token = Auth.get_token(payload)          # new primary name
valid = Auth.valid_token(token)          # new primary name
# create_token and validate_token still work as aliases
```

**Pagination parameter rename (v3.6.0).** `skip` became `offset` across all query methods.

```python
# Before
users = User.find(skip=10, limit=5)

# After
users = User.find(offset=10, limit=5)
```

**Token expiry parameter rename (v3.6.0).** `token_expiry` became `expires_in` and now accepts minutes instead of seconds.

```python
# Before
token = Auth.create_token(payload, token_expiry=3600)  # seconds

# After
token = Auth.get_token(payload, expires_in=60)          # minutes
```

**Locale environment variable (v3.6.0).** `LOCALE` became `TINA4_LOCALE`. Update your `.env` file.

---

## v3.5.x — Bundled Frontend (March 24, 2026)

### Features

**tina4js bundled (v3.5.0).** The reactive frontend library (13.6 KB minified) ships with the framework. No CDN link needed. Import it from your templates and build reactive UIs with signals, components, and declarative routing.

**AutoCrud Swagger metadata (v3.5.0).** Routes generated by `AutoCrud` now include Swagger annotations. They appear in the auto-generated API docs without extra configuration.

---

## v3.3.x — WebSockets, File Uploads, and Frond Improvements (March 24, 2026)

### Features

**Route-based WebSocket handlers (v3.3.0).** Define WebSocket endpoints with the same decorator pattern as HTTP routes.

```python
@app.websocket("/ws/chat")
def chat_handler(message, client):
    # message is the incoming data
    # client.send() to reply
    client.send(f"Echo: {message}")
```

**File upload improvements (v3.3.0).** Uploaded files include raw bytes, a `data_uri` template filter, and consistent property names across all frameworks.

```python
@app.post("/upload")
def handle_upload(request, response):
    file = request.files[0]
    print(file.filename)    # standardized from file_name
    print(file.type)        # new in v3.3.0
    raw = file.content      # raw bytes
    return response("Uploaded")
```

**Lazy `column_info()` on DatabaseResult (v3.3.0).** Query results expose schema metadata on demand. Call `result.column_info()` to inspect column names, types, and sizes without a separate query.

**`@any` decorator alias (v3.3.0).** `@any` works as shorthand for `@any_method`, matching the PHP, Ruby, and Node.js API.

**Ternary-with-filter support in Frond (v3.3.0).** Templates handle inline conditionals that pipe their result through a filter.

```html
{{ user.name if user else "Anonymous"|upper }}
```

### Breaking Changes

**`job.data` renamed to `job.payload` (v3.3.0).** Queue jobs use `payload` as the primary attribute. `job.data` remains as a read-only property alias but will be removed in a future release.

```python
# Before
@app.consume("emails")
def send_email(job):
    to = job.data["to"]

# After
@app.consume("emails")
def send_email(job):
    to = job.payload["to"]
```

**File upload property rename (v3.3.0).** `file_name` became `filename` (no underscore). The old name is no longer available.

```python
# Before
name = request.files[0].file_name

# After
name = request.files[0].filename
```

**Route params merged into `request.params` (v3.3.0).** Path parameters now merge into `request.params` alongside query parameters. If a query parameter shares a name with a path parameter, the path parameter wins.

---

## v3.2.x — Flexible Route Handlers and DevReload (March 24, 2026)

### Features

**Flexible handler signatures (v3.2.0).** Route handlers accept any combination of parameters. The framework inspects the signature and injects what you ask for.

```python
# No parameters — fire and forget
@app.get("/ping")
def ping():
    return "pong"

# Response only
@app.get("/hello")
def hello(response):
    return response("Hello")

# Request only (type-hinted)
@app.post("/echo")
def echo(request: Request):
    return request.body

# Both
@app.get("/users")
def users(request, response):
    return response({"users": []})
```

**DevReload with SCSS compilation (v3.2.0).** The development server watches for file changes and reloads the browser. SCSS files compile on change.

**Route groups (v3.2.0).** Group routes under a shared prefix with shared middleware.

**MongoDB queue backend (v3.2.0).** Use MongoDB as a queue backend alongside the existing file-based, RabbitMQ, and Kafka options.

**Migration naming convention (v3.2.0).** Migration files follow the `YYYYMMDDHHMMSS` timestamp format. The `tina4 migrate status` command shows which migrations have run.

**Auto-increment port (v3.2.0).** If the default port is in use, the framework picks the next available port and opens your browser.

### Breaking Changes

**Queue constructor simplified (v3.2.0).** The `db` parameter was removed from the Queue constructor. The queue reads its backend from the environment.

```python
# Before
from tina4_python import Queue, Database
db = Database("sqlite:///queue.db")
queue = Queue("emails", db=db)

# After
from tina4_python import Queue
queue = Queue("emails")
# Backend set via TINA4_QUEUE_BACKEND env var
```

**Producer/Consumer classes removed (v3.2.0).** Use `queue.produce()` and `queue.consume()` directly.

```python
# Before
from tina4_python import Producer, Consumer
producer = Producer(queue)
producer.send({"to": "user@example.com"})

# After
queue.produce({"to": "user@example.com"})
```

---

## v3.1.x — Benchmarks and Internal Improvements (March 22, 2026)

### Features

**Automated benchmark suite (v3.1.0).** A reproducible benchmark compares Tina4 Python against 17 frameworks across four languages. Run it yourself with `python benchmarks/run.py`.

No user-facing API changes in this release. Internal improvements to test infrastructure and benchmark tooling.

---

## v3.0.0 — The Rewrite (March 22, 2026)

The v3.0.0 release replaced the entire v2 codebase. Zero external dependencies. Pure Python standard library. 38 features. Over 6,000 tests.

### What Changed

- **New module structure.** `tina4_python.core` replaces the old flat namespace.
- **Frond template engine.** Built-in Twig-compatible templates replace the Jinja2 dependency. Pre-compilation caches tokens for a 2.8x speedup on file renders.
- **Decorator-based routing.** `@app.get`, `@app.post`, `@app.put`, `@app.delete`, `@app.patch` replace the old `Route` class.
- **Built-in Dev Admin.** A browser-based dashboard shows routes, database tables, and queue status.
- **Error overlay in debug mode.** Stack traces render in the browser with source context, request details, and suggested fixes.
- **Swagger auto-registration.** Decorated routes appear in the Swagger UI without manual annotation.
- **Unified queue system.** Switch between file-based, RabbitMQ, and Kafka backends through environment variables. No code changes.
- **Database query caching.** Set `TINA4_DB_CACHE=true` for transparent caching with a 4x speedup on repeated queries.
- **`tina4 generate` scaffolding.** Generate models, routes, migrations, and middleware from the command line.
- **Custom error pages.** Self-contained 404, 403, and 500 pages with clean, framework-neutral design.

For the full migration guide, see Chapter 29: Upgrading from v2 to v3.

---

## Release Candidate History

Five release candidates preceded the v3.0.0 stable release between March 21-22, 2026. They resolved test failures, polished the Dev Admin UI, added the benchmark suite, and stabilized the Frond template engine. If you tested a release candidate, upgrade to v3.0.0 or later. The RC builds are not supported.
