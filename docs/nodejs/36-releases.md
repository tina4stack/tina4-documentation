# Chapter 35: Release Notes

## v3.10.99 (2026-04-12)

- **breaking:** `autoMap` now defaults to `true` — ORM models automatically map between camelCase properties and snake_case DB columns. Set `static autoMap = false;` on your model to restore the old behaviour.
- **feat:** `toDict(include, case)` parameter — pass `'snake'` as second arg to get snake_case keys matching DB columns, or `'camel'` (default) for camelCase.
- **feat:** Frond `replace` filter now accepts object args — `{{ v|replace({"T": " ", "-": "/"}) }}` for multiple substitutions in one call.
- **tests:** 13 new parity tests covering `toDict(case)`, `autoMap` default, `replace` filter (object + positional), and `ServiceRunner` registration. 268 tests passing.
- **parity:** All features shipped identically across Python, PHP, Ruby, Node.js.

## v3.10.97 (2026-04-11)

- **fix:** frond.form.submit redirect handling — XHR follows 3xx redirects transparently; fixed by detecting `xhr.responseURL` mismatch and navigating instead.
- **dep:** Updated frond.min.js to v2.1.2.
- **parity:** All 4 frameworks bumped to 3.10.97.

## v3.10.93 (2026-04-11)

- **fix:** Frond bracket depth tracking in `findOutsideQuotes()` and `splitOutsideQuotes()` — expressions like `arr[i % 2]` no longer treated as top-level arithmetic.
- **fix:** Frond subscript expression evaluation — bracket content uses `evalExpr()` instead of direct context lookup, enabling `arr[loop.index0 % 2]`.
- **fix:** Frond slice with variable bounds — `items[start:end]` evaluates bounds through `evalExpr()`.
- **docs:** Developer skills updated — Metrics Dashboard guidance, Frond Template Parity rules, `@noauth` security warnings.
- **parity:** All Frond fixes applied identically across Python, PHP, Ruby, Node.js. 2,831 tests passing (268 Frond).

## v3.10.92 (2026-04-10)

- **feat:** Add `DevAdmin` methods — `capture()` (5-param), `clearAll()`, `health()`, `unresolvedCount()`, `reset()`, `register()`.
- **feat:** Add `Server.start()` and `Server.stop()` for cross-framework parity.
- **feat:** Add `DatabaseResult.size()` method.
- **feat:** Add `DevReload.start()` and `DevReload.stop()`.
- **feat:** Add `ScssCompiler.compileScss()` method.
- **fix:** `autoCrud.ts` — fix spread syntax on non-iterable, add id in POST response, correct response format to `{data, meta}`, change validation status from 400 to 422.
- **parity:** 44/44 cross-framework features green. 2,752 tests passing.

## v3.10.91 (2026-04-10)

- **feat:** Add parity methods — `GraphQLType.parse()`, `CorsMiddleware.isPreflight()`, `RateLimiterMiddleware.check()`.
- **breaking:** Rename `from()` → `fromTable()`, remove `template()` alias — align with Python canonical names.

## v3.10.90 (2026-04-09)

- **docs:** Chapter 4 (Templates) — new "Dumping Values for Debugging" section covering both `{{ x|dump }}` and `{{ dump(x) }}` forms, the v3.10.88 `inspectValue()` inspector (circular refs, BigInt, Map/Set, Error, Date, class instances), and the `TINA4_DEBUG=true` production gate. Filter table entry updated to reference the new section.
- **docs:** `plan/parity/parity-template.md` updated with a cross-framework dump helper comparison table and marks dump parity as confirmed across all 4 frameworks at v3.10.89.
- **chore:** Version sync release — brings all 4 frameworks to the same patch version (3.10.90) so downstream users can upgrade PHP/Python/Ruby/Node.js in lockstep without hunting version mismatches.

## v3.10.89 (2026-04-09)

- **feat:** `{{ dump(value) }}` global function form added to Frond alongside the existing `{{ value|dump }}` filter. Both call a single `renderDump()` helper (which delegates to the v3.10.88 `inspectValue()` inspector) and produce identical output.
- **security:** Dump is now **gated on `TINA4_DEBUG=true`**. In production (env var unset or `false`) both the filter and function silently return an empty `SafeString`. This prevents accidental leaks of internal state, object shapes, and sensitive values into rendered HTML when a developer leaves a `{{ dump(x) }}` call in a template.
- **test:** 4 new tests in `frond.test.ts` covering `dump()`/`|dump` parity, debug-mode circular ref handling, production silencing for both forms.

## v3.10.88 (2026-04-09)

- **fix:** `{{ value|dump }}` filter now handles complex objects safely. The previous implementation used `JSON.stringify` which crashed on circular references and BigInt, silently dropped functions/Symbols/`undefined`, and serialised `Map`/`Set`/`Error`/class instances as empty `{}`. Replaced with an `inspectValue()` inspector that matches PHP's `var_dump`, Python's `repr`, and Ruby's `inspect`:
  - Circular references: `[Circular]`
  - BigInt: `123n`
  - Date: `Date(2026-04-09T13:00:00.000Z)`
  - Map / Set: `Map(2) { "a" => 1, "b" => 2 }` / `Set(3) { 1, 2, 3 }`
  - Error: `Error("boom")`
  - Class instances: `User { name: "Alice", age: 30 }` (class name preserved)
  - Functions: `[Function: name]`
  - Depth-capped at 8 levels to prevent runaway graphs
