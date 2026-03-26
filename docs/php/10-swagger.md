# Chapter 10: API Documentation with Swagger

## 1. The 47-Endpoint Problem

Your team has 47 API endpoints. The frontend developer asks what each one accepts. You email a spreadsheet. It goes stale. You write a wiki page. Nobody updates it. You add comments to the code. Nobody reads them.

Swagger solves this permanently. It generates interactive API documentation from annotations in your route files. The docs stay current because they come from the code itself. Your frontend developer browses every endpoint, sees the expected request and response formats, and tests endpoints from the browser.

Tina4 auto-generates a Swagger UI at `/swagger` from doc-block annotations. No build step. No extra tooling. Write the annotations. The documentation appears.

---

## 2. What Swagger/OpenAPI Is

OpenAPI is a specification for describing REST APIs. Swagger is the toolset that reads OpenAPI specs and generates documentation, client SDKs, and server stubs.

An OpenAPI spec describes:

- Every endpoint (path + HTTP method)
- Parameters (path, query, header, body)
- Responses (status codes, body schemas)
- Data schemas (what a "User" or "Product" looks like)
- Authentication requirements
- Grouping and tagging

Tina4 builds this spec from doc-block comments in your PHP. No JSON or YAML by hand.

---

## 3. Enabling Swagger

Available out of the box when `TINA4_DEBUG=true`. Navigate to:

```
http://localhost:7146/swagger
```

The Swagger UI appears with all defined routes. No annotations yet means default descriptions.

For production, control it explicitly:

```env
TINA4_SWAGGER=true
```

### The Swagger JSON Endpoint

Raw OpenAPI spec:

```
http://localhost:7146/swagger/json
```

```bash
curl http://localhost:7146/swagger/json
```

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "My Store API",
    "version": "1.0.0"
  },
  "paths": {
    "/api/products": {
      "get": {
        "summary": "List all products",
        "responses": {
          "200": {
            "description": "Successful response"
          }
        }
      }
    }
  }
}
```

Import this JSON into Postman, Insomnia, or use it to generate client SDKs.

---

## 4. Adding Descriptions to Routes

Doc-block comments above route definitions:

```php
<?php
use Tina4Router;

/**
 * List all products
 * @description Returns a paginated list of all products in the catalog
 * @tags Products
 */
Router::get("/api/products", function ($request, $response) {
    return $response->json(["products" => []]);
});
```

First line becomes the `summary`. `@description` provides detail. `@tags` groups the endpoint.

### Documenting Path Parameters

```php
/**
 * Get a product by ID
 * @description Returns a single product with full details including inventory status
 * @tags Products
 * @param int $id The unique product identifier
 */
Router::get("/api/products/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    return $response->json([
        "id" => $id,
        "name" => "Wireless Keyboard",
        "price" => 79.99
    ]);
});
```

`@param` tells Swagger about the path parameter. Shows as a required field with type information.

### Documenting Query Parameters

```php
/**
 * Search products
 * @description Search the product catalog by name, category, or price range
 * @tags Products
 * @query string $q Search query (searches product name and description)
 * @query string $category Filter by category name
 * @query float $min_price Minimum price filter
 * @query float $max_price Maximum price filter
 * @query int $page Page number (default: 1)
 * @query int $limit Items per page (default: 20, max: 100)
 */
Router::get("/api/products/search", function ($request, $response) {
    $q = $request->query["q"] ?? "";
    $page = (int) ($request->query["page"] ?? 1);
    $limit = min((int) ($request->query["limit"] ?? 20), 100);

    return $response->json([
        "query" => $q,
        "page" => $page,
        "limit" => $limit,
        "results" => [],
        "total" => 0
    ]);
});
```

Each `@query` adds a parameter to the docs with type and description.

---

## 5. Documenting Request and Response Schemas

### Request Body

```php
/**
 * Create a new product
 * @description Creates a product in the catalog. Requires admin authentication.
 * @tags Products
 * @body {"name": "string", "category": "string", "price": "float", "in_stock": "bool", "description": "string"}
 * @response 201 {"id": "int", "name": "string", "category": "string", "price": "float", "in_stock": "bool", "created_at": "string"}
 * @response 400 {"error": "string"}
 */
