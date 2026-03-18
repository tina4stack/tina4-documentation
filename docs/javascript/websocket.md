# WebSocket

Signal-driven WebSocket client with automatic reconnect and exponential backoff. Under 1 KB gzipped.

## Installation

```ts
import { ws } from 'tina4js';
// or tree-shake:
import { ws } from 'tina4js/ws';
```

## Quick Start

```ts
import { ws, effect } from 'tina4js';

const socket = ws.connect('wss://api.example.com/live');

// React to connection status
effect(() => {
  console.log('Status:', socket.status.value);  // 'connecting' | 'open' | 'closed' | 'reconnecting'
});

// React to incoming messages
effect(() => {
  const msg = socket.lastMessage.value;
  if (msg) console.log('Received:', msg);
});

// Send data (objects are auto-stringified)
socket.send({ type: 'ping' });

// Close when done
socket.close();
```

## API

### `ws.connect(url, options?)`

Opens a managed WebSocket connection. Returns a `ManagedSocket`.

```ts
const socket = ws.connect('wss://api.example.com/chat', {
  reconnect: true,          // auto-reconnect on disconnect (default: true)
  reconnectDelay: 1000,     // initial delay ms (default: 1000)
  reconnectMaxDelay: 30000, // max delay ms with backoff (default: 30000)
  reconnectAttempts: 10,    // max attempts before giving up (default: Infinity)
  protocols: 'chat',        // WebSocket sub-protocol(s)
});
```

### Reactive Signals

| Signal | Type | Description |
|--------|------|-------------|
| `socket.status` | `Signal<SocketStatus>` | `'connecting'` \| `'open'` \| `'closed'` \| `'reconnecting'` |
| `socket.connected` | `Signal<boolean>` | `true` when status is `'open'` |
| `socket.lastMessage` | `Signal<unknown>` | Last received message (JSON auto-parsed) |
| `socket.error` | `Signal<Event \| null>` | Last error event, or `null` |
| `socket.reconnectCount` | `Signal<number>` | Number of reconnect attempts so far |

### `socket.send(data)`

Send data. Strings are sent as-is. Objects and arrays are auto-stringified with `JSON.stringify`.

```ts
socket.send('hello');
socket.send({ type: 'message', text: 'Hi there!' });
```

Throws if the socket is not connected.

### `socket.on(event, handler)`

Listen for events. Returns an unsubscribe function.

```ts
const off = socket.on('message', (data) => {
  console.log('message:', data);
});

socket.on('open',  () => console.log('connected'));
socket.on('close', (code, reason) => console.log('closed', code, reason));
socket.on('error', (event) => console.error('error', event));

// Later:
off(); // unsubscribe
```

### `socket.pipe(signal, reducer)`

Pipe incoming messages into a signal via a reducer function. Returns an unsubscribe function.

```ts
import { signal } from 'tina4js';

const messages = signal<string[]>([]);

// Append each new message to the array
socket.pipe(messages, (msg, current) => [...current, msg as string]);

// In your template, messages is always up to date:
// html`${() => messages.value.map(m => html`<p>${m}</p>`)}`
```

### `socket.close(code?, reason?)`

Intentionally close the connection. Prevents auto-reconnect.

```ts
socket.close();              // clean close (code 1000)
socket.close(4000, 'logout'); // custom code and reason
```

## Auto-Reconnect

When the connection drops unexpectedly, tina4js reconnects automatically using exponential backoff:

```
attempt 1: 1s delay
attempt 2: 2s delay
attempt 3: 4s delay
attempt 4: 8s delay
...capped at 30s
```

The `status` signal changes to `'reconnecting'` between attempts so you can show UI feedback:

```ts
effect(() => {
  const s = socket.status.value;
  statusEl.textContent =
    s === 'open'         ? '🟢 Connected' :
    s === 'reconnecting' ? `🟡 Reconnecting (${socket.reconnectCount.value})` :
                           '🔴 Disconnected';
});
```

## Real-World Example: Chat

```ts
import { ws, signal, html, effect } from 'tina4js';

const socket = ws.connect('wss://chat.example.com/ws');
const messages = signal<string[]>([]);
const inputVal = signal('');

// Pipe all incoming messages into the array
socket.pipe(messages, (msg, curr) => [...curr, msg as string]);

const view = html`
  <div>
    <div ?hidden=${() => socket.connected.value}>
      Connecting… (attempt ${socket.reconnectCount})
    </div>

    <ul>
      ${() => messages.value.map(m => html`<li>${m}</li>`)}
    </ul>

    <input .value=${inputVal} @input=${(e: Event) => {
      inputVal.value = (e.target as HTMLInputElement).value;
    }}>
    <button
      ?disabled=${() => !socket.connected.value}
      @click=${() => {
        socket.send({ text: inputVal.value });
        inputVal.value = '';
      }}
    >Send</button>
  </div>
`;

document.getElementById('root')!.appendChild(view);
```

## Integrating with Tina4 Backend

If you're using tina4-python or tina4-php with WebSocket support, connect like this:

```ts
import { ws, api } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

const token = localStorage.getItem('token');
const socket = ws.connect(`wss://myapp.com/ws?token=${token}`);

socket.on('message', (msg) => {
  // handle server push events
});
```

## Bundle Size

| Import | Gzipped |
|--------|---------|
| `tina4js/ws` | ~0.91 KB |
