# Feature 075: Redis cache provider

## Identity and status

- Matrix identity: 75 - Redis cache provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the redis backend in each cache module) at
  Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: Feature 72 (interface + factory), a Redis server, the RESP transport (shared with the
  session redis provider, Feature 67)
- Dependants: any deployment on `TINA4_CACHE_BACKEND=redis` (or `TINA4_DB_CACHE_BACKEND=redis`) - the
  usual choice for a cross-instance shared cache
- Existing ADRs: ADR-0024 (interface), ADR-0031 (redis invalidates by SCAN), ADR-0032 (server-expiring
  sweep returns 0)
- Shared fixtures: `cache_contract.json` (8/8 PROVEN) exercises the redis backend against a live Redis.
- Catalog phase: Cache (providers)

## Why this feature exists

A multi-instance deployment needs one shared cache; Redis is the usual choice. The backend speaks RESP
over a raw socket (no client library required), stores each entry under a prefixed key with a native
server TTL, and invalidates by a prefix-scoped SCAN so `clear()` never touches another tenant's keys.

## Boundary

This feature owns the redis cache backend's `get`/`set`/`delete`/`clear`/`available?`: the RESP
transport, the `tina4:cache:` key namespace, the native-TTL `SETEX`, and the SCAN-scoped `clear`. It
DELEGATES selection and fallback to Feature 72. It shares the RESP transport with the session redis
provider (Feature 67); Valkey (Feature 76) is the same protocol.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | optional `redis` client, else raw RESP | raw RESP | optional gem, else raw RESP | raw RESP |
| Key prefix | `tina4:cache:` | same | same | same |
| Write | `SETEX` (native seconds TTL) | same | same | same |
| `clear()` | SCAN + DEL (prefix-scoped) | same | same | same |
| The raw-RESP `clear()` no-op | FIXED | FIXED | FIXED | FIXED |
| `sweep()` | 0 (server-expiring, honest) | 0 | 0 | 0 |
| Cached null (JSON `"null"`) | HIT | HIT | HIT | HIT |
| Injection (RESP bulk strings) | safe | safe | safe | safe |

The redis cache backend is at parity and proven. The historically-notorious defect - the raw-RESP
`clear()` being a literal no-op on the zero-dependency default install - is FIXED in all four (now a
prefix-scoped SCAN+DEL). `sweep()` returns 0 honestly because Redis expires server-side (ADR-0032).

## Public surface contract

`get(key) -> value | miss` (`GET tina4:cache:<hashedkey>`, JSON-decode; a stored `"null"` is a HIT, a
raw nil is a miss); `set(key, value, ttl)` (`SETEX <key> <ttl> <json>`, native server expiry);
`delete(key)` (`DEL`); `clear()` (SCAN `MATCH tina4:cache:*` then DEL the batch, never FLUSHALL);
`sweep() -> 0`. The value is a JSON string; the expiry is the server's.

## Configuration and precedence

`TINA4_CACHE_URL` (default `redis://localhost:6379`) or the per-field env, plus `TINA4_CACHE_USERNAME`/
`_PASSWORD`. The connection opens on first use with a real AUTH+PING probe (`available?`), and a wrong
credential or unreachable server falls back to the file backend (Feature 72). Key prefix
`tina4:cache:` (distinct from the session `tina4:session:` prefix, so cache and session entries never
collide on a shared Redis).

## Failures, side effects and security

- ZERO-DEP: the raw-RESP path needs no client library (shared with Feature 67); `cache_contract.json`
  proves it against a live Redis.
- INJECTION is closed: RESP length-prefixed bulk strings; a key can never inject a command.
- CLEAR IS SCOPED (ADR-0031): `clear()` is a prefix-scoped SCAN+DEL, never `FLUSHALL`/`FLUSHDB`, so it
  cannot take another application's or the session store's keys with it. This is the fix for the
  historical raw-RESP no-op.
