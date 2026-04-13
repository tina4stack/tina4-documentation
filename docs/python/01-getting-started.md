# Chapter 1: Getting Started with Tina4 Python

## 1. What Is Tina4 Python

Tina4 Python is a zero-dependency web framework for Python 3.12+. One package. Routing, ORM, template engine, authentication, queues, WebSocket, and 70 other features -- all built in.

It belongs to the Tina4 family -- four identical frameworks in Python, PHP, Ruby, and Node.js. Everything you learn here transfers to the other three. Same project structure. Same template syntax. Same CLI commands. Same `.env` variables.

Tina4 Python follows Python convention: `snake_case` for methods and functions (`fetch_one()`, `soft_delete()`, `has_many()`), `PascalCase` for classes, `UPPER_SNAKE_CASE` for constants. Route handlers are `async def` functions decorated with `@get`, `@post`, and friends.

By the end of this chapter, you will have a running Tina4 Python project with an API endpoint and a rendered HTML page.

---

## 2. Prerequisites and Installation

### What You Need

Three tools. Nothing else.

1. **Python 3.12 or later** -- check with:

```bash
python3 --version
```

You should see output like:

```
Python 3.12.3
```

If you see a version lower than 3.12, upgrade Python first.

2. **uv** -- a fast Python package manager and project tool. Check with:

```bash
uv --version
```

You should see:

```
uv 0.6.9
```

