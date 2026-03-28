# Chapter 12: QueryBuilder

Every database query starts as a string. Small queries stay readable. But the moment you add optional filters, pagination, sorting, and joins, string concatenation turns your code into an unreadable mess of `if` statements and f-strings. One missed space, one misplaced comma, and the query breaks.

QueryBuilder solves this. It gives you a fluent, chainable API that assembles SQL for you. You describe what you want — columns, conditions, joins, ordering — and QueryBuilder produces the correct SQL string with properly separated parameters. No concatenation. No injection risk. No debugging whitespace.

---

## 1. The Factory: from_table()

Every QueryBuilder chain starts with `from_table()`. It takes a table name and an optional database connection.

```python
from tina4_python.query_builder import QueryBuilder

qb = QueryBuilder.from_table("users", db)
```

The first argument is the table name. The second is your database connection — the same `Database` object you use everywhere else. If you omit the database, QueryBuilder will fall back to the global ORM database (set via `orm_bind()`). If neither exists, it raises a `RuntimeError` when you try to execute.

`from_table()` returns a fresh `QueryBuilder` instance. Every method you call on it returns the same instance, so you can chain.

---

## 2. Choosing Columns: select()

By default, QueryBuilder selects all columns (`*`). Use `select()` to narrow the result.

```python
qb = QueryBuilder.from_table("users", db) \
    .select("id", "name", "email")
```

Pass column names as separate arguments — not a list. Each call to `select()` replaces the previous column selection.

```python
# This selects only "email", not "id", "name", "email"
qb = QueryBuilder.from_table("users", db) \
    .select("id", "name") \
    .select("email")
```

If you want all columns, skip `select()` entirely. The default is `*`.

---

## 3. Filtering: where() and or_where()

`where()` adds a condition joined with `AND`. Use `?` placeholders for parameter values.

```python
result = QueryBuilder.from_table("users", db) \
    .where("active = ?", [1]) \
    .where("age > ?", [18]) \
    .get()
```

This produces:

```sql
SELECT * FROM users WHERE active = ? AND age > ?
```

Parameters `[1, 18]` are passed separately to the database driver. No string interpolation. No injection.

### OR conditions

Use `or_where()` when you need an OR clause.

```python
result = QueryBuilder.from_table("users", db) \
    .where("role = ?", ["admin"]) \
    .or_where("role = ?", ["superadmin"]) \
    .get()
```

Produces:

```sql
SELECT * FROM users WHERE role = ? OR role = ?
```

The first condition in the chain never gets a connector prefix. Every subsequent `where()` adds `AND`, and every `or_where()` adds `OR`.

### Conditions without parameters

Some conditions do not need parameters. Pass the condition string alone.

```python
qb.where("deleted_at IS NULL")
```

---

## 4. Joins: join() and left_join()

`join()` adds an `INNER JOIN`. `left_join()` adds a `LEFT JOIN`. Both take a table name and an ON clause.

```python
result = QueryBuilder.from_table("orders", db) \
    .select("orders.id", "users.name", "orders.total") \
    .join("users", "users.id = orders.user_id") \
    .where("orders.total > ?", [100]) \
    .get()
```

Produces:

```sql
SELECT orders.id, users.name, orders.total
FROM orders
INNER JOIN users ON users.id = orders.user_id
WHERE orders.total > ?
```

For optional relationships — where a matching row might not exist — use `left_join()`.

```python
result = QueryBuilder.from_table("users", db) \
    .select("users.name", "profiles.avatar") \
    .left_join("profiles", "profiles.user_id = users.id") \
    .get()
```

You can chain multiple joins. They appear in the SQL in the order you add them.

```python
result = QueryBuilder.from_table("orders", db) \
    .join("users", "users.id = orders.user_id") \
    .join("products", "products.id = orders.product_id") \
    .left_join("discounts", "discounts.order_id = orders.id") \
    .get()
```

---

## 5. Aggregation: group_by() and having()

`group_by()` groups rows by a column. Call it once per column.

```python
result = QueryBuilder.from_table("orders", db) \
    .select("user_id", "COUNT(*) as order_count", "SUM(total) as revenue") \
    .group_by("user_id") \
    .get()
```

Produces:

```sql
SELECT user_id, COUNT(*) as order_count, SUM(total) as revenue
FROM orders
GROUP BY user_id
```

To group by multiple columns, chain multiple calls.

