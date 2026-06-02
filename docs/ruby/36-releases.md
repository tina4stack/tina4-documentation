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

- **breaking:** `auto_map` now defaults to `true` — ORM models automatically map between camelCase properties and snake_case DB columns. Set `self.auto_map = false` on your model class to restore the old behaviour.
- **feat:** `to_h(case:)` parameter — pass `case: 'camel'` to get camelCase keys (for JSON APIs) or `case: 'snake'` (default) for snake_case keys matching DB columns. All aliases (`to_dict`, `to_hash`, `to_assoc`, `to_object`) support the parameter.
<div v-pre>

- **feat:** Frond `replace` filter now accepts Hash args — `{{ v|replace({"T": " ", "-": "/"}) }}` for multiple substitutions in one call.
- **tests:** 6 new parity tests covering `to_h(case:)`, `auto_map` default, `replace` filter (Hash + positional), and `ServiceRunner` registration. 2,519 tests passing.
- **parity:** All features shipped identically across Python, PHP, Ruby, Node.js.

</div>

## v3.10.97 (2026-04-11)

- **fix:** frond.form.submit redirect handling — XHR follows 3xx redirects transparently; fixed by detecting `xhr.responseURL` mismatch and navigating instead.
- **dep:** Updated frond.min.js to v2.1.2.
- **parity:** All 4 frameworks bumped to 3.10.97.

## v3.10.93 (2026-04-11)

- **fix:** Frond bracket depth tracking in `find_outside_quotes` — expressions like `arr[i % 2]` no longer treated as top-level arithmetic.
- **fix:** Frond subscript expression evaluation — bracket content uses `eval_expr()` instead of simple variable lookup, enabling `arr[loop.index0 % 2]`.
- **fix:** Frond slice with variable bounds — `items[start:end]` evaluates bounds through `eval_expr()`.
- **docs:** Developer skills updated — Metrics Dashboard guidance, Frond Template Parity rules, `@noauth` security warnings.
- **parity:** All Frond fixes applied identically across Python, PHP, Ruby, Node.js. 2,513 tests passing.

## v3.10.92 (2026-04-10)

- **breaking:** Rename `ErrorOverlay` methods — `render` → `render_error_overlay`, `render_production` → `render_production_error`, `debug_mode?` → `is_debug_mode`.
- **feat:** Add `Server.handle(env)` for cross-framework parity.
- **breaking:** Rename `WebSocketBackplane.create` → `WebSocketBackplane.create_backplane`.
- **feat:** Add `ScssCompiler.compile`, `add_import_path`, `set_variable` methods.
- **feat:** Add `DevAdmin.register` method.
- **parity:** 44/44 cross-framework features green. 2,487 tests passing.

## v3.10.91 (2026-04-10)

- **feat:** Add parity methods — `Response.send` params, `Middleware.check`/`is_preflight`, AI/Log aliases, MCP optional router.
- **breaking:** Rename `from()` → `from_table()`, `error_envelope` → `error_response`, remove aliases.

## v3.10.90 (2026-04-09)

<div v-pre>

- **docs:** Chapter 4 (Templates) — new "Dumping Values for Debugging" section covering both `{{ x|dump }}` and `{{ dump(x) }}` forms, their shared `<pre>value.inspect</pre>` output, and the `TINA4_DEBUG=true` production gate. Filter table entry updated to reference the new section.
- **docs:** `plan/parity/parity-template.md` updated with a cross-framework dump helper comparison table and marks dump parity as confirmed across all 4 frameworks at v3.10.89.
- **chore:** Version sync release — brings all 4 frameworks to the same patch version (3.10.90) so downstream users can upgrade PHP/Python/Ruby/Node.js in lockstep without hunting version mismatches.

</div>

## v3.10.89 (2026-04-09)

<div v-pre>

- **feat:** `{{ dump(value) }}` global function form added to Frond alongside the existing `{{ value|dump }}` filter. Both call a single `Tina4::Frond.render_dump` helper and produce identical output (`<pre>value.inspect</pre>` HTML-escaped).
- **security:** Dump is now **gated on `TINA4_DEBUG=true`**. In production (env var unset or `false`) both the filter and function silently return an empty `SafeString`. This prevents accidental leaks of internal state, object shapes, and sensitive values into rendered HTML when a developer leaves a `{{ dump(x) }}` call in a template.
- **test:** 3 new `spec/frond_spec.rb` examples covering debug-mode output, production silencing, function/filter parity, and function-form production silencing.

</div>

## v3.10.86 (2026-04-09)

