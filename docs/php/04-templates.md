# Chapter 4: Templates

## 1. Why Templates

In Chapter 1, `$response->render("products.html", $data)` produced a full HTML page. That rendering was done by **Frond** -- Tina4's built-in template engine. Zero dependencies. Twig-compatible. If you know Twig, Jinja2, or Nunjucks, you already know 90% of Frond.

Templates live in `src/templates/`. Call `$response->render("page.html", $data)`. Frond loads `src/templates/page.html`, processes the tags and expressions, returns the final HTML.

This chapter covers every feature. After reading it, you can build real pages.

---

## 2. Variables and Expressions

Double curly braces output a variable:

```html
<h1>Hello, &#123;&#123; name &#125;&#125;!</h1>
```

Route handler:

```php
<?php
use Tina4\Router;

Router::get("/welcome", function ($request, $response) {
    return $response->render("welcome.html", [
        "name" => "Alice"
    ]);
});
```

Create `src/templates/welcome.html`:

```html
<!DOCTYPE html>
<html>
<head><title>Welcome</title></head>
<body>
    <h1>Hello, &#123;&#123; name &#125;&#125;!</h1>
</body>
</html>
```

**Output:**

```
Hello, Alice!
```

### Accessing Nested Data

Dot notation reaches into nested arrays:

```php
$data = [
    "user" => [
        "name" => "Alice",
        "email" => "alice@example.com",
        "address" => [
            "city" => "Cape Town",
            "country" => "South Africa"
        ]
    ]
];

return $response->render("profile.html", $data);
```

```html
<p>&#123;&#123; user.name &#125;&#125; lives in &#123;&#123; user.address.city &#125;&#125;, &#123;&#123; user.address.country &#125;&#125;.</p>
```

**Output:**

```
Alice lives in Cape Town, South Africa.
```

### Expressions

<div v-pre>

Basic arithmetic and string concatenation work inside `{{ }}`:

</div>

```html
<p>Total: $&#123;&#123; price * quantity &#125;&#125;</p>
<p>Discounted: $&#123;&#123; price * 0.9 &#125;&#125;</p>
<p>Full name: &#123;&#123; first_name ~ " " ~ last_name &#125;&#125;</p>
```

The `~` operator concatenates strings.

---

## 3. Template Inheritance

The most powerful feature. Define a base layout once. Extend it everywhere.

### Base Layout

Create `src/templates/base.twig`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>&#123;% block title %&#125;My App&#123;% endblock %&#125;</title>
    <link rel="stylesheet" href="/css/tina4.css">
    &#123;% block head %&#125;&#123;% endblock %&#125;
</head>
<body>
    <nav>
        <a href="/">Home</a>
        <a href="/about">About</a>
        <a href="/contact">Contact</a>
    </nav>

    <main>
        &#123;% block content %&#125;&#123;% endblock %&#125;
    </main>

    <footer>
        <p>&copy; 2026 My App. All rights reserved.</p>
    </footer>

    <script src="/js/frond.js"></script>
    &#123;% block scripts %&#125;&#123;% endblock %&#125;
</body>
</html>
```

Four blocks: `title`, `head`, `content`, `scripts`. Child templates override only what they need.

### Child Template

Create `src/templates/about.twig`:

```html
&#123;% extends "base.twig" %&#125;

&#123;% block title %&#125;About Us&#123;% endblock %&#125;

&#123;% block content %&#125;
    <h1>About Us</h1>
    <p>We have been building things since &#123;&#123; founded_year &#125;&#125;.</p>
    <p>Our team has &#123;&#123; team_size &#125;&#125; members across &#123;&#123; office_count &#125;&#125; offices.</p>
&#123;% endblock %&#125;
```

Route handler:

```php
<?php
use Tina4\Router;

Router::get("/about", function ($request, $response) {
    return $response->render("about.twig", [
        "founded_year" => 2020,
        "team_size" => 12,
        "office_count" => 3
    ]);
});
```

**Result:** A full HTML page with the nav, the "About Us" content, and the footer. The `<title>` reads "About Us". The `head` and `scripts` blocks stay empty because the child did not override them.

<div v-pre>

### Using `{{ parent() }}`

</div>

Add to a block instead of replacing it:

```html
&#123;% extends "base.twig" %&#125;

