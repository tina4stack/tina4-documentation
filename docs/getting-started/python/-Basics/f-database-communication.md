# Database Queries

!!! Note
    **All commands are transactional!** Don't forget to commit your transactions after executing SQL.

All the examples below require a database connection to work. The Database connection has the following methods you will use.
Use the examples below to see how we work with database data.



## table_exists (table_name)

```python

if not dba.table_exists("user"):
    dba.execute ("create table user (id integer default 0 not null, primary key(id))")

```

## get_next_id (table_name, column_name)

This method is useful to get the next integer value from an id field. Be warned about race conditions on high throughput tables, it would be preferred to make use of the built-in sequences for that database.
Our use here is primary for ORM.

```python
"""
Gets the next id using max method in sql for databases which don't have good sequences
:param str table_name: Name of the table
:param str column_name: Name of the column in that table to increment
:return: int : The next id in the sequence
"""
```

```python

id = dba.get_next_id ("user", "id")

```
## fetch (sql, params=[], limit=10, skip=0)

All data in Tina4 is paginated when we fetch it from the database to improve through put on large systems.  It is designed to work with most
front end tools and libraries that support pagination. Please do not add limit or top statements in the SQL as they are added automatically.

```python
"""
Fetch records based on a sql statement
:param str sql: A plan SQL statement or one with params in it designated by ?
:param list params: A list of params in order of precedence
:param int limit: Number of records to fetch
:param int skip: Offset of records to skip
:return: DatabaseResult
"""
```

```python title="example.py"
from . import dba

# returns 10 records from the first record in the table
records = dba.fetch("select * from user")

# return 10 records from the user table where the first_name is like John
records = dba.fetch("select * from user where first_name like ?", ["John%"])

# return 5 records from the user table
records = dba.fetch("select * from user", limit=5)

# return 5 records from the user table from the 3rd record
records = dba.fetch("select * from user", limit=5, skip=3)
```

## fetch_one (sql, params=[], skip=0)

Fetches a single record from the database based on the SQL query.  You have the ability to set the offset using the skip param.

```python
"""
Fetch a single record based on a sql statement, take note that BLOB and byte record data is converted into base64 automatically
:param str sql: A plan SQL statement or one with params in it designated by ?
:param list params: A list of params in order of precedence
:param int skip: Offset of records to skip
:return: dict : A dictionary containing the single record
"""
```

```python title="example.py"
from . import dba

user = dba.fetch_one("select * from user where email = ?", ["test@test.com"])

print(user["id"], user["email"])
```

## execute (sql, params=[])

Executes a single statement, if the statement contains a returning clause the returned values will be in the result.

```python
"""
Execute a query based on a sql statement
:param str sql: A plain SQL statement or one with params in it designated by ?
:param list params: A list of params in order of precedence
:return: DatabaseResult
"""
```

```python
from . import dba
if dba.table_exists("test_record"):
    result = dba.execute("drop table test_record")
    dba.commit()
    assert result.error is None
```

## execute_many (sql, params=[])

Executes a list of inputs multiple times against a single SQL statement.

```python
"""
Execute a query based on a single sql statement with a different number of params
:param sql: A plain SQL statement or one with params in it designated by ?
:param params: A list of params in order of precedence
:return: DatabaseResult
"""
```

```python
from . import dba

result = dba.execute_many("insert into test_record (id, name) values (?, ?)",
                          [[1, "Hello1"], [2, "Hello2"], [3, "Hello3"]])
dba.commit()
```


### insert (table_name, data, primary_key="id")

Inserts record or records into a table using the default primary key "id" without having to write SQL statements.

```python
"""
Insert data based on table name and data provided - single or multiple records
:param str table_name: Name of table
:param None data: List or Dictionary containing the data to be inserted
:param str primary_key: The name of the primary key of the table
"""
```

```python
from . import dba

# insert one record
result = dba.insert("test_record", {"id": 1, "name": "Test1"})
if result.error is None:    
    print(result)

# insert multiple records    
result = dba.insert("test_record", [{"id": 2, "name": "Test2"}, {"id": 3, "name": "Test2"}])
if result.error is None:
    print(result)    

```

### update (table_name, data, primary_key="id")

Updates a record or records using the default primary key "id" without having to write SQL statements.

```python
"""
Update data based on table name and record/primary key provided - single or multiple records
:param str table_name: Name of table
:param None data: List or Dictionary containing the data to be inserted
:param str primary_key: The name of the primary key of the table
"""
```

```python
from . import dba

result = dba.update("test_record", {"id": 1, "name": "Test1Update"})
if result is True:
    dba.commit()

# in this case the lists and dictionaries will be serialized to json before inserting them
result = dba.update("test_record", [{"id": 10, "name": {"id": 2}}, {"id": 11, "name": ["me1", "myself2", "I3"]}])

# we need to do a commit if we want the changes to stay
if result is True:
    dba.commit()
```

###  delete

