# Chapter 29: Dev Tools

## 1. Debugging at 2am

2am. Production monitoring pings you. A 500 error on checkout. You pull up the dev dashboard. The request inspector shows the failing request. The stack trace points to line 47 of `src/routes/checkout.php` -- a null reference on the shipping address because the user skipped the form field. You add a null check. Push the fix. Back to sleep. Total time: 30 seconds.

Tina4's dev tools ship with the framework from day one. When `TINA4_DEBUG=true`, you get a development dashboard, an error overlay with source code, hot reload, a request inspector with replay, a SQL query runner, a queue monitor, and system info -- all without installing extra packages.

---

## 2. Enabling the Dev Dashboard

Set `TINA4_DEBUG=true` in your `.env`:

```bash
TINA4_DEBUG=true
```

Restart your server and navigate to:

```
http://localhost:7145/__dev
```

No token or additional environment variables needed. The dashboard runs only when debug mode is on. Set `TINA4_DEBUG=false` in production and the entire dashboard disappears.

---

## 3. Dashboard Overview

The dev dashboard has several sections. Navigation tabs at the top:

### System Overview

The landing page shows at a glance:

- **Framework version** -- The installed Tina4 PHP version
- **PHP version** -- The running PHP version and loaded extensions
- **Uptime** -- How long the server has been running
- **Memory usage** -- Current and peak memory consumption
- **Database status** -- Connection status, database engine, file size (for SQLite)
- **Environment** -- Current `.env` variables (sensitive values are masked)
- **Project structure** -- Directory listing of your project with file counts

Check here first when something feels off. Is the database connected? Is the right PHP version running? Are the environment variables loaded?

---

## 4. The Dev Toolbar

Visit any HTML page in your application (like `/products` or `/admin`). A debug toolbar appears at the bottom. Thin bar. Expands when you click on it.

The toolbar shows:

| Field | What It Means |
|-------|--------------|
| **Request** | HTTP method and URL of the current request |
| **Status** | HTTP response status code |
| **Time** | Total request processing time in milliseconds |
| **DB** | Number of database queries executed and total query time |
| **Memory** | PHP memory used for this request |
| **Template** | The template rendered and how long rendering took |
| **Session** | Session ID and session data summary |
| **Route** | Which route handler matched this request |

Click any section to expand it and see details. For example, clicking "DB" shows every SQL query that ran during the request, with the query text, parameters, execution time, and number of rows returned.

### Disabling the Toolbar

The toolbar is automatically hidden when `TINA4_DEBUG=false`. You can also hide it for specific routes by returning a response with the `X-Debug-Toolbar: off` header:

```php
Router::get("/api/data", function ($request, $response) {
    return $response->json(["data" => "no toolbar"], 200, [
        "X-Debug-Toolbar" => "off"
    ]);
});
```

This is useful for API endpoints that return JSON -- the toolbar is only meaningful for HTML pages.

---

## 5. Error Overlay

An unhandled exception occurs. Tina4 does not show a generic "500 Internal Server Error" page. It shows a detailed error overlay with:

- **Exception type and message** -- What went wrong, in plain language
- **Stack trace** -- Every function call that led to the error, from the entry point to the crash
- **Source code** -- The actual PHP code around the line that threw the exception, with the failing line highlighted
- **Request data** -- The HTTP method, URL, headers, body, and query parameters of the request that triggered the error
- **Environment** -- Relevant `.env` variables at the time of the error

### Example Error

If you accidentally write:

```php
Router::get("/api/broken", function ($request, $response) {
    $user = null;
    return $response->json(["name" => $user->name]);
});
```

Visiting `/api/broken` shows the error overlay:

```
TypeError: Cannot access property "name" on null

  File: src/routes/api.php
  Line: 4

  2 | Router::get("/api/broken", function ($request, $response) {
  3 |     $user = null;
> 4 |     return $response->json(["name" => $user->name]);
  5 | });

  Stack Trace:
    #0 src/routes/api.php:4 — {closure}()
    #1 vendor/tina4/tina4-php/src/Router.php:142 — call_user_func()
    #2 vendor/tina4/tina4-php/src/Server.php:89 — Router->dispatch()

  Request: GET /api/broken
  Headers: Accept: */*
  Query: (none)
  Body: (none)
```

The highlighted line (line 4) makes it immediately obvious: `$user` is null and you are trying to access `->name` on it.

### Error Overlay in Production

When `TINA4_DEBUG=false`, the error overlay is disabled. Users see a clean error page (`src/templates/errors/500.html` if it exists, or a generic message). Full error details go to `logs/error.log`.

