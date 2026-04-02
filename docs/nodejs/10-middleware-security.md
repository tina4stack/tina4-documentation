# Chapter 8: Middleware

## 1. The Pipeline Pattern

Every HTTP request passes through a series of gates before reaching your route handler. Rate limiter. Body parser. Auth check. Logger. These gates are middleware -- code that wraps your route handler and runs before, after, or both.

Picture a public API. Every request hits a rate limit check. Some endpoints require an API key. All responses need CORS headers. Errors need logging. Without middleware, that logic lives in every handler. Duplicated. Scattered. Fragile. With middleware, you write it once and attach it where it belongs.

Tina4 Node.js ships with built-in middleware (CORS, rate limiting, request logging, security headers) and lets you write your own. This chapter covers both.

---

## 2. What Middleware Is

Middleware is code that runs before or after your route handler. It sits in the HTTP pipeline between the incoming request and the response. Every request can pass through multiple middleware layers before reaching the handler.

Tina4 Node.js supports two styles of middleware:

**Function-based middleware** receives `req`, `res`, and `next`. Call `next()` to continue. Skip it to short-circuit.

```typescript
function passthrough(req, res, next) {
    next();
}
```

```typescript
async function blockEverything(req, res, next) {
    return res.status(503).json({ error: "Service unavailable" });
}
```

**Class-based middleware** uses naming conventions. Static methods whose names start with `before` run before the handler (via `MiddlewareRunner.runBefore`). Methods starting with `after` run after it (via `MiddlewareRunner.runAfter`). Each method receives `(req, res)` and returns `[req, res]`.

```typescript
class MyMiddleware {
    static beforeCheck(req, res) {
        // Runs before the route handler
        return [req, res];
    }

    static afterCleanup(req, res) {
        // Runs after the route handler
        return [req, res];
    }
}
```

If a `before*` method sets the response status to >= 400, the handler is skipped. This is short-circuiting.

Register class-based middleware globally with `Router.use()`:

```typescript
import { Router, CorsMiddleware, RateLimiterMiddleware, RequestLogger } from "tina4-nodejs";

Router.use(CorsMiddleware);
Router.use(RateLimiterMiddleware);
Router.use(RequestLogger);
```

---

## 3. Built-in CorsMiddleware

CORS (Cross-Origin Resource Sharing) controls which domains can call your API from a browser. When React at `http://localhost:3000` calls your Tina4 API at `http://localhost:7148`, the browser sends a preflight `OPTIONS` request first. Wrong headers and the browser blocks everything.

Tina4 provides both a function-based `cors()` middleware and a class-based `CorsMiddleware`. Configure via `.env`:

```env
TINA4_CORS_ORIGINS=http://localhost:3000,https://myapp.com
TINA4_CORS_METHODS=GET,POST,PUT,PATCH,DELETE,OPTIONS
TINA4_CORS_HEADERS=Content-Type,Authorization,X-Request-ID
TINA4_CORS_MAX_AGE=86400
```

With these settings, only `localhost:3000` and `myapp.com` can make cross-origin requests to your API. The browser handles preflight `OPTIONS` requests on its own.

For development, allow all origins:

```env
TINA4_CORS_ORIGINS=*
```

Apply using the function-based form on a single route:

```typescript
import { Router, cors } from "tina4-nodejs";

Router.get("/api/products", async (req, res) => {
    return res.json({ products: [] });
}, [cors()]);
```

Or apply the class-based form globally via `Router.use()`:

```typescript
Router.use(CorsMiddleware);
```

The CORS middleware is active by default when registered. You do not need to handle preflight requests yourself.

You can also use the `cors()` function programmatically to inspect or apply CORS headers in your own middleware:

```typescript
import { cors } from "tina4-nodejs";

function customCors(req, res, next) {
    const origin = req.headers["origin"] ?? "";

    // Only allow CORS for specific paths
    if (req.url.startsWith("/api/public")) {
        cors()(req, res, next);
        return;
    }

    next();
}
```

Preflight `OPTIONS` requests return `204 No Content` with the correct CORS headers. The browser caches the preflight based on `TINA4_CORS_MAX_AGE`.

---

## 4. Built-in RateLimiterMiddleware

The rate limiter prevents a single client from flooding your API. It uses a sliding-window algorithm that tracks requests per IP in memory. Configure via `.env`:

```env
TINA4_RATE_LIMIT=60
TINA4_RATE_WINDOW=60
```

This allows 60 requests per 60-second window per IP address. Apply it:

```typescript
Router.use(RateLimiterMiddleware);
```

When a client exceeds the limit, they receive a `429 Too Many Requests` response with a `Retry-After` header.

Rate limit headers are included in every response:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 57
X-RateLimit-Reset: 1711113060
Retry-After: 42
```

You can use the `RateLimiterMiddleware` class directly for custom rate limiting logic:

```typescript
import { RateLimiterMiddleware } from "tina4-nodejs";

