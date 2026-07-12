# Chapter 38: Real-time Collaboration (WebRTC)

## 1. The Media Server You Don't Need to Run

You want a call button. Two people click it and they are talking -- video, audio, a shared screen. Then a chat thread beside the call, with typing indicators and history that survives a reconnect. Then drag-and-drop file sharing into that same channel.

The reflex is to reach for a media server: an SFU, a TURN farm, a signalling service, three moving parts to operate before anyone says a word. `Tina4::Realtime` skips the media server entirely. It ships a **mesh WebRTC control plane** -- Tina4 relays the offer/answer/ICE handshake so two browsers can find each other, and then **the media flows peer-to-peer, end-to-end, never through your server**. Tina4 never sees the audio or video. It never even parses the SDP.

What Tina4 *does* own is everything around the media: a self-describing config endpoint the client bootstraps from, a signalling relay, a secured chat socket with presence and history, and pluggable file storage. Three opt-in features, one `mount` call, zero external dependencies.

Shipped in **tina4-ruby 3.13.57**. This chapter is the backend surface. The browser counterpart is the tina4-js `rtc` module, which fetches `/api/rtc/config` and discovers every path from there -- the client never hardcodes a URL.

---

## 2. What You Get

`Tina4::Realtime` is a zero-dependency real-time control plane with three features you turn on individually:

- **`calls`** -- a WebRTC **signalling relay** (mesh / peer-to-peer) plus a public, self-describing ICE-config endpoint. Media is E2E between the browsers; **Tina4 carries no media -- it only relays the offer/answer/ICE handshake and never inspects the SDP.**
- **`chat`** -- persistent channels and messages (framework-owned ORM models), a **secured** chat WebSocket with live presence / typing / read receipts, and a history endpoint for catch-up-on-reconnect.
- **`files`** -- upload/download through a pluggable `StorageBackend` (local filesystem or S3).

Only the features you name are wired. The default is `calls` alone.

**Ruby is mesh-only.** There is a single media backend and `mount` **has no `media:` parameter** -- the path map and the config body both hardcode `"backend" => "mesh"`. (The Python port exposes a `media:` selector for an SFU; Ruby does not yet. An SFU/LiveKit backend is a future drop-in, not a Phase-1 option here.) The `TINA4_RTC_BACKEND` env var exists only for cross-language config parity and is **ignored** in Ruby.

