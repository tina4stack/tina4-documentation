# Chapter 35: Release Notes

## v3.13.1 (2026-06-02)

Cross-framework parity patch. Closes the remaining audit-flagged docs-vs-code gaps that didn't make 3.13.0 — the documentation claimed APIs across PHP / Ruby / Node that only Python had. This release ships those APIs everywhere and rewrites the PHP chapters that referenced fictional symbols.

### Convenience parity additions (Groups A / B)

Three highest-impact cross-framework methods every documentation set already claimed existed. PHP / Ruby / Node now match Python:

- **`db.fetchAll(sql, params)` / `db.fetch_all` / `$db->fetchAll`** — returns the records list directly. Symmetric with `fetch_one`. For the 80% case where you don't need the `DatabaseResult` metadata.
- **`Database.getConnection(url)` / `.get_connection` / `::getConnection`** — classmethod factory matching SQLAlchemy's `engine.connect()`. Falls back to in-memory SQLite when no URL or env resolves.
- **`Api(bearerToken=, username=, password=, headers=, verifySsl=)` ergonomic kwargs** — three setter calls collapse to one constructor. Bearer wins over basic-auth when both are passed. `verifySsl=False` is the positive form of `ignoreSsl=true`.

### Decorator-style GraphQL resolvers across the family

Python `@GraphQL.resolve` shipped in 3.13.0. This release adds:

- **PHP** — `GraphQL::resolve("Type", "field", $callable)` static method + class-level resolver registry that `new GraphQL()` drains into its schema.
- **Ruby** — `Tina4::GraphQL.resolve("Type", "field") { |root, args, ctx| ... }` with block-based registration.
- **Node.js** — `GraphQL.resolve(typeName, fieldName, resolver)` matching the cross-framework shape.

All four frameworks now support the FastAPI / Strawberry / Ariadne pattern where resolvers register at module-import time before any `GraphQL` instance is constructed, and where post-startup registrations land in the active default singleton via `setDefault(gql)` / `Tina4::GraphQL.default_instance = gql`.

### Class-based service pattern across the family

`class FooWorker extends Service { run() { ... } }` — chapter 27 / equivalent docs have long taught this pattern. Until 3.13.1, only the runner was real:

- **PHP** — new `Tina4\Service` abstract base class + `ServiceRunner::registerService($name, $service)` static helper.
- **Ruby** — new `Tina4::Service` class + `Tina4::ServiceRunner.register_service(name, service)`.
- **Node.js** — new `Tina4Service` abstract class + `ServiceRunner.registerService(name, service)`.
- **Python** — new `tina4_python.service.Service` base + `ServiceRunner.register_service(name, service)` (this release closes the gap; Python had only the function-style runner before).

All four ship `run()` (abstract), `stop()`, and `should_stop()` / `shouldStop()` helpers backed by an internal flag. Function-style services using bare callables continue to work alongside the new class-based pattern.

### PHP chapter rewrites (`docs/php/` and `book-2-php/`)

The 3.13.0 audit found that the PHP testing-chapter disaster was the tip of a larger pattern — multiple PHP chapters taught APIs that didn't exist. 3.13.1 rewrites all seven of them:

- **Chapter 15 — Logging** — primary surface now `Tina4\Log::info()/warning()/error()` instead of the legacy `Tina4\Debug::message()` shim (still works).
- **Chapter 18 — Testing** — `$response->statusCode` → `$response->status` across 23 occurrences; CLI section updated (`tina4 test` runs the suite; `vendor/bin/phpunit` for targeted runs).
- **Chapter 19 — Scaffolding** — v2 `Tina4\Get::add()` / `Post::add()` / `Put::add()` / `Delete::add()` syntax replaced with `Tina4\Router::get/post/put/delete`; fictional `->description()` chain replaced with real `->swagger([...])`.
- **Chapter 22 — GraphQL** — chapter's decorator pattern (`GraphQL::resolve("Type", "field", $fn)`) now matches real source (built this release).
- **Chapter 25 — WSDL** — `@wsdl_operation` docblock replaced with `#[WSDLOperation([...])]` PHP attribute; methods now return associative arrays matching the response-shape spec; `Router::soap()` → `Router::any()` + manual `(new Service($request))->handle()`.
- **Chapter 27 — ServiceRunner** — `new ServiceRunner()` + `->add()` instance API replaced with `ServiceRunner::registerService()` + `ServiceRunner::start()` static API. The `Tina4\Service` base class the chapter teaches now exists.
- **Chapter 34 — Deployment** — un-prefixed env vars (`SECRET`, `CORS_ORIGINS`, `SMTP_USER`, `JWT_SECRET`, `API_KEY`, `SWAGGER_TITLE`) replaced with `TINA4_`-prefixed forms. The v3.12 boot guard rejects the legacy names with `exit(2)`.

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

Drop-in patch — no breaking changes. Existing source-code patterns from 3.13.0 continue to work; the new methods are additive. Documentation rewrites in chapters 15 / 18 / 19 / 22 / 25 / 27 / 34 redirect copy-paste examples to the real APIs the framework actually ships.

## v3.13.0 (2026-06-01)

The docs-vs-code parity release. A cross-framework audit of 381 markdown files surfaced 146 hallucinations, signature drifts, and stale references across Python, PHP, Ruby, Node, and tina4-js. 3.13.0 closes the chapter-18 disaster pattern — where documentation taught a class-based API that didn't exist — by shipping the missing pieces, renaming the misnamed pieces, and rewriting the aspirational chapters.

### The headline fire: `Test` class with HTTP helpers

Every framework's chapter 18 has long shown integration tests like:

```python
class UserApiTest(Test):           # tina4_python.test.Test
    def test_health(self):
        resp = self.get("/health")
        assert_equal(resp.status, 200)
```

Until 3.13.0, only `Test` (the bare assertion base) existed — calling `self.get(...)` crashed with `AttributeError`. The HTTP test client lived in a separate `TestClient` class that the docs never mentioned.

This release mixes `TestClient.get / post / put / patch / delete` into the `Test` base across every framework:

- **Python** — `tina4_python.test.Test` (extends `unittest.TestCase`, pytest auto-discovers)
- **PHP** — `Tina4\Test` (extends `PHPUnit\Framework\TestCase`)
- **Ruby** — `Tina4::Test` (zero-dep; built-in `run_all` runner)
- **Node.js** — `Tina4Test` (zero-dep; built-in `Tina4Test.runAll()` runner)

Plus positional assertions on every framework — `assertEqual(actual, expected, message)`, `assertNotEqual`, `assertTrue`, `assertFalse`, `assertNull`/`assertNullValue`, `assertNotNull`/`assertNotNullValue`, `assertRaises` — matching the documented `(actual, expected, message)` shape.

