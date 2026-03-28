# Chapter 5: Database

## 1. From Arrays to Real Data

In Chapters 2 and 3, data lived in PHP arrays. Every server restart wiped the slate clean. That works for learning routing and responses. Real applications need persistence. This chapter covers Tina4's database layer: raw queries, parameterised queries, transactions, schema inspection, helper methods, and migrations.

Tina4 supports five database engines: SQLite, PostgreSQL, MySQL, Microsoft SQL Server, and Firebird. The API is identical across all of them. Switch databases by changing one line in `.env`.

---

## 2. Connecting to a Database

### The Default: SQLite

`tina4 init` creates an empty `data/` directory but does not create a database file. The default `.env` contains:

```env
TINA4_DEBUG=true
```

No explicit `DATABASE_URL` means Tina4 defaults to `sqlite:///data/app.db`. The SQLite file is created automatically the first time Tina4 opens a database connection (for example, when you run a query, execute a migration, or the framework initialises the database layer at startup with a `DATABASE_URL` configured).

### Connection Strings for Other Databases

Set `DATABASE_URL` in `.env`:

```env
# SQLite (explicit)
DATABASE_URL=sqlite:///data/app.db

# PostgreSQL
DATABASE_URL=postgres://localhost:5432/myapp

# MySQL
DATABASE_URL=mysql://localhost:3306/myapp

# Microsoft SQL Server
DATABASE_URL=mssql://localhost:1433/myapp

# Firebird
DATABASE_URL=firebird://localhost:3050/path/to/database.fdb
```

### Firebird: Dual-Driver Support

The Firebird adapter works with either the `ibase_*` or `fbird_*` PHP functions. It auto-detects which set is available at connection time. If you have `ext-interbase` installed, it uses `ibase_*`. If you have the newer `fbird_*` functions, it uses those instead. No configuration needed -- install whichever extension is available for your platform and the adapter picks it up.

### Separate Credentials

Keep credentials out of the connection string. Better for production:

```env
DATABASE_URL=postgres://localhost:5432/myapp
DATABASE_USERNAME=myuser
DATABASE_PASSWORD=secretpassword
```

Tina4 merges these at startup. Separate variables take precedence over anything embedded in the URL.

### Connection Pooling

For applications that handle many concurrent requests, enable connection pooling with the `pool` parameter:

```php
$db = new Database("postgres://localhost/mydb", pool: 5);
```

The `pool` parameter controls how many database connections are maintained:

- `pool: 0` (the default) -- a single connection is used for all queries
- `pool: N` (where N > 0) -- N connections are created and rotated round-robin across queries

Pooled connections are thread-safe. Each query is dispatched to the next available connection in the pool. This eliminates contention when multiple route handlers query the database simultaneously.

### Verifying the Connection

Update `.env`. Restart. Check:

```bash
curl http://localhost:7146/health
```

```json
{
  "status": "ok",
  "version": "3.0.0",
  "uptime": 3.14,
  "framework": "tina4-php"
}
```

---

## 3. Getting the Database Object

Access the database through the global `Tina4\Database` class:

```php
<?php
use Tina4\Router;
use Tina4\Database;

Router::get("/api/test-db", function ($request, $response) {
    $db = Database::getConnection();

    $result = $db->fetch("SELECT 1 + 1 AS answer");

    return $response->json($result);
});
```

```bash
curl http://localhost:7146/api/test-db
```

```json
{"answer": 2}
```

`Database::getConnection()` returns the active connection. Call `fetch()`, `execute()`, and `fetchOne()` on it.

---

## 4. Raw Queries

### fetch() -- Get Multiple Rows

```php
$db = Database::getConnection();

// Returns an array of associative arrays
$products = $db->fetch("SELECT * FROM products WHERE price > 50");
```

Each row is an associative array:

```php
// $products looks like:
[
    ["id" => 1, "name" => "Keyboard", "price" => 79.99],
    ["id" => 4, "name" => "Standing Desk", "price" => 549.99]
]
```

### DatabaseResult

`fetch()` returns a `DatabaseResult` object. It behaves like an array but carries extra metadata about the query.

#### Properties

