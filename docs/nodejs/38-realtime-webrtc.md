# Chapter 38: Real-time Collaboration (WebRTC)

## 1. The Media Server You Do Not Have to Run

You want a call button. Two people click it and they are talking: audio, video, a shared screen. Next to the call sits a chat panel and a place to drop a file. This is the Slack shape, the Teams shape, and the usual advice is heavy. Stand up a media server. Wire in TURN. Operate all of it.

You do not need any of that to start. Modern browsers already speak WebRTC to each other directly, peer to peer. What they cannot do is *find* each other. One browser has to hand its connection offer to the other and get an answer back. That hand-off is called **signalling**, and it is a tiny amount of text relayed through a server. The media itself, the actual audio and video, never touches your server. It flows browser to browser.

Tina4's realtime module is that relay, plus the two things every collaboration tool needs around a call: persistent **chat** and permissioned **file** transfer. It shipped in 3.13.57, carries zero core dependencies, and mounts with one line. Media is peer to peer, a **mesh**. Tina4 carries no media and never parses your SDP. It forwards the handshake and nothing more.

```typescript
import { realtime } from "tina4-nodejs/orm";

await realtime({ features: ["calls", "chat", "files"] });
```

Mesh is peer to peer: every participant connects to every other participant. Perfect for 1:1 and small-group sessions. A large room wants an SFU, and that is not what ships here (section 11).

---

## 2. What You Get, and How It Differs from Raw WebSocket

The WebSocket chapter gave you the raw primitive: `Router.websocket(path, handler)`, a `(connection, event, data)` handler, a room manager. That is the tool you reach for when you build your *own* protocol. The realtime module is the opposite end. It is a *pre-built* protocol for calls, chat, and files, assembled from that same primitive underneath.

The module gives you three surfaces, and you enable only the ones you want:

- **calls** - a WebRTC signalling relay (mesh, peer to peer) plus a self-describing ICE-config endpoint. The relay forwards offer, answer, and ICE frames between peers in a room. It is public: no login to join a room.
- **chat** - persistent channels and messages backed by framework-owned ORM models, a secured chat WebSocket with live presence, typing, and read receipts, and a history endpoint for catch-up on reconnect.
- **files** - permissioned upload and download through a pluggable storage backend (local filesystem by default, S3-compatible optional).

The distinction in one line: with `Router.websocket` you write the handler and invent the message protocol; with `realtime()` the protocol is written for you and the browser discovers every path from one config endpoint. Under the hood the realtime WebSockets *are* Tina4 WebSockets. Same `(connection, event, data)` handler convention, same room manager. You are handed the handlers pre-written.

The whole surface exports from the ORM package. Import what you need from `tina4-nodejs/orm`:

```typescript
import {
  realtime,           // the mount
  iceServers,         // build the ICE/TURN list from env
  selectStorage,      // resolve a storage backend
  storageKey,         // opaque, collision-free file keys
  LocalStorage,       // default filesystem store
  S3Storage,          // opt-in S3-compatible store
  type RealtimeOptions,
  type StorageBackend,
  // framework-owned ORM models (Realtime-prefixed so they never collide with yours)
  RealtimeWorkspace,
  RealtimeChannel,
  RealtimeChannelMember,
  RealtimeMessage,
  RealtimeAttachment,
} from "tina4-nodejs/orm";
```

Do the backend here. Do the browser side with the plain browser Web APIs shown in section 10, or with the tina4-js `rtc` module. The examples in this chapter use plain browser APIs so they run anywhere.

---

## 3. Mounting the Module: `realtime()`

Call `realtime()` once in `app.ts`, **before** `startServer()`. It creates the chat tables (when needed), registers the routes, and returns the resolved path map, the same map the config endpoint serves. So you can log it or assert against it.

```typescript
// app.ts
import { startServer } from "tina4-nodejs";
import { initDatabase, realtime } from "tina4-nodejs/orm";

await initDatabase(process.env.TINA4_DATABASE_URL!);   // bind the DB FIRST (section 11)

await realtime();                                         // calls only (default)
await realtime({ features: ["calls", "chat"] });          // add persistent chat
await realtime({ prefix: "/api/collab", features: ["calls", "chat", "files"] });

startServer();
```

