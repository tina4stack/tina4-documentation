# Database Connections

The database abstraction was designed to work with all basic Python database connections.
You need knowledge of which package to install then you can supply the connection string to get connected.

The following examples show how you would connect to specific database engines:

## Establishing a database connection

First you need to install the appropriate driver, this can be done using poetry or pip. In the case of SQlite3 it is already installed as part of the core Python.
All you need to do is make sure the sqlite3 module is installed and establish a database connection.


```python
# import sqlite3 , we don't need to import this ourselves as this will be done for us based on the connection string, we just need to make sure it is installed
from tina4_python.Database import Database

dba = Database("sqlite3:test.db")

```

## Connection construction

Tina4_python uses the following convention in creating a connection path

```
<driver-name>:<host>/<port>:<database-name>
```

### MySQL

For example if you would use mysql you would need to install the `mysql.connector` and then establish a database connection.

```bash
pip install mysql-connector-python
```

or 

```bash
poetry add mysql-connector-python
```

Somewhere in your code or preferably in the `__init__.py` file in src.

```python
from tina4_python.Database import Database

dba = Database("mysql.connector:localhost/3306:test", "root", "")
```

### Firebird
```bash
pip install firebird-driver
```
or

```bash
poetry add firebird-driver
```

```python
from tina4_python.Database import Database

dba = Database("firebird.driver:localhost/3050:/home/database/TEST.FDB", "SYSDBA", "masterkey")
```

### Other database engines

Theoretically you can simply install any database driver and use it by passing it into the connection string.  Let us know if there is a particular database engine you want us to test.

