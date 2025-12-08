# Tina4 JavaScript Helper

`tina4helper.js` is the **lightweight, zero-dependency JavaScript companion** that turns any Tina4 Python (or PHP) project into a **fast, secure, SPA-like experience** — with **automatic CSRF protection**, form handling, file uploads, and partial page updates.

Just include it once:

```html
<script src="/js/tina4helper.js"></script>
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
| Works with Tina4 Python & PHP | Works |

---

## Core Functions

### `saveForm(formId, url, targetElement, callback)`

**The #1 most used function** – submits a form securely.

```js
saveForm("loginForm", "/login", "message", function() {
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

Load any route into a div – perfect for navigation.

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

Beautiful Bootstrap 5 alert:

```js
showMessage("User created successfully!");
```

---

## Automatic Form Token Handling

```js
var formToken = null;   // Filled automatically from FreshToken header
```

Every successful request that returns a `FreshToken` header:
- Updates the global `formToken`
- **Automatically refreshes** every `<input name="formToken">` in your forms

Just include the token once in your template:

```twig
{{ form_token() }}
```

`tina4helper.js` does the rest — even on dynamic forms loaded via `loadPage()`.

---

## File Uploads – Zero Effort

```html
<form id="upload" enctype="multipart/form-data">
    {{ form_token() }}
    <input type="file" name="files[]" multiple>
    <button onclick="saveForm('upload', '/upload', 'message'); return false;">
        Upload
    </button>
</form>
```

Supports:
- Multiple files
- Correct `[]` naming
- Token refresh
- Progress? (future)

---

## Recommended Base Layout

```twig
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>My Tina4 App</title>
    <link href="/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- Optional: expose token for JS -->
    <meta name="csrf-token" content="{{ form_token() }}">
</head>
<body>
    <div id="content">Loading...</div>
    <div id="message"></div>

    <!-- Load the helper -->
    <script src="/js/tina4helper.js"></script>

    <script>
        // Optional: preload token from meta tag
        const metaToken = document.querySelector('meta[name="csrf-token"]');
        if (metaToken) formToken = metaToken.content;

        // Auto-load current page on start
        document.addEventListener("DOMContentLoaded", () => {
            loadPage(location.pathname + location.search, "content");
        });
    </script>
</body>
</html>
```

Now your entire site feels like a modern SPA — **with zero JavaScript framework overhead**.

---

## Hot Tips – tina4helper.js Best Practices

::: tip 🔥 Hot Tips – Remember These!
- Always use `saveForm()` — it handles tokens, files, and feedback
- Include `formToken` in every form
  :::

### One-liner CRUD Example

```js
// List
loadPage("/products", "content");

// Add new
showForm("create", "/products/create", "form");

// Save
saveForm("productForm", "/products", "message", () => {
    showMessage("Saved!");
    loadPage("/products", "content");
});
```

