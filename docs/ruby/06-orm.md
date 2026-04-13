# Chapter 6: ORM

## 1. From SQL to Objects

The last chapter was raw SQL. It works. It also gets repetitive. Every insert demands an INSERT statement. Every update demands an UPDATE. Every fetch maps column names to hash keys. Over and over.

Tina4's ORM turns database rows into Ruby objects. Define a model class with fields. The ORM writes the SQL. It stays SQL-first -- you can drop to raw SQL at any moment -- but for the 90% case of CRUD operations, the ORM handles the grunt work.

Picture a blog. Authors, posts, comments. Authors own many posts. Posts own many comments. Comments belong to posts. Modeling these relationships with raw SQL means JOINs and manual foreign key management. The ORM makes this declarative.

---

## 2. Defining a Model

Create a model file in `src/orm/`. Every `.rb` file in that directory is auto-loaded.

Create `src/orm/note.rb`:

```ruby
class Note < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field :title, nullable: false
  string_field :content, default: ""
  string_field :category, default: "general"
  boolean_field :pinned, default: false
  datetime_field :created_at
  datetime_field :updated_at
end
```

A complete model. Here is what each piece does:

- The table name defaults to the lowercase, pluralised class name (`Note` -> `notes`). Override it with `table_name "my_table"` inside the class body.
- `primary_key: true` on a field marks it as the primary key (defaults to `:id` if none is specified)
- Each field is a DSL declaration that creates a getter and setter on the model

### Field Types

| Field Type | Ruby Type | SQL Type | Description |
|-----------|-----------|----------|-------------|
| `integer_field` | `Integer` | `INTEGER` | Whole numbers |
| `string_field` | `String` | `VARCHAR(255)` | Text strings |
| `text_field` | `String` | `TEXT` | Long text |
| `float_field` | `Float` | `REAL` | Floating-point numbers |
| `decimal_field` | `Float` | `REAL` | Decimal numbers (precision/scale options) |
| `numeric_field` | `Float` | `REAL` | Alias for float_field |
| `boolean_field` | `Integer` | `INTEGER` (0/1) | True/False stored as 0/1 |
| `date_field` | `String` | `DATE` | Date values |
| `datetime_field` | `String` | `DATETIME` | Date and time |
| `timestamp_field` | `String` | `TIMESTAMP` | Timestamps |
| `blob_field` | `String` | `BLOB` | Binary data |
| `json_field` | `String` | `TEXT` | JSON stored as text |

For foreign keys, use `integer_field`. There is no separate foreign key field type -- the relationship is defined through `has_many`, `has_one`, and `belongs_to` declarations instead.

### Field Options

| Option | Type | Description |
|--------|------|-------------|
| `primary_key` | `bool` | Marks this field as the primary key |
| `auto_increment` | `bool` | Auto-incrementing integer |
| `nullable` | `bool` | Whether the field accepts nil (default: `true`) |
| `default` | any | Default value when not provided |
| `length` | `int` | String length for `string_field` (default: 255) |
| `precision` | `int` | Decimal precision for `decimal_field` |
| `scale` | `int` | Decimal scale for `decimal_field` |

### Field Mapping

When your Ruby attribute names do not match the database column names, use `field_mapping` to define the translation. `field_mapping` is a hash that maps Ruby attribute names to DB column names.

```ruby
class User < Tina4::ORM
  self.field_mapping = {
    "first_name"    => "fname",      # Ruby attr -> DB column
    "last_name"     => "lname",
    "email_address" => "email"
  }

  integer_field :id, primary_key: true, auto_increment: true
  string_field :first_name, nullable: false
  string_field :last_name, nullable: false
  string_field :email_address, nullable: false

  table_name "user_accounts"
end
```

With this mapping, `user.first_name` reads from and writes to the `fname` column. The ORM handles the conversion in both directions -- on reads via `from_hash` and on writes via `to_db_hash`. This is useful with legacy databases or third-party schemas where you cannot rename the columns.

A common use case is Firebird or Oracle, which store column names in uppercase:

```ruby
class Account < Tina4::ORM
  self.table_name   = "ACCOUNTS"
  self.field_mapping = {
    "id"           => "CUST_ID",
    "account_no"   => "ACCOUNTNO",
    "store_name"   => "STORENAME",
    "credit_limit" => "CREDITLIMIT",
  }

  integer_field :id, primary_key: true, auto_increment: true
  string_field :account_no
  string_field :store_name
  float_field :credit_limit, default: 0.0
end
```