### `Auth.valid_token` now returns the payload, not a bare bool — **BREAKING**

The most common silent-fail pattern caught by the audit. Every framework's docs claimed `valid_token` returned the decoded JWT payload; every framework's source returned `bool` and forced a second `get_payload` call.

| Framework | Before | After |
|---|---|---|
| Python | `Auth.valid_token(token) → bool` | `Auth.valid_token(token) → dict \| None` |
| PHP | `Auth::validToken(token) → bool` | `Auth::validToken(token) → array \| null` |
| Ruby | `Auth.valid_token(token) → Boolean` | `Auth.valid_token(token) → Hash \| nil` |
| Node | `validToken(token) → boolean` | `validToken(token) → Record<string, unknown> \| null` |

Matches PyJWT / firebase-jwt-ruby / firebase/php-jwt / jsonwebtoken conventions. Truthy/falsy contract preserved — existing `if (validToken(t))` callers keep working because a non-null object is truthy and null is falsy.

### Python-specific groups (mirrored to PHP/Ruby/Node in follow-up patches)

The Python framework is the reference per `feedback_python_master`. Six groups landed in tina4-python:

- **Group A — ergonomic additions**: `Database.get_connection()`, `db.fetch_all()`, `db.pool`, `DatabaseResult.columns`, `Job.error`, `Queue.produce(delay_until=datetime)`, module-level `migrate(db)`/`rollback(db)`/`status(db)`, module-level `i18n.t()`, dict-style `session[key]`, `WebSocketConnection.connection_count`. All zero-risk additions — no signatures changed.
- **Group B — signature expansions**: `Api(bearer_token=, username=, password=, headers=, verify_ssl=)` kwargs, `Model.find(pk)` int overload (Active Record convention), `@description(summary, detail=, params=, query=)`, `@tags(str | list)`, `@example_response(status_code, data)`, `response.render(template, data, status_code)`, `response.cookie(name, value, options_dict)`, `response(data, headers={})`, `@get(path, description=, middleware=["ResponseCache:300"])` with string-form middleware parser.
- **Group C — mixins + decorators**: the Test HTTP mixin (covered above), `Frond.add_filter / add_global / add_test` callable as classmethod OR instance method via a `_ClassOrInstanceMethod` descriptor, `@GraphQL.resolve("Type", "field")` decorator with class-level registry — chapter 22's pattern now works as documented.
- **Group D — return-type changes (BREAKING)**: `Container.reset()` now clears singleton cache only (factories survive); new `Container.reset_all()` for the old wipe-everything behaviour. `queue.dead_letters()` returns `list[Job]` with `.error` populated, not `list[dict]`. `Model.where(..., with_count=True)` returns `(list, int)` tuple for pagination UIs.
- **Group E — renames (BREAKING)**: `ai.install_all()` → `ai.install_context()`; new `ai.detect_ai()`, `ai.detect_ai_names()`, `ai.status_report()`. `queue.consume(id=)` → `queue.consume(job_id=)`. `Api.send_request()` → `Api.send()`. `I18n(locale=, path=)` preferred over `I18n(locale_dir=, default_locale=)` (legacy kept). `TINA4_TOKEN_EXPIRES_IN` preferred over `TINA4_TOKEN_LIMIT` for JWT expiry (both honoured; new wins; constructor arg overrides both).
- **Group F — top-level re-exports + scaffolder**: `from tina4_python import Api, WSDL, wsdl_operation, GraphQL, AutoCrud, Messenger, on, emit, once, off, tests` now resolve. `Model.select()` with no args defaults to `SELECT * FROM <table>` so the CRUD-list scaffolder template's emitted code actually runs.

### PHP-specific: `Tina4\Debug` shim

Chapter 15 of the PHP logging docs taught `Tina4\Debug::message($msg, TINA4_LOG_INFO, [...])`. Neither the class nor the constants existed. Real logger is `Tina4\Log`.

This release ships a `Tina4\Debug` compatibility shim that forwards to `Tina4\Log`, plus defines the `TINA4_LOG_*` level constants — so the chapter's code samples run as-written. For new code, prefer `\Tina4\Log::info()` etc.

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
- **Security fix**: `Auth.check_password(hash, password)` → `(password, hash)` in skill ref — the bcrypt comparison was returning False every time due to reversed args (silent-failure auth)
- `request.files['content']` is **raw bytes** — drop `base64.b64decode()` from upload examples
- Deployment chapter env vars all `TINA4_`-prefixed (un-prefixed names brick boot under v3.12 guard)

### Aspirational chapters rewritten

Two Python chapters were built on APIs that didn't exist:

- **Chapter 22 (GraphQL)**: rewritten around the new `@GraphQL.resolve("Type", "field")` decorator (the FastAPI/Strawberry pattern). The previous `gql.schema.add_query("name", {dict})` form still works but is no longer the primary documented path.
- **Chapter 25 (WSDL)**: rewritten around the real subclass pattern (`class Calculator(WSDL): @wsdl_operation({"Result": int}) def Add(self, ...): ...; Calculator(request).handle()`). The previous `WSDL(service_name=, namespace=, endpoint=)` constructor + `handle_wsdl` / `handle_request` API was entirely fictional.

### tina4-js doc drift caught

The cross-framework audit's synthesis pass dropped tina4-js findings; the raw agent transcripts had 23 real findings:

- Every import in CLAUDE.md and `docs/js/09-graphql.md` used `"tina4-js"` (with hyphen). The npm package is named `tina4js`. Fixed.
- `pwa({...})` was treated as callable; real API is `pwa.register({...})`. `PWAConfig.icon` is a single string, not an `icons: [...]` array.
- `static props = { label: { type: String, default: "..." } }` — the `{ type, default }` wrapper is fictional. Real shape is `static props = { label: String }`.
- `router.navigate('/users/42')` — `navigate` is a top-level export, not a method on `router`.
- Chapter 14's `<slot>` inside a `static shadow = false` component — slots are a Shadow DOM feature. Chapter 14 contradicted chapter 4. Switched to `shadow = true`.

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

`Auth.validToken` is the breakage to know about — your `if Auth::validToken($t)` style code keeps working unchanged because non-null arrays are truthy and null is falsy. If you do `=== true` / `=== false` strict comparisons, switch to `!== null` / `=== null`.

Python: `ai.install_all()` → `ai.install_context()`, `queue.consume(id=)` → `consume(job_id=)`, `Api.send_request()` → `Api.send()`, `Container.reset()` semantic change (use `reset_all()` for old behaviour).

Everything else is additive — new properties, new kwargs, new convenience methods that match what the docs have promised for years.

## v3.12.14 (2026-06-01)

