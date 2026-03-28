# Chapter 15: Frontend Integration

## 1. Beyond JSON APIs

Your API returns perfect JSON. Now someone has to build the interface.

Tina4 ships two frontend tools: **tina4css** (a utility CSS framework) and **frond.js** (a reactive JavaScript library). Both arrive with every project. No npm installs. No build tools. No webpack.

---

## 2. tina4css -- The Built-In CSS Framework

`tina4.css` lives at `/css/tina4.css`. It delivers layout, typography, buttons, cards, forms, alerts, and utility classes.

### Layout

```html
<div class="container">
    <div class="row">
        <div class="col-6">Left half</div>
        <div class="col-6">Right half</div>
    </div>
</div>
```

### Components

```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-danger">Danger</button>

<div class="card">
    <div class="card-header">Title</div>
    <div class="card-body">Content</div>
</div>

<div class="alert alert-success">Operation completed.</div>
<div class="alert alert-danger">Something went wrong.</div>

<div class="form-group">
    <label for="name">Name</label>
    <input type="text" id="name" class="form-control">
</div>
```

### Utility Classes

```html
<p class="text-center">Centered</p>
<div class="mt-4">Margin top</div>
<div class="p-3">Padding</div>
<span class="text-muted">Gray text</span>
```

---

## 3. frond.js -- Reactive JavaScript

`frond.js` lives at `/js/frond.js`. It delivers reactive data binding, DOM manipulation, HTTP fetch helpers, and WebSocket support.

### Reactive Data Binding

```html
<div id="app">
    <h1>{{ title }}</h1>
    <p>Count: {{ count }}</p>
    <button onclick="increment()">+1</button>
</div>

<script src="/js/frond.js"></script>
<script>
    const app = frond.reactive({
        el: "#app",
        data: {
            title: "My Counter",
            count: 0
        }
    });

    function increment() {
        app.data.count++;
    }
</script>
```

Changes to `app.data.count` automatically update the DOM.

### HTTP Fetch Helper

```javascript
// GET request
const products = await frond.get("/api/products");

// POST request
const result = await frond.post("/api/products", {
    name: "Widget",
    price: 9.99
});

// PUT request
await frond.put("/api/products/1", { price: 12.99 });

// DELETE request
await frond.del("/api/products/1");
```

### WebSocket Helper

```javascript
const ws = frond.ws("/ws/chat/general");

ws.on("open", () => console.log("Connected"));
ws.on("message", (data) => console.log(JSON.parse(data)));
ws.on("close", () => console.log("Disconnected"));

ws.send(JSON.stringify({ type: "message", text: "Hello!" }));
```

---

## 4. Building a CRUD Interface

Create `src/templates/product-manager.html`:

```html
{% extends "base.html" %}

{% block title %}Product Manager{% endblock %}

{% block content %}
    <h1>Product Manager</h1>

    <div id="app">
        <form id="add-form" class="card" style="padding: 16px; margin-bottom: 16px;">
            <h3>Add Product</h3>
            <div class="form-group">
                <label for="name">Name</label>
                <input type="text" id="name" class="form-control" required>
            </div>
            <div class="form-group">
                <label for="price">Price</label>
                <input type="number" id="price" class="form-control" step="0.01" required>
            </div>
            <button type="submit" class="btn btn-primary">Add Product</button>
        </form>

        <div id="product-list"></div>
    </div>

    <script src="/js/frond.js"></script>
    <script>
        async function loadProducts() {
            const data = await frond.get("/api/products");
            const list = document.getElementById("product-list");
            list.innerHTML = data.products.map(p =>
                `<div class="card" style="padding: 12px; margin-bottom: 8px;">
                    <strong>${p.name}</strong> - $${p.price.toFixed(2)}
                    <button class="btn btn-danger" style="float:right" onclick="deleteProduct(${p.id})">Delete</button>
                </div>`
            ).join("");
        }

        document.getElementById("add-form").addEventListener("submit", async (e) => {
            e.preventDefault();
            const name = document.getElementById("name").value;
            const price = document.getElementById("price").value;
            await frond.post("/api/products", { name, price: parseFloat(price) });
            document.getElementById("name").value = "";
            document.getElementById("price").value = "";
            loadProducts();
        });

        async function deleteProduct(id) {
            await frond.del("/api/products/" + id);
            loadProducts();
        }

        loadProducts();
    </script>
{% endblock %}
```

---

## 5. SCSS Compilation

Place `.scss` files in `src/public/scss/`. Tina4 compiles them automatically:

```
src/public/scss/custom.scss → /css/custom.css
```

---

## 6. Static File Serving

Files in `src/public/` are served directly:

```
src/public/images/logo.png → /images/logo.png
src/public/js/app.js       → /js/app.js
src/public/css/custom.css  → /css/custom.css
```

---

## 7. Integrating with React, Vue, or Svelte

Tina4 is the API backend. Point your frontend build tool's output to `src/public/`:

```env
# Vue
VITE_OUTPUT_DIR=../my-tina4-project/src/public

# React (Create React App)
BUILD_PATH=../my-tina4-project/src/public
```

Or use CORS to run them on separate ports during development:

```env
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
```

---

## 8. Exercise: Build a Product Dashboard

Build a single-page product dashboard using frond.js that displays products in a grid, supports adding and deleting products, and shows real-time updates via WebSocket.

---

## 9. Solution

Create `src/routes/dashboard-page.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/dashboard", async (req, res) => {
    return res.html("dashboard.html", {});
});
```

Create `src/templates/dashboard.html` with a full frond.js-powered dashboard using reactive data binding, HTTP helpers for CRUD operations, and WebSocket for live updates.

---

## 10. Gotchas

### 1. CORS Errors with Separate Frontend

**Fix:** Set `CORS_ORIGINS` in `.env`.

### 2. frond.js Not Loading

**Fix:** Ensure `<script src="/js/frond.js"></script>` is in your template. The file is auto-provided.

### 3. Static Files Return 404

**Fix:** Files must be in `src/public/`, not `public/` at the project root.

### 4. SCSS Not Compiling

**Fix:** Place files in `src/public/scss/` and restart the server.

### 5. Cache Busting

**Fix:** Use versioned filenames or query strings: `/css/app.css?v=1.2.3`.

### 6. React Router Conflicts

**Fix:** Add a catch-all route that serves `index.html` for client-side routing.

### 7. Large Bundle Sizes

**Fix:** Use code splitting. Serve static assets from a CDN.
