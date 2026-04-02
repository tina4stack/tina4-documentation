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

---

# Chapter 10: Security

Every route you write is a door. Chapter 7 gave you locks. Chapter 8 gave you guards. Chapter 9 gave you session keys. This chapter ties them together into a defence that works without thinking about it.

Tina4 ships secure by default. POST routes require authentication. CSRF tokens protect forms. Security headers harden every response. The framework does the boring security work so you focus on building features. But you need to understand what it does — and why — so you don't accidentally undo it.

---

## 1. Secure-by-Default Routing

Every POST, PUT, PATCH, and DELETE route requires a valid `Authorization: Bearer` token. No configuration needed. No decorator to remember. The framework enforces this before your handler runs.

```python
from tina4_python.core.router import post

@post("/api/orders")
async def create_order(request, response):
    # This handler ONLY runs if the request carries a valid Bearer token.
    # Without one, the framework returns 401 before your code executes.
    return response({"created": True}, 201)
```

Test it without a token:

```bash
curl -X POST http://localhost:7145/api/orders \
  -H "Content-Type: application/json" \
  -d '{"product": "widget"}'
# 401 Unauthorized
```

Test it with a valid token:

```bash
curl -X POST http://localhost:7145/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -d '{"product": "widget"}'
# 201 Created
```

GET routes are public by default. Anyone can read. Writing requires proof of identity.

### Making a Write Route Public

Some endpoints need to accept unauthenticated writes — webhooks, registration forms, public contact forms. Use `@noauth()`:

```python
from tina4_python.core.router import post, noauth

@noauth()
@post("/api/webhooks/stripe")
async def stripe_webhook(request, response):
    # No token required. Stripe can POST here freely.
    return response({"received": True})
```

### Protecting a GET Route

Admin dashboards, user profiles, account settings — some pages need protection even though they only read data. Use `@secured()`:

```python
from tina4_python.core.router import get, secured

@secured()
@get("/api/admin/users")
async def admin_users(request, response):
    # Requires a valid Bearer token, even though it's a GET.
    return response({"users": []})
```

### The Rule

| Method | Default | Override |
|--------|---------|----------|
| GET, HEAD, OPTIONS | Public | `@secured()` to protect |
| POST, PUT, PATCH, DELETE | Auth required | `@noauth()` to open |

Two decorators. One rule. No surprises.

---

## 2. CSRF Protection

Cross-Site Request Forgery tricks a user's browser into submitting a form to your server. The browser sends cookies automatically — including session cookies. Without CSRF protection, an attacker's page can submit forms as your logged-in user.

Tina4 blocks this with form tokens.

### How It Works

1. Your template renders a hidden token using `{{ form_token() }}`.
2. The browser submits the token with the form data.
3. The `CsrfMiddleware` validates the token before the route handler runs.
4. Invalid or missing tokens receive a `403 Forbidden` response.

### The Template

```twig
<form method="POST" action="/api/profile">
    {{ form_token() }}
    <input type="text" name="name" placeholder="Your name">
    <button type="submit">Save</button>
</form>
```

The `{{ form_token() }}` call generates a hidden input field containing a signed JWT. The token is bound to the current session — a token from one session cannot be used in another.

### The Middleware

CSRF protection is on by default. Every POST, PUT, PATCH, and DELETE request must include a valid form token. The middleware checks two places:

1. **Request body** — `request.body["formToken"]`
2. **Request header** — `X-Form-Token`

If the token is missing or invalid, the middleware returns 403 before your handler runs.

### AJAX Requests

For JavaScript-driven forms, send the token as a header:

```javascript
// frond.min.js handles this automatically via saveForm()
// For manual AJAX, extract the token from the hidden field:
const token = document.querySelector('input[name="formToken"]').value;

fetch("/api/profile", {
    method: "POST",
    headers: {
        "Content-Type": "application/json",
        "X-Form-Token": token
    },
    body: JSON.stringify({ name: "Alice" })
});
```

### Tokens in Query Strings — Blocked

Tokens must never appear in URLs. Query strings are logged in server access logs, browser history, and referrer headers. A token in the URL is a token anyone can steal.

Tina4 rejects any request that carries `formToken` in the query string and logs a warning:

```
CSRF token found in query string — rejected for security.
Use POST body or X-Form-Token header instead.
```

### Skipping CSRF Validation

Three scenarios skip CSRF checks automatically:

1. **GET, HEAD, OPTIONS** — Safe methods don't modify state.
2. **Routes with `@noauth()`** — Public write endpoints don't need CSRF (they have no session to protect).
3. **Requests with a valid Bearer token** — API clients authenticate with tokens, not cookies. CSRF only matters for cookie-based sessions.

### Disabling CSRF Globally

For internal microservices behind a firewall — where no browser ever touches the API — you can disable CSRF entirely:

```env
TINA4_CSRF=false
```

Leave it enabled for anything a browser can reach. The cost is one hidden field per form. The protection is worth it.

---

## 3. Session-Bound Tokens

A form token alone prevents cross-site forgery. But what if someone steals a token from a form? Session binding stops them.

When `{{ form_token() }}` generates a token, it embeds the current session ID in the JWT payload. The CSRF middleware checks that the session ID in the token matches the session ID of the request. A token stolen from one session cannot be replayed in another.

This happens automatically. No configuration. No extra code.

### How Stolen Tokens Fail

1. Attacker visits your site, gets a form token for session `abc-123`.
2. Attacker sends that token from their own session `xyz-789`.
3. The middleware compares: `abc-123 != xyz-789` — rejected with 403.

The token is cryptographically valid. But it belongs to the wrong session. The binding catches it.

---

## 4. Security Headers

Every response from Tina4 carries security headers. The `SecurityHeadersMiddleware` injects them before the response reaches the browser. No opt-in required.

| Header | Default Value | Purpose |
|--------|---------------|---------|
| `X-Frame-Options` | `SAMEORIGIN` | Prevents clickjacking — your pages cannot be embedded in iframes on other domains. |
| `X-Content-Type-Options` | `nosniff` | Stops browsers from guessing content types. A script is a script, not HTML. |
| `Content-Security-Policy` | `default-src 'self'` | Controls which resources the browser loads. Blocks inline scripts from injected HTML. |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limits referrer data sent to external sites. Protects internal URLs from leaking. |
| `X-XSS-Protection` | `0` | Disabled. Modern CSP replaces this legacy header. Keeping it on can introduce vulnerabilities. |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disables browser APIs your app does not need. |

### HSTS — Enforcing HTTPS

Strict Transport Security tells the browser to always use HTTPS. Disabled by default (it breaks local development on HTTP). Enable it in production:

```env
TINA4_HSTS=31536000
```

This sets a one-year HSTS policy with `includeSubDomains`. Once a browser sees this header, it refuses to connect over HTTP — even if the user types `http://`.

### Customising Headers

Override any header via environment variables:

```env
TINA4_FRAME_OPTIONS=DENY
TINA4_CSP=default-src 'self'; script-src 'self' https://cdn.example.com
TINA4_REFERRER_POLICY=no-referrer
TINA4_PERMISSIONS_POLICY=camera=(), microphone=(), geolocation=(), payment=()
```

---

## 5. SameSite Cookies

Session cookies control who can send them. The `SameSite` attribute tells the browser when to include the cookie in requests.

| Value | Behaviour |
|-------|-----------|
| `Strict` | Cookie sent only on same-site requests. Even clicking a link from email to your site won't include the cookie. The user must navigate directly. |
| `Lax` | Cookie sent on same-site requests and top-level navigations (clicking a link). Not sent on cross-site AJAX or form POSTs from other domains. |
| `None` | Cookie sent on all requests, including cross-site. Requires `Secure` flag (HTTPS only). |

Tina4 defaults to `Lax`. This blocks cross-site form submissions (CSRF) while allowing normal link navigation. Users click a link to your site from an email — they stay logged in. An attacker's page submits a hidden form — the cookie is withheld.

For most applications, `Lax` is the right choice. Change it only if you understand the trade-offs.

---

## 6. Login Flow — Complete Example

Authentication, sessions, tokens, and security converge in the login flow. Here is a complete implementation.

### The Login Route

```python
from tina4_python.core.router import post, noauth
from tina4_python.auth import Auth

@noauth()
@post("/api/login")
async def login(request, response):
    email = request.body.get("email", "")
    password = request.body.get("password", "")

    if not email or not password:
        return response({"error": "Email and password required"}, 400)

    # Look up user (replace with your database query)
    user = db.fetch_one(
        "SELECT id, email, password_hash, role FROM users WHERE email = ?",
        [email]
    )

    if not user:
        return response({"error": "Invalid credentials"}, 401)

    # Verify password
    if not Auth.check_password(password, user["password_hash"]):
        return response({"error": "Invalid credentials"}, 401)

    # Generate token with user claims
    token = Auth.get_token(
        {"sub": user["id"], "email": user["email"], "role": user["role"]}
    )

    # Store user in session
    request.session.set("user_id", user["id"])
    request.session.set("email", user["email"])
    request.session.set("role", user["role"])
    request.session.save()

    return response({"token": token, "user": {"id": user["id"], "email": user["email"]}})
```

The `@noauth()` decorator opens this route to unauthenticated requests. The handler validates credentials and issues a token. The session stores the user identity for server-side lookups.

### The Login Form

