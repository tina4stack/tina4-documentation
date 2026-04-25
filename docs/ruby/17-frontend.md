# Chapter 17: Frontend with tina4css

## 1. The Problem with Frontend Toolchains

Your client wants a dashboard. Install Node.js. Run `npm install`. Wait for 200MB of `node_modules`. Configure webpack or Vite. Set up PostCSS. Add a CSS framework. Maybe Tailwind with its purge config. Pray nothing breaks when you upgrade a dependency in 6 months.

Tina4 skips all of that. The framework ships with **tina4css** -- a Bootstrap-compatible CSS framework -- and **frond.js** -- a lightweight JavaScript helper library. Both land in your project when you scaffold. No npm. No webpack. No build step. Link the files. Start building.

By the end of this chapter, you will have a complete admin dashboard with a sidebar, navigation, cards, tables, modals, and dark mode support. Zero npm involvement.

---

## 2. What Ships with Tina4

When you run `tina4 init`, two files appear in your project:

```
src/public/
├── css/
│   └── tina4.css        # The CSS framework
├── js/
│   └── frond.js         # AJAX helpers, form submission, token management
└── scss/
    └── tina4.scss       # SCSS source (optional, for customization)
```

Include them in any template:

```html
<link rel="stylesheet" href="/css/tina4.css">
<script src="/js/frond.js"></script>
```

---

## 3. The Grid System

tina4css uses a 12-column responsive grid, compatible with Bootstrap's class names:

```html
<div class="container">
    <div class="row">
        <div class="col-md-4"><p>One third</p></div>
        <div class="col-md-4"><p>One third</p></div>
        <div class="col-md-4"><p>One third</p></div>
    </div>
</div>
```

### Responsive Breakpoints

| Prefix | Min Width | Typical Device |
|--------|-----------|----------------|
| `col-` | 0px | All |
| `col-sm-` | 576px | Phones (landscape) |
| `col-md-` | 768px | Tablets |
| `col-lg-` | 992px | Laptops |
| `col-xl-` | 1200px | Desktops |

---

## 4. Cards

```html
<div class="card">
    <div class="card-header">Product Details</div>
    <div class="card-body">
        <h3 class="card-title">Wireless Keyboard</h3>
        <p class="card-text">Ergonomic keyboard with backlit keys.</p>
        <p class="price">$79.99</p>
    </div>
    <div class="card-footer">
        <button class="btn btn-primary">Add to Cart</button>
    </div>
</div>
```

### Card Grid

```html
<div class="row">
    {% for product in products %}
        <div class="col-md-4">
            <div class="card">
                <div class="card-body">
                    <h3 class="card-title">{{ product.name }}</h3>
                    <p class="card-text">${{ product.price | number_format(2) }}</p>
                    <button class="btn btn-primary btn-sm">View</button>
                </div>
            </div>
        </div>
    {% endfor %}
</div>
```

---

## 5. Tables

```html
<table class="table table-striped table-hover">
    <thead>
        <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Price</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        {% for product in products %}
            <tr>
                <td>{{ product.id }}</td>
                <td>{{ product.name }}</td>
                <td>${{ product.price | number_format(2) }}</td>
                <td>
                    <button class="btn btn-sm btn-primary">Edit</button>
                    <button class="btn btn-sm btn-danger">Delete</button>
                </td>
            </tr>
        {% endfor %}
    </tbody>
</table>
```

---

## 6. Forms

```html
<form method="POST" action="/api/products">
    <div class="form-group">
        <label for="name">Product Name</label>
        <input type="text" class="form-control" id="name" name="name" required>
    </div>
    <div class="form-group">
        <label for="price">Price</label>
        <input type="number" class="form-control" id="price" name="price" step="0.01" required>
    </div>
    <div class="form-group">
        <label for="category">Category</label>
        <select class="form-control" id="category" name="category">
            <option value="Electronics">Electronics</option>
            <option value="Fitness">Fitness</option>
            <option value="Kitchen">Kitchen</option>
            <option value="Office">Office</option>
        </select>
    </div>
    <button type="submit" class="btn btn-primary">Create Product</button>
</form>
```

---

## 7. Buttons and Alerts

### Buttons

```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-success">Success</button>
<button class="btn btn-danger">Danger</button>
<button class="btn btn-warning">Warning</button>
<button class="btn btn-info">Info</button>
<button class="btn btn-outline-primary">Outline</button>
<button class="btn btn-sm btn-primary">Small</button>
<button class="btn btn-lg btn-primary">Large</button>
```

