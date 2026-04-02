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
    q = request.params["q"] || ""
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

---

# Chapter 10: Security

Every route you write is a door. Chapter 7 gave you locks. Chapter 8 gave you guards. Chapter 9 gave you session keys. This chapter ties them together into a defence that works without thinking about it.

Tina4 ships secure by default. POST routes require authentication. CSRF tokens protect forms. Security headers harden every response. The framework does the boring security work so you focus on building features. But you need to understand what it does — and why — so you don't accidentally undo it.

---

## 1. Secure-by-Default Routing

Every POST, PUT, PATCH, and DELETE route requires a valid `Authorization: Bearer` token. No configuration needed. No method call to remember. The framework enforces this before your handler runs.

```ruby
Tina4::Router.post "/api/orders" do |request, response|
  # This handler ONLY runs if the request carries a valid Bearer token.
  # Without one, the framework returns 401 before your code executes.
  response.call({ created: true }, 201)
end
```

Test it without a token:

```bash
curl -X POST http://localhost:7147/api/orders \
  -H "Content-Type: application/json" \
  -d '{"product": "widget"}'
# 401 Unauthorized
```

Test it with a valid token:

```bash
curl -X POST http://localhost:7147/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -d '{"product": "widget"}'
# 201 Created
```

GET routes are public by default. Anyone can read. Writing requires proof of identity.

### Making a Write Route Public

Some endpoints need to accept unauthenticated writes — webhooks, registration forms, public contact forms. Chain `.no_auth`:

```ruby
Tina4::Router.post("/api/webhooks/stripe").no_auth do |request, response|
  # No token required. Stripe can POST here freely.
  response.call({ received: true })
end
```

### Protecting a GET Route

Admin dashboards, user profiles, account settings — some pages need protection even though they only read data. Chain `.secure`:

```ruby
Tina4::Router.get("/api/admin/users").secure do |request, response|
  # Requires a valid Bearer token, even though it's a GET.
  response.call({ users: [] })
end
```

### The Rule

| Method | Default | Override |
|--------|---------|----------|
| GET, HEAD, OPTIONS | Public | `.secure` to protect |
| POST, PUT, PATCH, DELETE | Auth required | `.no_auth` to open |

Two chainable methods. One rule. No surprises.

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
2. **Routes with `.no_auth`** — Public write endpoints don't need CSRF (they have no session to protect).
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

```ruby
Tina4::Router.post("/api/login").no_auth do |request, response|
  email = request.body["email"].to_s.strip
  password = request.body["password"].to_s.strip

  if email.empty? || password.empty?
    return response.call({ error: "Email and password required" }, 400)
  end

  # Look up user (replace with your database query)
  user = db.fetch_one(
    "SELECT id, email, password_hash, role FROM users WHERE email = ?",
    [email]
  )

  if user.nil?
    return response.call({ error: "Invalid credentials" }, 401)
  end

  # Verify password
  unless Tina4::Auth.check_password(password, user["password_hash"])
    return response.call({ error: "Invalid credentials" }, 401)
  end

  # Generate token with user claims
  token = Tina4::Auth.get_token(
    { sub: user["id"], email: user["email"], role: user["role"] }
  )

  # Store user in session
  request.session["user_id"] = user["id"]
  request.session["email"] = user["email"]
  request.session["role"] = user["role"]
  request.session.save

  response.call({ token: token, user: { id: user["id"], email: user["email"] } })
end
```

The `.no_auth` chain opens this route to unauthenticated requests. The handler validates credentials and issues a token. The session stores the user identity for server-side lookups.

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

```ruby
Tina4::Router.get "/dashboard" do |request, response|
  user_id = request.session["user_id"]

  if user_id.nil?
    return response.redirect("/login")
  end

  response.render("dashboard.twig", {
    email: request.session["email"],
    role: request.session["role"]
  })
end
```

### Logout — Destroying the Session

```ruby
Tina4::Router.post("/api/logout").no_auth do |request, response|
  request.session.destroy
  response.call({ logged_out: true })
end
```

---

## 7. Handling Expired Sessions

Sessions expire. Tokens expire. The user clicks a link and finds themselves staring at a broken page or a cryptic error. A good security implementation handles expiry gracefully.

### The Pattern: Redirect to Login, Then Back

When a session expires mid-use, the user should:

1. See a login page — not an error.
2. Log in again.
3. Land on the page they were trying to reach — not the home page.

```ruby
require "cgi"

Tina4::Router.get "/account/settings" do |request, response|
  user_id = request.session["user_id"]

  if user_id.nil?
    # Remember where they wanted to go
    return_url = CGI.escape(request.url)
    return response.redirect("/login?redirect=#{return_url}")
  end

  response.render("settings.twig", { user_id: user_id })
end
```

The login handler reads the `redirect` parameter after successful authentication:

```ruby
Tina4::Router.post("/api/login").no_auth do |request, response|
  # ... validate credentials ...

  redirect_url = request.params["redirect"] || "/dashboard"

  response.call({
    token: token,
    redirect: redirect_url
  })
end
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

```ruby
class LoginRateLimit
  def self.before_rate_check(request, response)
    # Custom rate limiter: 5 attempts per 60 seconds for login
    ip = request.ip
    # ... implement per-route rate limiting ...
    [request, response]
  end
end

Tina4::Router.post("/api/login").no_auth.middleware(LoginRateLimit) do |request, response|
  # ... login logic ...
end
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
- [ ] Login route uses `.no_auth` and validates credentials before issuing tokens.
- [ ] Session is regenerated after login (prevents session fixation).
- [ ] Passwords are hashed with `Tina4::Auth.hash_password()` — never stored in plain text.
- [ ] File uploads are validated and size-limited (`TINA4_MAX_UPLOAD_SIZE`).
- [ ] Rate limiting is active on login and registration routes.
- [ ] Expired sessions redirect to login with a return URL.

---

## Gotchas

### 1. "My POST route returns 401 but I didn't add auth"

**Cause:** Tina4 requires authentication on all write routes by default.

**Fix:** Chain `.no_auth` onto the route definition if the endpoint should be public. Otherwise, send a valid Bearer token with the request.

### 2. "CSRF validation fails on AJAX requests"

**Cause:** The form token is not included in the request.

**Fix:** Send the token as an `X-Form-Token` header. If using `frond.min.js`, call `saveForm()` — it handles tokens automatically.

### 3. "I disabled CSRF but forms still fail"

**Cause:** The route still requires Bearer auth (separate from CSRF). CSRF and auth are independent checks.

**Fix:** Either send a Bearer token or chain `.no_auth` onto the route.

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

1. Does not require login (`.no_auth`).
2. Validates CSRF tokens (form includes `{{ form_token() }}`).
3. Rate-limits submissions to 3 per minute per IP.
4. Stores messages in the database.
5. Returns a success message.

### Solution

```ruby
# src/routes/contact.rb

Tina4::Router.get "/contact" do |request, response|
  response.render("contact.twig", { title: "Contact Us" })
end

Tina4::Router.post("/api/contact").no_auth do |request, response|
  name = request.body["name"].to_s.strip
  email = request.body["email"].to_s.strip
  message = request.body["message"].to_s.strip

  if name.empty? || email.empty? || message.empty?
    return response.call({ error: "All fields are required" }, 400)
  end

  db.insert("contact_messages", {
    name: name,
    email: email,
    message: message
  })

  response.call({ success: true, message: "Thank you for your message" })
end
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

The form is public. The CSRF token is present. The `.no_auth` chain opens the route. The middleware validates the token. The database stores the message. The user sees confirmation.

Five moving parts. Zero security holes. The framework handles the rest.
