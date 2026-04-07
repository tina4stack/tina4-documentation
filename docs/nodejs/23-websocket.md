# Chapter 23: Real-time with WebSocket

## 1. The Refresh Button Problem

Your project management app needs live updates. Someone moves a card from "In Progress" to "Done." Everyone else on the team should see it. No page refresh. No polling. No waiting.

Traditional HTTP is request-response. The client asks. The server answers. The server cannot push data on its own. WebSocket breaks that wall. A persistent, bi-directional connection between browser and server. Either side sends messages at any time. The connection stays open until one side closes it.

Tina4 treats WebSocket the same way it treats routing. Define a WebSocket handler the same way you define an HTTP route. It runs on Node's built-in HTTP server -- no `ws` or `socket.io` required.

---

## 2. What WebSocket Is

HTTP works like this:

```
Client: "Give me /api/products"
Server: "Here are the products" (connection closes)
Client: "Give me /api/products" (new connection)
Server: "Here are the products" (connection closes)
```

WebSocket works like this:

```
Client: "I want to upgrade to WebSocket on /ws/chat"
Server: "Upgrade accepted. Connection open."
Client: "Hello everyone!"
Server: "Alice says: Hello everyone!"  (pushed to all clients)
Server: "Bob joined the chat"  (pushed to all clients, at any time)
Client: "Goodbye!"
Server: "Alice says: Goodbye!"
Client: (closes connection)
```

Key differences:

- **Persistent**: The connection stays open. No repeated handshakes.
- **Bi-directional**: The server pushes data without the client asking.
- **Low overhead**: After the initial handshake, messages are tiny. No HTTP headers per message.
- **Real-time**: Messages arrive within milliseconds.

---

## 3. Router.websocket() -- WebSocket as a Route

In Tina4, you define WebSocket handlers using `Router.websocket()`:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/echo", (connection, event, data) => {
    if (event === "message") {
        connection.send(`Echo: ${data}`);
    }
});
```

This is the simplest WebSocket handler: it receives a message and sends it back with "Echo: " prepended. The callback receives three arguments:

| Argument | Type | Description |
|---|---|---|
| `connection` | `WebSocketConnection` | The client connection object. Use it to send messages. |
| `event` | `"open" \| "message" \| "close"` | Which lifecycle event fired |
| `data` | `string` | The message text (only meaningful when `event === "message"`) |

### Starting the Server

WebSocket runs alongside your HTTP server:

```bash
tina4 serve
```

```
  Tina4 Node.js v3.10.3
  HTTP server running at http://0.0.0.0:7148
  WebSocket server running at ws://0.0.0.0:7148
  Press Ctrl+C to stop
```

Both HTTP and WebSocket share the same port. The server detects the protocol upgrade request and routes it to the correct handler.

---

## 4. Connection Events

Every WebSocket connection goes through three lifecycle events:

### Open

Fires when a client connects:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/notifications", (connection, event, data) => {
    if (event === "open") {
        console.log(`Client connected: ${connection.id}`);
        connection.send(JSON.stringify({
            type: "welcome",
            message: "Connected to notifications",
            connection_id: connection.id
        }));
    }
});
```

### Message

Fires when a client sends data:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/notifications", (connection, event, data) => {
    if (event === "open") {
        connection.send(JSON.stringify({
            type: "welcome",
            connection_id: connection.id
        }));
    }

    if (event === "message") {
        const message = JSON.parse(data);
        console.log(`Received from ${connection.id}: ${data}`);

        if (message.type === "ping") {
            connection.send(JSON.stringify({
                type: "pong",
                timestamp: new Date().toISOString()
            }));
        }
    }
});
```

### Close

Fires when a client disconnects:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/notifications", (connection, event, data) => {
    if (event === "open") {
        console.log(`Client connected: ${connection.id}`);
    }

    if (event === "message") {
        console.log(`Message from ${connection.id}: ${data}`);
    }

    if (event === "close") {
        console.log(`Client disconnected: ${connection.id}`);
        // Clean up: remove from tracking, notify others, etc.
    }
});
```

### A Complete Handler

