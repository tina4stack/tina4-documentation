# Migrations

::: tip 🔥 Hot Tips
- Migrations are forward-rolling and track database changes using SQL statements.
- Use for incremental database updates during development.
- Tracked in the `tina4_migration` table for status.
- Migration files stored in `./migrations` and contain editable SQL.
  :::

## Creating a Migration

Tina4 migrations are created by calling `tina4 migrate:create`. Provide a description for the migration.

```bash
uv run tina4 migrate:create "Create users table"
```

- This generates a new migration file in `./migrations` with a timestamped name like `000001_create_users_table.sql`.
- Description is normalized to lowercase with underscores.
- Edit the file to add your SQL code (e.g., CREATE TABLE, ALTER TABLE).
- Example SQL in the file:
  ```sql
  CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
  );
  ```

Migrations can also auto-generate SQL when initializing an ORM object if the table doesn't exist—it logs the CREATE TABLE SQL to the console, which you can copy into a migration file.

## Running Migrations

Run pending migrations via `uv run tina4 migrate`.

- Scans `./migrations` for `.sql` files, sorted alphabetically.
- Executes SQL (split by `;`) from unrun migrations.
- Updates status in `tina4_migration` table.
- On failure, rolls back, logs error, and exits.

## Migrations as Part of Startup

After declaring your database handle in code (e.g., `app.py`), call `migrate` to run migrations on startup.

```python
from tina4_python.Database import Database
from tina4_python.Migration import migrate

dba = Database("sqlite3:test.db")  # Example connection
migrate(dba)  # Runs all pending migrations
```

## ORM Integration

Define models extending `tina4_python.ORM`. Fields require type classes with optional parameters.

```python
# src/app/models.py

from tina4_python import ORM
from tina4_python.FieldTypes import IntegerField, StringField

class Car(ORM):
    table_name = "car"  # Optional, inferred as snake_case from class name
    id = IntegerField(primary_key=True, auto_increment=True)
    brand_name = StringField()
    year = IntegerField()
```

- Initializing without table logs CREATE TABLE SQL.
- Fields map to snake_case in database.
- Supported field types include: IntegerField, StringField, TextField, DateField, etc. (import from `tina4_python.FieldTypes`).
- Parameters: primary_key, auto_increment, default_value, etc.

## Database Configuration

Configure connections directly in code or via environment variables for flexibility.

Example:
```bash
TINA4_DATABASE_NAME=sqlite3:test.db
```

In code:
```python
import os
from tina4_python.Database import Database

dba = Database(os.getenv("TINA4_DATABASE_NAME", "sqlite3:test.db"))
```

Supports SQLite, PostgreSQL, MySQL, MariaDB, MSSQL, Firebird. Install required drivers (e.g., `uv add psycopg2` for PostgreSQL).