Ruby code uses clean snake_case names (`account.account_no`, `account.credit_limit`). The ORM maps them to the uppercase DB columns automatically.

### find() vs where() -- naming convention

The two query methods have a deliberate difference in how they handle column names:

- **`find(filter)`** uses **Ruby attribute names**. The ORM translates them via `field_mapping`.
- **`where(conditions, params)`** uses **raw DB column names** in the SQL string. No translation is done.

```ruby
# find() -- use Ruby attribute names
accounts = Account.find(account_no: "A001")   # translates to ACCOUNTNO = ?

# where() -- use DB column names directly in the SQL
accounts = Account.where("ACCOUNTNO = ?", ["A001"])  # raw SQL, no translation
```

This means `find()` is portable across database engines, while `where()` gives you full control of the SQL.

### auto_map and Case Conversion Utilities

The `auto_map` flag exists on the ORM base class for cross-language parity with the PHP and Node.js versions. In Ruby it is a no-op because Ruby convention already uses `snake_case`, which matches database column names.

For cases where you need to convert between naming conventions (for example, when serialising to a camelCase JSON API), two utility methods are available:

```ruby
Tina4.snake_to_camel("first_name")   # "firstName"
Tina4.camel_to_snake("firstName")    # "first_name"
```

---

## 3. create_table -- Schema from Models

You can create the database table directly from your model definition:

```ruby
Note.create_table
```

This generates and runs the CREATE TABLE SQL based on your field definitions. It is good for development and testing. For production, use migrations (Chapter 5) for version-controlled schema changes.

```bash
irb
irb> require_relative "app"
irb> Note.create_table
```

---

## 4. CRUD Operations

### save -- Create or Update

```ruby
Tina4::Router.post "/api/notes" do |request, response|
  note = Note.new
  note.title = request.body_parsed["title"]
  note.content = request.body_parsed["content"] || ""
  note.category = request.body_parsed["category"] || "general"
  note.pinned = request.body_parsed["pinned"] || false
  result = note.save

  if result
    response.json({ message: "Note created", note: note.to_h }, status: 201)
  else
    response.json({ errors: note.errors }, status: 422)
  end
end
```

`save` detects whether the record is new (INSERT) or existing (UPDATE) based on whether the primary key has a value and the record is persisted. It returns `self` on success, so you can chain calls. It returns `false` on failure -- check `note.errors` for details.

### create -- Build and Save in One Step

When you have a hash of data ready, `create` builds the model and saves it in one call:

```ruby
note = Note.create({
  title: "Quick Note",
  content: "Created in one step",
  category: "general"
})
```

### find_by_id -- Fetch One Record by Primary Key

```ruby
Tina4::Router.get "/api/notes/{id:int}" do |request, response|
  note = Note.find_by_id(request.params["id"].to_i)

  if note.nil?
    response.json({ error: "Note not found" }, status: 404)
  else
    response.json(note.to_h)
  end
end
```

`find_by_id` takes a primary key value and returns a model instance, or `nil` if no row matches. If soft delete is enabled, it excludes soft-deleted records.

Use `find_or_fail` when you want an exception raised instead of `nil`:

```ruby
note = Note.find_or_fail(id)  # Raises RuntimeError if not found
```

### find -- Query by Filter Hash

The `find` method accepts a hash of column-value pairs and returns an array of matching records:

```ruby
# Find all notes in the "work" category
work_notes = Note.find({ category: "work" })

# Find with pagination and ordering
recent = Note.find({ pinned: true }, limit: 10, order_by: "created_at DESC")

# Find all records (no filter)
all_notes = Note.find
```

Both hash syntax (`find({category: "work"})`) and keyword syntax (`find(category: "work")`) are accepted. Ruby attribute names are used in the filter -- the ORM applies `field_mapping` automatically when translating to SQL column names.

### where -- Query with SQL Conditions

For more complex queries, `where` takes a SQL WHERE clause with `?` placeholders:

```ruby
notes = Note.where("category = ?", ["work"])
```

### delete -- Remove a Record

```ruby
Tina4::Router.delete "/api/notes/{id:int}" do |request, response|
  note = Note.find_by_id(request.params["id"].to_i)

  if note.nil?
    response.json({ error: "Note not found" }, status: 404)
  else
    note.delete
    response.json(nil, status: 204)
  end
end
```