### Alerts

```html
<div class="alert alert-success">Product created successfully!</div>
<div class="alert alert-danger">Error: Name is required.</div>
<div class="alert alert-warning">Stock is running low.</div>
<div class="alert alert-info">New features are available.</div>
```

---

## 8. frond.js -- AJAX Without jQuery

`frond.js` provides lightweight AJAX helpers for form submission, API calls, and token management.

### API Calls

```javascript
// GET request
frond.get("/api/products", function (data) {
    console.log(data.products);
});

// POST request
frond.post("/api/products", {
    name: "Widget",
    price: 9.99
}, function (data) {
    console.log("Created:", data);
});

// PUT request
frond.put("/api/products/1", {
    name: "Updated Widget",
    price: 12.99
}, function (data) {
    console.log("Updated:", data);
});

// DELETE request
frond.del("/api/products/1", function (data) {
    console.log("Deleted");
});
```

### Token Management

```javascript
// Store token after login
frond.post("/api/login", { email: "alice@example.com", password: "pass123" }, function (data) {
    frond.setToken(data.token);
});

// All subsequent requests automatically include the Authorization header
frond.get("/api/profile", function (data) {
    console.log(data);  // Token is sent automatically
});
```

### Form Submission via AJAX

```html
<form id="product-form" data-frond-submit="/api/products" data-frond-method="POST">
    <div class="form-group">
        <label for="name">Name</label>
        <input type="text" class="form-control" name="name" id="name">
    </div>
    <button type="submit" class="btn btn-primary">Create</button>
</form>

<div id="result"></div>

<script>
    frond.onSubmit("#product-form", function (data) {
        document.getElementById("result").innerHTML = '<div class="alert alert-success">Product created: ' + data.name + '</div>';
    });
</script>
```

---

## 9. Dark Mode

tina4css supports dark mode via a CSS class on the `<html>` or `<body>` element:

```html
<html data-theme="dark">
```

Toggle with JavaScript:

```javascript
function toggleDarkMode() {
    const html = document.documentElement;
    const current = html.getAttribute("data-theme");
    html.setAttribute("data-theme", current === "dark" ? "light" : "dark");
    localStorage.setItem("theme", html.getAttribute("data-theme"));
}

// Load saved theme
const savedTheme = localStorage.getItem("theme") || "light";
document.documentElement.setAttribute("data-theme", savedTheme);
```

---

## 10. Building a Dashboard

Here is a complete admin dashboard template:

Create `src/templates/dashboard.html`:

```html
{% extends "base.html" %}

{% block title %}Dashboard{% endblock %}

{% block content %}
    <h1>Dashboard</h1>

    <div class="row">
        <div class="col-md-3">
            <div class="card">
                <div class="card-body text-center">
                    <h2>{{ stats.total_products }}</h2>
                    <p class="text-muted">Products</p>
                </div>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card">
                <div class="card-body text-center">
                    <h2>{{ stats.total_orders }}</h2>
                    <p class="text-muted">Orders</p>
                </div>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card">
                <div class="card-body text-center">
                    <h2>${{ stats.revenue | number_format(2) }}</h2>
                    <p class="text-muted">Revenue</p>
                </div>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card">
                <div class="card-body text-center">
                    <h2>{{ stats.total_users }}</h2>
                    <p class="text-muted">Users</p>
                </div>
            </div>
        </div>
    </div>

    <div class="row mt-4">
        <div class="col-md-8">
            <div class="card">
                <div class="card-header">Recent Orders</div>
                <div class="card-body">
                    <table class="table table-striped">
                        <thead>
                            <tr><th>Order</th><th>Customer</th><th>Total</th><th>Status</th></tr>
                        </thead>
                        <tbody>
                            {% for order in recent_orders %}
                                <tr>
                                    <td>#{{ order.id }}</td>
                                    <td>{{ order.customer }}</td>
                                    <td>${{ order.total | number_format(2) }}</td>
                                    <td><span class="badge badge-{{ order.status_class }}">{{ order.status }}</span></td>
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
                    <a href="/admin/orders" class="btn btn-secondary btn-block mb-2">View Orders</a>
                    <a href="/admin/users" class="btn btn-secondary btn-block">Manage Users</a>
                </div>
            </div>
        </div>
    </div>
{% endblock %}
```

Route handler:

```ruby
Tina4::Router.get("/admin") do |request, response|
  response.render("dashboard.html", {
    stats: {
      total_products: 156,
      total_orders: 1423,
      revenue: 45678.90,
      total_users: 342
    },
    recent_orders: [
      { id: 1001, customer: "Alice Smith", total: 159.98, status: "Shipped", status_class: "success" },
      { id: 1000, customer: "Bob Jones", total: 49.99, status: "Processing", status_class: "warning" },
      { id: 999, customer: "Charlie Brown", total: 299.99, status: "Delivered", status_class: "info" }
    ]
  })
end
```

---

## 11. SCSS Customization

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

## 12. frond.js API Reference

Tina4 ships three JavaScript files. Each serves a different purpose. Use them independently or together.

### Including the Scripts

```html
<script src="/js/tina4.min.js"></script>
<script src="/js/frond.min.js"></script>
<script src="/js/tina4js.min.js"></script>
```

All three live in `src/public/js/` and are served from `/js/`. Include only what you need.

### tina4.min.js -- Core Utilities

Low-level helpers for AJAX page loading and form submission.

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

Generic AJAX helper for any HTTP method.

```javascript
sendRequest("/api/products", "GET", null, function (response) {
    console.log("Products:", JSON.parse(response));
});

sendRequest("/api/products", "POST", { name: "Widget", price: 9.99 }, function (response) {
    console.log("Created:", JSON.parse(response));
});
```

### frond.min.js -- Template Engine Client-Side Helpers

A companion to the Frond template engine. Handles AJAX form interception, WebSocket connections with auto-reconnect, JWT token management, and dynamic template loading.

#### AJAX Requests

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
frond.put("/api/products/1", { name: "Updated Product" }, function (data) {
    console.log("Updated:", data);
});

// DELETE request
frond.delete("/api/products/1", function (data) {
    console.log("Deleted:", data);
});
```

#### Token Management

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

#### Loading Indicators

frond.js can show and hide a loading element during AJAX requests.

```javascript
frond.get("/api/products", function (data) {
    renderProducts(data.products);
}, null, {
    loading: "#loadingSpinner"
});
```

```html
<div id="loadingSpinner" class="text-center p-4" style="display: none;">
    Loading...
</div>
```

frond.js toggles `display: block` and `display: none` on the element. No extra CSS needed.

#### WebSocket Auto-Reconnect

```javascript
const ws = frond.ws("/ws/notifications");
ws.on("message", function (data) {
    const notification = JSON.parse(data);
    alert(notification.text);
});
// If the server restarts or the network blips, frond.js reconnects.
```

### tina4js.min.js -- Reactive Frontend Framework

A standalone reactive framework for building interactive client-side applications. Provides signals, computed values, effects, Web Components, client-side routing, and built-in fetch and WebSocket wrappers.

#### Reactive State

```javascript
import { signal, computed, effect } from "/js/tina4js.min.js";

const count = signal(0);
const doubled = computed(() => count.value * 2);

effect(() => {
    console.log(`Count: ${count.value}, Doubled: ${doubled.value}`);
});

count.value = 5; // logs "Count: 5, Doubled: 10"
```

#### Web Components

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

---

## 13. Responsive Design

tina4css includes responsive breakpoints for adapting layouts to different screen sizes:

| Breakpoint | Min Width | Class Prefix |
|------------|-----------|-------------|
| Extra small | 0px | (none -- default) |
| Small | 576px | `sm-` |
| Medium | 768px | `md-` |
| Large | 992px | `lg-` |
| Extra large | 1200px | `xl-` |

### Responsive Columns

```html
<div class="row">
    <!-- Full width on mobile, half on medium, third on large -->
    <div class="col-12 col-md-6 col-lg-4">Product 1</div>
    <div class="col-12 col-md-6 col-lg-4">Product 2</div>
    <div class="col-12 col-md-6 col-lg-4">Product 3</div>
</div>
```

### Responsive Visibility

```html
<!-- Hidden on mobile, visible on medium and up -->
<div class="d-none d-md-block">Desktop Sidebar</div>

<!-- Visible on mobile only -->
<div class="d-block d-md-none">Mobile Menu</div>
```

---

## 14. Building a Users Page with AJAX

A single-page admin view that loads data without page reloads:

```html
{% extends "base.html" %}

{% block title %}User Management{% endblock %}

{% block content %}
<h2>User Management</h2>

<div id="loadingSpinner" class="text-center p-4" style="display: none;">
    Loading users...
