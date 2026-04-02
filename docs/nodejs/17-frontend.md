# Chapter 15: Frontend Integration

## 1. Beyond JSON APIs

Your API returns perfect JSON. Now someone has to build the interface.

Tina4 ships two frontend tools: **tina4css** (a utility CSS framework) and **frond.js** (a reactive JavaScript library). Both arrive with every project. No npm installs. No build tools. No webpack.

This chapter ends with a complete admin dashboard. Sidebar. Navigation. Cards. Tables. Modals. Dark mode. Progress bars. AJAX-driven user management. Zero npm dependencies.

---

## 2. What Ships with Tina4

Run `tina4 init nodejs`. Several files appear in your project:

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

Include only what you need. See section 7 for the full JavaScript API reference. No CDN. No package manager. No version conflicts.

---

## 3. The Grid System

tina4css uses a 12-column responsive grid. The class names match Bootstrap. Know Bootstrap? You know tina4css.

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

Columns stack vertically on screens smaller than their breakpoint. A `col-md-6` element takes half the row on tablets and up, full width on phones.

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

Use `navbar-light bg-light` for a light theme, or `navbar-dark bg-primary` for a colored background.

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

Table variants: `table-bordered`, `table-striped`, `table-hover`, `table-sm` (compact), `table-responsive` (wraps in a scrollable container on small screens). Mix and match.

### Alerts

```html
<div class="alert alert-success">Product created.</div>
<div class="alert alert-danger">Failed to save changes.</div>
<div class="alert alert-warning alert-dismissible">
    Your trial expires in 3 days.
    <button type="button" class="close" data-dismiss="alert">&times;</button>
</div>
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

tina4css includes the JavaScript for modal toggling. No jQuery required.

### Progress Bars

Progress bars visualize completion, upload status, or system health. The outer `progress` container holds a `progress-bar` fill element.

```html
<div class="progress">
    <div class="progress-bar bg-success" style="width: 75%">75%</div>
</div>

<div class="progress">
    <div class="progress-bar bg-warning progress-bar-striped" style="width: 45%">
        45% - Uploading...
    </div>
</div>
```

Set the width with inline `style`. Add `bg-success`, `bg-info`, `bg-warning`, or `bg-danger` for color. Add `progress-bar-striped` for animated stripes.

### Badges

```html
<span class="badge bg-primary">Primary</span>
<span class="badge bg-success">Active</span>
<span class="badge bg-warning">Pending</span>
<span class="badge bg-danger">Overdue</span>
<span class="badge bg-info">Info</span>
<span class="badge bg-dark">Dark</span>
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

### Utility Classes

```html
<p class="text-center">Centered</p>
<div class="mt-4">Margin top</div>
<div class="p-3">Padding</div>
<span class="text-muted">Gray text</span>
```

---

## 5. SCSS Customization

The default tina4css works out of the box. To customize colors, fonts, or spacing, edit the SCSS source.

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

The compiled CSS replaces the default `tina4.css`. Your custom colors and fonts take effect across the entire application.

### Live SCSS Compilation

During development, run SCSS compilation in watch mode:

```bash
tina4 scss --watch
```

Every save to a `.scss` file triggers a recompile. Combined with Tina4's live reload, changes appear in the browser within a second.

---

## 6. frond.js -- The JavaScript Helper

`frond.js` is a lightweight JavaScript library that ships with Tina4. It handles AJAX requests, form submission, JWT token management, and loading indicators. No jQuery. No Axios. No other dependency.

### AJAX Requests

```javascript
// GET request
frond.get("/api/products", function (data) {
    console.log("Products:", data);
});

// GET with error handling
frond.get("/api/products", function (data) {
    console.log(data);
}, function (error) {
    console.error("Failed:", error);
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

<script src="/js/frond.min.js"></script>
<script>
    frond.onFormSuccess("product-form", function (data) {
        alert("Product created: " + data.name);
    });

    frond.onFormError("product-form", function (error) {
        alert("Error: " + error.message);
    });
</script>
```

The `data-frond-submit` attribute tells frond.js to intercept the form submission and send it as an AJAX request. No page reload. frond.js serializes all form fields as JSON.

### Token Management

frond.js manages JWT tokens. Store a token after login, and frond.js attaches it to every request.

