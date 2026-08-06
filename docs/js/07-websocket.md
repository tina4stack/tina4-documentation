# Chapter 7: WebSocket

## Real-Time Without the Headache

A chat message arrives. A stock price changes. A deployment finishes. A sensor reading spikes. The data exists on the server right now, but your user stares at stale numbers until they refresh the page.

HTTP requests are pull. You ask, the server answers. WebSocket is push. The server sends data the moment it exists. The user sees it the moment it arrives.

The raw WebSocket API gives you this, but it hands you a connection object and wishes you luck. Reconnection? Write it yourself. State tracking? Manual. Feeding messages into your reactive UI? Also manual.

tina4-js wraps all of it. One function call opens the connection. Five reactive signals track the state. A pipe function streams messages into your signals with a reducer. Auto-reconnect handles dropped connections with exponential backoff.

---

## 1. The WebSocket Client

The tina4-js WebSocket client adds three things on top of the browser API:

1. **Reactive signals** -- `status`, `connected`, `lastMessage`, `error`, `reconnectCount`
2. **Auto-reconnect** -- exponential backoff, configurable attempts
3. **Signal piping** -- stream messages into signals with a reducer

```typescript
import { ws } from 'tina4js';
```

---

## 2. Connecting

```typescript
const socket = ws.connect('wss://api.example.com/ws');
```

One line. The connection starts. The `socket` object gives you reactive state and methods to send, listen, pipe, and close.

### With Options

```typescript
const socket = ws.connect('wss://api.example.com/ws', {
  reconnect: true,           // auto-reconnect on disconnect (default: true)
  reconnectDelay: 1000,      // initial delay in ms (default: 1000)
  reconnectMaxDelay: 30000,  // max delay with backoff (default: 30000)
  reconnectAttempts: 10,     // max attempts (default: Infinity)
  protocols: 'chat-v1',     // WebSocket sub-protocols
});
```

### Options Reference

| Option | Type | Default | Description |
|---|---|---|---|
| `reconnect` | `boolean` | `true` | Enable auto-reconnect |
| `reconnectDelay` | `number` | `1000` | Initial reconnect delay (ms) |
| `reconnectMaxDelay` | `number` | `30000` | Max delay after backoff (ms) |
| `reconnectAttempts` | `number` | `Infinity` | Max reconnect attempts |
| `protocols` | `string \| string[]` | `[]` | WebSocket sub-protocols |

---

## 3. Reactive Signals

The socket exposes five signals:

```typescript
const socket = ws.connect('wss://api.example.com/ws');

socket.status;          // Signal<'connecting' | 'open' | 'closed' | 'reconnecting'>
socket.connected;       // Signal<boolean>
socket.lastMessage;     // Signal<unknown>
socket.error;           // Signal<Event | null>
socket.reconnectCount;  // Signal<number>
```

Use them directly in templates:

```typescript
import { html } from 'tina4js';

html`
  <div>
    <p>Status: ${socket.status}</p>
    <p>Connected: ${() => socket.connected.value ? 'Yes' : 'No'}</p>
    <p>Reconnect attempts: ${socket.reconnectCount}</p>
    <p>Last message: ${() => JSON.stringify(socket.lastMessage.value)}</p>
  </div>
`
```

These update the moment the connection state changes. No polling. No callbacks. No manual state management. Drop them in a template and the UI stays current.

### Status Flow

```
connecting -> open -> closed -> reconnecting -> open -> ...
```

- **`connecting`** -- initial connection attempt
- **`open`** -- connected and ready
- **`closed`** -- disconnected
- **`reconnecting`** -- waiting to reconnect (auto-reconnect active)

---

## 4. Sending Messages

```typescript
// Send a string
socket.send('hello');

// Send an object (auto-JSON.stringify)
socket.send({ type: 'chat', message: 'Hello!' });

// Send with a specific structure
socket.send({
  action: 'subscribe',
  channel: 'notifications',
});
```

Objects are automatically serialized with `JSON.stringify()`. Strings are sent as-is.

If the socket is not connected, `send()` throws:

```typescript
try {
  socket.send('hello');
} catch (e) {
  console.error('Not connected');
}
```

Check the `connected` signal before sending:

```typescript
if (socket.connected.value) {
  socket.send(data);
}
```

---

## 5. Listening for Events

The `on()` method returns an unsubscribe function:

