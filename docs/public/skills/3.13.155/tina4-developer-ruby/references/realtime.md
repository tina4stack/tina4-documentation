# Real-time collaboration — `Tina4::Realtime` (Ruby)

**Shipped in tina4-ruby 3.13.57** (release commit "Release 3.13.57: realtime collaboration").
Merged from `feature/realtime-collab` into the tagged `3.13.57` release, so it is part of the
current 3.13.x line — not a feature-branch preview. Everything below is verified against
`lib/tina4/realtime.rb` and `lib/tina4/realtime/*.rb` in this repo.

A zero-dependency real-time **control plane** for building Slack/Teams-class tools. Three
opt-in features:

- **calls** — a WebRTC **signalling relay** (mesh / peer-to-peer) plus a self-describing
  ICE-config endpoint. Media is E2E between the browsers; **Tina4 carries no media — it only
  relays the offer/answer/ICE handshake and never parses the SDP.**
- **chat** — persistent channels + messages (framework-owned ORM models), a **secured** chat
  WebSocket with live presence / typing / read receipts, and a history endpoint for
  catch-up-on-reconnect.
- **files** — upload/download through a pluggable `StorageBackend` (local filesystem or S3).

This is the backend surface. The frontend counterpart is the **tina4-js `rtc` module**, which
consumes exactly these routes and JSON shapes — it fetches `/api/rtc/config` and discovers
every path from there, so the client never hardcodes a URL.

**Source of truth:** `lib/tina4/realtime.rb` (mount + handlers), `lib/tina4/realtime/*.rb`
(ORM models + storage backends).

This is a **cross-language** feature — the same paths, JSON shapes, env vars, and `tina4_rt_*`
tables exist in tina4-python, tina4-php, and tina4-nodejs. The Ruby-specific differences are
called out in Footguns below.

---

## Mounting: `Tina4::Realtime.mount(prefix: "", authorize: nil, storage: nil, features: nil)`

Call this once at boot (in `app.rb`, after `Tina4.initialize!` and `Tina4.bind_database`, before
the server starts). It registers the routes/WebSockets and **returns the resolved path map** (a
Hash with String keys) — the same map the config endpoint serves.

```ruby
Tina4::Realtime.mount                                         # calls only (default)
Tina4::Realtime.mount(features: %w[calls chat])               # add persistent chat
Tina4::Realtime.mount(prefix: "/api/collab",
                      features: %w[calls chat files])          # relocate the whole surface
```

| kwarg | meaning |
|---|---|
| `prefix:` | mounts the whole surface under this path. Leading/trailing slashes are stripped: `"/api/collab"` and `"api/collab/"` both → `/api/collab`. Default `""` (root). |
| `authorize:` | membership guard `->(identity, channel_id) { true/false }` used by **chat** and **files**. `identity` is the **String** user id from the JWT. Defaults to a `ChannelMember` membership check. |
| `storage:` | a `StorageBackend` instance for the **files** feature. Defaults to the env-selected store (`local`). |
| `features:` | Array of any of `"calls"`, `"chat"`, `"files"`. **Default `["calls"]`.** |

**Note (Ruby-specific): there is no `media:` parameter.** Unlike the Python port, Ruby ships a
single mesh backend and hardcodes `"backend" => "mesh"` — see Footguns.

**Returns** the resolved path map. Base paths (String keys), then the config endpoint appends
the `{room}`/`{channel}`/`{id}` template tokens for the client:

```ruby
Tina4::Realtime.mount
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "signalling"=>"/ws/rtc"}

Tina4::Realtime.mount(features: %w[calls chat])
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "signalling"=>"/ws/rtc",
#     "chat"=>"/ws/chat", "messages"=>"/api/channels"}

Tina4::Realtime.mount(features: %w[files])
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "files"=>"/api/files"}
```

`config` is added by **any** enabled feature (`calls` sets it; `chat`/`files` set it with `||=`),
so even a chat-only or files-only mount exposes `/api/rtc/config`.

