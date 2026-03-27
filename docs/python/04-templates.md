# Chapter 4: Templates

## 1. Beyond JSON -- Rendering HTML

Every route so far returns JSON. That works for APIs. But web applications need HTML -- product listings, dashboards, login forms, email templates. Tina4 uses the **Frond** template engine for this.

<div v-pre>

Frond is a zero-dependency template engine built from scratch. Its syntax is compatible with Twig, Jinja2, and Nunjucks. If you know any of those, you know Frond. If you do not, the syntax is three things: `{{ }}` for output, `{% %}` for logic, `{# #}` for comments.

</div>

Picture an online store. A product catalog page. Items in a grid. Featured products highlighted. Prices formatted. Layout inherited from a shared template. That is what this chapter builds.

---

## 2. The @template Decorator

The shortest path to a rendered template:

```python
from tina4_python.core.router import template

@template("/about", "about.html")
async def about_page(request, response):
    return {
        "title": "About Us",
        "company": "My Store",
        "founded": 2020
    }
```

Create `src/templates/about.html`:

```html
<!DOCTYPE html>
<html>
<head><title>&#123;&#123; title &#125;&#125;</title></head>
<body>
    <h1>&#123;&#123; title &#125;&#125;</h1>
    <p>&#123;&#123; company &#125;&#125; was founded in &#123;&#123; founded &#125;&#125;.</p>
</body>
</html>
```

Visit `http://localhost:7145/about` and the rendered page appears.

The `@template` decorator maps a URL to a template file. The function returns a dictionary. Those values become template variables. You can also use `response.render()` in any route handler -- `@template` is shorthand.

---

## 3. Variables and Output

### Basic Output

<div v-pre>

Use `{{ }}` to output a variable:

</div>

```html
<h1>Hello, &#123;&#123; name &#125;&#125;!</h1>
<p>Your balance is &#123;&#123; balance &#125;&#125;.</p>
```

With data `{"name": "Alice", "balance": 150.50}`, this renders:

```html
<h1>Hello, Alice!</h1>
<p>Your balance is 150.5.</p>
```

### Accessing Nested Properties

Dot notation for dictionaries and object attributes:

```html
<p>&#123;&#123; user.name &#125;&#125;</p>
<p>&#123;&#123; user.address.city &#125;&#125;</p>
<p>&#123;&#123; order.items.0.name &#125;&#125;</p>
```

With data:

```python
{
    "user": {
        "name": "Alice",
        "address": {"city": "Cape Town"}
    },
    "order": {
        "items": [{"name": "Keyboard"}, {"name": "Mouse"}]
    }
}
```

Renders:

```html
<p>Alice</p>
<p>Cape Town</p>
<p>Keyboard</p>
```

### Auto-Escaping

Frond escapes HTML characters in output by default. XSS attacks die here:

```html
<p>&#123;&#123; user_input &#125;&#125;</p>
```

With `{"user_input": "<script>alert('hacked')</script>"}`, this renders:

```html
<p>&lt;script&gt;alert(&#39;hacked&#39;)&lt;/script&gt;</p>
```

The script tag is escaped. Displayed as text. Never executes. If you need raw HTML (and you trust the source), use the `|safe` filter:

```html
<div>&#123;&#123; trusted_html | safe &#125;&#125;</div>
```

---

## 4. Filters

Filters transform output. The pipe `|` applies them:

```html
&#123;&#123; name | upper &#125;&#125;          &#123;# ALICE #&#125;
&#123;&#123; name | lower &#125;&#125;          &#123;# alice #&#125;
&#123;&#123; name | capitalize &#125;&#125;     &#123;# Alice #&#125;
&#123;&#123; name | title &#125;&#125;          &#123;# Alice Smith #&#125;
&#123;&#123; bio | trim &#125;&#125;            &#123;# Removes leading/trailing whitespace #&#125;
```

### Number Formatting

```html
&#123;&#123; "%.2f"|format(price) &#125;&#125;              &#123;# 79.99 #&#125;
&#123;&#123; "{:,}"|format(large_number) &#125;&#125;       &#123;# 1,234,567 #&#125;
&#123;&#123; percentage | round(1) &#125;&#125;             &#123;# 85.3 #&#125;
```

### String Filters

