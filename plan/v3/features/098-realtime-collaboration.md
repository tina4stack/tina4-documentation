# Feature 098: Realtime collaboration

## Identity and status

- Matrix identity: 98 - Realtime collaboration
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the realtime control plane in each repo) at
  Python `386cd6d`, PHP `743b7469`, Ruby `c61250c`, Node `26be920`. Four parallel extractions against the
  Python master + I self-verified the security-critical claims (the calls-WS public surface RT-01, the
  WS-auth-on-upgrade fix). The normative design is `plan/v3/realtime-collab.md`; the 098/099/100 feature
  packets were empty stubs before this audit. No framework code changed.
- Dependencies: the WebSocket server (signalling + chat), the router (mount), the ORM (chat models
  `tina4_rt_*`), the auth layer (WS-upgrade auth + per-frame membership), the storage backends (099/100),
  the env layer (`TINA4_RTC_*`)
- Dependants: any app building Slack/Teams-class collaboration; the tina4-js `rtc` client
- Existing ADRs: none specific to realtime. This audit proposes the first (the realtime control-plane
  contract) plus the fixture. The WS-auth-on-upgrade fix is shared with feature 083 (WS-01).
- Shared fixtures: NONE. `realtime_contract.json` is owed (no fixture, no CONTRACT-MAP row). The control
  plane is proven per-framework by REAL tests (Python ~45, PHP 11, Ruby 13, Node 40) but not by one oracle,
  and coverage is very uneven (S3 and the chat-WS plane are untested outside Python).
- Catalog phase: Integrations

## Why this feature exists

An application wants Slack/Teams-class collaboration - persistent chat with presence and receipts, file
sharing, and realtime audio/video/screen-share calls - without a heavy dependency. Tina4 ships a
ZERO-DEPENDENCY control plane in every language: a `realtime()` mount that wires a WebRTC signalling
relay (media stays peer-to-peer mesh; the SFU is a pluggable opt-in backend), a secured chat WebSocket
with membership guards and presence, a file plane over a pluggable `StorageBackend`, and a
self-describing config endpoint so the client never hardcodes a path.

## Boundary

This feature owns the CONTROL PLANE: the `realtime()` mount, the calls signalling relay + `ice_servers()`
+ the `RtcMediaBackend` seam, the chat models (`tina4_rt_*`) + secured chat WS + presence/typing/receipts
+ history, the file upload/download routes, the authorize/membership guard, and the self-describing
`/api/rtc/config`. The MEDIA plane (mesh browser-side / LiveKit SFU) is external opt-in, not framework
code. The STORAGE backends are features 099 (LocalStorage) and 100 (S3Storage). The tina4-js `rtc`
client is a separate frontend package.

## Existing implementation evidence

The control plane is wire-faithful across the four; the divergences are structural and coverage-based:

| Evidence | Python (master) | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Mount + resolved path map | yes | yes | yes | yes (async) |
| Self-describing `/api/rtc/config` (byte-identical shape) | yes | yes | yes | yes (serves real) |
| Signalling relay `/ws/rtc/{room}` (raw, exclude-self) | yes | yes | yes | yes |
| ICE + ephemeral coturn HMAC-SHA1 TURN cred | yes | yes | yes | yes |
| Chat models `tina4_rt_*` | ForeignKeyField | plain cols | plain cols | plain cols |
| Secured chat WS + per-frame membership guard | yes | yes | yes | yes |
| Presence (live room membership) / typing / receipts | yes | yes | yes | yes |
| Chat history newest-first + `before` cursor (paged in SQL) | yes | yes | NO (100-cap, in-mem) | NO (1000-cliff, in-mem) |
| Files: upload/download, membership-gated, S3-redirect/stream | yes | yes | yes | yes |
| WS-auth-on-upgrade (conn.auth + bearer echo, fail-closed) | yes | yes | yes | yes |
| `RtcMediaBackend`/`media=`/`TINA4_RTC_BACKEND` (SFU seam) | yes | NO | NO | NO |
| Real WS + real S3/MinIO tests | yes | NO | NO | NO |

The wire contract (paths, JSON, tables, HMAC, membership guard, WS auth) is faithfully mirrored. The
master ships the SFU seam and the deep test coverage; the three ports drop the seam and thin the tests,
and two ports (Ruby, Node) mis-page chat history.

## Public surface contract

