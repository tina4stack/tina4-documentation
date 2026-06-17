# Chapter 11: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. 800 milliseconds to render. Every visitor triggers the same queries, the same template rendering, the same JSON serialization -- for data that changes once a day.

Add caching. The first request takes 800ms. The next 10,000 take 3ms each. A 266x improvement from one line of configuration.

Caching stores the result of expensive operations for reuse. Tina4 gives you three layers, each with its own job:

1. **Request-scoped query cache** -- on by default, dedupes identical database reads within a single request.
2. **Persistent database cache** -- opt-in, caches query results across requests for a few seconds.
3. **Response cache** -- caches whole HTTP responses so the route handler never runs.

On top of those, a direct key/value API (`cacheGet`/`cacheSet`/...) caches anything you want.

> **Node specifics.** Method names are camelCase. The key/value API, the response-cache middleware, and the database read path are **async** -- `await` them. Only `db.cacheStats()` and `db.cacheClear()` are synchronous.

---

## 2. Layer 1: Request-Scoped Query Cache (On by Default)

The database wrapper caches every `SELECT` it runs during a single HTTP request. Run the same query twice in one handler and the second call returns the cached rows -- no second trip to the database.

This layer is **on by default**. You do not configure it. At the start of every request the framework clears it, so one request never sees another request's rows. Any write (`insert`, `update`, `delete`, `execute`) flushes it immediately.

```typescript
import { get } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

get("/api/report", async (req, res) => {
    const db = Database.getConnection();

    // First call hits the database.
    const totals = await db.fetchAll("SELECT category, COUNT(*) AS n FROM products GROUP BY category");

    // Same query later in the SAME request — served from the request cache, no DB hit.
    const totalsAgain = await db.fetchAll("SELECT category, COUNT(*) AS n FROM products GROUP BY category");

    return res.json({ totals, matches: JSON.stringify(totals) === JSON.stringify(totalsAgain) });
});
```

Control it with two environment variables:

```bash
# On by default. Set to false to turn the request-scoped cache off.
TINA4_AUTO_CACHING=true

# Safety TTL in seconds for non-request contexts (scripts, workers). Default: 5
TINA4_AUTO_CACHING_TTL=5
```

Inside an HTTP request the cache clears at the request boundary, so the TTL rarely matters. It only kicks in for long-running scripts or workers that never cross a request boundary.

This layer always runs in-process. It is the fastest cache there is -- a plain in-memory map, no serialization, no network.

---

## 3. Layer 2: Persistent Database Cache (Opt-In)

The request cache forgets everything between requests. The persistent cache does not. Turn it on and identical queries return cached rows across requests, until the entry expires.

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=30
```

`TINA4_DB_CACHE_TTL` defaults to **30** seconds. With the persistent cache enabled, identical queries return cached results instead of hitting the database:

```typescript
import { get } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

get("/api/categories", async (req, res) => {
    const db = Database.getConnection();

    // First call across all requests: runs the query.
    // Repeat calls within 30 seconds: returns the cached rows.
    const categories = await db.fetchAll("SELECT * FROM categories ORDER BY name");

    return res.json({ categories });
});
```

The cache key comes from the SQL and its parameters. Different queries or different parameters get different keys:

```typescript
// Cached separately:
await db.fetchAll("SELECT * FROM products WHERE category = ?", ["Electronics"]);
await db.fetchAll("SELECT * FROM products WHERE category = ?", ["Fitness"]);
```

A write on any connection flushes the persistent cache, so a stale row never outlives an update.

### Choosing the backend

By default the persistent cache lives in-process (same as request caching, just longer-lived). Point it at a shared store to share cached rows across instances:

```bash
TINA4_DB_CACHE_BACKEND=redis        # memory (default) | file | redis | valkey | memcached | mongodb | database
TINA4_DB_CACHE_URL=redis://localhost:6379
```

With `memory` (the default), each process keeps its own copy. With a network backend, every instance reads and writes the same cache, and a write on one instance invalidates the rest.

### When to use it

- Read-heavy apps where the same queries run over and over
- Reference data that changes seldom (categories, countries, settings)
- Dashboard queries that aggregate large datasets

### When not to use it

- Write-heavy apps where data changes on every request
- Queries with real-time requirements (inventory counts, live prices)
- Queries that must return the latest data at all times

### Skipping the cache for one query

Pass `{ noCache: true }` as the **trailing options argument** to bypass both cache layers for a single call. It is a separate argument -- it never replaces the params array:

```typescript
// fetchAll(sql, params, limit, offset, opts)
const fresh = await db.fetchAll("SELECT * FROM products WHERE category = ?", ["Electronics"], 50, 0, { noCache: true });

