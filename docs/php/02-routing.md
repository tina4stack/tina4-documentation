# Chapter 2: Routing

## 1. How Routing Works in Tina4

A URL arrives. The framework finds the function that handles it. The function runs. The result goes back. That mapping -- URL to code -- is routing.

In Tina4, routes live in PHP files inside `src/routes/`. Every `.php` file in that directory (and its subdirectories) is auto-loaded at startup. No registration file. No central config. Drop a file in. It works.

The simplest possible route:

```php
<?php
use Tina4Router;

Router::get("/hello", function ($request, $response) {
    return $response->json(["message" => "Hello, World!"]);
});
```

Save that as `src/routes/hello.php`. Start the server. Visit `http://localhost:7146/hello`:

```json
{"message":"Hello, World!"}
```

One line registers the route. One line handles the request.

---

## 2. HTTP Methods

Five methods. Five static calls on the `Route` class.

```php
<?php
use Tina4Router;

Router::get("/products", function ($request, $response) {
    return $response->json(["action" => "list all products"]);
});

Router::post("/products", function ($request, $response) {
    return $response->json(["action" => "create a product"], 201);
});

Router::put("/products/{id}", function ($request, $response) {
    $id = $request->params["id"];
    return $response->json(["action" => "replace product " . $id]);
});

Router::patch("/products/{id}", function ($request, $response) {
    $id = $request->params["id"];
    return $response->json(["action" => "update product " . $id]);
});

Router::delete("/products/{id}", function ($request, $response) {
    $id = $request->params["id"];
    return $response->json(["action" => "delete product " . $id]);
});
```

Test each one:

```bash
curl http://localhost:7146/products
```

```json
{"action":"list all products"}
```

```bash
curl -X POST http://localhost:7146/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Widget"}'
```

```json
{"action":"create a product"}
```

```bash
curl -X PUT http://localhost:7146/products/42
```

```json
{"action":"replace product 42"}
```

```bash
curl -X PATCH http://localhost:7146/products/42
```

```json
{"action":"update product 42"}
```

```bash
curl -X DELETE http://localhost:7146/products/42
```

```json
{"action":"delete product 42"}
```

`GET` reads. `POST` creates. `PUT` replaces. `PATCH` patches. `DELETE` removes. REST convention. Predictable API.

---

## 3. Path Parameters

Curly braces capture values from the URL.

```php
<?php
use Tina4Router;

Router::get("/users/{id}/posts/{postId}", function ($request, $response) {
    $userId = $request->params["id"];
    $postId = $request->params["postId"];

    return $response->json([
        "user_id" => $userId,
        "post_id" => $postId
    ]);
});
```

```bash
curl http://localhost:7146/users/5/posts/99
```

```json
{"user_id":"5","post_id":"99"}
```

Notice: `user_id` came back as the string `"5"`, not the integer `5`. Path parameters are strings by default.

### Typed Parameters

Add a colon and a type to enforce constraints:

```php
<?php
use Tina4Router;

Router::get("/orders/{id:int}", function ($request, $response) {
    $id = $request->params["id"]; // This is now an integer
    return $response->json([
        "order_id" => $id,
        "type" => gettype($id)
    ]);
});
```

```bash
curl http://localhost:7146/orders/42
```

```json
{"order_id":42,"type":"integer"}
```

Pass a non-integer and the route does not match. A 404 comes back instead:

```bash
curl http://localhost:7146/orders/abc
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
| `alpha` | Letters only | String | `{slug:alpha}` matches `hello` but not `hello123` |
| `alphanumeric` | Letters and digits | String | `{code:alphanumeric}` matches `abc123` |

The `{name}` form (no type) matches any single path segment and returns it as a string.

### Typed Parameters in Action

Here is a complete example showing the most commonly used typed parameters together:

```php
<?php
use Tina4Router;

// Integer parameter -- only digits match, auto-cast to integer
Router::get("/products/{id:int}", function ($request, $response) {
    $id = $request->params["id"]; // integer, e.g. 42
    return $response->json([
        "product_id" => $id,
        "type" => gettype($id)
    ]);
});

// Float parameter -- decimal numbers, auto-cast to float
Router::get("/products/{id:int}/price/{price:float}", function ($request, $response) {
    $id = $request->params["id"];
    $price = $request->params["price"];
    return $response->json([
        "product_id" => $id,
        "price" => $price,
        "type" => gettype($price)
    ]);
});