```twig
{% extends "base.twig" %}
{% block content %}
<div class="container mt-5" style="max-width: 400px;">
    <h2>Login</h2>
    <form id="loginForm">
        {{ form_token() }}
        <div class="mb-3">
            <label for="email">Email</label>
            <input type="email" name="email" id="email" class="form-control"
                   placeholder="you@example.com" required>
        </div>
        <div class="mb-3">
            <label for="password">Password</label>
            <input type="password" name="password" id="password" class="form-control"
                   placeholder="Your password" required>
        </div>
        <button type="button" class="btn btn-primary w-100"
                onclick="saveForm('loginForm', '/api/login', 'loginMsg', handleLogin)">
            Sign In
        </button>
        <div id="loginMsg" class="mt-3"></div>
    </form>
</div>

<script>
function handleLogin(result) {
    if (result.token) {
        localStorage.setItem("token", result.token);
        window.location.href = "/dashboard";
    }
}
</script>
{% endblock %}
```

### Protected Pages — Checking the Session

```python
from tina4_python.core.router import get

@get("/dashboard")
async def dashboard(request, response):
    user_id = request.session.get("user_id")

    if not user_id:
        return response.redirect("/login")

    return response.render("dashboard.twig", {
        "email": request.session.get("email"),
        "role": request.session.get("role"),
    })
```

### Logout — Destroying the Session

```python
from tina4_python.core.router import post, noauth

@noauth()
@post("/api/logout")
async def logout(request, response):
    request.session.destroy()
    return response({"logged_out": True})
```

---

## 7. Handling Expired Sessions

Sessions expire. Tokens expire. The user clicks a link and finds themselves staring at a broken page or a cryptic error. A good security implementation handles expiry gracefully.

### The Pattern: Redirect to Login, Then Back

When a session expires mid-use, the user should:

1. See a login page — not an error.
2. Log in again.
3. Land on the page they were trying to reach — not the home page.

```python
from urllib.parse import quote

@get("/account/settings")
async def account_settings(request, response):
    user_id = request.session.get("user_id")

    if not user_id:
        # Remember where they wanted to go
        return_url = quote(request.url)
        return response.redirect(f"/login?redirect={return_url}")

    return response.render("settings.twig", {"user_id": user_id})
```

The login handler reads the `redirect` parameter after successful authentication:

```python
@noauth()
@post("/api/login")
async def login(request, response):
    # ... validate credentials ...

    redirect_url = request.params.get("redirect", "/dashboard")

    return response({
        "token": token,
        "redirect": redirect_url
    })
```

The login form JavaScript redirects to the saved URL:

```javascript
function handleLogin(result) {
    if (result.token) {
        localStorage.setItem("token", result.token);
        window.location.href = result.redirect || "/dashboard";
    }
}
```

### Token Refresh

Tokens expire based on `TINA4_TOKEN_LIMIT` (default: 60 minutes). The `frond.min.js` frontend library handles token refresh automatically — every response includes a `FreshToken` header with a new token. The client stores it and uses it for the next request.

For custom AJAX code, read the header yourself:

```javascript
const res = await fetch("/api/data", {
    headers: { "Authorization": "Bearer " + localStorage.getItem("token") }
});

const freshToken = res.headers.get("FreshToken");
if (freshToken) {
    localStorage.setItem("token", freshToken);
}
```

---

## 8. Rate Limiting

Brute-force login attempts. Credential stuffing. API abuse. Rate limiting stops all of them.

Tina4 includes a sliding-window rate limiter that tracks requests per IP address. It activates automatically.

```env
TINA4_RATE_LIMIT=100
TINA4_RATE_WINDOW=60
```

One hundred requests per sixty seconds per IP. Exceed the limit and the server returns `429 Too Many Requests` with headers telling the client when to retry:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 45
```

For login routes, consider a stricter limit:

```python
from tina4_python.core.router import post, noauth, middleware

class LoginRateLimit:
    @staticmethod
    def before_rate_check(request, response):
        # Custom rate limiter: 5 attempts per 60 seconds for login
        ip = request.ip
        # ... implement per-route rate limiting ...
        return request, response

@noauth()
@middleware(LoginRateLimit)
@post("/api/login")
async def login(request, response):
    # ... login logic ...
    pass
