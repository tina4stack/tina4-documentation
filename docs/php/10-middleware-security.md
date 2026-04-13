# Chapter 10: Middleware

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

```bash
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

```bash
TINA4_CORS_ORIGINS=*
```

The default. Do not use `*` in production. Specify your domains.

### CORS Without Middleware

Set `TINA4_CORS_ORIGINS` in `.env` and Tina4 applies CORS headers globally. The middleware approach gives finer control -- CORS on specific groups, none on internal routes.

---

## 4. Built-in RateLimiter

Prevents a single client from flooding your API. Tracks requests per IP. Returns `429 Too Many Requests` when exceeded.

Configure in `.env`:

```bash
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

```bash
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

```bash
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

```bash
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

```bash
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

---

# Chapter 10: Security

Every route you write is a door. Chapter 8 gave you locks. Chapter 10 gave you guards. Chapter 9 gave you session keys. This chapter ties them together into a defence that works without thinking about it.

Tina4 ships secure by default. POST routes require authentication. CSRF tokens protect forms. Security headers harden every response. The framework does the boring security work so you focus on building features. But you need to understand what it does — and why — so you don't accidentally undo it.

---

## 1. Secure-by-Default Routing

Every POST, PUT, PATCH, and DELETE route requires a valid `Authorization: Bearer` token. No configuration needed. No method to call. The framework enforces this before your handler runs.

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::post("/api/orders", function (Request $request, Response $response) {
    // This handler ONLY runs if the request carries a valid Bearer token.
    // Without one, the framework returns 401 before your code executes.
    return $response(["created" => true], 201);
});
```

Test it without a token:

```bash
curl -X POST http://localhost:7146/api/orders \
  -H "Content-Type: application/json" \
  -d '{"product": "widget"}'
# 401 Unauthorized
```

Test it with a valid token:

```bash
curl -X POST http://localhost:7146/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -d '{"product": "widget"}'
# 201 Created
```

GET routes are public by default. Anyone can read. Writing requires proof of identity.

### Making a Write Route Public

Some endpoints need to accept unauthenticated writes — webhooks, registration forms, public contact forms. Use `->noAuth()`:

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::post("/api/webhooks/stripe", function (Request $request, Response $response) {
    // No token required. Stripe can POST here freely.
    return $response(["received" => true]);
})->noAuth();
```

### Protecting a GET Route

Admin dashboards, user profiles, account settings — some pages need protection even though they only read data. Use `->secure()`:

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/api/admin/users", function (Request $request, Response $response) {
    // Requires a valid Bearer token, even though it's a GET.
    return $response(["users" => []]);
})->secure();
```

### The Rule

| Method | Default | Override |
|--------|---------|----------|
| GET, HEAD, OPTIONS | Public | `->secure()` to protect |
| POST, PUT, PATCH, DELETE | Auth required | `->noAuth()` to open |

Two methods. One rule. No surprises.

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

1. **Request body** — `$request->body["formToken"]`
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
2. **Routes with `->noAuth()`** — Public write endpoints don't need CSRF (they have no session to protect).
3. **Requests with a valid Bearer token** — API clients authenticate with tokens, not cookies. CSRF only matters for cookie-based sessions.

### Disabling CSRF Globally

For internal microservices behind a firewall — where no browser ever touches the API — you can disable CSRF entirely:

```bash
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

```bash
TINA4_HSTS=31536000
```

This sets a one-year HSTS policy with `includeSubDomains`. Once a browser sees this header, it refuses to connect over HTTP — even if the user types `http://`.

### Customising Headers

Override any header via environment variables:

```bash
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

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;
use Tina4\Auth;

Router::post("/api/login", function (Request $request, Response $response) {
    $email = $request->body["email"] ?? "";
    $password = $request->body["password"] ?? "";

    if (empty($email) || empty($password)) {
        return $response(["error" => "Email and password required"], 400);
    }

    // Look up user (replace with your database query)
    $user = $DBA->fetch(
        "SELECT id, email, password_hash, role FROM users WHERE email = ?",
        [$email]
    )->asObject()[0] ?? null;

    if (!$user) {
        return $response(["error" => "Invalid credentials"], 401);
    }

    // Verify password
    if (!Auth::checkPassword($password, $user->password_hash)) {
        return $response(["error" => "Invalid credentials"], 401);
    }

    // Generate token with user claims
    $secret = $_ENV["SECRET"] ?? getenv("SECRET");
    $token = Auth::getToken([
        "sub" => $user->id,
        "email" => $user->email,
        "role" => $user->role,
    ], $secret);

    // Store user in session
    $request->session->set("user_id", $user->id);
    $request->session->set("email", $user->email);
    $request->session->set("role", $user->role);
    $request->session->save();

    return $response([
        "token" => $token,
        "user" => ["id" => $user->id, "email" => $user->email],
    ]);
})->noAuth();
```

The `->noAuth()` call opens this route to unauthenticated requests. The handler validates credentials and issues a token. The session stores the user identity for server-side lookups.

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

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/dashboard", function (Request $request, Response $response) {
    $userId = $request->session->get("user_id");

    if (!$userId) {
        return $response->redirect("/login");
    }

    return $response->render("dashboard.twig", [
        "email" => $request->session->get("email"),
        "role" => $request->session->get("role"),
    ]);
});
```

### Logout — Destroying the Session

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::post("/api/logout", function (Request $request, Response $response) {
    $request->session->destroy();
    return $response(["logged_out" => true]);
})->noAuth();
```

---

## 7. Handling Expired Sessions

