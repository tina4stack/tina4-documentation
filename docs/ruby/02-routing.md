# Chapter 2: Routing

## 1. How Routing Works in Tina4

Every web application maps URLs to code. You type `/products` in your browser. The framework finds the handler for `/products`, runs it, sends back the result. That mapping is routing.

In Tina4, routes live in Ruby files inside `src/routes/`. Every `.rb` file in that directory (and its subdirectories) is auto-loaded at startup. No registration. No central config. Drop a file in. It works.

The simplest possible route:

```ruby
Tina4::Router.get("/hello") do |request, response|
  response.json({ message: "Hello, World!" })
end
```

Save that as `src/routes/hello.rb`, start the server, visit `http://localhost:7147/hello`:

```json
{"message":"Hello, World!"}
```

One line registers the route. One block handles the request. Done.

---

## 2. HTTP Methods

Tina4 supports all five standard HTTP methods. Each one lives on `Tina4::Router`:

```ruby
Tina4::Router.get("/products") do |request, response|
  response.json({ action: "list all products" })
end

Tina4::Router.post("/products") do |request, response|
  response.json({ action: "create a product" }, 201)
end

Tina4::Router.put("/products/{id}") do |request, response|
  id = request.params[:id]
  response.json({ action: "replace product #{id}" })
end

Tina4::Router.patch("/products/{id}") do |request, response|
  id = request.params[:id]
  response.json({ action: "update product #{id}" })
end

Tina4::Router.delete("/products/{id}") do |request, response|
  id = request.params[:id]
  response.json({ action: "delete product #{id}" })
end
```

Test each one:

```bash
curl http://localhost:7147/products
```

```json
{"action":"list all products"}
```

```bash
curl -X POST http://localhost:7147/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Widget"}'
```

```json
{"action":"create a product"}
```

```bash
curl -X PUT http://localhost:7147/products/42
```

```json
{"action":"replace product 42"}
```

```bash
curl -X PATCH http://localhost:7147/products/42
```

```json
{"action":"update product 42"}
```

```bash
curl -X DELETE http://localhost:7147/products/42
```

```json
{"action":"delete product 42"}
```

`GET` reads. `POST` creates. `PUT` replaces. `PATCH` patches. `DELETE` removes. REST convention. Predictable API.

---

## 3. Path Parameters

Path parameters capture values from the URL. Wrap the name in curly braces:

```ruby
Tina4::Router.get("/users/{id}/posts/{post_id}") do |request, response|
  user_id = request.params[:id]
  post_id = request.params[:post_id]

  response.json({
    user_id: user_id,
    post_id: post_id
  })
end
```

```bash
curl http://localhost:7147/users/5/posts/99
```

```json
{"user_id":"5","post_id":"99"}
```

Notice: `user_id` came back as the string `"5"`, not the integer `5`. Path parameters are strings by default.

> **Auto-casting:** Tina4 automatically casts path parameter values that are purely numeric to integers. For example, requesting `/users/42/posts/99` will give you `request.params[:id]` as the integer `42` and `request.params[:post_id]` as the integer `99` -- no explicit `:int` type hint required. The `:int` type hint adds validation (rejecting non-numeric values with a 404), but the auto-casting happens regardless.

### Typed Parameters

Enforce a type with a colon after the parameter name:

```ruby
Tina4::Router.get("/orders/{id:int}") do |request, response|
  id = request.params[:id]
  response.json({
    order_id: id,
    type: id.class.name
  })
end
```

```bash
curl http://localhost:7147/orders/42
```

```json
{"order_id":42,"type":"Integer"}
```

Pass a non-integer? The route refuses to match. You get a 404:

```bash
curl http://localhost:7147/orders/abc
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

```ruby
# Integer parameter -- only digits match, auto-cast to Integer
Tina4::Router.get("/products/{id:int}") do |request, response|
  id = request.params[:id] # Integer, e.g. 42
  response.json({
    product_id: id,
    type: id.class.name
  })
end

# Float parameter -- decimal numbers, auto-cast to Float
Tina4::Router.get("/products/{id:int}/price/{price:float}") do |request, response|
  id = request.params[:id]
  price = request.params[:price]
  response.json({
    product_id: id,
    price: price,
    type: price.class.name
  })
end

