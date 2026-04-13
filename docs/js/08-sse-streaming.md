# Chapter 8: SSE / NDJSON Streaming

## Streaming Without WebSocket

An AI chatbot types back one token at a time. A dashboard counter ticks up as orders arrive. A notification feed shows events the moment they happen. The data flows from server to client, but you don't need the complexity of WebSocket for it.

Server-Sent Events (SSE) is the browser's built-in streaming protocol. One-directional: server pushes, client listens. It reconnects automatically. It works over HTTP/2. It's simpler than WebSocket for every case where you don't need to send data back.

NDJSON (Newline-Delimited JSON) is the same idea over a regular fetch response. One JSON object per line, streamed as the server generates them. This is how most AI APIs stream tokens — and it supports POST requests and custom headers, which SSE's EventSource does not.

tina4-js wraps both in a single module. One function call opens the stream. Six reactive signals track the state. A pipe function accumulates messages into your signals with a reducer. Auto-reconnect handles dropped connections.

---

## 1. The SSE Client

The tina4-js SSE client provides:

1. **Dual mode** — native EventSource for SSE, fetch+ReadableStream for NDJSON
2. **Reactive signals** — `status`, `connected`, `lastMessage`, `lastEvent`, `error`, `reconnectCount`
3. **Auto-reconnect** — exponential backoff, configurable attempts
4. **Signal piping** — stream messages into signals with a reducer

```typescript
import { sse } from 'tina4js';
```

---

## 2. EventSource Mode (Default)

```typescript
const stream = sse.connect('/api/events');
```

One line. The browser opens an EventSource connection. Messages arrive as the server sends them.

```typescript
import { sse, effect } from 'tina4js';

const stream = sse.connect('/api/events');

effect(() => {
  console.log('Status:', stream.status.value);
});

effect(() => {
  if (stream.lastMessage.value) {
    console.log('Received:', stream.lastMessage.value);
  }
});
```

---

## 3. Fetch Mode (NDJSON)

EventSource only supports GET requests with no custom headers. For POST requests, Bearer tokens, or NDJSON streaming, use fetch mode:

```typescript
const stream = sse.connect('/api/chat', {
  mode: 'fetch',
  method: 'POST',
  headers: { 'Authorization': 'Bearer eyJ...' },
  body: { prompt: 'Explain signals in tina4-js' },
});
```

The client reads the response body as a stream, splits on newlines, and parses each line as JSON. Every parsed object becomes a message.

---

## 4. Options

```typescript
const stream = sse.connect('/api/events', {
  mode: 'eventsource',    // 'eventsource' (default) or 'fetch'
  method: 'GET',           // HTTP method (fetch mode only)
  headers: {},             // Custom headers (fetch mode only)
  body: undefined,         // Request body (fetch mode only, auto-stringified)
  reconnect: true,         // Auto-reconnect on disconnect
  reconnectDelay: 1000,    // Initial delay (ms)
  reconnectMaxDelay: 30000,// Max delay after backoff (ms)
  reconnectAttempts: Infinity, // Max attempts
  events: [],              // Named SSE events (eventsource mode only)
  json: true,              // Auto-parse JSON (default: true)
});
```

| Option | Default | Description |
|--------|---------|-------------|
| `mode` | `'eventsource'` | Transport: native EventSource or fetch+ReadableStream |
| `method` | `'GET'` | HTTP method (fetch mode only) |
| `headers` | `{}` | Custom headers (fetch mode only) |
| `body` | `undefined` | Request body (fetch mode, auto JSON.stringify) |
| `reconnect` | `true` | Auto-reconnect on disconnect |
| `reconnectDelay` | `1000` | Initial reconnect delay in ms |
| `reconnectMaxDelay` | `30000` | Max delay for exponential backoff |
| `reconnectAttempts` | `Infinity` | Max reconnect attempts |
| `events` | `[]` | Named SSE events to listen for |
| `json` | `true` | Auto-parse messages as JSON |

---

## 5. Reactive Signals

Every stream exposes six reactive signals:

```typescript
const stream = sse.connect('/api/events');

stream.status         // Signal<'connecting' | 'open' | 'closed' | 'reconnecting'>
stream.connected      // Signal<boolean>
stream.lastMessage    // Signal<unknown>  — last parsed message
stream.lastEvent      // Signal<string | null>  — SSE event name or null
stream.error          // Signal<Event | Error | null>
stream.reconnectCount // Signal<number>
```

Use them in effects, computed values, or html templates:

```typescript
effect(() => {
  if (stream.connected.value) {
    console.log('Stream is live');
  }
});
```

---

## 6. Event Handlers

Register listeners for stream events. Every handler returns an unsubscribe function:

```typescript
const unsub = stream.on('message', (data, event?) => {
  console.log('Data:', data);
  console.log('Event name:', event); // SSE event name or undefined
});

stream.on('open', () => console.log('Connected'));
stream.on('close', () => console.log('Disconnected'));
stream.on('error', (err) => console.error('Error:', err));

// Stop listening
unsub();
```

---

## 7. Named Events (EventSource Mode)

SSE supports named events. By default, EventSource only listens for unnamed `message` events. Pass event names in the options to listen for specific types:

```typescript
const stream = sse.connect('/api/feed', {
  events: ['user_joined', 'message', 'user_left'],
});

stream.on('message', (data, event) => {
  switch (event) {
    case 'user_joined':
      console.log(`${data.name} joined`);
      break;
    case 'message':
      console.log(`${data.author}: ${data.text}`);
      break;
    case 'user_left':
      console.log(`${data.name} left`);
      break;
  }
});

// The lastEvent signal tracks the most recent event name
effect(() => console.log('Last event type:', stream.lastEvent.value));
```

