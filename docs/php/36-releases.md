# Chapter 35: Release Notes


## v3.12.3 (2026-05-05)

Cross-framework parity sweep. Two minor breaking changes in the Ruby and PHP public API that bring all four frameworks onto the same shape.

### Breaking changes (Ruby + PHP only)

**Ruby Container — predicate now uses `?` suffix.**

```ruby
# before (3.12.2 and earlier)
Tina4::Container.has(:mailer)        # outdated

# after (3.12.3)
Tina4::Container.has?(:mailer)       # idiomatic Ruby predicate
```

This brings Ruby in line with Python (`has()`), PHP (`has()`), and Node (`has()`) while still respecting Ruby's `?`-suffix idiom for predicates returning bool. The pre-existing `resolve` → `get` rename happened earlier; only the predicate was lagging.

**ResponseCache public surface — middleware-only across all four frameworks.**

The cache has always been middleware. Two of the four frameworks (PHP, Ruby) historically exposed lookup/store as public methods, which let users couple to internals. The public API is now consistent across all four: use the middleware on a route, and read stats with module-level helpers.

```ruby
# Ruby — module-level helpers (parity with Python)
Tina4.cache_stats   # → { hits:, misses:, size:, backend:, keys: }
Tina4.clear_cache   # flush all entries

# PHP — static methods on the class
\Tina4\Middleware\ResponseCache::cacheStats();
\Tina4\Middleware\ResponseCache::clearCache();
```

Internal methods that used to be public (`get`, `lookup`, `store`, `cache_response`) are now private. Tests that needed them retain access via `_internal*` test seams marked `@internal`.

### Doc parity — CLAUDE.md and book chapter 33

- **CLAUDE.md**: every framework's "Key Method Stubs" section now covers the same surface area Python documents — Queue, QueryBuilder, Frond, Api, Background Tasks, ResponseCache, etc. PHP added 4 sections; Ruby added 5; Node added 13.
- **Book chapter 33**: env var tables are now grounded in source. Each framework's chapter 33 lists every `TINA4_*` var its source actually reads. Found and fixed several gaps — Ruby was missing `TINA4_CACHE_*`, `TINA4_QUEUE_*`, `TINA4_KAFKA_*`, `TINA4_RABBITMQ_*`, `TINA4_MONGO_*`, `TINA4_WS_BACKPLANE`, and the entire `TINA4_SESSION_VALKEY_*` block.

### Other fixes

- **Ruby `lib/tina4/ai.rb`** — subprocess output is now force-encoded to UTF-8 before `String#strip`, fixing `Encoding::CompatibilityError` that crashed 4 ai specs on systems with non-ASCII pip output.
- **Node `test/serverParity.test.ts`** — sets `TINA4_OVERRIDE_CLIENT=true` so `start()` actually runs, plus emits the `N passed, M failed` summary line the runner expects. The test was effectively a no-op before; now it's recorded properly.

### Genuine gaps surfaced by the parity audit (follow-up, not blocking 3.12.3)

