# Chapter 1: Getting Started with Tina4 PHP

## 1. What Is Tina4 PHP

Tina4 PHP is a zero-dependency web framework for PHP 8.1+. One Composer package. Under 5,000 lines of code. Routing, an ORM, a template engine, authentication, queues, WebSocket, and 70 other features -- all included.

It belongs to the Tina4 family: four identical frameworks in Python, PHP, Ruby, and Node.js. Learn one, know all four. Same project structure. Same template syntax. Same CLI commands. Same `.env` variables.

Tina4 PHP follows PHP conventions. Method names are `camelCase` -- `fetchOne()`, `softDelete()`, `hasMany()`. Class names are `PascalCase`. Constants are `UPPER_SNAKE_CASE`.

By the end of this chapter you will have a working project with an API endpoint and a rendered HTML page.

---

## 2. Prerequisites and Installation

### What You Need

Four things. Nothing exotic.

1. **PHP 8.1 or later** -- check with:

```bash
php -v
```

You should see output like:

```
PHP 8.3.4 (cli) (built: Feb 13 2026 09:27:45) (NTS)
Copyright (c) The PHP Group
Zend Engine v4.3.4, Copyright (c) Zend Technologies
    with Zend OPcache v8.3.4, Copyright (c), by Zend Technologies
```

If you see a version lower than 8.1, upgrade PHP first.

2. **Composer** -- PHP's package manager. Check with:

```bash
composer --version
```

You should see:

```
Composer version 2.7.2 2024-03-11 17:12:18
```

