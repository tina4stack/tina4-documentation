# Chapter 24: Server-Sent Events (SSE)

## 1. The Polling Problem

Your monitoring dashboard needs live metrics. CPU usage. Memory. Active connections. The numbers change every few seconds.

The obvious solution: poll. A timer fires every three seconds. The browser sends a GET request. The server queries the database. The server responds. The browser updates the page. Repeat.

That works. It also wastes resources. Nineteen out of twenty polls return the same data. Each one opens a connection, sends headers, waits for a response, and closes the connection. The server does the same work whether the data changed or not.

WebSocket solves this. A persistent, bi-directional connection. The server pushes when data changes. But WebSocket is designed for two-way communication. Chat rooms. Collaborative editing. Live gaming. Your dashboard only needs one direction: server to client.

Server-Sent Events (SSE) is the middle ground. One-way streaming over plain HTTP. The server pushes. The client listens. The browser reconnects automatically if the connection drops. No upgrade handshake. No special protocol. Just HTTP with a twist.

---

## 2. What SSE Is

HTTP works like this:

```
Client: "Give me /api/metrics"
Server: "Here are the metrics" (connection closes)
Client: "Give me /api/metrics" (new connection, 3 seconds later)
Server: "Here are the metrics" (connection closes)
```

WebSocket works like this:

```
Client: "Upgrade to WebSocket on /ws/metrics"
Server: "Upgrade accepted. Connection open."
Client: "Subscribe to CPU metrics"
Server: "CPU: 42%"
Server: "CPU: 38%"  (pushed at any time)
Client: "Unsubscribe"
```

SSE works like this:

```
Client: "Give me /events (keep the connection open)"
Server: "data: CPU 42%"
Server: "data: CPU 38%"  (pushed, no client request)
Server: "data: CPU 45%"  (keeps flowing)
Client: (just listens)
```

The key differences:

| Feature | HTTP Polling | WebSocket | SSE |
|---------|-------------|-----------|-----|
| Direction | Client to server | Both ways | Server to client |
| Connection | New each time | Persistent | Persistent |
| Protocol | HTTP | WebSocket (upgrade) | HTTP |
| Auto-reconnect | No | No (manual) | Yes (built-in) |
| Binary data | Yes | Yes | No (text only) |
| Browser support | Universal | Universal | Universal (except IE) |
| Complexity | Simple | Moderate | Simple |

SSE uses plain HTTP. No protocol upgrade. No special server support. The server sets `Content-Type: text/event-stream` and keeps the connection open. The browser's `EventSource` API handles reconnection, event parsing, and last-event-ID tracking.

---

## 3. Your First Stream

Create `src/routes/events.php`:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/events", function (Request $request, Response $response) {
    $generator = function () {
        for ($i = 0; $i < 10; $i++) {
            yield "data: " . json_encode(["count" => $i, "message" => "tick"]) . "\n\n";
            sleep(1);
        }
        yield "data: " . json_encode(["done" => true]) . "\n\n";
    };

    return $response->stream($generator);
});
```

Three things happen here:

1. `$generator` is a closure that returns a PHP generator. Each `yield` produces one SSE message.
2. `$response->stream()` tells Tina4 to keep the connection open and send each chunk as the generator yields it.
3. The framework sets `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`, and `X-Accel-Buffering: no` for you.

Start the server and test with curl:

```bash
curl -N http://localhost:7145/events
```

You see one message per second:

```
data: {"count":0,"message":"tick"}

data: {"count":1,"message":"tick"}

data: {"count":2,"message":"tick"}
```

Each message arrives the moment the server yields it. No buffering. No waiting for the full response.

---

## 4. The SSE Protocol

SSE messages are plain text with a simple format. Each message is one or more field lines followed by a blank line.

### The `data:` Field

The most common field. Contains the message payload.

```
data: Hello, world

```

Multiple `data:` lines in one message get joined with newlines:

```
data: line one
data: line two

