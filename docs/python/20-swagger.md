# Chapter 20: Swagger / OpenAPI

## 1. The 47-Endpoint Problem

Your team ships 47 API endpoints. The frontend developer asks what each one accepts. You email a spreadsheet. It rots. You write a wiki page. Nobody updates it. You add comments to the code. Nobody reads them.

Swagger kills this problem for good. It generates interactive API documentation from decorators on your route files. The docs stay current because they live inside the code itself. Your frontend developer browses every endpoint, sees expected request and response formats, and tests endpoints from the browser.

Tina4 Python auto-generates a Swagger UI at `/swagger` from your route decorators. No build step. No extra tooling. Write the decorators. The documentation appears.

---

## 2. What Swagger/OpenAPI Is

OpenAPI is a specification for describing REST APIs. Swagger is the toolset that reads OpenAPI specs and produces documentation, client SDKs, and server stubs.

An OpenAPI spec describes:

- Every endpoint (path + HTTP method)
- Parameters (path, query, header, body)
- Responses (status codes, body schemas)
- Data schemas (what a "User" or "Product" looks like)
- Authentication requirements
- Grouping and tagging

The spec follows a standard JSON structure. Tools across the industry consume it -- Postman, Insomnia, code generators, testing frameworks, API gateways. One spec feeds them all.

Tina4 builds this spec from Python decorators on your routes. No JSON or YAML by hand. The framework inspects your decorators at startup and constructs the full OpenAPI 3.0.3 document. You write Python. Tina4 writes the spec.

---

## 3. Accessing the Swagger UI

When `TINA4_DEBUG=true`, the Swagger UI appears at:

```
http://localhost:7145/swagger
```

Open it in your browser. You see all registered routes, organized by tags, with request and response details.

The underlying OpenAPI JSON spec lives at:

```
http://localhost:7145/swagger/json
```

This raw JSON feeds tools that import API definitions. Postman, Insomnia, and code generators all consume it.

```bash
curl http://localhost:7145/swagger/json
```

```json
{
  "openapi": "3.0.3",
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

## 4. Documenting Routes with Decorators

### @description -- Describe What an Endpoint Does

```python
from tina4_python.core.router import get, post
from tina4_python.swagger import description

@get("/api/users")
@description("List all users", "Returns a paginated list of all registered users. Supports filtering by role and sorting by name or creation date.")
async def list_users(request, response):
    return response.json({"users": [], "count": 0})
```

The first argument is a short summary (shown in the route list). The second is a detailed description (shown when you expand the route).

### @tags -- Organize Endpoints into Groups

```python
from tina4_python.swagger import tags

@get("/api/users")
@tags("Users")
@description("List all users")
async def list_users(request, response):
    return response.json({"users": []})

@post("/api/users")
@tags("Users")
@description("Create a new user")
async def create_user(request, response):
    return response.json({"user": request.body}, 201)

@get("/api/products")
@tags("Products")
@description("List all products")
async def list_products(request, response):
    return response.json({"products": []})
```

Tags group related endpoints in the Swagger UI. All "Users" endpoints appear under one collapsible section, all "Products" under another. Without tags, every endpoint sits in one flat list. With tags, the UI becomes navigable.

### @example -- Document Request Body

```python
from tina4_python.swagger import example

@post("/api/users")
@tags("Users")
@description("Create a new user", "Registers a new user account. Email must be unique.")
@example({
    "name": "Alice Smith",
    "email": "alice@example.com",
    "password": "securePass123",
    "role": "user"
})
async def create_user(request, response):
    return response.json({"user": request.body}, 201)
```

The `@example` decorator shows a sample request body in the Swagger UI. Developers click "Try it out" and the example pre-fills the input fields.

### @example_response -- Document Response Body

```python
from tina4_python.swagger import example_response

@get("/api/users/{id:int}")
@tags("Users")
@description("Get a user by ID")
@example_response(200, {
    "id": 1,
    "name": "Alice Smith",
    "email": "alice@example.com",
    "role": "user",
    "created_at": "2026-03-22T14:30:00"
})
@example_response(404, {
    "error": "User not found"
})
async def get_user(request, response):
    user_id = request.params["id"]
    return response.json({"id": user_id, "name": "Alice"})
