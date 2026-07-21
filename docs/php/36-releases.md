# Chapter 35: Release Notes

## v3.13.81 (2026-07-21) - `tina4php test` fails the build when tests fail

The same hole Python had. `tina4php test` ran the suite through `passthru()` and never captured the exit code, so it always returned 0. A CI gate passed on a red suite. This release captures the runner's exit code and exits with it, so a failing suite fails the gate. A missing runner counts as a failure and exits non-zero too.

- **The exit code now propagates.** `tina4php test` exits with the runner's own code. A red suite stops the pipeline; a green suite exits 0.
- **The `--verbose` flag is gone.** PHPUnit 10 and up removed `--verbose`, so on the pinned PHPUnit 11 the runner exited 2. Once the exit code propagated, that would have turned a passing suite into a false failure. The command now runs with `--colors=always`, and the documented command matches.
- **Real lock-in tests pin both branches.** One covers the smoke-script path, one covers the phpunit path, each against a real temp project. No mocks. Nothing changes beyond the exit code and the flag.

This release re-aligns all four frameworks on one version. Python, Ruby, and Node skip 3.13.80, a PHP-only patch that shipped the `\Tina4\Test` base class; PHP moves from 3.13.80 to 3.13.81. Everyone is back on 3.13.81.

## v3.13.80 (2026-07-19) - The xUnit base class Tina4\Test finally ships

The `\Tina4\Test` base class has been documented since 3.13.0 for class-based test suites - chapter 18 shows `class MyTest extends \Tina4\Test`. It never actually shipped. This release ships it.

- **`Tina4/Test.php` was silently kept out of the package.** An unanchored `test.php` line in `.gitignore` matched `Tina4/Test.php` case-insensitively (macOS git), so the file was never committed and never reached Packagist - even though `\Tina4\TestClient` and the parity test that extends the base class were both present. Anyone who followed chapter 18 got "Class Tina4\Test not found". The file is now committed, guarded by an explicit un-ignore, and ships.
- **3.13.79 is what surfaced it.** The switch to test-directory discovery in 3.13.79 finally ran the test that extends `\Tina4\Test`, so CI failed loudly instead of the file staying invisible.
- **PHP only.** The Python, Ruby, and Node test base classes were already committed and shipping.

## v3.13.79 (2026-07-19) - The test suite runs every test file, a renamed session cookie is read back, and a stuck migration clears

The 3.13.78 session-cookie fix was PHP's, and its regression test never ran in CI. This release closes that hole, reads a renamed cookie back, and clears a stuck migration.

