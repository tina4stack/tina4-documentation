# Feature 085: NATS WebSocket backplane

## Identity and status

- Matrix identity: 85 - NATS WebSocket backplane
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 alongside features 083/084 at Python
  `386cd6d`, PHP `743b7469`, Ruby `c61250c`, Node `26be920` (WS source byte-identical to `v3`). No
  framework code changed.
- Dependencies: feature 083 (the WebSocket server owns the broadcast path, the envelope shape and the
  local-first-then-publish contract; this feature is only the NATS TRANSPORT that carries the envelope)
- Dependants: a multi-instance deployment that already runs NATS and prefers it over Redis for the
  broadcast bus
- Existing ADRs: none. Governed by the WS contract ADR proposed in feature 083.
- Shared fixtures: NONE. Covered by the proposed `websocket_contract.json` (feature 083, WS-08) via a
  two-instance relay case run against a real NATS.
- Catalog phase: Integration providers

## Why this feature exists

Some deployments standardise on NATS, not Redis, for pub/sub. The NATS backplane gives them the same
cross-instance broadcast fan-out as feature 084 over their existing bus: publish the envelope on a NATS
subject, every sibling relays it to its local connections. Like the Redis transport, it is a PROVIDER -
unconfigured the server is local-only, and configured-but-unreachable degrades to local-only.

## Boundary

This packet owns the NATS TRANSPORT of the backplane: connecting to NATS (`TINA4_WS_BACKPLANE=nats` +
`TINA4_WS_BACKPLANE_URL`), publishing the envelope on the shared subject, subscribing, and handing a
received envelope to the server's local relay. The envelope shape, origin-guard, ordering and
degrade-to-local policy belong to feature 083; the Redis transport is feature 084.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Selected by `TINA4_WS_BACKPLANE=nats` | yes | yes | yes | yes |
| `TINA4_WS_BACKPLANE_URL` (nats default) | `nats://localhost:4222` | `nats://localhost:4222` | `nats://localhost:4222` | `nats://localhost:4222` |
| Publishes envelope to subject `tina4:ws` | yes | yes | yes | yes |
| Subscribes, relays local-only | yes | yes | yes | yes |
| Transport library (NATS is a full wire protocol) | `nats-py` | `basis-company/nats` | `nats-pure` | npm `nats` |
| Lazy connect on first broadcast | yes | yes | yes | yes |
| Degrade to local-only on connect/publish failure | yes | yes | yes | yes |
| Origin-guard drops own echo by `src` | yes | yes | yes | yes |

Unlike Redis (where PHP is zero-dep and the other three carry a library - WS-03), the NATS transport is
LIBRARY-BACKED in ALL FOUR. That is the convergent, defensible position: the NATS protocol (CONNECT/
PUB/SUB/MSG with the server INFO negotiation) is a genuine wire protocol, and a vetted client is the
lean choice over hand-rolling it - the same reasoning the framework applies to database drivers.

## Public surface contract

Not app-facing. The internal surface mirrors feature 084: `create_backplane()` builds a `NATSBackplane`
when `TINA4_WS_BACKPLANE=nats`, `publish(envelope)` sends on the subject, and a subscribe callback runs
the server's local relay. An app switches to NATS by setting `TINA4_WS_BACKPLANE=nats` - no code change
above the seam.

## Inputs and outputs

- Input (publish): the feature-083 envelope `{src, kind, exclude, room, path, +text|b64}`, serialized
  to JSON.
- Output (publish): a NATS `PUB tina4:ws <json>`.
- Input (subscribe): a `MSG` on `tina4:ws` from any instance.
- Output (subscribe): the origin-guard drops the own-`src` echo, then the envelope is handed to the
  local relay (deliver by `kind`); the relay never re-publishes.

## Lifecycle and operation graph

1. SELECT: on the first broadcast, `create_backplane()` reads `TINA4_WS_BACKPLANE`; `nats` builds a
   `NATSBackplane` with `TINA4_WS_BACKPLANE_URL`.
2. CONNECT (lazy): the client connects to NATS (protocol negotiation via the server INFO), throwing at
   construction if the library is absent - caught by the degrade path.
3. SUBSCRIBE: subscribe to `tina4:ws`; each `MSG` runs the origin-guard then the local relay.
4. PUBLISH: each broadcast delivers locally first, then publishes on the subject.
5. DEGRADE: a missing library or an unreachable server logs once and drops to local-only for the
   process life.

## Configuration and precedence

- `TINA4_WS_BACKPLANE=nats` selects this transport. Unset = local-only. A value that is not
  `redis`/`nats` RAISES at selection (a typo fails loud).
- `TINA4_WS_BACKPLANE_URL` is the connection string; the nats default is `nats://localhost:4222` in all
  four. Credentials/tokens ride in the URL per the client library.
- The subject is the constant `tina4:ws`, shared with the Redis transport's channel name - one bus name
  across transports.

## Failures, side effects and security

- FAIL-SOFT is uniform: a missing NATS client library or an unreachable server logs and degrades to
  local-only; a broadcast never raises. This matters MORE for NATS than Redis because the library is
  required in every language - a deployment that sets `TINA4_WS_BACKPLANE=nats` without installing the
  client gets local-only delivery plus a clear log line, not a crash.
- ORIGIN-GUARD is identical to feature 084: the `src` field drops the own echo; the relay is local-only
  and never re-publishes, so no cluster loop.
