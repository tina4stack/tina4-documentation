# Chapter 30: Release Notes

## Version History

Tina4 PHP follows semantic versioning. The major number changes when something breaks. The minor number changes when something new arrives. The patch number changes when something gets fixed. Each release is available on Packagist.

This chapter covers the full v3 line -- from the first release candidate through the current stable release. If you are upgrading from v2, read Chapter 29 first. It covers every breaking change and gives you a migration checklist.

---

## v3.10.48 — April 2, 2026

### Bug Fixes

**FrankenPHP requires `--production` flag** — FrankenPHP no longer auto-detected when debug is off. Use `tina4php serve --production` to enable it. Gallery tests (19) and live reload tests (36) added. Fixed `DotEnv::load()` → `DotEnv::loadEnv()` in Server.php.

---

## v3.10.46 — April 1, 2026

### Test Coverage

Massive test expansion — 605 new tests added across session handlers, queue backends, database drivers, Frond template engine, dev admin, ORM, auth, seeder, log, service runner, container, CORS, form token, HTML element, migration, i18n, events, SCSS, CRUD, rate limiter, and CSRF middleware. PHP now at 1,937 tests with full parity across all 49 core areas.

### Bug Fixes

**CSRF query param check** — Fixed `$request->params` shadowing `$request->query` in the CSRF middleware, so query string token detection now works correctly.

---

## v3.10.45 — April 1, 2026

### Bug Fixes

**CLI serve hijack** — When `index.php` calls `App::run()`, the CLI `serve` command now sets a `TINA4_CLI_SERVE` constant so `run()` returns early, letting the CLI manage the server lifecycle (port, debug mode, browser open).

---

## v3.10.44 — April 1, 2026

### New Features

**Database tab redesign** — The dev admin Database panel now uses a split-screen layout. Tables are listed on the left as a navigation sidebar with click-to-select highlighting. The query editor, toolbar, and results occupy the right panel.

**Copy CSV / Copy JSON** — Two new buttons in the database toolbar copy query results to the clipboard in CSV or JSON format.

**Paste data** — A Paste button opens a modal for pasting JSON arrays or CSV/tab-separated data. Auto-detects the format and generates INSERT statements. Prompts for a table name if none is selected, and generates CREATE TABLE for new tables. SQL input passes through unchanged.

**Multi-statement execution** — The query runner handles multiple SQL statements separated by semicolons, running them in a single transaction with automatic rollback on error.

**Database badge on load** — The Database tab count badge shows the table count immediately on page load.

**Star wiggle animation** — The GitHub star button on the landing page uses an empty star (☆) with a wiggle animation: 3-second delay, then wiggles at random 3–18 second intervals.

### Bug Fixes

**Default port** — PHP default port confirmed as 7145 (PHP=7145, Python=7146, Ruby=7147, Node=7148).

**SQLite LIMIT fix** — Prevents double-LIMIT errors when browsing tables in the dev admin.

**browseTable quote escaping** — Fixed broken onclick handlers for table names using addEventListener.

**Frond template engine** — Fixed string concatenation (`~` operator) and inline if/else expressions (`{{ 'yes' if active else 'no' }}`). A greedy quoted-string fallback in `evaluateLiteral()` was treating compound expressions as single string literals.

### Test Coverage

Major test expansion — 200 new tests added (FakeData 42, Cache 30, DevMailbox 33, Static files 31, Metrics 20, CLI scaffolding 31, plus v3.10.44 feature tests). 1,532 tests passing, 0 failures.

---

## v3.10.40 — April 1, 2026

### Bug Fixes

**Dev overlay version check** — Fixed misleading "You are up to date" message when running a version ahead of what's published on Packagist. The overlay now shows a purple "ahead of Packagist" message. Also added a breaking changes warning (red banner with changelog link) when a major or minor version update is available.

---

## v3.10.39 — April 1, 2026

### Breaking Changes

**`Auth::hashPassword()` — separator changed from `:` to `$`**

The password hash format now uses `$` as a separator (matching Python, Ruby, and Node.js):

