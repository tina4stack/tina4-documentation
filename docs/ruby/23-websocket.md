# Chapter 23: Real-time with WebSocket

## 1. The Refresh Button Problem

Your project management app needs live updates. Someone moves a card from "In Progress" to "Done." Everyone else should see it -- no page refresh, no polling, no waiting. But HTTP is request-response. The client asks. The server answers. The server cannot speak first.

WebSocket tears down that wall. It establishes a persistent, bi-directional connection between browser and server. Either side can send messages at any time. The connection holds until one side closes it.

Tina4 treats WebSocket as routing. Define a WebSocket handler the same way you define an HTTP route. The path determines which handler owns the connection.

---

## 2. What WebSocket Is

HTTP works like this:

```
Client: "Give me /api/products"
Server: "Here are the products" (connection closes)
```

WebSocket works like this:

```
Client: "I want to upgrade to WebSocket on /ws/chat"
Server: "Upgrade accepted. Connection open."
Client: "Hello everyone!"
Server: "Alice says: Hello everyone!"  (pushed to all clients)
Server: "Bob joined the chat"  (pushed to all clients, at any time)
```

Key differences:

- **Persistent**: The connection stays open. No repeated handshakes.
- **Bi-directional**: The server can push data without the client asking.
- **Low overhead**: After the initial handshake, messages are tiny.
- **Real-time**: Messages arrive within milliseconds.

---

## 3. Router.websocket -- WebSocket as a Route

In Tina4, you define WebSocket handlers using `Tina4::Router.websocket`:

```ruby
Tina4::Router.websocket "/ws/echo" do |connection, event, data|
  if event == :message
    connection.send("Echo: #{data}")
  end
end
```

This is the simplest WebSocket handler: it receives a message and sends it back with "Echo: " prepended. The handler receives three arguments:

- **connection**: The WebSocket connection object. Use it to send messages, broadcast, or close the connection.
- **event**: The event type as a symbol: `:open`, `:message`, or `:close`.
- **data**: The message data (only present for `:message` events).

### Shorthand Syntax

The same handler can be written with the shorthand `Tina4.websocket`:

```ruby
Tina4.websocket "/ws/echo" do |connection, event, data|
  if event == :message
    connection.send("Echo: #{data}")
  end
end
```

Both forms are identical. Use whichever reads better in your project.

### Starting the Server

WebSocket runs alongside your HTTP server. It works with both Puma and WEBrick:

```bash
tina4 serve
```

```
  Tina4 Ruby v3.0.0
  HTTP server running at http://0.0.0.0:7147
  WebSocket server running at ws://0.0.0.0:7147
  Press Ctrl+C to stop
```

---

## 4. Connection Events

There are three events, passed as symbols:

| Event      | When it fires                        | `data` argument        |
|------------|--------------------------------------|------------------------|
| `:open`    | A client connects                    | `nil`                  |
| `:message` | A client sends a message             | The message string     |
| `:close`   | A client disconnects                 | `nil`                  |

### A Complete Handler

```ruby
Tina4::Router.websocket "/ws/chat" do |connection, event, data|
  case event
  when :open
    $stderr.puts "[Chat] New connection: #{connection.id}"
    connection.send(JSON.generate({
      type: "system",
      message: "Welcome to the chat!",
      your_id: connection.id
    }))

  when :message
    message = JSON.parse(data)
    $stderr.puts "[Chat] #{connection.id}: #{message['text'] || data}"

    connection.send(JSON.generate({
      type: "message",
      from: connection.id,
      text: message["text"] || data,
      timestamp: Time.now.iso8601
    }))

  when :close
    $stderr.puts "[Chat] Disconnected: #{connection.id}"
  end
end
```

---

## 5. Connection Methods

The `connection` object provides three methods for communication:

| Method                              | What it does                                              |
|-------------------------------------|-----------------------------------------------------------|
| `connection.send(message)`          | Send a message to this client only                        |
| `connection.broadcast(message)`     | Send a message to all clients on the same path            |
| `connection.close()`               | Close this client's connection                            |

### Sending to a Single Client

`connection.send` sends a message to the specific client that triggered the event:

```ruby
Tina4::Router.websocket "/ws/private" do |connection, event, data|
  if event == :message
    message = JSON.parse(data)
    action = message["action"] || ""

    if action == "get-time"
      connection.send(JSON.generate({
        type: "time",
        server_time: Time.now.iso8601
      }))
    end

    if action == "get-status"
      connection.send(JSON.generate({
        type: "status",
        uptime: 3600,
        connections: 42,
        memory_mb: (ObjectSpace.memsize_of_all / 1024.0 / 1024.0).round(2)
      }))
    end
  end
end
```

