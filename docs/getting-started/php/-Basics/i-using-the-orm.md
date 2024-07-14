# Using the ORM

The principal of ORM is to map a code based object or class to a database entity.
In most frameworks this effort is black-boxed and overcomplicated.  Essentially with Tina4's ORM we have tried to 
remove the complexity whilst retaining what one would expect from an ORM.

## Essentials

We assume that database conventions and fields are to be stored in a "snake case paradigm" whereas PHP expects "camel case" as a PSR standard when dealing with variables.  To this end we transform the database fields to the PHP paradigm so you don't need to worry about them.

Consider this code snippet:

```php
$car = (new \Tina4\ORM())('{"id": 1, "name": "BMW", "year": 2005}');
$car->tableName = "car";
$car->save(); // insert / update into a table called car
```

- we create an object from a JSON string (think form inputs and REST API)
- we set the table name
- we save the record to the database

The database engine would be defined by our `global $DBA`

Assuming we want to manipulate things a bit further, consider this:

```php
$car = (new \Tina4\ORM())('{"id": 1, "name": "BMW", "year": 2005}');
$car->table = "car"
$car->year = 2006;
$car->name = "Toyota";
$car->save(); // insert or update the record with the changed data
```

Let's say we want to select from the database

```php
$car = (new \Tina4\ORM())('{"id": 1, "name": "BMW", "year": 2005}');
$car->table = "car"

$cars = $car->select()->asArray(); //selects first 10 cars from the database

```

## Permanent ORM

If we want the Cars ORM to be permanent we can add a Class declaration in the `src/orm` folder.

**Car.php**
```php
<?php

class Car extends \Tina4\ORM
{
    public $primaryKey = "id";
    public $id;
    public $brandName; //becomes brand_name in the database
    public $year;
}

```

The table name is inferred from the class name, we can however set the `tableName` property if we want to change it.
Calling `save()` on an ORM object when there is no table in the database will create an exception and a migration file in the migration folder.
You can modify the migration to set the proper types you need before running it.

## Loading data

We can use the `load()` method to load information.

```php

$car = (new Car());
if ($car->load("id = ?", [1]) {
    print_r ($car);
}

```

## Saving data

We already saw how we populate an ORM object from a JSON request. There is another way you can load data by using the primary key.  The next example shows how to modify a record.

```php
$car = (new Car());
$car->id = 1;
$car->load();
$car->brandName = "BMW";
$car->save();
```

This example would be better written in this way:

```php
$car = (new Car());
$car->id = 1;
if ($car->load()) {
    $car->brandName = "BMW";
    if ($car->save()) {
        echo "Saved!";
    } else {
        echo "Failed to Save!";
    }
} else {
    echo "Failed to load";
}
```

## Creating CRUD router and user interface

The following code shows how to create a CRUD router for an ORM object.  The resulting code and landing pages can be incorporated into your system and should not be used as is for production purposes.

```php

(new Car())->generateCRUD("/api/cars");

```
Once you hit up the website or run the application a CRUD route will be created for you to use.  The CRUD router is described in detail in the advanced section.

Browse to here [http://127.0.0.1:7145/api/cars/landing](http://127.0.0.1:7145/api/cars/landing) to see the results.

## Selecting data using ORM

The ORM class can also be used to select data based on the table that is being modeled.
The following will select data from the `car` table.

```php
$cars =  (new Car())->select("*");
```

What if we wanted cars with features?  The filter method chained from the select method allows you to add variables to the main ORM class
if you want the data to be returned with its foreign keys.

```php
$cars =  (new Car())->select("*")->filter(function (Car $record){
                            $record->features = (new Feature())->select()
                                                ->where("car_id = ?", [$record->id]);
                        });

```

## Hot Tips
>- The `select` method on the ORM class is paginated, make sure your code accommodates this.
>- Checkout the `\Tina4\SQL()` class for more information about querying the database.
>- Use ? params to prevent SQL injection from request variables.
>- if you already have a database, use the `bin/tina4` command to create your ORM objects automatically.
>- The resulting crud router can be documented for swagger like any other route, see annotating api end points