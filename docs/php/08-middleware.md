# Chapter 8: Middleware

## 1. The Gatekeepers

Your API needs CORS headers for the React frontend, rate limiting for public endpoints, and auth checks for admin routes. You could paste the same 10 lines of CORS code into every handler. You will forget one. You could pile every check into a giant `if` tree. The business logic disappears under boilerplate.

Middleware solves this. Wrap routes with reusable logic. Each middleware does one job -- check a token, set CORS headers, log the request, enforce rate limits -- and the framework decides whether to continue to the next layer. Route handlers stay focused on their purpose.

Chapter 2 introduced middleware briefly. This chapter goes deep: built-in middleware, custom middleware, execution order, short-circuiting, and real-world patterns.

---

## 2. What Middleware Is

Middleware is code that runs before or after your route handler. It sits in the HTTP pipeline between the incoming request and the response. Every request can pass through multiple middleware layers before reaching the handler.

Tina4 PHP supports two styles of middleware:

**Route-level middleware (function-based)** receives `$request` and `$response`. To continue the chain, return nothing (null/void). To short-circuit, return a `Response` object directly. To block with a 403, return `false`.

```php
<?php

// This middleware continues to the next layer (returns nothing)
function passthrough($request, $response) {
    // do something with the request
}
```

```php
<?php

// This middleware short-circuits with a response
function blockUnauthorized($request, $response) {
    if (!$request->bearerToken()) {
        return $response->json(["error" => "Unauthorized"], 401);
    }
    // return nothing to continue
}
```

**Class-based middleware (global)** uses naming conventions. Static methods prefixed with `before` run before the handler. Methods prefixed with `after` run after it. Each method receives `($request, $response)` and returns `[$request, $response]`.

```php
<?php
use Tina4\Request;
use Tina4\Response;

class MyMiddleware
{
    public static function beforeCheck(Request $request, Response $response): array
    {
        // Runs before the route handler
        return [$request, $response];
    }

    public static function afterCleanup(Request $request, Response $response): array
    {
        // Runs after the route handler
        return [$request, $response];
    }
}
```

If a `before*` method sets the response status to >= 400, the handler is skipped (short-circuit).

Register class-based middleware globally with `Middleware::use()`:

```php
<?php
use Tina4\Middleware;
use Tina4\Middleware\CorsMiddleware;
use Tina4\Middleware\RequestLogger;

Middleware::use(CorsMiddleware::class);
Middleware::use(RequestLogger::class);
```

Global middleware runs on every request, in the order registered.

---

## 3. Built-in CorsMiddleware

CORS controls which domains can call your API. When React at `http://localhost:3000` calls your Tina4 API at `http://localhost:7146`, the browser sends a preflight `OPTIONS` request first. Wrong headers: the browser blocks everything.

Tina4 provides `CorsMiddleware`. Configure in `.env`:

```env
TINA4_CORS_ORIGINS=http://localhost:3000,https://myapp.com
TINA4_CORS_METHODS=GET,POST,PUT,PATCH,DELETE,OPTIONS
TINA4_CORS_HEADERS=Content-Type,Authorization,X-API-Key
TINA4_CORS_MAX_AGE=86400
```

Register it globally:

```php
<?php
use Tina4\Middleware;
use Tina4\Middleware\CorsMiddleware;

Middleware::use(CorsMiddleware::class);
```

The `beforeCors` method sets CORS response headers on every request. For `OPTIONS` preflight requests, it sets a 204 status which short-circuits the handler.

Test the preflight:

```bash
curl -X OPTIONS http://localhost:7146/api/products \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization" \
  -v
```

Response headers:

```
Access-Control-Allow-Origin: http://localhost:3000
Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS
Access-Control-Allow-Headers: Content-Type,Authorization,X-API-Key
Access-Control-Max-Age: 86400
```

The `OPTIONS` request returns `204 No Content` with those headers. The browser caches the preflight for 86400 seconds (24 hours). Subsequent requests skip the preflight.

### Wildcard Origins

During development:

```env
TINA4_CORS_ORIGINS=*
```

The default. Do not use `*` in production. Specify your domains.

### CORS Without Middleware

