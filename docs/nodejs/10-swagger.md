# Chapter 10: API Documentation with Swagger

## 1. The 47-Endpoint Problem

Your team has 47 API endpoints. The frontend developer asks "what does this endpoint accept?" again. And again.

Swagger kills that question. It generates interactive API documentation from annotations in your route files. The docs stay current because they live in the code.

Tina4 builds a Swagger UI at `/swagger` from doc-block annotations on your routes. No build step. No extra tooling.

---

## 2. What Swagger/OpenAPI Is

OpenAPI is a specification format for describing REST APIs. Swagger is the toolset that reads OpenAPI specs and renders documentation. Tina4 builds the spec from JSDoc comments in your TypeScript code. No manual spec writing.

---

## 3. Enabling Swagger

Swagger runs when `TINA4_DEBUG=true`. Navigate to:

```
http://localhost:7148/swagger
```

The raw spec is at:

```
http://localhost:7148/swagger/json
```

For production:

```env
TINA4_SWAGGER=true
```

---

## 4. Adding Descriptions to Routes

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

/**
 * Get a product by ID
 * @description Returns a single product with full details
 * @tags Products
 * @param int id The unique product identifier
 */
Router.get("/api/products/{id:int}", async (req, res) => {
    return res.json({ id: req.params.id, name: "Wireless Keyboard", price: 79.99 });
});

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

---

## 5. Documenting Request and Response Schemas

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
        price: parseFloat(req.body.price ?? 0)
    });
});
```

---

## 6. Tags for Grouping

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

---

## 7. Example Values

```typescript
/**
 * Create a new product
 * @tags Products
 * @example request {"name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99}
 * @example response {"id": 42, "name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99}
 */
Router.post("/api/products", async (req, res) => {
    return res.status(201).json({ id: 42, name: req.body.name, price: req.body.price });
});
```

---

## 8. Try-It-Out from the Swagger UI

The Swagger UI puts a "Try it out" button on every endpoint. Click it and the UI sends a real HTTP request to your running server. Live testing without curl.

---

## 9. Customizing the Swagger Info Block

```env
TINA4_SWAGGER_TITLE=My Store API
TINA4_SWAGGER_DESCRIPTION=API for managing products, orders, and users
TINA4_SWAGGER_VERSION=1.0.0
TINA4_SWAGGER_CONTACT_EMAIL=api@mystore.com
TINA4_SWAGGER_LICENSE=MIT
```

---

## 10. Generating Client SDKs

```bash
npm install -g @openapitools/openapi-generator-cli

openapi-generator-cli generate \
  -i http://localhost:7148/swagger/json \
  -g typescript-fetch \
  -o ./frontend/api-client
```

---

## 11. Exercise: Document a Complete User API

Document PUT, GET user orders, and POST avatar endpoints with full Swagger annotations including `@param`, `@query`, `@body`, `@response`, and `@example`.

---

## 12. Solution

```typescript
import { Router } from "tina4-nodejs";

/**
 * Update a user
 * @description Updates an existing user's profile information
 * @tags Users
 * @param int id User ID
 * @body {"name": "string", "email": "string", "role": "string"}
 * @response 200 {"id": "int", "name": "string", "email": "string", "role": "string", "updated_at": "string"}
 * @response 404 {"error": "string"}
 * @example request {"name": "Alice Smith", "email": "alice.smith@example.com"}
 * @example response {"id": 1, "name": "Alice Smith", "email": "alice.smith@example.com", "role": "admin", "updated_at": "2026-03-22T14:30:00+00:00"}
 */
Router.put("/api/users/{id:int}", async (req, res) => {
    return res.json({ id: req.params.id, name: req.body.name ?? "Alice", updated_at: new Date().toISOString() });
});

/**
 * List user orders
 * @description Returns a paginated list of orders for a specific user
 * @tags Users, Orders
 * @param int id User ID
 * @query string status Filter by order status
 * @query int page Page number (default: 1)
 * @response 200 {"orders": [{"id": "int", "product": "string", "total": "float", "status": "string"}], "total": "int"}
 * @response 404 {"error": "string"}
 */
Router.get("/api/users/{id:int}/orders", async (req, res) => {
    return res.json({ orders: [], total: 0, page: parseInt(req.query.page ?? "1", 10) });
});

/**
 * Upload user avatar
 * @description Sets or updates the avatar URL for a user
 * @tags Users
 * @param int id User ID
 * @body {"avatar_url": "string"}
 * @response 200 {"id": "int", "avatar_url": "string", "updated_at": "string"}
 * @response 400 {"error": "string"}
 * @example request {"avatar_url": "https://cdn.example.com/avatars/alice.jpg"}
 */
Router.post("/api/users/{id:int}/avatar", async (req, res) => {
    if (!req.body.avatar_url) {
        return res.status(400).json({ error: "avatar_url is required" });
    }
    return res.json({ id: req.params.id, avatar_url: req.body.avatar_url, updated_at: new Date().toISOString() });
});
```

---

## 13. Gotchas

### 1. Annotations Must Be Directly Above the Route

**Fix:** Make sure the `*/` closing is on the line directly before `Router.get(...)`.

### 2. Missing @tags Makes Endpoints Hard to Find

**Fix:** Add `@tags ResourceName` to every route doc-block.

### 3. @body Must Be Valid JSON

**Fix:** Every key and string value must be in double quotes.

### 4. Swagger Shows Routes You Did Not Annotate

**Fix:** By design. Add `@hidden` to hide a route from Swagger.

### 5. Response Examples Do Not Match Actual Responses

**Fix:** Update annotations when you change handler response format.

### 6. Swagger UI Not Available in Production

**Fix:** Set `TINA4_SWAGGER=true` explicitly in `.env`.

### 7. SDK Generation Produces Incorrect Types

**Fix:** Use correct OpenAPI types: `"string"`, `"number"`, `"boolean"`.
