# Chapter 14: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. 800 milliseconds to render. Every visitor triggers the same queries, the same template rendering, the same JSON serialization -- for data that changes once a day. Add caching. The first request takes 800ms. The next 10,000 take 3ms each. A 266x improvement from one line of configuration.

Caching stores the result of expensive operations for reuse. Tina4 provides three levels: response caching (entire HTTP responses), database query caching, and a direct cache API for custom use cases.

---

## 2. Response Caching with ResponseCache Middleware

The fastest way to cache is at the HTTP response level. The `ResponseCache` middleware stores the complete response and serves it directly on subsequent requests without calling your route handler at all.

```ruby
Tina4::Router.get("/api/products", middleware: "ResponseCache:300") do |request, response|
  $stderr.puts "Handler called -- this should only appear once every 5 minutes"

  products = [
    { id: 1, name: "Wireless Keyboard", price: 79.99 },
    { id: 2, name: "USB-C Hub", price: 49.99 },
    { id: 3, name: "Monitor Stand", price: 129.99 }
  ]

  response.json({ products: products, generated_at: Time.now.iso8601 })
end
```

The `"ResponseCache:300"` middleware caches the response for 300 seconds (5 minutes).

---

## 3. The Direct Cache API

For custom caching, use the `Tina4` cache API directly:

```ruby
# Store a value
Tina4.cache_set("products:featured", featured_products, ttl: 300)

# Retrieve a value
cached = Tina4.cache_get("products:featured")

# Delete a cached value
Tina4.cache_delete("products:featured")

# Clear all cache
Tina4.cache_clear
```

### Manual Fetch-or-Compute Pattern

The most common caching pattern -- check the cache, compute if missing, store and return:

```ruby
Tina4::Router.get("/api/products") do |request, response|
  products = Tina4.cache_get("products:all")

  if products.nil?
    db = Tina4.database
    products = db.fetch("SELECT * FROM products ORDER BY name")
    Tina4.cache_set("products:all", products, ttl: 300)
  end

  response.json({ products: products, count: products.length })
end
```

Check the cache for the key. If it exists, use the cached value. If not, compute the value, store it with a TTL (time to live in seconds), and return it.

---

## 4. Cache Backends

### Memory Cache (Default)

Out of the box, Tina4 caches in-process memory. No configuration needed:

```env
TINA4_CACHE_BACKEND=memory
```

### Redis Cache

For production with multiple servers:

```env
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_URL=redis://localhost:6379
```

### File Cache

For persistence across restarts without Redis:

```env
TINA4_CACHE_BACKEND=file
TINA4_CACHE_DIR=data/cache
```

---

## 5. Database Query Caching

Enable automatic query caching:

```env
TINA4_DB_CACHE=true
```

When enabled, `fetch` and `fetch_one` calls are cached. The cache is automatically invalidated when you call `execute`, `insert`, `update`, or `delete`.

---

## 6. Cache Invalidation

### Manual Invalidation

```ruby
# After updating products
Tina4.cache_delete("products:all")
Tina4.cache_delete("products:featured")
```

### Automatic Invalidation in Route Handlers

```ruby
Tina4::Router.post("/api/products") do |request, response|
  body = request.body

  db = Tina4.database
  db.insert("products", {
    name: body["name"],
    price: body["price"].to_f
  })

  # Invalidate product caches
  Tina4.cache_delete("products:all")
  Tina4.cache_delete("products:featured")

  response.json({ message: "Product created, cache cleared" }, 201)
end
```

---

## 7. Cache Headers

Set HTTP cache headers for browser and CDN caching:

```ruby
Tina4::Router.get("/api/public/config") do |request, response|
  response
    .header("Cache-Control", "public, max-age=3600")
    .header("ETag", Digest::MD5.hexdigest("config-v1"))
    .json({
      app_name: "My Store",
      version: "1.0.0",
      features: { dark_mode: true, notifications: true }
    })
end
```

---

## 8. Cache Statistics

Monitor your cache performance:

```ruby
Tina4::Router.get("/api/cache/stats") do |request, response|
  stats = Tina4.cache_stats

  response.json({
    backend: stats[:backend],
    size: stats[:size],
    hits: stats[:hits],
    misses: stats[:misses]
  })
end
```

