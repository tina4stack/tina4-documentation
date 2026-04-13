# Chapter 17: Frontend with tina4css

## 1. The Problem with Frontend Toolchains

Your client wants a dashboard. You know the drill. Install Node.js. Run `npm install`. Watch 200MB of `node_modules` download. Configure webpack or Vite. Set up PostCSS. Add a CSS framework. Maybe Tailwind with its purge config. Pray nothing breaks when you upgrade a dependency six months later.

Tina4 takes a different path. The framework ships with **tina4css** -- a Bootstrap-compatible CSS framework -- and **frond.js** -- a lightweight JavaScript helper library. Both arrive when you scaffold a project. No npm. No webpack. No build step. Link the files. Start building.

By the end of this chapter, you have a complete admin dashboard with sidebar, navigation, cards, tables, modals, and dark mode support. Zero npm dependencies.

---

## 2. What Ships with Tina4

Run `tina4 init`. Two files appear in your project:

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

That is everything. No CDN. No package manager. No version conflicts.

---

## 3. The Grid System

tina4css uses a 12-column responsive grid, compatible with Bootstrap's class names. Know Bootstrap? You know tina4css.

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
            <li class="nav-item">
                <a class="nav-link active" href="/dashboard">Dashboard</a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="/users">Users</a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="/settings">Settings</a>
            </li>
        </ul>
    </div>
</nav>
```

Use `navbar-light bg-light` for a light theme, or `navbar-dark bg-primary` for a colored background.

### Buttons

```html
<button class="btn btn-primary">Save</button>
<button class="btn btn-secondary">Cancel</button>
<button class="btn btn-danger">Delete</button>
<button class="btn btn-success">Approve</button>
<button class="btn btn-warning">Warning</button>
<button class="btn btn-outline-primary">Outlined</button>
<button class="btn btn-sm btn-primary">Small</button>
<button class="btn btn-lg btn-primary">Large</button>
```

### Cards

```html
<div class="card">
    <div class="card-header">
        Monthly Revenue
    </div>
    <div class="card-body">
        <h5 class="card-title">$12,450</h5>
        <p class="card-text">Up 8% from last month</p>
    </div>
    <div class="card-footer text-muted">
        Updated 5 minutes ago
    </div>
</div>
```

### Forms

```html
<form>
    <div class="form-group">
        <label for="email">Email address</label>
        <input type="email" class="form-control" id="email"
               placeholder="you@example.com">
    </div>
    <div class="form-group">
        <label for="password">Password</label>
        <input type="password" class="form-control" id="password">
    </div>
    <div class="form-group form-check">
        <input type="checkbox" class="form-check-input" id="remember">
        <label class="form-check-label" for="remember">Remember me</label>
    </div>
    <button type="submit" class="btn btn-primary">Sign In</button>
</form>
```

### Tables

```html
<table class="table table-striped table-hover">
    <thead>
        <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Role</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>1</td>
            <td>Alice Johnson</td>
            <td>alice@example.com</td>
            <td><span class="badge badge-primary">Admin</span></td>
            <td>
                <button class="btn btn-sm btn-outline-primary">Edit</button>
                <button class="btn btn-sm btn-outline-danger">Delete</button>
            </td>
        </tr>
        <tr>
            <td>2</td>
            <td>Bob Smith</td>
            <td>bob@example.com</td>
            <td><span class="badge badge-secondary">User</span></td>
            <td>
                <button class="btn btn-sm btn-outline-primary">Edit</button>
                <button class="btn btn-sm btn-outline-danger">Delete</button>
            </td>
        </tr>
    </tbody>
</table>
```

Table variants: `table-bordered`, `table-striped`, `table-hover`, `table-sm` (compact), `table-responsive` (wraps in a scrollable container on small screens). Mix and match.

### Badges

```html
<span class="badge badge-primary">Primary</span>
<span class="badge badge-success">Active</span>
<span class="badge badge-warning">Pending</span>
<span class="badge badge-danger">Overdue</span>
<span class="badge badge-info">Info</span>
<span class="badge badge-dark">Dark</span>
```

### Alerts

```html
<div class="alert alert-success">
    Product saved successfully.
</div>

<div class="alert alert-danger">
    Error: could not connect to the database.
</div>

<div class="alert alert-warning alert-dismissible">
    Your trial expires in 3 days.
    <button type="button" class="close" data-dismiss="alert">&times;</button>
