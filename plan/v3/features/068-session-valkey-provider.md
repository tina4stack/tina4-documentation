# Feature 068: Valkey session provider

## Identity and status

- Matrix identity: 68 - Valkey session provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the valkey session handler in each repo),
  at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. Valkey is a Redis fork speaking
  the SAME RESP protocol; this packet records only the valkey-specific facts and defers the shared
  RESP/connection/TTL contract to Feature 67 (Redis). No framework code changed.
- Dependencies: Feature 65 (lifecycle), a Valkey server, the RESP transport (shared with Feature 67)
- Dependants: any deployment setting `TINA4_SESSION_BACKEND=valkey`
- Existing ADRs: ADR-0021, ADR-0024, ADR-0027 (as Feature 67)
- Shared fixtures: `session_contract.json` PROVES the shared invariants against a live Valkey 8.
- Catalog phase: Sessions (providers)

## Why this feature exists

Valkey is the open-source Redis fork; a deployment that standardises on Valkey needs the same shared
session store Redis gives, on the same wire protocol. The handler is Feature 67's redis handler with a
`VALKEY` env-var prefix.

## Boundary

Same as Feature 67 (RESP transport, connection/AUTH, key namespace, native-TTL write, JSON) but keyed
on the `TINA4_SESSION_VALKEY_*` env vars. The RESP-protocol contract, the injection safety, the AUTH
handling, the native-TTL semantics and the degrade policy are IDENTICAL to Feature 67 and are audited
there; this packet records where Valkey differs from Redis.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | uses the `redis` client (not `valkey`), else raw RESP | raw RESP | uses the `redis` gem, else raw RESP | raw RESP (separate handler file) |
| Env prefix | `TINA4_SESSION_VALKEY_*` | same | same | same |
| Extra TTL var | - | - | `TINA4_SESSION_VALKEY_TTL` (overrides `TINA4_SESSION_TTL`) | - |
| Handler structure | parallel to redis | parallel | parallel | SEPARATE file; reads `config.host/port`, not the `redisHost/redisPort` keys |
| Key prefix | `tina4:session:` | same | same | same |

The RESP wire, connection, native TTL, injection safety and degrade are identical to Redis (Feature
67). Valkey adds three small divergences: Ruby's extra TTL var, Python/Ruby using the `redis` client
for Valkey, and Node's handler-config asymmetry.

## Public surface contract

Identical to Feature 67 (Redis): `read`/`write`/`destroy` over RESP, `SETEX` native TTL, key
`tina4:session:<id>`, JSON value. See Feature 67 for the full surface.

## Configuration and precedence

`TINA4_SESSION_VALKEY_HOST` (default `localhost`, Node `127.0.0.1`), `_PORT` (6379), `_PASSWORD`, `_DB`
(0), `_PREFIX` (`tina4:session:`), plus `TINA4_SESSION_TTL` (3600). Ruby ALSO reads
`TINA4_SESSION_VALKEY_TTL` (VK-01), overriding the shared TTL var for Valkey only - an asymmetry the
other three do not have.

## Failures, side effects and security

Identical to Feature 67 (RESP framing closes injection; AUTH skips a blank password; a transport
failure raises so Feature 65 degrades). The one structural note (VK-02): Node's Valkey handler is a
SEPARATE file reading `config.host`/`config.port`, whereas the Node Redis handler is inline and reads
`config.redisHost`/`config.redisPort`; passing a `{redisHost: ...}` config object configures Redis but
NOT Valkey. Same wire behaviour, divergent config plumbing.

## Wire and persistence contract

Identical to Feature 67 (Redis): JSON value under `tina4:session:<id>`, native server TTL. A Valkey
key is byte-compatible with a Redis key (same prefix, same JSON), so the two are interchangeable
stores.

## Providers and substitutability

