# Comprehensive Guide to Routing in Tina4 Python

## Introduction to Routing in Tina4 Python

Tina4 Python is a lightweight, ASGI-compliant web tool that emphasizes minimal boilerplate and rapid development, blending the simplicity of Laravel-style routing with Python's speed. Unlike traditional frameworks, Tina4 Python uses a decorator-based routing system imported from `tina4_python.Router`. This allows you to define routes directly in your application code—typically in `app.py`, `__init__.py`, or dedicated files under `src/routes/`—without complex configuration.

Routing in Tina4 Python supports:
- **HTTP methods**: GET, POST, PUT, DELETE, PATCH, and more.
- **Path parameters**: Dynamic segments like `/users/{id}`.
- **Query parameters**: Accessed via the `request` object.
- **Middleware integration**: Attach behaviors before/after routes.
- **Async handlers**: Full support for asynchronous functions.
- **Swagger/OpenAPI**: Automatic documentation with decorators.
- **Security**: Built-in JWT and route protection.

Routes are resolved at runtime, and the system auto-scans entry points. No explicit router registration is needed—just decorate your functions and run the app.

This guide assumes you have a basic Tina4 Python project set up (via `tina4 init my_project`). If not, install via `pip install tina4-python` or Poetry, then initialize.

## Basic Route Definition

Routes are defined using method-specific decorators (e.g., `@get`, `@post`) from `tina4_python.Router`. Each decorator takes a path string. The handler function receives a `request` (incoming ASGI scope) and `response` (outgoing ASGI send/receive) object.

### Simple GET Route

```python
from tina4_python.Router import get

@get("/hello")
async def hello(request, response):
    return response("Hello, Tina4 Python!")
```

- **Path**: `/hello` matches incoming requests exactly.
- **Handler**: Async function that returns a modified `response` or a string (auto-wrapped).
- **Response**: Use `response(content)` for body. Any dictionaries or list inputs get automatically translated to JSON`.

Run your app (`python app.py`), and visit `http://localhost:7145/hello` to see "Hello, Tina4 Python!".

### POST Route

```python
from tina4_python.Router import post

@post("/submit")
async def submit(request, response):
    data = await request.body()  # Parse POST body as dict
    return response(f"Received: {data}")
```

- Handles form/JSON payloads via `request.body()`.

## HTTP Methods

Tina4 supports all standard HTTP methods via dedicated decorators:

- `@get(path)`: Retrieve data.
- `@post(path)`: Create data.
- `@put(path)`: Update data.
- `@patch(path)`: Partial update.
- `@delete(path)`: Delete data.

Example with multiple methods on similar paths:

```python
from tina4_python.Router import get, post, put, delete

@get("/users")
async def list_users(request, response):
    return response({"users": ["Alice", "Bob"]})

@post("/users")
async def create_user(request, response):
    data = await request.body()
    return response({"created": data.get("name")})

@put("/users/{id}")
async def update_user(id: str, request, response):
    data = await request.body()
    return response(f"Updated user {id} with {data}")

@delete("/users/{id}")
async def delete_user(id: str, request, response):
    return response(f"Deleted user {id}")
```

## Path and Query Parameters

### Path Parameters

Use `{param}` in the path for dynamic segments. Parameters are injected as function arguments.

```python
from tina4_python.Router import get

@get("/users/{id}/posts/{post_id}")
async def user_post(id: str, post_id: str, request, response):  # Path params before request/response
    return response(f"User {id}'s post {post_id}")
```

- Type hints (e.g., `str`, `int`) are optional but recommended for clarity.
- Access via function args; no manual parsing needed.
- Supports regex? Not natively, but middleware can preprocess paths.

### Query Parameters

Query strings (e.g., `/search?q=term&page=1`) are in `request.query_params` (dict-like).

```python
from tina4_python.Router import get

@get("/search")
async def search(request, response):
    query = request.params.get("q", "default")
    page = int(request.params.get("page", 1))
    return response(f"Searching '{query}' on page {page}")
```

- Handles URL-encoded values automatically.
- For complex queries, use `request.raw_request` as raw bytes.

## Route Groups and Namespacing

Tina4 doesn't enforce strict groups like some frameworks, but you can organize via file structure (e.g., `src/routes/api.py`, `src/routes/admin.py`). Import and define routes in each; the router auto-discovers.

For prefixed groups, use a base class or manual prefixing:

```python
from tina4_python.Router import get

# In src/routes/admin.py
ADMIN_PREFIX = "/admin"

@get(f"{ADMIN_PREFIX}/dashboard")
async def dashboard(request, response):
    return response("Admin Dashboard")
```


## Middleware with Routes