// Path parameter -- catch-all, captures remaining segments as a string
Router::get("/files/{filepath:path}", function ($request, $response) {
    $filepath = $request->params["filepath"];
    // filepath could be "images/photos/cat.jpg"
    return $response->json([
        "filepath" => $filepath,
        "type" => gettype($filepath)
    ]);
});
```

```bash
# Integer route -- matches digits, returns an integer
curl http://localhost:7146/products/42
```

```json
{"product_id":42,"type":"integer"}
```

```bash
# Integer route -- non-integer gives a 404
curl http://localhost:7146/products/abc
```

```json
{"error":"Not found","path":"/products/abc","status":404}
```

```bash
# Path catch-all -- captures everything after /files/
curl http://localhost:7146/files/images/photos/cat.jpg
```

```json
{"filepath":"images/photos/cat.jpg","type":"string"}
```

The `:int` and `:float` types act as both a constraint and a converter. If the URL segment does not match the expected pattern, the route is skipped entirely and Tina4 moves on to the next registered route (or returns 404 if nothing matches). The `:path` type is greedy -- it consumes all remaining segments, making it ideal for file paths and documentation URLs.

---

## 4. Query Parameters

Key-value pairs after the `?` in a URL. Access them through `$request->query`:

```php
<?php
use Tina4Router;

Router::get("/search", function ($request, $response) {
    $q = $request->query["q"] ?? "";
    $page = (int) ($request->query["page"] ?? 1);
    $limit = (int) ($request->query["limit"] ?? 10);

    return $response->json([
        "query" => $q,
        "page" => $page,
        "limit" => $limit,
        "offset" => ($page - 1) * $limit
    ]);
});
```

```bash
curl "http://localhost:7146/search?q=keyboard&page=2&limit=20"
```

```json
{"query":"keyboard","page":2,"limit":20,"offset":20}
```

Missing query parameters do not exist in the array. Always use the null coalescing operator (`??`) for defaults.

---

## 5. Route Groups

Shared prefix. No repetition.

```php
<?php
use Tina4Router;

Router::group("/api/v1", function () {

    Router::get("/users", function ($request, $response) {
        return $response->json(["users" => []]);
    });

    Router::get("/users/{id:int}", function ($request, $response) {
        $id = $request->params["id"];
        return $response->json(["user" => ["id" => $id, "name" => "Alice"]]);
    });

    Router::post("/users", function ($request, $response) {
        return $response->json(["created" => true], 201);
    });

    Router::get("/products", function ($request, $response) {
        return $response->json(["products" => []]);
    });
});
```

These register as `/api/v1/users`, `/api/v1/users/{id}`, and `/api/v1/products`. Short paths inside the group. Tina4 prepends the prefix.

```bash
curl http://localhost:7146/api/v1/users
```

```json
{"users":[]}
```

```bash
curl http://localhost:7146/api/v1/products
```

```json
{"products":[]}
```

Groups nest:

```php
<?php
use Tina4Router;

Router::group("/api", function () {
    Router::group("/v1", function () {
        Router::get("/status", function ($request, $response) {
            return $response->json(["version" => "1.0"]);
        });
    });

    Router::group("/v2", function () {
        Router::get("/status", function ($request, $response) {
            return $response->json(["version" => "2.0"]);
        });
    });
});
```

```bash
curl http://localhost:7146/api/v1/status
```

```json
{"version":"1.0"}
```

```bash
curl http://localhost:7146/api/v2/status
```

```json
{"version":"2.0"}
```

---

## 6. Middleware

Code that runs before or after your handler. Authentication, logging, rate limiting, input validation -- anything that should apply to multiple routes without polluting each handler.

### Middleware on a Single Route

Pass the middleware name as the third argument:

```php
<?php
use Tina4Router;

function logRequest($request, $response, $next) {
    $start = microtime(true);
    error_log("[" . date("Y-m-d H:i:s") . "] " . $request->method . " " . $request->path);

    $result = $next($request, $response);

    $duration = round((microtime(true) - $start) * 1000, 2);
    error_log("  Completed in " . $duration . "ms");

    return $result;
}

Router::get("/api/data", function ($request, $response) {
    return $response->json(["data" => [1, 2, 3]]);
}, "logRequest");
```

The middleware receives `$request`, `$response`, and `$next`. Call `$next($request, $response)` to continue to the handler. Skip the call and the handler never runs -- the chain stops cold.

### Blocking Middleware

A gate that checks for an API key:

```php
<?php
use Tina4Router;

function requireApiKey($request, $response, $next) {
    $apiKey = $request->headers["X-API-Key"] ?? "";

    if ($apiKey !== "my-secret-key") {
        return $response->json(["error" => "Invalid API key"], 401);
    }

    return $next($request, $response);
}