```python
qb.group_by("user_id").group_by("status")
```

### Filtering groups with having()

`having()` filters after aggregation. It works like `where()` but applies to grouped results.

```python
result = QueryBuilder.from_table("orders", db) \
    .select("user_id", "COUNT(*) as order_count") \
    .group_by("user_id") \
    .having("COUNT(*) > ?", [5]) \
    .get()
```

Produces:

```sql
SELECT user_id, COUNT(*) as order_count
FROM orders
GROUP BY user_id
HAVING COUNT(*) > ?
```

Parameters in `having()` are kept separate from `where()` parameters internally but merged at execution time. The order is always correct.

---

## 6. Sorting: order_by()

`order_by()` takes a column name and optional direction as a single string.

```python
result = QueryBuilder.from_table("users", db) \
    .order_by("name ASC") \
    .get()
```

Chain multiple calls for multi-column sorting. They appear in the SQL in order.

```python
result = QueryBuilder.from_table("products", db) \
    .order_by("category ASC") \
    .order_by("price DESC") \
    .get()
```

Produces:

```sql
SELECT * FROM products ORDER BY category ASC, price DESC
```

If you omit the direction, your database's default applies (usually `ASC`).

---

## 7. Pagination: limit()

`limit()` sets the maximum number of rows. Pass an optional second argument for the offset.

```python
# First page: 10 rows starting at row 0
result = QueryBuilder.from_table("users", db) \
    .limit(10) \
    .get()

# Second page: 10 rows starting at row 10
result = QueryBuilder.from_table("users", db) \
    .limit(10, 10) \
    .get()

# Third page
result = QueryBuilder.from_table("users", db) \
    .limit(10, 20) \
    .get()
```

When you call `get()`, the limit and offset values are passed to `db.fetch()`. If you do not call `limit()`, the default is 100 rows starting at offset 0.

### Pagination pattern

A common pattern for API endpoints:

```python
@get("/api/users")
async def list_users(request, response):
    page = int(request.params.get("page", 1))
    per_page = int(request.params.get("per_page", 20))
    offset = (page - 1) * per_page

    result = QueryBuilder.from_table("users", db) \
        .select("id", "name", "email") \
        .where("active = ?", [1]) \
        .order_by("name ASC") \
        .limit(per_page, offset) \
        .get()

    total = QueryBuilder.from_table("users", db) \
        .where("active = ?", [1]) \
        .count()

    return response({
        "users": result.to_list(),
        "total": total,
        "page": page,
        "per_page": per_page,
    })
```

---

## 8. Inspecting the SQL: to_sql()

Before executing, you can inspect the generated SQL with `to_sql()`. This is useful for debugging.

```python
qb = QueryBuilder.from_table("users", db) \
    .select("id", "name") \
    .where("active = ?", [1]) \
    .order_by("name ASC") \
    .limit(10)

print(qb.to_sql())
```

Output:

```sql
SELECT id, name FROM users WHERE active = ? ORDER BY name ASC
```

Note that `to_sql()` does not include `LIMIT` or `OFFSET` in the string. Those values are passed as arguments to `db.fetch()` at execution time. The SQL string shows everything else — columns, joins, conditions, grouping, having, and ordering.

`to_sql()` does not execute anything. It does not require a database connection. Use it freely for logging and debugging.

---

## 9. Execution Methods

Four methods execute the query against the database.

### get() — Multiple rows

Returns a `DatabaseResult` object. Use `.records` for the list of dicts, `.to_list()` for a plain list, or iterate directly.

```python
result = QueryBuilder.from_table("users", db) \
    .where("active = ?", [1]) \
    .get()

for row in result:
    print(row["name"])
```

### first() — Single row

Returns a single dict, or `None` if no rows match.

```python
user = QueryBuilder.from_table("users", db) \
    .where("email = ?", ["alice@example.com"]) \
    .first()

if user:
    print(user["name"])
```

### count() — Row count

Returns an integer. Internally rewrites the select to `COUNT(*) as cnt` and reads the result.

```python
total = QueryBuilder.from_table("orders", db) \
    .where("status = ?", ["pending"]) \
    .count()

print(f"{total} pending orders")
```

### exists() — Boolean check

Returns `True` if at least one row matches, `False` otherwise. Calls `count()` under the hood.

```python
if QueryBuilder.from_table("users", db) \
    .where("email = ?", ["alice@example.com"]) \
    .exists():
    print("User exists")
```

