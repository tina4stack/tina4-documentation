# Chapter 39: Real-time Collaboration (WebRTC)

## 1. Calls, Chat, and Files Without a Media Server

You want video calls, live chat, and file sharing in your app. The usual answer is a media server -- an SFU like LiveKit or Janus -- sitting in the middle, decoding and re-encoding every stream. That is a lot of infrastructure to run, scale, and pay for.

There is a lighter option. Browsers already speak **WebRTC**: they can open direct, encrypted, peer-to-peer connections to each other and stream audio, video, and arbitrary data between themselves. No media server touches the bytes. The catch is that two browsers behind two different NATs cannot find each other on their own. They need a tiny **signalling** channel to swap connection offers, answers, and ICE candidates before the peer-to-peer link comes up.

That signalling channel is the only part that has to live on a server, and it is small. Tina4's realtime module is that server. It relays the WebRTC handshake between peers (a **mesh** -- every peer connects to every other peer), hands the browser its ICE/TURN configuration, and -- when you ask for it -- adds persistent **chat** channels and permissioned **file** upload/download on the same surface.

Tina4 carries **no media**. It relays the offer/answer/ICE frames verbatim and **never parses the SDP**. The framework is the control plane; the browsers are the media plane.

```php
<?php
use Tina4\Realtime\Realtime;

Realtime::mount(); // one line: WebRTC signalling is live
```

