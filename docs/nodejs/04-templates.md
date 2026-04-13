# Chapter 4: Templates

## 1. Why Templates

In Chapter 1, you saw `res.html("products.html", data)` produce a full HTML page. That rendering was done by **Frond**, Tina4's built-in template engine. Zero dependencies. Twig-compatible. Built from scratch. If you know Twig, Jinja2, or Nunjucks, you know 90% of Frond.

Templates live in `src/templates/`. Call `res.html("page.html", data)` and Frond loads `src/templates/page.html`, processes the tags and expressions, and returns the final HTML.

This chapter covers every feature of the template engine. After this, you build real pages.

---

## 2. Variables and Expressions

Output a variable with double curly braces:

```html
<h1>Hello, {{ name }}!</h1>
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
    <h1>Hello, {{ name }}!</h1>
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
<p>{{ user.name }} lives in {{ user.address.city }}, {{ user.address.country }}.</p>
```

**Output:**

```
Alice lives in Cape Town, South Africa.
```

### Method Calls on Objects

If an object value is a function, Frond calls it automatically when accessed via dot notation. You can also call methods with arguments:

```typescript
const data = {
    user: {
        name: "Alice",
        t: (key: string) => translations[key] ?? key
    }
};

return res.html("page.html", data);
```

```html
<p>{{ user.name }}</p>
<p>{{ user.t("welcome_message") }}</p>
```

This works with any callable property. Arguments are evaluated as expressions, so you can pass variables, strings, or numbers.

### Expressions

Basic expressions work inside `{{ }}`:

```html
<p>Total: ${{ price * quantity }}</p>
<p>Discounted: ${{ price * 0.9 }}</p>
<p>Full name: {{ first_name ~ " " ~ last_name }}</p>
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
    <title>{% block title %}My App{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.css">
    {% block head %}{% endblock %}
</head>
<body>
    <nav>
        <a href="/">Home</a>
        <a href="/about">About</a>
        <a href="/contact">Contact</a>
    </nav>

    <main>
        {% block content %}{% endblock %}
    </main>

    <footer>
        <p>&copy; 2026 My App. All rights reserved.</p>
    </footer>

    <script src="/js/frond.js"></script>
    {% block scripts %}{% endblock %}
</body>
</html>
```

### Child Template

Create `src/templates/about.twig`:

```html
{% extends "base.twig" %}

{% block title %}About Us{% endblock %}

{% block content %}
    <h1>About Us</h1>
    <p>We have been building things since {{ founded_year }}.</p>
    <p>Our team has {{ team_size }} members across {{ office_count }} offices.</p>
{% endblock %}
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

### Using `{{ parent() }}`

Add to a block rather than replace it:

```html
{% extends "base.twig" %}

{% block head %}
    {{ parent() }}
    <link rel="stylesheet" href="/css/contact-form.css">
{% endblock %}

{% block content %}
    <h1>Contact Us</h1>
    <form>...</form>
{% endblock %}
```

---

## 4. Includes

Break templates into reusable pieces with `{% include %}`:

Create `src/templates/partials/header.twig`:

```html
<header>
    <div class="logo">{{ site_name | default("My App") }}</div>
    <nav>
        <a href="/">Home</a>
        <a href="/products">Products</a>
        <a href="/contact">Contact</a>
    </nav>
</header>
```

Create `src/templates/partials/product-card.twig`:

```html
<div class="product-card{{ product.featured ? ' featured' : '' }}">
    <h3>{{ product.name }}</h3>
    <p class="price">${{ product.price | number_format(2) }}</p>
    {% if product.inStock %}
        <span class="badge-success">In Stock</span>
    {% else %}
        <span class="badge-danger">Out of Stock</span>
    {% endif %}
</div>
```

Use them in a page:

```html
{% extends "base.twig" %}

