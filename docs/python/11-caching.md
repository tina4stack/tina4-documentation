# Chapter 11: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. 800 milliseconds to render. Every visitor triggers the same queries, the same template rendering, the same JSON serialization -- for data that changes once a day.

Add caching. The first request takes 800ms. The next 10,000 take 3ms each. A 266x improvement from one line of configuration.

Caching stores the result of expensive operations for reuse. Tina4 provides three levels: response caching (entire HTTP responses), database query caching, and a direct cache API for custom use cases.

---

## 2. Response Caching with ResponseCache Middleware

The fastest way to cache is at the HTTP response level. The `ResponseCache` middleware stores the complete response (headers and body) and serves it directly on subsequent requests without calling your route handler at all.

```python
from tina4_python.core.router import get

@get("/api/products", middleware=["ResponseCache:300"])
async def list_products(request, response):
    # This handler runs 12 database queries and takes 800ms
    # With ResponseCache, it only runs once every 5 minutes

    print("Handler called -- this should only appear once every 5 minutes")

    products = [
        {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
        {"id": 2, "name": "USB-C Hub", "price": 49.99},
        {"id": 3, "name": "Monitor Stand", "price": 129.99}
    ]

    return response({"products": products, "generated_at": datetime.now(timezone.utc).isoformat()})
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
  "generated_at": "2026-03-22T14:30:00+00:00"
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
  "generated_at": "2026-03-22T14:30:00+00:00"
}
```

Notice the `generated_at` timestamp is the same. The handler did not run -- the response came from cache.

### Cache Headers

The `ResponseCache` middleware automatically sets cache-related headers:

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

```python
@get("/api/products", middleware=["ResponseCache:300"])
async def list_products(request, response):
    page = int(request.params.get("page", 1))
    limit = 20
    offset = (page - 1) * limit

    return response({
        "page": page,
        "products": [],
        "generated_at": datetime.now(timezone.utc).isoformat()
    })
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

```python
# GOOD: Public, rarely changing data
@get("/api/categories", middleware=["ResponseCache:3600"])
async def list_categories(request, response):
    return response({"categories": []})

# BAD: User-specific data -- do NOT cache
@get("/api/profile", middleware=["auth_middleware"])
async def get_profile(request, response):
    return response(request.user)
```

---

## 3. Memory Cache (Default)

Tina4's cache system stores data in memory by default. No configuration needed.

```bash
# This is the default -- you do not need to set it explicitly
TINA4_CACHE_BACKEND=memory
```

Memory cache is the fastest option (no disk I/O, no network calls) but it resets when the server restarts. It is ideal for development and single-server deployments where losing the cache on restart is acceptable.

---

## 4. Redis Cache

For production deployments where you want cache persistence across server restarts and shared cache across multiple server instances, use Redis:

```bash
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_HOST=localhost
TINA4_CACHE_PORT=6379
TINA4_CACHE_PASSWORD=your-redis-password
TINA4_CACHE_PREFIX=myapp:cache:
```

Your code does not change. The `cache_get`, `cache_set`, and `ResponseCache` middleware all work identically. Only the storage backend changes.

### Why Redis?

- Cache survives server restarts
- Shared across multiple server instances (behind a load balancer)
- Sub-millisecond reads and writes
- Built-in key expiry (TTL cleanup is automatic)
- Same Redis instance can serve sessions, cache, and queues

---

## 5. File Cache

If you want cache persistence but do not have Redis, use file-based caching:

```bash
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

For custom caching logic, use the `cache_get`, `cache_set`, and `cache_delete` functions directly:

### cache_set

```python
from tina4_python.cache import cache_set

# Cache a value for 300 seconds
cache_set("product:42", {
    "id": 42,
    "name": "Wireless Keyboard",
    "price": 79.99,
    "in_stock": True
}, ttl=300)

# Cache a string
cache_set("exchange_rate:USD_EUR", "0.92", ttl=3600)

# Cache indefinitely (no TTL)
cache_set("app:config", {"theme": "dark", "lang": "en"})
```