```

The client receives this as `"line one\nline two"`.

### The `event:` Field

Names the event type. Without it, the browser fires `onmessage`. With it, the browser fires a named event listener.

```php
yield "event: metrics\ndata: " . json_encode(["cpu" => 42]) . "\n\n";
yield "event: alert\ndata: " . json_encode(["level" => "high", "message" => "CPU spike"]) . "\n\n";
```

On the client:

```javascript
source.addEventListener("metrics", (e) => {
    const data = JSON.parse(e.data);
    updateDashboard(data);
});

source.addEventListener("alert", (e) => {
    const data = JSON.parse(e.data);
    showAlert(data.message);
});
```

Named events let you multiplex different data types on a single connection.

### The `id:` Field

Sets the last event ID. If the connection drops, the browser sends `Last-Event-ID` in the reconnection request. Your server can resume from where it left off.

```php
yield "id: {$i}\ndata: " . json_encode(["count" => $i]) . "\n\n";
```

### The `retry:` Field

Tells the browser how many milliseconds to wait before reconnecting after a disconnect.

```php
yield "retry: 5000\n\n"; // reconnect after 5 seconds
```

### The Delimiter

Every SSE message ends with two newlines: `\n\n`. This tells the browser that the message is complete. A single `\n` separates fields within one message.

```php
// One complete SSE message:
yield "event: update\nid: 42\ndata: " . json_encode(["value" => 100]) . "\n\n";

// Broken down:
// event: update\n        <- event type
// id: 42\n               <- event ID
// data: {"value":100}\n  <- payload
// \n                     <- end of message (blank line)
```

---

## 5. Frontend: EventSource

The browser provides `EventSource` for consuming SSE streams. It handles connection management, reconnection, and message parsing.

### Basic Usage

```javascript
const source = new EventSource("/events");

source.onmessage = function (event) {
    const data = JSON.parse(event.data);
    console.log("Received:", data);
};

source.onerror = function () {
    console.log("Connection lost. Reconnecting...");
};

source.onopen = function () {
    console.log("Connected");
};
```

`EventSource` reconnects automatically when the connection drops. The `onerror` handler fires, the browser waits (default 3 seconds), then reconnects. Your server receives a new request with the `Last-Event-ID` header if you sent event IDs.

### Named Events

```javascript
const source = new EventSource("/events");

source.addEventListener("metrics", function (event) {
    updateChart(JSON.parse(event.data));
});

source.addEventListener("notification", function (event) {
    showToast(JSON.parse(event.data));
});

source.addEventListener("heartbeat", function (event) {
    // Connection is alive
});
```

### Closing the Connection

```javascript
source.close();
```

The browser stops reconnecting. The server receives a client disconnect.

### With Authentication

`EventSource` does not support custom headers. Pass tokens as query parameters:

```javascript
const token = getAuthToken();
const source = new EventSource(`/events?token=${token}`);
```

On the server:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;
use Tina4\Auth;

Router::get("/events", function (Request $request, Response $response) {
    $token = $request->query["token"] ?? "";
    $payload = Auth::validToken($token);
    if (!$payload) {
        return $response->json(["error" => "Unauthorized"], 401);
    }

    $generator = function () use ($payload) {
        while (true) {
            yield "data: " . json_encode(["user" => $payload["email"]]) . "\n\n";
            sleep(5);
        }
    };

    return $response->stream($generator);
});
```

---

## 6. Real Examples

### Live Dashboard

Stream database metrics every five seconds:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;
use Tina4\Database\Database;

Router::get("/events/dashboard", function (Request $request, Response $response) {
    $generator = function () {
        $db = Database::fromEnv();
        while (true) {
            $orders = $db->fetch("SELECT count(*) as total FROM orders")->records[0] ?? ["total" => 0];
            $revenue = $db->fetch("SELECT sum(total) as revenue FROM orders WHERE date(created_at) = date('now')")->records[0] ?? ["revenue" => 0];

            yield "data: " . json_encode([
                "orders" => (int) $orders["total"],
                "revenue" => (float) ($revenue["revenue"] ?? 0),
            ]) . "\n\n";
            sleep(5);
        }
    };

    return $response->stream($generator);
});
```

The client updates the dashboard numbers without polling. One connection. One query every five seconds. No wasted requests.

### Build Progress

Stream deployment status as it happens:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/events/deploy/{buildId}", function (Request $request, Response $response, string $buildId) {
    $generator = function () use ($buildId) {
        $steps = [
            ["pull", "Pulling latest code..."],
            ["install", "Installing dependencies..."],
            ["test", "Running tests..."],
            ["build", "Building application..."],
            ["deploy", "Deploying to production..."],
            ["done", "Deployment complete"],
        ];

        foreach ($steps as [$step, $message]) {
            yield "event: progress\ndata: " . json_encode([
                "step" => $step,
                "message" => $message,
                "build_id" => $buildId,
            ]) . "\n\n";
            sleep(2); // simulate work
        }
    };

    return $response->stream($generator);
});
```

