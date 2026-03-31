# Chapter 6: ORM

## 1. From SQL to Objects

Chapter 5 used raw SQL for every operation. It works. It also repeats. The same `INSERT INTO products (name, price, ...) VALUES (:name, :price, ...)` pattern shows up in every route. The ORM replaces that repetition with PHP classes. Define a class. Map it to a table. Call `save()`, `load()`, `delete()`.

Tina4's ORM stays minimal. It does not hide SQL. It gives you methods for common operations and steps aside when you need raw queries.

---

## 2. Defining a Model

ORM models live in `src/orm/`. Every `.php` file in that directory is auto-loaded, just like route files.

Create `src/orm/Product.php`:

```php
<?php
use Tina4\ORM;

class Product extends ORM
{
    public int $id;
    public string $name;
    public string $category = "Uncategorized";
    public float $price = 0.00;
    public bool $inStock = true;
    public string $createdAt;
    public string $updatedAt;

    // Map to the "products" table
    public string $tableName = "products";

    // Primary key field
    public string $primaryKey = "id";
}
```

A complete model. Here is what each piece does:

- **Extends `ORM`** -- Gives you `save()`, `load()`, `delete()`, `select()`, and other methods.
- **Public properties** -- Each one maps to a database column. Property names are `camelCase`. Column names are `snake_case`. Tina4 converts automatically: `inStock` maps to `in_stock`, `createdAt` maps to `created_at`.
- **`$tableName`** -- The database table. Omit it and Tina4 infers from the class name: `Product` becomes `products`, `OrderItem` becomes `order_items`.
- **`$primaryKey`** -- The primary key column. Defaults to `"id"`.
- **Default values** -- Properties like `$category = "Uncategorized"` apply when creating new records without specifying those fields.

### Auto-Mapping with `$autoMap`

By default, you must declare every property or use `$fieldMapping` to map database columns to PHP properties. Setting `$autoMap = true` lets Tina4 auto-generate mappings from `snake_case` database columns to `camelCase` properties:

```php
class Product extends ORM
{
    public string $tableName = "products";
    public string $primaryKey = "id";
    public bool $autoMap = true;

    public int $id;
    public string $productName;   // auto-maps to "product_name"
    public float $unitPrice;      // auto-maps to "unit_price"
    public bool $inStock;         // auto-maps to "in_stock"
}
```

With `$autoMap = true`, when Tina4 loads data from the database, it automatically converts `snake_case` column names to `camelCase` property names using the built-in `snakeToCamel()` helper (and `camelToSnake()` when saving). Explicit `$fieldMapping` entries always take precedence over auto-mapped ones.

---

## 3. Field Types

PHP type declarations on properties. Tina4 uses them for DDL generation and data validation:

| PHP Type | Database Type (SQLite) | Database Type (PostgreSQL) | Notes |
|----------|----------------------|---------------------------|-------|
| `int` | INTEGER | INTEGER | Whole numbers |
| `string` | TEXT | VARCHAR(255) | Text fields |
| `float` | REAL | DOUBLE PRECISION | Decimal numbers |
| `bool` | INTEGER | BOOLEAN | SQLite stores as 0/1 |
| `?string` | TEXT (nullable) | VARCHAR(255) NULL | Nullable with `?` prefix |

### Nullable Fields

PHP nullable type syntax:

```php
public ?string $description = null;
public ?float $discount = null;
```

The `?` prefix allows `null` in the database column.

### Primary Keys and Auto-Increment

Tina4 treats `$primaryKey` as auto-incrementing by default. Call `save()` on a new object (primary key not set) and the database generates the ID:

```php
$product = new Product();
$product->name = "Widget";
$product->price = 9.99;
$product->save();

echo $product->id; // Auto-generated: 1, 2, 3, ...
```

---

## 4. Creating and Saving Records

### save() -- Insert or Update

`save()` inspects the primary key. Not set: INSERT. Already set: UPDATE.

