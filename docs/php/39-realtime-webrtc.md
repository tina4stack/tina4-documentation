# Chapter 39: Real-time Collaboration (WebRTC)

## 1. The Media Server You Do Not Have to Run

You want a call button. Two people click it and they are talking: audio, video, a shared screen. Next to the call sits a chat panel and a place to drop a file. This is the Slack shape, the Teams shape, and the usual advice is heavy. Stand up a media server. Wire in TURN. Operate all of it.

You do not need any of that to start. Modern browsers already speak WebRTC to each other directly, peer to peer. What they cannot do is *find* each other. One browser has to hand its connection offer to the other and get an answer back. That hand-off is called **signalling**, and it is a tiny amount of text relayed through a server. The media itself, the actual audio and video, never touches your server. It flows browser to browser.

Tina4's realtime module is that relay, plus the two things every collaboration tool needs around a call: persistent **chat** and permissioned **file** transfer. It shipped in 3.13.57, carries zero extra dependencies, and mounts with one line. Media is peer to peer, a **mesh**, by default. Tina4 carries no media and never parses your SDP. It forwards the handshake and nothing more. Outgrow mesh later and an SFU backend drops in with no route changes.

```php
<?php
use Tina4\Realtime\Realtime;

Realtime::mount(); // one line: WebRTC signalling is live
```

---

## 2. What You Get, and How It Differs from Raw WebSocket

The WebSocket chapter gave you the raw `Router::websocket()` primitive: a path, a handler, and a secure flag. That is the tool you reach for when you build your *own* protocol. The realtime module is the opposite end. It is a *pre-built* protocol for calls, chat, and files, assembled from that same primitive underneath.

The module gives you three surfaces, and you enable only the ones you want:

- **calls** - a WebRTC signalling relay (mesh, peer to peer) plus a self-describing ICE-config endpoint. The relay forwards offer, answer, and ICE frames between peers in a room. It is public: no login to join a room.
- **chat** - persistent channels and messages backed by framework-owned ORM models, a secured chat WebSocket with live presence, typing, and read receipts, and a history endpoint for catch-up on reconnect.
- **files** - permissioned upload and download through a pluggable storage backend (local filesystem by default, S3-compatible optional).

The distinction in one line: with `Router::websocket()` you write the handler and invent the message protocol; with `Realtime::mount()` the protocol is written for you and the browser discovers every path from one config endpoint. Under the hood the realtime WebSockets *are* Tina4 WebSockets. Same room manager, same connection API. You are handed the handlers pre-written.

One thing changes when you drop below the module and read the handlers, and it is the PHP handler convention. Tina4 PHP fires every WebSocket handler as `($connection, $data, $event)`. Position two is always the **payload**; position three is always the **event string**. Python and Node fire `(connection, event, data)`. Same feature, same JSON on the wire, different argument order. Name the parameters in the PHP order or your payload lands in `$event` and nothing works.

This backend pairs with the frontend tina4-js `rtc` module, whose `rtcConfig()` helper fetches the config endpoint so the client and server never drift on paths. Do the backend here. Do the browser side in tina4-js, or with the plain browser APIs shown in section 10.

---

## 3. Mounting the Module: `Realtime::mount()`

Call `mount()` once in your app bootstrap, **before the server starts**: in `index.php` after `new \Tina4\App()`, or in a `src/` bootstrap file. It registers the routes and returns the resolved path map.

```php
<?php
use Tina4\Realtime\Realtime;

Realtime::mount();                                                        // calls only (default)
Realtime::mount('', ['features' => ['calls', 'chat']]);                   // add persistent chat
Realtime::mount('/api/collab', ['features' => ['calls','chat','files']]); // relocate the whole surface
```

The full signature:

```php
\Tina4\Realtime\Realtime::mount(string $prefix = '', array $options = []): array
```

