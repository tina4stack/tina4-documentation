# Chapter 23: Real-time with WebSocket

## 1. The Refresh Button Problem

Your project management app needs live updates. Someone moves a card from "In Progress" to "Done." Everyone else on the team should see it. No page refresh. No polling. No waiting.

Traditional HTTP is request-response. The client asks. The server answers. The server cannot push data on its own. WebSocket breaks that wall. A persistent, bi-directional connection between browser and server. Either side sends messages at any time. The connection stays open until one side closes it.

Tina4 treats WebSocket the same way it treats routing. A decorator. A handler. The path determines which handler processes the connection.

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
- **Bi-directional**: The server can push data without the client asking.
- **Low overhead**: After the initial handshake, messages are tiny (no HTTP headers per message).
- **Real-time**: Messages arrive within milliseconds.

---

## 3. @websocket -- WebSocket as a Route

In Tina4, you define WebSocket handlers using the `@websocket` decorator:

```python
from tina4_python.core.router import websocket

@websocket("/ws/echo")
async def echo_handler(connection, event, data):
    if event == "message":
        await connection.send(f"Echo: {data}")
```

This is the simplest WebSocket handler: it receives a message and sends it back with "Echo: " prepended. The handler receives three arguments:

- **connection**: The WebSocket connection object. Use it to send messages.
- **event**: The event type: `"open"`, `"message"`, or `"close"`.
- **data**: The message data (only present for `"message"` events).

### Starting the Server

WebSocket runs alongside your HTTP server:

```bash
tina4 serve
```

```
  Tina4 Python v3.0.0
  HTTP server running at http://0.0.0.0:7145
  WebSocket server running at ws://0.0.0.0:7145
  Press Ctrl+C to stop
```

Both HTTP and WebSocket share the same port. The server detects the protocol upgrade request and routes it to the correct handler.

---

## 4. Connection Events

Every WebSocket connection goes through three lifecycle events:

### Open

Fires when a client connects:

```python
import json
from tina4_python.core.router import websocket

@websocket("/ws/notifications")
async def notifications_handler(connection, event, data):
    if event == "open":
        print(f"Client connected: {connection.id}")
        await connection.send(json.dumps({
            "type": "welcome",
            "message": "Connected to notifications",
            "connection_id": connection.id
        }))
```

### Message

Fires when a client sends data:

```python
import json
from datetime import datetime, timezone
from tina4_python.core.router import websocket

@websocket("/ws/notifications")
async def notifications_handler(connection, event, data):
    if event == "open":
        await connection.send(json.dumps({
            "type": "welcome",
            "connection_id": connection.id
        }))

    if event == "message":
        message = json.loads(data)
        print(f"Received from {connection.id}: {data}")

        if message.get("type") == "ping":
            await connection.send(json.dumps({
                "type": "pong",
                "timestamp": datetime.now(timezone.utc).isoformat()
            }))
```

### Close

Fires when a client disconnects:

```python
import json
from tina4_python.core.router import websocket

@websocket("/ws/notifications")
async def notifications_handler(connection, event, data):
    if event == "open":
        print(f"Client connected: {connection.id}")

    if event == "message":
        print(f"Message from {connection.id}: {data}")

    if event == "close":
        print(f"Client disconnected: {connection.id}")
        # Clean up: remove from tracking, notify others, etc.
```

### A Complete Handler

Here is a handler that responds to all three events:

```python
import json
from datetime import datetime, timezone
from tina4_python.core.router import websocket

@websocket("/ws/chat")
async def chat_handler(connection, event, data):
    if event == "open":
        print(f"[Chat] New connection: {connection.id}")
        await connection.send(json.dumps({
            "type": "system",
            "message": "Welcome to the chat!",
            "your_id": connection.id
        }))

    elif event == "message":
        message = json.loads(data)
        print(f"[Chat] {connection.id}: {message.get('text', data)}")

        await connection.send(json.dumps({
            "type": "message",
            "from": connection.id,
            "text": message.get("text", data),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }))

    elif event == "close":
        print(f"[Chat] Disconnected: {connection.id}")
```

