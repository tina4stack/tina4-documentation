# Chapter 11: Caching

## 1. From 800ms to 3ms

Your product catalog page runs 12 database queries. 800 milliseconds to render. Every visitor triggers the same queries, the same template rendering, the same JSON serialization -- for data that changes once a day.

Add caching. The first request takes 800ms. The next 10,000 take 3ms each. A 266x improvement from one line of configuration.

Caching stores the result of expensive work for reuse. Tina4 gives you three layers, each solving a different problem:

1. **Request-scoped query cache** -- on by default. Dedupes identical database reads inside a single request.
2. **Persistent DB query cache** -- opt-in. Shares query results across requests (and across server instances).
3. **HTTP response cache** -- the `ResponseCache` middleware. Stores entire HTTP responses and serves them without touching your handler.

You can layer all three, or use just the one you need.

---

## 2. The Request-Scoped Query Cache (On by Default)

Every `Database` connection caches query results for the life of a single request. This layer is **on by default** -- you do not configure anything.

When two handlers (or a handler and a middleware, or a template and a route) run the same `SELECT` during one request, the database is hit once. The second call returns the first call's result.

```python
from tina4_python.core.router import get
from tina4_python.database import Database

@get("/api/dashboard")
async def dashboard(request, response):
    db = Database()

    # First call hits the database
    users = db.fetch_all("SELECT * FROM users")

    # Same SQL + params during the same request -> served from the
    # request cache, no second round-trip
    users_again = db.fetch_all("SELECT * FROM users")

    return response({"count": len(users)})
```

The cache key comes from the SQL string and its parameters. Different SQL or different parameters mean different keys.

Two rules keep it safe:

- It is **cleared at the start of every request**, so it never serves one request's data to another.
- It is **flushed on any write** (`execute`, `insert`, `update`, `delete`), so a read after a write in the same request sees the new data.

Tuning:

```bash
TINA4_AUTO_CACHING=true        # default - set to false to turn this layer off
TINA4_AUTO_CACHING_TTL=5       # safety TTL in seconds (default: 5)
```

The TTL is a safety net for code that runs **outside** an HTTP request -- scripts, workers, queue consumers -- where there is no "start of request" to clear the cache. Inside a request, the per-request clear does the work.

---

## 3. The Persistent DB Query Cache (Opt-In)

The request-scoped cache disappears at the end of each request. When you want query results to survive across requests -- and to be shared across multiple server instances -- enable the persistent DB cache.

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=30          # default: 30 seconds
```

With this on, identical queries return cached results across requests until the TTL expires:

```python
from tina4_python.core.router import get
from tina4_python.database import Database

@get("/api/categories")
async def list_categories(request, response):
    db = Database()

    # First request: executes the query
    # Later requests within the TTL: served from the cache
    categories = db.fetch_all("SELECT * FROM categories ORDER BY name")

    return response({"categories": categories})
```

The persistent cache routes through the same backend system as the response cache. Point it at a shared store so several instances share one cache with global write-invalidation:

```bash
TINA4_DB_CACHE_BACKEND=redis                    # memory (default), file, redis, valkey, memcached, mongodb, database
TINA4_DB_CACHE_URL=redis://localhost:6379       # connection string for the chosen backend
```

When `TINA4_DB_CACHE_BACKEND` is left at `memory`, the cache lives in-process (fast, but not shared between instances).

### When to use the persistent cache

- Read-heavy apps where the same queries run on every request
- Reference data that changes rarely (categories, countries, settings)
- Dashboard queries that aggregate large datasets

### When not to use it

- Write-heavy data that changes constantly
- Queries with real-time requirements (live inventory, live prices)
- Anything that must always return the latest row

---

## 4. Bypassing the Cache Per Query

Both cache layers can be skipped for a single call. Pass `no_cache=True` and that call neither reads from nor writes to the cache -- it always hits the database:

```python
db = Database()

# fetch - full signature
fresh = db.fetch("SELECT * FROM products", params=None, limit=100, offset=0, no_cache=True)

# fetch_one - single row, always fresh
row = db.fetch_one("SELECT * FROM products WHERE id = ?", [42], no_cache=True)

# fetch_all - list of dicts, always fresh
rows = db.fetch_all("SELECT * FROM products", params=None, limit=0, offset=0, no_cache=True)
```

Use this for the one query that must read live data while the rest of your app benefits from caching.

### DB cache statistics

`db.cache_stats()` reports the state of the query cache for that connection:

```python
from tina4_python.core.router import get
from tina4_python.database import Database

