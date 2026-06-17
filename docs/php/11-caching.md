# Chapter 11: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. It takes 800 milliseconds to render. Every visitor triggers the same queries, the same template rendering, the same JSON serialization -- for data that changes once a day.

Add caching. The first request takes 800ms. The next 10,000 take 3ms each. A 266x improvement. One line of configuration.

Caching stores the result of expensive operations for reuse. Tina4 gives you three layers, and you reach for them in this order:

1. **Request-scoped query cache** -- on by default. Dedupes identical SELECTs inside a single request.
2. **Persistent database cache** -- opt-in. Shares query results across requests with a TTL.
3. **Response cache** -- the `ResponseCache` middleware. Stores whole HTTP responses and skips your handler entirely.

This chapter walks each layer, then shows the direct key/value API and how to combine the layers.

---

## 2. Layer 1: Request-Scoped Query Cache (On by Default)

Tina4 wraps every database connection in a query cache. The first layer runs automatically. When a request fires the same SELECT twice, the second call returns the first result instead of hitting the database again.

```bash
# These are the defaults -- you do not need to set them
TINA4_AUTO_CACHING=true
TINA4_AUTO_CACHING_TTL=5
```

The cache key derives from the SQL and its parameters. The dispatcher clears this cache at the **start** of every HTTP request, so it never serves stale rows across requests. Any write (`insert`, `update`, `delete`, `execute`) flushes it immediately. The 5-second TTL is a safety net for long-running CLI scripts and workers that live outside the request cycle.

```php
<?php
use Tina4\Router;
use Tina4\Database\Database;

Router::get("/api/report", function ($request, $response) {
    $db = Database::getConnection();

    // First call hits the database.
    $totals = $db->fetchAll("SELECT category, count(*) c FROM products GROUP BY category");

    // Same SQL again in this request -- served from the request-scoped cache.
    $alsoTotals = $db->fetchAll("SELECT category, count(*) c FROM products GROUP BY category");

    return $response->json(["totals" => $totals]);
});
```

To turn this layer off, set `TINA4_AUTO_CACHING=false`.

---

## 3. Layer 2: Persistent Database Cache (Opt-In)

The request-scoped cache dies at the end of each request. For results that stay fresh across requests -- reference data, category lists, slow aggregates -- enable the persistent layer:

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=30
```

Now identical queries return cached results across requests until the TTL expires:

```php
<?php
use Tina4\Router;
use Tina4\Database\Database;

Router::get("/api/categories", function ($request, $response) {
    $db = Database::getConnection();

    // First call: executes the query (20ms)
    // Subsequent calls within 30 seconds: returns the cached result (0.1ms)
    $categories = $db->fetchAll("SELECT * FROM categories ORDER BY name");

    return $response->json(["categories" => $categories]);
});
```

The persistent cache routes through the unified backend. Pick where it lives and point it at a server:

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=30
TINA4_DB_CACHE_BACKEND=redis              # memory (default), file, redis, valkey, memcached, mongodb, database
TINA4_DB_CACHE_URL=redis://localhost:6379
```

With a network backend like Redis, multiple server instances share one cache, and a write on any instance invalidates the shared cache for all of them.

### When to Use the Persistent Cache

- Read-heavy applications where the same queries run repeatedly
- Reference data that changes rarely (categories, countries, settings)
- Dashboard queries that aggregate large datasets

### When Not to Use It

- Write-heavy applications where data changes constantly
- Queries with real-time requirements (inventory counts, live prices)
- Queries that must return the latest data

### Bypassing the Cache for One Query

Every read method takes a final `$noCache` flag. Pass `true` to skip both the lookup and the store for that one call -- it runs straight against the database, in either cache mode:

```php
$db = Database::getConnection();

// fetch($sql, $params, $limit, $offset, $noCache)
$fresh = $db->fetch("SELECT * FROM products", [], 100, 0, true);

// fetchOne($sql, $params, $noCache)
$row = $db->fetchOne("SELECT * FROM products WHERE id = :id", ["id" => 42], true);

// fetchAll($sql, $params, $limit, $offset, $noCache)
$all = $db->fetchAll("SELECT * FROM products", [], 0, 0, true);
```

