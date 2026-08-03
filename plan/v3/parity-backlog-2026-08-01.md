# Parity backlog: every place the swap is broken

Generated 2026-08-01 from two independent read-only audits - the substitutability
audit (6 pluggable subsystems) and the features 1-20 re-audit. Judged against
[ADR-0024](decisions/ADR-0024.md): identical application code, identical
OBSERVABLE outcome, on every provider.

**85 findings break the swap. 78 are MEASURED (a probe was run), 7 INFERRED.**

Two facts that shape the work:

- **No framework is the reference.** php 57, ruby 56, node 56, python 55 - the
  breaks are spread almost evenly. "Python is master" does not apply on this
  axis; the reference has to be chosen per finding, on merit.
- **24 of the 85 fixes are DELETIONS**, and only one is "narrow the contract".
  Most swap breaks are one framework doing something EXTRA that the others do
  not. That is the minimal-code principle paying for itself: the fix is
  subtraction, not another abstraction.

Every feature audited came back with at least one finding, including the ten
already marked closed and shipped. The July pass judged SOLID, DRY, LOC and CC -
none of which ask whether the same code behaves the same on another provider, so
nothing was looking.

## Credential exposure  (9, all FIXED 2026-08-03)

Seven measured defects plus two found while fixing them. Recorded because the
SHAPE recurs, not because they are open.

### PostgreSQL DSN parameter injection via the password (php) - FIXED, mutation-proven

MEASURED on a live PostgreSQL. The password was concatenated UNESCAPED into a
libpq space-separated keyword/value DSN, so a space in the password injected
further parameters and last-occurrence-wins let them override earlier ones:

    password "tina4"                 -> connected to tina4_py   (as the URL said)
    password "tina4 dbname=postgres" -> connected to postgres   (a DIFFERENT database)

The same mechanism reaches `sslmode=disable`, silently dropping TLS on a
connection the operator believes is encrypted. Reverting the single call to
`quoteDsnValue()` makes the live injection work again - that is the gate.

### The dev server published the database URL, password included (php) - FIXED

`/__dev/api/status` and `/__dev/api/system` are PUBLIC GETs and both returned
`getenv("TINA4_DATABASE_URL")` VERBATIM. Anything that could reach the dev port
could read a URL-embedded password. Found while fixing the cluster, not by the
audit that went looking for credential leaks - which is the point: the audit
looked at the URL PARSER, and the leak was in a status endpoint.

### A malformed TINA4_DATABASE_URL wrote the password into the exception - ALL FOUR - FIXED

That message reaches the boot log, a crash report, the error overlay and CI.
Note the parent's first probe reported python SAFE; it was not - the probe had
hit urllib's port-cast error instead of python's own `Invalid URL format`
branch (database_url.py:187), which leaks like the other three. A single
negative probe is not proof of absence; probe every branch.

### The redaction helper had no call sites on any real path - ALL FOUR - FIXED

`toSafeString`/`to_safe_string` had ZERO call sites in php and node, and in
python and ruby was reached only from `__repr__`/`#inspect` - while its own
docblock calls it "the ONLY form allowed in a log line".

### to_safe_string() returned the ODBC string verbatim including PWD= - FIXED

The negative test `to_safe_string_never_contains_the_password` EXISTED IN ALL
FOUR AND PASSED, because the shared corpus had no odbc row. Identical to the
dotenv corpus: the guard exists, the test is green, and it protects nothing
because the fixture lacks the row that matters. THIS IS THE RECURRING SHAPE -
when adding a guard, add the corpus row that can fail it.

### KNOWN RESIDUAL: php var_export($url) still prints the password

PHP gives objects no hook for `var_export` - `__debugInfo` covers only
`print_r`/`var_dump`, and `__set_state` is for import. The real fix is to stop
holding the password as a plain property. Flagged rather than bodged.

### OWED: nobody has hunted for leak paths BEYOND these

The adversarial verifier for this batch died on a usage limit before running.
The two extra findings above were incidental. A deliberate sweep - malformed
URL, dead-host connect, wrong credentials, dump/serialize, ODBC url, traceback,
env-built url, across all four - has NOT been done.

## Test-harness service gates  (1)

### A service gate that tests REACHABILITY turns a skip into a FAILURE when the service is reachable but unusable

MEASURED 2026-08-01 on the macOS dev box. `tests/test_batch_insert.py` guards its
MySQL/MSSQL cases with:

    @pytest.mark.skipif(not (_has_mysql_connector() and _reachable(_MYSQL_HOST, _MYSQL_PORT)), ...)

A stray local MySQL container answers on localhost:3306, so `_reachable` is TRUE
and the test does NOT skip. Nothing exports `TINA4_TEST_MYSQL_*` locally, so the
test falls back to its defaults (`root`, empty password) and the real server
answers:

    Access denied for user 'root'@'172.17.0.1' (using password: NO)

The result is a FAILURE where the intent was a SKIP - and because it presents as
an ordinary red test, it gets normalised as "the known credential gap" and stops
being read. It survived hours of runs that way today.

The guard tests a PROXY (is the port open) instead of the real condition (can I
authenticate and use this service). The same shape as the other defects in this
backlog: a check standing in for the thing it is meant to verify.

Fix direction: the gate should attempt a real connection+auth, not a socket
probe, and distinguish three states - absent (skip), present-and-usable (run),
present-but-unusable (FAIL LOUD with the credential contract named, or skip
explicitly when TINA4_REQUIRE_SERVICES is unset). Note the lab exports BOTH
`TINA4_TEST_MYSQL_USERNAME` and `TINA4_TEST_MYSQL_USER`, which is why .99 is
green while a developer box is not.

## fetch() result envelope - count semantics, the COUNT probe, and the LIMIT detector  (6)

### A COLUMN NAMED `rate_limit` DEFEATS THE ROW CAP ENTIRELY - unbounded read in 3 of 4

MEASURED 2026-08-01, real SQLite, 150 rows, table `t (id INTEGER PRIMARY KEY, rate_limit INTEGER)`:

| query | python | ruby | node | php |
| ----- | ------ | ---- | ---- | --- |
| `SELECT id FROM t`             | 100 | 100 | 100 | 100 |
| `SELECT id, rate_limit FROM t` | **150** | **150** | **150** | 100 |

The "does this SQL already carry its own LIMIT?" test is a PLAIN SUBSTRING MATCH in Python,
Ruby and Node (`sql.upper().split("--")[0]` contains `"LIMIT"`). Any identifier containing
the letters l-i-m-i-t - `rate_limit`, `limit_amount`, `daily_limit`, `limit_reached` - reads
as an existing LIMIT clause, so no cap is appended and the full table comes back. This is the
exact unbounded full-table read the cap exists to prevent, reachable through an ordinary
column name with no unusual SQL.

PHP is correct here: `SqlNormalizerTrait::hasTrailingLimit` matches LIMIT ANCHORED to
end-of-string. PHP's anchoring is the design to promote - but see the two PHP crashes below,
because PHP pairs the right anchor with the wrong comment handling.

### Ruby's `DatabaseResult.limit` is ALWAYS 10, whatever limit was applied

MEASURED: a 150-row table, `db.fetch("SELECT * FROM t")` returns `records=100 count=100
limit=10 offset=0`. `Database#fetch_direct` never passes `limit:`/`offset:`/`count:`, so the
`limit: 10` default in `DatabaseResult#initialize` is what the envelope reports. The result
describes a page size that was never used.

That 10 is the SAME stale v2 number as the buried PHP test's asserted cap and the
`limit=10` line in tina4-python CLAUDE.md - the fourth place the v2 value outlived v2.


### `count` means "total matching rows" in Python/PHP and "rows returned" in Ruby/Node, so identical pagination code paginates differently

MEASURED 2026-08-01 on a real 150-row SQLite table, `fetch()` with no limit argument (cap 100):

| framework | records | count |
| --------- | ------- | ----- |
| python    | 100     | 150   |
| php       | 100     | 150 (`total`) |
| ruby      | 100     | 100   |
| node      | 100     | 100   |

`pages = ceil(result.count / limit)` yields 2 on Python/PHP and 1 on Ruby/Node. Same code,
same data, same config - a paginated list silently loses every page after the first on two
of four frameworks.

Python/PHP are correct. Django's `Paginator.count`, Laravel's `total()` and Kaminari's
`total_count` all mean TOTAL MATCHING (ADR-0012 authority order: mainstream frameworks over
internal precedent). On the Ruby/Node reading `count` is redundant - it always equals
`records.length` - so the whole `records`/`count`/`limit`/`offset` envelope carries no
pagination information at all.

BREAKING for Ruby and Node. Ruby's `fetch` runs no COUNT probe; Node's wrapper likewise.

### PHP `fetch()` RAISES on a trailing line comment, because the COUNT wrapper swallows the closing paren

MEASURED: `SELECT * FROM items LIMIT 3 -- c` raises
`SQLite3 fetch() failed: Unable to prepare statement: incomplete input`. `fetch()` builds
`SELECT COUNT(*) as total FROM ({$sql})`, and the trailing `--` comments out the `)`.
Python, Ruby and Node all return 3 rows for the same query.

### PHP `fetch()` RAISES on a trailing BLOCK comment, because the trailing-LIMIT detector only strips line comments

MEASURED: `SELECT * FROM items LIMIT 3 /* c */` raises
`Unable to prepare statement: near "LIMIT": syntax error`. `SqlNormalizerTrait::hasTrailingLimit`
strips `--` comments and trailing semicolons but not `/* */`, so the anchored end-of-string
LIMIT match fails and a SECOND `LIMIT 100 OFFSET 0` is appended. Python and Ruby avoid this
by accident, not by design: their detector is the LOOSE `sql.upper().split("--")[0]` contains
"LIMIT", which matches a LIMIT anywhere in the statement.

### Python returns `count = 0` alongside 3 real records when the COUNT probe fails

MEASURED: `SELECT * FROM items LIMIT 3 -- c` returns 3 records with `count = 0`. The probe is
wrapped in a bare `except: total = 0`, so a broken probe is indistinguishable from an empty
table. PHP fails LOUDLY on the same query and Ruby/Node get it right; Python is the only one
that returns a WRONG NUMBER silently, which is the harder failure to notice.

## Session backends  (6)

### Ruby: TINA4_SESSION_TTL is honoured by the memcached backend ONLY — every other backend hard-codes 86400

- **frameworks:** tina4-ruby only (Python, PHP, Node all pass the configured TTL to every handler)
- **confidence:** MEASURED
- **same code, different outcome:** With TINA4_SESSION_TTL=60, the same app on Ruby stores a session that lives 86400 seconds on file/redis/valkey/mongodb/database and 60 seconds on memcached. The Set-Cookie says Max-Age=60 on all of them. Root cause: Session#save calls safe_write(@id, @data) with NO ttl (session.rb:135, 370-375), so every handler falls back to its own default; only MemcachedHandler reads ENV["TINA4_SESSION_TTL"] (memcached_handler.rb:46). Valkey uses a third, unique variable TINA4_SESSION_VALKEY_TTL (valkey_handler.rb:14) that exists in no other backend and no other framework.
- **discovered:** Never, on the happy path. It bites as a security finding (sessions configured for 10 minutes remain resumable for 24 hours server-side after the cookie is gone), or as an outage the day someone swaps redis for memcached and every user starts being logged out 1440x sooner.
- **evidence:** Ran with TINA4_SESSION_TTL=60 against the real handlers: `ruby FileHandler @ttl = 86400`, `ruby MemcachedHandler @ttl = 60`, and FileHandler#write (the exact call Session#save makes) stored `_expires - now = 86400`. Python contrast, same env var: `python Session._ttl = 60`, stored `_expires - now = 60`. Code: /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/session.rb:135 and :370-375; file_handler.rb:11; redis_handler.rb:20; valkey_handler.rb:14; mongo_handler.rb:15; database_handler.rb:19; memcached_handler.rb:46.

### Node: the `database` session backend is SQLite-only and THROWS at Session construction on any other engine

- **frameworks:** tina4-nodejs only (Python/PHP/Ruby route the database backend through the generic ORM adapter and work on postgres/mysql/mssql/firebird)
- **confidence:** MEASURED
- **same code, different outcome:** Identical app code with TINA4_SESSION_BACKEND=database: on SQLite `new Session("database")` returns a working session; with TINA4_DATABASE_URL=postgres://… the constructor throws. The Node handler drives `node:sqlite` DatabaseSync directly (databaseHandler.ts:12, 46-51) and resolveDbPath() raises on any non-sqlite scheme (databaseHandler.ts:76-94). Python resolves ORM._get_db() (session/__init__.py:284-289), PHP resolves Database::fromEnv() (DatabaseSessionHandler.php:47), Ruby resolves Tina4::ORM.db (session.rb:476-478) — all engine-agnostic.
- **discovered:** At deploy. Develop on SQLite with database-backed sessions, point TINA4_DATABASE_URL at the production Postgres, and Session construction throws on the first request that touches a session. The upgrade path is severed, not degraded — exactly the shape of the Node rabbitmq/kafka queue defect.
- **evidence:** npx tsx probe against packages/core/src/session.ts: `TINA4_DATABASE_URL=sqlite -> OK, id=e4eacc10...` / `TINA4_DATABASE_URL=postgres -> THREW at Session construction: The "database" session backend is SQLite-only, but TINA4_DATABASE_URL is a "postgres" URL...`. Code: /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/core/src/sessionHandlers/databaseHandler.ts:76-94 and packages/core/src/session.ts:438-441.

### Python: a session-backend failure on the real HTTP path is SILENT — request.session becomes None with nothing logged

