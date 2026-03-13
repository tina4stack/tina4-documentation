# Migrations

::: tip 🔥 Hot Tips
- Migrations are plain SQL files — no Ruby DSL to learn
- Rollback support via `.down.sql` companion files
- Tracked in a `tina4_migrations` table automatically
:::

## Creating Migrations

```bash
tina4 migrate --create create_users_table
```

This creates two files:
```
migrations/20260313120000_create_users_table.sql       # Up migration
migrations/20260313120000_create_users_table.down.sql   # Rollback
```

## Writing Migrations

Edit the `.sql` file with your SQL:

```sql
-- migrations/20260313120000_create_users_table.sql
CREATE TABLE users (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name  TEXT NOT NULL,
    email TEXT UNIQUE,
    age   INTEGER DEFAULT 0
);
```

And the rollback:

```sql
-- migrations/20260313120000_create_users_table.down.sql
DROP TABLE IF EXISTS users;
```

## Running Migrations

```bash
tina4 migrate
```

Output:
```
  [OK] 20260313120000_create_users_table.sql
  [OK] 20260313120100_add_posts_table.sql
```

## Rollback

```bash
tina4 migrate --rollback 1    # Roll back the last migration
tina4 migrate --rollback 3    # Roll back the last 3 migrations
```

## Status

Check migration status programmatically:

```ruby
db = Tina4.database
migration = Tina4::Migration.new(db)

status = migration.status
puts status[:completed]    # → ["20260313120000_create_users_table.sql"]
puts status[:pending]      # → ["20260313120100_add_posts_table.sql"]
```

## Programmatic Usage

```ruby
db = Tina4::Database.new("sqlite3:data.db")
migration = Tina4::Migration.new(db, migrations_dir: "./migrations")

# Create
migration.create("add_email_column")

# Run all pending
results = migration.run
results.each do |r|
  puts "#{r[:name]}: #{r[:status]}"
end

# Rollback
migration.rollback(1)
```