The chapter 33 audit flagged env vars Python documents that no other framework actually reads — Ruby/PHP/Node lack `TINA4_OPEN_BROWSER`, `TINA4_DEV_POLL_INTERVAL`, `TINA4_PUBLIC_DIR`, `TINA4_TOKEN_EXPIRES_IN` alias, plus a few framework-specific gaps (Ruby has no Mongo session backend; Node `TINA4_CSRF` defaults to `false` vs Python's `true`). Tracked for a future patch.

### Upgrade path

| Symptom | Fix |
|---|---|
| Ruby: `NoMethodError: undefined method 'has' for Tina4::Container` | Replace `has(:key)` with `has?(:key)` |
| PHP: `BadMethodCallException` calling `$cache->lookup(...)` | Use the middleware: `[ResponseCache::class, 'beforeCache']` / `[..., 'afterCache']`. Or call `_internalLookup` if you really need direct access (test code only — `@internal`). |
| Ruby: `NoMethodError: undefined method 'get' for ResponseCache instance` | Use `Tina4.cache_stats` / `Tina4.clear_cache` for stats. Lookup goes through the middleware. |

No `.env` changes from 3.12.2.

## v3.12.2 (2026-05-05)

Quality-of-life patch. Two related portability fixes — no breaking changes from 3.12.1.

### Firebird URL auto-detect

Firebird is the awkward one in the stack. Every other engine has a server-side database name (`postgres://host:port/dbname`), but Firebird wants either an absolute file path on the server, a Windows drive-letter path, or an alias. The classic URI form needs a double slash to keep the leading `/` of an absolute path through the URL parser — unintuitive to anyone used to the way postgres / mysql / mssql encode the database name.

The framework now accepts five equivalent forms and normalises all of them transparently:

| URL path you write | Resolved Firebird identifier |
|---|---|
| `//abs/path/db.fdb`   (classic double-slash) | `/abs/path/db.fdb` |
| `/abs/path/db.fdb`    (single-slash, intuitive) | `/abs/path/db.fdb` |
| `/C:/Data/db.fdb`     (Windows drive letter) | `C:/Data/db.fdb` |
| `/C%3A/Data/db.fdb`   (URL-encoded colon) | `C:/Data/db.fdb` |
| `/employee`           (Firebird alias) | `employee` |

For ops setups that keep server URL and DB location in separate config layers — or for Windows backslash paths that fight URL encoding — set `TINA4_DATABASE_FIREBIRD_PATH`. The env override wins over whatever path is in the URL.

```bash
TINA4_DATABASE_FIREBIRD_PATH=C:\firebird\data\app.fdb
TINA4_DATABASE_URL=firebird://SYSDBA:masterkey@localhost:3050/ignored
```

Shipped to all 4 frameworks. 11 regression tests per framework (8 unit + 3 live).

### Bug fix specific to PHP — `mysqli` localhost+port quirk

PHP's `mysqli` has a long-standing quirk where `host == "localhost"` triggers a Unix socket lookup and IGNORES the port argument entirely. Connecting to `mysql://...:53306` against a Docker container fails with "No such file or directory" — `mysqli` is hunting for `/tmp/mysql.sock` instead of opening a TCP connection. `MySQLAdapter::rewriteHostForTcp()` now rewrites `localhost` to `127.0.0.1` when a non-zero port is specified, forcing the TCP code path. Bare `mysql:///db` (no port) is preserved so existing socket-based setups keep working.

### Other fixes

- **chore(python):** `pyproject.toml` had drifted to `3.10.41` while `__init__.py` read `3.12.1`. Synced both to 3.12.2 so `uv build` and runtime introspection now agree.
- **chore(claude.md, all 4):** stale framework version banners in `CLAUDE.md` headers updated.

No `.env` changes from 3.12.1, no migration needed. Existing 3.12.1 installs upgrade by changing one version number.

## v3.12.1 (2026-05-04)

CI-only patch — no framework code changes from 3.12.0.

- **fix(ci, all 4):** every `publish.yml` workflow now declares `permissions: contents: write` on the publish job. Without this, `softprops/action-gh-release` 403'd against the default `GITHUB_TOKEN` on repos whose default Workflow permissions setting was read-only (Ruby and Node hit this every release; PHP and Python worked by luck of repo settings). The explicit declaration makes the workflow self-sufficient.
- **chore(ci):** bumped `softprops/action-gh-release` from `@v1` (unmaintained) to `@v2`.

No `.env` changes, no API changes, no migration needed. Existing 3.12.0 installs can upgrade without touching anything else.

The version-bump itself is the test: a successful 3.12.1 release proves the workflow fix works on Ruby and Node where 3.12.0 needed manual `gh release create`.

## v3.12.0 (2026-05-04)

> **⚠️ Breaking change — read before upgrading.** Every framework env var now uses the `TINA4_` prefix. Existing `.env` files set with `DATABASE_URL`, `SECRET`, `SMTP_HOST`, `HOST_NAME`, etc. will cause the framework to refuse to boot. Run `tina4 env --migrate` to rewrite, or follow the rename table below.

### Why this release

Tina4's env vars had grown inconsistent. Some had the `TINA4_` prefix (`TINA4_DEBUG`, `TINA4_LOCALE`, `TINA4_CACHE_BACKEND`), others didn't (`DATABASE_URL`, `SECRET`, `SMTP_HOST`). Newcomers had to guess which convention applied to which feature. Existing tools and PaaS dashboards collided with un-prefixed names like `SECRET` and `API_KEY` that other libraries also read. Documentation drifted — 91 env-var names appeared in the docs that didn't exist in any framework, and 22 framework-specific env vars in the code didn't match the names users were told to set.

This release closes all three gaps with a single hard rename. No deprecation period, no fallback chain. The framework refuses to boot if it detects a legacy name in the environment, prints a list of every var to rename, and tells you which command to run.

### What changed

- **22 env vars renamed** to `TINA4_*` form. See the migration table below.
- **`tina4 env --migrate` CLI** added to all four frameworks. Reads your `.env`, rewrites it in place, leaves a `.env.bak` backup, prints a diff. Idempotent.
- **Boot-time guard** scans `os.environ` (or the language equivalent) for the 22 legacy names. If any are present, prints the rename map and exits with code 2. Bypass with `TINA4_ALLOW_LEGACY_ENV=true` for migration scripts that need both names set during transition.
- **All 4 framework books rewritten.** Chapter 33 (Environment Variables) is now a clean canonical list — every var prefixed, descriptions current, legacy names removed.
- **Doc-vs-code drift closed.** Of the 91 stale env vars previously documented, 61 were renames (corrected), 32 were never implemented (removed). The `audit-links.py` CI gate stays at 0 broken links / 0 broken anchors.
- **Frond bundle** rebuilt at v2.1.3 — `frond.min.js` footer now shows the version explicitly so users can verify what they have.

### Bug fixes shipped alongside the rename

- **#38 PostgreSQL UUID-PK transaction abort** — the post-INSERT `lastval()` probe is now wrapped in a SAVEPOINT, so UUID-PK INSERTs no longer poison the outer transaction with `InFailedSqlTransaction`. Live regression test against PostgreSQL 16. (Affects all 4 frameworks where the PG adapter does this probe.)
- **#39 Landing page + template auto-routing** —
  - Auto-routing now scans `src/templates/pages/` only. Partials, layouts, base.twig, errors/, components/, and `_*` files never auto-serve from a URL.
  - `TINA4_TEMPLATE_ROUTING=off` kills the feature entirely.
  - `src/public/index.html` auto-serves at `/` (and `/foo/` serves `src/public/foo/index.html`) — SPA hosting Just Works.
  - The framework landing page only renders when `TINA4_DEBUG=true`. Production never shows it; framework version, dev-admin link, and gallery don't leak to real users.
  - The malformed `HTTP/1.1 404 OK` status line is fixed — every status code now uses its canonical RFC 7231/9110 reason phrase.
- **#37 frond.form.submit redirect handling** — verified shipped at v2.1.x; `xhr.responseURL` change triggers `window.location` navigation correctly.
- **#36 Session file handler** — re-verified safeguards (lazy save, WebSocket skip, probabilistic GC, new-and-empty skip) all still in place.

### Migration — every renamed var

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

`PORT`, `HOST`, `NODE_ENV`, `RACK_ENV`, `RUBY_ENV`, `ENVIRONMENT` — these are runtime / PaaS conventions, not framework config. Heroku, Railway, Vercel, and friends set them; we keep reading them.

### How to upgrade

1. **Backup your `.env`:** `cp .env .env.bak.pre-v3.12`
2. **Run the migration:** `tina4 env --migrate` — rewrites your `.env` in place.
3. **Update PaaS dashboards:** Heroku, Railway, Vercel, Render, Fly.io etc — rename the same vars in your provider's env-var UI.
4. **Restart your app.** The boot guard verifies nothing legacy remains.

If your app uses `SECRET`, `DATABASE_URL`, or any other listed name in places besides `.env` (e.g. your CI pipeline's `env:` blocks), update those too — the boot guard checks `os.environ`, not just `.env`.

### Parity

All 4 frameworks aligned at **3.12.0**:
- tina4-python 3.11.32 → 3.12.0
- tina4-php 3.11.32 → 3.12.0
- tina4-ruby 3.11.32 → 3.12.0
- tina4-nodejs 3.11.32 → 3.12.0

Coordinated release across PyPI, Packagist, RubyGems, npm.

## v3.11.32 (2026-04-25)

**Critical fix — pool + transactions are now actually atomic.** Plus a coordinated parity release that aligns all four frameworks at the same version after months of drift.

Before this release, creating a `Database` with `pool > 0` silently broke transactions. The pool's round-robin checkout rotated to a different adapter on every call — so `start_transaction()` pinned its flag on adapter A, the executes autocommitted on adapters B and C, and the final `commit()` / `rollback()` landed on adapter D, which had nothing to commit. Result: `rollback()` was a no-op, writes leaked through, and no error or log surfaced the problem.

The fix pins one adapter to the calling context for the lifetime of a transaction. Each language uses its own primitive:

- **Python** — `threading.local()` on the `Database` instance
- **Ruby** — `Thread.current[:tina4_pinned_adapter_<obj_id>]`
- **Node.js** — `AsyncLocalStorage` from `node:async_hooks` (async-safe across overlapping awaits)
- **PHP** — per-instance property (PHP-FPM is one process per request; threading.local is unnecessary)

While pinned, every database call routes to the same adapter. `commit()` and `rollback()` release the pin so subsequent calls round-robin again.

- **fix (database / all 4):** adapter pinning across transaction scope in `Database._get_adapter()` (and language equivalents). Every backend is affected — SQLite, PostgreSQL, MySQL, MSSQL, Firebird. Firebird exposed it loudest because of its honest "commit-empty-txn is a real no-op" semantics; the others mostly hid the bug behind eager autocommits but still lost rollback atomicity.
- **tests (all 4):** new regression suite — three INSERTs followed by `rollback()` under `pool=4` now leaves zero rows (was leaking three). Three INSERTs followed by `commit()` persists exactly three. Pin-release after commit/rollback verified. `pool=0` regression test added so single-connection mode stays unaffected.
- **parity / version alignment:** all 4 frameworks bumped to 3.11.32 — closes the cross-framework version drift that had built up (PHP at 3.11.31, Python at 3.11.24, Ruby and Node at 3.11.19). A single coordinated release across all four registries: PyPI, Packagist, RubyGems, npm.

**No migration needed.** Code using `pool=0` (the default for every adapter except where explicitly raised) is unaffected. Code using `pool>0` will now actually honour transactions instead of silently dropping them.

**If you've been seeing intermittent "writes vanished" or "rollback didn't help" reports on a pooled `Database`, this release is the cause and the cure.**


## v3.11.13 (2026-04-16)

Issue-driven release. Everything reported in the open tina4-book issues either was fixed in this version or is already fixed in 3.11.12; this release consolidates the remaining bits and corrects documentation drift.

- **feat (router / all 4):** Explicit typed-parameter system shared across Python, PHP, Ruby, Node. Adds `alpha`, `alnum`, `slug`, `uuid`, and explicit `string` types in addition to the existing `int`/`integer`, `float`/`number`, `path`/`.*`. **Unknown type names now throw at registration** — `{name:str}`, `{id:inetger}`, etc. raise with a clear message listing the valid types instead of silently falling through to the default matcher. Fixes tina4-book#125. +45 new tests across the four suites.
- **fix (gallery / python+php+ruby):** Gallery Try-It / View buttons now open the deployed example in a new tab (`window.open(url, '_blank')`) instead of navigating away from the gallery home. Fixes tina4-book#115.
- **fix (ruby gemspec):** `sqlite3` promoted from `add_development_dependency` to `add_dependency`. Matches the "zero-config SQLite on first run" promise. Fixes tina4-book#100.
- **docs (tina4-book):** PHP Chapter 2 updated — correct port (7145), `->noAuth()` on write-method examples, and an explicit callout explaining the secure-by-default policy for POST/PUT/PATCH/DELETE. Addresses tina4-book#87, #94, #123.
- **docs (tina4-book):** Python `@template` decorator ordering corrected (must sit BELOW the route decorator) in book chapters 04 and 10; Python `request->query` vs `request->params` distinction in PHP chapter 1.
- **tests (python):** Session-handler tests updated to reflect the real default TTL of 3600s (were stale at 1800s).
- **verified already fixed in earlier 3.11.x releases** — closed comments posted on all of these:
<div v-pre>

  - #79 dotted numeric index (`{{ items.0.name }}`)
  - #80 `truncate` filter
  - #82 `{{ parent() }}` / `{{ super() }}` across all 4 frameworks
  - #83 Ruby dashboard — WEBrick is runtime dep
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
- **fix (python):** `_ensure_folders` no longer creates a bogus `src/migrations/` directory. The migration runner always looks at `migrations/` at the project root — there is only one correct location.
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

- **fix (php):** Hot-reload loop — DevAdmin's polling fallback used `mt=0` as the baseline, so the first poll after every page load triggered `location.reload()`, which reset `mt=0` again. Loop now initialises the baseline on the first poll.
- **fix (php):** Reload sentinel removed — PHP was the only framework recursively walking `src/` and touching `src/.reload_sentinel` on every reload POST. The sentinel lived inside the Rust CLI's watched tree and fed back into the watcher, triggering a second loop. Replaced with the same in-memory counter used by Python/Ruby/Node.
- **fix (php):** Polling no longer starts more than once when the WebSocket reconnect retry budget is exhausted (added a `pollStarted` guard).
- **feat (parity):** `GET /__dev/api/queue/topics` and `GET /__dev/api/queue/dead-letters` added to PHP, Ruby and Node (previously only in Python). PHP queue endpoints now read from the real `Tina4\Queue` backend instead of returning stubs.
- **feat (devadmin):** Refreshed `tina4-dev-admin.js` bundle (87.8 KB) across all 4 frameworks — adds the topic selector dropdown, inline payload expand/copy, and corrected version display.
- **tests:** 4-way parity tests for hot-reload: mtime starts at 0, POST /__dev/api/reload bumps the counter, no sentinel file is written to disk, mtime is monotonic across successive reloads. Mirrored in `tina4-php/tests/DevAdminTest.php`, `tina4-python/tests/test_dev_admin.py`, `tina4-ruby/spec/dev_admin_spec.rb`, `tina4-nodejs/test/devAdmin.test.ts`.
- **parity:** All 4 frameworks bumped to 3.11.10.


## v3.11.9 (2026-04-15)

Catch-up release covering v3.11.0 → v3.11.9 across all 4 frameworks.

- **feat (websocket):** Full WebSocket parity across Python/PHP/Node/Ruby — `get_client_rooms()` / `getClientRooms()`, `route()` usable as decorator or direct handler registration, matching room/broadcast semantics, plus new parity tests on all 4.
- **feat (graphql):** Input validation and field-level `@auth` directives with context threading.
- **feat (graphql):** Auto-discovery of schemas; removed legacy DevAdmin HTML/JS in favour of the new UI.
- **feat (devadmin — Python):** Queue tab with topic selector, dead-letter listing and replay endpoints, inline payload expand/copy, version display.
- **feat (cli):** Rust CLI now owns file watching — frameworks receive `POST /__dev/api/reload` and internal watchers are disabled when launched by the Rust CLI (`--managed`).
- **fix (cli):** `parseFlags` / `parse_flags` / `parseCliArgs` no longer swallow `host:port` or positional args after boolean flags.
- **fix (scss):** SCSS recompilation loop fixed; output path corrected to `src/public/css/` to match CLI and static serving.
- **fix (frond — Python):** Numeric dotted index for lists (`items.0.name`) now resolves correctly.
- **fix (router — Ruby):** Bare `/*` wildcard capture exposed under `"*"` key for parity.
- **fix (orm — PHP):** Three data-sync bugs fixed: `load()` double-fill, `getPrimaryKeyValue`, `save()` ID sync.
- **fix (graphql):** `from_orm` / `fromOrm` list resolver used `select(skip=)` instead of `all(offset=)`.
- **fix (metrics):** Windows backslash paths normalised to forward slashes.
- **fix (app — PHP):** No longer crashes on notices/deprecations in loaded files; `run()` now prints the banner when starting the server directly.
- **chore:** Example demo store ships with the repo; Windows-friendly setup; `.env.example` and setup scripts added.
- **parity:** All 4 frameworks bumped to 3.11.9. PHP aligned to the 3.x tag scheme on `v3`.

## v3.10.99 (2026-04-12)

- **breaking:** `autoMap` now defaults to `true` — ORM models automatically map between camelCase properties and snake_case DB columns. Set `public bool $autoMap = false;` on your model to restore the old behaviour.
- **breaking:** `all()` now returns a flat array of model instances instead of `['data' => [...], 'total' => N, ...]`. Use `count()` separately if you need the total.
- **feat:** `toDict(include, case)` parameter — pass `case: 'snake'` to get snake_case keys matching DB columns, or `case: 'camel'` (default) for camelCase.
<div v-pre>

- **feat:** Frond `replace` filter now accepts dict args — `{{ v|replace({"T": " ", "-": "/"}) }}` for multiple substitutions in one call.
- **feat:** `$app->background(callback, interval)` — register periodic tasks that run cooperatively in the `stream_select` event loop. No threads, no separate processes.
- **feat:** Background timing guard — warns when callbacks exceed their interval, helping developers identify blocking operations.
- **feat:** WebSocket room management moved to `Server` class — `joinRoom()`, `leaveRoom()`, `broadcastToRoom()` now work reliably via `WebSocketConnection->server`.
- **feat:** Docker image now bundles the example store demo — `docker run tina4stack/tina4-php:v3` starts a working app out of the box.
- **fix:** AutoCrud updated for new `all()` return format.
- **fix:** Cart nav badge now updates reactively on quantity change and item removal.
- **fix:** Non-blocking queue consumer — `processOrders()` uses `$queue->pop()` instead of blocking `$queue->consume()`.
- **tests:** 6 new parity tests covering `toDict(case:)`, `autoMap` default, `replace` filter (dict + positional), and `background()` registration. 2,345 tests passing.
- **parity:** All features shipped identically across Python, PHP, Ruby, Node.js.

</div>

## v3.10.97 (2026-04-11)

- **fix:** frond.form.submit redirect handling — XHR follows 3xx redirects transparently; fixed by detecting `xhr.responseURL` mismatch and navigating instead.
- **dep:** Updated frond.min.js to v2.1.2.
- **parity:** All 4 frameworks bumped to 3.10.97.

## v3.10.93 (2026-04-11)

- **fix:** Frond bracket depth tracking in `findOutsideQuotes()` and `splitOutsideQuotes()` — expressions like `$arr[$i % 2]` no longer treated as top-level arithmetic.
- **fix:** Frond subscript expression evaluation — bracket content uses `evaluateExpression()` instead of `resolveVariable()`, enabling `arr[loop.index0 % 2]`.
- **fix:** Frond slice with variable bounds — `items[start:end]` evaluates bounds through `evaluateExpression()`.
- **docs:** Developer skills updated — Metrics Dashboard guidance, Frond Template Parity rules, `@noauth` security warnings.
- **parity:** All Frond fixes applied identically across Python, PHP, Ruby, Node.js. 2,339 tests passing (263 Frond).

## v3.10.92 (2026-04-10)

- **feat:** Add `RateLimiterMiddleware` class with `beforeRateLimit()`, `check()`, `reset()` static methods.
- **breaking:** Rename `ErrorOverlay` methods — `render()` → `renderErrorOverlay()`, `renderProduction()` → `renderProductionError()`.
- **feat:** Add `Server::handle(Request $request): Response` for cross-framework parity.
- **feat:** Add `DatabaseResult::size()` method.
- **breaking:** Rename `WebSocketBackplane::create()` → `WebSocketBackplane::createBackplane()`.
- **feat:** Add `DevAdmin::health()` method.
- **feat:** Add `ScssCompiler::compileScss()` method.
- **fix:** Add `DatabaseSessionHandler::delete()` delegating to `destroy()`.
- **fix:** `SmokeTest` — pass secret explicitly to `Auth::getToken()` to fix test ordering issue.
- **parity:** 44/44 cross-framework features green. 2,305 tests passing.

## v3.10.91 (2026-04-10)

- **feat:** Add parity methods — `GraphQLType::parse()`, `Response::send()` params, `MCP::registerRoutes()` optional router.
- **breaking:** Rename `from()` → `fromTable()`, `template()` → `render()` — align with Python canonical names.

## v3.10.90 (2026-04-09)

<div v-pre>

- **docs:** Chapter 4 (Templates) — new "Dumping Values for Debugging" section covering both `{{ $x|dump }}` and `{{ dump($x) }}` forms, their shared `<pre>var_dump()</pre>` output, and the `TINA4_DEBUG=true` production gate. Filter table entry updated to reference the new section.
- **docs:** `plan/parity/parity-template.md` updated with a cross-framework dump helper comparison table and marks dump parity as confirmed across all 4 frameworks at v3.10.89.
- **chore:** Version sync release — brings all 4 frameworks to the same patch version (3.10.90) so downstream users can upgrade PHP/Python/Ruby/Node.js in lockstep without hunting version mismatches.

</div>

## v3.10.89 (2026-04-09)

<div v-pre>

- **feat:** `{{ dump(value) }}` global function form added to Frond alongside the existing `{{ value|dump }}` filter. Both call a single `Frond::renderDump()` helper and produce identical output (`<pre>var_dump()</pre>`).
- **security:** Dump is now **gated on `TINA4_DEBUG=true`**. In production (env var unset or `false`) both the filter and function silently return an empty string. This prevents accidental leaks of internal state, object shapes, and sensitive values into rendered HTML when a developer leaves a `{{ dump($x) }}` call in a template.
- **test:** 4 new tests in `FrondTest.php` covering debug-mode output, production silencing, function/filter parity, and function-form production silencing.

</div>

## v3.10.87 (2026-04-09)

- **fix:** Dev toolbar no longer vanishes after a hot-reload. `Server::onFilesChanged()` used to call `Router::clear()` and then loop `include_once` over every `.php` file in `src/routes/`. Because `include_once` is a no-op for already-included files, routes were never re-registered after a template/CSS/JS edit — subsequent requests fell through to the 404 handler and the dev toolbar injection was lost. The router is now left intact on template/asset edits (Frond re-reads templates in dev mode, static files are served from disk per request, so nothing else needs to move). PHP file edits log a warning that a full server restart is required (classes cannot be redeclared in-process).
- **fix:** This also resolves a related issue where rapid browser refreshes during hot reload would return 500s — the router wipe left a brief window with zero routes registered.

## v3.10.86 (2026-04-09)

- **feat:** `$foreignKeys` property on `ORM` auto-wires both sides of a foreign key relationship. Declaring `public array $foreignKeys = ['user_id' => 'User']` injects a `belongsTo` accessor (`$post->user`) on the declaring model and a `hasMany` accessor (`$user->posts`) on the referenced model via a cross-model FK registry. Extended form supports a custom has-many key: `['user_id' => ['model' => 'User', 'related_name' => 'blog_posts']]`.
- **feat:** Cross-framework parity — same FK auto-wiring semantics now available in Python (`ForeignKeyField`), Ruby (`foreign_key_field`), and Node.js (`type: "foreignKey"`)
- **docs:** Chapter 6 (ORM) updated with a new "$foreignKeys — Auto-Wired Relationships" section

## v3.10.85 (2026-04-09)

- **fix:** Removed duplicate `Job` class from `Queue.php` — canonical definition is `Job.php` only
- **fix:** `Job.php::fail()` now delegates to `writeFailed()` instead of calling private `getBasePath()` directly

## v3.10.84 (2026-04-09)

- **fix:** Router/middleware was setting `request.user` / `request.auth` / auth payload to `true` (boolean) instead of the actual JWT payload after `validToken()` was changed to return bool — any code reading `request.user["sub"]` etc. would have failed silently or crashed
- **fix:** CSRF middleware was not correctly rejecting invalid tokens (nil check on bool result always passed)
- **fix:** `toObject()` declared wrong return type (`array` vs actual `object`)
- **fix:** Router `request.user` and gallery auth verify endpoint updated for bool `validToken`
- **add:** Headless routing auth payload integration tests to prevent regression

## v3.10.83 (2026-04-08)

- **fix:** CORS headers now set before auth short-circuit (#106)
- **fix:** ORM find/all/where no longer crash with DatabaseResult object (#108)
- **fix:** toObject() returns stdClass, not array (#107)
- **fix:** Firebird absolute path no longer strips leading slash (#101)
- **feat:** WebSocket rooms — joinRoom, leaveRoom, broadcastToRoom, getRoomConnections, roomCount
- **feat:** queue signature parity — instance-scoped, no topic params on public methods
- **feat:** auth alias cleanup — removed createToken/validateToken aliases

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


## Version History

Tina4 PHP follows semantic versioning. The major number changes when something breaks. The minor number changes when something new arrives. The patch number changes when something gets fixed. Each release is available on Packagist.

This chapter covers the full v3 line -- from the first release candidate through the current stable release. If you are upgrading from v2, read Chapter 36 first. It covers every breaking change and gives you a migration checklist.

---

## v3.10.68 (2026-04-03) — Full Parity Release
- **100% API parity** across Python, PHP, Ruby, Node.js — 30+ issues fixed
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
- **load() returns bool** — `$model->load($sql, $params)` calls selectOne internally, populates the instance, returns `true`/`false`. Use `findById()` for PK lookups
- **api.upload()** added to tina4-js — sends FormData with Bearer token auth for multipart file uploads
- **ORM CLAUDE.md rewrite** — all method stubs now match actual API signatures
- **File upload docs** — `$request->files` format documented in CLAUDE.md

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
- **tina4 console** — interactive PHP REPL with framework loaded ($db, $app, Router, Auth)
- **tina4 env** — interactive environment configuration
- **Brand update** — "TINA4 — The Intelligent Native Application 4ramework"
- **Dynamic version** — reads from composer metadata at runtime, no hardcoded constant
- **Packagist v2 API** — version checker uses repo.packagist.org
- **@noauth docblock** — annotations now affect dispatch (#114)
- **Port kill-and-take-over** — default port always reclaimed
- **MongoDB adapter** (ext-mongodb), **ODBC adapter** (pdo_odbc)
- **Pagination standardized** — limit/offset primary, merged dual-key response
- **#101** Firebird paths, **#102** autoMap uppercase, **#104** TINA4_DATABASE_URL, **#105** CORS fix

---

## v3.10.57 (2026-04-02)
- **MongoDB adapter** — `Database("mongodb://host:port/db")`, requires ext-mongodb
- **ODBC adapter** — `Database("odbc:///DSN=MyDSN")` via pdo_odbc
- **Pagination standardized** — limit/offset primary, merged dual-key toPaginate() response
- **Test port at +1000** — user testing port (e.g. 8146) stable, no hot-reload
- **Dynamic version** — read from composer metadata, no hardcoded constant
- **Packagist v2 API** — version checker uses repo.packagist.org/p2/
- **#101** FirebirdAdapter path parsing preserves absolute paths
- **#102** ORM snakeToCamel handles uppercase columns
- **#104** ORM ensureDb() auto-discovers TINA4_DATABASE_URL
- **#105** CorsMiddleware matches request origin correctly
- **#114** @noauth docblock annotations now affect dispatch
- **108 features at 100% parity**, 2,220 tests

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** — second socket on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **#101** FirebirdAdapter path parsing preserves absolute paths
- **#102** ORM snakeToCamel handles uppercase columns (Firebird/Oracle)
- **#104** ORM ensureDb() auto-discovers TINA4_DATABASE_URL
- **#105** CorsMiddleware matches request origin correctly
- **SQLite commit()** no-op without transaction
- **Gallery fixes** — SQLite paths, auth bypass
- **QueryBuilder docs** — added to ORM chapter

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

<div v-pre>

**Frond template engine** — Fixed string concatenation (`~` operator) and inline if/else expressions (`{{ 'yes' if active else 'no' }}`). A greedy quoted-string fallback in `evaluateLiteral()` was treating compound expressions as single string literals.

</div>

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# AFTER:  pbkdf2_sha256$100000$salt$hash

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

tina4 ai

# Install for all known AI tools

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

tina4 ai --all

# Overwrite existing context files

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

<div v-pre>

Macro output was getting HTML-escaped when used inside expressions. A `{% macro %}` that returned HTML would render as visible `&lt;div&gt;` tags instead of actual markup. This patch marks macro output as safe, matching standard Twig behaviour.

</div>

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

composer require tina4stack/tina4php

# v3

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

**Environment variable rename.** `TINA4_AUTOCOMMIT` became `TINA4_AUTOCOMMIT` (no underscore between AUTO and COMMIT).

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
