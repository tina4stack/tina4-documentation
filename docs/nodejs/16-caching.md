# Chapter 14: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. 800 milliseconds to render. Every visitor triggers the same queries for data that changes once a day.

Add caching. The first request takes 800ms. The next 10,000 take 3ms each.

Tina4 caches at three levels: response caching, database query caching, and a direct cache API.

---

## 2. Response Caching with ResponseCache Middleware

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/products", async (req, res) => {
    console.log("Handler called -- should only appear once every 5 minutes");

    const products = [
        { id: 1, name: "Wireless Keyboard", price: 79.99 },
        { id: 2, name: "USB-C Hub", price: 49.99 }
    ];

    return res.json({ products, generated_at: new Date().toISOString() });
}, "ResponseCache:300");
```

The `"ResponseCache:300"` caches the response for 300 seconds.

### Cache Headers

```
X-Cache: HIT
X-Cache-TTL: 247
Cache-Control: public, max-age=300
```

### What Not to Cache

Do not use `ResponseCache` on POST/PUT/DELETE routes, user-specific endpoints, or real-time data.

---

## 3. Memory Cache (Default)

```dotenv
TINA4_CACHE_BACKEND=memory
```

The fastest option. Data lives in memory. Server restart wipes it clean.

---

## 4. Redis Cache

```dotenv
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_HOST=localhost
TINA4_CACHE_PORT=6379
TINA4_CACHE_PREFIX=myapp:cache:
```

---

## 5. File Cache

```dotenv
TINA4_CACHE_BACKEND=file
TINA4_CACHE_PATH=/path/to/cache/directory
```

---

## 6. Direct Cache API

```typescript
import { cacheGet, cacheSet, cacheDelete } from "tina4-nodejs";

// Set a value with TTL
await cacheSet("product:42", { id: 42, name: "Keyboard", price: 79.99 }, 300);

// Get a value
const product = await cacheGet("product:42");

// Delete a value
await cacheDelete("product:42");
```

### Cache-Aside Pattern

```typescript
import { Router, cacheGet, cacheSet } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/products/{id:int}", async (req, res) => {
    const id = req.params.id;
    const cacheKey = `product:${id}`;

    let product = await cacheGet(cacheKey);

    if (product !== null) {
        return res.json({ ...product, source: "cache" });
    }

    const db = Database.getConnection();
    product = await db.fetchOne("SELECT * FROM products WHERE id = :id", { id });

    if (product === null) {
        return res.status(404).json({ error: "Product not found" });
    }

    await cacheSet(cacheKey, product, 600);

    return res.json({ ...product, source: "database" });
});
```

---

## 7. Database Query Caching

```dotenv
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=300
```

Identical queries with identical parameters return cached results. The cache key is the SQL statement plus its parameters. Change either and the cache treats it as a new query.

---

## 8. Cache Invalidation Strategies

Cache invalidation is the hard problem. Stale data is worse than no cache. Three strategies solve it.

### Strategy 1: Time-Based Expiry (TTL)

Set a TTL and let the cache expire on its own:

```typescript
await cacheSet("products:featured", featuredProducts, 600);
```

After 600 seconds, the next request misses the cache, fetches from the database, and repopulates. Simple. Works for data that tolerates staleness -- product catalogs, configuration, public content.

### Strategy 2: Event-Based Invalidation

Delete the cache entry when the underlying data changes:

```typescript
Router.put("/api/products/{id:int}", async (req, res) => {
    // Update the database
    const product = Product.findById(req.params.id);
    product.name = req.body.name ?? product.name;
    product.save();

    // Invalidate related cache entries
    await cacheDelete(`product:${req.params.id}`);
    await cacheDelete("products:all");
    await cacheDelete("products:featured");

    return res.json(product.toDict());
});
```

The next read triggers a fresh database query. No stale data. More code -- every write must know which cache keys to invalidate.

### Strategy 3: Write-Through Cache

Update the cache at the same time you update the database:

```typescript
Router.put("/api/products/{id:int}", async (req, res) => {
    const product = Product.findById(req.params.id);
    product.name = req.body.name ?? product.name;
    product.save();

    // Write the fresh data to cache immediately
    await cacheSet(`product:${req.params.id}`, product.toDict(), 600);

    return res.json(product.toDict());
});
```

The next read hits the cache immediately -- no database roundtrip. Best for high-traffic data that changes often. The tradeoff: every write does extra work.

### Choosing a Strategy

| Strategy | Best For | Tradeoff |
|----------|----------|----------|
| TTL | Read-heavy, tolerates staleness | Stale data for up to TTL duration |
| Event-based | Consistency matters | Every write must invalidate |
| Write-through | High traffic, frequent updates | Every write does cache work |

Combine them. Use TTL as a safety net (entries expire even if invalidation misses). Use event-based invalidation for immediate consistency on critical data.

---

## 9. TTL Management

### Suggested TTLs by Data Type

| Data Type | Suggested TTL | Rationale |
|-----------|---------------|-----------|
| Static config | 3600 (1 hour) | Rarely changes |
| Product catalog | 300 (5 min) | Updates a few times per day |
| User profile | 60 (1 min) | Users expect quick updates |
| Dashboard stats | 30 (30 sec) | Frequently changing aggregates |
| Search results | 120 (2 min) | Expensive queries, tolerable staleness |
| Shopping cart | 0 (no cache) | Must be real-time |

### Dynamic TTL

Set TTL based on data characteristics:

```typescript
Router.get("/api/products/{id:int}", async (req, res) => {
    const product = Product.findById(req.params.id);

    // Popular products change more often -- shorter TTL
    const ttl = product.views > 1000 ? 60 : 300;

    await cacheSet(`product:${product.id}`, product.toDict(), ttl);

    return res.json(product.toDict());
});
```

---

## 10. Cache Statistics

```typescript
import { cacheStats } from "tina4-nodejs";

