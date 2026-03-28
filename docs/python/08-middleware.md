# Chapter 8: Middleware

## 1. The Pipeline Pattern

Every HTTP request passes through a series of gates before reaching your route handler. Rate limiter. Body parser. Auth check. Logger. These gates are middleware -- code that wraps your route handler and runs before, after, or both.

Picture a public API. Every request hits a rate limit check. Some endpoints require an API key. All responses need CORS headers. Errors need logging. Without middleware, that logic lives in every handler. Duplicated. Scattered. Fragile. With middleware, you write it once and attach it where it belongs.

Tina4 Python ships with built-in middleware (CORS, rate limiting) and lets you write your own. This chapter covers both.

---

## 2. Built-In Middleware

Tina4 Python ships with two built-in middleware classes in `tina4_python.core.middleware`: `CorsMiddleware` and `RateLimiter`. Both are configured via environment variables.

### CorsMiddleware

CORS (Cross-Origin Resource Sharing) controls which websites can call your API from a browser. When React at `http://localhost:3000` calls your Tina4 API at `http://localhost:7145`, the browser sends a preflight `OPTIONS` request first. Wrong headers and the browser blocks everything.

Configure via `.env`:

```env
TINA4_CORS_ORIGINS=https://app.example.com,https://admin.example.com
TINA4_CORS_METHODS=GET,POST,PUT,PATCH,DELETE,OPTIONS
TINA4_CORS_HEADERS=Content-Type,Authorization,X-Request-ID
TINA4_CORS_MAX_AGE=86400
TINA4_CORS_CREDENTIALS=true
```

With these settings, only `app.example.com` and `admin.example.com` can make cross-origin requests to your API. The browser automatically handles preflight `OPTIONS` requests.

For development, you can allow all origins:

```env
TINA4_CORS_ORIGINS=*
```

The CORS middleware is active by default. You do not need to register it manually.

You can also use `CorsMiddleware` programmatically in your own middleware:

```python
from tina4_python.core.middleware import CorsMiddleware

cors = CorsMiddleware()

# Check if an origin is allowed
allowed = cors.allowed_origin("https://app.example.com")

# Apply CORS headers to a response
cors.apply(request, response)

# Check if this is a preflight request
if cors.is_preflight(request):
    # Handle OPTIONS request
    pass
```

### RateLimiter

The rate limiter prevents abuse by limiting how many requests a single IP can make in a sliding time window. It uses an in-memory store that is thread-safe.

Configure via `.env`:

```env
TINA4_RATE_LIMIT=60
TINA4_RATE_WINDOW=60
```

This allows 60 requests per 60-second window per IP address. When a client exceeds the limit, they receive a `429 Too Many Requests` response with a `Retry-After` header.

Rate limit headers are included in every response:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 57
X-RateLimit-Reset: 60
```

You can use the `RateLimiter` class directly for custom rate limiting logic:

```python
from tina4_python.core.middleware import RateLimiter

limiter = RateLimiter()

allowed, info = limiter.check(request.ip)
if not allowed:
    return response.json({
        "error": "Too many requests",
        "retry_after": info["reset"]
    }, 429)

# Add rate limit headers to the response
limiter.apply_headers(response, info)
```

Like CORS, the rate limiter is active by default based on your `.env` configuration.

---

## 3. Writing Custom Middleware

Tina4 Python supports two styles of middleware: function-based and class-based.

### Function-Based Middleware

A middleware function takes three arguments: `request`, `response`, and `next_handler`. It must return a response.

```python
async def my_middleware(request, response, next_handler):
    # Code that runs BEFORE the route handler
    print("Before handler")

    # Call the next middleware or the route handler
    result = await next_handler(request, response)

    # Code that runs AFTER the route handler
    print("After handler")

    return result
```

### Class-Based Middleware

Class-based middleware uses a naming convention: static methods prefixed with `before_` run before the route handler, and methods prefixed with `after_` run after it. Each method receives `(request, response)` and returns `(request, response)`.

```python
class MyMiddleware:
    @staticmethod
    def before_check(request, response):
        """Runs before the route handler."""
        print("Before handler")
        return request, response

    @staticmethod
    def after_cleanup(request, response):
        """Runs after the route handler."""
        print("After handler")
        return request, response
```

If a `before_*` method returns a response with an error status (>= 400), the route handler is skipped entirely. This is short-circuiting.

### Example: Request Timer (Class-Based)

```python
import time

