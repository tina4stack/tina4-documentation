# Chapter 18: Real-time (WebRTC)

## Peer-to-Peer Without a Media Server

A user clicks "Join call" and sees three other faces. Someone drops a file into the chat and it appears on every screen. Another person shares their terminal. All of it happens in the browser, live, with no polling and no round-trip through a media server you had to build and scale.

The reflex is to reach for a stack: an SFU, TURN infrastructure, a signalling protocol, a chat backend, an upload service. That is a lot of moving parts before the first "hello" crosses the wire.

tina4-js takes the mesh route instead. Browsers connect directly to each other. Audio, video, and screen share flow peer to peer. The server does two small jobs: it relays the WebRTC handshake (the SDP and ICE messages) over a signalling WebSocket, and it tells the client where everything lives through one config endpoint. The media never touches your backend.

The `rtc` module wraps all of it, calls and chat and file sharing, behind three signal-driven functions. Bind the signals into an `html` template and the UI stays live on its own.

---

## 1. The `rtc` Module

The client pairs with a Tina4 backend's `realtime()` mount. It has three surfaces:

- **`rtc.call(room, options?)`** - mesh WebRTC (audio, video, screen share) over a signalling WebSocket, using the perfect-negotiation pattern.
- **`rtc.chat(channel, options?)`** - persistent chat: messages, presence, typing indicators, read receipts, and REST history.
- **`rtc.upload(channel, file, options?)`** and **`rtc.fetchBlob(key, options?)`** - file transfer.

Everything reactive is a `Signal<T>` from `tina4js`, so it drops straight into templates. The new-reference rule from the Signals chapter applies: the module replaces the signal arrays wholesale (`peers`, `messages`, `presence`, `typing`). Read them; never `.push()` or mutate them in place.

```typescript
import { rtc } from 'tina4js/rtc';
```

One distinction causes more bugs than any other, so learn it first. `rtc.call()` is async; `rtc.chat()` is sync. The call returns a `Promise`, because it fetches config and prompts for camera and mic, so you `await` it. The chat returns its session synchronously and connects the socket in the background.

```typescript
const call = await rtc.call('standup');   // await
const chat = rtc.chat('general');         // no await
```

---

## 2. Bootstrapping: `GET /api/rtc/config`

The client hardcodes no URLs. It asks the backend where the ICE servers and the WS and HTTP routes live, then wires itself up from the answer. `rtc.call()` does this fetch for you, but you can also call it directly:

```typescript
import { rtcConfig } from 'tina4js/rtc';

const cfg = await rtcConfig();          // GET /api/rtc/config
```

It is also exposed on the object as `rtc.config`. Note that this is the function itself (`rtc.config === rtcConfig`), not a cached config object. Call it:

```typescript
const cfg = await rtc.config();         // same thing
```

A non-2xx response throws `[tina4] rtc config fetch failed: <status>`.

```typescript
interface RtcConfig {
  backend: string;
  iceServers?: RTCIceServer[];   // STUN/TURN for the peer connections
  signalling?: string;           // call WS path, e.g. "/ws/rtc/{room}"
  chat?: string;                 // chat WS path, e.g. "/ws/chat/{channel}"
  messages?: string;             // history HTTP path, e.g. "/api/channels/{id}/messages"
  files?: string;                // upload/download path, e.g. "/api/files"
}
```

A `{room}`, `{channel}`, or `{id}` placeholder in a path template is substituted with the value you pass. If the template has no placeholder, the client appends `/<value>` instead.

Every `rtc.call()` fetches config unless you hand it one. If you open several rooms, fetch once and pass it along to skip the repeat network trips:

```typescript
const config = await rtc.config();
const a = await rtc.call('room-a', { config });
const b = await rtc.call('room-b', { config });
```

---

## 3. Calls: `rtc.call(room, options?)`