- **test:** 11 new edge-case assertions in `frond.test.ts` (frond.test now 254 passing).

## v3.10.87 (2026-04-09)

- **fix:** Dev toolbar no longer vanishes after a hot-reload. The CLI watcher used to call `server.router.clear()` on every file change — including template/CSS/JS asset edits — which left a brief window of 404 responses that bypass the dev toolbar injection. The watcher now reports whether a `.ts/.tsx/.js/.jsx` source file changed; router re-discovery only runs on code changes, and asset edits pass through without touching the router. Matches the PHP v3.10.87 fix.

## v3.10.86 (2026-04-09)

- **feat:** `foreignKey` field type on `BaseModel` auto-wires both sides of a foreign key relationship. Declaring `user_id: { type: "foreignKey", references: "User" }` injects a `belongsTo` entry on the declaring model and a `hasMany` entry on the referenced model via a module-level FK registry. New static methods `_processForeignKeys()` and `_applyFkRegistry()` are called lazily before relationship resolution. Optional `relatedName` overrides the has-many key.
- **feat:** Cross-framework parity — same FK auto-wiring semantics now available in Python (`ForeignKeyField`), PHP (`$foreignKeys`), and Ruby (`foreign_key_field`)
- **docs:** Chapter 6 (ORM) updated with a new "foreignKey Field Type — Auto-Wired Relationships" section

## v3.10.85 (2026-04-09)

- Version bump for parity with Python and PHP releases

## v3.10.84 (2026-04-09)

- **fix:** Router/middleware was setting `request.user` / `request.auth` / auth payload to `true` (boolean) instead of the actual JWT payload after `validToken()` was changed to return bool — any code reading `request.user.sub` etc. would have failed silently or crashed
- **fix:** CSRF middleware was not correctly rejecting invalid tokens (null check on bool result always passed)
- **add:** Headless routing auth payload integration tests to prevent regression

## v3.10.83 (2026-04-08)

- **feat:** WebSocket rooms — `joinRoom`, `leaveRoom`, `broadcastToRoom`, `getRoomConnections`, `roomCount`, `getClientRooms`
- **feat:** Queue signature parity — instance-scoped `push`/`pop`/`retry`, no topic params on public methods
- **feat:** Auth alias cleanup — removed `createToken`/`validateToken`, canonical `getToken`/`validToken`

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


Tina4 Node.js follows semantic versioning. The major version (3) marks the ground-up rewrite. The minor version tracks feature additions. The patch version tracks fixes, template engine corrections, and cross-framework parity updates.

This chapter covers every release from v3.0.0 through v3.10.x. Each section groups releases by minor version, lists features added, bugs fixed, and breaking changes with migration code where relevant.

---

## v3.10.68 (2026-04-03) — Full Parity Release
- **100% API parity** across Python, PHP, Ruby, Node.js — 30+ issues fixed
- **ORM:** save() returns self/false, arrays not tuples, toDict/toAssoc, scope registers method, where()/all() on Node, count() on PHP
- **Auth:** expires_in minutes, PBKDF2 260k, env SECRET fallback, API key fallback
- **Session:** dual-mode flash(), get_flash, cookieHeader, getSessionId
- **Database:** execute() bool/DatabaseResult, get_last_id/get_error, getColumns, cacheStats
- **Request/Response:** files dict, query, cookies, contentType, xml(), callable
- **Queue:** consume() poll_interval
- **WebSocket:** event naming, connection properties
- **GraphQL:** schema_sdl() + introspect() on all 4
- **Events:** emitAsync() on all 4
- **i18n:** zero-dep YAML support

## v3.10.67 (2026-04-03)
- **load() returns boolean** — `model.load(sql, params)` calls selectOne internally, populates the instance, returns `true`/`false`. Use `findById()` for PK lookups
- **api.upload()** added to tina4-js — sends FormData with Bearer token auth for multipart file uploads
- **ORM CLAUDE.md rewrite** — all method stubs now match actual API signatures
- **File upload docs** — `req.files` format documented in CLAUDE.md

## v3.10.66 (2026-04-03)
- **Metrics file detail fix** — clicking bubbles in framework scanning mode now resolves paths correctly via scan root tracking

## v3.10.65 (2026-04-03)
- **Metrics 3-stage test detection** — filename, path, and content matching
- **Metrics framework mode** — scans framework source with correct relative paths
- **tina4 console** — interactive REPL with framework loaded
- **tina4 env** — interactive environment configuration
- **Brand** — "TINA4 — The Intelligent Native Application 4ramework"
- **Quick references** — 36 sections, DotEnv API documented
- **37 chapters** — 7 new (Events, Localization, Logging, API Client, WSDL/SOAP, DI Container, Service Runner)
- **MongoDB + ODBC adapters** across all 4 frameworks
- **Pagination standardized** — limit/offset primary, merged dual-key response
- **Port kill-and-take-over** on startup