```php
$result = $db->fetch("SELECT * FROM users WHERE active = ?", [1]);

$result->records;      // [["id" => 1, "name" => "Alice"], ["id" => 2, "name" => "Bob"]]
$result->columns;      // ["id", "name", "email", "active"]
$result->count;        // total number of matching rows
$result->limit;        // query limit (if set)
$result->offset;       // query offset (if set)
```

#### Iteration

A `DatabaseResult` is iterable. Use it directly in `foreach`:

```php
foreach ($result as $user) {
    echo $user["name"];
}
```

#### Index Access

Access rows by index like a regular array:

```php
$firstUser = $result[0];
```

#### Countable

`count()` works on the result:

```php
echo count($result); // number of records in this result set
```

#### Conversion Methods

```php
$result->toJson();      // JSON string of all records
$result->toCsv();       // CSV string with column headers
$result->toArray();     // plain array of associative arrays
$result->toPaginate();  // ["records" => [...], "count" => 42, "limit" => 10, "offset" => 0]
```

`toPaginate()` is designed for building paginated API responses. It bundles the records with the total count, limit, and offset in a single array.

#### Schema Metadata with columnInfo()

`columnInfo()` returns detailed metadata about the columns in the result set. The data is lazy-loaded -- it only queries the database schema when you call the method for the first time:

```php
$info = $result->columnInfo();
// [
//     ["name" => "id", "type" => "INTEGER", "size" => null, "decimals" => null, "nullable" => false, "primary_key" => true],
//     ["name" => "name", "type" => "TEXT", "size" => null, "decimals" => null, "nullable" => false, "primary_key" => false],
//     ["name" => "email", "type" => "TEXT", "size" => 255, "decimals" => null, "nullable" => true, "primary_key" => false],
//     ...
// ]
```

Each column entry contains:

| Field | Description |
|-------|-------------|
| `name` | Column name |
| `type` | Database type (e.g. `INTEGER`, `TEXT`, `REAL`) |
| `size` | Maximum size (or `null` if not applicable) |
| `decimals` | Decimal places (or `null`) |
| `nullable` | Whether the column allows `NULL` |
| `primary_key` | Whether the column is part of the primary key |

This is useful for building dynamic forms, generating documentation, or validating data before insert.

### fetchOne() -- Get a Single Row

```php
$product = $db->fetchOne("SELECT * FROM products WHERE id = 1");
// Returns: ["id" => 1, "name" => "Keyboard", "price" => 79.99]
```

No match returns `null`.

### execute() -- Run a Statement

For INSERT, UPDATE, DELETE, and DDL -- statements that do not return rows:

```php
$db->execute("INSERT INTO products (name, price) VALUES ('Widget', 9.99)");
$db->execute("UPDATE products SET price = 89.99 WHERE id = 1");
$db->execute("DELETE FROM products WHERE id = 5");
$db->execute("CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, message TEXT, created_at TEXT)");
```

### Full Example: A Simple Query Route

```php
<?php
use Tina4\Router;
use Tina4\Database;

Router::get("/api/products", function ($request, $response) {
    $db = Database::getConnection();

    $products = $db->fetch("SELECT * FROM products ORDER BY name");

    return $response->json([
        "products" => $products,
        "count" => count($products)
    ]);
});
```

```bash
curl http://localhost:7146/api/products
```

```json
{
  "products": [
    {"id": 1, "name": "Keyboard", "price": 79.99, "in_stock": 1},
    {"id": 2, "name": "Mouse", "price": 29.99, "in_stock": 1},
    {"id": 3, "name": "Monitor", "price": 399.99, "in_stock": 0}
  ],
  "count": 3
}
```

---

## 5. Parameterised Queries

Never concatenate user input into SQL strings. That is how SQL injection happens:

```php
// NEVER do this:
$db->fetch("SELECT * FROM products WHERE name = '" . $userInput . "'");
```

Use parameterised queries instead. Parameters go in the second argument:

```php
$db = Database::getConnection();

// Named parameters
$product = $db->fetchOne(
    "SELECT * FROM products WHERE id = :id",
    ["id" => 42]
);

// Positional parameters
$products = $db->fetch(
    "SELECT * FROM products WHERE price BETWEEN ? AND ? ORDER BY price",
    [10.00, 100.00]
);
```

