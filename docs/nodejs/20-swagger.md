# Chapter 20: API Documentation with Swagger

## 1. The 47-Endpoint Problem

Your team builds 47 API endpoints. The frontend developer asks "what does this endpoint accept?" Again. And again.

Swagger kills that question. It generates interactive API documentation from annotations in your route files. The docs stay current because they live in the code. Change a handler. The documentation changes with it.

Tina4 builds a Swagger UI at `/swagger` from JSDoc comments on your routes. No build step. No extra tooling. No separate spec file to maintain.

---

## 2. What Swagger/OpenAPI Is

OpenAPI is a specification format for describing REST APIs. Swagger is the toolset that reads OpenAPI specs and renders interactive documentation. Tina4 scans your route files, reads JSDoc annotations, and builds the OpenAPI spec automatically. No manual spec writing.

The generated spec is standard OpenAPI 3.0. It works with every tool in the OpenAPI ecosystem: client SDK generators, testing tools, API gateways, and monitoring services.

---

## 3. Enabling Swagger

Swagger runs when `TINA4_DEBUG=true`. Navigate to:

```
http://localhost:7148/swagger
```

The interactive UI loads. Every annotated route appears. Click any endpoint to see its documentation. Click "Try it out" to send a real request.

The raw OpenAPI JSON spec lives at:

```
http://localhost:7148/swagger/json
```

### Swagger in Production

By default, Swagger only shows in debug mode. To expose it in production:

```env
TINA4_SWAGGER=true
```

This enables the Swagger UI even when `TINA4_DEBUG=false`. Useful for developer portals and partner integrations.

---

## 4. Adding Descriptions to Routes

Every JSDoc annotation starts with a summary line. The `@description` tag adds detail:

```typescript
import { Router } from "tina4-nodejs";

/**
 * List all products
 * @description Returns a paginated list of all products in the catalog
 * @tags Products
 */
Router.get("/api/products", async (req, res) => {
    return res.json({ products: [] });
});
```

The first line ("List all products") becomes the endpoint summary in Swagger. The `@description` text appears when a user expands the endpoint.

### Path Parameters

Use `@param` to document path parameters:

```typescript
/**
 * Get a product by ID
 * @description Returns a single product with full details
 * @tags Products
 * @param int id The unique product identifier
 */
Router.get("/api/products/{id:int}", async (req, res) => {
    return res.json({ id: req.params.id, name: "Wireless Keyboard", price: 79.99 });
});
```

### Query Parameters

Use `@query` to document query string parameters:

```typescript
/**
 * Search products
 * @description Search the product catalog by name or category
 * @tags Products
 * @query string q Search query
 * @query string category Filter by category
 * @query int page Page number (default: 1)
 * @query int limit Items per page (default: 20)
 */
Router.get("/api/products/search", async (req, res) => {
    return res.json({ query: req.query.q, results: [], total: 0 });
});
```

Each `@query` tag specifies the type, name, and description. Swagger renders these as a form in the "Try it out" view.

---

## 5. Documenting Request Bodies

Use `@body` to describe what the endpoint accepts:

```typescript
/**
 * Create a new product
 * @description Creates a product in the catalog
 * @tags Products
 * @body {"name": "string", "category": "string", "price": "float", "inStock": "bool"}
 * @response 201 {"id": "int", "name": "string", "category": "string", "price": "float"}
 * @response 400 {"error": "string"}
 */
Router.post("/api/products", async (req, res) => {
    if (!req.body.name) {
        return res.status(400).json({ error: "Name is required" });
    }
    return res.status(201).json({
        id: 1,
        name: req.body.name,
        category: req.body.category ?? "Uncategorized",
        price: parseFloat(req.body.price ?? 0),
    });
});
```

The `@body` tag defines the JSON schema. Keys are field names. Values are type strings. Swagger renders this as a schema in the request body section.

### Supported Types in @body and @response

| Type String | OpenAPI Type |
|-------------|-------------|
| `"string"` | string |
| `"int"` | integer |
| `"float"` | number (float) |
| `"number"` | number |
| `"bool"` | boolean |
| `"object"` | object |
| `"array"` | array |

---

## 6. Documenting Responses

Use `@response` to describe each possible response:

```typescript
/**
 * Update a product
 * @tags Products
 * @param int id Product ID
 * @body {"name": "string", "price": "float"}
 * @response 200 {"id": "int", "name": "string", "price": "float", "updatedAt": "string"}
 * @response 404 {"error": "string"}
 * @response 400 {"error": "string"}
 */
Router.put("/api/products/{id:int}", async (req, res) => {
    // ...
});
```

