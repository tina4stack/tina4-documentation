# Chapter 39: Real-time Collaboration (WebRTC)

## 1. The Media Server You Don't Have to Run

You want a call button. Two people click it and they are talking - audio, video, a shared screen. Alongside the call there is a chat panel and a place to drop a file. This is the Slack/Teams shape, and the usual advice is to stand up a media server (an SFU like LiveKit or Janus), wire in TURN, and operate all of it.

You do not need any of that to start. Modern browsers already speak WebRTC to each other directly, peer-to-peer. What they cannot do is *find* each other - one browser has to hand its connection offer to the other, and get an answer back. That hand-off is called **signalling**, and it is a tiny amount of text relayed through a server. The media itself - the actual audio and video - never touches your server. It flows browser-to-browser.

Tina4's realtime module is exactly that relay, plus the two things every collaboration tool needs around a call: persistent **chat** and permissioned **file** transfer. It ships in **3.13.57**, has zero extra dependencies, and mounts with one line. Media is peer-to-peer (a **mesh**) by default. Tina4 carries no media and never parses your SDP - it only forwards the handshake. If you outgrow mesh, an SFU backend drops in later with no route changes.

---

## 2. What You Get (and How It Differs from Raw WebSocket)

Chapter 23 gave you the raw `@websocket` primitive: a decorator, a handler, a path. That is the tool you reach for when you are building your *own* protocol. The realtime module is the opposite end - it is a *pre-built* protocol for calls, chat, and files, assembled from that same primitive underneath.

The module gives you three surfaces, and you enable only the ones you want:

- **calls** - a WebRTC **signalling relay** (mesh, peer-to-peer) plus a self-describing ICE-config endpoint. The relay forwards offer/answer/ICE frames between peers in a room. It is **public** - no login to join a room.
- **chat** - persistent channels and messages backed by framework-owned ORM models, a **secured** chat WebSocket with live presence / typing / read receipts, and a history endpoint for catch-up-on-reconnect.
- **files** - permissioned upload and download through a pluggable storage backend (local filesystem by default, S3-compatible optional).

The distinction from Chapter 23 in one line:

| Chapter 23 - `@websocket` | Chapter 39 - `realtime()` |
|---|---|
| You write the handler and the message protocol | The protocol (signalling, presence, receipts, persistence) is written for you |
| One path, one decorator, no auth or storage | A whole surface: config endpoint, WS routes, HTTP routes, ORM models, storage |
| Nothing is persisted unless you persist it | Chat messages and file metadata persist to `tina4_rt_*` tables |
| You invent the client contract | The client discovers every path from `GET /api/rtc/config` |

Under the hood the realtime WebSockets *are* Tina4 WebSockets - same `(connection, event, data)` handler convention, same room manager. You are just handed the handlers pre-written.

This backend pairs with the frontend **tina4-js `rtc` module**, whose `rtcConfig()` helper fetches the config endpoint so the client and server never drift on paths. Do the backend here; do the browser side in tina4-js (or with the plain browser APIs shown in section 10).

---

## 3. Mounting the Module: `realtime()`

Call `realtime()` once in `app.py`, **before `run()`**. It registers the routes and returns the resolved path map.

```python
from tina4_python.realtime import realtime

realtime()                                                           # calls only (default)
realtime(features=["calls", "chat"])                                 # add persistent chat
realtime(prefix="/api/collab", features=["calls", "chat", "files"])  # relocate the whole surface
```

The full signature:

```python
realtime(prefix="", *, media=None, authorize=None, storage=None, features=None) -> dict
```

| Parameter | Meaning |
|---|---|
| `prefix` | Mounts the whole surface under `/<prefix>` (default: root). Internally `prefix.strip("/")`, so `"/api/collab"` and `"api/collab"` behave the same. |
| `media` | An `RtcMediaBackend`. Defaults to the env-selected backend (`mesh` in Phase 1). Pass one to override the env entirely. |
| `authorize` | Membership guard `authorize(identity, channel_id) -> bool` (sync **or** async) used by `chat` and `files`. Defaults to a `ChannelMember` check. `identity` is the **string** user id from the JWT. |
| `storage` | A `StorageBackend` for the `files` feature. Defaults to the env-selected store (`local`). |
| `features` | List; any of `"calls"`, `"chat"`, `"files"`. **Defaults to `["calls"]`.** |