```php
<?php
use Tina4\Router;

Router::post("/api/products", function ($request, $response) {
    $body = $request->body;

    $product = new Product();
    $product->name = $body["name"];
    $product->category = $body["category"] ?? "Uncategorized";
    $product->price = (float) ($body["price"] ?? 0);
    $product->inStock = (bool) ($body["in_stock"] ?? true);
    $product->save();

    return $response->json($product->toArray(), 201);
});
```

```bash
curl -X POST http://localhost:7146/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Wireless Keyboard", "category": "Electronics", "price": 79.99}'
```

```json
{
  "id": 1,
  "name": "Wireless Keyboard",
  "category": "Electronics",
  "price": 79.99,
  "in_stock": true,
  "created_at": "2026-03-22 14:30:00",
  "updated_at": "2026-03-22 14:30:00"
}
```

### Updating an Existing Record

When `id` is set, `save()` performs an UPDATE:

```php
Router::put("/api/products/{id:int}", function ($request, $response) {
    $product = new Product();
    $product->load($request->params["id"]);

    if (empty($product->id)) {
        return $response->json(["error" => "Product not found"], 404);
    }

    $body = $request->body;
    $product->name = $body["name"] ?? $product->name;
    $product->price = (float) ($body["price"] ?? $product->price);
    $product->category = $body["category"] ?? $product->category;
    $product->save();

    return $response->json($product->toArray());
});
```

---

## 5. Loading Records

### load() -- Get by Primary Key

```php
$product = new Product();
$product->load(42);

if (empty($product->id)) {
    // Product with ID 42 not found
}
```

`load()` populates the object from the database row matching the primary key. No match leaves properties at their defaults (or unset).

### A Simple Get Endpoint

```php
Router::get("/api/products/{id:int}", function ($request, $response) {
    $product = new Product();
    $product->load($request->params["id"]);

    if (empty($product->id)) {
        return $response->json(["error" => "Product not found"], 404);
    }

    return $response->json($product->toArray());
});
```

```bash
curl http://localhost:7146/api/products/1
```

```json
{
  "id": 1,
  "name": "Wireless Keyboard",
  "category": "Electronics",
  "price": 79.99,
  "in_stock": true,
  "created_at": "2026-03-22 14:30:00",
  "updated_at": "2026-03-22 14:30:00"
}
```

---

## 6. Deleting Records

### delete()

```php
Router::delete("/api/products/{id:int}", function ($request, $response) {
    $product = new Product();
    $product->load($request->params["id"]);

    if (empty($product->id)) {
        return $response->json(["error" => "Product not found"], 404);
    }

    $product->delete();

    return $response->json(null, 204);
});
```

`delete()` removes the row from the database. The object stays in memory. The database row is gone.

---

## 7. Querying with select()

`select()` finds records with filters, ordering, and pagination.

### Basic Select

```php
$product = new Product();
$products = $product->select("*");
```

Returns an array of Product objects. All records.

### Filtering

```php
$product = new Product();

// Simple filter
$electronics = $product->select("*", "category = :category", ["category" => "Electronics"]);

// Multiple conditions
$affordable = $product->select("*", "price < :maxPrice AND in_stock = :inStock", [
    "maxPrice" => 100,
    "inStock" => 1
]);
```

### Ordering

```php
$product = new Product();
$sorted = $product->select("*", "", [], "price DESC");
```

Fourth argument: ORDER BY clause.

### Pagination

```php
$product = new Product();

$page = 1;
$perPage = 10;
$offset = ($page - 1) * $perPage;

$products = $product->select("*", "", [], "name ASC", $perPage, $offset);
```

Fifth argument: LIMIT. Sixth: OFFSET.

### A Full List Endpoint with Filters