### Inspecting the Query Cache

`$db->cacheStats()` reports the live state of the query cache:

```php
Router::get("/api/db-cache/stats", function ($request, $response) {
    $db = \Tina4\Database\Database::getConnection();
    return $response->json($db->cacheStats());
});
```

```json
{
  "enabled": true,
  "mode": "persistent",
  "hits": 1842,
  "misses": 96,
  "size": 12,
  "ttl": 30,
  "backend": "redis"
}
```

`mode` is `"request"` (layer 1 only), `"persistent"` (layer 2 on), or `"off"`. Call `$db->cacheClear()` to flush the query cache and reset the counters.

---

## 4. Layer 3: Response Caching with ResponseCache Middleware

The fastest cache is at the HTTP response level. The `ResponseCache` middleware stores the complete response -- body, status, and content type -- and serves it on subsequent GET requests without calling your route handler at all.

Attach it as a string spec with a TTL:

```php
<?php
use Tina4\Router;

Router::get("/api/products", function ($request, $response) {
    // This handler runs 12 database queries and takes 800ms
    // With ResponseCache, it only runs once every 5 minutes

    error_log("Handler called -- this should only appear once every 5 minutes");

    $products = [
        ["id" => 1, "name" => "Wireless Keyboard", "price" => 79.99],
        ["id" => 2, "name" => "USB-C Hub", "price" => 49.99],
        ["id" => 3, "name" => "Monitor Stand", "price" => 129.99]
    ];

    return $response->json(["products" => $products, "generated_at" => date("c")]);
})->middleware(["ResponseCache:300"]);
```

`"ResponseCache:300"` caches the response for 300 seconds (5 minutes). During those 5 minutes:

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

Same `generated_at` timestamp. The handler did not run. The response came from cache.

### Two Ways to Attach It

The string form parses a TTL after the colon. The class-array form uses the default TTL (`TINA4_CACHE_TTL`, 60 seconds). Both work:

```php
// String spec -- per-route TTL
Router::get("/api/products", $handler)->middleware(["ResponseCache:300"]);

// Class array -- default TTL from TINA4_CACHE_TTL
Router::get("/api/categories", $handler)->middleware([\Tina4\Middleware\ResponseCache::class]);
```

Two env vars tune the response cache globally: `TINA4_CACHE_TTL` (default 60, set 0 to disable) and `TINA4_CACHE_MAX_ENTRIES` (default 1000).

### Cache Headers

The `ResponseCache` middleware stamps two headers on every cacheable response:

```
X-Cache: HIT
X-Cache-TTL: 300
```

- `X-Cache: HIT` or `X-Cache: MISS` -- whether the response came from cache
- `X-Cache-TTL` -- the configured TTL in seconds

The middleware does not set a `Cache-Control` header.

### Caching with Query Parameters

The cache key is the request method plus the full URL, so `/api/products?page=1` and `/api/products?page=2` are cached separately:

```php
Router::get("/api/products", function ($request, $response) {
    $page = (int) ($request->params["page"] ?? 1);
    $limit = 20;
    $offset = ($page - 1) * $limit;

    // Simulate database query
    return $response->json([
        "page" => $page,
        "products" => [],
        "generated_at" => date("c")
    ]);
})->middleware(["ResponseCache:300"]);
```

```bash
curl "http://localhost:7145/api/products?page=1"  # Cache MISS, stores for page=1
curl "http://localhost:7145/api/products?page=2"  # Cache MISS, stores for page=2
curl "http://localhost:7145/api/products?page=1"  # Cache HIT
```

### What Not to Cache

`ResponseCache` only caches GET requests that return a 200. Even so, do not attach it to:

- **User-specific endpoints**: `/api/profile` returns different data for each user
- **Real-time data**: stock prices, live scores, chat messages
- **Authenticated endpoints**: unless every user shares the same response