class TimingMiddleware:
    @staticmethod
    def before_start_timer(request, response):
        request._start_time = time.time()
        return request, response

    @staticmethod
    def after_add_timing(request, response):
        elapsed = time.time() - getattr(request, "_start_time", time.time())
        from tina4_python.core.response import Response
        Response.add_header("X-Response-Time", f"{elapsed:.3f}s")
        return request, response
```

### Example: Request Logger (Function-Based)

```python
from datetime import datetime

async def log_middleware(request, response, next_handler):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {request.method} {request.path}")
    print(f"  Headers: {dict(request.headers)}")

    if request.body:
        print(f"  Body: {request.body}")

    result = await next_handler(request, response)

    print(f"  Status: {result.status_code if hasattr(result, 'status_code') else 'unknown'}")

    return result
```

### Example: Security Headers (Class-Based)

```python
from tina4_python.core.response import Response

class SecurityHeaders:
    @staticmethod
    def after_security(request, response):
        Response.add_header("X-Content-Type-Options", "nosniff")
        Response.add_header("X-Frame-Options", "DENY")
        Response.add_header("X-XSS-Protection", "1; mode=block")
        Response.add_header("Strict-Transport-Security", "max-age=31536000")
        return request, response
```

### Example: JSON Content-Type Enforcer (Function-Based)

```python
async def require_json(request, response, next_handler):
    if request.method in ("POST", "PUT", "PATCH"):
        content_type = request.headers.get("Content-Type", "")
        if "application/json" not in content_type:
            return response.json({
                "error": "Content-Type must be application/json"
            }, 415)

    return await next_handler(request, response)
```

### Example: Request ID (Class-Based)

```python
import secrets

class RequestIdMiddleware:
    @staticmethod
    def before_inject_id(request, response):
        request.request_id = secrets.token_hex(8)
        return request, response

    @staticmethod
    def after_add_header(request, response):
        from tina4_python.core.response import Response
        Response.add_header("X-Request-ID", getattr(request, "request_id", ""))
        return request, response
```

### Example: Input Sanitization (Class-Based)

```python
import html

class InputSanitizer:
    @staticmethod
    def before_sanitize(request, response):
        if request.body and isinstance(request.body, dict):
            request.body = InputSanitizer._sanitize_dict(request.body)
        return request, response

    @staticmethod
    def _sanitize_dict(data):
        sanitized = {}
        for key, value in data.items():
            if isinstance(value, str):
                sanitized[key] = html.escape(value)
            elif isinstance(value, dict):
                sanitized[key] = InputSanitizer._sanitize_dict(value)
            else:
                sanitized[key] = value
        return sanitized
```

---

## 4. The @middleware Decorator

Apply middleware to a single route with the `@middleware` decorator. Both function-based and class-based middleware work:

```python
from tina4_python.core.router import get, post, middleware

# Function-based middleware
@middleware(timer_middleware)
@get("/api/data")
async def get_data(request, response):
    return response.json({"data": [1, 2, 3]})

# Class-based middleware
@middleware(TimingMiddleware)
@get("/api/stats")
async def get_stats(request, response):
    return response.json({"stats": {}})
```

Apply multiple middleware by passing them as separate arguments:

```python
@middleware(RequestIdMiddleware, SecurityHeaders, require_json)
@post("/api/items")
async def create_item(request, response):
    return response.json({"item": request.body}, 201)
```

You can mix function-based and class-based middleware freely. They run in the order you list them. In the example above: `RequestIdMiddleware` runs first (before and after hooks), then `SecurityHeaders`, then `require_json`, then the route handler.

---

## 5. Middleware on Route Groups

Apply middleware to all routes in a group:

```python
from tina4_python.core.router import Router, get, post, middleware

def api_v1():

    @middleware(TimingMiddleware, SecurityHeaders)
    @get("/users")
    async def list_users(request, response):
        return response.json({"users": []})

    @middleware(TimingMiddleware, SecurityHeaders)
    @post("/users")
    async def create_user(request, response):
        return response.json({"created": True}, 201)

    @middleware(TimingMiddleware, SecurityHeaders)
    @get("/products")
    async def list_products(request, response):
        return response.json({"products": []})

Router.group("/api/v1", api_v1, middleware=[TimingMiddleware, SecurityHeaders])
```

Every route inside the group now has `TimingMiddleware` and `SecurityHeaders` applied. You can still add route-specific middleware on top:

```python
def api_v1():

    @get("/public")
    async def public_endpoint(request, response):
        # Only group middleware runs
        return response.json({"public": True})

    @middleware(AuthMiddleware)
    @post("/admin")
    async def admin_endpoint(request, response):
        # Group middleware + AuthMiddleware both run
        return response.json({"admin": True})

