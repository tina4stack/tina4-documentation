## Highlights since 3.12.3

This stretch takes Tina4 v3 from a documentation-and-code parity build-out to a hardened, production-ready release line across all four frameworks. The work concentrates on data correctness in the ORM and database layer, a unified cache backend, a fuller queue lifecycle, live developer tooling over WebSocket and MCP, and a broad security pass over every surface that touches untrusted input. Python leads as the master and the other three frameworks mirror it, with framework-specific fixes called out where they apply.

- **Unified cache backend** - Cache configuration moves to a single `CacheBackend` covering memory, file, redis, valkey, memcached, mongodb, and database, with credential support and a file-backend fallback when a driver or service is unavailable.
- **Request-scoped query cache** - A database query cache scoped to the request is now on by default, controlled by the renamed `TINA4_AUTO_CACHING` switch, with a per-query `no_cache` opt-out and `X-Cache` headers.
- **Queue lifecycle** - Workers pop jobs in priority order, retry failed jobs on a configurable backoff, and move exhausted jobs to a dead-letter destination, with `TINA4_QUEUE_URL` env-var parity and Kafka TLS/SASL support.
- **Dev tooling over WebSocket and MCP** - The dev server pushes reloads over a WebSocket connection, the dual-port layout separates a hot-reload port from a stable AI port, and the `/__dev/mcp` endpoint lets MCP clients connect to a running project and call its tools live.
- **WebSocket and SSE backplane** - The backplane is wired for real with broadcast, SSE, an origin allow-list, idle-reaper hardening, and per-route authentication on the upgrade.
- **ORM fail-loud contracts and fixes** - Save, create, `QueryBuilder`, execute, and fetch paths now fail loud instead of swallowing errors, the silent 100-row truncation is removed, and engine-aware DDL and schema-qualified introspection land across engines.
- **Response auto-serialization** - Routes can return ORM models, model lists, and query results directly, with the response layer serializing them automatically.
- **Security hardening** - XSS escaping in `htmlElement` and the messenger, SQL-injection fixes, SOAP DTD rejection, a GraphQL query-depth guard, safe 500 responses, timing-safe API-key comparison, and dev-secret bootstrap.
- **Env-var uniformity** - A canonical `TINA4_` manifest with a strict audit gate, a uniform `.env.example`, typed `Env` helpers, and aligned defaults for caching, queues, databases, CORS, and AI hosts.
- **Startup auto-migration** - Pending migrations can run automatically on startup behind `TINA4_AUTO_MIGRATE`, with numeric-aware ordering, `CREATE TABLE` idempotency, and smart-quote normalization in migration SQL.

## What is new

**v3.13.39 (2026-06-21)** - Auto-migrations on startup, unified critical log level, and per-route WebSocket auth

Upcoming release. Parked and not yet published. This release lands a broad parity sweep across all four frameworks.

- Migrations: pending migrations now run automatically on startup, gated by `TINA4_AUTO_MIGRATE` and off by default so nothing changes for existing apps. A footgun pass adds numeric-aware ordering, `CREATE TABLE` idempotency, a URL-safe `//` delimiter, and smart/curly-quote normalization in migration SQL before it runs. Ruby and Node.js also pick up clear-bug fixes (per-file transactions, row-existence tracking, stop-at-failure, and MSSQL bootstrap).
- Logging: `critical` is now a first-class top-level severity rather than a toggle, and a new console-threshold check ships as `Log.is_enabled(level)` in Python, `Log::isEnabled(level)` in PHP, `Tina4::Log.enabled?(level)` in Ruby, and `Log.isEnabled(level)` in Node.js. Logs default to stdout-only in production and container environments to avoid file bloat.
- WebSockets: routes can now require authentication on the upgrade. Node.js also wires user WebSocket routes into the integrated server.
- ORM: save, create, `QueryBuilder`, and the Mongo path now fail loud instead of failing silently, with Python as master and each framework's outlier bugs corrected to match.
- Security and env: the MCP endpoint enforces its localhost guard and honors `TINA4_MCP_REMOTE`. Environment defaults align to the canonical manifest with a uniform `.env.example`; CORS credentials are opt-in, and AI hosts default to localhost. Ruby gains an autocommit durability fix and ORM-plural default off.
- HTTP client: the built-in Api client strips auth headers on cross-origin redirects and adds opt-in retry and backoff. Ruby also fixes a dead `verify_ssl` setting.
- Metrics: test-coverage detection now counts full-package-path imports and short (3-character) class names, and the complexity counter no longer over-counts string literals. PHP, Ruby, and Node.js also bring Kafka TLS and SASL parity.

