# Chapter 38: Real-time Collaboration (WebRTC)

## 1. The Media Server You Do Not Have to Run

You want a call button. Two people click it and they are talking: audio, video, a shared screen. Next to the call sits a chat panel and a place to drop a file. This is the Slack shape, the Teams shape, and the usual advice is heavy. Stand up a media server. Wire in TURN. Operate all of it.

You do not need any of that to start. Modern browsers already speak WebRTC to each other directly, peer to peer. What they cannot do is *find* each other. One browser has to hand its connection offer to the other and get an answer back. That hand-off is called **signalling**, and it is a tiny amount of text relayed through a server. The media itself, the actual audio and video, never touches your server. It flows browser to browser.

`Tina4::Realtime` is that relay, plus the two things every collaboration tool needs around a call: persistent **chat** and permissioned **file** transfer. It shipped in tina4-ruby 3.13.57, carries zero extra dependencies, and mounts with one line. Media is peer to peer, a **mesh**. Tina4 carries no media and never parses your SDP. It forwards the handshake and nothing more.

**Ruby is mesh-only.** There is one media backend, and `mount` has no `media:` parameter. An SFU backend is a future drop-in, not a Phase-1 option here. The rest of this chapter is the backend surface. The browser side is the tina4-js `rtc` module, which fetches `/api/rtc/config` and discovers every path from there, so the client never hardcodes a URL.

---

## 2. What You Get, and How It Differs from Raw WebSocket

The WebSocket chapter gave you the raw `Tina4::Router.websocket` primitive: a path, a handler, a `(connection, event, data)` block. That is the tool you reach for when you build your *own* protocol. `Tina4::Realtime` is the opposite end. It is a *pre-built* protocol for calls, chat, and files, assembled from that same primitive underneath.

The module gives you three surfaces, and you enable only the ones you want:

- **calls** - a WebRTC signalling relay (mesh, peer to peer) plus a self-describing ICE-config endpoint. The relay forwards offer, answer, and ICE frames between peers in a room. It is public: no login to join a room.
- **chat** - persistent channels and messages backed by framework-owned ORM models, a secured chat WebSocket with live presence, typing, and read receipts, and a history endpoint for catch-up on reconnect.
- **files** - permissioned upload and download through a pluggable storage backend (local filesystem by default, S3-compatible optional).

The distinction in one line: with `Tina4::Router.websocket` you write the handler and invent the message protocol; with `Tina4::Realtime.mount` the protocol is written for you and the browser discovers every path from one config endpoint. Under the hood the realtime WebSockets *are* Tina4 WebSockets. Same `(connection, event, data)` convention, same room manager. You are handed the handlers pre-written.

This is a cross-language feature. The same paths, JSON shapes, env vars, and `tina4_rt_*` tables exist in tina4-python, tina4-php, and tina4-nodejs. Python is the reference implementation, and the Ruby-specific differences are called out in the footguns at the end.

---

## 3. Mounting the Module: `Tina4::Realtime.mount`

Call `mount` once at boot, in `app.rb`, after `Tina4.initialize!` and `Tina4.bind_database`, before the server starts. It registers the routes and WebSockets and returns the resolved path map, a Hash with String keys. That is the same map the config endpoint later serves back to clients.

```ruby
Tina4::Realtime.mount(prefix: "", authorize: nil, storage: nil, features: nil)
```

```ruby
Tina4::Realtime.mount                                          # calls only (default)
Tina4::Realtime.mount(features: %w[calls chat])                # add persistent chat
Tina4::Realtime.mount(prefix: "/api/collab",
                      features: %w[calls chat files])          # relocate the whole surface
```

