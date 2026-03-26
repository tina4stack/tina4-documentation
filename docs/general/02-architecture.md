# Chapter 2: Architecture

## The Request Lifecycle

A request arrives. Seven stages later, a response leaves. Every Tina4 application follows this path -- Python, PHP, Ruby, Node.js. The language changes. The architecture does not.

```
Client sends HTTP request
        │
        ▼
  ┌───────────┐
  │  Server   │  Accept connection, parse HTTP
  └─────┬─────┘
        │
        ▼
  ┌───────────┐
  │  Request  │  Build Request object (body, params, headers, files, session)
  └─────┬─────┘
        │
        ▼
  ┌───────────┐
  │  Router   │  Match URL pattern to a registered handler
  └─────┬─────┘
        │
        ▼
  ┌───────────┐
  │Middleware  │  Run before-handler functions (auth, logging, rate limit)
  └─────┬─────┘
        │
        ▼
  ┌───────────┐
  │  Handler  │  Your code runs here
  └─────┬─────┘
        │
        ▼
  ┌───────────┐
  │ Response  │  Build response (JSON, HTML, redirect, file)
  └─────┬─────┘
        │
        ▼
  ┌───────────┐
  │ Pipeline  │  Minify HTML, compact JSON, compress (gzip), set ETag
  └─────┬─────┘
        │
        ▼
  Client receives HTTP response
```

Learn this diagram. Everything else in Tina4 is a footnote to it.

### 1. Server

The server accepts TCP connections and parses raw HTTP into structured data. Each language uses its native server:

| Language | Server |
|----------|--------|
| Python | asyncio / ASGI |
| PHP | Built-in server / Swoole |
| Ruby | WEBrick / Puma |
| Node.js | `node:http` |

You never touch this layer. Tina4 owns it. The server starts, listens, and hands off parsed requests. Your code lives further down the chain.

### 2. Request

The framework assembles a `Request` object. Everything the handler needs is already unpacked and waiting:

```
request.body        # Parsed JSON or form data
request.params      # Path parameters ({id} from /users/{id})
request.query       # Query string (?page=2&sort=name)
request.headers     # HTTP headers (case-insensitive)
request.files       # Uploaded files
request.session     # Session data (read/write)
request.method      # GET, POST, PUT, DELETE, etc.
request.path        # URL path without query string
request.ip          # Client IP address
request.request_id  # Unique ID for this request (for log correlation)
request.cookies     # Parsed cookies
request.is_json     # True if Content-Type contains "json"
```

No parsing. No extraction. No guessing where the data lives. One object. Twelve properties. Everything accounted for.

### 3. Router

The router listens. A request arrives. Method and path are matched against registered routes. Routes live in files under `src/routes/`:

```php
// PHP
Router::get("/api/products/{id:int}", function ($request, $response) {
    // Only matches if {id} is an integer
});
```

```python
# Python
@get("/api/products/{id:int}")
async def get_product(request, response):
    # Only matches if {id} is an integer
    pass
```

```ruby
# Ruby
get "/api/products/{id:int}" do |request, response|
  # Only matches if {id} is an integer
end
```

```typescript
// Node.js (file-based routing: src/routes/api/products/[id].ts)
export default function handler(request, response) {
    // id available via request.params.id
}
```

The router supports:

- **Basic parameters:** `/users/{id}` matches `/users/42`
- **Typed parameters:** `/users/{id:int}` only matches integers
- **Catch-all:** `/pages/{slug:.*}` matches `/pages/about/team/history`
- **Route groups:** Prefix multiple routes with a common path and middleware
- **Route caching:** Cache the response for a given TTL

No match on a registered route? The router checks `src/public/` for a static file. Still nothing? A 404 goes back to the client.

### 4. Middleware

Middleware functions form a pipeline. Each one inspects the request, decides whether to pass it forward, and optionally modifies what comes back. Think of it as a series of gates. A request must pass through every gate before it reaches your handler.

Tina4 ships four built-in middleware:

- **CORS** -- configured via environment variables, runs on every request
- **Rate limiting** -- 60 requests per minute per IP, out of the box
- **Auth gating** -- attach `.secure()` to a route to demand a valid JWT
- **Request ID tracking** -- generates or reads the `X-Request-ID` header

You write your own the same way:

```php
// PHP
function logRequests($request, $response, $next) {
    $start = microtime(true);
    $result = $next($request, $response);
    $duration = round((microtime(true) - $start) * 1000, 2);
    Log::info("Request completed", [
        "method" => $request->method,
        "path" => $request->path,
        "duration_ms" => $duration
    ]);
    return $result;
}

Router::get("/api/users", $handler)->middleware([logRequests]);
```

A middleware receives the request, calls `$next` to continue the chain, and returns the result. Skip the `$next` call and the request stops right there. Short-circuit. The handler never runs. This is how auth guards work -- no valid token, no entry.

### 5. Handler

This is your territory. The handler receives a `Request` and a `Response`. What happens in between is your decision. Tina4 does not impose an application architecture. No base controllers. No service containers. No required inheritance. You receive two objects. You return a response.

### 6. Response

The `Response` object covers every common output:

```
response.json(data, statusCode)       # JSON with auto Content-Type
response.html(content, statusCode)    # HTML response
response.text(content, statusCode)    # Plain text
response.xml(content, statusCode)     # XML response
response.redirect(url, statusCode)    # HTTP redirect (302 or 301)
response.file(path)                   # File download with auto MIME type
response.render(template, data)       # Render a Frond template
response.status(code)                 # Set status code (chainable)
response.header(name, value)          # Set response header (chainable)
response.cookie(name, value, options) # Set a cookie
```

Ten methods. JSON, HTML, text, XML, redirects, files, templates, status codes, headers, cookies. Pick the one that fits. Chain what needs chaining.

### 7. Response Pipeline

Your handler finishes. The response is not done yet. It passes through an automatic pipeline -- five stages that optimize every response without a single line of configuration:

1. **Frond rendering** -- if you called `response.render()`, the template compiles and executes
2. **HTML minification** -- in production (`TINA4_DEBUG=false`), whitespace collapses, comments vanish. 15-25% smaller output.
3. **JSON compaction** -- JSON ships compact. Add `?pretty=true` to the query string during development for readable output.
4. **gzip compression** -- the client sends `Accept-Encoding: gzip` and the response exceeds 1KB? Compressed.
5. **ETag generation** -- a hash of the response body becomes an `ETag` header. The next request with a matching `If-None-Match` gets a `304 Not Modified`. Zero bytes transferred.

Five optimizations. Zero configuration. Every response benefits.

---

## Project Structure

Every Tina4 project follows the same directory layout. Python, PHP, Ruby, Node.js -- the folders are identical. A developer who has seen one Tina4 project has seen them all.

```
my-project/
├── .env                    # All configuration lives here
├── src/
│   ├── routes/             # Route handlers (auto-discovered)
│   ├── orm/                # ORM models (auto-discovered)
│   ├── migrations/         # SQL migration files
│   ├── seeds/              # Database seed files
│   ├── templates/          # Frond templates
│   │   └── errors/         # Custom error pages
│   ├── public/             # Static files (served at /)
│   │   ├── js/
│   │   │   └── frond.js    # Auto-provided
│   │   ├── css/
│   │   ├── scss/           # SCSS source files (auto-compiled)
│   │   ├── images/
│   │   └── icons/
│   └── locales/            # Translation files (JSON)
│       └── en.json
├── data/                   # SQLite databases, .broken files
├── logs/                   # Log files with rotation
├── secrets/                # JWT keys
└── tests/                  # Test files
```

Fourteen directories. Each one has a single purpose. No overlap. No ambiguity.

### `src/routes/` -- Where Your API Lives

Drop a file here. Tina4 finds the route definitions inside it. Organize however you want:

```
src/routes/
├── products.php        # All product routes
├── orders.php          # All order routes
└── admin/
    ├── users.php       # Admin user routes
    └── reports.php     # Admin report routes
```

One file or twenty. Nested folders or flat. Tina4 reads them all. The file name does not affect the route path. Only the route definition inside the file matters. Name it `products.php` or `banana.php` -- the URL comes from the code, not the filename.

### `src/orm/` -- Where Your Models Live

ORM model classes go here. Auto-discovered on startup:

```
src/orm/
├── Product.php
├── Order.php
├── OrderItem.php
└── User.php
```

Drop a class that extends the ORM base. Tina4 registers it. Auto-CRUD endpoints, route model binding, relationship resolution -- all of it flows from discovery.

### `src/migrations/` -- Database Schema Changes

Migrations are SQL files with timestamps:

```
src/migrations/
├── 20260319100000_create_users_table.sql
├── 20260319100000_create_users_table.down.sql
├── 20260320090000_create_products_table.sql
└── 20260320090000_create_products_table.down.sql
```

The `.sql` file runs on `tina4 migrate`. The `.down.sql` file runs on `tina4 migrate:rollback`. Tina4 tracks which migrations have run in a `tina4_migrations` table. Forward and back. Always reversible.

### `src/seeds/` -- Test Data

Seed files populate your database with test or default data. Run them with `tina4 seed`. Fifty built-in fake data generators handle the rest -- names, emails, addresses, phone numbers, dates.

### `src/templates/` -- Frond Templates

Templates use the Frond engine. Inheritance, includes, filters, loops, conditionals -- all covered in detail later. The structure is yours to decide:

```
src/templates/
├── base.html           # Layout with blocks
├── index.html          # Extends base.html
├── products/
│   ├── list.html       # Product listing
│   └── detail.html     # Single product
├── partials/
│   ├── header.html
│   └── footer.html
└── errors/
    ├── 404.html         # Custom 404 page
    └── 500.html         # Custom 500 page
```

### `src/public/` -- Static Files

Files here are served at the root URL path. A file at `src/public/images/logo.png` appears at `/images/logo.png`. No route registration. No configuration. Drop it in. It serves.

The framework auto-provides `frond.js` in `src/public/js/` and keeps it in sync with the installed framework version. You never manage this file.

### `data/` -- Runtime Data

SQLite databases live here by default (`data/app.db`). The `.broken/` subdirectory holds error marker files used by the health check. This entire directory belongs in `.gitignore`. Runtime data stays on the machine that runs the application.

### `logs/` -- Log Files

Structured log files with automatic rotation. In `.gitignore`. Compressed after two days. Deleted after thirty. The framework handles all of it.

### `secrets/` -- JWT Keys

Private and public keys for RS256 JWT signing. In `.gitignore`. Generated once, deployed with your application, never committed to source control.

---

## .env Driven Configuration

One file controls everything. Not YAML. Not TOML. Not JSON config objects. A `.env` file at the project root. Key-value pairs. Plain text.

```env
# .env
TINA4_DEBUG=true
TINA4_PORT=7145
DATABASE_URL=sqlite:///data/app.db
JWT_SECRET=change-me-in-production
```

Four lines. A working application.

### The Priority Chain

Tina4 resolves every configuration value through a three-level chain:

```
Constructor argument  >  .env file  >  Hardcoded default
```

The constructor wins. Always. The `.env` file is second. The hardcoded default is the safety net. This pattern applies to every configurable value in the framework. No exceptions.

### Example: Priority Chain in Practice

```env
# .env
TINA4_PORT=8080
```

```php
// In code -- this overrides .env
$app = new Tina4\App(["port" => 9000]);
// Server starts on port 9000, not 8080
```

```php
// No code override, no .env value
$app = new Tina4\App();
// Server starts on port 7145 (the default)
```

Three levels. Predictable resolution. Every time.

### is_truthy() -- Boolean Environment Values

Environment variables are strings. Booleans do not exist in `.env` files. Tina4 bridges this gap with `is_truthy()`. Four values mean `true`:

- `true` (any case: `True`, `TRUE`, `tRuE`)
- `1`
- `yes` (any case)
- `on` (any case)

Everything else is `false`. Empty strings. Unset variables. Typos. If it is not on the list, it is `false`.

```env
TINA4_DEBUG=true
TINA4_DEBUG=True
TINA4_DEBUG=1
TINA4_DEBUG=yes
TINA4_DEBUG=on
```

All equivalent. All enable debug mode.

```env
TINA4_DEBUG=false
TINA4_DEBUG=0
TINA4_DEBUG=no
TINA4_DEBUG=off
TINA4_DEBUG=
# or simply omit the line
```

All disable it. No ambiguity.

---

## Dev Mode vs. Production Mode

One variable. Two personalities. `TINA4_DEBUG` controls everything.

### Dev Mode (`TINA4_DEBUG=true`)

The framework opens up. Every diagnostic tool activates:

- **Debug overlay** injects into every HTML response -- a toolbar showing request details, database queries, template render times, session data, and logs
- **Full stack traces** appear in the browser with source code context, the triggering request, and the queries that ran
- **Swagger UI** auto-registers at `/swagger`
- **Admin console** becomes available at `/__dev`
- **Live reload** watches for file changes and refreshes the browser
- **SQL query logging** writes every query to `logs/query.log`
- **Pretty JSON** is available via `?pretty=true` on any JSON endpoint
- **404 pages** show helpful route-not-found messages listing similar registered routes

Development mode assumes you want to see everything. It shows you everything.

### Production Mode (`TINA4_DEBUG=false`)

The framework locks down. Every diagnostic tool disappears:

- **No debug overlay** -- responses ship clean
- **Generic error pages** -- no stack traces, no source code, no query details reach the browser
- **HTML minification** -- comments stripped, whitespace collapsed, 15-25% smaller output
- **.broken files** -- unhandled exceptions create marker files in `data/.broken/` that flip the health check to `503 Service Unavailable`, triggering container restarts
- **No Swagger UI** -- unless you force it on
- **No dev dashboard** -- only available when `TINA4_DEBUG=true`
- **No query logging** -- unless you enable it
- **Compact JSON only** -- no `?pretty=true`

Production mode assumes you want to expose nothing. It exposes nothing.

The default is `TINA4_DEBUG=false`. Forget to set it? The safe thing happens. Your application starts locked down.

**One mistake will undo all of this:** deploying with `TINA4_DEBUG=true`. Stack traces, database queries, session data -- visible to anyone with a browser. Set `TINA4_DEBUG=false` in production. Always.

---

## The Frond Template Engine

Frond is Tina4's template engine. Zero dependencies. Built from scratch in each language. The syntax borrows from Twig -- developers who know Twig, Jinja2, or Nunjucks will recognize every construct. But no third-party template library runs underneath. Frond is Tina4's own.

### Basic Syntax

**Variables:**
```html
<h1>{{ title }}</h1>
<p>Welcome, {{ user.name }}</p>
<p>First item: {{ items[0] }}</p>
```

**Filters (pipe syntax):**
```html
<p>{{ name | upper }}</p>           <!-- JOHN DOE -->
<p>{{ name | lower }}</p>           <!-- john doe -->
<p>{{ price | number_format(2) }}</p> <!-- 29.99 -->
<p>{{ text | truncate(100) }}</p>    <!-- First 100 chars... -->
<p>{{ description | raw }}</p>       <!-- No auto-escaping -->
<p>{{ items | length }}</p>          <!-- 5 -->
<p>{{ items | join(", ") }}</p>      <!-- apple, banana, cherry -->
```

Fifty-five filters. Strings, numbers, dates, arrays, encoding, formatting. If you need to transform data in a template, a filter exists.

**Control structures:**
```html
{% if products | length > 0 %}
    {% for product in products %}
        <div class="product">
            <h2>{{ product.name }}</h2>
            <p>{{ product.price | number_format(2) }}</p>
            {% if loop.last %}
                <hr>
            {% endif %}
        </div>
    {% else %}
        <p>No products found.</p>
    {% endfor %}
{% endif %}
```

