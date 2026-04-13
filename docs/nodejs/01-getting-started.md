# Chapter 1: Getting Started with Tina4 Node.js

## 1. What Is Tina4 Node.js

Tina4 Node.js is a zero-dependency web framework. One npm package. It hands you routing, an ORM, a template engine, authentication, queues, WebSocket, and 70 other features. Node.js 22+ and TypeScript.

Truly zero runtime dependencies means no native C++ addons, no `node-gyp`, no platform-specific binaries. SQLite support uses Node's built-in `node:sqlite` module (available in Node 22+), so even database access requires nothing beyond what ships with Node.js itself.

It belongs to the Tina4 family -- four identical frameworks in Python, PHP, Ruby, and Node.js. Learn one, know all four. Same project structure. Same template syntax. Same CLI commands. Same `.env` variables.

Tina4 Node.js uses `camelCase` for method names (`fetchOne()`, `softDelete()`, `hasMany()`). JavaScript convention. Class names are `PascalCase`. Constants are `UPPER_SNAKE_CASE`.

By the end of this chapter, you will have a working project with an API endpoint and a rendered HTML page.

---

## 2. Prerequisites and Installation

### What You Need

1. **Node.js 22 or later** -- check with:

```bash
node -v
```

You should see output like:

```
v22.0.0
```

Anything below 22 means you need to upgrade first. Node 22+ is required because Tina4 uses the built-in `node:sqlite` module for SQLite support, which is not available in earlier versions.

2. **npm** -- Node's package manager. Check with:

```bash
npm -v
```

You should see:

```
10.2.4
```

npm ships with Node.js. If Node.js is installed, npm is too.

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

Verify the CLI:

```bash
tina4 --version
```

```
tina4 0.1.0
```

4. **TypeScript and tsx** -- for running TypeScript directly:

```bash
npm install -g tsx
```

Verify:

```bash
tsx --version
```

## Installing the Tina4 CLI

```bash
cargo install tina4
```

