{
  "summary": "Find every test double across all four frameworks, triage it, and convert the ones standing in for real dependencies",
  "agentCount": 10,
  "logs": [
    "inventory: 179 doubles found across 4 frameworks, 154 judged VIOLATION",
    "[convert:ruby] failed: You've hit your session limit · resets 12pm (Africa/Johannesburg)",
    "[convert:python] failed: You've hit your session limit · resets 12pm (Africa/Johannesburg)",
    "[convert:php] failed: You've hit your session limit · resets 12pm (Africa/Johannesburg)",
    "[convert:nodejs] failed: You've hit your session limit · resets 12pm (Africa/Johannesburg)",
    "conversion complete across 0 frameworks",
    "[THE RULE, as stated verbatim in every repo's CLAUDE.md:] failed: You've hit your session limit · resets 12pm (Africa/Johannesburg)"
  ],
  "result": {
    "verification": null,
    "conversions": [],
    "parity": "# TINA4 MOCK-RULE CROSS-FRAMEWORK SYNTHESIS\n\nSource: the four supplied inventories (tina4-python v3 @ fb6fcb2, tina4-php v3 @ e5e00b28, tina4-ruby v3 @ 1784943, tina4-nodejs v3 @ a6bda71 - all four sitting on the same \"Confine response.file() to a root in all four\" commit). **I did not re-run any scan or any suite.** Everything below is derived from the four inventories as filed; where they disagree or fall silent I say so rather than filling the gap.\n\nFiled violation sites: **154 total - PY 50, PHP 10, RB 44, JS 50.** PHP's low count is real, not a measurement artifact (its scanner re-ran every count under `/usr/bin/grep` after catching the ugrep `--include` drop, control 4266). PHP genuinely uses `TestServer.php`, `Request::create`, `stream_socket_pair` and real log files across most of its suite. **PHP is the reference repo for two subsystems (transport, logger) and should be read before converting the other three.**\n\n---\n\n## 1. THE PARITY MATRIX\n\nLegend:\n`D(n)` = n filed violation sites. `CLEAN` = scanner explicitly confirmed real-dependency tests (an EXEMPT entry). `MIXED` = both a violation and a correct file in the same repo. `NONE FOUND` = no double AND no real test surfaced - **a candidate untested path, see section 2.**\n\n| Subsystem | PY | PHP | RB | JS |\n|---|---|---|---|---|\n| **Session backends (redis/valkey/memcached/mongo/db/file)** | D(9) + CLEAN integ classes | D(2), happy path CLEAN | D(3) | D(5) |\n| **Queue backends (kafka/rabbit/mongo)** | D(1) dead-letter, rest CLEAN | NONE FOUND | NONE FOUND | D(1) log only, broker CLEAN |\n| **Cache backends (response cache)** | D(1), memory only | NONE FOUND | NONE FOUND | D(1), memory only |\n| **Database - commit failure / txn state** | NONE FOUND | D(1) | D(3) | D(1) |\n| **Database - migration footguns / tableExists** | D(1) | D(2) | D(1) | D(1) |\n| **Database - per-engine DDL type mapping** | D(1) | NONE FOUND | D(1) | NONE FOUND |\n| **Database - Firebird reconnect** | D(4) | NONE FOUND | D(1) | NONE FOUND |\n| **Database - Postgres idle-in-txn + % interp** | D(3) | NONE FOUND | NONE FOUND | NONE FOUND |\n| **Database - driver-not-installed import** | D(2) | NONE FOUND | NONE FOUND | NONE FOUND |\n| **Database - write path contract** | CLEAN (exemplary) | CLEAN | partial | CLEAN |\n| **Messenger / SMTP / IMAP** | CLEAN (reference impl) | NONE FOUND | NONE FOUND | NONE FOUND |\n| **Logger** | D(1) | **CLEAN (reads real log files)** | D(11) | D(16) |\n| **HTTP client (outbound Api)** | CLEAN | MIXED: D(1) + CLEAN | NONE FOUND | CLEAN |\n| **WebSocket connection + backplane** | D(11) | MIXED: D(1) + CLEAN | D(15) | D(4) |\n| **HTTP request/response transport** | D(12) | D(1) | D(6) | D(24) |\n| **Auth gate** | D(3) | D(1) | D(3) | D(6) inc. 3 code copies |\n| **Dev-admin / MCP / Swagger gate** | D(4) | NONE FOUND | D(5, all ENV) | D(2) |\n| **SOAP / WSDL (inc. XXE, billion laughs)** | D(1, ~20 sites) | NONE FOUND | D(1) | NONE FOUND |\n| **SSE / streaming disconnect** | D(2) | NONE FOUND | NONE FOUND | D(1) |\n| **Static files / path traversal** | NONE FOUND | NONE FOUND | NONE FOUND | MIXED: D(1) + CLEAN |\n| **CLI / process lifecycle** | NONE FOUND | NONE FOUND | CLEAN (real stdout) | D(6) |\n| **Middleware pipeline (in-test mw classes)** | EXEMPT | EXEMPT | EXEMPT | EXEMPT |\n\n**Four-for-four doubled clusters** (ported doubles, fix all four together):\n1. **Session backend failure policy.** `_ExplodingHandler` (PY) / `ThrowingSessionHandler` (PHP) / `RaisingHandler` (RB) / `ExplodingHandler` (JS), each paired with an `Empty*Handler` positive control. Same file, same two classes, four languages.\n2. **Migration footguns `should_skip_create_table`.** `_FakeDB` / `FakeMSSQLAdapter`+`FakeFirebirdAdapter` / `FakeDB` / four impersonating adapter classes.\n3. **WebSocket backplane.** `FakeBackplane` in PY, RB, JS; `TestableWebSocket` + `php://memory` in PHP.\n4. **Request/Response transport shells.** All four, worst in Node.\n\n---\n\n## 2. THE MISSING TWINS\n\nThe sharper question. **Caveat that governs this whole section:** the four scanners enumerated *doubles*, not *coverage*. Absence of a double is not evidence of a test. Each item below therefore states what I can and cannot conclude, plus the probe that settles it. Do not treat any \"NONE FOUND\" as good news until the probe is run.\n\n### 2a. Confirmed worse-than-mocked: nothing tests it anywhere\n\n**Commit-failure / transaction-pin behaviour in Python.** PHP, Ruby and Node all fabricate a commit failure (`FlakyCommitAdapter`, `define_singleton_method(:commit)`, `target.commit = () => { throw }`). Python has **no commit-failure test at all** - its `test_write_path_contract.py` is exemplary but covers the success path. So the one framework the project treats as master on internal API design has zero coverage of the failure branch that the other three at least approximate. Probe: `rg -n \"commit\" tina4-python/tests/ | rg -i \"fail|error|raise\"`.\n\n**Firebird transparent reconnect in PHP and Node.** Python has four doubles for it, Ruby one. PHP and Node surface nothing. This is a shipped, user-visible behaviour (NAT/idle-timeout socket death) with three of four frameworks either faking it or not testing it, and the fourth pair not testing it at all. Given the project history - native Firebird CI found 3 bugs the non-native tests missed - this is the highest-value missing twin in the DB group.\n\n**Postgres idle-in-transaction and `%`-in-PL/pgSQL (issue #40) in PHP, Ruby, Node.** Python has doubles for both (and one of them, `test_postgres_idle_in_transaction.py:45`, stubs psycopg2 out of `sys.modules` entirely, so the file cannot observe the bug it regresses). The other three have neither test nor double. Issue #40 was a real reported bug; if the same `%` interpolation path exists in the PHP/Ruby/Node Postgres adapters, it is unregressed in three frameworks.\n\n**Messenger / SMTP / IMAP in PHP, Ruby, Node.** Python's `tests/test_messenger.py` is the single best test in the estate - real GreenMail send over real SMTP 3025, real read-back over real IMAP 3143, failure driven by a real refusal at 127.0.0.1:59999. Its scanner named it the reference implementation. The other three scanners each named their own exemplary files and **none of them was an SMTP test.** Either those frameworks do not ship a messenger, or the send path is untested in three of four. Probe: `rg -ril \"smtp|imap|mail\" tina4-php/tests tina4-ruby/spec tina4-nodejs/test`.\n\n**Outbound HTTP client in Ruby.** PHP has `ApiTest.php` (doubled) plus `ApiTransferTest.php` (real, two live servers); Python `test_api.py` and Node `apiTransfer.test.ts` are both real. Ruby surfaces nothing. If tina4-ruby ships an `Api` client, its retry, backoff and connection-error behaviour is untested. Probe: `rg -ril \"Tina4::Api|def get\\(|retries\" tina4-ruby/spec`.\n\n**Retry / backoff / real-503 semantics anywhere.** Even in the three \"CLEAN\" HTTP client repos, none of the inventories claims a real retry-after-503 or a measured backoff interval. PHP's real file (`ApiTransferTest`) covers transport injection and cross-origin redirect, not retries; PHP's *retry* coverage is exactly the doubled `ScriptedApi`. So retry-with-real-backoff is plausibly untested in all four.\n\n**Dead-letter routing in PHP and Ruby.** Python intercepts `backend.enqueue` (one residual double in an otherwise real-broker file); Node's queue backends are real. PHP and Ruby surface no queue tests at all. This is the exact feature class that shipped broken in Node for two releases. Kafka is up on 9092 and Mongo on 27017 - there is no infrastructure excuse.\n\n**Cache backends in PHP and Ruby.** Python and Node each double the request/response around the response cache and run memory-only; PHP and Ruby show no cache tests. So across four frameworks, **no test anywhere has ever run the response cache against redis, valkey, memcached or mongo**, and two frameworks appear to have no cache test at all.\n\n**SOAP XXE / billion-laughs in PHP and Node.** Python and Ruby both test it, both against hand-built request objects (Python passes hostile XML as a `str`, Ruby as a Struct field). PHP and Node surface nothing. If they ship WSDL/SOAP, the entity-expansion and external-entity defences are unregressed there.\n\n**SSE client-disconnect in PHP and Ruby.** Python and Node both fake it (a `CancelledError` at a chosen moment; a `fakeSocket.destroyed` boolean). PHP and Ruby have nothing. Generator cleanup on a real hangup is therefore proven nowhere.\n\n**Static path traversal in Python, PHP, Ruby.** Node has both a doubled traversal test (`static.test.ts`) and real ones (`responseFileTraversal.test.ts`, `staticCache.test.ts`). All four repos just landed \"Confine response.file() to a root in all four\" - so a security fix shipped in four frameworks and only one of them surfaced a traversal test in this audit. **Verify the other three have a real one before anything else in this list.**\n\n### 2b. Confirmed better: one framework already does it right - copy, do not reinvent\n\n| Path | Do it like | Fix in |\n|---|---|---|\n| Logger assertions | **PHP** - `SessionBackendFailurePolicyTest` writes to a real log dir and greps the real `tina4.log` / `error.log` | RB (11 sites), JS (16 sites), PY (1 site) |\n| Unreachable backend | **PHP** `SessionMemcachedTest.php:155` - real handler at real closed port 59999; **JS** `sessionHandlerErrors.ts:57` `closedPort()` + `:70` `startSilentServer()` | PY, RB, and JS's own `sessionBackendFailure.test.ts` |\n| Real WebSocket sockets | **PHP** `WebSocketHardeningTest.php` - `stream_socket_pair`, real `registerWebSocketClient`, real closed-port backplane | PY, RB, JS - and PHP's own `WebSocketV3Test.php` |\n| Real request objects | **PHP** `Request::create(...)`; **RB** `crud_spec.rb:35` rack-env builder | PY (12), RB (6), JS (24) |\n| Real HTTP client + refusal | **PY** `test_messenger.py`; **JS/PHP** `apiTransfer` real transport | PHP `ApiTest.php:28` |\n| Real broker | **PY** `test_queue_backends.py` header (MagicMock pika/confluent/pymongo deleted) | PHP, RB (no tests) |\n| Real second connection | **PY** `test_write_path_contract.py:90` `ContractConnection` | all commit-failure work |\n| Env var handling | **PY/PHP/JS** set the real var | **RB only** - 38+ `allow(ENV).to receive(:[])` sites |\n| Real ORM into Response | **RB** `response_autoserialize_spec.rb:17` (real `Tina4::ORM` subclass) | PY, PHP, JS all use duck types |\n\n### 2c. Anti-patterns unique to one framework\n\n- **Node only: three in-test COPIES of the production auth gate** (`checkAuth.test.ts:51`, `secureByDefault.test.ts:42`, `routerAuthPayload.test.ts:49`). Not doubles - re-typed production code, and the test asserts the copy. Two of them cite *different* line ranges for the same `server.ts` block (687-700 vs 788-800), which is direct evidence the copies have already drifted from the original and from each other. Every one of these can pass with `server.ts` having no auth gate at all.\n- **Ruby only: `allow(ENV).to receive(:[])`.** Intercepts one read method; `ENV.fetch`, `ENV.key?` and any memoised value escape it. Applied to the `TINA4_MCP_REMOTE` / `TINA4_MCP_TOKEN` gate, which fronts DB-query and file-write tools.\n- **Node only: `process.exit` reassigned to a throw** (`cliBuild.test.ts:55`). This specifically hides the truncated-stderr trap already recorded in project memory (`reference_node_execfilesync_child_traps`).\n- **Python only: whole-module substitution** (`monkeypatch.setitem(sys.modules, \"psycopg2\", ModuleType(...))`, `patch.dict({\"psycopg2\": None})`). Cannot reproduce the documented wheel-installs-but-cannot-import case.\n\n### 2d. Two findings that are not test findings\n\n1. **`TINA4_MAX_UPLOAD_SIZE` does not work in tina4-python.** Measured, not inferred: `tina4_python/core/request.py:10` binds the constant at import time, so `test_file_upload.py`'s sibling `monkeypatch.setenv` test is a proven no-op and false-green. Read the limit at use time. **Sweep all four for import-time binding of documented env vars** - this shape is invisible to any test that runs in-process.\n2. **The MagicMock session-handler fix believed shipped is not on v3.** `tina4-python/tests/test_session_handlers.py` on v3 @ fb6fcb2 still carries all five MagicMock clients; the fix exists only on `feature/audit-auth`. A fix reported as landed is absent from the release branch.\n\n---\n\n## 3. THE UNTESTED-PATH RISK\n\nWhat has therefore never been exercised against anything real. The Python Redis/Valkey session path was one instance; these are the rest.\n\n**Session backends - never exercised for real in ANY of the four:**\n- The driver's real failure exception. All four assert on a hand-thrown `RuntimeError`/`ConnectionError`. Real is `redis.exceptions.ConnectionError`, `Mongo::Error::NoServerAvailable` after a timeout, `Errno::ECONNREFUSED`, `PDOException`, a half-open socket, or a hang. If any framework's `except` clause is narrower than its test assumes, every one of these files stays green while production 500s on every request - the cascade outage the files exist to prevent.\n- **The positive control.** \"A healthy backend with an empty read logs ZERO errors\" is faked in all four (`_EmptyHandler`, `EmptyHealthySessionHandler`, `EmptyHealthyHandler`, `EmptyHandler`). So the specific regression where a real `$-1\\r\\n` null bulk reply is misclassified as a transport error is undetectable in all four simultaneously.\n- Mid-request backend death (connected, then killed) - simulated everywhere, produced nowhere.\n- Real server-side TTL expiry. Python fabricates `last_accessed`; nobody sleeps past a real TTL on a real key.\n- **Session -> backend persistence in Python and Node.** `test_session_handlers.py:516/538` assert `session.get(...)` immediately after `set` - that reads the in-process dict. The assertion passes with a handler that discards every write. Node's `checkAuth.test.ts:230` `mockSession` has the same shape. Cross-instance read-back is the only proof, and it is absent.\n- Real `gc()` over genuinely aged documents.\n\n**Queue:** dead-letter topic naming and the produce itself (PY intercepts `enqueue`; nothing has ever consumed back from `orders.dead_letter`). PHP and Ruby: the entire queue lifecycle - pop, ack, no-redelivery - which is precisely the Node Mongo bug.\n\n**Cache:** the response cache has never run against redis 6379, valkey 6380, memcached 11211 or mongo 27017 in any framework. Real `X-Cache` / `Cache-Control` emission on a real response: never (both PY and JS assert against invented response semantics - PY's `MockResponse.__call__` returns a *new* MockResponse, which the real Response does not do).\n\n**Database:**\n- **No framework has ever observed a real COMMIT failure.** Three fabricate it, one has no test. Connection state after a failed commit - the pin, the error, whether a follow-up rollback cleans a genuinely half-committed connection - is unproven everywhere.\n- `pg_stat_activity` state after a write: never observed. Python's test deletes psycopg2 from `sys.modules`, so the only witness that matters is structurally unreachable.\n- `%` interpolation in a PL/pgSQL body: only real psycopg2 does the interpolation that raises; the test uses a FakeCursor and therefore **cannot raise regardless of whether the fix is present.**\n- Per-engine DDL: **no MSSQL or Firebird server has ever accepted a Tina4-generated CREATE TABLE in any test in any framework.** All four assert substrings in generated text. A column type no engine accepts passes.\n- `tableExists()` on MSSQL and Firebird: faked in all four with a hard-coded boolean. Firebird's identifier folding (unquoted -> UPPERCASE, quoted `\"Orders\"` stays mixed) is the documented failure mode and is defined away in every framework.\n- Firebird reconnect: `_reconnect` / `open_connection` is stubbed in PY and RB, absent in PHP and JS. **No test anywhere has re-opened a real Firebird socket after a real death.** The dead-connection matcher strings are hand-typed; a reworded driver message silently disables recovery.\n- Driver absence: only PY tests it, and `sys.modules` poisoning cannot surface the wheel-installs-but-fails-to-load case.\n\n**Logger (RB, JS):** every \"must be LOGGED, never silent\" assertion in Ruby's `security_hardening_spec`, `middleware_events_spec`, `orm_contracts_spec` and Node's `sessionBackendFailure`, `ormContracts`, `logger.test.ts` is a message-count on a replaced method. Never exercised: level gating, `TINA4_LOG_OUTPUT` routing, JSON structuring, the file sink, and **whether the record reaches stdout at all**. Node's `logger.test.ts:147` asserts \"Production writes to stdout (docker logs / k8s)\" by `JSON.parse`-ing a string handed to a reassigned `console.log` - if `Log.info` stopped writing to real stdout, `docker logs` goes empty and that test still passes. Real disk-full / EACCES on the log file: Ruby fabricates an `IOError`, nobody produces `ENOSPC` or `EACCES`.\n\n**HTTP client:** PHP has never made a real retry, never waited a real backoff, never hit a real refusal in `ApiTest`. Ruby appears to have no outbound client test.\n\n**WebSocket / backplane - the largest single hole:**\n- **Cross-instance relay over a real bus has never happened in any of the four.** Every framework fans out synchronously in-process. Serialization on the wire, channel naming, ordering under concurrency, the subscriber thread, reconnect, and delivery to a genuinely separate process are all defined away, simultaneously, in four implementations.\n- Real broken-pipe pruning. PHP's hardening file is closest (real socket pairs); everywhere else the \"dead client\" is a boolean flag or a hand-raised `IOError`/`ConnectionError`, which is not what a real RST or half-open socket does.\n- Real RFC 6455 frame bytes read by a real peer: only PHP's hardening file and a few Ruby specs. Ruby's `websocket_spec.rb` `#broadcast` block - including the correctness-critical `exclude:` filter - asserts only that `send_text` was *called* on verified doubles. A broadcast that calls `send_text` and discards the bytes passes all four examples.\n- Backpressure / short writes: `StringIO` (RB), `php://memory` (PHP), an array (PY/JS). None can short-write.\n\n**Auth:**\n- **Node's real auth gate has never been executed by any of its three auth-gate test files.** They test copies.\n- JWT expiry against a real clock: Python substitutes a fake `time` module *into the auth module* inside a security test.\n- Session-token auth against a real session store: nowhere in four.\n- Ruby's timing-safe comparison is asserted by message expectations on `Tina4::Auth` and `OpenSSL` - which pins the implementation and would still pass if a non-constant-time fast path were added alongside.\n\n**MCP remote gate (PY, RB):** has never seen a genuinely non-loopback peer. Python hand-sets `remote_ip = '8.8.8.8'`; Ruby stubs `ENV#[]`. The documented design point is that the gate must read the **raw socket peer and never X-Forwarded-For** - a hand-set attribute cannot distinguish the two, so **the regression the gate exists to prevent is undetectable by construction**, in the only two frameworks that test it.\n\n**SOAP:** XXE and billion-laughs payloads are parsed as a Python `str` / a Ruby Struct field, never as real bytes arriving over a socket with a real Content-Length - which is how the attack actually presents.\n\n**Upload limit:** `TINA4_MAX_UPLOAD_SIZE` has never been proven readable from the environment in Python, and is measurably not readable.\n\n---\n\n## 4. CONVERSION ORDER\n\n### Tier 0 - PREREQUISITE (easy, but must land first)\n\nOrdering purely by difficulty produces a wrong plan, so this comes out of sequence deliberately.\n\n**0a. Logger doubles -> real sinks. RB (11), JS (16), PY (1).** Copy PHP: real log dir, run the scenario, read the real file. For stdout claims, spawn a child process and assert on its real captured stdout - that is literally the `docker logs` path.\n*Why first, despite being trivial:* the session, ORM, middleware and MCP conversions in every later tier assert \"and it was LOGGED\". If you convert the handler to a real closed port while `Log.error` is still a message expectation, you have converted half a test and the load-bearing half is still fake. **This is a prerequisite, not a follow-up.**\n\n**0b. Ruby `allow(ENV).to receive(:[])` -> real env vars.** 38+ sites across `dev_admin_spec`, `mcp_dev_endpoint_spec`, `router_reload_spec`, `dev_reload_ws_spec`. `env_vars_spec.rb:28-36` already ships the correct `with_env` helper. Zero infrastructure, mechanical, and it un-blocks the MCP gate work in Tier 4. Ruby-only.\n\n**0c. Wire `TINA4_REQUIRE_SERVICES` before converting anything else.** Every conversion below turns a green fake into either a real pass or a loud skip. Without the no-green-skips gate, converting a double to a skip is a silent regression that *looks* like progress. PHP already has the gate (`RequireServicesGateTest`); confirm it in the other three first.\n\n### Tier 1 - HARDEST: engine-level failure injection\n\n**Real COMMIT failure** (PHP `DbContractAbcTest:374`, RB `db_contract_abc_spec:163`, JS `dbContractAbc.test.ts:180`) **and write the Python one that does not exist.**\n*Why hardest:* you cannot fake it and you cannot ask the engine nicely. You need a rig that makes a real engine fail at COMMIT specifically. Three candidate rigs, in ascending confidence: Postgres `DEFERRABLE INITIALLY DEFERRED` unique constraint (standard-derived, **not measured by the PHP scanner - verify it surfaces as a `DatabaseException` through the adapter before committing to it**); Postgres `pg_terminate_backend` from a second real session (highest confidence, kills the socket for real); SQLite file DB with a competing `BEGIN IMMEDIATE` and a 50ms `busy_timeout` (portable, needs no server, safest fallback).\n*Do it first because* it is the long pole, the rig is reusable for Tier 4's \"backend dies mid-flight\" cases, and Python's total absence of coverage here means one of the four conversions is actually a new test.\n\n**Migration footguns on real MSSQL and Firebird** (all four). MSSQL 1433 and Firebird 3050 are **not provisioned on the audit host** (PHP's and Ruby's scanners confirmed absent; Python's saw a TCP accept on 3050 but never authenticated - a listening port is not a working service). The honest end state on this host is a loud skip naming host and port, with real CI coverage elsewhere. Concrete: create the real table (including the quoted `\"Orders\"` case on real Firebird), call the real `tableExists()`, drop it, call again. **The Firebird identifier-folding case is the one most likely to fail on conversion, which is exactly why it goes early.**\n\n**Firebird transparent reconnect** (PY 4 sites, RB 1 site; **write it for PHP and Node, which have none**). The rig: a real TCP forwarder you control between the adapter and 3050, torn down mid-session so the socket genuinely dies, then restarted. Prove recovery by *observable outcome* - the retried SELECT returns correct rows on a connection whose original attachment id provably changed - not by a call count on a stubbed `_reconnect`. Seed the dead-connection message matcher from strings captured during this live run so it cannot drift from the driver.\n\n**Postgres idle-in-transaction and `%`-in-PL/pgSQL** (PY 3 sites; probe whether PHP/RB/JS need new tests). Postgres is up on 55432. The witness is `pg_stat_activity` queried from a *second* connection - there is no in-process substitute, which is why the current Python test deleted the driver rather than face it.\n\n### Tier 2 - Cross-instance WebSocket backplane (all four)\n\nTwo real processes, one real Redis, real client sockets on both, assert the frame crosses. Plus an independent real SUBSCRIBE to read the actual published envelope off the bus (replaces RB's `CapturingBackplane`). Plus real socket death (`SO_LINGER 0` + close, or `resetAndDestroy`) for the prune tests, and a real closed port via bind-then-release for the degrade tests. NATS 4222 is **down** - that variant must skip loudly naming 127.0.0.1:4222.\n*Why second:* highest ratio of \"never proven anywhere\" to effort, and it is the only tier that requires a two-process harness, which Tier 3 then reuses. Start from **PHP's `WebSocketHardeningTest.php`** - it already does real socket pairs, real registration API and a real closed-port backplane, and it is in the same repo as the file that gets it wrong (`WebSocketV3Test.php`). Convert PHP's outlier first (cheapest, the pattern is one file away), then port the proven shape to PY, RB, JS.\n\n### Tier 3 - Session backend failure policy (all four, the flagship four-way twin)\n\nDelete `_ExplodingHandler` / `ThrowingSessionHandler` / `RaisingHandler` / `ExplodingHandler` and both `Empty*` positive controls. Three real drivers: (a) real handler at a bind-then-release closed port for never-connected; (b) a real accept-and-never-reply listener for the timeout branch (Node already has `startSilentServer()`); (c) connect to real Redis 6379 then `CLIENT KILL` that connection for mid-flight death. For the empty-healthy control, read a fresh `uuid4` key off the real server so the empty read is genuinely empty. Redis 6379, Valkey 6380, memcached 11211, Mongo 27017 and Postgres 55432 are all up - \"the service was not available\" is unavailable as a defence.\n*Why third and not first:* the rig is mostly built (PHP's port-59999 pattern, Node's `closedPort()`), so it is not the hardest - but its assertions are meaningless until Tier 0a lands, and its \"backend dies mid-flight\" case shares the kill-the-connection rig from Tier 1. Also fix, in the same pass, PY `test_session_handlers.py:516/538` and JS `checkAuth.test.ts:230`: the cross-instance read-back is the only thing that proves a session value ever left the process.\n\n### Tier 4 - Security gates whose key input is fabricated\n\n**Expect these to fail on conversion. That is the point of doing them.**\n\n- **MCP remote gate** (PY `test_mcp_security.py:92`, RB `mcp_dev_endpoint_spec.rb:57`). Needs a genuinely non-loopback peer: bind 0.0.0.0 and connect via the host's real LAN address, or add a `127.0.0.2` loopback alias, so `remote_ip` is populated by the kernel. Then send a real `X-Forwarded-For` alongside and assert it is ignored - **that is the actual regression test, and it currently cannot exist.**\n- **Node's three auth reimplementations.** Delete the copies; drive the real gate via the shipped `TestClient` or a real booted server. If the real gate turns out to be hard to reach from outside, export it from `server.ts` and call it - do not re-type it. **Do not defer this on the grounds that the copies pass.**\n- **CSRF and auth transport shells** (JS `csrfMiddleware.test.ts` ~40 sites, PY `test_check_auth.py` / `test_router_auth_payload.py`, RB `csrf_middleware_spec.rb`, PHP `AuthV3Test.php:648`). Real server, real headers off the wire, real 403/401 status codes. PHP's is a one-helper deletion - the rest of `AuthV3Test` already passes real header arrays.\n- **JWT expiry against the real clock** (PY `test_parity_group_d.py:48`): mint a token with a genuinely past `exp` rather than substituting a fake `time` module into the auth module.\n- **SOAP XXE / billion laughs** (PY ~20 sites, RB `wsdl_spec.rb`): POST the hostile payloads as real bytes over real HTTP and assert on the real SOAP fault envelope. Conformance testing against the wire contract a real SOAP client speaks.\n- **Static path traversal:** confirm PY/PHP/RB have real traversal tests for the `response.file()` root confinement that just shipped in all four; convert JS `static.test.ts:28` to the real harness its two sibling files already use.\n\n### Tier 5 - Bulk transport conversion\n\n~43 sites: JS 24, PY 12, RB 6, PHP 1. Mechanical, high volume, low per-site risk, and it removes the largest single category by count. Real server on an ephemeral port, real request, assert on bytes the client received.\n*Sequencing within the tier:* start with the half-finished migrations, where the real harness is already in the file and only the call sites need moving - JS `response.test.ts` (its own comment says the migration started; ~25 call sites still on the double), JS `corsPolicyConformance.test.ts:231` (a local double inside an otherwise honest file), PHP `AuthV3Test.php:648` (last surviving fake in a converted file). Then the rest.\nSpecial case worth separating: **JS `request.test.ts:25`** - the most charitable-looking hit in the estate. The class is the production `IncomingMessage` and the socket is a real `net.Socket`, but the socket is never connected and `req.headers` is *assigned*, which substitutes for Node's real HTTP header parser. Convert it with raw-socket writes so you control literal request bytes (duplicate headers, real chunked bodies, real multipart boundaries, genuinely malformed JSON). **Also probe whether the shipped `TestClient` assembles its `IncomingMessage` the same way** - if it does, every test relying on `TestClient` inherits the same gap, including several of the Tier 4 replacements.\n\n### Tier 6 - Cheap, self-contained, do while blocked on Tier 1 infrastructure\n\n- ORM/DatabaseResult duck types -> real models (PY `test_response_autoserialize.py`, PHP `ResponseAutoSerializeTest`, JS `response-autoserialize.test.ts`). **Copy Ruby**, the only one already using a real ORM subclass. Near-zero cost: a real sqlite in-memory DB, a real subclass, a real row. Matters because `insert/update/delete -> DatabaseResult` was a recent breaking change (3.13.86) and a two-member anonymous class hard-codes today's accessors.\n- PY `test_orm.py:223` `_Dummy` FK target -> reuse the real `User`/`Post` models 200 lines up.\n- PY `test_env_vars.py:416` `FakeORM` -> a real subclass with real Field objects.\n- PY `test_template_decorator.py` -> a real `.twig` fixture and the real Frond engine (11 tests currently prove only that a tuple was appended to a list; also has 3 dead `unittest.mock` imports).\n- JS CLI console/`process.exit` reassignments (6 sites) -> spawn the real binary; `cliDelegatedCommands.test.ts` is already the correct harness in the same suite. Note `metrics-cli.test.ts` is skipped by default (`TINA4_SKIP_METRICS` defaults to `1`), so that double may never have executed at all.\n- Ruby `env_vars_spec.rb:43` `double(\"app\")` -> real `RackApp`.\n\n### Tier 7 - Framework fixes surfaced by the audit (file as bugs, not test work)\n\n1. Move `TINA4_MAX_UPLOAD_SIZE` off import-time binding in tina4-python; **sweep all four for other env vars bound at import.** In-process tests are structurally blind to this shape.\n2. Land the MagicMock session-handler removal on **v3**, not just `feature/audit-auth`. Confirm it is a clean cherry-pick.\n3. Node: settle the three drifted copies of the `server.ts` auth block by exporting the real function.\n\n---\n\n## COULD NOT VERIFY\n\n- **I re-ran nothing.** No suite, no grep, no service probe. Every count, line number, verdict and service state above is as filed by the four scanners. Where two inventories imply different things (e.g. Firebird reachability), I have said so rather than picking one.\n- **Coverage is not established anywhere.** Each scanner enumerated doubles, not tests. Every \"NONE FOUND\" in the matrix and every entry in section 2a is a **candidate**, not a confirmed gap. The probes are given; run them before acting on any of them.\n- **Service state is stale and inconsistent across the four reports.** Redis 6379, Valkey 6380, redis-ish 6381, memcached 11211, Mongo 27017, Postgres 55432, MySQL 3306 were reported up by all four. Kafka 9092 and RabbitMQ 5672 were confirmed by TCP connect only (no protocol handshake) by the Python scanner. NATS 4222 reported down. MSSQL 1433 and Firebird 3050: PHP and Ruby report absent, Python reports a TCP accept on 3050 without authenticating. **Re-probe with a real handshake, not `nc -z`, before scheduling Tier 1.**\n- **The Postgres deferred-constraint rig for the commit-failure conversion is reasoned from the SQL standard, not measured.** No one opened psql to confirm the commit-time raise surfaces as a `DatabaseException` through the adapter. Prefer `pg_terminate_backend` or the SQLite `BEGIN IMMEDIATE` fallback until that is checked.\n- **No proposed replacement has been written or run.** Every one is a design derived from a pattern already proven in the same repo. None is verified green.\n- **Two judgement calls in the Ruby inventory should be ratified before conversion starts**, because they change scope by a large factor: (a) `\"rack.input\" => StringIO.new(body)` ruled EXEMPT on the grounds that the Rack spec defines the input as a rewindable IO-like - a stricter reading puts most of the Ruby HTTP suite in scope; (b) in-test middleware classes and `stub_const`'d ORM models ruled EXEMPT as application-supplied inputs rather than substituted collaborators. The other three inventories made the same call on middleware fixtures. **These four calls are consistent across the estate; if the project overrules any of them, overrule it in all four at once.**\n- **The `TestClient` question is open in Node and unexamined in the other three.** It is framework source, outside every scanner's scope, and several Tier 4/5 replacements depend on it being real.\n- Line numbers are pinned to the four commits named at the top. None of the four scanners confirmed a clean working tree.",
    "inventories": [
      {
        "framework": "pytest 9.0.2 / Python 3.13.5 (.venv) on macOS 26.5.2. Repo: /Users/andrevanzuydam/IdeaProjects/tina4-python, branch v3 @ fb6fcb2 (\"Confine response.file() to a root in all four\"), framework version 3.13.94. Doubles are stdlib unittest.mock (MagicMock/patch/patch.dict), pytest monkeypatch (setattr/setitem), and hand-rolled in-test classes. NOTE: the MagicMock Redis/Valkey/Mongo session fix you mention as \"already fixed on feature/audit-auth\" is NOT on v3 — tests/test_session_handlers.py on v3 still carries all five MagicMock clients.",
        "hits": [
          {
            "file": "tests/test_session_handlers.py",
            "line": 162,
            "shape": "MagicMock() assigned to handler._redis_client, with _use_redis_pkg=True forced",
            "stands_in_for": "a real Redis server (verified UP at 127.0.0.1:6379)",
            "verdict": "VIOLATION",
            "reason": "TestRedisHandlerMocked drives read/write/destroy/close entirely against MagicMock. assert_called_once_with on setex/delete asserts the SHAPE of the call, never that Redis stored or expired anything — the exact failure class that let the Node Mongo queue redeliver for two releases. This file is on v3 despite the claimed fix.",
            "real_replacement": "Use the real Redis at 127.0.0.1:6379 (already UP). TestRedisIntegration at line 557 in this same file is the correct pattern: RedisSessionHandler(host=_REDIS_HOST, port=_REDIS_PORT, ttl=60) then write->read->destroy->read. Extend it to cover TTL (write ttl=1, sleep 1.5, assert read=={}) and the default-TTL path via a real TTL query. Delete TestRedisHandlerMocked entirely."
          },
          {
            "file": "tests/test_session_handlers.py",
            "line": 271,
            "shape": "MagicMock() assigned to handler._collection, _use_pymongo=True forced",
            "stands_in_for": "a real MongoDB collection (verified UP at 127.0.0.1:27017)",
            "verdict": "VIOLATION",
            "reason": "TestMongoDBHandlerMocked asserts update_one/delete_one/delete_many call args. find_one returns a hand-written dict, so document round-trip, upsert semantics and the $lt gc query are never executed by Mongo. test_read_expired_session_returns_empty fabricates last_accessed instead of letting a real document age.",
            "real_replacement": "Real Mongo at 127.0.0.1:27017. Write a session, read it back on a SECOND MongoDBSessionHandler instance (proves durability, not local state), then destroy and re-read. For expiry: write with ttl=1, time.sleep(1.5), assert read()=={} and assert the document is actually gone via a real find_one. For gc: insert two genuinely-old docs plus one fresh, call gc(), then count_documents() for real."
          },
          {
            "file": "tests/test_session_handlers.py",
            "line": 388,
            "shape": "MagicMock() assigned to handler._redis_client on ValkeySessionHandler",
            "stands_in_for": "a real Valkey server (verified UP at 127.0.0.1:6380)",
            "verdict": "VIOLATION",
            "reason": "TestValkeyHandlerMocked never opens a socket to Valkey. Valkey is a separate daemon on a separate port with its own protocol quirks; a MagicMock proves nothing about it and would keep passing if the handler pointed at the wrong port entirely.",
            "real_replacement": "Real Valkey at 127.0.0.1:6380. TestValkeyIntegration at line 595 already does the round-trip correctly — fold the read/write/destroy/close/prefix assertions into it and delete the mocked class."
          },
          {
            "file": "tests/test_session_handlers.py",
            "line": 516,
            "shape": "MagicMock() Redis client injected into a real Session via _make_redis_handler_mocked",
            "stands_in_for": "a real Redis session backend behind the Session facade",
            "verdict": "VIOLATION",
            "reason": "test_session_with_redis_handler asserts session.get('user_id')==42 immediately after session.set — that reads back from the in-process dict, not from Redis. The assertion would pass with a handler that discards every write, so the Session->Redis integration is completely unproven.",
            "real_replacement": "Real Redis 6379. Session(handler=RedisSessionHandler(host,port), ttl=600); start(sid); set(); save(); then construct a SECOND Session with a fresh handler, start(same sid), and assert get('user_id')==42. Only a cross-instance read proves the value actually went to Redis."
          },
          {
            "file": "tests/test_session_handlers.py",
            "line": 538,
            "shape": "MagicMock() Valkey client injected into a real Session",
            "stands_in_for": "a real Valkey session backend behind the Session facade",
            "verdict": "VIOLATION",
            "reason": "Same defect as line 516 — session.get('lang') reads process memory, so the Session/Valkey persistence path is never exercised.",
            "real_replacement": "Real Valkey 6380, second-Session read-back as above."
          },
          {
            "file": "tests/test_firebird_reconnect.py",
            "line": 70,
            "shape": "MagicMock() as the connection and as dead_cursor/fresh_cursor",
            "stands_in_for": "a real Firebird connection and cursor (Firebird verified UP at 127.0.0.1:3050)",
            "verdict": "VIOLATION",
            "reason": "The whole point of this file is transparent recovery from a socket that died behind NAT/idle-timeout. dead_cursor.execute.side_effect = Exception('Error writing data to the connection.') is a hand-typed string, not a real driver error. If the Firebird driver ever reworded that message, or raised a different exception class, every test here still passes while production breaks.",
            "real_replacement": "Firebird is live on 3050. Put a real TCP forwarder you control between the adapter and the server (asyncio/socat listener on 127.0.0.1:0 forwarding to 3050), connect FirebirdAdapter through the forwarder, run a successful SELECT, then TEAR THE FORWARDER DOWN so the socket genuinely dies. The next cursor.execute raises the driver's real dead-connection error; restart the forwarder and assert _safe_cursor_execute reconnected and the retry returned rows. Same rig with the forwarder left up but a genuine bad SQL statement covers the no-retry-on-logical-error case."
          },
          {
            "file": "tests/test_firebird_reconnect.py",
            "line": 88,
            "shape": "monkeypatch.setattr(a, \"_reconnect\", fake_reconnect)",
            "stands_in_for": "the adapter's real reconnect path (real socket re-open against Firebird)",
            "verdict": "VIOLATION",
            "reason": "Replacing _reconnect means the assertion 'reconnect must be invoked exactly once' only proves a call count. Whether the real _reconnect can actually re-establish a Firebird connection after a dead socket — the entire shipped behaviour — is never executed. The sibling tests at 105 and 121 monkeypatch _reconnect to pytest.fail, which is a control-flow assertion, not a real dependency, but they still hang off the MagicMock cursor.",
            "real_replacement": "Let the REAL _reconnect run against real Firebird on 3050 using the TCP-forwarder rig above. Assert recovery by observable outcome: the retried SELECT returns the correct rows on a connection whose original socket is provably gone (compare the driver's connection handle/attachment id before and after)."
          },
          {
            "file": "tests/test_firebird_reconnect.py",
            "line": 145,
            "shape": "monkeypatch.setattr(a, \"_open\", fake_open)",
            "stands_in_for": "the real Firebird connection-open call",
            "verdict": "VIOLATION",
            "reason": "test_reconnect_uses_cached_params asserts _reconnect passes cached params to _open by capturing them in a fake. It never proves those cached params can actually open a connection — a params dict with a wrong key name would pass this test and fail in production.",
            "real_replacement": "Connect a real FirebirdAdapter to 127.0.0.1:3050 so connect() caches real params, kill the socket via the forwarder, call the real _reconnect(), and assert a real query succeeds afterwards. Credentials never re-passed = proven by the query working."
          },
          {
            "file": "tests/test_firebird_reconnect.py",
            "line": 170,
            "shape": "a._open = lambda: setattr(a, \"_conn\", MagicMock()) — direct method overwrite",
            "stands_in_for": "the real Firebird connection-open call",
            "verdict": "VIOLATION",
            "reason": "Comment says 'Stub _open so we don't actually try to connect to a real server'. Firebird IS running on 3050, so the stated reason is not true on this host. bad_conn.close() raising is also fabricated.",
            "real_replacement": "Real close-error: open a real Firebird connection, then destroy the underlying socket out from under the driver (drop the forwarder, or close the raw fd) so the driver's own close() raises for real. Then call _reconnect() and assert it completed and the new connection serves a query."
          },
          {
            "file": "tests/test_postgres_idle_in_transaction.py",
            "line": 45,
            "shape": "monkeypatch.setitem(sys.modules, \"psycopg2\", types.ModuleType(...)) — a stub MODULE injected into sys.modules",
            "stands_in_for": "the real psycopg2 driver",
            "verdict": "VIOLATION",
            "reason": "An autouse fixture replaces the entire psycopg2 module with an empty ModuleType whose RealDictCursor is `object`. Every test in the file then runs against a driver that does not exist. The bug being regressed (connections stuck 'idle in transaction' exhausting max_connections until autodiscovery 404s every route) is a property of the real psycopg2 connection's transaction state and cannot be observed here at all.",
            "real_replacement": "Postgres is UP at 127.0.0.1:55432 (and 5432). Install the postgres extra and connect for real. Prove the fix the way production shows it: run db.fetch('SELECT 1'), then from a SEPARATE connection query `SELECT state FROM pg_stat_activity WHERE pid = <the adapter connection's backend pid>` and assert state != 'idle in transaction'. For the deferred case, start_transaction() then fetch(), and assert pg_stat_activity DOES report 'idle in transaction' until commit(). pg_stat_activity is the only witness that matters and it requires a real server."
          },
          {
            "file": "tests/test_postgres_idle_in_transaction.py",
            "line": 96,
            "shape": "FakeConn class counting rollbacks/commits, with FakeCursor and FakeInfo",
            "stands_in_for": "a real psycopg2 connection, cursor and connection.info",
            "verdict": "VIOLATION",
            "reason": "Asserting adapter._conn.rollbacks == 1 counts calls into a fake. FakeInfo hardcodes transaction_status = 0 so the pre-flight heal branch is deliberately skipped — meaning a whole real code path is dead in every test. The file's own docstring justifies this with 'These tests need no live PostgreSQL', which is the 'hard to reproduce' exception the rule forbids, and is false: Postgres is up on 55432.",
            "real_replacement": "Real psycopg2 connection to 127.0.0.1:55432; assert transaction state through pg_stat_activity as above rather than counting rollback() calls. For the INERROR heal path, drive a real error (e.g. SELECT from a nonexistent table) so connection.info.transaction_status genuinely becomes INERROR, then assert the next fetch() heals and succeeds."
          },
          {
            "file": "tests/test_postgres_percent_substitution.py",
            "line": 18,
            "shape": "FakeCursor recording (sql, whether a params arg was supplied)",
            "stands_in_for": "a real psycopg2 cursor",
            "verdict": "VIOLATION",
            "reason": "Issue #40 is that psycopg2 itself raises 'list index out of range' when it tries to interpolate % in a PL/pgSQL body. Only real psycopg2 does that interpolation. FakeCursor asserts which overload the framework chose — a proxy for the bug, not the bug. test_plpgsql_body_with_percent_does_not_raise cannot raise regardless of whether the fix is present, because nothing in the test can interpolate.",
            "real_replacement": "Real Postgres 127.0.0.1:55432. Execute the actual CREATE OR REPLACE FUNCTION with literal % and 100%% in the body through db.execute(sql) with params=None, and assert (a) it does not raise and (b) SELECT proname FROM pg_proc WHERE proname='enforce_unique' returns the row. Add a negative lock-in that the params-supplied path still interpolates correctly: INSERT ... VALUES (%s,%s) with [1,2] then SELECT the row back."
          },
          {
            "file": "tests/test_websocket_hardening.py",
            "line": 46,
            "shape": "FakeBackplane(WebSocketBackplane) — in-memory pub/sub subclass",
            "stands_in_for": "the real Redis or NATS WebSocket backplane",
            "verdict": "VIOLATION",
            "reason": "The module docstring states outright: 'Everything here is engine-agnostic: no real Redis, NATS, or sockets. A tiny in-memory FakeBackplane proves the relay path end-to-end.' It proves the opposite — publish() fans out synchronously in-process, so serialization, channel naming on the wire, connection loss, reconnection and cross-process ordering are all untested. Redis is UP at 6379.",
            "real_replacement": "Real Redis at 127.0.0.1:6379 with TINA4_WS_BACKPLANE=redis. Run two WebSocketManagers (ideally two real processes, at minimum two managers with independent real Redis clients), attach real WebSocket connections, broadcast from A and assert the frame arrives on B's real socket. Assert the envelope by SUBSCRIBING to the real tina4:ws channel with a separate redis client and reading the real published bytes. NATS is DOWN (127.0.0.1:4222 refused) so the NATS variant must skip loudly naming host and port."
          },
          {
            "file": "tests/test_websocket_hardening.py",
            "line": 23,
            "shape": "FakeConnection class with a sent list and raise_on_send flag",
            "stands_in_for": "a real WebSocketConnection over a real TCP socket",
            "verdict": "VIOLATION",
            "reason": "Broadcast resilience is about a dead/slow client not aborting delivery to the rest. raise_on_send=True raises a hand-constructed ConnectionError, which is not what a real half-closed or RST socket does — real failures surface as ConnectionResetError, BrokenPipeError, or a hang, at different points in the frame write. Pruning is asserted against a list, not against the manager's real connection set after a real socket death.",
            "real_replacement": "Start a real WebSocket server (the suite already has conftest.boot_child_server). Connect three real clients. Kill one abruptly at the TCP level — setsockopt(SO_LINGER, 1, 0) then close() sends a real RST — then broadcast and assert the two survivors received the frame on their real sockets and mgr.count() dropped to 2."
          },
          {
            "file": "tests/test_websocket_hardening.py",
            "line": 220,
            "shape": "class ExplodingBackplane(FakeBackplane) overriding publish() to raise",
            "stands_in_for": "a real message bus that is down",
            "verdict": "VIOLATION",
            "reason": "A subclass overriding one method to force a branch — the exact non-obvious double shape. RuntimeError('bus down') is not how a real Redis outage presents (that is a connection reset or timeout at the client layer, possibly after a delay).",
            "real_replacement": "Point TINA4_WS_BACKPLANE_URL at a genuinely closed port: bind a socket to 127.0.0.1:0, read the assigned port, close it, use that URL. Publishing then fails with a real refused connection. Alternatively connect to real Redis 6379 and stop the service (or CLIENT KILL the backplane connection) mid-test. Assert local delivery still reached real connections."
          },
          {
            "file": "tests/test_websocket_hardening.py",
            "line": 244,
            "shape": "monkeypatch.setattr(\"tina4_python.websocket.backplane.create_backplane\", _boom)",
            "stands_in_for": "real backplane construction against Redis",
            "verdict": "VIOLATION",
            "reason": "Patching the module-level factory to raise fabricates the 'Redis unreachable at startup' condition the test names, instead of producing it. The degrade-to-local-only guarantee is only proven for a RuntimeError thrown at exactly that call site.",
            "real_replacement": "TINA4_WS_BACKPLANE=redis with TINA4_WS_BACKPLANE_URL pointing at a real closed port (bind-then-close to guarantee it is free). create_backplane then fails for real during _ensure_backplane, and you assert mgr._backplane is None, _backplane_started is True, and a real connection still received the broadcast."
          },
          {
            "file": "tests/test_websocket_hardening.py",
            "line": 322,
            "shape": "server.handle = fake_handle — module attribute overwritten, restored in finally",
            "stands_in_for": "the framework's real request dispatch",
            "verdict": "VIOLATION",
            "reason": "_run_stream replaces server.handle so server.app() never routes. The SSE tests therefore exercise the ASGI streaming branch with dispatch amputated; a regression in how a real route reaches the streaming branch is invisible. The scope dict and send/receive callables are also hand-rolled stand-ins for the real ASGI server.",
            "real_replacement": "Register a REAL route that returns response.stream(generator) and drive it through the real ASGI app, or through a real booted server (boot_child_server) with a real HTTP client reading the chunked body. No attribute replacement needed — the real path is one route registration away."
          },
          {
            "file": "tests/test_websocket_hardening.py",
            "line": 353,
            "shape": "class HangingSource — async-iterable that raises asyncio.CancelledError on the 2nd __anext__",
            "stands_in_for": "a real streaming generator whose HTTP client disconnected",
            "verdict": "VIOLATION",
            "reason": "'Simulate the client disconnecting' is a comment in the test. A real disconnect is the peer closing the TCP connection, which the server observes through the ASGI transport, not through the source raising CancelledError at a moment of the test's choosing. The aclose() cleanup assertion is against a flag on the fake.",
            "real_replacement": "Boot a real server with a real SSE route. Connect a real HTTP client, read the first chunk, then close the client socket (SO_LINGER 0 for an immediate RST). Assert server-side that the generator was closed — have the REAL route's generator write a marker to a real file in its finally/aclose, then read that file."
          },
          {
            "file": "tests/test_session_backend_failure.py",
            "line": 26,
            "shape": "class _ExplodingHandler(SessionHandler) raising ConnectionError on every method",
            "stands_in_for": "an unreachable Redis / Valkey / Mongo / database session backend",
            "verdict": "VIOLATION",
            "reason": "Its own docstring says 'simulates an unreachable Redis/Valkey/Mongo/DB mid-request'. ConnectionError is one exception type chosen by the test; a real unreachable Redis raises redis.exceptions.ConnectionError, a real Mongo raises ServerSelectionTimeoutError after a timeout, a real DB raises a driver-specific OperationalError. If the framework's except clause is narrower than the test assumes, all six tests here pass while production 500s on every request — a cascade outage, the exact thing this file claims to prevent.",
            "real_replacement": "Drive each backend to a REAL closed port: bind a socket to 127.0.0.1:0, capture the port, close it, then RedisSessionHandler(host='127.0.0.1', port=<that port>). Repeat for Valkey and Mongo (MongoDBSessionHandler with a short serverSelectionTimeoutMS so the test stays fast) and for DatabaseSessionHandler against a Postgres URL on a closed port. For a mid-request death rather than never-connected, connect to real Redis 6379 first, then CLIENT KILL that connection, then call save()."
          },
          {
            "file": "tests/test_session_backend_failure.py",
            "line": 43,
            "shape": "class _EmptyHandler(SessionHandler) returning {} and counting reads",
            "stands_in_for": "a healthy session backend that has no data for this id",
            "verdict": "VIOLATION",
            "reason": "The empty-but-healthy path is trivially real and there is no reason to fake it. handler.reads==1 is a call-count assertion on a double rather than an observation of the real backend.",
            "real_replacement": "Real Redis 6379 (or the real FileSessionHandler under tmp_path) with a session id generated fresh via uuid4 that has provably never been written. Assert all()=={} and that zero errors were logged."
          },
          {
            "file": "tests/test_session_backend_failure.py",
            "line": 69,
            "shape": "monkeypatch.setattr(Log, \"error\", classmethod(lambda cls, msg, **kw: errors.append(msg)))",
            "stands_in_for": "the real Tina4 Log / its real output sink",
            "verdict": "VIOLATION",
            "reason": "Replacing Log.error is a message expectation on a real collaborator — the same shape as the Ruby expect(Tina4::Log).to receive(:error) you already flagged. It asserts the framework called a method, not that an operator would ever see the line. Formatting, level filtering, json vs text mode, and whether the record reaches stdout or the log file are all bypassed. All five 'must be logged, never silent' assertions in this file are therefore unproven.",
            "real_replacement": "Capture the REAL log output. Either Log.configure(level='error', production=False) and read pytest's capsys stdout (tests/test_middleware.py:257 already uses capsys correctly against the real Log), or point the real log file at tmp_path, run the scenario, then read the file bytes and assert the message and level are present. Same fix applies to the Ruby RaisingHandler/Log expectations."
          },
          {
            "file": "tests/test_database_drivers.py",
            "line": 124,
            "shape": "with patch.dict(\"sys.modules\", {\"psycopg2\": None, \"psycopg2.extras\": None})",
            "stands_in_for": "a Python environment in which the psycopg2 driver is genuinely not installed",
            "verdict": "VIOLATION",
            "reason": "Poisoning sys.modules with None forces ImportError at a synthetic point. It does not reproduce a real missing-package environment: real absence also affects transitive imports, C-extension load failures (the documented pyodbc/libodbc.so.2 case where the wheel installs but cannot import), and the exact message text. Same construct at lines 131 (mysql) and 138 (pymssql).",
            "real_replacement": "Run the import in a real interpreter that really lacks the driver: subprocess with `uv run --no-project --python 3.13 python -c \"from tina4_python.database.postgres import PostgreSQLAdapter; PostgreSQLAdapter().connect('postgresql://...')\"` in an env without psycopg2, and assert on the real stderr. That also catches the wheel-installs-but-cannot-import case, which patch.dict can never surface."
          },
          {
            "file": "tests/test_database_drivers.py",
            "line": 143,
            "shape": "fb_module._driver = None (module attribute overwritten, restored in finally)",
            "stands_in_for": "a real environment with no Firebird driver",
            "verdict": "VIOLATION",
            "reason": "Same class as the patch.dict cases — a module attribute is reassigned to force the not-installed branch rather than running in an environment that lacks the driver.",
            "real_replacement": "Real subprocess in an interpreter without the Firebird driver installed, asserting the real ImportError text. (Firebird itself is UP on 3050, so the positive path can also be proven for real in the same file.)"
          },
          {
            "file": "tests/test_orm_v3_13_11.py",
            "line": 257,
            "shape": "monkeypatch.setattr on db.get_database_type, db.execute and db.table_exists (fake_execute captures SQL, fake_table_exists returns False)",
            "stands_in_for": "real Postgres / MySQL / MSSQL / Firebird engines",
            "verdict": "VIOLATION",
            "reason": "The in-test comment is verbatim the forbidden justification: 'we can't easily spin up every engine' and 'we also stub execute so the rendered DDL goes nowhere'. The test asserts a substring appears in generated DDL text. Because execute is stubbed, DDL that no engine would accept passes — which is exactly how a wrong column type ships. Every engine named here is reachable: Postgres 55432, MySQL 3306, MSSQL 1433, Firebird 3050.",
            "real_replacement": "Parametrize over real connections to 127.0.0.1:55432 (postgres), 3306 (mysql), 1433 (mssql), 3050 (firebird), plus sqlite. Run the REAL create_table() against each, then introspect the real result with db.get_columns(table) (or information_schema / RDB$RELATION_FIELDS) and assert the column's real stored type. That proves the engine accepted the DDL, which the current test cannot. Any engine not reachable must skip loudly naming host and port."
          },
          {
            "file": "tests/test_dev_reload_ws.py",
            "line": 61,
            "shape": "monkeypatch.setattr(server._ws_manager, \"broadcast\", fake_broadcast)",
            "stands_in_for": "the real WebSocketManager broadcasting over real sockets",
            "verdict": "VIOLATION",
            "reason": "The tests assert a payload was handed to a fake coroutine. Whether any browser on /__dev_reload actually receives the frame — the entire DevReload feature — is not exercised. Same construct at line 87.",
            "real_replacement": "The file already contains the correct pattern in its own docstring and imports conftest.boot_child_server. Boot a real child server with TINA4_DEBUG=true, open a real WebSocket client to /__dev_reload, POST /__dev/api/reload over real HTTP, and read the real frame off the client socket, asserting the JSON {type,file,mtime}."
          },
          {
            "file": "tests/test_dev_reload_ws.py",
            "line": 106,
            "shape": "monkeypatch.setattr(server._ws_manager, \"broadcast\", boom) raising RuntimeError(\"socket gone\")",
            "stands_in_for": "a real broadcast failing because a client socket died",
            "verdict": "VIOLATION",
            "reason": "'socket gone' is a fabricated RuntimeError. A real dead peer raises ConnectionResetError/BrokenPipeError from the frame write. If the endpoint's except clause is narrower than Exception, this test passes and the real endpoint 500s.",
            "real_replacement": "Connect a real WS client to a real booted server, then RST it (SO_LINGER 0 + close) without letting the server observe a clean close. POST /__dev/api/reload and assert it still returns ok while the real broadcast hit a real broken pipe."
          },
          {
            "file": "tests/test_dev_reload_ws.py",
            "line": 33,
            "shape": "class _Req with body/params, plus _resp_factory() returning a recording function",
            "stands_in_for": "the framework Request and Response objects",
            "verdict": "VIOLATION",
            "reason": "The handler is called with objects that merely happen to expose .body and .params. Real request parsing (JSON body decoding, content-type handling) and real response construction are skipped, so a handler that only works on the test's duck type would pass.",
            "real_replacement": "Drive POST /__dev/api/reload over a real socket against a real booted server so the framework builds the real Request and Response."
          },
          {
            "file": "tests/test_template_decorator.py",
            "line": 19,
            "shape": "class MockResponse with a render() that appends to _render_calls (plus MockRequest at line 10)",
            "stands_in_for": "the framework Response and, through it, the real Frond template engine",
            "verdict": "VIOLATION",
            "reason": "All 11 tests assert that @template recorded ('pages/dashboard.twig', {...}) into a list. No template is ever located, compiled or rendered. A template path that does not exist, a Frond syntax error, or a change to Response.render's signature would all keep this suite green.",
            "real_replacement": "Use the real Response and real Frond. Put a real .twig fixture under tests/fixtures (e.g. {{ title }}), point the decorator at it, and assert the real rendered bytes contain the interpolated value and content_type is text/html. For the composition test, register a real @get route and drive it through the real dispatcher. Note unittest.mock imports MagicMock/AsyncMock/patch here are unused dead imports."
          },
          {
            "file": "tests/test_cache.py",
            "line": 16,
            "shape": "class MockRequest and class MockResponse (line 27) used across ~30 tests in a 66-test file",
            "stands_in_for": "the framework Request and Response",
            "verdict": "VIOLATION",
            "reason": "ResponseCache middleware is exercised entirely against duck types. MockResponse.__call__ returns a NEW MockResponse, which is not what the real Response does — so cache-hit identity, header mutation ordering and X-Cache emission are all validated against invented semantics. `from unittest.mock import patch` at line 7 is an unused dead import.",
            "real_replacement": "Use the real Response()/Request, or better drive real @cached / @middleware(ResponseCache) routes through the real dispatcher and assert the real X-Cache and Cache-Control headers on the real response. Back the cache with the real backends that are up — redis 6379, valkey 6380, memcached 11211, mongodb 27017 — not just memory."
          },
          {
            "file": "tests/test_middleware.py",
            "line": 8,
            "shape": "class MockRequest (line 8), MockResponse (line 17), MockReqLog (line 250)",
            "stands_in_for": "the framework Request and Response objects",
            "verdict": "VIOLATION",
            "reason": "CorsMiddleware, RateLimiter and RequestLoggerMiddleware are driven with stubs exposing only .method/.headers/.ip and .header()/.status(). MockRequest.ip in particular substitutes for the real socket peer address, which is precisely the field a rate limiter must not get wrong (the MCP audit already found an X-Forwarded-For vs raw-peer bug of exactly this shape).",
            "real_replacement": "Drive real HTTP requests through a real booted server and assert the real Access-Control-* headers and 429s off the wire, with the client's real source address supplying request.ip. The RequestLogger test at line 257 already asserts against real stdout via capsys — keep that, replace only the req/resp stubs."
          },
          {
            "file": "tests/test_router_auth_payload.py",
            "line": 20,
            "shape": "class MockRequest (headers + auth) and MockResponse (line 28) recording status",
            "stands_in_for": "the framework Request and Response",
            "verdict": "VIOLATION",
            "reason": "Auth payload propagation is asserted by reading .auth off a stub the test itself defined. Whether the real Request exposes/carries auth the same way is unproven — an auth test that never sees a real request object is the highest-risk shape in the file set.",
            "real_replacement": "Use the real TestClient (which per project memory routes through the real auth gate) or a real booted server: mint a real JWT with the real Auth class, send a real Authorization header, and assert the handler observed the real decoded payload on the real Request."
          },
          {
            "file": "tests/test_check_auth.py",
            "line": 30,
            "shape": "class _MockSession (dict-backed get()) and class _MockRequest (line 40)",
            "stands_in_for": "the real Session (and its backend) and the framework Request",
            "verdict": "VIOLATION",
            "reason": "_MockSession stands in for a session backend inside an AUTH test. Session-based auth decisions are validated against a plain dict, so nothing about real session load, expiry, or backend failure influences the auth outcome.",
            "real_replacement": "Real Session with the real FileSessionHandler under tmp_path, or the real RedisSessionHandler against 127.0.0.1:6379. Write the session for real, then drive _check_auth through a real request (real server or TestClient) carrying the real session cookie."
          },
          {
            "file": "tests/test_websocket.py",
            "line": 136,
            "shape": "class _MockTransport returning a fixed peername, wrapped in a real asyncio.StreamWriter with type(\"P\",(),{})() as the protocol",
            "stands_in_for": "a real TCP socket transport",
            "verdict": "VIOLATION",
            "reason": "WebSocketConnection is built over a hand-made transport, so peer address resolution, is_closing() semantics, backpressure and real close behaviour are all invented. The same pattern recurs at lines 221, 239 and 588.",
            "real_replacement": "asyncio.start_server on 127.0.0.1:0, connect a real client with asyncio.open_connection, and build WebSocketConnection from the real reader/writer of the accepted connection. Real peername, real close, real is_closing — and the test can then assert bytes actually observed by the client."
          },
          {
            "file": "tests/test_parity_group_a.py",
            "line": 216,
            "shape": "class _MemoryHandler with a dict store, passed as Session(handler=...)",
            "stands_in_for": "a real session backend (file, Redis, Valkey, Mongo or database)",
            "verdict": "VIOLATION",
            "reason": "An in-test class implementing the session backend interface — the dangerous shape that does not look like a mock. All seven dict-access tests read back from the same in-process dict, so nothing about persistence is proven.",
            "real_replacement": "The framework ships a real FileSessionHandler — use it with tmp_path, or use the real RedisSessionHandler against 127.0.0.1:6379. Dict-style access assertions then run over a genuinely persisted session."
          },
          {
            "file": "tests/test_parity_group_a.py",
            "line": 289,
            "shape": "class _MockWriter with get_extra_info returning a fixed peername (defined twice, also line 303)",
            "stands_in_for": "a real asyncio StreamWriter / TCP socket",
            "verdict": "VIOLATION",
            "reason": "WebSocketConnection is constructed with reader=None and a fake writer purely to reach connection_count. reader=None means the object could never serve traffic, so the manager's counting is verified on objects that are not viable connections.",
            "real_replacement": "Real asyncio.start_server on 127.0.0.1:0 with real accepted connections, as for _MockTransport above."
          },
          {
            "file": "tests/test_parity_group_d.py",
            "line": 48,
            "shape": "monkeypatch.setattr(\"tina4_python.auth.time\", type(\"FakeTime\", (), {\"time\": staticmethod(lambda: real_time + 120)}))",
            "stands_in_for": "the real system clock module used by JWT expiry",
            "verdict": "VIOLATION",
            "reason": "A fake time module substituted into the auth module — a clock double inside a security test. JWT exp validation is the thing being tested; replacing the clock means the real comparison (including any nbf/leeway handling) is never executed with real values.",
            "real_replacement": "Mint a token that is ALREADY expired by the real clock: Auth(expires_in=...) with a value that puts exp in the past, or construct the token then time.sleep past a genuinely short expiry (expires_in is in minutes, so add a seconds-level seam or assert against a token built with a real past exp claim). The real clock then does the real comparison."
          },
          {
            "file": "tests/test_migration_footguns.py",
            "line": 16,
            "shape": "class _FakeDB with get_database_type() and table_exists() returning canned values",
            "stands_in_for": "a real Database against MSSQL / Firebird / SQLite / Postgres",
            "verdict": "VIOLATION",
            "reason": "Used at lines 200, 205, 210, 215, 216 and 220 to decide whether CREATE TABLE should be skipped on engines lacking IF NOT EXISTS. table_exists() is hardcoded True/False, so the real introspection query per engine — the part that actually breaks, and the identifier-quoting case at line 205 in particular — is never run. (The rest of this file, _split_statements / _parse_set_term / _migration_sort_key / _normalize_quotes, is genuinely pure string logic and is EXEMPT.)",
            "real_replacement": "All four engines are reachable: MSSQL 1433, Firebird 3050, Postgres 55432, SQLite local. Create the real table first (including the quoted \"Orders\" case on real Firebird), then call _should_skip_create_table with the real Database so real table_exists() runs, then drop it. That also proves the idempotency claim end to end by running the migration twice for real."
          },
          {
            "file": "tests/test_mcp.py",
            "line": 421,
            "shape": "class _FakeResponse with __call__/header()/stream() capturing output",
            "stands_in_for": "the framework Response used by the dev-admin MCP handlers",
            "verdict": "VIOLATION",
            "reason": "Docstring: 'Lets the tests drive the real MCP handlers without opening a socket.' MCP is a remotely-reachable surface with an explicit security gate; testing it without a socket means the SSE framing, streaming behaviour and header emission that a real MCP client depends on are asserted against a capture list.",
            "real_replacement": "Boot a real server (conftest.boot_child_server) with TINA4_DEBUG=true and speak real JSON-RPC over real HTTP to /__dev/mcp, including a real SSE read for the streaming path. This is conformance testing against the wire contract a real MCP client speaks."
          },
          {
            "file": "tests/test_mcp_security.py",
            "line": 92,
            "shape": "class _FakeReq with settable remote_ip and headers",
            "stands_in_for": "the framework Request and, critically, the real socket peer address",
            "verdict": "VIOLATION",
            "reason": "This is the security gate: loopback always allowed, remote requires TINA4_MCP_REMOTE plus a token. remote_ip is the one field the gate keys on, and the test sets it by hand to '8.8.8.8'. The documented design point is that the gate must read the RAW socket peer and never X-Forwarded-For — a hand-set attribute cannot distinguish those two, so the regression the gate exists to prevent is undetectable here.",
            "real_replacement": "Boot a real server and connect over a real socket. Loopback is free (connect from 127.0.0.1). For a genuinely non-loopback peer, bind the server to 0.0.0.0 and connect via the host's real LAN address, or add a second loopback alias (127.0.0.2 / a real secondary interface) and connect from it, so request.remote_ip is populated by the kernel. Then send a real X-Forwarded-For header alongside and assert it is ignored — that is the actual regression test."
          },
          {
            "file": "tests/test_swagger_v3_13_40.py",
            "line": 236,
            "shape": "class _FakeReq with path/method/headers, passed to srv._handle_swagger",
            "stands_in_for": "the framework Request",
            "verdict": "VIOLATION",
            "reason": "The production enable-gate for the Swagger surface is asserted with a hand-built request. Note the test correctly uses the REAL Response — so the real object was available and only the request was faked, which makes this a gratuitous double on a security-relevant gate.",
            "real_replacement": "Boot a real server with TINA4_DEBUG=false and TINA4_SWAGGER_ENABLED unset, GET /swagger over real HTTP and assert 404/refusal; set TINA4_SWAGGER_ENABLED=true, restart, and assert the real document is served."
          },
          {
            "file": "tests/test_dev_admin.py",
            "line": 369,
            "shape": "mock_req fixture = type(\"Req\", (), {\"params\": {}, \"body\": {}})() and mock_resp fixture = a recording function (75 references in the file; more inline at lines 588, 605, 617, 618)",
            "stands_in_for": "the framework Request and Response across the whole dev-admin API surface",
            "verdict": "VIOLATION",
            "reason": "An anonymous type() class standing in for Request — the least mock-looking double in the repo. The entire TestAPIHandlers class calls handlers directly with it, so every dev-admin endpoint's real request parsing, real response serialization and real HTTP status are unverified.",
            "real_replacement": "conftest.boot_child_server is already available in this suite. Boot the real dev server and GET/POST the real /__dev/api/* endpoints over real HTTP, asserting real status codes and real JSON bodies."
          },
          {
            "file": "tests/test_wsdl.py",
            "line": 107,
            "shape": "req = type(\"R\", (), {\"body\": ..., \"url\": ..., \"params\": {}})() — repeated ~20 times (lines 107,114,120,127,137,148,163,180,188,194,205,219,329,336,342,355,366,498,510)",
            "stands_in_for": "the framework Request carrying a real SOAP HTTP POST",
            "verdict": "VIOLATION",
            "reason": "SOAP handlers are invoked with anonymous type() objects. Body decoding, content-type negotiation and header handling never run. The XXE and billion-laughs security tests at lines 163 and 180 are the most serious: they assert the parser rejects hostile XML supplied as a Python str, not as real bytes arriving over a real socket with a real Content-Length, which is how the attack actually presents.",
            "real_replacement": "Boot a real server, register the real WSDL service, and POST real SOAP envelopes (including the XXE and entity-expansion payloads) as real bytes over real HTTP. Assert on the real SOAP fault envelope returned on the wire — that is the contract a real SOAP client speaks."
          },
          {
            "file": "tests/test_response_autoserialize.py",
            "line": 12,
            "shape": "class _Model (duck-typed to_dict) and class _Result (line 22, duck-typed records/to_array)",
            "stands_in_for": "a real ORM model and a real DatabaseResult",
            "verdict": "VIOLATION",
            "reason": "The feature under test is 'response() auto-serializes ORM models and DatabaseResult'. Both are replaced by two-line duck types. If ORM.to_dict gains a required parameter (it already takes include=), or DatabaseResult changes shape, these tests keep passing while every route returning a model breaks.",
            "real_replacement": "Zero-cost fix with real objects: bind a real Database('sqlite::memory:') (or real Postgres 55432), define a real ORM subclass, create_table(), save a row, and pass the REAL model to Response()(...). For the result case pass a real db.fetch('SELECT ...') DatabaseResult. Also covers list-of-models."
          },
          {
            "file": "tests/test_env_defaults.py",
            "line": 67,
            "shape": "class FakeResponse (captures header calls) and class FakeRequest (line 71, fixed headers dict)",
            "stands_in_for": "the framework Response and Request",
            "verdict": "VIOLATION",
            "reason": "CorsMiddleware.apply is called with two throwaway classes and the assertion reads a dict the fake populated. Whether the real Response actually emits Access-Control-Allow-Headers on the wire is not shown — and CORS is a security control where emitting vs not emitting is the whole point (ADR-0018 changed the default to deny).",
            "real_replacement": "Boot a real server with TINA4_CORS_ORIGINS/TINA4_CORS_HEADERS set, send a real cross-origin request (real Origin header) and assert the real Access-Control-Allow-Headers on the real response. tests/test_cors_policy_conformance.py is the right neighbouring pattern."
          },
          {
            "file": "tests/test_frond_live_push.py",
            "line": 14,
            "shape": "class _CaptureWriter — write()/drain()/close()/get_extra_info(), passed where the asyncio StreamWriter goes",
            "stands_in_for": "a real TCP socket under WebSocketConnection",
            "verdict": "VIOLATION",
            "reason": "The module docstring argues 'I/O redirection ... no collaborator is mocked'. It is an in-test object substituted for the socket transport, which is a real collaborator by name in the rule. Frame bytes are asserted from a bytearray the fake filled, so a frame the kernel would reject, or backpressure/drain behaviour, is never exercised. This is the clearest 'argued into EXEMPT' case in the repo.",
            "real_replacement": "asyncio.start_server on 127.0.0.1:0; build WebSocketConnection from the real accepted reader/writer; call push_live; then READ the real RFC-6455 frame bytes off the real client socket and decode them. Same assertions, real transport, roughly the same number of lines."
          },
          {
            "file": "tests/test_queue_backends.py",
            "line": 210,
            "shape": "backend.enqueue = lambda topic, msg: seen.update(...) — real method overwritten on a real KafkaBackend",
            "stands_in_for": "the real Kafka produce path",
            "verdict": "VIOLATION",
            "reason": "The in-test comment says 'no producer mock, we intercept the connector's own enqueue' — intercepting the method IS the double. This is the one residual double in a file whose header correctly boasts that all MagicMock pika/confluent/pymongo classes were deleted. Dead-letter routing is the exact feature class that shipped broken in Node for two releases.",
            "real_replacement": "Kafka is UP at 127.0.0.1:9092. Call the real dead_letter('orders', {...}) on a real KafkaBackend and then CONSUME from the real 'orders.dead_letter' topic, asserting the message body arrived. That proves both the naming and that the produce actually worked."
          },
          {
            "file": "tests/test_file_upload.py",
            "line": 101,
            "shape": "monkeypatch.setattr(req_mod, \"TINA4_MAX_UPLOAD_SIZE\", 10) — module constant overwritten",
            "stands_in_for": "the real TINA4_MAX_UPLOAD_SIZE configuration path (env var read at import)",
            "verdict": "VIOLATION",
            "reason": "MEASURED, not inferred. tina4_python/core/request.py:10 binds the constant at IMPORT time, so the sibling test_undersized_accepted's monkeypatch.setenv is a NO-OP. I proved it: `TINA4_MAX_UPLOAD_SIZE=10 pytest tests/test_file_upload.py::TestMaxUploadSize` -> test_undersized_accepted FAILS with PayloadTooLarge (10 bytes), while it passes normally only because the ambient default is large. So the pair is: one test that patches around the real config path, and one false-green test that appears to set the env var but does not. TINA4_MAX_UPLOAD_SIZE has never been proven readable from the environment.",
            "real_replacement": "Set the env var in the REAL process environment before the framework loads it — boot a child server (conftest.boot_child_server) with env TINA4_MAX_UPLOAD_SIZE=10 and POST a real oversized multipart body over real HTTP, asserting the real 413/PayloadTooLarge; then a second child with a large limit asserting acceptance. Separately, this is a real framework finding worth fixing: read the limit at use-time (or via a resolve_config accessor) instead of import-time, otherwise the documented env var does not work in any process that imported the module first."
          },
          {
            "file": "tests/test_database.py",
            "line": 292,
            "shape": "ns = type(\"DatabaseStub\", (), {\"url\": url})() with Database._connection_path(ns) called unbound",
            "stands_in_for": "a real Database instance",
            "verdict": "VIOLATION",
            "reason": "An anonymous stub object has the method bound onto it to avoid the real constructor. The docstring admits why: 'the constructor path depends on whether the resolved path is writable'. That writability branch is the actual root cause being regressed (the macOS 'Read-only file system: /data' crash) and it is precisely what the stub skips.",
            "real_replacement": "Construct a REAL Database under monkeypatch.chdir(tmp_path) and assert the real resolved path / that the sqlite file is really created there. For the read-only branch, create a real directory and chmod it 0o500 (a real permission error), then assert the real behaviour — that is the genuine reproduction of the reported crash."
          },
          {
            "file": "tests/test_env_vars.py",
            "line": 416,
            "shape": "class FakeORM with __name__ and _fields = {}, passed to GraphQL().auto_register()",
            "stands_in_for": "a real ORM model class",
            "verdict": "VIOLATION",
            "reason": "An in-test class passed where a real ORM model goes. auto_register returning 0 is asserted against a class that has no real fields, so a registration bug that only manifests on a model with actual Field objects would not be caught by the negative test.",
            "real_replacement": "Define a real ORM subclass with real Field objects (bound to a real sqlite/postgres Database) and assert auto_register returns 0 when TINA4_GRAPHQL_AUTO_SCHEMA=false and non-zero when true. Trivial change, real coverage."
          },
          {
            "file": "tests/test_orm.py",
            "line": 223,
            "shape": "class _Dummy: pass, passed as ForeignKeyField(to=_Dummy)",
            "stands_in_for": "a real related ORM model class",
            "verdict": "VIOLATION",
            "reason": "An empty in-test class handed to the framework where a real model is expected. The assertions (validate(42)==42) happen to avoid touching it, but the field is constructed with a target that has no primary key, no table and no fields — so the test locks in behaviour for a configuration that cannot exist in a real app.",
            "real_replacement": "Point ForeignKeyField at a real ORM subclass with a real IntegerField primary key (the file already defines User/Post/Comment/Profile at lines 12-47 — reuse one)."
          },
          {
            "file": "tests/test_firebird_reconnect.py",
            "line": 38,
            "shape": "no double — parametrized calls to FirebirdAdapter._is_dead_connection(Exception(msg))",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "A pure predicate over an exception message string. No dependency is contacted and no double is constructed anywhere in these two parametrized tests (lines 27-50). This is the pure-function carve-out, not a mock test.",
            "real_replacement": "n/a - keep as is. (Ideally seed the parametrize list from message strings captured from the real driver during the live reconnect test, so the matcher cannot drift from reality.)"
          },
          {
            "file": "tests/test_migration_footguns.py",
            "line": 31,
            "shape": "no double — _split_statements / _parse_set_term / _migration_sort_key / _normalize_quotes over string literals",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "SQL text splitting and sort-key computation are pure string functions. No database is involved and no double is constructed for these tests. Only the _should_skip_create_table tests in this file (which use _FakeDB) are violations.",
            "real_replacement": "n/a - keep as is."
          },
          {
            "file": "tests/test_api.py",
            "line": 21,
            "shape": "class _RecordingServer wrapping a real http.server.BaseHTTPRequestHandler on 127.0.0.1",
            "stands_in_for": "nothing - it IS a real HTTP service",
            "verdict": "EXEMPT",
            "reason": "This is a real HTTP server on a real socket; the Api client makes real urllib calls to it. Recording inbound requests is observation of a real interaction, not substitution. This is the correct pattern and the right model for fixing the WSDL/dev-admin/MCP violations above.",
            "real_replacement": "n/a - this is already the real-dependency pattern."
          },
          {
            "file": "tests/test_write_path_contract.py",
            "line": 90,
            "shape": "class ContractConnection wrapping real Database instances, opening a SECOND real connection",
            "stands_in_for": "nothing - real database engines",
            "verdict": "EXEMPT",
            "reason": "Real engines, real connections, and deliberately a second connection so a write visible only on the writing handle is caught. Exemplary — this is what the mocked DB tests should look like.",
            "real_replacement": "n/a - already real."
          },
          {
            "file": "tests/test_queue_backends.py",
            "line": 1,
            "shape": "live RabbitMQ / Kafka / MongoDB with _reachable() skip guards",
            "stands_in_for": "nothing - real brokers",
            "verdict": "EXEMPT",
            "reason": "Header documents that the MagicMock pika/confluent/pymongo classes were deleted and replaced with real-broker tests, skip-guarded on reachability. RabbitMQ 5672, Kafka 9092 and Mongo 27017 are all UP so these run. The single residual double is backend.enqueue at line 210, reported separately.",
            "real_replacement": "n/a - already real."
          },
          {
            "file": "tests/test_messenger.py",
            "line": 1,
            "shape": "live GreenMail SMTP 3025 / IMAP 3143, failure path aimed at a real closed port 127.0.0.1:59999",
            "stands_in_for": "nothing - real SMTP and IMAP services",
            "verdict": "EXEMPT",
            "reason": "The reference implementation of the rule: real send over a real SMTP socket, real read-back over real IMAP, and the failure case driven by a REAL connection refusal rather than a simulated exception. GreenMail verified UP on both 3025 and 3143.",
            "real_replacement": "n/a - already real; use this file as the template when fixing test_session_backend_failure.py."
          },
          {
            "file": "tests/test_dev_admin.py",
            "line": 159,
            "shape": "class TestBrokenTracker with BrokenTracker._broken_dir pointed at a real tempfile.mkdtemp()",
            "stands_in_for": "nothing - the real filesystem",
            "verdict": "EXEMPT",
            "reason": "Redirecting a path to a real temp directory is real configuration against the real filesystem, not a double — records are genuinely written and read back. (The mock_req/mock_resp fixtures elsewhere in this same file ARE violations, reported above.)",
            "real_replacement": "n/a."
          },
          {
            "file": "tests/test_background_tasks.py",
            "line": 24,
            "shape": "class _ConcurrencyProbe — a real callable doing real blocking work, counting in-flight copies",
            "stands_in_for": "nothing - it is the workload, not a dependency",
            "verdict": "EXEMPT",
            "reason": "The probe is the callback the real background_tick_loop is supposed to schedule — it is the SUT's input, not a substitute for a collaborator. It performs real blocking work and the real loop runs.",
            "real_replacement": "n/a."
          },
          {
            "file": "tests/test_csrf_middleware.py",
            "line": 56,
            "shape": "class _Result — a value object holding the REAL response's status_code and content",
            "stands_in_for": "nothing - it wraps real output",
            "verdict": "EXEMPT",
            "reason": "Explicitly 'the outcome of running CsrfMiddleware through the real before-dispatcher'. It reads fields off the real Response and parses the real error envelope. An assertion helper over real output is not a double.",
            "real_replacement": "n/a."
          },
          {
            "file": "tests/test_middleware_pipeline_characterisation.py",
            "line": 55,
            "shape": "in-test middleware classes (OrderedHooks, DenyReturningPair, ThrowingBefore, SubclassHooks, ...)",
            "stands_in_for": "nothing - application code the framework is designed to accept",
            "verdict": "EXEMPT",
            "reason": "These are the user-written middleware the pipeline exists to run — the SUT's input, not a substitute for something the framework depends on. The real registration, ordering and dispatch machinery executes. Same reasoning covers the Mw classes in test_middleware_events.py, NoopMw in test_middleware_parity.py, the Test subclasses in test_parity_group_c.py / test_test_module.py, and the in-test ORM models throughout the suite.",
            "real_replacement": "n/a - supplying real application code to a real framework is not mocking."
          },
          {
            "file": "tests/test_log.py",
            "line": 404,
            "shape": "monkeypatch.setattr(Log, \"_format_mode\", \"json\")",
            "stands_in_for": "nothing - a real config value on the object under test",
            "verdict": "EXEMPT",
            "reason": "Log is the SUT here, not a collaborator, and 'json' is the real value the real code path consumes; no behaviour is replaced. Distinct from test_session_backend_failure.py:69, which replaces Log.error's implementation. Flagging only as a style note: Log.configure() is the public path and would be preferable to poking a private attribute.",
            "real_replacement": "n/a - though prefer Log.configure(format='json') so the real configuration path is the one exercised."
          },
          {
            "file": "tests/test_test_module.py",
            "line": 294,
            "shape": "class _LifecycleSpy — a list accumulator appended to by real Test subclasses",
            "stands_in_for": "nothing - test-local state",
            "verdict": "EXEMPT",
            "reason": "Despite the name it substitutes for nothing: the real Test base class and the real runner execute, and the lifecycle hooks append to a plain list. It is an observation buffer, not a stand-in for a collaborator.",
            "real_replacement": "n/a."
          },
          {
            "file": "tests/test_session_handlers.py",
            "line": 557,
            "shape": "TestRedisIntegration / TestMongoDBIntegration / TestValkeyIntegration — real handlers, real servers, _reachable() skip guards",
            "stands_in_for": "nothing - real Redis, Mongo, Valkey",
            "verdict": "EXEMPT",
            "reason": "These three classes at lines 557/576/595 are correct: real write->read->destroy round-trips against the live services, gated on reachability (and hard-failed by TINA4_REQUIRE_SERVICES in CI). Also EXEMPT in this file: TestDatabaseSessionHandler (line 426) and TestResolveHandlerDatabase (line 478), which use a real sqlite::memory: Database. They are the replacement target for the five MagicMock classes.",
            "real_replacement": "n/a - extend these to absorb the assertions currently made against MagicMock."
          }
        ],
        "search_patterns_used": [
          "rg -n \"MagicMock\" --glob '*.py' tests/  (5 files, 25 occurrences)",
          "rg -n \"unittest\\.mock|from unittest import mock|^import mock\" --glob '*.py' tests/  (6 files)",
          "rg -n \"@patch|[^.\\w]patch\\(|mock\\.patch|patch\\.object\" --glob '*.py' tests/  (all hits were Tina4's HTTP @patch ROUTE decorator, not mock.patch — no false positive kept)",
          "rg -o \"monkeypatch\\.\\w+\" --glob '*.py' tests/ | sort | uniq -c   -> setenv 478, delenv 141, chdir 25, setattr 15, syspath_prepend 2, setitem 2",
          "rg -n \"monkeypatch\\.setattr\" --glob '*.py' tests/  (8 files, 15 sites — the real double surface)",
          "rg -n \"patch\\.dict\" --glob '*.py' tests/  (1 file, 3 sites)",
          "rg -n \"SimpleNamespace\" --glob '*.py' tests/  (2 hits, both in a docstring/assertion — NOT used as a double)",
          "rg -n \"^\\\\s*class (?!Test)\\\\w+\" -P --glob '*.py' tests/  (192 non-Test class definitions, each triaged)",
          "rg -n \"^\\\\s*class \\\\w*(Fake|Stub|Dummy|Mock|Raising|Broken|Failing|Bad|Null|Noop|NoOp|Spy|Recording|Capturing|Exploding|Dead|Sham)\\\\w*\" --glob '*.py' tests/",
          "rg -n 'type\\(\"?\\w+\"?, \\(\\)' --glob '*.py' tests/  (anonymous type() doubles — found the dev_admin Req and ~20 wsdl R doubles)",
          "rg -n \"def (fake_|stub_|_fake|_stub|mock_)\\\\w*\" --glob '*.py' tests/",
          "rg -n \"^\\\\s*\\\\w+\\\\.\\\\w+ = (lambda|fake|stub|mock)\" --glob '*.py' tests/  (found backend.enqueue=lambda, server.handle=fake_handle, a._open=lambda)",
          "per-file filter: rg -o \"monkeypatch\\\\.\\\\w+\" tests/<f> | grep -v 'setenv|delenv|chdir|syspath_prepend'  — confirmed the 11 highest-monkeypatch files are env/cwd only"
        ],
        "control_search": "CONTROL 1: `rg -o \"def test_\" --glob '*.py' tests/` -> 4089 hits across 233 of 234 files. CONTROL 2: `rg -o \"import pytest\" --glob '*.py' tests/` -> 178 hits in 178 files. CONTROL 3 (double-specific, known-present from the task brief): `rg -o \"MagicMock\" --glob '*.py' tests/` -> 25 hits in 5 files, including the tests/test_session_handlers.py MagicMock Redis/Valkey you named. All globs were QUOTED ('*.py') and run through ripgrep 14.1.1, avoiding the zsh unquoted-glob failure mode that mimics \"no matches\"; every variable was quoted so no word-splitting was relied on. A non-empty control on all three patterns means the empty results (e.g. SimpleNamespace-as-double = 0, mock.patch = 0) are real absences, not broken searches.",
        "total_test_files_scanned": 234,
        "could_not_verify": [
          "I did NOT run the full 4,113-test suite. Only targeted runs: tests/test_file_upload.py::TestMaxUploadSize (the false-green proof) and collect-only counts. So I cannot state which of these violating tests currently pass or fail in a full green run.",
          "Firebird: the port is open (127.0.0.1:3050 accepted a TCP connection) but I did NOT authenticate or run a query, so I cannot confirm a usable database/credentials exist there. Project memory says Firebird is excluded from CI by design; the reconnect fix needs a real Firebird target, so confirm usability before committing to that plan.",
          "MSSQL 1433, RabbitMQ 5672 and Kafka 9092 were confirmed only by TCP connect, not by protocol handshake or auth. A listening port is not a working service.",
          "I did NOT verify that the psycopg2 / mysql-connector / pymssql / pymongo / redis client packages are installed in this .venv. Several 'use the real service' recommendations assume `uv sync --extra test`; without the client library the tests will skip rather than run, which must be a LOUD skip naming host and port.",
          "tests/test_dev_admin.py and tests/test_wsdl.py: pytest --collect-only output was truncated by my grep, so I have exact per-double line numbers but not exact per-file test counts. The 75 figure for dev_admin is a count of mock_req/mock_resp REFERENCES (rg -c), not of test functions.",
          "I did not confirm whether tina4-php, tina4-nodejs and tina4-ruby carry the same doubles. The prompt names a live tina4-ruby violation (spec/security_hardening_spec.rb RaisingHandler + expect(Tina4::Log).to receive(:error)); per the parity rule every fix here almost certainly has a sibling in the other three, but I scanned only tina4-python/tests as instructed.",
          "I could not determine whether the MagicMock session-handler removal on feature/audit-auth is a clean cherry-pick onto v3 — I only confirmed that v3 @ fb6fcb2 still contains all five MagicMock clients.",
          "The claim that the WSDL XXE/billion-laughs tests would behave differently over a real socket is reasoned from how the parser is invoked, not measured — I did not build the real-HTTP version to compare."
        ]
      },
      {
        "framework": "PHPUnit 11.5.55 on PHP 8.5.7, tina4-php branch v3 @ e5e00b28 (\"Confine response.file() to a root in all four\"). Runs verified with ./vendor/bin/phpunit --no-coverage against /Users/andrevanzuydam/IdeaProjects/tina4-php/phpunit.xml. Service ports re-verified UP on 127.0.0.1 right now: redis 6379, valkey 6380, redis-ish 6381, memcached 11211, Mongo 27017, Postgres 55432, MySQL 3306. Port 59999 re-verified CLOSED (usable as a real dead port). NOT present on this host: MSSQL, Firebird.",
        "control_search": "Control string 'function test' (known present) searched with /usr/bin/grep -rn --include='*.php' over tests/ -> 4266 hits. Second control 'class ' -> 542 hits. NOTE ON MEASUREMENT: the default `grep` on this host is a ugrep shim that emits \"warning: --include=*.php: No such file or directory\" and SILENTLY DROPS the include filter — quoting did not fix it. Every count reported here was re-run with /usr/bin/grep explicitly, which honours --include and returns the same 4266 control. Zero-result searches below are therefore trustworthy.",
        "total_test_files_scanned": 256,
        "search_patterns_used": [
          "createMock -> 6 hits (ALL 6 are the test's own helper createMockRequest; zero real PHPUnit createMock)",
          "getMockBuilder -> 0",
          "prophesize -> 0",
          "createStub -> 0",
          "createPartialMock -> 0",
          "onlyMethods -> 0",
          "createConfiguredMock -> 0",
          "getMockForAbstractClass -> 0",
          "willReturn -> 0",
          "expects( -> 0",
          "MockObject -> 0",
          "Prophecy -> 0",
          "setMethods -> 0",
          "addMethods -> 0",
          "returnValue -> 0",
          "returnCallback -> 0",
          "stream_wrapper_register -> 0",
          "uopz_ -> 0",
          "runkit_ -> 0",
          "class_alias -> 2 (both in comments saying there is NO class_alias)",
          "regex ^\\s*(final |abstract )?class \\w+ implements -> 1 hit",
          "regex ^\\s*(final |abstract )?class \\w+ extends  (minus TestCase) -> 74 hits, all classified",
          "regex ^\\s*(final |abstract )?class \\w+\\s*\\{?$ (plain in-test classes) -> 66 hits, all classified",
          "new class -> 11 hits, all classified",
          "new class ... implements -> 0",
          "^\\s*(interface|trait) \\w+ -> 1 hit (PipelineHookTrait, middleware fixture)",
          "setValue(|setAccessible|Closure::bind|ReflectionMethod -> 67 hits across 13 files, each inspected",
          "case-insensitive simulat|pretend|stand[- ]in|duck[- ]typed|fake -> 60+ hits triaged",
          "identifier scan: Fake|Stub|Mock|Dummy|Noop|Dud|InMemory|Recording|Capturing|Throwing|Failing|Flaky|Broken|Testable|Scripted"
        ],
        "hits": [
          {
            "file": "tests/ApiTest.php",
            "line": 28,
            "shape": "class ScriptedApi extends Api — overrides the protected attempt() network seam to replay a queue of canned result arrays; counts attempts. Used at lines 258, 269, 285, 300, 316, 328, 343.",
            "stands_in_for": "a real HTTP service (Tina4\\Api's actual socket/stream-wrapper network call)",
            "verdict": "VIOLATION",
            "reason": "This is the textbook forbidden shape: a subclass that overrides one method to force a branch, standing in for the network. The file's own docblock admits it — 'mirroring how the Python suite patches _open. No real wire traffic.' Every retry/backoff assertion is against a hand-written array, so nothing proves Api actually retries a real 503, actually honours the backoff between real attempts, or actually surfaces a real connection error. This is precisely the shape that let the Node Mongo queue ship with no ack path. Damning detail: the SAME repo already has the correct pattern one file over — tests/ApiTransferTest.php:224 injects a transport that does REAL socket I/O and its docblock states 'the seam is only proven by replacing the network with another REAL network call, per the framework no-mock rule'. ApiTest predates and contradicts it.",
            "real_replacement": "Delete ScriptedApi entirely and use tests/TestServer.php the way ApiTransferTest::setUpBeforeClass does (boots a real PHP built-in server on a free port). (a) RETRY-THEN-SUCCEED: add a route to tests/fixtures/api_transfer_server.php that returns 503 for the first N requests and 200 afterwards, keeping the counter in a per-run temp file; point a real Api at it with maxRetries=2 and assert both the final 200 AND the server-side hit count of 3 — that proves real retries over real sockets. (b) EXHAUSTED-RETRIES / CONNECTION ERROR: point a real Api at 127.0.0.1:59999 (re-verified CLOSED on this host) with maxRetries=2 and assert it made 3 real connection attempts and returned a real error string — a genuinely refused TCP connection, not a canned ['error'=>...]. (c) BACKOFF: wrap (b) in hrtime() and assert the elapsed wall time is at least the sum of the real backoff sleeps. Never override attempt()."
          },
          {
            "file": "tests/DbContractAbcTest.php",
            "line": 374,
            "shape": "class FlakyCommitAdapter implements DatabaseAdapter — a full 18-method decorator whose commit() throws a DatabaseException once, then delegates. Injected over the real adapter via ReflectionProperty at line 259 (helper databaseWithAdapter, line 351). Used by testCommitFailureRaisesRetainsPinThenRollbackCleansUp (line 250).",
            "stands_in_for": "the database engine's real COMMIT (a real SQLite/Postgres connection)",
            "verdict": "VIOLATION",
            "reason": "The class docblock states outright that it is 'the PHP analogue of the Python test's monkeypatched adapter.commit'. A monkeypatch is named in the rule verbatim. The charitable read is that everything else delegates to a live adapter so 'the transaction really runs' — that is exactly the 'supplement, not substitute' argument the rule says does not exist. The assertions that matter (commit() re-raises, getError() is populated, the transaction pin is RETAINED, a follow-up rollback clears it) are all driven by a hand-thrown exception, so nothing proves the pin survives a real driver-level commit failure or that a real rollback on a real half-committed connection cleans up. That is the exact class of bug — connection-state handling after a failed write — that a synthetic throw cannot reach.",
            "real_replacement": "Drive a genuine COMMIT-time failure. Best on this host: the live Postgres at 127.0.0.1:55432 (verified UP, creds tina4/tina4 per tests/PgTestEnv.php). Postgres fails DEFERRED constraints at COMMIT, not at INSERT — so CREATE TABLE t (id int); ALTER TABLE t ADD CONSTRAINT u UNIQUE (id) DEFERRABLE INITIALLY DEFERRED; then START TRANSACTION, insert the same id twice (both succeed), then call $db->commit() — the real server raises a real unique_violation at commit time. Assert getError(), pin retention, then a real rollback and pin release, all on the real connection. Portable fallback with no server: on a real SQLite FILE db (not :memory:), open a SECOND real connection and hold BEGIN IMMEDIATE, set busy_timeout=50 on the first — the first connection's COMMIT then genuinely fails with SQLITE_BUSY. Either way the failure comes from the engine, and the whole 18-method decorator disappears."
          },
          {
            "file": "tests/SessionBackendFailurePolicyTest.php",
            "line": 40,
            "shape": "class ThrowingSessionHandler extends DatabaseSessionHandler — overrides read/write/destroy/gc to unconditionally throw RuntimeException('backend unreachable'). Injected into Session's private $dbHandler via ReflectionProperty (helper sessionWith, line 133). Drives 5+ tests; I watched the fabricated errors print during the run.",
            "stands_in_for": "a session backend (a real database connection behind DatabaseSessionHandler)",
            "verdict": "VIOLATION",
            "reason": "An in-test subclass overriding every method to force the failure branch. The docblock says it 'simulates an unreachable backend' — simulating a dependency's failure with a subclass is the rule's central prohibition, and 'unreachable backends are hard to reproduce' is explicitly denied as an exception. Credit where due: the log assertions here are CORRECT — the test writes to a real log dir and greps the real tina4.log/error.log file, not a logger message expectation. So only the handler needs replacing, not the assertion style. But because the throw is synthetic, nothing proves the degrade path survives what a REAL dead backend does: a connect timeout rather than an instant throw, a PDOException subtype rather than RuntimeException, a half-open socket, or a driver that returns false instead of raising.",
            "real_replacement": "The correct pattern already exists in this repo — tests/SessionMemcachedTest.php:155 and :166 do `new MemcachedSessionHandler(['host' => '127.0.0.1', 'port' => 59999, 'timeout' => 1])` and assert the real refusal. Copy it: construct a REAL DatabaseSessionHandler whose Database points at 127.0.0.1:59999 (re-verified CLOSED) so the real PDO/pgsql connect genuinely refuses, and assert Session::start()/save() degrade + the real log file gets the ERROR line. For a mid-flight failure (connection established, then the store dies) — the more dangerous case — connect for real to Postgres 127.0.0.1:55432, let the handler create its session table, then DROP TABLE the session table (or REVOKE SELECT/INSERT from the test role) and call read/write/destroy/gc: real SQL errors from a real server, different every method. Keep the existing real-log-file assertions verbatim; they are already right."
          },
          {
            "file": "tests/SessionBackendFailurePolicyTest.php",
            "line": 67,
            "shape": "class EmptyHealthySessionHandler extends DatabaseSessionHandler — overrides read() to return null and write()/destroy() to silently succeed",
            "stands_in_for": "a session backend that is reachable but has no stored row",
            "verdict": "VIOLATION",
            "reason": "Being strict: this is an in-test class overriding methods to fabricate a collaborator's response, which is a stub even though the fabricated response is a success rather than a failure. It is also the LEAST defensible of the pair, because 'a healthy backend with no row in it' needs no simulation whatsoever — it is a real empty table. The invariant it guards (empty is not a failure, so ZERO errors are logged) is exactly the kind of thing that would silently rot if the real handler ever started logging on a genuine empty read, and this stub can never notice because it never runs the real read.",
            "real_replacement": "Delete the class. Construct a REAL DatabaseSessionHandler over the live Postgres at 127.0.0.1:55432 (or a real SQLite file), let it create/migrate its session table, insert NOTHING, and call Session::start('some-id-that-does-not-exist'). The real read returns no row without raising, which is the exact condition under test. Then assert errorLogCount() === 0 against the real error.log the test already reads. For the write/destroy legs, let them really write to and really delete from that table and assert the row's presence/absence with a real SELECT — which additionally proves the handler's SQL is correct, something the current stub actively hides."
          },
          {
            "file": "tests/MigrationFootgunsTest.php",
            "line": 26,
            "shape": "class FakeMSSQLAdapter extends \\Tina4\\Database\\MSSQLAdapter — constructor deliberately does NOT call parent::__construct() (no connection); overrides tableExists() to return a constructor-injected bool and getColumns() to return a hard-coded column list. Used at lines 307, 323, 349.",
            "stands_in_for": "a real Microsoft SQL Server engine",
            "verdict": "VIOLATION",
            "reason": "A subclass that skips its parent constructor to avoid connecting and overrides two methods to feed the code under test a scripted answer. The docblock's justification — 'it is instanceof MSSQLAdapter, which is all the CREATE-TABLE idempotency guard checks' — is a self-fulfilling test: it asserts that a guard keyed on instanceof fires when handed an instanceof, and proves nothing about whether real MSSQL's tableExists() returns true for 'users' or for the bracketed '[Things]' form the test passes. Case folding, bracket/quote stripping and schema qualification are exactly where this guard breaks on a real server, and a hard-coded bool cannot reach any of it. Note the file itself shows the honest alternative in testCreateTableNotSkippedOnSqliteLeftToIfNotExists (line ~340), which uses a REAL SQLite3Adapter with a REAL CREATE TABLE.",
            "real_replacement": "Use the real MSSQLAdapter against a live SQL Server and SKIP LOUDLY naming host and port when it is absent — the gate already exists in this repo at tests/MySQLMSSQLLiveTest.php:242, which emits 'MSSQL not reachable at %s:%d — skip integration test' and is picked up by the TINA4_REQUIRE_SERVICES gate (tests/RequireServicesGateTest.php) so CI fails rather than false-greens. Concretely: connect, CREATE TABLE users for real, assert shouldSkipCreateTable() returns a reason naming users; repeat with the real bracketed [Things] and quoted forms; then DROP TABLE and assert it returns null. MSSQL is NOT running on this host (only 6379/6380/6381/11211/27017/55432/3306), so on this machine the honest outcome is a loud skip — which is the correct behaviour under the rule, not a reason to keep the fake."
          },
          {
            "file": "tests/MigrationFootgunsTest.php",
            "line": 59,
            "shape": "class FakeFirebirdAdapter extends \\Tina4\\Database\\FirebirdAdapter — same trick: empty constructor, no connection, overridden tableExists()/getColumns(). Used at lines 315, 331.",
            "stands_in_for": "a real Firebird engine",
            "verdict": "VIOLATION",
            "reason": "Identical shape and identical defect to FakeMSSQLAdapter. Firebird is the worst engine to fake here because its identifier semantics are the whole point of the test: unquoted names fold to UPPERCASE while quoted \"Orders\" stays mixed-case, so whether tableExists('Orders') matches depends entirely on real server-side folding that a hard-coded bool bypasses. The test asserts the reason string contains 'Orders' and passes because the fake said true — on a real Firebird the lookup could miss entirely and the guard would silently not fire. Project history is directly on point: per the Firebird ORM work, native CI against a real FB 5.0.2 found three bugs that the non-native tests had not.",
            "real_replacement": "Use the real FirebirdAdapter against a live Firebird and skip loudly when absent — the gate already exists at tests/FirebirdOrmWriteTest.php:41/45 ('ext-interbase not installed' / 'Set TINA4_TEST_FIREBIRD_URL to run the live Firebird ORM write test'), and the repo already runs live-Firebird CI. Concretely: against a real DB, CREATE TABLE users (unquoted, folds to USERS) and CREATE TABLE \"Orders\" (quoted, stays mixed) for real, then assert shouldSkipCreateTable() fires for both real spellings and does NOT fire for a table that was never created. Firebird is not on this host, so it must skip loudly naming the URL — never fall back to the subclass."
          },
          {
            "file": "tests/AuthV3Test.php",
            "line": 648,
            "shape": "private function createMockRequest(string $authHeader): object { return new class($authHeader) { ... public function header(string $name): ?string ... } } — an anonymous class exposing only header(). Used at lines 414, 427, 436, 445, 454.",
            "stands_in_for": "Tina4\\Request (the real HTTP request object the auth middleware receives)",
            "verdict": "VIOLATION",
            "reason": "An in-test anonymous object injected in place of a real collaborator, and the only one in this suite that matches the search shape by name. All five Auth::middleware() tests — valid token, expired token, missing token, wrong Basic scheme, malformed token — run against a fabricated one-method object. Its header() lowercases the name and maps '' to null; if the real Tina4\\Request normalises headers differently (case, dashes vs underscores, a headers array vs a header() method, a missing header returning '' instead of null), every one of these five tests stays green while the middleware fails on real traffic. This is the auth gate, so the blast radius is authentication bypass — the highest-stakes place in the codebase to be asserting against a fake.",
            "real_replacement": "Use the real Tina4\\Request; the repo already constructs real ones — tests/DevReloadWsTest.php:100 does Request::create('POST', '/__dev/api/reload', null, $body). Build a real Request carrying a real Authorization header and pass it to Auth::middleware() for all five cases. Stronger still, and available here: boot a real server with tests/TestServer.php (as ApiTransferTest does), register a ->secure() route, and issue five REAL HTTP requests — valid Bearer, expired Bearer, no header at all, 'Basic dXNlcjpwYXNz', and 'Bearer invalid.token.here' — asserting 200 vs 401 off the wire. That exercises the real header parsing, the real dispatch path and the real auth gate together, which is the contract a real client actually speaks. Note tests/AuthV3Test.php:648 is the last surviving fake in a file whose other tests (authenticateRequest, lines 461+) already pass real header arrays — so the fix is mostly deleting the helper."
          },
          {
            "file": "tests/ResponseAutoSerializeTest.php",
            "line": 17,
            "shape": "private function fakeModel(array $data): object { return new class($data) { public function toDict(): array { return $this->data; } }; } — anonymous class, docblock 'A duck-typed ORM model'. Used at lines 37, 44, 56.",
            "stands_in_for": "Tina4\\ORM (a real model)",
            "verdict": "VIOLATION",
            "reason": "An in-test object constructed purely to be passed into the SUT in place of the real collaborator — the docblock says 'duck-typed' out loud. The test claims to prove that Response auto-serializes an ORM model without the caller calling toDict() by hand, but it only proves Response calls toDict() on anything that has one. It cannot catch the failure that actually matters: a real Tina4\\ORM whose toDict() emits different keys, omits unset/null columns, stringifies integers, or returns nested field objects rather than scalars. Given the project's own history with ORM null-for-unset and column-case behaviour, that gap is not hypothetical.",
            "real_replacement": "Use a real Tina4\\ORM subclass against a real database — the repo has ~60 of these already (e.g. tests/OrmContractsTest.php:37 ContractUser, tests/OrmJsonFieldTest.php:18 JsonDoc). Declare a small model, bind it to a real SQLite file DB or the live Postgres at 127.0.0.1:55432, INSERT a real row, load it back through the real ORM, and hand THAT to (new Response())($model). Assert the decoded JSON equals the real row. Do the same for the list case with two really-loaded models. That proves the real toDict() shape flows through Response, which is the actual contract."
          },
          {
            "file": "tests/ResponseAutoSerializeTest.php",
            "line": 26,
            "shape": "private function fakeResult(array $rows): object { return new class($rows) { public array $records; public function toArray(): array { return $this->records; } }; } — anonymous class, docblock 'A duck-typed DatabaseResult'. Used at line 50.",
            "stands_in_for": "Tina4\\Database\\DatabaseResult (the real object every read returns)",
            "verdict": "VIOLATION",
            "reason": "Same shape, and worse in consequence, because DatabaseResult is a live contract this project has changed recently: per release 3.13.86, insert/update/delete were made to return DatabaseResult as a breaking change. A hand-rolled two-member anonymous class hard-codes the exact ->records/->toArray() pair Response happens to touch today, so any drift in the REAL DatabaseResult (extra state, a renamed accessor, records holding row objects rather than arrays, a lazily-populated records) leaves this test green while Response serializes wrong or fatals in production. tests/DatabaseResultTest.php exercises the real class; this test declines to use it.",
            "real_replacement": "Run a real query and hand Response the real DatabaseResult it returns. Against a real SQLite file DB or the live Postgres at 127.0.0.1:55432: CREATE TABLE, INSERT two real rows, then $result = $db->fetch('SELECT id FROM t ORDER BY id') and assert json_decode((new Response())($result)->getBody(), true) === [['id'=>1],['id'=>2]]. Because insert/update/delete now also return DatabaseResult, add a leg that passes the REAL result of a write straight into Response — that is the path an application actually takes and the one no current test covers with a real object."
          },
          {
            "file": "tests/WebSocketV3Test.php",
            "line": 675,
            "shape": "class TestableWebSocket extends WebSocket — adds injectClient()/getClientsRaw() that use Closure::bind to write fabricated client records straight into the private $clients array, paired with makeSocket() returning fopen('php://memory','r+'). Drives the whole WebSocketRoomsTest class (setUp line 705).",
            "stands_in_for": "a real WebSocket client connection (a real network socket) and the real accept/handshake path",
            "verdict": "VIOLATION",
            "reason": "Two substitutions at once. First, php://memory is not a socket: it cannot be closed by a peer, cannot refuse a write, cannot go half-open, and never returns a short write — so every room operation is validated against a stream that can never fail the way a real client fails. Second, injectClient() reaches past the real registration API with Closure::bind to fabricate the client record, meaning the room tests never touch the code that actually builds that record; if the real handshake path stops populating 'rooms' or renames a key, joinRoom/leaveRoom/roomCount stay green here and break live. The docblock is candid — 'inject test clients without a live server loop'. The decisive point is that the SAME repo already does this correctly: tests/WebSocketHardeningTest.php:28 uses real stream_socket_pair() loopback sockets and its header states 'NO mocks/fakes/doubles', registering through the real public Server::registerWebSocketClient(). Two files, same subsystem, opposite standards.",
            "real_replacement": "Adopt WebSocketHardeningTest's pattern wholesale. Replace makeSocket() with stream_socket_pair(STREAM_PF_UNIX, STREAM_SOCK_STREAM, 0) — real OS sockets with a readable far end — and replace injectClient()/Closure::bind with the real public registration API (Server::registerWebSocketClient($id, $near, '/'), as WebSocketHardeningTest:470 and :654 do), deleting TestableWebSocket entirely. Then roomCount/joinRoom/leaveRoom assertions can be strengthened from 'the array says 2' to 'broadcasting to the room really wrote a frame that both far ends can read', using WebSocketHardeningTest's readFramePayload(). For the dead-client case, fclose() one far end so the write really fails at the OS level rather than being simulated. For an unreachable backplane, point a real RedisBackplane at 127.0.0.1:59999 (re-verified CLOSED) exactly as WebSocketHardeningTest:448-450 already does."
          },
          {
            "file": "tests/WebSocketHardeningTest.php",
            "line": 448,
            "shape": "ReflectionProperty repoint of a real RedisBackplane's host/port to 127.0.0.1:59999 plus useRaw=true; stream_socket_pair() for client sockets",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "Not a double, and the model the other files should copy. No in-test class substitutes for anything: the backplane is a REAL RedisBackplane that first connects and PINGs the live Redis, the failure is a REAL fsockopen refusal to a genuinely closed port (I re-verified 59999 is closed), and the client sockets are REAL OS socket pairs. The reflection calls mutate configuration on a real object rather than replacing a collaborator — the same category as backdating a timestamp. The test even documents why ext-redis had to be swapped for the raw RESP transport: phpredis keeps an already-open connection that a port repoint cannot move, so the failure would not have been real. That is the standard of rigour the rule is asking for. Listed here only so the reviewer can see it was inspected and cleared.",
            "real_replacement": "n/a - already real"
          },
          {
            "file": "tests/ApiTransferTest.php",
            "line": 224,
            "shape": "an injected transport closure (testInjectedTransportReplacesNetworkWithRealIo)",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "Looks like a seam-injection double but is not one: the injected transport performs REAL socket I/O to a second live PHP built-in server, and the Api's own base URL is pointed at a dead port so a 200 can only have come from a real network call. The suite boots two genuine servers on two free ports to make the cross-origin redirect real. This is the in-repo precedent that condemns tests/ApiTest.php:28 — same class under test, same seam, one file replaces the network with another real network call and the other replaces it with canned arrays.",
            "real_replacement": "n/a - already real"
          },
          {
            "file": "tests/MiddlewareAuthBypassTest.php",
            "line": 22,
            "shape": "class DummyOAuthMiddleware — plain in-test class with a static handle() that returns [$request, $response]",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "Named like a double but is not one. The SUT is the Router, and middleware is the Router's public extension point — user-authored application code, exactly like the route closures alongside it. It substitutes for no service, backend, socket or logger; it is an INPUT to the SUT, not a stand-in for one of the SUT's dependencies. The assertions read real Router::match() metadata (the noAuth/secure flags) with no fabricated return values anywhere. Same reasoning clears tests/CorsIntegrationTest.php:25 FakeAuthMiddleware (which does real header work and returns a real 401), the ~25 Pipeline*Mw and Mw* fixtures in MiddlewarePipelineCharacterisationTest/MiddlewareEventsTest/GlobalAfterMiddlewareTest/GlobalMiddlewareSplitTest, PipelineHookTrait, and _ParityServiceFixture/_ParityTestFixture (concrete subclasses of abstract framework base classes, i.e. the documented extension point).",
            "real_replacement": "n/a - not a double"
          },
          {
            "file": "tests/MetricsTest.php",
            "line": 140,
            "shape": "class B / class A / class Sample / class Calculator etc., ~20 of them, all inside <<<'PHP' heredoc strings",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "These match a naive class-definition grep but are not code that runs — they are PHP SOURCE TEXT fed to the metrics analyzer as input data (complexity, LOC, coupling). They substitute for no dependency; they are the fixture the pure-logic analyzer parses. Same category as tests/ModelDiscoveryTest.php:101, which writes a Broken.php that GENUINELY throws at include time (a real failure of a real file, not a simulated one), and the ~60 'class X extends ORM' declarations across the suite, which are real domain models exercised against real databases.",
            "real_replacement": "n/a - not a double"
          },
          {
            "file": "tests/SessionMemcachedTest.php",
            "line": 155,
            "shape": "new MemcachedSessionHandler(['host' => '127.0.0.1', 'port' => 59999, 'timeout' => 1]) then expectException",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "The correct way to test an unreachable backend, and the direct in-repo counter-example to tests/SessionBackendFailurePolicyTest.php:40. A REAL MemcachedSessionHandler is pointed at a REAL closed port (59999, re-verified closed) so read() and write() raise real connection errors from the real client. No subclass, no override, no fabricated exception. Its sibling testTheSessionBackendEnvVarSelectsMemcached uses reflection only to set a configuration string on a real Session and invoke a real method — configuration mutation, not substitution.",
            "real_replacement": "n/a - already real"
          }
        ],
        "could_not_verify": [
          "I did NOT run the full 256-file suite. I ran only the 7 files containing flagged doubles: ApiTest, SessionBackendFailurePolicyTest, MigrationFootgunsTest (63 tests, 127 assertions, OK) and AuthV3Test, ResponseAutoSerializeTest, WebSocketV3Test, DbContractAbcTest (145 tests, 289 assertions, OK). 208 tests total, all green, zero skips — so every double reported here is confirmed to actually execute, not dead code. Whether the other 249 files are green is UNVERIFIED here.",
          "MSSQL and Firebird are NOT running on this host (I probed only the seven ports named in the brief plus 59999). I therefore could not demonstrate that the proposed real replacements for tests/MigrationFootgunsTest.php:26 and :59 pass against a live engine — only that the repo already contains the loud-skip gate they need (tests/MySQLMSSQLLiveTest.php:242, tests/FirebirdOrmWriteTest.php:45).",
          "I did not execute any proposed replacement. Every 'real_replacement' is a design derived from patterns already proven in this repo (TestServer.php, stream_socket_pair, port 59999, live Postgres 55432) — but none of them has been written and run, so their green-ness is unverified by me.",
          "The Postgres deferred-constraint route for DbContractAbcTest is reasoned from the SQL standard's DEFERRABLE INITIALLY DEFERRED semantics, not measured. I did not open a psql session against 127.0.0.1:55432 to confirm the commit-time raise surfaces through Tina4's adapter as a DatabaseException rather than being swallowed earlier. Confirm that before relying on it; the SQLite BEGIN IMMEDIATE / busy_timeout fallback is the safer of the two.",
          "I scanned only the 256 .php files under tests/. The 9 non-.php files (tests/fixtures/*.json, *.txt) were listed but not read for embedded doubles; they appear to be data corpora (adapter_contract.json, write_path_contract.json, frond_expression_corpus.txt), and tests/fixtures/*.php server scripts are real servers, but I did not audit their contents line by line.",
          "Coverage caveat on method-level doubles: my searches were keyed to class/anonymous-class declarations, PHPUnit mock APIs, and reflection seams. A double implemented purely as a closure passed as a constructor argument with a neutral name would not necessarily surface. I checked the closure-injection sites I found (ApiTransferTest transport, Container factories, WebSocketBackplaneManager's fn() => null) and cleared them, but I cannot claim exhaustiveness for that shape."
        ]
      },
      {
        "framework": "RSpec 3.13 (rspec-core 3.13.6, rspec-mocks 3.13.8, rspec-expectations 3.13.5) on Ruby 4.0.2 arm64-darwin25, repo /Users/andrevanzuydam/IdeaProjects/tina4-ruby branch v3 @ 1784943 \"Confine response.file() to a root in all four\". spec_helper.rb:123-124 sets mock_with :rspec, verify_partial_doubles = true. The rule is verbatim in tina4-ruby/CLAUDE.md line 27 and explicitly names \"RSpec double/instance_double\" and \"monkeypatch\" as prohibited shapes.",
        "hits": [
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/csrf_middleware_spec.rb",
            "line": 32,
            "shape": "double(\"request\") plus 12 allow(req).to receive(...) calls (lines 33-47), returned from the helper def mock_request",
            "stands_in_for": "Tina4::Request - the real HTTP request object built from a Rack env",
            "verdict": "VIOLATION",
            "reason": "The whole request collaborator is synthesised, including its respond_to? answers (lines 36-41). The middleware's real branch selection keys off respond_to?(:params)/(:query)/(:session); the double hard-codes those answers, so the test can never catch a Tina4::Request whose actual surface changed. This is precisely the 'shape not behaviour' failure that shipped the Node Mongo queue bug.",
            "real_replacement": "Build the real object the same way every other spec in this repo already does: a Hash rack env with REQUEST_METHOD/PATH_INFO/QUERY_STRING/HTTP_HOST/rack.input and CONTENT_TYPE, then Tina4::Request.new(env) - see crud_spec.rb:35-43 and auth_check_spec.rb:46-59 for the working pattern. Headers become HTTP_* keys, the body becomes a real StringIO rack.input, the session comes from a real Tina4::Session with handler: :file on a Dir.mktmpdir. For end-to-end coverage drive it through Tina4::TestClient or a real Puma boot as dev_admin_run_chips_spec.rb does."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/csrf_middleware_spec.rb",
            "line": 161,
            "shape": "double(\"handler\", no_auth: true)",
            "stands_in_for": "the real matched route handler object that Tina4::Router.match returns and that carries .no_auth",
            "verdict": "VIOLATION",
            "reason": "A synthetic object stands in for the router's real route/handler. If Route stops exposing no_auth, or renames it, this test still passes green while every real no_auth route starts being CSRF-blocked.",
            "real_replacement": "Register a real route and use the real handler: Tina4::Router.post('/thing') { |_req, res| res.json({}) }.no_auth, then Tina4::Router.match('POST', '/thing') and attach that real route object to a real Tina4::Request. post_protection_spec.rb:252 already builds a real .no_auth route this way."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/csrf_middleware_spec.rb",
            "line": 306,
            "shape": "double(\"handler\", no_auth: false)",
            "stands_in_for": "the real matched route handler object carrying .no_auth == false",
            "verdict": "VIOLATION",
            "reason": "Negative twin of the hit above; same substitution, same blind spot. The 'CSRF is required' branch is proven only against a fabricated handler.",
            "real_replacement": "Register a real route WITHOUT .no_auth (Tina4::Router.post('/guarded') { ... }), match it, and drive the real request through Tina4::CsrfMiddleware.before_csrf, asserting the 403 on a real Tina4::Response."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/database_autocommit_spec.rb",
            "line": 135,
            "shape": "allow(db).to receive(:current_driver).and_return(drv) followed by expect(drv).not_to receive(:commit) on line 136",
            "stands_in_for": "the real SQLite driver's commit path (Tina4::Drivers::SqliteDriver#commit)",
            "verdict": "VIOLATION",
            "reason": "expect(drv).not_to receive(:commit) REPLACES the real commit method with a null implementation for the duration of the example. The test named 'does NOT issue a framework commit' therefore proves nothing about durability - it proves only that a message was not sent to a stubbed method. The spec's own comment admits it cannot observe the real effect on SQLite.",
            "real_replacement": "Observe the real durability effect instead of the message. With TINA4_AUTOCOMMIT=false, do the standalone write on a real Postgres (127.0.0.1:55432, user/pass tina4/tina4 - verified UP) or real MySQL (127.0.0.1:3306, verified UP) where an uncommitted write is genuinely invisible, then open a SECOND real connection and SELECT: the row must be absent under autocommit=false and present under autocommit=on. That is a real-engine observation of the exact invariant, with no double."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/database_autocommit_spec.rb",
            "line": 147,
            "shape": "allow(db).to receive(:current_driver).and_return(drv) followed by expect(drv).to receive(:commit).at_least(:once).and_call_original on line 148",
            "stands_in_for": "the real SQLite driver's commit path",
            "verdict": "VIOLATION",
            "reason": "and_call_original keeps the real behaviour but the method is still wrapped by a message-expectation proxy, and db.current_driver itself is stubbed. Under the rule as written a message expectation on a real collaborator is a double.",
            "real_replacement": "Same as above - assert the row is visible from a second real connection on Postgres 55432 / MySQL 3306 after a standalone write with autocommit ON. The second-connection SELECT is the real proof that a commit happened."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/db_contract_abc_spec.rb",
            "line": 163,
            "shape": "drv.define_singleton_method(:commit) { raise RuntimeError, \"simulated commit failure\" if calls[:n] == 1; original_commit.call } (removed at line 189)",
            "stands_in_for": "the real database driver's commit, i.e. a genuine engine-side COMMIT failure",
            "verdict": "VIOLATION",
            "reason": "A monkeypatched singleton method on the real driver simulating a commit failure - the spec's own comment says 'simulated commit failure'. It proves the framework's pin/rollback bookkeeping against a fake exception raised at a point the engine may never raise at, and would not catch a driver that raises a DIFFERENT error class or leaves the connection in a different state.",
            "real_replacement": "Drive a REAL commit failure. On Postgres 55432: open two connections, take conflicting locks and set a short lock_timeout / use SERIALIZABLE and force a real serialization failure at COMMIT; or start a transaction, then from a second real session issue a server-side termination (SELECT pg_terminate_backend) so the COMMIT fails on a genuinely dead socket. On MySQL 3306 a deferred FK constraint or a real deadlock victim gives a commit-time error. Either way the exception comes from the engine, not from the test."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/dev_admin_spec.rb",
            "line": 305,
            "shape": "allow(ENV).to receive(:[]).and_call_original + allow(ENV).to receive(:[]).with(\"TINA4_DEBUG\").and_return(...) - 21 occurrences at lines 305,306,311,312,317,318,323,324,391,392,396,519,520,605,606,668,669,687,688,750,751",
            "stands_in_for": "ENV - the real process environment that gates DevAdmin.enabled?",
            "verdict": "VIOLATION",
            "reason": "ENV is a real collaborator and it is partially doubled. The stub only intercepts ENV#[]; any production code reading the same var via ENV.fetch, ENV.key?, or a cached ivar sees the UNSTUBBED value, so the gate can be tested green while the real gate is open in production. This is the cheapest violation in the repo to fix and the one most likely to hide a real debug-endpoint exposure.",
            "real_replacement": "Set the real variable and restore it. ENV['TINA4_DEBUG'] = 'true' in before, ENV.delete / restore the saved value in after - env_vars_spec.rb:28-36 already ships a with_env helper that does exactly this correctly. For the enabled?/disabled? pairs, boot the real dev server both ways (dev_admin_run_chips_spec.rb boots real Puma) and assert the real HTTP 404 vs 200."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/dev_reload_ws_spec.rb",
            "line": 31,
            "shape": "FakeWsConn = Struct.new(:id, :sent) do def send_text(message); sent << message; end end - used at lines 58, 78, 100",
            "stands_in_for": "Tina4::WebSocketConnection and the real socket underneath it",
            "verdict": "VIOLATION",
            "reason": "An in-test object implementing the same interface, registered into the real Tina4::DevReload manager. It records strings instead of writing RFC 6455 frames, so a regression in framing, in the close handshake, or in a write that silently fails on a dead peer is invisible. The spec asserts a JSON string was appended to an array, never that a browser could read a frame.",
            "real_replacement": "This repo already has the real pattern: dev_admin_run_chips_spec.rb:58-62 boots a real Puma (Puma supplies rack.hijack), opens a raw TCPSocket to 127.0.0.1:PORT, performs a real RFC 6455 handshake on /__dev_reload, then POSTs /__dev/api/reload and reads the real frame bytes off the socket. graceful_shutdown_spec.rb:315-337 does the same for close code 1001. Reuse that harness; assert on decoded frame payloads."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/dev_reload_ws_spec.rb",
            "line": 46,
            "shape": "allow(ENV).to receive(:[]).and_call_original / .with(\"TINA4_DEBUG\").and_return(\"true\") (lines 46-47)",
            "stands_in_for": "ENV - the real process environment",
            "verdict": "VIOLATION",
            "reason": "Partial double on ENV; only ENV#[] is intercepted, so any other read path in DevAdmin/DevReload sees the unstubbed environment.",
            "real_replacement": "ENV['TINA4_DEBUG'] = 'true' in before and restore in after, using the with_env helper from env_vars_spec.rb:28-36."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/env_vars_spec.rb",
            "line": 43,
            "shape": "Tina4::WebServer.new(double(\"app\")) - also line 50",
            "stands_in_for": "the real Rack application the web server is constructed around",
            "verdict": "VIOLATION",
            "reason": "The Rack app is the server's primary collaborator and it is a bare double. The test then reads @host out of the object with instance_variable_get, so it asserts on private state of a server built around a fake - it never proves the server actually binds the host it resolved.",
            "real_replacement": "Pass the real app: Tina4::RackApp.new(root_dir: Dir.mktmpdir). Better, prove the binding for real - with TINA4_HOST=127.0.0.1 boot the server on a free port and assert a TCPSocket connect to 127.0.0.1 succeeds while a connect to the machine's LAN address is refused; with TINA4_HOST unset (0.0.0.0) both succeed. dev_admin_run_chips_spec.rb:34 already has a free_port helper."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/env_vars_spec.rb",
            "line": 390,
            "shape": "allow(Tina4::Log.instance_variable_get(:@file_logger)).to receive(:<<).and_raise(IOError.new(\"disk full\")) - also lines 401-402 and 418-419",
            "stands_in_for": "the real ::Logger / file IO that Tina4::Log writes through",
            "verdict": "VIOLATION",
            "reason": "A simulated write failure on the real logger object. The comment even says 'so a @file_logger exists to mock'. It proves Tina4::Log re-raises when something raises IOError from <<, not that a genuine disk/permission failure propagates - and a real failure may surface as Errno::EACCES or Errno::ENOSPC from a different call site (write/flush/sync), which this test would not catch.",
            "real_replacement": "Cause a genuine write failure on the filesystem. Dir.mktmpdir, Tina4::Log.configure(dir) so the real log file is created and the real @file_logger is open, then File.chmod(0o400, log_path) and FileUtils.chmod(0o500, dir) (read+execute only) so the next append raises a real Errno::EACCES from the OS; assert it propagates with TINA4_LOG_STRICT=true and is swallowed without it. On a run as root, use a real full filesystem instead: a small hdiutil-attached ram disk (macOS) or a size-capped tmpfs mount, filled to capacity, gives a real ENOSPC. Restore permissions in ensure."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/firebird_reconnect_spec.rb",
            "line": 73,
            "shape": "double(\"conn\", close: nil) at 73, double(\"fresh_conn\", close: nil) at 76, allow(driver).to receive(:open_connection) at 75, double(\"dead_conn\") at 108, allow(bad_conn).to receive(:close).and_raise at 109, plus have_received assertions at 89, 96, 104",
            "stands_in_for": "a real Firebird connection and the real FirebirdDriver#open_connection reconnect",
            "verdict": "VIOLATION",
            "reason": "The entire #with_reconnect describe block runs against doubles - the driver's own reconnect is stubbed out, so the test proves only that with_reconnect calls a stubbed method the expected number of times. It cannot catch a reconnect that opens a connection but leaves @in_transaction wrong, reuses a poisoned handle, or fails to re-prepare a statement. The spec's before block openly says 'so we don't hit a real Firebird server'.",
            "real_replacement": "Use a real Firebird (this repo already runs live Firebird CI - see project_firebird_orm_132 / project_firebird_node_rollback; firebird_url_spec.rb:79-83 has a firebird_reachable? probe that skips loudly with host and port). Open a real connection, then kill it FOR REAL from outside the driver: (a) restart or `docker restart` the Firebird container mid-test, or (b) use FB's own gfix -shut / DELETE FROM MON$ATTACHMENTS to force-detach the session, or (c) point the driver at a real TCP proxy you then close, so the next execute raises the genuine 'Error writing data to the connection.' Assert the driver transparently reconnects AND that a subsequent SELECT returns real rows. Note lines 22-63 (.dead_connection? string classification) are already correct pure-logic tests and need no change."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/gallery_spec.rb",
            "line": 181,
            "shape": "allow(Tina4).to receive(:root_dir).and_return(tmp_dir)",
            "stands_in_for": "Tina4.root_dir - the real project-root resolution that DevAdmin gallery_deploy, dev_admin.rb:890/1438/1452 and test_client.rb:64 all read",
            "verdict": "VIOLATION",
            "reason": "The filesystem root the deploy writes into is faked. Any code path that resolves the root differently (Dir.pwd fallback, @root_dir on RackApp) escapes the stub, so a deploy could write outside tmp_dir in production and the test would still be green.",
            "real_replacement": "Set the real root. Either Dir.chdir(tmp_dir) { ... } so Dir.pwd genuinely is the temp dir (Tina4.root_dir falls back to Dir.pwd), or set the real backing state Tina4.root_dir reads (assign it, or export the TINA4 root env var the framework honours) in before and restore in after. Then assert the deployed files exist on the REAL filesystem under tmp_dir with File.file?, which the surrounding block at line 170 already does correctly."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/mcp_dev_endpoint_spec.rb",
            "line": 57,
            "shape": "allow(ENV).to receive(:[]) with TINA4_DEBUG / TINA4_MCP / TINA4_MCP_REMOTE / TINA4_MCP_TOKEN / TINA4_API_KEY - 17 occurrences at lines 57,58,196,197,236,237,238,239,240,241,263,269,270,279,280,298,299",
            "stands_in_for": "ENV - the real process environment gating a REMOTE-reachable MCP endpoint with DB query and file WRITE tools",
            "verdict": "VIOLATION",
            "reason": "This is the highest-stakes ENV double in the repo: it gates remote access to tools that can query the database and write files. Only ENV#[] is intercepted; a gate that consults ENV.fetch or a memoised value is untested, and the whole remote-deny suite could be green while the real endpoint is open. Doubling the security gate is exactly the class of bug the rule exists to stop.",
            "real_replacement": "Set the real env vars (ENV['TINA4_MCP_REMOTE']='true', ENV['TINA4_MCP_TOKEN']='s3cr3t-token', etc) with save/restore in before/after. Then prove the deny for real over the wire rather than through handle_request: boot the real server on a free port (dev_admin_run_chips_spec.rb:34 free_port + real Puma) and connect from a genuinely non-loopback source address so REMOTE_ADDR is a real remote peer - bind the client socket to the host's real LAN interface address, or run the request through a real local TCP forwarder - and assert the real 404. Keep the spoofed X-Forwarded-For case, sent as a real header."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/middleware_events_spec.rb",
            "line": 36,
            "shape": "expect(Tina4::Log).to receive(:warning) do |message| ... end",
            "stands_in_for": "Tina4::Log - the real logger",
            "verdict": "VIOLATION",
            "reason": "A message expectation on the real logger, and without and_call_original it REPLACES Tina4::Log.warning entirely - the real formatting, level filtering, file writing and stdout path never run. A regression that makes warning() raise, or drop the message before it reaches any sink, passes this test.",
            "real_replacement": "Capture the REAL log output. Dir.mktmpdir + Tina4::Log.configure(dir) with TINA4_LOG_OUTPUT=file, emit the event, Tina4::Log.close_file_logger, then File.read the real log file and assert it contains the event name, 'RuntimeError' and 'kaboom'. For the stdout sink, capture the real stream the way cli_spec.rb:71 and legacy_env_guard_spec.rb:71 already do ($stdout swap or IO.pipe) and assert on the real bytes written."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/middleware_events_spec.rb",
            "line": 210,
            "shape": "expect(Tina4::Log).to receive(:error) do |message| ... end",
            "stands_in_for": "Tina4::Log - the real logger",
            "verdict": "VIOLATION",
            "reason": "Same shape as line 36 - the real Log.error is replaced for the example, so the assertion is on a message send, not on anything a human operator would ever see.",
            "real_replacement": "Same: configure the real file logger into a tmpdir, run the before_* throw through the real pipeline, close the logger and assert on the real file contents (must contain 'before_boom', 'RuntimeError', 'kaboom')."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/middleware_events_spec.rb",
            "line": 239,
            "shape": "allow(Tina4::Log).to receive(:error) { |message| logged << message }",
            "stands_in_for": "Tina4::Log - the real logger",
            "verdict": "VIOLATION",
            "reason": "Swaps the real logger for a lambda that appends to an array. The test's after_* ordering assertions are fine, but the logging half is proven against a substitute and the real sink is never exercised.",
            "real_replacement": "Keep the ordering assertions, and get `logged` from the real log file instead: Tina4::Log.configure(Dir.mktmpdir) with TINA4_LOG_OUTPUT=file, then read and split the real file into lines after the run."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/migration_footguns_spec.rb",
            "line": 18,
            "shape": "class FakeDB with get_database_type / table_exists?, injected via m.instance_variable_set(:@db, FakeDB.new(engine, exists)) at line 90",
            "stands_in_for": "Tina4::Database and the real engines it reports (mssql, firebird, ...)",
            "verdict": "VIOLATION",
            "reason": "An in-test class implementing the same interface is injected as the migration's @db. should_skip_create_table's real inputs - what get_database_type actually returns for a live MSSQL/Firebird connection, and whether table_exists? actually finds the table - are both fabricated. If the real driver reports 'sqlserver' where the fake says 'mssql', or table_exists? has a schema-qualification bug, this test stays green and migrations break on the real engine. Lines 36-52 (split_sql_statements) are genuine pure-logic tests and are fine.",
            "real_replacement": "Use the real engines that are UP: MySQL at 127.0.0.1:3306 and Postgres at 127.0.0.1:55432 (both verified reachable). Connect a real Tina4::Database, CREATE the table for real, then run the real CREATE TABLE migration statement a second time and assert it is skipped (and that no error is raised and the row count is unchanged). For the engines that genuinely lack IF NOT EXISTS, use the live Firebird CI already in this repo (firebird_url_spec.rb:79-83 has the reachability probe) and skip LOUDLY naming host and port when it is absent - never fall back to FakeDB."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/orm_contracts_spec.rb",
            "line": 85,
            "shape": "expect(Tina4::Log).to receive(:error).with(/CGhost\\.save failed for table 'cghost_missing'/).and_call_original - also line 110",
            "stands_in_for": "Tina4::Log - the real logger",
            "verdict": "VIOLATION",
            "reason": "Message expectation on the real logger. Even with and_call_original the method is wrapped by a mock proxy; the rule as written names a logger assertion of exactly this form as a double. The surrounding save-failure assertions correctly use a real SQLite DB - only the logging half is faked.",
            "real_replacement": "Configure the real file logger for the example (Dir.mktmpdir, TINA4_LOG_OUTPUT=file, Tina4::Log.configure(dir)), run ghost.save against the real SQLite database that is already in play, close the logger, then assert File.read(log_path) matches /CGhost\\.save failed for table 'cghost_missing'/. That checks the real formatted line an operator would grep for."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/orm_contracts_spec.rb",
            "line": 128,
            "shape": "allow(Tina4::Log).to receive(:error) - also lines 133 and 197",
            "stands_in_for": "Tina4::Log - the real logger",
            "verdict": "VIOLATION",
            "reason": "Silences the real logger entirely for noise reduction. It is still a substitution of a real collaborator, and it means these examples cannot notice if the loud-failure logging disappears - the very contract the file exists to lock in.",
            "real_replacement": "Do not silence it - point it somewhere real and quiet. Set TINA4_LOG_OUTPUT=file and Tina4::Log.configure(Dir.mktmpdir) for the example so the output goes to a real temp file instead of the console, and (optionally) assert the file contains the expected failure line."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/orm_footguns_doc_spec.rb",
            "line": 56,
            "shape": "allow(Tina4::Log).to receive(:error).and_call_original in a before(:each)",
            "stands_in_for": "Tina4::Log - the real logger",
            "verdict": "VIOLATION",
            "reason": "A partial double installed on the real logger for EVERY example in the file (the trailing comment 'keep it quiet-ish' is the giveaway). Every doc-lock-in example in this file therefore runs with a mock proxy sitting on the logging collaborator.",
            "real_replacement": "Delete the stub and route the real logger to a temp file for the file's duration: in before(:each) set TINA4_LOG_OUTPUT=file and Tina4::Log.configure(Dir.mktmpdir); in after(:each) Tina4::Log.close_file_logger and restore the env. Console stays quiet, the real logger still runs."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/orm_v3_13_11_spec.rb",
            "line": 68,
            "shape": "fake_db = Object.new with define_singleton_method for :get_database_type, :table_exists?, :execute, :commit (lines 68-75), swapped onto the model via BoolFlagged.instance_variable_set(:@db, fake_db) and BoolFlagged.define_singleton_method(:db) (lines 79-80)",
            "stands_in_for": "Tina4::Database for postgres, postgresql, mysql, mssql, sqlserver, sqlite and firebird",
            "verdict": "VIOLATION",
            "reason": "Seven engines' DDL is asserted against a hand-built object that captures the SQL string and never executes it. The spec's own comment admits why: 'BIT / BOOLEAN wouldn't run on SQLite locally'. This tests that Tina4 GENERATES a string containing 'BOOLEAN', not that any engine ACCEPTS it - a syntactically wrong DDL that merely contains the right token passes. That is the same 'assert the generated script's shape' failure as the Node Mongo queue.",
            "real_replacement": "Run the DDL for real on the engines that are UP: Postgres 127.0.0.1:55432 (tina4/tina4) and MySQL 127.0.0.1:3306, both verified reachable, plus real file-backed SQLite. For each, BoolFlagged.create_table against a real Tina4::Database, then read the column type back from the real catalog (Postgres: information_schema.columns.data_type must be 'boolean'; MySQL: SHOW COLUMNS / information_schema; SQLite: PRAGMA table_info) and round-trip a true/false value through insert+select. For MSSQL and Firebird use the live containers this repo already provisions, skipping LOUDLY with host and port when absent - never fall back to the fake_db."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/router_reload_spec.rb",
            "line": 154,
            "shape": "allow(ENV).to receive(:[]).and_call_original / .with(\"TINA4_DEBUG\").and_return(\"true\") (lines 154-155)",
            "stands_in_for": "ENV - the real process environment gating the dev reload endpoint",
            "verdict": "VIOLATION",
            "reason": "Partial double on ENV. The rest of this example is excellent (real files on disk, real utime, real DevAdmin.handle_request) - the ENV double is the one fake left in an otherwise real end-to-end test.",
            "real_replacement": "ENV['TINA4_DEBUG'] = 'true' with save/restore, using the with_env helper at env_vars_spec.rb:28-36."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/router_spec.rb",
            "line": 191,
            "shape": "route.run_middleware(double(\"req\"), double(\"res\")) - also line 199",
            "stands_in_for": "Tina4::Request and Tina4::Response",
            "verdict": "VIOLATION",
            "reason": "Both pipeline collaborators are bare doubles. Because the doubles answer nothing, any middleware that actually touched the request or response would blow up - so the test silently constrains itself to middleware that ignore both arguments, and proves nothing about the real request/response contract the pipeline depends on.",
            "real_replacement": "Pass real objects: Tina4::Request.new(env) from a real Rack env hash (pattern at crud_spec.rb:35-43) and Tina4::Response.new. Assert ordering AND that the middleware could mutate the real response (e.g. a header actually lands on Tina4::Response). middleware_pipeline_characterisation_spec.rb:287 already builds real requests this way."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/router_v3_spec.rb",
            "line": 89,
            "shape": "req = double(\"request\") / res = double(\"response\") at 89-90 and 101-102; route.run_middleware(double(\"req\"), double(\"res\")) at 114",
            "stands_in_for": "Tina4::Request and Tina4::Response",
            "verdict": "VIOLATION",
            "reason": "Identical substitution to router_spec.rb:191, duplicated in the v3 router spec. The comment 'Simulate middleware run' names the problem: it is a simulation, not a run.",
            "real_replacement": "Tina4::Request.new(real rack env) and Tina4::Response.new, or drive the route end-to-end through Tina4::TestClient / Tina4::RackApp#call so the real dispatcher builds both objects."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/security_hardening_spec.rb",
            "line": 55,
            "shape": "expect(Tina4::Auth).to receive(:validate_api_key).with(\"super-secret-api-key-value\").and_call_original - also line 63",
            "stands_in_for": "Tina4::Auth.validate_api_key - the real timing-safe comparison",
            "verdict": "VIOLATION",
            "reason": "A message expectation installed on the real Auth module. It asserts a call was routed, which is an implementation detail, not a security property - if validate_api_key is later inlined or renamed the test goes red for no security reason, and if a non-timing-safe fast path is added ALONGSIDE the call the test stays green.",
            "real_replacement": "Assert the security property, not the call graph. The file already has the right idea at line 76 (source-grep for a `token == api_key` fast path) - keep that, and add a real behavioural check: a real timing measurement over many real authenticate_request calls with keys differing at byte 0 versus at the last byte, asserting the timing distributions are statistically indistinguishable (best-of-N to absorb the known perf flake). That exercises the real comparison end to end with no double."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/security_hardening_spec.rb",
            "line": 71,
            "shape": "expect(OpenSSL).to receive(:fixed_length_secure_compare).with(\"abc\", \"abc\").and_call_original",
            "stands_in_for": "the real OpenSSL module",
            "verdict": "VIOLATION",
            "reason": "A message expectation on a third-party real collaborator (OpenSSL). Same defect as above: it pins the implementation choice rather than the guarantee, and cannot detect a second, non-constant-time path added next to it.",
            "real_replacement": "Assert the real outcome plus the real source guarantee: validate_api_key returns true only for an exact match (already asserted) and false for every same-length near-miss, combined with the existing source assertion that no `==` fast path exists, plus the timing-distribution check described above. No double needed."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/security_hardening_spec.rb",
            "line": 118,
            "shape": "class RaisingHandler (read/write/destroy/gc all `raise \"connection refused\"`), injected via session.instance_variable_set(:@handler, ...) in build_session; used at lines 154, 164, 174, 186, 193, 212, 217, 223, 228, 237",
            "stands_in_for": "an unreachable Redis / Valkey / Memcached / MongoDB session backend (Tina4::SessionHandlers::RedisHandler etc)",
            "verdict": "VIOLATION",
            "reason": "This is the live confirmation named in the brief and it is the single most dangerous double in the file: TEN examples covering the entire backend-failure policy (degrade, dirty-flag retention, strict re-raise) run against an in-test class that raises a RuntimeError with a hand-written message. A real client raises Redis::CannotConnectError / Errno::ECONNREFUSED / Mongo::Error::NoServerAvailable, and a real unreachable backend also brings timeouts, half-open sockets and partial writes - none of which this exercises. The session degradation path has therefore NEVER touched a real server.",
            "real_replacement": "Point the real handlers at a real closed port and at real servers you stop. Port 127.0.0.1:6399 is verified CLOSED right now - construct Tina4::Session.new(env, handler: :redis, handler_options: { host: '127.0.0.1', port: 6399 }) and the real RedisHandler raises a real connection error on read/write/destroy/gc; repeat with :valkey, :memcached and :mongo against the same closed port. For the healthy-backend invariant (EmptyHealthyHandler) use the real servers that are UP: redis 6379, valkey 6380, the third redis-ish 6381, memcached 11211, MongoDB 27017 - all verified reachable - with a fresh unused session id so the read is genuinely empty. For a mid-flight failure, stop the real service (docker stop / redis-cli SHUTDOWN NOSAVE on a disposable instance) between two operations. Any example needing a service must skip LOUDLY naming host and port when it is absent."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/security_hardening_spec.rb",
            "line": 126,
            "shape": "class EmptyHealthyHandler (read -> nil, write -> true, destroy -> true, gc -> 0), injected the same way via build_session",
            "stands_in_for": "a reachable, healthy Redis / Valkey / Memcached / Mongo session backend",
            "verdict": "VIOLATION",
            "reason": "Easy to argue as harmless - and that is exactly why it is dangerous. It is the positive control for 'a healthy backend logs ZERO errors', and it is fabricated. A real handler that returns {} but ALSO logs a spurious error, or that returns a string where the framework expects a Hash, passes this test. The negative and positive halves of the invariant are both proven against in-test classes, so the pair proves nothing about any real backend.",
            "real_replacement": "Use the real servers, all verified UP: redis 127.0.0.1:6379, valkey 127.0.0.1:6380, the third redis-ish instance 127.0.0.1:6381, memcached 127.0.0.1:11211, MongoDB 127.0.0.1:27017. Build the real handler, read a freshly-generated session id that genuinely does not exist (so the empty read is real, not simulated), write/save, destroy and gc for real, and assert the real log file (temp-dir file logger) contains no ERROR line. Skip loudly with host and port when a service is down."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/security_hardening_spec.rb",
            "line": 153,
            "shape": "expect(Tina4::Log).to receive(:error).at_least(:once) at lines 153, 162, 173, 185, 192 and expect(Tina4::Log).not_to receive(:error) at line 199",
            "stands_in_for": "Tina4::Log - the real logger",
            "verdict": "VIOLATION",
            "reason": "Six message expectations that REPLACE the real Log.error (no and_call_original), stacked on top of the RaisingHandler double. The 'never silent' guarantee - the whole point of the block - is verified by counting messages to a mock. Line 199's not_to receive is the load-bearing negative assertion and it too is a mock.",
            "real_replacement": "Capture the REAL log output. In build_session's setup, Dir.mktmpdir + TINA4_LOG_OUTPUT=file + Tina4::Log.configure(dir); after the operation, Tina4::Log.close_file_logger and File.read the real log. Assert the file contains an ERROR line naming the real handler class (session.rb:300-301 formats 'Session #{operation} failed (#{handler_class}): ...'), and for line 199's negative case assert the real file contains no ERROR line at all. Combined with the real-closed-port replacement above, the message and the failure both become real."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/smoke_spec.rb",
            "line": 252,
            "shape": "req = double(\"request\", path: \"/test\") and res = double(\"response\") at 252-253; the same pair at 264-265",
            "stands_in_for": "Tina4::Request and Tina4::Response",
            "verdict": "VIOLATION",
            "reason": "The middleware section of the smoke suite - the suite whose entire job is to prove the framework works end to end - runs its before/after hooks against two doubles. A smoke test built on fakes is the weakest possible signal.",
            "real_replacement": "Tina4::Request.new(real rack env) + Tina4::Response.new, or better for a smoke suite: register a real route, boot the real Rack app and assert the hooks ran by observing a real header/body on the real HTTP response (global_after_middleware_spec.rb:41-49 already calls app.call(env) with a real env)."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/smoke_spec.rb",
            "line": 617,
            "shape": "Tina4::WebSocketConnection.new(\"test-id\", StringIO.new)",
            "stands_in_for": "the real TCP socket a WebSocket connection writes frames to",
            "verdict": "VIOLATION",
            "reason": "A 'fake' passed as a constructor argument - the exact non-obvious shape called out in the brief. StringIO accepts any bytes and never fails, so frame construction is asserted against an in-memory buffer that cannot exhibit short writes, EPIPE on a dead peer, or backpressure. This is how a silent write-failure prune bug hides.",
            "real_replacement": "Use a real socket pair. IO.pipe gives a real OS pipe (real short writes and real EPIPE when the read end closes), and a real TCPSocket pair via a TCPServer on 127.0.0.1 gives real network semantics; graceful_shutdown_spec.rb:320-337 and dev_admin_run_chips_spec.rb:58-62 already open real TCPSockets and read real RFC 6455 frames off them. Read the bytes back off the real read end and decode the frame."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_auth_spec.rb",
            "line": 57,
            "shape": "allow(write_io).to receive(:getbyte).and_return(0x88, 0x00, nil) / :read / :write / :close - lines 57-61, inside the run_upgrade helper used by the whole file",
            "stands_in_for": "the real client socket the WebSocket frame loop reads from",
            "verdict": "VIOLATION",
            "reason": "The real IO.pipe endpoint is partially doubled so getbyte hands back a scripted close frame instead of real bytes from a real peer. Every auth example in the file therefore runs against a socket whose read path is scripted; a framing or auth-ordering bug that only appears with real interleaved bytes is invisible. Line 60 even re-wraps the real write through the double.",
            "real_replacement": "Drive a real peer. Open a real TCPServer on 127.0.0.1 (free_port helper at dev_admin_run_chips_spec.rb:34), have the real client socket send a real RFC 6455 close frame (0x88 0x00, masked as a client must) and then close, and let the server's frame loop read genuine bytes. Assert the handshake response bytes read off the real client socket. graceful_shutdown_spec.rb:315-337 is the working template in this repo."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_hardening_spec.rb",
            "line": 22,
            "shape": "class FakeWsConnection with send_text/closed?/close and raise_on_send / report_closed flags",
            "stands_in_for": "Tina4::WebSocketConnection and the real socket beneath it",
            "verdict": "VIOLATION",
            "reason": "An in-test class implementing the same interface, used to drive the broadcast-resilience and prune paths. The failure it simulates ('simulated broken pipe') is a hand-raised IOError, not a real broken pipe - so the prune logic is proven against a flag, and a real dead peer that fails differently (silent short write, EPIPE on flush, half-open socket) is untested. The file header openly states 'no real Redis/NATS/sockets'.",
            "real_replacement": "Use real sockets and kill one for real. Open N real client TCPSockets to a real Puma-hosted WebSocket endpoint, then close one client abruptly (or SO_LINGER 0 reset it) so the server's next write hits a genuine EPIPE, and assert the other clients still receive the broadcast and the dead one is pruned from ws.connections. For the report_closed path, close the real peer and let closed? reflect the real socket state."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_hardening_spec.rb",
            "line": 54,
            "shape": "class FakeBackplane < Tina4::WebSocketBackplane (in-memory pub/sub), wired in via wire_backplane setting @backplane and @backplane_started directly",
            "stands_in_for": "Tina4::RedisBackplane (lib/tina4/websocket_backplane.rb:73) / Tina4::NATSBackplane (:127)",
            "verdict": "VIOLATION",
            "reason": "A subclass of the real base class that replaces the network with a synchronous in-memory hash - the comment says so: 'exactly what a real backplane does, minus the network and background thread'. Losing the network and the background thread loses everything that actually breaks: serialization over the wire, ordering, the subscriber thread, reconnects, and delivery to a genuinely separate process. Cross-instance relay is the feature under test and no second instance ever exists.",
            "real_replacement": "Use the real RedisBackplane against the real Redis at 127.0.0.1:6379 (verified UP; valkey 6380 and the third instance 6381 are also up for a second engine). Stand up TWO real WebSocket managers - ideally in two real processes, or at minimum two managers each with its own real RedisBackplane subscriber thread - with real client sockets attached to each, broadcast on instance A and assert the real frame arrives at instance B's client and that the origin instance does not echo. NATS 4222 is currently DOWN, so a NATS variant must skip LOUDLY naming host 127.0.0.1 port 4222."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_hardening_spec.rb",
            "line": 78,
            "shape": "class ExplodingBackplane < FakeBackplane whose publish always raises RuntimeError \"bus down\"",
            "stands_in_for": "a real backplane whose broker is down or rejecting publishes",
            "verdict": "VIOLATION",
            "reason": "A subclass overriding one method purely to force a branch - the exact pattern named in the brief. It proves the manager survives a RuntimeError from publish; a real Redis outage raises Redis::CannotConnectError / Errno::ECONNREFUSED / a timeout after a delay, and can also hang rather than raise, which this never explores.",
            "real_replacement": "Real broker failure. Point a real RedisBackplane at the verified-closed port 127.0.0.1:6399 so publish fails for real on connect; or connect to real Redis 6379, then stop it for real mid-test (docker stop, or redis-cli SHUTDOWN NOSAVE against a disposable instance) and assert the local broadcast still reaches local clients over their real sockets while the bus is down."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_hardening_spec.rb",
            "line": 86,
            "shape": "class CapturingBackplane < FakeBackplane recording every (channel, message) publish",
            "stands_in_for": "Tina4::RedisBackplane - specifically which channel a broadcast is published on",
            "verdict": "VIOLATION",
            "reason": "A spy in all but name: it exists to record calls so a test can assert on them. The channel name is asserted against the fake's recorded tuple rather than against what a real subscriber on a real broker actually receives - so a channel-naming or envelope-encoding bug that a real subscriber would reject still passes.",
            "real_replacement": "Subscribe for real. With real Redis at 127.0.0.1:6379, open an independent real Redis client SUBSCRIBEd to the expected channel (or PSUBSCRIBE '*' to discover the channel actually used), trigger the broadcast, and assert the real message arrives on the real channel with the real envelope - including the base64 bytes round-trip this file already cares about."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_hardening_spec.rb",
            "line": 451,
            "shape": "allow(write_io).to receive(:getbyte).and_return(0x88, 0x00) / :read / :close (lines 451-453) in the Origin allow-list example",
            "stands_in_for": "the real client socket in the origin-guard handshake",
            "verdict": "VIOLATION",
            "reason": "The accepted-origin case scripts the socket read path, so the 101 handshake is asserted against a socket whose peer is fabricated. The rejected-origin case just above (line 437) reads real bytes off a real pipe and is fine - the positive case, which is the one that must not silently accept, is the mocked one.",
            "real_replacement": "Real client socket via TCPServer on 127.0.0.1 sending a real masked close frame after the handshake, reading the real 101 response bytes back - same harness as graceful_shutdown_spec.rb:315-337."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_spec.rb",
            "line": 179,
            "shape": "allow(write_io).to receive(:getbyte).and_return(0x88, 0x00) / :read / :close - eight clusters at lines 179-181, 203-205, 235-237, 256-258, 276-278, 293-295, 313-314, 333-335",
            "stands_in_for": "the real client socket the WebSocket frame loop reads from",
            "verdict": "VIOLATION",
            "reason": "Thirty partial-double calls on real IO.pipe endpoints across the entire #handle_upgrade section. The frame loop's read path is scripted in every example, including line 313's and_raise(RuntimeError, 'socket broke') which fabricates the socket error the error-handler test exists to verify.",
            "real_replacement": "Real TCPServer/TCPSocket pair on 127.0.0.1 (free_port helper at dev_admin_run_chips_spec.rb:34): let a real client complete the handshake, send a real masked close frame, then close. For the 'fires error handler on read exception' case, get a REAL socket error - abruptly reset the client (SO_LINGER 0) or close the read end so the server's getbyte raises a genuine Errno::ECONNRESET/EPIPE - and assert the real error class reaches the :error hook."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_spec.rb",
            "line": 351,
            "shape": "instance_double(Tina4::WebSocketConnection, id: \"a\") at 351, 352, 364, 365, 381, each followed by expect(connX).to receive(:send_text)",
            "stands_in_for": "Tina4::WebSocketConnection and the socket it writes to",
            "verdict": "VIOLATION",
            "reason": "The whole #broadcast describe block - including the exclude: filter, which is a correctness-critical fan-out rule - is verified by asserting that send_text was CALLED on verified doubles. Nothing is ever written to anything. A broadcast that calls send_text and then throws the bytes away passes all four examples.",
            "real_replacement": "Register real Tina4::WebSocketConnection objects over real sockets (TCPServer pair, or Puma + real client sockets as dev_admin_run_chips_spec.rb:58-62 does), broadcast, and assert the real frame bytes arrive on the included clients' real read ends and that the excluded client's socket receives nothing within a timeout."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_spec.rb",
            "line": 857,
            "shape": "expect(conn1).to receive(:send_text).with(\"hello room\") / expect(conn3).not_to receive(:send_text) / allow(conn1).to receive(:send_text) - lines 857-862 and 875-878, applied to REAL WebSocketConnection objects from make_connection",
            "stands_in_for": "WebSocketConnection#send_text - the real frame-writing method",
            "verdict": "VIOLATION",
            "reason": "Subtler than the instance_double above and worth flagging separately: the connections are real objects, but send_text is REPLACED by a message expectation, so real framing never runs. The room-membership fan-out (including the not_to receive negative on conn3) is proven by counting method calls on a partially doubled real object.",
            "real_replacement": "Leave send_text alone and observe the real socket. Give each connection a real socket (TCPServer pair / IO.pipe), call broadcast_to_room, then read the real bytes off each peer's read end - decode and assert the payload on the room members and assert a non-blocking read on the non-member raises EAGAIN/returns nothing."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/websocket_spec.rb",
            "line": 390,
            "shape": "let(:socket) { StringIO.new } passed as the WebSocketConnection constructor arg - also lines 16, 170, 474, 510, 581, 595, 604, 613, 622, 632, 644, 659, 668, 735 (make_connection) and 935",
            "stands_in_for": "the real TCP socket a WebSocket connection reads frames from and writes frames to",
            "verdict": "VIOLATION",
            "reason": "A fake passed as a constructor argument, used across the whole WebSocketConnection suite. StringIO never short-writes, never raises EPIPE on a live peer, never blocks and has no notion of a half-open connection, so the frame writer and the close path are exercised against an object that cannot fail the way a socket fails. Line 474's 'silently handles IOError on closed socket' is the clearest case: close_write on a StringIO is not a closed TCP socket.",
            "real_replacement": "Use IO.pipe (a real OS pipe: real writes, real EPIPE once the read end is closed) for the unit-level frame tests, and a real TCPSocket pair from a TCPServer on 127.0.0.1 for anything touching close semantics or backpressure. For the closed-socket example, close the real peer end so the write raises a genuine Errno::EPIPE and assert send_text swallows it."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/feedback_spec.rb",
            "line": 154,
            "shape": "def fake_request(path:, env:) -> Struct.new(:path, :env).new(path, env)",
            "stands_in_for": "Tina4::Request - the real request object inject_feedback_widget receives",
            "verdict": "VIOLATION",
            "reason": "An anonymous Struct standing in for the framework's request. It responds only to .path and .env, so if inject_feedback_widget starts consulting headers, params or the session the test cannot notice; and the widget-injection decision is a security-adjacent gate (whitelist / dev-user) being decided on a fabricated request.",
            "real_replacement": "Tina4::Request.new(env) from a real Rack env (crud_spec.rb:35-43 pattern). Even better, this file already boots a real supervisor HTTP server and asserts on bytes received over a real socket (feedback_spec.rb:28-44) - route the injection assertions through that same real request path."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/wsdl_spec.rb",
            "line": 45,
            "shape": "RequestStub = Struct.new(:method, :body, :params, :url) - used at lines 80, 87, 94, 188, 197 and throughout the file",
            "stands_in_for": "Tina4::Request - the real request a WSDL/SOAP service is constructed with",
            "verdict": "VIOLATION",
            "reason": "Named 'stub' in the source and comment ('Minimal request stub'). Every SOAP dispatch test - GET returns WSDL, ?wsdl detection, operation invocation - runs against a four-field Struct. The real request parses method, body and query from a Rack env; a mismatch between the Struct's shape and Tina4::Request's actual surface (e.g. params vs query, url vs path) would make every one of these pass while real SOAP calls 404.",
            "real_replacement": "Tina4::Request.new(real rack env) with REQUEST_METHOD, PATH_INFO, QUERY_STRING ('wsdl'), CONTENT_TYPE 'text/xml' and the SOAP envelope as a real StringIO rack.input. For the dispatch tests, register the WSDL service as a real route and POST the real SOAP envelope through Tina4::TestClient or a real booted server, asserting on the real XML response bytes."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/firebird_reconnect_spec.rb",
            "line": 24,
            "shape": "no double - described_class.dead_connection?(msg) over a table of literal strings",
            "stands_in_for": "nothing - pure logic",
            "verdict": "EXEMPT",
            "reason": "A pure classification function over string inputs: given an error message, is it a dead-socket marker. No dependency is touched and no double appears anywhere in the .dead_connection? describe block (lines 22-63). This is the model of what an exempt test looks like - and it is in the same file as one of the worst violations, so the file cannot simply be deleted.",
            "real_replacement": "n/a - no change needed."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/middleware_pipeline_characterisation_spec.rb",
            "line": 54,
            "shape": "in-test middleware classes (Ordered, Ay, Bee, Base, Derived, DenyPair, DenyNil, ThrowingBefore, ...) with real def self.before_*/after_* methods - same pattern at global_after_middleware_spec.rb:54, global_middleware_split_spec.rb:56, middleware_parity_spec.rb:195",
            "stands_in_for": "nothing - these ARE the application-supplied middleware, the pipeline's input",
            "verdict": "EXEMPT",
            "reason": "I checked these hardest because in-test classes are the shape the brief warns about. They are not substitutes: the framework has no 'real middleware' these displace - middleware is user code the pipeline runs, exactly like a route handler or an ORM model class. They have real source_location (which the ordering logic reads), and the requests/responses around them are real (real rack env at line 287, real Tina4::Request). The file header at line 24 explicitly states the design intent. Nothing here stands between the test and a database, socket, logger or backend.",
            "real_replacement": "n/a - no substitution present."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/response_autoserialize_spec.rb",
            "line": 17,
            "shape": "stub_const(\"Widget\", widget_class) where widget_class = Class.new(Tina4::ORM) with real field declarations - same pattern at orm_construct_spec.rb:13 and smoke_spec.rb:69/330/437",
            "stands_in_for": "nothing - a real Tina4::ORM subclass, named for the example",
            "verdict": "EXEMPT",
            "reason": "stub_const here only gives an anonymous but otherwise fully real ORM subclass a stable constant name (so error messages and table_name resolution work); it replaces no collaborator. The behaviour under test is Response#call serialising a model via the real to_h - pure in-memory logic with no DB. In smoke_spec.rb the same pattern is backed by a real SQLite database. No double.",
            "real_replacement": "n/a - no substitution present."
          },
          {
            "file": "/Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/crud_spec.rb",
            "line": 35,
            "shape": "def mock_request building a Hash rack env then Tina4::Request.new(env) - same at auth_check_spec.rb:46, rack_app_spec.rb:13, static_files_spec.rb:19, http_protocol_gaps_spec.rb:20, landing_page_spec.rb:35, router_error_event_spec.rb:45, router_auth_payload_spec.rb:35",
            "stands_in_for": "nothing - the real Tina4::Request built from a real Rack env",
            "verdict": "EXEMPT",
            "reason": "Named 'mock_*' but is not one: a Rack env is a plain Hash of strings, which is what a real server hands the app, and the request object constructed from it is the genuine Tina4::Request. The rack.input StringIO is what the Rack SPEC itself defines the input as (a rewindable IO-like), not a stand-in. These helpers are the correct replacement target for the double(\"request\") violations above.",
            "real_replacement": "n/a - already real; the misleading 'mock_' name is worth renaming to build_request so it stops reading like a violation in audits."
          }
        ],
        "search_patterns_used": [
          "rg -n \"\\b(double|instance_double|class_double|spy|instance_spy|class_spy|object_double)\\s*\\(\" --glob '*.rb' .",
          "rg -n \"receive|allow\\(|allow_any_instance_of|stub_const|and_return|and_raise\" --glob '*.rb' .",
          "rg -n \"receive_messages|expect_any_instance_of|allow_any_instance_of|and_wrap_original|as_null_object|instance_spy|class_spy|object_double|\\bspy\\(\" --glob '*.rb' .   (0 hits, exit 1)",
          "rg -n \"^\\\\s*(class|module|Struct\\\\.new|Class\\\\.new)\\\\b.*(Raising|Fake|Stub|Null|Mock|Dummy|Spy|Dead|Broken|Failing|Bad|InMemory|Memory)\" --glob '*.rb' .",
          "rg -n \"define_singleton_method|singleton_class|alias_method|\\\\.prepend\\\\(|def self\\\\.|instance_variable_set\" --glob '*.rb' .",
          "rg -n \"StringIO|IO\\\\.pipe|Socket|TCPSocket\" --glob '*.rb' .",
          "rg -n \"Struct\\\\.new|OpenStruct\" --glob '*.rb' .",
          "rg -n \"def (mock|fake|stub|dummy|null)_\" --glob '*.rb' .",
          "rg -no \"\\\\b(Fake|Stub|Mock|Dummy|Null|Spy)\\\\w*\" --glob '*.rb' . | sort -u   (catches Struct/const forms the class-line regex missed, e.g. FakeWsConn)",
          "rg -o \"(allow|expect)\\\\([^)]*\\\\)\\\\s*\\\\.?\\\\s*(to|not_to)\\\\s+(receive|have_received)\" --glob '*.rb' . | sort | uniq -c   (target census)",
          "rg -n \"^\\\\s*class [A-Z]\\\\w+\" --glob '*.rb' .   (102 in-test class defs enumerated and triaged by hand)"
        ],
        "control_search": "CONTROL 1: `rg -o \"describe\" --glob '*.rb' .` -> 2090 hits across 217 of 220 files. CONTROL 2 (the string the brief told me is present): `rg -n \"RaisingHandler\" --glob '*.rb' .` -> 11 hits, all in security_hardening_spec.rb (lines 118, 154, 164, 174, 186, 193, 212, 217, 223, 228, 237), confirming the brief's known-present marker. CONTROL 3 (deliberate negative, to prove an empty result is real and not a broken glob): `rg -n \"receive_messages|expect_any_instance_of|as_null_object|and_wrap_original|spy\\(\" --glob '*.rb' .` -> 0 hits, exit 1 - those shapes genuinely do not appear in this suite. All globs were QUOTED ('*.rb') to avoid the zsh unquoted-glob failure mode that looks identical to \"no matches\". Positive counts across the suite: double( = 22, instance_double( = 5, \"to receive\" = 126, have_received = 3.",
        "total_test_files_scanned": 220,
        "could_not_verify": [
          "I did NOT run the full suite. I ran 9 of the 217 spec files to prove the cited doubles are live code and not dead files: `bundle exec rspec spec/csrf_middleware_spec.rb spec/firebird_reconnect_spec.rb spec/migration_footguns_spec.rb spec/orm_v3_13_11_spec.rb spec/wsdl_spec.rb` -> 196 examples, 0 failures; `bundle exec rspec spec/security_hardening_spec.rb spec/dev_reload_ws_spec.rb spec/feedback_spec.rb spec/env_vars_spec.rb spec/orm_contracts_spec.rb` -> 117 examples, 0 failures. 313 examples confirmed executing. The other 208 spec files were read, not run.",
          "Service availability re-verified myself with `nc -z -G 1 127.0.0.1 <port>` on 2026-08-01: redis 6379 UP, valkey 6380 UP, third redis-ish 6381 UP, memcached 11211 UP, MongoDB 27017 UP, Postgres 55432 UP, MySQL 3306 UP. Port 6399 confirmed CLOSED (usable as the real unreachable-backend target). NATS 4222 is DOWN, so any real NATSBackplane test must skip loudly naming 127.0.0.1:4222. I did NOT verify Firebird or MSSQL reachability on this host - the Firebird-dependent replacements assume the live Firebird CI this repo already runs elsewhere.",
          "I did not check whether the framework actually honours a settable Tina4.root_dir. `rg 'def self.root_dir' lib/` found no definition (only call sites at dev_admin.rb:890/1438/1452, service_runner.rb:90, test_client.rb:54/64, all with a `|| Dir.pwd` fallback), yet gallery_spec.rb:181 stubs it and spec_helper.rb:124 sets verify_partial_doubles = true - so it must be defined somewhere I did not locate. The Dir.chdir replacement I propose works regardless via the Dir.pwd fallback, but the cleaner fix depends on where root_dir is actually defined.",
          "JUDGEMENT CALL a human should confirm: I ruled `\"rack.input\" => StringIO.new(body)` EXEMPT (it appears in ~20 files). The Rack SPEC defines rack.input as a rewindable IO-like object, so StringIO is a conforming real value, not a stand-in. A stricter reading would call every one of those a socket substitute, which would put most of the HTTP-level suite in scope.",
          "JUDGEMENT CALL a human should confirm: I ruled in-test middleware classes (middleware_pipeline_characterisation_spec.rb, global_after_middleware_spec.rb:54, global_middleware_split_spec.rb:56, middleware_parity_spec.rb:195) and stub_const'd ORM model classes EXEMPT, on the ground that they are application-supplied inputs to the unit under test rather than substitutes for a framework collaborator. If the project wants the strictest possible reading, these are the next tier to revisit.",
          "I did not diff this inventory against the equivalent Python/PHP/Node suites, so I cannot say which of these 46 sites are Ruby-only versus shared parity gaps. The RaisingHandler cluster is known to be Ruby-only (the Python MagicMock Redis/Valkey twin was already fixed on feature/audit-auth per the brief).",
          "COUNT NOTE: 220 = all .rb files under spec/ (217 *_spec.rb + spec_helper.rb + 2 files under spec/support/). Every one was covered by the greps; the 27 files carrying any double shape were opened and read individually."
        ]
      },
      {
        "framework": "No third-party mocking library is present anywhere. jest.fn/jest.mock/jest.spyOn = 0 hits, vi.fn/vi.mock/vi.spyOn = 0, sinon = 0, node:test mock.method/mock.fn = 0. The suite is a hand-rolled harness: 225 of 227 *.test.ts files define their own `function assert(name, condition)` and are spawned one-per-child-process by test/run-all.ts under `npx tsx`. Exceptions: test/i18n.test.ts and test/i18n-leaf-alias.test.ts import vitest (describe/it/expect) and are run by the separate `test:i18n` npm script; test/parityTestClass.test.ts imports `node:assert` strict. Because there is no mocking library, EVERY double in this repo is hand-rolled - an in-test class, an object literal cast with `as unknown as`, or a direct property reassignment. Versions tested: tina4-nodejs 3.13.94, branch v3 @ a6bda71, Node v24.9.0, tsx 4.21.0, macOS Darwin 25.5.0. Services re-verified UP on 127.0.0.1 at scan time: redis 6379, valkey 6380, redis-ish 6381, memcached 11211, MongoDB 27017, Postgres 55432, MySQL 3306 - so \"the service was not available\" is not available as a defence for any hit below.",
        "control_search": "PRIMARY CONTROL: `grep -rn \"console.log(\" test --include='*.ts'` -> 2388 hits. This is a string I know is present (every one of the 225 hand-rolled harness files prints its PASS/FAIL lines with it), so the recursive walk + the QUOTED --include glob are both proven working under zsh. SECOND CONTROL: `grep -rn \"packages/core/src\" test --include='*.ts'` -> 227 hits; `grep -rn \"function assert\" test --include='*.ts'` -> 220 hits. NEGATIVE CONTROL: `grep -rn \"zzz_no_such_string_zzz\" test --include='*.ts'` -> 0 hits, confirming a genuine empty result is distinguishable from a glob error. The zero results for jest/vi/sinon/node:test-mock are therefore TRUSTWORTHY zeros, measured with the same quoted-glob invocation that returned 2388.",
        "total_test_files_scanned": 232,
        "search_patterns_used": [
          "grep -rni \"mock\" test --include='*.ts'  (535 hits)",
          "grep -rni \"stub\" test --include='*.ts'  (50)",
          "grep -rni \"spy\" test --include='*.ts'  (19)",
          "grep -rni \"fake\" test --include='*.ts'  (222)",
          "grep -rni \"dummy\" test --include='*.ts'  (2)",
          "grep -rn \"jest.fn|jest.mock|jest.spyOn\" test --include='*.ts'  (0)",
          "grep -rn \"vi.fn|vi.mock|vi.spyOn\" test --include='*.ts'  (0)",
          "grep -rn \"sinon\" test --include='*.ts'  (0)",
          "grep -rn \"node:test|mock.method|mock.fn\" test --include='*.ts'  (0)",
          "grep -rnE \"^[[:space:]]*(export )?(default )?(abstract )?class [A-Za-z0-9_]+\" test --include='*.ts'  (130 in-test class declarations, by-file histogram)",
          "grep -rn \"implements \" test --include='*.ts'  -- finds in-test classes implementing a framework interface (the most dangerous shape)",
          "grep -rnE \"^[[:space:]]*(Log|console|process|globalThis|global)\\.[A-Za-z]+ = \" test --include='*.ts'  -- global/module reassignment",
          "grep -rn \"process.stdout.write =|process.stderr.write =|process.exit =\" test --include='*.ts'",
          "grep -rn \"Object.defineProperty\" test --include='*.ts'",
          "grep -rnE \"\\(.* as unknown as \\{\" test --include='*.ts'  -- private-internals monkeypatching",
          "grep -rnE \"as (unknown as )?(DatabaseAdapter|SessionHandler|QueueBackend|CacheBackend|WebSocketBackplane|Transport)\" test --include='*.ts'",
          "grep -rn \"setHandler(\" test --include='*.ts'  -- injection points for session backends",
          "grep -rniE \"simulat(e|es) the .*(logic|from server|enforcement)|replicate(s)? the|reproduces the\" test --include='*.ts'  -- in-test REIMPLEMENTATIONS of framework code (found 3 auth cases)",
          "grep -rnE \"^[[:space:]]*(export )?(async )?(function|class|const|let|var) .*(mock|stub|spy|fake|dummy)\" test --include='*.ts'  -- double factory declarations"
        ],
        "hits": [
          {
            "file": "test/websocketHardening.test.ts",
            "line": 50,
            "shape": "in-test class `FakeBackplane implements WebSocketBackplane` (in-memory Map-backed pub/sub)",
            "stands_in_for": "the real cross-instance WebSocket backplane - Redis/Valkey pub-sub (6379/6380) or NATS",
            "verdict": "VIOLATION",
            "reason": "It implements the production interface and is injected in place of the real bus. The file header openly states 'Engine-agnostic - no real Redis/NATS/sockets.' Publish fans out SYNCHRONOUSLY in-process, so the exact things a real backplane does differently - network round-trip latency, message ordering under concurrency, reconnect, serialization over the wire, at-least-once redelivery - are all defined away. This is precisely the Node-Mongo-queue failure mode: the shape is asserted, the wire behaviour never is. I RAN it: 39 passed, 0 failed, without touching any of the 7 live services.",
            "real_replacement": "Redis is UP on 127.0.0.1:6379 and Valkey on 6380. Point WsBackplaneManager at the real RedisBackplane and run the two-server relay across a real SUBSCRIBE/PUBLISH: server A publishes an envelope, server B's relay must receive it exactly once. For the origin-guard-no-echo case, assert the originating server does NOT re-deliver to its own clients after a real round-trip through 6379. For backplane-down behaviour, do not build a broken fake - point at a genuinely closed port obtained by bind-then-release (test/sessionHandlerErrors.ts:57 already has the correct `closedPort()` helper to copy), or SIGSTOP/stop the real redis and assert the degrade path. Skip loudly naming host+port when redis is absent."
          },
          {
            "file": "test/websocketHardening.test.ts",
            "line": 75,
            "shape": "in-test class `MockSocket` with `throwOnWrite` flag, injected into the server's private `clients` Map at line 105",
            "stands_in_for": "a real client TCP socket (net.Socket) held by WebSocketServer",
            "verdict": "VIOLATION",
            "reason": "`throwOnWrite = true` throws `new Error('simulated broken pipe')` - a fabricated failure standing in for a real EPIPE. A real broken pipe on Node does not always throw synchronously from write(); it commonly surfaces as a deferred 'error' event and a false return from write() under backpressure. The broadcast-resilience and client-pruning assertions are therefore proving behaviour against an error shape the kernel may never produce.",
            "real_replacement": "Start the real WebSocketServer on an ephemeral port, connect real clients with node:net doing the real HTTP Upgrade handshake (computeAcceptKey is already exported and used in this suite). To drive a genuine broken pipe: have one connected client call socket.destroy() (or resetAndDestroy() for a real RST) and then broadcast - assert the surviving clients still receive the frame and the dead client is pruned from the map. For backpressure, write a payload larger than the socket high-water mark to a client that never reads, and assert on the real writableLength/drain behaviour."
          },
          {
            "file": "test/websocketHardening.test.ts",
            "line": 141,
            "shape": "private-internals monkeypatch via `as unknown as` casts: `mgr.backplane = fake`, `mgr.relay = fn`, `mgr.started = true`, `server.backplaneStarted = true`, `server.relayLocal` rewiring (lines 141-142, 157-159, 179, 243-252)",
            "stands_in_for": "the real `ensure()` startup wiring that connects a manager to a real bus and installs the real relay callback",
            "verdict": "VIOLATION",
            "reason": "The test reaches past the public API and hand-assembles the object graph the framework is supposed to build. Every bug in the real wiring path - ensure() failing to set started, failing to subscribe, installing the wrong relay - is invisible, because the test writes those fields itself. The comment at line 140 admits it: 'ensure() with no env config attaches no bus'.",
            "real_replacement": "Set the real env config (TINA4_WS_BACKPLANE / redis URL pointing at 127.0.0.1:6379) and call the public `ensure()` so the framework does its own wiring against the live Redis, then assert the observable outcome (a message published on server A arrives at a real client connected to server B). Assert on delivered frames, never on private fields."
          },
          {
            "file": "test/websocket.test.ts",
            "line": 364,
            "shape": "in-test class `MockSocket` (records `written: Buffer[]`), injected straight into the server's private `clients` map at line 377",
            "stands_in_for": "a real client TCP socket for the entire WebSocket Rooms feature",
            "verdict": "VIOLATION",
            "reason": "The file header states 'No actual socket connections are made.' The whole rooms/broadcast surface - join, leave, roomCount, getRoomConnections, room broadcast - is verified only against buffers appended to an array. Frame bytes are never handed to a kernel socket and never parsed by a real peer, so a framing bug that a real client would reject reads as PASS here.",
            "real_replacement": "The suite already imports node:net and node:http and already has computeAcceptKey/parseUpgradeHeaders. Bind the server to port 0, open N real TCP connections, perform the real Upgrade handshake, join rooms via the real path, broadcast, and assert on the bytes each real client actually reads off its socket (parseFrame on received data, not on written data). Client departure = a real socket.end(); assert roomCount drops."
          },
          {
            "file": "test/sessionBackendFailure.test.ts",
            "line": 51,
            "shape": "in-test class `ExplodingHandler implements SessionHandler` - every method throws `new Error('backend unreachable')`; injected via the real `session.setHandler()` at lines 131, 155, 178, 199, 244",
            "stands_in_for": "a real session backend: Redis (6379), Valkey (6380), MongoDB (27017), or the Database handler",
            "verdict": "VIOLATION",
            "reason": "This is the exact pattern the rule was written against, and the exact twin of tina4-ruby's RaisingHandler that the brief already flags as broken. A fabricated synchronous throw is not what an unreachable Redis produces: the real handler path goes through respClient/syncSocket and surfaces ECONNREFUSED / ETIMEDOUT / a partial RESP reply, with different messages and different timing. The 'read failure is LOGGED' assertion checks for the substrings 'read' and 'failed' in a message the test itself never lets the real transport generate. I RAN it: 16 passed, 0 failed, zero sockets opened, with all 7 services UP.",
            "real_replacement": "Three real drivers, no doubles. (1) Backend unreachable: construct the REAL RedisSessionHandler/ValkeySessionHandler/MongoSessionHandler pointed at a genuinely closed port - reuse the `closedPort()` bind-then-release helper that already exists in this repo at test/sessionHandlerErrors.ts:57 - and assert start()/save()/destroy()/gc() degrade and log. (2) Backend hangs: reuse `startSilentServer()` from test/sessionHandlerErrors.ts:70 (a real listener in its own process that accepts and never replies) to drive the timeout branch. (3) Backend up but rejecting: point the real handler at memcached on 11211 while speaking RESP, or at a real Redis with a wrong-password AUTH, for a genuine protocol/permission error. For write-fails-after-start, use the real file handler with TINA4_SESSION_DIR on a directory chmod'd 0500 - a real EACCES on a real write."
          },
          {
            "file": "test/sessionBackendFailure.test.ts",
            "line": 73,
            "shape": "in-test class `WriteFailsAfterStartHandler implements SessionHandler` - counts writes, throws on write #2+",
            "stands_in_for": "a session backend that accepts the bootstrap write then becomes unreachable",
            "verdict": "VIOLATION",
            "reason": "A stateful counter standing in for a mid-request outage. It is engineered specifically to land on one branch of Session.save() under TINA4_SESSION_STRICT, which means the test asserts the branch is reachable by construction rather than that a real outage reaches it.",
            "real_replacement": "Real degradation mid-flight: start a real Session against the live Redis on 6379, complete start(), then make the backend genuinely go away before the second write - either `redis-cli -p 6379 CLIENT KILL` the handler's connection, or (cleanest, no service disruption) run this case against the FILE handler in a real temp dir and `chmod 0500` the directory between start() and save() so the second write takes a real EACCES. Both produce a genuine errno the framework must map and log."
          },
          {
            "file": "test/sessionBackendFailure.test.ts",
            "line": 92,
            "shape": "in-test class `EmptyHandler implements SessionHandler` - read() returns null and counts calls, write/destroy are no-ops",
            "stands_in_for": "a healthy session backend that has no row for this session id",
            "verdict": "VIOLATION",
            "reason": "This is the 'positive control' half of the file and it is a double too. It asserts 'empty healthy read logs ZERO errors' against a handler that cannot fail - so it can never catch the real regression it exists to prevent, namely a real backend returning an empty/nil RESP reply that the transport misclassifies as a transport error. That misclassification lives in the transport, and this test never runs the transport.",
            "real_replacement": "Redis is UP on 6379. Use the REAL RedisSessionHandler and read a session id that genuinely does not exist (a fresh crypto.randomUUID key). The server returns a real `$-1\\r\\n` null bulk string; assert read() returns null and that captured real log output contains zero error lines. Same for MongoDB on 27017 with a real find that matches no document."
          },
          {
            "file": "test/sessionBackendFailure.test.ts",
            "line": 113,
            "shape": "`captureErrors()` reassigns the imported `Log.error` to a closure that pushes into an array, then restores it",
            "stands_in_for": "the real Log/logger collaborator and its real sinks (stdout JSON in prod, coloured console in dev, the on-disk tina4.log)",
            "verdict": "VIOLATION",
            "reason": "The brief names this class explicitly: a message expectation on the logger is a double under the rule as written. Every assertion in this file that claims a failure is 'LOGGED (never silent)' is checking a substring passed to a function the test itself installed. Log.error's real body - level gating, TINA4_LOG_OUTPUT routing, JSON structuring, file writing - never runs, so a regression that makes Log.error silently drop the record in production still reads as PASS.",
            "real_replacement": "Capture the REAL log output. Set TINA4_LOG_OUTPUT=file and TINA4_LOG_DIR to a real temp dir, let the real Log.error write the real file, then readFileSync the log and assert the line is present and is parseable JSON with level ERROR. test/envVars.test.ts already proves this works - it stats appLogPath and asserts the file grew. For the stdout path, spawn the scenario in a child process with execFile and assert on the child's real captured stdout, which is what `docker logs` would show."
          },
          {
            "file": "test/migrationFootguns.test.ts",
            "line": 47,
            "shape": "four in-test classes `MssqlAdapter`, `FirebirdAdapter`, `SQLiteAdapter`, `PostgresAdapter` (lines 47, 51, 55, 59) whose only method is `tableExists()` returning a constructor-injected boolean, laundered into the production type by `const asDb = (a) => a as DatabaseAdapter` (line 63) and passed to the real `shouldSkipCreateTable()` at lines 150, 155, 162, 169, 173, 181",
            "stands_in_for": "the real MSSQL, Firebird, SQLite and PostgreSQL database adapters",
            "verdict": "VIOLATION",
            "reason": "The most dangerous shape in the file, and it does not look like a mock. The runner's `engineOf()` discriminates on `constructor.name`, so these classes are named to impersonate the real adapters. `tableExists()` is hard-wired to a boolean, so the actual per-engine tableExists implementations - the ones that differ across MSSQL's sys.tables, Firebird's RDB$RELATIONS, SQLite's sqlite_master and Postgres's information_schema, and the ones that actually break - are never executed. I RAN the file: 88 passed, 0 failed, and Postgres was UP on 55432 the whole time.",
            "real_replacement": "SQLite needs nothing (node:sqlite, a real temp file) and Postgres is UP on 127.0.0.1:55432 with tina4/tina4 - drive both for real: create the table, call the real adapter's tableExists() (true), drop it, call again (false), and run shouldSkipCreateTable() against each real adapter in each state. MySQL is UP on 3306 for a third real engine. For MSSQL and Firebird, which are not provisioned on this host, the case must SKIP LOUDLY naming host and port - never fall back to a stand-in class. The existing live-Firebird CI job already covers that engine; reference it rather than impersonating it."
          },
          {
            "file": "test/dbContractAbc.test.ts",
            "line": 180,
            "shape": "monkeypatch of a REAL adapter instance: `const realCommit = target.commit.bind(target); target.commit = () => { throw new Error('simulated commit failure'); }` then restored at line 200",
            "stands_in_for": "a genuine transaction-commit failure from the real SQLite engine",
            "verdict": "VIOLATION",
            "reason": "The test is otherwise entirely real - a real temp SQLite DB through the real ORM - which is exactly what makes this hit dangerous: one method on the real collaborator is swapped out, so the test looks clean. A fabricated throw from a JS closure is not an engine commit failure: a real SQLITE_BUSY or SQLITE_FULL leaves the engine's own transaction state, error code and connection pinning in a specific condition, and the assertions here ('retains the transaction pin', 'follow-up rollback succeeds') are precisely about that state. The synthetic throw never touches the engine, so the engine's real post-failure state is never exercised.",
            "real_replacement": "Drive a real commit failure. SQLite: hold a second real connection with a competing write transaction so COMMIT returns a genuine SQLITE_BUSY; or set the DB file's directory read-only (chmod 0500) mid-transaction so the WAL/journal write fails with a real EACCES; or point the DB at a tmpfs sized so the commit hits a real disk-full. Postgres on 127.0.0.1:55432 is a cleaner driver: open the transaction, then from a second real connection issue `SELECT pg_terminate_backend(pid)` against the first - COMMIT then fails for real with the server's own error, and getError()/pin/rollback behaviour is measured against reality. Deferred-constraint violation (`SET CONSTRAINTS ALL DEFERRED` plus a violating row) is a second real Postgres path that fails only at COMMIT."
          },
          {
            "file": "test/ormContracts.test.ts",
            "line": 131,
            "shape": "instance method override on the object under test: `const originalValidate = bad.validate.bind(bad); (bad as any).validate = () => { const errs = originalValidate(); bad.name = null; return errs; }`",
            "stands_in_for": "the model's own validate() step in the real save() pipeline",
            "verdict": "VIOLATION",
            "reason": "This is the 'subclass that overrides one method to force a branch' case the brief warns about, done to an instance. The comment concedes the intent: pass validation, then null the NOT NULL column after validate() runs. The DB error that follows IS real, but the route to it is a hand-installed hook wedged into the middle of the framework's own save() sequence - so the test also silently asserts that save() calls validate() exactly once at that exact point. Any refactor that moves or re-invokes validate() changes what this test means without changing what it says.",
            "real_replacement": "Reach the driver error without touching the object under test. Create the table with a NOT NULL column (or a UNIQUE/CHECK constraint, or a FOREIGN KEY) that the model's field metadata does NOT declare, so the validator legitimately passes and the real engine legitimately rejects the INSERT. Simplest concrete version on the already-real SQLite: `ALTER TABLE cusers ADD COLUMN dept TEXT NOT NULL` after the model is defined, then save a model with no dept - a genuine SQLITE_CONSTRAINT_NOTNULL from the real driver. Or insert a duplicate value into a real UNIQUE column. Postgres on 55432 gives the same with a deferred CHECK."
          },
          {
            "file": "test/ormContracts.test.ts",
            "line": 98,
            "shape": "`captureStderrAndStdout()` reassigns `process.stdout.write` and `process.stderr.write` to tee-into-array closures",
            "stands_in_for": "the process's real stdout/stderr streams, i.e. the logger's sink",
            "verdict": "VIOLATION",
            "reason": "The assertion 'DB-error save() logged with model context' is checked against a buffer the test installed onto the process object. It is a milder case than a full logger mock because it tees to the originals, but it is still a reassigned global standing between the framework and its real sink, and it cannot observe anything the logger routes to a FILE rather than to a stream.",
            "real_replacement": "Run the failing-save scenario in a child process (execFileSync/spawnSync with npx tsx on a small real script) and assert on the child's genuinely captured stdout/stderr - no reassignment of the parent's streams. Or set TINA4_LOG_OUTPUT=file with a real TINA4_LOG_DIR and readFileSync the real log file, which additionally proves the file sink works."
          },
          {
            "file": "test/ormFootgunsDoc.test.ts",
            "line": 48,
            "shape": "`quiet()` reassigns `process.stderr.write` and `process.stdout.write` to `() => true`, discarding all output",
            "stands_in_for": "the process's real stderr/stdout streams",
            "verdict": "VIOLATION",
            "reason": "A global reassignment that black-holes the real streams for the duration of the deliberately-failing paths. Beyond being a double, it is actively hazardous: while `quiet()` is in effect ANY diagnostic the framework emits - including one signalling a different, unexpected failure - is destroyed, so a regression can hide inside the swallowed window.",
            "real_replacement": "Run the noisy cases in a child process and simply ignore the child's stdio (stdio: 'ignore' on spawnSync), leaving the parent's real streams untouched; or point the real logger at a temp file via TINA4_LOG_OUTPUT=file + TINA4_LOG_DIR so the noise lands in a real file the test can inspect afterwards instead of being destroyed."
          },
          {
            "file": "test/metrics-cli.test.ts",
            "line": 64,
            "shape": "`captureStdout()` reassigns `process.stdout.write` to an array-collecting closure",
            "stands_in_for": "the process's real stdout stream",
            "verdict": "VIOLATION",
            "reason": "Reassigned global standing in for the real output stream; every assertion about what the metrics CLI 'prints' is an assertion about strings handed to a test-installed function. Compounding risk: run-all.ts:41 skips this file by default (TINA4_SKIP_METRICS defaults to '1'), so this double sits in code that a normal `npm test` never even executes.",
            "real_replacement": "The metrics CLI is a real binary. Invoke it as a real child process (spawnSync with the real argv) and assert on the child's real captured stdout - that is what an operator and CI actually see. No stream reassignment needed at all, and it removes the in-process coupling that currently makes the file un-runnable without the Rust binary on PATH."
          },
          {
            "file": "test/cliBuild.test.ts",
            "line": 55,
            "shape": "`(process as any).exit = (c) => { throw { __exit: true, code: c } }` - reassigning a global to convert exit into a throw",
            "stands_in_for": "real process termination",
            "verdict": "VIOLATION",
            "reason": "A reassigned global substituting for the operating system's process lifecycle. The header calls it 'the Node analogue of pytest.raises(SystemExit)', but the two are not analogous: a thrown object unwinds the stack and runs every enclosing finally/catch, whereas a real process.exit terminates immediately and - as this repo's own reference notes record (reference_node_execfilesync_child_traps) - TRUNCATES pending async stderr writes. So this double specifically hides the truncated-diagnostics bug class the team has already been bitten by.",
            "real_replacement": "Spawn the real CLI entrypoint as a child process (spawnSync('npx', ['tsx', 'packages/cli/src/bin.ts', 'build', ...], {cwd: realTempProject})) and assert on the child's REAL exit status and REAL stdout/stderr. test/cliDelegatedCommands.test.ts already does exactly this ('Every case spawns the REAL CLI entrypoint as a child process') - copy that harness. The temp project, PATH override and missing-docker conditions are all already real in this file; only the exit interception needs replacing."
          },
          {
            "file": "test/cliBuild.test.ts",
            "line": 53,
            "shape": "`console.log = (...a) => { out += ... }`, restored in finally",
            "stands_in_for": "the real stdout stream / the console collaborator",
            "verdict": "VIOLATION",
            "reason": "Reassigned global standing in for the real output sink; assertions about what the build command reports are made against a test-installed sink rather than against what the process actually writes.",
            "real_replacement": "Same child-process fix as the process.exit hit above: spawn the real CLI and assert on the child's real stdout. One change removes both doubles in this file."
          },
          {
            "file": "test/cli.test.ts",
            "line": 59,
            "shape": "`captureLog()` reassigns `console.log` to a string-accumulating closure",
            "stands_in_for": "the real stdout stream",
            "verdict": "VIOLATION",
            "reason": "Reassigned global. The file's header claims 'Two tiers, both REAL (no mocks)' - the filesystem and generated-code tiers are indeed real, but the output channel is not, which is exactly the kind of hit that survives an audit that only greps for the word 'mock'.",
            "real_replacement": "Spawn the real `tina4 generate ...` entrypoint as a child process against the real temp project and assert on its real stdout, matching the harness already used in test/cliDelegatedCommands.test.ts and test/cliGenerateCoemits.test.ts."
          },
          {
            "file": "test/cliQueue.test.ts",
            "line": 49,
            "shape": "`captureLog()` reassigns `console.log`",
            "stands_in_for": "the real stdout stream",
            "verdict": "VIOLATION",
            "reason": "Reassigned global. The queue backends this file drives are genuinely real (its header is accurate about the broker), but the assertion channel is a double.",
            "real_replacement": "The file already knows how to run the real bin.ts entrypoint for its dispatch-guard cases; extend that to the output assertions - spawn the real queue command as a child and assert on real captured stdout."
          },
          {
            "file": "test/commandsManifest.test.ts",
            "line": 57,
            "shape": "`captureLog()` reassigns `console.log`",
            "stands_in_for": "the real stdout stream",
            "verdict": "VIOLATION",
            "reason": "Reassigned global. The manifest under test is specifically the `commands --json` wire output that the Rust CLI blind-forwards to - the one consumer that reads it is a separate PROCESS reading real stdout, so asserting on an in-process reassignment tests something structurally different from the contract.",
            "real_replacement": "Run `npx tsx packages/cli/src/bin.ts commands --json` as a real child process and JSON.parse the child's real stdout - that is byte-for-byte what the Rust CLI consumes. This is also a conformance-test improvement: it asserts the wire contract a real client speaks."
          },
          {
            "file": "test/logger.test.ts",
            "line": 147,
            "shape": "`console.log` reassigned to a capture closure at lines 147, 288, 532 and to a black-hole `() => {}` at lines 448 and 489",
            "stands_in_for": "the real stdout stream - the logger's own primary sink",
            "verdict": "VIOLATION",
            "reason": "The worst placement of this shape: it is the LOGGER's own test suite, and the collaborator being replaced is the thing the logger exists to write to. Line 158 does `JSON.parse(consoleOutput.trim())` to prove 'Production writes to stdout (docker logs / k8s)' - but nothing was ever written to stdout; a string was handed to a test-installed function. If Log.info were changed to write to a stream that is NOT the real stdout, this assertion would still pass while `docker logs` went empty. The two black-hole variants at 448/489 additionally destroy any unexpected diagnostic in their window.",
            "real_replacement": "Spawn a child process (execFileSync/spawnSync 'npx tsx' on a 3-line real script that imports Log and calls Log.info) with TINA4_DEBUG unset, and assert on the child's REAL captured stdout - that IS the docker-logs path, measured end to end. For the file-sink cases the same suite already does it right elsewhere (readFileSync on a real TINA4_LOG_DIR file); extend that pattern. For 'silence stdout' assertions, assert the child's real stdout is empty rather than swallowing the parent's."
          },
          {
            "file": "test/envVars.test.ts",
            "line": 210,
            "shape": "`console.log = (...args) => { captured += args.join(' ') }`, restored at line 212",
            "stands_in_for": "the real stdout stream",
            "verdict": "VIOLATION",
            "reason": "Reassigned global used to assert 'TINA4_LOG_OUTPUT=file silences stdout'. The claim is about the process's real stdout; the evidence is about a test-installed function. Notably the surrounding assertions in this same file DO measure reality (statSync on the real log file, comparing sizes) - so the correct technique is already in the file, sitting two lines above the double.",
            "real_replacement": "Spawn a child with TINA4_LOG_OUTPUT=file and TINA4_LOG_DIR set to a real temp dir; assert the child's real stdout is empty AND that the real log file on disk grew. Both halves of the contract, both measured for real, using the statSync approach this file already uses."
          },
          {
            "file": "test/middleware.test.ts",
            "line": 110,
            "shape": "`console.log` reassigned to a capture closure at lines 110, 297, 319 and 355",
            "stands_in_for": "the real stdout stream (requestLogger's sink)",
            "verdict": "VIOLATION",
            "reason": "Reassigned global; the requestLogger middleware's entire observable effect is asserted against a test-installed sink.",
            "real_replacement": "Boot a real server (this repo has ~27 test files that already do so on an ephemeral port), issue real HTTP requests including a real 404, and assert on the real log file written via TINA4_LOG_OUTPUT=file + TINA4_LOG_DIR - or run the server in a child process and assert on its real stdout."
          },
          {
            "file": "test/middlewareEvents.test.ts",
            "line": 44,
            "shape": "`captureLogs()` / `captureLogsAsync()` reassign console.log, console.error AND console.warn simultaneously (lines 44-46 and 63-65)",
            "stands_in_for": "the real stdout/stderr streams behind Log",
            "verdict": "VIOLATION",
            "reason": "Reassigned globals, and the comment at line 37 states the intent plainly: 'Capture Log output (everything routes through console.log/console.error)'. The assertions about middleware error reporting therefore never traverse Log's real level gating, formatting or sinks. Replacing all three streams at once also means an unexpected warning during the window is invisible.",
            "real_replacement": "Set TINA4_LOG_OUTPUT=file with a real TINA4_LOG_DIR and read the real log file after each middleware scenario; or run the pipeline in a child process and assert on the child's real stderr. The sibling test/middlewarePipelineCharacterisation.test.ts already runs 'one REAL server over a REAL socket' - route these assertions through that harness."
          },
          {
            "file": "test/checkAuth.test.ts",
            "line": 51,
            "shape": "`function checkAuth(req: MockReq)` - a 60-line in-test REIMPLEMENTATION of the auth enforcement block from server.ts, driven by the `MockReq` interface declared at line 38",
            "stands_in_for": "the framework's real server.ts request-auth gate",
            "verdict": "VIOLATION",
            "reason": "Strictly worse than a mock: the framework code is not doubled, it is COPIED, and the copy is what gets tested. The header says so - 'Reproduces the auth enforcement logic from server.ts so we can test the three-source priority chain in isolation.' Every one of these PASSes is compatible with server.ts having no auth gate at all. The copy also silently rots: it is pinned to a version of server.ts that may already have moved.",
            "real_replacement": "Drive the REAL gate. The repo ships a TestClient that executes against defaultRouter using real node:http IncomingMessage/ServerResponse (test/parityTestClass.test.ts:64 and test/testClientAuth.test.ts already rely on it), and ~27 files boot a real server on an ephemeral port. Register a real secure route, then issue three real requests - Bearer header, body token, session token - and assert the real status codes and the real FreshToken header. Delete the in-test copy entirely; if the priority chain is hard to reach from outside, that is a signal to export the real function from server.ts and call it, not to re-type it."
          },
          {
            "file": "test/checkAuth.test.ts",
            "line": 230,
            "shape": "object-literal `mockSession = { get(key) { return key === 'token' ? token : undefined } }` at lines 230, 249, 267, 288, 322 and 380",
            "stands_in_for": "the real Session object and, behind it, the real session backend (Redis 6379 / Valkey 6380 / Mongo 27017 / file / database)",
            "verdict": "VIOLATION",
            "reason": "A hand-rolled object passed where a real Session goes. This is the same failure the brief already records for tina4-python/tests/test_session_handlers.py: the session-token auth path has never touched a real session store, so serialization, TTL expiry, and cross-instance session lookup are all untested on this path.",
            "real_replacement": "All four backends are reachable: redis 6379, valkey 6380, memcached 11211, mongo 27017 (plus the file and database handlers, which need no service). Construct a REAL Session with TINA4_SESSION_BACKEND=redis, really `set('token', jwt)` and `save()` it, then issue a real request carrying that real session cookie and assert the gate authorises. Repeat for the invalid-token case with a genuinely stored garbage value. Run the matrix across backends; skip loudly by host+port for any that is absent."
          },
          {
            "file": "test/secureByDefault.test.ts",
            "line": 42,
            "shape": "`function simulateAuthEnforcement(match, authHeader)` - an in-test reimplementation, header at line 39: 'Simulate the auth enforcement logic from server.ts (lines 687-700)'",
            "stands_in_for": "the framework's real server.ts secure-by-default auth gate",
            "verdict": "VIOLATION",
            "reason": "Same class as checkAuth.test.ts: the security-critical decision under test is re-typed in the test file, and the test asserts the copy behaves. The file's own header admits it 'replicates the auth enforcement'. It is pinned to 'lines 687-700' of a file that has certainly moved since - the reference is already stale, which is direct evidence of the drift this pattern guarantees. A secure-by-default regression in the real server.ts cannot fail this test.",
            "real_replacement": "Register real routes on a real Router with each combination of secure/noAuth/default, boot a real server on an ephemeral port (or use the shipped TestClient), and issue real HTTP requests with and without a real Bearer JWT. Assert the real status codes (401 vs 200) coming back off the wire. test/autoCrudPublic.test.ts already drives 'the REAL router secure-by-default gate' - reuse that harness and delete the simulation."
          },
          {
            "file": "test/routerAuthPayload.test.ts",
            "line": 49,
            "shape": "`function simulateAuthEnforcement(...)` - in-test reimplementation, header at line 42: 'Replicate the auth enforcement block from server.ts (lines 788-800)'",
            "stands_in_for": "the framework's real server.ts auth gate and its req.user payload assignment",
            "verdict": "VIOLATION",
            "reason": "Third instance of the copied-production-code pattern, and this one guards a bug the header itself describes (validToken() changed to return bool while getPayload() was still expected). The copy in the test can be correct while the original is not - which is precisely the state the described bug was in. Note the two files cite DIFFERENT line ranges for the same block (687-700 vs 788-800), proving the copies have already drifted from each other.",
            "real_replacement": "Boot the real server / use the real TestClient, register a real route, send a real request with a real JWT built by the real getToken(), and assert that req.user inside the REAL handler carries the decoded payload (echo it back in the response body and assert on the received JSON). That measures the actual assignment the bug broke."
          },
          {
            "file": "test/csrfMiddleware.test.ts",
            "line": 49,
            "shape": "`mockRequest()` (line 49) and `mockResponse()` (line 70) - object literals cast `as unknown as Tina4Request` / `as Tina4Response`, with a fake `raw` carrying only statusCode and writableEnded; used across ~40 call sites (lines 108-487)",
            "stands_in_for": "the real node:http IncomingMessage/ServerResponse pair and the real HTTP transport",
            "verdict": "VIOLATION",
            "reason": "The largest single concentration of doubles in the suite (68 'mock' occurrences) and it guards CSRF - a security control. Nothing here goes over a socket: the fake `raw` has two properties, so header emission, real status-line writing, cookie handling and body termination are never exercised. A CSRF bypass that manifests only in how the real response is finalised passes cleanly. I RAN it: 32 passed, 0 failed, no socket opened.",
            "real_replacement": "Boot a real server on an ephemeral port with CsrfMiddleware in the real pipeline and issue real HTTP requests with node:http: safe methods (GET/HEAD/OPTIONS) expect 200; unsafe methods without a token expect a real 403 off the wire; token in body vs X-Form-Token header vs query string each as a real request; a real Authorization: Bearer to exercise the skip; and a real session cookie backed by a real Session (redis on 6379 is up) for the session-binding cases. Assert on the real status codes and real headers the client receives. ~27 files in this suite already boot a real server; the harness exists."
          },
          {
            "file": "test/static.test.ts",
            "line": 28,
            "shape": "`mockReq()` (line 28) and `mockRes()` (line 33) - object literals with a hand-written `raw.setHeader`/`raw.end`; ~30 call sites",
            "stands_in_for": "the real node:http request/response and the real socket",
            "verdict": "VIOLATION",
            "reason": "62 'mock' occurrences, and it guards path traversal - `/../package.json`, `/%2e%2e/package.json`, `/../../etc/passwd`. The assertion is on a boolean returned by tryServeStatic and on strings collected by a fake setHeader, so the test cannot see what bytes a real client would actually receive. Traversal defences are exactly where the gap between 'the function returned false' and 'no bytes left the process' matters.",
            "real_replacement": "The sibling test/staticCache.test.ts and test/responseFileTraversal.test.ts already do this right ('a real server, real sockets, real files'). Boot a real server serving the real public dir and request each path over a real socket, asserting on the real status code and the real response body - for traversal, assert the body does NOT contain the contents of the file being reached for. Files on disk are already real here; only the transport needs to become real."
          },
          {
            "file": "test/devAdmin.test.ts",
            "line": 340,
            "shape": "`mockReq()` (line 340) and `mockRes()` (line 345, captures via a `json()` that stores into a closure); ~14 call sites",
            "stands_in_for": "the real HTTP request/response for the dev-admin API handlers",
            "verdict": "VIOLATION",
            "reason": "Handlers are invoked directly with hand-built shells, so the real dev-admin route registration, the TINA4_DEBUG gate at dispatch time, real status codes and real serialization are all bypassed. This is the same subsystem where test/devAdminEsmRequire.test.ts records a real shipped bug - 'the dashboard silently showed one fake topic while real topics sat on the queue' - i.e. a 200-with-wrong-body, which a direct-handler-call harness is structurally blind to.",
            "real_replacement": "test/devAdminDbQueue.test.ts and test/devAdminEsmRequire.test.ts already boot 'the ACTUAL Tina4 dev server (TINA4_DEBUG=true) on a real port' and issue real HTTP. Move these cases onto that harness and assert on the real JSON received off the wire - which also then covers the debug gate (the same endpoint must 404 with TINA4_DEBUG unset)."
          },
          {
            "file": "test/connectionsTest.test.ts",
            "line": 44,
            "shape": "`mockReq()` (line 44) and `mockRes()` (line 47) - 'plain transport shells' per the header comment; used at lines 97 and 121",
            "stands_in_for": "the real HTTP request/response for the /__dev/api/connections/test endpoint",
            "verdict": "VIOLATION",
            "reason": "The header argues these are 'NOT mocks of any dependency'. Be strict: they are in-test objects passed where the real request/response go, so they are doubles regardless of the label. The database half genuinely is real (node:sqlite through the real ORM) and the regression it targets is a real one - but the endpoint is an HTTP endpoint, and the un-awaited-Promise bug class it locks in (Array.isArray(Promise) === false) is exactly the kind that a real JSON serialization over a real socket would also have caught, and caught more convincingly.",
            "real_replacement": "Boot the real dev server with TINA4_DEBUG=true on an ephemeral port and POST the real JSON body to /__dev/api/connections/test over a real socket, asserting on the real response JSON (tables === 2, a real engine version string). Keep the real SQLite DB exactly as it is - only the transport changes. test/devAdminDbQueue.test.ts is the template."
          },
          {
            "file": "test/landingPage.test.ts",
            "line": 45,
            "shape": "`mockReq()` (line 45) and `mockRes()` (line 49); call sites at 225-259",
            "stands_in_for": "the real HTTP request/response",
            "verdict": "VIOLATION",
            "reason": "In-test shells passed where real request/response objects go; the landing-page and /admin/ serving decisions are asserted against captured closure state rather than against bytes a client received.",
            "real_replacement": "Boot a real server over the real public dir and GET '/' and '/admin/' with node:http, asserting on the real status and the real HTML body. Same fix as test/static.test.ts, and both files can share one helper."
          },
          {
            "file": "test/feedback.test.ts",
            "line": 39,
            "shape": "`mockReq()` (line 39) and `mockRes()` (line 49) - a hand-built response recording json/status/rawWriteHeadStatus/rawHeaders/chunks; call sites at 153-330",
            "stands_in_for": "the real HTTP request/response",
            "verdict": "VIOLATION",
            "reason": "In-test shells standing in for the transport. Notable contrast within the same file: the upstream-service cases at lines 238 and 281 correctly use a REAL createServer on a real port - so the file already demonstrates the right technique and applies it to one collaborator while doubling another.",
            "real_replacement": "Extend the file's own real-createServer approach to the widget-injection and endpoint cases: boot the real Tina4 server, GET a real page and assert the widget markup is present in the real response body; POST real feedback and assert the real status and the real payload forwarded to the real upstream stub server (which is already real in this file)."
          },
          {
            "file": "test/middleware.test.ts",
            "line": 27,
            "shape": "`mockReq()` (line 27) and `mockRes()` (line 41) - a callable object with hand-written header/status/raw; used across the chain, CORS and OPTIONS cases",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "CORS assertions in particular are about response HEADERS, and here headers are collected into a plain object by a test-written `header()` implementation - so whether the real ServerResponse ever emits them (or emits them after headersSent, or with the wrong casing) is untested.",
            "real_replacement": "test/corsPolicyConformance.test.ts already boots 'one server per policy' with real requests - route these cases through the same harness and assert on the real Access-Control-* headers the HTTP client receives, including a real preflight OPTIONS request with a real Origin header."
          },
          {
            "file": "test/middlewareEvents.test.ts",
            "line": 77,
            "shape": "`mockReq()` (line 77) and `mockRes()` (line 90); section comment at line 76 reads 'Mocks (no external services)'",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "Self-declared mocks passed where the real request/response go; the before/after hook ordering and gating results are read off `_status`/`_body`/`_ended` fields the test itself defined, not off a real response.",
            "real_replacement": "test/middlewarePipelineCharacterisation.test.ts in this same suite runs 'NO MOCKS: one REAL server over a REAL socket, real middleware classes'. Move these ordering and gating cases onto that harness: register the real middleware classes, issue real requests, and assert the real status and real body - hook ordering shows up as an observable header or body stamp."
          },
          {
            "file": "test/middlewareParity.test.ts",
            "line": 41,
            "shape": "`mockRes()` (line 41), `mockReq()` (line 80), plus a `fake` object literal cast `as unknown as IncomingMessage` at line 222 and handed to the real createRequest()",
            "stands_in_for": "the real node:http request/response, including a fabricated IncomingMessage",
            "verdict": "VIOLATION",
            "reason": "The line-222 case is the sharper one: an object literal with a hand-written `socket: { remoteAddress }` is cast to IncomingMessage and passed to production code. The comment calls it 'a real-ish IncomingMessage' - real-ish is a double. Header case-insensitivity is asserted against headers the test assigned directly, never against headers produced by Node's real HTTP parser (which lowercases, folds duplicates and handles set-cookie specially).",
            "real_replacement": "Boot a real server and send real requests with genuinely mixed-case header names on the wire (node:http lets you set arbitrary header casing on the client). Assert the case-insensitive accessor works on the header object Node's real parser produced. For remoteAddress, use the real connecting socket's real address rather than a literal."
          },
          {
            "file": "test/auth.test.ts",
            "line": 183,
            "shape": "`mockRequest()` (line 183) and `mockResponse()` (line 198) - a callable response capturing {data, status}; call sites at 210-508",
            "stands_in_for": "the real node:http request/response behind authMiddleware",
            "verdict": "VIOLATION",
            "reason": "The auth middleware's rejection path is asserted by reading a `lastCall` object the test installed, so what a real client receives for an expired/garbage/RS256 token - real status code, real WWW-Authenticate header, real body - is never observed. Security control, doubled transport.",
            "real_replacement": "Register a real protected route, boot a real server (or use the shipped TestClient, which uses real IncomingMessage/ServerResponse), and issue real requests with: a valid HS256 JWT, a genuinely expired one, garbage, and a real RS256-signed one. Assert on the real 200/401 and the real response body off the socket. test/testClientAuth.test.ts already does this correctly for its cases - extend it."
          },
          {
            "file": "test/authJwtAlgorithmNbf.test.ts",
            "line": 423,
            "shape": "`mockRequest()` (line 423) and `mockResponse()` (line 436); call sites at 452-486",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "Same shape as auth.test.ts, guarding the JWT alg/nbf handling. The nbf-leeway and algorithm-confusion cases are security decisions whose real-world effect is an HTTP status; asserting on a captured `state.lastStatus` skips the whole emission path.",
            "real_replacement": "Real requests against a real protected route for each algorithm (HS256/384/512, RS256) and each nbf position (post-dated within leeway, post-dated beyond leeway), asserting the real status code returned over the socket."
          },
          {
            "file": "test/postProtection.test.ts",
            "line": 30,
            "shape": "`mockRequest()` (line 30) and `mockResponse()` (line 45); call sites at 61-210",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "29 'mock' occurrences guarding POST protection - a write-path security gate. Asserting on captured objects means the gate is proven to have decided, not proven to have blocked.",
            "real_replacement": "Boot a real server with a real POST route and issue real POST requests: no token, expired token, wrong-secret token, valid token. Assert the real status codes and that on rejection the handler genuinely did not run (have the real handler write to a real temp file and assert the file is absent)."
          },
          {
            "file": "test/response.test.ts",
            "line": 23,
            "shape": "`mockServerResponse()` - object literal cast `as unknown as ServerResponse` with hand-written setHeader/getHeader/end; ~25 call sites (lines 252-480)",
            "stands_in_for": "a real node:http ServerResponse and its socket",
            "verdict": "VIOLATION",
            "reason": "The file has a real-server harness (see its own comment at lines 51-58, which says the flagged cases 'were rewritten to drive createResponse() against a REAL node:http ServerResponse over a real socket') - yet the double remains and is still used by ~25 assertions. So this is a half-finished migration, and the remaining half is the part that never proves bytes reach a client: `end()` here just assigns to a string.",
            "real_replacement": "Finish the migration that this file already started. Move the remaining ~25 cases onto the existing RealResult harness in the same file: run each probe inside a live request handler and assert on the status, headers and body the HTTP client actually received off the wire. No new infrastructure required - it is already there."
          },
          {
            "file": "test/responseMethods.test.ts",
            "line": 24,
            "shape": "`mockServerResponse()` cast to ServerResponse; ~14 call sites (lines 78-212)",
            "stands_in_for": "a real node:http ServerResponse",
            "verdict": "VIOLATION",
            "reason": "Same double as response.test.ts, covering the response helper methods (json/html/redirect/file etc.). Content-Type negotiation, header ordering and body encoding are asserted against a hand-written setHeader.",
            "real_replacement": "Reuse the real-server harness already present in test/response.test.ts (lines 51+): call each response method inside a live handler and assert on the real Content-Type, real status and real body bytes received by a real client."
          },
          {
            "file": "test/response-autoserialize.test.ts",
            "line": 23,
            "shape": "`mockServerResponse()`; call sites at 47-73",
            "stands_in_for": "a real node:http ServerResponse",
            "verdict": "VIOLATION",
            "reason": "Auto-serialization is precisely about what bytes and what Content-Type go on the wire for a given return value; measuring it against a captured string bypasses the only thing that matters.",
            "real_replacement": "Return each value type (object, array, string, Buffer, null, number) from a real route handler on a real server and assert on the real Content-Type header and real body bytes the client reads."
          },
          {
            "file": "test/sse.test.ts",
            "line": 22,
            "shape": "`mockStreamResponse()` (line 22, ~12 call sites), plus a second hand-built response with `const fakeSocket = { destroyed: false }` at line 285",
            "stands_in_for": "a real node:http ServerResponse and its real TCP socket, for Server-Sent Events",
            "verdict": "VIOLATION",
            "reason": "SSE is a streaming protocol - its correctness IS its socket behaviour: chunked framing, flush timing, heartbeat, and detection of a client hangup. The line-285 case fabricates the hangup by flipping a boolean on a plain object called fakeSocket; a real hangup produces a real ECONNRESET/EPIPE and a real 'close' event with different timing and different ordering relative to in-flight writes. This is the highest-risk transport double in the suite.",
            "real_replacement": "Boot a real server with a real SSE route, connect a real HTTP client, and assert on the real event frames arriving over the socket (including the real heartbeat with TINA4_SSE_HEARTBEAT set). For client disconnect, have the real client call req.destroy() (or socket.resetAndDestroy() for a real RST) mid-stream and assert the server stops writing, cleans up its connection registry, and logs once - all driven by the real 'close' event, not a boolean."
          },
          {
            "file": "test/cache.test.ts",
            "line": 169,
            "shape": "`const mockReq = { method, url } as Tina4Request` and `const mockRes = { raw: { writableEnded: false } } as Tina4Response`, passed to the real responseCache middleware at line 171",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "A two-property literal cast to the production type and handed to production middleware. The TTL-0 and non-GET passthrough branches are exercised, but with a response object so thin that any change requiring a real response method would surface as a TypeError in production and a PASS here.",
            "real_replacement": "Boot a real server with responseCache in the real pipeline and issue real requests: with ttl 0 assert two identical GETs both reach the real handler (handler increments a real counter); with a real ttl assert the second GET is served from cache with the real cache headers. The cache backends themselves can be real too - redis is UP on 6379."
          },
          {
            "file": "test/router.test.ts",
            "line": 145,
            "shape": "`const mockReq = {} as Tina4Request` and `const mockRes = { raw: { writableEnded: false } } as Tina4Response`, passed to the real runRouteMiddlewares at lines 149 and 155",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "An EMPTY object cast to Tina4Request. Any route middleware that touches req.headers, req.query or req.method would throw in production; here it is simply never called that way. The gating assertion ('blocking middleware returns false') is about a boolean, not about the request being blocked.",
            "real_replacement": "Register the real middlewares on a real route, boot a real server, and issue real requests - assert the allowed route returns the handler's real 200 body and the blocked route returns the real 403/redirect without the handler running (real handler writes a real temp file; assert absent)."
          },
          {
            "file": "test/smoke.test.ts",
            "line": 248,
            "shape": "`mockReq` object literal (line 248) and a callable `mockRes` assembled with Object.assign (line 253), passed to the real cors() middleware",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "The comment says 'Simulate CORS middleware call'. The assertion is only that next() was called - so the CORS section of the framework's flagship smoke test proves nothing about the headers CORS exists to set.",
            "real_replacement": "The smoke test already stands up real HTTP elsewhere in the file. Add a real route behind cors(), send a real cross-origin GET and a real preflight OPTIONS, and assert on the real Access-Control-Allow-Origin / -Methods / -Headers received by the client."
          },
          {
            "file": "test/errorOverlay.test.ts",
            "line": 81,
            "shape": "`const mockRequest = { method, url, path, headers, params, query }` passed to the real renderErrorOverlay() at line 93",
            "stands_in_for": "a real Tina4Request",
            "verdict": "VIOLATION",
            "reason": "A hand-built request handed to production rendering code. Because the overlay renders request details into HTML, this also means the escaping of REAL header values (which can contain quotes, angle brackets, or attacker-controlled content) is never exercised with anything a real parser produced.",
            "real_replacement": "Boot a real server in debug mode with a route that genuinely throws, issue a real request carrying real headers and real query params (including a header value containing `<script>`), and assert the real HTML the client receives contains the Request Details section AND has properly escaped the hostile value."
          },
          {
            "file": "test/corsPolicyConformance.test.ts",
            "line": 231,
            "shape": "`function capture()` returning a callable `res` with hand-written `header()` and a `raw.getHeader` reading from the same local object",
            "stands_in_for": "the real node:http ServerResponse",
            "verdict": "VIOLATION",
            "reason": "The rest of this file is genuinely real ('NO MOCKS. One server per policy'), which makes this local double easy to miss - it sits at line 231, well below the honest header. It is used for the cors() vs CorsMiddleware.beforeCors equivalence check, i.e. the exact assertion that caught TINA4_CORS_CREDENTIALS becoming a silent no-op. Comparing two implementations through a shared fake response can show them agreeing while both are wrong at the real response layer.",
            "real_replacement": "Use the file's own real-server harness twice: boot one real server wired with cors() and another wired with CorsMiddleware, send the identical real request to both, and compare the real header sets the HTTP client receives. That proves equivalence at the layer that actually ships."
          },
          {
            "file": "test/envDefaults.test.ts",
            "line": 29,
            "shape": "`makeReqRes()` returning `req: any` and a callable `res: any` with a hand-written `header()`; the docstring at line 25 calls them 'Minimal Tina4Request / Tina4Response doubles'",
            "stands_in_for": "the real node:http request/response",
            "verdict": "VIOLATION",
            "reason": "Self-described doubles. The assertion 'Allow-Credentials header NOT sent' is checked by finding the key absent from an object the test populated - which cannot distinguish 'the framework did not set it' from 'the framework set it by a route this fake does not implement' (e.g. via res.raw.setHeader rather than res.header).",
            "real_replacement": "Boot a real server with default env and assert the real response has no Access-Control-Allow-Credentials header (check the real headers object the HTTP client received, which sees every emission route). Then set TINA4_CORS_CREDENTIALS=true and assert it IS present. Reuse the real harness in test/corsPolicyConformance.test.ts."
          },
          {
            "file": "test/request.test.ts",
            "line": 25,
            "shape": "`fakeIncoming()` (line 25) and `fakeIncomingWithBody()` (line 35) - construct `new IncomingMessage(new Socket())` on an UNCONNECTED socket, then assign `req.url`, `req.method` and `req.headers` directly and `push()` the body",
            "stands_in_for": "a real HTTP request as produced by Node's HTTP parser off a real socket",
            "verdict": "VIOLATION",
            "reason": "This is the most charitable-looking hit in the suite and I nearly cleared it: the class IS the production class and the Socket IS a real net.Socket. But the socket is never connected and no bytes are ever parsed - the test ASSIGNS req.headers as a plain object, which substitutes for Node's real HTTP header parser. Everything that parser does (lowercasing, duplicate folding, the special set-cookie array, malformed-header rejection, header-count and size limits, chunked transfer decoding) is bypassed. The x-forwarded-for, multipart and malformed-JSON cases are precisely the ones where the real parser's output differs from a hand-written literal.",
            "real_replacement": "Boot a real node:http server on an ephemeral port and send real requests with node:http (or a raw net.Socket writing literal request bytes when you want to control exact framing). Capture the real IncomingMessage inside the real handler, pass it to createRequest(), and assert. Raw-socket writes let you drive the genuinely nasty cases for real: duplicate headers, a real chunked body, a real multipart/form-data payload with real boundaries, and genuinely malformed JSON bytes."
          },
          {
            "file": "test/apiTransfer.test.ts",
            "line": 444,
            "shape": "`realTransport` - a function passed as the `transport` option to the real Api class",
            "stands_in_for": "nothing - it performs real socket I/O to a second real http.Server started at line 431",
            "verdict": "EXEMPT",
            "reason": "Inspected specifically because an injected 'transport' is the classic hiding place for a double, and this one is not. It opens a real socket to a real backend server and returns that server's real response, including a real Set-Cookie the real jar then stores. No canned data, no simulated failure, no stand-in implementation - it is an alternate REAL transport, which is what the injection seam exists for. The file also verifies the default no-transport path against a second real server (lines 496-503), so the seam is proven not to change the real network behaviour.",
            "real_replacement": "n/a - already real. Keep it as the reference example of a legitimate injection seam for the rest of the suite."
          },
          {
            "file": "test/frond.test.ts",
            "line": 439,
            "shape": "a Frond filter registered in-test under the name `spy`, recording its arguments into `spyCalls` (used at lines 445, 454, 458)",
            "stands_in_for": "nothing - pure template-expression evaluation with no dependency",
            "verdict": "EXEMPT",
            "reason": "Matched the 'spy' search pattern but is not a test double: it is a user-supplied filter registered through Frond's real, public extension point, used to observe evaluation order of the real template engine over in-memory strings. There is no external collaborator anywhere in the case - no filesystem, socket, DB or logger - and nothing is substituted for a real dependency. Pure logic over inputs.",
            "real_replacement": "n/a - no dependency and no double."
          },
          {
            "file": "test/seederOverhaul.test.ts",
            "line": 213,
            "shape": "`Object.defineProperty(Author, 'name', { value: 'Author' })` (also lines 214, 259, 260)",
            "stands_in_for": "nothing - it restores a class's own name after transpilation, on real BaseModel subclasses backed by a real database",
            "verdict": "EXEMPT",
            "reason": "Matched the defineProperty/global-patching sweep and I checked it rather than assuming. It sets a class's `name` to its own correct value so the seeder's real constructor.name-based table resolution works under tsx, and the models are real BaseModel subclasses writing real rows to a real database. Nothing is substituted for a collaborator and no behaviour is faked. Contrast with test/migrationFootguns.test.ts:47, where classes are NAMED to impersonate real adapters and their method bodies are faked - that one is a VIOLATION.",
            "real_replacement": "n/a - no double. (Worth a note that relying on constructor.name is fragile under minification, but that is a design observation, not a mock-rule finding.)"
          }
        ],
        "could_not_verify": [
          "I did NOT run the full 227-file suite. I executed 4 files to prove the doubles are live and load-bearing rather than dead code, all on Node v24.9.0 / tsx 4.21.0 with all 7 services UP: test/sessionBackendFailure.test.ts (16 passed, 0 failed), test/websocketHardening.test.ts (39/0), test/migrationFootguns.test.ts (88/0), test/csrfMiddleware.test.ts (32/0). All four passed WITHOUT contacting any of the live services, which is the finding. Every other hit in this inventory was adjudicated by reading the source, not by execution - so the classification is verified but the runtime behaviour of those specific doubles is not.",
          "test/metrics-cli.test.ts:64 (process.stdout.write patch): I could not observe it execute. run-all.ts line 41 sets skipMetrics from `TINA4_SKIP_METRICS ?? '1'`, so metrics.test.ts, metrics-cli.test.ts, metrics-nested-complexity.test.ts, metrics-offender-cap.test.ts, metricsCoverage.test.ts and metrics-dispatch-pipeline.test.ts are SKIPPED by default in a normal `npm test`. The double is real in the source; whether it ever runs in CI, I could not confirm.",
          "The two vitest files (test/i18n.test.ts, test/i18n-leaf-alias.test.ts) run under the separate `test:i18n` npm script and I did not execute them. I read them: neither contains vi.fn/vi.mock/vi.spyOn (both greps returned 0 against a control that returned 2388), and i18n-leaf-alias.test.ts:179 'Simulate the auto-wire logic from server.ts' calls the REAL I18n and REAL Frond, so I did not file it as a double - but that judgement is from reading only.",
          "test/envLocalPrecedence.test.ts:16 says it 'replicates the exact boot load sequence' from server.ts. I read it and it calls the REAL loadEnv twice in the documented order against real .env files, so no double object exists and I did not file it. It does duplicate an ORDERING decision from server.ts, which will drift the same way the three auth reimplementations already have - flagging it as a risk, not as a rule violation.",
          "I did not verify whether the shipped TestClient (used by test/parityTestClass.test.ts, test/testClientAuth.test.ts, test/testClientFrontController.test.ts) constructs its node:http IncomingMessage/ServerResponse from real parsed bytes or assembles them in-process. The test comments claim 'real node:http IncomingMessage/ServerResponse objects - no mock collaborator'. It is FRAMEWORK source, not test source, so it is outside this scan's scope - but if it assembles them the way test/request.test.ts:25 does, then every test that relies on TestClient inherits that same gap. This is worth a follow-up scan of packages/core/src.",
          "Scope note: the task scoped me to /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/test. The repo also has a sibling top-level tests/ directory containing exactly 1 file (tests/test_testing.ts); I grepped it for mock/stub/spy/fake/dummy and got zero hits, but it is otherwise outside this inventory.",
          "Line numbers are from branch v3 at commit a6bda71 ('Stop the Node test run launching browser tabs'). The working tree is not a git repo at the scan root (/Users/andrevanzuydam/IdeaProjects), so I confirmed the branch and commit from inside tina4-nodejs itself; I did not check whether the tree has uncommitted modifications."
        ]
      }
    ],
    "total_doubles": 179,
    "total_violations": 154
  },
  "workflowProgress": [
    {
      "type": "workflow_phase",
      "index": 1,
      "title": "Inventory"
    },
    {
      "type": "workflow_phase",
      "index": 2,
      "title": "Parity"
    },
    {
      "type": "workflow_phase",
      "index": 3,
      "title": "Convert"
    },
    {
      "type": "workflow_phase",
      "index": 4,
      "title": "Verify"
    },
    {
      "type": "workflow_agent",
      "index": 1,
      "label": "inventory:python",
      "phaseIndex": 1,
      "phaseTitle": "Inventory",
      "agentId": "a78fc9b43fa4446b1",
      "model": "claude-opus-5",
      "state": "done",
      "startedAt": 1785565240850,
      "queuedAt": 1785565240833,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "pytest 9.0.2 / Python 3.13.5 (.venv) on macOS 26.5.2. Repo:…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785565948313,
      "tokens": 171621,
      "toolCalls": 58,
      "durationMs": 707461,
      "resultPreview": "{\"framework\":\"pytest 9.0.2 / Python 3.13.5 (.venv) on macOS 26.5.2. Repo: /Users/andrevanzuydam/IdeaProjects/tina4-python, branch v3 @ fb6fcb2 (\\\"Confine response.file() to a root in all four\\\"), framework version 3.13.94. Doubles are stdlib unittest.mock (MagicMock/patch/patch.dict), pytest monkeypatch (setattr/setitem), and hand-rolled in-test classes. NOTE: the MagicMock Redis/Valkey/Mongo sess…"
    },
    {
      "type": "workflow_agent",
      "index": 2,
      "label": "inventory:php",
      "phaseIndex": 1,
      "phaseTitle": "Inventory",
      "agentId": "a61dc8c2ed7ac87d5",
      "model": "claude-opus-5",
      "state": "done",
      "startedAt": 1785565240852,
      "queuedAt": 1785565240833,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "PHPUnit 11.5.55 on PHP 8.5.7, tina4-php branch v3 @ e5e00b2…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785565692266,
      "tokens": 118268,
      "toolCalls": 51,
      "durationMs": 451414,
      "resultPreview": "{\"framework\":\"PHPUnit 11.5.55 on PHP 8.5.7, tina4-php branch v3 @ e5e00b28 (\\\"Confine response.file() to a root in all four\\\"). Runs verified with ./vendor/bin/phpunit --no-coverage against /Users/andrevanzuydam/IdeaProjects/tina4-php/phpunit.xml. Service ports re-verified UP on 127.0.0.1 right now: redis 6379, valkey 6380, redis-ish 6381, memcached 11211, Mongo 27017, Postgres 55432, MySQL 3306. …"
    },
    {
      "type": "workflow_agent",
      "index": 3,
      "label": "inventory:ruby",
      "phaseIndex": 1,
      "phaseTitle": "Inventory",
      "agentId": "ab49d42851847c67a",
      "model": "claude-opus-5",
      "state": "done",
      "startedAt": 1785565240853,
      "queuedAt": 1785565240833,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "RSpec 3.13 (rspec-core 3.13.6, rspec-mocks 3.13.8, rspec-ex…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785565830252,
      "tokens": 137890,
      "toolCalls": 49,
      "durationMs": 589398,
      "resultPreview": "{\"framework\":\"RSpec 3.13 (rspec-core 3.13.6, rspec-mocks 3.13.8, rspec-expectations 3.13.5) on Ruby 4.0.2 arm64-darwin25, repo /Users/andrevanzuydam/IdeaProjects/tina4-ruby branch v3 @ 1784943 \\\"Confine response.file() to a root in all four\\\". spec_helper.rb:123-124 sets mock_with :rspec, verify_partial_doubles = true. The rule is verbatim in tina4-ruby/CLAUDE.md line 27 and explicitly names \\\"RSp…"
    },
    {
      "type": "workflow_agent",
      "index": 4,
      "label": "inventory:nodejs",
      "phaseIndex": 1,
      "phaseTitle": "Inventory",
      "agentId": "a493485c986416a90",
      "model": "claude-opus-5",
      "state": "done",
      "startedAt": 1785565240853,
      "queuedAt": 1785565240833,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "lastToolSummary": "No third-party mocking library is present anywhere. jest.fn…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785565871552,
      "tokens": 151060,
      "toolCalls": 48,
      "durationMs": 630699,
      "resultPreview": "{\"framework\":\"No third-party mocking library is present anywhere. jest.fn/jest.mock/jest.spyOn = 0 hits, vi.fn/vi.mock/vi.spyOn = 0, sinon = 0, node:test mock.method/mock.fn = 0. The suite is a hand-rolled harness: 225 of 227 *.test.ts files define their own `function assert(name, condition)` and are spawned one-per-child-process by test/run-all.ts under `npx tsx`. Exceptions: test/i18n.test.ts an…"
    },
    {
      "type": "workflow_agent",
      "index": 5,
      "label": "THE RULE, as stated verbatim in every repo's CLAUDE.md:",
      "phaseIndex": 2,
      "phaseTitle": "Parity",
      "agentId": "ae3bfff33634b0e49",
      "model": "claude-opus-5",
      "state": "done",
      "startedAt": 1785565948333,
      "queuedAt": 1785565948331,
      "attempt": 1,
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785566280615,
      "tokens": 125736,
      "toolCalls": 0,
      "durationMs": 332274,
      "resultPreview": "# TINA4 MOCK-RULE CROSS-FRAMEWORK SYNTHESIS\n\nSource: the four supplied inventories (tina4-python v3 @ fb6fcb2, tina4-php v3 @ e5e00b28, tina4-ruby v3 @ 1784943, tina4-nodejs v3 @ a6bda71 - all four sitting on the same \"Confine response.file() to a root in all four\" commit). **I did not re-run any scan or any suite.** Everything below is derived from the four inventories as filed; where they disagr…"
    },
    {
      "type": "workflow_agent",
      "index": 6,
      "label": "convert:python",
      "phaseIndex": 3,
      "phaseTitle": "Convert",
      "agentId": "ae12042babb9a2d58",
      "model": "claude-opus-5",
      "state": "error",
      "startedAt": 1785566324619,
      "queuedAt": 1785566324304,
      "attempt": 1,
      "lastToolName": "Bash",
      "lastToolSummary": "cd /Users/andrevanzuydam/IdeaProjects/.worktrees/no-mock-sw…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785567791492,
      "error": "You've hit your session limit · resets 12pm (Africa/Johannesburg)",
      "tokens": 183579,
      "toolCalls": 46,
      "durationMs": 1466851
    },
    {
      "type": "workflow_agent",
      "index": 7,
      "label": "convert:php",
      "phaseIndex": 3,
      "phaseTitle": "Convert",
      "agentId": "ac135a4ec74ded0b5",
      "model": "claude-opus-5",
      "state": "error",
      "startedAt": 1785566324950,
      "queuedAt": 1785566324308,
      "attempt": 1,
      "lastToolName": "Bash",
      "lastToolSummary": "cd /Users/andrevanzuydam/IdeaProjects/.worktrees/no-mock-sw…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785567796235,
      "error": "You've hit your session limit · resets 12pm (Africa/Johannesburg)",
      "tokens": 208051,
      "toolCalls": 93,
      "durationMs": 1471284
    },
    {
      "type": "workflow_agent",
      "index": 8,
      "label": "convert:ruby",
      "phaseIndex": 3,
      "phaseTitle": "Convert",
      "agentId": "a05bddd504af98d25",
      "model": "claude-opus-5",
      "state": "error",
      "startedAt": 1785566324969,
      "queuedAt": 1785566324310,
      "attempt": 1,
      "lastToolName": "Bash",
      "lastToolSummary": "until grep -aq \"EXIT=\" /private/tmp/claude-501/-Users-andre…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785567788723,
      "error": "You've hit your session limit · resets 12pm (Africa/Johannesburg)",
      "tokens": 289447,
      "toolCalls": 148,
      "durationMs": 1463754
    },
    {
      "type": "workflow_agent",
      "index": 9,
      "label": "convert:nodejs",
      "phaseIndex": 3,
      "phaseTitle": "Convert",
      "agentId": "a69dc6feac0f3e571",
      "model": "claude-opus-5",
      "state": "error",
      "startedAt": 1785566325022,
      "queuedAt": 1785566324317,
      "attempt": 1,
      "lastToolName": "Bash",
      "lastToolSummary": "cd /Users/andrevanzuydam/IdeaProjects/.worktrees/no-mock-sw…",
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785567801930,
      "error": "You've hit your session limit · resets 12pm (Africa/Johannesburg)",
      "tokens": 277459,
      "toolCalls": 90,
      "durationMs": 1476908
    },
    {
      "type": "workflow_agent",
      "index": 10,
      "label": "THE RULE, as stated verbatim in every repo's CLAUDE.md:",
      "phaseIndex": 4,
      "phaseTitle": "Verify",
      "agentId": "a995bdd678c289efd",
      "model": "claude-opus-5",
      "state": "error",
      "startedAt": 1785567801931,
      "queuedAt": 1785567801931,
      "attempt": 1,
      "promptPreview": "THE RULE, as stated verbatim in every repo's CLAUDE.md:\n\n  \"NO mock testing. Mocks are not acceptable in any circumstances. A test double (mock, stub,\n  fake, spy, monkeypatch, or any in-test object standing in for a real collaborator) may never\n  substitute for a real dependency, under any justification. There is no 'supplement' exception\n  and no 'hard to reproduce' exception.\"\n\nThe ONLY exempt …",
      "lastProgressAt": 1785567802828,
      "error": "You've hit your session limit · resets 12pm (Africa/Johannesburg)",
      "tokens": 0,
      "toolCalls": 0,
      "durationMs": 897
    }
  ],
  "totalTokens": 1663111,
  "totalToolCalls": 583
}