**Template inheritance:**
```html
{# base.html #}
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}My App{% endblock %}</title>
</head>
<body>
    {% block content %}{% endblock %}
</body>
</html>

{# products/list.html #}
{% extends "base.html" %}

{% block title %}Products{% endblock %}

{% block content %}
    <h1>Our Products</h1>
    {% for product in products %}
        <p>{{ product.name }} - ${{ product.price | number_format(2) }}</p>
    {% endfor %}
{% endblock %}
```

**Includes:**
```html
{% include "partials/header.html" %}
<main>
    {{ content }}
</main>
{% include "partials/footer.html" %}
```

**Fragment caching:**
```html
{% cache "product-list" 300 %}
    {# This block is cached for 300 seconds #}
    {% for product in products %}
        <div>{{ product.name }}</div>
    {% endfor %}
{% endcache %}
```

One fact matters above all others: the template syntax is identical across all four languages. A template written for a Python backend works on PHP, Ruby, and Node.js without a single change. The backend is invisible to the frontend. Frond guarantees that.

---

## How Auto-Discovery Works

Tina4 finds your code without being told where to look. No registration files. No import chains. No bootstrapping rituals. Drop files in the right directories. The framework discovers them.

### Routes

On startup, Tina4 scans every file in `src/routes/` -- recursively, through every subdirectory. It finds route registration calls: `get()`, `post()`, `put()`, `delete()`, `any()`. Each call registers a route with the router.

```
Startup
  │
  ├── Scan src/routes/
  │   ├── products.php → registers GET /api/products, POST /api/products, ...
  │   ├── orders.php → registers GET /api/orders, ...
  │   └── admin/users.php → registers GET /api/admin/users, ...
  │
  └── Router now has all routes in memory
```

The scan happens once at startup. In dev mode with live reload, the scan re-runs when files change. New route file saved? The router rebuilds. No restart needed.

**The file name and path within `src/routes/` do not determine the URL.** Only the route definition inside the file matters. Put all your routes in one file called `everything.php` and it works. Spread them across fifty files in nested folders and it works. The directory structure is for your organization. The framework ignores it.

### Models

ORM model classes in `src/orm/` follow the same pattern. The framework scans for classes that extend the ORM base class and registers them. This powers auto-CRUD -- REST endpoints generated from models. It powers route model binding -- URL parameters resolved to model instances. Discovery makes both possible without a single line of registration code.

### Templates

Templates work differently. They are not discovered at startup -- they are loaded on demand when `response.render()` is called. But the framework knows where to look without being told. Reference `"products/list.html"` and Tina4 resolves it to `src/templates/products/list.html`. No path configuration. No template registry.

### Static Files

When the router cannot match a request to a registered route, it falls back to the filesystem. The lookup follows a strict order:

```
1. Registered route?          → Run handler
2. File in src/public/?       → Serve static file
3. Framework built-in asset?  → Serve framework file
4. Nothing matches            → 404 response
```

Four steps. Tried in order. The first match wins. A file at `src/public/css/style.css` serves at `/css/style.css` with the correct MIME type. No route needed. No configuration needed. The file exists, so it serves.

---

## Summary

| Concept | How It Works in Tina4 |
|---------|----------------------|
| Request lifecycle | Request > Router > Middleware > Handler > Response > Pipeline |
| Project structure | Fixed conventions: routes, orm, templates, public, migrations |
| Configuration | `.env` only, priority: constructor > .env > default |
| Dev vs. production | Single toggle: `TINA4_DEBUG` |
| Template engine | Frond: Twig-like syntax, zero dependencies, identical across languages |
| Auto-discovery | Files in `src/routes/` and `src/orm/` are found at startup |
| Static files | Files in `src/public/` are served at `/` |
| Response pipeline | Minification > compression > ETag, all automatic |