`realtime(prefix="", *, media, storage, authorize, features=["calls"])` (PHP/Ruby spell it `mount`; Node
is async) mounts, by feature: `GET <prefix>/api/rtc/config` (self-describing), WS `<prefix>/ws/rtc/{room}`
(signalling relay), WS `<prefix>/ws/chat/{channel}` (secured), `GET <prefix>/api/channels/{id}/messages`
(history), `POST <prefix>/api/files` + `GET <prefix>/api/files/{key}`. It returns the resolved path map.
`ice_servers()` returns STUN + an ephemeral TURN cred. `RtcMediaBackend` (`mint_join`, `ice_servers`,
`MeshBackend` default) is the SFU seam - present only in Python (RT-03). `authorize(identity, channel_id)`
is the membership guard (default: a `ChannelMember` count).

## Inputs and outputs

- Input: a WS upgrade (secured chat carries a JWT; signalling is public); chat/typing/read frames; a
  multipart file upload; history paging (`before`, `limit`).
- Output: `/api/rtc/config` returns `{backend, iceServers, signalling, chat, messages, files}` with
  resolved paths; the signalling relay forwards raw offer/answer/ICE to the room (sender excluded); the
  chat WS emits presence rosters, typing, and read receipts; history returns messages newest-first;
  upload returns attachment metadata + a URL; download 302-redirects to a presigned S3 URL or streams the
  local bytes.

## Lifecycle and operation graph

1. MOUNT: `realtime()` resolves the prefix, ensures the chat tables, and registers the routes for the
   enabled features; the client fetches `/api/rtc/config` to discover paths.
2. CALLS: a peer connects the public signalling WS, joins `rtc:{room}`, and its offer/answer/ICE is
   relayed raw to the room (Tina4 never parses SDP; media is peer-to-peer mesh).
3. CHAT: the secured chat WS authenticates on upgrade (conn.auth), checks membership at open AND on every
   frame; messages persist and fan out; presence is derived from live room membership; typing and read
   receipts broadcast; history pages newest-first.
4. FILES: an upload is membership-gated, stored via the `StorageBackend`, and recorded as an attachment;
   a download is membership-gated and 302-redirects (S3) or streams (local).

## Configuration and precedence

- `TINA4_RTC_STUN_URLS` (default a public STUN), `TINA4_RTC_TURN_URL` + `TINA4_RTC_TURN_SECRET` (TURN only
  when both set), `TINA4_RTC_TURN_TTL` (3600). `TINA4_RTC_BACKEND` (mesh|livekit) - READ ONLY IN PYTHON
  (RT-03); the three ports ignore it and hardcode mesh.
- `TINA4_STORAGE_BACKEND` (local|s3) + `TINA4_STORAGE_DIR`/`_URL`/`_KEY`/`_SECRET`/`_BUCKET`/`_REGION`
  (features 099/100). Explicit constructor args win over env.

## Failures, side effects and security

- WS-AUTH-ON-UPGRADE is fail-closed in ALL FOUR (the `cb6b164` fix): the secured chat WS authenticates
  the JWT BEFORE the handshake accept (401/1008 on failure), sets `conn.auth`, and echoes the `bearer`
  subprotocol. The plan explicitly required checking PHP/Ruby/Node built-in WS servers for the same
  bypass Python fixed - all three are clean (Python `server.py:1256`/`:1052`, PHP `Server.php:1686`, Ruby
  `websocket.rb:589`, Node `websocket.ts:1188`). This is the realtime instance of the integrated-path WS
  auth (feature 083); it does NOT rely on Python's standalone `WebSocketServer` (which has the separate
  WS-01 gap).
- PER-FRAME MEMBERSHIP GUARD: the chat WS re-checks `authorize(identity, channel_id)` on EVERY inbound
  frame, not just at open - membership can be revoked mid-session, and a payload's identity is never
  trusted. Uniform in all four.
- CALLS SIGNALLING IS PUBLIC (RT-01, security): `/ws/rtc/{room}` has no membership gate in any framework
  (self-verified in Python: `__init__.py:256` registers it unsecured; the same in PHP/Ruby/Node).
  Anyone who guesses a room name joins the mesh and receives relayed offer/answer/ICE - and SDP carries
  peer IPs and ICE candidates. The plan envisaged a `@secure_websocket` variant scoping a room to a
  member; it was never shipped. This is deliberate for public join-by-link huddles but an open surface
  for private rooms, and it is undocumented.
- TRAVERSAL SAFETY: `LocalStorage` rejects a key that escapes its directory in all four (feature 099);
  storage keys are opaque random hex, never a user path.
- IDENTITY STRINGIFICATION is the cross-language contract: `user_id`/`sub`/`id` from the JWT is coerced to
  a string and `ChannelMember.user_id` is a string column - a port that does not stringify identically
  gets silent membership mismatches (int `1` vs `"1"`).

## Wire and persistence contract