### cache_get

```python
from tina4_python.cache import cache_get, cache_set

product = cache_get("product:42")
# Returns the cached value, or None if not found or expired

if product is None:
    # Cache miss -- fetch from database
    product = fetch_product_from_database(42)
    cache_set("product:42", product, ttl=300)

return response(product)
```

### cache_delete

```python
from tina4_python.cache import cache_delete

# Delete a specific key
cache_delete("product:42")

# Delete multiple keys
cache_delete("product:42")
cache_delete("product:43")
cache_delete("product:44")
```

### Real-World Pattern: Cache-Aside

The most common caching pattern is cache-aside (also called lazy loading):

```python
from tina4_python.core.router import get
from tina4_python.cache import cache_get, cache_set

@get("/api/products/{product_id}")
async def get_product(request, response):
    product_id = request.params["product_id"]
    cache_key = f"product:{product_id}"

    # 1. Try the cache first
    product = cache_get(cache_key)

    if product is not None:
        # Cache hit -- return immediately
        return response({**product, "source": "cache"})

    # 2. Cache miss -- fetch from database
    db = Database.get_connection()
    product = db.fetch_one(
        "SELECT id, name, category, price, in_stock FROM products WHERE id = ?",
        [product_id]
    )

    if product is None:
        return response({"error": "Product not found"}, 404)

    # 3. Store in cache for next time
    cache_set(cache_key, product, ttl=600)  # Cache for 10 minutes

    return response({**product, "source": "database"})
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

Tina4 can cache database query results automatically. Enable it in `.env`:

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=300
```

With database caching enabled, identical queries return cached results instead of hitting the database:

```python
from tina4_python.core.router import get

@get("/api/categories")
async def list_categories(request, response):
    db = Database.get_connection()

    # First call: executes the query (20ms)
    # Subsequent calls within 300 seconds: returns cached result (0.1ms)
    categories = db.fetch_all("SELECT * FROM categories ORDER BY name")

    return response({"categories": categories})
```

The cache key is derived from the SQL query and its parameters. Different queries or different parameters produce different cache keys:

```python
# These are cached separately:
db.fetch_all("SELECT * FROM products WHERE category = ?", ["Electronics"])
db.fetch_all("SELECT * FROM products WHERE category = ?", ["Fitness"])
```

### When to Use DB Cache

- Read-heavy applications where the same queries run repeatedly
- Reference data that changes infrequently (categories, countries, settings)
- Dashboard queries that aggregate large datasets

### When Not to Use DB Cache

- Write-heavy applications where data changes constantly
- Queries with real-time requirements (inventory counts, live prices)
- Queries that must always return the latest data

### Skipping Cache for Specific Queries

```python
# Force a fresh query, bypassing the cache
fresh_data = db.fetch_all("SELECT * FROM products", no_cache=True)
```

---

## 8. Cache Invalidation Strategies

Cache invalidation is the hard problem. Stale cache serves outdated data. Premature invalidation throws away performance gains. Three strategies handle this.

### Strategy 1: Time-Based Expiry (TTL)

The simplest strategy. Set a TTL and let the cache expire naturally:

```python
cache_set("products:featured", featured_products, ttl=600)  # Expires in 10 minutes
```

Good for data where near-real-time accuracy is acceptable. A 10-minute delay in updating the featured products list is usually fine.

### Strategy 2: Event-Based Invalidation

Clear the cache when the underlying data changes:

```python
from tina4_python.core.router import put
from tina4_python.cache import cache_set, cache_delete

@put("/api/products/{product_id}")
async def update_product(request, response):
    product_id = request.params["product_id"]
    body = request.body
    db = Database.get_connection()

    db.execute(
        "UPDATE products SET name = ?, price = ? WHERE id = ?",
        [body["name"], body["price"], product_id]
    )

    # Invalidate the cache for this product
    cache_delete(f"product:{product_id}")

    # Also invalidate any list caches that might include this product
    cache_delete("products:all")
    cache_delete("products:featured")

    updated = db.fetch_one("SELECT * FROM products WHERE id = ?", [product_id])

    return response(updated)
```

