# Chapter 4: Templates

## 1. Beyond JSON -- Rendering HTML

Every route so far returns JSON. That works for APIs. Web applications need HTML -- product listings, dashboards, login forms, email templates. Tina4 uses the **Frond** template engine for this work.

Frond is a zero-dependency template engine built from scratch. Its syntax matches Twig, Jinja2, and Nunjucks. Three constructs drive the entire engine: `{{ }}` for output, `{% %}` for logic, `{# #}` for comments. That is the whole grammar.

This chapter builds toward a product catalog page. Items in a grid. Featured products highlighted. Prices formatted. Layout inherited from a shared template. One engine handles it all.

---

## 2. The @template Decorator

The shortest path to a rendered page:

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

The `@template` decorator stacks above `@get` (or `@post`, etc.). When the handler returns a dictionary, the decorator passes that dict to `response.render()` with the named template. If the handler returns something other than a dict -- an already-built Response, for instance -- the decorator passes it through unchanged. You can also call `response.render()` directly in any route handler. The decorator is shorthand.

---

## 3. Variables and Output

### Basic Output

Double curly braces print a variable:

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

Dot notation reaches into dictionaries and object attributes:

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

Frond supports calling methods on values inside templates. If a dictionary value is callable, you invoke it with arguments:

```html
{{ user.t("greeting") }}       {# calls user.t("greeting") #}
{{ text[:10] }}                {# slice syntax -- first 10 characters #}
{{ items[2:5] }}               {# slice from index 2 to 5 #}
```

Operators inside quoted function arguments (such as `+`, `-`, `*`) parse without breaking the expression.

### Auto-Escaping

Frond escapes HTML characters in output by default. XSS attacks die here:

```html
<p>{{ user_input }}</p>
```

With `{"user_input": "<script>alert('hacked')</script>"}`, this renders:

```html
<p>&lt;script&gt;alert(&#39;hacked&#39;)&lt;/script&gt;</p>
```

The script tag becomes plain text. It never executes. If you need raw HTML output and you trust the source, use the `|safe` filter:

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

### Complete Filter Reference

#### String Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `upper` | `{{ name \| upper }}` | Convert to uppercase |
| `lower` | `{{ name \| lower }}` | Convert to lowercase |
| `capitalize` | `{{ name \| capitalize }}` | Capitalize first letter |
| `title` | `{{ name \| title }}` | Capitalize each word |
| `trim` | `{{ name \| trim }}` | Strip leading/trailing whitespace |
| `ltrim` | `{{ name \| ltrim }}` | Strip leading whitespace |
| `rtrim` | `{{ name \| rtrim }}` | Strip trailing whitespace |
| `slug` | `{{ title \| slug }}` | Convert to URL-friendly slug |
| `wordwrap(80)` | `{{ text \| wordwrap(80) }}` | Wrap text at N characters |
| `truncate(100)` | `{{ text \| truncate(100) }}` | Truncate to N characters with ellipsis |
| `nl2br` | `{{ text \| nl2br }}` | Convert newlines to `<br>` tags |
| `striptags` | `{{ html \| striptags }}` | Remove all HTML tags |
| `replace("a", "b")` | `{{ text \| replace("old", "new") }}` | Replace occurrences of a substring |

#### Array Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `length` | `{{ items \| length }}` | Count items in array or string length |
| `reverse` | `{{ items \| reverse }}` | Reverse order of items |
| `sort` | `{{ items \| sort }}` | Sort items ascending |
| `shuffle` | `{{ items \| shuffle }}` | Randomly shuffle items |
| `first` | `{{ items \| first }}` | Get the first item |
| `last` | `{{ items \| last }}` | Get the last item |
| `join(", ")` | `{{ items \| join(", ") }}` | Join array items with separator |
| `split(",")` | `{{ csv \| split(",") }}` | Split string into array |
| `unique` | `{{ items \| unique }}` | Remove duplicate values |
| `filter` | `{{ items \| filter }}` | Remove falsy values from array |
| `map("name")` | `{{ items \| map("name") }}` | Extract a property from each item |
| `column("name")` | `{{ items \| column("name") }}` | Extract a column from array of objects |
| `batch(3)` | `{{ items \| batch(3) }}` | Group items into batches of N |
| `slice(0, 3)` | `{{ items \| slice(0, 3) }}` | Extract a slice from offset with length |