Here is a handler that responds to all three events:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/chat", (connection, event, data) => {
    switch (event) {
        case "open":
            console.log(`[Chat] New connection: ${connection.id}`);
            connection.send(JSON.stringify({
                type: "system",
                message: "Welcome to the chat!",
                your_id: connection.id
            }));
            break;

        case "message":
            const message = JSON.parse(data);
            console.log(`[Chat] ${connection.id}: ${message.text ?? data}`);
            connection.send(JSON.stringify({
                type: "message",
                from: connection.id,
                text: message.text ?? data,
                timestamp: new Date().toISOString()
            }));
            break;

        case "close":
            console.log(`[Chat] Disconnected: ${connection.id}`);
            break;
    }
});
```

---

## 5. Sending to a Single Client

`connection.send()` sends a message to the specific client that triggered the event:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/private", (connection, event, data) => {
    if (event === "message") {
        const message = JSON.parse(data);
        const action = message.action ?? "";

        if (action === "get-time") {
            connection.send(JSON.stringify({
                type: "time",
                server_time: new Date().toISOString()
            }));
        }

        if (action === "get-status") {
            const memUsage = process.memoryUsage();
            connection.send(JSON.stringify({
                type: "status",
                uptime: Math.floor(process.uptime()),
                connections: 42,
                memory_mb: Math.round(memUsage.rss / 1024 / 1024 * 100) / 100
            }));
        }
    }
});
```

Only the client that sent the message receives the response. Other connected clients do not see it.

---

## 6. Broadcasting to All Clients

`connection.broadcast()` sends a message to every client connected to the same WebSocket path:

```typescript
Router.websocket("/ws/announcements", (connection, event, data) => {
    if (event === "open") {
        connection.broadcast(JSON.stringify({
            type: "system",
            message: "A new user joined",
            online_count: connection.connectionCount()
        }));
    }

    if (event === "message") {
        const message = JSON.parse(data);
        connection.broadcast(JSON.stringify({
            type: "announcement",
            from: connection.id,
            text: message.text ?? "",
            timestamp: new Date().toISOString()
        }));
    }

    if (event === "close") {
        connection.broadcast(JSON.stringify({
            type: "system",
            message: "A user left",
            online_count: connection.connectionCount()
        }));
    }
});
```

When one client sends a message, every client connected to `/ws/announcements` receives it. This is the foundation for chat rooms, live dashboards, and collaborative editing.

### Broadcast Excluding Sender

Sometimes you want to send to everyone except the client that triggered the event:

```typescript
if (event === "message") {
    const message = JSON.parse(data);

    // Send to sender (confirmation)
    connection.send(JSON.stringify({
        type: "sent",
        text: message.text
    }));

    // Send to everyone else
    connection.broadcast(JSON.stringify({
        type: "message",
        from: message.username ?? "Anonymous",
        text: message.text,
        timestamp: new Date().toISOString()
    }), { excludeSelf: true });
}
```

The `{ excludeSelf: true }` option on `broadcast()` excludes the sender. The sender gets a "sent" confirmation. Everyone else gets the "message".

### Sending JSON

Use `connection.sendJson()` to send an object as a JSON string without calling `JSON.stringify()` yourself:

```typescript
Router.websocket("/ws/status", (connection, event, data) => {
    if (event === "open") {
        connection.sendJson({
            type: "welcome",
            connection_id: connection.id
        });
    }

    if (event === "message") {
        connection.sendJson({
            type: "ack",
            received: data
        });
    }
});
```

`sendJson()` serialises the data to JSON for you. It is equivalent to `connection.send(JSON.stringify(data))` but saves you the call.

### Closing a Connection

Use `connection.close()` to close the connection from the server side:

```typescript
Router.websocket("/ws/secure", (connection, event, data) => {
    if (event === "open") {
        const token = connection.params.token;
        if (!token || !validToken(token)) {
            connection.sendJson({ error: "Unauthorized" });
            connection.close();
            return;
        }

        connection.sendJson({ type: "welcome" });
    }
});
```

### Connection Methods Summary

| Method | Description |
|--------|-------------|
| `connection.send(message)` | Send a string message to this connection only |
| `connection.sendJson(data)` | Send an object as JSON to this connection only |
| `connection.broadcast(message)` | Send to all connections on the same path |
| `connection.broadcast(message, { excludeSelf: true })` | Send to all except this connection |
| `connection.close()` | Close this connection from the server side |
| `connection.id` | Unique identifier for this connection |
| `connection.params` | Path parameters extracted from the URL |
| `connection.connectionCount()` | Number of active connections on this path |