</div>

<div class="alert alert-info">
    Tip: you can drag and drop items to reorder them.
</div>
```

### Modals

```html
<button class="btn btn-primary" data-toggle="modal" data-target="#confirmModal">
    Delete User
</button>

<div class="modal" id="confirmModal">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Confirm Deletion</h5>
                <button type="button" class="close" data-dismiss="modal">&times;</button>
            </div>
            <div class="modal-body">
                <p>Are you sure you want to delete this user? This action cannot be undone.</p>
            </div>
            <div class="modal-footer">
                <button class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button class="btn btn-danger">Delete</button>
            </div>
        </div>
    </div>
</div>
```

tina4css includes the JavaScript needed for modal toggling. No jQuery required.

### Progress Bars

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

---

## 5. SCSS Customization

The SCSS source lives in `src/public/scss/tina4.scss`. Customize colors, fonts, or spacing here. Compile to CSS when ready.

### Variables

At the top of `tina4.scss`, you will find variables you can override:

```scss
// Colors
$primary:   #007bff;
$secondary: #6c757d;
$success:   #28a745;
$danger:    #dc3545;
$warning:   #ffc107;
$info:      #17a2b8;
$dark:      #343a40;
$light:     #f8f9fa;

// Typography
$font-family-base: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
$font-size-base: 1rem;
$line-height-base: 1.5;

// Spacing
$spacer: 1rem;

// Border radius
$border-radius: 0.25rem;

// Breakpoints
$breakpoint-sm: 576px;
$breakpoint-md: 768px;
$breakpoint-lg: 992px;
$breakpoint-xl: 1200px;
```

### Compiling SCSS

If you edit the SCSS files, compile them with the Tina4 CLI:

```bash
tina4 scss
```

```
Compiling SCSS...
  src/public/scss/tina4.scss → src/public/css/tina4.css
Done.
```

This reads all `.scss` files from `src/public/scss/` and writes compiled CSS to `src/public/css/`. No Sass gem. No Node. No additional dependencies. The Tina4 CLI includes a built-in SCSS compiler.

You can also run it in watch mode during development:

```bash
tina4 scss --watch
```

```
Watching src/public/scss/ for changes...
  [14:30:05] Compiled tina4.scss → tina4.css (42ms)
```

Every time you save a `.scss` file, it recompiles automatically.

### Custom Theme Example

Create `src/public/scss/custom.scss`:

```scss
// Override variables before importing tina4
$primary: #6f42c1;
$font-family-base: "Inter", sans-serif;
$border-radius: 0.5rem;

// Import the base framework
@import "tina4";

// Add your own styles
.sidebar {
    background: $dark;
    color: $light;
    min-height: 100vh;
    padding: 1rem;

    .nav-link {
        color: rgba(255, 255, 255, 0.7);
        padding: 0.5rem 1rem;
        border-radius: $border-radius;

        &:hover, &.active {
            color: #fff;
            background: rgba(255, 255, 255, 0.1);
        }
    }
}
```

Compile:

```bash
tina4 scss
```

Then reference your custom CSS in your template:

```html
<link rel="stylesheet" href="/css/custom.css">
```

---

## 6. frond.js -- The JavaScript Helper

frond.js is a lightweight JavaScript library that ships with Tina4. AJAX helpers. Form submission. JWT token management. No jQuery. No Axios. No other library.

### AJAX Requests

```javascript
// GET request
frond.get("/api/products", function (data) {
    console.log(data.products);
});