---

## v3.10.60 (2026-04-03)
- **tina4 console** — interactive Node REPL with framework loaded (db, Router, Database, Log)
- **tina4 env** — interactive environment configuration
- **Brand update** — "TINA4 — The Intelligent Native Application 4ramework"
- **Dynamic version** — reads from package.json at runtime
- **Port kill-and-take-over** — default port always reclaimed
- **findAvailablePort** — checks 0.0.0.0 not 127.0.0.1
- **MongoDB adapter** (mongodb npm), **ODBC adapter** (odbc npm)
- **Pagination standardized** — limit/offset primary, merged dual-key response
- **Metrics dependency lines** — basename fix for correct rendering
- **autoMap uppercase** — snakeToCamel lowercases first

---

## v3.10.57 (2026-04-02)
- **MongoDB adapter** — `initDatabase({ url: "mongodb://host:port/db" })`, requires `npm install mongodb`
- **ODBC adapter** — `initDatabase({ url: "odbc:///DSN=MyDSN" })`, requires `npm install odbc`
- **Pagination standardized** — limit/offset primary, merged dual-key toPaginate() response
- **Test port at +1000** — user testing port (e.g. 8148) stable, no hot-reload
- **Dynamic version** — read from package.json, no hardcoded constant
- **Metrics dependency lines** — fixed basename parsing
- **autoMap uppercase columns** — snakeToCamel lowercases first
- **ORM DATABASE_URL discovery** — auto-connect from env for SQLite
- **108 features at 100% parity**, 2,646 tests

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** — second HTTP server on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **SQLite transaction safety** — commit/rollback/startTransaction guarded
- **autoMap uppercase columns** — snakeToCamel lowercases first
- **ORM DATABASE_URL discovery** — auto-connect from env for SQLite
- **QueryBuilder docs** — added to ORM chapter

---

## v3.10.48 — April 2, 2026

### Bug Fixes

**Cluster mode requires `TINA4_PRODUCTION=true`** — Worker forking no longer auto-triggers when debug is off. Set `TINA4_PRODUCTION=true` env var or use `tina4 serve --production` to enable cluster mode.

---

## v3.10.46 — April 1, 2026

### Test Coverage

CSRF middleware expanded to 32 tests matching Python reference. Node.js now at 2,546 tests with full parity across all 49 core areas.

---

## v3.10.45 — April 1, 2026

### Notes

Version bump for parity with PHP CLI serve fix. No Node.js-specific changes.

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

**Default port** — Node.js default port set to 7148 (PHP=7145, Python=7146, Ruby=7147, Node=7148).

**SQLite LIMIT fix** — Prevents double-LIMIT errors in the database browser.

**browseTable quote escaping** — Fixed table name click handlers.

**Server handler dispatch regex** — Fixed a regex that required whitespace after `async` in handler functions. Transpiled auto-CRUD handlers producing `async(req,res)=>` were called with zero arguments, causing crashes.

**Cluster mode in tests** — Server-based tests now set `TINA4_DEBUG=true` to prevent cluster mode forking, which was causing ECONNREFUSED errors.

### Test Coverage

Massive test expansion — 718 new tests added across Auth (+52), ORM (+30), FakeData (+48), Cache (+23), DevMailbox (+32), Static (+21), Queue (+20), Frond (+57), CLI scaffolding (55), Metrics (69), plus v3.10.44 feature tests and server test fixes. 2,530 tests passing, 0 failures.

---

## v3.10.40 — April 1, 2026

### Bug Fixes

**Dev overlay version check** — Fixed misleading "You are up to date" message when running a version ahead of what's published on npm. The overlay now shows a purple "ahead of npm" message. Also added a breaking changes warning (red banner with changelog link) when a major or minor version update is available.

---

## v3.10.39 — April 1, 2026

### New Features

**`Database.getColumns(tableName)`** — Returns `[{name, type, nullable, default, primaryKey}]` for each column. Uses `PRAGMA table_info` for SQLite and `information_schema.columns` for PostgreSQL/MySQL/MSSQL.

**`Database.executeMany(sql, paramSets)`** — Execute a SQL statement with multiple parameter arrays in a single transaction for atomicity and performance.

**`BaseModel.create<T>(data)`** — Static factory method: instantiates, saves, and returns the new record.

**`BaseModel.find()` and `BaseModel.load()`** — aliases for `findById()` (parity with Python, PHP, Ruby).

**`seed` CLI command** — `tina4nodejs seed` scans `src/seeds/*.ts` and executes them via `tsx`.

**`Router.allRoutes()`** — alias for `getRoutes()`.

---

## v3.10.38 — April 1, 2026

### Code Metrics & Bubble Chart

The dev dashboard (`/__dev`) now includes a **Code Metrics** tab with a PHPMetrics-style bubble chart visualization. Files appear as animated bubbles sized by LOC and colored by maintainability index. Click any bubble to drill down into per-function cyclomatic complexity.

The metrics engine uses regex-based TypeScript/JavaScript analysis for zero-dependency static analysis covering cyclomatic complexity, Halstead volume, maintainability index, coupling, and violation detection. File analysis is sorted worst-first. Results are cached for 60 seconds.