Set `TINA4_CORS_ORIGINS` in `.env` and Tina4 applies CORS headers globally. The middleware approach gives finer control -- CORS on specific groups, none on internal routes.

---

## 4. Built-in RateLimiter

Prevents a single client from flooding your API. Tracks requests per IP. Returns `429 Too Many Requests` when exceeded.

Configure in `.env`:

```env
TINA4_RATE_LIMIT=60
TINA4_RATE_WINDOW=60
```

60 requests per 60 seconds per IP. Register it globally:

```php
<?php
use Tina4\Middleware;
use Tina4\Middleware\RateLimiter;

Middleware::use(RateLimiter::class);
```

When exceeded, the `beforeRateLimit` method sets a 429 status on the response, which short-circuits the handler. The response includes rate limit headers:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
Retry-After: 42
```

### Built-in RequestLogger

The `RequestLogger` middleware logs every request with its timing. It uses two hooks:

- `beforeLog` stamps the start time before the handler runs
- `afterLog` calculates elapsed time and writes an info-level log entry

Register it globally:

```php
<?php
use Tina4\Middleware;
use Tina4\Middleware\RequestLogger;

Middleware::use(RequestLogger::class);
```

The log output looks like:

```
GET /api/users 12.34ms
POST /api/products 45.67ms
```

### Built-in SecurityHeadersMiddleware

The `SecurityHeadersMiddleware` adds standard security headers to every response. Register it globally:

```php
<?php
use Tina4\Middleware;
use Tina4\Middleware\SecurityHeadersMiddleware;

Middleware::use(SecurityHeadersMiddleware::class);
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

```php
<?php
use Tina4\Middleware;
use Tina4\Middleware\CorsMiddleware;
use Tina4\Middleware\RateLimiter;
use Tina4\Middleware\RequestLogger;
use Tina4\Middleware\SecurityHeadersMiddleware;

Middleware::use(CorsMiddleware::class);
Middleware::use(RateLimiter::class);
Middleware::use(RequestLogger::class);
Middleware::use(SecurityHeadersMiddleware::class);
```

Order matters. CORS handles `OPTIONS` preflight first. The rate limiter only counts real requests (not preflight). The logger measures total time including the other middleware. Security headers are added to every response.

---

## 5. Writing Custom Middleware

Route-level middleware functions receive `$request` and `$response`. Return nothing to continue the chain. Return a `Response` to short-circuit. Return `false` to block with 403.

### Request Logging Middleware

```php
<?php

function logRequest($request, $response) {
    $method = $request->method;
    $path = $request->path;
    $ip = $request->ip;

    error_log("[" . date("Y-m-d H:i:s") . "] " . $method . " " . $path . " from " . $ip);
    // return nothing to continue
}
```

Save in `src/routes/middleware.php`. Apply it to a route:

```php
Router::get("/api/products", function ($request, $response) {
    return $response->json(["products" => []]);
})->middleware([function ($request, $response) {
    error_log($request->method . " " . $request->path);
}]);
```

Or apply the named function to a group:

```php
Router::group("/api", function () {
    Router::get("/products", function ($request, $response) {
        return $response->json(["products" => []]);
    });
}, [$logRequest]);
```

Note: `Router::group()` takes an **array** of middleware callables as its third argument.

### IP Whitelist Middleware

```php
<?php

function ipWhitelist($request, $response) {
    $allowedIps = explode(",", $_ENV["ALLOWED_IPS"] ?? "127.0.0.1");

    if (!in_array($request->ip, $allowedIps)) {
        return $response->json([
            "error" => "Access denied",
            "your_ip" => $request->ip
        ], 403);
    }
    // return nothing to continue
}
```

Configure in `.env`:

```env
ALLOWED_IPS=127.0.0.1,10.0.0.5,192.168.1.100
```

When the IP is not in the list, the middleware returns a `Response` object. This short-circuits the chain -- the handler never runs.

### Request Validation Middleware