```
# BEFORE: pbkdf2_sha256:100000:salt:hash
# AFTER:  pbkdf2_sha256$100000$salt$hash
```

Existing hashed passwords stored in your database **will not verify** after upgrade. Rehash passwords on next user login:

```php
if (!Auth::checkPassword($password, $storedHash)) {
    // try old format first, then rehash
}
```

**`Database::update()` and `Database::delete()` filter signature changed**

```php
// BEFORE (v3.10.38 and earlier) — associative array filter
$db->update('users', ['name' => 'Alice'], ['id' => 1]);
$db->delete('users', ['id' => 1]);

// AFTER (v3.10.39+) — SQL string + params (matches Python, Ruby, Node.js)
$db->update('users', ['name' => 'Alice'], 'id = ?', [1]);
$db->delete('users', 'id = ?', [1]);
```

**`Router::list()` removed — use `Router::getRoutes()` or `Router::listRoutes()`**

```php
// BEFORE
$routes = Router::list();

// AFTER
$routes = Router::getRoutes();   // or Router::listRoutes()
```

### New Features

**`ORM::findById(int|string $id)`** — explicit primary method (with `find()` and `load()` as aliases).

**`Session`: `TINA4_SESSION_HANDLER` env var** — replaces `TINA4_SESSION_BACKEND` (old name still accepted for backward compatibility).

**`Session\RedisSessionHandler`** — new zero-dependency Redis session handler using raw RESP protocol over TCP sockets. Configure with `TINA4_SESSION_REDIS_HOST`, `TINA4_SESSION_REDIS_PORT`, `TINA4_SESSION_REDIS_PASSWORD`, `TINA4_SESSION_REDIS_DB`.

**`Database::cacheStats()` and `Database::cacheClear()`** — query cache wired to `TINA4_DB_CACHE=true` env var.

---

## v3.10.38 -- April 1, 2026

### Code Metrics & Bubble Chart

The dev dashboard (`/__dev`) now includes a **Code Metrics** tab with a PHPMetrics-style bubble chart visualization. Files appear as animated bubbles sized by LOC and colored by maintainability index. Click any bubble to drill down into per-function cyclomatic complexity.

The metrics engine uses `token_get_all()` for zero-dependency static analysis covering cyclomatic complexity, Halstead volume, maintainability index, coupling, and violation detection. File analysis is sorted worst-first. Results are cached for 60 seconds.

### AI Context Installer

`bin/tina4php ai` now presents a simple numbered menu instead of auto-detection. Select tools by number, comma-separated or `all`. Already-installed tools show green. Generated context includes the full skills table.

### Dashboard Improvements

Full-width layout, sticky header/tabs, full-screen overlay. Removed junk migrations (`mooo`, `hkhkhk`), sample routes, and test templates.

### Cleanup

Removed old `plan/` spec documents, replaced with `PARITY.md` and `TESTS.md`. Central parity matrix added to tina4-book.

---

## v3.10.x -- Previous Releases

**Released:** 28-30 March 2026

The v3.10 line introduced the Frond template engine as a singleton, automatic ORM field mapping, transaction safety, the `tina4 ai` CLI command, and a round of Frond parser fixes.
### v3.10.29 -- `tina4 ai` Command (30 March 2026)

The `tina4 ai` CLI command stopped returning a stub message and started doing real work. It scans your project for AI coding tools -- Claude Code, Cursor, GitHub Copilot, Windsurf, Aider, Cline, and OpenAI Codex -- then installs context files for each one it finds.

```bash
# Detect tools and install context files
tina4 ai

# Install for all known AI tools
tina4 ai --all

# Overwrite existing context files
tina4 ai --force
```

### v3.10.28 -- DevReload Performance Fix (30 March 2026)

The development server's live-reload system polled too often and reloaded too fast. This patch fixed both problems.

- **Poll interval** increased from 2 seconds to 3 seconds (configurable via `TINA4_DEV_POLL_INTERVAL`)
- **Debounce** added a 500ms window before triggering a reload, preventing rapid successive refreshes
- **CSS hot-reload** now busts stylesheet cache links instead of forcing a full page reload

