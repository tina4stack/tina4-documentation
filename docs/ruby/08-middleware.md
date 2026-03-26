# Chapter 8: Middleware

## 1. The Gatekeepers

Your API needs CORS headers for the React frontend. Rate limiting for public endpoints. Auth checking for admin routes. All without cluttering your handlers.

You could copy-paste 10 lines of CORS code into every handler. That breaks the moment you forget one. You could pile all the checks into a giant `if` tree. That buries business logic under boilerplate.

Middleware solves this. Wrap routes with reusable logic that runs before or after the handler. Each middleware does one job -- check a token, set CORS headers, log the request, enforce rate limits -- then passes control to the next layer. Route handlers stay focused on their actual purpose.

Chapter 2 introduced middleware. This chapter goes deep. Built-in middleware. Custom middleware. Execution order. Short-circuiting. Real-world patterns.

---

## 2. What Middleware Is

Middleware is code that runs before or after your route handler. It sits in the HTTP pipeline between the incoming request and the response. Every request can pass through multiple middleware layers before reaching the handler.

Tina4 Ruby supports two styles of middleware:

**Method-based middleware** receives the request, the response, and a `next_handler` callable. Call `next_handler` to continue. Skip it to short-circuit.

```ruby
def passthrough(request, response, next_handler)
  next_handler.call(request, response)
end
```

```ruby
def block_everything(request, response, next_handler)
  response.json({ error: "Service unavailable" }, 503)
end
```

**Class-based middleware** uses naming conventions. Class methods prefixed with `before_` run before the handler. Methods prefixed with `after_` run after it. Each method receives `(request, response)` and returns `[request, response]`.

```ruby
class MyMiddleware
  class << self
    def before_check(request, response)
      # Runs before the route handler
      [request, response]
    end

    def after_cleanup(request, response)
      # Runs after the route handler
      [request, response]
    end
  end
end
```

Register class-based middleware globally with `Middleware.use`:

```ruby
Tina4::Middleware.use(Tina4::CorsClassMiddleware)
Tina4::Middleware.use(Tina4::RateLimiterMiddleware)
Tina4::Middleware.use(Tina4::RequestLoggerMiddleware)
```

If a `before_*` method returns a response with status >= 400, the handler is skipped (short-circuit).

---

## 3. Built-in CorsMiddleware

Cross-Origin Resource Sharing (CORS) is the browser mechanism that controls which domains can call your API. Tina4 provides a built-in `CorsMiddleware` that handles this. Configure it in `.env`:

```env
TINA4_CORS_ORIGINS=http://localhost:3000,https://myapp.com
TINA4_CORS_METHODS=GET,POST,PUT,PATCH,DELETE,OPTIONS
TINA4_CORS_HEADERS=Content-Type,Authorization,Accept
TINA4_CORS_MAX_AGE=86400
TINA4_CORS_CREDENTIALS=true
```

Apply it to a group:

```ruby
Tina4::Router.group("/api", middleware: "CorsMiddleware") do

  Tina4::Router.get("/products") do |request, response|
    response.json({ products: [] })
  end

  Tina4::Router.post("/products") do |request, response|
    response.json({ created: true }, 201)
  end

end
```

---

## 4. Built-in RateLimiter

Rate limiting prevents a single client from overwhelming your API. Configure it in `.env`:

```env
TINA4_RATE_LIMIT=60
TINA4_RATE_WINDOW=60
```

This means 60 requests per 60 seconds per IP. Apply it:

```ruby
Tina4::Router.group("/api/public", middleware: "RateLimiter") do

  Tina4::Router.get("/search") do |request, response|
    q = request.query["q"] || ""
    response.json({ query: q, results: [] })
  end

end
```

When a client exceeds the limit:

```json
{"error":"Rate limit exceeded. Try again in 42 seconds.","retry_after":42}
```

### Custom Limits Per Group

```ruby
# Public endpoints: 30 requests per minute
Tina4::Router.group("/api/public", middleware: "RateLimiter:30") do
  Tina4::Router.get("/search") do |request, response|
    response.json({ results: [] })
  end
end

# Authenticated endpoints: 120 requests per minute
Tina4::Router.group("/api/v1", middleware: ["auth_middleware", "RateLimiter:120"]) do
  Tina4::Router.get("/data") do |request, response|
    response.json({ data: [] })
  end
end
```

### Built-in RequestLoggerMiddleware

The `RequestLoggerMiddleware` logs every request with its timing. It uses two hooks:

- `before_log` stamps the start time before the handler runs
- `after_log` calculates elapsed time and writes a log entry

Register it globally:

```ruby
Tina4::Middleware.use(Tina4::RequestLoggerMiddleware)
```

The log output looks like:

```
[RequestLogger] GET /api/users -> 200 (12.345ms)
[RequestLogger] POST /api/products -> 201 (45.678ms)
```

### Built-in SecurityHeadersMiddleware

The `SecurityHeadersMiddleware` adds standard security headers to every response. Register it globally:

```ruby
Tina4::Middleware.use(Tina4::SecurityHeadersMiddleware)
```

It sets the following headers by default:

| Header | Default Value |
|--------|---------------|
| `X-Frame-Options` | `DENY` |
| `Content-Security-Policy` | `default-src 'self'` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |
| `X-Content-Type-Options` | `nosniff` |

Override any header via environment variables in `.env`:

```env
TINA4_FRAME_OPTIONS=SAMEORIGIN
TINA4_CSP=default-src 'self'; script-src 'self' https://cdn.example.com
TINA4_HSTS=max-age=63072000; includeSubDomains; preload
TINA4_REFERRER_POLICY=no-referrer
TINA4_PERMISSIONS_POLICY=camera=(), microphone=(), geolocation=(self)
```

### Combining All Four Built-In Middleware

A common production setup registers all four globally:

```ruby
Tina4::Middleware.use(Tina4::CorsClassMiddleware)
Tina4::Middleware.use(Tina4::RateLimiterMiddleware)
Tina4::Middleware.use(Tina4::RequestLoggerMiddleware)
Tina4::Middleware.use(Tina4::SecurityHeadersMiddleware)
```

Order matters. CORS handles preflight first. The rate limiter only counts real requests. The logger measures total time including the other middleware. Security headers are added to every response.

---

## 5. Writing Custom Middleware

Custom middleware follows the same pattern. You can write method-based or class-based middleware.

### Request Logging Middleware

```ruby
def log_request(request, response, next_handler)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  method = request.method
  path = request.path
  ip = request.ip

  $stderr.puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{method} #{path} from #{ip}"

  result = next_handler.call(request, response)

  duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  $stderr.puts "  Completed in #{duration}ms"

  result
end
```

### Request Timing Middleware

```ruby
def add_timing(request, response, next_handler)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  result = next_handler.call(request, response)

  duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  response.header("X-Response-Time", "#{duration}ms")

  result
end
```

### IP Whitelist Middleware

```ruby
def ip_whitelist(request, response, next_handler)
  allowed_ips = (ENV["ALLOWED_IPS"] || "127.0.0.1").split(",")

  unless allowed_ips.include?(request.ip)
    return response.json({
      error: "Access denied",
      your_ip: request.ip
    }, 403)
  end

  next_handler.call(request, response)
end
```

### Request Validation Middleware

```ruby
def require_json(request, response, next_handler)
  if %w[POST PUT PATCH].include?(request.method)
    content_type = request.headers["Content-Type"] || ""

    unless content_type.include?("application/json")
      return response.json({
        error: "Content-Type must be application/json",
        received: content_type
      }, 415)
    end
  end

  next_handler.call(request, response)
end
```

### Writing Class-Based Middleware

For middleware that needs both before and after hooks, use the class-based pattern:

```ruby
class InputSanitizer
  class << self
    def before_sanitize(request, response)
      if request.body.is_a?(Hash)
        request.body = sanitize_hash(request.body)
      end
      [request, response]
    end

    private

    def sanitize_hash(data)
      data.transform_values do |value|
        case value
        when String
          CGI.escapeHTML(value)
        when Hash
          sanitize_hash(value)
        else
          value
        end
      end
    end
  end
end
```

Register globally or apply to groups:

```ruby
# Global
Tina4::Middleware.use(InputSanitizer)

# On a specific group
Tina4::Router.group("/api", middleware: "InputSanitizer") do
  # routes here
end
```

### JWT Authentication Middleware (Class-Based)

```ruby
class JwtAuthMiddleware
  class << self
    def before_verify_token(request, response)
      auth_header = request.headers["Authorization"] || ""

      unless auth_header.start_with?("Bearer ")
        response.json({ error: "Authorization header required" }, 401)
        return [request, response]
      end

      token = auth_header[7..]
      payload = Tina4::Auth.valid_token(token)

      if payload.nil?
        response.json({ error: "Invalid or expired token" }, 401)
        return [request, response]
      end

      request.user = payload
      [request, response]
    end
  end
end
```

Apply it to protected routes:

```ruby
Tina4::Router.group("/api/protected", middleware: "JwtAuthMiddleware") do

  Tina4::Router.get("/profile") do |request, response|
    response.json({ user: request.user })
  end

  Tina4::Router.post("/settings") do |request, response|
    user_id = request.user["sub"]
    response.json({ updated: true, user_id: user_id })
  end

end
```

---

## 6. Applying Middleware to Individual Routes

Pass middleware as a keyword argument to any route method:

```ruby
Tina4::Router.get("/api/data", middleware: "log_request") do |request, response|
  response.json({ data: [1, 2, 3] })
end

Tina4::Router.post("/api/data", middleware: ["log_request", "require_json"]) do |request, response|
  response.json({ created: true }, 201)
end
```

For a single middleware, pass a string. For multiple, pass an array. Each middleware runs in the order listed.

---

## 7. Route Groups with Shared Middleware

Groups apply middleware to every route inside them:

```ruby
# Public API -- rate limited, CORS enabled
Tina4::Router.group("/api/public", middleware: ["CorsMiddleware", "RateLimiter:30"]) do

  Tina4::Router.get("/products") do |request, response|
    response.json({ products: [] })
  end

  Tina4::Router.get("/categories") do |request, response|
    response.json({ categories: [] })
  end

end

# Admin API -- auth required, IP restricted, logged
Tina4::Router.group("/api/admin", middleware: ["log_request", "ip_whitelist", "auth_middleware"]) do

  Tina4::Router.get("/users") do |request, response|
    response.json({ users: [] })
  end

  Tina4::Router.delete("/users/{id:int}") do |request, response|
    id = request.params["id"]
    response.json({ deleted: id })
  end

end
```

---

## 8. Middleware Execution Order

When you stack middleware, they execute from outer to inner -- like layers of an onion. The first middleware listed runs first on the way in and last on the way out.

Consider this setup:

```ruby
def middleware_a(request, response, next_handler)
  $stderr.puts "A: before"
  result = next_handler.call(request, response)
  $stderr.puts "A: after"
  result
end

def middleware_b(request, response, next_handler)
  $stderr.puts "B: before"
  result = next_handler.call(request, response)
  $stderr.puts "B: after"
  result
end

def middleware_c(request, response, next_handler)
  $stderr.puts "C: before"
  result = next_handler.call(request, response)
  $stderr.puts "C: after"
  result
end
```

```ruby
Tina4::Router.get("/api/test", middleware: ["middleware_a", "middleware_b", "middleware_c"]) do |request, response|
  $stderr.puts "Handler"
  response.json({ ok: true })
end
```

Server log output:

```
A: before
B: before
C: before
Handler
C: after
B: after
A: after
```

The request flows inward: A, B, C, Handler. The response flows outward: C, B, A.

---

## 9. Short-Circuiting

When middleware does not call `next_handler`, the chain stops. No subsequent middleware runs and the route handler is never called.

### Maintenance Mode

```ruby
def maintenance_mode(request, response, next_handler)
  is_maintenance = (ENV["MAINTENANCE_MODE"] || "false") == "true"

  if is_maintenance
    if request.path == "/health"
      return next_handler.call(request, response)
    end

    return response.json({
      error: "Service is undergoing maintenance",
      retry_after: 300
    }, 503)
  end

  next_handler.call(request, response)
end
```

---

## 10. Modifying Requests in Middleware

Middleware can add data to the request before passing it to the handler:

```ruby
def add_request_id(request, response, next_handler)
  request_id = SecureRandom.hex(8)
  request.request_id = request_id

  result = next_handler.call(request, response)

  response.header("X-Request-Id", request_id)

  result
end
```

---

## 11. Real-World Middleware Stack

Here is a realistic middleware setup for a production API:

```ruby
# src/routes/middleware.rb

def add_request_id(request, response, next_handler)
  request.request_id = SecureRandom.hex(8)
  result = next_handler.call(request, response)
  response.header("X-Request-Id", request.request_id)
  result
end

def log_request(request, response, next_handler)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  $stderr.puts "[#{request.request_id}] #{request.method} #{request.path}"

  result = next_handler.call(request, response)

  duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  $stderr.puts "[#{request.request_id}] Completed in #{duration}ms"

  result
end

def require_api_key(request, response, next_handler)
  api_key = request.headers["X-API-Key"] || ""
  valid_keys = (ENV["API_KEYS"] || "").split(",")

  unless valid_keys.include?(api_key)
    return response.json({
      error: "Invalid or missing API key",
      request_id: request.request_id
    }, 401)
  end

  next_handler.call(request, response)
end
```

```ruby
# src/routes/api.rb

Tina4::Router.group("/api/v1", middleware: ["add_request_id", "log_request", "CorsMiddleware", "require_api_key"]) do

  Tina4::Router.get("/products") do |request, response|
    response.json({ products: [
      { id: 1, name: "Widget", price: 9.99 },
      { id: 2, name: "Gadget", price: 19.99 }
    ]})
  end

end
```

---

## 12. Exercise: Build an API Key Middleware

Build a middleware called `validate_api_key` that:

1. Checks for an `X-API-Key` header on every request
2. Validates the key against a comma-separated list stored in the `API_KEYS` environment variable
3. If the key is missing, returns `401` with `{"error": "API key required"}`
4. If the key is invalid, returns `403` with `{"error": "Invalid API key"}`
5. If the key is valid, attaches the key to `request.api_key` and continues
6. Apply this middleware to a route group with at least two endpoints

### Setup

Add this to your `.env`:

```env
API_KEYS=key-alpha-001,key-beta-002,key-gamma-003
```

### Test with:

```bash
# No API key -- should get 401
curl http://localhost:7147/api/partner/data

# Invalid API key -- should get 403
curl http://localhost:7147/api/partner/data \
  -H "X-API-Key: wrong-key"

# Valid API key -- should get 200
curl http://localhost:7147/api/partner/data \
  -H "X-API-Key: key-alpha-001"
```

---

## 13. Solution

Create `src/routes/api_key_middleware.rb`:

```ruby
def validate_api_key(request, response, next_handler)
  api_key = request.headers["X-API-Key"] || ""

  if api_key.empty?
    return response.json({ error: "API key required" }, 401)
  end

  valid_keys = (ENV["API_KEYS"] || "").split(",").map(&:strip)

  unless valid_keys.include?(api_key)
    return response.json({ error: "Invalid API key" }, 403)
  end

  request.api_key = api_key

  next_handler.call(request, response)
end

Tina4::Router.group("/api/partner", middleware: "validate_api_key") do

  Tina4::Router.get("/data") do |request, response|
    response.json({
      authenticated_with: request.api_key,
      data: [
        { id: 1, value: "alpha" },
        { id: 2, value: "beta" }
      ]
    })
  end

  Tina4::Router.get("/stats") do |request, response|
    response.json({
      authenticated_with: request.api_key,
      stats: {
        total_requests: 1423,
        avg_response_ms: 42
      }
    })
  end

end
```

**Expected output -- no key:**

```json
{"error":"API key required"}
```

(Status: `401 Unauthorized`)

**Expected output -- valid key:**

```json
{
  "authenticated_with": "key-alpha-001",
  "data": [
    {"id": 1, "value": "alpha"},
    {"id": 2, "value": "beta"}
  ]
}
```

---

## 14. Gotchas

### 1. Middleware Must Be a Named Method

**Problem:** You pass an anonymous lambda as middleware and get an error.

**Cause:** Tina4 expects middleware to be referenced by a string name, not as an inline block. The string is resolved to a method at runtime.

**Fix:** Define your middleware as a named method: `def my_middleware(request, response, next_handler) ... end` and pass `"my_middleware"` as a string.

### 2. Forgetting to Return next_handler Result

**Problem:** Your middleware runs but the route handler never executes. The response is empty or a 500 error.

**Cause:** You called `next_handler.call(request, response)` but did not return the result.

**Fix:** Always return the result of `next_handler.call(request, response)`. Without the return, the middleware discards the response from the handler and returns `nil`.

### 3. Middleware Order Matters

**Problem:** Your logging middleware does not see the request ID, even though `add_request_id` is in the middleware list.

**Cause:** `log_request` runs before `add_request_id`. Middleware executes in the order listed.

**Fix:** Put `add_request_id` before `log_request` in the array: `["add_request_id", "log_request"]`.

### 4. CORS Preflight Returns 404

**Problem:** The browser's preflight `OPTIONS` request gets a 404, but `GET` and `POST` work fine when tested with curl.

**Cause:** You did not apply `CorsMiddleware` to the route, so the `OPTIONS` method is not handled.

**Fix:** Apply `CorsMiddleware` to the group. It automatically handles `OPTIONS` requests.

### 5. Rate Limiter Counts Preflight Requests

**Problem:** Your frontend hits the rate limit faster than expected because every `POST` request counts as two requests.

**Cause:** The rate limiter counts all requests, including `OPTIONS`.

**Fix:** Put `CorsMiddleware` before `RateLimiter` in the middleware chain.

### 6. Middleware File Not Auto-Loaded

**Problem:** You defined middleware in a file but get "method not found" when referencing it.

**Cause:** The file is not in `src/routes/`. Tina4 auto-loads all `.rb` files in `src/routes/`, but middleware defined outside that directory is not discovered.

**Fix:** Put your middleware methods in a file inside `src/routes/`, such as `src/routes/middleware.rb`.

### 7. Short-Circuiting Skips Cleanup Middleware

**Problem:** Your timing middleware logs the start time but never logs the completion time for blocked requests.

**Cause:** When an inner middleware short-circuits, the outer middleware's code after `next_handler.call` still runs. But if the short-circuiting middleware is listed before the timing middleware, the timing middleware never executes at all.

**Fix:** Put cleanup-dependent middleware (timing, logging) at the outermost layer.