This is a cross-language feature: the same paths, JSON shapes, env vars, and `tina4_rt_*` tables exist in tina4-python, tina4-php, and tina4-nodejs. The Ruby-specific differences are called out in [Footguns](#_11-footguns-hard-rules).

---

## 3. Mounting: `Tina4::Realtime.mount(...)`

Call `mount` once at boot -- in `app.rb`, **after** `Tina4.initialize!` and `Tina4.bind_database`, before the server starts. It registers the routes and WebSockets and **returns the resolved path map** (a Hash with String keys) -- the same map the config endpoint serves back to clients.

```ruby
Tina4::Realtime.mount(prefix: "", authorize: nil, storage: nil, features: nil)
```

```ruby
Tina4::Realtime.mount                                          # calls only (default)
Tina4::Realtime.mount(features: %w[calls chat])                # add persistent chat
Tina4::Realtime.mount(prefix: "/api/collab",
                      features: %w[calls chat files])          # relocate the whole surface
```

| kwarg | meaning |
|---|---|
| `prefix:` | Mounts the whole surface under this path. Leading/trailing slashes are stripped: `"/api/collab"` and `"api/collab/"` both resolve to `/api/collab`. Default `""` (root). |
| `authorize:` | Membership guard `->(identity, channel_id) { true_or_false }` used by **chat** and **files**. `identity` is the **String** user id from the JWT. Defaults to a `ChannelMember` membership check. |
| `storage:` | A `StorageBackend` instance for the **files** feature. Defaults to the env-selected store (`local`). |
| `features:` | Array of any of `"calls"`, `"chat"`, `"files"`. **Default `["calls"]`.** |

**Returns** the resolved path map. Base paths are String-keyed; the config endpoint later appends the `{room}` / `{channel}` / `{id}` template tokens for the client:

```ruby
Tina4::Realtime.mount
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "signalling"=>"/ws/rtc"}

Tina4::Realtime.mount(features: %w[calls chat])
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "signalling"=>"/ws/rtc",
#     "chat"=>"/ws/chat", "messages"=>"/api/channels"}

Tina4::Realtime.mount(features: %w[files])
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "files"=>"/api/files"}
```

`config` is added by **any** enabled feature (`calls` sets it; `chat` and `files` set it with `||=`), so even a chat-only or files-only mount still exposes `/api/rtc/config`.

### What each feature wires

| feature | routes registered | auth |
|---|---|---|
| any (has `config`) | `GET  {p}/api/rtc/config` | **public** (no `.secure`) |
| `calls` | `WS   {p}/ws/rtc/{room}` | **public** (unauthenticated) |
| `chat` | `WS   {p}/ws/chat/{channel}` | **secured** -- `.secure`, valid JWT required on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` | **secured** -- `.secure` |
| `files` | `POST {p}/api/files` (upload) | write route -- default bearer-token gate |
| `files` | `GET  {p}/api/files/{key}` (download) | **secured** -- `.secure` |

If `chat` or `files` is enabled, `ensure_chat_tables` runs at mount time and creates the `tina4_rt_*` tables. If no database is bound it **logs an error and continues** -- see [Footguns](#_11-footguns-hard-rules).

---

## 4. The Config Bootstrap: `GET {p}/api/rtc/config`

This is the one URL the frontend has to know. It fetches the config, reads back the paths and ICE servers, and drives everything else from there -- client and server never drift because the server is the single source of truth for its own routes.

The body is **feature-gated**: only keys for enabled features appear.

```jsonc
{
  "backend": "mesh",
  "iceServers": [ /* Tina4::Realtime.ice_servers */ ],   // calls
  "signalling": "/ws/rtc/{room}",                        // calls
  "chat": "/ws/chat/{channel}",                          // chat
  "messages": "/api/channels/{id}/messages",             // chat
  "files": "/api/files"                                  // files
}
```

`{room}`, `{channel}`, and `{id}` are literal template tokens the client substitutes. The endpoint is **public** -- no token required -- because the client needs the ICE config before it has authenticated anyone into a call.

```js
// Browser: discover everything from one fetch, then wire the sockets.
const cfg = await fetch("/api/rtc/config").then(r => r.json());

const signallingUrl = cfg.signalling.replace("{room}", roomId);   // /ws/rtc/room-42
const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });
const ws = new WebSocket(`wss://${location.host}${signallingUrl}`);
```

---

## 5. ICE / TURN: `Tina4::Realtime.ice_servers`

Peers on the same network find each other with STUN alone. Peers behind symmetric NATs need a TURN relay. `ice_servers` builds the list the client hands to `RTCPeerConnection`, straight from the environment.

It **always** includes a STUN entry. It adds a TURN entry **only when both** `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set. TURN credentials use the coturn **`use-auth-secret`** (ephemeral) scheme -- a time-limited username/credential pair minted on each request, so you never ship static TURN passwords to the browser:

```ruby
username   = (Time.now.to_i + ttl).to_s                                   # expiry epoch
credential = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", secret, username))
```

```ruby
# No TURN env set:
Tina4::Realtime.ice_servers
# => [{"urls"=>["stun:stun.l.google.com:19302"]}]

# TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
# => [{"urls"=>["stun:stun.l.google.com:19302"]},
#     {"urls"=>["turn:turn.example.com:3478"], "username"=>"1783546725", "credential"=>"ie7Mm...=="}]
```

STUN and TURN URLs are comma-separated in the env and split into arrays.

### Environment variables

