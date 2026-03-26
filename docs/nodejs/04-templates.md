# Chapter 4: Templates

## 1. Why Templates

In Chapter 1, you saw `res.html("products.html", data)` produce a full HTML page. That rendering was done by **Frond**, Tina4's built-in template engine. Zero dependencies. Twig-compatible. Built from scratch. If you know Twig, Jinja2, or Nunjucks, you know 90% of Frond.

Templates live in `src/templates/`. Call `res.html("page.html", data)` and Frond loads `src/templates/page.html`, processes the tags and expressions, and returns the final HTML.

This chapter covers every feature of the template engine. After this, you build real pages.

---

## 2. Variables and Expressions

Output a variable with double curly braces:

```html
<h1>Hello, &#123;&#123; name &#125;&#125;!</h1>
```

Route handler:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/welcome", async (req, res) => {
    return res.html("welcome.html", {
        name: "Alice"
    });
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

**Expected browser output:**

```
Hello, Alice!
```

### Accessing Nested Data

Dot notation reaches into nested objects:

```typescript
const data = {
    user: {
        name: "Alice",
        email: "alice@example.com",
        address: {
            city: "Cape Town",
            country: "South Africa"
        }
    }
};

return res.html("profile.html", data);
```

```html
<p>&#123;&#123; user.name &#125;&#125; lives in &#123;&#123; user.address.city &#125;&#125;, &#123;&#123; user.address.country &#125;&#125;.</p>
```

**Output:**

```
Alice lives in Cape Town, South Africa.
```

### Expressions

Basic expressions work inside `&#123;&#123; &#125;&#125;`:

```html
<p>Total: $&#123;&#123; price * quantity &#125;&#125;</p>
<p>Discounted: $&#123;&#123; price * 0.9 &#125;&#125;</p>
<p>Full name: &#123;&#123; first_name ~ " " ~ last_name &#125;&#125;</p>
```

The `~` operator concatenates strings.

---

## 3. Template Inheritance

Template inheritance is the engine's most powerful feature. Define a base layout once. Extend it in every page.

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

```typescript
import { Router } from "tina4-nodejs";

Router.get("/about", async (req, res) => {
    return res.html("about.twig", {
        founded_year: 2020,
        team_size: 12,
        office_count: 3
    });
});
```

### Using `&#123;&#123; parent() &#125;&#125;`

Add to a block rather than replace it:

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

---

## 4. Includes

Break templates into reusable pieces with `&#123;% include %&#125;`:

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
    &#123;% if product.inStock %&#125;
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

### Passing Variables to Includes

```html
&#123;% include "partials/header.twig" with {"site_name": "Cool Store"} %&#125;
```

Use `only` to isolate the included template from the parent scope:

```html
&#123;% include "partials/header.twig" with {"site_name": "Cool Store"} only %&#125;
```

---

## 5. For Loops

Loop through arrays with `&#123;% for %&#125;`:

```html
<ul>
&#123;% for item in items %&#125;
    <li>&#123;&#123; item &#125;&#125;</li>
&#123;% endfor %&#125;
</ul>
```

### The `loop` Variable

Inside a for loop, Frond provides a special `loop` variable:

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

Handle empty lists with `&#123;% else %&#125;`:

```html
&#123;% for product in products %&#125;
    <div class="product-card">
        <h3>&#123;&#123; product.name &#125;&#125;</h3>
    </div>
&#123;% else %&#125;
    <p>No products found.</p>
&#123;% endfor %&#125;
```

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

---

## 7. Filters

Filters transform values. Apply them with the `|` (pipe) character.

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

### The `default` Filter

```html
<p>&#123;&#123; subtitle | default("No subtitle") &#125;&#125;</p>
<p>&#123;&#123; user.nickname | default(user.name) | default("Anonymous") &#125;&#125;</p>
```

### The `escape` and `raw` Filters

All `&#123;&#123; &#125;&#125;` output is auto-escaped for HTML safety. If you trust the content and need raw HTML:

```html
&#123;&#123; trusted_html | raw &#125;&#125;
```

Use `raw` with caution. Apply it only to content you control. Never to user input.

### Chaining Filters

```html
&#123;&#123; name | trim | lower | capitalize &#125;&#125;
&#123;# "  ALICE SMITH  " -> "Alice smith" #&#125;
```

---

## 8. Macros

Macros are reusable template functions. Define once. Call many times.

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