&#123;% block head %&#125;
    &#123;&#123; parent() &#125;&#125;
    <link rel="stylesheet" href="/css/contact-form.css">
&#123;% endblock %&#125;

&#123;% block content %&#125;
    <h1>Contact Us</h1>
    <form>...</form>
&#123;% endblock %&#125;
```

The `head` block now contains everything from the base plus the extra stylesheet.

---

## 4. Includes

<div v-pre>

Break templates into reusable pieces with `{% include %}`:

</div>

Create `src/templates/partials/header.twig`:

```html
<header>
    <div class="logo">&#123;&#123; site_name | default("My App") &#125;&#125;</div>
    <nav>
        <a href="/">Home</a>
        <a href="/products">Products</a>
        <a href="/contact">Contact</a>
    </nav>
</header>
```

Create `src/templates/partials/product-card.twig`:

```html
<div class="product-card&#123;&#123; product.featured ? ' featured' : '' &#125;&#125;">
    <h3>&#123;&#123; product.name &#125;&#125;</h3>
    <p class="price">$&#123;&#123; product.price | number_format(2) &#125;&#125;</p>
    &#123;% if product.in_stock %&#125;
        <span class="badge-success">In Stock</span>
    &#123;% else %&#125;
        <span class="badge-danger">Out of Stock</span>
    &#123;% endif %&#125;
</div>
```

Use them in a page:

```html
&#123;% extends "base.twig" %&#125;

&#123;% block content %&#125;
    &#123;% include "partials/header.twig" %&#125;

    <h1>Products</h1>
    &#123;% for product in products %&#125;
        &#123;% include "partials/product-card.twig" %&#125;
    &#123;% endfor %&#125;
&#123;% endblock %&#125;
```

The `product` variable is available inside the included template because it exists in the current scope -- the for loop.

### Passing Variables to Includes

Explicit variable passing with `with`:

```html
&#123;% include "partials/header.twig" with {"site_name": "Cool Store"} %&#125;
```

Isolate the included template from the parent scope with `only`:

```html
&#123;% include "partials/header.twig" with {"site_name": "Cool Store"} only %&#125;
```

With `only`, the included template sees `site_name` and nothing else.

---

## 5. For Loops

<div v-pre>

Loop through arrays with `{% for %}`:

</div>

```html
<ul>
&#123;% for item in items %&#125;
    <li>&#123;&#123; item &#125;&#125;</li>
&#123;% endfor %&#125;
</ul>
```

### The `loop` Variable

Inside every for loop, Frond provides a `loop` variable:

| Property | Type | Description |
|----------|------|-------------|
| `loop.index` | int | Current iteration (1-based) |
| `loop.index0` | int | Current iteration (0-based) |
| `loop.first` | bool | True on the first iteration |
| `loop.last` | bool | True on the last iteration |
| `loop.length` | int | Total number of items |
| `loop.revindex` | int | Iterations remaining (1-based) |

```html
<table>
    <thead>
        <tr><th>#</th><th>Name</th><th>Price</th></tr>
    </thead>
    <tbody>
    &#123;% for product in products %&#125;
        <tr class="&#123;&#123; loop.index is odd ? 'row-light' : 'row-dark' &#125;&#125;">
            <td>&#123;&#123; loop.index &#125;&#125;</td>
            <td>&#123;&#123; product.name &#125;&#125;</td>
            <td>$&#123;&#123; product.price | number_format(2) &#125;&#125;</td>
        </tr>
    &#123;% endfor %&#125;
    </tbody>
</table>
```

### Empty Lists

<div v-pre>

Handle empty lists with `{% else %}`:

</div>

```html
&#123;% for product in products %&#125;
    <div class="product-card">
        <h3>&#123;&#123; product.name &#125;&#125;</h3>
    </div>
&#123;% else %&#125;
    <p>No products found.</p>
&#123;% endfor %&#125;
```

If `products` is empty or undefined, the `else` block renders instead.

### Looping Over Key-Value Pairs

```html
&#123;% for key, value in metadata %&#125;
    <dt>&#123;&#123; key &#125;&#125;</dt>
    <dd>&#123;&#123; value &#125;&#125;</dd>
&#123;% endfor %&#125;
```

---

## 6. Conditionals

### if / elseif / else

```html
&#123;% if user.role == "admin" %&#125;
    <a href="/admin">Admin Panel</a>
