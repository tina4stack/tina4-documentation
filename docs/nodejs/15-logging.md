# Chapter 15: Structured Logging

## 1. console.log Is Not a Logging Strategy

`console.log("something happened")` tells you nothing. No timestamp. No severity. No context. No way to filter by level in production. No way to ship to a log aggregator. When an incident happens at 2am, you need to know exactly what happened and when.

Structured logging emits machine-readable JSON. Every entry has a timestamp, log level, message, and optional context fields. You can filter, search, and aggregate without grep.

Tina4 provides a `Log` singleton with four severity levels. Zero configuration required. Control verbosity with one environment variable.

---

## 2. The Four Log Levels

```typescript
import { Log } from "tina4-nodejs";

Log.debug("Cache lookup", { key: "product:42", hit: false });
Log.info("User registered", { userId: 99, email: "alice@example.com" });
Log.warn("Rate limit approaching", { ip: "203.0.113.5", requests: 95, limit: 100 });
Log.error("Payment failed", { orderId: 1042, reason: "Card declined" });
```

Each call emits a structured log line:

```json
{"timestamp":"2026-04-02T08:12:01.234Z","level":"DEBUG","message":"Cache lookup","key":"product:42","hit":false}
{"timestamp":"2026-04-02T08:12:01.235Z","level":"INFO","message":"User registered","userId":99,"email":"alice@example.com"}
{"timestamp":"2026-04-02T08:12:01.236Z","level":"WARN","message":"Rate limit approaching","ip":"203.0.113.5","requests":95,"limit":100}
{"timestamp":"2026-04-02T08:12:01.237Z","level":"ERROR","message":"Payment failed","orderId":1042,"reason":"Card declined"}
```

| Level | Use for |
|-------|---------|
| `debug` | Detailed diagnostic info, cache hits/misses, query plans |
| `info` | Normal application events: logins, signups, orders placed |
| `warn` | Unexpected but recoverable situations: retries, slow queries |
| `error` | Failures that need attention: payment errors, crashed workers |

---

## 3. Controlling Verbosity with TINA4_LOG_LEVEL

Set the minimum level in `.env`:

```bash
TINA4_LOG_LEVEL=info
```

Only entries at or above the configured level are emitted:

| `TINA4_LOG_LEVEL` | debug | info | warn | error |
|-------------------|-------|------|------|-------|
| `debug` | shown | shown | shown | shown |
| `info` | silent | shown | shown | shown |
| `warn` | silent | silent | shown | shown |
| `error` | silent | silent | silent | shown |

In development, use `debug`. In production, use `info` or `warn` to reduce log volume.

```bash
# .env.development
TINA4_LOG_LEVEL=debug

# .env.production
TINA4_LOG_LEVEL=warn
```

---

## 4. Adding Context Fields

The second argument to any log method is a plain object. Its fields are merged into the log entry:

```typescript
import { Log } from "tina4-nodejs";

Log.info("HTTP request", {
    method: "POST",
    path: "/api/orders",
    status: 201,
    duration_ms: 47,
    user_id: 15
});
```

```json
{"timestamp":"2026-04-02T08:15:00.000Z","level":"INFO","message":"HTTP request","method":"POST","path":"/api/orders","status":201,"duration_ms":47,"user_id":15}
```

Any JSON-serializable value is valid: strings, numbers, booleans, arrays, nested objects.

---

## 5. Logging Errors

Pass an `Error` object alongside context:

```typescript
import { Log } from "tina4-nodejs";

try {
    await processPayment(orderId, amount);
} catch (err) {
    Log.error("Payment processing failed", {
        orderId,
        amount,
        error: err instanceof Error ? err.message : String(err),
        stack: err instanceof Error ? err.stack : undefined
    });
}
```

```json
{
  "timestamp": "2026-04-02T08:16:00.000Z",
  "level": "ERROR",
  "message": "Payment processing failed",
  "orderId": 1042,
  "amount": 249.99,
  "error": "Connection timeout after 5000ms",
  "stack": "Error: Connection timeout...\n    at PaymentGateway.charge ..."
}
```

---

## 6. Request-Scoped Logging

Add a request ID to every log entry in a request handler so you can trace all log lines from a single request:

```typescript
import { Router, Log } from "tina4-nodejs";
import { randomUUID } from "crypto";

Router.post("/api/checkout", async (req, res) => {
    const requestId = randomUUID();
    const start = Date.now();

    Log.info("Checkout started", { requestId, user: req.user?.id });

    try {
        const orderId = await placeOrder(req.body, requestId);

        Log.info("Order placed", {
            requestId,
            orderId,
            duration_ms: Date.now() - start
        });

        return res.status(201).json({ order_id: orderId });

    } catch (err) {
        Log.error("Checkout failed", {
            requestId,
            error: err instanceof Error ? err.message : String(err),
            duration_ms: Date.now() - start
        });

        return res.status(500).json({ error: "Checkout failed" });
    }
});
```