- **feat:** `foreign_key_field` DSL auto-wires both sides of a foreign key relationship. Declaring `foreign_key_field :user_id, references: User` registers the integer column, calls `belongs_to :user` on the declaring class, and calls `has_many :posts` on the referenced class. Supports `related_name:` for custom has-many names and deferred wiring via a module-level registry so the referenced class can be defined either before or after the declaring one.
- **feat:** Cross-framework parity — same FK auto-wiring semantics now available in Python (`ForeignKeyField`), PHP (`$foreignKeys`), and Node.js (`type: "foreignKey"`)
- **docs:** Chapter 6 (ORM) updated with a new "foreign_key_field — Auto-Wired Relationships" section

## v3.10.85 (2026-04-09)

- Version bump for parity with Python and PHP releases

## v3.10.84 (2026-04-09)

- **fix:** Router/middleware was setting `request.user` / `request.auth` / auth payload to `true` (boolean) instead of the actual JWT payload after `valid_token?` was changed to return bool — any code reading `request.user["sub"]` etc. would have failed silently or crashed
- **fix:** CSRF middleware was not correctly rejecting invalid tokens (nil check on bool result always passed)
- **add:** Headless routing auth payload integration tests to prevent regression

## v3.10.83 (2026-04-08)

- **feat:** WebSocket rooms — `join_room`, `leave_room`, `broadcast_to_room`, `room_count`, `get_room_connections`
- **feat:** Queue signature parity — instance-scoped `push`/`pop`/`retry`, no topic params on public methods
- **feat:** Auth cleanup — canonical `getToken`/`validToken` methods
- Full parity across Python, PHP, Ruby, Node.js

---

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


Tina4 Ruby follows semantic versioning. The major version (3) marks the initial Ruby launch — Tina4 Ruby is new in the v3 line, alongside Tina4 for Node.js. Minor versions (3.1, 3.2, etc.) introduce features and non-breaking API additions. Patch versions carry bug fixes and small improvements.

This chapter covers every v3 release from the initial launch through the current stable line. Each section groups releases by minor version, highlights the changes that affect your code, and shows migration steps for anything that breaks.

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
- **load() is now an instance method** — `model.load(sql, params)` calls select_one internally, populates the instance, returns `true`/`false`. Use `find(id)` for PK lookups
- **api.upload()** added to tina4-js — sends FormData with Bearer token auth for multipart file uploads
- **ORM CLAUDE.md rewrite** — all method stubs now match actual API signatures
- **File upload docs** — `request.files` format documented in CLAUDE.md

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
- **tina4 console** — already existed, now matches Python/PHP/Node API
- **tina4 env** — interactive environment configuration
- **Brand update** — "TINA4 — The Intelligent Native Application 4ramework"
- **Imperative relationships** — query_has_one/many/belongs_to for ad-hoc queries
- **Port kill-and-take-over** — default port always reclaimed
- **MongoDB adapter** (mongo gem), **ODBC adapter** (ruby-odbc gem)
- **Pagination standardized** — limit/offset primary, merged dual-key response
- **CORS fix** — returns empty string when origin not allowed

---

## v3.10.57 (2026-04-02)
- **MongoDB adapter** — `Database.new("mongodb://host:port/db")`, requires `gem install mongo`
- **ODBC adapter** — `Database.new("odbc:///DSN=MyDSN")`, requires `gem install ruby-odbc`
- **Imperative relationships** — `query_has_one`/`query_has_many`/`query_belongs_to`
- **Pagination standardized** — limit/offset primary, merged dual-key to_paginate response
- **Test port at +1000** — user testing port (e.g. 8147) stable, no hot-reload
- **CORS fix** — returns empty string when origin not allowed
- **ORM TINA4_DATABASE_URL discovery** — auto-connect from env
- **108 features at 100% parity**, 2,333 tests

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** — second WEBrick on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **CORS fix** — returns empty string when origin not allowed (not *)
- **ORM TINA4_DATABASE_URL discovery** — auto-connect from env
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

**ORM table name pluralization** — Fixed default table name resolution. Table names are now pluralized by default (adding "s" suffix), only skipping when `TINA4_ORM_PLURAL_TABLE_NAMES` is explicitly set to false.

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
Tina4::Container.singleton(:db) { Tina4::Database.new(ENV["TINA4_DATABASE_URL"]) }
db1 = Tina4::Container.resolve(:db)  # creates instance
db2 = Tina4::Container.resolve(:db)  # same instance
```

**`Router.match(method, path)`** — primary route lookup (replaces `find_route`; consistent with Python, PHP, Node.js). **`Router.add(method, path, handler)`** — primary imperative registration (replaces `add_route`; all convenience methods delegate to this).

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

<div v-pre>

**Bug fix:** Macro output was HTML-escaped when used inside `{{ }}` expressions. Characters like `<`, `>`, and `"` rendered as `&lt;`, `&gt;`, `&amp;quot;` instead of raw HTML. Nested macro calls double-escaped.