---

## 6. Request Inspector

The request inspector records every HTTP request to your application:

- **Method and URL** -- GET /api/products, POST /api/users, etc.
- **Status code** -- 200, 201, 404, 500, etc. (color-coded: green for 2xx, yellow for 4xx, red for 5xx)
- **Response time** -- How many milliseconds the request took
- **Request ID** -- A unique identifier for correlating logs
- **Timestamp** -- When the request was received

Click on any request to see its full details:

### Request Details Panel

- **Headers** -- All request headers (Accept, Content-Type, Authorization, etc.)
- **Body** -- The request body (for POST/PUT/PATCH), formatted as JSON if applicable
- **Query parameters** -- Parsed URL query parameters
- **Route match** -- Which route definition matched this request
- **Middleware** -- Which middleware ran and how long each took
- **Database queries** -- Every SQL query executed during this request, with timing
- **Template renders** -- Which templates were rendered and how long each took
- **Response headers** -- The response headers sent back to the client
- **Response body** -- The first 1000 characters of the response body

### Filtering Requests

The inspector supports filtering:

- **By status**: Click the status code badges at the top to filter (e.g., show only 5xx errors)
- **By method**: Filter by GET, POST, PUT, DELETE
- **By path**: Search for a URL pattern (e.g., `/api/` to show only API requests)
- **By time range**: Show requests from the last 5 minutes, 1 hour, or all time

### Request Replay

Click "Replay" on any request to re-send it. Reproduce an error without constructing the curl command by hand.

---

## 7. SQL Query Runner

The dev dashboard includes an interactive SQL query runner. Navigate to the "SQL" tab:

- **Execute queries** directly against your database
- **See results** in a formatted table
- **View query timing** -- how long each query took
- **Browse tables** -- a sidebar lists all tables in your database with their column definitions
- **Export results** -- download query results as CSV

### Example

Type into the query editor:

```sql
SELECT name, price, in_stock FROM products WHERE price > 50 ORDER BY price DESC
```

Click "Run" and see:

```
Results (3 rows, 2.1ms):

| name              | price  | in_stock |
|-------------------|--------|----------|
| Standing Desk     | 549.99 | 0        |
| Ergonomic Chair   | 399.99 | 1        |
| Wireless Keyboard | 79.99  | 1        |
```

Faster than opening a separate database client. Test queries, check data, debug issues -- all without leaving the browser.

### Safety

The query runner is read-write in development. You can run INSERT, UPDATE, and DELETE statements. Be careful -- there is no undo. In shared environments, consider using a read-only database user for the dev dashboard.

---

## 8. Hot Reload

Edit a file. Save it. The browser updates. No manual refresh. No external tools.

### How It Works

The `tina4` Rust CLI is the sole file watcher for the Tina4 stack — PHP has no internal watcher (there never was one, unlike Python/Ruby/Node which had their own watchers that were removed in 3.11.x). The flow:

```
 ┌────────────┐  POST /__dev/api/reload   ┌────────────┐   WS /__dev_reload    ┌─────────┐
 │ tina4 CLI  │ ─────────────────────────►│ PHP server │ ─────────────────────►│ Browser │
 │ (watcher)  │                           │            │   fallback: poll      │         │
 └────────────┘                           └────────────┘   GET /__dev/api/mtime└─────────┘
```

1. The CLI watches `src/`, `migrations/`, `.env` with the `notify` crate. Events are filtered to real source changes — Access and Metadata-only events are dropped; `__pycache__`, `.git`, `.venv`, `node_modules`, `vendor`, `logs`, `.log`/`.db*`/`.swp`/`.pyc` files are ignored. A real mtime check also defeats overlayfs / polling-mode spurious events (Podman, distrobox).
2. On a real change the CLI POSTs `/__dev/api/reload` to your running PHP server. The server keeps running — there is no process restart for file edits.
3. `DevAdmin` bumps its in-memory `$reloadMtime` counter and broadcasts `{type: "reload"}` over WebSocket at `/__dev_reload`. `GET /__dev/api/mtime` returns the counter for browsers using the polling fallback.
4. The inline reload script injected by the dev toolbar reloads the browser. SCSS/CSS changes are signalled as `type: "css"` and swap the stylesheet without a full reload.

No file watcher inside PHP. No sentinel file on disk. No daemon. No Node.js process. The Rust CLI watches, the framework relays, the browser reloads.

### Watched Directories and File Types

The file watcher scans three locations:

- `src/` -- Your application code (routes, ORM models, templates, assets)
- `migrations/` -- Database migration files
- `.env` -- Environment configuration

### What Happens on Reload

