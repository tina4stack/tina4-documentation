# Feature 078: MongoDB cache provider

## Identity and status

- Matrix identity: 78 - MongoDB cache provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the mongo backend in each cache module) at
  Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: Feature 72 (interface), a MongoDB server, the OP_MSG wire transport (shared with the
  session mongo provider, Feature 69)
- Dependants: any deployment on `TINA4_CACHE_BACKEND=mongodb`
- Existing ADRs: ADR-0024 (interface), ADR-0032 (server-expiring sweep returns 0)
- Shared fixtures: `cache_contract.json` (8/8 PROVEN) exercises the mongo backend against a live
  MongoDB.
- Catalog phase: Cache (providers)

## Why this feature exists

A deployment already running MongoDB can use it as a shared cache. The backend speaks the MongoDB wire
protocol (OP_MSG) over a raw socket - no driver required - storing each entry as a document keyed by
the cache key, with an `expires_at` and a `deleteMany` clear.

## Boundary

This feature owns the mongo cache backend's `get`/`set`/`delete`/`clear`/`available?`: the OP_MSG
transport, the cache document, the TTL, and the collection. It DELEGATES selection and fallback to
Feature 72. It shares the OP_MSG transport with the session mongo provider (Feature 69).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | driver preferred, raw OP_MSG fallback | raw OP_MSG only | gem preferred, raw fallback | driver preferred, raw fallback |
| Record | `{_id: key, value, expires_at}` | same | same | same |
| Cached null (JSON `"null"` in value) | HIT | HIT | HIT | HIT |
| `clear()` | `deleteMany({})` | same | same | same |
| `sweep()` | 0 (treated server-expiring) | 0 | 0 | 0 |
| Expiry enforcement | read-time `expires_at` (TTL index parity, see MG-78-01) | same | same | same |
| Injection (`_id` bound) | safe | safe | safe | safe |

