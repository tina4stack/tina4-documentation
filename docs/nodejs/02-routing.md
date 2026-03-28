# Chapter 2: Routing

## 1. How Routing Works in Tina4

Every web application maps URLs to code. A browser requests `/products`. The framework finds the handler for `/products`. Runs it. Sends back the result. That mapping is routing.

In Tina4 Node.js, you define routes in TypeScript files inside `src/routes/`. Every `.ts` file in that directory -- and its subdirectories -- is auto-loaded when the server starts. No registration files. No central config. Drop a file in. It works.

Tina4 supports two routing styles: **explicit registration** with the `Router` class, and **file-based routing** where the file path becomes the URL.

The simplest possible route using explicit registration:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/hello", async (req, res) => {
    return res.json({ message: "Hello, World!" });
});
```

Save that as `src/routes/hello.ts`, start the server with `tina4 serve`, and visit `http://localhost:7148/hello`:

```json
{"message":"Hello, World!"}
```

The same thing using file-based routing. Create `src/routes/hello/get.ts`:

```typescript
export default async (req, res) => {
    return res.json({ message: "Hello, World!" });
};
```

Both approaches produce identical results. Use whichever you prefer -- or mix them.

---

## 2. HTTP Methods

Tina4 supports all five standard HTTP methods. Each one has a static method on the `Router` class:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/products", async (req, res) => {
    return res.json({ action: "list all products" });
});

Router.post("/products", async (req, res) => {
    return res.status(201).json({ action: "create a product" });
});

Router.put("/products/{id}", async (req, res) => {
    const id = req.params.id;
    return res.json({ action: `replace product ${id}` });
});

Router.patch("/products/{id}", async (req, res) => {
    const id = req.params.id;
    return res.json({ action: `update product ${id}` });
});

Router.delete("/products/{id}", async (req, res) => {
    const id = req.params.id;
    return res.json({ action: `delete product ${id}` });
});
```

For file-based routing, the HTTP method is the filename:

```
src/routes/products/get.ts      → GET /products
src/routes/products/post.ts     → POST /products
src/routes/products/[id]/put.ts → PUT /products/{id}
```

Test each one:

```bash
curl http://localhost:7148/products
```

```json
{"action":"list all products"}
```

```bash
curl -X POST http://localhost:7148/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Widget"}'
```

```json
{"action":"create a product"}
```

```bash
curl -X PUT http://localhost:7148/products/42
```

```json
{"action":"replace product 42"}
```

```bash
curl -X PATCH http://localhost:7148/products/42
```

```json
{"action":"update product 42"}
```

```bash
curl -X DELETE http://localhost:7148/products/42
```

```json
{"action":"delete product 42"}
```

`GET` reads. `POST` creates. `PUT` replaces. `PATCH` patches. `DELETE` removes. REST convention. Predictable API.

---

## 3. Path Parameters

Path parameters capture values from the URL. Wrap the parameter name in curly braces:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/users/{id}/posts/{postId}", async (req, res) => {
    const userId = req.params.id;
    const postId = req.params.postId;

    return res.json({
        user_id: userId,
        post_id: postId
    });
});
```

For file-based routing, wrap the parameter name in brackets:

```
src/routes/users/[id]/posts/[postId]/get.ts
```

```bash
curl http://localhost:7148/users/5/posts/99
```

```json
{"user_id":"5","post_id":"99"}
```

Notice `user_id` came back as the string `"5"`, not the integer `5`. Path parameters are strings by default.

> **Auto-casting:** Tina4 automatically casts path parameter values that are purely numeric to numbers. For example, requesting `/users/42/posts/99` will give you `req.params.id` as the number `42` and `req.params.postId` as the number `99` -- no explicit `:int` type hint required. The `:int` type hint adds validation (rejecting non-numeric values with a 404), but the auto-casting happens regardless.

### Typed Parameters