---

## 7. Path-Scoped Isolation

Different WebSocket paths are isolated. Clients connected to `/ws/chat/room-1` do not see messages from `/ws/chat/room-2`:

```typescript
Router.websocket("/ws/chat/{room}", (connection, event, data) => {
    const room = connection.params.room;

    if (event === "open") {
        console.log(`[Room ${room}] New connection: ${connection.id}`);
        connection.broadcast(JSON.stringify({
            type: "system",
            message: `Someone joined room ${room}`,
            room,
            online: connection.connectionCount()
        }));
    }

    if (event === "message") {
        const message = JSON.parse(data);
        connection.broadcast(JSON.stringify({
            type: "message",
            room,
            from: message.username ?? "Anonymous",
            text: message.text ?? "",
            timestamp: new Date().toISOString()
        }));
    }

    if (event === "close") {
        connection.broadcast(JSON.stringify({
            type: "system",
            message: `Someone left room ${room}`,
            room,
            online: connection.connectionCount()
        }));
    }
});
```

Connect to different rooms:

```
ws://localhost:7148/ws/chat/general    -- general chat
ws://localhost:7148/ws/chat/random     -- random chat
ws://localhost:7148/ws/chat/dev-team   -- dev team chat
```

Broadcasting in `/ws/chat/general` reaches only clients connected to `/ws/chat/general`. The `dev-team` and `random` rooms are separate.

Chat rooms. Project-specific notifications. Per-user channels. No extra configuration. The URL path is the isolation boundary.

Path parameters use `{name}` curly-brace syntax, not `:name` colon syntax. Both `connection.params.room` and `connection.params["room"]` work.

---

## 8. Building a Live Chat

Here is a complete chat application with usernames, typing indicators, and online counts:

### WebSocket Handler

Create `src/routes/chat-ws.ts`:

```typescript
import { Router } from "tina4-nodejs";

const chatUsers: Record<string, { id: string; username: string; room: string; joinedAt: string }> = {};

Router.websocket("/ws/livechat/{room}", (connection, event, data) => {
    const room = connection.params.room;

    if (event === "open") {
        chatUsers[connection.id] = {
            id: connection.id,
            username: "Anonymous",
            room,
            joinedAt: new Date().toISOString()
        };

        connection.send(JSON.stringify({
            type: "welcome",
            message: `Connected to room: ${room}`,
            your_id: connection.id,
            online: connection.connectionCount()
        }));
    }

    if (event === "message") {
        const message = JSON.parse(data);
        const type = message.type ?? "message";

        if (type === "set-username") {
            const oldName = chatUsers[connection.id].username;
            chatUsers[connection.id].username = message.username;
            connection.broadcast(JSON.stringify({
                type: "system",
                message: `${oldName} is now known as ${message.username}`
            }));
        }

        if (type === "message") {
            const username = chatUsers[connection.id].username;
            connection.broadcast(JSON.stringify({
                type: "message",
                from: username,
                from_id: connection.id,
                text: message.text ?? "",
                timestamp: new Date().toISOString()
            }));
        }

        if (type === "typing") {
            const username = chatUsers[connection.id].username;
            connection.broadcast(JSON.stringify({
                type: "typing",
                username
            }), { excludeSelf: true });
        }
    }

    if (event === "close") {
        const username = chatUsers[connection.id]?.username ?? "Unknown";
        delete chatUsers[connection.id];

        connection.broadcast(JSON.stringify({
            type: "system",
            message: `${username} left the chat`,
            online: connection.connectionCount()
        }));
    }
});
```

---

## 9. Live Notifications

WebSocket is built for pushing notifications to users in real time:

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/notifications/{userId}", (connection, event, data) => {
    const userId = connection.params.userId;

    if (event === "open") {
        console.log(`[Notifications] User ${userId} connected`);
        connection.send(JSON.stringify({
            type: "connected",
            message: "Listening for notifications"
        }));
    }

    if (event === "message") {
        const message = JSON.parse(data);
        if (message.type === "mark-read") {
            console.log(`[Notifications] User ${userId} read notification ${message.id}`);
        }
    }
});

