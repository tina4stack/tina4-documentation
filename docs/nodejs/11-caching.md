# Chapter 11: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. 800 milliseconds to render. Every visitor triggers the same queries, the same template rendering, the same JSON serialization -- for data that changes once a day.

Add caching. The first request takes 800ms. The next 10,000 take 3ms each. A 266x improvement from one line of configuration.

Caching stores the result of expensive operations for reuse. Tina4 provides three levels: response caching (entire HTTP responses), database query caching, and a direct cache API for custom use cases.

---

## 2. Response Caching with ResponseCache Middleware

The fastest way to cache is at the HTTP response level. The `ResponseCache` middleware stores the complete response (headers and body) and serves it on subsequent requests without calling your route handler at all.

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/products", async (req, res) => {
    // This handler runs 12 database queries and takes 800ms
    // With ResponseCache, it runs once every 5 minutes

    console.log("Handler called -- should only appear once every 5 minutes");

    const products = [
        { id: 1, name: "Wireless Keyboard", price: 79.99 },
        { id: 2, name: "USB-C Hub", price: 49.99 },
        { id: 3, name: "Monitor Stand", price: 129.99 }
    ];

    return res.json({ products, generated_at: new Date().toISOString() });
}, "ResponseCache:300");
```

The `"ResponseCache:300"` middleware caches the response for 300 seconds (5 minutes). During those 5 minutes:

- The first request runs the handler (800ms)
- The next 10,000 requests serve the cached response (3ms each)
- After 300 seconds, the cache expires and the next request runs the handler again

```bash
curl http://localhost:7145/api/products
```

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
    {"id": 2, "name": "USB-C Hub", "price": 49.99},
    {"id": 3, "name": "Monitor Stand", "price": 129.99}
  ],
  "generated_at": "2026-03-22T14:30:00.000Z"
}
```

Call it again within 5 minutes:

```bash
curl http://localhost:7145/api/products
```

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
    {"id": 2, "name": "USB-C Hub", "price": 49.99},
    {"id": 3, "name": "Monitor Stand", "price": 129.99}
  ],
  "generated_at": "2026-03-22T14:30:00.000Z"
}
```

Notice the `generated_at` timestamp is the same. The handler did not run -- the response came from cache.

### Cache Headers

The `ResponseCache` middleware sets cache-related headers on every response:

```
X-Cache: HIT
X-Cache-TTL: 247
Cache-Control: public, max-age=300
```

- `X-Cache: HIT` or `X-Cache: MISS` tells you whether the response came from cache
- `X-Cache-TTL` shows the remaining time-to-live in seconds
- `Cache-Control` enables browser and CDN caching

### Caching with Query Parameters

By default, the cache key includes the full URL with query parameters. `/api/products?page=1` and `/api/products?page=2` are cached separately:

```typescript
Router.get("/api/products", async (req, res) => {
    const page = parseInt(req.query.page ?? "1", 10);
    const limit = 20;
    const offset = (page - 1) * limit;

    return res.json({
        page,
        products: [],
        generated_at: new Date().toISOString()
    });
}, "ResponseCache:300");
```

```bash
curl "http://localhost:7145/api/products?page=1"  # Cache MISS, stores for page=1
curl "http://localhost:7145/api/products?page=2"  # Cache MISS, stores for page=2
curl "http://localhost:7145/api/products?page=1"  # Cache HIT
```

### What Not to Cache

Do not use `ResponseCache` on:

- **POST, PUT, PATCH, DELETE routes**: Only GET responses should be cached
- **User-specific endpoints**: `/api/profile` returns different data for each user
- **Real-time data**: Stock prices, live scores, chat messages
- **Authenticated endpoints**: Unless the cache is scoped per user

```typescript
// GOOD: Public, rarely changing data
Router.get("/api/categories", async (req, res) => {
    return res.json({ categories: [] });
}, "ResponseCache:3600");

