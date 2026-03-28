# Chapter 8: Middleware

## 1. The Gatekeepers

Your API needs CORS headers for the React frontend. Rate limiting for the public endpoints. Auth checking for admin routes. All without cluttering route handlers.

Middleware solves this. Each middleware is a gatekeeper. It does one job and passes control to the next layer. Chapter 2 introduced the concept. This chapter goes deep: built-in middleware, custom middleware, execution order, short-circuiting, and real-world patterns.

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

If a `before*` method sets the response status to >= 400, the handler is skipped (short-circuit).

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
TINA4_CORS_HEADERS=Content-Type,Authorization
TINA4_CORS_MAX_AGE=86400
```

For development, allow all origins:

```env
TINA4_CORS_ORIGINS=*
```

Apply using the function-based form:

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

Preflight `OPTIONS` requests return `204 No Content` with the correct CORS headers. The browser caches the preflight based on `TINA4_CORS_MAX_AGE`.

---

## 4. Built-in RateLimiterMiddleware

The rate limiter prevents a single client from flooding your API. It uses a sliding-window algorithm that tracks requests per IP in memory. Configure via `.env`:

```env
TINA4_RATE_LIMIT=60
TINA4_RATE_WINDOW=60
```

60 requests per 60 seconds per IP. Apply it:

```typescript
Router.use(RateLimiterMiddleware);
```

When a client exceeds the limit, they receive a `429 Too Many Requests` response with rate limit headers:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1711113060
Retry-After: 42
```

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

### Request Logging

```typescript
function logRequest(req, res, next) {
    const start = Date.now();
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.socket?.remoteAddress}`);
    next();
    const duration = Date.now() - start;
    console.log(`  Completed in ${duration}ms`);
}
```

### Request Timing

```typescript
function addTiming(req, res, next) {
    const start = Date.now();
    res.raw.on("finish", () => {
        const duration = Date.now() - start;
        res.header("X-Response-Time", `${duration}ms`);
    });
    next();
}
```

### IP Whitelist

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

### Request Validation

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

### Writing Class-Based Middleware

For middleware that needs both before and after hooks, use the class-based pattern with static `before*` and `after*` methods:

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

### JWT Authentication Middleware (Class-Based)

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

        (req as any).user = payload;
        return [req, res];
    }
}
```

Apply it to protected routes:

```typescript
Router.use(JwtAuthMiddleware);
```

### Request ID Middleware (Class-Based)

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

---

## 7. Applying Middleware

Single middleware:

```typescript
Router.get("/api/data", async (req, res) => {
    return res.json({ data: [1, 2, 3] });
}, [logRequest]);
```

Multiple middleware:

```typescript
Router.post("/api/data", async (req, res) => {
    return res.status(201).json({ created: true });
}, [logRequest, requireJson]);
```

---

## 8. Route Groups with Shared Middleware

```typescript
Router.group("/api/public", (group) => {
    group.get("/products", async (req, res) => {
        return res.json({ products: [] });
    });
    group.get("/categories", async (req, res) => {
        return res.json({ categories: [] });
    });
}, [cors()]);

Router.group("/api/admin", (group) => {
    group.get("/users", async (req, res) => {
        return res.json({ users: [] });
    });
}, [logRequest, authMiddleware]);
```

---

## 9. Middleware Execution Order

Middleware executes from outer to inner:

```typescript
Router.get("/api/test", async (req, res) => {
    console.log("Handler");
    return res.json({ ok: true });
}, [middlewareA, middlewareB, middlewareC]);
```

Output:

```
A: before
B: before
C: before
Handler
C: after
B: after
A: after
```

Group middleware always runs before route middleware.

---

## 10. Short-Circuiting

When middleware does not call `next`, the chain dies:

```typescript
function requireAuth(req, res, next) {
    const token = req.headers["authorization"] ?? "";

    if (!token) {
        res({ error: "Authentication required" }, 401);
        return;
    }

    next();
}
```

### Maintenance Mode

```typescript
function maintenanceMode(req, res, next) {
    const isMaintenanceMode = process.env.MAINTENANCE_MODE === "true";

    if (isMaintenanceMode) {
        if (req.path === "/health") {
            next();
            return;
        }
        res({ error: "Service is undergoing maintenance", retry_after: 300 }, 503);
        return;
    }

    next();
}
```

---

## 11. Modifying Requests in Middleware

```typescript
function addRequestId(req, res, next) {
    const { randomUUID } = require("crypto");
    (req as any).requestId = randomUUID();
    res.header("X-Request-Id", (req as any).requestId);
    next();
}
```

---

## 12. Real-World Middleware Stack

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
}, [addRequestId, logRequest, cors(), requireApiKey]);
```

---

## 13. Exercise: Build an API Key Middleware

Build `validateApiKey` middleware that checks `X-API-Key` header against `API_KEYS` env variable.

### Requirements

1. Missing key: return 401 with `{"error": "API key required"}`
2. Invalid key: return 403 with `{"error": "Invalid API key"}`
3. Valid key: attach to `req.apiKey` and continue
4. Apply to a route group with at least two endpoints

---

## 14. Solution

```typescript
import { Router } from "tina4-nodejs";

function validateApiKey(req, res, next) {
    const apiKey = req.headers["x-api-key"] ?? "";

    if (!apiKey) {
        res({ error: "API key required" }, 401);
        return;
    }

    const validKeys = (process.env.API_KEYS ?? "").split(",").map(k => k.trim());

    if (!validKeys.includes(apiKey)) {
        res({ error: "Invalid API key" }, 403);
        return;
    }

    (req as any).apiKey = apiKey;
    next();
}

Router.group("/api/partner", (group) => {
    group.get("/data", async (req, res) => {
        return res.json({
            authenticated_with: (req as any).apiKey,
            data: [{ id: 1, value: "alpha" }, { id: 2, value: "beta" }]
        });
    });

    group.get("/stats", async (req, res) => {
        return res.json({
            authenticated_with: (req as any).apiKey,
            stats: { total_requests: 1423, avg_response_ms: 42 }
        });
    });
}, [validateApiKey]);
```

---

## 15. Gotchas

### 1. Middleware Must Be Passed as Function References

**Fix:** Pass middleware as function references in an array: `[myMiddleware]`, not `"myMiddleware"`.

### 2. Forgetting to Call next()

**Fix:** Always call `next()` to continue the chain. The `next()` function takes no arguments.

### 3. Middleware Order Matters

**Fix:** Put `addRequestId` before `logRequest`: `[addRequestId, logRequest]`.

### 4. CORS Preflight Returns 404

**Fix:** Apply `CorsMiddleware` to the group. It handles `OPTIONS` automatically.

### 5. Rate Limiter Counts Preflight Requests

**Fix:** Put `CorsMiddleware` before `RateLimiter`.

### 6. Middleware File Not Auto-Loaded

**Fix:** Put middleware functions in a file inside `src/routes/`.

### 7. Short-Circuiting Skips Cleanup

**Fix:** Put timing/logging middleware at the outermost layer.
