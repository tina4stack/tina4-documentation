# Chapter 36: Upgrading from v2 to v3

## 1. Overview

Tina4 v3 is a ground-up rewrite. Zero Composer dependencies. The built-in HTTP server, template engine, ORM, and database drivers are all native PHP. No Guzzle, no Twig, no Doctrine -- nothing external.

The patterns you know still work. Routes, ORM models, templates, migrations -- same concepts, cleaner implementation. The framework is faster, more consistent, and easier to deploy.

Three things to know before you start:

- **Methods are camelCase.** `$db->startTransaction()`, not `$db->start_transaction()`.
- **Classes are PascalCase.** `Router`, `Database`, `ORM`, `Response`.
- **Zero dependencies.** `composer install` pulls exactly one package: `tina4stack/tina4-php`.

This chapter walks through every breaking change and gives you a step-by-step migration checklist at the end.

---

## Step 0: Run the Automated Upgrade Command

Before doing anything manually, run the automated upgrade tool:

```bash
cd your-v2-project
tina4 i-want-to-stop-using-v2-and-switch-to-v3
```

This command automatically:
- Moves `routes/`, `orm/`, `templates/`, `scss/`, `public/`, `app/`, `locales/`, `seeds/` into `src/`
- Updates your `composer.json` dependency from v2 to v3
- Removes split packages (`tina4php-core`, `tina4php-database`, `tina4php-orm`)

After running the command, continue with the steps below for the changes that require manual attention.

---

## 2. Package and Installation

### v2

```bash
composer require tina4stack/tina4php
```

This pulled in a tree of Composer dependencies -- HTTP clients, template engines, database abstractions.

### v3

```bash
composer require tina4stack/tina4-php
```

Note the hyphen: `tina4-php`, not `tina4php`. This is the only package. It has zero Composer dependencies. Everything is built in.

Update your `composer.json`:

```json
{
    "require": {
        "tina4stack/tina4-php": "^3.0"
    }
}
```

Then run:

```bash
composer update
```

Remove any v2-era Tina4 packages from `composer.json` (`tina4stack/tina4php`, `tina4stack/tina4-database`, etc.). They are all consolidated into the single `tina4-php` package.

---

## 3. Project Structure Changes

### v2 Structure

```
project/
  routes/
  orm/
  templates/
  migrations/
  .env
  index.php
```

### v3 Structure

```
project/
  src/
    routes/
    orm/
    templates/
    app/
  migrations/
  .env
  index.php
```

The key change: source files live under `src/`. Routes go in `src/routes/`, ORM models in `src/orm/`, templates in `src/templates/`, and application logic in `src/app/`.

Auto-discovery still works the same way. Every `.php` file in `src/` and its subdirectories is auto-included at startup. No manual registration. Drop a file in, it loads.

**Migration path:** Move your existing `routes/`, `orm/`, and `templates/` directories into `src/`. Create `src/app/` for any utility classes or service files.

---

## 4. Routing Changes

### Method-Based Registration

The core pattern is the same. The class name changed from `Route` to `Router`:

**v2:**

```php
<?php
\Tina4\Get::add("/hello", function ($response, $request) {
    return $response("Hello, World!");
});
```

**v3:**

```php
<?php
use Tina4\Router;

Router::get("/hello", function ($request, $response) {
    return $response->json(["message" => "Hello, World!"]);
});
```

Three changes:

1. `\Tina4\Get::add()` becomes `Router::get()`. Same for `Post`, `Put`, `Patch`, `Delete`.
2. The callback signature flips: `$request` comes first, then `$response`.
3. Response methods are explicit: `$response->json()`, `$response->render()`, `$response->text()`.

### Class-Based Routes with Attributes

v3 supports PHP 8 attributes for class-based routes:

```php
<?php
use Tina4\Router;

class ProductController
{
    #[Router("/products", "GET")]
    public function list($request, $response)
    {
        return $response->json(["products" => []]);
    }

    #[Router("/products", "POST")]
    public function create($request, $response)
    {
        return $response->json(["created" => true], 201);
    }
}
```

### Auth Defaults

This is a breaking change. v3 has opinionated auth defaults:

| Method | v2 Default | v3 Default |
|--------|-----------|-----------|
| GET | Public | Public |
| POST | Public | Requires auth |
| PUT | Public | Requires auth |
| PATCH | Public | Requires auth |
| DELETE | Public | Requires auth |

Write operations require authentication by default. Two attributes control this:

- **`#[NoAuth]`** -- Makes a write route public (no auth required).
- **`#[Secured]`** -- Requires auth on a GET route.

```php
<?php
use Tina4\Router;
use Tina4\NoAuth;
use Tina4\Secured;

// This POST route is public -- no auth needed
#[NoAuth]
Router::post("/register", function ($request, $response) {
    // Public registration endpoint
    return $response->json(["registered" => true], 201);
});

// This GET route requires auth
#[Secured]
Router::get("/admin/dashboard", function ($request, $response) {
    return $response->render("admin/dashboard.html");
});
```