The database driver handles escaping. Your input never touches the SQL string.

### A Safe Search Endpoint

```php
<?php
use Tina4\Router;
use Tina4\Database;

Router::get("/api/products/search", function ($request, $response) {
    $db = Database::getConnection();

    $q = $request->params["q"] ?? "";
    $maxPrice = (float) ($request->params["max_price"] ?? 99999);

    if (empty($q)) {
        return $response->json(["error" => "Query parameter 'q' is required"], 400);
    }

    $products = $db->fetch(
        "SELECT * FROM products WHERE name LIKE :query AND price <= :maxPrice ORDER BY name",
        ["query" => "%" . $q . "%", "maxPrice" => $maxPrice]
    );

    return $response->json([
        "query" => $q,
        "max_price" => $maxPrice,
        "results" => $products,
        "count" => count($products)
    ]);
});
```

```bash
curl "http://localhost:7146/api/products/search?q=key&max_price=100"
```

```json
{
  "query": "key",
  "max_price": 100,
  "results": [
    {"id": 1, "name": "Wireless Keyboard", "price": 79.99, "in_stock": 1}
  ],
  "count": 1
}
```

---

## 6. Transactions

Multiple operations that must succeed or fail together:

```php
<?php
use Tina4\Router;
use Tina4\Database;

Router::post("/api/orders", function ($request, $response) {
    $db = Database::getConnection();
    $body = $request->body;

    try {
        $db->startTransaction();

        // Create the order
        $db->execute(
            "INSERT INTO orders (customer_id, total, status) VALUES (:customerId, :total, 'pending')",
            ["customerId" => $body["customer_id"], "total" => $body["total"]]
        );

        // Get the new order ID
        $order = $db->fetchOne("SELECT last_insert_rowid() AS id");
        $orderId = $order["id"];

        // Create order items
        foreach ($body["items"] as $item) {
            $db->execute(
                "INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (:orderId, :productId, :qty, :price)",
                [
                    "orderId" => $orderId,
                    "productId" => $item["product_id"],
                    "qty" => $item["quantity"],
                    "price" => $item["price"]
                ]
            );

            // Decrease stock
            $db->execute(
                "UPDATE products SET stock = stock - :qty WHERE id = :productId",
                ["qty" => $item["quantity"], "productId" => $item["product_id"]]
            );
        }

        $db->commit();

        return $response->json(["order_id" => $orderId, "status" => "created"], 201);
    } catch (\Exception $e) {
        $db->rollback();
        return $response->json(["error" => "Order failed: " . $e->getMessage()], 500);
    }
});
```

If any step fails, `rollback()` undoes everything. The database never lands in a half-finished state.

You must call `commit()` to save. Forget it, and the transaction rolls back when the connection closes.

---

## 7. Schema Inspection

Tina4 provides methods to inspect your database structure at runtime.

### getTables()

```php
$db = Database::getConnection();
$tables = $db->getTables();
```

Returns an array of table names:

```php
["orders", "order_items", "products", "users"]
```

### getColumns()

```php
$columns = $db->getColumns("products");
```

Returns column definitions:

```php
[
    ["name" => "id", "type" => "INTEGER", "nullable" => false, "primary" => true],
    ["name" => "name", "type" => "TEXT", "nullable" => false, "primary" => false],
    ["name" => "price", "type" => "REAL", "nullable" => true, "primary" => false],
    ["name" => "in_stock", "type" => "INTEGER", "nullable" => true, "primary" => false]
]
```

### tableExists()

```php
if ($db->tableExists("products")) {
    // Table exists, safe to query
}
```

### A Schema Info Endpoint

```php
<?php
use Tina4\Router;
use Tina4\Database;

Router::get("/api/schema", function ($request, $response) {
    $db = Database::getConnection();
    $tables = $db->getTables();

    $schema = [];
    foreach ($tables as $table) {
        $schema[$table] = $db->getColumns($table);
    }

    return $response->json(["tables" => $schema]);
});
```

---

## 8. Batch Operations with executeMany()