| var | default | effect |
|---|---|---|
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | -- | Comma-separated TURN URLs; enables TURN when set **together with** the secret. |
| `TINA4_RTC_TURN_SECRET` | -- | coturn `use-auth-secret` shared secret (ephemeral creds). |
| `TINA4_RTC_TURN_TTL` | `3600` | Ephemeral TURN credential lifetime, in seconds. |
| `TINA4_RTC_BACKEND` | -- | **Read only for cross-language config parity; Ruby ignores it.** The backend is always `mesh`. |

```bash
# Enable a coturn relay for peers behind symmetric NAT.
export TINA4_RTC_TURN_URL="turn:turn.example.com:3478"
export TINA4_RTC_TURN_SECRET="a-long-random-shared-secret"
export TINA4_RTC_TURN_TTL="3600"
```

---

## 6. The Signalling WebSocket (mesh): `WS {p}/ws/rtc/{room}`

This is the relay that lets two browsers negotiate a peer connection. It is registered with `Tina4::Router.websocket(...)` and is **not** `.secure`, so it is **public**. The Ruby WebSocket convention is `(connection, event, data)` where `event` is a **Symbol**:

```ruby
# connection : the WebSocket connection
# event      : :open | :message | :close
# data       : the payload String on :message; nil on :open / :close
```

The whole handler is a mesh relay -- it moves opaque frames between peers and gets out of the way:

```ruby
Tina4::Router.websocket "/ws/rtc/{room}" do |connection, event, data|
  room = connection.params[:room].to_s
  next if room.empty?                                   # empty room -> no-op

  key = "rtc:#{room}"
  case event
  when :open
    connection.join_room(key)
  when :message
    connection.broadcast_to_room(key, data, exclude_self: true)  # relay raw, verbatim
  end
end
```

Behavior:

- `room = connection.params[:room].to_s`; an **empty room is a no-op** (the handler returns).
- `:open` -- `connection.join_room("rtc:#{room}")`.
- `:message` -- `connection.broadcast_to_room("rtc:#{room}", data, exclude_self: true)` relays the **raw** payload to the other peers. Tina4 never parses the SDP; peers address each other by putting a `to` field in their own payload and filtering on it.

Rooms are namespaced `rtc:<room>` so signalling rooms never collide with chat channels (`chat:<channel>`) sharing the same WebSocket manager.

Because the room is a URL segment and the socket is public, treat the room id as a capability: gate access at the app layer if a call must be private.

---

## 7. The Chat WebSocket and History (secured)

### `WS {p}/ws/chat/{channel}` -- secured

The chat socket is registered with `.secure`, so a **valid JWT is required on the upgrade** -- an unauthenticated upgrade is rejected before the handler ever runs. The handler is `chat_handler(connection, event, data)`.

- The channel is addressed by **integer id**: the handler requires `connection.params[:channel]` to match `\A\d+\z`. A non-integer channel makes the handler **return silently** -- the socket opens and does nothing, no error frame.
- `identity = Tina4::Realtime.identity(connection.auth)` -- the String id from the verified token.
- The room key is `chat:<channel_id>`.

Every inbound frame is a JSON object; every broadcast is a `.to_json` String.

| event / message `"type"` | server behavior |
|---|---|
| `:open` | Authorize. **Fail:** send `{"type":"error","error":"not a member of this channel"}` then `close`. **OK:** `join_room`, send the caller the roster `{"type":"presence","event":"roster","users":[...]}`, then broadcast `{"type":"presence","event":"join","user_id":<id>}` (exclude self). |
| `:close` | Broadcast `{"type":"presence","event":"leave","user_id":<id>}` (exclude self). |
| `"typing"` | Broadcast `{"type":"typing","user_id":<id>}` (exclude self). |
| `"read"` | Advance the member's read cursor (`last_read_at = now`), broadcast `{"type":"read","user_id":<id>,"at":<iso8601>}` (exclude self). |
| `"message"` | Strip `body`; empty/whitespace is **silently dropped**. Otherwise persist a `Message` row and broadcast `{"type":"message","message":<saved>}` to **everyone including the sender** -- so the sender's optimistic message reconciles with its server `id` and `created_at`. |

`"type"` defaults to `"message"` when absent. Unknown types are ignored, and non-Hash payloads are ignored.

