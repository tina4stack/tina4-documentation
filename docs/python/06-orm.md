# Chapter 6: ORM

## 1. From SQL to Objects

The last chapter was raw SQL. It works. It also gets repetitive. Every insert demands an INSERT statement. Every update demands an UPDATE. Every fetch maps column names to dictionary keys. Over and over.

Tina4's ORM turns database rows into Python objects. Define a model class with fields. The ORM writes the SQL. It stays SQL-first -- you can drop to raw SQL at any moment -- but for the 90% case of CRUD operations, the ORM handles the grunt work.

Picture a blog. Authors, posts, comments. Authors own many posts. Posts own many comments. Comments belong to posts. Modeling these relationships with raw SQL means JOINs and manual foreign key management. The ORM makes this declarative.

---

## 2. Defining a Model

Create a model file in `src/orm/`. Every `.py` file in that directory is auto-loaded.

Create `src/orm/note.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, BooleanField, DateTimeField

class Note(ORM):
    table_name = "notes"
    primary_key = "id"

    id = IntegerField(auto_increment=True)
    title = StringField(required=True, max_length=200)
    content = StringField(default="")
    category = StringField(default="general")
    pinned = BooleanField(default=False)
    created_at = DateTimeField(auto_now_add=True)
    updated_at = DateTimeField(auto_now=True)
```

A complete model. Here is what each piece does:

- `table_name` -- the database table this model maps to. If omitted, the ORM uses the lowercase class name plus `"s"` (e.g. `Contact` → `contacts`, `Product` → `products`). Always set it explicitly to avoid surprises.
- `primary_key` -- the primary key column (defaults to `"id"`)
- Each field is a class-level attribute with a field type

### Field Types

| Field Type | Python Type | SQL Type | Description |
|-----------|-------------|----------|-------------|
| `IntegerField` | `int` | `INTEGER` | Whole numbers |
| `StringField` | `str` | `TEXT` or `VARCHAR` | Text strings |
| `NumericField` | `float` | `REAL` or `NUMERIC` | Decimal numbers |
| `BooleanField` | `bool` | `INTEGER` (0/1) | True/False |
| `DateTimeField` | `str` | `TEXT` or `TIMESTAMP` | Date and time |
| `TextField` | `str` | `TEXT` | Long text |
| `BlobField` | `bytes` | `BLOB` | Binary data |
| `ForeignKeyField` | `int` | `INTEGER` | Foreign key reference |

Verbose names (`IntegerField`, `StringField`, `BooleanField`) are the standard. Short aliases (`IntField`, `StrField`, `BoolField`) also work.

### Field Options

| Option | Type | Description |
|--------|------|-------------|
| `required` | `bool` | Field must have a value (not None) |
| `default` | any | Default value when not provided |
| `max_length` | `int` | Maximum string length |
| `min_length` | `int` | Minimum string length |
| `min_value` | number | Minimum numeric value |
| `max_value` | number | Maximum numeric value |
| `choices` | list | Allowed values |
| `auto_increment` | `bool` | Auto-incrementing integer |
| `auto_now_add` | `bool` | Set to current time on create |
| `auto_now` | `bool` | Set to current time on every save |
| `regex` | `str` | Pattern the value must match |
| `validator` | callable | Custom validation function |

### Field Mapping

When your Python attribute names do not match the database column names, use `field_mapping` to define the translation:

```python
from tina4_python.orm import ORM, IntegerField, StringField

class User(ORM):
    table_name = "user_accounts"
    primary_key = "id"
    field_mapping = {
        "first_name": "fname",      # Python attr -> DB column
        "last_name": "lname",
        "email_address": "email",
    }

    id = IntegerField(auto_increment=True)
    first_name = StringField(required=True)
    last_name = StringField(required=True)
    email_address = StringField(required=True)
```

With this mapping, `user.first_name` reads from and writes to the `fname` column. The ORM handles the conversion in both directions -- on `find()`, `save()`, `select()`, and `to_dict()`. This is useful with legacy databases or third-party schemas where you cannot rename the columns.

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

    return response.json({"message": "Note created", "note": note.to_dict()}, 201)