Each participant opens one `RTCPeerConnection` per other participant in the room, a full mesh. The server relays only `hello`, `welcome`, `bye`, `desc`, and `ice` messages between peers; the audio and video are strictly peer to peer. Glare is handled for you with the perfect-negotiation pattern, so simultaneous offers never wedge the connection.

```typescript
const call = await rtc.call('standup');   // camera + mic by default
```

### `CallOptions`

| Option | Type | Default | Behaviour |
|---|---|---|---|
| `config` | `RtcConfig` | - | Pre-fetched config; skips the per-call fetch. |
| `configUrl` | `string` | `'/api/rtc/config'` | Where to fetch config if `config` is not given. |
| `signallingUrl` | `string` | config's `signalling` or `/ws/rtc` | Explicit WS base; `{room}` is filled or appended. |
| `iceServers` | `RTCIceServer[]` | config's `iceServers` or `[]` | ICE server override. |
| `media` | `MediaStreamConstraints \| MediaStream \| false` | `{ audio: true, video: true }` | Local media. A ready `MediaStream` is used as-is; `false` means receive-only (no `getUserMedia` prompt). |

### `CallSession`

```typescript
interface CallSession {
  readonly status: Signal<CallStatus>;              // 'idle' | 'connecting' | 'connected' | 'closed'
  readonly localStream: Signal<MediaStream | null>; // your camera/mic (null if media: false)
  readonly peers: Signal<RemotePeer[]>;             // remote participants + their streams
  readonly screenSharing: Signal<boolean>;
  readonly error: Signal<Error | null>;             // last negotiation/ICE error
  readonly id: string;                              // this peer's id in the room
  shareScreen(): Promise<void>;
  stopScreen(): Promise<void>;
  toggleAudio(on?: boolean): boolean;               // returns new enabled state
  toggleVideo(on?: boolean): boolean;
  leave(): void;
}

interface RemotePeer { id: string; stream: MediaStream | null; }
```

### The status signal

```typescript
type CallStatus = 'idle' | 'connecting' | 'connected' | 'closed';
```

A live session starts at `'connecting'`, flips to `'connected'` when a peer connection actually reaches `connected`, and lands on `'closed'` after `leave()`. `'idle'` exists in the type but a live session never emits it, so do not wait for it. A lone occupant of a room stays at `'connecting'` until someone else joins.

### Binding streams into the DOM

`MediaStream` objects are set on `<video>` elements through the `.srcObject` property. Use an `effect` for the local stream and bind the remote peers in a `mount`:

```typescript
import { rtc } from 'tina4js/rtc';
import { html, mount, effect } from 'tina4js';

const call = await rtc.call('standup');

// local preview
effect(() => {
  const local = call.localStream.value;
  if (local) (document.querySelector('#me') as HTMLVideoElement).srcObject = local;
});

// remote peers - one <video> each, re-rendered as peers come and go
mount('#peers', () => html`
  ${call.peers.value.map(p => html`
    <video autoplay playsinline .srcObject=${p.stream}></video>
  `)}
`);
```

### Controls

`toggleAudio()` and `toggleVideo()` enable or disable the local track and return the new state (or `false` if there is no such track). Pass an explicit boolean to force it:

```typescript
call.toggleAudio();       // toggle mic
call.toggleVideo(false);  // force camera off
await call.shareScreen(); // getDisplayMedia + swap the outgoing video track
await call.stopScreen();  // restore the camera track
```

`shareScreen()` replaces the outgoing video track on the existing peer connections. Clicking the browser's native "Stop sharing" restores the camera automatically.

### Receive-only viewer

Pass `media: false` for a watcher that consumes streams without ever prompting for a camera:

```typescript
const viewer = await rtc.call('standup', { media: false });
```

### Leaving

```typescript
call.leave();
```

`leave()` is terminal. It sends `bye`, closes every peer connection, stops your local tracks (the camera light goes off), closes the signalling socket, and sets `status` to `'closed'`. The session cannot be reused. Call `rtc.call()` again to rejoin.