Two independent fixes ship together as 3.12.14. **Python** — the `tina4_python.test` class-based xUnit testing surface that the chapter 18 documentation has always promised but never actually existed. Reports came in of developers copy-pasting `from tina4_python.test import Test, assert_equal, assert_true` straight out of the book and getting `ModuleNotFoundError`. The fix was to build the module to match the documentation, not the other way around. **PHP** — `:named` placeholder translation for the four non-PDO adapters where `ORM::save()` was silently failing.

### Python — `tina4_python.test` xUnit testing surface

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

The module did not exist. Every developer who followed the chapter hit an immediate import error. The other surface, `tina4_python.Testing` with the inline `@tests` decorator, has always existed — but the two are for different purposes and the docs only documented one of them.

The fix ships the missing module — `tina4_python/test/__init__.py` — with the `Test` base class (inherits `unittest.TestCase`, so pytest discovers any subclass regardless of class-name convention) and 13 positional assertions. The signatures are uniform: `(actual, expected, message)`. The 2-arg legacy `(value, message)` form keeps working — a type-based dispatch detects which shape the caller used. `assert_raises` accepts three forms: docs form (`callable, exception, message`), context-manager form (`with assert_raises(X):`), and unittest order (`exception, callable`). Lifecycle hooks come in both flavours — snake_case `set_up`/`tear_down` (the Tina4 idiom) and camelCase `setUp`/`tearDown` (for users coming from unittest) — without double-calling when a subclass uses either one.

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

PHP / Ruby / Node testing chapters already teach native conventions correctly — PHPUnit, RSpec, and `node:test` respectively. No fake API to fix. The Python-specific gap was that Tina4 had two testing surfaces (`tina4_python.Testing` for inline `@tests` decorator, `tina4_python.test` for class-based suites) and only one of the two existed. The other three frameworks defer to a single native runner each, so the same trap doesn't apply.

### PHP — :named placeholder translation across non-PDO adapters

The ORM's `save()` emits `:named` placeholders because PDO would accept them. Four of the five PHP database adapters do not use PDO. `MySQLAdapter` (mysqli), `MSSQLAdapter` (sqlsrv), `FirebirdAdapter` (ibase/fbird), and `PostgresAdapter` (pgsql) all bind positionally. Every INSERT/UPDATE through `save()` against those four engines failed silently. Reads worked because read paths typically use `?` or no params.

A single helper, `SqlTranslation::namedToPositional($sql, $params)`, translates `:name` to `?` and reorders `$params` to match the SQL order. Wired into the four affected adapters at the top of their prepare/execute paths. The helper skips string literals and SQL comments, so a literal `:colon` inside a value stays as a value. Duplicate names bind once per occurrence, so `WHERE id = :id AND parent_id = :id` works as expected.

`SQLite3Adapter` is untouched. ext-sqlite3 natively accepts `:name` via `SQLite3Stmt::bindValue`. The other four did not, and now do.

15 unit tests pin the helper in `tests/SqlTranslationNamedToPositionalTest.php`: order preservation, duplicate names, quoted strings, line and block comments, unknown placeholders, null values, and the `0`-as-value case. Full PHP suite: 2,290 passing.

### Cross-framework parity check (`:named` placeholders)

Python (`mysql-connector-python` uses `%s`), Ruby (`mysql2` uses `?`), and Node (`mysql2` uses `?`) build their INSERT/UPDATE SQL with positional placeholders from the ORM down. No `:named` ever emitted. Audited the MySQL adapter and `save()` path in each before shipping; confirmed clean. PHP-only fix.

### Upgrade

Drop in for both Python and PHP. No `.env` changes, no API changes.

**Python users** who followed chapter 18 and hit `ModuleNotFoundError` — bump to `3.12.14`, the `from tina4_python.test import Test, assert_equal, ...` import now resolves. Existing tests written against `tina4_python.Testing` (the inline `@tests` decorator) continue to work — that surface was not touched.

**PHP users** — `:named` and `?` both work, and the framework picks the right form for whichever driver is underneath. Existing ORM `save()` calls start succeeding on MariaDB/MySQL, PostgreSQL, MSSQL, and Firebird.

**Ruby and Node users** — no framework change shipped in 3.12.14. Stay on `3.12.13` or bump to `3.12.14` for version alignment. Both are functionally identical.

## v3.12.13 (2026-05-29)

Consolidated parity release. PHP ran ahead through two independent patch releases (3.12.11–3.12.12) while Python / Ruby / Node stayed at 3.12.10. This release realigns all four frameworks on **3.12.13** and ships the cross-framework dev-admin parity sweep — five tiers of work that bring PHP, Ruby and Node up to Python's AI-assisted development surface.

### Cross-framework dev-admin parity sweep (Tier 1–5)

The Python framework had pulled ahead on a series of dev-admin features driven by real frustration with the AI coder loop ("Applying a small patch went and messed up my whole file", "Says it is creating files but then doesn't", repeated import-error spirals). This release ports the full set to PHP, Ruby, and Node — same intent, language-idiomatic implementations.

**Tier 1 — MCP defensive write layer.** `file_write` and `file_patch` now refuse prose-as-filenames (the LLM occasionally emits `## FILE: I'll implement Step 1 by creating the database migration` and the parser used to write a zero-byte file with that sentence as its filename), normalise bare top-level `routes/` / `orm/` / `templates/` / `seeds/` / `controllers/` / `middleware/` paths to their canonical `src/<dir>/` form (auto-discovery only scans `src/`, so a file at `templates/foo.twig` was dead weight), back up existing files to `.tina4/backups/<flat-path>.<ISO-ts>.bak` before overwrite, and refuse suspicious truncations (>200B file → <30% size = almost always a truncated LLM response). Every attempt logs to `.tina4/agent.log` with a structured category (`write.ok` / `write.refused` / `write.path_normalized` / `write.import_failed`) — the supervisor reads that file on every turn so it sees what broke last time and can self-correct without asking the developer "what's the error?".

**Tier 2 — Post-write syntax verification.** PHP shells out to `php -l`, Ruby to `ruby -c`, Node to `node --check` (and single-file `tsc --noEmit --allowJs --skipLibCheck` for `.ts`). On parse error the tool result gets an `import_error` field AND a `write.import_failed` log entry surfaces in the next supervisor turn's failure context. Catches hallucinated framework APIs (`CharField` doesn't exist in `tina4_python.orm.fields` — should be `StrField`; `auto_now_add` keyword on `Field.__init__()`) at write time instead of letting them propagate to a runtime 500 the user only discovers by hitting the URL.

**Tier 3 — `/__dev/api/threads` + `/__dev/api/chat` proxy.** The SPA now talks to the Rust supervisor agent the same way regardless of framework. `_supervisor_base_url()` matches Python's 4-step ladder (`TINA4_SUPERVISOR_URL` → `TINA4_AGENT_PORT` → `PORT+2000` → `9145`). `active_file` rides through `/chat` POST verbatim so deictic phrases ("fix this", "explain this") bind to the editor's open file without the supervisor asking. The Node port forwards SSE chunks as they arrive; PHP and Ruby buffer (functional — EventSource parses fine — but feels less snappy until a future round of Rack/PHP-FPM streaming work).