```

Stack multiple `@example_response` decorators for different status codes. Developers see what to expect for both success and failure.

---

## 5. Documenting Path Parameters

The framework detects path parameters from the route pattern. Add descriptions with the `@description` decorator's extended syntax:

```python
@get("/api/users/{id:int}/posts/{status}")
@tags("Posts")
@description(
    "Get user posts by status",
    "Returns all posts for a specific user filtered by status.",
    params={
        "id": "The user's unique identifier (integer)",
        "status": "Post status filter: 'draft', 'published', or 'archived'"
    }
)
async def user_posts(request, response):
    return response.json({"posts": []})
```

### Documenting Query Parameters

```python
@get("/api/products")
@tags("Products")
@description(
    "List products",
    "Returns a filtered and paginated list of products.",
    query={
        "category": {"type": "string", "description": "Filter by category name", "required": False},
        "min_price": {"type": "number", "description": "Minimum price filter", "required": False},
        "max_price": {"type": "number", "description": "Maximum price filter", "required": False},
        "page": {"type": "integer", "description": "Page number (default: 1)", "required": False},
        "limit": {"type": "integer", "description": "Items per page (default: 20)", "required": False}
    }
)
async def list_products(request, response):
    return response.json({"products": [], "count": 0})
```

---

## 6. Authentication in Swagger

Routes marked with `@secured` show a lock icon in the Swagger UI. Developers click "Authorize", paste their JWT token, and all subsequent requests include the header.

```python
from tina4_python.core.router import get, secured
from tina4_python.swagger import description, tags

@get("/api/profile")
@secured()
@tags("Auth")
@description("Get current user profile", "Requires a valid JWT token in the Authorization header.")
async def get_profile(request, response):
    return response.json({"user": request.user})
```

Public routes marked with `@noauth` show as unlocked:

```python
from tina4_python.core.router import post, noauth

@post("/api/login")
@noauth()
@tags("Auth")
@description("Login", "Authenticate with email and password. Returns a JWT token.")
@example({"email": "alice@example.com", "password": "securePass123"})
@example_response(200, {
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {"id": 1, "name": "Alice", "email": "alice@example.com"}
})
@example_response(401, {"error": "Invalid email or password"})
async def login(request, response):
    return response.json({"token": "..."})
```

---

## 7. Try-It-Out from the Swagger UI

Every endpoint in the Swagger UI has a "Try it out" button. Click it and the interface transforms.

1. Input fields expand for every parameter
2. Example values pre-fill (when provided via `@example`)
3. Edit parameters, headers, and the request body
4. Click "Execute" -- the actual HTTP request fires against your running server
5. The response appears: status code, headers, body

This turns your documentation into a live testing tool. No Postman needed. No curl commands to remember.

### Authentication in Try-It-Out

Endpoints that require auth display a lock icon. Click the "Authorize" button at the top of the Swagger UI. Paste your JWT token or API key. The UI stores it and includes the `Authorization` header on every subsequent request.

The workflow for testing a secured endpoint:

1. Call your `/api/login` endpoint through Swagger to get a token
2. Click "Authorize" and paste the token
3. Test any protected endpoint -- the token travels with each request
4. Click "Authorize" again and "Logout" to clear it

Tina4 auto-detects auth requirements from `@secured` and `@noauth` decorators. Secured routes show the lock. Public routes show an open lock. Routes without either decorator inherit the default security scheme.

---

## 8. Customizing the Swagger Info Block

The Swagger UI header and OpenAPI spec carry metadata about your API. Configure this metadata through environment variables in `.env`:

```bash
SWAGGER_TITLE=My Store API
SWAGGER_DESCRIPTION=REST API for managing products, orders, and users
SWAGGER_VERSION=1.0.0
SWAGGER_DEV_URL=http://localhost:7145
```

These values appear in the OpenAPI spec under the `info` block:

```json
{
  "openapi": "3.0.3",
  "info": {
    "title": "My Store API",
    "description": "REST API for managing products, orders, and users",
    "version": "1.0.0"
  },
  "servers": [
    {
      "url": "http://localhost:7145"
    }
  ]
}
```

| Variable | Purpose | Default |
|----------|---------|---------|
| `SWAGGER_TITLE` | API name shown in the UI header | `Tina4 API` |
| `SWAGGER_DESCRIPTION` | Brief description below the title | (empty) |
| `SWAGGER_VERSION` | API version number | `1.0.0` |
| `SWAGGER_DEV_URL` | Server URL for the spec | `http://localhost:7145` |