Breaking: Logging unifies `critical` as a first-class top-level severity and drops the previous toggle (Ruby also renames its strict flag), so log configuration that relied on the old toggle must be updated.

**v3.13.38 (2026-06-19)** - Security hardening, tina4 metrics CLI, and a framework-wide parity sweep

This release lands a broad security and reliability pass across all four frameworks, a new code-health metrics CLI, and a fix for Kafka TLS/SASL credentials.

Security hardening reaches the API surfaces that handle untrusted input. GraphQL and WSDL gain DTD rejection for SOAP, a GraphQL query depth guard, and debug-gated error masking so internal detail stays hidden in production. The WebSocket backplane is now wired for real and ships with broadcast, SSE, origin allow-list, and idle-reaper hardening. `htmlElement` and the messenger escape child content to prevent XSS, with raw output as an explicit opt-in, and IMAP now fails loud. Sessions log loud and degrade on backend failure rather than failing silently. Framework-specific fixes: PHP closes a SQL injection in `DatabaseSessionHandler`, and Ruby adds a timing-safe API-key comparison and drops a guessable default secret.

The new `tina4 metrics` CLI reports the top code-health offenders, backed by precise test-detection that ends the coverage-badge over- and under-reporting.

Other work in the sweep:

- Database contract: `execute()` raises on failure, automatic caching defaults off, fetch fails loud, `generate_next_id` is atomic, and commit failures are handled. A dev secret is auto-generated.
- The seeder is overhauled for visible-but-resilient errors, idempotency, and foreign-key ordering.
- Middleware and event listeners run in isolation with deterministic order and clean throw handling.
- `.env.local` no longer overrides real environment variables.
- Kafka now passes SSL/SASL config through to the confluent client, with a `TINA4_KAFKA_*` namespaced alias and lock-in tests.

Node.js also makes `pg` an optional dependency to restore the zero-hard-dependency promise, and adds a `tsc` typecheck gate. Ruby drops phantom runtime dependencies (`bcrypt`, `dotenv`, `oj`) from the gemspec and corrects its dependency claim to "minimal dependencies".

Breaking: `execute()` now raises on failure instead of returning a falsy value, and automatic query caching now defaults off.

**v3.13.37 (2026-06-18)** - Dev-admin editor syntax highlighting

The dev-admin editor now highlights more languages across all four frameworks. The shipped editor bundle adds grammar coverage for TypeScript, Ruby, Rust, Go, Java, and SCSS. PHP aligns its file-read language map to the Python master and detects bare `Dockerfile` names. The Ruby and Node.js file-read endpoints now return the file language, which was missing before and left TypeScript and other files without highlighting.

**v3.13.36 (2026-06-18)** - Instant WebSocket dev-reload across all four frameworks

The dev server now pushes reloads over a WebSocket connection, so saved changes refresh the browser instantly. Python led as the master and now has parity across all four frameworks.

- Ruby and Node.js also fix the dev-admin file browser.
- The Node.js example app no longer uses a non-existent `getDatabase` call or an invalid SQLite URL in its users routes.

**v3.13.35 (2026-06-17)** - Live /__dev/mcp endpoint for MCP clients