```php
<?php
use Tina4\Router;

Router::get("/api/products", function ($request, $response) {
    $product = new Product();

    $category = $request->params["category"] ?? "";
    $minPrice = (float) ($request->params["min_price"] ?? 0);
    $maxPrice = (float) ($request->params["max_price"] ?? 999999);
    $page = (int) ($request->params["page"] ?? 1);
    $perPage = (int) ($request->params["per_page"] ?? 20);
    $sort = $request->params["sort"] ?? "name";
    $order = strtoupper($request->params["order"] ?? "ASC");

    // Build filter
    $conditions = [];
    $params = [];

    if (!empty($category)) {
        $conditions[] = "category = :category";
        $params["category"] = $category;
    }

    $conditions[] = "price >= :minPrice AND price <= :maxPrice";
    $params["minPrice"] = $minPrice;
    $params["maxPrice"] = $maxPrice;

    $filter = implode(" AND ", $conditions);

    // Validate sort field
    $allowedSorts = ["name", "price", "category", "created_at"];
    if (!in_array($sort, $allowedSorts)) {
        $sort = "name";
    }
    if ($order !== "ASC" && $order !== "DESC") {
        $order = "ASC";
    }

    $offset = ($page - 1) * $perPage;

    $products = $product->select("*", $filter, $params, $sort . " " . $order, $perPage, $offset);

    $results = array_map(fn($p) => $p->toArray(), $products);

    return $response->json([
        "products" => $results,
        "page" => $page,
        "per_page" => $perPage,
        "count" => count($results)
    ]);
});
```

```bash
curl "http://localhost:7146/api/products?category=Electronics&sort=price&order=DESC&page=1&per_page=5"
```

```json
{
  "products": [
    {"id": 4, "name": "Standing Desk", "category": "Electronics", "price": 549.99, "in_stock": true},
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": true}
  ],
  "page": 1,
  "per_page": 5,
  "count": 2
}
```

---

## 8. Creating Tables from Models

Generate the table directly from your model:

```php
$product = new Product();
$product->createTable();
```

Tina4 reads the properties, types, and defaults from the class and generates the correct `CREATE TABLE` statement for your database engine.

CLI alternative:

```bash
tina4 orm:create-table Product
```

```
Created table "products" with 7 columns.
```

Handy during early development. For production, use migrations (Chapter 5) so schema changes are versioned and reversible.

---

## 9. Relationships

### hasMany -- One-to-Many

A user has many posts.

Create `src/orm/User.php`:

```php
<?php
use Tina4\ORM;

class User extends ORM
{
    public int $id;
    public string $name;
    public string $email;
    public string $createdAt;

    public string $tableName = "users";
    public string $primaryKey = "id";

    public function posts(): array
    {
        return $this->hasMany(Post::class, "user_id");
    }
}
```

Create `src/orm/Post.php`:

```php
<?php
use Tina4\ORM;

class Post extends ORM
{
    public int $id;
    public int $userId;
    public string $title;
    public string $body;
    public string $createdAt;

    public string $tableName = "posts";
    public string $primaryKey = "id";

    public function user(): ?User
    {
        return $this->belongsTo(User::class, "user_id");
    }

    public function comments(): array
    {
        return $this->hasMany(Comment::class, "post_id");
    }
}
```

The second argument to `hasMany()` is the foreign key on the related table. `$this->hasMany(Post::class, "user_id")` means: find all rows in `posts` where `user_id` equals this user's ID.

### hasOne -- One-to-One

```php
public function profile(): ?Profile
{
    return $this->hasOne(Profile::class, "user_id");
}
```

Same as `hasMany()` but returns a single object.

### belongsTo -- Inverse Relationship

A post belongs to a user:

```php
public function user(): ?User
{
    return $this->belongsTo(User::class, "user_id");
}
```

`belongsTo(User::class, "user_id")` means: load the User where `users.id` equals `this->user_id`.

### Using Relationships

```php
Router::get("/api/users/{id:int}", function ($request, $response) {
    $user = new User();
    $user->load($request->params["id"]);

    if (empty($user->id)) {
        return $response->json(["error" => "User not found"], 404);
    }

    $posts = $user->posts();

    return $response->json([
        "user" => $user->toArray(),
        "posts" => array_map(fn($p) => $p->toArray(), $posts),
        "post_count" => count($posts)
    ]);
});
```

```bash
curl http://localhost:7146/api/users/1
```

```json
{
  "user": {"id": 1, "name": "Alice", "email": "alice@example.com"},
  "posts": [
    {"id": 1, "user_id": 1, "title": "First Post", "body": "Hello world!"},
    {"id": 3, "user_id": 1, "title": "Second Post", "body": "Another one."}
  ],
  "post_count": 2
}
```

