# Chapter 7: QueryBuilder

## 1. Why a Query Builder?

Chapter 5 covered raw SQL. Chapter 6 covered the ORM. Both work. But raw SQL is error-prone for dynamic queries -- the more conditions you add, the more string concatenation you juggle. The ORM handles simple CRUD but steps aside for complex filtering, joins, and aggregations.

The QueryBuilder sits between the two. It gives you a fluent, chainable Ruby API that builds SQL for you. You describe *what* you want. It handles the syntax. No string concatenation. No misplaced commas. No forgotten WHERE keywords.

---

## 2. Creating a QueryBuilder

Every query starts with `Tina4::QueryBuilder.from`:

```ruby
query = Tina4::QueryBuilder.from("users", db: db)
```

The first argument is the table name. The `db:` keyword argument is the database connection. If you omit `db:`, the QueryBuilder will fall back to `Tina4.database` when you execute the query -- but it will raise an error if no connection is available.

You can also access the QueryBuilder from an ORM model:

```ruby
query = User.query
```

This creates a QueryBuilder pre-configured with the model's table name and the active database connection.

---

## 3. Selecting Columns

By default, the QueryBuilder selects all columns (`*`). Use `.select` to pick specific columns:

```ruby
query = Tina4::QueryBuilder.from("users", db: db)
  .select("id", "name", "email")
```

Pass as many column names as you need. Each is a separate string argument:

```ruby
query = Tina4::QueryBuilder.from("products", db: db)
  .select("name", "price", "category")
```

If you call `.select` with no arguments, the columns remain unchanged.

---

## 4. Filtering with where

Add conditions with `.where`. Use `?` placeholders for parameters:

```ruby
results = Tina4::QueryBuilder.from("users", db: db)
  .where("active = ?", [1])
  .get
```

The first argument is the SQL condition. The second is an array of parameter values that replace the `?` placeholders. The database driver handles escaping. Your input never touches the SQL string directly.

### Multiple where Calls

Chain multiple `.where` calls. They combine with AND:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .where("price > ?", [10.00])
  .where("category = ?", ["Electronics"])
  .get
```

This generates:

```sql
SELECT * FROM products WHERE price > ? AND category = ?
```

The first `.where` produces the condition directly. Every subsequent `.where` prepends `AND`.

---

## 5. OR Conditions with or_where

Use `.or_where` when you need OR logic:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .where("category = ?", ["Electronics"])
  .or_where("category = ?", ["Books"])
  .get
```

This generates:

```sql
SELECT * FROM products WHERE category = ? OR category = ?
```

You can mix `.where` and `.or_where` freely:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .where("price > ?", [10.00])
  .where("in_stock = ?", [1])
  .or_where("featured = ?", [1])
  .get
```

This generates:

```sql
SELECT * FROM products WHERE price > ? AND in_stock = ? OR featured = ?
```

If you need grouped conditions (parentheses), write the group as a single condition string:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .where("price > ?", [10.00])
  .where("(category = ? OR category = ?)", ["Electronics", "Books"])
  .get
```

---

## 6. Joins

### Inner Join

```ruby
results = Tina4::QueryBuilder.from("orders", db: db)
  .select("orders.id", "users.name", "orders.total")
  .join("users", "users.id = orders.user_id")
  .get
```

This generates:

```sql
SELECT orders.id, users.name, orders.total FROM orders INNER JOIN users ON users.id = orders.user_id
```

### Left Join

```ruby
results = Tina4::QueryBuilder.from("users", db: db)
  .select("users.name", "orders.total")
  .left_join("orders", "orders.user_id = users.id")
  .get
```

This generates:

```sql
SELECT users.name, orders.total FROM users LEFT JOIN orders ON orders.user_id = users.id
```

### Multiple Joins

Chain as many joins as you need:

```ruby
results = Tina4::QueryBuilder.from("order_items", db: db)
  .select("products.name", "order_items.quantity", "orders.status")
  .join("products", "products.id = order_items.product_id")
  .join("orders", "orders.id = order_items.order_id")
  .where("orders.status = ?", ["completed"])
  .get
```

---

## 7. Ordering

Use `.order_by` to sort results:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .order_by("price ASC")
  .get
```

Pass the column name and direction as a single string. Chain multiple `.order_by` calls for multi-column sorting:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .order_by("category ASC")
  .order_by("price DESC")
  .get
```

