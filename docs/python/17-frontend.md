# Chapter 15: Frontend with tina4css

## 1. The Problem with Frontend Toolchains

Your client wants a dashboard. You know the drill. Install Node.js. Run `npm install`. Wait for 200MB of `node_modules`. Configure webpack or Vite. Set up PostCSS. Add a CSS framework. Pray nothing breaks when you upgrade a dependency six months from now.

Tina4 skips all of that. The framework ships with **tina4css** -- a Bootstrap-compatible CSS framework -- and **frond.js** -- a lightweight JavaScript helper. Both are included when you scaffold a project. No npm. No webpack. No build step. Link the files. Start building.

By the end of this chapter, you will have a complete admin dashboard with sidebar, navigation, cards, tables, modals, and dark mode -- without touching npm.

---

## 2. What Ships with Tina4

When you run `tina4 init python`, several files appear in your project:

```
src/public/
├── css/
│   └── tina4.css        # The CSS framework
├── js/
│   ├── tina4.min.js     # Core AJAX utilities
│   ├── frond.min.js     # Template engine client-side helpers
│   └── tina4js.min.js   # Reactive frontend framework (tina4-js)
└── scss/
    └── tina4.scss       # SCSS source (optional, for customization)
```

Include them in any template:

```html
<link rel="stylesheet" href="/css/tina4.css">
<script src="/js/tina4.min.js"></script>
<script src="/js/frond.min.js"></script>
```

Include only what you need. See section 7 for the full JavaScript API reference. No CDN, no package manager, no version conflicts.

---

## 3. The Grid System

tina4css uses a 12-column responsive grid, compatible with Bootstrap's class names. If you already know Bootstrap, you already know tina4css.

```html
<div class="container">
    <div class="row">
        <div class="col-md-4">
            <p>One third</p>
        </div>
        <div class="col-md-4">
            <p>One third</p>
        </div>
        <div class="col-md-4">
            <p>One third</p>
        </div>
    </div>
</div>
```

Breakpoints:

| Class Prefix | Screen Width | Typical Device |
|-------------|-------------|----------------|
| `col-` | All sizes | Phones and up |
| `col-sm-` | >= 576px | Large phones |
| `col-md-` | >= 768px | Tablets |
| `col-lg-` | >= 992px | Desktops |
| `col-xl-` | >= 1200px | Large desktops |

Columns stack vertically on screens smaller than their breakpoint. A `col-md-6` element takes half the row on tablets and up, but full width on phones.

---

## 4. Components

### Navbar

```html
<nav class="navbar navbar-dark bg-dark">
    <div class="container">
        <a class="navbar-brand" href="/">My Dashboard</a>
        <ul class="navbar-nav">
            <li class="nav-item"><a class="nav-link" href="/dashboard">Dashboard</a></li>
            <li class="nav-item"><a class="nav-link" href="/products">Products</a></li>
            <li class="nav-item"><a class="nav-link" href="/settings">Settings</a></li>
        </ul>
    </div>
</nav>
```

### Cards

```html
<div class="card">
    <div class="card-header">Monthly Revenue</div>
    <div class="card-body">
        <h2 class="card-title">$12,450</h2>
        <p class="card-text">Up 12% from last month</p>
    </div>
    <div class="card-footer text-muted">Updated 5 minutes ago</div>
</div>
```

### Buttons

```html
<button class="btn btn-primary">Save</button>
<button class="btn btn-secondary">Cancel</button>
<button class="btn btn-danger">Delete</button>
<button class="btn btn-success">Publish</button>
<button class="btn btn-outline-primary">Outlined</button>
<button class="btn btn-sm btn-primary">Small</button>
<button class="btn btn-lg btn-primary">Large</button>
```

### Tables

