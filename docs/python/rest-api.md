# REST APIs

::: tip Hot Tips
- POST, PUT, PATCH, DELETE routes require a valid token by default
- Use `@noauth()` to make a write route public (e.g. webhooks)
- Use `@secured()` to protect a GET route that needs auth
- Return a `dict` or `list` from `response()` and the framework sets `application/json` automatically
- `request.body` is already parsed — JSON comes in as a `dict`, no manual decoding needed
  :::

## A Simple GET Endpoint {#simple-get}

```python
from tina4_python.Router import get

@get("/api/status")
async def api_status(request, response):
    return response({"status": "ok", "version": "1.0.0"})
```

- Returns JSON automatically because the argument is a `dict`
- GET routes are **public by default** — no token required

## Path Parameters {#path-params}

Use `{name}` in the route path. The value is injected as a function argument:

```python
@get("/api/users/{id}")
async def get_user(id, request, response):
    user = User()
    if not user.load("id = ?", [id]):
        return response({"error": "User not found"}, 404)
    return response(user.to_dict())
```

### Typed Parameters

| Syntax           | Type    | Example match        |
|------------------|---------|----------------------|
| `{id}`           | `str`   | `/users/42`          |
| `{id:int}`       | `int`   | `/users/42`          |
| `{price:float}`  | `float` | `/products/9.99`     |
| `{path:path}`    | `str`   | `/files/docs/a/b.pdf` (greedy) |

```python
@get("/api/products/{id:int}")
async def get_product(id, request, response):
    # id is already an int
    return response({"product_id": id})

@get("/api/files/{path:path}")
async def get_file(path, request, response):
    return response.file(path, root_path="src/public/uploads")
```

## POST with a JSON Body {#post-json}

POST routes **require a valid token by default** (CSRF/auth protection). The request body is automatically parsed based on `Content-Type`.

```python
from tina4_python.Router import post

@post("/api/users")
async def create_user(request, response):
    # request.body is already a dict for JSON requests
    name = request.body.get("name", "")
    email = request.body.get("email", "")

    if not name or not email:
        return response({"error": "name and email are required"}, 400)

    user = User({"name": name, "email": email})
    user.save()

    return response(user.to_dict(), 201)
```

**Client call:**

```bash
curl -X POST http://localhost:7145/api/users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name": "Alice", "email": "alice@example.com"}'
```

### How `request.body` is parsed

| Content-Type                        | `request.body` type |
|-------------------------------------|---------------------|
| `application/json`                  | `dict` or `list`    |
| `application/x-www-form-urlencoded` | `dict`              |
| `multipart/form-data`               | `dict` (files in `request.files`) |
| `text/plain`                        | `str`               |

## PUT, PATCH, DELETE {#other-methods}

```python
from tina4_python.Router import put, patch, delete

@put("/api/users/{id}")
async def update_user(id, request, response):
    user = User()
    if not user.load("id = ?", [id]):
        return response({"error": "Not found"}, 404)

    user.name = request.body.get("name", user.name)
    user.email = request.body.get("email", user.email)
    user.save()

    return response(user.to_dict())


@patch("/api/users/{id}")
async def patch_user(id, request, response):
    user = User()
    if not user.load("id = ?", [id]):
        return response({"error": "Not found"}, 404)

    # Only update fields that were sent
    for key, value in request.body.items():
        if hasattr(user, key):
            setattr(user, key, value)
    user.save()

    return response(user.to_dict())


@delete("/api/users/{id}")
async def delete_user(id, request, response):
    user = User()
    if not user.load("id = ?", [id]):
        return response({"error": "Not found"}, 404)

    user.delete()
    return response({"deleted": True})
```

## Authentication {#auth}

### How it works

- **GET** routes are public by default
- **POST, PUT, PATCH, DELETE** require a valid `Authorization: Bearer <token>` header
- Tokens are validated as either a static `API_KEY` or an RS256 JWT

### Getting a token

Set `API_KEY` in your `.env` file for a simple static token:

```bash
# .env
API_KEY=my-secret-api-key
```

Clients include it in the header:

```bash
curl -H "Authorization: Bearer my-secret-api-key" \
     http://localhost:7145/api/users
```

For JWT tokens, use the `Auth` class to generate them:

```python
from tina4_python.Auth import Auth

auth = Auth()
token = auth.get_token({"user_id": 1, "role": "admin"})
```

### `@secured()` — Protect a GET route

```python
from tina4_python.Router import get, secured

@secured()
@get("/api/admin/stats")
async def admin_stats(request, response):
    return response({"active_users": 42})
```

### `@noauth()` — Make a write route public