The call **returns the resolved path map** - the same map the config endpoint serves, so you can log it or assert against it:

```python
realtime()
# -> {'backend': 'mesh', 'config': '/api/rtc/config', 'signalling': '/ws/rtc'}

realtime(features=['calls', 'chat'])
# -> {'backend': 'mesh', 'config': '/api/rtc/config',
#     'signalling': '/ws/rtc', 'chat': '/ws/chat', 'messages': '/api/channels'}

realtime(prefix='/api/collab', features=['calls', 'chat', 'files'])
# -> every path prefixed with /api/collab
```

`config` is added by **any** enabled feature - `calls` sets it outright; `chat` and `files` add it with `setdefault`. So even a chat-only mount exposes `/api/rtc/config`.

### What each feature wires

| Feature | Route registered | Auth |
|---|---|---|
| any | `GET  {p}/api/rtc/config` → `rtc_config` | **public** (no auth) |
| `calls` | `WS   {p}/ws/rtc/{room}` → `rtc_signalling` | **public** (unauthenticated) |
| `chat` | `WS   {p}/ws/chat/{channel}` → `chat_ws` | **secured** - valid JWT required on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` → `chat_history` | `auth_required=True` |
| `files` | `POST {p}/api/files` → `files_upload` | `auth_required=True` |
| `files` | `GET  {p}/api/files/{key}` → `files_download` | `auth_required=True` |

If `chat` or `files` is enabled, the framework creates its chat tables at mount time (see section 11 - a missing database logs an error but does **not** crash boot).

---

## 4. The Config Bootstrap: `GET /api/rtc/config`

The client never hardcodes a URL. It fetches this one public endpoint, and everything else - the signalling path, the ICE servers, the chat and messages and files paths - comes back in the response. Move `prefix` on the server and the client follows automatically.

The body is **feature-gated**: only keys for enabled features appear.

```jsonc
{
  "backend": "mesh",
  "iceServers": [ /* ...ice_servers()... */ ],   // calls
  "signalling": "/ws/rtc/{room}",                 // calls
  "chat": "/ws/chat/{channel}",                   // chat
  "messages": "/api/channels/{id}/messages",      // chat
  "files": "/api/files"                            // files
}
```

The `{room}` / `{channel}` / `{id}` are **literal template tokens** - the client substitutes the real room name, channel id, or message id before connecting.

This endpoint is **public**, and it returns your ICE/TURN configuration including freshly-minted ephemeral TURN credentials (section 5). That is intentional - the browser needs those before it can authenticate anywhere - but it means the credentials are short-lived by design.

---

## 5. ICE and TURN Servers

Before two browsers can connect, each gathers candidate addresses using **ICE**. A **STUN** server tells a browser its public address; a **TURN** server relays media when a direct path is impossible (strict NAT, symmetric firewalls). The realtime module builds this list from environment variables via `ice_servers()`.

`ice_servers()` **always** includes a STUN entry. It adds a TURN entry **only when both** `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set, using coturn's `use-auth-secret` scheme with time-limited credentials:

- `username = str(int(time.time()) + ttl)` - an expiry epoch.
- `credential = base64(HMAC_SHA1(secret, username))`.

```python
# No TURN env - STUN only:
[{'urls': ['stun:stun.l.google.com:19302']}]

# TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
[{'urls': ['stun:stun.l.google.com:19302']},
 {'urls': ['turn:turn.example.com:3478'],
  'username': '1783546725',
  'credential': 'ie7Mm...=='}]
```

### Environment variables

```bash
# .env
TINA4_RTC_BACKEND=mesh                          # only 'mesh' ships in Phase 1
TINA4_RTC_STUN_URLS=stun:stun.l.google.com:19302
TINA4_RTC_TURN_URL=turn:turn.example.com:3478   # enables TURN when paired with the secret
TINA4_RTC_TURN_SECRET=your-coturn-shared-secret
TINA4_RTC_TURN_TTL=3600                          # ephemeral credential lifetime (seconds)
```

| Var | Default | Effect |
|---|---|---|
| `TINA4_RTC_BACKEND` | `mesh` | Media backend name. Only `mesh` ships in Phase 1 - an unknown name falls back to `mesh`, never failing boot. |
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | - | Comma-separated TURN URLs; enables TURN when set together with the secret. |
| `TINA4_RTC_TURN_SECRET` | - | coturn `use-auth-secret` shared secret (drives the ephemeral credentials). |
| `TINA4_RTC_TURN_TTL` | `3600` | Ephemeral TURN credential lifetime, in seconds. |