```html
&#123;&#123; text | replace("old", "new") &#125;&#125;      &#123;# Replace substring #&#125;
&#123;&#123; title | striptags &#125;&#125;                  &#123;# Remove HTML tags #&#125;
&#123;&#123; content | nl2br &#125;&#125;                   &#123;# Convert newlines to <br> #&#125;
&#123;&#123; slug | url_encode &#125;&#125;                 &#123;# URL-encode a string #&#125;
&#123;&#123; items | join(", ") &#125;&#125;                &#123;# Join list with separator #&#125;
```

### Collection Filters

```html
&#123;&#123; items | length &#125;&#125;          &#123;# Number of items #&#125;
&#123;&#123; items | first &#125;&#125;           &#123;# First item #&#125;
&#123;&#123; items | last &#125;&#125;            &#123;# Last item #&#125;
&#123;&#123; items | sort &#125;&#125;            &#123;# Sort ascending #&#125;
&#123;&#123; items | reverse &#125;&#125;         &#123;# Reverse order #&#125;
&#123;&#123; items | unique &#125;&#125;          &#123;# Remove duplicates #&#125;
&#123;&#123; items | slice(0, 3) &#125;&#125;     &#123;# First 3 items #&#125;
&#123;&#123; items | batch(3) &#125;&#125;        &#123;# Group into batches of 3 #&#125;
```

### Date Formatting

```html
&#123;&#123; created_at | date("Y-m-d") &#125;&#125;        &#123;# 2026-03-22 #&#125;
&#123;&#123; created_at | date("d M Y") &#125;&#125;        &#123;# 22 Mar 2026 #&#125;
&#123;&#123; created_at | date("H:i:s") &#125;&#125;        &#123;# 14:30:00 #&#125;
```

### Encoding Filters

```html
&#123;&#123; data | json_encode &#125;&#125;                &#123;# {"key": "value"} #&#125;
&#123;&#123; text | base64encode &#125;&#125;               &#123;# Base64 encoded #&#125;
&#123;&#123; encoded | base64decode &#125;&#125;            &#123;# Base64 decoded #&#125;
```

### Chaining Filters

Filters chain left to right:

```html
&#123;&#123; name | trim | lower | capitalize &#125;&#125;
&#123;# "  alice smith  " → "alice smith" → "Alice smith" #&#125;

&#123;&#123; items | sort | reverse | first &#125;&#125;
&#123;# Sort, reverse, take first = largest item #&#125;
```

### The default Filter

A fallback when a variable is empty or undefined:

```html
&#123;&#123; username | default("Guest") &#125;&#125;
&#123;&#123; bio | default("No bio provided.") &#125;&#125;
&#123;&#123; theme | default("light") &#125;&#125;
```

---

## 5. Control Tags

### if / elif / else

```html
&#123;% if user.role == "admin" %&#125;
    <span class="badge">Admin</span>
&#123;% elif user.role == "moderator" %&#125;
    <span class="badge">Moderator</span>
&#123;% else %&#125;
    <span class="badge">Member</span>
&#123;% endif %&#125;
```

Comparisons and logical operators:

```html
&#123;% if price > 100 and in_stock %&#125;
    <p>Premium item, available now!</p>
&#123;% endif %&#125;

&#123;% if not user.verified %&#125;
    <p>Please verify your email.</p>
&#123;% endif %&#125;

&#123;% if not items %&#125;
    <p>Your cart is empty.</p>
&#123;% endif %&#125;
```

### for Loops

```html
&#123;% for product in products %&#125;
    <div class="product-card">
        <h3>&#123;&#123; product.name &#125;&#125;</h3>
        <p>$&#123;&#123; "%.2f"|format(product.price) &#125;&#125;</p>
    </div>
&#123;% endfor %&#125;
```

Inside a for loop, the `loop` variable gives you context:

| Variable | Description |
|----------|-------------|
| `loop.index` | Current iteration (1-based) |
| `loop.index0` | Current iteration (0-based) |
| `loop.first` | True on the first iteration |
| `loop.last` | True on the last iteration |
| `loop.length` | Total number of items |

```html
<ol>
&#123;% for item in items %&#125;
    <li class="&#123;&#123; 'first' if loop.first else '' &#125;&#125; &#123;&#123; 'last' if loop.last else '' &#125;&#125;">
        &#123;&#123; loop.index &#125;&#125;. &#123;&#123; item.name &#125;&#125;
    </li>
&#123;% endfor %&#125;
</ol>
```