# Path parameter -- catch-all, captures remaining segments as a string
Tina4::Router.get("/files/{filepath:path}") do |request, response|
  filepath = request.params[:filepath]
  # filepath could be "images/photos/cat.jpg"
  response.json({
    filepath: filepath,
    type: filepath.class.name
  })
end
```

```bash
# Integer route -- matches digits, returns an Integer
curl http://localhost:7147/products/42
```

```json
{"product_id":42,"type":"Integer"}
```

```bash
# Integer route -- non-integer gives a 404
curl http://localhost:7147/products/abc
```

```json
{"error":"Not found","path":"/products/abc","status":404}
```

```bash
# Path catch-all -- captures everything after /files/
curl http://localhost:7147/files/images/photos/cat.jpg
```

```json
{"filepath":"images/photos/cat.jpg","type":"String"}
```

The `:int` and `:float` types act as both a constraint and a converter. If the URL segment does not match the expected pattern, the route is skipped entirely and Tina4 moves on to the next registered route (or returns 404 if nothing matches). The `:path` type is greedy -- it consumes all remaining segments, making it ideal for file paths and documentation URLs.

---

## 4. Query Parameters

Query parameters are key-value pairs after the `?` in a URL. Access them through `request.params`:

```ruby
Tina4::Router.get("/search") do |request, response|
  q = request.params["q"] || ""
  page = (request.params["page"] || 1).to_i
  limit = (request.params["limit"] || 10).to_i

  response.json({
    query: q,
    page: page,
    limit: limit,
    offset: (page - 1) * limit
  })
end
```

```bash
curl "http://localhost:7147/search?q=keyboard&page=2&limit=20"
```

```json
{"query":"keyboard","page":2,"limit":20,"offset":20}
```

Missing query parameter? `request.params["key"]` returns `nil`. Use `||` to provide defaults.

---

## 5. Route Groups

A set of routes shares a common prefix. `Tina4::Router.group` eliminates repetition:

```ruby
Tina4::Router.group("/api/v1") do

  Tina4::Router.get("/users") do |request, response|
    response.json({ users: [] })
  end

  Tina4::Router.get("/users/{id:int}") do |request, response|
    id = request.params[:id]
    response.json({ user: { id: id, name: "Alice" } })
  end

  Tina4::Router.post("/users") do |request, response|
    response.json({ created: true }, 201)
  end

  Tina4::Router.get("/products") do |request, response|
    response.json({ products: [] })
  end

end
```

These routes register as `/api/v1/users`, `/api/v1/users/{id}`, and `/api/v1/products`. Short paths inside the group. Tina4 prepends the prefix.

```bash
curl http://localhost:7147/api/v1/users
```

```json
{"users":[]}
```

```bash
curl http://localhost:7147/api/v1/products
```

```json
{"products":[]}
```

Groups nest:

```ruby
Tina4::Router.group("/api") do
  Tina4::Router.group("/v1") do
    Tina4::Router.get("/status") do |request, response|
      response.json({ version: "1.0" })
    end
  end

  Tina4::Router.group("/v2") do
    Tina4::Router.get("/status") do |request, response|
      response.json({ version: "2.0" })
    end
  end
end
```

```bash
curl http://localhost:7147/api/v1/status
```

```json
{"version":"1.0"}
```

```bash
curl http://localhost:7147/api/v2/status
```

```json
{"version":"2.0"}
```

---

## 6. Middleware

Middleware is code that runs before or after your route handler. Authentication. Logging. Rate limiting. Input validation. Anything that belongs on multiple routes but not in every handler.

### Middleware on a Single Route

Pass middleware as the third argument:

```ruby
log_request = lambda do |request, response, next_handler|
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  $stderr.puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{request.method} #{request.path}"

  result = next_handler.call(request, response)

  duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  $stderr.puts "  Completed in #{duration}ms"

  result
end

Tina4::Router.get("/api/data", middleware: "log_request") do |request, response|
  response.json({ data: [1, 2, 3] })
