# Chapter 10: Swagger / OpenAPI

## 1. Self-Documenting APIs

Routes built. Requests handled. Database connected. Authentication locked down. Now other developers need to know how to use your API. What endpoints exist. What parameters they accept. What the response looks like.

Tina4 Python auto-generates Swagger/OpenAPI documentation from your routes. Add a few decorators. Tina4 produces an interactive API reference that developers explore and test in the browser.

Picture handing your API to a frontend team. No separate document that rots the moment you change a route. You point them to `/swagger`. They see every endpoint. Examples. Parameter descriptions. A "Try it out" button on each one.

---

## 2. Accessing the Swagger UI

When `TINA4_DEBUG=true`, the Swagger UI is automatically available at:

```
http://localhost:7145/swagger
```

Open it in your browser and you will see all your registered routes, organized by tags, with request/response details.

The underlying OpenAPI JSON spec is available at:

```
http://localhost:7145/swagger/json
```

This is the raw JSON that tools like Postman, Insomnia, and code generators can import.

---

## 3. Documenting Routes with Decorators

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

Tags group related endpoints together in the Swagger UI. All "Users" endpoints appear under one collapsible section, all "Products" under another.

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

The `@example` decorator shows a sample request body in the Swagger UI. Developers can click "Try it out" and the example is pre-filled.

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

You can add multiple `@example_response` decorators for different status codes. This shows developers exactly what to expect for success and error cases.

---

## 4. Documenting Path Parameters

Path parameters are automatically detected from the route pattern. You can add descriptions with the `@description` decorator's extended syntax:

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

## 5. Authentication in Swagger

When your API uses JWT authentication, document it so the Swagger UI includes an "Authorize" button:

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

Routes marked with `@secured` automatically show a lock icon in the Swagger UI. Developers can click "Authorize", paste their JWT token, and all subsequent requests will include it.

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

## 6. Complete API Documentation Example

Here is a fully documented User API:

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

## 7. Swagger Configuration

Control Swagger behavior in `.env`:

```env
# Swagger is only available when debug mode is on (default behavior)
TINA4_DEBUG=true

# Custom API title and version shown in Swagger UI
TINA4_SWAGGER_TITLE=My Store API
TINA4_SWAGGER_VERSION=1.0.0
TINA4_SWAGGER_DESCRIPTION=REST API for the My Store e-commerce platform
```

---

## 8. Exercise: Document a User API

Take the authentication routes from Chapter 7 (register, login, profile, update profile, change password) and add full Swagger documentation.

### Requirements

1. Add `@tags("Auth")` to all auth-related endpoints
2. Add `@description()` with both summary and detailed description
3. Add `@example()` for all POST and PUT endpoints
4. Add `@example_response()` for success and error cases on every endpoint
5. Document query parameters on any endpoint that accepts them
6. Visit `/swagger` and verify all routes appear correctly with examples

### Expected Result

When you open `http://localhost:7145/swagger`, you should see:

- An "Auth" section with 5 endpoints
- Each endpoint has a summary and description
- POST/PUT endpoints show example request bodies
- Every endpoint shows example responses for success and error cases
- The "Authorize" button works for testing protected endpoints

---

## 9. Solution

Update `src/routes/auth.py` with Swagger decorators (showing just the decorator additions -- the function bodies remain the same as Chapter 7):

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
    # ... same as Chapter 7 ...
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
    # ... same as Chapter 7 ...
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
    # ... same as Chapter 7 ...
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
    # ... same as Chapter 7 ...
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
    # ... same as Chapter 7 ...
    pass
```

---

## 10. Gotchas

### 1. Swagger not showing up

**Problem:** Visiting `/swagger` returns a 404.

**Cause:** `TINA4_DEBUG` is not set to `true` in your `.env`. The Swagger UI is only available in debug mode.

**Fix:** Set `TINA4_DEBUG=true` in `.env` and restart the server.

### 2. Route appears but has no documentation

**Problem:** A route shows up in Swagger but has no description, examples, or parameter documentation.

**Cause:** You did not add Swagger decorators (`@description`, `@example`, etc.) to the route.

**Fix:** Add at least `@description()` and `@tags()` to every route you want documented. Without these, Swagger shows the route but with minimal information.

### 3. Decorator order causes issues

**Problem:** Adding `@description` or `@tags` breaks the route registration.

**Cause:** Swagger decorators must be placed above the route decorator (applied after it in Python's bottom-up decorator application).

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

**Problem:** The example response in Swagger does not match what the endpoint actually returns.

**Cause:** You updated the route handler but forgot to update the `@example_response` decorator.

**Fix:** Keep examples in sync with your actual response format. This is the main downside of Swagger decorators -- they are not enforced. Consider writing tests that validate your responses match the documented examples.

### 5. Sensitive data in examples

**Problem:** Your `@example` decorator includes a real password or API key.

**Cause:** You copy-pasted from a test and forgot to replace real values.

**Fix:** Always use placeholder values in examples: `"password": "securePass123"`, `"token": "eyJhbGciOiJIUzI1NiIs..."`. Never include real credentials.

### 6. Swagger in production

**Problem:** Your production API exposes the Swagger UI, revealing all endpoints and their parameters to the public.

**Cause:** `TINA4_DEBUG=true` in production.

**Fix:** Always set `TINA4_DEBUG=false` in production. The Swagger UI will not be available. If you need API docs in production, export the OpenAPI JSON and host it separately with access controls.

### 7. Too many tags

**Problem:** Your Swagger UI has 20 tags, making it hard to navigate.

**Cause:** You created a separate tag for every resource, sub-resource, and action.

**Fix:** Use broad tags that group related functionality: "Users", "Products", "Orders", "Auth". Most APIs need 5-10 tags. Avoid tags like "User Profile", "User Settings", "User Notifications" -- just use "Users" for all of them.