**Authorization is re-checked on every inbound `:message` frame**, not just on join -- membership can be revoked mid-session, and the server never trusts an identity carried in the payload. The roster is the sorted, de-duplicated set of authenticated identities currently in the room, collected from each live connection's `auth`.

A saved message (broadcast, and returned by history) has this shape:

```jsonc
{ "id": <int>, "channel_id": <int>, "user_id": "<str>", "body": "<str>",
  "thread_id": <int|null>, "created_at": "<iso8601 Z>" }
```

`thread_id` is `null` for a top-level message, or the parent message id for a threaded reply.

### `GET {p}/api/channels/{id}/messages` -- secured

The catch-up-on-reconnect endpoint. A client opens the socket for live traffic and calls this to backfill what it missed.

- Identity comes from `request.user` (the router-attached, verified JWT payload).
- `channel_id <= 0` -- **400**; not authorized -- **403**; otherwise the message list.
- Query params: `before` (return messages with `id < before`) and `limit` (default **50**, floored at 1, capped at **200**).
- Returns messages **newest-first** -- the standard infinite-scroll-backwards shape. Each item uses the saved-message JSON above.

```bash
# Page backwards from message id 900, 50 at a time.
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7147/api/channels/42/messages?before=900&limit=50"
```

---

## 8. Files: Upload / Download and Storage Backends

Enabled with `features: %w[files]`. Files are stored through a `StorageBackend` (the `storage:` arg, or the env-selected store, default `LocalStorage`), resolved once at mount via `Tina4::Realtime::Storage.select(storage)`.

### `POST {p}/api/files` -- upload

- **Multipart**: file field **`file`** plus a form field **`channel_id`** (required, integer).
- Invalid/missing `channel_id` -- **400**; not a channel member -- **403**; no file -- **400**.
- The blob is stored under an opaque, collision-free `storage_key` (`SecureRandom.hex(16)` plus a sanitized, length-capped extension -- **never a user-controlled path**). An `Attachment` row records the metadata only, never the blob. Responds **201**:

```jsonc
{ "id": <int>, "key": "<storage_key>", "filename": "<str>", "mime": "<str>",
  "size": <int>, "url": "<direct url OR {files}/{key}>" }
```

`url` is `store.url(key)` when the backend exposes a direct URL (e.g. an S3 presigned URL), otherwise the app download route `{files}/{key}`.

This route is registered with `Tina4::Router.post(...)` **without** `.no_auth`, so the default **write-route bearer gate applies** -- a tokenless upload 401s.

```bash
curl -X POST http://localhost:7147/api/files \
  -H "Authorization: Bearer $JWT" \
  -F "channel_id=42" \
  -F "file=@./diagram.png"
```

### `GET {p}/api/files/{key}` -- download (secured)

- Looks up the `Attachment` by `storage_key`; missing -- **404**. Authorizes against the attachment's `channel_id`; a non-member -- **403**.
- If the backend has a direct URL it **302-redirects** to it. Otherwise it **streams the bytes** (**200**) with `Content-Disposition: inline; filename="..."` and `Content-Type` set from `attachment.mime` (default `application/octet-stream`). A missing blob on disk -- **404**.

The download route needs `.secure` because a `GET` is public by default; the upload does not, because writes already require a token.

### Storage backends

`Tina4::Realtime::Storage.select(storage = nil)` resolves from the `storage:` arg or `TINA4_STORAGE_BACKEND` (`local` default | `s3`). An `s3` backend that cannot be built -- the `aws-sdk-s3` gem is missing, or the config is incomplete -- **falls back to `LocalStorage` with a warning**. A real persistent store, never a silent no-op. (Ruby rescues both `StandardError` and `LoadError` here, because a missing gem raises `LoadError`, which is not a `StandardError`.)

