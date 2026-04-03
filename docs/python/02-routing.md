# Chapter 2: Routing

## 1. How Routing Works in Tina4

Every web application maps URLs to code. A browser requests `/products`. The framework finds the handler for `/products`, runs it, sends back the result. That mapping is routing.

In Tina4 Python, routes live in Python files inside `src/routes/`. Every `.py` file in that directory (and its subdirectories) is auto-loaded at startup. No registration file. No central config. Drop a file in. It works.

The simplest route:

```python
from tina4_python.core.router import get

@get("/hello")
async def hello(request, response):
    return response.json({"message": "Hello, World!"})
```

Save that as `src/routes/hello.py`, start the server with `tina4 serve`, and visit `http://localhost:7145/hello`:

```json
{"message":"Hello, World!"}
```

One decorator. One function. Done.

---

## 2. HTTP Methods

Tina4 supports all five standard HTTP methods. Each has a decorator:

```python
from tina4_python.core.router import get, post, put, patch, delete

@get("/products")
async def list_products(request, response):
    return response.json({"action": "list all products"})

@post("/products")
async def create_product(request, response):
    return response.json({"action": "create a product"}, 201)

@put("/products/{id}")
async def replace_product(id, request, response):
    return response.json({"action": f"replace product {id}"})

@patch("/products/{id}")
async def update_product(id, request, response):
    return response.json({"action": f"update product {id}"})

@delete("/products/{id}")
async def delete_product(id, request, response):
    return response.json({"action": f"delete product {id}"})
```

Test each one:

```bash
curl http://localhost:7145/products
```

```json
{"action":"list all products"}
```

```bash
curl -X POST http://localhost:7145/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Widget"}'
```

```json
{"action":"create a product"}
```

```bash
curl -X PUT http://localhost:7145/products/42
```

```json
{"action":"replace product 42"}
```

```bash
curl -X PATCH http://localhost:7145/products/42
```

```json
{"action":"update product 42"}
```

```bash
curl -X DELETE http://localhost:7145/products/42
```

```json
{"action":"delete product 42"}
```

`GET` reads. `POST` creates. `PUT` replaces. `PATCH` patches. `DELETE` removes. REST convention. Predictable API.

---

## 3. Path Parameters

Path parameters capture values from the URL. Wrap the parameter name in curly braces:

```python
from tina4_python.core.router import get

@get("/users/{id}/posts/{post_id}")
async def user_post(id, post_id, request, response):
    return response.json({
        "user_id": id,
        "post_id": post_id
    })
```

```bash
curl http://localhost:7145/users/5/posts/99
```

```json
{"user_id":"5","post_id":"99"}
```

Notice `user_id` came back as the string `"5"`, not the integer `5`. Path parameters are strings by default. In Python, path parameters are passed as function arguments -- the parameter names in the function signature must match the `{name}` placeholders in the route pattern.

> **Auto-casting:** Tina4 automatically casts path parameter values that are purely numeric to integers. For example, requesting `/users/42/posts/99` will pass `id` as the integer `42` and `post_id` as the integer `99` to your handler -- no explicit `:int` type hint required. The `:int` type hint adds validation (rejecting non-numeric values with a 404), but the auto-casting happens regardless.

### Typed Parameters

Enforce a type by adding a colon and the type after the parameter name:

```python
from tina4_python.core.router import get

@get("/orders/{id:int}")
async def get_order(id, request, response):
    # id is already an integer thanks to :int
    return response.json({
        "order_id": id,
        "type": type(id).__name__
    })
```

```bash
curl http://localhost:7145/orders/42
```

```json
{"order_id":42,"type":"int"}
```

Pass a non-integer value and the route does not match. A 404:

```bash
curl http://localhost:7145/orders/abc
```

```json
{"error":"Not found","path":"/orders/abc","status":404}
```

Supported types:

| Type | Matches | Auto-cast | Example |
|------|---------|-----------|---------|
| `int` | Digits only | Integer | `{id:int}` matches `42` but not `abc` |
| `float` | Decimal numbers | Float | `{price:float}` matches `19.99` |
| `path` | All remaining path segments (catch-all) | String | `{slug:path}` matches `docs/api/auth` |

