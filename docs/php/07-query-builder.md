# Chapter 7: QueryBuilder

## 1. Why a Query Builder?

Chapter 5 used raw SQL strings. Chapter 6 wrapped single-table CRUD in the ORM. Both work. Neither handles the messy middle ground well: multi-table joins, conditional filters, pagination, aggregation. You end up concatenating SQL fragments, juggling parameter arrays, and debugging mismatched question marks.

The QueryBuilder sits between raw SQL and the ORM. It builds SQL programmatically through a fluent, chainable API. Every method returns `$this`, so you compose queries left to right. When you need the SQL string, call `toSql()`. When you need results, call `get()`, `first()`, `count()`, or `exists()`.

No magic. No hidden queries. You see exactly what runs.

---

## 2. The Factory: `QueryBuilder::from()`

The constructor is private. You create a QueryBuilder through the static `from()` method:

```php
<?php
use Tina4\QueryBuilder;
use Tina4\Database\Database;

$db = Database::create("sqlite:///data/app.db");

$qb = QueryBuilder::from("users", $db);
```

Two arguments:

- **`$table`** -- The table name. This becomes the `FROM` clause.
- **`$db`** -- A `DatabaseAdapter` instance. Optional if you only need `toSql()`, required if you call any execution method.

The factory returns a fresh `QueryBuilder` instance. Chain methods directly:

```php
$result = QueryBuilder::from("users", $db)
    ->select("id", "name")
    ->where("active = ?", [1])
    ->get();
```

---

## 3. Selecting Columns: `select()`

By default the builder selects all columns (`*`). Narrow the selection with `select()`:

```php
$qb = QueryBuilder::from("products", $db)
    ->select("id", "name", "price");
```

Pass column names as separate string arguments. Expressions work too:

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("customer_id", "SUM(total) as revenue");
```

If you never call `select()`, the builder uses `SELECT *`.

---

## 4. Filtering: `where()`

Add a `WHERE` condition with `where()`:

```php
$qb = QueryBuilder::from("users", $db)
    ->where("active = ?", [1]);
```

The first argument is the SQL condition. Use `?` placeholders for parameter binding. The second argument is an array of values that replace the placeholders in order.

### Multiple `where()` Calls

Each call adds an `AND` condition:

```php
$qb = QueryBuilder::from("products", $db)
    ->where("price > ?", [10])
    ->where("category = ?", ["electronics"]);
```

Generates:

```sql
SELECT * FROM products WHERE price > ? AND category = ?
```

Parameters are accumulated in order: `[10, "electronics"]`.

### Conditions Without Parameters

For conditions that do not need binding:

```php
$qb = QueryBuilder::from("users", $db)
    ->where("email IS NOT NULL");
```

The second argument defaults to an empty array.

---

## 5. OR Conditions: `orWhere()`

Use `orWhere()` to add an `OR` condition:

```php
$qb = QueryBuilder::from("products", $db)
    ->where("category = ?", ["books"])
    ->orWhere("category = ?", ["music"]);
```

Generates:

```sql
SELECT * FROM products WHERE category = ? OR category = ?
```

The first condition in the chain never has a connector prefix. The second gets `OR`. If you mix `where()` and `orWhere()`, they appear in order:

```php
$qb = QueryBuilder::from("products", $db)
    ->where("active = ?", [1])
    ->where("price > ?", [5])
    ->orWhere("featured = ?", [1]);
```

Generates:

```sql
SELECT * FROM products WHERE active = ? AND price > ? OR featured = ?
```

Standard SQL operator precedence applies. If you need grouping, write the grouped condition as a single string:

```php
->where("(category = ? OR category = ?)", ["books", "music"])
```

---

## 6. Joins: `join()` and `leftJoin()`

### Inner Join

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("orders.id", "users.name", "orders.total")
    ->join("users", "users.id = orders.user_id");
```

Generates:

```sql
SELECT orders.id, users.name, orders.total FROM orders INNER JOIN users ON users.id = orders.user_id
```

### Left Join

```php
$qb = QueryBuilder::from("users", $db)
    ->select("users.name", "orders.id as order_id")
    ->leftJoin("orders", "orders.user_id = users.id");
```

Generates:

```sql
SELECT users.name, orders.id as order_id FROM users LEFT JOIN orders ON orders.user_id = users.id
```

### Multiple Joins