end
```

The middleware receives `request`, `response`, and `next_handler`. Call `next_handler.call(request, response)` to proceed to the route handler. Skip the call and the handler never runs -- a gatekeeper that blocks unauthorized requests.

### Blocking Middleware

Middleware that checks for an API key:

```ruby
require_api_key = lambda do |request, response, next_handler|
  api_key = request.headers["X-API-Key"] || ""

  if api_key != "my-secret-key"
    return response.json({ error: "Invalid API key" }, 401)
  end

  next_handler.call(request, response)
end

Tina4::Router.get("/api/secret", middleware: "require_api_key") do |request, response|
  response.json({ secret: "The answer is 42" })
end
```

```bash
curl http://localhost:7147/api/secret
```

```json
{"error":"Invalid API key"}
```

Status: `401 Unauthorized`.

```bash
curl http://localhost:7147/api/secret -H "X-API-Key: my-secret-key"
```

```json
{"secret":"The answer is 42"}
```

### Middleware on a Group

Apply middleware to every route inside a group:

```ruby
Tina4::Router.group("/api/admin", middleware: "require_auth") do

  Tina4::Router.get("/dashboard") do |request, response|
    response.json({ page: "admin dashboard" })
  end

  Tina4::Router.get("/users") do |request, response|
    response.json({ page: "user management" })
  end

end
```

Every route in the group now demands the `Authorization` header. No per-route repetition.

### Multiple Middleware

Chain them with an array:

```ruby
Tina4::Router.get("/api/important", middleware: ["log_request", "require_api_key", "require_auth"]) do |request, response|
  response.json({ data: "important stuff" })
end
```

Middleware runs in order: `log_request` first, then `require_api_key`, then `require_auth`, then the route handler. If any middleware skips `next_handler`, the chain stops there.

---

## 7. Route Decorators: @noauth and @secured

Tina4 provides two decorators for controlling authentication at the route level.

### @noauth -- Public Routes

When your application has global authentication middleware, `@noauth` marks specific routes as public:

```ruby
# @noauth
Tina4::Router.get("/api/public/info") do |request, response|
  response.json({
    app: "My Store",
    version: "1.0.0"
  })
end
```

The `@noauth` comment tells Tina4 to skip authentication for this route, even if global auth middleware guards the parent group.

### @secured -- Protected GET Routes

`@secured` marks a GET route as requiring authentication:

```ruby
# @secured
Tina4::Router.get("/api/profile") do |request, response|
  # request.user is populated by the auth middleware
  response.json({ user: request.user })
end
```

By default, `POST`, `PUT`, `PATCH`, and `DELETE` routes are secured. `GET` routes are public unless you add `@secured`. Reading is open. Writing demands credentials.

---

## 8. Route Chaining: .secure and .cache

Routes return a chainable object. Two methods you can call on any route: `.secure` and `.cache`.

### .secure

`.secure` requires a valid bearer token in the `Authorization` header. If the token is missing or invalid, the route returns `401 Unauthorized` without ever reaching your handler:

```ruby
Tina4::Router.get("/api/account") do |request, response|
  response.json({ account: request.user })
end.secure
```

```bash
curl http://localhost:7147/api/account
# 401 Unauthorized

curl http://localhost:7147/api/account -H "Authorization: Bearer eyJhbGci..."
# 200 OK
```

### .cache

`.cache` enables response caching for the route. Once the handler runs and produces a response, subsequent requests to the same URL return the cached result without re-executing the handler:

```ruby
Tina4::Router.get("/api/catalog") do |request, response|
  # Expensive database query
  response.json({ products: products })
end.cache
```

### Chaining Both

Chain `.secure` and `.cache` together:

```ruby
Tina4::Router.get("/api/data") do |request, response|
  response.json({ data: data })
end.secure.cache
```

This route requires a bearer token and caches the response. Order does not matter -- `.cache.secure` produces the same result.

---

## 9. Wildcard and Catch-All Routes

### Wildcard Routes

Use `*` at the end of a path to match everything after it:

```ruby
Tina4::Router.get("/docs/*") do |request, response|
  path = request.params["*"] || ""
  response.json({
    section: "docs",
    path: path
  })
end
```

```bash
curl http://localhost:7147/docs/getting-started
```

```json
{"section":"docs","path":"getting-started"}
```

```bash
curl http://localhost:7147/docs/api/authentication/jwt
```

```json
{"section":"docs","path":"api/authentication/jwt"}
```

### Catch-All Route (Custom 404)

Handle any unmatched URL:

```ruby
Tina4::Router.get("/*") do |request, response|
  response.json({
    error: "Page not found",
    path: request.path
  }, 404)