| Keyword | Meaning |
|---|---|
| `prefix:` | Mounts the whole surface under this path. Leading and trailing slashes are stripped, so `"/api/collab"` and `"api/collab/"` both resolve to `/api/collab`. Default `""` (root). |
| `authorize:` | Membership guard `->(identity, channel_id) { true_or_false }` used by **chat** and **files**. `identity` is the String user id from the JWT. Defaults to a `ChannelMember` membership check. |
| `storage:` | A `StorageBackend` instance for the **files** feature. Defaults to the env-selected store (`local`). |
| `features:` | Array of any of `"calls"`, `"chat"`, `"files"`. Default `["calls"]`. |

The return value is the resolved path map, so you log it or assert against it. Base paths are String-keyed; the config endpoint later appends the `{room}`, `{channel}`, and `{id}` template tokens for the client:

```ruby
Tina4::Realtime.mount
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "signalling"=>"/ws/rtc"}

Tina4::Realtime.mount(features: %w[calls chat])
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "signalling"=>"/ws/rtc",
#     "chat"=>"/ws/chat", "messages"=>"/api/channels"}

Tina4::Realtime.mount(features: %w[files])
# => {"backend"=>"mesh", "config"=>"/api/rtc/config", "files"=>"/api/files"}
```

`config` is added by any enabled feature. `calls` sets it outright; `chat` and `files` set it with `||=`. So even a chat-only or files-only mount still exposes `/api/rtc/config`.

### What each feature wires

| Feature | Route registered | Auth |
|---|---|---|
| any (has `config`) | `GET  {p}/api/rtc/config` | public (no `.secure`) |
| `calls` | `WS   {p}/ws/rtc/{room}` | public (unauthenticated) |
| `chat` | `WS   {p}/ws/chat/{channel}` | secured - `.secure`, valid JWT on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` | secured - `.secure` |
| `files` | `POST {p}/api/files` (upload) | write route - default bearer-token gate |
| `files` | `GET  {p}/api/files/{key}` (download) | secured - `.secure` |

If `chat` or `files` is enabled, `ensure_chat_tables` runs at mount and creates the `tina4_rt_*` tables. A missing database logs an error and does not crash boot. That footgun waits for you at the end of the chapter.

---

## 4. The Config Bootstrap: `GET {p}/api/rtc/config`

This is the one URL the frontend has to know. It fetches the config, reads back the paths and ICE servers, and drives everything else from there. The client and server never drift, because the server is the single source of truth for its own routes. Move `prefix:` on the server and the client follows.

The body is feature-gated. Only keys for enabled features appear.

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

`{room}`, `{channel}`, and `{id}` are literal template tokens the client substitutes with a real room name, channel id, or message id before connecting.

This endpoint is public. No token required, because the client needs the ICE config before it has authenticated anyone into a call. It returns your ICE and TURN configuration, including freshly-minted ephemeral TURN credentials. That is by design, and it is exactly why those credentials are short-lived.

```js
// Browser: discover everything from one fetch, then wire the sockets.
const cfg = await fetch("/api/rtc/config").then(r => r.json());

const signallingUrl = cfg.signalling.replace("{room}", roomId);   // /ws/rtc/room-42
const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });
const ws = new WebSocket(`wss://${location.host}${signallingUrl}`);
```

---

## 5. ICE and TURN Servers: `Tina4::Realtime.ice_servers`

Before two browsers connect, each gathers candidate addresses using **ICE**. A **STUN** server tells a browser its public address. Peers on the same network find each other with STUN alone. A **TURN** server relays media when a direct path is impossible: strict NAT, symmetric firewalls. `ice_servers` builds the list the client hands to `RTCPeerConnection`, straight from the environment.

It always includes a STUN entry. It adds a TURN entry only when both `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set. TURN credentials use the coturn `use-auth-secret` scheme: a time-limited username and credential pair minted on each request, so you never ship static TURN passwords to the browser.

```ruby
username   = (Time.now.to_i + ttl).to_s                                   # expiry epoch
credential = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", secret, username))
```

```ruby
# No TURN env set - STUN only:
Tina4::Realtime.ice_servers
# => [{"urls"=>["stun:stun.l.google.com:19302"]}]

# TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
# => [{"urls"=>["stun:stun.l.google.com:19302"]},
#     {"urls"=>["turn:turn.example.com:3478"], "username"=>"1783546725", "credential"=>"ie7Mm...=="}]
```