```javascript
// Store the token (usually after login)
frond.setToken("eyJhbGciOiJIUzI1NiIs...");

// All subsequent requests include:
// Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
frond.get("/api/profile", function (data) {
    console.log("Profile:", data);
});

// Clear the token (logout)
frond.clearToken();
```

frond.js stores the token in `localStorage` and includes it as a `Bearer` token in the `Authorization` header on every request.

### Loading Indicators

frond.js can show and hide a loading element during AJAX requests. Pass a CSS selector in the options object.

```javascript
// Show a loading state while fetching
frond.get("/api/products", function (data) {
    renderProducts(data.products);
}, null, {
    loading: "#loadingSpinner"  // CSS selector for loading element
});
```

The element with id `loadingSpinner` appears while the request flies and disappears when it completes. Pair it with a spinner or "Loading..." text in your HTML:

```html
<div id="loadingSpinner" class="text-center p-4" style="display: none;">
    Loading...
</div>
```

frond.js toggles `display: block` and `display: none` on the element. No extra CSS needed.

### WebSocket (Covered in Chapter 12)

```javascript
const ws = frond.ws("/ws/chat/general");
ws.on("message", function (data) {
    console.log("Message:", JSON.parse(data));
});
```

Connections drop. frond.js reconnects with exponential backoff. If the server restarts or the network blips, the client reconnects without intervention.

---

## 7. JavaScript API Reference

Tina4 ships three JavaScript files. Each serves a different purpose. Use them independently or together.

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

Forms with `data-frond-submit` are intercepted. No page reload. No boilerplate.

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

```javascript
const ws = frond.ws("/ws/notifications");
ws.on("message", function (data) {
    const notification = JSON.parse(data);
    alert(notification.text);
});
// If the server restarts or the network blips, frond.js reconnects.
```

#### Token Refresh

JWT tokens stored via `frond.setToken()` are attached to every request. When a token expires, frond.js triggers a refresh before retrying the request.

```javascript
frond.setToken("eyJhbGciOiJIUzI1NiIs...");
// All subsequent frond.get/post/put/delete calls include the token.
// When the token expires, frond.js calls the refresh endpoint.
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

A complete admin dashboard. The kind of page that powers the backend of every web application.

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
    <script>
        var t = localStorage.getItem("theme");
        if (t) document.documentElement.setAttribute("data-theme", t);
    </script>
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

    <script src="/js/frond.min.js"></script>
    <script>
        function toggleDarkMode() {
            var html = document.documentElement;
            var current = html.getAttribute("data-theme");
            html.setAttribute("data-theme", current === "dark" ? "light" : "dark");
            localStorage.setItem("theme", current === "dark" ? "light" : "dark");
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

            <div class="card mt-3">
                <div class="card-header">System Health</div>
                <div class="card-body">
                    <p><strong>CPU:</strong></p>
                    <div class="progress mb-3">
                        <div class="progress-bar bg-success" style="width: {{ stats.cpu_usage }}%">
                            {{ stats.cpu_usage }}%
                        </div>
                    </div>
                    <p><strong>Memory:</strong></p>
                    <div class="progress mb-3">
                        <div class="progress-bar bg-info" style="width: {{ stats.memory_usage }}%">
                            {{ stats.memory_usage }}%
                        </div>
                    </div>
                    <p><strong>Disk:</strong></p>
                    <div class="progress">
                        <div class="progress-bar bg-warning" style="width: {{ stats.disk_usage }}%">
                            {{ stats.disk_usage }}%
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
{% endblock %}
```

### Dashboard Route

Create `src/routes/admin.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/admin", async (req, res) => {
    const stats = {
        total_products: 156,
        total_orders: 1243,
        revenue: "24,580",
        active_users: 89,
        cpu_usage: 42,
        memory_usage: 68,
        disk_usage: 55
    };

    const recent_orders = [
        { id: 1042, customer: "Alice Johnson", amount: "129.99", status: "Shipped", badge: "success" },
        { id: 1041, customer: "Bob Smith", amount: "549.99", status: "Processing", badge: "warning" },
        { id: 1040, customer: "Carol White", amount: "79.99", status: "Delivered", badge: "info" },
        { id: 1039, customer: "Dave Brown", amount: "34.99", status: "Cancelled", badge: "danger" },
    ];

    return res.html("dashboard.html", { stats, recent_orders });
});
```