**If your v2 app had unprotected POST/PUT/PATCH/DELETE routes,** add `#[NoAuth]` to each one or they will return 401. Review every write route during migration.

---

## 5. Database Changes

### Connection Strings

The format is the same URL-based approach, but the syntax is cleaner:

**v2:**

```php
$db = new \Tina4\DataSQLite3("data/app.db");
```

**v3:**

```bash
DATABASE_URL=sqlite:///data/app.db
```

Or in code:

```php
<?php
use Tina4\Database;

$db = new Database("sqlite:///data/app.db");
```

All drivers use the same `Database` class. The URL scheme selects the driver:

```bash
# SQLite
DATABASE_URL=sqlite:///data/app.db

# PostgreSQL
DATABASE_URL=postgres://localhost:5432/myapp

# MySQL
DATABASE_URL=mysql://localhost:3306/myapp

# Firebird
DATABASE_URL=firebird://localhost:3050/path/to/database.fdb

# Microsoft SQL Server
DATABASE_URL=mssql://localhost:1433/myapp
```

### Firebird Notes

v3 supports both the legacy `interbase` and modern `firebird-driver` PHP extensions. Column names are returned in lowercase by default. If your v2 code relied on uppercase column names from Firebird, update your references.

### Transactions

Transaction methods are renamed to camelCase:

**v2:**

```php
$db->beginTransaction();
// ... queries ...
$db->commit();
$db->rollBack();
```

**v3:**

```php
$db->startTransaction();
// ... queries ...
$db->commit();
$db->rollback();
```

Note: `beginTransaction()` becomes `startTransaction()`, and `rollBack()` (capital B) becomes `rollback()` (lowercase b).

---

## 6. ORM Changes

### Auto-Mapping

The biggest ORM improvement in v3 is `$autoMap`. Set it to `true` and Tina4 automatically generates `$fieldMapping` entries from your camelCase PHP properties to snake_case database columns.

**v2:**

```php
<?php
class Product extends \Tina4\ORM
{
    public $tableName = "products";
    public $primaryKey = "id";

    public $id;
    public $productName;
    public $unitPrice;
    public $inStock;

    public $fieldMapping = [
        "productName" => "product_name",
        "unitPrice" => "unit_price",
        "inStock" => "in_stock"
    ];
}
```

**v3:**

```php
<?php
use Tina4\ORM;

class Product extends ORM
{
    public string $tableName = "products";
    public string $primaryKey = "id";
    public bool $autoMap = true;

    public int $id;
    public string $productName;
    public float $unitPrice;
    public bool $inStock = true;
}
```

With `$autoMap = true`, Tina4 sees `$productName` and auto-generates the mapping to `product_name`. Same for `$unitPrice` to `unit_price` and `$inStock` to `in_stock`. No manual `$fieldMapping` needed.

### Explicit Mappings Take Precedence

If you have a column that does not follow the convention, add it to `$fieldMapping` manually. Explicit entries override auto-generated ones:

```php
<?php
use Tina4\ORM;

class Legacy extends ORM
{
    public string $tableName = "legacy_table";
    public bool $autoMap = true;

    public int $id;
    public string $firstName;     // auto-maps to first_name
    public string $legacyField;   // override below

    public array $fieldMapping = [
        "legacyField" => "LEGACY_FLD"  // takes precedence over auto-map
    ];
}
```

### Utility Methods

Two helper methods are available for manual conversions:

```php
$snake = ORM::camelToSnake("firstName");  // "first_name"
$camel = ORM::snakeToCamel("first_name"); // "firstName"
```

### Typed Properties

v3 models use PHP 8 typed properties. Add types to all your ORM properties:

```php
// v2
public $price;

// v3
public float $price = 0.00;
```

---

## 7. Template Engine Changes

Tina4 v3 uses Frond as its template engine. If you were using Twig in v2, most syntax carries over -- Frond is Twig-compatible.

### Frond Singleton

Access the Frond instance through the `Response` class:

```php
<?php
use Tina4\Response;

// Get the Frond instance
$frond = Response::getFrond();

// Add a custom filter
$frond->addFilter("shout", function ($value) {
    return strtoupper($value) . "!!!";
});

// Add a global variable
$frond->addGlobal("appName", "My App");

// Set the instance back (if needed after modification)
Response::setFrond($frond);
```

### Custom Filters and Globals

Custom filters and globals persist across requests within the same process. Register them once at startup (in `src/app/` or early in `index.php`) and they are available in every template render.

### Method Calls in Templates

v3 adds the ability to call methods on array or object values inside templates:

```html
<!-- Call a method on an object -->
<p>{{ user.getName() }}</p>

<!-- Call with arguments -->
<p>{{ translator.t("welcome_message") }}</p>

<!-- Chain with filters -->
<p>{{ user.getName()|upper }}</p>
```

This is new in v3. v2 only supported property access (`{{ user.name }}`), not method calls.

---

## 8. Migration Tracking Table

v3 uses an enhanced migration tracking table with additional columns for better tracking.

When you run migrations on a database that was previously managed by v2, Tina4 v3 auto-detects the old tracking table format and upgrades it. The upgrade adds three columns:

- **`migration_id`** -- Unique identifier for each migration record.
- **`batch`** -- Groups migrations that ran together.
- **`executed_at`** -- Timestamp of when the migration was executed.

Existing migration records are preserved. The upgrade happens automatically on the first migration run. No manual intervention needed.

---

## 9. New Features in v3

Features that did not exist in v2. Each is covered in its own chapter:

- **Built-in HTTP server** -- No Apache or Nginx needed for development (Chapter 1).
- **Connection pooling** -- `pool` parameter on database connections (Chapter 5).
- **Query builder** -- Fluent SQL without raw strings (Chapter 7).
- **Job queues** -- Background task processing (Chapter 12).
- **WebSocket support** -- Real-time communication built in (Chapter 23).
- **Email sending** -- Native SMTP, no SwiftMailer (Chapter 16).
- **Caching layer** -- File, Redis, Valkey, Mongo backends (Chapter 11).
- **GraphQL** -- Built-in GraphQL endpoint (Chapter 22).
- **CLI tooling** -- `tina4` command for scaffolding, migrations, serving (Chapter 30).
- **Auto-mapping in ORM** -- `$autoMap = true` eliminates manual field mappings (Chapter 6).
- **Rate limiting** -- Per-IP rate limiting via env vars (Chapter 10).
- **CSRF protection** -- Built-in, enabled by default (Chapter 10).

---

## Common Pitfalls

### 1. POST/PUT/DELETE routes now require authentication

This is the most common upgrade issue. In v2, all routes were public by default. In v3, only GET routes are public -- POST, PUT, PATCH, and DELETE require a Bearer JWT token.

**Symptom:** Working v2 endpoints return `401 Unauthorized` after upgrading.

**Fix:** Add `#[NoAuth]` or `->noAuth()` to any write route that should remain public.

**Find affected routes:**

```bash
grep -rn "Router::post\|Router::put\|Router::patch\|Router::delete" src/routes/
```

Review each match -- if the endpoint should be public (webhooks, public forms, etc.), add the `#[NoAuth]` attribute.

### 2. Database connection strings changed

v2 used driver-specific classes. v3 uses URL format:

```php
// v2
$db = new \Tina4\DataSQLite3("data/app.db");
// v3
$db = Database::create("sqlite:///data/app.db");
```

### 3. Template engine renamed

v2: `Template.render()` -- v3: `Frond.render()` (or `$response->render()`)

The Twig syntax is the same -- your `.twig` files work unchanged. Only the PHP API call changes.

---

## 10. Step-by-Step Migration Checklist

Follow these steps in order. Check each one off as you go.

1. **Back up your v2 project.** Copy the entire project directory. You want a rollback point.

2. **Update `composer.json`.** Replace `tina4stack/tina4php` with `tina4stack/tina4-php`. Remove any other `tina4stack/*` packages. Run `composer update`.

3. **Restructure directories.** Move `routes/` to `src/routes/`, `orm/` to `src/orm/`, `templates/` to `src/templates/`. Create `src/app/` for utility classes.

4. **Update namespace imports.** Replace `\Tina4\Get::add()` with `Router::get()`, `\Tina4\Post::add()` with `Router::post()`, and so on. Add `use Tina4\Router;` at the top of each route file.

5. **Fix callback signatures.** Swap the parameter order from `($response, $request)` to `($request, $response)` in every route callback.

6. **Update response calls.** Replace `$response("data")` with `$response->json()`, `$response->render()`, or `$response->text()` as appropriate.

7. **Review auth on write routes.** Every POST, PUT, PATCH, and DELETE route now requires auth by default. Add `#[NoAuth]` to any write route that should be public (registration, public form submissions, webhooks).

8. **Add `#[Secured]` to protected GET routes.** Any GET route that should require authentication needs the `#[Secured]` attribute.

9. **Update database connection code.** Replace driver-specific classes (`DataSQLite3`, `DataMySQL`, etc.) with `new Database("url")`. Move connection strings to `DATABASE_URL` in `.env`.

10. **Fix transaction calls.** `beginTransaction()` becomes `startTransaction()`. `rollBack()` becomes `rollback()`.

11. **Add typed properties to ORM models.** Replace untyped `public $name;` with typed `public string $name;`. Add `$autoMap = true` and remove manual `$fieldMapping` entries where auto-mapping covers the conversion.

12. **Update template code.** If you were using Twig directly, switch to Frond. The syntax is compatible. Replace any Twig-specific PHP calls with `Response::getFrond()`.

13. **Run migrations.** Start the server and trigger a migration run. Tina4 auto-upgrades the tracking table. Verify your existing migrations still apply cleanly.

14. **Test every route.** Hit every endpoint. Check auth behaviour. Verify response formats. The test chapter (Chapter 18) covers how to write automated tests.

15. **Remove leftover v2 files.** Delete the old `routes/`, `orm/`, and `templates/` directories at the project root (now that everything is under `src/`). Clean up any v2-specific config files.

The migration is mechanical. Most of it is find-and-replace. The auth defaults are the one change that can silently break things -- step 7 is the most important step on this list.
