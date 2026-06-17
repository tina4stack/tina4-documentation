# Chapter 11: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. 800 milliseconds to render. Every visitor triggers the same queries, the same template rendering, the same JSON serialization -- for data that changes once a day.

Add caching. The first request takes 800ms. The next 10,000 take 3ms each. A 266x improvement from one line of configuration.

Caching stores the result of expensive operations for reuse. Tina4 gives you three layers, and they stack:

1. **Request-scoped query cache** -- on by default. Dedupes identical reads inside a single request. Flushes on every write.
2. **Persistent database query cache** -- opt-in. Holds query results across requests until they expire.
3. **Response cache middleware** -- caches whole HTTP responses so the route handler never runs.

This chapter covers all three, plus the direct key-value API you use for everything else.

---

## 2. Layer 1: Request-Scoped Query Cache

The first layer needs no setup. Tina4 caches database reads for the lifetime of a single request. Run the same query twice in one handler and the second call returns the first result -- no second trip to the database.

```ruby
Tina4::Router.get("/api/dashboard") do |request, response|
  db = Tina4.database

  # First call hits the database
  user_count = db.fetch_one("SELECT COUNT(*) AS c FROM users")

  # ... other work ...

  # Same query, same request: served from the request-scoped cache
  user_count_again = db.fetch_one("SELECT COUNT(*) AS c FROM users")

  response.json({ users: user_count["c"] })
end
```

This layer is controlled by two environment variables:

```bash
TINA4_AUTO_CACHING=true       # default -- set to false to turn it off
TINA4_AUTO_CACHING_TTL=5      # default TTL in seconds
```

The cache clears at the start of each request, so one request never sees another request's data. Any write -- `insert`, `update`, `delete`, `execute` -- flushes the cache immediately, so a read after a write always reflects the change.

It lives in process and never touches the network. You get it for free.

---

## 3. Layer 2: Persistent Database Query Cache

The second layer survives across requests. Turn it on when the same queries run on every request and the underlying data changes rarely.

```bash
TINA4_DB_CACHE=true           # opt-in -- off by default
TINA4_DB_CACHE_TTL=30         # default TTL in seconds
```

With persistent caching on, identical queries return cached results until the TTL expires:

```ruby
Tina4::Router.get("/api/categories") do |request, response|
  db = Tina4.database

  # First call: executes the query
  # Subsequent calls within 30 seconds (across requests): cached result
  categories = db.fetch("SELECT * FROM categories ORDER BY name")

  response.json({ categories: categories })
end
```

The cache key derives from the SQL and its parameters. Different queries or different parameters get different keys:

```ruby
# Cached separately:
db.fetch("SELECT * FROM products WHERE category = ?", ["Electronics"])
db.fetch("SELECT * FROM products WHERE category = ?", ["Fitness"])
```

Any write operation (`insert`, `update`, `delete`, `execute`) invalidates the cache.

### Sharing the cache across instances