#### Encoding Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `escape` (`e`) | `{{ text \| escape }}` | HTML-escape special characters |
| `raw` (`safe`) | `{{ html \| raw }}` | Output without auto-escaping |
| `url_encode` | `{{ text \| url_encode }}` | URL-encode a string |
| `base64_encode` (`base64encode`) | `{{ text \| base64_encode }}` | Base64-encode a string |
| `base64_decode` (`base64decode`) | `{{ data \| base64_decode }}` | Base64-decode a string |
| `md5` | `{{ text \| md5 }}` | Compute MD5 hash |
| `sha256` | `{{ text \| sha256 }}` | Compute SHA-256 hash |

#### Numeric Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `abs` | `{{ num \| abs }}` | Absolute value |
| `round(2)` | `{{ price \| round(2) }}` | Round to N decimal places |
| `number_format(2)` | `{{ price \| number_format(2) }}` | Format with decimals and thousands separator |
| `int` | `{{ val \| int }}` | Cast to integer |
| `float` | `{{ val \| float }}` | Cast to float |
| `string` | `{{ val \| string }}` | Cast to string |

#### JSON Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `json_encode` | `{{ data \| json_encode }}` | Encode value as JSON string |
| `to_json` (`tojson`) | `{{ data \| to_json }}` | Encode value as JSON string (alias) |
| `json_decode` | `{{ str \| json_decode }}` | Decode JSON string to object |
| `js_escape` | `{{ text \| js_escape }}` | Escape string for safe use in JavaScript |

#### Dict Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `keys` | `{{ obj \| keys }}` | Get dictionary keys as array |
| `values` | `{{ obj \| values }}` | Get dictionary values as array |
| `merge(other)` | `{{ defaults \| merge(overrides) }}` | Merge two dictionaries |

#### Other Filters

| Filter | Example | Description |
|--------|---------|-------------|
| `default("fallback")` | `{{ name \| default("Guest") }}` | Fallback when value is empty or undefined |
| `date("Y-m-d")` | `{{ created \| date("Y-m-d") }}` | Format a date value |
| `format(val)` | `{{ "%.2f" \| format(price) }}` | Format string with value (sprintf-style) |
| `data_uri` | `{{ content \| data_uri }}` | Convert to a data URI string |
| `dump` | `{{ var \| dump }}` | Debug output of a variable |
| `form_token` | `{{ form_token() }}` | Generate a CSRF hidden input with token |
| `formTokenValue` | `{{ formTokenValue("context") }}` | Return the raw JWT token string |
| `to_json` | `{{ data \| to_json }}` | JSON-encode a value (no double-escaping) |
| `js_escape` | `{{ text \| js_escape }}` | Escape for safe use in JavaScript strings |

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

Inside a for loop, the `loop` variable provides iteration context:

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
{% set total = price * quantity %}
{% set discount = total - rebate %}

<p>{{ greeting }}, {{ full_name }}!</p>
<p>Total: {{ total }}, After discount: {{ discount }}</p>
```

The `~` operator concatenates strings. Arithmetic operators (`+`, `-`, `*`, `/`, `//`, `%`, `**`) work in `set` and expressions.

When combining filters with arithmetic, assign the filtered values first:

```html
{% set dr = account.dr|default(0) %}
{% set cr = account.cr|default(0) %}
{% set balance = dr - cr %}
<p>Balance: {{ balance }}</p>
```

---

## 6. Template Inheritance

Template inheritance kills duplication. A base template defines blocks. Child templates override them. One layout file controls every page.

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
4. Blocks not overridden (`head`, `scripts`) keep their default content -- empty here.

### Calling Parent Blocks

Use `{{ parent() }}` to include the parent block's content:

```html
{% extends "base.html" %}

{% block head %}
    {{ parent() }}
    <link rel="stylesheet" href="/css/products.css">
{% endblock %}
```

The `head` block now contains everything from the base plus the extra stylesheet.

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

Macros are functions for templates. Define once, call everywhere:

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

Change the macro once and every form in your application updates. Consistent markup across the entire project.