Enforce a type by adding a colon and the type after the parameter name:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/orders/{id:int}", async (req, res) => {
    const id = req.params.id; // This is now a number
    return res.json({
        order_id: id,
        type: typeof id
    });
});
```

```bash
curl http://localhost:7148/orders/42
```

```json
{"order_id":42,"type":"number"}
```

Pass a non-integer value and the route refuses to match. You get a 404:

```bash
curl http://localhost:7148/orders/abc
```

```json
{"error":"Not found","path":"/orders/abc","status":404}
```

Supported types:

| Type | Matches | Auto-cast | Example |
|------|---------|-----------|---------|
| `int` | Digits only | Number | `{id:int}` matches `42` but not `abc` |
| `float` | Decimal numbers | Number | `{price:float}` matches `19.99` |
| `path` | All remaining path segments (catch-all) | String | `{slug:path}` matches `docs/api/auth` |
| `alpha` | Letters only | String | `{slug:alpha}` matches `hello` but not `hello123` |
| `alphanumeric` | Letters and digits | String | `{code:alphanumeric}` matches `abc123` |

The `{name}` form (no type) matches any single path segment and returns it as a string.

### Typed Parameters in Action

Here is a complete example showing the most commonly used typed parameters together:

```typescript
import { Router } from "tina4-nodejs";

// Integer parameter -- only digits match, auto-cast to number
Router.get("/products/{id:int}", async (req, res) => {
    const id = req.params.id; // number, e.g. 42
    return res.json({
        product_id: id,
        type: typeof id
    });
});

// Float parameter -- decimal numbers, auto-cast to number
Router.get("/products/{id:int}/price/{price:float}", async (req, res) => {
    const id = req.params.id;
    const price = req.params.price;
    return res.json({
        product_id: id,
        price,
        type: typeof price
    });
});

// Path parameter -- catch-all, captures remaining segments as a string
Router.get("/files/{filepath:path}", async (req, res) => {
    const filepath = req.params.filepath;
    // filepath could be "images/photos/cat.jpg"
    return res.json({
        filepath,
        type: typeof filepath
    });
});
```

```bash
# Integer route -- matches digits, returns a number
curl http://localhost:7148/products/42
```

```json
{"product_id":42,"type":"number"}
```

```bash
# Integer route -- non-integer gives a 404
curl http://localhost:7148/products/abc
```

```json
{"error":"Not found","path":"/products/abc","status":404}
```

```bash
# Path catch-all -- captures everything after /files/
curl http://localhost:7148/files/images/photos/cat.jpg
```

```json
{"filepath":"images/photos/cat.jpg","type":"string"}
```

The `:int` and `:float` types act as both a constraint and a converter. If the URL segment does not match the expected pattern, the route is skipped entirely and Tina4 moves on to the next registered route (or returns 404 if nothing matches). The `:path` type is greedy -- it consumes all remaining segments, making it ideal for file paths and documentation URLs.

---

## 4. Query Parameters

Query parameters are the key-value pairs after the `?` in a URL. Access them via `req.query`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/search", async (req, res) => {
    const q = req.query.q ?? "";
    const page = parseInt(req.query.page ?? "1", 10);
    const limit = parseInt(req.query.limit ?? "10", 10);

    return res.json({
        query: q,
        page,
        limit,
        offset: (page - 1) * limit
    });
});
```

```bash
curl "http://localhost:7148/search?q=keyboard&page=2&limit=20"
```

```json
{"query":"keyboard","page":2,"limit":20,"offset":20}
```

A missing query parameter yields `undefined` from `req.query.key`. The nullish coalescing operator (`??`) provides defaults.

---

## 5. Route Groups

A set of routes sharing a common prefix belongs in a group. `Router.group()` eliminates repetition:

```typescript
import { Router } from "tina4-nodejs";

Router.group("/api/v1", () => {

    Router.get("/users", async (req, res) => {
        return res.json({ users: [] });
    });

    Router.get("/users/{id:int}", async (req, res) => {
        const id = req.params.id;
        return res.json({ user: { id, name: "Alice" } });
    });

    Router.post("/users", async (req, res) => {
        return res.status(201).json({ created: true });
    });

    Router.get("/products", async (req, res) => {
        return res.json({ products: [] });
    });
});
```

The routes register as `/api/v1/users`, `/api/v1/users/{id}`, and `/api/v1/products`. Short paths inside the group. Tina4 prepends the prefix.

```bash
curl http://localhost:7148/api/v1/users
```

```json
{"users":[]}
```

Groups nest:

```typescript
import { Router } from "tina4-nodejs";

Router.group("/api", () => {
    Router.group("/v1", () => {
        Router.get("/status", async (req, res) => {
            return res.json({ version: "1.0" });
        });
    });

    Router.group("/v2", () => {
        Router.get("/status", async (req, res) => {
            return res.json({ version: "2.0" });
        });
    });
});
```

```bash
curl http://localhost:7148/api/v1/status
```

```json
{"version":"1.0"}
```

```bash
curl http://localhost:7148/api/v2/status
```

```json
{"version":"2.0"}
```

---

## 6. Middleware on Routes

Middleware is code that runs before (or after) your route handler. Authentication. Logging. Rate limiting. Input validation. Anything that belongs on multiple routes.

### Middleware on a Single Route

Pass middleware as the third argument to any route method:

```typescript
import { Router } from "tina4-nodejs";

async function logRequest(req, res, next) {
    const start = Date.now();
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);

    const result = await next(req, res);

    const duration = Date.now() - start;
    console.log(`  Completed in ${duration}ms`);

    return result;
}

Router.get("/api/data", async (req, res) => {
    return res.json({ data: [1, 2, 3] });
}, "logRequest");
```

The middleware function receives `req`, `res`, and `next`. Call `next(req, res)` to continue to the route handler. Skip the call and the handler never runs -- the chain stops. A locked gate for unauthorized requests.

### Blocking Middleware

Middleware that checks for an API key:

```typescript
import { Router } from "tina4-nodejs";

async function requireApiKey(req, res, next) {
    const apiKey = req.headers["x-api-key"] ?? "";

    if (apiKey !== "my-secret-key") {
        return res.status(401).json({ error: "Invalid API key" });
    }

    return next(req, res);
}

Router.get("/api/secret", async (req, res) => {
    return res.json({ secret: "The answer is 42" });
}, "requireApiKey");
```

```bash
curl http://localhost:7148/api/secret
```

```json
{"error":"Invalid API key"}
```

```bash
curl http://localhost:7148/api/secret -H "X-API-Key: my-secret-key"
```

```json
{"secret":"The answer is 42"}
```

### Middleware on a Group

Apply middleware to an entire group:

```typescript
import { Router } from "tina4-nodejs";

Router.group("/api/admin", () => {

    Router.get("/dashboard", async (req, res) => {
        return res.json({ page: "admin dashboard" });
    });

    Router.get("/users", async (req, res) => {
        return res.json({ page: "user management" });
    });

}, "requireAuth");
```

### Multiple Middleware

Chain multiple middleware by passing an array:

```typescript
Router.get("/api/important", async (req, res) => {
    return res.json({ data: "important stuff" });
}, ["logRequest", "requireApiKey", "requireAuth"]);
```

Middleware runs in order: `logRequest` first, then `requireApiKey`, then `requireAuth`, then the route handler.

---

## 7. Route Decorators: @noauth and @secured

Tina4 provides two special decorators for controlling authentication on routes.

### @noauth -- Public Routes

When your application has global authentication middleware, `@noauth` marks specific routes as public:

```typescript
import { Router, noauth } from "tina4-nodejs";

/**
 * @noauth
 */
Router.get("/api/public/info", async (req, res) => {
    return res.json({
        app: "My Store",
        version: "1.0.0"
    });
});
```