&#123;% elseif user.role == "editor" %&#125;
    <a href="/editor">Editor Dashboard</a>
&#123;% else %&#125;
    <a href="/profile">My Profile</a>
&#123;% endif %&#125;
```

### Ternary Operator

Inline conditionals:

```html
<span class="&#123;&#123; is_active ? 'text-green' : 'text-gray' &#125;&#125;">
    &#123;&#123; is_active ? 'Active' : 'Inactive' &#125;&#125;
</span>
```

### Testing for Existence

```html
&#123;% if error_message is defined %&#125;
    <div class="alert alert-danger">&#123;&#123; error_message &#125;&#125;</div>
&#123;% endif %&#125;
```

### Truthiness

False values: `false`, `null`, `0`, `""` (empty string), `[]` (empty array). Everything else is true.

```html
&#123;% if items %&#125;
    <p>&#123;&#123; items | length &#125;&#125; items found.</p>
&#123;% else %&#125;
    <p>No items.</p>
&#123;% endif %&#125;
```

---

## 7. Filters

Filters transform values. Apply them with `|`:

```html
&#123;&#123; name | upper &#125;&#125;
```

### Text Filters

| Filter | Input | Output | Description |
|--------|-------|--------|-------------|
| `upper` | `"hello"` | `"HELLO"` | Uppercase |
| `lower` | `"HELLO"` | `"hello"` | Lowercase |
| `capitalize` | `"hello world"` | `"Hello world"` | Capitalize first letter |
| `title` | `"hello world"` | `"Hello World"` | Capitalize each word |
| `trim` | `"  hello  "` | `"hello"` | Remove whitespace |
| `striptags` | `"<b>bold</b>"` | `"bold"` | Remove HTML tags |

### Number Filters

| Filter | Input | Output | Description |
|--------|-------|--------|-------------|
| `number_format(2)` | `1234.5` | `"1,234.50"` | Format number |
| `round` | `3.7` | `4` | Round to nearest integer |
| `round(2)` | `3.14159` | `3.14` | Round to N decimal places |
| `abs` | `-5` | `5` | Absolute value |

### Array Filters

| Filter | Input | Output | Description |
|--------|-------|--------|-------------|
| `length` | `[1,2,3]` | `3` | Count items |
| `join(", ")` | `["a","b","c"]` | `"a, b, c"` | Join with separator |
| `first` | `[1,2,3]` | `1` | First item |
| `last` | `[1,2,3]` | `3` | Last item |
| `reverse` | `[1,2,3]` | `[3,2,1]` | Reverse order |
| `sort` | `[3,1,2]` | `[1,2,3]` | Sort ascending |
| `slice(1, 2)` | `[1,2,3,4]` | `[2,3]` | Slice from offset, length |

### Date Filter

```html
<p>Published: &#123;&#123; created_at | date("F j, Y") &#125;&#125;</p>
<p>Time: &#123;&#123; created_at | date("H:i") &#125;&#125;</p>
```

With a PHP timestamp or date string:

- `date("F j, Y")` outputs `"March 22, 2026"`
- `date("H:i")` outputs `"14:30"`
- `date("Y-m-d")` outputs `"2026-03-22"`

### The `default` Filter

Fallback value when a variable is null or undefined:

```html
<p>&#123;&#123; subtitle | default("No subtitle") &#125;&#125;</p>
<p>&#123;&#123; user.nickname | default(user.name) | default("Anonymous") &#125;&#125;</p>
```

### The `escape` and `raw` Filters

<div v-pre>

All `{{ }}` output is auto-escaped for HTML safety. XSS attacks are blocked by default:

</div>

```html
&#123;&#123; user_input &#125;&#125;
&#123;# If user_input is "<script>alert('xss')</script>", outputs:
   &lt;script&gt;alert('xss')&lt;/script&gt; #}
```

For trusted content that needs raw HTML:

```html
&#123;&#123; trusted_html | raw &#125;&#125;
```

Use `raw` sparingly. Only on content you fully control. Never on user input.

### Chaining Filters

Left to right:

```html
&#123;&#123; name | trim | lower | capitalize &#125;&#125;
&#123;# "  ALICE SMITH  " -> "Alice smith" #&#125;
```

---

## 8. Macros

Macros are reusable template functions. Define once, call many times.

### Defining a Macro

Create `src/templates/macros.twig`:

```html
&#123;% macro button(text, url, style) %&#125;
    <a href="&#123;&#123; url | default('#') &#125;&#125;" class="btn btn-&#123;&#123; style | default('primary') &#125;&#125;">
        &#123;&#123; text &#125;&#125;
    </a>