Router.post("/api/orders/{orderId}/ship", async (req, res) => {
    const orderId = req.params.orderId;
    const userId = req.body.user_id ?? 0;

    // Update order status in database...

    // Send real-time notification via WebSocket
    Router.pushToWebSocket(`/ws/notifications/${userId}`, JSON.stringify({
        type: "notification",
        title: "Order Shipped",
        message: `Your order #${orderId} has been shipped!`,
        action_url: `/orders/${orderId}`,
        timestamp: new Date().toISOString()
    }));

    return res.status(201).json({ message: "Order shipped, user notified" });
});
```

`Router.pushToWebSocket()` lets your HTTP handlers send messages to WebSocket clients. This bridges the gap between traditional request-response endpoints and real-time notifications.

### Use Cases

- **Dashboard updates** -- New orders, user signups, system alerts
- **Notification feeds** -- Task assignments, comments, mentions
- **Live data** -- Stock tickers, sensor readings, log streams
- **Progress tracking** -- File upload progress, background job status

### Scoped Notifications

Path parameters scope the broadcast. Only clients connected to a specific path receive the message:

```typescript
// Only clients connected to /ws/project/42 receive this
Router.pushToWebSocket("/ws/project/42", JSON.stringify({
    type: "task_completed",
    task: "Design review"
}));
```

---

## 10. Connecting from JavaScript

Tina4 provides `frond.js`, a built-in JavaScript helper library that includes WebSocket support:

### Basic Connection

```html
<script src="/js/frond.js"></script>
<script>
    const ws = frond.ws("/ws/chat/general");

    ws.on("open", function () {
        console.log("Connected to chat");
    });

    ws.on("message", function (data) {
        const message = JSON.parse(data);
        console.log("Received:", message);

        if (message.type === "message") {
            addMessageToUI(message.from, message.text, message.timestamp);
        }

        if (message.type === "system") {
            addSystemMessage(message.message);
        }
    });

    ws.on("close", function () {
        console.log("Disconnected from chat");
    });

    function sendMessage(text) {
        ws.send(JSON.stringify({
            type: "message",
            text: text
        }));
    }

    function setUsername(name) {
        ws.send(JSON.stringify({
            type: "set-username",
            username: name
        }));
    }
</script>
```

### Auto-Reconnect

`frond.js` reconnects when the connection drops:

```javascript
const ws = frond.ws("/ws/notifications/42", {
    reconnect: true,           // Enable auto-reconnect (default: true)
    reconnectInterval: 3000,   // Retry every 3 seconds
    maxReconnectAttempts: 10   // Give up after 10 attempts
});

ws.on("reconnect", function (attempt) {
    console.log("Reconnecting... attempt " + attempt);
});

ws.on("reconnect_failed", function () {
    console.log("Failed to reconnect after maximum attempts");
});
```

### Using Native WebSocket

If you prefer not to use `frond.js`, the native WebSocket API works too:

```javascript
const ws = new WebSocket("ws://localhost:7148/ws/chat/general");

ws.onopen = function () {
    console.log("Connected");
    ws.send(JSON.stringify({ type: "set-username", username: "Alice" }));
};

ws.onmessage = function (event) {
    const message = JSON.parse(event.data);
    console.log("Received:", message);
};

ws.onclose = function () {
    console.log("Disconnected");
};

ws.onerror = function (error) {
    console.error("WebSocket error:", error);
};
```

`frond.js` gives you auto-reconnect, message buffering during reconnection, and a cleaner event API. Native WebSocket does not.

### Manual Auto-Reconnect with Native WebSocket

If you use the native API and want reconnection, build it yourself:

```javascript
function connectWebSocket(path) {
    const ws = new WebSocket(`ws://${location.host}${path}`);

    ws.addEventListener("close", () => {
        console.log("Disconnected. Reconnecting in 3s...");
        setTimeout(() => connectWebSocket(path), 3000);
    });

    ws.addEventListener("message", (event) => {
        const data = JSON.parse(event.data);
        console.log("Received:", data);
    });

    return ws;
}

const ws = connectWebSocket("/ws/chat/general");
```

This reconnects on every close. It does not limit retries or buffer messages sent during the reconnection window. For production use, `frond.js` handles these edge cases for you.

---

## 11. A Complete Chat Page

Here is a full chat page using templates and WebSocket:

Create `src/templates/chat.html`:

```html
{% extends "base.html" %}

{% block title %}Chat - {{ room }}{% endblock %}