The wire is: the `/api/rtc/config` JSON (`{backend, iceServers, signalling, chat, messages, files}`, byte-
identical across the four); the signalling relay (raw offer/answer/ICE, peers filter by `to`); the chat
WS frames (presence roster, typing, read, message); the history JSON (newest-first). Persistence is the
ORM (`tina4_rt_*` tables) for channels/members/messages/attachments and the `StorageBackend` for file
blobs. Presence and typing are ephemeral (derived from live WS room membership, not a table); read
receipts persist `last_read_at`.

## Providers and substitutability

Two provider seams: the MEDIA backend (`RtcMediaBackend`: `MeshBackend` default, LiveKit SFU Phase 2,
selected by `TINA4_RTC_BACKEND`) - present only in Python (RT-03); and the STORAGE backend
(`StorageBackend`: LocalStorage 099 / S3Storage 100, selected by `TINA4_STORAGE_BACKEND`) - present in
all four. The self-describing config makes the whole surface relocatable by `prefix` without a client
edit.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RT-01 | SECURITY (owner decision, shared all four): the calls signalling WS `/ws/rtc/{room}` is PUBLIC - no membership gate, `authorize=` never applies to it. Anyone guessing a room name joins the mesh and receives relayed offer/answer/ICE (SDP leaks peer IPs/ICE candidates). The plan's secured-signalling variant was never shipped. | Owner decides: ship a secured signalling variant (gate `/ws/rtc/{room}` with `authorize=` like chat) for private rooms, OR document `/ws/rtc/{room}` as deliberately public (join-by-link huddles) with the SDP/IP-in-relay exposure stated. Add a `secured` option either way. |
| RT-02 | CORRECTNESS (Ruby + Node): chat history mis-pages. Ruby caps at 100 rows then sorts in memory (`realtime.rb:361-362`); Node fetches a 1000-row window then sorts/slices in JS (`realtime.ts:343-366`). Past the window, newest-first + `before` silently return the wrong page. Python and PHP order+limit in SQL (`ORDER BY id DESC LIMIT`). | Ruby and Node push the order + limit into SQL (match Python/PHP). FIX RUBY + NODE. |
| RT-03 | STRUCTURAL (all three non-master): the `RtcMediaBackend`/`MeshBackend` media-plane seam is ABSENT in PHP, Ruby AND Node - no media class, a DEAD `media=` option, and `TINA4_RTC_BACKEND` unread; all three hardcode `"mesh"`. Only Python ships the seam. So the Phase-2 LiveKit SFU drop-in - the "zero core, opt-in backend" scaling promise - works ONLY in Python. | PHP/Ruby/Node add the `RtcMediaBackend` seam (`mint_join`/`room_state`/`close`, `MeshBackend` default), the `media=` mount option, and read `TINA4_RTC_BACKEND`, mirroring the master. |
| RT-04 | TEST COVERAGE (all three non-master): the chat WS plane, the HTTP file/history routes, and REAL S3/MinIO are UNVERIFIED in PHP/Ruby/Node (PHP 11 tests, Ruby 13, Node 40 - none drive a real WS handshake, a real route dispatch, or a real object store). Critically, the `cb6b164` WS-auth fix has NO regression test outside Python, so a refactor could silently reopen the bypass. Python has ~45 real tests incl. a real socketpair WS-auth test and real MinIO. | PHP/Ruby/Node add real-WS (socketpair), real HTTP route-dispatch, and real MinIO tests, and port the WS-auth-on-upgrade regression test. Feature 100 (S3Storage) must be verified against a real object store in each. |
| RT-05 | No `realtime_contract.json`; no CONTRACT-MAP row; no ADR. The control plane is proven per-framework but not by one oracle, and coverage is uneven. | Add `realtime_contract.json` gating the config shape, the HMAC TURN cred, the WS-upgrade auth + per-frame membership guard, the history paging, and the storage round-trip; add the first realtime ADR. |
| RT-06 | ORM drift (all three non-master): the chat models use plain typed columns, not `ForeignKeyField` + constraints. Python declares `ForeignKeyField(to=, related_name=)` + `StringField(required=, max_length=)` (an auto-wired relationship graph + NOT NULL/VARCHAR DDL); PHP/Ruby/Node declare bare int/string columns. Column names + JSON keys + the wire contract are identical, but the relationship graph and DDL constraints are absent, so the "byte-identical schema" claim over-reaches. | PHP/Ruby/Node add the FK wiring + field constraints to match the master's DDL (or the owner ratifies the plain-column approach and the docblocks are corrected). Lower priority - functional today. |

## Owner decisions

The control plane wire contract and the WS-auth security core are settled parity. The open calls:

1. CALLS-WS SECURITY (RT-01): ship a secured signalling variant OR document the public model; add a
   `secured` option. Headline security decision.
