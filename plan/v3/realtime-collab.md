# Plan: Real-time collaboration (Slack/Teams-class) on Tina4

Status: IN PROGRESS (2026-07-08). Owner: Andre. Author: maintainer agent.

## Progress log
- 2026-07-08 — **Slice 1 (calls plane), Python master: DONE + banked.** `realtime()`
  mount + `RtcMediaBackend`/`MeshBackend` + `ice_servers()` (STUN + ephemeral coturn
  TURN) + signalling relay + self-describing `GET /api/rtc/config`. Real (no-mock)
  relay test drives the actual `WebSocketManager` fan-out (room delivery, sender
  excluded, room isolation) + STUN/TURN cred + mount paths. Full suite green
  (3277 passed). Committed to `feature/realtime-collab` (`decc7f1`), pushed, local==remote.
  Docs/skills intentionally NOT yet written (cross-framework surfaces; wait for parity).
- 2026-07-08 — **Chat + files (Python master): DONE + banked.** Owner chose
  "expand Python first" -> full Phase-1 reference before mirroring.
  - Chat: framework-owned ORM models (`tina4_rt_*`, one class per file) + secured
    `/ws/chat/{channel}` (membership guard re-checked per frame, live presence from
    real room membership, typing, read receipts) + `GET /api/channels/{id}/messages`
    history (newest-first, `before` cursor). `realtime()` gained `authorize=`.
  - Files: `StorageBackend` + `LocalStorage` (zero-dep, traversal-safe) + `S3Storage`
    (opt-in boto3, presigned URLs, graceful fallback) + secured `POST /api/files` +
    `GET /api/files/{key}`. `realtime()` gained `storage=`. Env `TINA4_STORAGE_*`.
  - 26 no-mock tests (real WS fan-out, real SQLite, real multipart dispatch, real
    filesystem, real MinIO S3 incl. presigned fetch). Full suite green (3297 passed).
    Committed `9408be3`, pushed, local==remote.
- 2026-07-08 — **tina4-js `rtc` client + live end-to-end demo: DONE + banked.**
  Owner chose "build the client + demo first" to prove the whole path before the
  3-framework port.
  - `tina4js/rtc` (2.5KB gz): `rtc.call` (perfect-negotiation mesh + screen share),
    `rtc.chat` (messages/presence/typing/receipts/history), `rtc.upload`/`fetchBlob`.
    Signal-driven, builds on the `ws` module. New package + vite + IIFE entry.
    Committed `a83d0f0` on tina4-js `feature/realtime-rtc`, pushed, local==remote.
    327 existing tests + size budgets still green.
  - Live demo (real browser vs a real Python realtime() backend): two mesh peers
    exchange media, chat persists + fans out with presence + typing, a file
    uploads + downloads -- all six checks PASS. (Demo app is throwaway scaffolding
    in the session scratchpad, not committed.)
  - **Backend bug the demo surfaced + FIXED (tina4-python `cb6b164`):** the
    built-in webserver's WS upgrade never authenticated secured routes, never set
    `conn.auth`, and never echoed the `bearer` subprotocol (browser handshake
    failed). Also an auth-bypass on that server. Fixed + real socketpair regression
    tests; full suite 3300 passed. PHP/Ruby/Node built-in WS servers must be checked
    for the same gap in the mirror.
  NEXT (still owner-chosen path): mirror the WHOLE reference (calls + chat + files +
  the WS-auth fix) to PHP/Ruby/Node, then docs + book + skills across all 4 + a
  gallery demo, then release.

## Note for the owner (surfaced, not acted on)
`.claude/skills/tina4-developer/` has 3 uncommitted working-tree edits (SKILL.md,
references/auth-and-services.md, references/data-and-orm.md) that predate this
session -- they rewrite the Auto-CRUD section to an `auto_crud = True` ORM flag.
Left untouched (kept out of the realtime commits). Decide: intended (commit
separately) or discard. Verify `auto_crud` exists in Python source before shipping
that skill change (docs-match-code).

