# Feature 142: Raw TCP service

## Identity and status

- Matrix identity: 142 — Raw TCP service
- Audit state: implementation-ready
- Dependencies: 006 (built-in HTTP server / event loop per runtime), 025
  (graceful shutdown), queue + ORM subsystems (app-side fan-out, not required by
  the primitive itself)
- Dependants: none yet (first consumer is an application-level car-tracker
  gateway, not another framework feature)
- Existing ADRs: ADR-0102 (this feature's contract), ADR-0004 (best
  implementation prevails), ADR-0019 (write-secure-by-default routing, aligned
  not inherited), ADR-0099 (T4DD — ADR before code)
- Shared fixtures: `plan/v3/fixtures/raw_tcp_service_contract.json` (owed)

## Why this feature exists

An app needs to expose its own non-HTTP, long-lived binary TCP service — a GPS/GPRS
car-tracker gateway — in the same process as its HTTP dashboard, reusing the
framework's config, logging, ORM and queue, without hand-rolling socket lifecycle,
limits, idle reaping and backpressure for every protocol.

## Boundary

The feature OWNS: opening a listener folded into the runtime's existing accept/event
loop; the connection lifecycle (accept, `on_connect`/`on_data`/`on_close`, optional
`on_line`); a uniform connection object (`send`, `close`, `remote_addr`, `id`,
`identify`, `context`); a connection registry keyed by an app-assigned id with
`send_to`/`connection`/`broadcast`; `max_connections` refusal; an idle reaper
(default off); graceful-shutdown drain; and read/write backpressure.

The feature DELEGATES to the app: all protocol framing (binary/length/CRC parsing on
the raw byte stream), device authentication (reading the login packet, calling
`conn.identify`), and persistence/fan-out (via the ORM and queue).

The feature explicitly does NOT: provide CRC/length framing helpers beyond `on_line`;
terminate TLS; listen on UDP; or replace the WebSocket surface. Those are deferred
(TLS, UDP) or out of scope (WebSocket).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | none (no user-facing TCP listener) | none | none | none |
| Startup/CLI integration | none | none | none | none |
| Stored/wire format | none (app-defined protocol on the wire) | none | none | none |
| Existing focused tests | none | none | none | none |
| Existing lab baseline | none | none | none | none |

Internal raw-TCP plumbing exists in all four (HTTP server, HTTP client, queue
brokers, cache/session backends, MQTT, WebSocket upgrade) and is the proof the
sockets work; none of it is exposed as a user-facing listener. This feature is
greenfield at the public-surface layer.

## Public surface contract

Language-neutral: `tcp_service(port, options)` opens a named listener. The app
registers handlers `on_connect(conn)`, `on_data(conn, bytes)`, `on_close(conn)`, and
optionally `on_line(conn, line)`. A registry is reachable from anywhere in the app by
the service name: `tcp(name).send_to(id, bytes)`, `tcp(name).connection(id)`,
`tcp(name).broadcast(bytes)`. The connection object exposes `send(bytes)`, `close()`,
`remote_addr`, `id`, `identify(app_id)`, `context`.

Idiomatic spellings (illustrative; exact wording is pinned by the fixture):
- Python: `svc = Tina4.tcp_service(port=5023, idle_timeout=0, max_connections=5000)`;
  `@svc.on_data` decorator; `conn.identify(imei)`; `Tina4.tcp("trackers").send_to(imei, cmd)`.
- Node: `const svc = tcpService({ port: 5023, onData(conn, buf){...}, idleTimeout: 0 })`.
- Ruby: `svc = Tina4.tcp_service(5023) { |conn, data| ... }`.
- PHP: `Tina4::tcpService(5023, ['on_data' => fn($conn,$data)=>..., ...])`.

## Inputs and outputs

- `port`: integer, required.
- `idle_timeout`: seconds, default `0` (OFF — these connections are long-lived by
  design); `> 0` closes a connection silent for that long.
- `max_connections`: integer, default unbounded unless set; the (N+1)th is refused.
- Callbacks receive a connection object and (for `on_data`) a raw byte buffer, never a
  decoded string. `on_line` receives one newline-delimited line with the terminator
  stripped.
- `conn.identify(app_id)` takes an app-chosen identifier (the IMEI); `id` reads it
  back, null until identified.
- `remote_addr` is the raw socket peer address, never a forwarded header.
- Registry sends take raw bytes; `send_to` to an unknown/closed id is a no-op return,
  not a raise.

## Lifecycle and operation graph

Register handlers -> service binds on boot (one owner) -> accept -> `on_connect` ->
loop: bytes arrive -> `on_data` (app frames, may `identify`, may `send`) -> optional
`on_line` -> ... -> peer or server closes -> `on_close` (registry entry removed).
Server->device path: an HTTP route resolves `tcp(name).connection(imei)` or calls
`send_to(imei, bytes)` -> bytes written to that live socket. Shutdown: SIGTERM ->
drain in-flight writes and close live connections within the shutdown deadline while
HTTP keeps serving until then.

## Configuration and precedence

Per-service options are passed at `tcp_service(...)` construction (explicit arguments
win). The listener honours the same graceful-shutdown deadline as the HTTP server
(`TINA4_SHUTDOWN_TIMEOUT`). Options are read once at construction; there is no env
override of a per-service `port`/`idle_timeout`/`max_connections` in v1. On a
multi-worker HTTP deployment the listener binds in exactly ONE owner (primary worker);
`SO_REUSEPORT` is off by default.

