# Chapter 5: Database

## 1. From Lists to Real Data

Every example so far stored data in Python lists. Restart the server. Data gone. A real application demands persistence.

Tina4 Python makes database access straightforward. Set a `DATABASE_URL` in your `.env`. Create a `Database()` connection. Run SQL. No ORM required (Chapter 6 adds that). The SQL you already know carries over unchanged.

Picture a notes application. Users create, edit, and delete notes. Those notes must survive restarts, support searching, and handle concurrent users. A database delivers all three.

---

## 2. Configuration

### DATABASE_URL

Set your database connection in `.env`:

```bash
DATABASE_URL=sqlite:///data/app.db
```

That is the default -- a SQLite database stored in `data/`. SQLite ships with Python. No install required.

Tina4 supports six database engines:

| Engine | DATABASE_URL Format | Package Required |
|--------|-------------------|-----------------|
| SQLite | `sqlite:///data/app.db` | None (stdlib) |
| PostgreSQL | `postgresql://user:pass@host:5432/dbname` | `psycopg2` |
| MySQL | `mysql://user:pass@host:3306/dbname` | `mysql-connector-python` |
| MSSQL | `mssql://user:pass@host:1433/dbname` | `pymssql` |
| Firebird | `firebird://user:pass@host:3050/path/to/db.fdb` | `firebird-driver` |
| ODBC | `odbc://DSN_NAME` | `pyodbc` |

Switch databases by changing the URL. Your Python code stays the same. All drivers implement the same adapter interface.

### Installing Database Drivers

SQLite requires nothing. For other databases, install the driver with uv:

```bash
# PostgreSQL
uv add psycopg2-binary

# MySQL
uv add mysql-connector-python

# MSSQL
uv add pymssql

# Firebird
uv add firebird-driver

# ODBC
uv add pyodbc
```

---

## 3. Creating a Connection

```python
from tina4_python.database.connection import Database

db = Database()
```

One line. `Database()` reads `DATABASE_URL` from your `.env` and connects. If the SQLite file does not exist, the adapter creates one.

You can also pass a URL directly:

```python
db = Database("sqlite:///data/test.db")
```

### Connection Pooling

Applications that handle many concurrent requests benefit from connection pooling. Pass a `pool` argument:

```python
db = Database("postgres://localhost/mydb", pool=5)  # 5 connections, round-robin
```

The `pool` parameter controls how many database connections the pool maintains:

- `pool=0` (the default) -- a single connection serves all queries
- `pool=N` (where N > 0) -- N connections rotate round-robin across queries

Pooled connections are thread-safe. Each query dispatches to the next available connection. This eliminates contention when multiple route handlers query the database at the same time.

### Extra Driver Options via **kwargs

Any additional keyword arguments pass through to the underlying driver's `connect()` call. This suits engine-specific options:

```python
db = Database("firebird://localhost:3050//data/legacy.fdb", charset="ISO8859_1")
```

### Firebird Dual-Driver Support

The Firebird adapter tries `firebird-driver` (the modern package) first and falls back to the legacy `fdb` package if `firebird-driver` is missing. Install whichever is available -- the adapter handles the difference internally.

### Lowercase Column Names

Firebird returns column names in uppercase by default. Tina4 normalises them to lowercase, so `result["first_name"]` works regardless of how the column was defined in the schema.

### Firebird Migration Support

As of 3.10.8, the migration runner handles Firebird correctly. It uses a generator (sequence) for auto-increment IDs instead of `AUTOINCREMENT`, and emits `VARCHAR(4096)` instead of `TEXT` (which Firebird does not support as a column type). No changes to existing migrations are needed -- the runner detects the engine on its own.

---

## 4. Running Queries

### fetch -- Get Multiple Rows