**Tier 4 — Customer feedback widget.** A floating bubble for end-users of a shipped Tina4 app, gated by `TINA4_ENABLE_FEEDBACK=true` AND a non-empty `TINA4_FEEDBACK_WHITELIST`. The framework's response middleware injects `<script src="/__feedback/widget.js" data-tina4-feedback></script>` immediately before the LAST `</body>` tag on text/html responses, ONLY for whitelisted users, NEVER on `/__dev` or `/__feedback` paths (no double-bubble UX on the developer dashboard). One conversational turn at a time POSTs to `/__feedback/api/turn` → server-side identity stamp from the verified JWT (clients cannot fake `sender`) → forward to the Rust agent's intake-only agent (zero tools, JSON-only output). Finalised tickets land in the dev admin sidebar with `kind:"feedback"`. Rate-limited at 5 turns/hour per user.

**Tier 5 — Stale-source overlay badge + `list_plans()` merge.** The error overlay now stamps `captured_at` on render and tags each stack frame whose source file has been modified since: "FILE MODIFIED @ HH:MM:SS UTC — source may not match what failed". Stops the user from chasing ghosts when the AI coder rewrote the file between the error and the page reload. `list_plans()` reads from BOTH `plan/` (user-curated canonical) AND `.tina4/plans/` (AI-planner output), dedupes by filename with `plan/` winning on collision, sorts newest-first, and returns a `path` field so the SPA can open the right file regardless of source dir.

**Test counts.** Per-framework deltas across the sweep:

| Framework | Before → After (full suite) |
|---|---|
| Python | 2453 → 2453 (canonical — no new tests, just released) |
| PHP | 2235 → 2714 (+479) |
| Ruby | 2747 → 2800 (+53) |
| Node | 3263 → 3368 (+105) |

PHP's larger delta reflects new tests + the 3.12.11 + 3.12.12 lineage rolling forward.

**Why all four frameworks at once.** Per the cross-framework parity rule: a feature that exists in only one framework is technical debt. The Python-only Tier 1–5 surface had been accumulating for two weeks while the UX was settling. With it settled, this release closes the gap in one coordinated sweep.

### Folded-in from PHP 3.12.11 — file upload regression (`tina4-book#139`)

`WebSocket::parseHttpHeaders()` previously split the entire raw HTTP request on `\r\n` and iterated every line for a `:` to fill the headers map. Multipart body parts have their own `Content-Type`, `Content-Disposition`, and `Content-Transfer-Encoding` headers — those lines matched the parser and overwrote the real request `Content-Type: multipart/form-data; boundary=...` with whatever the last body part's content type was (typically `application/pdf`, `image/png`). Downstream `str_contains($contentType, 'multipart/form-data')` then failed, the multipart branch was skipped, `$parsedFiles` was never set, and `$request->files` came out empty. Every file upload through the stream-socket server was silently lost — the body landed in `$request->body` as a raw multipart string with no way to parse it.

**Fix.** Stop the parser at the first `\r\n\r\n` (RFC 9112 §2.2 boundary between headers and body) before splitting into lines. One logical change in `Tina4/WebSocket.php`. 9 regression tests in `tests/BookIssue139Test.php` cover single-part, multi-part, and mixed-header cases.

**Cross-framework parity check.** Python (`http.server`), Ruby (`webrick`/`puma`), and Node (built-in `http` module) all delegate header parsing to upstream stdlib HTTP parsers that already split headers from body correctly. PHP was the only framework with a hand-rolled HTTP parser in this code path. No port needed.

### Folded-in from PHP 3.12.12 + Python 3.12.13 — v2 `tina4_migration` auto-upgrade (#115)

Projects upgrading from tina4 ^2.x to ^3.x carried a v2-shaped `tina4_migration` table that v3's `ensureMigrationsTable()` left untouched (the `CREATE TABLE IF NOT EXISTS` short-circuited). The v3 reader then selected columns that didn't exist, fell into the "never seen this migration, run it" branch, and re-applied already-applied migrations — typically failing on duplicate-column / table-already-exists errors when the SQL was non-idempotent. The AirOffices ~190-migration codebase tripped on this in March 2026 and needed a manual SQL backfill at the time.

| Framework | v2 schema | v3 schema |
|---|---|---|
| PHP | `migration_id VARCHAR(14)`, `description`, `content BLOB`, `passed` | `id INT PK`, `migration`, `batch`, `applied_at` |
| Python | `description` as identifier, `content`, `passed` | `migration_id`, `migration_name`, `executed_at` |

**Fix.** `ensureMigrationsTable()` (PHP) and `_ensure_tracking_table()` (Python) now detect a v2-shaped table (v2 columns present, v3 columns absent) and call an in-place upgrade that ALTERs in the v3 columns alongside the v2 ones, then backfills v3 fields from the v2 data. v2 columns are kept in place so a manual rollback path stays open — they're simply ignored by v3 readers. The match is by file stem: a v2 row's identifier is matched against `migrations/` files by basename (Python uses `000001_create_users.sql` → stem `000001_create_users` → v2 description `create_users`).

**Cross-framework parity check.** Ruby and Node never shipped a v2 migration table with the trapping shape — their v2 lineages used a different column layout that v3's tracker tolerated. Nothing to port.

### Folded-in from PHP 3.12.11 — request URL parity

`$request->url` now returns the full absolute URL (`https://host:port/path?query`) instead of just the path. `$request->queryString` (raw query bytes) added for parity with `request.query_string` on the other frameworks. Drop-in — old code that read `$request->path` (untouched) keeps working.

### Upgrade

Drop in. No `.env` changes, no API changes.

**For projects upgrading from v2.x:** the v2 `tina4_migration` auto-upgrade runs once on first boot against v3 — back up your migrations table beforehand if you're paranoid. The upgrade is non-destructive (v2 columns are kept alongside the new v3 ones).

**For projects using the dev admin AI coder loop:** the new MCP defensive layer will silently rewrite `## FILE: routes/foo.py` to `src/routes/foo.py` and log a `write.path_normalized` entry. If you were relying on the old behaviour (writes landing wherever the LLM emitted them), this will move some files. Run `tail -n 50 .tina4/agent.log | grep path_normalized` after upgrading to see what got rewritten.

**For shipping apps that want the customer feedback widget:** set `TINA4_ENABLE_FEEDBACK=true` AND `TINA4_FEEDBACK_WHITELIST=alice@example.com,bob@example.com` in `.env`. The widget appears only for those users on non-`/__dev` pages.