| Key | Meaning |
|---|---|
| `$prefix` | Mounts the whole surface under `/<prefix>` (default: root). Normalised with `trim($prefix, '/')`, so `'/api/collab'`, `'api/collab'`, and `'api/collab/'` resolve identically. |
| `features` | `string[]`; any of `"calls"`, `"chat"`, `"files"`. Default `["calls"]`. |
| `authorize` | Membership guard `callable(string $identity, int $channelId): bool` used by `chat` and `files`. Defaults to a `ChannelMember` lookup. `$identity` is the string user id from the JWT. |
| `storage` | A `StorageBackend` for the `files` feature. Defaults to the env-selected store (`local`). |
| `media` | A media-plane backend. Defaults to the env-selected backend (mesh in Phase 1). |

The call returns the resolved path map, the same map the config endpoint serves, so you can log it or assert against it:

```php
Realtime::mount();
// ['backend' => 'mesh', 'config' => '/api/rtc/config', 'signalling' => '/ws/rtc']

Realtime::mount('', ['features' => ['calls', 'chat']]);
// ['backend' => 'mesh', 'config' => '/api/rtc/config', 'signalling' => '/ws/rtc',
//  'chat' => '/ws/chat', 'messages' => '/api/channels']

Realtime::mount('', ['features' => ['files']]);
// ['backend' => 'mesh', 'config' => '/api/rtc/config', 'files' => '/api/files']
```

`config` is added by any enabled feature, so even a chat-only or files-only mount still exposes `/api/rtc/config`. The config endpoint appends the template tokens (`/{room}`, `/{channel}`, `/{id}/messages`) to these base paths.

### What each feature wires

| Feature | Route registered | Auth |
|---|---|---|
| any | `GET  {p}/api/rtc/config` | public - `->noAuth()` |
| `calls` | `WS   {p}/ws/rtc/{room}` | public (unauthenticated) |
| `chat` | `WS   {p}/ws/chat/{channel}` | secured - `Router::websocket(..., secure: true)`; valid JWT on upgrade |
| `chat` | `GET  {p}/api/channels/{id}/messages` | secured - `->secure()` |
| `files` | `POST {p}/api/files` | auth-required (write route, no `->noAuth()`) |
| `files` | `GET  {p}/api/files/{key}` | secured - `->secure()` |

If `chat` or `files` is enabled, `ensureChatTables()` runs at mount time. A missing database logs an error but does not crash boot (section 11).

---

## 4. The Config Bootstrap: `GET /api/rtc/config`

The client never hardcodes a URL. It fetches this one public endpoint, and everything else comes back in the response: the signalling path, the ICE servers, the chat, messages, and files paths. Move `$prefix` on the server and the client follows automatically. It is registered with `->noAuth()`, public on purpose, because the client needs it before it can authenticate a call.

The body is feature-gated. Only keys for enabled features appear.

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

The `{room}`, `{channel}`, and `{id}` are literal template tokens. The client substitutes the real room name, channel id, or message id before connecting.

```js
const cfg = await fetch("/api/rtc/config").then(r => r.json());

// Join a call room "standup":
const signalUrl = cfg.signalling.replace("{room}", "standup"); // /ws/rtc/standup

// Open chat channel 42:
const chatUrl = cfg.chat.replace("{channel}", "42");           // /ws/chat/42
```

This endpoint is public, and it returns your ICE and TURN configuration including freshly-minted ephemeral TURN credentials (section 5). That is intentional. The browser needs those before it can authenticate anywhere, which is exactly why the credentials are short-lived by design. Do not put secrets in it.

---

## 5. ICE and TURN Servers

Before two browsers connect, each gathers candidate addresses using **ICE**. A **STUN** server tells a browser its public address. A **TURN** server relays media when a direct path is impossible: strict NAT, symmetric firewalls. The realtime module builds this list from environment variables via `Realtime::iceServers()`.

```php
\Tina4\Realtime\Realtime::iceServers(): array
```

A public static. It **always** includes a STUN entry. It adds a TURN entry only when both `TINA4_RTC_TURN_URL` and `TINA4_RTC_TURN_SECRET` are set, using coturn's `use-auth-secret` scheme with time-limited credentials:

```php
$username   = (string)(time() + $ttl);
$credential = base64_encode(hash_hmac('sha1', $username, $secret, true));
```

```php
// No TURN env - STUN only:
[['urls' => ['stun:stun.l.google.com:19302']]]

// TINA4_RTC_TURN_URL + TINA4_RTC_TURN_SECRET set:
[
  ['urls' => ['stun:stun.l.google.com:19302']],
  ['urls' => ['turn:turn.example.com:3478'], 'username' => '1783546725', 'credential' => 'ie7Mm...=='],
]
```

STUN gets most peers connected; TURN is the relay-of-last-resort for peers behind symmetric NATs that STUN cannot punch through. Because TURN credentials are minted fresh on every `/api/rtc/config` call and expire after `TINA4_RTC_TURN_TTL` seconds, you never ship a long-lived TURN secret to the browser.

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
| `TINA4_RTC_BACKEND` | `mesh` | Media backend name. Only `mesh` ships in Phase 1. The reported `backend` is hardcoded to `mesh` regardless of this value. |
| `TINA4_RTC_STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URLs. |
| `TINA4_RTC_TURN_URL` | - | Comma-separated TURN URLs; enables TURN when set together with the secret. |
| `TINA4_RTC_TURN_SECRET` | - | coturn `use-auth-secret` shared secret (drives the ephemeral credentials). |
| `TINA4_RTC_TURN_TTL` | `3600` | Ephemeral TURN credential lifetime, in seconds. |

The media backend is a strategy object. Mesh is the default, zero-dependency backend: browsers connect peer to peer in a mesh. An explicit `media` option wins; otherwise the module reads `TINA4_RTC_BACKEND`. An SFU or LiveKit backend that returns a real join token is the documented Phase-2 drop-in, and because signalling paths are unchanged, the client keeps working.

---

## 6. Signalling: The Mesh Relay

The signalling handler is registered at `WS {p}/ws/rtc/{room}` and is public. There is no `secure:` flag, so anyone can join any room. It follows the PHP WebSocket handler convention:

```php
Router::websocket($paths['signalling'] . '/{room}', function ($connection, $data, $event) {
    // $connection : the WebSocketConnection
    // $data       : the payload - a string on "message", null on "open"/"close"
    // $event      : "open" | "message" | "close"
});
```

Its behaviour is deliberately minimal, a raw relay:

- Reads `$room = $connection->params['room'] ?? '';`. An empty room is a no-op.
- On `"open"` it calls `$connection->joinRoom("rtc:{$room}")`.
- On `"message"` it calls `$connection->broadcastToRoom("rtc:{$room}", (string)$data, true)`, forwarding the raw payload to the other peers in the room, sender excluded, untouched.

Tina4 never parses the SDP. Peers put a `to` field in their own frames and filter for themselves. Rooms are namespaced `rtc:<room>` so signalling rooms never collide with chat channels, which use `chat:<channel>`, on the shared WebSocket manager.

### The connection surface

Every realtime handler works through these `WebSocketConnection` members, all **camelCase** in PHP:

| Member | Purpose |
|---|---|
| `$connection->params` | route params, e.g. `['room' => '...']` / `['channel' => '...']` |
| `$connection->auth` | the verified JWT payload on a secured socket (`null` on a public one) |
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

Because signalling is public, the room name is your only barrier. If a call must be private, gate access at your app layer: issue unguessable room ids, or check membership before you hand the client a room name.

---

## 7. Chat: Secured Channels, Presence, History

Chat is the opposite of signalling: secured. The handler `Realtime::chatHandler($connection, $data, $event)` is registered with `Router::websocket(..., secure: true)`, so a valid JWT is required on the WebSocket upgrade. The router rejects an unauthenticated upgrade with a `401` before your handler runs.

A browser cannot set request headers on `new WebSocket()`, so it passes the token as the **`bearer` subprotocol** (or a `?token=` query param):

```js
const token = localStorage.getItem("jwt");
const url   = (location.origin.replace(/^http/, "ws")) + cfg.chat.replace("{channel}", "42");

