# Chapter 19: CLI & Scaffolding

## 1. Getting a New Developer Up to Speed

Monday morning. A new developer joins your team. You hand them the repo URL. By 10am they have a running project, a new database model, CRUD routes, a migration, and a deployment to staging. All from the command line. No documentation scavenger hunt. No boilerplate copy-paste.

The Tina4 CLI is a single Rust binary that manages all four Tina4 frameworks (PHP, Python, Ruby, Node.js). The commands are identical across languages. Learn the CLI for Python. You know it for PHP.

---

## 2. tina4 init -- Project Scaffolding

You saw this in Chapter 1, but let us look at it in detail.

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
  uv run python app.py
```

### Language Detection

The CLI detects the language from existing files in the directory:

| File Present | Language |
|-------------|----------|
| `composer.json` | PHP |
| `pyproject.toml` or `requirements.txt` | Python |
| `Gemfile` | Ruby |
| `package.json` | Node.js |

If no language-specific file exists, the CLI asks you:

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

This creates a Python project directly, including `pyproject.toml`, `app.py`, and the full directory structure.

### Init into an Existing Directory

If you already have a project and want to add Tina4 structure:

```bash
cd existing-project
tina4 init .
```

The CLI only creates files and directories that do not already exist. It never overwrites existing files.

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

You can also start the server directly with Python:

```bash
uv run python app.py
```

This is identical to `tina4 serve` but gives you more control over the Python runtime.

---

## 4. tina4 generate -- Code Generation

The `generate` command creates boilerplate code for common patterns. Every generated file follows Tina4 conventions and is immediately functional.

### Generate a Model

```bash
tina4 generate model Product
```

```
Created src/orm/product.py

  class Product(ORM):
      table_name = "products"
      id: int
      name: str
      created_at: str
```

The model is ready to use. Add your fields and run migrations.

### Generate a Route

```bash
tina4 generate route products
```

```
Created src/routes/products.py

  @get("/api/products")
  @get("/api/products/{product_id}")
  @post("/api/products")
  @put("/api/products/{product_id}")
  @delete("/api/products/{product_id}")
```

A complete CRUD route file with all five REST endpoints, proper imports, and response handling.

### Generate a Migration

```bash
tina4 generate migration create_products_table
```

```
Created src/migrations/20260322120000_create_products_table.sql

  -- UP
  CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
  );

  -- DOWN
  DROP TABLE IF EXISTS products;
```

The migration file is timestamped for ordering. Add your column definitions to the `UP` section.

### Generate Middleware

```bash
tina4 generate middleware rate_limit
```

```
Created src/middleware/rate_limit.py

  async def rate_limit(request, response, next_handler):
      # Add your middleware logic here
      return await next_handler(request, response)
```

### Generate All at Once

```bash
tina4 generate model Product --with-route --with-migration
```

```
Created src/orm/product.py
Created src/routes/products.py
Created src/migrations/20260322120000_create_products_table.sql
```

This creates the model, a CRUD route file, and a migration -- all wired together and ready to use.

---

## 5. tina4 doctor -- Health Check

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

The warnings give you actionable advice. If your database is not configured, it tells you exactly what to add to `.env`.

---

## 6. tina4 test -- Running Tests

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

## 7. tina4 routes -- Route Listing

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

This is useful for verifying that your routes are registered correctly and for finding the handler function for a specific URL.

---

## 8. tina4 migrate -- Database Migrations

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

If your project was created with an earlier version of Tina4, the `tina4_migration` tracking table may use the older v2 schema. Running `tina4 migrate` automatically detects the old layout and adds the missing `migration_id`, `batch`, and `executed_at` columns, backfilling existing data. No manual intervention is needed.

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

## 9. Exercise: Scaffold a Feature in 5 Commands

Scaffold a complete "Customer" feature from scratch using only CLI commands.

### Requirements

Starting from an existing Tina4 Python project, run exactly 5 commands to create:

1. A Customer ORM model with name, email, phone, and company fields
2. A CRUD route file with all five REST endpoints
3. A migration that creates the customers table
4. Run the migration to create the table
5. Run the tests to verify everything works

### Expected Commands

```bash
# 1. Generate the model with route and migration
tina4 generate model Customer --with-route --with-migration

# 2. Edit the model to add fields (this is manual, not a CLI command)
# Add fields to src/orm/customer.py

# 3. Edit the migration to add columns (this is manual)
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

**Command 3:** Edit the migration file to add columns:

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

---

## 10. Gotchas

### 1. tina4 Command Not Found

**Problem:** Running `tina4` gives "command not found".

**Cause:** The Tina4 CLI is not installed or not in your PATH.

**Fix:** Install the CLI: `curl -fsSL https://tina4.com/install.sh | sh`. Verify with `tina4 --version`. If installed but not found, add the installation directory to your PATH.

### 2. Wrong Language Detected

**Problem:** `tina4 init` creates a PHP project instead of Python.

**Cause:** A `composer.json` file exists in the directory (perhaps from a previous project).

**Fix:** Use explicit language selection: `tina4 init python my-project`. Or delete the conflicting language file before running `init`.

### 3. Generated Files Overwrite Existing Code

**Problem:** Running `tina4 generate route products` overwrites your custom route file.

**Cause:** The generate command creates files at fixed paths. If the file already exists, it is overwritten.

**Fix:** The CLI warns you before overwriting. Always check if the file exists first. If you need to regenerate, rename the existing file first: `mv src/routes/products.py src/routes/products_backup.py`.

### 4. Migration Order Issues

**Problem:** A migration fails because it references a table that does not exist yet.

**Cause:** Migration files are run in alphabetical (timestamp) order. If migration B depends on a table created by migration A, but A has a later timestamp, B runs first and fails.

**Fix:** Use consistent timestamps. The `tina4 generate migration` command uses the current timestamp, so generating migrations in order ensures correct execution order. If you need to fix ordering, rename the migration files to adjust their timestamps.

### 5. tina4 serve Uses Wrong Port

**Problem:** `tina4 serve` starts on port 7145 but you need port 8080.

**Cause:** The default port is 7145 unless overridden.

**Fix:** Set it in `.env`: `TINA4_PORT=8080`. Or pass it as a flag: `tina4 serve --port 8080`. The `.env` value takes precedence over the default, and the command-line flag overrides everything.

### 6. Doctor Shows False Warnings

**Problem:** `tina4 doctor` warns about missing migrations, but your project does not use migrations.

**Cause:** Doctor checks for common conventions. If your project uses a different approach (like manual schema management), it still warns about missing migrations.

**Fix:** These are warnings, not errors. You can ignore warnings that do not apply to your project. Doctor is a guide, not a gatekeeper.

### 7. Generate Creates Python 3.12+ Syntax

**Problem:** Generated code uses `type: int` syntax that does not work in Python 3.10.

**Cause:** The generator targets the latest Python version supported by Tina4.

**Fix:** Use Python 3.12 or later with Tina4 Python. Check your Python version with `python --version`. If you must use an older version, modify the generated code to use compatible syntax.
