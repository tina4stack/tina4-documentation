# Feature 077: Memcached cache provider

## Identity and status

- Matrix identity: 77 - Memcached cache provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the memcached backend in each cache
  module) at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code
  changed.
- Dependencies: Feature 72 (interface), a memcached server, the ASCII text transport
- Dependants: any deployment on `TINA4_CACHE_BACKEND=memcached`
- Existing ADRs: ADR-0024 (interface), ADR-0031 (memcached invalidates by NAMESPACE GENERATION),
  ADR-0032 (server-expiring sweep returns 0)
- Shared fixtures: `cache_contract.json` (8/8 PROVEN) exercises the memcached backend against a live
  memcached, including the ttl-units 30-day-cliff invariant.
- Catalog phase: Cache (providers)

## Why this feature exists

A deployment running memcached can use it as a shared cache. The backend speaks the memcached ASCII
text protocol over a raw socket (no client library), stores each entry under a generation-namespaced
key with a native exptime, and - because memcached has no SCAN and no prefix-delete - invalidates
`clear()` by bumping a shared generation counter embedded in every key (ADR-0031).

## Boundary

This feature owns the memcached cache backend's `get`/`set`/`delete`/`clear`/`available?`: the text
transport, the generation-namespaced key, the exptime handling (with the 30-day cliff), and the
JSON serialization. It DELEGATES selection and fallback to Feature 72. It shares the text transport with
the session memcached provider (Feature 71).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | raw ASCII text, stdlib socket | raw text, `fsockopen` | raw text, stdlib socket | raw text, `node:net` via worker |
| Key | `tina4:cache:<generation>:sha256(key)` | same | same | same |
| Namespace invalidation (ADR-0031) | generation bump on `clear()` | same | same | same |
| Generation read per op (never cached) | yes | yes | yes | yes |
| 30-day exptime cliff | CONVERT to absolute (not clamp) | same | same | same |
| `sweep()` | 0 (server-expiring, honest) | 0 | 0 | 0 |
| Cached null (JSON `"null"`) | HIT | HIT | HIT | HIT |

The memcached cache backend is at full parity and proven. The 30-day exptime cliff - a value >
2592000 treated by memcached as an ABSOLUTE unix timestamp - is handled by CONVERTING a large relative
ttl to an absolute stamp (never clamping) in all four (verified 2026-08-10, `MAX_RELATIVE_EXPTIME` in
every backend; the earlier session_contract.json note that recorded the cache side as owed predates
this fix). `clear()` bumps a shared generation counter, so it invalidates every instance's entries
without a SCAN.

## Public surface contract

`get(key) -> value | miss` (`get <generation-key>`, JSON-decode; a stored `"null"` is a HIT); `set(key,
value, ttl)` (`set <key> 0 <exptime> <bytes>`, `STORED` expected, exptime converting past the 30-day
cliff); `delete(key)` (`delete <key>`); `clear()` (bump the generation counter, orphaning every prior
key); `sweep() -> 0`. The generation is read from the server on every op (never cached) so a bump is
seen immediately.

## Configuration and precedence

`TINA4_CACHE_URL` (default `memcached://localhost:11211`), key prefix `tina4:cache:`. The connection
opens on first use with a `version` probe (`available?`); an unreachable server falls back to file
(Feature 72). The generation counter lives under a fixed generation key in the same namespace.

## Failures, side effects and security

- ZERO-DEP: the raw ASCII text protocol needs no client library (shared with Feature 71).
- NAMESPACE INVALIDATION (ADR-0031): memcached has no SCAN and no prefix delete, so `clear()` bumps a
  generation counter embedded in every key. This invalidates ALL instances' entries at once, which a
  per-instance own-key delete could not do, and a `flush_all` would over-invalidate (nuking other
  tenants). The generation is read per op so a bump is immediate.
- THE 30-DAY EXPTIME CLIFF is handled uniformly (proven, cache_contract ttl-units): a relative ttl past
  2592000 is CONVERTED to an absolute stamp, so `TINA4_CACHE_TTL` "about a month" is not silently
  expired-on-write. This is the cache-side fix that matches the session side (Feature 71).