```

`save()` detects whether the record is new (INSERT) or existing (UPDATE) based on whether the primary key has a value.

To update an existing record:

```python
@put("/api/notes/{id:int}")
async def update_note(id, request, response):
    note = Note.find(id)

    if note is None:
        return response.json({"error": "Note not found"}, 404)

    body = request.body
    if "title" in body:
        note.title = body["title"]
    if "content" in body:
        note.content = body["content"]
    if "category" in body:
        note.category = body["category"]
    if "pinned" in body:
        note.pinned = body["pinned"]

    note.save()

    return response.json({"message": "Note updated", "note": note.to_dict()})
```

### find -- Fetch One Record

```python
from tina4_python.core.router import get
from src.orm.note import Note

@get("/api/notes/{id:int}")
async def get_note(id, request, response):
    note = Note.find(id)

    if note is None:
        return response.json({"error": "Note not found"}, 404)

    return response.json(note.to_dict())
```

`find()` takes a primary key value and returns a model instance, or `None` if no row matches. For queries by other columns, use `where()`:

```python
notes, count = Note.where("category = ?", ["work"])
```

### delete -- Remove a Record

```python
from tina4_python.core.router import delete as delete_route
from src.orm.note import Note

@delete_route("/api/notes/{id:int}")
async def delete_note(id, request, response):
    note = Note.find(id)

    if note is None:
        return response.json({"error": "Note not found"}, 404)

    note.delete()

    return response.json(None, 204)
```

### select -- Fetch Multiple Records

```python
@get("/api/notes")
async def list_notes(request, response):
    category = request.params.get("category")

    if category:
        notes, count = Note.where("category = ?", [category])
    else:
        notes, count = Note.all()

    return response.json({
        "notes": [note.to_dict() for note in notes],
        "count": count
    })
```

`where()` takes a WHERE clause with `?` placeholders and a list of parameters. It returns a tuple of `(instances, total_count)`. `all()` fetches all records. Both support pagination:

```python
# With pagination
notes, count = Note.where("category = ?", ["work"], limit=20, offset=40)

# Fetch all with pagination
notes, count = Note.all(limit=20, offset=0)

# SQL-first query -- full control over the SQL
notes, count = Note.select(
    "SELECT * FROM notes WHERE pinned = ? ORDER BY created_at DESC",
    [1], limit=20, offset=0
)
```

---

## 5. to_dict and to_json

### to_dict

Convert a model instance to a dictionary:

```python
note = Note.find(1)

data = note.to_dict()
# {"id": 1, "title": "Shopping List", "content": "Milk, eggs", "category": "personal", "pinned": False, "created_at": "2026-03-22 14:30:00", "updated_at": "2026-03-22 14:30:00"}
```

The `include` parameter adds relationship data to the output (see Eager Loading below):

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

---

## 6. Relationships

### has_many

An author has many posts:

Create `src/orm/author.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class Author(ORM):
    table_name = "authors"

    id = IntegerField(auto_increment=True)
    name = StringField(required=True)
    email = StringField(required=True)
    bio = StringField(default="")
    created_at = DateTimeField(auto_now_add=True)
```

Create `src/orm/blog_post.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField, ForeignKeyField

class BlogPost(ORM):
    table_name = "posts"

    id = IntegerField(auto_increment=True)
    author_id = ForeignKeyField("authors.id", required=True)
    title = StringField(required=True, max_length=300)
    slug = StringField(required=True)
    content = StringField(default="")
    status = StringField(default="draft", choices=["draft", "published", "archived"])
    created_at = DateTimeField(auto_now_add=True)
    updated_at = DateTimeField(auto_now=True)
```

Now use `has_many` to get an author's posts:

```python
@get("/api/authors/{id:int}")
async def get_author(id, request, response):
    author = Author.find(id)

    if author is None:
        return response.json({"error": "Author not found"}, 404)

    posts = author.has_many(BlogPost, "author_id")

    data = author.to_dict()
    data["posts"] = [post.to_dict(include=["id", "title", "slug", "status"]) for post in posts]

    return response.json(data)
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
    post = BlogPost.find(id)

    if post is None:
        return response.json({"error": "Post not found"}, 404)

    author = post.belongs_to(Author, "author_id")

    data = post.to_dict()
    data["author"] = author.to_dict(include=["id", "name", "email"]) if author else None

    return response.json(data)
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

The `include` parameter on `select()`, `where()`, `all()`, and `find()` solves this. It eager-loads relationships in bulk:

```python
@get("/api/authors")
async def list_authors(request, response):
    authors = Author.select(
        order_by="name ASC",
        include=[{"model": BlogPost, "foreign_key": "author_id", "as": "posts"}]
    )

    data = []
    for author in authors:
        author_dict = author.to_dict()
        author_dict["posts"] = [p.to_dict(include=["id", "title", "status"]) for p in author.posts]
        data.append(author_dict)

    return response.json({"authors": data})
```

Without eager loading, 10 authors and their posts cost 11 queries. With eager loading: 2 queries. That is the difference between a fast page and a slow one.

### Declarative Relationships with Descriptors

For models where you define relationships declaratively using `HasMany`, `HasOne`, or `BelongsTo` descriptors in the ORM fields module, eager loading works through the `include` parameter on `find()`, `all()`, `where()`, and `select()`. Pass a list of relationship names:

```python
# Eager load posts when fetching all authors
authors, count = Author.all(include=["posts"])

# Eager load author and comments when finding a single post
post = BlogPost.find(1, include=["author", "comments"])
```

### Nested Eager Loading

Dot notation loads multiple levels deep:

```python
# Load authors, their posts, and each post's comments
authors, count = Author.all(include=["posts", "posts.comments"])
```

Authors, their posts, and each post's comments. Three queries total instead of hundreds.

### to_dict with Nested Includes

When eager loading is active, `to_dict(include=...)` embeds the related data:

```python
post = BlogPost.find(1, include=["author", "comments"])
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

Sometimes a record needs to disappear from queries without leaving the database. Soft delete handles this. The row stays. A timestamp marks it as deleted. Queries skip it.

```python
from tina4_python.orm import ORM, IntegerField, StringField, BooleanField, DateTimeField

class Task(ORM):
    table_name = "tasks"
    soft_delete = True  # Enable soft delete

    id = IntegerField(auto_increment=True)
    title = StringField(required=True)
    completed = BooleanField(default=False)
    deleted_at = DateTimeField()  # Required for soft delete
    created_at = DateTimeField(auto_now_add=True)
```

When `soft_delete = True`, the ORM changes its behaviour:

- `task.delete()` sets `deleted_at` to the current UTC timestamp instead of running a DELETE query
- `Task.all()`, `Task.where()`, and `Task.find()` filter out soft-deleted records
- `task.restore()` clears `deleted_at` and makes the record visible again
- `task.force_delete()` permanently removes the row from the database
- `Task.with_trashed()` includes soft-deleted records in query results

### Deleting and Restoring

```python
# Soft delete -- sets deleted_at, row stays in the database
task = Task.find(1)
task.delete()

# Restore -- clears deleted_at, record is visible again
task.restore()

# Permanently delete -- removes the row, no recovery possible
task.force_delete()
```

`restore()` is the inverse of `delete()`. It sets `deleted_at` back to `None` and commits the change. The record reappears in all standard queries.

### Including Soft-Deleted Records

Standard queries (`all()`, `where()`, `find()`) exclude soft-deleted records. When you need to see everything -- for admin dashboards, audit logs, or data recovery -- use `with_trashed()`:

```python
# All tasks, including soft-deleted ones
all_tasks, count = Task.with_trashed()

# Soft-deleted tasks matching a condition
deleted_tasks, count = Task.with_trashed("completed = ?", [1])
```

`with_trashed()` accepts the same filter parameters as `where()`. The only difference: it ignores the `deleted_at IS NULL` filter that standard queries apply.

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

### Registering a Model

```python
from tina4_python.crud import AutoCrud
from src.orm.note import Note

AutoCrud.register(Note)
```

That single call registers five routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all with pagination (`limit`, `skip` params) |
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
curl "http://localhost:7145/api/notes?limit=10&offset=0"
```

```json
{
  "data": [
    {"id": 1, "title": "Shopping List", "content": "Milk, eggs", "category": "personal", "pinned": false},
    {"id": 2, "title": "Sprint Plan", "content": "Review backlog", "category": "work", "pinned": true}
  ],
  "total": 2,
  "limit": 10,
  "skip": 0
}
```

**POST /api/notes** validates input before saving:

```bash
curl -X POST http://localhost:7145/api/notes \
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

## 10. Scopes

Scopes are reusable query filters baked into the model:

```python
class BlogPost(ORM):
    table_name = "posts"

    id = IntegerField(auto_increment=True)
    title = StringField(required=True)
    status = StringField(default="draft")
    created_at = DateTimeField(auto_now_add=True)

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
    return response.json({"posts": [p.to_dict() for p in posts]})

