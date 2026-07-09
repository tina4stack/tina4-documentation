# Chapter 38: Real-time Collaboration (WebRTC)

## 1. Calls, Chat and Files Without a Media Server

You want a video call, a live chat channel, or a drag-and-drop file share inside your app. The reflex is to reach for a media server -- an SFU, a TURN farm, a third-party SDK, a monthly bill. For a small team or a peer-to-peer session, that is a lot of machinery.

Tina4's `realtime()` mount takes a different path. It ships a **mesh WebRTC signalling relay**: the browsers form direct peer-to-peer connections and stream audio and video to each other. Tina4 never touches the media. It only relays the WebRTC handshake -- the offer, the answer, the ICE candidates -- and it never even parses the SDP. That means no media server to run, no per-minute cost, and zero dependencies for the core feature.

On top of that same mount you can turn on **persistent chat** (channels, messages, presence, typing indicators, read receipts) and **file upload/download** (local disk by default, S3 when you want it). One call, three features, one wire contract the browser discovers for itself.

```typescript
import { realtime } from "tina4-nodejs/orm";

await realtime({ features: ["calls", "chat", "files"] });
```

> Mesh is peer-to-peer: every participant connects to every other participant. It is perfect for 1:1 and small-group sessions. For large rooms an SFU is the right tool -- but that is not what ships here (see §11).

---

## 2. What You Get

Enabling `realtime()` wires up to three feature bundles, each guarded appropriately:

| Feature | What it gives you | Transport |
|---|---|---|
| `calls` | WebRTC signalling relay (mesh) + a self-describing ICE-config endpoint | Public WebSocket + public `GET` |
| `chat` | Channels, messages, live presence / typing / read receipts, catch-up history | JWT-secured WebSocket + secured `GET` |
| `files` | Permissioned upload / download through a pluggable storage backend | Auth-required `POST` + secured `GET` |

The whole surface is exported from the ORM package. Import what you need from `tina4-nodejs/orm`:

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

Tina4 carries **no media**. It relays the WebRTC offer/answer/ICE frames and gets out of the way; the peers connect directly and filter frames by a `to` field they put in the payload themselves.

> **This is the backend.** The browser client that consumes it -- `getUserMedia`, `RTCPeerConnection`, the chat socket UI -- is your frontend's job. It fetches `/api/rtc/config` and drives the WebSockets described below. The examples in this chapter use plain browser Web APIs so they run anywhere.

---

## 3. Mounting: `await realtime(options?)`

Call `realtime()` **once** in `app.ts`, **before** `startServer()`. It creates the chat tables (when needed), registers the routes, and returns the resolved path map -- which is also served from the config endpoint, so the client discovers every path and never hardcodes a URL.

```typescript
// app.ts
import { startServer } from "tina4-nodejs";
import { initDatabase, realtime } from "tina4-nodejs/orm";

await initDatabase(process.env.TINA4_DATABASE_URL!);   // bind the DB FIRST (see §11)

await realtime();                                          // calls only (default)
await realtime({ features: ["calls", "chat"] });          // add persistent chat
await realtime({ prefix: "/api/collab", features: ["calls", "chat", "files"] });

startServer();
```

> **`realtime()` is `async` in Node -- always `await` it.** Route registration itself is synchronous, but Node's ORM creates the `tina4_rt_*` tables asynchronously, so the mount returns a `Promise`. Awaiting it guarantees the tables exist before the first chat, history, or file request lands. (The Python master's `realtime()` is synchronous; Node's is not -- this is a Node-specific gotcha.)

### `RealtimeOptions`

```typescript
interface RealtimeOptions {
  prefix?: string;
  authorize?: (identity: string, channelId: number) => boolean | Promise<boolean>;
  storage?: StorageBackend;
  features?: string[];
}
```

| Option | Meaning |
|---|---|
| `prefix` | Mounts the whole surface under `/<prefix>` (default: root). Leading/trailing slashes are stripped: `"/api/collab/"` becomes `/api/collab`. |
| `authorize` | Channel-membership guard, `(identity, channelId) => boolean \| Promise<boolean>` (sync **or** async). Used by `chat` and `files`. Defaults to a `RealtimeChannelMember` membership check. `identity` is the **string** user id taken from the JWT. |
| `storage` | A `StorageBackend` for the `files` feature. Defaults to the env-selected store (`local`). |
| `features` | Array of `"calls"`, `"chat"`, `"files"`. **Defaults to `["calls"]`.** |