**`realtime()` is `async` in Node, so always `await` it.** Route registration itself is synchronous, but Node's ORM creates the `tina4_rt_*` tables asynchronously, so the mount returns a `Promise`. Awaiting it guarantees the tables exist before the first chat, history, or file request lands. The Python master's `realtime()` is synchronous. Node's is not, and this is a Node-specific gotcha.

The signature is an options object:

```typescript
async function realtime(options?: RealtimeOptions): Promise<Record<string, string>>

interface RealtimeOptions {
  prefix?: string;
  authorize?: (identity: string, channelId: number) => boolean | Promise<boolean>;
  storage?: StorageBackend;
  features?: string[];
}
```

| Option | Meaning |
|---|---|
| `prefix` | Mounts the whole surface under `/<prefix>` (default: root). Leading and trailing slashes are stripped, so `"/api/collab/"` becomes `/api/collab`. |
| `authorize` | Channel-membership guard, `(identity, channelId) => boolean \| Promise<boolean>` (sync or async). Used by `chat` and `files`. Defaults to a `RealtimeChannelMember` check. `identity` is the **string** user id from the JWT. |
| `storage` | A `StorageBackend` for the `files` feature. Defaults to the env-selected store (`local`). |
| `features` | Array of `"calls"`, `"chat"`, `"files"`. Defaults to `["calls"]`. |

There is no `media` option. The Node port is mesh only (section 11).

The returned map holds the **base** paths. The config endpoint body adds the `{room}` / `{channel}` / `{id}` template tokens the client fills in.

```typescript
await realtime();
// -> { backend: "mesh", config: "/api/rtc/config", signalling: "/ws/rtc" }

await realtime({ features: ["calls", "chat"] });
// -> { backend, config, signalling: "/ws/rtc", chat: "/ws/chat", messages: "/api/channels" }

await realtime({ features: ["files"] });
// -> { backend, config, files: "/api/files" }
```

`config` is added by any enabled feature. `calls` sets it outright; `chat` and `files` add it with `??=`. So even a chat-only or files-only mount still exposes `/api/rtc/config`.

### What each feature wires

| Feature | Route registered | Auth |
|---|---|---|
| any | `GET  {p}/api/rtc/config` | **public**, no `.secure()` |
| `calls` | `WS   {p}/ws/rtc/{room}` | **public**, unauthenticated |
| `chat` | `WS   {p}/ws/chat/{channel}` | **secured**, `Router.websocket(..., { secured: true })`, valid JWT on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` | `.secure()` |
| `files` | `POST {p}/api/files` | auth-required (Tina4 secures write routes by default) |
| `files` | `GET  {p}/api/files/{key}` | `.secure()` |

When `chat` or `files` is enabled, the framework runs `ensureChatTables()` at mount time to create the `tina4_rt_*` tables. A missing database logs an error but does not crash boot (section 11).

---

## 4. The Config Bootstrap: `GET {p}/api/rtc/config`

The client never hardcodes a URL. It fetches this one public endpoint, and everything else comes back in the response: the signalling path, the ICE servers, the chat, messages, and files paths. Move `prefix` on the server and the client follows automatically.

The body is feature-gated. Only keys for enabled features appear, and this is where the template tokens live.

```jsonc
{
  "backend": "mesh",
  "iceServers": [ /* result of iceServers() */ ],   // calls
  "signalling": "/ws/rtc/{room}",                    // calls
  "chat": "/ws/chat/{channel}",                      // chat
  "messages": "/api/channels/{id}/messages",         // chat
  "files": "/api/files"                              // files
}
```

The `{room}`, `{channel}`, and `{id}` are literal template tokens. The client substitutes the real room name, channel id, or message id before connecting.

```js
const cfg = await fetch("/api/rtc/config").then(r => r.json());

const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });
const signalling = new WebSocket(
  location.origin.replace(/^http/, "ws") + cfg.signalling.replace("{room}", roomId)
);
```

This endpoint is public, and it returns your ICE and TURN configuration including freshly-minted ephemeral TURN credentials (section 5). That is intentional. The browser needs those before it can authenticate anywhere, which is exactly why the credentials are short-lived by design. Be aware anyone can read it.

---

## 5. ICE and TURN Servers

Before two browsers connect, each gathers candidate addresses using **ICE**. A **STUN** server tells a browser its public address. A **TURN** server relays media when a direct path is impossible: strict NAT, symmetric firewalls. The module builds this list from environment variables via `iceServers()`, which is exported so you can inspect or reuse it.

`iceServers()` always includes a STUN entry. It adds a TURN entry only when both `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set, using coturn's `use-auth-secret` scheme with time-limited credentials:

```
username   = String(Math.floor(Date.now() / 1000) + ttl)
credential = base64( HMAC_SHA1(secret, username) )
```

built with Node's `node:crypto` `createHmac`. The credential expires after `ttl` seconds, so a leaked config from `/api/rtc/config` is only briefly useful.

```jsonc
// no TURN env set - STUN only:
[ { "urls": ["stun:stun.l.google.com:19302"] } ]

// TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
[ { "urls": ["stun:stun.l.google.com:19302"] },
  { "urls": ["turn:turn.example.com:3478"], "username": "1783546725", "credential": "ie7Mm...==" } ]
```

### Environment variables

```bash
# .env
TINA4_RTC_STUN_URLS=stun:stun.l.google.com:19302
TINA4_RTC_TURN_URL=turn:turn.example.com:3478   # enables TURN when paired with the secret
TINA4_RTC_TURN_SECRET=your-coturn-shared-secret
TINA4_RTC_TURN_TTL=3600                          # ephemeral credential lifetime (seconds)
```

| Variable | Default | Effect |
|---|---|---|
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | - | Comma-separated TURN URLs; enables TURN when set together with the secret. |
| `TINA4_RTC_TURN_SECRET` | - | coturn `use-auth-secret` shared secret (drives the ephemeral credentials). |
| `TINA4_RTC_TURN_TTL` | `3600` | Ephemeral TURN credential lifetime, in seconds. |

`TINA4_RTC_BACKEND` is **not read** in Node. The backend is always `mesh` (section 11).

---

## 6. Signalling: The Mesh Relay

The `calls` feature registers the signalling handler at `WS {p}/ws/rtc/{room}`, and it is public. Anyone can join any room. It follows the framework's WebSocket handler convention:

```typescript
(connection, event, data) => {
  // connection : the WebSocketConnection
  // event      : "open" | "message" | "close"
  // data       : the string frame on "message"
};
```

The mesh relay behaviour is small and deliberate:

- `room = connection.params.room ?? ""`. An empty room is a no-op, and the handler returns.
- On `event === "open"` it calls `connection.joinRoom("rtc:" + room)`.
- On `event === "message"` it calls `connection.broadcastToRoom("rtc:" + room, data, true)`, relaying the **raw** frame to the other peers (`excludeSelf = true`).

Tina4 never inspects the SDP. Peers put a `to` field in their own frames and filter for themselves. Rooms are namespaced `rtc:<room>` so signalling rooms never collide with chat channels (`chat:<id>`), which share the same WebSocket manager.

The `WebSocketConnection` surface the relay uses is camelCase in Node:

```typescript
connection.params                                   // { room: "..." }
connection.auth                                     // verified JWT payload, or null on a public route
connection.joinRoom(name)
connection.broadcastToRoom(name, message, excludeSelf)
connection.getRoomConnections(key)                  // live connections in a room (for presence)
connection.sendJson(obj)
connection.close()
```

A minimal browser peer, framework-agnostic:

```js
const ws = new WebSocket(signallingUrl);            // ".../ws/rtc/room-42"
const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });

pc.onicecandidate = (e) => {
  if (e.candidate) ws.send(JSON.stringify({ to: peerId, type: "ice", candidate: e.candidate }));
};

ws.onmessage = async (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.to !== myId) return;                      // Tina4 relays to everyone; filter yourself
  if (msg.type === "offer") {
    await pc.setRemoteDescription(msg.sdp);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    ws.send(JSON.stringify({ to: msg.from, type: "answer", sdp: answer }));
  } else if (msg.type === "answer") {
    await pc.setRemoteDescription(msg.sdp);
  } else if (msg.type === "ice") {
    await pc.addIceCandidate(msg.candidate);
  }
};
```

Because signalling is public, the room name is your only barrier. If a call must be private, gate access at your app layer: issue unguessable room ids, or check membership before you hand the client a room name.

---

## 7. Chat: Secured Channels, Presence, History

Chat is the opposite of signalling: secured. It registers as `Router.websocket(path, chatHandler, { secured: true })`, so a **valid JWT is required on the WebSocket upgrade**. The router rejects an unauthenticated upgrade (401) before your handler ever runs.