The `{name}` form (no type) matches any single path segment and returns it as a string.

### Typed Parameters in Action

Here is a complete example showing the most commonly used typed parameters together:

```python
from tina4_python.core.router import get

# Integer parameter -- only digits match, auto-cast to int
@get("/products/{id:int}")
async def get_product(id, request, response):
    # id is an integer, e.g. 42
    return response.json({
        "product_id": id,
        "type": type(id).__name__
    })

# Float parameter -- decimal numbers, auto-cast to float
@get("/products/{id:int}/price/{price:float}")
async def check_price(id, price, request, response):
    return response.json({
        "product_id": id,
        "price": price,
        "type": type(price).__name__
    })

# Path parameter -- catch-all, captures remaining segments as a string
@get("/files/{filepath:path}")
async def serve_file(filepath, request, response):
    # filepath could be "images/photos/cat.jpg"
    return response.json({
        "filepath": filepath,
        "type": type(filepath).__name__
    })
```

```bash
# Integer route -- matches digits, returns an int
curl http://localhost:7145/products/42
```

```json
{"product_id":42,"type":"int"}
```

```bash
# Integer route -- non-integer gives a 404
curl http://localhost:7145/products/abc
```

```json
{"error":"Not found","path":"/products/abc","status":404}
```

```bash
# Path catch-all -- captures everything after /files/
curl http://localhost:7145/files/images/photos/cat.jpg
```

```json
{"filepath":"images/photos/cat.jpg","type":"str"}
```

The `:int` and `:float` types act as both a constraint and a converter. If the URL segment does not match the expected pattern, the route is skipped entirely and Tina4 moves on to the next registered route (or returns 404 if nothing matches). The `:path` type is greedy -- it consumes all remaining segments, making it ideal for file paths and documentation URLs.

---

## 4. Query Parameters

Query parameters are the key-value pairs after the `?` in a URL. Access them through `request.params`:

```python
from tina4_python.core.router import get

@get("/search")
async def search(request, response):
    q = request.params.get("q", "")
    page = int(request.params.get("page", 1))
    limit = int(request.params.get("limit", 10))

    return response.json({
        "query": q,
        "page": page,
        "limit": limit,
        "offset": (page - 1) * limit
    })
```

```bash
curl "http://localhost:7145/search?q=keyboard&page=2&limit=20"
```

```json
{"query":"keyboard","page":2,"limit":20,"offset":20}
```

If a query parameter is missing, `request.params.get("key")` returns `None`. Use `.get()` with a default value.

---

## 5. Route Groups

A set of routes sharing a common prefix belongs in a `group()`:

```python
from tina4_python.core.router import Router, get, post

Router.group("/api/v1", lambda: [
    Router.get("/users", list_users),
    Router.get("/users/{id:int}", get_user),
    Router.post("/users", create_user),
    Router.get("/products", list_products),
])

async def list_users(request, response):
    return response.json({"users": []})

async def get_user(id, request, response):
    return response.json({"user": {"id": id, "name": "Alice"}})

async def create_user(request, response):
    return response.json({"created": True}, 201)

async def list_products(request, response):
    return response.json({"products": []})
```

These routes register as `/api/v1/users`, `/api/v1/users/{id}`, and `/api/v1/products`. Short paths inside the group. Tina4 prepends the prefix. `Router.group()` is a classmethod that takes a prefix, a callback, and an optional middleware list.

```bash
curl http://localhost:7145/api/v1/users
```

```json
{"users":[]}
```

```bash
curl http://localhost:7145/api/v1/products
```

```json
{"products":[]}
```

Groups nest:

```python
from tina4_python.core.router import Router

async def v1_status(request, response):
    return response.json({"version": "1.0"})

async def v2_status(request, response):
    return response.json({"version": "2.0"})

Router.group("/api", lambda: [
    Router.group("/v1", lambda: [
        Router.get("/status", v1_status),
    ]),
    Router.group("/v2", lambda: [
        Router.get("/status", v2_status),
    ]),
])
```

```bash
curl http://localhost:7145/api/v1/status
```

