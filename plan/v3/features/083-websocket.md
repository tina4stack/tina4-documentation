# Feature 083: WebSocket protocol and server

## Identity and status

- Matrix identity: 83 - WebSocket protocol and server
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the WebSocket server + backplane in each
  repo) at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c`, Node `26be920`. The WS source on the
  in-flight `feature/csrf-fail-closed` branches is byte-identical to `v3` (verified: empty diff), so
  the SHAs above are the `v3` heads. No framework code changed in this audit.
- Dependencies: the auth layer (JWT `valid_token`/`Auth::validToken` for per-route auth on upgrade),
  the router (WS route registration + the `auth_required`/`secured` flag), the core HTTP server (the
  integrated upgrade path), the debug/log layer (resilient-broadcast pruning, degrade-to-local)
- Dependants: any app serving realtime connections; the realtime-collaboration control plane (calls/
  chat/files) mounts secured WS routes on top of this; the dev-reload channel (`/__dev_reload`) is a
  separate debug-only socket, NOT this feature
- Existing ADRs: none specific to WebSocket. This audit proposes the first (the WS security contract)
  plus the `websocket_contract.json` fixture. The security posture (origin allow-list, per-route auth,
  resource caps) follows the framework fail-closed convention.
- Shared fixtures: NONE. `websocket_contract.json` is owed (no fixture, no CONTRACT-MAP row). A prose
  spec exists at `plan/v3/14-WEBSOCKET-SPEC.md`, but no executable oracle drives the four runners.
- Catalog phase: Integrations

## Why this feature exists

An application needs realtime, bidirectional connections without a heavy dependency. Tina4 ships a
hand-rolled, ZERO-DEPENDENCY RFC 6455 WebSocket server (its own handshake, framing, masking, ping/pong
and close handling) in every language, with rooms, a resilient broadcast path, per-route JWT auth on
the upgrade, an origin allow-list, and an idle reaper. Broadcast scales across instances through a
pluggable backplane (Redis or NATS, features 084/085) that never becomes a hard dependency.

## Boundary

This packet owns the WebSocket PROTOCOL and SERVER: the RFC 6455 handshake (`compute_accept_key`), the
frame codec (opcodes, client-mask decode, fragmentation, ping/pong, close), the connection object and
its manager, the rooms API, the resilient local-first broadcast, per-route auth on the upgrade
(`ws_authorized`/`ws_token`), the origin allow-list, the idle reaper, and the resource caps. The
backplane ENVELOPE and the local-first-then-publish contract are described here (they are the seam the
broadcast path crosses); the TRANSPORTS that carry the envelope are features 084 (Redis) and 085
(NATS). The dev-reload socket (`/__dev_reload`) is a separate debug channel and is out of scope.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Hand-rolled zero-dep RFC 6455 (no `ws`/faye/driver) | yes | yes | yes | yes |
| Handshake: SHA-1(key+GUID) -> base64 -> 101 | yes | yes | yes | yes |
| Frame codec: opcodes, ping->pong, close | yes | yes | yes | yes |
| Fragmentation reassembly (OP_CONTINUATION) | yes | yes | NO | NO |
| Inbound binary (0x2) delivered | yes | yes | NO (dropped) | yes |
| Client-MASK enforced (unmasked -> close 1002) | no | no | no | no |
| Per-route JWT auth BEFORE accept (3 transports) | integrated only | every path | every path | every path |
| `conn.auth` = verified payload on a secured route | integrated only | yes | yes | yes |
| Origin allow-list (`TINA4_WS_ALLOWED_ORIGINS`, 403) | yes | yes | yes | yes |
| Idle reaper (`TINA4_WS_IDLE_TIMEOUT`, close 1001) | standalone only | every path | yes | standalone only |
| Frame-size cap (`TINA4_WS_MAX_FRAME_SIZE`) | yes | no | no | no |
| Connection cap (`TINA4_WS_MAX_CONNECTIONS`, 503) | yes | no | no | no |
| Resilient broadcast (prune dead, never abort rest) | yes | yes | yes | yes |
| Rooms: join/leave/broadcast/get/count | yes | yes | yes | yes |
| Send-to-one manager method | `send_to` | `sendTo` | `send_to` | `sendTo` |
| Backplane envelope + local-first + degrade-local | yes | yes | yes | yes |

The PROTOCOL core (handshake, ping/pong, close) and the SECURITY controls that EXIST are at strong
parity, but coverage is uneven: per-route auth and the idle reaper are wired on some upgrade paths and
not others (Python and Node each leave one path uncovered), fragmentation and binary handling are
missing in two languages, the client-mask requirement is enforced nowhere, and the two DoS caps
(frame-size, connection-count) exist only in Python.

## Public surface contract

- Registration: `Router.websocket(path, secured=False, handler)` (Ruby also `secure_websocket`; module
  convenience `websocket`/`secure_websocket`; Node `WsRouteRef.secure()`; PHP `Router::websocket(path,
  handler, secure=false)` + a `@secured` docblock). A route is PUBLIC by default; `secured` requires a
  valid JWT on the upgrade.
- Connection object (`WebSocketConnection`): `send`/`send_text` (one message to this socket),
  `send_json`, `broadcast`, `broadcast_to_room`, `join_room`, `leave_room`, `get_room_connections`,
  `close`, and a read-only `auth` (the verified JWT payload, else null).
- Manager (`WebSocketServer`/`WebSocket`/engine): `broadcast(message, exclude, path)`, `broadcast_all`,
  `send_to(conn_id, message)` (the send-to-ONE spelling; Node/PHP `sendTo`), `broadcast_to_room(room,
  message, exclude)`, `get_room_connections(room)`, `room_count(room)`, `get_client_rooms(id)`,
  `close(conn_id, code, reason)`.
- Helpers: `compute_accept_key(key)`, `ws_token(headers, query, subprotocol)` (extract a bearer token),
  `ws_authorized(route, headers, query, subprotocol) -> (payload, ok)` (the auth gate).

## Inputs and outputs

- Input: an HTTP upgrade request (`Upgrade: websocket`, `Sec-WebSocket-Key`, `Sec-WebSocket-Version:
  13`, optional `Origin`, optional bearer token via `Authorization`, the `bearer,<jwt>`
  subprotocol, or `?token=`). After the handshake: RFC 6455 frames (text 0x1, binary 0x2, close 0x8,
  ping 0x9, pong 0xA; client frames masked).
- Output: a `101 Switching Protocols` with the computed `Sec-WebSocket-Accept`, then framed messages
  (server frames are never masked). Rejections before accept: `400` (bad upgrade / missing key), `426`
  (wrong version), `403` (origin not allowed), `401` (secured route, missing/invalid token), `503`
  (Python only, connection cap reached).
- Broadcast output: the message is delivered to matching LOCAL connections first (a dead/slow client is
  logged and pruned, never aborting the rest), then an envelope is published to the backplane channel
  for sibling instances.

## Lifecycle and operation graph

1. UPGRADE: parse the request; reject a non-websocket upgrade (400) or wrong version (426).
2. ORIGIN: if `TINA4_WS_ALLOWED_ORIGINS` is set, reject a mismatched/missing `Origin` (403).
3. AUTH: for a `secured` route, run `ws_authorized` (a valid JWT via one of three transports); reject
   401 on failure; on success carry the verified payload to `conn.auth`. (Python: this step runs on the
   integrated server paths, NOT the standalone `WebSocketServer` - WS-01.)
4. CAPS: (Python only) reject 503 once `TINA4_WS_MAX_CONNECTIONS` is reached.
5. ACCEPT: compute the accept key, send 101, register the connection, fire `on_connect`.
6. FRAME LOOP: decode client frames (unmasking if masked), reassemble fragments (Python/PHP), answer a
   ping with a pong, tear down on close; stamp last-activity for the reaper.
7. BROADCAST: deliver local-first + resilient, then publish the envelope to the backplane (lazy start;
   a backplane failure degrades to local-only).
8. REAP: a background reaper closes connections idle past `TINA4_WS_IDLE_TIMEOUT` with 1001 (Python/Node
   only on the standalone server - WS-02).

## Configuration and precedence

| Env var | Default | Meaning | Present in |
| --- | --- | --- | --- |
| `TINA4_WS_ALLOWED_ORIGINS` | unset = allow all | comma-separated exact-origin allow-list; set -> 403 on mismatch/missing Origin | all four |
| `TINA4_WS_IDLE_TIMEOUT` | `0` (disabled) | seconds; reaper closes idle connections with 1001 | all four (wired everywhere only in PHP/Ruby - WS-02) |
| `TINA4_WS_MAX_FRAME_SIZE` | `1048576` (1 MiB) | inbound frame-size cap (DoS guard) | Python only - WS-07 |
| `TINA4_WS_MAX_CONNECTIONS` | `10000` | connection cap; 503 past it (fd-exhaustion guard) | Python only - WS-07 |
| `TINA4_WS_MAX_BACKLOG` | `1048576` | outbound slow-client socket-backlog cap; drop+close past it | Node only - WS-07 |
| `TINA4_WS_PORT` | `8080` | standalone-server listen port | PHP, Node (Python/Ruby use a constructor default) |
| `TINA4_WS_BACKPLANE` | unset = none | `redis` or `nats`; any other value RAISES | all four (features 084/085) |
| `TINA4_WS_BACKPLANE_URL` | redis `redis://localhost:6379`, nats `nats://localhost:4222` | backplane connection string | all four |