### What each feature wires

| feature | routes registered | auth |
|---|---|---|
| any (has `config`) | `GET  {p}/api/rtc/config` | **public** (no `.secure`) |
| `calls` | `WS   {p}/ws/rtc/{room}` | **public** (unauthenticated) |
| `chat` | `WS   {p}/ws/chat/{channel}` | **secured** — `.secure`, valid JWT required on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` | **secured** — `.secure` |
| `files` | `POST {p}/api/files` (upload) | write route → default bearer-token gate |
| `files` | `GET  {p}/api/files/{key}` (download) | **secured** — `.secure` |

If `chat` or `files` is enabled, `ensure_chat_tables` runs at mount time (creates the
`tina4_rt_*` tables) — see Footguns for the no-DB behavior.

---

## `GET {p}/api/rtc/config` — public bootstrap

The public endpoint the frontend fetches (via the tina4-js `rtc` module) so client and server
never drift. The body is **feature-gated** — only keys for enabled features appear:

```jsonc
{
  "backend": "mesh",
  "iceServers": [ /* ice_servers() */ ],       // calls
  "signalling": "/ws/rtc/{room}",              // calls
  "chat": "/ws/chat/{channel}",                // chat
  "messages": "/api/channels/{id}/messages",   // chat
  "files": "/api/files"                        // files
}
```

`{room}`, `{channel}`, and `{id}` are literal template tokens the client fills in.

---

## ICE / TURN: `Tina4::Realtime.ice_servers`

Builds the ICE server list from the environment. **Always** includes a STUN entry. Adds a TURN
entry **only when both** `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set.

TURN credentials use the coturn **`use-auth-secret`** (ephemeral) scheme, verified in source:

```ruby
username   = (Time.now.to_i + ttl).to_s                                  # expiry epoch
credential = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", secret, username))
```

```ruby
# no TURN env:
Tina4::Realtime.ice_servers
# => [{"urls"=>["stun:stun.l.google.com:19302"]}]

# TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
# => [{"urls"=>["stun:stun.l.google.com:19302"]},
#     {"urls"=>["turn:turn.example.com:3478"], "username"=>"1783546725", "credential"=>"ie7Mm...=="}]
```

STUN/TURN URLs are comma-separated and split into arrays.

### Env vars

| var | default | effect |
|---|---|---|
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | — | comma-separated TURN URLs; enables TURN when set **with** the secret. |
| `TINA4_RTC_TURN_SECRET` | — | coturn `use-auth-secret` shared secret (ephemeral creds). |
| `TINA4_RTC_TURN_TTL` | `3600` | ephemeral TURN credential lifetime (seconds). |
| `TINA4_RTC_BACKEND` | — | **read only for cross-language config parity; Ruby ignores it.** The backend is always `mesh`. |

---

## Signalling WebSocket: `WS {p}/ws/rtc/{room}` — public, mesh relay

Registered with `Tina4::Router.websocket(...)` — **not** `.secure`, so it is **public**. The
Ruby WebSocket handler convention is `(connection, event, data)` where `event` is a **Symbol**:

```ruby
# connection : the WebSocket connection
# event      : :open | :message | :close
# data       : the payload String on :message; nil on :open/:close
```

Behavior (mesh relay):

- `room = connection.params[:room].to_s`; **empty room → no-op** (returns).
- `:open`  → `connection.join_room("rtc:#{room}")`.
- `:message` → `connection.broadcast_to_room("rtc:#{room}", data, exclude_self: true)` — relays
  the **raw** payload to the other peers. Tina4 never parses the SDP; peers filter by a `to`
  field themselves.

Rooms are namespaced `rtc:<room>` so signalling rooms never collide with chat channels
(`chat:<channel>`) that share the same WebSocket manager.

---

## Chat WebSocket: `WS {p}/ws/chat/{channel}` — secured

Registered with `.secure`, so a **valid JWT is required on the upgrade** — an unauthenticated
upgrade is rejected before the handler runs. Handler: `chat_handler(connection, event, data)`.