function customRateLimit(req, res, next) {
    const clientIp = req.socket?.remoteAddress ?? "unknown";
    const result = RateLimiterMiddleware.check(clientIp);

    if (!result.allowed) {
        res({
            error: "Too many requests",
            retry_after: result.reset
        }, 429);
        return;
    }

    res.header("X-RateLimit-Limit", String(result.limit));
    res.header("X-RateLimit-Remaining", String(result.remaining));
    res.header("X-RateLimit-Reset", String(result.reset));

    next();
}
```

Like CORS, the rate limiter is active by default based on your `.env` configuration.

---

## 5. Built-in RequestLogger

The `RequestLogger` middleware logs every request with timing and coloured status codes. It uses two hooks:

- `beforeLog` stamps the start time before the handler runs
- `afterLog` calculates elapsed time and prints a coloured log line

Register it globally:

```typescript
import { Router, RequestLogger } from "tina4-nodejs";

Router.use(RequestLogger);
```

The console output looks like:

```
  200 GET /api/users 12ms
  201 POST /api/products 45ms
  404 GET /api/missing 2ms
```

Green for 2xx, yellow for 3xx, red for 4xx and 5xx.

### Built-in SecurityHeadersMiddleware

The `SecurityHeadersMiddleware` adds standard security headers to every response. Register it globally:

```typescript
import { Router, SecurityHeadersMiddleware } from "tina4-nodejs";

Router.use(SecurityHeadersMiddleware);
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

A common production setup:

```typescript
import { Router, CorsMiddleware, RateLimiterMiddleware, RequestLogger, SecurityHeadersMiddleware } from "tina4-nodejs";

Router.use(CorsMiddleware);
Router.use(RateLimiterMiddleware);
Router.use(RequestLogger);
Router.use(SecurityHeadersMiddleware);
```

Order matters. CORS handles `OPTIONS` preflight first. The rate limiter only counts real requests (not preflight). The logger measures total time including the other middleware. Security headers are added to every response.

---

## 6. Writing Custom Middleware

### Function-Based Middleware

A middleware function takes three arguments: `req`, `res`, and `next`. It must call `next()` to continue the chain or return a response to short-circuit.

```typescript
function myMiddleware(req, res, next) {
    // Code that runs BEFORE the route handler
    console.log("Before handler");

    // Call the next middleware or the route handler
    next();

    // Code that runs AFTER the route handler
    console.log("After handler");
}
```

### Class-Based Middleware

Class-based middleware uses a naming convention: static methods prefixed with `before` run before the route handler, and methods prefixed with `after` run after it. Each method receives `(req, res)` and returns `[req, res]`.

```typescript
class MyMiddleware {
    static beforeCheck(req, res) {
        // Runs before the route handler
        console.log("Before handler");
        return [req, res];
    }

    static afterCleanup(req, res) {
        // Runs after the route handler
        console.log("After handler");
        return [req, res];
    }
}
```

If a `before*` method sets the response status to >= 400, the route handler is skipped. This is short-circuiting.

### Example: Request Timer (Class-Based)

```typescript
class TimingMiddleware {
    static beforeStartTimer(req, res) {
        (req as any).startTime = Date.now();
        return [req, res];
    }

    static afterAddTiming(req, res) {
        const elapsed = Date.now() - ((req as any).startTime ?? Date.now());
        res.header("X-Response-Time", `${elapsed}ms`);
        return [req, res];
    }
}
```

### Example: Request Logger (Function-Based)

```typescript
function logMiddleware(req, res, next) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.url}`);
    console.log(`  Headers: ${JSON.stringify(req.headers)}`);

    if (req.body) {
        console.log(`  Body: ${JSON.stringify(req.body)}`);
    }

    const start = Date.now();
    next();
    const duration = Date.now() - start;

    console.log(`  Completed in ${duration}ms`);
}
```

### Example: Security Headers (Class-Based)

```typescript
class CustomSecurityHeaders {
    static afterSecurity(req, res) {
        res.header("X-Content-Type-Options", "nosniff");
        res.header("X-Frame-Options", "DENY");
        res.header("X-XSS-Protection", "1; mode=block");
        res.header("Strict-Transport-Security", "max-age=31536000");
        return [req, res];
    }
}
```

### Example: JSON Content-Type Enforcer (Function-Based)

```typescript
function requireJson(req, res, next) {
    if (["POST", "PUT", "PATCH"].includes(req.method)) {
        const contentType = req.headers["content-type"] ?? "";

        if (!contentType.includes("application/json")) {
            res({
                error: "Content-Type must be application/json",
                received: contentType
            }, 415);
            return;
        }
    }

    next();
}
```

### Example: Request ID (Class-Based)

```typescript
import { randomUUID } from "crypto";

class RequestIdMiddleware {
    static beforeInjectId(req, res) {
        (req as any).requestId = randomUUID();
        return [req, res];
    }