STUN and TURN URLs are comma-separated in the env and split into arrays.

### Environment variables

| Var | Default | Effect |
|---|---|---|
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | - | Comma-separated TURN URLs; enables TURN when set together with the secret. |
| `TINA4_RTC_TURN_SECRET` | - | coturn `use-auth-secret` shared secret (drives the ephemeral credentials). |
| `TINA4_RTC_TURN_TTL` | `3600` | Ephemeral TURN credential lifetime, in seconds. |
| `TINA4_RTC_BACKEND` | - | Read only for cross-language config parity; Ruby ignores it. The backend is always `mesh`. |

```bash
# Enable a coturn relay for peers behind symmetric NAT.
export TINA4_RTC_TURN_URL="turn:turn.example.com:3478"
export TINA4_RTC_TURN_SECRET="a-long-random-shared-secret"
export TINA4_RTC_TURN_TTL="3600"
```

---

## 6. Signalling: The Mesh Relay

This is the relay that lets two browsers negotiate a peer connection. It registers at `WS {p}/ws/rtc/{room}` with `Tina4::Router.websocket`, and it is not `.secure`, so it is public. Anyone can join any room. The Ruby WebSocket convention is `(connection, event, data)` where `event` is a **Symbol**:

```ruby
# connection : the WebSocket connection
# event      : :open | :message | :close
# data       : the payload String on :message; nil on :open / :close
```

The whole handler is a mesh relay. It moves opaque frames between peers and gets out of the way:

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

The behaviour is deliberately minimal:

- `room = connection.params[:room].to_s`. An empty room is a no-op, and the handler returns.
- `:open` calls `connection.join_room("rtc:#{room}")`.
- `:message` calls `connection.broadcast_to_room("rtc:#{room}", data, exclude_self: true)`, relaying the raw payload to the other peers untouched.

Tina4 never parses the SDP. Peers address each other by putting a `to` field in their own frames and filtering on it. Rooms are namespaced `rtc:<room>` so signalling rooms never collide with chat channels, which use `chat:<channel>`, on the shared WebSocket manager.

The socket is public and the room is a URL segment, so treat the room id as a capability. Gate call access at your app layer if a call must be private: issue unguessable room ids, or check membership before you hand the client a room name.

---

## 7. Chat: Secured Channels, Presence, History

Chat is the opposite of signalling: secured. The chat socket registers with `.secure`, so a valid JWT is required on the upgrade. The router rejects an unauthenticated upgrade before the handler ever runs. The handler is `chat_handler(connection, event, data)`.

- Channels are addressed by **integer id**. The handler requires `connection.params[:channel]` to match `\A\d+\z`. A non-integer channel makes the handler return silently: the socket opens and does nothing, no error frame.
- `identity = Tina4::Realtime.identity(connection.auth)`, the String id from the verified token.
- The room key is `chat:<channel_id>`.

Every inbound frame is a JSON object. Every broadcast is a `.to_json` String.

| Event / message `"type"` | Server behaviour |
|---|---|
| `:open` | Authorize. Fail: send `{"type":"error","error":"not a member of this channel"}` then `close`. OK: `join_room`, send the caller the roster `{"type":"presence","event":"roster","users":[...]}`, then broadcast `{"type":"presence","event":"join","user_id":<id>}` (exclude self). |
| `:close` | Broadcast `{"type":"presence","event":"leave","user_id":<id>}` (exclude self). |
| `"typing"` | Broadcast `{"type":"typing","user_id":<id>}` (exclude self). |
| `"read"` | Advance the member's read cursor (`last_read_at = now`), broadcast `{"type":"read","user_id":<id>,"at":<iso8601>}` (exclude self). |
| `"message"` | Strip `body`; empty or whitespace is silently dropped. Otherwise persist a `Message` row and broadcast `{"type":"message","message":<saved>}` to everyone including the sender, so the sender's optimistic message reconciles with its server `id` and `created_at`. |

