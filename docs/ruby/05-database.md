# Chapter 5: Database

## 1. From Arrays to Real Data

In Chapters 2 and 3, all your data lived in Ruby arrays. Server restart. Data gone. Fine for learning routing. Useless for production.

This chapter covers Tina4's database layer: raw queries, parameterised queries, transactions, schema inspection, helper methods, and migrations.

Tina4 speaks to five database engines: SQLite, PostgreSQL, MySQL, Microsoft SQL Server, and Firebird. The API is identical across all five. Switch databases by changing one line in `.env`.

---

## 2. Connecting to a Database

### The Default: SQLite

When you scaffold with `tina4 init`, Tina4 creates a SQLite database at `data/app.db`. The default `.env` contains:

```env
TINA4_DEBUG=true
```

No explicit `DATABASE_URL`? Tina4 defaults to `sqlite:///data/app.db`. The health check at `/health` shows `"database": "connected"` with zero configuration.

### Connection Strings for Other Databases

Set `DATABASE_URL` in `.env` to use a different engine:

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

### Separate Credentials

If you prefer to keep credentials out of the connection string (recommended for production), use separate environment variables:

```env
DATABASE_URL=postgres://localhost:5432/myapp
DATABASE_USERNAME=myuser
DATABASE_PASSWORD=secretpassword
```

Tina4 merges these with the connection string at startup. The credentials in the separate variables take precedence over any embedded in the URL.

### Programmatic Connection

You can also create a database connection directly in Ruby code:

```ruby
db = Tina4::Database.new("sqlite://app.db", username: nil, password: nil)
```

### Connection Pooling

For applications that handle many concurrent requests, enable connection pooling with the `pool` parameter:

```ruby
db = Tina4::Database.new("postgres://localhost/mydb", pool: 5)
```

The `pool` parameter controls how many database connections are maintained:

- `pool: 0` (the default) -- a single connection is used for all queries
- `pool: N` (where N > 0) -- N connections are created and rotated round-robin across queries

Pooled connections are thread-safe. Each query is dispatched to the next available connection in the pool. This eliminates contention when multiple route handlers query the database simultaneously.

### Verifying the Connection

After updating `.env`, restart the server and check:

```bash
curl http://localhost:7147/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 3,
  "version": "3.0.0",
  "framework": "tina4-ruby"
}
```

If the database is not reachable, you will see `"database": "disconnected"` with an error message.

---

## 3. Getting the Database Object

In your route handlers, access the database via the `Tina4::Database` class:

```ruby
Tina4::Router.get("/api/test-db") do |request, response|
  db = Tina4::Database.connection

  result = db.fetch("SELECT 1 + 1 AS answer")

  response.json(result)
end
```

```bash
curl http://localhost:7147/api/test-db
```

```json
{"answer": 2}
```

`Tina4::Database.connection` returns the active database connection. You call methods like `fetch`, `execute`, and `fetch_one` on this object.

---

## 4. Raw Queries

### fetch -- Get Multiple Rows

```ruby
db = Tina4::Database.connection

# Returns an array of hashes
products = db.fetch("SELECT * FROM products WHERE price > 50")
```

Each row is a hash with column names as keys:

```ruby
# products looks like:
[
  { "id" => 1, "name" => "Keyboard", "price" => 79.99 },
  { "id" => 4, "name" => "Standing Desk", "price" => 549.99 }
]
```

### DatabaseResult

`fetch` returns a `DatabaseResult` object. It behaves like an array but carries extra metadata about the query.

#### Properties

```ruby
result = db.fetch("SELECT * FROM users WHERE active = ?", [1])

result.records      # [{ "id" => 1, "name" => "Alice" }, { "id" => 2, "name" => "Bob" }]
result.columns      # ["id", "name", "email", "active"]
result.count        # total number of matching rows
result.limit        # query limit (if set)
result.offset       # query offset (if set)
```

#### Iteration

A `DatabaseResult` is enumerable. Use it directly in loops:

```ruby
result.each do |user|
  puts user["name"]
end
```

#### Index Access

Access rows by index like a regular array:

```ruby
first_user = result[0]
```

#### Countable

`length` works on the result:

```ruby
puts result.length  # number of records in this result set
```

#### Conversion Methods

```ruby
result.to_json       # JSON string of all records
result.to_csv        # CSV string with column headers
result.to_array      # plain array of hashes
result.to_paginate   # { "records" => [...], "count" => 42, "limit" => 10, "offset" => 0 }
```

`to_paginate` is designed for building paginated API responses. It bundles the records with the total count, limit, and offset in a single hash.

#### Schema Metadata with column_info

`column_info` returns detailed metadata about the columns in the result set. The data is lazy-loaded -- it only queries the database schema when you call the method for the first time:

```ruby
info = result.column_info
# [
#     { "name" => "id", "type" => "INTEGER", "size" => nil, "decimals" => nil, "nullable" => false, "primary_key" => true },
#     { "name" => "name", "type" => "TEXT", "size" => nil, "decimals" => nil, "nullable" => false, "primary_key" => false },
#     { "name" => "email", "type" => "TEXT", "size" => 255, "decimals" => nil, "nullable" => true, "primary_key" => false },
#     ...
# ]
```

Each column entry contains:

| Field | Description |
|-------|-------------|
| `name` | Column name |
| `type` | Database type (e.g. `INTEGER`, `TEXT`, `REAL`) |
| `size` | Maximum size (or `nil` if not applicable) |
| `decimals` | Decimal places (or `nil`) |
| `nullable` | Whether the column allows `NULL` |
| `primary_key` | Whether the column is part of the primary key |

This is useful for building dynamic forms, generating documentation, or validating data before insert.

### fetch_one -- Get a Single Row

```ruby
product = db.fetch_one("SELECT * FROM products WHERE id = 1")
# Returns: { "id" => 1, "name" => "Keyboard", "price" => 79.99 }
```

If no row matches, `fetch_one` returns `nil`.

### execute -- Run a Statement

For INSERT, UPDATE, DELETE, and DDL statements that do not return rows:

```ruby
db.execute("INSERT INTO products (name, price) VALUES ('Widget', 9.99)")
db.execute("UPDATE products SET price = 89.99 WHERE id = 1")
db.execute("DELETE FROM products WHERE id = 5")
db.execute("CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, message TEXT, created_at TEXT)")
```

### Full Example: A Simple Query Route

```ruby
Tina4::Router.get("/api/products") do |request, response|
  db = Tina4::Database.connection

  products = db.fetch("SELECT * FROM products ORDER BY name")

  response.json({
    products: products,
    count: products.length
  })
end
```

```bash
curl http://localhost:7147/api/products
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

Never concatenate user input into SQL strings. That road leads to SQL injection:

```ruby
# NEVER do this:
db.fetch("SELECT * FROM products WHERE name = '#{user_input}'")
```

Instead, use parameterised queries. Pass parameters as the second argument:

```ruby
db = Tina4::Database.connection

# Named parameters
product = db.fetch_one(
  "SELECT * FROM products WHERE id = :id",
  { id: 42 }
)

# Positional parameters
products = db.fetch(
  "SELECT * FROM products WHERE price BETWEEN ? AND ? ORDER BY price",
  [10.00, 100.00]
)
```

The database driver handles escaping. Your input is never part of the SQL string.

### A Safe Search Endpoint

```ruby
Tina4::Router.get("/api/products/search") do |request, response|
  db = Tina4::Database.connection

  q = request.query["q"] || ""
  max_price = (request.query["max_price"] || 99999).to_f

  if q.empty?
    return response.json({ error: "Query parameter 'q' is required" }, 400)
  end

  products = db.fetch(
    "SELECT * FROM products WHERE name LIKE :query AND price <= :max_price ORDER BY name",
    { query: "%#{q}%", max_price: max_price }
  )

  response.json({
    query: q,
    max_price: max_price,
    results: products,
    count: products.length
  })
end
```

```bash
curl "http://localhost:7147/api/products/search?q=key&max_price=100"
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

Multiple operations must succeed or fail together. Transactions enforce that contract:

```ruby
Tina4::Router.post("/api/orders") do |request, response|
  db = Tina4::Database.connection
  body = request.body

  begin
    db.start_transaction

    # Create the order
    db.execute(
      "INSERT INTO orders (customer_id, total, status) VALUES (:customer_id, :total, 'pending')",
      { customer_id: body["customer_id"], total: body["total"] }
    )

    # Get the new order ID
    order = db.fetch_one("SELECT last_insert_rowid() AS id")
    order_id = order["id"]

    # Create order items
    body["items"].each do |item|
      db.execute(
        "INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (:order_id, :product_id, :qty, :price)",
        {
          order_id: order_id,
          product_id: item["product_id"],
          qty: item["quantity"],
          price: item["price"]
        }
      )

      # Decrease stock
      db.execute(
        "UPDATE products SET stock = stock - :qty WHERE id = :product_id",
        { qty: item["quantity"], product_id: item["product_id"] }
      )
    end

    db.commit

    response.json({ order_id: order_id, status: "created" }, 201)
  rescue => e
    db.rollback
    response.json({ error: "Order failed: #{e.message}" }, 500)
  end
end
```

If any step fails, `rollback` undoes everything. The database never sits in a half-finished state.

**Critical:** You must call `commit` to save changes. Forget it, and the transaction rolls back when the connection closes.

---

## 7. Schema Inspection

Tina4 provides methods to inspect your database structure at runtime:

### get_tables

```ruby
db = Tina4::Database.connection
tables = db.get_tables
```

Returns an array of table names:

```ruby
["orders", "order_items", "products", "users"]
```

### get_columns

```ruby
columns = db.get_columns("products")
```

Returns an array of column definitions:

```ruby
[
  { "name" => "id", "type" => "INTEGER", "nullable" => false, "primary" => true },
  { "name" => "name", "type" => "TEXT", "nullable" => false, "primary" => false },
  { "name" => "price", "type" => "REAL", "nullable" => true, "primary" => false },
  { "name" => "in_stock", "type" => "INTEGER", "nullable" => true, "primary" => false }
]
```

### table_exists?

```ruby
if db.table_exists?("products")
  # Table exists, safe to query
end
```

### A Schema Info Endpoint

```ruby
Tina4::Router.get("/api/schema") do |request, response|
  db = Tina4::Database.connection
  tables = db.get_tables

  schema = {}
  tables.each do |table|
    schema[table] = db.get_columns(table)
  end

  response.json({ tables: schema })
end
```

---

## 8. Batch Operations with execute_many

Insert or update many rows efficiently:

```ruby
db = Tina4::Database.connection

products = [
  { name: "Widget A", price: 9.99 },
  { name: "Widget B", price: 14.99 },
  { name: "Widget C", price: 19.99 },
  { name: "Widget D", price: 24.99 }
]

db.execute_many(
  "INSERT INTO products (name, price) VALUES (:name, :price)",
  products
)
```

`execute_many` prepares the statement once and executes it for each item in the array. This is significantly faster than calling `execute` in a loop because the SQL only needs to be parsed once.

---

## 9. Helper Methods: insert, update, delete

Tina4 provides shorthand methods so you do not have to write SQL for simple operations.

### insert

```ruby
db = Tina4::Database.connection

# Insert a single row
db.insert("products", {
  name: "Wireless Mouse",
  price: 34.99,
  in_stock: 1
})

# Insert multiple rows
db.insert("products", [
  { name: "USB Cable", price: 9.99, in_stock: 1 },
  { name: "HDMI Cable", price: 14.99, in_stock: 1 },
  { name: "DisplayPort Cable", price: 19.99, in_stock: 0 }
])
```

### update

```ruby
# Update rows matching a filter
db.update("products", { price: 39.99, in_stock: 1 }, "id = :id", { id: 7 })
```

The third argument is the WHERE clause, and the fourth is the parameters for it.

### delete

```ruby
# Delete rows matching a filter
db.delete("products", "id = :id", { id: 7 })
```

These helpers generate SQL for you. Convenient for simple CRUD. Raw queries still own complex joins, subqueries, and aggregations.

---

## 10. Migrations

Migrations are versioned scripts that evolve your schema over time. No manual `CREATE TABLE` statements. Write migration files. Tina4 applies them in order.

Ruby's migration system is unique among Tina4 implementations: it supports both `.sql` and `.rb` migration files.