### AI Context Installer

`npx tina4nodejs ai` now presents a simple numbered menu instead of auto-detection. Select tools by number, comma-separated or `all`. Already-installed tools show green. Generated context includes the full skills table.

### Dashboard Improvements

Full-width layout, sticky header/tabs, full-screen overlay. Fixed `/__dev/` trailing slash returning 404.

### Cleanup

Removed `demo/` directory. Removed old `plan/` spec documents, replaced with `PARITY.md` and `TESTS.md`. Central parity matrix added to tina4-book.

---

## v3.10.x — Previous Releases (March 28–31, 2026)

The v3.10 line focused on ORM refinements, Frond template engine fixes, and cross-framework parity. Thirty-two patch releases landed in four days.

### Features

**autoMap for ORM field mapping (v3.10.1)**

The ORM gained automatic translation between JavaScript camelCase and database snake_case. Set `autoMap = true` on a model and the framework handles the rest.

```typescript
import { BaseModel } from "tina4-nodejs";

class User extends BaseModel {
  static tableName = "users";
  static autoMap = true;
  static fields = {
    id: { type: "integer" as const, primaryKey: true },
    firstName: { type: "string" as const },   // maps to first_name
    lastName: { type: "string" as const },     // maps to last_name
    createdAt: { type: "datetime" as const },  // maps to created_at
  };
}
```

Explicit `fieldMapping` entries take precedence over auto-generated ones. The two utilities `snakeToCamel()` and `camelToSnake()` are exported for direct use.

**WSDL lifecycle hooks and dotted function names (v3.10.6)**

WSDL services gained `beforeCall` and `afterCall` hooks. The Frond template engine learned to resolve dotted function names like `{{ utils.format(value) }}`.

**ORM auto-commit on write operations (v3.10.13)**

The ORM now commits after every `save()` and `delete()` call. Before this change, writes on SQLite would silently succeed in memory but never persist to disk unless you called `commit()` yourself.

**get_next_id() for ID pre-generation (v3.10.14)**

Models gained a `getNextId()` method. It queries the database engine for the next auto-increment value before the insert happens. Useful when you need the ID for a related record before you save the parent.

```typescript
const nextId = await User.getNextId();
// Use nextId in a related record before saving the User
```

**Template filters: to_json, tojson, js_escape (v3.10.16)**

Three new Frond filters for passing data from templates to JavaScript:

```twig
<script>
  const config = {{ settings|to_json }};
  const message = "{{ userInput|js_escape }}";
</script>
```

**formTokenValue() in Frond templates (v3.10.23)**

Templates gained a `formTokenValue()` function that generates a unique CSRF token per form. Each token carries a nonce in the JWT payload, so two forms on the same page get distinct tokens (v3.10.22).

```twig
<form method="POST" action="/submit">
  <input type="hidden" name="formToken" value="{{ formTokenValue() }}">
  <button type="submit">Send</button>
</form>
```

**Arithmetic in set and expressions (v3.10.31)**

The Frond engine learned arithmetic. `{% set total = price * quantity %}` and `{{ width + padding }}` now work as expected.

**MCP server (v3.10.32)**

Tina4 Node.js ships a built-in MCP (Model Context Protocol) server. AI coding tools can connect to your running application and inspect routes, models, and database schema.

### Bug Fixes

**Frond dict[variable_key] access (v3.10.11)**

Variable keys in dictionary access were ignored. The engine treated `dict[myVar]` as a literal string lookup instead of resolving `myVar` first.

```twig
{# Before fix — broken: always looked up the literal string "myVar" #}
{% set key = "name" %}
{{ user[key] }}  {# returned undefined #}

{# After fix — works: resolves key to "name", then looks up user["name"] #}
{% set key = "name" %}
{{ user[key] }}  {# returns the user's name #}
```

**Frond |replace filter backslash escaping (v3.10.15)**

The `|replace` filter mangled backslashes. A replacement string containing `\n` would insert a literal newline instead of the two characters `\n`.

**Frond variable resolution (v3.10.17)**

Nested variable lookups in certain template constructs returned `undefined`. The engine now walks the scope chain correctly.

**Frond inline-if with quoted strings (v3.10.19)**

Inline conditionals broke when the true/false branches contained quoted strings with spaces. The parser split on whitespace inside the quotes.

**Filters in if conditions (v3.10.21)**

Filters inside `{% if %}` conditions were silently ignored. The condition evaluated the raw value instead of the filtered one.

```twig
{# Before fix — broken: |length filter ignored, condition tested the array itself #}
{% if items|length > 0 %}

{# After fix — works: |length runs first, condition compares the number #}
{% if items|length > 0 %}
```

**Stale templates in dev mode (v3.10.24)**

The dev server cached compiled templates and ignored file changes. Editing a template required a server restart. The fix reads the filesystem on every request in development mode, while production mode keeps the cache.

**ORM save/delete transaction safety (v3.10.25)**

SQLite threw "cannot commit — no transaction is active" when the ORM called `commit()` outside an explicit transaction. The ORM now wraps every `save()` and `delete()` in a `startTransaction()`/`commit()`/`rollback()` block.