The `/__dev/mcp` dev endpoint now mounts a JSON-RPC and SSE handler across all four frameworks, so MCP clients can connect to a running project and call its tools live. In Node.js this release also wires `globalThis.__tina4_db` and async tool dispatch so the database tools work against the live connection. The `CLAUDE.md` guidance now notes that `tina4 deploy docker` generates the Dockerfile, not `tina4 init`.

**v3.13.34 (2026-06-17)** - Demo app fixes and dual-port reload corrections

This release repairs the example applications that broke against the current API and corrects the dual-port reload behavior.

- Updated the demos to call the renamed database binding methods so they boot again: `orm_bind` is now `bind_database` in Python, and `setGlobalDb` is now `bindDatabase` in PHP. The PHP store demo now reads `image_url` for store images, where the templates previously read `imageUrl`, and its `.env.example` carries corrected env names so a stale `SECRET` no longer crashes boot.
- Corrected stale env var names and unified the CLI references in the Python README and example `.env`.
- Fixed the Node.js dual-port reload, which was inverted: the base port now hot-reloads and base+1000 is the stable AI port, with the docs updated to match. The Node CLI now scaffolds a runnable project with a `^3.0.0` dependency and `npx tina4nodejs serve` scripts.
- Added a PHP server test that locks in the dual-port reload behavior for parity with Python, Node, and Ruby.

**v3.13.33 (2026-06-17)** - Queue lifecycle: priority pop, auto dead-letter, and retry backoff

The queue system gains a fuller lifecycle across all four frameworks. Workers now pop jobs in priority order, failed jobs retry on a configurable `retry_backoff` and move to a dead-letter destination automatically once they exhaust their attempts.

Framework-specific fixes landed alongside the shared work:

- Node.js queue backends now read `TINA4_QUEUE_URL` for env-var parity with the other frameworks, with per-backend variables acting as overrides. This release also fixes a double-increment in `fail()`.
- PHP makes `Job::$topic` public.
- Ruby fixes `consume(id:)` and `pop_by_id`.

Behavioural change: `job.fail()` now re-enqueues the job and retries it until it reaches `max_retries`, then moves it to the dead-letter store automatically. Previously `fail()` only marked the job failed. A `consume` loop that calls `job.fail()` now retries and dead-letters on its own, with no manual `retry_failed()` call. Only the file/lite backend changed; brokers already delegate retry and dead-lettering.

**v3.13.32 (2026-06-17)** - Response cache parity: per-query bypass, X-Cache headers, string middleware

This release brings the response cache into line across all four frameworks. Individual queries can now opt out of caching with a `no_cache` (`noCache`) flag, so a route can serve fresh data without disabling caching elsewhere. Cached responses carry `X-Cache` and `X-Cache-TTL` headers so you can see hits, misses, and remaining lifetime from the client. The response cache also works as string middleware.

Each framework also picked up a specific correction:

- PHP: `afterCache` no longer fails to run on the route path.
- Ruby: `X-Cache` MISS is no longer a no-op on a real `Request`.

The caching documentation chapters were rewritten to match.

**v3.13.31 (2026-06-17)** - Ruby request/response parity and lazy upload content

Ruby now matches its request and response API with Python, PHP, and Node.js, so the same code reads the same way across all four frameworks. Ruby uploads also load file content lazily instead of buffering large files into memory up front. The documentation corrects `add_header` to instance usage and drops a stale `fieldName` from the upload example.

Breaking: Ruby `request.body` changes shape to match the other frameworks. Code that reads the Ruby request body must be updated.

**v3.13.30 (2026-06-16)** - Typed path param coercion and JWT expiry in minutes

Typed path parameters now coerce to their declared type. A route segment like `{id:int}` hands your handler an integer and `{x:float}` hands it a float, instead of a string you have to convert yourself.

- PHP also tightens the `/__dev` auth-bypass path check.
- Node.js now expresses JWT expiry in minutes for parity with the other frameworks.