---

## 10. Chaining — Building Complex Queries

Every method returns `self`, so you can chain everything into a single expression. Here is a realistic example that combines most features.

```python
result = QueryBuilder.from_table("orders", db) \
    .select(
        "orders.id",
        "users.name as customer",
        "products.name as product",
        "orders.quantity",
        "orders.total",
        "orders.created_at",
    ) \
    .join("users", "users.id = orders.user_id") \
    .join("products", "products.id = orders.product_id") \
    .where("orders.status = ?", ["completed"]) \
    .where("orders.created_at > ?", ["2025-01-01"]) \
    .order_by("orders.created_at DESC") \
    .limit(50) \
    .get()
```

You can also build queries conditionally. Since each method returns the same instance, store it in a variable and add clauses as needed.

```python
@get("/api/products")
async def search_products(request, response):
    qb = QueryBuilder.from_table("products", db) \
        .select("id", "name", "price", "category")

    # Apply filters only if provided
    category = request.params.get("category")
    if category:
        qb.where("category = ?", [category])

    min_price = request.params.get("min_price")
    if min_price:
        qb.where("price >= ?", [float(min_price)])

    max_price = request.params.get("max_price")
    if max_price:
        qb.where("price <= ?", [float(max_price)])

    search = request.params.get("q")
    if search:
        qb.where("name LIKE ?", [f"%{search}%"])

    # Always sort and paginate
    qb.order_by("name ASC")
    qb.limit(20)

    return response(qb.get().to_list())
```

This is where QueryBuilder shines. Without it, you would be concatenating SQL fragments with `if` checks and tracking parameter positions manually.

---

## 11. Using with ORM Models

If your ORM models are bound to a database via `orm_bind()`, QueryBuilder can use that connection automatically. You do not need to pass `db` explicitly.

```python
from tina4_python.query_builder import QueryBuilder

# No db argument — uses the global ORM database
result = QueryBuilder.from_table("users") \
    .where("active = ?", [1]) \
    .get()
```

When you call `get()`, `first()`, `count()`, or `exists()` without a database connection, QueryBuilder checks the global ORM database. If it finds one, it uses it. If not, it raises `RuntimeError: QueryBuilder: No database connection provided.`

This means you can use QueryBuilder in the same files as your ORM models without importing or passing the database around.

### When to use QueryBuilder vs ORM

Use the ORM when you are working with a single model — loading, saving, deleting records. The ORM gives you objects with attributes.

Use QueryBuilder when you need joins across tables, aggregations, complex filtering, or you want a `DatabaseResult` instead of model instances.

```python
# ORM — single model operations
user = User.find(1)
user.name = "Alice"
user.save()

# QueryBuilder — cross-table query with joins
result = QueryBuilder.from_table("users", db) \
    .select("users.name", "COUNT(orders.id) as order_count") \
    .join("orders", "orders.user_id = users.id") \
    .group_by("users.name") \
    .having("COUNT(orders.id) > ?", [10]) \
    .order_by("order_count DESC") \
    .get()
```

---

## NoSQL: MongoDB Queries

The QueryBuilder can generate MongoDB-compatible query documents with `to_mongo()`. This returns a dict containing the filter, projection, sort, limit, and skip -- ready to pass to PyMongo or any MongoDB driver.

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

```python
from tina4 import QueryBuilder

query = (
    QueryBuilder.from_table("users")
    .select("name", "email")
    .where("age > ?", [25])
    .where("status = ?", ["active"])
    .order_by("name ASC")
    .limit(10)
    .offset(5)
)

mongo = query.to_mongo()
```

The returned dict:

```python
{
    "filter": {"age": {"$gt": 25}, "status": "active"},
    "projection": {"name": 1, "email": 1},
    "sort": [("name", 1)],
    "limit": 10,
    "skip": 5,
}
```

Pass it directly to PyMongo:

```python
collection = db["users"]
cursor = collection.find(
    mongo["filter"],
    mongo["projection"]
).sort(mongo["sort"]).limit(mongo["limit"]).skip(mongo["skip"])
```

---

## Gotchas

### 1. "select() replaced my columns"

**Cause:** Each call to `select()` replaces the column list. It does not append.

**Fix:** Pass all columns in a single `select()` call.

```python
# Wrong — only selects "email"
qb.select("id", "name").select("email")

# Right — selects all three
qb.select("id", "name", "email")
```