- Channels are addressed by **integer id**: `connection.params.channel` must match `/^\d+$/`. A non-integer `{channel}` makes the handler return silently. The socket opens and does nothing (section 11).
- Identity comes from the verified token: `connection.auth` (section 9).
- The room key is `chat:<channelId>`.

Every inbound frame is JSON; every broadcast is a `JSON.stringify(...)` string. The handler is **`async`**, since it awaits the membership check and message persistence on each frame.

| Event / message `type` | Server behaviour |
|---|---|
| `open` | Authorize. **Fail:** send `{ type: "error", error: "not a member of this channel" }` then `close()`. **OK:** `joinRoom`, send the caller the roster `{ type: "presence", event: "roster", users: [...] }`, then broadcast `{ type: "presence", event: "join", user_id }` (exclude self). |
| `close` | Broadcast `{ type: "presence", event: "leave", user_id }` (exclude self). |
| message `typing` | Broadcast `{ type: "typing", user_id }` (exclude self). |
| message `read` | Advance the member's read cursor (`last_read_at = now`), broadcast `{ type: "read", user_id, at: <iso> }` (exclude self). |
| message `message` | Trim `body`; if empty, **ignore**. Persist a `RealtimeMessage` row; on success broadcast `{ type: "message", message: <saved> }` to **everyone including the sender**, so the sender's optimistic message reconciles with its server `id` and `created_at`. |

`type` defaults to `"message"` when absent. Unknown types are ignored. The roster is the sorted set of distinct identities currently in the room, read from each live connection's `auth`. Authorization is re-checked on **every inbound frame**, not just on join. Membership can be revoked mid-session, and the server never trusts an identity carried in the payload.

The saved-message JSON shape, also what history returns:

```jsonc
{ "id": 12, "channel_id": 3, "user_id": "7", "body": "hi",
  "thread_id": null, "created_at": "2026-07-08T10:00:00Z" }
```

`thread_id` is `null` for a top-level message, or the parent message's id for a threaded reply.

A minimal browser chat client:

```js
const chat = new WebSocket(chatUrl + "?token=" + jwt);   // upgrade must carry a valid JWT

chat.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  switch (m.type) {
    case "presence": /* m.event: "roster" | "join" | "leave" */ break;
    case "typing":   showTyping(m.user_id); break;
    case "read":     advanceReadReceipt(m.user_id, m.at); break;
    case "message":  appendMessage(m.message); break;   // includes the server id + created_at
    case "error":    console.warn(m.error); break;
  }
};

// send a message
chat.send(JSON.stringify({ type: "message", body: "hello" }));
// or a threaded reply
chat.send(JSON.stringify({ type: "message", body: "re:", thread_id: 12 }));
// typing indicator / read receipt
chat.send(JSON.stringify({ type: "typing" }));
chat.send(JSON.stringify({ type: "read" }));
```

### Chat history: `GET {p}/api/channels/{id}/messages`

The catch-up-on-reconnect endpoint, marked `.secure()`.

- Identity comes from **`req.user`**, the verified JWT payload the router attached on the secured route.
- Invalid channel id returns `400 { "error": "invalid channel id" }`; not authorized returns `403 { "error": "forbidden" }`.
- Query params: `before` (return messages with `id < before`) and `limit` (default **50**, clamped to **1-200**).
- Returns messages **newest-first**, the standard infinite-scroll-backwards shape. Each item uses the saved-message JSON shape above.

```bash
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7148/api/channels/3/messages?limit=50"

# older page: pass the smallest id you already have as `before`
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7148/api/channels/3/messages?before=12&limit=50"
```

---

## 8. Files: Upload and Download

Enable by adding `"files"` to `features`. Uploads flow through a `StorageBackend`: the `storage` option, or the env-selected store (default `LocalStorage`).

### `POST {p}/api/files` - upload (auth-required)

- Multipart: a file field named **`file`** (`req.files.file`), plus a form field **`channel_id`** (required integer, read from body, query, or params).
- Missing or invalid `channel_id` returns `400 { "error": "channel_id is required" }`; not a channel member returns `403 { "error": "forbidden" }`; no file returns `400 { "error": "no file uploaded (field 'file')" }`.
- Stores the blob under an opaque, collision-free `storageKey` (16 random bytes hex plus a sanitized extension, **never** a user-controlled path), inserts a `RealtimeAttachment` row (metadata only), and responds **`201`**:

```jsonc
{ "id": 4, "key": "<storageKey>", "filename": "report.pdf", "mime": "application/pdf",
  "size": 20481, "url": "<direct url OR {files}/{key}>" }
```

`url` is `store.url(key)` when the backend exposes a direct URL (for example an S3 presigned link), otherwise the app download route `{files}/{key}`.

```js
const fd = new FormData();
fd.append("file", fileInput.files[0]);
fd.append("channel_id", "3");

const att = await fetch("/api/files", {
  method: "POST",
  headers: { Authorization: `Bearer ${jwt}` },      // POST is auth-required
  body: fd,
}).then(r => r.json());
// att.url is either a direct (presigned) URL or /api/files/<key>
```

### `GET {p}/api/files/{key}` - download (`.secure()`)

- Looks up the `RealtimeAttachment` by `storage_key`; missing returns `404 { "error": "not found" }`.
- Authorizes against the attachment's `channel_id`; a non-member gets `403`.
- If the backend has a direct URL, it returns a **`302`** redirect (`res.redirect(url, 302)`). Otherwise it **streams the bytes** (`200`) with `Content-Disposition: inline; filename="..."` and the attachment's `mime` (default `application/octet-stream`). Missing bytes return `404`.

### Storage backends

`selectStorage(storage?)` resolves from the `storage` argument or `TINA4_STORAGE_BACKEND` (`local` default, or `s3`). An `s3` backend that cannot be built (the **`@aws-sdk/client-s3`** driver missing, or config incomplete) **falls back to `LocalStorage`** with a warning: a real store, never a silent no-op.

Node uses `@aws-sdk/client-s3` (plus `@aws-sdk/s3-request-presigner`), not boto3. They are optional peer dependencies, loaded lazily. Install them only when you set `TINA4_STORAGE_BACKEND=s3`.

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

| Variable | Default | Effect |
|---|---|---|
| `TINA4_STORAGE_BACKEND` | `local` | `local` or `s3`. |
| `TINA4_STORAGE_DIR` | `data/rt_storage` | Local filesystem directory. |
| `TINA4_STORAGE_URL` | - | S3 endpoint URL (S3-compatible / MinIO); `forcePathStyle: true`. |
| `TINA4_STORAGE_KEY` / `TINA4_STORAGE_SECRET` | - | S3 credentials. |
| `TINA4_STORAGE_BUCKET` | - | S3 bucket. Required for S3; missing means the constructor throws and selection falls back to local. |
| `TINA4_STORAGE_REGION` | `us-east-1` | S3 region. |

`LocalStorage` resolves every key inside its root and rejects path traversal; its `url()` returns `null`, so files serve through the permissioned download route. `S3Storage.url()` returns a presigned GET URL (default TTL 3600s), so clients fetch large blobs straight from object storage and the download becomes a 302 redirect. You can also pass an instance explicitly:

```typescript
import { realtime, S3Storage } from "tina4-nodejs/orm";

await realtime({
  features: ["chat", "files"],
  storage: new S3Storage({ bucket: "collab-files", region: "eu-west-1" }),
});
```

---

## 9. Auth, Identity, and the Data Model

Identity is always taken from the **verified token**, never from a message payload. Two pieces make membership work: how an identity is extracted, and how membership is checked.

**Extracting identity, `identityOf(auth)`.** It pulls a stable **string** user id from a verified JWT payload, trying the claims `user_id`, then `sub`, then `id`, and returns `null` if none are present. Because identities round-trip as strings, an integer id, a UUID, or an email all work. WebSocket identity comes from `connection.auth`, the payload the router attached on the secured upgrade. HTTP identity comes from **`req.user`** inside each handler. This is the Node and PHP convention: the router validates the JWT on the secured or auth-required route and attaches the payload for you.

**Checking membership.** The secure default requires channel membership: `RealtimeChannelMember.count("channel_id = ? AND user_id = ?", [channelId, identity]) > 0`. Any exception is logged and denies (`false`). A custom `authorize` overrides it, `(identity, channelId) => boolean | Promise<boolean>` (sync or async; a promise is awaited). Use it to open public channels to any authenticated user. It short-circuits to `false` when `identity` is `null`, so an unauthenticated caller is always denied. It runs on every inbound chat frame, so keep it cheap.

```typescript
await realtime({
  features: ["calls", "chat"],
  // any authenticated user may read/write any channel
  authorize: (_identity, _channelId) => true,
});
```