</div>

<div id="user-list"></div>

<script src="/js/frond.min.js"></script>
<script>
    function loadUsers() {
        frond.get("/api/users", function (data) {
            var html = '<table class="table"><thead><tr>' +
                '<th>ID</th><th>Name</th><th>Email</th><th>Actions</th>' +
                '</tr></thead><tbody>';

            data.users.forEach(function (user) {
                html += '<tr>' +
                    '<td>' + user.id + '</td>' +
                    '<td>' + user.name + '</td>' +
                    '<td>' + user.email + '</td>' +
                    '<td><button class="btn btn-sm btn-danger" ' +
                    'onclick="deleteUser(' + user.id + ')">Delete</button></td>' +
                    '</tr>';
            });

            html += '</tbody></table>';
            document.getElementById("user-list").innerHTML = html;
        }, null, { loading: "#loadingSpinner" });
    }

    function deleteUser(id) {
        frond.delete("/api/users/" + id, function () {
            loadUsers();
        });
    }

    loadUsers();
</script>
{% endblock %}
```

The page loads instantly. frond.js fetches user data in the background. Delete a user and the list refreshes without a page reload.

---

## 15. Exercise: Build a Product Management Page

Build a product management page with a table, add/edit form, and AJAX interactions.

### Requirements

1. `GET /admin/products` -- HTML page with a product table and "Add Product" form
2. Use frond.js for AJAX form submission
3. Display flash messages for success/error
4. Include search and category filter

---

## 16. Solution

Create `src/templates/admin-products.html` with a table displaying products, a form for adding new ones using `data-frond-submit`, and JavaScript handlers using `frond.post` and `frond.get` for CRUD operations. The template extends `base.html` and uses tina4css for styling.

Create `src/routes/admin_products.rb`:

```ruby
Tina4::Router.get("/admin/products") do |request, response|
  db = Tina4.database
  products = db.fetch("SELECT * FROM products ORDER BY name")

  response.render("admin-products.html", {
    products: products,
    count: products.length
  })
end
```

---

## 17. Gotchas

### 1. tina4css Classes Do Not Work

**Problem:** CSS classes have no effect.

**Fix:** Make sure `<link rel="stylesheet" href="/css/tina4.css">` is in your HTML head.

### 2. frond.js Not Loading

**Problem:** `frond is not defined` error in the browser console.

**Fix:** Make sure `<script src="/js/frond.js"></script>` is included before your custom scripts.

### 3. AJAX Calls Return HTML Instead of JSON

**Problem:** `frond.get` returns HTML instead of JSON.

**Fix:** Your route handler is returning `response.render` instead of `response.json`. API endpoints should use `response.json`.

### 4. Forms Submit Twice

**Problem:** The form submits via AJAX and then also submits normally.

**Fix:** Call `event.preventDefault()` in your submit handler, or use `data-frond-submit` which handles this automatically.

### 5. Dark Mode Resets on Page Load

**Problem:** Dark mode resets to light mode when navigating.

**Fix:** Save the theme preference in `localStorage` and apply it on page load before the page renders.

### 6. Bootstrap Classes Not Working

**Problem:** Some Bootstrap classes do not work with tina4css.

**Fix:** tina4css is Bootstrap-compatible but not a complete clone. Stick to the documented classes. Complex Bootstrap components (modals, tooltips) require additional JavaScript.

### 7. SCSS Changes Not Reflected

**Problem:** You edited `tina4.scss` but the browser shows the old CSS.

**Fix:** Compile SCSS to CSS with `tina4 build:css` or `sass src/public/scss/tina4.scss src/public/css/tina4.css`. The browser loads the compiled CSS file, not the SCSS source.

---

## 18. HtmlElement — Programmatic HTML Builder

Build HTML in Ruby without string concatenation:

```ruby
el = Tina4::HtmlElement.new("div", { class: "card" }, ["Hello"])
el.to_s  # => '<div class="card">Hello</div>'

# Nesting
card = Tina4::HtmlElement.new("div", { class: "card" }, [
  Tina4::HtmlElement.new("h2", {}, ["Title"]),
  Tina4::HtmlElement.new("p", {}, ["Content"]),
])

# HtmlHelpers mixin
include Tina4::HtmlHelpers
html = _div({ class: "card" }, _p("Hello"), _a({ href: "/" }, "Home"))
```

Void tags (`<br>`, `<img>`, `<input>`) render without closing tags. Boolean attributes render as bare names.