// GET with error handling
frond.get("/api/products", function (data) {
    console.log(data);
}, function (error) {
    console.error("Failed:", error);
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
frond.delete("/api/products/1", function (data) {
    console.log("Deleted");
});
```

### Form Submission

frond.js can intercept form submissions and send them via AJAX instead of a full page reload:

```html
<form id="createProduct" data-frond-submit="/api/products" data-frond-method="POST">
    <div class="form-group">
        <label for="name">Product Name</label>
        <input type="text" class="form-control" name="name" id="name">
    </div>
    <div class="form-group">
        <label for="price">Price</label>
        <input type="number" class="form-control" name="price" id="price" step="0.01">
    </div>
    <button type="submit" class="btn btn-primary">Create Product</button>
</form>

<div id="result"></div>

<script>
    frond.onSubmit("createProduct", function (response) {
        document.getElementById("result").innerHTML =
            '<div class="alert alert-success">Product created: ' + response.name + '</div>';
    }, function (error) {
        document.getElementById("result").innerHTML =
            '<div class="alert alert-danger">Error: ' + error.message + '</div>';
    });
</script>
```

The `data-frond-submit` attribute tells frond.js the URL to POST to. The `data-frond-method` attribute specifies the HTTP method. frond.js serializes all form fields as JSON automatically.

### Token Management

When your application uses JWT authentication (Chapter 8), frond.js manages tokens automatically:

```javascript
// Store the token after login
frond.setToken("eyJhbGciOiJIUzI1NiIs...");

// All subsequent requests include the Authorization header automatically
frond.get("/api/profile", function (data) {
    // The request included: Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
    console.log(data);
});

// Clear the token on logout
frond.clearToken();
```

frond.js stores the token in `localStorage` and includes it as a `Bearer` token in the `Authorization` header on every request.

### Loading Indicators

```javascript
// Show a loading state while fetching
frond.get("/api/products", function (data) {
    renderProducts(data.products);
}, null, {
    loading: "#loadingSpinner"  // CSS selector for loading element
});
```

The element with id `loadingSpinner` will be shown while the request is in flight and hidden when it completes.

---

## 7. Building a Dashboard Layout

A real admin dashboard. Template layout with sidebar, top navbar, and content area.

### The Base Layout

Create `src/templates/admin/layout.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Admin Dashboard{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }

        .app-wrapper { display: flex; min-height: 100vh; }

        .sidebar {
            width: 250px;
            background: #1a1a2e;
            color: #e0e0e0;
            padding: 0;
            flex-shrink: 0;
        }
        .sidebar-header {
            padding: 20px;
            font-size: 1.2em;
            font-weight: bold;
            color: #fff;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .sidebar-nav { list-style: none; padding: 10px 0; }
        .sidebar-nav li a {
            display: block;
            padding: 10px 20px;
            color: rgba(255,255,255,0.7);
            text-decoration: none;
            transition: all 0.2s;
        }
        .sidebar-nav li a:hover,
        .sidebar-nav li a.active {
            color: #fff;
            background: rgba(255,255,255,0.1);
        }
        .sidebar-nav li a .badge {
            float: right;
            margin-top: 2px;
        }

        .main-content { flex: 1; background: #f5f5f5; }

        .topbar {
            background: #fff;
            padding: 12px 24px;
            border-bottom: 1px solid #e0e0e0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .topbar-title { font-size: 1.1em; font-weight: 600; }
        .topbar-actions { display: flex; gap: 12px; align-items: center; }

        .content-area { padding: 24px; }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 20px;
            margin-bottom: 24px;
        }

        .stat-card {
            background: #fff;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .stat-card .stat-value { font-size: 2em; font-weight: bold; }
        .stat-card .stat-label { color: #888; margin-top: 4px; }
        .stat-card .stat-change { font-size: 0.85em; margin-top: 8px; }
        .stat-card .stat-change.up { color: #28a745; }
        .stat-card .stat-change.down { color: #dc3545; }

        @media (max-width: 768px) {
            .sidebar { display: none; }
            .stats-grid { grid-template-columns: 1fr; }
        }
    </style>
    {% block extra_css %}{% endblock %}
</head>
<body>
    <div class="app-wrapper">
        <aside class="sidebar">
            <div class="sidebar-header">Admin Panel</div>
            <ul class="sidebar-nav">
                <li><a href="/admin" class="{% if active_page == 'dashboard' %}active{% endif %}">Dashboard</a></li>
                <li><a href="/admin/users" class="{% if active_page == 'users' %}active{% endif %}">Users</a></li>
                <li><a href="/admin/products" class="{% if active_page == 'products' %}active{% endif %}">Products</a></li>
                <li>
                    <a href="/admin/orders" class="{% if active_page == 'orders' %}active{% endif %}">
                        Orders
                        {% if pending_orders > 0 %}
                            <span class="badge badge-warning">{{ pending_orders }}</span>
                        {% endif %}
                    </a>
                </li>
                <li><a href="/admin/settings" class="{% if active_page == 'settings' %}active{% endif %}">Settings</a></li>
            </ul>
        </aside>

        <div class="main-content">
            <div class="topbar">
                <span class="topbar-title">{% block page_title %}Dashboard{% endblock %}</span>
                <div class="topbar-actions">
                    <span>Welcome, {{ user_name | default("Admin") }}</span>
                    <button class="btn btn-sm btn-outline-danger">Logout</button>
                </div>
            </div>

            <div class="content-area">
                {% block content %}{% endblock %}
            </div>
        </div>
    </div>

    <script src="/js/frond.js"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
```

### The Dashboard Page

Create `src/templates/admin/dashboard.html`:

```html
{% extends "admin/layout.html" %}

{% block title %}Dashboard - Admin{% endblock %}
{% block page_title %}Dashboard{% endblock %}

{% block content %}
    <div class="stats-grid">
        {% for stat in stats %}
            <div class="stat-card">
                <div class="stat-value">{{ stat.value }}</div>
                <div class="stat-label">{{ stat.label }}</div>
                <div class="stat-change {{ stat.direction }}">
                    {{ stat.direction == "up" ? "+" : "" }}{{ stat.change }}% from last month
                </div>
            </div>
        {% endfor %}
    </div>

    <div class="row">
        <div class="col-md-8">
            <div class="card">
                <div class="card-header">Recent Orders</div>
                <div class="card-body" style="padding: 0;">
                    <table class="table table-hover" style="margin: 0;">
                        <thead>
                            <tr>
                                <th>Order ID</th>
                                <th>Customer</th>
                                <th>Total</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for order in recent_orders %}
                                <tr>
                                    <td>#{{ order.id }}</td>
                                    <td>{{ order.customer }}</td>
                                    <td>${{ order.total | number_format(2) }}</td>
                                    <td>
                                        {% if order.status == "completed" %}
                                            <span class="badge badge-success">Completed</span>
                                        {% elseif order.status == "pending" %}
                                            <span class="badge badge-warning">Pending</span>
                                        {% elseif order.status == "cancelled" %}
                                            <span class="badge badge-danger">Cancelled</span>
                                        {% endif %}
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
                    <button class="btn btn-primary btn-block" style="margin-bottom: 8px;">
                        Add New Product
                    </button>
                    <button class="btn btn-outline-primary btn-block" style="margin-bottom: 8px;">
                        View Reports
                    </button>
                    <button class="btn btn-outline-secondary btn-block">
                        Export Data
                    </button>
                </div>
            </div>

            <div class="card" style="margin-top: 20px;">
                <div class="card-header">System Health</div>
                <div class="card-body">
                    <p><strong>CPU:</strong></p>
                    <div class="progress" style="margin-bottom: 12px;">
                        <div class="progress-bar bg-success" style="width: {{ cpu_usage }}%">
                            {{ cpu_usage }}%
                        </div>
                    </div>
                    <p><strong>Memory:</strong></p>
                    <div class="progress" style="margin-bottom: 12px;">
                        <div class="progress-bar bg-info" style="width: {{ memory_usage }}%">
                            {{ memory_usage }}%
                        </div>
                    </div>
                    <p><strong>Disk:</strong></p>
                    <div class="progress">
                        <div class="progress-bar bg-warning" style="width: {{ disk_usage }}%">
                            {{ disk_usage }}%
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
{% endblock %}
```

### The Dashboard Route

Create `src/routes/admin.php`:

```php
<?php
use Tina4\Router;

Router::get("/admin", function ($request, $response) {
    $stats = [
        ["label" => "Total Users", "value" => "1,247", "change" => 12, "direction" => "up"],
        ["label" => "Revenue", "value" => "$34,500", "change" => 8, "direction" => "up"],
        ["label" => "Orders", "value" => "456", "change" => 3, "direction" => "down"],
        ["label" => "Conversion Rate", "value" => "3.2%", "change" => 0.5, "direction" => "up"]
    ];

    $recentOrders = [
        ["id" => 1042, "customer" => "Alice Johnson", "total" => 149.99, "status" => "completed"],
        ["id" => 1041, "customer" => "Bob Smith", "total" => 89.50, "status" => "pending"],
        ["id" => 1040, "customer" => "Carol Davis", "total" => 234.00, "status" => "completed"],
        ["id" => 1039, "customer" => "David Lee", "total" => 45.99, "status" => "cancelled"],
        ["id" => 1038, "customer" => "Eva Martinez", "total" => 178.25, "status" => "pending"]
    ];

    return $response->render("admin/dashboard.html", [
        "active_page" => "dashboard",
        "user_name" => "Admin",
        "pending_orders" => 2,
        "stats" => $stats,
        "recent_orders" => $recentOrders,
        "cpu_usage" => 42,
        "memory_usage" => 68,
        "disk_usage" => 55
    ]);
});
```

Start the server. Visit `http://localhost:7146/admin`. You see:

- Dark sidebar on the left with navigation links
- Top bar with a welcome message and logout button
- Four stat cards showing users, revenue, orders, and conversion rate
- Recent orders table with color-coded status badges
- Quick action buttons in a card on the right
- System health progress bars

Zero npm dependencies.

---

## 8. Dark Mode Support

tina4css includes built-in dark mode. One attribute on the `<html>` element:

```html
<html lang="en" data-theme="dark">
```

Light backgrounds become dark. Dark text becomes light. All components adapt.

### Toggle with JavaScript

Add a dark mode toggle button to your layout:

```html
<button class="btn btn-sm btn-outline-secondary" onclick="toggleDarkMode()">
    Toggle Dark Mode
</button>

<script>
    function toggleDarkMode() {
        const html = document.documentElement;
        const current = html.getAttribute("data-theme");
        const next = current === "dark" ? "light" : "dark";
        html.setAttribute("data-theme", next);
        localStorage.setItem("theme", next);
    }

    // Load saved preference
    const saved = localStorage.getItem("theme");
    if (saved) {
        document.documentElement.setAttribute("data-theme", saved);
    }
</script>
```

### Respecting System Preference

If the user has not set a preference, respect their operating system setting:

```javascript
const saved = localStorage.getItem("theme");
if (saved) {
    document.documentElement.setAttribute("data-theme", saved);
} else if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
    document.documentElement.setAttribute("data-theme", "dark");
}
```

### Custom Dark Mode Colors

In your SCSS, you can customize the dark mode palette:

```scss
[data-theme="dark"] {
    --bg-primary: #1a1a2e;
    --bg-secondary: #16213e;
    --text-primary: #e0e0e0;
    --text-secondary: #a0a0a0;
    --border-color: #2d2d4a;
    --card-bg: #16213e;
}
```

---

## 9. Responsive Design

tina4css is mobile-first. Components stack on small screens. They expand on larger screens.

### Responsive Utilities

Show and hide elements at different breakpoints:

```html
<!-- Only visible on medium screens and up -->
<div class="d-none d-md-block">
    Desktop sidebar content
</div>

<!-- Only visible on small screens -->
<div class="d-block d-md-none">
    Mobile navigation
</div>
```

### Responsive Tables

Wrap tables in a `.table-responsive` container to make them scroll horizontally on small screens:

```html
<div class="table-responsive">
    <table class="table">
        <!-- Wide table content -->
    </table>
</div>
```

### Spacing Utilities

Use margin and padding utilities that respond to breakpoints:

```html
<div class="p-2 p-md-4">Padding: 0.5rem on mobile, 1.5rem on desktop</div>
<div class="mt-2 mt-lg-5">Margin-top: 0.5rem on mobile, 3rem on large screens</div>
```

Spacing scale:

| Class | Size |
|-------|------|
| `*-0` | 0 |
| `*-1` | 0.25rem |
| `*-2` | 0.5rem |
| `*-3` | 1rem |
| `*-4` | 1.5rem |
| `*-5` | 3rem |

Directions: `m` (margin), `p` (padding), `t` (top), `b` (bottom), `l` (left), `r` (right), `x` (horizontal), `y` (vertical).

---

## 10. Building a Users Page with AJAX

A users management page. Data loads via AJAX using frond.js.

Create `src/templates/admin/users.html`:

```html
{% extends "admin/layout.html" %}

{% block title %}Users - Admin{% endblock %}
{% block page_title %}User Management{% endblock %}

{% block content %}
    <div class="card">
        <div class="card-header" style="display: flex; justify-content: space-between; align-items: center;">
            <span>All Users</span>
            <button class="btn btn-sm btn-primary" data-toggle="modal" data-target="#addUserModal">
                Add User
            </button>
        </div>
        <div class="card-body" style="padding: 0;">
            <div id="loadingSpinner" class="text-center p-4" style="display: none;">
                Loading...
            </div>
            <table class="table table-hover" id="usersTable" style="margin: 0;">
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
                    <button type="button" class="close" data-dismiss="modal">&times;</button>
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

    <div id="alertArea" style="margin-top: 16px;"></div>
{% endblock %}

{% block extra_js %}
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

Create the route for the users page:

```php
Router::get("/admin/users", function ($request, $response) {
    return $response->render("admin/users.html", [
        "active_page" => "users",
        "user_name" => "Admin",
        "pending_orders" => 2
    ]);
});
```

This page loads users via an AJAX call to `/api/users` (provided by auto-CRUD on the User model from Chapter 6). The table populates dynamically, and users can be added through a modal form and deleted with confirmation -- all without full page reloads.

---

## 11. Exercise: Build a Complete Admin Dashboard

Build an admin dashboard with the following features:

### Requirements

1. **Layout** -- Sidebar with navigation links for Dashboard, Products, and Orders. Top bar with the current user name and a dark mode toggle button.

2. **Dashboard Page** (`GET /admin`) -- Four stat cards (Total Products, Total Orders, Revenue, Low Stock Items). A table of the 5 most recent orders. A progress bar showing inventory health (percentage of products in stock).

3. **Products Page** (`GET /admin/products`) -- A table listing all products with columns: ID, Name, Category, Price, Stock Status. An "Add Product" button that opens a modal with a form. The form submits via frond.js AJAX to `POST /api/products`. After submission, the table reloads without a page refresh.

4. **Dark Mode** -- The toggle button switches between light and dark themes. The preference persists in localStorage.

### Seed Data

Create a route that populates sample data:

```php
Router::get("/admin/seed", function ($request, $response) {
    $products = [
        ["name" => "Wireless Keyboard", "category" => "Electronics", "price" => 79.99, "in_stock" => true],
        ["name" => "USB-C Hub", "category" => "Electronics", "price" => 49.99, "in_stock" => true],
        ["name" => "Standing Desk", "category" => "Furniture", "price" => 549.99, "in_stock" => false],
        ["name" => "Monitor Light", "category" => "Electronics", "price" => 39.99, "in_stock" => true],
        ["name" => "Ergonomic Chair", "category" => "Furniture", "price" => 399.99, "in_stock" => false]
    ];

    foreach ($products as $data) {
        $product = new Product();
        $product->name = $data["name"];
        $product->category = $data["category"];
        $product->price = $data["price"];
        $product->inStock = $data["in_stock"];
        $product->save();
    }

    return $response->json(["message" => "Seeded " . count($products) . " products"]);
});
```

### Expected Result

Visit `http://localhost:7146/admin` and see:

- A sidebar with navigation (Dashboard highlighted)
- Four stat cards showing product and order counts
- A recent orders table with status badges
- A dark mode toggle that switches the entire UI

Visit `http://localhost:7146/admin/products` and see:

- A table of all products loaded via AJAX
- An "Add Product" button that opens a modal
- Form submission creates the product and refreshes the table

---

## 12. Solution

The solution follows the same patterns shown in sections 7 and 10. Create the layout template extending the base layout from section 7. Create the dashboard page template with stat cards using `{% for stat in stats %}`. Create the products page template using the AJAX pattern from section 10, but for products instead of users.

For the products page, use auto-CRUD on the Product model (`$autoCrud = true`) so the API endpoints are available at `/api/products`. Load the table with `frond.get("/api/products", ...)` and handle form submission with `frond.post("/api/products", ...)`.

For the dark mode toggle, add the JavaScript from section 8 to the base layout template inside the `{% block extra_js %}` block.

The key route handlers are:

```php
<?php
use Tina4\Router;

Router::get("/admin", function ($request, $response) {
    $product = new Product();
    $allProducts = $product->select("*");
    $inStockCount = count(array_filter($allProducts, fn($p) => $p->inStock));
    $totalProducts = count($allProducts);
    $stockHealth = $totalProducts > 0 ? round(($inStockCount / $totalProducts) * 100) : 0;

    $stats = [
        ["label" => "Total Products", "value" => $totalProducts, "change" => 5, "direction" => "up"],
        ["label" => "Total Orders", "value" => 156, "change" => 12, "direction" => "up"],
        ["label" => "Revenue", "value" => "$8,450", "change" => 3, "direction" => "up"],
        ["label" => "Low Stock", "value" => $totalProducts - $inStockCount, "change" => 2, "direction" => "down"]
    ];

    return $response->render("admin/dashboard.html", [
        "active_page" => "dashboard",
        "stats" => $stats,
        "stock_health" => $stockHealth,
        "recent_orders" => [],
        "pending_orders" => 0
    ]);
});

Router::get("/admin/products", function ($request, $response) {
    return $response->render("admin/products.html", [
        "active_page" => "products",
        "pending_orders" => 0
    ]);
});
```

---

## 13. Gotchas

### 1. CSS File Not Loading

**Problem:** The browser shows unstyled HTML. The CSS file returns a 404.

**Cause:** The CSS file must be inside `src/public/css/`. If you put it in `src/css/` or `css/` at the root, Tina4 will not serve it.

**Fix:** Make sure the file is at `src/public/css/tina4.css`. Static files are served from `src/public/`.

### 2. SCSS Changes Not Reflected

**Problem:** You edited `tina4.scss` but the browser still shows the old styles.

**Cause:** SCSS must be compiled to CSS. Editing the `.scss` file does not automatically update the `.css` file unless you are running `tina4 scss --watch`.

**Fix:** Run `tina4 scss` to compile, or use `tina4 scss --watch` during development.

### 3. Modal Does Not Open

**Problem:** Clicking a button with `data-toggle="modal"` does nothing.

**Cause:** frond.js is not loaded, or the `data-target` value does not match the modal's `id`.

**Fix:** Check that `<script src="/js/frond.js"></script>` is included before `</body>`. Verify that `data-target="#myModal"` matches `<div class="modal" id="myModal">` (the `#` prefix is required in `data-target`).

### 4. frond.js AJAX Returns HTML Instead of JSON

**Problem:** `frond.get("/api/products", ...)` receives an HTML page instead of JSON data.

**Cause:** The route handler returns `$response->render(...)` or `$response->html(...)` instead of `$response->json(...)`. Or the URL is wrong and hitting a catch-all route that returns HTML.

**Fix:** Verify the API route returns JSON. Check the URL in the frond.js call matches the route path exactly.

### 5. Dark Mode Flickers on Load

**Problem:** The page loads in light mode for a split second before switching to dark mode.

**Cause:** The theme is set by JavaScript after the page renders. The initial HTML does not include `data-theme="dark"`.

**Fix:** Move the theme detection script to the `<head>` section so it runs before the body renders:

```html
<head>
    <script>
        (function() {
            var t = localStorage.getItem("theme");
            if (t) document.documentElement.setAttribute("data-theme", t);
            else if (window.matchMedia("(prefers-color-scheme: dark)").matches)
                document.documentElement.setAttribute("data-theme", "dark");
        })();
    </script>
</head>
```

### 6. Form Data Not Reaching the Server

**Problem:** `frond.post()` sends the request but `$request->body` is empty on the server.

**Cause:** frond.js sends JSON by default. If you are building the data object incorrectly or passing a FormData object, the server may not parse it correctly.

**Fix:** Pass a plain JavaScript object to `frond.post()`. Do not use `new FormData()` -- frond.js handles serialization internally. Make sure your object keys match what the server expects:

```javascript
frond.post("/api/products", {
    name: document.getElementById("name").value,
    price: parseFloat(document.getElementById("price").value)
}, callback);
```

### 7. Responsive Grid Not Working

**Problem:** Columns do not stack on mobile. They overflow horizontally instead.

**Cause:** Missing the viewport meta tag. Without it, mobile browsers render the page at desktop width.

**Fix:** Add this to your `<head>`:

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0">
```

This tag is included in all the examples above but is easy to forget when creating templates from scratch.

---

## 14. HtmlElement — Programmatic HTML Builder

Build HTML in PHP without string concatenation:

```php
$el = new HtmlElement("div", ["class" => "card"], ["Hello"]);
echo $el; // <div class="card">Hello</div>

// Nesting
$card = new HtmlElement("div", ["class" => "card"], [
    new HtmlElement("h2", [], ["Title"]),
    new HtmlElement("p", [], ["Content"]),
]);

// Helper functions
extract(HtmlElement::helpers());
echo $_div(["class" => "card"], $_p("Hello"), $_a(["href" => "/"], "Home"));
```

Void tags (`<br>`, `<img>`, `<input>`) render without closing tags. Boolean attributes render as bare names.