    static afterAddHeader(req, res) {
        res.header("X-Request-ID", (req as any).requestId);
        return [req, res];
    }
}
```

### Example: Input Sanitization (Class-Based)

```typescript
class InputSanitizer {
    static beforeSanitize(req, res) {
        if (req.body && typeof req.body === "object") {
            req.body = InputSanitizer.sanitize(req.body);
        }
        return [req, res];
    }

    private static sanitize(data: Record<string, any>): Record<string, any> {
        const clean: Record<string, any> = {};
        for (const [key, value] of Object.entries(data)) {
            if (typeof value === "string") {
                clean[key] = value.replace(/[<>&"']/g, (c) =>
                    ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", '"': "&quot;", "'": "&#39;" })[c] ?? c
                );
            } else if (typeof value === "object" && value !== null) {
                clean[key] = InputSanitizer.sanitize(value);
            } else {
                clean[key] = value;
            }
        }
        return clean;
    }
}
```

### Example: IP Whitelist (Function-Based)

```typescript
function ipWhitelist(req, res, next) {
    const allowedIps = (process.env.ALLOWED_IPS ?? "127.0.0.1").split(",");
    const clientIp = req.socket?.remoteAddress ?? "";

    if (!allowedIps.includes(clientIp)) {
        res({ error: "Access denied", your_ip: clientIp }, 403);
        return;
    }

    next();
}
```

---

## 7. Applying Middleware to Routes

Apply middleware to a single route by passing an array as the third argument. Both function-based and class-based middleware work:

```typescript
import { Router } from "tina4-nodejs";

// Function-based middleware on a single route
Router.get("/api/data", async (req, res) => {
    return res.json({ data: [1, 2, 3] });
}, [logMiddleware]);

// Class-based middleware on a single route
Router.get("/api/stats", async (req, res) => {
    return res.json({ stats: {} });
}, [TimingMiddleware]);
```

Apply multiple middleware by listing them in the array:

```typescript
Router.post("/api/items", async (req, res) => {
    return res.status(201).json({ item: req.body });
}, [RequestIdMiddleware, CustomSecurityHeaders, requireJson]);
```

You can mix function-based and class-based middleware freely. They run in the order you list them. In the example above: `RequestIdMiddleware` runs first (before and after hooks), then `CustomSecurityHeaders`, then `requireJson`, then the route handler.

---

## 8. Middleware on Route Groups

Apply middleware to all routes in a group:

```typescript
import { Router } from "tina4-nodejs";

Router.group("/api/v1", (group) => {
    group.get("/users", async (req, res) => {
        return res.json({ users: [] });
    });

    group.post("/users", async (req, res) => {
        return res.status(201).json({ created: true });
    });

    group.get("/products", async (req, res) => {
        return res.json({ products: [] });
    });
}, [TimingMiddleware, CustomSecurityHeaders]);
```

Every route inside the group now has `TimingMiddleware` and `CustomSecurityHeaders` applied. You can still add route-specific middleware on top:

```typescript
Router.group("/api/v1", (group) => {
    group.get("/public", async (req, res) => {
        // Only group middleware runs
        return res.json({ public: true });
    });

    group.post("/admin", async (req, res) => {
        // Group middleware + authMiddleware both run
        return res.json({ admin: true });
    }, [authMiddleware]);
}, [RequestIdMiddleware]);
```

Group middleware always runs before route-specific middleware. This means authentication checks at the group level cannot be bypassed by individual routes.

---

## 9. Execution Order

Stacked middleware forms a nested pipeline. Requests travel inward. Responses travel outward:

```
Request arrives
  → logMiddleware (before)
    → authMiddleware (before)
      → timerMiddleware (before)
        → route handler
      → timerMiddleware (after)
    → authMiddleware (after)
  → logMiddleware (after)
Response sent
```

Each middleware wraps around the next one. The outermost middleware runs first on the way in and last on the way out.

Here is a concrete example showing the order:

```typescript
function middlewareA(req, res, next) {
    console.log("A: before");
    next();
    console.log("A: after");
}

function middlewareB(req, res, next) {
    console.log("B: before");
    next();
    console.log("B: after");
}

Router.get("/test", async (req, res) => {
    console.log("Handler");
    return res.json({ ok: true });
}, [middlewareA, middlewareB]);
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

## 10. Short-Circuiting

Skip `next()` and the chain stops cold. The route handler never runs. This is how blocking middleware works:

```typescript
function maintenanceMode(req, res, next) {
    if (process.env.MAINTENANCE_MODE === "true") {
        // Allow health checks through
        if (req.url === "/health") {
            next();
            return;
        }
        res({
            error: "Service is under maintenance. Please try again later.",
            retry_after: 300
        }, 503);
        return;
    }

    next();
}
```

When `MAINTENANCE_MODE=true`, every request gets a 503 response without reaching any route handler. The health check endpoint still works -- a common pattern for load balancers.

### Conditional Short-Circuit

```typescript
function requireApiKey(req, res, next) {
    const apiKey = req.headers["x-api-key"] ?? "";

    if (!apiKey) {
        res({ error: "API key required" }, 401);
        return;
    }

    // Validate the key against a list or database
    const validKeys = ["key-abc-123", "key-def-456", "key-ghi-789"];
    if (!validKeys.includes(apiKey)) {
        res({ error: "Invalid API key" }, 403);
        return;
    }

    // Attach the key info to the request for the handler to use
    (req as any).apiKey = apiKey;

    next();
}
```

```bash
# No key -- 401
curl http://localhost:7148/api/data
```

```json
{"error":"API key required"}
```

```bash
# Invalid key -- 403
curl http://localhost:7148/api/data -H "X-API-Key: wrong-key"
```

```json
{"error":"Invalid API key"}
```

```bash
# Valid key -- 200
curl http://localhost:7148/api/data -H "X-API-Key: key-abc-123"
```

```json
{"data":[1,2,3]}
```

---

## 11. Modifying Request and Response

Middleware can modify the request before it reaches the handler, and the response before it reaches the client.

### Adding Data to the Request

```typescript
function injectUserAgent(req, res, next) {
    const ua = req.headers["user-agent"] ?? "";

    (req as any).isMobile = ua.includes("Mobile") || ua.includes("Android") || ua.includes("iPhone");
    (req as any).isBot = ua.toLowerCase().includes("bot") || ua.toLowerCase().includes("spider");

    next();
}
```

Now the route handler can access `req.isMobile` and `req.isBot`:

```typescript
Router.get("/api/content", async (req, res) => {
    const isMobile = (req as any).isMobile;

    if (isMobile) {
        return res.json({ layout: "compact", images: "low-res" });
    }

    return res.json({ layout: "full", images: "high-res" });
}, [injectUserAgent]);
```

### Modifying the Response

```typescript
function addSecurityHeaders(req, res, next) {
    next();

    // Add security headers to every response after the handler runs
    res.header("X-Content-Type-Options", "nosniff");
    res.header("X-Frame-Options", "DENY");
    res.header("X-XSS-Protection", "1; mode=block");
    res.header("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
}
```

### Adding a Request ID

```typescript
function addRequestId(req, res, next) {
    const { randomUUID } = require("crypto");
    (req as any).requestId = randomUUID();
    res.header("X-Request-Id", (req as any).requestId);
    next();
}
```

The request ID follows the request through every layer. Log it in your handler, return it in error responses, and use it to trace issues across services.

---

## 12. Real-World Example: JWT Authentication Middleware

This class-based middleware verifies JWT tokens on protected routes. It uses the `before*` / `after*` convention.

```typescript
import { Auth } from "tina4-nodejs";

class JwtAuthMiddleware {
    static beforeVerifyToken(req, res) {
        const authHeader = req.headers["authorization"] ?? "";

        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            res(JSON.stringify({ error: "Authorization header required" }), 401);
            return [req, res];
        }

        const token = authHeader.slice(7);
        const secret = process.env.SECRET || "tina4-default-secret";
        const payload = Auth.validToken(token, secret);

        if (!payload) {
            res(JSON.stringify({ error: "Invalid or expired token" }), 401);
            return [req, res];
        }

        // Attach the decoded payload to the request
        (req as any).user = payload;
        return [req, res];
    }
}
```

Apply it to a group of protected routes:

```typescript
import { Router } from "tina4-nodejs";

Router.group("/api/protected", (group) => {
    group.get("/profile", async (req, res) => {
        return res.json({ user: (req as any).user });
    });

    group.post("/settings", async (req, res) => {
        const userId = (req as any).user.sub;
        return res.json({ updated: true, user_id: userId });
    });
}, [JwtAuthMiddleware]);
```

The middleware short-circuits with 401 if the token is missing or invalid. The route handler never runs. If the token is valid, the decoded payload is available as `req.user`.

---

## 13. Real-World Example: API Key Middleware with Database Lookup

```typescript
import { Database } from "tina4-nodejs";

async function apiKeyMiddleware(req, res, next) {
    const apiKey = req.headers["x-api-key"] ?? "";

    if (!apiKey) {
        res({
            error: "API key required. Send it in the X-API-Key header."
        }, 401);
        return;
    }

    const db = new Database();
    const keyRecord = await db.fetchOne(
        "SELECT id, name, rate_limit, is_active FROM api_keys WHERE key_value = ?",
        [apiKey]
    );

    if (!keyRecord) {
        res({ error: "Invalid API key" }, 403);
        return;
    }

    if (!keyRecord.is_active) {
        res({ error: "API key has been deactivated" }, 403);
        return;
    }

    // Update last used timestamp
    await db.execute(
        "UPDATE api_keys SET last_used_at = ?, request_count = request_count + 1 WHERE id = ?",
        [new Date().toISOString(), keyRecord.id]
    );

    // Attach key info to request
    (req as any).apiKeyId = keyRecord.id;
    (req as any).apiKeyName = keyRecord.name;

    next();
}
```

The middleware checks the database on every request. Tina4's `Database` class uses connection pooling internally, so creating a new instance per request is safe. For high-traffic APIs, cache your key lookups in memory with a TTL instead of querying on every request.

---

## 14. Real-World Middleware Stack

```typescript
import { Router } from "tina4-nodejs";

Router.group("/api/v1", (group) => {
    group.get("/products", async (req, res) => {
        return res.json({ products: [
            { id: 1, name: "Widget", price: 9.99 },
            { id: 2, name: "Gadget", price: 19.99 }
        ]});
    });

    group.post("/products", async (req, res) => {
        return res.status(201).json({
            id: 3,
            name: req.body.name ?? "Unknown",
            price: parseFloat(req.body.price ?? 0)
        });
    });
}, [addRequestId, logMiddleware, cors(), requireApiKey]);
```

Four middleware layers. Each does one job. The request ID comes first so every log line and error response includes it. The logger records the request. CORS handles browser preflight. The API key check gates access. The route handler never sees any of that work.

---

## 15. Exercise: Build an API Key Middleware System

Build a complete API key system with key management and usage tracking.

### Requirements

1. Create a migration for an `api_keys` table: `id`, `name`, `key_value` (unique), `is_active` (default true), `rate_limit` (default 100), `request_count` (default 0), `last_used_at`, `created_at`

2. Build these endpoints:

| Method | Path | Middleware | Description |
|--------|------|-----------|-------------|
| `POST` | `/admin/api-keys` | Auth | Create a new API key (generate random key) |
| `GET` | `/admin/api-keys` | Auth | List all API keys with usage stats |
| `DELETE` | `/admin/api-keys/:id` | Auth | Deactivate an API key |
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
curl -X POST http://localhost:7148/admin/api-keys \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Mobile App"}'

# Use the API key
curl http://localhost:7148/api/data \
  -H "X-API-Key: THE_GENERATED_KEY"

# List keys with stats
curl http://localhost:7148/admin/api-keys \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN"
```

---

## 16. Solution

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

Create `src/routes/apiKeys.ts`:

```typescript
import { Router, Auth, Database } from "tina4-nodejs";
import { randomBytes } from "crypto";

async function authMiddleware(req, res, next) {
    const authHeader = req.headers["authorization"] ?? "";
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res({ error: "Authorization required" }, 401);
        return;
    }