Precedence is simple: the origin allow-list and the caps read their env var once at the upgrade; unset
means "no restriction" for the allow-list and the framework default for the caps.

## Failures, side effects and security

- PER-ROUTE AUTH is the primary access control, and its coverage is uneven. PHP, Ruby and Node run
  `ws_authorized` on EVERY upgrade path and populate `conn.auth`. Python runs it on the core server's
  two integrated upgrade paths (`core/server.py:1052` and `:1256`, setting `conn.auth` at `:1071`/
  `:1282`) but NOT on the standalone `WebSocketServer` (`websocket/__init__.py:790-869` - the loop
  enforces the origin allow-list and the connection cap, computes the accept key and registers the
  socket, but never calls `ws_authorized`, so `conn.auth` stays `None` even on a `@secured` route).
  This is WS-01, a real security divergence, compounded by doc-drift: the Python CLAUDE.md still calls
  per-route WS auth "a deliberate follow-up ... the origin allow-list is the shipped control", which
  the integrated server contradicts.
- ORIGIN ALLOW-LIST is defended UNIFORMLY: `TINA4_WS_ALLOWED_ORIGINS` unset allows all (non-breaking);
  set rejects a mismatched or MISSING `Origin` with 403 on every upgrade path in all four.
- IDLE REAPER coverage is uneven (WS-02): PHP and Ruby run it on the served path; Python and Node wire
  it ONLY into the standalone server, and the integrated path that real apps run never stamps
  last-activity, so `TINA4_WS_IDLE_TIMEOUT` is inert there - a documented knob that does nothing.
