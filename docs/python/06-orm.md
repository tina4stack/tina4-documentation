# Chapter 6: ORM

## 1. From SQL to Objects

The last chapter was raw SQL. It works. It also gets repetitive. Every insert demands an INSERT statement. Every update demands an UPDATE. Every fetch maps column names to dictionary keys. Over and over.

Tina4's ORM turns database rows into Python objects. Define a model class with fields. The ORM writes the SQL. It stays SQL-first -- you can drop to raw SQL at any moment -- but for the 90% case of CRUD operations, the ORM handles the grunt work.

Picture a blog. Authors, posts, comments. Authors own many posts. Posts own many comments. Comments belong to posts. Modeling these relationships with raw SQL means JOINs and manual foreign key management. The ORM makes this declarative.

---

## ORM at a Glance: Four Languages, One Shape

The ORM does the same job in every Tina4 book. Define a model. Save it. Query it. Each language wears its own clothes — PHP uses typed properties, Python uses field class instances, Ruby uses a DSL, Node uses config objects — but the operations line up. If you know the API in one book, you can read the others.

### Defining a Model

The same `Post` model with `id`, `title`, `body`, and `created_at`:

**Python** — field class instances on the class body:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class Post(ORM):
    table_name = "posts"

    id = IntegerField(primary_key=True, auto_increment=True)
    title = StringField(required=True, max_length=200)
    body = StringField(default="")
    created_at = DateTimeField()
```

**PHP** — native typed properties:

```php
<?php
use Tina4\ORM;

class Post extends ORM
{
    public string $tableName = "posts";

    public int $id;
    public string $title;
    public string $body = "";
    public string $createdAt;
}
```

**Ruby** — class-level DSL declarations:

```ruby
class Post < Tina4::ORM
  table_name "posts"

  integer_field :id, primary_key: true, auto_increment: true
  string_field :title, nullable: false, length: 200
  string_field :body, default: ""
  datetime_field :created_at
end
```

**Node.js (TypeScript)** — config objects in a `static fields` block:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Post extends BaseModel {
  static tableName = "posts";
  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    title:     { type: "string"  as const, required: true, maxLength: 200 },
    body:      { type: "string"  as const, default: "" },
    createdAt: { type: "datetime" as const },
  };
}
```

### Common Query Operations

Same operation, four shapes:

| Operation | Python | PHP | Ruby | Node.js |
|---|---|---|---|---|
| Find by primary key | `Post.find_by_id(1)` | `Post::findById(1)` | `Post.find_by_id(1)` | `Post.findById(1)` |
| Filter by attributes | `Post.find({"title": "x"})` | `Post::find(["title" => "x"])` | `Post.find(title: "x")` | `Post.find({ title: "x" })` |
| Raw SQL where clause | `Post.where("title = ?", ["x"])` | `(new Post())->where("title = ?", ["x"])` | `Post.where("title = ?", ["x"])` | `Post.where("title = ?", ["x"])` |
| Build and save | `Post.create(title="x")` | `Post::create(["title" => "x"])` | `Post.create(title: "x")` | `Post.create({ title: "x" })` |
| Save an instance | `post.save()` | `$post->save()` | `post.save` | `post.save()` |
| Fetch every row | `Post.all()` | `(new Post())->all()` | `Post.all` | `Post.all()` |
| Delete a record | `post.delete()` | `$post->delete()` | `post.delete` | `post.delete()` |
| Count rows | `Post.count()` | `(new Post())->count()` | `Post.count` | `Post.count()` |

A few details worth noting. `find()` takes attribute names and applies the field map; `where()` takes raw SQL and skips translation. PHP needs `(new Post())` for instance methods like `where()` and `all()` — the rest are static. Ruby methods drop the parentheses by convention.

For full detail on field options, relationships, eager loading, soft delete, validation, and Auto-CRUD, read the rest of this chapter — it shows the API for the language of this book.

---

## 2. Defining a Model

Create a model file in `src/orm/`. Every `.py` file in that directory is auto-loaded.

Create `src/orm/note.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, BooleanField, DateTimeField

class Note(ORM):
    table_name = "notes"

    id = IntegerField(primary_key=True, auto_increment=True)
    title = StringField(required=True, max_length=200)
    content = StringField(default="")
    category = StringField(default="general")
    pinned = BooleanField(default=False)
    created_at = DateTimeField()
    updated_at = DateTimeField()
```

A complete model. Here is what each piece does:

- `table_name` -- the database table this model maps to. If omitted, the ORM uses the lowercase class name (e.g. `Contact` -> `contact`).
- `primary_key=True` on a field marks it as the primary key (defaults to `id` if none is specified)
- Each field is a class-level attribute with a field type

### Field Types