When you version your API, update `SWAGGER_VERSION` so consumers know which version they target. The title and description give context -- a developer who opens your Swagger page should know what the API does before scrolling.

---

## 9. Generating Client SDKs from the Spec

The OpenAPI spec at `/swagger/json` feeds code generation tools. One spec produces client libraries in any language.

### Using OpenAPI Generator

```bash
npm install -g @openapitools/openapi-generator-cli

# TypeScript client
openapi-generator-cli generate \
  -i http://localhost:7145/swagger/json \
  -g typescript-fetch \
  -o ./frontend/api-client

# Python client
openapi-generator-cli generate \
  -i http://localhost:7145/swagger/json \
  -g python \
  -o ./python-client
```

The generated code carries types. IDE autocompletion works:

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

Update your decorators. Regenerate. The client stays in sync with the server.

### Other Generators

The ecosystem supports dozens of languages and frameworks:

| Generator | Output |
|-----------|--------|
| `typescript-fetch` | Browser-ready TypeScript client |
| `typescript-axios` | Axios-based TypeScript client |
| `python` | Python client with type hints |
| `swift5` | iOS/macOS client |
| `kotlin` | Android/JVM client |
| `csharp-netcore` | .NET client |
| `go` | Go client |

Every generator reads the same spec. Your API documentation becomes the single source of truth for every consumer.

---

## 10. Complete API Documentation Example

Here is a fully documented User API with all decorator features:

```python
from tina4_python.core.router import get, post, put, delete, noauth, secured, middleware
from tina4_python.swagger import description, tags, example, example_response
from tina4_python.auth import Auth
from tina4_python.database.connection import Database


async def auth_middleware(request, response, next_handler):
    auth_header = request.headers.get("Authorization", "")
    if not auth_header or not auth_header.startswith("Bearer "):
        return response.json({"error": "Authorization required"}, 401)
    token = auth_header[7:]
    if not Auth.valid_token(token):
        return response.json({"error": "Invalid or expired token"}, 401)
    request.user = Auth.get_payload(token)
    return await next_handler(request, response)


@post("/api/users")
@noauth()
@tags("Users")
@description(
    "Register a new user",
    "Creates a new user account. Email must be unique. Password must be at least 8 characters."
)
@example({
    "name": "Alice Smith",
    "email": "alice@example.com",
    "password": "securePass123"
})
@example_response(201, {
    "message": "Registration successful",
    "user": {"id": 1, "name": "Alice Smith", "email": "alice@example.com", "role": "user"}
})
@example_response(400, {"errors": ["Password must be at least 8 characters"]})
@example_response(409, {"error": "Email already registered"})
async def register_user(request, response):
    # Registration logic...
    return response.json({"message": "Registration successful"}, 201)


@get("/api/users")
@middleware(auth_middleware)
@tags("Users")
@description(
    "List all users",
    "Returns a paginated list of users. Admin only.",
    query={
        "role": {"type": "string", "description": "Filter by role", "required": False},
        "page": {"type": "integer", "description": "Page number", "required": False},
        "limit": {"type": "integer", "description": "Results per page", "required": False}
    }
)
@example_response(200, {
    "users": [
        {"id": 1, "name": "Alice", "email": "alice@example.com", "role": "admin"},
        {"id": 2, "name": "Bob", "email": "bob@example.com", "role": "user"}
    ],
    "count": 2,
    "page": 1,
    "total_pages": 1
})
async def list_users(request, response):
    return response.json({"users": []})


@get("/api/users/{id:int}")
@middleware(auth_middleware)
@tags("Users")
@description(
    "Get a user by ID",
    "Returns the full profile of a single user.",
    params={"id": "The user's unique identifier"}
)
@example_response(200, {
    "id": 1, "name": "Alice Smith", "email": "alice@example.com",
    "role": "user", "created_at": "2026-03-22T14:30:00"
})
@example_response(404, {"error": "User not found"})
async def get_user(request, response):
    return response.json({"id": request.params["id"]})


@put("/api/users/{id:int}")
@middleware(auth_middleware)
@tags("Users")
@description("Update a user", "Update user profile. Users can only update themselves. Admins can update anyone.")
@example({"name": "Alice Johnson", "email": "alice.j@example.com"})
@example_response(200, {"message": "User updated", "user": {"id": 1, "name": "Alice Johnson"}})
@example_response(404, {"error": "User not found"})
async def update_user(request, response):
    return response.json({"message": "User updated"})


@delete("/api/users/{id:int}")
@middleware(auth_middleware)
@tags("Users")
@description("Delete a user", "Permanently removes a user account. Admin only.")
@example_response(204, None)
@example_response(404, {"error": "User not found"})
async def delete_user(request, response):
    return response.json(None, 204)
```