This generates:

```sql
SELECT * FROM products ORDER BY category ASC, price DESC
```

---

## 8. Limiting and Offsetting

Use `.limit` to cap the number of rows returned:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .order_by("created_at DESC")
  .limit(10)
  .get
```

Pass a second argument for the offset:

```ruby
# Skip 20 rows, return the next 10
results = Tina4::QueryBuilder.from("products", db: db)
  .order_by("created_at DESC")
  .limit(10, 20)
  .get
```

If you do not call `.limit`, the QueryBuilder defaults to 100 rows with an offset of 0 when you call `.get`. This prevents accidental full-table dumps.

---

## 9. Grouping and Having

### Group By

```ruby
results = Tina4::QueryBuilder.from("orders", db: db)
  .select("status", "COUNT(*) AS order_count")
  .group_by("status")
  .get
```

This generates:

```sql
SELECT status, COUNT(*) AS order_count FROM orders GROUP BY status
```

### Having

Filter grouped results with `.having`:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .select("category", "AVG(price) AS avg_price")
  .group_by("category")
  .having("AVG(price) > ?", [50.00])
  .get
```

This generates:

```sql
SELECT category, AVG(price) AS avg_price FROM products GROUP BY category HAVING AVG(price) > ?
```

Multiple `.having` calls combine with AND:

```ruby
results = Tina4::QueryBuilder.from("products", db: db)
  .select("category", "COUNT(*) AS cnt", "AVG(price) AS avg_price")
  .group_by("category")
  .having("COUNT(*) > ?", [5])
  .having("AVG(price) < ?", [100.00])
  .get
```

---

## 10. Executing Queries

The QueryBuilder provides four execution methods.

### get -- Multiple Rows

```ruby
results = Tina4::QueryBuilder.from("users", db: db)
  .where("active = ?", [1])
  .order_by("name ASC")
  .limit(25)
  .get
```

Returns a `DatabaseResult` object. You can iterate over it, access rows by index, call `.to_json`, `.to_csv`, or `.to_paginate` -- everything covered in Chapter 5.

### first -- Single Row

```ruby
user = Tina4::QueryBuilder.from("users", db: db)
  .where("email = ?", ["alice@example.com"])
  .first
```

Returns a single hash, or `nil` if no row matches. Useful when you expect exactly one result.

### count -- Row Count

```ruby
total = Tina4::QueryBuilder.from("users", db: db)
  .where("active = ?", [1])
  .count
```

Returns an integer. The QueryBuilder rewrites your columns to `COUNT(*) AS cnt` internally, so it works regardless of what you passed to `.select`.

### exists? -- Boolean Check

```ruby
if Tina4::QueryBuilder.from("users", db: db)
     .where("email = ?", ["alice@example.com"])
     .exists?
  puts "User found"
end
```

Returns `true` if at least one matching row exists, `false` otherwise. Calls `.count` under the hood.

---

## 11. Inspecting the SQL with to_sql

Call `.to_sql` to see the generated SQL without executing it:

```ruby
query = Tina4::QueryBuilder.from("products", db: db)
  .select("name", "price")
  .where("category = ?", ["Electronics"])
  .where("price > ?", [50.00])
  .order_by("price DESC")
  .limit(10)

puts query.to_sql
```

Output:

```sql
SELECT name, price FROM products WHERE category = ? AND price > ? ORDER BY price DESC
```

This is invaluable for debugging. If a query returns unexpected results, print the SQL and check the logic. Note that `.to_sql` shows the SQL with `?` placeholders -- the actual parameter values are bound at execution time by the database driver.

---

## 12. Using QueryBuilder in Routes

### A Filtered API Endpoint

```ruby
Tina4::Router.get("/api/products") do |request, response|
  db = Tina4.database

  query = Tina4::QueryBuilder.from("products", db: db)

  # Apply filters from query string
  category = request.params["category"]
  min_price = request.params["min_price"]
  max_price = request.params["max_price"]
  search = request.params["search"]

  query = query.where("category = ?", [category]) if category
  query = query.where("price >= ?", [min_price.to_f]) if min_price
  query = query.where("price <= ?", [max_price.to_f]) if max_price
  query = query.where("name LIKE ?", ["%#{search}%"]) if search

  # Pagination
  page = (request.params["page"] || 1).to_i
  per_page = (request.params["per_page"] || 20).to_i
  offset = (page - 1) * per_page

  total = query.count

  results = query
    .order_by("name ASC")
    .limit(per_page, offset)
    .get

  response.call({
    products: results,
    total: total,
    page: page,
    per_page: per_page
  }, Tina4::HTTP_OK)
end
```