    const token = authHeader.slice(7);
    const secret = process.env.SECRET || "tina4-default-secret";
    const payload = Auth.validToken(token, secret);

    if (!payload) {
        res({ error: "Invalid or expired token" }, 401);
        return;
    }

    (req as any).user = payload;
    next();
}

async function apiKeyMiddleware(req, res, next) {
    const apiKey = req.headers["x-api-key"] ?? "";

    if (!apiKey) {
        res({ error: "API key required. Send in X-API-Key header." }, 401);
        return;
    }

    const db = new Database();
    const keyRecord = await db.fetchOne(
        "SELECT id, name, is_active FROM api_keys WHERE key_value = ?",
        [apiKey]
    );

    if (!keyRecord) {
        res({ error: "Invalid API key" }, 403);
        return;
    }

    if (!keyRecord.is_active) {
        res({ error: "API key has been deactivated" }, 403);
        return;
    }

    await db.execute(
        "UPDATE api_keys SET last_used_at = ?, request_count = request_count + 1 WHERE id = ?",
        [new Date().toISOString(), keyRecord.id]
    );

    (req as any).apiKeyId = keyRecord.id;
    (req as any).apiKeyName = keyRecord.name;

    next();
}

// Admin routes -- require auth token
Router.group("/admin", (group) => {
    group.post("/api-keys", async (req, res) => {
        const db = new Database();
        const name = req.body?.name ?? "Unnamed Key";
        const keyValue = `tk_${randomBytes(24).toString("hex")}`;

        await db.execute(
            "INSERT INTO api_keys (name, key_value) VALUES (?, ?)",
            [name, keyValue]
        );

        const key = await db.fetchOne(
            "SELECT * FROM api_keys WHERE key_value = ?",
            [keyValue]
        );

        return res.status(201).json({ message: "API key created", key });
    });

    group.get("/api-keys", async (req, res) => {
        const db = new Database();
        const keys = await db.fetch(
            "SELECT id, name, key_value, is_active, rate_limit, request_count, last_used_at, created_at FROM api_keys ORDER BY created_at DESC"
        );
        return res.json({ keys, count: keys.length });
    });

    group.delete("/api-keys/:id", async (req, res) => {
        const db = new Database();
        const keyId = req.params.id;

        const existing = await db.fetchOne(
            "SELECT id FROM api_keys WHERE id = ?",
            [keyId]
        );

        if (!existing) {
            return res.status(404).json({ error: "API key not found" });
        }

        await db.execute(
            "UPDATE api_keys SET is_active = 0 WHERE id = ?",
            [keyId]
        );

        return res.json({ message: "API key deactivated" });
    });
}, [authMiddleware]);