`"type"` defaults to `"message"` when absent. Unknown types are ignored, and non-Hash payloads are ignored.

Authorization is re-checked on every inbound `:message` frame, not just on join. Membership can be revoked mid-session, and the server never trusts an identity carried in the payload. The roster is the sorted, de-duplicated set of authenticated identities currently in the room, collected from each live connection's `auth`.

A saved message, the shape broadcast and returned by history, looks like this:

```jsonc
{ "id": 42, "channel_id": 7, "user_id": "12", "body": "hi team",
  "thread_id": null, "created_at": "2026-07-08T10:15:00Z" }
```

`thread_id` is `null` for a top-level message, or the parent message id for a threaded reply.

### Chat history: `GET {p}/api/channels/{id}/messages`

The catch-up-on-reconnect endpoint. A client opens the socket for live traffic and calls this to backfill what it missed.

- Identity comes from `request.user`, the router-attached, verified JWT payload.
- `channel_id <= 0` returns 400. Not authorized returns 403. Otherwise the message list.
- Query params: `before` (return messages with `id < before`) and `limit` (default 50, floored at 1, capped at 200).
- Messages come back newest-first, the standard infinite-scroll-backwards shape. Each item uses the saved-message JSON above.

```bash
# Page backwards from message id 900, 50 at a time.
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7147/api/channels/42/messages?before=900&limit=50"
```

---

## 8. Files: Upload and Download

Enable with `features: %w[files]`. Files store through a `StorageBackend`: the `storage:` argument, or the env-selected store, default `LocalStorage`. The backend resolves once at mount via `Tina4::Realtime::Storage.select(storage)`.

### `POST {p}/api/files` - upload

Multipart: a file field named `file`, plus a form field `channel_id` (required, integer). Invalid or missing `channel_id` returns 400; not a channel member returns 403; no file returns 400. The blob stores under an opaque, collision-free `storage_key` (`SecureRandom.hex(16)` plus a sanitized, length-capped extension, never a user-controlled path). An `Attachment` row records the metadata only, never the blob. It responds 201:

```jsonc
{ "id": 9, "key": "3f8c...e1.png", "filename": "diagram.png",
  "mime": "image/png", "size": 20481,
  "url": "/api/files/3f8c...e1.png" }
```

`url` is `store.url(key)` when the backend exposes a direct URL (an S3 presigned URL, say), otherwise the app download route `{files}/{key}`.

This route registers with `Tina4::Router.post` without `.no_auth`, so the default write-route bearer gate applies: a tokenless upload 401s.

```bash
curl -X POST http://localhost:7147/api/files \
  -H "Authorization: Bearer $JWT" \
  -F "channel_id=42" \
  -F "file=@./diagram.png"
```

### `GET {p}/api/files/{key}` - download (secured)

- Looks up the `Attachment` by `storage_key`; missing returns 404. Authorizes against the attachment's `channel_id`; a non-member returns 403.
- If the backend has a direct URL, it 302-redirects to it. Otherwise it streams the bytes (200) with `Content-Disposition: inline; filename="..."` and `Content-Type` from `attachment.mime` (default `application/octet-stream`). A missing blob on disk returns 404.

The download route needs `.secure` because a `GET` is public by default. The upload does not, because writes already require a token.

### Storage backends

`Tina4::Realtime::Storage.select(storage = nil)` resolves from the `storage:` argument or `TINA4_STORAGE_BACKEND` (`local` default, `s3`). An `s3` backend that cannot be built (the `aws-sdk-s3` gem is missing, or the config is incomplete) falls back to `LocalStorage` with a warning. A real persistent store, never a silent no-op. Ruby rescues both `StandardError` and `LoadError` here, because a missing gem raises `LoadError`, which is not a `StandardError`.

