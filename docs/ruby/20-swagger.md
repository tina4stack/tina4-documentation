# Chapter 20: API Documentation with Swagger

## 1. The 47-Endpoint Problem

Your team has 47 API endpoints. The frontend developer keeps asking "what does this endpoint accept?" You email a spreadsheet. It goes stale. You write a wiki page. Nobody touches it. You add comments to the code. Nobody reads them.

Swagger (OpenAPI) solves this for good. It generates interactive API documentation from annotations in your route files. The docs stay current because they live in the code. Your frontend developer browses every endpoint, sees expected request and response formats, and tests endpoints from the browser.

Tina4 auto-generates a Swagger UI at `/swagger` from comment annotations on your routes. No build step. No extra tooling. Write the annotations. The documentation appears.

---

## 2. What Swagger/OpenAPI Is

OpenAPI is a specification format for describing REST APIs. Swagger is the toolset that reads OpenAPI specs and generates documentation, client SDKs, and server stubs.

An OpenAPI spec describes:

- Every endpoint (path + HTTP method)
- What parameters each endpoint accepts (path, query, header, body)
- What each endpoint returns (response codes, response bodies)
- Data schemas (what a "User" or "Product" object looks like)
- Authentication requirements
- Grouping and tagging

Tina4 builds this spec automatically from comment annotations in your Ruby code. You never write JSON or YAML by hand.

---

## 3. Enabling Swagger

Swagger is available out of the box when `TINA4_DEBUG=true`. Navigate to:

```
http://localhost:7147/swagger
```

You should see the Swagger UI with any routes you have already defined. If you have not added any Swagger annotations yet, you will see the routes listed with default descriptions.

For production, you can explicitly enable or disable Swagger:

```bash
TINA4_SWAGGER=true
```

### The Swagger JSON Endpoint

The raw OpenAPI spec is available at:

```
http://localhost:7147/swagger/json
```

```bash
curl http://localhost:7147/swagger/json
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

---

## 4. Adding Descriptions to Routes

Add Swagger annotations as comments above your route definitions:

```ruby
# List all products
# @description Returns a paginated list of all products in the catalog
# @tags Products
Tina4::Router.get("/api/products") do |request, response|
  response.json({ products: [] })
end
```

The first comment line becomes the `summary`. The `@description` tag provides a longer explanation.

### Documenting Path Parameters

```ruby
# Get a product by ID
# @description Returns a single product with full details including inventory status
# @tags Products
# @param int $id The unique product identifier
Tina4::Router.get("/api/products/{id:int}") do |request, response|
  id = request.params["id"]
  response.json({ id: id, name: "Wireless Keyboard", price: 79.99 })
end
```

### Documenting Query Parameters

```ruby
# Search products
# @description Search the product catalog by name, category, or price range
# @tags Products
# @query string $q Search query (searches product name and description)
# @query string $category Filter by category name
# @query float $min_price Minimum price filter
# @query float $max_price Maximum price filter
# @query int $page Page number (default: 1)
# @query int $limit Items per page (default: 20, max: 100)
Tina4::Router.get("/api/products/search") do |request, response|
  q = request.params["q"] || ""
  page = (request.params["page"] || 1).to_i
  limit = [(request.params["limit"] || 20).to_i, 100].min

  response.json({
    query: q,
    page: page,
    limit: limit,
    results: [],
    total: 0
  })
end
```

---

## 5. Documenting Request and Response Schemas

### Request Body

```ruby
# Create a new product
# @description Creates a product in the catalog. Requires admin authentication.
# @tags Products
# @body {"name": "string", "category": "string", "price": "float", "in_stock": "bool", "description": "string"}
# @response 201 {"id": "int", "name": "string", "category": "string", "price": "float", "in_stock": "bool", "created_at": "string"}
# @response 400 {"error": "string"}
Tina4::Router.post("/api/products") do |request, response|
  body = request.body

  if body["name"].nil? || body["name"].empty?
    return response.json({ error: "Name is required" }, 400)
  end

  response.json({
    id: 1,
    name: body["name"],
    category: body["category"] || "Uncategorized",
    price: (body["price"] || 0).to_f,
    in_stock: body["in_stock"] != false,
    created_at: Time.now.iso8601
  }, 201)
end
```

---

## 6. Tags for Grouping Endpoints

Tags group related endpoints in the Swagger UI:

```ruby
# List all users
# @tags Users
Tina4::Router.get("/api/users") do |request, response|
  response.json({ users: [] })
end

# List all orders
# @tags Orders
Tina4::Router.get("/api/orders") do |request, response|
  response.json({ orders: [] })
end
```

In the Swagger UI, you will see sections for "Users" and "Orders". An endpoint can belong to multiple groups:

```ruby
# Get user's orders
# @tags Users, Orders
Tina4::Router.get("/api/users/{id:int}/orders") do |request, response|
  response.json({ orders: [] })