Search your log aggregator for `requestId` to see every log line from that request, in order, with timings.

---

## 7. Performance Logging

Log slow operations to identify bottlenecks:

```typescript
import { Log } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

async function fetchDashboardData(userId: number) {
    const t0 = Date.now();
    const db = Database.getConnection();

    const data = await db.fetchAll(
        `SELECT o.id, o.total, o.status, COUNT(oi.id) as item_count
         FROM orders o
         JOIN order_items oi ON oi.order_id = o.id
         WHERE o.user_id = :userId
         GROUP BY o.id
         ORDER BY o.created_at DESC
         LIMIT 10`,
        { userId }
    );

    const duration = Date.now() - t0;

    if (duration > 500) {
        Log.warn("Slow dashboard query", { userId, duration_ms: duration, rows: data.length });
    } else {
        Log.debug("Dashboard query", { userId, duration_ms: duration, rows: data.length });
    }

    return data;
}
```

---

## 8. Exercise: Add Logging to an Existing API

Take the product listing endpoint from Chapter 11 and add structured logging at every meaningful point.

### Requirements

1. Log `info` when a request is received, including the route and query parameters
2. Log `debug` for cache hits and misses with the cache key
3. Log `warn` when a query takes longer than 200ms
4. Log `error` when an exception is caught, with the error message and stack

### Expected log output (debug level):

```json
{"timestamp":"...","level":"INFO","message":"Products request","category":"Electronics","page":1}
{"timestamp":"...","level":"DEBUG","message":"Cache miss","key":"store:products:a3f2..."}
{"timestamp":"...","level":"WARN","message":"Slow product query","duration_ms":312,"rows":3}
{"timestamp":"...","level":"INFO","message":"Products served","source":"database","count":3,"duration_ms":315}
```

---

## 9. Solution

```typescript
import { Router, Log, cacheGet, cacheSet } from "tina4-nodejs";
import { createHash } from "crypto";

const PRODUCTS = [
    { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99 },
    { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99 },
    { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99 },
    { id: 4, name: "Standing Desk", category: "Electronics", price: 549.99 },
];

Router.get("/api/products/logged", async (req, res) => {
    const category = req.query.category ?? null;
    const page = parseInt(req.query.page ?? "1", 10);
    const start = Date.now();

    Log.info("Products request", { category, page });

    const keyData = JSON.stringify({ category, page });
    const cacheKey = `products:${createHash("md5").update(keyData).digest("hex")}`;

    try {
        const cached = await cacheGet(cacheKey);

        if (cached !== null) {
            Log.debug("Cache hit", { key: cacheKey });
            return res.json({ ...cached, source: "cache" });
        }

        Log.debug("Cache miss", { key: cacheKey });

        // Simulate database work
        const t0 = Date.now();
        await new Promise(resolve => setTimeout(resolve, 50));
        let products = PRODUCTS;

        if (category) {
            products = products.filter(
                p => p.category.toLowerCase() === String(category).toLowerCase()
            );
        }

        const queryDuration = Date.now() - t0;

        if (queryDuration > 200) {
            Log.warn("Slow product query", { duration_ms: queryDuration, rows: products.length });
        }

        const result = { products, page, total: products.length };
        await cacheSet(cacheKey, result, 300);

        Log.info("Products served", {
            source: "database",
            count: products.length,
            duration_ms: Date.now() - start
        });

        return res.json({ ...result, source: "database" });

    } catch (err) {
        Log.error("Products endpoint failed", {
            error: err instanceof Error ? err.message : String(err),
            stack: err instanceof Error ? err.stack : undefined,
            duration_ms: Date.now() - start
        });
        return res.status(500).json({ error: "Internal server error" });
    }
});
```

---

## 10. Gotchas

### 1. Logging sensitive data

`Log.info("Login", { email, password })` ships the password to your log aggregator.

**Fix:** Never log passwords, tokens, credit card numbers, or PII. Log user IDs and request IDs instead. Before shipping a log call to production, check every field.

### 2. Logging in hot paths adds latency

Calling `Log.debug()` on every database row in a loop adds up.

**Fix:** Log aggregates, not individual items. `Log.debug("Fetched rows", { count: rows.length })` is better than logging each row.

### 3. Circular references in context objects

`Log.info("Data", { obj })` throws if `obj` contains circular references, because JSON serialization fails.

**Fix:** Pass primitive values and simple objects. Use `JSON.stringify` with a replacer to handle circular references if you must log complex objects.

### 4. TINA4_LOG_LEVEL defaults to info

In development, you might expect to see debug output and see nothing.

**Fix:** Set `TINA4_LOG_LEVEL=debug` in your `.env` file. Check the value with `Log.debug("Log level check", {})` -- if it appears, debug logging is active.