```typescript
// Messages
const unsub = socket.on('message', (data) => {
  console.log('Received:', data);
});

// Connection opened
socket.on('open', () => {
  console.log('Connected!');
  socket.send({ type: 'auth', token: 'my-token' });
});

// Connection closed
socket.on('close', (code, reason) => {
  console.log(`Closed: ${code} ${reason}`);
});

// Errors
socket.on('error', (event) => {
  console.error('WebSocket error:', event);
});

// Later, unsubscribe
unsub();
```

### Message Parsing

Messages are automatically JSON-parsed. If the message is valid JSON, you get an object. If not, you get the raw string:

```typescript
socket.on('message', (data) => {
  // data is already parsed if it was JSON
  if (typeof data === 'object') {
    console.log(data.type, data.payload);
  } else {
    console.log('Raw string:', data);
  }
});
```

---

## 6. pipe() -- Stream Messages Into Signals

This is where WebSocket meets reactivity. A message arrives. It flows into a signal through a reducer function. The signal updates. Every subscriber -- text nodes, computed values, effects -- responds. The data moves from server to DOM without a single manual step.

`pipe()` connects a WebSocket message stream to a signal with a reducer:

```typescript
import { signal } from 'tina4js';

const messages = signal<string[]>([]);

socket.pipe(messages, (msg, current) => {
  const chatMsg = msg as { text: string };
  return [...current, chatMsg.text];
});
```

Every time a message arrives:

1. The reducer runs with `(message, currentSignalValue)`
2. The return value is assigned to `messages.value`
3. Everything subscribed to `messages` updates

No event listener that grabs a signal reference and mutates it. No manual state management. The pipe is declarative, testable, and composable. Data flows in one direction: server to socket to reducer to signal to DOM.

### Multiple Pipes

You can pipe the same socket to multiple signals:

```typescript
const notifications = signal<any[]>([]);
const userCount = signal(0);

// Route messages to different signals based on type
socket.pipe(notifications, (msg, current) => {
  const m = msg as { type: string; data: any };
  if (m.type === 'notification') return [...current, m.data];
  return current; // ignore non-notification messages
});

socket.pipe(userCount, (msg, current) => {
  const m = msg as { type: string; count: number };
  if (m.type === 'user_count') return m.count;
  return current;
});
```

### Unsubscribing

`pipe()` returns an unsubscribe function:

```typescript
const unsub = socket.pipe(messages, reducer);

// Later
unsub();
```

---

## 7. Auto-Reconnect

By default, the socket reconnects automatically when the connection drops. The delay doubles after each attempt (exponential backoff):

- Attempt 1: 1000ms delay
- Attempt 2: 2000ms delay
- Attempt 3: 4000ms delay
- Attempt 4: 8000ms delay
- ...up to `reconnectMaxDelay` (default: 30000ms)

When reconnection succeeds:

- `status` goes to `'open'`
- `connected` becomes `true`
- `reconnectCount` resets to `0`
- The delay resets to the initial value

Track reconnection in the UI:

```typescript
html`
  ${() => socket.status.value === 'reconnecting'
    ? html`<div class="banner">
        Reconnecting... (attempt ${socket.reconnectCount})
      </div>`
    : null
  }
`
```

### Disabling Reconnect

```typescript
const socket = ws.connect('wss://api.example.com/ws', {
  reconnect: false,
});
```

### Limiting Attempts

```typescript
const socket = ws.connect('wss://api.example.com/ws', {
  reconnectAttempts: 5, // give up after 5 tries
});
```

---

## 8. Closing the Connection

```typescript
socket.close();
```

An intentional close stops reconnecting. The status goes to `'closed'` and stays there. The user logs out. The component unmounts. The page no longer needs live data. Call `close()` and the connection ends.

With code and reason:

```typescript
socket.close(1000, 'User logged out');
```

---

## 9. Real Example: Chat Room

Two users. One room. Messages appear the moment they are sent. The connection status shows at the top. The input disables when the socket disconnects. Everything is reactive -- signals drive every piece of state.