end
```

---

## 7. Example Values

Add example values to make the docs more useful:

```ruby
# Create a new product
# @description Creates a product in the catalog
# @tags Products
# @example request {"name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99, "in_stock": true}
# @example response {"id": 42, "name": "Ergonomic Keyboard", "category": "Electronics", "price": 89.99, "in_stock": true, "created_at": "2026-03-22T14:30:00+00:00"}
Tina4::Router.post("/api/products") do |request, response|
  body = request.body

  response.json({
    id: 42,
    name: body["name"],
    category: body["category"] || "Uncategorized",
    price: (body["price"] || 0).to_f,
    in_stock: body["in_stock"] != false,
    created_at: Time.now.iso8601
  }, 201)
end
```

---

## 8. Try-It-Out from the Swagger UI

The Swagger UI includes a "Try it out" button on every endpoint. Clicking it:

1. Expands the endpoint with editable input fields
2. Pre-fills example values (if provided)
3. Lets you edit the parameters, headers, and request body
4. Sends the actual HTTP request to your running server
5. Shows the response status, headers, and body

This is a live testing tool built into your documentation.

### Authentication in Try-It-Out

If your endpoints require authentication, click the "Authorize" button at the top of the Swagger UI. Enter your JWT token or API key, and all subsequent "Try it out" requests will include the authentication header.

---

## 9. Customizing the Swagger Info Block

Configure the top-level API information in `.env`:

```bash
TINA4_SWAGGER_TITLE=My Store API
TINA4_SWAGGER_DESCRIPTION=API for managing products, orders, and users
TINA4_SWAGGER_VERSION=1.0.0
TINA4_SWAGGER_CONTACT_EMAIL=api@mystore.com
TINA4_SWAGGER_LICENSE=MIT
```

---

## 10. Generating Client SDKs from the Spec

The OpenAPI spec at `/swagger/json` can be used with code generation tools:

```bash
# Install the OpenAPI Generator CLI
npm install -g @openapitools/openapi-generator-cli

# Generate a TypeScript client
openapi-generator-cli generate \
  -i http://localhost:7147/swagger/json \
  -g typescript-fetch \
  -o ./frontend/api-client
```

---

## 11. A Complete Documented API

Here is a full example showing all the annotation features together:

```ruby
# List all users
# @description Returns a paginated list of users. Supports filtering by role and searching by name.
# @tags Users
# @query int $page Page number (default: 1)
# @query int $limit Items per page (default: 20)
# @query string $role Filter by role (admin, user, moderator)
# @query string $search Search by name or email
# @response 200 {"users": [{"id": "int", "name": "string", "email": "string", "role": "string"}], "total": "int", "page": "int", "pages": "int"}
# @example response {"users": [{"id": 1, "name": "Alice", "email": "alice@example.com", "role": "admin"}], "total": 42, "page": 1, "pages": 3}
Tina4::Router.get("/api/users") do |request, response|
  page = (request.params["page"] || 1).to_i
  limit = (request.params["limit"] || 20).to_i

  response.json({
    users: [
      { id: 1, name: "Alice", email: "alice@example.com", role: "admin" },
      { id: 2, name: "Bob", email: "bob@example.com", role: "user" }
    ],
    total: 42,
    page: page,
    pages: (42.0 / limit).ceil
  })
end

# Create a new user
# @description Creates a user account. Email must be unique.
# @tags Users
# @body {"name": "string", "email": "string", "password": "string", "role": "string"}
# @response 201 {"id": "int", "name": "string", "email": "string", "role": "string", "created_at": "string"}
# @response 400 {"errors": ["string"]}
# @response 409 {"error": "string"}
# @example request {"name": "Charlie", "email": "charlie@example.com", "password": "securePass123", "role": "user"}
# @example response {"id": 3, "name": "Charlie", "email": "charlie@example.com", "role": "user", "created_at": "2026-03-22T14:30:00+00:00"}
Tina4::Router.post("/api/users") do |request, response|
  body = request.body

  errors = []
  errors << "Name is required" if body["name"].nil? || body["name"].empty?
  errors << "Email is required" if body["email"].nil? || body["email"].empty?
  errors << "Password is required" if body["password"].nil? || body["password"].empty?

  unless errors.empty?
    return response.json({ errors: errors }, 400)
  end

  response.json({
    id: 3,
    name: body["name"],
    email: body["email"],
    role: body["role"] || "user",
    created_at: Time.now.iso8601
  }, 201)