- **CI gap (#178): every test file runs now.** `phpunit.xml` hand-listed its test files, so 78 of 186 test classes never ran in CI - including the #174 session-cookie regression added in 3.13.78. The config now discovers `tests/` by directory, so every `tests/*Test.php` runs, and a guard test asserts the config collects them all. This is the same class of hole as a file registered by hand in 3.13.78.
- **`TINA4_SESSION_NAME` is now read back.** The write side honoured `TINA4_SESSION_NAME`, but the router read the incoming cookie under a hardcoded `tina4_session`, so a renamed cookie never resumed. Both sides now resolve the name through one method, `Session::cookieName()`; the default is byte-identical.
- **Migration (#176): a stuck row clears.** A bookkeeping row left at `passed = 0` - a prior failure, or one carried over from a v2 table - is treated as pending and re-applies cleanly on the next migrate. This was merged earlier; this release publishes it.
- **Test hygiene.** Four PHPUnit "risky" notices surfaced once directory discovery ran the dormant files, and they are cleared. They came from error and exception-handler bookkeeping in the test harness (an `ErrorTracker` static counter and `App` handlers restored at garbage-collection time); the fix is test-infra only and touches no framework runtime code, so production behaviour is identical.

The session-cookie `Secure` fix itself shipped for PHP in 3.13.78, the proven reference for the other three this release; 3.13.79 closes the CI hole that let its test go unrun and adds the cookie-name parity.

Reported by justin-k-bruce (php#178, php#179; #176).

## v3.13.78 (2026-07-17) - Session cookies get Secure behind a TLS-terminating proxy

If you run PHP behind nginx, HAProxy, an ALB, Cloudflare, or almost any container setup, your session cookies were missing `Secure` and stayed sendable over plain HTTP. This release fixes that.

- **Security: `Secure` now follows the scheme the client actually used.** TLS is normally terminated at the proxy, which forwards plain HTTP to PHP, so `$_SERVER['HTTPS']` is unset on exactly the deployments that are encrypted. Both session cookies read that flag alone, concluded "plain HTTP", and dropped `Secure`. They now go through `Request::isSecureScheme()`, which honours `x-forwarded-proto` (and takes the first hop of a proxy chain, which is the client-facing one). The framework already did this when building `$request->url`, so `$request->url` reported `https://` on the very request where the cookies decided otherwise. That disagreement was the bug, and there is now one rule instead of two.
- **`TINA4_SESSION_SECURE` now works on both session cookies.** The documented variable was only read by `Session.php`; the two cookies emitted by the router ignored it entirely, so setting it did nothing for `PHPSESSID` or `tina4_session`. All three now honour it.
- **Plain HTTP is unchanged.** Without a proxy header and without TLS, neither cookie gets `Secure` - marking it eagerly would stop the browser returning the cookie at all and silently break every local session.

Reported by justin-k-bruce as a follow-up to 3.13.77, with the proxy repro and the inconsistency already isolated. Pinned by tests that read the real `Set-Cookie` off a live server driven with a real `X-Forwarded-Proto` header.

Correction: the other three did not merely lack proxy detection - their session-cookie emit path bypassed the cookie builder, so `TINA4_SESSION_SECURE` was a silent no-op there and none of them was proxy-aware. 3.13.79 brings Python, Ruby, and Node to this same contract.

## v3.13.77 (2026-07-16) - The native session cookie is no longer readable by JavaScript

- **Security: `PHPSESSID` now carries `HttpOnly` and `SameSite`.** The framework starts PHP's native session so `$_SESSION` persists, but it let PHP emit the cookie with the stock ini defaults: no `HttpOnly`, no `SameSite`. Any app keeping a login in `$_SESSION` had a session cookie readable by any XSS and sent on cross-site requests. Tina4's own `tina4_session` cookie was correctly attributed twenty-five lines further down the same method; that asymmetry was the bug. The cookie is now configured before it is emitted, reusing `TINA4_SESSION_SAMESITE` (default `Lax`) and the same SameSite=None implies Secure rule. Scope is unchanged: lifetime, path and domain still come from your ini.
- **`toDict()` is not deprecated.** The `@deprecated` tag said the default key casing changed from camel to snake in 3.11.22, but it sat on the method, so editors struck through every call and pointed nowhere: `toAssoc()`, `toObject()` and the response auto-serialization all delegate to `toDict()`. The tag is gone and the casing note is now plain documentation.

Both reported by justin-k-bruce. The cookie fix is pinned by a test that reads the real `Set-Cookie` off a live server.

## v3.13.76 (2026-07-16) - Migrations apply again on a database created before 3.13.55

If your database was created by Tina4 v3 3.13.54 or earlier, every new migration failed and none could ever be applied. This release fixes that. PHP already built its insert this way and was never affected; the behaviour is now pinned by tests here too.

- **The bookkeeping insert now writes the columns your table actually has.** The 3.13.55 rename added `migration_name` and left the old `migration_id` column in place, calling it harmless. It was harmless on reads and anything but harmless on writes: that column is `NOT NULL`, the insert never filled it, so recording a migration raised a not-null violation, the migration rolled back, and the database was stuck. The runner now builds its insert from the table's real columns and fills any legacy one it finds. No schema change, no `ALTER`, every engine.
- **Fresh databases are untouched.** A table with no legacy column still gets exactly the six canonical columns. That is the case CI and every new project exercised, which is why this only ever bit long-lived staging and production databases.

Thanks to justin-k-bruce, who reported it against 3.13.75 with a full compatibility matrix and a working patch. Real-database regression tests now cover a pending migration on a legacy table in all four frameworks.

## v3.13.75 (2026-07-14) - Static assets revalidate, so a deploy reaches users without a hard refresh

The built-in static file handler (everything under public/) now lets a browser cache an asset but forces it to revalidate on every use. A redeployed CSS or JS file reaches the browser on the next page load, with no manual hard refresh - and an unchanged file costs a cheap 304 Not Modified, not a full re-download.

- **Cache-Control and validators on every static response.** Each asset carries `Cache-Control: no-cache, must-revalidate`, an `ETag`, and a `Last-Modified`. Before, a static asset carried only its Content-Type and Content-Length.
- **Conditional requests get a 304.** The handler answers `If-None-Match` and `If-Modified-Since` with a `304 Not Modified` and no body, so a revalidation is a small round trip rather than a re-download. Real-file, real-request tests lock the behaviour in.

This lands identically across Python, PHP, Ruby, and Node.js. It closes the class of "I already reported this" where a browser kept serving a fixed-but-cached front-end asset.

## v3.13.74 (2026-07-13) - The dev dashboard connection tester works again

The dev dashboard "Test connection" panel now connects, lists the tables, and shows the server version. On PHP it was broken two ways: it built the database with `new DataBase(...)`, which resolved to a class that does not exist and threw before anything ran, and it counted tables with a method the adapters do not expose. This release builds the connection with `Database::create(url, username:, password:)` (the same call the rest of the dashboard uses) and counts tables with `getTables()`.

- **A real-SQLite test drives the endpoint end to end.** It opens a live database with two tables and asserts the panel returns success, the real table count, and the version. No mocks.
- **Firebird writes are guarded against a silent loss (#132).** A regression test confirms that an explicit-transaction DELETE or UPDATE - the path the ORM takes - is visible to a separate connection, run against a real Firebird server. The fix itself shipped earlier; this locks it in so a write can never again commit an empty transaction unnoticed.
- **A PHPDoc house style is written down (#128).** CONTRIBUTING.md now states the standard: every public method carries a one-line behaviour summary plus `@param`, `@return`, and `@throws`, describes the behaviour rather than the fix, keeps types in step with the signature, and leaves no orphaned docblocks. The generated AI-context files carry the same rule.

## v3.13.73 (2026-07-13) - A failed migration re-applies cleanly

This release makes a previously-failed migration run again on the next migrate, at full parity across the four frameworks.

- **A leftover `passed = 0` row no longer wedges the next run.** When a migration succeeds, the runner deletes any existing bookkeeping row for that migration name before it writes the fresh `passed = 1` row. A migration that failed earlier - whether you recorded it with `recordMigration($name, $batch, 0)` or carried it over from a v2 table - re-applies cleanly instead of colliding on the unique `migration_name`. The `tina4_migration` table holds at most one row per migration, and the latest run wins. The delete-then-insert path is identical on every engine, so there is no dialect-specific behaviour to reason about.
- **The v2 upgrade tells you what happens next.** When the v2 to v3 upgrade finds `passed = 0` rows, it logs that those migrations re-apply on the next migrate, instead of asking you to clear them by hand.

## v3.13.72 (2026-07-12) - Frond number_format, filter precedence, and a sandbox fix

This release sharpens the Frond template engine, locks in a database error contract, and brings the dev dashboard to parity across the four frameworks.

- **`number_format` reads all three arguments.** The filter now honours the full Twig signature, `number_format(decimals, decimalPoint, thousandsSep)`:

  ```twig
  {{ 1234.5 | number_format(2, ',', '.') }}   {# renders 1.234,50 #}
  ```

  The one-argument form is unchanged, so every existing template behaves as before. (#170)
- **The filter pipe binds tighter than concat.** `|` now groups before `~`:

  ```twig
  {{ amount|number_format(2) ~ ' EUR' }}   {# (amount|number_format(2)) ~ ' EUR' -> 1,234.50 EUR #}
  ```

  The rule holds at any nesting depth, including both branches of a ternary. (#171)
- **The sandbox allow-list covers every filter path (Security).** A filter applied inside a `~` concatenation or a ternary condition now respects the `{% sandbox %}` filter allow-list. A filter you did not allow-list no longer runs its code in sandbox mode. **Breaking:** in `{% sandbox %}` mode a blocked filter now skips and passes the value through unchanged, where PHP used to return an empty string. Both behaviours were secure; this only aligns PHP's output with Python, Ruby, and Node.
- **A malformed request path was already safe here.** The Node worker gained a guard this release for a path like `//` (or `///`, `/\`); PHP never crashed on it and returns a normal 404.
- **Database errors still fail loud (python#57).** `execute()` and `fetch()` raise on failure and record the message on `getError()` rather than returning `false` or an empty result. This shipped in 3.13.38; this release adds a real-PostgreSQL regression test across all four frameworks so it can never slip back to a silent failure.
- **Dev dashboard parity (`TINA4_DEBUG`).** The dev-admin dependency installer (`deps/install`), the grounding-token proxy, and the Migrate, Test, and Seed run-chips now match across all four frameworks. This is development-only; nothing changes in production.

## v3.13.71 (2026-07-11) - AI skills: sharper tina4_code guidance

A skills-and-docs release; no change to the PHP package. The bundled Tina4 AI skills now state WHY `tina4_code` is deprecated: in a boot-and-verify gate (scaffold the output, boot it, run it) `tina4_code` failed where a strong model grounded with `tina4_context` passed, so the tools point to grounding plus a strong model over the self-hosted coder. The recommendation is unchanged - ground with `tina4_context` and write the code yourself; only the rationale is sharper. Running `curl -fsSL https://tina4.com/install-skills.sh | sh` now installs these updated skills by default.

## v3.13.70 (2026-07-11) - Unset columns keep their database default, and Swagger stops overwriting

**An unset column no longer forces a `NULL` into your `INSERT`.** Leave a column unset on a new model and the ORM now drops it from the `INSERT` entirely, so a `NOT NULL DEFAULT` column takes its database default instead of an explicit `NULL` that breaks the constraint. Set a column to `null` on purpose and it still writes `NULL`. When every insertable column is unset, the row inserts with the engine's all-defaults form: `DEFAULT VALUES` on SQLite, PostgreSQL, MSSQL, and Firebird, and `() VALUES ()` on MySQL. (#165)

**One PHP-specific edge.** PHP fires no `__set` for a declared public property, so a direct `$model->col = null` on a property that already defaults to `null` looks identical to leaving it unset. In that one case the column is omitted rather than written `NULL`, which you notice only on a `NOT NULL DEFAULT` column during an `INSERT`. Constructor data, `fill()` data, and a no-default typed property (`public ?int $qty;`) all behave exactly as you expect: an explicit `null` there writes `NULL`.

### Firebird charset is now yours to set (#160)

The Firebird adapter hardcoded `UTF8`, so bytes stored under a legacy `NONE` database came back double-encoded with no way out. You can now set the connection charset with a `?charset=` query on the URL (`firebird://host:3050/path?charset=NONE`) or the `TINA4_DATABASE_CHARSET` environment variable. The URL query wins, then the env var, then the `UTF8` default, so every existing connection behaves exactly as before.

### Swagger stops overwriting stacked metadata (#59)

`Router::swagger()` used to replace whatever metadata a route already carried, so a second call wiped the first. It now merges: each call adds its keys, a later call may override the same key, but no sibling key is ever dropped. Summary, description, and tags attached across separate calls all reach the OpenAPI spec, matching the Python master (where Node and Ruby were already correct too).

## v3.13.69 (2026-07-10) - Api file transfer, plus a cross-origin redirect fix

**The `Api` HTTP client learns to move files, and it stops leaking your token on a redirect.** Five additions, all zero-dependency, all opt-in, none breaking:

- **Multipart `upload()`** posts a `multipart/form-data` body from a file on disk or from in-memory bytes, with optional form fields. No temp file, no ext-curl.
- **Streaming `download()`** writes a response body to disk 64KB at a time, so a large export never buffers whole in memory. It returns `path` instead of `body`.
- **An injectable `transport` seam** lets you unit-test the code that calls an `Api` without a live server. Tina4's own suite never injects a canned fake: its transport-seam test injects a transport that performs real socket I/O.
- **An opt-in in-memory cookie jar** (`cookies: true`) reads `Set-Cookie` and replays the `Cookie` header on later requests, so a session carries across a login.

### Security

**The `Api` was following cross-origin redirects and forwarding your credentials to the new origin.** The old client used the `file_get_contents` stream wrapper, which auto-follows redirects and forwarded the `Authorization` header and the session `Cookie` to the redirect target, including a different host. A call to an endpoint that redirected to another origin handed your bearer token and session cookie to a host you never authenticated against. The client now follows redirects itself, one hop at a time, and strips the `Authorization` and `Cookie` headers whenever the origin (scheme, host, or port) changes. Same-origin redirects keep them. This is verified against a real two-origin localhost server, needs no code change, and adds no dependency (the stream wrapper only). **Upgrade recommended** for anyone using `Api` against endpoints that redirect.

### Also shipping (previously held on v3)

- **Firebird `pdo_firebird` fallback.** The Firebird adapter auto-engages the `pdo_firebird` driver when the native `ext-interbase` extension is absent or broken (the macOS plus Firebird 5 clumplet case), so you get a working database either way. Force the choice with `TINA4_FIREBIRD_DRIVER=pdo` (or `interbase`) app-wide, or with a `?driver=pdo` query param on one connection. Migrations are engine-aware across the driver switch.
- **The REPL console honours the database env.** `tina4 console` now reads `TINA4_DATABASE_URL` plus `TINA4_DATABASE_USERNAME` / `TINA4_DATABASE_PASSWORD` and binds the ORM, so models resolve a connection inside the console exactly as they do in a request.
- **The AI Coder Rule Path.** The developer skill now ships the canonical guidance for where an AI coding tool reads and writes project rules, aligned across all four frameworks.

### Docs

- A dedicated **Real-time Collaboration (WebRTC)** chapter is now published: peer-to-peer calls, live chat, and file transfer, grounded in the shipped `realtime()` surface.

## v3.13.68 (2026-07-10) - Firebird counts again

`count()` and `recordExists()` return the right number on Firebird. Firebird folds an unquoted column alias to upper case, so `SELECT COUNT(*) as cnt` comes back under the key `CNT`. The ORM read a lower-case `cnt` that never existed and always returned 0, so every count looked empty and `recordExists()` always said no. Both now read the alias without caring about case. `insert()` also routes Firebird through `INSERT ... RETURNING` so a generated identity key lands back on the model, the same path Postgres already uses. Verified against a real Firebird 5.0.2 server. Reported in #132 (#133).

## v3.13.67 (2026-07-10) - The MCP table browser lists your tables again

**The `database_tables` dev-tool works again.** It called `getDatabase()`, a method the base `Database` does not carry, so every call fataled with "Call to undefined method" and returned an error instead of your table list. The tool now calls `getTables()`, the adapter contract that actually lists tables. Drive the dev MCP server from an AI client and "list the tables" answers correctly.

The bug hid in plain sight because the test only checked that the tool was registered, never that it ran. The new test invokes the real handler against a real SQLite database and asserts a table list comes back, so a silent fatal cannot ship again. All four frameworks gained the same behavioural test; Python, Ruby, and Node already called the right method. Reported by skorteva (#164).

## v3.13.66 (2026-07-10) - A self-describing CLI, and generators that ship their tests

The command line grew up. The `tina4` client no longer keeps its own copy of what
each framework can do. It asks the framework, then forwards the request. A command
you add to the framework shows up in the client automatically; one you remove simply
stops being offered. The whole class of client-versus-framework drift is gone.

### The self-describing CLI

- **`commands` / `commands --json`.** Every framework CLI now prints its own command
  table from a single source. The `tina4` client reads that manifest to render an
  accurate `tina4 --help`, caches it by a cheap fingerprint of the resolved CLI, and
  refreshes with `--refresh`. Dispatch never depends on the manifest, so a discovery
  miss shortens the help listing and never breaks a command.
- **Pass-through dispatch.** The client keeps its own conductor commands (serve, scss,
  setup, init, deploy, agent, doctor, install, update, build) and forwards everything
  else to the framework verbatim. It carries no per-command flag knowledge, so it can
  never fall out of parity.
- **`queue` is now a top-level command** in all four frameworks: `queue work`,
  `queue stats`, `queue retry`, `queue clear`, wired to the real queue. Run a worker
  straight from the CLI instead of only scaffolding one.
- **`build` builds the deployable Docker image** (`docker build`), replacing the old
  library-packaging behaviour. `build` produces the image; `deploy` ships it.
- **Ruby gains `migrate:create`**, matching the other three.

### Generators now ship a test with the code

Every code-producing `generate` subcommand writes a real, passing test next to the
code it scaffolds. `generate model Product` also gives you a `Product` test that talks
to a real database. The tests use real collaborators (real SQLite, a real test client,
a real queue), never mocks, and pass the moment they are generated.

Writing those tests exposed real bugs in the scaffolds that no string-matching test
would have caught: the generated `auth` current-user endpoint rejected valid tokens in
Python and PHP, and the generated migration created then immediately dropped its table
in Ruby and PHP. All four are fixed and locked in by the new tests.

### Databases

- **PHP silent PDO fallback.** SQLite and PostgreSQL adapters prefer the native
  extension and fall back to the matching PDO driver when it is missing. The developer
  gets a working database either way, with identical behaviour (native types, raw-byte
  BLOBs, last insert id, transactions, fail-loud errors).
- **ORM `where()` takes an order.** `Model.where(...)` now accepts `order_by` /
  `orderBy` (and Ruby also gains `limit`/`offset`), matching `find()`, `all()`, and the
  query builder.

### Fixes

- The Frond browser helper now applies a 30 second request timeout by default.
- SQLite datetime adapters no longer emit a deprecation warning on Python 3.12+.
- Node route handlers accept a `void` return in TypeScript without a type error.

### Breaking

- **Frond `request()` now times out after 30 seconds by default.** A request that
  used to hang forever now fails after 30 seconds and calls `onError`. Pass
  `timeout: 0` to restore the old unbounded behaviour, or a millisecond value to set
  your own.
- **`build` changed target.** It now builds a Docker image rather than packaging the
  framework as a library. Projects that relied on the old behaviour should call their
  packaging tool directly.
- **`generate` writes an extra test file per scaffold.** If you script generation and
  assert on the exact set of created files, expect one more file (the co-emitted test).

## v3.13.57 (2026-07-08) - Realtime collaboration, and a test client that tells the truth

**Tina4 ships realtime collaboration: peer-to-peer calls, live chat, and file sharing, from one call.** Mount the surface before you serve and the framework wires the whole thing. A WebRTC signalling channel relays offers and answers between peers. A chat channel carries messages, presence, typing, and read receipts, and persists its history through the ORM. An upload and download path moves files.

```php
use Tina4\Realtime\Realtime;

Realtime::mount('', ['features' => ['calls', 'chat', 'files']]);
```

Calls run on a mesh backend by default, so a small room needs no media server at all. Set `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` and the framework mints time-limited coturn credentials for peers behind strict NATs. Chat history survives a restart, so a reconnecting client catches up. Files land on local disk by default, or in any S3-compatible bucket (MinIO included) when you set `TINA4_STORAGE_BACKEND=s3`.

The browser half ships in tina4-js 1.5.0 as the `rtc` module. `rtc.call(room)` opens a call with perfect-negotiation handshaking. `rtc.chat(channel)` binds a live message list, a presence roster, and a typing signal straight into a template. `rtc.upload(channel, file)` sends a file. Every piece of live state is a signal, so the interface updates itself. Every Tina4 backend now vendors the tina4-js bundle that carries this module.

The auth levels are deliberate. The call signalling socket is public, because the framework never reads your SDP. Chat, history, upload, and download each require a valid token, and chat rechecks channel membership on every frame.

**The in-process TestClient now enforces the real auth gate.** This is the fail-loud fix. The PHP `TestClient` already dispatched through the real router, so it met the contract, but nothing pinned that at the client surface. A regression test now locks it in: a write with no token returns 401 through the test client exactly as it does on the live server, so a green test can never hide a live 401.

**Breaking, tests only.** A test that posts to an auth-required route without a token sees 401, not the handler response. When the test checks plumbing rather than auth, open the route with `->noAuth()` or pass a valid bearer token. No production request path changes. Shipped across all four frameworks.

## v3.13.56 (2026-07-08) - Skills that own up when they drift

**Every AI skill now tells the assistant how to report itself when it is wrong.** A skill is documentation, and documentation drifts. When a skill still describes a method, default, or column the framework no longer has, an assistant writes confident code against an API that is gone. This release closes that loop.

Every skill, and every project context file the AI installer writes (CLAUDE.md, .cursorules, .github/copilot-instructions.md, .windsurfrules, CONVENTIONS.md, .clinerules, AGENTS.md), now carries one instruction: if Tina4 behaves differently from what the skill describes, that is a bug in the skill. Tell the developer, then report it at https://tina4.com/report-a-skill. The report lands as an issue on the documentation repository, gets fixed at the source, and ships to everyone.

**The skills themselves are corrected too.** The ORM soft-delete guidance now names the real `is_deleted` column (it wrongly said `deleted_at`), the tina4-js signal-persistence reference ships alongside the skill, and the per-framework skill copies are back in sync with the canonical set.

The web framework runtime does not change in this release. Update your installed skills with `curl -fsSL https://tina4.com/install-skills.sh | sh` (re-run to refresh in place).

## v3.13.55 (2026-07-07) - One migration tracking schema on every engine

**The `tina4_migration` bookkeeping table now has the same shape on every framework and every engine.** Before this release the four frameworks each named and typed the tracking table a little differently. A project that moved between them, or a tool that read the table directly, met a different schema each time.

The canonical table is six columns: an auto-increment `id`, a `migration_name` (unique, the migration file stem), a `description`, a `batch`, an `executed_at` timestamp, and a `passed` flag. The auto-increment and the column types follow the engine: `AUTOINCREMENT` on SQLite, `SERIAL` on PostgreSQL, `AUTO_INCREMENT` on MySQL, `IDENTITY(1,1)` on SQL Server, and a generator on Firebird.

**Existing installs upgrade in place, and no applied migration re-runs.** The runner detects the old name column (`migration_id` in Python, `migration` in PHP, `name` in Node; Ruby already used `migration_name`), adds `migration_name`, copies the values across, and backfills the new columns. The old column stays where it is, ignored. A migration already marked applied stays applied.

No new third-party dependencies. Shipped across all four frameworks.

## v3.13.54 (2026-07-07) - Migrations honour the SET TERM directive

**A Firebird trigger or stored procedure now survives the migration splitter.** Those bodies end their inner statements with a semicolon, the same character the runner uses to separate one statement from the next. Run under the default terminator, a trigger body split apart on its own punctuation and the migration failed.

A `SET TERM` line fixes it. Wrap the block in the universal isql idiom and the runner switches its active terminator, so the whole body travels as one statement:

```sql
SET TERM ^ ;
CREATE OR ALTER TRIGGER t_bi FOR t ACTIVE BEFORE INSERT AS
BEGIN
  IF (NEW.id IS NULL) THEN NEW.id = GEN_ID(GEN_T, 1);
END^
SET TERM ; ^
```

The runner consumes each `SET TERM` line instead of sending it to the engine, restores the previous terminator when the block ends, and handles a multi-character terminator such as `!!`. A migration with no `SET TERM` splits on the semicolon exactly as before. Shipped across all four frameworks.

**PHP and Ruby also repair the Firebird v2 to v3 upgrade.** Firebird returns column names in upper case, so the migration tracker read a null migration name and treated every applied migration as pending, re-running the lot. The tracking-table reads now normalise to one key shape. PHP additionally records a row on an upgraded table with its original 14-character id and detects the Firebird dialect through the Database facade.

Thanks to justin-k-bruce for the contribution.

## v3.13.53 (2026-07-06) - JSONField: JSON document columns

**Store a JSON document in a column.** A model field can now hold a whole object or array. The framework encodes it to JSON when it writes and decodes it back to a native array when it reads, so the attribute is always live data, never a raw string.

```php
class Event extends \Tina4\ORM {
    public ?array $payload = null;   // JSON document
```

The column type follows the engine. PostgreSQL gets native `JSONB`, MySQL native `JSON`, SQL Server `NVARCHAR(MAX)`, Firebird a text `BLOB`, and SQLite `TEXT` (queryable through JSON1). One field declaration, the right column on every database.

A value that cannot be encoded to JSON does not slip through. `save()` fails loud: it rolls back, returns `false`, and records the cause, so a half-written row never reaches the table. A mutable default is copied per instance, so two records never share and mutate the same object.

No new third-party dependencies.

## v3.13.52 (2026-07-04) - Frond live blocks, pgsql:// URL scheme, SCSS colour functions

**Frond live blocks.** A page can now carry a region that keeps itself current. Wrap the region in `{% live %}` and Frond paints it on the server with the first request, then refreshes it over the transport you name.

```twig
{% live "prices" poll 5 %}
  <ul>{% for row in rows %}<li>{{ row.name }}: {{ row.price }}</li>{% endfor %}</ul>
{% endlive %}
```

The block renders server-side on first paint, so a crawler and a client with no JavaScript both see real content. After that it refreshes on its own. `poll N` re-fetches every N seconds. `sse` streams updates over Server-Sent Events. `ws "/path"` rides a WebSocket route you already own. A data provider feeds every refresh: `@live_source` in Python, `Frond::liveSource` in PHP, `Frond.live_source` in Ruby, `Frond.liveSource` in Node. The provider re-runs with the live request, so a block that reads the signed-in user reads it again on every refresh, and an authenticated block cannot serve one user another user's data. For poll and SSE, Tina4 mounts one always-on endpoint, `GET /__frond/live/{name}`. For a WebSocket block, `push_live(name, data)` re-renders the block and broadcasts the fresh HTML to every client on that path. Nested live blocks are rejected, and a block's optional `src` attribute is same-origin only.

One client script drives it, `frond.js`, byte-identical across Python, PHP, Ruby, and Node. No build step. No framework on the page.

**pgsql:// is a Postgres URL scheme again (#58).** A connection string like `pgsql://user:pass@host/db` was rejected. v3 registered only `postgresql://` and `postgres://` and dropped the older spelling, but `pgsql` is the scheme PDO, Laravel, and Doctrine all use, so real config files carried it and Tina4 refused to start. `pgsql://` now resolves to the PostgreSQL driver in all four frameworks, next to the two existing spellings. Same driver, three accepted names.

**SCSS colour functions evaluate at compile time.** `rgba(#3498db, 0.5)` used to pass through to the stylesheet as literal text, and the browser dropped the whole rule because `rgba()` cannot take a hex string. The built-in SCSS compiler now evaluates the colour functions: `rgba(#hex, a)` and `rgb(#hex)` expand to real channel values, `mix(c1, c2, weight)` blends two colours, and `lighten()` and `darken()` shift a colour through HSL. The output is byte-identical across all four compilers, down to the same integer rounding, so a shared stylesheet renders the same colour whichever framework served it.

No new third-party dependencies.

## v3.13.51 (2026-07-03) - MCP Streamable HTTP transport, Firebird fixes

The built-in dev MCP server now speaks the current MCP Streamable HTTP transport, the one Claude Code and today's MCP clients expect. It still answers the older 2024-11-05 HTTP+SSE transport, so nothing that already worked stops working.

One endpoint carries the whole session. A client POSTs JSON-RPC to `/__dev/mcp` and reads the response inline. `initialize` mints a session and returns it in an `Mcp-Session-Id` header; the client sends that header back on every later call. A request with an unknown session gets a `404`, its cue to initialize again. A notification returns `202`. `GET` on the endpoint returns `405` with `Allow: POST, DELETE`, and `DELETE` ends the session. The server negotiates the protocol version: it echoes the version a client asks for when it can speak it, otherwise it picks the newest one it knows.

Tina4 writes the connection details to `.claude/settings.json` for you, now with `"type": "http"` and the bare `/__dev/mcp` URL. Prefer the command line? Run `claude mcp add --transport http tina4-dev http://localhost:7145/__dev/mcp`. The change lands uniformly across Python, PHP, Ruby, and Node. Python and Node keep a full persistent legacy SSE stream; PHP and Ruby serve the current transport plus a one-shot legacy handshake, with no long-lived connection required.

**Why the transport slipped past us.** Our MCP tests spoke our own JSON-RPC shape over the endpoints we built, never the wire a real client speaks. They stayed green while a real Claude Code client could not connect. Every framework now ships a no-mock transport test that drives the real session lifecycle, and each was verified end to end against a live server booted through the tina4 CLI.

**Firebird (PHP).** Three reported issues are fixed. The migration runner and the ORM now call `execute()` rather than the old `exec()` (#120). Parameterized DML no longer throws a type error when it fetches the last insert id (#121). NULL parameters bind correctly again, rewritten to a literal `NULL` because the ibase driver cannot bind a PHP null (#123). The `exec()` method stays as a deprecated alias for `execute()`.

**Migration recording on upgraded schemas (PHP).** The fail-loud `execute()` surfaced a quiet bug. On a database whose `tina4_migration` table had been upgraded in place from the old v2 layout, a new migration never recorded itself, so it re-ran on every boot. The old `exec()` had swallowed the constraint error. The runner now supplies the legacy `migration_id` column when it is present, so a migration records once and stays recorded.

No new third-party dependencies.

## v3.13.50 (2026-07-02) - Path route params match INTEGER primary keys on SQLite (Ruby fix)

A route path parameter like `{id}`, matched against a real HTTP request, must find an INTEGER primary-key row. On Ruby it did not. Rack delivers the request path as ASCII-8BIT, so an untyped `{id}` capture reached the SQL bind as a binary string, and the sqlite3 gem bound it as a BLOB. SQLite gives a BLOB no numeric affinity, so `WHERE id = ?` never matched an INTEGER column - `GET /api/users/{id}` returned 404 for a row that plainly existed (and `GET /api/users` listed it). The router now relabels path captures as UTF-8 so they bind as TEXT, which SQLite coerces to the column's integer affinity, and the row matches. Typed `{id:int}` params were never affected - they cast to an Integer. The SQLite driver is left alone on purpose: coercing every binary string there would corrupt genuine BLOB writes, so the encoding is fixed at the source (the router).

Python, PHP, and Node were confirmed unaffected - their string path params already bind as TEXT - and each gains a real regression test: real router extraction feeding a real SQLite integer-primary-key lookup, no mocks, so the contract cannot silently drift. No new third-party dependencies.

## v3.13.49 (2026-06-30) - Current tina4-js runtime bundle + reactive-select guidance

Refreshes the bundled tina4-js runtime that every Tina4 app loads from `/js/tina4js.min.js`. The shipped script-tag bundle had drifted behind npm: it predated persistent signals and the i18n module, because the minified IIFE was never committed to the tina4-js repo, so `tina4 install tina4-js` downloaded a 404 and fell back to a stale copy. tina4-js 1.4.1 fixes the source of the drift (the bundle is now tracked in git and built in CI), and this release vendors the current bundle so a fresh install serves persistent signals and i18n out of the box. Run `tina4 install tina4-js` to refresh an existing app immediately.

It also documents a reactive-`<select>` footgun in the bundled tina4-js skill. A `<select>` whose options come from a reactive block loses its selection when the options re-render if you bind `.value` on the select. Bind `?selected` on each `<option>` instead, so every option owns its selected state and survives a re-render. No framework code changed.

## v3.13.48 (2026-06-29) - i18n hardening, swagger decorator-stacking fix, and skill env-name corrections

Three threads, all verified against real dependencies, no mocks.

**i18n now agrees across all four frameworks.** Interpolation is partial and never throws: a `{name}` token present in the parameters is replaced, and a missing or malformed placeholder (`{x.y}`, `{n:d}`, a stray brace) stays literal, so a broken template can no longer crash `t()`. Leaf-key aliasing is first-wins and never overwrites an explicit flat key, so a real top-level `home` beats a derived `nav.home` alias. Non-string locale values render JSON-native: `true`, `false`, `null`. Ruby also stops crashing on a malformed JSON or YAML locale file (it logs the file and skips it), loads a locale lazily on `set_locale`, and lists `available_locales` from the files on disk. **Breaking:** the PHP and Node `I18n` constructor argument order is now `(locale, path)` to match the Python master, and Ruby interpolation tokens are now `{name}`, not Rails-style `%{name}`. Update each `new I18n(...)` call to the new order, and change `%{name}` to `{name}` in shared locale files.

**Swagger decorators stopped dropping metadata (Python).** Stacking `@description` above `@tags` above `@get` lost the description with no error: every decorator returned a new wrapper carrying only its own attribute, but `@get` is innermost and registers the bare handler, so only the decorator touching `@get` reached the generated spec. The decorators now annotate the handler in place and return the same object, so every field survives in any order. A regression test stacks five decorators through the real router and asserts each one lands in the OpenAPI operation. PHP, Ruby, and Node attach Swagger metadata through a single meta object, so they never had this bug; each gains a lock-in test that proves a combined annotation keeps every field.

**The bundled AI skill shipped wrong env names.** The skill told assistants to write `SECRET=`, `SWAGGER_TITLE=`, and `API_KEY=` in `.env`. Tina4 3.12 made the `TINA4_` prefix mandatory, and the startup guard refuses to boot on a legacy un-prefixed name, so an app scaffolded from the skill never bound its port. The skill now teaches `TINA4_SECRET`, `TINA4_SWAGGER_TITLE`, and `TINA4_API_KEY`, and the connection-string examples use the schemes the driver registry accepts (`postgresql://`, `sqlite:`). The JWT secret reads from `TINA4_SECRET` only.

No new third-party dependencies.

## v3.13.47 (2026-06-25) - Open-issue batch: migration comment splitting, global middleware, SCSS interpolation

Three reported issues, fixed and locked in with tests against the real thing.

**Migration statement splitter (#54).** A migration whose SQL carried a `;` inside a `-- ...` line comment could fragment into broken pieces in the frameworks that split before stripping comments. PHP's splitter was already a single-pass, quote- and comment-aware scanner and never fragmented, so it changed in one way only: it now strips `--` and `/* */` comments from the emitted SQL instead of carrying them through, byte-identical with Python, Ruby, and Node. Named regression tests cover a `;` inside a line comment, a `;` inside a block comment, a `;` and a `--` inside string literals, and an end-to-end migrate against a real temp SQLite database, with no mocks.

**Global middleware lock-in (#55).** Middleware registered globally with `Router::use(...)` / `Middleware::use(...)` already ran on every route in PHP. A lock-in test now guards the contract - `Router::use` registers into the one global registry the dispatcher reads, the before and after hooks fire, and a class registered twice is deduped - so the regression fixed in the Python master this release cannot creep in.

**SCSS `#{}` interpolation (#116).** The SCSS compiler did not support interpolation, so `calc(100% - #{$gap})` left the `#{...}` in the output and corrupted the CSS around it. The compiler now resolves `#{ ... }` before variable substitution and nesting: a `$variable` inside the braces resolves to its value and anything else inlines verbatim, so `calc(100% - #{$gap})` becomes `calc(100% - 20px)` and `.icon-#{$name}` becomes `.icon-home`. Shipped across all four frameworks for parity.

No new third-party dependencies. Full suite: 2,727 passing.

## v3.13.46 (2026-06-24) - MySQL/MSSQL batch atomicity tests

The MySQL and MSSQL batch-insert tests checked that all three rows landed, but not that a failed batch rolls back. They now cover the same atomic-rollback and single-row contract the SQLite and PostgreSQL tests already enforce: a batch with a bad row (a NULL into a NOT NULL column) raises and leaves the table unchanged, run against the real engines with no mocks. No framework code changed - Database::executeMany already wraps the batch in one transaction and the adapters re-raise on a bad row; this locks the behaviour in as a regression guard. No new third-party dependencies.

## v3.13.45 (2026-06-24) - SQLite commit resilience + real-service test hardening

A standalone write under autocommit lands through SQLite's own autocommit, so a later explicit `commit()` finds no open transaction to close. SQLite reports that as a harmless warning, and on some platform builds of libsqlite3 the warning surfaced as an exception the adapter did not catch - so a redundant commit raised instead of doing nothing. `commit()` and `rollback()` now absorb the no-transaction case on every build while still surfacing any other error loudly. The data was already committed either way; this only stops the no-op commit from throwing. Real-service test hardening rounds out the release. No new third-party dependencies.

## v3.13.44 (2026-06-24) - Real-service bug-fix sweep (no mocks)

Standing up live infrastructure - PostgreSQL, MongoDB, Redis, Valkey, Memcached, RabbitMQ, Kafka - and running the suites against the real services surfaced a batch of bugs that mock-based and skipped tests had hidden. This release fixes them across the family and makes the no-mock rule absolute: a test that touches a dependency exercises the real service, never a stand-in. **Migrations on PostgreSQL/MySQL/MSSQL:** the migration runner built its bookkeeping table (`tina4_migration`) with SQLite-only DDL (`id INTEGER PRIMARY KEY AUTOINCREMENT`) for every non-Firebird engine, so `migrate()` failed on PostgreSQL with a syntax error and never applied a single file. The tracking-table id is now engine-aware - `SERIAL` on PostgreSQL, `AUTO_INCREMENT` on MySQL, `IDENTITY` on MSSQL, `AUTOINCREMENT` on SQLite. The existing migration tests only covered SQLite, which is why this shipped; a gated live-PostgreSQL migration test now guards the engine-aware path. **RabbitMQ:** the AMQP handshake now completes against a standard broker - it negotiates `Connection.TuneOk` instead of sending `channel-max=0`, which RabbitMQ rejected. **ORM:** a UUID primary-key insert returns its id through `INSERT ... RETURNING` instead of null. **Tests:** the database-factory tests assert both the `Database` facade and its underlying adapter, since `create()` returns the facade in v3. No new third-party runtime dependencies. All four suites pass against live services.

**MySQL and MSSQL join the provisioned test services (#262).** Both engines now run live round-trip tests by default, gated on reachability the same way the other services are. The non-skippable real-service gate fails on a MySQL or MSSQL skip under `TINA4_REQUIRE_SERVICES`, so a missing engine in CI breaks the build instead of passing quiet. CI gained a MySQL 8 container and a SQL Server 2022 container. Running the suites against these two engines for the first time surfaced adapter bugs that no prior test could reach.

The MSSQL adapter gained a `pdo_dblib` (FreeTDS) backend, used when the Microsoft `ext-sqlsrv` extension is absent. This is the same FreeTDS stack that Python (pymssql) and Ruby (tiny_tds) already lean on, so PHP now reaches SQL Server on macOS and CI without the Microsoft driver installed. `ext-sqlsrv` stays the primary path when it is present. Two more adapter fixes landed alongside it. `getLastId()` on MySQL now captures the insert id at write time, so a later read returns the real auto-increment value. The MSSQL row-count probe stripped its trailing top-level `ORDER BY` - the same fix the Python master needed, because the master carried the bug too: a `COUNT(*)` wrapper put the `ORDER BY` in a derived-table subquery, which SQL Server rejects, and the probe reported zero. Boolean binding was already correct in PHP, since the adapter coerces a raw boolean to `1`/`0` at the parameter boundary.

The no-mock rule reached further this release (#250). The messenger SMTP and IMAP tests now talk to a real GreenMail mail server, the WebSocket backplane tests run against a real Redis backplane, and the HTTP-client tests hit a real loopback HTTP server. Every in-test double in those paths is gone. The dev mailbox gained a non-ASCII round-trip regression test for parity with the family: write a message with an accented name, read it back, confirm the bytes survive. PHP escapes non-ASCII to ASCII in its message JSON, so it never carried the decode bug that bit Ruby, but the test now guards the contract.

## v3.13.43 (2026-06-22) - Queue: MongoDB fail/retry/dead-letter route to the active backend

Part of a cross-framework queue-lifecycle unification: the active backend (whatever `TINA4_QUEUE_BACKEND` selects) now owns the whole job lifecycle. PHP completed MongoDB jobs correctly, but `fail()`/`retry()` and the inspection verbs (`failed()`/`deadLetters()`/`retryFailed()`) routed to the local file backend - so a MongoDB job that failed was not requeued or dead-lettered through MongoDB, and the dead-letter inspection read the wrong store. Now the full lifecycle routes to the active backend: `fail()` requeues under `maxRetries` (resetting `available_at` so it retries promptly) or dead-letters at the limit, and `failed()`/`deadLetters()`/`retryFailed()`/`retry()` read and act on the active store. RabbitMQ and Kafka delegate redelivery to the broker, so the routing is a safe no-op for them. A lock-in test injects a stub backend and asserts complete acks, fail-under-max requeues, fail-at-max dead-letters, and the inspection verbs route to the active backend. Full suite: 3,477 passing.

## v3.13.42 (2026-06-22) - Swagger configurability for external and public APIs

Closes four gaps that pushed teams to hand-roll their own OpenAPI spec instead of using the built-in generator. **Configurable security schemes:** the built-in `bearerAuth` scheme honours `TINA4_SWAGGER_BEARER_FORMAT` (default `JWT`; set `opaque` for `sk_live_`-style keys), and setting `TINA4_SWAGGER_API_KEY_NAME` emits an `apiKeyAuth` scheme (`TINA4_SWAGGER_API_KEY_IN` is `header`/`query`/`cookie`). Register any scheme - including an `oauth2` flow with scopes - programmatically with `Swagger::addSecurityScheme(name, definition)` (`Swagger::resetRegistry()` clears it). **Per-route security:** a route declares its own requirement through its Swagger metadata - `security` as a scheme name plus a `scopes` array, a `{name: [scopes]}` map, a list of maps for an OR requirement, or `'public'` to mark a write route open (emits `security: []`). A secured route with no explicit declaration falls back to `TINA4_SWAGGER_DEFAULT_SCHEME` (default `bearerAuth`). Scopes stay spec-valid: only `oauth2`/`openIdConnect` schemes carry them, every other type gets `[]`, so the output validates against 3.0 and 3.1. **Path filtering:** `TINA4_SWAGGER_INCLUDE` documents only routes whose path starts with one of its comma-separated prefixes; `TINA4_SWAGGER_EXCLUDE` drops matching prefixes; framework internals (`/swagger`, `/__dev`) are always excluded. **OpenAPI 3.1 opt-in:** `TINA4_SWAGGER_OPENAPI` (default `3.0.3`) emits `3.1.0` when set to `3.1`/`3.1.0`. **Reusable component schemas:** register a shared shape with `Swagger::addSchema(name, schema)` and reference it from a route's `requestSchema` / `responseSchemas` metadata, extending the ORM-model `$ref` mechanism to arbitrary schemas. Identical behaviour and tests across all four frameworks. Zero new third-party dependencies. Full suite: 3,465 passing.

## v3.13.41 (2026-06-22) - Queue reservation/visibility timeout (at-least-once delivery)

A targeted fix for silent job loss in multi-replica / rolling-deploy setups. When a consumer reserved a queue message and then died before acknowledging - a crash, an OOM kill, a Kubernetes pod eviction - the message was stranded forever: never re-delivered, never retried, never dead-lettered. The file backend deleted the job on pop (lost outright); the MongoDB backend flipped the document to `processing` without advancing `available_at` and never re-evaluated it. Now a popped job is held as a reservation with `available_at = now + visibility_timeout` (plus a `reserved_at` stamp). If the consumer does not acknowledge in time, the next dequeue reclaims the abandoned reservation: it increments `attempts` and re-enqueues the job, or dead-letters it once it has hit `maxRetries`. A dead consumer can no longer strand a job - standard at-least-once delivery, the contract SQS and RabbitMQ already provide. The window is configurable via `TINA4_QUEUE_VISIBILITY_TIMEOUT` (default 300 seconds; `<= 0` disables the reclaim) or the per-queue `visibilityTimeout` option; `acknowledge()`/`failJob()`/`retryJob()` clear the reservation. RabbitMQ and Kafka are unchanged - the broker already owns redelivery there. Regression tests lock the behaviour in across all four frameworks (file backend: reclaim after the timeout, no reclaim before it, dead-letter past maxRetries, complete/fail clear the reservation, env override, disable-at-zero; MongoDB: dequeue advances `available_at` and the reclaim requeues or dead-letters). Zero new third-party dependencies. Full suite: 3,449 passing.

## v3.13.40 (2026-06-22) - MCP security hardening + Swagger/OpenAPI overhaul

A coordinated cross-framework release with two themes: MCP transport security and a full Swagger/OpenAPI sweep. **MCP security:** the built-in dev MCP server now authorises every request on the raw socket peer rather than a configured host name, closing a remote-reach surface where a debug box bound to `0.0.0.0` exposed the file and database tools to unauthenticated callers. The gate is two layers - a host-independent capability check (`TINA4_MCP`, else `TINA4_DEBUG`) and a per-request authorisation: loopback always passes, while a remote caller needs `TINA4_MCP_REMOTE=true` AND a token matching `TINA4_MCP_TOKEN` (fallback `TINA4_API_KEY`), sent as `Authorization: Bearer`, `X-MCP-Token`, or `X-Api-Key`. Every MCP surface returns 404 to a disallowed caller, the SQL tool is read-only (SELECT/WITH, no stacked statements), and the file tools are sandboxed to the project root. **Swagger:** the production on/off switch is wired for real - set `TINA4_SWAGGER_ENABLED=false` to disable `/swagger` and `/swagger/openapi.json` in any environment, or `true` to expose them in production (it falls back to `TINA4_DEBUG` when unset). Secured routes now carry a `bearerAuth` security requirement, so the documentation no longer presents protected endpoints as public. ORM models become reusable `components.schemas` referenced by `$ref` across all four frameworks. The spec is valid where it was not: wildcard and splat routes emit proper `{name}` path parameters, `operationId` values are de-duplicated, and WebSocket routes no longer leak an invalid method. **Swagger configuration:** `TINA4_SWAGGER_SERVERS` (comma-separated) drives a multi-server block, `TINA4_SWAGGER_UI_CDN` points the UI assets at a self-hosted mirror for air-gapped use, and the generator adds typed-parameter formats, enums, top-level tags, and multipart request bodies. **SqliteDocStore (new):** a pymongo-style document store with a zero-config SQLite fallback. `getCollection(name)` returns a real Mongo collection when a Mongo URI is set (`TINA4_MONGO_URI`, then `TINA4_SESSION_MONGO_URI`, then the legacy `TINA4_SESSION_MONGO_URL`), otherwise a SQLite-backed collection over a local file (`TINA4_DOC_STORE_PATH`, default `data/tina4_docstore.db`) - the call sites are identical, only the backend differs. It pushes filters down to JSON1 `json_extract` (equality, `$in`, `$nin`, `$gt`/`$gte`/`$lt`/`$lte`, `$ne`, `$exists`, `$regex`, `$or`, `$and`, dotted nested keys), supports `$set`/`$unset`/`$inc`/replace/upsert with lazy `sort`/`limit`/`skip`/projection cursors, ships a zero-dependency 12-byte ObjectId, and round-trips datetimes and ObjectIds so values stay queryable. Develop against the local store and switch to MongoDB in production by setting one env var. **Developer experience:** the blank-`TINA4_SECRET` warning now explains why it fired - the run was not detected as development - and gives both fixes (set `TINA4_SECRET`, or set `TINA4_DEBUG=true` to auto-generate one into `.env.local`); the legacy-env strict check now hints the names may come from a `.env` baked into a Docker image and points at `tina4 env --migrate`. **Session Mongo env parity:** the session and DocStore Mongo URI is canonical as `TINA4_SESSION_MONGO_URI` across all four frameworks, with `TINA4_SESSION_MONGO_URL` kept as a back-compat legacy alias (Python and PHP historically read `_URL`). **Tests:** new DB contract tests (execute raises on a bad statement, read-after-write, generator monotonicity, transaction bracketing) and a queue isolation contract (a job in one topic never leaks into another, and a queue on a fresh storage path starts empty). **Breaking:** the Swagger and MCP production gates are now enforced - if you relied on `/swagger` being reachable in production, set `TINA4_SWAGGER_ENABLED=true`, and a remote MCP caller now needs `TINA4_MCP_REMOTE=true` and a token. Zero new third-party dependencies. Full suite: 3,434 passing.

## v3.13.39 (2026-06-21) - Auto-migration, unified critical log level, fail-loud ORM, per-route WebSocket auth

A cross-framework parity sweep that hardens the data layer and tightens a few safe-by-default behaviours. **Migrations:** pending migrations can now run on startup, gated by `TINA4_AUTO_MIGRATE` and off by default so existing apps are untouched. A footgun pass adds numeric-aware ordering (so `10_` sorts after `2_`, not after `1_`), `CREATE TABLE` idempotency, a URL-safe `//` delimiter, and smart/curly-quote normalization in migration SQL before it runs. **ORM:** `save()`, `create()`, `QueryBuilder`, and the Mongo path now fail loud instead of swallowing errors - `save()` validates first and returns `false` with the reason on `getError()`, `create()` returns `false` when the write fails, and the silent fallbacks are gone. **Logging:** `critical` is now a first-class top-level severity, a new `Log::isEnabled($level)` lets callers skip building an expensive log payload, and logs default to stdout-only in production and container environments to avoid file bloat. **WebSockets:** a route can require authentication on the upgrade itself, before the socket is established. **Security:** the `/__dev/mcp` endpoint enforces its localhost guard and honors `TINA4_MCP_REMOTE`, and the built-in `Api` client strips the `Authorization` header on a cross-origin redirect and gains opt-in retry with backoff. **Env:** defaults align to the canonical `TINA4_` manifest with a uniform `.env.example` - CORS credentials are opt-in and AI hosts default to localhost. **Tooling:** the `tina4 metrics` coverage detection now counts full-package-path imports and short (3-character) class names, the complexity counter no longer over-counts string literals, and Kafka TLS/SASL config reaches the producer and consumer. Breaking: `critical` is now a top-level severity and the previous toggle is removed - update any logging configuration that relied on it. Full suite: 3,355 tests, zero failures.

## v3.13.38 (2026-06-19) - Coordinated security & robustness release

A large bundled release closing a cross-framework hardening sweep. **WebSockets:** the Redis backplane is now wired for real - local-first delivery, then a published envelope on the shared `tina4:ws` channel, relayed with an origin guard (no own-echo, no cluster loop) - and, critically, the backplane class is now PSR-4 autoloadable (it had never loaded). Plus an origin allow-list (`TINA4_WS_ALLOWED_ORIGINS`), an idle reaper (`TINA4_WS_IDLE_TIMEOUT`), resilient broadcast, OP_CONTINUATION frame reassembly, and SSE hardening (generator error mid-stream). **Sessions:** the `DatabaseSessionHandler` SQL injection is fixed - the client-controlled session id is no longer interpolated into SQL; every query is parameterized. Plus a log-loud-and-degrade backend-failure policy (`TINA4_SESSION_STRICT` to re-raise). **GraphQL/WSDL:** a SOAP `<!DOCTYPE>` is rejected before parsing (SOAP 1.1 forbids DTDs - closes the XML entity-expansion / external-entity surface), a recursion-depth guard (`TINA4_GRAPHQL_MAX_DEPTH`, default 50) catches deep queries **and** circular fragments, and resolver/SOAP faults are masked in production with the real cause logged (full detail only under `TINA4_DEBUG`). **Tooling:** a new `tina4 metrics` command reports the top-N code-health offenders with `--top/--json/--fail-on/--path`, and the coverage test-detection is now precise (a real `use`/FQCN import or defined-class reference, not a name-substring scan). Zero new third-party dependencies. Full suite: 3,219 passing.

## v3.13.37 (2026-06-18) - Dev-admin editor: Ruby + more syntax highlighting

The dev-admin code editor now highlights `.rb`/`.rs`/`.go`/`.java`/`.scss` (the CodeMirror bundle was missing those grammars). Also aligned the file-read language map to the Python master (scss→css, add rust/go/java, txt/csv/log→text, xml→html, shell variants, gemspec/rake→ruby, svg) and added no-extension `Dockerfile` detection. Dev-mode tooling only. Full suite: 3,078 passing.

## v3.13.36 (2026-06-18) - Instant WebSocket dev-reload (parity)

Dev-reload is now a WebSocket push, matching Python. `tina4 serve` POSTs `/__dev/api/reload`; `DevAdmin` invalidates OPcache for the changed file and re-discovers routes in-process (`RouteDiscovery::rescan`, no respawn, same PID), then broadcasts `{type, file, mtime}` over `/__dev_reload`. The injected client is WebSocket-primary - instant reload, CSS hot-swap, and it only falls back to the `/__dev/api/mtime` poll when the socket drops. `Router` registers `(method, path)` with replace-in-place semantics so the re-loaded handler wins. Debug-mode only - production is untouched. Full suite: 3,078 passing.

## v3.13.35 (2026-06-17) - Live MCP endpoint for AI agents

The built-in MCP server is now actually reachable. Its 48 dev tools (live DB queries, sandboxed file I/O, route list, project overview, docs search) were fully built but never mounted. `DevAdmin::register()` now mounts `/__dev/mcp` (JSON-RPC) + `/__dev/mcp/sse` in debug mode, so an AI agent (Claude Desktop/Code) gets live access scoped to the running project. The SSE handshake was made SAPI-safe for the built-in server. 15 new tests; full suite 3,064 passing.

## v3.13.34 (2026-06-17) - Store images + dual-port test

Fixed blank product images in the example store: the storefront templates read `product.imageUrl` (camelCase) but `toDict()` emits snake_case `image_url`. Aligned the templates to `image_url` (matching the API and the Python store). Corrected stale env-var names in `example/.env.example` (notably `SECRET` → `TINA4_SECRET`, which PHP rejects at boot). Added `DualPortReloadTest` locking in the AI dual-port dev mode (main port hot-reloads; port+1000 is the stable AI port). Full suite: 3,049 passing.

## v3.13.33 (2026-06-17) - Queues: priority pop + automatic dead-lettering (⚠ behavioural change)

**Behavioural change.** `$job->fail()` now re-enqueues (incrementing `attempts`) until `attempts >= maxRetries`, then dead-letters - a `consume` loop retries `maxRetries` times automatically. `pop`/`consume` are now priority-ordered (was FIFO); new additive `retryBackoff` config. Bug fix: `Job::$topic` is now **public** (was private → fatal when read). Only the file backend changed. Queue chapter rewritten to match. Full suite: 3,046 passing.

## v3.13.32 (2026-06-17) - Caching: per-query bypass + X-Cache headers + string-middleware (chapter rewritten)

Added a per-query bypass - `$db->fetch(..., noCache: true)` (also `fetchOne`/`fetchAll`) skips lookup + store. `ResponseCache` now sets `X-Cache: HIT|MISS` + `X-Cache-TTL`, and the `"ResponseCache:300"` string-middleware form now works (parity with Python/Ruby) - this also fixed a dispatch bug where the response cache's store step never ran on the route path. The KV helpers live in `\Tina4\Middleware\`. The caching chapter was rewritten to match code (real `cacheStats()` shapes, all seven backends + file fallback, the three cache layers, accurate env/defaults), dropping earlier aspirational claims. Full suite: 3,035 passing.

## v3.13.31 (2026-06-17) - Version alignment (no functional change in PHP)

Cross-framework version alignment with the Ruby request/response parity release. PHP's request body, query, headers, cookies, file uploads (raw-bytes `content`), and response surface were already in parity - no behavioural change here. Full suite: 3,024 passing.

## v3.13.30 (2026-06-16) - Typed route params coerce + /__dev auth-bypass fixed (⚠ behavioural change)

**Behavioural change.** Typed path params now arrive coerced: `{id:int}` → `int`, `{price:float}` → `float` (other types and untyped params stay strings; matching unchanged). `compilePath()` computed the param-type map but `addRoute()` dropped it, so the existing cast in `matchInTable()` was dead code and `{id:int}` arrived as the string `"42"` - now wired through, bringing PHP in line with Python/Ruby/Node. Separately, a bug fix: the dev-admin auth bypass tested `$request->url` (always the full `scheme://host/path`) so it never matched - a write to `/__dev/...` (and the gallery prefixes) returned 401 instead of bypassing; it now tests `$request->path`. Full suite: 3,024 passing.

## v3.13.29 (2026-06-16) - Live API search finds magic methods + ranks qualified queries

Parity with the Python master fix for the `api_*` live-reflection tools (what AI assistants query for real signatures):

- **Magic methods are now indexed.** `Frond::addFilter` / `addGlobal` / `addTest` dispatch through `__call`/`__callStatic`, so the token parser never saw them. `Docs` now reads `@method` docblock tags (and `Frond` declares them, which also helps IDE autocomplete), so `api_method("Frond", "addTest")` returns `addTest(string $name, callable $fn)`.
- **Class-qualified ranking.** `api_search("Frond.addTest")` now ranks `Frond::addTest` first - the owning class, fqn segments, and an exact `Class.method` match are scored.
- **Natural-name lookups.** `api_class`/`api_method` resolve a bare class name (`Database`) and leading-backslash variants, not just the exact fqn.

The bundled AI skills now tell assistants to query `api_*` before guessing. Full suite: 3,014 passing.

## v3.13.26 (2026-06-16) - pooling fixes: standalone writes auto-commit + independent pooled PostgreSQL connections

**Behavioural default change.** A standalone write made **outside** an explicit transaction now auto-commits on its own connection before returning - the default `autoCommit` is flipped to *on* across all adapters. Previously autocommit was off by default, which broke connection pooling: a standalone write stayed uncommitted on one pooled connection while the next read round-robined to another and saw nothing. Explicit transactions (`startTransaction`/`commit`/`rollback`) stay atomic - MySQL/MSSQL suspend driver autocommit for the duration of the transaction, and Firebird's commit branch is gated on `transaction === null`. Set `TINA4_AUTOCOMMIT=false` for strict manual-commit mode (per-connection override: `Database::create($url, autoCommit: false)`).

**PostgreSQL pooling fix.** `pg_connect()` was reusing a single libpq connection for every adapter that shared a DSN, so a `pool` of N adapters all shared **one** connection - and closing one broke the rest. Pooled adapters now each open an independent connection (`PGSQL_CONNECT_FORCE_NEW`), matching Python, Node, and Ruby.

Verified live on PostgreSQL: standalone write visible from a separate connection, explicit rollback discards, explicit commit persists, and pooled standalone writes visible across every round-robin connection. Full suite: 3,011 passing.

## v3.13.24 (2026-06-15) - unified cache backends across response, KV, and persistent DB cache

The response/KV cache now supports **seven backends**, selected by `TINA4_CACHE_BACKEND`: `memory` (default), `file`, `redis`, `valkey`, `memcached`, `mongodb`, and `database`. `TINA4_CACHE_URL` carries the connection string for `redis`/`valkey`/`memcached`/`mongodb`, or a SQL URL for the `database` backend (which falls back to `TINA4_DATABASE_URL`). Credentials can be embedded in the URL (`redis://user:pass@host`, `redis://:pass@host`, `mongodb://user:pass@host`) or supplied via `TINA4_CACHE_USERNAME` / `TINA4_CACHE_PASSWORD` (mirroring `TINA4_DATABASE_USERNAME`/`_PASSWORD`); memcached is unauthenticated. The usual `TINA4_CACHE_TTL` (60), `TINA4_CACHE_MAX_ENTRIES` (1000), and `TINA4_CACHE_DIR` (`data/cache`) still apply.

**Graceful fallback:** if a configured backend's driver is missing or the service/credentials are unreachable or wrong, the cache logs a warning and falls back to the **file** backend - a real persistent cache, never a silent no-op.

The **persistent DB query cache** (`TINA4_DB_CACHE=true`) now routes through the same backend set via `TINA4_DB_CACHE_BACKEND` + `TINA4_DB_CACHE_URL`, so multiple instances share one cache with global write-invalidation. `cacheStats()` now reports a `backend` field alongside `mode`.

Full suite: 3,010 tests passing.

## v3.13.23 (2026-06-15) - request-scoped DB query cache, on by default

A new **request-scoped query cache** protects your database from rapid repeat reads. Within a single request, identical `SELECT`s and ORM reads are deduped automatically - the DB is hit once and subsequent identical reads are served from memory. The cache is **cleared at the start of every request** (so it never serves stale rows across requests) and **flushed on any write** (insert/update/delete/execute). For non-request contexts (scripts, workers) a short safety TTL applies.

It is **on by default** via `TINA4_AUTO_CACHING=true` (off-switch `TINA4_AUTO_CACHING=false`); the in-request TTL is `TINA4_AUTO_CACHING_TTL` (default 5 seconds). The existing `TINA4_DB_CACHE` (default `false`) remains the separate *persistent* cross-request cache (TTL `TINA4_DB_CACHE_TTL`, default 30s) and is not cleared per request. `cacheStats()` now reports a `mode` field: `"request"` (default), `"persistent"`, or `"off"`.

**Also fixed:** the `\Tina4\Middleware\cache_get/cache_set/cache_delete/cache_clear/cache_stats` helpers now autoload on a plain `require` - previously they fataled with "undefined function" until the `ResponseCache` class had been touched.

Full suite: 2,992 tests passing.

## v3.13.21 (2026-06-15) - docs: `render()` corrections + version re-sync

Documentation consistency pass - no behavior change. References to a `$response->template()` *method* (which never existed) are corrected to **`$response->render()`** - the real method; `template` is only the route-level binding, not a response method. Fixed across the AI guide, `llms.txt`, and the gallery page. Version re-synced to 3.13.21 with the other frameworks (this release also carries a Python-side JWT-secret security hardening).

Full suite: 2,433 tests passing.

## v3.13.19 (2026-06-15) - return domain objects, construct from JSON, and one database binder

Three ergonomic improvements surfaced by the live side-by-side review of the book's own examples across all four frameworks.

### `$response(...)` serializes domain objects

Return an ORM model, an array of models, or a query result straight from a route - Tina4 serializes it to JSON. No more hand-rolled `toDict()` / `toJson()`:

```php
Router::get('/api/users', function ($request, $response) {
    return $response((new User())->all());     // array of models -> JSON array
});
```

A single model becomes a JSON object; an array of models or a `DatabaseResult` becomes a JSON array. Plain arrays and strings behave exactly as before - purely additive. (`Response::json()` still pretty-prints.)

### Construct a model from JSON, or data-first

```php
new User('{"name": "Alice"}');     // JSON object string -> one record
new User(['name' => 'Alice']);     // array data-first (NEW - no need for the data: arg)
new User(data: ['name' => 'Alice']); // still works
new User($db, ['name' => 'Alice']);  // still works ($db first)
```

The first constructor argument is now type-detected (a `DatabaseAdapter`, an array, or a JSON string). Passing a **list** to a single-record constructor throws `InvalidArgumentException`. To build many records, map over the list.

### ⚠ Breaking - one database binder: `bindDatabase`

The ORM-to-database binder is now **`bindDatabase`** (was `ORM::setGlobalDb`). The default is unchanged - models still auto-bind to `TINA4_DATABASE_URL` (via `Database::fromEnv()`), so apps relying on the `.env` default need **no change**.

```php
// Most apps: nothing to do - the .env default is auto-bound.

\Tina4\ORM::bindDatabase(Database::create('sqlite:///app.db'));   // override the default

// Register a NAMED connection and point a model at it:
\Tina4\ORM::bindDatabase(
    Database::create('postgres://.../analytics', username: 'u', password: 'p'),
    name: 'analytics'
);

class Visit extends \Tina4\ORM {
    public \Tina4\Database\DatabaseAdapter|string|null $_db = 'analytics';  // uses the analytics connection
}
```

`bindDatabase($db, name: '...')` registers a named connection; a model selects it with `$_db = '...'`. A missing named connection throws a clear error.

**Migration:** rename `\Tina4\ORM::setGlobalDb(...)` → `\Tina4\ORM::bindDatabase(...)`. That is the only change.

Full suite: 2,433 tests passing. Shipped with parity across all four frameworks.

## v3.13.18 (2026-06-15) - ORM relationship + QueryBuilder fixes + boolean param binding

Found by the live side-by-side validation against PostgreSQL.

- **QueryBuilder `first()` / `count()` returned null/0** even with matching rows - `get()` returns a `DatabaseResult` but `first()`/`count()` read `$result['data']` (raw-array shape). All three now consume the result via a shared `extractRecords()`: `first()` returns the row, `count()` the integer, and `groupBy().get()` returns every group.
- **`belongsTo` returned null for a snake_case FK column** under autoMap - the lookup read `$this->{column}` but autoMap stores the value under the camelCase property. It now reverse-maps column → property, so the documented `$foreignKeys=['author_id'=>'Author']` form resolves the parent (lazy `$post->author`, explicit, and eager `include:['author']`).
- **`fetch()` corrupted SQL that already ended in `LIMIT`** - it appended `LIMIT 100 OFFSET 0` unconditionally (`... LIMIT 1 LIMIT 100`), PG errored, the adapter swallowed it → empty result. It now skips the append when a trailing `LIMIT` is present.
- **Bound PHP booleans are normalised** to the literal the column accepts - `'t'`/`'f'` on PostgreSQL's native `BOOLEAN`, `1`/`0` on the integer/BIT-backed engines (SQLite, MySQL, MSSQL, Firebird). Previously `fetch('... WHERE active = ?', [false])` bound `''` and PG rejected it.
- Doc: `DatabaseUrl` docstring corrected to `postgres://` / `postgresql://` (not `pgsql://`).

Python/Ruby/Node were already correct on the boolean binding (verified live). Full suite: 2,416 passing.

## v3.13.17 (2026-06-15) - PostgreSQL: native-type reads + `execute()` reports real failure

Two fixes found by the live side-by-side validation against PostgreSQL.

### Reads return native PHP types (not strings)

`ext-pgsql` returns every column as a string - `id` as `"1"`, a boolean as `"t"`, floats as `"12.50"`. A Tina4 app written on SQLite (native-ish types) silently changed behaviour when moved to PostgreSQL, and diverged from Python/Node which return native types. `PostgresAdapter` now coerces each column from its PG type: `int2`/`int4`/`int8` → `int`, `bool` → `bool`, `float4`/`float8`/`numeric` → `float` (nulls preserved; `bytea` unchanged). So `$result[0]` is now `{"id":1,"active":true,...}` instead of all-strings. (`timestamp`/`date`/`json`/`uuid` stay strings - a minor diff vs Python's datetime objects.)

### `execute()` propagates failure

`Database::execute()` returned `true` unconditionally for a plain write/DDL, discarding the adapter's boolean result - so a failed INSERT/UPDATE/DELETE/DDL reported success. (Python/Ruby/Node were already correct: their adapters *raise* and the facade catches; PHP adapters *return false*, which the facade ignored.) It now returns `false` and populates `getError()` from the adapter when the statement fails. A write affecting 0 rows is still a success.

Full suite: 2,405 passing. Python/Node already had both behaviours (Ruby ships the native-reads half), so this is primarily a PHP release.

## v3.13.16 (2026-06-15) - `createTable()` works on PostgreSQL + `DatabaseResult` index access

Found by the live documentation-verification pass - running the book's own samples against a real PostgreSQL database. The documented code-first schema path, `ORM::createTable()`, was silently broken on PostgreSQL: it ignored the model entirely, emitted a hardcoded SQLite `INTEGER PRIMARY KEY AUTOINCREMENT`, PG rejected it, and it returned `true` while creating **no table**.

### `createTable()` is now engine-aware

It now derives the DDL from the model's typed properties:

- **datetime → `TIMESTAMP`** on PostgreSQL/Firebird (no `DATETIME` there); `DATETIME` on SQLite/MySQL/MSSQL.
- **bool → native `BOOLEAN`** (PostgreSQL/MySQL), `BIT` (MSSQL), `INTEGER` (SQLite/Firebird); boolean `DEFAULT`s engine-aware (`TRUE`/`FALSE` vs `1`/`0`).
- Auto-increment translated per engine (`SERIAL` on PostgreSQL) via `SqlTranslation`.
- **A failed `CREATE` now returns `false`** (with a post-create `tableExists` re-check + `Log::error`) instead of reporting success.

`DatabaseResult` already implements `ArrayAccess`, so `$result[0]` works (no change needed there).

Verified against PostgreSQL 16: a model with `id` (auto-increment) + string + bool + datetime creates, inserts, and round-trips natively (`SERIAL`, `boolean`, `timestamp`; `WHERE active = TRUE` matches). New `CreateTablePostgresTest` (PG-gated). Full suite: 2,400 passing. Shipped with parity across all four frameworks.

## v3.13.14 (2026-06-13) - Logs reach stdout in containers + per-request logging + schema-qualified tables (#48)

**Cross-framework release (all four).** Deployed Docker containers were getting no application logs. In production PHP set `Log::$stdout = false` (logs went only to `logs/tina4.log` inside the container), never read `TINA4_LOG_LEVEL`, and didn't flush stdout. `docker logs` reads PID 1 stdout - so it was empty. A follow-on report - the dev server going silent after startup - surfaced a second gap: requests were never logged.

### PHP also: #119 - legacy-env guard crash under the built-in server

`App::checkLegacyEnvVars()` wrote its migration message with `fwrite(STDERR, ...)`. `STDERR` is only auto-defined for the `cli` SAPI - under `cli-server` (the built-in dev server) a bare `STDERR` in `namespace Tina4` resolved to the undefined `Tina4\STDERR`, so a user with a stray legacy var (e.g. `SMTP_HOST`) in `.env` got `Uncaught Error: Undefined constant "Tina4\STDERR"` instead of the actionable "rename these vars" message. Now writes to the `php://stderr` stream (available in every SAPI). The same latent pattern in `MCP.php` was fixed alongside. New `cli-server` subprocess regression test reproduces it.

### Per-request logging - on by default in dev

Every request now logs one line through `Tina4\Log` (→ stdout), on by default in dev and opt-in for production via `TINA4_LOG_REQUESTS`:

```
2026-06-12T10:15:03.221Z [INFO   ] GET /api/users -> 200 (12.3ms)
```

`Router::dispatch()` emits it at the end of every request. Format is identical across all four frameworks: `METHOD /path -> STATUS (Nms)`. Default: on under `TINA4_DEBUG`, off in production; `TINA4_LOG_REQUESTS=true`/`false` overrides. The `RequestLogger` middleware's line now includes the status code for parity.

### What changed (stdout)

1. **stdout is ON by default** (was: only when `TINA4_DEBUG=true`). The default-case in `Log::configure()` now sets `$stdout = true`. `TINA4_LOG_OUTPUT=file` still opts out.
2. **`Log::configure()` now reads `TINA4_LOG_LEVEL`** from the environment (it previously ignored it). Default level is **INFO** (was effectively DEBUG).
3. **stdout is flushed** - `fflush()` after each `fwrite()` so logs appear immediately under the long-running built-in server instead of sitting in the stream buffer.
4. **Production stdout is clean JSON** - `writeStdout()` no longer prepends ANSI colour when not in human-readable mode, so aggregators can parse the line.

```php
// In a container (TINA4_DEBUG unset), default config:
\Tina4\Log::info("worker started");
// pre-v3.13.14: only in logs/tina4.log inside the container → docker logs empty
// v3.13.14:    {"timestamp":"...","level":"INFO","message":"worker started"} on stdout
```

### Why it spanned all four

The bug was the same architectural decision in every framework - production logged to a file (or suppressed stdout) when a container's stdout *is* the log sink:

| Framework | Pre-v3.13.14 cause | Fix |
|---|---|---|
| Python | `not _is_production` gate suppressed stdout; default ERROR | stdout always on (flushed); default INFO |
| PHP | `$stdout = $development` (file-only in prod); no `TINA4_LOG_LEVEL` read | stdout default on + `fflush`; reads `TINA4_LOG_LEVEL`; default INFO |
| Ruby | stdout written but never flushed (block-buffered on non-TTY); default ALL | `$stdout.sync = true`; default INFO; accepts plain + bracket names |
| Node | `!isProduction()` gate suppressed console; default DEBUG | console always on; production emits JSON; default INFO |

The Rust `tina4` CLI was already correct (inherits child stdio).

### Schema-qualified tables (#48) + a PostgreSQL `fetch()` regression

Issue #48 - *"Database Table Does Not Exist"* on PostgreSQL. A model whose table lives in a non-default schema (`gift_cards.gift_card`, MSSQL `dbo.widget`, MySQL `otherdb.table`, SQLite ATTACH `extra.widget`) was invisible to the framework's introspection. `tableExists`, `getTables`, and `getColumns` hardcoded the default namespace (`public`) and matched the whole dotted string as one flat name - so plain reads worked, but `createTable`, migrations, and auto-CRUD were blind to the table and reported it missing.

All introspection is now schema-aware on every affected engine:

- **PostgreSQL** - `tableExists` uses `to_regclass()` (honours schema + `search_path`); `getColumns` filters by `table_schema`; `getTables` lists every non-system schema and returns non-`public` tables schema-qualified.
- **MySQL** - schema = database; a qualified name checks that catalog, a bare name defaults to `DATABASE()`.
- **MSSQL** - honours `dbo.table`; a bare name matches in any schema.
- **SQLite** - honours an ATTACH alias (`extra.widget`) for both `tableExists` and `getColumns`.
- **Firebird** - N/A (no schemas).

Verified against a live PostgreSQL 16 container: `tableExists('gift_cards.gift_card') → true`, `getTables → ['gift_cards.gift_card', 'gift_cards.transaction']`, `getColumns → 12 columns` - identical results across all four frameworks.

> **A v3.13.12 regression surfaced while cross-checking #48.** `PostgresAdapter` referenced `stripTrailingSemicolons()` (added in v3.13.12) and the new `splitSchema()` but never mixed in `SqlNormalizerTrait` - so **every PostgreSQL `fetch()` / `fetchOne()` / `getColumns()` fatalled** with *"Call to undefined method"*. It shipped silently because PHP's PostgreSQL test suite skips without a live server. Fixed with a one-line trait mix-in and pinned by server-free reflection guards that assert all five SQL adapters expose the normalizer helpers - so this can never regress unnoticed again.

### Tests

- PHP: 2,394 passed (+63 new - stdout/level/file gating; request-log format + gate; #119 cli-server repro + the previously-unregistered LegacyEnvGuard suite now gated in CI; #48 schema-qualified introspection + PG `SqlNormalizerTrait` regression guards)
- Family: Python 2,829 · PHP 2,394 · Ruby 2,999 · Node 3,628 - **11,850 total, zero regressions.**

---

## v3.13.13 (2026-06-11) - PHP only: large-response truncation fix

**PHP-only release.** Python, Ruby, and Node stay at v3.13.12 - the bug is specific to PHP's built-in socket server, which is the only one of the four frameworks that hand-rolls a non-blocking socket write loop. Python (asyncio `StreamWriter.drain()`), Ruby (WEBrick), and Node (`node:http`) all delegate body writes to a server that handles a full send buffer correctly, so none of them can hit this.

### Responses larger than the OS send buffer are no longer truncated

`Tina4\Server` (the standalone HTTP server behind `tina4 serve`, including when run as an nginx upstream) wrote responses with a non-blocking `fwrite()` loop. On a non-blocking socket, `fwrite()` returns `0` when the OS send buffer is full - this is **EAGAIN ("try again")**, *not* a closed socket. The pre-v3.13.13 loop treated `0` as fatal and `break`ed mid-body:

```php
while ($written < $total) {
    $n = @fwrite($client, substr($httpResponse, $written));
    if ($n === false || $n === 0) {
        break;   // BUG: 0 is "buffer full", not "socket closed"
    }
    $written += $n;
    // ...only waited for drain AFTER a successful write
}
```

Symptom: a ~4 MB attachment download returned `200` with the correct `Content-Length` but only part of the body (the cutoff varied run-to-run - we saw 2.31 MB and 1.30 MB), nginx logged `upstream prematurely closed connection while reading upstream`, and the browser showed a failed download. Anything larger than the send buffer (~200 KB-1 MB depending on platform) was affected - the dev-admin JS bundle had hit a related case.

### The fix

Body writes now go through `Server::writeFully()`, which:

- On `fwrite() === 0`, **waits for the socket to become writable** (`stream_select` on the write set, 5 s no-progress timeout) and retries, instead of bailing.
- Only gives up on a real error (`false`) or a client that has genuinely stopped reading for 5 s.
- Writes in 512 KB chunks so it doesn't recopy the entire remaining tail on every iteration (O(n) instead of O(n²) for large bodies).

```php
$n = @fwrite($client, substr($data, $written, 524288)); // 512KB
if ($n === false) break;                 // real error
if ($n === 0) {                          // buffer full - wait, don't quit
    $sw = [$client]; $sr = []; $se = [];
    if (@stream_select($sr, $sw, $se, 5) === 0) break; // 5s no progress → gone
    continue;
}
$written += $n;
```

The error-response path (`sendHttpError`) routes through the same helper.

### Why PHP only - cross-framework verification

| Framework | Built-in server | Body write | Truncation risk |
|---|---|---|---|
| **PHP** | raw `stream_socket_server` | non-blocking `fwrite` loop | ❌ **was buggy** → fixed |
| Python | asyncio `start_server` | `write()` + `await drain()` | ✅ safe |
| Ruby | WEBrick | blocking `IO#write` | ✅ safe |
| Node | native `node:http` | atomic `res.end(buffer)` | ✅ safe |

### Tests

- New `tests/ServerLargeResponseTest.php`: pushes 4 MB through a deliberately stalled reader (via `pcntl_fork`) and asserts every byte arrives. Verified to **fail on the old loop** (truncated at the 8 KB socketpair buffer) and **pass on the fix** (full 4 MB).
- PHP: 2,331 passing.

> Housekeeping caught alongside this fix: the CI test invocation (`vendor/bin/phpunit`, xml-file-list mode) ran fewer tests than `composer test` (directory mode), so newly-added test files could silently skip CI. The v3.13.12 SQL-normalizer tests and this release's socket test are now registered in `phpunit.xml`; fully reconciling the two invocations is tracked separately.

---

## v3.13.12 (2026-06-11) - SQL safety + implicit ORM binding + `fetchAll` correctness

Three high-impact fixes that close out long-standing footguns. All three ship with full parity across all four frameworks.

### `fetchAll` actually fetches ALL rows now (no silent 100-row truncation)

Pre-v3.13.12 the convenience method defaulted to `$limit = 100` and silently truncated. The name says `fetchAll` - it should fetch them all:

```php
// 150 rows in the table
$db->fetchAll("SELECT * FROM rows");
// pre-v3.13.12: returns 100 rows, silently drops the other 50
// v3.13.12:    returns all 150 rows
```

The new default is `$limit = 0`, which all six adapters (SQLite, PostgreSQL, MySQL, MSSQL, Firebird, ODBC) now interpret as "no pagination injection" - your SQL runs verbatim. To opt back into a cap, pass an explicit `$limit`:

```php
$db->fetchAll("SELECT * FROM events", [], 500);   // capped at 500
$db->fetchAll("SELECT * FROM users");             // all rows
```

`$db->fetch()` (the paginated sibling that returns a `DatabaseResult` with count metadata) keeps its 100-row default - pagination is its job. Only the `fetchAll` convenience changed.

**Breaking change**: callers who relied on the silent 100-row cap now get every row. For very large tables, switch to `fetch()` (which paginates with metadata) or pass an explicit limit.

### Trailing `;` is now stripped from user SQL in `fetch()` / `fetchOne()`

The framework appends `LIMIT n OFFSET m` to the user-supplied query (and wraps it in `SELECT COUNT(*) FROM (...) AS subq` for the count probe). When the user's query already ended with a `;`, both rewrites broke:

```php
$db->fetch("SELECT * FROM users;");
// pre-v3.13.12: syntax error near "LIMIT" - the appended LIMIT followed a ;
// v3.13.12:    works - trailing ; is stripped before LIMIT is appended
```

The strip is conservative: only trailing whitespace + semicolons are removed (any number of them, including `;;`), nothing inside the statement is touched. Parameters and quoting are unchanged - the existing parameter-binding defense against injection still does all the heavy lifting.

The shared logic lives in a new `\Tina4\Database\SqlNormalizerTrait` and is `use`d by all five adapters: PostgreSQL, MySQL, SQLite, MSSQL, Firebird.

### Implicit ORM binding from `TINA4_DATABASE_URL`

PHP already auto-discovered `TINA4_DATABASE_URL` on adapter init - this release simply documents and pins it as parity behaviour. When the env var is present, the first ORM model call binds the default adapter; an explicit `\Tina4\Database\Adapter` instance still takes precedence and can be used to bind a second database.

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

## v3.13.11 (2026-06-11) - ORM correctness pass (parity bump)

**No PHP source changes.** This release is a parity-version bump alongside Python's ORM correctness pass. Each issue in the Python report was checked against PHP and found to be either already-correct or N/A for the PHP framework.

### Per-issue audit

- **#50.1 - Callable field defaults** → **N/A**. PHP property defaults must be constant expressions in declarations (`public string $foo = 'bar';` is allowed; `public DateTime $foo = new DateTime();` is not). The Python/Ruby callable-default pattern doesn't apply.
- **#50.2 - `save()` correctly handles natural-key INSERTs** → **already correct**. `Tina4\ORM::save()` (line 363) already routes through `recordExists($pkValue)` for natural-key models. The Python bug was specifically about that decision branch; PHP's branch was already right.
- **#49 - PostgreSQL error visibility follow-on** → **N/A**. The cascade behaviour is psycopg2-specific (DB-API 2.0 implicit transactions). PHP's `pg_query` uses libpq in autocommit mode; every statement is its own transaction, so the cascade never happens.
- **BooleanField engine-aware DDL** → **N/A**. PHP's `ORM::createTable()` is a minimal stub that creates a PK-only table - full schema is migration-driven, so the user controls the bool column type explicitly in their migration SQL.

### Tests

2,888 passed - unchanged from v3.13.9.

---

## v3.13.9 (2026-06-10)

Non-destructive AI installer - `AI::installSelected()` / `AI::installAll()` no longer clobber the user's `CLAUDE.md`. They write (or refresh) a marker-bracketed Tina4 skill block and leave the rest of the file alone.

### The bug

Pre-v3.13.9 the installer wrote a full developer guide to `CLAUDE.md` (and to `.cursorules` / `.github/copilot-instructions.md` / `.windsurfrules` / `CONVENTIONS.md` / `.clinerules` / `AGENTS.md` / `.antigravity/context.md`) on every run, clobbering whatever the user had put there. If a user kept project-specific notes in `CLAUDE.md`, re-running the installer wiped all of it.

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

The actual skill content under `.claude/skills/tina4-*/SKILL.md` still gets cleanly overwritten - those are framework-owned packages, not user notes.

### Same algorithm in Python / Ruby / Node

Identical four-branch logic, identical marker syntax, identical canonical action verbs in the log output. Skill content stays consistent across the family.

### Tests

11 new tests in `tests/AIInstallerTest.php` (verified via reflection so private helpers stay private). All four branches plus marker detection, block replacement, idempotency, old-header detection, and rule-file vs markdown-file behaviour.

2,888 passed - no regressions.

### What you'll see when you re-install

```
[OK] Migrated (replaced old framework dump in) CLAUDE.md   ← first run after upgrade
[OK] Refreshed skill block in CLAUDE.md                     ← every subsequent run
[OK] Appended skill block to CLAUDE.md                      ← user-curated file
```

---

## v3.13.7 (2026-06-10)

Two changes from the 24rent app-platform team (PLATFORM-2159) - one observability hook, one production-safety fix. Both ship across **all four frameworks** with identical event payload shape.

### NEW: `tina4.request.error` event

When `Router::dispatch()` catches a `Throwable`, it now emits `tina4.request.error` **before** rendering the 500 page. Listeners receive an assoc array `['exception' => $e, 'request' => $request]` and can ship the failure to CloudWatch / Sentry / Slack - even though the framework caught it.

```php
use Tina4\Events;
use Tina4\Log;

Events::on('tina4.request.error', function ($payload) {
    /** @var \Throwable $e */
    $e = $payload['exception'];
    /** @var \Tina4\Request $request */
    $request = $payload['request'];

    Log::error(sprintf(
        'Route error: %s: %s',
        $e::class,
        $e->getMessage()
    ), [
        'method' => $request->method ?? null,
        'path'   => $request->path ?? null,
    ]);
    // ...or POST to your centralised logging pipeline
});
```

- **Fires for caught route throwables.** Does NOT fire for 404s - those aren't server errors.
- **Listener errors are swallowed + warning-logged** so a broken listener can't break the 500 render.
- **Listeners fire in priority order** (higher priority first, matching `Events::on($event, $cb, priority: N)`).
- **Identical event name + payload across Python / Ruby / Node** - only the per-language syntax differs.

The Router also now calls `Log::error` itself with the exception class, message, method, and path. Previously route exceptions were swallowed without any framework-side log; tail-the-log workflows now see them.

### FIX: Stack trace removed from production 500 body (CWE-209)

Before v3.13.7, an unhandled route exception in PHP would render `$e->getMessage() . "\n" . $e->getTraceAsString()` into the 500 response body - absolute file paths, full call chain - **regardless of `TINA4_DEBUG`**. That's [CWE-209 / OWASP A05](https://cwe.mitre.org/data/definitions/209.html): information disclosure.

<div v-pre>

The framework's own `Tina4/templates/errors/500.twig` now guards the trace block with `{% if error_message %}`. When `TINA4_DEBUG=false`, the Router passes an empty `error_message` and the trace block doesn't render. The trace stays in `Log::error` (server-side) and reaches observability via the new event.

</div>

When `TINA4_DEBUG=true`, the rich `ErrorOverlay` page is unchanged.

### Tests

Six new tests in `tests/RouterErrorEventTest.php`: event payload shape, behaviour with no listeners, listener priority order, no traceback markers in prod body, request_id still surfaces, listener-error safety.

- 2,877 tests passing, no regressions.

### Background

Reported by DevProx on the 24rent platform - they centralise observability by scraping structured JSON lines from stderr → CloudWatch → a Slack notifier. Route-level exceptions weren't surfacing because the framework caught them silently. The event hook fixes that without forcing any team's logging convention; the trace-leak fix is independently a security concern.

---

## v3.13.6 (2026-06-09)

Parity-version bump alongside Python's #46 / #47 fixes. **No PHP source changes** - both issues were verified against the PHP codebase and required no action here.

### #46 - PostgreSQL transaction cascade (no fix needed)

The cascade behaviour that prompted Python's fix is psycopg2-specific (DB-API 2.0 mandates an implicit transaction on first statement). PHP's `pg_query` / `pg_query_params` use libpq in autocommit mode by default - each statement is its own transaction, so a failed query does not poison subsequent ones.

`PostgresAdapter::query()` already populates `$this->lastError` from `pg_last_error()` on every failure, accessible via `$db->getError()`:

```php
$db = \Tina4\Database\Database::create('postgres://localhost:5432/mydb');
$db->fetch("SELECT * FROM does_not_exist");
$error = $db->getError();  // already populated - has been since 3.x
```

### #47 - Driver install hints (no change needed)

PHP's driver-missing exceptions already include OS-level install guidance (`sudo apt-get install php-pgsql`, `brew install php`). PHP database drivers are extensions, not Composer packages, so the Python/Ruby/Node-style "extras" pattern doesn't apply.

### Tests

2,871 passing - no regressions.

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

- **breaking:** `autoMap` now defaults to `true` - ORM models automatically map between camelCase properties and snake_case DB columns. Set `public bool $autoMap = false;` on your model to restore the old behaviour.
- **breaking:** `all()` now returns a flat array of model instances instead of `['data' => [...], 'total' => N, ...]`. Use `count()` separately if you need the total.
- **feat:** `toDict(include, case)` parameter - pass `case: 'snake'` to get snake_case keys matching DB columns, or `case: 'camel'` (default) for camelCase.
<div v-pre>

- **feat:** Frond `replace` filter now accepts dict args - `{{ v|replace({"T": " ", "-": "/"}) }}` for multiple substitutions in one call.
- **feat:** `$app->background(callback, interval)` - register periodic tasks that run cooperatively in the `stream_select` event loop. No threads, no separate processes.
- **feat:** Background timing guard - warns when callbacks exceed their interval, helping developers identify blocking operations.
- **feat:** WebSocket room management moved to `Server` class - `joinRoom()`, `leaveRoom()`, `broadcastToRoom()` now work reliably via `WebSocketConnection->server`.
- **feat:** Docker image now bundles the example store demo - `docker run tina4stack/tina4-php:v3` starts a working app out of the box.
- **fix:** AutoCrud updated for new `all()` return format.
- **fix:** Cart nav badge now updates reactively on quantity change and item removal.
- **fix:** Non-blocking queue consumer - `processOrders()` uses `$queue->pop()` instead of blocking `$queue->consume()`.
- **tests:** 6 new parity tests covering `toDict(case:)`, `autoMap` default, `replace` filter (dict + positional), and `background()` registration. 2,345 tests passing.
- **parity:** All features shipped identically across Python, PHP, Ruby, Node.js.

</div>

## v3.10.97 (2026-04-11)

- **fix:** frond.form.submit redirect handling - XHR follows 3xx redirects transparently; fixed by detecting `xhr.responseURL` mismatch and navigating instead.
- **dep:** Updated frond.min.js to v2.1.2.
- **parity:** All 4 frameworks bumped to 3.10.97.

## v3.10.93 (2026-04-11)

- **fix:** Frond bracket depth tracking in `findOutsideQuotes()` and `splitOutsideQuotes()` - expressions like `$arr[$i % 2]` no longer treated as top-level arithmetic.
- **fix:** Frond subscript expression evaluation - bracket content uses `evaluateExpression()` instead of `resolveVariable()`, enabling `arr[loop.index0 % 2]`.
- **fix:** Frond slice with variable bounds - `items[start:end]` evaluates bounds through `evaluateExpression()`.
- **docs:** Developer skills updated - Metrics Dashboard guidance, Frond Template Parity rules, `@noauth` security warnings.
- **parity:** All Frond fixes applied identically across Python, PHP, Ruby, Node.js. 2,339 tests passing (263 Frond).

## v3.10.92 (2026-04-10)

- **feat:** Add `RateLimiterMiddleware` class with `beforeRateLimit()`, `check()`, `reset()` static methods.
- **breaking:** Rename `ErrorOverlay` methods - `render()` → `renderErrorOverlay()`, `renderProduction()` → `renderProductionError()`.
- **feat:** Add `Server::handle(Request $request): Response` for cross-framework parity.
- **feat:** Add `DatabaseResult::size()` method.
- **breaking:** Rename `WebSocketBackplane::create()` → `WebSocketBackplane::createBackplane()`.
- **feat:** Add `DevAdmin::health()` method.
- **feat:** Add `ScssCompiler::compileScss()` method.
- **fix:** Add `DatabaseSessionHandler::delete()` delegating to `destroy()`.
- **fix:** `SmokeTest` - pass secret explicitly to `Auth::getToken()` to fix test ordering issue.
- **parity:** 44/44 cross-framework features green. 2,305 tests passing.

## v3.10.91 (2026-04-10)

- **feat:** Add parity methods - `GraphQLType::parse()`, `Response::send()` params, `MCP::registerRoutes()` optional router.
- **breaking:** Rename `from()` → `fromTable()`, `template()` → `render()` - align with Python canonical names.

## v3.10.90 (2026-04-09)

<div v-pre>

- **docs:** Chapter 4 (Templates) - new "Dumping Values for Debugging" section covering both `{{ $x|dump }}` and `{{ dump($x) }}` forms, their shared `<pre>var_dump()</pre>` output, and the `TINA4_DEBUG=true` production gate. Filter table entry updated to reference the new section.
- **docs:** `plan/parity/parity-template.md` updated with a cross-framework dump helper comparison table and marks dump parity as confirmed across all 4 frameworks at v3.10.89.
- **chore:** Version sync release - brings all 4 frameworks to the same patch version (3.10.90) so downstream users can upgrade PHP/Python/Ruby/Node.js in lockstep without hunting version mismatches.

</div>

## v3.10.89 (2026-04-09)

<div v-pre>

- **feat:** `{{ dump(value) }}` global function form added to Frond alongside the existing `{{ value|dump }}` filter. Both call a single `Frond::renderDump()` helper and produce identical output (`<pre>var_dump()</pre>`).
- **security:** Dump is now **gated on `TINA4_DEBUG=true`**. In production (env var unset or `false`) both the filter and function silently return an empty string. This prevents accidental leaks of internal state, object shapes, and sensitive values into rendered HTML when a developer leaves a `{{ dump($x) }}` call in a template.
- **test:** 4 new tests in `FrondTest.php` covering debug-mode output, production silencing, function/filter parity, and function-form production silencing.

</div>

## v3.10.87 (2026-04-09)

- **fix:** Dev toolbar no longer vanishes after a hot-reload. `Server::onFilesChanged()` used to call `Router::clear()` and then loop `include_once` over every `.php` file in `src/routes/`. Because `include_once` is a no-op for already-included files, routes were never re-registered after a template/CSS/JS edit - subsequent requests fell through to the 404 handler and the dev toolbar injection was lost. The router is now left intact on template/asset edits (Frond re-reads templates in dev mode, static files are served from disk per request, so nothing else needs to move). PHP file edits log a warning that a full server restart is required (classes cannot be redeclared in-process).
- **fix:** This also resolves a related issue where rapid browser refreshes during hot reload would return 500s - the router wipe left a brief window with zero routes registered.

## v3.10.86 (2026-04-09)

- **feat:** `$foreignKeys` property on `ORM` auto-wires both sides of a foreign key relationship. Declaring `public array $foreignKeys = ['user_id' => 'User']` injects a `belongsTo` accessor (`$post->user`) on the declaring model and a `hasMany` accessor (`$user->posts`) on the referenced model via a cross-model FK registry. Extended form supports a custom has-many key: `['user_id' => ['model' => 'User', 'related_name' => 'blog_posts']]`.
- **feat:** Cross-framework parity - same FK auto-wiring semantics now available in Python (`ForeignKeyField`), Ruby (`foreign_key_field`), and Node.js (`type: "foreignKey"`)
- **docs:** Chapter 6 (ORM) updated with a new "$foreignKeys - Auto-Wired Relationships" section

## v3.10.85 (2026-04-09)

- **fix:** Removed duplicate `Job` class from `Queue.php` - canonical definition is `Job.php` only
- **fix:** `Job.php::fail()` now delegates to `writeFailed()` instead of calling private `getBasePath()` directly

## v3.10.84 (2026-04-09)

- **fix:** Router/middleware was setting `request.user` / `request.auth` / auth payload to `true` (boolean) instead of the actual JWT payload after `validToken()` was changed to return bool - any code reading `request.user["sub"]` etc. would have failed silently or crashed
- **fix:** CSRF middleware was not correctly rejecting invalid tokens (nil check on bool result always passed)
- **fix:** `toObject()` declared wrong return type (`array` vs actual `object`)
- **fix:** Router `request.user` and gallery auth verify endpoint updated for bool `validToken`
- **add:** Headless routing auth payload integration tests to prevent regression

## v3.10.83 (2026-04-08)

- **fix:** CORS headers now set before auth short-circuit (#106)
- **fix:** ORM find/all/where no longer crash with DatabaseResult object (#108)
- **fix:** toObject() returns stdClass, not array (#107)
- **fix:** Firebird absolute path no longer strips leading slash (#101)
- **feat:** WebSocket rooms - joinRoom, leaveRoom, broadcastToRoom, getRoomConnections, roomCount
- **feat:** queue signature parity - instance-scoped, no topic params on public methods
- **feat:** auth alias cleanup - removed createToken/validateToken aliases

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js


## Version History

Tina4 PHP follows semantic versioning. The major number changes when something breaks. The minor number changes when something new arrives. The patch number changes when something gets fixed. Each release is available on Packagist.

This chapter covers the full v3 line -- from the first release candidate through the current stable release. If you are upgrading from v2, read Chapter 36 first. It covers every breaking change and gives you a migration checklist.

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
- **load() returns bool** - `$model->load($sql, $params)` calls selectOne internally, populates the instance, returns `true`/`false`. Use `findById()` for PK lookups
- **api.upload()** added to tina4-js - sends FormData with Bearer token auth for multipart file uploads
- **ORM CLAUDE.md rewrite** - all method stubs now match actual API signatures
- **File upload docs** - `$request->files` format documented in CLAUDE.md

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
- **tina4 console** - interactive PHP REPL with framework loaded ($db, $app, Router, Auth)
- **tina4 env** - interactive environment configuration
- **Brand update** - "TINA4 - The Intelligent Native Application 4ramework"
- **Dynamic version** - reads from composer metadata at runtime, no hardcoded constant
- **Packagist v2 API** - version checker uses repo.packagist.org
- **@noauth docblock** - annotations now affect dispatch (#114)
- **Port kill-and-take-over** - default port always reclaimed
- **MongoDB adapter** (ext-mongodb), **ODBC adapter** (pdo_odbc)
- **Pagination standardized** - limit/offset primary, merged dual-key response
- **#101** Firebird paths, **#102** autoMap uppercase, **#104** TINA4_DATABASE_URL, **#105** CORS fix

---

## v3.10.57 (2026-04-02)
- **MongoDB adapter** - `Database("mongodb://host:port/db")`, requires ext-mongodb
- **ODBC adapter** - `Database("odbc:///DSN=MyDSN")` via pdo_odbc
- **Pagination standardized** - limit/offset primary, merged dual-key toPaginate() response
- **Test port at +1000** - user testing port (e.g. 8146) stable, no hot-reload
- **Dynamic version** - read from composer metadata, no hardcoded constant
- **Packagist v2 API** - version checker uses repo.packagist.org/p2/
- **#101** FirebirdAdapter path parsing preserves absolute paths
- **#102** ORM snakeToCamel handles uppercase columns
- **#104** ORM ensureDb() auto-discovers TINA4_DATABASE_URL
- **#105** CorsMiddleware matches request origin correctly
- **#114** @noauth docblock annotations now affect dispatch
- **108 features at 100% parity**, 2,220 tests

---

## v3.10.54 (2026-04-02)
- **Auto AI dev port** - second socket on port+1 with no-reload when TINA4_DEBUG=true
- **TINA4_NO_RELOAD** env var + --no-reload CLI flag
- **#101** FirebirdAdapter path parsing preserves absolute paths
- **#102** ORM snakeToCamel handles uppercase columns (Firebird/Oracle)
- **#104** ORM ensureDb() auto-discovers TINA4_DATABASE_URL
- **#105** CorsMiddleware matches request origin correctly
- **SQLite commit()** no-op without transaction
- **Gallery fixes** - SQLite paths, auth bypass
- **QueryBuilder docs** - added to ORM chapter

---

## v3.10.48 - April 2, 2026

### Bug Fixes

**FrankenPHP requires `--production` flag** - FrankenPHP no longer auto-detected when debug is off. Use `tina4php serve --production` to enable it. Gallery tests (19) and live reload tests (36) added. Fixed `DotEnv::load()` → `DotEnv::loadEnv()` in Server.php.

---

## v3.10.46 - April 1, 2026

### Test Coverage

Massive test expansion - 605 new tests added across session handlers, queue backends, database drivers, Frond template engine, dev admin, ORM, auth, seeder, log, service runner, container, CORS, form token, HTML element, migration, i18n, events, SCSS, CRUD, rate limiter, and CSRF middleware. PHP now at 1,937 tests with full parity across all 49 core areas.

### Bug Fixes

**CSRF query param check** - Fixed `$request->params` shadowing `$request->query` in the CSRF middleware, so query string token detection now works correctly.

---

## v3.10.45 - April 1, 2026

### Bug Fixes

**CLI serve hijack** - When `index.php` calls `App::run()`, the CLI `serve` command now sets a `TINA4_CLI_SERVE` constant so `run()` returns early, letting the CLI manage the server lifecycle (port, debug mode, browser open).

---

## v3.10.44 - April 1, 2026

### New Features

**Database tab redesign** - The dev admin Database panel now uses a split-screen layout. Tables are listed on the left as a navigation sidebar with click-to-select highlighting. The query editor, toolbar, and results occupy the right panel.

**Copy CSV / Copy JSON** - Two new buttons in the database toolbar copy query results to the clipboard in CSV or JSON format.

**Paste data** - A Paste button opens a modal for pasting JSON arrays or CSV/tab-separated data. Auto-detects the format and generates INSERT statements. Prompts for a table name if none is selected, and generates CREATE TABLE for new tables. SQL input passes through unchanged.

**Multi-statement execution** - The query runner handles multiple SQL statements separated by semicolons, running them in a single transaction with automatic rollback on error.

**Database badge on load** - The Database tab count badge shows the table count immediately on page load.

**Star wiggle animation** - The GitHub star button on the landing page uses an empty star (☆) with a wiggle animation: 3-second delay, then wiggles at random 3-18 second intervals.

### Bug Fixes

**Default port** - PHP default port confirmed as 7145 (PHP=7145, Python=7146, Ruby=7147, Node=7148).

**SQLite LIMIT fix** - Prevents double-LIMIT errors when browsing tables in the dev admin.

**browseTable quote escaping** - Fixed broken onclick handlers for table names using addEventListener.

<div v-pre>

**Frond template engine** - Fixed string concatenation (`~` operator) and inline if/else expressions (`{{ 'yes' if active else 'no' }}`). A greedy quoted-string fallback in `evaluateLiteral()` was treating compound expressions as single string literals.

</div>

### Test Coverage

Major test expansion - 200 new tests added (FakeData 42, Cache 30, DevMailbox 33, Static files 31, Metrics 20, CLI scaffolding 31, plus v3.10.44 feature tests). 1,532 tests passing, 0 failures.

---

## v3.10.40 - April 1, 2026

### Bug Fixes

**Dev overlay version check** - Fixed misleading "You are up to date" message when running a version ahead of what's published on Packagist. The overlay now shows a purple "ahead of Packagist" message. Also added a breaking changes warning (red banner with changelog link) when a major or minor version update is available.

---

## v3.10.39 - April 1, 2026

### Breaking Changes

**`Auth::hashPassword()` - separator changed from `:` to `$`**

The password hash format now uses `$` as a separator (matching Python, Ruby, and Node.js):

```
# BEFORE: pbkdf2_sha256:100000:salt:hash

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

# AFTER:  pbkdf2_sha256$100000$salt$hash

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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
// BEFORE (v3.10.38 and earlier) - associative array filter
$db->update('users', ['name' => 'Alice'], ['id' => 1]);
$db->delete('users', ['id' => 1]);

// AFTER (v3.10.39+) - SQL string + params (matches Python, Ruby, Node.js)
$db->update('users', ['name' => 'Alice'], 'id = ?', [1]);
$db->delete('users', 'id = ?', [1]);
```

**`Router::list()` removed - use `Router::getRoutes()` or `Router::listRoutes()`**

```php
// BEFORE
$routes = Router::list();

// AFTER
$routes = Router::getRoutes();   // or Router::listRoutes()
```

### New Features

**`ORM::findById(int|string $id)`** - explicit primary method (with `find()` and `load()` as aliases).

**`Session`: `TINA4_SESSION_HANDLER` env var** - replaces `TINA4_SESSION_BACKEND` (old name still accepted for backward compatibility).

**`Session\RedisSessionHandler`** - new zero-dependency Redis session handler using raw RESP protocol over TCP sockets. Configure with `TINA4_SESSION_REDIS_HOST`, `TINA4_SESSION_REDIS_PORT`, `TINA4_SESSION_REDIS_PASSWORD`, `TINA4_SESSION_REDIS_DB`.

**`Database::cacheStats()` and `Database::cacheClear()`** - query cache wired to `TINA4_DB_CACHE=true` env var.

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

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

tina4 ai

# Install for all known AI tools

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

tina4 ai --all

# Overwrite existing context files

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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
$results = QueryBuilder::fromTable("orders")
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

The authentication API consolidated. `getToken` and `validToken` are the only token methods - there are no `createToken`/`validateToken` aliases.

```php
$token = \Tina4\Auth::getToken(["userId" => 42, "role" => "admin"]);
$valid = \Tina4\Auth::validToken($token);
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

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
- **New:** Chapter 24 added to documentation: Server-Sent Events
- Feature count: 45 (was 44)
- Full parity across Python, PHP, Ruby, Node.js

composer require tina4stack/tina4php

# v3

## v3.10.70 (2026-04-06)

- **New:** SSE (Server-Sent Events) support via `response.stream()` - pass a generator, framework handles chunked transfer encoding, keep-alive, and `text/event-stream` content type
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