---

## 10. Eager Loading

Calling relationship methods inside a loop triggers the N+1 problem. Load 100 users. Call `$user->posts()` for each one. That fires 101 queries. One for users. One hundred for posts.

Use the `include` parameter with `select()` to eager-load:

```php
$user = new User();
$users = $user->select("*", "", [], "name ASC", 20, 0, ["posts"]);
```

The seventh argument is an array of relationship names. Two queries total: one for users, one for all related posts. Tina4 stitches the results together.

### toArray() with Nested Includes

When eager loading is active, `toArray()` includes the related data:

```php
$user = new User();
$users = $user->select("*", "", [], "", 0, 0, ["posts"]);

$result = array_map(fn($u) => $u->toArray(), $users);

return $response->json($result);
```

```json
[
  {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com",
    "posts": [
      {"id": 1, "title": "First Post", "body": "Hello world!"},
      {"id": 3, "title": "Second Post", "body": "Another one."}
    ]
  },
  {
    "id": 2,
    "name": "Bob",
    "email": "bob@example.com",
    "posts": [
      {"id": 2, "title": "Bob's Post", "body": "Hi there."}
    ]
  }
]
```

### Nested Eager Loading

Dot notation loads multiple levels deep:

```php
$user = new User();
$users = $user->select("*", "", [], "", 0, 0, ["posts", "posts.comments"]);
```

Users, their posts, and each post's comments. Three queries total.

---

## 11. Soft Delete

Add a `deletedAt` property and Tina4 marks records as deleted instead of removing them:

```php
<?php
use Tina4\ORM;

class Post extends ORM
{
    public int $id;
    public string $title;
    public string $body;
    public ?string $deletedAt = null;

    public string $tableName = "posts";
    public string $primaryKey = "id";
    public bool $softDelete = true;
}
```

With `$softDelete = true`:

- `$post->delete()` sets `deleted_at` to the current timestamp. The row stays.
- `select()` excludes rows where `deleted_at` is not null.
- `$post->forceDelete()` removes the row permanently.

### Restoring Soft-Deleted Records

Use `restore()` to bring a soft-deleted record back:

```php
$post = new Post();
$post->load(5); // Load even if soft-deleted
$post->restore();
```

`restore()` clears `deleted_at` and saves the record in one call. The row reappears in normal queries.

### Including Soft-Deleted Records in Queries

```php
$post = new Post();
$allPosts = $post->select("*", "", [], "", 0, 0, [], true); // eighth arg = include deleted
```

---

## 12. NumericField for Prices

Floating-point arithmetic causes rounding errors with money. Use `NumericField` for precise decimals:

```php
<?php
use Tina4\ORM;
use Tina4\NumericField;

class Product extends ORM
{
    public int $id;
    public string $name;
    public NumericField $price;
    public NumericField $discount;

    public string $tableName = "products";
    public string $primaryKey = "id";
}
```

`NumericField` maps to `DECIMAL` or `NUMERIC` in the database. Precision stays intact for financial operations.

---

## 13. Auto-CRUD

Tina4 generates REST endpoints from any ORM model. One property flips the switch:

```php
<?php
use Tina4\ORM;

class Product extends ORM
{
    public int $id;
    public string $name;
    public string $category = "Uncategorized";
    public float $price = 0.00;
    public bool $inStock = true;

    public string $tableName = "products";
    public string $primaryKey = "id";
    public bool $autoCrud = true;
}
```

`$autoCrud = true` registers five routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List all with pagination |
| `GET` | `/api/products/{id}` | Get one by ID |
| `POST` | `/api/products` | Create a new record |
| `PUT` | `/api/products/{id}` | Update a record |
| `DELETE` | `/api/products/{id}` | Delete a record |

The endpoint prefix comes from the table name: `products` becomes `/api/products`.

```bash
curl http://localhost:7146/api/products
```