### Closing a Connection

`connection.close` terminates the client's connection from the server side. This triggers the `:close` event:

```ruby
Tina4::Router.websocket "/ws/secure" do |connection, event, data|
  case event
  when :open
    token = connection.params["token"]
    unless valid_token?(token)
      connection.send(JSON.generate({ error: "Invalid token" }))
      connection.close
    end
  when :message
    connection.broadcast(data)
  when :close
    $stderr.puts "Client disconnected"
  end
end
```

---

## 6. Broadcasting to All Clients

`connection.broadcast` sends a message to every client connected to the same WebSocket path. Broadcast is **path-scoped** -- clients on `/ws/chat/room-1` never receive broadcasts from `/ws/chat/room-2`:

```ruby
Tina4::Router.websocket "/ws/announcements" do |connection, event, data|
  case event
  when :open
    connection.broadcast(JSON.generate({
      type: "system",
      message: "A new user joined",
      online_count: connection.connection_count
    }))

  when :message
    message = JSON.parse(data)

    connection.broadcast(JSON.generate({
      type: "announcement",
      from: connection.id,
      text: message["text"] || "",
      timestamp: Time.now.iso8601
    }))

  when :close
    connection.broadcast(JSON.generate({
      type: "system",
      message: "A user left",
      online_count: connection.connection_count
    }))
  end
end
```

### Broadcast Excluding Sender

```ruby
when :message
  message = JSON.parse(data)

  # Send to sender (confirmation)
  connection.send(JSON.generate({ type: "sent", text: message["text"] }))

  # Send to everyone else
  connection.broadcast(JSON.generate({
    type: "message",
    from: message["username"] || "Anonymous",
    text: message["text"],
    timestamp: Time.now.iso8601
  }), true)  # true = exclude sender
```

---

## 7. Path Parameters and Scoped Isolation

WebSocket paths support the same `{param}` syntax as HTTP routes. Access them with `connection.params["param_name"]`. Different resolved paths are completely isolated:

```ruby
Tina4::Router.websocket "/ws/chat/{room}" do |connection, event, data|
  room = connection.params["room"]

  case event
  when :open
    $stderr.puts "[Room #{room}] New connection: #{connection.id}"
    connection.broadcast(JSON.generate({
      type: "system",
      message: "Someone joined room #{room}",
      room: room,
      online: connection.connection_count
    }))

  when :message
    message = JSON.parse(data)
    connection.broadcast(JSON.generate({
      type: "message",
      room: room,
      from: message["username"] || "Anonymous",
      text: message["text"] || "",
      timestamp: Time.now.iso8601
    }))

  when :close
    connection.broadcast(JSON.generate({
      type: "system",
      message: "Someone left room #{room}",
      room: room,
      online: connection.connection_count
    }))
  end
end
```

A client connecting to `/ws/chat/ruby` only sees messages broadcast on `/ws/chat/ruby`. A client on `/ws/chat/python` is in a completely separate space.

---

## 8. Building a Live Chat

### WebSocket Handler

Create `src/routes/chat_ws.rb`:

```ruby
$chat_users = {}

Tina4::Router.websocket "/ws/livechat/{room}" do |connection, event, data|
  room = connection.params["room"]

  case event
  when :open
    $chat_users[connection.id] = {
      id: connection.id,
      username: "Anonymous",
      room: room,
      joined_at: Time.now.iso8601
    }

    connection.send(JSON.generate({
      type: "welcome",
      message: "Connected to room: #{room}",
      your_id: connection.id,
      online: connection.connection_count
    }))

  when :message
    message = JSON.parse(data)
    type = message["type"] || "message"

    if type == "set-username"
      old_name = $chat_users[connection.id][:username]
      $chat_users[connection.id][:username] = message["username"]

      connection.broadcast(JSON.generate({
        type: "system",
        message: "#{old_name} is now known as #{message['username']}"
      }))
    end

    if type == "message"
      username = $chat_users[connection.id][:username]

      connection.broadcast(JSON.generate({
        type: "message",
        from: username,
        from_id: connection.id,
        text: message["text"] || "",
        timestamp: Time.now.iso8601
      }))
    end

    if type == "typing"
      username = $chat_users[connection.id][:username]

      connection.broadcast(JSON.generate({
        type: "typing",
        username: username
      }), true)  # Exclude sender
    end

  when :close
    username = $chat_users.dig(connection.id, :username) || "Unknown"
    $chat_users.delete(connection.id)

    connection.broadcast(JSON.generate({
      type: "system",
      message: "#{username} left the chat",
      online: connection.connection_count
    }))
  end
end
```

