# Chapter 5: Database

## 1. From Lists to Real Data

Every example so far stored data in Python lists. Restart the server. Data gone. A real application needs a database.

Tina4 Python makes this painless. Set a `DATABASE_URL` in your `.env`. Create a `Database()` connection. Run SQL. No ORM required (Chapter 6 adds that). Write the SQL you already know.

Picture a notes application. Users create, edit, and delete notes. Those notes need to survive restarts, support searching, and handle concurrent users. That is what a database provides.

---

## 2. Configuration

### DATABASE_URL

Set your database connection in `.env`:

```env
DATABASE_URL=sqlite:///data/app.db
```

That is the default -- a SQLite database stored in `data/`. SQLite comes with Python. No install required.

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

That is it. `Database()` reads `DATABASE_URL` from your `.env` and connects. If the SQLite database file does not exist, it creates one.

You can also pass a URL directly:

```python
db = Database("sqlite:///data/test.db")
```

### Connection Pooling

For applications that handle many concurrent requests, enable connection pooling by passing a `pool` argument:

```python
db = Database("postgres://localhost/mydb", pool=5)  # 5 connections, round-robin
```

The `pool` parameter controls how many database connections are maintained:

- `pool=0` (the default) -- a single connection is used for all queries
- `pool=N` (where N > 0) -- N connections are created and rotated round-robin across queries

Pooled connections are thread-safe. Each query is dispatched to the next available connection in the pool. This eliminates contention when multiple route handlers query the database simultaneously.

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

`fetch()` returns a list of dictionaries. Each dictionary represents a row:

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