### The data model

Framework-owned `BaseModel` classes, all carrying the **`tina4_rt_`** table prefix so they never collide with your own tables. They are created on demand at mount via `ensureChatTables()`, in dependency order: `Workspace, Channel, ChannelMember, Message, Attachment`.

| Model (public alias) | Table | Key fields |
|---|---|---|
| `RealtimeWorkspace` | `tina4_rt_workspaces` | `id`, `name`, `created_at` |
| `RealtimeChannel` | `tina4_rt_channels` | `id`, `workspace_id`, `name`, `kind` (`public` / `private` / `dm`, default `public`), `created_at` |
| `RealtimeChannelMember` | `tina4_rt_channel_members` | `id`, `channel_id`, `user_id` (string), `role` (default `member`), `last_read_at` (read cursor) |
| `RealtimeMessage` | `tina4_rt_messages` | `id`, `channel_id`, `user_id` (string), `body` (text), `thread_id` (nullable parent id), `created_at`, `edited_at` (nullable) |
| `RealtimeAttachment` | `tina4_rt_attachments` | `id`, `channel_id`, `message_id` (nullable), `storage_key`, `filename`, `mime`, `size`, `thumb_key` (nullable) |

`user_id` is a **string** everywhere, so any JWT identity shape fits. The mount seeds no data. Create channels and memberships with these models (or your own admin flow) **before** clients connect:

```typescript
import { RealtimeChannel, RealtimeChannelMember } from "tina4-nodejs/orm";

const general = new RealtimeChannel({ workspace_id: 1, name: "general", kind: "public" });
await general.save();

await new RealtimeChannelMember({
  channel_id: (general as { id: number }).id,
  user_id: "7",
  role: "member",
}).save();
```

Now user `7` can open `WS /ws/chat/<channel.id>` and pass the history and file checks.

---

## 10. A Complete Example

A runnable server with all three features, a seeded channel, and a custom authorize guard.

### Backend - `app.ts`

Bind the database, mount the surface before `startServer()`, and seed one channel so chat has somewhere to land.

```typescript
// app.ts
import { startServer } from "tina4-nodejs";
import {
  initDatabase,
  realtime,
  RealtimeChannel,
  RealtimeChannelMember,
} from "tina4-nodejs/orm";

// 1. Bind a database FIRST - the chat/files tables are created at mount.
await initDatabase(process.env.TINA4_DATABASE_URL ?? "sqlite://./data/app.db");

// 2. Mount the realtime surface (await it - it is async in Node).
const paths = await realtime({
  prefix: "/api/collab",
  features: ["calls", "chat", "files"],
  // Members-only channels: return true here to open every channel instead.
  authorize: async (identity, channelId) =>
    (await RealtimeChannelMember.count(
      "channel_id = ? AND user_id = ?",
      [channelId, identity],
    )) > 0,
});

console.log(paths);
// {
//   backend: "mesh",
//   config:     "/api/collab/api/rtc/config",
//   signalling: "/api/collab/ws/rtc",
//   chat:       "/api/collab/ws/chat",
//   messages:   "/api/collab/api/channels",
//   files:      "/api/collab/api/files"
// }

// 3. Seed a channel + membership so a client can connect.
const existing = await RealtimeChannel.where("name = ?", ["general"], 1);
if (existing.length === 0) {
  const general = new RealtimeChannel({ workspace_id: 1, name: "general", kind: "public" });
  await general.save();
  await new RealtimeChannelMember({
    channel_id: (general as { id: number }).id,
    user_id: "7",
    role: "member",
  }).save();
}

// 4. Boot.
startServer();
```

```bash
# run it
tina4 serve
```

### Browser - bootstrap from the config endpoint

The client fetches `/api/collab/api/rtc/config` first and never hardcodes a path.