### File Naming

Two naming patterns are accepted:

| Pattern | Example |
|---------|---------|
| Sequential | `000001_create_products_table.sql` |
| Timestamp | `20260324120000_create_products_table.sql` |

Pick one pattern and stick with it. Do not mix sequential and timestamp naming in the same project.

### Generating a Migration

Use the CLI to scaffold migration files:

```bash
tina4 generate migration create_products_table
```

```
Created migration: migrations/20260324120000_create_products_table.sql
Created migration: migrations/20260324120000_create_products_table.down.sql
```

The generator creates both the up and down files. The timestamp prefix ensures migrations always run in chronological order.

### SQL Migrations

Edit the generated file `migrations/20260324120000_create_products_table.sql`:

```sql
-- migrations/20260324120000_create_products_table.sql
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

The down migration goes in the separate `.down.sql` file:

```sql
-- migrations/20260324120000_create_products_table.down.sql
DROP TABLE IF EXISTS products;
```

The `.down.sql` file is optional. If it does not exist, rollback for that migration is skipped.

The SQL parser supports `$$` delimited stored procedures and block comments, so you can include complex database objects in a single migration file.

### Ruby Class Migrations

As an alternative to SQL files, you can write migrations as Ruby classes. This is useful when you need conditional logic, loops, or data transformations during a migration:

```ruby
# migrations/20260324120000_create_products_table.rb
class CreateProductsTable < Tina4::MigrationBase
  def up
    execute "CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT NOT NULL, price REAL DEFAULT 0.00)"
  end

  def down
    execute "DROP TABLE IF EXISTS products"
  end
end
```

For `.rb` migrations, the `down` method handles rollback directly in the same file. No separate `.down.sql` file is needed.

### Running Migrations

```bash
tina4 migrate
```

```
Running migrations...
  [APPLIED] 20260324120000_create_products_table.sql
Migrations complete. 1 applied.
```

### Checking Migration Status

```bash
tina4ruby migrate:status
```

```
Migration                                    Status     Applied At
---------                                    ------     ----------
20260324120000_create_products_table.sql      applied    2026-03-24 12:00:00
20260324130000_create_orders_table.sql        pending    -
```

### Rolling Back

```bash
tina4ruby migrate:rollback
```

```
Rolling back last batch...
  [ROLLED BACK] 20260324130000_create_orders_table.sql
Rollback complete. 1 rolled back.
```

Rollback undoes the entire last batch of migrations. If you applied three migrations in one `tina4 migrate` run, all three are rolled back together. You can configure the number of steps if you need finer control.

For `.sql` migrations, rollback runs the corresponding `.down.sql` file. For `.rb` migrations, rollback calls the `down` method.

### A Real Migration Sequence

Here is what a typical project's migrations look like:

```
migrations/
├── 20260324120000_create_products_table.sql
├── 20260324120000_create_products_table.down.sql
├── 20260324121000_create_users_table.sql
├── 20260324121000_create_users_table.down.sql
├── 20260324122000_create_orders_table.rb
└── 20260325091500_add_email_index_to_users.sql
```

Notice the mix of `.sql` and `.rb` files. Both types can coexist in the same project. The `create_orders_table.rb` file contains both `up` and `down` methods, so it does not need a separate down file.

The last SQL migration might look like:

```sql
-- migrations/20260325091500_add_email_index_to_users.sql
CREATE INDEX idx_users_email ON users (email);
```

With its down file:

```sql
-- migrations/20260325091500_add_email_index_to_users.down.sql
DROP INDEX IF EXISTS idx_users_email;
```

### Migration Tracking

Migrations run in filename order. Each migration runs once. Tina4 tracks applied migrations in a `tina4_migration` table with the following columns:

| Column | Description |
|--------|-------------|
| `id` | Auto-increment primary key |
| `migration_name` | The filename of the migration |
| `batch` | The batch number (all migrations applied in one run share a batch) |
| `executed_at` | Timestamp of when the migration was applied |

The batch system is what makes rollback work: `migrate:rollback` undoes all migrations in the highest batch number.

---

## 11. Query Caching

For read-heavy applications, enable query caching:

```env
TINA4_DB_CACHE=true
```

When enabled, Tina4 caches the results of `fetch` and `fetch_one` calls. Identical queries with identical parameters return cached results instead of hitting the database again.

The cache is automatically invalidated when you call `execute`, `insert`, `update`, or `delete` on the same table.

You can also control caching per-query:

```ruby
# Force a fresh query (bypass cache)
products = db.fetch("SELECT * FROM products", [], false) # third arg = use cache

