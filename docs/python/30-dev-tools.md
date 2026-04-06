# Chapter 29: Dev Tools

## 1. Debugging at 2am

2am. Production monitoring pings you. A 500 error on checkout. You pull up the dev dashboard. The request inspector shows the failing request. The stack trace points to line 47 of `src/routes/checkout.py` -- an `AttributeError` on the shipping address because the user skipped the form field. You add a None check. Push the fix. Back to sleep. Total time: 30 seconds.

Tina4's dev tools are not an afterthought. They ship with the framework from day one. When `TINA4_DEBUG=true`, you get a development dashboard, an error overlay with source code, live reload, a request inspector with replay, a SQL query runner, a queue monitor, and system info -- all without installing extra packages.

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

The dev dashboard has several sections. Navigation tabs run along the top.

### System Overview

The landing page shows at a glance:

- **Framework version** -- The installed Tina4 Python version
- **Python version** -- The running Python version and loaded packages
- **Uptime** -- How long the server has been running
- **Memory usage** -- Current and peak memory consumption
- **Database status** -- Connection status, database engine, file size (for SQLite)
- **Environment** -- Current `.env` variables (sensitive values masked)
- **Project structure** -- Directory listing of your project with file counts

Check here first when something feels off. Is the database connected? Is the right Python version running? Are the environment variables loaded?

---

## 4. The Dev Toolbar

Visit any HTML page in your application. A debug toolbar appears at the bottom of the page. Thin bar. Click it to expand.

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

Click any section to expand it. Clicking "DB" shows every SQL query that ran during the request, with the query text, parameters, execution time, and row count.

### Disabling the Toolbar

The toolbar hides when `TINA4_DEBUG=false`. You can also hide it for specific routes by returning a response with the `X-Debug-Toolbar: off` header:

```python
from tina4_python.core.router import get

@get("/api/data")
async def api_data(request, response):
    return response({"data": "no toolbar"}, headers={
        "X-Debug-Toolbar": "off"
    })
```

This is useful for API endpoints that return JSON -- the toolbar only matters for HTML pages.

---

## 5. Error Overlay

An unhandled exception occurs. Tina4 does not show a generic "500 Internal Server Error" page. It shows a detailed error overlay:

- **Exception type and message** -- What went wrong, in plain language
- **Stack trace** -- Every function call that led to the error, from entry point to crash
- **Source code** -- The Python code around the line that threw the exception, with the failing line highlighted
- **Request data** -- HTTP method, URL, headers, body, and query parameters of the request that triggered the error
- **Environment** -- Relevant `.env` variables at the time of the error

### Example Error

Write this handler:

```python
@get("/api/users/{user_id}")
async def get_user(request, response):
    user_id = request.params["user_id"]
    user = get_user_from_db(user_id)
    return response({"name": user.name, "email": user.email})
```

If `get_user_from_db()` returns `None` for a missing user, the error overlay shows:

```
AttributeError: 'NoneType' object has no attribute 'name'

  File: src/routes/users.py, line 5

  3 | async def get_user(request, response):
  4 |     user_id = request.params["user_id"]
  5 |     user = get_user_from_db(user_id)
> 6 |     return response({"name": user.name, "email": user.email})
  7 |

  Request: GET /api/users/999
  Headers: {"Accept": "application/json"}
```

The highlighted line makes the cause obvious. `user` is `None` and the code accesses `.name` on it.

### Error Overlay in Production

When `TINA4_DEBUG=false`, the error overlay is disabled. Users see a clean error page. Full error details go to `logs/error.log` for later investigation.

---

## 6. The Gallery

The gallery is a collection of ready-to-use code examples built into the dev dashboard. Each gallery item includes:

- A description of what it does
- The complete source code (routes, templates, models)
- A "Try It" button that installs the example into your project

Available gallery items:

- **JWT Authentication** -- Complete login/register flow with token management
- **CRUD API** -- Full REST API with ORM model
- **File Upload** -- Multipart form handling with file storage
- **WebSocket Chat** -- Real-time chat with rooms
- **Email Contact Form** -- Form with Messenger integration
- **Dashboard Template** -- Admin dashboard with tina4css

Click "Try It" on any gallery item. Tina4 creates the necessary files in your project. Modify them to fit your needs.

---

## 7. Live Reload

When `TINA4_DEBUG=true`, Tina4 watches your project files for changes and reloads the server. Edit a route file. Save it. The browser refreshes with the new code. No manual restart required.