---

## 11. Swagger Configuration

Control Swagger behavior in `.env`:

```bash
# Swagger is only available when debug mode is on (default behavior)
TINA4_DEBUG=true

# Custom API title and version shown in Swagger UI
SWAGGER_TITLE=My Store API
SWAGGER_VERSION=1.0.0
SWAGGER_DESCRIPTION=REST API for the My Store e-commerce platform
```

---

## 12. Exercise: Document a User API

Take the authentication routes from Chapter 8 (register, login, profile, update profile, change password) and add full Swagger documentation.

### Requirements

1. Add `@tags("Auth")` to all auth-related endpoints
2. Add `@description()` with both summary and detailed description
3. Add `@example()` for all POST and PUT endpoints
4. Add `@example_response()` for success and error cases on every endpoint
5. Document query parameters on any endpoint that accepts them
6. Visit `/swagger` and verify all routes appear with examples

### Expected Result

Open `http://localhost:7145/swagger`. You should see:

- An "Auth" section with 5 endpoints
- Each endpoint carries a summary and description
- POST/PUT endpoints show example request bodies
- Every endpoint shows example responses for success and error cases
- The "Authorize" button works for testing protected endpoints

---

## 13. Solution

Update `src/routes/auth.py` with Swagger decorators (showing the decorator additions -- the function bodies remain the same as Chapter 8):

```python
from tina4_python.core.router import get, post, put, noauth, middleware
from tina4_python.swagger import description, tags, example, example_response
from tina4_python.auth import Auth
from tina4_python.database.connection import Database


async def auth_middleware(request, response, next_handler):
    auth_header = request.headers.get("Authorization", "")
    if not auth_header or not auth_header.startswith("Bearer "):
        return response.json({"error": "Authorization required"}, 401)
    token = auth_header[7:]
    if not Auth.valid_token(token):
        return response.json({"error": "Invalid or expired token"}, 401)
    request.user = Auth.get_payload(token)
    return await next_handler(request, response)


@post("/api/register")
@noauth()
@tags("Auth")
@description(
    "Register a new account",
    "Creates a new user account. All fields are required. Password must be at least 8 characters. Email must be unique."
)
@example({
    "name": "Alice Smith",
    "email": "alice@example.com",
    "password": "securePass123"
})
@example_response(201, {
    "message": "Registration successful",
    "user": {"id": 1, "name": "Alice Smith", "email": "alice@example.com", "role": "user", "created_at": "2026-03-22 16:00:00"}
})
@example_response(400, {"errors": ["Password must be at least 8 characters"]})
@example_response(409, {"error": "Email already registered"})
async def register(request, response):
    # ... same as Chapter 8 ...
    pass


@post("/api/login")
@noauth()
@tags("Auth")
@description(
    "Login",
    "Authenticate with email and password. Returns a JWT token valid for 1 hour. Include the token in subsequent requests as: Authorization: Bearer <token>"
)
@example({"email": "alice@example.com", "password": "securePass123"})
@example_response(200, {
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {"id": 1, "name": "Alice Smith", "email": "alice@example.com", "role": "user"}
})
@example_response(400, {"error": "Email and password are required"})
@example_response(401, {"error": "Invalid email or password"})
async def login(request, response):
    # ... same as Chapter 8 ...
    pass


@get("/api/profile")
@middleware(auth_middleware)
@tags("Auth")
@description(
    "Get current user profile",
    "Returns the profile of the currently authenticated user. Requires a valid JWT token."
)
@example_response(200, {
    "id": 1, "name": "Alice Smith", "email": "alice@example.com",
    "role": "user", "created_at": "2026-03-22 16:00:00"
})
@example_response(401, {"error": "Authorization required"})
async def get_profile(request, response):
    # ... same as Chapter 8 ...
    pass


@put("/api/profile")
@middleware(auth_middleware)
@tags("Auth")
@description(
    "Update profile",
    "Update the current user's name and/or email. Only the fields you include will be updated."
)
@example({"name": "Alice Johnson", "email": "alice.j@example.com"})
@example_response(200, {
    "message": "Profile updated",
    "user": {"id": 1, "name": "Alice Johnson", "email": "alice.j@example.com", "role": "user"}
})
@example_response(409, {"error": "Email already in use by another account"})
async def update_profile(request, response):
    # ... same as Chapter 8 ...
    pass


@put("/api/profile/password")
@middleware(auth_middleware)
@tags("Auth")
@description(
    "Change password",
    "Change the current user's password. Requires the current password for verification. New password must be at least 8 characters."
)
@example({"current_password": "securePass123", "new_password": "evenMoreSecure456"})
@example_response(200, {"message": "Password changed successfully"})
@example_response(400, {"error": "New password must be at least 8 characters"})
@example_response(401, {"error": "Current password is incorrect"})
async def change_password(request, response):
    # ... same as Chapter 8 ...
    pass
```

