# Migrations

::: tip 🔥 Hot Tips
- Migrations are forward-rolling and track database changes using SQL statements.
- Use for incremental database updates during development.
- Tracked in the `tina4_migration` table for status.
- Migration files stored in `./migrations` and contain editable SQL.
- Any migration depending on a previous migration should be placed in a separate migration. 
  :::

## Creating a Migration {#creation}

It is highly recommended that any database building is done through migrations, to benefit from the version control 
and deploy benefits (presuming you build it in) that migrations offer.

In a browser `/migrate/create` will offer an simple form to create the migration. The `.env` variable must be set `TINA4_DEBUG=true`.
Tina4 creates the timestamped migration files and are saved in the `./migrations` folder and can be edited there as needed.

Alternatively this can be done from the command line and does not require the `.env` variable setting. This will create the 
migration file in the `./migrations` folder, after which it must be edited.
```bash

php bin/tina4 migrate:create "add new table"  
```

## Running the migrations {#running}

Once finished editing the migration or migrations, again in the browser `/migrate` will check which migrations have been run and only 
run the new migrations. This is presented by a colour coded text log onscreen. These are tracked in the `tina4_migrations` database table, 
first created on the first migration creation. 

Alternatively this can be done from the command line. 
```bash

php bin/tina4 migrate
```

## ORM integrations {#orm}

Define ORM models extending `\Tina4\ORM`. On the first attempted interaction with the table, Tina4 will automatically create 
the migration file. It will throw an error, warning that the migrations need to be run.

Default fields are varchar(1000) or can be defined using an annotation.

```php
class Role extends \Tina4\ORM
{
    public $tableName = 'role';
    
    public $genPrimaryKey = true;

    public $id;         // Without annotations $id will be integer not null and the primary key
    /**
    * This will ensure that $roleName will be a varchar(32)
    * @var varchar(32)
    */
    public $roleName;   // Will resolve to snake case on the database role_name
}
```
Will create the following migration
```sql
create table role (
	id integer not null,
	role_name varchar(32),
   primary key (id)
)
```