- SERVER-EXPIRING: `sweep()` returns 0 honestly; expiry is `SETEX`'s, so there is nothing for the
  client to reclaim (ADR-0032).
- FALLBACK: an unreachable Redis degrades to file at selection time (Feature 72); a mid-life death is
  silent (Feature 72 CI-02, shared).

## Wire and persistence contract

The value is a JSON string under `tina4:cache:<hashedkey>`, expiry held by Redis (`SETEX`/`EXPIRE`).
The observable contract: a cached value is gone after its TTL, a `clear()` removes every
`tina4:cache:*` key (and nothing else), and a stored null round-trips. A cache key never collides with
a session key (different prefix).

## Providers and substitutability

The redis cache backend is selected by `TINA4_CACHE_BACKEND=redis` (ADR-0024). It shares the RESP
transport with the session redis provider (Feature 67) and Valkey (Feature 76). A cross-instance
deployment uses it (or Valkey) for a shared cache.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RC-75-01 | The connect timeout / default host divergences noted for the SESSION redis provider (Feature 67 RP-02/RP-03: 10/10/5/2s; `127.0.0.1` vs `localhost`) apply to the cache redis backend's transport too if it shares the same transport code. | Confirm the cache redis backend inherits the session redis transport fixes (one connect timeout, one default host); resolve together with Feature 67. |

No cache-specific open defects: the redis cache backend is proven parity (the raw-RESP clear no-op is
fixed, sweep=0 is honest, injection is closed).

## Owner decisions

Proposed for owner ratification:

1. Confirm the cache redis backend inherits the Feature 67 transport decisions (connect timeout,
   default host) - one RESP transport policy across cache and session redis (RC-75-01).

The redis cache backend is otherwise proven parity - no cache-specific decisions.

## Proposed conformance fixture

`cache_contract.json` already gates the redis backend for every invariant against a live Redis. Add one
scoping case: a `clear()` on the cache prefix leaves `tina4:session:*` keys (and any unrelated key)
untouched, proving the SCAN scope (over a real Redis holding both).

## Integration map

- Feature 72 selects and probes this backend; Feature 67 is the session redis sibling sharing the RESP
  transport; Feature 76 is Valkey.
- `cache_contract.json` proves it against a live Redis; the scoping case is added there.

## Breaking changes and migration

- Inheriting the Feature 67 transport fixes (connect timeout / host) is a config change; a deployment
  relying on the old value adjusts its env. No cache data breaks.

## Implementation backlog

1. Confirm the cache redis backend shares the session redis transport; resolve RC-75-01 with Feature 67.
2. Add the clear-scoping case to `cache_contract.json`.
3. Run locally and on the root lab; the CONTRACT-MAP row stays proven.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the redis cache backend: speak RESP over a raw socket (prefer a client, fall back to raw),
connecting on first use with a real AUTH+PING probe. `get` is `GET tina4:cache:<key>` JSON-decoded (a
stored `"null"` is a hit); `set` is `SETEX <key> <ttl> <json>` (native server TTL); `delete` is `DEL`;
`clear` is a prefix-scoped SCAN+DEL, never FLUSHALL; `sweep` returns 0 (server-expiring). Degrade to
file when unreachable. Prove the port with a native-TTL expiry, a scoped clear that spares other keys,
a cached-null hit, and a degrade.

## Audit closure checklist

- [x] Boundary and public surface complete (RESP get/set/delete/clear + native TTL + SCAN clear).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (zero-dep, injection, scoped clear).
- [x] Wire/storage and provider contracts complete (JSON value, native TTL, prefix).
- [x] Existing-language contradictions recorded (RC-75-01; the raw-RESP clear no-op is FIXED).
- [x] Owner ambiguities recorded (1 proposed; inherit the Feature 67 transport policy).
- [x] Proposed shared cases and mutation witnesses complete (proven + clear-scoping, real Redis).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