### Listing Records

```ruby
Tina4::Router.get "/api/notes" do |request, response|
  category = request.query["category"]

  if category
    notes = Note.where("category = ?", [category])
  else
    notes = Note.all
  end

  response.json({
    notes: notes.map(&:to_h),
    count: notes.length
  })
end
```

`where` takes a WHERE clause with `?` placeholders and an array of parameters. It returns an array of model instances. `all` fetches all records. Both support pagination:

```ruby
# With pagination
notes = Note.where("category = ?", ["work"])

# Fetch all with pagination and ordering
notes = Note.all(limit: 20, offset: 0, order_by: "created_at DESC")

# SQL-first query -- full control over the SQL
notes = Note.select(
  "SELECT * FROM notes WHERE pinned = ? ORDER BY created_at DESC",
  [1], limit: 20, offset: 0
)
```

### select_one -- Fetch a Single Record by SQL

When you need exactly one record from a custom SQL query:

```ruby
note = Note.select_one("SELECT * FROM notes WHERE slug = ?", ["my-note"])
```

Returns a model instance or `nil`.

### load -- Populate an Existing Instance

The `load` method fills an existing model instance from the database:

```ruby
note = Note.new
note.id = 42
note.load  # Loads data for id=42

# Or with a filter string
note = Note.new
note.load("slug = ?", ["my-note"])
```

Returns `true` if a record was found, `false` otherwise.

### count -- Count Records

```ruby
total = Note.count
work_count = Note.count("category = ?", ["work"])
```

Respects soft delete -- only counts non-deleted records.

---

## 5. to_h, to_dict, to_json, and Other Serialisation

### to_h and to_dict

Convert a model instance to a hash. `to_dict` is a direct alias for `to_h` -- use whichever reads more naturally in your code:

```ruby
note = Note.find_by_id(1)

data = note.to_h
# {id: 1, title: "Shopping List", content: "Milk, eggs", category: "personal", pinned: false, created_at: "2026-03-22 14:30:00", updated_at: "2026-03-22 14:30:00"}

# to_dict is identical
data = note.to_dict
```

The `include` parameter adds relationship data to the output (see Eager Loading below). Pass an array of relationship names:

```ruby
# Include relationships in the hash
data = note.to_h(include: [:comments])
data = note.to_dict(include: [:comments])  # same result
```

### to_json

Convert directly to a JSON string:

```ruby
json_string = note.to_json
# '{"id":1,"title":"Shopping List",...}'
```

### Other Serialisation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `to_h(include: nil)` | `Hash` | Primary hash method with optional relationship includes |
| `to_hash(include: nil)` | `Hash` | Alias for `to_h` |
| `to_dict(include: nil)` | `Hash` | Alias for `to_h` |
| `to_assoc(include: nil)` | `Hash` | Alias for `to_h` |
| `to_object` | `Hash` | Alias for `to_h` |
| `to_json(include: nil)` | `String` | JSON string |
| `to_array` | `Array` | Flat list of values (no keys) |
| `to_list` | `Array` | Alias for `to_array` |

---

## 6. Relationships

Tina4 Ruby supports two styles of relationships: declarative (class-level DSL) and imperative (instance-level method calls). Both produce the same queries. Declarative relationships enable eager loading; imperative relationships are ad-hoc.

### foreign_key_field — Auto-Wired Relationships

Declaring a column with `foreign_key_field :user_id, references: User` automatically wires both sides of the relationship. The declaring class gets a `belongs_to` accessor (the column name with `_id` stripped), and the referenced class gets a `has_many` accessor (the declaring class name lowercased with `s` appended, or whatever you pass via `related_name:`).

```ruby
class User < Tina4::ORM
  table_name "users"
  integer_field :id, primary_key: true
  string_field :name
end

class Post < Tina4::ORM
  table_name "posts"
  integer_field :id, primary_key: true
  string_field :title

  # Auto-wires post.user (belongs_to) and user.posts (has_many)
  foreign_key_field :user_id, references: User
end
```

With just the `foreign_key_field` declaration, both sides are accessible:

```ruby
post = Post.find_by_id(1)
puts post.user.name        # "Alice"

user = User.find_by_id(1)
user.posts.each do |p|
  puts p.title
end
```

For a custom `has_many` name, pass `related_name:`:

```ruby
foreign_key_field :user_id, references: User, related_name: :blog_posts
# user.blog_posts instead of user.posts
```

If the referenced class is defined later, the framework handles deferred wiring — as soon as the referenced class applies its own field definitions, the `has_many` is injected.

### Declarative Relationships

Define relationships at the class level. The ORM creates accessor methods on each instance.

#### has_many

An author has many posts:

Create `src/orm/author.rb`:

```ruby
class Author < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field :name, nullable: false
  string_field :email, nullable: false
  string_field :bio, default: ""
  datetime_field :created_at

  has_many :posts, class_name: "BlogPost", foreign_key: "author_id"
end
```

Create `src/orm/blog_post.rb`:

```ruby
class BlogPost < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  integer_field :author_id, nullable: false
  string_field :title, nullable: false
  string_field :slug, nullable: false
  string_field :content, default: ""
  string_field :status, default: "draft"
  datetime_field :created_at
  datetime_field :updated_at

  table_name "posts"

  belongs_to :author, class_name: "Author", foreign_key: "author_id"
end
```

Now access an author's posts:

```ruby
Tina4::Router.get "/api/authors/{id:int}" do |request, response|
  author = Author.find_by_id(request.params["id"].to_i)

  if author.nil?
    response.json({ error: "Author not found" }, status: 404)
  else
    posts = author.posts  # Calls the has_many accessor

    data = author.to_h
    data[:posts] = posts.map(&:to_h)
    response.json(data)
  end
end
```

#### has_one

A user has one profile:

```ruby
class User < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field :name, nullable: false

  has_one :profile, class_name: "Profile", foreign_key: "user_id"
end
```

```ruby
profile = user.profile  # Returns a single instance or nil
```

#### belongs_to

A post belongs to an author:

```ruby
Tina4::Router.get "/api/posts/{id:int}" do |request, response|
  post = BlogPost.find_by_id(request.params["id"].to_i)

  if post.nil?
    response.json({ error: "Post not found" }, status: 404)
  else
    author = post.author  # Calls the belongs_to accessor

    data = post.to_h
    data[:author] = author&.to_h
    response.json(data)
  end
end
```

### Imperative Relationships

For ad-hoc queries without class-level declarations, use `query_has_many`, `query_has_one`, and `query_belongs_to` on any instance:

```ruby
# Same result as declarative has_many, but without a class-level declaration
posts = author.query_has_many(BlogPost, foreign_key: "author_id")

# Has one
profile = user.query_has_one(Profile, foreign_key: "user_id")

# Belongs to
author = post.query_belongs_to(Author, foreign_key: "author_id")
```

These work identically to the declarative accessors but do not support eager loading.

---

## 7. Eager Loading

Calling relationship methods inside a loop creates the N+1 problem. Load 10 authors. Call `author.posts` for each one. That fires 11 queries -- 1 for authors, 10 for posts. The page drags.

The `include` parameter on `all`, `where`, `find`, and `select` solves this. It eager-loads relationships in bulk:

```ruby
Tina4::Router.get "/api/authors" do |request, response|
  authors = Author.all(include: ["posts"])

  data = authors.map do |author|
    author_dict = author.to_h
    author_dict[:posts] = author.posts.map(&:to_h)
    author_dict
  end

  response.json({ authors: data })
end
```

Without eager loading, 10 authors and their posts cost 11 queries. With eager loading: 2 queries. That is the difference between a fast page and a slow one.

### Nested Eager Loading

Dot notation loads multiple levels deep:

```ruby
# Load authors, their posts, and each post's comments
authors = Author.all(include: ["posts", "posts.comments"])
```

Authors, their posts, and each post's comments. Three queries total instead of hundreds.

### to_h with Nested Includes

When eager loading is active, `to_h(include: ...)` embeds the related data:

```ruby
post = BlogPost.find_by_id(1)
# Manually trigger eager load first, or use select with include
posts = BlogPost.select(
  "SELECT * FROM posts WHERE id = ?", [1],
  include: ["author", "comments"]
)
post = posts.first
data = post.to_h(include: ["author", "comments"])
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

```ruby
class Task < Tina4::ORM
  self.soft_delete = true  # Enable soft delete

  integer_field :id, primary_key: true, auto_increment: true
  string_field :title, nullable: false
  boolean_field :completed, default: false
  integer_field :is_deleted, default: 0  # Required for soft delete (0 = active, 1 = deleted)
  string_field :created_at