---

## 8. Comments

Template comments use `{# #}`. Frond strips them from the output:

```html
{# This comment will not appear in the HTML source #}
<p>Visible content</p>

{#
    Multi-line comments work too.
    Use them to document template logic.
#}
```

HTML comments (`<!-- -->`) reach the browser. Frond comments never do.

---

## 9. Special Tags

### {% raw %} -- Literal Output

Output literal `{{ }}` or `{% %}` without processing. This tag saves you when embedding Vue.js or Angular templates:

```html
{% raw %}
    <div id="app">
        {{ message }}
    </div>
{% endraw %}
```

Frond outputs the literal text `{{ message }}`. No variable lookup. No expression parsing.

### {% spaceless %} -- Remove Whitespace

Strip whitespace between HTML tags:

```html
{% spaceless %}
    <div>
        <span>Hello</span>
    </div>
{% endspaceless %}
```

**Output:**

```html
<div><span>Hello</span></div>
```

Inline elements create visible gaps when whitespace sits between them. The `spaceless` tag eliminates those gaps.

### {% autoescape %} -- Control Escaping

Override auto-escaping for a block of content:

```html
{% autoescape false %}
    {{ trusted_html }}
{% endautoescape %}
```

Everything inside outputs without HTML escaping. This works the same as `| raw` on every variable, but handles large blocks of trusted content with less repetition. Never use this with user-submitted data.

### Whitespace Control

Template tags occupy a full line and produce blank lines in the output. Use `{%-` and `-%}` to strip surrounding whitespace:

```html
{%- for item in items -%}
    <li>{{ item.name }}</li>
{%- endfor -%}
```

The `-` on the left strips whitespace before the tag. The `-` on the right strips whitespace after. The output contains no blank lines between list items.

---

## 10. tina4css

The `tina4.css` file is Tina4's built-in CSS utility framework. It ships with every project. Layout utilities. Typography. Spacing. Common UI patterns. No Bootstrap. No Tailwind. No separate download.

Include it in your base template:

```html
<link rel="stylesheet" href="/css/tina4.css">
```

### Layout Classes

The grid system uses a 12-column layout:

```html
<div class="container">
    <div class="row">
        <div class="col-6">Left half</div>
        <div class="col-6">Right half</div>
    </div>
</div>
```

Flex layout for alignment:

```html
<div class="flex justify-between items-center">
    <h1>Title</h1>
    <button class="btn btn-primary">Action</button>
</div>
```

CSS grid for card layouts:

```html
<div class="grid grid-cols-3 gap-4">
    <div class="card">Item 1</div>
    <div class="card">Item 2</div>
    <div class="card">Item 3</div>
</div>
```

### Buttons

Five button styles cover most use cases:

```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-success">Success</button>
<button class="btn btn-warning">Warning</button>
<button class="btn btn-danger">Danger</button>
```

Link-style buttons use the same classes on anchor tags:

```html
<a href="/dashboard" class="btn btn-primary">Go to Dashboard</a>
<a href="/cancel" class="btn btn-secondary">Cancel</a>
```

### Cards

Cards group related content with optional header and footer sections:

```html
<div class="card">
    <div class="card-header">Order Summary</div>
    <div class="card-body">
        <p>3 items in your cart</p>
        <p class="text-primary">Total: $149.97</p>
    </div>
    <div class="card-footer">
        <button class="btn btn-primary">Checkout</button>
    </div>
</div>
```

Cards work well inside a grid for catalog-style layouts:

```html
<div class="grid grid-cols-3 gap-4">
    {% for product in products %}
    <div class="card">
        <div class="card-header">{{ product.name }}</div>
        <div class="card-body">
            <p>${{ "%.2f"|format(product.price) }}</p>
        </div>
    </div>
    {% endfor %}
</div>
```

### Alerts

Alert boxes communicate status messages to the user:

```html
<div class="alert alert-success">Order placed. Check your email for confirmation.</div>
<div class="alert alert-danger">Payment failed. Your card was declined.</div>
<div class="alert alert-warning">Your session expires in 5 minutes.</div>
<div class="alert alert-info">New features are available. See the changelog.</div>
```

### Forms