// fetch(sql, params, limit, offset, opts) — returns the full DatabaseResult
const result = await db.fetch("SELECT * FROM products", [], 50, 0, { noCache: true });

// fetchOne(sql, params, opts)
const one = await db.fetchOne("SELECT * FROM products WHERE id = ?", [42], { noCache: true });
```

A `noCache` read runs straight against the database and leaves the hit/miss counters untouched.

---

## 4. Layer 3: Response Cache

The fastest cache skips your handler entirely. The response-cache middleware stores the complete response -- body, content type, status code -- and serves it on the next matching GET request without calling your route handler at all.

There are two ways to attach it. Both work.

### String form in the middleware list

Pass `"ResponseCache:300"` as a middleware spec. The number after the colon is the TTL in seconds:

```typescript
import { get } from "tina4-nodejs";

get("/api/products", async (req, res) => {
    // This handler runs 12 database queries and takes 800ms.
    // With the response cache, it runs once every 5 minutes.
    console.log("Handler called — should only appear once every 5 minutes");

    const products = [
        { id: 1, name: "Wireless Keyboard", price: 79.99 },
        { id: 2, name: "USB-C Hub", price: 49.99 },
        { id: 3, name: "Monitor Stand", price: 129.99 }
    ];

    return res.json({ products, generatedAt: new Date().toISOString() });
}, ["ResponseCache:300"]);
```

The middleware list is the third argument -- an array. Use `"ResponseCache"` on its own for the default TTL (`TINA4_CACHE_TTL`, 60 seconds), or `"ResponseCache:300"` to set it.

### Function form via `.middleware(...)`

For the same effect with an explicit config object, chain `responseCache(...)`:

```typescript
import { get, responseCache } from "tina4-nodejs";

get("/api/products", listProducts).middleware(responseCache({ ttl: 300 }));
```

### What happens during the TTL

```bash
curl http://localhost:7148/api/products
```

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
    {"id": 2, "name": "USB-C Hub", "price": 49.99},
    {"id": 3, "name": "Monitor Stand", "price": 129.99}
  ],
  "generatedAt": "2026-03-22T14:30:00.000Z"
}
```

Call it again within 5 minutes:

```bash
curl http://localhost:7148/api/products
```

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
    {"id": 2, "name": "USB-C Hub", "price": 49.99},
    {"id": 3, "name": "Monitor Stand", "price": 129.99}
  ],
  "generatedAt": "2026-03-22T14:30:00.000Z"
}
```

The `generatedAt` timestamp is identical. The handler did not run -- the response came from cache.

### Cache headers

The middleware sets two headers on every response:

```
X-Cache: HIT
X-Cache-TTL: 300
```

- `X-Cache` is `HIT` when the response came from cache, `MISS` when the handler ran.
- `X-Cache-TTL` reports the configured cache lifetime in seconds.

### Caching with query parameters

The cache key is the method plus the full URL, including the query string. `/api/products?page=1` and `/api/products?page=2` cache separately:

```typescript
import { get } from "tina4-nodejs";

get("/api/products", async (req, res) => {
    const page = parseInt(req.query.page ?? "1", 10);

    return res.json({
        page,
        products: [],
        generatedAt: new Date().toISOString()
    });
}, ["ResponseCache:300"]);
```

```bash
curl "http://localhost:7148/api/products?page=1"  # MISS, stores page=1
curl "http://localhost:7148/api/products?page=2"  # MISS, stores page=2
curl "http://localhost:7148/api/products?page=1"  # HIT
```

### What not to cache

Only GET responses are cached -- the middleware passes other methods straight through. Beyond that, do not put the response cache on:

- **User-specific endpoints**: `/api/profile` returns different data per user, but the key is just the URL, so the first user's response goes to everyone.
- **Real-time data**: stock prices, live scores, chat messages.
- **Authenticated endpoints**: unless the cache is scoped per user (use the key/value API with a user-specific key instead).

```typescript
// GOOD: public, rarely changing data
get("/api/categories", async (req, res) => {
    return res.json({ categories: [] });
}, ["ResponseCache:3600"]);