end
```

When `soft_delete` is set to `true`, the ORM changes its behaviour:

- `task.delete` sets `is_deleted` to `1` instead of running a DELETE query
- `Task.all`, `Task.where`, and `Task.find_by_id` filter out records where `is_deleted = 1`
- `task.restore` sets `is_deleted` back to `0` and makes the record visible again
- `task.force_delete` permanently removes the row from the database
- `Task.with_trashed` includes soft-deleted records in query results

### Deleting and Restoring

```ruby
# Soft delete -- sets is_deleted = 1, row stays in the database
task = Task.find_by_id(1)
task.delete

# Restore -- sets is_deleted = 0, record is visible again
task.restore

# Permanently delete -- removes the row, no recovery possible
task.force_delete
```

`restore` is the inverse of `delete`. It sets `is_deleted` back to `0` and commits the change. The record reappears in all standard queries.

### Including Soft-Deleted Records

Standard queries (`all`, `where`, `find_by_id`) exclude soft-deleted records. When you need to see everything -- for admin dashboards, audit logs, or data recovery -- use `with_trashed`:

```ruby
# All tasks, including soft-deleted ones
all_tasks = Task.with_trashed

# Soft-deleted tasks matching a condition
deleted_tasks = Task.with_trashed("completed = ?", [1])
```

`with_trashed` accepts the same filter parameters as `where`. The only difference: it ignores the `is_deleted` filter that standard queries apply.

### Counting with Soft Delete

The `count` class method respects soft delete. It only counts non-deleted records:

```ruby
active_count = Task.count
active_work = Task.count("category = ?", ["work"])
```

### Custom Soft Delete Field

By default, the ORM uses `:is_deleted` as the soft delete column. You can change this:

```ruby
class Task < Tina4::ORM
  self.soft_delete = true
  self.soft_delete_field = :deleted_flag

  integer_field :id, primary_key: true, auto_increment: true
  string_field :title, nullable: false
  integer_field :deleted_flag, default: 0
end
```

### When to Use Soft Delete

Soft delete suits data that users might want to recover -- emails, documents, user accounts. It also serves audit requirements where regulations demand retention. For temporary data (sessions, cache entries, logs), hard delete keeps the table lean.

---

## 9. Auto-CRUD

Writing the same five REST endpoints for every model gets tedious. Auto-CRUD generates them from your model class. Define the model. Register it. Five routes appear.

### The auto_crud Flag

The simplest approach -- set `self.auto_crud = true` on your model class:

```ruby
class Note < Tina4::ORM
  self.auto_crud = true  # Generates REST endpoints automatically

  integer_field :id, primary_key: true, auto_increment: true
  string_field :title, nullable: false
  string_field :content, default: ""
end
```

The moment Ruby loads this class, the ORM registers it with `AutoCrud`. Five routes appear after `Tina4::AutoCrud.generate_routes` is called.

### Manual Registration

You can also register models explicitly using `AutoCrud.register`:

```ruby
Tina4::AutoCrud.register(Note)
```

Then generate all routes at once:

```ruby
Tina4::AutoCrud.generate_routes(prefix: "/api")
```

Both approaches produce the same result:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all with pagination (`limit`, `offset`, `page`, `per_page` params) |
| `GET` | `/api/notes/{id}` | Get one by primary key |
| `POST` | `/api/notes` | Create a new record |
| `PUT` | `/api/notes/{id}` | Update a record |
| `DELETE` | `/api/notes/{id}` | Delete a record |

The endpoint prefix derives from the table name. The `notes` table becomes `/api/notes`. Pass a custom prefix to change it:

```ruby
Tina4::AutoCrud.generate_routes(prefix: "/api/v2")
# Routes: /api/v2/notes, /api/v2/notes/{id}, etc.
```

### What the Generated Routes Do

**GET /api/notes** returns paginated results with optional filtering and sorting:

```bash
curl "http://localhost:7147/api/notes?limit=10&offset=0"
curl "http://localhost:7147/api/notes?filter[category]=work&sort=-created_at"
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

Sorting uses the `sort` parameter. Prefix a field with `-` for descending order: `?sort=-created_at,name`.

Filtering uses `filter[field]=value` syntax: `?filter[category]=work&filter[pinned]=true`.