@get("/api/posts/recent")
async def recent_posts(request, response):
    days = int(request.params.get("days", 7))
    posts = BlogPost.recent(days)
    return response.json({"posts": [p.to_dict() for p in posts]})
```

Scopes keep query logic in the model where it belongs. Route handlers stay thin.

---

## 11. Input Validation

Field definitions carry validation rules. Call `validate()` before `save()` and the ORM checks every constraint:

```python
from tina4_python.orm import ORM, IntegerField, StringField, NumericField

class Product(ORM):
    table_name = "products"

    id = IntegerField(auto_increment=True)
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
        return response.json({"errors": errors}, 400)

    product.save()
    return response.json({"product": product.to_dict()}, 201)
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

## 12. Exercise: Build a Blog with Relationships

Build a blog API with authors, posts, and comments.

### Requirements

1. Create these models:

**Author:** `id`, `name` (required), `email` (required), `bio`, `created_at`

**Post:** `id`, `author_id` (foreign key), `title` (required, max 300), `slug` (required), `content`, `status` (choices: draft/published/archived, default draft), `created_at`, `updated_at`

**Comment:** `id`, `post_id` (foreign key), `author_name` (required), `author_email` (required), `body` (required, min 5 chars), `created_at`

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

## 13. Solution

Create `src/orm/author.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class Author(ORM):
    table_name = "authors"

    id = IntegerField(auto_increment=True)
    name = StringField(required=True, min_length=2)
    email = StringField(required=True)
    bio = StringField(default="")
    created_at = DateTimeField(auto_now_add=True)
```

Create `src/orm/blog_post.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField, ForeignKeyField

class BlogPost(ORM):
    table_name = "posts"

    id = IntegerField(auto_increment=True)
    author_id = ForeignKeyField("authors.id", required=True)
    title = StringField(required=True, max_length=300)
    slug = StringField(required=True)
    content = StringField(default="")
    status = StringField(default="draft", choices=["draft", "published", "archived"])
    created_at = DateTimeField(auto_now_add=True)
    updated_at = DateTimeField(auto_now=True)

    @classmethod
    def published(cls):
        return cls.where("status = ?", ["published"])
```

Create `src/orm/comment.py`:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField, ForeignKeyField

class Comment(ORM):
    table_name = "comments"

    id = IntegerField(auto_increment=True)
    post_id = ForeignKeyField("posts.id", required=True)
    author_name = StringField(required=True)
    author_email = StringField(required=True)
    body = StringField(required=True, min_length=5)
    created_at = DateTimeField(auto_now_add=True)
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
        return response.json({"errors": errors}, 400)

    author.save()
    return response.json({"author": author.to_dict()}, 201)


@get("/api/authors/{id:int}")
async def get_author(request, response):
    author = Author.find(request.params["id"])

    if author is None:
        return response.json({"error": "Author not found"}, 404)

    posts, count = BlogPost.where("author_id = ?", [author.id])

    data = author.to_dict()
    data["posts"] = [p.to_dict() for p in posts]

    return response.json(data)


@post("/api/posts")
async def create_post(request, response):
    body = request.body

    # Verify author exists
    author = Author.find(body.get("author_id"))
    if author is None:
        return response.json({"error": "Author not found"}, 404)

    blog_post = BlogPost()
    blog_post.author_id = body["author_id"]
    blog_post.title = body.get("title")
    blog_post.slug = body.get("slug")
    blog_post.content = body.get("content", "")
    blog_post.status = body.get("status", "draft")

    errors = blog_post.validate()
    if errors:
        return response.json({"errors": errors}, 400)

    blog_post.save()
    return response.json({"post": blog_post.to_dict()}, 201)


@get("/api/posts")
async def list_posts(request, response):
    posts = BlogPost.published()
    data = []

    for p in posts:
        post_dict = p.to_dict()
        author = p.belongs_to(Author, "author_id")
        post_dict["author"] = author.to_dict(include=["id", "name"]) if author else None
        data.append(post_dict)

    return response.json({"posts": data, "count": len(data)})


@get("/api/posts/{id:int}")
async def get_post(id, request, response):
    blog_post = BlogPost.find(id)

    if blog_post is None:
        return response.json({"error": "Post not found"}, 404)

    author = blog_post.belongs_to(Author, "author_id")
    comments = blog_post.has_many(Comment, "post_id")

    data = blog_post.to_dict()
    data["author"] = author.to_dict() if author else None
    data["comments"] = [c.to_dict() for c in comments]
    data["comment_count"] = len(comments)

    return response.json(data)