Router.group("/api/v1", api_v1, middleware=[RequestIdMiddleware])
```

Group middleware always runs before route-specific middleware. This means authentication checks at the group level cannot be bypassed by individual routes.

---

## 6. Execution Order

Stacked middleware forms a nested pipeline. Requests travel inward. Responses travel outward:

```
Request arrives
  → log_middleware (before)
    → auth_middleware (before)
      → timer_middleware (before)
        → route handler
      → timer_middleware (after)
    → auth_middleware (after)
  → log_middleware (after)
Response sent
```

Each middleware wraps around the next one. The outermost middleware runs first on the way in and last on the way out.

Here is a concrete example showing the order:

```python
async def middleware_a(request, response, next_handler):
    print("A: before")
    result = await next_handler(request, response)
    print("A: after")
    return result

async def middleware_b(request, response, next_handler):
    print("B: before")
    result = await next_handler(request, response)
    print("B: after")
    return result

@get("/test")
@middleware(middleware_a, middleware_b)
async def test(request, response):
    print("Handler")
    return response.json({"ok": True})
```

When you request `/test`, the console shows:

```
A: before
B: before
Handler
B: after
A: after
```

---

## 7. Short-Circuiting

Skip `next_handler` and the chain stops cold. The route handler never runs. This is how blocking middleware works:

```python
async def maintenance_mode(request, response, next_handler):
    import os
    if os.getenv("MAINTENANCE_MODE") == "true":
        return response.json({
            "error": "Service is under maintenance. Please try again later."
        }, 503)

    return await next_handler(request, response)
```

When `MAINTENANCE_MODE=true`, every request gets a 503 response without reaching any route handler.

### Conditional Short-Circuit

```python
async def require_api_key(request, response, next_handler):
    api_key = request.headers.get("X-API-Key", "")

    if not api_key:
        return response.json({"error": "API key required"}, 401)

    # Validate the key against a database or config
    valid_keys = ["key-abc-123", "key-def-456", "key-ghi-789"]
    if api_key not in valid_keys:
        return response.json({"error": "Invalid API key"}, 403)

    # Attach the key info to the request for the handler to use
    request.api_key = api_key

    return await next_handler(request, response)
```

```bash
# No key -- 401
curl http://localhost:7145/api/data
```

```json
{"error":"API key required"}
```

```bash
# Invalid key -- 403
curl http://localhost:7145/api/data -H "X-API-Key: wrong-key"
```

```json
{"error":"Invalid API key"}
```

```bash
# Valid key -- 200
curl http://localhost:7145/api/data -H "X-API-Key: key-abc-123"
```

```json
{"data":[1,2,3]}
```

---

## 8. Modifying Request and Response

Middleware can modify the request before it reaches the handler, and the response before it reaches the client.

### Adding Data to the Request

```python
async def inject_user_agent(request, response, next_handler):
    ua = request.headers.get("User-Agent", "")

    request.is_mobile = "Mobile" in ua or "Android" in ua or "iPhone" in ua
    request.is_bot = "bot" in ua.lower() or "spider" in ua.lower()

    return await next_handler(request, response)
```

Now the route handler can access `request.is_mobile` and `request.is_bot`.

### Modifying the Response

```python
async def add_security_headers(request, response, next_handler):
    result = await next_handler(request, response)

    # Add security headers to every response
    return response.header("X-Content-Type-Options", "nosniff") \
                   .header("X-Frame-Options", "DENY") \
                   .header("X-XSS-Protection", "1; mode=block") \
                   .header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
```

---

## 9. Real-World Example: JWT Authentication Middleware

This class-based middleware verifies JWT tokens on protected routes. It uses the `before_*` / `after_*` convention.

```python
from tina4_python.auth import Auth

class JwtAuthMiddleware:
    @staticmethod
    def before_verify_token(request, response):
        auth_header = request.headers.get("authorization", "")

        if not auth_header or not auth_header.startswith("Bearer "):
            return request, response({"error": "Authorization header required"}, 401)

        token = auth_header[7:]
        payload = Auth.valid_token(token)

        if payload is None:
            return request, response({"error": "Invalid or expired token"}, 401)

        # Attach the decoded payload to the request
        request.user = payload
        return request, response
```

Apply it to a group of protected routes:

```python
from tina4_python.core.router import Router, get, post, middleware

def protected_routes():

    @get("/profile")
    async def get_profile(request, response):
        return response({"user": request.user})

    @post("/settings")
    async def update_settings(request, response):
        user_id = request.user["sub"]
        return response({"updated": True, "user_id": user_id})

