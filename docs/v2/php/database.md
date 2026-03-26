# Working with Databases {#connections}
::: tip 🔥 Hot Tips
- Instantiate `$DBA` in the `index.php`,  declare it as a `global`
- `$DBA` is the recognized global for database handling, but you can use any naming.
- Always call `commit()` after `insert/update/delete` unless in a transaction.
- Beware, implementation is database specific, for example Sqlite does not do transactions, MySql does not implement `returning`.
- It is good practice to use [Migrations](migrations.md) instead of the `exec` function for database creation.
- Most methods return a `DatabaseResult` object which you can transform.   
  :::
- 
## Available Connections
Database modules do not ship with Tina4php, to avoid bloat in the software. The [quick reference](index.md#databases) details how to implement one
of the following database modules, which need to be included in your composer files.
```bash
composer require tina4stack/tina4php-sqlite3
composer require tina4stack/tina4php-mysql
composer require tina4stack/tina4php-mssql
composer require tina4stack/tina4php-postgresql
composer require tina4stack/tina4php-firebird
composer require tina4stack/tina4php-mongodb
composer require tina4stack/tina4php-graphql
```
If your database module is not present you can write your own based on the `Database` interface.

## Core Methods {#core-methods} 

| Method                                              | Description                                        | Returns                     |
|-----------------------------------------------------|----------------------------------------------------|-----------------------------|
| `exec($sql, $params=None)`                          | Run any SQL (CREATE, DROP, INSERT, …) - Not SELECT | `DataResult` or `DataError` |
| `fetch($sql, $noOfRecords, $offset, $fieldMapping)` | SELECT with pagination & search                    | `DataResult` or `DataError` |
| `fetchOne(sql, params=None)`                        | Return single row                                  | `array` or `null`           |
| `tableExists(table_name)`                           | Check if table exists                              | `bool`                      |
| `startTransaction()`, `commit()`, `rollback()`      | Full transaction control                           | —                           |
| `close()`                                           | Close connection                                   | —                           |

## Usage {#usage}

Every query returns a `DataResult` with these properties:

```php
global $DBA;
$result = $DBA->fetch("select * from user");

$result->noOfRecords;       // Number of records
$result->recordsFiltered;   // Number of records filtered by where statement
$result->recordCount;       // Number of records returned in the page, when using pagination (limit)
$result->recordsOffset;     // Start record for the page returned (offset)
$result->fields;            // Array of the fields in the record set
$result->data;              // Array of data records
$result->error;             // Object containing errorCode and errorMessage

$result->asArray();         // Returns an array of records as arrays
$result->asObject();        // Returns an array of records as objects
$result->asOriginal();      // Returns an object of records as objects
```

## Examples {#examples}

```php
// Using exec to insert a record
$result = $DBA->exec('insert into transactions (id, transaction) values (6, "12000") returning');

// Using fetch to select a records as an array of arrays
$result = $DBA->fetch("select * from user")->asArray();

// Using fetch to select records with pagination (returns the first 10 records)  as an array of Objects
$result = $DBA->fetch("select * from user", 10, 0)->asObject();
```

## Transactions {#transactions}

```php
global $DBA;
$transId = $DBA->startTransaction();
try {
    $result = $DBA->exec('insert into transactions (id, transaction) values (6, "12000")');
    $result = $DBA->exec('insert into transactions (id, transaction) values (6, "12000")');
    $DBA->commit($transId);
} catch (Exception $e) {
    $DBA->rollback($transId);
    return $response($e->getMessage(), HTTP_OK, APPLICATION_JSON);
}
```