- Channel is addressed by **integer id**: the handler requires `connection.params[:channel]` to
  match `\A\d+\z`. A non-integer channel makes the handler **return silently** (the socket opens
  and does nothing — no error frame).
- `identity = Tina4::Realtime.identity(connection.auth)` — the String id from the verified token.
- Room key is `chat:<channel_id>`.

Event flow (all inbound frames are JSON objects; every broadcast is a `.to_json` String):

| event / message `"type"` | server behavior |
|---|---|
| `:open` | authorize. **fail →** send `{"type":"error","error":"not a member of this channel"}` then `close`. **ok →** `join_room`, send the caller the roster `{"type":"presence","event":"roster","users":[...]}`, then broadcast `{"type":"presence","event":"join","user_id":<id>}` (exclude self). |
| `:close` | broadcast `{"type":"presence","event":"leave","user_id":<id>}` (exclude self). |
| `"typing"` | broadcast `{"type":"typing","user_id":<id>}` (exclude self). |
| `"read"` | advance the member's read cursor (`last_read_at = now`), broadcast `{"type":"read","user_id":<id>,"at":<iso8601>}` (exclude self). |
| `"message"` | strip `body`; empty/whitespace → **silently dropped**. Otherwise persist a `Message` row and broadcast `{"type":"message","message":<saved>}` to **everyone including the sender** (so the sender's optimistic message reconciles with its server `id` + `created_at`). |

`"type"` defaults to `"message"` when absent. Unknown types are ignored. Non-Hash payloads are
ignored.

**Authorization is re-checked on every inbound `:message` frame**, not just on join — membership
can be revoked mid-session, and the server never trusts an identity carried in the payload.

The roster (`users`) is the sorted set of distinct authenticated identities currently in the
room, collected from each live connection's `auth` via the WebSocket manager
(`Tina4::WebSocket.current.get_room_connections(key)`).

Saved-message JSON shape (also returned by history):

```jsonc
{ "id": <int>, "channel_id": <int>, "user_id": "<str>", "body": "<str>",
  "thread_id": <int|null>, "created_at": "<iso8601 Z>" }
```

`thread_id` is `null` for a top-level message, or the parent message id for a threaded reply.

---

## Chat history: `GET {p}/api/channels/{id}/messages` — secured

Catch-up-on-reconnect endpoint. Handler `chat_history`-style route body:

- Identity comes from `request.user` (the router-attached verified JWT payload).
- `channel_id <= 0` → **400**; not authorized → **403**; otherwise the message list.
- Query params: `before` (return messages with `id < before`) and `limit` (default **50**,
  floored at 1, capped at **200**).
- Returns messages **newest-first** — the standard infinite-scroll-backwards shape. Each item
  has the saved-message JSON shape above.

---

## Files: upload / download — enabled by `features: %w[files]`

Uses a `StorageBackend` (`storage:` arg, or the env-selected store, default `LocalStorage`).
The backend is resolved once at mount via `Tina4::Realtime::Storage.select(storage)`.

### `POST {p}/api/files` — upload (write route → auth-required)

- **Multipart**: file field **`file`** plus form field **`channel_id`** (required, integer).
- Invalid/missing `channel_id` → **400**; not a channel member → **403**; no file → **400**.
- Stores the blob under an opaque, collision-free `storage_key`
  (`SecureRandom.hex(16)` + sanitized extension — **never a user-controlled path**), inserts an
  `Attachment` row (metadata only, never the blob), and responds **201**:

```jsonc
{ "id": <int>, "key": "<storage_key>", "filename": "<str>", "mime": "<str>",
  "size": <int>, "url": "<direct url OR {files}/{key}>" }
```

`url` is `store.url(key)` when the backend exposes a direct URL (e.g. an S3 presigned URL),
else the app download route `{files}/{key}`.

This route is registered with `Tina4::Router.post(...)` **without** `.no_auth`, so the default
**write-route bearer gate applies** — a tokenless upload 401s. (The download route below needs
`.secure` because `GET` is public by default; the upload does not, because writes already
require a token.)

### `GET {p}/api/files/{key}` — download (secured)

- Looks up the `Attachment` by `storage_key`; missing → **404**. Authorizes against the
  attachment's `channel_id`; non-member → **403**.
- If the backend has a direct URL → **302** redirect (`Location`). Otherwise **streams the
  bytes** (**200**) with `Content-Disposition: inline; filename="…"` and `Content-Type` =
  `attachment.mime` (default `application/octet-stream`). Missing blob on disk → **404**.

### Storage backends (`lib/tina4/realtime/storage.rb` + `*_storage.rb`)

`Tina4::Realtime::Storage.select(storage = nil)` resolves from the `storage:` arg or
`TINA4_STORAGE_BACKEND` (`local` default | `s3`). An `s3` backend that can't be built (the
`aws-sdk-s3` gem is missing, or config is incomplete) **falls back to `LocalStorage` with a
warning** — a real persistent store, never a silent no-op. (Ruby rescues both `StandardError`
and `LoadError` here, since a missing gem raises `LoadError`, which is not a `StandardError`.)