Or download from [GitHub Releases](https://github.com/tina4stack/tina4/releases).

The `tina4` CLI manages project scaffolding, development servers, migrations, and more across all Tina4 frameworks.

### Creating a New Project

The Tina4 CLI scaffolds a new project in one command:

```bash
tina4 init nodejs my-store
```

`tina4 init` installs the Tina4 CLI globally (via cargo, homebrew, or direct download), then scaffolds a complete project with routes, templates, database, and configuration.

You should see:

```
Creating Tina4 project in ./my-store ...
  Detected language: Node.js (package.json)
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
  npm install
  tina4 serve
```

Install the Node.js dependencies:

```bash
cd my-store
npm install
```

```
added 1 package in 2s

1 package installed
```

One package. No dependency tree. No version conflicts. Just `tina4-nodejs`.

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

  Tina4 Node.js v3.10.3
  Server running at http://0.0.0.0:7148
  Debug mode: ON
  Database: sqlite:///data/app.db
  Press Ctrl+C to stop
```

Open your browser to `http://localhost:7148`. The Tina4 welcome page greets you.

Hit the health endpoint:

```bash
curl http://localhost:7148/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 12,
  "version": "3.10.3",
  "framework": "tina4-nodejs"
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
├── package.json            # npm package definition
├── package-lock.json       # Locked dependency versions
├── tsconfig.json           # TypeScript configuration
├── app.ts                  # Application entry point
├── node_modules/           # npm packages (gitignored)
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
├── secrets/                # JWT keys (gitignored)
└── tests/                  # Your test files
    └── run-all.ts          # Test runner
```

**Key directories:**

- **`src/routes/`** -- Every `.ts` file here is auto-loaded at startup. Drop your route definitions here. Organize into subdirectories if you want. Tina4 also supports file-based routing: a file at `src/routes/api/users/get.ts` maps to `GET /api/users` with zero configuration.
- **`src/orm/`** -- Every `.ts` file here is auto-loaded. ORM model classes live here.
- **`src/templates/`** -- Frond (Tina4's built-in template engine -- see [Chapter 4: Templates](04-templates.md)) looks here when you call `res.html()` with a template.
- **`src/public/`** -- Files served directly. `src/public/images/logo.png` becomes `/images/logo.png`.
- **`data/`** -- The default SQLite database (`app.db`) lives here. Gitignored because databases do not belong in version control.

---

## 4. Your First Route

Time to build an API endpoint that returns a JSON greeting.

### Explicit Route Registration

Create the file `src/routes/greeting.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/greeting/{name}", async (req, res) => {
    const name = req.params.name;
    return res.json({
        message: `Hello, ${name}!`,
        timestamp: new Date().toISOString()
    });
});
```

Save the file. The dev server picks up the change. If live reload is off, restart with `tina4 serve`.

### File-Based Routing Alternative

Create the file `src/routes/api/greeting/[name]/get.ts`:

```typescript
export default async (req, res) => {
    const name = req.params.name;
    return res.json({
        message: `Hello, ${name}!`,
        timestamp: new Date().toISOString()
    });
};
```

Both approaches produce identical results. File-based routing maps the file path to the URL. Dynamic segments go in brackets (`[name]`).

### Test It

Open your browser to:

```
http://localhost:7148/api/greeting/Alice
```

You should see:

```json
{
  "message": "Hello, Alice!",
  "timestamp": "2026-03-22T14:30:00.000Z"
}
```

Or use curl:

```bash
curl http://localhost:7148/api/greeting/Alice
```

```json
{"message":"Hello, Alice!","timestamp":"2026-03-22T14:30:00.000Z"}
```

### Understanding What Happened

1. You created a file in `src/routes/`. Tina4 discovered it at startup.
2. `Router.get("/api/greeting/{name}", ...)` registered a GET route with a path parameter `{name}`.
3. A request to `/api/greeting/Alice` hit the router. Pattern matched. Handler fired.
4. `req.params.name` delivered the value `"Alice"` from the URL.
5. `res.json(...)` serialized the object, set `Content-Type: application/json`, and returned `200 OK`.

### Adding More HTTP Methods

Add a POST endpoint. Update `src/routes/greeting.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/greeting/{name}", async (req, res) => {
    const name = req.params.name;
    return res.json({
        message: `Hello, ${name}!`,
        timestamp: new Date().toISOString()
    });
});

Router.post("/api/greeting", async (req, res) => {
    const name = req.body.name ?? "World";
    const language = req.body.language ?? "en";

    const greetings: Record<string, string> = {
        en: "Hello",
        es: "Hola",
        fr: "Bonjour",
        de: "Hallo",
        ja: "Konnichiwa"
    };

    const greeting = greetings[language] ?? greetings["en"];

    return res.status(201).json({
        message: `${greeting}, ${name}!`,
        language
    });
});
```

Test the POST endpoint:

```bash
curl -X POST http://localhost:7148/api/greeting \
  -H "Content-Type: application/json" \
  -d '{"name": "Carlos", "language": "es"}'
```

```json
{"message":"Hola, Carlos!","language":"es"}
```

The HTTP status code is `201 Created` (set by `res.status(201)`).

---

## 5. Your First Template

Tina4 ships with **Frond** -- a zero-dependency, Twig-compatible template engine built from scratch. If you have used Twig, Jinja2, or Nunjucks, Frond will feel familiar.

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
    <p>Showing {{ products | length }} product{{ products | length != 1 ? "s" : "" }}</p>

    {% if products | length > 0 %}
        {% for product in products %}
            <div class="product-card">
                <h3>{{ product.name }}</h3>
                <p>{{ product.description }}</p>
                <p class="price">${{ product.price | number_format(2) }}</p>
                {% if product.inStock %}
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

Create `src/routes/pages.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/products", async (req, res) => {
    const products = [
        {
            name: "Wireless Keyboard",
            description: "Ergonomic wireless keyboard with backlit keys.",
            price: 79.99,
            inStock: true
        },
        {
            name: "USB-C Hub",
            description: "7-port USB-C hub with HDMI, SD card reader, and Ethernet.",
            price: 49.99,
            inStock: true
        },
        {
            name: "Monitor Stand",
            description: "Adjustable aluminum monitor stand with cable management.",
            price: 129.99,
            inStock: false
        },
        {
            name: "Mechanical Mouse",
            description: "High-precision wireless mouse with 16,000 DPI sensor.",
            price: 59.99,
            inStock: true
        }
    ];

    return res.html("products.html", { products });
});
```

File-based routing works here too. Create `src/routes/products/get.ts`:

```typescript
export const template = "products.html";

export default async (req, res) => {
    return {
        products: [
            { name: "Wireless Keyboard", description: "Ergonomic wireless keyboard.", price: 79.99, inStock: true },
            // ... more products
        ]
    };
};
```

Export a `template` constant and Tina4 renders it with the data returned from the handler.

### See It in the Browser

Open `http://localhost:7148/products`. You should see:

- A dark navigation bar at the top with "Home" and "Products" links
- The heading "Our Products"
- A subheading showing "Showing 4 products"
- Four product cards, each with a name, description, price, and stock badge
- The "Monitor Stand" card wears a red "Out of Stock" badge
- The other three wear green "In Stock" badges

### How Template Rendering Works

1. `res.html("products.html", { products })` tells Frond to render `src/templates/products.html` with the given data.
2. Frond sees `{% extends "base.html" %}` and loads the base template.
3. The `{% block content %}` in `products.html` replaces the same block in `base.html`.
4. `{{ product.name }}` outputs the value, auto-escaped for HTML safety.
5. `{{ product.price | number_format(2) }}` formats the number with 2 decimal places.
6. `{% for product in products %}` loops through the array.
7. `{% if product.inStock %}` conditionally renders the stock badge.
8. `{{ products | length }}` returns the count of items in the array.

### About tina4css

The `tina4.css` file in the base template is Tina4's built-in CSS utility framework. Layout utilities, typography, and common UI patterns -- without Bootstrap or Tailwind. Auto-provided at scaffolding time. No separate download needed.

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
| `TINA4_PORT` | `7148` | Server runs on port 7148 |
| `DATABASE_URL` | `sqlite:///data/app.db` | SQLite database in the `data/` directory |
| `TINA4_LOG_LEVEL` | `ALL` | All log messages are output |
| `CORS_ORIGINS` | `*` | All origins allowed (fine for development) |
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

```bash
TINA4_DEBUG=true
TINA4_PORT=8080
```

Restart the server (`Ctrl+C`, then `tina4 serve`). It now runs on port 8080.

**How port resolution works:** The Rust CLI (`tina4 serve`) determines the port using this priority order:

1. **CLI flag** (highest priority): `tina4 serve --port 8080`
2. **`.env` file**: `TINA4_PORT=8080`
3. **Environment variable**: `PORT=8080`
4. **Framework default** (Python: 7145, PHP: 7146, Ruby: 7144, Node.js: 7143)

The CLI reads your `.env` file and checks for `TINA4_PORT` (and falls back to `PORT`). The resolved port is passed to the Node.js server. All three methods work -- use whichever fits your workflow.

For the complete `.env` reference with all 68 variables, see [Book 0, Chapter 4: Environment Variables](../../book-0-understanding/chapters/04-environment-variables.md).

---

## 7. The Dev Dashboard

With `TINA4_DEBUG=true` in your `.env`, Tina4 provides a built-in development dashboard. No additional environment variables are needed.

Restart the server and navigate to:

```
http://localhost:7148/__dev
```

The dashboard reveals:

- **System Overview** -- framework version, Node.js version, uptime, memory usage, database status
- **Request Inspector** -- recent HTTP requests with method, path, status, duration, and request ID. Click any request to see full headers, body, database queries, and template renders.
- **Error Log** -- unhandled exceptions with stack traces and occurrence counts
- **Queue Manager** -- queue status (pending, reserved, failed, dead-letter messages)
- **WebSocket Monitor** -- active WebSocket connections with metadata
- **Routes** -- all registered routes with their methods, paths, and middleware

The dev dashboard shows you what your application is doing without littering your code with `console.log` statements.

When you visit any HTML page (like `/products`), a **debug overlay** appears -- a toolbar at the bottom of the page showing:

- Request details (method, URL, duration)
- Database queries executed (with timing)
- Template renders (with timing)
- Session data
- Recent log entries

This overlay lives only in debug mode. Production never sees it.

---

## 8. The app.ts Entry Point

The `app.ts` file is the entry point:

```typescript
import { startServer } from "tina4-nodejs";

startServer();
```

That is the entire file. Tina4 discovers routes, models, and templates from the `src/` directory. You register nothing manually.

The standard way to start the server is with the CLI:

```bash
tina4 serve
```

```
 _____ _             _  _
|_   _(_)_ __   __ _| || |
  | | | | '_ \ / _` | || |_
  | | | | | | | (_| |__   _|
  |_| |_|_| |_|\__,_|  |_|

  Tina4 Node.js v3.10.3
  Server running at http://0.0.0.0:7148
```

The CLI adds live reload and other development features. For direct Node.js execution (advanced usage), see [Chapter 30: CLI](30-cli.md).

---

## 9. Manual Setup (No CLI)

The `tina4` CLI scaffolds everything for you. But if you start from an empty folder — just Node.js and npm — here is the minimum you need.

### Step 1: Initialize and Install

```bash
npm init -y
npm install tina4-nodejs typescript tsx
```

### Step 2: Create `app.ts`

This is the entry point. Create a file called `app.ts` in your project root:

```typescript
import { startServer } from "@tina4/core";

const port = parseInt(process.env.PORT || "7149", 10);
const host = process.env.HOST || "0.0.0.0";
startServer({ port, host });
```

Three lines of real code. `startServer` boots the framework, scans for routes, and starts listening.

### Step 3: Create `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "dist"
  },
  "include": ["src/**/*", "app.ts"]
}
```

### Step 4: Create the Folder Structure

Tina4 expects this layout:

```
my-project/
├── app.ts
├── tsconfig.json
├── package.json
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

### Step 5: Create `.env`

```bash
TINA4_DEBUG=true
```

### Step 6: Run It

```bash
npx tsx app.ts
```

The server starts on `http://localhost:7149`. You should see the Tina4 welcome page. From here, add route files in `src/routes/` and templates in `src/templates/` — the same way as a CLI-scaffolded project.

---

## 10. Request & Response Fundamentals

Before jumping into the exercises, let's consolidate how route handlers work in Tina4 Node.js. Every handler receives two arguments: `req` (what the client sent) and `res` (what you send back). Here is the complete picture.

### Reading Query Parameters

Query parameters are the key-value pairs after the `?` in a URL. Access them through `req.query`:

```typescript
// URL: /api/search?q=laptop&page=2
req.query.q          // "laptop"
req.query.page       // "2" (always a string)
req.query.sort ?? "name"  // "name" (default -- param was not sent)
```

### Reading URL Path Parameters

Route patterns like `/users/{id}` capture segments of the URL. Access them through `req.params`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/users/{id:int}/posts/{slug}", async (req, res) => {
    const id = req.params.id;      // 5 (number, because of :int)
    const slug = req.params.slug;  // "hello-world" (string)
    return res.json({ user_id: id, slug: slug });
});
```

The `{id:int}` syntax tells Tina4 to convert the value to a number. Without `:int`, it stays a string.

### Reading the Request Body

POST, PUT, and PATCH requests carry a body. Tina4 parses JSON bodies into an object automatically (as long as the client sends `Content-Type: application/json`):

```typescript
Router.post("/api/items", async (req, res) => {
    const name = req.body.name ?? "";
    const price = req.body.price ?? 0;
    return res.json({ received_name: name, received_price: price });
});
```

### Reading Headers

Headers are available as an object. In Node.js, header names are normalized to lowercase:

```typescript
const contentType = req.headers["content-type"] ?? "not set";
const authToken = req.headers["authorization"] ?? "";
const custom = req.headers["x-custom-header"] ?? "";
```

### Sending JSON Responses

`res.json()` converts an object to JSON and sets the correct `Content-Type`. Chain with `res.status()` for a custom status code:

```typescript
return res.json({ id: 1, name: "Widget" });               // 200 OK (default)
return res.status(201).json({ id: 1, name: "Widget" });    // 201 Created
return res.status(404).json({ error: "Not found" });        // 404 Not Found
```

### Sending HTML / Template Responses

`res.html()` renders a Frond template from `src/templates/` when given a filename and data:

```typescript
return res.html("products.html", { products: productList, title: "Our Products" });
```

For raw HTML without a template file:

```typescript
return res.html("<h1>Hello</h1><p>This works too.</p>");
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