The browser shows a progress bar that updates in real time. Each step arrives as it completes. The user watches the deployment unfold instead of staring at a spinner.

### LLM Chat Streaming

Stream AI responses token by token. This is how ChatGPT works:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/events/chat", function (Request $request, Response $response) {
    $prompt = $request->query["q"] ?? "Hello";

    $generator = function () use ($prompt) {
        // Call the LLM API with streaming enabled
        $body = json_encode([
            "model" => "claude-sonnet-4-20250514",
            "max_tokens" => 512,
            "stream" => true,
            "messages" => [["role" => "user", "content" => $prompt]],
        ]);

        $context = stream_context_create([
            "http" => [
                "method" => "POST",
                "header" => implode("\r\n", [
                    "Content-Type: application/json",
                    "x-api-key: " . getenv("ANTHROPIC_API_KEY"),
                    "anthropic-version: 2023-06-01",
                ]),
                "content" => $body,
            ],
        ]);

        $stream = fopen("https://api.anthropic.com/v1/messages", "r", false, $context);
        while (!feof($stream)) {
            $line = trim(fgets($stream));
            if (str_starts_with($line, "data: ")) {
                $chunk = json_decode(substr($line, 6), true);
                if (($chunk["type"] ?? "") === "content_block_delta") {
                    $text = $chunk["delta"]["text"] ?? "";
                    yield "data: " . json_encode(["token" => $text]) . "\n\n";
                }
            }
        }
        fclose($stream);

        yield "data: " . json_encode(["done" => true]) . "\n\n";
    };

    return $response->stream($generator);
});
```

The frontend appends each token as it arrives:

```javascript
const source = new EventSource(`/events/chat?q=${encodeURIComponent(question)}`);
const output = document.getElementById("response");

source.onmessage = function (event) {
    const data = JSON.parse(event.data);
    if (data.done) {
        source.close();
        return;
    }
    output.textContent += data.token;
};
```

The response builds character by character. The user reads as the AI writes. No waiting for the full answer.

### File Processing Progress

Upload a CSV, stream the processing status:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::post("/api/import", function (Request $request, Response $response) {
    $file = $request->files["csv"] ?? null;
    if (!$file) {
        return $response->json(["error" => "No file"], 400);
    }

    $lines = explode("\n", trim($file["content"]));
    $total = count($lines) - 1; // minus header

    $generator = function () use ($lines, $total) {
        $rows = array_slice($lines, 1);
        foreach ($rows as $i => $line) {
            // Process each row
            $cols = explode(",", $line);
            // ... insert into database ...
            $processed = $i + 1;
            yield "data: " . json_encode([
                "processed" => $processed,
                "total" => $total,
                "percent" => (int) round($processed / $total * 100),
            ]) . "\n\n";
        }

        yield "data: " . json_encode(["done" => true, "total" => $total]) . "\n\n";
    };

    return $response->stream($generator, "text/event-stream");
});
```

The browser shows a progress bar that fills as each row is processed. The user sees exactly where the import stands.

---

## 7. Custom Content Types

SSE defaults to `text/event-stream`, but `$response->stream()` accepts any content type as the second argument. Use this for newline-delimited JSON (NDJSON), chunked binary, or custom protocols.

### NDJSON Streaming

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;
use Tina4\Database\Database;