end
```

---

## 12. Exercise: Document a Complete User API

Take the User API from the example above and extend it with the following endpoints. Write full Swagger annotations for each one.

### Requirements

Document these additional endpoints (you can use hardcoded data in the handlers):

| Method | Path | Description |
|--------|------|-------------|
| `PUT` | `/api/users/{id}` | Update a user. Body: name, email, role. Response: updated user. |
| `GET` | `/api/users/{id}/orders` | List a user's orders. Query: status filter, pagination. |
| `POST` | `/api/users/{id}/avatar` | Upload user avatar. Body: avatar_url string. |

Each endpoint should have:

1. A summary (first comment line)
2. A `@description`
3. A `@tags` annotation
4. `@param` for path parameters
5. `@query` for query parameters (where applicable)
6. `@body` for request body (where applicable)
7. `@response` for each possible response code
8. `@example` for request and response (where applicable)

### Test by visiting:

```
http://localhost:7147/swagger
```

---

## 13. Solution

Create `src/routes/user_api_documented.rb`:

```ruby
# Update a user
# @description Updates an existing user's profile information. Only provided fields are updated.
# @tags Users
# @param int $id User ID
# @body {"name": "string", "email": "string", "role": "string"}
# @response 200 {"id": "int", "name": "string", "email": "string", "role": "string", "updated_at": "string"}
# @response 404 {"error": "string"}
# @example request {"name": "Alice Smith", "email": "alice.smith@example.com", "role": "admin"}
# @example response {"id": 1, "name": "Alice Smith", "email": "alice.smith@example.com", "role": "admin", "updated_at": "2026-03-22T14:30:00+00:00"}
Tina4::Router.put("/api/users/{id:int}") do |request, response|
  id = request.params["id"]
  body = request.body

  if id > 100
    return response.json({ error: "User not found" }, 404)
  end

  response.json({
    id: id,
    name: body["name"] || "Alice",
    email: body["email"] || "alice@example.com",
    role: body["role"] || "user",
    updated_at: Time.now.iso8601
  })
end

# List user orders
# @description Returns a paginated list of orders for a specific user.
# @tags Users, Orders
# @param int $id User ID
# @query string $status Filter by order status (pending, processing, shipped, delivered, cancelled)
# @query int $page Page number (default: 1)
# @query int $limit Items per page (default: 20)
# @response 200 {"orders": [{"id": "int", "product": "string", "quantity": "int", "total": "float", "status": "string"}], "total": "int", "page": "int"}
# @response 404 {"error": "string"}
# @example response {"orders": [{"id": 101, "product": "Wireless Keyboard", "quantity": 2, "total": 159.98, "status": "shipped"}], "total": 5, "page": 1}
Tina4::Router.get("/api/users/{id:int}/orders") do |request, response|
  id = request.params["id"]
  status = request.params["status"]
  page = (request.params["page"] || 1).to_i

  if id > 100
    return response.json({ error: "User not found" }, 404)
  end

  orders = [
    { id: 101, product: "Wireless Keyboard", quantity: 2, total: 159.98, status: "shipped" },
    { id: 102, product: "USB-C Hub", quantity: 1, total: 49.99, status: "delivered" }
  ]

  orders = orders.select { |o| o[:status] == status } if status

  response.json({ orders: orders, total: orders.length, page: page })
end

# Upload user avatar
# @description Sets or updates the avatar URL for a user.
# @tags Users
# @param int $id User ID
# @body {"avatar_url": "string"}
# @response 200 {"id": "int", "avatar_url": "string", "updated_at": "string"}
# @response 400 {"error": "string"}
# @response 404 {"error": "string"}
# @example request {"avatar_url": "https://cdn.example.com/avatars/alice-2026.jpg"}
# @example response {"id": 1, "avatar_url": "https://cdn.example.com/avatars/alice-2026.jpg", "updated_at": "2026-03-22T14:30:00+00:00"}
Tina4::Router.post("/api/users/{id:int}/avatar") do |request, response|
  id = request.params["id"]
  body = request.body

  if id > 100
    return response.json({ error: "User not found" }, 404)
  end

  if body["avatar_url"].nil? || body["avatar_url"].empty?
    return response.json({ error: "avatar_url is required" }, 400)
  end

  response.json({
    id: id,
    avatar_url: body["avatar_url"],
    updated_at: Time.now.iso8601
  })
end
```

---

## 14. Gotchas

### 1. Annotations Must Be Directly Above the Route

**Problem:** Your Swagger annotations do not appear in the docs.

**Cause:** There is a blank line or other code between the comment block and the `Tina4::Router` call.

**Fix:** Make sure the comments are on the lines directly before the route definition with no blank lines in between.

### 2. Missing @tags Makes Endpoints Hard to Find

**Problem:** All endpoints appear in one giant flat list in the Swagger UI.

**Fix:** Add `# @tags ResourceName` to every route comment block.

### 3. @body Must Be Valid JSON

**Problem:** The Swagger UI shows the body schema as empty or broken.

**Fix:** Validate your `@body` JSON. Every key and string value must be in double quotes.

### 4. Swagger Shows Routes You Did Not Annotate

**Problem:** Unannotated routes appear in the Swagger UI with minimal documentation.

**Cause:** Tina4 includes all registered routes in the Swagger spec. Add `# @hidden` to hide a route.

### 5. Response Examples Do Not Match Actual Responses

**Problem:** The example response in Swagger shows different fields than the actual API response.

**Fix:** Treat annotations as part of the code. When you change a handler's response format, update the annotations.

### 6. Swagger UI Not Available in Production

**Problem:** `/swagger` returns a 404 in production.

**Fix:** If you want Swagger in production, explicitly set `TINA4_SWAGGER=true` in your `.env`.

### 7. SDK Generation Produces Incorrect Types

**Problem:** The generated TypeScript client has `any` types instead of proper interfaces.

**Fix:** Use correct OpenAPI type format in your annotations: `"name": "string"` (lowercase), `"price": "number"`, `"in_stock": "boolean"`.