Create `src/routes/books.ts`:

```typescript
import { Router } from "tina4-nodejs";

// In-memory data store
const books = [
    { id: 1, title: "Dune", author: "Frank Herbert", year: 1965 },
    { id: 2, title: "Neuromancer", author: "William Gibson", year: 1984 },
    { id: 3, title: "Snow Crash", author: "Neal Stephenson", year: 1992 }
];

Router.get("/api/books", async (req, res) => {
    // List all books. Supports ?author= filter and ?sort=year.
    const author = (req.query.author ?? "") as string;
    const sortBy = (req.query.sort ?? "") as string;

    let result = [...books];

    // Filter by author if the query param is present
    if (author) {
        result = result.filter(b =>
            b.author.toLowerCase().includes(author.toLowerCase())
        );
    }

    // Sort by year if requested
    if (sortBy === "year") {
        result.sort((a, b) => a.year - b.year);
    }

    return res.json({ books: result, count: result.length });
});

Router.get("/api/books/{id:int}", async (req, res) => {
    // Get a single book by ID. Returns 404 if not found.
    const id = req.params.id;
    const book = books.find(b => b.id === id);

    if (!book) {
        return res.status(404).json({ error: `Book with id ${id} not found` });
    }

    return res.json(book);
});

Router.post("/api/books", async (req, res) => {
    // Create a new book from the JSON body. Returns 201 on success.
    const title = req.body.title ?? "";
    const author = req.body.author ?? "";
    const year = req.body.year ?? 0;

    if (!title || !author) {
        return res.status(400).json({ error: "title and author are required" });
    }

    const newBook = {
        id: Math.max(...books.map(b => b.id)) + 1,
        title,
        author,
        year
    };
    books.push(newBook);

    return res.status(201).json(newBook);
});
```