- CLIENT-MASK is NOT enforced anywhere (WS-05): RFC 6455 5.1 requires the server to fail a connection
  that sends an unmasked client frame (close 1002). All four decode-if-masked and accept an unmasked
  frame; `CLOSE_PROTOCOL_ERROR`/`1002` is defined (PHP `WebSocket.php:31`, Node, Python) but never
  sent for this. Uniform, low-severity spec-conformance gap (real browsers always mask), but it should
  be closed together.
- RESOURCE CAPS are Python-only (WS-07): the inbound frame-size cap (`TINA4_WS_MAX_FRAME_SIZE`, an
  OOM guard against a giant declared payload) and the connection cap (`TINA4_WS_MAX_CONNECTIONS` -> 503,
  an fd-exhaustion guard) exist only in Python. PHP/Ruby/Node accept an unbounded frame and an
  unbounded connection count. This is the most material security-adjacent gap in the cluster.
- BROADCAST is RESILIENT in all four: a send to a dead or slow client is caught, logged and the client
  pruned, and the loop continues - one bad socket never aborts a fan-out.
- BACKPLANE is fail-soft: lazily started on first broadcast, and a wiring/publish failure logs and
  degrades to local-only delivery - a broadcast never crashes because Redis/NATS is down.

## Wire and persistence contract

There is no persistence. Two wire contracts:

1. RFC 6455 on the socket: the handshake (`Sec-WebSocket-Accept = base64(SHA1(key + "258EAFA5-E914-
   47DA-95CA-C5AB0DC85B11"))`, 101), then frames. Server frames are unmasked; client frames are
   masked (accepted-if-unmasked today - WS-05). Fragmentation via `OP_CONTINUATION` is reassembled in
   Python/PHP and unhandled in Node/Ruby (WS-04).
