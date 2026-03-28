# Chapter 26: Upgrading from v2 to v3

## 1. Overview

Tina4 v3 is a ground-up rewrite. Zero external dependencies. Pure Python stdlib. The framework does more with less.

The concepts are the same -- routing, ORM, templates, migrations, authentication. The APIs are cleaner. The internals are simpler. If you built something with v2, you will recognise everything in v3. But the import paths, decorators, and project layout have all changed.

This chapter covers every breaking change and the migration path for each one. Read it top to bottom before you start, then use the checklist at the end.

---

## 2. Package and Installation

v2 installed with pip and pulled in external dependencies:

```bash
# v2
pip install tina4_python
```

v3 uses `uv` (recommended) or pip. Zero external dependencies:

```bash
# v3
uv add tina4-python

# or with pip
pip install tina4-python
```

v3 requires Python 3.12 or later. Check your version:

```bash
python --version
```

If you are on 3.11 or earlier, upgrade Python first. v3 uses features from 3.12 that cannot be backported.

---

## 3. Project Structure Changes

v2 used a flat structure. Routes, models, and templates could live anywhere. v3 expects a standard layout:

```
project/
  .env
  app.py
  src/
    routes/
      products.py
      users.py
    orm/
      product.py
      user.py
    templates/
      index.twig
      layout.twig
    app/
      helpers.py
      services.py
```

v3 auto-discovers every `.py` file in `src/` and its subdirectories. No manual imports. No registration. Drop a file in `src/routes/` and it loads at startup.

The framework adds your project root (CWD) to `sys.path`, so imports like this work everywhere:

```python
from src.app.helpers import format_currency
from src.orm.product import Product
```

If you have v2 code scattered across the project root, move it into the appropriate `src/` subdirectory. The `tina4 init python .` command creates this structure for you.

---

## 4. Routing Changes

### Decorators

v2 used `@route.get()`. v3 uses standalone decorators:

```python
# v2
from tina4_python import route

@route.get("/products")
def list_products(request, response):
    return response.json({"products": []})

# v3
from tina4_python.core.router import get

@get("/products")
async def list_products(request, response):
    return response.json({"products": []})
```

Import all HTTP methods from one place:

```python
from tina4_python.core.router import get, post, put, patch, delete
```

### Auth Defaults

v3 changes the default auth behaviour. GET routes are public. POST, PUT, PATCH, and DELETE routes require authentication.

To make a write route public, use `@noauth()`:

```python
from tina4_python.core.router import post, noauth

@noauth()
@post("/api/feedback")
async def submit_feedback(request, response):
    return response.json({"status": "received"}, 201)
```

To protect a GET route, use `@secured()`:

```python
from tina4_python.core.router import get, secured

@secured()
@get("/admin/dashboard")
async def admin_dashboard(request, response):
    return response.render("admin/dashboard.twig")
```

### Decorator Order

Order matters. Stack them outermost to innermost:

1. `@noauth()` or `@secured()` (auth control)
2. `@description("...")` (Swagger docs)
3. `@get("/path")` or `@post("/path")` (route binding)

```python
@noauth()
@description("Submit anonymous feedback")
@post("/api/feedback")
async def submit_feedback(request, response):
    return response.json({"status": "received"}, 201)
```

### Middleware

Middleware uses a decorator. It works in any order relative to the route decorator:

```python
from tina4_python.core.router import get, middleware
from src.app.rate_limiter import RateLimiter

@middleware(RateLimiter)
@get("/api/data")
async def get_data(request, response):
    return response.json({"data": []})
```

### Wildcard Routes

Wildcard routes now work correctly in v3:

```python
@get("/api/*")
async def catch_all(request, response):
    return response.json({"path": request.path})
```

---

## 5. Database Changes

### Connection URL

v2 imported `Database` from the top-level package. v3 imports from `tina4_python.database`:

```python
# v2
from tina4_python import Database
db = Database("sqlite3", "data/app.db")

# v3
from tina4_python.database import Database
db = Database("sqlite:///data/app.db")
```

URL format examples:

```python
# SQLite
db = Database("sqlite:///data/app.db")

# PostgreSQL
db = Database("postgresql://localhost:5432/myapp", "user", "password")

# Firebird
db = Database("firebird://localhost:3050//var/data/app.fdb", "SYSDBA", "masterkey")
```

### Keyword Arguments

v3 passes `**kwargs` through to the underlying driver. Useful for Firebird charset, connection timeouts, and other driver-specific options:

```python
db = Database("firebird://localhost:3050//var/data/app.fdb", "SYSDBA", "masterkey", charset="ISO8859_1")
```

### Firebird Column Names

v3 lowercases all Firebird column names. This makes Firebird consistent with every other adapter. Update your code:

```python
# v2
email = row["EMAIL"]
first_name = row["FIRST_NAME"]

# v3
email = row["email"]
first_name = row["first_name"]
```

Search your codebase for uppercase column access. Every instance needs updating.

### Firebird Drivers

v3 supports both `firebird-driver` (modern, recommended) and `fdb` (legacy). It tries `firebird-driver` first, falls back to `fdb`. Install the one you prefer:

```bash
uv add firebird-driver    # recommended
# or
uv add fdb                # legacy fallback
```

### Transactions

Use the database object's transaction methods. Never use raw SQL for transaction control:

```python
# Correct
db.start_transaction()
db.execute("INSERT INTO products (name) VALUES (?)", ["Widget"])
db.commit()

# Wrong -- do not do this
db.execute("BEGIN")
db.execute("INSERT INTO products (name) VALUES (?)", ["Widget"])
db.execute("COMMIT")
```

### Connection Pooling

v3 adds connection pooling. Pass the `pool` parameter:

```python
db = Database("postgresql://localhost:5432/myapp", "user", "password", pool=4)
```

This creates a pool of 4 connections. The framework manages checkout and return.

---

## 6. ORM Changes

### Field Definitions

v2 field definitions varied. v3 uses typed field classes:

```python
# v2
class Product:
    table_name = "products"
    id = None
    name = None
    price = None

# v3
from tina4_python.orm import ORM, orm_bind, IntegerField, StringField, FloatField

class Product(ORM):
    table_name = "products"
    id = IntegerField(primary_key=True)
    name = StringField()
    price = FloatField()
```

### Binding the Database

Call `orm_bind(db)` before using any ORM class. Do this once in `app.py`:

```python
from tina4_python.database import Database
from tina4_python.orm import orm_bind

db = Database("sqlite:///data/app.db")
orm_bind(db)
```

### Auto Mapping

Set `auto_map = True` on your ORM class for automatic snake_case to camelCase field mapping. This exists for cross-language parity (Python, PHP, Ruby, Node.js all share the same ORM concepts):

```python
class UserProfile(ORM):
    table_name = "user_profiles"
    auto_map = True
    id = IntegerField(primary_key=True)
    first_name = StringField()
    last_name = StringField()
```

### Field Mapping

For columns that do not follow conventions, use `field_mapping`:

```python
class LegacyUser(ORM):
    table_name = "tbl_users"
    field_mapping = {
        "user_id": "usr_id",
        "email": "usr_email",
        "name": "usr_full_name"
    }
    user_id = IntegerField(primary_key=True)
    email = StringField()
    name = StringField()
```

### Relationships

v3 adds `has_many`, `has_one`, and `belongs_to` with eager loading:

```python
from tina4_python.orm import ORM, IntegerField, StringField, has_many, belongs_to

class Customer(ORM):
    table_name = "customers"
    id = IntegerField(primary_key=True)
    name = StringField()
    orders = has_many("Order", "customer_id")

class Order(ORM):
    table_name = "orders"
    id = IntegerField(primary_key=True)
    customer_id = IntegerField()
    total = FloatField()
    customer = belongs_to("Customer", "customer_id")
```

---

## 7. Template Engine Changes

### Frond Replaces Template

v2 used a `Template` class. v3 uses the Frond engine, which is Jinja2/Twig-compatible:

```python
# v2
return response.template("page.html", {"title": "Home"})

# v3
return response.render("page.twig", {"title": "Home"})
```

Frond is a singleton. It is created once at startup and reused for every request.

### Custom Filters

Register filters in `app.py` before calling `run()`:

```python
from tina4_python.template import Frond

def money(value):
    return f"${value:,.2f}"

Frond.add_filter("money", money)
```

Use in templates:

```twig
{{ product.price | money }}
```

### Custom Globals

Add global variables available in every template:

```python
Frond.add_global("APP_NAME", "My Store")
Frond.add_global("YEAR", 2026)
```

```twig
<footer>&copy; {{ YEAR }} {{ APP_NAME }}</footer>
```

### New Template Features

v3 Frond supports method calls on dict values:

```twig
{{ user.t("greeting") }}
```

Python slice syntax works:

```twig
{{ text[:10] }}
{{ items[1:3] }}
```

---

## 8. Migration Tracking Table

v2 used a `tina4_migration` table with a `description` column.

v3 uses an expanded schema:

| Column | Type | Description |
|--------|------|-------------|
| `migration_id` | text | Unique identifier |
| `description` | text | Migration description |
| `batch` | integer | Batch number |
| `executed_at` | timestamp | When it ran |
| `passed` | boolean | Whether it succeeded |

You do not need to alter the table yourself. Run `tina4 migrate` and v3 auto-detects the v2 schema. It adds the missing columns and backfills `migration_id` from `description`. Your existing migration history is preserved.