### Media backends

The media backend is a strategy object:

- **`RtcMediaBackend`** - the interface. `name = "mesh"`; `mint_join(room, identity)` returns `None` (mesh has no media server to authenticate against); `ice_servers()` delegates to the module-level `ice_servers()`.
- **`MeshBackend(RtcMediaBackend)`** - the default, zero-dependency backend. Browsers connect peer-to-peer in a mesh.
- **`_select_backend(media)`** - an explicit `media=` argument wins; otherwise it reads `TINA4_RTC_BACKEND`. **Any unknown name falls back to `MeshBackend`** - it never fails boot.

An SFU/LiveKit backend that returns a real join token is the documented Phase-2 drop-in, and because signalling paths are unchanged, the client keeps working.

---

## 6. Signalling: The Mesh Relay

The signalling handler is registered at `WS {p}/ws/rtc/{room}` and is **public** - anyone can join any room. It follows the framework's WebSocket handler convention (the same as Chapter 23):

```python
async def rtc_signalling(connection, event, data):
    # connection : the WebSocketConnection
    # event      : "open" | "message" | "close"
    # data       : payload (str for "message", None for "open"/"close")
    ...
```

Its behaviour is deliberately minimal - a raw relay:

- Reads `room = connection.params.get("room", "")`. An empty room is a no-op.
- On `"open"` → `connection.join_room("rtc:<room>")`.
- On `"message"` → `await connection.broadcast_to_room("rtc:<room>", data, exclude_self=True)` - it forwards the **raw** payload to the other peers in the room, untouched.

Tina4 never parses the SDP. Peers put a `to` field in their own frames and filter for themselves. Rooms are namespaced `rtc:<room>` so signalling rooms never collide with chat channels (which use `chat:<channel>`) on the shared WebSocket manager.

The connection surface these handlers use: `connection.params`, `connection.auth`, `connection.join_room(name)`, `connection.broadcast_to_room(name, message, exclude_self=...)`, `connection.send_json(data)`, and `connection.close()`.

Because signalling is public, the room name is your only barrier. If a call must be private, gate access at your app layer (issue unguessable room ids, or check membership before you hand the client a room name).

---

## 7. Chat: Secured Channels, Presence, History

Chat is the opposite of signalling: **secured**. The handler `chat_ws(connection, event, data)` is marked `chat_ws._secured = True`, so a **valid JWT is required on the WebSocket upgrade** - the router rejects an unauthenticated upgrade before your handler runs.

- Channels are addressed by **integer id**: `int(connection.params["channel"])`. A non-integer `{channel}` makes the handler return silently - the socket opens and does nothing.
- Identity comes from the verified token: `identity = _identity(connection.auth)` (section 9).
- The room key is `chat:<channel_id>`.

Every frame is JSON; every broadcast is a `json.dumps(...)` string. The event flow:

| Event / message `type` | Server behaviour |
|---|---|
| `open` | Authorize. **Fail →** send `{"type":"error","error":"not a member of this channel"}` then `close()`. **OK →** `join_room`, send the caller the roster `{"type":"presence","event":"roster","users":[...]}`, then broadcast `{"type":"presence","event":"join","user_id":<id>}` (exclude self). |
| `close` | Broadcast `{"type":"presence","event":"leave","user_id":<id>}` (exclude self). |
| message `typing` | Broadcast `{"type":"typing","user_id":<id>}` (exclude self). |
| message `read` | Advance the member's read cursor (`last_read_at = now`), broadcast `{"type":"read","user_id":<id>,"at":<iso>}` (exclude self). |
| message `message` | Trim `body`; empty → ignored. Persist a `Message` row; on success broadcast `{"type":"message","message":<saved>}` to **everyone including the sender** (so an optimistic client message reconciles with its server `id` + `created_at`). |

`type` defaults to `"message"` when absent. Unknown types are ignored. The roster is the sorted set of distinct identities currently in the room, derived from each live connection's `auth`.

**Authorization is re-checked on every inbound frame**, not just on join - membership can be revoked mid-session, and the server never trusts an identity carried in the payload.

The saved-message JSON shape (also what history returns):