Test it:

```bash
# List all books
curl http://localhost:7148/api/books

# Filter by author
curl "http://localhost:7148/api/books?author=gibson"

# Sort by year
curl "http://localhost:7148/api/books?sort=year"

# Get a single book
curl http://localhost:7148/api/books/2

# Get a book that does not exist (returns 404)
curl http://localhost:7148/api/books/99

# Create a new book
curl -X POST http://localhost:7148/api/books \
  -H "Content-Type: application/json" \
  -d '{"title": "Foundation", "author": "Isaac Asimov", "year": 1951}'
```

This example covers every building block the exercises use: reading query parameters, reading path parameters, reading the request body, returning JSON with different status codes, and handling missing data. Refer back to it as you work through the exercises below.

---

## 11. Exercise: Greeting API + Product List Template

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
curl "http://localhost:7148/api/greet?name=Sarah"
curl "http://localhost:7148/api/greet"
```

### Exercise Part B: Product List Page

Create a page at `GET /store` that:

1. Displays a list of at least 5 products (hardcoded for now)
2. Each product has: name, category, price, and a boolean `featured` flag
3. Featured products should be highlighted (different background color, border, or badge)
4. The page should show the total number of products and the number of featured products
5. Use template inheritance -- create a layout template and a page template that extends it
6. Include `tina4.css` and `frond.js`

**Your products data should look like this in your route handler:**

```typescript
const products = [
    { name: "Espresso Machine", category: "Kitchen", price: 299.99, featured: true },
    { name: "Yoga Mat", category: "Fitness", price: 29.99, featured: false },
    { name: "Standing Desk", category: "Office", price: 549.99, featured: true },
    { name: "Noise-Canceling Headphones", category: "Electronics", price: 199.99, featured: true },
    { name: "Water Bottle", category: "Fitness", price: 24.99, featured: false }
];
```

**Expected browser output:**

- A page titled "Our Store"
- Text showing "5 products, 3 featured"
- A list of product cards with name, category, price, and a "Featured" badge on the highlighted items
- Featured products have a distinct visual style (your choice -- different border color, background, star icon, etc.)

---

## 12. Solutions

### Solution A: Greeting API

Create `src/routes/greet.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/greet", async (req, res) => {
    const name = req.query.name ?? "Stranger";
    const hour = new Date().getHours();

    let timeOfDay: string;
    if (hour >= 5 && hour < 12) {
        timeOfDay = "morning";
    } else if (hour >= 12 && hour < 17) {
        timeOfDay = "afternoon";
    } else if (hour >= 17 && hour < 21) {
        timeOfDay = "evening";
    } else {
        timeOfDay = "night";
    }

    return res.json({
        greeting: `Welcome, ${name}!`,
        time_of_day: timeOfDay
    });
});
```

**Test:**

```bash
curl "http://localhost:7148/api/greet?name=Sarah"
```

```json
{"greeting":"Welcome, Sarah!","time_of_day":"afternoon"}
```

```bash
curl "http://localhost:7148/api/greet"
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

