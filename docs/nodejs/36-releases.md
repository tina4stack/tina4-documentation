# Chapter 35: Release Notes

## v3.13.38 (2026-06-19) - Coordinated security & robustness release

A large bundled release closing a cross-framework hardening sweep. **WebSockets:** the Redis/NATS backplane is now wired for real - local-first delivery, then a published envelope on the shared `tina4:ws` channel, relayed with an origin guard (no own-echo, no cluster loop) - plus an origin allow-list (`TINA4_WS_ALLOWED_ORIGINS`), an idle reaper (`TINA4_WS_IDLE_TIMEOUT`), slow-client backpressure drop (`TINA4_WS_MAX_BACKLOG`), and SSE hardening (heartbeat + mid-stream error + client disconnect). **Sessions:** the external handlers now throw a transport error instead of silently dropping data, with a log-loud-and-degrade boundary (`TINA4_SESSION_STRICT` to re-raise). **GraphQL/WSDL:** a SOAP `<!DOCTYPE>` is rejected before parsing, non-numeric SOAP int/float params now fault instead of silently yielding `NaN`, a recursion-depth guard (`TINA4_GRAPHQL_MAX_DEPTH`, default 50) catches deep queries **and** circular fragments, resolver/SOAP faults are masked in production (full detail only under `TINA4_DEBUG`), and GraphQL fragment spreads + inline fragments now parse and resolve (the parser used to error on `...`). **Tooling:** a new `tina4 metrics` command reports the top-N code-health offenders with `--top/--json/--fail-on/--path`, the coverage test-detection is now precise (a real import / defined-class reference, not a name-substring scan), `@tina4/orm` now has **zero hard dependencies** (`pg`/`mongodb` are optional), and the repo type-checks clean under tsc (`npm run typecheck`). Zero new third-party dependencies. Full suite: 4,244 passing.

## v3.13.37 (2026-06-18) - Dev-admin editor: TypeScript + Ruby highlighting fixed

The dev-admin file-read endpoint returned `{path, content, bytes}` with **no `language` field**, so the dashboard editor highlighted nothing - including `.ts`. It now returns a `language` (canonical extension map matching the Python master, plus no-extension `Dockerfile`), and the rebuilt editor bundle adds the Ruby/Rust/Go/Java/SCSS grammars. `.ts` and `.rb` now highlight correctly. Dev-mode tooling only. Full suite: 3,980 passing.

## v3.13.36 (2026-06-18) - Instant WebSocket dev-reload + dev-admin file browser fix

Dev-reload is now a WebSocket push, matching Python. `tina4 serve` POSTs `/__dev/api/reload`; the server re-imports changed routes in-process (no respawn, same PID) and broadcasts `{type, file, mtime}` over the `/__dev_reload` WebSocket upgrade route (debug-only, never mounted on the stable AI port). The injected client is WebSocket-primary and only polls `/__dev/api/mtime` when the socket drops. **Also fixed:** the dev-admin file browser returned `type` instead of `is_dir`, so folders never rendered in the dashboard tree - `/__dev/api/files` now returns `is_dir`, `has_children`, real per-entry `git_status` and the repo `branch`, full parity with Python/PHP. Full suite: 3,957 passing.

## v3.13.35 (2026-06-17) - Live MCP endpoint + working DB tools for AI agents

The built-in MCP server is now reachable and its database tools actually work. It was fully built but never mounted; ~10 dev tools used a bare `require` that's undefined under ESM (so they errored); and the DB tools read a `globalThis.__tina4_db` that nothing set - and called the async `Database` methods synchronously. Now: `DevAdmin.register()` mounts `/__dev/mcp` (JSON-RPC) + `/__dev/mcp/sse` in debug mode; `initDatabase()` exposes the Database on `globalThis.__tina4_db`; the tool dispatch is async end to end; and the require-based tools resolve correctly. An AI agent (Claude Desktop/Code) gets live access (real DB queries, file I/O, routes, docs) scoped to the running project. New regression tests; full suite 3,909 passing.

## v3.13.34 (2026-06-17) - Scaffolder fix + dual-port reload correction

`npx tina4nodejs init` scaffolded an unresolvable `"tina4-nodejs": "^0.0.1"` dependency and dev/serve scripts that invoked the Rust CLI - fixed to `^3.0.0` and `npx tina4nodejs serve` so a pure-npm project installs and runs. Corrected the AI dual-port dev mode, which was inverted vs Python: the **main port now hot-reloads** (dev toolbar + `/__dev_reload` injected) and **port+1000 is the stable AI port** - previously reversed, so the `tina4` client's reload POST (which targets the base port) never reached the browser. Full suite: 3,858 passing.

## v3.13.33 (2026-06-17) - Queues: priority pop + auto dead-lettering + TINA4_QUEUE_URL parity (⚠ behavioural change)

**Behavioural change.** `job.fail(reason)` now re-enqueues (incrementing `attempts` exactly once - a double-increment bug is fixed) until `attempts >= maxRetries`, then dead-letters - a `for await` consume loop retries automatically. `pop`/`consume` are now priority-ordered (was FIFO); new additive `retryBackoff`. **Config parity:** the broker backends now read `TINA4_QUEUE_URL` like Python/PHP/Ruby (per-backend `TINA4_RABBITMQ_*`/`KAFKA_*`/`MONGO_*` vars remain as overrides). Only the file backend changed for lifecycle. Queue chapter rewritten to match. Full suite: 3,858 passing.

## v3.13.32 (2026-06-17) - Caching: per-query bypass + string-middleware + X-Cache-TTL (chapter rewritten)

Added a per-query bypass - `await db.fetchAll(sql, params, limit, offset, { noCache: true })` (also `fetch`/`fetchOne`) skips lookup + store; the option is a trailing arg, not the params array. The `"ResponseCache:300"` string-middleware form now works (parity with Python/Ruby), and `responseCache` now also sets `X-Cache-TTL` alongside `X-Cache`. The caching chapter was rewritten to match code - correct async/await on every cache-aside example, real `cacheStats()` shapes, all seven backends + file fallback, the three cache layers - dropping earlier aspirational claims. Full suite: 3,801 passing.

## v3.13.31 (2026-06-17) - Version alignment (no functional change in Node)

Cross-framework version alignment with the Ruby request/response parity release. Node's request/response surface (parsed `req.body`, `req.query`, case-insensitive headers, `req.files[...].content` as a Buffer, `res.json`/`redirect`/`file`/`stream`) was already in parity - no behavioural change here. Full suite: 3,775 passing.

## v3.13.30 (2026-06-16) - Typed route params coerce + JWT expiry now in minutes (⚠ two breaking changes)

**Two behavioural changes.** (1) Typed path params now arrive coerced: `{id:int}` → `number`, `{price:float}` → `number` (other types and untyped params stay strings; matching unchanged) - previously the value was the string `"42"`. (2) `getToken` / `refreshToken` `expiresIn` is now in **minutes** (default 60), not seconds - matching Python/PHP/Ruby and Node's own docs; callers passing a seconds value (e.g. `3600`) must divide by 60. Both bring Node into cross-framework parity. Also fixed a stale `hashPassword` iteration-count docstring and a `refreshToken` signature drift in the guide. Full suite: 3,775 passing.

## v3.13.29 (2026-06-16) - Live API search ranks qualified queries + resolves the public import path

Parity with the Python master fix for the `api_*` live-reflection tools. (Node's `Frond.addFilter`/`addGlobal`/`addTest` are normal class methods the reflector already sees - the metaprogramming gap that hit Python/PHP doesn't apply.)

- **Class-qualified ranking.** `api_search("Frond.addTest")` now ranks `Frond.addTest` first - the owning class, fqn segments, and an exact `Class.method` match are scored.
- **Natural-name lookups.** `api_class`/`api_method` resolve the published import path (`@tina4/orm.Database`) and a bare class name, not just the stored fqn.

The bundled AI skills now tell assistants to query `api_*` before guessing. Full suite: 3,756 passing.

## v3.13.27 (2026-06-16) - Frond template-engine parity fixes

A 50-case cross-engine audit (every Frond tag, filter, and test rendered through all four frameworks with identical templates) surfaced two places where Node's output diverged from the Twig/Jinja standard. Both are now fixed to match:

<div v-pre>

- **`{{ "%.2f" | format(value) }}`** is now a real printf - it handles precision/width/flags (`%.2f` → `3.14`) instead of only `%s`/`%d`, and it resolves a *variable* argument to its value. Unquoted filter arguments are now treated as variable references (a `VarRef` resolved at apply-time); quoted literals stay literal, numbers/bools/null are coerced.
- **`nl2br`** escapes its input, inserts `<br />`, and is marked safe (it was emitting an un-safe `<br>` that the auto-escaper then escaped).

</div>

Behavioural note: these change rendered output for the affected filters - correctness fixes toward the documented Twig/Jinja behaviour. Full suite: 3,752 passing.

## v3.13.26 (2026-06-16) - pooling fix: standalone writes auto-commit; explicit transactions stay atomic

**Behavioural default change.** A standalone write - `execute`/`insert`/`update`/`delete` made **outside** an explicit transaction - now **auto-commits on its own connection before returning** (`autoCommit` default flipped to *on*). Previously autocommit was off by default, which broke connection pooling: a standalone write stayed uncommitted on one pooled connection while the next read round-robined to a different connection and saw nothing.

Explicit transactions stay atomic. The per-statement commit branches now also check whether a transaction adapter is pinned to the current async context (`AsyncLocalStorage`) and suppress the commit inside `startTransaction()` ... `commit()`/`rollback()`, so a `rollback()` still discards everything. Set `TINA4_AUTOCOMMIT=false` for strict manual-commit mode.

Verified live on PostgreSQL: standalone write visible from a separate connection, explicit rollback discards, explicit commit persists, and pooled standalone writes visible across every round-robin connection. Full suite: 3,748 passing.

## v3.13.25 (2026-06-16) - Node.js: distributed responseCache + persistent DB cache (async completion)

**Node.js only.** Completes the async cache work so Node reaches full parity with Python, PHP, and Ruby on the *automatic* cache paths. Previously (v3.13.24) Node's `responseCache` middleware and persistent DB query cache ran in-process (per-instance) because the middleware runner and `db.fetch()` were synchronous; distributed caching needed the explicit KV API.

Now the middleware runner (`MiddlewareRunner.runBefore`/`runAfter`) is **async**, so the `responseCache` middleware routes GET-response caching through the unified async backend - cached responses **distribute across instances** via `redis`/`valkey`/`memcached`/`mongodb` (selected by `TINA4_CACHE_BACKEND`). The **persistent DB query cache** (`TINA4_DB_CACHE=true`) routes through the async `fetchAsync` path to the same backend (`TINA4_DB_CACHE_BACKEND` + `TINA4_DB_CACHE_URL`), so multiple instances share one DB-query cache with global write-invalidation. The previous in-process-only restriction and its warning are gone.