```json
{
  "data": [
    {"id": 1, "name": "Wireless Keyboard", "category": "Electronics", "price": 79.99, "in_stock": true},
    {"id": 2, "name": "Yoga Mat", "category": "Fitness", "price": 29.99, "in_stock": true}
  ],
  "total": 2,
  "page": 1,
  "per_page": 20
}
```

Filtering, sorting, and pagination work out of the box:

```bash
curl "http://localhost:7146/api/products?category=Electronics&sort=price&order=desc&page=1&per_page=10"
```

Custom routes still work alongside auto-CRUD. Your custom routes take precedence.

---

## 14. Scopes

Scopes are reusable query filters. Define them as static methods on your model. Call them anywhere you need the same filter.

```php
<?php
use Tina4\ORM;

class Product extends ORM
{
    public int $id;
    public string $name;
    public float $price;
    public bool $inStock;
    public string $category;

    public string $tableName = "products";
    public string $primaryKey = "id";

    public static function active(): array
    {
        $p = new self();
        return $p->select("*", "in_stock = :inStock", ["inStock" => 1]);
    }

    public static function expensive(float $threshold = 100.0): array
    {
        $p = new self();
        return $p->select("*", "price >= :threshold", ["threshold" => $threshold]);
    }

    public static function inCategory(string $category): array
    {
        $p = new self();
        return $p->select("*", "category = :category", ["category" => $category]);
    }
}
```

Use scopes in your route handlers:

```php
Router::get("/api/products/active", function ($request, $response) {
    $products = Product::active();
    return $response->json(array_map(fn($p) => $p->toArray(), $products));
});

Router::get("/api/products/expensive", function ($request, $response) {
    $threshold = (float) ($request->params["min"] ?? 100);
    $products = Product::expensive($threshold);
    return $response->json(array_map(fn($p) => $p->toArray(), $products));
});
```

Scopes give common queries a name. The filtering logic lives in the model. Route handlers stay clean.

---

## 15. Input Validation on Models

Move validation into the model. Define a `validate()` method that checks field values before saving:

```php
<?php
use Tina4\ORM;

class Product extends ORM
{
    public int $id;
    public string $name;
    public float $price;
    public string $category = "Uncategorized";

    public string $tableName = "products";
    public string $primaryKey = "id";

    public function validate(): array
    {
        $errors = [];

        if (empty($this->name)) {
            $errors[] = "Name is required";
        }

        if ($this->price < 0) {
            $errors[] = "Price cannot be negative";
        }

        if (strlen($this->name) > 255) {
            $errors[] = "Name must be 255 characters or fewer";
        }

        return $errors;
    }
}
```

Call `validate()` before saving:

```php
Router::post("/api/products", function ($request, $response) {
    $body = $request->body;

    $product = new Product();
    $product->name = $body["name"] ?? "";
    $product->price = (float) ($body["price"] ?? 0);
    $product->category = $body["category"] ?? "Uncategorized";

    $errors = $product->validate();
    if (!empty($errors)) {
        return $response->json(["errors" => $errors], 400);
    }

    $product->save();
    return $response->json($product->toArray(), 201);
});
```

Validation lives with the data it validates. Every route that saves a Product calls `validate()`. Change a rule once. Every endpoint picks it up.

---

## 16. Exercise: Build a Blog

Three models: User, Post, Comment. Relationships, eager loading, and auto-CRUD.

### Requirements

1. Create three models in `src/orm/`:

   **User** -- `users` table:
   - `id` (int, primary key)
   - `name` (string)
   - `email` (string)
   - `createdAt` (string)
   - Has many posts

   **Post** -- `posts` table:
   - `id` (int, primary key)
   - `userId` (int, foreign key)
   - `title` (string)
   - `body` (string)
   - `published` (bool, default false)
   - `createdAt` (string)
   - Belongs to user, has many comments

   **Comment** -- `comments` table:
   - `id` (int, primary key)
   - `postId` (int, foreign key)
   - `authorName` (string)
   - `body` (string)
   - `createdAt` (string)
   - Belongs to post

2. Create migrations for all three tables.