```php
// GOOD: Public, stable data
Router::get("/api/categories", function ($request, $response) {
    return $response->json(["categories" => []]);
})->middleware(["ResponseCache:3600"]); // Cache for 1 hour

// BAD: User-specific data -- do NOT cache
Router::get("/api/profile", function ($request, $response) {
    return $response->json($request->user);
})->middleware(["authMiddleware"]); // No ResponseCache here
```

### Inspecting the Response Cache

`ResponseCache::cacheStats()` reports hits, misses, and the active backend:

```php
<?php
use Tina4\Router;
use Tina4\Middleware\ResponseCache;

Router::get("/api/cache/stats", function ($request, $response) {
    return $response->json(ResponseCache::cacheStats());
});
```

```json
{
  "hits": 15234,
  "misses": 891,
  "size": 42,
  "backend": "memory",
  "keys": []
}
```

Call `ResponseCache::clearCache()` to flush every cached response and reset the counters.

---

## 5. Cache Backends

All three layers share one set of backends, selected by `TINA4_CACHE_BACKEND`. Seven are available:

| Backend | Notes |
|---------|-------|
| `memory` | In-process array. The default. Fastest, zero dependencies, lost on restart. |
| `file` | JSON files under `data/cache/`. Survives restarts, no external service. |
| `redis` | Redis over the wire. Shared across instances, server-side expiry. |
| `valkey` | Valkey (Redis wire protocol). |
| `memcached` | Memcached, zero-dependency text protocol. |
| `mongodb` | MongoDB TTL collection. |
| `database` | A `tina4_cache` table in any Tina4-supported database. |

If a configured network or driver backend is unreachable -- the driver is missing, the service is down, the credentials are wrong -- Tina4 logs a warning and falls back to the **file** backend. It never silently degrades to a no-op, so you always get a real cache.

### Memory (Default)

```bash
# This is the default -- you do not need to set it
TINA4_CACHE_BACKEND=memory
```

Memory cache is the fastest option. No disk I/O. No network calls. But it resets when the server restarts. Ideal for development and single-server deployments where losing the cache on restart is acceptable.

### File

```bash
TINA4_CACHE_BACKEND=file
TINA4_CACHE_DIR=data/cache
```

Each cache entry becomes a file on disk. Slower than memory, but survives restarts without extra infrastructure. Use it when you need persistence but cannot run Redis -- shared hosting, no external services.

### Redis (and Valkey, Memcached, MongoDB)

For production, you usually want a cache that survives restarts and is shared across server instances behind a load balancer. Point the backend at one URL:

```bash
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_URL=redis://localhost:6379
```

Credentials can ride in the URL (`redis://user:pass@host:6379`) or live in their own variables:

```bash
TINA4_CACHE_USERNAME=cacheuser
TINA4_CACHE_PASSWORD=secret
```

Your code does not change. `cache_get`, `cache_set`, and `ResponseCache` all work the same. Only the storage backend changes.

---

## 6. Direct Key/Value Cache API

For custom caching logic, use the namespace-level helpers. They live in `\Tina4\Middleware\`, so import them from there:

```php
use function Tina4\Middleware\cache_get;
use function Tina4\Middleware\cache_set;
use function Tina4\Middleware\cache_delete;
```

The full surface:

```php
\Tina4\Middleware\cache_get(string $key): mixed
\Tina4\Middleware\cache_set(string $key, mixed $value, int $ttl = 0): void
\Tina4\Middleware\cache_delete(string $key): bool
\Tina4\Middleware\cache_clear(): void
\Tina4\Middleware\cache_stats(): array
```

### cache_set

```php
<?php
use function Tina4\Middleware\cache_set;

// Cache a value for 300 seconds
cache_set("product:42", [
    "id" => 42,
    "name" => "Wireless Keyboard",
    "price" => 79.99,
    "in_stock" => true
], 300);

// Cache a string
cache_set("exchange_rate:USD_EUR", "0.92", 3600);

