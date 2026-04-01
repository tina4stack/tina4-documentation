# Chapter 19: Tina4 CLI

## 1. Getting a New Developer Up to Speed

A new developer joins your team Monday morning. You hand them the repo URL. By 10am they have a running project, a new database model, CRUD routes, a migration, and a deployment to staging. All from the command line. No hunting through documentation. No copy-pasting boilerplate from old projects. The CLI handles scaffolding.

The Tina4 CLI is a single Rust binary. It manages all four Tina4 frameworks (PHP, Python, Ruby, Node.js). Commands stay identical across languages. Learn the CLI for PHP. You know it for Python.

---

## 2. tina4 init -- Project Scaffolding

You saw this in Chapter 1. Now the details.

```bash
tina4 init my-project
```

```
Creating Tina4 project in ./my-project ...
  Detected language: PHP (composer.json)
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
  composer install
  tina4 serve
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
> 1

Creating Tina4 PHP project in ./my-project ...
```

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
 _____ _             _  _
|_   _(_)_ __   __ _| || |
  | | | | '_ \ / _` | || |_
  | | | | | | | (_| |__   _|
  |_| |_|_| |_|\__,_|  |_|

  Tina4 PHP v3.0.0
  Server running at http://0.0.0.0:7146
  Debug mode: ON
  Database: sqlite:///data/app.db
  Press Ctrl+C to stop
```

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--port` | Custom port (default: 7146) | `tina4 serve --port 8080` |
| `--host` | Bind address (default: 0.0.0.0) | `tina4 serve --host 127.0.0.1` |
| `--no-reload` | Disable live reload | `tina4 serve --no-reload` |

### Production Mode Detection

```bash
tina4 serve --production
```

When the `--production` flag is passed, the CLI:

1. Checks for `TINA4_DEBUG=false` in `.env` (warns if debug is on)
2. Uses FrankenPHP if available for better performance
3. Enables response caching and template pre-compilation
4. Disables the dev toolbar and error overlay
5. Enables graceful shutdown handling

In practice, you rarely use `tina4 serve --production` directly. Instead, you use Docker or a process manager (Chapter 20). But this flag is useful for quick production testing.

---

## 4. tina4 generate model -- ORM Scaffolding

Generate a new ORM model:

```bash
tina4 generate model Order
```

```
Created src/orm/Order.php
Created src/migrations/20260322100000_create_orders_table.sql
```

The generated model:

```php
<?php
use Tina4\ORM;

class Order extends ORM
{
    public int $id;
    public string $createdAt;
    public string $updatedAt;

    public string $tableName = "orders";
    public string $primaryKey = "id";
}
```

The generated migration:

```sql
-- UP
CREATE TABLE orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS orders;
```

### Adding Fields

You can specify fields on the command line:

```bash
tina4 generate model Order --fields "userId:int,total:float,status:string,paid:bool"
```

```
Created src/orm/Order.php
Created src/migrations/20260322100000_create_orders_table.sql
```

The generated model now includes all the fields:

```php
<?php
use Tina4\ORM;

class Order extends ORM
{
    public int $id;
    public int $userId;
    public float $total;
    public string $status;
    public bool $paid;
    public string $createdAt;
    public string $updatedAt;

    public string $tableName = "orders";
    public string $primaryKey = "id";
}
```

And the migration:

```sql
-- UP
CREATE TABLE orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    total REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT '',
    paid INTEGER NOT NULL DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS orders;
```

### Field Types

| CLI Type | PHP Type | SQLite Column |
|----------|----------|---------------|
| `string` | `string` | `TEXT` |
| `int` | `int` | `INTEGER` |
| `float` | `float` | `REAL` |
| `bool` | `bool` | `INTEGER` |
| `text` | `string` | `TEXT` |
| `date` | `string` | `TEXT` |

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--fields` | Comma-separated field definitions | `--fields "name:string,price:float"` |
| `--auto-crud` | Enable auto-CRUD on the model | `--auto-crud` |
| `--soft-delete` | Add soft delete support | `--soft-delete` |
| `--no-migration` | Skip migration generation | `--no-migration` |

---

## 5. tina4 generate route -- CRUD Route Scaffolding

Generate CRUD routes for a model:

```bash
tina4 generate route Order
```

```
Created src/routes/orders.php
```

The generated route file:

```php
<?php
use Tina4\Router;

Router::group("/api", function () {

    // List all orders
    Router::get("/orders", function ($request, $response) {
        $order = new Order();
        $page = (int) ($request->params["page"] ?? 1);
        $perPage = (int) ($request->params["per_page"] ?? 20);
        $offset = ($page - 1) * $perPage;

        $orders = $order->select("*", "", [], "created_at DESC", $perPage, $offset);
        $results = array_map(fn($o) => $o->toArray(), $orders);

        return $response->json([
            "data" => $results,
            "page" => $page,
            "per_page" => $perPage,
            "count" => count($results)
        ]);
    });

    // Get a single order
    Router::get("/orders/{id:int}", function ($request, $response) {
        $order = new Order();
        $order->load($request->params["id"]);

        if (empty($order->id)) {
            return $response->json(["error" => "Order not found"], 404);
        }

        return $response->json($order->toArray());
    });

    // Create an order
    Router::post("/orders", function ($request, $response) {
        $body = $request->body;
        $order = new Order();
        $order->userId = (int) ($body["user_id"] ?? 0);
        $order->total = (float) ($body["total"] ?? 0);
        $order->status = $body["status"] ?? "";
        $order->paid = (bool) ($body["paid"] ?? false);
        $order->save();

        return $response->json($order->toArray(), 201);
    });

    // Update an order
    Router::put("/orders/{id:int}", function ($request, $response) {
        $order = new Order();
        $order->load($request->params["id"]);

        if (empty($order->id)) {
            return $response->json(["error" => "Order not found"], 404);
        }

        $body = $request->body;
        if (isset($body["user_id"])) $order->userId = (int) $body["user_id"];
        if (isset($body["total"])) $order->total = (float) $body["total"];
        if (isset($body["status"])) $order->status = $body["status"];
        if (isset($body["paid"])) $order->paid = (bool) $body["paid"];
        $order->save();

        return $response->json($order->toArray());
    });

    // Delete an order
    Router::delete("/orders/{id:int}", function ($request, $response) {
        $order = new Order();
        $order->load($request->params["id"]);

        if (empty($order->id)) {
            return $response->json(["error" => "Order not found"], 404);
        }

        $order->delete();
        return $response->json(null, 204);
    });
});
```

The generator reads the model's properties and creates routes with type casting and null checks. Customize the generated code immediately. It is regular PHP, not magic.

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--prefix` | Custom route prefix (default: `/api`) | `--prefix /api/v2` |
| `--middleware` | Add middleware to all routes | `--middleware requireAuth` |

---

## 6. tina4 generate migration -- Migration Scaffolding

Create an empty migration file:

```bash
tina4 generate migration "add email to orders"
```

```
Created src/migrations/20260322101500_add_email_to_orders.sql
```

The generated file:

```sql
-- UP
-- Add your forward migration SQL here


-- DOWN
-- Add your rollback migration SQL here

```

You fill in the SQL yourself:

```sql
-- UP
ALTER TABLE orders ADD COLUMN email TEXT DEFAULT '';

-- DOWN
ALTER TABLE orders DROP COLUMN email;
```

The timestamp prefix (`20260322101500`) ensures migrations run in order. Each migration runs once. The framework tracks which ones have been applied.

---

## 7. tina4 generate middleware -- Middleware Scaffolding

```bash
tina4 generate middleware rateLimiter
```

```
Created src/middleware/rateLimiter.php
```

The generated file:

```php
<?php

function rateLimiter($request, $response, $next)
{
    // Add your middleware logic here

    // Continue to the next middleware or route handler
    return $next($request, $response);

    // Or return early to block the request:
    // return $response->json(["error" => "Rate limit exceeded"], 429);
}
```

The middleware is a named function that you can reference in route definitions:

```php
Router::get("/api/data", function ($request, $response) {
    return $response->json(["data" => "protected"]);
}, "rateLimiter");
```

---

## 8. tina4 doctor -- Environment Health Check

```bash
tina4 doctor
```

```
Tina4 Doctor - Environment Health Check

  PHP Version .............. 8.3.4       [OK]
  Composer ................. 2.7.2       [OK]
  ext-json ................. loaded      [OK]
  ext-mbstring ............. loaded      [OK]
  ext-openssl .............. loaded      [OK]
  ext-sqlite3 .............. loaded      [OK]
  ext-fileinfo ............. loaded      [OK]
  ext-pdo_sqlite ........... loaded      [OK]
  .env file ................ found       [OK]
  data/ directory .......... writable    [OK]
  logs/ directory .......... writable    [OK]
  secrets/ directory ....... writable    [OK]
  Database connection ...... connected   [OK]
  Routes discovered ........ 14 routes   [OK]
  ORM models discovered .... 5 models    [OK]
  Templates directory ...... found       [OK]
  tina4.css ................ found       [OK]
  frond.js ................. found       [OK]

  All checks passed. Your environment is ready.
```

If something is wrong, the doctor tells you:

```
  ext-mbstring ............. missing     [FAIL]
    Fix: apt install php8.3-mbstring (Ubuntu)
         brew install php (macOS, includes mbstring)

  data/ directory .......... not writable [FAIL]
    Fix: chmod 755 data/

  Database connection ...... failed      [FAIL]
    Error: could not open database file
    Fix: Check DATABASE_URL in .env. Current value: sqlite:///data/app.db
         Make sure the data/ directory exists and is writable.
```

The doctor checks everything a new developer might get wrong. Specific fix instructions for each issue.

---

## 9. tina4 test -- Running Tests

```bash
tina4 test
```

```
Running tests...

  ProductTest
    [PASS] test_create_product
    [PASS] test_load_product

  AuthTest
    [PASS] test_login

  3 tests, 3 passed, 0 failed (0.21s)
```

See Chapter 17 for the full testing guide. The CLI command discovers all test files in `tests/` and runs them.

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--file` | Run a specific test file | `--file tests/ProductTest.php` |
| `--method` | Run a specific test method | `--method testCreateProduct` |
| `--verbose` | Show all assertions | `--verbose` |

---

## 10. tina4 routes -- List All Routes

```bash
tina4 routes
```

```
Method   Path                          Middleware          Auth
------   ----                          ----------          ----
GET      /health                       -                   public
GET      /api/products                 -                   public
GET      /api/products/{id:int}        -                   public
POST     /api/products                 -                   secured
PUT      /api/products/{id:int}        -                   secured
DELETE   /api/products/{id:int}        -                   secured
GET      /api/orders                   -                   public
POST     /api/orders                   requireAuth         secured
GET      /admin                        -                   public
GET      /admin/users                  -                   public
```

### Filtering

```bash
# Filter by HTTP method
tina4 routes --method POST

# Filter by path pattern
tina4 routes --filter orders

# Filter by middleware
tina4 routes --middleware requireAuth
```

When debugging routing issues, check here first. If a route is not matching, `tina4 routes` shows whether it was registered and what middleware is attached.

---

## 11. tina4 migrate -- Run Database Migrations

```bash
tina4 migrate
```

```
Running migrations...
  [APPLIED] 20260322100000_create_orders_table.sql
  [APPLIED] 20260322101500_add_email_to_orders.sql
  [SKIPPED] 20260322080000_create_products_table.sql (already applied)
Migrations complete. 2 applied, 1 skipped.
```

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--rollback` | Undo the last migration | `tina4 migrate --rollback` |
| `--rollback-all` | Undo all migrations | `tina4 migrate --rollback-all` |
| `--status` | Show migration status | `tina4 migrate --status` |

### Migration Status

```bash
tina4 migrate --status
```

```
Migration Status:

  [APPLIED]  20260322080000_create_products_table.sql     (applied 2026-03-22 08:15:00)
  [APPLIED]  20260322100000_create_orders_table.sql       (applied 2026-03-22 10:05:00)
  [APPLIED]  20260322101500_add_email_to_orders.sql       (applied 2026-03-22 10:20:00)
  [PENDING]  20260322120000_add_status_to_products.sql    (not yet applied)

  3 applied, 1 pending
```

---

## 12. Exercise: Scaffold a Complete Feature in 5 Commands

You need to add a "Tasks" feature to your project. Each task has a title, description, priority (string), completed status (boolean), and belongs to a user.

### Requirements

Using only CLI commands, do the following:

1. Generate the Task model with fields
2. Generate CRUD routes for the Task model
3. Run the migration to create the table
4. Verify the routes are registered
5. Run the doctor to make sure everything is healthy

### Expected Commands

Complete this in exactly 5 commands. After running them, test the API with curl to verify everything works.

### Test with:

```bash
# Create a task
curl -X POST http://localhost:7146/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Write chapter 19", "description": "CLI and scaffolding", "priority": "high", "user_id": 1}'

# List tasks
curl http://localhost:7146/api/tasks

# Get one task
curl http://localhost:7146/api/tasks/1
```

---

## 13. Solution

The five commands:

```bash
# 1. Generate the model with fields (creates model + migration)
tina4 generate model Task --fields "userId:int,title:string,description:text,priority:string,completed:bool"

# 2. Generate CRUD routes
tina4 generate route Task

# 3. Run the migration
tina4 migrate

# 4. Verify routes are registered
tina4 routes --filter tasks

# 5. Health check
tina4 doctor
```

**Command 1 output:**

```
Created src/orm/Task.php
Created src/migrations/20260322140000_create_tasks_table.sql
```

**Command 2 output:**

```
Created src/routes/tasks.php
```

**Command 3 output:**

```
Running migrations...
  [APPLIED] 20260322140000_create_tasks_table.sql
Migrations complete. 1 applied.
```

**Command 4 output:**

```
Method   Path                          Middleware          Auth
------   ----                          ----------          ----
GET      /api/tasks                    -                   public
GET      /api/tasks/{id:int}           -                   public
POST     /api/tasks                    -                   secured
PUT      /api/tasks/{id:int}           -                   secured
DELETE   /api/tasks/{id:int}           -                   secured
```

**Command 5 output:**

```
Tina4 Doctor - Environment Health Check
  ...
  All checks passed. Your environment is ready.
```

**Test - create a task:**

```bash
curl -X POST http://localhost:7146/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Write chapter 19", "description": "CLI and scaffolding", "priority": "high", "user_id": 1}'
```

```json
{
  "id": 1,
  "user_id": 1,
  "title": "Write chapter 19",
  "description": "CLI and scaffolding",
  "priority": "high",
  "completed": false,
  "created_at": "2026-03-22 14:05:00",
  "updated_at": "2026-03-22 14:05:00"
}
```

From zero to a working CRUD API in 5 commands and under 2 minutes.

---

## 14. Gotchas

### 1. Model Name Must Be PascalCase

**Problem:** `tina4 generate model order_item` creates a model class named `order_item` which is not valid PHP.

**Cause:** The CLI uses the argument as-is for the class name if it cannot determine the PascalCase form.

**Fix:** Always use PascalCase for model names: `tina4 generate model OrderItem`. The CLI converts it to snake_case for the table name (`order_items`).

### 2. Migration Already Applied

**Problem:** You regenerated a model and the migration has the same name as an existing one, but the CLI says it was already applied.

**Cause:** Tina4 tracks applied migrations by filename. If the filename matches, it considers it already applied.

**Fix:** Each migration should have a unique timestamp prefix. If you need to modify a table after the initial migration, create a new migration: `tina4 generate migration "add status to tasks"`.

### 3. Generated Routes Conflict with Auto-CRUD

**Problem:** You generated routes for a model that has `$autoCrud = true`, and now requests hit the wrong handler.

**Cause:** Both the generated routes and auto-CRUD routes register at the same paths. The first one registered wins.

**Fix:** Either use generated routes or auto-CRUD, not both for the same model. If you use `tina4 generate route`, set `$autoCrud = false` on the model (or do not set it at all -- it defaults to false).

### 4. Port Already in Use

**Problem:** `tina4 serve` fails with "Address already in use."

**Cause:** Another process is using port 7146 (or whichever port you configured).

**Fix:** Find and stop the other process, or use a different port:

```bash
tina4 serve --port 8080
```

To find what is using the port:

```bash
lsof -i :7146
```

### 5. CLI Not Found After Installation

**Problem:** `tina4: command not found` after running the install script.

**Cause:** The CLI binary is not in your `PATH`. The install script puts it in `~/.tina4/bin/` which may not be in your shell's PATH.

**Fix:** Add the binary location to your PATH. For zsh (macOS default):

```bash
echo 'export PATH="$HOME/.tina4/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

For bash:

```bash
echo 'export PATH="$HOME/.tina4/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