@get("/api/db/cache-stats")
async def db_cache_stats(request, response):
    db = Database()
    return response(db.cache_stats())
```

```json
{
  "enabled": true,
  "mode": "request",
  "hits": 128,
  "misses": 42,
  "size": 17,
  "ttl": 5,
  "backend": "memory"
}
```

The fields are exactly:

- `enabled` -- whether any query caching is active
- `mode` -- `"request"` (request-scoped only), `"persistent"` (cross-request), or `"off"`
- `hits` / `misses` -- counters for this connection
- `size` -- number of cached entries
- `ttl` -- the active TTL in seconds
- `backend` -- the storage backend name

Flush the query cache and reset the counters with `db.cache_clear()`.

---

## 5. Response Caching with ResponseCache Middleware

The fastest cache is at the HTTP response level. The `ResponseCache` middleware stores the complete response and serves it on later requests without calling your handler at all.

Attach it as a string in the middleware list, with an optional TTL after the colon:

```python
from tina4_python.core.router import get
from datetime import datetime, timezone

@get("/api/products", middleware=["ResponseCache:300"])
async def list_products(request, response):
    # This handler runs 12 database queries and takes 800ms.
    # With ResponseCache, it runs once every 5 minutes.
    print("Handler called -- this should only appear once every 5 minutes")

    products = [
        {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
        {"id": 2, "name": "USB-C Hub", "price": 49.99},
        {"id": 3, "name": "Monitor Stand", "price": 129.99}
    ]

    return response({"products": products, "generated_at": datetime.now(timezone.utc).isoformat()})
```

`"ResponseCache:300"` caches the response for 300 seconds (5 minutes). During that window:

- The first request runs the handler (800ms)
- The next 10,000 requests serve the cached response (3ms each)
- After 300 seconds, the cache expires and the next request runs the handler again

```bash
curl http://localhost:7146/api/products
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

Call it again within 5 minutes and the `generated_at` timestamp is identical -- the handler did not run.

### Three ways to attach it

The string form (no import) and the class form both work.

```python
from tina4_python.core.router import get, middleware, cached
from tina4_python.cache import ResponseCache

# 1. String in the middleware list (TTL after the colon)
@get("/api/a", middleware=["ResponseCache:300"])
async def route_a(request, response):
    return response({"ok": True})

# 2. The @middleware decorator with the class (uses TINA4_CACHE_TTL, default 60s)
@middleware(ResponseCache)
@get("/api/b")
async def route_b(request, response):
    return response({"ok": True})

# 3. The @cached decorator for a per-route TTL override
@cached(max_age=120)
@get("/api/c")
async def route_c(request, response):
    return response({"ok": True})
```

### Response cache headers

On a cached route, the middleware adds two headers:

```
X-Cache: HIT
X-Cache-TTL: 247
```

- `X-Cache` is `HIT` (served from cache) or `MISS` (your handler ran)
- `X-Cache-TTL` is the seconds the entry has left on a HIT, or the TTL it was stored with on a MISS

The middleware does **not** set `Cache-Control`. Browser- and CDN-cache directives are your application's call -- add them yourself if you want them.

### Caching with query parameters

The cache key is the method plus the full URL including the query string. `/api/products?page=1` and `/api/products?page=2` cache separately:

```python
@get("/api/products", middleware=["ResponseCache:300"])
async def list_products(request, response):
    page = int(request.params.get("page", 1))
    return response({
        "page": page,
        "products": [],
        "generated_at": datetime.now(timezone.utc).isoformat()
    })
```

```bash
curl "http://localhost:7146/api/products?page=1"  # MISS, stores page=1
curl "http://localhost:7146/api/products?page=2"  # MISS, stores page=2
curl "http://localhost:7146/api/products?page=1"  # HIT
```

Only `GET` responses with a 200 status are cached by default.

### What not to cache

Do not put `ResponseCache` on:

- **POST, PUT, PATCH, DELETE routes** -- only GET responses are cached
- **User-specific endpoints** -- `/api/profile` returns different data per user, but the key is URL-only
- **Real-time data** -- stock prices, live scores, chat messages
- **Authenticated endpoints** -- unless every user shares the same response

```python
# GOOD: public, rarely changing data
@get("/api/categories", middleware=["ResponseCache:3600"])
async def list_categories(request, response):
    return response({"categories": []})

# BAD: user-specific data -- do NOT cache the whole response
@get("/api/profile", middleware=["auth_middleware"])
async def get_profile(request, response):
    return response(request.user)
```

### Response cache configuration

```bash
TINA4_CACHE_TTL=60             # default response TTL in seconds (default: 60)
TINA4_CACHE_MAX_ENTRIES=1000   # max cached entries before LRU eviction (default: 1000)
```

---

## 6. Cache Backends

Both the response cache and the key/value API (Section 7) share one set of backends, selected with `TINA4_CACHE_BACKEND`:

| Backend | Value | Notes |
|---------|-------|-------|
| Memory | `memory` (default) | In-process LRU. Fastest. Lost on restart. |
| File | `file` | JSON files on disk. Survives restarts, zero infrastructure. |
| Redis | `redis` | Shared across instances. Survives restarts. |
| Valkey | `valkey` | Redis-protocol compatible. |
| Memcached | `memcached` | Text protocol over TCP. Unauthenticated. |
| MongoDB | `mongodb` | TTL collection. Requires `pymongo`. |
| Database | `database` | A `tina4_cache` table in any Tina4-supported DB. |

```bash
# Memory - the default, nothing to set
TINA4_CACHE_BACKEND=memory

# File
TINA4_CACHE_BACKEND=file
TINA4_CACHE_DIR=data/cache     # directory for the file backend (default: data/cache)
```

### Redis (and Valkey / Memcached / MongoDB)

Network backends take a single connection URL. Credentials may be embedded in the URL or supplied separately:

```bash
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_URL=redis://[user:pass@]host:port/db   # e.g. redis://localhost:6379/0
TINA4_CACHE_USERNAME=                                # optional, if not in the URL
TINA4_CACHE_PASSWORD=                                # optional, if not in the URL
```

The URL accepts a username, a password (`redis://:pass@host`), and a database number (`/0`). Valkey, Memcached, and MongoDB use the same `TINA4_CACHE_URL` with their own schemes (`valkey://`, `memcached://`, `mongodb://`). Memcached is unauthenticated. For the `database` backend, `TINA4_CACHE_URL` is a SQL URL that falls back to `TINA4_DATABASE_URL`.

Your code never changes. `cache_get`, `cache_set`, and the `ResponseCache` middleware work the same on every backend -- only the storage changes.

### Graceful fallback

If a backend's driver is missing or its service or credentials are unreachable, Tina4 logs a warning and falls back to the **file** backend -- a real, persistent cache, never a silent no-op. Your app keeps caching even when Redis is down.

---

## 7. Direct Cache API (Key/Value)

For caching anything that is not a database query or an HTTP response, use the key/value helpers from `tina4_python.cache`.

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

# No TTL given -> uses TINA4_CACHE_TTL (default 60s)
cache_set("app:config", {"theme": "dark", "lang": "en"})
```

### cache_get

```python
from tina4_python.cache import cache_get, cache_set

product = cache_get("product:42")
# Returns the cached value, or None if missing or expired

if product is None:
    product = fetch_product_from_database(42)
    cache_set("product:42", product, ttl=300)
```

### cache_delete

```python
from tina4_python.cache import cache_delete

cache_delete("product:42")            # returns True if the key existed
```

### Real-World Pattern: Cache-Aside

The most common pattern is cache-aside (lazy loading): check the cache, fall back to the database, store the result.

```python
from tina4_python.core.router import get
from tina4_python.cache import cache_get, cache_set
from tina4_python.database import Database

@get("/api/products/{product_id}")
async def get_product(request, response):
    product_id = request.params["product_id"]
    cache_key = f"product:{product_id}"

    # 1. Try the cache
    product = cache_get(cache_key)
    if product is not None:
        return response({**product, "source": "cache"})

    # 2. Miss -- fetch from the database
    db = Database()
    product = db.fetch_one(
        "SELECT id, name, category, price, in_stock FROM products WHERE id = ?",
        [product_id]
    )
    if product is None:
        return response({"error": "Product not found"}, 404)

    # 3. Store for next time
    cache_set(cache_key, product, ttl=600)
    return response({**product, "source": "database"})
```

First call returns `"source": "database"`; the next returns `"source": "cache"`.

### Key/value statistics

`cache_stats()` from `tina4_python.cache` reports the backend's counters:

```python
from tina4_python.cache import cache_stats

stats = cache_stats()
```

```json
{
  "hits": 15234,
  "misses": 891,
  "size": 42,
  "backend": "memory"
}
```

The fields are exactly `hits`, `misses`, `size`, and `backend`. Flush everything with `clear_cache()`:

```python
from tina4_python.cache import clear_cache

clear_cache()   # flush all entries and reset stats
```

---

## 8. Cache Invalidation Strategies

Cache invalidation is the hard problem. A stale cache serves outdated data; premature invalidation throws away the performance gain. Three strategies handle the trade-off.

### Strategy 1: Time-Based Expiry (TTL)

The simplest. Set a TTL and let the entry expire on its own:

```python
cache_set("products:featured", featured_products, ttl=600)  # expires in 10 minutes
```

Good when near-real-time accuracy is fine. A 10-minute delay on the featured list rarely matters.

### Strategy 2: Event-Based Invalidation

Clear the cache when the underlying data changes:

```python
from tina4_python.core.router import put
from tina4_python.cache import cache_delete
from tina4_python.database import Database

@put("/api/products/{product_id}")
async def update_product(request, response):
    product_id = request.params["product_id"]
    body = request.body
    db = Database()

    db.execute(
        "UPDATE products SET name = ?, price = ? WHERE id = ?",
        [body["name"], body["price"], product_id]
    )

    # Invalidate this product and any list caches that include it
    cache_delete(f"product:{product_id}")
    cache_delete("products:all")
    cache_delete("products:featured")

    updated = db.fetch_one("SELECT * FROM products WHERE id = ?", [product_id])
    return response(updated)
```

The most accurate strategy -- the cache is fresh right after a write. The cost is discipline: you must invalidate everywhere the data could be cached.

### Strategy 3: Write-Through Cache

Update the cache at the same moment as the database:

```python
@put("/api/products/{product_id}")
async def update_product(request, response):
    product_id = request.params["product_id"]
    body = request.body
    db = Database()

    db.execute(
        "UPDATE products SET name = ?, price = ? WHERE id = ?",
        [body["name"], body["price"], product_id]
    )

    updated = db.fetch_one("SELECT * FROM products WHERE id = ?", [product_id])

    # Write the new data straight to the cache instead of deleting
    cache_set(f"product:{product_id}", updated, ttl=600)
    return response(updated)
```

The cache always holds the latest data, so there is no miss after an update -- the next read comes from the warm cache.

---

## 9. TTL Management

The right TTL depends on how often the data changes and how much staleness you can tolerate:

| Data Type | Suggested TTL | Reasoning |
|-----------|---------------|-----------|
| Static config (categories, countries) | 3600 (1 hour) | Changes rarely, stale data is harmless |
| Product catalog | 300 (5 min) | Updates several times per day |
| User profile | 60 (1 min) | Users expect changes to appear quickly |
| Search results | 120 (2 min) | Balance freshness and performance |
| Dashboard stats | 30 (30 sec) | Near-real-time but expensive to compute |
| Exchange rates | 60 (1 min) | Updates often, slight delay is acceptable |
| Shopping cart | 0 (no cache) | Must always reflect current state |

### Dynamic TTL

Adjust the TTL based on the data:

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

## 10. Monitoring Cache Performance

Expose the stats to verify caching is helping:

```python
from tina4_python.core.router import get
from tina4_python.cache import cache_stats

@get("/api/cache/stats")
async def get_cache_stats(request, response):
    return response(cache_stats())
```

```bash
curl http://localhost:7146/api/cache/stats
```

```json
{
  "hits": 15234,
  "misses": 891,
  "size": 42,
  "backend": "memory"
}
```

Compute the hit rate yourself: `hits / (hits + misses)`. Above 90% means your strategy works. Below 80% means TTLs are too short, the cache is too small, or you are caching data that is not read often enough to pay off.

---

## 11. Combining Cache Layers

For maximum performance, stack the layers. Each one catches what the layer above it missed.

```python
from datetime import datetime, timezone
from tina4_python.core.router import get
from tina4_python.cache import cache_get, cache_set
from tina4_python.database import Database
import math

@get("/api/catalog", middleware=["ResponseCache:60"])
async def get_catalog(request, response):
    page = int(request.params.get("page", 1))
    cache_key = f"catalog:page:{page}"

    # Layer 1: key/value cache
    catalog = cache_get(cache_key)
    if catalog is not None:
        return response({**catalog, "cache": "kv"})

    # Layer 2: database query (request-scoped cache always on;
    # persistent cache too if TINA4_DB_CACHE=true)
    db = Database()
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

    cache_set(cache_key, catalog, ttl=300)
    return response({**catalog, "cache": "none"})
```

The layers, from outermost to innermost:

1. **ResponseCache** (60s) -- the whole HTTP response is served from cache. No Python runs.
2. **Key/value cache** (300s) -- if the response cache expired, skip the database queries.
3. **DB query cache** -- individual query results are cached even when the key/value layer missed.

The first visitor after a full expiry waits 800ms. Everyone else gets the response in under 5ms.

---

## 12. Exercise: Cache an Expensive Product Listing Endpoint

Build a product listing endpoint that caches at multiple levels.

### Requirements

1. Create a `GET /api/store/products` endpoint that:
   - Accepts query parameters: `category`, `page`, `limit`
   - Returns a list of products with pagination metadata
   - Uses the key/value API (`cache_get`/`cache_set`) with a 5-minute TTL
   - Includes a `source` field in the response (`"cache"` or `"database"`)

2. Create a `POST /api/store/products` endpoint that:
   - Creates a new product
   - Invalidates the relevant cache entries

3. Create a `GET /api/store/cache-stats` endpoint that returns cache statistics

### Test with:

```bash
# First call -- cache miss, slow
curl "http://localhost:7146/api/store/products?category=Electronics&page=1"

# Second call -- cache hit, fast
curl "http://localhost:7146/api/store/products?category=Electronics&page=1"

# Different category -- cache miss
curl "http://localhost:7146/api/store/products?category=Fitness&page=1"

# Create a product -- should invalidate cache
curl -X POST http://localhost:7146/api/store/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Smart Watch", "category": "Electronics", "price": 299.99}'

# Same query again -- cache miss (invalidated by the POST)
curl "http://localhost:7146/api/store/products?category=Electronics&page=1"

# Check cache stats
curl http://localhost:7146/api/store/cache-stats
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

    # Build a cache key from the query parameters
    key_data = json.dumps({"category": category, "page": page, "limit": limit})
    cache_key = f"store:products:{hashlib.md5(key_data.encode()).hexdigest()}"

    # Try the cache first
    cached = cache_get(cache_key)
    if cached is not None:
        return response({**cached, "source": "cache"})

    # Simulate an expensive database query
    time.sleep(0.1)  # 100ms delay

    products = get_product_store()
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

**First call (cache miss):**

```bash
curl "http://localhost:7146/api/store/products?category=Electronics&page=1"
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

**Second call (cache hit):** the same payload, but `source` changes from `"database"` to `"cache"`. The handler skipped the simulated query.

---

## 14. Gotchas

### 1. Caching Authenticated Responses

**Problem:** User A's profile is served to User B because the response was cached.

**Cause:** `ResponseCache` keys on the URL only. If `/api/profile` returns different data per user but every request hits the same URL, the first user's response is served to everyone.

**Fix:** Do not put `ResponseCache` on user-specific endpoints. Use the key/value API with a per-user key instead: `cache_set(f"profile:{user_id}", data, ttl=300)`.

### 2. Memory Cache Lost on Restart

**Problem:** After a restart, performance drops until the cache warms up.

**Cause:** The memory backend lives in-process and disappears when the process restarts. Every request is a miss until data is cached again.

**Fix:** In production, use a persistent backend -- `TINA4_CACHE_BACKEND=redis` (shared and durable) or `file` (durable, zero infrastructure). Or run a warmup script that pre-populates hot keys on startup.

### 3. Stale Data After a Database Update

**Problem:** You updated a product's price, but the API still returns the old one.

**Cause:** A cached value still holds the old data and has not expired.

**Fix:** Invalidate or update the cache when you change the underlying data. Use `cache_delete(...)` after a write, or write through with `cache_set(...)`. The request-scoped DB cache already flushes on writes within the same request; the key/value and persistent caches do not -- you manage those.

### 4. Cache Key Collisions

**Problem:** Two different queries return the same cached data.

**Cause:** The keys are not specific enough. Using `"products"` for both the full list and a filtered list collides.

**Fix:** Put every relevant parameter in the key -- `"products:category:Electronics:page:1:limit:20"` -- or hash the parameters: `f"products:{hashlib.md5(json.dumps(params).encode()).hexdigest()}"`.

### 5. Serialization Overhead

**Problem:** Caching makes some requests slower, not faster.

**Cause:** The cached object is large. Serializing and deserializing it costs more than recomputing it.

**Fix:** Cache only what is expensive to produce. If the original work takes 5ms and cache serialization takes 10ms, caching loses. Measure before and after.

### 6. Forgetting the TTL on the Memory Backend

**Problem:** Cache entries never expire and memory grows.

**Cause:** You called `cache_set("key", value, ttl=0)` (or relied on a zero TTL). A zero TTL means no expiry, so the entry lives until eviction or restart.

**Fix:** Pass a real TTL: `cache_set("key", value, ttl=300)`. Even for data that "never changes," use a long TTL like 86400 (24 hours) as a safety net. The memory backend caps total entries at `TINA4_CACHE_MAX_ENTRIES` and evicts the least-recently-used entry when full.