**POST /api/notes** validates input before saving:

```bash
curl -X POST http://localhost:7147/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "New Note", "content": "Created via auto-CRUD"}'
```

If validation fails (for example, a required field is missing), the endpoint returns a 422 with error details:

```json
{"errors": ["title cannot be null"]}
```

**DELETE /api/notes/1** respects soft delete. If the model has `self.soft_delete = true`, the record is marked deleted instead of removed.

### Custom Routes Alongside Auto-CRUD

Custom routes defined in `src/routes/` load before auto-CRUD routes. They take precedence. If you need special logic for one endpoint (custom validation, side effects, complex queries), define that route manually. Auto-CRUD handles the rest.

---

## 10. Scopes

Scopes are reusable query filters baked into the model. Ruby supports two approaches: instance methods and the `scope` class method.

### Class Methods as Scopes

```ruby
class BlogPost < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field :title, nullable: false
  string_field :status, default: "draft"
  datetime_field :created_at

  table_name "posts"

  def self.published
    where("status = ?", ["published"])
  end

  def self.drafts
    where("status = ?", ["draft"])
  end

  def self.recent(days = 7)
    where(
      "created_at > datetime('now', ?)",
      ["-#{days} days"]
    )
  end
end
```

Use them in your routes:

```ruby
Tina4::Router.get "/api/posts/published" do |request, response|
  posts = BlogPost.published
  response.json({ posts: posts.map(&:to_h) })
end

Tina4::Router.get "/api/posts/recent" do |request, response|
  days = (request.query["days"] || 7).to_i
  posts = BlogPost.recent(days)
  response.json({ posts: posts.map(&:to_h) })
end
```

### Dynamic Scopes with scope()

Register scopes dynamically with the `scope` class method:

```ruby
BlogPost.scope("active", "status != ?", ["archived"])

# Now call it:
active_posts = BlogPost.active
```

Scopes keep query logic in the model where it belongs. Route handlers stay thin.

---

## 11. Input Validation

Field definitions carry validation rules through the `nullable` option. Call `validate` before `save` and the ORM checks every constraint:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field :name, nullable: false
  string_field :sku, nullable: false
  float_field :price, nullable: false
  string_field :category
end
```

```ruby
Tina4::Router.post "/api/products" do |request, response|
  product = Product.new(request.body_parsed)

  errors = product.validate
  if errors.any?
    response.json({ errors: errors }, status: 400)
  else
    product.save
    response.json({ product: product.to_h }, status: 201)
  end
end
```

If validation fails, `validate` returns an array of error messages:

```json
{
  "errors": [
    "name cannot be null",
    "sku cannot be null",
    "price cannot be null"
  ]
}
```

Note that `save` also runs field validation internally and returns `false` if any required fields are missing. Check `model.errors` after a failed save.

---

## 12. Exercise: Build a Blog with Relationships

Build a blog API with authors, posts, and comments.

### Requirements

1. Create these models:

**Author:** `id`, `name` (required), `email` (required), `bio`, `created_at`

**Post:** `id`, `author_id` (integer foreign key), `title` (required), `slug` (required), `content`, `status` (default: draft), `created_at`, `updated_at`

**Comment:** `id`, `post_id` (integer foreign key), `author_name` (required), `author_email` (required), `body` (required), `created_at`

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

Create `src/orm/author.rb`:

```ruby
class Author < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field :name, nullable: false
  string_field :email, nullable: false
  string_field :bio, default: ""
  datetime_field :created_at

  has_many :posts, class_name: "BlogPost", foreign_key: "author_id"
end
```

Create `src/orm/blog_post.rb`:

```ruby
class BlogPost < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  integer_field :author_id, nullable: false
  string_field :title, nullable: false
  string_field :slug, nullable: false
  string_field :content, default: ""
  string_field :status, default: "draft"
  datetime_field :created_at
  datetime_field :updated_at

  table_name "posts"

  belongs_to :author, class_name: "Author", foreign_key: "author_id"
  has_many :comments, class_name: "Comment", foreign_key: "post_id"

  def self.published
    where("status = ?", ["published"])
  end
end
```

Create `src/orm/comment.rb`:

```ruby
class Comment < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  integer_field :post_id, nullable: false
  string_field :author_name, nullable: false
  string_field :author_email, nullable: false
  string_field :body, nullable: false
  datetime_field :created_at

  belongs_to :post, class_name: "BlogPost", foreign_key: "post_id"