```json
{"version":"1.0"}
```

```bash
curl http://localhost:7145/api/v2/status
```

```json
{"version":"2.0"}
```

---

## 6. Middleware on Routes

Middleware is code that runs before or after your route handler. Authentication. Logging. Rate limiting. Input validation. Anything that belongs on multiple routes. Chapter 10 covers middleware in depth. Here is how it connects to routes.

### Middleware on a Single Route

Attach middleware with the `@middleware` decorator. Middleware classes use `before_*` and `after_*` methods:

```python
from tina4_python.core.router import get, middleware
import time

class LogRequest:
    def before_request(self, request, response):
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {request.method} {request.path}")
        return request, response

    def after_request(self, request, response):
        print(f"  Completed: {response.status_code}")
        return request, response

@middleware(LogRequest)
@get("/api/data")
async def get_data(request, response):
    return response.json({"data": [1, 2, 3]})
```

Middleware classes have `before_*` methods (called before the handler) and `after_*` methods (called after). If a `before_*` method sets `response.status_code` to 400 or above, the handler is skipped entirely. Useful for blocking unauthorized requests.

### Blocking Middleware

Middleware that checks for an API key:

```python
from tina4_python.core.router import get, middleware

class RequireApiKey:
    def before_check(self, request, response):
        api_key = request.headers.get("x-api-key", "")
        if api_key != "my-secret-key":
            return request, response.json({"error": "Invalid API key"}, 401)
        return request, response

@middleware(RequireApiKey)
@get("/api/secret")
async def secret_data(request, response):
    return response.json({"secret": "The answer is 42"})
```

```bash
curl http://localhost:7145/api/secret
```

```json
{"error":"Invalid API key"}
```

Status: `401 Unauthorized`.

```bash
curl http://localhost:7145/api/secret -H "X-API-Key: my-secret-key"
```

```json
{"secret":"The answer is 42"}
```

### Multiple Middleware

Chain multiple middleware classes as arguments:

```python
@middleware(LogRequest, RequireApiKey)
@get("/api/important")
async def important_data(request, response):
    return response.json({"data": "important stuff"})
```

Middleware runs left to right: `LogRequest` first, then `RequireApiKey`, then the route handler. If any middleware's `before_*` method returns a response with status 400+, the chain stops and the handler is skipped.

---

## 7. Route Decorators: @noauth() and @secured()

Two decorators control authentication at the route level.

### @noauth() -- Public Routes

When your application has global authentication middleware, `@noauth()` marks a route as public:

```python
from tina4_python.core.router import get, noauth

@noauth()
@get("/api/public/info")
async def public_info(request, response):
    return response.json({
        "app": "My Store",
        "version": "1.0.0"
    })
```

`@noauth()` tells Tina4 to skip authentication checks for this route, even if global auth middleware is configured in `.env` or applied to the parent group.

### @secured() -- Protected GET Routes

`@secured()` marks a GET route as requiring authentication:

```python
from tina4_python.core.router import get, secured

@secured()
@get("/api/profile")
async def profile(request, response):
    # request.user is populated by the auth middleware
    return response.json({
        "user": request.user
    })
```

By default, `POST`, `PUT`, `PATCH`, and `DELETE` routes are secured. `GET` routes are public unless you add `@secured()`. This matches the common pattern: reading data is public, modifying data requires authentication.

---

## 8. Route Chaining: .secure() and .cache()

Route decorators return a chainable object. Two methods you can call on any route: `.secure()` and `.cache()`.

### .secure()

`.secure()` requires a valid bearer token in the `Authorization` header. If the token is missing or invalid, the route returns `401 Unauthorized` without ever reaching your handler:

```python
from tina4_python.core.router import get

@get("/api/account")
async def get_account(request, response):
    return response.json({"account": request.user})

get_account.secure()
```

Or chain it inline using the `Router` class directly:

```python
from tina4_python.core.router import Router

Router.get("/api/account", get_account).secure()
```

```bash
curl http://localhost:7145/api/account
# 401 Unauthorized

curl http://localhost:7145/api/account -H "Authorization: Bearer eyJhbGci..."
# 200 OK
```

### .cache()