## Failures, side effects and security

The app opens the service explicitly for a known protocol, so it is not an ambient
route surface and ADR-0019's write-secure-by-default does not transfer mechanically;
device authentication lives in the app's login-packet handling (`on_data` ->
`conn.identify`). The framework owns: refusing past `max_connections`; reaping idle
connections when `idle_timeout > 0`; draining on shutdown; and backpressure — a slow
or stalled reader must never grow server memory without bound (writes queue bounded,
and a client past the backlog limit is dropped, mirroring the WebSocket
`TINA4_WS_MAX_BACKLOG` posture). A handler that raises is logged and the connection is
closed; one failing connection never aborts the accept loop.

## Wire and persistence contract

The on-the-wire protocol is entirely app-defined (binary/length/CRC frames for
GT06/TK103/Concox/Teltonika). The framework imposes no envelope on `on_data` bytes and
injects nothing into the stream. The registry id is an opaque app string. There is no
persisted state owned by the feature; any persistence is the app's via the ORM/queue.

## Providers and substitutability

Single transport (TCP) in v1. The same `tcp_service` API must behave identically
whether it runs in-process (default) or as a dedicated process (the fleet-scale escape
hatch) — that is the one substitutability axis, and both must satisfy the same fixture
cases. TLS and UDP are deliberate capability exceptions recorded as deferred (see
Breaking changes and migration).

## Contradictions and defects

None found: the feature is greenfield at the public layer, so there is no existing
cross-framework divergence to reconcile. The audit confirmed only that internal raw
TCP exists in all four and that no user-facing listener does.

## Owner decisions

Recorded in ADR-0102 (Accepted 2026-11-03):
- D1 in-process, folded into each runtime's existing loop (alternatives: second
  blocking loop — rejected; separate daemon by default — rejected, kept as an escape
  hatch).
- D2 callback handlers (alternative: per-connection coroutines — rejected, do not port
  to Node/PHP).
- D3 raw `on_data` + app buffer baseline, `on_line` convenience, no framing helper v1.
- D4 connection registry + `send_to`/`broadcast` in v1 scope (without it the feature
  only ingests).
- D5 uniform connection object across all four.
- D6 TLS out of scope v1.

## Proposed conformance fixture

`raw_tcp_service_contract.json` cases (positive, negative, malformed, stale, duplicate,
partial), each with a mutation witness:
- listen+accept in-process; a real client connects and `on_connect` fires.
- a binary frame round-trips and is ACK'd via `conn.send` (positive).
- login-then-stream: `identify(imei)` registers; a later `send_to(imei, cmd)` reaches
  that same client socket and NOT another (positive + isolation negative).
- `on_data` delivers raw bytes, not newline-split; `on_line` splits a `\n` stream.
- `max_connections`: the (N+1)th connection is refused/closed, not queued unbounded
  (negative).
- `idle_timeout=0` keeps a silent connection open; `> 0` reaps it (stale).
- graceful shutdown drains live connections on SIGTERM while HTTP serves until the
  deadline.
- backpressure: a stalled reader does not grow server memory without bound (partial).
- `send_to` to an unknown/closed id is a no-op, not a raise (malformed/duplicate).
- `remote_addr` is the raw socket peer, never a forwarded header.

## Integration map

- Package exports: a `tcp_service` constructor and a `tcp(name)` registry accessor per
  framework, exported from the public surface.
- Startup: the listener binds after DB/route init, before serving, in one owner;
  shutdown hook drains it alongside the HTTP server.
- Request lifecycle: independent of HTTP request handling, but the registry is callable
  from HTTP routes for server->device push.
- CLI/scaffolders/doctor: none required in v1 (no new `tina4` command).
- Documentation: a new cross-framework guide page under `docs/<lang>/` in the same PR
  as each implementation (First Principle: no doc without code).
- Release notes: a new-feature entry when the first framework ships.

## Breaking changes and migration

None — purely additive, a new primitive. Deferred capabilities with their future path:
TLS termination (front with a terminator today; a later feature adds it), and UDP (many
trackers also use UDP; a fast-follow feature extends this contract rather than changing
it).

## Implementation backlog

1. Python reference: `asyncio.start_server` on the server loop; connection object;
   registry; limits; idle reaper; drain; backpressure; `raw_tcp_service_contract.json`;
   no-mock socket tests, each mutation-proved.
2. PHP: fold the TCP listener fd into `Server.php`'s `stream_select` read set
   (highest-risk; single process); same contract + tests.
3. Ruby: acceptor thread + thread-per-connection (the `http_server.rb` model); same
   contract + tests.
4. Node: `net.createServer` on the event loop; same contract + tests.
5. Docs page per framework; CONTRACT-MAP.md row; flip owed -> proven; lab verify at
   HEAD.

## Porting capsule

A clean-room implementer builds this from ADR-0102 and `raw_tcp_service_contract.json`
alone: open a TCP listener inside the runtime's existing accept/event loop (never a
second blocking loop); deliver raw bytes to `on_data` with `on_connect`/`on_close` and
an `on_line` convenience; give each connection `send`/`close`/`remote_addr`/`id`/
`identify`/`context`; keep a name-keyed registry so `send_to`/`connection`/`broadcast`
reach a live socket by app id; refuse past `max_connections`; reap idle connections only
when `idle_timeout > 0`; drain on shutdown within the deadline; bound write buffering and
drop a client past the backlog limit; bind in one owner under multiple workers. No TLS,
no UDP, no framing helper beyond `on_line` in v1.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