Start the server and visit `http://localhost:7148/admin`. You see a sidebar, stat cards, a data table, quick action buttons, and system health progress bars. Zero npm dependencies.

---

## 9. Dark Mode

tina4css supports dark mode through a single attribute on the `<html>` element:

```html
<!-- Light mode (default) -->
<html data-theme="light">

<!-- Dark mode -->
<html data-theme="dark">
```

The toggle function from the base template handles switching:

```javascript
function toggleDarkMode() {
    var html = document.documentElement;
    var current = html.getAttribute("data-theme");
    html.setAttribute("data-theme", current === "dark" ? "light" : "dark");
    localStorage.setItem("theme", current === "dark" ? "light" : "dark");
}
```

Dark mode transforms every surface. Backgrounds darken. Text colors invert. Borders shift. Cards, tables, buttons -- all adjust contrast. Zero CSS rules required from you.

### Respecting System Preference

Match the user's operating system dark mode setting:

```javascript
var saved = localStorage.getItem("theme");
if (saved) {
    document.documentElement.setAttribute("data-theme", saved);
} else if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
    document.documentElement.setAttribute("data-theme", "dark");
}
```

---

## 10. Responsive Design

tina4css is mobile-first. Components stack on small screens and expand on larger ones.

### Responsive Sidebar

On mobile, the sidebar collapses into a toggle:

```html
<button class="btn btn-dark d-md-none" onclick="toggleSidebar()">Menu</button>

<div id="sidebar" class="d-none d-md-block col-md-2">
    <!-- sidebar content -->
</div>

<script>
function toggleSidebar() {
    var sidebar = document.getElementById("sidebar");
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

## 11. Building a Users Page with AJAX

A user management page. Data loads via AJAX using frond.js. No full page reloads. The table populates from the API. Users create, edit, and delete records through modals and inline actions.

### The Template

Create `src/templates/admin/users.html`:

```html
{% extends "base.html" %}

{% block title %}Users - Admin{% endblock %}

{% block content %}
    <div class="card">
        <div class="card-header d-flex justify-content-between align-items-center">
            <span>All Users</span>
            <button class="btn btn-sm btn-primary" data-toggle="modal" data-target="#addUserModal">
                Add User
            </button>
        </div>
        <div class="card-body p-0">
            <div id="loadingSpinner" class="text-center p-4" style="display: none;">
                Loading...
            </div>
            <table class="table table-hover m-0" id="usersTable">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Created</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody id="usersBody">
                    <!-- Populated by JavaScript -->
                </tbody>
            </table>
        </div>
    </div>

    <!-- Add User Modal -->
    <div class="modal" id="addUserModal">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Add New User</h5>
                    <button type="button" class="btn-close" data-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <form id="addUserForm">
                        <div class="form-group">
                            <label for="userName">Name</label>
                            <input type="text" class="form-control" name="name" id="userName" required>
                        </div>
                        <div class="form-group">
                            <label for="userEmail">Email</label>
                            <input type="email" class="form-control" name="email" id="userEmail" required>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                    <button class="btn btn-primary" onclick="createUser()">Create User</button>
                </div>
            </div>
        </div>
    </div>

    <div id="alertArea" class="mt-3"></div>
{% endblock %}

{% block scripts %}
<script>
    function loadUsers() {
        frond.get("/api/users", function (data) {
            var tbody = document.getElementById("usersBody");
            tbody.innerHTML = "";

            if (data.data && data.data.length > 0) {
                data.data.forEach(function (user) {
                    var row = '<tr>'
                        + '<td>' + user.id + '</td>'
                        + '<td>' + user.name + '</td>'
                        + '<td>' + user.email + '</td>'
                        + '<td>' + user.created_at + '</td>'
                        + '<td>'
                        + '<button class="btn btn-sm btn-outline-primary" onclick="editUser(' + user.id + ')">Edit</button> '
                        + '<button class="btn btn-sm btn-outline-danger" onclick="deleteUser(' + user.id + ')">Delete</button>'
                        + '</td>'
                        + '</tr>';
                    tbody.innerHTML += row;
                });
            } else {
                tbody.innerHTML = '<tr><td colspan="5" class="text-center p-4">No users found</td></tr>';
            }
        }, null, { loading: "#loadingSpinner" });
    }

    function createUser() {
        var name = document.getElementById("userName").value;
        var email = document.getElementById("userEmail").value;

        frond.post("/api/users", { name: name, email: email }, function (data) {
            document.getElementById("alertArea").innerHTML =
                '<div class="alert alert-success">User "' + data.name + '" created.</div>';
            loadUsers();
        }, function (error) {
            document.getElementById("alertArea").innerHTML =
                '<div class="alert alert-danger">Error creating user.</div>';
        });
    }

    function deleteUser(id) {
        if (confirm("Are you sure you want to delete this user?")) {
            frond.delete("/api/users/" + id, function () {
                loadUsers();
            });
        }
    }

    // Load users on page load
    loadUsers();