Insert or update many rows in one call:

```php
$db = Database::getConnection();

$products = [
    ["name" => "Widget A", "price" => 9.99],
    ["name" => "Widget B", "price" => 14.99],
    ["name" => "Widget C", "price" => 19.99],
    ["name" => "Widget D", "price" => 24.99]
];

$db->executeMany(
    "INSERT INTO products (name, price) VALUES (:name, :price)",
    $products
);
```

`executeMany()` prepares the statement once and executes it for each item. The SQL is parsed once. Four rows inserted. Much faster than four separate `execute()` calls.

---

## 9. Helper Methods: insert(), update(), delete()

Shorthand methods for simple operations. No SQL needed.

### insert()

```php
$db = Database::getConnection();

// Insert a single row
$db->insert("products", [
    "name" => "Wireless Mouse",
    "price" => 34.99,
    "in_stock" => 1
]);

// Insert multiple rows
$db->insert("products", [
    ["name" => "USB Cable", "price" => 9.99, "in_stock" => 1],
    ["name" => "HDMI Cable", "price" => 14.99, "in_stock" => 1],
    ["name" => "DisplayPort Cable", "price" => 19.99, "in_stock" => 0]
]);
```

### update()

```php
// Update rows matching a filter
$db->update("products", ["price" => 39.99, "in_stock" => 1], "id = :id", ["id" => 7]);
```

Third argument: WHERE clause. Fourth argument: parameters.

### delete()

```php
// Delete rows matching a filter
$db->delete("products", "id = :id", ["id" => 7]);
```

These helpers generate SQL for you. Convenient for simple CRUD. For complex joins, subqueries, or aggregations, use raw queries.

---

## 10. Migrations

Migrations are versioned SQL scripts that evolve your schema over time. No manual `CREATE TABLE` statements. Write migration files. Tina4 applies them in order and tracks what has run.

### File Naming

Two naming patterns are supported:

- **Sequential**: `000001_create_products_table.sql`
- **Timestamp**: `20260322143000_create_products_table.sql` (YYYYMMDDHHMMSS)

Both work. Pick one pattern and stick with it throughout a project. Do not mix them.

### Generating a Migration

```bash
tina4 generate migration create_products_table
```

```
Created migration: migrations/20260322143000_create_products_table.sql
Created migration: migrations/20260322143000_create_products_table.down.sql
```

The generator creates two files: the migration itself and a matching `.down.sql` file for rollback.

### Writing the Migration

Edit `migrations/20260322143000_create_products_table.sql`:

```sql
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Uncategorized',
    price REAL NOT NULL DEFAULT 0.00,
    in_stock INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

Edit `migrations/20260322143000_create_products_table.down.sql`:

```sql
DROP TABLE IF EXISTS products;
```

The `.down.sql` file is optional but recommended for production projects. It contains the SQL that reverses the migration.

### Running Migrations

```bash
tina4 migrate
# or
tina4php migrate
```

```
Running migrations...
  [APPLIED] 20260322143000_create_products_table.sql
Migrations complete. 1 applied.
```

Each call to `tina4 migrate` is a **batch**. All pending migrations applied in a single run share the same batch number. This matters for rollback.

### Checking Migration Status

```bash
tina4php migrate:status
```

```
Migration                                    Status     Applied At
---------                                    ------     ----------
20260322143000_create_products_table.sql      applied    2026-03-22 14:30:00
20260322150000_create_orders_table.sql        pending    -
```

Shows which migrations have been applied and which are still pending.

### Rolling Back

```bash
tina4php migrate:rollback
```

```
Rolling back last batch...
  [ROLLED BACK] 20260322150000_create_orders_table.sql