// BAD: User-specific data -- do NOT cache
Router.get("/api/profile", async (req, res) => {
    return res.json(req.user);
}, "auth_middleware");
```

---

## 3. Memory Cache (Default)

Tina4's cache system stores data in memory by default. No configuration needed.

```env
# This is the default -- you do not need to set it explicitly
TINA4_CACHE_BACKEND=memory
```

Memory cache is the fastest option (no disk I/O, no network calls) but it resets when the server restarts. It is ideal for development and single-server deployments where losing the cache on restart is acceptable.

---

## 4. Redis Cache

For production deployments where you want cache persistence across server restarts and shared cache across multiple server instances, use Redis:

```env
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_HOST=localhost
TINA4_CACHE_PORT=6379
TINA4_CACHE_PASSWORD=your-redis-password
TINA4_CACHE_PREFIX=myapp:cache:
```

Your code does not change. The `cacheGet`, `cacheSet`, and `ResponseCache` middleware all work the same way. Only the storage backend changes.

### Why Redis?

- Cache survives server restarts
- Shared across multiple server instances (behind a load balancer)
- Sub-millisecond reads and writes
- Built-in key expiry (TTL cleanup is automatic)
- Same Redis instance can serve sessions, cache, and queues

---

## 5. File Cache

If you want cache persistence but do not have Redis, use file-based caching:

```env
TINA4_CACHE_BACKEND=file
TINA4_CACHE_PATH=/path/to/cache/directory
```

File cache stores each cache entry as a file on disk. It is slower than memory or Redis but survives server restarts without extra infrastructure.

### When to Use File Cache

- You need cache persistence but cannot run Redis
- Your hosting environment is limited (shared hosting, no external services)
- Cache entries are large and you do not want them in memory

---

## 6. Direct Cache API

For custom caching logic, use the `cacheGet`, `cacheSet`, and `cacheDelete` functions:

### cacheSet

```typescript
import { cacheSet } from "tina4-nodejs";

// Cache a value for 300 seconds
await cacheSet("product:42", {
    id: 42,
    name: "Wireless Keyboard",
    price: 79.99,
    inStock: true
}, 300);

// Cache a string
await cacheSet("exchange_rate:USD_EUR", "0.92", 3600);

// Cache indefinitely (no TTL)
await cacheSet("app:config", { theme: "dark", lang: "en" });
```

### cacheGet

```typescript
import { cacheGet, cacheSet } from "tina4-nodejs";

const product = await cacheGet("product:42");
// Returns the cached value, or null if not found or expired

if (product === null) {
    // Cache miss -- fetch from database
    const freshProduct = await fetchProductFromDatabase(42);
    await cacheSet("product:42", freshProduct, 300);
}

return res.json(product);
```

### cacheDelete

```typescript
import { cacheDelete } from "tina4-nodejs";

// Delete a specific key
await cacheDelete("product:42");

// Delete multiple keys
await cacheDelete("product:42");
await cacheDelete("product:43");
await cacheDelete("product:44");
```

### Real-World Pattern: Cache-Aside

The most common caching pattern is cache-aside (also called lazy loading):

```typescript
import { Router, cacheGet, cacheSet } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/products/{id:int}", async (req, res) => {
    const id = req.params.id;
    const cacheKey = `product:${id}`;

    // 1. Try the cache first
    let product = await cacheGet(cacheKey);

    if (product !== null) {
        // Cache hit -- return immediately
        return res.json({ ...product, source: "cache" });
    }

    // 2. Cache miss -- fetch from database
    const db = Database.getConnection();
    product = await db.fetchOne(
        "SELECT id, name, category, price, in_stock FROM products WHERE id = :id",
        { id }
    );

    if (product === null) {
        return res.status(404).json({ error: "Product not found" });
    }

    // 3. Store in cache for next time
    await cacheSet(cacheKey, product, 600);  // Cache for 10 minutes

    return res.json({ ...product, source: "database" });
});
```

```bash
curl http://localhost:7145/api/products/42
```

First call (cache miss):

```json
{
  "id": 42,
  "name": "Wireless Keyboard",
  "category": "Electronics",
  "price": 79.99,
  "in_stock": true,
  "source": "database"
}
```

Second call (cache hit):

```json
{
  "id": 42,
  "name": "Wireless Keyboard",
  "category": "Electronics",
  "price": 79.99,
  "in_stock": true,
  "source": "cache"
}
```

---

## 7. Database Query Caching

Tina4 can cache database query results. Enable it in `.env`:

```env
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=300
```

With database caching enabled, identical queries return cached results instead of hitting the database:

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/categories", async (req, res) => {
    const db = Database.getConnection();

    // First call: executes the query (20ms)
    // Subsequent calls within 300 seconds: returns cached result (0.1ms)
    const categories = await db.fetchAll("SELECT * FROM categories ORDER BY name");

    return res.json({ categories });
});
```

