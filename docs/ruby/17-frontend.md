# Chapter 15: Frontend with tina4css

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

## 11. Exercise: Build a Product Management Page

Build a product management page with a table, add/edit form, and AJAX interactions.

### Requirements

1. `GET /admin/products` -- HTML page with a product table and "Add Product" form
2. Use frond.js for AJAX form submission
3. Display flash messages for success/error
4. Include search and category filter

---

## 12. Solution

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

## 13. Gotchas

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