---

## 9. Live Notifications

WebSocket is great for pushing notifications to users in real time:

```ruby
Tina4::Router.websocket "/ws/notifications/{user_id}" do |connection, event, data|
  user_id = connection.params["user_id"]

  case event
  when :open
    $stderr.puts "[Notifications] User #{user_id} connected"
    connection.send(JSON.generate({
      type: "connected",
      message: "Listening for notifications"
    }))
  when :message
    # Handle client acknowledgments if needed
  when :close
    $stderr.puts "[Notifications] User #{user_id} disconnected"
  end
end

# HTTP endpoint that triggers a notification
Tina4::Router.post("/api/orders/{order_id:int}/ship") do |request, response|
  order_id = request.params["order_id"]
  user_id = request.body["user_id"] || 0

  Tina4::Router.push_to_websocket("/ws/notifications/#{user_id}", JSON.generate({
    type: "notification",
    title: "Order Shipped",
    message: "Your order ##{order_id} has been shipped!",
    action_url: "/orders/#{order_id}",
    timestamp: Time.now.iso8601
  }))

  response.json({ message: "Order shipped, user notified" })
end
```

---

## 10. Connecting from JavaScript

### Using Plain WebSocket

The browser's built-in `WebSocket` API is all you need:

```html
<script>
    const ws = new WebSocket("ws://" + location.host + "/ws/chat/general");

    ws.onopen = function () {
        console.log("Connected to chat");
    };

    ws.onmessage = function (event) {
        const message = JSON.parse(event.data);
        console.log("Received:", message);
    };

    ws.onclose = function () {
        console.log("Disconnected from chat");
    };

    function sendMessage(text) {
        ws.send(JSON.stringify({ type: "message", text: text }));
    }
</script>
```

### Using Frond.js

Tina4's Frond helper wraps WebSocket with convenience features:

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
    });

    ws.on("close", function () {
        console.log("Disconnected from chat");
    });

    function sendMessage(text) {
        ws.send(JSON.stringify({ type: "message", text: text }));
    }
</script>
```

### Auto-Reconnect

```javascript
const ws = frond.ws("/ws/notifications/42", {
    reconnect: true,
    reconnectInterval: 3000,
    maxReconnectAttempts: 10
});
```

---

## 11. A Complete Chat Page

Create `src/templates/chat.html`:

```html
{% extends "base.html" %}

{% block title %}Chat - {{ room }}{% endblock %}

{% block content %}
    <h1>Chat Room: {{ room }}</h1>
    <p id="status">Connecting...</p>
    <p id="online">Online: 0</p>

    <div id="messages" style="border: 1px solid #ddd; height: 400px; overflow-y: scroll; padding: 12px; margin-bottom: 12px; border-radius: 8px;"></div>

    <form id="chat-form" style="display: flex; gap: 8px;">
        <input type="text" id="message-input" placeholder="Type a message..."
               style="flex: 1; padding: 8px; border: 1px solid #ddd; border-radius: 4px;">
        <button type="submit" style="padding: 8px 16px; background: #333; color: white; border: none; border-radius: 4px;">Send</button>
    </form>

    <script>
        const room = "{{ room }}";
        const ws = new WebSocket("ws://" + location.host + "/ws/livechat/" + room);
        const messagesDiv = document.getElementById("messages");
        let username = prompt("Enter your username:") || "Anonymous";

        ws.onopen = function () {
            document.getElementById("status").textContent = "Connected";
            ws.send(JSON.stringify({ type: "set-username", username: username }));
        };

        ws.onmessage = function (event) {
            const msg = JSON.parse(event.data);
            const div = document.createElement("div");
            div.style.marginBottom = "8px";

            if (msg.type === "message") {
                div.innerHTML = "<strong>" + msg.from + ":</strong> " + msg.text;
            } else if (msg.type === "system") {
                div.style.cssText = "color: #888; font-style: italic;";
                div.textContent = msg.message;
            }

            messagesDiv.appendChild(div);
            messagesDiv.scrollTop = messagesDiv.scrollHeight;

            if (msg.online !== undefined) {
                document.getElementById("online").textContent = "Online: " + msg.online;
            }
        };

        ws.onclose = function () {
            document.getElementById("status").textContent = "Disconnected";
        };

        document.getElementById("chat-form").addEventListener("submit", function (e) {
            e.preventDefault();
            const input = document.getElementById("message-input");
            if (input.value.trim()) {
                ws.send(JSON.stringify({ type: "message", text: input.value }));
                input.value = "";
            }
        });
    </script>
{% endblock %}
```

Create the route:

```ruby
Tina4::Router.get("/chat/{room}") do |request, response|
  room = request.params["room"]
  response.render("chat.html", { room: room })