3. Build custom endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/blog/posts` | List published posts with author info (eager load user) |
| `GET` | `/api/blog/posts/{id:int}` | Get a post with author and comments (eager load both) |
| `POST` | `/api/blog/posts/{id:int}/comments` | Add a comment to a post |

4. Enable auto-CRUD on User for admin access at `/api/users`.

### Test with:

```bash
# Create a user (via auto-CRUD)
curl -X POST http://localhost:7146/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}'

# Create a post
curl -X POST http://localhost:7146/api/blog/posts \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "title": "My First Post", "body": "Hello world!", "published": true}'

# List posts
curl http://localhost:7146/api/blog/posts

# Add a comment
curl -X POST http://localhost:7146/api/blog/posts/1/comments \
  -H "Content-Type: application/json" \
  -d '{"author_name": "Bob", "body": "Great post!"}'

# Get post with comments
curl http://localhost:7146/api/blog/posts/1
```

---

## 17. Solution

### Migrations

Create `src/migrations/20260322150000_create_users_table.sql`:

```sql
-- UP
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS users;
```

Create `src/migrations/20260322150100_create_posts_table.sql`:

```sql
-- UP
CREATE TABLE posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    published INTEGER NOT NULL DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- DOWN
DROP TABLE IF EXISTS posts;
```

Create `src/migrations/20260322150200_create_comments_table.sql`:

```sql
-- UP
CREATE TABLE comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id INTEGER NOT NULL,
    author_name TEXT NOT NULL,
    body TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id)
);

-- DOWN
DROP TABLE IF EXISTS comments;
```

Run them:

```bash
tina4 migrate
```

```
Running migrations...
  [APPLIED] 20260322150000_create_users_table.sql
  [APPLIED] 20260322150100_create_posts_table.sql
  [APPLIED] 20260322150200_create_comments_table.sql
Migrations complete. 3 applied.
```

### Models

Create `src/orm/User.php`:

```php
<?php
use Tina4\ORM;

class User extends ORM
{
    public int $id;
    public string $name;
    public string $email;
    public string $createdAt;

    public string $tableName = "users";
    public string $primaryKey = "id";
    public bool $autoCrud = true;

    public function posts(): array
    {
        return $this->hasMany(Post::class, "user_id");
    }
}
```

Create `src/orm/Post.php`:

```php
<?php
use Tina4\ORM;

class Post extends ORM
{
    public int $id;
    public int $userId;
    public string $title;
    public string $body;
    public bool $published = false;
    public string $createdAt;

    public string $tableName = "posts";
    public string $primaryKey = "id";

    public function user(): ?User
    {
        return $this->belongsTo(User::class, "user_id");
    }

    public function comments(): array
    {
        return $this->hasMany(Comment::class, "post_id");
    }
}
```

Create `src/orm/Comment.php`:

```php
<?php
use Tina4\ORM;

class Comment extends ORM
{
    public int $id;
    public int $postId;
    public string $authorName;
    public string $body;
    public string $createdAt;

    public string $tableName = "comments";
    public string $primaryKey = "id";

    public function post(): ?Post
    {
        return $this->belongsTo(Post::class, "post_id");
    }
}
```

### Routes

Create `src/routes/blog.php`:

```php
<?php
use Tina4\Router;

// List published posts with author
Router::get("/api/blog/posts", function ($request, $response) {
    $post = new Post();
    $posts = $post->select("*", "published = :published", ["published" => 1], "created_at DESC", 0, 0, ["user"]);

    $results = array_map(fn($p) => $p->toArray(), $posts);

    return $response->json([
        "posts" => $results,
        "count" => count($results)
    ]);
});

// Get a single post with author and comments
Router::get("/api/blog/posts/{id:int}", function ($request, $response) {
    $post = new Post();
    $post->load($request->params["id"]);

    if (empty($post->id)) {
        return $response->json(["error" => "Post not found"], 404);
    }

    $user = $post->user();
    $comments = $post->comments();

    $result = $post->toArray();
    $result["user"] = $user ? $user->toArray() : null;
    $result["comments"] = array_map(fn($c) => $c->toArray(), $comments);
    $result["comment_count"] = count($comments);

    return $response->json($result);
});