```python
from tina4_python.core.router import get
from tina4_python.database.connection import Database

@get("/api/notes")
async def list_notes(request, response):
    db = Database()
    notes = db.fetch("SELECT id, title, content, created_at FROM notes ORDER BY created_at DESC")

    return response.json({"notes": notes, "count": len(notes)})
```

`fetch()` returns a `DatabaseResult` containing a list of dictionaries. Each dictionary represents one row:

```json
{
  "notes": [
    {"id": 1, "title": "Shopping List", "content": "Milk, eggs, bread", "created_at": "2026-03-22 14:30:00"},
    {"id": 2, "title": "Meeting Notes", "content": "Discuss Q2 roadmap", "created_at": "2026-03-22 10:00:00"}
  ],
  "count": 2
}
```

### DatabaseResult

`fetch()` returns a `DatabaseResult` object. It behaves like a list but carries extra metadata about the query.

#### Properties

```python
result = db.fetch("SELECT * FROM users WHERE active = ?", [1])

result.records      # [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]
result.columns      # ["id", "name", "email", "active"]
result.count        # total number of matching rows
result.limit        # query limit (if set)
result.offset       # query offset (if set)
```

#### Iteration

A `DatabaseResult` is iterable. Use it directly in a `for` loop:

```python
for user in result:
    print(user["name"])
```

#### Index Access

Access rows by index:

```python
first_user = result[0]
```

#### Countable

`len()` works on the result:

```python
print(len(result))  # number of records in this result set
```

#### Conversion Methods

```python
result.to_list()              # plain list of dictionaries (same as result.records)
result.to_paginate()          # {"data": [...], "total": 42, "page": 1, "per_page": 20, ...}
result.to_paginate(page=2, per_page=10)  # custom page and page size
```

`to_list()` returns the records as a plain list. `to_paginate(page=1, per_page=20)` bundles the records with total count, page, per_page, total_pages, has_next, and has_prev in a single dictionary. It is built for paginated API responses.

#### Schema Metadata with column_info()

`column_info()` returns detailed metadata about the columns in the result set. The data loads lazily -- it queries the database schema only when you call the method for the first time:

```python
info = result.column_info()
# [
#     {"name": "id", "type": "INTEGER", "size": None, "decimals": None, "nullable": False, "primary_key": True},
#     {"name": "name", "type": "TEXT", "size": None, "decimals": None, "nullable": False, "primary_key": False},
#     {"name": "email", "type": "TEXT", "size": 255, "decimals": None, "nullable": True, "primary_key": False},
#     ...
# ]
```

Each column entry contains:

| Field | Description |
|-------|-------------|
| `name` | Column name |
| `type` | Database type (e.g. `INTEGER`, `TEXT`, `REAL`) |
| `size` | Maximum size (or `None` if not applicable) |
| `decimals` | Decimal places (or `None`) |
| `nullable` | Whether the column allows `NULL` |
| `primary_key` | Whether the column is part of the primary key |

This powers dynamic forms, documentation generation, and data validation before insert.

### fetch_one -- Get a Single Row

```python
@get("/api/notes/{id:int}")
async def get_note(id, request, response):
    db = Database()
    note = db.fetch_one(
        "SELECT id, title, content, created_at FROM notes WHERE id = ?",
        [id]
    )

    if note is None:
        return response.json({"error": "Note not found"}, 404)

    return response.json(note)
```

`fetch_one()` returns a single dictionary or `None` if no row matches.

### execute -- Insert, Update, Delete

```python
from tina4_python.core.router import post, put, delete
from tina4_python.database.connection import Database

@post("/api/notes")
async def create_note(request, response):
    db = Database()
    body = request.body

    if not body.get("title"):
        return response.json({"error": "Title is required"}, 400)

    result = db.execute(
        "INSERT INTO notes (title, content) VALUES (?, ?)",
        [body["title"], body.get("content", "")]
    )

    note = db.fetch_one("SELECT * FROM notes WHERE id = ?", [result.last_id])

    return response.json({"message": "Note created", "note": note}, 201)
```

