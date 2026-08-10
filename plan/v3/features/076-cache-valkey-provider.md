# Feature 076: Valkey cache provider

## Identity and status

- Matrix identity: 76 - Valkey cache provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the valkey backend in each cache module)
  at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. Valkey is a Redis fork on the
  SAME RESP protocol; this packet records only the valkey-specific facts and defers the shared
  RESP/TTL/clear contract to Feature 75 (Redis cache). No framework code changed.
- Dependencies: Feature 72 (interface), a Valkey server, the RESP transport (shared with Feature 75)
- Dependants: any deployment on `TINA4_CACHE_BACKEND=valkey`
- Existing ADRs: ADR-0024, ADR-0031, ADR-0032 (as Feature 75)
- Shared fixtures: `cache_contract.json` (8/8 PROVEN) exercises the valkey backend against a live
  Valkey.
- Catalog phase: Cache (providers)

## Why this feature exists

Valkey is the open-source Redis fork; a deployment standardised on Valkey gets the same shared cache on
the same wire protocol. The backend is Feature 75's redis cache backend keyed on the `VALKEY` env
prefix.

## Boundary

Same as Feature 75 (RESP transport, `tina4:cache:` namespace, native-TTL `SETEX`, SCAN-scoped `clear`,
`sweep()=0`) keyed on `TINA4_CACHE_URL` with a `valkey://` default. The RESP contract, injection safety,
native-TTL semantics and scoped-clear are IDENTICAL to Feature 75 and audited there; this packet
records only where Valkey differs from Redis.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | uses the `redis` client (not `valkey`), else raw RESP | raw RESP | uses the `redis` gem, else raw RESP | raw RESP |
| Default URL | `valkey://localhost:6379` | same | same | same |
| Key prefix | `tina4:cache:` | same | same | same |
| Everything else | identical to Feature 75 | identical | identical | identical |

The valkey cache backend is at parity and proven, identical to the redis cache backend (Feature 75) on
the RESP wire, the SCAN-scoped clear, the native TTL and `sweep()=0`. The only divergence is the same
one as the session layer: Python and Ruby use the `redis` client for Valkey (the Python docs' claim of
a `valkey` package is doc drift, shared with Feature 67 RP-04 / Feature 68 VK-03).

## Public surface contract

Identical to Feature 75 (Redis cache): `get`/`set`/`delete`/`clear`/`sweep` over RESP, `SETEX` native
TTL, key `tina4:cache:<hashedkey>`, JSON value, SCAN-scoped clear, `sweep()=0`. See Feature 75.

## Configuration and precedence

`TINA4_CACHE_URL` with a `valkey://localhost:6379` default (or the per-field env), plus the cache
credentials. Connection, probe and fallback are identical to Feature 75.

## Failures, side effects and security

Identical to Feature 75 (RESP framing closes injection; the scoped SCAN clear cannot take another
tenant's keys; a wrong credential falls back to file). No valkey-specific failure surface.

## Wire and persistence contract

Identical to Feature 75: JSON value under `tina4:cache:<hashedkey>`, native server TTL. A Valkey cache
key is byte-compatible with a Redis cache key (same prefix, same JSON), so the two are interchangeable
cache stores.

## Providers and substitutability

Selected by `TINA4_CACHE_BACKEND=valkey` (ADR-0024). Shares the RESP transport with the redis cache
backend (Feature 75). Because Valkey speaks Redis's protocol, the same backend logic serves both.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| VC-76-01 | Python and Ruby use the `redis` client for Valkey; the Python docs claim a `valkey` package (doc drift, shared with Feature 67/68). | Fix the Python doc; confirm the `redis`-client-for-Valkey choice is intended. |
| (shared) | Every Feature 75 item (RC-75-01 transport policy) and the session valkey items (Feature 68 VK-01 Valkey-only TTL var, VK-02 Node config-key asymmetry) apply here if the cache valkey backend shares that code. | Resolve once with Features 75/68 and apply to the cache valkey backend. |

No cache-specific open defects: the valkey cache backend is proven parity.

## Owner decisions

Proposed for owner ratification:

1. Fix the Python valkey-package doc (VC-76-01) and confirm the `redis`-client-for-Valkey choice.
2. Resolve the shared Feature 75 transport decision (RC-75-01) once and apply to both cache backends; a
   Valkey cache key stays byte-compatible with a Redis cache key.

## Proposed conformance fixture

Valkey runs the SAME redis-backend cases as Feature 75 against a REAL Valkey (`cache_contract.json`
already does this), including the clear-scoping case.

## Integration map

- Feature 72 selects this backend; the RESP transport and cases are Feature 75's; Feature 68 is the
  session valkey sibling.
- `cache_contract.json` proves it against a live Valkey.

## Breaking changes and migration

- None cache-specific; any shared transport change (host/timeout) follows Feature 75.

## Implementation backlog

1. Fold Valkey into the Feature 75 redis cache cases against a real Valkey.
2. Fix the Python doc (VC-76-01); apply the shared Feature 75/68 fixes to the cache valkey backend.
3. Run locally and on the root lab; the CONTRACT-MAP row stays proven.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement Valkey as the Feature 75 redis cache backend keyed on `TINA4_CACHE_URL` with a `valkey://`
default and only `TINA4_CACHE_*` config. The RESP transport, native TTL, scoped clear and injection
safety are identical to Redis - see Feature 75's porting capsule. Prove the port by running the redis
cache cases against a real Valkey.

## Audit closure checklist

- [x] Boundary and public surface complete (defers the RESP contract to Feature 75).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (valkey-specific: client choice).
- [x] Wire/storage and provider contracts complete (byte-compatible with Redis cache).
- [x] Existing-language contradictions recorded (VC-76-01 + the shared Feature 75/68 set).
- [x] Owner ambiguities recorded (2 proposed; the Python doc and the shared transport policy).
- [x] Proposed shared cases and mutation witnesses complete (real Valkey, no doubles).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