&#123;% endmacro %&#125;

&#123;% macro alert(message, type) %&#125;
    <div class="alert alert-&#123;&#123; type | default('info') &#125;&#125;">
        &#123;&#123; message &#125;&#125;
    </div>
&#123;% endmacro %&#125;

&#123;% macro input(name, label, type, value) %&#125;
    <div class="form-group">
        <label for="&#123;&#123; name &#125;&#125;">&#123;&#123; label | default(name | capitalize) &#125;&#125;</label>
        <input type="&#123;&#123; type | default('text') &#125;&#125;" id="&#123;&#123; name &#125;&#125;" name="&#123;&#123; name &#125;&#125;" value="&#123;&#123; value | default('') &#125;&#125;">
    </div>
&#123;% endmacro %&#125;
```

### Using Macros

Import and use:

```html
&#123;% from "macros.twig" import button, alert, input %&#125;

&#123;% extends "base.twig" %&#125;

&#123;% block content %&#125;
    &#123;&#123; alert("Your profile has been updated.", "success") &#125;&#125;

    <form method="POST" action="/profile">
        &#123;&#123; input("name", "Full Name", "text", user.name) &#125;&#125;
        &#123;&#123; input("email", "Email Address", "email", user.email) &#125;&#125;
        &#123;&#123; input("phone", "Phone Number", "tel", user.phone) &#125;&#125;

        &#123;&#123; button("Save Changes", "", "primary") &#125;&#125;
        &#123;&#123; button("Cancel", "/dashboard", "secondary") &#125;&#125;
    </form>
&#123;% endblock %&#125;
```

**Output** (simplified):

```html
<div class="alert alert-success">
    Your profile has been updated.
</div>

<form method="POST" action="/profile">
    <div class="form-group">
        <label for="name">Full Name</label>
        <input type="text" id="name" name="name" value="Alice">
    </div>
    <div class="form-group">
        <label for="email">Email Address</label>
        <input type="email" id="email" name="email" value="alice@example.com">
    </div>
    <div class="form-group">
        <label for="phone">Phone Number</label>
        <input type="tel" id="phone" name="phone" value="">
    </div>

    <a href="#" class="btn btn-primary">Save Changes</a>
    <a href="/dashboard" class="btn btn-secondary">Cancel</a>
</form>
```

---

## 9. Special Tags

<div v-pre>

### {% raw %} -- Literal Output

</div>

<div v-pre>

Output literal `{{ }}` or `{% %}` without processing. Essential for Vue.js or Angular templates:

</div>

```html
&#123;% raw %&#125;
    <div id="app">
        &#123;&#123; message &#125;&#125;
    </div>
&#123;% endraw %&#125;
```

<div v-pre>

Outputs the literal text `{{ message }}`.

</div>

<div v-pre>

### {% spaceless %} -- Remove Whitespace

</div>

Strip whitespace between HTML tags:

```html
&#123;% spaceless %&#125;
    <div>
        <span>Hello</span>
    </div>
&#123;% endspaceless %&#125;
```

**Output:**

```html
<div><span>Hello</span></div>
```

Useful for inline elements where whitespace creates unwanted gaps.

<div v-pre>

### {% autoescape %} -- Control Escaping

</div>

Override auto-escaping for a block:

```html
&#123;% autoescape false %&#125;
    &#123;&#123; trusted_html &#125;&#125;
&#123;% endautoescape %&#125;
```

Everything inside outputs without HTML escaping. Equivalent to `| raw` on every variable, but more convenient for large blocks of trusted content.

### Comments

Template comments are invisible in the output:

```html
&#123;# This comment will not appear in the HTML output #&#125;

&#123;#
    Multi-line comments work too.
    Use them to document template logic.
#}
```

---

## 10. tina4css Integration

Every Tina4 project includes `tina4.css` -- a built-in CSS utility framework. Available at `/css/tina4.css`. Layout, typography, common UI patterns. No external dependencies.

Include it in your base template:

```html
<link rel="stylesheet" href="/css/tina4.css">
```

### Layout Classes

```html
<div class="container">
    <div class="row">
        <div class="col-6">Left half</div>
        <div class="col-6">Right half</div>
    </div>