This is the most accurate strategy -- the cache is always fresh after a write. The downside is you must remember to invalidate everywhere the data could be cached.

### Strategy 3: Write-Through Cache

Update the cache at the same time as the database:

```python
@put("/api/products/{product_id}")
async def update_product(request, response):
    product_id = request.params["product_id"]
    body = request.body
    db = Database.get_connection()

    db.execute(
        "UPDATE products SET name = ?, price = ? WHERE id = ?",
        [body["name"], body["price"], product_id]
    )

    updated = db.fetch_one("SELECT * FROM products WHERE id = ?", [product_id])

    # Write the new data directly to cache (instead of deleting)
    cache_set(f"product:{product_id}", updated, ttl=600)

    return response(updated)
```

This ensures the cache always has the latest data. No cache miss after an update -- the next read comes from the already-warm cache.

---

## 9. TTL Management

Choosing the right TTL depends on how often the data changes and how acceptable stale data is:

| Data Type | Suggested TTL | Reasoning |
|-----------|---------------|-----------|
| Static config (categories, countries) | 3600 (1 hour) | Changes rarely, stale data is harmless |
| Product catalog | 300 (5 min) | Updates several times per day |
| User profile | 60 (1 min) | Users expect changes to appear quickly |
| Search results | 120 (2 min) | Balance between freshness and performance |
| Dashboard stats | 30 (30 sec) | Near-real-time but expensive to compute |
| Exchange rates | 60 (1 min) | Updates frequently, slight delay is acceptable |
| Shopping cart | 0 (no cache) | Must always reflect current state |

### Dynamic TTL

Adjust TTL based on data characteristics:

```python
from tina4_python.cache import cache_get, cache_set

def get_cached_product(product_id):
    cache_key = f"product:{product_id}"
    product = cache_get(cache_key)

    if product is not None:
        return product

    product = fetch_product_from_database(product_id)

    # Popular products: shorter TTL (more likely to change)
    # Inactive products: longer TTL (rarely change)
    ttl = 60 if product["view_count"] > 1000 else 3600

    cache_set(cache_key, product, ttl=ttl)

    return product
```

---

## 10. Cache Statistics

Monitor cache performance to verify that caching is actually helping:

```python
from tina4_python.core.router import get
from tina4_python.cache import cache_stats

@get("/api/cache/stats")
async def get_cache_stats(request, response):
    stats = cache_stats()
    return response(stats)
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

Hit rate above 90%: your caching strategy works. Below 80%: TTLs are too short, cache is too small, or you are caching data that is not accessed often enough to benefit.

The dev dashboard at `/__dev` shows cache statistics too -- per-key hit counts and miss counts. You see which keys earn their keep.

---

## 11. Combining Cache Layers

For maximum performance, layer multiple cache strategies:

```python
from datetime import datetime, timezone
from tina4_python.core.router import get
from tina4_python.cache import cache_get, cache_set
import math

@get("/api/catalog", middleware=["ResponseCache:60"])
async def get_catalog(request, response):
    page = int(request.params.get("page", 1))
    cache_key = f"catalog:page:{page}"

    # Layer 1: Check application cache
    catalog = cache_get(cache_key)

    if catalog is not None:
        return response({**catalog, "cache": "application"})

    # Layer 2: Database query (with DB-level caching if TINA4_DB_CACHE=true)
    db = Database.get_connection()
    limit = 20
    offset = (page - 1) * limit

    products = db.fetch_all(
        """SELECT p.*, c.name as category_name
           FROM products p
           JOIN categories c ON p.category_id = c.id
           WHERE p.active = 1
           ORDER BY p.created_at DESC
           LIMIT ? OFFSET ?""",
        [limit, offset]
    )

    total = db.fetch_one("SELECT COUNT(*) as count FROM products WHERE active = 1")

    catalog = {
        "products": products,
        "page": page,
        "total": total["count"],
        "pages": math.ceil(total["count"] / limit),
        "generated_at": datetime.now(timezone.utc).isoformat()
    }

    # Store in application cache
    cache_set(cache_key, catalog, ttl=300)

    return response({**catalog, "cache": "none"})
