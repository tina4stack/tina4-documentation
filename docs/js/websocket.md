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

## Real-World Example: Live Notifications

```ts
import { ws, signal, html } from 'tina4js';

const socket = ws.connect('wss://api.example.com/notifications');
const notifications = signal([]);
const unreadCount = signal(0);

// Pipe notifications into state
socket.pipe(notifications, (msg, current) => {
  const notification = { ...msg, read: false, time: new Date() };
  return [notification, ...current].slice(0, 50); // keep last 50
});

// Update unread count reactively
socket.on('message', () => {
  unreadCount.value++;
});

function markAllRead() {
  notifications.value = notifications.value.map(n => ({ ...n, read: true }));
  unreadCount.value = 0;
  socket.send({ type: 'mark-read' });
}

const view = html`
  <div class="notifications">
    <div class="header">
      <h3>Notifications ${() => unreadCount.value > 0
        ? html`<span class="badge">${unreadCount}</span>`
        : null}</h3>
      <button @click=${markAllRead}>Mark all read</button>
    </div>
    <ul>
      ${() => notifications.value.map(n => html`
        <li class=${() => n.read ? 'read' : 'unread'}>
          <strong>${n.title}</strong>
          <p>${n.body}</p>
          <time>${n.time.toLocaleTimeString()}</time>
        </li>
      `)}
    </ul>
  </div>
`;
```

## Real-World Example: Live Dashboard Metrics

```ts
import { ws, signal, computed, html } from 'tina4js';

const socket = ws.connect('wss://api.example.com/metrics', {
  reconnect: true,
  reconnectDelay: 2000,
});

const metrics = signal({ cpu: 0, memory: 0, requests: 0, errors: 0 });
const history = signal([]);

// Update metrics on every message
socket.pipe(metrics, (msg) => msg);

// Keep a rolling history of the last 60 data points
socket.on('message', (data) => {
  history.value = [...history.value.slice(-59), {
    ...data,
    timestamp: Date.now(),
  }];
});

const errorRate = computed(() => {
  const m = metrics.value;
  return m.requests > 0 ? ((m.errors / m.requests) * 100).toFixed(1) : '0.0';
});

const view = html`
  <div class="dashboard">
    <div class="status-bar">
      ${() => socket.connected.value
        ? html`<span class="online">Live</span>`
        : html`<span class="offline">Reconnecting (${socket.reconnectCount})...</span>`}
    </div>
    <div class="grid">
      <div class="metric">
        <label>CPU</label>
        <span>${() => metrics.value.cpu}%</span>
      </div>
      <div class="metric">
        <label>Memory</label>
        <span>${() => metrics.value.memory}%</span>
      </div>
      <div class="metric">
        <label>Requests/s</label>
        <span>${() => metrics.value.requests}</span>
      </div>
      <div class="metric">
        <label>Error Rate</label>
        <span>${errorRate}%</span>
      </div>
    </div>
  </div>
`;
```

## Real-World Example: Collaborative Editing

```ts
import { ws, signal, html, batch } from 'tina4js';

const socket = ws.connect('wss://api.example.com/collab/doc-123');
const content = signal('');
const cursors = signal({});  // { [userId]: { line, col, name, color } }

// Handle different message types
socket.on('message', (msg) => {
  batch(() => {
    switch (msg.type) {
      case 'content':
        content.value = msg.text;
        break;
      case 'cursor':
        cursors.value = {
          ...cursors.value,
          [msg.userId]: { line: msg.line, col: msg.col, name: msg.name, color: msg.color },
        };
        break;
      case 'user-left':
        const c = { ...cursors.value };
        delete c[msg.userId];
        cursors.value = c;
        break;
    }
  });
});

// Send edits to server
function onEdit(e) {
  const text = e.target.value;
  content.value = text;
  socket.send({ type: 'edit', text });
}

// Send cursor position
function onCursorMove(e) {
  socket.send({
    type: 'cursor',
    line: e.target.selectionStart,
    col: e.target.selectionEnd,
  });
}

const view = html`
  <div class="editor">
    <div class="collaborators">
      ${() => Object.values(cursors.value).map(c => html`
        <span style="color: ${c.color}">${c.name}</span>
      `)}
    </div>
    <textarea .value=${content}
              @input=${onEdit}
              @click=${onCursorMove}
              @keyup=${onCursorMove}
              ?disabled=${() => !socket.connected.value}></textarea>
    <div ?hidden=${() => socket.connected.value} class="overlay">
      Reconnecting...
    </div>
  </div>
`;
```

## Integrating with Tina4 Backend

If you're using tina4-python or tina4-php with WebSocket support, connect like this:

```ts
import { ws, api } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

const token = localStorage.getItem('tina4_token');
const socket = ws.connect(`wss://myapp.com/ws?token=${token}`);

// Handle server push events
socket.on('message', (msg) => {
  switch (msg.event) {
    case 'order.created':
      // refresh order list
      break;
    case 'user.updated':
      // update user profile
      break;
  }
});

// Send actions
socket.send({ action: 'subscribe', channel: 'orders' });
```

## Bundle Size

| Import | Gzipped |
|--------|---------|
| `tina4js/ws` | ~0.91 KB |