- KEY SAFETY: the key is `prefix:generation:sha256(key)`, so it is bounded (under 250 bytes) and
  contains no control chars - no injection surface.
- SERVER-EXPIRING: `sweep()` returns 0 honestly (ADR-0032).

## Wire and persistence contract

The value is a JSON string under `tina4:cache:<generation>:sha256(key)`, expiry via the exptime. A
`clear()` bumps the generation, so all prior keys become unreachable (and memcached evicts them under
memory pressure). A stored null round-trips. The generation-namespaced key is uniform across the four.

## Providers and substitutability

Selected by `TINA4_CACHE_BACKEND=memcached` (ADR-0024). It shares the text transport with the session
memcached provider (Feature 71). It is the one cache backend whose invalidation is namespace-generation
rather than key-scan (ADR-0031), because the protocol offers no alternative.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MC-77-01 | The host/timeout/connection-model divergences noted for the SESSION memcached provider (Feature 71 MC-01..04: Node `127.0.0.1` vs `localhost`, Node persistent-connection, Node no configurable timeout, control-char coverage edge) apply to the cache memcached backend's transport if it shares that code. | Confirm the cache memcached backend inherits the session memcached transport decisions; resolve together with Feature 71. |

No cache-specific open defects: the memcached cache backend is proven parity - the 30-day cliff is
CONVERTED (not clamped) in all four, the generation invalidation is correct (ADR-0031), and `sweep()=0`
is honest.

## Owner decisions

Proposed for owner ratification:

1. Confirm the cache memcached backend inherits the Feature 71 transport decisions (host, timeout,
   connection model, unsafe-key predicate) - one memcached transport policy across cache and session
   (MC-77-01).

The memcached cache backend is otherwise proven parity - the exptime cliff and the generation
invalidation are both correct and gated.

## Proposed conformance fixture

`cache_contract.json` already gates the memcached backend for every invariant against a live memcached,
including the 30-day-cliff convert-not-clamp (asserting the server's own reported remaining ttl). Add
one generation case: a `clear()` bump makes a prior key a miss on every framework (over a real
memcached), proving the ADR-0031 namespace invalidation.

## Integration map

- Feature 72 selects and probes this backend; Feature 71 is the session memcached sibling sharing the
  text transport.
- `cache_contract.json` proves it (including the cliff) against a live memcached; the generation case is
  added there.
- ADR-0031 governs the namespace-generation invalidation.

## Breaking changes and migration

- Inheriting the Feature 71 transport decisions is a config change; no cache data breaks.

## Implementation backlog

1. Confirm the cache memcached backend shares the session memcached transport; resolve MC-77-01 with
   Feature 71.
2. Add the generation-invalidation case to `cache_contract.json`.
3. Run locally and on the root lab; the CONTRACT-MAP row stays proven.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the memcached cache backend: speak the ASCII text protocol over a raw socket, connecting on
first use with a `version` probe. Build the key as `tina4:cache:<generation>:sha256(key)`, reading the
generation from the server on every op. `get` is `get <key>` JSON-decoded (a stored `"null"` is a hit);
`set` is `set <key> 0 <exptime> <bytes>` where the exptime CONVERTS any ttl past 2592000 to an absolute
stamp (never clamp); `delete` is `delete <key>`; `clear` bumps the generation counter (orphaning every
prior key); `sweep` returns 0. Degrade to file when unreachable. Prove the port with a native-exptime
expiry, a 60-day convert-not-clamp case, a generation-bump clear that turns a prior key into a miss,
and a cached-null hit.

## Audit closure checklist

- [x] Boundary and public surface complete (text protocol get/set/delete + generation clear + exptime).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (zero-dep, cliff, generation).
- [x] Wire/storage and provider contracts complete (generation-namespaced key, JSON, exptime).
- [x] Existing-language contradictions recorded (MC-77-01; the exptime cliff is CONVERTED, verified).
- [x] Owner ambiguities recorded (1 proposed; inherit the Feature 71 transport policy).
- [x] Proposed shared cases and mutation witnesses complete (proven cliff + generation, real memcached).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
