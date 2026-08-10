# Feature 072: Cache interface and provider selection

## Identity and status

- Matrix identity: 72 - Cache interface and provider selection
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the cache backend interface, the provider
  factory, and the graceful-fallback path in each repo) at Python `386cd6d`, PHP `743b7469`, Ruby
  `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: the seven cache providers (Features 73-79), the Database/ORM query-cache layer, the
  logger
- Dependants: the HTTP response cache (Feature 80), the persistent DB query cache, the module KV
  helpers (`cache_get`/`cache_set`/...)
- Existing ADRs: ADR-0024 (a provider is an env var; an explicit provider is honoured), ADR-0030 (a
  cache key names the database it came from), ADR-0031 (memcached invalidates by namespace generation,
  redis by SCAN), ADR-0032 (sweep returns evicted; a server-expiring provider returns 0), ADR-0020
  (the response cache, Feature 80)
- Shared fixtures: `cache_contract.json` (ADR-0024) PROVES all 8 interface invariants in all four -
  8/8 proven per CONTRACT-MAP. This packet records the (well-built) contract and the few remaining
  divergences.
- Catalog phase: Cache

## Why this feature exists

An application needs one cache surface with a pluggable backend, chosen by a single env var, that
behaves identically whichever backend is active - so switching from the in-memory default to Redis is
a config change, not a code change, and a `clear()` really clears, a cached `null` comes back as
`null`, and two databases sharing one backend never serve each other's rows.

## Boundary

This feature owns the cache backend INTERFACE (`get`/`set`/`delete`/`clear`/`stats`/`name`/`sweep`/
`available?`), the provider FACTORY (selection from `TINA4_CACHE_BACKEND`, the unknown-name error, the
graceful fallback to file), and the three cache MODES and their selector env vars. It DELEGATES the
per-backend wire behaviour to Features 73-79 and the response-cache middleware to Feature 80. The
in-process `QueryCache`/`Cache` facade class (which carries `has`/`remember`) is a SEPARATE surface,
not the pluggable backend.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Backend interface | get/set/delete/clear/stats/name/sweep/is_available | same | same (`available?`) | same (`isAvailable`) |
| `has`/`remember` on the backend | no (on a separate class) | no | no | no |
| Unknown backend name | RAISES | RAISES | RAISES | THROWS |
| Explicit provider beats env (ADR-0024) | yes (locked) | yes | yes | yes |
| Graceful fallback to file (real probe) | yes | yes | yes | yes |
| `clear()` invalidates every provider | yes (locked) | yes | yes | yes |
| `sweep()` returns count; server-expiring = 0 (ADR-0032) | yes (locked) | yes | yes | yes |
| TTL in seconds; memcached convert-not-clamp | yes (locked) | yes | yes | yes |
| Cached null round-trips (envelope) | yes (locked) | yes | yes | yes |
| Key carries database identity (ADR-0030) | yes (locked) | yes | yes | yes |
| Persistent-layer clear | yes (locked) | yes | yes | yes |
| Namespace invalidation (memcached gen / redis SCAN, ADR-0031) | yes | yes | yes | yes |
| `TINA4_DB_CACHE_BACKEND` typo | SWALLOWED (silent degrade) | raises (via factory) | raises (via factory) | throws (via factory) |

Eleven of twelve rows are at full parity and PROVEN (`cache_contract.json`, 8/8, mutation-tested,
locked by named per-invariant tests in each framework). This is a reference-quality subsystem. The one
behavioural outlier is Python's swallowed DB-cache-backend typo.

## Public surface contract

The backend interface is `get(key) -> value | miss`, `set(key, value, ttl_seconds)`,
`delete(key) -> bool`, `clear()`, `stats() -> {hits, misses, size, backend}`, `name()`, `sweep() ->
evicted_count`, `available?() -> bool`. `has`/`remember`/`exists` are NOT on this interface in any
framework - they live on a separate in-process facade class. The provider is selected by
`TINA4_CACHE_BACKEND` (one of memory/file/redis/valkey/memcached/mongodb/database, aliases
memcache/mongo/db); an unknown name raises (never a silent fall-through to memory); an explicitly
passed backend beats the env (ADR-0024).

## Inputs and outputs

- `set(key, value, ttl)`: `ttl` is SECONDS (`<=0` = no expiry) on every provider; the backend converts
  to its wire unit (Redis `SETEX` seconds, memcached exptime with the 30-day convert-not-clamp).
- `get(key)`: returns the stored value, and a stored `null`/`None`/`nil` comes back as that value (a
  HIT), not the storage envelope and not a miss - the miss decision is key-presence, never
  value-truthiness.
- `sweep()`: evicts expired entries and returns the count; a server-expiring provider (redis, valkey,
  memcached, mongodb) honestly returns 0.
- provider selection: `TINA4_CACHE_BACKEND` (response/KV), `TINA4_DB_CACHE_BACKEND` (persistent DB
  cache); an explicit argument wins.

## Lifecycle and operation graph

1. SELECT: the factory reads `TINA4_CACHE_BACKEND` (or the explicit arg), normalises it, and switches
   to the provider; an unknown name RAISES.
2. PROBE: for a networked backend the factory calls `available?()` - a real handshake (Redis
   AUTH+PING, memcached `version`, mongo `ping`, database `CREATE TABLE`) - and on failure logs a
   warning and returns a real FILE backend, never a no-op. Wrong credentials also fall back.
3. OPERATE: `get`/`set`/`delete` run against the selected backend; `clear()` invalidates every entry
   (SCAN+DEL, generation bump, or DELETE, never FLUSHALL); `sweep()` reclaims expired entries.
4. INVALIDATE: a write invalidates the query cache across every instance sharing the backend; the
   key carries the database identity so tenants never collide.

## Configuration and precedence

Env vars (uniform): `TINA4_CACHE_BACKEND` (default memory), `TINA4_CACHE_URL` (per-backend default),
`TINA4_CACHE_MAX_ENTRIES` (1000), `TINA4_CACHE_DIR` (`data/cache`), `TINA4_CACHE_TTL` (60, response
cache only), `TINA4_CACHE_USERNAME`/`_PASSWORD`. The three modes select their backend independently:
request-scoped auto-cache (`TINA4_AUTO_CACHING`, in-process, no backend), persistent DB cache
(`TINA4_DB_CACHE` + `TINA4_DB_CACHE_BACKEND`), response/KV cache (`TINA4_CACHE_BACKEND`). An explicit
argument beats the env (ADR-0024). PHP reads some cache env via raw `getenv` and some via
`DotEnv::getEnv` - an internal inconsistency (CI-03).

## Failures, side effects and security

- UNKNOWN NAME RAISES (all four): a typo in `TINA4_CACHE_BACKEND` names the bad value and the valid
  set, rather than silently running on the memory backend while the operator believes it is on Redis.
- GRACEFUL FALLBACK is loud and real (proven, all four): a missing driver or unreachable/mis-
  credentialled service logs a warning and degrades to a persistent FILE backend, never a silent
  no-op. The probe is a real handshake, so wrong credentials also fall back.
- SWALLOWED DB-CACHE TYPO (CI-01): Python's persistent DB-cache call site wraps the factory in
  `except Exception: self._cache_backend = None` (`connection.py:278`), so a typo'd
  `TINA4_DB_CACHE_BACKEND` silently degrades to the in-process dict - the OPPOSITE of the raise the
  response-cache selector performs, and of the other three, which route the persistent cache through
  the same raising factory. An operator's typo runs silently on Python's DB cache.
- MID-LIFE DEGRADATION IS SILENT (CI-02, shared): the visible-fallback guarantee is SELECTION-TIME
  only. A backend that dies AFTER selection yields silent misses and silent `set` no-ops, with no
  warning and no re-fallback, in all four. The invariant "an-unreachable-backend-degrades-visibly"
  holds at startup but not at runtime.
- CACHE-OF-THE-CACHE is avoided: the database backend forces `TINA4_AUTO_CACHING`/`TINA4_DB_CACHE`
  off around its own connection so the cache's own reads do not recurse into caching.

## Wire and persistence contract

Each backend has its own wire/persistence (Features 73-79); the INTERFACE contract is: a value set with
a TTL is gone after the TTL; a `clear()` removes every entry the cache can serve; a cached null
round-trips; the query-cache key is `sha256(engine://host:port/database NUL sql NUL params)` with
credentials deliberately excluded so a shared backend's entries are reused across instances (ADR-0030).

## Providers and substitutability

The whole point (ADR-0024): a provider is one env var. The seven providers (Features 73-79) implement
the same interface; the factory selects one and falls back to file when it is unreachable. An explicit
argument overrides the env. The response cache (Feature 80) and the persistent DB cache both consume
this interface, isolated only by which env var names their backend.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| CI-01 | Python swallows a `TINA4_DB_CACHE_BACKEND` typo (`connection.py:278` `except Exception -> None`), silently degrading to the in-process dict, while its response-cache selector and the other three frameworks RAISE on an unknown name. | Python raises on an unknown `TINA4_DB_CACHE_BACKEND` too, matching the response-cache contract and the other three. Confirm PHP/Ruby/Node do not wrap the factory call (they route through the raising factory; wrapping not observed). |
| CI-02 | The graceful fallback is SELECTION-TIME only; a backend that dies mid-life yields silent misses and `set` no-ops with no warning and no re-fallback, in all four. | Decide the runtime-death policy: log at least once (rate-limited) on a mid-life backend failure so a dead cache is visible, not just a startup one. |
| CI-03 | PHP reads some cache env via raw `getenv` (`Cache.php`, `ResponseCache.php`) and some via `DotEnv::getEnv` (factory, backends, `CachedDatabase`), with different `.env`-visibility semantics. | Read cache env through one path in PHP (the `DotEnv` reader), matching the single-path env reads elsewhere. |
| CI-04 | The `set` verb takes a positional `ttl` on the backend but a keyword `ttl:` on Ruby's `QueryCache` facade; a couple of module aliases (`cache_clear` for `clear_cache`) exist. | Minor: align the facade `set` signature; document the intentional back-compat alias. |

Not defects (settled, uniform, PROVEN): the 8 `cache_contract.json` invariants - unknown-name-raises,
explicit-provider, graceful-fallback, clear-invalidates, sweep-count, ttl-seconds, cached-null,
key-database-identity, persistent-clear, and namespace invalidation - all hold in all four and are
locked by named tests.

## Owner decisions

Proposed for owner ratification. The interface is settled and proven; these are the open calls:

1. DB-CACHE TYPO (CI-01): Python raises on an unknown `TINA4_DB_CACHE_BACKEND` (remove the swallow),
   so a typo never runs silently on any selector in any framework. This is the clear defect.
2. MID-LIFE DEGRADATION (CI-02): decide whether a backend that dies after selection must log (once,
   rate-limited) rather than silently miss, in all four. The startup fallback is already loud; this is
   about the runtime path.
3. PHP ENV PATH (CI-03) and the facade `set` signature (CI-04): housekeeping - one env-read path in
   PHP, one `set` spelling.

## Proposed conformance fixture

`cache_contract.json` already gates the 8 interface invariants (8/8 proven). Add two cases: a typo'd
`TINA4_DB_CACHE_BACKEND` RAISES on every framework (closes CI-01, over a real selection), and a
backend that becomes unreachable AFTER selection is logged rather than silently missing (CI-02, over a
real stopped backend). Both run in all four runners with no doubles.

## Integration map

- Features 73-79 are the providers behind this interface; Feature 80 is the response cache that
  consumes it; the Database layer's query cache consumes it for the persistent mode.
- `cache_contract.json` proves the interface invariants; the two new cases above extend it.
- ADR-0024/0030/0031/0032 govern the contract; the cache docs describe the env vars and modes.

## Breaking changes and migration

- CI-01 makes a Python `TINA4_DB_CACHE_BACKEND` typo raise instead of silently degrading: a Python
  deployment with a typo'd DB-cache backend that "worked" (on the in-process dict) now fails loudly.
  `Breaking:` and a correctness fix - the typo was never doing what the operator intended.
- CI-02/CI-03/CI-04 are additive/internal; no app breaks.

## Implementation backlog

1. Add the two cases to `cache_contract.json` and wire four runners.
2. Fix CI-01 (Python DB-cache typo raises); decide and gate CI-02 (mid-life logging).
3. Fold in CI-03 (PHP one env path) and CI-04 (facade `set`).
4. Run locally and on the root lab, then confirm the CONTRACT-MAP row stays 8/8 (plus the two new).

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the cache interface: a backend exposes `get`/`set(key, value, ttl_seconds)`/`delete`/`clear`/
`stats`/`name`/`sweep`/`available?`. A factory selects the backend from `TINA4_CACHE_BACKEND` (raising
on an unknown name, honouring an explicit argument over the env, ADR-0024), probes a networked backend
with a real handshake, and degrades LOUDLY to a persistent file backend when it is unreachable.
`clear()` removes every entry the cache serves (SCAN+DEL / generation bump / DELETE, never FLUSHALL);
`sweep()` returns the evicted count (0 for a server-expiring provider); a stored null round-trips as
null; the query-cache key carries the `engine://host:port/database` identity (ADR-0030); memcached
invalidates by generation and redis by SCAN (ADR-0031). Raise on a typo in EVERY selector. Prove the
port with the 8 invariants plus the typo-raises and mid-life-visible cases.

## Audit closure checklist

- [x] Boundary and public surface complete (interface, factory, three modes).
- [x] Lifecycle and every producer/consumer edge complete (select/probe/operate/invalidate).
- [x] Configuration, failure, side-effect and security rules complete (unknown-name, fallback, typo).
- [x] Wire/storage and provider contracts complete (interface contract; providers deferred to 73-79).
- [x] Existing-language contradictions recorded (CI-01..04; the interface is otherwise proven parity).
- [x] Owner ambiguities recorded (3 proposed; the Python DB-cache typo swallow is the one real defect).
- [x] Proposed shared cases and mutation witnesses complete (8 proven + 2 new, no doubles).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