```jsonc
{ "id": 42, "channel_id": 7, "user_id": "12", "body": "hi team",
  "thread_id": null, "created_at": "2026-07-08T10:15:00+00:00" }
```

`thread_id` is `null` for a top-level message, or the parent message id for a threaded reply.

### Chat history: `GET {p}/api/channels/{id}/messages`

A catch-up-on-reconnect endpoint (`auth_required`). Handler `chat_history(request, response)`.

- Identity comes from `authenticate_request(request.headers)`. An invalid channel id → **400**; not authorized → **403**.
- Query params: `before` (return messages with `id < before`) and `limit` (default **50**, capped at **200**).
- Returns messages **newest-first** (`ORDER BY id DESC`, applied in SQL) - the standard infinite-scroll-backwards shape. Each item uses the saved-message shape above.

```bash
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7146/api/channels/7/messages?limit=50"

# older page: pass the smallest id you already have as `before`
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7146/api/channels/7/messages?before=42&limit=50"
```

---

## 8. Files: Upload and Download

Enable with `features=["files"]`. Both routes are `auth_required` and go through a pluggable `StorageBackend` - the `storage=` argument, or the env-selected store (default `LocalStorage`).

### `POST {p}/api/files` - upload

- Multipart: a file field named **`file`**, plus a form field **`channel_id`** (required, integer).
- Missing/invalid `channel_id` → **400**; not a channel member → **403**; no file → **400**.
- Stores the blob under an opaque, collision-free `storage_key` (a uuid plus a sanitized extension - never a user-controlled path), inserts an `Attachment` row (metadata only), and responds **201**:

```jsonc
{ "id": 9, "key": "3f8c...e1.png", "filename": "diagram.png",
  "mime": "image/png", "size": 20481,
  "url": "/api/files/3f8c...e1.png" }
```

`url` is `store.url(key)` when the backend exposes a direct URL (e.g. an S3 presigned URL), otherwise the app download route `{files}/{key}`.

```bash
curl -X POST http://localhost:7146/api/files \
  -H "Authorization: Bearer $JWT" \
  -F "channel_id=7" \
  -F "file=@diagram.png"
```

### `GET {p}/api/files/{key}` - download

- Looks up the `Attachment` by `storage_key`; missing → **404**. Authorizes against the attachment's `channel_id`; a non-member → **403**.
- If the backend has a direct URL → **302** redirect (`Location`). Otherwise it **streams the bytes** (**200**) with `Content-Disposition: inline; filename="..."` and `Content-Type` set from the attachment's `mime` (default `application/octet-stream`).

### Storage backends

`select_storage(storage=None)` resolves from the `storage=` argument or `TINA4_STORAGE_BACKEND`. An `s3` backend that cannot be built (boto3 missing, or incomplete config) **falls back to `LocalStorage`** with a warning - a real store, never a silent no-op.

```bash
# .env - local (default)
TINA4_STORAGE_BACKEND=local
TINA4_STORAGE_DIR=data/rt_storage

# .env - S3-compatible (MinIO, AWS, ...)
TINA4_STORAGE_BACKEND=s3
TINA4_STORAGE_URL=https://s3.example.com
TINA4_STORAGE_KEY=...
TINA4_STORAGE_SECRET=...
TINA4_STORAGE_BUCKET=my-bucket
TINA4_STORAGE_REGION=us-east-1
```

| Var | Default | Effect |
|---|---|---|
| `TINA4_STORAGE_BACKEND` | `local` | `local` \| `s3`. |
| `TINA4_STORAGE_DIR` | `data/rt_storage` | Local filesystem directory. |
| `TINA4_STORAGE_URL` | - | S3 endpoint URL (S3-compatible / MinIO). |
| `TINA4_STORAGE_KEY` / `TINA4_STORAGE_SECRET` | - | S3 credentials. |
| `TINA4_STORAGE_BUCKET` | - | S3 bucket (required for S3). |
| `TINA4_STORAGE_REGION` | `us-east-1` | S3 region. |

`LocalStorage` resolves every key inside its root and rejects path traversal; its `url()` returns `None`, so files are served through the permissioned download route. `S3Storage` returns a presigned GET URL from `url()`, so clients fetch large blobs straight from object storage (and downloads become a 302 redirect).

---

## 9. Auth and Identity

Chat and files are membership-gated. Two pieces make that work: how an identity is extracted, and how membership is checked.