{% block content %}
    {% include "partials/header.twig" %}

    <h1>Products</h1>
    {% for product in products %}
        {% include "partials/product-card.twig" %}
    {% endfor %}
{% endblock %}
```

### Passing Variables to Includes

```html
{% include "partials/header.twig" with {"site_name": "Cool Store"} %}
```

Use `only` to isolate the included template from the parent scope:

```html
{% include "partials/header.twig" with {"site_name": "Cool Store"} only %}
```

---

## 5. For Loops

Loop through arrays with `{% for %}`:

```html
<ul>
{% for item in items %}
    <li>{{ item }}</li>
{% endfor %}
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
    {% for product in products %}
        <tr class="{{ loop.index is odd ? 'row-light' : 'row-dark' }}">
            <td>{{ loop.index }}</td>
            <td>{{ product.name }}</td>
            <td>${{ product.price | number_format(2) }}</td>
        </tr>
    {% endfor %}
    </tbody>
</table>
```

### Empty Lists

Handle empty lists with `{% else %}`:

```html
{% for product in products %}
    <div class="product-card">
        <h3>{{ product.name }}</h3>
    </div>
{% else %}
    <p>No products found.</p>
{% endfor %}
```

### Looping Over Key-Value Pairs

```html
{% for key, value in metadata %}
    <dt>{{ key }}</dt>
    <dd>{{ value }}</dd>
{% endfor %}
```

---

## 6. Conditionals

### if / elseif / else

```html
{% if user.role == "admin" %}
    <a href="/admin">Admin Panel</a>
{% elseif user.role == "editor" %}
    <a href="/editor">Editor Dashboard</a>
{% else %}
    <a href="/profile">My Profile</a>
{% endif %}
```

### Ternary Operator

```html
<span class="{{ is_active ? 'text-green' : 'text-gray' }}">
    {{ is_active ? 'Active' : 'Inactive' }}