| Var | Default | Effect |
|---|---|---|
| `TINA4_STORAGE_BACKEND` | `local` | `local` or `s3`. |
| `TINA4_STORAGE_DIR` | `data/rt_storage` | Local filesystem directory. |
| `TINA4_STORAGE_URL` | - | S3 endpoint URL (S3-compatible / MinIO); `force_path_style` is on. |
| `TINA4_STORAGE_KEY` / `TINA4_STORAGE_SECRET` | - | S3 credentials. |
| `TINA4_STORAGE_BUCKET` | - | S3 bucket (required for S3; raises `ArgumentError` if absent). |
| `TINA4_STORAGE_REGION` | `us-east-1` | S3 region. |

`LocalStorage` resolves every key inside its root and rejects path traversal (it raises `ArgumentError` on an unsafe key); its `url` returns `nil`, so blobs serve through the permissioned download route. `S3Storage` returns a presigned GET URL from `url`, so clients fetch large blobs straight from object storage and skip your app server.

You can also pass a custom backend instance directly:

```ruby
Tina4::Realtime.mount(features: %w[chat files], storage: MyStorageBackend.new)
```

---

## 9. Auth, Identity, and the Data Model

Identity is always taken from the verified token, never from the message body. Two pieces make membership work: how an identity is extracted, and how membership is checked.

**Extracting identity, `Tina4::Realtime.identity(auth)`.** It pulls a stable String user id from a verified JWT payload, trying the claims `user_id`, then `sub`, then `id` (String or Symbol keys). It returns `nil` when `auth` is not a Hash or none of those claims are present. Identities round-trip as Strings, so an integer id, a UUID, or an email all fit. WebSocket identity comes from `connection.auth`, the verified payload the router attached on the secured upgrade. HTTP identity comes from `request.user`, also router-attached. Ruby matches the PHP and Node ports here: it does not re-parse the `Authorization` header the way Python's HTTP handlers do.

**Checking membership, `Tina4::Realtime.authorized?(identity, channel_id)`.** This is the shared guard for chat channels and file access. A `nil` identity is always denied. If a custom `authorize:` Proc was passed to `mount`, it wins (`!!proc.call(identity, channel_id)`); otherwise the secure default requires channel membership:

```ruby
ChannelMember.count("channel_id = ? AND user_id = ?", [channel_id, identity]).positive?
```

Any exception logs and returns `false` (deny). Because the guard runs on every inbound chat frame, a custom `authorize:` must be cheap.

```ruby
# Open every channel to any logged-in user (skip the per-channel membership check).
Tina4::Realtime.mount(
  features: %w[calls chat],
  authorize: ->(identity, _channel_id) { !identity.nil? }   # keep it cheap - runs per frame
)
```

### Data model

The chat and files features own a small set of `Tina4::ORM` models, all with the `tina4_rt_` table prefix so they never collide with your app's own tables. Ruby is snake_case end to end: columns, attributes, and JSON keys match with no mapping layer. Tables are created on demand at mount (`ensure_chat_tables` iterates them in dependency order).

| Model | Table | Key fields |
|---|---|---|
| `Workspace` | `tina4_rt_workspaces` | `id`, `name`, `created_at` |
| `Channel` | `tina4_rt_channels` | `id`, `workspace_id`, `name`, `kind` (`public`/`private`/`dm`, default `public`), `created_at` |
| `ChannelMember` | `tina4_rt_channel_members` | `id`, `channel_id`, `user_id` (String, <=128), `role` (default `member`), `last_read_at` (read cursor) |
| `Message` | `tina4_rt_messages` | `id`, `channel_id`, `user_id` (String), `body` (Text), `thread_id` (nullable parent id), `created_at`, `edited_at` (nullable) |
| `Attachment` | `tina4_rt_attachments` | `id`, `channel_id`, `message_id` (nullable), `storage_key`, `filename`, `mime`, `size`, `thumb_key` (nullable) |