- **PHP source** (`src/routes/*.php`, `src/orm/*.php`, etc.) -- PHP loads these fresh on every request, so once the browser reloads, the next request sees the updated code. The server process stays up.
- **Template files** (`.twig`, `.html`) -- Re-read from disk on the next render.
- **`.env`** -- Re-read on next request.
- **SCSS/CSS** -- The browser swaps the stylesheet; no full page reload.

The PHP server never restarts for file edits. It only restarts if it actually crashes (unlikely in dev mode thanks to the error overlay catching most issues).

### Activation

Hot reload is only active when `TINA4_DEBUG=true`. In production (`TINA4_DEBUG=false`), the file watcher is disabled, the `/__dev_reload` WebSocket endpoint does not exist, and routes and templates are cached for performance.

### Disabling Hot Reload

If hot reload interferes with your workflow (e.g., you are filling out a form and do not want it to reset), disable it in `.env`:

```bash
TINA4_LIVE_RELOAD=false
```

This disables the browser-side reload while keeping `TINA4_DEBUG=true` for the rest of the dev tools.

---

## 9. Gallery -- Interactive Examples

The dev dashboard includes a Gallery section where you can deploy interactive code examples. This is useful for:

- Demonstrating API endpoints to team members
- Creating runnable documentation
- Prototyping features quickly

### Creating a Gallery Entry

Create a file in `src/gallery/`:

```php
<?php
// src/gallery/product-search.php
// title: Product Search
// description: Search products by name and category

use Tina4\Router;

Router::get("/gallery/product-search", function ($request, $response) {
    $q = $request->params["q"] ?? "";
    $category = $request->params["category"] ?? "";

    $product = new Product();
    $conditions = [];
    $params = [];

    if (!empty($q)) {
        $conditions[] = "name LIKE :q";
        $params["q"] = "%" . $q . "%";
    }

    if (!empty($category)) {
        $conditions[] = "category = :category";
        $params["category"] = $category;
    }

    $filter = !empty($conditions) ? implode(" AND ", $conditions) : "";
    $results = $product->select("*", $filter, $params, "name ASC");

    return $response->json([
        "query" => $q,
        "category" => $category,
        "results" => array_map(fn($p) => $p->toArray(), $results),
        "count" => count($results)
    ]);
});
```

The comments at the top (`// title:` and `// description:`) are parsed by the gallery and shown in the dashboard. Navigate to the Gallery tab to see all your interactive examples, with a "Try It" button that opens the endpoint in a new tab.

---

## 10. Queue Monitor

If your application uses background job queues (Chapter 12 -- Queues), the dev dashboard includes a queue monitor showing:

- **Pending jobs** -- Jobs waiting to be processed
- **Active jobs** -- Jobs currently being processed
- **Completed jobs** -- Recently completed jobs with timing
- **Failed jobs** -- Jobs that threw exceptions, with error details
- **Dead-letter queue** -- Jobs that failed too many times and were moved to the dead-letter queue

For each job, you can see:

- The job class or function name
- The payload (serialized arguments)
- When it was enqueued
- When it started processing (if active)
- The error message and stack trace (if failed)
- How many times it has been retried

You can also:

- **Retry a failed job** -- Click "Retry" to move it back to the pending queue
- **Delete a job** -- Remove it from any queue
- **Pause/resume the queue** -- Temporarily stop processing without losing jobs

---

## 11. System Info

The System Info tab shows detailed information about your environment:

- **PHP Configuration** -- Version, loaded extensions, php.ini location, memory limit, max execution time, upload limits
- **Database Info** -- Engine, version, connection details, table sizes, index information
- **Server Info** -- OS, hostname, server software, document root
- **Tina4 Config** -- All loaded `.env` variables (sensitive values masked), auto-discovered routes, registered middleware, ORM models
- **Disk Usage** -- Size of your project directory, data directory, logs directory, and vendor directory

This is especially useful when debugging environment-specific issues. If a colleague says "it works on my machine," compare the System Info output between both environments to spot differences.

---

## 12. Exercise: Debug a Failing Route

Set up a project with the following intentionally broken route, then use the dev tools to find and fix the bug.

### Setup

Create `src/routes/orders.php` with this intentionally broken code:

```php
<?php
use Tina4\Router;

Router::get("/api/orders/summary", function ($request, $response) {
    $product = new Product();
    $products = $product->select("*");

    $total = 0;
    foreach ($products as $p) {
        $total += $p->price * $p->quantity; // Bug: Product has no "quantity" field
    }

    $orderCount = count($products);
    $averageValue = $total / $orderCount; // Bug: division by zero if no products

    return $response->json([
        "total_value" => $total,
        "order_count" => $orderCount,
        "average_value" => round($averageValue, 2)
    ]);
});
```