Chain as many as you need:

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("orders.id", "users.name", "products.name as product")
    ->join("users", "users.id = orders.user_id")
    ->join("order_items", "order_items.order_id = orders.id")
    ->join("products", "products.id = order_items.product_id");
```

Joins appear in the SQL in the order you call them.

---

## 7. Grouping: `groupBy()`

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("customer_id", "COUNT(*) as order_count")
    ->groupBy("customer_id");
```

Generates:

```sql
SELECT customer_id, COUNT(*) as order_count FROM orders GROUP BY customer_id
```

Call `groupBy()` multiple times for multiple columns:

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("customer_id", "status", "COUNT(*) as cnt")
    ->groupBy("customer_id")
    ->groupBy("status");
```

Generates:

```sql
SELECT customer_id, status, COUNT(*) as cnt FROM orders GROUP BY customer_id, status
```

---

## 8. Filtering Groups: `having()`

`having()` filters aggregated results. It works like `where()` but applies after `GROUP BY`:

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("customer_id", "SUM(total) as revenue")
    ->groupBy("customer_id")
    ->having("SUM(total) > ?", [1000]);
```

Generates:

```sql
SELECT customer_id, SUM(total) as revenue FROM orders GROUP BY customer_id HAVING SUM(total) > ?
```

Multiple `having()` calls are joined with `AND`:

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("customer_id", "COUNT(*) as cnt", "SUM(total) as revenue")
    ->groupBy("customer_id")
    ->having("COUNT(*) > ?", [5])
    ->having("SUM(total) > ?", [500]);
```

Generates:

```sql
... HAVING COUNT(*) > ? AND SUM(total) > ?
```

---

## 9. Sorting: `orderBy()`

```php
$qb = QueryBuilder::from("products", $db)
    ->orderBy("price ASC");
```

Pass the column name and direction as a single string. Call multiple times for multi-column sorts:

```php
$qb = QueryBuilder::from("products", $db)
    ->orderBy("category ASC")
    ->orderBy("price DESC");
```

Generates:

```sql
SELECT * FROM products ORDER BY category ASC, price DESC
```

---

## 10. Pagination: `limit()`

```php
$qb = QueryBuilder::from("products", $db)
    ->limit(10);
```

With an offset for pagination:

```php
$qb = QueryBuilder::from("products", $db)
    ->limit(10, 20); // 10 rows, skip 20
```

The first argument is the maximum number of rows. The second is the offset (number of rows to skip). When you call `get()` without ever calling `limit()`, the builder defaults to 100 rows with offset 0.

---

## 11. Inspecting the SQL: `toSql()`

`toSql()` returns the constructed SQL string without executing it. Invaluable for debugging:

```php
$qb = QueryBuilder::from("orders", $db)
    ->select("customer_id", "SUM(total) as revenue")
    ->join("users", "users.id = orders.user_id")
    ->where("orders.status = ?", ["completed"])
    ->groupBy("customer_id")
    ->having("SUM(total) > ?", [1000])
    ->orderBy("revenue DESC")
    ->limit(10);

echo $qb->toSql();
```

Output:

```sql
SELECT customer_id, SUM(total) as revenue FROM orders INNER JOIN users ON users.id = orders.user_id WHERE orders.status = ? GROUP BY customer_id HAVING SUM(total) > ? ORDER BY revenue DESC
```

Note: `toSql()` does not include the `LIMIT`/`OFFSET` in the SQL string. Those values are passed to the database adapter's `fetch()` method as separate arguments.

`toSql()` does not require a database connection. Use it to build SQL strings for logging, testing, or manual inspection without connecting to a database.

---

## 12. Execution Methods

Four methods execute the query against the database. All require a `DatabaseAdapter` passed to `from()`.

### `get()` -- Fetch All Matching Rows

```php
$result = QueryBuilder::from("users", $db)
    ->where("active = ?", [1])
    ->orderBy("name ASC")
    ->limit(25)
    ->get();
```

Returns the raw result from `DatabaseAdapter::fetch()`. Access rows through `$result['data']`:

```php
foreach ($result['data'] as $row) {
    echo $row['name'] . "\n";
}
```

### `first()` -- Fetch a Single Row

```php
$user = QueryBuilder::from("users", $db)
    ->where("email = ?", ["alice@example.com"])
    ->first();

if ($user !== null) {
    echo $user['name'];
}
```

Returns an associative array for the first matching row, or `null` if nothing matches. Internally sets the limit to 1.

### `count()` -- Count Matching Rows

```php
$total = QueryBuilder::from("orders", $db)
    ->where("status = ?", ["pending"])
    ->count();