```php
// .env -- set poll interval in milliseconds
TINA4_DEV_POLL_INTERVAL=1000  // 1 second
TINA4_DEV_POLL_INTERVAL=5000  // 5 seconds
```

### v3.10.27 -- Frond Macro HTML Escaping Fix (30 March 2026)

Macro output was getting HTML-escaped when used inside expressions. A `{% macro %}` that returned HTML would render as visible `&lt;div&gt;` tags instead of actual markup. This patch marks macro output as safe, matching standard Twig behaviour.

**Before (broken):**

```twig
{% macro button(label) %}
  <button class="btn">{{ label }}</button>
{% endmacro %}

{# Rendered as: &lt;button class=&quot;btn&quot;&gt;Click&lt;/button&gt; #}
{{ button("Click") }}
```

**After (fixed):**

```twig
{# Renders as: <button class="btn">Click</button> #}
{{ button("Click") }}
```

### v3.10.26 -- Rebrand and ORM Transaction Safety (30 March 2026)

Two changes landed together. The framework rebranded to "This Is Now A 4Framework" across all default pages, CLI banners, and READMEs. More important: ORM `save()`, `delete()`, and `restore()` now wrap their operations in explicit transactions.

**Before (manual workaround for SQLite):**

```php
$db->startTransaction();
try {
    $user = new User();
    $user->name = "Alice";
    $user->save(); // Without this wrapper, SQLite could silently drop the write
    $db->commit();
} catch (\Exception $e) {
    $db->rollback();
}
```

**After (automatic transaction wrapping):**

```php
$user = new User();
$user->name = "Alice";
$user->save(); // save() now calls startTransaction() / commit() / rollback() internally
```

The fix also removed the hardcoded `version` field from `composer.json`, which was blocking Packagist sync.

### v3.10.22-24 -- Form Tokens and Template Fixes (29-30 March 2026)

- **v3.10.24** -- Fixed stale templates in dev mode. The Frond engine now checks file modification times during development
- **v3.10.23** -- Added `formTokenValue` and `form_token_value` as template globals for CSRF protection
- **v3.10.22** -- Form tokens now include a nonce in the JWT payload, making each token unique per form render

```twig
<form method="POST" action="/users">
  <input type="hidden" name="formToken" value="{{ formTokenValue }}">
  <input type="text" name="name">
  <button type="submit">Create</button>
</form>
```

### v3.10.18-20 -- Frond Parser Fixes (28-29 March 2026)

- **v3.10.20** -- Race-safe `getNextId()` for pre-generating database IDs. Frond engine optimization for template compilation
- **v3.10.18** -- Fixed ternary and inline-if parsing when the expression contained quoted strings

**Before (broken):**

```twig
{# This crashed the parser because the colon inside the string confused the ternary operator #}
{{ isActive ? "status: active" : "status: inactive" }}
```

**After (fixed):**

```twig
{# Parser now tracks quote boundaries before splitting on operators #}
{{ isActive ? "status: active" : "status: inactive" }}
```

### v3.10.14-16 -- Filters, Auto-Commit, and ID Generation (28 March 2026)

- **v3.10.16** -- Added `to_json`, `tojson`, and `js_escape` template filters
- **v3.10.15** -- Fixed the `|replace` filter when the replacement string contained backslashes
- **v3.10.14** -- Added `get_next_id()` for engine-aware ID pre-generation
- **v3.10.13** -- ORM now auto-commits on write operations

```twig
{# to_json filter -- pass PHP data to JavaScript #}
<script>
  const config = {{ settings|to_json }};
</script>

{# js_escape filter -- safe string embedding in JavaScript #}
<script>
  const message = "{{ userInput|js_escape }}";
</script>
```

### v3.10.10-12 -- Firebird, Sessions, and Dictionary Access (28 March 2026)

- **v3.10.12** -- Session garbage collection and NATS backplane parity
- **v3.10.11** -- Fixed dictionary access with variable keys in Frond templates
- **v3.10.10** -- Fixed Firebird migration runner for idempotent schema changes

