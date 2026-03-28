# Chapter 6: ORM

## 1. From SQL to Objects

The last chapter was raw SQL. It works. It also gets repetitive. Every insert: an INSERT statement. Every update: an UPDATE. Every fetch: column names mapped to dictionary keys. Over and over.

Tina4's ORM turns database rows into Python objects. Define a model class with fields. The ORM writes the SQL. It remains SQL-first -- you can drop to raw SQL any time -- but for the 90% case of CRUD operations, the ORM handles the grunt work.

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

- `table_name` -- the database table this model maps to
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
        "first_name": "fname",      # Python attr → DB column
        "last_name": "lname",
        "email_address": "email",
    }

    id = IntegerField(auto_increment=True)
    first_name = StringField(required=True)
    last_name = StringField(required=True)
    email_address = StringField(required=True)
```

With this mapping, `user.first_name` reads from and writes to the `fname` column in the database. The ORM handles the conversion in both directions -- on `find()`, `save()`, `select()`, and `to_dict()`. This is useful when working with legacy databases or third-party schemas where you cannot rename the columns.

### auto_map and Case Conversion Utilities

The `auto_map` flag exists on the ORM base class for cross-language parity with the PHP and Node.js versions. In Python it is a no-op because Python convention already uses `snake_case`, which typically matches database column names.

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

This generates and runs the CREATE TABLE SQL based on your field definitions. Good for development and testing. For production, use migrations (Chapter 5) for version-controlled schema changes.

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

The `include` parameter is used to include relationship data (see Eager Loading below):

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

### Eager Loading with include

To avoid N+1 queries, use `include` to eager-load relationships:

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

Without eager loading, 10 authors and their posts cost 11 queries (1 for authors + 10 for posts). With eager loading: 2 queries. That is the difference between a fast page and a slow one.

---

## 7. Soft Delete

Sometimes a record needs to disappear from queries without leaving the database. Soft delete handles this:

```python
from tina4_python.orm import ORM, IntegerField, StringField, DateTimeField

class Task(ORM):
    table_name = "tasks"
    soft_delete = True  # Enable soft delete

    id = IntegerField(auto_increment=True)
    title = StringField(required=True)
    completed = BooleanField(default=False)
    deleted_at = DateTimeField()  # Required for soft delete
    created_at = DateTimeField(auto_now_add=True)
```

When `soft_delete = True`:

- `task.delete()` sets `deleted_at` to the current timestamp instead of running a DELETE query
- `Task.select()` automatically filters out soft-deleted records
- `task.restore()` clears `deleted_at` and makes the record visible again
- `task.force_delete()` permanently removes the record
- `Task.select(with_trashed=True)` includes soft-deleted records

```python
# Soft delete
task.delete()  # Sets deleted_at, does not remove the row

# Restore
task.restore()  # Clears deleted_at

# Permanently delete
task.force_delete()  # Actually removes the row

# Query including soft-deleted
all_tasks = Task.select(with_trashed=True)
```

---

## 8. Scopes

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

---

## 9. Input Validation

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

## 10. Exercise: Build a Blog with Relationships

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

## 11. Solution

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

## 12. Gotchas

### 1. Forgetting to call save()

**Problem:** You set properties on a model but the database does not change.

**Cause:** Setting `note.title = "New Title"` only changes the Python object. The database is not updated until you call `note.save()`.

**Fix:** Always call `save()` after modifying properties.

### 2. find() returns None

**Problem:** You call `Note.find(id)` but get `None` instead of a note object.

**Cause:** `find()` returns `None` when no row matches the given primary key.

**Fix:** Always check for `None` after `find()`: `if note is None: return 404`. Use `find_or_fail()` if you want a `ValueError` raised instead.

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

**Cause:** `save()` does not automatically validate. This is by design -- sometimes you need to save partial data or bypass validation for bulk operations.

**Fix:** Always call `errors = model.validate()` before `save()` in your route handlers. Or create a helper method that validates and saves in one step.

### 6. Foreign key not enforced

**Problem:** You save a post with `author_id = 999` and it succeeds, even though no author with ID 999 exists.

**Cause:** SQLite does not enforce foreign key constraints by default. The `ForeignKeyField` in the ORM defines the relationship for Tina4's relationship methods, but the database itself may not enforce it.

**Fix:** Enable SQLite foreign keys with `PRAGMA foreign_keys = ON;` in a migration, or validate the foreign key in your route handler before saving.

### 7. N+1 query problem

**Problem:** Listing 100 authors with their posts runs 101 queries (1 for authors + 100 for posts), making the page slow.

**Cause:** You are calling `author.has_many(BlogPost, "author_id")` inside a loop for each author.

**Fix:** Use eager loading with the `include` parameter on `select()`, or fetch all posts in a single query and group them manually:

```python
authors = Author.select()
all_posts = BlogPost.select("author_id IN (" + ",".join(str(a.id) for a in authors) + ")")
posts_by_author = {}
for post in all_posts:
    posts_by_author.setdefault(post.author_id, []).append(post)
```