Calls carry no token. The signalling WebSocket opens without auth, and there is no `token` option on `rtc.call()`. Secure a private room on the server (the signalling route), not from this client. Only `chat` and file operations take a `token`.

---

## 4. Chat: `rtc.chat(channel, options?)`

A message-and-presence channel over its own WebSocket, backed by a REST history endpoint. It returns synchronously; the socket connects in the background, so watch `session.connected`.

```typescript
const chat = rtc.chat('general', { token: myJwt });
```

The `channel` argument accepts a `string` or a `number`.

### `ChatOptions`

| Option | Type | Default | Behaviour |
|---|---|---|---|
| `token` | `string` | - | JWT for the secured chat WS and the history calls (bearer on the WS, `Authorization` header on HTTP). |
| `url` | `string` | `'/ws/chat'` | Explicit WS base; `{channel}` is filled or appended. |
| `apiBase` | `string` | `''` (same origin) | HTTP base for history. |
| `messagesPath` | `string` | `'/api/channels/{id}/messages'` | History path template; `{id}` is the channel. |
| `typingTimeout` | `number` | `3000` | ms a typing indicator lingers before auto-clearing. |

### `ChatSession`

```typescript
interface ChatSession {
  readonly status: Signal<SocketStatus>;    // 'connecting' | 'open' | 'closed' | 'reconnecting'
  readonly connected: Signal<boolean>;
  readonly messages: Signal<ChatMessage[]>; // live + prepended history
  readonly presence: Signal<string[]>;      // user ids currently in the channel
  readonly typing: Signal<string[]>;        // user ids currently typing (auto-expire)
  send(body: string, threadId?: number): void;
  sendTyping(): void;
  markRead(): void;
  history(before?: number, limit?: number): Promise<ChatMessage[]>;
  close(): void;
}

interface ChatMessage {
  id?: number;
  channel_id?: number;
  user_id?: string;
  body?: string;
  thread_id?: number | null;
  created_at?: string;
}
```

`status` and `connected` are the very same signals from the underlying WebSocket client in the WebSocket chapter, so reconnection and backoff come along for free.

### A minimal chat panel

```typescript
import { rtc } from 'tina4js/rtc';
import { html, mount } from 'tina4js';

const chat = rtc.chat('general', { token: myJwt });

await chat.history();        // load the last 50, prepended into chat.messages

mount('#log', () => html`
  ${chat.messages.value.map(m => html`<p><b>${m.user_id}</b> ${m.body}</p>`)}
`);

mount('#who', () => html`Online: ${chat.presence.value.join(', ')}`);
mount('#typing', () => html`
  ${chat.typing.value.length ? `${chat.typing.value.join(', ')} typing...` : ''}
`);

const input = document.querySelector('#msg') as HTMLInputElement;
input.addEventListener('input', () => chat.sendTyping());
input.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && input.value) { chat.send(input.value); input.value = ''; }
});
```

### Sending, typing, and read receipts

```typescript
chat.send('hello everyone');       // a top-level message
chat.send('in reply', 42);         // reply into thread_id 42
chat.sendTyping();                 // emit a typing signal
chat.markRead();                   // emit a read receipt
```

### Paging older messages

`history()` both prepends the fetched (older) messages into the `messages` signal and returns the raw rows (newest-first). Render from the signal; do not also append the return value or you will duplicate every message. To load an earlier page, pass the oldest id you already hold as `before`:

```typescript
const oldest = chat.messages.value[0]?.id;
await chat.history(oldest, 50);
```

### Teardown

```typescript
chat.close();   // clears typing timers and closes the socket
```

`markRead()` sends a `read` event and the server rebroadcasts it, but `ChatSession` does not expose the raw socket, so there is no built-in signal for incoming read receipts through the returned API.

---