**Before (broken in v3.10.9):**

```twig
{% set key = "name" %}
{# This returned null instead of the value #}
{{ user[key] }}
```

**After (fixed in v3.10.11):**

```twig
{% set key = "name" %}
{# Now resolves the variable and uses it as the dictionary key #}
{{ user[key] }}
```

### v3.10.5 -- Frond Quote-Aware Operator Matching (28 March 2026)

Template operators (`~`, `??`, comparisons) no longer match inside quoted strings. The expression evaluator gained `findOutsideQuotes()` and `splitOutsideQuotes()` helpers.

### v3.10.1 -- autoMap for ORM Field Mapping (28 March 2026)

The ORM gained an `$autoMap` flag. Set it to `true` and the ORM converts between `snake_case` database columns and `camelCase` PHP properties without manual field mapping.

**Before (manual mapping):**

```php
class UserProfile extends \Tina4\ORM {
    public $tableName = "user_profiles";
    public $fieldMapping = [
        "first_name" => "firstName",
        "last_name"  => "lastName",
        "created_at" => "createdAt",
    ];
}
```

**After (automatic mapping):**

```php
class UserProfile extends \Tina4\ORM {
    public $tableName = "user_profiles";
    public $autoMap = true;

    // DB columns: first_name, last_name, created_at
    // Auto-mapped to: $firstName, $lastName, $createdAt
}
```

Explicit entries in `$fieldMapping` take precedence. The auto-mapper never overwrites manual mappings.

### v3.10.0 -- Singleton Frond Engine (28 March 2026)

The Frond template engine became a singleton. One instance serves all template renders during a request, eliminating redundant initialization and token parsing. This is an internal change -- no API differences -- but template-heavy pages render faster.

---

## v3.9.x -- QueryBuilder, Sessions, Security

**Released:** 26-27 March 2026

The v3.9 line brought three headline features: a fluent query builder, automatic sessions, and secure-by-default routing. It also fixed a critical `setcookie()` error in the built-in server.

### v3.9.0 -- QueryBuilder, Sessions, Path Injection (26 March 2026)

**QueryBuilder.** A fluent SQL builder that works standalone or through the ORM.

```php
// Through the ORM
$admins = User::query()
    ->where("role = ?", ["admin"])
    ->orderBy("name")
    ->limit(10)
    ->get();

// Standalone
$results = QueryBuilder::from("orders")
    ->where("total > ?", [100])
    ->join("customers", "customers.id = orders.customer_id")
    ->orderBy("total DESC")
    ->get();
```

The builder supports `select`, `where`, `orWhere`, `join`, `leftJoin`, `groupBy`, `having`, `orderBy`, `limit`, `first`, `count`, `exists`, and `toSql`.

**Path parameter injection.** Route handlers receive path parameters as named function arguments.

```php
// The framework injects $id directly into the handler
Router::get("/users/{id:int}", function (int $id) {
    $user = (new User())->load("id = ?", [$id]);
    return $user->toArray();
});
```

**Auto-start sessions.** Every route handler now has `$request->session` available with zero configuration.

```php
Router::get("/dashboard", function ($request) {
    $request->session->set("lastVisit", date("Y-m-d H:i:s"));
    $username = $request->session->get("username");
    return ["user" => $username];
});
```

The session API includes: `get`, `set`, `delete`, `has`, `clear`, `destroy`, `save`, `regenerate`, `flash`, `getFlash`, and `all`.

### v3.9.1 -- Secure by Default (27 March 2026)

POST, PUT, PATCH, and DELETE routes now require authentication by default. CSRF middleware ships built in with session-bound form tokens.

**Breaking change.** If your application has unprotected POST routes, they will return 401 after upgrading.

**Before (v3.8.x):**

```php
// This worked without any auth
Router::post("/comments", function ($request) {
    // Anyone could post
});
```

**After (v3.9.1):**

