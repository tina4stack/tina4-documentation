# Feature 084: Redis WebSocket backplane

## Identity and status

- Matrix identity: 84 - Redis WebSocket backplane
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 alongside feature 083 at Python `386cd6d`,
  PHP `743b7469`, Ruby `c61250c`, Node `26be920` (WS source byte-identical to `v3`). No framework code
  changed.
- Dependencies: feature 083 (the WebSocket server owns the broadcast path, the envelope shape and the
  local-first-then-publish contract; this feature is only the REDIS TRANSPORT that carries the
  envelope between instances)
- Dependants: any multi-instance deployment that needs a broadcast on instance A to reach a client
  connected to instance B
- Existing ADRs: none. Governed by the WS security/contract ADR proposed in feature 083, and by the
  zero-dependency principle (the reason WS-03 matters).
- Shared fixtures: NONE. Covered by the proposed `websocket_contract.json` (feature 083, WS-08) via a
  two-instance relay case; there is no separate backplane fixture.
- Catalog phase: Integration providers

## Why this feature exists

A single WebSocket server only reaches the clients connected to it. Behind a load balancer, a broadcast
must fan out across every instance. The Redis backplane carries each broadcast as a small JSON envelope
over a Redis pub/sub channel: instance A publishes, every sibling relays it to its own local
connections. It is a PROVIDER, never a hard dependency - unconfigured, the server stays local-only;
configured and unreachable, a broadcast degrades to local-only rather than failing.

## Boundary

This packet owns the REDIS TRANSPORT of the backplane: connecting to Redis (`TINA4_WS_BACKPLANE=redis`
+ `TINA4_WS_BACKPLANE_URL`), publishing the envelope to the shared channel, subscribing on a second
connection, and handing a received envelope to the server's local relay. The envelope SHAPE, the
origin-guard, the local-first ordering and the degrade-to-local policy belong to feature 083 (they are
identical across transports). The NATS transport is feature 085.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Selected by `TINA4_WS_BACKPLANE=redis` | yes | yes | yes | yes |
| `TINA4_WS_BACKPLANE_URL` (redis default) | `redis://localhost:6379` | `tcp://127.0.0.1:6379` | `redis://localhost:6379` | `redis://localhost:6379` |
| Publishes envelope to channel `tina4:ws` | yes | yes | yes | yes |
| Subscribes on a second connection, relays local-only | yes | yes | yes | yes |
| ZERO-DEP transport (no client library required) | NO (`redis` pkg) | YES (ext-redis OR raw RESP) | NO (`redis` gem) | NO (npm `redis`) |
| Lazy connect on first broadcast | yes | yes | yes | yes |
| Degrade to local-only on connect/publish failure | yes | yes | yes | yes |
| Origin-guard drops own echo by `src` | yes | yes | yes | yes |

The transport behaviour is at parity: same channel, same envelope, same lazy-connect and
degrade-to-local. The one hard divergence is the DEPENDENCY (WS-03): PHP carries Redis with no external
library, the other three require a client package.

## Public surface contract

The backplane is not an app-facing API; it is selected by env var and driven by the server's broadcast
path. The internal surface is a small provider: `create_backplane()` (a factory reading
`TINA4_WS_BACKPLANE`/`_URL`), `publish(envelope)` (send to `tina4:ws`), and a subscribe loop that calls
the server's local relay for each received envelope. An app substitutes transports by changing
`TINA4_WS_BACKPLANE` alone - the broadcast code above it does not change.

## Inputs and outputs

- Input (publish): the envelope `{src, kind, exclude, room, path, +text|b64}` built by feature 083,
  serialized to JSON.
- Output (publish): a Redis `PUBLISH tina4:ws <json>`.
- Input (subscribe): a message on `tina4:ws` from any instance (including self).
- Output (subscribe): after the origin-guard drops the instance's own `src`, the envelope is handed to
  the server's LOCAL relay (deliver to matching local connections by `kind` = all/path/room); the
  relay never re-publishes.

## Lifecycle and operation graph

1. SELECT: on the first broadcast, `create_backplane()` reads `TINA4_WS_BACKPLANE`; `redis` builds a
   `RedisBackplane` with `TINA4_WS_BACKPLANE_URL`.