`.cache()` enables response caching for the route. Once the handler runs and produces a response, subsequent requests to the same URL return the cached result without re-executing the handler:

```python
Router.get("/api/catalog", list_catalog).cache()
```

### Chaining Both

Chain `.secure()` and `.cache()` together:

```python
Router.get("/api/data", handler).secure().cache()
```

This route requires a bearer token and caches the response. Order does not matter -- `.cache().secure()` produces the same result.

---

## 9. Wildcard and Catch-All Routes

### Wildcard Routes

Use `*` at the end of a path to match anything after it:

```python
from tina4_python.core.router import get

@get("/docs/*")
async def docs_handler(request, response):
    path = request.params.get("*", "")
    return response.json({
        "section": "docs",
        "path": path
    })
```

```bash
curl http://localhost:7145/docs/getting-started
```

```json
{"section":"docs","path":"getting-started"}
```

```bash
curl http://localhost:7145/docs/api/authentication/jwt
```

```json
{"section":"docs","path":"api/authentication/jwt"}
```

### Catch-All Route (Custom 404)

A catch-all handles any unmatched URL:

```python
from tina4_python.core.router import get

@get("/*")
async def not_found(request, response):
    return response.json({
        "error": "Page not found",
        "path": request.path
    }, 404)
```

Define this route last (or in a file that sorts alphabetically after your other route files). Tina4 matches routes in registration order -- first match wins.

You can also create a custom 404 page by placing a template at `src/templates/errors/404.html`:

```html
{% extends "base.html" %}

{% block title %}Not Found{% endblock %}

{% block content %}
    <h1>404 - Page Not Found</h1>
    <p>The page you are looking for does not exist.</p>
    <a href="/">Go back home</a>
{% endblock %}
```

Tina4 uses this template for any unmatched route when the file exists.

---

## 10. Route Listing via CLI

As your application grows, see all registered routes at a glance:

```bash
tina4 routes
```

```
Method   Path                          Middleware          Auth
------   ----                          ----------          ----
GET      /hello                        -                   public
GET      /products                     -                   public
POST     /products                     -                   secured
PUT      /products/{id}                -                   secured
PATCH    /products/{id}                -                   secured
DELETE   /products/{id}                -                   secured
GET      /api/v1/users                 -                   public
GET      /api/v1/users/{id:int}        -                   public
POST     /api/v1/users                 -                   secured
GET      /api/public/info              -                   @noauth
GET      /api/profile                  -                   @secured
GET      /search                       -                   public
GET      /docs/*                       -                   public
```

The `Auth` column shows whether a route is public, secured (default for non-GET methods), `@noauth`, or `@secured`.

Filter by method:

```bash
tina4 routes --method POST
```

```
Method   Path                          Middleware          Auth
------   ----                          ----------          ----
POST     /products                     -                   secured
POST     /api/v1/users                 -                   secured
```

Search for a path pattern:

```bash
tina4 routes --filter users
```

```
Method   Path                          Middleware          Auth
------   ----                          ----------          ----
GET      /api/v1/users                 -                   public
GET      /api/v1/users/{id:int}        -                   public
POST     /api/v1/users                 -                   secured
```

---

## 11. Organizing Route Files

Organize route files any way you want. Tina4 loads every `.py` file in `src/routes/` recursively. Two common patterns:

### Pattern 1: One File Per Resource

```
src/routes/
├── products.py     # All product routes
├── users.py        # All user routes
├── orders.py       # All order routes
└── pages.py        # HTML page routes
```

### Pattern 2: Subdirectories by Feature

```
src/routes/
├── api/
│   ├── products.py
│   ├── users.py
│   └── orders.py
├── admin/
│   ├── dashboard.py
│   └── settings.py
└── pages/
    ├── home.py
    └── about.py
```

Both work identically. The directory structure has no effect on URL paths -- only the route definitions inside the files matter. Choose whichever keeps your project navigable.

---

## 12. Exercise: Build a Full CRUD API for Products

Build a complete REST API for managing products. All data stored in a Python list (no database yet -- Chapter 5 adds that).

### Requirements