```php
// Option 1: Add authentication
Router::post("/comments", function ($request) {
    // Requires valid auth token
})->secure();

// Option 2: Explicitly allow public access
Router::post("/comments", function ($request) {
    // Public endpoint
})->allowAnonymous();
```

This release also standardized environment variables: `TINA4_CORS_CREDENTIALS`, `TINA4_RATE_LIMIT`, `TINA4_CSRF`, `TINA4_QUEUE_BACKEND`, and `TINA4_TOKEN_LIMIT`.

### v3.9.2-3 -- NoSQL QueryBuilder and Cookie Fixes (27 March 2026)

- **v3.9.3** -- Fixed `SameSite` cookie handling and session `save()` visibility. Set `SameSite=Lax` as the default
- **v3.9.2** -- Extended QueryBuilder to work with MongoDB. Added WebSocket backplane support

### v3.9.4 -- setcookie Fatal Error Fix (27 March 2026)

The built-in HTTP server called `setcookie()` after headers had already been sent. This caused a fatal error on any route that set a cookie. The fix buffers cookie headers before flushing the response.

---

## v3.8.x -- Hot Reload, Security Headers, Connection Pooling

**Released:** 25-26 March 2026

### v3.8.0 -- Hot Reload and Frond Filters (25 March 2026)

The PHP development server gained hot reload. Save a file and the browser refreshes. The Frond template engine added `base64encode` and `base64decode` filter aliases.

```php
// .env
TINA4_DEBUG=true  // Enables hot reload in dev mode
```

### v3.8.1-3 -- Security and Validation (25 March 2026)

Three patches shipped on the same day:

- **SecurityHeadersMiddleware** -- Adds `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy`, and `X-Content-Type-Options` to every response
- **Validator class** -- Input validation with error response envelopes
- **Upload size limit** -- Configurable via `TINA4_MAX_UPLOAD_SIZE` (default 10MB)

```php
// .env
TINA4_MAX_UPLOAD_SIZE=20  // 20MB limit
```

### v3.8.7 -- Connection Pooling (26 March 2026)

Database connections now support round-robin pooling. Pass a `pool` parameter to the connection string.

```php
// Pool of 5 connections
$db = new Database("sqlite:///data/app.db?pool=5");
```

---

## v3.7.x -- Template Auto-Serve, Typed Route Params

**Released:** 25 March 2026

### v3.7.0 -- Template Auto-Serve (25 March 2026)

Place an `index.html` or `index.twig` in `src/templates/` and the framework serves it at `/`. No route registration needed. If you register a `GET /` route, your route takes priority. If neither exists, the framework falls back to the default landing page.

This release also made Firebird migrations idempotent. `ALTER TABLE ADD` statements check `RDB$RELATION_FIELDS` before executing. Columns that already exist are skipped and logged.

### v3.7.1-2 -- Typed Route Parameters (25 March 2026)

Route parameters gained type constraints: `{id:int}`, `{price:float}`, `{slug:path}`. The framework validates the type before the handler runs. Mismatched types return a 404.

```php
Router::get("/products/{id:int}", function (int $id) {
    // $id is guaranteed to be an integer
});

Router::get("/files/{path:path}", function (string $path) {
    // $path matches the full remaining URL segment
});
```

Template lookup caching arrived for production mode. In development, the framework checks the filesystem on every request to pick up changes.

---

## v3.6.x -- Reference Cleanup

**Released:** 24 March 2026

### v3.6.0 (24 March 2026)

Fixed outdated API references across the codebase. Corrected `getToken`/`validToken` method names and the `TINA4_LOCALE` environment variable. No new features -- housekeeping only.

---

## v3.5.x -- Bundled Frontend, Swagger, Middleware

**Released:** 24 March 2026

### v3.5.0 (24 March 2026)

The `tina4js.min.js` reactive frontend library (13.6KB) now ships bundled with the framework. No CDN link, no npm install -- the file is included in the package.

- **AutoCrud** routes now include Swagger metadata
- **Swagger generator** parses docblock annotations from route handlers
- **Middleware** standardized around `before*` and `after*` naming with three built-in middleware classes

