# Database interactions

All the examples below require a database connection to work. The Database connection has the following methods you will use.

## Examples

Use the examples below to see how we work with database data.

### table_exists

```python

if not dba.table_exists("user"):
    dba.execute ("create table user (id integer default 0 not null, primary key(id))")

```

### get_next_id

This method is useful to get the next integer value from an id field.

```python

id = dba.get_next_id ("user", "id")

```
### fetch

All data in Tina4 is paginated when we fetch it from the database to improve through put on large systems.  It is designed to work with most
front end tools and libraries that support pagination.

```python
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

### fetch_one
- execute
- execute_many
- insert
- update
- delete

## 