## Goal
Give Tina4 the building blocks to build Slack/Teams-class tools: persistent chat
(channels, threads, presence, receipts), server-stored file sharing, and real-time
audio/video/screen-share calls. Ship the parts Tina4 can own with zero third-party
core dependencies first; make the one irreducible dependency (a media SFU) a
pluggable, opt-in backend rather than a core dependency.

## Locked decisions (owner, 2026-07-08)
- **Topology:** SFU-backed is the target for large calls; **Phase 1 ships mesh** (pure P2P) as the zero-dep default.
- **Path:** build the zero-dep control plane now; define an `RtcMediaBackend` interface with `mesh` as the shipped default so an SFU is a drop-in later, not a rewrite.
- **SFU target for the adapter (built in Phase 2):** LiveKit (external service; all 4 frameworks mint join tokens + call its API identically; keeps cross-language parity, which embedding mediasoup would break).
- **File storage:** pluggable `StorageBackend` adapter (local disk in dev, S3-compatible in prod) mirroring the existing cache/session/queue backend pattern.
- **TURN:** self-host coturn; Tina4 mints ephemeral HMAC credentials (stdlib, already prototyped).

## Why the SFU is a dependency, not core
Server-side selective forwarding needs SRTP/RTP termination, DTLS-SRTP, jitter/NACK,
bandwidth estimation and simulcast selection. That is not achievable in stdlib (needs
native media/crypto), is tens of thousands of lines x4 languages (violates the
~5000-LOC/zero-dep principle), and embedding mediasoup (C++/Node) would break parity
for Python/PHP/Ruby. So the SFU is external infra reached over an API, sitting behind
`RtcMediaBackend`, exactly like a DB or Redis is app infra, not a framework dep.

## Architecture: three planes
- **Control plane (Tina4, zero deps):** auth + workspaces/channels/membership, presence, WebSocket signalling relay, message store, file metadata. WS rooms + ORM + queue + Redis/NATS backplane (all already in the framework).
- **Media plane (external, opt-in):** the audio/video/screen bits. `mesh` (browser P2P, zero server media) for small rooms; `RtcMediaBackend=livekit` for large rooms + recording.
- **Storage plane:** file blobs via `StorageBackend`; message history in the ORM.

## Honest scaling line
| Participants | Carried by | Tina4 code deps |
|---|---|---|
| 1:1 | mesh (P2P) | zero |
| 3-6 | mesh | zero (rough past ~6, esp. with screen share) |
| 6-50+ | LiveKit adapter | zero core; opt-in backend |
| recording | LiveKit adapter | opt-in backend |

## Phase 1 scope (zero-dep, ships on its own)
A usable "Slack/Teams for small teams + huddles":
1. **Signalling** WS route: `@websocket("/ws/rtc/{room}")` relaying offer/answer/ICE via `broadcast_to_room(room, data, exclude_self=True)`; `@secure_websocket` variant scopes a room to a member (`connection.auth`).
2. **1:1 + small-group mesh calls** incl. **screen share** (`getDisplayMedia`, added as a renegotiated track) — browser-side; Tina4 relays only.
3. **ICE config** route `GET /api/rtc/config` returning STUN + ephemeral coturn TURN creds. Env: `TINA4_RTC_STUN_URLS`, `TINA4_RTC_TURN_URL`, `TINA4_RTC_TURN_SECRET`.
4. **Chat control plane:** ORM models + WS delivery + catch-up-on-reconnect + presence + typing + read receipts.
5. **File sharing:** upload (`request.files`, raw bytes) -> `StorageBackend` -> permissioned attachment link in a channel; thumbnails/previews; chunked/resumable for large files.
6. **`RtcMediaBackend` interface** with `mesh` default (the only shipped impl in Phase 1).
7. **tina4-js `rtc` module:** perfect-negotiation wrapper over the signalling WS + getUserMedia/getDisplayMedia; plus chat/presence via the existing `ws` module.

