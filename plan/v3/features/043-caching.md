# Feature 43: cache backends, + 39 template caching, + 40 fragment caching

Audited 2026-08-01. Part of `98-feature-audit.md`.

Measured on macOS 26.5.2 (Darwin 25.5.0, arm64) with Python 3.14.5, PHP 8.5.7,
Ruby 4.0.2, Node 24.9.0, against live Redis 6379, Valkey 6380, memcached 11211,
MongoDB 27017 and PostgreSQL 5432/55432.

## Files

| | KV + backends | response cache | fragment cache |
| --- | --- | --- | --- |
| python | `tina4-python/tina4_python/cache/__init__.py` | same file (`ResponseCache`) | `tina4_python/frond/engine.py` (`_handle_cache`) |
| php | `tina4-php/Tina4/Cache/` + `CacheFactory.php` | `Tina4/Middleware/ResponseCache.php` | `Tina4/Frond.php` (`renderCache`) |
| ruby | `tina4-ruby/lib/tina4/cache_backends.rb` + `cache_backends/` | `lib/tina4/response_cache.rb` | `lib/tina4/frond.rb` (`handle_cache`) |
| node | `tina4-nodejs/packages/core/src/cache.ts` | same file (`responseCache`) | `packages/frond/src/engine.ts` (`handleCache`) |

`tina4-ruby/lib/tina4/cache.rb` is NOT a backend: it is `QueryCache`, the
in-memory tagged TTL cache used by the DB query layer. The unified backend
family lives in `cache_backends.rb`.

## Method

Every claim below was measured from the live source and then confirmed by
running it. The response-cache findings were driven end-to-end through each
framework's REAL dispatcher (`TestClient` in all four), not through stubs,
because the decisive defects were invisible to the existing stub-based tests.

## What differed, before the fix

| Aspect | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| Response cache key | `GET:{url}` + sorted params | `GET:{url}` | `GET:{url}` | `response:GET:{url}` |
| Any request header in the key | no | no | no | no |
| `Vary` honoured | no | no | no | no |
| `Authorization` respected | no | no | no | no |
| Middleware works on a real route | NO (500) | class form NO, string spec yes | NO (no short-circuit) | yes |
| Authenticated user B gets user A's body | n/a | YES | no | YES |
| Anonymous gets an authenticated body | no | no | no | YES |
| `Set-Cookie` replayed to another caller | no | no | no | no |
| Responses stored in the configured backend | NO | yes | yes | yes |
| Cross-process response sharing on redis | NO | yes | yes | yes |
| `X-Cache-TTL` on a HIT | remaining | configured | remaining | configured |
| Unknown backend name | silent memory | silent memory | silent memory | silent memory |
| Unreachable backend | file | file | file | file |
| `backend.sweep()` exists | no | yes | file only | no |
| `cache_stats()` keys | 4 | 5 (`keys`) | 5 (`keys`) | 4 |
| KV `cache_set(k, v, 0)` | no expiry | default TTL | default TTL | no expiry |
| KV key namespace | raw | `direct:` prefix | `direct:` prefix | raw |
| `{% cache "k" %}` default TTL | 60 | **0** | 60 | 60 |
| `{% cache "k" 0 %}` | not cached | **cached forever** | not cached | not cached |
| `clear_cache()` clears fragments | no | no | no | no |

## FINDING 1 (SECURITY): the key ignores every request header

The key is method plus URL in all four. Nothing about the caller enters it. On a
route that is `@secured()` / `->secure()` / `.secure()`, that means the first
caller's response body is replayed to every later caller of the same URL.

Reproduced end-to-end on a real secured GET route whose body is derived from the
caller's JWT. PHP, before the fix:

```
A_alice.status=200 body={"secret_for":"alice","balance":"alice-PRIVATE-DATA"} x_cache=MISS
B_bob.status=200   body={"secret_for":"alice","balance":"alice-PRIVATE-DATA"} x_cache=HIT
C_anon.status=401  D_bad.status=401
me.invocations=1
```

Node, before the fix, is worse, because its route middleware runs BEFORE the
auth gate, so a cache hit returns without the gate ever running:

```
A_alice.status=200 body={"secret_for":"alice",...} x_cache=MISS
B_bob.status=200   body={"secret_for":"alice",...} x_cache=HIT
C_anon.status=200  body={"secret_for":"alice",...} x_cache=HIT
D_bad.status=200   body={"secret_for":"alice",...} x_cache=HIT
```

