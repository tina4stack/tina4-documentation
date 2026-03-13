# Tina4 Ruby – Database Class {#connections}

::: tip 🔥 Hot Tips
- Set `DATABASE_URL` in `.env` and Tina4 auto-connects on startup
- `Tina4.database` gives you the global database instance
- Most methods return a `DatabaseResult` which you can transform
- Use `transaction { }` blocks for safe multi-statement operations
:::

## Connection

```ruby
require "tina4"

# SQLite (file)
db = Tina4::Database.new("sqlite3:data.db")

# SQLite (in-memory – perfect for tests)
db = Tina4::Database.new("sqlite3::memory:")

# PostgreSQL
db = Tina4::Database.new("postgres://user:pass@localhost:5432/mydb")

# MySQL / MariaDB
db = Tina4::Database.new("mysql://root:secret@localhost:3306/mydb")

# Microsoft SQL Server
db = Tina4::Database.new("mssql://sa:Password@localhost:1433/mydb")

# Firebird
db = Tina4::Database.new("firebird://sysdba:masterkey@localhost:3050/path/db.fdb")
```

### Required Gems

| Driver | Gem | Install |
|--------|-----|---------|
| SQLite | `sqlite3` | `gem install sqlite3` |
| PostgreSQL | `pg` | `gem install pg` |
| MySQL/MariaDB | `mysql2` | `gem install mysql2` |
| SQL Server | `tiny_tds` | `gem install tiny_tds` |
| Firebird | `fb` | `gem install fb` |

### Auto-Connection via `.env`

```env
DATABASE_URL=sqlite3:data.db
```

```ruby
# After Tina4.initialize!, use:
db = Tina4.database
```

## Core Methods {#core-methods}

| Method | Description | Returns |
|--------|-------------|---------|
| `execute(sql, params)` | Run any SQL (CREATE, DROP, INSERT, …) | — |
| `insert(table, data)` | Smart insert (returns last_id) | `{ success: true, last_id: N }` |
| `update(table, data, filter)` | Update by filter hash | `{ success: true }` |
| `delete(table, filter)` | Delete by filter hash | `{ success: true }` |
| `fetch(sql, params, limit:, skip:)` | SELECT with pagination | `DatabaseResult` |
| `fetch_one(sql, params)` | Return single row as hash | `Hash` or `nil` |
| `table_exists?(name)` | Check if table exists | `bool` |
| `tables` | List all tables | `Array` |
| `columns(table)` | Get column info | `Array` |
| `transaction { }` | Block-based transaction | — |
| `close` | Close connection | — |

## Result Object

Every `fetch` returns a `DatabaseResult` with these methods:

```ruby
result = db.fetch("SELECT * FROM users")

result.to_a          # → Array of hashes
result.count         # → Integer
result.first         # → First row hash
result.to_json       # → JSON string
result.to_csv        # → CSV string
result.columns       # → Column names
result.empty?        # → Boolean
```

## Examples {#usage}

```ruby
db = Tina4::Database.new("sqlite3::memory:")

# Create table
db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")

# Insert
db.insert("users", { name: "Alice", age: 30 })
db.insert("users", { name: "Bob", age: 25 })

# Update
db.update("users", { age: 31 }, { id: 1 })

# Delete
db.delete("users", { id: 2 })

# Select
result = db.fetch("SELECT * FROM users")
puts result.to_a     # → [{ id: 1, name: "Alice", age: 31 }]
puts result.count    # → 1

# With parameters
result = db.fetch("SELECT * FROM users WHERE age > ?", [30])
puts result.first[:name]  # → "Alice"

# Pagination
result = db.fetch("SELECT * FROM users", [], limit: 10, skip: 20)

db.close
```

## Transactions {#transactions}

```ruby
db.transaction do |tx|
  tx.insert("users", { name: "Risky" })
  tx.insert("users", { name: "Also Risky" })
  # Auto-commits on success, auto-rollbacks on exception
end
```

## One-liner Heaven (Tina4 style)

```ruby
Tina4::Database.new("sqlite3:data.db").execute("INSERT INTO logs (msg) VALUES (?)", ["Hello Tina4"])
```

That's it. No models. No config files. No nonsense.