```php
<?php

function requireJson($request, $response) {
    if (in_array($request->method, ["POST", "PUT", "PATCH"])) {
        $contentType = $request->headers["Content-Type"] ?? "";

        if (strpos($contentType, "application/json") === false) {
            return $response->json([
                "error" => "Content-Type must be application/json",
                "received" => $contentType
            ], 415);
        }
    }
    // return nothing to continue
}
```

Ensures all write requests send JSON. Status: `415 Unsupported Media Type`.

### Writing Class-Based Middleware

For more complex middleware, use the class-based pattern with `before*` and `after*` static methods. This style is for **global** middleware registered via `Middleware::use()`:

```php
<?php
use Tina4\Request;
use Tina4\Response;

class InputSanitizer
{
    public static function beforeSanitize(Request $request, Response $response): array
    {
        if (is_array($request->body)) {
            $request->body = self::sanitize($request->body);
        }
        return [$request, $response];
    }

    private static function sanitize(array $data): array
    {
        $clean = [];
        foreach ($data as $key => $value) {
            if (is_string($value)) {
                $clean[$key] = htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
            } elseif (is_array($value)) {
                $clean[$key] = self::sanitize($value);
            } else {
                $clean[$key] = $value;
            }
        }
        return $clean;
    }
}
```

Register it globally:

```php
Middleware::use(InputSanitizer::class);
```

### JWT Authentication Middleware (Class-Based)

A real-world authentication middleware that verifies JWT tokens:

```php
<?php
use Tina4\Auth;
use Tina4\Request;
use Tina4\Response;

class JwtAuthMiddleware
{
    public static function beforeVerifyToken(Request $request, Response $response): array
    {
        $authHeader = $request->headers["Authorization"] ?? "";

        if (empty($authHeader) || !str_starts_with($authHeader, "Bearer ")) {
            $response->status(401);
            return [$request, $response->json(["error" => "Authorization header required"])];
        }

        $token = substr($authHeader, 7);

        if (!Auth::validToken($token)) {
            $response->status(401);
            return [$request, $response->json(["error" => "Invalid or expired token"])];
        }

        $request->user = Auth::getPayload($token);
        return [$request, $response];
    }
}
```

Register it globally so all routes require authentication:

```php
Middleware::use(JwtAuthMiddleware::class);
```

The middleware short-circuits with 401 if the token is missing or invalid. When `beforeVerifyToken` sets the response status to >= 400, the framework skips the route handler. The decoded payload is available as `$request->user` in the handler.

---

## 6. Applying Middleware to Individual Routes

Use the `->middleware()` method to attach route-level middleware. Pass an array of callables:

```php
<?php
use Tina4\Router;

Router::get("/api/data", function ($request, $response) {
    return $response->json(["data" => [1, 2, 3]]);
})->middleware([function ($request, $response) {
    error_log("Accessing /api/data");
}]);
```

Multiple middleware functions run in listed order:

```php
Router::post("/api/data", function ($request, $response) {
    return $response->json(["created" => true], 201);
})->middleware([$logRequest, $requireJson]);
```

You can also use named functions defined elsewhere:

```php
$checkAuth = function ($request, $response) {
    if (!$request->bearerToken()) {
        return $response->json(["error" => "Unauthorized"], 401);
    }
};

Router::get("/api/secret", function ($request, $response) {
    return $response->json(["secret" => "data"]);
})->middleware([$checkAuth]);
```

---

## 7. Route Groups with Shared Middleware

Groups apply middleware to every route inside. The third argument is an **array** of middleware callables:

```php
<?php
use Tina4\Router;

$checkAuth = function ($request, $response) {
    if (!$request->bearerToken()) {
        return $response->json(["error" => "Unauthorized"], 401);
    }
};

$logRequest = function ($request, $response) {
    error_log($request->method . " " . $request->path);
};

// Public API -- no auth needed
Router::group("/api/public", function () {

    Router::get("/products", function ($request, $response) {
        return $response->json(["products" => []]);
    });

    Router::get("/categories", function ($request, $response) {
        return $response->json(["categories" => []]);
    });

}, [$logRequest]);

// Admin API -- auth required, IP restricted, logged
Router::group("/api/admin", function () {

    Router::get("/users", function ($request, $response) {
        return $response->json(["users" => []]);
    });

    Router::delete("/users/{id:int}", function ($request, $response) {
        $id = $request->params["id"];
        return $response->json(["deleted" => $id]);
    });

}, [$logRequest, $ipWhitelist, $checkAuth]);
```