echo "Pending orders: {$total}";
```

Returns an integer. Internally replaces your column list with `COUNT(*) as cnt`, executes, and restores the original columns.

### `exists()` -- Check for Any Match

```php
$hasAdmin = QueryBuilder::from("users", $db)
    ->where("role = ?", ["admin"])
    ->exists();

if ($hasAdmin) {
    echo "Admin exists";
}
```

Returns a boolean. Calls `count()` internally and checks if the result is greater than zero.

---

## 13. Chaining It All Together

Every method returns `$this`. Chain them in any order (though a logical order improves readability):

```php
$topCustomers = QueryBuilder::from("orders", $db)
    ->select("users.name", "users.email", "COUNT(*) as order_count", "SUM(orders.total) as total_spent")
    ->join("users", "users.id = orders.user_id")
    ->where("orders.created_at > ?", ["2025-01-01"])
    ->where("orders.status = ?", ["completed"])
    ->groupBy("users.name")
    ->groupBy("users.email")
    ->having("SUM(orders.total) > ?", [500])
    ->orderBy("total_spent DESC")
    ->limit(10)
    ->get();
```

This single chain:

1. Joins orders with users.
2. Filters to completed orders in 2025.
3. Groups by customer.
4. Keeps only customers who spent more than 500.
5. Sorts by spending, highest first.
6. Returns the top 10.

### Using QueryBuilder in Routes

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;
use Tina4\QueryBuilder;

Router::get("/api/products", function (Request $request, Response $response) {
    global $db;

    $qb = QueryBuilder::from("products", $db)
        ->select("id", "name", "price", "category")
        ->where("active = ?", [1])
        ->orderBy("name ASC")
        ->limit(50);

    $result = $qb->get();

    return $response($result['data']);
});
```

### Dynamic Filters

Build queries conditionally based on request parameters:

```php
Router::get("/api/products/search", function (Request $request, Response $response) {
    global $db;

    $qb = QueryBuilder::from("products", $db)
        ->select("id", "name", "price", "category")
        ->where("active = ?", [1]);

    if (!empty($request->query["category"])) {
        $qb->where("category = ?", [$request->query["category"]]);
    }

    if (!empty($request->query["min_price"])) {
        $qb->where("price >= ?", [(float)$request->query["min_price"]]);
    }

    if (!empty($request->query["max_price"])) {
        $qb->where("price <= ?", [(float)$request->query["max_price"]]);
    }

    $sortBy = $request->query["sort"] ?? "name ASC";
    $qb->orderBy($sortBy);

    $limit = (int)($request->query["limit"] ?? 25);
    $offset = (int)($request->query["page"] ?? 0) * $limit;
    $qb->limit($limit, $offset);

    $result = $qb->get();

    return $response($result['data']);
});
```

This is where the builder shines. Conditional filters with raw SQL require clumsy `if` blocks that splice strings and shuffle parameter arrays. With the builder, each `->where()` call simply appends a condition. No index juggling. No string concatenation.

---

## 14. ORM Integration

ORM models can expose a `query()` static method that returns a QueryBuilder pre-configured with the model's table and the global database connection:

```php
class User extends \Tina4\ORM
{
    public string $tableName = "users";
    public string $primaryKey = "id";

    public int $id;
    public string $name;
    public string $email;
    public bool $active = true;

    public static function query(): QueryBuilder
    {
        global $db;
        return QueryBuilder::from("users", $db);
    }
}
```

Then query through the model:

```php
$activeUsers = User::query()
    ->where("active = ?", [1])
    ->orderBy("name ASC")
    ->get();

$count = User::query()
    ->where("role = ?", ["admin"])
    ->count();

$first = User::query()
    ->where("email = ?", ["alice@example.com"])
    ->first();
```

This keeps the ORM for simple CRUD (`save()`, `load()`, `delete()`) and the QueryBuilder for complex reads. Both use the same table. Both use parameterised queries. Pick the tool that fits the job.

---

## 15. NoSQL: MongoDB Queries

The QueryBuilder can generate MongoDB-compatible query documents with `toMongo()`. This returns an associative array containing the filter, projection, sort, limit, and skip -- ready to pass to the MongoDB PHP driver.

### Operator Mapping

