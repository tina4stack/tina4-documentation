# Chapter 4: Templates

## 1. Beyond JSON -- Rendering HTML

Every route so far returns JSON. That works for APIs. But web applications need HTML -- product listings, dashboards, login forms, email templates. Tina4 uses the **Frond** template engine for this.

Frond is a zero-dependency template engine built from scratch. Its syntax is compatible with Twig, Jinja2, and Nunjucks. If you know any of those, you know Frond. If you do not, the syntax is three things: `{{ }}` for output, `{% %}` for logic, `{# #}` for comments.

Picture an online store. A product catalog page. Items in a grid. Featured products highlighted. Prices formatted. Layout inherited from a shared template. That is what this chapter builds.

---

## 2. The @template Decorator

The shortest path to a rendered template:

```python
from tina4_python.core.router import get, template

@template("about.html")
@get("/about")
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
<head><title>{{ title }}</title></head>
<body>
    <h1>{{ title }}</h1>
    <p>{{ company }} was founded in {{ founded }}.</p>
</body>
</html>
```

Visit `http://localhost:7145/about` and the rendered page appears.

The `@template` decorator is stacked above `@get` (or `@post`, etc.). When the handler returns a dictionary, the decorator passes that dict to `response.render()` with the named template. If the handler returns something other than a dict (like an already-built Response), it is passed through unchanged. You can also use `response.render()` directly in any route handler -- `@template` is shorthand.

---

## 3. Variables and Output

### Basic Output

Use `{{ }}` to output a variable:

```html
<h1>Hello, {{ name }}!</h1>
<p>Your balance is {{ balance }}.</p>
```

With data `{"name": "Alice", "balance": 150.50}`, this renders:

```html
<h1>Hello, Alice!</h1>
<p>Your balance is 150.5.</p>
```

### Accessing Nested Properties

Dot notation for dictionaries and object attributes:

```html
<p>{{ user.name }}</p>
<p>{{ user.address.city }}</p>
<p>{{ order.items.0.name }}</p>
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

### Method Calls and Slicing

Frond supports calling methods on values directly in templates. If a dictionary value is callable, you can invoke it with arguments:

```html
{{ user.t("greeting") }}       {# calls user.t("greeting") #}
{{ text[:10] }}                {# slice syntax -- first 10 characters #}
{{ items[2:5] }}               {# slice from index 2 to 5 #}
```

Operators inside quoted function arguments (like `+`, `-`, `*`) are handled correctly and will not break the expression parser.

### Auto-Escaping

Frond escapes HTML characters in output by default. XSS attacks die here:

```html
<p>{{ user_input }}</p>
```

With `{"user_input": "<script>alert('hacked')</script>"}`, this renders:

```html
<p>&lt;script&gt;alert(&#39;hacked&#39;)&lt;/script&gt;</p>
```

The script tag is escaped. Displayed as text. Never executes. If you need raw HTML (and you trust the source), use the `|safe` filter:

```html
<div>{{ trusted_html | safe }}</div>
```

---

## 4. Filters

Filters transform output. The pipe `|` applies them:

```html
{{ name | upper }}          {# ALICE #}
{{ name | lower }}          {# alice #}
{{ name | capitalize }}     {# Alice #}
{{ name | title }}          {# Alice Smith #}
{{ bio | trim }}            {# Removes leading/trailing whitespace #}
```

### Number Formatting

```html
{{ "%.2f"|format(price) }}              {# 79.99 #}
{{ "{:,}"|format(large_number) }}       {# 1,234,567 #}
{{ percentage | round(1) }}             {# 85.3 #}
```

### String Filters

```html
{{ text | replace("old", "new") }}      {# Replace substring #}
{{ title | striptags }}                  {# Remove HTML tags #}
{{ content | nl2br }}                   {# Convert newlines to <br> #}
{{ slug | url_encode }}                 {# URL-encode a string #}
{{ items | join(", ") }}                {# Join list with separator #}
```

### Collection Filters

```html
{{ items | length }}          {# Number of items #}
{{ items | first }}           {# First item #}
{{ items | last }}            {# Last item #}
{{ items | sort }}            {# Sort ascending #}
{{ items | reverse }}         {# Reverse order #}
{{ items | unique }}          {# Remove duplicates #}
{{ items | slice(0, 3) }}     {# First 3 items #}
{{ items | batch(3) }}        {# Group into batches of 3 #}
```

### Date Formatting

```html
{{ created_at | date("Y-m-d") }}        {# 2026-03-22 #}
{{ created_at | date("d M Y") }}        {# 22 Mar 2026 #}
{{ created_at | date("H:i:s") }}        {# 14:30:00 #}
```

### Encoding Filters

```html
{{ data | json_encode }}                {# {"key": "value"} #}
{{ text | base64encode }}               {# Base64 encoded #}
{{ encoded | base64decode }}            {# Base64 decoded #}
```

### Chaining Filters

Filters chain left to right:

```html
{{ name | trim | lower | capitalize }}
{# "  alice smith  " → "alice smith" → "Alice smith" #}

{{ items | sort | reverse | first }}
{# Sort, reverse, take first = largest item #}
```

### The default Filter

A fallback when a variable is empty or undefined:

```html
{{ username | default("Guest") }}
{{ bio | default("No bio provided.") }}
{{ theme | default("light") }}
```

---

## 5. Control Tags

### if / elif / else

```html
{% if user.role == "admin" %}
    <span class="badge">Admin</span>
{% elif user.role == "moderator" %}
    <span class="badge">Moderator</span>
{% else %}
    <span class="badge">Member</span>
{% endif %}
```

Comparisons and logical operators:

```html
{% if price > 100 and in_stock %}
    <p>Premium item, available now!</p>
{% endif %}

{% if not user.verified %}
    <p>Please verify your email.</p>
{% endif %}

{% if not items %}
    <p>Your cart is empty.</p>
{% endif %}
```

### for Loops

```html
{% for product in products %}
    <div class="product-card">
        <h3>{{ product.name }}</h3>
        <p>${{ "%.2f"|format(product.price) }}</p>
    </div>
{% endfor %}
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
{% for item in items %}
    <li class="{{ 'first' if loop.first else '' }} {{ 'last' if loop.last else '' }}">
        {{ loop.index }}. {{ item.name }}
    </li>
{% endfor %}
</ol>
```

### for / else

The `{% else %}` block inside `{% for %}` runs when the list is empty:

```html
{% for product in products %}
    <div class="product-card">{{ product.name }}</div>
{% else %}
    <p>No products found.</p>
{% endfor %}
```

### set -- Local Variables

Create or update a variable inside a template:

```html
{% set greeting = "Hello" %}
{% set full_name = user.first_name ~ " " ~ user.last_name %}

<p>{{ greeting }}, {{ full_name }}!</p>
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
    <title>{% block title %}My Store{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.css">
    {% block head %}{% endblock %}
</head>
<body>
    <nav>
        <a href="/">Home</a>
        <a href="/products">Products</a>
        <a href="/about">About</a>
    </nav>

    <main>
        {% block content %}{% endblock %}
    </main>

    <footer>
        <p>&copy; 2026 My Store</p>
    </footer>

    <script src="/js/frond.js"></script>
    {% block scripts %}{% endblock %}
</body>
</html>
```

### Child Template

Create `src/templates/home.html`:

```html
{% extends "base.html" %}

{% block title %}Home - My Store{% endblock %}

{% block content %}
    <h1>Welcome to My Store</h1>
    <p>Browse our collection of quality products.</p>
{% endblock %}
```

When Frond renders `home.html`:

1. It sees `{% extends "base.html" %}` and loads the base template.
2. The `{% block title %}` in `home.html` replaces the one in `base.html`.
3. The `{% block content %}` in `home.html` replaces the one in `base.html`.
4. Blocks not overridden (`head`, `scripts`) keep their default content (empty here).

### Calling Parent Blocks

Use `{{ parent() }}` to include the parent block's content:

```html
{% extends "base.html" %}

{% block head %}
    {{ parent() }}
    <link rel="stylesheet" href="/css/products.css">
{% endblock %}
```

This keeps whatever the parent had in `{% block head %}` and adds the extra stylesheet.

---

## 7. Include and Macro

### include

Pull in another template file:

```html
{% include "partials/header.html" %}

<main>
    <h1>Products</h1>
</main>

{% include "partials/footer.html" %}
```

Pass variables to included templates:

```html
{% include "partials/product-card.html" with {"product": featured_product} %}
```

### macro -- Reusable Template Functions

Macros are functions for templates. Define once, use everywhere:

Create `src/templates/macros/forms.html`:

```html
{% macro input(name, label, type="text", value="", required=false) %}
    <div class="form-group">
        <label for="{{ name }}">{{ label }}{% if required %} *{% endif %}</label>
        <input type="{{ type }}" name="{{ name }}" id="{{ name }}"
               value="{{ value }}" {{ "required" if required else "" }}>
    </div>
{% endmacro %}

{% macro textarea(name, label, value="", rows=4) %}
    <div class="form-group">
        <label for="{{ name }}">{{ label }}</label>
        <textarea name="{{ name }}" id="{{ name }}" rows="{{ rows }}">{{ value }}</textarea>
    </div>
{% endmacro %}

{% macro button(text, type="submit", class="btn-primary") %}
    <button type="{{ type }}" class="btn {{ class }}">{{ text }}</button>
{% endmacro %}
```

Use them:

```html
{% import "macros/forms.html" as forms %}

<form method="POST" action="/api/contact">
    {{ forms.input("name", "Your Name", required=true) }}
    {{ forms.input("email", "Email Address", type="email", required=true) }}
    {{ forms.textarea("message", "Your Message", rows=6) }}
    {{ forms.button("Send Message") }}
</form>
```

Consistent markup. Change the macro once and every form in your application updates.

---

## 8. Comments

Use `{# #}` for template comments. Stripped from output:

```html
{# This comment will not appear in the HTML source #}
<p>Visible content</p>

{#
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
{# Grid layout #}
<div class="grid grid-cols-3 gap-4">
    <div class="card">Item 1</div>
    <div class="card">Item 2</div>
    <div class="card">Item 3</div>
</div>

{# Flex layout #}
<div class="flex justify-between items-center">
    <h1>Title</h1>
    <button class="btn btn-primary">Action</button>
</div>

{# Spacing #}
<div class="p-4 m-2">Padded and margined</div>

{# Typography #}
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
{% macro product_card(product) %}
    <div class="product-card {{ 'featured' if product.featured else '' }}">
        {% if product.featured %}
            <span class="featured-badge">Featured</span>
        {% endif %}
        <h3><a href="/catalog/{{ product.id }}">{{ product.name }}</a></h3>
        <p class="category">{{ product.category }}</p>
        <p class="price">${{ "%.2f"|format(product.price) }}</p>
        {% if product.in_stock %}
            <span class="badge badge-success">In Stock</span>
        {% else %}
            <span class="badge badge-danger">Out of Stock</span>
        {% endif %}
    </div>
{% endmacro %}
```

Create `src/templates/catalog.html`:

```html
{% extends "base.html" %}
{% import "macros/catalog.html" as catalog %}

{% block title %}{{ page_title | default("Product Catalog") }}{% endblock %}

{% block content %}
    <h1>{{ page_title | default("Product Catalog") }}</h1>

    <div class="category-filters">
        <a href="/catalog" class="{{ 'active' if active_category is not defined else '' }}">All</a>
        {% for cat in categories %}
            <a href="/catalog?category={{ cat }}"
               class="{{ 'active' if active_category == cat else '' }}">{{ cat }}</a>
        {% endfor %}
    </div>

    <p class="stats">Showing {{ products | length }} product{{ "s" if products|length != 1 else "" }}</p>

    <div class="product-grid">
        {% for product in products %}
            {{ catalog.product_card(product) }}
        {% else %}
            <p>No products found in this category.</p>
        {% endfor %}
    </div>
{% endblock %}
```

Create `src/templates/product_detail.html`:

```html
{% extends "base.html" %}

{% block title %}{{ product.name }} - My Store{% endblock %}

{% block content %}
    <a href="/catalog">&larr; Back to catalog</a>

    <div class="product-detail">
        <h1>{{ product.name }}</h1>
        <p class="category">{{ product.category }}</p>
        <p class="price">${{ "%.2f"|format(product.price) }}</p>
        {% if product.in_stock %}
            <span class="badge badge-success">In Stock</span>
        {% else %}
            <span class="badge badge-danger">Out of Stock</span>
        {% endif %}
        {% if product.featured %}
            <span class="featured-badge">Featured</span>
        {% endif %}
        <div class="description">
            <h2>Description</h2>
            <p>{{ product.description | default("No description available.") }}</p>
        </div>
    </div>
{% endblock %}
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
    category = request.params.get("category")
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

**Fix:** Use whitespace control with `{%-` and `-%}` to strip whitespace around tags:

```html
{%- for item in items -%}
    <li>{{ item.name }}</li>
{%- endfor -%}
```

### 2. Variable not defined error

**Problem:** Frond raises an error when a variable does not exist in the context.

**Cause:** You used `{{ user.name }}` but did not pass `user` in the template data.

**Fix:** Use the `|default` filter: `{{ user.name | default("Guest") }}`. Or check first: `{% if user is defined %}{{ user.name }}{% endif %}`.

### 3. Extends must be the first tag

**Problem:** `{% extends "base.html" %}` has no effect and the page renders without the layout.

**Cause:** `{% extends %}` must be the first tag in the template. Any text, HTML, or tags before it cause Frond to treat the template as standalone.

**Fix:** Move `{% extends "base.html" %}` to the first line. No content before it.

### 4. Macro not found

**Problem:** `{{ forms.input(...) }}` produces an error about `forms` being undefined.

**Cause:** You forgot the `{% import %}` statement, or the import path is wrong.

**Fix:** Add `{% import "macros/forms.html" as forms %}` at the top of the template (after `{% extends %}` if using inheritance). The path is relative to `src/templates/`.

### 5. Filter produces wrong type

**Problem:** `{{ "%.2f"|format(price) }}` shows an error instead of a formatted number.

**Cause:** The variable `price` is a string, not a number. Filters expect specific types.

**Fix:** Pass correct types from your route handler. Use `float(price)` in Python before passing to the template, or convert in the template: `{{ "%.2f"|format(price|float) }}`.

### 6. Escaped HTML when you want raw output

**Problem:** Your HTML content shows as text with visible `<tags>` instead of rendering.

**Cause:** Frond auto-escapes all `{{ }}` output to prevent XSS.

**Fix:** Use the `|safe` filter: `{{ trusted_html | safe }}`. Only use this with content you trust -- never with user input.

### 7. Include file path wrong

**Problem:** `{% include "header.html" %}` gives a "template not found" error even though the file exists.

**Cause:** The path in `{% include %}` is relative to `src/templates/`, not the current template file.

**Fix:** Use the full path from the templates root: `{% include "partials/header.html" %}` for a file at `src/templates/partials/header.html`.