```php
/**
 * @description Get user by ID
 * @tags Users
 * @param int $id User ID
 * @return User
 */
Router::get("/api/users/{id:int}", function (int $id) {
    return (new User())->load("id = ?", [$id]);
});
```

The Swagger generator picks up the `@description`, `@tags`, `@param`, and `@return` annotations and builds the OpenAPI spec.

---

## v3.4.x -- DatabaseResult, File Uploads, WebSocket Broadcast

**Released:** 24 March 2026

### v3.4.0 (24 March 2026)

The database layer gained a `DatabaseResult` class as a standardized return type for `fetch()`. Every query now returns an object with `data`, `error`, `count`, and a lazy `columnInfo()` method for schema metadata.

**Breaking change.** If your code accessed raw arrays from database queries, you need to use `->data` on the result.

**Before (v3.3.x):**

```php
$rows = $db->fetch("SELECT * FROM users");
foreach ($rows as $row) {
    echo $row["name"];
}
```

**After (v3.4.0):**

```php
$result = $db->fetch("SELECT * FROM users");
foreach ($result->data as $row) {
    echo $row["name"];
}
// Also available: $result->error, $result->count
```

Other changes in this release:

- **File uploads** normalized to a consistent format: `filename`, `type`, `content`, `size`. Added `data_uri` template filter for inline images
- **WebSocket broadcast** scoped to specific paths
- **`Database::getConnection()`** added as an alias for accessing the underlying connection
- **Queue job files** changed extension from `.json` to `.queue-data`
- **Auth method rename** -- `getToken` became the primary method, `createToken` became an alias

---

## v3.3.x -- Queue API, Route Chaining, Dev Toolbar

**Released:** 24 March 2026

### v3.3.0 (24 March 2026)

The queue system arrived with a full lifecycle API. Produce messages, consume them with a generator, and manage job state through `complete()`, `fail()`, and `reject()`.

```php
use Tina4\Queue;

// Produce a job
Queue::produce("emails", ["to" => "alice@example.com", "subject" => "Welcome"]);

// Consume jobs
foreach (Queue::consume("emails") as $job) {
    try {
        sendEmail($job->data);
        $job->complete();
    } catch (\Exception $e) {
        $job->fail($e->getMessage());
    }
}
```

Route handlers became flexible. They accept zero, one, or two parameters with type-hint detection. Chaining modifiers arrived: `.secure()` and `.cache()`.

```php
// Zero params
Router::get("/health", function () {
    return ["status" => "ok"];
});

// One param -- type-hint determines if it's request or response
Router::get("/users", function (\Tina4\Request $request) {
    return $request->query;
});

// Chain modifiers
Router::get("/admin/users", function ($request) {
    return User::query()->get();
})->secure()->cache(300);
```

The `render()` method arrived as an alias for `template()`. The dev admin dashboard made routes clickable -- each one opens in a new tab.

---

## v3.2.x -- Flexible Route Handlers, Strict Mode, Live Reload

**Released:** 23 March 2026

### v3.2.0 (23 March 2026)

Route handlers gained support for zero, one, or two parameters. The framework detects whether your single parameter is a request or response by checking the type hint.

```php
// Single param with Request type-hint
Router::get("/search", function (\Tina4\Request $request) {
    return ["q" => $request->query["q"]];
});
```

The authentication API consolidated. `createToken` and `validateToken` became the primary methods. `getToken` and `validToken` remain as aliases.

```php
$token = \Tina4\Auth::createToken(["userId" => 42, "role" => "admin"]);
$valid = \Tina4\Auth::validateToken($token);
```

Other changes: inline `Router::` calls now work in route discovery. The error overlay passes full request details. Windows path separators are normalized after gallery deploy.

### v3.2.1-2 -- Strict Mode and Benchmarks (23 March 2026)

- **Strict mode** -- PHP warnings and notices now throw `ErrorException`. Silent failures become visible failures
- **Stream-select server** gained a 35% throughput improvement
- **Live-reload polling** added for PHP dev mode

---

## v3.1.x -- Drop-In Server Support, Migration Guide