```html
<script type="module">
  const base = "/api/collab";
  const jwt = localStorage.getItem("token");        // minted by your login route

  // Discover everything from the server - never hardcode paths.
  const cfg = await fetch(`${base}/api/rtc/config`).then(r => r.json());
  const wsOrigin = location.origin.replace(/^http/, "ws");

  // --- calls: mesh WebRTC signalling (public, no token) ---
  const signalling = new WebSocket(wsOrigin + cfg.signalling.replace("{room}", "room-42"));
  const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });
  const local = await navigator.mediaDevices.getUserMedia({ audio: true, video: true });
  local.getTracks().forEach(t => pc.addTrack(t, local));
  // ...exchange offer/answer/ICE over `signalling`, filtering by a `to` field...

  // --- chat: secured WebSocket (JWT on the upgrade) ---
  const chat = new WebSocket(wsOrigin + cfg.chat.replace("{channel}", "1") + `?token=${jwt}`);
  chat.onmessage = (ev) => console.log(JSON.parse(ev.data));   // presence/typing/read/message
  chat.onopen = () => chat.send(JSON.stringify({ type: "message", body: "hello" }));

  // --- history: catch up on reconnect ---
  const history = await fetch(
    cfg.messages.replace("{id}", "1") + "?limit=50",
    { headers: { Authorization: `Bearer ${jwt}` } },
  ).then(r => r.json());

  // --- files: upload to the channel ---
  async function upload(file) {
    const fd = new FormData();
    fd.append("file", file);
    fd.append("channel_id", "1");
    return fetch(cfg.files, {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}` },
      body: fd,
    }).then(r => r.json());   // -> { id, key, filename, mime, size, url }
  }
</script>
```

The signalling socket is public: anyone with the room name joins. The chat socket and the history and file endpoints require a valid JWT and channel membership. Two browser tabs, both members of channel `1` and joined to `room-42`, see each other's video peer to peer and each other's messages through the relay.

---

## 11. Footguns and Hard Rules

- **Bind a database BEFORE `realtime({ features: ["chat" | "files"] })`.** `ensureChatTables()` runs at mount, but a failure (no DB bound) is caught, logged as an ERROR, and boot continues. `realtime` still returns the full path map and registers every route, and the failure only resurfaces at query time. Call `initDatabase(url)` or `bindDatabase(db)` first, then `await realtime(...)`.
- **`realtime()` is async, so always `await` it.** Skipping the `await` risks the first chat, history, or file request racing table creation.
- **The signalling WebSocket (`/ws/rtc/{room}`) is PUBLIC.** It is not secured, so anyone can join any room and receive the relayed frames. Only the **chat** WebSocket is JWT-secured. Gate call access at the app layer if you need it.
- **The config endpoint (`/api/rtc/config`) is PUBLIC** and returns your ICE and TURN config, including freshly-minted ephemeral TURN credentials. This is by design, which is exactly why the TURN credentials are time-limited (`TINA4_RTC_TURN_TTL`).
- **The WebSocket handler signature is `(connection, event, data)`.** `event` is `"open"` / `"message"` / `"close"`, and `data` is the string frame on `"message"`. This matches the Python master. The **PHP** port fires `($connection, $data, $event)`, so the order differs there, not here.
- **Channels are addressed by integer id.** A non-integer `{channel}` makes the chat handler return silently, with no error frame. The client sees a socket that opens and does nothing. Pass the numeric channel id, never its name.
- **Chat authorization is re-checked on every frame,** and identity is always taken from the verified token (`connection.auth` / `req.user`), never from the message payload. A custom `authorize` must be cheap, since it runs on every inbound message.
- **A message with an empty or whitespace `body` is silently dropped.** No persist, no broadcast. `read`, `typing`, and unknown types never persist anything.
- **The backend is hardcoded `mesh` in Node.** There is no `media` option and `TINA4_RTC_BACKEND` is ignored. The Python master's `media=` parameter and `mint_join` SFU token do **not** exist in the Node port. Only mesh (peer to peer, zero core dependency) ships. An SFU or LiveKit backend is a future drop-in, not a current option, and because signalling paths would not change, the client keeps working.

---

## Where to Go Next

- **The WebSocket chapter** - the raw `Router.websocket()` primitive these handlers are built on, and the connection API (`joinRoom`, `broadcastToRoom`, `sendJson`).
- **The ORM and Authentication chapters** - you seed workspaces, channels, and members with the ORM, and the JWT that secures chat is the same one from the Authentication chapter.
- **The tina4-js `rtc` module** - the browser side, whose `rtcConfig()` helper wraps `GET /api/rtc/config` so the client and server never drift on paths.

You started this chapter wanting a call button. You end it with calls, chat, presence, read receipts, history, and file transfer, mounted in one line, carrying no media, running no server you did not already have. The hard part of real-time was never the video. It was finding the other browser, and Tina4 relays that in a few lines of text.