The cache key is derived from the SQL query and its parameters. Different queries or different parameters produce different cache keys:

```typescript
// These are cached separately:
await db.fetchAll("SELECT * FROM products WHERE category = :cat", { cat: "Electronics" });
await db.fetchAll("SELECT * FROM products WHERE category = :cat", { cat: "Fitness" });
```

### When to Use DB Cache

- Read-heavy applications where the same queries run over and over
- Reference data that changes seldom (categories, countries, settings)
- Dashboard queries that aggregate large datasets

### When Not to Use DB Cache

- Write-heavy applications where data changes on every request
- Queries with real-time requirements (inventory counts, live prices)
- Queries that must return the latest data at all times

### Skipping Cache for Specific Queries

```typescript
// Force a fresh query, bypassing the cache
const freshData = await db.fetchAll("SELECT * FROM products", { noCache: true });
```

---

## 8. Cache Invalidation Strategies

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
import { Router, cacheSet, cacheDelete } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.put("/api/products/{id:int}", async (req, res) => {
    const productId = req.params.id;
    const body = req.body;
    const db = Database.getConnection();

    await db.execute(
        "UPDATE products SET name = :name, price = :price WHERE id = :id",
        { name: body.name, price: body.price, id: productId }
    );

    // Invalidate the cache for this product
    await cacheDelete(`product:${productId}`);

    // Also invalidate any list caches that might include this product
    await cacheDelete("products:all");
    await cacheDelete("products:featured");

    const updated = await db.fetchOne("SELECT * FROM products WHERE id = :id", { id: productId });

    return res.json(updated);
});
```

This is the most accurate strategy -- the cache is fresh after every write. The downside: you must remember to invalidate every key that holds the affected data.

### Strategy 3: Write-Through Cache

Update the cache at the same time as the database:

```typescript
Router.put("/api/products/{id:int}", async (req, res) => {
    const productId = req.params.id;
    const body = req.body;
    const db = Database.getConnection();

    await db.execute(
        "UPDATE products SET name = :name, price = :price WHERE id = :id",
        { name: body.name, price: body.price, id: productId }
    );

    const updated = await db.fetchOne("SELECT * FROM products WHERE id = :id", { id: productId });

    // Write the new data to cache (instead of deleting)
    await cacheSet(`product:${productId}`, updated, 600);

    return res.json(updated);
});
```

This ensures the cache holds the latest data at all times. No cache miss after an update -- the next read comes from the already-warm cache.

### Choosing a Strategy

| Strategy | Best For | Tradeoff |
|----------|----------|----------|
| TTL | Read-heavy, tolerates staleness | Stale data for up to TTL duration |
| Event-based | Consistency matters | Every write must invalidate |
| Write-through | High traffic, frequent updates | Every write does cache work |

Combine them. Use TTL as a safety net (entries expire even if invalidation misses). Use event-based invalidation for immediate consistency on critical data.

---

## 9. TTL Management

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

Adjust TTL based on data characteristics:

```typescript
import { Router, cacheGet, cacheSet } from "tina4-nodejs";

async function getCachedProduct(productId: number) {
    const cacheKey = `product:${productId}`;
    let product = await cacheGet(cacheKey);

    if (product !== null) {
        return product;
    }

    product = await fetchProductFromDatabase(productId);

    // Popular products: shorter TTL (more likely to change)
    // Inactive products: longer TTL (rarely change)
    const ttl = product.viewCount > 1000 ? 60 : 3600;

    await cacheSet(cacheKey, product, ttl);

    return product;
}
```

---

## 10. Cache Statistics

Monitor cache performance to verify that caching helps:

```typescript
import { Router, cacheStats } from "tina4-nodejs";