2. HISTORY PAGING (RT-02): Ruby + Node page in SQL. FIX.
3. MEDIA SEAM (RT-03): PHP/Ruby/Node add the `RtcMediaBackend` seam + `media=` + `TINA4_RTC_BACKEND`.
4. TEST COVERAGE (RT-04): PHP/Ruby/Node add real-WS/route/MinIO tests + the WS-auth regression.
5. FIXTURE + ADR (RT-05): add `realtime_contract.json` and the first realtime ADR.
6. ORM DECLARATIONS (RT-06): add FK + constraints, or ratify plain columns and fix the docblocks.

## Proposed conformance fixture

Add `realtime_contract.json` driving four runners against a real WS server, a real DB, and a real object
store (no mocks - Python already does this): `/api/rtc/config` returns the byte-identical shape with
resolved paths; the TURN cred recomputes as `base64(HMAC-SHA1(secret, expiry-epoch))`; a secured chat WS
rejects a tokenless upgrade (401) and accepts a valid one (conn.auth set), and re-checks membership on a
second frame after membership is revoked; history returns the true newest page on a channel with more
messages than the in-memory window (the RT-02 witness - proves Ruby/Node are fixed); an upload round-trips
through LocalStorage AND real S3/MinIO (presigned download); and the signalling relay forwards to the room
excluding the sender. The WS-auth-on-upgrade and the history-window cases are the load-bearing witnesses.

## Integration map

- `realtime()` mounts on the router + WS server; the auth layer gates the chat upgrade; the ORM stores
  `tina4_rt_*`; the storage backends (099/100) hold blobs; the tina4-js `rtc` client reads
  `/api/rtc/config`.
- `realtime_contract.json` (owed) is the shared oracle; the WS-auth-on-upgrade is shared with feature 083.
- The media seam (RT-03) is the Phase-2 LiveKit integration point - only wired in Python today.

## Breaking changes and migration

- RT-01, if the owner ships secured signalling, makes a private-room `/ws/rtc/{room}` require a token: a
  join-by-link client must send one. `Breaking:` only if the secured mode is turned on for an existing
  public deployment.
- RT-02 (history fix) changes the returned page on channels past the window to the CORRECT newest page: a
  client that depended on the buggy window sees correct data. Effectively a fix, not a break.
- RT-03 (media seam), RT-04 (tests), RT-06 (ORM constraints) are additive.

## Implementation backlog

1. Add `realtime_contract.json` and wire four real-service runners (RT-05); add the first realtime ADR.
2. Ruby + Node: page history in SQL (RT-02).
3. PHP/Ruby/Node: add the `RtcMediaBackend` seam + `media=` + `TINA4_RTC_BACKEND` (RT-03); add the WS-auth
   regression + real-WS/route/MinIO tests (RT-04).
4. RT-01 owner decision (secured signalling or documented public); RT-06 ORM constraints. Run on the lab
   with real WS + MinIO + coturn, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a realtime control plane: a `realtime(prefix, media, storage, authorize, features)` mount that
registers a self-describing `GET /api/rtc/config` (returning `{backend, iceServers, signalling, chat,
messages, files}` with resolved paths), a PUBLIC signalling WS `/ws/rtc/{room}` (relay raw offer/answer/
ICE to the room, exclude the sender, never parse SDP), a SECURED chat WS `/ws/chat/{channel}` that
authenticates the JWT on upgrade (set conn.auth, echo the bearer subprotocol, fail closed) and re-checks
`authorize(identity, channel_id)` on EVERY frame, deriving presence from live room membership and
broadcasting typing + read receipts; a history endpoint paging newest-first with a `before` cursor IN SQL
(`ORDER BY id DESC LIMIT`); membership-gated file upload/download over a `StorageBackend`; `ice_servers()`
returning STUN + an ephemeral coturn cred (`base64(HMAC-SHA1(secret, expiry-epoch))`); and an
`RtcMediaBackend` seam (`MeshBackend` default, `media=`, `TINA4_RTC_BACKEND`) so an SFU drops in later.
Keep the core zero-dependency and stringify identity consistently. Prove it with `realtime_contract.json`
against a real WS server, DB and object store.

## Audit closure checklist

- [x] Boundary and public surface complete (the control plane; media external, storage 099/100).
- [x] Lifecycle and every producer/consumer edge complete (mount/calls/chat/files).
- [x] Configuration, failure, side-effect and security rules complete (WS auth, per-frame guard, public calls WS, traversal).
- [x] Wire/storage and provider contracts complete (config JSON, tina4_rt_* tables, the two provider seams).
- [x] Existing-language contradictions recorded (RT-01..06; wire parity, master-vs-mirror structural + coverage drift).
- [x] Owner ambiguities recorded (6; the public calls WS and the dropped media seam are the keys).
- [x] Proposed shared cases and mutation witnesses complete (`realtime_contract.json`, real WS + DB + S3).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
