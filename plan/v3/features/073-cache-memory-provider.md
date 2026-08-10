# Feature 073: Memory cache provider

## Identity and status

- Matrix identity: 73 - Memory cache provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the memory backend in each cache module)
  at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: Feature 72 (the cache interface + factory)
- Dependants: the default cache mode (memory is the default backend); any deployment on
  `TINA4_CACHE_BACKEND=memory`
- Existing ADRs: ADR-0024 (provider interface), ADR-0032 (sweep returns evicted count)
- Shared fixtures: `cache_contract.json` (8/8 PROVEN) exercises the memory backend for every interface
  invariant. This packet records the memory-specific contract.
- Catalog phase: Cache (providers)

## Why this feature exists

The default cache needs no service: it keeps entries in an in-process map, bounded by a max-entries
cap, with per-entry expiry. It is the fastest backend and the zero-config default - and, being
per-process, the one that does NOT share across instances.

## Boundary

This feature owns the memory backend's `get`/`set`/`delete`/`clear`/`sweep`/`stats`: the in-process
store, the bound, and the expiry check. It DELEGATES selection and fallback to Feature 72. It is a
provider behind the Feature 72 interface.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Store | in-process dict | array | Hash | Map |
| Stored shape | `(value, expires_at)` tuple | envelope | `[value, expires_at]` pair | entry object |
| Bound (`TINA4_CACHE_MAX_ENTRIES`) | 1000 | 1000 | 1000 | 1000 |
| Cached null | HIT (present entry) | HIT | HIT (truthy pair) | HIT |
| `sweep()` returns count | yes | yes | yes | yes |
| `clear()` empties the store | yes | yes | yes | yes |
| Cross-instance | no (per-process, by design) | no | no | no |

The memory backend is at full parity and fully proven. A cached null is a HIT because the miss check
is entry-presence, never value-truthiness. `sweep()` returns the real evicted count (memory is not
server-expiring, so it must reclaim). The store is bounded by `TINA4_CACHE_MAX_ENTRIES`.

## Public surface contract

`get(key) -> value | miss` (a present entry is a hit, even for a stored null); `set(key, value, ttl)`
(store `(value, expires_at)` where `expires_at` is `now + ttl` for `ttl > 0`, else never);
`delete(key)`; `clear()` (empty the store); `sweep() -> evicted` (drop expired entries, return the
count); `stats() -> {hits, misses, size, backend}`. The store is bounded; the eviction policy on the
bound is the one thing to pin (LRU vs insertion-order).

## Configuration and precedence

`TINA4_CACHE_MAX_ENTRIES` (default 1000) bounds the store. TTL is seconds (`<=0` = no expiry). There is
no URL, no credentials, no service. The memory backend is the fallback target's ONLY peer that is not
persistent - a note for the response cache, which prefers the file fallback for durability.

## Failures, side effects and security

- MEMORY GROWTH: the store is bounded by `TINA4_CACHE_MAX_ENTRIES`; the eviction policy at the bound
  (MC-73-01) should be pinned identical across the four so a full cache evicts the same entry
  everywhere.
- PER-PROCESS: the memory cache is not shared, so two workers can serve different cached values - this
  is inherent and documented; a deployment needing cross-worker consistency picks a networked backend.
- No external surface (no socket, no file), so no injection or credential concern.

## Wire and persistence contract

There is no persistence; the store is an in-process map from key to `(value, expires_at)`. The
observable contract: a value set with a TTL is gone after the TTL, a `clear()` empties the store, and a
stored null returns null. Nothing survives a process restart.

## Providers and substitutability

The memory backend is the default and the interface's simplest implementation; every networked backend
substitutes it behind the same interface (Feature 72). It is also the graceful-fallback peer, though
the factory prefers the FILE backend for a persistent fallback.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MC-73-01 | The eviction policy at `TINA4_CACHE_MAX_ENTRIES` (LRU vs insertion-order vs random) is not pinned identical across the four. | Pin one eviction policy (recommend LRU) so a bounded cache evicts the same entry in every framework. |

Everything else is proven parity: cached-null, sweep-count, clear, ttl-seconds all hold and are locked
by `cache_contract.json`.

## Owner decisions

Proposed for owner ratification:

1. EVICTION POLICY (MC-73-01): pin one policy at the max-entries bound (recommend LRU) across the four.

There are no other open questions - the memory backend is proven parity.

## Proposed conformance fixture

`cache_contract.json` already gates the memory backend for every interface invariant. Add one case: a
store filled past `TINA4_CACHE_MAX_ENTRIES` evicts the SAME entry (per the pinned policy) in all four.

## Integration map

- Feature 72 selects and bounds this backend; it is the default and the interface's reference.
- `cache_contract.json` proves it for every invariant; the eviction-policy case is added there.

## Breaking changes and migration

- Pinning the eviction policy is internal; no app breaks (a bounded cache already evicts something).

## Implementation backlog

1. Add the eviction-policy case to `cache_contract.json`; pin LRU (MC-73-01) in all four.
2. Run locally and on the root lab; the CONTRACT-MAP row stays proven.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the memory backend: an in-process map from key to `(value, expires_at)`, bounded by
`TINA4_CACHE_MAX_ENTRIES` with an LRU eviction. `get` is a hit on a present entry (even a stored null);
`set` stores `(value, now + ttl)` (`ttl <= 0` = never); `clear` empties the map; `sweep` drops expired
entries and returns the count; `stats` reports hits/misses/size. Prove the port with a cached-null
hit, a sweep count, a clear, and a bound-eviction.

## Audit closure checklist

- [x] Boundary and public surface complete (in-process store + bound + expiry).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (bound, per-process).
- [x] Wire/storage and provider contracts complete (no persistence; interface behaviour).
- [x] Existing-language contradictions recorded (MC-73-01, eviction policy).
- [x] Owner ambiguities recorded (1 proposed; eviction policy).
- [x] Proposed shared cases and mutation witnesses complete (proven + eviction case).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