Router.group("/api/protected", protected_routes, middleware=[JwtAuthMiddleware])
```

The middleware short-circuits with 401 if the token is missing or invalid. The route handler never runs. If the token is valid, the decoded payload is available as `request.user`.

---

## 10. Real-World Example: API Key Middleware with Database Lookup

```python
from tina4_python.database.connection import Database
from datetime import datetime

async def api_key_middleware(request, response, next_handler):
    api_key = request.headers.get("X-API-Key", "")

    if not api_key:
        return response.json({
            "error": "API key required. Send it in the X-API-Key header."
        }, 401)

    db = Database()
    key_record = db.fetch_one(
        "SELECT id, name, rate_limit, is_active FROM api_keys WHERE key_value = ?",
        [api_key]
    )

    if key_record is None:
        return response.json({"error": "Invalid API key"}, 403)

    if not key_record["is_active"]:
        return response.json({"error": "API key has been deactivated"}, 403)

    # Update last used timestamp
    db.execute(
        "UPDATE api_keys SET last_used_at = ?, request_count = request_count + 1 WHERE id = ?",
        [datetime.now().isoformat(), key_record["id"]]
    )

    # Attach key info to request
    request.api_key_id = key_record["id"]
    request.api_key_name = key_record["name"]

    return await next_handler(request, response)
```

---

## 11. Exercise: Build an API Key Middleware System

Build a complete API key system with key management and usage tracking.

### Requirements

1. Create a migration for an `api_keys` table: `id`, `name`, `key_value` (unique), `is_active` (default true), `rate_limit` (default 100), `request_count` (default 0), `last_used_at`, `created_at`

2. Build these endpoints:

| Method | Path | Middleware | Description |
|--------|------|-----------|-------------|
| `POST` | `/admin/api-keys` | Auth | Create a new API key (generate random key) |
| `GET` | `/admin/api-keys` | Auth | List all API keys with usage stats |
| `DELETE` | `/admin/api-keys/{id:int}` | Auth | Deactivate an API key |
| `GET` | `/api/data` | API Key | Protected endpoint -- requires valid API key |
| `GET` | `/api/status` | API Key | Another protected endpoint |

3. The API key middleware should:
   - Check `X-API-Key` header
   - Validate against the database
   - Reject deactivated keys
   - Track usage (increment count, update last_used_at)
   - Attach key info to the request

### Test with:

```bash
# Create an API key (requires auth token from Chapter 7)
curl -X POST http://localhost:7145/admin/api-keys \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Mobile App"}'

# Use the API key
curl http://localhost:7145/api/data \
  -H "X-API-Key: THE_GENERATED_KEY"

# List keys with stats
curl http://localhost:7145/admin/api-keys \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN"
```

---

## 12. Solution

### Migration

Create `src/migrations/20260322170000_create_api_keys_table.sql`:

```sql
-- UP
CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    key_value TEXT NOT NULL UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    rate_limit INTEGER NOT NULL DEFAULT 100,
    request_count INTEGER NOT NULL DEFAULT 0,
    last_used_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_api_keys_key ON api_keys (key_value);

-- DOWN
DROP INDEX IF EXISTS idx_api_keys_key;
DROP TABLE IF EXISTS api_keys;
```

### Routes

Create `src/routes/api_keys.py`:

```python
from tina4_python.core.router import get, post, delete as delete_route, middleware
from tina4_python.auth import Auth
from tina4_python.database.connection import Database
from datetime import datetime
import secrets


async def auth_middleware(request, response, next_handler):
    auth_header = request.headers.get("Authorization", "")
    if not auth_header or not auth_header.startswith("Bearer "):
        return response.json({"error": "Authorization required"}, 401)

    token = auth_header[7:]
    if not Auth.valid_token(token):
        return response.json({"error": "Invalid or expired token"}, 401)

    request.user = Auth.get_payload(token)
    return await next_handler(request, response)


async def api_key_middleware(request, response, next_handler):
    api_key = request.headers.get("X-API-Key", "")

    if not api_key:
        return response.json({"error": "API key required. Send in X-API-Key header."}, 401)

    db = Database()
    key_record = db.fetch_one(
        "SELECT id, name, is_active FROM api_keys WHERE key_value = ?",
        [api_key]
    )

    if key_record is None:
        return response.json({"error": "Invalid API key"}, 403)

    if not key_record["is_active"]:
        return response.json({"error": "API key has been deactivated"}, 403)

    db.execute(
        "UPDATE api_keys SET last_used_at = ?, request_count = request_count + 1 WHERE id = ?",
        [datetime.now().isoformat(), key_record["id"]]
    )

    request.api_key_id = key_record["id"]
    request.api_key_name = key_record["name"]

    return await next_handler(request, response)