```typescript
// Before fix — threw on SQLite:
const user = new User({ firstName: "Alice" });
await user.save(); // Error: cannot commit — no transaction is active

// After fix — works on all database engines:
const user = new User({ firstName: "Alice" });
await user.save(); // Transaction handled internally
```

**Frond macro HTML escaping (v3.10.27)**

Macro output was HTML-escaped when used inside `{{ }}` expressions. A macro that generated `<div>` would render as `&lt;div&gt;`. Nested macros double-escaped. Macro output is now treated as safe HTML, matching standard Twig behaviour.

**js_escape and to_json auto-escaping (v3.10.17–19)**

The `js_escape` and `to_json` filters produced output that Frond then HTML-escaped. A JSON string like `{"key":"value"}` became `{&quot;key&quot;:&quot;value&quot;}`. These filters now wrap their output in SafeString to bypass auto-escaping.

### Firebird-Specific

**Migration runner fixes (v3.10.10)**

The migration runner generated SQLite-style `AUTOINCREMENT` and `TEXT` types for Firebird. Firebird needs generators and `VARCHAR`. The runner now emits the correct DDL and generates IDs from a `GEN_TINA4_MIGRATION_ID` sequence.

---

## v3.9.x — QueryBuilder, Sessions, Path Injection (March 26–27, 2026)

The v3.9 line delivered three features that changed how developers write routes and query data.

### Features

**QueryBuilder (v3.9.0)**

A fluent SQL builder that integrates with the ORM. Chain methods to build queries without writing raw SQL.

```typescript
import { User } from "./orm/User.js";

// ORM integration
const admins = await User.query()
  .where("role = ?", ["admin"])
  .orderBy("name")
  .limit(10)
  .get();

// Standalone usage
import { QueryBuilder } from "tina4-nodejs";

const results = await QueryBuilder.from("orders")
  .where("total > ?", [100])
  .leftJoin("customers", "orders.customer_id = customers.id")
  .orderBy("total", "DESC")
  .limit(20)
  .get();

// Utility methods
const exists = await User.query().where("email = ?", [email]).exists();
const total = await User.query().where("active = ?", [true]).count();
const first = await User.query().where("id = ?", [1]).first();
```

The builder supports `select`, `where`, `orWhere`, `join`, `leftJoin`, `groupBy`, `having`, `orderBy`, `limit`, `first`, `count`, `exists`, and `toSql`.

**Path parameter injection (v3.9.0)**

Route handlers receive path parameters as named function arguments. The framework inspects the handler's parameter names and injects matching values.

```typescript
import { Router } from "tina4-nodejs";

// The framework injects id as a typed argument
Router.get("/users/{id:int}", async (id, request, response) => {
  const user = await User.find(id);
  response.json(user);
});
```

**Auto-start sessions (v3.9.0)**

Every route handler receives a session object on `request.session` with zero configuration. No middleware to register. No setup code.

```typescript
Router.post("/login", async (request, response) => {
  request.session.set("userId", 42);
  request.session.flash("message", "Welcome back.");
  response.redirect("/dashboard");
});

Router.get("/dashboard", async (request, response) => {
  const userId = request.session.get("userId");
  const flash = request.session.getFlash("message");
  response.render("dashboard", { userId, flash });
});
```

The session API: `get`, `set`, `delete`, `has`, `clear`, `destroy`, `save`, `regenerate`, `flash`, `getFlash`, `all`.

**CSRF middleware and secure-by-default (v3.9.1)**

POST, PUT, PATCH, and DELETE routes require authentication by default. The framework ships a `CsrfMiddleware` that validates session-bound form tokens.

```typescript
// Routes that modify data are protected out of the box
Router.post("/api/orders", async (request, response) => {
  // Request must include a valid form token or auth header
  // Otherwise the framework returns 403
});
```

**Queue parity (v3.9.1)**

The queue system gained priority-based push, `size(status)` to count jobs by state, `job.retry()`, and `job.topic` for filtering.

**NoSQL QueryBuilder and WebSocket backplane (v3.9.2)**

The QueryBuilder gained MongoDB support. WebSocket servers gained a backplane for broadcasting across multiple server instances.

**SameSite=Lax cookie default (v3.9.2)**

Session cookies now set `SameSite=Lax` by default. This prevents CSRF attacks from cross-origin form submissions without breaking same-site navigation.

### Breaking Changes

**Secure-by-default for mutation routes (v3.9.1)**

All POST, PUT, PATCH, and DELETE routes now require authentication. If your application has public mutation endpoints, mark them as open:

```typescript
// BEFORE (v3.8.x) — all routes were open by default
Router.post("/api/feedback", async (request, response) => {
  // Anyone could call this
});

// AFTER (v3.9.x) — opt out of auth for public endpoints
Router.post("/api/feedback", async (request, response) => {
  // Now requires auth unless you explicitly open it
}).secure(false);
```

**session.delete() replaces session.unset() (v3.9.0)**

The session method was renamed for cross-framework parity.

```typescript
// BEFORE (v3.8.x)
request.session.unset("userId");

// AFTER (v3.9.x)
request.session.delete("userId");
```