Router::post("/api/products", function ($request, $response) {
    $body = $request->body;

    if (empty($body["name"])) {
        return $response->json(["error" => "Name is required"], 400);
    }

    return $response->json([
        "id" => 1,
        "name" => $body["name"],
        "category" => $body["category"] ?? "Uncategorized",
        "price" => (float) ($body["price"] ?? 0),
        "in_stock" => (bool) ($body["in_stock"] ?? true),
        "created_at" => date("c")
    ], 201);
});
```

`@body` describes the expected JSON. `@response` documents each status code and its payload.

### Multiple Response Codes

```php
/**
 * Update a product
 * @description Update an existing product by ID. Only provided fields are updated.
 * @tags Products
 * @param int $id Product ID
 * @body {"name": "string", "category": "string", "price": "float", "in_stock": "bool"}
 * @response 200 {"id": "int", "name": "string", "category": "string", "price": "float", "in_stock": "bool", "updated_at": "string"}
 * @response 404 {"error": "string", "id": "int"}
 * @response 400 {"error": "string"}
 */
Router::put("/api/products/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    $body = $request->body;

    if ($id > 100) {
        return $response->json(["error" => "Product not found", "id" => $id], 404);
    }

    return $response->json([
        "id" => $id,
        "name" => $body["name"] ?? "Widget",
        "category" => $body["category"] ?? "General",
        "price" => (float) ($body["price"] ?? 9.99),
        "in_stock" => (bool) ($body["in_stock"] ?? true),
        "updated_at" => date("c")
    ]);
});
```

Swagger UI shows each response code with its schema. A `200` versus a `404` at a glance.

---

## 6. Tags for Grouping Endpoints

Tags organize the Swagger UI. Without tags: one flat list. With tags: collapsible sections.

```php
/**
 * List all users
 * @tags Users
 */
Router::get("/api/users", function ($request, $response) {
    return $response->json(["users" => []]);
});

/**
 * Get user by ID
 * @tags Users
 */
Router::get("/api/users/{id:int}", function ($request, $response) {
    return $response->json(["id" => $request->params["id"], "name" => "Alice"]);
});

/**
 * List all orders
 * @tags Orders
 */
Router::get("/api/orders", function ($request, $response) {
    return $response->json(["orders" => []]);
});

/**
 * Create an order
 * @tags Orders
 */
Router::post("/api/orders", function ($request, $response) {
    return $response->json(["order_id" => 1], 201);
});

/**
 * List all products
 * @tags Products
 */
Router::get("/api/products", function ($request, $response) {
    return $response->json(["products" => []]);
});
```

Three sections in the UI: "Users", "Orders", "Products". Each expands to show its endpoints.

### Multiple Tags

An endpoint in multiple groups:

```php
/**
 * Get user's orders
 * @tags Users, Orders
 */
Router::get("/api/users/{id:int}/orders", function ($request, $response) {
    return $response->json(["orders" => []]);
});
```

Appears in both the "Users" and "Orders" sections.

---

## 7. Example Values

Realistic data instead of type names:

```php
/**
 * Create a new product
 * @description Creates a product in the catalog
 * @tags Products
 * @example request {"name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99, "in_stock": true, "description": "Split keyboard with adjustable tenting"}
 * @example response {"id": 42, "name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99, "in_stock": true, "created_at": "2026-03-22T14:30:00+00:00"}
 */
Router::post("/api/products", function ($request, $response) {
    $body = $request->body;

    return $response->json([
        "id" => 42,
        "name" => $body["name"],
        "category" => $body["category"] ?? "Uncategorized",
        "price" => (float) ($body["price"] ?? 0),
        "in_stock" => (bool) ($body["in_stock"] ?? true),
        "created_at" => date("c")
    ], 201);
});
```

The `@example` annotations populate the Swagger UI. When a developer clicks "Try it out", the example request is pre-filled.

---

## 8. Try-It-Out from the Swagger UI

Every endpoint has a "Try it out" button. Click it:

1. Input fields expand
2. Example values pre-fill (if provided)
3. Edit parameters, headers, body
4. The actual HTTP request fires against your running server
5. Response appears: status, headers, body

A live testing tool inside your documentation. No Postman needed.

### Authentication in Try-It-Out

Endpoints requiring auth show a lock icon. Click "Authorize" at the top of the Swagger UI. Enter your JWT or API key. All subsequent requests include the header.

Tina4 auto-detects auth requirements from `@secured` and `@noauth` annotations.

---

## 9. Customizing the Swagger Info Block

Configure in `.env`:

```env
TINA4_SWAGGER_TITLE=My Store API
TINA4_SWAGGER_DESCRIPTION=API for managing products, orders, and users
TINA4_SWAGGER_VERSION=1.0.0
TINA4_SWAGGER_CONTACT_EMAIL=api@mystore.com
TINA4_SWAGGER_LICENSE=MIT
```

This appears in the Swagger UI header and the OpenAPI spec:

```json
{
  "openapi": "3.0.0",
  "info": {
    "title": "My Store API",
    "description": "API for managing products, orders, and users",
    "version": "1.0.0",
    "contact": {
      "email": "api@mystore.com"
    },
    "license": {
      "name": "MIT"
    }
  }
}
```

---

## 10. Generating Client SDKs from the Spec

The OpenAPI spec at `/swagger/json` feeds code generation tools. Client libraries in any language.

### Using OpenAPI Generator

```bash
npm install -g @openapitools/openapi-generator-cli

