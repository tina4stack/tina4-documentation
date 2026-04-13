# frond.js — Client-Side Helper

A zero-dependency DOM helper for AJAX, forms, WebSocket, SSE, cookies, and GraphQL. Ships with every Tina4 backend and tina4-css. Under 3KB gzipped.

Include it once in your base template:

```html
<script src="/js/frond.min.js"></script>
```

Every method is available on the global `window.frond` object.

---

## API Reference

### frond.request(url, options)

Core HTTP request with automatic Bearer token and CSRF token handling.

```js
frond.request("/api/users", {
    method: "GET",
    onSuccess: function(data, status, xhr) {
        console.log(data);
    },
    onError: function(status, xhr) {
        console.error("Failed:", status);
    }
});
```

Shorthand with callback:

```js
frond.request("/api/users", function(data) {
    console.log(data);
});
```

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `method` | `string` | HTTP method (default: `"GET"`) |
| `body` | `object\|FormData\|string` | Request body — objects become JSON, FormData stays multipart |
| `headers` | `object` | Extra headers |
| `onSuccess` | `function(data, status, xhr)` | Success callback (2xx/3xx) |
| `onError` | `function(status, xhr)` | Error callback (4xx/5xx) |

**Automatic features:**
- Sends `Authorization: Bearer <token>` when `frond.token` is set
- Reads `FreshToken` response header and updates `frond.token` automatically
- Detects XHR-followed redirects (3xx) and navigates the browser

---

### frond.load(url, target, callback)

GET a URL and inject the HTML response into a target element.

```js
frond.load("/dashboard", "content");
frond.load("/profile", "main", function(html, raw) {
    console.log("Loaded");
});
```

---

### frond.post(url, data, target, callback)

POST data and inject the HTML response into a target element.

```js
frond.post("/api/save", { name: "Alice" }, "message", function(html, raw) {
    console.log("Saved");
});
```

---

### frond.inject(html, targetId)

Parse an HTML string, inject it into an element, and execute any `<script>` tags found in the content.

```js
frond.inject('<div>Hello</div><script>console.log("injected")</script>', "content");
```

Returns the innerHTML if no target is specified.

---

## Forms

### frond.form.collect(formId)

Collect all form fields into a `FormData` object. Handles text inputs, selects, textareas, checkboxes, radio buttons, and file uploads.

```js
var data = frond.form.collect("myForm");
```

If `frond.token` is set and the form contains a `formToken` field, the token value is updated automatically.

### frond.form.submit(formId, url, target, callback)

Collect form data and POST it. The response is injected into the target element.

```js
frond.form.submit("loginForm", "/login", "message", function(html) {
    window.location = "/dashboard";
});
```

This is the primary way to submit forms in Tina4 applications. The button should use `type="button"` with an `onclick` handler:

```html
<form id="loginForm" method="POST" action="/login">
    {{ form_token() }}
    <input type="email" name="email">
    <input type="password" name="password">
    <button type="button" onclick="frond.form.submit('loginForm', '/login', null, function(){ window.location='/dashboard'; })">
        Login
    </button>
</form>
```

### frond.form.show(action, url, target, callback)

Load a form by action type. Maps actions to HTTP methods:

| Action | HTTP Method |
|--------|-------------|
| `"create"` | GET |
| `"edit"` | GET |
| `"delete"` | DELETE |

```js
frond.form.show("create", "/products/new", "form");
frond.form.show("edit", "/products/42/edit", "form");
frond.form.show("delete", "/products/42", "form");
```

---

## WebSocket

### frond.ws(url, options)

Connect to a WebSocket endpoint with automatic reconnection.