**Extracting identity - `_identity(auth)`.** It pulls a stable **string** user id from a verified JWT payload, trying the claims **`user_id` → `sub` → `id`** in order, and returns `None` if `auth` is not a dict or none of those claims are present. Identities round-trip as strings, so an integer id, a UUID, or an email all work:

```python
_identity({"user_id": 7})    # -> "7"
_identity({"sub": "abc"})     # -> "abc"
_identity({"foo": 1})         # -> None
```

- **WebSocket identity** comes from `connection.auth` - the verified JWT payload the router attached on the secured upgrade.
- **HTTP identity** comes from `authenticate_request(request.headers)` inside each handler.

**Checking membership - `_default_authorize(identity, channel_id)`.** The secure default: the user must be a member of the channel (`ChannelMember.count("channel_id=? AND user_id=?") > 0`). Any exception logs and returns `False` (deny).

**Overriding it - `authorize=`.** Pass `authorize(identity, channel_id) -> bool`, **sync or async** (a coroutine result is awaited). Use it to, for example, open public channels to any authenticated user. The internal wrapper returns `False` first whenever `identity is None`, so an unauthenticated caller is always denied regardless of your guard.

```python
# Open every channel to any logged-in user (skip per-channel membership).
async def allow_any_authenticated(identity, channel_id):
    return True

realtime(features=["calls", "chat"], authorize=allow_any_authenticated)
```

Because this runs on **every inbound chat frame**, keep a custom guard cheap.

### Data model

The chat surface persists to framework-owned ORM models, all carrying the **`tina4_rt_`** table prefix so they never collide with your app's tables. `CHAT_MODELS` lists them in dependency order: `[Workspace, Channel, ChannelMember, Message, Attachment]`. Tables are created on demand at mount time.

| Model | Table | Key fields |
|---|---|---|
| `Workspace` | `tina4_rt_workspaces` | `id`, `name`, `created_at` |
| `Channel` | `tina4_rt_channels` | `id`, `workspace_id`→Workspace, `name`, `kind` (`public`\|`private`\|`dm`, default `public`), `created_at` |
| `ChannelMember` | `tina4_rt_channel_members` | `id`, `channel_id`→Channel, `user_id` (string, ≤128), `role` (`member`\|`admin`\|`owner`, default `member`), `last_read_at` (read cursor) |
| `Message` | `tina4_rt_messages` | `id`, `channel_id`→Channel, `user_id` (string), `body` (Text), `thread_id` (nullable parent id), `created_at`, `edited_at` (nullable) |
| `Attachment` | `tina4_rt_attachments` | `id`, `channel_id`→Channel, `message_id`→Message (nullable), `storage_key`, `filename`, `mime`, `size`, `thumb_key` (nullable) |

`user_id` is a **string** everywhere so any JWT identity shape fits. Because these are ordinary Tina4 ORM models, you seed a workspace, a channel, and its members exactly as in Chapter 6:

```python
from tina4_python.realtime.models import Workspace, Channel, ChannelMember

ws = Workspace(name="Acme")
ws.save()

channel = Channel(workspace_id=ws.id, name="general", kind="public")
channel.save()

ChannelMember(channel_id=channel.id, user_id="12", role="owner").save()
```

Now user `12` can open `WS /ws/chat/{channel.id}` and pass the history and file checks.

---

## 10. A Complete Example

A mesh video call with a chat side-panel, using only the browser's built-in `RTCPeerConnection` and `WebSocket` - no client library required.

### Backend - `app.py`

Mount the surface before `run()`, and seed one channel so chat has somewhere to land.

```python
from tina4_python import run, bind_database, Database
from tina4_python.realtime import realtime
from tina4_python.realtime.models import Workspace, Channel, ChannelMember

# Chat/files need a bound DB BEFORE realtime(features=[...]) - see section 11.
bind_database(Database("sqlite:data/app.db"))

paths = realtime(features=["calls", "chat", "files"])
print("realtime mounted:", paths)

# One-time seed so a channel + member exist.
if not Channel.where("name = ?", ["general"], limit=1):
    ws = Workspace(name="Acme"); ws.save()
    channel = Channel(workspace_id=ws.id, name="general", kind="public"); channel.save()
    ChannelMember(channel_id=channel.id, user_id="12", role="owner").save()

if __name__ == "__main__":
    run()
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

// Local ICE candidates -> relay to peers through the room.
pc.onicecandidate = (e) => {
  if (e.candidate) {
    signal.send(JSON.stringify({ kind: "ice", candidate: e.candidate }));
  }
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

```js
const channelId = 7;                       // integer id, not a name
const chatUrl = location.origin.replace(/^http/, "ws")
              + cfg.chat.replace("{channel}", channelId)
              + "?token=" + encodeURIComponent(jwt);   // WS carries the JWT