### What it returns -- the resolved path map

The returned map holds the **base** paths. The config endpoint body adds the `{room}` / `{channel}` / `{id}` template tokens the client fills in.

```typescript
await realtime();
// -> { backend: "mesh", config: "/api/rtc/config", signalling: "/ws/rtc" }

await realtime({ features: ["calls", "chat"] });
// -> { backend, config, signalling: "/ws/rtc", chat: "/ws/chat", messages: "/api/channels" }

await realtime({ features: ["files"] });
// -> { backend, config, files: "/api/files" }
```

`config` is added by **any** enabled feature (`calls` sets it; `chat` and `files` add it with `??=`), so even a chat-only or files-only mount still exposes `/api/rtc/config`.

### What each feature wires

| Feature | Routes registered | Auth |
|---|---|---|
| any | `GET  {p}/api/rtc/config` | **public** -- no `.secure()` |
| `calls` | `WS   {p}/ws/rtc/{room}` | **public** -- unauthenticated |
| `chat` | `WS   {p}/ws/chat/{channel}` | **secured** -- `Router.websocket(..., { secured: true })`, valid JWT required on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` | `.secure()` |
| `files` | `POST {p}/api/files` | auth-required (Tina4 secures write routes by default) |
| `files` | `GET  {p}/api/files/{key}` | `.secure()` |

When `chat` or `files` is enabled, the framework runs `ensureChatTables()` at mount time to create the `tina4_rt_*` tables (see §11).

---

## 4. `GET {p}/api/rtc/config` -- Public Bootstrap

This is the single call the frontend makes on startup. The server describes itself -- ICE servers, WebSocket paths, feature availability -- so the client and server can never drift out of sync. The body is **feature-gated**: only the keys for enabled features appear, and this is where the template tokens live.

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

Fetch it once, then substitute the tokens:

```js
const cfg = await fetch("/api/rtc/config").then(r => r.json());

const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });
const signalling = new WebSocket(
  location.origin.replace(/^http/, "ws") + cfg.signalling.replace("{room}", roomId)
);
```

> This endpoint is **public** and returns your ICE/TURN configuration, including freshly-minted ephemeral TURN credentials. That is by design -- the client needs them before it authenticates -- but be aware anyone can read it.

---

## 5. ICE / TURN Configuration -- `iceServers()`

`iceServers()` is exported so you can inspect or reuse the list. It builds the ICE server array from environment variables:

- It **always** includes a STUN entry.
- It adds a TURN entry with time-limited coturn `use-auth-secret` credentials **only when both** `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set.

The ephemeral TURN credential scheme matches coturn's REST API:

```
username   = String(Math.floor(Date.now() / 1000) + ttl)
credential = base64( HMAC_SHA1(secret, username) )
```

built with Node's `node:crypto` `createHmac`. The credential expires after `ttl` seconds, so a leaked config from `/api/rtc/config` is only briefly useful.

```jsonc
// no TURN env set:
[ { "urls": ["stun:stun.l.google.com:19302"] } ]

// TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
[ { "urls": ["stun:stun.l.google.com:19302"] },
  { "urls": ["turn:turn.example.com:3478"], "username": "1783546725", "credential": "ie7Mm...==" } ]
```

### Environment variables

| Variable | Default | Effect |
|---|---|---|
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | - | Comma-separated TURN URLs; enables TURN when set together with the secret. |
| `TINA4_RTC_TURN_SECRET` | - | coturn `use-auth-secret` shared secret (ephemeral credentials). |
| `TINA4_RTC_TURN_TTL` | `3600` | Ephemeral TURN credential lifetime, in seconds. |

> `TINA4_RTC_BACKEND` is **not read** in Node. The backend is always `mesh` (see §11).

---

## 6. Signalling WebSocket: `{p}/ws/rtc/{room}` -- Public

Registered by the `calls` feature. This is the WebRTC control channel: browsers send each other their offer, answer, and ICE candidates through it, and Tina4 relays the raw frames. **It is not secured -- anyone can join any room** (see §11).