**Released:** 22 March 2026

### v3.1.0 (22 March 2026)

The framework gained drop-in support for production-grade PHP servers. The application exposes an `__invoke()` method compatible with Swoole, RoadRunner, FrankenPHP, and ReactPHP.

```php
// RoadRunner worker
$app = new \Tina4\App();
// $app is callable -- pass it to your server's handler
```

The `toDict()` method was renamed to `toArray()` as the primary name. `toDict()` remains as an alias.

### v3.1.1-2 -- README and CI Fixes (22 March 2026)

- Fixed `composer.json` to remove the `version` field (Packagist recommendation)
- Updated README code examples to match the v3 API
- Added the v2 to v3 migration guide (`MIGRATE.md`)

---

## v3.0.0 -- The Rewrite

**Released:** 22 March 2026

The v3.0.0 release is a ground-up rewrite. Zero Composer dependencies. The HTTP server, template engine, ORM, and database drivers are all native PHP. No Guzzle, no Twig, no Doctrine.

### What Changed

- **Custom HTTP server** built on `stream_select` with WebSocket support -- replaces `php -S`
- **Frond template engine** with pre-compilation and token caching -- replaces Twig
- **Native database drivers** for SQLite, PostgreSQL, MySQL, MSSQL, and Firebird
- **Standardized connection strings** -- `driver://host:port/database`
- **DevAdmin dashboard** with panels for routes, database, queue, mailbox, requests, errors, and connection info
- **`tina4 generate` command** scaffolds models, routes, migrations, and middleware
- **DB query caching** via `TINA4_DB_CACHE=true` for transparent read caching
- **Unified queue** switches between SQLite, RabbitMQ, and Kafka via `.env` with no code change
- **Unified messenger** for email sending, driven by `.env` configuration
- **Interactive gallery** with seven example apps, each with deploy and live-try buttons
- **Dead letter queue** support with `deadLetters()`, `purge()`, and `retryFailed()`

### Breaking Changes from v2

These are the changes that will break existing code. See Chapter 29 for a full migration checklist.

**PHP version.** Requires PHP 8.0 or later.

**Package name.** Changed from `tina4stack/tina4php` to `tina4stack/tina4-php` (note the hyphen).

```bash
# v2
composer require tina4stack/tina4php

# v3
composer require tina4stack/tina4-php
```

**Directory structure.** `Tina4/` moved from `src/Tina4/` to the project root.

**Database connection strings.** Scheme aliases removed.

```php
// v2 -- these aliases no longer work
$db = new \Tina4\DataSQLite3("database.db");
$db = new \Tina4\DataFirebird("localhost:database.fdb");

// v3 -- use standardized connection strings
$db = new \Tina4\Database("sqlite:///database.db");
$db = new \Tina4\Database("firebird://localhost/database.fdb");
```

**Environment variable rename.** `TINA4_AUTO_COMMIT` became `TINA4_AUTOCOMMIT` (no underscore between AUTO and COMMIT).

**Method naming.** All methods follow camelCase.

```php
// v2
$db->start_transaction();

// v3
$db->startTransaction();
```

### Release Candidates (21 March 2026)

Five release candidates shipped before the final v3.0.0 release. They covered the initial rewrite (`rc.1`), Frond pre-compilation with a 2.8x render speedup (`rc.4`), and final test fixes (`rc.5`). The RC period lasted one day. The test suite passed before the final tag.

---

## Upgrade Path Summary

| From | To | Action Required |
|------|----|----------------|
| v2.x | v3.0.0 | Full migration -- see Chapter 29 |
| v3.0-3.3 | v3.4.0 | Update `fetch()` calls to use `->data` on DatabaseResult |
| v3.0-3.8 | v3.9.1 | Add auth to POST/PUT/PATCH/DELETE routes or mark them `->allowAnonymous()` |
| v3.9.x | v3.10.x | No breaking changes -- update and test |

The version numbers move fast. The API stays stable. Pick the latest v3.10.x patch and your application gets every fix listed here without changing a line of code.
