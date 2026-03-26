# Chapter 18: Dev Tools

## 1. Debugging at 2am

2am. Production monitoring pings you -- a 500 error on checkout. You pull up the dev dashboard. Find the failing request in the request inspector. See the full stack trace with source code context. Line 47 of `src/routes/checkout.py` -- an `AttributeError` on the shipping address because the user skipped the form field. You add a None check. Push the fix. Go back to sleep. Total time: 30 seconds.

Tina4's dev tools are not an afterthought. They are built into the framework from day one. When `TINA4_DEBUG=true`, you get a development dashboard, an error overlay with source code, live reload, a request inspector, a SQL query runner, and more -- all without installing extra packages.

---

## 2. Enabling the Dev Dashboard

The dev dashboard is available when `TINA4_DEBUG=true` in your `.env`:

```env
TINA4_DEBUG=true
```

Restart your server and navigate to:

```
http://localhost:7145/__dev
```

You are now in the dev dashboard. No token or additional environment variables are needed -- the dashboard is a dev-only feature that only runs when debug mode is on. In production, set `TINA4_DEBUG=false` and the entire dashboard disappears.

---

## 3. Dashboard Overview

The dev dashboard has several sections, accessible from the navigation tabs at the top:

### System Overview

The landing page shows at a glance:

- **Framework version** -- The installed Tina4 Python version
- **Python version** -- The running Python version and loaded packages
- **Uptime** -- How long the server has been running
- **Memory usage** -- Current and peak memory consumption
- **Database status** -- Connection status, database engine, file size (for SQLite)
- **Environment** -- Current `.env` variables (sensitive values are masked)
- **Project structure** -- Directory listing of your project with file counts

This is the first thing to check when something feels off. Is the database connected? Is the right Python version running? Are the environment variables loaded?

---

## 4. The Dev Toolbar

When you visit any HTML page in your application (like `/products` or `/admin`), a debug toolbar appears at the bottom of the page. It is a thin bar that expands when you click on it.

The toolbar shows:

| Field | What It Means |
|-------|--------------|
| **Request** | HTTP method and URL of the current request |
| **Status** | HTTP response status code |
| **Time** | Total request processing time in milliseconds |
| **DB** | Number of database queries executed and total query time |
| **Memory** | Python memory used for this request |
| **Template** | The template rendered and how long rendering took |
| **Session** | Session ID and session data summary |
| **Route** | Which route handler matched this request |

Click any section to expand it and see details. For example, clicking "DB" shows every SQL query that ran during the request, with the query text, parameters, execution time, and number of rows returned.

### Disabling the Toolbar

The toolbar is automatically hidden when `TINA4_DEBUG=false`. You can also hide it for specific routes by returning a response with the `X-Debug-Toolbar: off` header:

```python
from tina4_python.core.router import get

@get("/api/data")
async def api_data(request, response):
    return response({"data": "no toolbar"}, headers={
        "X-Debug-Toolbar": "off"
    })
```

This is useful for API endpoints that return JSON -- the toolbar is only meaningful for HTML pages.

---

## 5. Error Overlay

When an unhandled exception occurs, Tina4 does not show a generic "500 Internal Server Error" page. Instead, it shows a detailed error overlay with:

- **Exception type and message** -- What went wrong, in plain language
- **Stack trace** -- Every function call that led to the error, from the entry point to the crash
- **Source code** -- The actual Python code around the line that threw the exception, with the failing line highlighted
- **Request data** -- The HTTP method, URL, headers, body, and query parameters of the request that triggered the error
- **Environment** -- Relevant `.env` variables at the time of the error

### Example Error

If you accidentally write:

```python
@get("/api/users/{user_id}")
async def get_user(request, response):
    user_id = request.params["user_id"]
    user = get_user_from_db(user_id)
    return response({"name": user.name, "email": user.email})
```

And `get_user_from_db()` returns `None` for a missing user, the error overlay shows:

```
AttributeError: 'NoneType' object has no attribute 'name'

  File: src/routes/users.py, line 5

  3 │ async def get_user(request, response):
  4 │     user_id = request.params["user_id"]
  5 │     user = get_user_from_db(user_id)
→ 6 │     return response({"name": user.name, "email": user.email})
  7 │

  Request: GET /api/users/999
  Headers: {"Accept": "application/json"}
```

You can see exactly what happened, where it happened, and what request triggered it.

### Error Overlay in Production

When `TINA4_DEBUG=false`, the error overlay is disabled. Instead, users see a clean error page. The full error details are written to the log file (`logs/error.log`) so you can investigate later.

---

## 6. The Gallery

The gallery is a collection of ready-to-use code examples built into the dev dashboard. Each gallery item includes:

- A description of what it does
- The complete source code (routes, templates, models)
- A "Try It" button that installs the example into your project

Available gallery items include:

- **JWT Authentication** -- Complete login/register flow with token management
- **CRUD API** -- Full REST API with ORM model
- **File Upload** -- Multipart form handling with file storage
- **WebSocket Chat** -- Real-time chat with rooms
- **Email Contact Form** -- Form with Messenger integration
- **Dashboard Template** -- Admin dashboard with tina4css

Click "Try It" on any gallery item, and Tina4 creates the necessary files in your project. You can then modify them to fit your needs.

---

## 7. Live Reload

When `TINA4_DEBUG=true`, Tina4 watches your project files for changes and automatically reloads the server. Edit a route file, save it, and the browser refreshes with the new code -- no manual restart required.

```bash
uv run python app.py
```

```
  Tina4 Python v3.0.0
  HTTP server running at http://0.0.0.0:7145
  Live reload enabled -- watching for changes
```

Live reload watches:

- `src/routes/*.py` -- Route definitions
- `src/orm/*.py` -- ORM models
- `src/middleware/*.py` -- Middleware
- `src/templates/*.html` -- Templates (browser refresh only, no server restart)
- `.env` -- Environment variables

### How It Works

Tina4 uses file system monitoring to detect changes. When a Python file changes, the server restarts automatically. When a template changes, only the browser refreshes (no server restart needed).

The reload happens in under a second. You edit code, switch to the browser, and the changes are already there.

### Browser Auto-Refresh (DevReload)

When `TINA4_DEBUG=true`, Tina4 Python automatically refreshes the browser when source files change. You do not need to manually reload the page -- save a file and the browser updates on its own. This matches the behavior of the PHP, Ruby, and Node.js implementations.

---

## 8. Hot-Patching with jurigged

For even faster iteration, Tina4 supports hot-patching via jurigged. Hot-patching updates function definitions in the running server without restarting it. This means:

- No connection drops (WebSocket clients stay connected)
- No cache loss (in-memory caches stay warm)
- No session interruption
- Sub-second updates

Install jurigged:

```bash
uv add --dev jurigged
```

Start the server with hot-patching:

```bash
uv run python app.py --hot
```

```
  Tina4 Python v3.0.0
  HTTP server running at http://0.0.0.0:7145
  Hot-patching enabled (jurigged)
```

Now edit any route handler and save. The function is updated in place -- without restarting the server. The next request uses the new code immediately.

### When Hot-Patching Cannot Help

Hot-patching works for function body changes. It does not work for:

- Adding or removing route decorators (requires restart)
- Changing module-level variables (requires restart)
- Modifying class definitions (may require restart)
- Changing `.env` (requires restart)

For these changes, the server does a full reload automatically.

---

## 9. Request Inspector

The request inspector in the dev dashboard shows every HTTP request that has hit the server. For each request, you see:

- **Timestamp** -- When the request arrived
- **Method** -- GET, POST, PUT, DELETE, etc.
- **URL** -- The full URL including query parameters
- **Status** -- The HTTP status code returned
- **Time** -- How long the request took to process
- **Body** -- The request body (for POST/PUT)
- **Response** -- The response body
- **Headers** -- Request and response headers
- **Queries** -- All database queries executed during the request

No more `print()` statements scattered through your code. The inspector shows what happened. Every request. Every detail.

### Filtering Requests

The inspector supports filtering by:

- URL pattern (e.g., `/api/` to see only API requests)
- HTTP method (e.g., only POST requests)
- Status code (e.g., only 500 errors)
- Time range (e.g., requests in the last 5 minutes)

---

## 10. SQL Query Runner

The dev dashboard includes a SQL query runner that lets you execute queries directly against your database. This is useful for:

- Inspecting data during development
- Running ad-hoc queries to debug issues
- Testing SQL before writing it in your route handlers
- Examining table schemas

```sql
SELECT * FROM products WHERE category = 'Electronics' ORDER BY price DESC;
```

The results are displayed in a table with column headers, row numbers, and data type indicators. You can copy results, export as CSV, or run another query.

The query runner only works when `TINA4_DEBUG=true`. It is completely disabled in production.

---

## 11. Exercise: Debug a Failing Route

Your colleague wrote a route that is failing in mysterious ways. Use the dev tools to find and fix the bug.

### Setup

Create `src/routes/buggy.py`:

```python
from tina4_python.core.router import get, post
from tina4_python.cache import cache_get, cache_set

@get("/api/buggy/users")
async def buggy_users(request, response):
    users = cache_get("all_users")
    if users:
        return response({"users": users, "source": "cache"})

    # Bug 1: This query has an error
    db = Database.get_connection()
    users = db.fetch_all("SELCT * FROM users ORDER BY name")

    cache_set("all_users", users, ttl=300)
    return response({"users": users, "source": "database"})


@post("/api/buggy/users")
async def buggy_create_user(request, response):
    body = request.body

    # Bug 2: Missing validation
    user = User()
    user.name = body["name"]
    user.email = body["email"]
    user.save()

    # Bug 3: Wrong status code
    return response({"message": "User created", "user": user.to_dict()})
```

### Requirements

1. Open the dev dashboard at `http://localhost:7145/__dev`
2. Hit the `GET /api/buggy/users` endpoint and find Bug 1 using the error overlay
3. Hit the `POST /api/buggy/users` endpoint without a body and find Bug 2 using the request inspector
4. Fix all three bugs:
   - Bug 1: Fix the SQL syntax error
   - Bug 2: Add validation for required fields
   - Bug 3: Return 201 instead of 200

### Solution

```python
from tina4_python.core.router import get, post
from tina4_python.cache import cache_get, cache_set

@get("/api/buggy/users")
async def buggy_users(request, response):
    users = cache_get("all_users")
    if users:
        return response({"users": users, "source": "cache"})

    db = Database.get_connection()
    users = db.fetch_all("SELECT * FROM users ORDER BY name")  # Fixed: SELCT -> SELECT

    cache_set("all_users", users, ttl=300)
    return response({"users": users, "source": "database"})


@post("/api/buggy/users")
async def buggy_create_user(request, response):
    body = request.body

    # Fixed: Added validation
    if not body.get("name") or not body.get("email"):
        return response({"error": "Name and email are required"}, 400)

    user = User()
    user.name = body["name"]
    user.email = body["email"]
    user.save()

    return response({"message": "User created", "user": user.to_dict()}, 201)  # Fixed: 201
```

The dev tools made it easy: the error overlay showed the SQL syntax error with the exact line, the request inspector showed the missing body causing a `KeyError`, and you knew to fix the status code from the API conventions covered in Chapter 3.

---

## 12. Gotchas

### 1. Dev Dashboard Accessible on Network

**Problem:** Anyone on your network can access the dev dashboard.

**Cause:** `TINA4_DEBUG=true` makes the dashboard available at `/__dev`.

**Fix:** In production, set `TINA4_DEBUG=false` to disable the dashboard entirely. In shared development environments, restrict network access.

### 2. Live Reload Causes Connection Drops

**Problem:** WebSocket connections drop every time you save a file.

**Cause:** The server restarts on file change, which closes all active connections. This is expected behavior for live reload.

**Fix:** Use hot-patching (`--hot` flag) instead of live reload for WebSocket development. Hot-patching updates function bodies without restarting the server, so connections stay open.

### 3. Error Overlay Shows in Production

**Problem:** Users see Python stack traces when errors occur.

**Cause:** `TINA4_DEBUG=true` is set in the production environment.

**Fix:** Set `TINA4_DEBUG=false` in production. The error overlay is replaced by a clean error page, and the full details are logged to `logs/error.log`.

### 4. Request Inspector Slows Down the Server

**Problem:** The server becomes slower as it runs longer.

**Cause:** The request inspector stores every request in memory. After thousands of requests, memory usage grows.

**Fix:** The inspector automatically limits storage to the last 1000 requests. If you notice slowness, clear the inspector from the dashboard. In production, the inspector is disabled.

### 5. SQL Runner Executes Destructive Queries

**Problem:** Someone ran `DROP TABLE users` in the SQL query runner.

**Cause:** The SQL runner executes any valid SQL query, including destructive ones. There is no confirmation step.

**Fix:** The SQL runner is only available when `TINA4_DEBUG=true`. Never leave debug mode on in production. For sensitive development databases, use a read-only database connection for the SQL runner.

### 6. Hot-Patching Does Not Pick Up New Routes

**Problem:** You added a new route decorator but it does not respond to requests.

**Cause:** Hot-patching (jurigged) can update function bodies but cannot register new decorators. Adding `@get("/new-route")` requires the decorator to execute, which only happens at import time.

**Fix:** Restart the server when adding or removing routes. Hot-patching is for modifying the behavior of existing routes, not for adding new ones.

### 7. Template Changes Not Reflected

**Problem:** You edited a template but the page still shows the old version.

**Cause:** Template caching is enabled (`TINA4_CACHE_TEMPLATES=true`). The compiled template is served from cache.

**Fix:** In development, set `TINA4_CACHE_TEMPLATES=false` (this is the default when `TINA4_DEBUG=true`). If you manually enabled template caching, disable it for development.