Create `src/routes/store.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/store", async (req, res) => {
    const products = [
        { name: "Espresso Machine", category: "Kitchen", price: 299.99, featured: true },
        { name: "Yoga Mat", category: "Fitness", price: 29.99, featured: false },
        { name: "Standing Desk", category: "Office", price: 549.99, featured: true },
        { name: "Noise-Canceling Headphones", category: "Electronics", price: 199.99, featured: true },
        { name: "Water Bottle", category: "Fitness", price: 24.99, featured: false }
    ];

    const featuredCount = products.filter(p => p.featured).length;

    return res.html("store.html", {
        products,
        featured_count: featuredCount
    });
});
```

**Open `http://localhost:7148/store` in your browser.** You should see:

- A dark header reading "Our Store"
- Text showing "5 products, 3 featured"
- Five product cards in a grid
- Three cards (Espresso Machine, Standing Desk, Noise-Canceling Headphones) have a yellow border, light yellow background, and a "Featured" badge
- Two cards (Yoga Mat, Water Bottle) have a standard white background with gray border
- Each card shows the product name, category, and price formatted with two decimal places

---

## 13. Gotchas

### 1. File not auto-discovered

**Problem:** You created a route file but nothing happens when you visit the URL.

**Cause:** The file is not in `src/routes/`. It must be inside `src/routes/` (or a subdirectory of it), and the file must end with `.ts`.