Breaking: Typed path params now arrive coerced (for example `{id:int}` is an int, not a string), and Node.js JWT expiry is now measured in minutes.

**v3.13.29 (2026-06-16)** - Sharper live API search results

The live API search now finds metaprogrammed methods, ranks qualified queries higher, and resolves natural names so lookups land on the method you meant. This change is in tina4-python.

**v3.13.28 (2026-06-16)** - Frond honours custom test registrations in is checks

Frond now respects custom `add_test()` registrations when evaluating `is` tests, so tests you register are used in place of the built-in defaults. This change landed in tina4-python.

**v3.13.27 (2026-06-16)** - Frond template parity fixes in Python, Ruby, and Node.js

This release fixes Frond template divergences. Python corrects six Twig/Jinja differences. Ruby fixes expression-parser literal handling and safe-output filters. Node.js fixes printf-style formatting and variable filter-argument resolution. The Ruby suite also loads `spec_helper` in `frond_spec` so it passes when run in isolation.

**v3.13.26 (2026-06-16)** - Pooled standalone writes commit by default

Standalone writes now auto-commit by default across all four frameworks, so a write made on one pooled connection is visible to the next checkout from the pool. Ruby adds a regression test that locks in standalone-write visibility across the pool, and PHP also fixes pooled PostgreSQL connections so each one stays independent. On Node.js this release completes the async cache work, bringing the distributed `responseCache` and persistent DB cache to parity.

**v3.13.24 (2026-06-15)** - Unified cache backend set with credentials and fallback

Cache configuration moves to a single `CacheBackend` across all four frameworks, adding `valkey`, `memcached`, `mongodb`, and `database` backends alongside the existing options. The backend reads credentials for Redis, Valkey, and MongoDB, and falls back to the file backend when a driver or service is unavailable so a missing dependency no longer takes down caching.

- In Python, the persistent cache now routes through the same unified `CacheBackend`, which supports multiple instances. The database backend reads `TINA4_CACHE_URL` rather than a separate `TINA4_CACHE_DB_URL`.
- The Node.js network backends are async, dropping `execFileSync`.
- CI gains real authenticated-Redis integration tests through a Docker harness, with the Node.js job running Redis auth via `docker run` instead of a nonexistent service image.

**v3.13.23 (2026-06-15)** - Request-scoped query cache on by default

A request-scoped database query cache is now on by default in Python and Ruby. The auto-cache switch is renamed to `TINA4_AUTO_CACHING` so the control name matches across frameworks. Ruby sets the default response-cache TTL to 60 seconds for parity, up from 0 (disabled). PHP and Node.js were not tagged for this version.

**v3.13.22 (2026-06-15)** - Session default TTL aligned to one hour

The default session TTL now falls back to `3600` seconds (one hour) when none is set, matching session behavior across frameworks. This change landed in Python and Ruby.

**v3.13.21 (2026-06-15)** - Safer JWT signing in Python and a Node global middleware fix

Python no longer silently signs JWTs with a guessable default secret. Node.js now runs global class middleware registered through `Router.use()`. Documentation in the PHP, Ruby, and Node.js frameworks corrects stale `Response::template()` references to `render()`.

**v3.13.19 (2026-06-15)** - Unified ORM database binding and automatic model serialization

This release lines up the ORM and response handling across all four frameworks.

- The database binder is now `bind_database`/`bindDatabase` with support for named connections, so models can target a specific connection by name.
- A model can be constructed from a JSON object string, and array input is rejected with a clear error instead of binding silently.
- Responses auto-serialize ORM models, model lists, and query results, so a route can return ORM objects directly without manual conversion.

PHP and Ruby also picked up earlier fixes batched into this tag: PostgreSQL reads now return native types (int, bool, float in PHP; native Ruby types via `PG::BasicTypeMapForResults`) instead of strings, and PHP `Database::execute()` now propagates adapter failure instead of always returning true. PHP, Ruby, and Node.js folded in ORM relationship, QueryBuilder, eager-load, and `foreign_key_field` wiring fixes from their intermediate releases.