</div>
```

### Common Components

```html
<!-- Buttons -->
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-danger">Danger</button>

<!-- Cards -->
<div class="card">
    <div class="card-header">Title</div>
    <div class="card-body">Content here</div>
    <div class="card-footer">Footer</div>
</div>

<!-- Alerts -->
<div class="alert alert-success">Operation completed.</div>
<div class="alert alert-danger">Something went wrong.</div>
<div class="alert alert-warning">Please review your input.</div>

<!-- Forms -->
<div class="form-group">
    <label for="name">Name</label>
    <input type="text" id="name" class="form-control">
</div>
```

### Utility Classes

```html
<p class="text-center">Centered text</p>
<p class="text-right">Right-aligned text</p>
<div class="mt-4">Margin top</div>
<div class="p-3">Padding all around</div>
<span class="text-muted">Gray text</span>
<span class="text-primary">Primary color text</span>
```

No Bootstrap. No Tailwind. If you prefer those, swap the `<link>` tag. Tina4 does not care.

---

## 11. Exercise: Build a Product Catalog Page

Build a catalog page with a base layout, product cards, category filters, and a reusable card macro.

### Requirements

1. Create a base layout at `src/templates/catalog-base.twig` with blocks for `title`, `content`, and `scripts`
2. Create a macro file at `src/templates/catalog-macros.twig` with:
   - A `productCard(product)` macro that renders a styled card with name, category, price, stock status, and optional featured badge
   - A `categoryFilter(categories, active)` macro that renders filter buttons
3. Create a page template at `src/templates/catalog.twig` that:
   - Extends the base layout
   - Uses the macros
   - Shows a heading with total product count
   - Shows category filter buttons (All, plus one per unique category)
   - Shows product cards in a grid
   - Highlights featured products
   - Handles empty filter results
4. Create a route at `GET /catalog` that accepts an optional `?category=` filter

### Data

Use this product list in your route handler:

```php
$products = [
    ["name" => "Espresso Machine", "category" => "Kitchen", "price" => 299.99, "in_stock" => true, "featured" => true],
    ["name" => "Yoga Mat", "category" => "Fitness", "price" => 29.99, "in_stock" => true, "featured" => false],
    ["name" => "Standing Desk", "category" => "Office", "price" => 549.99, "in_stock" => true, "featured" => true],
    ["name" => "Blender", "category" => "Kitchen", "price" => 89.99, "in_stock" => false, "featured" => false],
    ["name" => "Running Shoes", "category" => "Fitness", "price" => 119.99, "in_stock" => true, "featured" => false],
    ["name" => "Desk Lamp", "category" => "Office", "price" => 39.99, "in_stock" => true, "featured" => true],
    ["name" => "Cast Iron Skillet", "category" => "Kitchen", "price" => 44.99, "in_stock" => true, "featured" => false]
];
```

### Test with:

```
http://localhost:7146/catalog
http://localhost:7146/catalog?category=Kitchen
http://localhost:7146/catalog?category=Fitness
```

---

## 12. Solution

Create `src/templates/catalog-base.twig`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>&#123;% block title %&#125;Product Catalog&#123;% endblock %&#125;</title>
    <link rel="stylesheet" href="/css/tina4.css">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 0; background: #f8f9fa; }
        .container { max-width: 1000px; margin: 0 auto; padding: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; margin-bottom: 24px; }
        .header h1 { margin: 0; }
        .header p { margin: 4px 0 0; opacity: 0.8; }
        .filters { margin-bottom: 20px; }
        .filter-btn { display: inline-block; padding: 6px 14px; margin: 0 6px 6px 0; border-radius: 20px; text-decoration: none; font-size: 0.9em; border: 1px solid #dee2e6; color: #495057; background: white; }
        .filter-btn.active { background: #2c3e50; color: white; border-color: #2c3e50; }
        .product-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }
        .product-card { background: white; border: 2px solid #e9ecef; border-radius: 8px; padding: 16px; transition: border-color 0.2s; }
        .product-card:hover { border-color: #adb5bd; }
        .product-card.featured { border-color: #f39c12; background: #fef9e7; }
        .product-name { font-size: 1.1em; font-weight: 600; margin: 0 0 4px; }
        .product-category { font-size: 0.85em; color: #6c757d; margin: 0 0 8px; }
        .product-price { font-size: 1.2em; font-weight: bold; color: #27ae60; }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.75em; font-weight: 600; margin-left: 8px; }
        .badge-featured { background: #f39c12; color: white; }
        .badge-stock { background: #d4edda; color: #155724; }
        .badge-nostock { background: #f8d7da; color: #721c24; }
        .empty-state { text-align: center; padding: 40px; color: #6c757d; }
    </style>
</head>
<body>
    &#123;% block content %&#125;&#123;% endblock %&#125;

    <script src="/js/frond.js"></script>
    &#123;% block scripts %&#125;&#123;% endblock %&#125;
</body>
</html>
```