`execute()` runs an INSERT, UPDATE, or DELETE statement and returns a `DatabaseResult` with `affected_rows` and `last_id` properties.

---

## 5. Parameterised Queries

Never concatenate user input into SQL strings. Parameterised queries stand between you and SQL injection:

```python
# WRONG -- SQL injection vulnerability
db.fetch(f"SELECT * FROM notes WHERE title = '{user_input}'")

# CORRECT -- parameterised query
db.fetch("SELECT * FROM notes WHERE title = ?", [user_input])
```

Positional parameters use the `?` placeholder. Pass a list of values as the second argument:

```python
db.fetch(
    "SELECT * FROM notes WHERE category = ? AND created_at > ?",
    ["work", "2026-03-01"]
)
```

Tina4 handles parameter escaping and type conversion for all database engines.

---

## 6. Transactions

Multiple operations must succeed or fail together. Transactions enforce that contract:

```python
@post("/api/transfer")
async def transfer_funds(request, response):
    db = Database()
    body = request.body

    from_account = body["from_account"]
    to_account = body["to_account"]
    amount = float(body["amount"])

    db.start_transaction()

    try:
        # Deduct from sender
        db.execute(
            "UPDATE accounts SET balance = balance - ? WHERE id = ? AND balance >= ?",
            [amount, from_account, amount]
        )

        # Check if deduction succeeded
        sender = db.fetch_one(
            "SELECT balance FROM accounts WHERE id = ?",
            [from_account]
        )

        if sender is None:
            db.rollback()
            return response.json({"error": "Insufficient funds or account not found"}, 400)

        # Credit receiver
        db.execute(
            "UPDATE accounts SET balance = balance + ? WHERE id = ?",
            [amount, to_account]
        )

        db.commit()

        return response.json({"message": f"Transferred {amount} successfully"})

    except Exception as e:
        db.rollback()
        return response.json({"error": str(e)}, 500)
```

The three transaction methods:

- `db.start_transaction()` -- begin a transaction
- `db.commit()` -- save all changes since the transaction started
- `db.rollback()` -- undo all changes since the transaction started

Without transactions, each `execute()` call auto-commits on its own.

---

## 7. Batch Operations with execute_many

Inserting or updating many rows at once calls for `execute_many()`. It batches operations for speed:

```python
@post("/api/notes/import")
async def import_notes(request, response):
    db = Database()
    notes = request.body.get("notes", [])

    if not notes:
        return response.json({"error": "No notes provided"}, 400)

    params_list = [
        [note["title"], note.get("content", "")]
        for note in notes
    ]

    db.execute_many(
        "INSERT INTO notes (title, content) VALUES (?, ?)",
        params_list
    )

    return response.json({"message": f"Imported {len(notes)} notes"}, 201)
```

```bash
curl -X POST http://localhost:7145/api/notes/import \
  -H "Content-Type: application/json" \
  -d '{"notes": [{"title": "Note 1", "content": "First"}, {"title": "Note 2", "content": "Second"}, {"title": "Note 3", "content": "Third"}]}'
```

```json
{"message":"Imported 3 notes"}
```

`execute_many()` runs far faster than `execute()` in a loop. One round trip instead of many.

---

## 8. Insert, Update, and Delete Helpers

Tina4 provides shorthand methods that cut the boilerplate:

### insert

```python
result = db.insert("notes", {
    "title": "Quick Note",
    "content": "Created with insert helper"
})
# result.last_id contains the new row's ID
```

Returns a `DatabaseResult`. Access `result.last_id` for the inserted row's ID.

### update

```python
result = db.update("notes", {"title": "Updated Title", "content": "New content"}, "id = ?", [1])
```

The third argument is the WHERE clause, the fourth is a list of parameter values. Returns a `DatabaseResult` with `affected_rows`.

### delete

```python
result = db.delete("notes", "id = ?", [1])
```