| var | default | effect |
|---|---|---|
| `TINA4_STORAGE_BACKEND` | `local` | `local` \| `s3`. |
| `TINA4_STORAGE_DIR` | `data/rt_storage` | Local filesystem directory. |
| `TINA4_STORAGE_URL` | -- | S3 endpoint URL (S3-compatible / MinIO); `force_path_style` is on. |
| `TINA4_STORAGE_KEY` / `TINA4_STORAGE_SECRET` | -- | S3 credentials. |
| `TINA4_STORAGE_BUCKET` | -- | S3 bucket (**required** for S3; raises `ArgumentError` if absent). |
| `TINA4_STORAGE_REGION` | `us-east-1` | S3 region. |

`LocalStorage` resolves every key inside its root and **rejects path traversal** (raises `ArgumentError` on an unsafe key); its `url` returns `nil`, so blobs are served by the permissioned download route. `S3Storage` returns a presigned GET URL from `url`, so clients fetch large blobs straight from object storage and skip your app server.

You can also pass a custom backend instance directly:

```ruby
Tina4::Realtime.mount(features: %w[chat files], storage: MyStorageBackend.new)
```

---

## 9. Auth and Identity

Identity is always taken from the verified token -- never from the message body.

- **`Tina4::Realtime.identity(auth)`** extracts a stable **String** user id from a verified JWT payload, trying claims **`user_id` -> `sub` -> `id`** in order (String or Symbol keys). It returns `nil` if `auth` is not a Hash or none of those claims are present. Identities round-trip as Strings, so an integer id, a UUID, or an email all work.
- **WebSocket identity** comes from `connection.auth` (the verified payload attached on the secured upgrade). **HTTP identity** comes from `request.user` (router-attached). Ruby matches the PHP/Node ports here -- it does not re-parse the `Authorization` header the way Python's HTTP handlers do.
- **`Tina4::Realtime.authorized?(identity, channel_id)`** is the shared guard for chat channels and file access. A `nil` identity is **always denied**. If a custom `authorize:` Proc was passed to `mount`, it wins (`!!proc.call(identity, channel_id)`); otherwise the secure default requires channel membership:

  ```ruby
  ChannelMember.count("channel_id = ? AND user_id = ?", [channel_id, identity]).positive?
  ```

  Any exception logs and returns `false` (deny).
- A custom `authorize:` must be **cheap** -- it runs on every inbound chat frame, not just on join.

### Data model

The chat/files features own a small set of `Tina4::ORM` models, all with the **`tina4_rt_`** table prefix so they never collide with your app's own tables. Ruby is snake_case end to end -- columns, attributes, and JSON keys match with no mapping layer. Tables are created on demand at mount (`ensure_chat_tables` iterates them in dependency order).

| model | table | key fields |
|---|---|---|
| `Workspace` | `tina4_rt_workspaces` | `id`, `name`, `created_at` |
| `Channel` | `tina4_rt_channels` | `id`, `workspace_id`, `name`, `kind` (`public`\|`private`\|`dm`, default `public`), `created_at` |
| `ChannelMember` | `tina4_rt_channel_members` | `id`, `channel_id`, `user_id` (String, <=128), `role` (default `member`), `last_read_at` (read cursor) |
| `Message` | `tina4_rt_messages` | `id`, `channel_id`, `user_id` (String), `body` (Text), `thread_id` (nullable parent id), `created_at`, `edited_at` (nullable) |
| `Attachment` | `tina4_rt_attachments` | `id`, `channel_id`, `message_id` (nullable), `storage_key`, `filename`, `mime`, `size`, `thumb_key` (nullable) |

`workspace_id` and `channel_id` are plain integer FK columns queried directly (no ORM relationship wiring -- the control plane does not need it). `user_id` is a String everywhere, so any JWT identity shape fits.

Add a member so the default guard lets them in:

```ruby
Tina4::Realtime::ChannelMember.new(
  channel_id: 42, user_id: current_user_id.to_s, role: "member"
).save
```

---

## 10. A Complete Minimal Example

Backend -- mount calls + chat + files, membership-gated by the default `ChannelMember` check:

```ruby
# app.rb -- after Tina4.initialize! and Tina4.bind_database(...)
require "tina4"

paths = Tina4::Realtime.mount(features: %w[calls chat files])
Tina4::Log.info("realtime mounted: #{paths.inspect}")
```