Create `src/templates/catalog-macros.twig`:

```html
&#123;% macro productCard(product) %&#125;
    <div class="product-card&#123;&#123; product.featured ? ' featured' : '' &#125;&#125;">
        <p class="product-name">
            &#123;&#123; product.name &#125;&#125;
            &#123;% if product.featured %&#125;
                <span class="badge badge-featured">Featured</span>
            &#123;% endif %&#125;
        </p>
        <p class="product-category">&#123;&#123; product.category &#125;&#125;</p>
        <p class="product-price">
            $&#123;&#123; product.price | number_format(2) &#125;&#125;
            &#123;% if product.in_stock %&#125;
                <span class="badge badge-stock">In Stock</span>
            &#123;% else %&#125;
                <span class="badge badge-nostock">Out of Stock</span>
            &#123;% endif %&#125;
        </p>
    </div>
&#123;% endmacro %&#125;

&#123;% macro categoryFilter(categories, active) %&#125;
    <div class="filters">
        <a href="/catalog" class="filter-btn&#123;&#123; active is not defined or active == '' ? ' active' : '' &#125;&#125;">All</a>
        &#123;% for cat in categories %&#125;
            <a href="/catalog?category=&#123;&#123; cat &#125;&#125;" class="filter-btn&#123;&#123; active == cat ? ' active' : '' &#125;&#125;">&#123;&#123; cat &#125;&#125;</a>
        &#123;% endfor %&#125;
    </div>
&#123;% endmacro %&#125;
```

Create `src/templates/catalog.twig`:

```html
&#123;% extends "catalog-base.twig" %&#125;

&#123;% from "catalog-macros.twig" import productCard, categoryFilter %&#125;

&#123;% block title %&#125;&#123;&#123; active_category | default("All") &#125;&#125; Products - Catalog&#123;% endblock %&#125;

&#123;% block content %&#125;
    <div class="header">
        <h1>Product Catalog</h1>
        <p>&#123;&#123; products | length &#125;&#125; product&#123;&#123; products | length != 1 ? 's' : '' &#125;&#125;&#123;% if active_category %&#125; in &#123;&#123; active_category &#125;&#125;&#123;% endif %&#125;</p>
    </div>

    <div class="container">
        &#123;&#123; categoryFilter(categories, active_category) &#125;&#125;

        &#123;% if products | length > 0 %&#125;
            <div class="product-grid">
                &#123;% for product in products %&#125;
                    &#123;&#123; productCard(product) &#125;&#125;
                &#123;% endfor %&#125;
            </div>
        &#123;% else %&#125;
            <div class="empty-state">
                <h2>No products found</h2>
                <p>Try a different category or <a href="/catalog">view all products</a>.</p>
            </div>
        &#123;% endif %&#125;
    </div>
&#123;% endblock %&#125;
```

Create `src/routes/catalog.php`:

```php
<?php
use Tina4\Router;

Router::get("/catalog", function ($request, $response) {
    $allProducts = [
        ["name" => "Espresso Machine", "category" => "Kitchen", "price" => 299.99, "in_stock" => true, "featured" => true],
        ["name" => "Yoga Mat", "category" => "Fitness", "price" => 29.99, "in_stock" => true, "featured" => false],
        ["name" => "Standing Desk", "category" => "Office", "price" => 549.99, "in_stock" => true, "featured" => true],
        ["name" => "Blender", "category" => "Kitchen", "price" => 89.99, "in_stock" => false, "featured" => false],
        ["name" => "Running Shoes", "category" => "Fitness", "price" => 119.99, "in_stock" => true, "featured" => false],
        ["name" => "Desk Lamp", "category" => "Office", "price" => 39.99, "in_stock" => true, "featured" => true],
        ["name" => "Cast Iron Skillet", "category" => "Kitchen", "price" => 44.99, "in_stock" => true, "featured" => false]
    ];

    // Get unique categories
    $categories = array_unique(array_column($allProducts, "category"));
    sort($categories);

    // Filter by category if specified
    $activeCategory = $request->query["category"] ?? "";
    if (!empty($activeCategory)) {
        $products = array_values(array_filter(
            $allProducts,
            fn($p) => strtolower($p["category"]) === strtolower($activeCategory)
        ));
    } else {
        $products = $allProducts;
    }

    return $response->render("catalog.twig", [
        "products" => $products,
        "categories" => $categories,
        "active_category" => $activeCategory
    ]);
});
```

**Expected browser output for `/catalog`:**

- A dark header with "Product Catalog" and "7 products"
- Filter buttons: All (active), Fitness, Kitchen, Office
- A grid of 7 product cards
- Three cards (Espresso Machine, Standing Desk, Desk Lamp) have a gold border and "Featured" badge
- The Blender card shows an "Out of Stock" badge in red

**Expected browser output for `/catalog?category=Kitchen`:**

- Header shows "3 products in Kitchen"
- The Kitchen filter button is active
- Three cards: Espresso Machine, Blender, Cast Iron Skillet

---

## 13. Gotchas

<div v-pre>

### 1. `{% extends %}` Must Be the First Tag

</div>

**Problem:** Template inheritance does not work. The page renders without the base layout.

<div v-pre>

**Cause:** `{% extends "base.twig" %}` must be the very first tag. Any text, whitespace, or comment before it breaks inheritance.

</div>

<div v-pre>

**Fix:** Put `{% extends %}` on the absolute first line. Move `{% from %}` imports after it.

</div>

### 2. Undefined Variables Show Nothing

<div v-pre>

**Problem:** `{{ username }}` renders as blank instead of an error.

</div>

**Cause:** Frond silently outputs nothing for undefined variables. By design, like Twig. But it hides bugs.

<div v-pre>

**Fix:** Use the `default` filter: `{{ username | default("Guest") }}`. Or check with `{% if username is defined %}`.

</div>

### 3. Auto-Escaping Prevents HTML Output

**Problem:** HTML content like `"<strong>bold</strong>"` appears as literal text.

**Cause:** Auto-escaping converts `<` to `&lt;` and `>` to `&gt;` for security.

<div v-pre>

**Fix:** Trusted content: `{{ content | raw }}`. Never use `raw` on user-supplied input.

</div>

### 4. Variable Scope in Includes

<div v-pre>

**Problem:** A variable defined inside a `{% for %}` loop is not accessible after the loop ends.

</div>

**Cause:** Loop variables are scoped to the loop. They do not leak.

<div v-pre>

**Fix:** Use `{% set %}` before the loop and update inside it. Or restructure to keep all logic within the loop.

</div>

### 5. Macro Arguments Are Positional

<div v-pre>

**Problem:** `{{ button("Click", style="danger") }}` does not work.

</div>

**Cause:** Frond macros use positional arguments. Order matters. Keyword arguments are not supported.

<div v-pre>

**Fix:** Pass arguments in definition order: `{{ button("Click", "/url", "danger") }}`. For many optional arguments, pass a single object.

</div>

### 6. Template File Extension Does Not Matter

**Problem:** Unsure whether to use `.html`, `.twig`, or `.tpl`.

**Cause:** Frond processes any file in `src/templates/` regardless of extension.

**Fix:** Pick one extension. Be consistent. This book uses `.twig` for templates with Twig syntax and `.html` for simple files. Both work identically.

### 7. Filters Are Not PHP Functions

<div v-pre>

**Problem:** `{{ items | count }}` or `{{ name | strtoupper }}` causes an error.

</div>

**Cause:** Frond filters follow Twig conventions, not PHP function names.

<div v-pre>

**Fix:** `{{ items | length }}` not `count`. `{{ name | upper }}` not `strtoupper`. `{{ text | lower }}` not `strtolower`. See the filter table in section 7.

</div>