</div>

```ruby
# BEFORE (broken): macro output escaped

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# Template: {{ my_macro() }}

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# Rendered: &lt;div class=&quot;card&quot;&gt;...&lt;/div&gt;

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


# AFTER (fixed): macro output treated as safe HTML

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# Template: {{ my_macro() }}

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# Rendered: <div class="card">...</div>

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

### v3.10.25 -- ORM Transaction Fix (March 30)

**Bug fix:** ORM `save` and `delete` called `commit` without an active transaction on SQLite. This raised `cannot commit -- no transaction is active` errors.

```ruby
# BEFORE (broken):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

user = User.new(name: "Alice")
user.save  # => RuntimeError: cannot commit

# AFTER (fixed): save/delete wrap operations in a transaction block

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

user = User.new(name: "Alice")
user.save  # => works on all database engines
```

### v3.10.22 -- Unique Form Tokens (March 30)

Form tokens now include a nonce in the JWT payload. Each token is unique per form render, which prevents replay attacks.

```ruby
# In your Frond template:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

<input type="hidden" name="formToken" value="{{ formTokenValue() }}">
```

### v3.10.18 -- Frond Ternary Parser Fix (March 29)

**Bug fix:** The Frond template ternary/inline-if parser failed on quoted strings containing special characters.

```ruby
# BEFORE (broken):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# {{ status == "active" ? "Yes" : "No" }}  =>  parse error

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


# AFTER (fixed):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# {{ status == "active" ? "Yes" : "No" }}  =>  "Yes"

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

### v3.10.16 -- Template Filters: to_json, js_escape (March 28)

Three new Frond template filters for working with data in JavaScript contexts.

```ruby
# Convert a Ruby hash to JSON inside a template:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# {% set key = "name" %}

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# {{ user[key] }}  =>  empty

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


# AFTER (fixed):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# {% set key = "name" %}

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# {{ user[key] }}  =>  "Alice"

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

admins = User.query
  .where("role = ?", ["admin"])
  .order_by("name")
  .limit(10)
  .get

# Standalone:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Tina4::Router.post("/api/users") do |request, response|
  # anyone could call this
end

# AFTER (v3.9.1): unauthenticated requests get 401

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# To allow public access, add .public:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

users = User.fetch(limit: 10, skip: 20)

# AFTER (v3.6.0):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

token = auth.create_token(payload)
valid = auth.validate_token(token)

# AFTER (v3.4.0 -- preferred):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

token = auth.get_token(payload)
valid = auth.valid_token(token)

# Old names still work but are deprecated.

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

```

**HS256 authentication.** Set `TINA4_SECRET` in your `.env` and auth uses HS256. Provide RSA key files and it uses RS256. The framework picks the right algorithm.

```ruby
# .env for HS256:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

TINA4_SECRET=my-secret-key

# .env for RS256:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

<div v-pre>

- Ternary-with-filter: `{{ value ? value|upper : "default" }}`
- `data_uri` filter for inline file display in templates

</div>

---

## v3.3.x

**Released:** March 24, 2026

### v3.3.0 -- Queue API, Route Chaining (March 24)

**Breaking change:** `Producer` and `Consumer` classes removed. Use `queue.produce()` and `queue.consume()` directly.

```ruby
# BEFORE (v3.2.x):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

producer = Tina4::Producer.new(queue)
producer.send(message)
consumer = Tina4::Consumer.new(queue)
consumer.listen { |msg| handle(msg) }

# AFTER (v3.3.0):

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Tina4::Router.get("/health") { "OK" }

# One param -- response only:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Tina4::Router.get("/hello") { |response| response.html("Hello") }

# Two params -- request and response:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

Tina4::Router.get("/echo") do |request, response|
  response.json({ body: request.body })
end

# Named :request or :req -- single param receives the request:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

TINA4_CACHE_BACKEND=redis
TINA4_CACHE_URL=redis://localhost:6379

# Code stays the same:

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` — pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

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

The initial Ruby release. Zero gem dependencies. Everything the framework needs -- HTTP server, template engine, ORM, migrations, auth, queue, GraphQL, WebSocket, WSDL -- ships inside a single gem.

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
