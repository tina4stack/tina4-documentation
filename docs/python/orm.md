# Tina4-Python ORM 

::: tip 🔥 Hot Tips
- You **never** need the ORM — raw `Database` is perfect for 90% of cases
- But when you want it… it feels like writing plain Python classes
- Zero boilerplate — no `__init__`, no `save()` method to write
- Works with SQLite, PostgreSQL, MySQL, MSSQL, Firebird — all the same  
  :::

## Quick Start – 8 lines

```python
from tina4_python import ORM, orm, Database
from tina4_python import IntegerField, StringField, DateTimeField

class User(ORM):
    id         = IntegerField(primary_key=True, auto_increment=True)
    name       = StringField()
    email      = StringField(unique=True)
    created_at = DateTimeField()

# Connect once (usually in your main.py)
orm(Database("sqlite3:test.db"))

# That's it — table is auto-created on first use
user = User({"name": "Alice", "email": "alice@example.com"})
user.save()                    # → INSERT
print(user.id)                 # → 1

user.name = "Alice Wonder"
user.save()                    # → UPDATE

user = User()
user.load("email = ?", ["alice@example.com"])
print(user.name)               # → Alice Wonder
```

## Field Types

| Field Type               | Python type | SQL example                         | Notes                             |
|--------------------------|-------------|-------------------------------------|-----------------------------------|
| `IntegerField()`         | `int`       | `INTEGER`                           |                                   |
| `StringField()`          | `str`       | `VARCHAR(255)`                      | `length=500` optional             |
| `TextField()`            | `str`       | `TEXT`                              | unlimited                         |
| `DateTimeField()`        | `datetime`  | `TIMESTAMP`                         |                                   |
| `NumericField()`         | `Decimal`   | `NUMERIC(10,2)`                     |                                   |
| `BlobField()`            | `bytes`     | `BLOB`                              |                                   |
| `JSONBField()`           | `dict/list` | `JSON` / `JSONB`                    | auto serialize/deserialize        |
| `ForeignKeyField(...)`   | `int`       | `INTEGER REFERENCES table(id)`      | import from `tina4_python.FieldTypes` |

### Field Options

```python
name = StringField(
    default="Anonymous",
    null=False,
    length=100
)
created_at = DateTimeField()
status = IntegerField(default=1)
```

## Foreign Keys – Beautiful & Simple

```python
from tina4_python.FieldTypes import ForeignKeyField

class Post(ORM):
    id        = IntegerField(primary_key=True, auto_increment=True)
    title     = StringField()
    author_id = ForeignKeyField(references=User)
```

Usage:
```python
post = Post({"title": "Hello World", "author_id": 1})
post.save()

# Load
post = Post()
post.load("id = ?", [1])
print(post.title)
```

## Core Methods

| Method                 | Example                     | What it does                       | Returns          |
|------------------------|-----------------------------|------------------------------------|------------------|
| `.save()`              | `user.save()`               | INSERT or UPDATE                   |                  |
| `.load(where, params)` | `user.load("id = ?", [1])`  | Load single record into instance   | `bool`           |
| `.select()` / `.fetch()` | `User().select()`         | Returns records (default limit 10) | `DatabaseResult` |
| `.fetch_one()`         | `User().fetch_one()`        | Fetches one record                 | `DatabaseResult` |
| `.delete()`            | `user.delete()`             | Delete record                      |                  |
| `.create_table()`      | `User().create_table()`     | Auto-create table                  |                  |
| `.to_dict()`           | `user.to_dict()`            | Convert instance to dict           | `dict`           |

## Migrations – One command

```python
from tina4_python.Migration import migrate

migrate(Database("sqlite3:test.db"))  # creates/updates all ORM tables
```

## Full Example – Real Project Ready

```python
from tina4_python import ORM, orm, Database
from tina4_python import IntegerField, StringField, TextField, DateTimeField
from tina4_python.FieldTypes import ForeignKeyField

orm(Database("sqlite3:app.db"))  # ← one line to rule them all

class Category(ORM):
    id   = IntegerField(primary_key=True, auto_increment=True)
    name = StringField(unique=True)

class Article(ORM):
    id          = IntegerField(primary_key=True, auto_increment=True)
    title       = StringField()
    content     = TextField()
    category_id = ForeignKeyField(references=Category)
    created_at  = DateTimeField()

# Auto-create tables
Category().create_table()
Article().create_table()

# Use it
cat = Category({"name": "Tech"})
cat.save()

article = Article({"title": "Tina4 is awesome", "content": "Great framework", "category_id": 1})
article.save()

# Query
result = Article().select(filter="category_id = ?", params=[1])
for a in result.records:
    print(a["title"])
```

## Summary – The Tina4 ORM Philosophy

- **No `__init__` needed**
- **No `save()` method to write**
- **No migration files**
- **No sessions**
- **No query builder hell**

Just:

```python
user = User({"name": "Bob"})
user.save()

@post("/api/users")
async def post_api_users(request, response):
    user = User(request.body)
    user.save()
    return response(user.to_dict())
```