By default the persistent cache lives in process memory. To share one cache across multiple server instances, route it through a backend:

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_BACKEND=redis
TINA4_DB_CACHE_URL=redis://localhost:6379
```

`TINA4_DB_CACHE_BACKEND` accepts any of the backends listed in section 5. A shared backend means a write on one instance invalidates the cache for all of them.

### Bypassing the cache per query

Some reads must always hit the database -- a live inventory count, a balance check. Pass `no_cache: true` to skip the cache for a single call. No lookup, no store, just a direct query:

```ruby
# Always reads fresh from the database
balance = db.fetch_one(
  "SELECT balance FROM accounts WHERE id = ?",
  [account_id],
  no_cache: true
)
```

The flag works on all three read methods:

```ruby
db.fetch(sql, params, limit: 100, offset: 0, no_cache: false)
db.fetch_one(sql, params, no_cache: false)
db.fetch_all(sql, params, limit: nil, offset: nil, no_cache: false)
```

`no_cache: true` bypasses both Layer 1 and Layer 2 for that call.

### When to use the persistent DB cache

- Read-heavy applications where the same queries run repeatedly
- Reference data that changes infrequently (categories, countries, settings)
- Dashboard queries that aggregate large datasets

### When not to use it

- Write-heavy applications where data changes constantly
- Queries with real-time requirements (use `no_cache: true` for those reads)
- Queries that must always return the latest data

---

## 4. Layer 3: Response Cache Middleware

The fastest cache lives at the HTTP response level. The `Tina4::ResponseCache` middleware stores the complete response (body, content type, status) and serves it on later requests without calling your route handler at all.

Attach it as middleware with a TTL:

```ruby
Tina4::Router.get("/api/products", middleware: ["ResponseCache:300"]) do |request, response|
  # This handler runs 12 database queries and takes 800ms
  # With ResponseCache, it only runs once every 5 minutes

  puts "Handler called -- this should only appear once every 5 minutes"

  products = [
    { id: 1, name: "Wireless Keyboard", price: 79.99 },
    { id: 2, name: "USB-C Hub", price: 49.99 },
    { id: 3, name: "Monitor Stand", price: 129.99 }
  ]

  response.json({ products: products, generated_at: Time.now.utc.iso8601 })