const chat = new WebSocket(chatUrl);

chat.onmessage = (evt) => {
  const m = JSON.parse(evt.data);
  if (m.type === "message")  addLine(m.message.user_id, m.message.body);
  if (m.type === "presence") renderRoster(m);   // roster / join / leave
  if (m.type === "typing")   showTyping(m.user_id);
  if (m.type === "error")    console.warn(m.error);   // e.g. not a member
};

function send(text) {
  chat.send(JSON.stringify({ type: "message", body: text }));
}

// Load the last page of history on open (secured HTTP call).
const history = await (await fetch(
  cfg.messages.replace("{id}", channelId) + "?limit=50",
  { headers: { Authorization: "Bearer " + jwt } }
)).json();
```

The signalling socket is public (anyone with the room name joins). The chat socket and the history/file endpoints require a valid JWT and channel membership. Two browser tabs, both members of channel `7`, joined to room `standup`, will see each other's video peer-to-peer and each other's messages through the relay.

---

## 11. Footguns and Hard Rules

### 1. Chat Needs a Bound Database -- But a Missing One Does Not Crash Boot

With `features=["chat"]` or `["files"]`, table creation runs at mount. If **no database is bound**, it **logs an ERROR and continues** -- `realtime()` still returns the full path map and registers every route, and the failure only resurfaces at query time.

**Fix:** Bind a database (`bind_database(db)` or `TINA4_DATABASE_URL`) **before** calling `realtime(features=[...])`, or chat / history / files will error per request while the app looks healthy.

### 2. The Signalling WebSocket Is Public

`/ws/rtc/{room}` is **not** secured. Anyone can join any room and receive the relayed signalling frames. Only the **chat** WebSocket is JWT-secured.

**Fix:** If a call must be private, gate room access at your app layer -- issue unguessable room ids, or check membership before you hand the client a room name.

### 3. The Config Endpoint Is Public

`/api/rtc/config` returns your ICE/TURN configuration, including **freshly-minted ephemeral TURN credentials**. This is by design -- the browser needs them before it can connect -- which is exactly why the TURN credentials are time-limited (`TINA4_RTC_TURN_TTL`).

### 4. The WS Handler Signature Is `(connection, event, data)`

`event` is `"open"` / `"message"` / `"close"`; `data` is a `str` on `"message"` and `None` on `"open"` / `"close"`. This is the framework convention -- **not** `(connection, data, event)`.

### 5. Channels Are Addressed by Integer Id

A non-integer `{channel}` makes the chat handler **return silently** -- no error frame. The client sees a socket that opens and does nothing.

**Fix:** Pass the numeric channel id, never its name.

### 6. Authorization Is Re-Checked on Every Chat Frame

Membership can be revoked mid-session, and identity is always taken from the verified token (`connection.auth` / `authenticate_request`), never from the message payload. A custom `authorize=` must be **cheap** -- it runs on every inbound message.

### 7. Empty Messages Are Silently Dropped

A `message` with an empty or whitespace-only `body` is not persisted and not broadcast. `read` / `typing` / unknown types never persist anything either.

### 8. An Unknown `TINA4_RTC_BACKEND` Silently Falls Back to Mesh

A typo won't error -- you just get `mesh`. Only `mesh` exists in Phase 1, and its `mint_join` returns `None` (there is no SFU join token yet).

---

## Where to Go Next

- **Chapter 23 - WebSocket** - the raw `@websocket` primitive these handlers are built on, and the connection API (`join_room`, `broadcast_to_room`, `send_json`).
- **Chapter 6 - ORM** and **Chapter 8 - Authentication** - you seed workspaces/channels/members with the ORM, and the JWT that secures chat is the same one from the auth chapter.
- **tina4-js `rtc` module** - the browser side, whose `rtcConfig()` helper wraps `GET /api/rtc/config` so the client and server never drift.