> This is a coordinated **cross-language** feature. The routes, JSON shapes, env vars, and the `tina4_rt_*` tables are identical across tina4-python, tina4-php, tina4-ruby, and tina4-nodejs -- only the language changes. If you port an example from the Python or Node docs, read the WebSocket-handler note in [section 6](#_6-calls-the-signalling-relay) first: **PHP fires WebSocket handlers as `($connection, $data, $event)`**, which is a different argument order from the other frameworks.

---

## 2. What You Get

`Realtime::mount()` registers a self-describing surface. You opt into three features:

- **`calls`** (default) -- a public WebRTC signalling relay (`WS /ws/rtc/{room}`) plus a public config endpoint (`GET /api/rtc/config`) that ships the ICE/TURN servers and the paths the client should use.
- **`chat`** -- a **JWT-secured** WebSocket per channel (`WS /ws/chat/{channel}`) with presence, typing indicators, read receipts, and persisted messages, plus a secured history endpoint (`GET /api/channels/{id}/messages`).
- **`files`** -- authenticated upload (`POST /api/files`) and secured download (`GET /api/files/{key}`) backed by a pluggable storage backend (local filesystem or S3).

The client never hardcodes a path. It fetches `/api/rtc/config`, reads the paths and ICE servers from the response, and fills in the `{room}` / `{channel}` / `{id}` tokens. Server and client can never drift.

The persistent side (chat + files) is backed by five framework-owned ORM models with a `tina4_rt_` table prefix, so they never collide with your own tables. See [section 11](#_11-the-data-model).

It pairs with the frontend **`tina4-js` `rtc` module** (`rtcConfig()` and the call/chat/file clients), which does the `/api/rtc/config` fetch and token-filling for you. Everything below works with plain browser APIs too.

---

## 3. Mounting the Realtime Surface

```php
\Tina4\Realtime\Realtime::mount(string $prefix = '', array $options = []): array
```

Call `mount()` **once in your app bootstrap, before the server starts** -- in `index.php` after `new \Tina4\App()`, or in a `src/` bootstrap file. It registers the routes and **returns the resolved path map** (the same map served from `/api/rtc/config`).

```php
<?php
use Tina4\Realtime\Realtime;

Realtime::mount();                                                        // calls only (default)
Realtime::mount('', ['features' => ['calls', 'chat']]);                   // add persistent chat
Realtime::mount('/api/collab', ['features' => ['calls','chat','files']]); // relocate the whole surface
```

### Options

| key | type | meaning |
|---|---|---|
| `features` | `string[]` | Any of `"calls"`, `"chat"`, `"files"`. **Default `["calls"]`.** |
| `authorize` | `callable(string $identity, int $channelId): bool` | Channel-membership guard for `chat`/`files`. Defaults to a `ChannelMember` lookup. `$identity` is the **string** user id from the JWT. |
| `storage` | `StorageBackend` | Backing store for the `files` feature. Defaults to the env-selected store (`local`). |
| `media` | object | A media-plane backend. Defaults to the env-selected backend (mesh in Phase 1). |

`$prefix` mounts the entire surface under `/<prefix>` (default: root). It is normalised with `trim($prefix, '/')`, so `'/api/collab'`, `'api/collab'`, and `'api/collab/'` all resolve identically.

### The returned path map

`mount()` returns the **base** paths. The config endpoint appends the template tokens (`/{room}`, `/{channel}`, `/{id}/messages`).

```php
Realtime::mount();
// ['backend' => 'mesh', 'config' => '/api/rtc/config', 'signalling' => '/ws/rtc']

Realtime::mount('', ['features' => ['calls', 'chat']]);
// ['backend' => 'mesh', 'config' => '/api/rtc/config', 'signalling' => '/ws/rtc',
//  'chat' => '/ws/chat', 'messages' => '/api/channels']

Realtime::mount('', ['features' => ['files']]);
// ['backend' => 'mesh', 'config' => '/api/rtc/config', 'files' => '/api/files']
```

`config` is added by **any** enabled feature, so even a chat-only or files-only mount still exposes `/api/rtc/config`.

### What each feature wires

| feature | route registered | auth |
|---|---|---|
| any | `GET  {p}/api/rtc/config` | **public** -- `->noAuth()` |
| `calls` | `WS   {p}/ws/rtc/{room}` | **public** (unauthenticated) |
| `chat` | `WS   {p}/ws/chat/{channel}` | **secured** -- `Router::websocket(..., secure: true)`; valid JWT required on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` | **secured** -- `->secure()` |
| `files` | `POST {p}/api/files` | **auth-required** (write route -- no `->noAuth()`) |
| `files` | `GET  {p}/api/files/{key}` | **secured** -- `->secure()` |

If `chat` or `files` is enabled, `ensureChatTables()` runs at mount time -- read the [footguns](#_13-footguns-and-hard-rules) about binding a database first.

---

## 4. The Public Bootstrap: `GET /api/rtc/config`

This is the endpoint the frontend fetches so client and server never drift. It is registered with `->noAuth()` -- **public on purpose**, because the client needs it before it can authenticate a call. The body is feature-gated: only keys for enabled features appear.

```jsonc
{
  "backend": "mesh",
  "iceServers": [ /* iceServers() output */ ],  // calls
  "signalling": "/ws/rtc/{room}",               // calls
  "chat": "/ws/chat/{channel}",                 // chat
  "messages": "/api/channels/{id}/messages",    // chat
  "files": "/api/files"                          // files
}
```

`{room}`, `{channel}`, and `{id}` are literal template tokens the client substitutes at connect time:

```js
const cfg = await fetch("/api/rtc/config").then(r => r.json());

// Join a call room "standup":
const signalUrl = cfg.signalling.replace("{room}", "standup"); // /ws/rtc/standup

// Open chat channel 42:
const chatUrl = cfg.chat.replace("{channel}", "42");           // /ws/chat/42
```

---

## 5. ICE and TURN: `iceServers()` and the Env Vars

```php
\Tina4\Realtime\Realtime::iceServers(): array
```

A public static that builds the ICE server list from the environment. It **always** includes a STUN entry. It adds a TURN entry with time-limited coturn `use-auth-secret` credentials **only when both** `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set.

The ephemeral TURN credential scheme (verified against the source):

```php
$username   = (string)(time() + $ttl);
$credential = base64_encode(hash_hmac('sha1', $username, $secret, true));
```

```php
// No TURN env -- STUN only:
[['urls' => ['stun:stun.l.google.com:19302']]]

// TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
[
  ['urls' => ['stun:stun.l.google.com:19302']],
  ['urls' => ['turn:turn.example.com:3478'], 'username' => '1783546725', 'credential' => 'ie7Mm...=='],
]
```

STUN gets most peers connected; TURN is the relay-of-last-resort for peers behind symmetric NATs that STUN cannot punch through. Because TURN credentials are minted fresh on every `/api/rtc/config` call and expire after `TINA4_RTC_TURN_TTL` seconds, you never ship a long-lived TURN secret to the browser.

### Env vars

| var | default | effect |
|---|---|---|
| `TINA4_RTC_BACKEND` | `mesh` | Media backend name. Only `mesh` ships in Phase 1. **The reported `backend` is hardcoded to `mesh` regardless of this value.** |
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | -- | Comma-separated TURN URLs; enables TURN when set together with the secret. |
| `TINA4_RTC_TURN_SECRET` | -- | coturn `use-auth-secret` shared secret (used to sign ephemeral creds). |
| `TINA4_RTC_TURN_TTL` | `3600` | Ephemeral TURN credential lifetime, in seconds. |

---

## 6. Calls: the Signalling Relay

```
WS {p}/ws/rtc/{room}   (public)
```

Registered **unauthenticated** -- there is no `secure:` flag. The handler follows the **PHP WebSocket handler convention**, which is where PHP differs from the other frameworks:

```php
Router::websocket($paths['signalling'] . '/{room}', function ($connection, $data, $event) {
    // $connection : the WebSocketConnection
    // $data       : the payload  -- a string on "message", null on "open"/"close"
    // $event       : "open" | "message" | "close"
});
```

> **PHP argument order is `($connection, $data, $event)`.** The built-in server fires every WebSocket handler positionally as `($connection, null, 'open')`, `($connection, $payload, 'message')`, and `($connection, null, 'close')`. So position 2 is always the **payload** and position 3 is always the **event string**. Python and Node fire `(connection, event, data)`. Name the parameters in the PHP order or `$event` will hold your payload and nothing will work.

The relay logic is deliberately tiny:

- It reads `$room = $connection->params['room'] ?? '';`. An empty room is a no-op.
- On `open`, the peer joins the room: `$connection->joinRoom("rtc:{$room}")`.
- On `message`, it relays the **raw** payload to the other peers and excludes the sender: `$connection->broadcastToRoom("rtc:{$room}", (string)$data, true)`. Tina4 never inspects the payload -- peers put a `to` field in their own messages and filter for themselves.

Rooms are namespaced `rtc:<room>` so signalling rooms can never collide with chat channels (`chat:<channel>`) that share the same WebSocket manager.

### The connection surface

Every realtime handler works through these `WebSocketConnection` methods (all **camelCase** in PHP):

| member | purpose |
|---|---|
| `$connection->params` | route params, e.g. `['room' => '...']` / `['channel' => '...']` |
| `$connection->auth` | the verified JWT payload on a **secured** socket (`null` on a public one) |
| `$connection->joinRoom($name)` | add this connection to a broadcast room |
| `$connection->broadcastToRoom($name, $message, $excludeSelf = true)` | send a string to a room |
| `$connection->sendJson($data)` | JSON-encode and send to this one connection |
| `$connection->getRoomConnections($name)` | the live connections in a room |
| `$connection->close()` | close this connection |

A minimal browser peer, driven entirely by the config response:

```js
const cfg  = await fetch("/api/rtc/config").then(r => r.json());
const room = "standup";
const ws   = new WebSocket((location.origin.replace(/^http/, "ws")) +
                           cfg.signalling.replace("{room}", room));

const pc = new RTCPeerConnection({ iceServers: cfg.iceServers });

// Relay ICE candidates to the other peers.
pc.onicecandidate = (e) => {
  if (e.candidate) ws.send(JSON.stringify({ type: "ice", candidate: e.candidate }));
};

ws.onmessage = async (evt) => {
  const msg = JSON.parse(evt.data);        // raw frame relayed by the server
  if (msg.type === "offer") {
    await pc.setRemoteDescription(msg.sdp);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    ws.send(JSON.stringify({ type: "answer", sdp: answer }));
  } else if (msg.type === "answer") {
    await pc.setRemoteDescription(msg.sdp);
  } else if (msg.type === "ice") {
    await pc.addIceCandidate(msg.candidate);
  }
};
```

---

## 7. Chat: the Secured Channel Socket

```
WS {p}/ws/chat/{channel}   (secured -- valid JWT required on upgrade)
```

Handler `Realtime::chatHandler($connection, $data, $event)`, registered with `Router::websocket(..., secure: true)`. The router requires a valid JWT on the upgrade and rejects an unauthenticated upgrade with a `401` **before** the handler ever runs.

A browser cannot set request headers on `new WebSocket()`, so it passes the token as the **`bearer` subprotocol** (or a `?token=` query param):

```js
const token = localStorage.getItem("jwt");
const url   = (location.origin.replace(/^http/, "ws")) + cfg.chat.replace("{channel}", "42");

const ws = new WebSocket(url, ["bearer", token]);   // browser: bearer subprotocol
// or: new WebSocket(`${url}?token=${token}`)        // query-param fallback
```

Two rules shape the handler:

- **Channels are addressed by integer id.** If `{channel}` is not all digits, `chatHandler` returns silently (`ctype_digit()`) -- the socket opens and does nothing, with no error frame.
- **Identity comes only from the verified token** (`$identity = Realtime::identity($connection->auth)`), never from the message payload. The room key is `chat:<channelId>`.

### Event flow

Inbound frames are JSON; broadcasts are `json_encode(...)` strings.

| event / message `type` | server behaviour |
|---|---|
| `open` | Authorize. **Fail →** `sendJson(['type'=>'error','error'=>'not a member of this channel'])` then `close()`. **OK →** `joinRoom`, send the caller the roster `{"type":"presence","event":"roster","users":[…]}`, then broadcast `{"type":"presence","event":"join","user_id":<id>}` (excluding self). |
| `close` | Broadcast `{"type":"presence","event":"leave","user_id":<id>}` (excluding self). |
| `typing` | Broadcast `{"type":"typing","user_id":<id>}` (excluding self). |
| `read` | Advance the member's read cursor (`last_read_at = now`), broadcast `{"type":"read","user_id":<id>,"at":<iso>}` (excluding self). |
| `message` | Trim `body`; empty is ignored. Persist a `Message`, then broadcast `{"type":"message","message":<saved>}` to **everyone including the sender** (so the sender's optimistic message reconciles with its server `id` + `created_at`). |

`type` defaults to `"message"` when absent; unknown types are ignored. **Authorization is re-checked on every inbound frame**, not just on join -- membership can be revoked mid-session, so keep a custom `authorize` cheap.

The `users` roster is the sorted set of distinct identities currently in the room. It is deliberately built as a **list, not array keys** -- PHP would coerce numeric-string keys to ints and send `[1,2]` instead of `["1","2"]`, breaking the client's string comparison.

### Saved-message shape

The same shape is broadcast on `message` and returned by history:

```jsonc
{ "id": 128, "channel_id": 42, "user_id": "17", "body": "ship it",
  "thread_id": null, "created_at": "2026-07-08T09:14:22Z" }
```

`thread_id` is `null` for a top-level message, or the parent message id for a threaded reply.

---

## 8. Chat History: `GET /api/channels/{id}/messages`

```
GET {p}/api/channels/{id}/messages   (secured -- ->secure())
```

The catch-up-on-reconnect endpoint. Load history over HTTP, then keep up over the socket.

- Identity comes from `$request->user` (the router-attached, already-verified JWT payload). Not a member → `403`.
- Query params: `before` (return messages with `id < before`) and `limit` (default **50**, clamped to **1..200**).
- Messages come back **newest-first** (`ORDER BY id DESC`), the standard infinite-scroll-backwards shape. Each item uses the saved-message shape above.

```bash
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7145/api/channels/42/messages?limit=50"

# Older page, walking backwards from the oldest id you already have:
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7145/api/channels/42/messages?before=79&limit=50"
```

---

## 9. Files: Upload, Download, and Storage Backends

Enabled by `features=['files']`. Backed by a `StorageBackend` (the `storage` option, or the env-selected store -- default `LocalStorage`). The backend is resolved once at mount via `Storage::select()`.

### `POST {p}/api/files` -- upload (auth-required)

- Multipart: file field **`file`** (`$request->files['file']`) plus form field **`channel_id`** (required integer, read from body/query/params).
- Missing/invalid `channel_id` → `400`; not a channel member → `403`; no file → `400`.
- The blob is stored under an opaque, collision-free `storage_key` (`Storage::key()` -- 16 random bytes as hex plus a sanitized extension, **never a user-controlled path**). An `Attachment` row (metadata only) is inserted, and the response is **`201`**:

```jsonc
{ "id": 9, "key": "3f9c...b1.png", "filename": "diagram.png",
  "mime": "image/png", "size": 20481, "url": "<direct url OR {files}/{key}>" }
```

`url` is `$store->url($key)` when the backend exposes a direct URL (e.g. an S3 presigned GET), otherwise the app download route `{files}/{key}`.

```bash
curl -H "Authorization: Bearer $JWT" \
  -F "channel_id=42" \
  -F "file=@diagram.png" \
  http://localhost:7145/api/files
```

### `GET {p}/api/files/{key}` -- download (secured)

- Looks up the `Attachment` by `storage_key`; missing → `404`. Authorizes against the attachment's `channelId`; non-member → `403`.
- If the backend has a direct URL → **`302`** redirect. Otherwise it **streams the bytes** (`200`) with `Content-Disposition: inline; filename="…"` and `Content-Type = $attachment->mime` (default `application/octet-stream`).

### Storage backends

`Storage::select(?StorageBackend $storage = null)` resolves from the `storage` option or `TINA4_STORAGE_BACKEND` (`local` default | `s3`). `S3Storage` requires the AWS SDK (`aws/aws-sdk-php`); if it cannot be built (SDK missing, or `TINA4_STORAGE_BUCKET` unset) it **falls back to `LocalStorage`** with a logged warning -- a real store, never a silent no-op.

The `StorageBackend` interface:

```php
interface StorageBackend
{
    public function put(string $key, string $data, string $mime): void;
    public function get(string $key): ?string;
    public function url(string $key, int $ttl = 3600): ?string;
    public function delete(string $key): void;
    public function exists(string $key): bool;
}
```

| var | default | effect |
|---|---|---|
| `TINA4_STORAGE_BACKEND` | `local` | `local` \| `s3`. |
| `TINA4_STORAGE_DIR` | `data/rt_storage` | Local filesystem directory. |
| `TINA4_STORAGE_URL` | -- | S3 endpoint URL (S3-compatible / MinIO → path-style addressing). |
| `TINA4_STORAGE_KEY` / `TINA4_STORAGE_SECRET` | -- | S3 credentials. |
| `TINA4_STORAGE_BUCKET` | -- | S3 bucket (required for S3). |
| `TINA4_STORAGE_REGION` | `us-east-1` | S3 region. |

`LocalStorage` resolves every key inside its root and rejects path traversal (keys containing `/`, `\`, `..`, or NUL); its `url()` returns `null`, so downloads go through the permissioned route. `S3Storage` returns a presigned GET URL from `url()` so clients fetch large blobs straight from object storage.

---

## 10. Auth, Identity, and Channel Membership

- **`Realtime::identity($auth): ?string`** extracts a stable **string** user id from a verified JWT payload array, trying the claims **`user_id` → `sub` → `id`** in order. It returns `null` if `$auth` is not an array or none of those claims are present. Identities round-trip as strings, so an int id, a UUID, or an email all work.
- **WebSocket identity** comes from `$connection->auth` -- the verified JWT payload the router attached on the secured chat upgrade.
- **HTTP identity** comes from **`$request->user`** -- the router has already validated the JWT on the secured/auth-required route and exposed its decoded payload there. This is the single source of truth in PHP; do **not** re-parse the `Authorization` header yourself.
- **Default guard** -- the caller must be a member of the channel:
  `(new ChannelMember())->count('channel_id = ? AND user_id = ?', [$channelId, $identity]) > 0`. Any exception logs and returns `false` (deny).
- **`authorize` overrides it** -- pass `authorize(string $identity, int $channelId): bool`. Use it to, for example, open public channels to any authenticated user. An unauthenticated caller (`$identity === null`) is **always denied before the guard runs**, so a custom guard never has to handle a null identity.

```php
Realtime::mount('', [
    'features'  => ['calls', 'chat', 'files'],
    'authorize' => function (string $identity, int $channelId): bool {
        // Any authenticated user may read/write public channels;
        // fall back to the default membership check otherwise.
        $ch = (new \Tina4\Realtime\Channel())->where('id = ?', [$channelId], 1);
        if (!empty($ch) && $ch[0]->kind === 'public') {
            return true;
        }
        return (new \Tina4\Realtime\ChannelMember())
            ->count('channel_id = ? AND user_id = ?', [$channelId, $identity]) > 0;
    },
]);
```

---

## 11. The Data Model

Framework-owned ORM models, all with the **`tina4_rt_`** table prefix so they never collide with your own tables. Properties are **camelCase** (Tina4 PHP ORM convention); the ORM maps them to snake_case columns and to snake_case JSON keys, so the schema and wire shape stay byte-identical across every language. `ensureChatTables()` creates them in dependency order: `Workspace, Channel, ChannelMember, Message, Attachment`.

| model | table | key fields (camelCase → wire snake_case) |
|---|---|---|
| `Workspace` | `tina4_rt_workspaces` | `id`, `name`, `createdAt` |
| `Channel` | `tina4_rt_channels` | `id`, `workspaceId`, `name`, `kind` (`public`\|`private`\|`dm`, default `public`), `createdAt` |
| `ChannelMember` | `tina4_rt_channel_members` | `id`, `channelId`, `userId` (string), `role` (default `member`), `lastReadAt` (read cursor) |
| `Message` | `tina4_rt_messages` | `id`, `channelId`, `userId` (string), `body`, `threadId` (nullable parent id), `createdAt`, `editedAt` (nullable) |
| `Attachment` | `tina4_rt_attachments` | `id`, `channelId`, `messageId` (nullable), `storageKey`, `filename`, `mime`, `size`, `thumbKey` (nullable) |

`userId` is a **string** field everywhere so any JWT identity shape (int id, UUID, or email) fits. These are ordinary `\Tina4\ORM` models -- create a channel or add a member the same way you would with any Tina4 model:

```php
use Tina4\Realtime\Channel;
use Tina4\Realtime\ChannelMember;

$ch = new Channel();
$ch->name = "general";
$ch->kind = "public";
$ch->save();

$member = new ChannelMember();
$member->channelId = $ch->id;
$member->userId    = "17";     // string identity from the JWT
$member->role      = "member";
$member->save();
```

---

## 12. A Complete End-to-End Example

A minimal collaboration backend: calls, chat, and files on one surface, with a public channel policy.

`index.php`:

```php
<?php
require_once "vendor/autoload.php";

use Tina4\Realtime\Realtime;

// A bound database MUST exist before mounting chat/files -- see the footguns.
// Tina4 reads TINA4_DATABASE_URL (or your own init) here.
$app = new \Tina4\App();

Realtime::mount('', [
    'features'  => ['calls', 'chat', 'files'],
    'authorize' => function (string $identity, int $channelId): bool {
        $ch = (new \Tina4\Realtime\Channel())->where('id = ?', [$channelId], 1);
        if (!empty($ch) && $ch[0]->kind === 'public') {
            return true; // any authenticated user may join a public channel
        }
        return (new \Tina4\Realtime\ChannelMember())
            ->count('channel_id = ? AND user_id = ?', [$channelId, $identity]) > 0;
    },
]);

$app->run();
```

Boot it with an STUN/TURN and storage config:

```bash
export TINA4_DATABASE_URL="sqlite:./data/app.db"

# Calls
export TINA4_RTC_STUN_URLS="stun:stun.l.google.com:19302"
export TINA4_RTC_TURN_URL="turn:turn.example.com:3478"
export TINA4_RTC_TURN_SECRET="a-long-random-coturn-secret"
export TINA4_RTC_TURN_TTL="3600"

# Files (local by default; switch to s3 with the TINA4_STORAGE_* vars)
export TINA4_STORAGE_BACKEND="local"
export TINA4_STORAGE_DIR="./data/rt_storage"

tina4 serve
```

```
  Tina4 PHP v3.0.0
  HTTP server running at http://0.0.0.0:7145
  WebSocket server running at ws://0.0.0.0:7145
```

A browser client that bootstraps from config, opens a chat channel, and keeps a call going -- no hardcoded paths:

```js
const wsBase = location.origin.replace(/^http/, "ws");
const cfg    = await fetch("/api/rtc/config").then(r => r.json());
const token  = localStorage.getItem("jwt");

// ── Chat (secured: bearer subprotocol) ──
const chat = new WebSocket(wsBase + cfg.chat.replace("{channel}", "42"), ["bearer", token]);

chat.onmessage = (evt) => {
  const m = JSON.parse(evt.data);
  if (m.type === "presence" && m.event === "roster") console.log("in room:", m.users);
  if (m.type === "message")                          console.log("msg:", m.message.body);
};
chat.onopen = () => chat.send(JSON.stringify({ type: "message", body: "hello team" }));

// ── History (secured HTTP) ──
const history = await fetch(cfg.messages.replace("{id}", "42") + "?limit=50",
  { headers: { Authorization: `Bearer ${token}` } }).then(r => r.json());

// ── Call signalling (public) ──
const signal = new WebSocket(wsBase + cfg.signalling.replace("{room}", "standup"));
const pc     = new RTCPeerConnection({ iceServers: cfg.iceServers });
pc.onicecandidate = (e) => e.candidate &&
  signal.send(JSON.stringify({ type: "ice", candidate: e.candidate }));

// ── File upload (auth-required) ──
async function upload(file) {
  const fd = new FormData();
  fd.append("channel_id", "42");
  fd.append("file", file);
  return fetch(cfg.files, { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: fd })
    .then(r => r.json()); // { id, key, filename, mime, size, url }
}
```

---

## 13. Footguns and Hard Rules

- **The WebSocket handler signature is `($connection, $data, $event)`.** `$event` is `"open"` / `"message"` / `"close"`; `$data` is a string on `message` and `null` on `open`/`close`. This is the **PHP** order -- position 2 is the payload, position 3 is the event. Python and Node use `(connection, event, data)`. Get it wrong and your payload lands in `$event`.
- **Chat needs a bound database -- but a missing one does not crash boot.** With `features=['chat'|'files']`, `ensureChatTables()` runs at mount. If no database is bound it **logs an ERROR and continues**: `mount()` still returns the full path map and registers every route, and the failure only resurfaces at query time. **Bind a database before mounting realtime with chat/files** (`TINA4_DATABASE_URL` or your own DB init) or chat, history, and files will error per-request while the app looks healthy.
- **The signalling socket (`/ws/rtc/{room}`) is PUBLIC.** It is not `secure:`, so anyone can join any room and receive relayed signalling frames. Only the **chat** socket is JWT-secured. Gate call access at the app layer if you need it.
- **The config endpoint (`/api/rtc/config`) is PUBLIC** and returns your ICE/TURN config, including freshly-minted ephemeral TURN credentials. That is by design -- the client needs it before it can authenticate -- but do not put secrets in it.
- **Channels are addressed by integer id.** A non-integer `{channel}` makes `chatHandler` return silently (no error frame) -- the client sees a socket that opens and does nothing.
- **Chat authorization is re-checked on every frame**, and identity is always taken from the verified token (`$connection->auth` / `$request->user`), never from the message payload. A custom `authorize` must be cheap -- it runs on every inbound message.
- **A message with an empty or whitespace-only `body` is silently dropped** (no persist, no broadcast). `read` / `typing` / unknown types never persist anything.
- **`backend` is hardcoded to `'mesh'`** in the path map and config body regardless of `TINA4_RTC_BACKEND` -- a Phase-1 shortcut. Only mesh ships in Phase 1 (browsers connect peer-to-peer). An SFU/LiveKit backend is the documented Phase-2 drop-in with no route changes.
- **File upload (`POST /api/files`) relies on the framework's default Bearer protection** -- it has no `->noAuth()`, so it is auth-required like any write route. Do not add `->noAuth()` to it.