| var | default | effect |
|---|---|---|
| `TINA4_STORAGE_BACKEND` | `local` | `local` \| `s3`. |
| `TINA4_STORAGE_DIR` | `data/rt_storage` | local filesystem directory. |
| `TINA4_STORAGE_URL` | — | S3 endpoint URL (S3-compatible / MinIO); `force_path_style` is on. |
| `TINA4_STORAGE_KEY` / `TINA4_STORAGE_SECRET` | — | S3 credentials. |
| `TINA4_STORAGE_BUCKET` | — | S3 bucket (**required** for S3; raises `ArgumentError` if absent). |
| `TINA4_STORAGE_REGION` | `us-east-1` | S3 region. |

`LocalStorage` resolves every key inside its root and **rejects path traversal** (raises
`ArgumentError` on an unsafe key); `url` returns `nil` (blobs are served by the permissioned
download route). `S3Storage` returns a presigned GET URL from `url`, so clients fetch large
blobs straight from object storage.

---

## Auth & identity

- **`Tina4::Realtime.identity(auth)`** — extracts a stable **String** user id from a verified
  JWT payload, trying claims **`user_id` → `sub` → `id`** in order (String or Symbol keys);
  returns `nil` if `auth` is not a Hash or none of those claims are present. Identities
  round-trip as Strings, so an int id, a UUID, or an email all work.
- **WS identity** comes from `connection.auth` (the verified JWT payload attached on the secured
  upgrade). **HTTP identity** comes from `request.user` (router-attached) — Ruby matches the
  PHP/Node ports here; it does **not** re-parse the `Authorization` header the way Python's HTTP
  handlers do.
- **`Tina4::Realtime.authorized?(identity, channel_id)`** — the shared guard for chat channels
  and file access. A `nil` identity is **always denied**. If a custom `authorize:` Proc was
  passed to `mount`, it wins (`!!proc.call(identity, channel_id)`); otherwise the secure default
  requires channel membership:
  `ChannelMember.count("channel_id = ? AND user_id = ?", [channel_id, identity]).positive?`. Any
  exception logs and returns `false` (deny).
- A custom `authorize:` must be **cheap** — it runs on every inbound chat frame, not just on join.

---

## Data model (`lib/tina4/realtime/*.rb`)

Framework-owned `Tina4::ORM` models, all with the **`tina4_rt_`** table prefix so they never
collide with an app's own tables. Ruby is snake_case end to end — columns, attributes, and JSON
keys match with no mapping layer. Tables are created on demand at mount via each model's
`create_table` (`ensure_chat_tables` iterates them in dependency order).