## 5. Files: `rtc.upload` and `rtc.fetchBlob`

`rtc.upload()` POSTs a `multipart/form-data` body (`channel_id` plus `file`) to the files path and resolves with the stored record:

```typescript
const res = await rtc.upload('general', fileInput.files![0], { token: myJwt });
// res: UploadResult
```

```typescript
interface UploadResult {
  id: number;
  key: string;
  filename: string;
  mime: string;
  size: number;
  url: string;   // presigned URL for S3 backends; a route path for local storage
}

interface FileOptions {
  token?: string;
  apiBase?: string;     // default '' (same origin)
  filesPath?: string;   // default '/api/files'
}
```

A secured GET route cannot be reached by a bare `<img src>`, since there is no way to attach a bearer header to it. `rtc.fetchBlob()` fetches the file with the auth header and hands back an object URL you drop straight into `<img src>` or `<a href>`:

```typescript
const src = await rtc.fetchBlob(res.key, { token: myJwt });
imgEl.src = src;
```

For an S3 backend, `UploadResult.url` is already a presigned URL. Pass it to `fetchBlob` (it is used directly) or set it as `src` without a fetch at all.

Object URLs must be revoked. `fetchBlob()` returns a `URL.createObjectURL(...)` handle. It leaks until you release it, so call `URL.revokeObjectURL(src)` when the element unmounts or the image is no longer needed:

```typescript
URL.revokeObjectURL(src);
```

---

## 6. Real Example: A Call + Chat Room

One room. Video down the side, chat down the middle, a file drop at the bottom. Every piece of live state, peers and messages and presence and connection status, is a signal, so the template renders itself as the world changes. Nothing here polls.

```typescript
import { rtc } from 'tina4js/rtc';
import { html, mount, effect, signal } from 'tina4js';

async function room(name: string, token: string) {
  // Fetch config once, share it with the call.
  const config = await rtc.config();

  const call = await rtc.call(name, { config });
  const chat = rtc.chat(name, { token });
  const draft = signal('');

  await chat.history();

  // local preview
  effect(() => {
    const local = call.localStream.value;
    if (local) (document.querySelector('#me') as HTMLVideoElement).srcObject = local;
  });

  // remote peers
  mount('#peers', () => html`
    ${call.peers.value.map(p => html`
      <video class="peer" autoplay playsinline .srcObject=${p.stream}></video>
    `)}
  `);

  const send = () => {
    const body = draft.value.trim();
    if (body) { chat.send(body); draft.value = ''; }
  };

  const onFile = async (e: Event) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    const res = await rtc.upload(name, file, { token });
    chat.send(`shared a file: ${res.filename}`);   // announce it in the channel
  };

  mount('#app', () => html`
    <div class="room">
      <header>
        <span>Call: ${call.status}</span>
        <span>Chat: ${chat.status}</span>
        <span>Online: ${chat.presence.value.length}</span>
      </header>

      <section class="stage">
        <video id="me" class="me" autoplay playsinline muted></video>
        <div id="peers"></div>
      </section>

      <aside class="chat">
        <div class="log">
          ${chat.messages.value.map(m => html`
            <p><b>${m.user_id}</b> ${m.body}</p>
          `)}
        </div>
        <div class="typing">
          ${chat.typing.value.length ? `${chat.typing.value.join(', ')} typing...` : ''}
        </div>
        <form @submit=${(e: Event) => { e.preventDefault(); send(); }}>
          <input
            placeholder="Message..."
            .value=${draft}
            @input=${(e: Event) => {
              draft.value = (e.target as HTMLInputElement).value;
              chat.sendTyping();
            }}
          />
          <button type="submit" ?disabled=${() => !chat.connected.value}>Send</button>
        </form>
        <input type="file" @change=${onFile} />
      </aside>

      <footer>
        <button @click=${() => call.toggleAudio()}>Mute</button>
        <button @click=${() => call.toggleVideo()}>Camera</button>
        <button @click=${() => call.shareScreen()}>Share screen</button>
        <button @click=${() => { call.leave(); chat.close(); }}>Leave</button>
      </footer>
    </div>
  `);
}

room('standup', localStorage.getItem('tina4_token') ?? '');
```