2. The backplane envelope (features 084/085): a JSON object `{src, kind, exclude, room, path, +text|b64}`
   published to the shared channel `tina4:ws`. `src` is the publishing instance id (origin-guard: a
   sibling drops its own echo); `kind` selects the fan-out (all/path/room); binary payloads ride as
   base64 in `b64`, text in `text`. A relaying sibling delivers to its LOCAL connections only and never
   re-publishes (no cluster loop). This envelope shape is uniform across all four.

## Providers and substitutability

The server is self-contained (no external WebSocket library in any language - Node uses `node:http`/
`crypto`/`net`, Ruby stdlib `socket`/`digest`/`base64`, Python asyncio + hashlib, PHP raw stream
sockets). The BROADCAST scale-out is the substitutable seam: the backplane is a provider chosen by
`TINA4_WS_BACKPLANE` (Redis feature 084, NATS feature 085, or none = local-only), selected the same way
as the session/cache providers. A handler is a plain callable, so an app substitutes its own
connection logic behind the same registration surface.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| WS-01 | SECURITY: Python's standalone `WebSocketServer` upgrade (`websocket/__init__.py:790-869`) does NOT enforce per-route `@secured` auth - `conn.auth` stays `None` and a secured handler runs unauthenticated (origin + connection-cap still apply). The integrated server paths DO enforce it (`core/server.py:1052`/`:1256`). PHP/Ruby/Node enforce on EVERY path. Plus doc-drift: Python CLAUDE.md calls WS auth "a deliberate follow-up". | Python wires `ws_authorized` into `handle_connection` so every upgrade path enforces `secured`; set `conn.auth`; fix the CLAUDE.md note. FIX PYTHON (do not mirror the gap). |
| WS-02 | Idle reaper (`TINA4_WS_IDLE_TIMEOUT`) is wired only into the STANDALONE server in Python and Node; the integrated path real apps run never stamps last-activity, so the knob is inert there. PHP/Ruby apply it on the served path. | Python and Node wire the reaper (and last-activity stamping) into the integrated path so the documented env var works where apps actually serve. |
| WS-03 | Backplane dep asymmetry (feeds 084): PHP's Redis backplane is ZERO-DEP (ext-redis when present, else a raw-RESP client over a socket with a PING handshake); Python/Ruby/Node require a client library (`redis`/`redis` gem/npm `redis`). The framework already speaks raw RESP in the session/cache layer. | Reuse the existing zero-dep RESP client for the WS Redis backplane in Python/Ruby/Node, matching PHP (see feature 084). NATS stays library-backed in all four (feature 085). |
| WS-04 | Fragmentation reassembly (`OP_CONTINUATION`) is ABSENT in Node (`websocket.ts`: constant defined, no case, `frame.fin` ignored) and Ruby (`websocket.rb:767`: FIN never read, no 0x0 branch) - a conformant client that fragments a large message produces corrupt/partial messages. Ruby also DROPS inbound binary (0x2) and always sends the text opcode (0x1). Python/PHP reassemble. | Node and Ruby reassemble continuation frames (buffer until FIN); Ruby handles the binary opcode inbound and outbound. Match the Python/PHP reference. FIX NODE + RUBY. |
| WS-05 | Client-MASK is not enforced in any framework: an unmasked client frame is accepted instead of failing the connection with 1002 (RFC 6455 5.1). `CLOSE_PROTOCOL_ERROR`/`1002` is defined but never sent for this. | All four close 1002 on an unmasked client frame. Uniform fix (low severity - browsers always mask - but it belongs in the fixture). |
| WS-06 | Surface asymmetry: `get_room_connections` returns client-ID STRINGS on the standalone manager but connection OBJECTS on the integrated manager, within BOTH PHP and Node; `roomCount` exists only on the standalone class in PHP. Python/Ruby return objects and expose `room_count` on the engine. | Standardise `get_room_connections` to return connection objects everywhere (presence rosters need the object; the id is on it); expose `room_count` on both managers. |
| WS-07 | SECURITY-ADJACENT: the inbound frame-size cap (`TINA4_WS_MAX_FRAME_SIZE`, OOM guard) and the connection cap (`TINA4_WS_MAX_CONNECTIONS` -> 503, fd-exhaustion guard) exist ONLY in Python. PHP/Ruby/Node accept an unbounded frame and unbounded connections. Node has an outbound `TINA4_WS_MAX_BACKLOG` the others lack. | PHP/Ruby/Node adopt Python's `TINA4_WS_MAX_FRAME_SIZE` + `TINA4_WS_MAX_CONNECTIONS`; consider `TINA4_WS_MAX_BACKLOG` cross-framework. Python is the master here. |
| WS-08 | No `websocket_contract.json`; no CONTRACT-MAP row; no ADR. The cluster is proven only per-framework and unevenly. A prose spec exists (`14-WEBSOCKET-SPEC.md`) but no executable oracle. | Add `websocket_contract.json` gating the handshake, per-route auth, origin allow-list, the reaper, resilient broadcast, rooms and the backplane envelope; add the first WS ADR ratifying the security contract. |