// BAD: user-specific data — do NOT cache
get("/api/profile", async (req, res) => {
    return res.json(req.user);
});
```

---

## 5. Backends

All three layers (and the key/value API below) share one backend set. Pick it with `TINA4_CACHE_BACKEND`:

| Backend | Notes |
|---------|-------|
| `memory` | Default. In-process, fastest, lost on restart. |
| `file` | JSON files on disk. Survives restarts, no extra service. |
| `redis` | Shared across instances, sub-millisecond, built-in expiry. |
| `valkey` | Redis wire protocol -- same behaviour as redis. |
| `memcached` | Shared, unauthenticated. |
| `mongodb` | TTL collection. Needs the optional `mongodb` driver. |
| `database` | A `tina4_cache` table in your existing database. |

### Memory (default)

```bash
# This is the default — you do not need to set it.
TINA4_CACHE_BACKEND=memory
```

No disk I/O, no network calls. It resets when the server restarts. Ideal for development and single-server deployments where losing the cache on restart is fine.

### Redis (and Valkey)

For cache that survives restarts and is shared across instances behind a load balancer, use Redis:

```bash
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_URL=redis://localhost:6379
```

Credentials live in the URL (`redis://user:pass@host`, `redis://:pass@host`) or in separate env vars when they are not embedded:

```bash
TINA4_CACHE_USERNAME=myuser
TINA4_CACHE_PASSWORD=mypassword
```

Valkey speaks the same protocol -- set `TINA4_CACHE_BACKEND=valkey` and the rest is identical.

Why Redis:

- Cache survives server restarts.
- Shared across instances behind a load balancer.
- Sub-millisecond reads and writes.
- Built-in key expiry -- TTL cleanup is automatic.
- One instance can serve sessions, cache, and queues.

### File

If you want persistence but cannot run Redis, use file-based caching:

```bash
TINA4_CACHE_BACKEND=file
TINA4_CACHE_DIR=/path/to/cache/directory
```

Each entry is a file on disk. Slower than memory or Redis, but survives restarts with zero extra infrastructure. Reach for it when you need persistence on limited hosting, or when entries are large and you would rather not hold them in memory.

### Graceful fallback

If the configured backend's driver is missing, or the service is unreachable, or the credentials are wrong, the cache logs a warning and falls back to the **file** backend -- a real, persistent cache, never a silent no-op. Your code does not change; only the storage backend does.

---

## 6. Direct Key/Value API

For custom caching logic, use the key/value functions. They are **async** -- `await` every call. A miss returns `undefined`.

```typescript
import { cacheGet, cacheSet, cacheDelete, clearCache, cacheStats } from "@tina4/core";
```

### cacheSet

```typescript
import { cacheSet } from "@tina4/core";

// Cache a value for 300 seconds.
await cacheSet("product:42", {
    id: 42,
    name: "Wireless Keyboard",
    price: 79.99,
    inStock: true
}, 300);

// Cache a string.
await cacheSet("exchangeRate:USD_EUR", "0.92", 3600);

// No TTL — uses the default (TINA4_CACHE_TTL, 60 seconds).
await cacheSet("app:config", { theme: "dark", lang: "en" });
```

### cacheGet

```typescript
import { cacheGet, cacheSet } from "@tina4/core";

const product = await cacheGet("product:42");
// Returns the cached value, or undefined if not found or expired.

if (product === undefined) {
    // Cache miss — fetch from the database, then store it.
    const fresh = await fetchProductFromDatabase(42);
    await cacheSet("product:42", fresh, 300);
}
```

### cacheDelete

```typescript
import { cacheDelete } from "@tina4/core";

await cacheDelete("product:42");

// Delete several keys.
await cacheDelete("product:43");
await cacheDelete("product:44");
```

### clearCache

```typescript
import { clearCache } from "@tina4/core";

// Wipe every entry in the active backend.
await clearCache();
```

### Cache-aside pattern

The most common pattern is cache-aside (lazy loading). Note the `=== undefined` miss check -- and that every cache call is `await`ed:

```typescript
import { get, cacheGet, cacheSet } from "@tina4/core";
import { Database } from "tina4-nodejs/orm";

get("/api/products/{id}", async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const cacheKey = `product:${id}`;

    // 1. Try the cache first — await it.
    const cached = await cacheGet(cacheKey);
    if (cached !== undefined) {
        return res.json({ ...(cached as object), source: "cache" });
    }

    // 2. Miss — fetch from the database.
    const db = Database.getConnection();
    const product = await db.fetchOne(
        "SELECT id, name, category, price, in_stock FROM products WHERE id = ?",
        [id]
    );

    if (product === null) {
        return res.status(404).json({ error: "Product not found" });
    }

    // 3. Store for next time.
    await cacheSet(cacheKey, product, 600);  // 10 minutes

    return res.json({ ...product, source: "database" });
});
```

First call (cache miss):

```json
{ "id": 42, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": true, "source": "database" }
```

Second call (cache hit):

```json
{ "id": 42, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": true, "source": "cache" }
```

---

## 7. Cache Invalidation Strategies

Cache invalidation is the hard problem. Stale cache serves outdated data. Premature invalidation throws away performance gains. Three strategies handle this.

### Strategy 1: Time-Based Expiry (TTL)

The simplest strategy. Set a TTL and let the cache expire on its own:

```typescript
await cacheSet("products:featured", featuredProducts, 600);  // Expires in 10 minutes
```

Good for data where near-real-time accuracy is acceptable. A 10-minute delay in updating the featured products list is fine for most storefronts.

### Strategy 2: Event-Based Invalidation

Clear the cache when the underlying data changes:

```typescript
import { put, cacheDelete } from "@tina4/core";
import { Database } from "tina4-nodejs/orm";

put("/api/products/{id}", async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const body = req.body;
    const db = Database.getConnection();

    await db.execute(
        "UPDATE products SET name = ?, price = ? WHERE id = ?",
        [body.name, body.price, id]
    );

    // Invalidate the cache for this product.
    await cacheDelete(`product:${id}`);

    // Also invalidate any list caches that might include it.
    await cacheDelete("products:all");
    await cacheDelete("products:featured");

    const updated = await db.fetchOne("SELECT * FROM products WHERE id = ?", [id]);
    return res.json(updated);
});
```

The most accurate strategy -- the cache is fresh after every write. The downside: you must remember to invalidate every key that holds the affected data.

### Strategy 3: Write-Through Cache

Update the cache at the same time as the database:

```typescript
import { put, cacheSet } from "@tina4/core";
import { Database } from "tina4-nodejs/orm";

put("/api/products/{id}", async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const body = req.body;
    const db = Database.getConnection();

    await db.execute(
        "UPDATE products SET name = ?, price = ? WHERE id = ?",
        [body.name, body.price, id]
    );

    const updated = await db.fetchOne("SELECT * FROM products WHERE id = ?", [id]);

    // Write the new data to cache instead of deleting.
    await cacheSet(`product:${id}`, updated, 600);

    return res.json(updated);
});
```

The cache holds the latest data at all times. No cache miss after an update -- the next read comes from the already-warm cache.

### Choosing a strategy

| Strategy | Best For | Tradeoff |
|----------|----------|----------|
| TTL | Read-heavy, tolerates staleness | Stale data for up to TTL duration |
| Event-based | Consistency matters | Every write must invalidate |
| Write-through | High traffic, frequent updates | Every write does cache work |

Combine them. Use TTL as a safety net (entries expire even if invalidation misses). Use event-based invalidation for immediate consistency on critical data.

---

## 8. TTL Management

Choosing the right TTL depends on how often the data changes and how acceptable stale data is:

| Data Type | Suggested TTL | Reasoning |
|-----------|---------------|-----------|
| Static config (categories, countries) | 3600 (1 hour) | Changes rarely, stale data is harmless |
| Product catalog | 300 (5 min) | Updates several times per day |
| User profile | 60 (1 min) | Users expect changes to appear fast |
| Search results | 120 (2 min) | Balance between freshness and performance |
| Dashboard stats | 30 (30 sec) | Near-real-time but expensive to compute |
| Exchange rates | 60 (1 min) | Updates often, slight delay is acceptable |
| Shopping cart | 0 (no cache) | Must reflect current state at all times |

### Dynamic TTL

Adjust the TTL based on the data:

```typescript
import { cacheGet, cacheSet } from "@tina4/core";

async function getCachedProduct(productId: number) {
    const cacheKey = `product:${productId}`;

    const cached = await cacheGet(cacheKey);
    if (cached !== undefined) {
        return cached;
    }

    const product = await fetchProductFromDatabase(productId);

    // Popular products: shorter TTL (more likely to change).
    // Inactive products: longer TTL (rarely change).
    const ttl = product.viewCount > 1000 ? 60 : 3600;
    await cacheSet(cacheKey, product, ttl);

    return product;
}
```

---

## 9. Cache Statistics

Two `cacheStats` calls report on two different things. Get the async/await right -- they differ.

### Key/value backend stats (async)

`cacheStats()` from `@tina4/core` reports the backend behind the key/value API, the response cache, and the persistent DB cache. It is **async**:

```typescript
import { get, cacheStats } from "@tina4/core";

get("/api/cache/stats", async (req, res) => {
    const stats = await cacheStats();
    return res.json(stats);
});
```

```bash
curl http://localhost:7148/api/cache/stats
```

```json
{
  "hits": 15234,
  "misses": 891,
  "size": 42,
  "backend": "memory"
}
```

The shape is exactly `{ hits, misses, size, backend }` -- four fields, nothing more.

### Database query-cache stats (sync)

`db.cacheStats()` reports the database query cache (layers 1 and 2). It is **synchronous** -- no `await`:

```typescript
import { Database } from "tina4-nodejs/orm";

const db = Database.getConnection();
const stats = db.cacheStats();
```

```json
{
  "enabled": true,
  "mode": "request",
  "hits": 128,
  "misses": 12,
  "size": 9,
  "ttl": 5,
  "backend": "memory"
}
```

The shape is `{ enabled, mode, hits, misses, size, ttl, backend? }`. `mode` is one of:

- `"request"` -- request-scoped caching is active (the default).
- `"persistent"` -- `TINA4_DB_CACHE=true`, so entries survive across requests.
- `"off"` -- both layers are disabled.

`db.cacheClear()` flushes the query cache and resets its counters. It is synchronous too.

A key/value hit rate above 90% means your caching strategy works. Below 80% means TTLs are too short, the cache is too small, or you are caching data that is not accessed often enough to benefit.

---

## 10. Combining Cache Layers

For maximum performance, stack the layers. Each backstops the one above it:

```typescript
import { get, cacheGet, cacheSet } from "@tina4/core";
import { Database } from "tina4-nodejs/orm";

get("/api/catalog", async (req, res) => {
    const page = parseInt(req.query.page ?? "1", 10);
    const cacheKey = `catalog:page:${page}`;

    // Layer A: application key/value cache — await it.
    const cached = await cacheGet(cacheKey);
    if (cached !== undefined) {
        return res.json({ ...(cached as object), cache: "application" });
    }

    // Layer B: database query (request + persistent caching apply here automatically).
    const db = Database.getConnection();
    const limit = 20;
    const offset = (page - 1) * limit;

    const products = await db.fetchAll(
        `SELECT p.*, c.name AS category_name
         FROM products p
         JOIN categories c ON p.category_id = c.id
         WHERE p.active = 1
         ORDER BY p.created_at DESC
         LIMIT ? OFFSET ?`,
        [limit, offset]
    );

    const total = await db.fetchOne("SELECT COUNT(*) AS count FROM products WHERE active = 1");

    const catalog = {
        products,
        page,
        total: (total as { count: number }).count,
        pages: Math.ceil((total as { count: number }).count / limit),
        generatedAt: new Date().toISOString()
    };

    await cacheSet(cacheKey, catalog, 300);

    return res.json({ ...catalog, cache: "none" });
}, ["ResponseCache:60"]);
```

Three layers, in the order a request meets them:

1. **Response cache** (60 seconds): the entire HTTP response is cached. The handler does not run.
2. **Application key/value cache** (300 seconds): if the response cache expired but this is still fresh, skip the database work.
3. **Database query cache**: individual query results dedupe within the request and (if `TINA4_DB_CACHE=true`) across requests.

The first visitor after a full expiry waits 800ms. Everyone else gets the response in under 5ms.

---

## 11. Exercise: Cache an Expensive Product Listing Endpoint

Build a product listing endpoint that caches at multiple levels.

### Requirements