end
```

---

## 12. Server Compatibility

WebSocket works with both Puma and WEBrick. Tina4 detects the available server and sets up WebSocket handling automatically:

| Server  | Notes                                                     |
|---------|-----------------------------------------------------------|
| Puma    | Recommended for production. Handles concurrent connections efficiently. |
| WEBrick | Ships with Ruby. Good for development and testing.        |

For production deployments behind Nginx, configure WebSocket proxying:

```nginx
location /ws/ {
    proxy_pass http://127.0.0.1:7147;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

---

## 13. Exercise: Build a Real-Time Chat Room

Build a WebSocket chat room with username support, message broadcasting, and join/leave notifications.

### Requirements

1. WebSocket endpoint at `/ws/room/{room_name}` that handles `:open`, `:message`, and `:close` events
2. HTTP endpoint at `GET /room/{room_name}` that serves an HTML chat page
3. The chat page should prompt for a username, display messages in real time, and show online count

### Test by:

1. Open `http://localhost:7147/room/test` in two browser tabs
2. Set different usernames
3. Send messages from both tabs and verify they appear in both
4. Close one tab and verify the "user left" message appears

---

## 14. Solution

Create `src/routes/chat_room.rb`:

```ruby
$room_users = {}

Tina4::Router.websocket "/ws/room/{room_name}" do |connection, event, data|
  room = connection.params["room_name"]
  key = "#{room}:#{connection.id}"

  case event
  when :open
    $room_users[key] = "Anonymous"

    connection.send(JSON.generate({
      type: "system",
      message: "Welcome to room: #{room}",
      online: connection.connection_count
    }))

    connection.broadcast(JSON.generate({
      type: "system",
      message: "A new user joined",
      online: connection.connection_count
    }), true)

  when :message
    msg = JSON.parse(data)
    type = msg["type"] || "chat"

    if type == "set-name"
      old_name = $room_users[key] || "Anonymous"
      new_name = msg["name"] || "Anonymous"
      $room_users[key] = new_name

      connection.broadcast(JSON.generate({
        type: "system",
        message: "#{old_name} changed their name to #{new_name}"
      }))
    end

    if type == "chat"
      username = $room_users[key] || "Anonymous"

      connection.broadcast(JSON.generate({
        type: "chat",
        from: username,
        text: msg["text"] || "",
        timestamp: Time.now.strftime("%H:%M:%S")
      }))
    end

  when :close
    username = $room_users[key] || "Anonymous"
    $room_users.delete(key)

    connection.broadcast(JSON.generate({
      type: "system",
      message: "#{username} left the room",
      online: connection.connection_count
    }))
  end
end

Tina4::Router.get("/room/{room_name}") do |request, response|
  room = request.params["room_name"]
  response.render("room.html", { room: room })
end
```

---

## 15. Scaling with a Backplane

When you run a single server instance, `broadcast` reaches every connected client. But in production you often run multiple instances behind a load balancer. Each instance only knows about its own connections. A message broadcast on instance A never reaches clients connected to instance B.

A backplane solves this. It relays WebSocket messages across all instances using a shared pub/sub channel. Tina4 supports Redis as a backplane out of the box.

### Configuration

Set two environment variables in your `.env`:

```bash
TINA4_WS_BACKPLANE=redis
TINA4_WS_BACKPLANE_URL=redis://localhost:6379
```

When `TINA4_WS_BACKPLANE` is set, every `broadcast` call publishes the message to Redis. Every instance subscribes to the same channel and forwards the message to its local connections. No code changes required -- your existing WebSocket routes work as before.

### Requirements

The Redis backplane requires a Redis client gem as an optional dependency:

```bash
gem install redis
```

If `TINA4_WS_BACKPLANE` is not set (the default), Tina4 broadcasts only to local connections. This is fine for single-instance deployments.

---

## 16. Securing a WebSocket Route

A WebSocket route is **public by default** -- exactly like a `GET` route. Anyone can connect. That is the right default for a public chat or a live ticker. When a channel carries private data, mark the route secured and Tina4 enforces a valid JWT *on the upgrade itself* -- before the handshake completes, before any frame flows.

Mark a route secured one of two ways, both equivalent (they set the same flag):

```ruby
# Declarative -- the secure_websocket sibling of secure_get / secure_post
Tina4::Router.secure_websocket "/ws/inbox" do |connection, event, data|
  case event
  when :open
    # connection.auth holds the verified token payload
    connection.send_json({ welcome: connection.auth["user_id"] })
  when :message
    connection.send(data)
  end
end

# Imperative -- chain .secure on a normal websocket route
Tina4::Router.websocket("/ws/inbox") do |connection, event, data|
  # ...
end.secure
```

On a secured route, Tina4 extracts a token, validates it with the same `Tina4::Auth.valid_token` your HTTP routes use, and **rejects the upgrade with `401` (it never accepts the handshake)** when the token is missing or invalid. A public route always passes -- so adding this feature breaks nothing that already worked.

### Sending the token -- three transports

The client can present the JWT three ways. Tina4 checks them in this order:

**1. Authorization header (servers, CLI tools, mobile clients):**

```ruby
require "faye/websocket" # or any client that can set headers
ws = Faye::WebSocket::Client.new(
  "ws://localhost:7147/ws/inbox",
  nil,
  headers: { "Authorization" => "Bearer #{token}" }
)
```

**2. The `bearer` subprotocol (browsers):**

A browser's `new WebSocket()` cannot set request headers -- but it *can* offer subprotocols. Pass `['bearer', token]` and Tina4 reads the token from the `Sec-WebSocket-Protocol` header. When you do, Tina4 **echoes `bearer` back** as the accepted subprotocol so the browser's handshake succeeds:

```javascript
const ws = new WebSocket("ws://localhost:7147/ws/inbox", ["bearer", token]);
```

**3. The `?token=` query parameter (fallback):**

```javascript
const ws = new WebSocket(`ws://localhost:7147/ws/inbox?token=${token}`);
```

### Reading the verified payload

Once the upgrade is accepted, the decoded token payload is on `connection.auth` (a Hash). On a public route it is `nil`. Use it to scope the connection to a user:

```ruby
Tina4::Router.secure_websocket "/ws/inbox" do |connection, event, data|
  case event
  when :open
    user_id = connection.auth["user_id"]
    connection.join_room("user-#{user_id}")
  when :close
    # cleanup
  end
end
```

The origin allow-list (`TINA4_WS_ALLOWED_ORIGINS`) still applies first -- a rejected origin never reaches the auth check. Auth is the per-route control; the origin list is the per-deployment control. Use both.

---

## 17. Gotchas

### 1. WebSocket Needs a Persistent Server

**Problem:** WebSocket connections drop immediately.

**Fix:** Use `tina4 serve` which runs a persistent server. For production with Puma, configure WebSocket proxying with Nginx.

### 2. Events Are Symbols, Not Strings

**Problem:** Your handler never matches any events.

**Fix:** Use symbols (`:open`, `:message`, `:close`), not strings (`"open"`, `"message"`, `"close"`).

### 3. Messages Are Strings, Not Objects

**Problem:** `data` in the message handler is a string, not a Ruby hash.

**Fix:** Always `JSON.parse(data)` when you expect JSON messages. Always `JSON.generate(...)` when you send structured data.

### 4. Connection Count Is Per-Path

**Problem:** `connection.connection_count` returns a lower number than expected.

**Cause:** Connection count is scoped to the WebSocket path. Clients on `/ws/chat/room-1` and `/ws/chat/room-2` are counted separately.

### 5. Broadcasting Does Not Scale Across Servers

**Problem:** Users connected to different server instances do not see each other's messages.

**Fix:** Use a pub/sub backend like Redis to relay messages across server instances.

### 6. Large Messages Cause Disconnects

**Problem:** The connection drops when sending a large message.

**Fix:** Keep messages small (under 64KB). Use HTTP endpoints for bulk data transfer.

### 7. Memory Leak from Tracking Connected Users

**Problem:** The server's memory usage grows over time.

**Fix:** Always clean up in the `:close` handler: `$chat_users.delete(connection.id)`.

### 8. No Authentication on WebSocket Connect

**Problem:** Anyone can connect to your WebSocket endpoint.

**Fix:** Mark the route secured -- `Tina4::Router.secure_websocket "/ws/chat"` (or chain `.secure`). Tina4 then enforces a valid JWT on the upgrade and rejects the handshake with `401` when the token is missing or invalid. The client sends the token via the `Authorization: Bearer` header, the `['bearer', token]` subprotocol (browsers), or `?token=`. The verified payload lands on `connection.auth`. See [Securing a WebSocket Route](#_16-securing-a-websocket-route). Don't hand-roll the check in the `:open` handler -- by then the handshake is already accepted.