Routes inside a group can add their own middleware. Group middleware runs first, then route-specific:

```php
Router::group("/api", function () {

    // Execution: $logRequest -> $requireJson -> handler
    Router::post("/upload", function ($request, $response) {
        return $response->json(["uploaded" => true]);
    })->middleware([$requireJson]);

}, [$logRequest]);
```

---

## 8. Middleware Execution Order

Route-level middleware runs in listed order. Each middleware either returns nothing (continue) or returns a `Response` (stop).

```php
<?php

$middlewareA = function ($request, $response) {
    error_log("A: running");
    // returns nothing -- continues to B
};

$middlewareB = function ($request, $response) {
    error_log("B: running");
    // returns nothing -- continues to C
};

$middlewareC = function ($request, $response) {
    error_log("C: running");
    // returns nothing -- continues to handler
};
```

```php
Router::get("/api/test", function ($request, $response) {
    error_log("Handler");
    return $response->json(["ok" => true]);
})->middleware([$middlewareA, $middlewareB, $middlewareC]);
```

Server log:

```
A: running
B: running
C: running
Handler
```

The request flows through the middleware array in order: A, B, C, then the handler.

Placement matters:

- Authentication goes early. Catch unauthorized requests before doing work.
- Validation goes before the handler. Reject bad input early.
- Logging can go first to capture every request, even blocked ones.

### Group + Route Middleware Order

```php
Router::group("/api", function () {

    Router::get("/data", function ($request, $response) {
        return $response->json(["data" => true]);
    })->middleware([$middlewareC]);

}, [$middlewareA, $middlewareB]);
```

Execution: `$middlewareA` -> `$middlewareB` -> `$middlewareC` -> handler. Group middleware always runs before route middleware.

---

## 9. Short-Circuiting

When middleware returns a `Response` object, the chain stops. No subsequent middleware runs. The handler never executes.

### Authentication Short-Circuit

```php
<?php

function requireAuth($request, $response) {
    $token = $request->headers["Authorization"] ?? "";

    if (empty($token)) {
        return $response->json(["error" => "Authentication required"], 401);
    }
    // return nothing to continue
}
```

Missing header: `401` returned. Handler never runs. No database query. No business logic. Resources saved.

### Blocking with false

Returning `false` from middleware tells the framework to respond with a generic `403 Forbidden`:

```php
<?php

function requireAdmin($request, $response) {
    if (!isAdmin($request)) {
        return false; // framework sends 403 Forbidden
    }
    // return nothing to continue
}
```

### Maintenance Mode

```php
<?php

function maintenanceMode($request, $response) {
    $isMaintenanceMode = ($_ENV["MAINTENANCE_MODE"] ?? "false") === "true";

    if ($isMaintenanceMode) {
        return $response->json([
            "error" => "Service is undergoing maintenance",
            "retry_after" => 300
        ], 503);
    }
    // return nothing to continue
}
```

Add to `.env`:

```env
MAINTENANCE_MODE=true
```

Every request gets `503 Service Unavailable`.

### Read-Only Mode

```php
<?php

function readOnly($request, $response) {
    if (in_array($request->method, ["POST", "PUT", "PATCH", "DELETE"])) {
        return $response->json(["error" => "API is in read-only mode"], 405);
    }
    // return nothing to continue
}
```

GET requests pass. Write operations blocked. Useful for standby replicas or demo environments.

---

## 10. Modifying Requests in Middleware

Middleware can attach data to the request before the handler sees it:

```php
<?php
use Tina4\Auth;

function attachUser($request, $response) {
    $authHeader = $request->headers["Authorization"] ?? "";

    if (!empty($authHeader) && str_starts_with($authHeader, "Bearer ")) {
        $token = substr($authHeader, 7);
        if (Auth::validToken($token)) {
            $request->user = Auth::getPayload($token);
        }
    }

    // return nothing -- this middleware does not block
}
```