```bash
curl "http://localhost:7147/api/products?category=Electronics&min_price=50&page=2&per_page=10"
```

### A Dashboard Summary Endpoint

```ruby
Tina4::Router.get("/api/dashboard/summary") do |request, response|
  db = Tina4.database

  # Total users
  total_users = Tina4::QueryBuilder.from("users", db: db).count

  # Active users
  active_users = Tina4::QueryBuilder.from("users", db: db)
    .where("active = ?", [1])
    .count

  # Revenue by category
  revenue = Tina4::QueryBuilder.from("order_items", db: db)
    .select("products.category", "SUM(order_items.quantity * order_items.price) AS revenue")
    .join("products", "products.id = order_items.product_id")
    .group_by("products.category")
    .order_by("revenue DESC")
    .get

  response.call({
    total_users: total_users,
    active_users: active_users,
    revenue_by_category: revenue
  }, Tina4::HTTP_OK)
end
```

---

## 13. Exercise: Build a Product Search API

Build a product search endpoint that uses the QueryBuilder for all database access.

### Requirements

1. Assume the `products` table from Chapter 5 exists with columns: `id`, `name`, `category`, `price`, `in_stock`, `created_at`.

2. Build these API endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products/search` | Search products. Support `?q=`, `?category=`, `?min_price=`, `?max_price=`, `?in_stock=`, `?sort=`, `?page=`, `?per_page=`. |
| `GET` | `/api/products/stats` | Return category statistics: product count and average price per category. Only include categories with more than 2 products. |

### Test with:

```bash
# Full-text search with price range
curl "http://localhost:7147/api/products/search?q=wireless&min_price=20&max_price=100"

# Category filter with pagination
curl "http://localhost:7147/api/products/search?category=Electronics&page=1&per_page=5&sort=price_desc"

# In-stock only
curl "http://localhost:7147/api/products/search?in_stock=1&sort=name_asc"

# Category stats
curl "http://localhost:7147/api/products/stats"
```

---

## 14. Solution

### Search Endpoint

Create `src/routes/product_search.rb`:

```ruby
Tina4::Router.get("/api/products/search") do |request, response|
  db = Tina4.database

  query = Tina4::QueryBuilder.from("products", db: db)

  # Text search
  q = request.params["q"]
  query = query.where("name LIKE ?", ["%#{q}%"]) if q && !q.empty?

  # Category filter
  category = request.params["category"]
  query = query.where("category = ?", [category]) if category && !category.empty?

  # Price range
  min_price = request.params["min_price"]
  query = query.where("price >= ?", [min_price.to_f]) if min_price

  max_price = request.params["max_price"]
  query = query.where("price <= ?", [max_price.to_f]) if max_price

  # In-stock filter
  in_stock = request.params["in_stock"]
  query = query.where("in_stock = ?", [in_stock.to_i]) if in_stock

  # Total count before pagination
  total = query.count

  # Sorting
  sort = request.params["sort"] || "name_asc"
  order = case sort
          when "price_asc"  then "price ASC"
          when "price_desc" then "price DESC"
          when "name_desc"  then "name DESC"
          when "newest"     then "created_at DESC"
          else "name ASC"
          end

  # Pagination
  page = (request.params["page"] || 1).to_i
  per_page = (request.params["per_page"] || 20).to_i
  offset = (page - 1) * per_page

  results = query
    .order_by(order)
    .limit(per_page, offset)
    .get

  response.call({
    products: results,
    total: total,
    page: page,
    per_page: per_page,
    sort: sort
  }, Tina4::HTTP_OK)
end
```

### Stats Endpoint

```ruby
Tina4::Router.get("/api/products/stats") do |request, response|
  db = Tina4.database

  stats = Tina4::QueryBuilder.from("products", db: db)
    .select("category", "COUNT(*) AS product_count", "ROUND(AVG(price), 2) AS avg_price")
    .group_by("category")
    .having("COUNT(*) > ?", [2])
    .order_by("product_count DESC")
    .get

  response.call({
    categories: stats
  }, Tina4::HTTP_OK)