end
```

Define this route last (or in a file that sorts alphabetically after your other route files). Tina4 matches routes in registration order. First match wins.

Or create a custom 404 page at `src/templates/errors/404.html`:

```html
{% extends "base.html" %}

{% block title %}Not Found{% endblock %}

{% block content %}
    <h1>404 - Page Not Found</h1>
    <p>The page you are looking for does not exist.</p>
    <a href="/">Go back home</a>
{% endblock %}
```

Tina4 uses this template for unmatched routes when the file exists.

---

## 10. Route Listing via CLI

As your application grows, you need to see all registered routes at a glance:

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
GET      /api/admin/dashboard          require_auth        public
GET      /api/admin/users              require_auth        public
GET      /api/public/info              -                   @noauth
GET      /api/profile                  -                   @secured
GET      /search                       -                   public
GET      /docs/*                       -                   public
```

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
GET      /api/admin/users              require_auth        public
```

---

## 11. Organizing Route Files

Organize route files however you want. Tina4 loads every `.rb` file in `src/routes/` recursively. Two common patterns:

### Pattern 1: One File Per Resource

```
src/routes/
├── products.rb     # All product routes
├── users.rb        # All user routes
├── orders.rb       # All order routes
└── pages.rb        # HTML page routes
```

### Pattern 2: Subdirectories by Feature

```
src/routes/
├── api/
│   ├── products.rb
│   ├── users.rb
│   └── orders.rb
├── admin/
│   ├── dashboard.rb
│   └── settings.rb
└── pages/
    ├── home.rb
    └── about.rb
```

Both work the same. The directory structure has no effect on URL paths -- only the route definitions inside the files matter. Pick whichever pattern keeps your project navigable.

---

## 12. Exercise: Build a Full CRUD API for Products

Build a complete REST API for managing products. Data lives in a Ruby array (no database yet -- Chapter 5 handles that).

### Requirements

Create `src/routes/product_api.rb` with these routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List all products. Support `?category=` filter. |
| `GET` | `/api/products/{id:int}` | Get a single product by ID. Return 404 if not found. |
| `POST` | `/api/products` | Create a new product. Return 201. |
| `PUT` | `/api/products/{id:int}` | Replace a product. Return 404 if not found. |
| `DELETE` | `/api/products/{id:int}` | Delete a product. Return 204 with no body. |

Each product has: `id` (int), `name` (string), `category` (string), `price` (float), `in_stock` (bool).

Seed data:

```ruby
products = [
  { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99, in_stock: true },
  { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99, in_stock: true },
  { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99, in_stock: false },
  { id: 4, name: "Standing Desk", category: "Office", price: 549.99, in_stock: true },
  { id: 5, name: "Running Shoes", category: "Fitness", price: 119.99, in_stock: true }
]
```

Test with:

```bash
# List all
curl http://localhost:7147/api/products

# Filter by category
curl "http://localhost:7147/api/products?category=Fitness"

# Get one
curl http://localhost:7147/api/products/3

# Create
curl -X POST http://localhost:7147/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Desk Lamp", "category": "Office", "price": 39.99, "in_stock": true}'

# Update
curl -X PUT http://localhost:7147/api/products/3 \
  -H "Content-Type: application/json" \
  -d '{"name": "Burr Coffee Grinder", "category": "Kitchen", "price": 59.99, "in_stock": true}'

# Delete
curl -X DELETE http://localhost:7147/api/products/3

# Not found
curl http://localhost:7147/api/products/999
```

---

## 13. Solution

Create `src/routes/product_api.rb`:

```ruby
# In-memory product store (resets on server restart)
$products = [
  { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99, in_stock: true },
  { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99, in_stock: true },
  { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99, in_stock: false },
  { id: 4, name: "Standing Desk", category: "Office", price: 549.99, in_stock: true },
  { id: 5, name: "Running Shoes", category: "Fitness", price: 119.99, in_stock: true }
]

$next_id = 6

# List all products, optionally filter by category
Tina4::Router.get("/api/products") do |request, response|
  category = request.params["category"]

  if category
    filtered = $products.select { |p| p[:category].downcase == category.downcase }
    response.json({ products: filtered, count: filtered.length })
  else
    response.json({ products: $products, count: $products.length })
  end