1. Create a `GET /api/store/products` endpoint that:
   - Accepts query parameters: `category`, `page`, `limit`
   - Returns a list of products with pagination metadata
   - Uses the key/value API (`cacheGet`/`cacheSet`) with a 5-minute TTL
   - Includes a `source` field (`"cache"` or `"database"`)

2. Create a `POST /api/store/products` endpoint that:
   - Creates a new product
   - Invalidates the relevant cache entries

3. Create a `GET /api/store/cache-stats` endpoint that shows cache statistics

### Test with

```bash
# First call — cache miss, slow
curl "http://localhost:7148/api/store/products?category=Electronics&page=1"

# Second call — cache hit, fast
curl "http://localhost:7148/api/store/products?category=Electronics&page=1"

# Different category — cache miss
curl "http://localhost:7148/api/store/products?category=Fitness&page=1"

# Create a product — should invalidate cache
curl -X POST http://localhost:7148/api/store/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Smart Watch", "category": "Electronics", "price": 299.99}'

# Same query again — cache miss (invalidated by the POST)
curl "http://localhost:7148/api/store/products?category=Electronics&page=1"

# Check cache stats
curl http://localhost:7148/api/store/cache-stats
```

---

## 12. Solution

Create `src/routes/storeCached.ts`:

```typescript
import { get, post, cacheGet, cacheSet, cacheDelete, cacheStats } from "@tina4/core";
import { createHash } from "crypto";

function getProductStore() {
    return [
        { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99, inStock: true },
        { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true },
        { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99, inStock: false },
        { id: 4, name: "Standing Desk", category: "Electronics", price: 549.99, inStock: true },
        { id: 5, name: "Running Shoes", category: "Fitness", price: 119.99, inStock: true },
        { id: 6, name: "Bluetooth Speaker", category: "Electronics", price: 39.99, inStock: true },
        { id: 7, name: "Resistance Bands", category: "Fitness", price: 14.99, inStock: true },
        { id: 8, name: "French Press", category: "Kitchen", price: 34.99, inStock: true },
    ];
}

function cacheKeyFor(category: string | null, page: number, limit: number): string {
    const keyData = JSON.stringify({ category, page, limit });
    return `store:products:${createHash("md5").update(keyData).digest("hex")}`;
}


get("/api/store/products", async (req, res) => {
    const category = req.query.category ?? null;
    const page = parseInt(req.query.page ?? "1", 10);
    const limit = parseInt(req.query.limit ?? "20", 10);

    const cacheKey = cacheKeyFor(category, page, limit);

    // Try cache first — await it. A miss is undefined.
    const cached = await cacheGet(cacheKey);
    if (cached !== undefined) {
        return res.json({ ...(cached as object), source: "cache" });
    }

    // Simulate an expensive database query.
    await new Promise(resolve => setTimeout(resolve, 100));  // 100ms delay

    let products = getProductStore();
    if (category !== null) {
        products = products.filter(
            p => p.category.toLowerCase() === String(category).toLowerCase()
        );
    }

    const total = products.length;
    const offset = (page - 1) * limit;
    products = products.slice(offset, offset + limit);

    const result = {
        products,
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
        generatedAt: new Date().toISOString()
    };

    // Cache for 5 minutes.
    await cacheSet(cacheKey, result, 300);

    return res.json({ ...result, source: "database" });
});


post("/api/store/products", async (req, res) => {
    const body = req.body;

    if (!body.name) {
        return res.status(400).json({ error: "Name is required" });
    }

    const product = {
        id: Math.floor(Math.random() * 9000) + 100,
        name: body.name,
        category: body.category ?? "General",
        price: parseFloat(body.price ?? "0"),
        inStock: true
    };

    // Invalidate every product-list cache we might have stored.
    const categories: (string | null)[] = ["Electronics", "Fitness", "Kitchen", "General", null];
    for (const cat of categories) {
        for (let p = 1; p <= 5; p++) {
            await cacheDelete(cacheKeyFor(cat, p, 20));
        }
    }

    return res.status(201).json({
        message: "Product created",
        product,
        cacheInvalidated: true
    });
});


get("/api/store/cache-stats", async (req, res) => {
    return res.json(await cacheStats());
});
```

**First call (cache miss):**

