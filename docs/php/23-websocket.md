# Chapter 23: Real-time with WebSocket

## 1. The Refresh Button Problem

Your project management app needs live updates. Someone moves a card from "In Progress" to "Done." Everyone else should see it. No page refresh. No polling. No waiting.

HTTP is a conversation with amnesia. The client asks, the server answers, the connection dies. The server cannot reach back.

WebSocket fixes this. It opens a persistent, two-way channel between browser and server. Either side sends messages at any time. The connection holds until someone closes it.

Tina4 treats WebSocket the same as routing. Define a handler. Assign a path. Done.

---

## 2. What WebSocket Is

HTTP works this way:

```
Client: "Give me /api/products"
Server: "Here are the products" (connection closes)
Client: "Give me /api/products" (new connection)
Server: "Here are the products" (connection closes)
```

WebSocket works this way:

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

Four differences matter:

- **Persistent**: The connection stays open. No repeated handshakes.
- **Bi-directional**: The server pushes data without the client asking.
- **Low overhead**: After the initial handshake, messages are tiny. No HTTP headers per message.
- **Real-time**: Messages arrive within milliseconds.

---

## 3. Router::websocket() -- WebSocket as a Route

Define WebSocket handlers with `Router::websocket()`:

```php
<?php
use Tina4\Router;

Router::websocket("/ws/echo", function ($connection, $event, $data) {
    if ($event === "message") {
        $connection->send("Echo: " . $data);
    }
});
```

The simplest handler. It receives a message and sends it back with "Echo: " prepended. Three arguments arrive:

- **$connection**: The WebSocket connection object. Send messages through it.
- **$event**: The event type: `"open"`, `"message"`, or `"close"`.
- **$data**: The message data. Present only for `"message"` events.

### Starting the Server

WebSocket runs alongside your HTTP server:

```bash
tina4 serve
```

```
  Tina4 PHP v3.0.0
  HTTP server running at http://0.0.0.0:7146
  WebSocket server running at ws://0.0.0.0:7146
  Press Ctrl+C to stop
```

Both protocols share the same port. Tina4's built-in server uses PHP's `stream_select()` to multiplex HTTP and WebSocket connections in a single process -- no extensions like Swoole or ReactPHP required. The server detects the upgrade request and routes to the correct handler.

---

## 4. Connection Events

Every WebSocket connection passes through three lifecycle events.

### Open

Fires when a client connects:

```php
<?php
use Tina4\Router;

Router::websocket("/ws/notifications", function ($connection, $event, $data) {
    if ($event === "open") {
        error_log("Client connected: " . $connection->id);
        $connection->send(json_encode([
            "type" => "welcome",
            "message" => "Connected to notifications",
            "connection_id" => $connection->id
        ]));
    }
});
```

### Message

Fires when a client sends data:

```php
Router::websocket("/ws/notifications", function ($connection, $event, $data) {
    if ($event === "open") {
        $connection->send(json_encode([
            "type" => "welcome",
            "connection_id" => $connection->id
        ]));
    }

    if ($event === "message") {
        $message = json_decode($data, true);
        error_log("Received from " . $connection->id . ": " . $data);

        // Process the message based on its type
        if (($message["type"] ?? "") === "ping") {
            $connection->send(json_encode([
                "type" => "pong",
                "timestamp" => date("c")
            ]));
        }
    }
});
```

### Close

Fires when a client disconnects:

```php
Router::websocket("/ws/notifications", function ($connection, $event, $data) {
    if ($event === "open") {
        error_log("Client connected: " . $connection->id);
    }

    if ($event === "message") {
        error_log("Message from " . $connection->id . ": " . $data);
    }

    if ($event === "close") {
        error_log("Client disconnected: " . $connection->id);
        // Clean up: remove from tracking, notify others, etc.
    }
});
```

### A Complete Handler

All three events in one handler:

```php
<?php
use Tina4\Router;

Router::websocket("/ws/chat", function ($connection, $event, $data) {
    switch ($event) {
        case "open":
            error_log("[Chat] New connection: " . $connection->id);
            $connection->send(json_encode([
                "type" => "system",
                "message" => "Welcome to the chat!",
                "your_id" => $connection->id
            ]));
            break;

        case "message":
            $message = json_decode($data, true);
            error_log("[Chat] " . $connection->id . ": " . ($message["text"] ?? $data));

            // Echo back with sender info
            $connection->send(json_encode([
                "type" => "message",
                "from" => $connection->id,
                "text" => $message["text"] ?? $data,
                "timestamp" => date("c")
            ]));
            break;

        case "close":
            error_log("[Chat] Disconnected: " . $connection->id);
            break;
    }
});
```

---

## 5. Sending to a Single Client

`$connection->send()` targets the specific client that triggered the event:

```php
Router::websocket("/ws/private", function ($connection, $event, $data) {
    if ($event === "message") {
        $message = json_decode($data, true);
        $action = $message["action"] ?? "";

        if ($action === "get-time") {
            $connection->send(json_encode([
                "type" => "time",
                "server_time" => date("c"),
                "timezone" => date_default_timezone_get()
            ]));
        }

        if ($action === "get-status") {
            $connection->send(json_encode([
                "type" => "status",
                "uptime" => 3600,
                "connections" => 42,
                "memory_mb" => round(memory_get_usage() / 1024 / 1024, 2)
            ]));
        }
    }
});
```

Only the sender receives the response. Other connected clients see nothing.

### Closing a Connection

`$connection->close()` terminates the connection from the server side:

```php
Router::websocket("/ws/secure", function ($connection, $event, $data) {
    if ($event === "open") {
        // Reject unauthenticated connections
        $token = $connection->params["token"] ?? "";
        if (!Auth::validToken($token)) {
            $connection->send(json_encode([
                "type" => "error",
                "message" => "Invalid token"
            ]));
            $connection->close();
            return;
        }
    }
});
```

The client receives the close event. Use this for kicking users, enforcing authentication, or cleaning up idle connections.

---

## 6. Broadcasting to All Clients

`$connection->broadcast()` sends a message to every client connected to the same WebSocket path:

```php
<?php
use Tina4\Router;

Router::websocket("/ws/announcements", function ($connection, $event, $data) {
    if ($event === "open") {
        // Tell everyone about the new connection
        $connection->broadcast(json_encode([
            "type" => "system",
            "message" => "A new user joined",
            "online_count" => $connection->connectionCount()
        ]));
    }

    if ($event === "message") {
        $message = json_decode($data, true);

        // Broadcast the message to everyone (including sender)
        $connection->broadcast(json_encode([
            "type" => "announcement",
            "from" => $connection->id,
            "text" => $message["text"] ?? "",
            "timestamp" => date("c")
        ]));
    }

    if ($event === "close") {
        $connection->broadcast(json_encode([
            "type" => "system",
            "message" => "A user left",
            "online_count" => $connection->connectionCount()
        ]));
    }
});
```

One client sends a message. Every client connected to `/ws/announcements` receives it. Chat rooms, live dashboards, collaborative editing -- they all start here.

### Broadcast Excluding Sender

Send to everyone except the client that triggered the event:

```php
if ($event === "message") {
    $message = json_decode($data, true);

    // Send to sender (confirmation)
    $connection->send(json_encode([
        "type" => "sent",
        "text" => $message["text"]
    ]));

    // Send to everyone else
    $connection->broadcast(json_encode([
        "type" => "message",
        "from" => $message["username"] ?? "Anonymous",
        "text" => $message["text"],
        "timestamp" => date("c")
    ]), true); // true = exclude sender
}
```

The second argument to `broadcast()` excludes the sender when set to `true`. The sender gets a "sent" confirmation. Everyone else gets the "message."

---

## 7. Path-Scoped Isolation

Different WebSocket paths are walls. Clients connected to `/ws/chat/room-1` never see messages from `/ws/chat/room-2`:

```php
<?php
use Tina4\Router;

Router::websocket("/ws/chat/{room}", function ($connection, $event, $data) {
    $room = $connection->params["room"];

    if ($event === "open") {
        error_log("[Room " . $room . "] New connection: " . $connection->id);
        $connection->broadcast(json_encode([
            "type" => "system",
            "message" => "Someone joined room " . $room,
            "room" => $room,
            "online" => $connection->connectionCount()
        ]));
    }

    if ($event === "message") {
        $message = json_decode($data, true);

        $connection->broadcast(json_encode([
            "type" => "message",
            "room" => $room,
            "from" => $message["username"] ?? "Anonymous",
            "text" => $message["text"] ?? "",
            "timestamp" => date("c")
        ]));
    }

    if ($event === "close") {
        $connection->broadcast(json_encode([
            "type" => "system",
            "message" => "Someone left room " . $room,
            "room" => $room,
            "online" => $connection->connectionCount()
        ]));
    }
});
```

Connect to different rooms:

```
ws://localhost:7146/ws/chat/general    -- general chat
ws://localhost:7146/ws/chat/random     -- random chat
ws://localhost:7146/ws/chat/dev-team   -- dev team chat
```

Broadcasting in `/ws/chat/general` reaches only clients in `/ws/chat/general`. The `dev-team` and `random` rooms are separate worlds.

Chat rooms. Project-specific notifications. Per-user channels. No extra configuration. The URL path is the isolation boundary.

---

## 8. Building a Live Chat

A complete chat application with usernames, typing indicators, and message history.

### WebSocket Handler

Create `src/routes/chat-ws.php`:

```php
<?php
use Tina4\Router;

$chatUsers = [];

Router::websocket("/ws/livechat/{room}", function ($connection, $event, $data) use (&$chatUsers) {
    $room = $connection->params["room"];

    if ($event === "open") {
        // User has not set their name yet
        $chatUsers[$connection->id] = [
            "id" => $connection->id,
            "username" => "Anonymous",
            "room" => $room,
            "joined_at" => date("c")
        ];

        $connection->send(json_encode([
            "type" => "welcome",
            "message" => "Connected to room: " . $room,
            "your_id" => $connection->id,
            "online" => $connection->connectionCount()
        ]));
    }

    if ($event === "message") {
        $message = json_decode($data, true);
        $type = $message["type"] ?? "message";

        if ($type === "set-username") {
            $oldName = $chatUsers[$connection->id]["username"];
            $chatUsers[$connection->id]["username"] = $message["username"];

            $connection->broadcast(json_encode([
                "type" => "system",
                "message" => $oldName . " is now known as " . $message["username"]
            ]));
        }

        if ($type === "message") {
            $username = $chatUsers[$connection->id]["username"];

            $connection->broadcast(json_encode([
                "type" => "message",
                "from" => $username,
                "from_id" => $connection->id,
                "text" => $message["text"] ?? "",
                "timestamp" => date("c")
            ]));
        }

        if ($type === "typing") {
            $username = $chatUsers[$connection->id]["username"];

            $connection->broadcast(json_encode([
                "type" => "typing",
                "username" => $username
            ]), true); // Exclude sender
        }
    }

    if ($event === "close") {
        $username = $chatUsers[$connection->id]["username"] ?? "Unknown";
        unset($chatUsers[$connection->id]);

        $connection->broadcast(json_encode([
            "type" => "system",
            "message" => $username . " left the chat",
            "online" => $connection->connectionCount()
        ]));
    }
});
```

---

## 9. Live Notifications

WebSocket pushes notifications to users in real time:

```php
<?php
use Tina4\Router;
use Tina4\Queue;

// WebSocket handler for notifications
Router::websocket("/ws/notifications/{userId}", function ($connection, $event, $data) {
    $userId = $connection->params["userId"];

    if ($event === "open") {
        error_log("[Notifications] User " . $userId . " connected");
        $connection->send(json_encode([
            "type" => "connected",
            "message" => "Listening for notifications"
        ]));
    }

    if ($event === "message") {
        // Client can send acknowledgments or mark notifications as read
        $message = json_decode($data, true);
        if (($message["type"] ?? "") === "mark-read") {
            error_log("[Notifications] User " . $userId . " read notification " . $message["id"]);
        }
    }
});

// HTTP endpoint that triggers a notification
Router::post("/api/orders/{orderId:int}/ship", function ($request, $response) {
    $orderId = $request->params["orderId"];
    $userId = $request->body["user_id"] ?? 0;

    // Update order status in database...

    // Send real-time notification via WebSocket
    // The notification is pushed to all connections on /ws/notifications/{userId}
    Router::pushToWebSocket("/ws/notifications/" . $userId, json_encode([
        "type" => "notification",
        "title" => "Order Shipped",
        "message" => "Your order #" . $orderId . " has been shipped!",
        "action_url" => "/orders/" . $orderId,
        "timestamp" => date("c")
    ]));

    return $response->json(["message" => "Order shipped, user notified"]);
});
```

`Router::pushToWebSocket()` bridges the gap. Your HTTP handlers send messages to WebSocket clients. Request-response meets real-time.

---

## 10. Connecting from JavaScript

Tina4 ships `frond.js`, a built-in JavaScript helper library with WebSocket support.

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

    // Send a message
    function sendMessage(text) {
        ws.send(JSON.stringify({
            type: "message",
            text: text
        }));
    }

    // Set username
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

The native WebSocket API works too:

```javascript
const ws = new WebSocket("ws://localhost:7146/ws/chat/general");

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

The advantage of `frond.js`: auto-reconnect, message buffering during reconnection, a cleaner event API.

---

## 11. A Complete Chat Page

A full chat page using templates and WebSocket.

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

```php
<?php
use Tina4\Router;

Router::get("/chat/{room}", function ($request, $response) {
    $room = $request->params["room"];
    return $response->render("chat.html", ["room" => $room]);
});
```

Open `http://localhost:7146/chat/general` in two browser tabs. Type in one. Watch the message appear in the other.

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

1. Open `http://localhost:7146/room/test` in two browser tabs
2. Set different usernames in each
3. Send messages from both tabs and verify they appear in both
4. Close one tab and verify the "user left" message appears in the other

---

## 13. Solution

Create `src/routes/chat-room.php`:

```php
<?php
use Tina4\Router;

$roomUsers = [];

Router::websocket("/ws/room/{roomName}", function ($connection, $event, $data) use (&$roomUsers) {
    $room = $connection->params["roomName"];
    $key = $room . ":" . $connection->id;

    if ($event === "open") {
        $roomUsers[$key] = "Anonymous";

        $connection->send(json_encode([
            "type" => "system",
            "message" => "Welcome to room: " . $room . ". Set your name with: {\"type\": \"set-name\", \"name\": \"YourName\"}",
            "online" => $connection->connectionCount()
        ]));

        $connection->broadcast(json_encode([
            "type" => "system",
            "message" => "A new user joined",
            "online" => $connection->connectionCount()
        ]), true);
    }

    if ($event === "message") {
        $msg = json_decode($data, true);
        $type = $msg["type"] ?? "chat";

        if ($type === "set-name") {
            $oldName = $roomUsers[$key] ?? "Anonymous";
            $newName = $msg["name"] ?? "Anonymous";
            $roomUsers[$key] = $newName;

            $connection->broadcast(json_encode([
                "type" => "system",
                "message" => $oldName . " changed their name to " . $newName
            ]));
        }

        if ($type === "chat") {
            $username = $roomUsers[$key] ?? "Anonymous";

            $connection->broadcast(json_encode([
                "type" => "chat",
                "from" => $username,
                "text" => $msg["text"] ?? "",
                "timestamp" => date("H:i:s")
            ]));
        }
    }

    if ($event === "close") {
        $username = $roomUsers[$key] ?? "Anonymous";
        unset($roomUsers[$key]);

        $connection->broadcast(json_encode([
            "type" => "system",
            "message" => $username . " left the room",
            "online" => $connection->connectionCount()
        ]));
    }
});

Router::get("/room/{roomName}", function ($request, $response) {
    $room = $request->params["roomName"];
    return $response->render("room.html", ["room" => $room]);
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

Open `http://localhost:7146/room/test` in two browser tabs. Set different usernames. Send messages from one tab and watch them appear in both. Close one tab and verify the "left the room" message appears.

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
composer require predis/predis
```

If `TINA4_WS_BACKPLANE` is not set (the default), Tina4 broadcasts only to local connections. This is fine for single-instance deployments.

---

## 15. Gotchas

### 1. WebSocket Needs a Persistent Server

**Problem:** WebSocket connections drop or fail to connect.

**Cause:** You are running behind a traditional PHP-FPM + Nginx setup. PHP-FPM processes terminate after each HTTP request. No persistent process exists to maintain WebSocket connections.

**Fix:** Use `tina4 serve`. It runs a persistent server handling both HTTP and WebSocket. For production, run the Tina4 server directly -- not behind PHP-FPM. Nginx can still serve as a reverse proxy, but it must be configured for WebSocket: `proxy_set_header Upgrade $http_upgrade` and `proxy_set_header Connection "upgrade"`.

### 2. Messages Are Strings, Not Objects

**Problem:** `$data` in the message handler is a string, not a PHP array.

**Cause:** WebSocket transmits raw strings. JSON from the client arrives as a JSON string, not a decoded array.

**Fix:** Always `json_decode($data, true)` when you expect JSON. Always `json_encode()` when you send structured data. WebSocket does not know about content types. It moves bytes.

### 3. Connection Count Is Per-Path

**Problem:** `$connection->connectionCount()` returns a lower number than expected.

**Cause:** Connection count is scoped to the WebSocket path. Clients on `/ws/chat/room-1` are counted separately from `/ws/chat/room-2`.

**Fix:** This is by design. Each path is an isolated group. For a global connection count across all paths, maintain a counter in a shared variable.

### 4. Broadcasting Does Not Scale Across Servers

**Problem:** Users connected to different server instances do not see each other's messages.

**Cause:** `$connection->broadcast()` sends only to clients on the same server process. Multiple instances behind a load balancer each maintain their own connection sets.

**Fix:** Use a pub/sub backend. Redis works well. Each server subscribes to a Redis channel. Broadcast messages publish to Redis. All servers receive them.

### 5. Large Messages Cause Disconnects

**Problem:** The connection drops when sending a large message.

**Cause:** WebSocket servers enforce a maximum message size. The default is around 1MB. Exceed it, and the server closes the connection.

**Fix:** Keep messages small. Under 64KB is a good target. For large data transfers, use HTTP endpoints. WebSocket is built for small, frequent messages -- not bulk data.

### 6. Memory Leak from Tracking Connected Users

**Problem:** Server memory grows over time and crashes.

**Cause:** User data stored in a PHP array (like `$chatUsers`) is not cleaned up when users disconnect. The `close` handler does not remove them. The array grows without limit.

**Fix:** Always clean up in the `close` handler. Remove disconnected users from tracking arrays: `unset($chatUsers[$connection->id])`. Test by connecting and disconnecting repeatedly. Verify memory stays stable.

### 7. No Authentication on WebSocket Connect

**Problem:** Anyone can connect to your WebSocket endpoint and see all messages.

**Cause:** The WebSocket upgrade request does not carry your JWT token in the `Authorization` header. Browsers do not support custom headers on WebSocket connections.

**Fix:** Pass the token as a query parameter: `ws://localhost:7146/ws/chat?token=eyJ...`. In your `open` handler, validate the token and disconnect if invalid. Use a short-lived token for WebSocket connections. Or authenticate via HTTP first, store the session, and check the session cookie during the upgrade.