## Owner decisions

Proposed for owner ratification. The protocol core is settled parity; every open call is on the
SECURITY coverage or the framing completeness, and several are "fix the outlier, do not mirror":

1. AUTH ON EVERY UPGRADE PATH (WS-01, SECURITY): per-route `@secured` auth is enforced on every WS
   upgrade path in all four, `conn.auth` always carries the verified payload on a secured route. Python
   wires the standalone `WebSocketServer` and fixes its doc. This is the headline security decision.
2. IDLE REAPER ON THE SERVED PATH (WS-02): the reaper and last-activity stamping run on the integrated
   path in all four; Python and Node close the gap.
3. FRAGMENTATION + BINARY (WS-04): Node and Ruby reassemble `OP_CONTINUATION`; Ruby handles the binary
   opcode. Match Python/PHP.
4. CLIENT-MASK ENFORCEMENT (WS-05): all four close 1002 on an unmasked client frame.
5. RESOURCE CAPS (WS-07): PHP/Ruby/Node adopt `TINA4_WS_MAX_FRAME_SIZE` and `TINA4_WS_MAX_CONNECTIONS`
   (Python is the reference).
6. ROOM API (WS-06): `get_room_connections` returns connection objects; `room_count` on both managers.
7. BACKPLANE DEP (WS-03): reuse the zero-dep RESP client for the Redis backplane in Python/Ruby/Node
   (feature 084); NATS stays library-backed (feature 085).
8. FIXTURE + ADR (WS-08): add `websocket_contract.json` and the first WS ADR (next free number in
   `DECISIONS.md`) ratifying the security contract (auth-every-path, origin allow-list, mask
   enforcement, frame/connection caps, resilient broadcast, backplane envelope).

## Proposed conformance fixture