## Data model (ORM; Python master shape, mirrored to all 4)
- `workspaces(id, name, ...)`
- `channels(id, workspace_id FK, name, kind[public|private|dm], ...)`
- `channel_members(id, channel_id FK, user_id FK, role, last_read_at)`
- `messages(id, channel_id FK, user_id FK, body, thread_id nullable, created_at, edited_at)`
- `attachments(id, message_id FK, storage_key, filename, mime, size, thumb_key)`
- Presence + typing: ephemeral, in Redis (not the DB), keyed by user/channel with TTL.

## API surface (Phase 1) — configurable mount, NOT fixed paths
Paths are NOT hardcoded into the framework. The feature is a mountable module with
convention DEFAULTS; everything is overridable, and the client discovers paths from
the server so client/server never drift. Three layers:

1. **Primitives (always exposed):** `RtcMediaBackend`, `StorageBackend`, and a
   `relay(connection, room, data)` signalling helper. Write your own routes on these
   for full control.
2. **One-liner mount with convention defaults** (called in app.py, per the
   "centralise config in app.py" convention):
   `realtime(app, prefix="/", features=["calls","chat","files"], media=..., storage=..., authorize=...)`.
   With no args you get the convention paths below. `prefix` relocates the whole
   surface; `features` enables a subset; `media`/`storage` swap backends; `authorize`
   is the per-room/channel membership guard.
3. **Self-describing bootstrap:** the client never hardcodes a URL. `GET <prefix>/api/rtc/config`
   returns `{iceServers, signalling, chat, files}` with the RESOLVED paths (reflecting
   `prefix`), so moving the prefix moves the client automatically. The config may also
   be injected directly into the tina4-js client (`Rtc.init({...})`) to skip the fetch.
   Only this one bootstrap URL is a convention, and it too is overridable.

Convention DEFAULT paths (identical across all 4 frameworks — parity is about
identical defaults, not immovable paths):
- WS `<prefix>/ws/rtc/{room}` — call signalling relay.
- WS `<prefix>/ws/chat/{channel}` — chat/presence/typing (secured; membership-checked via `authorize`).
- `GET  <prefix>/api/rtc/config` — ICE servers + ephemeral TURN creds + resolved paths.
- `POST <prefix>/api/files` — upload -> StorageBackend -> attachment metadata.
- `GET  <prefix>/api/files/{key}` — permissioned download / presigned redirect.
- `GET  <prefix>/api/channels/{id}/messages?before=...` — history paging (catch-up).

Design rationale: convention-over-configuration (zero-config `realtime(app)` DX +
config always available); "the server tells the client" (like formToken/FreshToken and
the injected dev-reload WS URL); no collision with an app's existing route tree.

## Interfaces to add (framework, all 4)
- `RtcMediaBackend`: `mint_join(room, identity) -> token|None`, `room_state(room)`, `close(room)`. Impls: `MeshBackend` (default, returns None token = pure P2P), `LiveKitBackend` (Phase 2). Selected by `TINA4_RTC_BACKEND` (default `mesh`).
- `StorageBackend`: `put(key, bytes, mime)`, `get(key)`, `url(key, ttl)`, `delete(key)`. Impls: `LocalStorage` (default), `S3Storage` (boto/S3-compatible; presigned URLs). Selected by `TINA4_STORAGE_BACKEND` (default `local`), `TINA4_STORAGE_URL`/creds — mirrors the cache backend env pattern.

## Env vars (documented + read by code, per docs-match-code)
`TINA4_RTC_BACKEND` (mesh|livekit), `TINA4_RTC_STUN_URLS`, `TINA4_RTC_TURN_URL`,
`TINA4_RTC_TURN_SECRET`, `TINA4_LIVEKIT_URL`/`_KEY`/`_SECRET` (Phase 2),
`TINA4_STORAGE_BACKEND` (local|s3), `TINA4_STORAGE_DIR`, `TINA4_STORAGE_URL`,
`TINA4_STORAGE_KEY`/`_SECRET`/`_BUCKET`.