```bash
tina4 migrate
```

That is it. No manual SQL. No data loss.

---

## 9. Authentication Changes

v2 had various auth approaches. v3 consolidates into an `Auth` class:

```python
from tina4_python.auth import Auth

# Generate a token
token = Auth.get_token({"user_id": 42, "role": "admin"})

# Validate a token
is_valid = Auth.valid_token(token)

# Extract the payload
payload = Auth.get_payload(token)
```

Password hashing:

```python
hashed = Auth.hash_password("my-secret-password")
matches = Auth.check_password(hashed, "my-secret-password")  # True
```

JWT uses HMAC-SHA256. Set the signing key in `.env`:

```env
SECRET=your-long-random-secret-key
```

Token lifetime defaults to 60 minutes. Override with:

```env
TINA4_TOKEN_LIMIT=120
```

---

## 10. Session Changes

v2 had basic file-based sessions. v3 supports pluggable backends.

Set the backend in `.env`:

```env
TINA4_SESSION_BACKEND=file
```

Available backends:

| Value | Backend | Package Required |
|-------|---------|-----------------|
| `file` | Local filesystem (default) | None |
| `redis` | Redis | `redis` |
| `valkey` | Valkey | `valkey` |
| `mongodb` | MongoDB | `pymongo` |
| `database` | Database table | None |

Session cookies default to `SameSite=Lax`. Override with:

```env
TINA4_SESSION_SAMESITE=Strict
```

---

## 11. New Features in v3

v3 adds capabilities that did not exist in v2. Each has its own chapter:

- **Events system** -- publish and subscribe to application events (Chapter 20)
- **GraphQL engine** -- schema-first GraphQL with resolvers (Chapter 18)
- **WSDL/SOAP services** -- consume and expose SOAP endpoints
- **WebSocket with Redis backplane** -- real-time with horizontal scaling (Chapter 14)
- **Response caching middleware** -- cache responses with TTL and invalidation (Chapter 16)
- **DI container** -- dependency injection for services and repositories
- **Queue system** -- RabbitMQ, Kafka, and MongoDB backends (Chapter 13)
- **Swagger/OpenAPI auto-generation** -- live API docs from route decorators (Chapter 11)
- **Auto-CRUD endpoint generator** -- CRUD routes from ORM models with one line
- **Seeder/fake data** -- populate databases with realistic test data
- **i18n translations** -- multi-language support with translation files
- **AI coding assistant context** -- `tina4 ai` generates context for LLM coding tools
- **Error overlay in dev mode** -- stack traces rendered in the browser
- **SCSS auto-compilation** -- `.scss` files compiled to CSS on change

You do not need to adopt all of these at once. They are opt-in. Migrate your existing code first, then add new features as you need them.

---

## 12. Step-by-Step Migration Checklist

Follow this order. Each step builds on the previous one.

1. **Install v3**
   ```bash
   uv add tina4-python
   ```

2. **Create the v3 project structure**
   ```bash
   tina4 init python .
   ```
   This creates `src/routes/`, `src/orm/`, `src/templates/`, and `src/app/` if they do not exist. It will not overwrite existing files.

3. **Move route files to `src/routes/`**
   Update imports from `from tina4_python import route` to `from tina4_python.core.router import get, post, put, patch, delete`. Replace `@route.get()` with `@get()`. Make handler functions `async`.

4. **Move ORM models to `src/orm/`**
   Replace raw field definitions with typed fields: `IntegerField`, `StringField`, `FloatField`, `TextField`. Add `orm_bind(db)` in `app.py`.

5. **Move templates to `src/templates/`**
   Replace `response.template()` calls with `response.render()`. Templates are Twig-compatible -- most existing templates work without changes.

6. **Update `app.py`**
   ```python
   from tina4_python.core import run
   run()
   ```

7. **Update database connections**
   Switch to URL format in `.env`:
   ```env
   DATABASE_URL=sqlite:///data/app.db
   ```

8. **Run migrations**
   ```bash
   tina4 migrate
   ```
   The tracking table upgrades automatically.

9. **Fix Firebird column names**
   Search for uppercase column access (`row["UPPER"]`) and change to lowercase (`row["upper"]`). Only applies if you use Firebird.

10. **Start the server and test**
    ```bash
    tina4 serve
    ```
    Hit every route. Check the logs for errors.

11. **Run the doctor**
    ```bash
    tina4 doctor
    ```
    This verifies your project structure, database connection, and configuration.

---

That covers the migration. Most projects take under an hour. The biggest time sink is updating import paths and decorators -- a find-and-replace handles the bulk of it. Once you are running on v3, you get zero dependencies, faster startup, and access to every new feature listed in section 11.