2. CONNECT (lazy): open a publish connection and a separate subscribe connection; PHP prefers ext-redis
   and otherwise opens a raw socket and completes a RESP `PING` handshake.
3. SUBSCRIBE: the subscribe connection listens on `tina4:ws`; each message runs the origin-guard, then
   the local relay.
4. PUBLISH: each `broadcast`/`broadcast_all`/`broadcast_to_room` delivers locally first, then publishes
   the envelope.
5. DEGRADE: a connect or publish failure logs once and drops to local-only for the rest of the process
   life (the server keeps serving; broadcasts just do not cross instances).

## Configuration and precedence

- `TINA4_WS_BACKPLANE=redis` selects this transport. Unset = no backplane (local-only). Any value that
  is not `redis`/`nats` RAISES at selection (a typo fails loud, it does not silently disable scale-out).
- `TINA4_WS_BACKPLANE_URL` is the connection string; the redis default is `redis://localhost:6379`
  (PHP expresses the same default as `tcp://127.0.0.1:6379`). Credentials ride in the URL.
- There is no separate channel env var: the channel is the constant `tina4:ws` in all four (a shared
  constant is the point - every instance must publish and subscribe to the same name).

## Failures, side effects and security

- FAIL-SOFT is uniform: an unreachable Redis (wrong URL, service down, auth failure) logs and degrades
  to local-only. A broadcast never raises because the backplane is down - the local fan-out (feature
  083) always runs first and is never gated on the publish.
- ORIGIN-GUARD prevents a broadcast loop: every envelope carries the publisher's instance `src`, and a
  subscriber drops a message whose `src` is its own before relaying; the relay delivers to local
  connections only and never re-publishes. Without this a two-node cluster would echo forever.
- DEPENDENCY POSTURE is the security-adjacent point (WS-03): PHP honours the zero-dependency promise
  (raw RESP over a socket, ext-redis only as an optimisation), so a PHP app scales WebSocket broadcast
  with NO added supply-chain surface. Python/Ruby/Node pull a Redis client library for the same job,
  even though the framework already speaks raw RESP in its session and cache layers. The library is not
  a security hole, but it is an avoidable dependency the house style says to avoid.
- The envelope carries message payloads over Redis: a shared Redis is trusted infrastructure (same as a
  shared session/cache store). No auth token or session cookie rides in the envelope - only the
  broadcast payload, `src`, and routing fields.

## Wire and persistence contract

No persistence (pub/sub is fire-and-forget; an instance that is down misses broadcasts sent while it
was down - this is a broadcast bus, not a message queue). The wire contract is `PUBLISH tina4:ws
<json>` where `<json>` is the feature-083 envelope. PHP's raw-RESP path speaks the standard Redis
protocol (`*3\r\n$7\r\nPUBLISH\r\n...`), so it interoperates with the library-backed instances on the
same channel - a mixed PHP+Node cluster shares one `tina4:ws` correctly.

## Providers and substitutability

Redis is one of two transports behind the `TINA4_WS_BACKPLANE` selector; NATS (feature 085) is the
other, and unset is local-only. All three are chosen by the one env var with no code change above the
seam. The proposed WS-03 fix makes the Redis transport itself substitutable between a raw-RESP client
and a library client WITHOUT changing behaviour - the raw-RESP client (already proven in the session/
cache layer) becomes the default, matching PHP.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| WS-03 | The Redis transport is ZERO-DEP in PHP (ext-redis when present, else a hand-rolled raw-RESP client over a socket with a real PING handshake) but requires a client library in Python (`redis`), Ruby (`redis` gem) and Node (npm `redis`). The framework already speaks raw RESP in its session/cache backends, so the library is avoidable. | Python/Ruby/Node reuse the existing zero-dep RESP client for the WS Redis backplane, matching PHP. Behaviour is unchanged (same channel, envelope, degrade-to-local); only the dependency drops. |
| WS-08 (shared) | No executable oracle proves the two-instance relay (a broadcast on A reaching a client on B, exactly once, no echo). | The `websocket_contract.json` relay case (feature 083) runs two instances against a real Redis and asserts single delivery + no loop. No mocks - a real Redis, per the no-mock rule. |