@post("/api/posts/{id:int}/comments")
async def add_comment(id, request, response):
    blog_post = BlogPost.find(id)

    if blog_post is None:
        return response.json({"error": "Post not found"}, 404)

    comment = Comment()
    comment.post_id = request.params["id"]
    comment.author_name = request.body.get("author_name")
    comment.author_email = request.body.get("author_email")
    comment.body = request.body.get("body")

    errors = comment.validate()
    if errors:
        return response.json({"errors": errors}, 400)

    comment.save()
    return response.json({"comment": comment.to_dict()}, 201)
```

---

## 14. Gotchas

### 1. Forgetting to call save()

**Problem:** You set properties on a model but the database does not change.

**Cause:** Setting `note.title = "New Title"` only changes the Python object. The database remains unchanged until you call `note.save()`.

**Fix:** Call `save()` after modifying properties.

### 2. find() returns None

**Problem:** You call `Note.find(id)` but get `None` instead of a note object.

**Cause:** `find()` returns `None` when no row matches the given primary key. If soft delete is enabled, `find()` also excludes soft-deleted records.

**Fix:** Check for `None` after `find()`: `if note is None: return 404`. Use `find_or_fail()` if you want a `ValueError` raised instead.

### 3. Circular imports with relationships

**Problem:** `from src.orm.post import BlogPost` in `author.py` and `from src.orm.author import Author` in `post.py` causes an `ImportError`.

**Cause:** Python cannot handle circular imports at module level.

**Fix:** Import inside the method that uses the relationship, not at the top of the file. Or pass the model class as a parameter in the route handler where you use both models.

### 4. to_dict() includes everything

**Problem:** `user.to_dict()` includes `password_hash` in the API response.

**Cause:** `to_dict()` includes all fields by default.

**Fix:** Build the response dict manually, omitting sensitive fields: `{"id": user.id, "name": user.name, "email": user.email}`. Or create a helper method on your model class that returns only safe fields.

### 5. Validation only runs on validate()

**Problem:** You call `save()` without calling `validate()` first, and invalid data gets into the database.

**Cause:** `save()` does not validate. This is by design -- sometimes you need to save partial data or bypass validation for bulk operations.

**Fix:** Call `errors = model.validate()` before `save()` in your route handlers. Or create a helper method that validates and saves in one step.

### 6. Foreign key not enforced

**Problem:** You save a post with `author_id = 999` and it succeeds, even though no author with ID 999 exists.

**Cause:** SQLite does not enforce foreign key constraints by default. The `ForeignKeyField` in the ORM defines the relationship for Tina4's methods, but the database itself may not enforce it.

**Fix:** Enable SQLite foreign keys with `PRAGMA foreign_keys = ON;` in a migration, or validate the foreign key in your route handler before saving.

### 7. N+1 query problem

**Problem:** Listing 100 authors with their posts runs 101 queries (1 for authors + 100 for posts), and the page loads slowly.

**Cause:** You call `author.has_many(BlogPost, "author_id")` inside a loop for each author.

**Fix:** Use eager loading with the `include` parameter on `all()`, `where()`, or `select()`. Or fetch all posts in a single query and group them manually:

```python
authors, count = Author.all()
all_posts, _ = BlogPost.select(
    "SELECT * FROM posts WHERE author_id IN (" + ",".join(str(a.id) for a in authors) + ")"
)
posts_by_author = {}
for post in all_posts:
    posts_by_author.setdefault(post.author_id, []).append(post)
```

### 8. Auto-CRUD endpoint conflicts

**Problem:** Custom route at `/api/notes/{id}` stops working after registering Auto-CRUD for the Note model.

**Cause:** Both routes match the same path. The first registered route wins.

**Fix:** Custom routes in `src/routes/` load before Auto-CRUD routes. They take precedence. If you want different behaviour, use a different path for the custom route.

### 9. Soft-deleted records appearing in find()

**Problem:** You soft-deleted a record, but `Model.find(id)` still returns it.

**Cause:** `find()` respects soft delete. If the record appears, check that `soft_delete = True` is set on the model class and that the model has a `deleted_at` field.

**Fix:** Verify both the `soft_delete = True` flag and the `deleted_at = DateTimeField()` field exist on the model. Without both, soft delete is inactive.