const ws = new WebSocket(url, ["bearer", token]);   // browser: bearer subprotocol
// or: new WebSocket(`${url}?token=${token}`)        // query-param fallback
```

Two rules shape the handler:

- **Channels are addressed by integer id.** If `{channel}` is not all digits, `chatHandler` returns silently (`ctype_digit()`) - the socket opens and does nothing, with no error frame.
- **Identity comes only from the verified token** (`$connection->auth`), never from the message payload. The room key is `chat:<channelId>`.

Every frame is JSON; every broadcast is a `json_encode(...)` string. The event flow:

| Event / message `type` | Server behaviour |
|---|---|
| `open` | Authorize. Fail: `sendJson(['type'=>'error','error'=>'not a member of this channel'])` then `close()`. OK: `joinRoom`, send the caller the roster `{"type":"presence","event":"roster","users":[...]}`, then broadcast `{"type":"presence","event":"join","user_id":<id>}` (exclude self). |
| `close` | Broadcast `{"type":"presence","event":"leave","user_id":<id>}` (exclude self). |
| `typing` | Broadcast `{"type":"typing","user_id":<id>}` (exclude self). |
| `read` | Advance the member's read cursor (`last_read_at = now`), broadcast `{"type":"read","user_id":<id>,"at":<iso>}` (exclude self). |
| `message` | Trim `body`; empty is ignored. Persist a `Message`, then broadcast `{"type":"message","message":<saved>}` to everyone including the sender, so an optimistic client reconciles with the server `id` and `created_at`. |

`type` defaults to `"message"` when absent. Unknown types are ignored. Authorization is re-checked on every inbound frame, not just on join. Membership can be revoked mid-session, and the server never trusts an identity carried in the payload.

The `users` roster is the sorted set of distinct identities currently in the room. It is deliberately built as a list, not array keys: PHP would coerce numeric-string keys to ints and send `[1,2]` instead of `["1","2"]`, breaking the client's string comparison.

The saved-message JSON shape, also what history returns:

```jsonc
{ "id": 128, "channel_id": 42, "user_id": "17", "body": "ship it",
  "thread_id": null, "created_at": "2026-07-08T09:14:22Z" }
```

`thread_id` is `null` for a top-level message, or the parent message id for a threaded reply.

### Chat history: `GET {p}/api/channels/{id}/messages`

The catch-up-on-reconnect endpoint, secured with `->secure()`. Load history over HTTP, then keep up over the socket. Identity comes from `$request->user`, the router-attached, already-verified JWT payload. Not a member returns `403`. Query params: `before` (return messages with `id < before`) and `limit` (default 50, clamped to 1..200). Messages come back newest-first (`ORDER BY id DESC`), the standard infinite-scroll-backwards shape.

```bash
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7145/api/channels/42/messages?limit=50"

# Older page, walking backwards from the oldest id you already have:
curl -H "Authorization: Bearer $JWT" \
  "http://localhost:7145/api/channels/42/messages?before=79&limit=50"
```

---

## 8. Files: Upload and Download

Enable with `features=['files']`. Both routes go through a pluggable `StorageBackend`: the `storage` option, or the env-selected store (default `LocalStorage`). The backend resolves once at mount via `Storage::select()`.

**`POST {p}/api/files` - upload (auth-required).** Multipart: a file field named `file` (`$request->files['file']`) plus a form field `channel_id` (required integer, read from body, query, or params). Missing or invalid `channel_id` returns `400`; not a channel member returns `403`; no file returns `400`. It stores the blob under an opaque, collision-free `storage_key` (`Storage::key()`: 16 random bytes as hex plus a sanitized extension, never a user-controlled path), inserts an `Attachment` row (metadata only), and responds `201`:

```jsonc
{ "id": 9, "key": "3f9c...b1.png", "filename": "diagram.png",
  "mime": "image/png", "size": 20481, "url": "<direct url OR {files}/{key}>" }