```html
<table class="table table-striped table-hover">
    <thead>
        <tr>
            <th>Name</th>
            <th>Category</th>
            <th>Price</th>
            <th>Status</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Wireless Keyboard</td>
            <td>Electronics</td>
            <td>$79.99</td>
            <td><span class="badge bg-success">In Stock</span></td>
        </tr>
        <tr>
            <td>Standing Desk</td>
            <td>Furniture</td>
            <td>$549.99</td>
            <td><span class="badge bg-danger">Out of Stock</span></td>
        </tr>
    </tbody>
</table>
```

### Alerts

```html
<div class="alert alert-success">Product created successfully!</div>
<div class="alert alert-danger">Failed to save changes.</div>
<div class="alert alert-warning">Your trial expires in 3 days.</div>
<div class="alert alert-info">A new version is available.</div>
```

### Modals

```html
<button class="btn btn-primary" data-toggle="modal" data-target="#confirmModal">Delete Product</button>

<div class="modal" id="confirmModal">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Confirm Delete</h5>
                <button class="btn-close" data-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <p>Are you sure you want to delete this product? This action cannot be undone.</p>
            </div>
            <div class="modal-footer">
                <button class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button class="btn btn-danger">Delete</button>
            </div>
        </div>
    </div>
</div>
```

### Forms

```html
<form>
    <div class="form-group">
        <label for="name" class="form-label">Product Name</label>
        <input type="text" class="form-control" id="name" placeholder="Enter product name">
    </div>

    <div class="form-group">
        <label for="category" class="form-label">Category</label>
        <select class="form-control" id="category">
            <option value="">Select a category</option>
            <option value="electronics">Electronics</option>
            <option value="furniture">Furniture</option>
        </select>
    </div>

    <div class="form-group">
        <label for="description" class="form-label">Description</label>
        <textarea class="form-control" id="description" rows="4"></textarea>
    </div>

    <div class="form-check">
        <input type="checkbox" class="form-check-input" id="featured">
        <label class="form-check-label" for="featured">Featured product</label>
    </div>

    <button type="submit" class="btn btn-primary mt-3">Save Product</button>
</form>
```

---

## 5. SCSS Customization

The default tina4css is ready to use, but if you want to customize colors, fonts, or spacing, edit the SCSS source:

Edit `src/public/scss/tina4.scss`:

```scss
// Override variables before importing the framework
$primary: #2d6a4f;
$secondary: #52b788;
$dark: #1b4332;
$font-family-base: 'Inter', sans-serif;
$border-radius: 8px;

// Import the framework
@import 'tina4-base';
```

Compile SCSS to CSS:

```bash
tina4 scss
```

```
Compiling SCSS...
  src/public/scss/tina4.scss -> src/public/css/tina4.css
Done (0.12s)
```

The compiled CSS replaces the default `tina4.css`. Your custom colors and fonts are now active across the entire application.

### Live SCSS Compilation

During development, run SCSS compilation in watch mode:

```bash
tina4 scss --watch
```

Every time you save a `.scss` file, it recompiles automatically. Combined with Tina4's live reload, you see changes in the browser within a second.

---

## 6. frond.js -- The JavaScript Helper

`frond.js` is a lightweight JavaScript library that ships with Tina4. It handles common frontend tasks without jQuery or any other dependency.

### AJAX Requests

```javascript
// GET request
frond.get("/api/products", function (data) {
    console.log("Products:", data);
});

// POST request
frond.post("/api/products", {
    name: "New Product",
    price: 29.99
}, function (data) {
    console.log("Created:", data);
});

// PUT request
frond.put("/api/products/1", {
    name: "Updated Product"
}, function (data) {
    console.log("Updated:", data);
});

// DELETE request
frond.delete("/api/products/1", function (data) {
    console.log("Deleted:", data);
});
```

### Form Submission via AJAX