Create a file `src/routes/product_api.py` with the following routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List all products. Support `?category=` filter. |
| `GET` | `/api/products/{id:int}` | Get a single product by ID. Return 404 if not found. |
| `POST` | `/api/products` | Create a new product. Return 201. |
| `PUT` | `/api/products/{id:int}` | Replace a product. Return 404 if not found. |
| `DELETE` | `/api/products/{id:int}` | Delete a product. Return 204 with no body. |

Each product has: `id` (int), `name` (string), `category` (string), `price` (float), `in_stock` (bool).

Start with this seed data:

```python
products = [
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": True},
    {"id": 2, "name": "Yoga Mat", "category": "Fitness", "price": 29.99, "in_stock": True},
    {"id": 3, "name": "Coffee Grinder", "category": "Kitchen", "price": 49.99, "in_stock": False},
    {"id": 4, "name": "Standing Desk", "category": "Office", "price": 549.99, "in_stock": True},
    {"id": 5, "name": "Running Shoes", "category": "Fitness", "price": 119.99, "in_stock": True}
]
```

Test with:

```bash
# List all
curl http://localhost:7145/api/products

# Filter by category
curl "http://localhost:7145/api/products?category=Fitness"

# Get one
curl http://localhost:7145/api/products/3

# Create
curl -X POST http://localhost:7145/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Desk Lamp", "category": "Office", "price": 39.99, "in_stock": true}'

# Update
curl -X PUT http://localhost:7145/api/products/3 \
  -H "Content-Type: application/json" \
  -d '{"name": "Burr Coffee Grinder", "category": "Kitchen", "price": 59.99, "in_stock": true}'

# Delete
curl -X DELETE http://localhost:7145/api/products/3

# Not found
curl http://localhost:7145/api/products/999
```

---

## 13. Solution

Create `src/routes/product_api.py`:

```python
from tina4_python.core.router import get, post, put, delete

# In-memory product store (resets on server restart)
products = [
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": True},
    {"id": 2, "name": "Yoga Mat", "category": "Fitness", "price": 29.99, "in_stock": True},
    {"id": 3, "name": "Coffee Grinder", "category": "Kitchen", "price": 49.99, "in_stock": False},
    {"id": 4, "name": "Standing Desk", "category": "Office", "price": 549.99, "in_stock": True},
    {"id": 5, "name": "Running Shoes", "category": "Fitness", "price": 119.99, "in_stock": True}
]

next_id = 6


# List all products, optionally filter by category
@get("/api/products")
async def list_products(request, response):
    category = request.params.get("category")

    if category is not None:
        filtered = [p for p in products if p["category"].lower() == category.lower()]
        return response.json({"products": filtered, "count": len(filtered)})

    return response.json({"products": products, "count": len(products)})


# Get a single product by ID
@get("/api/products/{id:int}")
async def get_product(id, request, response):
    for product in products:
        if product["id"] == id:
            return response.json(product)

    return response.json({"error": "Product not found", "id": id}, 404)


# Create a new product
@post("/api/products")
async def create_product(request, response):
    global next_id
    body = request.body

    if not body.get("name"):
        return response.json({"error": "Name is required"}, 400)

    product = {
        "id": next_id,
        "name": body["name"],
        "category": body.get("category", "Uncategorized"),
        "price": float(body.get("price", 0)),
        "in_stock": bool(body.get("in_stock", True))
    }
    next_id += 1

    products.append(product)

    return response.json(product, 201)


# Replace a product
@put("/api/products/{id:int}")
async def replace_product(id, request, response):
    body = request.body

    for i, product in enumerate(products):
        if product["id"] == id:
            products[i] = {
                "id": id,
                "name": body.get("name", product["name"]),
                "category": body.get("category", product["category"]),
                "price": float(body.get("price", product["price"])),
                "in_stock": bool(body.get("in_stock", product["in_stock"]))
            }
            return response.json(products[i])

    return response.json({"error": "Product not found", "id": id}, 404)


# Delete a product
@delete("/api/products/{id:int}")
async def delete_product(id, request, response):
    for i, product in enumerate(products):
        if product["id"] == id:
            products.pop(i)
            return response.json(None, 204)

    return response.json({"error": "Product not found", "id": id}, 404)
```