**v3.13.16 (2026-06-15)** - Engine-aware create_table and DatabaseResult index access on PostgreSQL

`ORM.create_table` now generates DDL that matches the target engine, with correct boolean and datetime column types, and `DatabaseResult` supports index access on PostgreSQL. This is a Python-only release; PHP, Ruby, and Node.js were not tagged for this version.

**v3.13.15 (2026-06-15)** - Close implicit PostgreSQL read transactions

tina4-python now closes the implicit transaction PostgreSQL opens for read queries, fixing an idle-in-transaction connection leak (#51). This release is Python only; the other three frameworks are unchanged.

**v3.13.14 (2026-06-13)** - Schema-qualified introspection and dev request logging to stdout

Table introspection now resolves schema-qualified names across every database engine, fixing issue #48 across all four frameworks. The PHP fix also corrects a Postgres `SqlNormalizerTrait` regression that surfaced during the change.

Per-request logging now routes through the Tina4 `Log` system and is on by default in development, so request logs reach stdout in containers without extra configuration.

PHP also picks up two framework-specific fixes:

- A legacy-env guard no longer crashes under the built-in cli-server (`Undefined constant Tina4\STDERR`), resolving issue #119.
- The built-in server no longer truncates large responses (shipped in the PHP-only 3.13.13).

**v3.13.12 (2026-06-11)** - Fetch returns all rows and tolerates trailing semicolons

`fetch_all` (and `fetchAll`) now returns every matching row by default, removing the silent 100-row truncation that could hide data. The paginated `fetch()` sibling, which returns a `DatabaseResult` with count metadata, keeps its 100-row default because pagination is its job. The fetch and fetch-one paths also strip a trailing `;` from user-supplied SQL so queries copied from a SQL console run without error. The semicolon fix lands across all four frameworks. Python, PHP, and Ruby fix the row truncation in code; Node.js pins the return-all-rows behavior with explicit tests. Ruby also wires up `auto_discover_db`, so a model bound only through `TINA4_DATABASE_URL` no longer silently no-ops.

Breaking: callers that relied on the silent 100-row cap from `fetch_all` now get every row. For very large tables, pass an explicit `limit` or use `fetch()`, which paginates.

**v3.13.11 (2026-06-11)** - ORM correctness pass

A set of ORM fixes, led by tina4-python as the master:

- Callable field defaults now resolve per instance at construction time. A field like `DateTimeField(default=lambda: datetime.now())` stores a fresh value on each row instead of the lambda object, which used to crash on save.
- `save()` now INSERTs a natural (non-auto-increment) primary key correctly. Previously it always chose UPDATE, matched no rows, and returned success without writing anything. It now checks whether the key already exists.
- `Database.fetch()` captures `last_error` the way `execute()` does, and a failure inside an explicit transaction logs the original cause before the rollback cascade buries it.
- `BooleanField` generates engine-aware DDL: `BOOLEAN` on PostgreSQL and MySQL, `BIT` on MSSQL, and `INTEGER` on SQLite and Firebird, instead of `INTEGER` on every engine.

The other frameworks already handled several of these cases and picked up the rest in the following parity releases.

Breaking: on PostgreSQL, MySQL, and MSSQL, a literal `= 0` or `= 1` comparison against a boolean column created by `create_table()` must become `= false` or `= true` (or the engine's native boolean literal). Tables created by migration with explicit DDL are unaffected, since the framework only sets the type when it creates the table itself.

**v3.13.10 (2026-06-11)** - Antigravity removal and housekeeping (Python)

A Python-only release. It removes the Antigravity integration and cleans up housekeeping items. No PHP, Ruby, or Node.js tags ship in this version.

**v3.13.9 (2026-06-10)** - Non-destructive AI installer

The AI installer now preserves existing files instead of overwriting them, so running it against a configured project no longer clobbers local changes. This release lands in tina4-python.

**v3.13.8 (2026-06-10)** - Heal poisoned PostgreSQL connections

tina4-python recovers from a poisoned PostgreSQL connection so a broken connection in the pool no longer fails later queries. This follows on from issue #46. Only tina4-python carries a tag for this version.

**v3.13.7 (2026-06-10)** - Request error event and safe 500 responses

Unhandled request errors now fire a `tina4.request.error` event across all four frameworks, so you can hook logging or alerting into a single place. The default 500 response no longer leaks exception details to the client (CWE-209).

**v3.13.6 (2026-06-09)** - Clearer PostgreSQL errors and driver install hints

PostgreSQL failures now surface the underlying error, and missing database drivers report an install hint that names the package to add. The driver install hints ship across all four frameworks. Ruby also clears the `ServiceRunner` registry between specs to stop Frond spec contamination.

**v3.13.5 (2026-06-05)** - Static facade for registering Frond filters, globals, and tests

Frond now exposes `addFilter`, `addGlobal`, and `addTest` as static facade methods across all four frameworks, so you can register custom template filters, globals, and tests without holding a Frond instance. Ruby uses the matching `Frond.add_filter`, `Frond.add_global`, and `Frond.add_test` class methods.

This release also tidies a few things: the Ruby v3 test suite for the Rack and MCP paths is green again, and stale references are corrected (a Ruby version line and a Node.js env-var name now read `TINA4_AUTOCOMMIT`).

**v3.13.4 (2026-06-04)** - Middleware and headers parity across all four frameworks

Aligns middleware behavior and response header handling across all four frameworks, so requests pass through middleware and emit headers the same way in Python, PHP, Ruby, and Node.js.

**v3.13.3 (2026-06-03)** - Typed env-var helpers and function names in logs

Adds a typed `Env` helper across all four frameworks. Configuration values read from the environment now return as the type you expect instead of raw strings. Log output now includes the calling function name, so you can trace where a message came from.

**v3.13.2 (2026-06-03)** - SCSS arithmetic and database URL guidance fixes

This patch fixes two issues. The SCSS compiler now leaves mixed-unit arithmetic verbatim instead of resolving it, so expressions that combine units pass through unchanged. Environment guidance now points to `TINA4_DATABASE_URL` instead of the legacy bare key. The SCSS fix lands in Python, PHP, and Node.js. The `TINA4_DATABASE_URL` guidance updates in Python and Node.js. Ruby ships as a version alignment with no code changes.

**v3.13.1 (2026-06-02)** - Service base class and GraphQL resolve parity

This release adds a `Service` base class and service registration across all four frameworks. Define a service by extending the framework's `Service` class. Python registers it with `ServiceRunner.register_service` and PHP with `ServiceRunner::registerService`. Ruby and Node.js ship the matching `Service` base class.

PHP, Ruby, and Node.js gain the decorator-style `GraphQL.resolve()` static API, so resolver registration reads the same way in each framework.

The same three frameworks pick up the first round of Group A/B database helpers: a `fetchAll`/`fetch_all` helper, URL-aware connection setup through `getConnection`/`get_connection`, and an options bag for the `Api` client.

- Node.js: the CI runner now uses Node 22, which the `node:sqlite` import requires.

**v3.13.0 (2026-06-01)** - Documentation and code parity build-out

This release closes the gap between the documentation and the running code. The Python master lands a set of lettered parity groups that bring the public API in line with what the docs describe:

- Group A adds properties and methods that the docs document but the code missed.
- Group B expands method signatures to match the documented arguments.
- Group C adds a `Test` HTTP mixin, Frond classmethods, and the `@GraphQL.resolve` decorator.
- Group D changes return types to match the documented contracts.
- Group E renames methods to match the documented names.
- Group F adds top-level re-exports and fixes the scaffolder templates.

The Python skills and `CLAUDE.md` files were corrected for import paths, environment variable names, and `Auth` argument order. PHP mirrors the Python Groups C and D, gaining the `Test` class, a `Debug` shim, and an `Auth::validToken` that returns `array|null`, and adds `SqlTranslation::namedToPositional` to the PHP `CLAUDE.md` method list. Ruby and Node.js were not tagged for this version.

Breaking: Python Groups D and E and the matching PHP mirror change return types and rename methods to match the docs. Callers relying on the old return types or method names must update.

**v3.12.14 (2026-06-01)** - Class-based xUnit testing surface for Python

Python gains a class-based xUnit testing surface under `tina4_python.test`, matching what the documentation already describes. Assertions now share a uniform `(actual, expected, message)` signature, `assert_raises` takes a consistent signature, and lifecycle hooks use snake_case `set_up` and `tear_down`.

In PHP, `:named` placeholders now translate correctly for non-PDO database adapters.

**v3.12.13 (2026-05-29)** - Dev admin tooling, safer MCP writes, and request URL parity

This release ships a batch across all four frameworks, centered on the development admin tooling and the MCP write path.

- Dev admin gains a customer feedback widget served through middleware with an intake proxy, a thread sidebar that proxies to the supervisor with SSE streaming, and a stale-source badge that warns when the running code is behind your edits. Plan files in `plan/` and `.tina4/plans/` now merge into one view.
- MCP file writes verify the result after writing. `file_write` and `file_patch` run post-write syntax checks for PHP, Ruby, and Node.
- Route discovery re-runs on `/__dev/api/reload`, warns when it finds zero routes, and marks failing files with `.broken`.
- Environment configuration uses `TINA4_DATABASE_URL` across docs, init templates, the dashboard `.env` editor, and CLI errors so the boot guard matches what you set.
- The request object reports `.url` as the full absolute URL across all four frameworks. Ruby honours `X-Forwarded-Proto` and `X-Forwarded-Host`, PHP and Node also expose `.queryString`, and Node adds `.path`.

Two framework-specific fixes ship as well. PHP corrects a file upload regression where `WebSocket::parseHttpHeaders` read past the header boundary (tina4-book#139). Node fixes the migrate CLI to await `initDatabase()` and `loadEnv()`, which had left migrations broken.

**v3.12.10 (2026-05-14)** - PHP ORM save() no longer hides write failures

The PHP ORM `save()` now honours the result of the underlying `update()` and `insert()` calls. A failed write surfaces instead of being swallowed, closing a path to silent data loss. This release also aligns versions across all four frameworks.

**v3.12.9 (2026-05-13)** - Version bump release

Maintenance release. This bumps the version with no functional changes. The tina4-python, tina4-ruby, and tina4-nodejs frameworks carry a version-bump commit.

**v3.12.8 (2026-05-12)** - RFC 9110 HTTP method conformance in the router

The router now follows RFC 9110 for HTTP method handling across all four frameworks. It answers `HEAD` and `OPTIONS` requests, returns `405 Method Not Allowed` when a path exists but the method does not, and includes an `Allow` header listing the methods a route accepts.

PHP also normalises caller-provided header keys to lowercase so header lookups behave the same regardless of the case used.

**v3.12.6 (2026-05-06)** - psycopg2 percent-sign substitution fix

Fixes percent-sign (`%`) substitution in psycopg2 queries so literal `%` characters no longer trip parameter binding (issue #40). The fix ships across all four frameworks.

**v3.12.5 (2026-05-06)** - PHP multipart body parse fix

Fixes multipart request body parsing in PHP so requests with file uploads parse correctly (tina4-book#135).

**v3.12.4 (2026-05-06)** - 25 new env vars, log rotation, and a stricter env audit gate

This release adds 25 new environment variables and built-in log rotation across all four frameworks. The audit-truth gate now runs strict on environment variables, so documented env vars must match what the code actually reads. The `tina4 env-migrate` command is now `tina4 env --migrate`, matching the CLI as shipped.