```python
from tina4_python.Router import post, noauth

@noauth()
@post("/api/webhook/stripe")
async def stripe_webhook(request, response):
    # No token required — public endpoint
    event = request.body
    return response({"received": True})
```

## Request Headers {#headers}

Headers are a plain `dict` with **lowercased keys**:

```python
@get("/api/debug")
async def debug_headers(request, response):
    auth = request.headers.get("authorization", "")
    content_type = request.headers.get("content-type", "")
    custom = request.headers.get("x-custom-header", "")

    return response({
        "auth": auth,
        "content_type": content_type,
        "custom": custom
    })
```

## Custom Response Headers {#response-headers}

Use `Response.add_header()` before returning:

```python
from tina4_python.Response import Response

@get("/api/data")
async def get_data(request, response):
    Response.add_header("X-Request-Id", "abc-123")
    Response.add_header("Cache-Control", "max-age=3600")
    return response({"data": [1, 2, 3]})
```

## Status Codes {#status-codes}

Pass the HTTP status code as the second argument to `response()`:

```python
return response({"created": True}, 201)          # Created
return response({"error": "Bad input"}, 400)      # Bad Request
return response({"error": "Unauthorized"}, 401)   # Unauthorized
return response({"error": "Not found"}, 404)      # Not Found
return response({"error": "Server error"}, 500)   # Internal Error
```

## Serving Files {#files}

`Response.file()` serves a file with automatic MIME type detection and directory traversal protection:

```python
@get("/api/download/{filename}")
async def download(filename, request, response):
    return response.file(filename, root_path="src/public/downloads")
```

## CORS {#cors}

Tina4 sends permissive CORS headers automatically on every response:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept, Authorization
```

OPTIONS pre-flight requests are handled automatically.

## Swagger Documentation {#swagger}

Add metadata to your routes and they appear in the Swagger UI at `/swagger`:

```python
from tina4_python.Router import post
from tina4_python import description, tags, example, example_response, secure

@post("/api/users")
@description("Create a new user account")
@tags(["users"])
@secure()
@example({"name": "Alice", "email": "alice@example.com"})
@example_response({"id": 1, "name": "Alice", "email": "alice@example.com"})
async def create_user(request, response):
    user = User(request.body)
    user.save()
    return response(user.to_dict(), 201)
```

See the [Swagger documentation](swagger.md) for the full list of decorators.

## Full Example — CRUD API {#full-example}

```python
from tina4_python import ORM, orm, Database
from tina4_python import IntegerField, StringField
from tina4_python.Router import get, post, put, delete, noauth
from tina4_python import description, tags, example, example_response

class Product(ORM):
    id    = IntegerField(primary_key=True, auto_increment=True)
    name  = StringField()
    price = StringField()

orm(Database("sqlite3:app.db"))
Product().create_table()


@get("/api/products")
@description("List all products")
@tags(["products"])
async def list_products(request, response):
    result = Product().select(limit=100)
    return response(result.to_array())


@get("/api/products/{id:int}")
@description("Get a single product")
@tags(["products"])
async def get_product(id, request, response):
    product = Product()
    if not product.load("id = ?", [id]):
        return response({"error": "Product not found"}, 404)
    return response(product.to_dict())


@post("/api/products")
@description("Create a product")
@tags(["products"])
@example({"name": "Widget", "price": "9.99"})
async def create_product(request, response):
    product = Product(request.body)
    product.save()
    return response(product.to_dict(), 201)


@put("/api/products/{id:int}")
@description("Update a product")
@tags(["products"])
@example({"name": "Widget Pro", "price": "19.99"})
async def update_product(id, request, response):
    product = Product()
    if not product.load("id = ?", [id]):
        return response({"error": "Product not found"}, 404)

    product.name = request.body.get("name", product.name)
    product.price = request.body.get("price", product.price)
    product.save()
    return response(product.to_dict())


@delete("/api/products/{id:int}")
@description("Delete a product")
@tags(["products"])
async def delete_product(id, request, response):
    product = Product()
    if not product.load("id = ?", [id]):
        return response({"error": "Product not found"}, 404)

    product.delete()
    return response({"deleted": True})
```

**Test it:**

```bash
# List (public)
curl http://localhost:7145/api/products

# Create (needs token)
curl -X POST http://localhost:7145/api/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"name": "Widget", "price": "9.99"}'

# Update
curl -X PUT http://localhost:7145/api/products/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"name": "Widget Pro", "price": "19.99"}'

# Delete
curl -X DELETE http://localhost:7145/api/products/1 \
  -H "Authorization: Bearer $API_KEY"
```