```

This creates three cache layers:

1. **ResponseCache** (60 seconds): The entire HTTP response is cached. No Python code runs at all.
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
   - Uses the direct cache API (`cache_get`/`cache_set`) with a 5-minute TTL
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

Create `src/routes/store_cached.py`:

```python
import json
import time
import hashlib
from datetime import datetime, timezone
from tina4_python.core.router import get, post
from tina4_python.cache import cache_get, cache_set, cache_delete, cache_stats


def get_product_store():
    return [
        {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": True},
        {"id": 2, "name": "Yoga Mat", "category": "Fitness", "price": 29.99, "in_stock": True},
        {"id": 3, "name": "Coffee Grinder", "category": "Kitchen", "price": 49.99, "in_stock": False},
        {"id": 4, "name": "Standing Desk", "category": "Electronics", "price": 549.99, "in_stock": True},
        {"id": 5, "name": "Running Shoes", "category": "Fitness", "price": 119.99, "in_stock": True},
        {"id": 6, "name": "Bluetooth Speaker", "category": "Electronics", "price": 39.99, "in_stock": True},
        {"id": 7, "name": "Resistance Bands", "category": "Fitness", "price": 14.99, "in_stock": True},
        {"id": 8, "name": "French Press", "category": "Kitchen", "price": 34.99, "in_stock": True},
    ]


@get("/api/store/products")
async def list_store_products(request, response):
    category = request.params.get("category")
    page = int(request.params.get("page", 1))
    limit = int(request.params.get("limit", 20))

    # Build cache key from query parameters
    key_data = json.dumps({"category": category, "page": page, "limit": limit})
    cache_key = f"store:products:{hashlib.md5(key_data.encode()).hexdigest()}"

    # Try cache first
    cached = cache_get(cache_key)

    if cached is not None:
        return response({**cached, "source": "cache"})

    # Simulate expensive database query
    time.sleep(0.1)  # 100ms delay

    products = get_product_store()

    # Filter by category
    if category is not None:
        products = [p for p in products if p["category"].lower() == category.lower()]

    total = len(products)
    offset = (page - 1) * limit
    products = products[offset:offset + limit]

    import math
    result = {
        "products": products,
        "page": page,
        "limit": limit,
        "total": total,
        "pages": math.ceil(total / limit),
        "generated_at": datetime.now(timezone.utc).isoformat()
    }

    # Cache for 5 minutes
    cache_set(cache_key, result, ttl=300)

    return response({**result, "source": "database"})


@post("/api/store/products")
async def create_store_product(request, response):
    body = request.body

    if not body.get("name"):
        return response({"error": "Name is required"}, 400)

    import random
    product = {
        "id": random.randint(100, 9999),
        "name": body["name"],
        "category": body.get("category", "General"),
        "price": float(body.get("price", 0)),
        "in_stock": True
    }

    # Invalidate all product list caches
    categories = ["Electronics", "Fitness", "Kitchen", "General"]
    for cat in categories:
        for p in range(1, 6):
            key_data = json.dumps({"category": cat, "page": p, "limit": 20})
            cache_delete(f"store:products:{hashlib.md5(key_data.encode()).hexdigest()}")

    # Also invalidate the unfiltered list
    for p in range(1, 6):
        key_data = json.dumps({"category": None, "page": p, "limit": 20})
        cache_delete(f"store:products:{hashlib.md5(key_data.encode()).hexdigest()}")

    return response({
        "message": "Product created",
        "product": product,
        "cache_invalidated": True
    }, 201)


@get("/api/store/cache-stats")
async def store_cache_stats(request, response):
    return response(cache_stats())
```

**Expected output -- first call (cache miss):**

```bash
curl "http://localhost:7145/api/store/products?category=Electronics&page=1"
```

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": true},
    {"id": 4, "name": "Standing Desk", "category": "Electronics", "price": 549.99, "in_stock": true},
    {"id": 6, "name": "Bluetooth Speaker", "category": "Electronics", "price": 39.99, "in_stock": true}
  ],
  "page": 1,
  "limit": 20,
  "total": 3,
  "pages": 1,
  "generated_at": "2026-03-22T14:30:00+00:00",
  "source": "database"
}
```

**Expected output -- second call (cache hit):**

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": true},
    {"id": 4, "name": "Standing Desk", "category": "Electronics", "price": 549.99, "in_stock": true},
    {"id": 6, "name": "Bluetooth Speaker", "category": "Electronics", "price": 39.99, "in_stock": true}
  ],
  "page": 1,
  "limit": 20,
  "total": 3,
  "pages": 1,
  "generated_at": "2026-03-22T14:30:00+00:00",
  "source": "cache"
}
```

Notice: same `generated_at`, but `source` changed from `"database"` to `"cache"`. The handler did not run.

---

## 14. Gotchas

### 1. Caching Authenticated Responses

**Problem:** User A's profile is served to User B because the response was cached.

**Cause:** `ResponseCache` caches by URL only. If `/api/profile` returns different data per user but all requests hit the same URL, the first user's response is served to everyone.

**Fix:** Do not use `ResponseCache` on user-specific endpoints. Use the direct cache API with user-specific keys instead: `cache_set(f"profile:{user_id}", data, ttl=300)`.

### 2. Cache Stampede

**Problem:** When a popular cache key expires, hundreds of requests hit the database simultaneously (all experiencing a cache miss at the same moment).

**Cause:** All requests see the cache miss and all try to rebuild the cache independently.

**Fix:** Use cache locking or "stale-while-revalidate". One request rebuilds the cache while others serve the stale value. Tina4's `ResponseCache` handles this automatically by serving the expired response to concurrent requests while one request refreshes it.

### 3. Memory Cache Lost on Restart

**Problem:** After restarting the server, performance drops until the cache warms up.

**Cause:** Memory cache is lost when the process restarts. Every request is a cache miss until data is cached again.

**Fix:** For production, use Redis cache (`TINA4_CACHE_BACKEND=redis`). It persists across server restarts. Alternatively, implement a cache warmup script that pre-populates the cache with frequently accessed data.

### 4. Stale Data After Database Update

**Problem:** You updated a product's price in the database, but the API still returns the old price.

**Cause:** The cache still has the old data and has not expired yet.

**Fix:** Always invalidate (or update) the cache when you modify the underlying data. Use `cache_delete(f"product:{product_id}")` after an update, or use write-through caching with `cache_set()` to update the cache with the new value.

### 5. Cache Key Collisions

**Problem:** Two different queries return the same cached data.

**Cause:** Your cache keys are not specific enough. Using `"products"` as a key for both the full list and a filtered list causes collisions.

**Fix:** Include all relevant parameters in the cache key: `"products:category:Electronics:page:1:limit:20"`. Or use an MD5 hash of the parameters: `f"products:{hashlib.md5(json.dumps(params).encode()).hexdigest()}"`.

### 6. Serialization Overhead

**Problem:** Caching makes certain requests slower, not faster.

**Cause:** The cached object is very large. Serializing and deserializing it takes more time than re-computing it.

**Fix:** Only cache data that is expensive to compute. If the original operation takes 5ms and cache serialization takes 10ms, caching is counterproductive. Profile before and after caching to verify the improvement.

### 7. Forgetting to Set TTL

**Problem:** Cache entries never expire and the server's memory grows until it crashes.

**Cause:** You called `cache_set("key", value)` without a TTL. The entry lives forever (or until the server restarts).

**Fix:** Always set a TTL: `cache_set("key", value, ttl=300)`. Even for data that "never changes," set a long TTL like 86400 (24 hours). This provides a safety net against stale data and prevents unbounded memory growth.