### Bug Fixes

**ESM compatibility (v3.9.4)**

Internal `require()` calls broke on Node 22 with ESM-only configurations. All internal imports now use the ESM `import()` function.

**Zero dependencies achieved (v3.9.3)**

The `better-sqlite3` native module was the last remaining npm dependency. This release replaced it with Node's built-in `node:sqlite` module. `npm install` no longer needs a C++ compiler or `node-gyp`.

---

## v3.8.x — Template Engine, Typed Params, Security (March 25–26, 2026)

The v3.8 line replaced the template engine, added typed route parameters, and introduced production-grade security middleware.

### Features

**Typed route parameters (v3.8.0)**

Route paths gained type annotations. The framework validates and converts parameters before your handler runs.

```typescript
Router.get("/products/{id:int}", async (request, response) => {
  // id is guaranteed to be an integer
  // /products/abc returns 404 automatically
});

Router.get("/prices/{amount:float}", async (request, response) => {
  // amount is a floating-point number
});

Router.get("/docs/{path:path}", async (request, response) => {
  // path captures everything including slashes: /docs/api/v2/users
});
```

**Template fallback (v3.8.0)**

Requesting `/hello` now serves `src/templates/hello.twig` or `src/templates/hello.html` when no route matches. No explicit route registration needed for static pages.

**Connection pooling (v3.8.1)**

Set `TINA4_DB_POOL=5` in your `.env` file and the framework creates five database connections. Requests distribute across them in a round-robin pattern.

**SecurityHeadersMiddleware (v3.8.1)**

A built-in middleware that sets `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy`, and `X-Content-Type-Options` on every response.

**Validator class (v3.8.1)**

Input validation with structured error responses:

```typescript
import { Validator } from "tina4-nodejs";

Router.post("/api/users", async (request, response) => {
  const errors = Validator.validate(request.body, {
    email: ["required", "email"],
    name: ["required", "minLength:2"],
    age: ["integer", "min:18"],
  });

  if (errors.length > 0) {
    return response.json({ errors }, 422);
  }
});
```

**Upload size limit and Docker support (v3.8.1)**

Set `TINA4_MAX_UPLOAD_SIZE=10mb` to cap file uploads. The `tina4 init` scaffolding now includes a multi-stage Alpine Dockerfile.

**base64encode and base64decode Frond filters (v3.8.0)**

```twig
{{ sensitiveId|base64encode }}
{{ encodedValue|base64decode }}
```

**Production template caching (v3.8.0)**

Template lookups are cached in production mode. In development mode, the framework reads the filesystem on every request so changes appear without a restart.

### Breaking Changes

**Frond replaces Twig dependency (v3.8.4)**

The `@tina4/twig` npm package was removed. The framework now uses its built-in Frond engine for all template rendering. Frond supports the same Twig syntax, but if your templates relied on Twig-specific extensions, you need to rewrite them as Frond filters.

```typescript
// BEFORE (v3.7.x) — Twig as a separate dependency
// package.json included "@tina4/twig": "^1.x"
// Templates used Twig-specific extensions

// AFTER (v3.8.x) — Frond is built in, zero dependencies
// Remove @tina4/twig from package.json
// Templates use Frond filters (same Twig syntax, built-in engine)
```

**Groundwork for zero dependencies (v3.8.4)**

v3.8.4 began migrating from `better-sqlite3` to Node's built-in `node:sqlite` module. The migration completed in v3.9.3.

---

## v3.7.x — Template Auto-Serve, Firebird Migrations (March 25, 2026)

A focused release. Two features, no breaking changes.

### Features

**Template auto-serve at / (v3.7.0)**

Place `index.html` or `index.twig` in `src/templates/` and the framework serves it at `/`. User-registered `GET /` routes take priority. When neither exists, the Tina4 landing page appears.

**Firebird idempotent migrations (v3.7.0)**

`ALTER TABLE ADD` statements on Firebird now check `RDB$RELATION_FIELDS` before executing. If the column exists, the migration logs "already applied" and moves on. Other databases and statement types are unaffected.

---

## v3.6.x — Architectural Parity (March 25, 2026)

### Features

**src/orm/ as primary model directory (v3.6.0)**

Models now live in `src/orm/` by default, matching the convention across all Tina4 frameworks. The framework still scans `src/models/` as a fallback.

### Bug Fixes

**Outdated API references (v3.6.0)**

Internal references to deprecated function names (`createToken` instead of `getToken`, `validateToken` instead of `validToken`) and route parameter syntax were updated.

---

## v3.5.x — Bundled Frontend, Middleware (March 25, 2026)

### Features

**Bundled tina4js.min.js (v3.5.0)**

The reactive frontend library ships inside the framework. A 13.6 KB file gives your templates reactive signals, client-side routing, and API calls with zero additional installs.

**session.clear() (v3.5.0)**

Wipe all session data without destroying the session itself. The session ID and cookie persist.

```typescript
// clear() removes data but keeps the session alive
request.session.clear();

// destroy() ends the session entirely
request.session.destroy();
```

**Standardized middleware classes (v3.5.0)**