The valkey backend is selected by `TINA4_SESSION_BACKEND=valkey` (ADR-0024). It shares the RESP
transport with Redis (67). Because Valkey speaks Redis's protocol, the same handler logic serves both;
the divergences below are the only places the two are not literally the same code.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| VK-01 | Ruby's Valkey handler reads a Valkey-only `TINA4_SESSION_VALKEY_TTL` override; the other three (and Ruby's own Redis handler) read only `TINA4_SESSION_TTL`. | Drop the Valkey-only TTL var (or add it uniformly to all backends and languages); one TTL var. |
| VK-02 | Node's Valkey handler reads `config.host`/`port` while its Redis handler (inline) reads `config.redisHost`/`redisPort`; a `{redisHost}` config configures Redis but not Valkey. | Unify the Node config-key shape across the Redis and Valkey handlers. |
| VK-03 | Python and Ruby use the `redis` client for Valkey; the Python docs claim a `valkey` package is needed (doc drift, shared with Feature 67 RP-04). | Fix the Python doc; confirm the `redis`-client-for-Valkey choice is intended. |
| (shared) | Every Feature 67 defect (RP-01 SET/SETEX never-expires, RP-02 connect timeout, RP-03 host, RP-05 Node handler TTL) applies to Valkey identically. | Resolve once with Feature 67 and apply to both handlers. |

## Owner decisions

Proposed for owner ratification:

1. ONE TTL VAR (VK-01): drop `TINA4_SESSION_VALKEY_TTL` so every backend and language reads
   `TINA4_SESSION_TTL` (Ruby converges).
2. UNIFY NODE CONFIG KEYS (VK-02): the Redis and Valkey handlers read the same config-key shape.
3. Resolve the shared Feature 67 decisions (RP-01..05) once and apply to both handlers; a Valkey key
   stays byte-compatible with a Redis key.

## Proposed conformance fixture

Valkey runs the SAME redis-backend cases as Feature 67 against a REAL Valkey (the session fixture
already does this), plus one asymmetry case: a config/env set the Redis way must configure the Valkey
handler identically (VK-02), and only `TINA4_SESSION_TTL` (not a Valkey-only var) governs the lifetime
(VK-01).

## Integration map

- Feature 65 calls this backend; the RESP transport and the shared cases are Feature 67's.
- `session_contract.json` proves the shared invariants against a live Valkey; the valkey-specific
  asymmetries above are added there.

## Breaking changes and migration

- Dropping `TINA4_SESSION_VALKEY_TTL` (VK-01) is `Breaking:` for a Ruby deployment that set it -
  migration: set `TINA4_SESSION_TTL` instead.
- Unifying the Node config keys (VK-02) is internal unless an app passed `{redisHost}` expecting it to
  configure Valkey (it never did).

## Implementation backlog

1. Fold Valkey into the Feature 67 redis fixture cases against a real Valkey.
2. Drop the Valkey-only TTL var (VK-01); unify Node config keys (VK-02); fix the Python doc (VK-03).
3. Apply the shared Feature 67 fixes (RP-01..05) to the Valkey handler.
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement Valkey as the Feature 67 redis backend keyed on `TINA4_SESSION_VALKEY_*`, reading only
`TINA4_SESSION_TTL` for the lifetime and the same config-key shape as the redis handler. The RESP
transport, native TTL, injection safety and degrade are identical to Redis - see Feature 67's porting
capsule. Prove the port by running the redis cases against a real Valkey plus the config-symmetry case.

## Audit closure checklist

- [x] Boundary and public surface complete (defers the RESP contract to Feature 67).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (valkey-specific asymmetries).
- [x] Wire/storage and provider contracts complete (byte-compatible with Redis).
- [x] Existing-language contradictions recorded (VK-01..03 + the shared Feature 67 set).
- [x] Owner ambiguities recorded (3 proposed; one-TTL-var and Node config unification).
- [x] Proposed shared cases and mutation witnesses complete (real Valkey, no doubles).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