If uv is not installed, get it from [https://docs.astral.sh/uv/](https://docs.astral.sh/uv/):

```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

3. **The Tina4 CLI** -- a Rust-based binary that manages all four Tina4 frameworks:

**macOS (Homebrew):**

```bash
brew install tina4stack/tap/tina4
```

**Linux / macOS (install script):**

```bash
curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/tina4stack/tina4/main/install.ps1 | iex
```

Verify the CLI is installed:

```bash
tina4 --version
```

```
tina4 0.1.0
```

## Installing the Tina4 CLI

```bash
cargo install tina4
```

Or download from [GitHub Releases](https://github.com/tina4stack/tina4/releases).

The `tina4` CLI manages project scaffolding, development servers, migrations, and more across all Tina4 frameworks.

### Creating a New Project

One command. One package. No dependency tree.

```bash
tina4 init python my-store
```

`tina4 init` installs the Tina4 CLI globally (via cargo, homebrew, or direct download), then scaffolds a complete project with routes, templates, database, and configuration.

You should see:

```
Creating Tina4 project in ./my-store ...
  Detected language: Python (pyproject.toml)
  Created .env
  Created .env.example
  Created .gitignore
  Created src/routes/
  Created src/orm/
  Created src/migrations/
  Created src/seeds/
  Created src/templates/
  Created src/templates/errors/
  Created src/public/
  Created src/public/js/
  Created src/public/css/
  Created src/public/scss/
  Created src/public/images/
  Created src/public/icons/
  Created src/locales/
  Created data/
  Created logs/
  Created secrets/
  Created tests/

Project created! Next steps:
  cd my-store
  uv sync
  tina4 serve
```

Install the Python dependencies:

```bash
cd my-store
uv sync
```

```
Resolved 1 package in 0.8s
Installed 1 package in 0.3s
 + tina4-python==3.1.0
```

One package. No dependency tree. No version conflicts. Just `tina4-python`.

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

  Tina4 Python v3.2.0
  Server running at http://0.0.0.0:7145
  Debug mode: ON
  Database: sqlite:///data/app.db
  Press Ctrl+C to stop
```

Open your browser to `http://localhost:7145`. The Tina4 welcome page greets you.

Open `http://localhost:7145/health` in your browser or curl it:

```bash
curl http://localhost:7145/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 12,
  "version": "3.2.0",
  "framework": "tina4-python"
}
```

Your Tina4 Python project is running.

---

## 3. Project Structure Walkthrough

Here is what `tina4 init` created:

```
my-store/
├── .env                    # Your configuration (gitignored)
├── .env.example            # Template for other developers
├── .gitignore              # Pre-configured
├── pyproject.toml          # Python project definition (uv / pip)
├── .venv/                  # Virtual environment (gitignored)
├── src/
│   ├── routes/             # Your route handlers go here
│   ├── orm/                # Your ORM model classes go here
│   ├── migrations/         # SQL migration files
│   ├── seeds/              # Database seed files
│   ├── templates/          # Frond templates
│   │   └── errors/         # Custom 404.html, 500.html
│   ├── public/             # Static files (CSS, JS, images)
│   │   ├── js/
│   │   │   └── frond.js    # Auto-provided JS helper library
│   │   ├── css/
│   │   │   └── tina4.css   # Built-in CSS utility framework
│   │   ├── scss/
│   │   ├── images/
│   │   └── icons/
│   └── locales/            # Translation files
│       └── en.json
├── data/                   # SQLite databases (gitignored)
├── logs/                   # Log files (gitignored)
├── secrets/                # JWT keys (gitignored)
└── tests/                  # Your test files
```

**Key directories:**

- **`src/routes/`** -- Every `.py` file here is auto-loaded at startup. Drop your route definitions here. Organize into subdirectories if you want.
- **`src/orm/`** -- Every `.py` file here is auto-loaded. Drop your ORM model classes here.
- **`src/templates/`** -- Frond (Tina4's built-in template engine -- see [Chapter 4: Templates](04-templates.md)) looks here when you call `response.render("my-page.html", data)`.
- **`src/public/`** -- Files served directly. `src/public/images/logo.png` lives at `/images/logo.png`.
- **`data/`** -- The default SQLite database (`app.db`) lives here. Gitignored because databases do not belong in version control.

---

## 4. Your First Route

Create the file `src/routes/greeting.py`:

```python
from tina4_python.core.router import get

@get("/api/greeting/{name}")
async def greeting(name, request, response):
    from datetime import datetime
    return response.json({
        "message": f"Hello, {name}!",
        "timestamp": datetime.now().isoformat()
    })
```

In Python, path parameters are passed directly as function arguments -- not via `request.params`. The parameter name in the function signature must match the `{name}` in the route pattern.

Save the file. The dev server picks up the change through live reload. If not, restart with `tina4 serve`.

### Test It

Open your browser to:

```
http://localhost:7145/api/greeting/Alice
```

You should see:

```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-03-22T14:30:00.000000"
}
```

Or use curl:

```bash
curl http://localhost:7145/api/greeting/Alice
```

```json
{"message":"Hello, Alice!","timestamp":"2026-03-22T14:30:00.000000"}
```

The browser shows pretty-printed JSON (browser extensions or dev mode). Curl shows compact JSON. Force pretty output with `?pretty=true`:

```bash
curl "http://localhost:7145/api/greeting/Alice?pretty=true"
```

```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-03-22T14:30:00.000000"
}
```

### Understanding What Happened

Five steps. No magic.

1. You created a file in `src/routes/`. Tina4 auto-discovered it at startup.
2. `@get("/api/greeting/{name}")` registered a GET route with a path parameter `{name}`.
3. When you requested `/api/greeting/Alice`, the router matched the pattern and called your handler.
4. The router extracted `"Alice"` from the URL and passed it as the `name` argument to your function.
5. `response.json(...)` serialized the dictionary to JSON, set `Content-Type: application/json`, and returned a `200 OK`.

### Adding More HTTP Methods

Update `src/routes/greeting.py`:

```python
from tina4_python.core.router import get, post

@get("/api/greeting/{name}")
async def greeting(name, request, response):
    from datetime import datetime
    return response.json({
        "message": f"Hello, {name}!",
        "timestamp": datetime.now().isoformat()
    })

@post("/api/greeting")
async def create_greeting(request, response):
    name = request.body.get("name", "World")
    language = request.body.get("language", "en")

    greetings = {
        "en": "Hello",
        "es": "Hola",
        "fr": "Bonjour",
        "de": "Hallo",
        "ja": "Konnichiwa"
    }

    greeting_word = greetings.get(language, greetings["en"])

    return response.json({
        "message": f"{greeting_word}, {name}!",
        "language": language
    }, 201)
```

Test the POST endpoint:

```bash
curl -X POST http://localhost:7145/api/greeting \
  -H "Content-Type: application/json" \
  -d '{"name": "Carlos", "language": "es"}'
```

```json
{"message":"Hola, Carlos!","language":"es"}
```

The HTTP status code is `201 Created` (the second argument to `response.json()`).

---

## 5. Your First Template

Tina4 uses the **Frond** template engine -- a zero-dependency, Twig-compatible engine built from scratch. If you have used Twig, Jinja2, or Nunjucks, Frond will feel familiar.

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

This base layout defines two blocks (`title` and `content`) that child templates override. It includes `tina4.css` (the built-in CSS framework) and `frond.js` (the built-in JS helper library).

### Create a Product Listing Page

Create `src/templates/products.html`:

```html
{% extends "base.html" %}

{% block title %}Products - My Store{% endblock %}

{% block content %}
    <h1>Our Products</h1>
    <p>Showing {{ products | length }} product{{ "s" if products|length != 1 else "" }}</p>

    {% if products %}
        {% for product in products %}
            <div class="product-card">
                <h3>{{ product.name }}</h3>
                <p>{{ product.description }}</p>
                <p class="price">${{ "%.2f"|format(product.price) }}</p>
                {% if product.in_stock %}
                    <span class="badge badge-success">In Stock</span>
                {% else %}
                    <span class="badge badge-danger">Out of Stock</span>
                {% endif %}
            </div>
        {% endfor %}
    {% else %}
        <p>No products available at the moment.</p>
    {% endif %}
{% endblock %}
```

### Create the Route That Renders the Template

Create `src/routes/pages.py`:

```python
from tina4_python.core.router import get

@get("/products")
async def products_page(request, response):
    products = [
        {
            "name": "Wireless Keyboard",
            "description": "Ergonomic wireless keyboard with backlit keys.",
            "price": 79.99,
            "in_stock": True
        },
        {
            "name": "USB-C Hub",
            "description": "7-port USB-C hub with HDMI, SD card reader, and Ethernet.",
            "price": 49.99,
            "in_stock": True
        },
        {
            "name": "Monitor Stand",
            "description": "Adjustable aluminum monitor stand with cable management.",
            "price": 129.99,
            "in_stock": False
        },
        {
            "name": "Mechanical Mouse",
            "description": "High-precision wireless mouse with 16,000 DPI sensor.",
            "price": 59.99,
            "in_stock": True
        }
    ]

    return response.render("products.html", {"products": products})
```

### See It in the Browser

Open `http://localhost:7145/products`. You should see:

- A dark navigation bar with "Home" and "Products" links
- The heading "Our Products"
- A subheading showing "Showing 4 products"
- Four product cards, each with name, description, price, and stock badge
- The "Monitor Stand" card shows a red "Out of Stock" badge
- The other three show green "In Stock" badges

### How Template Rendering Works

Eight steps. All automatic.

1. `response.render("products.html", {"products": products})` tells Frond to render `src/templates/products.html` with the given data.
2. Frond sees `{% extends "base.html" %}` and loads the base template.
3. The `{% block content %}` in `products.html` replaces the same block in `base.html`.
4. `{{ product.name }}` outputs the value, auto-escaped for HTML safety.
5. `{{ "%.2f"|format(product.price) }}` formats the number with 2 decimal places.
6. `{% for product in products %}` loops through the list.
7. `{% if product.in_stock %}` renders the stock badge conditionally.
8. `{{ products | length }}` returns the item count.

### About tina4css

The `tina4.css` file is Tina4's built-in CSS utility framework. Layout utilities. Typography. Common UI patterns. No Bootstrap. No Tailwind. No download. It ships with every scaffolded project.

---

## 6. Understanding .env

Open the `.env` file at the root of your project:

```bash
TINA4_DEBUG=true
```

That is likely all you see. The scaffold creates a minimal `.env` with debug mode enabled. Everything else uses defaults.

The important defaults for development:

| Variable | Default Value | What It Means |
|----------|---------------|---------------|
| `TINA4_PORT` | `7145` | Default server port (override with `tina4 serve --port`) |
| `DATABASE_URL` | `sqlite:///data/app.db` | SQLite database in the `data/` directory |
| `TINA4_LOG_LEVEL` | `ALL` | All log messages are output |
| `CORS_ORIGINS` | `*` | All origins allowed (fine for development) |
| `TINA4_RATE_LIMIT` | `60` | 60 requests per minute per IP |

**Log levels** control how much output Tina4 produces:

| Level | Behaviour |
|-------|-----------|
| `ALL` / `DEBUG` | Full verbose output. DevReload active (live-reload, error overlay, hot-patching). |
| `INFO` | Standard logging. Startup messages, request summaries. |
| `WARNING` | Warnings and errors only. |
| `ERROR` | Errors only. Minimal output. |

Set `TINA4_LOG_LEVEL=DEBUG` during development for maximum visibility. Use `WARNING` or `ERROR` in production.

To change the port, use the CLI flag or `.env`:

```bash
tina4 serve --port 8080
```

Or add it to your `.env` file:

```bash
TINA4_DEBUG=true
TINA4_PORT=8080
```

Restart the server. It now runs on port 8080.

**How port resolution works:** The Rust CLI (`tina4 serve`) determines the port using this priority order:

1. **CLI flag** (highest priority): `tina4 serve --port 8080`
2. **`.env` file**: `TINA4_PORT=8080`
3. **Environment variable**: `PORT=8080`
4. **Framework default** (Python: 7145, PHP: 7146, Ruby: 7144, Node.js: 7143)

The CLI reads your `.env` file and checks for `TINA4_PORT` (and falls back to `PORT`). The resolved port is passed to the Python server. All three methods work -- use whichever fits your workflow.

For the complete `.env` reference with all 68 variables, see [Book 0, Chapter 4: Environment Variables](../../book-0-understanding/chapters/04-environment-variables.md).

---

## 7. The Dev Dashboard

With `TINA4_DEBUG=true` in your `.env`, Tina4 provides a built-in development dashboard. No additional environment variables are needed.

Restart the server and navigate to:

```
http://localhost:7145/__dev
```

The dashboard shows:

- **System Overview** -- framework version, Python version, uptime, memory usage, database status
- **Request Inspector** -- recent HTTP requests with method, path, status, duration, and request ID. Click any request to see full headers, body, database queries, and template renders.
- **Error Log** -- unhandled exceptions with stack traces and occurrence counts
- **Queue Manager** -- queue status (pending, reserved, failed, dead-letter messages)
- **WebSocket Monitor** -- active WebSocket connections with metadata
- **Routes** -- all registered routes with their methods, paths, and middleware

The dev dashboard shows you what your application is doing without adding print statements or log calls.

When you visit any HTML page (like `/products`), a **debug overlay** appears -- a toolbar at the bottom showing:

- Request details (method, URL, duration)
- Database queries executed (with timing)
- Template renders (with timing)
- Session data
- Recent log entries

This overlay is only visible when `TINA4_DEBUG=true`. Production never sees it.

---

## 8. Manual Setup (No CLI)

The `tina4` CLI scaffolds everything for you. But sometimes you create a project from scratch — an empty folder, a fresh virtual environment, no CLI installed yet. Here is the minimum you need.

### Step 1: Install the Package

```bash
pip install tina4-python
```

Or with `uv`:

```bash
uv add tina4-python
```

### Step 2: Create `app.py`

This is the entry point. Create a file called `app.py` in your project root:

```python
"""Tina4 Application."""
from tina4_python.core import run

if __name__ == "__main__":
    run()
```

That is the entire file. The `run()` function starts the web server, scans for routes, and loads templates.

### Step 3: Create the Folder Structure

Tina4 expects this layout:

```
my-project/
├── app.py
├── .env
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

```bash
TINA4_DEBUG=true
```

### Step 5: Run It

```bash
python app.py
```

The server starts on `http://localhost:7145`. You should see the Tina4 welcome page. From here, add route files in `src/routes/` and templates in `src/templates/` — the same way as a CLI-scaffolded project.

---

## 9. Request & Response Fundamentals

Before jumping into the exercises, let's consolidate how route handlers work in Tina4 Python. Every handler receives two objects: `request` (what the client sent) and `response` (what you send back). Here is the complete picture.

### Reading Query Parameters

Query parameters are the key-value pairs after the `?` in a URL. Access them through `request.params`:

```python
# URL: /api/search?q=laptop&page=2
request.params.get("q", "")       # "laptop"
request.params.get("page", "1")   # "2" (always a string)
request.params.get("sort", "name") # "name" (default -- param was not sent)
```

### Reading URL Path Parameters

Route patterns like `/users/{id}` capture segments of the URL. In Tina4 Python, path parameters arrive as function arguments:

```python
from tina4_python.core.router import get

@get("/users/{id:int}/posts/{slug}")
async def user_post(id, slug, request, response):
    # id = 5 (int, because of :int type hint)
    # slug = "hello-world" (string)
    return response.json({"user_id": id, "slug": slug})
```

The `{id:int}` syntax tells Tina4 to convert the value to an integer. Without `:int`, it stays a string.

### Reading the Request Body

POST, PUT, and PATCH requests carry a body. Tina4 parses JSON bodies into a dictionary automatically (as long as the client sends `Content-Type: application/json`):

```python
from tina4_python.core.router import post

@post("/api/items")
async def create_item(request, response):
    name = request.body.get("name", "")
    price = request.body.get("price", 0)
    return response.json({"received_name": name, "received_price": price})
```

### Reading Headers

Headers are available as a dictionary. Header names are case-insensitive:

```python
content_type = request.headers.get("Content-Type", "not set")
auth_token = request.headers.get("Authorization", "")
custom = request.headers.get("X-Custom-Header", "")
```

### Sending JSON Responses

`response.json()` converts a dictionary to JSON and sets the correct `Content-Type`. Pass a status code as the second argument:

```python
return response.json({"id": 1, "name": "Widget"})        # 200 OK (default)
return response.json({"id": 1, "name": "Widget"}, 201)    # 201 Created
return response.json({"error": "Not found"}, 404)          # 404 Not Found
```

### Sending HTML / Template Responses

`response.render()` renders a Frond template from `src/templates/` and passes data to it:

```python
return response.render("products.html", {"products": product_list, "title": "Our Products"})
```

For raw HTML without a template file:

```python
return response.html("<h1>Hello</h1><p>This works too.</p>")
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

Create `src/routes/books.py`:

```python
from tina4_python.core.router import get, post

# In-memory data store
books = [
    {"id": 1, "title": "Dune", "author": "Frank Herbert", "year": 1965},
    {"id": 2, "title": "Neuromancer", "author": "William Gibson", "year": 1984},
    {"id": 3, "title": "Snow Crash", "author": "Neal Stephenson", "year": 1992}
]


@get("/api/books")
async def list_books(request, response):
    """List all books. Supports ?author= filter and ?sort=year."""
    author = request.params.get("author", "")
    sort_by = request.params.get("sort", "")

    result = books

    # Filter by author if the query param is present
    if author:
        result = [b for b in result if author.lower() in b["author"].lower()]

    # Sort by year if requested
    if sort_by == "year":
        result = sorted(result, key=lambda b: b["year"])

    return response.json({"books": result, "count": len(result)})


@get("/api/books/{id:int}")
async def get_book(id, request, response):
    """Get a single book by ID. Returns 404 if not found."""
    book = next((b for b in books if b["id"] == id), None)

    if book is None:
        return response.json({"error": f"Book with id {id} not found"}, 404)

    return response.json(book)


@post("/api/books")
async def create_book(request, response):
    """Create a new book from the JSON body. Returns 201 on success."""
    title = request.body.get("title", "")
    author = request.body.get("author", "")
    year = request.body.get("year", 0)

    if not title or not author:
        return response.json({"error": "title and author are required"}, 400)

    new_book = {
        "id": max(b["id"] for b in books) + 1,
        "title": title,
        "author": author,
        "year": year
    }
    books.append(new_book)

    return response.json(new_book, 201)
```

Test it:

```bash
# List all books
curl http://localhost:7145/api/books

# Filter by author
curl "http://localhost:7145/api/books?author=gibson"

# Sort by year
curl "http://localhost:7145/api/books?sort=year"

# Get a single book
curl http://localhost:7145/api/books/2

# Get a book that does not exist (returns 404)
curl http://localhost:7145/api/books/99

# Create a new book
curl -X POST http://localhost:7145/api/books \
  -H "Content-Type: application/json" \
  -d '{"title": "Foundation", "author": "Isaac Asimov", "year": 1951}'
```

This example covers every building block the exercises use: reading query parameters, reading path parameters, reading the request body, returning JSON with different status codes, and handling missing data. Refer back to it as you work through the exercises below.

---

## 10. Exercise: Greeting API + Product List Template

Build the following two features from scratch, without looking at the examples above.

### Exercise Part A: Greeting API

Create an API endpoint at `GET /api/greet` that:

1. Accepts a query parameter `name` (e.g., `/api/greet?name=Sarah`)
2. If `name` is missing, defaults to `"Stranger"`
3. Returns JSON like:

```json
{
  "greeting": "Welcome, Sarah!",
  "time_of_day": "afternoon"
}
```

4. The `time_of_day` should be calculated from the server's current hour:
   - 5:00 - 11:59 = "morning"
   - 12:00 - 16:59 = "afternoon"
   - 17:00 - 20:59 = "evening"
   - 21:00 - 4:59 = "night"

**Test your endpoint with:**

```bash
curl "http://localhost:7145/api/greet?name=Sarah"
curl "http://localhost:7145/api/greet"
```

### Exercise Part B: Product List Page

Create a page at `GET /store` that:

1. Displays a list of at least 5 products (hardcoded for now)
2. Each product has: name, category, price, and a boolean `featured` flag
3. Featured products get a visual highlight (different background color, border, or badge)
4. The page shows the total number of products and the number of featured products
5. Uses template inheritance -- a layout template and a page template that extends it
6. Includes `tina4.css` and `frond.js`

**Your products data should look like this in your route handler:**

```python
products = [
    {"name": "Espresso Machine", "category": "Kitchen", "price": 299.99, "featured": True},
    {"name": "Yoga Mat", "category": "Fitness", "price": 29.99, "featured": False},
    {"name": "Standing Desk", "category": "Office", "price": 549.99, "featured": True},
    {"name": "Noise-Canceling Headphones", "category": "Electronics", "price": 199.99, "featured": True},
    {"name": "Water Bottle", "category": "Fitness", "price": 24.99, "featured": False}
]
```

**Expected browser output:**

- A page titled "Our Store"
- Text showing "5 products, 3 featured"
- A list of product cards with name, category, price, and a "Featured" badge on highlighted items
- Featured products have a distinct visual style (your choice -- different border color, background, star icon, etc.)

---

## 11. Solutions

### Solution A: Greeting API

Create `src/routes/greet.py`:

```python
from tina4_python.core.router import get

@get("/api/greet")
async def greet(request, response):
    name = request.params.get("name", "Stranger")

    from datetime import datetime
    hour = datetime.now().hour

    if 5 <= hour < 12:
        time_of_day = "morning"
    elif 12 <= hour < 17:
        time_of_day = "afternoon"
    elif 17 <= hour < 21:
        time_of_day = "evening"
    else:
        time_of_day = "night"

    return response.json({
        "greeting": f"Welcome, {name}!",
        "time_of_day": time_of_day
    })
```

**Test:**

```bash
curl "http://localhost:7145/api/greet?name=Sarah"
```

```json
{"greeting":"Welcome, Sarah!","time_of_day":"afternoon"}
```

```bash
curl "http://localhost:7145/api/greet"
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
            <div class="product-card{{ ' featured' if product.featured else '' }}">
                <p class="product-name">
                    {{ product.name }}
                    {% if product.featured %}
                        <span class="featured-badge">Featured</span>
                    {% endif %}
                </p>
                <p class="product-category">{{ product.category }}</p>
                <p class="product-price">${{ "%.2f"|format(product.price) }}</p>
            </div>
        {% endfor %}
    </div>
{% endblock %}
```

Create `src/routes/store.py`:

```python
from tina4_python.core.router import get

@get("/store")
async def store_page(request, response):
    products = [
        {"name": "Espresso Machine", "category": "Kitchen", "price": 299.99, "featured": True},
        {"name": "Yoga Mat", "category": "Fitness", "price": 29.99, "featured": False},
        {"name": "Standing Desk", "category": "Office", "price": 549.99, "featured": True},
        {"name": "Noise-Canceling Headphones", "category": "Electronics", "price": 199.99, "featured": True},
        {"name": "Water Bottle", "category": "Fitness", "price": 24.99, "featured": False}
    ]

    featured_count = sum(1 for p in products if p["featured"])

    return response.render("store.html", {
        "products": products,
        "featured_count": featured_count
    })
```

**Open `http://localhost:7145/store` in your browser.** You should see:

- A dark header reading "Our Store"
- Text showing "5 products, 3 featured"
- Five product cards in a grid
- Three cards (Espresso Machine, Standing Desk, Noise-Canceling Headphones) have a yellow border, light yellow background, and a "Featured" badge
- Two cards (Yoga Mat, Water Bottle) have a standard white background with gray border
- Each card shows the product name, category, and price formatted with two decimal places

---

## 12. Gotchas

### 1. File not auto-discovered

**Problem:** You created a route file but nothing happens when you visit the URL.

**Cause:** The file is not in `src/routes/`. It must be inside `src/routes/` (or a subdirectory), and the file must end with `.py`.

**Fix:** Move the file to `src/routes/your-file.py` and restart the server.

### 2. Missing import

**Problem:** `NameError: name 'get' is not defined` or similar.

**Cause:** You forgot to import the route decorator.

**Fix:** Start your route file with the correct import: `from tina4_python.core.router import get, post` (include whichever decorators you need).

### 3. Handler not async

**Problem:** Your route handler runs but returns an error about a coroutine object.

**Cause:** You defined the handler with `def` instead of `async def`. Tina4 Python expects all route handlers to be async.

**Fix:** Change `def greeting(request, response):` to `async def greeting(request, response):`. Every route handler must be `async def`.

### 4. Template not found

**Problem:** `Template "my-page.html" not found` error.

**Cause:** The template file is not in `src/templates/`, or there is a typo in the filename.

**Fix:** Check that the file exists at `src/templates/my-page.html`. The name in `response.render()` is relative to `src/templates/`.

### 5. Port already in use

**Problem:** `Error: Address already in use (port 7145)`

**Cause:** Another process (or another Tina4 instance) is using port 7145.

**Fix:** Stop the other process, or change the port with the CLI flag:

```bash
tina4 serve --port 8080
```

The CLI will also auto-increment the port if it detects the default port is in use.

### 6. Changes not reflected

**Problem:** You edited a file but the browser shows the old version.

**Cause:** Live reload may not be active. Browser caching can serve stale versions.

**Fix:** Hard-refresh the browser (`Ctrl+Shift+R` or `Cmd+Shift+R`). If that fails, restart the dev server with `Ctrl+C` and `tina4 serve`.

### 7. .env not loaded

**Problem:** Environment variables have no effect.

**Cause:** The `.env` file must be at the project root (same directory as `pyproject.toml`). A subdirectory placement hides it from Tina4.

**Fix:** Move `.env` to the project root.