// Public API routes -- require API key
Router.group("/api", (group) => {
    group.get("/data", async (req, res) => {
        return res.json({
            data: [1, 2, 3, 4, 5],
            api_key: (req as any).apiKeyName
        });
    });

    group.get("/status", async (req, res) => {
        return res.json({
            status: "operational",
            api_key: (req as any).apiKeyName
        });
    });
}, [apiKeyMiddleware]);
```

---

## 17. Gotchas

### 1. Forgetting to Call next()

**Problem:** The route handler never runs. The request hangs or times out.

**Cause:** You forgot to call `next()` after your middleware logic. Without `next()`, the chain stops and the handler never executes.

**Fix:** Always call `next()` to continue the chain. The `next()` function takes no arguments. If you intend to block the request, return a response instead of leaving the request hanging.

### 2. Middleware Modifies Response After It Is Sent

**Problem:** Headers or cookies you add in the "after" phase of middleware do not appear in the response.

**Cause:** The response was already finalized by the route handler. In Node.js, once the response body is sent, headers cannot be modified.

**Fix:** In the "after" phase, modify the result before it reaches the client. Some modifications need to happen in the "before" phase instead. For class-based middleware, the `after*` methods run before the response is finalized, so they can still add headers.

### 3. Middleware Applied to Wrong Routes

**Problem:** Your API key middleware runs on public routes that should not require a key.

**Cause:** The middleware is applied to the group, and the public route is inside that group.

**Fix:** Move public routes outside the group. Or create two groups -- one for public endpoints with no auth middleware, one for protected endpoints with it. For custom middleware, you can also check the path inside the middleware and skip the check for specific routes.

### 4. Middleware Execution Order Surprises

**Problem:** Your auth check runs after your logging middleware, but you wanted it to run first.

**Cause:** Middleware in the array `[a, b, c]` runs in left-to-right order: `a` wraps `b` wraps `c` wraps handler.

**Fix:** Put the middleware you want to run first at the leftmost position: `[authMiddleware, logMiddleware]`.

### 5. Error in Middleware Breaks the Chain

**Problem:** An unhandled exception in middleware causes a 500 error without reaching the route handler.

**Cause:** If middleware throws an exception before calling `next()`, no subsequent middleware or the handler runs.

**Fix:** Wrap risky middleware code in try/catch and return an appropriate error response instead of letting the exception propagate:

```typescript
function safeMiddleware(req, res, next) {
    try {
        // risky operation
        const result = somethingThatMightFail();
        (req as any).result = result;
        next();
    } catch (err) {
        res({ error: "Internal middleware error" }, 500);
    }
}
```

### 6. Database Connections in Middleware

**Problem:** Opening a database connection in middleware that runs on every request causes connection pool exhaustion.

**Cause:** Each middleware call creates a new `Database()` instance.

**Fix:** Tina4's `Database` class uses connection pooling internally, so this is usually safe. But if you see issues under high traffic, cache your database lookups (like API keys) in memory with a TTL instead of querying on every request.

### 7. Modifying Request in Middleware Does Not Persist

**Problem:** You set `req.customField = "value"` in middleware, but the route handler does not see it.

**Cause:** TypeScript's type system does not know about your custom property. In some cases, the request object may be copied between middleware stages.

**Fix:** Use type assertion `(req as any).customField` consistently. If the property is not persisting, check that you are modifying the same request object that is passed to `next()`. Do not create a new request object.

### 8. CORS Preflight Returns 404

**Problem:** The browser sends an `OPTIONS` request and gets a 404, blocking the actual request.

**Cause:** No middleware handles the preflight `OPTIONS` request for that route.

**Fix:** Apply `CorsMiddleware` to the group or globally with `Router.use()`. It handles `OPTIONS` on its own. Make sure CORS middleware is registered before the rate limiter so preflight requests do not count against the rate limit.

### 9. Rate Limiter Counts Preflight Requests

**Problem:** Browsers burn through the rate limit with `OPTIONS` requests before making actual API calls.

**Cause:** The rate limiter runs before the CORS middleware, so it counts preflight requests.

**Fix:** Put `CorsMiddleware` before `RateLimiterMiddleware` in the registration order. CORS handles the preflight and returns early. The rate limiter only sees real requests.

### 10. Middleware File Not Auto-Loaded

**Problem:** You defined middleware in a file, but Tina4 does not recognize it.

**Cause:** The file is not inside the auto-loaded directory.

**Fix:** Put middleware files inside `src/routes/`. Tina4 auto-loads all files in that directory. If you place middleware in a separate folder, import it in a file inside `src/routes/`.

### 11. Short-Circuiting Skips Cleanup

**Problem:** Your timing middleware never logs the "after" phase because an earlier middleware short-circuited the request.

**Cause:** When middleware returns a response without calling `next()`, downstream middleware never runs -- including the "after" hooks of outer middleware.

**Fix:** Put timing and logging middleware at the outermost layer. They wrap everything else, so their "after" code runs regardless of what happens inside.

### 12. Middleware Must Be Passed as Function References

**Problem:** You passed a middleware name as a string and nothing happened.

**Cause:** The middleware array expects function or class references, not strings.

**Fix:** Pass middleware as references in an array: `[myMiddleware]`, not `["myMiddleware"]`. If you use a factory function like `cors()`, call it to get the actual middleware function.

---

# Chapter 10: Security

Every route you write is a door. Chapter 7 gave you locks. Chapter 8 gave you guards. Chapter 9 gave you session keys. This chapter ties them together into a defence that works without thinking about it.

Tina4 ships secure by default. POST routes require authentication. CSRF tokens protect forms. Security headers harden every response. The framework does the boring security work so you focus on building features. But you need to understand what it does — and why — so you don't accidentally undo it.

---

## 1. Secure-by-Default Routing

Every POST, PUT, PATCH, and DELETE route requires a valid `Authorization: Bearer` token. No configuration needed. No export to remember. The framework enforces this before your handler runs.

```typescript
// src/routes/api/orders/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    // This handler ONLY runs if the request carries a valid Bearer token.
    // Without one, the framework returns 401 before your code executes.
    return res.status(201).json({ created: true });
}
```

Test it without a token:

```bash
curl -X POST http://localhost:7148/api/orders \
  -H "Content-Type: application/json" \
  -d '{"product": "widget"}'