## v3.12.10 (2026-05-14)

Version-alignment release. PHP ran ahead through three independent patch releases (3.12.7–3.12.9) while Python / Ruby / Node stayed at 3.12.6. This release realigns all four frameworks on **3.12.10** and ships the ORM `save()` fix.

### PHP — `ORM->save()` no longer swallows write failures (#114)

`ORM->save()` called `update()`/`insert()` but ignored their `bool` return — it only caught exceptions. The PHP adapter's `exec()` returns `false` on a bad statement instead of throwing, so a failed `UPDATE` (commonly: one referencing a public model property with no matching DB column, since `getDbData()` includes every public property) slipped through. The empty transaction got committed and `save()` returned `$this` — the documented success signal. Callers relying on the `save(): static|false` contract believed the row persisted when nothing changed. **Silent data loss** — no exception, no log.

**Fix.** `save()` now captures the `bool` return of `update()`/`insert()`, rolls back, and returns `false` on a falsy result.

```php
$ok = $this->_exists || ... ? $this->update() : $this->insert();
if ($ok === false) { $this->_db->rollback(); return false; }
$this->_db->commit();
```

**Cross-framework parity check.** Python, Ruby and Node don't have this exact failure mode — they build the write payload from declared fields only (not all public properties), and their DB adapters raise on bad SQL, which the existing `try/except` already catches. PHP was the outlier on both counts. 3 regression tests in `tests/Issue114Test.php`; PHP suite 2235 → 2238 passing.

### Also in the PHP 3.12.7–3.12.9 patch line

These shipped to PHP between 3.12.6 and this release; folded into the consolidated 3.12.10 line:

- **3.12.7** — `Request` now normalises caller-provided header keys to lowercase. Some upstream entry points (Apache+PHP-FPM custom mappings, certain proxies, hand-written test fixtures) hand headers in with original case. The constructor only looks them up by lowercase key, so without normalisation `multipart/form-data` content-type detection silently missed and the body fell through as raw bytes — a follow-up to the #135 fix.
- **3.12.8 / 3.12.9** — Router gained RFC 9110 HTTP method conformance: proper `HEAD` and `OPTIONS` handling, `405 Method Not Allowed` with an `Allow` header listing the methods a route does support.

### Python / Ruby / Node

Version-only bump 3.12.6 → 3.12.10 to realign with PHP. No behavioural changes in these three since 3.12.6.

### Upgrade

Drop in. No `.env` changes, no API changes. PHP users on 3.12.9 get the `save()` fix; everyone else gets a version-number realignment.

## v3.12.6 (2026-05-06)

Python-only fix release. PHP / Ruby / Node ship the same version stamp for parity but carry no behavioural changes.

### Python — psycopg2 `%` substitution no longer trips PL/pgSQL function bodies (#40)

A migration containing a PL/pgSQL function with literal `%` characters in a `RAISE EXCEPTION` (or `format()`) call used to fail with the misleading:

> RuntimeError: Migration failed: list index out of range

The error message gave no hint that the `%` chars were the problem. The user-facing failure looked like a tina4 internal bug — actually psycopg2's argument-substitution system tripping on the literal percent signs.

**Root cause.** `PostgreSQLAdapter.execute(sql, params)` always called `cursor.execute(sql, params or [])`. psycopg2 interprets `%` as parameter placeholders WHENEVER the `params` arg is supplied — even an empty list `[]`. So a function body containing `RAISE EXCEPTION 'thing % conflicts with %', a, b` (perfectly valid PL/pgSQL) blew up because psycopg2 thought `%` was a placeholder and there were no values to substitute.

**Fix.** New `PostgreSQLAdapter._safe_execute(cursor, sql, params)` helper routes empty/None params through `cursor.execute(sql)` (no second arg), which makes psycopg2 skip the substitution pass entirely. Literal `%` chars flow through untouched. Applied at every `cursor.execute(...)` call site in the adapter (5 spots across `execute`, `fetch`, `fetch_one`).

**Tests.** 5 new unit tests in `tests/test_postgres_percent_substitution.py` pin the helper's branching. 3 live-Postgres regression tests in `tests/test_postgres_plpgsql_percent.py` exercise a real CREATE FUNCTION + trigger flow with literal `%` in the body — skipped automatically when no Postgres is reachable. Full suite: 2453 passing (was 2448).

**Cross-framework parity check.** PHP (`pg_query` vs `pg_query_params`) and Ruby (`exec` vs `exec_params`) already branch on params presence so they don't have this bug. Node uses `$1` placeholders not `%`, so the same class of bug doesn't apply.

### Long-standing tina4-js #37 confirmed fixed

`frond.form.submit` not following 3xx redirects — fixed in frond v2.1.2 back on April 11, 2026 (`xhr.responseURL` comparison + `window.location.href` navigation). All four framework `public/js/frond.min.js` copies carry the fix. The original issue stayed open because the reporter never confirmed against the patched build.

### Upgrade

Drop in. No `.env` changes, no API changes.

## v3.12.5 (2026-05-06)

PHP-only bug fix release. Python / Ruby / Node ship the same version stamp for parity but carry no behavioural changes.

### PHP — multipart bodies with file uploads now parse correctly (#135)

Two stacked bugs in `Tina4\Request::__construct` made `$request->body` come through as the raw multipart bytes (~11 KB blobs starting with `------WebKitFormBoundary…`) whenever the request included a file upload:

1. The constructor called `$this->parseBody()` BEFORE initialising `$this->files`. Inside parseBody's multipart branch, the line `$this->files = array_merge($this->files, $parsed['files'])` read an uninitialised typed property — fatal `Error`.
2. After fixing the init order, that same line tried to mutate the `readonly` `$files` property — another fatal `Error`.

Both errors got swallowed by the upstream error handler and the route handler received the raw multipart payload instead of the parsed associative array. Routes that worked fine for ordinary form posts broke the moment a file field came along.

**Fix.** Move `$this->files` initialisation AFTER `parseBody()` runs. parseBody stashes extracted multipart files on a new private mutable `$multipartFiles`; the constructor merges them into the readonly `$files` in a single assignment that respects the readonly contract.

4 new regression tests in `tests/Issue135Test.php` pin the constructor's contract. Full PHP suite: 2235 passing (was 2231).

### Upgrade

Drop in. No `.env` changes, no API changes, no other framework changes.

## v3.12.4 (2026-05-06)

