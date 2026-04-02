# Chapter 1: Getting Started with Tina4 Ruby

## 1. What Is Tina4 Ruby

Tina4 Ruby is a zero-dependency web framework for Ruby 3.1+. One gem. Under 5,000 lines of code. Routing, ORM, template engine, authentication, queues, WebSocket, and 70 other features -- all built in.

It belongs to the Tina4 family. Four identical frameworks. Python, PHP, Ruby, Node.js. Everything you learn here transfers to the other three languages. Same project structure. Same template syntax. Same CLI commands. Same `.env` variables.

Tina4 Ruby follows Ruby conventions. Method names use `snake_case` -- `fetch_one`, `soft_delete`, `has_many`. Class names use `PascalCase`. Constants use `UPPER_SNAKE_CASE`.

By the end of this chapter, you will have a running Tina4 Ruby project with an API endpoint and a rendered HTML page.

---

## 2. Prerequisites and Installation

### What You Need

Four things. Nothing more.

1. **Ruby 3.1 or later** -- check with:

```bash
ruby -v
```

You should see output like:

```
ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin23]
```

Below 3.1? Upgrade first.

2. **Bundler** -- Ruby's dependency manager:

```bash
bundle --version
```

```
Bundler version 2.5.6
```

Not installed? `gem install bundler`.

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

4. **SQLite3 development libraries** -- most systems ship these:

```bash
# macOS (already included)
# Ubuntu/Debian
sudo apt-get install libsqlite3-dev

# Fedora
sudo dnf install sqlite-devel
```

## Installing the Tina4 CLI

```bash
cargo install tina4
```