Middleware follows a naming convention: `before*` classes run before the handler, `after*` classes run after. Three built-in middleware classes ship with the framework.

---

## v3.4.x — Database, Auth, WebSocket, Uploads (March 24, 2026)

The v3.4 line added production-grade features across several subsystems.

### Features

**Database class wrapper (v3.4.0)**

A constructor-based pattern for database connections, replacing bare function calls:

```typescript
import { Database } from "tina4-nodejs";

const db = new Database("sqlite://data.db");
const result = await db.fetch("SELECT * FROM users WHERE active = ?", [true]);
```

**DatabaseResult with columnInfo() (v3.4.0)**

Query results return a `DatabaseResult` object. Call `columnInfo()` to inspect column names, types, and sizes without a separate schema query.

```typescript
const result = await db.fetch("SELECT * FROM users LIMIT 1");
const columns = result.columnInfo();
// [{ name: "id", type: "INTEGER" }, { name: "email", type: "VARCHAR" }, ...]
```

**Auth class wrapper (v3.4.0)**

Authentication functions grouped into a class with `getToken()` and `validToken()` as the primary API. The old names `createToken` and `validateToken` remain as aliases.

```typescript
import { Auth } from "tina4-nodejs";

const token = Auth.getToken({ userId: 42, role: "admin" });
const payload = Auth.validToken(token);
```

**Redis session handler (v3.4.0)**

Sessions can now persist to Redis for multi-server deployments. Set `TINA4_SESSION_HANDLER=redis` in your `.env` file.

**Path-scoped WebSocket broadcast (v3.4.0)**

Broadcast messages to WebSocket clients subscribed to a specific path:

```typescript
Router.websocket("/chat/{room}", (connection, request) => {
  connection.onMessage((message) => {
    connection.broadcast(message); // Only reaches clients on the same path
  });
});
```

**File uploads with raw Buffer and data_uri (v3.4.0)**

Uploaded files include a raw `Buffer` and a `data_uri` template filter for embedding images directly in HTML.

### Breaking Changes

**WebSocket handler signature changed to 3 arguments (v3.4.0)**

WebSocket handlers now receive `(connection, request, params)` instead of `(connection, request)`.

```typescript
// BEFORE (v3.3.x)
Router.websocket("/ws", (connection, request) => {
  // No access to path params
});

// AFTER (v3.4.x)
Router.websocket("/ws/{room}", (connection, request, params) => {
  const room = params.room;
});
```

**Auth function rename (v3.4.0)**

`getToken()` and `validToken()` are now the primary function names. The old names `createToken` and `validateToken` continue to work as aliases but are deprecated.

```typescript
// BEFORE (v3.3.x)
const token = Auth.createToken({ userId: 42 });
const valid = Auth.validateToken(token);

// AFTER (v3.4.0)
const token = Auth.getToken({ userId: 42 });
const valid = Auth.validToken(token);
```

**Queue job file extension (v3.4.0)**

Queue jobs on the file backend use `.queue-data` instead of `.json`. Existing `.json` job files need renaming or the queue treats them as new.

**File upload format (v3.4.0)**

Upload objects now use `{ type, content }` where `content` is base64-encoded. Legacy property names (`filename`, `data`) remain as aliases.

---

## v3.3.x — Queue API, Field Mapping, Route Chaining (March 24, 2026)

### Features

**Queue API (v3.3.0)**

Produce jobs, consume them with an async generator, and manage their lifecycle:

```typescript
import { produce, consume, Job } from "tina4-nodejs";

// Produce a job
await produce("email-queue", { to: "user@example.com", subject: "Welcome" });

// Consume jobs
for await (const job of consume("email-queue")) {
  try {
    await sendEmail(job.data);
    job.complete();
  } catch (error) {
    job.fail(error.message);
  }
}
```

Switch between SQLite, RabbitMQ, Kafka, and MongoDB backends with a single `.env` variable: `TINA4_QUEUE_BACKEND=rabbitmq`.

**ORM fieldMapping (v3.3.0)**

Map JavaScript property names to database column names explicitly:

```typescript
class User extends BaseModel {
  static fieldMapping = {
    firstName: "first_name",
    lastName: "last_name",
  };
}
```

**Route chaining with .secure() and .cache() (v3.3.0)**

Routes return a `RouteRef` that supports chainable modifiers:

```typescript
Router.get("/api/products", handler)
  .secure()
  .cache(300); // Cache for 5 minutes
```

**MongoDB queue backend (v3.3.0)**

The queue system gained MongoDB as a backend. Set `TINA4_QUEUE_BACKEND=mongodb` in your `.env` file.

**Database session handler (v3.3.0)**

Sessions can persist to any supported database. Set `TINA4_SESSION_HANDLER=database`.

**Dev admin improvements (v3.3.0)**

Routes in the dev admin panel are now clickable links that open in a new tab. The error overlay shows full request details.

---

## v3.2.x — Flexible Route Handlers (March 22, 2026)

### Features

**Zero-param and single-param route handlers (v3.2.0)**

Route handlers accept multiple signatures. The framework inspects the function's parameter names and injects the right objects.