It uses the standard Tina4 WebSocket handler convention, `(connection, event, data)`:

```typescript
(connection, event, data) => {
  // event: "open" | "message" | "close"; data is the string frame on "message"
};
```

The mesh relay behaviour is small and deliberate:

- `room = connection.params.room ?? ""`; an empty room is a no-op (the handler returns).
- On `event === "open"` -> `connection.joinRoom("rtc:" + room)`.
- On `event === "message"` -> `connection.broadcastToRoom("rtc:" + room, data, true)` -- it relays the **raw** frame to the other peers (`excludeSelf = true`).

Tina4 never inspects the SDP. Peers put a `to` field in their payloads and filter incoming frames themselves. Rooms are namespaced `rtc:<room>` so signalling rooms never collide with chat channels (`chat:<id>`), which share the same WebSocket manager.

The `WebSocketConnection` surface the relay uses (camelCase in Node):

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

---

## 7. Chat WebSocket + History -- Secured

### `{p}/ws/chat/{channel}` -- secured

Registered as `Router.websocket(path, chatHandler, { secured: true })`. A **valid JWT is required on the upgrade** -- an unauthenticated upgrade is rejected (401) before the handler ever runs.

- The channel is addressed by **integer id**: `connection.params.channel` must match `/^\d+$/`. A non-integer channel makes the handler return silently -- the socket opens and does nothing (see §11).
- `identity` is extracted from `connection.auth` (the verified JWT payload).
- The room key is `chat:<channelId>`.

All inbound frames are JSON; every broadcast is a `JSON.stringify(...)` string. The handler is **`async`** -- it awaits the membership check and message persistence on each frame.