| SQL Operator | MongoDB Operator |
|-------------|-----------------|
| `=` | Exact match |
| `!=` | `$ne` |
| `>` | `$gt` |
| `<` | `$lt` |
| `>=` | `$gte` |
| `<=` | `$lte` |
| `LIKE` | `$regex` |
| `IN` | `$in` |
| `IS NULL` | `$exists: false` |
| `IS NOT NULL` | `$exists: true` |

### Example

```php
$query = QueryBuilder::from("users")
    ->select("name", "email")
    ->where("age > ?", [25])
    ->where("status = ?", ["active"])
    ->orderBy("name ASC")
    ->limit(10)
    ->offset(5);

$mongo = $query->toMongo();
```

The returned array:

```php
[
    "filter" => ["age" => ['$gt' => 25], "status" => "active"],
    "projection" => ["name" => 1, "email" => 1],
    "sort" => ["name" => 1],
    "limit" => 10,
    "skip" => 5,
]
```

Pass it directly to the MongoDB driver:

```php
$collection = $client->selectCollection("mydb", "users");
$cursor = $collection->find(
    $mongo["filter"],
    [
        "projection" => $mongo["projection"],
        "sort" => $mongo["sort"],
        "limit" => $mongo["limit"],
        "skip" => $mongo["skip"],
    ]
);
```

---

## 16. Gotchas

### No Database Adapter

Calling `get()`, `first()`, `count()`, or `exists()` without a database adapter throws a `RuntimeException`:

```php
$qb = QueryBuilder::from("users"); // no $db
$qb->get(); // RuntimeException: QueryBuilder: No database adapter provided.
```

Fix: pass a `DatabaseAdapter` as the second argument to `from()`.

### Parameter Order Matters

Parameters are accumulated in the order you call `where()`, `orWhere()`, and `having()`. The `?` placeholders in your conditions must align with the parameter arrays you pass:

```php
// Correct
->where("price > ? AND price < ?", [10, 100])

// Also correct -- two separate calls
->where("price > ?", [10])
->where("price < ?", [100])
```

Both produce the same result. The second form is easier to read and easier to make conditional.

### Default Limit

If you call `get()` without calling `limit()`, the builder defaults to fetching 100 rows with offset 0. This prevents accidental full-table scans on large datasets. Set an explicit `limit()` if you need more:

```php
->limit(500) // fetch up to 500 rows
```

### `toSql()` Does Not Include LIMIT

The `LIMIT` and `OFFSET` are not part of the SQL string returned by `toSql()`. They are passed as separate arguments to the database adapter's `fetch()` method. This is by design -- different database engines handle pagination differently, and the adapter takes care of the dialect-specific syntax.

### `count()` Temporarily Replaces Columns

`count()` swaps your selected columns with `COUNT(*) as cnt` for the query, then restores the original columns. This means calling `toSql()` after `count()` still shows your original columns, not the count expression.

### OR Precedence

SQL evaluates `AND` before `OR`. This query:

```php
->where("active = ?", [1])
->where("price > ?", [5])
->orWhere("featured = ?", [1])
```

Means `(active = 1 AND price > 5) OR featured = 1`, not `active = 1 AND (price > 5 OR featured = 1)`. If you need the second interpretation, group the condition manually:

```php
->where("active = ?", [1])
->where("(price > ? OR featured = ?)", [5, 1])
```

---

## 16. Exercise: Product Search API

Build a product search endpoint that uses QueryBuilder for all database access.

### Setup

Create the migration file `migrations/003_create_products.sql`:

```sql
CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    price REAL DEFAULT 0.00,
    active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO products (name, category, price) VALUES ('PHP in Action', 'books', 29.99);
INSERT INTO products (name, category, price) VALUES ('Mechanical Keyboard', 'electronics', 149.00);
INSERT INTO products (name, category, price) VALUES ('Standing Desk', 'furniture', 499.00);
INSERT INTO products (name, category, price) VALUES ('USB-C Hub', 'electronics', 45.00);
INSERT INTO products (name, category, price) VALUES ('Code Complete', 'books', 35.00);
INSERT INTO products (name, category, price) VALUES ('Monitor Light', 'electronics', 65.00);
INSERT INTO products (name, category, price) VALUES ('Desk Mat', 'furniture', 25.00);
INSERT INTO products (name, category, price) VALUES ('Clean Code', 'books', 32.00);
```

### The Route

Create `src/routes/productSearch.php`:

```php
<?php
use Tina4\Router;
use Tina4\Request;
use Tina4\Response;
use Tina4\QueryBuilder;

/**
 * @description Search products with filters
 * @tags Products
 * @queryParam category string Filter by category
 * @queryParam min_price number Minimum price
 * @queryParam max_price number Maximum price
 * @queryParam search string Search by name
 * @queryParam sort string Sort field and direction (e.g. "price DESC")
 * @queryParam limit int Results per page (default 10)
 * @queryParam page int Page number (default 0)
 * @example /api/products/search?category=books&min_price=20&sort=price ASC
 */
Router::get("/api/products/search", function (Request $request, Response $response) {
    global $db;

    try {
        $qb = QueryBuilder::from("products", $db)
            ->select("id", "name", "category", "price")
            ->where("active = ?", [1]);

        // Category filter
        if (!empty($request->query["category"])) {
            $qb->where("category = ?", [$request->query["category"]]);
        }

        // Price range
        if (!empty($request->query["min_price"])) {
            $qb->where("price >= ?", [(float)$request->query["min_price"]]);
        }
        if (!empty($request->query["max_price"])) {
            $qb->where("price <= ?", [(float)$request->query["max_price"]]);
        }

        // Name search
        if (!empty($request->query["search"])) {
            $qb->where("name LIKE ?", ["%" . $request->query["search"] . "%"]);
        }

        // Sorting
        $sort = $request->query["sort"] ?? "name ASC";
        $qb->orderBy($sort);

        // Pagination
        $limit = (int)($request->query["limit"] ?? 10);
        $page = (int)($request->query["page"] ?? 0);
        $qb->limit($limit, $page * $limit);

        // Get total count (separate query)
        $countQb = QueryBuilder::from("products", $db)
            ->where("active = ?", [1]);

        if (!empty($request->query["category"])) {
            $countQb->where("category = ?", [$request->query["category"]]);
        }
        if (!empty($request->query["min_price"])) {
            $countQb->where("price >= ?", [(float)$request->query["min_price"]]);
        }
        if (!empty($request->query["max_price"])) {
            $countQb->where("price <= ?", [(float)$request->query["max_price"]]);
        }
        if (!empty($request->query["search"])) {
            $countQb->where("name LIKE ?", ["%" . $request->query["search"] . "%"]);
        }

        $total = $countQb->count();
        $result = $qb->get();

        return $response([
            "data" => $result['data'] ?? [],
            "total" => $total,
            "page" => $page,
            "limit" => $limit,
            "pages" => ceil($total / $limit),
        ]);
    } catch (\Throwable $e) {
        \Tina4\Debug::message($e->getMessage(), TINA4_LOG_ERROR);
        return $response(["error" => "Search failed"], 500);
    }
});
```

### Test It

```bash
# All active products
curl "http://localhost:7146/api/products/search"

# Books only
curl "http://localhost:7146/api/products/search?category=books"

# Electronics under $100
curl "http://localhost:7146/api/products/search?category=electronics&max_price=100"

# Search by name, sorted by price
curl "http://localhost:7146/api/products/search?search=Code&sort=price%20DESC"

# Page 2, 3 per page
curl "http://localhost:7146/api/products/search?limit=3&page=1"
```

### Verify the SQL

Add a debug line to inspect what the builder generates:

```php
\Tina4\Debug::message("SQL: " . $qb->toSql(), TINA4_LOG_DEBUG);
```

Check the log output. The SQL should match your filters exactly. No extra conditions. No missing joins. What you chain is what you get.

---

## Summary

| Method | Purpose | Returns |
|--------|---------|---------|
| `QueryBuilder::from($table, $db)` | Create a builder | `QueryBuilder` |
| `->select(...$columns)` | Set columns | `$this` |
| `->where($condition, $params)` | AND filter | `$this` |
| `->orWhere($condition, $params)` | OR filter | `$this` |
| `->join($table, $on)` | INNER JOIN | `$this` |
| `->leftJoin($table, $on)` | LEFT JOIN | `$this` |
| `->groupBy($column)` | GROUP BY | `$this` |
| `->having($expression, $params)` | HAVING filter | `$this` |
| `->orderBy($expression)` | ORDER BY | `$this` |
| `->limit($count, $offset)` | LIMIT / OFFSET | `$this` |
| `->toSql()` | Get SQL string | `string` |
| `->get()` | Fetch rows | `mixed` |
| `->first()` | Fetch one row | `?array` |
| `->count()` | Count rows | `int` |
| `->exists()` | Check existence | `bool` |