### for / else

<div v-pre>

The `{% else %}` block inside `{% for %}` runs when the list is empty:

</div>

```html
&#123;% for product in products %&#125;
    <div class="product-card">&#123;&#123; product.name &#125;&#125;</div>
&#123;% else %&#125;
    <p>No products found.</p>
&#123;% endfor %&#125;
```

### set -- Local Variables

Create or update a variable inside a template:

```html
&#123;% set greeting = "Hello" %&#125;
&#123;% set full_name = user.first_name ~ " " ~ user.last_name %&#125;

<p>&#123;&#123; greeting &#125;&#125;, &#123;&#123; full_name &#125;&#125;!</p>
```

The `~` operator concatenates strings.

---

## 6. Template Inheritance

Template inheritance kills duplication. A base template defines blocks. Child templates override them.

### Base Template

Create `src/templates/base.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>&#123;% block title %&#125;My Store&#123;% endblock %&#125;</title>
    <link rel="stylesheet" href="/css/tina4.css">
    &#123;% block head %&#125;&#123;% endblock %&#125;
</head>
<body>
    <nav>
        <a href="/">Home</a>
        <a href="/products">Products</a>
        <a href="/about">About</a>
    </nav>

    <main>
        &#123;% block content %&#125;&#123;% endblock %&#125;
    </main>

    <footer>
        <p>&copy; 2026 My Store</p>
    </footer>

    <script src="/js/frond.js"></script>
    &#123;% block scripts %&#125;&#123;% endblock %&#125;
</body>
</html>
```

### Child Template

Create `src/templates/home.html`:

```html
&#123;% extends "base.html" %&#125;

&#123;% block title %&#125;Home - My Store&#123;% endblock %&#125;

&#123;% block content %&#125;
    <h1>Welcome to My Store</h1>
    <p>Browse our collection of quality products.</p>
&#123;% endblock %&#125;
```

When Frond renders `home.html`:

<div v-pre>

1. It sees `{% extends "base.html" %}` and loads the base template.
2. The `{% block title %}` in `home.html` replaces the one in `base.html`.
3. The `{% block content %}` in `home.html` replaces the one in `base.html`.
4. Blocks not overridden (`head`, `scripts`) keep their default content (empty here).

</div>

### Calling Parent Blocks

<div v-pre>

Use `{{ parent() }}` to include the parent block's content:

</div>

```html
&#123;% extends "base.html" %&#125;

&#123;% block head %&#125;
    &#123;&#123; parent() &#125;&#125;
    <link rel="stylesheet" href="/css/products.css">
&#123;% endblock %&#125;
```

<div v-pre>

This keeps whatever the parent had in `{% block head %}` and adds the extra stylesheet.

</div>

---

## 7. Include and Macro

### include

Pull in another template file:

```html
&#123;% include "partials/header.html" %&#125;

<main>
    <h1>Products</h1>
</main>

&#123;% include "partials/footer.html" %&#125;
```

Pass variables to included templates:

```html
&#123;% include "partials/product-card.html" with {"product": featured_product} %&#125;
```

### macro -- Reusable Template Functions

Macros are functions for templates. Define once, use everywhere:

Create `src/templates/macros/forms.html`:

```html
&#123;% macro input(name, label, type="text", value="", required=false) %&#125;
    <div class="form-group">
        <label for="&#123;&#123; name &#125;&#125;">&#123;&#123; label &#125;&#125;&#123;% if required %&#125; *&#123;% endif %&#125;</label>
        <input type="&#123;&#123; type &#125;&#125;" name="&#123;&#123; name &#125;&#125;" id="&#123;&#123; name &#125;&#125;"
               value="&#123;&#123; value &#125;&#125;" &#123;&#123; "required" if required else "" &#125;&#125;>
    </div>
&#123;% endmacro %&#125;

&#123;% macro textarea(name, label, value="", rows=4) %&#125;
    <div class="form-group">
        <label for="&#123;&#123; name &#125;&#125;">&#123;&#123; label &#125;&#125;</label>
        <textarea name="&#123;&#123; name &#125;&#125;" id="&#123;&#123; name &#125;&#125;" rows="&#123;&#123; rows &#125;&#125;">&#123;&#123; value &#125;&#125;</textarea>
    </div>
&#123;% endmacro %&#125;

&#123;% macro button(text, type="submit", class="btn-primary") %&#125;
    <button type="&#123;&#123; type &#125;&#125;" class="btn &#123;&#123; class &#125;&#125;">&#123;&#123; text &#125;&#125;</button>
&#123;% endmacro %&#125;
```