// Cache with the backend's default TTL (pass no TTL)
cache_set("app:config", ["theme" => "dark", "lang" => "en"]);
```

### cache_get

```php
<?php
use function Tina4\Middleware\cache_get;
use function Tina4\Middleware\cache_set;

$product = cache_get("product:42");
// Returns the cached value, or null if not found or expired

if ($product === null) {
    // Cache miss -- fetch from database
    $product = fetchProductFromDatabase(42);
    cache_set("product:42", $product, 300);
}

return $response->json($product);
```

### cache_delete

```php
<?php
use function Tina4\Middleware\cache_delete;

// Delete a specific key
cache_delete("product:42");

// Delete multiple keys
cache_delete("product:42");
cache_delete("product:43");
cache_delete("product:44");
```

### Real-World Pattern: Cache-Aside

The most common caching pattern. Also called lazy loading:

```php
<?php
use Tina4\Router;
use Tina4\Database\Database;
use function Tina4\Middleware\cache_get;
use function Tina4\Middleware\cache_set;

Router::get("/api/products/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    $cacheKey = "product:" . $id;

    // 1. Try the cache first
    $product = cache_get($cacheKey);

    if ($product !== null) {
        // Cache hit -- return immediately
        return $response->json(array_merge($product, ["source" => "cache"]));
    }

    // 2. Cache miss -- fetch from database
    $db = Database::getConnection();
    $product = $db->fetchOne(
        "SELECT id, name, category, price, in_stock FROM products WHERE id = :id",
        ["id" => $id]
    );

    if ($product === null) {
        return $response->json(["error" => "Product not found"], 404);
    }

    // 3. Store in cache for next time
    cache_set($cacheKey, $product, 600); // Cache for 10 minutes

    return $response->json(array_merge($product, ["source" => "database"]));
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

## 7. Cache Invalidation Strategies

The hardest problem in caching: knowing when to clear the cache. Stale cache serves outdated data. Premature invalidation reduces cache effectiveness.

### Strategy 1: Time-Based Expiry (TTL)

The simplest approach. Set a TTL. Let the cache expire on its own:

```php
cache_set("products:featured", $featuredProducts, 600); // Expires in 10 minutes
```

Good for data where near-real-time accuracy is acceptable. A 10-minute delay in updating the featured products list is usually fine.

### Strategy 2: Event-Based Invalidation

Clear the cache when the underlying data changes:

```php
<?php
use Tina4\Router;
use Tina4\Database\Database;
use function Tina4\Middleware\cache_delete;

// Update a product
Router::put("/api/products/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    $body = $request->body;
    $db = Database::getConnection();

    $db->execute(
        "UPDATE products SET name = :name, price = :price WHERE id = :id",
        ["name" => $body["name"], "price" => $body["price"], "id" => $id]
    );

    // Invalidate the cache for this product
    cache_delete("product:" . $id);

    // Also invalidate any list caches that might include this product
    cache_delete("products:all");
    cache_delete("products:featured");

    $updated = $db->fetchOne("SELECT * FROM products WHERE id = :id", ["id" => $id]);

    return $response->json($updated);
});
```

The most accurate strategy. The cache is always fresh after a write. The downside: you must remember to invalidate everywhere the data could be cached.

### Strategy 3: Write-Through Cache

Update the cache at the same time as the database:

```php
Router::put("/api/products/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    $body = $request->body;
    $db = Database::getConnection();

    $db->execute(
        "UPDATE products SET name = :name, price = :price WHERE id = :id",
        ["name" => $body["name"], "price" => $body["price"], "id" => $id]
    );

    $updated = $db->fetchOne("SELECT * FROM products WHERE id = :id", ["id" => $id]);

    // Write the new data directly to cache (instead of deleting)
    cache_set("product:" . $id, $updated, 600);

    return $response->json($updated);
});
```

The cache always has the latest data. No cache miss after an update. The next read comes from the already-warm cache.

---

## 8. TTL Management

Choosing the right TTL depends on change frequency and tolerance for stale data:

| Data Type | Suggested TTL | Reasoning |
|-----------|---------------|-----------|
| Static config (categories, countries) | 3600 (1 hour) | Changes rarely, stale data is harmless |
| Product catalog | 300 (5 min) | Updates several times per day |
| User profile | 60 (1 min) | Users expect changes to appear fast |
| Search results | 120 (2 min) | Balance between freshness and performance |
| Dashboard stats | 30 (30 sec) | Near-real-time but expensive to compute |
| Exchange rates | 60 (1 min) | Updates frequently, slight delay is acceptable |
| Shopping cart | 0 (no cache) | Must reflect current state |

### Dynamic TTL

Adjust TTL based on data characteristics:

```php
<?php
use function Tina4\Middleware\cache_get;
use function Tina4\Middleware\cache_set;

function getCachedProduct($id) {
    $cacheKey = "product:" . $id;
    $product = cache_get($cacheKey);

    if ($product !== null) {
        return $product;
    }

    $product = fetchProductFromDatabase($id);

    // Popular products: shorter TTL (more likely to change)
    // Inactive products: longer TTL (rarely change)
    $ttl = ($product["view_count"] > 1000) ? 60 : 3600;

    cache_set($cacheKey, $product, $ttl);

    return $product;
}
```

---

## 9. Cache Statistics

Monitor cache performance. Verify that caching helps.

For the response cache, use `cache_stats()` (or `ResponseCache::cacheStats()`):

```php
<?php
use Tina4\Router;
use function Tina4\Middleware\cache_stats;

Router::get("/api/cache/stats", function ($request, $response) {
    return $response->json(cache_stats());
});
```

```bash
curl http://localhost:7145/api/cache/stats
```

```json
{
  "hits": 15234,
  "misses": 891,
  "size": 42,
  "backend": "memory",
  "keys": []
}
```

A high hit-to-miss ratio means your caching strategy works. Lots of misses suggests TTLs are too short, or you are caching data that is accessed too infrequently to benefit.

For the database query cache, use `$db->cacheStats()` instead -- it reports `enabled`, `mode`, `hits`, `misses`, `size`, `ttl`, and `backend` (see Section 3).

---

## 10. Combining Cache Layers

For maximum performance, layer multiple cache strategies:

```php
<?php
use Tina4\Router;
use Tina4\Database\Database;
use function Tina4\Middleware\cache_get;
use function Tina4\Middleware\cache_set;

Router::get("/api/catalog", function ($request, $response) {
    $page = (int) ($request->params["page"] ?? 1);
    $cacheKey = "catalog:page:" . $page;

    // Layer A: Check the key/value cache
    $catalog = cache_get($cacheKey);

    if ($catalog !== null) {
        return $response->json(array_merge($catalog, ["cache" => "application"]));
    }

    // Layer B: Database query (with the query cache underneath)
    $db = Database::getConnection();
    $limit = 20;
    $offset = ($page - 1) * $limit;

    $products = $db->fetchAll(
        "SELECT p.*, c.name as category_name
         FROM products p
         JOIN categories c ON p.category_id = c.id
         WHERE p.active = 1
         ORDER BY p.created_at DESC
         LIMIT :limit OFFSET :offset",
        ["limit" => $limit, "offset" => $offset]
    );

    $total = $db->fetchOne("SELECT COUNT(*) as count FROM products WHERE active = 1");

    $catalog = [
        "products" => $products,
        "page" => $page,
        "total" => $total["count"],
        "pages" => (int) ceil($total["count"] / $limit),
        "generated_at" => date("c")
    ];

    // Store in the key/value cache
    cache_set($cacheKey, $catalog, 300);

    return $response->json(array_merge($catalog, ["cache" => "none"]));
})->middleware(["ResponseCache:60"]); // Response cache (60 seconds)
```

Three cache layers stack here:

1. **ResponseCache** (60 seconds): the entire HTTP response is cached. No PHP code runs.
2. **Key/value cache** (300 seconds): if the response cache expired but the KV entry is fresh, skip the database queries.
3. **Query cache** (request-scoped by default, or persistent if `TINA4_DB_CACHE=true`): individual query results are cached even when the KV entry missed.

The first visitor after a full cache expiry waits 800ms. Everyone else gets the response in under 5ms.

---

## 11. Exercise: Cache an Expensive Product Listing Endpoint

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

## 12. Solution

Create `src/routes/store-cached.php`:

```php
<?php
use Tina4\Router;
use function Tina4\Middleware\cache_get;
use function Tina4\Middleware\cache_set;
use function Tina4\Middleware\cache_delete;
use function Tina4\Middleware\cache_stats;

// Simulated product database
function getProductStore() {
    return [
        ["id" => 1, "name" => "Wireless Keyboard", "category" => "Electronics", "price" => 79.99, "in_stock" => true],
        ["id" => 2, "name" => "Yoga Mat", "category" => "Fitness", "price" => 29.99, "in_stock" => true],
        ["id" => 3, "name" => "Coffee Grinder", "category" => "Kitchen", "price" => 49.99, "in_stock" => false],
        ["id" => 4, "name" => "Standing Desk", "category" => "Electronics", "price" => 549.99, "in_stock" => true],
        ["id" => 5, "name" => "Running Shoes", "category" => "Fitness", "price" => 119.99, "in_stock" => true],
        ["id" => 6, "name" => "Bluetooth Speaker", "category" => "Electronics", "price" => 39.99, "in_stock" => true],
        ["id" => 7, "name" => "Resistance Bands", "category" => "Fitness", "price" => 14.99, "in_stock" => true],
        ["id" => 8, "name" => "French Press", "category" => "Kitchen", "price" => 34.99, "in_stock" => true]
    ];
}

// List products with caching
Router::get("/api/store/products", function ($request, $response) {
    $category = $request->params["category"] ?? null;
    $page = (int) ($request->params["page"] ?? 1);
    $limit = (int) ($request->params["limit"] ?? 20);

    // Build cache key from query parameters
    $cacheKey = "store:products:" . md5(json_encode([
        "category" => $category,
        "page" => $page,
        "limit" => $limit
    ]));

    // Try cache first
    $cached = cache_get($cacheKey);

    if ($cached !== null) {
        return $response->json(array_merge($cached, ["source" => "cache"]));
    }

    // Simulate expensive database query
    usleep(100000); // 100ms delay to simulate a slow query

    $products = getProductStore();

    // Filter by category
    if ($category !== null) {
        $products = array_values(array_filter(
            $products,
            fn($p) => strtolower($p["category"]) === strtolower($category)
        ));
    }

    $total = count($products);
    $offset = ($page - 1) * $limit;
    $products = array_slice($products, $offset, $limit);

    $result = [
        "products" => $products,
        "page" => $page,
        "limit" => $limit,
        "total" => $total,
        "pages" => (int) ceil($total / $limit),
        "generated_at" => date("c")
    ];

    // Cache for 5 minutes
    cache_set($cacheKey, $result, 300);

    return $response->json(array_merge($result, ["source" => "database"]));
});

// Create product and invalidate cache
Router::post("/api/store/products", function ($request, $response) {
    $body = $request->body;

    if (empty($body["name"])) {
        return $response->json(["error" => "Name is required"], 400);
    }

    $product = [
        "id" => rand(100, 9999),
        "name" => $body["name"],
        "category" => $body["category"] ?? "General",
        "price" => (float) ($body["price"] ?? 0),
        "in_stock" => true
    ];

    // Invalidate all product list caches
    // In a real app with many cache keys, you would track which keys to invalidate
    // For now, we delete known cache patterns
    $categories = ["Electronics", "Fitness", "Kitchen", "General"];
    foreach ($categories as $cat) {
        for ($p = 1; $p <= 5; $p++) {
            $key = "store:products:" . md5(json_encode([
                "category" => $cat,
                "page" => $p,
                "limit" => 20
            ]));
            cache_delete($key);
        }
    }

    // Also invalidate the unfiltered list
    for ($p = 1; $p <= 5; $p++) {
        $key = "store:products:" . md5(json_encode([
            "category" => null,
            "page" => $p,
            "limit" => 20
        ]));
        cache_delete($key);
    }

    return $response->json([
        "message" => "Product created",
        "product" => $product,
        "cache_invalidated" => true
    ], 201);
});

// Cache statistics
Router::get("/api/store/cache-stats", function ($request, $response) {
    return $response->json(cache_stats());
});
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

Same `generated_at`. Source changed from `"database"` to `"cache"`. The handler did not run.

**Expected output -- after creating a product:**

```bash
curl -X POST http://localhost:7145/api/store/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Smart Watch", "category": "Electronics", "price": 299.99}'
```

```json
{
  "message": "Product created",
  "product": {
    "id": 4721,
    "name": "Smart Watch",
    "category": "Electronics",
    "price": 299.99,
    "in_stock": true
  },
  "cache_invalidated": true
}
```

The next request to the same URL is a cache miss again. The POST invalidated the cache.

---

## 13. Gotchas

### 1. Caching Authenticated Responses

**Problem:** User A's profile is served to User B because the response was cached.

**Cause:** `ResponseCache` keys by method and URL only. `/api/profile` returns different data per user, but all requests hit the same URL. The first user's response is served to everyone.

**Fix:** Do not attach `ResponseCache` to user-specific endpoints. Use the direct cache API with user-specific keys: `cache_set("profile:" . $userId, $data, 300)`.

### 2. Cache Stampede

**Problem:** A popular cache key expires. Hundreds of requests hit the database at once. All experience a cache miss at the same moment.

**Cause:** All requests see the miss. All try to rebuild the cache independently.

**Fix:** Shorten the window where the key is missing -- pre-warm hot keys on a schedule, or stagger TTLs so popular keys do not all expire together. Tina4 does not lock or serve stale entries for you, so plan for the miss.

### 3. Memory Cache Lost on Restart

**Problem:** After restarting the server, performance drops until the cache warms up.

**Cause:** The memory backend dies when the process restarts. Every request is a cache miss until data populates again.

**Fix:** For production, use a persistent backend (`TINA4_CACHE_BACKEND=redis` or `file`). Redis also survives across multiple instances. Or run a cache warmup script that pre-populates frequently accessed data.

### 4. Stale Data After Database Update

**Problem:** You updated a product's price in the database. The API still returns the old price.

**Cause:** The key/value cache holds the old data. It has not expired yet. (The query cache flushes itself on writes; the KV cache does not.)

**Fix:** Always invalidate or update the KV cache when you modify the underlying data. Use `cache_delete("product:" . $id)` after an update, or write the new value with `cache_set()`.

### 5. Cache Key Collisions

**Problem:** Two different queries return the same cached data.

**Cause:** Cache keys are not specific enough. Using `"products"` as a key for both the full list and a filtered list causes collisions.

**Fix:** Include all relevant parameters in the cache key: `"products:category:Electronics:page:1:limit:20"`. Or use an MD5 hash of the parameters: `"products:" . md5(json_encode($params))`.

### 6. Serialization Overhead

**Problem:** Caching makes certain requests slower, not faster.

**Cause:** The cached object is large. Serializing and deserializing it takes more time than re-computing it.

**Fix:** Only cache data that is expensive to compute. If the original operation takes 5ms and cache serialization takes 10ms, caching is counterproductive. Profile before and after to verify the improvement.

### 7. Importing the Helpers from the Wrong Namespace

**Problem:** `Call to undefined function Tina4\cache_set()`.

**Cause:** The key/value helpers live in `\Tina4\Middleware\`, not the root `Tina4\` namespace.

**Fix:** Import them from the right place: `use function Tina4\Middleware\cache_set;`. Or call them fully qualified: `\Tina4\Middleware\cache_set("key", $value, 300)`.