Documentation-truth release. The `audit-truth.py` CI gate (introduced post-3.12.3) flagged 39 env vars referenced in docs that no framework actually read. This release closes that gap: 25 of them now exist in code, the other 14 are deleted from docs (11 hallucinations + 6 clustering vars deferred to [tina4#2](https://github.com/tina4stack/tina4/issues/2)). Both audit gates (CLI drift + env-var drift) are now strict in CI.

### 25 new env vars across all 4 frameworks

Server: `TINA4_HOST`, `TINA4_SUPPRESS`, `TINA4_ENV_FILE`. Health: `TINA4_HEALTH_PATH` (default `/__health`, with `/health` kept as a legacy alias), `TINA4_TRAILING_SLASH_REDIRECT`. Sessions: `TINA4_SESSION_HTTPONLY`, `TINA4_SESSION_NAME`, `TINA4_SESSION_SECURE`. Templates: `TINA4_TEMPLATE_CACHE_TTL` (`0` = permanent). GraphQL: `TINA4_GRAPHQL_AUTO_SCHEMA`, `TINA4_GRAPHQL_ENDPOINT`. Mail: `TINA4_MAIL_IMAP_ENCRYPTION` (`tls`/`starttls`/`none`). MCP: `TINA4_MCP`, `TINA4_MCP_PORT`. Swagger: `TINA4_SWAGGER_ENABLED`, `TINA4_SWAGGER_CONTACT_EMAIL`, `TINA4_SWAGGER_LICENSE`. Database: `TINA4_DB_POOL` (env override on the existing `Database(url, pool=N)` constructor argument).

### Logging — env-driven file output + rotation

Six new vars give you full control over logging without touching code:

| Var | Default | What it does |
|---|---|---|
| `TINA4_LOG_FILE` | _(empty — stdout only)_ | Path to a log file. Empty leaves you on stdout. |
| `TINA4_LOG_DIR` | `logs` | Directory for log files (joined with `_LOG_FILE` if relative). |
| `TINA4_LOG_FORMAT` | `text` | `text` or `json`. JSON mode emits one structured record per line. |
| `TINA4_LOG_OUTPUT` | `stdout` | `stdout`, `file`, or `both`. Strict — `stdout` means stdout only. |
| `TINA4_LOG_CRITICAL` | `false` | Enables a `Log.critical()` level above `error`. Off = no-op. |
| `TINA4_LOG_ROTATE_SIZE` | `10485760` (10 MB) | Rotate when the file exceeds this many bytes. `0` disables rotation. |
| `TINA4_LOG_ROTATE_KEEP` | `5` | Number of rotated files to retain (`app.log.1` … `app.log.N`). Older ones are deleted. |

Implementation uses each language's stdlib — Python's `logging.handlers.RotatingFileHandler`, Ruby's `Logger.new(path, shift_age, shift_size)`, and a roll-your-own atomic-rename pattern in PHP and Node. Zero new dependencies in any framework.

### Documentation-truth CI gate now strict on both axes

The `audit-truth.py` script now blocks merges to `main` of `tina4-documentation` whenever a doc references a `tina4 <command>` or `TINA4_*` env var that doesn't exist in source. Previously CLI drift was strict; env drift was warn-only. Today both are strict.

### Tests added

- Python: +53 tests in `tests/test_env_vars.py` (2395 → 2448)
- PHP: +59 tests in `tests/EnvVarTest.php` (2172 → 2231)
- Ruby: +51 examples in `spec/env_vars_spec.rb` (2696 → 2747)
- Node: +59 tests in `test/envVars.test.ts` (3204 → 3263)

**Cross-framework total: 10,689 tests passing, +222 from 3.12.3.**

### Upgrade path

Drop in. No breaking changes — every new env var is opt-in with a sensible default. If you were setting any of the 17 deleted vars in your `.env`, the boot guard will warn (then ignore) — clean them out at your leisure.

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

- **breaking:** `auto_map` now defaults to `True` — ORM models automatically map between camelCase properties and snake_case DB columns. Set `auto_map = False` on your model to restore the old behaviour.
- **feat:** `to_dict(case=)` parameter — pass `case='camel'` to get camelCase keys (for JSON APIs) or `case='snake'` (default) for snake_case keys matching DB columns.
<div v-pre>

- **feat:** Frond `replace` filter now accepts dict args — `{{ v|replace({"T": " ", "-": "/"}) }}` for multiple substitutions in one call.
- **feat:** `background(callback, interval)` — register periodic tasks that run cooperatively in the asyncio event loop. Replaces `threading.Thread` for background work.
- **feat:** Background task protection — sync callbacks run in a `ThreadPoolExecutor` via `run_in_executor()` with `asyncio.wait_for()` timeout, preventing blocking functions from freezing the server.
- **feat:** Docker image now bundles the example store demo — `docker run tina4stack/tina4-python:v3` starts a working app out of the box.
- **fix:** Cart nav badge now updates reactively on quantity change and item removal (tina4-js `signal`/`computed`/`effect`).
- **fix:** Non-blocking queue consumer — `process_orders()` uses `queue.pop()` (single job per tick) instead of blocking `queue.consume()`.
- **tests:** 6 new parity tests covering `to_dict(case=)`, `auto_map` default, `replace` filter (dict + positional), and `background()` registration.
- **parity:** All features shipped identically across Python, PHP, Ruby, Node.js. 2,304 tests passing.

</div>

## v3.10.97 (2026-04-11)

- **fix:** frond.form.submit redirect handling — XHR transparently follows 3xx redirects, so the callback received redirected HTML instead of navigating. Fixed by comparing `xhr.responseURL` with the original URL and calling `window.location.href` when a redirect is detected.
- **fix:** Currency placeholder — locale files now default to `$` for the currency symbol.
- **fix:** Admin sidebar alignment — widened sidebar to 220px with `min-width` to prevent label truncation.
- **fix:** Admin table overflow — added `min-width: 0` and `overflow-x: auto` on `.admin-main` to prevent content clipping.
- **fix:** Order detail template — corrected variable names (`items` instead of `order.items`, `item.name` instead of `item.product_name`) and used `.records` from `DatabaseResult`.
- **fix:** Status badges — dashboard recent orders and order list now show colored badge pills with translated status labels (pending, processing, shipped, delivered, cancelled).
- **fix:** Date formatting — admin order/dashboard dates trimmed to `YYYY-MM-DD HH:MM:SS` instead of raw ISO with microseconds.
- **feat:** Cart quantity spinner — reactive qty controls using tina4-js signals, computed values, and effects.
- **feat:** Multi-currency pricing — forex conversion via Api client (frankfurter.app), `|currency` template filter, currency selector in navbar.
- **feat:** MCP server tools — `check_stock`, `low_stock_report`, `search_products` tools and `store://categories`, `store://inventory-summary` resources for AI assistant integration.
- **feat:** Contact form — built with `HtmlElement` and `add_html_helpers()` to demonstrate programmatic HTML generation.
- **feat:** ORM named scopes — `Product.scope("active")`, `Product.scope("low_stock")`, `Product.scope("expensive")`.
- **feat:** Database connection pooling — `Database("sqlite:data/store.db", pool=4)`.
- **feat:** Inline tests — `@tests` decorators on `cart_service.py` and `forex_service.py`.
- **feat:** Language toggle — flag button (🇫🇷/🇬🇧) in navbar to switch locale.
- **feat:** Helpdesk chat persistence — chat messages stored in DB, history API (`GET /api/chat/history`).
- **dep:** Updated frond.min.js to v2.1.2 across all 4 frameworks (Python, PHP, Ruby, Node.js).
- **parity:** All 4 frameworks bumped to 3.10.97.

## v3.10.93 (2026-04-11)

<div v-pre>

- **fix:** Frond array/dict literal support — `{% set items = ["a", "b"] %}` and `{% set obj = {"k": "v"} %}` now parse correctly.
- **fix:** Frond bracket depth tracking in `_find_outside_quotes()` and `_split_outside_quotes()` — expressions like `arr[i % 2]` no longer treated as top-level arithmetic.
- **fix:** Frond subscript expression evaluation — bracket content uses `_eval_expr()` instead of `_resolve()`, enabling `arr[loop.index0 % 2]`.
- **fix:** Frond slice with variable bounds — `items[start:end]` evaluates bounds through `_eval_expr()`.
- **fix:** Frond multiline `{% set %}` — `_SET_RE` regex now uses `re.DOTALL` flag.
- **docs:** Developer skills updated — Metrics Dashboard guidance, Frond Template Parity rules, `@noauth` security warnings.
- **demo:** Complete e-commerce store example (`example/store/`) with GraphQL search, SSE, WebSocket, Queue, Events, 13 test files.
- **parity:** All Frond fixes applied identically across Python, PHP, Ruby, Node.js. 2,304 tests passing.

</div>

## v3.10.92 (2026-04-10)

- **refactor:** Extract `RateLimiter` from `core/middleware.py` into its own file `core/rate_limiter.py`. The old import path still works via re-export.
- **feat:** Add `RateLimiterMiddleware` wrapper class with `before_rate_limit()` and `check()` static methods.
- **breaking:** Rename `ErrorOverlay` methods — `render()` → `render_error_overlay()`, `render_production()` → `render_production_error()`, `debug_mode()` → `is_debug_mode()`.
- **feat:** Add `Server.start()` and `Server.stop()` for cross-framework parity.
- **feat:** Add `DatabaseResult.size()`, `to_array()`, `to_json()`, `to_csv()` methods.
- **feat:** Add `ScssCompiler` class with `compile()`, `compile_file()`, `add_import_path()`, `set_variable()`.
- **feat:** Add `DevAdmin.unresolved_count()`, `clear_all()`, `reset()`, `capture()` (5-param), `register()`.
- **fix:** GraphQL test API — update `add_query()` calls to use positional args (args, return_type, resolver).
- **parity:** 44/44 cross-framework features green. 2,263 tests passing.

## v3.10.91 (2026-04-10)

- **feat:** Add parity methods — `GraphQLType.parse()`, `Response.send()` params, `QueryBuilder.from_()`, `Debug.configure()`.
- **breaking:** Remove alias methods `from_`, `configure`, `template` — use canonical names only (`from_table`, etc.).

## v3.10.90 (2026-04-09)

<div v-pre>

- **docs:** Chapter 4 (Templates) — new "Dumping Values for Debugging" section covering both `{{ x|dump }}` and `{{ dump(x) }}` forms, their shared `<pre>`-wrapped output, and the `TINA4_DEBUG=true` production gate. Filter table entry updated to reference the new section.
- **docs:** `plan/parity/parity-template.md` updated with a cross-framework dump helper comparison table and marks dump parity as confirmed across all 4 frameworks at v3.10.89.
- **chore:** Version sync release — brings all 4 frameworks to the same patch version (3.10.90) so downstream users can upgrade PHP/Python/Ruby/Node.js in lockstep without hunting version mismatches.

</div>

## v3.10.89 (2026-04-09)

<div v-pre>

- **feat:** `{{ dump(value) }}` global function form added to Frond alongside the existing `{{ value|dump }}` filter. Both call a single `_render_dump()` helper and produce identical output.
- **security:** Dump is now **gated on `TINA4_DEBUG=true`**. In production (env var unset or `false`) both the filter and function silently return an empty string. This prevents accidental leaks of internal state, object shapes, and sensitive values into rendered HTML when a developer leaves a `{{ dump(x) }}` call in a template.
- **refactor:** Dump output is wrapped in `<pre>` and HTML-escaped via a single shared code path.
- **test:** 6 new tests in `test_frond.py` (`TestDump`) covering debug-mode output, production silencing, unset-env default-to-production, function/filter parity, and circular references.

</div>

## v3.10.86 (2026-04-09)

- **feat:** `ForeignKeyField` is now a proper `Field` subclass that auto-wires both sides of the relationship. Declaring `author_id = ForeignKeyField(to=Author)` injects `belongs_to` on the declaring model and `has_many` on the referenced model via `ORMMeta` — no manual descriptor calls required. Override the has-many name with `related_name=`.
- **feat:** Cross-framework parity — same FK auto-wiring semantics now available in PHP (`$foreignKeys`), Ruby (`foreign_key_field`), and Node.js (`type: "foreignKey"`)
- **fix:** `@orm_bind(db)` no longer nulls the decorated class — returns a pass-through decorator
- **fix:** `Auth.get_token`/`valid_token`/`get_payload`/`refresh_token`/`authenticate_request` can now be called on the class (e.g. `Auth.get_token(payload)`) or on an instance via the `_DualMethod` descriptor
- **fix:** `SQLiteAdapter` uses a class-level `threading.Lock` + `PRAGMA busy_timeout = 30000` + `timeout=30` on connect to eliminate `SQLITE_BUSY` deadlocks in the dev server under concurrent writes
- **docs:** Chapter 6 (ORM) updated with a new "ForeignKeyField — Auto-Wired Relationships" section

## v3.10.85 (2026-04-09)

- **refactor:** Split queue adapters into separate files — `queue/rabbitmq_backend.py`, `queue/kafka_backend.py`, `queue/mongo_backend.py` (one class per file, aligning with PHP/Node/Ruby architecture)
- **fix:** Updated remaining tests to use bool `valid_token()` + `get_payload()` pattern

## v3.10.84 (2026-04-09)

- **fix:** Router/middleware was setting `request.user` / `request.auth` / auth payload to `true` (boolean) instead of the actual JWT payload dict after `validToken()` was changed to return bool — any code reading `request.user["sub"]` etc. would have failed silently or crashed
- **fix:** CSRF middleware was not correctly rejecting invalid tokens (nil check on bool result always passed)
- **fix:** `AuthMiddleware.before_request` called `get_payload` incorrectly — would TypeError at runtime on valid token
- **add:** Headless routing auth payload integration tests to prevent regression

## v3.10.83 (2026-04-08)

- **fix:** prevent orphaned session files on WebSocket and anonymous requests (#36)
- **feat:** WebSocket rooms — `join_room`, `leave_room`, `broadcast_to_room`, `room_count`, `get_room_connections`
- **feat:** queue signature parity — instance-scoped `push`/`pop`/`retry`, no topic params on public methods

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

## v3.10.68 (2026-04-03) — Full Parity Release
- **100% API parity** across Python, PHP, Ruby, Node.js — 30+ issues fixed
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
- **BREAKING: request.files content is now raw bytes** — previously base64-encoded; remove any `base64.b64decode()` calls when saving uploaded files. Write `file["content"]` directly to disk
- **load() is now an instance method** — `model.load(sql, params)` calls selectOne internally, populates the instance, returns `True`/`False`. Use `Model.find(id)` for PK lookups
- **api.upload()** added to tina4-js — sends FormData with Bearer token auth for multipart file uploads
- **ORM CLAUDE.md rewrite** — all method stubs now match actual API signatures
- **tina4-js skill** — critical input binding warning, routing docs (`{param}` not `:param`), file upload pattern

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
- **tina4 console** — interactive Python REPL with framework loaded (db, Router, ORM, Auth, Api, Log)
- **tina4 env** — interactive environment configuration (database, cache, session, queue, mail)
- **Brand update** — "TINA4 — The Intelligent Native Application 4ramework"
- **Quick reference** — 36 sections covering every framework feature
- **Chapter reshuffle** — 37 chapters, 7 new (Events, Localization, Logging, API Client, WSDL/SOAP, DI Container, Service Runner)
- **RouteGroup fix** — double prefix bug resolved
- **Port kill-and-take-over** — default port always reclaimed on startup
- **Metrics test detection** — expanded to check spec/, tests/, test/ directories
- **MongoDB adapter** (pymongo), **ODBC adapter** (pyodbc)
- **Pagination standardized** — limit/offset primary, merged dual-key response
- **9,138 tests** across all 4 frameworks

---

## v3.10.57 (2026-04-02)
- **MongoDB adapter** — `Database("mongodb://host:port/db")`, requires `pip install pymongo`
- **ODBC adapter** — parity with PHP/Ruby/Node
- **RouteGroup class** — `group.get()`/`group.post()` syntax matching PHP/Ruby/Node
- **Pagination standardized** — limit/offset primary, merged dual-key toPaginate() response
- **Test port at +1000** — user testing port (e.g. 8145) stable, no hot-reload
- **Dynamic version** — `__version__` read at runtime, no hardcoded constants
- **ORM TINA4_DATABASE_URL discovery** — auto-connect from env
- **Firebird path parsing** — preserves absolute paths
- **108 features at 100% parity**, 2,112 tests

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** — second listener on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **Firebird path parsing** — preserve absolute paths
- **ORM TINA4_DATABASE_URL discovery** — auto-connect from env
- **SQLite transaction safety** — commit() no-op without transaction
- **QueryBuilder docs** — added to ORM chapter

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Auth.check_password(hashed, password)

# AFTER (v3.10.39+)

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Auth.check_password(password, hashed)  # password first — matches PHP, Ruby, Node.js
```

**`Router.all()` removed — use `get_routes()` or `list_routes()`**

```python
# BEFORE

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

routes = Router.all()

# AFTER

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

<div v-pre>

- **Arithmetic in `{% set %}` and expressions** (v3.10.31). The template engine handles math operations inside assignment blocks.

</div>

```html
{% set total = price * quantity + shipping %}
```

### Bug Fixes

**Middleware not applied to routes (fixed in v3.10.1).** Middleware functions registered with `@middleware` were silently skipped during route dispatch. Routes ran without their middleware.

```python
# Before (broken) — middleware was silently skipped

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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
# After (fixed in v3.10.1) — middleware runs on every matching route

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

user = User()
user.name = "Alice"
user.save()  # raised "cannot commit -- no transaction is active"

# After (fixed in v3.10.25) — save() wraps in a transaction automatically

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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
# Before (broken) — decorator had no effect

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/public")
@noauth
def public_page(response):
    return response("Open to all")  # still required auth

# After (fixed in v3.10.1) — decorator works as expected

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/users/{id}")
def get_user(request, response):
    user_id = request.params["id"]
    return response(f"User {user_id}")

# v3.9.0 and later

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# Disable for API-only apps:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# TINA4_CSRF=false

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

request.session.unset("cart")

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Auth

token = Auth.get_token(payload)          # new primary name
valid = Auth.valid_token(token)          # new primary name
# create_token and validate_token still work as aliases

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

**Pagination parameter rename (v3.6.0).** `skip` became `offset` across all query methods.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

users = User.find(skip=10, limit=5)

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

users = User.find(offset=10, limit=5)
```

**Token expiry parameter rename (v3.6.0).** `token_expiry` became `expires_in` and now accepts minutes instead of seconds.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

token = Auth.create_token(payload, token_expiry=3600)  # seconds

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.consume("emails")
def send_email(job):
    to = job.data["to"]

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

name = request.files[0].file_name

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

name = request.files[0].filename
```

**Route params merged into `request.params` (v3.3.0).** Path parameters now merge into `request.params` alongside query parameters. If a query parameter shares a name with a path parameter, the path parameter wins.

---

## v3.2.x — Flexible Route Handlers and DevReload (March 24, 2026)

### Features

**Flexible handler signatures (v3.2.0).** Route handlers accept any combination of parameters. The framework inspects the signature and injects what you ask for.

```python
# No parameters — fire and forget

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/ping")
def ping():
    return "pong"

# Response only

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.get("/hello")
def hello(response):
    return response("Hello")

# Request only (type-hinted)

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

@app.post("/echo")
def echo(request: Request):
    return request.body

# Both

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Queue, Database
db = Database("sqlite:///queue.db")
queue = Queue("emails", db=db)

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Queue
queue = Queue("emails")
# Backend set via TINA4_QUEUE_BACKEND env var

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

**Producer/Consumer classes removed (v3.2.0).** Use `queue.produce()` and `queue.consume()` directly.

```python
# Before

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

from tina4_python import Producer, Consumer
producer = Producer(queue)
producer.send({"to": "user@example.com"})

# After

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

For the full migration guide, see Chapter 36: Upgrading from v2 to v3.

---

## Release Candidate History

Five release candidates preceded the v3.0.0 stable release between March 21-22, 2026. They resolved test failures, polished the Dev Admin UI, added the benchmark suite, and stabilized the Frond template engine. If you tested a release candidate, upgrade to v3.0.0 or later. The RC builds are not supported.
