# Chapter 35: Release Notes

## v3.13.38 (2026-06-19) - Coordinated security & robustness release

A large bundled release closing a cross-framework hardening sweep. **WebSockets:** the Redis/NATS backplane is now wired for real - local-first delivery, then a published envelope on the shared `tina4:ws` channel, relayed by sibling instances with an origin guard (no own-echo, no cluster loop) - plus an origin allow-list (`TINA4_WS_ALLOWED_ORIGINS`), an idle reaper (`TINA4_WS_IDLE_TIMEOUT`), resilient broadcast (a dead/slow client is pruned, never aborts the loop), and SSE hardening (client-disconnect + generator-error). **Sessions:** a log-loud-and-degrade backend-failure policy (set `TINA4_SESSION_STRICT=true` to re-raise). **GraphQL/WSDL:** a SOAP `<!DOCTYPE>` is rejected before parsing (SOAP 1.1 forbids DTDs - this closes the XML entity-expansion / billion-laughs and external-entity surface), a recursion-depth guard (`TINA4_GRAPHQL_MAX_DEPTH`, default 50) catches deep queries **and** circular fragments, and resolver/SOAP faults are masked in production with the real cause logged (full detail only under `TINA4_DEBUG`). **Tooling:** a new `tina4 metrics` command reports the top-N code-health offenders (complexity, large files, low maintainability, untested) with `--top/--json/--fail-on/--path`, and the coverage test-detection is now precise - a real import / defined symbol, not a name-substring scan. **Queue:** Kafka TLS/SASL on the confluent producer **and** consumer (`TINA4_KAFKA_SECURITY_PROTOCOL` / `_SSL_CA_LOCATION` / `_SASL_MECHANISM|USERNAME|PASSWORD`, with bare `KAFKA_*` as a fallback - community PR #52). Zero new third-party dependencies. Full suite: 3,080 passing.

## v3.13.37 (2026-06-18) - Dev-admin editor: Ruby + more syntax highlighting

The dev-admin dashboard's code editor (CodeMirror) gained the grammars it was missing: `.rb` files - plus `.rs`/`.go`/`.java`/`.scss` - now highlight in the file viewer instead of falling through to plain text (the editor bundle had no Ruby/Rust/Go/Java case). Python's file-read endpoint already reported the correct `language` per extension, so this ships the rebuilt editor bundle that can render them. Dev-mode tooling only; no framework runtime change. Full suite: 2,952 passing.

## v3.13.36 (2026-06-18) - Instant WebSocket dev-reload

Dev-reload is now a WebSocket push instead of a poll. On a file change `tina4 serve` POSTs `/__dev/api/reload`; the server re-imports just the changed route module in-process - mtime-tracked, same PID, **no respawn** - then broadcasts `{type, file, mtime}` to every browser on the `/__dev_reload` WebSocket, and the injected toolbar client reloads instantly (CSS changes hot-swap the `<link>` href without a full reload). The `/__dev/api/mtime` poll is now a fallback only, used when the socket is down. `Router.add` replaces a re-registered `(method, path)` in place so the fresh handler wins instead of being shadowed by a stale duplicate. Debug-mode only - production is untouched. Full suite: 2,952 passing.

## v3.13.35 (2026-06-17) - Live MCP endpoint for AI agents

The built-in MCP server is now actually reachable. It was fully built - 50+ dev tools (live DB queries, file I/O sandboxed to the project, route list, project overview, framework docs search) - but never mounted, so no MCP client could connect. `tina4 serve` now exposes it at `/__dev/mcp` (JSON-RPC) + `/__dev/mcp/sse`, gated on debug mode, giving an AI agent (Claude Desktop/Code) live access scoped to the running project. Also fixed the `route_list` dev tool, which referenced a non-existent `Router._routes` (now `Router.get_routes()`) and errored for every caller - caught by new tool-coverage tests. Full suite: 2,943 passing.

## v3.13.34 (2026-06-17) - Demo + onboarding fixes

The example store crashed on boot: `app.py` imported `orm_bind`, which was renamed to `bind_database` in 3.13 (no alias). Switched it, so the demo boots, migrates, seeds, and serves real data again. Corrected stale env-var names in the README and `example/.env` to the names the framework actually reads (`TINA4_SECRET`, `TINA4_LOG_LEVEL`, `TINA4_LOCALE`, `TINA4_SESSION_BACKEND`, `TINA4_SWAGGER_*`) - the demo had been signing JWTs with a blank secret - and unified project creation on the `tina4` CLI. Examples/docs only; framework unchanged.

## v3.13.33 (2026-06-17) - Queues: priority pop + automatic dead-lettering (⚠ behavioural change)

**Behavioural change.** `job.fail()` now **re-enqueues** the job (incrementing `attempts`) until `attempts >= max_retries`, then moves it to the dead-letter store - so a `for job in queue.consume(topic): ... job.fail(e)` loop retries `max_retries` times and dead-letters automatically (no manual `retry_failed()`). Previously `fail()` only marked the job failed. Also: `pop`/`consume` now return the **highest-priority** available job first (ties oldest-first) instead of FIFO; new additive `Queue(..., retry_backoff=0)` delays the auto re-enqueue. Only the file/lite backend changed (brokers delegate retry/dead-lettering). The queue chapter was rewritten to match (the documented retry→dead-letter flow is now real). Full suite: 2,933 passing.

## v3.13.32 (2026-06-17) - Caching: per-query bypass + X-Cache headers (chapter rewritten to match code)

Added a per-query cache bypass - `db.fetch(... , no_cache=True)` (also `fetch_one`/`fetch_all`) skips both the lookup and the store for that one call. The HTTP `ResponseCache` now stamps `X-Cache: HIT|MISS` and `X-Cache-TTL: <seconds>` on cached responses (no `Cache-Control`). The caching chapter was substantially rewritten to match the code: the real `cache_stats()` shapes, all seven backends + file-backend fallback, the three cache layers (request-scoped auto, persistent DB, response), and accurate env/defaults - removing earlier aspirational claims (a fictional stats shape, stale-while-revalidate, a `/__dev` per-key panel, auto `Cache-Control`). Full suite: 2,924 passing.

## v3.13.31 (2026-06-17) - Documentation fixes (no functional change)

Corrected the developer guide: `Response.add_header` is an instance method - the class-level `Response.add_header(...)` shown previously raises `TypeError`, so it's now `response.add_header(...)` (including six middleware examples in Chapter 10). Removed a stale `fieldName` key from the `request.files` upload example (the dict has `filename`, `type`, `content`, `size`). Code is unchanged. Full suite: 2,914 passing.

## v3.13.30 (2026-06-16) - Typed route params now arrive coerced (⚠ behavioural change)

**Behavioural change.** A typed path param now arrives **coerced to its type** instead of as a raw string: `{id:int}` / `{id:integer}` → `int`, `{price:float}` / `{x:number}` → `float`. Every other type (`string`, `alpha`, `alnum`, `slug`, `uuid`, `path`) and an untyped `{id}` stay strings; URL matching is unchanged (`{id:int}` still 404s on non-digits). Previously `{id:int}` matched only digits but still handed the handler the string `"42"` - code that did string operations on a typed param must adjust. This brings Python in line with Ruby (which already coerced) and the documented "auto-converted" behaviour, now matched by PHP and Node too. Also fixed a reversed `check_password` argument-order line in the dev guide. Full suite: 2,914 passing.

## v3.13.29 (2026-06-16) - Live API search (`api_search`/`api_class`/`api_method`) now finds what you ask for

The live reflection index behind the `api_*` MCP tools - what AI assistants query for real method signatures instead of guessing - had three gaps, now fixed:

- **Metaprogrammed methods were invisible.** `Frond.add_filter` / `add_global` / `add_test` are defined through a custom class/instance descriptor, and the reflector's `__qualname__` owner check skipped them - they never entered the index. Reflection now walks `obj.__dict__`, unwraps staticmethod/classmethod/property/descriptor wrappers, and strips receiver params, so `api_method("Frond", "add_test")` returns `add_test(name, fn)`.
- **Class-qualified queries weren't steered.** `api_search("Frond.add_test")` returned unrelated `add_*`/`*test*` methods because only the bare name was scored. Ranking now weights the owning class, fqn segments, and an exact `Class.method` match, so the right method ranks first.
- **Lookups only matched the deep fqn.** `api_class`/`api_method` now resolve the documented public import path and a bare class name (`Database`), not just `tina4_python.database.connection.Database`.

The bundled AI skills (developer/maintainer/js) now instruct assistants to query `api_*` before guessing a signature. Full suite: 2,905 passing.

## v3.13.28 (2026-06-16) - Frond: custom `add_test` now honoured by `is`

<div v-pre>

**Python only.** A test registered with `Frond.add_test("positive", fn)` was ignored by `{% if x is positive %}` - the `is` evaluator checked a hardcoded built-in table (`even`, `odd`, `defined`, ...) and never consulted the instance's custom-test registry, so every custom test silently returned false. It now merges the registered tests (reachable via the bound evaluator) over the built-ins, so custom registrations work and can override built-ins - matching PHP, Ruby, and Node. Built-in tests are unchanged. Surfaced by a cross-engine host-API check (`add_filter`/`add_global`/`add_test`/`form_token`) while building the verified cheatsheet. Full suite: 2,901 passing.

</div>

## v3.13.27 (2026-06-16) - Frond template-engine parity fixes

A 50-case cross-engine audit (every Frond tag, filter, and test rendered through all four frameworks with identical templates) surfaced six places where Python's output diverged from the Twig/Jinja standard. All are now fixed to match:

<div v-pre>

- **`{{ x | e }}` / `escape`** no longer double-escapes - the filter returns a `SafeString`, so the auto-escaper leaves it alone (`<b>` → `&lt;b&gt;`, not `&amp;lt;b&amp;gt;`).
- **`{{ "%.2f" | format(value) }}`** now resolves a *variable* argument to its value (it previously errored). Unquoted filter arguments are treated as variable references; quoted literals stay literal.
- **`{%- ... -%}` whitespace control** now actually trims - a single up-front pass applies every trim marker, including on closing tags (`endif`/`endfor`) and block-body boundaries.
- **`json_encode`** emits compact `[1,2,3]` (no spaces); **`round`** at precision 0 renders the integer `4` (not `4.0`); **`nl2br`** escapes its input, inserts `<br />`, and is marked safe - all matching PHP.

</div>

Behavioural note: these change rendered output for the affected filters - they are correctness fixes toward the documented Twig/Jinja behaviour. Full suite: 2,900 passing.

## v3.13.26 (2026-06-16) - pooling fix: standalone writes auto-commit; explicit transactions stay atomic

**Behavioural default change.** A standalone write - `execute`/`insert`/`update`/`delete` made **outside** an explicit transaction - now **auto-commits on its own connection before returning**. Previously the default was autocommit *off*, which broke connection pooling: a standalone `INSERT` landed uncommitted on one pooled connection, then the next read round-robined to a different connection and saw nothing. Standalone writes are now durable and visible across the pool.

Explicit transactions are unchanged and stay atomic - inside `start_transaction()` ... `commit()`/`rollback()` the per-statement commit is suppressed (the commit branches are gated on `not self._in_transaction`), so a `rollback()` still discards everything. The psycopg2 connection still runs with `connection.autocommit = False`, so the framework owns commit boundaries and the v3.13.15 idle-in-transaction read-rollback still applies.

Set `TINA4_AUTOCOMMIT=false` in `.env` for strict manual-commit mode (every write needs an explicit `commit()`).

Verified live on PostgreSQL: standalone write visible from a separate connection, explicit rollback discards, explicit commit persists, and pooled standalone writes visible across every round-robin connection. Full suite: 2,894 passing.

## v3.13.24 (2026-06-15) - unified cache backends across response, KV, and persistent DB cache

The response/KV cache now supports **seven backends**, selected by `TINA4_CACHE_BACKEND`: `memory` (default), `file`, `redis`, `valkey`, `memcached`, `mongodb`, and `database`. `TINA4_CACHE_URL` carries the connection string for `redis`/`valkey`/`memcached`/`mongodb`, or a SQL URL for the `database` backend (which falls back to `TINA4_DATABASE_URL`). Credentials can be embedded in the URL (`redis://user:pass@host`, `redis://:pass@host`, `mongodb://user:pass@host`) or supplied via `TINA4_CACHE_USERNAME` / `TINA4_CACHE_PASSWORD` (mirroring `TINA4_DATABASE_USERNAME`/`_PASSWORD`); memcached is unauthenticated. The usual `TINA4_CACHE_TTL` (60), `TINA4_CACHE_MAX_ENTRIES` (1000), and `TINA4_CACHE_DIR` (`data/cache`) still apply.

**Graceful fallback:** if a configured backend's driver is missing or the service/credentials are unreachable or wrong, the cache logs a warning and falls back to the **file** backend - a real persistent cache, never a silent no-op.

The **persistent DB query cache** (`TINA4_DB_CACHE=true`) now routes through the same backend set via `TINA4_DB_CACHE_BACKEND` + `TINA4_DB_CACHE_URL`, so multiple instances share one cache with global write-invalidation. `cache_stats()` now reports a `backend` field alongside `mode`.

Full suite: 2,899 passing.

## v3.13.23 (2026-06-15) - request-scoped DB query cache, on by default

A new **request-scoped query cache** protects your database from rapid repeat reads. Within a single request, identical `SELECT`s and ORM reads are deduped automatically - the DB is hit once and subsequent identical reads are served from memory. The cache is **cleared at the start of every request** (so it never serves stale rows across requests) and **flushed on any write** (insert/update/delete/execute). For non-request contexts (scripts, workers) a short safety TTL applies.

It is **on by default** via `TINA4_AUTO_CACHING=true` (off-switch `TINA4_AUTO_CACHING=false`); the in-request TTL is `TINA4_AUTO_CACHING_TTL` (default 5 seconds). The existing `TINA4_DB_CACHE` (default `false`) remains the separate *persistent* cross-request cache (TTL `TINA4_DB_CACHE_TTL`, default 30s) and is not cleared per request. `cache_stats()` now reports a `mode` field: `"request"` (default), `"persistent"`, or `"off"`.

Full suite: 2,866 passing.

## v3.13.22 (2026-06-15) - session default TTL standardised to 1 hour

The default session lifetime now matches across all four frameworks: **3600 seconds (1 hour)**. Python previously defaulted to 1800s (30 min). The session cookie `Max-Age` and the file-handler garbage-collection window both follow `TINA4_SESSION_TTL` (default now 3600) - override it in your `.env`. PHP and Node already used 3600 and are unchanged.

## v3.13.21 (2026-06-15) - security: never sign JWTs with a guessable default secret

**Security fix.** When `TINA4_SECRET` was unset, Tina4 silently signed JWTs **and** CSRF form tokens with a hardcoded built-in default secret - so anyone who knew that default could forge valid tokens, and the developer got no warning. It affected `Auth`, the Frond `form_token()` filter, and the CSRF middleware (four copies of the same fallback).

Token signing now reads `TINA4_SECRET` and, when it is unset, **warns loudly and uses a blank secret** - matching what the PHP and Node frameworks already did. There is no longer a guessable built-in secret. **Always set `TINA4_SECRET` in production.**

Also corrected stale docs: the JWT secret env var is **`TINA4_SECRET`** (some docs still said `SECRET`), and `$response->template()` references are fixed to `response.render()`.

Full suite: 2,857 passing.

## v3.13.19 (2026-06-15) - return domain objects, construct from JSON, and one database binder

Three ergonomic improvements surfaced by the live side-by-side review of the book's own examples across all four frameworks.

### `response(...)` serializes domain objects

Return an ORM model, a list of models, or a query result straight from a route - Tina4 serializes it to JSON. No more hand-rolled `to_dict()` / `to_json()`:

```python
@get("/api/users")
async def users(request, response):
    return response(User.all())        # list of models -> JSON array
```

A single model becomes a JSON object; a list of models or a `DatabaseResult` becomes a JSON array. Plain dicts, lists and strings behave exactly as before - this is purely additive.

### Construct a model from a JSON object string

The model constructor now accepts a JSON object string, alongside a dict or keyword args:

```python
User('{"name": "Alice", "email": "alice@example.com"}')   # parsed into one record
User({"name": "Alice"})                                    # still works
User(name="Alice")                                         # still works
```

Passing a **list/array** to a single-record constructor now raises a clear `TypeError` instead of a cryptic `'list' object has no attribute 'items'`. To build many records, map over the list.

### ⚠ Breaking - one database binder: `bind_database`

The ORM-to-database binder is now **`bind_database`** across all four frameworks (was `orm_bind` in Python). The default is unchanged - models still auto-bind to `TINA4_DATABASE_URL`, so apps that rely on the `.env` default need **no change at all**.

```python
# Most apps: nothing to do - the .env default is auto-bound.

# Override the default explicitly:
bind_database(Database("sqlite:///app.db"))

# Register a NAMED connection and point a model at it:
bind_database(Database("postgres://.../analytics", "u", "p"), name="analytics")

class Visit(ORM):
    _db = "analytics"        # this model uses the analytics connection
```

A model can live on a different database from the default - `bind_database(db, name="...")` registers it and `_db = "..."` selects it. A missing named connection raises a clear error.

**Migration:** rename `orm_bind(...)` → `bind_database(...)`. That is the only change; the `name=` argument, per-model `_db`, and `.env` resolution are new or unchanged.

Full suite: 2,852 passing. Shipped with parity across all four frameworks.

## v3.13.16 (2026-06-15) - `create_table()` works on PostgreSQL + `DatabaseResult` index access

Found by the live documentation-verification pass - running the book's own samples against a real PostgreSQL database. The documented code-first schema path, `ORM.create_table()`, was silently broken on PostgreSQL: it emitted SQLite-only DDL, PG rejected it, the error was swallowed, and the method returned `True` while creating **no table**.

### `create_table()` is now engine-aware

- **`DateTimeField` → `TIMESTAMP`** on PostgreSQL (and Firebird) - they have no `DATETIME` type (`type "datetime" does not exist`); `DATETIME` stays on SQLite/MySQL/MSSQL.
- **`BooleanField` → native `BOOLEAN`** on PostgreSQL/MySQL, `BIT` on MSSQL, `INTEGER` on SQLite/Firebird. The engine check previously compared against `"postgres"` but `get_database_type()` returns `"postgresql"`, so bool columns silently got `INTEGER` on PG - fixed. Boolean column `DEFAULT`s are engine-aware too (`TRUE`/`FALSE` vs `1`/`0`).
- **A failed `CREATE` now returns `False` (and logs)** instead of masquerading as success.
- The PostgreSQL adapter no longer rewrites `TRUE`/`FALSE` → `1`/`0` (`boolean_to_int`) - PG has a native boolean, and that rewrite had broken `DEFAULT FALSE` and `WHERE active = TRUE` on `BOOLEAN` columns.

### `DatabaseResult` is subscriptable

`result[0]` (documented in chapter 5, "Index Access") raised `TypeError: 'DatabaseResult' object is not subscriptable`. Added `__getitem__` - index and slice access now delegate to `.records`. The bundled guide's wrong "no `len()` support" note is corrected too.

Verified against PostgreSQL 16: a model with `id` (auto-increment) + `StringField` + `BooleanField` + `DateTimeField` creates, inserts, and round-trips natively (real `bool`, `TIMESTAMP`). New PG-backed test suite (skip-if-no-PG) + always-run subscript suite. Full suite: 2,840 passing. Shipped with parity across all four frameworks.

## v3.13.15 (2026-06-15) - Python only: PostgreSQL idle-in-transaction leak (#51)

**Python only.** psycopg2 follows the DB-API contract - a connection starts with `autocommit = False`, so even a bare `SELECT` opens a transaction. Tina4's `fetch()` / `fetch_one()` never closed it, so every read left the connection `idle in transaction` for its lifetime, pinning a pool slot and any locks it touched. PHP (`pg_query`), Ruby (`pg`), and Node (`node-postgres`) run on libpq autocommit - each statement is its own transaction - so the leak can't happen there. They stay at v3.13.14.

### The slow-motion outage

The migration runner's batch lookup runs at boot:

```python
row = db.fetch_one("SELECT MAX(batch) as max_batch FROM tina4_migration")
```

That read opened a transaction and left it open. Each short-lived pod/process leaked one `idle in transaction` connection holding locks on `tina4_migration`. Over enough restarts the pool filled - `FATAL: remaining connection slots are reserved for roles with the SUPERUSER attribute` - and then module autodiscovery failed mid-boot, so `/health-check` still passed (pod marked Ready) while every real route 404'd. A silent "ready but broken" state; #51 reported sessions sitting idle for 2+ days.

### The fix

After a successful read **outside** an explicit transaction, the PostgreSQL adapter now rolls back the implicit transaction - a `SELECT` has nothing to persist, so a rollback is the clean close that returns the connection to plain `idle`. Inside `start_transaction()` the caller owns the transaction, so it's left alone. `execute()` (writes) is deliberately untouched: with autocommit off a write must still be committed explicitly, and auto-closing it would silently drop data.

This is distinct from the v3.13.8 fix, which healed *aborted* transactions - a clean idle read-transaction never hit that path.

### Tests

- Python: 2,836 passed (+7 - `_end_read_txn` unit, `fetch`/`fetch_one` wiring, in-transaction deferral). No live PostgreSQL required: a fake connection records the rollback, and psycopg2 is stubbed when the optional driver is absent (so the guard runs in CI).

## v3.13.14 (2026-06-13) - Logs reach stdout in containers + per-request logging + schema-qualified tables (#48)

**Cross-framework release (all four).** Deployed Docker containers were getting no application logs. The cause was the same architectural decision in every framework: in production/container mode Tina4 either **suppressed stdout** or wrote logs **only to a file inside the container** - but `docker logs` (and Kubernetes) read PID 1's stdout, so operators saw nothing. A follow-on report - "logs stop after `Development server: asyncio`" - surfaced a second gap: the dev server logged its startup banner but **never logged requests**, so it looked dead under traffic.

This is a 12-factor correction: a container's stdout *is* the log sink.

### Per-request logging - on by default in dev

Every request now logs one line through the Tina4 `Log` (→ stdout), on by default in development and opt-in for production via `TINA4_LOG_REQUESTS`:

```
2026-06-12T10:15:03.221Z [INFO   ] GET /api/users -> 200 (12.3ms)
```

- Format is identical across all four frameworks: `METHOD /path -> STATUS (Nms)`.
- **Default**: on when `TINA4_DEBUG` is truthy (dev), off in production - so prod doesn't pay the per-request cost unless you opt in.
- `TINA4_LOG_REQUESTS=true` forces it on (production debugging); `=false` forces it off.
- Routed through `Log`, so it's coloured human-readable in dev and structured JSON in production, like every other line.

Two bugs fixed here: Python's `RequestLoggerMiddleware` emitted via an **unconfigured stdlib `logging` logger** (silently dropped - never reached stdout), and the dev server only fed request data to the `/__dev` dashboard inspector, never to a log. Both now go through `Log`.

### What changed (stdout)

1. **stdout is no longer suppressed in production.** Logs are written to stdout regardless of `TINA4_ENV`/`TINA4_DEBUG`. Production emits clean JSON (no ANSI colour) so aggregators can parse it; dev keeps the human-readable coloured format. `TINA4_LOG_OUTPUT=file` still opts out of stdout entirely.
2. **stdout is flushed per line.** `print(..., flush=True)` - logs appear immediately on a non-TTY pipe (every container) instead of sitting in Python's block buffer until the process exits (or vanishing on an abrupt stop).
3. **Default log level is now `INFO`** (was `ERROR`). An app that logged at info/debug previously looked silent in production. INFO surfaces request/startup/warning/error without debug noise. Override with `TINA4_LOG_LEVEL`.

```python
# In a container (TINA4_ENV=production), with the default config:
Log.info("worker started")
# pre-v3.13.14: written only to logs/tina4.log inside the container → docker logs empty
# v3.13.14:    {"timestamp":"...","level":"INFO","message":"worker started"}  → on stdout
```

### Why it spanned all four

The bug was the *same* decision in each framework, so the fix is too:

| Framework | Pre-v3.13.14 cause | Fix |
|---|---|---|
| Python | `not _is_production` gate suppressed stdout; default ERROR | stdout always on (flushed); default INFO |
| PHP | `$stdout = $development` (file-only in prod); no `TINA4_LOG_LEVEL` read | stdout default on + `fflush`; reads `TINA4_LOG_LEVEL`; default INFO |
| Ruby | stdout written but **never flushed** (block-buffered on non-TTY); default ALL | `$stdout.sync = true`; default INFO; accepts plain + bracket level names |
| Node | `!isProduction()` gate suppressed console; default DEBUG | console always on; production emits JSON; default INFO |

The Rust `tina4` CLI was already correct - it inherits child stdio, so child logs flow to the container.

### Request logging parity

| Framework | Pre-v3.13.14 | Fix |
|---|---|---|
| Python | no request log; `RequestLoggerMiddleware` used a dead stdlib logger | log in dispatch via `Log`; middleware routed through `Log` |
| PHP | `RequestLogger` not default-on, line lacked status | log in `Router::dispatch` via `Log`; status added to the line |
| Ruby | dev inspector only; `RequestLoggerMiddleware` not wired; `[RequestLogger]` prefix | log in `rack_app` via `Log`; prefix dropped for parity |
| Node | `requestLogger` always-on via bare `console.log`, status-first format | gated (dev-default + env), routed through `Log`, standard format |

### Schema-qualified tables (#48) + a PostgreSQL `fetch()` regression

Issue #48 - *"Database Table Does Not Exist"* on PostgreSQL. A model whose table lives in a non-default schema (`gift_cards.gift_card`, MSSQL `dbo.widget`, MySQL `otherdb.table`, SQLite ATTACH `extra.widget`) was invisible to the framework's introspection. `table_exists`, `get_tables`, and `get_columns` hardcoded the default namespace (`public`) and matched the whole dotted string as one flat name - so plain reads worked, but `create_table`, migrations, and auto-CRUD were blind to the table and reported it missing.

All introspection is now schema-aware on every affected engine:

- **PostgreSQL** - `table_exists` uses `to_regclass()` (honours schema + `search_path`); `get_columns` filters by `table_schema`; `get_tables` lists every non-system schema and returns non-`public` tables schema-qualified.
- **MySQL** - schema = database; a qualified name checks that catalog, a bare name defaults to `DATABASE()`.
- **MSSQL** - honours `dbo.table`; a bare name matches in any schema.
- **SQLite** - honours an ATTACH alias (`extra.widget`) for both `table_exists` and `get_columns`.
- **Firebird** - N/A (no schemas).

Verified against a live PostgreSQL 16 container: `table_exists('gift_cards.gift_card') → True`, `get_tables → ['gift_cards.gift_card', 'gift_cards.transaction']`, `get_columns → 12 columns` - identical results across all four frameworks.

> **PHP also fixed a v3.13.12 regression found while cross-checking #48.** `PostgresAdapter` referenced `stripTrailingSemicolons()` (added in v3.13.12) and the new `splitSchema()` but never mixed in `SqlNormalizerTrait` - so **every PostgreSQL `fetch()` / `fetchOne()` / `getColumns()` fatalled** with *"Call to undefined method"*. It shipped silently because the PHP PostgreSQL test suite skips without a live server. Fixed with a one-line trait mix-in and pinned by server-free reflection guards that assert all five SQL adapters expose the normalizer helpers.

### Tests

- Python: 2,829 passed (+18 new - stdout-in-prod, JSON shape, level filter, file opt-out; request-log gate + middleware; #48 schema split + SQLite ATTACH introspection)
- PHP: 2,394 passed (+63 new - stdout/level/file gating; request-log format + gate; #119 cli-server crash fix + LegacyEnvGuard suite now CI-gated; #48 schema-qualified + PG trait regression guards)
- Ruby: 2,999 passed (+23 new - level resolution + `$stdout.sync`; request-log gate + dispatch; #48 schema split + SQLite ATTACH introspection)
- Node: 3,628 passed (+16 net - production JSON stdout; request-log gating + format; #48 schema split + SQLite ATTACH introspection)

**11,850 tests across the family, zero regressions.**

> PHP also fixed #119 in this release - `App::checkLegacyEnvVars()` crashed with `Undefined constant Tina4\STDERR` under the built-in `cli-server` (bare `STDERR` is only auto-defined for the `cli` SAPI). Now uses the `php://stderr` stream. PHP-specific; the other three don't reference that constant.

---

## v3.13.12 (2026-06-11) - SQL safety + implicit ORM binding + `fetch_all` correctness

Three high-impact fixes that close out long-standing footguns. All three ship with full parity across all four frameworks.

### `fetch_all` actually fetches ALL rows now (no silent 100-row truncation)

Pre-v3.13.12 the convenience method defaulted to `limit=100` and silently truncated. The name says `fetch_all` - it should fetch them all:

```python
# 150 rows in the table
db.fetch_all("SELECT * FROM rows")
# pre-v3.13.12: returns 100 rows, silently drops the other 50
# v3.13.12:    returns all 150 rows
```

The new default is `limit=0`, which the adapter interprets as "no pagination injection" - your SQL runs verbatim. To opt back into a cap, pass `limit=N` explicitly:

```python
db.fetch_all("SELECT * FROM events", limit=500)   # capped
db.fetch_all("SELECT * FROM users")               # all rows
```

`db.fetch()` (the paginated sibling that returns a `DatabaseResult` with count metadata) keeps its 100-row default - pagination is its job. Only the `fetch_all` convenience changed.

**Breaking change**: callers who relied on the silent 100-row cap now get every row. For very large tables, switch to `fetch()` (which paginates with metadata) or pass an explicit `limit`. Per the v3 parity rule, breaking changes are OK when correctness is the win.

### Trailing `;` is now stripped from user SQL in `fetch()` / `fetch_one()`

The framework appends `LIMIT n OFFSET m` to the user-supplied query (and wraps it in `SELECT COUNT(*) FROM (...) AS subq` for the count probe). When the user's query already ended with a `;`, both rewrites broke:

```python
db.fetch("SELECT * FROM users;")
# pre-v3.13.12: syntax error near "LIMIT" - the appended LIMIT followed a ;
# v3.13.12:    works - trailing ; is stripped before LIMIT is appended
```

The strip is conservative: only trailing whitespace + semicolons are removed (any number of them, including `;;`), nothing inside the statement is touched. Parameters and quoting are unchanged - the existing parameter-binding defense against injection still does all the heavy lifting.

Applied at the top of `fetch()` and `fetch_one()` on all five adapters: PostgreSQL, MySQL, SQLite, MSSQL, Firebird.

### Ruby ORM now auto-discovers `TINA4_DATABASE_URL` like the other three

When `TINA4_DATABASE_URL` was set in `.env` but `Tina4.bind!` had never been called, Ruby ORM operations returned `nil` from the model's `db` accessor - every save / find / where silently no-op'd. Python, PHP, and Node all already discovered the env var on first use; Ruby had the helper (`auto_discover_db`) defined but never called.

```ruby
# .env has TINA4_DATABASE_URL=sqlite://./app.db, no explicit Tina4.bind! anywhere
User.find(1)
# pre-v3.13.12: nil  (db accessor returned nil, query never ran)
# v3.13.12:     <User id: 1, ...>  (auto-discovered on first model access)
```

Explicit `Tina4.bind!(db)` still takes precedence - use it to bind a second database or override the env-driven default. The behaviour now matches Python's `database_url_auto_discover()`, PHP's adapter auto-init, and Node's `initDatabase()` env fallback.

### Cross-framework parity

| Fix | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| `fetch_all` returns ALL rows by default | ✓ `limit=0` default | ✓ `$limit = 0` default | ✓ `limit: nil` default | ✓ already correct (`limit?` undefined) |
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

Five fixes bundled into one release. Two are Andre's own ORM bugs (#50), two close out follow-on gaps from Michael's error-visibility report (#49), and one fixes a PostgreSQL-level mismatch that BooleanField columns were creating.

### #50.1 - Callable field defaults are now resolved per-instance

```python
class GiftCard(ORM):
    created_at = DateTimeField(default=lambda: datetime.now())
```

Pre-v3.13.11 this stored the lambda object verbatim and crashed on save:

```
psycopg2.ProgrammingError: can't adapt type 'function'
```

Now the framework invokes the callable **per instance** at construction time, so every row gets a fresh value. Types are excluded (`default=int` is preserved verbatim - that's almost never intended as "call `int()`").

### #50.2 - `save()` correctly INSERTs natural (non-auto-increment) PKs

For models with a user-supplied PK (e.g. `gift_card_number = "GC-100"` set before the first save), pre-v3.13.11 `save()` always chose UPDATE - matched zero rows - and silently returned success without inserting anything. The framework now checks `cls.exists(pk_value)` for non-auto-increment PKs:

```python
gc = GiftCard()
gc.gift_card_number = "GC-100"
gc.save()                          # → INSERT (pre-v3.13.11 was a silent UPDATE no-op)
GiftCard.find_by_id("GC-100")      # → returns the row
```

Auto-increment behaviour is unchanged: `PK is None → INSERT`, `PK set → UPDATE`. Saving an existing natural-key row still UPDATEs (and doesn't duplicate).

### #49.1 - Original cause logged when failure is inside an explicit transaction

When a query fails inside `db.start_transaction()`, the auto-rollback correctly defers to the user. But the visibility half no longer goes with it - the framework now emits a Log.warning marker so operators can spot the upstream cause that's about to be buried by the cascade. The `fetch()` COUNT probe also now logs original-cause failures via `Log.warning` before swallowing.

### #49.2 - `Database.fetch()` populates `last_error` (mirror of `execute()`)

```python
try:
    db.fetch("SELECT * FROM does_not_exist")
except Exception:
    pass

db.get_error()   # pre-v3.13.11: None  (adapter had the cause, wrapper never read it)
                 # v3.13.11:     "relation \"does_not_exist\" does not exist"
```

### BooleanField - engine-aware DDL on PG / MySQL / MSSQL

Pre-v3.13.11 `BooleanField` mapped to `INTEGER` on every engine. That caused PostgreSQL to throw `operator does not exist: boolean = integer` when Python `bool` values bound via psycopg2 met the `INTEGER` column - because psycopg2 adapts `True`/`False` to PG `boolean`, not to integer.

v3.13.11 makes `BooleanField → create_table()` engine-aware:

| Engine | DDL type |
|---|---|
| PostgreSQL | `BOOLEAN` |
| MySQL | `BOOLEAN` (alias for `TINYINT(1)`) |
| MSSQL | `BIT` |
| SQLite | `INTEGER` (no native bool) |
| Firebird | `INTEGER` (driver round-trip uneven for native BOOLEAN) |

**Breaking change**: callers writing literal `= 0` / `= 1` against tables created by `create_table()` on PG / MySQL / MSSQL will need to update to `= false` / `= true` (or the engine's native bool literal). Tables created via migration with explicit DDL aren't affected - the framework only sets the type when it creates the table itself.

### Cross-framework parity

| Fix | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| #50.1 callable defaults | ✓ fixed | N/A (PHP property defaults are constants) | ✓ fixed (Procs) | N/A (no auto-default at construction) |
| #50.2 natural-key INSERT | ✓ fixed | ✓ already correct (`recordExists`) | ✓ already correct (`@persisted` flag) | ✓ fixed |
| #49.1 + #49.2 PG visibility | ✓ fixed (Python-only - libpq autocommit means cascade never happens on PHP/Ruby/Node) |  |  |  |
| BooleanField DDL | ✓ fixed | N/A (PHP createTable is migration-driven) | ✓ fixed | ✓ already engine-aware |

### Tests

- Python: 2,807 passed, 31 skipped (+34 new)
- PHP: 2,888 passed (no changes)
- Ruby: 2,962 passed, 7 pending (+10 new)
- Node: 3,596 passed across 94 files (+10 new)

**12,253 tests across the family, +54 new for v3.13.11, zero regressions.**

---

## v3.13.10 (2026-06-11) - Python only

Three Python-only housekeeping items.

### 1. Google Antigravity removed from `AI_TOOLS` - it reads `AGENTS.md`, not `.antigravity/context.md`

Per Google's official Antigravity docs ([rules-workflows](https://antigravity.google/docs/rules-workflows)), as of Antigravity **v1.20.3 (March 2026)** the IDE reads `AGENTS.md` from the repo root - the same cross-tool standard Codex pioneered, Cursor adopted, and Claude Code reads as a fallback. Our pre-v3.13.10 installer wrote to `.antigravity/context.md`, **a path nothing actually reads.** Antigravity has been silently producing dead files in users' projects since the entry was added in commit `04fba18`.

The fix in v3.13.10 is simply to **remove the antigravity entry from `AI_TOOLS`**. The existing `codex` entry (`AGENTS.md`) already writes the Tina4 skill block to the file Antigravity actually consumes - one file, four tools (Codex + Cursor + Claude Code + Antigravity all read it).

If you want Antigravity-specific tuning beyond the shared `AGENTS.md`, write it to `.agents/rules/tina4.md` by hand - that's the documented per-workspace rules folder.

### 2. `uv.lock` drift caught

The lockfile had quietly fallen out of sync - it tracked `tina4-python` at `3.13.8` while `pyproject.toml` was at `3.13.9`. The mistake was on my side: I didn't re-stage `uv.lock` on the v3.13.7 / v3.13.8 / v3.13.9 commits, and `uv` only regenerates it lazily. **Cosmetic only** (the PyPI artefact was always built from `pyproject.toml`, so the published packages were correct), but the lockfile would have drifted further every release. Now refreshed to `3.13.10` and committed.

### 3. `.gitignore` for runtime broken-route artefacts

`Tina4::BrokenTracker` writes import-time and route-time failure dumps to `data/.broken/` and `data/broken/` at the project root. The pre-v3.13.10 `.gitignore` only covered `/broken` (older convention) and the `example/store/` paths. The newer `data/`-rooted paths weren't ignored, so test runs that intentionally threw (the `tina4.request.error` tests in v3.13.7) were leaving untracked `.broken` files lying around in the framework's own repo.

Now ignored:
```gitignore
/data/broken/
/data/.broken/
```

### Why Python-only

All three items are Python-specific. PHP/Ruby/Node never had the Antigravity entry, don't use uv, and have their own gitignore conventions covered separately.

### Tests

- `tests/test_ai.py::TestAITools::test_antigravity_is_handled_via_codex_entry` - new test that asserts (a) Antigravity is NOT a separate `AI_TOOLS` entry, (b) the Codex entry's `context_file` remains `AGENTS.md`. Keeps the design intent visible so nobody reintroduces a dedicated Antigravity entry without checking the docs.
- Existing `test_tools_count_matches_known_set` updated from 8 → 7.

2,773 passed, 47 skipped - no regressions.

---

## v3.13.9 (2026-06-10)

Non-destructive AI installer across all four frameworks.

### The bug

Pre-v3.13.9 the installer wrote a full developer guide to `CLAUDE.md` (and the equivalent context files for Cursor / Copilot / Windsurf / Aider / Cline / Codex / Antigravity) on every run, clobbering whatever the user had put there. If a user kept project-specific notes in `CLAUDE.md` - branch naming, deploy URLs, "don't touch this", reminders about a flaky service - re-running `install_context()` wiped all of that.

### The fix

The installer now uses a **marker-bracketed skill block**:

```markdown
<!-- tina4-skills:start -->
## Tina4 Skills

When working on this Tina4 project, these skills give the assistant project-aware behaviour:

- **tina4-developer** - Read `.claude/skills/tina4-developer/SKILL.md` before building features.
- **tina4-js** - Read `.claude/skills/tina4-js/SKILL.md` for frontend work.
- **tina4-maintainer** - Read `.claude/skills/tina4-maintainer/SKILL.md` for framework-level changes.

See https://tina4.com for full docs.
<!-- tina4-skills:end -->
```

Four behaviours:

1. **Fresh install** - file doesn't exist → write the framework guide plus the skill block.
2. **Marker refresh** - file exists with our markers → replace just the bracketed block. **Idempotent**: re-running the installer keeps the skill references current as new skills are added.
3. **One-time migration** - file starts with the pre-v3.13.9 framework header (`# Tina4 Python - Developer Guidelines`, `# Tina4 PHP`, `# Tina4 Ruby`, `# CLAUDE.md - AI Developer Guide for tina4-nodejs`) → replace the old dump with the new framework guide + skill block.
4. **Preserve user content** - file exists with the user's own content (no markers, no old header) → append the skill block to the end. Everything else is preserved verbatim.

Markdown files (`CLAUDE.md`, `.github/copilot-instructions.md`, `CONVENTIONS.md`, `AGENTS.md`, `.antigravity/context.md`) get HTML-comment markers (`<!-- ... -->`). Rule files (`.cursorules`, `.windsurfrules`, `.clinerules`) get `#`-prefixed markers so rule loaders treat them as comments.

The actual skill content lives in `.claude/skills/tina4-*/SKILL.md` - those are framework-owned and still get cleanly overwritten so re-runs upgrade the skill content. `CLAUDE.md` itself becomes a thin pointer, not a re-rendered guide.

### Cross-framework parity

Same algorithm, same marker syntax, same four branches in Python, PHP, Ruby, and Node. Same canonical action verbs in the log output (`Installed` / `Refreshed skill block in` / `Migrated (replaced old framework dump in)` / `Appended skill block to`).

### Tests

99 new tests across the family covering all four branches plus marker detection, block replacement, idempotency, old-header detection, encoding edge cases, and rule-file vs markdown-file behaviour.

- Python: 2,772 passed, 47 skipped (24 new)
- PHP: 2,888 passed (11 new - verified via reflection so private helpers stay private)
- Ruby: 2,952 passed, 7 pending (18 new)
- Node: 3,586 passed across 93 files (46 assertions new)

### What you'll see when you re-install

Existing users running the installer for the first time after upgrading will hit branch 3 - they'll see this in the output:

```
✓ Migrated (replaced old framework dump in) CLAUDE.md
```

On any subsequent run, branch 2 kicks in:

```
✓ Refreshed skill block in CLAUDE.md
```

Users who curated their own `CLAUDE.md` and never ran the old installer will see branch 4:

```
✓ Appended skill block to CLAUDE.md
```

---

## v3.13.8 (2026-06-10) - Python only

Follow-on for issue [#46](https://github.com/tina4stack/tina4-python/issues/46). Schalk on the 24rent team upgraded to v3.13.7 and still hit the cascade message on the FIRST query of a function - meaning the PostgreSQL connection had been poisoned **before** the wrapper saw any failure.

### The gap in v3.13.6 / v3.13.7

v3.13.6 added auto-rollback **inside** `_on_query_error` - that clears the abort *on* a failure the framework's wrapper catches. But the connection can still arrive poisoned from sources the wrapper never observed:

- A boot-time query that failed before request handling started (migration probe, ORM `information_schema` lookup, etc.)
- A failure inside an explicit transaction where the user owned the rollback but never issued one
- A direct `cursor.execute` call in another adapter method (the `SELECT lastval()` SAVEPOINT probe in `execute`) that managed to leave the txn dirty

In all three cases, the *next* `db.fetch` / `db.execute` - even one routed through the wrapper - hits `InFailedSqlTransaction` immediately, and the cascade message buries whatever the original cause was. Exactly what Schalk reported:

```
[ERROR] PostgreSQL query failed: InFailedSqlTransaction: current transaction is aborted, commands ignored until end of transaction block
{"sql": "SELECT * FROM gift_cards.gift_card WHERE created_by_email = %s AND is_deleted = 0 LIMIT %s OFFSET %s"}
```

### The fix: pre-flight heal

`_exec_with_handling` and `fetch` now call `_heal_aborted_txn()` before executing. That checks the psycopg2 connection's `transaction_status` against `TRANSACTION_STATUS_INERROR` and rolls back if poisoned:

```python
def _heal_aborted_txn(self):
    if self._in_transaction or self._conn is None:
        return
    import psycopg2.extensions as _ext
    if self._conn.info.transaction_status != _ext.TRANSACTION_STATUS_INERROR:
        return
    self._conn.rollback()
    Log.warning(
        "PostgreSQL connection arrived in aborted-transaction state - "
        "issued pre-flight ROLLBACK so the next query starts clean. "
        "Look back in the log for the original PostgreSQL query failed entry."
    )
```

- **Only fires outside an explicit transaction** - same rule as the failure-time auto-rollback. Callers running SAVEPOINT/retry stay in charge.
- **Logs a warning when it triggers** so the operator can correlate against the upstream failure.
- **Defensive**: even if a code path bypasses the wrapper entirely, the next path that does *use* the wrapper heals the connection on the way in.

### Cross-framework

Python only. PHP `pg_query`, Ruby `pg`, and Node `node-postgres` use libpq autocommit by default - each statement is its own transaction, so the cascade never happens there.

### Tests

3 new tests in `tests/test_postgres_error_visibility.py::TestPoisonedConnectionIsHealed`:
- `test_fetch_heals_poisoned_connection` - manually poison the connection with a raw `cursor.execute`, then verify `db.fetch` succeeds
- `test_execute_heals_poisoned_connection` - same for `db.execute`
- `test_explicit_transaction_skips_heal` - confirms the heal defers when the user owns the txn

2,764 passing, 31 skipped (skipped tests require PG container; verified against `postgres:16-alpine` on `localhost:55432`).

---

## v3.13.7 (2026-06-10)

Two changes from an external app-platform team (24rent, PLATFORM-2159) - one observability hook, one production-safety fix. Both ship across **all four frameworks** with identical event payload shape.

### NEW: `tina4.request.error` event

When the router catches a thrown exception, it now emits `tina4.request.error` **before** rendering the 500 page. Listeners receive `{exception, request}` and can ship the failure to CloudWatch / Sentry / Slack - even though the framework caught the throwable.

```python
from tina4_python.core.events import on
from tina4_python.debug import Log

@on("tina4.request.error")
def report_to_observability(payload):
    exc = payload["exception"]
    req = payload["request"]
    Log.error(f"Route error: {type(exc).__name__}: {exc}", path=req.path)
    # ...or POST to your centralised logging pipeline
```

- **Fires for caught route exceptions** (and warnings escalated to exceptions). Does NOT fire for 404s - those aren't server errors.
- **Listener errors are swallowed + logged via `Log.warning`** so a broken listener can never break the 500 render.
- **Listeners fire in priority order** (higher priority first, matching the existing `@on(event, priority=N)` contract).
- **Same payload shape in every framework** - only the calling syntax differs:

```php
// PHP
Events::on('tina4.request.error', function ($payload) {
    Log::error('Route error: ' . $payload['exception']->getMessage());
});
```

```ruby
# Ruby
Tina4::Events.on("tina4.request.error") do |payload|
  Tina4::Log.error("Route error: #{payload[:exception].message}")
end
```

```typescript
// Node.js
import { Events, Log } from "@tina4/core";
Events.on("tina4.request.error", (payload) => {
  Log.error(`Route error: ${(payload as any).exception.message}`);
});
```

### FIX: Stack trace removed from production 500 body (CWE-209)

Before v3.13.7, an unhandled route exception would render the **full stack trace** into the HTTP 500 response body - file paths, function chain, the exception message - **regardless of `TINA4_DEBUG`**. That's [CWE-209 / OWASP A05](https://cwe.mitre.org/data/definitions/209.html): information disclosure.

<div v-pre>

The framework's own `500.twig` now guards the trace block with `{% if error_message %}`. When `TINA4_DEBUG=false`, callers pass an empty `error_message` and the trace block doesn't render. The trace stays in `Log.error` (server-side) and reaches observability via the new event.

</div>

When `TINA4_DEBUG=true`, the rich `ErrorOverlay` page is unchanged.

### Tests

Each framework added 6-14 regression tests covering: event payload shape, dev/prod symmetry, listener priority ordering, listener-error safety, and CWE-209 (no trace markers in the prod body).

- Python: 2,748 passed, 44 skipped
- PHP: 2,877 passed
- Ruby: 2,934 passed, 7 pending (PG container)
- Node: 3,540 passed across 92 files

### Background

Reported by DevProx on the 24rent platform - they centralise observability by scraping structured JSON lines from stderr → CloudWatch → a Slack notifier. Route-level exceptions weren't surfacing because the framework caught them silently. The event hook fixes that without forcing any team's logging convention; the trace-leak fix is independently a security concern.

---

## v3.13.6 (2026-06-09)

Two small reliability fixes - both tracked across all four frameworks.

### PostgreSQL transaction errors no longer cascade (#46)

A failed PostgreSQL query outside an explicit transaction used to leave the connection in an aborted state. Every subsequent query then failed with `current transaction is aborted, commands ignored until end of transaction block`, masking the original cause and making the bug effectively invisible to operators.

The fix wraps every PostgreSQL `cursor.execute` in error-aware machinery:

```python
# Bad query
try:
    db.execute("SELECT * FROM table_that_does_not_exist")
except Exception:
    pass

# Before v3.13.6: this raised InFailedSqlTransaction
# v3.13.6 onward: succeeds - the framework auto-rolled back
result = db.fetch("SELECT 1 AS one")
assert result.records[0]["one"] == 1

# The original error is still visible:
db.last_error  # → 'relation "table_that_does_not_exist" does not exist'
```

The framework now:
1. Logs the original failure via `Log.error` with the SQL and params.
2. Stores the message on `db.last_error` so observability tools can read it.
3. Auto-rollbacks **only** when the caller is not inside an explicit transaction - explicit transactions are left to the user (so SAVEPOINT / retry patterns still work).

Cross-framework note: this cascade behaviour is psycopg2-specific (DB-API 2.0 mandates an implicit transaction on first statement). PHP `pg_query`, Ruby `pg` gem, and Node `node-postgres` all run in libpq autocommit by default - no cascade, no fix needed.

### Better driver install hints (#47)

Missing-driver `ImportError` messages now suggest a `uv add` command alongside `pip install`:

```
psycopg2 is required for PostgreSQL connections. Install one of:
    uv add tina4-python[postgres]   # extra for projects using uv
    pip install psycopg2-binary    # bare driver
    uv add tina4-python[all-db]    # all five database drivers
```

Applies to the PostgreSQL, MySQL, MSSQL, Firebird, ODBC, and MongoDB drivers, plus the MongoDB queue backend.

### Tests

2,741 passing, 44 skipped (Postgres / MySQL / MongoDB containers).

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

- **breaking:** `auto_map` now defaults to `True` - ORM models automatically map between camelCase properties and snake_case DB columns. Set `auto_map = False` on your model to restore the old behaviour.
- **feat:** `to_dict(case=)` parameter - pass `case='camel'` to get camelCase keys (for JSON APIs) or `case='snake'` (default) for snake_case keys matching DB columns.
<div v-pre>

- **feat:** Frond `replace` filter now accepts dict args - `{{ v|replace({"T": " ", "-": "/"}) }}` for multiple substitutions in one call.
- **feat:** `background(callback, interval)` - register periodic tasks that run cooperatively in the asyncio event loop. Replaces `threading.Thread` for background work.
- **feat:** Background task protection - sync callbacks run in a `ThreadPoolExecutor` via `run_in_executor()` with `asyncio.wait_for()` timeout, preventing blocking functions from freezing the server.
- **feat:** Docker image now bundles the example store demo - `docker run tina4stack/tina4-python:v3` starts a working app out of the box.
- **fix:** Cart nav badge now updates reactively on quantity change and item removal (tina4-js `signal`/`computed`/`effect`).
- **fix:** Non-blocking queue consumer - `process_orders()` uses `queue.pop()` (single job per tick) instead of blocking `queue.consume()`.
- **tests:** 6 new parity tests covering `to_dict(case=)`, `auto_map` default, `replace` filter (dict + positional), and `background()` registration.
- **parity:** All features shipped identically across Python, PHP, Ruby, Node.js. 2,304 tests passing.

</div>

## v3.10.97 (2026-04-11)

- **fix:** frond.form.submit redirect handling - XHR transparently follows 3xx redirects, so the callback received redirected HTML instead of navigating. Fixed by comparing `xhr.responseURL` with the original URL and calling `window.location.href` when a redirect is detected.
- **fix:** Currency placeholder - locale files now default to `$` for the currency symbol.
- **fix:** Admin sidebar alignment - widened sidebar to 220px with `min-width` to prevent label truncation.
- **fix:** Admin table overflow - added `min-width: 0` and `overflow-x: auto` on `.admin-main` to prevent content clipping.
- **fix:** Order detail template - corrected variable names (`items` instead of `order.items`, `item.name` instead of `item.product_name`) and used `.records` from `DatabaseResult`.
- **fix:** Status badges - dashboard recent orders and order list now show colored badge pills with translated status labels (pending, processing, shipped, delivered, cancelled).
- **fix:** Date formatting - admin order/dashboard dates trimmed to `YYYY-MM-DD HH:MM:SS` instead of raw ISO with microseconds.
- **feat:** Cart quantity spinner - reactive qty controls using tina4-js signals, computed values, and effects.
- **feat:** Multi-currency pricing - forex conversion via Api client (frankfurter.app), `|currency` template filter, currency selector in navbar.
- **feat:** MCP server tools - `check_stock`, `low_stock_report`, `search_products` tools and `store://categories`, `store://inventory-summary` resources for AI assistant integration.
- **feat:** Contact form - built with `HtmlElement` and `add_html_helpers()` to demonstrate programmatic HTML generation.
- **feat:** ORM named scopes - `Product.scope("active")`, `Product.scope("low_stock")`, `Product.scope("expensive")`.
- **feat:** Database connection pooling - `Database("sqlite:data/store.db", pool=4)`.
- **feat:** Inline tests - `@tests` decorators on `cart_service.py` and `forex_service.py`.
- **feat:** Language toggle - flag button (🇫🇷/🇬🇧) in navbar to switch locale.
- **feat:** Helpdesk chat persistence - chat messages stored in DB, history API (`GET /api/chat/history`).
- **dep:** Updated frond.min.js to v2.1.2 across all 4 frameworks (Python, PHP, Ruby, Node.js).
- **parity:** All 4 frameworks bumped to 3.10.97.

## v3.10.93 (2026-04-11)

<div v-pre>

- **fix:** Frond array/dict literal support - `{% set items = ["a", "b"] %}` and `{% set obj = {"k": "v"} %}` now parse correctly.
- **fix:** Frond bracket depth tracking in `_find_outside_quotes()` and `_split_outside_quotes()` - expressions like `arr[i % 2]` no longer treated as top-level arithmetic.
- **fix:** Frond subscript expression evaluation - bracket content uses `_eval_expr()` instead of `_resolve()`, enabling `arr[loop.index0 % 2]`.
- **fix:** Frond slice with variable bounds - `items[start:end]` evaluates bounds through `_eval_expr()`.
- **fix:** Frond multiline `{% set %}` - `_SET_RE` regex now uses `re.DOTALL` flag.
- **docs:** Developer skills updated - Metrics Dashboard guidance, Frond Template Parity rules, `@noauth` security warnings.
- **demo:** Complete e-commerce store example (`example/store/`) with GraphQL search, SSE, WebSocket, Queue, Events, 13 test files.
- **parity:** All Frond fixes applied identically across Python, PHP, Ruby, Node.js. 2,304 tests passing.

</div>

## v3.10.92 (2026-04-10)

- **refactor:** Extract `RateLimiter` from `core/middleware.py` into its own file `core/rate_limiter.py`. The old import path still works via re-export.
- **feat:** Add `RateLimiterMiddleware` wrapper class with `before_rate_limit()` and `check()` static methods.
- **breaking:** Rename `ErrorOverlay` methods - `render()` → `render_error_overlay()`, `render_production()` → `render_production_error()`, `debug_mode()` → `is_debug_mode()`.
- **feat:** Add `Server.start()` and `Server.stop()` for cross-framework parity.
- **feat:** Add `DatabaseResult.size()`, `to_array()`, `to_json()`, `to_csv()` methods.
- **feat:** Add `ScssCompiler` class with `compile()`, `compile_file()`, `add_import_path()`, `set_variable()`.
- **feat:** Add `DevAdmin.unresolved_count()`, `clear_all()`, `reset()`, `capture()` (5-param), `register()`.
- **fix:** GraphQL test API - update `add_query()` calls to use positional args (args, return_type, resolver).
- **parity:** 44/44 cross-framework features green. 2,263 tests passing.

## v3.10.91 (2026-04-10)

- **feat:** Add parity methods - `GraphQLType.parse()`, `Response.send()` params, `QueryBuilder.from_()`, `Debug.configure()`.
- **breaking:** Remove alias methods `from_`, `configure`, `template` - use canonical names only (`from_table`, etc.).

## v3.10.90 (2026-04-09)

<div v-pre>

- **docs:** Chapter 4 (Templates) - new "Dumping Values for Debugging" section covering both `{{ x|dump }}` and `{{ dump(x) }}` forms, their shared `<pre>`-wrapped output, and the `TINA4_DEBUG=true` production gate. Filter table entry updated to reference the new section.
- **docs:** `plan/parity/parity-template.md` updated with a cross-framework dump helper comparison table and marks dump parity as confirmed across all 4 frameworks at v3.10.89.
- **chore:** Version sync release - brings all 4 frameworks to the same patch version (3.10.90) so downstream users can upgrade PHP/Python/Ruby/Node.js in lockstep without hunting version mismatches.

</div>

## v3.10.89 (2026-04-09)

<div v-pre>

- **feat:** `{{ dump(value) }}` global function form added to Frond alongside the existing `{{ value|dump }}` filter. Both call a single `_render_dump()` helper and produce identical output.
- **security:** Dump is now **gated on `TINA4_DEBUG=true`**. In production (env var unset or `false`) both the filter and function silently return an empty string. This prevents accidental leaks of internal state, object shapes, and sensitive values into rendered HTML when a developer leaves a `{{ dump(x) }}` call in a template.
- **refactor:** Dump output is wrapped in `<pre>` and HTML-escaped via a single shared code path.
- **test:** 6 new tests in `test_frond.py` (`TestDump`) covering debug-mode output, production silencing, unset-env default-to-production, function/filter parity, and circular references.

</div>

## v3.10.86 (2026-04-09)

- **feat:** `ForeignKeyField` is now a proper `Field` subclass that auto-wires both sides of the relationship. Declaring `author_id = ForeignKeyField(to=Author)` injects `belongs_to` on the declaring model and `has_many` on the referenced model via `ORMMeta` - no manual descriptor calls required. Override the has-many name with `related_name=`.
- **feat:** Cross-framework parity - same FK auto-wiring semantics now available in PHP (`$foreignKeys`), Ruby (`foreign_key_field`), and Node.js (`type: "foreignKey"`)
- **fix:** `@orm_bind(db)` no longer nulls the decorated class - returns a pass-through decorator
- **fix:** `Auth.get_token`/`valid_token`/`get_payload`/`refresh_token`/`authenticate_request` can now be called on the class (e.g. `Auth.get_token(payload)`) or on an instance via the `_DualMethod` descriptor
- **fix:** `SQLiteAdapter` uses a class-level `threading.Lock` + `PRAGMA busy_timeout = 30000` + `timeout=30` on connect to eliminate `SQLITE_BUSY` deadlocks in the dev server under concurrent writes
- **docs:** Chapter 6 (ORM) updated with a new "ForeignKeyField - Auto-Wired Relationships" section

## v3.10.85 (2026-04-09)

- **refactor:** Split queue adapters into separate files - `queue/rabbitmq_backend.py`, `queue/kafka_backend.py`, `queue/mongo_backend.py` (one class per file, aligning with PHP/Node/Ruby architecture)
- **fix:** Updated remaining tests to use bool `valid_token()` + `get_payload()` pattern

## v3.10.84 (2026-04-09)

- **fix:** Router/middleware was setting `request.user` / `request.auth` / auth payload to `true` (boolean) instead of the actual JWT payload dict after `validToken()` was changed to return bool - any code reading `request.user["sub"]` etc. would have failed silently or crashed
- **fix:** CSRF middleware was not correctly rejecting invalid tokens (nil check on bool result always passed)
- **fix:** `AuthMiddleware.before_request` called `get_payload` incorrectly - would TypeError at runtime on valid token
- **add:** Headless routing auth payload integration tests to prevent regression

## v3.10.83 (2026-04-08)

- **fix:** prevent orphaned session files on WebSocket and anonymous requests (#36)
- **feat:** WebSocket rooms - `join_room`, `leave_room`, `broadcast_to_room`, `room_count`, `get_room_connections`
- **feat:** queue signature parity - instance-scoped `push`/`pop`/`retry`, no topic params on public methods

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


## Version History

Tina4 Python follows semantic versioning. The major version (3) marks the ground-up rewrite from v2. Minor versions (3.1, 3.2, ...) introduce features. Patch versions fix bugs and polish edges.

Every release ships through PyPI. Upgrade with:

```bash
uv add tina4-python@latest

# or with pip

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

pip install --upgrade tina4-python
```

Check your current version:

```python
import tina4_python
print(tina4_python.__version__)
```

---

## v3.10.68 (2026-04-03) - Full Parity Release
- **100% API parity** across Python, PHP, Ruby, Node.js - 30+ issues fixed
- **ORM:** save() returns self/false, all/select/where return arrays, toDict/toAssoc standardized, scope() registers reusable method, where()/all() on Node, count() on PHP
- **Auth:** expires_in in minutes, PBKDF2 260k iterations, env TINA4_SECRET fallback, API key fallback in authenticateRequest
- **Session:** dual-mode flash(), get_flash/getFlash, cookieHeader on all, getSessionId on Node, save() public on Node
- **Database:** execute() returns bool/DatabaseResult for RETURNING, get_last_id/get_error on all, getColumns on PHP, cacheStats on Node
- **Request/Response:** Node files as dict, Python query property, cookies on PHP/Node, contentType on Node, xml() on PHP/Node, Ruby callable response
- **Queue:** consume() poll_interval (long-running generator with built-in sleep)
- **WebSocket:** event naming standardized (open/message/close/error), connection ip/headers/params, Python on() string API
- **GraphQL:** schema_sdl()/schemaSdl() and introspect() on all 4
- **WSDL:** Node.js zero-dep DOM parser (replaced regex)
- **Events:** emitAsync()/emit_async() on all 4
- **i18n:** zero-dep YAML locale file support on Python/PHP/Node (Ruby already had it)

## v3.10.67 (2026-04-03)
- **BREAKING: request.files content is now raw bytes** - previously base64-encoded; remove any `base64.b64decode()` calls when saving uploaded files. Write `file["content"]` directly to disk
- **load() is now an instance method** - `model.load(sql, params)` calls selectOne internally, populates the instance, returns `True`/`False`. Use `Model.find(id)` for PK lookups
- **api.upload()** added to tina4-js - sends FormData with Bearer token auth for multipart file uploads
- **ORM CLAUDE.md rewrite** - all method stubs now match actual API signatures
- **tina4-js skill** - critical input binding warning, routing docs (`{param}` not `:param`), file upload pattern

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
- **tina4 console** - interactive Python REPL with framework loaded (db, Router, ORM, Auth, Api, Log)
- **tina4 env** - interactive environment configuration (database, cache, session, queue, mail)
- **Brand update** - "TINA4 - The Intelligent Native Application 4ramework"
- **Quick reference** - 36 sections covering every framework feature
- **Chapter reshuffle** - 37 chapters, 7 new (Events, Localization, Logging, API Client, WSDL/SOAP, DI Container, Service Runner)
- **RouteGroup fix** - double prefix bug resolved
- **Port kill-and-take-over** - default port always reclaimed on startup
- **Metrics test detection** - expanded to check spec/, tests/, test/ directories
- **MongoDB adapter** (pymongo), **ODBC adapter** (pyodbc)
- **Pagination standardized** - limit/offset primary, merged dual-key response
- **9,138 tests** across all 4 frameworks

---

## v3.10.57 (2026-04-02)
- **MongoDB adapter** - `Database("mongodb://host:port/db")`, requires `pip install pymongo`
- **ODBC adapter** - parity with PHP/Ruby/Node
- **RouteGroup class** - `group.get()`/`group.post()` syntax matching PHP/Ruby/Node
- **Pagination standardized** - limit/offset primary, merged dual-key toPaginate() response
- **Test port at +1000** - user testing port (e.g. 8145) stable, no hot-reload
- **Dynamic version** - `__version__` read at runtime, no hardcoded constants
- **ORM TINA4_DATABASE_URL discovery** - auto-connect from env
- **Firebird path parsing** - preserves absolute paths
- **108 features at 100% parity**, 2,112 tests

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** - second listener on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **Firebird path parsing** - preserve absolute paths
- **ORM TINA4_DATABASE_URL discovery** - auto-connect from env
- **SQLite transaction safety** - commit() no-op without transaction
- **QueryBuilder docs** - added to ORM chapter

---

## v3.10.48 - April 2, 2026

### Bug Fixes

**Production server explicit opt-in** - All frameworks now require an explicit `--production` flag to use production servers (Puma for Ruby, FrankenPHP for PHP, cluster mode for Node.js). Previously, production servers activated automatically when `TINA4_DEBUG=false`, which was surprising behaviour. Now `tina4 serve` always uses the dev server unless `--production` is passed.

**Python `--no-browser`** - The `run()` function now accepts `no_browser=True` and respects the `TINA4_NO_BROWSER` env var to prevent browser auto-opening on server start.

### Test Coverage

Python: 2,132. PHP: 1,992. Ruby: 2,387. Node.js: 2,546. Total: 9,057 tests, 0 failures.

---

## v3.10.46 - April 1, 2026

### Test Coverage

Massive test parity push across all 4 frameworks. CSRF middleware tests expanded to 29+ per framework. Dedicated test suites added for FakeData, Cache, DevMailbox, Static files, Metrics, CLI scaffolding, and all remaining gap areas. Python: 2,132 tests. PHP: 1,937. Ruby: 2,274. Node.js: 2,546. Total: 8,889 tests, 0 failures, 49 core areas with full parity.

---

## v3.10.45 - April 1, 2026

### Bug Fixes

**PHP CLI serve hijack** - When `index.php` calls `App::run()`, the CLI `serve` command now sets a `TINA4_CLI_SERVE` constant so `run()` returns early, letting the CLI manage the server lifecycle (port, debug mode, browser open). Previously, `index.php`'s `run()` would start its own server and block the CLI's serve logic.

---

## v3.10.44 - April 1, 2026

### New Features

**Database tab redesign** - The dev admin Database panel now uses a split-screen layout. Tables are listed on the left as a navigation sidebar with click-to-select highlighting. The query editor, toolbar, and results occupy the right panel. Results render immediately below the query box with no gap.

**Copy CSV / Copy JSON** - Two new buttons in the database toolbar copy query results to the clipboard. CSV uses proper comma-separated format with quoting; JSON copies a formatted array of objects.

**Paste data** - A new Paste button opens a modal where you can paste JSON arrays or CSV/tab-separated data. The tool auto-detects the format and generates INSERT statements. If a table is selected on the left, it targets that table. If no table is selected, it prompts for a name and generates a CREATE TABLE statement for new tables. If you paste SQL directly, it passes through to the query box unchanged.

**Multi-statement execution** - The query runner now handles multiple SQL statements separated by semicolons. CREATE TABLE + INSERT batches run in a single transaction with automatic rollback on error.

**Database badge on load** - The Database tab count badge now shows the table count immediately when the dev admin opens, without needing to click the tab first.

**Star wiggle animation** - The GitHub star button on the landing page uses an empty star (☆) with a playful wiggle animation: 3-second delay on page load, then wiggles at random 3-18 second intervals.

### Bug Fixes

**Default port** - Python default port changed from 7145 to 7146 to avoid clashes when running multiple Tina4 frameworks (PHP=7145, Python=7146, Ruby=7147, Node=7148).

**SQLite LIMIT fix** - The SQLite adapter now checks if a query already contains a LIMIT clause before appending one, preventing double-LIMIT errors in the database browser.

**browseTable quote escaping** - Fixed broken onclick handlers for table names in the database panel. Now uses `addEventListener` instead of inline onclick with escaped quotes.

**Migration UP/DOWN separation** - Migration generator no longer puts DOWN SQL in the .sql file. UP SQL stays in the .sql file; DOWN SQL goes in the separate .down.sql file.

### Test Coverage

Major test expansion across all 4 frameworks - 8,107 total tests (up from ~5,200), with full parity across 49 core feature areas. New dedicated test suites added for FakeData, Cache, DevMailbox, Static files, Metrics, and CLI scaffolding.

Python: 2,132 tests passing (12 skipped).

---

## v3.10.40 - April 1, 2026

### Bug Fixes

**Dev overlay version check** - Fixed misleading "You are up to date" message when running a version ahead of what's published on PyPI (e.g. running v3.10.39 locally while PyPI still has v3.10.24). The overlay now shows a purple "ahead of PyPI" message. Also added a breaking changes warning (red banner with changelog link) when a major or minor version update is available, so developers know to check for breaking changes before upgrading.

---

## v3.10.39 - April 1, 2026

### Breaking Changes

This release aligns the Python framework with the other three Tina4 implementations. Two breaking changes affect existing code:

**`Auth.check_password()` parameter order reversed**

```python
# BEFORE (v3.10.38 and earlier)

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Auth.check_password(hashed, password)

# AFTER (v3.10.39+)

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Auth.check_password(password, hashed)  # password first - matches PHP, Ruby, Node.js
```

**`Router.all()` removed - use `get_routes()` or `list_routes()`**

```python
# BEFORE

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

routes = Router.all()

# AFTER

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

routes = Router.get_routes()   # or Router.list_routes()
```

### New Features

**`Auth.validate_api_key(provided, expected=None)`**

Compare API keys with constant-time comparison. Optionally pass `expected`; if omitted, reads `TINA4_API_KEY` (or `TINA4_API_KEY`) from environment.

```python
Auth.validate_api_key("sk-abc123")              # check against env
Auth.validate_api_key("sk-abc123", "sk-abc123") # check against explicit value
```

**`Auth.authenticate_request(headers)`**

One-call header authentication: checks Bearer JWT, Bearer API key, and Basic auth in order.

```python
payload = Auth.authenticate_request(request.headers)
# Returns: dict on success, None on failure

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

**`ORM.find_by_id(pk)` with `find()` and `load()` as aliases**

`find_by_id()` is now the explicit primary method. Both `find()` and `load()` continue to work as aliases, ensuring backward compatibility.

### Test Coverage

2,054 tests passing (up from 2,051 in v3.10.38).

---

## v3.10.38 - April 1, 2026

### Code Metrics & Bubble Chart

The dev dashboard (`/__dev`) now includes a **Code Metrics** tab with a PHPMetrics-style bubble chart visualization. Files are represented as animated bubbles - sized by lines of code, colored by maintainability index (green = healthy, red = needs attention). Click any bubble to drill down into per-function cyclomatic complexity.

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

## v3.10.x - Previous Releases (March 28-31, 2026)

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

<div v-pre>

- **Arithmetic in `{% set %}` and expressions** (v3.10.31). The template engine handles math operations inside assignment blocks.

</div>

```html
{% set total = price * quantity + shipping %}
```

### Bug Fixes

**Middleware not applied to routes (fixed in v3.10.1).** Middleware functions registered with `@middleware` were silently skipped during route dispatch. Routes ran without their middleware.

```python
# Before (broken) - middleware was silently skipped

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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
# After (fixed in v3.10.1) - middleware runs on every matching route

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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
<!-- Before (broken) - raised KeyError -->
{% set key = "name" %}
{{ user[key] }}

<!-- After (fixed in v3.10.11) - resolves variable, then looks up the key -->
{% set key = "name" %}
{{ user[key] }}  <!-- now outputs user["name"] -->
```

**ORM transaction errors on SQLite (fixed in v3.10.25).** Calling `save()` or `delete()` on an ORM model raised `"cannot commit -- no transaction is active"` on SQLite. The ORM now wraps every write operation in a proper `start_transaction` / `commit` / `rollback` cycle.

```python
# Before (broken on SQLite)

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

user = User()
user.name = "Alice"
user.save()  # raised "cannot commit -- no transaction is active"

# After (fixed in v3.10.25) - save() wraps in a transaction automatically

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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
# Before (broken) - decorator had no effect

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/public")
@noauth
def public_page(response):
    return response("Open to all")  # still required auth

# After (fixed in v3.10.1) - decorator works as expected

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/public")
@noauth
def public_page(response):
    return response("Open to all")  # accessible without token
```

---

## v3.9.x - QueryBuilder and Sessions (March 26-27, 2026)

### Features

**QueryBuilder with fluent API (v3.9.0).** SQL construction through method chaining, integrated with the ORM.

```python
from tina4_python import ORM

class User(ORM):
    table_name = "users"

# Fluent query through the ORM

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

admins = User.query() \
    .where("role = ?", ["admin"]) \
    .order_by("name") \
    .limit(10) \
    .get()

# Standalone query

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/users/{id}")
def get_user(request, response):
    user_id = request.params["id"]
    return response(f"User {user_id}")

# v3.9.0 and later

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

**CSRF middleware and form tokens (v3.9.1).** Session-bound CSRF tokens protect forms by default. Toggle with the `TINA4_CSRF` environment variable.

```python
# CSRF is on by default in v3.9.1+

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# Disable for API-only apps:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# TINA4_CSRF=false

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

**WebSocket backplane (v3.9.2).** Redis pub/sub for scaling WebSocket broadcast across multiple server instances.

**SameSite cookie default (v3.9.2).** Session cookies default to `SameSite=Lax`. Override with the `TINA4_SESSION_SAMESITE` environment variable.

### Breaking Changes

**Session API rename (v3.9.0).** The `unset()` method became `delete()` for cross-framework parity. `unset()` still works as an alias but will show a deprecation warning in future releases.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

request.session.unset("cart")

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

request.session.delete("cart")
```

**Environment variable standardization (v3.9.1).** All framework environment variables now follow the `TINA4_*` naming convention. `TOKEN_LIMIT` became `TINA4_TOKEN_LIMIT`. Check your `.env` file and rename any bare variables.

**Queue backend change (v3.9.1).** The SQLite queue backend no longer exists. If you used it, the file-based backend is a drop-in replacement. Queue data from the old SQLite store must be migrated manually.

---

## v3.8.x - Pooling, Validation, and Security (March 25-26, 2026)

### Features

**Connection pooling (v3.8.1).** Pass `pool=N` to the `Database` constructor for round-robin, thread-safe connection pooling.

```python
from tina4_python import Database

db = Database("sqlite:///app.db", pool=4)
# Four connections rotate across requests

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.7.x - Template Auto-Serve and Firebird Fixes (March 25, 2026)

### Features

**Template auto-serve at `/` (v3.7.0).** Place an `index.html` or `index.twig` in `src/templates/` and the framework serves it at the root path. User-registered `GET /` routes take priority.

```
src/
  templates/
    index.html   ← served at / with no route needed
```

**Firebird idempotent migrations (v3.7.0).** `ALTER TABLE ADD` statements on Firebird check `RDB$RELATION_FIELDS` before executing. Columns that already exist are skipped. Other databases and statement types are not affected.

---

## v3.6.x - API Parity (March 24, 2026)

### Breaking Changes

**Auth method renames (v3.6.0).** The authentication API aligned with the PHP, Ruby, and Node.js implementations.

```python
# Before v3.6.0

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Auth

token = Auth.create_token(payload)       # old name
valid = Auth.validate_token(token)       # old name
```

```python
# v3.6.0 and later

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Auth

token = Auth.get_token(payload)          # new primary name
valid = Auth.valid_token(token)          # new primary name
# create_token and validate_token still work as aliases

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

**Pagination parameter rename (v3.6.0).** `skip` became `offset` across all query methods.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

users = User.find(skip=10, limit=5)

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

users = User.find(offset=10, limit=5)
```

**Token expiry parameter rename (v3.6.0).** `token_expiry` became `expires_in` and now accepts minutes instead of seconds.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

token = Auth.create_token(payload, token_expiry=3600)  # seconds

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

token = Auth.get_token(payload, expires_in=60)          # minutes
```

**Locale environment variable (v3.6.0).** `LOCALE` became `TINA4_LOCALE`. Update your `.env` file.

---

## v3.5.x - Bundled Frontend (March 24, 2026)

### Features

**tina4js bundled (v3.5.0).** The reactive frontend library (13.6 KB minified) ships with the framework. No CDN link needed. Import it from your templates and build reactive UIs with signals, components, and declarative routing.

**AutoCrud Swagger metadata (v3.5.0).** Routes generated by `AutoCrud` now include Swagger annotations. They appear in the auto-generated API docs without extra configuration.

---

## v3.3.x - WebSockets, File Uploads, and Frond Improvements (March 24, 2026)

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.consume("emails")
def send_email(job):
    to = job.data["to"]

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.consume("emails")
def send_email(job):
    to = job.payload["to"]
```

**File upload property rename (v3.3.0).** `file_name` became `filename` (no underscore). The old name is no longer available.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

name = request.files[0].file_name

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

name = request.files[0].filename
```

**Route params merged into `request.params` (v3.3.0).** Path parameters now merge into `request.params` alongside query parameters. If a query parameter shares a name with a path parameter, the path parameter wins.

---

## v3.2.x - Flexible Route Handlers and DevReload (March 24, 2026)

### Features

**Flexible handler signatures (v3.2.0).** Route handlers accept any combination of parameters. The framework inspects the signature and injects what you ask for.

```python
# No parameters - fire and forget

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/ping")
def ping():
    return "pong"

# Response only

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/hello")
def hello(response):
    return response("Hello")

# Request only (type-hinted)

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.post("/echo")
def echo(request: Request):
    return request.body

# Both

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/users")
def users(request, response):
    return response({"users": []})
```

**DevReload with SCSS compilation (v3.2.0).** The development server watches for file changes and reloads the browser. SCSS files compile on change.

**Route groups (v3.2.0).** Group routes under a shared prefix with shared middleware.

**MongoDB queue backend (v3.2.0).** Use MongoDB as a queue backend alongside the existing file-based, RabbitMQ, and Kafka options.

**Migration naming convention (v3.2.0).** Migration files follow the `YYYYMMDDHHMMSS` timestamp format. The `tina4 migrate --status` command shows which migrations have run.

**Auto-increment port (v3.2.0).** If the default port is in use, the framework picks the next available port and opens your browser.

### Breaking Changes

**Queue constructor simplified (v3.2.0).** The `db` parameter was removed from the Queue constructor. The queue reads its backend from the environment.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Queue, Database
db = Database("sqlite:///queue.db")
queue = Queue("emails", db=db)

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Queue
queue = Queue("emails")
# Backend set via TINA4_QUEUE_BACKEND env var

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

**Producer/Consumer classes removed (v3.2.0).** Use `queue.produce()` and `queue.consume()` directly.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Producer, Consumer
producer = Producer(queue)
producer.send({"to": "user@example.com"})

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

queue.produce({"to": "user@example.com"})
```

---

## v3.1.x - Benchmarks and Internal Improvements (March 22, 2026)

### Features

**Automated benchmark suite (v3.1.0).** A reproducible benchmark compares Tina4 Python against 17 frameworks across four languages. Run it yourself with `python benchmarks/run.py`.

No user-facing API changes in this release. Internal improvements to test infrastructure and benchmark tooling.

---

## v3.0.0 - The Rewrite (March 22, 2026)

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

For the full migration guide, see Chapter 36: Upgrading from v2 to v3.

---

## Release Candidate History

Five release candidates preceded the v3.0.0 stable release between March 21-22, 2026. They resolved test failures, polished the Dev Admin UI, added the benchmark suite, and stabilized the Frond template engine. If you tested a release candidate, upgrade to v3.0.0 or later. The RC builds are not supported.