{% block content %}
    <h1>Chat Room: {{ room }}</h1>
    <p id="status">Connecting...</p>
    <p id="online">Online: 0</p>

    <div id="messages" style="border: 1px solid #ddd; height: 400px; overflow-y: scroll; padding: 12px; margin-bottom: 12px; border-radius: 8px;">
    </div>

    <div id="typing" style="height: 20px; color: #888; font-style: italic; margin-bottom: 4px;"></div>

    <form id="chat-form" style="display: flex; gap: 8px;">
        <input type="text" id="message-input" placeholder="Type a message..."
               style="flex: 1; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
        <button type="submit" style="padding: 8px 16px; background: #333; color: white; border: none; border-radius: 4px; cursor: pointer;">
            Send
        </button>
    </form>

    <script src="/js/frond.js"></script>
    <script>
        const room = "{{ room }}";
        const ws = frond.ws("/ws/livechat/" + room);
        const messagesDiv = document.getElementById("messages");
        const statusEl = document.getElementById("status");
        const onlineEl = document.getElementById("online");
        const typingEl = document.getElementById("typing");

        let username = prompt("Enter your username:") || "Anonymous";

        ws.on("open", function () {
            statusEl.textContent = "Connected";
            ws.send(JSON.stringify({ type: "set-username", username: username }));
        });

        ws.on("message", function (data) {
            const msg = JSON.parse(data);

            if (msg.type === "message") {
                const div = document.createElement("div");
                div.style.marginBottom = "8px";
                div.innerHTML = "<strong>" + msg.from + ":</strong> " + msg.text;
                messagesDiv.appendChild(div);
                messagesDiv.scrollTop = messagesDiv.scrollHeight;
            }

            if (msg.type === "system") {
                const div = document.createElement("div");
                div.style.cssText = "color: #888; font-style: italic; margin-bottom: 8px;";
                div.textContent = msg.message;
                messagesDiv.appendChild(div);
                messagesDiv.scrollTop = messagesDiv.scrollHeight;
            }

            if (msg.type === "typing") {
                typingEl.textContent = msg.username + " is typing...";
                setTimeout(function () { typingEl.textContent = ""; }, 2000);
            }

            if (msg.online !== undefined) {
                onlineEl.textContent = "Online: " + msg.online;
            }
        });

        ws.on("close", function () {
            statusEl.textContent = "Disconnected. Reconnecting...";
        });

        document.getElementById("chat-form").addEventListener("submit", function (e) {
            e.preventDefault();
            const input = document.getElementById("message-input");
            if (input.value.trim()) {
                ws.send(JSON.stringify({ type: "message", text: input.value }));
                input.value = "";
            }
        });

        document.getElementById("message-input").addEventListener("input", function () {
            ws.send(JSON.stringify({ type: "typing" }));
        });
    </script>
{% endblock %}
```

Create the route to serve the page:

```typescript
Router.get("/chat/{room}", async (req, res) => {
    const room = req.params.room;
    return res.html("chat.html", { room });
});
```

Visit `http://localhost:7148/chat/general` in two browser tabs. Type in one tab and watch the message appear in the other.

---

## 12. Exercise: Build a Real-Time Chat Room

Build a WebSocket chat room with the following features:

### Requirements

1. WebSocket endpoint at `/ws/room/{roomName}` that handles:
   - `open`: Send welcome message with connection count
   - `message` with type `set-name`: Set the user's display name
   - `message` with type `chat`: Broadcast the message to all clients with the sender's name
   - `close`: Broadcast that the user left

2. HTTP endpoint at `GET /room/{roomName}` that serves an HTML chat page

3. The chat page should:
   - Prompt for a username on load
   - Display messages in real time
   - Show system messages (join/leave) in a different style
   - Show the count of online users

### Test by:

1. Open `http://localhost:7148/room/test` in two browser tabs
2. Set different usernames in each
3. Send messages from both tabs and verify they appear in both
4. Close one tab and verify the "user left" message appears in the other

---

## 13. Solution

Create `src/routes/chat-room.ts`:

```typescript
import { Router } from "tina4-nodejs";

const roomUsers: Record<string, string> = {};

Router.websocket("/ws/room/{roomName}", (connection, event, data) => {
    const room = connection.params.roomName;
    const key = `${room}:${connection.id}`;

    if (event === "open") {
        roomUsers[key] = "Anonymous";

        connection.send(JSON.stringify({
            type: "system",
            message: `Welcome to room: ${room}. Set your name with: `
                + '{"type": "set-name", "name": "YourName"}',
            online: connection.connectionCount()
        }));

        connection.broadcast(JSON.stringify({
            type: "system",
            message: "A new user joined",
            online: connection.connectionCount()
        }), { excludeSelf: true });
    }

    if (event === "message") {
        const msg = JSON.parse(data);
        const msgType = msg.type ?? "chat";

        if (msgType === "set-name") {
            const oldName = roomUsers[key] ?? "Anonymous";
            const newName = msg.name ?? "Anonymous";
            roomUsers[key] = newName;

            connection.broadcast(JSON.stringify({
                type: "system",
                message: `${oldName} changed their name to ${newName}`
            }));
        }

        if (msgType === "chat") {
            const username = roomUsers[key] ?? "Anonymous";

            connection.broadcast(JSON.stringify({
                type: "chat",
                from: username,
                text: msg.text ?? "",
                timestamp: new Date().toTimeString().substring(0, 8)
            }));
        }
    }

    if (event === "close") {
        const username = roomUsers[key] ?? "Anonymous";
        delete roomUsers[key];

        connection.broadcast(JSON.stringify({
            type: "system",
            message: `${username} left the room`,
            online: connection.connectionCount()
        }));
    }
});

Router.get("/room/{roomName}", async (req, res) => {
    const room = req.params.roomName;
    return res.html("room.html", { room });
});
```

Create `src/templates/room.html`:

```html
{% extends "base.html" %}

{% block title %}Room: {{ room }}{% endblock %}

{% block content %}
    <h1>Room: {{ room }}</h1>
    <p id="online" style="color: #666;">Online: 0</p>

    <div id="messages" style="border: 1px solid #ddd; height: 400px; overflow-y: auto; padding: 12px; margin-bottom: 12px; border-radius: 8px; background: #fafafa;">
    </div>

    <form id="form" style="display: flex; gap: 8px;">
        <input type="text" id="input" placeholder="Type a message..."
               style="flex: 1; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px;">
        <button type="submit"
                style="padding: 10px 20px; background: #1a1a2e; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px;">
            Send
        </button>
    </form>

    <script src="/js/frond.js"></script>
    <script>
        const room = "{{ room }}";
        const username = prompt("Choose a username:") || "Anonymous";
        const ws = frond.ws("/ws/room/" + room);
        const msgs = document.getElementById("messages");

        ws.on("open", function () {
            ws.send(JSON.stringify({ type: "set-name", name: username }));
        });

        ws.on("message", function (raw) {
            const msg = JSON.parse(raw);
            const div = document.createElement("div");
            div.style.marginBottom = "8px";

            if (msg.type === "chat") {
                div.innerHTML = "<strong>" + msg.from + "</strong> <span style='color:#999;font-size:12px;'>" + msg.timestamp + "</span><br>" + msg.text;
            } else if (msg.type === "system") {
                div.style.color = "#888";
                div.style.fontStyle = "italic";
                div.textContent = msg.message;
            }

            msgs.appendChild(div);
            msgs.scrollTop = msgs.scrollHeight;

            if (msg.online !== undefined) {
                document.getElementById("online").textContent = "Online: " + msg.online;
            }
        });

        document.getElementById("form").addEventListener("submit", function (e) {
            e.preventDefault();
            const input = document.getElementById("input");
            if (input.value.trim()) {
                ws.send(JSON.stringify({ type: "chat", text: input.value }));
                input.value = "";
            }
        });
    </script>
{% endblock %}
```

Open `http://localhost:7148/room/test` in two browser tabs. Set different usernames. Send messages from one tab and watch them appear in both. Close one tab and verify the "left the room" message appears.

---

## 14. Scaling with a Backplane

When you run a single server instance, `broadcast()` reaches every connected client. But in production you often run multiple instances behind a load balancer. Each instance only knows about its own connections. A message broadcast on instance A never reaches clients connected to instance B.

A backplane solves this. It relays WebSocket messages across all instances using a shared pub/sub channel. Tina4 supports Redis as a backplane out of the box.

### Configuration

Set two environment variables in your `.env`:

```bash
TINA4_WS_BACKPLANE=redis
TINA4_WS_BACKPLANE_URL=redis://localhost:6379
```