```bash
curl "http://localhost:7148/api/store/products?category=Electronics&page=1"
```

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "inStock": true},
    {"id": 4, "name": "Standing Desk", "category": "Electronics", "price": 549.99, "inStock": true},
    {"id": 6, "name": "Bluetooth Speaker", "category": "Electronics", "price": 39.99, "inStock": true}
  ],
  "page": 1,
  "limit": 20,
  "total": 3,
  "pages": 1,
  "generatedAt": "2026-03-22T14:30:00.000Z",
  "source": "database"
}
```

**Second call (cache hit):**

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "inStock": true},
    {"id": 4, "name": "Standing Desk", "category": "Electronics", "price": 549.99, "inStock": true},
    {"id": 6, "name": "Bluetooth Speaker", "category": "Electronics", "price": 39.99, "inStock": true}
  ],
  "page": 1,
  "limit": 20,
  "total": 3,
  "pages": 1,
  "generatedAt": "2026-03-22T14:30:00.000Z",
  "source": "cache"
}
```

Same `generatedAt`, but `source` changed from `"database"` to `"cache"`. The handler did not run.

---

## 13. Gotchas

### 1. Forgetting to await a cache call

**Problem:** `cacheGet` always looks like a miss, or `cacheSet` never seems to store anything.

**Cause:** The key/value API is async. `const v = cacheGet(key)` returns a Promise, not the value. Comparing a Promise with `=== undefined` is always false, so you treat every read as a hit -- of a Promise object.

**Fix:** `await` every key/value call: `const v = await cacheGet(key)`, `await cacheSet(...)`, `await cacheDelete(...)`, `await clearCache()`. The database read path is async too -- `await db.fetchAll(...)`. Only `db.cacheStats()` and `db.cacheClear()` are synchronous.

### 2. Caching authenticated responses

**Problem:** User A's profile is served to User B because the response was cached.

**Cause:** The response cache keys by method and URL alone. If `/api/profile` returns different data per user but every request hits the same URL, the first response is served to everyone.

**Fix:** Do not put the response cache on user-specific endpoints. Use the key/value API with a user-specific key instead: `await cacheSet(`profile:${userId}`, data, 300)`.

### 3. Memory cache lost on restart

**Problem:** After restarting the server, performance drops until the cache warms up.

**Cause:** The memory backend lives in the process. It is gone when the process restarts, so every request is a miss until data is cached again.

**Fix:** For production, use Redis (`TINA4_CACHE_BACKEND=redis`) or file (`TINA4_CACHE_BACKEND=file`). Both survive restarts. You can also run a warmup script that pre-populates the cache with your hottest data.

### 4. Stale data after a database update

**Problem:** You updated a product's price, but the API still returns the old price.

**Cause:** A key/value entry you set yourself still holds the old data and has not expired.

**Fix:** Invalidate or update on write. Use `await cacheDelete(`product:${id}`)` after an update, or write-through with `await cacheSet(...)`. (The request and persistent DB caches flush themselves on any write -- this gotcha is about keys you manage by hand.)

### 5. Cache key collisions

**Problem:** Two different queries return the same cached data.

**Cause:** Your keys are not specific enough. Using `"products"` for both the full list and a filtered list collides.

**Fix:** Include every relevant parameter in the key: `"products:category:Electronics:page:1:limit:20"`, or hash the parameters: `` `products:${createHash("md5").update(JSON.stringify(params)).digest("hex")}` ``.

### 6. Serialization overhead

**Problem:** Caching makes certain requests slower, not faster.

**Cause:** The cached object is large. Serializing and deserializing it costs more than recomputing it -- especially on a network backend, where every value is JSON over the wire.

**Fix:** Only cache data that is expensive to compute. If the original operation takes 5ms and serialization takes 10ms, caching is counterproductive. Profile before and after.

### 7. Forgetting to set a TTL

**Problem:** Cache entries never expire and the server's memory grows until it crashes.

**Cause:** You called `await cacheSet("key", value)` with no TTL, so it used the default. For data you expect to live a long time, that may be shorter than you think -- or, on a backend without eviction, longer.

**Fix:** Set an explicit TTL: `await cacheSet("key", value, 300)`. Even for data that "never changes," set a long one like 86400 (24 hours). It is a safety net against both stale data and unbounded growth. `TINA4_CACHE_MAX_ENTRIES` (default 1000) also caps the memory and file backends.