end

# Get a single product by ID
Tina4::Router.get("/api/products/{id:int}") do |request, response|
  id = request.params[:id]

  product = $products.find { |p| p[:id] == id }

  if product
    response.json(product)
  else
    response.json({ error: "Product not found", id: id }, 404)
  end
end

# Create a new product
Tina4::Router.post("/api/products") do |request, response|
  body = request.body

  if body["name"].nil? || body["name"].empty?
    return response.json({ error: "Name is required" }, 400)
  end

  product = {
    id: $next_id,
    name: body["name"],
    category: body["category"] || "Uncategorized",
    price: (body["price"] || 0).to_f,
    in_stock: body["in_stock"] != false
  }

  $next_id += 1
  $products << product

  response.json(product, 201)
end

# Replace a product
Tina4::Router.put("/api/products/{id:int}") do |request, response|
  id = request.params[:id]
  body = request.body

  index = $products.index { |p| p[:id] == id }

  if index.nil?
    response.json({ error: "Product not found", id: id }, 404)
  else
    $products[index] = {
      id: id,
      name: body["name"] || $products[index][:name],
      category: body["category"] || $products[index][:category],
      price: (body["price"] || $products[index][:price]).to_f,
      in_stock: body.key?("in_stock") ? body["in_stock"] : $products[index][:in_stock]
    }
    response.json($products[index])
  end
end

# Delete a product
Tina4::Router.delete("/api/products/{id:int}") do |request, response|
  id = request.params[:id]

  index = $products.index { |p| p[:id] == id }

  if index.nil?
    response.json({ error: "Product not found", id: id }, 404)
  else
    $products.delete_at(index)
    response.json(nil, 204)
  end
end
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

### 1. Trailing Slashes Matter

**Problem:** `/products` works but `/products/` returns 404.

**Cause:** Tina4 treats `/products` and `/products/` as different routes by default.

**Fix:** Pick one convention. Stick with it. Set `TINA4_TRAILING_SLASH_REDIRECT=true` in `.env` and Tina4 redirects `/products/` to `/products`.

### 2. Parameter Names Must Be Unique in a Path

**Problem:** `/users/{id}/posts/{id}` behaves wrong -- both parameters share the same name.

**Cause:** The second `{id}` overwrites the first in `request.params`.

**Fix:** Use distinct names: `/users/{user_id}/posts/{post_id}`.

### 3. Method Conflicts

**Problem:** You defined `Tina4::Router.get("/items/{id}", ...)` and `Tina4::Router.get("/items/{action}", ...)` and the wrong handler runs.

**Cause:** Both patterns match `/items/42`. First registered wins.

**Fix:** Use typed parameters: `Tina4::Router.get("/items/{id:int}", ...)` matches integers only, leaving `/items/export` free. Or restructure: `/items/{id:int}` and `/items/actions/{action}`.

### 4. Route Handler Must Return a Response

**Problem:** Handler runs but the browser shows an empty page or 500 error.

**Cause:** No call to `response.json`, `response.render`, or another response method. Without a return value from the response object, Tina4 has nothing to send.

**Fix:** Every handler must end with `response.json(...)`, `response.html(...)`, or `response.render(...)`.

### 5. Block Syntax Matters

**Problem:** Route handler raises a syntax error about unexpected blocks.

**Cause:** Ruby blocks with `do...end` and `{...}` have different precedence.

**Fix:** Use `do |request, response| ... end` for route blocks. The curly brace form works for single-line handlers but causes parsing issues with method arguments.

### 6. Middleware Must Be a Named Function or String

**Problem:** Passing an inline lambda as middleware causes unexpected behavior.

**Cause:** Tina4 expects middleware referenced by name (a string), resolved at runtime.

**Fix:** Define middleware as a named method or lambda. Pass the name as a string: `"my_middleware"`.

### 7. Group Prefix Must Start with a Slash

**Problem:** `Tina4::Router.group("api/v1")` produces routes that do not match.

**Cause:** The group prefix needs a leading `/`.

**Fix:** Start group prefixes with `/`: `Tina4::Router.group("/api/v1")`.