end
```

The string form `"ResponseCache:300"` caches the response for 300 seconds (5 minutes). During those 5 minutes:

- The first request runs the handler (800ms)
- The next 10,000 requests serve the cached response (3ms each)
- After 300 seconds, the cache expires and the next request runs the handler again

```bash
curl http://localhost:7147/api/products
```

```json
{
  "products": [
    {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
    {"id": 2, "name": "USB-C Hub", "price": 49.99},
    {"id": 3, "name": "Monitor Stand", "price": 129.99}
  ],
  "generated_at": "2026-03-22T14:30:00Z"
}
```

Call it again within 5 minutes. The `generated_at` timestamp stays the same. The handler did not run -- the response came from cache.

The middleware only caches `GET` requests that return a `200` status.

### Default TTL and limits

Without a TTL in the middleware string, the response cache reads its settings from the environment:

```bash
TINA4_CACHE_TTL=60            # default response-cache TTL in seconds
TINA4_CACHE_MAX_ENTRIES=1000  # maximum cached entries (LRU eviction)
```

### Cache headers

The `ResponseCache` middleware stamps two headers on every response it handles:

```
X-Cache: HIT
X-Cache-TTL: 247
```

- `X-Cache: HIT` or `X-Cache: MISS` tells you whether the response came from cache
- `X-Cache-TTL` shows the remaining TTL in seconds on a HIT, or the configured TTL on a MISS

### Caching with query parameters

The cache key includes the full URL with query parameters. `/api/products?page=1` and `/api/products?page=2` are cached separately:

```bash
curl "http://localhost:7147/api/products?page=1"  # MISS, stores for page=1
curl "http://localhost:7147/api/products?page=2"  # MISS, stores for page=2
curl "http://localhost:7147/api/products?page=1"  # HIT
```

### What not to cache

Do not use `ResponseCache` on:

- **POST, PUT, PATCH, DELETE routes**: only GET responses are cached
- **User-specific endpoints**: `/api/profile` returns different data per user, but the cache keys on URL alone
- **Real-time data**: stock prices, live scores, chat messages
- **Authenticated endpoints**: unless every user shares the same response

---

## 5. Cache Backends

The response cache and the direct key-value API share one backend, selected with `TINA4_CACHE_BACKEND`. Seven backends ship in the box:

| Backend | `TINA4_CACHE_BACKEND` | Notes |
|---------|------------------------|-------|
| Memory | `memory` (default) | In-process LRU. Fastest. Lost on restart. |
| File | `file` | JSON files on disk. Survives restarts, zero dependencies. |
| Redis | `redis` | Shared across instances, sub-millisecond. |
| Valkey | `valkey` | Redis wire protocol; reports as `valkey`. |
| Memcached | `memcached` | Zero-dependency text protocol. |
| MongoDB | `mongodb` | TTL collection (requires the `mongo` gem). |
| Database | `database` | A `tina4_cache` table in any Tina4-supported database. |

```bash
# Memory is the default -- you do not need to set it
TINA4_CACHE_BACKEND=memory
```

### Redis

For cache that survives restarts and is shared across instances behind a load balancer:

```bash
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_URL=redis://localhost:6379
```

Your code does not change. `cache_get`, `cache_set`, and the `ResponseCache` middleware all work the same way -- only the storage changes. If your credentials are not in the URL, set them separately:

```bash
TINA4_CACHE_USERNAME=cacheuser
TINA4_CACHE_PASSWORD=secret
```

Valkey, Memcached, and MongoDB use the same single `TINA4_CACHE_URL` (Memcached is unauthenticated).

### File

When you want persistence but cannot run Redis:

```bash
TINA4_CACHE_BACKEND=file
TINA4_CACHE_DIR=/path/to/cache/directory
```

File cache stores each entry as a JSON file on disk. Slower than memory or Redis, but it survives restarts with no extra infrastructure.

### Graceful fallback

If a configured backend's driver is missing or its service is unreachable, Tina4 logs a warning and falls back to the **file** backend -- a real, working, persistent cache. It never degrades to a silent no-op. A degraded backend reports its real name (`file`) in `cache_stats`, so you can see the fallback happened.

---

## 6. The Direct Cache API

For custom caching logic, use the key-value helpers on the `Tina4` module: `cache_get`, `cache_set`, `cache_delete`, `clear_cache`, and `cache_stats`.

### cache_set

```ruby
# Cache a value for 300 seconds
Tina4.cache_set("product:42", {
  id: 42,
  name: "Wireless Keyboard",
  price: 79.99,
  in_stock: true
}, ttl: 300)

# Cache a string
Tina4.cache_set("exchange_rate:USD_EUR", "0.92", ttl: 3600)
```

`ttl:` defaults to `0`, which falls back to the configured default TTL.

### cache_get

```ruby
product = Tina4.cache_get("product:42")
# Returns the cached value, or nil if not found or expired

if product.nil?
  # Cache miss -- fetch from database
  product = fetch_product_from_database(42)
  Tina4.cache_set("product:42", product, ttl: 300)
end
```

### cache_delete

```ruby
# Delete a specific key
Tina4.cache_delete("product:42")

# Delete several keys
Tina4.cache_delete("product:42")
Tina4.cache_delete("product:43")
Tina4.cache_delete("product:44")
```

### clear_cache

```ruby
# Flush every entry in the cache
Tina4.clear_cache
```

### Real-world pattern: cache-aside

The most common caching pattern is cache-aside (also called lazy loading):

```ruby
Tina4::Router.get("/api/products/{id:int}") do |request, response|
  product_id = request.params["id"]
  cache_key = "product:#{product_id}"

  # 1. Try the cache first
  product = Tina4.cache_get(cache_key)

  unless product.nil?
    # Cache hit -- return immediately
    return response.json(product.merge(source: "cache"))
  end

  # 2. Cache miss -- fetch from database
  db = Tina4.database
  product = db.fetch_one(
    "SELECT id, name, category, price, in_stock FROM products WHERE id = ?",
    [product_id]
  )

  if product.nil?
    return response.json({ error: "Product not found" }, 404)
  end

  # 3. Store in cache for next time
  Tina4.cache_set(cache_key, product, ttl: 600)  # Cache for 10 minutes

  response.json(product.merge(source: "database"))
end
```

```bash
curl http://localhost:7147/api/products/42
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

Cache invalidation is the hard problem. Stale cache serves outdated data. Premature invalidation throws away performance gains. Three strategies handle this.

### Strategy 1: Time-based expiry (TTL)

The simplest strategy. Set a TTL and let the cache expire naturally:

```ruby
Tina4.cache_set("products:featured", featured_products, ttl: 600)  # Expires in 10 minutes
```

Good for data where near-real-time accuracy is acceptable. A 10-minute delay in updating the featured products list is usually fine.

### Strategy 2: Event-based invalidation

Clear the cache when the underlying data changes:

```ruby
Tina4::Router.put("/api/products/{id:int}") do |request, response|
  product_id = request.params["id"]
  body = request.body
  db = Tina4.database

  db.execute(
    "UPDATE products SET name = ?, price = ? WHERE id = ?",
    [body["name"], body["price"], product_id]
  )

  # Invalidate the cache for this product
  Tina4.cache_delete("product:#{product_id}")

  # Also invalidate list caches that might include this product
  Tina4.cache_delete("products:all")
  Tina4.cache_delete("products:featured")

  updated = db.fetch_one("SELECT * FROM products WHERE id = ?", [product_id])

  response.json(updated)
end
```

This is the most accurate strategy -- the cache is always fresh after a write. The downside: you must remember to invalidate everywhere the data could be cached.

### Strategy 3: Write-through cache

Update the cache at the same time as the database:

```ruby
Tina4::Router.put("/api/products/{id:int}") do |request, response|
  product_id = request.params["id"]
  body = request.body
  db = Tina4.database

  db.execute(
    "UPDATE products SET name = ?, price = ? WHERE id = ?",
    [body["name"], body["price"], product_id]
  )

  updated = db.fetch_one("SELECT * FROM products WHERE id = ?", [product_id])

  # Write the new data directly to cache (instead of deleting)
  Tina4.cache_set("product:#{product_id}", updated, ttl: 600)

  response.json(updated)
end
```

The cache always has the latest data. No cache miss after an update -- the next read comes from the already-warm cache.

---

## 8. TTL Management

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

```ruby
def get_cached_product(product_id)
  cache_key = "product:#{product_id}"
  product = Tina4.cache_get(cache_key)

  return product unless product.nil?

  product = fetch_product_from_database(product_id)

  # Popular products: shorter TTL (more likely to change)
  # Inactive products: longer TTL (rarely change)
  ttl = product["view_count"].to_i > 1000 ? 60 : 3600

  Tina4.cache_set(cache_key, product, ttl: ttl)

  product
end
```

---

## 9. Cache Statistics

Two stat surfaces help you verify that caching helps.

### Response / KV cache stats

`Tina4.cache_stats` reports the shared response and key-value cache:

```ruby
Tina4::Router.get("/api/cache/stats") do |request, response|
  response.json(Tina4.cache_stats)
end
```

```bash
curl http://localhost:7147/api/cache/stats
```

```json
{
  "hits": 15234,
  "misses": 891,
  "size": 42,
  "backend": "memory",
  "keys": ["GET:/api/products", "direct:product:42"]
}
```

The fields are `hits`, `misses`, `size`, `backend`, and `keys`. The `keys` array is populated for the memory backend and empty for the others.

Hit rate above 90%: your caching strategy works. Below 80%: TTLs are too short, the cache is too small, or you are caching data that does not benefit from caching.

### Database cache stats

`db.cache_stats` reports the query cache on a database connection:

```ruby
Tina4::Router.get("/api/db/cache-stats") do |request, response|
  response.json(Tina4.database.cache_stats)
end
```

```json
{
  "enabled": true,
  "mode": "request",
  "hits": 318,
  "misses": 47,
  "size": 12,
  "backend": "memory",
  "ttl": 5
}
```

The `mode` field tells you which layer is active:

- `"request"` -- request-scoped caching (the default)
- `"persistent"` -- `TINA4_DB_CACHE=true` is set
- `"off"` -- both layers are disabled

---

## 10. Combining Cache Layers

For maximum performance, stack all three layers:

```ruby
Tina4::Router.get("/api/catalog", middleware: ["ResponseCache:60"]) do |request, response|
  page = (request.params["page"] || 1).to_i
  cache_key = "catalog:page:#{page}"

  # Layer A: application cache (direct KV API)
  catalog = Tina4.cache_get(cache_key)

  unless catalog.nil?
    return response.json(catalog.merge(cache: "application"))
  end

  # Layer B: database queries (request-scoped + persistent DB cache apply here)
  db = Tina4.database
  limit = 20
  offset = (page - 1) * limit

  products = db.fetch(
    "SELECT p.*, c.name AS category_name
     FROM products p
     JOIN categories c ON p.category_id = c.id
     WHERE p.active = 1
     ORDER BY p.created_at DESC",
    [], limit: limit, offset: offset
  )

  total = db.fetch_one("SELECT COUNT(*) AS count FROM products WHERE active = 1")

  catalog = {
    products: products,
    page: page,
    total: total["count"],
    pages: (total["count"].to_f / limit).ceil,
    generated_at: Time.now.utc.iso8601
  }

  # Store in application cache
  Tina4.cache_set(cache_key, catalog, ttl: 300)

  response.json(catalog.merge(cache: "none"))
end
```

This creates three working layers:

1. **ResponseCache** (60 seconds): the entire HTTP response is cached. No Ruby code runs at all.
2. **Application cache** (300 seconds): if the response cache expired but the app cache is fresh, skip the database queries.
3. **DB query cache**: individual query results are cached -- request-scoped by default, persistent if `TINA4_DB_CACHE=true`.

The first visitor after a full cache expiry waits 800ms. Everyone else gets the response in under 5ms.

---

## 11. Exercise: Cache an Expensive Product Listing Endpoint

Build a product listing endpoint that caches at multiple levels.

### Requirements

1. Create a `GET /api/store/products` endpoint that:
   - Accepts query parameters: `category`, `page`, `limit`
   - Returns a list of products with pagination metadata
   - Uses the direct cache API (`Tina4.cache_get` / `Tina4.cache_set`) with a 5-minute TTL
   - Includes a `source` field in the response (`"cache"` or `"database"`)

2. Create a `POST /api/store/products` endpoint that:
   - Creates a new product
   - Invalidates the cached product lists

3. Create a `GET /api/store/cache-stats` endpoint that shows cache statistics

### Test with:

```bash
# First call -- cache miss, slow
curl "http://localhost:7147/api/store/products?category=Electronics&page=1"

# Second call -- cache hit, fast
curl "http://localhost:7147/api/store/products?category=Electronics&page=1"

# Different category -- cache miss
curl "http://localhost:7147/api/store/products?category=Fitness&page=1"

# Create a product -- should invalidate cache
curl -X POST http://localhost:7147/api/store/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Smart Watch", "category": "Electronics", "price": 299.99}'

# Same query again -- cache miss (invalidated by the POST)
curl "http://localhost:7147/api/store/products?category=Electronics&page=1"

# Check cache stats
curl http://localhost:7147/api/store/cache-stats
```

---

## 12. Solution

Create `src/routes/store_cached.rb`:

```ruby
require "digest"
require "json"

PRODUCT_STORE = [
  { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99, in_stock: true },
  { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99, in_stock: true },
  { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99, in_stock: false },
  { id: 4, name: "Standing Desk", category: "Electronics", price: 549.99, in_stock: true },
  { id: 5, name: "Running Shoes", category: "Fitness", price: 119.99, in_stock: true },
  { id: 6, name: "Bluetooth Speaker", category: "Electronics", price: 39.99, in_stock: true },
  { id: 7, name: "Resistance Bands", category: "Fitness", price: 14.99, in_stock: true },
  { id: 8, name: "French Press", category: "Kitchen", price: 34.99, in_stock: true }
]

Tina4::Router.get("/api/store/products") do |request, response|
  category = request.params["category"]
  page = (request.params["page"] || 1).to_i
  limit = (request.params["limit"] || 20).to_i

  # Build cache key from query parameters
  key_data = JSON.generate({ category: category, page: page, limit: limit })
  cache_key = "store:products:#{Digest::MD5.hexdigest(key_data)}"

  # Try cache first
  cached = Tina4.cache_get(cache_key)

  unless cached.nil?
    return response.json(cached.merge("source" => "cache"))
  end

  # Simulate expensive database query
  sleep(0.1)

  products = PRODUCT_STORE.dup

  # Filter by category
  if category
    products = products.select { |p| p[:category].downcase == category.downcase }
  end

  total = products.length
  offset = (page - 1) * limit
  products = products[offset, limit] || []

  result = {
    products: products,
    page: page,
    limit: limit,
    total: total,
    pages: (total.to_f / limit).ceil,
    generated_at: Time.now.utc.iso8601
  }

  # Cache for 5 minutes
  Tina4.cache_set(cache_key, result, ttl: 300)

  response.json(result.merge(source: "database"))
end

Tina4::Router.post("/api/store/products") do |request, response|
  body = request.body

  if body["name"].nil? || body["name"].empty?
    return response.json({ error: "Name is required" }, 400)
  end

  product = {
    id: rand(100..9999),
    name: body["name"],
    category: body["category"] || "General",
    price: (body["price"] || 0).to_f,
    in_stock: true
  }

  # Invalidate all product list caches
  Tina4.clear_cache

  response.json({
    message: "Product created",
    product: product,
    cache_invalidated: true
  }, 201)
end

Tina4::Router.get("/api/store/cache-stats") do |request, response|
  response.json(Tina4.cache_stats)
end
```

**Expected output -- first call (cache miss):**

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
  "generated_at": "2026-03-22T14:30:00Z",
  "source": "database"
}
```

**Expected output -- second call (cache hit):**

Same data, but `source` changes to `"cache"`. The handler did not run.

---

## 13. Gotchas

### 1. Caching authenticated responses

**Problem:** User A's profile is served to User B because the response was cached.

**Cause:** `ResponseCache` keys on URL only. If `/api/profile` returns different data per user but every request hits the same URL, the first user's response is served to everyone.

**Fix:** Do not use `ResponseCache` on user-specific endpoints. Use the direct cache API with user-specific keys: `Tina4.cache_set("profile:#{user_id}", data, ttl: 300)`.

### 2. Memory cache lost on restart

**Problem:** After restarting the server, performance drops until the cache warms up.

**Cause:** The memory backend lives in process and is lost when the process restarts.

**Fix:** For production, use the Redis backend (`TINA4_CACHE_BACKEND=redis`). It survives restarts and is shared across instances. Or write a warmup script that pre-populates frequently accessed keys.

### 3. Stale data after a database update

**Problem:** You updated a product's price in the database, but the API still returns the old price.

**Cause:** The cache still holds the old value and has not expired.

**Fix:** Invalidate or update the cache when you change the underlying data. Use `Tina4.cache_delete("product:#{product_id}")` after an update, or write through with the new value. For a single live read, pass `no_cache: true` to the query.

### 4. Cache key collisions

**Problem:** Two different queries return the same cached data.

**Cause:** Your cache keys are not specific enough. Using `"products"` for both the full list and a filtered list causes collisions.

**Fix:** Include every relevant parameter in the key: `"products:category:Electronics:page:1:limit:20"`. Or hash the parameters with MD5.

### 5. Serialization overhead

**Problem:** Caching makes certain requests slower, not faster.

**Cause:** The cached object is very large. Serializing and deserializing it costs more than recomputing it.

**Fix:** Only cache data that is expensive to compute. If the original operation takes 5ms and cache serialization takes 10ms, caching hurts. Profile before and after to confirm the win.

### 6. Forgetting that writes flush the request cache

**Problem:** You expected a read to come from cache, but it hit the database.

**Cause:** A write earlier in the same request flushed the request-scoped query cache. That is by design -- a read after a write must reflect the change.

**Fix:** This is correct behavior. If you need a value to survive a write within one request, capture it in a local variable before the write, or store it with the direct cache API.

### 7. Reaching for a backend you do not have

**Problem:** You set `TINA4_CACHE_BACKEND=redis` but `cache_stats` reports `"backend": "file"`.

**Cause:** Redis was unreachable or its driver was missing, so Tina4 fell back to the file backend and logged a warning.

**Fix:** This is the graceful-fallback safety net -- your cache still works. Check the logs, fix the connection (`TINA4_CACHE_URL`, credentials, the service itself), and the reported backend returns to `redis`.