```

`url` is `$store->url($key)` when the backend exposes a direct URL (for example an S3 presigned GET), otherwise the app download route `{files}/{key}`. This route relies on the framework's default Bearer protection: it has no `->noAuth()`, so it is auth-required like any write route.

```bash
curl -H "Authorization: Bearer $JWT" \
  -F "channel_id=42" \
  -F "file=@diagram.png" \
  http://localhost:7145/api/files
```

**`GET {p}/api/files/{key}` - download (secured with `->secure()`).** Looks up the `Attachment` by `storage_key`; missing returns `404`. Authorizes against the attachment's `channelId`; a non-member returns `403`. If the backend has a direct URL it returns a `302` redirect; otherwise it streams the bytes (`200`) with `Content-Disposition: inline; filename="..."` and `Content-Type = $attachment->mime` (default `application/octet-stream`).

### Storage backends

`Storage::select(?StorageBackend $storage = null)` resolves from the `storage` option or `TINA4_STORAGE_BACKEND` (`local` default, or `s3`). `S3Storage` requires the AWS SDK (`aws/aws-sdk-php`); if it cannot be built (SDK missing, or `TINA4_STORAGE_BUCKET` unset) it falls back to `LocalStorage` with a logged warning: a real store, never a silent no-op.

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

`LocalStorage` resolves every key inside its root and rejects path traversal (keys containing `/`, `\`, `..`, or NUL); its `url()` returns `null`, so files serve through the permissioned download route. `S3Storage` returns a presigned GET URL from `url()`, so clients fetch large blobs straight from object storage and downloads become a `302` redirect.

---

## 9. Auth, Identity, and the Data Model

Chat and files are membership-gated. Two pieces make that work: how an identity is extracted, and how membership is checked.

**Extracting identity.** A stable string user id is pulled from a verified JWT payload, trying the claims `user_id`, then `sub`, then `id`, and returning `null` if none are present. Identities round-trip as strings, so an integer id, a UUID, or an email all work. WebSocket identity comes from `$connection->auth`, the verified payload the router attached on the secured upgrade. HTTP identity comes from `$request->user`, the router-validated payload on the secured route. That is the single source of truth in PHP; do not re-parse the `Authorization` header yourself.

**Checking membership.** The secure default: the caller must be a member of the channel.

```php
(new \Tina4\Realtime\ChannelMember())
    ->count('channel_id = ? AND user_id = ?', [$channelId, $identity]) > 0;
