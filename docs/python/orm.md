# Tina4-Python ORM – The Most Beautiful ORM You've Ever Seen
**This is not a 4ramework – this is love**

::: tip Hot Tips
- You **never** need the ORM — raw `Database` is perfect for 90% of cases
- But when you want it… it feels like writing plain Python classes
- Zero boilerplate — no `__init__`, no `save()` method to write
- Works with SQLite, PostgreSQL, MySQL, MSSQL, Firebird — all the same  
  :::

## Quick Start – 8 lines

```python
from tina4_python import orm, Database
from tina4_python.ORM import IntegerField, StringField, DateTimeField

class User(ORM):
    id         = IntegerField(primary_key=True, auto_increment=True)
    name       = StringField()
    email      = StringField(unique=True)
    created_at = DateTimeField(default=datetime.now)

# Connect once (usually in your main.py)
orm(Database("sqlite3:test.db"))

# That's it — table is auto-created on first use
user = User(name="Alice", email="alice@example.com")
user.save()                    # → INSERT
print(user.id)                 # → 1

user.name = "Alice Wonder"
user.save()                    # → UPDATE

found = User().load("email = ?", ["alice@example.com"])
print(found.name)              # → Alice Wonder
```

## Field Types

| Field Type               | Python type | SQL example                         | Notes                             |
|--------------------------|-------------|-------------------------------------|-----------------------------------|
| `IntegerField()`         | `int`       | `INTEGER`                           |                                   |
| `StringField()`          | `str`       | `VARCHAR(255)`                      | `length=500` optional             |
| `TextField()`            | `str`       | `TEXT`                              | unlimited                         |
| `DateTimeField()`        | `datetime`  | `TIMESTAMP`                         | auto `now()` on insert if wanted  |
| `BooleanField()`         | `bool`      | `BOOLEAN` / `TINYINT(1)`            |                                   |
| `NumericField()`         | `Decimal`   | `NUMERIC(10,2)`                     |                                   |
| `JSONBField()`           | `dict/list` | `JSON` / `JSONB`                    | auto serialize/deserialize        |
| `ForeignKeyField(...)`   | `int`       | `INTEGER REFERENCES table(id)`      | see below                         |

### Field Options

```python
name = StringField(
    default="Anonymous",
    null=False,
    length=100
)
created_at = DateTimeField(default=datetime.now)
is_active = BooleanField(default=True)
```

## Foreign Keys – Beautiful & Simple

```python
class Post(ORM):
    id        = IntegerField(primary_key=True, auto_increment=True)
    title     = StringField()
    author_id = ForeignKeyField(references=User)   # ← magic!
    author    = User()  # ← optional: auto-load relation
```

Usage:
```python
post = Post(title="Hello World")
post.author_id = 1
post.save()

# Or even better:
post.author = User().load("id = 1")
post.save()

# Load with relation
post = Post().load("id = ?", [1])
print(post.author.name)   # → Alice (auto-loaded!)
```

## Core Methods (all chainable)

| Method                 | Example                     | What it does                       |
|------------------------|-----------------------------|------------------------------------|
| `.save()`              | `user.save()`               | INSERT or UPDATE                   |
| `.load(where, params)` | `user.load("id = ?", [1])`  | Load single record based on filter |
| `.fetch()`             | `User().fetch()`            | Returns first 10 records           |
|  `.fetch_one()`        | `User().fetch_one()`        | Fetches one record                 |
| `.delete()`            | `user.delete()`             | Delete record                      |
| `.create_table()`      | `User().create_table()`     | Auto-create table (migrations too) |

## Migrations – One command

```python
from tina4_python.Migration import migrate

migrate(Database("sqlite3:test.db"))  # creates/updates all ORM tables
```

## Full Example – Real Project Ready

```python
from tina4_python import orm, Database
from tina4_python.ORM import *

orm(Database("sqlite3:app.db"))  # ← one line to rule them all

class Category(ORM):
    id   = IntegerField(primary_key=True, auto_increment=True)
    name = StringField(unique=True)

class Article(ORM):
    id         = IntegerField(primary_key=True, auto_increment=True)
    title      = StringField()
    content    = TextField()
    category   = ForeignKeyField(references=Category)
    author     = ForeignKeyField(references="User")
    created_at = DateTimeField(default=datetime.now)

# Auto-create tables
Category().create_table()
Article().create_table()

# Use it
cat = Category({"name": "Tech"})
cat.save()

article = Article({"title":"Tina4 is awesome", "content":..., "category":"cat", "author_id": 1})
article.save()

# Query
for a in Article().select(filter="category_name = ?", "Tech").records:
    print(a.title, "by", a.author.name) # still working on this
```

## Summary – The Tina4 ORM Philosophy

- **No `__init__` needed**
- **No `save()` method to write**
- **No migration files**
- **No sessions**
- **No query builder hell**

Just:

```python
user = User({"name":"Bob"})
user.save()

@post("/api/users")
async def post_api_users(request, response):
    
    user = User(request.body)
    user.save()
    
    return response(user.to_dict())    
    


```