Different from blocking auth middleware. This attaches user data if present but does not reject unauthenticated requests. Some routes need user data for personalization but remain accessible without it.

### Adding Request Metadata

```php
<?php

function addRequestId($request, $response) {
    $requestId = bin2hex(random_bytes(8));
    $request->requestId = $requestId;
    $response->addHeader("X-Request-Id", $requestId);
    // return nothing to continue
}
```

The handler accesses `$request->requestId` for logging and correlation:

```php
Router::get("/api/data", function ($request, $response) {
    error_log("[" . $request->requestId . "] Processing data request");
    return $response->json(["request_id" => $request->requestId, "data" => []]);
})->middleware([$addRequestId]);
```

---

## 11. Real-World Middleware Stack

A realistic production setup combining global class-based middleware with route-level function middleware:

```php
<?php
use Tina4\Middleware;
use Tina4\Middleware\CorsMiddleware;
use Tina4\Middleware\RateLimiter;
use Tina4\Middleware\RequestLogger;

// Global middleware -- runs on every request
Middleware::use(CorsMiddleware::class);
Middleware::use(RateLimiter::class);
Middleware::use(RequestLogger::class);
```

```php
<?php
use Tina4\Router;

// src/routes/middleware.php

$addRequestId = function ($request, $response) {
    $request->requestId = bin2hex(random_bytes(8));
    $response->addHeader("X-Request-Id", $request->requestId);
};

$requireApiKey = function ($request, $response) {
    $apiKey = $request->headers["X-API-Key"] ?? "";
    $validKeys = explode(",", $_ENV["API_KEYS"] ?? "");

    if (!in_array($apiKey, $validKeys)) {
        return $response->json([
            "error" => "Invalid or missing API key",
            "request_id" => $request->requestId ?? null
        ], 401);
    }
};
```

```php
<?php
use Tina4\Router;

// src/routes/api.php

Router::group("/api/v1", function () {

    Router::get("/products", function ($request, $response) {
        return $response->json(["products" => [
            ["id" => 1, "name" => "Widget", "price" => 9.99],
            ["id" => 2, "name" => "Gadget", "price" => 19.99]
        ]]);
    });

    Router::get("/products/{id:int}", function ($request, $response) {
        $id = $request->params["id"];
        return $response->json(["id" => $id, "name" => "Widget", "price" => 9.99]);
    });

    Router::post("/products", function ($request, $response) {
        $body = $request->body;
        return $response->json([
            "id" => 3,
            "name" => $body["name"] ?? "Unknown",
            "price" => (float) ($body["price"] ?? 0)
        ], 201);
    });

}, [$addRequestId, $requireApiKey]);
```

Without API key:

```json
{"error":"Invalid or missing API key","request_id":"a1b2c3d4e5f6a7b8"}
```

With valid key:

```json
{"products":[{"id":1,"name":"Widget","price":9.99},{"id":2,"name":"Gadget","price":19.99}]}
```

---

## 12. Exercise: Build an API Key Middleware

Build API key middleware:

1. Check for `X-API-Key` header
2. Validate against a comma-separated list in `API_KEYS` env variable
3. Missing key: `401` with `{"error": "API key required"}`
4. Invalid key: `403` with `{"error": "Invalid API key"}`
5. Valid key: attach to `$request->apiKey` and continue
6. Apply to a group with at least two endpoints

### Setup

```env
API_KEYS=key-alpha-001,key-beta-002,key-gamma-003
```

### Test with:

```bash
# No key -- 401
curl http://localhost:7146/api/partner/data

# Invalid key -- 403
curl http://localhost:7146/api/partner/data \
  -H "X-API-Key: wrong-key"

# Valid key -- 200
curl http://localhost:7146/api/partner/data \
  -H "X-API-Key: key-alpha-001"

# Valid key on another endpoint
curl http://localhost:7146/api/partner/stats \
  -H "X-API-Key: key-beta-002"
```

---

## 13. Solution

Create `src/routes/api-key-middleware.php`:

```php
<?php
use Tina4\Router;

$validateApiKey = function ($request, $response) {
    $apiKey = $request->headers["X-API-Key"] ?? "";

    if (empty($apiKey)) {
        return $response->json(["error" => "API key required"], 401);
    }

    $validKeys = array_map("trim", explode(",", $_ENV["API_KEYS"] ?? ""));

    if (!in_array($apiKey, $validKeys)) {
        return $response->json(["error" => "Invalid API key"], 403);
    }

    $request->apiKey = $apiKey;
    // return nothing to continue
};

Router::group("/api/partner", function () {

    Router::get("/data", function ($request, $response) {
        return $response->json([
            "authenticated_with" => $request->apiKey,
            "data" => [
                ["id" => 1, "value" => "alpha"],
                ["id" => 2, "value" => "beta"]
            ]
        ]);
    });

    Router::get("/stats", function ($request, $response) {
        return $response->json([
            "authenticated_with" => $request->apiKey,
            "stats" => [
                "total_requests" => 1423,
                "avg_response_ms" => 42
            ]
        ]);
    });

}, [$validateApiKey]);
```

**No key:** `401` -- `{"error":"API key required"}`

**Invalid key:** `403` -- `{"error":"Invalid API key"}`

**Valid key:**

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

### 1. Route Middleware Must Be Callable

**Problem:** Passing a string name instead of a callable to `->middleware()` or `Router::group()`.

**Cause:** Route-level middleware expects an array of callable functions (closures or function references), not string names.

**Fix:** Pass callables: `->middleware([$myFunction])` or `->middleware([function ($request, $response) { ... }])`. Use variables holding closures, not strings.

### 2. Returning the Wrong Thing from Middleware

**Problem:** Middleware runs but does not behave as expected -- handler runs when it should be blocked, or chain stops when it should continue.

**Cause:** Confusion about return values. Route-level middleware uses a three-way contract:
- Return nothing (null/void) to continue
- Return a `Response` to short-circuit
- Return `false` to block with 403

**Fix:** To continue, just do not return anything. To block, return `$response->json([...], 401)`. Do not return `true` or other values.

### 3. Middleware Order Matters

**Problem:** Logging middleware does not see the request ID.

**Cause:** `$logRequest` runs before `$addRequestId`.

**Fix:** Put `$addRequestId` first: `[$addRequestId, $logRequest]`. Think: what needs to happen first.

### 4. CORS Preflight Returns 404

**Problem:** Browser `OPTIONS` request gets 404. `GET` and `POST` work with curl.

**Cause:** No `CorsMiddleware` registered. `OPTIONS` is not handled.

**Fix:** Register `Middleware::use(CorsMiddleware::class)`. It handles `OPTIONS` and returns correct CORS headers. Or set `CORS_ORIGINS` in `.env` for global handling.

### 5. Rate Limiter Counts Preflight Requests

**Problem:** Frontend hits rate limit faster than expected. Every `POST` counts as two (OPTIONS + POST).

**Fix:** Register `CorsMiddleware` before `RateLimiter` globally. CORS handles `OPTIONS` and short-circuits with 204. The rate limiter only sees real requests.

### 6. Middleware File Not Auto-Loaded

**Problem:** Middleware variable is undefined when used in a route file.

**Cause:** File is not in `src/routes/`. Tina4 auto-loads `.php` files from that directory only.

**Fix:** Put middleware in `src/routes/middleware.php`. Filename does not matter. Location does.

### 7. Group Middleware Expects an Array

**Problem:** Passing a single callable instead of an array to `Router::group()`.

**Cause:** The third parameter of `Router::group()` is typed as `array $middleware = []`.

**Fix:** Always wrap in an array: `Router::group("/api", $callback, [$myMiddleware])`, not `Router::group("/api", $callback, $myMiddleware)`.

### 8. Mixing Up the Two Middleware Styles

**Problem:** Trying to use a class-based middleware in `->middleware()` or a function in `Middleware::use()`.

**Cause:** The two styles serve different purposes. Route-level middleware (`->middleware()` and `Router::group()`) takes callable functions. Global middleware (`Middleware::use()`) takes class names with `before*`/`after*` static methods.

**Fix:** Use `Middleware::use(MyClass::class)` for class-based global middleware. Use `->middleware([$callable])` for route-level function middleware.
