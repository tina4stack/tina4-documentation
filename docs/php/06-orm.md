# Chapter 6: ORM

## 1. From SQL to Objects

The last chapter was raw SQL. It works. It also gets repetitive. Every insert demands an INSERT statement. Every update demands an UPDATE. Every fetch maps column names to array keys. Over and over.

Tina4's ORM turns database rows into PHP objects. Define a model class with properties. The ORM writes the SQL. It stays SQL-first -- you can drop to raw SQL at any moment -- but for the 90% case of CRUD operations, the ORM handles the grunt work.

Picture a blog. Authors, posts, comments. Authors own many posts. Posts own many comments. Comments belong to posts. Modelling these relationships with raw SQL means JOINs and manual foreign key management. The ORM makes this declarative.

---

## 2. Defining a Model

Create a model file in `src/orm/`. Every `.php` file in that directory is auto-loaded.

Create `src/orm/Note.php`:

```php
<?php

use Tina4\ORM;

class Note extends ORM
{
    public string $tableName = "notes";
    public string $primaryKey = "id";

    public int $id;
    public string $title;
    public string $content = "";
    public string $category = "general";
    public bool $pinned = false;
    public string $createdAt;
    public string $updatedAt;
}
```

A complete model. Here is what each piece does:

- `$tableName` -- the database table this model maps to. If omitted, the ORM uses the lowercase class name (e.g. `Contact` maps to `contact`).
- `$primaryKey` -- the primary key column name. Defaults to `"id"` if not specified.
- Each property uses native PHP type hints (`int`, `string`, `float`, `bool`) to define the column type.

### Property Types

| PHP Type | SQL Type | Description |
|----------|----------|-------------|
| `int` | `INTEGER` | Whole numbers |
| `string` | `VARCHAR(255)` | Text strings |
| `float` | `REAL` / `DOUBLE PRECISION` | Decimal numbers |
| `bool` | `INTEGER` (0/1) | True/False |

For foreign keys, use `int`. There is no separate foreign key type -- the relationship is defined through `$hasMany`, `$hasOne`, and `$belongsTo` array properties instead.

### Field Mapping

When your PHP property names do not match the database column names, use `$fieldMapping` to define the translation:

```php
<?php

use Tina4\ORM;

class User extends ORM
{
    public string $tableName = "user_accounts";
    public array $fieldMapping = [
        "firstName" => "fname",      // PHP property => DB column
        "lastName"  => "lname",
        "emailAddress" => "email",
    ];

    public int $id;
    public string $firstName;
    public string $lastName;
    public string $emailAddress;
}
```

With this mapping, `$user->firstName` reads from and writes to the `fname` column. The ORM handles the conversion in both directions -- on `findById()`, `save()`, `select()`, and `toDict()`. This is useful with legacy databases or third-party schemas where you cannot rename the columns.

### autoMap and Case Conversion

The `$autoMap` flag converts camelCase PHP property names to snake_case database column names. This matters in PHP because convention uses camelCase for properties, but most databases use snake_case for columns.

```php
<?php

use Tina4\ORM;

class User extends ORM
{
    public string $tableName = "users";
    public bool $autoMap = true;  // firstName <-> first_name

    public int $id;
    public string $firstName;    // maps to first_name column
    public string $lastName;     // maps to last_name column
    public string $emailAddress; // maps to email_address column
}
```

When `$autoMap` is `true`, the ORM generates the `$fieldMapping` entries from your camelCase properties. Explicit entries in `$fieldMapping` take precedence over auto-generated ones.

---

## 3. createTable -- Schema from Models

You can create the database table directly from your model:

```php
$note = new Note($db);
$note->createTable([
    'id'         => 'INTEGER PRIMARY KEY AUTOINCREMENT',
    'title'      => 'VARCHAR(200) NOT NULL',
    'content'    => 'TEXT DEFAULT ""',
    'category'   => 'VARCHAR(50) DEFAULT "general"',
    'pinned'     => 'INTEGER DEFAULT 0',
    'created_at' => 'DATETIME',
    'updated_at' => 'DATETIME',
]);
```

This generates and runs the CREATE TABLE SQL. It is good for development and testing. For production, use migrations (Chapter 5) for version-controlled schema changes.

If you call `createTable()` with no arguments, it creates a minimal table with just the primary key column.

---

## 4. CRUD Operations

### save -- Create or Update

```php
Router::post("/api/notes", function (Request $request, Response $response) {
    $note = new Note();
    $note->title = $request->body["title"];
    $note->content = $request->body["content"] ?? "";
    $note->category = $request->body["category"] ?? "general";
    $note->pinned = $request->body["pinned"] ?? false;
    $note->save();

    return $response(["message" => "Note created", "note" => $note->toDict()], 201);
});
```