---

## 5. Sending to a Single Client

`connection.send()` sends a message to the specific client that triggered the event:

```python
import json
import psutil
from datetime import datetime, timezone
from tina4_python.core.router import websocket

@websocket("/ws/private")
async def private_handler(connection, event, data):
    if event == "message":
        message = json.loads(data)
        action = message.get("action", "")

        if action == "get-time":
            await connection.send(json.dumps({
                "type": "time",
                "server_time": datetime.now(timezone.utc).isoformat()
            }))

        if action == "get-status":
            await connection.send(json.dumps({
                "type": "status",
                "uptime": 3600,
                "connections": 42,
                "memory_mb": round(psutil.Process().memory_info().rss / 1024 / 1024, 2)
            }))
```

Only the client that sent the message receives the response. Other connected clients do not see it.

---

## 6. Broadcasting to All Clients

`connection.broadcast()` sends a message to every client connected to the same WebSocket path:

```python
import json
from datetime import datetime, timezone
from tina4_python.core.router import websocket

@websocket("/ws/announcements")
async def announcements_handler(connection, event, data):
    if event == "open":
        await connection.broadcast(json.dumps({
            "type": "system",
            "message": "A new user joined",
            "online_count": connection.connection_count()
        }))

    if event == "message":
        message = json.loads(data)

        await connection.broadcast(json.dumps({
            "type": "announcement",
            "from": connection.id,
            "text": message.get("text", ""),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }))

    if event == "close":
        await connection.broadcast(json.dumps({
            "type": "system",
            "message": "A user left",
            "online_count": connection.connection_count()
        }))
```

When one client sends a message, every client connected to `/ws/announcements` receives it. This is the foundation for chat rooms, live dashboards, and collaborative editing.

### Broadcast Excluding Sender

Sometimes you want to send to everyone except the client that triggered the event:

```python
if event == "message":
    message = json.loads(data)

    # Send to sender (confirmation)
    await connection.send(json.dumps({
        "type": "sent",
        "text": message.get("text")
    }))

    # Send to everyone else
    await connection.broadcast(json.dumps({
        "type": "message",
        "from": message.get("username", "Anonymous"),
        "text": message.get("text"),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), exclude_self=True)
```

The `exclude_self=True` argument to `broadcast()` excludes the sender. The sender gets a "sent" confirmation, and everyone else gets the "message".

### Sending JSON

Use `connection.send_json()` to send a Python dict or list as a JSON string without manually calling `json.dumps()`:

```python
@websocket("/ws/status")
async def status_handler(connection, event, data):
    if event == "open":
        await connection.send_json({
            "type": "welcome",
            "connection_id": connection.id
        })

    if event == "message":
        await connection.send_json({
            "type": "ack",
            "received": data
        })
```

`send_json()` serialises the data to JSON for you. It is equivalent to `connection.send(json.dumps(data))` but saves you the import and the call.

### Closing a Connection

Use `connection.close()` to close the connection from the server side:

```python
@websocket("/ws/secure")
async def secure_handler(connection, event, data):
    if event == "open":
        token = connection.params.get("token")
        if not token or not valid_token(token):
            await connection.send_json({"error": "Unauthorized"})
            await connection.close()
            return

        await connection.send_json({"type": "welcome"})
```

### Connection Methods Summary

| Method | Description |
|--------|-------------|
| `await connection.send(message)` | Send a string message to this connection only |
| `await connection.send_json(data)` | Send a dict/list as JSON to this connection only |
| `await connection.broadcast(message)` | Send to all connections on the same path |
| `await connection.broadcast(message, exclude_self=True)` | Send to all except this connection |
| `await connection.close()` | Close this connection from the server side |
| `connection.id` | Unique identifier for this connection |
| `connection.params` | Path parameters extracted from the URL |
| `connection.connection_count()` | Number of active connections on this path |