# 401 Unauthorized
```

Test it with a valid token:

```bash
curl -X POST http://localhost:7148/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -d '{"product": "widget"}'
# 201 Created
```

GET routes are public by default. Anyone can read. Writing requires proof of identity.

### Making a Write Route Public

Some endpoints need to accept unauthenticated writes — webhooks, registration forms, public contact forms. Export `meta` with `noAuth: true`:

```typescript
// src/routes/api/webhooks/stripe/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    // No token required. Stripe can POST here freely.
    return res.json({ received: true });
}
```

### Protecting a GET Route

Admin dashboards, user profiles, account settings — some pages need protection even though they only read data. Export `meta` with `secured: true`:

```typescript
// src/routes/api/admin/users/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { secured: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    // Requires a valid Bearer token, even though it's a GET.
    return res.json({ users: [] });
}
```

### The Rule

| Method | Default | Override |
|--------|---------|----------|
| GET, HEAD, OPTIONS | Public | `{ secured: true }` to protect |
| POST, PUT, PATCH, DELETE | Auth required | `{ noAuth: true }` to open |

One export. One rule. No surprises.

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

1. **Request body** — `req.body.formToken`
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
2. **Routes with `noAuth: true`** — Public write endpoints don't need CSRF (they have no session to protect).
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

```typescript
// src/routes/api/login/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import { getToken, checkPassword } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    const email: string = req.body.email || "";
    const password: string = req.body.password || "";

    if (!email || !password) {
        return res.status(400).json({ error: "Email and password required" });
    }

    // Look up user (replace with your database query)
    const user = await db.fetchOne(
        "SELECT id, email, password_hash, role FROM users WHERE email = ?",
        [email]
    );

    if (!user) {
        return res.status(401).json({ error: "Invalid credentials" });
    }

    // Verify password
    if (!checkPassword(password, user.password_hash)) {
        return res.status(401).json({ error: "Invalid credentials" });
    }

    // Generate token with user claims
    const secret = process.env.SECRET || "tina4-default-secret";
    const token: string = getToken({
        sub: user.id,
        email: user.email,
        role: user.role,
    }, secret);

    // Store user in session
    req.session.set("user_id", user.id);
    req.session.set("email", user.email);
    req.session.set("role", user.role);

    return res.json({
        token,
        user: { id: user.id, email: user.email },
    });
}
```

The `meta.noAuth` flag opens this route to unauthenticated requests. The handler validates credentials and issues a token. The session stores the user identity for server-side lookups.

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

```typescript
// src/routes/dashboard/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const userId: string | undefined = req.session.get("user_id");

    if (!userId) {
        return res.redirect("/login");
    }

    return res.render("dashboard.twig", {
        email: req.session.get("email"),
        role: req.session.get("role"),
    });
}
```

### Logout — Destroying the Session

```typescript
// src/routes/api/logout/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    req.session.destroy();
    return res.json({ logged_out: true });
}
```

---

## 7. Handling Expired Sessions

Sessions expire. Tokens expire. The user clicks a link and finds themselves staring at a broken page or a cryptic error. A good security implementation handles expiry gracefully.

### The Pattern: Redirect to Login, Then Back

When a session expires mid-use, the user should:

1. See a login page — not an error.
2. Log in again.
3. Land on the page they were trying to reach — not the home page.

```typescript
// src/routes/account/settings/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const userId: string | undefined = req.session.get("user_id");

    if (!userId) {
        // Remember where they wanted to go
        const returnUrl: string = encodeURIComponent(req.url);
        return res.redirect(`/login?redirect=${returnUrl}`);
    }

    return res.render("settings.twig", { user_id: userId });
}
```

The login handler reads the `redirect` parameter after successful authentication:

```typescript
// src/routes/api/login/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import { getToken, checkPassword } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    // ... validate credentials ...

    const redirectUrl: string = req.params.redirect || "/dashboard";

    return res.json({
        token,
        redirect: redirectUrl,
    });
}
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