```html
<form id="product-form" data-frond-submit="/api/products" data-frond-method="POST">
    <input type="text" name="name" placeholder="Product name">
    <input type="number" name="price" placeholder="Price">
    <button type="submit">Create</button>
</form>

<script src="/js/frond.js"></script>
<script>
    frond.onFormSuccess("product-form", function (data) {
        alert("Product created: " + data.name);
    });

    frond.onFormError("product-form", function (error) {
        alert("Error: " + error.message);
    });
</script>
```

The `data-frond-submit` attribute tells frond.js to intercept the form submission and send it as an AJAX request. No page reload.

### Token Management

frond.js automatically includes the JWT token in all requests:

```javascript
// Store the token (usually after login)
frond.setToken("eyJhbGciOiJIUzI1NiIs...");

// All subsequent requests automatically include:
// Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
frond.get("/api/profile", function (data) {
    console.log("Profile:", data);
});

// Clear the token (logout)
frond.clearToken();
```

### WebSocket (Covered in Chapter 12)

```javascript
const ws = frond.ws("/ws/chat/general");
ws.on("message", function (data) {
    console.log("Message:", JSON.parse(data));
});
```

---

## 7. JavaScript API Reference

Tina4 ships three JavaScript files. Each serves a different purpose and can be used independently or together.

### Including the Scripts

```html
<script src="/js/tina4.min.js"></script>
<script src="/js/frond.min.js"></script>
<script src="/js/tina4js.min.js"></script>
```

All three live in `src/public/js/` and are served from `/js/`. Include only what you need.

---

### 7.1 tina4.min.js -- Core Utilities

Low-level helpers for AJAX page loading and form submission. Use this when you want simple dynamic page updates without a full framework.

#### `loadPage(url, targetId)`

Fetches HTML from `url` and injects it into the element with the given `id`.

```html
<nav>
    <a href="#" onclick="loadPage('/dashboard', 'content')">Dashboard</a>
    <a href="#" onclick="loadPage('/settings', 'content')">Settings</a>
</nav>
<div id="content"><!-- pages load here --></div>

<script src="/js/tina4.min.js"></script>
```

#### `saveForm(formId, url, method)`

Serializes a form and submits it via AJAX. Prevents the default page reload.

```html
<form id="product-form">
    <input type="text" name="name" placeholder="Product name">
    <input type="number" name="price" placeholder="Price">
    <button type="button" onclick="saveForm('product-form', '/api/products', 'POST')">
        Save
    </button>
</form>
```

#### `sendRequest(url, method, data, callback)`

Generic AJAX helper for any HTTP method. Returns the response to a callback function.

```javascript
sendRequest("/api/products", "GET", null, function (response) {
    console.log("Products:", JSON.parse(response));
});

sendRequest("/api/products", "POST", { name: "Widget", price: 9.99 }, function (response) {
    console.log("Created:", JSON.parse(response));
});
```

---

### 7.2 frond.min.js -- Template Engine Client-Side Helpers

A companion to the Frond template engine. Handles AJAX form interception, WebSocket connections with auto-reconnect, JWT token refresh, and dynamic template loading.

#### AJAX Form Handling

Forms with `data-frond-submit` are intercepted automatically. No page reload, no boilerplate.

```html
<form id="login-form" data-frond-submit="/api/login" data-frond-method="POST">
    <input type="text" name="username" placeholder="Username">
    <input type="password" name="password" placeholder="Password">
    <button type="submit">Log In</button>
</form>

<script src="/js/frond.min.js"></script>
<script>
    frond.onFormSuccess("login-form", function (data) {
        frond.setToken(data.token);
        window.location.href = "/dashboard";
    });
</script>
```

#### WebSocket Auto-Reconnect

Connections drop. frond.js reconnects automatically with exponential backoff.

```javascript
const ws = frond.ws("/ws/notifications");
ws.on("message", function (data) {
    const notification = JSON.parse(data);
    alert(notification.text);
});
// If the server restarts or the network blips, frond.js reconnects silently.
```

#### Token Refresh

JWT tokens stored via `frond.setToken()` are attached to every request. When a token expires, frond.js triggers a refresh before retrying the request.