Use them:

```html
&#123;% import "macros/forms.html" as forms %&#125;

<form method="POST" action="/api/contact">
    &#123;&#123; forms.input("name", "Your Name", required=true) &#125;&#125;
    &#123;&#123; forms.input("email", "Email Address", type="email", required=true) &#125;&#125;
    &#123;&#123; forms.textarea("message", "Your Message", rows=6) &#125;&#125;
    &#123;&#123; forms.button("Send Message") &#125;&#125;
</form>
```

Consistent markup. Change the macro once and every form in your application updates.

---

## 8. Comments

<div v-pre>

Use `{# #}` for template comments. Stripped from output:

</div>

```html
&#123;# This comment will not appear in the HTML source #&#125;
<p>Visible content</p>

&#123;#
    Multi-line comments work too.
    Use them to document template logic.
#}
```

Unlike HTML comments (`<!-- -->`), Frond comments never reach the browser.

---

## 9. tina4css

The `tina4.css` file is Tina4's built-in CSS utility framework. It ships with every project. Layout utilities. Typography. Spacing. Common UI patterns. No Bootstrap. No Tailwind. No separate download.

Some common classes:

```html
&#123;# Grid layout #&#125;
<div class="grid grid-cols-3 gap-4">
    <div class="card">Item 1</div>
    <div class="card">Item 2</div>
    <div class="card">Item 3</div>
</div>

&#123;# Flex layout #&#125;
<div class="flex justify-between items-center">
    <h1>Title</h1>
    <button class="btn btn-primary">Action</button>
</div>

&#123;# Spacing #&#125;
<div class="p-4 m-2">Padded and margined</div>

&#123;# Typography #&#125;
<p class="text-lg text-gray-600">Large gray text</p>
```

The full tina4css reference is in Book 0. For this chapter, inline styles in the examples work fine.

---

## 10. Exercise: Build a Product Catalog Page

Build a product catalog page with categories, filtering, and a detail view.

### Requirements

1. Create a route at `GET /catalog` that renders a product catalog page
2. Create a route at `GET /catalog/{id:int}` that renders a single product detail page
3. Use template inheritance with a base layout
4. Display products in a grid with:
   - Product name, price (formatted to 2 decimal places), category
   - "In Stock" / "Out of Stock" badge
   - Featured products get a highlighted border
5. Show category filter links at the top (all categories from the data)
6. Support `?category=` query parameter to filter products
7. The detail page shows full product info including description
8. Use at least one macro (e.g., for the product card)
9. Use the `|default` filter somewhere meaningful

Use this data:

```python
products = [
    {"id": 1, "name": "Espresso Machine", "category": "Kitchen", "price": 299.99, "in_stock": True, "featured": True, "description": "Professional-grade espresso machine with 15-bar pressure pump and built-in grinder."},
    {"id": 2, "name": "Yoga Mat", "category": "Fitness", "price": 29.99, "in_stock": True, "featured": False, "description": "Extra-thick 6mm yoga mat with non-slip surface. Available in 5 colors."},
    {"id": 3, "name": "Standing Desk", "category": "Office", "price": 549.99, "in_stock": True, "featured": True, "description": "Electric sit-stand desk with memory presets and cable management tray."},
    {"id": 4, "name": "Noise-Canceling Headphones", "category": "Electronics", "price": 199.99, "in_stock": False, "featured": True, "description": "Wireless headphones with adaptive noise canceling and 30-hour battery life."},
    {"id": 5, "name": "Water Bottle", "category": "Fitness", "price": 24.99, "in_stock": True, "featured": False, "description": "Insulated stainless steel bottle, keeps drinks cold for 24 hours."},
    {"id": 6, "name": "Desk Lamp", "category": "Office", "price": 79.99, "in_stock": True, "featured": False, "description": "LED desk lamp with adjustable color temperature and brightness."}
]
```

---

## 11. Solution

Create `src/templates/macros/catalog.html`:

```html
&#123;% macro product_card(product) %&#125;
    <div class="product-card &#123;&#123; 'featured' if product.featured else '' &#125;&#125;">
        &#123;% if product.featured %&#125;
            <span class="featured-badge">Featured</span>
        &#123;% endif %&#125;
        <h3><a href="/catalog/&#123;&#123; product.id &#125;&#125;">&#123;&#123; product.name &#125;&#125;</a></h3>
        <p class="category">&#123;&#123; product.category &#125;&#125;</p>
        <p class="price">$&#123;&#123; "%.2f"|format(product.price) &#125;&#125;</p>
        &#123;% if product.in_stock %&#125;
            <span class="badge badge-success">In Stock</span>
        &#123;% else %&#125;
            <span class="badge badge-danger">Out of Stock</span>
        &#123;% endif %&#125;
    </div>
&#123;% endmacro %&#125;
```

Create `src/templates/catalog.html`:

```html
&#123;% extends "base.html" %&#125;
&#123;% import "macros/catalog.html" as catalog %&#125;

&#123;% block title %&#125;&#123;&#123; page_title | default("Product Catalog") &#125;&#125;&#123;% endblock %&#125;

&#123;% block content %&#125;
    <h1>&#123;&#123; page_title | default("Product Catalog") &#125;&#125;</h1>

    <div class="category-filters">
        <a href="/catalog" class="&#123;&#123; 'active' if active_category is not defined else '' &#125;&#125;">All</a>
        &#123;% for cat in categories %&#125;
            <a href="/catalog?category=&#123;&#123; cat &#125;&#125;"
               class="&#123;&#123; 'active' if active_category == cat else '' &#125;&#125;">&#123;&#123; cat &#125;&#125;</a>
        &#123;% endfor %&#125;
    </div>

    <p class="stats">Showing &#123;&#123; products | length &#125;&#125; product&#123;&#123; "s" if products|length != 1 else "" &#125;&#125;</p>

    <div class="product-grid">
        &#123;% for product in products %&#125;
            &#123;&#123; catalog.product_card(product) &#125;&#125;
        &#123;% else %&#125;
            <p>No products found in this category.</p>
        &#123;% endfor %&#125;
    </div>
&#123;% endblock %&#125;
```

Create `src/templates/product_detail.html`:

```html
&#123;% extends "base.html" %&#125;

&#123;% block title %&#125;&#123;&#123; product.name &#125;&#125; - My Store&#123;% endblock %&#125;

&#123;% block content %&#125;
    <a href="/catalog">&larr; Back to catalog</a>

    <div class="product-detail">
        <h1>&#123;&#123; product.name &#125;&#125;</h1>
        <p class="category">&#123;&#123; product.category &#125;&#125;</p>
        <p class="price">$&#123;&#123; "%.2f"|format(product.price) &#125;&#125;</p>
        &#123;% if product.in_stock %&#125;
            <span class="badge badge-success">In Stock</span>
        &#123;% else %&#125;
            <span class="badge badge-danger">Out of Stock</span>
        &#123;% endif %&#125;
        &#123;% if product.featured %&#125;
            <span class="featured-badge">Featured</span>
        &#123;% endif %&#125;
        <div class="description">
            <h2>Description</h2>
            <p>&#123;&#123; product.description | default("No description available.") &#125;&#125;</p>
        </div>
    </div>
&#123;% endblock %&#125;
```

Create `src/routes/catalog.py`:

```python
from tina4_python.core.router import get

products = [
    {"id": 1, "name": "Espresso Machine", "category": "Kitchen", "price": 299.99, "in_stock": True, "featured": True, "description": "Professional-grade espresso machine with 15-bar pressure pump and built-in grinder."},
    {"id": 2, "name": "Yoga Mat", "category": "Fitness", "price": 29.99, "in_stock": True, "featured": False, "description": "Extra-thick 6mm yoga mat with non-slip surface. Available in 5 colors."},
    {"id": 3, "name": "Standing Desk", "category": "Office", "price": 549.99, "in_stock": True, "featured": True, "description": "Electric sit-stand desk with memory presets and cable management tray."},
    {"id": 4, "name": "Noise-Canceling Headphones", "category": "Electronics", "price": 199.99, "in_stock": False, "featured": True, "description": "Wireless headphones with adaptive noise canceling and 30-hour battery life."},
    {"id": 5, "name": "Water Bottle", "category": "Fitness", "price": 24.99, "in_stock": True, "featured": False, "description": "Insulated stainless steel bottle, keeps drinks cold for 24 hours."},
    {"id": 6, "name": "Desk Lamp", "category": "Office", "price": 79.99, "in_stock": True, "featured": False, "description": "LED desk lamp with adjustable color temperature and brightness."}
]


@get("/catalog")
async def catalog_page(request, response):
    category = request.query.get("category")
    categories = sorted(set(p["category"] for p in products))

    if category:
        filtered = [p for p in products if p["category"].lower() == category.lower()]
    else:
        filtered = products

    return response.render("catalog.html", {
        "products": filtered,
        "categories": categories,
        "active_category": category,
        "page_title": f"{category} Products" if category else "Product Catalog"
    })


@get("/catalog/{id:int}")
async def product_detail(id, request, response):
    product_id = id

    for product in products:
        if product["id"] == product_id:
            return response.render("product_detail.html", {"product": product})

    return response.render("errors/404.html", {}, 404)
```