**Expected output for the test commands:**

List all:

```json
{"products":[{"id":1,"name":"Wireless Keyboard","category":"Electronics","price":79.99,"in_stock":true},{"id":2,"name":"Yoga Mat","category":"Fitness","price":29.99,"in_stock":true},{"id":3,"name":"Coffee Grinder","category":"Kitchen","price":49.99,"in_stock":false},{"id":4,"name":"Standing Desk","category":"Office","price":549.99,"in_stock":true},{"id":5,"name":"Running Shoes","category":"Fitness","price":119.99,"in_stock":true}],"count":5}
```

Filter by category:

```json
{"products":[{"id":2,"name":"Yoga Mat","category":"Fitness","price":29.99,"in_stock":true},{"id":5,"name":"Running Shoes","category":"Fitness","price":119.99,"in_stock":true}],"count":2}
```

Get one:

```json
{"id":3,"name":"Coffee Grinder","category":"Kitchen","price":49.99,"in_stock":false}
```

Create:

```json
{"id":6,"name":"Desk Lamp","category":"Office","price":39.99,"in_stock":true}
```

(Status: `201 Created`)

Update:

```json
{"id":3,"name":"Burr Coffee Grinder","category":"Kitchen","price":59.99,"in_stock":true}
```

Delete: empty response with status `204 No Content`.

Not found:

```json
{"error":"Product not found","id":999}
```

(Status: `404 Not Found`)

---

## 14. Gotchas

### 1. Trailing slashes matter

**Problem:** `/products` works but `/products/` returns a 404 (or vice versa).

**Cause:** Tina4 treats `/products` and `/products/` as different routes by default.

**Fix:** Pick one convention and stick with it. If you want both to work, register the route without a trailing slash -- Tina4 redirects `/products/` to `/products` when `TINA4_TRAILING_SLASH_REDIRECT=true` is set in `.env`.

### 2. Parameter names must be unique in a path

**Problem:** `/users/{id}/posts/{id}` behaves wrong -- both parameters share a name.

**Cause:** The second `{id}` overwrites the first in `request.params`.

**Fix:** Use distinct names: `/users/{user_id}/posts/{post_id}`.

### 3. Method conflicts

**Problem:** You defined `@get("/items/{id}")` and `@get("/items/{action}")` and the wrong handler runs.

**Cause:** Both patterns match `/items/42`. The first one registered wins.

**Fix:** Use typed parameters to disambiguate: `@get("/items/{id:int}")` matches integers only, leaving `/items/export` free for the other route. Or restructure your paths: `/items/{id:int}` and `/items/actions/{action}`.

### 4. Route handler must return a response

**Problem:** Your route handler runs but the browser shows an empty page or a 500 error.

**Cause:** You forgot the `return` statement. Without `return`, the handler returns `None` and Tina4 has nothing to send back.

**Fix:** Every handler must return something: `return response.json(...)` or `return response.html(...)` or `return response.render(...)`.

### 5. Decorator order matters

**Problem:** Your `@middleware` decorator has no effect, or your `@noauth()` is ignored.

**Cause:** Python decorators apply bottom-up. Wrong stacking order breaks registration.

**Fix:** Put the route decorator (`@get`, `@post`, etc.) first (closest to the function), then additional decorators above it:

```python
@middleware(require_api_key)  # Applied second (wraps the route)
@get("/api/secret")           # Applied first (registers the route)
async def secret(request, response):
    ...
```

### 6. Forgetting async def

**Problem:** Your route handler raises a `TypeError` about a coroutine or the response is a coroutine object instead of JSON.

**Cause:** You used `def` instead of `async def`.

**Fix:** Every route handler in Tina4 Python must be `async def`. The framework runs on an async server. Change `def my_handler(request, response):` to `async def my_handler(request, response):`.

### 7. Group prefix must start with a slash

**Problem:** `Router.group("api/v1", ...)` produces routes that do not match.

**Cause:** The group prefix should start with `/` for consistency.

**Fix:** Start group prefixes with `/`: `Router.group("/api/v1", ...)`.