### Task

1. Start the dev server with `tina4 serve`.
2. Visit `http://localhost:7145/api/orders/summary`.
3. Observe the error overlay.
4. Use the error overlay to identify the exact line and cause of the error.
5. Fix both bugs:
   - Replace `$p->quantity` with `1` (or remove the multiplication) since products do not have a quantity field.
   - Add a check for zero `$orderCount` before dividing.
6. Reload the page and verify the response is correct.
7. Open the dev dashboard at `/__dev` and find the failed request in the request inspector.
8. Verify the fixed request now appears as a 200 in the inspector.

### Expected Steps

1. The error overlay shows: `Undefined property: Product::$quantity` on the line `$total += $p->price * $p->quantity;`
2. You fix the line to `$total += $p->price;`
3. You reload and get a new error (if there are zero products): `Division by zero`
4. You add `if ($orderCount > 0)` before the division
5. The endpoint returns valid JSON

---

## 13. Solution

The fixed route:

```php
<?php
use Tina4\Router;

Router::get("/api/orders/summary", function ($request, $response) {
    $product = new Product();
    $products = $product->select("*");

    $total = 0.0;
    foreach ($products as $p) {
        $total += $p->price;
    }

    $orderCount = count($products);
    $averageValue = $orderCount > 0 ? $total / $orderCount : 0;

    return $response->json([
        "total_value" => round($total, 2),
        "order_count" => $orderCount,
        "average_value" => round($averageValue, 2)
    ]);
});
```

**Expected output (with 5 seeded products):**

```json
{
  "total_value": 909.95,
  "order_count": 5,
  "average_value": 181.99
}
```

### What You Practiced

- Reading the error overlay to find the exact line and error type
- Understanding stack traces
- Using the request inspector to view failed and successful requests
- Iterative debugging -- fixing one error, reloading, fixing the next

---

## 14. Gotchas

### 1. Dev Dashboard Returns 404

**Problem:** Navigating to `/__dev` returns a 404 page.

**Cause:** `TINA4_DEBUG` is not set to `true`.

**Fix:** Add to your `.env`:

```bash
TINA4_DEBUG=true
```

Restart the server after changing `.env`.

### 3. Hot Reload Not Working

**Problem:** You save a file but the browser does not reload.

**Cause:** Hot reload uses a WebSocket connection to the `/__dev_reload` endpoint. If your browser blocks WebSocket connections (some corporate proxies do), or if you are accessing the site via a reverse proxy that does not forward WebSocket, hot reload will not work.

**Fix:** Check the browser console for WebSocket connection errors to `/__dev_reload`. If you are behind a proxy, configure it to forward WebSocket connections. As a workaround, manually refresh with `Ctrl+R`.

### 4. Error Overlay Shows in Production

**Problem:** Users see stack traces and source code on error pages.

**Cause:** `TINA4_DEBUG=true` in the production `.env`.

**Fix:** Always set `TINA4_DEBUG=false` in production. This hides all debug information and shows the custom error page from `src/templates/errors/500.html` instead.

### 5. Request Inspector Shows Too Many Requests

**Problem:** The request inspector is flooded with entries, making it hard to find the one you care about.

**Cause:** Static file requests (CSS, JS, images, favicon) are all recorded.

**Fix:** Use the path filter to narrow down the list. Type `/api/` in the filter box to show only API requests. You can also configure the dev dashboard to exclude static file requests from the inspector.

### 6. SQL Runner Modifies Data Accidentally

**Problem:** You ran a DELETE query in the SQL runner and lost data.

**Cause:** The SQL runner executes queries directly against the database with full read-write access.

**Fix:** There is no undo. For safety, always include a WHERE clause with DELETE and UPDATE statements. If you are worried about accidental modifications, use a read-only database connection for the dev dashboard.

### 7. Debug Toolbar Breaks Layout

**Problem:** The debug toolbar at the bottom of the page overlaps with your content or breaks the layout.

**Cause:** The toolbar adds a fixed-position element at the bottom of the page. If your page uses `position: fixed` elements at the bottom (like a footer or chat widget), they may conflict.

**Fix:** The toolbar adds a `data-tina4-debug` attribute to the body. Use this in your CSS to adjust:

```css
body[data-tina4-debug] .my-footer {
    bottom: 40px; /* Make room for the debug toolbar */
}
```

Alternatively, collapse the toolbar by clicking on it -- it minimizes to a thin line.