```js
var conn = frond.ws("ws://localhost:7146/ws/chat", {
    reconnect: true,
    reconnectDelay: 1000,
    maxReconnectDelay: 30000,
    onOpen: function() { console.log("Connected"); },
    onClose: function(code, reason) { console.log("Closed"); },
    onError: function(err) { console.error(err); }
});

// Listen for messages
conn.on("message", function(data) {
    console.log("Received:", data);
});

// Send a message
conn.send({ type: "chat", text: "Hello" });

// Close
conn.close();
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `reconnect` | `boolean` | `true` | Auto-reconnect on disconnect |
| `reconnectDelay` | `number` | `1000` | Initial reconnect delay (ms) |
| `maxReconnectDelay` | `number` | `30000` | Max reconnect delay (exponential backoff) |
| `maxReconnectAttempts` | `number` | `Infinity` | Stop trying after N attempts |
| `protocols` | `string[]` | `[]` | WebSocket sub-protocols |
| `onOpen` | `function` | — | Connection opened |
| `onClose` | `function(code, reason)` | — | Connection closed |
| `onError` | `function(error)` | — | Connection error |

**Connection object:**

| Property/Method | Description |
|----------------|-------------|
| `conn.status` | `"connecting"` / `"open"` / `"reconnecting"` / `"closed"` |
| `conn.send(data)` | Send string or object (auto-stringified) |
| `conn.on(event, fn)` | Listen for `"message"`, `"open"`, `"close"`, `"error"` |
| `conn.close(code?, reason?)` | Close the connection |

---

## Server-Sent Events (SSE)

### frond.sse(url, options)

Connect to an SSE endpoint with automatic reconnection.

```js
var stream = frond.sse("/api/sse/sales", {
    events: ["order", "stock"],
    json: true,
    onOpen: function() { console.log("Stream open"); }
});

stream.on("message", function(data, eventName) {
    console.log(eventName, data);
});

stream.close();
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `reconnect` | `boolean` | `true` | Auto-reconnect |
| `events` | `string[]` | `[]` | Named events to listen for |
| `json` | `boolean` | `true` | Auto-parse JSON data |
| `onOpen` | `function` | — | Stream opened |
| `onClose` | `function` | — | Stream closed |
| `onError` | `function(error)` | — | Stream error |

---

## Cookies

### frond.cookie

```js
frond.cookie.set("theme", "dark", 30);    // Set cookie, expires in 30 days
frond.cookie.get("theme");                 // "dark"
frond.cookie.remove("theme");              // Delete cookie
```

---

## Utility

### frond.message(text, type)

Display a Bootstrap-style alert in the `#message` element.

```js
frond.message("User created!", "success");
frond.message("Something went wrong", "danger");
```

### frond.popup(url, title, width, height)

Open a centred popup window.

```js
frond.popup("/preview", "Preview", 800, 600);
```

### frond.report(url)

Open a URL (typically a PDF) in a new browser tab.

```js
frond.report("/api/reports/monthly.pdf");
```

---

## GraphQL

### frond.graphql(url, query, variables, options)

Execute a GraphQL query or mutation.

```js
frond.graphql("/api/graphql", "{ products { id name price } }", {}, {
    onSuccess: function(result) {
        console.log(result.data);
        if (result.errors) console.warn(result.errors);
    }
});
```

With variables:

```js
frond.graphql("/api/graphql",
    'query ($term: String!) { search(term: $term) { id name } }',
    { term: "widget" },
    function(result) {
        console.log(result.data.search);
    }
);
```

---

## Token Management

### frond.token

Read or write the Bearer token. When set, every `frond.request()` call includes `Authorization: Bearer <token>`.

```js
// Set after login
frond.token = "eyJhbGciOiJIUzI1NiIs...";

// Read
console.log(frond.token);

// Clear on logout
frond.token = null;
```

Token rotation is automatic — if a response includes a `FreshToken` header, `frond.token` updates to the new value.

---

## File Uploads

Use `frond.form.submit()` with a form containing file inputs. FormData handles multipart encoding automatically.

```html
<form id="uploadForm">
    {{ form_token() }}
    <input type="file" name="avatar">
    <button type="button" onclick="frond.form.submit('uploadForm', '/api/upload', 'message')">
        Upload
    </button>
</form>
```

Multiple files:

```html
<input type="file" name="files[]" multiple>
```

---

## Quick Reference

| Method | Description |
|--------|-------------|
| `frond.request(url, opts)` | Core HTTP with auth + token rotation |
| `frond.load(url, target, cb)` | GET + inject HTML |
| `frond.post(url, data, target, cb)` | POST + inject HTML |
| `frond.inject(html, target)` | Parse HTML + run scripts |
| `frond.form.collect(formId)` | Collect FormData |
| `frond.form.submit(formId, url, target, cb)` | POST form |
| `frond.form.show(action, url, target, cb)` | Load form by CRUD action |
| `frond.ws(url, opts)` | WebSocket with reconnect |
| `frond.sse(url, opts)` | SSE with reconnect |
| `frond.cookie.set/get/remove` | Cookie helpers |
| `frond.message(text, type)` | Alert display |
| `frond.popup(url, title, w, h)` | Centred popup |
| `frond.report(url)` | Open PDF |
| `frond.graphql(url, query, vars, opts)` | GraphQL query/mutation |
| `frond.token` | Bearer token (read/write) |
