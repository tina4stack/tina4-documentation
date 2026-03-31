# Chapter 19: CLI & Scaffolding

## 1. Getting a New Developer Up to Speed

Monday morning. A new developer joins your team. You hand them the repo URL. By 10am they have a running project, a new database model, CRUD routes, a migration, and a deployment to staging. All from the command line. No documentation scavenger hunt. No boilerplate copy-paste.

The Tina4 CLI is a single Rust binary. It manages all four Tina4 frameworks (PHP, Python, Ruby, Node.js). The commands are identical across languages. Learn the CLI for Python. You know it for PHP.

---

## 2. tina4 init -- Project Scaffolding

You saw this in Chapter 1. Now the details.

```bash
tina4 init my-project
```

```
Creating Tina4 project in ./my-project ...
  Detected language: Python (pyproject.toml)
  Created .env
  Created .env.example
  Created .gitignore
  Created src/routes/
  Created src/orm/
  Created src/migrations/
  Created src/seeds/
  Created src/templates/
  Created src/templates/errors/
  Created src/public/
  Created src/public/js/
  Created src/public/css/
  Created src/public/scss/
  Created src/public/images/
  Created src/public/icons/
  Created src/locales/
  Created data/
  Created logs/
  Created secrets/
  Created tests/

Project created! Next steps:
  cd my-project
  uv sync
  tina4 serve
```

### Language Detection

The CLI detects the language from existing files:

| File Present | Language |
|-------------|----------|
| `composer.json` | PHP |
| `pyproject.toml` or `requirements.txt` | Python |
| `Gemfile` | Ruby |
| `package.json` | Node.js |

If no language-specific file exists, the CLI asks:

```bash
tina4 init my-project
```

```
No language detected. Which language?
  1. PHP
  2. Python
  3. Ruby
  4. Node.js
> 2

Creating Tina4 Python project in ./my-project ...
```

### Explicit Language Selection

Skip the prompt by specifying the language:

```bash
tina4 init python my-project
```

This creates a Python project with `pyproject.toml`, `app.py`, and the full directory structure.

### Init into an Existing Directory

Already have a project? Add Tina4 structure:

```bash
cd existing-project
tina4 init .
```

The CLI creates only files and directories that do not exist. It never overwrites.

---

## 3. tina4 serve -- Dev Server

```bash
tina4 serve
```

```
  Tina4 Python v3.0.0
  HTTP server running at http://0.0.0.0:7145
  WebSocket server running at ws://0.0.0.0:7145
  Live reload enabled
  Press Ctrl+C to stop
```

`tina4 serve` detects the language and starts the appropriate server. For Python, it runs `uv run python app.py` with live reload enabled.

### Options

```bash
tina4 serve --port 8080        # Custom port
tina4 serve --host 127.0.0.1   # Bind to localhost only
tina4 serve --production       # Production mode (no live reload, debug off)
```

### Direct Python Execution

You can start the server with Python:

```bash
uv run python app.py
```

This is identical to `tina4 serve` but gives you more control over the Python runtime.

---

## 4. tina4 generate model -- ORM Scaffolding

The `generate model` command creates an ORM model file and a matching migration. One command produces both.

```bash
tina4 generate model Product
```

```
Created src/orm/product.py
Created src/migrations/20260322120000_create_products_table.sql
```

The generated model:

```python
from tina4_python.orm import ORM

class Product(ORM):
    table_name = "products"
    id: int
    created_at: str
```

The generated migration:

```sql
-- UP
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS products;
```

The model is ready to use. Add your fields and run migrations.

### Adding Fields

Specify fields on the command line:

```bash
tina4 generate model Product --fields "name:string,price:float,category:string,in_stock:bool"
```

The generated model includes all the fields:

```python
from tina4_python.orm import ORM

class Product(ORM):
    table_name = "products"
    id: int
    name: str
    price: float
    category: str
    in_stock: bool
    created_at: str
```

And the migration:

```sql
-- UP
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL DEFAULT '',
    price REAL NOT NULL DEFAULT 0,
    category TEXT NOT NULL DEFAULT '',
    in_stock INTEGER NOT NULL DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS products;
```

### Field Types