Control, same Node route with the cache removed: `anon=401`, `authed=200`. The
gate works; the cache is what defeats it. So PHP is an authorization bypass and
Node is an authentication bypass.

Clean negative: no framework replays `Set-Cookie` or any other response header.
Only body, content type and status code are stored, so one caller's session
cookie is never handed to another. Each response carries its own fresh cookie.

### Authority

RFC 9111 is directly on point and normative, so per ADR-0012's order of
authority it settles this above any framework comparison.

Section 3, constraints on storing:

> if the cache is shared: the Authorization header field is not present in the
> request (see Section 11.6.2 of [HTTP]) or a response directive is present that
> explicitly allows shared caching (see Section 3.5)

Section 3.5, Storing Responses to Authenticated Requests:

> A shared cache MUST NOT use a cached response to a request with an
> Authorization header field (Section 11.6.2 of [HTTP]) to satisfy any
> subsequent request unless the response contains a Cache-Control field with a
> response directive (Section 5.2.2) that allows it to be stored by a shared
> cache, and the cache conforms to the requirements of that directive for that
> response.

Section 4.1, Calculating Cache Keys with the Vary Header Field:

> the cache MUST NOT use that stored response without revalidation unless all
> the presented request header fields nominated by that Vary field value match
> those fields in the original request

and

> A stored response with a Vary header field value containing a member "*"
> always fails to match.

These are MUST NOTs, not SHOULDs. Tina4's ResponseCache is a shared cache by
construction: one server-side store, every caller. The mainstream tier agrees
with the standard here, which is the easiest case ADR-0012 admits: Varnish
refuses to cache a request carrying Authorization unless the response is
explicitly public, nginx's `proxy_cache` does the same, and Rails' `Rack::Cache`
follows RFC 9111 for both rules.

### Fix

One store-side rule closes both bypasses, because a response that is never
stored can never be replayed:

- On store, if the request carried `Authorization`, refuse unless the response
  carries `public`, `s-maxage` or `must-revalidate` (section 3.5's own list).
- On store, record the response's `Vary` fields and the values they had on this
  request. On lookup, every nominated field must match; absent matches only
  absent. `Vary: *` is never stored.

No lookup-side Authorization rule is needed. Section 3.5 constrains reuse of a
response stored FOR an authorized request; if section 3 stops it being stored,
3.5 is satisfied. Serving a genuinely public cached response to a caller who
happens to hold a token stays correct.

The Node ordering problem is NOT fixed here. It belongs to feature 6 and
ADR-0019, and is filed there with this repro. Rule 1 closes the exploit on its
own, so the ordering fix can be sequenced separately.

## FINDING 2: the response cache did not work at all in two of four

The existing suites were green throughout, because all four drove stubs.

**Python.** `before_cache` did `request._cache_key = cache_key`. The framework
`Request` uses `__slots__`, so that raised `AttributeError: 'Request' object has
no attribute '_cache_key' and no __dict__ for setting new attributes`, and every
`@middleware(ResponseCache)` request became a 500. The cache suite passed because
it drove a `MockRequest` class with a plain `__dict__`. That stub is deleted; the
tests now build a real `Request` and `Response`.

**Ruby.** `before_cache` returned the `[request, response]` pair on a HIT. Per
Ruby's own middleware contract that only REBINDS and continues, so the handler
ran on every request while `X-Cache: HIT` was stamped anyway:

```
r1 body={"n":1} x_cache=MISS
r2 body={"n":2} x_cache=HIT      <- fresh body, header lying
handler_invocations=2
```

Python turned out to have the identical defect once the `__slots__` crash was
cleared: `Middleware.apply_hook_result` short-circuits on a returned `Response`
OBJECT, never on the pair. PHP's class-form hook path is the same shape.

**PHP, class form.** `->middleware([ResponseCache::class])`, the spelling the PHP
docs show, was a SILENT no-op. `Middleware::discoverMethods()` only collects
PUBLIC STATIC methods, and `beforeCache`/`afterCache` are instance methods, so no
hook was ever discovered. No warning, no header, no caching.

**Ruby, class form.** `middleware: [Tina4::ResponseCache]` had the same shape:
`discover_methods` walks `klass.singleton_class` and calls `klass.send(...)`, so
it finds class methods only.

Both now expose static/class-level `beforeResponseCache` / `after_response_cache`
delegating to the module singleton.

**`@cached(max_age=N)` was inert in Python.** It stamped `_cached` and
`_cache_max_age` on the handler and nothing in the framework read either. It is
now read off `request._handler`, which the dispatcher already attaches.

## FINDING 3: Python built the backend and never used it

`ResponseCache.__init__` called `_create_backend()` and stored the result, then
the request path wrote responses into a private per-instance `OrderedDict`. With
`TINA4_CACHE_BACKEND=redis` the stats reported `redis` while nothing was shared.
Measured before the fix:

```
PROC A: backend_reported=redis  same_instance_hit="PROC-A-RESPONSE-BODY"
        second_instance_same_process_hit=""
PROC B: backend_reported=redis  second_process_response_hit=""
                                second_process_kv_hit="KV-FROM-PROC-A"
```

The last line is the control: the KV surface DOES cross the process boundary, so
Redis was working. Only the response cache ignored it. PHP, Ruby and Node all
returned the stored body for both reads. Python was the 1-of-4 outlier, so
"Python is master" does not apply; the governance rule is that a broken Python
gets fixed, not mirrored. Responses now route through the backend, memoised at
module level so a dispatcher that builds a fresh middleware instance per request
still reads one store.

## FINDING 4: `{% cache %}` disagreed with itself across frameworks

PHP parsed a missing TTL as 0 and then treated 0 as "cache forever". Python,
Ruby and Node default a missing TTL to 60 and treat `now + 0` as already
expired, so 0 means NOT cached. Both ends of the contract were inverted:

- `{% cache "k" %}` never re-rendered for the life of a PHP process.
- `{% cache "k" 0 %}` meant "never cache" in three frameworks and "cache
  forever" in PHP.

Three of four agree and the disagreement is internal, so the majority answer
stands and PHP moved. This is a breaking change for PHP templates relying on
`0`.

## FINDING 5: a typo in `TINA4_CACHE_BACKEND` silently gave you a memory cache

All four fell through to the memory backend on an unrecognised name.
`TINA4_CACHE_BACKEND=redsi` produced a running app with a per-process cache
while the operator believed it was Redis. This is exactly the footgun the
session layer already fixed: `TINA4_SESSION_BACKEND` raises on an unknown name,
naming the bad value and the valid set. Internal precedent is settled and
consistent, so the cache now matches it in all four.

## FINDING 6: the persistent DB query cache crashed every `fetch_one` in Python

`fetch()` yields a `DatabaseResult`; `fetch_one()` yields a plain dict or None.
Python's persistent serializer read `result.records` unconditionally, so the
moment `TINA4_DB_CACHE=true` was set, every `fetch_one()` raised:

```
File "tina4_python/database/connection.py", line 260, in _serialize_result
    "records": result.records, "count": result.count,
AttributeError: 'dict' object has no attribute 'records'
```

The opt-in persistent cache was therefore unusable with `fetch_one`. PHP, Ruby
and Node all already carried a shape marker in the cached envelope; Python was
the 1-of-4 outlier again. Fixed with an explicit `_shape` field, and the
cross-process write-invalidation path then verified end-to-end against live
PostgreSQL and live Redis:

```
PROC A read  -> ORIGINAL   (populates the shared redis cache)
PROC B read  -> ORIGINAL   (fresh process, cross-process hit)
PROC C WRITE -> mutated
PROC D read  -> MUTATED    (invalidation crossed the process boundary)
```

## FINDING 7 (OPEN, not fixed): `clear()` is a no-op on the raw RESP path

`RedisBackend.clear()` deletes the namespace only when the native client
library is present. On the zero-dependency raw RESP path it does nothing:

- python: `elif self._use_raw:` ... `pass` ("let TTL handle cleanup")
- php: `// Raw RESP path: no easy pattern delete - let TTL handle cleanup`
- ruby: `elsif @use_raw` ... `# rely on TTL`
- node: implements it, `KEYS prefix*` then `DEL`

Three of four therefore never invalidate. Since the raw path is what a
zero-dependency install uses, this is the DEFAULT configuration, not an edge
case. Measured in PHP, with `TINA4_DB_CACHE=true`, redis backend, no ext-redis:

```
A read  -> ORIGINAL
B read  -> ORIGINAL   (fresh process, shared cache working)
C mutate
D read  -> ORIGINAL   <- STALE. the write never invalidated anything
```

So the persistent DB cache's headline property, "multiple instances share one
cache with global write-invalidation", does not hold on the default driver
path in Python, PHP or Ruby. `cache_clear()` and the response cache's
`clear_cache()` are equally inert there.

Not fixed here, deliberately. Node's implementation is the obvious template,
but `KEYS` is a blocking O(N) command that is explicitly discouraged against a
production Redis, so copying it into three more frameworks is a decision about
the invalidation strategy (`SCAN` with a cursor, a generation counter in the
key prefix, or per-key tracking) rather than a typo fix. It needs its own ADR
and its own cross-framework tests. Recorded with the repro instead of rushed.

## Confirmed correct, no change needed

**The documented graceful fallback is real in all four.** Pointed at a genuinely
unreachable endpoint (a port bound then closed, so `connect` gets ECONNREFUSED)
for redis, valkey, memcached, mongodb and database, every framework logged the
warning, reported `file`, and round-tripped a real value through the file
backend. Wrong Redis credentials against the live server on 6379 also fell back
to `file` in all four, so the probe is a genuine AUTH handshake and not just a
TCP connect.

**Async vs sync is genuine runtime necessity, not drift.** Node's KV API and
middleware are async because its backend clients are; Python, PHP and Ruby are
synchronous for the same reason. The observable contract is identical. The
divergences found were behavioural (above), not a consequence of the async split.

## Still open, not fixed here

- **Node route middleware runs before the auth gate.** Filed to feature 6 /
  ADR-0019 with the repro. Rule 1 closes the exploit; the ordering is a
  separate, wider decision.
- **`X-Cache-TTL` on a HIT** is remaining seconds in Python and Ruby, the
  configured TTL in PHP and Node. Cosmetic, unresolved, low priority.
- **KV key namespacing differs**: Python and Node write the raw key, PHP and
  Ruby prefix `direct:`. Two frameworks sharing one Redis cannot read each
  other's `cache_set` values. No caller depends on cross-framework KV sharing
  today, so this is recorded rather than changed.
- **`cache_set(key, value, 0)`** means "no expiry" in Python and Node, "use the
  default TTL" in PHP and Ruby. A 2-2 split with no standard to appeal to.
- **`Frond.clear_cache()` does not clear the fragment cache** in any of the
  four, so a fragment can only be invalidated by TTL expiry. Consistent across
  all four, so it is a design question rather than drift.
- **`backend.sweep()`** exists on PHP's backends and now on Python's memory and
  file backends; Ruby has it on the file backend only and Node has none.

## Tests

Named identically in all four so the gate is greppable across the stack:

| test | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| `response_cache_does_not_store_a_response_to_an_authorized_request` | yes | yes | yes | yes |
| `response_cache_stores_an_authorized_response_when_cache_control_public` | yes | yes | yes | yes |
| `response_cache_serves_an_unauthenticated_get` | yes | yes | yes | yes |
| `response_cache_honours_vary_on_a_nominated_request_header` | yes | yes | yes | yes |
| `response_cache_never_stores_vary_asterisk` | yes | yes | yes | yes |
| `cache_backend_unknown_name_raises` | yes | yes | yes | yes |
| `cache_backend_known_names_do_not_raise` | yes | yes | yes | yes |
| `db_cache_persistent_fetch_one_round_trips` | yes | - | - | - |
| `frond_fragment_cache_defaults_to_sixty_seconds_without_ttl` | - | yes | - | - |
| `frond_fragment_cache_ttl_zero_is_not_cached` | - | yes | - | - |

The fragment-cache pair is PHP-only because PHP is the only framework whose
behaviour changed; the other three already had the correct semantics.

`response_cache_serves_an_unauthenticated_get` is the negative control. Without
it, a "fix" that simply disabled caching everywhere would satisfy every
bypass assertion.

## Suite results

At the commit this ships:

| | before | after | notes |
| --- | --- | --- | --- |
| python | 100 passed | 109 passed | `test_cache`, `test_cache_backends`, `test_db_query_cache` |
| php | 242 tests, 2234 assertions | 251 tests, 2257 assertions | 9 cache test files |
| ruby | 144 examples, 1 pending | 152 examples, 1 pending | pending is the mongo gem, absent before and after |
| node | 259 passed | 270 passed | 6 cache test files, 0 skipped, typecheck green |

Every gate was proven able to fail: each named test was watched going red
against a surgical revert of exactly the line it guards, with the right message,
and the rest of the suite staying green.