# TypeScript client
openapi-generator-cli generate \
  -i http://localhost:7146/swagger/json \
  -g typescript-fetch \
  -o ./frontend/api-client

# Python client
openapi-generator-cli generate \
  -i http://localhost:7146/swagger/json \
  -g python \
  -o ./python-client
```

The generated code is typed. IDE autocompletion works:

```typescript
const api = new ProductsApi();

const product = await api.getProductById({ id: 42 });
console.log(product.name);  // TypeScript knows this is a string

const newProduct = await api.createProduct({
    name: "Widget",
    category: "General",
    price: 9.99,
    inStock: true
});
```

Update annotations. Regenerate. Client stays in sync.

---

## 11. A Complete Documented API

All annotation features together:

```php
<?php
use Tina4Router;

/**
 * List all users
 * @description Returns a paginated list of users. Supports filtering by role and searching by name.
 * @tags Users
 * @query int $page Page number (default: 1)
 * @query int $limit Items per page (default: 20)
 * @query string $role Filter by role (admin, user, moderator)
 * @query string $search Search by name or email
 * @response 200 {"users": [{"id": "int", "name": "string", "email": "string", "role": "string"}], "total": "int", "page": "int", "pages": "int"}
 * @example response {"users": [{"id": 1, "name": "Alice", "email": "alice@example.com", "role": "admin"}, {"id": 2, "name": "Bob", "email": "bob@example.com", "role": "user"}], "total": 42, "page": 1, "pages": 3}
 */
Router::get("/api/users", function ($request, $response) {
    $page = (int) ($request->query["page"] ?? 1);
    $limit = (int) ($request->query["limit"] ?? 20);

    return $response->json([
        "users" => [
            ["id" => 1, "name" => "Alice", "email" => "alice@example.com", "role" => "admin"],
            ["id" => 2, "name" => "Bob", "email" => "bob@example.com", "role" => "user"]
        ],
        "total" => 42,
        "page" => $page,
        "pages" => (int) ceil(42 / $limit)
    ]);
});

/**
 * Get user by ID
 * @description Returns full user profile including account creation date
 * @tags Users
 * @param int $id User ID
 * @response 200 {"id": "int", "name": "string", "email": "string", "role": "string", "created_at": "string"}
 * @response 404 {"error": "string"}
 * @example response {"id": 1, "name": "Alice", "email": "alice@example.com", "role": "admin", "created_at": "2026-01-15T10:30:00+00:00"}
 */
Router::get("/api/users/{id:int}", function ($request, $response) {
    $id = $request->params["id"];

    if ($id > 100) {
        return $response->json(["error" => "User not found"], 404);
    }

    return $response->json([
        "id" => $id,
        "name" => "Alice",
        "email" => "alice@example.com",
        "role" => "admin",
        "created_at" => "2026-01-15T10:30:00+00:00"
    ]);
});

/**
 * Create a new user
 * @description Creates a user account. Email must be unique.
 * @tags Users
 * @body {"name": "string", "email": "string", "password": "string", "role": "string"}
 * @response 201 {"id": "int", "name": "string", "email": "string", "role": "string", "created_at": "string"}
 * @response 400 {"errors": ["string"]}
 * @response 409 {"error": "string"}
 * @example request {"name": "Charlie", "email": "charlie@example.com", "password": "securePass123", "role": "user"}
 * @example response {"id": 3, "name": "Charlie", "email": "charlie@example.com", "role": "user", "created_at": "2026-03-22T14:30:00+00:00"}
 */