Each `@response` tag starts with the status code, followed by the JSON schema. Document every status code your endpoint can return. The frontend developer sees exactly what to expect for success and failure.

---

## 7. Tags for Grouping

Tags organize endpoints into sections in the Swagger UI:

```typescript
/**
 * List all users
 * @tags Users
 */
Router.get("/api/users", async (req, res) => {
    return res.json({ users: [] });
});

/**
 * List all orders
 * @tags Orders
 */
Router.get("/api/orders", async (req, res) => {
    return res.json({ orders: [] });
});
```

All endpoints with `@tags Users` appear under the "Users" heading in Swagger. An endpoint can belong to multiple tags:

```typescript
/**
 * List user orders
 * @tags Users, Orders
 */
```

Without tags, endpoints land in a "default" group. Always add tags. They make the documentation navigable.

---

## 8. Example Values

Static schemas tell the developer what type each field is. Examples show what real data looks like:

```typescript
/**
 * Create a product
 * @tags Products
 * @body {"name": "string", "category": "string", "price": "float"}
 * @example request {"name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99}
 * @example response {"id": 42, "name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99}
 */
Router.post("/api/products", async (req, res) => {
    return res.status(201).json({ id: 42, name: req.body.name, price: req.body.price });
});
```

`@example request` pre-fills the request body in "Try it out." The developer clicks the button and the form already has realistic data. No manual typing.

`@example response` shows what a successful response looks like. The Swagger UI displays it in the response section.

---

## 9. Authentication in Swagger

### Public and Secured Routes

Mark routes as public or secured with `@noauth` and `@secured`:

```typescript
/**
 * Login
 * @noauth
 * @tags Auth
 * @body {"email": "string", "password": "string"}
 * @response 200 {"token": "string"}
 */
Router.post("/api/auth/login", async (req, res) => {
    // ...
});

/**
 * Get user profile
 * @secured
 * @tags Users
 * @response 200 {"id": "int", "name": "string", "email": "string"}
 * @response 401 {"error": "string"}
 */
Router.get("/api/profile", async (req, res) => {
    // ...
}, [authMiddleware]);
```

`@noauth` tells Swagger this endpoint does not require authentication. `@secured` adds a lock icon and includes the Authorization header in the spec.

### Authorize Button

The Swagger UI has an "Authorize" button at the top. Click it. Paste your JWT token. All subsequent "Try it out" requests include the `Authorization: Bearer <token>` header automatically.

### Workflow

1. Call the login endpoint in Swagger -- get a token in the response
2. Click the "Authorize" button at the top
3. Paste the token value
4. All secured endpoints now send the token with every request

No curl. No Postman. Test the full auth flow from the browser.

---

## 10. Try-It-Out from the Swagger UI

The Swagger UI puts a "Try it out" button on every endpoint. Click it. The UI expands the endpoint into a form. Fill in path parameters, query parameters, and the request body. Click "Execute." The UI sends a real HTTP request to your running server and displays the response.

The response panel shows:

- The HTTP status code
- Response headers
- The response body (formatted JSON)
- The curl command equivalent

This replaces curl for development testing. See the request. See the response. Adjust and try again. All in the browser.

---

## 11. A Complete Documented API

Here is a full product API with complete Swagger annotations:

```typescript
import { Router } from "tina4-nodejs";

/**
 * List all products
 * @description Returns a paginated list of products. Supports filtering by category and sorting.
 * @tags Products
 * @query string category Filter by category name
 * @query string sort Sort field (name, price, created_at)
 * @query string order Sort direction (ASC or DESC)
 * @query int page Page number (default: 1)
 * @query int limit Items per page (default: 20)
 * @response 200 {"products": [{"id": "int", "name": "string", "category": "string", "price": "float"}], "page": "int", "total": "int"}
 * @example response {"products": [{"id": 1, "name": "Keyboard", "category": "Electronics", "price": 79.99}], "page": 1, "total": 42}
 */
Router.get("/api/products", async (req, res) => {
    // implementation
});

/**
 * Get a product by ID
 * @description Returns full product details including category and stock status
 * @tags Products
 * @param int id Product ID
 * @response 200 {"id": "int", "name": "string", "category": "string", "price": "float", "inStock": "bool", "createdAt": "string"}
 * @response 404 {"error": "string"}
 * @example response {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "inStock": true, "createdAt": "2026-03-22T14:30:00Z"}
 */
Router.get("/api/products/{id:int}", async (req, res) => {
    // implementation
});

/**
 * Create a product
 * @description Adds a new product to the catalog
 * @secured
 * @tags Products
 * @body {"name": "string", "category": "string", "price": "float", "inStock": "bool"}
 * @response 201 {"id": "int", "name": "string", "category": "string", "price": "float"}
 * @response 400 {"error": "string"}
 * @response 401 {"error": "string"}
 * @example request {"name": "Ergonomic Mouse", "category": "Electronics", "price": 49.99, "inStock": true}
 * @example response {"id": 42, "name": "Ergonomic Mouse", "category": "Electronics", "price": 49.99}
 */
Router.post("/api/products", async (req, res) => {
    // implementation
}, [authMiddleware]);

/**
 * Update a product
 * @description Updates an existing product. Only include fields you want to change.
 * @secured
 * @tags Products
 * @param int id Product ID
 * @body {"name": "string", "category": "string", "price": "float", "inStock": "bool"}
 * @response 200 {"id": "int", "name": "string", "category": "string", "price": "float"}
 * @response 404 {"error": "string"}
 * @response 401 {"error": "string"}
 * @example request {"price": 69.99}
 * @example response {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 69.99}
 */
Router.put("/api/products/{id:int}", async (req, res) => {
    // implementation
}, [authMiddleware]);

/**
 * Delete a product
 * @description Removes a product from the catalog
 * @secured
 * @tags Products
 * @param int id Product ID
 * @response 204
 * @response 404 {"error": "string"}
 * @response 401 {"error": "string"}
 */
Router.delete("/api/products/{id:int}", async (req, res) => {
    // implementation
}, [authMiddleware]);
```

---

## 12. Hiding Routes

Use `@hidden` to exclude a route from Swagger:

```typescript
/**
 * Internal health check
 * @hidden
 */
Router.get("/internal/ping", async (req, res) => {
    return res.json({ pong: true });
});
```

The route still works. It does not appear in the Swagger UI or the JSON spec.

---

## 13. Customizing the Swagger Info Block

Configure the API metadata through `.env`:

```env
TINA4_SWAGGER_TITLE=My Store API
TINA4_SWAGGER_DESCRIPTION=API for managing products, orders, and users
TINA4_SWAGGER_VERSION=1.0.0
TINA4_SWAGGER_CONTACT_EMAIL=api@mystore.com
TINA4_SWAGGER_LICENSE=MIT
```

These values appear in the header of the Swagger UI. Set them once. Every endpoint inherits the context.

---

## 14. Generating Client SDKs

The OpenAPI spec at `/swagger/json` feeds into code generators. Generate a typed API client for your frontend:

```bash
npm install -g @openapitools/openapi-generator-cli

openapi-generator-cli generate \
  -i http://localhost:7148/swagger/json \
  -g typescript-fetch \
  -o ./frontend/api-client
```

This produces a fully typed TypeScript client. Every endpoint becomes a method. Every request body and response has type definitions. The frontend developer gets autocompletion and type checking from your Swagger annotations.

### Available Generators

| Generator | Output |
|-----------|--------|
| `typescript-fetch` | TypeScript with Fetch API |
| `typescript-axios` | TypeScript with Axios |
| `javascript` | Plain JavaScript |
| `python` | Python client |
| `java` | Java client |
| `swift5` | iOS Swift client |
| `kotlin` | Android Kotlin client |
| `csharp` | C# .NET client |

One spec. Any language. The API documentation becomes a contract between your backend and every frontend that consumes it.

---

## 15. Auto-CRUD Routes in Swagger

Models with `static autoCrud = true` generate Swagger documentation automatically. The generated routes include:

- Summary and description
- Path parameters
- Query parameters for the list endpoint (page, limit, sort, order, filters)
- Request body schema from the model's `fields` definition
- Response schemas

No JSDoc annotations needed for auto-CRUD routes. The ORM model definition drives the documentation.

---

## 16. Exercise: Document a Complete User API

Document a User API with the following endpoints. Include full Swagger annotations: `@param`, `@query`, `@body`, `@response`, `@example`, `@tags`, and `@secured` where appropriate.

### Requirements

1. `PUT /api/users/{id}` -- Update user profile
2. `GET /api/users/{id}/orders` -- List a user's orders (with status filter and pagination)
3. `POST /api/users/{id}/avatar` -- Upload a user avatar URL

---

## 17. Solution