### 2. "My LIMIT is not in to_sql() output"

**Cause:** `to_sql()` builds the SQL string but does not include `LIMIT` or `OFFSET`. Those values are passed as separate arguments to `db.fetch()` when you call `get()`.

**Fix:** This is expected behaviour. If you need to see the full query for debugging, print both `to_sql()` and the limit/offset values.

### 3. "count() returns 0 but get() returns rows"

**Cause:** `count()` temporarily replaces the select columns with `COUNT(*) as cnt`. If you have a `GROUP BY` clause, the count query counts groups, not total rows. The first group's count is returned, which may be unexpected.

**Fix:** For simple row counts without grouping, `count()` works correctly. For grouped queries, use `get()` and check the result length instead.

### 4. "RuntimeError: No database connection provided"

**Cause:** You called an execution method (`get()`, `first()`, `count()`, `exists()`) without passing a database to `from_table()` and without having called `orm_bind()`.

**Fix:** Either pass the database explicitly:

```python
QueryBuilder.from_table("users", db).get()
```

Or ensure `orm_bind(db)` has been called in your `app.py` before the query runs.

### 5. "or_where() on the first condition has no effect"

**Cause:** The first condition in the chain never gets a connector prefix (`AND` or `OR`). Whether you use `where()` or `or_where()` for the first condition, the result is the same.

**Fix:** This is by design. The connector only matters from the second condition onward.

### 6. "Parameters are in the wrong order"

**Cause:** `having()` parameters are stored separately from `where()` parameters. At execution time, they are merged as `where_params + having_params`. If you mix calls in an unusual order, the parameter positions might not match your expectations.

**Fix:** Add all `where()` conditions before `having()` conditions. This matches the natural SQL order and keeps parameters aligned.

---

## Exercise: Product Search API

Build a product search endpoint that:

1. Accepts optional query parameters: `category`, `min_price`, `max_price`, `sort` (column name), `order` (`asc` or `desc`), `page`, `per_page`.
2. Returns matching products with their category name (joined from a `categories` table).
3. Includes total count and pagination metadata in the response.
4. Returns an empty list (not an error) when no products match.

### Solution

```python
# src/routes/products.py
from tina4_python.core.router import get
from tina4_python.query_builder import QueryBuilder

ALLOWED_SORT_COLUMNS = {"name", "price", "created_at"}

@get("/api/products")
async def search_products(request, response):
    page = max(int(request.params.get("page", 1)), 1)
    per_page = min(int(request.params.get("per_page", 20)), 100)
    offset = (page - 1) * per_page

    # Base query with join
    qb = QueryBuilder.from_table("products", db) \
        .select(
            "products.id",
            "products.name",
            "products.price",
            "categories.name as category",
            "products.created_at",
        ) \
        .left_join("categories", "categories.id = products.category_id")

    # Count query — same filters, no join needed for count
    count_qb = QueryBuilder.from_table("products", db)

    # Apply filters to both queries
    category = request.params.get("category")
    if category:
        qb.where("categories.name = ?", [category])
        count_qb.join("categories", "categories.id = products.category_id")
        count_qb.where("categories.name = ?", [category])

    min_price = request.params.get("min_price")
    if min_price:
        qb.where("products.price >= ?", [float(min_price)])
        count_qb.where("products.price >= ?", [float(min_price)])

    max_price = request.params.get("max_price")
    if max_price:
        qb.where("products.price <= ?", [float(max_price)])
        count_qb.where("products.price <= ?", [float(max_price)])

    # Sorting — validate column name to prevent injection
    sort_col = request.params.get("sort", "name")
    if sort_col not in ALLOWED_SORT_COLUMNS:
        sort_col = "name"

    sort_dir = request.params.get("order", "asc").upper()
    if sort_dir not in ("ASC", "DESC"):
        sort_dir = "ASC"

    qb.order_by(f"products.{sort_col} {sort_dir}")

    # Paginate
    qb.limit(per_page, offset)

    # Execute
    result = qb.get()
    total = count_qb.count()

    return response({
        "products": result.to_list(),
        "total": total,
        "page": page,
        "per_page": per_page,
        "pages": (total + per_page - 1) // per_page,
    })
```

The sort column is validated against a whitelist. The direction is constrained to `ASC` or `DESC`. User input never touches the SQL directly — it either goes through `?` placeholders or gets checked against known-safe values. QueryBuilder handles the assembly. The route handler stays readable.