end
```

**Expected output for search:**

```json
{
  "products": [
    {"id": 5, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": 1},
    {"id": 8, "name": "Wireless Mouse", "category": "Electronics", "price": 34.99, "in_stock": 1}
  ],
  "total": 2,
  "page": 1,
  "per_page": 20,
  "sort": "name_asc"
}
```

**Expected output for stats:**

```json
{
  "categories": [
    {"category": "Electronics", "product_count": 12, "avg_price": 149.99},
    {"category": "Books", "product_count": 8, "avg_price": 24.50},
    {"category": "Home", "product_count": 5, "avg_price": 67.25}
  ]
}
```

---

## 15. NoSQL: MongoDB Queries

The QueryBuilder can generate MongoDB-compatible query documents with `to_mongo`. This returns a hash containing the filter, projection, sort, limit, and skip -- ready to pass to the Mongo Ruby driver.

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

```ruby
query = Tina4::QueryBuilder.from("users")
  .select("name", "email")
  .where("age > ?", [25])
  .where("status = ?", ["active"])
  .order_by("name ASC")
  .limit(10)
  .offset(5)

mongo = query.to_mongo
```

The returned hash:

```ruby
{
  filter: { "age" => { "$gt" => 25 }, "status" => "active" },
  projection: { "name" => 1, "email" => 1 },
  sort: { "name" => 1 },
  limit: 10,
  skip: 5,
}
```

Pass it directly to the Mongo Ruby driver:

```ruby
collection = client[:users]
cursor = collection.find(mongo[:filter])
  .projection(mongo[:projection])
  .sort(mongo[:sort])
  .limit(mongo[:limit])
  .skip(mongo[:skip])
```

---

## 16. Gotchas

### 1. Default Limit of 100

**Problem:** You expect all rows but only get 100.

**Cause:** When you call `.get` without calling `.limit`, the QueryBuilder defaults to `limit: 100, offset: 0`. This is a safety net to prevent accidental full-table dumps.

**Fix:** Call `.limit` explicitly if you need more rows: `.limit(500)`. For truly unbounded queries, use raw SQL via `db.fetch`.

### 2. Parameter Order Matters

**Problem:** Your query returns wrong results or the database throws a type error.

**Cause:** The `?` placeholders are positional. Parameters from `.where`, `.or_where`, and `.having` are collected in the order you chain them. If you reorder your calls, the parameter positions change.

**Fix:** Keep your chained calls in a consistent order. Use `.to_sql` to verify the generated SQL matches your parameter array.

### 3. No Database Connection

**Problem:** You get `QueryBuilder: No database connection provided.`

**Cause:** You did not pass `db:` to `.from`, and `Tina4.database` is not configured.

**Fix:** Either pass the connection explicitly with `Tina4::QueryBuilder.from("users", db: db)` or ensure your `.env` has a valid `DATABASE_URL` so the framework configures `Tina4.database` at startup.

### 4. count Replaces Your Columns

**Problem:** You call `.count` after setting `.select("name", "price")` and get confused about what SQL runs.

**Cause:** `.count` temporarily replaces your columns with `COUNT(*) AS cnt`, executes the query, then restores your original columns. This is transparent -- your QueryBuilder object is unchanged after the call.

**Fix:** No action needed. This is by design. If you need both the count and the rows, call `.count` first and then `.get`. The QueryBuilder is reusable.

### 5. to_sql Does Not Show Parameter Values

**Problem:** You call `.to_sql` and see `?` placeholders instead of actual values.

**Cause:** `.to_sql` returns the SQL template. The parameter values are bound separately by the database driver at execution time. This is correct behaviour -- it is how parameterised queries work.

**Fix:** To debug parameter values, inspect the arrays you pass to `.where` and `.having`. The parameters are applied in order, left to right, matching the `?` placeholders in the SQL output.

### 6. or_where as First Condition

**Problem:** Your SQL starts with `WHERE OR condition` and the database rejects it.

**Cause:** You used `.or_where` as the first filter. The QueryBuilder prepends OR to every `.or_where` condition except when it is the first condition in the list -- in that case, the connector is dropped. However, the intent is unclear. Starting a WHERE clause with OR is semantically wrong.

**Fix:** Always start with `.where` for the first condition. Use `.or_where` only for subsequent conditions that need OR logic.