Router::get("/api/secret", function ($request, $response) {
    return $response->json(["secret" => "The answer is 42"]);
}, "requireApiKey");
```

```bash
curl http://localhost:7146/api/secret
```

```json
{"error":"Invalid API key"}
```

Status: `401 Unauthorized`.

```bash
curl http://localhost:7146/api/secret -H "X-API-Key: my-secret-key"
```

```json
{"secret":"The answer is 42"}
```

### Middleware on a Group

Third argument to `Router::group()`. Every route inside inherits it.

```php
<?php
use Tina4Router;

function requireAuth($request, $response, $next) {
    $token = $request->headers["Authorization"] ?? "";

    if (empty($token)) {
        return $response->json(["error" => "Authentication required"], 401);
    }

    return $next($request, $response);
}

Router::group("/api/admin", function () {

    Router::get("/dashboard", function ($request, $response) {
        return $response->json(["page" => "admin dashboard"]);
    });

    Router::get("/users", function ($request, $response) {
        return $response->json(["page" => "user management"]);
    });

}, "requireAuth");
```

No per-route repetition. The group handles it.

### Multiple Middleware

Pass an array. They run in order.

```php
Router::get("/api/important", function ($request, $response) {
    return $response->json(["data" => "important stuff"]);
}, ["logRequest", "requireApiKey", "requireAuth"]);
```

`logRequest` first, then `requireApiKey`, then `requireAuth`, then the handler. If any middleware skips `$next`, the chain stops there.

---

## 7. Route Decorators: @noauth and @secured

Two annotations for controlling authentication at the route level.

### @noauth -- Public Routes

When your application has global authentication, `@noauth` exempts specific routes:

```php
<?php
use Tina4Router;

/**
 * @noauth
 */
Router::get("/api/public/info", function ($request, $response) {
    return $response->json([
        "app" => "My Store",
        "version" => "1.0.0"
    ]);
});
```

The `@noauth` decorator tells Tina4 to skip authentication for this route, even if global auth middleware is configured.

### @secured -- Protected GET Routes

`@secured` marks a GET route as requiring authentication:

```php
<?php
use Tina4Router;

/**
 * @secured
 */
Router::get("/api/profile", function ($request, $response) {
    // $request->user is populated by the auth middleware
    return $response->json([
        "user" => $request->user
    ]);
});
```

The convention: `POST`, `PUT`, `PATCH`, and `DELETE` routes are secured by default. `GET` routes are public unless you add `@secured`. Reading is open. Writing requires proof.

---

## 8. Route Chaining: secure() and cache()

Routes return a chainable object. Two methods you can call on any route: `secure()` and `cache()`.

### secure()

`secure()` requires a valid bearer token in the `Authorization` header. If the token is missing or invalid, the route returns `401 Unauthorized` without ever reaching your handler:

```php
Router::get("/api/account", function ($request, $response) {
    return $response->json(["account" => $request->user]);
})->secure();
```

```bash
curl http://localhost:7146/api/account
# 401 Unauthorized

curl http://localhost:7146/api/account -H "Authorization: Bearer eyJhbGci..."
# 200 OK
```

This is a lighter alternative to `@secured` -- it works inline without a docblock annotation.

### cache()

`cache()` enables response caching for the route. Once the handler runs and produces a response, subsequent requests to the same URL return the cached result without re-executing the handler:

```php
Router::get("/api/catalog", function ($request, $response) {
    // Expensive database query
    return $response->json(["products" => $products]);
})->cache();
```

### Chaining Both

Chain `secure()` and `cache()` together on the same route:

```php
Router::get("/api/data", function ($request, $response) {
    return $response->json(["data" => $data]);
})->secure()->cache();
```

This route requires a bearer token and caches the response. Order does not matter -- `->cache()->secure()` produces the same result.

---

## 9. Wildcard and Catch-All Routes

### Wildcard Routes

Use `{name:path}` at the end of a path to capture everything after it:

```php
<?php
use Tina4\Router;

Router::get("/docs/{path:path}", function ($request, $response) {
    return $response->json([
        "section" => "docs",
        "path" => $request->params["path"]
    ]);
});
```

```bash
curl http://localhost:7146/docs/getting-started
```

```json
{"section":"docs","path":"getting-started"}
```

```bash
curl http://localhost:7146/docs/api/authentication/jwt
```

```json
{"section":"docs","path":"api/authentication/jwt"}
```

### Catch-All Route (Custom 404)

Handle any unmatched URL:

```php
<?php
use Tina4\Router;