```

Any exception logs and denies. Override it with the `authorize` option, a `callable(string $identity, int $channelId): bool` guard. The internal wrapper denies first whenever `$identity` is null, so an unauthenticated caller is always rejected before your guard runs, and a custom guard never has to handle a null identity. Because it runs on every inbound chat frame, keep a custom guard cheap.

```php
Realtime::mount('', [
    'features'  => ['calls', 'chat'],
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

### Data model

The chat surface persists to framework-owned ORM models, all carrying the `tina4_rt_` table prefix so they never collide with your app's tables. Properties are camelCase (Tina4 PHP ORM convention); the ORM maps them to snake_case columns and to snake_case JSON keys, so the schema and wire shape stay byte-identical across every language. `ensureChatTables()` creates them in dependency order.

| Model | Table | Key fields (camelCase to wire snake_case) |
|---|---|---|
| `Workspace` | `tina4_rt_workspaces` | `id`, `name`, `createdAt` |
| `Channel` | `tina4_rt_channels` | `id`, `workspaceId`, `name`, `kind` (`public`/`private`/`dm`, default `public`), `createdAt` |
| `ChannelMember` | `tina4_rt_channel_members` | `id`, `channelId`, `userId` (string), `role` (default `member`), `lastReadAt` (read cursor) |
| `Message` | `tina4_rt_messages` | `id`, `channelId`, `userId` (string), `body`, `threadId` (nullable parent id), `createdAt`, `editedAt` (nullable) |
| `Attachment` | `tina4_rt_attachments` | `id`, `channelId`, `messageId` (nullable), `storageKey`, `filename`, `mime`, `size`, `thumbKey` (nullable) |

`userId` is a string field everywhere so any JWT identity shape fits (an int id, a UUID, or an email). Because these are ordinary `\Tina4\ORM` models, you seed a channel and its members exactly as in the ORM chapter:

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

Now user `17` can open `WS /ws/chat/{$ch->id}` and pass the history and file checks.

---

## 10. A Complete Example

A minimal collaboration backend: calls, chat, and files on one surface, with a public channel policy, plus a browser client that hardcodes nothing.

### Backend - `index.php`

Mount the surface after `new \Tina4\App()` and before `$app->run()`. A bound database must exist before mounting chat or files (section 11).

```php
<?php
require_once "vendor/autoload.php";

use Tina4\Realtime\Realtime;
use Tina4\Realtime\Channel;
use Tina4\Realtime\ChannelMember;

// A bound database MUST exist before mounting chat/files - see the footguns.
// Tina4 reads TINA4_DATABASE_URL (or your own DB init) here.
$app = new \Tina4\App();

$paths = Realtime::mount('', [
    'features'  => ['calls', 'chat', 'files'],
    'authorize' => function (string $identity, int $channelId): bool {
        $ch = (new Channel())->where('id = ?', [$channelId], 1);
        if (!empty($ch) && $ch[0]->kind === 'public') {
            return true; // any authenticated user may join a public channel
        }
        return (new ChannelMember())
            ->count('channel_id = ? AND user_id = ?', [$channelId, $identity]) > 0;
    },
]);
error_log("realtime mounted: " . json_encode($paths));

// One-time seed so a channel + member exist.
if (empty((new Channel())->where('name = ?', ['general'], 1))) {
    $ch = new Channel();
    $ch->name = "general";
    $ch->kind = "public";
    $ch->save();

    $member = new ChannelMember();
    $member->channelId = $ch->id;
    $member->userId    = "17";
    $member->role      = "owner";
    $member->save();
}

$app->run();
```

Boot it with a STUN/TURN and storage config:

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

### Browser - bootstrap from the config endpoint

The client fetches `/api/rtc/config` first and never hardcodes a path.

```js
const wsBase = location.origin.replace(/^http/, "ws");
const cfg    = await fetch("/api/rtc/config").then(r => r.json());
const token  = localStorage.getItem("jwt");

// -- Call signalling (public, no token) --
const signal = new WebSocket(wsBase + cfg.signalling.replace("{room}", "standup"));
const pc     = new RTCPeerConnection({ iceServers: cfg.iceServers });

pc.onicecandidate = (e) => {
  if (e.candidate) signal.send(JSON.stringify({ type: "ice", candidate: e.candidate }));
};
pc.ontrack = (e) => { document.getElementById("remote").srcObject = e.streams[0]; };

signal.onmessage = async (evt) => {
  const msg = JSON.parse(evt.data);        // raw frame relayed by the server
  if (msg.type === "offer") {
    await pc.setRemoteDescription(msg.sdp);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    signal.send(JSON.stringify({ type: "answer", sdp: answer }));
  } else if (msg.type === "answer") {
    await pc.setRemoteDescription(msg.sdp);
  } else if (msg.type === "ice") {
    await pc.addIceCandidate(msg.candidate);
  }
};

// The caller adds their camera/mic and sends an offer.
async function startCall() {
  const media = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
  document.getElementById("local").srcObject = media;
  media.getTracks().forEach((t) => pc.addTrack(t, media));
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  signal.send(JSON.stringify({ type: "offer", sdp: offer }));
}

// -- Chat (secured: bearer subprotocol) --
const chat = new WebSocket(wsBase + cfg.chat.replace("{channel}", "42"), ["bearer", token]);

chat.onmessage = (evt) => {
  const m = JSON.parse(evt.data);
  if (m.type === "presence" && m.event === "roster") console.log("in room:", m.users);
  if (m.type === "message")                          console.log("msg:", m.message.body);
  if (m.type === "error")                            console.warn(m.error); // e.g. not a member
};
chat.onopen = () => chat.send(JSON.stringify({ type: "message", body: "hello team" }));

// -- History (secured HTTP) --
const history = await fetch(cfg.messages.replace("{id}", "42") + "?limit=50",
  { headers: { Authorization: `Bearer ${token}` } }).then(r => r.json());

// -- File upload (auth-required) --
async function upload(file) {
  const fd = new FormData();
  fd.append("channel_id", "42");
  fd.append("file", file);
  return fetch(cfg.files, { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: fd })
    .then(r => r.json()); // { id, key, filename, mime, size, url }
}
```

The signalling socket is public: anyone with the room name joins. The chat socket and the history and file endpoints require a valid JWT and channel membership. Two browser tabs, both members of channel `42`, joined to room `standup`, will see each other's video peer to peer and each other's messages through the relay.

---

## 11. Footguns and Hard Rules

**The WebSocket handler signature is `($connection, $data, $event)`.** `$event` is `"open"`, `"message"`, or `"close"`; `$data` is a string on `"message"` and `null` otherwise. This is the PHP order: position two is the payload, position three is the event. Python and Node use `(connection, event, data)`. Get it wrong and your payload lands in `$event`.

**Chat needs a bound database, but a missing one does not crash boot.** With `features=['chat']` or `['files']`, `ensureChatTables()` runs at mount. If no database is bound it logs an ERROR and continues: `mount()` still returns the full path map and registers every route, and the failure only resurfaces at query time. Bind a database before mounting realtime with chat or files (`TINA4_DATABASE_URL` or your own DB init), or chat, history, and files will error per-request while the app looks healthy.

**The signalling socket (`/ws/rtc/{room}`) is public.** It is not `secure:`, so anyone can join any room and receive the relayed frames. Only the chat socket is JWT-secured. If a call must be private, gate the room name at your app layer.

**The config endpoint (`/api/rtc/config`) is public.** It returns your ICE and TURN configuration, including freshly-minted ephemeral TURN credentials. This is by design, which is exactly why the TURN credentials are time-limited (`TINA4_RTC_TURN_TTL`). Do not put secrets in it.

**Channels are addressed by integer id.** A non-integer `{channel}` makes `chatHandler` return silently (`ctype_digit()`), no error frame. The client sees a socket that opens and does nothing. Pass the numeric channel id, never its name.

**Authorization is re-checked on every chat frame.** Membership can be revoked mid-session, and identity is always taken from the verified token (`$connection->auth` / `$request->user`), never from the payload. A custom `authorize` must be cheap.

**Empty messages are dropped.** A `message` with an empty or whitespace-only `body` is not persisted and not broadcast. `read`, `typing`, and unknown types never persist anything.

**`backend` is hardcoded to `'mesh'`.** In the path map and config body regardless of `TINA4_RTC_BACKEND`, a Phase-1 shortcut. Only mesh ships in Phase 1 (browsers connect peer to peer). An SFU/LiveKit backend is the documented Phase-2 drop-in with no route changes.

**File upload (`POST /api/files`) has no `->noAuth()`.** It relies on the framework's default Bearer protection, so it is auth-required like any write route. Do not add `->noAuth()` to it.

---

## Where to Go Next

- **The WebSocket chapter** - the raw `Router::websocket()` primitive these handlers are built on, and the connection API (`joinRoom`, `broadcastToRoom`, `sendJson`).
- **The ORM and Authentication chapters** - you seed workspaces, channels, and members with the ORM, and the JWT that secures chat is the same one from the auth chapter.
- **The tina4-js `rtc` module** - the browser side, whose `rtcConfig()` helper wraps `GET /api/rtc/config` so the client and server never drift.

You started this chapter wanting a call button. You end it with calls, chat, presence, read receipts, history, and file transfer, mounted in one line, carrying no media, running no server you did not already have. The hard part of real-time was never the video. It was finding the other browser, and Tina4 relays that in a few lines of text.