## Owner decisions

Proposed for owner ratification:

1. ZERO-DEP REDIS TRANSPORT (WS-03): Python, Ruby and Node back the WS Redis backplane with the
   framework's existing raw-RESP client (the one already used by sessions/cache), dropping the Redis
   client library. PHP is the reference. This is a dependency decision, not a behaviour change.
2. RELAY FIXTURE (WS-08, shared with 083): prove the two-instance relay against a real Redis in
   `websocket_contract.json`.

## Proposed conformance fixture

Covered by `websocket_contract.json` (feature 083). The Redis-specific case: start two server instances
both configured `TINA4_WS_BACKPLANE=redis` against ONE real Redis; connect a client to instance B;
`broadcast` on instance A; assert the client on B receives the message EXACTLY once (relay works) and
that instance A does NOT receive its own echo (origin-guard). A second case points
`TINA4_WS_BACKPLANE_URL` at a dead Redis and asserts the broadcast still reaches instance A's local
client (degrade-to-local) and logs the failure. Real Redis only - no fake pub/sub.

## Integration map

- Selected by `TINA4_WS_BACKPLANE`/`_URL`; driven by feature 083's broadcast path (local-first, then
  `publish`); relays back through feature 083's local relay.
- Shares the channel `tina4:ws` and the envelope with feature 085 (NATS) - the two transports are
  interchangeable on the same envelope.
- The WS-03 fix reuses the session/cache raw-RESP client (features 067/075) - the SAME zero-dep RESP
  code path, extended to pub/sub.
- `websocket_contract.json` (owed) proves the relay.

## Breaking changes and migration

- WS-03 removes the Redis client library as a requirement in Python/Ruby/Node: PURELY additive for a
  running app (the same env vars, the same behaviour, one fewer install). A deployment that pinned the
  library keeps working; a new deployment needs nothing extra. No client-visible change.
- No wire change: the raw-RESP client publishes the identical `PUBLISH tina4:ws <json>`, so a mixed
  cluster (some instances library-backed, some raw) interoperates during a rollout.

## Implementation backlog

1. Python/Ruby/Node: extend the existing zero-dep RESP client (sessions/cache) to pub/sub
   (`SUBSCRIBE`/`PUBLISH` + the message-read loop) and back the WS Redis backplane with it (WS-03).
2. Add the two-instance relay + degrade-to-local cases to `websocket_contract.json` against a real
   Redis (WS-08).
3. Run locally and on the root lab with a live Redis, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the Redis transport as a provider behind `TINA4_WS_BACKPLANE=redis`: on first broadcast, lazily
open a publish connection and a separate subscribe connection to `TINA4_WS_BACKPLANE_URL` (default
`redis://localhost:6379`); prefer a native extension if present, else speak raw RESP over a socket
(`PING` handshake, then `SUBSCRIBE tina4:ws` and `PUBLISH tina4:ws <json>`) so NO client library is
required. Publish the feature-083 envelope after the local fan-out; on each received message, drop the
own-`src` echo (origin-guard) and hand it to the local relay (never re-publish). On any connect/publish
failure, log once and degrade to local-only. Prove it with the two-instance relay case (a broadcast on
A reaches a client on B exactly once, no echo) and the dead-Redis degrade case, both against a real
Redis.

## Audit closure checklist

- [x] Boundary and public surface complete (the Redis transport; envelope/ordering belong to 083).
- [x] Lifecycle and every producer/consumer edge complete (select/connect/subscribe/publish/degrade).
- [x] Configuration, failure, side-effect and security rules complete (fail-soft, origin-guard, dep posture).
- [x] Wire/storage and provider contracts complete (`PUBLISH tina4:ws <json>`; raw RESP interoperates).
- [x] Existing-language contradictions recorded (WS-03 dependency asymmetry; PHP is zero-dep).
- [x] Owner ambiguities recorded (2 proposed; the zero-dep reuse is the key call).
- [x] Proposed shared cases and mutation witnesses complete (two-instance relay + degrade, real Redis).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