end
```

Create `src/routes/blog.rb`:

```ruby
Tina4::Router.post "/api/authors" do |request, response|
  author = Author.new
  author.name = request.body_parsed["name"]
  author.email = request.body_parsed["email"]
  author.bio = request.body_parsed["bio"] || ""

  errors = author.validate
  if errors.any?
    response.json({ errors: errors }, status: 400)
  else
    author.save
    response.json({ author: author.to_h }, status: 201)
  end
end

Tina4::Router.get "/api/authors/{id:int}" do |request, response|
  author = Author.find_by_id(request.params["id"].to_i)

  if author.nil?
    response.json({ error: "Author not found" }, status: 404)
  else
    posts = author.posts

    data = author.to_h
    data[:posts] = posts.map(&:to_h)
    response.json(data)
  end
end

Tina4::Router.post "/api/posts" do |request, response|
  body = request.body_parsed

  # Verify author exists
  author = Author.find_by_id(body["author_id"])
  if author.nil?
    next response.json({ error: "Author not found" }, status: 404)
  end

  blog_post = BlogPost.new
  blog_post.author_id = body["author_id"]
  blog_post.title = body["title"]
  blog_post.slug = body["slug"]
  blog_post.content = body["content"] || ""
  blog_post.status = body["status"] || "draft"

  errors = blog_post.validate
  if errors.any?
    response.json({ errors: errors }, status: 400)
  else
    blog_post.save
    response.json({ post: blog_post.to_h }, status: 201)
  end
end

Tina4::Router.get "/api/posts" do |request, response|
  posts = BlogPost.published
  data = []

  posts.each do |p|
    post_dict = p.to_h
    post_dict[:author] = p.author&.to_h
    data << post_dict
  end

  response.json({ posts: data, count: data.length })
end

Tina4::Router.get "/api/posts/{id:int}" do |request, response|
  blog_post = BlogPost.find_by_id(request.params["id"].to_i)

  if blog_post.nil?
    response.json({ error: "Post not found" }, status: 404)
  else
    data = blog_post.to_h
    data[:author] = blog_post.author&.to_h
    comments = blog_post.comments
    data[:comments] = comments.map(&:to_h)
    data[:comment_count] = comments.length
    response.json(data)
  end
end

Tina4::Router.post "/api/posts/{id:int}/comments" do |request, response|
  blog_post = BlogPost.find_by_id(request.params["id"].to_i)

  if blog_post.nil?
    next response.json({ error: "Post not found" }, status: 404)
  end

  comment = Comment.new
  comment.post_id = request.params["id"].to_i
  comment.author_name = request.body_parsed["author_name"]
  comment.author_email = request.body_parsed["author_email"]
  comment.body = request.body_parsed["body"]

  errors = comment.validate
  if errors.any?
    response.json({ errors: errors }, status: 400)
  else
    comment.save
    response.json({ comment: comment.to_h }, status: 201)
  end