```typescript
import { Router } from "tina4-nodejs";

/**
 * Update a user
 * @description Updates an existing user's profile information. Only send fields you want to change.
 * @secured
 * @tags Users
 * @param int id User ID
 * @body {"name": "string", "email": "string", "role": "string"}
 * @response 200 {"id": "int", "name": "string", "email": "string", "role": "string", "updatedAt": "string"}
 * @response 404 {"error": "string"}
 * @response 401 {"error": "string"}
 * @example request {"name": "Alice Smith", "email": "alice.smith@example.com"}
 * @example response {"id": 1, "name": "Alice Smith", "email": "alice.smith@example.com", "role": "admin", "updatedAt": "2026-03-22T14:30:00Z"}
 */
Router.put("/api/users/{id:int}", async (req, res) => {
    return res.json({ id: req.params.id, name: req.body.name ?? "Alice", updatedAt: new Date().toISOString() });
});

/**
 * List user orders
 * @description Returns a paginated list of orders for a specific user. Filter by status to see pending, shipped, or delivered orders.
 * @secured
 * @tags Users, Orders
 * @param int id User ID
 * @query string status Filter by order status (pending, shipped, delivered)
 * @query int page Page number (default: 1)
 * @query int limit Items per page (default: 20)
 * @response 200 {"orders": [{"id": "int", "product": "string", "total": "float", "status": "string"}], "total": "int", "page": "int"}
 * @response 404 {"error": "string"}
 * @example response {"orders": [{"id": 101, "product": "Wireless Keyboard", "total": 79.99, "status": "shipped"}], "total": 1, "page": 1}
 */
Router.get("/api/users/{id:int}/orders", async (req, res) => {
    return res.json({ orders: [], total: 0, page: parseInt(req.query.page ?? "1", 10) });
});

/**
 * Upload user avatar
 * @description Sets or updates the avatar URL for a user. The URL must point to an accessible image.
 * @secured
 * @tags Users
 * @param int id User ID
 * @body {"avatarUrl": "string"}
 * @response 200 {"id": "int", "avatarUrl": "string", "updatedAt": "string"}
 * @response 400 {"error": "string"}
 * @response 404 {"error": "string"}
 * @example request {"avatarUrl": "https://cdn.example.com/avatars/alice.jpg"}
 * @example response {"id": 1, "avatarUrl": "https://cdn.example.com/avatars/alice.jpg", "updatedAt": "2026-03-22T14:30:00Z"}
 */
Router.post("/api/users/{id:int}/avatar", async (req, res) => {
    if (!req.body.avatarUrl) {
        return res.status(400).json({ error: "avatarUrl is required" });
    }
    return res.json({ id: req.params.id, avatarUrl: req.body.avatarUrl, updatedAt: new Date().toISOString() });
});
```

---

## 18. Gotchas

### 1. Annotations Must Be Directly Above the Route

**Problem:** Swagger does not pick up your annotations.

**Cause:** A blank line or other code sits between the JSDoc comment and the `Router.get(...)` call.

**Fix:** The `*/` closing must be on the line directly before the Router call. No blank lines between them.

### 2. Missing @tags Makes Endpoints Hard to Find

**Problem:** All endpoints land in a "default" group in the Swagger UI.

**Fix:** Add `@tags ResourceName` to every route doc-block. Group related endpoints together.

### 3. @body Must Be Valid JSON

**Problem:** Swagger shows an error parsing the body schema.

**Fix:** Every key and string value must be in double quotes. `{"name": "string"}` works. `{name: string}` fails.

### 4. Swagger Shows Routes You Did Not Annotate

**Problem:** Un-annotated routes appear in Swagger with no documentation.

**Fix:** By design -- Tina4 shows all registered routes. Add `@hidden` to hide a route from Swagger.

### 5. Response Examples Do Not Match Actual Responses

**Problem:** The Swagger example shows one format but the actual response has different fields.

**Fix:** Update annotations when you change the handler's response format. Examples are static text in your source code. They do not update automatically.

### 6. Swagger UI Not Available in Production

**Problem:** Navigating to `/swagger` returns a 404 in production.

**Fix:** Set `TINA4_SWAGGER=true` in `.env` to enable Swagger in production. Without it, Swagger only runs when `TINA4_DEBUG=true`.

### 7. SDK Generation Produces Incorrect Types

**Problem:** The generated TypeScript client has `any` types instead of proper types.

**Fix:** Use correct OpenAPI type strings in your annotations: `"string"`, `"int"`, `"float"`, `"bool"`. Avoid using TypeScript type syntax -- Swagger annotations use their own type vocabulary.

### 8. @secured Routes Not Sending Auth Token

**Problem:** "Try it out" sends requests without the Authorization header even though the route is marked `@secured`.

**Fix:** Click the "Authorize" button at the top of the Swagger UI. Paste your JWT token. All subsequent requests include the header. The token persists until you close the tab or click "Logout."