`save()` detects whether the record is new (INSERT) or existing (UPDATE) based on whether the primary key has a value and whether the record exists in the database. It returns `$this` on success (fluent chaining), or `false` on failure.

### create -- Build and Save in One Step

When you have an array of data ready, `create()` builds the model and saves it in one call:

```php
$note = Note::create([
    "title"    => "Quick Note",
    "content"  => "Created in one step",
    "category" => "general",
]);
```

`create()` is a static method. It creates a new instance, populates it from the array, calls `save()`, and returns the saved instance.

### findById -- Fetch One Record by Primary Key

```php
Router::get("/api/notes/{id}", function (Request $request, Response $response) {
    $note = Note::findById($request->params["id"]);

    if ($note === null) {
        return $response(["error" => "Note not found"], 404);
    }

    return $response($note->toDict());
});
```

`findById()` takes a primary key value and returns a model instance, or `null` if no row matches. If soft delete is enabled, it excludes soft-deleted records.

Use `findOrFail()` when you want a `RuntimeException` raised instead of `null`:

```php
$note = Note::findOrFail($id);  // Throws RuntimeException if not found
```

### find -- Query by Filter Array

The `find()` method accepts an associative array of column-value pairs and returns an array of matching records:

```php
// Find all notes in the "work" category
$workNotes = Note::find(["category" => "work"]);

// Find with pagination and ordering
$recent = Note::find(["pinned" => true], limit: 10, orderBy: "created_at DESC");

// Find all records (no filter)
$allNotes = Note::find();
```

### find() vs where() -- naming convention

The two query methods have a deliberate difference in how they handle column names:

- **`find($filter)`** uses **PHP property names**. The ORM translates them via `$fieldMapping` or `$autoMap`.
- **`where($sql)`** uses **raw DB column names** in the SQL string. No translation is done.

```php
// find() -- use PHP property names
$accounts = (new Account())->find(["accountNo" => "A001"]);    // translates to ACCOUNTNO = ?

// where() -- use DB column names directly in the SQL
$accounts = (new Account())->where("ACCOUNTNO = ?", ["A001"]); // raw SQL, no translation
```

> **Warning:** Mixing up the two is a common source of bugs. Use `find()` for portability and `where()` when you need full SQL control. Never pass DB column names to `find()`, and never use PHP property names as column names in `where()`.

### where -- Query with SQL Conditions

For more complex queries, `where()` takes a SQL WHERE clause with `?` placeholders:

```php
$notes = (new Note())->where("category = ?", ["work"]);
```

### delete -- Remove a Record

```php
Router::delete("/api/notes/{id}", function (Request $request, Response $response) {
    $note = Note::findById($request->params["id"]);

    if ($note === null) {
        return $response(["error" => "Note not found"], 404);
    }

    $note->delete();

    return $response(null, 204);
});
```

### Listing Records

```php
Router::get("/api/notes", function (Request $request, Response $response) {
    $category = $request->query["category"] ?? null;

    if ($category) {
        $notes = (new Note())->where("category = ?", [$category]);
        return $response([
            "notes" => array_map(fn(Note $n) => $n->toDict(), $notes),
            "count" => count($notes),
        ]);
    }

    $notes = (new Note())->all();

    return $response([
        "notes" => array_map(fn(Note $n) => $n->toDict(), $notes),
        "count" => count($notes),
    ]);
});
```

`where()` takes a WHERE clause with `?` placeholders and an array of parameters. It returns an array of model instances. `all()` also returns an array of model instances. Both support pagination:

```php
// With pagination
$notes = (new Note())->where("category = ?", ["work"], limit: 20, offset: 40);

// Fetch all with pagination
$result = (new Note())->all(limit: 20, offset: 0);

// SQL-first query -- full control over the SQL
$notes = (new Note())->select(
    "SELECT * FROM notes WHERE pinned = ? ORDER BY created_at DESC",
    [1], limit: 20, offset: 0
);
```

### selectOne -- Fetch a Single Record by SQL

When you need exactly one record from a custom SQL query:

```php
$note = (new Note())->selectOne("SELECT * FROM notes WHERE slug = ?", ["my-note"]);
```

Returns a model instance or `null`.

### load -- Populate an Existing Instance

The `load()` method fills an existing model instance from the database:

```php
$note = new Note();
$note->id = 42;
$note->load();  // Loads data for id=42

// Or with a filter string
$note = new Note();
$note->load("slug = ?", ["my-note"]);
```

Returns `true` if a record was found, `false` otherwise.

### count -- Count Records

```php
$total = (new Note())->count();
$workCount = (new Note())->count("category = ?", ["work"]);
```

Respects soft delete -- only counts non-deleted records.

---

## 5. toDict, toJson, and Other Serialisation

### toDict

Convert a model instance to an associative array (keyed by property names):