Rollback complete. 1 rolled back.
```

Rollback undoes the entire last batch. It finds each migration's `.down.sql` file and executes it, then removes the tracking records. If you applied three migrations in one `tina4 migrate` call, rollback undoes all three.

The `.down.sql` file must share the exact same base name as the migration. For `20260322150000_create_orders_table.sql`, the down file is `20260322150000_create_orders_table.down.sql`.

### Tracking Table

Tina4 creates a `tina4_migration` table to track applied migrations. The table has four columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | integer | Auto-increment primary key |
| `migration` | VARCHAR(255) | The migration filename |
| `batch` | integer | Batch number (increments each `tina4 migrate` run) |
| `applied_at` | timestamp | When the migration was applied |

You should not modify this table directly, but inspecting it can help debug migration issues.

### Advanced SQL: Stored Procedures and Block Comments

The migration runner handles more than simple semicolon-delimited statements. It correctly parses:

- **`$$` delimited blocks** -- PostgreSQL stored procedures and functions
- **`//` blocks** -- alternative delimiter blocks
- **`/* */` block comments** -- skipped during parsing
- **`--` line comments** -- skipped during parsing

A PostgreSQL stored procedure migration works without issues:

```sql
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();
```

No special configuration needed. The SQL splitter recognises `$$` boundaries and treats the block as a single statement.

### A Real Migration Sequence

```
migrations/
├── 20260322143000_create_products_table.sql
├── 20260322143000_create_products_table.down.sql
├── 20260322143100_create_users_table.sql
├── 20260322143100_create_users_table.down.sql
├── 20260322143200_create_orders_table.sql
├── 20260322143200_create_orders_table.down.sql
├── 20260322143300_create_order_items_table.sql
├── 20260322143300_create_order_items_table.down.sql
└── 20260323091500_add_email_index_to_users.sql
```

The index migration without a `.down.sql` -- this is fine. Down migrations are optional. If you roll back and no `.down.sql` exists, the tracking record is removed but no reversal SQL runs.

The index migration:

```sql
CREATE INDEX idx_users_email ON users (email);
```

Its down file (`20260323091500_add_email_index_to_users.down.sql`), if you choose to create one:

```sql
DROP INDEX IF EXISTS idx_users_email;
```

Migrations run in filename order. Each runs only once.

---

## 11. Query Caching

For read-heavy applications:

```env
TINA4_DB_CACHE=true
```

Tina4 caches results of `fetch()` and `fetchOne()` calls. Identical queries with identical parameters return cached results instead of hitting the database.

The cache invalidates when you call `execute()`, `insert()`, `update()`, or `delete()` on the same table.

Per-query control:

```php
// Force a fresh query (bypass cache)
$products = $db->fetch("SELECT * FROM products", [], false); // third arg = use cache

// Clear the entire cache
$db->clearCache();
```

---

## 12. Exercise: Build a Notes App

A notes application backed by SQLite. Migration for the table. Full CRUD API.

### Requirements

1. Create a migration for a `notes` table:
   - `id` -- integer, primary key, auto-increment
   - `title` -- text, not null
   - `content` -- text, not null
   - `tag` -- text, default "general"
   - `created_at` -- text, default current timestamp
   - `updated_at` -- text, default current timestamp

2. Build these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all notes. Support `?tag=` and `?search=` filters. |
| `GET` | `/api/notes/{id:int}` | Get a single note. 404 if not found. |
| `POST` | `/api/notes` | Create a note. Validate title and content are not empty. |
| `PUT` | `/api/notes/{id:int}` | Update a note. 404 if not found. |
| `DELETE` | `/api/notes/{id:int}` | Delete a note. 204 on success, 404 if not found. |

### Test with:

```bash
# Create
curl -X POST http://localhost:7146/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "Shopping List", "content": "Milk, eggs, bread", "tag": "personal"}'

# List all
curl http://localhost:7146/api/notes

# Search
curl "http://localhost:7146/api/notes?search=shopping"

# Filter by tag
curl "http://localhost:7146/api/notes?tag=personal"

# Get one
curl http://localhost:7146/api/notes/1

# Update
curl -X PUT http://localhost:7146/api/notes/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Shopping List", "content": "Milk, eggs, bread, butter"}'

# Delete
curl -X DELETE http://localhost:7146/api/notes/1
```

---

## 13. Solution

### Migration

Generate the migration:

```bash
tina4 generate migration create_notes_table
```

Edit `migrations/20260322143000_create_notes_table.sql`:

```sql
CREATE TABLE notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tag TEXT NOT NULL DEFAULT 'general',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

Edit `migrations/20260322143000_create_notes_table.down.sql`:

```sql
DROP TABLE IF EXISTS notes;
```

Run it:

```bash
tina4 migrate
```

```
Running migrations...
  [APPLIED] 20260322143000_create_notes_table.sql
Migrations complete. 1 applied.
```

### Routes

Create `src/routes/notes.php`:

```php
<?php
use Tina4\Router;
use Tina4\Database;

// List all notes with optional filters
Router::get("/api/notes", function ($request, $response) {
    $db = Database::getConnection();

    $tag = $request->params["tag"] ?? "";
    $search = $request->params["search"] ?? "";

    $sql = "SELECT * FROM notes";
    $params = [];
    $conditions = [];

    if (!empty($tag)) {
        $conditions[] = "tag = :tag";
        $params["tag"] = $tag;
    }

    if (!empty($search)) {
        $conditions[] = "(title LIKE :search OR content LIKE :search)";
        $params["search"] = "%" . $search . "%";
    }

    if (!empty($conditions)) {
        $sql .= " WHERE " . implode(" AND ", $conditions);
    }

    $sql .= " ORDER BY updated_at DESC";

    $notes = $db->fetch($sql, $params);

    return $response->json([
        "notes" => $notes,
        "count" => count($notes)
    ]);
});

// Get a single note
Router::get("/api/notes/{id:int}", function ($request, $response) {
    $db = Database::getConnection();
    $id = $request->params["id"];

    $note = $db->fetchOne("SELECT * FROM notes WHERE id = :id", ["id" => $id]);

    if ($note === null) {
        return $response->json(["error" => "Note not found", "id" => $id], 404);
    }

    return $response->json($note);
});

// Create a note
Router::post("/api/notes", function ($request, $response) {
    $db = Database::getConnection();
    $body = $request->body;

    // Validate
    $errors = [];
    if (empty($body["title"])) {
        $errors[] = "Title is required";
    }
    if (empty($body["content"])) {
        $errors[] = "Content is required";
    }
    if (!empty($errors)) {
        return $response->json(["errors" => $errors], 400);
    }

    $db->execute(
        "INSERT INTO notes (title, content, tag) VALUES (:title, :content, :tag)",
        [
            "title" => $body["title"],
            "content" => $body["content"],
            "tag" => $body["tag"] ?? "general"
        ]
    );

    $note = $db->fetchOne("SELECT * FROM notes WHERE id = last_insert_rowid()");

    return $response->json($note, 201);
});

// Update a note
Router::put("/api/notes/{id:int}", function ($request, $response) {
    $db = Database::getConnection();
    $id = $request->params["id"];
    $body = $request->body;

    $existing = $db->fetchOne("SELECT * FROM notes WHERE id = :id", ["id" => $id]);

    if ($existing === null) {
        return $response->json(["error" => "Note not found", "id" => $id], 404);
    }

    $db->execute(
        "UPDATE notes SET title = :title, content = :content, tag = :tag, updated_at = CURRENT_TIMESTAMP WHERE id = :id",
        [
            "title" => $body["title"] ?? $existing["title"],
            "content" => $body["content"] ?? $existing["content"],
            "tag" => $body["tag"] ?? $existing["tag"],
            "id" => $id
        ]
    );

    $note = $db->fetchOne("SELECT * FROM notes WHERE id = :id", ["id" => $id]);

    return $response->json($note);
});