Or download from [GitHub Releases](https://github.com/tina4stack/tina4/releases).

The `tina4` CLI manages project scaffolding, development servers, migrations, and more across all Tina4 frameworks.

### Creating a New Project

One command:

```bash
tina4 init ruby my-store
```

`tina4 init` installs the Tina4 CLI globally (via cargo, homebrew, or direct download), then scaffolds a complete project with routes, templates, database, and configuration.

```
Creating Tina4 project in ./my-store ...
  Detected language: Ruby (Gemfile)
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
  Created .keys/
  Created tests/

Project created! Next steps:
  cd my-store
  bundle install
  tina4 serve
```

Install the Ruby dependencies:

```bash
cd my-store
bundle install
```

```
Fetching gem metadata from https://rubygems.org/...
Resolving dependencies...
Installing tina4 (3.2.1)
Bundle complete! 1 Gemfile dependency, 1 gem installed.
```

One gem. No dependency tree. No version conflicts. Just `tina4`.

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

  Tina4 Ruby v3.2.1
  Server running at http://0.0.0.0:7147
  Debug mode: ON
  Database: sqlite:///data/app.db
  Press Ctrl+C to stop
```

Open `http://localhost:7147`. The Tina4 welcome page appears.

Hit the health endpoint:

```bash
curl http://localhost:7147/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 12,
  "version": "3.2.1",
  "framework": "tina4-ruby"
}
```

Your project is alive.

---

## 3. Project Structure Walkthrough

Here is what `tina4 init` built:

```
my-store/
├── .env                    # Your configuration (gitignored)
├── .env.example            # Template for other developers
├── .gitignore              # Pre-configured
├── Gemfile                 # Gem dependencies
├── Gemfile.lock            # Locked dependency versions
├── app.rb                  # Application entry point
├── src/
│   ├── routes/             # Your route handlers go here
│   ├── orm/                # Your ORM model classes go here
│   ├── migrations/         # SQL migration files
│   ├── seeds/              # Database seed files
│   ├── templates/          # Frond/Twig templates
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
├── .keys/                  # JWT keys (gitignored)
└── tests/                  # Your test files
```

Five directories matter:

- **`src/routes/`** -- Every `.rb` file here is auto-loaded at startup. Drop your route definitions here. Subdirectories work too.
- **`src/orm/`** -- Every `.rb` file here is auto-loaded. ORM model classes live here.
- **`src/templates/`** -- Frond (Tina4's built-in template engine -- see [Chapter 4: Templates](04-templates.md)) looks here when you call `response.render("my-page.html", data)`.
- **`src/public/`** -- Files served directly. `src/public/images/logo.png` maps to `/images/logo.png`.
- **`data/`** -- The default SQLite database (`app.db`) lives here. Gitignored. Databases do not belong in version control.

---

## 4. Your First Route

Create `src/routes/greeting.rb`:

```ruby
Tina4::Router.get("/api/greeting/{name}") do |request, response|
  name = request.params["name"]
  response.json({
    message: "Hello, #{name}!",
    timestamp: Time.now.iso8601
  })
end
```

Save the file. The dev server picks up the change. If not, restart with `tina4 serve`.

### Test It

```
http://localhost:7147/api/greeting/Alice
```

```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-03-22T14:30:00+00:00"
}
```

Or curl:

```bash
curl http://localhost:7147/api/greeting/Alice
```

```json
{"message":"Hello, Alice!","timestamp":"2026-03-22T14:30:00+00:00"}
```

Force pretty output:

```bash
curl "http://localhost:7147/api/greeting/Alice?pretty=true"
```

```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-03-22T14:30:00+00:00"
}
```

### Understanding What Happened

1. You created a file in `src/routes/`. Tina4 discovered it at startup.
2. `Tina4::Router.get("/api/greeting/{name}")` registered a GET route with a path parameter `{name}`.
3. A request to `/api/greeting/Alice` matched the pattern. The router called your handler block.
4. `request.params["name"]` returned `"Alice"` from the URL.
5. `response.json(...)` serialized the hash to JSON, set `Content-Type: application/json`, and sent a `200 OK`.

### Adding More HTTP Methods

Add a POST endpoint. Update `src/routes/greeting.rb`:

```ruby
Tina4::Router.get("/api/greeting/{name}") do |request, response|
  name = request.params["name"]
  response.json({
    message: "Hello, #{name}!",
    timestamp: Time.now.iso8601
  })
end

Tina4::Router.post("/api/greeting") do |request, response|
  name = request.body["name"] || "World"
  language = request.body["language"] || "en"

  greetings = {
    "en" => "Hello",
    "es" => "Hola",
    "fr" => "Bonjour",
    "de" => "Hallo",
    "ja" => "Konnichiwa"
  }

  greeting = greetings[language] || greetings["en"]

  response.json({
    message: "#{greeting}, #{name}!",
    language: language
  }, 201)
end
```

Test:

```bash
curl -X POST http://localhost:7147/api/greeting \
  -H "Content-Type: application/json" \
  -d '{"name": "Carlos", "language": "es"}'
```

```json
{"message":"Hola, Carlos!","language":"es"}
```

Status code: `201 Created`.

---

## 5. Your First Template

Tina4 uses **Frond** -- a zero-dependency, Twig-compatible template engine built from scratch. If you know Twig, Jinja2, or Nunjucks, you know Frond.

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

Two blocks: `title` and `content`. Child templates override only what they need. `tina4.css` provides built-in styling. `frond.js` provides JS helpers. Both ship with every project.

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

Create `src/routes/pages.rb`:

```ruby
Tina4::Router.get("/products") do |request, response|
  products = [
    {
      name: "Wireless Keyboard",
      description: "Ergonomic wireless keyboard with backlit keys.",
      price: 79.99,
      in_stock: true
    },
    {
      name: "USB-C Hub",
      description: "7-port USB-C hub with HDMI, SD card reader, and Ethernet.",
      price: 49.99,
      in_stock: true
    },
    {
      name: "Monitor Stand",
      description: "Adjustable aluminum monitor stand with cable management.",
      price: 129.99,
      in_stock: false
    },
    {
      name: "Mechanical Mouse",
      description: "High-precision wireless mouse with 16,000 DPI sensor.",
      price: 59.99,
      in_stock: true
    }
  ]

  response.render("products.html", { products: products })
end
```

### See It in the Browser

Open `http://localhost:7147/products`. You see:

- A dark nav bar with "Home" and "Products"
- The heading "Our Products"
- "Showing 4 products"
- Four product cards with name, description, price, and stock badge
- "Monitor Stand" wears a red "Out of Stock" badge
- The other three wear green "In Stock" badges

### How Template Rendering Works

1. `response.render("products.html", { products: products })` tells Frond to render `src/templates/products.html`.
2. Frond sees `{% extends "base.html" %}` and loads the base template.
3. `{% block content %}` in `products.html` replaces the same block in `base.html`.
4. `{{ product.name }}` outputs the value, auto-escaped for HTML safety.
5. `{{ product.price | number_format(2) }}` formats the number with 2 decimal places.
6. `{% for product in products %}` loops through the array.
7. `{% if product.in_stock %}` renders the right badge.
8. `{{ products | length }}` returns the item count.

### About tina4css

`tina4.css` is Tina4's built-in CSS utility framework. Layout utilities, typography, common UI patterns. No Bootstrap. No Tailwind. No npm. It ships with every scaffolded project.

---

## 6. Understanding .env

Open `.env` at the project root:

```env
TINA4_DEBUG=true
```

That is it. The scaffold creates a minimal `.env`. Everything else uses defaults.

The defaults that matter:

| Variable | Default Value | What It Means |
|----------|---------------|---------------|
| `TINA4_PORT` | `7147` | Server runs on port 7147 |
| `DATABASE_URL` | `sqlite:///data/app.db` | SQLite database in `data/` |
| `TINA4_LOG_LEVEL` | `ALL` | All log messages output |
| `CORS_ORIGINS` | `*` | All origins allowed (fine for dev) |
| `TINA4_RATE_LIMIT` | `100` | 100 requests per minute per IP |

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

Restart the server. It now runs on 8080.

**How port resolution works:** The Rust CLI (`tina4 serve`) determines the port using this priority order:

1. **CLI flag** (highest priority): `tina4 serve --port 8080`
2. **`.env` file**: `TINA4_PORT=8080`
3. **Environment variable**: `PORT=8080`
4. **Framework default** (Python: 7145, PHP: 7146, Ruby: 7147, Node.js: 7143)

The CLI reads your `.env` file and checks for `TINA4_PORT` (and falls back to `PORT`). The resolved port is passed to the Ruby server. All three methods work -- use whichever fits your workflow.

For the complete `.env` reference with all 68 variables, see [Book 0, Chapter 4: Environment Variables](../../book-0-understanding/chapters/04-environment-variables.md).

---

## 7. The Dev Dashboard

With `TINA4_DEBUG=true` in your `.env`, Tina4 provides a built-in development dashboard. No additional environment variables are needed.

Restart and navigate to:

```
http://localhost:7147/__dev
```

The dashboard shows:

- **System Overview** -- framework version, Ruby version, uptime, memory, database status
- **Request Inspector** -- recent HTTP requests with method, path, status, duration, and request ID. Click any request for full headers, body, queries, and template renders.
- **Error Log** -- unhandled exceptions with stack traces and occurrence counts
- **Queue Manager** -- pending, reserved, failed, dead-letter messages
- **WebSocket Monitor** -- active connections with metadata
- **Routes** -- all registered routes with methods, paths, and middleware

The dev dashboard is a debugging powerhouse. It shows you what your application does without print statements.

HTML pages also get a **debug overlay** -- a toolbar at the bottom showing:

- Request details (method, URL, duration)
- Database queries executed (with timing)
- Template renders (with timing)
- Session data
- Recent log entries

The overlay vanishes when `TINA4_DEBUG=false`. Production users never see it.

---

## 8. Manual Setup (No CLI)

The `tina4` CLI scaffolds everything for you. But if you start from an empty folder — just Ruby and Bundler — here is the minimum you need.

### Step 1: Create `Gemfile`

```ruby
source "https://rubygems.org"

gem "tina4-ruby", "~> 3.0"
```

Then install:

```bash
bundle install
```

### Step 2: Create `app.rb`

This is the entry point. Create a file called `app.rb` in your project root:

```ruby
require "tina4"
Tina4.initialize!(__dir__)
app = Tina4::RackApp.new
Tina4::WebServer.new(app, port: 7147).start
```

Four lines. `initialize!` sets up the project directory. `RackApp` builds the Rack application. `WebServer` starts it on the given port.

### Step 3: Create the Folder Structure

Tina4 expects this layout:

```
my-project/
├── app.rb
├── Gemfile
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

```env
TINA4_DEBUG=true
```

### Step 5: Run It

```bash
ruby app.rb
```

The server starts on `http://localhost:7147`. You should see the Tina4 welcome page. From here, add route files in `src/routes/` and templates in `src/templates/` — the same way as a CLI-scaffolded project.

---

## 9. Request & Response Fundamentals

Before jumping into the exercises, let's consolidate how route handlers work in Tina4 Ruby. Every handler receives two arguments: `request` (what the client sent) and `response` (what you send back). Here is the complete picture.

### Reading Query Parameters

Query parameters are the key-value pairs after the `?` in a URL. Access them through `request.params`:

```ruby
# URL: /api/search?q=laptop&page=2
request.params["q"]                  # "laptop"
request.params["page"]               # "2" (always a string)
request.params["sort"] || "name"     # "name" (default -- param was not sent)
```

### Reading URL Path Parameters

Route patterns like `/users/{id}` capture segments of the URL. Access them through `request.params`:

```ruby
Tina4::Router.get("/users/{id:int}/posts/{slug}") do |request, response|
  id = request.params["id"]      # 5 (int, because of :int)
  slug = request.params["slug"]  # "hello-world" (string)
  response.json({ user_id: id, slug: slug })
end
```

The `{id:int}` syntax tells Tina4 to convert the value to an integer. Without `:int`, it stays a string.

### Reading the Request Body

POST, PUT, and PATCH requests carry a body. Tina4 parses JSON bodies into a hash automatically (as long as the client sends `Content-Type: application/json`):

```ruby
Tina4::Router.post("/api/items") do |request, response|
  name = request.body["name"] || ""
  price = request.body["price"] || 0
  response.json({ received_name: name, received_price: price })
end
```

### Reading Headers

Headers are available as a hash with their original casing:

```ruby
content_type = request.headers["Content-Type"] || "not set"
auth_token = request.headers["Authorization"] || ""
custom = request.headers["X-Custom-Header"] || ""
```

### Sending JSON Responses

`response.json` converts a hash to JSON and sets the correct `Content-Type`. Pass a status code as the second argument:

```ruby
response.json({ id: 1, name: "Widget" })        # 200 OK (default)
response.json({ id: 1, name: "Widget" }, 201)    # 201 Created
response.json({ error: "Not found" }, 404)        # 404 Not Found
```

### Sending HTML / Template Responses

`response.render` renders a Frond template from `src/templates/` and passes data to it:

```ruby
response.render("products.html", { products: product_list, title: "Our Products" })
```

For raw HTML without a template file:

```ruby
response.html("<h1>Hello</h1><p>This works too.</p>")
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

Create `src/routes/books.rb`:

```ruby
# In-memory data store
books = [
  { id: 1, title: "Dune", author: "Frank Herbert", year: 1965 },
  { id: 2, title: "Neuromancer", author: "William Gibson", year: 1984 },
  { id: 3, title: "Snow Crash", author: "Neal Stephenson", year: 1992 }
]

Tina4::Router.get("/api/books") do |request, response|
  # List all books. Supports ?author= filter and ?sort=year.
  author = request.params["author"] || ""
  sort_by = request.params["sort"] || ""

  result = books

  # Filter by author if the query param is present
  unless author.empty?
    result = result.select { |b| b[:author].downcase.include?(author.downcase) }
  end

  # Sort by year if requested
  if sort_by == "year"
    result = result.sort_by { |b| b[:year] }
  end

  response.json({ books: result, count: result.length })
end

Tina4::Router.get("/api/books/{id:int}") do |request, response|
  # Get a single book by ID. Returns 404 if not found.
  id = request.params["id"]
  book = books.find { |b| b[:id] == id }

  if book.nil?
    return response.json({ error: "Book with id #{id} not found" }, 404)
  end

  response.json(book)
end

Tina4::Router.post("/api/books") do |request, response|
  # Create a new book from the JSON body. Returns 201 on success.
  title = request.body["title"] || ""
  author = request.body["author"] || ""
  year = request.body["year"] || 0

  if title.empty? || author.empty?
    return response.json({ error: "title and author are required" }, 400)
  end

  new_book = {
    id: books.map { |b| b[:id] }.max + 1,
    title: title,
    author: author,
    year: year
  }
  books << new_book

  response.json(new_book, 201)
end
```

Test it:

```bash
# List all books
curl http://localhost:7147/api/books

# Filter by author
curl "http://localhost:7147/api/books?author=gibson"

# Sort by year
curl "http://localhost:7147/api/books?sort=year"

# Get a single book
curl http://localhost:7147/api/books/2

# Get a book that does not exist (returns 404)
curl http://localhost:7147/api/books/99

# Create a new book
curl -X POST http://localhost:7147/api/books \
  -H "Content-Type: application/json" \
  -d '{"title": "Foundation", "author": "Isaac Asimov", "year": 1951}'
```

This example covers every building block the exercises use: reading query parameters, reading path parameters, reading the request body, returning JSON with different status codes, and handling missing data. Refer back to it as you work through the exercises below.

---

## 10. Exercise: Greeting API + Product List Template

Build two features from scratch. No peeking at the examples above.

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

**Test:**

```bash
curl "http://localhost:7147/api/greet?name=Sarah"
curl "http://localhost:7147/api/greet"
```

### Exercise Part B: Product List Page

Create a page at `GET /store` that:

1. Displays at least 5 products (hardcoded)
2. Each product has: name, category, price, and a boolean `featured` flag
3. Featured products get a visual highlight (different background, border, or badge)
4. The page shows total product count and featured count
5. Uses template inheritance -- a layout template and a page that extends it
6. Includes `tina4.css` and `frond.js`

**Product data for your route handler:**

```ruby
products = [
  { name: "Espresso Machine", category: "Kitchen", price: 299.99, featured: true },
  { name: "Yoga Mat", category: "Fitness", price: 29.99, featured: false },
  { name: "Standing Desk", category: "Office", price: 549.99, featured: true },
  { name: "Noise-Canceling Headphones", category: "Electronics", price: 199.99, featured: true },
  { name: "Water Bottle", category: "Fitness", price: 24.99, featured: false }
]
```

**Expected browser output:**

- A page titled "Our Store"
- "5 products, 3 featured"
- Product cards with name, category, price, and "Featured" badge on highlighted items
- Featured products wear a distinct visual style

---

## 11. Solutions

### Solution A: Greeting API

Create `src/routes/greet.rb`:

```ruby
Tina4::Router.get("/api/greet") do |request, response|
  name = request.params["name"] || "Stranger"
  hour = Time.now.hour

  time_of_day = if hour >= 5 && hour < 12
                  "morning"
                elsif hour >= 12 && hour < 17
                  "afternoon"
                elsif hour >= 17 && hour < 21
                  "evening"
                else
                  "night"
                end

  response.json({
    greeting: "Welcome, #{name}!",
    time_of_day: time_of_day
  })
end
```

**Test:**

```bash
curl "http://localhost:7147/api/greet?name=Sarah"
```

```json
{"greeting":"Welcome, Sarah!","time_of_day":"afternoon"}
```

```bash
curl "http://localhost:7147/api/greet"
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

Create `src/routes/store.rb`:

```ruby
Tina4::Router.get("/store") do |request, response|
  products = [
    { name: "Espresso Machine", category: "Kitchen", price: 299.99, featured: true },
    { name: "Yoga Mat", category: "Fitness", price: 29.99, featured: false },
    { name: "Standing Desk", category: "Office", price: 549.99, featured: true },
    { name: "Noise-Canceling Headphones", category: "Electronics", price: 199.99, featured: true },
    { name: "Water Bottle", category: "Fitness", price: 24.99, featured: false }
  ]

  featured_count = products.count { |p| p[:featured] }

  response.render("store.html", {
    products: products,
    featured_count: featured_count
  })
end
```

**Open `http://localhost:7147/store`.** You see:

- A dark header reading "Our Store"
- "5 products, 3 featured"
- Five product cards in a grid
- Three cards (Espresso Machine, Standing Desk, Noise-Canceling Headphones) wear a yellow border, light yellow background, and "Featured" badge
- Two cards (Yoga Mat, Water Bottle) wear a standard white background with gray border
- Each card shows name, category, and price formatted to 2 decimal places

---

## 12. Gotchas

### 1. File not auto-discovered

**Problem:** You created a route file but the URL returns nothing.

**Cause:** The file is not in `src/routes/`. It must live inside `src/routes/` (or a subdirectory), and must end with `.rb`.

**Fix:** Move the file to `src/routes/your-file.rb` and restart the server.

### 2. "Uninitialized constant" errors

**Problem:** `NameError: uninitialized constant Tina4::Router`.

**Cause:** The Tina4 gem is not loaded.

**Fix:** Confirm your `Gemfile` includes `gem "tina4"` and you ran `bundle install`. Route files in `src/routes/` auto-load -- no `require` statements needed.

### 3. JSON response shows HTML

**Problem:** Your JSON endpoint returns HTML.

**Cause:** You returned a string instead of calling `response.json`. Plain strings become HTML in Tina4.

**Fix:** Use `response.json(data)` for JSON endpoints. Not `puts data.to_json`.

### 4. Template not found

**Problem:** `Template "my-page.html" not found`.

**Cause:** The template file is not in `src/templates/`, or the filename has a typo.

**Fix:** Check that the file exists at `src/templates/my-page.html`. The name in `response.render` is relative to `src/templates/`.

### 5. Port already in use

**Problem:** `Error: Address already in use (port 7147)`.

**Cause:** Another process owns port 7147.

**Fix:** Stop the other process, or change the port:

```env
TINA4_PORT=8080
```

Or: `tina4 serve --port 8080`.

### 6. Changes not reflected

**Problem:** You edited a file but the browser shows the old version.

**Cause:** Live reload may not be active. Browser caching can serve stale versions.

**Fix:** Hard-refresh (`Ctrl+Shift+R` or `Cmd+Shift+R`). If that fails, restart with `Ctrl+C` and `tina4 serve`.

### 7. .env not loaded

**Problem:** Environment variables have no effect.

**Cause:** The `.env` file must sit at the project root (same directory as `Gemfile`).

**Fix:** Move `.env` to the project root.

### 8. Debug mode in production

**Problem:** Production shows stack traces and query details.

**Cause:** `TINA4_DEBUG=true` in production.

**Fix:** Set `TINA4_DEBUG=false`. This hides debug information, enables HTML minification, and activates `.broken` file health checks.