| CLI Type | Python Type | SQLite Column |
|----------|------------|---------------|
| `string` | `str` | `TEXT` |
| `int` | `int` | `INTEGER` |
| `float` | `float` | `REAL` |
| `bool` | `bool` | `INTEGER` |
| `text` | `str` | `TEXT` |
| `date` | `str` | `TEXT` |

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--fields` | Comma-separated field definitions | `--fields "name:string,price:float"` |
| `--auto-crud` | Enable auto-CRUD on the model | `--auto-crud` |
| `--soft-delete` | Add soft delete support | `--soft-delete` |
| `--no-migration` | Skip migration generation | `--no-migration` |
| `--with-route` | Also generate a CRUD route file | `--with-route` |

---

## 5. tina4 generate route -- CRUD Route Scaffolding

The `generate route` command creates a complete CRUD route file with all five REST endpoints. It reads the model's properties and builds routes with proper imports and response handling.

```bash
tina4 generate route products
```

```
Created src/routes/products.py
```

The generated route file:

```python
from tina4_python.core.router import get, post, put, delete

@get("/api/products")
async def list_products(request, response):
    page = int(request.params.get("page", 1))
    per_page = int(request.params.get("per_page", 20))
    offset = (page - 1) * per_page

    products, total = Product.where("1=1", [], limit=per_page, offset=offset)
    results = [p.to_dict() for p in products]

    return response({
        "data": results,
        "page": page,
        "per_page": per_page,
        "count": len(results)
    })


@get("/api/products/{product_id}")
async def get_product(request, response):
    product = Product.find(request.params["product_id"])

    if product is None:
        return response({"error": "Product not found"}, 404)

    return response(product.to_dict())


@post("/api/products")
async def create_product(request, response):
    body = request.body

    product = Product()
    product.name = body.get("name", "")
    product.price = float(body.get("price", 0))
    product.category = body.get("category", "")
    product.in_stock = bool(body.get("in_stock", False))
    product.save()

    return response(product.to_dict(), 201)


@put("/api/products/{product_id}")
async def update_product(request, response):
    product = Product.find(request.params["product_id"])

    if product is None:
        return response({"error": "Product not found"}, 404)

    body = request.body
    if "name" in body:
        product.name = body["name"]
    if "price" in body:
        product.price = float(body["price"])
    if "category" in body:
        product.category = body["category"]
    if "in_stock" in body:
        product.in_stock = bool(body["in_stock"])
    product.save()

    return response(product.to_dict())


@delete("/api/products/{product_id}")
async def delete_product(request, response):
    product = Product.find(request.params["product_id"])

    if product is None:
        return response({"error": "Product not found"}, 404)

    product.delete()
    return response(None, 204)
```

The generator reads the model's properties and creates routes with type casting and None checks. Customize the generated code immediately. It is regular Python, not magic.

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--prefix` | Custom route prefix (default: `/api`) | `--prefix /api/v2` |
| `--middleware` | Add middleware to all routes | `--middleware auth_middleware` |

---

## 6. tina4 generate migration -- Migration Scaffolding

The `generate migration` command creates a timestamped migration file with `UP` and `DOWN` sections. The timestamp ensures migrations run in order.

```bash
tina4 generate migration add_category_to_products
```

```
Created src/migrations/20260322120500_add_category_to_products.sql
```

The generated file:

```sql
-- UP
-- Add your forward migration SQL here


-- DOWN
-- Add your rollback migration SQL here

```

Fill in the SQL:

```sql
-- UP
ALTER TABLE products ADD COLUMN category TEXT DEFAULT '';

-- DOWN
ALTER TABLE products DROP COLUMN category;
```

The timestamp prefix (`20260322120500`) ensures migrations run in order. Each migration runs once. The framework tracks which ones have been applied.

### When to Generate a Migration

Generate a new migration when you need to change the database schema after the initial model migration. Adding a column. Creating an index. Renaming a table. Each change gets its own migration file with a unique timestamp.

---

## 7. tina4 generate middleware -- Middleware Scaffolding

The `generate middleware` command creates a middleware function with the correct signature and a placeholder for your logic.

```bash
tina4 generate middleware rate_limit
```

```
Created src/middleware/rate_limit.py
```

The generated file:

```python
async def rate_limit(request, response, next_handler):
    # Add your middleware logic here

    # Continue to the next middleware or route handler
    return await next_handler(request, response)

    # Or return early to block the request:
    # return response({"error": "Rate limit exceeded"}, 429)
```

The middleware is a named function. Reference it in route definitions:

```python
@get("/api/data", middleware=["rate_limit"])
async def protected_data(request, response):
    return response({"data": "protected"})
```

---

## 8. Generate All at Once

Combine flags to generate multiple files in a single command:

```bash
tina4 generate model Product --with-route --with-migration
```

```
Created src/orm/product.py
Created src/routes/products.py
Created src/migrations/20260322120000_create_products_table.sql
```

Model. CRUD routes. Migration. All wired together. Ready to use.

---

## 9. tina4 doctor -- Health Check

The `doctor` command checks your project for common issues:

```bash
tina4 doctor
```

```
Tina4 Doctor -- Checking your project...

  [OK] Python 3.12.0 detected
  [OK] uv package manager found
  [OK] tina4_python package installed (v3.0.0)
  [OK] .env file exists
  [OK] Database connection: sqlite:///data/app.db
  [OK] Database is accessible
  [OK] src/routes/ directory exists (3 route files)
  [OK] src/orm/ directory exists (2 model files)
  [OK] src/templates/ directory exists (5 templates)
  [OK] src/public/ directory exists (static files served)
  [OK] tests/ directory exists (4 test files)
  [WARN] No migrations found in src/migrations/
  [OK] AI context: Claude Code detected, CLAUDE.md present
  [OK] .gitignore includes .env, data/, logs/

  12 checks passed, 1 warning, 0 errors
```

Doctor checks:

- Python version and package manager
- Tina4 package installation and version
- `.env` file existence and critical variables
- Database connectivity
- Directory structure
- Missing files or configurations
- AI tool context files
- Git configuration

The warnings give actionable advice. If your database is not configured, it tells you exactly what to add to `.env`.

---

## 10. tina4 test -- Running Tests

```bash
tina4 test
```

```
Running tests...

  ProductTest
    [PASS] test_create_product
    [PASS] test_load_product

  2 tests, 2 passed, 0 failed (0.12s)
```

This runs all tests in the `tests/` directory. See Chapter 17 for full testing documentation.

### Test Options

```bash
tina4 test --file tests/test_product.py           # Specific file
tina4 test --file tests/test_product.py --method test_create  # Specific method
tina4 test --verbose                                # Show assertion details
```

---

## 11. tina4 routes -- Route Listing

See all registered routes in your project:

```bash
tina4 routes
```

```
Registered Routes:

  Method  Path                        Handler                     Middleware
  ------  --------------------------  --------------------------  ----------
  GET     /health                     health_check                -
  GET     /api/products               list_products               ResponseCache:300
  GET     /api/products/{product_id}  get_product                 -
  POST    /api/products               create_product              auth_middleware
  PUT     /api/products/{product_id}  update_product              auth_middleware
  DELETE  /api/products/{product_id}  delete_product              auth_middleware
  GET     /api/auth/login             -                           -
  POST    /api/auth/login             login                       -
  GET     /admin                      admin_dashboard             -

  9 routes registered
```

This is useful for verifying that your routes are registered and for finding the handler function for a specific URL.

### Filtering

```bash
tina4 routes --method POST          # Filter by HTTP method
tina4 routes --filter products      # Filter by path pattern
tina4 routes --middleware auth      # Filter by middleware
```

When debugging routing issues, check here first. If a route does not match, `tina4 routes` shows whether it was registered and what middleware is attached.

---

## 12. tina4 migrate -- Database Migrations

Run pending migrations:

```bash
tina4 migrate
```

```
Running migrations...
  [UP] 20260322000100_create_users_table.sql
  [UP] 20260322000200_create_products_table.sql
  [UP] 20260322000300_add_category_to_products.sql

  3 migrations applied
```

### Rollback

```bash
tina4 migrate --down
```

```
Rolling back last migration...
  [DOWN] 20260322000300_add_category_to_products.sql

  1 migration rolled back
```

### Migration Table Auto-Upgrade

If your project was created with an earlier version of Tina4, the `tina4_migration` tracking table may use the older v2 schema. Running `tina4 migrate` detects the old layout and adds the missing `migration_id`, `batch`, and `executed_at` columns, backfilling existing data. No manual intervention needed.

### Status

```bash
tina4 migrate --status
```

```
Migration Status:

  Status    Migration
  --------  -----------------------------------------
  Applied   20260322000100_create_users_table.sql
  Applied   20260322000200_create_products_table.sql
  Applied   20260322000300_add_category_to_products.sql
  Pending   20260322000400_create_orders_table.sql

  3 applied, 1 pending
```

---

## 13. Exercise: Scaffold a Feature in 5 Commands

Scaffold a complete "Customer" feature from scratch using only CLI commands.

### Requirements

Starting from an existing Tina4 Python project, run 5 commands to create:

1. A Customer ORM model with name, email, phone, and company fields
2. A CRUD route file with all five REST endpoints
3. A migration that creates the customers table
4. Run the migration to create the table
5. Run the doctor to verify everything

### Expected Commands

```bash
# 1. Generate the model with route and migration
tina4 generate model Customer --with-route --with-migration

# 2. Edit the model to add fields (manual step)
# Add fields to src/orm/customer.py

# 3. Edit the migration to add columns (manual step)
# Add columns to the migration file

# 4. Run the migration
tina4 migrate

# 5. Run the doctor to verify everything is set up
tina4 doctor
```