// Create a post
Router::post("/api/blog/posts", function ($request, $response) {
    $body = $request->body;

    if (empty($body["title"]) || empty($body["body"]) || empty($body["user_id"])) {
        return $response->json(["error" => "title, body, and user_id are required"], 400);
    }

    $post = new Post();
    $post->userId = (int) $body["user_id"];
    $post->title = $body["title"];
    $post->body = $body["body"];
    $post->published = (bool) ($body["published"] ?? false);
    $post->save();

    return $response->json($post->toArray(), 201);
});

// Add a comment to a post
Router::post("/api/blog/posts/{id:int}/comments", function ($request, $response) {
    $postId = $request->params["id"];

    // Verify post exists
    $post = new Post();
    $post->load($postId);

    if (empty($post->id)) {
        return $response->json(["error" => "Post not found"], 404);
    }

    $body = $request->body;

    if (empty($body["author_name"]) || empty($body["body"])) {
        return $response->json(["error" => "author_name and body are required"], 400);
    }

    $comment = new Comment();
    $comment->postId = $postId;
    $comment->authorName = $body["author_name"];
    $comment->body = $body["body"];
    $comment->save();

    return $response->json($comment->toArray(), 201);
});
```

**Expected output for GET /api/blog/posts/1:**

```json
{
  "id": 1,
  "user_id": 1,
  "title": "My First Post",
  "body": "Hello world!",
  "published": true,
  "created_at": "2026-03-22 15:00:00",
  "user": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com"
  },
  "comments": [
    {
      "id": 1,
      "post_id": 1,
      "author_name": "Bob",
      "body": "Great post!",
      "created_at": "2026-03-22 15:01:00"
    }
  ],
  "comment_count": 1
}
```

---

## 18. Gotchas

### 1. Table Naming Convention

**Problem:** Model class is `OrderItem`. Queries fail because the table does not exist.

**Cause:** Tina4 converts `OrderItem` to `order_items` (plural, snake_case). Your table is `order_item` (singular).

**Fix:** Set `$tableName` explicitly: `public string $tableName = "order_item";`. Or rename the table.

### 2. Null Handling

**Problem:** A nullable field causes errors when the value is null.

**Cause:** Property declared as `string` instead of `?string`. PHP 8.1+ enforces type declarations.

**Fix:** Use nullable types: `public ?string $description = null;`.

### 3. Relationship Foreign Key Direction

**Problem:** `$this->hasMany(Post::class, "id")` gives wrong results.

**Cause:** The foreign key argument is the column on the related table, not the current table. `hasMany(Post::class, "user_id")` means "find posts where posts.user_id = this.id".

**Fix:** The foreign key is always on the "many" side. For `hasMany`, it is on the child table. For `belongsTo`, it is on the current table.

### 4. camelCase to snake_case Mapping

**Problem:** Property `$userId` maps to column `user_id`. But your column is `userid` (no underscore). The field reads as null.

**Cause:** Tina4 auto-converts `camelCase` to `snake_case`. `userId` becomes `user_id`. If the column is `userid`, the mapping fails.

**Fix:** Consistent naming. PHP: `camelCase`. Database: `snake_case`. Adjust column names or override the mapping.

### 5. Forgetting save()

**Problem:** Properties changed on the model. Database unchanged.

**Cause:** No `$model->save()` call. Setting properties only changes the in-memory object.

**Fix:** Call `save()` after modifying any property you want persisted.

### 6. Auto-CRUD Endpoint Conflicts

**Problem:** Custom route at `/api/products/{id}` stops working after enabling auto-CRUD.

**Cause:** Both routes match the same path. First registered wins.

**Fix:** Custom routes in `src/routes/` load before auto-CRUD routes. They take precedence. If you want different behavior, use a different path for the custom route.

### 7. select() Returns Objects, Not Arrays

**Problem:** Array syntax `$result["name"]` on the result of `select()` throws an error.

**Cause:** `select()` returns model objects, not associative arrays.

**Fix:** Use object syntax: `$result->name`. Or convert: `$result->toArray()`.