The `@noauth` decorator tells Tina4 to skip authentication checks for this route, even with global auth middleware configured in `.env`.

### @secured -- Protected GET Routes

The `@secured` annotation marks a GET route as requiring authentication:

```typescript
import { Router } from "tina4-nodejs";

/**
 * @secured
 */
Router.get("/api/profile", async (req, res) => {
    return res.json({
        user: req.user
    });
});
```

By default, `POST`, `PUT`, `PATCH`, and `DELETE` routes are considered secured. `GET` routes are not -- they are public unless you add `@secured`.

---

## 8. Route Chaining: .secure() and .cache()

Routes return a chainable object. Two methods you can call on any route: `.secure()` and `.cache()`.

### .secure()

`.secure()` requires a valid bearer token in the `Authorization` header. If the token is missing or invalid, the route returns `401 Unauthorized` without ever reaching your handler:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/account", async (req, res) => {
    return res.json({ account: req.user });
}).secure();
```

```bash
curl http://localhost:7148/api/account
# 401 Unauthorized

curl http://localhost:7148/api/account -H "Authorization: Bearer eyJhbGci..."
# 200 OK
```

### .cache()

`.cache()` enables response caching for the route. Once the handler runs and produces a response, subsequent requests to the same URL return the cached result without re-executing the handler:

```typescript
Router.get("/api/catalog", async (req, res) => {
    // Expensive database query
    return res.json({ products });
}).cache();
```

### Chaining Both

Chain `.secure()` and `.cache()` together:

```typescript
Router.get("/api/data", async (req, res) => {
    return res.json({ data });
}).secure().cache();
```

This route requires a bearer token and caches the response. Order does not matter -- `.cache().secure()` produces the same result.

---

## 9. Wildcard and Catch-All Routes

### Wildcard Routes

Use `*` at the end of a path to match anything after it:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/docs/*", async (req, res) => {
    const path = req.params["*"] ?? "";
    return res.json({
        section: "docs",
        path
    });
});
```

```bash
curl http://localhost:7148/docs/getting-started
```

```json
{"section":"docs","path":"getting-started"}
```

```bash
curl http://localhost:7148/docs/api/authentication/jwt
```

```json
{"section":"docs","path":"api/authentication/jwt"}
```

### Catch-All Route (Custom 404)

