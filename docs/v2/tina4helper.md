# Tina4 JavaScript Helper

::: tip 🔥 Hot Tips
- tina4helper.js does not require jquery or other libraries to work!  
- Use `saveForm` to post data from a html form to a REST end point, this includes files.
- Add the latest boostrap to your page to get nice messages and alerts.
- Include `formToken` in every form for direct posts.
:::
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

**The #1 most used function** – submits a form securely. Mutually exclusive response options. Use the targetElement to 
insert the response into your HTML, OR run a callback function. 

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

Beautiful Bootstrap 5 alert inserted into the "message" html element.

```js
showMessage("User created successfully!");
```

---

## Automatic Form Token Handling
The first line in Tina4Helper.js declares the `formToken` variable.
```js
var formToken = null;   // Filled automatically from FreshToken header
```

The following requests will return a `FreshToken` header which automatically updates the global `formToken` variable,
even on dynamic forms loaded via `loadPage()`.
```js
loadPage(...);
showForm(...);
postUrl(...);
getRoute(...);
```

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