```javascript
frond.setToken("eyJhbGciOiJIUzI1NiIs...");
// All subsequent frond.get/post/put/delete calls include the token.
// When the token expires, frond.js calls the refresh endpoint automatically.
```

#### Dynamic Template Loading

Load server-rendered Frond templates into any element without a full page reload.

```javascript
frond.loadTemplate("/templates/user-card", { userId: 42 }, "user-panel");
// Fetches the rendered template and injects it into #user-panel.
```

---

### 7.3 tina4js.min.js -- Reactive Frontend Framework

A standalone reactive framework for building rich client-side applications. Provides signals, computed values, effects, Web Components, client-side routing, and built-in fetch and WebSocket wrappers. This is the **tina4-js** project.

#### Reactive State: `signal()`, `computed()`, `effect()`

```javascript
import { signal, computed, effect } from "/js/tina4js.min.js";

const count = signal(0);
const doubled = computed(() => count.value * 2);

effect(() => {
    console.log(`Count: ${count.value}, Doubled: ${doubled.value}`);
});

count.value = 5; // logs "Count: 5, Doubled: 10"
```

#### DOM Rendering: `html` Tagged Template

```javascript
import { signal, html } from "/js/tina4js.min.js";

const name = signal("World");

const app = html`
    <div>
        <h1>Hello, ${name}!</h1>
        <input value="${name}" oninput="${(e) => name.value = e.target.value}" />
    </div>
`;

document.getElementById("app").append(app);
```

#### Web Components: `Tina4Element`

```javascript
import { Tina4Element, signal, html } from "/js/tina4js.min.js";

class CounterButton extends Tina4Element {
    setup() {
        this.count = signal(0);
    }
    render() {
        return html`
            <button onclick="${() => this.count.value++}">
                Clicked ${this.count} times
            </button>
        `;
    }
}
customElements.define("counter-button", CounterButton);
```

Use it in HTML:

```html
<counter-button></counter-button>
<script type="module" src="/js/counter-button.js"></script>
```

#### Fetch Wrapper: `api()`

```javascript
import { api } from "/js/tina4js.min.js";

const products = await api("/api/products");            // GET
await api("/api/products", { method: "POST", body: { name: "Widget" } });
```

#### WebSocket Client: `ws()`

```javascript
import { ws } from "/js/tina4js.min.js";

const socket = ws("/ws/chat");
socket.on("message", (data) => console.log(data));
socket.send({ text: "Hello" });
```

#### Client-Side Routing: `route()`, `navigate()`

```javascript
import { route, navigate, html } from "/js/tina4js.min.js";

route("/", () => html`<h1>Home</h1>`);
route("/about", () => html`<h1>About</h1>`);

// Navigate programmatically
navigate("/about");
```

---

## 8. Building an Admin Dashboard

Let us build a complete admin dashboard. This is the kind of page that powers the backend of every web application.

### Base Template

Create `src/templates/base.html`:

```html
<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Dashboard{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.css">
</head>
<body>
    <nav class="navbar navbar-dark bg-dark">
        <div class="container-fluid">
            <a class="navbar-brand" href="/admin">TaskFlow Admin</a>
            <ul class="navbar-nav">
                <li class="nav-item"><a class="nav-link" href="/admin">Dashboard</a></li>
                <li class="nav-item"><a class="nav-link" href="/admin/products">Products</a></li>
                <li class="nav-item"><a class="nav-link" href="/admin/users">Users</a></li>
                <li class="nav-item">
                    <button class="btn btn-sm btn-outline-light" onclick="toggleDarkMode()">Dark Mode</button>
                </li>
            </ul>
        </div>
    </nav>

    <div class="container-fluid mt-4">
        <div class="row">
            <div class="col-md-2">
                {% block sidebar %}
                <div class="list-group">
                    <a href="/admin" class="list-group-item list-group-item-action">Overview</a>
                    <a href="/admin/products" class="list-group-item list-group-item-action">Products</a>
                    <a href="/admin/orders" class="list-group-item list-group-item-action">Orders</a>
                    <a href="/admin/customers" class="list-group-item list-group-item-action">Customers</a>
                    <a href="/admin/reports" class="list-group-item list-group-item-action">Reports</a>
                    <a href="/admin/settings" class="list-group-item list-group-item-action">Settings</a>
                </div>
                {% endblock %}
            </div>
            <div class="col-md-10">
                {% block content %}{% endblock %}
            </div>
        </div>
    </div>

    <script src="/js/frond.js"></script>
    <script>
        function toggleDarkMode() {
            const html = document.documentElement;
            const current = html.getAttribute("data-theme");
            html.setAttribute("data-theme", current === "dark" ? "light" : "dark");
            localStorage.setItem("theme", current === "dark" ? "light" : "dark");
        }

        // Restore saved theme
        const savedTheme = localStorage.getItem("theme");
        if (savedTheme) {
            document.documentElement.setAttribute("data-theme", savedTheme);
        }
    </script>
    {% block scripts %}{% endblock %}
</body>
</html>
```

### Dashboard Page

Create `src/templates/dashboard.html`:

```html
{% extends "base.html" %}

{% block title %}Dashboard - Admin{% endblock %}

{% block content %}
    <h1>Dashboard</h1>

    <div class="row mb-4">
        <div class="col-md-3">
            <div class="card">
                <div class="card-body">
                    <h6 class="card-subtitle text-muted">Total Products</h6>
                    <h2 class="card-title">{{ stats.total_products }}</h2>
                </div>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card">
                <div class="card-body">
                    <h6 class="card-subtitle text-muted">Total Orders</h6>
                    <h2 class="card-title">{{ stats.total_orders }}</h2>
                </div>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card">
                <div class="card-body">
                    <h6 class="card-subtitle text-muted">Revenue</h6>
                    <h2 class="card-title">${{ stats.revenue }}</h2>
                </div>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card">
                <div class="card-body">
                    <h6 class="card-subtitle text-muted">Active Users</h6>
                    <h2 class="card-title">{{ stats.active_users }}</h2>
                </div>
            </div>
        </div>
    </div>

    <div class="row">
        <div class="col-md-8">
            <div class="card">
                <div class="card-header">Recent Orders</div>
                <div class="card-body">
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>Order</th>
                                <th>Customer</th>
                                <th>Amount</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for order in recent_orders %}
                            <tr>
                                <td>#{{ order.id }}</td>
                                <td>{{ order.customer }}</td>
                                <td>${{ order.amount }}</td>
                                <td>
                                    <span class="badge bg-{{ order.badge }}">{{ order.status }}</span>
                                </td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <div class="card">
                <div class="card-header">Quick Actions</div>
                <div class="card-body">
                    <a href="/admin/products/new" class="btn btn-primary btn-block mb-2">Add Product</a>
                    <a href="/admin/orders" class="btn btn-outline-primary btn-block mb-2">View Orders</a>
                    <a href="/admin/reports" class="btn btn-outline-secondary btn-block">Generate Report</a>
                </div>
            </div>
        </div>
    </div>
{% endblock %}
```

### Dashboard Route

Create `src/routes/admin.py`:

```python
from tina4_python.core.router import get, template

@get("/admin")
async def admin_dashboard(request, response):
    stats = {
        "total_products": 156,
        "total_orders": 1243,
        "revenue": "24,580",
        "active_users": 89
    }

    recent_orders = [
        {"id": 1042, "customer": "Alice Johnson", "amount": "129.99", "status": "Shipped", "badge": "success"},
        {"id": 1041, "customer": "Bob Smith", "amount": "549.99", "status": "Processing", "badge": "warning"},
        {"id": 1040, "customer": "Carol White", "amount": "79.99", "status": "Delivered", "badge": "info"},
        {"id": 1039, "customer": "Dave Brown", "amount": "34.99", "status": "Cancelled", "badge": "danger"},
    ]

    return response(template("dashboard.html", stats=stats, recent_orders=recent_orders))
```