---

## 7. Path-Scoped Isolation

Different WebSocket paths are completely isolated. Clients connected to `/ws/chat/room-1` do not see messages from `/ws/chat/room-2`:

```python
import json
from tina4_python.core.router import websocket

@websocket("/ws/chat/{room}")
async def room_handler(connection, event, data):
    room = connection.params["room"]

    if event == "open":
        print(f"[Room {room}] New connection: {connection.id}")
        await connection.broadcast(json.dumps({
            "type": "system",
            "message": f"Someone joined room {room}",
            "room": room,
            "online": connection.connection_count()
        }))

    if event == "message":
        message = json.loads(data)

        await connection.broadcast(json.dumps({
            "type": "message",
            "room": room,
            "from": message.get("username", "Anonymous"),
            "text": message.get("text", ""),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }))

    if event == "close":
        await connection.broadcast(json.dumps({
            "type": "system",
            "message": f"Someone left room {room}",
            "room": room,
            "online": connection.connection_count()
        }))
```

Connect to different rooms:

```
ws://localhost:7145/ws/chat/general    -- general chat
ws://localhost:7145/ws/chat/random     -- random chat
ws://localhost:7145/ws/chat/dev-team   -- dev team chat
```

Broadcasting in `/ws/chat/general` only reaches clients connected to `/ws/chat/general`. The `dev-team` and `random` rooms are separate.

Chat rooms. Project-specific notifications. Per-user channels. No extra configuration. The URL path is the isolation boundary.

---

## 8. Building a Live Chat

Here is a complete chat application with usernames, typing indicators, and message history:

### WebSocket Handler

Create `src/routes/chat_ws.py`:

```python
import json
from datetime import datetime, timezone
from tina4_python.core.router import websocket

chat_users = {}

@websocket("/ws/livechat/{room}")
async def livechat_handler(connection, event, data):
    room = connection.params["room"]

    if event == "open":
        chat_users[connection.id] = {
            "id": connection.id,
            "username": "Anonymous",
            "room": room,
            "joined_at": datetime.now(timezone.utc).isoformat()
        }

        await connection.send(json.dumps({
            "type": "welcome",
            "message": f"Connected to room: {room}",
            "your_id": connection.id,
            "online": connection.connection_count()
        }))

    if event == "message":
        message = json.loads(data)
        msg_type = message.get("type", "message")

        if msg_type == "set-username":
            old_name = chat_users[connection.id]["username"]
            chat_users[connection.id]["username"] = message["username"]

            await connection.broadcast(json.dumps({
                "type": "system",
                "message": f"{old_name} is now known as {message['username']}"
            }))

        if msg_type == "message":
            username = chat_users[connection.id]["username"]

            await connection.broadcast(json.dumps({
                "type": "message",
                "from": username,
                "from_id": connection.id,
                "text": message.get("text", ""),
                "timestamp": datetime.now(timezone.utc).isoformat()
            }))

        if msg_type == "typing":
            username = chat_users[connection.id]["username"]

            await connection.broadcast(json.dumps({
                "type": "typing",
                "username": username
            }), exclude_self=True)

    if event == "close":
        username = chat_users.get(connection.id, {}).get("username", "Unknown")
        chat_users.pop(connection.id, None)

        await connection.broadcast(json.dumps({
            "type": "system",
            "message": f"{username} left the chat",
            "online": connection.connection_count()
        }))
```

---

## 9. Live Notifications

WebSocket is great for pushing notifications to users in real time:

```python
import json
from datetime import datetime, timezone
from tina4_python.core.router import websocket, post, push_to_websocket

@websocket("/ws/notifications/{user_id}")
async def notification_handler(connection, event, data):
    user_id = connection.params["user_id"]

    if event == "open":
        print(f"[Notifications] User {user_id} connected")
        await connection.send(json.dumps({
            "type": "connected",
            "message": "Listening for notifications"
        }))

    if event == "message":
        message = json.loads(data)
        if message.get("type") == "mark-read":
            print(f"[Notifications] User {user_id} read notification {message['id']}")


@post("/api/orders/{order_id}/ship")
async def ship_order(request, response):
    order_id = request.params["order_id"]
    user_id = request.body.get("user_id", 0)

    # Update order status in database...

    # Send real-time notification via WebSocket
    await push_to_websocket(f"/ws/notifications/{user_id}", json.dumps({
        "type": "notification",
        "title": "Order Shipped",
        "message": f"Your order #{order_id} has been shipped!",
        "action_url": f"/orders/{order_id}",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }))

    return response({"message": "Order shipped, user notified"})
```

The `push_to_websocket()` function lets your HTTP handlers send messages to WebSocket clients. This bridges the gap between traditional request-response endpoints and real-time notifications.

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

`frond.js` automatically reconnects when the connection drops:

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
const ws = new WebSocket("ws://localhost:7145/ws/chat/general");

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

```python
from tina4_python.core.router import get, template

@get("/chat/{room}")
async def chat_page(request, response):
    room = request.params["room"]
    return response(template("chat.html", room=room))
```

Visit `http://localhost:7145/chat/general` in two browser tabs. Type in one tab and watch the message appear in the other instantly.

---

## 12. Exercise: Build a Real-Time Chat Room

Build a WebSocket chat room with the following features:

### Requirements

1. WebSocket endpoint at `/ws/room/{room_name}` that handles:
   - `open`: Send welcome message with connection count
   - `message` with type `set-name`: Set the user's display name
   - `message` with type `chat`: Broadcast the message to all clients with the sender's name
   - `close`: Broadcast that the user left

2. HTTP endpoint at `GET /room/{room_name}` that serves an HTML chat page

3. The chat page should:
   - Prompt for a username on load
   - Display messages in real time
   - Show system messages (join/leave) in a different style
   - Show the count of online users

### Test by:

1. Open `http://localhost:7145/room/test` in two browser tabs
2. Set different usernames in each
3. Send messages from both tabs and verify they appear in both
4. Close one tab and verify the "user left" message appears in the other

---

## 13. Solution

Create `src/routes/chat_room.py`:

```python
import json
from datetime import datetime, timezone
from tina4_python.core.router import websocket, get, template

room_users = {}

@websocket("/ws/room/{room_name}")
async def room_ws_handler(connection, event, data):
    room = connection.params["room_name"]
    key = f"{room}:{connection.id}"

    if event == "open":
        room_users[key] = "Anonymous"

        await connection.send(json.dumps({
            "type": "system",
            "message": f"Welcome to room: {room}. Set your name with: "
                       '{"type": "set-name", "name": "YourName"}',
            "online": connection.connection_count()
        }))

        await connection.broadcast(json.dumps({
            "type": "system",
            "message": "A new user joined",
            "online": connection.connection_count()
        }), exclude_self=True)

    if event == "message":
        msg = json.loads(data)
        msg_type = msg.get("type", "chat")

        if msg_type == "set-name":
            old_name = room_users.get(key, "Anonymous")
            new_name = msg.get("name", "Anonymous")
            room_users[key] = new_name

            await connection.broadcast(json.dumps({
                "type": "system",
                "message": f"{old_name} changed their name to {new_name}"
            }))

        if msg_type == "chat":
            username = room_users.get(key, "Anonymous")

            await connection.broadcast(json.dumps({
                "type": "chat",
                "from": username,
                "text": msg.get("text", ""),
                "timestamp": datetime.now(timezone.utc).strftime("%H:%M:%S")
            }))

    if event == "close":
        username = room_users.get(key, "Anonymous")
        room_users.pop(key, None)

        await connection.broadcast(json.dumps({
            "type": "system",
            "message": f"{username} left the room",
            "online": connection.connection_count()
        }))


@get("/room/{room_name}")
async def room_page(request, response):
    room = request.params["room_name"]
    return response(template("room.html", room=room))
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

Open `http://localhost:7145/room/test` in two browser tabs. Set different usernames. Send messages from one tab and watch them appear in both. Close one tab and verify the "left the room" message appears.

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
uv add redis
```

If `TINA4_WS_BACKPLANE` is not set (the default), Tina4 broadcasts only to local connections. This is fine for single-instance deployments.

---

## 15. Gotchas

### 1. WebSocket Needs a Persistent Server

**Problem:** WebSocket connections drop immediately or do not work at all.

**Cause:** You are running behind a traditional WSGI server like Gunicorn with sync workers. WSGI does not support persistent connections. Each request is handled and the connection is closed.

**Fix:** Use `tina4 serve` which runs Tina4's async server that handles both HTTP and WebSocket. For production, use an ASGI server like uvicorn or hypercorn (Tina4 auto-detects them). You can still use Nginx as a reverse proxy, but it must be configured for WebSocket proxying with `proxy_set_header Upgrade $http_upgrade` and `proxy_set_header Connection "upgrade"`.

### 2. Messages Are Strings, Not Dicts

**Problem:** `data` in the message handler is a string, not a Python dict.

**Cause:** WebSocket transmits raw strings. If the client sends JSON, you receive the JSON string, not a decoded dict.

**Fix:** Always `json.loads(data)` when you expect JSON messages. Always `json.dumps()` when you send structured data. WebSocket does not know about content types -- it is just bytes.

### 3. Connection Count Is Per-Path

**Problem:** `connection.connection_count()` returns a lower number than expected.

**Cause:** Connection count is scoped to the WebSocket path. Clients on `/ws/chat/room-1` are counted separately from `/ws/chat/room-2`.

**Fix:** This is by design. Each path is an isolated group. If you need a global connection count across all paths, maintain a counter in a shared variable or use a module-level dict.

### 4. Broadcasting Does Not Scale Across Servers

**Problem:** Users connected to different server instances do not see each other's messages.

**Cause:** `connection.broadcast()` only sends to clients connected to the same server process. With multiple server instances behind a load balancer, each instance has its own set of connections.

**Fix:** Use a pub/sub backend like Redis to relay messages across server instances. Each server subscribes to a Redis channel, and broadcast messages are published to Redis so all servers receive them.

### 5. Large Messages Cause Disconnects

**Problem:** The connection drops when sending a large message.

**Cause:** WebSocket servers typically have a maximum message size. The default is usually around 1MB. If your message exceeds this, the server closes the connection.

**Fix:** Keep messages small (under 64KB is a good target). For large data transfers, use HTTP endpoints instead of WebSocket. WebSocket is designed for small, frequent messages -- not bulk data transfer.

### 6. Memory Leak from Tracking Connected Users

**Problem:** The server's memory usage grows over time and eventually crashes.

**Cause:** You store user data in a dict (like `chat_users`) but do not clean it up when users disconnect. If the `close` event handler does not remove the user from the dict, the dict grows indefinitely.

**Fix:** Always clean up in the `close` handler. Remove disconnected users from tracking dicts: `chat_users.pop(connection.id, None)`. Test by connecting and disconnecting repeatedly to verify memory stays stable.

### 7. No Authentication on WebSocket Connect

**Problem:** Anyone can connect to your WebSocket endpoint and see all messages.

**Cause:** The WebSocket upgrade request does not carry your JWT token in the `Authorization` header (browsers do not support custom headers on WebSocket connections).

**Fix:** Pass the token as a query parameter: `ws://localhost:7145/ws/chat?token=eyJ...`. In your `open` handler, validate the token and disconnect if invalid. Use a short-lived token specifically for WebSocket connections. Alternatively, authenticate via an HTTP endpoint first, store the session, and check the session cookie during the WebSocket upgrade.