Router::post("/api/users", function ($request, $response) {
    $body = $request->body;

    $errors = [];
    if (empty($body["name"])) $errors[] = "Name is required";
    if (empty($body["email"])) $errors[] = "Email is required";
    if (empty($body["password"])) $errors[] = "Password is required";

    if (!empty($errors)) {
        return $response->json(["errors" => $errors], 400);
    }

    return $response->json([
        "id" => 3,
        "name" => $body["name"],
        "email" => $body["email"],
        "role" => $body["role"] ?? "user",
        "created_at" => date("c")
    ], 201);
});

/**
 * Delete a user
 * @description Permanently deletes a user account. Requires admin role.
 * @tags Users
 * @param int $id User ID
 * @response 204
 * @response 404 {"error": "string"}
 */
Router::delete("/api/users/{id:int}", function ($request, $response) {
    $id = $request->params["id"];

    if ($id > 100) {
        return $response->json(["error" => "User not found"], 404);
    }

    return $response->json(null, 204);
});
```

Visit `/swagger`. Four endpoints under "Users". Full parameter documentation, examples, multiple response codes.

---

## 12. Exercise: Document a Complete User API

Extend the User API with three more endpoints. Full Swagger annotations on each.

### Requirements

| Method | Path | Description |
|--------|------|-------------|
| `PUT` | `/api/users/{id}` | Update a user. Body: name, email, role. Response: updated user. |
| `GET` | `/api/users/{id}/orders` | List a user's orders. Query: status filter, pagination. |
| `POST` | `/api/users/{id}/avatar` | Upload user avatar. Body: avatar_url string. |

Each endpoint needs:

1. Summary (first line)
2. `@description`
3. `@tags`
4. `@param` for path parameters
5. `@query` for query parameters (where applicable)
6. `@body` for request body (where applicable)
7. `@response` for each status code
8. `@example` for request and response (where applicable)

### Verify at:

```
http://localhost:7146/swagger
```

---

## 13. Solution

Create `src/routes/user-api-documented.php`:

```php
<?php
use Tina4Router;

/**
 * Update a user
 * @description Updates an existing user's profile information. Only provided fields are updated. Email must remain unique.
 * @tags Users
 * @param int $id User ID
 * @body {"name": "string", "email": "string", "role": "string"}
 * @response 200 {"id": "int", "name": "string", "email": "string", "role": "string", "updated_at": "string"}
 * @response 404 {"error": "string"}
 * @response 409 {"error": "string"}
 * @example request {"name": "Alice Smith", "email": "alice.smith@example.com", "role": "admin"}
 * @example response {"id": 1, "name": "Alice Smith", "email": "alice.smith@example.com", "role": "admin", "updated_at": "2026-03-22T14:30:00+00:00"}
 */
Router::put("/api/users/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    $body = $request->body;

    if ($id > 100) {
        return $response->json(["error" => "User not found"], 404);
    }

    return $response->json([
        "id" => $id,
        "name" => $body["name"] ?? "Alice",
        "email" => $body["email"] ?? "alice@example.com",
        "role" => $body["role"] ?? "user",
        "updated_at" => date("c")
    ]);
});

/**
 * List user orders
 * @description Returns a paginated list of orders for a specific user. Supports filtering by order status.
 * @tags Users, Orders
 * @param int $id User ID
 * @query string $status Filter by order status (pending, processing, shipped, delivered, cancelled)
 * @query int $page Page number (default: 1)
 * @query int $limit Items per page (default: 20)
 * @response 200 {"orders": [{"id": "int", "product": "string", "quantity": "int", "total": "float", "status": "string", "created_at": "string"}], "total": "int", "page": "int"}
 * @response 404 {"error": "string"}
 * @example response {"orders": [{"id": 101, "product": "Wireless Keyboard", "quantity": 2, "total": 159.98, "status": "shipped", "created_at": "2026-03-20T10:00:00+00:00"}], "total": 5, "page": 1}
 */
