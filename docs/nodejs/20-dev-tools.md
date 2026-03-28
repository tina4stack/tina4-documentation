# Chapter 18: Dev Tools

## 1. Debugging at 2am

2am. Production monitoring pings you -- a 500 error on checkout. You pull up the dev dashboard. Find the failing request. Full stack trace with source context. Line 47 of `src/routes/checkout.ts` -- a null reference. Add a null check. Push the fix. Back to sleep. Total time: 30 seconds.

Tina4's dev tools are part of the framework from day one. When `TINA4_DEBUG=true`, you get a development dashboard, error overlay, live reload, request inspector, and SQL query runner.

---

## 2. Enabling the Dev Dashboard

```env
TINA4_DEBUG=true
```

Navigate to:

```
http://localhost:7148/__dev
```

No token or additional environment variables are needed -- the dashboard is a dev-only feature that only runs when debug mode is on.

---

## 3. Dashboard Overview

### System Overview

- Framework version, Node.js version, uptime, memory usage
- Database status, connection info
- Environment variables (sensitive values masked)

### Request Inspector

- Recent HTTP requests with method, path, status, duration
- Click any request to see headers, body, database queries, template renders

### Error Log

- Unhandled exceptions with stack traces
- Occurrence counts and timestamps

### Queue Manager

- Queue status: pending, reserved, completed, failed, dead counts
- Recent jobs with status and duration

### WebSocket Monitor

- Active WebSocket connections with metadata
- Message history

### Routes

- All registered routes with methods, paths, middleware, auth status

### Mail

- Intercepted emails with To, Subject, HTML body, attachments

---

## 4. Debug Overlay

When `TINA4_DEBUG=true`, HTML pages show a toolbar at the bottom:

- Request details (method, URL, duration)
- Database queries (with timing)
- Template renders (with timing)
- Session data
- Recent log entries

---

## 5. Live Reload

The dev server watches `src/` for file changes and automatically reloads:

```bash
tina4 serve
```

When you save a `.ts` file in `src/routes/`, the server restarts and your changes are live immediately.

---

## 6. SQL Query Runner

The dev dashboard includes a SQL query runner. Type any SQL query. Execute it against your database. Results appear in the browser:

```sql
SELECT * FROM products WHERE price > 50 ORDER BY name;
```

Results render in a table. Faster than opening a separate database client for quick queries.

---

## 7. Error Pages

In debug mode, errors show a detailed page with:

- The exception message
- The full stack trace with source code context (5 lines above and below)
- Request details (method, URL, headers, body)
- Environment info

In production (`TINA4_DEBUG=false`), errors show a generic "Internal Server Error" page. Custom error pages go in `src/templates/errors/`:

```
src/templates/errors/404.html
src/templates/errors/500.html
```

---

## 8. Logging

```typescript
import { Log } from "tina4-nodejs";

Log.debug("Debug message");
Log.info("Info message");
Log.warning("Warning message");
Log.error("Error message");
```

Log levels are controlled by `TINA4_LOG_LEVEL` in `.env`:

| Level | Shows |
|-------|-------|
| `ALL` | Everything |
| `DEBUG` | Debug and above |
| `INFO` | Info and above |
| `WARNING` | Warning and above |
| `ERROR` | Errors only |
| `NONE` | Nothing |

Logs are written to `logs/app.log` and to stdout.

---

## 9. Health Check

```
http://localhost:7148/health
```

Returns system status: database connectivity, uptime, and version. Your monitoring tools and load balancers hit this endpoint.

---

## 10. Exercise: Explore the Dev Dashboard

1. Enable the dev dashboard
2. Make several requests to different endpoints
3. Inspect a request in the Request Inspector
4. Run a SQL query in the Query Runner
5. Trigger a 404 and inspect the error log
6. Check the queue statistics

---

## 11. Gotchas

### 1. Dashboard Not Available -- Check `TINA4_DEBUG=true` in your `.env`.
### 2. Debug Overlay Shows in Production -- Set `TINA4_DEBUG=false`.
### 3. Debug Mode in Version Control -- Add `.env` to `.gitignore`.
### 4. Live Reload Not Working -- Ensure `tina4 serve` is running (not `npx tsx app.ts`).
### 5. Logs Fill Up Disk -- Set `TINA4_LOG_LEVEL=WARNING` in production.
### 6. SQL Runner in Production -- Never enable the console in production.
### 7. Performance Overhead -- Debug mode adds overhead. Always disable in production.