Router::get("/api/export", function (Request $request, Response $response) {
    $generator = function () {
        $db = Database::fromEnv();
        $result = $db->fetch("SELECT * FROM products", 1000);
        foreach ($result->records as $row) {
            yield json_encode($row) . "\n";
        }
    };

    return $response->stream($generator, "application/x-ndjson");
});
```

Each line is a complete JSON object. The client reads line by line. No need to parse a giant array. Memory stays flat regardless of how many rows you export.

### Consuming NDJSON on the Client

```javascript
async function streamProducts() {
    const response = await fetch("/api/export");
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop(); // keep incomplete line

        for (const line of lines) {
            if (line.trim()) {
                const product = JSON.parse(line);
                addToTable(product);
            }
        }
    }
}
```

---

## 8. SSE vs WebSocket

Both keep a persistent connection. Both push data in real time. The choice depends on the direction of communication.

| Use Case | Choose | Why |
|----------|--------|-----|
| Live dashboard | SSE | Server pushes metrics. Client only listens. |
| Chat application | WebSocket | Both sides send messages. |
| Notification feed | SSE | Server pushes. Client marks as read via separate HTTP POST. |
| Collaborative editor | WebSocket | Both sides send cursor positions and edits. |
| Build/deploy progress | SSE | Server streams status. Client watches. |
| LLM token streaming | SSE | Server streams tokens. Client displays them. |
| Online gaming | WebSocket | Low-latency, bi-directional input and state. |
| Stock ticker | SSE | Server pushes prices. Client displays. |
| File upload progress | HTTP (native) | Browser tracks upload. Server tracks processing via SSE. |

**Rule of thumb:** If the client only listens, use SSE. If the client sends data back on the same connection, use WebSocket.

SSE has one advantage WebSocket does not: automatic reconnection. The browser's `EventSource` reconnects without any code. WebSocket requires manual reconnection logic (or `frond.js` which handles it for you).

---

## 9. Production Considerations

### Nginx Proxy Buffering

Nginx buffers responses by default. SSE messages accumulate in the buffer and arrive in batches instead of one at a time. Tina4 sets `X-Accel-Buffering: no` on streaming responses, which tells Nginx to disable buffering for that response.

If you configure Nginx manually:

```nginx
location /events/ {
    proxy_pass http://localhost:7145;
    proxy_buffering off;
    proxy_cache off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding off;
}
```

### Connection Limits

Each SSE connection is a persistent HTTP connection. Most servers limit concurrent connections. Tina4's built-in server uses `stream_select()` to multiplex thousands of connections in a single process. In production:

- Monitor open connections
- Set timeouts on long-running streams
- Close streams when the client no longer needs them

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/events/metrics", function (Request $request, Response $response) {
    $generator = function () {
        for ($i = 0; $i < 3600; $i++) { // max 1 hour (one message per second)
            yield "data: " . json_encode(["cpu" => get_cpu()]) . "\n\n";
            sleep(1);
        }
        yield "event: timeout\ndata: " . json_encode(["message" => "Stream expired. Reconnect."]) . "\n\n";
    };

    return $response->stream($generator);
});
```

`$response->stream()` checks `connection_aborted()` after each chunk and breaks the loop when the client disconnects, so dropped clients release their slot immediately.

### Heartbeat Messages

Some proxies and load balancers close idle connections after a timeout (typically 30-60 seconds). Send a heartbeat comment to keep the connection alive:

```php
$generator = function () {
    while (true) {
        if (has_new_data()) {
            yield "data: " . json_encode(get_data()) . "\n\n";
        } else {
            yield ": heartbeat\n\n"; // SSE comment (colon prefix) -- ignored by EventSource
        }
        sleep(5);
    }
};
```

Lines starting with `:` are SSE comments. The browser ignores them, but they keep the connection alive through proxies.

---

## 10. Exercise: Build a Live Metrics Dashboard

Build a dashboard that streams server metrics to the browser.

### Requirements

1. SSE endpoint at `GET /events/server-metrics` that streams every 3 seconds:
   - Current timestamp
   - A random CPU percentage (simulate with `random_int(10, 90)`)
   - A random memory percentage
   - A random request count

2. HTML page at `GET /dashboard` that:
   - Connects to the SSE endpoint
   - Displays the four metrics in cards
   - Updates the values in real time (no page refresh)
   - Shows a "Connected" / "Reconnecting..." status indicator

### Test by:

1. Open `http://localhost:7145/dashboard`
2. Watch the numbers update every 3 seconds
3. Stop the server and verify "Reconnecting..." appears
4. Restart the server and verify it reconnects and resumes updating

---

## 11. Solution

Create `src/routes/server_metrics.php`:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/events/server-metrics", function (Request $request, Response $response) {
    $generator = function () {
        yield "retry: 3000\n\n";
        $counter = 0;
        while (true) {
            $payload = json_encode([
                "timestamp" => gmdate("c"),
                "cpu" => random_int(10, 90),
                "memory" => random_int(30, 85),
                "requests" => random_int(100, 5000),
            ]);
            yield "id: {$counter}\ndata: {$payload}\n\n";
            $counter++;
            sleep(3);
        }
    };

    return $response->stream($generator);
});


Router::get("/dashboard", function (Request $request, Response $response) {
    $html = <<<HTML
    <!DOCTYPE html>
    <html>
    <head><title>Live Dashboard</title></head>
    <body style="font-family: system-ui; max-width: 600px; margin: 40px auto; padding: 0 20px;">
        <h1>Server Metrics</h1>
        <p id="status" style="color: #888;">Connecting...</p>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 20px;">
            <div style="background: #f5f5f5; padding: 20px; border-radius: 8px;">
                <div style="color: #888; font-size: 14px;">CPU</div>
                <div id="cpu" style="font-size: 32px; font-weight: 700;">--</div>
            </div>
            <div style="background: #f5f5f5; padding: 20px; border-radius: 8px;">
                <div style="color: #888; font-size: 14px;">Memory</div>
                <div id="memory" style="font-size: 32px; font-weight: 700;">--</div>
            </div>
            <div style="background: #f5f5f5; padding: 20px; border-radius: 8px;">
                <div style="color: #888; font-size: 14px;">Requests/min</div>
                <div id="requests" style="font-size: 32px; font-weight: 700;">--</div>
            </div>
            <div style="background: #f5f5f5; padding: 20px; border-radius: 8px;">
                <div style="color: #888; font-size: 14px;">Last Update</div>
                <div id="time" style="font-size: 16px; font-weight: 500;">--</div>
            </div>
        </div>
        <script>
            const source = new EventSource("/events/server-metrics");
            const status = document.getElementById("status");

            source.onopen = function () {
                status.textContent = "Connected";
                status.style.color = "#22c55e";
            };

            source.onmessage = function (event) {
                const data = JSON.parse(event.data);
                document.getElementById("cpu").textContent = data.cpu + "%";
                document.getElementById("memory").textContent = data.memory + "%";
                document.getElementById("requests").textContent = data.requests.toLocaleString();
                document.getElementById("time").textContent = new Date(data.timestamp).toLocaleTimeString();
            };

            source.onerror = function () {
                status.textContent = "Reconnecting...";
                status.style.color = "#ef4444";
            };
        </script>
    </body>
    </html>
    HTML;
    return $response->html($html);
});
```

Open `http://localhost:7145/dashboard`. The numbers update every three seconds. Stop the server. The status turns red: "Reconnecting..." Start it again. The status turns green. The numbers resume.

No polling. No WebSocket. No JavaScript timers. The browser handles everything.

---

## 12. What You Learned

- **SSE streams data from server to client** over a single HTTP connection. No upgrade. No special protocol.
- **`$response->stream($generator)`** keeps the connection open and flushes each chunk as the generator yields it.
- **The SSE protocol** uses `data:`, `event:`, `id:`, and `retry:` fields. Messages end with `\n\n`.
- **`EventSource`** on the client handles connection, parsing, and automatic reconnection.
- **Named events** let you multiplex different data types on one stream.
- **Custom content types** let you stream NDJSON, binary, or any format -- pass the type as the second argument to `stream()`.
- **SSE is for one-way server pushes.** Use WebSocket when the client needs to send data back on the same connection.
- **Heartbeat comments** keep connections alive through proxies. Tina4 sets `X-Accel-Buffering: no` to disable nginx buffering and breaks the loop on `connection_aborted()` to release dropped clients.

One direction. One connection. Real-time data. The server speaks. The client listens. The rest is infrastructure.