`workspace_id` and `channel_id` are plain integer FK columns queried directly, no ORM relationship wiring, because the control plane does not need it. `user_id` is a String everywhere, so any JWT identity shape fits.

Because these are ordinary Tina4 ORM models, you seed a workspace, a channel, and its members exactly as in the ORM chapter. `save` returns the model on success, so you chain straight through to the fresh `id`:

```ruby
ws = Tina4::Realtime::Workspace.new(name: "Acme").save
channel = Tina4::Realtime::Channel.new(
  workspace_id: ws.id, name: "general", kind: "public"
).save
Tina4::Realtime::ChannelMember.new(
  channel_id: channel.id, user_id: "12", role: "owner"
).save
```

Now user `12` can open `WS /ws/chat/#{channel.id}` and pass the history and file checks.

---

## 10. A Complete Example

A mesh video call with a chat side-panel, using only the browser's built-in `RTCPeerConnection` and `WebSocket`. No client library required.

### Backend - `app.rb`

Mount the surface after the database is bound, and seed one channel so chat has somewhere to land.

```ruby
# app.rb - after Tina4.initialize! and a bound database.
require "tina4"

# Chat/files need a bound DB BEFORE mount(features: [...]) - see the footguns.
Tina4.bind_database(Tina4::Database.new("sqlite://data/app.db"))

paths = Tina4::Realtime.mount(features: %w[calls chat files])
Tina4::Log.info("realtime mounted: #{paths.inspect}")

# One-time seed so a channel + member exist.
if Tina4::Realtime::Channel.where("name = ?", ["general"], limit: 1).empty?
  ws = Tina4::Realtime::Workspace.new(name: "Acme").save
  channel = Tina4::Realtime::Channel.new(
    workspace_id: ws.id, name: "general", kind: "public"
  ).save
  Tina4::Realtime::ChannelMember.new(
    channel_id: channel.id, user_id: "12", role: "owner"
  ).save
end
```

### Browser - bootstrap from the config endpoint

The client fetches `/api/rtc/config` first and never hardcodes a path.

```js
// 1. Discover paths + ICE servers (public endpoint).
const cfg = await (await fetch("/api/rtc/config")).json();

// 2. Open the signalling socket for a room (public, no token).
const room = "standup";
const wsUrl = location.origin.replace(/^http/, "ws")
            + cfg.signalling.replace("{room}", room);
const signal = new WebSocket(wsUrl);

// 3. One RTCPeerConnection per call, using the server's ICE list.
const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });

pc.onicecandidate = (e) => {
  if (e.candidate) signal.send(JSON.stringify({ kind: "ice", candidate: e.candidate }));
};
pc.ontrack = (e) => { document.getElementById("remote").srcObject = e.streams[0]; };

// 4. Handle relayed signalling frames. Tina4 forwards raw payloads verbatim.
signal.onmessage = async (evt) => {
  const msg = JSON.parse(evt.data);
  if (msg.kind === "offer") {
    await pc.setRemoteDescription(msg.sdp);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    signal.send(JSON.stringify({ kind: "answer", sdp: answer }));
  } else if (msg.kind === "answer") {
    await pc.setRemoteDescription(msg.sdp);
  } else if (msg.kind === "ice") {
    await pc.addIceCandidate(msg.candidate);
  }
};

// 5. The caller adds their camera/mic and sends an offer.
async function startCall() {
  const media = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
  document.getElementById("local").srcObject = media;
  media.getTracks().forEach((t) => pc.addTrack(t, media));
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  signal.send(JSON.stringify({ kind: "offer", sdp: offer }));
}
```

### Browser - the chat side-panel (secured, needs a JWT)

The chat upgrade carries the bearer token in the WebSocket subprotocol, the browser-friendly transport Tina4 accepts.