Sessions expire. Tokens expire. The user clicks a link and finds themselves staring at a broken page or a cryptic error. A good security implementation handles expiry gracefully.

### The Pattern: Redirect to Login, Then Back

When a session expires mid-use, the user should:

1. See a login page — not an error.
2. Log in again.
3. Land on the page they were trying to reach — not the home page.

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/account/settings", function (Request $request, Response $response) {
    $userId = $request->session->get("user_id");

    if (!$userId) {
        // Remember where they wanted to go
        $returnUrl = urlencode($request->url);
        return $response->redirect("/login?redirect={$returnUrl}");
    }

    return $response->render("settings.twig", ["user_id" => $userId]);
});
```

The login handler reads the `redirect` parameter after successful authentication:

```php
Router::post("/api/login", function (Request $request, Response $response) {
    // ... validate credentials ...

    $redirectUrl = $request->query["redirect"] ?? "/dashboard";

    return $response([
        "token" => $token,
        "redirect" => $redirectUrl,
    ]);
})->noAuth();
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

```bash
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

```php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;
use Tina4\Middleware;

class LoginRateLimit extends Middleware
{
    public static function beforeRateCheck(Request $request, Response $response): array
    {
        // Custom rate limiter: 5 attempts per 60 seconds for login
        $ip = $request->ip;
        // ... implement per-route rate limiting ...
        return [$request, $response];
    }
}

Router::post("/api/login", function (Request $request, Response $response) {
    // ... login logic ...
})->noAuth()->middleware(LoginRateLimit::class);
```

---

## 9. CORS and Credentials

When your frontend runs on a different origin than your API (common in development), CORS controls whether the browser sends cookies and auth headers.

Tina4 handles CORS automatically. The relevant security settings:

```bash
TINA4_CORS_ORIGINS=*
TINA4_CORS_CREDENTIALS=true
```

Two rules to remember:

1. **`TINA4_CORS_ORIGINS=*` with `TINA4_CORS_CREDENTIALS=true`** is invalid per the CORS spec. Tina4 handles this — when origin is `*`, the credentials header is not sent. But in production, list your actual origins.

2. **Cookies need `SameSite=None; Secure`** for true cross-origin requests. If your API is on `api.example.com` and your frontend is on `app.example.com`, the default `Lax` cookie works because they share the same registrable domain. Different domains need `SameSite=None`.

Production CORS:

```bash
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
- [ ] Login route uses `->noAuth()` and validates credentials before issuing tokens.
- [ ] Session is regenerated after login (prevents session fixation).
- [ ] Passwords are hashed with `Auth::hashPassword()` — never stored in plain text.
- [ ] File uploads are validated and size-limited (`TINA4_MAX_UPLOAD_SIZE`).
- [ ] Rate limiting is active on login and registration routes.
- [ ] Expired sessions redirect to login with a return URL.

---

## Gotchas

### 1. "My POST route returns 401 but I didn't add auth"

**Cause:** Tina4 requires authentication on all write routes by default.

**Fix:** Chain `->noAuth()` on the route definition if the endpoint should be public. Otherwise, send a valid Bearer token with the request.

### 2. "CSRF validation fails on AJAX requests"

**Cause:** The form token is not included in the request.

**Fix:** Send the token as an `X-Form-Token` header. If using `frond.min.js`, call `saveForm()` — it handles tokens automatically.

### 3. "I disabled CSRF but forms still fail"

**Cause:** The route still requires Bearer auth (separate from CSRF). CSRF and auth are independent checks.

**Fix:** Either send a Bearer token or chain `->noAuth()` on the route.

### 4. "My Content-Security-Policy blocks inline scripts"

**Cause:** The default CSP is `default-src 'self'`, which blocks inline `<script>` tags and `onclick` handlers.

**Fix:** Move scripts to external `.js` files (the right approach) or relax the CSP:

```bash
TINA4_CSP=default-src 'self'; script-src 'self' 'unsafe-inline'
```

Prefer external scripts. Inline scripts are an XSS vector.

### 5. "User stays logged in after session expires"

**Cause:** The frontend stores a JWT in localStorage. The token is still valid even after the session is destroyed server-side.

**Fix:** Check the session on every page load. If the session is gone, redirect to login regardless of the token. Tokens authenticate API calls; sessions track server-side state. Both must be valid.

---

## Exercise: Secure Contact Form

Build a public contact form that:

1. Does not require login (`->noAuth()`).
2. Validates CSRF tokens (form includes `{{ form_token() }}`).
3. Rate-limits submissions to 3 per minute per IP.
4. Stores messages in the database.
5. Returns a success message.

### Solution

```php
// src/routes/contact.php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::get("/contact", function (Request $request, Response $response) {
    return $response->render("contact.twig", ["title" => "Contact Us"]);
});

Router::post("/api/contact", function (Request $request, Response $response) {
    $name = trim($request->body["name"] ?? "");
    $email = trim($request->body["email"] ?? "");
    $message = trim($request->body["message"] ?? "");

    if (empty($name) || empty($email) || empty($message)) {
        return $response(["error" => "All fields are required"], 400);
    }

    global $DBA;

    $DBA->exec(
        "INSERT INTO contact_messages (name, email, message) VALUES (?, ?, ?)",
        [$name, $email, $message]
    );
    $DBA->commit();

    return $response(["success" => true, "message" => "Thank you for your message"]);
})->noAuth();
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

The form is public. The CSRF token is present. The `->noAuth()` call opens the route. The middleware validates the token. The database stores the message. The user sees confirmation.

Five moving parts. Zero security holes. The framework handles the rest.