```typescript
// src/routes/api/login/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import { getToken, checkPassword } from "tina4-nodejs";

export const meta = { noAuth: true };

// Simple in-memory rate limiter for login
const loginAttempts: Map<string, { count: number; resetAt: number }> = new Map();

export default async function (req: Tina4Request, res: Tina4Response) {
    const ip: string = req.ip;
    const now: number = Date.now();
    const windowMs: number = 60_000; // 60 seconds
    const maxAttempts: number = 5;

    // Check rate limit
    const entry = loginAttempts.get(ip);
    if (entry && now < entry.resetAt) {
        if (entry.count >= maxAttempts) {
            const retryAfter: number = Math.ceil((entry.resetAt - now) / 1000);
            return res.status(429).json({
                error: "Too many login attempts",
                retry_after: retryAfter,
            });
        }
        entry.count++;
    } else {
        loginAttempts.set(ip, { count: 1, resetAt: now + windowMs });
    }

    // ... login logic ...
}
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
- [ ] Login route uses `noAuth: true` and validates credentials before issuing tokens.
- [ ] Session is regenerated after login (prevents session fixation).
- [ ] Passwords are hashed with `hashPassword()` — never stored in plain text.
- [ ] File uploads are validated and size-limited (`TINA4_MAX_UPLOAD_SIZE`).
- [ ] Rate limiting is active on login and registration routes.
- [ ] Expired sessions redirect to login with a return URL.

---

## Gotchas

### 1. "My POST route returns 401 but I didn't add auth"

**Cause:** Tina4 requires authentication on all write routes by default.

**Fix:** Export `meta` with `noAuth: true` if the endpoint should be public. Otherwise, send a valid Bearer token with the request.

### 2. "CSRF validation fails on AJAX requests"

**Cause:** The form token is not included in the request.

**Fix:** Send the token as an `X-Form-Token` header. If using `frond.min.js`, call `saveForm()` — it handles tokens automatically.

### 3. "I disabled CSRF but forms still fail"

**Cause:** The route still requires Bearer auth (separate from CSRF). CSRF and auth are independent checks.

**Fix:** Either send a Bearer token or export `meta` with `noAuth: true` on the route.

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

1. Does not require login (`noAuth: true`).
2. Validates CSRF tokens (form includes `{{ form_token() }}`).
3. Rate-limits submissions to 3 per minute per IP.
4. Stores messages in the database.
5. Returns a success message.

### Solution

```typescript
// src/routes/contact/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    return res.render("contact.twig", { title: "Contact Us" });
}
```

```typescript
// src/routes/api/contact/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { noAuth: true };