```js
const channelId = 42;                      // integer id, not a name
const chatUrl = location.origin.replace(/^http/, "ws")
              + cfg.chat.replace("{channel}", channelId);
const chat = new WebSocket(chatUrl, ["bearer", jwt]);   // WS carries the JWT

chat.onmessage = (evt) => {
  const m = JSON.parse(evt.data);
  if (m.type === "message")  addLine(m.message.user_id, m.message.body);
  if (m.type === "presence") renderRoster(m);   // roster / join / leave
  if (m.type === "typing")   showTyping(m.user_id);
  if (m.type === "error")    console.warn(m.error);   // e.g. not a member
};

function send(text) { chat.send(JSON.stringify({ type: "message", body: text })); }
```

Start it the usual way. The WebSockets run alongside the HTTP server:

```bash
tina4ruby serve
```

The signalling socket is public: anyone with the room name joins. The chat socket and the history and file endpoints require a valid JWT and channel membership. Two browser tabs, both members of channel `42`, joined to room `standup`, see each other's video peer to peer and each other's messages through the relay.

---

## 11. Footguns and Hard Rules

**Ruby is mesh-only; `TINA4_RTC_BACKEND` is ignored.** `mount` has no `media:` param, and the path map and config body hardcode `"backend" => "mesh"`. Setting `TINA4_RTC_BACKEND` does nothing in Ruby; it exists for cross-language config parity. An SFU/LiveKit backend is a future drop-in, not a Phase-1 option here.

**Chat needs a bound database, but a missing one does not crash boot.** With `features:` that include `chat` or `files`, `ensure_chat_tables` runs at mount. If no DB is bound, it logs an error and continues. `mount` still returns the full path map and registers every route, so the failure surfaces only at query time. Bind a DB (`Tina4.bind_database(db)` or `TINA4_DATABASE_URL`) before calling `mount(features: [...])`, or chat, history, and files will error per request while the app looks healthy.

**The signalling WebSocket is public.** `/ws/rtc/{room}` is not `.secure`, so anyone can join any room and receive relayed signalling frames. Only the chat WebSocket is JWT-secured. Gate call access at your app layer if you need it.

**The config endpoint is public.** `/api/rtc/config` returns your ICE and TURN config, including freshly-minted ephemeral TURN credentials. That is by design, which is exactly why the TURN credentials are time-limited (`TINA4_RTC_TURN_TTL`).

**The WS handler signature is `(connection, event, data)` and `event` is a Symbol** (`:open`, `:message`, `:close`); `data` is the payload String on `:message`, `nil` otherwise. This is the Ruby framework convention, not `(connection, data, event)`. The PHP port fires `($connection, $data, $event)`, so argument order differs across languages.

**Channels are addressed by integer id.** A non-integer `{channel}` makes the chat handler return silently, no error frame. The client sees a socket that opens and does nothing. Pass the numeric channel id, never its name.

**Chat authorization is re-checked on every frame**, and identity is always taken from the verified token (`connection.auth` / `request.user`), never from the message payload. Keep a custom `authorize:` cheap.

**A message with an empty or whitespace `body` is silently dropped**: no persist, no broadcast. `read`, `typing`, and unknown types never persist anything.

**Upload is protected by the default write gate, not `.secure`; download is `.secure`.** Do not add `.no_auth` to the upload route thinking it needs auth added; writes already require a token. The download route needs `.secure` only because a `GET` is public by default.

---

## Where to Go Next

- **The WebSocket chapter** - the raw `Tina4::Router.websocket` primitive these handlers are built on, and the connection API (`join_room`, `broadcast_to_room`, `send_json`).
- **The ORM chapter and the Authentication chapter** - you seed workspaces, channels, and members with the ORM, and the JWT that secures chat is the same one from the auth chapter.
- **The tina4-js `rtc` module** - the browser side, which fetches `GET /api/rtc/config` so the client and server never drift on paths.

You started this chapter wanting a call button. You end it with calls, chat, presence, read receipts, history, and file transfer, mounted in one line, carrying no media, running no server you did not already have. The hard part of real-time was never the video. It was finding the other browser, and Tina4 relays that in a few lines of text.
