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

- This generates a new migration file in `./migrations` with a timestamped name.
- Edit the file to add your SQL code (e.g., CREATE TABLE, ALTER TABLE).
- Example SQL in the file:
  ```sql
  CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
  );
  ```

Migrations can also auto-generate when saving an ORM object if the table doesn't exist, throwing an exception and creating a file.

## Running Migrations

Run pending migrations via `uv run tina4 migrate`.

- Executes SQL from unrun migrations.
- Updates status in `tina4_migration` table.

## Migrations as part of code start up

Just after you declare your database handle you can do the following

```python
from tina4_python.Migration import migrate
migrate(dba)
```

## ORM Integration

Define models extending `tina4_python.ORM`.

```python
# src/app/models.py

from tina4_python import ORM

class Car(ORM):
    table_name = "car"  # Optional, inferred from class name
    primary_key = "id"
    id: IntegerField(primary_key=True, auto_increment=True)
    brand_name: StringField()
    year: IntegerField()
```

- Calling `car.save()` without table creates migration file.
- Fields use snake_case in database.

## Database Configuration

Set in `.env` or environment variables.

Example:
```bash
TINA4_DATABASE_NAME=sqlite3:test.db
```

Supports SQLite, PostgreSQL, MySQL, etc.