# Clear the entire cache
db.clear_cache
```

---

## 12. Exercise: Build a Notes App

Build a notes application backed by SQLite. Create the database table via a migration and build a full CRUD API.

### Requirements

1. Create a migration that creates a `notes` table with columns:
   - `id` -- integer, primary key, auto-increment
   - `title` -- text, not null
   - `content` -- text, not null
   - `tag` -- text, default "general"
   - `created_at` -- text, default current timestamp
   - `updated_at` -- text, default current timestamp

2. Build these API endpoints:

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
curl -X POST http://localhost:7147/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "Shopping List", "content": "Milk, eggs, bread", "tag": "personal"}'

# List all
curl http://localhost:7147/api/notes

# Search
curl "http://localhost:7147/api/notes?search=shopping"

# Filter by tag
curl "http://localhost:7147/api/notes?tag=personal"

# Get one
curl http://localhost:7147/api/notes/1

# Update
curl -X PUT http://localhost:7147/api/notes/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Shopping List", "content": "Milk, eggs, bread, butter"}'

# Delete
curl -X DELETE http://localhost:7147/api/notes/1
```

---

## 13. Solution

### Migration

Generate the migration:

```bash
tina4 generate migration create_notes_table
```

Edit `migrations/20260324120000_create_notes_table.sql`:

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

Edit `migrations/20260324120000_create_notes_table.down.sql`:

```sql
DROP TABLE IF EXISTS notes;
```

Run the migration:

```bash
tina4 migrate
```

```
Running migrations...
  [APPLIED] 20260322143000_create_notes_table.sql
Migrations complete. 1 applied.
```

### Routes

Create `src/routes/notes.rb`:

```ruby
# List all notes with optional filters
Tina4::Router.get("/api/notes") do |request, response|
  db = Tina4::Database.connection

  tag = request.query["tag"] || ""
  search = request.query["search"] || ""

  sql = "SELECT * FROM notes"
  params = {}
  conditions = []

  unless tag.empty?
    conditions << "tag = :tag"
    params[:tag] = tag
  end

  unless search.empty?
    conditions << "(title LIKE :search OR content LIKE :search)"
    params[:search] = "%#{search}%"
  end

  sql += " WHERE #{conditions.join(' AND ')}" unless conditions.empty?
  sql += " ORDER BY updated_at DESC"

  notes = db.fetch(sql, params)

  response.json({
    notes: notes,
    count: notes.length
  })
end

# Get a single note
Tina4::Router.get("/api/notes/{id:int}") do |request, response|
  db = Tina4::Database.connection
  id = request.params["id"]

  note = db.fetch_one("SELECT * FROM notes WHERE id = :id", { id: id })

  if note.nil?
    response.json({ error: "Note not found", id: id }, 404)
  else
    response.json(note)
  end
end

# Create a note
Tina4::Router.post("/api/notes") do |request, response|
  db = Tina4::Database.connection
  body = request.body

  # Validate
  errors = []
  errors << "Title is required" if body["title"].nil? || body["title"].empty?
  errors << "Content is required" if body["content"].nil? || body["content"].empty?

  unless errors.empty?
    return response.json({ errors: errors }, 400)
  end

  db.execute(
    "INSERT INTO notes (title, content, tag) VALUES (:title, :content, :tag)",
    {
      title: body["title"],
      content: body["content"],
      tag: body["tag"] || "general"
    }
  )

  note = db.fetch_one("SELECT * FROM notes WHERE id = last_insert_rowid()")

  response.json(note, 201)
end

# Update a note
Tina4::Router.put("/api/notes/{id:int}") do |request, response|
  db = Tina4::Database.connection
  id = request.params["id"]
  body = request.body

  existing = db.fetch_one("SELECT * FROM notes WHERE id = :id", { id: id })

  if existing.nil?
    return response.json({ error: "Note not found", id: id }, 404)
  end

  db.execute(
    "UPDATE notes SET title = :title, content = :content, tag = :tag, updated_at = CURRENT_TIMESTAMP WHERE id = :id",
    {
      title: body["title"] || existing["title"],
      content: body["content"] || existing["content"],
      tag: body["tag"] || existing["tag"],
      id: id
    }
  )

  note = db.fetch_one("SELECT * FROM notes WHERE id = :id", { id: id })

  response.json(note)
end

# Delete a note
Tina4::Router.delete("/api/notes/{id:int}") do |request, response|
  db = Tina4::Database.connection
  id = request.params["id"]

  existing = db.fetch_one("SELECT * FROM notes WHERE id = :id", { id: id })

  if existing.nil?
    return response.json({ error: "Note not found", id: id }, 404)
  end

  db.execute("DELETE FROM notes WHERE id = :id", { id: id })

  response.json(nil, 204)
end
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

### 1. Forgetting commit

**Problem:** You call `start_transaction`, run your queries, but the changes disappear on the next request.

**Cause:** Without `commit`, the transaction is rolled back when the connection closes.

**Fix:** Always call `db.commit` after your transaction succeeds. Use a `begin/rescue` block with `db.rollback` in the rescue.

### 2. Connection String Formats

**Problem:** The database will not connect and you see a cryptic error about the connection string.

**Cause:** Each database engine expects a specific URL format. A common mistake is using `mysql://user:pass@host/db` when the engine expects the port.