The default backend remains `memory` (in-process - behaviour unchanged for apps that don't opt into a network backend); the request-scoped auto cache (`TINA4_AUTO_CACHING`) stays in-process by design (ephemeral, fastest). All network I/O is native async (no child processes).

Full suite: 3,804 passing.

## v3.13.24 (2026-06-15) - unified cache backends across response, KV, and persistent DB cache

The response/KV cache now supports **seven backends**, selected by `TINA4_CACHE_BACKEND`: `memory` (default), `file`, `redis`, `valkey`, `memcached`, `mongodb`, and `database`. `TINA4_CACHE_URL` carries the connection string for `redis`/`valkey`/`memcached`/`mongodb`, or a SQL URL for the `database` backend (which falls back to `TINA4_DATABASE_URL`). Credentials can be embedded in the URL (`redis://user:pass@host`, `redis://:pass@host`, `mongodb://user:pass@host`) or supplied via `TINA4_CACHE_USERNAME` / `TINA4_CACHE_PASSWORD` (mirroring `TINA4_DATABASE_USERNAME`/`_PASSWORD`); memcached is unauthenticated. The usual `TINA4_CACHE_TTL` (60), `TINA4_CACHE_MAX_ENTRIES` (1000), and `TINA4_CACHE_DIR` (`data/cache`) still apply.

**Graceful fallback:** if a configured backend's driver is missing or the service/credentials are unreachable or wrong, the cache logs a warning and falls back to the **file** backend - a real persistent cache, never a silent no-op.

The **persistent DB query cache** (`TINA4_DB_CACHE=true`) now routes through the same backend set via `TINA4_DB_CACHE_BACKEND` + `TINA4_DB_CACHE_URL`. `db.cacheStats()` reports `mode`, and the KV `cacheStats()` reports a `backend` field.

**Node characteristic (by design):** Node's KV API is **async** - `await cacheGet(...)`, `await cacheSet(...)`, etc. - matching Node's async-everywhere idiom, and all seven backends use native async clients (no child processes). Because Node's middleware runner and `db.fetch()` are synchronous, the **`responseCache` middleware and the persistent DB query cache run in-process (per-instance) in Node**; for distributed, cross-instance caching in Node, use the async KV API (`await cacheGet`/`cacheSet`). The other three frameworks route those auto-paths through the configured backend (distributed). A full async middleware/DB pipeline is a future-major item.

Full suite: 3,787 passing.

## v3.13.23 (2026-06-15) - request-scoped DB query cache, on by default (+ cache fixes)

A new **request-scoped query cache** protects your database from rapid repeat reads. Within a single request, identical `SELECT`s and ORM reads are deduped automatically - the DB is hit once and subsequent identical reads are served from memory. The cache is **cleared at the start of every request** (so it never serves stale rows across requests) and **flushed on any write** (insert/update/delete/execute). For non-request contexts (scripts, workers) a short safety TTL applies.

It is **on by default** via `TINA4_AUTO_CACHING=true` (off-switch `TINA4_AUTO_CACHING=false`); the in-request TTL is `TINA4_AUTO_CACHING_TTL` (default 5 seconds). The existing `TINA4_DB_CACHE` (default `false`) remains the separate *persistent* cross-request cache (TTL `TINA4_DB_CACHE_TTL`, default 30s) and is not cleared per request. `db.cacheStats()` now reports a `mode` field: `"request"` (default), `"persistent"`, or `"off"`.

**Also fixed (Node):** `cacheStats()` now reflects the real KV backend (it was wrongly reading the response-cache middleware store). And the DB query cache - previously dead code, where `db.cacheStats()` hardcoded `size: 0`, `db.cacheClear()` was a no-op, and the cache wrapper was never applied - now actually caches `db.fetch()` **and** ORM reads, with real `db.cacheStats()` / `db.cacheClear()`.

Full suite: 3,708 passing.

## v3.13.21 (2026-06-15) - docs: `render()` corrections + version re-sync

Documentation consistency pass - no behavior change. The `res.template(...)` reference in `llms.txt` and a stale `server.ts` comment are corrected to **`res.render(...)`** - the real method; `template` is only the route-level binding (`export const template`), not a response method. Version re-synced to 3.13.21 with the other frameworks (this release also carries a Python-side JWT-secret security hardening).

Full suite: 3,684 passing.

## v3.13.20 (2026-06-15) - Node.js: global class middleware (`Router.use`) now runs

**Node.js only.** Class-based middleware registered globally with `Router.use(SomeMiddleware)` was never executed - only per-route `.middleware(fn)` and the built-in CORS / logger / rate-limiter chain ran. The documented pattern (register a `beforeX`/`afterX` class once and have it apply to every route) silently did nothing.

`startServer` now runs every globally-registered class middleware around each route handler: `beforeX` hooks run **before** the handler (they can set response headers, mutate the request, or short-circuit by setting a status ≥ 400), and `afterX` hooks run **after** it. This brings Node to parity with Python, PHP, and Ruby, whose `Router.use` class middleware already ran.

```typescript
class PoweredBy {
  static beforePoweredBy(req, res) {
    res.header("X-Powered-By", "Tina4");
    return [req, res];
  }
}
Router.use(PoweredBy);   // now applies to every response
```

Note: in Node the response is flushed by the handler, so set response headers in `beforeX` (they persist through the handler's write); `afterX` is for logging / post-processing (header changes after the body is sent are no-ops). Full suite: 3,684 passing.

## v3.13.19 (2026-06-15) - return domain objects, construct from JSON, and one database binder

Three ergonomic improvements surfaced by the live side-by-side review of the book's own examples across all four frameworks.

### `response(...)` serializes domain objects

Return an ORM model, an array of models, or a query result straight from a route - Tina4 serializes it to JSON. No more hand-rolled `toDict()` / `toJson()`:

```typescript
get("/api/users", async (req, res) => {
  res.json(await User.all());        // array of models -> JSON array
});
```

A single model becomes a JSON object; an array of models or a `DatabaseResult` becomes a JSON array. Plain objects, arrays and strings behave exactly as before - purely additive.

### Construct a model from a JSON object string

```typescript
new User('{"name": "Alice"}');     // JSON object string -> one record
new User({ name: "Alice" });       // still works
```

Passing an **array** to a single-record constructor now throws a clear `TypeError` (previously it silently produced an empty model). To build many records, map over the list.

### One database binder: `bindDatabase` (+ named connections)

Node gains a public **`bindDatabase(adapter, name?)`**. This is **not a breaking change** - `initDatabase()` (which auto-binds the `.env` default) and the internal `setAdapter()` are unchanged.

```typescript
// Most apps: nothing to do - initDatabase() auto-binds the .env default at boot.

bindDatabase(adapter);                       // set/override the default explicitly

// Register a NAMED connection and point a model at it:
bindDatabase(await createAdapterFromUrl("postgres://u:p@.../analytics"), "analytics");

class Visit extends BaseModel {
  static _db = "analytics";          // uses the analytics connection
}
```

`bindDatabase(adapter, "...")` registers a named connection; a model selects it with `static _db = "..."`. A mistyped/missing named connection now throws a clear error instead of silently falling back to the default.

Full suite: 3,679 passing. Shipped with parity across all four frameworks (where the binder is named `bind_database` in Python/Ruby and `bindDatabase` in PHP/Node).

## v3.13.18 (2026-06-15) - ORM eager-load + include + aggregate fixes

Found by the live side-by-side validation against PostgreSQL. (No v3.13.17 - that was a PHP/Ruby release; Node goes 3.13.16 → 3.13.18.)

- **Eager load (`include`) silently returned no relations** in standalone use - `_eagerLoad` processed foreign keys only on the parent model, but the `hasMany` registry entry is registered by the *child* model's `_processForeignKeys()`, which is never called outside server boot. It now processes all registered models' FKs, so `Model.findById(id, ["Related"])` populates relations as documented.
- **`include` keys are now resilient** - matched case-insensitively against the model name, its singular/plural key, or the related table name; an include name that matches nothing emits a `Log.warn` instead of silently doing nothing.
- **Aggregate columns return numbers** - `SUM()`/`AVG()` came back as strings (node-postgres returns `int8`/`numeric` as strings). The PostgreSQL adapter now registers type parsers (`int8`, `numeric` → number) so aggregates match Python/Ruby/PHP. (Values beyond `Number.MAX_SAFE_INTEGER` lose precision - documented; cast to `::text` when exactness is needed.)

Full suite: 3,653 passing.

## v3.13.16 (2026-06-15) - ⚠ Async database API (BREAKING) + `createTable` on PostgreSQL + result indexing

Found by the live documentation-verification pass - running the book's own samples against a real PostgreSQL database. The entire documented `Database`/`BaseModel`/`QueryBuilder` API was unusable on PostgreSQL (and MySQL/MSSQL/Firebird/MongoDB): every call threw `Use fetchAsync() for PostgreSQL.`

### ⚠ Breaking: the database / ORM / QueryBuilder API is now uniformly async

The Node DB layer was sync-first (built around synchronous `node:sqlite`). The async adapters implemented only `*Async` methods and made the sync methods throw - so the documented API worked **only on SQLite**. The public API is now uniformly **async** (returns Promises) and works identically across every engine - the cross-engine parity the docs always promised.

```ts
// before (worked only on SQLite):
const rows = db.fetch("SELECT * FROM users");
const user = User.find(1);
const list = QueryBuilder.fromTable("users").get();

// now (all engines, incl. PostgreSQL):
const rows = await db.fetch("SELECT * FROM users");
const user = await User.find(1);
const list = await QueryBuilder.fromTable("users").get();
```

**Migration - add `await`** to: `db.fetch / fetchOne / fetchAll / execute / executeMany / insert / update / delete / startTransaction / commit / rollback / tableExists / getTables / getColumns / getNextId`; all `BaseModel` operations (`save / find / findById / all / where / count / createTable / delete / ...`); and `QueryBuilder.get / first / count / exists`. Pure builders and serializers stay synchronous (`toSql`, `toMongo`, `toDict`, `toJson`) - so relationships must be eager-loaded (via `include`) before a synchronous `toDict`/`toJson`.

### `createTable` engine-aware on PostgreSQL

Now emits `TIMESTAMP` for datetime, native `BOOLEAN` for boolean, and `SERIAL` for auto-increment on PostgreSQL; a failed `CREATE` no longer reports success.

### `result[0]` index access

The book documents `const firstUser = result[0]`; `DatabaseResult` now supports integer index access (alongside iteration, `length`, and `.at()`).

Verified against PostgreSQL 16: `db.fetch/fetchOne/execute`, `BaseModel.createTable + save + findById + all + count`, and `QueryBuilder.get/count/exists` all work. New PG-backed test; 10 SQLite test files updated to `await` (the intended breaking change). Full suite: 3,644 passing across 97 files.

## v3.13.14 (2026-06-13) - Logs reach stdout in containers + per-request logging + schema-qualified tables (#48)

**Cross-framework release (all four).** Deployed Docker containers were getting no application logs. In production Node's logger gated console output behind `!Log.isProduction()` (which is `!TINA4_DEBUG`), so a deployed app - where `TINA4_DEBUG` is off - printed nothing to stdout, writing only to `logs/tina4.log` inside the container. `docker logs` reads PID 1 stdout, so it was empty. A follow-on report - the dev server going silent after startup - surfaced a second gap in the other frameworks: requests weren't logged.

### Per-request logging - now gated, routed through Log

Node already logged every request, but via a bare `console.log` with a status-first format, and **always on** (even in production). v3.13.14 aligns it with the family:

```
2026-06-12T10:15:03.221Z [INFO   ] GET /api/users -> 200 (12.3ms)
```

- Routed through the Tina4 `Log` (so prod → JSON, dev → human) instead of `console.log`.
- Gated by `TINA4_LOG_REQUESTS`: on by default in dev (`TINA4_DEBUG`), **off by default in production** (was always-on) so prod doesn't pay the per-request cost unless you opt in with `TINA4_LOG_REQUESTS=true`.
- Standard line format `METHOD /path -> STATUS (Nms)`, identical across all four frameworks (was `  STATUS METHOD url ms`).

### What changed (stdout)

1. **Console output is no longer gated on `isProduction()`.** Logs go to stdout in production too (subject to `TINA4_LOG_OUTPUT` and level).
2. **Production emits structured JSON** to both stdout and the file (parity with Python/Ruby - Node previously wrote *text* to the file in production unless `TINA4_LOG_FORMAT=json`). Dev keeps the coloured human-readable line.
3. **Default log level is `INFO`** (was `DEBUG`).

```typescript
// In a container (TINA4_DEBUG off), default config:
Log.info("worker started");
// pre-v3.13.14: console suppressed in production → docker logs empty
// v3.13.14:    {"timestamp":"...","level":"INFO","message":"worker started"} on stdout
```

> Node cluster workers (production auto-cluster) inherit the primary's stdio by default, so worker logs already propagate to the container's stdout - no change needed there.

### Why it spanned all four

The same logging-in-containers gap showed up in every framework:

| Framework | Pre-v3.13.14 cause | Fix |
|---|---|---|
| Python | `not _is_production` gate suppressed stdout; default ERROR | stdout always on (flushed); default INFO |
| PHP | `$stdout = $development` (file-only in prod); no `TINA4_LOG_LEVEL` read | stdout default on + `fflush`; reads `TINA4_LOG_LEVEL`; default INFO |
| Ruby | stdout written but never flushed (block-buffered on non-TTY); default ALL | `$stdout.sync = true`; default INFO; accepts plain + bracket names |
| Node | `!isProduction()` gate suppressed console; default DEBUG | console always on; production emits JSON; default INFO |

The Rust `tina4` CLI was already correct (inherits child stdio).

### Schema-qualified tables (#48) + a PostgreSQL `fetch()` regression

Issue #48 - *"Database Table Does Not Exist"* on PostgreSQL. A model whose table lives in a non-default schema (`gift_cards.gift_card`, MSSQL `dbo.widget`, MySQL `otherdb.table`, SQLite ATTACH `extra.widget`) was invisible to the framework's introspection. `tableExists`, `getTables`, and `getColumns` hardcoded the default namespace (`public`) and matched the whole dotted string as one flat name - so plain reads worked, but `createTable`, migrations, and auto-CRUD were blind to the table and reported it missing.

A shared `SQLTranslator.splitSchema()` helper drives schema-awareness in every affected adapter:

- **PostgreSQL** - `tableExists` uses `to_regclass()` (honours schema + `search_path`); `getColumns` filters by `table_schema`; `getTables` lists every non-system schema and returns non-`public` tables schema-qualified.
- **MySQL** - schema = database; a qualified name checks that catalog, a bare name defaults to `DATABASE()` (`DESCRIBE` back-quotes each part).
- **MSSQL** - honours `dbo.table`; a bare name matches in any schema.
- **SQLite** - honours an ATTACH alias (`extra.widget`) for both `tableExists` and `getColumns`.
- **Firebird** - N/A (no schemas).

Verified against a live PostgreSQL 16 container: `tableExists('gift_cards.gift_card') → true`, `getTables → ['gift_cards.gift_card', 'gift_cards.transaction']`, `getColumns → 12 columns` - identical results across all four frameworks.

> **PHP also fixed a v3.13.12 regression found while cross-checking #48.** Its `PostgresAdapter` referenced `stripTrailingSemicolons()` (added in v3.13.12) and the new `splitSchema()` but never mixed in `SqlNormalizerTrait` - so **every PostgreSQL `fetch` / `fetchOne` / `getColumns` fatalled**. It shipped silently because the PostgreSQL test suite skips without a live server. Fixed and pinned by server-free reflection guards.

### Tests

- Node: 3,628 passed (+16 net - production JSON stdout; request-log gating, format, and Log routing; #48 schema split + SQLite ATTACH introspection)
- Family: Python 2,829 · PHP 2,394 · Ruby 2,999 · Node 3,628 - **11,850 total, zero regressions.** (PHP also fixed #119, a `cli-server` boot crash, and the PG `fetch` regression above.)

---

## v3.13.12 (2026-06-11) - SQL safety + implicit ORM binding + `fetchAll` correctness

Three high-impact fixes that close out long-standing footguns. All three ship with full parity across all four frameworks.

### `fetchAll` actually fetches ALL rows now (no silent 100-row truncation)

Pre-v3.13.12 the Python/PHP/Ruby conveniences silently truncated at 100 rows. Node already had the correct semantics (the `limit` parameter is optional and `undefined` skips LIMIT injection at the adapter layer), but this release locks the contract in with explicit tests:

```typescript
// 150 rows in the table
db.fetchAll("SELECT * FROM rows");           // → 150 rows (always did, now tested)
db.fetchAll("SELECT * FROM rows", undefined, 10);   // → 10 rows (explicit cap)
db.fetchAll("SELECT * FROM rows", undefined, 5, 20); // → 5 rows starting at offset 20
```

`db.fetch()` (the paginated sibling that returns a `DatabaseResult` with count metadata) keeps its 100-row default at the HTTP query-builder layer - pagination is its job. Only the low-level `db.fetchAll()` convenience returns everything.

For very large tables, prefer `db.fetch()` (returns a `DatabaseResult` with count) or pass an explicit `limit` to `db.fetchAll()`.

### Trailing `;` is now stripped from user SQL in `fetch()` / `fetchOne()`

The framework appends `LIMIT n OFFSET m` to the user-supplied query (and wraps it in `SELECT COUNT(*) FROM (...) AS subq` for the count probe). When the user's query already ended with a `;`, both rewrites broke:

```typescript
db.fetch("SELECT * FROM users;")
// pre-v3.13.12: syntax error near "LIMIT" - the appended LIMIT followed a ;
// v3.13.12:    works - trailing ; is stripped before LIMIT is appended
```

The strip is conservative: only trailing whitespace + semicolons are removed (any number of them, including `;;`), nothing inside the statement is touched. Parameters and quoting are unchanged - the existing parameter-binding defense against injection still does all the heavy lifting.

```typescript
import { stripTrailingSemicolons } from "@tina4/orm";

stripTrailingSemicolons("SELECT 1; ");       // "SELECT 1"
stripTrailingSemicolons("SELECT 1;;  ");     // "SELECT 1"
stripTrailingSemicolons("SELECT ';' AS x;"); // "SELECT ';' AS x"  (string literal preserved)
```

Applied at the top of `Database.fetch()` and `Database.fetchOne()`.

### Implicit ORM binding from `TINA4_DATABASE_URL`

Node already auto-discovered `TINA4_DATABASE_URL` via `initDatabase()` on the env-driven path - this release simply documents and pins it as parity behaviour. An explicit `initDatabase({ url, ... })` call still takes precedence and can be used to bind a second database.

### Cross-framework parity

| Fix | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| `fetch_all`/`fetchAll` returns ALL rows by default | ✓ `limit=0` default | ✓ `$limit = 0` default | ✓ `limit: nil` default | ✓ already correct (`limit?` undefined) |
| Strip trailing `;` from fetch SQL | ✓ shared helper on `DatabaseAdapter` | ✓ `SqlNormalizerTrait` on 5 adapters | ✓ `Tina4::Database.strip_trailing_semicolons` | ✓ exported `stripTrailingSemicolons` |
| Implicit ORM binding from env | ✓ already worked | ✓ already worked | ✓ **fixed** (wired `auto_discover_db`) | ✓ already worked |

### Tests

- Python: 2,811 passed (+24 new)
- PHP: 2,316 passed (+13 new)
- Ruby: 2,980 passed (+18 new)
- Node: 3,612 passed across 95 files (+16 new)

**11,719 tests across the family, +71 new for v3.13.12, zero regressions.**

---

## v3.13.11 (2026-06-11) - ORM correctness pass

Mirrors Python's ORM correctness pass. One Node-side change plus regression-pinning tests.

### #50.2 - `save()` correctly INSERTs natural (non-auto-increment) PKs

Pre-v3.13.11 the BaseModel `save()` decided INSERT vs UPDATE purely on `pkValue != null`. For models with a user-supplied PK (e.g. `gift_card_number = "GC-100"` set before the first save), this always picked UPDATE - matched zero rows - and silently returned success without inserting anything.

v3.13.11 checks `ModelClass.exists(pkValue)` for non-auto-increment PKs:

```typescript
class GiftCard extends BaseModel {
  static tableName = "gift_cards";
  static fields = {
    gift_card_number: { type: "string", primaryKey: true, maxLength: 50 },
    owner: { type: "string", maxLength: 120 },
  };
}

const gc = new GiftCard();
gc.gift_card_number = "GC-100";
gc.owner = "alice@example.com";
gc.save();                          // → INSERT (pre-v3.13.11: silent UPDATE no-op)
GiftCard.find({ gift_card_number: "GC-100" });  // → returns the row
```

Auto-increment PKs are unchanged: `pk == null → INSERT`, `pk != null → UPDATE`. The fix also stops the engine-assigned `lastInsertRowid` from overwriting a natural PK that the caller already set.

### #50.1 - callable defaults (N/A in Node)

The Python/Ruby auto-default-application pattern doesn't exist in Node's `BaseModel`. The constructor only copies provided data; field defaults are metadata used by `createTable()` for the DDL `DEFAULT` clause, not auto-applied at construction. If a user wants a callable default, they set the field manually before `save()`. Worth noting for parity but no source change needed.

### BooleanField engine-aware DDL (already correct in Node)

Node's per-adapter `fieldTypeTo*()` functions already mapped boolean to each engine's native type: PG → `BOOLEAN`, MySQL → `TINYINT(1)`, MSSQL → `BIT`, Firebird → `SMALLINT`, SQLite → `INTEGER`. Pinned with a regression test on SQLite.

### PG error-visibility fixes (Python only)

`node-postgres` uses libpq in autocommit mode - the InFailedSqlTransaction cascade that Python's psycopg2 produces never happens. No Node changes needed.

### Tests

3,596 passed across 94 files (+10 new - `test/ormV3_13_11.test.ts`). No regressions.

---

## v3.13.9 (2026-06-10)

Non-destructive AI installer - `installSelected()` / `installAll()` no longer clobber the user's `CLAUDE.md`. They write (or refresh) a marker-bracketed Tina4 skill block and leave the rest of the file alone.

### The bug

Pre-v3.13.9 the installer wrote a full developer guide to `CLAUDE.md` (and to `.cursorules` / `.github/copilot-instructions.md` / `.windsurfrules` / `CONVENTIONS.md` / `.clinerules` / `AGENTS.md` / `.antigravity/context.md`) on every run, clobbering whatever the user had put there. Comment in the old code: *"Always overwrite -- user chose to install"* - but they didn't choose to lose their notes.

### The fix

A marker-bracketed skill block - HTML comments for `.md` files, `#`-prefixed line comments for rule files:

```markdown
<!-- tina4-skills:start -->
## Tina4 Skills

- **tina4-maintainer** - Read `.claude/skills/tina4-maintainer/SKILL.md` for framework-level changes.
- **tina4-developer** - Read `.claude/skills/tina4-developer/SKILL.md` before building features.
- **tina4-js** - Read `.claude/skills/tina4-js/SKILL.md` for frontend work.
<!-- tina4-skills:end -->
```

Four behaviours:

1. **Fresh install** → write the framework guide plus the skill block.
2. **Marker refresh** (idempotent) → file exists with our markers → replace only the bracketed block.
3. **One-time migration** → file starts with the pre-v3.13.9 framework header → replace the old dump with the new framework guide + skill block.
4. **Preserve user content** → file exists with the user's own content (no markers, no old header) → append the skill block to the end, leave everything else verbatim.

The helpers (`markersFor`, `skillBlock`, `hasMarkers`, `replaceMarkerBlock`, `looksLikeOldFrameworkInstall`, `writeOrMerge`) are exported from `packages/core/src/ai.ts` so external tooling can compose them.

### Same algorithm in Python / PHP / Ruby

Identical four-branch logic, identical marker syntax, identical canonical action verbs in the log output. Skill content stays consistent across the family.

### Tests

46 new assertions in `test/aiInstaller.test.ts`. All four branches plus marker detection, block replacement, idempotency, old-header detection, and rule-file vs markdown-file behaviour.

3,586 passed across 93 files - no regressions.

### What you'll see when you re-install

```
✓ Migrated (replaced old framework dump in) CLAUDE.md   ← first run after upgrade
✓ Refreshed skill block in CLAUDE.md                     ← every subsequent run
✓ Appended skill block to CLAUDE.md                      ← user-curated file
```

---

## v3.13.7 (2026-06-10)

Two changes from the 24rent app-platform team (PLATFORM-2159) - one observability hook, one production-safety fix. Both ship across **all four frameworks** with identical event payload shape.

### NEW: `tina4.request.error` event

When the dispatch catch fires for a thrown route exception, the server now emits `tina4.request.error` **before** rendering the 500 page. Listeners receive `{ exception, request }` and can ship the failure to CloudWatch / Sentry / Slack - even though the framework caught it.

```typescript
import { Events, Log } from "@tina4/core";

Events.on("tina4.request.error", (payload: any) => {
  const err: Error = payload.exception;
  const req = payload.request;
  Log.error(`Route error: ${err.name}: ${err.message}`, {
    method: req?.method,
    path: req?.path,
  });
  // ...or POST to your centralised logging pipeline
});
```

- **Fires for caught route throwables.** Does NOT fire for 404s - those aren't server errors.
- **Listener errors are swallowed + warning-logged** so a broken listener can't break the 500 render.
- **Listeners fire in priority order** (higher priority first, matching `Events.on(event, cb, priority)`).
- **Identical event name + payload across Python / PHP / Ruby** - only the per-language syntax differs.

The dispatch catch also now calls `Log.error` with the exception name, message, method, and path. Previously route exceptions hit `console.error` (raw stderr); they now flow through the framework's structured logger so they reach the same sinks as everything else.

### FIX: Stack trace removed from production 500 body (CWE-209)

Before v3.13.7, an unhandled route exception in Node would (in some configurations) render the raw `String(err)` into the 500 response body - exception name, message, and depending on the renderer, the stack - when `TINA4_DEBUG` was truthy. That's [CWE-209 / OWASP A05](https://cwe.mitre.org/data/definitions/209.html): information disclosure.

<div v-pre>

The framework's own `packages/core/templates/errors/500.twig` now guards the trace block with `{% if error_message %}`. When `TINA4_DEBUG=false`, the dispatcher passes an empty `error_message` and the trace block doesn't render. The trace stays in `Log.error` (server-side) and reaches observability via the new event.

</div>

When `TINA4_DEBUG=true`, the rich `renderErrorOverlay()` page is unchanged.

### Tests

14 new assertions in `test/routerErrorEvent.test.ts`: event payload shape, listener priority order, no traceback markers in prod body, request_id still surfaces, listener-error safety, multiple-listener fanout.

- 3,540 tests passing across 92 files, no regressions.

### Background

Reported by DevProx on the 24rent platform - they centralise observability by scraping structured JSON lines from stderr → CloudWatch → a Slack notifier. Route-level exceptions weren't surfacing because the framework caught them silently. The event hook fixes that without forcing any team's logging convention; the trace-leak fix is independently a security concern.

---

## v3.13.6 (2026-06-09)

Parity bump alongside Python's #46 / #47 fixes, plus a Node-side polish on driver install hints.

### Better driver install hints (#47)

Missing-driver errors across all six adapters (PostgreSQL, MySQL, MSSQL, Firebird, ODBC, MongoDB) now suggest every common Node package manager instead of only `npm`:

```
PostgreSQL adapter requires the "pg" package. Install one of:
    npm install pg
    yarn add pg
    pnpm add pg
    bun add pg
```

Useful for monorepos and Bun/Yarn-first projects where the npm command is the wrong recommendation.

### #46 - PostgreSQL transaction cascade (no fix needed)

The cascade behaviour that prompted Python's #46 fix is psycopg2-specific (DB-API 2.0 mandates an implicit transaction on first statement). `node-postgres` runs in libpq autocommit by default - each query is its own transaction, so a failed query does not poison subsequent ones. The async PostgreSQL adapter already returns the error in its result object:

```typescript
const result = await db.executeAsync("SELECT * FROM does_not_exist");
result.success;  // false
result.error;    // 'relation "does_not_exist" does not exist'
```

Verified - no source change needed.

### Tests

3,526 passing across 91 files.

---

## v3.13.5 (2026-06-05)

Frond static-facade parity across PHP, Ruby, Node.js. Closes the last documented v3 parity gap (tina4-python task #32). Python's `Frond.add_filter` / `add_global` / `add_test` have worked as classmethods since v3.13.0 - now PHP / Ruby / Node match.

### What changes

Filters, globals, and tests registered at app-startup persist across `new Frond()` instances. Every framework now supports the same pattern:

```php
// PHP
\Tina4\Frond::addFilter("money", fn($v) => number_format((float)$v, 2));
\Tina4\Frond::addGlobal("APP_NAME", "My App");
\Tina4\Frond::addTest("positive", fn($v) => $v > 0);
```

```ruby
# Ruby
Tina4::Frond.add_filter("money") { |v| "%.2f" % v.to_f }
Tina4::Frond.add_global("APP_NAME", "My App")
Tina4::Frond.add_test("positive") { |v| v > 0 }
```

```typescript
// Node.js
Frond.addFilter("money", (v) => Number(v).toFixed(2));
Frond.addGlobal("APP_NAME", "My App");
Frond.addTest("positive", (v) => Number(v) > 0);
```

```python
# Python - already shipped in v3.13.0
Frond.add_filter("money", lambda v: f"{float(v):.2f}")
Frond.add_global("APP_NAME", "My App")
Frond.add_test("positive", lambda v: v > 0)
```

In every framework, registering at the class level updates a static registry. The next `new Frond()` drains that registry into its own filter/global/test maps automatically. No need to thread a single `Frond` instance through the application - register at startup, render everywhere.

### Instance form still works

Existing per-instance registration continues to work, and now propagates to the class registry too - so the lifecycle is symmetric:

```php
$frond = new \Tina4\Frond();
$frond->addFilter("currency", $fn);
// Future `new Frond()` instances also see "currency"
```

### `clearRegistry()` for test fixtures

Every framework exposes a class-level method to wipe user-registered filters/globals/tests without touching the built-ins (upper, lower, length, defined, even, ...). Useful in test setup/teardown to prevent state leaks between specs.

```php
\Tina4\Frond::clearRegistry();
```

```ruby
Tina4::Frond.clear_registry
```

```typescript
Frond.clearRegistry();
```

```python
Frond.clear_registry()
```

### Implementation notes per framework

| Framework | Mechanism |
|---|---|
| **Python** | `_ClassOrInstanceMethod` descriptor - one method, dual-callable via `__get__` |
| **PHP** | `__call` + `__callStatic` magic-method pair - PHP can't have same-name static and instance methods |
| **Ruby** | Same-name class method and instance method - Ruby naturally allows this |
| **Node.js** | TypeScript class supports same-name `static foo()` and `foo()` instance methods - distinct lookup spaces |

### Test count

| Framework | Before | After | New |
|---|---|---|---|
| Python | 2,741 | 2,741 | 0 (already covered) |
| PHP | 2,858 | 2,871 | +13 |
| Ruby | 2,907 | 2,928 | +21 |
| Node.js | 3,508 | 3,526 | +18 |
| **Total** | **12,014** | **12,066** | **+52** |

### Upgrade

Drop-in patch. No breaking changes. Existing instance-form code (`$frond->addFilter(...)` / `frond.add_filter` / `frond.addFilter`) keeps working unchanged. The new static form is purely additive.

## v3.13.4 (2026-06-04)

Three middleware/header bug fixes across all four frameworks, plus Python chapter 10 + 18 docs rewrites. Reported in tina4-book#140 and tina4-book#141 by MichaelC8E.

### PY-10-02 - `@middleware()` no longer silently disables auth (SECURITY)

**Before**: Applying `@middleware(...)` to a POST/PUT/PATCH/DELETE route silently flipped `auth_required = false`, removing the framework's built-in Bearer-token gate. A developer adding custom logging or rate-limiting middleware to an admin endpoint would, with no warning, open it to unauthenticated callers.

**After**: Middleware is purely additive. Write routes stay Bearer-token-gated by default. Use `@noauth()` to open a write route, `@secured()` to lock a read route. Same rule across all four frameworks.

This is a **behaviour change** - if your code relied on the old auto-disable to handle auth in custom middleware, add `@noauth()` (and have your middleware enforce auth on its own).

### PY-10-03 - `request.headers` is now case-insensitive

**Before**: `request.headers["Content-Type"]` returned `None`/`undefined`/`nil`. The dict was lowercase-only; mixed-case lookups silently failed. Six chapter 10 examples (`Content-Type`, `X-API-Key`, `Authorization`, `User-Agent`) were broken.

**After**: HTTP headers are case-insensitive per RFC 7230 §3.2. Same is true in every framework:

| Framework | Implementation |
|---|---|
| Python | `CaseInsensitiveDict` (dict subclass, normalises string keys to lowercase on read/write) |
| PHP | `Tina4\CaseInsensitiveArray` (ArrayAccess + IteratorAggregate + Countable) |
| Ruby | `Tina4::CaseInsensitiveHash < Hash` (overrides `[]`, `[]=`, `key?`, `delete`, etc.) |
| Node | Proxy wrapper around `http.IncomingHttpHeaders` |

`request.headers.get("Content-Type")`, `request.headers.get("content-type")`, and `request.headers.get("CONTENT-TYPE")` all return the same value. Existing lowercase code keeps working unchanged.

### PY-10-01 - Function-based middleware now runs

**Before**: Chapter 10 taught Express-style `async def mw(req, resp, next_handler)` in 8+ examples, but the Python framework's dispatcher only looked for class-based `before_*`/`after_*` methods. Function-style middleware was silently inert - body never executed. PHP and Ruby had similar gaps (closures ran but no `next` continuation).

**After**: Express-style continuation chain is implemented across the family. Python adds `_is_function_middleware()` + `_invoke_handler_with_middleware()`. PHP wraps closures with `array_reverse` continuation. Ruby uses lambdas + `reverse_each`. Node already had `next()` continuation - added a regression test to keep it green.

```python
@middleware(my_mw)
@post("/api/orders")
async def create_order(req, resp):
    ...

async def my_mw(req, resp, next_handler):
    if not authorised(req):
        return resp.json({"error": "forbidden"}, 403)
    result = await next_handler(req, resp)   # continue the chain
    return result
```

First-declared middleware is the outermost layer; calling `next_handler` descends to the next layer (or the route handler if last). Omitting the `next_handler` call short-circuits the chain.

### Python chapter rewrites - book + docs

- **Chapter 18 (Testing)** - Fixed PY-18-04 (test runner output now shows real pytest output, not the fictional `[PASS] test_addition` format), PY-18-07a (added missing `from src.orm.Product import Product` import), PY-18-08 (`resp.status_code` → `resp.status` across 14+ call sites, positional body `self.post(path, dict)` → keyword `self.post(path, json=dict)`).
- **Chapter 10 (Middleware)** - Added two callouts: headers are case-insensitive in v3.13.4+; `@middleware()` is purely additive (does not change auth_required). Existing mixed-case header examples now work against v3.13.4.

### Test count

| Framework | Before | After | New |
|---|---|---|---|
| Python | 2,725 | 2,741 | +16 |
| PHP | 2,844 | 2,858 | +14 |
| Ruby | 2,887 | 2,906 | +19 |
| Node.js | 3,477 | 3,508 | +31 |
| **Total** | **11,933** | **12,013** | **+80** |

### Upgrade

PY-10-02 is a behaviour change with a security implication. Audit routes that use `@middleware()` on POST/PUT/PATCH/DELETE: if you rely on custom middleware to handle auth, add `@noauth()` above `@middleware()` (and make sure your middleware enforces auth). Otherwise, no action - your write routes were always supposed to require Bearer tokens.

PY-10-01 and PY-10-03 are purely additive - no breaking changes.

## v3.13.3 (2026-06-03)

Two reporter-driven ergonomic additions, shipped across all four frameworks with full parity per `feedback_parity`.

### `Env` typed env-var helpers (tina4-python#43)

Reading env vars by hand gets old fast: every boolean flag becomes a `os.getenv("TINA4_DEBUG", "false").lower() in ("1", "true", "on", "yes")` incantation. Every numeric tuning knob needs a try/except around `int()`. `Env` centralises it:

```python
from tina4_python import Env

debug   = Env.bool("TINA4_DEBUG", default=False)
workers = Env.int("WORKERS", default=4)
rate    = Env.float("RATE_LIMIT", default=10.0)
region  = Env.str("AWS_REGION", default="us-east-1")
```

Same API across all four frameworks:

- **Python** - `from tina4_python import Env`
- **PHP** - `Tina4\Env::bool / int / float / str`
- **Ruby** - `Tina4::Env.bool / int / float / str`
- **Node.js** - `import { Env } from "@tina4/core"`

Truthy tokens (case-insensitive after `strip`/`trim`): `1`, `true`, `on`, `yes`, `y`, `t`. Falsy: `0`, `false`, `off`, `no`, `n`, `f`, empty string. Anything else returns the `default` - never raises. `int`/`float` parse failures log a warning via `Log` and fall back to default.

### Function-name in log lines (tina4-python#41)

Opt-in via `TINA4_LOG_FUNC=true`. When enabled, the calling function name is injected into every log line so a `tail -f` gives you free context:

```
2026-06-03T14:22:18.341Z [INFO   ] [super_trooper] Hello from inside the function
```

Or in JSON mode:

```json
{"timestamp":"...","level":"INFO","function":"super_trooper","message":"Hello..."}
```

Default off - zero overhead unless opted in. When on, ~5% per-call cost from the stack walk.

Per-framework implementation:

- **Python** - `inspect.currentframe()` walk past Log's own frames
- **PHP** - `debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS)` + `{closure}` filter
- **Ruby** - `caller_locations(2, 16)` + block-noise regex
- **Node.js** - `new Error().stack` regex parse + anonymous filter

Anonymous frames (`<lambda>`, `<module>`, `{closure}`, anonymous IIFEs) are filtered as noise - showing `[<lambda>]` would be uglier than nothing.

### Test count

| Framework | Before | After | New |
|---|---|---|---|
| Python | 2,675 | 2,725 | +50 |
| PHP | 2,780 | 2,844 | +64 |
| Ruby | 2,839 | 2,887 | +49 (+1 pre-existing rack_app fail unchanged) |
| Node.js | 3,420 | 3,477 | +57 |
| **Total** | **11,714** | **11,933** | **+220** |

### Upgrade

Drop-in patch. No breaking changes. Two new exports (`Env`, plus one new env var `TINA4_LOG_FUNC`). Existing logs and existing code keep working unchanged.

## v3.13.2 (2026-06-03)

Bug-fix patch - three field reports, fixed with full cross-framework parity audit per `feedback_crosscheck_bugs`.

### SCSS calc() with mixed units (tina4-python#42, tina4-php#116, tina4-nodejs#1)

The SCSS math evaluator silently folded mixed-unit arithmetic by keeping operand 1's unit and dropping operand 2's, producing wrong CSS:

- `max-height: calc(100vh - 170px)` → `calc(-70vh)` (negative, layout-breaking)
- `width: 100% - 20px` → `80%` (pixel term silently lost)
- `padding: 1rem + 4px` → `5rem`

Fixed in Python, PHP, and Node - the evaluator now captures both operand units, only folds when units match (or one side is unitless for `*`/`/`), and masks `calc(...)` ranges so the browser computes them as intended. Ruby unaffected (delegates to libsass).

### Router.group docs taught a crashing pattern (tina4-python#44)

The Python book and docs site showed `Router.group("/api/v1", lambda: [...])` with a zero-arg lambda. Source intentionally passes a `RouteGroup` instance to the callback, so users hit `TypeError: <lambda>() takes 0 positional arguments but 1 was given`. Docs rewritten to `lambda group: [group.get(...), group.post(...)]` matching the real contract (Node has always taught this correctly; PHP and Ruby use ambient state, no group arg needed).

### DATABASE_URL → TINA4_DATABASE_URL drift (tina4-python#45)

Three real bugs:

- **Python ORM error message** told users to "set DATABASE_URL in .env" - but the v3.12 boot guard rejects that bare name. Users following the error message hit a hard stop.
- **Python dev-admin `.env` writer** stripped the `TINA4_` prefix when updating existing rows, actively corrupting the config every time the user saved a new connection through the dashboard.
- **Node `Database.fromEnv()`** defaulted to `"DATABASE_URL"` as the env-var key, missing the project's actual connection. The ORM error message had the same drift.

All fixed. PHP and Ruby audited - already correct in both.

### Test count

| Framework | Before | After | New |
|---|---|---|---|
| Python | 2,665 | 2,675 | +10 |
| PHP | 2,774 | 2,780 | +6 |
| Ruby | 2,839 | 2,839 | 0 (parity bump only) |
| Node.js | 3,406 | 3,420 | +14 |
| **Total** | **11,684** | **11,714** | **+30** |

### Upgrade

Drop-in patch. No breaking changes. No new public API.

## v3.13.1 (2026-06-02)

Cross-framework parity patch. Closes the remaining audit-flagged docs-vs-code gaps that didn't make 3.13.0 - the documentation claimed APIs across PHP / Ruby / Node that only Python had. This release ships those APIs everywhere and rewrites the PHP chapters that referenced fictional symbols.

### Convenience parity additions (Groups A / B)

Three highest-impact cross-framework methods every documentation set already claimed existed. PHP / Ruby / Node now match Python:

- **`db.fetchAll(sql, params)` / `db.fetch_all` / `$db->fetchAll`** - returns the records list directly. Symmetric with `fetch_one`. For the 80% case where you don't need the `DatabaseResult` metadata.
- **`Database.getConnection(url)` / `.get_connection` / `::getConnection`** - classmethod factory matching SQLAlchemy's `engine.connect()`. Falls back to in-memory SQLite when no URL or env resolves.
- **`Api(bearerToken=, username=, password=, headers=, verifySsl=)` ergonomic kwargs** - three setter calls collapse to one constructor. Bearer wins over basic-auth when both are passed. `verifySsl=False` is the positive form of `ignoreSsl=true`.

### Decorator-style GraphQL resolvers across the family

Python `@GraphQL.resolve` shipped in 3.13.0. This release adds:

- **PHP** - `GraphQL::resolve("Type", "field", $callable)` static method + class-level resolver registry that `new GraphQL()` drains into its schema.
- **Ruby** - `Tina4::GraphQL.resolve("Type", "field") { |root, args, ctx| ... }` with block-based registration.
- **Node.js** - `GraphQL.resolve(typeName, fieldName, resolver)` matching the cross-framework shape.

All four frameworks now support the FastAPI / Strawberry / Ariadne pattern where resolvers register at module-import time before any `GraphQL` instance is constructed, and where post-startup registrations land in the active default singleton via `setDefault(gql)` / `Tina4::GraphQL.default_instance = gql`.

### Class-based service pattern across the family

`class FooWorker extends Service { run() { ... } }` - chapter 27 / equivalent docs have long taught this pattern. Until 3.13.1, only the runner was real:

- **PHP** - new `Tina4\Service` abstract base class + `ServiceRunner::registerService($name, $service)` static helper.
- **Ruby** - new `Tina4::Service` class + `Tina4::ServiceRunner.register_service(name, service)`.
- **Node.js** - new `Tina4Service` abstract class + `ServiceRunner.registerService(name, service)`.
- **Python** - new `tina4_python.service.Service` base + `ServiceRunner.register_service(name, service)` (this release closes the gap; Python had only the function-style runner before).

All four ship `run()` (abstract), `stop()`, and `should_stop()` / `shouldStop()` helpers backed by an internal flag. Function-style services using bare callables continue to work alongside the new class-based pattern.

### PHP chapter rewrites (`docs/php/` and `book-2-php/`)

The 3.13.0 audit found that the PHP testing-chapter disaster was the tip of a larger pattern - multiple PHP chapters taught APIs that didn't exist. 3.13.1 rewrites all seven of them:

- **Chapter 15 - Logging** - primary surface now `Tina4\Log::info()/warning()/error()` instead of the legacy `Tina4\Debug::message()` shim (still works).
- **Chapter 18 - Testing** - `$response->statusCode` → `$response->status` across 23 occurrences; CLI section updated (`tina4 test` runs the suite; `vendor/bin/phpunit` for targeted runs).
- **Chapter 19 - Scaffolding** - v2 `Tina4\Get::add()` / `Post::add()` / `Put::add()` / `Delete::add()` syntax replaced with `Tina4\Router::get/post/put/delete`; fictional `->description()` chain replaced with real `->swagger([...])`.
- **Chapter 22 - GraphQL** - chapter's decorator pattern (`GraphQL::resolve("Type", "field", $fn)`) now matches real source (built this release).
- **Chapter 25 - WSDL** - `@wsdl_operation` docblock replaced with `#[WSDLOperation([...])]` PHP attribute; methods now return associative arrays matching the response-shape spec; `Router::soap()` → `Router::any()` + manual `(new Service($request))->handle()`.
- **Chapter 27 - ServiceRunner** - `new ServiceRunner()` + `->add()` instance API replaced with `ServiceRunner::registerService()` + `ServiceRunner::start()` static API. The `Tina4\Service` base class the chapter teaches now exists.
- **Chapter 34 - Deployment** - un-prefixed env vars (`SECRET`, `CORS_ORIGINS`, `SMTP_USER`, `JWT_SECRET`, `API_KEY`, `SWAGGER_TITLE`) replaced with `TINA4_`-prefixed forms. The v3.12 boot guard rejects the legacy names with `exit(2)`.

### Test count

Net new across the family this release:

| Framework | Before | After | New |
|---|---|---|---|
| Python | 2,654 | 2,665 | +11 |
| PHP | 2,749 | 2,774 | +25 |
| Ruby | 2,827 | 2,839 | +12 |
| Node.js | 3,384 | 3,406 | +22 |
| **Total** | **11,614** | **11,684** | **+70** |

### Upgrade

Drop-in patch - no breaking changes. Existing source-code patterns from 3.13.0 continue to work; the new methods are additive. Documentation rewrites in chapters 15 / 18 / 19 / 22 / 25 / 27 / 34 redirect copy-paste examples to the real APIs the framework actually ships.

## v3.13.0 (2026-06-01)

The docs-vs-code parity release. A cross-framework audit of 381 markdown files surfaced 146 hallucinations, signature drifts, and stale references across Python, PHP, Ruby, Node, and tina4-js. 3.13.0 closes the chapter-18 disaster pattern - where documentation taught a class-based API that didn't exist - by shipping the missing pieces, renaming the misnamed pieces, and rewriting the aspirational chapters.

### The headline fire: `Test` class with HTTP helpers

Every framework's chapter 18 has long shown integration tests like:

```python
class UserApiTest(Test):           # tina4_python.test.Test
    def test_health(self):
        resp = self.get("/health")
        assert_equal(resp.status, 200)
```

Until 3.13.0, only `Test` (the bare assertion base) existed - calling `self.get(...)` crashed with `AttributeError`. The HTTP test client lived in a separate `TestClient` class that the docs never mentioned.

This release mixes `TestClient.get / post / put / patch / delete` into the `Test` base across every framework:

- **Python** - `tina4_python.test.Test` (extends `unittest.TestCase`, pytest auto-discovers)
- **PHP** - `Tina4\Test` (extends `PHPUnit\Framework\TestCase`)
- **Ruby** - `Tina4::Test` (zero-dep; built-in `run_all` runner)
- **Node.js** - `Tina4Test` (zero-dep; built-in `Tina4Test.runAll()` runner)

Plus positional assertions on every framework - `assertEqual(actual, expected, message)`, `assertNotEqual`, `assertTrue`, `assertFalse`, `assertNull`/`assertNullValue`, `assertNotNull`/`assertNotNullValue`, `assertRaises` - matching the documented `(actual, expected, message)` shape.

### `Auth.valid_token` now returns the payload, not a bare bool - **BREAKING**

The most common silent-fail pattern caught by the audit. Every framework's docs claimed `valid_token` returned the decoded JWT payload; every framework's source returned `bool` and forced a second `get_payload` call.

| Framework | Before | After |
|---|---|---|
| Python | `Auth.valid_token(token) → bool` | `Auth.valid_token(token) → dict \| None` |
| PHP | `Auth::validToken(token) → bool` | `Auth::validToken(token) → array \| null` |
| Ruby | `Auth.valid_token(token) → Boolean` | `Auth.valid_token(token) → Hash \| nil` |
| Node | `validToken(token) → boolean` | `validToken(token) → Record<string, unknown> \| null` |

Matches PyJWT / firebase-jwt-ruby / firebase/php-jwt / jsonwebtoken conventions. Truthy/falsy contract preserved - existing `if (validToken(t))` callers keep working because a non-null object is truthy and null is falsy.

### Python-specific groups (mirrored to PHP/Ruby/Node in follow-up patches)

The Python framework is the reference per `feedback_python_master`. Six groups landed in tina4-python:

- **Group A - ergonomic additions**: `Database.get_connection()`, `db.fetch_all()`, `db.pool`, `DatabaseResult.columns`, `Job.error`, `Queue.produce(delay_until=datetime)`, module-level `migrate(db)`/`rollback(db)`/`status(db)`, module-level `i18n.t()`, dict-style `session[key]`, `WebSocketConnection.connection_count`. All zero-risk additions - no signatures changed.
- **Group B - signature expansions**: `Api(bearer_token=, username=, password=, headers=, verify_ssl=)` kwargs, `Model.find(pk)` int overload (Active Record convention), `@description(summary, detail=, params=, query=)`, `@tags(str | list)`, `@example_response(status_code, data)`, `response.render(template, data, status_code)`, `response.cookie(name, value, options_dict)`, `response(data, headers={})`, `@get(path, description=, middleware=["ResponseCache:300"])` with string-form middleware parser.
- **Group C - mixins + decorators**: the Test HTTP mixin (covered above), `Frond.add_filter / add_global / add_test` callable as classmethod OR instance method via a `_ClassOrInstanceMethod` descriptor, `@GraphQL.resolve("Type", "field")` decorator with class-level registry - chapter 22's pattern now works as documented.
- **Group D - return-type changes (BREAKING)**: `Container.reset()` now clears singleton cache only (factories survive); new `Container.reset_all()` for the old wipe-everything behaviour. `queue.dead_letters()` returns `list[Job]` with `.error` populated, not `list[dict]`. `Model.where(..., with_count=True)` returns `(list, int)` tuple for pagination UIs.
- **Group E - renames (BREAKING)**: `ai.install_all()` → `ai.install_context()`; new `ai.detect_ai()`, `ai.detect_ai_names()`, `ai.status_report()`. `queue.consume(id=)` → `queue.consume(job_id=)`. `Api.send_request()` → `Api.send()`. `I18n(locale=, path=)` preferred over `I18n(locale_dir=, default_locale=)` (legacy kept). `TINA4_TOKEN_EXPIRES_IN` preferred over `TINA4_TOKEN_LIMIT` for JWT expiry (both honoured; new wins; constructor arg overrides both).
- **Group F - top-level re-exports + scaffolder**: `from tina4_python import Api, WSDL, wsdl_operation, GraphQL, AutoCrud, Messenger, on, emit, once, off, tests` now resolve. `Model.select()` with no args defaults to `SELECT * FROM <table>` so the CRUD-list scaffolder template's emitted code actually runs.

### PHP-specific: `Tina4\Debug` shim

Chapter 15 of the PHP logging docs taught `Tina4\Debug::message($msg, TINA4_LOG_INFO, [...])`. Neither the class nor the constants existed. Real logger is `Tina4\Log`.

This release ships a `Tina4\Debug` compatibility shim that forwards to `Tina4\Log`, plus defines the `TINA4_LOG_*` level constants - so the chapter's code samples run as-written. For new code, prefer `\Tina4\Log::info()` etc.

### Documentation sweep

Aside from the source-side changes, the audit caught hundreds of stale references in docs site + book + AI skills + CLAUDE.md files. All fixed in this release:

- ~80 occurrences of `from tina4 import` → `from tina4_python import` (the Python package is `tina4_python`, not `tina4`)
- `from tina4_python.router` → `from tina4_python.core.router`
- `TINA4_SESSION_HANDLER` → `TINA4_SESSION_BACKEND` (matches the env var the framework actually reads)
- `DATABASE_NAME=` → `TINA4_DATABASE_URL=` (legacy un-prefixed names get rejected by the v3.12 boot guard)
- `@cached(True, max_age=N)` → `@cached(max_age=N)` (bogus first arg)
- `Template.render()` → `response.render()` (Template class doesn't exist; renamed to Frond)
- `Debug.error()` → `Log.error()` in Python (Debug class doesn't exist)
- `Producer` / `Consumer` (removed in v3.2.0) → `Queue.push / consume`
- `Email` → `Messenger`, `event.fire / @listener` → `emit / @on`, `gql` singleton → `GraphQL()` + `@GraphQL.resolve`
- **Security fix**: `Auth.check_password(hash, password)` → `(password, hash)` in skill ref - the bcrypt comparison was returning False every time due to reversed args (silent-failure auth)
- `request.files['content']` is **raw bytes** - drop `base64.b64decode()` from upload examples
- Deployment chapter env vars all `TINA4_`-prefixed (un-prefixed names brick boot under v3.12 guard)

### Aspirational chapters rewritten

Two Python chapters were built on APIs that didn't exist:

- **Chapter 22 (GraphQL)**: rewritten around the new `@GraphQL.resolve("Type", "field")` decorator (the FastAPI/Strawberry pattern). The previous `gql.schema.add_query("name", {dict})` form still works but is no longer the primary documented path.
- **Chapter 25 (WSDL)**: rewritten around the real subclass pattern (`class Calculator(WSDL): @wsdl_operation({"Result": int}) def Add(self, ...): ...; Calculator(request).handle()`). The previous `WSDL(service_name=, namespace=, endpoint=)` constructor + `handle_wsdl` / `handle_request` API was entirely fictional.

### tina4-js doc drift caught

The cross-framework audit's synthesis pass dropped tina4-js findings; the raw agent transcripts had 23 real findings:

- Every import in CLAUDE.md and `docs/js/09-graphql.md` used `"tina4-js"` (with hyphen). The npm package is named `tina4js`. Fixed.
- `pwa({...})` was treated as callable; real API is `pwa.register({...})`. `PWAConfig.icon` is a single string, not an `icons: [...]` array.
- `static props = { label: { type: String, default: "..." } }` - the `{ type, default }` wrapper is fictional. Real shape is `static props = { label: String }`.
- `router.navigate('/users/42')` - `navigate` is a top-level export, not a method on `router`.
- Chapter 14's `<slot>` inside a `static shadow = false` component - slots are a Shadow DOM feature. Chapter 14 contradicted chapter 4. Switched to `shadow = true`.

### Test counts

Net new across the family:

| Framework | Before | After | New |
|---|---|---|---|
| Python | 2,537 | 2,654 | +117 |
| PHP | 2,742 | 2,749 | +20 |
| Ruby | 2,800 | 2,816 | +16 (1 pre-existing unrelated rack_app failure) |
| Node.js | 3,366 | 3,384 | +18 |
| **Total** | **11,445** | **11,603** | **+171** |

### Upgrade

`Auth.validToken` is the breakage to know about - your `if Auth::validToken($t)` style code keeps working unchanged because non-null arrays are truthy and null is falsy. If you do `=== true` / `=== false` strict comparisons, switch to `!== null` / `=== null`.

Python: `ai.install_all()` → `ai.install_context()`, `queue.consume(id=)` → `consume(job_id=)`, `Api.send_request()` → `Api.send()`, `Container.reset()` semantic change (use `reset_all()` for old behaviour).

Everything else is additive - new properties, new kwargs, new convenience methods that match what the docs have promised for years.

## v3.12.14 (2026-06-01)

Two independent fixes ship together as 3.12.14. **Python** - the `tina4_python.test` class-based xUnit testing surface that the chapter 18 documentation has always promised but never actually existed. Reports came in of developers copy-pasting `from tina4_python.test import Test, assert_equal, assert_true` straight out of the book and getting `ModuleNotFoundError`. The fix was to build the module to match the documentation, not the other way around. **PHP** - `:named` placeholder translation for the four non-PDO adapters where `ORM::save()` was silently failing.

### Python - `tina4_python.test` xUnit testing surface

The testing chapter taught a `Test` base class with positional assertions:

```python
from tina4_python.test import Test, assert_equal, assert_true

class BasicTest(Test):
    def test_addition(self):
        assert_equal(2 + 2, 4, "Basic addition should work")

    def test_string_contains(self):
        greeting = "Hello, World!"
        assert_true("World" in greeting, "Greeting should contain 'World'")
```

The module did not exist. Every developer who followed the chapter hit an immediate import error. The other surface, `tina4_python.Testing` with the inline `@tests` decorator, has always existed - but the two are for different purposes and the docs only documented one of them.

The fix ships the missing module - `tina4_python/test/__init__.py` - with the `Test` base class (inherits `unittest.TestCase`, so pytest discovers any subclass regardless of class-name convention) and 13 positional assertions. The signatures are uniform: `(actual, expected, message)`. The 2-arg legacy `(value, message)` form keeps working - a type-based dispatch detects which shape the caller used. `assert_raises` accepts three forms: docs form (`callable, exception, message`), context-manager form (`with assert_raises(X):`), and unittest order (`exception, callable`). Lifecycle hooks come in both flavours - snake_case `set_up`/`tear_down` (the Tina4 idiom) and camelCase `setUp`/`tearDown` (for users coming from unittest) - without double-calling when a subclass uses either one.

```python
# 13 assertions, all uniform (actual, expected, message)
assert_equal(actual, expected, message="")
assert_not_equal(actual, expected, message="")
assert_true(actual, expected=True, message="")
assert_false(actual, expected=False, message="")
assert_none(actual, expected=None, message="")
assert_not_none(actual, expected="not None", message="")
assert_in(item, container, message="")
assert_not_in(item, container, message="")
assert_is_instance(value, expected_type, message="")
assert_greater(actual, expected, message="")
assert_less(actual, expected, message="")
assert_almost_equal(actual, expected, places=7, message="")
assert_raises(callable, exception_class, message="")
```

51 new tests in `tests/test_test_module.py` pin the contract: BasicTest from the chapter runs verbatim, every assertion fails when it should and passes when it should, both 2-arg and 3-arg shapes work, snake_case and camelCase lifecycle hooks fire once each (never both). Full Python suite: 2,537 passing.

`tina4 test` continues to run pytest (`subprocess.run([sys.executable, "-m", "pytest", "tests/"] + args)`).

### Cross-framework parity check (testing)

PHP / Ruby / Node testing chapters already teach native conventions correctly - PHPUnit, RSpec, and `node:test` respectively. No fake API to fix. The Python-specific gap was that Tina4 had two testing surfaces (`tina4_python.Testing` for inline `@tests` decorator, `tina4_python.test` for class-based suites) and only one of the two existed. The other three frameworks defer to a single native runner each, so the same trap doesn't apply.

### PHP - :named placeholder translation across non-PDO adapters

The ORM's `save()` emits `:named` placeholders because PDO would accept them. Four of the five PHP database adapters do not use PDO. `MySQLAdapter` (mysqli), `MSSQLAdapter` (sqlsrv), `FirebirdAdapter` (ibase/fbird), and `PostgresAdapter` (pgsql) all bind positionally. Every INSERT/UPDATE through `save()` against those four engines failed silently. Reads worked because read paths typically use `?` or no params.

A single helper, `SqlTranslation::namedToPositional($sql, $params)`, translates `:name` to `?` and reorders `$params` to match the SQL order. Wired into the four affected adapters at the top of their prepare/execute paths. The helper skips string literals and SQL comments, so a literal `:colon` inside a value stays as a value. Duplicate names bind once per occurrence, so `WHERE id = :id AND parent_id = :id` works as expected.

`SQLite3Adapter` is untouched. ext-sqlite3 natively accepts `:name` via `SQLite3Stmt::bindValue`. The other four did not, and now do.

15 unit tests pin the helper in `tests/SqlTranslationNamedToPositionalTest.php`: order preservation, duplicate names, quoted strings, line and block comments, unknown placeholders, null values, and the `0`-as-value case. Full PHP suite: 2,290 passing.

### Cross-framework parity check (`:named` placeholders)

Python (`mysql-connector-python` uses `%s`), Ruby (`mysql2` uses `?`), and Node (`mysql2` uses `?`) build their INSERT/UPDATE SQL with positional placeholders from the ORM down. No `:named` ever emitted. Audited the MySQL adapter and `save()` path in each before shipping; confirmed clean. PHP-only fix.

### Upgrade

Drop in for both Python and PHP. No `.env` changes, no API changes.

**Python users** who followed chapter 18 and hit `ModuleNotFoundError` - bump to `3.12.14`, the `from tina4_python.test import Test, assert_equal, ...` import now resolves. Existing tests written against `tina4_python.Testing` (the inline `@tests` decorator) continue to work - that surface was not touched.

**PHP users** - `:named` and `?` both work, and the framework picks the right form for whichever driver is underneath. Existing ORM `save()` calls start succeeding on MariaDB/MySQL, PostgreSQL, MSSQL, and Firebird.

**Ruby and Node users** - no framework change shipped in 3.12.14. Stay on `3.12.13` or bump to `3.12.14` for version alignment. Both are functionally identical.

## v3.12.13 (2026-05-29)

Consolidated parity release. PHP ran ahead through two independent patch releases (3.12.11-3.12.12) while Python / Ruby / Node stayed at 3.12.10. This release realigns all four frameworks on **3.12.13** and ships the cross-framework dev-admin parity sweep - five tiers of work that bring PHP, Ruby and Node up to Python's AI-assisted development surface.

### Cross-framework dev-admin parity sweep (Tier 1-5)

The Python framework had pulled ahead on a series of dev-admin features driven by real frustration with the AI coder loop ("Applying a small patch went and messed up my whole file", "Says it is creating files but then doesn't", repeated import-error spirals). This release ports the full set to PHP, Ruby, and Node - same intent, language-idiomatic implementations.

**Tier 1 - MCP defensive write layer.** `file_write` and `file_patch` now refuse prose-as-filenames (the LLM occasionally emits `## FILE: I'll implement Step 1 by creating the database migration` and the parser used to write a zero-byte file with that sentence as its filename), normalise bare top-level `routes/` / `orm/` / `templates/` / `seeds/` / `controllers/` / `middleware/` paths to their canonical `src/<dir>/` form (auto-discovery only scans `src/`, so a file at `templates/foo.twig` was dead weight), back up existing files to `.tina4/backups/<flat-path>.<ISO-ts>.bak` before overwrite, and refuse suspicious truncations (>200B file → <30% size = almost always a truncated LLM response). Every attempt logs to `.tina4/agent.log` with a structured category (`write.ok` / `write.refused` / `write.path_normalized` / `write.import_failed`) - the supervisor reads that file on every turn so it sees what broke last time and can self-correct without asking the developer "what's the error?".

**Tier 2 - Post-write syntax verification.** PHP shells out to `php -l`, Ruby to `ruby -c`, Node to `node --check` (and single-file `tsc --noEmit --allowJs --skipLibCheck` for `.ts`). On parse error the tool result gets an `import_error` field AND a `write.import_failed` log entry surfaces in the next supervisor turn's failure context. Catches hallucinated framework APIs (`CharField` doesn't exist in `tina4_python.orm.fields` - should be `StrField`; `auto_now_add` keyword on `Field.__init__()`) at write time instead of letting them propagate to a runtime 500 the user only discovers by hitting the URL.

**Tier 3 - `/__dev/api/threads` + `/__dev/api/chat` proxy.** The SPA now talks to the Rust supervisor agent the same way regardless of framework. `_supervisor_base_url()` matches Python's 4-step ladder (`TINA4_SUPERVISOR_URL` → `TINA4_AGENT_PORT` → `PORT+2000` → `9145`). `active_file` rides through `/chat` POST verbatim so deictic phrases ("fix this", "explain this") bind to the editor's open file without the supervisor asking. The Node port forwards SSE chunks as they arrive; PHP and Ruby buffer (functional - EventSource parses fine - but feels less snappy until a future round of Rack/PHP-FPM streaming work).

**Tier 4 - Customer feedback widget.** A floating bubble for end-users of a shipped Tina4 app, gated by `TINA4_ENABLE_FEEDBACK=true` AND a non-empty `TINA4_FEEDBACK_WHITELIST`. The framework's response middleware injects `<script src="/__feedback/widget.js" data-tina4-feedback></script>` immediately before the LAST `</body>` tag on text/html responses, ONLY for whitelisted users, NEVER on `/__dev` or `/__feedback` paths (no double-bubble UX on the developer dashboard). One conversational turn at a time POSTs to `/__feedback/api/turn` → server-side identity stamp from the verified JWT (clients cannot fake `sender`) → forward to the Rust agent's intake-only agent (zero tools, JSON-only output). Finalised tickets land in the dev admin sidebar with `kind:"feedback"`. Rate-limited at 5 turns/hour per user.

**Tier 5 - Stale-source overlay badge + `list_plans()` merge.** The error overlay now stamps `captured_at` on render and tags each stack frame whose source file has been modified since: "FILE MODIFIED @ HH:MM:SS UTC - source may not match what failed". Stops the user from chasing ghosts when the AI coder rewrote the file between the error and the page reload. `list_plans()` reads from BOTH `plan/` (user-curated canonical) AND `.tina4/plans/` (AI-planner output), dedupes by filename with `plan/` winning on collision, sorts newest-first, and returns a `path` field so the SPA can open the right file regardless of source dir.

**Test counts.** Per-framework deltas across the sweep:

| Framework | Before → After (full suite) |
|---|---|
| Python | 2453 → 2453 (canonical - no new tests, just released) |
| PHP | 2235 → 2714 (+479) |
| Ruby | 2747 → 2800 (+53) |
| Node | 3263 → 3368 (+105) |

PHP's larger delta reflects new tests + the 3.12.11 + 3.12.12 lineage rolling forward.

**Why all four frameworks at once.** Per the cross-framework parity rule: a feature that exists in only one framework is technical debt. The Python-only Tier 1-5 surface had been accumulating for two weeks while the UX was settling. With it settled, this release closes the gap in one coordinated sweep.

### Folded-in from PHP 3.12.11 - file upload regression (`tina4-book#139`)

`WebSocket::parseHttpHeaders()` previously split the entire raw HTTP request on `\r\n` and iterated every line for a `:` to fill the headers map. Multipart body parts have their own `Content-Type`, `Content-Disposition`, and `Content-Transfer-Encoding` headers - those lines matched the parser and overwrote the real request `Content-Type: multipart/form-data; boundary=...` with whatever the last body part's content type was (typically `application/pdf`, `image/png`). Downstream `str_contains($contentType, 'multipart/form-data')` then failed, the multipart branch was skipped, `$parsedFiles` was never set, and `$request->files` came out empty. Every file upload through the stream-socket server was silently lost - the body landed in `$request->body` as a raw multipart string with no way to parse it.

**Fix.** Stop the parser at the first `\r\n\r\n` (RFC 9112 §2.2 boundary between headers and body) before splitting into lines. One logical change in `Tina4/WebSocket.php`. 9 regression tests in `tests/BookIssue139Test.php` cover single-part, multi-part, and mixed-header cases.

**Cross-framework parity check.** Python (`http.server`), Ruby (`webrick`/`puma`), and Node (built-in `http` module) all delegate header parsing to upstream stdlib HTTP parsers that already split headers from body correctly. PHP was the only framework with a hand-rolled HTTP parser in this code path. No port needed.

### Folded-in from PHP 3.12.12 + Python 3.12.13 - v2 `tina4_migration` auto-upgrade (#115)

Projects upgrading from tina4 ^2.x to ^3.x carried a v2-shaped `tina4_migration` table that v3's `ensureMigrationsTable()` left untouched (the `CREATE TABLE IF NOT EXISTS` short-circuited). The v3 reader then selected columns that didn't exist, fell into the "never seen this migration, run it" branch, and re-applied already-applied migrations - typically failing on duplicate-column / table-already-exists errors when the SQL was non-idempotent. The AirOffices ~190-migration codebase tripped on this in March 2026 and needed a manual SQL backfill at the time.

| Framework | v2 schema | v3 schema |
|---|---|---|
| PHP | `migration_id VARCHAR(14)`, `description`, `content BLOB`, `passed` | `id INT PK`, `migration`, `batch`, `applied_at` |
| Python | `description` as identifier, `content`, `passed` | `migration_id`, `migration_name`, `executed_at` |

**Fix.** `ensureMigrationsTable()` (PHP) and `_ensure_tracking_table()` (Python) now detect a v2-shaped table (v2 columns present, v3 columns absent) and call an in-place upgrade that ALTERs in the v3 columns alongside the v2 ones, then backfills v3 fields from the v2 data. v2 columns are kept in place so a manual rollback path stays open - they're simply ignored by v3 readers. The match is by file stem: a v2 row's identifier is matched against `migrations/` files by basename (Python uses `000001_create_users.sql` → stem `000001_create_users` → v2 description `create_users`).

**Cross-framework parity check.** Ruby and Node never shipped a v2 migration table with the trapping shape - their v2 lineages used a different column layout that v3's tracker tolerated. Nothing to port.

### Folded-in from PHP 3.12.11 - request URL parity

`$request->url` now returns the full absolute URL (`https://host:port/path?query`) instead of just the path. `$request->queryString` (raw query bytes) added for parity with `request.query_string` on the other frameworks. Drop-in - old code that read `$request->path` (untouched) keeps working.

### Upgrade

Drop in. No `.env` changes, no API changes.

**For projects upgrading from v2.x:** the v2 `tina4_migration` auto-upgrade runs once on first boot against v3 - back up your migrations table beforehand if you're paranoid. The upgrade is non-destructive (v2 columns are kept alongside the new v3 ones).

**For projects using the dev admin AI coder loop:** the new MCP defensive layer will silently rewrite `## FILE: routes/foo.py` to `src/routes/foo.py` and log a `write.path_normalized` entry. If you were relying on the old behaviour (writes landing wherever the LLM emitted them), this will move some files. Run `tail -n 50 .tina4/agent.log | grep path_normalized` after upgrading to see what got rewritten.

**For shipping apps that want the customer feedback widget:** set `TINA4_ENABLE_FEEDBACK=true` AND `TINA4_FEEDBACK_WHITELIST=alice@example.com,bob@example.com` in `.env`. The widget appears only for those users on non-`/__dev` pages.

## v3.12.10 (2026-05-14)

Version-alignment release. PHP ran ahead through three independent patch releases (3.12.7-3.12.9) while Python / Ruby / Node stayed at 3.12.6. This release realigns all four frameworks on **3.12.10** and ships the ORM `save()` fix.

### PHP - `ORM->save()` no longer swallows write failures (#114)

`ORM->save()` called `update()`/`insert()` but ignored their `bool` return - it only caught exceptions. The PHP adapter's `exec()` returns `false` on a bad statement instead of throwing, so a failed `UPDATE` (commonly: one referencing a public model property with no matching DB column, since `getDbData()` includes every public property) slipped through. The empty transaction got committed and `save()` returned `$this` - the documented success signal. Callers relying on the `save(): static|false` contract believed the row persisted when nothing changed. **Silent data loss** - no exception, no log.

**Fix.** `save()` now captures the `bool` return of `update()`/`insert()`, rolls back, and returns `false` on a falsy result.

```php
$ok = $this->_exists || ... ? $this->update() : $this->insert();
if ($ok === false) { $this->_db->rollback(); return false; }
$this->_db->commit();
```

**Cross-framework parity check.** Python, Ruby and Node don't have this exact failure mode - they build the write payload from declared fields only (not all public properties), and their DB adapters raise on bad SQL, which the existing `try/except` already catches. PHP was the outlier on both counts. 3 regression tests in `tests/Issue114Test.php`; PHP suite 2235 → 2238 passing.

### Also in the PHP 3.12.7-3.12.9 patch line

These shipped to PHP between 3.12.6 and this release; folded into the consolidated 3.12.10 line:

- **3.12.7** - `Request` now normalises caller-provided header keys to lowercase. Some upstream entry points (Apache+PHP-FPM custom mappings, certain proxies, hand-written test fixtures) hand headers in with original case. The constructor only looks them up by lowercase key, so without normalisation `multipart/form-data` content-type detection silently missed and the body fell through as raw bytes - a follow-up to the #135 fix.
- **3.12.8 / 3.12.9** - Router gained RFC 9110 HTTP method conformance: proper `HEAD` and `OPTIONS` handling, `405 Method Not Allowed` with an `Allow` header listing the methods a route does support.

### Python / Ruby / Node

Version-only bump 3.12.6 → 3.12.10 to realign with PHP. No behavioural changes in these three since 3.12.6.

### Upgrade

Drop in. No `.env` changes, no API changes. PHP users on 3.12.9 get the `save()` fix; everyone else gets a version-number realignment.

## v3.12.6 (2026-05-06)

Python-only fix release. PHP / Ruby / Node ship the same version stamp for parity but carry no behavioural changes.

### Python - psycopg2 `%` substitution no longer trips PL/pgSQL function bodies (#40)

A migration containing a PL/pgSQL function with literal `%` characters in a `RAISE EXCEPTION` (or `format()`) call used to fail with the misleading:

> RuntimeError: Migration failed: list index out of range

The error message gave no hint that the `%` chars were the problem. The user-facing failure looked like a tina4 internal bug - actually psycopg2's argument-substitution system tripping on the literal percent signs.

**Root cause.** `PostgreSQLAdapter.execute(sql, params)` always called `cursor.execute(sql, params or [])`. psycopg2 interprets `%` as parameter placeholders WHENEVER the `params` arg is supplied - even an empty list `[]`. So a function body containing `RAISE EXCEPTION 'thing % conflicts with %', a, b` (perfectly valid PL/pgSQL) blew up because psycopg2 thought `%` was a placeholder and there were no values to substitute.

**Fix.** New `PostgreSQLAdapter._safe_execute(cursor, sql, params)` helper routes empty/None params through `cursor.execute(sql)` (no second arg), which makes psycopg2 skip the substitution pass entirely. Literal `%` chars flow through untouched. Applied at every `cursor.execute(...)` call site in the adapter (5 spots across `execute`, `fetch`, `fetch_one`).

**Tests.** 5 new unit tests in `tests/test_postgres_percent_substitution.py` pin the helper's branching. 3 live-Postgres regression tests in `tests/test_postgres_plpgsql_percent.py` exercise a real CREATE FUNCTION + trigger flow with literal `%` in the body - skipped automatically when no Postgres is reachable. Full suite: 2453 passing (was 2448).

**Cross-framework parity check.** PHP (`pg_query` vs `pg_query_params`) and Ruby (`exec` vs `exec_params`) already branch on params presence so they don't have this bug. Node uses `$1` placeholders not `%`, so the same class of bug doesn't apply.

### Long-standing tina4-js #37 confirmed fixed

`frond.form.submit` not following 3xx redirects - fixed in frond v2.1.2 back on April 11, 2026 (`xhr.responseURL` comparison + `window.location.href` navigation). All four framework `public/js/frond.min.js` copies carry the fix. The original issue stayed open because the reporter never confirmed against the patched build.

### Upgrade

Drop in. No `.env` changes, no API changes.

## v3.12.5 (2026-05-06)

PHP-only bug fix release. Python / Ruby / Node ship the same version stamp for parity but carry no behavioural changes.

### PHP - multipart bodies with file uploads now parse correctly (#135)

Two stacked bugs in `Tina4\Request::__construct` made `$request->body` come through as the raw multipart bytes (~11 KB blobs starting with `------WebKitFormBoundary...`) whenever the request included a file upload:

1. The constructor called `$this->parseBody()` BEFORE initialising `$this->files`. Inside parseBody's multipart branch, the line `$this->files = array_merge($this->files, $parsed['files'])` read an uninitialised typed property - fatal `Error`.
2. After fixing the init order, that same line tried to mutate the `readonly` `$files` property - another fatal `Error`.

Both errors got swallowed by the upstream error handler and the route handler received the raw multipart payload instead of the parsed associative array. Routes that worked fine for ordinary form posts broke the moment a file field came along.

**Fix.** Move `$this->files` initialisation AFTER `parseBody()` runs. parseBody stashes extracted multipart files on a new private mutable `$multipartFiles`; the constructor merges them into the readonly `$files` in a single assignment that respects the readonly contract.

4 new regression tests in `tests/Issue135Test.php` pin the constructor's contract. Full PHP suite: 2235 passing (was 2231).

### Upgrade

Drop in. No `.env` changes, no API changes, no other framework changes.

## v3.12.4 (2026-05-06)

Documentation-truth release. The `audit-truth.py` CI gate (introduced post-3.12.3) flagged 39 env vars referenced in docs that no framework actually read. This release closes that gap: 25 of them now exist in code, the other 14 are deleted from docs (11 hallucinations + 6 clustering vars deferred to [tina4#2](https://github.com/tina4stack/tina4/issues/2)). Both audit gates (CLI drift + env-var drift) are now strict in CI.

### 25 new env vars across all 4 frameworks

Server: `TINA4_HOST`, `TINA4_SUPPRESS`, `TINA4_ENV_FILE`. Health: `TINA4_HEALTH_PATH` (default `/__health`, with `/health` kept as a legacy alias), `TINA4_TRAILING_SLASH_REDIRECT`. Sessions: `TINA4_SESSION_HTTPONLY`, `TINA4_SESSION_NAME`, `TINA4_SESSION_SECURE`. Templates: `TINA4_TEMPLATE_CACHE_TTL` (`0` = permanent). GraphQL: `TINA4_GRAPHQL_AUTO_SCHEMA`, `TINA4_GRAPHQL_ENDPOINT`. Mail: `TINA4_MAIL_IMAP_ENCRYPTION` (`tls`/`starttls`/`none`). MCP: `TINA4_MCP`, `TINA4_MCP_PORT`. Swagger: `TINA4_SWAGGER_ENABLED`, `TINA4_SWAGGER_CONTACT_EMAIL`, `TINA4_SWAGGER_LICENSE`. Database: `TINA4_DB_POOL` (env override on the existing `Database(url, pool=N)` constructor argument).

### Logging - env-driven file output + rotation

Six new vars give you full control over logging without touching code:

| Var | Default | What it does |
|---|---|---|
| `TINA4_LOG_FILE` | _(empty - stdout only)_ | Path to a log file. Empty leaves you on stdout. |
| `TINA4_LOG_DIR` | `logs` | Directory for log files (joined with `_LOG_FILE` if relative). |
| `TINA4_LOG_FORMAT` | `text` | `text` or `json`. JSON mode emits one structured record per line. |
| `TINA4_LOG_OUTPUT` | `stdout` | `stdout`, `file`, or `both`. Strict - `stdout` means stdout only. |
| `TINA4_LOG_CRITICAL` | `false` | Enables a `Log.critical()` level above `error`. Off = no-op. |
| `TINA4_LOG_ROTATE_SIZE` | `10485760` (10 MB) | Rotate when the file exceeds this many bytes. `0` disables rotation. |
| `TINA4_LOG_ROTATE_KEEP` | `5` | Number of rotated files to retain (`app.log.1` ... `app.log.N`). Older ones are deleted. |

Implementation uses each language's stdlib - Python's `logging.handlers.RotatingFileHandler`, Ruby's `Logger.new(path, shift_age, shift_size)`, and a roll-your-own atomic-rename pattern in PHP and Node. Zero new dependencies in any framework.

### Documentation-truth CI gate now strict on both axes

The `audit-truth.py` script now blocks merges to `main` of `tina4-documentation` whenever a doc references a `tina4 <command>` or `TINA4_*` env var that doesn't exist in source. Previously CLI drift was strict; env drift was warn-only. Today both are strict.

### Tests added

- Python: +53 tests in `tests/test_env_vars.py` (2395 → 2448)
- PHP: +59 tests in `tests/EnvVarTest.php` (2172 → 2231)
- Ruby: +51 examples in `spec/env_vars_spec.rb` (2696 → 2747)
- Node: +59 tests in `test/envVars.test.ts` (3204 → 3263)

**Cross-framework total: 10,689 tests passing, +222 from 3.12.3.**

### Upgrade path

Drop in. No breaking changes - every new env var is opt-in with a sensible default. If you were setting any of the 17 deleted vars in your `.env`, the boot guard will warn (then ignore) - clean them out at your leisure.

## v3.12.3 (2026-05-05)

Cross-framework parity sweep. Two minor breaking changes in the Ruby and PHP public API that bring all four frameworks onto the same shape.

### Breaking changes (Ruby + PHP only)

**Ruby Container - predicate now uses `?` suffix.**

```ruby
# before (3.12.2 and earlier)
Tina4::Container.has(:mailer)        # outdated

# after (3.12.3)
Tina4::Container.has?(:mailer)       # idiomatic Ruby predicate
```

This brings Ruby in line with Python (`has()`), PHP (`has()`), and Node (`has()`) while still respecting Ruby's `?`-suffix idiom for predicates returning bool. The pre-existing `resolve` → `get` rename happened earlier; only the predicate was lagging.

**ResponseCache public surface - middleware-only across all four frameworks.**

The cache has always been middleware. Two of the four frameworks (PHP, Ruby) historically exposed lookup/store as public methods, which let users couple to internals. The public API is now consistent across all four: use the middleware on a route, and read stats with module-level helpers.

```ruby
# Ruby - module-level helpers (parity with Python)
Tina4.cache_stats   # → { hits:, misses:, size:, backend:, keys: }
Tina4.clear_cache   # flush all entries

# PHP - static methods on the class
\Tina4\Middleware\ResponseCache::cacheStats();
\Tina4\Middleware\ResponseCache::clearCache();
```

Internal methods that used to be public (`get`, `lookup`, `store`, `cache_response`) are now private. Tests that needed them retain access via `_internal*` test seams marked `@internal`.

### Doc parity - CLAUDE.md and book chapter 33

- **CLAUDE.md**: every framework's "Key Method Stubs" section now covers the same surface area Python documents - Queue, QueryBuilder, Frond, Api, Background Tasks, ResponseCache, etc. PHP added 4 sections; Ruby added 5; Node added 13.
- **Book chapter 33**: env var tables are now grounded in source. Each framework's chapter 33 lists every `TINA4_*` var its source actually reads. Found and fixed several gaps - Ruby was missing `TINA4_CACHE_*`, `TINA4_QUEUE_*`, `TINA4_KAFKA_*`, `TINA4_RABBITMQ_*`, `TINA4_MONGO_*`, `TINA4_WS_BACKPLANE`, and the entire `TINA4_SESSION_VALKEY_*` block.

### Other fixes

- **Ruby `lib/tina4/ai.rb`** - subprocess output is now force-encoded to UTF-8 before `String#strip`, fixing `Encoding::CompatibilityError` that crashed 4 ai specs on systems with non-ASCII pip output.
- **Node `test/serverParity.test.ts`** - sets `TINA4_OVERRIDE_CLIENT=true` so `start()` actually runs, plus emits the `N passed, M failed` summary line the runner expects. The test was effectively a no-op before; now it's recorded properly.

### Genuine gaps surfaced by the parity audit (follow-up, not blocking 3.12.3)

The chapter 33 audit flagged env vars Python documents that no other framework actually reads - Ruby/PHP/Node lack `TINA4_OPEN_BROWSER`, `TINA4_DEV_POLL_INTERVAL`, `TINA4_PUBLIC_DIR`, `TINA4_TOKEN_EXPIRES_IN` alias, plus a few framework-specific gaps (Ruby has no Mongo session backend; Node `TINA4_CSRF` defaults to `false` vs Python's `true`). Tracked for a future patch.

### Upgrade path

| Symptom | Fix |
|---|---|
| Ruby: `NoMethodError: undefined method 'has' for Tina4::Container` | Replace `has(:key)` with `has?(:key)` |
| PHP: `BadMethodCallException` calling `$cache->lookup(...)` | Use the middleware: `[ResponseCache::class, 'beforeCache']` / `[..., 'afterCache']`. Or call `_internalLookup` if you really need direct access (test code only - `@internal`). |
| Ruby: `NoMethodError: undefined method 'get' for ResponseCache instance` | Use `Tina4.cache_stats` / `Tina4.clear_cache` for stats. Lookup goes through the middleware. |

No `.env` changes from 3.12.2.

## v3.12.2 (2026-05-05)

Quality-of-life patch. Two related portability fixes - no breaking changes from 3.12.1.

### Firebird URL auto-detect

Firebird is the awkward one in the stack. Every other engine has a server-side database name (`postgres://host:port/dbname`), but Firebird wants either an absolute file path on the server, a Windows drive-letter path, or an alias. The classic URI form needs a double slash to keep the leading `/` of an absolute path through the URL parser - unintuitive to anyone used to the way postgres / mysql / mssql encode the database name.

The framework now accepts five equivalent forms and normalises all of them transparently:

| URL path you write | Resolved Firebird identifier |
|---|---|
| `//abs/path/db.fdb`   (classic double-slash) | `/abs/path/db.fdb` |
| `/abs/path/db.fdb`    (single-slash, intuitive) | `/abs/path/db.fdb` |
| `/C:/Data/db.fdb`     (Windows drive letter) | `C:/Data/db.fdb` |
| `/C%3A/Data/db.fdb`   (URL-encoded colon) | `C:/Data/db.fdb` |
| `/employee`           (Firebird alias) | `employee` |

For ops setups that keep server URL and DB location in separate config layers - or for Windows backslash paths that fight URL encoding - set `TINA4_DATABASE_FIREBIRD_PATH`. The env override wins over whatever path is in the URL.

```bash
TINA4_DATABASE_FIREBIRD_PATH=C:\firebird\data\app.fdb
TINA4_DATABASE_URL=firebird://SYSDBA:masterkey@localhost:3050/ignored
```

Shipped to all 4 frameworks. 11 regression tests per framework (8 unit + 3 live).

### Bug fix specific to PHP - `mysqli` localhost+port quirk

PHP's `mysqli` has a long-standing quirk where `host == "localhost"` triggers a Unix socket lookup and IGNORES the port argument entirely. Connecting to `mysql://...:53306` against a Docker container fails with "No such file or directory" - `mysqli` is hunting for `/tmp/mysql.sock` instead of opening a TCP connection. `MySQLAdapter::rewriteHostForTcp()` now rewrites `localhost` to `127.0.0.1` when a non-zero port is specified, forcing the TCP code path. Bare `mysql:///db` (no port) is preserved so existing socket-based setups keep working.

### Other fixes

- **chore(python):** `pyproject.toml` had drifted to `3.10.41` while `__init__.py` read `3.12.1`. Synced both to 3.12.2 so `uv build` and runtime introspection now agree.
- **chore(claude.md, all 4):** stale framework version banners in `CLAUDE.md` headers updated.

No `.env` changes from 3.12.1, no migration needed. Existing 3.12.1 installs upgrade by changing one version number.

## v3.12.1 (2026-05-04)

CI-only patch - no framework code changes from 3.12.0.

- **fix(ci, all 4):** every `publish.yml` workflow now declares `permissions: contents: write` on the publish job. Without this, `softprops/action-gh-release` 403'd against the default `GITHUB_TOKEN` on repos whose default Workflow permissions setting was read-only (Ruby and Node hit this every release; PHP and Python worked by luck of repo settings). The explicit declaration makes the workflow self-sufficient.
- **chore(ci):** bumped `softprops/action-gh-release` from `@v1` (unmaintained) to `@v2`.

No `.env` changes, no API changes, no migration needed. Existing 3.12.0 installs can upgrade without touching anything else.

The version-bump itself is the test: a successful 3.12.1 release proves the workflow fix works on Ruby and Node where 3.12.0 needed manual `gh release create`.

## v3.12.0 (2026-05-04)

> **⚠️ Breaking change - read before upgrading.** Every framework env var now uses the `TINA4_` prefix. Existing `.env` files set with `DATABASE_URL`, `SECRET`, `SMTP_HOST`, `HOST_NAME`, etc. will cause the framework to refuse to boot. Run `tina4 env --migrate` to rewrite, or follow the rename table below.

### Why this release

Tina4's env vars had grown inconsistent. Some had the `TINA4_` prefix (`TINA4_DEBUG`, `TINA4_LOCALE`, `TINA4_CACHE_BACKEND`), others didn't (`DATABASE_URL`, `SECRET`, `SMTP_HOST`). Newcomers had to guess which convention applied to which feature. Existing tools and PaaS dashboards collided with un-prefixed names like `SECRET` and `API_KEY` that other libraries also read. Documentation drifted - 91 env-var names appeared in the docs that didn't exist in any framework, and 22 framework-specific env vars in the code didn't match the names users were told to set.

This release closes all three gaps with a single hard rename. No deprecation period, no fallback chain. The framework refuses to boot if it detects a legacy name in the environment, prints a list of every var to rename, and tells you which command to run.

### What changed

- **22 env vars renamed** to `TINA4_*` form. See the migration table below.
- **`tina4 env --migrate` CLI** added to all four frameworks. Reads your `.env`, rewrites it in place, leaves a `.env.bak` backup, prints a diff. Idempotent.
- **Boot-time guard** scans `os.environ` (or the language equivalent) for the 22 legacy names. If any are present, prints the rename map and exits with code 2. Bypass with `TINA4_ALLOW_LEGACY_ENV=true` for migration scripts that need both names set during transition.
- **All 4 framework books rewritten.** Chapter 33 (Environment Variables) is now a clean canonical list - every var prefixed, descriptions current, legacy names removed.
- **Doc-vs-code drift closed.** Of the 91 stale env vars previously documented, 61 were renames (corrected), 32 were never implemented (removed). The `audit-links.py` CI gate stays at 0 broken links / 0 broken anchors.
- **Frond bundle** rebuilt at v2.1.3 - `frond.min.js` footer now shows the version explicitly so users can verify what they have.

### Bug fixes shipped alongside the rename

- **#38 PostgreSQL UUID-PK transaction abort** - the post-INSERT `lastval()` probe is now wrapped in a SAVEPOINT, so UUID-PK INSERTs no longer poison the outer transaction with `InFailedSqlTransaction`. Live regression test against PostgreSQL 16. (Affects all 4 frameworks where the PG adapter does this probe.)
- **#39 Landing page + template auto-routing** -
  - Auto-routing now scans `src/templates/pages/` only. Partials, layouts, base.twig, errors/, components/, and `_*` files never auto-serve from a URL.
  - `TINA4_TEMPLATE_ROUTING=off` kills the feature entirely.
  - `src/public/index.html` auto-serves at `/` (and `/foo/` serves `src/public/foo/index.html`) - SPA hosting Just Works.
  - The framework landing page only renders when `TINA4_DEBUG=true`. Production never shows it; framework version, dev-admin link, and gallery don't leak to real users.
  - The malformed `HTTP/1.1 404 OK` status line is fixed - every status code now uses its canonical RFC 7231/9110 reason phrase.
- **#37 frond.form.submit redirect handling** - verified shipped at v2.1.x; `xhr.responseURL` change triggers `window.location` navigation correctly.
- **#36 Session file handler** - re-verified safeguards (lazy save, WebSocket skip, probabilistic GC, new-and-empty skip) all still in place.

### Migration - every renamed var

| Legacy name | New name |
|---|---|
| `DATABASE_URL` | `TINA4_DATABASE_URL` |
| `DATABASE_USERNAME` | `TINA4_DATABASE_USERNAME` |
| `DATABASE_PASSWORD` | `TINA4_DATABASE_PASSWORD` |
| `DB_URL` | `TINA4_DATABASE_URL` (alias dropped) |
| `SECRET` | `TINA4_SECRET` |
| `API_KEY` | `TINA4_API_KEY` |
| `JWT_ALGORITHM` | `TINA4_JWT_ALGORITHM` |
| `SMTP_HOST` | `TINA4_MAIL_HOST` |
| `SMTP_PORT` | `TINA4_MAIL_PORT` |
| `SMTP_USERNAME` | `TINA4_MAIL_USERNAME` |
| `SMTP_PASSWORD` | `TINA4_MAIL_PASSWORD` |
| `SMTP_FROM` | `TINA4_MAIL_FROM` |
| `SMTP_FROM_NAME` | `TINA4_MAIL_FROM_NAME` |
| `IMAP_HOST` | `TINA4_MAIL_IMAP_HOST` |
| `IMAP_PORT` | `TINA4_MAIL_IMAP_PORT` |
| `IMAP_USER` | `TINA4_MAIL_IMAP_USERNAME` |
| `IMAP_PASS` | `TINA4_MAIL_IMAP_PASSWORD` |
| `HOST_NAME` | `TINA4_HOST_NAME` |
| `SWAGGER_TITLE` | `TINA4_SWAGGER_TITLE` |
| `SWAGGER_DESCRIPTION` | `TINA4_SWAGGER_DESCRIPTION` |
| `SWAGGER_VERSION` | `TINA4_SWAGGER_VERSION` |
| `ORM_PLURAL_TABLE_NAMES` | `TINA4_ORM_PLURAL_TABLE_NAMES` |

### Names that stay un-prefixed (not framework config)

`PORT`, `HOST`, `NODE_ENV`, `RACK_ENV`, `RUBY_ENV`, `ENVIRONMENT` - these are runtime / PaaS conventions, not framework config. Heroku, Railway, Vercel, and friends set them; we keep reading them.

### How to upgrade

1. **Backup your `.env`:** `cp .env .env.bak.pre-v3.12`
2. **Run the migration:** `tina4 env --migrate` - rewrites your `.env` in place.
3. **Update PaaS dashboards:** Heroku, Railway, Vercel, Render, Fly.io etc - rename the same vars in your provider's env-var UI.
4. **Restart your app.** The boot guard verifies nothing legacy remains.

If your app uses `SECRET`, `DATABASE_URL`, or any other listed name in places besides `.env` (e.g. your CI pipeline's `env:` blocks), update those too - the boot guard checks `os.environ`, not just `.env`.

### Parity

All 4 frameworks aligned at **3.12.0**:
- tina4-python 3.11.32 → 3.12.0
- tina4-php 3.11.32 → 3.12.0
- tina4-ruby 3.11.32 → 3.12.0
- tina4-nodejs 3.11.32 → 3.12.0

Coordinated release across PyPI, Packagist, RubyGems, npm.

## v3.11.32 (2026-04-25)

**Critical fix - pool + transactions are now actually atomic.** Plus a coordinated parity release that aligns all four frameworks at the same version after months of drift.

Before this release, creating a `Database` with `pool > 0` silently broke transactions. The pool's round-robin checkout rotated to a different adapter on every call - so `start_transaction()` pinned its flag on adapter A, the executes autocommitted on adapters B and C, and the final `commit()` / `rollback()` landed on adapter D, which had nothing to commit. Result: `rollback()` was a no-op, writes leaked through, and no error or log surfaced the problem.

The fix pins one adapter to the calling context for the lifetime of a transaction. Each language uses its own primitive:

- **Python** - `threading.local()` on the `Database` instance
- **Ruby** - `Thread.current[:tina4_pinned_adapter_<obj_id>]`
- **Node.js** - `AsyncLocalStorage` from `node:async_hooks` (async-safe across overlapping awaits)
- **PHP** - per-instance property (PHP-FPM is one process per request; threading.local is unnecessary)

While pinned, every database call routes to the same adapter. `commit()` and `rollback()` release the pin so subsequent calls round-robin again.

- **fix (database / all 4):** adapter pinning across transaction scope in `Database._get_adapter()` (and language equivalents). Every backend is affected - SQLite, PostgreSQL, MySQL, MSSQL, Firebird. Firebird exposed it loudest because of its honest "commit-empty-txn is a real no-op" semantics; the others mostly hid the bug behind eager autocommits but still lost rollback atomicity.
- **tests (all 4):** new regression suite - three INSERTs followed by `rollback()` under `pool=4` now leaves zero rows (was leaking three). Three INSERTs followed by `commit()` persists exactly three. Pin-release after commit/rollback verified. `pool=0` regression test added so single-connection mode stays unaffected.
- **parity / version alignment:** all 4 frameworks bumped to 3.11.32 - closes the cross-framework version drift that had built up (PHP at 3.11.31, Python at 3.11.24, Ruby and Node at 3.11.19). A single coordinated release across all four registries: PyPI, Packagist, RubyGems, npm.

**No migration needed.** Code using `pool=0` (the default for every adapter except where explicitly raised) is unaffected. Code using `pool>0` will now actually honour transactions instead of silently dropping them.

**If you've been seeing intermittent "writes vanished" or "rollback didn't help" reports on a pooled `Database`, this release is the cause and the cure.**


## v3.11.13 (2026-04-16)

Issue-driven release. Everything reported in the open tina4-book issues either was fixed in this version or is already fixed in 3.11.12; this release consolidates the remaining bits and corrects documentation drift.

- **feat (router / all 4):** Explicit typed-parameter system shared across Python, PHP, Ruby, Node. Adds `alpha`, `alnum`, `slug`, `uuid`, and explicit `string` types in addition to the existing `int`/`integer`, `float`/`number`, `path`/`.*`. **Unknown type names now throw at registration** - `{name:str}`, `{id:inetger}`, etc. raise with a clear message listing the valid types instead of silently falling through to the default matcher. Fixes tina4-book#125. +45 new tests across the four suites.
- **fix (gallery / python+php+ruby):** Gallery Try-It / View buttons now open the deployed example in a new tab (`window.open(url, '_blank')`) instead of navigating away from the gallery home. Fixes tina4-book#115.
- **fix (ruby gemspec):** `sqlite3` promoted from `add_development_dependency` to `add_dependency`. Matches the "zero-config SQLite on first run" promise. Fixes tina4-book#100.
- **docs (tina4-book):** PHP Chapter 2 updated - correct port (7145), `->noAuth()` on write-method examples, and an explicit callout explaining the secure-by-default policy for POST/PUT/PATCH/DELETE. Addresses tina4-book#87, #94, #123.
- **docs (tina4-book):** Python `@template` decorator ordering corrected (must sit BELOW the route decorator) in book chapters 04 and 10; Python `request->query` vs `request->params` distinction in PHP chapter 1.
- **tests (python):** Session-handler tests updated to reflect the real default TTL of 3600s (were stale at 1800s).
- **verified already fixed in earlier 3.11.x releases** - closed comments posted on all of these:
<div v-pre>

  - #79 dotted numeric index (`{{ items.0.name }}`)
  - #80 `truncate` filter
  - #82 `{{ parent() }}` / `{{ super() }}` across all 4 frameworks
  - #83 Ruby dashboard - WEBrick is runtime dep
  - #89 `load_dotenv` rename, `DatabaseResult` methods, SQLite WAL locking
  - #91 Ruby `request.params` symbol + string keys via `IndifferentHash`
  - #93 Ruby `/docs/*` and bare `/*` wildcard routes
  - #97 Frond ternary operator
- **parity:** All 4 frameworks bumped to 3.11.13.

</div>


## v3.11.12 (2026-04-16)

**Breaking:** `sqlite:///X` URLs are now relative to the project root (cwd), matching the documented convention. For absolute paths use four slashes (`sqlite:////abs/path.db`) or a Windows drive letter (`sqlite:///C:/Users/app.db`).

Before this release, `TINA4_DATABASE_URL=sqlite:///data/app.db` was interpreted differently by every framework. Python/Node/Ruby tried to open `/data/app.db` (absolute) which crashed on macOS with `OSError: [Errno 30] Read-only file system: '/data'`. PHP did the same under the hood. All four frameworks now agree: three slashes = relative, four slashes = absolute.

- **fix (all 4):** `sqlite:///X` resolves under cwd; parent directory auto-created only when inside cwd. Absolute paths are trusted and never mkdir'd at root.
- **fix (python):** `_ensure_folders` no longer creates a bogus `src/migrations/` directory. The migration runner always looks at `migrations/` at the project root - there is only one correct location.
- **parity (php, ruby, node):** Same `sqlite:///X` parsing as Python. Dedicated `resolve_path` / `resolveSqlitePath` helpers in each framework so adapters consistently handle `:memory:`, `./` forms, Windows drive letters.
- **tests:** 9 new Python tests in `TestSQLiteConnectionPath` + `TestProjectFolders`. 4 new PHP tests in `DatabaseUrlTest` covering relative/absolute/Windows/bruce-regression. 6 new Ruby specs in `database_drivers_spec.rb :: SqliteDriver.resolve_path`. Node URL tests expanded in `database.test.ts` with the full relative/absolute/Windows/:memory: matrix.
- **parity:** All 4 frameworks bumped to 3.11.12.

**Migration note:** If your `.env` has `TINA4_DATABASE_URL=sqlite:///data/app.db`, it will now create `./data/app.db` in the project root (which is what most users actually want). If you genuinely want an absolute path, change to `sqlite:////data/app.db` (four slashes).


## v3.11.11 (2026-04-16)

- **fix (python ORM):** `Field.validate` no longer re-coerces values that are already the correct type. Previously, any PostgreSQL/MSSQL read of a row containing a `DateTimeField` crashed because `datetime(datetime_instance)` raises `TypeError`. The fix accepts native driver types (`datetime`, `bytes`, `int`, `bool`, `float`, `str`) without re-wrapping, and parses ISO-8601 strings into `datetime` for SQLite. See `tina4-python/plan/orm-field-validate-native-types.md`.
- **fix (python ORM):** `BooleanField` vs `IntegerField` ordering handled explicitly. `BooleanField(1)` still coerces to `True`, `IntegerField(True)` still coerces to `1`; no regression for either direction (bool is a subclass of int in Python).
- **tests (python):** 10 new `TestFieldsNativeTypes` cases covering datetime/int/bool/float/bytes/string/ForeignKey round-trips.
- **tests (parity):** Regression-guard "datetime round-trip on read path" tests added to PHP (`ORMV3Test`), Ruby (`orm_spec`) and Node.js (`orm.test.ts`) so an equivalent bug can't creep in there later.
- **parity:** All 4 frameworks bumped to 3.11.11.


## v3.11.10 (2026-04-15)

- **fix (php):** Hot-reload loop - DevAdmin's polling fallback used `mt=0` as the baseline, so the first poll after every page load triggered `location.reload()`, which reset `mt=0` again. Loop now initialises the baseline on the first poll.
- **fix (php):** Reload sentinel removed - PHP was the only framework recursively walking `src/` and touching `src/.reload_sentinel` on every reload POST. The sentinel lived inside the Rust CLI's watched tree and fed back into the watcher, triggering a second loop. Replaced with the same in-memory counter used by Python/Ruby/Node.
- **fix (php):** Polling no longer starts more than once when the WebSocket reconnect retry budget is exhausted (added a `pollStarted` guard).
- **feat (parity):** `GET /__dev/api/queue/topics` and `GET /__dev/api/queue/dead-letters` added to PHP, Ruby and Node (previously only in Python). PHP queue endpoints now read from the real `Tina4\Queue` backend instead of returning stubs.
- **feat (devadmin):** Refreshed `tina4-dev-admin.js` bundle (87.8 KB) across all 4 frameworks - adds the topic selector dropdown, inline payload expand/copy, and corrected version display.
- **tests:** 4-way parity tests for hot-reload: mtime starts at 0, POST /__dev/api/reload bumps the counter, no sentinel file is written to disk, mtime is monotonic across successive reloads. Mirrored in `tina4-php/tests/DevAdminTest.php`, `tina4-python/tests/test_dev_admin.py`, `tina4-ruby/spec/dev_admin_spec.rb`, `tina4-nodejs/test/devAdmin.test.ts`.
- **parity:** All 4 frameworks bumped to 3.11.10.


## v3.11.9 (2026-04-15)

Catch-up release covering v3.11.0 → v3.11.9 across all 4 frameworks.

- **feat (websocket):** Full WebSocket parity across Python/PHP/Node/Ruby - `get_client_rooms()` / `getClientRooms()`, `route()` usable as decorator or direct handler registration, matching room/broadcast semantics, plus new parity tests on all 4.
- **feat (graphql):** Input validation and field-level `@auth` directives with context threading.
- **feat (graphql):** Auto-discovery of schemas; removed legacy DevAdmin HTML/JS in favour of the new UI.
- **feat (devadmin - Python):** Queue tab with topic selector, dead-letter listing and replay endpoints, inline payload expand/copy, version display.
- **feat (cli):** Rust CLI now owns file watching - frameworks receive `POST /__dev/api/reload` and internal watchers are disabled when launched by the Rust CLI (`--managed`).
- **fix (cli):** `parseFlags` / `parse_flags` / `parseCliArgs` no longer swallow `host:port` or positional args after boolean flags.
- **fix (scss):** SCSS recompilation loop fixed; output path corrected to `src/public/css/` to match CLI and static serving.
- **fix (frond - Python):** Numeric dotted index for lists (`items.0.name`) now resolves correctly.
- **fix (router - Ruby):** Bare `/*` wildcard capture exposed under `"*"` key for parity.
- **fix (orm - PHP):** Three data-sync bugs fixed: `load()` double-fill, `getPrimaryKeyValue`, `save()` ID sync.
- **fix (graphql):** `from_orm` / `fromOrm` list resolver used `select(skip=)` instead of `all(offset=)`.
- **fix (metrics):** Windows backslash paths normalised to forward slashes.
- **fix (app - PHP):** No longer crashes on notices/deprecations in loaded files; `run()` now prints the banner when starting the server directly.
- **chore:** Example demo store ships with the repo; Windows-friendly setup; `.env.example` and setup scripts added.
- **parity:** All 4 frameworks bumped to 3.11.9. PHP aligned to the 3.x tag scheme on `v3`.

## v3.10.99 (2026-04-12)

- **breaking:** `autoMap` now defaults to `true` - ORM models automatically map between camelCase properties and snake_case DB columns. Set `static autoMap = false;` on your model to restore the old behaviour.
- **feat:** `toDict(include, case)` parameter - pass `'snake'` as second arg to get snake_case keys matching DB columns, or `'camel'` (default) for camelCase.
<div v-pre>

- **feat:** Frond `replace` filter now accepts object args - `{{ v|replace({"T": " ", "-": "/"}) }}` for multiple substitutions in one call.
- **tests:** 13 new parity tests covering `toDict(case)`, `autoMap` default, `replace` filter (object + positional), and `ServiceRunner` registration. 268 tests passing.
- **parity:** All features shipped identically across Python, PHP, Ruby, Node.js.

</div>

## v3.10.97 (2026-04-11)

- **fix:** frond.form.submit redirect handling - XHR follows 3xx redirects transparently; fixed by detecting `xhr.responseURL` mismatch and navigating instead.
- **dep:** Updated frond.min.js to v2.1.2.
- **parity:** All 4 frameworks bumped to 3.10.97.

## v3.10.93 (2026-04-11)

- **fix:** Frond bracket depth tracking in `findOutsideQuotes()` and `splitOutsideQuotes()` - expressions like `arr[i % 2]` no longer treated as top-level arithmetic.
- **fix:** Frond subscript expression evaluation - bracket content uses `evalExpr()` instead of direct context lookup, enabling `arr[loop.index0 % 2]`.
- **fix:** Frond slice with variable bounds - `items[start:end]` evaluates bounds through `evalExpr()`.
- **docs:** Developer skills updated - Metrics Dashboard guidance, Frond Template Parity rules, `@noauth` security warnings.
- **parity:** All Frond fixes applied identically across Python, PHP, Ruby, Node.js. 2,831 tests passing (268 Frond).

## v3.10.92 (2026-04-10)

- **feat:** Add `DevAdmin` methods - `capture()` (5-param), `clearAll()`, `health()`, `unresolvedCount()`, `reset()`, `register()`.
- **feat:** Add `Server.start()` and `Server.stop()` for cross-framework parity.
- **feat:** Add `DatabaseResult.size()` method.
- **feat:** Add `DevReload.start()` and `DevReload.stop()`.
- **feat:** Add `ScssCompiler.compileScss()` method.
- **fix:** `autoCrud.ts` - fix spread syntax on non-iterable, add id in POST response, correct response format to `{data, meta}`, change validation status from 400 to 422.
- **parity:** 44/44 cross-framework features green. 2,752 tests passing.

## v3.10.91 (2026-04-10)

- **feat:** Add parity methods - `GraphQLType.parse()`, `CorsMiddleware.isPreflight()`, `RateLimiterMiddleware.check()`.
- **breaking:** Rename `from()` → `fromTable()`, remove `template()` alias - align with Python canonical names.

## v3.10.90 (2026-04-09)

<div v-pre>

- **docs:** Chapter 4 (Templates) - new "Dumping Values for Debugging" section covering both `{{ x|dump }}` and `{{ dump(x) }}` forms, the v3.10.88 `inspectValue()` inspector (circular refs, BigInt, Map/Set, Error, Date, class instances), and the `TINA4_DEBUG=true` production gate. Filter table entry updated to reference the new section.
- **docs:** `plan/parity/parity-template.md` updated with a cross-framework dump helper comparison table and marks dump parity as confirmed across all 4 frameworks at v3.10.89.
- **chore:** Version sync release - brings all 4 frameworks to the same patch version (3.10.90) so downstream users can upgrade PHP/Python/Ruby/Node.js in lockstep without hunting version mismatches.

</div>

## v3.10.89 (2026-04-09)

<div v-pre>

- **feat:** `{{ dump(value) }}` global function form added to Frond alongside the existing `{{ value|dump }}` filter. Both call a single `renderDump()` helper (which delegates to the v3.10.88 `inspectValue()` inspector) and produce identical output.
- **security:** Dump is now **gated on `TINA4_DEBUG=true`**. In production (env var unset or `false`) both the filter and function silently return an empty `SafeString`. This prevents accidental leaks of internal state, object shapes, and sensitive values into rendered HTML when a developer leaves a `{{ dump(x) }}` call in a template.
- **test:** 4 new tests in `frond.test.ts` covering `dump()`/`|dump` parity, debug-mode circular ref handling, production silencing for both forms.

</div>

## v3.10.88 (2026-04-09)

<div v-pre>

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

</div>

## v3.10.87 (2026-04-09)

- **fix:** Dev toolbar no longer vanishes after a hot-reload. The CLI watcher used to call `server.router.clear()` on every file change - including template/CSS/JS asset edits - which left a brief window of 404 responses that bypass the dev toolbar injection. The watcher now reports whether a `.ts/.tsx/.js/.jsx` source file changed; router re-discovery only runs on code changes, and asset edits pass through without touching the router. Matches the PHP v3.10.87 fix.

## v3.10.86 (2026-04-09)

- **feat:** `foreignKey` field type on `BaseModel` auto-wires both sides of a foreign key relationship. Declaring `user_id: { type: "foreignKey", references: "User" }` injects a `belongsTo` entry on the declaring model and a `hasMany` entry on the referenced model via a module-level FK registry. New static methods `_processForeignKeys()` and `_applyFkRegistry()` are called lazily before relationship resolution. Optional `relatedName` overrides the has-many key.
- **feat:** Cross-framework parity - same FK auto-wiring semantics now available in Python (`ForeignKeyField`), PHP (`$foreignKeys`), and Ruby (`foreign_key_field`)
- **docs:** Chapter 6 (ORM) updated with a new "foreignKey Field Type - Auto-Wired Relationships" section

## v3.10.85 (2026-04-09)

- Version bump for parity with Python and PHP releases

## v3.10.84 (2026-04-09)

- **fix:** Router/middleware was setting `request.user` / `request.auth` / auth payload to `true` (boolean) instead of the actual JWT payload after `validToken()` was changed to return bool - any code reading `request.user.sub` etc. would have failed silently or crashed
- **fix:** CSRF middleware was not correctly rejecting invalid tokens (null check on bool result always passed)
- **add:** Headless routing auth payload integration tests to prevent regression

## v3.10.83 (2026-04-08)

- **feat:** WebSocket rooms - `joinRoom`, `leaveRoom`, `broadcastToRoom`, `getRoomConnections`, `roomCount`, `getClientRooms`
- **feat:** Queue signature parity - instance-scoped `push`/`pop`/`retry`, no topic params on public methods
- **feat:** Auth alias cleanup - removed `createToken`/`validateToken`, canonical `getToken`/`validToken`

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


Tina4 Node.js follows semantic versioning. The major version (3) marks the initial Node.js launch - Tina4 Node.js is new in the v3 line, alongside Tina4 Ruby. The minor version tracks feature additions. The patch version tracks fixes, template engine corrections, and cross-framework parity updates.

This chapter covers every release from v3.0.0 through v3.10.x. Each section groups releases by minor version, lists features added, bugs fixed, and breaking changes with migration code where relevant.

---

## v3.10.68 (2026-04-03) - Full Parity Release
- **100% API parity** across Python, PHP, Ruby, Node.js - 30+ issues fixed
- **ORM:** save() returns self/false, arrays not tuples, toDict/toAssoc, scope registers method, where()/all() on Node, count() on PHP
- **Auth:** expires_in minutes, PBKDF2 260k, env TINA4_SECRET fallback, API key fallback
- **Session:** dual-mode flash(), get_flash, cookieHeader, getSessionId
- **Database:** execute() bool/DatabaseResult, get_last_id/get_error, getColumns, cacheStats
- **Request/Response:** files dict, query, cookies, contentType, xml(), callable
- **Queue:** consume() poll_interval
- **WebSocket:** event naming, connection properties
- **GraphQL:** schema_sdl() + introspect() on all 4
- **Events:** emitAsync() on all 4
- **i18n:** zero-dep YAML support

## v3.10.67 (2026-04-03)
- **load() returns boolean** - `model.load(sql, params)` calls selectOne internally, populates the instance, returns `true`/`false`. Use `findById()` for PK lookups
- **api.upload()** added to tina4-js - sends FormData with Bearer token auth for multipart file uploads
- **ORM CLAUDE.md rewrite** - all method stubs now match actual API signatures
- **File upload docs** - `req.files` format documented in CLAUDE.md

## v3.10.66 (2026-04-03)
- **Metrics file detail fix** - clicking bubbles in framework scanning mode now resolves paths correctly via scan root tracking

## v3.10.65 (2026-04-03)
- **Metrics 3-stage test detection** - filename, path, and content matching
- **Metrics framework mode** - scans framework source with correct relative paths
- **tina4 console** - interactive REPL with framework loaded
- **tina4 env** - interactive environment configuration
- **Brand** - "TINA4 - The Intelligent Native Application 4ramework"
- **Quick references** - 36 sections, DotEnv API documented
- **37 chapters** - 7 new (Events, Localization, Logging, API Client, WSDL/SOAP, DI Container, Service Runner)
- **MongoDB + ODBC adapters** across all 4 frameworks
- **Pagination standardized** - limit/offset primary, merged dual-key response
- **Port kill-and-take-over** on startup

---

## v3.10.60 (2026-04-03)
- **tina4 console** - interactive Node REPL with framework loaded (db, Router, Database, Log)
- **tina4 env** - interactive environment configuration
- **Brand update** - "TINA4 - The Intelligent Native Application 4ramework"
- **Dynamic version** - reads from package.json at runtime
- **Port kill-and-take-over** - default port always reclaimed
- **findAvailablePort** - checks 0.0.0.0 not 127.0.0.1
- **MongoDB adapter** (mongodb npm), **ODBC adapter** (odbc npm)
- **Pagination standardized** - limit/offset primary, merged dual-key response
- **Metrics dependency lines** - basename fix for correct rendering
- **autoMap uppercase** - snakeToCamel lowercases first

---

## v3.10.57 (2026-04-02)
- **MongoDB adapter** - `initDatabase({ url: "mongodb://host:port/db" })`, requires `npm install mongodb`
- **ODBC adapter** - `initDatabase({ url: "odbc:///DSN=MyDSN" })`, requires `npm install odbc`
- **Pagination standardized** - limit/offset primary, merged dual-key toPaginate() response
- **Test port at +1000** - user testing port (e.g. 8148) stable, no hot-reload
- **Dynamic version** - read from package.json, no hardcoded constant
- **Metrics dependency lines** - fixed basename parsing
- **autoMap uppercase columns** - snakeToCamel lowercases first
- **ORM TINA4_DATABASE_URL discovery** - auto-connect from env for SQLite
- **108 features at 100% parity**, 2,646 tests

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** - second HTTP server on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **SQLite transaction safety** - commit/rollback/startTransaction guarded
- **autoMap uppercase columns** - snakeToCamel lowercases first
- **ORM TINA4_DATABASE_URL discovery** - auto-connect from env for SQLite
- **QueryBuilder docs** - added to ORM chapter

---

## v3.10.48 - April 2, 2026

### Bug Fixes

**Cluster mode requires `TINA4_PRODUCTION=true`** - Worker forking no longer auto-triggers when debug is off. Set `TINA4_PRODUCTION=true` env var or use `tina4 serve --production` to enable cluster mode.

---

## v3.10.46 - April 1, 2026

### Test Coverage

CSRF middleware expanded to 32 tests matching Python reference. Node.js now at 2,546 tests with full parity across all 49 core areas.

---

## v3.10.45 - April 1, 2026

### Notes

Version bump for parity with PHP CLI serve fix. No Node.js-specific changes.

---

## v3.10.44 - April 1, 2026

### New Features

**Database tab redesign** - Split-screen layout with tables navigation on the left and query editor + results on the right. Click-to-select table highlighting.

**Copy CSV / Copy JSON** - Copy query results to clipboard in CSV or JSON format.

**Paste data** - Modal for pasting JSON arrays or CSV/tab-separated data. Auto-generates INSERT statements targeting the selected table, or prompts for a new table name with CREATE TABLE generation. SQL input passes through unchanged.

**Multi-statement execution** - Query runner handles batched SQL statements in a transaction.

**Database badge on load** - Table count shows immediately without clicking the Database tab.

**Star wiggle animation** - Empty star (☆) on the landing page with delayed wiggle animation at random intervals.

### Bug Fixes

**Default port** - Node.js default port set to 7148 (PHP=7145, Python=7146, Ruby=7147, Node=7148).

**SQLite LIMIT fix** - Prevents double-LIMIT errors in the database browser.

**browseTable quote escaping** - Fixed table name click handlers.

**Server handler dispatch regex** - Fixed a regex that required whitespace after `async` in handler functions. Transpiled auto-CRUD handlers producing `async(req,res)=>` were called with zero arguments, causing crashes.

**Cluster mode in tests** - Server-based tests now set `TINA4_DEBUG=true` to prevent cluster mode forking, which was causing ECONNREFUSED errors.

### Test Coverage

Massive test expansion - 718 new tests added across Auth (+52), ORM (+30), FakeData (+48), Cache (+23), DevMailbox (+32), Static (+21), Queue (+20), Frond (+57), CLI scaffolding (55), Metrics (69), plus v3.10.44 feature tests and server test fixes. 2,530 tests passing, 0 failures.

---

## v3.10.40 - April 1, 2026

### Bug Fixes

**Dev overlay version check** - Fixed misleading "You are up to date" message when running a version ahead of what's published on npm. The overlay now shows a purple "ahead of npm" message. Also added a breaking changes warning (red banner with changelog link) when a major or minor version update is available.

---

## v3.10.39 - April 1, 2026

### New Features

**`Database.getColumns(tableName)`** - Returns `[{name, type, nullable, default, primaryKey}]` for each column. Uses `PRAGMA table_info` for SQLite and `information_schema.columns` for PostgreSQL/MySQL/MSSQL.

**`Database.executeMany(sql, paramSets)`** - Execute a SQL statement with multiple parameter arrays in a single transaction for atomicity and performance.

**`BaseModel.create<T>(data)`** - Static factory method: instantiates, saves, and returns the new record.

**`BaseModel.find()` and `BaseModel.load()`** - aliases for `findById()` (parity with Python, PHP, Ruby).

**`seed` CLI command** - `tina4nodejs seed` scans `src/seeds/*.ts` and executes them via `tsx`.

**`Router.allRoutes()`** - alias for `getRoutes()`.

---

## v3.10.38 - April 1, 2026

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

## v3.10.x - Previous Releases (March 28-31, 2026)

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

<div v-pre>

WSDL services gained `beforeCall` and `afterCall` hooks. The Frond template engine learned to resolve dotted function names like `{{ utils.format(value) }}`.

</div>

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

<div v-pre>

The Frond engine learned arithmetic. `{% set total = price * quantity %}` and `{{ width + padding }}` now work as expected.

</div>

**MCP server (v3.10.32)**

Tina4 Node.js ships a built-in MCP (Model Context Protocol) server. AI coding tools can connect to your running application and inspect routes, models, and database schema.

### Bug Fixes

**Frond dict[variable_key] access (v3.10.11)**

Variable keys in dictionary access were ignored. The engine treated `dict[myVar]` as a literal string lookup instead of resolving `myVar` first.

```twig
{# Before fix - broken: always looked up the literal string "myVar" #}
{% set key = "name" %}
{{ user[key] }}  {# returned undefined #}

{# After fix - works: resolves key to "name", then looks up user["name"] #}
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

<div v-pre>

Filters inside `{% if %}` conditions were silently ignored. The condition evaluated the raw value instead of the filtered one.

</div>

```twig
{# Before fix - broken: |length filter ignored, condition tested the array itself #}
{% if items|length > 0 %}

{# After fix - works: |length runs first, condition compares the number #}
{% if items|length > 0 %}
```

**Stale templates in dev mode (v3.10.24)**

The dev server cached compiled templates and ignored file changes. Editing a template required a server restart. The fix reads the filesystem on every request in development mode, while production mode keeps the cache.

**ORM save/delete transaction safety (v3.10.25)**

SQLite threw "cannot commit - no transaction is active" when the ORM called `commit()` outside an explicit transaction. The ORM now wraps every `save()` and `delete()` in a `startTransaction()`/`commit()`/`rollback()` block.

```typescript
// Before fix - threw on SQLite:
const user = new User({ firstName: "Alice" });
await user.save(); // Error: cannot commit - no transaction is active

// After fix - works on all database engines:
const user = new User({ firstName: "Alice" });
await user.save(); // Transaction handled internally
```

**Frond macro HTML escaping (v3.10.27)**

<div v-pre>

Macro output was HTML-escaped when used inside `{{ }}` expressions. A macro that generated `<div>` would render as `&lt;div&gt;`. Nested macros double-escaped. Macro output is now treated as safe HTML, matching standard Twig behaviour.

</div>

**js_escape and to_json auto-escaping (v3.10.17-19)**

The `js_escape` and `to_json` filters produced output that Frond then HTML-escaped. A JSON string like `{"key":"value"}` became `{&quot;key&quot;:&quot;value&quot;}`. These filters now wrap their output in SafeString to bypass auto-escaping.

### Firebird-Specific

**Migration runner fixes (v3.10.10)**

The migration runner generated SQLite-style `AUTOINCREMENT` and `TEXT` types for Firebird. Firebird needs generators and `VARCHAR`. The runner now emits the correct DDL and generates IDs from a `GEN_TINA4_MIGRATION_ID` sequence.

---

## v3.9.x - QueryBuilder, Sessions, Path Injection (March 26-27, 2026)

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
// BEFORE (v3.8.x) - all routes were open by default
Router.post("/api/feedback", async (request, response) => {
  // Anyone could call this
});

// AFTER (v3.9.x) - opt out of auth for public endpoints
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

## v3.8.x - Template Engine, Typed Params, Security (March 25-26, 2026)

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
// BEFORE (v3.7.x) - Twig as a separate dependency
// package.json included "@tina4/twig": "^1.x"
// Templates used Twig-specific extensions

// AFTER (v3.8.x) - Frond is built in, zero dependencies
// Remove @tina4/twig from package.json
// Templates use Frond filters (same Twig syntax, built-in engine)
```

**Groundwork for zero dependencies (v3.8.4)**

v3.8.4 began migrating from `better-sqlite3` to Node's built-in `node:sqlite` module. The migration completed in v3.9.3.

---

## v3.7.x - Template Auto-Serve, Firebird Migrations (March 25, 2026)

A focused release. Two features, no breaking changes.

### Features

**Template auto-serve at / (v3.7.0)**

Place `index.html` or `index.twig` in `src/templates/` and the framework serves it at `/`. User-registered `GET /` routes take priority. When neither exists, the Tina4 landing page appears.

**Firebird idempotent migrations (v3.7.0)**

`ALTER TABLE ADD` statements on Firebird now check `RDB$RELATION_FIELDS` before executing. If the column exists, the migration logs "already applied" and moves on. Other databases and statement types are unaffected.

---

## v3.6.x - Architectural Parity (March 25, 2026)

### Features

**src/orm/ as primary model directory (v3.6.0)**

Models now live in `src/orm/` by default, matching the convention across all Tina4 frameworks. The framework still scans `src/models/` as a fallback.

### Bug Fixes

**Outdated API references (v3.6.0)**

Internal references to deprecated function names (`createToken` instead of `getToken`, `validateToken` instead of `validToken`) and route parameter syntax were updated.

---

## v3.5.x - Bundled Frontend, Middleware (March 25, 2026)

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

## v3.4.x - Database, Auth, WebSocket, Uploads (March 24, 2026)

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

## v3.3.x - Queue API, Field Mapping, Route Chaining (March 24, 2026)

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

## v3.2.x - Flexible Route Handlers (March 22, 2026)

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

## v3.1.x - Response Parity, Routing API (March 21-22, 2026)

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

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

TINA4_CACHE_BACKEND=redis
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

## v3.0.0 - Initial Release (March 21, 2026)

The initial Node.js release. No Express. No Fastify. No dependencies.

### Features

- **Native node:http** - The server uses Node's built-in HTTP module. Zero framework overhead.
- **TypeScript-first** - Strict mode, ESM only. No separate build step.
- **Database adapters** - SQLite, PostgreSQL, MySQL, MSSQL, and Firebird. Same API across all five.
- **File-based routing** - `src/routes/api/users/[id]/get.ts` maps to `GET /api/users/:id`.
- **Auto-CRUD** - Generate full REST endpoints from a model definition.
- **DevAdmin dashboard** - A built-in developer panel with route inspection and database tools.
- **AI integration** - Auto-detect and configure context for seven AI coding tools.
- **1,311 tests** across 43 test files.
- **Configurable port and host** - Default port 7148, binds to 0.0.0.0 for Docker.

```typescript
import { startServer } from "tina4-nodejs";

startServer({ port: 7148 });
```

One import. One function call. The server starts and your application is live.

---

## Pre-Release (rc.2-rc.5)

Four release candidates preceded v3.0.0. They stabilized the scaffolding, fixed the init command, added the error overlay, refined the landing page, and established the benchmark suite. If you started a project on a release candidate, upgrade to v3.0.0 and run `tina4 init` to regenerate your scaffolding files.

---

## Version Timeline

| Version | Date | Headline |
|---------|------|----------|
| v3.0.0 | March 21 | Initial release - zero dependencies, TypeScript-first |
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
