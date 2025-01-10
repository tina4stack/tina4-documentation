# Database Migrations

Database migrations help you keep track of your database changes.  We keep track of migrations in the database using the `tina4_migration` table which will be created the first time you run migrations on your database.
Our methodology is a forward-only migration, once a migration has been flagged as passed you should not be changing the files in your code repository.
Migrations are transactional so if you add multiple lines of SQL in to a single migration make sure that it makes sense.  For example, you would need to put create table statements in a different migration file from the migration that adds the data as the create table statements would need to `pass` first.
## Getting started with migrations

First you need a database connection, once you have that you can implement migrations. Consider the following code in `src/__init__.py`:

```python
from tina4_python.Migration import migrate
from tina4_python.Database import Database


dba = Database("sqlite3:test.db", "username", "password")
migrate(dba)
```

The migration method takes the database connection and runs migrations on it. Your migrations are found in the migrations folder in the root of your project (the same place your `pyproject.toml` file exists).

Migrations are plain SQL statements that modify the data stored in a text file with a `.sql` extension.  Our suggested naming convention is to give a migration number followed by a description.

### Migration naming example:

```bash
00001_my_first_table_migration.sql
```

Inside the file you can have one or more SQL statements separated by a `;`.

When you start up your project the migrations will run and whether they fail or pass will be stored in the database. You can easily see
the state of a migration by the console output when you run the project.  You can then fix the migration and re-run the project to get the migration working.

## Hot Tips

>- Migrations are transaction based, so if one fails the transaction rolls back and the database is unaffected.  You can see the errors on the console or in the `tina4_migration` table on why it failed.
>- If a migration fails the application will immediately terminate so nothing else can break.