# Connecting to a database

Connecting to a database engine requires additional composer libraries to be installed for the database engine
you want to connect to.  Below is a list of database engines that are supported.

## List of database composer libraries

| Database   | Composer Command                                      |
|------------|-------------------------------------------------------|
| Sqlite3    | ```composer require tina4stack/tina4php-sqlite3```    |
| ODBC       | ```composer require tina4stack/tina4php-odbc```       |
| MySQL      | ```composer require tina4stack/tina4php-mysql```      |
| Firebird   | ```composer require tina4stack/tina4php-firebird```   |
| MongoDB    | ```composer require tina4stack/tina4php-mongodb```    |
| PostgreSQL | ```composer require tina4stack/tina4php-postgresql``` |
| MSSQL      | ```composer require tina4stack/tina4php-mssql```      |
| PDO        | ```composer require tina4stack/tina4php-pdo```        |

## Creating a database connection string

A connection string is composed of the following sections:

`<host>/<port>:<schema/path-to-database>`

We create a global `$DBA` variable in `index.php` which can be used by the data aware classes.

```php
require_once "./vendor/autoload.php";

global $DBA;
$DBA = new \Tina4\DataSQLite3("test.db", $username="", $password="");

$config = new \Tina4\Config(static function (\Tina4\Config $config){
    //Your own config initializations
     
});

echo new \Tina4\Tina4Php($config);
```

Alternatively the database connection can be instantiated in the config section in the `index.php`,
This means the database connection will only be available to routes or REST end points.

```php
<?php
require_once "./vendor/autoload.php";

$config = new \Tina4\Config(static function (\Tina4\Config $config){
    //Your own config initializations
    global $DBA;
    $DBA = new \Tina4\DataSQLite3("test.db", $username="", $password="");   
});

echo new \Tina4\Tina4Php($config);
```

>- Extend `\Tina4\Data` for a class that needs a database connection