Router::get("/{path:path}", function ($request, $response) {
    return $response->json([
        "error" => "Page not found",
        "path" => $request->params["path"]
    ], 404);
});
```

Define this last. Tina4 matches routes in registration order -- first match wins. Place this in a file that sorts alphabetically after your other route files, or it will shadow everything.

You can also create a custom 404 template at `src/templates/errors/404.twig`:

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

Your application grows. You need a map. The CLI provides one.

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
GET      /api/admin/dashboard          requireAuth         public
GET      /api/admin/users              requireAuth         public
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
GET      /api/admin/users              requireAuth         public
```

---

## 11. Organizing Route Files

Tina4 loads every `.php` file in `src/routes/` recursively. The directory structure is yours to organize. Two common patterns:

### Pattern 1: One File Per Resource

```
src/routes/
├── products.php     # All product routes
├── users.php        # All user routes
├── orders.php       # All order routes
└── pages.php        # HTML page routes
```

### Pattern 2: Subdirectories by Feature

```
src/routes/
├── api/
│   ├── products.php
│   ├── users.php
│   └── orders.php
├── admin/
│   ├── dashboard.php
│   └── settings.php
└── pages/
    ├── home.php
    └── about.php
```

Both work identically. The directory structure has no effect on URL paths -- only the route definitions inside the files matter. Pick whichever pattern keeps your project navigable.

---

## 12. Exercise: Build a Full CRUD API for Products

Build a REST API for managing products. All data stored in a PHP array. No database yet -- Chapter 5 handles that.

### Requirements

Create `src/routes/product-api.php` with these routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List all products. Support `?category=` filter. |
| `GET` | `/api/products/{id:int}` | Get a single product by ID. Return 404 if not found. |
| `POST` | `/api/products` | Create a new product. Return 201. |
| `PUT` | `/api/products/{id:int}` | Replace a product. Return 404 if not found. |
| `DELETE` | `/api/products/{id:int}` | Delete a product. Return 204 with no body. |

Each product: `id` (int), `name` (string), `category` (string), `price` (float), `in_stock` (bool).

Seed data:

```php
$products = [
    ["id" => 1, "name" => "Wireless Keyboard", "category" => "Electronics", "price" => 79.99, "in_stock" => true],
    ["id" => 2, "name" => "Yoga Mat", "category" => "Fitness", "price" => 29.99, "in_stock" => true],
    ["id" => 3, "name" => "Coffee Grinder", "category" => "Kitchen", "price" => 49.99, "in_stock" => false],
    ["id" => 4, "name" => "Standing Desk", "category" => "Office", "price" => 549.99, "in_stock" => true],
    ["id" => 5, "name" => "Running Shoes", "category" => "Fitness", "price" => 119.99, "in_stock" => true]
];
```

Test with:

```bash
# List all
curl http://localhost:7146/api/products

# Filter by category
curl "http://localhost:7146/api/products?category=Fitness"

# Get one
curl http://localhost:7146/api/products/3

# Create
curl -X POST http://localhost:7146/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Desk Lamp", "category": "Office", "price": 39.99, "in_stock": true}'

# Update
curl -X PUT http://localhost:7146/api/products/3 \
  -H "Content-Type: application/json" \
  -d '{"name": "Burr Coffee Grinder", "category": "Kitchen", "price": 59.99, "in_stock": true}'

# Delete
curl -X DELETE http://localhost:7146/api/products/3

# Not found
curl http://localhost:7146/api/products/999
```

---

## 13. Solution

Create `src/routes/product-api.php`:

```php
<?php
use Tina4Router;

// In-memory product store (resets on server restart)
$products = [
    ["id" => 1, "name" => "Wireless Keyboard", "category" => "Electronics", "price" => 79.99, "in_stock" => true],
    ["id" => 2, "name" => "Yoga Mat", "category" => "Fitness", "price" => 29.99, "in_stock" => true],
    ["id" => 3, "name" => "Coffee Grinder", "category" => "Kitchen", "price" => 49.99, "in_stock" => false],
    ["id" => 4, "name" => "Standing Desk", "category" => "Office", "price" => 549.99, "in_stock" => true],
    ["id" => 5, "name" => "Running Shoes", "category" => "Fitness", "price" => 119.99, "in_stock" => true]
];

$nextId = 6;

// List all products, optionally filter by category
Router::get("/api/products", function ($request, $response) use (&$products) {
    $category = $request->query["category"] ?? null;

    if ($category !== null) {
        $filtered = array_values(array_filter(
            $products,
            fn($p) => strtolower($p["category"]) === strtolower($category)
        ));
        return $response->json(["products" => $filtered, "count" => count($filtered)]);
    }

    return $response->json(["products" => $products, "count" => count($products)]);
});

// Get a single product by ID
Router::get("/api/products/{id:int}", function ($request, $response) use (&$products) {
    $id = $request->params["id"];

    foreach ($products as $product) {
        if ($product["id"] === $id) {
            return $response->json($product);
        }
    }

    return $response->json(["error" => "Product not found", "id" => $id], 404);
});

// Create a new product
Router::post("/api/products", function ($request, $response) use (&$products, &$nextId) {
    $body = $request->body;

    if (empty($body["name"])) {
        return $response->json(["error" => "Name is required"], 400);
    }

    $product = [
        "id" => $nextId++,
        "name" => $body["name"],
        "category" => $body["category"] ?? "Uncategorized",
        "price" => (float) ($body["price"] ?? 0),
        "in_stock" => (bool) ($body["in_stock"] ?? true)
    ];

    $products[] = $product;

    return $response->json($product, 201);
});

// Replace a product
Router::put("/api/products/{id:int}", function ($request, $response) use (&$products) {
    $id = $request->params["id"];
    $body = $request->body;

    foreach ($products as $index => $product) {
        if ($product["id"] === $id) {
            $products[$index] = [
                "id" => $id,
                "name" => $body["name"] ?? $product["name"],
                "category" => $body["category"] ?? $product["category"],
                "price" => (float) ($body["price"] ?? $product["price"]),
                "in_stock" => (bool) ($body["in_stock"] ?? $product["in_stock"])
            ];
            return $response->json($products[$index]);
        }
    }

    return $response->json(["error" => "Product not found", "id" => $id], 404);
});

// Delete a product
Router::delete("/api/products/{id:int}", function ($request, $response) use (&$products) {
    $id = $request->params["id"];

    foreach ($products as $index => $product) {
        if ($product["id"] === $id) {
            array_splice($products, $index, 1);
            return $response->json(null, 204);
        }
    }

    return $response->json(["error" => "Product not found", "id" => $id], 404);
});
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

### 1. Trailing Slashes Are Normalised

Tina4 strips trailing slashes automatically. Both `/products` and `/products/` match the same route. You do not need to register both or configure anything — it just works.

### 2. Parameter Names Must Be Unique in a Path

**Problem:** `/users/{id}/posts/{id}` produces wrong results -- the second `{id}` overwrites the first.

**Fix:** Use distinct names: `/users/{userId}/posts/{postId}`.

### 3. Method Conflicts

**Problem:** `Router::get("/items/{id}", ...)` and `Router::get("/items/{action}", ...)` collide. The wrong handler runs.

**Cause:** Both patterns match `/items/42`. First registration wins.

**Fix:** Use typed parameters to disambiguate: `Router::get("/items/{id:int}", ...)` matches only integers, leaving `/items/export` free. Or restructure: `/items/{id:int}` and `/items/actions/{action}`.

### 4. Route Handler Must Return a Response

**Problem:** The handler runs but the browser shows empty or 500.

**Cause:** No `return` statement. Without `return`, the handler returns `null`. Tina4 has nothing to send.

**Fix:** Every handler must return something. `return $response->json(...)`, `return $response->html(...)`, `return $response->render(...)`.

### 5. Route Files Must Start with `<?php`

**Problem:** Route file is ignored. No errors. No routes registered.

**Cause:** Missing PHP opening tag. Without `<?php`, the file is not parsed.

**Fix:** First line of every route file: `<?php`.

### 6. Middleware Uses Class-Based Pattern

**Problem:** Passing a function name string as middleware doesn't work.

**Fix:** Use class-based middleware with `before*`/`after*` static methods. See Chapter 8 for the full middleware pattern:

```php
class AuthMiddleware {
    public static function beforeAuth($request, $response) {
        if (!$request->headers['authorization']) {
            return [$request, $response->json(["error" => "Unauthorized"], 401)];
        }
        return [$request, $response];
    }
}
Router::use(AuthMiddleware::class);
```

### 7. Group Prefix Normalisation

Tina4 auto-normalises group prefixes — it prepends `/` if missing and strips trailing slashes. `Router::group("api/v1", ...)` and `Router::group("/api/v1", ...)` both work. However, for clarity, always start with `/`.