- **frameworks:** tina4-python only (PHP Router::dispatch and Node dispatchPipeline construct Session unguarded, so the failure surfaces loudly)
- **confidence:** MEASURED
- **same code, different outcome:** tina4_python/core/server.py:1376-1406 wraps the whole per-request session bootstrap in `try: ... except Exception: pass`. With TINA4_SESSION_BACKEND=file the route sees a live session. With a typo (`redsi`) the documented startup ValueError is swallowed and the route serves 200 with request.session = None. With TINA4_SESSION_BACKEND=database and the DB unreachable, the same: 200, session None, zero log lines. Both the advertised 'an unrecognised backend name RAISES at startup' and the advertised 'log-loud + degrade' are defeated on the only path that matters.
- **discovered:** Silently in production. Any route doing request.session.get(...) raises AttributeError -> 500; any route guarding with `if request.session:` silently skips auth/flash/CSRF and looks healthy. Nothing is written to the log to connect it to the session store.
- **evidence:** Dispatched through the real front controller via TestClient: `backend=file status=200 body={"session_is_none":false}`, `backend=redsi status=200 body={"session_is_none":true}`, `backend=database status=200 body={"session_is_none":true}` (TINA4_DATABASE_URL=postgresql://127.0.0.1:55499/nope). A re-run of the redsi case captured ZERO log output. Code: /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/core/server.py:1376 and :1405-1406.

### The `database` backend does network I/O in the HANDLER CONSTRUCTOR, outside the log-loud + degrade policy

- **frameworks:** tina4-python, tina4-ruby, tina4-nodejs. PHP is the ONLY one that gets it right (handlers are lazily constructed inside dispatchLoad/dispatchSave, so a construction failure lands inside safeRead/safeWrite)
- **confidence:** MEASURED
- **same code, different outcome:** Same app, same code, store unreachable: redis/valkey/mongodb/memcached construct fine, log one Log.error and degrade (save() -> False, request still serves). `database` raises out of the Session constructor before any safe* wrapper exists — Python OperationalError, Ruby Tina4::DatabaseConnectionError, Node throws from `new DatabaseSync(...)`/resolveDbPath. The four CLAUDE.md files all state the policy covers 'a backend (Redis/Valkey/Mongo/DB) that becomes unreachable mid-request'; it does not cover the DB.
- **discovered:** During the first production DB blip. Redis-backed deployments ride it out with an empty session; database-backed deployments 500 every request (Ruby/Node) or go silently sessionless (Python, see the finding above). A local SQLite dev box never reproduces it because SQLite cannot be 'down'.
- **evidence:** Python probe (store down): `redis -> Session() OK; start() OK; save()->False` (+ Log.error), same for mongodb and memcached, but `database -> Session() CONSTRUCTOR raised OperationalError: connection to server at "127.0.0.1", port 55499 failed`. Ruby probe: `Tina4::SessionHandlers::DatabaseHandler.new({}) -> RAISED Tina4::DatabaseConnectionError`. PHP contrast probe: `database: Session() OK; start() OK; save()->false` and `redis: Session() OK; start() OK; save()->false`. Code: python session/__init__.py:133-146 + :284-289; ruby session.rb:100 + database_handler.rb:18-22 + :74-76; node session.ts:438-441 + databaseHandler.ts:46-51; PHP contrast Session.php:1082-1088 (lazy getDbHandler) reached only from dispatchLoad under safeRead.

### Ruby: the mongodb session backend hard-requires the `mongo` gem; the other three frameworks ship a zero-dependency wire-protocol fallback

- **frameworks:** tina4-ruby only
- **confidence:** INFERRED
- **same code, different outcome:** TINA4_SESSION_BACKEND=mongodb on Ruby: `require "mongo"` inside MongoHandler#initialize; on LoadError it re-raises a bare RuntimeError('MongoDB session handler requires the "mongo" gem. Install with: gem install mongo') out of Session.new. Python falls back to a raw OP_MSG codec when pymongo is absent (mongodb_handler.py:52-59, :183-272), PHP is raw fsockopen OP_MSG with no driver at all (MongoSessionHandler.php:161, :189), Node falls back to a raw OP_MSG worker when `mongodb` is not resolvable (mongoClient.ts:76-79). Ruby has no fallback path.
- **discovered:** At deploy, on a slim production image. The app boots on `file` locally, the operator flips one env var to mongodb, and the Ruby process raises on the first request that constructs a session. The framework advertises 'zero dependencies' for the peer backends (Ruby's own redis/valkey handlers fall back to RespClient when the redis gem is missing — redis_handler.rb:72-78), so the asymmetry is invisible until it fires.
- **evidence:** /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/session_handlers/mongo_handler.rb:14 (`require "mongo"`) and :22-23 (`rescue LoadError; raise "MongoDB session handler requires the 'mongo' gem..."`). Not MEASURED because the `mongo` gem IS installed on this host (`mongo gem: PRESENT`), so the LoadError branch cannot be reached without uninstalling it — which would mutate the environment.

### memcached: any TTL above 2592000 seconds (30 days) is sent raw and memcached reads it as an absolute 1970 timestamp — the session expires instantly

- **frameworks:** all four (tina4-python, tina4-php, tina4-ruby, tina4-nodejs) — identical defect in each memcached handler
- **confidence:** INFERRED
- **same code, different outcome:** Set TINA4_SESSION_TTL=2592001 (30 days + 1s, a plausible 'remember me' value). On file/redis/valkey/mongodb/database the session lives 30 days. On memcached every handler emits `set <key> 0 2592001 <bytes>`; the memcached text protocol specifies that an expiry larger than 60*60*24*30 is interpreted as an absolute Unix time rather than an offset, so 2592001 is 1970-01-31 — already in the past — and the item is dead on arrival. Every write appears to succeed (STORED), and every subsequent read is a clean miss, so it reads as 'no session yet', not as an error. None of the four handlers clamps or converts.
- **discovered:** Only in production, and only on memcached. save() returns true, no error is logged, the store reports STORED — the session simply never resumes, so every request mints a new id and the user can never stay logged in. Looks like a cookie problem, not a TTL problem.
- **evidence:** No memcached is reachable from this host (port 11211 closed, no docker daemon, no memcached binary), so this is read from source against the documented protocol rule. Code passing the raw value: python tina4_python/session_handlers/memcached_handler.py:106-108; php Tina4/Session/MemcachedSessionHandler.php:170-172; ruby lib/tina4/session_handlers/memcached_handler.rb:70-72; node packages/core/src/sessionHandlers/memcachedHandler.ts:127-130. Contrast: the file/database handlers compute `now + ttl` as an absolute deadline (python session/__init__.py:110, :164) with no such ceiling.

## Cache backends — response cache, KV cache, and the persistent DB query cache  (7)

### redis/valkey clear() is a no-op on the zero-dependency RESP transport, so the persistent DB query cache never invalidates on a write

- **frameworks:** Python, PHP, Ruby. Node is correct (its RespClient issues a real scoped KEYS + DEL).
- **confidence:** MEASURED
- **same code, different outcome:** Identical app code with TINA4_DB_CACHE=true. On memory/file/memcached/database: UPDATE then SELECT returns the new row. On redis/valkey: UPDATE then SELECT returns the PRE-WRITE row, for up to TINA4_DB_CACHE_TTL (default 30s). Same for the KV/response cache: cache_clear() / clearCache() returns having deleted nothing and every key keeps serving.
- **discovered:** Silently in production. It cannot happen locally: the local default is memory or file, which invalidate correctly. It only appears after the one-env-var swap to the server's Redis, and only as intermittently stale data with no error, no log line and no failing request. PHP is the worst case because ext-redis is not a Tina4 dependency, so the broken transport is the DEFAULT install.
- **evidence:** MEASURED end-to-end on the real PHP install (php -m shows no redis extension), live redis 6379 / valkey 6380, sqlite app DB, TINA4_DB_CACHE=true: memory read_AFTER_write=after INVALIDATED-OK | file after OK | redis read_AFTER_write=**before** *** STALE *** | valkey **before** *** STALE *** | memcached after OK | database after OK. Reproduced in Python with the redis package unavailable: redis same-instance-invalidate=STALE, valkey=STALE, everything else OK. Direct backend probe (Python, raw path): set 2 keys, clear(), both still readable. Source: tina4-python/tina4_python/cache/__init__.py:314-327 (`elif self._use_raw:  # ...let TTL handle cleanup` / `pass`); tina4-php/Tina4/Cache/RedisBackend.php:252-268 (comment 'Raw RESP path: no easy pattern delete'); tina4-ruby/lib/tina4/cache_backends/redis_backend.rb:112-124. Invalidation call sites that hit it: tina4-python/tina4_python/database/connection.py:440-444 `_cache_invalidate`, tina4-php/Tina4/Database/CachedDatabase.php:169-176 `cacheInvalidate`, tina4-ruby/lib/tina4/database.rb:1406-1409.

### memcached gives no cross-instance write-invalidation — clear() only deletes the keys the local process happened to write

- **frameworks:** Python, PHP, Ruby, Node — all four use the same per-process `_own` write-log design.
- **confidence:** MEASURED
- **same code, different outcome:** Two workers/instances sharing one cache. Worker A caches a SELECT; worker B performs the write. On redis/file/mongodb/database, B's clear() empties the shared namespace and A's next read is fresh. On memcached, B's `_own` log does not contain A's key, so B deletes nothing and A keeps serving pre-write rows until TTL. memcached is the one provider a developer picks *specifically* to share cache across instances.
- **discovered:** Silently in production, and only under multi-instance/multi-worker load. A single-process dev run passes because the writer and the reader are the same process, so the local `_own` log does contain the key.
- **evidence:** MEASURED in Python against live memcached 11211, two Database instances on one sqlite file, TINA4_DB_CACHE=true, run-unique SQL to avoid contamination: memcached cross-instance-invalidate=STALE, while redis/file/mongodb/database=OK (memory=STALE as documented). Source: tina4-python/tina4_python/cache/__init__.py:546-561 (`for mc_key in list(self._own)`); tina4-php/Tina4/Cache/MemcachedBackend.php:142-150; tina4-ruby/lib/tina4/cache_backends/memcached_backend.rb:74-79; tina4-nodejs/packages/core/src/cache.ts:844-851. The scoping was a deliberate fix for a `flush_all` that wiped other tenants; it fixed that and silently removed global invalidation.

### The DB query-cache key carries no database identity, so every shared backend cross-serves rows between different databases

- **frameworks:** Python, PHP, Ruby, Node — all four key on sha256(sql + params) with nothing identifying the connection, the database, or the application.
- **confidence:** MEASURED
- **same code, different outcome:** Two Database connections to DIFFERENT databases (the documented named-connection feature: `_db = "analytics"` / `static _db`) running the same SQL text. On memory each connection reads its own rows. On any shared backend the second connection is served the FIRST database's rows. The same collision happens between two separate Tina4 apps pointed at one Redis, and between the response cache and the DB cache, because the prefix is a hardcoded `tina4:cache:` with no configurable namespace.
- **discovered:** Silently in production, as wrong data rather than missing data. Local dev on the default memory backend can never reproduce it. The failure looks like a data-integrity bug in the application, not a cache bug.
- **evidence:** MEASURED in Python (two sqlite DBs, identical SQL, TINA4_DB_CACHE=true): memory cross-DB-isolated=OK; file/redis/memcached/mongodb/database all LEAK — the second connection returned the first database's value. MEASURED in Node: memory=OK; file/redis/memcached/database all LEAK(v1). Key functions: tina4-python/tina4_python/database/connection.py:409-413 `_cache_key = sha256(sql + str(params))`; tina4-php/Tina4/Database/CachedDatabase.php:129-132 `hash('sha256', $sql . json_encode($params))`; tina4-ruby/lib/tina4/database.rb:1369-1371; tina4-nodejs/packages/orm/src/cachedDatabase.ts:315 via `QueryCache.queryKey`. Prefix: tina4-python cache/__init__.py:175 `self._prefix = "tina4:cache:"` (hardcoded, no env override).

### Node: an explicitly-requested response-cache provider is silently ignored once any responseCache middleware exists

- **frameworks:** Node only. Python creates a dedicated backend whenever an explicit backend/cache_url/max_entries is passed (cache/__init__.py:1021-1028); PHP and Ruby build a backend per ResponseCache instance.
- **confidence:** MEASURED
- **same code, different outcome:** `responseCache({ backend: "redis", cacheUrl: "redis://…" })` on a route stores into whatever backend the FIRST responseCache() resolved (memory by default). Nothing reaches Redis, cross-instance sharing never happens, and X-Cache still reports HIT/MISS as if it did.
- **discovered:** Never, from the app's behaviour — the cache still works, just in-process. It surfaces as 'our Redis cache hit rate is zero' or as instances not sharing cached responses after a scale-out.
- **evidence:** MEASURED: built responseCache({ttl:60}) (default memory), served one request, then built responseCache({ttl:60, backend:'redis', cacheUrl:'redis://localhost:6379/9'}) and served another; reading `response:GET:/b` back from live redis returned undefined — nothing was stored. tina4-nodejs/packages/core/src/cache.ts:1270-1284: `_getResponseBackend(config)` returns the memoised `_responseBackend` before it ever looks at `config`.

### Node's file backend hands back the storage envelope instead of the value when the cached value is null

- **frameworks:** Node only. Python (`data.get("value")`), PHP (`$data['value'] ?? null`) and Ruby (`data["value"]`) all return the value unconditionally.
- **confidence:** MEASURED
- **same code, different outcome:** `await cacheSet(k, null); await cacheGet(k)` returns `null` on memory and redis, but `{"key":"k","value":null,"expiresAt":1785602813.004}` on file. A caller doing `if (v === null)` takes the opposite branch, and a caller that spreads/serialises the value now leaks the cache's internal envelope into its own output.
- **discovered:** At deploy, if the file backend is the production choice — but far more often it is hit by ACCIDENT, because `file` is also the automatic degradation target when a configured redis/mongo/database backend is unreachable. So a Redis blip converts a correct null into a garbage object.
- **evidence:** MEASURED: NULL round-trip memory=null, redis=null, file={"key":"nullkey","value":null,"expiresAt":1785602813.004}. (`false` and `""` round-trip correctly — only null trips it.) tina4-nodejs/packages/core/src/cache.ts:586 `return data.value ?? data;` — the `?? data` fallback fires whenever the stored value is null/undefined.

### sweep() behaves three different ways: real counts (Python/PHP), a NoMethodError crash on 6 of 7 providers (Ruby), and a permanent 0 on every provider (Node)

- **frameworks:** Ruby (crash), Node (permanent no-op), vs Python/PHP (works).
- **confidence:** MEASURED
- **same code, different outcome:** `backend.sweep()` after an expired write: Python/PHP memory=1 file=1; Ruby memory raises `NoMethodError: undefined method 'sweep' for an instance of Tina4::CacheBackends::MemoryBackend`, file=1; Node's exported `sweep()` returns 0 on memory and file even with expired entries present, because no Node backend implements the method at all.
- **discovered:** Ruby: an outright 500 the moment a job or admin endpoint calls sweep on anything but the file backend — i.e. immediately after swapping the backend. Node: silently, as an eviction job that reports 0 reclaimed forever while data/cache grows.
- **evidence:** MEASURED Ruby against live services: memory/redis/valkey/memcached/database all `sweep() RAISED NoMethodError`, file sweep()=1. MEASURED Node: `module sweep(): 0`, and `typeof memory.sweep === 'undefined'`, `typeof file.sweep === 'undefined'`. MEASURED Python: memory=1 file=1 rest=0; PHP identical. Source: tina4-ruby/lib/tina4/cache_backends/base_backend.rb declares clear/name/available? but no `sweep` (only FileBackend defines one); tina4-nodejs/packages/core/src/cache.ts:152-170 (interface has no sweep) and 1505-1511 (`if (typeof backend.sweep === 'function')` — never true); vs tina4-python/tina4_python/cache/__init__.py:69-77 and tina4-php/Tina4/Cache/CacheBackend.php `sweep()` on the base.

### Python's Database.cache_clear() never clears the persistent shared backend — it is a no-op on every provider

- **frameworks:** Python only. PHP CachedDatabase::cacheClear(), Ruby cache_clear and Node cacheClear() all clear the backend as well as the local store.
- **confidence:** MEASURED
- **same code, different outcome:** `db.cache_clear()` is documented as 'cache_clear() is real'. In persistent mode Python clears only `self._query_cache`, the in-process dict that the persistent path never writes to; the shared backend keeps every entry and the next read is still a hit on pre-clear data. The identical call in PHP/Ruby/Node empties the store.
- **discovered:** Wherever cache_clear() is the escape hatch — an admin 'flush cache' button, a deploy hook, a test teardown — it appears to work and changes nothing. Locally on memory it is equally broken, so it is not even a swap-only failure; it is simply dead API in the Python master.
- **evidence:** MEASURED: with TINA4_DB_CACHE=true, warm a read, change the row out-of-band, call db.cache_clear(), read again — stale on memory, file, redis, valkey, memcached, mongodb AND database (cache_clear=NO-OP on all seven). tina4-python/tina4_python/database/connection.py:497-502: `def cache_clear(self): with self._cache_lock: self._query_cache.clear(); self._cache_hits = 0; self._cache_misses = 0` — `self._cache_backend` is never touched. Compare tina4-php/Tina4/Database/CachedDatabase.php:238-246 and tina4-ruby/lib/tina4/database.rb:408-414, which both call `->clear()` on the backend.

## Database adapters / ORM  (10)

### Node ORM save()/findById()/all() emit PostgreSQL-dialect SQL on every engine — totally broken on MySQL and MSSQL, and save() returns false instead of raising

- **frameworks:** tina4-nodejs
- **confidence:** MEASURED
- **same code, different outcome:** Identical model + `await w.save()` / `W.findById(1)` / `W.all()`. sqlite: save=W, id=1, findById="a", all=1. postgres: identical. mysql: save returns Boolean false, id=undefined, findById RAISES `You have an error in your SQL syntax ... near '"t4a_ndy" ("name") VALUES ('a') RETURNING "id"'`, all RAISES. mssql: save returns false with `Incorrect syntax near 'RETURNING'`, findById RAISES `Incorrect syntax near 'LIMIT'`, all RAISES `Incorrect syntax near '100'`. baseModel.ts hard-codes double-quoted identifiers and appends ` RETURNING "pk"` for every adapter whose class name is not literally "SQLiteAdapter"; the read path emits LIMIT/OFFSET unconditionally. Note createTable() DOES work on all four (it routes through the adapter's createTableAsync), so the table exists and the developer sees a schema but no data.
- **discovered:** In production, on the first write. save() returns a falsy value rather than raising, so an app that does not check the return value silently drops every insert; the reads then blow up with a raw driver syntax error. Nothing fails locally on sqlite.
- **evidence:** Probe via the canonical `initDatabase({url})` path (/tmp/t4probe/node/orm4.mjs) against live pg:55432, mysql:3306, mssql:1433. Output: `sqlite createTable=true save=W id=1 findById="a" all=1` / `mysql createTable=true save=Boolean id=undefined findById="RAISED You have an error in your SQL syntax..."` / `mssql ... findById="RAISED Incorrect syntax near 'LIMIT'."`. Source: /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/orm/src/baseModel.ts:797 `const wantReturning = pkField?.autoIncrement && db.constructor.name !== "SQLiteAdapter";` and :798 `const returningClause = wantReturning ? ` RETURNING "${pkCol}"` : "";`, :814-819 double-quoted table/column names.

### Python: any literal `%` in a fetch() query (a LIKE pattern, a '100%' string, a modulo) raises `IndexError: list index out of range` on PostgreSQL only

- **frameworks:** tina4-python
- **confidence:** MEASURED
- **same code, different outcome:** `db.fetch("SELECT * FROM t4a_l WHERE n LIKE 'app%'")` -> sqlite 1 row, mysql 1 row, mssql 1 row, postgres RAISES `IndexError: list index out of range`. Same for `db.fetch("SELECT '100%' AS pct")` and `db.fetch("SELECT 7 % 2 AS m")`. Cause: fetch() appends `LIMIT %s OFFSET %s` and passes `[limit, offset]`, so psycopg2 performs %-substitution over the WHOLE string and reads the literal `%'` as a malformed placeholder. The issue-#40 guard in `_safe_execute` (pass None when params are empty) never fires on fetch() because pagination always supplies params. `fetch_one()` is NOT paginated and therefore works on postgres — so the two read methods disagree with each other on the same SQL.
- **discovered:** In production, the first time a search box is used. The exception is `IndexError: list index out of range` from deep inside psycopg2 — it names neither the SQL nor the `%`, so it reads like a framework bug, not a dialect one. PHP measured unaffected (pg_query_params binds $1 with no % pass).
- **evidence:** /tmp/t4probe/like.py and /tmp/t4probe/pct.py against live services. Output: `sqlite inline LIKE 'app%' -> 1 rows` ... `postgres inline LIKE 'app%' -> RAISED IndexError: list index out of range`; `postgres literal '100%' string -> RAISED IndexError`; `postgres modulo 7 % 2 -> RAISED IndexError`; `postgres fetch_one inline LIKE -> {'c': 1}` (works). Code: /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/database/postgres.py:54 `cursor.execute(sql, params)` reached from postgres.py:412 `self._exec_with_handling(cursor, paginated_sql, paginated_params)`.

### `... RETURNING ...` produces a different type AND different content on every provider, in all four frameworks — and none of the four returns the framework's own DatabaseResult on more than a subset

- **frameworks:** tina4-python, tina4-php, tina4-ruby, tina4-nodejs
- **confidence:** MEASURED
- **same code, different outcome:** `db.execute("INSERT INTO t (name) VALUES (?) RETURNING *")`: PYTHON — sqlite records=[] affected_rows=0 (rows silently discarded because sqlite3 >= 3.35 supports RETURNING natively so the emulation branch is skipped and the cursor is never fetched), postgres/mysql/mssql records=[row] affected=1. PHP — sqlite AND postgres both DatabaseResult(records=[], affectedRows=0, lastId=null); mysql and mssql RAISE a SQL syntax error (`near 'RETURNING *'` / `Incorrect syntax near 'RETURNING'`). RUBY — sqlite returns a bare `Array` of row hashes, postgres returns a raw `PG::Result`, mysql and mssql RAISE; none responds to `.records`. NODE — sqlite returns `{lastInsertRowid, changes}` with the rows dropped entirely, postgres returns a raw `pg.Result` (rows under `.rows`, not `.records`), mysql and mssql RAISE. UPDATE/DELETE ... RETURNING: postgres returns the rows in Python; mysql/mssql return [] with correct affected_rows; sqlite returns [] with affected_rows=0.
- **discovered:** Two ways, both in production. Develop on sqlite and the call quietly returns nothing so the developer stops using it; move to postgres and it starts returning rows (or a raw driver object with a different accessor). Or develop on sqlite/postgres and deploy on MySQL/MSSQL, where in PHP/Ruby/Node the statement is a hard SQL syntax error at runtime.
- **evidence:** /tmp/t4probe/ret.py, /tmp/t4probe/php/probe.php, /tmp/t4probe/rb/ret.rb, /tmp/t4probe/node/ret.mjs. Python: `sqlite INSERT..RETURNING * -> records=[] affected=0 last_id=1` vs `postgres -> records=[{'id':1,'name':'a'}] affected=1`. Ruby: `sqlite: class=Array` / `postgres: class=PG::Result` / `responds to records? false` for both. Node: `sqlite RETURNING result keys: [ 'lastInsertRowid', 'changes' ]` vs `postgres ... rows: [ { id: 1, name: 'a' } ]`. Code: tina4-python/tina4_python/database/sqlite.py:82-102 (`if returning_match and not self._supports_returning()`), sqlite.py:275-277 (`_supports_returning` true for the shipped 3.49.1).

### ORM createTable() emits `CREATE TABLE IF NOT EXISTS` — invalid T-SQL — so the entire ORM DDL path is dead on MSSQL in Python, PHP and Ruby

- **frameworks:** tina4-python, tina4-php, tina4-ruby (tina4-nodejs is CORRECT — its MSSQL adapter emits `IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES ...) CREATE TABLE`)
- **confidence:** MEASURED
- **same code, different outcome:** Identical model, `Model.create_table()` / `createTable()`: sqlite true, postgres true, mysql true, mssql FALSE with `Incorrect syntax near the keyword 'IF'`. Every subsequent save() then fails with `Invalid object name`. The frameworks already KNOW this — migration.rb:609 / Migration.php:1460 / migration/runner.py:611 / migration.ts:156 all carry the comment "Firebird and MSSQL do not support `CREATE TABLE IF NOT EXISTS`" — but the ORM createTable path never got the same treatment. The internal `tina4_sequences` / `tina4_cache` / `tina4_session` DDL has the same shape (Python special-cases only tina4_sequences for mssql).
- **discovered:** At first deploy onto SQL Server. create_table() honours its bool contract and returns false rather than raising, so a boot sequence that does not check the return value continues and every write then fails with a confusing "Invalid object name".
- **evidence:** Python /tmp/t4probe/orm_probe.py: `create_table failed for t4a_widget: (156, b"Incorrect syntax near the keyword 'IF'.") {"sql": "CREATE TABLE IF NOT EXISTS [t4a_widget] (...)"}` -> `create_table -> False`. Ruby /tmp/t4probe/rb/orm.rb: `mssql create_table=false ... {"sql":"CREATE TABLE IF NOT EXISTS t4a_rbw (id INTEGER PRIMARY KEY IDENTITY(1,1), name VARCHAR(255))"}`. PHP /tmp/t4probe/php/orm4.php: `mssql createTable=false save=false`. Source: tina4-python/tina4_python/orm/model.py:1122; tina4-php/Tina4/ORM.php:1774; tina4-ruby/lib/tina4/orm.rb:548. Correct implementation to copy: tina4-nodejs/packages/orm/src/adapters/mssql.ts:539.

### Python + MSSQL: one failed DDL statement permanently poisons the connection — every later write RAISES at commit while the row has already landed

- **frameworks:** tina4-python
- **confidence:** MEASURED
- **same code, different outcome:** App code: run an idempotent `CREATE TABLE`, catch the already-exists error, carry on. sqlite/postgres/mysql: `write AFTER duplicate DDL -> OK affected=1 last_id=1`. mssql: `write AFTER duplicate DDL -> RAISED OperationalError: Cannot commit transaction: (3902, 'The COMMIT TRANSACTION request has no corresponding BEGIN TRANSACTION')` — and `rows visible: {'c': 1}`, i.e. the write DID commit. The connection never recovers: the following DROP fails the same way. postgres has an explicit `_heal_aborted_txn()` pre-flight for exactly this; MSSQL has no equivalent. Under pooling the poisoned adapter is handed back out to subsequent requests.
- **discovered:** In production on SQL Server, and it looks like a write failure when it is actually a write SUCCESS plus a bogus exception. Application-level compensating logic (retry, rollback-and-report) then double-writes or reports a false error. A caught, expected non-DDL failure (bad column) does NOT trigger it — only DDL does, which is exactly what boot-time "ensure schema" code runs.
- **evidence:** /tmp/t4probe/mssql_iso3.py against live mssql:1433. `== mssql / duplicate CREATE caught: OperationalError / write AFTER duplicate DDL -> RAISED OperationalError Cannot commit transaction: (3902 ...) / rows visible: {'c': 1} / drop failed Cannot commit transaction`. Same script: postgres, mysql and sqlite all print `write AFTER duplicate DDL -> OK`. Code: tina4-python/tina4_python/database/mssql.py:111 `self._conn.commit()` (no heal); compare postgres.py `_heal_aborted_txn` (postgres.py:59+).

### Python + MySQL: a failed start_transaction leaks the transaction pin, after which the developer's explicit rollback() silently does nothing and the row survives

- **frameworks:** tina4-python
- **confidence:** MEASURED
- **same code, different outcome:** `Model.create_table()` twice (the ordinary idempotent boot pattern), then `model.save()`: sqlite `save -> W id=1`, postgres `save -> W id=1`, mysql `save RAISED ProgrammingError: Transaction already in progress` (mysql-connector's `start_transaction()` is the only driver that raises on an already-open transaction). `Database.start_transaction()` sets `self._tx_local.adapter = adapter` BEFORE calling `adapter.start_transaction()`, so the raise leaves the pin set forever. Every later `start_transaction()` then takes the "nested begin ignored" branch and logs a warning — and the writes inside it autocommit. Measured consequence: `db.start_transaction(); db.insert(...); db.rollback()` on MySQL leaves `rows after ROLLBACK: [{'id': 1, 'name': 'should-be-rolled-back'}]`. The same code on sqlite/postgres rolls the row back.
- **discovered:** Never, until data is wrong. The rollback path emits a WARNING (not an error) and returns normally; the transaction the developer believes is atomic is not. Only reachable on MySQL because only mysql-connector's start_transaction can raise on a healthy connection.
- **evidence:** /tmp/t4probe/mysql_orm2.py: `mysql c1 True / c2 True / save RAISED ProgrammingError Transaction already in progress` vs `postgres ... save -> W 1`. /tmp/t4probe/mysql_pin.py: `save raised: ProgrammingError` then `[WARNING] start_transaction() called while a transaction is already open ...` then `rows after ROLLBACK: [{'id': 1, 'name': 'should-be-rolled-back'}]`. Code: tina4-python/tina4_python/database/connection.py:869-871 (pin set before the begin can fail); tina4_python/database/mysql.py:163-165.

### PHP + MySQL returns EVERY column as a PHP string — the same endpoint emits different JSON types than it did on sqlite

- **frameworks:** tina4-php
- **confidence:** MEASURED
- **same code, different outcome:** Same table, same `$db->fetchOne("SELECT id, name, num, price, flag FROM t")`, same `json_encode($row)`: sqlite `{"id":1,"name":"x","num":7,"price":1.5,"flag":1}`; postgres `{"id":1,"name":"x","num":7,"price":1.5,"flag":true}`; mysql `{"id":"1","name":"x","num":"7","price":"1.5","flag":"1"}`; mssql same as sqlite. So a boolean column serialises three different ways (1 / true / "1") and every numeric becomes a quoted string on MySQL. `$row['num'] === 7` is true on sqlite/postgres/mssql and FALSE on mysql. Separately, `$db->insert(...)->lastId` is the string "1" on postgres and int 1 on the other three, so an API that echoes the new id changes JSON type on the headline sqlite->postgres swap.
- **discovered:** Silently, in the client. Strict-equality checks in PHP start returning false and any typed API consumer (a TS client, a mobile app, a JSON-schema validator) starts rejecting the payload. Nothing in the framework logs or errors.
- **evidence:** /tmp/t4probe/php/probe2.php against live services. Full output quoted above per engine, including `mysql: col id => string '1' / col num => string '7' / col flag => string '1'` and `postgres: lastId php-type=string value='1'` vs `sqlite/mysql/mssql: lastId php-type=integer`. Code: tina4-php/Tina4/Database/MySQLAdapter.php:174 `$result->fetch_assoc()` with no `MYSQLI_OPT_INT_AND_FLOAT_NATIVE`; compare tina4-nodejs/packages/orm/src/adapters/postgres.ts:33-40 where Node deliberately registers pg type parsers for exactly this parity reason.

### PHP + MySQL: a failed WRITE escapes as the raw `mysqli_sql_exception`, not `Tina4\Database\DatabaseException` — so `catch (DatabaseException)` stops working when you swap to MySQL

- **frameworks:** tina4-php
- **confidence:** MEASURED
- **same code, different outcome:** `try { $db->execute("INSERT INTO t (nope) VALUES (1)"); } catch (\Tina4\Database\DatabaseException $e) { ... }`: sqlite/postgres/mssql -> caught (`isDatabaseException=true`). mysql -> NOT caught; a `mysqli_sql_exception` propagates past the handler. Inconsistent even inside MySQL: a failed FETCH on MySQL IS wrapped into DatabaseException, only writes and DDL leak the raw type. PHP is the only framework of the four with a declared database exception type, and it has a hole in it.
- **discovered:** In production, as an unhandled 500 on a code path that has a working error handler locally. The catch block simply never runs.
- **evidence:** /tmp/t4probe/php/probe2.php: `mysql driver-error class=mysqli_sql_exception isDatabaseException=false` / `mysql fetch-error class=Tina4\Database\DatabaseException isDatabaseException=true` / `mysql dup-ddl class=mysqli_sql_exception isDatabaseException=false`; sqlite, postgres, mssql all report `isDatabaseException=true` on all three. Code: tina4-php/Tina4/Database/MySQLAdapter.php:252 `execute()` does not wrap the mysqli throw the way fetch() does.

### Python, Ruby and Node declare no database exception type at all — the class you must catch is the raw driver's and it changes with every provider

- **frameworks:** tina4-python, tina4-ruby, tina4-nodejs (tina4-php has DatabaseException, with the MySQL-write hole above)
- **confidence:** MEASURED
- **same code, different outcome:** The same failing statement raises: PYTHON sqlite3.OperationalError / psycopg2 UndefinedTable / mysql.connector ProgrammingError / pymssql ProgrammingError. RUBY SQLite3::SQLException / PG::UndefinedTable / Mysql2::Error / TinyTds::Error. NODE Error / DatabaseError (pg) / Error (mysql2) / RequestError (tedious). A developer who writes `except sqlite3.OperationalError:` or `rescue SQLite3::SQLException` locally has written a handler that catches nothing in production — and, worse, that also requires importing the local driver's module, which is not installed on the production host. `grep -rn 'class DatabaseError|class DatabaseException'` returns ZERO hits in tina4-python/tina4_python, tina4-ruby/lib and tina4-nodejs/packages.
- **discovered:** In production, as an unhandled exception on a path that had a working handler locally. There is no framework-supplied class to catch instead, so the only portable option today is a bare `except Exception` / `rescue => e` / `catch (e)`, which the frameworks' own fail-loud design is trying to discourage.
- **evidence:** Exception classes observed live in /tmp/t4probe/py_contract.py, /tmp/t4probe/rb/probe.rb and /tmp/t4probe/node/probe.mjs (quoted per engine above). Absence confirmed by grep over /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python, /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib and /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages — only PHP's /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/Database/DatabaseException.php exists.

### PHP: the shipped ORM model shape gets a VARCHAR primary key — SQLite silently stores id=NULL while reporting id=1, PostgreSQL/MySQL reject the insert, MSSQL cannot create the table

- **frameworks:** tina4-php
- **confidence:** MEASURED
- **same code, different outcome:** A model in exactly the shape of the SHIPPED examples (tina4-php/example/src/orm/Category.php: `public string $tableName; public string $primaryKey = "id"; public $id; public $name;` — untyped properties), then `createTable()` + `save()`. sqlite: createTable=true, DDL gives `id VARCHAR(255) PRIMARY KEY`, save() returns the model with `id = 1` — but the stored row is `{"rowid":1,"id":null,"name":"a"}` and `load()` with id=1 then returns FALSE. postgres: save()=false, `null value in column "id" ... violates not-null constraint`. mysql: save()=false, `Field 'id' doesn't have a default value`. mssql: createTable()=false. Declaring the properties as typed (`public ?int $id = null;`) fixes sqlite/postgres/mysql but MSSQL still fails at createTable.
- **discovered:** The sqlite case is the dangerous one: it never errors, save() returns the model with a plausible id, and only a later load()/find by that id comes back empty — which reads as a caching bug. On postgres/mysql it is loud at the first insert.
- **evidence:** /tmp/t4probe/php/orm2.php: `sqlite createTable -> true / cols: [{"name":"id","type":"VARCHAR(255)",...,"primaryKey":true},...] / save -> T4aOrmX id=1` vs `postgres save -> false ... err=ERROR: null value in column "id" of relation "t4a_ormx" violates not-null constraint` and `mysql ... err=Field 'id' doesn't have a default value`. /tmp/t4probe/php/orm3.php proves the sqlite corruption: `save id reported: 1 / raw rows: [{"rowid":1,"id":null,"name":"a"}] / load by id=1 -> false`. Code: tina4-php/Tina4/ORM.php:1721-1733 (AUTOINCREMENT only when the declared type resolves to 'int'; an untyped property falls through to `VARCHAR(255) PRIMARY KEY`).

## Queue backends  (11)

### PHP: failed(), deadLetters() and retryFailed() are a FATAL Error on rabbitmq and kafka

- **frameworks:** tina4-php
- **confidence:** MEASURED
- **same code, different outcome:** `$queue->deadLetters()` returns an array of dead jobs on the file backend and throws `Error: Call to undefined method Tina4\Queue\RabbitMQBackend::deadLetters()` the moment TINA4_QUEUE_BACKEND=rabbitmq. Same for `failed()` and `retryFailed()`. Tina4\Queue calls these on a property typed `?QueueBackend`, but the QueueBackend interface never declares them and neither RabbitMQBackend nor KafkaBackend implements them.
- **discovered:** In production, inside the worker loop, the first time a dead-letter inspector or retry sweep runs. Not at boot, not at deploy — the app starts and pushes/pops fine, then a PHP Error takes the worker down when the operator opens the dead-letter view.
- **evidence:** Ran a probe against the real repo (no broker needed — both backends connect lazily):
  rabbit failed() => Error: Call to undefined method Tina4\Queue\RabbitMQBackend::failed()
  rabbit deadLetters() => Error: Call to undefined method Tina4\Queue\RabbitMQBackend::deadLetters()
  rabbit retryFailed() => Error: Call to undefined method Tina4\Queue\RabbitMQBackend::retryFailed()
  kafka failed()/deadLetters()/retryFailed() => same three Errors
  file failed()/deadLetters()/retryFailed() => 0 / 0 / 0 (no error)
Call sites: Tina4/Queue.php:364, :418, :443. Declared interface: Tina4/Queue/QueueBackend.php:13-68 (7 methods, none of these). Implemented methods: Tina4/Queue/RabbitMQBackend.php and Tina4/Queue/KafkaBackend.php expose only __construct/connect/enqueue/dequeue/acknowledge/requeue/deadLetter/size/close.

### PHP: clear() and purge() always hit the LOCAL FILE store, whatever backend is configured

- **frameworks:** tina4-php
- **confidence:** MEASURED
- **same code, different outcome:** `$queue->clear()` and `$queue->purge($status)` are hard-wired to `$this->liteBackend` with no external-backend branch. On a kafka- or mongodb-backed queue they delete JSON files under data/queue/<topic>/ and return that file count, while the broker/collection is untouched. The operator sees a plausible non-zero return and believes the queue was drained.
- **discovered:** Silently in production: the admin "clear queue" button reports success, the broker keeps delivering, and stray data/queue/ directories appear on the app server. Nothing errors.
- **evidence:** Probe: seeded 1 job into the FILE store for topic 'shadow', then called clear() on a kafka-backed Queue for the same topic.
  file 'shadow' pending before: 1
  kafka-backed clear() returned: 1
  file 'shadow' pending after kafka clear(): 0
Code: Tina4/Queue.php:282-287 (clear() -> $this->liteBackend->count/clear unconditionally) and Tina4/Queue.php:429-432 (purge() -> $this->liteBackend->purge unconditionally). Compare size()/pop()/push(), which DO branch on $this->externalBackend.

### Node: popBatch() and popById() always read the LOCAL FILE store, even on mongodb

- **frameworks:** tina4-nodejs
- **confidence:** MEASURED
- **same code, different outcome:** `Queue.popBatch()` and `Queue.popById()` call `this.liteBackend` with no `externalBackend` check. So on TINA4_QUEUE_BACKEND=mongodb, `queue.consume({batchSize: 10})`, `queue.process(h, {batchSize: 10})` and `queue.consume(topic, jobId)` never issue a single Mongo query — they poll an empty local directory forever. Single-job `pop()` DOES route to Mongo, so a batch worker and a single worker on the same topic read two different stores.
- **discovered:** Silently in production. A batch consumer developed on the file backend deploys onto Mongo and processes zero jobs with no error and no log line — it just idles. Meanwhile any single-job consumer on the same topic works, which makes it look like a throughput problem rather than a wrong-store problem.
- **evidence:** Probe: pushed one job into the FILE store for topic 'shadow', then called popBatch(5) on a Queue constructed with { backend: "mongodb" } (its Mongo client is a lazy child process, so no server was contacted).
  seeded file job id: 0168722e-... file size: 1
  mongo-backed popBatch(5) => [{"who":"file-store"}]
  file store size after mongo-backed popBatch: 0
The mongodb-configured queue consumed the file job. Code: packages/core/src/queue.ts:275-277 (popBatch) and :549-551 (popById); compare pop() at :263-270 which does branch on externalBackend. Consumers: consume() :522-523, process() :303.

### Ruby: queue.size raises NoMethodError on kafka

- **frameworks:** tina4-ruby
- **confidence:** MEASURED
- **same code, different outcome:** `Tina4::Queue#size` calls `@backend.size(@topic)` unconditionally for the default "pending" status, but `Tina4::QueueBackends::KafkaBackend` defines no `size` method at all. `queue.size` returns an Integer on lite and raises NoMethodError on kafka.
- **discovered:** At runtime in production, the first time a health endpoint, dashboard, or `while queue.size > 0` drain loop runs. The app boots and produces/consumes normally until something asks how deep the queue is.
- **evidence:** Probed the real classes with method_defined?:
  KafkaBackend MISSING: dequeue_batch, find_by_id, complete, fail, retry, size, reserved_count, dead_letter_count, dead_letters, purge, retry_failed, failed, retry_job, clear
  LiteBackend MISSING: (none)
Call site: lib/tina4/queue.rb:220-241 — the "pending" branch is `@backend.size(@topic)` with no respond_to? guard (unlike every other method in the class). lib/tina4/queue_backends/kafka_backend.rb (134 lines) defines enqueue/dequeue/acknowledge/requeue/dead_letter/close only.

### Ruby: on rabbitmq/kafka the whole failure lifecycle silently no-ops — job.fail() never reaches the backend and dead_letters() is always empty

- **frameworks:** tina4-ruby
- **confidence:** MEASURED
- **same code, different outcome:** Neither broker backend defines `fail`, so `Tina4::Job#fail` takes its else-branch and does in-memory bookkeeping ONLY (attempts += 1, status = :failed) — nothing is written to the broker, so the `dead_letter` method both backends DO implement is never called by the lifecycle. Then `Tina4::Queue`'s respond_to? guards turn every read into a silent default: dead_letters -> [], failed -> [], retry -> false, purge -> 0, retry_failed -> 0, clear -> 0, pop_by_id -> nil. Identical code returns real dead letters and real counts on lite. On mongodb, `clear` -> 0 (no-op) and `failed` -> [] for the same reason.
- **discovered:** Silently in production, and only when something is genuinely poison. A dead-letter handler written and tested on lite deploys onto RabbitMQ and finds nothing, forever; on RabbitMQ the messages sit unacked and get redelivered on channel close, so the job loops instead of dead-lettering. No exception, no log.
- **evidence:** method_defined? probe (above) plus the guards. Guards: lib/tina4/queue.rb:80 (`return 0 unless @backend.respond_to?(:clear)`), :86 (failed -> []), :93 (retry -> false), :100 (dead_letters -> []), :106 (purge -> 0), :113 (retry_failed -> 0), :213 (pop_by_id -> nil). Degradation branch: lib/tina4/job.rb `fail` — `if @queue.backend.respond_to?(:fail) ... else @attempts += 1; @status = :failed end`. RabbitmqBackend MISSING: fail, retry, dead_letters, purge, retry_failed, failed, retry_job, clear, find_by_id, dequeue_batch. MongoBackend MISSING: clear, failed, find_by_id, dequeue_batch, retry_job.

### Node: rabbitmq and kafka throw at construction — the upgrade path is severed, not degraded

- **frameworks:** tina4-nodejs
- **confidence:** MEASURED
- **same code, different outcome:** `new Queue({ backend: "rabbitmq" })` throws before any I/O. A developer who builds on the file backend cannot move to the broker their server runs — the app does not start. tina4-python, tina4-php and tina4-ruby all accept both names.
- **discovered:** At deploy, loudly — which is the deliberate choice (ADR-0022): both backends drove one child process per operation, so no connection survived between pop() and complete() and acknowledgement was impossible (RabbitMQ was at-most-once, Kafka re-read offset 0 forever). Refusing beats losing work silently. It is still a hole in the promise, because the same env var that works in three frameworks is fatal in the fourth.
- **evidence:** Probe: new Queue({topic:"t", backend:"rabbitmq"}) => THREW: Queue backend "rabbitmq" is not available in tina4-nodejs. Same for kafka. Code: packages/core/src/queue.ts:218-219, message built at :154-171.

### delay_seconds / delay is silently dropped on EVERY non-file backend, in all four frameworks

- **frameworks:** tina4-python, tina4-php, tina4-ruby, tina4-nodejs
- **confidence:** MEASURED
- **same code, different outcome:** `queue.push(data, delay_seconds=60)` (and produce(..., delay)) holds the job for 60s on the file backend and makes it immediately poppable on every other provider. Python and PHP never even forward the value: the adapter builds `{payload, priority, attempts}` / `['id','payload','topic']` and drops delay on the floor. Ruby's Mongo enqueue writes no available_at at all. Node forwards delayUntil but its pop predicate ignores it (see the next finding). A scheduled-email or retry-later feature fires instantly in production.
- **discovered:** Silently in production, as a timing bug: the "send in 1 hour" job is delivered in the same second. Locally on the file backend it behaves correctly, so it reads as a broker quirk rather than a dropped argument.
- **evidence:** File-backend baselines MEASURED in all four (delay honoured): Python `pop()` after `push(delay_seconds=60)` => None; PHP `pop()` after `push(x,0,60)` => NULL; Node `pop()` after `push(x,60)` => null; Ruby `pop` after `push(..., delay_seconds: 60)` => nil.
Dropped on the way out (read): tina4_python/queue/mongo_backend.py:38-40, kafka_backend.py:28-30, rabbitmq_backend.py:53-56 — all three build `msg = {"payload": data, "priority": priority, "attempts": 0}` with the `delay_seconds` parameter unused. tina4-php Tina4/Queue.php:126-133 (external branch omits both 'priority' and 'delay_seconds', which the file branch at :135-141 includes). tina4_python/queue_backends/mongo_backend.py:117 and tina4-php Tina4/Queue/MongoBackend.php:118-127 hardcode `available_at = now`. tina4-ruby lib/tina4/queue_backends/mongo_backend.rb:60-69 inserts only _id/topic/payload/created_at/attempts/status.

### Node + mongodb: the availability predicate is an OR that always matches, so both delay and retryBackoff are inert

- **frameworks:** tina4-nodejs
- **confidence:** INFERRED
- **same code, different outcome:** The pop filter is `{queue, status:"pending", $or:[{availableAt:null},{availableAt:{$exists:false}},{availableAt:{$lte:now}},{delayUntil:null},{delayUntil:{$lte:now}}]}`. A freshly pushed job has no `availableAt` field at all, so `{availableAt:{$exists:false}}` matches and a delayed job pops immediately. A job requeued by fail() with `availableAt = now + retryBackoff` still carries `delayUntil: null` from push, so `{delayUntil:null}` matches and the backoff is bypassed too. On the file backend both are honoured, so a poison job that backs off politely locally becomes a tight retry loop against Mongo.
- **discovered:** Silently in production as a hot loop: a failing job is re-popped as fast as the worker can spin, burning the retry budget in milliseconds instead of over the configured backoff, then dead-letters far sooner than expected.
- **evidence:** packages/core/src/queueBackends/mongoBackend.ts:213-227 (the $or predicate) against :383-401 (push writes `delayUntil` but never `availableAt`) and :289-297 (fail sets `availableAt` but leaves `delayUntil` untouched). Note the reservation itself is safe — `status:"pending"` is ANDed, so reserved docs are correctly excluded. Not measured: no MongoDB reachable on this host (27017 closed).

### Ruby + mongodb: priority and job availability are ignored entirely on the read path

- **frameworks:** tina4-ruby
- **confidence:** MEASURED (lite baseline) / INFERRED (mongo)
- **same code, different outcome:** `MongoBackend#enqueue` never writes `priority` or `available_at`, and `#dequeue` filters on `{topic:, status: "pending"}` with `sort: {created_at: 1}` — no priority sort, no availability check. So on Mongo a high-priority job queues behind older low-priority work, and `job.retry(delay_seconds: 3600)` / retry_backoff (which DO write a future available_at at mongo_backend.rb:177-201, 251-264) are re-popped on the very next dequeue. The lite backend honours both.
- **discovered:** Silently in production: priority lanes stop working (looks like a load problem) and delayed retries fire immediately (looks like a broker quirk). Both are invisible locally because the lite backend is correct.
- **evidence:** Lite baseline MEASURED: pushed {n:"low", priority:0} then {n:"high", priority:9}; `q.pop.payload` => {"n"=>"high"}. Mongo code read: lib/tina4/queue_backends/mongo_backend.rb:60-69 (enqueue: _id, topic, payload, created_at, attempts, status — no priority, no available_at) and :71-99 (dequeue: filter `{topic:, status: "pending"}`, `sort: {created_at: 1}`). Contrast lib/tina4/queue_backends/lite_backend.rb:372-397 (available_candidates skips future available_at, sorts priority DESC then created_at ASC). Not measured: no MongoDB reachable (27017 closed).

### Python: reading dead letters on a broker is a DESTRUCTIVE drain-and-republish, not a read

- **frameworks:** tina4-python
- **confidence:** INFERRED
- **same code, different outcome:** `queue.dead_letters()`, `queue.failed()` and `queue.retry(job_id)` on rabbitmq/kafka consume the ENTIRE `<topic>.dead_letter` queue/topic in a `while True` loop and then re-enqueue every message they read. On the file backend the same three calls are pure reads of the failed/ directory. On RabbitMQ the drained messages are read with `auto_ack=False` and then ALSO re-published, so each inspection can double them and leaves the originals unacked until the channel closes. On Kafka, `dequeue` never commits (only `acknowledge` does) and the re-enqueue APPENDS new records, so every call to dead_letters() grows the dead-letter topic and a crash mid-drain loses whatever was read but not yet re-published.
- **discovered:** Silently in production. A dashboard that polls dead_letters() every 30 seconds inflates the dead-letter topic without bound on Kafka and duplicates dead letters on RabbitMQ. On the file backend the identical dashboard is harmless.
- **evidence:** tina4_python/queue/rabbitmq_backend.py:94-116 (failed), :118-140 (dead_letters), :142-163 (retry_job) — each is `while True: msg = dequeue(dl_topic) ... requeue.append(msg)` followed by `for msg in requeue: self._backend.enqueue(dl_topic, msg)`. Identical shape at tina4_python/queue/kafka_backend.py:65-87, :89-111, :113-134. Ack semantics: tina4_python/queue_backends/rabbitmq_backend.py:96 `basic_get(queue=topic, auto_ack=False)`; tina4_python/queue_backends/kafka_backend.py:103-138 (dequeue polls, records _in_flight, never commits) vs :150-155 (acknowledge commits). Not measured: no RabbitMQ/Kafka reachable (5672/9092 closed) and pika/confluent-kafka are not installed in the repo venv.

### Ruby: job.complete() never commits the Kafka offset, and one shared delivery tag breaks multi-job acks on RabbitMQ

- **frameworks:** tina4-ruby
- **confidence:** MEASURED (missing method) / INFERRED (redelivery consequence)
- **same code, different outcome:** `Tina4::Job#complete` calls `backend.complete(self)` only `if backend.respond_to?(:complete)`. RabbitmqBackend defines `complete`; KafkaBackend defines `acknowledge` instead and no `complete` — so on Kafka `job.complete` is a silent no-op and the offset is never committed (the consumer is configured `enable.auto.commit=false`). Every message is re-delivered from the last committed offset on worker restart. Separately, RabbitmqBackend stores a single `@last_delivery_tag` overwritten on each dequeue, so after popping A then B, `A.complete` acks B's delivery tag.
- **discovered:** On Kafka: after the first worker restart or rebalance — the whole topic is reprocessed, which looks like a poison-message storm rather than a missing commit. On RabbitMQ: only when more than one job is in flight per consumer, so it never shows up in single-threaded local testing.
- **evidence:** method_defined? probe: `KafkaBackend MISSING: ... complete ...`; RabbitmqBackend defines complete. Guard: lib/tina4/job.rb `def complete; @status = :completed; @queue.backend.complete(self) if @queue && @queue.backend.respond_to?(:complete); end`. Kafka's only commit path is `acknowledge(_message)` (lib/tina4/queue_backends/kafka_backend.rb:111-113), which nothing in Queue or Job calls. Shared tag: lib/tina4/queue_backends/rabbitmq_backend.rb:46 (`@last_delivery_tag = delivery_info.delivery_tag` on every dequeue) and :56-61 (complete acks whatever the last one was). Not measured: no broker reachable (5672/9092 closed) and bunny/rdkafka are not installed.

## DocStore  (9)

### PHP: on a default production install, TINA4_MONGO_URI is honoured by isServerless() but getCollection() still hands back local SQLite — production writes land in a container-local file

- **frameworks:** PHP
- **confidence:** MEASURED
- **same code, different outcome:** `mongodb/mongodb` is declared in **require-dev** only (composer.json:35-38), while `ext-mongodb` is what ops installs for the Mongo queue/session backends. On that host `class_exists('\MongoDB\Driver\Manager')` is true so `isServerless()` returns **false** (DocStore.php:1092 — 'I am on Mongo'), but `getCollection()` checks `class_exists('\MongoDB\Client')` (DocStore.php:1125) and, finding it absent, falls through to `docStoreDefaultDb()->getCollection($name)` (:1130). Same app code, same TINA4_MONGO_URI: every insertOne/updateOne goes to data/tina4_docstore.db on the local disk. `isServerless()` — the one health check a developer would write — actively reports the opposite of the truth.
- **discovered:** Never, until the data is gone. The app starts, all writes succeed, reads work (they read back the same local file), health checks pass. It surfaces when a second replica sees none of the first replica's documents, or when the container is redeployed and the writable layer is discarded. There is no log line on this path.
- **evidence:** Ran /tmp scratch probe reproducing the --no-dev shape (ext-mongodb present, no autoloader for MongoDB\Client): `ext-mongodb (MongoDB\Driver\Manager): present | library (MongoDB\Client): absent | TINA4_MONGO_URI: mongodb://localhost:27017 | isServerless() reports: false | getCollection() actually returns: Tina4\SqliteCollection | local SQLite file created: YES | rows sitting in the LOCAL file: 1`. Source: /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/Bootstrap/DocStore.php:1085-1131; /Users/andrevanzuydam/IdeaProjects/tina4-php/composer.json:35-38.

### URI set + driver missing silently degrades to the local SQLite file in Python, PHP and Ruby (Node crashes instead) — three different outcomes from one env

- **frameworks:** Python, PHP, Ruby (silent local write); Node (hard failure) — divergent from each other
- **confidence:** MEASURED
- **same code, different outcome:** Python `is_serverless()` (docstore/__init__.py:654-664) catches ImportError on pymongo and returns True; Ruby `serverless?` (docstore.rb:707-718) rescues LoadError and returns true; PHP `isServerless()` (DocStore.php:1085-1093) returns true when the driver class is missing. All three then write to data/tina4_docstore.db with TINA4_MONGO_URI pointing at a real cluster. The comments claim it will 'say so once' — there is no Log call anywhere in any of the three files. Node (docstore.ts:774-779, :803-810) does the opposite: `isServerless()` returns false and `await import("mongodb")` rejects, so the app fails loud. So the identical misconfiguration produces silent data loss in three frameworks and a crash in the fourth.
- **discovered:** In production, after the fact. Locally the developer never has the driver installed either, so dev and prod look identical and green. The Node behaviour (crash at first use) is the only one that surfaces it, and it surfaces it as an unrelated-looking ERR_MODULE_NOT_FOUND.
- **evidence:** Python probe with pymongo import blocked at the meta_path level (no framework code patched): `TINA4_MONGO_URI is set to: mongodb://localhost:27017 | is_serverless() -> True | collection class -> tina4_python.docstore.SqliteCollection | wrote to local file? -> True | rows in local sqlite -> 1`, with zero warning output. PHP measured in the finding above. Ruby/Node arms INFERRED from identical code shape: docstore.rb:710-717, docstore.ts:774-779.

### PHP: every result accessor and the whole cursor chain is call-site incompatible with the real driver — and three of them fail SILENTLY as null

- **frameworks:** PHP
- **confidence:** MEASURED
- **same code, different outcome:** The fallback returns Tina4 result objects with public readonly PROPERTIES (`$res->insertedId`, `->matchedCount`, `->modifiedCount`, `->deletedCount`; DocStore.php:562-601) and a Tina4 `Cursor` with `->sort()/->limit()/->skip()/->toList()` (:608-686). The real `MongoDB\Collection` returns result objects with GETTERS and a `MongoDB\Driver\Cursor` with none of those methods. Worst case: `$r->matchedCount` / `->modifiedCount` / `->deletedCount` on the real driver are undefined properties, so PHP emits a Warning and evaluates to **NULL** — `if ($r->deletedCount > 0)` silently becomes false instead of throwing. `updateOne($f, $u, true)` is also wrong: the fallback's third parameter is `bool $upsert` (:900), the driver's is `array $options`. The example in DocStore.php's own docblock (:20-25) and in CLAUDE.md does not run on real Mongo.
- **discovered:** At deploy, as a mix of fatal errors and — worse — silent wrong answers. `->insertedId`, `->sort()`, `->toList()` and the `true` upsert throw immediately; the three count accessors do not throw, they return null, so post-write branching quietly takes the wrong path.
- **evidence:** Probe against live mongod, sqlite vs MongoDB\Collection: `[insertedid] sqlite '6a6e22f2...' | mongo THREW Error: Cannot access private property MongoDB\InsertOneResult::$insertedId`; `[cursorsort] sqlite 1 | mongo THREW Error: Call to undefined method MongoDB\Driver\Cursor::sort()`; `[matchedcount] sqlite 1 | mongo NULL (Warning: Undefined property MongoDB\UpdateResult::$matchedCount)`; `[modifiedcount] sqlite 1 | mongo NULL`; `[deletedcount] sqlite 1 | mongo NULL`; `[tolist] sqlite 1 | mongo THREW Error: Call to undefined method MongoDB\Driver\Cursor::toList()`; `[upsertbool] mongo THREW TypeError: MongoDB\Collection::updateOne(): Argument #3 ($options) must be of type array, true given`; `[insertmanyids] mongo THREW Error: Cannot access private property MongoDB\InsertManyResult::$insertedIds`. Source: DocStore.php:562-686, :900.

### Ruby: find_one() does not exist on Mongo::Collection, and the cursor's two-argument sort(key, direction) is rejected by the driver

- **frameworks:** Ruby
- **confidence:** MEASURED
- **same code, different outcome:** The fallback defines `find_one(filter, projection)` (docstore.rb:514) and a Cursor whose `sort(key_or_list, direction = 1)` takes two args (:405). The real Ruby driver's `Mongo::Collection` has **no `find_one` method at all** (only find, find_one_and_update/_delete/_replace), and `Mongo::Collection::View#sort` accepts 0..1 arguments. `to_list` (:453) also does not exist on the View. The documented example in docstore.rb:10-15 and in CLAUDE.md — `orders.find_one(...)` and `.find(...).sort("created_at", -1).limit(10)` — is exactly what breaks.
- **discovered:** At deploy, as NoMethodError / ArgumentError on the first request that reads a document. Loud, but it means the app cannot be moved to the server's environment at all without rewriting every read call site.
- **evidence:** Probe against live mongod: `[findone] sqlite 1 | mongo RAISED NoMethodError: undefined method 'find_one' for an instance of Mongo::Collection`; `[cursorsort] sqlite 1 | mongo RAISED ArgumentError: wrong number of arguments (given 2, expected 0..1)`; `[tolist] sqlite 1 | mongo RAISED NoMethodError: undefined method 'to_list' for an instance of Mongo::Collection::View`. Source: /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/docstore.rb:405, :453, :514.

### Node: the fallback collection is fully synchronous while the driver is fully asynchronous — un-awaited code returns a real value locally and a Promise in production

- **frameworks:** Node
- **confidence:** MEASURED
- **same code, different outcome:** Every SqliteCollection method returns a plain value (insertOne :520, findOne :547, countDocuments :555, Cursor.toArray :472 — all sync because node:sqlite is sync). Every driver method returns a Promise. The known/declared difference is only on `getCollection` itself; the undeclared one is on all ~15 collection methods. Code written and passing locally without `await` — `const res = orders.insertOne(...); res.insertedId` or `if (orders.findOne(f).status === "new")` — silently reads `undefined` off a Promise in production instead of throwing. The documented CLAUDE.md example additionally iterates the cursor with `for (const doc of orders.find(...).sort(...).limit(10))`, which the driver's FindCursor (async-iterable only) cannot do, and calls `.toList()`, which it does not have.
- **discovered:** Silently in production for the un-awaited value reads (undefined propagates into stored documents and into branch conditions); loudly at first request for the `for..of` and `.toList()` cases. Local dev never fails because the sync path makes the missing `await` invisible.
- **evidence:** Probe against live mongod: `[docs_example_noawait] sqlite "object" | mongo "undefined"` (typeof res.insertedId); `[findone_noawait] sqlite "string" | mongo "undefined"`; `[countdocs_noawait] sqlite 1 | mongo "type:Promise"`; `[forof_cursor] sqlite 1 | mongo THREW TypeError: ...is not a function or its return value is not iterable`; `[tolist] sqlite 1 | mongo THREW TypeError: c.find(...).toList is not a function`. Source: /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/orm/src/docstore.ts:472, :520, :547, :555, :485-487.

### Array fields do not match on the SQLite fallback — Mongo's array-containment semantics are absent in all four frameworks

- **frameworks:** Python, PHP, Ruby, Node (identical filter compiler in all four)
- **confidence:** MEASURED
- **same code, different outcome:** In Mongo, `{tags: "red"}` matches a document whose `tags` is `["red","blue"]`, `{tags: {$in: ["red"]}}` matches the same, `{"items.name": "x"}` reaches into an array of sub-documents, and `{"items.0.name": "x"}` addresses an array index. The fallback compiles every field to `json_extract(doc, '$.field') = ?` (Python :191/:232, Node :204/:271, PHP :276/:328, Ruby :192/:227), which for an array returns the JSON array text, so all four forms return **zero rows**. A developer writes and tests a tag/role/permission query locally, gets 0 results, adjusts the data until it works with a scalar field — then the same query starts matching everything on the server. Or the reverse: a local filter that returns nothing is deployed and suddenly returns rows.
- **discovered:** Silently, as wrong result sets. Nothing raises. Locally it is a persistent 'my query returns nothing' puzzle; in production it is over-matching. Nothing in the docs lists array containment as a non-goal — the stated non-goals are aggregation, $elemMatch and geo.
- **evidence:** Python vs live mongod, isolated collections: `[arraymatch] sqlite 0 | mongo 1`; `[arrayin] sqlite 0 | mongo 1`; `[nestedarray] sqlite 0 | mongo 1`; `[arrayindex] sqlite 0 | mongo 1`. Cross-framework fallback confirmation, same document `{tags:["red"]}` and filter `{tags:"red"}`: `NODE arraymatch: 0`, `RUBY arraymatch: 0`, `PHP arraymatch: 0`. Source: tina4_python/docstore/__init__.py:184-235; docstore.ts:197-277; DocStore.php:265-335; docstore.rb:185-233.

### A new Mongo client is constructed on every get_collection() call and never closed — connections grow without bound on the real provider only

- **frameworks:** Python, PHP, Ruby, Node
- **confidence:** MEASURED
- **same code, different outcome:** On the SQLite path the connection and the collection object are cached (Python :616-619, Node :739-746, PHP :1039-1045, Ruby :679-682), so calling `get_collection("orders")` in a request handler is free. On the real-Mongo path each call constructs a brand-new client — `pymongo.MongoClient(uri)` (Python :696), `new MongoClient(uri)` + `await client.connect()` (Node :807-808), `Mongo::Client.new(...)` (Ruby :741), `new \MongoDB\Client($uri)` (PHP :1126) — with no cache and no close. The idiomatic call site (`const orders = getCollection("orders")` at the top of a handler) is therefore free locally and leaks a full connection pool per request in production.
- **discovered:** Only in production, under load, as connection-limit errors on the mongod side or file-descriptor exhaustion in the app. Never locally: the SQLite path has nothing to exhaust.
- **evidence:** Python, 30 identical `get_collection("orders")` calls against live mongod: `connections before: 4 | connections after 30 get_collection() calls: 94 delta: 90 | distinct client objects: 30`. Node, same shape: `connections before: 2 | connections after 30 getCollection() calls: 62 delta: 60 | distinct MongoClient objects: 30`. Source: tina4_python/docstore/__init__.py:696; docstore.ts:807-808; docstore.rb:741; DocStore.php:1126.

### The ObjectId class the DocStore module exports cannot be encoded by the real driver

- **frameworks:** Python measured; PHP, Ruby, Node share the same design (own zero-dep ObjectId class, exported alongside get_collection)
- **confidence:** MEASURED
- **same code, different outcome:** The documented import is `from tina4_python.docstore import get_collection, ObjectId` (docstore/__init__.py:6, and the same in each CLAUDE.md). Rehydrating an id from a URL parameter — `collection.find_one({"_id": ObjectId(hex)})` — works on the fallback and is rejected outright by the real driver, which cannot serialise a foreign class into BSON. The class is documented as 'interchangeable with bson.ObjectId as a 24-hex string' (:29-30) and it is, as a string; it is not interchangeable as an object, which is exactly how the constructor invites you to use it.
- **discovered:** At deploy, on the first lookup-by-id route — the single most common DocStore call site. Loud, but it means every id-handling call site has to be rewritten to use the driver's own ObjectId, i.e. the code is no longer provider-independent.
- **evidence:** Probe: `[t4objectid] sqlite: 1 | mongo: RAISED InvalidDocument: cannot encode object: ObjectId('6a6e22c3e4d7d21640198c2b'), of type: <class 'tina4_python.docstore.ObjectId'>`. Source: tina4_python/docstore/__init__.py:57-122, :709-714 (__all__ exports ObjectId).

### No DocStore test in any of the four frameworks ever touches a real Mongo collection — the substitutability promise has zero coverage

- **frameworks:** Python, PHP, Ruby, Node
- **confidence:** MEASURED
- **same code, different outcome:** tests/test_docstore.py, tests/DocStoreTest.php, spec/docstore_spec.rb and test/docstore.test.ts exercise only SqliteCollection. Their 'serverless selection' sections assert env-var resolution and that get_collection returns a SqliteCollection when no URI is set — never that the two providers agree on any operation. There is no shared conformance fixture driving the same assertions against both, of the kind used for the write-path contract elsewhere in the stack. A live mongod is available on this host (measured throughout this audit), so the real provider is reachable in CI; it is simply never exercised. This is why every finding above shipped, including ones as visible as a PHP docblock example that cannot run.
- **discovered:** Never from CI. Green suites across all four frameworks are consistent with a completely broken swap in three of them.
- **evidence:** grep -niE 'mongo|MongoClient|serverless' across all four test files returns only docstring text, env-var names, and is_serverless()/isServerless() assertions — no MongoClient, no Mongo::Client, no MongoDB\Client, no pymongo import. Files: /Users/andrevanzuydam/IdeaProjects/tina4-python/tests/test_docstore.py:209-240; /Users/andrevanzuydam/IdeaProjects/tina4-php/tests/DocStoreTest.php:322-340; /Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/docstore_spec.rb:254-275; /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/test/docstore.test.ts:252-270.

## WebSocket backplane / pluggable realtime transport  (4)

### conn.broadcast() inside a WebSocket route handler never crosses the backplane in Ruby or Node — the exact call a developer writes is local-only

- **frameworks:** tina4-ruby, tina4-nodejs (broken). tina4-python, tina4-php route connections publish correctly.
- **confidence:** MEASURED
- **same code, different outcome:** A route handler does `conn.broadcast(msg)` (Ruby) / `conn.broadcast(msg)` (Node). Python: WebSocketConnection.broadcast delegates to the manager (tina4_python/websocket/__init__.py:245-250) which publishes the envelope. PHP: WebSocketConnection::broadcast -> Server::broadcastWebSocket (Tina4/Server.php:1294-1299) which publishes. Ruby: WebSocketConnection#broadcast (lib/tina4/websocket.rb:718-727) iterates `@ws_server.connections` DIRECTLY and calls conn.send_text — it never calls WebSocket#broadcast, so publish_envelope is never reached. Node: the integrated server drives user WS routes through `WsRouteManager` (packages/core/src/websocket.ts:944-1077), a class that contains ZERO backplane references; createRouteConnection wires `broadcast`/`broadcastToRoom` to it at :1109-1111, and server.ts:1816 dispatches upgrades via serveWebSocketRoute. Only the standalone `WebSocketServer` class has a backplane. Frond {% live %} server push is on the same dead path (server.ts:1517). Ruby is additionally self-inconsistent: on the SAME connection object, conn.broadcast_to_room DOES publish while conn.broadcast does not.
- **discovered:** Never locally — one process, one instance, everything works. It bites the first time a second replica exists: in production a user on pod A speaks and users on pod B hear nothing. No error, no warning, no log line; the startup log even says "WebSocket backplane active". The only symptom is missing messages, which reads as a client bug.
- **evidence:** Ran a real RESP pub/sub broker on 127.0.0.1:16379 and traced every command. RUBY (/tmp/wsaudit/connbroadcast_rb.rb): with the backplane confirmed active, `ws.broadcast_all("MANAGER-LEVEL")` -> PUBLISH tina4:ws {..."text":"MANAGER-LEVEL"} appears on the bus; `conn.broadcast("CONN-LEVEL-BROADCAST", include_self: true)` -> NO PUBLISH; `conn.broadcast_to_room("lobby","CONN-LEVEL-ROOM")` -> PUBLISH appears. NODE (/tmp/wsaudit/routemgr_node.mts, one process, backplane active): `new WebSocketServer().broadcast("STANDALONE-CONTROL")` -> PUBLISH appears; `wsRouteManager.broadcastPath("/chat",...)` and `wsRouteManager.broadcastToRoom("lobby",...)` -> NO PUBLISH. Source: tina4-ruby/lib/tina4/websocket.rb:718; tina4-nodejs/packages/core/src/websocket.ts:944,1079,1109-1111; tina4-nodejs/packages/core/src/server.ts:28,1816,1517.

### Ruby raises LoadError out of broadcast() when the provider client gem is absent — Python/PHP/Node log and degrade to local-only

- **frameworks:** tina4-ruby (crashes). tina4-python, tina4-php, tina4-nodejs all degrade cleanly.
- **confidence:** MEASURED
- **same code, different outcome:** Same env var TINA4_WS_BACKPLANE=nats, same app code, client library not installed. Python/PHP/Node: one ERROR log "backplane wiring failed, continuing local-only", process exit 0, local delivery still happens. Ruby: `Tina4::NATSBackplane#initialize` does `raise LoadError` (lib/tina4/websocket_backplane.rb:132, and :78 for redis), but `ensure_backplane` guards with `rescue StandardError` (lib/tina4/websocket.rb:440). LoadError is a ScriptError, NOT a StandardError, so it is not caught — it propagates out of ensure_backplane, out of broadcast_all/broadcast/broadcast_to_room, and kills the caller. Because ensure_backplane runs BEFORE local delivery, even the LOCAL broadcast is aborted. The method's own docstring says "it must NEVER crash a broadcast".
- **discovered:** At deploy, the moment the first message is broadcast — the WS handler blows up with an unhandled LoadError. If the app is developed with TINA4_WS_BACKPLANE unset (create_backplane returns nil, no require happens) and the var is set only in the production manifest, this is a production-only crash.
- **evidence:** BP=nats ruby /tmp/wsaudit/probe_ruby.rb -> `websocket_backplane.rb:132:in 'Tina4::NATSBackplane#initialize': The 'nats-pure' gem is required (LoadError)` ... `from websocket.rb:434:in 'ensure_backplane'` ... `from websocket.rb:235:in 'broadcast_all'`, process exit=1. Same run for Python -> "ERROR ... continuing local-only", exit=0; PHP -> "backplane active: false", exit=0; Node -> "NODE ERROR: ... continuing local-only", exit=0. Source: tina4-ruby/lib/tina4/websocket.rb:440 (rescue StandardError) vs websocket_backplane.rb:78,132 (raise LoadError).

### Ruby reports "backplane active" when the backplane is unreachable — the connection error dies inside the subscriber thread and the instance never receives anything, ever

- **frameworks:** tina4-ruby (false positive). tina4-python, tina4-php, tina4-nodejs correctly report inactive.
- **confidence:** MEASURED
- **same code, different outcome:** TINA4_WS_BACKPLANE=redis pointed at a host that refuses the connection. Python/PHP/Node: `create_backplane()` or `subscribe()` raises on the calling thread, the manager sets backplane = null, logs one ERROR "continuing local-only", and every later publish is a silent no-op. Ruby: `RedisBackplane#subscribe` (websocket_backplane.rb:94-102) does the connect inside `Thread.new`, so ensure_backplane sees no error, keeps @backplane non-nil, and logs INFO "WebSocket backplane active (instance ..., channel 'tina4:ws')". The subscriber thread is dead and is never retried, so that instance can never receive a sibling broadcast even after Redis comes back; meanwhile every single broadcast logs a WARNING.
- **discovered:** Never from the logs — the startup line says the backplane is active, which is what an operator greps for. It surfaces as an unexplained per-broadcast WARNING flood plus one-way message flow that never self-heals after a Redis restart.
- **evidence:** /tmp/wsaudit/probe_ruby3.rb against a dead port 16999: `[INFO] WebSocket backplane active (instance c1cde9bad7d34b10, channel 'tina4:ws')` followed by three `[WARNING] WebSocket backplane publish failed: Connection refused` (one per broadcast) and `RUBY backplane object present: true`. Same dead port: Python -> `[ERROR] ... Connection refused` + `backplane active: False`; Node -> `NODE ERROR: ... ECONNREFUSED` + `active: false`; PHP -> `backplane active: false`. Source: tina4-ruby/lib/tina4/websocket_backplane.rb:94-102.

### Binary broadcasts are relayed as RFC-6455-illegal TEXT frames by PHP and Ruby — the browser must kill the connection

- **frameworks:** tina4-php and tina4-ruby emit opcode 0x1 for binary; tina4-python and tina4-nodejs emit 0x2 correctly
- **confidence:** MEASURED
- **same code, different outcome:** An app broadcasts bytes (Python `b"..."`, Node `Buffer`, Ruby an ASCII-8BIT string). All four publish the same envelope with the payload under `b64`. On relay: Python `send()` picks OP_BINARY for bytes (websocket/__init__.py:232-235) and Node `safeSend()` picks OP_BINARY for a Buffer (websocket.ts:668-669). PHP's relay calls `WebSocket::buildFrame($message)` whose opcode parameter DEFAULTS to OP_TEXT (Tina4/WebSocket.php:778) and no caller ever overrides it. Ruby's `WebSocketConnection#send` HARDCODES `build_frame(0x1, data)` (lib/tina4/websocket.rb:738) — Ruby can never emit a binary frame at all. RFC 6455 s5.6 requires a Text frame payload to be valid UTF-8 and s8.1 requires the receiving endpoint to Fail the WebSocket Connection on invalid UTF-8, so a browser attached to the PHP or Ruby instance is disconnected (1007) while the same message on the Python/Node instance arrives fine. PHP additionally classifies binary by CONTENT (mb_check_encoding, Bootstrap/WebSocketBackplane.php:707) while the other three classify by TYPE, so PHP silently reclassifies UTF-8-valid bytes as text.
- **discovered:** Only in production, only on the instances that happen to be PHP or Ruby, and only for binary payloads — as clients randomly dropping with close code 1007. Never locally on a single instance if that instance is the publisher (the publisher's own local delivery in Python/Node is correct).
- **evidence:** Fed the identical envelope {"src":"OTHER-INSTANCE","kind":"all","b64":base64("\xff\xfe\x00binary")} through each relay and read the first frame byte off a real socket. RUBY (/tmp/wsaudit/opcode_rb.rb, real TCP peer): first byte 0x81, bytes=[129,9,255,254,0,98,105,110,97,114,121] — FIN|TEXT carrying invalid UTF-8. PHP (\Tina4\WebSocket::buildFrame): 0x81, 129,9,255,254,0,... PYTHON (build_frame(OP_BINARY,...)): 0x82, [130,9,255,254,0,...]. Cross-framework relay verified end to end over the real bus: Python published the b64 envelope, a PHP subscriber relayed it byte-exact (255,254,0,98,105,110,97,114,121) and would then frame it as 0x81.

## feature 1 DotEnv parser  (3)

### A quoted value with a trailing comment keeps its quote characters on 3 of 4

- **frameworks:** python, ruby, node (wrong); php (right)
- **confidence:** MEASURED
- **same code, different outcome:** The line `PW="s3cret" # the database password` parses to `s3cret` on PHP and to the 8-character string `"s3cret"` (literal double quotes included) on Python, Ruby and Node. Same for single quotes: `SQ='lit' # note` -> `lit` on PHP, `'lit'` elsewhere. Python/Ruby/Node decide 'is this quoted?' by testing the FIRST and LAST character of the value (python dotenv/__init__.py:57,62; node dotenv.ts:90,100; ruby env.rb ~340); a trailing comment makes the last character non-quote, so the value falls to the unquoted branch, which strips only the ` #` comment and leaves the quotes in the value. PHP instead scans for the CLOSING quote and discards the remainder (DotEnv.php:190-205), which is what every mainstream dotenv implementation does. A quoted secret with an explanatory comment is the single most common .env line there is; on 3 of 4 the credential handed to the driver has quote characters baked into it.
- **least-code fix:** Adopt PHP's shape in the other three: when the value starts with a quote, find the terminating quote and drop everything after it, instead of testing the last character. That is a two-line change per framework and it deletes the separate 'strip ` #` comment' step for quoted values. Add the row `PW="s3cret" # comment` -> `s3cret` to the shared dotenv_corpus.json (already byte-identical in all four) so it can never regress.
- **evidence:** Probe: wrote one .env containing `PW="s3cret" # the database password` and `SQ='lit' # note`, then called load_env/loadEnv/Env.load_env in all four. python PW="\"s3cret\"" ruby PW="\"s3cret\"" node PW="\"s3cret\"" php PW="s3cret". Sources: /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/dotenv/__init__.py:57-70, /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/core/src/dotenv.ts:90-116, /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/env.rb:340-366, /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/DotEnv.php:183-225

### The double-quote escape table is a 2-2 split, and PHP truncates at the first escaped quote

- **frameworks:** all four, three different answers
- **confidence:** MEASURED
- **same code, different outcome:** Escapes honoured inside a double-quoted value: Python and Ruby handle \n \t \\ only; PHP and Node handle \n \r \t \" \\. So `CR="a\rb"` yields a real carriage return on PHP/Node and the literal two characters backslash-r on Python/Ruby. Worse, PHP's own \" support is unreachable: DotEnv.php:191 does strpos($value,'"',1) to find the closing quote WITHOUT skipping backslash-escaped quotes, so `DQ="say \"hi\""` is truncated at the first inner quote and PHP stores `say \`. Four frameworks, four different values from one line.
- **least-code fix:** One escape table, five entries (\n \r \t \" \\), stated once per framework: add \r and \" to Python and Ruby (one line each). Fix PHP's terminator scan in the same edit - the closing-quote search must skip a quote preceded by a backslash, which is the change that makes PHP's existing \" entry reachable. Add both lines to dotenv_corpus.json.
- **evidence:** Probe: one .env with `CR="a\rb"` and `DQ="say \"hi\""`. CR -> python "a\\rb", ruby "a\\rb", php real CR, node real CR. DQ -> python "say \\\"hi\\\"", ruby same, php "say \\" (truncated), node "say \"hi\"". Sources: /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/DotEnv.php:191-201, /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/dotenv/__init__.py:63, /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/env.rb:347-349, /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/core/src/dotenv.ts:93-98

### Backslash line-continuation is a Node-only extension, so a .env produces a different VARIABLE SET

- **frameworks:** node (extra rule); python, php, ruby (no rule)
- **confidence:** MEASURED
- **same code, different outcome:** node dotenv.ts:106-109 joins a value ending in a backslash with the following line. Python, PHP and Ruby have no such rule. Given `CONT=part1\` followed by `CONT_TAIL`, Node yields CONT="part1CONT_TAIL" and no CONT_TAIL; the other three yield CONT="part1\" and skip the CONT_TAIL line as malformed (PHP and Ruby at least warn; Python warns too). This is not a value difference, it is a different set of variables from the same file - the strongest form of swap break.
- **least-code fix:** Delete the continuation loop from Node (4 lines removed, nothing added). It is undocumented in the env-var chapters, absent from the corpus, and absent from the other three. If continuation is genuinely wanted it has to land in all four with a corpus row - but the LESS_CODE answer is to remove it.
- **evidence:** Probe: .env containing `CONT=part1\` newline `CONT_TAIL`. node CONT="part1CONT_TAIL", CONT_TAIL=null; python/php/ruby CONT="part1\\", CONT_TAIL=null with a 'no = in CONT_TAIL, line skipped' warning. Source: /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/core/src/dotenv.ts:105-109

## feature 2 Structured logger  (4)

### Production log format is selected from a DIFFERENT env var per framework - one container, two formats

- **frameworks:** python+ruby (TINA4_ENV) vs php+node (TINA4_DEBUG)
- **confidence:** MEASURED
- **same code, different outcome:** Python (core/server.py:3195) and Ruby (log.rb:289-292) decide 'production' from TINA4_ENV/RACK_ENV/RUBY_ENV; PHP (App.php:291-294) and Node (logger.ts:439-441) decide it from TINA4_DEBUG. In an ordinary container that sets neither, PHP and Node emit one JSON object per line with no ANSI, while Python and Ruby emit coloured human-readable text - ANSI escape codes straight into the aggregator. Setting TINA4_DEBUG=true with TINA4_ENV=production inverts the split: PHP/Node go back to coloured text while Python/Ruby emit JSON. There is no single env var that makes all four agree except by setting both.
- **least-code fix:** Pick TINA4_DEBUG - it is already the gate for the error overlay, dev toolbar, swagger, MCP and the log-file default in all four. Delete the TINA4_ENV/RACK_ENV/RUBY_ENV read from Ruby (log.rb:289-292, 4 lines) and from Python's boot (server.py:3195), and delete the `production`/`development` parameter from Python's and PHP's configure(). Net: less code, one fact, one place.
- **evidence:** Probe replicating each framework's own boot call, TINA4_DEBUG and TINA4_ENV both unset: python/ruby -> '\e[32m2026-...Z [INFO    ] probe-info\e[0m'; php/node -> '{"timestamp":"...","level":"INFO","message":"probe-info"}'. With TINA4_ENV=production TINA4_DEBUG=true the pairing flips (php/node text+colour, python/ruby JSON).

### TINA4_LOG_OUTPUT=stdout means two different things - Python and Node cannot tell it from unset

- **frameworks:** python+node vs php+ruby
- **confidence:** MEASURED
- **same code, different outcome:** Python (debug/__init__.py:276-291) and Node (logger.ts:269-288) default the variable to the string 'stdout', so an explicitly-set TINA4_LOG_OUTPUT=stdout is indistinguishable from unset and still takes the dev-gated file branch. PHP (Log.php:176-180) and Ruby (log.rb:149-155) treat 'stdout' as an explicit sink selection and write no file. Two measured symptoms of the one root cause: (a) with TINA4_LOG_OUTPUT=stdout TINA4_DEBUG=true, Python and Node write logs/tina4.log + logs/error.log while PHP and Ruby write nothing; (b) with TINA4_LOG_OUTPUT=stdout plus an explicit TINA4_LOG_FILE, Python and Node write the operator's named file (the documented 'explicit wins') while PHP and Ruby silently write nothing - PHP at Log.php:179 and Ruby at log.rb:187 discard the named path. The same side effect also swallows a typo: an unrecognised value falls back silently in all four, so TINA4_LOG_OUTPUT=stout is never reported, unlike TINA4_SESSION_BACKEND which raises.
- **least-code fix:** Read the variable as absent-or-set, not as a string with a default: in Python `os.environ.get('TINA4_LOG_OUTPUT')` (None when unset) and in Node `process.env.TINA4_LOG_OUTPUT ?? ''`, applying the dev-gated default only in the unset branch - about three lines each. Then settle the (b) conflict once: TINA4_LOG_OUTPUT selects the SINKS and TINA4_LOG_FILE only names where the file goes. That lets you delete the 'an explicit TINA4_LOG_FILE forces a file' branch from all four (logger.ts:284-285, Log.php:121+203, log.rb:143-148, debug/__init__.py:357-364) - strictly less code than reconciling it. While in there, raise on an unrecognised value, matching TINA4_SESSION_BACKEND.
- **evidence:** Probe (a): TINA4_DEBUG=true TINA4_LOG_OUTPUT=stdout TINA4_LOG_DIR=<tmp> -> python 'error.log tina4.log', node 'error.log tina4.log', php '', ruby ''. Probe (b): TINA4_DEBUG=false TINA4_LOG_OUTPUT=stdout TINA4_LOG_FILE=<tmp>/app.log -> python 'app.log', node 'app.log', php '', ruby ''.

### TINA4_LOG_LEVEL has two value spellings and one value that means the opposite thing

- **frameworks:** ruby (extra spellings + NONE); python, php, node (silent fallback); python (never reads it outside the server boot)
- **confidence:** MEASURED
- **same code, different outcome:** Ruby accepts both plain names and a bracket form (log.rb:346-356), and defines NONE=5 to silence everything; Tina4::Env's own advertised default for the variable is the bracket string '[TINA4_LOG_ALL]' (env.rb:92) and the Ruby CLI prints TINA4_LOG_LEVEL=ALL (cli.rb:3150). Python/PHP/Node understand neither NONE nor the bracket form. Measured: TINA4_LOG_LEVEL=NONE silences Ruby completely and produces FULL INFO+WARNING output on the other three (Python and Node fall through to threshold 0, PHP keeps INFO) - an operator asking for silence gets maximum verbosity on three of four. TINA4_LOG_LEVEL=[TINA4_LOG_ERROR] behaves as ERROR on Ruby and is ignored everywhere else. Separately, Python's Log class never reads TINA4_LOG_LEVEL at all - only core/server.py:3200 does - so any process that does not boot the HTTP server (the documented standalone worker.py queue-consumer pattern) ignores the variable entirely.
- **least-code fix:** One value space: plain names only, plus NONE, in all four. Delete Ruby's bracket-form branch (log.rb:354) and change the Env default at env.rb:92 to 'INFO'; add NONE to the three level maps (one entry each). Make Python's Log read TINA4_LOG_LEVEL itself the way Node's readEnv does, which also lets you delete the `level` parameter from configure() and the read at server.py:3200.
- **evidence:** Probe logging INFO then WARNING through each framework's boot path: TINA4_LOG_LEVEL=NONE -> python '[INFO [WARNING', php '[INFO [WARNING', node '[INFO [WARNING', ruby '' ; TINA4_LOG_LEVEL=[TINA4_LOG_ERROR] -> ruby '' and the other three '[INFO [WARNING'; TINA4_LOG_LEVEL=ERROR -> all four silent. Separate probe: a script that calls Log.info/Log.error with no configure() and TINA4_LOG_LEVEL=ERROR printed BOTH lines on Python (level ignored) and only the error on Ruby and Node.

### TINA4_LOG_DIR is ignored on Ruby's boot path and log files land in the project root

- **frameworks:** ruby
- **confidence:** MEASURED
- **same code, different outcome:** log.rb:88-93 resolves `chosen = target || ENV['TINA4_LOG_DIR'] || 'logs'` - the positional argument wins over the env var. lib/tina4.rb:392 calls Tina4::Log.configure(root_dir), passing the PROJECT ROOT. Under the old semantics the argument WAS a root and 'logs/' was appended; the audit changed the argument to mean the log DIRECTORY (documented as breaking at log.rb:82-87) but the framework's own boot call was never updated. Result: a Ruby app writes tina4.log and error.log into the project root, where Python, PHP and Node write <TINA4_LOG_DIR or logs>/tina4.log, and setting TINA4_LOG_DIR on Ruby has no effect at all.
- **least-code fix:** Delete the argument: change lib/tina4.rb:392 to `Tina4::Log.configure` (one word removed). The env var and the 'logs' default then apply exactly as in the other three. Add the negative test 'configure_does_not_write_into_the_project_root' that the feature plan already specified.
- **evidence:** Probe replicating lib/tina4.rb:392 - Tina4::Log.configure(Dir.pwd) with TINA4_LOG_DIR=<tmp>/wanted and TINA4_DEBUG=true - reported log_dir=<cwd>, log_file=<cwd>/tina4.log, and left tina4.log + error.log in the cwd with <tmp>/wanted empty. Source: /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4.rb:392 and /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/log.rb:88-93.

## feature 5 DATABASE_URL parser (the principle-2 reference)  (1)

### The scheme-to-engine table differs in all four - the one mechanism the whole principle rests on

- **frameworks:** php (missing mongodb, odbc, hostless); ruby (extra mongo); node (extra mongodb+srv); python (baseline)
- **confidence:** MEASURED
- **same code, different outcome:** 'The SCHEME selects the provider' is the reference contract, and no two frameworks accept the same set. mongodb:// parses on Python, Ruby and Node and RAISES on PHP (its ENGINE_ALIASES stops at firebird, DatabaseUrl.php:32-42, and PHP has no Mongo database adapter). mongo:// is accepted only by Ruby. mongodb+srv:// - the standard Atlas SRV URI - is accepted only by Node. odbc:///DSN=x parses on Python, Ruby and Node and RAISES on PHP. A hostless URL such as postgres:///db parses on Python/Ruby/Node (host null, port defaulted) and RAISES on PHP with 'Invalid URL format'. Each framework's error message then prints a DIFFERENT 'Supported:' list, so the user is told a different truth per provider. The shared answer key cannot catch any of it: database_url_corpus.json (byte-identical in all four) has 19 cases, none for mongodb, mongo, mongodb+srv, odbc or a hostless URL, and its default_ports block omits mongodb.
- **least-code fix:** Move the alias table INTO database_url_corpus.json (it already has an `aliases` block covering only four of them) and have each suite assert its own table equals the fixture's - that is one assertion per framework and it makes any future divergence impossible. Then settle the four disputed entries once: drop Ruby's mongo:// (one line deleted, it is not a real URI scheme), add mongodb+srv to the other three (one line each, it is the scheme MongoDB Atlas actually hands you), and add mongodb + odbc + the hostless-URL branch to PHP. PHP having no Mongo/ODBC adapter is a separate capability question, but the PARSER refusing a scheme the other three accept is the swap break and it is three table entries.
- **evidence:** Probe constructing DatabaseUrl in all four for five URLs. mongodb://localhost:27017/app -> OK python/ruby/node, RAISE php 'Unsupported database scheme mongodb'. mongo://... -> OK ruby only. mongodb+srv://... -> OK node only. odbc:///DSN=x -> OK python/ruby/node, RAISE php 'Invalid URL format'. postgres:///db -> OK python/ruby/node (host null, port 5432), RAISE php 'Invalid URL format'. Tables: /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/DatabaseUrl.php:32-42, /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/database_url.rb:33-46, /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/database/database_url.py:29-41, /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/orm/src/databaseUrl.ts:32-45

## feature 3 - DB adapter interface  (2)

### TINA4_AUTOCOMMIT=false is a silent no-op on 6 of the 8 framework/provider pairs measured

- **frameworks:** all four
- **confidence:** MEASURED
- **same code, different outcome:** All four CLAUDE.md files document TINA4_AUTOCOMMIT=false as "strict manual-commit mode (every write needs an explicit commit())". I wrote a row with autocommit off, closed the connection without committing, reopened and counted. Measured rows-visible-without-commit: Python+SQLite 1 (NO-OP), Python+Postgres 0 (honoured), Python+MySQL 0 (honoured), PHP+SQLite 1, PHP+Postgres 1, PHP+MySQL 0 (honoured - MySQLAdapter is the only PHP adapter that calls the driver's own autocommit()), Ruby+SQLite 1, Ruby+Postgres 1, Node+SQLite 1, Node+Postgres 1. So the knob delivers its promise in 3 of 10 measured combinations. The dangerous direction is Python: it works on the server (Postgres/MySQL) and is a no-op on the laptop (SQLite), so code that forgets a commit() passes locally and silently drops every write in production. Root cause is that nobody issues a BEGIN when autocommit is off - PHP's AutocommitTrait docblock states it outright: the flag only governs "whether Tina4 issues its own commit after a standalone write", and with no BEGIN the driver has already committed.
- **least-code fix:** Two options, and the smaller one is deletion. (a) Make it real in ONE place: when autocommit is off and no explicit transaction is open, issue BEGIN before the first statement - Python's SQLite adapter already has _in_transaction and a BEGIN at sqlite.py:213, it just never fires on this path. That is one branch per adapter x 4 frameworks. (b) DELETE the knob from all four and document Tina4 as autocommit-only with explicit transactions. Option (b) removes an `if autocommit` branch from every write path in four frameworks and removes a config item that today lies to the operator. Recommend (b) unless a user is known to rely on it.
- **evidence:** MEASURED via /tmp/f34audit/ac_py.py, ac_php.php, ac_php2.php, ac_rb.rb, ac_node.mts against live sqlite/postgres:55432/mysql:3306. Code: tina4-python/tina4_python/database/sqlite.py:58 (isolation_level=None) + :104-106; tina4-php/Tina4/Database/AutocommitTrait.php:26-28; tina4-ruby/lib/tina4/database.rb:1346-1350; tina4-nodejs/packages/orm/src/database.ts:657-659

### Node's DatabaseAdapter interface is synchronous, so every non-SQLite adapter is ~95 throwing stubs plus a parallel *Async twin set

- **frameworks:** nodejs
- **confidence:** MEASURED
- **same code, different outcome:** types.ts:61-101 declares DatabaseAdapter with synchronous returns (execute(): unknown, insert(): DatabaseResult, getTables(): string[] ...). Only node:sqlite can satisfy that. The other six adapters implement every interface method purely to throw "Use xAsync() for PostgreSQL" - 15 stubs each for postgres/mysql/mssql/firebird, 15 for mongodb, 17 for odbc, ~95 methods total - and ship a full second set of *Async twins. Database.ts then dispatches through ~20 `(adapter as any).xAsync ? await (adapter as any).xAsync(...) : adapter.x(...)` ternaries, each an `as any` that defeats the interface it is dispatching on. This is not cosmetic: every ternary is a place a provider can be forgotten, and one already is. postgres.ts:172-177 executeManyAsync reads `"lastId" in result` - a shape only the node:sqlite path produces, since pg's Result has no lastId - so a batch insert loses the id on Postgres. MEASURED: db.insert("probe_a", [3 rows]) returned lastId 4 on SQLite and undefined on Postgres, with db.getLastId() left stale at 1.
- **least-code fix:** Declare DatabaseAdapter async (Promise<T> returns) and delete both the ~95 sync stubs and the *Async twins, keeping one method per operation. SQLiteAdapter wraps its synchronous node:sqlite calls in already-resolved promises (a one-word change per method, no behavioural cost - the calls stay sync). The ~20 dispatch ternaries and their `as any` casts in database.ts collapse to plain `await adapter.x(...)`. This is a large deletion, not an addition, and it removes the class of bug that lost the batch lastId.
- **evidence:** MEASURED via /tmp/f34audit/probe_node.mts (insert_batch3: sqlite lastId=4, postgres lastId=undefined, getLastId=1). Code: packages/orm/src/types.ts:61-101; packages/orm/src/adapters/postgres.ts:152,156,201,213,228,237,283,326,364,378,389,399,416,476,490 (throwing stubs) and :172-177 (the lastId read); packages/orm/src/database.ts:47-72, 676-677, 773-774, 802-803, 815-816

## feature 4 - SQLite adapter + write path  (8)

### insert() loses the generated key on PostgreSQL when the primary-key column is not named `id`; Python then writes ANOTHER TABLE'S id onto the model

- **frameworks:** python (worst), ruby, nodejs
- **confidence:** MEASURED
- **same code, different outcome:** Identical application code - a model with `widget_id = IntegerField(primary_key=True, auto_increment=True)` and `Widget(name="first widget").save()`. On SQLite the model comes back with widget_id 1, the real value. On PostgreSQL the model comes back with widget_id 5 while the row in the database has widget_id 1. The 5 is the id of an unrelated row in a different table, inserted earlier on the same connection. The chain: postgres.py:307 reads the generated key as records[0]["id"] by hardcoded column name, so it is None for a widget_id PK; connection.py:716 only overwrites the cached _last_id when the new one is not None, so db.get_last_id() keeps the stale value; orm/model.py:549-552 assigns that stale value to the model's PK. The developer then redirects to /widget/5, or calls save() again and the UPDATE lands on WHERE widget_id = 5 and silently changes nothing. Ruby and Node have the same hardcoded-`id` read: Ruby's db.insert(...).last_id is nil on Postgres and 1 on SQLite (Ruby's last_insert_id happens to recover via the lastval() fallback); Node's is undefined on Postgres and 1 on SQLite, with getLastId() left stale.
- **least-code fix:** Stop guessing the column. Every framework already introspects and caches the primary key (Database.primary_key/primaryKey, built on the cross-engine getColumns contract), and PHP's ORM already does the right thing at ORM.php:2149-2151 by emitting `RETURNING <pkColumn>`. Change INSERT_RETURNING from `RETURNING *` to the introspected key columns and read them by name. That is one call site per framework and it deletes the three bespoke id-guessing helpers (see the LESS_CODE finding below). A one-line stopgap that does NOT fix it: falling back to lastval() when the id read comes back empty - that is what accidentally saves Ruby, and it is wrong for UUID/composite keys.
- **evidence:** MEASURED via /tmp/f34audit/probe_orm.py: {"engine":"sqlite","model_pk_after_save":1,"actual_pk_in_db":1} vs {"engine":"postgres","model_pk_after_save":5,"actual_pk_in_db":1}. Code: tina4-python/tina4_python/database/postgres.py:307-308; tina4-python/tina4_python/database/connection.py:716-717; tina4-python/tina4_python/orm/model.py:549-552; tina4-ruby/lib/tina4/drivers/postgres_driver.rb:300-304; tina4-nodejs/packages/orm/src/adapters/postgres.ts:269-270 and :194-196

### PHP reads the FIRST column of `RETURNING *` as the id, so a table whose PK is not its first column reports a data value as lastId

- **frameworks:** php
- **confidence:** MEASURED
- **same code, different outcome:** `CREATE TABLE pk_last (name VARCHAR(40), note VARCHAR(40), id SERIAL PRIMARY KEY)` then `$db->insert('pk_last', ['name'=>'x','note'=>'y'])`. MEASURED lastId: SQLite int(1) - correct; PostgreSQL string("x") - the value of the name column. PostgresAdapter uses reset($rows[0]) / reset($row) to pick the id, i.e. positional first column of RETURNING *, which is column-declaration order, not the primary key. $db->getLastId() is polluted with "x" too, so any subsequent code reading it gets the same garbage. Separately and on the same code path: lastId is an int on SQLite and a PHP string on PostgreSQL even in the ordinary case ('1' vs 1), because execute() reads pg_fetch_assoc directly and skips the buildColumnCasters type map that query() applies - so a strict `=== 1` and a JSON body both change shape on the swap.
- **least-code fix:** Same one fix as the finding above - emit `RETURNING <introspected pk columns>` instead of `RETURNING *` (PostgresAdapter.php:31) and read the value by column name rather than by position. That removes both reset() calls and makes the type cast a single named lookup that can go through buildColumnCasters.
- **evidence:** MEASURED via /tmp/f34audit/php_orm.php: {"engine":"sqlite","insert_pk_not_first_lastId":1,"type":"integer"} vs {"engine":"postgres","insert_pk_not_first_lastId":"x","type":"string"}; and /tmp/f34audit/php_lastid.php (lastId='1' type=string on PG, int on SQLite). Code: tina4-php/Tina4/Database/PostgresAdapter.php:181-186 and :286-294

### getLastId() after execute("INSERT ...") returns a STALE id on PostgreSQL in PHP and Node

- **frameworks:** php, nodejs
- **confidence:** MEASURED
- **same code, different outcome:** PHP, in autocommit (the default): I inserted 'two' (real id 2) and 'three' (real id 3) via $db->execute("INSERT INTO li_probe (name) VALUES (?)") and $db->getLastId() returned '1' after BOTH. Inside an explicit startTransaction() it returned the correct '4'. Cause: the lastval() probe at PostgresAdapter.php:310-328 is gated on `pg_query('SAVEPOINT _t4_lastval_probe')` succeeding, and SAVEPOINT is invalid outside a transaction block, so in autocommit mode the whole probe block is skipped and $this->lastId keeps its previous value. Node has the same symptom with a different cause: postgres.ts executeAsync only sets _lastInsertId when result.rows?.[0]?.id exists, and a bare INSERT with no RETURNING returns no rows - there is no lastval() fallback at all. MEASURED Node: id 5 written, getLastId() returned 1. On SQLite both frameworks return the correct new id every time.
- **least-code fix:** PHP: the SAVEPOINT wrapper exists only to protect an open transaction from psycopg2-style abort. Run the plain `SELECT lastval()` when SAVEPOINT fails (i.e. when there is no transaction) instead of skipping the probe - Ruby already does exactly this at postgres_driver.rb:135-143. Roughly four lines. Node: add the same lastval() probe for a no-RETURNING INSERT (it has none today). Both become unnecessary if the RETURNING-by-pk-name fix above is applied to db.insert(), but execute("INSERT ...") is a raw-SQL path so it still needs the probe.
- **evidence:** MEASURED via /tmp/f34audit/php_lastid.php (after execute(INSERT) getLastId='1', ACTUAL id of 'two' = 2; ACTUAL id of 'three' = 3; in-txn getLastId='4') and /tmp/f34audit/probe_node.mts (getLastId_after_execute_insert: sqlite 5, postgres 1). Code: tina4-php/Tina4/Database/PostgresAdapter.php:310-328; tina4-nodejs/packages/orm/src/adapters/postgres.ts:190-198

### MySQL reports CHANGED rows where SQLite and PostgreSQL report MATCHED rows - in Python, PHP and Ruby but not Node

- **frameworks:** python, php, ruby (nodejs differs from all three)
- **confidence:** MEASURED
- **same code, different outcome:** Run the same update twice: db.update("t", {"name": "z"}, "qty = ?", [2]) against three rows that already hold name='z'. MEASURED affected_rows on the second call: SQLite 3, PostgreSQL 3, MySQL 0 in Python, 0 in PHP, 0 in Ruby, 3 in Node. So `if db.update(...).affected_rows == 0: return 404` (or the same test to detect a lost optimistic-lock update) is correct on the laptop and wrong in production on MySQL for three of the four frameworks - every idempotent save 404s. Node is right by accident: mysql2 includes CLIENT_FOUND_ROWS in its default connection flags (node_modules/mysql2/lib/connection_config.js:230); none of the four adapters asks for it explicitly, so Node also has a divergence from its three siblings on the same engine.
- **least-code fix:** One argument at each of the three connect() call sites: Python `client_flags=[mysql.connector.ClientFlag.FOUND_ROWS]`, Ruby `flags: [:FOUND_ROWS]` on Mysql2::Client.new, PHP `CLIENT_FOUND_ROWS` in the mysqli_real_connect flags. Three lines total, and it makes MySQL agree with the SQLite/PostgreSQL/Node answer rather than making the other three agree with MySQL.
- **evidence:** MEASURED: /tmp/f34audit/probe_py_mysql.py update_noop_same_value affected=0 vs probe_py.py sqlite/postgres affected=3; mysql_php.php {"update_noop_same":0}; mysql_rb.rb {"update_noop_same":0}; mysql_node.mts {"update_noop_same":3}. Code (no found-rows flag set): tina4-python/tina4_python/database/mysql.py:50; tina4-php/Tina4/Database/MySQLAdapter.php:112; tina4-ruby/lib/tina4/drivers/mysql_driver.rb:36

### PHP on MySQL returns every column as a string; the same code on SQLite and PostgreSQL returns native types

- **frameworks:** php
- **confidence:** MEASURED
- **same code, different outcome:** Same table, same select, three engines. MEASURED PHP fetchOne types: SQLite {id:integer, name:string, qty:integer, price:double}, PostgreSQL {id:integer, name:string, qty:integer, price:double}, MySQL {id:string, name:string, qty:string, price:string} with the row reading {"id":"1","qty":"42","price":"1.50"}. A JSON API developed on SQLite emits "qty": 42 locally and "qty": "42" in production, and `$row['qty'] === 42` flips from true to false. PostgresAdapter.php already fixed exactly this class of bug for its own engine - buildColumnCasters at :165, whose docblock says it exists "so a Tina4 app on SQLite (native-ish types) sees the SAME shapes on PostgreSQL" - and MySQLAdapter never got the equivalent. Python and Ruby return native types on all three engines, so this is PHP-only.
- **least-code fix:** One line at MySQLAdapter's connect, before mysqli_real_connect: `$this->db->options(MYSQLI_OPT_INT_AND_FLOAT_NATIVE, 1);`. I verified against the live MySQL that this returns int(42) for an INTEGER column. Cheaper than the per-column caster map PostgresAdapter builds, and it makes MySQL match without adding a second copy of that map.
- **evidence:** MEASURED via /tmp/f34audit/types_php.php (three engines) against types_py.py and types_rb.rb which return int/Integer on all three. Fix verified: `$m->options(MYSQLI_OPT_INT_AND_FLOAT_NATIVE, 1)` returns int(42) for the same query. Code: tina4-php/Tina4/Database/PostgresAdapter.php:160-176 (the fix, PG only); tina4-php/Tina4/Database/MySQLAdapter.php:112 (no equivalent)

### Python's insert() result carries the inserted ROW on PostgreSQL and nothing on SQLite

- **frameworks:** python
- **confidence:** MEASURED
- **same code, different outcome:** db.insert("t", {...}) returns a DatabaseResult. MEASURED on SQLite: count 0, records 0, len(result) 0, iterating yields nothing. MEASURED on PostgreSQL: count 1, records 1, len(result) 1, iterating yields the full inserted row [['id','name']]. The cause is that the base adapter appends INSERT_RETURNING = " RETURNING *" for PostgreSQL only (adapter.py:539), so the PG path materialises the row while SQLite does not. Because response() auto-serialises a DatabaseResult to a JSON array, `return response(db.insert("users", data))` sends `[]` from the laptop and `[{"id":1,"name":...}]` from the server - a different HTTP body from byte-identical code. len(result) and `for row in result` diverge the same way.
- **least-code fix:** Decide which one insert() promises and enforce it in Database.insert (connection.py:711-718), the single funnel both engines pass through. The smaller and safer choice is "a write result carries no rows": clear records/count there, exactly as _without_last_id (connection.py:827-836) already normalises last_id for update/delete. That is a two-line addition in one method and no adapter changes. Narrowing the contract is also the honest framing - a write result that sometimes contains the row is a promise only one engine can keep.
- **evidence:** MEASURED via /tmp/f34audit/fetch_all.py: sqlite {"insert_len":0,"insert_records":0,"insert_iter":[]} vs postgres {"insert_len":1,"insert_records":1,"insert_iter":[["id","name"]]}. Code: tina4-python/tina4_python/database/adapter.py:536-539, 578-584; tina4-python/tina4_python/database/postgres.py:305-308, 344-351; tina4-python/tina4_python/database/sqlite.py:108-115

### execute_many()/executeMany() reports three different affected counts for one identical call, and Node returns raw driver objects

- **frameworks:** all four
- **confidence:** MEASURED
- **same code, different outcome:** Same batch UPDATE, `execute_many("UPDATE t SET qty = 6 WHERE qty = ?", [[5],[6]])`. MEASURED Python affected_rows: SQLite 2, MySQL 3, PostgreSQL 6. SQLite's adapter hardcodes `affected = len(rows)` (the number of parameter SETS, sqlite.py:140) because sqlite3's cursor.rowcount is unreliable after executemany; PostgreSQL sums the real per-statement rowcounts; MySQL sums its own changed-row counts. For a batch INSERT the two definitions coincide, which is why this has not been noticed. PHP returns 2 on both engines (parameter-set count). Node does not return a count at all: db.executeMany resolves to an ARRAY of raw driver result objects - node:sqlite {lastInsertRowid, changes} on SQLite and a full pg Result on PostgreSQL - so `results[0].changes` works on SQLite and is undefined on PostgreSQL. Node's own comment at database.ts:1005-1007 acknowledges it is the only one of the four doing this.
- **least-code fix:** Narrow the contract rather than chase the counts: define execute_many's affected_rows as the number of parameter sets successfully applied (which is all SQLite can honestly report, and is what PHP already returns on both engines), document it, and make Postgres/MySQL stop summing rowcounts. That is a deletion in the PG/MySQL paths. Node separately needs to return a DatabaseResult like its three siblings instead of an array of driver objects - that also removes the per-row result-fanout loop at database.ts:1000-1012.
- **evidence:** MEASURED via /tmp/f34audit/probe_py.py + probe_py_mysql.py (execute_many_update: sqlite affected=2, postgres affected=6, mysql affected=3), probe_php.php (executeMany_update int(2) on both), probe_node.mts (executeMany_insert returns an array of driver objects, shape differs per engine). Code: tina4-python/tina4_python/database/sqlite.py:136-142; tina4-python/tina4_python/database/adapter.py:376-405; tina4-php/Tina4/Database/Database.php:1497; tina4-nodejs/packages/orm/src/database.ts:971-1010

### "Which column of a RETURNING row holds the generated key" is written four times, four different ways, and three of them are wrong

- **frameworks:** all four
- **confidence:** MEASURED
- **same code, different outcome:** One fact, four locations, no shared artifact: Python reads records[0]["id"] by hardcoded name (postgres.py:307); Ruby reads row[:id] || row["id"] || row[:ID] || row["ID"] by hardcoded name with key-style tolerance (postgres_driver.rb:300-304); Node reads insertedRow?.id by hardcoded name (postgres.ts:270); PHP reads reset($row), the first column by POSITION (PostgresAdapter.php:182, :289). Three of the four are wrong for a PK not named `id` (measured above); the fourth is wrong for a PK that is not the first column (measured above, returned "x"). None of them is right for a composite key. Each also has its own bespoke normaliser for the value - Ruby's normalize_returned_id (postgres_driver.rb:276-295), Node's normalizeId (postgres.ts:139-145) - written to do the same numeric-string coercion.
- **least-code fix:** Do not guess - ask. Every framework already has an introspected, cached primary key (Database.primary_key / primaryKey / primary_key, built on the getColumns contract) and PHP's ORM already emits `RETURNING <pkColumn>` at ORM.php:2149-2151 for exactly this reason. Replace `RETURNING *` with `RETURNING <pk columns>` at the one INSERT-building site per framework and read the values back by name. That deletes four id-guessing branches and two normalisers, and it is the same change that fixes the two SWAP findings above - so the net line count goes DOWN, not up.
- **evidence:** The four sites above; wrongness MEASURED in /tmp/f34audit/probe_orm.py, php_orm.php, probe_rb.rb, probe_node.mts

## feature 6 Router + dispatch  (2)

### TINA4_TRAILING_SLASH_REDIRECT: one env var, four behaviours, and it is a total no-op in Ruby

- **frameworks:** all four diverge; ruby (dead env var) and nodejs (default 404 where three return 200) are the outliers
- **confidence:** MEASURED
- **same code, different outcome:** With the var UNSET, `GET /api/users/` against a route registered as `/api/users` matches on Python (regex ends `/?$`, core/router.py:628), Ruby (find_route chomps the slash unconditionally, router.rb:524) and PHP (match() does `'/' . trim($path,'/')`, Router.php:404) - but NOT on Node, which only de-slashes when the flag is on (router.ts:302-311). With the var set to true: Python 301, PHP 301 (trailingSlashRedirect stage), Node 200 with no redirect, Ruby 200 with the var ignored. Ruby's `Tina4::Router.trailing_slash_redirect?` (router.rb:604) has exactly ONE caller in the whole repo - spec/env_vars_spec.rb:122/128, which asserts only that the reader reads the env. That is a tautological test guarding dead code: the reader is never wired into the dispatch pipeline (REQUEST_STAGES has no trailing-slash stage), so the env var changes nothing. Node's router.ts:288-291 comment says the de-slashed match "lets callers issue a 308 redirect instead of a hard 404" - no caller does; grep for 301/308 in server.ts finds only the status-text table.
- **least-code fix:** Pick ONE default and delete the flag. Three of four already absorb the trailing slash unconditionally at match time in ~1 line; make Node do the same (drop the `isTrailingSlashRedirectEnabled()` guard at router.ts:304) and delete TINA4_TRAILING_SLASH_REDIRECT, Ruby's dead `trailing_slash_redirect?` reader, its tautological spec, Python's `_stage_trailing_slash_redirect`, PHP's `trailingSlashRedirect` stage and the four .env.example lines. That removes a stage from two pipelines and a whole env var from the surface. If a 301 is wanted instead, it must be one behaviour in all four - but that is MORE code than the delete.
- **evidence:** Ran Router.match directly in all four. Python: `/api/users/` -> MATCH (both settings); full handle() -> 301 Location:/api/users with flag on, 200 with it off. Ruby: MATCH both settings; full RackApp#call with flag on -> 200, location=nil. PHP: MATCH both settings. Node: MATCH only with TINA4_TRAILING_SLASH_REDIRECT=true, NO MATCH unset. grep -rn trailing_slash_redirect tina4-ruby -> lib/tina4/router.rb:604 + spec/env_vars_spec.rb only.

### The no-route fallback chain runs in a different order in Node than in the other three

- **frameworks:** nodejs (outlier) vs python, php, ruby
- **confidence:** MEASURED
- **same code, different outcome:** Node's FALLBACK_STAGES (dispatchPipeline.ts:87-93, mirrored by the real function array at server.ts:1356-1362) is template -> landing -> 405 -> static -> 404. Python (_FALLBACK_STAGES at server.py:2455 then _handle_no_route at 1922-1956) is 405 -> static -> template -> landing -> 404. PHP (dispatchNoMatch, Router.php:1660-1716) is 405/OPTIONS -> static -> template -> 404. Ruby (method_not_allowed then not_found -> handle_404, dispatch_pipeline.rb:245-290 and rack_app.rb:321-332) is 405 -> swagger -> static -> template -> landing -> 404. Two observable consequences for identical app code: (a) a GET on a path that only has a non-GET route but does have a pages/ template renders the template with 200 on Node and returns 405+Allow on the other three; (b) when both public/index.html and src/templates/pages/index.twig exist, Node serves the template and the other three serve the static file. Node's own comment at dispatchPipeline.ts:76-79 justifies "405 beats static" but never addresses template-beats-405, which is the divergence.
- **least-code fix:** Reorder Node's FALLBACK_STAGES array to [serveMethodNotAllowed, serveStaticAsset, serveTemplateFallback, serveLandingPage, serveNotFound] and reorder the matching literal in test/dispatchPipeline.test.ts:88-89. Two line moves, no new code - the stage functions and the derived `FALLBACK_STAGES matches the array dispatch really walks` assertion already exist. Then record the chosen order once in dispatch_contract.json as a new invariant rather than in four comments.
- **evidence:** Stood up a real Node server (startServer, port 7911) with only src/routes/submit/post.ts registered plus src/templates/pages/submit.twig. `GET /submit` -> 200, allow=null, body=<h1>TEMPLATE SUBMIT PAGE</h1>. The other three answer 405: their runners walk 405 before the template branch (tina4-python server.py:2455-2458, tina4-php Router.php:1675-1687, tina4-ruby dispatch_pipeline.rb:51-61).

## feature 7 Middleware pipeline  (1)

### Ruby's block-form Middleware.before handler runs TWICE per matched request when any pre-match middleware is registered

- **frameworks:** ruby
- **confidence:** MEASURED
- **same code, different outcome:** Tina4::Middleware.run_before iterates `before_handlers` (the block form) unconditionally at middleware.rb:102-114, before it touches the class list it was passed. The dispatcher calls run_before once per phase: global_middleware_pre (dispatch_pipeline.rb:210) and global_middleware_post (dispatch_pipeline.rb:477). The pre call is guarded by `return nil if middleware.empty?`, so with no pre-match class middleware the blocks run once - but register one and every block before-handler fires twice on every matched request. This is the exact failure mode ADR-0012's after-pass work was created to close (an acquire/release pair going unbalanced), just on the before side. Python has a named regression test for it (tests/test_global_middleware_split.py:187 `test_a_pre_match_global_does_not_run_twice`); Ruby's spec/global_middleware_split_spec.rb has no equivalent case. Separately, the block form is Ruby-only and is documented in-code (middleware.rb:99-104) as keeping a DIFFERENT return contract from the shared table - "false halts", with a returned Response deliberately NOT treated as a short-circuit. One behaviour, two contracts, in one framework.
- **least-code fix:** Delete the block form. `Middleware.before`/`.after`, `before_handlers`/`after_handlers`, `matches_pattern?` and the two unconditional loops in run_before/run_after are ~45 lines that exist in no other framework, carry a contradicting return contract, and are the sole cause of the double-run. Class middleware already covers every use. If it must stay, the minimal fix is to move the block loop out of run_before into the post-match call site only - but that keeps two contracts alive for one behaviour.
- **evidence:** Ran RackApp#call against a real Rack env with a pre-match class middleware plus `Tina4::Middleware.before { counter += 1 }`: "RUBY block BEFORE handler ran 2 time(s) (expected 1)"; control with no pre-match class middleware: "before=1 after=1". Source: tina4-ruby/lib/tina4/middleware.rb:102-114 (unconditional loop), lib/tina4/dispatch_pipeline.rb:208-213 and 475-481 (two run_before calls).

## feature 12 Response types  (1)

### response.file() has four incompatible signatures; the second positional argument means different things in PHP and Python

- **frameworks:** all four; python is the one that silently misreads the PHP/Ruby spelling
- **confidence:** MEASURED
- **same code, different outcome:** Python: `file(file_path, download_name=None, root=None)` - second positional is the DOWNLOAD FILENAME (core/response.py:309). PHP: `file(string $path, ?string $contentType = null, bool $download = false, ?string $root = null)` - second positional is the CONTENT TYPE (Tina4/Response.php:575). Ruby: `file(path, content_type: nil, download: false, root: nil)` - keywords, content_type/download separate (lib/tina4/response.rb:159). Node: `file(path, options?: {download, contentType, root})` - an options bag (packages/core/src/response.ts:296). So `response.file(p, "text/csv")` written against PHP sets Content-Type on PHP and sets the download filename to the literal string "text/csv" on Python - silently, no error. Python additionally has no way at all to set the content type, and no boolean `download`.
- **least-code fix:** Settle on ONE argument order and make Python match it: `file(path, content_type=None, download=False, root=None)` - the shape PHP and Ruby already share. Python's change is a signature line plus setting content_type where it currently derives it, and `download_name` disappears (basename is what the other three send). Node's options bag is idiomatic and can stay as long as the key names are contentType/download/root, which they already are. Do not add a second confined variant - the file()/root design is already agreed.
- **evidence:** tina4-python/tina4_python/core/response.py:309; tina4-php/Tina4/Response.php:575; tina4-ruby/lib/tina4/response.rb:159; tina4-nodejs/packages/core/src/response.ts:296-299 and packages/core/src/types.ts:95.

## feature 9 Graceful shutdown (TINA4_SHUTDOWN_TIMEOUT)  (2)

### Python's production shutdown drops WebSocket 1001 and background-task stop; only the dev server does the full contract

- **frameworks:** tina4-python (Ruby, Node, PHP do the full teardown)
- **confidence:** INFERRED
- **same code, different outcome:** The contract written at the head of tina4-ruby/lib/tina4/shutdown.rb:6-14 (and repeated in tina4-python/tests/test_graceful_shutdown.py:14) is four steps: stop accepting, RFC 6455 1001 to live WebSocket peers, bounded drain, then stop background tasks + close databases + exit 0. Python's BUILT-IN dev server does all four (server.py:3481-3524: server.close(), t.cancel() on every background task, _ws_manager.disconnect_all(CLOSE_GOING_AWAY), _close_bound_databases()). Python's PRODUCTION path does exactly ONE: the ASGI lifespan.shutdown handler at server.py:2538-2543 calls `_close_bound_databases()` and nothing else. Live WebSocket peers get no close frame and Tina4 background tasks are never stopped in production. `stop_all_background_tasks()` exists at server.py:122 and has NO production caller anywhere in tina4_python - only tests and the re-export in __init__.py:88. Ruby hit the identical shape and fixed it: tina4.rb:588-591 wraps `Puma::Launcher.new(config).run` in `ensure Tina4::Shutdown.release_resources`, which does websockets + background + database. Node does all four in one handler (server.ts:1975-2020). PHP does websockets + database in Server::cleanup (Server.php:1744-1772).
- **least-code fix:** Add two calls to the lifespan.shutdown branch beside the existing `_close_bound_databases()`: `stop_all_background_tasks()` and `await _ws_manager.disconnect_all(code=CLOSE_GOING_AWAY, reason='server shutting down')`. 2 lines, both already-written functions.
- **evidence:** tina4-python/tina4_python/core/server.py:2538-2543 (lifespan.shutdown = one call) vs server.py:3487-3524 (dev path = four steps); `grep -rn stop_all_background_tasks tina4-python/tina4_python` returns only the definition at server.py:122 and the re-export at __init__.py:88.

### TINA4_SHUTDOWN_TIMEOUT is a no-op on granian, and the ASGI server is chosen by import probing rather than config

- **frameworks:** tina4-python
- **confidence:** INFERRED
- **same code, different outcome:** tina4-python/tina4_python/core/server.py:2805-2816: when granian is the installed ASGI server, the code logs 'granian has no request-drain deadline, so TINA4_SHUTDOWN_TIMEOUT is NOT honoured on this path' and serves anyway. That is a documented caveat on a knob the framework advertises as identical in all four - by ADR-0024's rule there is no acceptable-divergence tier. Compounding it, the provider is selected implicitly by whichever of uvicorn/hypercorn/granian happens to import first (priority hardcoded at server.py:2782), with only a boolean TINA4_DEFAULT_WEBSERVER to pin the built-in one. Every other pluggable subsystem in Tina4 picks its provider from a URL scheme or a named backend var; this one picks it from the contents of site-packages.
- **least-code fix:** Either drop granian from _find_production_server (the swap it offers is broken, so shipping it costs 10 lines to deliver a caveat), or refuse to boot on granian when TINA4_SHUTDOWN_TIMEOUT is explicitly set. Deleting the branch is the smaller change: -11 lines.
- **evidence:** tina4-python/tina4_python/core/server.py:2805-2816 (granian warning), :2778-2817 (_find_production_server import-probe chain), :3271 (TINA4_DEFAULT_WEBSERVER boolean).

## feature 10 CORS middleware (TINA4_CORS_*)  (2)

### tina4-php never registers CorsMiddleware, so every TINA4_CORS_* variable does nothing

- **frameworks:** tina4-php (Python, Ruby, Node all always-on)
- **confidence:** MEASURED
- **same code, different outcome:** Python registers CORS as two dispatch stages (_stage_cors_preflight in _PRE_MATCH_STAGES, _stage_apply_cors in the response stages - server.py:2039-2042, 2307-2309, 2470). Ruby has cors_preflight in REQUEST_STAGES and apply_cors in ALWAYS_STAGES (dispatch_pipeline.rb:53, 70-73). Node does `middleware.use(cors())` at server.ts:1541. PHP does none of these: Middleware::$globalMiddleware starts empty (Middleware.php:66) and NOTHING in Tina4/ ever calls Middleware::use(CorsMiddleware::class). Every PHP CORS test registers it by hand first (CorsIntegrationTest.php:72, CorsPolicyConformanceTest.php:98, OptionsAllowConformanceTest.php:51), so the PHP 'conformance' suite exercises a pipeline no PHP app has by default. A developer who sets TINA4_CORS_ORIGINS in .env gets working CORS on three frameworks and silence on the fourth.
- **least-code fix:** One line in App::__construct beside registerHealthCheck(): `Middleware::use(\Tina4\Middleware\CorsMiddleware::class);`. CorsMiddleware already declares `$preMatch = true`, so the ordering is already right.
- **evidence:** /tmp/t4probe/php/probe2.php: with TINA4_CORS_ORIGINS='*' and a full `new \Tina4\App()` bootstrap, `Middleware::getGlobal()` and `getPreMatch()` both return [], and three cross-origin GETs return headers ["Content-Type","Set-Cookie"] - no access-control-allow-origin. The same probe against Ruby (/tmp/t4probe/rb/probe.rb) returns access-control-allow-origin: * on every request.

### Python builds the CORS policy at import time, so TINA4_CORS_ORIGINS in .env is silently ignored and every cross-origin request is denied

- **frameworks:** tina4-python (PHP reads per-request via DotEnv; Ruby memoises after Env.load_env; Node constructs inside startServer after loadEnv)
- **confidence:** MEASURED
- **same code, different outcome:** tina4-python/tina4_python/core/server.py:28 does `_cors = CorsMiddleware()` at module scope, and CorsMiddleware.__init__ (middleware.py:299-313) snapshots os.environ. That runs on the app's first `from tina4_python import ...`, before start_server() calls load_env(). Every dispatch stage uses that one frozen `_cors` instance. Same root cause as the health-path defect, and the rate limiter sitting 20 lines away already carries the fix: RateLimiter.configure_from_env() exists precisely because 'the shared limiter is built when the module is imported, but .env is loaded AFTER that' (rate_limiter.py:53-63). CORS never got the same treatment. Worse, the opt-in class hook CorsMiddleware.before_cors (middleware.py:287) constructs a FRESH CorsMiddleware per request and therefore does see .env - so the same config produces two different answers depending on which path is used.
- **least-code fix:** Give CorsMiddleware the same env-snapshot re-read the RateLimiter already has and call it from _stage_cors_preflight/_stage_apply_cors, OR rebuild `_cors` once in start_server() after load_env(). The second is 1 line.
- **evidence:** /tmp/t4probe/py2/probe.py: `.env` with TINA4_CORS_ORIGINS=https://app.example.com -> `cors origins at import: []`, `os.environ CORS after .env: https://app.example.com`, `cors origins after .env: []`. The adjacent rate limiter in the same probe DOES pick the value up (limit 2) because it re-reads.

## feature 11 Rate limiter (TINA4_RATE_LIMIT / TINA4_RATE_WINDOW / TINA4_TRUSTED_PROXIES)  (2)

### Rate limiting is on by default in Node, off by default in Python, and never wired at all in PHP and Ruby

- **frameworks:** all four - Node enforces, Python is gated off, PHP and Ruby never enforce
- **confidence:** MEASURED
- **same code, different outcome:** Node: `middleware.use(rateLimiter())` unconditionally at server.ts:1543, defaulting to 100/60. Python: `_stage_rate_limit` IS in _PRE_MATCH_STAGES (server.py:2160) but `_handle_rate_limit` opens with `rate_enabled = os.environ.get('TINA4_RATE_LIMIT',''); if not rate_enabled: return None` (server.py:1410-1412) - so the documented default of 100 is never applied and the limiter is off until an operator sets the variable. PHP: REQUEST_STAGES/ROUTE_STAGES (Router.php:85-110) contain no rate-limit stage and no code path calls Middleware::use(RateLimiter::class) - the only mentions are doc comments. Ruby: no rate-limit stage in REQUEST_STAGES, ALWAYS_STAGES or ROUTE_STAGES (dispatch_pipeline.rb:51-99), and RateLimiterMiddleware is opt-in. Identical application code plus identical .env yields protection on one framework and none on three.
- **least-code fix:** Delete the `if not rate_enabled: return None` guard in Python (server.py:1410-1412, -3 lines) so the documented 100/60 default applies, and add one Middleware::use / one pipeline stage in PHP and Ruby respectively. Alternative if the intent really is opt-in: remove the always-on `middleware.use(rateLimiter())` from Node and say so in the manifest - but pick one, because right now the contract is unstated.
- **evidence:** TINA4_RATE_LIMIT=2, TINA4_RATE_WINDOW=60, same client IP: Node (/tmp/t4probe/node/probe.ts) 200,200,429,429 with x-ratelimit headers; Python (/tmp/t4probe/py3/probe.py) 200,200,429,429; Ruby (/tmp/t4probe/rb/probe.rb) 200,200,200 with no x-ratelimit headers at all; PHP (/tmp/t4probe/php/probe2.php) 200,200,200 with Middleware::getGlobal() == []. With TINA4_RATE_LIMIT unset, Python served 120 consecutive requests with no headers and no 429 (/tmp/t4probe/py3/probe2.py) while Node emitted x-ratelimit-limit: 100 on request 1.

### Node's always-on limiter covers /__health, so behind an untrusted proxy the liveness probe gets 429 and the pod is restarted

- **frameworks:** tina4-nodejs (default install), tina4-python when TINA4_RATE_LIMIT is set
- **confidence:** MEASURED
- **same code, different outcome:** The health route is registered into the same router the rateLimiter middleware fronts (server.ts:1486 vs 1543); nothing excludes it. Separately, TINA4_TRUSTED_PROXIES defaults to unset, which is correct security policy (ADR-0019) but means that behind an ingress every request resolves to the proxy's socket address - so all clients share ONE bucket of 100/60 for the whole service. Once ordinary traffic exhausts it, the kubelet's httpGet on /__health receives 429, which Kubernetes treats as a failed liveness probe, and the container is restarted - under load, repeatedly. Python has the same exposure but only when an operator opts in; PHP and Ruby cannot hit it because they never limit.
- **least-code fix:** Skip the limiter for the health paths - one early return in the rateLimiter middleware: `if (req.url === healthPath() || req.url === '/health') return next();` (2 lines, and healthPath() is already exported).
- **evidence:** /tmp/t4probe/node/probe.ts requested GET /__health four times with TINA4_RATE_LIMIT=2 and got status 200, 200, 429, 429 - the health endpoint itself returned 429. Same shape measured on Python via TestClient.

## feature 13 ORM base class  (2)

### Node's ORM cannot run a single statement on MySQL - every identifier is double-quoted and nothing rewrites it

- **frameworks:** Node (fatal on MySQL), PHP + Ruby (reserved-word breakage), Python (correct)
- **confidence:** MEASURED
- **same code, different outcome:** baseModel.ts hardcodes ANSI double quotes in 14 SELECT sites plus every UPDATE/INSERT/DELETE (`SELECT * FROM "${ModelClass.tableName}"`). MysqlAdapter.translateSql only runs concatPipesToFunc + ilikeToLike, so the quotes reach the server unchanged. MySQL 8's default sql_mode has no ANSI_QUOTES, so `"users"` is a syntax error. Python solved this correctly with `_get_table_sql()` -> `db.quote_identifier(table)` (dialect-aware); PHP and Ruby interpolate the raw name unquoted, which works on MySQL but breaks the moment a table is named `order` or `user`. One fact - how you spell an identifier in SQL - has four answers, two of them broken in different ways. Node's own adapters/sqlDialect.ts already defines the correct per-engine `quote()` for ANSI/MySQL/MSSQL/Firebird and the ORM does not call it. Same root cause hits Firebird: a lower-case double-quoted name is case-SENSITIVE there and will not match a table created unquoted.
- **least-code fix:** Node already ships the per-engine quoter. Add one private helper on BaseModel - `private static q(db, name) { return dialectFor(db).quote(name); }` - and replace the 19 hardcoded `"` literals with it. That is a net DELETION of string-literal quoting. Do the same for PHP/Ruby by porting Python's existing `_get_table_sql()` (11 lines) rather than inventing anything new. No new abstraction: sqlDialect.ts and quote_identifier already exist and simply are not called from the ORM.
- **evidence:** MEASURED against live MySQL 8 on 127.0.0.1:3306 (root/tina4) via tsx driving the real MysqlAdapter + BaseModel: `all()` -> "error in your SQL syntax ... near '\"db\" LIMIT 2 OFFSET 0'", `where()` -> same, `count()` -> same; the backtick form of the identical query returned rows. sql_mode confirmed as ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,... with no ANSI_QUOTES. Code: /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/orm/src/baseModel.ts:389,501,553,617,664,774,810,818,930,936,1282,1314,1347,1378,1425,1462,1496,1651,1697; adapters/mysql.ts:99-104; adapters/sqlDialect.ts:47-56 (the unused MYSQL_DIALECT). Contrast /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/orm/model.py:307-323.

### tableFilter is enforced in Node, half-enforced in PHP, and does not exist in Python or Ruby

- **frameworks:** Node (6 paths), PHP (count() only, undeclared), Python + Ruby (absent)
- **confidence:** MEASURED
- **same code, different outcome:** Node documents `static tableFilter = "active = 1"` and applies it in six read paths: findById, find, all, where, withTrashed, count. PHP references `$this->tableFilter` in exactly ONE place - count() - and never declares the property on the base class, so it resolves through __get and returns null unless a subclass declares it. A PHP model that does declare it gets `count()` = filtered but `all()`, `find()`, `where()`, `findById()` and `withTrashed()` = every row in the table. Python and Ruby have no such concept at all. A row-level scope (tenant isolation is the obvious use) that is enforced on one framework and silently ignored on another is a data-exposure-shaped divergence, and within PHP alone the pager total and the page contents disagree.
- **least-code fix:** Decide once: either delete it from Node and PHP (removes 8 call sites and a documented property), or add it to the single WHERE-clause builder each framework already has. Do NOT add it to five separate methods per language. PHP's count() at :1013 shows the whole feature is 2 lines when there is one place that assembles conditions - so the smallest honest fix is to extract that one condition-assembly point in each of the four and let tableFilter and softDelete both live there.
- **evidence:** MEASURED via reflection over the installed PHP framework: `Tina4\ORM` declares $tableFilter = NO; source scan of each method body reports tableFilter present in count() only, absent from find/all/where/findById/withTrashed. /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/ORM.php:1013 is the sole application site (also listed in the reflection-exclusion arrays at :1897 and :2386). Node: /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/orm/src/baseModel.ts:101,394,611,658,1341,1372.

## feature 14 Soft delete  (2)

### A NULL is_deleted means 'live' in Python and Ruby and 'deleted' in PHP and Node - 5 of 5 rows vs 0 of 5

- **frameworks:** PHP + Node (NULL = deleted), Python + Ruby (NULL = live)
- **confidence:** MEASURED
- **same code, different outcome:** Python writes `(is_deleted = 0 OR is_deleted IS NULL)` at all 7 read sites and Ruby writes `(field IS NULL OR field = 0)` at all 5. PHP writes bare `is_deleted = 0` at 7 sites and Node writes bare `is_deleted = 0` at 10. The way you actually turn soft delete on for an existing table is `ALTER TABLE t ADD COLUMN is_deleted INTEGER`, which leaves every existing row NULL on SQLite, PostgreSQL, MySQL and Firebird alike. From that identical database state, Python and Ruby return the whole table and PHP and Node return nothing - silently, with no error and no log line. This is the same application code and the same rows producing opposite answers.
- **least-code fix:** One predicate, one place. Each framework already has a point where framework-owned conditions are collected (Node baseModel.ts:607-613, PHP ORM.php:1010-1015). Move the predicate there, spell it `(is_deleted = 0 OR is_deleted IS NULL)` once, and delete the other 6-9 copies. Net LOC goes down in every language and the drift becomes impossible rather than merely fixed.
- **evidence:** MEASURED on identical SQLite fixtures (5 rows, then ALTER TABLE ADD COLUMN is_deleted INTEGER, model with softDelete on): Node `all()` -> 0, `count()` -> 0. Python `all()` -> 5, `count()` -> 5. Sites: PHP /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/ORM.php:762,811,931,974,1011,1196,1348; Node baseModel.ts:392,498,609,656,1369; Python model.py:713,763,838,869,907,921,948; Ruby orm.rb:324,338,408,614,661.

### Soft-deleted children come back through relationships in Python, PHP and Ruby - Node is the only one that filters them

- **frameworks:** Node (filters), Python + PHP + Ruby (do not)
- **confidence:** MEASURED
- **same code, different outcome:** Node appends `AND is_deleted = 0` when the RELATED class has softDelete on, in hasOne, hasMany, belongsTo and both branches of _eagerLoad - 5 sites. Python's has_one/has_many/belongs_to and _eager_load never look at the related class's soft_delete flag; neither do PHP's hasOneMethod/hasManyMethod/eagerLoad nor Ruby's load_has_one/load_has_many/eager_load. So `child.delete()` removes the row from `Child.all()` but the same row is still handed back through `parent.children` on three of the four. A developer who writes the delete on Node and the read on PHP (or vice versa) sees deleted records reappear.
- **least-code fix:** The relationship SQL builders are already one function per relationship type per language. Add the same two lines Node has at baseModel.ts:1426 to Python/PHP/Ruby's relationship query builders - or better, once the previous finding's shared condition-assembly point exists, route the relationship query through it too and get this for free with zero added lines.
- **evidence:** MEASURED in Python on SQLite: Pchild declared `soft_delete = True` with one of five children per parent carrying is_deleted=1; the lazy `parent.pchildren` returned 5 records including the is_deleted=1 row, and the eager `include=["pchildren"]` path returned all 300 of 300 rows including the 60 soft-deleted ones. Code: Node baseModel.ts:1426,1463,1497,1652,1698 (present) vs Python model.py:1220-1250 and 1291,1332 (absent), PHP ORM.php:2612,2673,2700-2740 (absent), Ruby orm.rb:271,304,1216,1234 (absent).

## feature 15 Relationships + eager load  (1)

### Ruby's eager load and lazy has_many inherit db.fetch's default LIMIT 100 - 40 of 60 parents came back with an empty children array

- **frameworks:** Ruby (silently truncates), Node (unbounded), Python + PHP (n*1000)
- **confidence:** MEASURED
- **same code, different outcome:** Ruby's `eager_load` calls `klass.db.fetch(sql, pk_values)` with no limit, and `load_has_many` calls `klass.db.fetch(sql, [pk_value])` with no limit. Ruby's `Database#fetch` defaults to `limit: 100`. So an eager load across 60 parents holding 300 children returns the first 100 rows and every parent past the cut-off gets `[]` - not an error, not a warning, an empty collection that looks exactly like 'this parent has no children'. Ruby's own row-cap spec states the rule this breaks, in its own words: 'a path with NO limit parameter must never cap, because there the cap can only ever be silent'. Neither of these two paths has a limit parameter.
- **least-code fix:** Three call sites, one word each: pass `limit: nil` on the two eager-load fetches and the one lazy has_many fetch, exactly as `fetch_all` already does. Zero new code, and it brings Ruby in line with the rule its own spec file states.
- **evidence:** MEASURED on SQLite: 60 parents x 5 children = 300 rows in the table; `Eparent.all(limit: 60, include: [:echildren])` returned 60 parents but only 100 children in total, with counts [5,5,5,5,5] at the front and [0,0,0,0,0] at the back - 40 parents with ZERO children. The lazy path on a parent with 150 children returned 100. Code: /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/orm.rb:271, 304, 1234; /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/database.rb:461. Rule quoted from /Users/andrevanzuydam/IdeaProjects/tina4-ruby/spec/orm_row_cap_spec.rb:21-33.

## feature 16 Scopes  (1)

### PHP scopes live in one static array on the abstract base - Order::activeOnly() runs User's filter against the orders table

- **frameworks:** PHP (shared), Python + Ruby + Node (per-model)
- **confidence:** MEASURED
- **same code, different outcome:** `ORM::scope()` writes to `static::$_scopes[$name]`, and `$_scopes` is declared `protected static array $_scopes = []` on the abstract ORM base. PHP shares a parent's static property with every subclass that does not redeclare it, so all models share one scope namespace. Registering `activeOnly` on User makes `Order::activeOnly()` resolve instead of throwing BadMethodCallException, and `__callStatic` then runs `(new Order())->where('active = ?', [1])` - User's WHERE clause against the orders table. Two models that happen to pick the same scope name silently overwrite each other. Python sets the method on the class via setattr, Node assigns an own static property, Ruby uses define_singleton_method - all three are per-model.
- **least-code fix:** One line: key the registry by class - `static::$_scopes[static::class][$name] = ...` and read it back the same way in __callStatic. Two edits, no new structure.
- **evidence:** MEASURED against the installed framework: after `(new Usr())->scope('activeOnly', 'active = ?', [1])`, reflection on `Tina4\ORM::$_scopes` showed `{"activeOnly":{"filter":"active = ?","params":[1]}}` on the BASE class, and `Ordr::activeOnly()` did not throw BadMethodCallException - it resolved and reached the DB layer. /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/ORM.php:1528-1536 (scope + the shared static), :1539-1552 (__callStatic).

## feature 18 Paginated results  (1)

### Node's ORM writes LIMIT/OFFSET into the SQL string, bypassing the engine-aware pagination the other three get for free

- **frameworks:** Node (breaks on MSSQL), Python + PHP + Ruby (adapter-translated)
- **confidence:** MEASURED
- **same code, different outcome:** Node's `all()`, `where()`, `hasOne()`, `hasMany()` and `belongsTo()` append `LIMIT ${limit} OFFSET ${offset}` to the SQL and call `adapterQuery`. Python, PHP and Ruby all pass limit/offset as ARGUMENTS to `db.fetch(sql, params, limit, offset)`, and each adapter then emits the correct dialect - PHP's PdoAdapterTrait::paginate, Python's mssql.py OFFSET...FETCH NEXT, Firebird's ROWS. Node's MssqlAdapter only calls SQLTranslator.limitToTop, whose own docblock says it 'Does NOT convert if OFFSET is present' - and the ORM always emits OFFSET. So every paged ORM read on Node emits invalid T-SQL on MSSQL. This is the same root defect as the identifier quoting: the ORM builds finished SQL instead of handing the intent to the adapter that knows the engine.
- **least-code fix:** Replace `adapterQuery(db, sqlWithLimit, params)` with `adapterFetch(db, sql, params, limit, offset)` at those five sites. `adapterFetch` already exists in database.ts:41 and already forwards limit/skip to the adapter. This DELETES the string concatenation and gets MSSQL and Firebird correct as a side effect.
- **evidence:** The emitted shape was MEASURED end-to-end against live MySQL - the failing statements were literally `SELECT * FROM "db" LIMIT 2 OFFSET 0` and `SELECT * FROM "db" WHERE (1=1) LIMIT 2 OFFSET 0`. Code: /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/orm/src/baseModel.ts:617-618, 664, 1431, 1467, 1502; adapters/mssql.ts:127-132; sqlTranslator.ts:54-56 (the refusal-to-translate comment).

## feature 19 Result/ORM caching  (2)

### A write invalidates Model.cached() in Python only - Ruby, PHP and Node serve stale rows for the full TTL

- **frameworks:** Python (invalidates on save only), PHP + Ruby + Node (never invalidate)
- **confidence:** MEASURED
- **same code, different outcome:** Python's save() calls `self.clear_cache()` before returning. PHP's, Ruby's and Node's save() do not touch their query cache at all, and no delete()/force_delete()/restore() in ANY of the four clears it - so Python disagrees with itself as well. The sequence `Model.cached(sql, ttl=60)` -> `model.save()` -> `Model.cached(sql)` returns fresh rows on Python and pre-write rows for up to 60 seconds on the other three. The DB-level cache (CachedDatabaseAdapter / Database._cache_invalidate) DOES flush on write, so the two caching layers in the same framework have opposite invalidation semantics.
- **least-code fix:** One line in each of the other three save() bodies, mirroring model.py:597, plus the same line in all four delete() bodies. Five added lines total. Do NOT build a dependency-tracking invalidator - the tag/model-scoped clear already exists in three of the four.
- **evidence:** MEASURED in Ruby on SQLite: first `Witem.cached(sql, [], ttl: 60)` -> ["a"]; then `w.save` inserting "b"; `db.fetch_all(sql).length` -> 2 rows really present; second `Witem.cached(sql, [], ttl: 60)` -> still ["a"]. Python's invalidation at /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/orm/model.py:597. Absent from PHP ORM.php:573-650, Ruby orm.rb:790-942, Node baseModel.ts:694-905. No delete() path in any of the four clears it (model.py:602-676, ORM.php:840, orm.rb:944, baseModel.ts:915).

### Model.cached() ignores the cache provider completely - TINA4_CACHE_BACKEND=redis buys nothing for ORM reads

- **frameworks:** all four
- **confidence:** INFERRED
- **same code, different outcome:** All four back Model.cached() with a process-local store: Python a module-level `Cache` (model.py:18), Ruby an ORM-anchored QueryCache (orm.rb:368), Node a per-model-class QueryCache (baseModel.ts:1201), PHP a private static array in SQLTranslator. None of them consults TINA4_CACHE_BACKEND or TINA4_DB_CACHE_BACKEND. The persistent DB cache DOES route through the pluggable backend and CLAUDE.md advertises that 'multiple instances share one cache with global write-invalidation' - that sentence is simply false for Model.cached(). Behind a load balancer with four workers you get four divergent caches and `Model.clearCache()` clears exactly one of them.
- **least-code fix:** Do not port a backend into the ORM cache - that is four new integrations. The smaller correct move is to narrow the contract: make Model.cached() delegate to the DB layer's already-backend-aware fetch (pass a ttl through db.fetch) and DELETE the four separate ORM cache stores. That removes ~120 lines across the four and makes the provider swap apply automatically. If delegation is rejected, then the docs must stop claiming cross-instance sharing for ORM reads.
- **evidence:** /Users/andrevanzuydam/IdeaProjects/tina4-python/tina4_python/orm/model.py:18,1145-1160; /Users/andrevanzuydam/IdeaProjects/tina4-ruby/lib/tina4/orm.rb:368-401; /Users/andrevanzuydam/IdeaProjects/tina4-nodejs/packages/orm/src/baseModel.ts:1191-1227; /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/ORM.php:2047-2071 -> SQLTranslator.php:17. The backend-aware path that ORM does not use: tina4-python/tina4_python/database/connection.py:244-253; tina4-nodejs/packages/orm/src/cachedDatabase.ts:127,143-163.

## feature 20 Input validation  (1)

### PHP's ORM::validate() is `return [];` - the enforcement gate is present and the rule set is empty

- **frameworks:** PHP (no-op), Python + Node (enforce), Ruby (null-only)
- **confidence:** MEASURED
- **same code, different outcome:** All four call validate() first in save(), record the joined errors on lastError, log, and return false without touching the driver - the gate is identical and duplicated four times. PHP's validate() body is `return [];`, unconditionally. So the gate can never fire, and PHP has no way to declare a constraint in the first place because its models use typed public properties rather than field objects. A model that Python and Node refuse to save (max_length, required, pattern, range) is written straight to the driver on PHP, where it either truncates, violates a DB constraint, or succeeds with bad data depending on the engine.
- **least-code fix:** The smallest honest fix is to narrow the contract rather than build a PHP validation engine. PHP already ships Tina4\Validator; wire ORM::validate() to it over an optional per-model rules array, so a model that declares nothing behaves exactly as today and a model that declares rules is enforced. If that is rejected, the docs and CHANGELOG must stop describing validate() as an enforced gate in PHP - shipping an empty gate is worse than shipping none.
- **evidence:** MEASURED: PHP `$s->validate()` on a model holding a 500-character value returned `[]`. Python MEASURED on the same shape: `save()` -> False with 'Field \'name\': maximum length is 5, got 29'. Node MEASURED: `save()` -> false with 'name must be at most 5 characters'. Code: /Users/andrevanzuydam/IdeaProjects/tina4-php/Tina4/ORM.php:1502-1505; the gate that calls it at :578-587. Python model.py:1363-1373 and the gate at :440-448. Node baseModel.ts:1065-1074 and the gate at :700.