Prefer a public channel open to any authenticated user? Pass a custom guard:

```ruby
Tina4::Realtime.mount(
  features: %w[calls chat],
  authorize: ->(identity, _channel_id) { !identity.nil? }   # keep it cheap -- runs per frame
)
```

Frontend -- bootstrap from the config, then drive the sockets. This is exactly what the tina4-js `rtc` module does for you:

```js
// 1. Discover every path + the ICE servers from one public fetch.
const cfg = await fetch("/api/rtc/config").then(r => r.json());

// 2. Calls: mesh signalling over the public relay.
const pc  = new RTCPeerConnection({ iceServers: cfg.iceServers });
const sig = new WebSocket(`wss://${location.host}${cfg.signalling.replace("{room}", "room-42")}`);
sig.onmessage = (e) => handleSignal(JSON.parse(e.data));   // offer / answer / ICE from peers

// 3. Chat: JWT required on the upgrade (subprotocol carries the bearer token).
const chatUrl = cfg.chat.replace("{channel}", "42");
const chat = new WebSocket(`wss://${location.host}${chatUrl}`, ["bearer", jwt]);
chat.onmessage = (e) => render(JSON.parse(e.data));        // presence / typing / read / message
chat.onopen = () => chat.send(JSON.stringify({ type: "message", body: "Hello, channel." }));

// 4. History: backfill on reconnect.
const older = await fetch(cfg.messages.replace("{id}", "42") + "?limit=50",
  { headers: { Authorization: `Bearer ${jwt}` } }).then(r => r.json());
```

Start it the usual way -- the WebSockets run alongside the HTTP server:

```bash
tina4 serve
```

---

## 11. Footguns / Hard Rules

- **Ruby is mesh-only; `TINA4_RTC_BACKEND` is ignored.** `mount` has **no `media:` param**, and the path map and config body hardcode `"backend" => "mesh"`. Setting `TINA4_RTC_BACKEND` does nothing in Ruby (it exists for cross-language config parity). An SFU/LiveKit backend is a future drop-in, not a Phase-1 option here.
- **Chat needs a bound database -- but a missing one does NOT crash boot.** With `features:` that include `chat`/`files`, `ensure_chat_tables` runs at mount; if no DB is bound it **logs an error and continues**. `mount` still returns the full path map and registers every route -- the failure only surfaces at query time. Bind a DB (`Tina4.bind_database(db)` / `TINA4_DATABASE_URL`) **before** calling `mount(features: [...])`, or chat/history/files will error per request while the app looks healthy.
- **The signalling WS (`/ws/rtc/{room}`) is PUBLIC.** It is not `.secure`, so anyone can join any room and receive relayed signalling frames. Only the **chat** WS is JWT-secured. Gate call access at the app layer if you need it.
- **The config endpoint (`/api/rtc/config`) is PUBLIC** and returns your ICE/TURN config, including freshly-minted ephemeral TURN credentials.
- **The WS handler signature is `(connection, event, data)` and `event` is a Symbol** (`:open` / `:message` / `:close`); `data` is the payload String on `:message`, `nil` otherwise. This is the Ruby framework convention -- **not** `(connection, data, event)`. (The PHP port fires `($connection, $data, $event)` -- argument order differs across languages.)
- **Channels are addressed by integer id.** A non-integer `{channel}` makes the chat handler return silently (no error frame) -- the client sees a socket that opens and does nothing.
- **Chat authorization is re-checked on every frame**, and identity is always taken from the verified token (`connection.auth` / `request.user`), never from the message payload. Keep a custom `authorize:` cheap.
- **A message with an empty/whitespace `body` is silently dropped** (no persist, no broadcast). `read` / `typing` / unknown types never persist anything.
- **Upload is protected by the default write gate, not `.secure`; download IS `.secure`.** Do not add `.no_auth` to the upload route thinking it needs auth added -- writes already require a token. The download route needs `.secure` only because a `GET` is public by default.