end
```

---

## 14. Gotchas

### 1. Forgetting to call save

**Problem:** You set properties on a model but the database does not change.

**Cause:** Setting `note.title = "New Title"` only changes the Ruby object. The database remains unchanged until you call `note.save`.

**Fix:** Call `save` after modifying properties. Check the return value -- `save` returns `self` on success and `false` on failure.

### 2. find_by_id returns nil

**Problem:** You call `Note.find_by_id(id)` but get `nil` instead of a note object.

**Cause:** `find_by_id` returns `nil` when no row matches the given primary key. If soft delete is enabled, `find_by_id` also excludes soft-deleted records.

**Fix:** Check for `nil` after `find_by_id`: `if note.nil?` and return 404. Use `find_or_fail` if you want an exception raised instead.

### 3. find takes a hash, not keyword arguments

**Problem:** You call `Note.find(category: "work")` expecting a filter, but get unexpected results.

**Cause:** `find` takes a hash argument: `find({category: "work"})`. Passing `category: "work"` as a keyword argument does not filter -- it gets interpreted differently.

**Fix:** Use `find({column: value})` with an explicit hash. Use `find_by_id(id)` for primary key lookups.

### 4. to_h includes everything

**Problem:** `user.to_h` includes `password_hash` in the API response.

**Cause:** `to_h` includes all fields by default.

**Fix:** Build the response hash manually, omitting sensitive fields: `{id: user.id, name: user.name, email: user.email}`. Or create a helper method on your model class that returns only safe fields.

### 5. Validation runs on save, but check errors

**Problem:** You call `save` and it returns `false`, but you do not know why.

**Cause:** `save` validates required fields internally. When validation fails, it populates `model.errors` and returns `false`.

**Fix:** Call `errors = model.validate` before `save` for explicit error messages. Or check `model.errors` after a failed save.

### 6. Foreign key not enforced

**Problem:** You save a post with `author_id = 999` and it succeeds, even though no author with ID 999 exists.

**Cause:** SQLite does not enforce foreign key constraints by default. The ORM defines the relationship through `has_many`/`belongs_to` declarations, but the database itself may not enforce it.

**Fix:** Enable SQLite foreign keys with `PRAGMA foreign_keys = ON;` in a migration, or validate the foreign key in your route handler before saving.

### 7. N+1 query problem

**Problem:** Listing 100 authors with their posts runs 101 queries (1 for authors + 100 for posts), and the page loads slowly.

**Cause:** You call `author.posts` inside a loop for each author.

**Fix:** Use eager loading with the `include` parameter on `all`, `where`, or `select`:

```ruby
authors = Author.all(include: ["posts"])
```

Two queries instead of 101.

### 8. Auto-CRUD endpoint conflicts

**Problem:** Custom route at `/api/notes/{id}` stops working after registering Auto-CRUD for the Note model.

**Cause:** Both routes match the same path. The first registered route wins.

**Fix:** Custom routes in `src/routes/` load before Auto-CRUD routes. They take precedence. If you want different behaviour, use a different path for the custom route.

### 9. Soft-deleted records appearing in queries

**Problem:** You soft-deleted a record, but queries still return it.

**Cause:** Soft delete requires `self.soft_delete = true` on the model class and an `integer_field :is_deleted, default: 0` field. Without both, soft delete is inactive.

**Fix:** Verify both the `self.soft_delete = true` flag and the `integer_field :is_deleted, default: 0` field exist on the model. The column stores `0` for active records and `1` for deleted ones.

### 10. Table name pluralisation

**Problem:** Your model `Category` maps to `categorys` instead of `categories`.

**Cause:** The ORM appends `s` by default unless the name already ends in `s`. It does not handle irregular plurals.

**Fix:** Set the table name explicitly with `table_name "categories"` inside the class body. Disable auto-pluralisation with the `ORM_PLURAL_TABLE_NAMES=false` environment variable.

---

## 15. Raw SQL

The ORM handles 90% of queries. The other 10% need custom SQL -- reports, aggregations, complex joins. Drop down to the database directly:

```ruby
result = Tina4.database.fetch("SELECT * FROM users WHERE active = ?", [1])
result.each { |row| puts row["name"] }
```

`fetch` returns an array of hashes. Column names are the keys. Combine raw SQL with ORM serialisation:

```ruby
rows = Tina4.database.fetch(
  "SELECT u.*, COUNT(p.id) AS post_count FROM users u LEFT JOIN posts p ON p.user_id = u.id GROUP BY u.id",
  []
)

rows.each do |row|
  puts "#{row["name"]}: #{row["post_count"]} posts"
end
```

When your raw query returns rows that match a model's shape, you can hydrate them via `from_hash`:

```ruby
rows = Tina4.database.fetch("SELECT * FROM users WHERE active = ?", [1])
users = rows.map { |row| User.from_hash(row) }
users.each { |user| puts user.to_h }
```

`from_hash` applies `field_mapping` during hydration, so DB column names are translated to Ruby attribute names automatically.

---

## 16. QueryBuilder Integration

ORM models provide a `query` class method that returns a `QueryBuilder` pre-configured with the model's table name and database connection. This gives you a fluent API for building complex queries without writing raw SQL:

```ruby
# Fluent query builder from ORM
results = User.query
  .where("active = ?", [1])
  .order_by("name")
  .limit(50)
  .get

# First matching record
user = User.query
  .where("email = ?", ["alice@example.com"])
  .first

# Count
total = User.query
  .where("role = ?", ["admin"])
  .count

# Check existence
exists = User.query
  .where("email = ?", ["test@example.com"])
  .exists?
```

See the [QueryBuilder chapter](07-query-builder.md) for the full fluent API including joins, grouping, having, and MongoDB support.