Middleware intercepts requests/responses. Define a class with static methods named after events (e.g., `before_route`, `after_route`).

Example middleware:

```python
class AuthMiddleware:
    @staticmethod
    def before_route(request, response):
        token = request.headers.get("Authorization")
        if not token:
            response.status_code = 401
            return request, "Unauthorized"
        # Validate token...
        return request, response

    @staticmethod
    def after_route(request, response):
        response.headers["X-Custom"] = "Processed"
        return request, response
```

Attach to specific routes:

```python
from tina4_python.Router import get, middleware

@middleware(AuthMiddleware)
@get("/protected")
async def protected(request, response):
    return response("Secure data")
```

- **Events**: `before_route`, `after_route`, `any_route`, `before_{method}`, etc.
- Global middleware: Add to app startup in `app.py`.

## Error Handling in Routes

Use try-except in handlers:

```python
from tina4_python.Router import get

@get("/divide/{num}")
async def divide(request, response, num: str):
    try:
        result = 100 / float(num)
        return response(str(result))
    except ValueError:
        response.status_code = 400
        return response("Invalid number")
    except ZeroDivisionError:
        response.status_code = 400
        return response("Cannot divide by zero")
```

- Global errors: Use middleware's `before_route` to catch exceptions.
- Custom exceptions: Tina4 propagates ASGI errors; catch in outer handlers.

## Async and Sync Handlers

All examples use `async def` for full ASGI compatibility (e.g., DB calls, I/O). Sync functions work but block the event loop—avoid for production.

```python
@get("/async-db")
async def async_db(request, response):
    users =  db.fetch_all("SELECT * FROM users")
    return response(users)

```

## Returning Responses

The `response` object is versatile:

- `response("text")`: Plain text.
- `response("<html>")`: HTML.
- `response({"key": "value"})`: JSON (auto-serializes).
- `response.redirect("/other")`: 302 redirect.
- `response.render("template.twig", data={})`: Render Twig (import `Template`).


## API Routes and Swagger Documentation

Tina4 auto-generates Swagger at `/swagger`. Enhance with decorators from `tina4_python.Swagger`:

```python
from tina4_python.Router import post
from tina4_python.Swagger import description, summary, example, tags, secure

@post("/api/users")
@description("Create a new user")
@summary("User Creation Endpoint")
@example({"name": "John", "email": "john@example.com"})
@tags(["users", "api"])
@secure()  # Requires JWT
async def create_user(request, response):
    data =  request.body
    # Save user...
    user = User(data)
    user.save()
    
    return response(user.to_dict())
```

- `@secure()`: Enforces auth (JWT in headers).
- Visit `/swagger` post-run for interactive docs.

## Route Security and Authentication

- **JWT**: Use `tina4_python.tina4_auth.generate_token(payload)` to create tokens. Validate in middleware.
- **Sessions**: Built-in; access via `request.session`.
- **CSRF**: Auto-handled for forms.

Example protected route:

```python
from tina4_python.Router import get,secured

@get("/profile")
@secured()
async def profile(request, response):
    user = request.body
    return response(user)
```

## Static Files and Public Routing

Static assets (CSS/JS/images) in `src/public/` are auto-served at `/`. No explicit routes needed.

```python
# Custom static handler if needed
@get("/custom-static/{file}")
async def serve_custom(request, response, file: str):
    return response.file(f"custom/{file}")
```

## Advanced Topics

### WebSockets

Tina4 supports WS via `@ws(path)`:

```python
from tina4_python.Router import ws

@ws("/chat")
async def chat(websocket):
    async for message in websocket:
        await websocket.send(f"Echo: {message}")
```

- Handles upgrade; use `app.py` for global WS config.

### Rate Limiting

Implement in middleware:

```python
class RateLimitMiddleware:
    @staticmethod
    def before_route(request, response):
        ip = request.client_host
        # Check cache/DB for limits
        if exceeded(ip):
            response.status_code = 429
            return request, "Rate limited"
        return request, response
```

### Route Testing

Use `pytest` with ASGI test client:

```python
from tina4_python.testing import TestClient

client = TestClient(app)

def test_hello():
    response = client.get("/hello")
    assert response.status_code == 200
    assert response.text == "Hello, Tina4 Python!"
```

## Best Practices

- **Organization**: Group routes by feature in `src/routes/` (e.g., `users.py`, `api.py`).
- **Validation**: Use Pydantic or manual checks in handlers.
- **Logging**: Inject via middleware.
- **Performance**: Keep handlers lean; offload to services.
- **Hot Reload**: Use `python -m jurigged app.py` in dev.
- **Comparisons**: Like FastAPI's decorators but with Twig integration and zero-schema enforcement for quicker starts.