### Solution

**Command 1:** Generate everything:

```bash
tina4 generate model Customer --with-route --with-migration
```

**Command 2:** Edit `src/orm/customer.py`:

```python
from tina4_python.orm import ORM

class Customer(ORM):
    table_name = "customers"

    id: int
    name: str
    email: str
    phone: str
    company: str
    created_at: str
```

**Command 3:** Edit the migration file:

```sql
-- UP
CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    company TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_email ON customers(email);

-- DOWN
DROP TABLE IF EXISTS customers;
```

**Command 4:** Run the migration:

```bash
tina4 migrate
```

```
Running migrations...
  [UP] 20260322120000_create_customers_table.sql

  1 migration applied
```

**Command 5:** Verify with doctor:

```bash
tina4 doctor
```

```
  [OK] src/orm/ directory exists (3 model files)
  [OK] src/routes/ directory exists (4 route files)
  [OK] Database connection: sqlite:///data/app.db
  ...
```

Now test the API:

```bash
curl -X POST http://localhost:7145/api/customers \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Corp", "email": "alice@corp.com", "phone": "+1-555-0100", "company": "Alice Corp"}'
```

```json
{
  "id": 1,
  "name": "Alice Corp",
  "email": "alice@corp.com",
  "phone": "+1-555-0100",
  "company": "Alice Corp",
  "created_at": "2026-03-22 12:00:00"
}
```

From zero to a working CRUD API. Five commands. Under two minutes.

---

## 14. Gotchas

### 1. tina4 Command Not Found

**Problem:** Running `tina4` gives "command not found".

**Cause:** The Tina4 CLI is not installed or not in your PATH.

**Fix:** Install the CLI: `curl -fsSL https://tina4.com/install.sh | sh`. Verify with `tina4 --version`. If installed but not found, add the installation directory to your PATH:

```bash
echo 'export PATH="$HOME/.tina4/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 2. Wrong Language Detected

**Problem:** `tina4 init` creates a PHP project instead of Python.

**Cause:** A `composer.json` file exists in the directory from a previous project.

**Fix:** Use explicit language selection: `tina4 init python my-project`. Or delete the conflicting language file before running `init`.

### 3. Generated Files Overwrite Existing Code

**Problem:** Running `tina4 generate route products` overwrites your custom route file.

**Cause:** The generate command creates files at fixed paths. If the file exists, it is overwritten.

**Fix:** The CLI warns you before overwriting. Check if the file exists first. If you need to regenerate, rename the existing file: `mv src/routes/products.py src/routes/products_backup.py`.

### 4. Migration Order Issues

**Problem:** A migration fails because it references a table that does not exist yet.

**Cause:** Migration files run in alphabetical (timestamp) order. If migration B depends on a table created by migration A, but A has a later timestamp, B runs first and fails.

**Fix:** Use consistent timestamps. The `tina4 generate migration` command uses the current timestamp. Generating migrations in order ensures correct execution order. If you need to fix ordering, rename the migration files to adjust their timestamps.

### 5. tina4 serve Uses Wrong Port

**Problem:** `tina4 serve` starts on port 7145 but you need port 8080.

**Cause:** The default port is 7145 unless overridden.

**Fix:** Set it in `.env`: `TINA4_PORT=8080`. Or pass it as a flag: `tina4 serve --port 8080`. The `.env` value takes precedence over the default. The command-line flag overrides everything.

### 6. Doctor Shows False Warnings

**Problem:** `tina4 doctor` warns about missing migrations, but your project does not use migrations.

**Cause:** Doctor checks for common conventions. It warns about missing migrations regardless of your approach.

**Fix:** These are warnings, not errors. Ignore warnings that do not apply to your project. Doctor is a guide, not a gatekeeper.

### 7. Generate Creates Python 3.12+ Syntax

**Problem:** Generated code uses `type: int` syntax that does not work in Python 3.10.

**Cause:** The generator targets the latest Python version supported by Tina4.

**Fix:** Use Python 3.12 or later with Tina4 Python. Check your Python version with `python --version`. If you must use an older version, modify the generated code to use compatible syntax.

### 8. Model Name Must Be PascalCase

**Problem:** `tina4 generate model order_item` creates a model class named `order_item` which is not valid Python convention.

**Cause:** The CLI uses the argument as-is for the class name.

**Fix:** Use PascalCase for model names: `tina4 generate model OrderItem`. The CLI converts it to snake_case for the table name (`order_items`).