Form controls use `form-group` for spacing and `form-control` for input styling:

```html
<form method="POST" action="/api/contact">
    <div class="form-group">
        <label for="name">Full Name</label>
        <input type="text" id="name" name="name" class="form-control" required>
    </div>

    <div class="form-group">
        <label for="email">Email Address</label>
        <input type="email" id="email" name="email" class="form-control" required>
    </div>

    <div class="form-group">
        <label for="message">Message</label>
        <textarea id="message" name="message" class="form-control" rows="4"></textarea>
    </div>

    <div class="form-group">
        <label for="priority">Priority</label>
        <select id="priority" name="priority" class="form-control">
            <option value="low">Low</option>
            <option value="medium" selected>Medium</option>
            <option value="high">High</option>
        </select>
    </div>

    <button type="submit" class="btn btn-primary">Send Message</button>
    <button type="reset" class="btn btn-secondary">Clear</button>
</form>
```

### Tables

Tables gain borders and row striping with tina4css classes:

```html
<table class="table">
    <thead>
        <tr>
            <th>#</th>
            <th>Product</th>
            <th>Price</th>
        </tr>
    </thead>
    <tbody>
        {% for product in products %}
        <tr>
            <td>{{ loop.index }}</td>
            <td>{{ product.name }}</td>
            <td>${{ "%.2f"|format(product.price) }}</td>
        </tr>
        {% endfor %}
    </tbody>
</table>
```

### Spacing and Typography Utilities

```html
{# Spacing #}
<div class="p-4 m-2">Padded and margined</div>
<div class="mt-4">Margin top</div>
<div class="mb-2">Margin bottom</div>
<div class="px-3">Horizontal padding</div>

{# Typography #}
<p class="text-lg text-gray-600">Large gray text</p>
<p class="text-center">Centered text</p>
<p class="text-right">Right-aligned text</p>
<span class="text-muted">Gray text</span>
<span class="text-primary">Primary color text</span>
```

No external dependencies. If you prefer Bootstrap or Tailwind, swap the `<link>` tag. Tina4 does not care which CSS framework you choose.

---

## 11. Exercise: Build a Product Catalog Page

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

## 12. Solution

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
- Featured products wear a highlighted style and a "Featured" badge
- Clicking a product name navigates to the detail page
- Clicking a category link filters the list

---

## 13. Gotchas

### 1. Whitespace in output

**Problem:** Rendered HTML contains unexpected blank lines or spaces.

**Cause:** Template tags produce whitespace on the lines they occupy.

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

**Problem:** `{% extends "base.html" %}` has no effect. The page renders without the layout.

**Cause:** `{% extends %}` must be the first tag in the template. Any text, HTML, or tags before it cause Frond to treat the template as standalone.

**Fix:** Move `{% extends "base.html" %}` to the first line. Nothing before it.

### 4. Macro not found

**Problem:** `{{ forms.input(...) }}` produces an error about `forms` being undefined.

**Cause:** The `{% import %}` statement is missing, or the import path is wrong.

**Fix:** Add `{% import "macros/forms.html" as forms %}` at the top of the template (after `{% extends %}` if using inheritance). The path is relative to `src/templates/`.

### 5. Filter produces wrong type

**Problem:** `{{ "%.2f"|format(price) }}` shows an error instead of a formatted number.

**Cause:** The variable `price` is a string, not a number. Filters expect specific types.

**Fix:** Pass correct types from your route handler. Use `float(price)` in Python before passing to the template, or convert in the template: `{{ "%.2f"|format(price|float) }}`.

### 6. Escaped HTML when you want raw output

**Problem:** HTML content shows as text with visible `<tags>` instead of rendering.

**Cause:** Frond auto-escapes all `{{ }}` output to prevent XSS.

**Fix:** Use the `|safe` filter: `{{ trusted_html | safe }}`. Only use this with content you trust -- never with user input.

### 7. Include file path wrong

**Problem:** `{% include "header.html" %}` produces a "template not found" error even though the file exists.

**Cause:** The path in `{% include %}` is relative to `src/templates/`, not the current template file.

**Fix:** Use the full path from the templates root: `{% include "partials/header.html" %}` for a file at `src/templates/partials/header.html`.
