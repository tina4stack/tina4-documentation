---
title: Let's get route to it
---

# Let's get route to it

::: tip 🔥 Hot Tips – Read This First!
- You **don’t need** `app = Tina4()` in route files – just import `get`, `post`, etc. directly  
- All route handlers **must be `async def`** – Tina4 is 100% async-native  
- Path parameters are **auto-injected** in the exact order they appear in the URL  
- Use type hints: `{id:int}`, `{price:float}`, `{path:path}` – Tina4 converts them automatically  
- `request` and `response` are **automatically added** as the last arguments if you don’t declare them  
- Save files in a `routes/` folder  → **auto-discovered**, zero config needed  
- Stack decorators freely: `@get("/users") @post("/users")` works on the same function  
- Use `@description("...")` for beautiful Swagger docs  
:::

The routing system in **Tina4 Python** is decorator-driven, fully async-ready, and designed for clarity and speed — comparable to FastAPI but with even less boilerplate.

Routes are defined using imported method decorators directly — no app instance required in route files.

## Core Imports

```python
from tina4_python import get, post, put, delete, patch, options
from tina4_python import middleware, description, secured
from tina4_python import HTTP_OK, HTTP_BAD_REQUEST
```

## Basic Route Definition

```python
@get("/hello")
async def hello_world(request, response):
    return response("Hello, Tina4 Python!")
```

Stack multiple HTTP methods on one handler:

```python
@get("/users")
@post("/users")
async def users_handler(request, response):
    if request.method == "GET":
        return response({"users": [...]})
    return response({"created": True})
```

## Route Parameters (Dynamic Paths)

```python
@get("/users/{id}")
async def get_user(id: str, request, response):
    return response({"user_id": id})

# With automatic type conversion
@get("/users/{id:int}")
async def get_user_int(id: int, request, response):
    return response({"user_id": id, "type": type(id).__name__})

# Multiple parameters + path (greedy)
@get("/files/{filepath:str}")
async def serve_file(filepath: str, request, response):
    return response.file(filepath)
```

**Supported converters**: `int`, `float`, `str` (default), `path`

## Query Parameters

```python
@get("/search")
async def search(request, response):
    q = request.params.get("q", "world")
    page = request.params.get("page", 1, type=int)
    return response(f"Searching '{q}' – page {page}")
```

## Prefixes & File Organization

Just use the path you want – no special prefix decorator needed:

```python
@get("/admin/dashboard")
async def admin_dashboard(request, response):
    return response("Admin Area")
```

Put files in `routes/admin_routes.py` → auto-loaded.

## Middleware

```python
class AuthMiddleware:
    @staticmethod
    def before_route(request, response):
        if request.headers.get("authorization") != "Bearer secret123":
            response.status = 401
            return request, response  # stops chain
        return request, response

    @staticmethod
    def after_route(request, response):
        response.add_header("X-Powered-By", "Tina4")
        return request, response

@middleware(AuthMiddleware)
@get("/protected")
async def protected_route(request, response):
    return response("Top secret data")
```

## Metadata & Swagger

```python
@get("/api/users")
@description("Retrieve the full list of users")
async def list_users(request, response):
    return response({"users": [...]})
```

## Secured Routes

```python
@secured()
@get("/profile")
async def profile(request, response):
    return response({"user": request.user})
```

## Response Helpers

```python
return response({"json": "yes"})                        # application/json
return response("<h1>Hello</h1>")                       # text/html
return response.redirect("/login")                      # 302
return response.file("report.pdf", "uploads")           # send/file download
return response.render("index.twig", {"title": "Home"})
return response("plain text", HTTP_OK, TEXT_PLAIN)      # text/plain
```

With custom status:

```python
return response("Not found", HTTP_NOT_FOUND)
```

## WebSockets

```python
from tina4_python.Websocket import Websocket

@get("/ws/chat")
async def chat_ws(request, response):
    ws = await Websocket(request).connection()
    try:
        while True:
            data = await ws.receive()
            await ws.send(f"Echo: {data}")
    finally:
        await ws.close()
    return response("")
```

## Auto-Discovery

Tina4 automatically loads routes from:
- Any file inside `routes/` folder

**Zero manual registration required.**

## Summary Table

| Feature                | Syntax Example                       | Notes                                      |
|------------------------|--------------------------------------|--------------------------------------------|
| Route                  | `@get("/path")`                      | Must be `async def`                        |
| Path Params            | `/users/{id:int}`                    | Auto-injected + conversion                 |
| Query Params           | `request.params.get("q")`            | Dict-like                                  |
| Middleware             | `@middleware(MyClass)`               | `before_route` / `after_route`             |
| Description            | `@description("Text")`               | Populates Swagger UI                       |
| Secured                | `@secured()`                         | Built-in auth guard                        |
| Responses              | `response.json()` `.file()` etc.     | All via injected `response`                |
| WebSockets             | `@get("/ws")` + `Websocket(request)` | Full async support                         |
| Auto-discovery         | Drop file in `routes/`               | No config needed                           |

::: tip 🔥 Hot Tips 
- Prefer **explicit `request, response` arguments** – they are auto-injected only when needed
- Use **`response.file()`** for serving uploads (root is project folder by default)
- Return early in `before_route` middleware to **block** the request
- `@description` is your friend for auto-generated Swagger/OpenAPI docs
- Combine `@get` + `@post` on the same function to handle multiple methods cleanly
- Your route files can be **anywhere** under `./src/routes/` – Tina4 finds them magically
- Always `await` WebSocket send/receive – they are fully async  
  :::

Happy routing with Tina4 Python! 🚀