Returns a `DatabaseResult` with `affected_rows`.

These helpers eliminate boilerplate INSERT/UPDATE/DELETE SQL. For complex queries, `execute()` is always available.

---

## 9. Schema Inspection

Tina4 exposes methods to inspect your database structure at runtime. The `Database` object delegates to the underlying adapter, so these work across all six engines.

### get_tables()

```python
db = Database()
tables = db.get_tables()
```

Returns a list of table names:

```python
["notes", "users", "tina4_migration"]
```

### get_columns()

```python
columns = db.get_columns("notes")
```

Returns column definitions as a list of dictionaries:

```python
[
    {"name": "id", "type": "INTEGER", "nullable": False, "default": None, "primary_key": True},
    {"name": "title", "type": "TEXT", "nullable": False, "default": None, "primary_key": False},
    {"name": "content", "type": "TEXT", "nullable": True, "default": "''", "primary_key": False},
    {"name": "created_at", "type": "TEXT", "nullable": True, "default": "CURRENT_TIMESTAMP", "primary_key": False}
]
```

Each entry includes the column name, data type, whether it accepts NULL, its default value, and whether it belongs to the primary key.

### table_exists()

```python
if db.table_exists("notes"):
    # Table exists, safe to query
    notes = db.fetch("SELECT * FROM notes")
```

Returns `True` if the table exists, `False` otherwise.

### get_database_type()

```python
engine = db.get_database_type()
# "sqlite", "postgresql", "mysql", "mssql", or "firebird"
```

Returns a lowercase string identifying the active database engine. This is useful when you need engine-specific SQL in a multi-database setup.

### A Schema Info Endpoint

Combine these methods to build a schema browser:

```python
from tina4_python.core.router import get
from tina4_python.database.connection import Database

@get("/api/schema")
async def schema_info(request, response):
    db = Database()
    tables = db.get_tables()

    schema = {}
    for table in tables:
        schema[table] = db.get_columns(table)

    return response.json({"tables": schema})
```

```json
{
  "tables": {
    "notes": [
      {"name": "id", "type": "INTEGER", "nullable": false, "default": null, "primary_key": true},
      {"name": "title", "type": "TEXT", "nullable": false, "default": null, "primary_key": false}
    ],
    "users": [
      {"name": "id", "type": "INTEGER", "nullable": false, "default": null, "primary_key": true},
      {"name": "email", "type": "TEXT", "nullable": false, "default": null, "primary_key": false}
    ]
  }
}
```

Schema inspection powers admin dashboards, migration generators, and dynamic form builders. The database tells you its own structure -- no guesswork required.

---

## 10. Migrations

Migrations are SQL files that version your database schema. Write them once. Apply them in order. Roll them back when needed.

### File Naming

Migration files live in a `migrations/` directory. Two naming patterns are supported:

| Pattern | Example |
|---------|---------|
| Sequential | `000001_create_users.sql` |
| Timestamp | `20260322160000_create_notes.sql` |

Files sort alphabetically when they run. Pick one pattern and stick with it -- `000001_` sorts before `20260322_`, so mixing them leads to unexpected execution order.

### Generating a Migration

```bash
tina4 generate migration create_notes_table
```

This creates two files:

```
migrations/000001_create_notes_table.sql
migrations/000001_create_notes_table.down.sql
```

The first is your "up" migration. The second is the matching "down" migration for rollbacks.

### Writing the Up Migration

Open the generated `.sql` file and add your schema changes:

```sql
-- migrations/000001_create_notes_table.sql
CREATE TABLE notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT DEFAULT '',
    category TEXT DEFAULT 'general',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notes_category ON notes (category);
CREATE INDEX idx_notes_created_at ON notes (created_at);
```

### Writing the Down Migration

The `.down.sql` file undoes whatever the up migration did:

```sql
-- migrations/000001_create_notes_table.down.sql
DROP INDEX IF EXISTS idx_notes_created_at;
DROP INDEX IF EXISTS idx_notes_category;
DROP TABLE IF EXISTS notes;
```

Down migrations are optional. Everything works without them -- until you try to roll back. At that point Tina4 fails with a clear error about the missing file.

The `.down.sql` file must share the exact same base name as the up file. If your up file is `000001_create_notes_table.sql`, the down file must be `000001_create_notes_table.down.sql`.

### Running Migrations

```bash
tina4 migrate
# or
tina4python migrate
```

Tina4 finds all pending `.sql` files in `migrations/`, sorts them alphabetically, and executes them in order. Each run receives a **batch number**. The batch groups every migration applied in that single run.

### Checking Status

```bash
tina4python migrate:status
```

This shows which migrations have been applied and which are still pending. Run it before deploying to see what will execute.

### Rolling Back

```bash
tina4python migrate:rollback
```

Rollback undoes the **entire last batch**. If your last `tina4 migrate` run applied three migration files, rollback reverts all three by running their `.down.sql` counterparts in reverse order.

### Tracking Table

Tina4 creates a `tina4_migration` table in your database to track what has run:

| Column | Purpose |
|--------|---------|
| `id` | Primary key |
| `migration_id` | The migration filename |
| `description` | Human-readable description |
| `batch` | Which batch this migration belonged to |
| `executed_at` | When it ran |
| `passed` | `1` if it succeeded, `0` if it failed |

Failed migrations are recorded with `passed = 0`. On the next `tina4 migrate` run, the runner retries them.

### Advanced SQL Splitting

Tina4's migration runner is not a naive line splitter. It correctly handles:

- **`$$` delimited blocks** -- PostgreSQL stored procedures and functions that contain semicolons
- **`//` blocks** -- alternative delimiter blocks
- **`/* */` block comments** -- skipped during splitting
- **`--` line comments** -- skipped during splitting

Write PostgreSQL stored procedures in your migration files without worrying about the runner choking on internal semicolons.

### Migration Best Practices

1. **One migration per change** -- do not pile multiple table changes into one file
2. **Always write a down migration** -- so you can roll back cleanly
3. **Never edit a migration that has been applied** -- create a new migration instead
4. **Use descriptive names** -- `create_users_table`, `add_email_to_orders`, `create_category_index`
5. **Pick one naming pattern** -- use either `000001_` or `YYYYMMDDHHMMSS_`, not both

---

## 11. Query Caching

Expensive queries that return the same result on every call deserve caching. Tina4 builds caching in. Enable it via environment variables in your `.env`:

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=30
```

When caching is active, all `fetch()` and `fetch_one()` calls cache their results. The `TINA4_DB_CACHE_TTL` value (in seconds) controls how long results stay cached. Write operations (`execute()`, `insert()`, `update()`, `delete()`) invalidate the entire cache.

To clear the cache manually (for example, after external data changes):

```python
@post("/api/notes")
async def create_note(request, response):
    db = Database()
    result = db.execute(
        "INSERT INTO notes (title, content, category) VALUES (?, ?, ?)",
        [request.body["title"], request.body.get("content", ""), request.body.get("category", "general")]
    )

    # Cache is auto-invalidated on writes, but you can also clear manually:
    db.cache_clear()

    note = db.fetch_one("SELECT * FROM notes WHERE id = ?", [result.last_id])
    return response.json({"note": note}, 201)