Router.get("/api/cache/stats", async (req, res) => {
    const stats = await cacheStats();
    return res.json(stats);
});
```

```bash
curl http://localhost:7145/api/cache/stats
```

```json
{
  "backend": "memory",
  "entries": 42,
  "hits": 15234,
  "misses": 891,
  "hit_rate": "94.5%",
  "memory_bytes": 524288,
  "oldest_entry_age": 3542
}
```

Hit rate above 90%: your caching strategy works. Below 80%: TTLs are too short, the cache is too small, or you are caching data that is not accessed often enough to benefit.

The dev dashboard at `/__dev` shows cache statistics too -- per-key hit counts and miss counts. You see which keys earn their keep.

---

## 11. Combining Cache Layers

For maximum performance, layer multiple cache strategies:

```typescript
import { Router, cacheGet, cacheSet } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/catalog", async (req, res) => {
    const page = parseInt(req.query.page ?? "1", 10);
    const cacheKey = `catalog:page:${page}`;

    // Layer 1: Check application cache
    const cached = await cacheGet(cacheKey);

    if (cached !== null) {
        return res.json({ ...cached, cache: "application" });
    }

    // Layer 2: Database query (with DB-level caching if TINA4_DB_CACHE=true)
    const db = Database.getConnection();
    const limit = 20;
    const offset = (page - 1) * limit;

    const products = await db.fetchAll(
        `SELECT p.*, c.name as category_name
         FROM products p
         JOIN categories c ON p.category_id = c.id
         WHERE p.active = 1
         ORDER BY p.created_at DESC
         LIMIT :limit OFFSET :offset`,
        { limit, offset }
    );

    const total = await db.fetchOne("SELECT COUNT(*) as count FROM products WHERE active = 1");

    const catalog = {
        products,
        page,
        total: total.count,
        pages: Math.ceil(total.count / limit),
        generated_at: new Date().toISOString()
    };

    // Store in application cache
    await cacheSet(cacheKey, catalog, 300);

    return res.json({ ...catalog, cache: "none" });
}, "ResponseCache:60");
```

This creates three cache layers:

1. **ResponseCache** (60 seconds): The entire HTTP response is cached. No JavaScript code runs at all.
2. **Application cache** (300 seconds): If the response cache expired but the app cache is still fresh, skip the database queries.
3. **DB query cache** (if enabled): Individual query results are cached even if the application cache missed.

The first visitor after a full cache expiry waits 800ms. Everyone else gets the response in under 5ms.

---

## 12. Exercise: Cache an Expensive Product Listing Endpoint

Build a product listing endpoint that uses caching at multiple levels.

### Requirements

1. Create a `GET /api/store/products` endpoint that:
   - Accepts query parameters: `category`, `page`, `limit`
   - Returns a list of products with pagination metadata
   - Uses the direct cache API (`cacheGet`/`cacheSet`) with a 5-minute TTL
   - Includes a `source` field in the response (`"cache"` or `"database"`)

2. Create a `POST /api/store/products` endpoint that:
   - Creates a new product
   - Invalidates the relevant cache entries

3. Create a `GET /api/store/cache-stats` endpoint that shows cache statistics

### Test with:

```bash
# First call -- cache miss, slow
curl "http://localhost:7145/api/store/products?category=Electronics&page=1"

# Second call -- cache hit, fast
curl "http://localhost:7145/api/store/products?category=Electronics&page=1"

# Different category -- cache miss
curl "http://localhost:7145/api/store/products?category=Fitness&page=1"

# Create a product -- should invalidate cache
curl -X POST http://localhost:7145/api/store/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Smart Watch", "category": "Electronics", "price": 299.99}'

# Same query again -- cache miss (invalidated by the POST)
curl "http://localhost:7145/api/store/products?category=Electronics&page=1"

# Check cache stats
curl http://localhost:7145/api/store/cache-stats
```

---

## 13. Solution

Create `src/routes/storeCached.ts`:

```typescript
import { Router, cacheGet, cacheSet, cacheDelete, cacheStats } from "tina4-nodejs";
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


Router.get("/api/store/products", async (req, res) => {
    const category = req.query.category ?? null;
    const page = parseInt(req.query.page ?? "1", 10);
    const limit = parseInt(req.query.limit ?? "20", 10);

    // Build cache key from query parameters
    const keyData = JSON.stringify({ category, page, limit });
    const cacheKey = `store:products:${createHash("md5").update(keyData).digest("hex")}`;

    // Try cache first
    const cached = await cacheGet(cacheKey);

    if (cached !== null) {
        return res.json({ ...cached, source: "cache" });
    }

    // Simulate expensive database query
    await new Promise(resolve => setTimeout(resolve, 100));  // 100ms delay

    let products = getProductStore();

    // Filter by category
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
        generated_at: new Date().toISOString()
    };

    // Cache for 5 minutes
    await cacheSet(cacheKey, result, 300);

    return res.json({ ...result, source: "database" });
});


