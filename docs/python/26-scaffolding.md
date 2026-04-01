# Scaffolding

One command. Six files. A working CRUD feature with routes, templates, tests, and Swagger docs -- ready to run.

That is Tina4's scaffolding system. It generates the boilerplate you write by hand in every project: models, migrations, routes, forms, views, and tests. You describe what you want. The generators produce it.

---

## The CRUD Generator

This is the generator most developers reach for first. It creates everything a feature needs in one shot.

```bash
tina4python generate crud Product --fields "name:string,price:float"
```

That single command creates six files:

| # | File | Purpose |
|---|------|---------|
| 1 | `src/orm/Product.py` | ORM model with typed fields |
| 2 | `migrations/20260401_create_product.sql` | UP migration (CREATE TABLE) |
| 3 | `migrations/20260401_create_product.down.sql` | DOWN migration (DROP TABLE) |
| 4 | `src/routes/products.py` | CRUD routes with Swagger annotations |
| 5 | `src/templates/products/form.html` | Form template with typed inputs and `form_token` |
| 6 | `src/templates/products/view.html` | List and detail templates |
| 7 | `tests/test_products.py` | pytest stubs for all CRUD operations |

### What Each File Contains

The **model** maps the `product` table to a Python class:

```python
from tina4 import ORM

class Product(ORM):
    table_name = "product"
    fields = {
        "id": "integer",
        "name": "string",
        "price": "float",
        "created_at": "datetime",
        "updated_at": "datetime"
    }
```

The **migration** creates the table:

```sql
-- migrations/20260401_create_product.sql
CREATE TABLE product (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255),
    price FLOAT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

The **down migration** reverses it:

```sql
-- migrations/20260401_create_product.down.sql
DROP TABLE IF EXISTS product;
```

The **routes** file wires up five endpoints with Swagger docs:

```python
from tina4 import get, post, put, delete
from src.orm.Product import Product

@get("/api/products", description="List all products")
async def get_products(request, response):
    products = Product().select()
    return response(products)

@get("/api/products/{id}", description="Get a product by ID")
async def get_product(request, response):
    product = Product()
    product.id = request.params["id"]
    product.load()
    return response(product)

@post("/api/products", description="Create a product")
async def create_product(request, response):
    product = Product(request.body)
    product.save()
    return response(product, 201)

@put("/api/products/{id}", description="Update a product")
async def update_product(request, response):
    product = Product(request.body)
    product.id = request.params["id"]
    product.save()
    return response(product)

@delete("/api/products/{id}", description="Delete a product")
async def delete_product(request, response):
    product = Product()
    product.id = request.params["id"]
    product.delete()
    return response(None, 204)
```

The **form template** renders typed inputs with CSRF protection:

```html
<form method="POST" action="/api/products">
    <input type="hidden" name="form_token" value="{{ form_token }}">
    <label>Name</label>
    <input type="text" name="name" required>
    <label>Price</label>
    <input type="number" step="0.01" name="price" required>
    <button type="submit">Save</button>
</form>
```

The **test file** stubs out CRUD assertions:

```python
import pytest
from tina4 import App

@pytest.fixture
def client():
    app = App()
    return app.test_client()

def test_create_product(client):
    response = client.post("/api/products", json={"name": "Widget", "price": 9.99})
    assert response.status_code == 201

def test_list_products(client):
    response = client.get("/api/products")
    assert response.status_code == 200

def test_get_product(client):
    response = client.get("/api/products/1")
    assert response.status_code == 200

def test_update_product(client):
    response = client.put("/api/products/1", json={"name": "Updated Widget"})
    assert response.status_code == 200

def test_delete_product(client):
    response = client.delete("/api/products/1")
    assert response.status_code == 204
```

### Run It

After generating, run the migration and start the server:

```bash
tina4python migrate
tina4python serve
```

Open Swagger UI at `http://localhost:7145/swagger` and test every endpoint. The scaffolded code works out of the box.

---

## Individual Generators

The CRUD generator calls several smaller generators under the hood. You can call each one directly when you need a single piece.

### Model

```bash
tina4python generate model Product --fields "name:string,price:float"
```

Creates three files: the ORM model (`src/orm/Product.py`), the UP migration, and the DOWN migration. No routes, no templates, no tests.

### Route

```bash
tina4python generate route products --model Product
```

Creates one file: `src/routes/products.py` with CRUD endpoints and Swagger annotations. The model must exist first.

### Migration

```bash
tina4python generate migration add_category_to_product
```

Creates two files: `migrations/20260401_add_category_to_product.sql` and `migrations/20260401_add_category_to_product.down.sql`. Both are empty stubs. You write the SQL.

### Middleware

```bash
tina4python generate middleware AuthLog
```

Creates one file with before and after stubs:

```python
from tina4 import middleware

@middleware(before=True)
async def auth_log_before(request):
    print(f"Request: {request.method} {request.url}")
    return request

@middleware(after=True)
async def auth_log_after(request, response):
    print(f"Response: {response.status_code}")
    return response
```

### Test

```bash
tina4python generate test products --model Product
```

Creates one file: `tests/test_products.py` with pytest CRUD stubs.

### Form

```bash
tina4python generate form Product --fields "name:string,price:float"
```

Creates one file: `src/templates/products/form.html` with typed inputs and `form_token`.

### View

```bash
tina4python generate view Product --fields "name:string,price:float"
```

Creates two templates: a list view and a detail view in `src/templates/products/`.

---

## The Auth Generator

Authentication needs more than one file. The auth generator creates seven:

```bash
tina4python generate auth
```

| # | File | Purpose |
|---|------|---------|
| 1 | `src/orm/User.py` | User model with hashed password field |
| 2 | `migrations/20260401_create_user.sql` | UP migration |
| 3 | `migrations/20260401_create_user.down.sql` | DOWN migration |
| 4 | `src/routes/auth.py` | Login, register, logout routes |
| 5 | `src/templates/auth/login.html` | Login form |
| 6 | `src/templates/auth/register.html` | Registration form |
| 7 | `tests/test_auth.py` | Auth flow tests |

The generated routes handle password hashing, JWT token creation, and session management. The templates include CSRF tokens. The tests cover registration, login, invalid credentials, and logout.

Run the migration, start the server, and you have working auth:

```bash
tina4python migrate
tina4python serve
```

---

## Field Types

Generators accept these field types. Each type maps to a specific column type in migrations, input type in forms, and display format in views.

| Field Type | Migration Column | Form Input | View Display |
|------------|-----------------|------------|--------------|
| `string` | `VARCHAR(255)` | `<input type="text">` | Plain text |
| `int` | `INTEGER` | `<input type="number">` | Number |
| `float` | `FLOAT` | `<input type="number" step="0.01">` | Decimal |
| `bool` | `BOOLEAN` | `<input type="checkbox">` | Yes / No |
| `text` | `TEXT` | `<textarea>` | Paragraph |
| `datetime` | `DATETIME` | `<input type="datetime-local">` | Formatted date |
| `blob` | `BLOB` | `<input type="file">` | Download link |

### Table Naming Convention

Tina4 uses singular table names. The model name `Product` maps to the table `product`. The model name `OrderItem` maps to `order_item`. The generator handles the conversion.

---

## Combining Generators

Sometimes you want a model with routes but no form. Or a model with a migration but no test. The `--with` flags let you compose:

```bash
tina4python generate model Product --fields "name:string,price:float" --with-route --with-migration
```

Available flags:

| Flag | Adds |
|------|------|
| `--with-route` | CRUD route file |
| `--with-migration` | Migration files (included by default with model) |
| `--with-test` | Test file |
| `--with-form` | Form template |
| `--with-view` | View templates |

The `generate crud` command is equivalent to using all `--with` flags at once.

---

## Exercise: Scaffold a Blog

Build a blog with three resources using generators.

**Step 1:** Generate the auth system.

```bash
tina4python generate auth
```

**Step 2:** Scaffold the Post resource.

```bash
tina4python generate crud Post --fields "title:string,body:text,published:bool"
```

**Step 3:** Scaffold the Category resource.

```bash
tina4python generate crud Category --fields "name:string,description:text"
```

**Step 4:** Add a migration to link posts to categories.

```bash
tina4python generate migration add_category_id_to_post
```

Edit the migration to add the foreign key:

```sql
ALTER TABLE post ADD COLUMN category_id INTEGER REFERENCES category(id);
```

**Step 5:** Run all migrations and start the server.

```bash
tina4python migrate
tina4python serve
```

You now have a working blog with authentication, posts, categories, and Swagger documentation. Total commands: five. Total hand-written SQL: one line.

---

## Gotchas

### Generators Do Not Overwrite

If a file exists, the generator skips it and prints a warning. This protects your edits. To regenerate, delete the file first.

### Run Migrate After Generate

The model generator creates migration files. Those files do nothing until you run `tina4python migrate`. Generate and migrate are separate steps by design.

### File Naming Matters

The generator derives file names from the model name. `Product` becomes `Product.py` for the model and `products.py` for routes. Do not rename generated files unless you update all imports.

### Field Changes Need New Migrations

Changing `--fields` and re-running the generator does not update existing migrations. Create a new migration with `generate migration` and write the ALTER TABLE by hand.

### Singular Table Names

Tina4 uses singular table names: `product`, not `products`. The route paths use plural (`/api/products`), but the table stays singular. The generator handles this split.
