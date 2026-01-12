# Middleware {#declare}

::: tip 🔥 Hot Tips
- Middleware classes modify requests/responses before or after route handling.
- Use for authentication, CORS, logging, or content manipulation.
- Method names follow conventions: `before_`, `after_`, or `before_and_after_` prefixes.
- Return modified `(request, response)` tuples from methods.
  :::

## Defining a Middleware Class

Create a class with static methods for events. Prefixes determine when they fire.

```python
# src/app/middleware.py (or any file, import accordingly)

class MiddleWare:
    @staticmethod
    def before_route(request, response):
        response.headers['Tina4-Control-Allow-Origin-Before'] = '*'
        response.content = "Before"  # Initialize or modify content
        return request, response

    @staticmethod
    def before_something_else(request, response):
        response.headers['Tina4-Control-Allow-Origin-Before-Something-Else'] = '*'
        response.content = "Before Something Else"
        return request, response

    @staticmethod
    def after_route(request, response):
        response.headers['Tina4-Control-Allow-Origin-After'] = '*'
        response.content += " After"
        return request, response

    @staticmethod
    def some_other(request, response):
        response.content += " Some Other"
        return request, response
    
    @staticmethod
    def before_and_after_route(request, response):
        response.headers['Tina4-Control-Allow-Origin-BEFORE_AFTER'] = '*'
        response.content += " Before and After"
        return request, response
```

- Methods run based on prefixes: `before_` before route, `after_` after, `before_and_after_` both.
- Useful for headers (e.g., CORS), authentication, or content changes.

## Attaching Middleware to Routes {#routes}

Import and apply `@middleware` decorator before route decorators. Fires all matching methods by default.

```python
# src/routes/example.py (include in src/__init__.py)

from tina4_python.Router import get, middleware
from src.app.middleware import MiddleWare  # Adjust import path

# All methods fire based on naming
@middleware(MiddleWare)
@get("/test/redirect")
async def redirect(request, response):
    return response.redirect("/hello/world")

# Specify events to fire
@middleware(MiddleWare, ["some_other"])
@get("/system/roles/data")
async def system_roles(request, response):
    print("roles")
    return response("OK")
```

- `@middleware(ClassName)`: Applies to the route.
- Optional list: Limits to specific methods (e.g., `["before_route", "after_route"]`).
- Multiple middlewares stackable by adding more `@middleware` decorators.