```

Check cache performance with `db.cache_stats()`. It returns hits, misses, size, and TTL.

---

## 12. Exercise: Build a Notes App API

Build a complete notes application API with database persistence.

### Requirements

1. Create a migration for a `notes` table with: `id`, `title` (required), `content`, `category` (default "general"), `pinned` (boolean, default false), `created_at`, `updated_at`

2. Build these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all notes. Support `?category=` and `?pinned=true` filters. |
| `GET` | `/api/notes/{id:int}` | Get a single note. 404 if not found. |
| `POST` | `/api/notes` | Create a note. Title required. Return 201. |
| `PUT` | `/api/notes/{id:int}` | Update a note. Return 404 if not found. |
| `DELETE` | `/api/notes/{id:int}` | Delete a note. Return 204. |
| `GET` | `/api/notes/categories` | List all distinct categories with counts. |

### Test with:

```bash
# Create notes
curl -X POST http://localhost:7145/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "Shopping List", "content": "Milk, eggs, bread", "category": "personal"}'

curl -X POST http://localhost:7145/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "Sprint Planning", "content": "Review backlog, assign tasks", "category": "work", "pinned": true}'

# List all
curl http://localhost:7145/api/notes

# Filter by category
curl "http://localhost:7145/api/notes?category=work"

# Filter by pinned
curl "http://localhost:7145/api/notes?pinned=true"

# Get categories
curl http://localhost:7145/api/notes/categories

# Update
curl -X PUT http://localhost:7145/api/notes/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated Shopping List", "content": "Milk, eggs, bread, butter"}'

# Delete
curl -X DELETE http://localhost:7145/api/notes/2
```

---

## 13. Solution

### Migration

Generate the migration:

```bash
tina4 generate migration create_notes_table
```

Edit `migrations/000001_create_notes_table.sql`:

```sql
CREATE TABLE notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT DEFAULT '',
    category TEXT NOT NULL DEFAULT 'general',
    pinned INTEGER NOT NULL DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notes_category ON notes (category);
CREATE INDEX idx_notes_pinned ON notes (pinned);
```

Edit `migrations/000001_create_notes_table.down.sql`:

```sql
DROP INDEX IF EXISTS idx_notes_pinned;
DROP INDEX IF EXISTS idx_notes_category;
DROP TABLE IF EXISTS notes;
```

Run the migration:

```bash
tina4 migrate
```

### Routes

Create `src/routes/notes.py`:

```python
from tina4_python.core.router import get, post, put, delete
from tina4_python.database.connection import Database


@get("/api/notes")
async def list_notes(request, response):
    db = Database()
    category = request.params.get("category")
    pinned = request.params.get("pinned")

    sql = "SELECT * FROM notes"
    params = []
    conditions = []

    if category:
        conditions.append("category = ?")
        params.append(category)

    if pinned == "true":
        conditions.append("pinned = 1")

    if conditions:
        sql += " WHERE " + " AND ".join(conditions)

    sql += " ORDER BY pinned DESC, created_at DESC"

    notes = db.fetch(sql, params)

    return response.json({"notes": notes, "count": len(notes)})


@get("/api/notes/categories")
async def list_categories(request, response):
    db = Database()
    categories = db.fetch(
        "SELECT category, COUNT(*) as count FROM notes GROUP BY category ORDER BY count DESC"
    )
    return response.json({"categories": categories})


@get("/api/notes/{id:int}")
async def get_note(request, response):
    db = Database()
    note = db.fetch_one(
        "SELECT * FROM notes WHERE id = ?",
        [request.params["id"]]
    )

    if note is None:
        return response.json({"error": "Note not found"}, 404)

    return response.json(note)


@post("/api/notes")
async def create_note(request, response):
    db = Database()
    body = request.body

    if not body.get("title"):
        return response.json({"error": "Title is required"}, 400)

    result = db.execute(
        "INSERT INTO notes (title, content, category, pinned) VALUES (?, ?, ?, ?)",
        [body["title"], body.get("content", ""), body.get("category", "general"), 1 if body.get("pinned") else 0]
    )

    note = db.fetch_one("SELECT * FROM notes WHERE id = ?", [result.last_id])
    db.cache_clear()

    return response.json({"message": "Note created", "note": note}, 201)


