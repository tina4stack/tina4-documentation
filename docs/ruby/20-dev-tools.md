# Chapter 18: Dev Tools

## 1. Debugging at 2am

2am. Production monitoring pings you. A 500 error on the checkout endpoint. You open the dev dashboard. Find the failing request in the request inspector. Full stack trace with source code context. Line 47 of `src/routes/checkout.rb` -- a nil reference on the shipping address because the user skipped the form. Add a nil check. Push the fix. Go back to sleep. 30 seconds.

Tina4's dev tools are not an afterthought. They ship with the framework from day one. Set `TINA4_DEBUG=true` and you get a full development dashboard, an error overlay with source code, live reload, a request inspector, a SQL query runner -- all without installing a single extra package.

---

## 2. Enabling the Dev Dashboard

```env
TINA4_DEBUG=true
```

Navigate to `http://localhost:7147/__dev`. No token or additional environment variables are needed -- the dashboard is a dev-only feature that only runs when debug mode is on.

---

## 3. Dashboard Overview

### System Overview

- **Framework version** -- The installed Tina4 Ruby version
- **Ruby version** -- The running Ruby version, loaded gems
- **Uptime** -- How long the server has been running
- **Memory usage** -- Current and peak memory consumption
- **Database status** -- Connection status, database engine, file size
- **Environment** -- Current `.env` variables (sensitive values are masked)

### Request Inspector

Every HTTP request is logged with:

- Method, path, status code, response time
- Request headers, query parameters, body
- Response headers and body
- Database queries executed (with timing)
- Template renders (with timing)

Click any request to drill into the details. This replaces `puts` debugging entirely.

### Error Log

Unhandled exceptions are captured with:

- Full stack trace with source code context
- The request that triggered the error
- Occurrence count and timestamps
- Ruby version and gem information

### Queue Manager

See queue statistics, recent jobs, failed jobs, and dead letter queue.

### WebSocket Monitor

Active WebSocket connections with metadata, message counts, and connection duration.

### Routes

All registered routes with methods, paths, middleware, and auth requirements.

---

## 4. The Debug Overlay

When `TINA4_DEBUG=true`, every HTML page shows a debug toolbar at the bottom:

- Request details (method, URL, duration)
- Database queries executed (with timing and SQL)
- Template renders (with timing)
- Session data
- Recent log entries

Click any section to expand it. The overlay is injected automatically -- you do not add any code.

---

## 5. SQL Query Runner

The dev dashboard includes an interactive SQL query runner:

```
http://localhost:7147/__dev#sql
```

Type any SQL query and see the results instantly. Useful for exploring your data without a separate database client:

```sql
SELECT * FROM products WHERE price > 50 ORDER BY price DESC
```

The runner shows the result as a formatted table with column types and row count.

---

## 6. Log Viewer

View application logs in real time from the dashboard:

```
http://localhost:7147/__dev#logs
```

Filter by level (DEBUG, INFO, WARNING, ERROR), search by keyword, and view timestamps. In development, all log levels are shown. In production with `TINA4_LOG_LEVEL=WARNING`, only warnings and errors appear.

### Logging from Code

```ruby
Tina4::Logger.debug("Processing order #{order_id}")
Tina4::Logger.info("User #{user_id} logged in")
Tina4::Logger.warning("Rate limit approaching for IP #{ip}")
Tina4::Logger.error("Failed to send email: #{error.message}")
```

Logs are written to `logs/app.log` and displayed in the dev dashboard.

---

## 7. Live Reload

When `TINA4_DEBUG=true`, the dev server watches your files for changes and automatically restarts:

- Route files (`src/routes/*.rb`)
- ORM models (`src/orm/*.rb`)
- Templates (`src/templates/*`)
- The `.env` file

When you save a file, the server reloads within 1 second. The browser page refreshes automatically if you have the debug overlay enabled.

---

## 8. Error Pages

### Development Error Page

When `TINA4_DEBUG=true`, unhandled exceptions show a detailed error page with:

- The exception class and message
- The full stack trace with source code context (5 lines above and below)
- The request details (method, path, headers, body)
- Environment variables
- Database connection status

### Production Error Page