---

## 14. Gotchas

### 1. Swagger not showing up

**Problem:** Visiting `/swagger` returns a 404.

**Cause:** `TINA4_DEBUG` is not set to `true` in your `.env`. The Swagger UI only appears in debug mode.

**Fix:** Set `TINA4_DEBUG=true` in `.env` and restart the server.

### 2. Route appears but has no documentation

**Problem:** A route shows up in Swagger but carries no description, examples, or parameter documentation.

**Cause:** The route has no Swagger decorators (`@description`, `@example`, etc.).

**Fix:** Add at least `@description()` and `@tags()` to every route you want documented. Without these, Swagger shows the route with minimal information.

### 3. Decorator order causes issues

**Problem:** Adding `@description` or `@tags` breaks the route registration.

**Cause:** Swagger decorators must sit below the route decorator. Python applies decorators bottom to top, so the route decorator executes first.

**Fix:** Follow this order (bottom to top): route decorator first, then middleware, then Swagger decorators:

```python
@tags("Users")               # Applied last
@description("List users")   # Applied third
@middleware(auth_middleware)  # Applied second
@get("/api/users")           # Applied first
async def list_users(...):
    ...
```

### 4. Example does not match actual response

**Problem:** The example response in Swagger differs from what the endpoint returns.

**Cause:** You updated the route handler but forgot to update the `@example_response` decorator.

**Fix:** Keep examples in sync with your actual response format. Decorators are not enforced by the runtime. Consider writing tests that validate your responses match the documented examples.

### 5. Sensitive data in examples

**Problem:** Your `@example` decorator contains a real password or API key.

**Cause:** You copy-pasted from a test and forgot to replace real values.

**Fix:** Use placeholder values in examples: `"password": "securePass123"`, `"token": "eyJhbGciOiJIUzI1NiIs..."`. Never include real credentials.

### 6. Swagger in production

**Problem:** Your production API exposes the Swagger UI, revealing all endpoints and their parameters.

**Cause:** `TINA4_DEBUG=true` in production.

**Fix:** Set `TINA4_DEBUG=false` in production. The Swagger UI disappears. If you need API docs in production, export the OpenAPI JSON and host it separately with access controls.

### 7. Too many tags

**Problem:** Your Swagger UI has 20 tags. Navigation becomes painful.

**Cause:** You created a separate tag for every resource, sub-resource, and action.

**Fix:** Use broad tags that group related functionality: "Users", "Products", "Orders", "Auth". Most APIs need 5-10 tags. Avoid tags like "User Profile", "User Settings", "User Notifications" -- use "Users" for all of them.

### 8. SDK generation produces incorrect types

**Problem:** The generated TypeScript client has `any` types everywhere.

**Cause:** Your `@example_response` data uses generic strings instead of typed values.

**Fix:** Use correct types in examples: strings for text, numbers for numeric values, booleans for flags, arrays for lists. The generator infers types from example values. `"price": 9.99` produces `number`. `"price": "9.99"` produces `string`.