```typescript
import { signal, html, ws, batch } from 'tina4js';

function chatRoom() {
  const messages = signal<{ user: string; text: string; time: string }[]>([]);
  const input = signal('');
  const username = signal('Anonymous');
  const socket = ws.connect('wss://api.example.com/chat');

  // Pipe incoming messages into the messages signal
  socket.pipe(messages, (msg, current) => {
    const m = msg as { type: string; user: string; text: string; time: string };
    if (m.type === 'chat') {
      return [...current, { user: m.user, text: m.text, time: m.time }];
    }
    return current;
  });

  // Send on enter
  const sendMessage = () => {
    const text = input.value.trim();
    if (!text || !socket.connected.value) return;

    socket.send({
      type: 'chat',
      user: username.value,
      text,
    });
    input.value = '';
  };

  return html`
    <div>
      <h1>Chat</h1>

      ${() => !socket.connected.value
        ? html`<p>Connecting...</p>`
        : null
      }

      <div style="height: 400px; overflow-y: auto; border: 1px solid #e5e7eb; padding: 1rem;">
        ${() => messages.value.map(msg => html`
          <div>
            <strong>${msg.user}</strong>
            <span style="color: #6b7280; font-size: 0.75rem">${msg.time}</span>
            <p>${msg.text}</p>
          </div>
        `)}
      </div>

      <form @submit=${(e: Event) => { e.preventDefault(); sendMessage(); }}>
        <input
          type="text"
          placeholder="Type a message..."
          .value=${input}
          @input=${(e: Event) => { input.value = (e.target as HTMLInputElement).value; }}
          ?disabled=${() => !socket.connected.value}
        />
        <button type="submit" ?disabled=${() => !socket.connected.value}>
          Send
        </button>
      </form>
    </div>
  `;
}
```

---

## 10. Real Example: Live Dashboard

A server streams metrics every second. Active users. Requests per second. Error rate. CPU usage. Alerts arrive when thresholds are exceeded. The dashboard updates without a single API poll -- the data pushes itself to the screen.

```typescript
import { signal, computed, html, ws } from 'tina4js';

function liveDashboard() {
  const metrics = signal({
    activeUsers: 0,
    requestsPerSecond: 0,
    errorRate: 0,
    cpuUsage: 0,
  });

  const alerts = signal<string[]>([]);

  const socket = ws.connect('wss://api.example.com/metrics');

  // Pipe metrics updates
  socket.pipe(metrics, (msg, current) => {
    const m = msg as { type: string; data: any };
    if (m.type === 'metrics') {
      return { ...current, ...m.data };
    }
    return current;
  });

  // Pipe alerts
  socket.pipe(alerts, (msg, current) => {
    const m = msg as { type: string; message: string };
    if (m.type === 'alert') {
      return [...current.slice(-9), m.message]; // keep last 10
    }
    return current;
  });

  const cpuColor = computed(() => {
    const cpu = metrics.value.cpuUsage;
    if (cpu > 80) return '#dc2626';
    if (cpu > 50) return '#f59e0b';
    return '#059669';
  });

  return html`
    <div>
      <h1>Live Dashboard</h1>
      <p>Status: ${socket.status}</p>

      <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem;">
        <div class="card">
          <h3>Active Users</h3>
          <p style="font-size: 2rem">${() => metrics.value.activeUsers}</p>
        </div>
        <div class="card">
          <h3>Requests/s</h3>
          <p style="font-size: 2rem">${() => metrics.value.requestsPerSecond}</p>
        </div>
        <div class="card">
          <h3>Error Rate</h3>
          <p style="font-size: 2rem">${() => metrics.value.errorRate}%</p>
        </div>
        <div class="card">
          <h3>CPU</h3>
          <p style="font-size: 2rem; color: ${cpuColor}">
            ${() => metrics.value.cpuUsage}%
          </p>
        </div>
      </div>

      <h2>Alerts</h2>
      <ul>
        ${() => alerts.value.map(alert => html`
          <li style="color: #dc2626">${alert}</li>
        `)}
      </ul>
    </div>
  `;
}
```

---

## Summary

| What | How |
|---|---|
| Connect | `ws.connect(url, options?)` |
| Status signal | `socket.status` -- `'connecting' \| 'open' \| 'closed' \| 'reconnecting'` |
| Connected signal | `socket.connected` -- boolean |
| Last message signal | `socket.lastMessage` |
| Error signal | `socket.error` |
| Reconnect count | `socket.reconnectCount` |
| Send data | `socket.send(data)` -- auto-stringify objects |
| Listen for events | `socket.on('message' \| 'open' \| 'close' \| 'error', handler)` |
| Pipe to signal | `socket.pipe(signal, (msg, current) => newValue)` |
| Close | `socket.close(code?, reason?)` -- stops reconnect |
| Auto-reconnect | On by default, exponential backoff |