</script>
{% endblock %}
```

### The Route

```typescript
import { Router } from "tina4-nodejs";

Router.get("/admin/users", async (req, res) => {
    return res.html("admin/users.html", {});
});
```

This page loads users via an AJAX call to `/api/users` (provided by auto-CRUD on the User model from Chapter 6). The loading indicator appears while the request flies. The table populates when data arrives. Users add records through a modal form and delete with confirmation -- all without full page reloads.

---

## 12. Building a CRUD Interface

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

## 13. Static File Serving

Files in `src/public/` are served directly:

```
src/public/images/logo.png → /images/logo.png
src/public/js/app.js       → /js/app.js
src/public/css/custom.css  → /css/custom.css
```

---

## 14. Integrating with React, Vue, or Svelte

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

## 15. Exercise: Build an Admin Dashboard

Build an admin dashboard for a product management system.

### Requirements

1. Create a base template with:
   - A dark navbar with the app name and navigation links
   - A sidebar with menu items (Dashboard, Products, Orders, Settings)
   - A main content area
   - Dark mode toggle that persists across page loads

2. Create a dashboard page at `GET /admin` with:
   - Four stat cards (Products, Orders, Revenue, Users)
   - A table showing recent orders with status badges
   - Progress bars showing system health (CPU, Memory, Disk)

3. Create a users page at `GET /admin/users` with:
   - A table of users loaded via AJAX using frond.js
   - An "Add User" button that opens a modal with a form
   - AJAX form submission that refreshes the table without a page reload
   - A loading indicator while data fetches

4. Use tina4css classes throughout (no custom CSS needed)

### Test by:

1. Visit `http://localhost:7148/admin` -- see the dashboard with stats, orders, and progress bars
2. Click "Dark Mode" -- the entire page switches to dark theme
3. Refresh the page -- dark mode persists
4. Resize the browser to mobile width -- the sidebar collapses
5. Visit `http://localhost:7148/admin/users` -- see the user table loaded via AJAX

---

## 16. Solution

The base template, dashboard page, and users page are shown in sections 8 and 11. The product list page follows the same AJAX pattern from section 11, but for products instead of users.

For the users page, use auto-CRUD on the User model (`autoCrud = true`) so the API endpoints exist at `/api/users`. Load the table with `frond.get("/api/users", ...)` and handle form submission with `frond.post("/api/users", ...)`.

Add the product list route:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/admin/products", async (req, res) => {
    const search = req.query.search ?? "";
    const selectedCategory = req.query.category ?? "";

    let products = [
        { id: 1, name: "Wireless Keyboard", category: "Electronics", price: "79.99", inStock: true },
        { id: 2, name: "Standing Desk", category: "Furniture", price: "549.99", inStock: true },
        { id: 3, name: "Coffee Grinder", category: "Kitchen", price: "49.99", inStock: false },
        { id: 4, name: "Yoga Mat", category: "Fitness", price: "29.99", inStock: true },
        { id: 5, name: "USB-C Hub", category: "Electronics", price: "49.99", inStock: true },
    ];

    if (selectedCategory) {
        products = products.filter(p => p.category === selectedCategory);
    }

    if (search) {
        products = products.filter(p => p.name.toLowerCase().includes(search.toLowerCase()));
    }

    const categories = ["Electronics", "Furniture", "Kitchen", "Fitness"];

    return res.html("products.html", { products, categories, search, selected_category: selectedCategory });
});
```

---

## 17. Gotchas

### 1. CSS Not Loading

**Problem:** The page looks unstyled -- no colors, no layout, plain text.

**Cause:** The path to `tina4.css` is wrong. The file lives in `src/public/css/` but the link points elsewhere.

**Fix:** Tina4 serves everything in `src/public/` from the root path. Link to `/css/tina4.css` (not `/src/public/css/tina4.css`). Verify the file exists at `src/public/css/tina4.css`.

### 2. frond.js Functions Not Found

**Problem:** `frond.get is not a function` or `frond is not defined` in the browser console.

**Cause:** The `frond.min.js` script tag is missing or placed after the code that uses it.

**Fix:** Include `<script src="/js/frond.min.js"></script>` before any script that calls `frond.*`. Put it at the bottom of the body, before your custom scripts.

### 3. Dark Mode Flickers on Page Load

**Problem:** The page loads in light mode and then flashes to dark mode.

**Cause:** The dark mode JavaScript runs after the page renders. The browser paints the light theme first, then switches.

**Fix:** Add the theme detection script in the `<head>` (before the body renders):

```html
<head>
    <script>
        var t = localStorage.getItem("theme");
        if (t) document.documentElement.setAttribute("data-theme", t);
    </script>