Access rows by index like a regular list:

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
result.to_json()      # JSON string of all records
result.to_csv()       # CSV string with column headers
result.to_array()     # plain list of dictionaries
result.to_paginate()  # {"records": [...], "count": 42, "limit": 10, "offset": 0}
```

`to_paginate()` is designed for building paginated API responses. It bundles the records with the total count, limit, and offset in a single dictionary.

#### Schema Metadata with column_info()

`column_info()` returns detailed metadata about the columns in the result set. The data is lazy-loaded -- it only queries the database schema when you call the method for the first time:

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

This is useful for building dynamic forms, generating documentation, or validating data before insert.

### fetch_one -- Get a Single Row

```python
@get("/api/notes/{id:int}")
async def get_note(request, response):
    db = Database()
    note = db.fetch_one(
        "SELECT id, title, content, created_at FROM notes WHERE id = :id",
        {"id": request.params["id"]}
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

    db.execute(
        "INSERT INTO notes (title, content) VALUES (:title, :content)",
        {"title": body["title"], "content": body.get("content", "")}
    )

    note = db.fetch_one("SELECT * FROM notes WHERE id = last_insert_rowid()")

    return response.json({"message": "Note created", "note": note}, 201)
```

`execute()` runs an INSERT, UPDATE, or DELETE statement and returns the number of affected rows.

---

## 5. Parameterised Queries

Never concatenate user input into SQL strings. Parameterised queries are the wall between you and SQL injection:

```python
# WRONG -- SQL injection vulnerability
db.fetch(f"SELECT * FROM notes WHERE title = '{user_input}'")

# CORRECT -- parameterised query
db.fetch("SELECT * FROM notes WHERE title = :title", {"title": user_input})
```

Named parameters use the `:name` syntax. Pass a dictionary of values as the second argument:

```python
db.fetch(
    "SELECT * FROM notes WHERE category = :category AND created_at > :since",
    {"category": "work", "since": "2026-03-01"}
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
            "UPDATE accounts SET balance = balance - :amount WHERE id = :id AND balance >= :amount",
            {"amount": amount, "id": from_account}
        )

        # Check if deduction succeeded
        sender = db.fetch_one(
            "SELECT balance FROM accounts WHERE id = :id",
            {"id": from_account}
        )

        if sender is None:
            db.rollback()
            return response.json({"error": "Insufficient funds or account not found"}, 400)

        # Credit receiver
        db.execute(
            "UPDATE accounts SET balance = balance + :amount WHERE id = :id",
            {"amount": amount, "id": to_account}
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
        {"title": note["title"], "content": note.get("content", "")}
        for note in notes
    ]

    db.execute_many(
        "INSERT INTO notes (title, content) VALUES (:title, :content)",
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
last_id = db.insert("notes", {
    "title": "Quick Note",
    "content": "Created with insert helper"
})
```

Returns the last inserted ID.

### update

```python
affected = db.update("notes", {"title": "Updated Title", "content": "New content"}, "id = :id", {"id": 1})
```

The third argument is the WHERE clause, the fourth is its parameters. Returns the number of affected rows.

### delete

```python
affected = db.delete("notes", "id = :id", {"id": 1})
```

Returns the number of deleted rows.

These helpers eliminate boilerplate INSERT/UPDATE/DELETE SQL. For complex queries, `execute()` is always there.

---

## 9. Migrations

Migrations are SQL files that version your database schema. Write them once. Apply them in order. Roll them back when needed.

### File Naming

Migration files live in a `migrations/` directory. Two naming patterns are supported:

| Pattern | Example |
|---------|---------|
| Sequential | `000001_create_users.sql` |
| Timestamp | `20260322160000_create_notes.sql` |

Files are sorted alphabetically when they run. Pick one pattern and stick with it -- `000001_` sorts before `20260322_`, so mixing the two in one project leads to unexpected execution order.

### Generating a Migration

```bash
tina4 generate migration create_notes_table
```

This creates two files:

```
migrations/000001_create_notes_table.sql
migrations/000001_create_notes_table.down.sql
```

The first is your "up" migration. The second is the matching "down" migration used for rollbacks.

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

Down migrations are optional. If you skip them, everything works until you try to roll back -- at which point Tina4 will fail with a clear error telling you the down file is missing.

The `.down.sql` file must share the exact same base name as the up file. If your up file is `000001_create_notes_table.sql`, the down file must be `000001_create_notes_table.down.sql`.

### Running Migrations

```bash
tina4 migrate
# or
tina4python migrate
```

Tina4 finds all pending `.sql` files in `migrations/`, sorts them alphabetically, and executes them in order. Each run is assigned a **batch number**. The batch groups every migration applied in that single run.

### Checking Status

```bash
tina4python migrate:status
```

This shows which migrations have been applied and which are still pending. Useful before deploying to see what will run.

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

Failed migrations are recorded with `passed = 0`. On the next `tina4 migrate` run, they will be retried automatically.

### Advanced SQL Splitting

Tina4's migration runner is not a naive line splitter. It correctly handles:

- **`$$` delimited blocks** -- PostgreSQL stored procedures and functions that contain semicolons
- **`//` blocks** -- alternative delimiter blocks
- **`/* */` block comments** -- skipped during splitting
- **`--` line comments** -- skipped during splitting

This means you can write PostgreSQL stored procedures in your migration files without worrying about the runner choking on internal semicolons.

### Migration Best Practices

1. **One migration per change** -- do not pile multiple table changes into one file
2. **Always write a down migration** -- so you can roll back cleanly
3. **Never edit a migration that has been applied** -- create a new migration instead
4. **Use descriptive names** -- `create_users_table`, `add_email_to_orders`, `create_category_index`
5. **Pick one naming pattern** -- use either `000001_` or `YYYYMMDDHHMMSS_`, not both

---

## 10. Query Caching

Expensive queries that return the same result on every call deserve caching. Tina4 builds it in:

```python
from tina4_python.database.connection import Database

db = Database()

# Cache this query result for 300 seconds (5 minutes)
categories = db.fetch(
    "SELECT DISTINCT category, COUNT(*) as count FROM notes GROUP BY category",
    cache_ttl=300
)
```

The first call runs the SQL and caches the result. Subsequent calls within the TTL skip the database entirely.

To invalidate the cache when data changes:

```python
@post("/api/notes")
async def create_note(request, response):
    db = Database()
    db.execute(
        "INSERT INTO notes (title, content, category) VALUES (:title, :content, :category)",
        {"title": request.body["title"], "content": request.body.get("content", ""), "category": request.body.get("category", "general")}
    )

    # Clear cached queries that might be stale
    db.clear_cache()

    note = db.fetch_one("SELECT * FROM notes WHERE id = last_insert_rowid()")
    return response.json({"note": note}, 201)
```

---

## 11. Exercise: Build a Notes App API

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

## 12. Solution

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
    category = request.query.get("category")
    pinned = request.query.get("pinned")

    sql = "SELECT * FROM notes"
    params = {}
    conditions = []

    if category:
        conditions.append("category = :category")
        params["category"] = category

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
        "SELECT category, COUNT(*) as count FROM notes GROUP BY category ORDER BY count DESC",
        cache_ttl=60
    )
    return response.json({"categories": categories})


@get("/api/notes/{id:int}")
async def get_note(request, response):
    db = Database()
    note = db.fetch_one(
        "SELECT * FROM notes WHERE id = :id",
        {"id": request.params["id"]}
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

    db.execute(
        "INSERT INTO notes (title, content, category, pinned) VALUES (:title, :content, :category, :pinned)",
        {
            "title": body["title"],
            "content": body.get("content", ""),
            "category": body.get("category", "general"),
            "pinned": 1 if body.get("pinned") else 0
        }
    )

    note = db.fetch_one("SELECT * FROM notes WHERE id = last_insert_rowid()")
    db.clear_cache()

    return response.json({"message": "Note created", "note": note}, 201)


@put("/api/notes/{id:int}")
async def update_note(request, response):
    db = Database()
    note_id = request.params["id"]
    body = request.body

    existing = db.fetch_one("SELECT * FROM notes WHERE id = :id", {"id": note_id})
    if existing is None:
        return response.json({"error": "Note not found"}, 404)

    db.execute(
        """UPDATE notes
           SET title = :title, content = :content, category = :category,
               pinned = :pinned, updated_at = CURRENT_TIMESTAMP
           WHERE id = :id""",
        {
            "title": body.get("title", existing["title"]),
            "content": body.get("content", existing["content"]),
            "category": body.get("category", existing["category"]),
            "pinned": 1 if body.get("pinned", existing["pinned"]) else 0,
            "id": note_id
        }
    )

    updated = db.fetch_one("SELECT * FROM notes WHERE id = :id", {"id": note_id})
    db.clear_cache()

    return response.json({"message": "Note updated", "note": updated})


@delete("/api/notes/{id:int}")
async def delete_note(request, response):
    db = Database()
    note_id = request.params["id"]

    existing = db.fetch_one("SELECT * FROM notes WHERE id = :id", {"id": note_id})
    if existing is None:
        return response.json({"error": "Note not found"}, 404)

    db.execute("DELETE FROM notes WHERE id = :id", {"id": note_id})
    db.clear_cache()

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

## 13. Seeder -- Generating Test Data

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

Pass a seed to get reproducible results. The same seed always produces the same sequence:

```python
fake = FakeData(seed=42)
fake.name()   # Always "Wendy White" with seed 42
fake.email()  # Always the same email with seed 42
```

This matters for tests. Deterministic data means deterministic assertions.

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

This inserts 100 rows into the `users` table. Each row calls `fake.name()`, `fake.email()`, and so on to generate its values. The function commits automatically after all rows are inserted.

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

## 14. Gotchas

### 1. SQLite boolean quirk

**Problem:** Boolean values come back as `0` and `1` instead of `false` and `true` in JSON.

**Cause:** SQLite does not have a native boolean type. It stores booleans as integers.

**Fix:** This is expected behavior. In your route handler, you can convert them: `note["pinned"] = bool(note["pinned"])`. Or handle it in the frontend. The ORM (Chapter 6) does this conversion automatically with `BooleanField`.

### 2. last_insert_rowid() is SQLite-specific

**Problem:** `SELECT * FROM notes WHERE id = last_insert_rowid()` does not work on PostgreSQL or MySQL.

**Cause:** `last_insert_rowid()` is a SQLite function. Other databases use different mechanisms.

**Fix:** Use `db.insert()` which returns the last inserted ID regardless of database engine. Or use database-specific syntax: PostgreSQL uses `RETURNING id` in the INSERT statement, MySQL uses `LAST_INSERT_ID()`.

### 3. String vs integer comparison

**Problem:** `WHERE id = :id` does not find the row even though the ID exists.

**Cause:** Path parameters come as strings by default. If `id` is `"5"` (string) and the column is an integer, some databases handle this differently.

**Fix:** Use typed path parameters (`{id:int}`) so the value is already an integer, or explicitly cast: `{"id": int(request.params["id"])}`.

### 4. Connection not closed

**Problem:** After many requests, the application runs out of database connections.

**Cause:** You are creating `Database()` instances without them being properly cleaned up.

**Fix:** Tina4's `Database()` manages connection pooling internally. In most cases, creating `Database()` in each handler is fine because it reuses connections from the pool. If you are seeing connection issues, check that you are not holding transactions open for too long.

### 5. Migration order matters

**Problem:** A migration fails because it references a table that does not exist yet.

**Cause:** Migrations run in alphabetical order. If migration B depends on the table created by migration A, migration A must sort earlier alphabetically.

**Fix:** Use `tina4 generate migration` which auto-generates sequential numbers. Do not mix `000001_` and `YYYYMMDDHHMMSS_` patterns in the same project -- `000001_` sorts before `20240315_`, which will scramble your intended order.

### 6. Missing down migration

**Problem:** `tina4python migrate:rollback` fails with an error about a missing file.

**Cause:** The `.down.sql` file does not exist for the migration being rolled back.

**Fix:** Create a `.down.sql` file with the exact same base name as the up migration. If your up file is `000001_create_users.sql`, the down file must be `000001_create_users.down.sql`. It should undo exactly what the up migration did. For `CREATE TABLE`, the down is `DROP TABLE IF EXISTS`. For `ALTER TABLE ADD COLUMN`, the down is `ALTER TABLE DROP COLUMN` (though SQLite does not support dropping columns -- in that case, you may need to recreate the table).

### 7. Failed migrations blocking progress

**Problem:** A migration failed and now `tina4 migrate` keeps skipping it or retrying it.

**Cause:** Failed migrations are recorded in the `tina4_migration` table with `passed = 0`. Tina4 will retry them on the next `migrate` run.

**Fix:** Fix the SQL in the migration file, then run `tina4 migrate` again. The failed migration will be retried. If you need to skip it entirely, you can manually update its `passed` column to `1` in the `tina4_migration` table -- but fix the root cause first.

### 8. SQL injection through string formatting

**Problem:** Your application is vulnerable to SQL injection attacks.

**Cause:** You used f-strings or string concatenation to build SQL queries with user input: `f"WHERE name = '{name}'"`.

**Fix:** Always use parameterised queries: `"WHERE name = :name", {"name": name}`. This is the single most important security practice for database code. Tina4 will handle escaping and quoting for you.