If Composer is not installed, get it from [https://getcomposer.org](https://getcomposer.org).

3. **The Tina4 CLI** -- a Rust-based binary that manages all four Tina4 frameworks:

```bash
# macOS (Homebrew)
brew install tina4stack/tap/tina4

# Linux / macOS (install script)
curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/tina4stack/tina4/main/install.ps1 | iex
```

Verify:

```bash
tina4 --version
```

```
tina4 0.1.0
```

4. **Required PHP extensions** -- these ship with most PHP installations:

- `ext-json` (bundled since PHP 8.0)
- `ext-mbstring`
- `ext-openssl`
- `ext-sqlite3` (for the default SQLite database)
- `ext-fileinfo`

Check:

```bash
php -m | grep -E "json|mbstring|openssl|sqlite3|fileinfo"
```

```
fileinfo
json
mbstring
openssl
sqlite3
```

If any are missing, install them via your OS package manager (e.g., `apt install php8.3-mbstring` on Ubuntu).

### Creating a New Project

One command. The CLI scaffolds everything.

```bash
tina4 init php my-store
```

```
▶ Initialising php project at ./my-store
▶ Checking php runtime...
  ✔ php found
▶ Checking package manager...
  ✔ composer found
  ✔ Created directory ./my-store
▶ Scaffolding php project...
  ✔ Created directory structure
  ✔ Created .env
  ✔ Created index.php
  ✔ Created .gitignore
  ✔ Created composer.json
▶ Installing dependencies...
  ✔ Dependencies installed

✔ Project created at ./my-store

Next steps:
  cd ./my-store
  tina4 serve
```

Install the PHP dependencies:

```bash
cd my-store
composer install
```

```
Installing dependencies from lock file
  - Installing tina4/tina4-php (v3.2.2): Extracting archive
Generating autoload files
1 package installed
```

One package. No dependency tree. No version conflicts. Just `tina4/tina4-php`.

### Starting the Dev Server

```bash
tina4 serve
```

```
 _____ _             _  _
|_   _(_)_ __   __ _| || |
  | | | | '_ \ / _` | || |_
  | | | | | | | (_| |__   _|
  |_| |_|_| |_|\__,_|  |_|

  Tina4 PHP v3.2.2
  Server running at http://0.0.0.0:7146
  Debug mode: ON
  Press Ctrl+C to stop
```

Open your browser to `http://localhost:7146`. The Tina4 welcome page appears.

Hit the health check:

```bash
curl http://localhost:7146/health
```

```json
{
  "status": "ok",
  "uptime_seconds": 12,
  "version": "3.2.2",
  "framework": "tina4-php"
}
```

The server is running. Time to write code.

> **Note:** No database exists yet. The SQLite file (`data/app.db`) is created automatically the first time your code opens a database connection -- for example, when you configure `DATABASE_URL` in `.env` and run a query or migration. Until then, the `data/` directory remains empty.

---

## 3. Project Structure Walkthrough

Here is what `tina4 init` created:

```
my-store/
├── .env                    # Your configuration (gitignored)
├── .gitignore              # Pre-configured
├── index.php               # Application entry point
├── composer.json           # Composer package definition
├── vendor/                 # Composer packages (after composer install)
├── src/
│   ├── routes/             # Your route handlers go here
│   ├── orm/                # Your ORM model classes go here
│   ├── templates/          # Frond/Twig templates
│   ├── public/             # Static files (CSS, JS, images)
│   │   ├── js/
│   │   ├── css/
│   │   └── images/
│   └── scss/               # SCSS source files (compiled to CSS)
├── migrations/             # SQL migration files
├── data/                   # SQLite databases (gitignored)
└── logs/                   # Log files (gitignored)
```

> **Note:** The scaffold creates empty directories. Files like `tina4.css`, `frond.js`, and error templates become available at runtime through the `tina4/tina4-php` Composer package -- they are not copied into your project.

Five directories matter:

- **`src/routes/`** -- Every `.php` file here is auto-loaded at startup. Route definitions go here. Subdirectories are fine.
- **`src/orm/`** -- Every `.php` file here is auto-loaded. ORM model classes go here.
- **`src/templates/`** -- Frond (Tina4's built-in template engine -- see [Chapter 4: Templates](04-templates.md)) looks here when you call `$response->render("my-page.html", $data)`.
- **`src/public/`** -- Files served directly. `src/public/images/logo.png` becomes `/images/logo.png`.
- **`data/`** -- Where the SQLite database lives once created. Gitignored. The `data/` directory starts empty; the database file (e.g., `app.db`) is created automatically on the first database connection.

---

## 4. Your First Route

Create `src/routes/greeting.php`:

```php
<?php
use Tina4\Router;

Router::get("/api/greeting/{name}", function ($request, $response) {
    $name = $request->params["name"];
    return $response->json([
        "message" => "Hello, " . $name . "!",
        "timestamp" => date("c")
    ]);
});
```

Save the file. The dev server picks it up. No restart needed if live reload is active. Otherwise, restart with `tina4 serve`.

### Test It

```
http://localhost:7146/api/greeting/Alice
```

```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-03-22T14:30:00+00:00"
}
```

Or with curl:

```bash
curl http://localhost:7146/api/greeting/Alice
```

```json
{"message":"Hello, Alice!","timestamp":"2026-03-22T14:30:00+00:00"}
```

The browser pretty-prints. Curl shows compact JSON. Force pretty output with `?pretty=true`:

```bash
curl "http://localhost:7146/api/greeting/Alice?pretty=true"
```

```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-03-22T14:30:00+00:00"
}
```

### Understanding What Happened

Five things, in order:

1. You created a file in `src/routes/`. Tina4 discovered it at startup.
2. `Router::get("/api/greeting/{name}", ...)` registered a GET route with a path parameter `{name}`.
3. A request arrived at `/api/greeting/Alice`. The router matched the pattern. Your handler ran.
4. `$request->params["name"]` extracted `"Alice"` from the URL.
5. `$response->json(...)` serialized the array to JSON, set `Content-Type: application/json`, and returned `200 OK`.

No base controller. No service provider. No bootstrapping ritual.

### Adding More HTTP Methods

Update `src/routes/greeting.php`:

```php
<?php
use Tina4\Router;

Router::get("/api/greeting/{name}", function ($request, $response) {
    $name = $request->params["name"];
    return $response->json([
        "message" => "Hello, " . $name . "!",
        "timestamp" => date("c")
    ]);
});

Router::post("/api/greeting", function ($request, $response) {
    $name = $request->body["name"] ?? "World";
    $language = $request->body["language"] ?? "en";

    $greetings = [
        "en" => "Hello",
        "es" => "Hola",
        "fr" => "Bonjour",
        "de" => "Hallo",
        "ja" => "Konnichiwa"
    ];

    $greeting = $greetings[$language] ?? $greetings["en"];

    return $response->json([
        "message" => $greeting . ", " . $name . "!",
        "language" => $language
    ], 201);
});
```

Test the POST endpoint:

```bash
curl -X POST http://localhost:7146/api/greeting \
  -H "Content-Type: application/json" \
  -d '{"name": "Carlos", "language": "es"}'
```

```json
{"message":"Hola, Carlos!","language":"es"}
```

Status code: `201 Created`. The second argument to `$response->json()` sets it.

---

## 5. Your First Template

Tina4 uses **Frond** -- a zero-dependency, Twig-compatible template engine built from scratch. If you know Twig, Jinja2, or Nunjucks, this will feel familiar.

### Create a Base Layout

Create `src/templates/base.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}My Store{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.css">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 0; }
        .container { max-width: 960px; margin: 0 auto; padding: 20px; }
        .product-card { border: 1px solid #ddd; border-radius: 8px; padding: 16px; margin: 8px 0; }
        .product-card h3 { margin-top: 0; }
        .price { color: #2d8f2d; font-weight: bold; font-size: 1.2em; }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.8em; }
        .badge-success { background: #d4edda; color: #155724; }
        .badge-danger { background: #f8d7da; color: #721c24; }
        nav { background: #333; color: white; padding: 12px 20px; }
        nav a { color: white; text-decoration: none; margin-right: 16px; }
    </style>
</head>
<body>
    <nav>
        <a href="/">Home</a>
        <a href="/products">Products</a>
    </nav>
    <div class="container">
        {% block content %}{% endblock %}
    </div>
    <script src="/js/frond.js"></script>
</body>
</html>
```

Two blocks: `title` and `content`. Child templates override what they need. The rest stays.

### Create a Product Listing Page

Create `src/templates/products.html`:

```html
{% extends "base.html" %}

{% block title %}Products - My Store{% endblock %}

{% block content %}
    <h1>Our Products</h1>
    <p>Showing {{ products | length }} product{{ products | length != 1 ? "s" : "" }}</p>

    {% if products | length > 0 %}
        {% for product in products %}
            <div class="product-card">
                <h3>{{ product.name }}</h3>
                <p>{{ product.description }}</p>
                <p class="price">${{ product.price | number_format(2) }}</p>
                {% if product.in_stock %}
                    <span class="badge badge-success">In Stock</span>
                {% else %}
                    <span class="badge badge-danger">Out of Stock</span>
                {% endif %}
                {% if not loop.last %}
                    {# Don't add separator after the last item #}
                {% endif %}
            </div>
        {% endfor %}
    {% else %}
        <p>No products available at the moment.</p>
    {% endif %}
{% endblock %}
```

### Create the Route That Renders the Template

Create `src/routes/pages.php`:

```php
<?php
use Tina4\Router;

Router::get("/products", function ($request, $response) {
    $products = [
        [
            "name" => "Wireless Keyboard",
            "description" => "Ergonomic wireless keyboard with backlit keys.",
            "price" => 79.99,
            "in_stock" => true
        ],
        [
            "name" => "USB-C Hub",
            "description" => "7-port USB-C hub with HDMI, SD card reader, and Ethernet.",
            "price" => 49.99,
            "in_stock" => true
        ],
        [
            "name" => "Monitor Stand",
            "description" => "Adjustable aluminum monitor stand with cable management.",
            "price" => 129.99,
            "in_stock" => false
        ],
        [
            "name" => "Mechanical Mouse",
            "description" => "High-precision wireless mouse with 16,000 DPI sensor.",
            "price" => 59.99,
            "in_stock" => true
        ]
    ];

    return $response->render("products.html", ["products" => $products]);
});
```

### See It in the Browser

Open `http://localhost:7146/products`. You see:

- A dark navigation bar with "Home" and "Products" links
- The heading "Our Products"
- A subheading: "Showing 4 products"
- Four product cards. Name, description, price, stock badge.
- The Monitor Stand shows a red "Out of Stock" badge
- The other three show green "In Stock" badges

### How Template Rendering Works

The chain is short:

1. `$response->render("products.html", ["products" => $products])` tells Frond to render `src/templates/products.html`.
2. Frond sees `{% extends "base.html" %}` and loads the base template.
3. The `{% block content %}` in `products.html` replaces the same block in `base.html`.
4. `{{ product.name }}` outputs the value, auto-escaped for HTML safety.
5. `{{ product.price | number_format(2) }}` formats the number with 2 decimal places.
6. `{% for product in products %}` loops through the array.
7. `{% if product.in_stock %}` renders the correct badge.
8. `{{ products | length }}` returns the count.

### About tina4css

The `tina4.css` file is Tina4's built-in CSS utility framework. Layout utilities, typography, common UI patterns -- no Bootstrap or Tailwind required. It ships with every scaffolded project. Nothing to download.

---

## 6. Understanding .env

Open `.env` at the project root:

```env
TINA4_DEBUG=true
```

That is likely everything. The scaffold creates a minimal `.env` with debug mode enabled. Everything else uses sensible defaults.

The defaults that matter for development:

| Variable | Default Value | What It Does |
|----------|---------------|--------------|
| `TINA4_PORT` | `7146` | Server port |
| `DATABASE_URL` | `sqlite:///data/app.db` | SQLite database path (created on first connection) |
| `TINA4_LOG_LEVEL` | `ALL` | All log messages output |
| `CORS_ORIGINS` | `*` | All origins allowed |
| `TINA4_RATE_LIMIT` | `60` | 60 requests per minute per IP |

**Log levels** control how much output Tina4 produces:

| Level | Behaviour |
|-------|-----------|
| `ALL` / `DEBUG` | Full verbose output. DevReload active (live-reload, error overlay). |
| `INFO` | Standard logging. Startup messages, request summaries. |
| `WARNING` | Warnings and errors only. |
| `ERROR` | Errors only. Minimal output. |

Set `TINA4_LOG_LEVEL=DEBUG` during development for maximum visibility. Use `WARNING` or `ERROR` in production.

To change the port, use the CLI flag or `.env`:

```bash
tina4 serve --port 8080
```

Or add it to your `.env` file:

```env
TINA4_DEBUG=true
TINA4_PORT=8080
```

Restart the server. It runs on port 8080.

**How port resolution works:** The Rust CLI (`tina4 serve`) determines the port using this priority order:

1. **CLI flag** (highest priority): `tina4 serve --port 8080`
2. **`.env` file**: `TINA4_PORT=8080`
3. **Environment variable**: `PORT=8080`
4. **Framework default** (Python: 7145, PHP: 7146, Ruby: 7144, Node.js: 7143)

The CLI reads your `.env` file and checks for `TINA4_PORT` (and falls back to `PORT`). The resolved port is passed to the PHP server. All three methods work -- use whichever fits your workflow.

For the complete `.env` reference with all 68 variables, see [Book 0, Chapter 4: Environment Variables](../../book-0-understanding/chapters/04-environment-variables.md).

---

## 7. The Dev Dashboard

With `TINA4_DEBUG=true` in your `.env`, Tina4 provides a built-in development dashboard. No additional environment variables are needed.

Restart and navigate to:

```
http://localhost:7146/__dev
```

The dashboard opens. Six panels. Each one saves you from adding print statements:

- **System Overview** -- framework version, PHP version, uptime, memory usage, database status
- **Request Inspector** -- recent HTTP requests with method, path, status, duration, request ID. Click any request for full headers, body, database queries, and template renders.
- **Error Log** -- unhandled exceptions with stack traces and occurrence counts
- **Queue Manager** -- pending, reserved, failed, dead-letter messages
- **WebSocket Monitor** -- active WebSocket connections with metadata
- **Routes** -- all registered routes with methods, paths, and middleware

When you visit any HTML page (like `/products`), a **debug overlay** appears at the bottom:

- Request details (method, URL, duration)
- Database queries executed (with timing)
- Template renders (with timing)
- Session data
- Recent log entries

This overlay exists only when `TINA4_DEBUG=true`. Production never sees it.

---

## 8. Manual Setup (No CLI)

The `tina4` CLI creates the project for you. But if you start from an empty folder — just Composer and a text editor — here is the minimum you need.

### Step 1: Install the Package

```bash
composer require tina4stack/tina4php
```

### Step 2: Create `index.php`

This is the entry point. Create a file called `index.php` in your project root:

```php
<?php
require_once "./vendor/autoload.php";

$app = new \Tina4\App(basePath: __DIR__, development: true);
$app->start();

// Dispatch when running under PHP built-in server
if (php_sapi_name() === "cli-server") {
    $response = \Tina4\Router::dispatch(new \Tina4\Request(), new \Tina4\Response());
    http_response_code($response->getStatusCode());
    foreach ($response->getHeaders() as $name => $value) {
        header("$name: $value");
    }
    echo $response->getBody();
}
```

The `App` class boots the framework. The `cli-server` block handles routing when you run PHP's built-in web server.

### Step 3: Create the Folder Structure

Tina4 expects this layout:

```
my-project/
├── index.php
├── .env
├── vendor/
└── src/
    ├── routes/       # Route files go here
    ├── templates/    # Twig templates go here
    └── public/       # Static files (CSS, JS, images)
```

Create the directories:

```bash
mkdir -p src/routes src/templates src/public
```

### Step 4: Create `.env`

```env
TINA4_DEBUG=true
```

### Step 5: Run It

```bash
php -S localhost:7145 index.php
```

The server starts on `http://localhost:7145`. You should see the Tina4 welcome page. From here, add route files in `src/routes/` and templates in `src/templates/` — the same way as a CLI-scaffolded project.

---

## 9. Request & Response Fundamentals

Before jumping into the exercises, let's consolidate how route handlers work in Tina4 PHP. Every handler receives two arguments: `$request` (what the client sent) and `$response` (what you send back). Here is the complete picture.

### Reading Query Parameters

Query parameters are the key-value pairs after the `?` in a URL. Access them through `$request->params`:

```php
// URL: /api/search?q=laptop&page=2
$request->params["q"]      // "laptop"
$request->params["page"]   // "2" (always a string)
$request->params["sort"] ?? "name"  // "name" (default -- param was not sent)
```

### Reading URL Path Parameters

Route patterns like `/users/{id}` capture segments of the URL. Access them through `$request->params`:

```php
<?php
use Tina4\Router;

Router::get("/users/{id:int}/posts/{slug}", function ($request, $response) {
    $id = $request->params["id"];     // 5 (int, because of :int)
    $slug = $request->params["slug"]; // "hello-world" (string)
    return $response->json(["user_id" => $id, "slug" => $slug]);
});
```

The `{id:int}` syntax tells Tina4 to convert the value to an integer. Without `:int`, it stays a string.

### Reading the Request Body

POST, PUT, and PATCH requests carry a body. Tina4 parses JSON bodies into an associative array automatically (as long as the client sends `Content-Type: application/json`):

```php
Router::post("/api/items", function ($request, $response) {
    $name = $request->body["name"] ?? "";
    $price = $request->body["price"] ?? 0;
    return $response->json(["received_name" => $name, "received_price" => $price]);
});
```

### Reading Headers

Headers are available as an associative array with their original casing:

```php
$contentType = $request->headers["Content-Type"] ?? "not set";
$authToken = $request->headers["Authorization"] ?? "";
$custom = $request->headers["X-Custom-Header"] ?? "";
```

### Sending JSON Responses

`$response->json()` converts an array to JSON and sets the correct `Content-Type`. Pass a status code as the second argument:

```php
return $response->json(["id" => 1, "name" => "Widget"]);        // 200 OK (default)
return $response->json(["id" => 1, "name" => "Widget"], 201);   // 201 Created
return $response->json(["error" => "Not found"], 404);           // 404 Not Found
```

### Sending HTML / Template Responses

`$response->render()` renders a Frond template from `src/templates/` and passes data to it:

```php
return $response->render("products.html", ["products" => $productList, "title" => "Our Products"]);
```

For raw HTML without a template file:

```php
return $response->html("<h1>Hello</h1><p>This works too.</p>");
```

### Status Codes

The most common status codes you will use:

| Code | Meaning | When to Use |
|------|---------|-------------|
| `200` | OK | Successful GET (default) |
| `201` | Created | Successful POST that created something |
| `400` | Bad Request | Client sent invalid input |
| `404` | Not Found | Resource does not exist |
| `500` | Internal Server Error | Something broke on the server |

### Worked Example: A Complete Route File

Here is a full route file that ties everything together. It builds a small book lookup API with query parameters, path parameters, JSON responses, and proper status codes. Read through it before attempting the exercises -- it is your reference.

Create `src/routes/books.php`:

```php
<?php
use Tina4\Router;

// In-memory data store
$books = [
    ["id" => 1, "title" => "Dune", "author" => "Frank Herbert", "year" => 1965],
    ["id" => 2, "title" => "Neuromancer", "author" => "William Gibson", "year" => 1984],
    ["id" => 3, "title" => "Snow Crash", "author" => "Neal Stephenson", "year" => 1992]
];

Router::get("/api/books", function ($request, $response) use (&$books) {
    // List all books. Supports ?author= filter and ?sort=year.
    $author = $request->params["author"] ?? "";
    $sortBy = $request->params["sort"] ?? "";

    $result = $books;

    // Filter by author if the query param is present
    if ($author !== "") {
        $result = array_values(array_filter($result, function ($b) use ($author) {
            return stripos($b["author"], $author) !== false;
        }));
    }

    // Sort by year if requested
    if ($sortBy === "year") {
        usort($result, fn($a, $b) => $a["year"] <=> $b["year"]);
    }

    return $response->json(["books" => $result, "count" => count($result)]);
});

Router::get("/api/books/{id:int}", function ($request, $response) use (&$books) {
    // Get a single book by ID. Returns 404 if not found.
    $id = $request->params["id"];
    $book = null;

    foreach ($books as $b) {
        if ($b["id"] === $id) {
            $book = $b;
            break;
        }
    }

    if ($book === null) {
        return $response->json(["error" => "Book with id {$id} not found"], 404);
    }

    return $response->json($book);
});

Router::post("/api/books", function ($request, $response) use (&$books) {
    // Create a new book from the JSON body. Returns 201 on success.
    $title = $request->body["title"] ?? "";
    $author = $request->body["author"] ?? "";
    $year = $request->body["year"] ?? 0;

    if ($title === "" || $author === "") {
        return $response->json(["error" => "title and author are required"], 400);
    }

    $maxId = max(array_column($books, "id"));
    $newBook = [
        "id" => $maxId + 1,
        "title" => $title,
        "author" => $author,
        "year" => $year
    ];
    $books[] = $newBook;

    return $response->json($newBook, 201);
});
```

Test it:

```bash
# List all books
curl http://localhost:7146/api/books

# Filter by author
curl "http://localhost:7146/api/books?author=gibson"

# Sort by year
curl "http://localhost:7146/api/books?sort=year"

# Get a single book
curl http://localhost:7146/api/books/2

# Get a book that does not exist (returns 404)
curl http://localhost:7146/api/books/99

# Create a new book
curl -X POST http://localhost:7146/api/books \
  -H "Content-Type: application/json" \
  -d '{"title": "Foundation", "author": "Isaac Asimov", "year": 1951}'
```

This example covers every building block the exercises use: reading query parameters, reading path parameters, reading the request body, returning JSON with different status codes, and handling missing data. Refer back to it as you work through the exercises below.

---

## 10. Exercise: Greeting API + Product List Template

Build both features from scratch. No peeking at the examples above.

### Exercise Part A: Greeting API

Create an API endpoint at `GET /api/greet` that:

1. Accepts a query parameter `name` (e.g., `/api/greet?name=Sarah`)
2. Defaults to `"Stranger"` if `name` is missing
3. Returns JSON:

```json
{
  "greeting": "Welcome, Sarah!",
  "time_of_day": "afternoon"
}
```

4. Calculates `time_of_day` from the server's current hour:
   - 5:00 - 11:59 = "morning"
   - 12:00 - 16:59 = "afternoon"
   - 17:00 - 20:59 = "evening"
   - 21:00 - 4:59 = "night"

**Test your endpoint with:**

```bash
curl "http://localhost:7146/api/greet?name=Sarah"
curl "http://localhost:7146/api/greet"
```

### Exercise Part B: Product List Page

Create a page at `GET /store` that:

1. Displays at least 5 products (hardcoded)
2. Each product has: name, category, price, and a boolean `featured` flag
3. Featured products are visually distinct (different background, border, or badge)
4. The page shows total product count and featured count
5. Uses template inheritance -- a layout template and a page template that extends it
6. Includes `tina4.css` and `frond.js`

**Your products data:**

```php
$products = [
    ["name" => "Espresso Machine", "category" => "Kitchen", "price" => 299.99, "featured" => true],
    ["name" => "Yoga Mat", "category" => "Fitness", "price" => 29.99, "featured" => false],
    ["name" => "Standing Desk", "category" => "Office", "price" => 549.99, "featured" => true],
    ["name" => "Noise-Canceling Headphones", "category" => "Electronics", "price" => 199.99, "featured" => true],
    ["name" => "Water Bottle", "category" => "Fitness", "price" => 24.99, "featured" => false]
];
```

**Expected browser output:**

- Page titled "Our Store"
- Text: "5 products, 3 featured"
- Product cards with name, category, price, and a "Featured" badge on highlighted items
- Featured products have a distinct visual style

---

## 11. Solutions

### Solution A: Greeting API

Create `src/routes/greet.php`:

```php
<?php
use Tina4\Router;

Router::get("/api/greet", function ($request, $response) {
    $name = $request->params["name"] ?? "Stranger";
    $hour = (int) date("G");

    if ($hour >= 5 && $hour < 12) {
        $timeOfDay = "morning";
    } elseif ($hour >= 12 && $hour < 17) {
        $timeOfDay = "afternoon";
    } elseif ($hour >= 17 && $hour < 21) {
        $timeOfDay = "evening";
    } else {
        $timeOfDay = "night";
    }

    return $response->json([
        "greeting" => "Welcome, " . $name . "!",
        "time_of_day" => $timeOfDay
    ]);
});
```

**Test:**

```bash
curl "http://localhost:7146/api/greet?name=Sarah"
```

```json
{"greeting":"Welcome, Sarah!","time_of_day":"afternoon"}
```

```bash
curl "http://localhost:7146/api/greet"
```

```json
{"greeting":"Welcome, Stranger!","time_of_day":"afternoon"}
```

### Solution B: Product List Page

Create `src/templates/store-layout.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Store{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.css">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 0; background: #f5f5f5; }
        .container { max-width: 960px; margin: 0 auto; padding: 20px; }
        header { background: #1a1a2e; color: white; padding: 16px 20px; }
        header h1 { margin: 0; }
        .stats { color: #888; margin: 8px 0 20px; }
        .product-grid { display: grid; gap: 16px; }
        .product-card { background: white; border: 2px solid #e0e0e0; border-radius: 8px; padding: 16px; }
        .product-card.featured { border-color: #ffc107; background: #fffdf0; }
        .product-name { font-size: 1.2em; font-weight: bold; margin: 0 0 4px; }
        .product-category { color: #666; font-size: 0.9em; }
        .product-price { color: #2d8f2d; font-weight: bold; font-size: 1.1em; margin-top: 8px; }
        .featured-badge { background: #ffc107; color: #333; padding: 2px 8px; border-radius: 4px; font-size: 0.8em; font-weight: bold; }
    </style>
</head>
<body>
    <header>
        <h1>{% block header %}Store{% endblock %}</h1>
    </header>
    <div class="container">
        {% block content %}{% endblock %}
    </div>
    <script src="/js/frond.js"></script>
</body>
</html>
```

Create `src/templates/store.html`:

```html
{% extends "store-layout.html" %}

{% block title %}Our Store{% endblock %}
{% block header %}Our Store{% endblock %}

{% block content %}
    <p class="stats">{{ products | length }} products, {{ featured_count }} featured</p>

    <div class="product-grid">
        {% for product in products %}
            <div class="product-card{{ product.featured ? ' featured' : '' }}">
                <p class="product-name">
                    {{ product.name }}
                    {% if product.featured %}
                        <span class="featured-badge">Featured</span>
                    {% endif %}
                </p>
                <p class="product-category">{{ product.category }}</p>
                <p class="product-price">${{ product.price | number_format(2) }}</p>
            </div>
        {% endfor %}
    </div>
{% endblock %}
```

Create `src/routes/store.php`:

```php
<?php
use Tina4\Router;

Router::get("/store", function ($request, $response) {
    $products = [
        ["name" => "Espresso Machine", "category" => "Kitchen", "price" => 299.99, "featured" => true],
        ["name" => "Yoga Mat", "category" => "Fitness", "price" => 29.99, "featured" => false],
        ["name" => "Standing Desk", "category" => "Office", "price" => 549.99, "featured" => true],
        ["name" => "Noise-Canceling Headphones", "category" => "Electronics", "price" => 199.99, "featured" => true],
        ["name" => "Water Bottle", "category" => "Fitness", "price" => 24.99, "featured" => false]
    ];

    $featuredCount = count(array_filter($products, fn($p) => $p["featured"]));

    return $response->render("store.html", [
        "products" => $products,
        "featured_count" => $featuredCount
    ]);
});
```

**Open `http://localhost:7146/store`.** You see:

- A dark header reading "Our Store"
- Text: "5 products, 3 featured"
- Five product cards in a grid
- Three cards (Espresso Machine, Standing Desk, Noise-Canceling Headphones) have a yellow border, light yellow background, and a "Featured" badge
- Two cards (Yoga Mat, Water Bottle) have a white background with gray border
- Each card shows name, category, and price formatted to two decimal places

---

## 12. Gotchas

### 1. File not auto-discovered

**Problem:** You created a route file but the URL returns 404.

**Cause:** The file is not in `src/routes/`. It must be inside `src/routes/` (or a subdirectory), and the filename must end with `.php`.

**Fix:** Move the file to `src/routes/your-file.php`. Restart the server.

### 2. "Class not found" errors

**Problem:** `Class 'Tina4\Route' not found` or similar.

**Cause:** Missing `use` statement or stale autoload.

**Fix:** Start the file with `<?php` and include `use Tina4\Router;`. Run `composer dump-autoload` if the error persists.

### 3. JSON response shows HTML

**Problem:** Your JSON endpoint returns HTML.

**Cause:** You returned a string instead of using `$response->json()`. Plain strings are treated as HTML.

**Fix:** Use `$response->json($data)` for JSON endpoints. Never `echo json_encode($data)`.

### 4. Template not found

**Problem:** `Template "my-page.html" not found`.

**Cause:** The file is not in `src/templates/`, or the filename has a typo.

**Fix:** Check that the file exists at `src/templates/my-page.html`. The name in `$response->render()` is relative to `src/templates/`.

### 5. Port already in use

**Problem:** `Error: Address already in use (port 7146)`.

**Cause:** Another process occupies port 7146.

**Fix:** Stop the other process, or change the port:

```env
TINA4_PORT=8080
```

Or use the CLI flag: `tina4 serve --port 8080`.

### 6. Changes not reflected

**Problem:** You edited a file but the browser shows the old version.

**Cause:** Live reload may not be active. Browser caching can serve stale content.

**Fix:** Hard-refresh (`Ctrl+Shift+R` or `Cmd+Shift+R`). If that fails, restart the dev server.

### 7. .env not loaded

**Problem:** Environment variables have no effect.

**Cause:** The `.env` file must be at the project root (same directory as `composer.json`). A subdirectory will not work.

**Fix:** Move `.env` to the project root.

### 8. Debug mode in production

**Problem:** Your production site shows stack traces and query details.

**Cause:** `TINA4_DEBUG=true` in production.

**Fix:** Set `TINA4_DEBUG=false` in your production `.env`. This hides debug information, enables HTML minification, and activates `.broken` file health checks.