```bash
tina4 serve
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

Tina4 uses file system monitoring to detect changes. When a Python file changes, the server restarts. When a template changes, only the browser refreshes (no server restart needed).

The reload happens in under a second. Edit code. Switch to the browser. The changes are already there.

### Browser Auto-Refresh (DevReload)

When `TINA4_DEBUG=true`, Tina4 Python refreshes the browser when source files change. Save a file and the browser updates on its own. This matches the behavior of the PHP, Ruby, and Node.js implementations.

---

## 8. Hot-Patching with jurigged

For faster iteration, Tina4 supports hot-patching via jurigged. Hot-patching updates function definitions in the running server without restarting it:

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
tina4 serve --hot
```

```
  Tina4 Python v3.0.0
  HTTP server running at http://0.0.0.0:7145
  Hot-patching enabled (jurigged)
```

Edit any route handler and save. The function updates in place -- without restarting the server. The next request uses the new code.

### When Hot-Patching Cannot Help

Hot-patching works for function body changes. It does not work for:

- Adding or removing route decorators (requires restart)
- Changing module-level variables (requires restart)
- Modifying class definitions (may require restart)
- Changing `.env` (requires restart)

For these changes, the server does a full reload.

---

## 9. Request Inspector

The request inspector records every HTTP request to your application. For each request:

- **Timestamp** -- When the request arrived
- **Method** -- GET, POST, PUT, DELETE
- **URL** -- The full URL including query parameters
- **Status** -- The HTTP status code returned (color-coded: green for 2xx, yellow for 4xx, red for 5xx)
- **Time** -- How long the request took to process
- **Request ID** -- A unique identifier for correlating logs

Click on any request to see its full details.

### Request Details Panel

- **Headers** -- All request headers (Accept, Content-Type, Authorization)
- **Body** -- The request body (for POST/PUT/PATCH), formatted as JSON if applicable
- **Query parameters** -- Parsed URL query parameters
- **Route match** -- Which route definition matched this request
- **Middleware** -- Which middleware ran and how long each took
- **Database queries** -- Every SQL query executed during this request, with timing
- **Template renders** -- Which templates rendered and how long each took
- **Response headers** -- The response headers sent back
- **Response body** -- The first 1000 characters of the response body

### Filtering Requests

The inspector supports filtering:

- **By status**: Click the status code badges at the top (e.g., show only 5xx errors)
- **By method**: Filter by GET, POST, PUT, DELETE
- **By path**: Search for a URL pattern (e.g., `/api/` for API requests only)
- **By time range**: Show requests from the last 5 minutes, 1 hour, or all time

### Request Replay

Click "Replay" on any request to re-send it. The inspector fires the same method, URL, headers, and body. You reproduce an error without constructing the curl command by hand.

This is the fastest path from "what happened?" to "I can see it happen again." Find a failing request. Hit Replay. Watch the error overlay show the stack trace. Fix the code. Replay again. Green status code. Done.

No more `print()` statements scattered through your code. The inspector shows what happened. Every request. Every detail. With one-click replay.

---

## 10. SQL Query Runner

The dev dashboard includes a SQL query runner. Execute queries against your database:

- **Execute queries** -- Run any SQL statement
- **See results** -- Formatted table with column headers and row numbers
- **View query timing** -- How long each query took
- **Browse tables** -- A sidebar lists all tables with their column definitions
- **Export results** -- Download as CSV

```sql
SELECT * FROM products WHERE category = 'Electronics' ORDER BY price DESC;
```

The results display in a table with column headers, row numbers, and data type indicators. Copy results, export as CSV, or run another query.

### Safety

The query runner is read-write in development. You can run INSERT, UPDATE, and DELETE statements. Be careful -- there is no undo. In shared environments, consider a read-only database connection for the dev dashboard.

The query runner only works when `TINA4_DEBUG=true`. It is disabled in production.

---

## 11. Queue Monitor

If your application uses background job queues (Chapter 12 -- Queues), the dev dashboard includes a queue monitor. The monitor shows five categories:

- **Pending jobs** -- Jobs waiting to be processed
- **Active jobs** -- Jobs currently being processed
- **Completed jobs** -- Recently completed jobs with timing
- **Failed jobs** -- Jobs that threw exceptions, with error details
- **Dead-letter queue** -- Jobs that failed too many times

For each job, you see:

- The job function name
- The payload (serialized arguments)
- When it was enqueued
- When it started processing (if active)
- The error message and stack trace (if failed)
- How many times it has been retried

You can also take action:

- **Retry a failed job** -- Click "Retry" to move it back to the pending queue
- **Delete a job** -- Remove it from any queue
- **Pause/resume the queue** -- Stop processing without losing jobs

The queue monitor gives you a window into your background work. A job fails. You see the error. You fix the code. You hit Retry. The job processes. No log file hunting. No guesswork about what payload caused the failure.

---

## 12. System Info

The System Info tab shows detailed information about your environment:

- **Python Configuration** -- Version, installed packages, virtual environment path, memory limit
- **Database Info** -- Engine, version, connection details, table sizes, index information
- **Server Info** -- OS, hostname, server software, document root
- **Tina4 Config** -- All loaded `.env` variables (sensitive values masked), auto-discovered routes, registered middleware, ORM models
- **Disk Usage** -- Size of your project directory, data directory, logs directory

This panel solves the "it works on my machine" problem. Compare the System Info output between two environments. Spot the difference. The wrong Python version. A missing package. A misconfigured environment variable. The answer is in the panel.

---

## 13. Exercise: Debug a Failing Route

Your colleague wrote a route that fails. Use the dev tools to find and fix the bug.

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
5. Use Request Replay to verify each fix

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

The dev tools made each bug visible. The error overlay showed the SQL syntax error with the exact line. The request inspector showed the missing body causing a `KeyError`. Request Replay let you re-send the fixed requests without leaving the dashboard.

---

## 14. Gotchas

### 1. Dev Dashboard Accessible on Network

**Problem:** Anyone on your network can access the dev dashboard.

**Cause:** `TINA4_DEBUG=true` makes the dashboard available at `/__dev`.

**Fix:** In production, set `TINA4_DEBUG=false` to disable the dashboard. In shared development environments, restrict network access.

### 2. Live Reload Causes Connection Drops

**Problem:** WebSocket connections drop every time you save a file.

**Cause:** The server restarts on file change, which closes all active connections.

**Fix:** Use hot-patching (`--hot` flag) instead of live reload for WebSocket development. Hot-patching updates function bodies without restarting the server, so connections stay open.

### 3. Error Overlay Shows in Production

**Problem:** Users see Python stack traces when errors occur.

**Cause:** `TINA4_DEBUG=true` is set in the production environment.

**Fix:** Set `TINA4_DEBUG=false` in production. The error overlay is replaced by a clean error page. Full details go to `logs/error.log`.

### 4. Request Inspector Slows Down the Server

**Problem:** The server becomes slower as it runs longer.

**Cause:** The request inspector stores every request in memory. After thousands of requests, memory usage grows.

**Fix:** The inspector limits storage to the last 1000 requests. If you notice slowness, clear the inspector from the dashboard. In production, the inspector is disabled.

### 5. SQL Runner Executes Destructive Queries

**Problem:** Someone ran `DROP TABLE users` in the SQL query runner.

**Cause:** The SQL runner executes any valid SQL query. There is no confirmation step.

**Fix:** The SQL runner only works when `TINA4_DEBUG=true`. Never leave debug mode on in production. For sensitive development databases, use a read-only database connection for the SQL runner.

### 6. Hot-Patching Does Not Pick Up New Routes

**Problem:** You added a new route decorator but it does not respond to requests.

**Cause:** Hot-patching (jurigged) can update function bodies but cannot register new decorators. Adding `@get("/new-route")` requires the decorator to execute, which only happens at import time.

**Fix:** Restart the server when adding or removing routes. Hot-patching modifies existing route behavior. It does not add new routes.

### 7. Template Changes Not Reflected

**Problem:** You edited a template but the page still shows the old version.

**Cause:** Template caching is enabled (`TINA4_CACHE_TEMPLATES=true`). The compiled template serves from cache.

**Fix:** In development, set `TINA4_CACHE_TEMPLATES=false` (this is the default when `TINA4_DEBUG=true`). If you enabled template caching manually, disable it for development.

### 8. Queue Monitor Shows No Jobs

**Problem:** The Queue Monitor tab is empty even though your application uses queues.

**Cause:** The queue system is not running. Jobs are enqueued but no worker processes them.

**Fix:** Start a queue worker: `tina4 serve --worker`. The queue monitor reflects the state of the queue storage (database or Redis). If no worker is running, jobs sit in "Pending" and never move to "Active" or "Completed."