```html
&#123;% from "macros.twig" import button, alert, input %&#125;

&#123;% extends "base.twig" %&#125;

&#123;% block content %&#125;
    &#123;&#123; alert("Your profile has been updated.", "success") &#125;&#125;

    <form method="POST" action="/profile">
        &#123;&#123; input("name", "Full Name", "text", user.name) &#125;&#125;
        &#123;&#123; input("email", "Email Address", "email", user.email) &#125;&#125;

        &#123;&#123; button("Save Changes", "", "primary") &#125;&#125;
        &#123;&#123; button("Cancel", "/dashboard", "secondary") &#125;&#125;
    </form>
&#123;% endblock %&#125;
```

---

## 9. Special Tags

### &#123;% raw %&#125; -- Literal Output

When you need to output literal `&#123;&#123; &#125;&#125;` (for a Vue.js template, for example):

```html
&#123;% raw %&#125;
    <div id="app">
        &#123;&#123; message &#125;&#125;
    </div>
&#123;% endraw %&#125;
```

### Comments

```html
&#123;# This comment will not appear in the HTML output #&#125;
```

---

## 10. Template Route Export Pattern

Tina4 Node.js has a special pattern for file-based routes with templates. Export a `template` constant and return data from the handler:

Create `src/routes/catalog/get.ts`:

```typescript
export const template = "catalog.twig";

export default async (req, res) => {
    const category = req.query.category ?? "";

    const products = [
        { name: "Espresso Machine", category: "Kitchen", price: 299.99, featured: true },
        { name: "Yoga Mat", category: "Fitness", price: 29.99, featured: false },
        { name: "Standing Desk", category: "Office", price: 549.99, featured: true }
    ];

    const filtered = category
        ? products.filter(p => p.category.toLowerCase() === category.toLowerCase())
        : products;

    return {
        products: filtered,
        active_category: category,
        categories: [...new Set(products.map(p => p.category))]
    };
};
```

Tina4 renders `src/templates/catalog.twig` with the returned data. The route handler stays clean -- it returns data, the framework handles rendering.

---

## 11. Exercise: Build a Product Catalog Page

Build a product catalog page with a base layout, product cards, category filters, and a reusable card macro.

### Requirements

1. Create a base layout at `src/templates/catalog-base.twig` with blocks for `title`, `content`, and `scripts`
2. Create a macro file at `src/templates/catalog-macros.twig` with a `productCard(product)` macro and a `categoryFilter(categories, active)` macro
3. Create a page template at `src/templates/catalog.twig` that extends the base, uses the macros, shows category filter buttons, and shows product cards in a grid
4. Create a route at `GET /catalog` that accepts an optional `?category=` filter

### Data

