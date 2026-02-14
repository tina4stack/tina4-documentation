# ORM
::: tip 🔥 Hot Tips
- You **never** need the ORM — raw `Database` is [perfect for 90% of cases](database.md)
- But when you want it . . , you might enjoy it, as it feels like writing plain classes
- Zero boilerplate — no methods to write
- Works with SQLite, PostgreSQL, MySQL, MSSQL, Firebird — all the same  
  :::

## Setting it all up

Ensure there is a global database connection, usually done in your `index.php` file, before calling the Tina4 echo.

```php
global $DBA;
$DBA = new \Tina4\DataSQLite3("database/myDatabase.db", "admin", "my-password", "d/m/Y");
```
Create the ORM class
```php
class User extends Tina4\ORM
{
public $tableName = 'user';

public $id;
public $email;
}
```
Create the table [using migrations](migrations.md) or [on first use](migrations.md#orm)

You are ready to go!

## ORM properties

The ORM operations can be modified by setting a number of the properties

| Property    | Usage Notes                                                                                                                                            |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| $primaryKey | Used to set the primary key if not `id` or set a compound key, as a comma delimited string.                                                            |
| $tableName | Set the table name that links the object to the database.                                                                                              |
| $fieldMapping | Default matches camelCase in the ORM to snake_case in the database. Set field mapping if the orm - database configuration does not match this pattern. |
| $virtualFields | An array of fields that do not belong to the table and will not be included in database interactions.                                                  |
| $excludeFields | An array of fields that are excluded from any return.                                                                                                  |
| $readOnlyFields | An array of fields in the table that should not be modified or inserted.                                                                               |
| $filterMethod | An anonymous function that can filter records at the ORM level.                                                                                        |
| $genPrimaryKey | Let Tina4 set the primary key using maximum primary key. Use with caution, can effect race conditions.                                                 |
| $protectedFields | Fields used by `Tina4\ORM` in operations. Not included in any object.                                                                                  |

## Simple usage

Create a new object
```php
// Creating with an empty object
$user = (new User());
$user->email = "mymail@email.com";
$user->save();

// OR with data on the outset
$user = (new User(["email" => "my-email@email.com"]));
$user->save();
```
Read and then update an object
```php
$user = (new User())->load("id = ?", [456]);
$user->email = "different@email.com";
$user->save();
```
Delete and object
```php
$user->delete("id = ?", [12])
```

## Advanced selects using ORM
The `select()` in ORM returns a `Tina4\SQL` object which then offers a number of other possibilities. To create neat responses
append `asArray()` or `asObject()` to the end of the methods. For more verbose returns, use `asResult()`,
but beware as it might expose unwanted data.
```php
$users = (new User())->select("*")->where("id > 10")->asArray();
```
Here are a list of useful methods to remember, most have their intended meaning as derived from normal `SQL`. All are optional,
but should be used in the order given here.

| Methods                             | Usage Notes                                                                                                                                                                                                                       |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| from("user")                        | If the from is omitted, it is taken as the object table, given the alias t, important to know when using joins.                                                                                                                   |
| join("role r")->on("t.id = r.id")   | Joining tables, beware the implied table alias if omitted the from clause will be t.                                                                                                                                              |
| leftJoin("role r")->on("t.id = r.id") | Standard left join, beware the implied table alias if omitted from the from clause will be t.                                                                                                                                     |                                                                                                                                    
| where("filterString", \[params])    | Simple means of filtering. Records filtered are not returned from the database.                                                                                                                                                   |
| groupBy("fields")                   | Fields grouped as per normal SQL rules                                                                                                                                                                                            |
| having("filterString")              | Filtering records based on the groupings. Records filtered are not returned from the database.                                                                                                                                    |
| filter(function($record){// your code here}) | Applies a method on each record. Filtering is done after required records are returned from the database. Use with care as this can be very inefficient. Useful to modify a returned record where database joins are unavailable. |
| orderBy("filterString")             | Ordering logic to sort returned records.                                                                                                                                                                                          |

A more complex example of the select concatenation
```php
$users = (new User())->select("*")
                    ->join("role r")->on("t.roleId = r.id")
                    ->where("r.id > ?", [2])
                    ->orderBy("t.id asc")
                    ->asObject(); 
```

## Create - Read - Update - Delete

The ORM object makes available a CRUD generator, which in a single line of code will generate the routes and screens for a fully functional CRUD mechanism.

[The details of how this works is on it's own page.](crud.md)