// Simple in-memory rate limiter for contact submissions
const submissions: Map<string, { count: number; resetAt: number }> = new Map();

export default async function (req: Tina4Request, res: Tina4Response) {
    // Rate limit: 3 submissions per 60 seconds per IP
    const ip: string = req.ip;
    const now: number = Date.now();
    const windowMs: number = 60_000;
    const maxSubmissions: number = 3;

    const entry = submissions.get(ip);
    if (entry && now < entry.resetAt) {
        if (entry.count >= maxSubmissions) {
            return res.status(429).json({ error: "Too many submissions. Try again later." });
        }
        entry.count++;
    } else {
        submissions.set(ip, { count: 1, resetAt: now + windowMs });
    }

    const name: string = (req.body.name || "").trim();
    const email: string = (req.body.email || "").trim();
    const message: string = (req.body.message || "").trim();

    if (!name || !email || !message) {
        return res.status(400).json({ error: "All fields are required" });
    }

    await db.insert("contact_messages", {
        name,
        email,
        message,
    });
    await db.commit();

    return res.json({ success: true, message: "Thank you for your message" });
}
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

The form is public. The CSRF token is present. The `noAuth: true` export opens the route. The middleware validates the token. The database stores the message. The user sees confirmation.

Five moving parts. Zero security holes. The framework handles the rest.