**Open `http://localhost:7145/catalog` in your browser.** You should see:

- A heading "Product Catalog"
- Category filter links: All, Electronics, Fitness, Kitchen, Office
- A count of products shown
- Product cards in a grid with names, prices, category labels, and stock badges
- Featured products have a highlighted style and a "Featured" badge
- Clicking a product name navigates to the detail page
- Clicking a category link filters the list

---

## 12. Gotchas

### 1. Whitespace in output

**Problem:** Your rendered HTML has unexpected blank lines or spaces.

**Cause:** Template tags produce whitespace on the line they occupy.

<div v-pre>

**Fix:** Use whitespace control with `{%-` and `-%}` to strip whitespace around tags:

</div>

```html
&#123;%- for item in items -%&#125;
    <li>&#123;&#123; item.name &#125;&#125;</li>
&#123;%- endfor -%&#125;
```

### 2. Variable not defined error

**Problem:** Frond raises an error when a variable does not exist in the context.

<div v-pre>

**Cause:** You used `{{ user.name }}` but did not pass `user` in the template data.

</div>

<div v-pre>

**Fix:** Use the `|default` filter: `{{ user.name | default("Guest") }}`. Or check first: `{% if user is defined %}{{ user.name }}{% endif %}`.

</div>

### 3. Extends must be the first tag

<div v-pre>

**Problem:** `{% extends "base.html" %}` has no effect and the page renders without the layout.

</div>

<div v-pre>

**Cause:** `{% extends %}` must be the first tag in the template. Any text, HTML, or tags before it cause Frond to treat the template as standalone.

</div>

<div v-pre>

**Fix:** Move `{% extends "base.html" %}` to the first line. No content before it.

</div>

### 4. Macro not found

<div v-pre>

**Problem:** `{{ forms.input(...) }}` produces an error about `forms` being undefined.

</div>

<div v-pre>

**Cause:** You forgot the `{% import %}` statement, or the import path is wrong.

</div>

<div v-pre>

**Fix:** Add `{% import "macros/forms.html" as forms %}` at the top of the template (after `{% extends %}` if using inheritance). The path is relative to `src/templates/`.

</div>

### 5. Filter produces wrong type

<div v-pre>

**Problem:** `{{ "%.2f"|format(price) }}` shows an error instead of a formatted number.

</div>

**Cause:** The variable `price` is a string, not a number. Filters expect specific types.

<div v-pre>

**Fix:** Pass correct types from your route handler. Use `float(price)` in Python before passing to the template, or convert in the template: `{{ "%.2f"|format(price|float) }}`.

</div>

### 6. Escaped HTML when you want raw output

**Problem:** Your HTML content shows as text with visible `<tags>` instead of rendering.

<div v-pre>

**Cause:** Frond auto-escapes all `{{ }}` output to prevent XSS.

</div>

<div v-pre>

**Fix:** Use the `|safe` filter: `{{ trusted_html | safe }}`. Only use this with content you trust -- never with user input.

</div>

### 7. Include file path wrong

<div v-pre>

**Problem:** `{% include "header.html" %}` gives a "template not found" error even though the file exists.

</div>

<div v-pre>

**Cause:** The path in `{% include %}` is relative to `src/templates/`, not the current template file.

</div>

<div v-pre>

**Fix:** Use the full path from the templates root: `{% include "partials/header.html" %}` for a file at `src/templates/partials/header.html`.

</div>