```typescript
// All of these work:
Router.get("/health", () => ({ status: "ok" }));
Router.get("/health", (response) => response.json({ status: "ok" }));
Router.get("/health", (request, response) => response.json({ status: "ok" }));
```

Name your single parameter `request` or `req` and the framework passes the request object. Name it anything else and it receives the response.

---

## v3.1.x — Response Parity, Routing API (March 21–22, 2026)

### Features

**Explicit routing methods (v3.1.0)**

`Router.get()`, `Router.post()`, `Router.put()`, `Router.delete()`, and `Router.websocket()` replaced generic registration. Each method reads like what it does.

```typescript
import { Router } from "tina4-nodejs";

Router.get("/users", listUsers);
Router.post("/users", createUser);
Router.put("/users/{id:int}", updateUser);
Router.delete("/users/{id:int}", deleteUser);
```

**response.file() and response.render() (v3.1.0)**

Two new response methods for serving files and rendering templates:

```typescript
Router.get("/download", async (request, response) => {
  response.file("reports/quarterly.pdf");
});

Router.get("/dashboard", async (request, response) => {
  response.render("dashboard", { user: currentUser });
});
```

**FetchResult with toPaginate() (v3.1.0)**

Database queries return a `FetchResult` object with built-in pagination:

```typescript
const result = await db.fetch("SELECT * FROM products", [], 20, 0);
const paginated = result.toPaginate();
// { data: [...], total: 156, page: 1, perPage: 20, totalPages: 8 }
```

**ORM relationships (v3.1.0)**

`hasMany`, `hasOne`, and `belongsTo` with eager loading:

```typescript
class User extends BaseModel {
  static relationships = {
    posts: { type: "hasMany", model: "Post", foreignKey: "user_id" },
    profile: { type: "hasOne", model: "Profile", foreignKey: "user_id" },
  };
}

const user = await User.find(1, { include: ["posts", "profile"] });
```

**Unified Cache, Messenger, and Queue (v3.1.0)**

Switch between memory, Redis, and file-based caching with a single environment variable. The messenger and queue systems follow the same pattern. No code changes needed.

```bash
# .env

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

TINA4_CACHE_BACKEND=redis
TINA4_MESSENGER_BACKEND=redis
TINA4_QUEUE_BACKEND=sqlite
```

**tina4 generate command (v3.1.0)**

Scaffold models, routes, migrations, and middleware from the command line:

```bash
tina4 generate model User
tina4 generate route api/products
tina4 generate migration add_email_to_users
tina4 generate middleware AuthCheck
```

**Frond pre-compilation (v3.1.0)**

The template engine caches compiled tokens. File rendering runs 2.8x faster than v3.0.0.

---

## v3.0.0 — Initial Release (March 21, 2026)

The ground-up rewrite. No Express. No Fastify. No dependencies.

### Features

- **Native node:http** — The server uses Node's built-in HTTP module. Zero framework overhead.
- **TypeScript-first** — Strict mode, ESM only. No separate build step.
- **Database adapters** — SQLite, PostgreSQL, MySQL, MSSQL, and Firebird. Same API across all five.
- **File-based routing** — `src/routes/api/users/[id]/get.ts` maps to `GET /api/users/:id`.
- **Auto-CRUD** — Generate full REST endpoints from a model definition.
- **DevAdmin dashboard** — A built-in developer panel with route inspection and database tools.
- **AI integration** — Auto-detect and configure context for seven AI coding tools.
- **1,311 tests** across 43 test files.
- **Configurable port and host** — Default port 7148, binds to 0.0.0.0 for Docker.

```typescript
import { startServer } from "tina4-nodejs";

startServer({ port: 7148 });
```

One import. One function call. The server starts and your application is live.

---

## Pre-Release (rc.2–rc.5)

Four release candidates preceded v3.0.0. They stabilized the scaffolding, fixed the init command, added the error overlay, refined the landing page, and established the benchmark suite. If you started a project on a release candidate, upgrade to v3.0.0 and run `tina4 init` to regenerate your scaffolding files.

---

## Version Timeline

| Version | Date | Headline |
|---------|------|----------|
| v3.0.0 | March 21 | Initial release — zero dependencies, TypeScript-first |
| v3.1.0 | March 21 | Response parity, ORM relationships, unified cache/queue |
| v3.2.0 | March 22 | Flexible route handler signatures |
| v3.3.0 | March 24 | Queue API, field mapping, route chaining |
| v3.4.0 | March 24 | Database class, auth wrapper, Redis sessions, WebSocket broadcast |
| v3.5.0 | March 25 | Bundled frontend, standardized middleware |
| v3.6.0 | March 25 | src/orm/ as primary model directory |
| v3.7.0 | March 25 | Template auto-serve, Firebird idempotent migrations |
| v3.8.0 | March 25 | Typed route params, template fallback, Frond replaces Twig |
| v3.9.0 | March 26 | QueryBuilder, path injection, auto-start sessions |
| v3.10.0 | March 28 | Cached Frond instances, autoMap, ORM transactions, template fixes |
| v3.10.32 | March 31 | MCP server, arithmetic expressions, current stable |

Forty-two releases in eleven days. Each one a step closer to the framework the code deserves.