@put("/api/notes/{id:int}")
async def update_note(request, response):
    db = Database()
    note_id = request.params["id"]
    body = request.body

    existing = db.fetch_one("SELECT * FROM notes WHERE id = ?", [note_id])
    if existing is None:
        return response.json({"error": "Note not found"}, 404)

    db.execute(
        """UPDATE notes
           SET title = ?, content = ?, category = ?,
               pinned = ?, updated_at = CURRENT_TIMESTAMP
           WHERE id = ?""",
        [
            body.get("title", existing["title"]),
            body.get("content", existing["content"]),
            body.get("category", existing["category"]),
            1 if body.get("pinned", existing["pinned"]) else 0,
            note_id
        ]
    )

    updated = db.fetch_one("SELECT * FROM notes WHERE id = ?", [note_id])
    db.cache_clear()

    return response.json({"message": "Note updated", "note": updated})


@delete("/api/notes/{id:int}")
async def delete_note(request, response):
    db = Database()
    note_id = request.params["id"]

    existing = db.fetch_one("SELECT * FROM notes WHERE id = ?", [note_id])
    if existing is None:
        return response.json({"error": "Note not found"}, 404)

    db.execute("DELETE FROM notes WHERE id = ?", [note_id])
    db.cache_clear()

    return response.json(None, 204)
```

**Expected output for creating a note:**

```json
{
  "message": "Note created",
  "note": {
    "id": 1,
    "title": "Shopping List",
    "content": "Milk, eggs, bread",
    "category": "personal",
    "pinned": 0,
    "created_at": "2026-03-22 16:00:00",
    "updated_at": "2026-03-22 16:00:00"
  }
}
```

(Status: `201 Created`)

**Expected output for categories:**

```json
{
  "categories": [
    {"category": "personal", "count": 1},
    {"category": "work", "count": 1}
  ]
}
```

---

## 14. Seeder -- Generating Test Data

Testing with an empty database tells you nothing. Testing with hand-typed rows is slow and brittle. The `FakeData` class generates realistic test data, and `seed_table()` inserts it in bulk.

### FakeData

```python
from tina4_python.seeder import FakeData

fake = FakeData()

fake.name()       # "Grace Lopez"
fake.email()      # "bob.anderson@demo.net"
fake.phone()      # "+1 (547) 382-9104"
fake.sentence()   # "Magna exercitation lorem ipsum dolor sit amet consectetur."
fake.paragraph()  # Four sentences of filler text
fake.integer()    # 7342
fake.decimal()    # 481.29
fake.date()       # "2023-07-14"
fake.uuid()       # "a3f1b2c4-d5e6-f7a8-b9c0-d1e2f3a4b5c6"
fake.address()    # "742 Oak Ave, Tokyo"
fake.boolean()    # True
```

Every method draws from built-in word banks -- no network calls, no external packages.

### Deterministic Output

Pass a seed to get reproducible results. The same seed produces the same sequence every time:

```python
fake = FakeData(seed=42)
fake.name()   # Always "Wendy White" with seed 42
fake.email()  # Always the same email with seed 42
```

Deterministic data means deterministic assertions. This matters for tests.

### Seeding a Table

`seed_table()` combines `FakeData` with your database. Pass a field map -- a dictionary where each key is a column name and each value is a callable that generates data:

```python
from tina4_python.seeder import FakeData, seed_table
from tina4_python.database.connection import Database

db = Database()
fake = FakeData(seed=1)