```typescript
const products = [
    { name: "Espresso Machine", category: "Kitchen", price: 299.99, inStock: true, featured: true },
    { name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true, featured: false },
    { name: "Standing Desk", category: "Office", price: 549.99, inStock: true, featured: true },
    { name: "Blender", category: "Kitchen", price: 89.99, inStock: false, featured: false },
    { name: "Running Shoes", category: "Fitness", price: 119.99, inStock: true, featured: false },
    { name: "Desk Lamp", category: "Office", price: 39.99, inStock: true, featured: true },
    { name: "Cast Iron Skillet", category: "Kitchen", price: 44.99, inStock: true, featured: false }
];
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
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; background: #f8f9fa; }
        .container { max-width: 1000px; margin: 0 auto; padding: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; margin-bottom: 24px; }
        .header h1 { margin: 0; }
        .filters { margin-bottom: 20px; }
        .filter-btn { display: inline-block; padding: 6px 14px; margin: 0 6px 6px 0; border-radius: 20px; text-decoration: none; font-size: 0.9em; border: 1px solid #dee2e6; color: #495057; background: white; }
        .filter-btn.active { background: #2c3e50; color: white; border-color: #2c3e50; }
        .product-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }
        .product-card { background: white; border: 2px solid #e9ecef; border-radius: 8px; padding: 16px; }
        .product-card.featured { border-color: #f39c12; background: #fef9e7; }
        .product-name { font-size: 1.1em; font-weight: 600; margin: 0 0 4px; }
        .product-category { font-size: 0.85em; color: #6c757d; }
        .product-price { font-size: 1.2em; font-weight: bold; color: #27ae60; }
        .badge-featured { background: #f39c12; color: white; display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.75em; margin-left: 8px; }
        .badge-stock { background: #d4edda; color: #155724; display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.75em; margin-left: 8px; }
        .badge-nostock { background: #f8d7da; color: #721c24; display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.75em; margin-left: 8px; }
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
                <span class="badge-featured">Featured</span>
            &#123;% endif %&#125;
        </p>
        <p class="product-category">&#123;&#123; product.category &#125;&#125;</p>
        <p class="product-price">
            $&#123;&#123; product.price | number_format(2) &#125;&#125;
            &#123;% if product.inStock %&#125;
                <span class="badge-stock">In Stock</span>
            &#123;% else %&#125;
                <span class="badge-nostock">Out of Stock</span>
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

Create `src/routes/catalog.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/catalog", async (req, res) => {
    const allProducts = [
        { name: "Espresso Machine", category: "Kitchen", price: 299.99, inStock: true, featured: true },
        { name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true, featured: false },
        { name: "Standing Desk", category: "Office", price: 549.99, inStock: true, featured: true },
        { name: "Blender", category: "Kitchen", price: 89.99, inStock: false, featured: false },
        { name: "Running Shoes", category: "Fitness", price: 119.99, inStock: true, featured: false },
        { name: "Desk Lamp", category: "Office", price: 39.99, inStock: true, featured: true },
        { name: "Cast Iron Skillet", category: "Kitchen", price: 44.99, inStock: true, featured: false }
    ];

    const categories = [...new Set(allProducts.map(p => p.category))].sort();
    const activeCategory = req.query.category ?? "";

    const products = activeCategory
        ? allProducts.filter(p => p.category.toLowerCase() === String(activeCategory).toLowerCase())
        : allProducts;

    return res.html("catalog.twig", {
        products,
        categories,
        active_category: activeCategory
    });
});
```

**Expected browser output for `/catalog`:**

- A dark header with "Product Catalog" and "7 products"
- Filter buttons: All (active), Fitness, Kitchen, Office
- A grid of 7 product cards
- Three cards (Espresso Machine, Standing Desk, Desk Lamp) have a gold border and "Featured" badge

**Expected browser output for `/catalog?category=Kitchen`:**

- Header shows "3 products in Kitchen"
- The Kitchen filter button is active
- Three cards: Espresso Machine, Blender, Cast Iron Skillet

---

## 13. Gotchas

### 1. `&#123;% extends %&#125;` Must Be the First Tag

**Problem:** Template inheritance does not work. The page renders without the base layout.

**Cause:** `&#123;% extends "base.twig" %&#125;` must be the first tag in the template. No exceptions.

**Fix:** Make `&#123;% extends %&#125;` the absolute first thing in the file.

### 2. Undefined Variables Show Nothing

**Problem:** `&#123;&#123; username &#125;&#125;` renders as empty instead of showing an error.

**Cause:** Frond outputs nothing for undefined variables. By design.

**Fix:** Use the `default` filter: `&#123;&#123; username | default("Guest") &#125;&#125;`.

### 3. Auto-Escaping Prevents HTML Output

**Problem:** You pass HTML content but it appears as literal text.

**Cause:** Auto-escaping converts `<` to `&lt;` for security.

**Fix:** For trusted content, use `&#123;&#123; content | raw &#125;&#125;`. Never use `raw` on user-supplied input.

### 4. Variable Scope in Includes

**Problem:** A variable defined inside a `&#123;% for %&#125;` loop is not accessible after the loop ends.

**Cause:** Loop variables are scoped to the loop.

**Fix:** Use `&#123;% set %&#125;` before the loop to accumulate values.

### 5. Macro Arguments Are Positional

**Problem:** Calling `&#123;&#123; button("Click", style="danger") &#125;&#125;` does not work.

**Cause:** Frond macros use positional arguments, not keyword arguments.

**Fix:** Pass arguments in the order defined: `&#123;&#123; button("Click", "/url", "danger") &#125;&#125;`.

### 6. Template File Extension Does Not Matter

**Problem:** Not sure whether to use `.html`, `.twig`, or `.tpl`.

**Cause:** Frond does not care about the file extension. It processes any file in `src/templates/`.

**Fix:** Pick one extension. Be consistent. This book uses `.twig` for templates with Twig syntax and `.html` for simple HTML files.

### 7. Filters Are Not JavaScript Functions

**Problem:** You try `&#123;&#123; items | count &#125;&#125;` or `&#123;&#123; name | toUpperCase &#125;&#125;` and get an error.

**Cause:** Frond filters follow Twig conventions, not JavaScript conventions.

**Fix:** Use `&#123;&#123; items | length &#125;&#125;` instead of `count`. Use `&#123;&#123; name | upper &#125;&#125;` instead of `toUpperCase`.