**Fix:** Move the file to `src/routes/your-file.ts` and restart the server.

### 2. "Module not found" errors

**Problem:** `Cannot find module 'tina4-nodejs'` or similar.

**Cause:** Missing npm install or incorrect import path.

**Fix:** Run `npm install` in your project root. Make sure your import uses the exact package name: `import { Router } from "tina4-nodejs"`.

### 3. JSON response shows HTML

**Problem:** Your JSON endpoint returns HTML instead of JSON.

**Cause:** You returned a string instead of using `res.json()`. A plain string tells Tina4 to treat it as HTML.

**Fix:** Use `res.json(data)` for JSON endpoints. `console.log()` is not a response mechanism.

### 4. Template not found

**Problem:** `Template "my-page.html" not found` error.

**Cause:** The template file is not in `src/templates/`, or there is a typo in the filename.

**Fix:** Check that the file exists at `src/templates/my-page.html`. The name in `res.html()` is relative to `src/templates/`.

### 5. Port already in use

**Problem:** `Error: Address already in use (port 7148)`

**Cause:** Another process is occupying port 7148.

**Fix:** Stop the other process, or change the port:

```bash
TINA4_PORT=8080
```

Or use the CLI flag: `tina4 serve --port 8080`.

### 6. Changes not reflected

**Problem:** You edited a file but the browser shows the old version.

**Cause:** Live reload may not be active. Browser caching can serve stale versions.

**Fix:** Hard-refresh the browser (`Ctrl+Shift+R` or `Cmd+Shift+R`). If that fails, restart the dev server with `Ctrl+C` and `tina4 serve`.

### 7. .env not loaded

**Problem:** Environment variables have no effect.

**Cause:** The `.env` file must be at the project root (same directory as `package.json`).

**Fix:** Move `.env` to the project root.