---

## 8. Pipe to Signal

The pipe pattern streams messages into a signal through a reducer. This is the same pattern as the WebSocket module:

```typescript
import { sse, signal } from 'tina4js';

const messages = signal([]);

const stream = sse.connect('/api/notifications');
stream.pipe(messages, (msg, current) => [...current, msg]);

// messages.value grows as notifications arrive
effect(() => {
  console.log(`${messages.value.length} notifications`);
});
```

Pipe returns an unsubscribe function:

```typescript
const unsub = stream.pipe(messages, (msg, current) => [...current, msg]);

// Stop piping
unsub();
```

---

## 9. Auto-Reconnect

In EventSource mode, the browser handles reconnection natively. If the connection is fully closed, tina4-js schedules manual reconnection with exponential backoff.

In fetch mode, tina4-js handles all reconnection:

```typescript
const stream = sse.connect('/api/stream', {
  mode: 'fetch',
  reconnect: true,
  reconnectDelay: 1000,       // Start at 1s
  reconnectMaxDelay: 30000,   // Cap at 30s
  reconnectAttempts: 10,      // Give up after 10 tries
});

effect(() => {
  if (stream.status.value === 'reconnecting') {
    console.log(`Reconnect attempt ${stream.reconnectCount.value}`);
  }
});
```

---

## 10. Closing

```typescript
stream.close();
```

This stops the connection and prevents reconnection. In EventSource mode it calls `source.close()`. In fetch mode it aborts the fetch request.

---

## 11. SSE vs WebSocket

| | SSE | WebSocket |
|---|---|---|
| Direction | Server → Client | Bidirectional |
| Protocol | HTTP | WS/WSS |
| Reconnect | Built-in (EventSource) | Manual (tina4-js handles it) |
| Headers | No (EventSource) / Yes (fetch mode) | Subprotocols only |
| POST body | No (EventSource) / Yes (fetch mode) | N/A |
| Binary data | No | Yes |
| HTTP/2 multiplexing | Yes | No |
| Use case | Notifications, feeds, AI streaming | Chat, gaming, live collaboration |

**Rule of thumb:** If the client only needs to receive, use SSE. If the client needs to send too, use WebSocket.

---

## 12. Real-World Example: AI Chat Streaming

```typescript
import { sse, signal, html } from 'tina4js';

const messages = signal([]);
const input = signal('');
const streaming = signal(false);

async function sendMessage() {
  const prompt = input.value.trim();
  if (!prompt) return;

  // Add user message
  messages.value = [...messages.value, { role: 'user', text: prompt }];
  input.value = '';

  // Add empty assistant message
  messages.value = [...messages.value, { role: 'assistant', text: '' }];
  streaming.value = true;

  // Stream tokens
  const stream = sse.connect('/api/chat', {
    mode: 'fetch',
    method: 'POST',
    headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` },
    body: { prompt },
  });

  stream.on('message', (data) => {
    const token = data.token || data;
    const msgs = [...messages.value];
    const last = msgs[msgs.length - 1];
    msgs[msgs.length - 1] = { ...last, text: last.text + token };
    messages.value = msgs;
  });

  stream.on('close', () => {
    streaming.value = false;
  });
}

const view = html`
  <div class="chat">
    ${() => messages.value.map(m => html`
      <div class="message ${m.role}">
        <strong>${m.role}:</strong> ${m.text}
      </div>
    `)}
    <div class="input-bar">
      <input
        type="text"
        .value=${input}
        @input=${(e) => { input.value = e.target.value; }}
        @keydown=${(e) => { if (e.key === 'Enter') sendMessage(); }}
        ?disabled=${streaming}
      />
      <button @click=${sendMessage} ?disabled=${streaming}>Send</button>
    </div>
  </div>
`;
```

---

## 13. Real-World Example: Live Notification Feed

```typescript
import { sse, signal, html } from 'tina4js';

const notifications = signal([]);

const stream = sse.connect('/api/notifications', {
  events: ['info', 'warning', 'error'],
});

stream.pipe(notifications, (msg, current) => {
  return [{ ...msg, event: stream.lastEvent.value, time: new Date() }, ...current].slice(0, 50);
});

const view = html`
  <div class="feed">
    <h2>Notifications ${() => stream.connected.value ? '(live)' : '(disconnected)'}</h2>
    ${() => notifications.value.map(n => html`
      <div class="notification ${n.event}">
        <span class="badge">${n.event}</span>
        ${n.message}
        <small>${n.time.toLocaleTimeString()}</small>
      </div>
    `)}
  </div>
`;
```

---

## Bundle Size

| Module | Raw | Gzipped |
|--------|-----|---------|
| SSE | 3.42 KB | 1.30 KB |

Import only what you need:

```typescript
import { sse } from 'tina4js/sse';  // 1.30 KB gzip
```

---

## Summary

| Task | Code |
|------|------|
| Connect (EventSource) | `sse.connect('/events')` |
| Connect (NDJSON/POST) | `sse.connect('/api', { mode: 'fetch', method: 'POST', body: {...} })` |
| Read status | `stream.status.value` |
| Listen for messages | `stream.on('message', (data, event?) => { ... })` |
| Named events | `sse.connect(url, { events: ['update', 'delete'] })` |
| Pipe to signal | `stream.pipe(signal, (msg, current) => [...current, msg])` |
| Close | `stream.close()` |