The `#me` video is `muted` on purpose. It is your own microphone echoing back, and unmuting it causes feedback. Always `leave()` the call and `close()` the chat together on teardown; both release sockets and timers, and `leave()` frees the camera and mic.

---

## 7. Hard Rules

WebRTC has sharp edges. These are the ones the module cannot paper over for you:

1. **`rtc.call()` is async; `rtc.chat()` is sync.** `await` the call, not the chat.
2. **`rtc.config` is the fetch function, not a config object.** It is `=== rtcConfig`. Call it: `await rtc.config()`.
3. **`status` only reaches `'connected'` when a remote peer connects.** A lone occupant stays `'connecting'`, and `'idle'` is never emitted by a live session.
4. **`leave()` is terminal.** It stops your tracks, closes everything, and cannot be reused. Call `rtc.call()` again to rejoin.
5. **Calls take no `token`.** Secure a private room on the signalling route server-side.
6. **`history()` mutates and returns.** Render from the `messages` signal; do not also append its return value.
7. **`fetchBlob()` leaks without cleanup.** Revoke the object URL with `URL.revokeObjectURL()` when done.
8. **Signals follow the new-reference rule.** Read `peers`, `messages`, `presence`, and `typing`; never mutate them in place.
9. **Always tear down.** `leave()` the call and `close()` the chat to release cameras, sockets, and timers.

---

## 8. Backend Pairing

This module is the front half of a pair. It talks to a Tina4 backend that mounts the realtime module, which serves `GET /api/rtc/config`, relays the signalling WebSocket, brokers the chat channel, and stores files. Nothing here works until that mount is in place, and the client deliberately learns every path and ICE server from the config endpoint, so the two sides stay in sync without you hardcoding anything.

Wire up the backend in your language of choice. Python, PHP, and Node.js mount it with `realtime()`; Ruby mounts it with `Tina4::Realtime.mount`. Each framework's own Real-time Collaboration chapter walks the server side and the same room this chapter's client connects to.

---

## Summary

| What | How |
|---|---|
| Import | `import { rtc } from 'tina4js/rtc'` |
| Fetch config | `await rtc.config(url?)` - `GET /api/rtc/config` |
| Start or join a call | `await rtc.call(room, options?)` - async |
| Local / remote media | `call.localStream` / `call.peers` - bind to `<video>.srcObject` |
| Call status | `call.status` - `'idle' \| 'connecting' \| 'connected' \| 'closed'` |
| Mic / camera | `call.toggleAudio(on?)` / `call.toggleVideo(on?)` |
| Screen share | `call.shareScreen()` / `call.stopScreen()` |
| Leave a call | `call.leave()` - terminal, releases the camera |
| Open a chat | `rtc.chat(channel, options?)` - sync |
| Send a message | `chat.send(body, threadId?)` |
| Typing / read | `chat.sendTyping()` / `chat.markRead()` |
| Presence / typing | `chat.presence` / `chat.typing` signals |
| Load history | `await chat.history(before?, limit?)` - prepends into `messages` |
| Close a chat | `chat.close()` |
| Upload a file | `await rtc.upload(channel, file, options?)` returns `UploadResult` |
| Permissioned download | `await rtc.fetchBlob(keyOrUrl, options?)` returns an object URL (revoke it) |
| Backend | Pairs with a Tina4 `realtime()` mount |

You started with a call button and a fear of infrastructure. You end with calls, chat, presence, typing, history, screen share, and permissioned file transfer, every live value a signal that renders itself, and not one media server to run. The browser already knew how to talk peer to peer. tina4-js just handed it the room.