Start the server and visit `http://localhost:7145/admin`. You have a complete admin dashboard with a sidebar, stats cards, a data table, and quick action buttons.

---

## 9. Dark Mode

tina4css supports dark mode via the `data-theme` attribute on the `<html>` element:

```html
<!-- Light mode (default) -->
<html data-theme="light">

<!-- Dark mode -->
<html data-theme="dark">
```

The toggle function from the base template handles switching:

```javascript
function toggleDarkMode() {
    const html = document.documentElement;
    const current = html.getAttribute("data-theme");
    html.setAttribute("data-theme", current === "dark" ? "light" : "dark");
    localStorage.setItem("theme", current === "dark" ? "light" : "dark");
}
```

Dark mode transforms every surface. Backgrounds darken. Text colors invert. Borders shift. Cards, tables, buttons -- all adjust contrast. Zero CSS rules required from you.

### Respecting System Preference

To match the user's operating system dark mode setting:

```javascript
// Check if user prefers dark mode
if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    document.documentElement.setAttribute("data-theme", "dark");
}

// Listen for changes
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    document.documentElement.setAttribute("data-theme", e.matches ? "dark" : "light");
});
```

---

## 10. Responsive Design

tina4css is mobile-first. Components adapt to screen size automatically. Here are the key patterns:

### Responsive Sidebar

On mobile, the sidebar collapses into a hamburger menu:

```html
<button class="btn btn-dark d-md-none" onclick="toggleSidebar()">Menu</button>

<div id="sidebar" class="d-none d-md-block col-md-2">
    <!-- sidebar content -->
</div>

<script>
function toggleSidebar() {
    const sidebar = document.getElementById("sidebar");
    sidebar.classList.toggle("d-none");
}
</script>
```

### Responsive Tables

Tables scroll horizontally on small screens:

```html
<div class="table-responsive">
    <table class="table">
        <!-- table content -->
    </table>
</div>
```

### Hiding Elements by Screen Size

```html
<div class="d-none d-md-block">Only visible on tablet and up</div>
<div class="d-md-none">Only visible on mobile</div>
```

---

## 11. Exercise: Build an Admin Dashboard

Build a complete admin dashboard for a product management system.

### Requirements

1. Create a base template with:
   - A dark navbar with the app name and navigation links
   - A sidebar with menu items (Dashboard, Products, Orders, Settings)
   - A main content area
   - Dark mode toggle that persists across page loads

2. Create a dashboard page at `GET /admin` with:
   - Four stat cards (Products, Orders, Revenue, Users)
   - A table showing recent orders with status badges
   - Quick action buttons

3. Create a product list page at `GET /admin/products` with:
   - A table of products with name, category, price, and stock status
   - An "Add Product" button
   - Search/filter by category

4. Use tina4css classes throughout (no custom CSS needed)

### Test by:

1. Visit `http://localhost:7145/admin` -- you should see the dashboard with stats and orders
2. Click "Dark Mode" -- the entire page should switch to dark theme
3. Refresh the page -- dark mode should persist
4. Resize the browser to mobile width -- the sidebar should collapse
5. Visit `http://localhost:7145/admin/products` -- you should see the product table

---

## 12. Solution

The base template and dashboard route are shown in sections 8 and above. Here is the product list page:

Create `src/templates/products.html`:

```html
{% extends "base.html" %}

{% block title %}Products - Admin{% endblock %}

{% block content %}
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h1>Products</h1>
        <a href="/admin/products/new" class="btn btn-primary">Add Product</a>
    </div>

    <div class="card mb-4">
        <div class="card-body">
            <form class="row g-3" method="GET" action="/admin/products">
                <div class="col-md-4">
                    <input type="text" class="form-control" name="search"
                           placeholder="Search products..." value="{{ search }}">
                </div>
                <div class="col-md-3">
                    <select class="form-control" name="category">
                        <option value="">All Categories</option>
                        {% for cat in categories %}
                        <option value="{{ cat }}" {% if cat == selected_category %}selected{% endif %}>{{ cat }}</option>
                        {% endfor %}
                    </select>
                </div>
                <div class="col-md-2">
                    <button type="submit" class="btn btn-outline-primary">Filter</button>
                </div>
            </form>
        </div>
    </div>

    <div class="card">
        <div class="card-body">
            <div class="table-responsive">
                <table class="table table-striped table-hover">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Category</th>
                            <th>Price</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for product in products %}
                        <tr>
                            <td>{{ product.id }}</td>
                            <td>{{ product.name }}</td>
                            <td>{{ product.category }}</td>
                            <td>${{ product.price }}</td>
                            <td>
                                {% if product.in_stock %}
                                <span class="badge bg-success">In Stock</span>
                                {% else %}
                                <span class="badge bg-danger">Out of Stock</span>
                                {% endif %}
                            </td>
                            <td>
                                <a href="/admin/products/{{ product.id }}" class="btn btn-sm btn-outline-primary">Edit</a>
                                <button class="btn btn-sm btn-outline-danger">Delete</button>
                            </td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
{% endblock %}
```

Add the route:

```python
@get("/admin/products")
async def admin_products(request, response):
    search = request.query.get("search", "")
    selected_category = request.query.get("category", "")

    products = [
        {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": "79.99", "in_stock": True},
        {"id": 2, "name": "Standing Desk", "category": "Furniture", "price": "549.99", "in_stock": True},
        {"id": 3, "name": "Coffee Grinder", "category": "Kitchen", "price": "49.99", "in_stock": False},
        {"id": 4, "name": "Yoga Mat", "category": "Fitness", "price": "29.99", "in_stock": True},
        {"id": 5, "name": "USB-C Hub", "category": "Electronics", "price": "49.99", "in_stock": True},
    ]

    if selected_category:
        products = [p for p in products if p["category"] == selected_category]

    if search:
        products = [p for p in products if search.lower() in p["name"].lower()]

    categories = ["Electronics", "Furniture", "Kitchen", "Fitness"]

    return response(template("products.html",
        products=products,
        categories=categories,
        search=search,
        selected_category=selected_category
    ))
```

---

## 12. HTML Builder -- Generating HTML in Code

Sometimes you need to produce HTML from a route handler without a template -- a dynamic email body, an AJAX fragment, or a one-off snippet. String concatenation is fragile and error-prone. The `HTMLElement` class builds HTML programmatically with auto-escaping.

### Direct Construction

```python
from tina4_python.HtmlElement import HTMLElement

el = HTMLElement("div", {"class": "card"}, ["Hello"])
str(el)  # <div class="card">Hello</div>
```

The constructor takes three arguments: tag name, an attribute dictionary, and a list of children (strings or other `HTMLElement` instances).

### Builder Pattern

Call an element to append children and return a new element:

```python
page = HTMLElement("div")(
    HTMLElement("h1")("Dashboard"),
    HTMLElement("p")("Welcome back."),
)
```

Pass a dictionary to merge attributes:

```python
link = HTMLElement("a")({"href": "/home", "class": "nav-link"}, "Home")
# <a href="/home" class="nav-link">Home</a>
```

### Helper Functions

Typing `HTMLElement` everywhere gets verbose. `add_html_helpers()` injects shorthand functions -- `_div()`, `_p()`, `_a()`, `_span()`, `_h1()`, `_table()`, and every other standard HTML tag -- into your module:

```python
from tina4_python.HtmlElement import add_html_helpers

add_html_helpers(globals())

html = _div({"class": "alert alert-success"},
    _strong("Done!"),
    _p("Your changes have been saved."),
)
```

