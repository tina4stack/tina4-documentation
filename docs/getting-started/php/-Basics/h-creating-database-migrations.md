# Database Migrations

If you are maintaining a database whilst developing an application there are always going to be incremental changes occuring to the database.
Database migrations help keep track of this. Tina4 has simple forward rolling migrations which should suffice for most projects.

## Connect to the database

Let's use an SQlite3 database to test with. Use composer to get the required package:

```bash
composer require tina4stack/tina4php-sqlite3
```

Modify the `index.php` to instantiate a `test.db`

```php
require_once "./vendor/autoload.php";

global $DBA;
$DBA = new \Tina4\DataSQLite3("test.db", $username="", $password="");

$config = new \Tina4\Config(static function (\Tina4\Config $config){
    //Your own config initializations
     
});

echo new \Tina4\Tina4Php($config);
```

## First Migration

Make sure you have already established a database connection in your index file.  Navigate to the following
URL to start your migrations: [http://localhost:7145/migrate/create](http://localhost:7145/migrate/create).
This URL is only available if `TINA4_DEBUG=true`

Fill in a description for the migration and paste in your SQL code in the SQL Statement input.
Here is some code you can test:

```sql
create table user (
  id integer not null,
  first_name varchar(100) default '',
  last_name varchar(100) default '',
  email varchar(255) default '',
  primary key (id)
);
```

Click the "Create Migration" button to create the migration. You should see a migrations folder created in your project root.

Use this URL [http://localhost:7145/migrate](http://localhost:7145/migrate) to run the migration you have just created.
The status of the migrations will be present on this end point.

!!! tip "Hot Tips"
    - You can call the `/migrate` end point from your CI tool to run migrations on deployment.
    - The migrations are stored in a `tina4_migration` table where their pass status is recorded.
    - Stored procedures should be migrated by themselves, one file per stored procedure.
    - Multiple SQL statements are separated by `;`