When `TINA4_WS_BACKPLANE` is set, every `broadcast()` call publishes the message to Redis. Every instance subscribes to the same channel and forwards the message to its local connections. No code changes required -- your existing WebSocket routes work as before.

### Requirements

The Redis backplane requires a Redis client package as an optional dependency:

```bash
npm install ioredis
```

If `TINA4_WS_BACKPLANE` is not set (the default), Tina4 broadcasts only to local connections. This is fine for single-instance deployments.

---

## 15. Gotchas

### 1. WebSocket Needs a Persistent Server

**Problem:** WebSocket connections drop right away or do not work at all.

**Cause:** You are running behind a serverless platform or a proxy that closes idle connections. Traditional request-response servers do not support persistent connections. Each request is handled and the connection is closed.

**Fix:** Use `tina4 serve` which runs Tina4's built-in HTTP server that handles both HTTP and WebSocket. For production, you can use Nginx as a reverse proxy, but it must be configured for WebSocket proxying with `proxy_set_header Upgrade $http_upgrade` and `proxy_set_header Connection "upgrade"`.

### 2. Messages Are Strings, Not Objects

**Problem:** `data` in the message handler is a string, not a JavaScript object.

**Cause:** WebSocket transmits raw strings. If the client sends JSON, you receive the JSON string, not a parsed object.

**Fix:** Always `JSON.parse(data)` when you expect JSON messages. Always `JSON.stringify()` when you send structured data. WebSocket does not know about content types -- it is just bytes on a wire.

### 3. Connection Count Is Per-Path

**Problem:** `connection.connectionCount()` returns a lower number than expected.

**Cause:** Connection count is scoped to the WebSocket path. Clients on `/ws/chat/room-1` are counted separately from `/ws/chat/room-2`.

**Fix:** This is by design. Each path is an isolated group. If you need a global connection count across all paths, maintain a counter in a shared variable or use a module-level map.

### 4. Broadcasting Does Not Scale Across Servers

**Problem:** Users connected to different server instances do not see each other's messages.

**Cause:** `connection.broadcast()` sends only to clients connected to the same server process. With multiple server instances behind a load balancer, each instance has its own set of connections.

**Fix:** Use a pub/sub backend like Redis to relay messages across server instances. Each server subscribes to a Redis channel, and broadcast messages are published to Redis so all servers receive them. See section 14 for configuration.

### 5. Large Messages Cause Disconnects

**Problem:** The connection drops when sending a large message.

**Cause:** WebSocket servers have a maximum message size. The default is usually around 1MB. If your message exceeds this, the server closes the connection.

**Fix:** Keep messages small. Under 64KB is a good target. For large data transfers, use HTTP endpoints instead of WebSocket. WebSocket is designed for small, frequent messages -- not bulk data transfer.

### 6. Memory Leak from Tracking Connected Users

**Problem:** The server's memory usage grows over time and the process crashes.

**Cause:** You store user data in an object (like `chatUsers`) but do not clean it up when users disconnect. If the `close` event handler does not remove the user from the object, the object grows without limit.

**Fix:** Always clean up in the `close` handler. Remove disconnected users from tracking objects: `delete chatUsers[connection.id]`. Test by connecting and disconnecting many times to verify memory stays stable.

### 7. No Authentication on WebSocket Connect

**Problem:** Anyone can connect to your WebSocket endpoint and see all messages.

**Cause:** The WebSocket upgrade request does not carry your JWT token in the `Authorization` header. Browsers do not support custom headers on WebSocket connections.

**Fix:** Pass the token as a query parameter: `ws://localhost:7148/ws/chat?token=eyJ...`. In your `open` handler, validate the token and disconnect if invalid. Use a short-lived token for WebSocket connections. You can also authenticate via an HTTP endpoint first, store the session, and check the session cookie during the WebSocket upgrade.

### 8. Route Params Use `{id}` Not `:id`

**Problem:** Your WebSocket path parameters do not resolve. `connection.params` is empty.

**Cause:** You used Express-style `:param` colon syntax instead of Tina4's `{param}` curly-brace syntax.

**Fix:** WebSocket path parameters follow the same `{param}` syntax as HTTP routes. Write `/ws/chat/{room}`, not `/ws/chat/:room`. Both `connection.params.room` and `connection.params["room"]` work.