| Field Type | Python Type | SQL Type | Description |
|-----------|-------------|----------|-------------|
| `IntegerField` | `int` | `INTEGER` | Whole numbers |
| `StringField` | `str` | `VARCHAR(255)` | Text strings |
| `NumericField` | `float` | `REAL` | Decimal numbers |
| `BooleanField` | `bool` | `INTEGER` (0/1) | True/False |
| `DateTimeField` | `str` | `DATETIME` | Date and time |
| `TextField` | `str` | `TEXT` | Long text |
| `BlobField` | `bytes` | `BLOB` | Binary data |
| `ForeignKeyField` | `int` | `INTEGER` | Foreign key — auto-wires `belongs_to` and `has_many` (see [Relationships](#6-relationships)) |

Verbose names (`IntegerField`, `StringField`, `BooleanField`) are the standard. Short aliases (`IntField`, `StrField`, `BoolField`) also work.


### Field Options

| Option | Type | Description |
|--------|------|-------------|
| `primary_key` | `bool` | Marks this field as the primary key |
| `required` | `bool` | Field must have a value (not None) |
| `default` | any | Default value when not provided |
| `max_length` | `int` | Maximum string length |
| `min_length` | `int` | Minimum string length |
| `min_value` | number | Minimum numeric value |
| `max_value` | number | Maximum numeric value |
| `choices` | list | Allowed values |
| `auto_increment` | `bool` | Auto-incrementing integer |
| `regex` | `str` | Pattern the value must match |
| `validator` | callable | Custom validation function |

### Field Mapping

When your Python attribute names do not match the database column names, use `field_mapping` to define the translation. `field_mapping` is a dict that maps Python attribute names to DB column names.

```python
from tina4_python.orm import ORM, IntegerField, StringField

class User(ORM):
    table_name = "user_accounts"
    field_mapping = {
        "first_name": "fname",      # Python attr -> DB column
        "last_name": "lname",
        "email_address": "email",
    }

    id = IntegerField(primary_key=True, auto_increment=True)
    first_name = StringField(required=True)
    last_name = StringField(required=True)
    email_address = StringField(required=True)
```

With this mapping, `user.first_name` reads from and writes to the `fname` column. The ORM handles the conversion in both directions -- on `find_by_id()`, `save()`, `select()`, and `to_dict()`. This is useful with legacy databases or third-party schemas where you cannot rename the columns.

A common use case is Firebird or Oracle, which store column names in uppercase:

```python
from tina4_python.orm import ORM, Field, StringField

class Account(ORM):
    table_name = "ACCOUNTS"
    field_mapping = {
        "account_no":   "ACCOUNTNO",
        "store_name":   "STORENAME",
        "credit_limit": "CREDITLIMIT",
    }
    account_no   = StringField()
    store_name   = StringField()
    credit_limit = Field(float, default=0.0)
```

Python code uses clean snake_case names (`account.account_no`, `account.credit_limit`). The ORM maps them to the uppercase DB columns automatically.

### _get_db_column and _get_db_data

Two internal helpers make field_mapping available in custom code:

```python
# Get the DB column name for a Python attribute
col = account._get_db_column("account_no")   # "ACCOUNTNO"

# Get a dict of all fields using DB column names as keys
data = account._get_db_data()
# {"ACCOUNTNO": "A001", "STORENAME": "Main Store", "CREDITLIMIT": 5000.0}
```

These are mainly used internally by `save()` and `create_table()`, but are available if you need them in custom queries.

### find() vs where() -- naming convention

The two query methods have a deliberate difference in how they handle column names:

- **`find(filter_dict)`** uses **Python attribute names**. The ORM translates them via `field_mapping`.
- **`where(filter_sql)`** uses **raw DB column names** in the SQL string. No translation is done.

```python
# find() -- use Python attribute names
accounts = Account.find({"account_no": "A001"})   # translates to ACCOUNTNO = ?

# where() -- use DB column names directly in the SQL
accounts = Account.where("ACCOUNTNO = ?", ["A001"])  # raw SQL, no translation
```

This means `find()` is portable across database engines, while `where()` gives you full control of the SQL.

### auto_map and Case Conversion Utilities

The `auto_map` flag exists on the ORM base class for cross-language parity with the PHP and Node.js versions. In Python it is a no-op because Python convention already uses `snake_case`, which matches database column names.

For cases where you need to convert between naming conventions (for example, when serialising to a camelCase JSON API), two utility functions are available:

```python
from tina4_python.orm.model import snake_to_camel, camel_to_snake

snake_to_camel("first_name")   # "firstName"
camel_to_snake("firstName")    # "first_name"
```

---

## 3. create_table -- Schema from Models

You can create the database table directly from your model definition:

```python
Note.create_table()
```

This generates and runs the CREATE TABLE SQL based on your field definitions. It is good for development and testing. For production, use migrations (Chapter 5) for version-controlled schema changes.

```bash
tina4 shell
>>> from src.orm.note import Note
>>> Note.create_table()
```

---

## 4. CRUD Operations

### save -- Create or Update

```python
from tina4_python.core.router import post, put
from src.orm.note import Note

@post("/api/notes")
async def create_note(request, response):
    note = Note()
    note.title = request.body["title"]
    note.content = request.body.get("content", "")
    note.category = request.body.get("category", "general")
    note.pinned = request.body.get("pinned", False)
    note.save()

    return response({"message": "Note created", "note": note.to_dict()}, 201)
```

`save()` detects whether the record is new (INSERT) or existing (UPDATE) based on whether the primary key has a value. It returns `self` on success, so you can chain calls. It returns `False` on failure.

### create -- Build and Save in One Step

When you have a dict of data ready, `create()` builds the model and saves it in one call:

```python
note = Note.create({
    "title": "Quick Note",
    "content": "Created in one step",
    "category": "general"
})
```

You can also pass keyword arguments:

```python
note = Note.create(title="Quick Note", content="One step", category="general")
```

### find_by_id -- Fetch One Record by Primary Key

```python
from tina4_python.core.router import get
from src.orm.note import Note

@get("/api/notes/{id:int}")
async def get_note(id, request, response):
    note = Note.find_by_id(id)

    if note is None:
        return response({"error": "Note not found"}, 404)

    return response(note.to_dict())
```

`find_by_id()` takes a primary key value and returns a model instance, or `None` if no row matches. If soft delete is enabled, it excludes soft-deleted records.

Use `find_or_fail()` when you want a `ValueError` raised instead of `None`:

```python
note = Note.find_or_fail(id)  # Raises ValueError if not found
```

### find -- Query by Filter Dict

The `find()` method accepts a dictionary of column-value pairs and returns a list of matching records:

```python
# Find all notes in the "work" category
work_notes = Note.find({"category": "work"})

# Find with pagination and ordering
recent = Note.find({"pinned": True}, limit=10, order_by="created_at DESC")

# Find all records (no filter)
all_notes = Note.find()
```

### where -- Query with SQL Conditions

For more complex queries, `where()` takes a SQL WHERE clause with `?` placeholders:

```python
notes = Note.where("category = ?", ["work"])
```

### delete -- Remove a Record

```python
from tina4_python.core.router import delete as delete_route
from src.orm.note import Note

@delete_route("/api/notes/{id:int}")
async def delete_note(id, request, response):
    note = Note.find_by_id(id)

    if note is None:
        return response({"error": "Note not found"}, 404)

    note.delete()

    return response(None, 204)
```

### Listing Records

```python
@get("/api/notes")
async def list_notes(request, response):
    category = request.params.get("category")

    if category:
        notes = Note.where("category = ?", [category])
    else:
        notes = Note.all()

    return response({
        "notes": [note.to_dict() for note in notes],
        "count": len(notes)
    })
```

`where()` takes a WHERE clause with `?` placeholders and a list of parameters. It returns a list of model instances. `all()` fetches all records. Both support pagination:

```python
# With pagination
notes = Note.where("category = ?", ["work"], limit=20, offset=40)

# Fetch all with pagination
notes = Note.all(limit=20, offset=0)

# SQL-first query -- full control over the SQL
notes = Note.select(
    "SELECT * FROM notes WHERE pinned = ? ORDER BY created_at DESC",
    [1], limit=20, offset=0
)
```

### select_one -- Fetch a Single Record by SQL

When you need exactly one record from a custom SQL query:

```python
note = Note.select_one("SELECT * FROM notes WHERE slug = ?", ["my-note"])
```

Returns a model instance or `None`.

### load -- Populate an Existing Instance

The `load()` method fills an existing model instance from the database:

```python
note = Note()
note.id = 42
note.load()  # Loads data for id=42

# Or with a filter string
note = Note()
note.load("slug = ?", ["my-note"])
```

Returns `True` if a record was found, `False` otherwise.

### count -- Count Records

```python
total = Note.count()
work_count = Note.count("category = ?", ["work"])
```

Respects soft delete -- only counts non-deleted records.

---

## 5. to_dict, to_json, and Other Serialisation

### to_dict

Convert a model instance to a dictionary:

```python
note = Note.find_by_id(1)

data = note.to_dict()
# {"id": 1, "title": "Shopping List", "content": "Milk, eggs", "category": "personal", "pinned": False, "created_at": "2026-03-22 14:30:00", "updated_at": "2026-03-22 14:30:00"}
```

The `include` parameter adds relationship data to the output (see Eager Loading below). Pass a list of relationship names:

```python
# Include relationships in the dict
data = note.to_dict(include=["comments"])
```

### to_json

Convert directly to a JSON string:

```python
json_string = note.to_json()
# '{"id": 1, "title": "Shopping List", ...}'
```

### Other Serialisation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `to_dict(include=None)` | `dict` | Primary dict method with optional relationship includes |
| `to_assoc(include=None)` | `dict` | Alias for `to_dict()` |
| `to_object()` | `dict` | Alias for `to_dict()` |
| `to_json(include=None)` | `str` | JSON string |
| `to_array()` | `list` | Flat list of values (no keys) |
| `to_list()` | `list` | Alias for `to_array()` |

---

## 6. Relationships

Tina4 ORM supports three relationship types: `has_many`, `has_one`, and `belongs_to`. Each works in two styles:

- **Imperative**: call the method on an instance when you need a one-off lookup
- **Declarative**: define the relationship as a class attribute using descriptor functions — accessed as a simple attribute, lazy-loaded on first access

Both styles support eager loading via `include=["relationship_name"]`.

### ForeignKeyField — Auto-Wired Relationships

Declaring a column with `ForeignKeyField(to=OtherModel)` automatically wires both sides of the relationship. The declaring model gets a `belongs_to` accessor (the column name with `_id` stripped), and the referenced model gets a `has_many` accessor (the declaring class name lowercased with `s` appended, or whatever you pass via `related_name=`).

```python
from tina4_python.orm import ORM, IntegerField, StringField, ForeignKeyField

class Author(ORM):
    table_name = "authors"
    id = IntegerField(primary_key=True, auto_increment=True)
    name = StringField(required=True)

class BlogPost(ORM):
    table_name = "posts"
    id = IntegerField(primary_key=True, auto_increment=True)
    title = StringField(required=True)
    author_id = ForeignKeyField(to=Author, related_name="posts")
```

With that single `ForeignKeyField` declaration, two accessors are auto-wired:

- `post.author` — returns the `Author` instance (belongs_to)
- `author.posts` — returns a list of `BlogPost` instances (has_many)

No manual `has_many` or `belongs_to` calls required.

```python
post = BlogPost.find_by_id(1)
print(post.author.name)         # "Alice"

author = Author.find_by_id(1)
for p in author.posts:
    print(p.title)
```

### has_many

An author has many posts:

Create `src/orm/author.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class Author(ORM):
    table_name = "authors"

    id = IntegerField(primary_key=True, auto_increment=True)
    name = StringField(required=True)
    email = StringField(required=True)
    bio = StringField(default="")
    created_at = DateTimeField()
```

Create `src/orm/blog_post.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class BlogPost(ORM):
    table_name = "posts"

    id = IntegerField(primary_key=True, auto_increment=True)
    author_id = IntegerField(required=True)
    title = StringField(required=True, max_length=300)
    slug = StringField(required=True)
    content = StringField(default="")
    status = StringField(default="draft", choices=["draft", "published", "archived"])
    created_at = DateTimeField()
    updated_at = DateTimeField()
```

Now use `has_many` to get an author's posts:

```python
@get("/api/authors/{id:int}")
async def get_author(id, request, response):
    author = Author.find_by_id(id)

    if author is None:
        return response({"error": "Author not found"}, 404)

    posts = author.has_many(BlogPost, "author_id")

    data = author.to_dict()
    data["posts"] = [post.to_dict() for post in posts]

    return response(data)
```

```json
{
  "id": 1,
  "name": "Alice",
  "email": "alice@example.com",
  "bio": "Tech writer",
  "posts": [
    {"id": 1, "title": "Getting Started with Tina4", "slug": "getting-started", "status": "published"},
    {"id": 2, "title": "Advanced Routing", "slug": "advanced-routing", "status": "draft"}
  ]
}
```

### has_one

A user has one profile:

```python
profile = user.has_one(Profile, "user_id")
```

Returns a single model instance or `None`.

### belongs_to

A post belongs to an author:

```python
@get("/api/posts/{id:int}")
async def get_post(id, request, response):
    post = BlogPost.find_by_id(id)

    if post is None:
        return response({"error": "Post not found"}, 404)

    author = post.belongs_to(Author, "author_id")

    data = post.to_dict()
    data["author"] = author.to_dict() if author else None

    return response(data)
```

```json
{
  "id": 1,
  "author_id": 1,
  "title": "Getting Started with Tina4",
  "slug": "getting-started",
  "content": "...",
  "status": "published",
  "author": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com"
  }
}
```

---

## 7. Eager Loading

Calling relationship methods inside a loop creates the N+1 problem. Load 10 authors. Call `has_many(BlogPost, "author_id")` for each one. That fires 11 queries -- 1 for authors, 10 for posts. The page drags.

The `include` parameter on `all()`, `where()`, `find_by_id()`, and `select()` solves this. It eager-loads relationships in bulk:

```python
@get("/api/authors")
async def list_authors(request, response):
    # Pass a list of relationship names — ORM batch-loads all posts in 2 queries total
    authors = Author.all(include=["posts"])

    data = []
    for author in authors:
        author_dict = author.to_dict(include=["posts"])
        data.append(author_dict)

    return response({"authors": data})
```

Without eager loading, 10 authors and their posts cost 11 queries. With eager loading: 2 queries. That is the difference between a fast page and a slow one.

### Declarative Relationships with Descriptors

The imperative `has_many()`, `has_one()`, and `belongs_to()` methods called on instances work for one-off lookups. For models where relationships are always needed, declare them as class attributes using the descriptor functions imported from `tina4_python.orm`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField
from tina4_python.orm import has_many, has_one, belongs_to

class Author(ORM):
    table_name = "authors"

    id    = IntegerField(primary_key=True, auto_increment=True)
    name  = StringField(required=True)
    email = StringField(required=True)

    # Declare the relationship once on the class
    posts = has_many("BlogPost", foreign_key="author_id")


class BlogPost(ORM):
    table_name = "posts"

    id        = IntegerField(primary_key=True, auto_increment=True)
    author_id = IntegerField(required=True)
    title     = StringField(required=True)

    # Lazy-load the parent author
    author   = belongs_to("Author", foreign_key="author_id")
    # Lazy-load comments
    comments = has_many("Comment", foreign_key="post_id")
```

With declarative descriptors, accessing the relationship is a simple attribute read:

```python
author = Author.find_by_id(1)
for post in author.posts:          # lazy-loads on first access
    print(post.title)

post = BlogPost.find_by_id(10)
print(post.author.name)            # lazy-loads the related Author
```

Eager loading works through the `include` parameter. Pass a list of relationship names:

```python
# Eager load posts when fetching all authors
authors = Author.all(include=["posts"])

# Eager load author and comments when finding a single post
post = BlogPost.find_by_id(1, include=["author", "comments"])
```

### Nested Eager Loading

Dot notation loads multiple levels deep:

```python
# Load authors, their posts, and each post's comments
authors = Author.all(include=["posts", "posts.comments"])
```

Authors, their posts, and each post's comments. Three queries total instead of hundreds.

### to_dict with Nested Includes

When eager loading is active, `to_dict(include=...)` embeds the related data:

```python
post = BlogPost.find_by_id(1, include=["author", "comments"])
data = post.to_dict(include=["author", "comments"])
```

```json
{
  "id": 1,
  "title": "Getting Started with Tina4",
  "author": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com"
  },
  "comments": [
    {"id": 1, "body": "Great post!", "author_name": "Bob"}
  ]
}
```

---

## 8. Soft Delete

Sometimes a record needs to disappear from queries without leaving the database. Soft delete handles this. The row stays. A flag marks it as deleted. Queries skip it.

```python
from tina4_python.orm import ORM, IntegerField, StringField, BooleanField

class Task(ORM):
    table_name = "tasks"
    soft_delete = True  # Enable soft delete

    id = IntegerField(primary_key=True, auto_increment=True)
    title = StringField(required=True)
    completed = BooleanField(default=False)
    is_deleted = IntegerField(default=0)  # Required for soft delete (0 = active, 1 = deleted)
    created_at = StringField()
```

When `soft_delete = True`, the ORM changes its behaviour:

- `task.delete()` sets `is_deleted` to `1` instead of running a DELETE query
- `Task.all()`, `Task.where()`, and `Task.find_by_id()` filter out records where `is_deleted = 1`
- `task.restore()` sets `is_deleted` back to `0` and makes the record visible again
- `task.force_delete()` permanently removes the row from the database
- `Task.with_trashed()` includes soft-deleted records in query results

### Deleting and Restoring

```python
# Soft delete -- sets is_deleted = 1, row stays in the database
task = Task.find_by_id(1)
task.delete()

# Restore -- sets is_deleted = 0, record is visible again
task.restore()

# Permanently delete -- removes the row, no recovery possible
task.force_delete()
```

`restore()` is the inverse of `delete()`. It sets `is_deleted` back to `0` and commits the change. The record reappears in all standard queries.

### Including Soft-Deleted Records

Standard queries (`all()`, `where()`, `find_by_id()`) exclude soft-deleted records. When you need to see everything -- for admin dashboards, audit logs, or data recovery -- use `with_trashed()`:

```python
# All tasks, including soft-deleted ones
all_tasks = Task.with_trashed()

# Soft-deleted tasks matching a condition
deleted_tasks = Task.with_trashed("completed = ?", [1])
```

`with_trashed()` accepts the same filter parameters as `where()`. The only difference: it ignores the `is_deleted` filter that standard queries apply.

### Counting with Soft Delete

The `count()` class method respects soft delete. It only counts non-deleted records:

```python
active_count = Task.count()
active_work = Task.count("category = ?", ["work"])
```

### When to Use Soft Delete

Soft delete suits data that users might want to recover -- emails, documents, user accounts. It also serves audit requirements where regulations demand retention. For temporary data (sessions, cache entries, logs), hard delete keeps the table lean.

---

## 9. Auto-CRUD

Writing the same five REST endpoints for every model gets tedious. Auto-CRUD generates them from your model class. Define the model. Register it. Five routes appear.

### The auto_crud Flag

The simplest approach -- set `auto_crud = True` on your model class:

```python
class Note(ORM):
    table_name = "notes"
    auto_crud = True  # Generates REST endpoints automatically

    id = IntegerField(primary_key=True, auto_increment=True)
    title = StringField(required=True)
    content = StringField(default="")
```

The moment Python loads this class, the ORM metaclass detects `auto_crud = True` and registers it with `AutoCrud`. Five routes appear at `/api/notes` with no additional code.

Here is a more complete example with a `Product` model:

```python
from tina4_python.orm import ORM, Field, IntegerField, StringField

class Product(ORM):
    table_name = "products"
    auto_crud  = True   # registers /api/products routes automatically

    id    = IntegerField(primary_key=True, auto_increment=True)
    name  = StringField(required=True)
    price = Field(float, default=0.0)
```

This registers five endpoints at `/api/products` with no route files needed.

### Manual Registration

You can also register models explicitly using `AutoCrud.register()`:

```python
from tina4_python.crud import AutoCrud
from src.orm.note import Note

AutoCrud.register(Note)
```

Both approaches produce the same result:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all with pagination (`limit`, `offset` params) |
| `GET` | `/api/notes/{id}` | Get one by primary key |
| `POST` | `/api/notes` | Create a new record |
| `PUT` | `/api/notes/{id}` | Update a record |
| `DELETE` | `/api/notes/{id}` | Delete a record |

The endpoint prefix derives from the table name. The `notes` table becomes `/api/notes`. Pass a custom prefix to change it:

```python
AutoCrud.register(Note, prefix="/api/v2")
# Routes: /api/v2/notes, /api/v2/notes/{id}, etc.
```

### Auto-Discovering Models

Rather than registering each model by hand, point `AutoCrud.discover()` at your models directory. It scans every `.py` file, finds ORM subclasses, and registers them all:

```python
from tina4_python.crud import AutoCrud

AutoCrud.discover("src/orm", prefix="/api")
```

Every ORM model in `src/orm/` gets five REST endpoints. No route files needed.

### What the Generated Routes Do

**GET /api/notes** returns paginated results:

```bash
curl "http://localhost:7146/api/notes?limit=10&offset=0"
```

```json
{
  "data": [
    {"id": 1, "title": "Shopping List", "content": "Milk, eggs", "category": "personal", "pinned": false},
    {"id": 2, "title": "Sprint Plan", "content": "Review backlog", "category": "work", "pinned": true}
  ],
  "total": 2,
  "limit": 10,
  "offset": 0
}
```

**POST /api/notes** validates input before saving:

```bash
curl -X POST http://localhost:7146/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "New Note", "content": "Created via auto-CRUD"}'
```

If validation fails (for example, a required field is missing), the endpoint returns a 400 with error details:

```json
{"error": "Validation failed", "detail": ["title: This field is required"]}
```

**DELETE /api/notes/1** respects soft delete. If the model has `soft_delete = True`, the record is marked deleted instead of removed.

### Custom Routes Alongside Auto-CRUD

Custom routes defined in `src/routes/` load before auto-CRUD routes. They take precedence. If you need special logic for one endpoint (custom validation, side effects, complex queries), define that route manually. Auto-CRUD handles the rest.

### Introspection

Check which models are registered:

```python
registered = AutoCrud.models()
# {"notes": <class 'Note'>, "users": <class 'User'>}
```

---

## 10. Cached Queries

For expensive queries that don't change often, `cached()` caches the results in memory with a TTL:

```python
# Cache for 60 seconds
popular = Note.cached(
    "SELECT * FROM notes WHERE pinned = ? ORDER BY created_at DESC",
    [True], ttl=60, limit=20
)
```

Clear the cache when data changes:

```python
Note.clear_cache()
```

---

## 11. Scopes

Scopes are reusable query filters baked into the model:

```python
class BlogPost(ORM):
    table_name = "posts"

    id = IntegerField(primary_key=True, auto_increment=True)
    title = StringField(required=True)
    status = StringField(default="draft")
    created_at = DateTimeField()

    @classmethod
    def published(cls):
        return cls.where("status = ?", ["published"])

    @classmethod
    def drafts(cls):
        return cls.where("status = ?", ["draft"])

    @classmethod
    def recent(cls, days=7):
        return cls.where(
            "created_at > datetime('now', ?)",
            [f"-{days} days"]
        )
```

Use them in your routes:

```python
@get("/api/posts/published")
async def published_posts(request, response):
    posts = BlogPost.published()
    return response({"posts": [p.to_dict() for p in posts]})

@get("/api/posts/recent")
async def recent_posts(request, response):
    days = int(request.params.get("days", 7))
    posts = BlogPost.recent(days)
    return response({"posts": [p.to_dict() for p in posts]})
```

You can also register scopes dynamically with the `scope()` class method:

```python
BlogPost.scope("active", "status != ?", ["archived"])

# Now call it:
active_posts = BlogPost.active()
```

Scopes keep query logic in the model where it belongs. Route handlers stay thin.

---

## 12. Input Validation

Field definitions carry validation rules. Call `validate()` before `save()` and the ORM checks every constraint:

```python
from tina4_python.orm import ORM, IntegerField, StringField, NumericField

class Product(ORM):
    table_name = "products"

    id = IntegerField(primary_key=True, auto_increment=True)
    name = StringField(required=True, min_length=2, max_length=200)
    sku = StringField(required=True, regex=r"^[A-Z]{2}-\d{4}$")  # e.g., EL-1234
    price = NumericField(required=True, min_value=0.01, max_value=999999.99)
    category = StringField(choices=["Electronics", "Kitchen", "Office", "Fitness"])
```

```python
@post("/api/products")
async def create_product(request, response):
    product = Product()
    product.name = request.body.get("name")
    product.sku = request.body.get("sku")
    product.price = request.body.get("price")
    product.category = request.body.get("category")

    errors = product.validate()
    if errors:
        return response({"errors": errors}, 400)

    product.save()
    return response({"product": product.to_dict()}, 201)
```

If validation fails, `validate()` returns a list of error messages:

```json
{
  "errors": [
    "name: Must be at least 2 characters",
    "sku: Must match pattern ^[A-Z]{2}-\\d{4}$",
    "price: Must be at least 0.01",
    "category: Must be one of: Electronics, Kitchen, Office, Fitness"
  ]
}
```

---

## 13. Exercise: Build a Blog with Relationships

Build a blog API with authors, posts, and comments.

### Requirements

1. Create these models:

**Author:** `id`, `name` (required), `email` (required), `bio`, `created_at`

**Post:** `id`, `author_id` (integer foreign key), `title` (required, max 300), `slug` (required), `content`, `status` (choices: draft/published/archived, default draft), `created_at`, `updated_at`

**Comment:** `id`, `post_id` (integer foreign key), `author_name` (required), `author_email` (required), `body` (required, min 5 chars), `created_at`

2. Build these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/authors` | Create an author |
| `GET` | `/api/authors/{id:int}` | Get author with their posts |
| `POST` | `/api/posts` | Create a post (requires author_id) |
| `GET` | `/api/posts` | List published posts with author info |
| `GET` | `/api/posts/{id:int}` | Get post with author and comments |
| `POST` | `/api/posts/{id:int}/comments` | Add comment to a post |

---

## 14. Solution

Create `src/orm/author.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class Author(ORM):
    table_name = "authors"

    id = IntegerField(primary_key=True, auto_increment=True)
    name = StringField(required=True, min_length=2)
    email = StringField(required=True)
    bio = StringField(default="")
    created_at = DateTimeField()
```

Create `src/orm/blog_post.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class BlogPost(ORM):
    table_name = "posts"

    id = IntegerField(primary_key=True, auto_increment=True)
    author_id = IntegerField(required=True)
    title = StringField(required=True, max_length=300)
    slug = StringField(required=True)
    content = StringField(default="")
    status = StringField(default="draft", choices=["draft", "published", "archived"])
    created_at = DateTimeField()
    updated_at = DateTimeField()

    @classmethod
    def published(cls):
        return cls.where("status = ?", ["published"])
```

Create `src/orm/comment.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class Comment(ORM):
    table_name = "comments"

    id = IntegerField(primary_key=True, auto_increment=True)
    post_id = IntegerField(required=True)
    author_name = StringField(required=True)
    author_email = StringField(required=True)
    body = StringField(required=True, min_length=5)
    created_at = DateTimeField()
```

Create `src/routes/blog.py`:

```python
from tina4_python.core.router import get, post
from src.orm.author import Author
from src.orm.blog_post import BlogPost
from src.orm.comment import Comment


@post("/api/authors")
async def create_author(request, response):
    author = Author()
    author.name = request.body.get("name")
    author.email = request.body.get("email")
    author.bio = request.body.get("bio", "")

    errors = author.validate()
    if errors:
        return response({"errors": errors}, 400)

    author.save()
    return response({"author": author.to_dict()}, 201)


@get("/api/authors/{id:int}")
async def get_author(id, request, response):
    author = Author.find_by_id(id)

    if author is None:
        return response({"error": "Author not found"}, 404)

    posts = BlogPost.where("author_id = ?", [author.id])

    data = author.to_dict()
    data["posts"] = [p.to_dict() for p in posts]

    return response(data)


@post("/api/posts")
async def create_post(request, response):
    body = request.body

    # Verify author exists
    author = Author.find_by_id(body.get("author_id"))
    if author is None:
        return response({"error": "Author not found"}, 404)

    blog_post = BlogPost()
    blog_post.author_id = body["author_id"]
    blog_post.title = body.get("title")
    blog_post.slug = body.get("slug")
    blog_post.content = body.get("content", "")
    blog_post.status = body.get("status", "draft")

    errors = blog_post.validate()
    if errors:
        return response({"errors": errors}, 400)

    blog_post.save()
    return response({"post": blog_post.to_dict()}, 201)


@get("/api/posts")
async def list_posts(request, response):
    posts = BlogPost.published()
    data = []

    for p in posts:
        post_dict = p.to_dict()
        author = p.belongs_to(Author, "author_id")
        post_dict["author"] = author.to_dict() if author else None
        data.append(post_dict)

    return response({"posts": data, "count": len(data)})


@get("/api/posts/{id:int}")
async def get_post(id, request, response):
    blog_post = BlogPost.find_by_id(id)

    if blog_post is None:
        return response({"error": "Post not found"}, 404)

    author = blog_post.belongs_to(Author, "author_id")
    comments = blog_post.has_many(Comment, "post_id")

    data = blog_post.to_dict()
    data["author"] = author.to_dict() if author else None
    data["comments"] = [c.to_dict() for c in comments]
    data["comment_count"] = len(comments)

    return response(data)


@post("/api/posts/{id:int}/comments")
async def add_comment(id, request, response):
    blog_post = BlogPost.find_by_id(id)

    if blog_post is None:
        return response({"error": "Post not found"}, 404)

    comment = Comment()
    comment.post_id = id
    comment.author_name = request.body.get("author_name")
    comment.author_email = request.body.get("author_email")
    comment.body = request.body.get("body")

    errors = comment.validate()
    if errors:
        return response({"errors": errors}, 400)

    comment.save()
    return response({"comment": comment.to_dict()}, 201)
```

---

## 15. Gotchas

### 1. Forgetting to call save()

**Problem:** You set properties on a model but the database does not change.

**Cause:** Setting `note.title = "New Title"` only changes the Python object. The database remains unchanged until you call `note.save()`.

**Fix:** Call `save()` after modifying properties. Check the return value -- `save()` returns `self` on success and `False` on failure.

### 2. find_by_id() returns None

**Problem:** You call `Note.find_by_id(id)` but get `None` instead of a note object.

**Cause:** `find_by_id()` returns `None` when no row matches the given primary key. If soft delete is enabled, `find_by_id()` also excludes soft-deleted records.

**Fix:** Check for `None` after `find_by_id()`: `if note is None: return 404`. Use `find_or_fail()` if you want a `ValueError` raised instead.

### 3. find() vs find_by_id()

**Problem:** You call `Note.find(42)` expecting a single record, but get unexpected results.

**Cause:** `find()` takes a dict filter (`find({"id": 42})`), not a bare primary key value. For single-record lookups by primary key, use `find_by_id(42)`.

**Fix:** Use `find_by_id(id)` for primary key lookups. Use `find({"column": value})` for filter-based queries.

### 4. Circular imports with relationships

**Problem:** `from src.orm.post import BlogPost` in `author.py` and `from src.orm.author import Author` in `post.py` causes an `ImportError`.

**Cause:** Python cannot handle circular imports at module level.

**Fix:** Import inside the method that uses the relationship, not at the top of the file. Or pass the model class as a parameter in the route handler where you use both models.

### 5. to_dict() includes everything

**Problem:** `user.to_dict()` includes `password_hash` in the API response.

**Cause:** `to_dict()` includes all fields by default.

**Fix:** Build the response dict manually, omitting sensitive fields: `{"id": user.id, "name": user.name, "email": user.email}`. Or create a helper method on your model class that returns only safe fields.

### 6. Validation only runs on validate()

**Problem:** You call `save()` without calling `validate()` first, and invalid data gets into the database.

**Cause:** `save()` does not validate. This is by design -- sometimes you need to save partial data or bypass validation for bulk operations.

**Fix:** Call `errors = model.validate()` before `save()` in your route handlers. Or create a helper method that validates and saves in one step.

### 7. Foreign key not enforced

**Problem:** You save a post with `author_id = 999` and it succeeds, even though no author with ID 999 exists.

**Cause:** SQLite does not enforce foreign key constraints by default. The ORM defines the relationship through `has_many`/`belongs_to` methods, but the database itself may not enforce it.

**Fix:** Enable SQLite foreign keys with `PRAGMA foreign_keys = ON;` in a migration, or validate the foreign key in your route handler before saving.

### 8. N+1 query problem

**Problem:** Listing 100 authors with their posts runs 101 queries (1 for authors + 100 for posts), and the page loads slowly.

**Cause:** You call `author.has_many(BlogPost, "author_id")` inside a loop for each author.

**Fix:** Use eager loading with the `include` parameter on `all()`, `where()`, or `select()`. Or fetch all posts in a single query and group them manually:

```python
authors = Author.all()
all_posts = BlogPost.select(
    "SELECT * FROM posts WHERE author_id IN (" + ",".join(str(a.id) for a in authors) + ")"
)
posts_by_author = {}
for post in all_posts:
    posts_by_author.setdefault(post.author_id, []).append(post)
```

### 9. Auto-CRUD endpoint conflicts

**Problem:** Custom route at `/api/notes/{id}` stops working after registering Auto-CRUD for the Note model.

**Cause:** Both routes match the same path. The first registered route wins.

**Fix:** Custom routes in `src/routes/` load before Auto-CRUD routes. They take precedence. If you want different behaviour, use a different path for the custom route.

### 10. Soft-deleted records appearing in queries

**Problem:** You soft-deleted a record, but queries still return it.

**Cause:** Soft delete requires the `soft_delete = True` flag on the model class and an `is_deleted = IntegerField(default=0)` field. Without both, soft delete is inactive.

**Fix:** Verify both the `soft_delete = True` flag and the `is_deleted = IntegerField(default=0)` field exist on the model. The column stores `0` for active records and `1` for deleted ones.

---

## QueryBuilder Integration

ORM models provide a `query()` class method that returns a `QueryBuilder` pre-configured with the model's table name and database connection. This gives you a fluent API for building complex queries without writing raw SQL:

```python
# Fluent query builder from ORM
results = User.query() \
    .select("id", "name", "email") \
    .where("active = ?", [True]) \
    .order_by("name") \
    .limit(50) \
    .get()

# First matching record
user = User.query() \
    .where("email = ?", ["alice@example.com"]) \
    .first()

# Count
total = User.query() \
    .where("role = ?", ["admin"]) \
    .count()

# Check existence
exists = User.query() \
    .where("email = ?", ["test@example.com"]) \
    .exists()
```

See the [QueryBuilder chapter](07-query-builder.md) for the full fluent API including joins, grouping, having, and MongoDB support.