Router.get("/api/cache/stats", async (req, res) => {
    return res.json(await cacheStats());
});
```

---

## 11. Exercise: Cache an Expensive Product Listing

Build `GET /api/store/products` with direct cache API (5-min TTL), `POST /api/store/products` that invalidates cache, and `GET /api/store/cache-stats`.

---

## 12. Solution

```typescript
import { Router, cacheGet, cacheSet, cacheDelete, cacheStats } from "tina4-nodejs";
import { createHash } from "crypto";

function getProductStore() {
    return [
        { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99, inStock: true },
        { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true },
        { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99, inStock: false }
    ];
}

Router.get("/api/store/products", async (req, res) => {
    const category = req.query.category ?? null;
    const page = parseInt(req.query.page ?? "1", 10);
    const limit = parseInt(req.query.limit ?? "20", 10);

    const cacheKey = `store:products:${createHash("md5").update(JSON.stringify({ category, page, limit })).digest("hex")}`;

    const cached = await cacheGet(cacheKey);
    if (cached !== null) {
        return res.json({ ...cached, source: "cache" });
    }

    let products = getProductStore();
    if (category) {
        products = products.filter(p => p.category.toLowerCase() === String(category).toLowerCase());
    }

    const result = {
        products,
        page,
        limit,
        total: products.length,
        generated_at: new Date().toISOString()
    };

    await cacheSet(cacheKey, result, 300);
    return res.json({ ...result, source: "database" });
});

Router.post("/api/store/products", async (req, res) => {
    if (!req.body.name) {
        return res.status(400).json({ error: "Name is required" });
    }
    // Invalidate caches (simplified)
    await cacheDelete("store:products:*");

    return res.status(201).json({ message: "Product created", cache_invalidated: true });
});

Router.get("/api/store/cache-stats", async (req, res) => {
    return res.json(await cacheStats());
});
```

---

## 13. Gotchas

### 1. Caching Authenticated Responses

**Fix:** Do not use `ResponseCache` on user-specific endpoints. Use user-specific cache keys.

### 2. Cache Stampede

**Fix:** Tina4's `ResponseCache` handles this with stale-while-revalidate.

### 3. Memory Cache Lost on Restart

**Fix:** Use Redis for production.

### 4. Stale Data After Database Update

**Fix:** Always invalidate or update cache after writes.

### 5. Cache Key Collisions

**Fix:** Include all relevant parameters in the cache key.

### 6. Serialization Overhead

**Fix:** Only cache data that is expensive to compute.

### 7. Forgetting to Set TTL

**Fix:** Always set a TTL to prevent unbounded memory growth.