## Test strategy (NO mocks — real services)
- Signalling: real Tina4 WS server, two real WS clients, assert offer/answer/ICE relay + room isolation + membership rejection on secured rooms.
- Media (mesh): a real headless-browser two-peer connect (canvas.captureStream source, no camera) reaching `iceConnectionState=connected` with a track received — the no-camera loopback pattern already proven in the preview demo, driven in CI.
- Files: real `LocalStorage` round-trip + real MinIO (S3-compatible) container in CI for `S3Storage` (presigned put/get, large/chunked).
- Chat: real DB + real Redis presence; reconnect catch-up asserted against real rows.
- TURN: a real coturn container; assert an ephemeral cred authenticates a TURN allocation.
- CI provisions MinIO + coturn + Redis as services (extends the existing service matrix).

## Parity plan
Python master first (design + reference), then PHP/Ruby/Node with identical wire
protocol, env vars, JSON shapes, and route names. Same tests in each. tina4-js `rtc`
module + a gallery demo (video call + shared files + chat) at `/__dev/`.

## Documentation and skills (ship WITH the code, never ahead)
Hard rule (First Principle + audit-truth --strict CI gate): none of the below is
written until the matching code lands in the same change. Every env var, method,
class, and route named in docs/skills must resolve in source first, or audit-truth
fails and (on docs main) freezes tina4.com. So this is a build deliverable, not a
head-start.
- **New docs chapter** — a cross-framework intro under `docs/general/` plus a
  per-framework `realtime.md` (`docs/python|php|ruby|nodejs/`), a tina4-js chapter for
  the `rtc` client module, all wired into the VitePress sidebar. content-writer voice,
  ASCII-only.
- **New book chapter** in all 4 tina4-book books.
- **Skills** — extend `tina4-developer/SKILL.md` (+ new `references/realtime.md`) and
  `tina4-js/SKILL.md` (+ `references/` for the `rtc` module) with the `realtime()` mount
  API, the `RtcMediaBackend`/`StorageBackend` backends, env vars, and the honest
  mesh-scaling caveat + LiveKit upgrade path. Reconcile canonical -> all mirrors, add a
  lock-in test, and **bump the install-skills pin** on the release that ships it (skills
  changed). Route the AI to the live API index for verification, per house rule.
- Gate: `audit-truth.py --strict` + `pnpm docs:build` green before any docs/main push.

## Phases
1. **Zero-dep control plane** (this plan): signalling + mesh 1:1/small-group + screen share + chat + presence + files + `RtcMediaBackend(mesh)` + `StorageBackend(local|s3)`. Shippable alone.
2. **LiveKit adapter:** `RtcMediaBackend=livekit` (join-token mint + room state), group video + screen share at scale, simulcast. App opts in.
3. **Recording:** via LiveKit egress; store to `StorageBackend`.

## Risks / open questions
- Mesh honestly degrades past ~6; docs must state the line and the LiveKit upgrade path (no silent cap).
- S3 adapter adds the first optional native dep (S3 client) — kept behind the adapter, graceful-fallback to local like the cache backends.
- Perfect-negotiation (glare) must be baked into the tina4-js `rtc` helper, not left to app authors.
- Presence at scale = Redis key TTLs + backplane fan-out; confirm the backplane already carries room membership deltas or add it.

## Checklist (Phase 1, per framework x4)
- [ ] `RtcMediaBackend` + `MeshBackend` (default)
- [ ] `StorageBackend` + `LocalStorage` + `S3Storage`
- [ ] `/ws/rtc/{room}` signalling relay (+ secured variant)
- [ ] `GET /api/rtc/config` (STUN + ephemeral TURN)
- [ ] chat ORM models + migrations + `/ws/chat/{channel}` + history route + presence/typing/receipts
- [ ] `/api/files` upload + `/api/files/{key}` download (permissioned)
- [ ] tina4-js `rtc` module (perfect negotiation) + chat via `ws`
- [ ] real-service tests (WS, headless two-peer, MinIO, coturn, Redis) in CI
- [ ] docs (new `realtime.md` per framework) + book chapter + gallery demo
- [ ] env vars documented + audit-truth clean