Router::get("/api/users/{id:int}/orders", function ($request, $response) {
    $id = $request->params["id"];
    $status = $request->query["status"] ?? null;
    $page = (int) ($request->query["page"] ?? 1);

    if ($id > 100) {
        return $response->json(["error" => "User not found"], 404);
    }

    $orders = [
        ["id" => 101, "product" => "Wireless Keyboard", "quantity" => 2, "total" => 159.98, "status" => "shipped", "created_at" => "2026-03-20T10:00:00+00:00"],
        ["id" => 102, "product" => "USB-C Hub", "quantity" => 1, "total" => 49.99, "status" => "delivered", "created_at" => "2026-03-15T09:00:00+00:00"]
    ];

    if ($status !== null) {
        $orders = array_values(array_filter($orders, fn($o) => $o["status"] === $status));
    }

    return $response->json(["orders" => $orders, "total" => count($orders), "page" => $page]);
});

/**
 * Upload user avatar
 * @description Sets or updates the avatar URL for a user. The avatar should be hosted on a CDN or static file server.
 * @tags Users
 * @param int $id User ID
 * @body {"avatar_url": "string"}
 * @response 200 {"id": "int", "avatar_url": "string", "updated_at": "string"}
 * @response 400 {"error": "string"}
 * @response 404 {"error": "string"}
 * @example request {"avatar_url": "https://cdn.example.com/avatars/alice-2026.jpg"}
 * @example response {"id": 1, "avatar_url": "https://cdn.example.com/avatars/alice-2026.jpg", "updated_at": "2026-03-22T14:30:00+00:00"}
 */
Router::post("/api/users/{id:int}/avatar", function ($request, $response) {
    $id = $request->params["id"];
    $body = $request->body;

    if ($id > 100) {
        return $response->json(["error" => "User not found"], 404);
    }

    if (empty($body["avatar_url"])) {
        return $response->json(["error" => "avatar_url is required"], 400);
    }

    return $response->json([
        "id" => $id,
        "avatar_url" => $body["avatar_url"],
        "updated_at" => date("c")
    ]);
});
```

Visit `http://localhost:7146/swagger`. Verify:

- "Users" section has six endpoints (list, get, create, update, delete, avatar)
- "Orders" section shows "List user orders" (dual-tagged)
- Each endpoint has summary, description, parameters, request body, response codes
- "Try it out" works
- Examples pre-fill

---

## 14. Gotchas

### 1. Annotations Must Be Directly Above the Route

**Problem:** Swagger annotations missing from the docs.

**Cause:** Blank line or code between the doc-block and `Router::`. Tina4 reads only doc-blocks immediately above the route definition.

**Fix:** `*/` must be on the line directly before `Router::get(...)`. No blank lines.

### 2. Missing @tags Makes Endpoints Hard to Find

**Problem:** All endpoints in one flat list.

**Cause:** No `@tags`. Everything grouped under "default".

**Fix:** Add `@tags ResourceName` to every route.

### 3. @body Must Be Valid JSON

**Problem:** Body schema shows empty or broken.

**Cause:** Malformed JSON. Trailing comma, missing quotes, unescaped characters.

**Fix:** Validate the JSON. Double quotes on every key and string value. No trailing commas.

### 4. Swagger Shows Unannotated Routes

**Problem:** Routes without annotations appear with minimal docs.

**Cause:** Tina4 includes all registered routes. By design. Nothing hidden.

**Fix:** Add annotations for quality. Hide a route with `@hidden` in its doc-block.

### 5. Response Examples Do Not Match Reality

**Problem:** Example response shows different fields than the actual API.

**Cause:** Annotations written once, never updated. They are comments. Not validated against code.

**Fix:** Treat annotations as code. When the handler changes, update annotations. Consider integration tests that compare responses to documented schemas.

### 6. Swagger UI Not Available in Production

**Problem:** `/swagger` returns 404 in production.

**Cause:** Swagger disabled when `TINA4_DEBUG=false`.

**Fix:** Set `TINA4_SWAGGER=true` in `.env` for staging servers. Be aware that public documentation reveals implementation details.

### 7. SDK Generation Produces Incorrect Types

**Problem:** Generated TypeScript client has `any` types.

**Cause:** Annotations use generic strings instead of typed schemas.

**Fix:** Use correct OpenAPI type format: `"name": "string"` (lowercase), `"price": "number"`, `"in_stock": "boolean"`, `"tags": ["string"]` (array of strings).