| model | table | key fields |
|---|---|---|
| `Workspace` | `tina4_rt_workspaces` | `id`, `name`, `created_at` |
| `Channel` | `tina4_rt_channels` | `id`, `workspace_id`, `name`, `kind` (`public`\|`private`\|`dm`, default `public`), `created_at` |
| `ChannelMember` | `tina4_rt_channel_members` | `id`, `channel_id`, `user_id` (String, ≤128), `role` (default `member`), `last_read_at` (read cursor) |
| `Message` | `tina4_rt_messages` | `id`, `channel_id`, `user_id` (String), `body` (Text), `thread_id` (nullable parent id), `created_at`, `edited_at` (nullable) |
| `Attachment` | `tina4_rt_attachments` | `id`, `channel_id`, `message_id` (nullable), `storage_key`, `filename`, `mime`, `size`, `thumb_key` (nullable) |

`workspace_id` / `channel_id` are plain integer FK columns queried directly (no ORM relationship
wiring — the control plane doesn't need it). `user_id` is a String everywhere so any JWT identity
shape fits.

---

## ⚠️ Footguns / hard rules

- **Ruby is mesh-only; `TINA4_RTC_BACKEND` is ignored.** `mount` has **no `media:` param**, and
  the path map and config body hardcode `"backend" => "mesh"`. Setting `TINA4_RTC_BACKEND` does
  nothing in Ruby (it exists for cross-language config parity). An SFU/LiveKit backend is a future
  drop-in, not a Phase-1 option here.
- **Chat needs a bound database — but a missing one does NOT crash boot.** With `features:` that
  include `chat`/`files`, `ensure_chat_tables` runs at mount; if no DB is bound it **logs an
  error and continues**. `mount` still returns the full path map and registers every route — the
  failure only surfaces at query time. Bind a DB (`Tina4.bind_database(db)` /
  `TINA4_DATABASE_URL`) **before** calling `mount(features: [...])`, or chat/history/files will
  error per-request while the app looks healthy.
- **The signalling WS (`/ws/rtc/{room}`) is PUBLIC** — it is not `.secure`, so anyone can join
  any room and receive relayed signalling frames. Only the **chat** WS is JWT-secured. Gate call
  access at the app layer if you need it.
- **The config endpoint (`/api/rtc/config`) is PUBLIC** and returns your ICE/TURN config,
  including freshly-minted ephemeral TURN credentials.
- **WS handler signature is `(connection, event, data)` and `event` is a Symbol**
  (`:open`/`:message`/`:close`); `data` is the payload String on `:message`, `nil` otherwise.
  This is the Ruby framework convention — **not** `(connection, data, event)`. (The PHP port
  fires `($connection, $data, $event)` — argument order differs across languages.)
- **Channels are addressed by integer id.** A non-integer `{channel}` makes the chat handler
  return silently (no error frame) — the client sees a socket that opens and does nothing.
- **Chat authorization is re-checked on every frame**, and identity is always taken from the
  verified token (`connection.auth` / `request.user`), never from the message payload. Keep a
  custom `authorize:` cheap.
- **A message with an empty/whitespace `body` is silently dropped** (no persist, no broadcast).
  `read`/`typing`/unknown types never persist anything.
- **Upload is protected by the default write gate, not `.secure`; download IS `.secure`.** Don't
  add `.no_auth` to the upload route thinking it needs auth added — writes already require a
  token. The download route needs `.secure` only because GET is public by default.

---

## Minimal end-to-end example

```ruby
# app.rb — after Tina4.initialize! and Tina4.bind_database(...)
require "tina4"

# Persistent chat + calls + files, membership-gated by the default ChannelMember check.
paths = Tina4::Realtime.mount(features: %w[calls chat files])
Tina4::Log.info("realtime mounted: #{paths.inspect}")

# Open a channel to any authenticated user (public channel) with a custom guard:
Tina4::Realtime.mount(
  features: %w[calls chat],
  authorize: ->(identity, _channel_id) { !identity.nil? }
)
```

The frontend calls `/api/rtc/config`, reads back `signalling` / `chat` / `messages` / `files`,
and drives the WebRTC handshake + chat sockets from there — see the **tina4-js `rtc` module**.