The first argument can be an attribute dictionary. Everything else becomes children.

### Void Tags and Auto-Escaping

Void tags like `br`, `hr`, `img`, and `input` render without a closing tag:

```python
HTMLElement("img", {"src": "logo.png", "alt": "Logo"})
# <img src="logo.png" alt="Logo">

HTMLElement("br")
# <br>
```

All attribute values and text children are HTML-escaped automatically. User input is safe by default -- no XSS vectors from forgotten escaping.

### Use Case -- HTML from a Route

```python
from tina4_python.core.router import get
from tina4_python.HtmlElement import add_html_helpers

add_html_helpers(globals())

@get("/api/status-badge")
async def status_badge(request, response):
    status = request.params.get("status", "unknown")
    color = "success" if status == "active" else "danger"

    badge = _span({"class": f"badge bg-{color}"}, status)
    return response(str(badge))
```

No template file needed. The builder handles escaping, nesting, and rendering in one place.

---

## 13. Gotchas

### 1. CSS Not Loading

**Problem:** The page looks unstyled -- no colors, no layout, just plain text.

**Cause:** The path to `tina4.css` is wrong. The file is in `src/public/css/` but you are linking to `/css/tina4.css`.

**Fix:** Tina4 serves everything in `src/public/` as static files from the root path. Link to `/css/tina4.css` (not `/src/public/css/tina4.css`). Verify the file exists at `src/public/css/tina4.css`.

### 2. frond.js Functions Not Found

**Problem:** `frond.get is not a function` or `frond is not defined` in the browser console.

**Cause:** The `frond.js` script tag is missing or placed after the code that uses it.

**Fix:** Include `<script src="/js/frond.js"></script>` before any script that calls `frond.*`. Put it at the bottom of the body, just before your custom scripts.

### 3. Dark Mode Flickers on Page Load

**Problem:** The page loads in light mode and then flashes to dark mode.

**Cause:** The dark mode JavaScript runs after the page is rendered. The browser paints the light theme first, then switches.

**Fix:** Add the theme detection script in the `<head>` (before the body renders):

```html
<head>
    <script>
        const t = localStorage.getItem("theme");
        if (t) document.documentElement.setAttribute("data-theme", t);
    </script>
</head>
```

### 4. SCSS Not Compiling

**Problem:** You edited `tina4.scss` but the CSS did not change.

**Cause:** SCSS does not compile automatically. You need to run `tina4 scss` or use `--watch` mode.

**Fix:** Run `tina4 scss --watch` during development. For production builds, run `tina4 scss` as part of your build process.

### 5. Modal Does Not Open

**Problem:** Clicking the button does nothing -- the modal stays hidden.

**Cause:** The `data-toggle` and `data-target` attributes require frond.js to be loaded. Without it, there is no JavaScript to handle the modal toggle.

**Fix:** Ensure `frond.js` is loaded. Verify the `data-target` matches the modal's `id` exactly (including the `#` prefix).

### 6. Grid Columns Do Not Stack on Mobile

**Problem:** Columns stay side-by-side on phone screens instead of stacking vertically.

**Cause:** You used `col-4` instead of `col-md-4`. The `col-4` class applies at all screen sizes, so the columns always take one-third width.

**Fix:** Use responsive prefixes: `col-md-4` means "one-third on medium screens and up, full width on small screens." For mobile-first design, always use `col-md-*` or `col-lg-*`.

### 7. Static Files Return 404

**Problem:** CSS, JS, or image files return 404 Not Found.

**Cause:** The files are not in the `src/public/` directory, or the directory structure is wrong.

**Fix:** Static files must be in `src/public/`. The URL path maps directly to the file path within that directory. `/css/tina4.css` maps to `src/public/css/tina4.css`. Check file paths and ensure the `src/public/` directory exists.