</head>
```

### 4. SCSS Not Compiling

**Problem:** You edited `tina4.scss` but the CSS did not change.

**Cause:** SCSS does not compile on its own. You need to run `tina4 scss` or use `--watch` mode.

**Fix:** Run `tina4 scss --watch` during development. For production builds, run `tina4 scss` as part of your build process.

### 5. Modal Does Not Open

**Problem:** Clicking the button does nothing -- the modal stays hidden.

**Cause:** The `data-toggle` and `data-target` attributes require frond.js to be loaded. Without it, no JavaScript handles the modal toggle.

**Fix:** Ensure `frond.min.js` is loaded. Verify the `data-target` matches the modal's `id` exactly (including the `#` prefix).

### 6. Grid Columns Do Not Stack on Mobile

**Problem:** Columns stay side-by-side on phone screens instead of stacking vertically.

**Cause:** You used `col-4` instead of `col-md-4`. The `col-4` class applies at all screen sizes.

**Fix:** Use responsive prefixes: `col-md-4` means "one-third on medium screens and up, full width on small screens."

### 7. Static Files Return 404

**Problem:** CSS, JS, or image files return 404 Not Found.

**Cause:** The files are not in the `src/public/` directory.

**Fix:** Static files must be in `src/public/`. The URL path maps to the file path within that directory. `/css/tina4.css` maps to `src/public/css/tina4.css`.

### 8. Form Data Not Reaching the Server

**Problem:** `frond.post()` sends the request but `req.body` is empty on the server.

**Cause:** frond.js sends JSON by default. Passing a `FormData` object or building the data object wrong prevents correct parsing.

**Fix:** Pass a plain JavaScript object to `frond.post()`. Do not use `new FormData()` -- frond.js handles serialization. Make sure your object keys match what the server expects.

### 9. Loading Indicator Never Disappears

**Problem:** The loading spinner shows but never hides after the AJAX request completes.

**Cause:** The CSS selector passed to the `loading` option does not match any element, or the element uses a CSS class to toggle visibility instead of inline `display`.

**Fix:** frond.js toggles `display: block` and `display: none`. Make sure the element exists and its initial style is `display: none`. Use an `id` selector: `{ loading: "#loadingSpinner" }`.

### 10. CORS Errors with Separate Frontend

**Fix:** Set `CORS_ORIGINS` in `.env`.

### 11. Large Bundle Sizes

**Fix:** Use code splitting. Serve static assets from a CDN.

### 12. React Router Conflicts

**Fix:** Add a catch-all route that serves `index.html` for client-side routing.

---

## 18. HtmlElement — Programmatic HTML Builder

Build HTML in TypeScript without string concatenation:

```typescript
import { HtmlElement, htmlElement, addHtmlHelpers } from "@tina4/core";

const el = new HtmlElement("div", { class: "card" }, ["Hello"]);
el.toString(); // '<div class="card">Hello</div>'

// Nesting
const card = new HtmlElement("div", { class: "card" }, [
    new HtmlElement("h2", {}, ["Title"]),
    new HtmlElement("p", {}, ["Content"]),
]);

// Helper functions
const h: Record<string, any> = {};
addHtmlHelpers(h);
const html = h._div({ class: "card" }, h._p("Hello"), h._a({ href: "/" }, "Home"));
```

Void tags (`<br>`, `<img>`, `<input>`) render without closing tags. Boolean attributes render as bare names.