@post("/admin/api-keys")
@middleware(auth_middleware)
async def create_api_key(request, response):
    db = Database()
    name = request.body.get("name", "Unnamed Key")
    key_value = f"tk_{secrets.token_hex(24)}"

    db.execute(
        "INSERT INTO api_keys (name, key_value) VALUES (?, ?)",
        [name, key_value]
    )

    key = db.fetch_one("SELECT * FROM api_keys WHERE id = last_insert_rowid()")

    return response.json({"message": "API key created", "key": key}, 201)


@get("/admin/api-keys")
@middleware(auth_middleware)
async def list_api_keys(request, response):
    db = Database()
    keys = db.fetch("SELECT id, name, key_value, is_active, rate_limit, request_count, last_used_at, created_at FROM api_keys ORDER BY created_at DESC")
    return response.json({"keys": keys, "count": len(keys)})


@delete_route("/admin/api-keys/{id:int}")
@middleware(auth_middleware)
async def deactivate_api_key(request, response):
    db = Database()
    key_id = request.params["id"]

    existing = db.fetch_one("SELECT id FROM api_keys WHERE id = ?", [key_id])
    if existing is None:
        return response.json({"error": "API key not found"}, 404)

    db.execute("UPDATE api_keys SET is_active = 0 WHERE id = ?", [key_id])
    return response.json({"message": "API key deactivated"})


@get("/api/data")
@middleware(api_key_middleware)
async def api_data(request, response):
    return response.json({
        "data": [1, 2, 3, 4, 5],
        "api_key": request.api_key_name
    })


@get("/api/status")
@middleware(api_key_middleware)
async def api_status(request, response):
    return response.json({
        "status": "operational",
        "api_key": request.api_key_name
    })
```

---

## 13. Gotchas

### 1. Forgetting to await next_handler

**Problem:** The route handler never runs, or you get an error about a coroutine object.

**Cause:** You called `next_handler(request, response)` without `await`.

**Fix:** Always use `await next_handler(request, response)`. Since Tina4 Python is async, every middleware and handler must be awaited.

### 2. Middleware modifies response after it is sent

**Problem:** Headers or cookies you add in the "after" phase of middleware do not appear in the response.

**Cause:** The response was already finalized by the route handler.

**Fix:** In the "after" phase, modify the result returned by `next_handler`, not the original `response` object. Some modifications may need to happen in the "before" phase instead.

### 3. Middleware applied to wrong routes

**Problem:** Your API key middleware runs on public routes that should not require a key.

**Cause:** The middleware is applied to the group, and the public route is inside that group.

**Fix:** Move public routes outside the group, or use `@noauth` on specific routes to bypass authentication middleware. For custom middleware like API key checks, you need to handle exemptions manually by checking the path in the middleware.

### 4. Middleware execution order surprises

**Problem:** Your auth check runs after your logging middleware, but you wanted it to run first.

**Cause:** Middleware in `@middleware(a, b, c)` runs in left-to-right order: `a` wraps `b` wraps `c` wraps handler.

**Fix:** Put the middleware you want to run first at the leftmost position: `@middleware(auth_middleware, log_middleware)`.

### 5. Error in middleware breaks the chain

**Problem:** An unhandled exception in middleware causes a 500 error without reaching the route handler.

**Cause:** If middleware throws an exception before calling `next_handler`, no subsequent middleware or the handler runs.

**Fix:** Wrap risky middleware code in try/except and return an appropriate error response instead of letting the exception propagate.

### 6. Database connections in middleware

**Problem:** Opening a database connection in middleware that runs on every request causes connection pool exhaustion.

**Cause:** Each middleware call creates a new `Database()` instance.

**Fix:** Tina4's `Database()` uses connection pooling internally, so this is usually safe. But if you are seeing issues, cache your database lookups (like API keys) in memory with a TTL instead of querying on every request.

### 7. Modifying request in middleware does not persist

**Problem:** You set `request.custom_field = "value"` in middleware, but the route handler does not see it.

**Cause:** In some edge cases, the request object may be copied between middleware stages.

**Fix:** Use `request.custom_field` consistently. If it is not persisting, check that you are modifying the same request object that is passed to `next_handler`. Do not create a new request object.