// Delete a note
Router::delete("/api/notes/{id:int}", function ($request, $response) {
    $db = Database::getConnection();
    $id = $request->params["id"];

    $existing = $db->fetchOne("SELECT * FROM notes WHERE id = :id", ["id" => $id]);

    if ($existing === null) {
        return $response->json(["error" => "Note not found", "id" => $id], 404);
    }

    $db->execute("DELETE FROM notes WHERE id = :id", ["id" => $id]);

    return $response->json(null, 204);
});
```

**Expected output for create:**

```json
{
  "id": 1,
  "title": "Shopping List",
  "content": "Milk, eggs, bread",
  "tag": "personal",
  "created_at": "2026-03-22 14:30:00",
  "updated_at": "2026-03-22 14:30:00"
}
```

(Status: `201 Created`)

**Expected output for list:**

```json
{
  "notes": [
    {
      "id": 1,
      "title": "Shopping List",
      "content": "Milk, eggs, bread",
      "tag": "personal",
      "created_at": "2026-03-22 14:30:00",
      "updated_at": "2026-03-22 14:30:00"
    }
  ],
  "count": 1
}
```

**Expected output for search:**

```json
{
  "notes": [
    {
      "id": 1,
      "title": "Shopping List",
      "content": "Milk, eggs, bread",
      "tag": "personal",
      "created_at": "2026-03-22 14:30:00",
      "updated_at": "2026-03-22 14:30:00"
    }
  ],
  "count": 1
}
```

**Expected output for validation error:**

```json
{"errors": ["Title is required", "Content is required"]}
```

(Status: `400 Bad Request`)

---

## 14. Gotchas

### 1. Forgetting commit()

**Problem:** Queries run inside `startTransaction()`, but changes vanish on the next request.

**Cause:** No `commit()`. The transaction rolls back when the connection closes.

**Fix:** Always call `$db->commit()` on success. Use try/catch with `$db->rollback()` in the catch.

### 2. Connection String Formats

**Problem:** Database refuses to connect. Cryptic error about the connection string.

**Cause:** Missing port. A common mistake is `mysql://user:pass@host/db` without the port number.

**Fix:** Always include the port:

| Engine | Default Port |
|--------|-------------|
| PostgreSQL | 5432 |
| MySQL | 3306 |
| MSSQL | 1433 |
| Firebird | 3050 |
| SQLite | (file path, no port) |

### 3. SQLite File Paths

**Problem:** SQLite creates a new empty database instead of using the existing one.

**Cause:** Wrong slash count. `sqlite://` (two slashes) instead of `sqlite:///` (three slashes). Or a relative path resolving to the wrong directory.

**Fix:** Three slashes for a relative path: `sqlite:///data/app.db`. Four slashes for absolute: `sqlite:////var/data/app.db`. The third slash separates the scheme. The fourth starts the absolute path.

### 4. Parameterised Queries with LIKE

**Problem:** `WHERE name LIKE :q` with `["q" => "%search%"]` works. `WHERE name LIKE '%:q%'` does not.

**Cause:** Parameters inside quotes are literal text, not placeholders.

**Fix:** Put the `%` wildcards in the parameter value: `["q" => "%" . $search . "%"]`. The SQL should be `WHERE name LIKE :q`.

### 5. Boolean Values in SQLite

**Problem:** You insert `true` or `false`. The database stores `1` or `0`. Reading it back gives integers, not booleans.

**Cause:** SQLite has no native boolean type. Booleans become integers.

**Fix:** Cast in PHP: `"in_stock" => (bool) $row["in_stock"]`. Or accept that `1` and `0` work as truthy/falsy.

### 6. Migration Already Applied

**Problem:** You edited a migration file and ran `tina4 migrate` again. Nothing changed.

**Cause:** Tina4 tracks applied migrations by filename in the `tina4_migration` table. Once applied, a migration will not run again regardless of content changes.

**Fix:** Create a new migration for schema changes. Never edit applied migrations. For early development, use `tina4php migrate:rollback` first, then `tina4 migrate` to reapply.

### 7. Down Migration Not Found During Rollback

**Problem:** `tina4php migrate:rollback` removes the tracking record but does not reverse the schema change.

**Cause:** The `.down.sql` file is missing, or its name does not match the migration. For `20260322143000_create_products_table.sql`, the down file must be `20260322143000_create_products_table.down.sql` -- same base name with `.down.sql` appended before the extension.

**Fix:** Always generate migrations with `tina4 generate migration` which creates both files automatically. If you created migration files manually, add the `.down.sql` file with the exact matching name.

### 8. fetch() Returns Empty Array, Not Null

**Problem:** `if ($result === null)` never matches, even when the table is empty.

**Cause:** `fetch()` always returns an array. Empty result is `[]`, not `null`. Only `fetchOne()` returns `null`.

**Fix:** Check with `if (empty($result))` or `if (count($result) === 0)`.
