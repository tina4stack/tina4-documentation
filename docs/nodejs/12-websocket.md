# Chapter 12: Real-time with WebSocket

## 1. The Refresh Button Problem

Your project management app needs live updates. Someone moves a card from "In Progress" to "Done." Everyone else should see it. Now. Not after a refresh.

WebSocket establishes a persistent, bi-directional connection between the browser and the server. Data flows both ways. No polling. No refresh.

Tina4 treats WebSocket the same way it treats routing. Define a WebSocket handler the same way you define an HTTP route. It runs on Node's built-in HTTP server -- no `ws` or `socket.io` required.

---

## 2. What WebSocket Is

HTTP is a conversation that ends. Request. Response. Connection closes. WebSocket is an open line. Persistent. Bi-directional. Low overhead. Real-time.

---

## 3. Router.websocket() -- WebSocket as a Route

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/echo", (connection, event, data) => {
    if (event === "message") {
        connection.send(`Echo: ${data}`);
    }
});
```

```bash
tina4 serve
```

```
  Tina4 Node.js v3.0.0
  HTTP server running at http://0.0.0.0:7148
  WebSocket server running at ws://0.0.0.0:7148
```

The callback receives three arguments:

| Argument | Type | Description |
|---|---|---|
| `connection` | `WebSocketConnection` | The client connection object |
| `event` | `"open" \| "message" \| "close"` | Which lifecycle event fired |
| `data` | `string` | The message text (only meaningful when `event === "message"`) |

---

## 4. Connection Events

Every WebSocket route receives exactly three events: `"open"`, `"message"`, and `"close"`.

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
            connection.broadcast(JSON.stringify({
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

## 5. The Connection Object

The `connection` object provides three methods:

| Method | What it does |
|---|---|
| `connection.send(message)` | Send a message to this client only |
| `connection.broadcast(message)` | Send a message to all clients on the same path |
| `connection.close()` | Disconnect this client |

```typescript
// Send to the current client
connection.send(JSON.stringify({ type: "pong", timestamp: new Date().toISOString() }));

// Send to everyone on this path
connection.broadcast(JSON.stringify({ type: "announcement", text: "Server restarting" }));

// Kick a client
connection.close();
```

---

## 6. Broadcasting to All Clients

Broadcast sends a message to every connection on the same WebSocket path. It is path-scoped: clients on `/ws/chat/general` will never receive broadcasts from `/ws/chat/dev-team`.

```typescript
Router.websocket("/ws/announcements", (connection, event, data) => {
    if (event === "open") {
        connection.broadcast(JSON.stringify({
            type: "system",
            message: "A new user joined"
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
            message: "A user left"
        }));
    }
});
```

---

## 7. Path Parameters and Scoped Isolation

Route parameters use `{param}` syntax in the path. Access them via `connection.params`.

```typescript
Router.websocket("/ws/chat/{room}", (connection, event, data) => {
    const room = connection.params.room;

    if (event === "open") {
        connection.broadcast(JSON.stringify({
            type: "system",
            message: `Someone joined room ${room}`
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
            message: `Someone left room ${room}`
        }));
    }
});
```

Connect to different rooms:

```
ws://localhost:7148/ws/chat/general
ws://localhost:7148/ws/chat/dev-team
```

A broadcast in `/ws/chat/general` reaches only clients on that path. The rooms are walls.

Path parameters use `{name}` curly-brace syntax, not `:name` colon syntax. Both `connection.params.room` and `connection.params["room"]` work.

---

## 8. Live Chat with Typing Indicators

```typescript
import { Router } from "tina4-nodejs";

const chatUsers: Record<string, { id: string; username: string; room: string }> = {};

Router.websocket("/ws/livechat/{room}", (connection, event, data) => {
    const room = connection.params.room;

    if (event === "open") {
        chatUsers[connection.id] = { id: connection.id, username: "Anonymous", room };

        connection.send(JSON.stringify({
            type: "welcome",
            message: `Connected to room: ${room}`,
            your_id: connection.id
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
                text: message.text ?? "",
                timestamp: new Date().toISOString()
            }));
        }

        if (type === "typing") {
            connection.broadcast(JSON.stringify({
                type: "typing",
                username: chatUsers[connection.id].username
            }));
        }
    }

    if (event === "close") {
        const username = chatUsers[connection.id]?.username ?? "Unknown";
        delete chatUsers[connection.id];

        connection.broadcast(JSON.stringify({
            type: "system",
            message: `${username} left the chat`
        }));
    }
});
```

---

## 9. Connecting from JavaScript (Browser Client)

Use the standard `WebSocket` API built into every browser. No library needed.

```html
<script>
    const ws = new WebSocket("ws://localhost:7148/ws/chat/general");

    ws.addEventListener("open", () => {
        console.log("Connected");
    });

    ws.addEventListener("message", (event) => {
        const message = JSON.parse(event.data);
        console.log("Received:", message);
    });

    ws.addEventListener("close", () => {
        console.log("Disconnected");
    });

    function sendMessage(text) {
        ws.send(JSON.stringify({ type: "message", text }));
    }
</script>
```

### Auto-Reconnect

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

---

## 10. Exercise: Build a Real-Time Chat Room

Build a WebSocket chat at `/ws/room/{roomName}` with usernames, join/leave messages, and an HTML page at `GET /room/{roomName}`.

---

## 11. Solution

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
            message: `Welcome to room: ${room}`
        }));
        connection.broadcast(JSON.stringify({
            type: "system",
            message: "A new user joined"
        }));
    }

    if (event === "message") {
        const msg = JSON.parse(data);

        if (msg.type === "set-name") {
            const oldName = roomUsers[key];
            roomUsers[key] = msg.name ?? "Anonymous";
            connection.broadcast(JSON.stringify({
                type: "system",
                message: `${oldName} changed their name to ${roomUsers[key]}`
            }));
        }

        if (msg.type === "chat") {
            connection.broadcast(JSON.stringify({
                type: "chat",
                from: roomUsers[key],
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
            message: `${username} left the room`
        }));
    }
});

Router.get("/room/{roomName}", async (req, res) => {
    return res.html("room.html", { room: req.params.roomName });
});
```

---

## 12. Gotchas

### 1. WebSocket Needs a Persistent Server

**Fix:** Use `tina4 serve` or `npx tsx app.ts`. Configure Nginx for WebSocket proxying.

### 2. Messages Are Strings, Not Objects

**Fix:** Always `JSON.parse(data)` on receive, `JSON.stringify()` on send.

### 3. Broadcast Is Path-Scoped

Clients on `/ws/chat/general` never see broadcasts from `/ws/chat/dev-team`. By design. Each path is an isolated group.

### 4. Broadcasting Does Not Scale Across Servers

**Fix:** Use Redis pub/sub to relay messages across server instances.

### 5. Large Messages Cause Disconnects

**Fix:** Keep messages under 64KB. Use HTTP for bulk data.

### 6. Memory Leak from Tracking Users

**Fix:** Always clean up in the `close` handler.

### 7. No Authentication on WebSocket

**Fix:** Pass token as query parameter and validate in the `open` handler.

### 8. Route Params Use `{id}` Not `:id`

WebSocket path parameters follow the same `{param}` curly-brace syntax as HTTP routes. Do not use Express-style `:param` colon syntax.