Router.post("/api/store/products", async (req, res) => {
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

    // Invalidate all product list caches
    const categories = ["Electronics", "Fitness", "Kitchen", "General"];
    for (const cat of categories) {
        for (let p = 1; p <= 5; p++) {
            const keyData = JSON.stringify({ category: cat, page: p, limit: 20 });
            await cacheDelete(
                `store:products:${createHash("md5").update(keyData).digest("hex")}`
            );
        }
    }

    // Also invalidate the unfiltered list
    for (let p = 1; p <= 5; p++) {
        const keyData = JSON.stringify({ category: null, page: p, limit: 20 });
        await cacheDelete(
            `store:products:${createHash("md5").update(keyData).digest("hex")}`
        );
    }

    return res.status(201).json({
        message: "Product created",
        product,
        cache_invalidated: true
    });
});


Router.get("/api/store/cache-stats", async (req, res) => {
    return res.json(await cacheStats());
});
```

**Expected output -- first call (cache miss):**

```bash
curl "http://localhost:7145/api/store/products?category=Electronics&page=1"
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
  "generated_at": "2026-03-22T14:30:00.000Z",
  "source": "database"
}
```

**Expected output -- second call (cache hit):**

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
  "generated_at": "2026-03-22T14:30:00.000Z",
  "source": "cache"
}
```

Notice: same `generated_at`, but `source` changed from `"database"` to `"cache"`. The handler did not run.

---

## 14. Gotchas

### 1. Caching Authenticated Responses

**Problem:** User A's profile is served to User B because the response was cached.

**Cause:** `ResponseCache` caches by URL alone. If `/api/profile` returns different data per user but all requests hit the same URL, the first user's response is served to everyone.

**Fix:** Do not use `ResponseCache` on user-specific endpoints. Use the direct cache API with user-specific keys instead: `await cacheSet(`profile:${userId}`, data, 300)`.

### 2. Cache Stampede

**Problem:** When a popular cache key expires, hundreds of requests hit the database at the same moment (all experiencing a cache miss together).

**Cause:** All requests see the cache miss and all try to rebuild the cache on their own.

**Fix:** Use cache locking or "stale-while-revalidate." One request rebuilds the cache while others serve the stale value. Tina4's `ResponseCache` handles this by serving the expired response to concurrent requests while one request refreshes it.

### 3. Memory Cache Lost on Restart

**Problem:** After restarting the server, performance drops until the cache warms up.

**Cause:** Memory cache is lost when the process restarts. Every request is a cache miss until data is cached again.

**Fix:** For production, use Redis cache (`TINA4_CACHE_BACKEND=redis`). It persists across server restarts. You can also implement a cache warmup script that pre-populates the cache with data your application accesses most.

### 4. Stale Data After Database Update

**Problem:** You updated a product's price in the database, but the API still returns the old price.

**Cause:** The cache still has the old data and has not expired yet.

**Fix:** Invalidate (or update) the cache when you modify the underlying data. Use `await cacheDelete(`product:${productId}`)` after an update, or use write-through caching with `cacheSet()` to update the cache with the new value.

### 5. Cache Key Collisions

**Problem:** Two different queries return the same cached data.

**Cause:** Your cache keys are not specific enough. Using `"products"` as a key for both the full list and a filtered list causes collisions.

**Fix:** Include all relevant parameters in the cache key: `"products:category:Electronics:page:1:limit:20"`. Or use an MD5 hash of the parameters: `` `products:${createHash("md5").update(JSON.stringify(params)).digest("hex")}` ``.

### 6. Serialization Overhead

**Problem:** Caching makes certain requests slower, not faster.

**Cause:** The cached object is large. Serializing and deserializing it takes more time than re-computing it.

**Fix:** Only cache data that is expensive to compute. If the original operation takes 5ms and cache serialization takes 10ms, caching is counterproductive. Profile before and after caching to verify the improvement.

### 7. Forgetting to Set TTL

**Problem:** Cache entries never expire and the server's memory grows until it crashes.

**Cause:** You called `await cacheSet("key", value)` without a TTL. The entry lives forever (or until the server restarts).

**Fix:** Set a TTL on every entry: `await cacheSet("key", value, 300)`. Even for data that "never changes," set a long TTL like 86400 (24 hours). This provides a safety net against stale data and prevents unbounded memory growth.