```

---

## 9. CORS and Credentials

When your frontend runs on a different origin than your API (common in development), CORS controls whether the browser sends cookies and auth headers.

Tina4 handles CORS automatically. The relevant security settings:

```env
TINA4_CORS_ORIGINS=*
TINA4_CORS_CREDENTIALS=true
```

Two rules to remember:

1. **`TINA4_CORS_ORIGINS=*` with `TINA4_CORS_CREDENTIALS=true`** is invalid per the CORS spec. Tina4 handles this — when origin is `*`, the credentials header is not sent. But in production, list your actual origins.

2. **Cookies need `SameSite=None; Secure`** for true cross-origin requests. If your API is on `api.example.com` and your frontend is on `app.example.com`, the default `Lax` cookie works because they share the same registrable domain. Different domains need `SameSite=None`.

Production CORS:

```env
TINA4_CORS_ORIGINS=https://app.example.com,https://admin.example.com
TINA4_CORS_CREDENTIALS=true
```

---

## 10. Security Checklist

Before you deploy, verify:

- [ ] `SECRET` is set to a long, random string — not the default.
- [ ] `TINA4_DEBUG=false` in production.
- [ ] `TINA4_HSTS=31536000` if serving over HTTPS.
- [ ] `TINA4_CORS_ORIGINS` lists your actual domains — not `*`.
- [ ] `TINA4_CSRF=true` (the default) for any browser-facing application.
- [ ] Login route uses `@noauth()` and validates credentials before issuing tokens.
- [ ] Session is regenerated after login (prevents session fixation).
- [ ] Passwords are hashed with `Auth.hash_password()` — never stored in plain text.
- [ ] File uploads are validated and size-limited (`TINA4_MAX_UPLOAD_SIZE`).
- [ ] Rate limiting is active on login and registration routes.
- [ ] Expired sessions redirect to login with a return URL.

---

## Gotchas

### 1. "My POST route returns 401 but I didn't add auth"

**Cause:** Tina4 requires authentication on all write routes by default.

**Fix:** Add `@noauth()` above the route decorator if the endpoint should be public. Otherwise, send a valid Bearer token with the request.

### 2. "CSRF validation fails on AJAX requests"

**Cause:** The form token is not included in the request.

**Fix:** Send the token as an `X-Form-Token` header. If using `frond.min.js`, call `saveForm()` — it handles tokens automatically.

### 3. "I disabled CSRF but forms still fail"

**Cause:** The route still requires Bearer auth (separate from CSRF). CSRF and auth are independent checks.

**Fix:** Either send a Bearer token or add `@noauth()` to the route.

### 4. "My Content-Security-Policy blocks inline scripts"

**Cause:** The default CSP is `default-src 'self'`, which blocks inline `<script>` tags and `onclick` handlers.

**Fix:** Move scripts to external `.js` files (the right approach) or relax the CSP:

```env
TINA4_CSP=default-src 'self'; script-src 'self' 'unsafe-inline'
```

Prefer external scripts. Inline scripts are an XSS vector.

### 5. "User stays logged in after session expires"

**Cause:** The frontend stores a JWT in localStorage. The token is still valid even after the session is destroyed server-side.

**Fix:** Check the session on every page load. If the session is gone, redirect to login regardless of the token. Tokens authenticate API calls; sessions track server-side state. Both must be valid.

---

## Exercise: Secure Contact Form

Build a public contact form that:

1. Does not require login (`@noauth()`).
2. Validates CSRF tokens (form includes `{{ form_token() }}`).
3. Rate-limits submissions to 3 per minute per IP.
4. Stores messages in the database.
5. Returns a success message.

### Solution

```python
# src/routes/contact.py
from tina4_python.core.router import post, get, noauth, template

@template("contact.twig")
@get("/contact")
async def contact_page(request, response):
    return {"title": "Contact Us"}


@noauth()
@post("/api/contact")
async def submit_contact(request, response):
    name = request.body.get("name", "").strip()
    email = request.body.get("email", "").strip()
    message = request.body.get("message", "").strip()

    if not name or not email or not message:
        return response({"error": "All fields are required"}, 400)

    db.insert("contact_messages", {
        "name": name,
        "email": email,
        "message": message,
    })
    db.commit()

    return response({"success": True, "message": "Thank you for your message"})
```

```twig
{# src/templates/contact.twig #}
{% extends "base.twig" %}
{% block title %}Contact Us{% endblock %}
{% block content %}
<div class="container mt-5" style="max-width: 500px;">
    <h2>{{ title }}</h2>
    <form id="contactForm">
        {{ form_token() }}
        <div class="mb-3">
            <label for="name">Name</label>
            <input type="text" name="name" id="name" class="form-control"
                   placeholder="Jane Smith" required>
        </div>
        <div class="mb-3">
            <label for="email">Email</label>
            <input type="email" name="email" id="email" class="form-control"
                   placeholder="jane@example.com" required>
        </div>
        <div class="mb-3">
            <label for="message">Message</label>
            <textarea name="message" id="message" class="form-control" rows="4"
                      placeholder="How can we help?" required></textarea>
        </div>
        <button type="button" class="btn btn-primary"
                onclick="saveForm('contactForm', '/api/contact', 'contactMsg')">
            Send Message
        </button>
        <div id="contactMsg" class="mt-3"></div>
    </form>
</div>
{% endblock %}
```

The form is public. The CSRF token is present. The `@noauth()` decorator opens the route. The middleware validates the token. The database stores the message. The user sees confirmation.

Five moving parts. Zero security holes. The framework handles the rest.
