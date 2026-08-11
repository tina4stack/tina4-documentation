# Feature 60: Frond fragment caching

## Identity and status

- Matrix identity: 60 - Frond fragment caching (`{% cache "key" ttl %}...{% endcache %}`)
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language Frond source. `{% cache %}` exists in all four with a
  default 60s TTL, but the store is UNBOUNDED and per-instance and a shared key collides. Python
  `frond/engine.py:2571` (`46007c1`); PHP `Tina4/Frond.php:1492` (`ab871934`); Ruby `lib/tina4/frond.rb:2240`
  (`f549923`); Node `packages/frond/src/engine.ts:3001` (`1319cf3`).
- Dependencies: the runtime (51), the template cache (59).
- Dependants: templates caching an expensive block.
- Existing ADRs: ADR-0004.

- Catalog phase: Frond

## Why this feature exists

`{% cache "key" ttl %}` caches a rendered block for `ttl` seconds so an expensive fragment is not re-rendered
every request. The audit questions: is the store bounded, does it survive across requests, and what happens on
a key collision. It is at parity as a within-instance TTL cache, but the store is unbounded, per-instance, and
a shared key silently collides.

## Existing implementation evidence

Universal shape, measured:

- `{% cache "key" ttl %}...{% endcache %}` in all four: Python `_handle_cache` (`engine.py:2571`); PHP
  `renderCache` (`Frond.php:1492`); Ruby `handle_cache` (`frond.rb:2240`); Node `handleCache`
  (`engine.ts:3001`). Default TTL 60s (PHP `:924`, Ruby `:2244`, Node); `ttl <= 0` means not cached (PHP
  `:1501`).
- The store is an UNBOUNDED in-memory dict/map, PER Frond INSTANCE, in all four (Python unbounded dict; PHP
  `$this->cache` `:21` never capped; Ruby `@fragment_cache` `:304`; Node `this.fragmentCache` `:1715` never
  passed through `capCache`).
- Keyed by the LITERAL key string; two `{% cache %}` blocks sharing a key COLLIDE (last writer wins) in all
  four.
- No cache-backend abstraction (no redis/memcached/database like the response cache feature) - it is
  in-process, per-instance only.

## Public surface contract

`{% cache "key" ttl %}` caches the block for `ttl` seconds within the Frond instance. The key must be unique
per block; the cache is not shared across requests/instances.

## Inputs and outputs

- Input: a key + a TTL + a block. Output: the cached rendered block until TTL expiry.

## Lifecycle and operation graph

1. `{% cache key ttl %}` -> cache hit (fresh) returns the stored HTML; miss renders the block and stores it
with an expiry. 2. Expiry is TTL-only (no manual bust).

## Configuration and precedence

- TTL per block (default 60s); `ttl <= 0` disables. No env var, no backend selection.

## Failures, side effects and security

- Memory: the store is unbounded (distinct keys grow it without limit) - a leak over a long-running instance
  rendering many distinct cache keys. A shared key silently serves the wrong block. See the register.

## Wire and persistence contract

In-memory, per-instance. No wire/persistence, no cross-request/cross-instance sharing.

## Providers and substitutability

A future runtime should bound the fragment store, make a key collision safe, and decide whether to back it
with the unified cache backend set (so it survives across requests).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| FRAGCACHE-UNBOUNDED | UNIVERSAL (cross-ref feature 59 CACHE-FRAGMENT-UNBOUNDED): the fragment store is UNBOUNDED in all four (`$this->cache`/`@fragment_cache`/`fragmentCache`/the Python dict never capped) - distinct keys grow memory without limit over a long-running instance. | Bound the fragment store (agreed size + eviction), with feature 59 CACHE-DEC-01. |
| FRAGCACHE-KEY-COLLISION | UNIVERSAL: two `{% cache %}` blocks with the SAME key COLLIDE (last writer wins) in all four - block B's cached HTML is served for block A. A silent correctness footgun (a caller reusing a key gets the wrong content). | Make a shared-key reuse safe (namespace by template + block position) or raise on a duplicate key; gate it. |
| FRAGCACHE-PER-INSTANCE-NO-BACKEND | The fragment cache is in-memory PER Frond INSTANCE only, with NO backend abstraction (unlike the response cache's redis/memcached/database set). So in a fresh-instance-per-request deployment it does NOT survive across requests, and it never shares across instances - limiting its value to within-instance reuse. | Decide: back the fragment cache with the unified cache backend set (survives across requests/instances), or document it as within-instance-only. |
| FRAGCACHE-NO-INVALIDATION | Expiry is TTL-only; no manual bust or tag-based invalidation - a cached fragment serves stale data until the TTL, even after the underlying data changes. | Optionally add a manual/tag invalidation (or document TTL-only). |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- FRAGCACHE-DEC-01 (proposed): bound the fragment store (FRAGCACHE-UNBOUNDED, with feature 59) and make a
  shared-key collision safe or an error (FRAGCACHE-KEY-COLLISION) - the two real correctness/memory footguns.
- FRAGCACHE-DEC-02 (proposed): decide whether the fragment cache uses the unified backend set so it survives
  across requests/instances (FRAGCACHE-PER-INSTANCE-NO-BACKEND), or document it as within-instance-only; and
  whether to add manual invalidation (FRAGCACHE-NO-INVALIDATION).

## Proposed conformance fixture

A shared fixture (real render): `{% cache "k" 60 %}` returns the cached HTML on the second render within TTL,
re-renders after; TWO blocks sharing a key do NOT serve each other's content (catches FRAGCACHE-KEY-COLLISION);
rendering N+1 distinct keys evicts to a bounded size (FRAGCACHE-UNBOUNDED).

## Integration map

- Consumers: templates caching an expensive block. Composes: the runtime (51), the template cache (59, shares
  the bound decision), potentially the unified cache backend (the response-cache family).

## Breaking changes and migration

- Bounding the store changes memory behaviour (a fix). Namespacing keys changes cache-hit behaviour for
  duplicate keys (a correctness fix). Backing it with a network cache (if chosen) changes cross-request
  behaviour - version it.

## Porting capsule

Implement `{% cache "key" ttl %}` as a BOUNDED cache (never unbounded - the universal leak), keyed so two
blocks with the same key do NOT collide (namespace by template + position, or raise on a duplicate). Default
TTL 60s, `ttl <= 0` disables. Decide whether it uses the unified cache backend (survives across
requests/instances) or is within-instance-only, and document it. TTL-only expiry unless a manual invalidation
is added.

## Audit closure checklist

- [x] Boundary and public surface complete ({% cache %} x four).
- [x] Lifecycle and producer/consumer edges complete (hit/miss/expiry).
- [x] Configuration (TTL), failure (unbounded/collision) and security rules complete.
- [x] Wire (in-memory per-instance) and provider contracts complete.
- [x] Four-language behaviour recorded (unbounded + collision + per-instance all four).
- [x] Owner ambiguities decided (FRAGCACHE-DEC-01 bound/collision, FRAGCACHE-DEC-02 backend).
- [x] Conformance fixture (bound + collision) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
