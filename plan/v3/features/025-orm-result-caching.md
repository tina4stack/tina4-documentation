# Feature 25: ORM result caching

## Identity and status

- Matrix identity: 25 - ORM result caching (`tina4_python/orm/model.py`; `tina4_python/core/cache.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature with a STRUCTURAL divergence (an explicit method in three, adapter-level
  in Node) and a shared stale-on-write footgun. Measured 2026-08-11. Python `orm/model.py:1144` `cached()` +
  `connection.py` auto-cache (`ebbab30`); PHP `Tina4/ORM.php:2171` `cached()` + `CachedDatabase.php`
  (`6faabac5`); Ruby `lib/tina4/orm.rb:381` `cached` + `database.rb` auto-cache (`6d5b1de`); Node
  `packages/orm/src/cachedDatabase.ts` (adapter-level only) (`27cf0f4`).
- Dependencies: the query-cache store (TTL + LRU + tags), the DB facade.
- Dependants: apps caching hot queries.
- Existing ADRs: none dedicated. Memory: `TINA4_AUTO_CACHING` vs `TINA4_DB_CACHE`.

- Catalog phase: ORM / database

## Why this feature exists

Caching a hot query's rows avoids a round-trip. The correctness-critical part is INVALIDATION: a cached read
must not return rows a subsequent write changed. Tina4 has two layers (an explicit per-query ORM cache and an
adapter-level auto-cache) - and the explicit one has a stale-on-write footgun.

## Existing implementation evidence

Two mechanisms, but implemented differently:

- Explicit ORM cache METHOD (Python/PHP/Ruby): `Model.cached(sql, ttl=60)` stores a query's instances in a
  process-wide TTL+LRU+tag store, keyed by `class:query_key:limit:offset`. INVALIDATION is the footgun -
  Python's `save()` busts it (but `delete`/`force_delete`/`restore` do NOT); PHP and Ruby never bust it
  automatically at all (only a manual `clear_cache`). So a cached read returns stale/deleted rows until TTL.
  Node has NO such method.
- Adapter-level auto-cache (all four): `TINA4_DB_CACHE` (persistent cross-request, OFF by default, TTL 30) +
  `TINA4_AUTO_CACHING` (request-scoped dedupe, OFF by default, TTL 5), keyed by DB-identity + SQL + params.
  Writes (execute/insert/update/delete) do a WHOLESALE flush, so ORM writes DO bust it. Node relies ENTIRELY
  on this layer (it caches all reads through the adapter and busts on write) - which is why Node avoids the
  stale-on-write footgun the explicit method has.

## Public surface contract

`Model.cached(sql, ttl)` (Python/PHP/Ruby) returns cached instances; the adapter auto-cache is env-gated. The
contract SHOULD be: a write invalidates a cached read. The explicit method violates it (see the register).

## Inputs and outputs

- Input: SQL + params + TTL (explicit); or any read (auto-cache). Output: cached instances/rows; a write
  invalidation.

## Lifecycle and operation graph

1. Explicit: `cached()` -> store keyed by class+query, TTL 60. Manual `clear_cache` (tag-scoped).
2. Auto-cache: read -> cache; write -> wholesale flush.

## Configuration and precedence

- `TINA4_DB_CACHE` (+`_TTL`/`_BACKEND`/`_URL`), `TINA4_AUTO_CACHING` (+`_TTL`), both OFF by default
  (deliberately - a cached `MAX(id)` before an INSERT in one request would duplicate keys). The explicit
  `cached()` TTL defaults to 60s.

## Failures, side effects and security

- The failure mode is a STALE READ (see the register). No security surface. Persistent auto-cache with the
  default memory backend is per-process, so cross-instance staleness lasts up to TTL unless a network backend
  is configured.

## Wire and persistence contract

No persisted state (unless a network cache backend). The invalidation contract is "a write busts a cached
read" - met by the auto-cache, violated by the explicit method.

## Providers and substitutability

The auto-cache backend is pluggable (memory / Redis-class via `TINA4_DB_CACHE_BACKEND`). The explicit method
uses the in-process store.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CACHE-EXPLICIT-STALE | The explicit `Model.cached()`/`ORM::cached()` (Python/PHP/Ruby) is STALE-ON-WRITE: Python's `save()` busts it but `delete`/`force_delete`/`restore` do NOT; PHP and Ruby never bust it automatically at all (manual `clear_cache` only). So a read-after-write through the ORM returns stale/deleted rows until the 60s TTL. Node has no such method (its adapter auto-cache busts on write, so Node is safe). | Make the explicit cache invalidate on ALL writes (save AND delete/force_delete/restore) - or drop the explicit method in favour of the adapter auto-cache (Node's model), which invalidates correctly. Either way, no silent stale-read. |
| CACHE-STRUCTURAL-DIVERGENCE | The feature is implemented differently: Python/PHP/Ruby expose an explicit per-query `cached()` method PLUS the adapter auto-cache; Node has ONLY the adapter auto-cache. So "ORM result caching" is a different surface across the four - a portability inconsistency, and the one that decides CACHE-EXPLICIT-STALE. | Decide the canonical model: either add an explicit method to Node (with correct invalidation), or drop it from Python/PHP/Ruby and standardise on the adapter auto-cache. |
| CACHE-CROSS-MODEL | The explicit cache's `clear_cache` clears only the calling class's tag, so a `cached()` query that JOINs another table is not invalidated when the OTHER model writes (Python). And `ttl=0` stores a NEVER-expiring entry. | Tag a cached query by every table it touches; treat `ttl=0` as no-cache (not infinite). |
| CACHE-TEST-WEAK | The explicit-cache invalidation is under-tested: PHP's `testCacheClearsOnSave` tests the RELATIONSHIP cache (`_relCache`), not the query cache (and is weak - the relation is empty throughout); no test asserts `cached()` write-invalidation in PHP. | Add a real test that a `cached()` query returns fresh rows after a write (once CACHE-EXPLICIT-STALE is fixed). |

## Owner decisions

- CACHE-DEC-01 (proposed): fix the explicit-cache stale-on-write (CACHE-EXPLICIT-STALE) - invalidate on all
  writes, or drop the explicit method for the adapter auto-cache (Node's correct model). Highest value (silent
  stale/deleted-row reads).
- CACHE-DEC-02 (proposed): decide the canonical caching surface (CACHE-STRUCTURAL-DIVERGENCE); fix cross-model
  invalidation + `ttl=0` (CACHE-CROSS-MODEL); add the invalidation test (CACHE-TEST-WEAK).

## Proposed conformance fixture

A shared fixture (real DB): a `cached()` query returns FRESH rows after a save AND after a delete (catches
CACHE-EXPLICIT-STALE); the adapter auto-cache is OFF by default, dedupes when on, and flushes on write; a
cross-table cached query is invalidated when either table writes.

## Integration map

- Consumers: apps caching queries. Composes: the DB facade, the cache engine (feature 43 family). The
  auto-cache wraps every adapter.

## Breaking changes and migration

- Fixing invalidation changes behaviour only in the stale window (a correctness fix). Standardising the surface
  (if the explicit method is dropped) is a breaking API change - version it.

## Porting capsule

ORM result caching needs ONE canonical model with CORRECT invalidation: either an adapter-level cache that
busts on every write (Node's model - safe), or an explicit per-query method that invalidates on ALL writes
(save AND delete) and tags by every table it touches - never a `cached()` that only `save()` busts (or that
nothing busts). Keep the request-scoped/persistent auto-cache OFF by default (the read-after-write footgun),
and treat `ttl=0` as no-cache, not infinite.

## Audit closure checklist

- [x] Boundary and public surface complete (explicit method + auto-cache x four).
- [x] Lifecycle and producer/consumer edges complete (cache, invalidate).
- [x] Configuration, failure (stale read) and security rules complete.
- [x] Wire (invalidation contract) and provider (backend) contracts complete.
- [x] Four-language behaviour + the structural divergence recorded.
- [x] Owner ambiguities decided (CACHE-DEC-01/02).
- [x] Conformance fixture (write-invalidation) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
