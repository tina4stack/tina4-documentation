# frond.js – Client-Side Helper

::: tip
- frond.js is a drop-in replacement for tina4helper.js with zero dependencies
- Use `saveForm` to post data from an HTML form to a REST endpoint, including file uploads
- Includes a built-in `ReconnectingWebSocket` for real-time features
- Include `formToken` in every form for CSRF protection
:::

Include it once in your base template:

```html
<script src="/js/frond.min.js"></script>
```

---

### Features at a Glance

| Feature                     | Status |
|-----------------------------|--------|
| Automatic `formToken` refresh & injection | Works |
| Full CSRF protection        | Works |
| File uploads (single + multiple) | Works |
| Partial HTML replacement + script re-execution | Works |
| Bootstrap 5 alert messages  | Works |
| ReconnectingWebSocket       | Works |
| Works with all Tina4 backends (Python, PHP, Ruby, Node.js) | Works |

---

## Core Functions

### `saveForm(formId, url, targetElement, callback)`

**The most used function** — submits a form securely. Use the targetElement to insert the response into your HTML, OR run a callback function.

```js
saveForm("loginForm", "/login", "message", function(content, status) {
    loadPage("/dashboard", "content");
});
```

### `postForm()` / `submitForm()`

Exact aliases of `saveForm()`:

```js
postForm("userForm", "/users", "content");
submitForm("contact", "/contact", "message");
```

### `loadPage(url, targetElement = "content", callback)`

Load any route into a div — perfect for SPA-style navigation.

```js
loadPage("/users", "content");
loadPage("/profile", "main", () => console.log("Loaded!"));
```

### `showForm(action, url, targetElement = "form")`

Smart CRUD helper:

```js
showForm("create", "/articles/create", "form");   // GET
showForm("edit",   "/articles/42/edit", "form");   // GET
showForm("delete", "/articles/42/delete", "form"); // DELETE
```

### `showMessage("Success!")`

Bootstrap 5 alert inserted into the "message" HTML element.

```js
showMessage("User created successfully!");
```

### `getRoute(url, callback)`

Simple GET request with callback:

```js
getRoute("/api/users", function(content, status, xhr) {
    console.log(JSON.parse(content));
});
```

### `postUrl(url, data, targetElement, callback)`

POST data to a URL:

```js
postUrl("/api/users", { name: "John" }, "result");
```

---

## Automatic Form Token Handling

frond.js declares a global `formToken` variable:

```js
var formToken = null;   // Filled automatically from FreshToken header
```

The following functions automatically update `formToken` from the `FreshToken` response header:

```js
loadPage(...);
showForm(...);
postUrl(...);
getRoute(...);
```

## File Uploads

```html
<form id="upload" enctype="multipart/form-data">
    <input type="hidden" name="formToken" value="">
    <input type="file" name="files[]" multiple>
    <button onclick="saveForm('upload', '/upload', 'message'); return false;">
        Upload
    </button>
</form>
```

Supports:
- Multiple files
- Correct `[]` naming
- Automatic token refresh
- Proper multipart content-type handling

---

## ReconnectingWebSocket

frond.js includes a built-in reconnecting WebSocket client:

```js
var ws = new ReconnectingWebSocket("ws://localhost:7145/ws");

ws.onopen = function() {
    console.log("Connected");
};

ws.onmessage = function(event) {
    console.log("Received:", event.data);
};

ws.onclose = function() {
    console.log("Disconnected — will auto-reconnect");
};
```

Features:
- Automatic reconnection with exponential backoff
- Configurable max reconnect attempts
- Drop-in replacement for native `WebSocket`

---

## Recommended Base Layout

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>My Tina4 App</title>
    <link href="/css/tina4.min.css" rel="stylesheet">
    <link href="/css/default.css" rel="stylesheet">
</head>
<body>
    <div id="content">Loading...</div>
    <div id="message"></div>

    <script src="/js/tina4.js"></script>
    <script src="/js/frond.min.js"></script>

    <script>
        document.addEventListener("DOMContentLoaded", () => {
            loadPage(location.pathname + location.search, "content");
        });
    </script>
</body>
</html>
```

---

### One-liner CRUD Example

```js
// List
loadPage("/products", "content");

// Add new
showForm("create", "/products/create", "form");

// Save
saveForm("productForm", "/products", "message", (content, status) => {
    showMessage("Saved!");
    loadPage("/products", "content");
});
```

---

::: info Migration from tina4helper.js
frond.js is a drop-in replacement. Simply change your script include from `/js/tina4helper.js` to `/js/frond.min.js`. All existing function calls will work without changes. The callback signature for `sendRequest` is enhanced — it now passes `(content, status, xhr)` instead of just `(content)`.
:::