</span>
```

### Testing for Existence

```html
{% if error_message is defined %}
    <div class="alert alert-danger">{{ error_message }}</div>
{% endif %}
```

### {% set %} -- Local Variables

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

## 7. Filters

Filters transform values. Apply them with the `|` (pipe) character.

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
| `dump` | `{{ var \| dump }}` or `{{ dump(var) }}` | Debug output — gated on `TINA4_DEBUG=true` (see [Dumping Values](#dumping-values-for-debugging)) |
| `form_token` | `{{ form_token() }}` | Generate a CSRF hidden input with token |
| `formTokenValue` | `{{ formTokenValue("context") }}` | Return just the raw JWT token string |
| `to_json` | `{{ data \| to_json }}` | JSON-encode a value (safe, no double-escaping) |
| `js_escape` | `{{ text \| js_escape }}` | Escape for safe use in JavaScript strings |

### Chaining Filters

```html
{{ name | trim | lower | capitalize }}
{# "  ALICE SMITH  " -> "Alice smith" #}
```

### Dumping Values for Debugging

The `dump` helper lets you inspect any variable mid-template. Two interchangeable forms are supported:

```html
{{ user | dump }}
{{ dump(user) }}
```

Both produce the same `<pre>`-wrapped, HTML-escaped inspection of the value. Unlike `JSON.stringify`, the built-in inspector handles everything safely:

- **Circular references** — marked `[Circular]` (no crash)
- **BigInt** — shown as `123n` (no crash)
- **Map / Set** — `Map(2) { "a" => 1, "b" => 2 }` / `Set(3) { 1, 2, 3 }`
- **Date** — `Date(2026-04-09T13:00:00.000Z)` (type retained)
- **Error** — `Error("message")` (type + message)
- **Class instances** — `User { name: "Alice" }` (class name preserved)
- **Functions / Symbols / undefined** — shown inline, not silently dropped

```html
{{ dump(order) }}

{# Output: #}
{# <pre>Order { id: 42, items: [...], total: 99.99 }</pre> #}
```

**dump is gated on `TINA4_DEBUG=true`.** In production (env var unset or `false`) **both** the filter and function form silently return an empty `SafeString`. This prevents accidental leaks of internal state, object shapes, or sensitive values into rendered HTML if a developer leaves a `{{ dump(x) }}` call in a template.

```bash
# .env — dev
TINA4_DEBUG=true    # dump() outputs the value

# .env — production
TINA4_DEBUG=false   # dump() is a no-op
```

You can rely on this gate for safety, but treat `dump` as a development-only convenience. For structured output in production code paths, use `to_json`.

---

## 8. Macros

Macros are reusable template functions. Define once. Call many times.

### Defining a Macro

Create `src/templates/macros.twig`:

```html
{% macro button(text, url, style) %}
    <a href="{{ url | default('#') }}" class="btn btn-{{ style | default('primary') }}">
        {{ text }}
    </a>
{% endmacro %}

{% macro alert(message, type) %}
    <div class="alert alert-{{ type | default('info') }}">
        {{ message }}
    </div>
{% endmacro %}

{% macro input(name, label, type, value) %}
    <div class="form-group">
        <label for="{{ name }}">{{ label | default(name | capitalize) }}</label>
        <input type="{{ type | default('text') }}" id="{{ name }}" name="{{ name }}" value="{{ value | default('') }}">
    </div>
{% endmacro %}
```

### Using Macros

```html
{% from "macros.twig" import button, alert, input %}

{% extends "base.twig" %}

{% block content %}
    {{ alert("Your profile has been updated.", "success") }}

    <form method="POST" action="/profile">
        {{ input("name", "Full Name", "text", user.name) }}
        {{ input("email", "Email Address", "email", user.email) }}

        {{ button("Save Changes", "", "primary") }}
        {{ button("Cancel", "/dashboard", "secondary") }}
    </form>
{% endblock %}
```

---

## 9. Special Tags

### {% raw %} -- Literal Output

When you need to output literal `{{ }}` (for a Vue.js template, for example):

```html
{% raw %}
    <div id="app">
        {{ message }}
    </div>
{% endraw %}
```

### {% spaceless %} -- Remove Whitespace Between Tags

The `spaceless` tag strips whitespace between HTML tags. Useful for inline elements where whitespace affects layout:

```html
{% spaceless %}
    <div>
        <span>Hello</span>
        <span>World</span>
    </div>
{% endspaceless %}
```

Output:

```html
<div><span>Hello</span><span>World</span></div>
```

Only whitespace between tags is removed. Whitespace inside text content stays intact.

### {% autoescape %} -- Control HTML Escaping

By default, Frond escapes HTML in `{{ }}` output to prevent XSS attacks. The `autoescape` tag controls this behavior for a block:

```html
{% autoescape false %}
    {{ raw_html }}
{% endautoescape %}
```

With `autoescape false`, the variable outputs as raw HTML without escaping. Use this when you trust the content -- rendering Markdown-to-HTML output, for example.

To re-enable escaping inside a `false` block:

```html
{% autoescape false %}
    {{ trusted_html }}
    {% autoescape true %}
        {{ user_input }}
    {% endautoescape %}
{% endautoescape %}
```

### Whitespace Control

Use hyphens in tag delimiters to trim whitespace:

```html
{%- if condition -%}
    No leading or trailing whitespace around this block
{%- endif -%}
```

The `-` on the left trims whitespace before the tag. The `-` on the right trims whitespace after the tag. Works with `{{ }}`, `{% %}`, and `{# #}` delimiters.

### Comments

```html
{# This comment will not appear in the HTML output #}
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
    <title>{% block title %}Product Catalog{% endblock %}</title>
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
    {% block content %}{% endblock %}
    <script src="/js/frond.js"></script>
    {% block scripts %}{% endblock %}
</body>
</html>
```

Create `src/templates/catalog-macros.twig`:

```html
{% macro productCard(product) %}
    <div class="product-card{{ product.featured ? ' featured' : '' }}">
        <p class="product-name">
            {{ product.name }}
            {% if product.featured %}
                <span class="badge-featured">Featured</span>
            {% endif %}
        </p>
        <p class="product-category">{{ product.category }}</p>
        <p class="product-price">
            ${{ product.price | number_format(2) }}
            {% if product.inStock %}
                <span class="badge-stock">In Stock</span>
            {% else %}
                <span class="badge-nostock">Out of Stock</span>
            {% endif %}
        </p>
    </div>
{% endmacro %}

{% macro categoryFilter(categories, active) %}
    <div class="filters">
        <a href="/catalog" class="filter-btn{{ active is not defined or active == '' ? ' active' : '' }}">All</a>
        {% for cat in categories %}
            <a href="/catalog?category={{ cat }}" class="filter-btn{{ active == cat ? ' active' : '' }}">{{ cat }}</a>
        {% endfor %}
    </div>
{% endmacro %}
```

Create `src/templates/catalog.twig`:

```html
{% extends "catalog-base.twig" %}

{% from "catalog-macros.twig" import productCard, categoryFilter %}

{% block title %}{{ active_category | default("All") }} Products - Catalog{% endblock %}

{% block content %}
    <div class="header">
        <h1>Product Catalog</h1>
        <p>{{ products | length }} product{{ products | length != 1 ? 's' : '' }}{% if active_category %} in {{ active_category }}{% endif %}</p>
    </div>

    <div class="container">
        {{ categoryFilter(categories, active_category) }}

        {% if products | length > 0 %}
            <div class="product-grid">
                {% for product in products %}
                    {{ productCard(product) }}
                {% endfor %}
            </div>
        {% else %}
            <div class="empty-state">
                <h2>No products found</h2>
                <p>Try a different category or <a href="/catalog">view all products</a>.</p>
            </div>
        {% endif %}
    </div>
{% endblock %}
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

### 1. `{% extends %}` Must Be the First Tag

**Problem:** Template inheritance does not work. The page renders without the base layout.

**Cause:** `{% extends "base.twig" %}` must be the first tag in the template. No exceptions.

**Fix:** Make `{% extends %}` the absolute first thing in the file.

### 2. Undefined Variables Show Nothing

**Problem:** `{{ username }}` renders as empty instead of showing an error.

**Cause:** Frond outputs nothing for undefined variables. By design.

**Fix:** Use the `default` filter: `{{ username | default("Guest") }}`.

### 3. Auto-Escaping Prevents HTML Output

**Problem:** You pass HTML content but it appears as literal text.

**Cause:** Auto-escaping converts `<` to `&lt;` for security.

**Fix:** For trusted content, use `{{ content | raw }}`. Never use `raw` on user-supplied input.

### 4. Variable Scope in Includes

**Problem:** A variable defined inside a `{% for %}` loop is not accessible after the loop ends.

**Cause:** Loop variables are scoped to the loop.

**Fix:** Use `{% set %}` before the loop to accumulate values.

### 5. Macro Arguments Are Positional

**Problem:** Calling `{{ button("Click", style="danger") }}` does not work.

**Cause:** Frond macros use positional arguments, not keyword arguments.

**Fix:** Pass arguments in the order defined: `{{ button("Click", "/url", "danger") }}`.

### 6. Template File Extension Does Not Matter

**Problem:** Not sure whether to use `.html`, `.twig`, or `.tpl`.

**Cause:** Frond does not care about the file extension. It processes any file in `src/templates/`.

**Fix:** Pick one extension. Be consistent. This book uses `.twig` for templates with Twig syntax and `.html` for simple HTML files.

### 7. Filters Are Not JavaScript Functions

**Problem:** You try `{{ items | count }}` or `{{ name | toUpperCase }}` and get an error.

**Cause:** Frond filters follow Twig conventions, not JavaScript conventions.

**Fix:** Use `{{ items | length }}` instead of `count`. Use `{{ name | upper }}` instead of `toUpperCase`.