**Fix:** Always include the port: `mysql://localhost:3306/mydb`. Here are the default ports:

| Engine | Default Port |
|--------|-------------|
| PostgreSQL | 5432 |
| MySQL | 3306 |
| MSSQL | 1433 |
| Firebird | 3050 |
| SQLite | (file path, no port) |

### 3. SQLite File Paths

**Problem:** SQLite creates a new empty database instead of using the existing one.

**Cause:** The path in `DATABASE_URL` is relative and resolves to the wrong directory, or you used `sqlite://` (two slashes) instead of `sqlite:///` (three slashes).

**Fix:** Use three slashes for a relative path: `sqlite:///data/app.db`. For an absolute path, use four slashes: `sqlite:////var/data/app.db`. The third slash separates the scheme from the path; the fourth starts the absolute path.

### 4. Parameterised Queries with LIKE

**Problem:** `WHERE name LIKE :q` with `{ q: "%search%" }` works, but `WHERE name LIKE '%:q%'` does not.

**Cause:** Parameters inside quotes are treated as literal text, not as placeholders.

**Fix:** Include the `%` wildcards in the parameter value, not in the SQL: `{ q: "%#{search}%" }`. The SQL should be `WHERE name LIKE :q`.

### 5. Boolean Values in SQLite

**Problem:** You insert `true` or `false` but the database stores `1` or `0`. When you read it back, you get integers, not booleans.

**Cause:** SQLite does not have a native boolean type. It stores booleans as integers.

**Fix:** Cast in your Ruby code: `row["in_stock"] == 1` or use `!!row["in_stock"]` to convert to a boolean. Ruby treats `0` as truthy (unlike some other languages), so be explicit with comparisons.

### 6. Migration Already Applied

**Problem:** You edited a migration file and ran `tina4 migrate` again, but nothing changed.

**Cause:** Tina4 tracks applied migrations by filename in the `tina4_migration` table. Once applied, a migration will not run again even if you change its contents.

**Fix:** Create a new migration for schema changes. Do not edit applied migrations. If you are in early development and want to start fresh, use `tina4ruby migrate:rollback` to undo the last batch and then `tina4 migrate` to reapply. Use `tina4ruby migrate:status` to see which migrations are applied and which are pending.

### 7. fetch Returns Empty Array, Not Nil

**Problem:** You check `if result.nil?` but it never matches, even when the table is empty.

**Cause:** `fetch` always returns an array. An empty result is `[]`, not `nil`. Only `fetch_one` returns `nil` when no row matches.

**Fix:** Check with `if result.empty?` or `if result.length == 0`.