```php
$note = Note::findById(1);

$data = $note->toDict();
// ["id" => 1, "title" => "Shopping List", "content" => "Milk, eggs", "category" => "personal", "pinned" => false, "createdAt" => "2026-03-22 14:30:00", "updatedAt" => "2026-03-22 14:30:00"]
```

The `$include` parameter adds relationship data to the output (see Eager Loading below). Pass an array of relationship names:

```php
// Include relationships in the dict
$data = $note->toDict(["comments"]);
```

### toJson

Convert directly to a JSON string:

```php
$jsonString = $note->toJson();
// '{"id": 1, "title": "Shopping List", ...}'
```

### toArray vs toDict

This distinction matters. `toDict()` returns an associative array with property names as keys. `toArray()` returns an indexed array of values with keys stripped:

```php
$note = Note::findById(1);

$note->toDict();
// ["id" => 1, "title" => "Shopping List", "content" => "Milk, eggs"]

$note->toArray();
// [1, "Shopping List", "Milk, eggs"]
```

### toObject() -- Returns a stdClass

`toObject()` returns a PHP `stdClass` object, not an array. This differs from `toDict()` which returns an associative array:

```php
$user = (new User())->findById(1);

$obj = $user->toObject();
var_dump(is_object($obj));  // bool(true)
echo $obj->name;            // access as object property

$arr = $user->toDict();
var_dump(is_array($arr));   // bool(true)
echo $arr["name"];          // access as array key
```

### All Serialisation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `toDict($include)` | `array` | Associative array, keyed by PHP property names |
| `toAssoc($include)` | `array` | Alias for `toDict()` |
| `toObject()` | `stdClass` | PHP object (NOT an array) — properties match PHP property names |
| `toJson($include)` | `string` | JSON string |
| `toArray()` | `array` | Indexed array of values (no keys) |
| `toList()` | `array` | Alias for `toArray()` |

---

## 6. Relationships

### $foreignKeys — Auto-Wired Relationships

Declaring `public array $foreignKeys = ['user_id' => 'User']` on a model automatically wires both sides of the relationship. The declaring model gets a `belongsTo` accessor (the column name with `_id` stripped), and the referenced model gets a `hasMany` accessor (the declaring class name lowercased with `s` appended).

```php
<?php
use Tina4\ORM;

class User extends ORM
{
    public string $tableName = "users";
    public string $primaryKey = "id";
}

class Post extends ORM
{
    public string $tableName = "posts";
    public string $primaryKey = "id";

    // Auto-wires $post->user (belongs_to) and $user->posts (has_many)
    public array $foreignKeys = [
        'user_id' => 'User',
    ];
}
```

With just the `$foreignKeys` array, both sides are accessible:

```php
$post = new Post($db);
$post->load('id = 1');
echo $post->user->name;              // "Alice"

$user = new User($db);
$user->load('id = 1');
foreach ($user->posts as $post) {
    echo $post->title . "\n";
}
```

For a custom `has_many` key, use the extended form:

```php
public array $foreignKeys = [
    'user_id' => ['model' => 'User', 'related_name' => 'blog_posts'],
];
// $user->blog_posts instead of $user->posts
```

### hasMany

An author has many posts:

Create `src/orm/Author.php`:

```php
<?php

use Tina4\ORM;

class Author extends ORM
{
    public string $tableName = "authors";

    public int $id;
    public string $name;
    public string $email;
    public string $bio = "";
    public string $createdAt;
}
```

Create `src/orm/BlogPost.php`:

```php
<?php

use Tina4\ORM;

class BlogPost extends ORM
{
    public string $tableName = "posts";

    public int $id;
    public int $authorId;
    public string $title;
    public string $slug;
    public string $content = "";
    public string $status = "draft";
    public string $createdAt;
    public string $updatedAt;
}
```

Now use `hasMany()` to get an author's posts:

```php
Router::get("/api/authors/{id}", function (Request $request, Response $response) {
    $author = Author::findById($request->params["id"]);

    if ($author === null) {
        return $response(["error" => "Author not found"], 404);
    }

    $posts = $author->hasMany(BlogPost::class, "author_id");

    $data = $author->toDict();
    $data["posts"] = array_map(fn(BlogPost $p) => $p->toDict(), $posts);

    return $response($data);
});
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

### hasOne

A user has one profile:

```php
$profile = $user->hasOne(Profile::class, "user_id");
```

Returns a single model instance or `null`.

### belongsTo

A post belongs to an author:

```php
Router::get("/api/posts/{id}", function (Request $request, Response $response) {
    $post = BlogPost::findById($request->params["id"]);

    if ($post === null) {
        return $response(["error" => "Post not found"], 404);
    }

    $author = $post->belongsTo(Author::class, "author_id");

    $data = $post->toDict();
    $data["author"] = $author ? $author->toDict() : null;

    return $response($data);
});
```

```json
{
  "id": 1,
  "authorId": 1,
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

### Declarative Relationships

Instead of calling relationship methods in every route, declare them as array properties on the model. Each entry is a two-element array: `[ClassName, foreign_key_column]`.

```php
<?php

use Tina4\ORM;

class Author extends ORM
{
    public string $tableName = "authors";
    public array $hasMany = [
        ["BlogPost", "author_id"],
    ];

    public int $id;
    public string $name;
    public string $email;
}
```

```php
<?php

use Tina4\ORM;

class BlogPost extends ORM
{
    public string $tableName = "posts";
    public array $hasOne = [
        ["Author", "author_id"],
    ];
    public array $hasMany = [
        ["Comment", "post_id"],
    ];

    public int $id;
    public int $authorId;
    public string $title;
    public string $content = "";
}
```

With declarative relationships, accessing the magic property triggers lazy loading. The property name is the lowercase class name (or the lowercase plural for `hasMany`):

```php
$author = (new Author())->findById(1);
$posts  = $author->posts;   // Lazy-loads BlogPost records via the hasMany declaration

$post   = (new BlogPost())->findById(1);
$author = $post->author;    // Lazy-loads the related Author via hasOne
```

---

## 7. Eager Loading

Calling relationship methods inside a loop creates the N+1 problem. Load 10 authors. Call `hasMany(BlogPost::class, "author_id")` for each one. That fires 11 queries -- 1 for authors, 10 for posts. The page drags.

The `$include` parameter on `toDict()` and `selectOne()` solves this. It eager-loads relationships in bulk.

For models with declarative relationships (`$hasOne`, `$hasMany`, `$belongsTo` array properties), pass a list of relationship names:

```php
// Eager load posts when serialising an author
$author = Author::findById(1);
$data = $author->toDict(["posts"]);

// Eager load author and comments when serialising a post
$post = BlogPost::findById(1);
$data = $post->toDict(["author", "comments"]);
```

### Nested Eager Loading

Dot notation loads multiple levels deep:

```php
// Load author with posts, and each post with its comments
$data = $author->toDict(["posts", "posts.comments"]);
```

Authors, their posts, and each post's comments. Three queries total instead of hundreds.

### toDict with Nested Includes

When eager loading is active, `toDict()` embeds the related data:

```php
$post = BlogPost::findById(1);
$data = $post->toDict(["author", "comments"]);
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
    {"id": 1, "body": "Great post!", "authorName": "Bob"}
  ]
}
```

---

## 8. Soft Delete

Sometimes a record needs to disappear from queries without leaving the database. Soft delete handles this. The row stays. A flag marks it as deleted. Queries skip it.

```php
<?php

use Tina4\ORM;

class Task extends ORM
{
    public string $tableName = "tasks";
    public bool $softDelete = true;  // Enable soft delete

    public int $id;
    public string $title;
    public bool $completed = false;
    public int $isDeleted = 0;  // Required for soft delete (0 = active, 1 = deleted)
    public string $createdAt;
}
```

When `$softDelete` is `true`, the ORM changes its behaviour:

- `$task->delete()` sets `is_deleted` to `1` instead of running a DELETE query
- `Task::find()`, `(new Task)->where()`, and `Task::findById()` filter out records where `is_deleted = 1`
- `$task->restore()` sets `is_deleted` back to `0` and makes the record visible again
- `$task->forceDelete()` permanently removes the row from the database
- `(new Task)->withTrashed()` includes soft-deleted records in query results

The soft delete column is `is_deleted` (integer, 0 or 1). There is no `deleted_at` timestamp column -- just the flag.

### Deleting and Restoring

```php
// Soft delete -- sets is_deleted = 1, row stays in the database
$task = Task::findById(1);
$task->delete();

// Restore -- sets is_deleted = 0, record is visible again
$task->restore();

// Permanently delete -- removes the row, no recovery possible
$task->forceDelete();
```

`restore()` is the inverse of `delete()`. It sets `is_deleted` back to `0` and commits the change. The record reappears in all standard queries.

### Including Soft-Deleted Records

Standard queries (`all()`, `where()`, `findById()`) exclude soft-deleted records. When you need to see everything -- for admin dashboards, audit logs, or data recovery -- use `withTrashed()`:

```php
// All tasks, including soft-deleted ones
$allTasks = (new Task())->withTrashed();

// Soft-deleted tasks matching a condition
$deletedTasks = (new Task())->withTrashed("completed = ?", [1]);
```

`withTrashed()` accepts the same filter parameters as `where()`. The only difference: it ignores the `is_deleted` filter that standard queries apply.

### Counting with Soft Delete

The `count()` method respects soft delete. It only counts non-deleted records:

```php
$activeCount = (new Task())->count();
$activeWork = (new Task())->count("category = ?", ["work"]);
```

### When to Use Soft Delete

Soft delete suits data that users might want to recover -- emails, documents, user accounts. It also serves audit requirements where regulations demand retention. For temporary data (sessions, cache entries, logs), hard delete keeps the table lean.

---

## 9. Auto-CRUD

Writing the same five REST endpoints for every model gets tedious. Auto-CRUD generates them from your model class. Define the model. Register it. Five routes appear.

### The autoCrud Flag

The simplest approach -- set `$autoCrud = true` on your model class:

```php
<?php

use Tina4\ORM;

class Note extends ORM
{
    public string $tableName = "notes";
    public bool $autoCrud = true;  // Generates REST endpoints automatically

    public int $id;
    public string $title;
    public string $content = "";
}
```

The moment PHP loads this class, the ORM registers it with AutoCrud. Five routes appear.

### Manual Registration

You can also register models explicitly using the `AutoCrud` class:

```php
use Tina4\AutoCrud;
use Tina4\Database\Database;

$db = Database::create("sqlite:///path/to/app.db");
$crud = new AutoCrud($db);
$crud->register(Note::class);
$crud->generateRoutes();
```

Both approaches produce the same result:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all with pagination (`limit`, `offset` params) |
| `GET` | `/api/notes/{id}` | Get one by primary key |
| `POST` | `/api/notes` | Create a new record |
| `PUT` | `/api/notes/{id}` | Update a record |
| `DELETE` | `/api/notes/{id}` | Delete a record |

The endpoint prefix derives from the table name. The `notes` table becomes `/api/notes`. Pass a custom prefix to the `AutoCrud` constructor to change it:

```php
$crud = new AutoCrud($db, prefix: "/api/v2");
// Routes: /api/v2/notes, /api/v2/notes/{id}, etc.
```

### Auto-Discovering Models

Rather than registering each model by hand, point `discover()` at your models directory. It scans every `.php` file, finds ORM subclasses, and registers them all:

```php
use Tina4\AutoCrud;

$crud = new AutoCrud($db);
$crud->discover("src/orm");
$crud->generateRoutes();
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

**POST /api/notes** creates a record:

```bash
curl -X POST http://localhost:7146/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "New Note", "content": "Created via auto-CRUD"}'
```

**DELETE /api/notes/1** respects soft delete. If the model has `$softDelete = true`, the record is marked deleted instead of removed.

### Sorting and Filtering

The list endpoint accepts `sort` and `filter` query parameters:

```bash
# Sort by name descending, then created_at ascending
curl "http://localhost:7146/api/notes?sort=-name,created_at"

# Filter by column values
curl "http://localhost:7146/api/notes?filter[category]=work"
```

The `-` prefix on a sort field means descending order.

### Custom Routes Alongside Auto-CRUD

Custom routes defined in `src/routes/` load before auto-CRUD routes. They take precedence. If you need special logic for one endpoint (custom validation, side effects, complex queries), define that route manually. Auto-CRUD handles the rest.

### Introspection

Check which models are registered:

```php
$crud = new AutoCrud($db);
$crud->register(Note::class);
$registered = $crud->getModels();
// ["notes" => "Note"]
```

---

## 10. Database Connection

### Setting the Global Database

The ORM needs a database connection. Three ways to provide one:

```php
use Tina4\ORM;
use Tina4\Database\Database;

// Option 1: Set globally on ORM
$db = Database::create("sqlite:///path/to/app.db");
ORM::setGlobalDb($db);

// Option 2: Set via App
App::setDatabase($db);

// Option 3: Set DATABASE_URL in .env (auto-discovered)
// DATABASE_URL=sqlite:///path/to/app.db
```

Once a global database is set, all ORM models resolve it. You can also pass a database adapter to a specific instance:

```php
$note = new Note($db);
```

The resolution order is: instance `$_db` -> global `ORM::setGlobalDb()` -> `App::getDatabase()` -> `Database::fromEnv()`. If none is found, the ORM throws a `RuntimeException`.

---

## 11. Raw SQL and DatabaseResult

When you drop below the ORM to execute raw SQL, `$db->fetch()` returns a `DatabaseResult` object. This object has a `->records` property containing the rows -- it is **not** a plain array.

```php
$result = $db->fetch("SELECT * FROM users WHERE active = ?", [1]);

// WRONG -- $result is not an array:
foreach ($result['data'] as $row) { ... }

// RIGHT -- iterate over ->records:
foreach ($result->records as $row) {
    echo $row->name;
}
```

`$result->records` is an array of `stdClass` objects, one per row. Column names map to object properties.

```php
// Fetch a single row
$result = $db->fetch("SELECT * FROM users WHERE id = ?", [42]);
if (!empty($result->records)) {
    $user = $result->records[0];
    echo $user->email;
}
```

> **Note:** ORM methods (`findById()`, `find()`, `where()`, etc.) return model instances or arrays of model instances -- not `DatabaseResult`. The `DatabaseResult` object only appears when you call `$db->fetch()` directly.

---

## 12. Scopes

Scopes are reusable query filters baked into the model. Register them with the `scope()` method, then call them as static methods:

```php
<?php

use Tina4\ORM;

class BlogPost extends ORM
{
    public string $tableName = "posts";

    public int $id;
    public string $title;
    public string $status = "draft";
    public string $createdAt;
}

// Register scopes
(new BlogPost())->scope("published", "status = ?", ["published"]);
(new BlogPost())->scope("drafts", "status = ?", ["draft"]);
```

Use them in your routes:

```php
Router::get("/api/posts/published", function (Request $request, Response $response) {
    $posts = BlogPost::published();
    return $response(["posts" => array_map(fn($p) => $p->toDict(), $posts)]);
});

Router::get("/api/posts/drafts", function (Request $request, Response $response) {
    $posts = BlogPost::drafts();
    return $response(["posts" => array_map(fn($p) => $p->toDict(), $posts)]);
});
```

Scopes accept `$limit` and `$offset` as arguments:

```php
$recentPublished = BlogPost::published(10, 0);  // limit 10, offset 0
```

Scopes keep query logic in the model where it belongs. Route handlers stay thin.

---

## 13. Input Validation

Override the `validate()` method on your model to add validation rules:

```php
<?php

use Tina4\ORM;

class Product extends ORM
{
    public string $tableName = "products";

    public int $id;
    public string $name;
    public string $sku;
    public float $price;
    public string $category;

    public function validate(): array
    {
        $errors = [];

        if (empty($this->name) || strlen($this->name) < 2) {
            $errors[] = "name: Must be at least 2 characters";
        }
        if (strlen($this->name) > 200) {
            $errors[] = "name: Must be at most 200 characters";
        }
        if (!preg_match('/^[A-Z]{2}-\d{4}$/', $this->sku ?? '')) {
            $errors[] = "sku: Must match pattern XX-0000 (e.g., EL-1234)";
        }
        if (($this->price ?? 0) < 0.01 || ($this->price ?? 0) > 999999.99) {
            $errors[] = "price: Must be between 0.01 and 999999.99";
        }
        if (!in_array($this->category ?? '', ["Electronics", "Kitchen", "Office", "Fitness"])) {
            $errors[] = "category: Must be one of: Electronics, Kitchen, Office, Fitness";
        }

        return $errors;
    }
}
```

```php
Router::post("/api/products", function (Request $request, Response $response) {
    $product = new Product();
    $product->name = $request->body["name"] ?? "";
    $product->sku = $request->body["sku"] ?? "";
    $product->price = $request->body["price"] ?? 0;
    $product->category = $request->body["category"] ?? "";

    $errors = $product->validate();
    if (!empty($errors)) {
        return $response(["errors" => $errors], 400);
    }

    $product->save();
    return $response(["product" => $product->toDict()], 201);
});
```

If validation fails, `validate()` returns an array of error messages:

```json
{
  "errors": [
    "name: Must be at least 2 characters",
    "sku: Must match pattern XX-0000 (e.g., EL-1234)",
    "price: Must be between 0.01 and 999999.99",
    "category: Must be one of: Electronics, Kitchen, Office, Fitness"
  ]
}
```

---

## 14. QueryBuilder Integration

ORM models provide a `query()` static method that returns a `QueryBuilder` pre-configured with the model's table name and database connection. This gives you a fluent API for building complex queries without writing raw SQL:

```php
// Fluent query builder from ORM
$results = User::query()
    ->select("id", "name", "email")
    ->where("active = ?", [1])
    ->orderBy("name")
    ->limit(50)
    ->get();

// First matching record
$user = User::query()
    ->where("email = ?", ["alice@example.com"])
    ->first();

// Count
$total = User::query()
    ->where("role = ?", ["admin"])
    ->count();

// Check existence
$exists = User::query()
    ->where("email = ?", ["test@example.com"])
    ->exists();
```

See the [QueryBuilder chapter](07-query-builder.md) for the full fluent API including joins, grouping, having, and MongoDB support.

---

## 15. Exercise: Build a Blog with Relationships

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
| `GET` | `/api/authors/{id}` | Get author with their posts |
| `POST` | `/api/posts` | Create a post (requires author_id) |
| `GET` | `/api/posts` | List published posts with author info |
| `GET` | `/api/posts/{id}` | Get post with author and comments |
| `POST` | `/api/posts/{id}/comments` | Add comment to a post |

---

## 16. Solution

Create `src/orm/Author.php`:

```php
<?php

use Tina4\ORM;

class Author extends ORM
{
    public string $tableName = "authors";

    public int $id;
    public string $name;
    public string $email;
    public string $bio = "";
    public string $createdAt;

    public function validate(): array
    {
        $errors = [];
        if (empty($this->name) || strlen($this->name) < 2) {
            $errors[] = "name: Must be at least 2 characters";
        }
        if (empty($this->email)) {
            $errors[] = "email: Required";
        }
        return $errors;
    }
}
```

Create `src/orm/BlogPost.php`:

```php
<?php

use Tina4\ORM;

class BlogPost extends ORM
{
    public string $tableName = "posts";

    public int $id;
    public int $authorId;
    public string $title;
    public string $slug;
    public string $content = "";
    public string $status = "draft";
    public string $createdAt;
    public string $updatedAt;

    public function validate(): array
    {
        $errors = [];
        if (empty($this->title)) {
            $errors[] = "title: Required";
        }
        if (strlen($this->title ?? '') > 300) {
            $errors[] = "title: Must be at most 300 characters";
        }
        if (empty($this->slug)) {
            $errors[] = "slug: Required";
        }
        if (!in_array($this->status ?? 'draft', ["draft", "published", "archived"])) {
            $errors[] = "status: Must be one of: draft, published, archived";
        }
        return $errors;
    }
}
```

Register a scope for published posts:

```php
(new BlogPost())->scope("published", "status = ?", ["published"]);
```

Create `src/orm/Comment.php`:

```php
<?php

use Tina4\ORM;

class Comment extends ORM
{
    public string $tableName = "comments";

    public int $id;
    public int $postId;
    public string $authorName;
    public string $authorEmail;
    public string $body;
    public string $createdAt;

    public function validate(): array
    {
        $errors = [];
        if (empty($this->authorName)) {
            $errors[] = "authorName: Required";
        }
        if (empty($this->authorEmail)) {
            $errors[] = "authorEmail: Required";
        }
        if (empty($this->body) || strlen($this->body) < 5) {
            $errors[] = "body: Must be at least 5 characters";
        }
        return $errors;
    }
}
```

Create `src/routes/blog.php`:

```php
<?php

use Tina4\Router;
use Tina4\Request;
use Tina4\Response;

Router::post("/api/authors", function (Request $request, Response $response) {
    $author = new Author();
    $author->name = $request->body["name"] ?? "";
    $author->email = $request->body["email"] ?? "";
    $author->bio = $request->body["bio"] ?? "";

    $errors = $author->validate();
    if (!empty($errors)) {
        return $response(["errors" => $errors], 400);
    }

    $author->save();
    return $response(["author" => $author->toDict()], 201);
});

Router::get("/api/authors/{id}", function (Request $request, Response $response) {
    $author = Author::findById($request->params["id"]);

    if ($author === null) {
        return $response(["error" => "Author not found"], 404);
    }

    $posts = $author->hasMany(BlogPost::class, "author_id");

    $data = $author->toDict();
    $data["posts"] = array_map(fn(BlogPost $p) => $p->toDict(), $posts);

    return $response($data);
});

Router::post("/api/posts", function (Request $request, Response $response) {
    $body = $request->body;

    // Verify author exists
    $author = Author::findById($body["author_id"] ?? 0);
    if ($author === null) {
        return $response(["error" => "Author not found"], 404);
    }

    $post = new BlogPost();
    $post->authorId = $body["author_id"];
    $post->title = $body["title"] ?? "";
    $post->slug = $body["slug"] ?? "";
    $post->content = $body["content"] ?? "";
    $post->status = $body["status"] ?? "draft";

    $errors = $post->validate();
    if (!empty($errors)) {
        return $response(["errors" => $errors], 400);
    }

    $post->save();
    return $response(["post" => $post->toDict()], 201);
});

Router::get("/api/posts", function (Request $request, Response $response) {
    $posts = BlogPost::published();
    $data = [];

    foreach ($posts as $p) {
        $postDict = $p->toDict();
        $author = $p->belongsTo(Author::class, "author_id");
        $postDict["author"] = $author ? $author->toDict() : null;
        $data[] = $postDict;
    }

    return $response(["posts" => $data, "count" => count($data)]);
});

Router::get("/api/posts/{id}", function (Request $request, Response $response) {
    $post = BlogPost::findById($request->params["id"]);

    if ($post === null) {
        return $response(["error" => "Post not found"], 404);
    }

    $author = $post->belongsTo(Author::class, "author_id");
    $comments = $post->hasMany(Comment::class, "post_id");

    $data = $post->toDict();
    $data["author"] = $author ? $author->toDict() : null;
    $data["comments"] = array_map(fn(Comment $c) => $c->toDict(), $comments);
    $data["commentCount"] = count($comments);

    return $response($data);
});

Router::post("/api/posts/{id}/comments", function (Request $request, Response $response) {
    $post = BlogPost::findById($request->params["id"]);

    if ($post === null) {
        return $response(["error" => "Post not found"], 404);
    }

    $comment = new Comment();
    $comment->postId = (int)$request->params["id"];
    $comment->authorName = $request->body["author_name"] ?? "";
    $comment->authorEmail = $request->body["author_email"] ?? "";
    $comment->body = $request->body["body"] ?? "";

    $errors = $comment->validate();
    if (!empty($errors)) {
        return $response(["errors" => $errors], 400);
    }

    $comment->save();
    return $response(["comment" => $comment->toDict()], 201);
});
```

---

## 17. Gotchas

### 1. Forgetting to call save()

**Problem:** You set properties on a model but the database does not change.

**Cause:** Setting `$note->title = "New Title"` only changes the PHP object. The database remains unchanged until you call `$note->save()`.

**Fix:** Call `save()` after modifying properties. Check the return value -- `save()` returns `$this` on success and `false` on failure.

### 2. findById() returns null

**Problem:** You call `Note::findById($id)` but get `null` instead of a note object.

**Cause:** `findById()` returns `null` when no row matches the given primary key. If soft delete is enabled, `findById()` also excludes soft-deleted records.

**Fix:** Check for `null` after `findById()`: `if ($note === null) { return $response(["error" => "Not found"], 404); }`. Use `findOrFail()` if you want a `RuntimeException` raised instead.

### 3. find() vs findById()

**Problem:** You call `Note::find(42)` expecting a single record, but get a type error.

**Cause:** `find()` takes an associative array filter (`find(["id" => 42])`), not a bare primary key value. For single-record lookups by primary key, use `findById(42)`.

**Fix:** Use `findById($id)` for primary key lookups. Use `find(["column" => $value])` for filter-based queries.

### 4. Static vs instance methods

**Problem:** You call `Note::where("category = ?", ["work"])` but get an error.

**Cause:** `where()`, `all()`, `select()`, `selectOne()`, `count()`, and `withTrashed()` are instance methods. `findById()`, `findOrFail()`, `find()`, `create()`, and `query()` are static methods.

**Fix:** For instance methods, create an instance first: `(new Note())->where(...)`. Static methods call directly: `Note::findById(...)`.

### 5. toDict() includes everything

**Problem:** `$user->toDict()` includes `passwordHash` in the API response.

**Cause:** `toDict()` includes all fields by default.

**Fix:** Build the response array manually, omitting sensitive fields: `["id" => $user->id, "name" => $user->name, "email" => $user->email]`. Or create a helper method on your model class that returns only safe fields.

### 6. Validation only runs on validate()

**Problem:** You call `save()` without calling `validate()` first, and invalid data gets into the database.

**Cause:** `save()` does not validate. This is by design -- sometimes you need to save partial data or bypass validation for bulk operations.

**Fix:** Call `$errors = $model->validate()` before `save()` in your route handlers.

### 7. Soft delete column is is_deleted, not deleted_at

**Problem:** You add a `deleted_at` timestamp column expecting soft delete to use it.

**Cause:** Tina4's soft delete uses an `is_deleted` integer column (0 = active, 1 = deleted). It does not use a `deleted_at` timestamp.

**Fix:** Add an `is_deleted` integer column to your table with a default of `0`. Set `$softDelete = true` on the model.

### 8. N+1 query problem

**Problem:** Listing 100 authors with their posts runs 101 queries (1 for authors + 100 for posts), and the page loads slowly.

**Cause:** You call `$author->hasMany(BlogPost::class, "author_id")` inside a loop for each author.

**Fix:** Use declarative relationships with `$hasMany`/`$hasOne`/`$belongsTo` array properties and eager loading via `toDict(["posts"])`. Or fetch all posts in a single query and group them manually.

### 9. Auto-CRUD endpoint conflicts

**Problem:** Custom route at `/api/notes/{id}` stops working after registering Auto-CRUD for the Note model.

**Cause:** Both routes match the same path. The first registered route wins.

**Fix:** Custom routes in `src/routes/` load before Auto-CRUD routes. They take precedence. If you want different behaviour, use a different path for the custom route.

### 10. Soft-deleted records appearing in queries

**Problem:** You soft-deleted a record, but queries still return it.

**Cause:** Soft delete requires the `$softDelete = true` flag on the model class and an `is_deleted` column in the database table. Without both, soft delete is inactive.

**Fix:** Verify both the `$softDelete = true` flag and the `is_deleted` column exist. The column stores `0` for active records and `1` for deleted ones.

### 11. $db->fetch() returns DatabaseResult, not an array

**Problem:** You call `$db->fetch(...)` and try to iterate over it as an array, getting a type error or empty results.

**Cause:** `$db->fetch()` returns a `DatabaseResult` object. The rows are in `$result->records`, not in `$result['data']` or `$result` itself.

**Fix:** Access `->records`:

```php
// WRONG:
foreach ($result['data'] as $row) { ... }

// RIGHT:
foreach ($result->records as $row) { ... }
```

This only applies to raw `$db->fetch()` calls. ORM methods (`findById()`, `find()`, `where()`, etc.) return model instances directly.