Add `websocket_contract.json` driving four runners against real sockets (no mocks - the WS suites
already use real sockets, see `WebSocketV3Test`'s socket conversion): the handshake computes the
canonical `Sec-WebSocket-Accept` and returns 101; a `secured` route rejects a missing/invalid token
with 401 on EVERY upgrade path and accepts a valid one (payload lands on `conn.auth`); an allow-list
set via `TINA4_WS_ALLOWED_ORIGINS` returns 403 for a mismatched and a MISSING Origin; an idle
connection past `TINA4_WS_IDLE_TIMEOUT` is closed 1001 on the served path; a fragmented text message
(two frames, FIN on the second) is reassembled to the whole message; an unmasked client frame is
closed 1002; a broadcast to three clients with one dead socket still reaches the other two; join/leave/
`broadcast_to_room` deliver only to room members; and a second instance sharing the backplane relays a
broadcast to its local connections once (origin-guard: no echo, no loop). The frame-size and
connection caps assert a 1 MiB-plus frame and the N+1th connection are refused.

## Integration map

- The router registers WS routes and carries the `secured`/`auth_required` flag; the core server's
  integrated upgrade path calls `ws_authorized` and stamps `conn.auth`; the auth layer verifies the JWT.
- The broadcast path crosses the backplane seam: local-first delivery, then `publish_envelope` to
  `tina4:ws`; a sibling's listener relays local-only (features 084/085 carry the envelope).
- `websocket_contract.json` (owed) is the shared oracle; the prose `14-WEBSOCKET-SPEC.md` is the
  human-readable companion and must match the fixture once written.
- The realtime-collaboration control plane mounts secured WS routes on this server; WS-01 affects it
  directly (a secured chat socket on the standalone server would not authenticate in Python).

## Breaking changes and migration

- WS-01 makes the Python standalone `WebSocketServer` enforce `@secured`: a deployment that ran a
  secured handler on the standalone server WITHOUT sending a token starts getting 401. That is the
  point (it was unauthenticated). `Breaking:` for such a Python deployment - migration: send the token
  (Authorization bearer, the `bearer,<jwt>` subprotocol, or `?token=`), the same as the integrated path.
- WS-05 (mask enforcement) rejects a non-conformant client that sent unmasked frames. Real browsers
  mask, so no browser client breaks; a hand-rolled client that omitted masking must mask. `Breaking:`
  only for a non-conformant client.
- WS-07 caps refuse an over-large frame / an over-cap connection in PHP/Ruby/Node: additive protection;
  a deployment relying on unbounded frames raises the cap via the env var.
- WS-04, WS-02, WS-06 are additive (reassembly, reaper coverage, a uniform return type) - no
  conformant client breaks.

## Implementation backlog

1. Add `websocket_contract.json` and wire four real-socket runners (WS-08); add the first WS ADR.
2. Python: enforce auth on the standalone path and fix the doc (WS-01); wire the reaper into the
   integrated path (WS-02, shared with Node).
3. Node + Ruby: reassemble continuation frames, Ruby binary opcode (WS-04); Node reaper on the
   integrated path (WS-02).
4. All four: enforce the client mask -> 1002 (WS-05); PHP/Ruby/Node adopt the frame-size + connection
   caps (WS-07); standardise `get_room_connections` return type (WS-06).
5. Redis backplane zero-dep reuse in Python/Ruby/Node (WS-03, feature 084); run locally and on the root
   lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a zero-dependency RFC 6455 server: a handshake computing `Sec-WebSocket-Accept =
base64(SHA1(Sec-WebSocket-Key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))` returning 101; a frame codec
handling text/binary/close/ping/pong, unmasking client frames (and FAILING an unmasked client frame
with close 1002), and reassembling `OP_CONTINUATION` fragments until FIN; a connection object with
`send`/`send_json`/`broadcast`/`broadcast_to_room`/`join_room`/`leave_room`/`close` and a read-only
`auth`; a manager with `broadcast(message, exclude, path)`, `send_to(id, message)`, `broadcast_to_room`,
`get_room_connections` (returning connection objects), `room_count` and `close`. On upgrade, enforce IN
ORDER: origin allow-list (`TINA4_WS_ALLOWED_ORIGINS`, 403), per-route JWT auth for a `secured` route
(`ws_authorized` over three transports - Authorization bearer, the `bearer,<jwt>` subprotocol, and
`?token=` - 401 on failure, payload to `conn.auth`) on EVERY upgrade path, the connection cap
(`TINA4_WS_MAX_CONNECTIONS`, 503) and the frame-size cap (`TINA4_WS_MAX_FRAME_SIZE`). Run an idle reaper
(`TINA4_WS_IDLE_TIMEOUT`, close 1001) on the served path. Make broadcast local-first and resilient
(prune a dead/slow client, never abort the fan-out), then publish the envelope `{src, kind, exclude,
room, path, +text|b64}` to `tina4:ws` (lazy start; degrade to local-only on failure; a sibling relays
local-only and never re-publishes). Prove the port with `websocket_contract.json`: handshake, auth on
every path, origin allow-list, reaper, reassembly, mask enforcement, resilient broadcast, rooms, and the
backplane relay.

## Audit closure checklist

- [x] Boundary and public surface complete (protocol + server + the backplane envelope seam).
- [x] Lifecycle and every producer/consumer edge complete (upgrade/origin/auth/caps/accept/frame/broadcast/reap).
- [x] Configuration, failure, side-effect and security rules complete (auth coverage, origin, reaper, mask, caps).
- [x] Wire/storage and provider contracts complete (RFC 6455 + the `tina4:ws` envelope; backplane is the provider seam).
- [x] Existing-language contradictions recorded (WS-01..08; the protocol core is parity, the security coverage is uneven).
- [x] Owner ambiguities recorded (8 proposed; auth-on-every-path and the resource caps are the security keys).
- [x] Proposed shared cases and mutation witnesses complete (`websocket_contract.json` over real sockets, no mocks).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