- DEPENDENCY POSTURE (WS-03 contrast): NATS being library-backed in all four is DELIBERATE and correct
  under the house rule that a real wire protocol is the one place a vetted library beats a hand-roll.
  It is the single optional third-party dependency in the WebSocket subsystem, and it is opt-in (only
  loaded when `TINA4_WS_BACKPLANE=nats`). Redis, by contrast, CAN and SHOULD be zero-dep (feature 084,
  WS-03), because RESP is simple and the framework already speaks it.
- The envelope carries broadcast payloads over NATS: trusted infrastructure, same as Redis. No auth
  token or session cookie rides in the envelope.

## Wire and persistence contract

No persistence (core NATS pub/sub is fire-and-forget; JetStream is not used - an instance down during a
broadcast misses it). The wire contract is a NATS `PUB tina4:ws <json>` with the feature-083 envelope,
and a `SUB tina4:ws` delivering `MSG`. The subject name and envelope are shared with feature 084, so
the CHOICE of transport is a deployment decision, not a protocol difference at the envelope layer.

## Providers and substitutability

NATS is the second of two transports behind `TINA4_WS_BACKPLANE`; Redis (feature 084) is the first, and
unset is local-only. The selector swaps them with one env var. The two transports are behaviourally
equivalent above the wire (same envelope, same origin-guard, same degrade-to-local), so an app moves
between Redis and NATS without touching broadcast code.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| WS-05-N | The NATS transport is library-backed in all four - this is CONVERGENT and defensible (a real wire protocol), not a divergence to fix. The only open item is that it is UNDOCUMENTED as the WebSocket subsystem's one optional dependency in three of the four CLAUDE.md files (Python names the Redis/NATS backplane; the optional-dep nature of the NATS client is implicit). | Document NATS as the single opt-in third-party dependency of the WS backplane in all four CLAUDE.md files (loaded only when `TINA4_WS_BACKPLANE=nats`); no code change. |
| WS-08 (shared) | No executable oracle proves the two-instance NATS relay. | The `websocket_contract.json` relay case (feature 083) runs two instances against a real NATS and asserts single delivery + no echo. No mocks - a real NATS server. |

Note: WS-03 (the Redis zero-dep divergence) is NOT restated as a NATS defect - NATS is correctly
library-backed everywhere. The contrast is the point: Redis should converge DOWN to zero-dep, NATS
stays library-backed.

## Owner decisions

Proposed for owner ratification:

1. NATS STAYS LIBRARY-BACKED (all four): ratify that the NATS transport uses a vetted client in every
   language (the wire-protocol exception to zero-dep), and DOCUMENT it as the WS subsystem's one opt-in
   third-party dependency, loaded only under `TINA4_WS_BACKPLANE=nats`.
2. RELAY FIXTURE (WS-08, shared with 083/084): prove the two-instance NATS relay against a real NATS in
   `websocket_contract.json`.

## Proposed conformance fixture

Covered by `websocket_contract.json` (feature 083). The NATS-specific case: start two server instances
configured `TINA4_WS_BACKPLANE=nats` against ONE real NATS server; connect a client to instance B;
`broadcast` on instance A; assert the client on B receives the message exactly once and instance A gets
no echo. A second case sets `TINA4_WS_BACKPLANE=nats` with the client library absent (or a dead server)
and asserts the broadcast still reaches instance A's local client (degrade-to-local) with a clear log.
Real NATS only - no fake subject bus.

## Integration map

- Selected by `TINA4_WS_BACKPLANE=nats`/`_URL`; driven by feature 083's broadcast path; relays through
  feature 083's local relay.
- Shares the subject `tina4:ws` and the envelope with feature 084 (Redis) - transports are
  interchangeable at the envelope layer.
- The NATS client library is the WS subsystem's one optional dependency (opt-in); documenting it is the
  WS-05-N action.
- `websocket_contract.json` (owed) proves the relay.

## Breaking changes and migration

- None. NATS support is unchanged by this audit; the only action is a doc addition (WS-05-N) naming the
  optional client, and the shared fixture (WS-08). No wire, env or behaviour change.

## Implementation backlog

1. Document NATS as the WS backplane's one opt-in third-party dependency in all four CLAUDE.md files
   (WS-05-N).
2. Add the two-instance NATS relay + degrade-to-local cases to `websocket_contract.json` against a real
   NATS server (WS-08).
3. Run locally and on the root lab with a live NATS, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the NATS transport as a provider behind `TINA4_WS_BACKPLANE=nats`: on first broadcast, lazily
connect a vetted NATS client to `TINA4_WS_BACKPLANE_URL` (default `nats://localhost:4222`), `SUB
tina4:ws`, and `PUB tina4:ws <json>` for each broadcast after the local fan-out. Drop the own-`src`
echo (origin-guard) and hand a received `MSG` to the local relay (never re-publish). A missing client
library or an unreachable server logs once and degrades to local-only. Use a real client library (the
NATS protocol is a genuine wire protocol - do not hand-roll it), and load it only when this transport is
selected. Prove it with the two-instance relay case and the degrade case against a real NATS server.

## Audit closure checklist

- [x] Boundary and public surface complete (the NATS transport; envelope/ordering belong to 083).
- [x] Lifecycle and every producer/consumer edge complete (select/connect/subscribe/publish/degrade).
- [x] Configuration, failure, side-effect and security rules complete (fail-soft, origin-guard, dep posture).
- [x] Wire/storage and provider contracts complete (`PUB tina4:ws <json>`; subject shared with Redis).
- [x] Existing-language contradictions recorded (library-backed is convergent + defensible; WS-05-N is a doc gap).
- [x] Owner ambiguities recorded (2 proposed; ratify library-backed + document the opt-in dep).
- [x] Proposed shared cases and mutation witnesses complete (two-instance NATS relay + degrade, real NATS).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