Register a catch-all to handle any unmatched URL:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/*", async (req, res) => {
    return res.status(404).json({
        error: "Page not found",
        path: req.path
    });
});
```

Define this route last. Tina4 matches routes in registration order -- first match wins.

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

As your application grows, you need visibility into all registered routes. The CLI provides it:

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

Filter by method or search for a path pattern:

```bash
tina4 routes --method POST
tina4 routes --filter users
```

---

## 11. Organizing Route Files

Organize route files however you want. Tina4 loads every `.ts` file in `src/routes/` recursively. Two common patterns:

### Pattern 1: One File Per Resource

```
src/routes/
├── products.ts     # All product routes
├── users.ts        # All user routes
├── orders.ts       # All order routes
└── pages.ts        # HTML page routes
```

### Pattern 2: File-Based Routing by Feature

```
src/routes/
├── api/
│   ├── products/
│   │   ├── get.ts          # GET /api/products
│   │   ├── post.ts         # POST /api/products
│   │   └── [id]/
│   │       ├── get.ts      # GET /api/products/{id}
│   │       ├── put.ts      # PUT /api/products/{id}
│   │       └── delete.ts   # DELETE /api/products/{id}
│   └── users/
│       ├── get.ts
│       └── post.ts
├── admin/
│   ├── dashboard/get.ts
│   └── settings/get.ts
└── pages/
    ├── home/get.ts
    └── about/get.ts
```

Both patterns work identically. Choose whichever keeps your project navigable.

---

## 12. Exercise: Build a Full CRUD API for Products

Build a complete REST API for managing products. All data lives in a TypeScript array (no database yet -- that comes in Chapter 5).

### Requirements

Create a file `src/routes/product-api.ts` with the following routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List all products. Support `?category=` filter. |
| `GET` | `/api/products/{id:int}` | Get a single product by ID. Return 404 if not found. |
| `POST` | `/api/products` | Create a new product. Return 201. |
| `PUT` | `/api/products/{id:int}` | Replace a product. Return 404 if not found. |
| `DELETE` | `/api/products/{id:int}` | Delete a product. Return 204 with no body. |

Each product has: `id` (number), `name` (string), `category` (string), `price` (number), `inStock` (boolean).

Start with this seed data:

```typescript
let products = [
    { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99, inStock: true },
    { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true },
    { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99, inStock: false },
    { id: 4, name: "Standing Desk", category: "Office", price: 549.99, inStock: true },
    { id: 5, name: "Running Shoes", category: "Fitness", price: 119.99, inStock: true }
];
```

Test with:

```bash
# List all
curl http://localhost:7148/api/products

# Filter by category
curl "http://localhost:7148/api/products?category=Fitness"

# Get one
curl http://localhost:7148/api/products/3

# Create
curl -X POST http://localhost:7148/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Desk Lamp", "category": "Office", "price": 39.99, "inStock": true}'

# Update
curl -X PUT http://localhost:7148/api/products/3 \
  -H "Content-Type: application/json" \
  -d '{"name": "Burr Coffee Grinder", "category": "Kitchen", "price": 59.99, "inStock": true}'

# Delete
curl -X DELETE http://localhost:7148/api/products/3

# Not found
curl http://localhost:7148/api/products/999
```

---

## 13. Solution

Create `src/routes/product-api.ts`:

```typescript
import { Router } from "tina4-nodejs";

// In-memory product store (resets on server restart)
let products = [
    { id: 1, name: "Wireless Keyboard", category: "Electronics", price: 79.99, inStock: true },
    { id: 2, name: "Yoga Mat", category: "Fitness", price: 29.99, inStock: true },
    { id: 3, name: "Coffee Grinder", category: "Kitchen", price: 49.99, inStock: false },
    { id: 4, name: "Standing Desk", category: "Office", price: 549.99, inStock: true },
    { id: 5, name: "Running Shoes", category: "Fitness", price: 119.99, inStock: true }
];

let nextId = 6;

// List all products, optionally filter by category
Router.get("/api/products", async (req, res) => {
    const category = req.query.category ?? null;

    if (category !== null) {
        const filtered = products.filter(
            p => p.category.toLowerCase() === String(category).toLowerCase()
        );
        return res.json({ products: filtered, count: filtered.length });
    }

    return res.json({ products, count: products.length });
});

// Get a single product by ID
Router.get("/api/products/{id:int}", async (req, res) => {
    const id = req.params.id;
    const product = products.find(p => p.id === id);

    if (!product) {
        return res.status(404).json({ error: "Product not found", id });
    }

    return res.json(product);
});

// Create a new product
Router.post("/api/products", async (req, res) => {
    const body = req.body;

    if (!body.name) {
        return res.status(400).json({ error: "Name is required" });
    }

    const product = {
        id: nextId++,
        name: body.name,
        category: body.category ?? "Uncategorized",
        price: parseFloat(body.price ?? 0),
        inStock: Boolean(body.inStock ?? true)
    };

    products.push(product);

    return res.status(201).json(product);
});

// Replace a product
Router.put("/api/products/{id:int}", async (req, res) => {
    const id = req.params.id;
    const body = req.body;
    const index = products.findIndex(p => p.id === id);

    if (index === -1) {
        return res.status(404).json({ error: "Product not found", id });
    }

    products[index] = {
        id,
        name: body.name ?? products[index].name,
        category: body.category ?? products[index].category,
        price: parseFloat(body.price ?? products[index].price),
        inStock: Boolean(body.inStock ?? products[index].inStock)
    };

    return res.json(products[index]);
});

// Delete a product
Router.delete("/api/products/{id:int}", async (req, res) => {
    const id = req.params.id;
    const index = products.findIndex(p => p.id === id);

    if (index === -1) {
        return res.status(404).json({ error: "Product not found", id });
    }

    products.splice(index, 1);

    return res.status(204).json(null);
});
```

**Expected output for the test commands:**

List all:

```json
{"products":[{"id":1,"name":"Wireless Keyboard","category":"Electronics","price":79.99,"inStock":true},{"id":2,"name":"Yoga Mat","category":"Fitness","price":29.99,"inStock":true},{"id":3,"name":"Coffee Grinder","category":"Kitchen","price":49.99,"inStock":false},{"id":4,"name":"Standing Desk","category":"Office","price":549.99,"inStock":true},{"id":5,"name":"Running Shoes","category":"Fitness","price":119.99,"inStock":true}],"count":5}
```

Filter by category:

```json
{"products":[{"id":2,"name":"Yoga Mat","category":"Fitness","price":29.99,"inStock":true},{"id":5,"name":"Running Shoes","category":"Fitness","price":119.99,"inStock":true}],"count":2}
```

Create (Status: `201 Created`):

```json
{"id":6,"name":"Desk Lamp","category":"Office","price":39.99,"inStock":true}
```

Not found (Status: `404 Not Found`):

```json
{"error":"Product not found","id":999}
```

---

## 14. Gotchas

### 1. Trailing Slashes Matter

**Problem:** `/products` works but `/products/` returns a 404 (or vice versa).

**Cause:** Tina4 treats `/products` and `/products/` as different routes by default.

**Fix:** Pick one convention and stick with it. Set `TINA4_TRAILING_SLASH_REDIRECT=true` in `.env` and Tina4 redirects `/products/` to `/products`.

### 2. Parameter Names Must Be Unique in a Path

**Problem:** `/users/{id}/posts/{id}` gives wrong results -- both parameters share the same name.

**Cause:** The second `{id}` overwrites the first in `req.params`.

**Fix:** Use distinct names: `/users/{userId}/posts/{postId}`.

### 3. Method Conflicts

**Problem:** You defined `Router.get("/items/{id}", ...)` and `Router.get("/items/{action}", ...)` and the wrong handler runs.

**Cause:** Both patterns match `/items/42`. The first one registered wins.

**Fix:** Use typed parameters to disambiguate: `Router.get("/items/{id:int}", ...)` matches integers only, leaving `/items/export` free for the other route.

### 4. Route Handler Must Return a Response

**Problem:** Your route handler runs but the browser shows an empty page or a 500 error.

**Cause:** You forgot the `return` statement. Without `return`, the handler produces `undefined` and Tina4 has nothing to send back.

**Fix:** Every handler must `return res.json(...)` or `return res.html(...)`.

### 5. Async Handlers

**Problem:** Your handler calls an async function but the response returns before it completes.

**Cause:** You forgot to `await` the async operation. The handler returns before the work finishes.

**Fix:** `await` all async operations inside handlers. All Tina4 route handlers should be `async` functions.

### 6. Middleware Function Must Be a Named Function

**Problem:** Passing an anonymous arrow function as middleware causes an error.

**Cause:** Tina4 expects middleware referenced by function name (a string), not as an inline closure.

**Fix:** Define your middleware as a named function and pass the name as a string: `"myMiddleware"`, not `(req, res, next) => { ... }`.

### 7. Group Prefix Must Start with a Slash

**Problem:** `Router.group("api/v1", ...)` produces routes that do not match.

**Cause:** The group prefix needs a leading `/`.

**Fix:** Start group prefixes with `/`: `Router.group("/api/v1", ...)`.