| Event / message `type` | Server behaviour |
|---|---|
| `open` | Authorize. **Fail ->** send `{ type: "error", error: "not a member of this channel" }` then `close()`. **OK ->** `joinRoom`, send the caller the roster `{ type: "presence", event: "roster", users: [...] }`, then broadcast `{ type: "presence", event: "join", user_id }` (excluding self). |
| `close` | Broadcast `{ type: "presence", event: "leave", user_id }` (excluding self). |
| message `typing` | Broadcast `{ type: "typing", user_id }` (excluding self). |
| message `read` | Advance the member's read cursor (`last_read_at = now`), broadcast `{ type: "read", user_id, at: <iso> }` (excluding self). |
| message `message` | Trim `body`; if empty, **ignore**. Persist a `RealtimeMessage` row; on success broadcast `{ type: "message", message: <saved> }` to **everyone including the sender** (so the sender's optimistic message reconciles with its server `id` and `created_at`). |

- `type` defaults to `"message"` when absent. Unknown `type` values are ignored.
- The roster is the sorted set of distinct identities currently in the room (read from each live connection's `auth`).
- **Authorization is re-checked on every inbound frame**, not just on join -- membership can be revoked mid-session, and the server never trusts an identity carried in the payload.

The saved-message JSON shape (also what history returns):

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

### `GET {p}/api/channels/{id}/messages` -- `.secure()`

The catch-up-on-reconnect endpoint.

- Identity comes from **`req.user`** (the verified JWT payload the router attached on the secured route).
- Invalid channel id -> `400 { "error": "invalid channel id" }`; not authorized -> `403 { "error": "forbidden" }`.
- Query params: `before` (return messages with `id < before`) and `limit` (default **50**, clamped to **1-200**).
- Returns messages **newest-first** -- the standard infinite-scroll-backwards shape. Each item uses the saved-message JSON shape above.

```js
// initial load
let page = await fetch(`/api/channels/3/messages?limit=50`,
                       { headers: { Authorization: `Bearer ${jwt}` } }).then(r => r.json());

// scroll back: pass the oldest id you have as `before`
const older = await fetch(`/api/channels/3/messages?before=${page.at(-1).id}&limit=50`,
                          { headers: { Authorization: `Bearer ${jwt}` } }).then(r => r.json());
```

---

## 8. Files: Upload / Download

Enable by adding `"files"` to `features`. Uploads flow through a `StorageBackend` -- the `storage` option, or the env-selected store (default `LocalStorage`).

### `POST {p}/api/files` -- upload (auth-required)

- Multipart: a file field named **`file`** (`req.files.file`), plus a form field **`channel_id`** (required integer -- read from body, query, or params).
- Missing / invalid `channel_id` -> `400 { "error": "channel_id is required" }`; not a channel member -> `403 { "error": "forbidden" }`; no file -> `400 { "error": "no file uploaded (field 'file')" }`.
- Stores the blob under an opaque, collision-free `storageKey` (16 random bytes hex + a sanitized extension -- **never** a user-controlled path), inserts a `RealtimeAttachment` row (metadata only), and responds **`201`**:

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

### `GET {p}/api/files/{key}` -- download (`.secure()`)

- Looks up the `RealtimeAttachment` by `storage_key`; missing -> `404 { "error": "not found" }`.
- Authorizes against the attachment's `channel_id`; a non-member gets `403`.
- If the backend has a direct URL -> **`302`** redirect (`res.redirect(url, 302)`). Otherwise it **streams the bytes** (`200`) with `Content-Disposition: inline; filename="..."` and the attachment's `mime` (default `application/octet-stream`). Missing bytes -> `404`.

### Storage backends (`storage.ts`)

`selectStorage(storage?)` resolves from the `storage` argument or `TINA4_STORAGE_BACKEND` (`local` default | `s3`). An `s3` backend that cannot be built (the **`@aws-sdk/client-s3`** driver missing, or config incomplete) **falls back to `LocalStorage`** with a warning -- a real store, never a silent no-op.

> **Node uses `@aws-sdk/client-s3` (plus `@aws-sdk/s3-request-presigner`), not boto3.** They are optional peer dependencies, loaded lazily. Install them only when you set `TINA4_STORAGE_BACKEND=s3`.

| Variable | Default | Effect |
|---|---|---|
| `TINA4_STORAGE_BACKEND` | `local` | `local` \| `s3`. |
| `TINA4_STORAGE_DIR` | `data/rt_storage` | Local filesystem directory. |
| `TINA4_STORAGE_URL` | - | S3 endpoint URL (S3-compatible / MinIO); `forcePathStyle: true`. |
| `TINA4_STORAGE_KEY` / `TINA4_STORAGE_SECRET` | - | S3 credentials. |
| `TINA4_STORAGE_BUCKET` | - | S3 bucket. Required for S3 -- missing means the constructor throws and selection falls back to local. |
| `TINA4_STORAGE_REGION` | `us-east-1` | S3 region. |

`LocalStorage` resolves every key inside its root and rejects path traversal; its `url()` returns `null` (files are served by the permissioned download route). `S3Storage.url()` returns a presigned GET URL (default TTL 3600s), so clients fetch large blobs straight from object storage. You can also pass an instance explicitly:

```typescript
import { realtime, S3Storage } from "tina4-nodejs/orm";

await realtime({
  features: ["chat", "files"],
  storage: new S3Storage({ bucket: "collab-files", region: "eu-west-1" }),
});
```

---

## 9. Auth & Identity / Channel Membership

Identity is always taken from the **verified token**, never from a message payload.

- **`identityOf(auth)`** extracts a stable **string** user id from a verified JWT payload, trying the claims **`user_id` -> `sub` -> `id`** in order; it returns `null` if none are present. Because identities round-trip as strings, an integer id, a UUID, or an email all work.
- **WebSocket identity** comes from `connection.auth` (the payload the router attached on the secured upgrade). **HTTP identity** comes from **`req.user`** inside each handler. This is the Node/PHP convention -- the router validates the JWT on the secured / auth-required route and attaches the payload for you.
- **Default authorization** requires channel membership: `RealtimeChannelMember.count("channel_id = ? AND user_id = ?", [channelId, identity]) > 0`. Any exception is logged and denies (`false`).
- **A custom `authorize` overrides it** -- `(identity, channelId) => boolean | Promise<boolean>` (sync or async; a promise is awaited). Use it to, say, open public channels to any authenticated user. It short-circuits to `false` when `identity` is `null`, so an unauthenticated caller is always denied. **It runs on every inbound chat frame -- keep it cheap.**

```typescript
await realtime({
  features: ["chat"],
  // any authenticated user may read/write any channel
  authorize: (_identity, _channelId) => true,
});
```

### The data model

Framework-owned `BaseModel` classes, all with the **`tina4_rt_`** table prefix so they never collide with your own tables. They are created on demand at mount via `ensureChatTables()`, in dependency order: `Workspace, Channel, ChannelMember, Message, Attachment`.

| Model (public alias) | Table | Key fields |
|---|---|---|
| `RealtimeWorkspace` | `tina4_rt_workspaces` | `id`, `name`, `created_at` |
| `RealtimeChannel` | `tina4_rt_channels` | `id`, `workspace_id`, `name`, `kind` (`public` \| `private` \| `dm`, default `public`), `created_at` |
| `RealtimeChannelMember` | `tina4_rt_channel_members` | `id`, `channel_id`, `user_id` (string, ≤128), `role` (default `member`), `last_read_at` (read cursor) |
| `RealtimeMessage` | `tina4_rt_messages` | `id`, `channel_id`, `user_id` (string), `body` (text), `thread_id` (nullable parent id), `created_at`, `edited_at` (nullable) |
| `RealtimeAttachment` | `tina4_rt_attachments` | `id`, `channel_id`, `message_id` (nullable), `storage_key`, `filename`, `mime`, `size`, `thumb_key` (nullable) |

`user_id` is a **string** everywhere, so any JWT identity shape fits. Create channels and memberships with these models (or your own admin flow) **before** clients connect -- the mount seeds no data:

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

---

## 10. Complete End-to-End Example

A runnable server with all three features, a seeded channel, and a custom authorize guard.

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
  // Members-only channels: fall back to the default membership check by
  // returning a promise from the model. (Return `true` here for open channels.)
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

// 3. Seed a channel + membership so a client can connect (idempotent-ish demo).
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

The browser side, driven entirely by `/api/collab/api/rtc/config`:

```html
<script type="module">
  const base = "/api/collab";
  const jwt = localStorage.getItem("token");        // minted by your login route

  // Discover everything from the server - never hardcode paths.
  const cfg = await fetch(`${base}/api/rtc/config`).then(r => r.json());
  const wsOrigin = location.origin.replace(/^http/, "ws");

  // --- calls: mesh WebRTC signalling ---
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

---

## 11. Footguns / Hard Rules

- **Bind a database BEFORE `realtime({ features: ["chat" | "files"] })`.** `ensureChatTables()` runs at mount, but a failure (no DB bound) is **caught, logged as an ERROR, and boot continues** -- `realtime` still returns the full path map and registers every route; the failure only resurfaces at query time. Call `initDatabase(url)` / `bindDatabase(db)` first, then `await realtime(...)`.
- **`realtime()` is async -- always `await` it.** Skipping the `await` risks the first chat / history / file request racing table creation.
- **The signalling WebSocket (`/ws/rtc/{room}`) is PUBLIC.** It is not secured, so anyone can join any room and receive relayed signalling frames. Only the **chat** WebSocket is JWT-secured. Gate call access at the app layer if you need it.
- **The config endpoint (`/api/rtc/config`) is PUBLIC** and returns your ICE/TURN config, including freshly-minted ephemeral TURN credentials.
- **The WebSocket handler signature is `(connection, event, data)`** -- `event` is `"open"` / `"message"` / `"close"`, and `data` is the string frame on `"message"`. This matches the Python master. (The **PHP** port fires `($connection, $data, $event)` -- the order differs there, not here.)
- **Channels are addressed by integer id.** A non-integer `{channel}` makes the chat handler return silently (no error frame) -- the client sees a socket that opens and does nothing.
- **Chat authorization is re-checked on every frame,** and identity is always taken from the verified token (`connection.auth` / `req.user`), never from the message payload. A custom `authorize` must be cheap -- it runs on every inbound message.
- **A message with an empty / whitespace `body` is silently dropped** (no persist, no broadcast). `read` / `typing` / unknown types never persist anything.
- **The backend is hardcoded `mesh` in Node.** There is no `media` option and `TINA4_RTC_BACKEND` is ignored -- the Python master's `media=` parameter and `mint_join` SFU token do **not** exist in the Node port. Only mesh (peer-to-peer, zero-dependency) ships; an SFU / LiveKit backend is a future drop-in, not a current option.