---

## 9. Exercise: Add Caching to a Product API

Take your product API from Chapter 5 and add caching at multiple levels.

### Requirements

1. Cache the product list for 5 minutes
2. Cache individual product lookups for 10 minutes
3. Invalidate caches when products are created, updated, or deleted
4. Add a `GET /api/cache/stats` endpoint

### Test with:

```bash
# First call (slow, hits database)
curl http://localhost:7147/api/products

# Second call (fast, from cache)
curl http://localhost:7147/api/products

# Create a product (should invalidate cache)
curl -X POST http://localhost:7147/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "New Widget", "price": 19.99}'

# Next call should hit database again
curl http://localhost:7147/api/products

# Check cache stats
curl http://localhost:7147/api/cache/stats
```

---

## 10. Solution

Create `src/routes/cached_products.rb`:

```ruby
Tina4::Router.get("/api/products") do |request, response|
  products = Tina4.cache_get("products:all")

  if products.nil?
    db = Tina4.database
    products = db.fetch("SELECT * FROM products ORDER BY name")
    Tina4.cache_set("products:all", products, ttl: 300)
  end

  response.json({ products: products, count: products.length, cached: true })
end

Tina4::Router.get("/api/products/{id:int}") do |request, response|
  id = request.params["id"]

  product = Tina4.cache_get("products:#{id}")

  if product.nil?
    db = Tina4.database
    product = db.fetch_one("SELECT * FROM products WHERE id = ?", [id])

    if product.nil?
      return response.json({ error: "Product not found" }, 404)
    end

    Tina4.cache_set("products:#{id}", product, ttl: 600)
  end

  response.json(product)
end

Tina4::Router.post("/api/products") do |request, response|
  body = request.body
  db = Tina4.database

  db.insert("products", { name: body["name"], price: body["price"].to_f })

  Tina4.cache_delete("products:all")

  product = db.fetch_one("SELECT * FROM products WHERE id = last_insert_rowid()")
  response.json(product, 201)
end

Tina4::Router.put("/api/products/{id:int}") do |request, response|
  id = request.params["id"]
  body = request.body
  db = Tina4.database

  db.update("products", { name: body["name"], price: body["price"].to_f }, { id: id })

  Tina4.cache_delete("products:#{id}")
  Tina4.cache_delete("products:all")

  product = db.fetch_one("SELECT * FROM products WHERE id = ?", [id])
  response.json(product)
end

Tina4::Router.delete("/api/products/{id:int}") do |request, response|
  id = request.params["id"]
  db = Tina4.database

  db.delete("products", { id: id })

  Tina4.cache_delete("products:#{id}")
  Tina4.cache_delete("products:all")

  response.json(nil, 204)
end

Tina4::Router.get("/api/cache/stats") do |request, response|
  response.json(Tina4.cache_stats)
end
```

---

## 11. Gotchas

### 1. Stale Data After Updates

**Problem:** Users see old data after an update.

**Fix:** Always invalidate related cache keys when data changes.

### 2. Cache Key Collisions

**Problem:** Different queries return the same cached data.

**Fix:** Include all relevant parameters in the cache key: `"products:category:#{category}:page:#{page}"`.

### 3. Memory Cache Lost on Restart

**Problem:** Cache is empty after server restart.

**Fix:** This is expected with memory cache. Use file or Redis cache for persistence.

### 4. Over-Caching Prevents Updates

**Problem:** Cache TTL is too long and users see stale data for hours.

**Fix:** Choose appropriate TTL values. For frequently changing data, use short TTLs or invalidate on write.

### 5. Cache Stampede

**Problem:** When a popular cache key expires, hundreds of requests simultaneously hit the database.

**Fix:** Use a mutex or similar locking mechanism around your cache-miss computation to ensure only one request computes the value while others wait.

### 6. Caching User-Specific Data

**Problem:** User A sees User B's profile because the cache key does not include the user ID.

**Fix:** Include the user ID in the cache key: `"profile:#{user_id}"`.

### 7. ResponseCache Ignores Query Parameters

**Problem:** `/api/products?page=1` and `/api/products?page=2` return the same cached response.

**Fix:** ResponseCache includes query parameters in the cache key by default. If it does not, ensure your middleware version is up to date.
