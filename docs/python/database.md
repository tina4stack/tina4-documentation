# Tina4-Python – Database Class {#connections}

::: tip 🔥 Hot Tips
- Instantiate `dba` in the `./src/__init__.py`,  include with `from . import dba`
- `dba` is the recognized global for database handling, but you can use any naming.
- Always call `commit()` after `insert/update/delete` unless in a transaction.
- Most methods return a `DatabaseResult` object which you can transform.   
:::

## Connection

```python
from tina4_python.Database import Database

# SQLite (file)
dba = Database("sqlite3:test.db")

# SQLite (in-memory – perfect for tests)
dba = Database("sqlite3::memory:")

# PostgreSQL
dba = Database("psycopg2:localhost/5432:mydb", "postgres", "password")

# MySQL / MariaDB
dba = Database("mysql.connector:localhost/3306:mydb", "root", "secret")

# MSSQL
dba = Database("pymssql:localhost/1433:mydb", "sa", "Password123")

# Firebird
dba = Database("firebird.driver:localhost/3050:/path/db.fdb", "sysdba", "masterkey")
```

## Core Methods {#core-methods}

| Method                               | Description                                          | Returns                     |
|--------------------------------------|------------------------------------------------------|-----------------------------|
| `execute(sql, params=None)`          | Run any SQL (CREATE, DROP, INSERT, …)               | `Result`                    |
| `execute_many(sql, params_list)`     | Bulk insert/update                                   | `Result`                    |
| `insert(table, data)`                | Smart insert (auto-increment, returns IDs)           | `Result`                    |
| `update(table, data, primary_key="id")` | Update by PK                                      | `bool`                      |
| `delete(table, filter=None)`        | Delete by filter dict                                | `bool`                      |
| `fetch(sql, params=None, **options)` | SELECT with pagination & search                      | `Result`                    |
| `fetch_one(sql, params=None)`        | Return single row as dict                            | `dict` or `None`            |
| `table_exists(table_name)`           | Check if table exists                                | `bool`                      |
| `commit()`, `rollback()`, `start_transaction()` | Full transaction control                  | —                           |
| `close()`                            | Close connection                                     | —                           |

## Result Object

Every query returns a `Result` with these properties:

```python
result.records          # list[dict] or list[tuple]
result.count            # int
result.error            # None or error message
result.to_json()        # → JSON string
result.to_array()       # → list of records
result.to_paginate()    # → pagination dict with totals
result.to_crud(request) # → CRUD HTML interface
result.to_csv()         # → CSV string
```

## Examples {#usage}

```python
db = Database("sqlite3::memory:")

# Create table
db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")

# Insert
db.insert("users", {"name": "Alice", "age": 30})
db.insert("users", [{"name": "Bob", "age": 25}, {"name": "Eve", "age": 35}])

# Update
db.update("users", {"id": 1, "age": 31})

# Delete
db.delete("users", {"id": 2})

# Select
result = db.fetch("SELECT * FROM users")
print(result.records)           # → [{'id': 1, 'name': 'Alice', 'age': 31}, ...]
print(result.count)             # → 2

# With parameters
result = db.fetch("SELECT * FROM users WHERE age > ?", [30])
print(result.records[0]["name"])  # → Alice

# Pagination + search
result = db.fetch(
    "SELECT * FROM users",
    limit=10,
    skip=20,
    search_columns=["name"],
    search="ali"
)

db.close()
```

## Transactions {#transactions}

```python
db.start_transaction()
try:
    db.insert("users", {"name": "Risky"})
    db.commit()
except:
    db.rollback()   # automatically rolls back on exception
```

## One-liner Heaven (Tina4 style)

```python
Database("sqlite3:test.db").execute("INSERT INTO logs (msg) VALUES (?)", ["Hello Tina4"])
```

That’s it.  
No models. No config files. No nonsense.