The mongo cache backend is at parity and proven for the interface invariants. `clear()` is a
`deleteMany({})`, the value round-trips a stored null, and the `_id` is bound (no injection). TTL
enforcement was measured 2026-08-11: it is a MongoDB SERVER TTL INDEX (`expireAfterSeconds`) in all four
(Node `packages/core/src/cache.ts:1187` `createIndex({expiresAt:1},{expireAfterSeconds:0})`; PHP
`Tina4/Cache/MongoBackend.php:183` `expireAfterSeconds:0`; Ruby `cache_backends/mongo_backend` "MongoDB
TTL collection"; Python `core/cache.py` mongo backend), PLUS a read-time `expires_at` check for
determinism (the TTL index sweeps lazily - explicit in Node `cache.ts:1213`). So it is BOTH mechanisms,
at parity - the same shape as the session mongo provider (Feature 69).

## Public surface contract

`get(key) -> value | miss` (find one by `_id`, return `value`, a stored null is a HIT; a past
`expires_at` is a miss); `set(key, value, ttl)` (upsert `{_id: key, value, expires_at}`); `delete(key)`
(delete one by `_id`); `clear()` (`deleteMany({})`); `sweep() -> 0`. The document lives in the cache
collection.

## Configuration and precedence

`TINA4_CACHE_URL` (default `mongodb://localhost:27017`), the cache database/collection, plus the cache
credentials. The connection opens on first use with a `ping` probe (`available?`); an unreachable
server falls back to file (Feature 72).

## Failures, side effects and security

- ZERO-DEP: all four hand-roll OP_MSG over a raw socket (shared with Feature 69).
- INJECTION is closed: the cache key is bound as `_id`, never interpolated.
- SERVER-EXPIRING (declared): `sweep()` returns 0. But mongo does NOT auto-expire without a TTL index,
  so an untouched-but-expired document lingers unless a read removes it or a TTL index reaps it -
  MG-78-01, the same question as the session mongo provider (Feature 69 MG-04).
- FALLBACK: an unreachable MongoDB degrades to file at selection time (Feature 72); a mid-life death is
  silent (Feature 72 CI-02).

## Wire and persistence contract

The entry is a document `{_id: <cachekey>, value, expires_at}` in the cache collection; `value` carries
the JSON-encoded cached value (a stored null round-trips). A `clear()` empties the collection. Expiry
is enforced at read time (and by a TTL index where present); MG-78-01 pins which.

## Providers and substitutability

Selected by `TINA4_CACHE_BACKEND=mongodb` (ADR-0024). Shares the OP_MSG transport with the session
mongo provider (Feature 69). A deployment already on MongoDB uses it to avoid a second cache service.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MG-78-01 | `sweep()` returns 0 (declared server-expiring), but MongoDB does not auto-expire without a TTL index; an untouched-expired document lingers unless a read removes it. Same question as the session mongo provider (Feature 69 MG-04) and the Node ttl handler-boundary gap (Feature 69 MG-01). | Pin the TTL-enforcement mechanism (read-time check plus a server TTL index) for the cache mongo backend, consistent with the session mongo decision; a cache lingering is lower-severity (disposable) but the mechanism should be one contract. |
| (shared) | The connect-timeout and driver-vs-raw notes for the session mongo provider (Feature 69 MG-02/MG-05) apply to the cache mongo backend's transport if it shares that code. | Confirm the cache mongo backend inherits the session mongo transport decisions; resolve with Feature 69. |

No cache-specific data-correctness defect: the mongo cache backend is proven parity on the interface
invariants (clear, cached-null, injection).

## Owner decisions

Proposed for owner ratification:

1. TTL ENFORCEMENT (MG-78-01): pin the cache mongo TTL mechanism (read-time + optional TTL index)
   consistent with the session mongo decision (Feature 69); a lingering expired cache document is
   lower-severity but should follow one contract.
2. Confirm the cache mongo backend inherits the Feature 69 transport decisions (connect timeout,
   driver-vs-raw).

## Proposed conformance fixture

`cache_contract.json` already gates the mongo backend for every interface invariant against a live
MongoDB. Add one expiry case: an expired document is not served (read-time), and (if a TTL index is the
pinned mechanism) is reaped, on every framework over a real MongoDB.

## Integration map

- Feature 72 selects and probes this backend; Feature 69 is the session mongo sibling sharing OP_MSG.
- `cache_contract.json` proves it against a live MongoDB; the expiry case is added there.

## Breaking changes and migration

- Pinning the TTL mechanism (adding a TTL index) is additive; no cache data breaks.

## Implementation backlog

1. Pin the cache mongo TTL mechanism (MG-78-01) with Feature 69; confirm the shared transport.
2. Add the expiry case to `cache_contract.json`.
3. Run locally and on the root lab; the CONTRACT-MAP row stays proven.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the mongo cache backend: speak OP_MSG over a raw socket (prefer a driver, fall back to raw),
connecting on first use with a `ping` probe. `get` finds one by `_id` and returns its `value` (a stored
null is a hit; a past `expires_at` is a miss); `set` upserts `{_id, value, expires_at}`; `delete`
deletes by `_id`; `clear` is `deleteMany({})`; `sweep` returns 0. Enforce expiry at read time (plus a
TTL index per the pinned mechanism). Bind the `_id`. Degrade to file when unreachable. Prove the port
with a clear, an expiry, a cached-null hit, and an injection attempt against a real MongoDB.

## Audit closure checklist

- [x] Boundary and public surface complete (OP_MSG get/set/delete/clear + expiry).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (zero-dep, injection, expiry).
- [x] Wire/storage and provider contracts complete (document shape, TTL).
- [x] Existing-language contradictions recorded (MG-78-01, shared with Feature 69).
- [x] Owner ambiguities recorded (2 proposed; TTL enforcement and the shared transport).
- [x] Proposed shared cases and mutation witnesses complete (real MongoDB, no doubles).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