When `TINA4_DEBUG=false`, users see a generic error page. Create custom error pages:

- `src/templates/errors/404.html` -- Page not found
- `src/templates/errors/500.html` -- Internal server error

---

## 9. Health Check Endpoint

The `/health` endpoint reports application status:

```bash
curl http://localhost:7147/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 3600,
  "version": "3.0.0",
  "framework": "tina4-ruby",
  "ruby_version": "3.3.0",
  "memory_mb": 42.5,
  "pid": 12345
}
```

In production with `TINA4_DEBUG=false`, create a `.broken` file in the project root to make the health check return a failure status. This is useful for graceful shutdown: set the file, wait for the load balancer to stop sending traffic, then restart the server.

---

## 10. Exercise: Debug a Broken Endpoint

Create a route with an intentional bug and use the dev tools to find and fix it.

### Setup

Create `src/routes/buggy.rb`:

```ruby
Tina4::Router.get("/api/orders/{id:int}/total") do |request, response|
  db = Tina4.database
  id = request.params["id"]

  order = db.fetch_one("SELECT * FROM orders WHERE id = ?", [id])

  # Bug: order might be nil, causing a NoMethodError
  items = db.fetch("SELECT * FROM order_items WHERE order_id = ?", [order["id"]])

  total = items.sum { |item| item["price"] * item["quantity"] }

  response.json({ order_id: id, total: total, items: items.length })
end
```

### Test

```bash
curl http://localhost:7147/api/orders/999/total
```

### Task

1. Visit the dev dashboard and find the error in the request inspector
2. Read the stack trace to identify the bug
3. Fix the nil check
4. Verify the fix works

---

## 11. Solution

The bug is on the line `order["id"]` -- when the order does not exist, `order` is nil, causing a `NoMethodError: undefined method '[]' for nil:NilClass`.

Fix:

```ruby
Tina4::Router.get("/api/orders/{id:int}/total") do |request, response|
  db = Tina4.database
  id = request.params["id"]

  order = db.fetch_one("SELECT * FROM orders WHERE id = ?", [id])

  if order.nil?
    return response.json({ error: "Order not found", id: id }, 404)
  end

  items = db.fetch("SELECT * FROM order_items WHERE order_id = ?", [order["id"]])

  total = items.sum { |item| item["price"] * item["quantity"] }

  response.json({ order_id: id, total: total, items: items.length })
end
```

---

## 12. Gotchas

### 1. Dev Dashboard Accessible on Network

**Problem:** Anyone on your network can access the dev dashboard.

**Fix:** In production, set `TINA4_DEBUG=false` to disable the dashboard entirely. In shared development environments, restrict network access.

### 2. Debug Mode in Production

**Problem:** Stack traces and database queries visible to users.

**Fix:** Always set `TINA4_DEBUG=false` in production to disable the dashboard entirely.

### 3. Log Files Growing Without Bound

**Problem:** `logs/app.log` grows to gigabytes over time.

**Fix:** Use log rotation. Set `TINA4_LOG_MAX_SIZE=10mb` and `TINA4_LOG_MAX_FILES=5` to automatically rotate logs.

### 4. Live Reload Causes Crashes

**Problem:** The server crashes during live reload when a file has syntax errors.

**Fix:** Fix the syntax error and save the file again. The watcher will detect the change and attempt to reload. Check the terminal for the error message.

### 5. Debug Overlay Breaks Page Layout

**Problem:** The debug toolbar interferes with your page's CSS.

**Fix:** The overlay uses isolated CSS with high specificity. If conflicts occur, it is usually because your CSS uses `!important` on body or footer elements. The overlay only appears when `TINA4_DEBUG=true`.

### 6. SQL Runner Allows Destructive Queries

**Problem:** Someone runs `DROP TABLE products` in the SQL runner.

**Fix:** The SQL runner is only available via the dev dashboard when `TINA4_DEBUG=true`. Never leave debug mode on in production. The SQL runner is a power tool for development only.

### 7. Memory Usage Grows During Development

**Problem:** The server's memory usage increases over time during development.

**Fix:** This is normal during live reload -- each reload may not fully release old objects. Restart the server periodically during long development sessions.