seed_table(db, "users", 100, {
    "name": fake.name,
    "email": fake.email,
    "phone": fake.phone,
    "bio": fake.sentence,
})
```

This inserts 100 rows into the `users` table. Each row calls `fake.name()`, `fake.email()`, and so on to generate its values. The function commits after all rows are inserted.

### Overrides

Static values that apply to every row go in the `overrides` dictionary:

```python
seed_table(db, "users", 50,
    field_map={
        "name": fake.name,
        "email": fake.email,
    },
    overrides={
        "role": "member",
        "active": 1,
    },
)
```

Every row gets `role = "member"` and `active = 1`. The field map generates the rest.

### When to Use It

- Populating a development database with realistic data
- Writing integration tests that need rows in the database
- Load testing with thousands of records
- Demos and screenshots that look real without using real data

---

## 15. Gotchas

### 1. SQLite boolean quirk

**Problem:** Boolean values come back as `0` and `1` instead of `false` and `true` in JSON.

**Cause:** SQLite has no native boolean type. It stores booleans as integers.

**Fix:** This is expected. In your route handler, convert them: `note["pinned"] = bool(note["pinned"])`. Or handle it in the frontend. The ORM (Chapter 6) does this conversion with `BooleanField`.

### 2. last_insert_rowid() is SQLite-specific

**Problem:** `SELECT * FROM notes WHERE id = last_insert_rowid()` does not work on PostgreSQL or MySQL.

**Cause:** `last_insert_rowid()` is a SQLite function. Other databases use different mechanisms.

**Fix:** Use `db.insert()` which returns the last inserted ID regardless of engine. Or use database-specific syntax: PostgreSQL uses `RETURNING id` in the INSERT statement, MySQL uses `LAST_INSERT_ID()`.

### 3. String vs integer comparison

**Problem:** `WHERE id = ?` does not find the row even though the ID exists.

**Cause:** Path parameters arrive as strings by default. If `id` is `"5"` (string) and the column is an integer, some databases handle this differently.

**Fix:** Use typed path parameters (`{id:int}`) so the value is already an integer, or cast explicitly: `[int(request.params["id"])]`.

### 4. Connection not closed

**Problem:** After many requests, the application runs out of database connections.

**Cause:** You create `Database()` instances without them being cleaned up.

**Fix:** Tina4's `Database()` manages connection pooling internally. Creating `Database()` in each handler is fine because it reuses connections from the pool. If you see connection issues, check that you are not holding transactions open too long.

### 5. Migration order matters

**Problem:** A migration fails because it references a table that does not exist yet.

**Cause:** Migrations run in alphabetical order. If migration B depends on the table created by migration A, migration A must sort earlier.

**Fix:** Use `tina4 generate migration` which auto-generates sequential numbers. Do not mix `000001_` and `YYYYMMDDHHMMSS_` patterns in the same project -- `000001_` sorts before `20240315_`, which scrambles your intended order.

### 6. Missing down migration

**Problem:** `tina4python migrate:rollback` fails with an error about a missing file.

**Cause:** The `.down.sql` file does not exist for the migration being rolled back.

**Fix:** Create a `.down.sql` file with the exact same base name as the up migration. If your up file is `000001_create_users.sql`, the down file must be `000001_create_users.down.sql`. It should undo exactly what the up migration did. For `CREATE TABLE`, the down is `DROP TABLE IF EXISTS`. For `ALTER TABLE ADD COLUMN`, the down is `ALTER TABLE DROP COLUMN` (though SQLite does not support dropping columns -- in that case, recreate the table).

### 7. Failed migrations blocking progress

**Problem:** A migration failed and now `tina4 migrate` keeps retrying it.

**Cause:** Failed migrations are recorded in the `tina4_migration` table with `passed = 0`. Tina4 retries them on the next `migrate` run.

**Fix:** Fix the SQL in the migration file, then run `tina4 migrate` again. The failed migration retries. If you need to skip it entirely, update its `passed` column to `1` in the `tina4_migration` table manually -- but fix the root cause first.

### 8. SQL injection through string formatting

**Problem:** Your application is vulnerable to SQL injection attacks.

**Cause:** You used f-strings or string concatenation to build SQL queries with user input: `f"WHERE name = '{name}'"`.

**Fix:** Use parameterised queries: `"WHERE name = ?", [name]`. This is the single most important security practice for database code. Tina4 handles escaping and quoting for you.
