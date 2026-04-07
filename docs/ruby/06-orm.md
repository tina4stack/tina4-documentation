# Chapter 6: ORM

## 1. From SQL to Objects

Chapter 5 was raw SQL for every operation. It works. It also gets tedious. The same `INSERT INTO products (name, price, ...) VALUES (:name, :price, ...)` patterns, over and over. The ORM lets you work with Ruby classes instead. Define a class. Map it to a table. Call `save`, `load`, `delete`.

Tina4's ORM is minimal by design. It does not hide SQL. It gives you convenience for common operations and steps aside when you need raw queries.

---

## 2. Defining a Model

ORM models live in `src/orm/`. Every `.rb` file in that directory is auto-loaded, just like route files.

Create `src/orm/product.rb`:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name
  string_field :category, default: "Uncategorized"
  float_field :price, default: 0.00
  boolean_field :in_stock, default: true
  string_field :created_at
  string_field :updated_at

  table_name "products"
end
```

That is a complete model. Let us break it down:

- **Extends `Tina4::ORM`** -- This gives you `save`, `load`, `delete`, `select`, and other methods.
- **Field declarations** -- Each field maps to a database column. The field name uses `snake_case` which maps directly to the column name. Tina4 handles the conversion automatically.
- **`table_name`** -- The database table this model maps to. If you omit it, Tina4 uses the lowercase class name: `Product` becomes `product`. Set `ORM_PLURAL_TABLE_NAMES=true` in `.env` to get plural names (`product` → `products`).
- **`primary_key: true`** -- Marks the primary key column. Defaults to `id`.
- **Default values** -- Fields with defaults (like `category: "Uncategorized"`) are used when creating new records without specifying those fields.

---

## 3. Field Types

Use the appropriate field declaration for your data types:

| Ruby Declaration | Database Type (SQLite) | Database Type (PostgreSQL) | Notes |
|-----------------|----------------------|---------------------------|-------|
| `integer_field` | INTEGER | INTEGER | Whole numbers |
| `string_field` | TEXT | VARCHAR(255) | Text fields |
| `float_field` | REAL | DOUBLE PRECISION | Decimal numbers |
| `boolean_field` | INTEGER | BOOLEAN | SQLite stores as 0/1 |

### Nullable Fields

Fields are nullable by default. To require a value:

```ruby
string_field :name, nullable: false
string_field :description  # nullable by default
```

### Primary Keys and Auto-Increment

By default, Tina4 treats the primary key field as auto-incrementing. When you call `save` on a new object (where the primary key is not set), the database generates the ID:

```ruby
product = Product.new
product.name = "Widget"
product.price = 9.99
product.save

puts product.id  # Auto-generated: 1, 2, 3, ...
```

---

## 4. Creating and Saving Records

### save -- Insert or Update

The `save` method inserts a new record or updates an existing one, depending on whether the primary key is set:

```ruby
Tina4::Router.post("/api/products") do |request, response|
  body = request.body

  product = Product.new
  product.name = body["name"]
  product.category = body["category"] || "Uncategorized"
  product.price = (body["price"] || 0).to_f
  product.in_stock = body["in_stock"] != false
  product.save

  response.json(product.to_h, 201)
end
```

```bash
curl -X POST http://localhost:7147/api/products \
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

When `id` is already set, `save` performs an UPDATE:

```ruby
Tina4::Router.put("/api/products/{id:int}") do |request, response|
  product = Product.new
  product.load(request.params["id"])

  if product.id.nil?
    return response.json({ error: "Product not found" }, 404)
  end

  body = request.body
  product.name = body["name"] || product.name
  product.price = (body["price"] || product.price).to_f
  product.category = body["category"] || product.category
  product.save

  response.json(product.to_h)
end
```

---

## 5. Loading Records

### load -- Get by Primary Key

```ruby
product = Product.new
product.load(42)

if product.id.nil?
  # Product with ID 42 not found
end
```

`load` populates the object's properties from the database row matching the primary key. If no row matches, the properties remain at their default values (or nil).

### A Simple Get Endpoint

```ruby
Tina4::Router.get("/api/products/{id:int}") do |request, response|
  product = Product.new
  product.load(request.params["id"])

  if product.id.nil?
    return response.json({ error: "Product not found" }, 404)
  end

  response.json(product.to_h)
end
```

```bash
curl http://localhost:7147/api/products/1
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

### delete

```ruby
Tina4::Router.delete("/api/products/{id:int}") do |request, response|
  product = Product.new
  product.load(request.params["id"])

  if product.id.nil?
    return response.json({ error: "Product not found" }, 404)
  end

  product.delete

  response.json(nil, 204)
end
```

`delete` removes the row from the database. The object still exists in memory but the database row is gone.

---

## 7. Querying with select

The `select` method lets you find records with filters, ordering, and pagination:

### Basic Select

```ruby
product = Product.new
products = product.select("*")
```

Returns an array of Product objects with all records.

### Filtering

```ruby
# Simple filter
electronics = Product.where("category = ?", ["Electronics"])

# Multiple conditions
affordable = Product.where("price < ? AND in_stock = ?", [100, 1])
```

### Ordering

```ruby
sorted = Product.all(order_by: "price DESC")
```

The `order_by` keyword argument is an ORDER BY clause.

### Pagination

```ruby
page = 1
per_page = 10
offset = (page - 1) * per_page

products = Product.all(order_by: "name ASC", limit: per_page, offset: offset)
```

The `limit` and `offset` keyword arguments control pagination.

### A Full List Endpoint with Filters

```ruby
Tina4::Router.get("/api/products") do |request, response|
  product = Product.new

  category = request.params["category"] || ""
  min_price = (request.params["min_price"] || 0).to_f
  max_price = (request.params["max_price"] || 999999).to_f
  page = (request.params["page"] || 1).to_i
  per_page = (request.params["per_page"] || 20).to_i
  sort = request.params["sort"] || "name"
  order = (request.params["order"] || "ASC").upcase

  # Build filter
  conditions = []
  params = []

  unless category.empty?
    conditions << "category = ?"
    params << category
  end

  conditions << "price >= ? AND price <= ?"
  params << min_price
  params << max_price

  filter = conditions.join(" AND ")

  # Validate sort field
  allowed_sorts = %w[name price category created_at]
  sort = "name" unless allowed_sorts.include?(sort)
  order = "ASC" unless %w[ASC DESC].include?(order)

  offset = (page - 1) * per_page

  sql = "SELECT * FROM products WHERE #{filter} ORDER BY #{sort} #{order}"
  products = Product.select(sql, params, limit: per_page, offset: offset)

  results = products.map(&:to_h)

  response.json({
    products: results,
    page: page,
    per_page: per_page,
    count: results.length
  })
end
```

```bash
curl "http://localhost:7147/api/products?category=Electronics&sort=price&order=DESC&page=1&per_page=5"
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

Instead of writing a migration manually, you can generate the table from your model:

```ruby
product = Product.new
product.create_table
```

You can also use the CLI:

```bash
tina4 orm:create-table Product
```

```
Created table "products" with 7 columns.
```

This is convenient during early development. For production, use migrations (Chapter 5) so schema changes are versioned and reversible.

---

## 9. Relationships

### has_many -- One-to-Many

A user has many posts:

Create `src/orm/user.rb`:

```ruby
class User < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name
  string_field :email
  string_field :created_at

  table_name "users"

  has_many :posts, class_name: "Post", foreign_key: "user_id"
end
```

Create `src/orm/post.rb`:

```ruby
class Post < Tina4::ORM
  integer_field :id, primary_key: true
  integer_field :user_id
  string_field :title
  string_field :body
  string_field :created_at

  table_name "posts"

  belongs_to :user, class_name: "User", foreign_key: "user_id"
  has_many :comments, class_name: "Comment", foreign_key: "post_id"
end
```

The `foreign_key` option specifies the column on the related table. `has_many :posts, class_name: "Post", foreign_key: "user_id"` means: find all rows in `posts` where `user_id` equals this user's ID.

### has_one -- One-to-One

```ruby
has_one :profile, class_name: "Profile", foreign_key: "user_id"
```

`has_one` works like `has_many` but returns a single object instead of an array.

### belongs_to -- Inverse Relationship

The inverse of `has_many`. A post belongs to a user:

```ruby
belongs_to :user, class_name: "User", foreign_key: "user_id"
```

`belongs_to :user, class_name: "User", foreign_key: "user_id"` means: load the User where `users.id` equals `self.user_id`.

### Using Relationships

```ruby
Tina4::Router.get("/api/users/{id:int}") do |request, response|
  user = User.new
  user.load(request.params["id"])

  if user.id.nil?
    return response.json({ error: "User not found" }, 404)
  end

  posts = user.posts

  response.json({
    user: user.to_h,
    posts: posts.map(&:to_h),
    post_count: posts.length
  })
end
```

```bash
curl http://localhost:7147/api/users/1
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

Calling relationship methods inside a loop creates the N+1 query problem. Load 100 users. Call `user.posts` for each one. That is 101 queries -- 1 for users, 100 for posts.

Use the `include` parameter with `select` to eager-load relationships:

```ruby
user = User.new
users = user.select("*", "", {}, "name ASC", 20, 0, ["posts"])
```

The seventh argument is an array of relationship names to include. This runs just 2 queries (one for users, one for all related posts) and stitches the results together.

### to_h with Nested Includes

When eager loading is active, `to_h` includes the related data:

```ruby
user = User.new
users = user.select("*", "", {}, "", 0, 0, ["posts"])

result = users.map(&:to_h)

response.json(result)
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

Load multiple levels deep with dot notation:

```ruby
user = User.new
users = user.select("*", "", {}, "", 0, 0, ["posts", "posts.comments"])
```

This loads users, their posts, and each post's comments in 3 queries total.

---

## 11. Soft Delete

If your model has a `deleted_at` field, Tina4 supports soft delete -- marking records as deleted without actually removing them from the database:

```ruby
class Post < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :title
  string_field :body
  string_field :deleted_at

  table_name "posts"

  soft_delete true
end
```

With `soft_delete true`:

- `post.delete` sets `deleted_at` to the current timestamp instead of deleting the row
- `select` automatically excludes rows where `deleted_at` is not null
- `post.force_delete` permanently removes the row

### Restoring Soft-Deleted Records

```ruby
post = Post.new
post.load(5)  # Load even if soft-deleted
post.deleted_at = nil
post.save
```

### Including Soft-Deleted Records in Queries

```ruby
post = Post.new
all_posts = post.select("*", "", {}, "", 0, 0, [], true)  # eighth arg = include deleted
```

---

## 12. Auto-CRUD

Auto-CRUD generates REST endpoints for any ORM model. No route files needed.

Add the `auto_crud` declaration to your model:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name
  string_field :category, default: "Uncategorized"
  float_field :price, default: 0.00
  boolean_field :in_stock, default: true

  table_name "products"

  auto_crud true
end
```

With `auto_crud true`, Tina4 automatically registers these routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List all with pagination |
| `GET` | `/api/products/{id}` | Get one by ID |
| `POST` | `/api/products` | Create a new record |
| `PUT` | `/api/products/{id}` | Update a record |
| `DELETE` | `/api/products/{id}` | Delete a record |

The endpoint prefix is derived from the table name: `products` becomes `/api/products`.

```bash
curl http://localhost:7147/api/products
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

Auto-CRUD supports query parameters for filtering, sorting, and pagination out of the box:

```bash
curl "http://localhost:7147/api/products?category=Electronics&sort=price&order=desc&page=1&per_page=10"
```

### Custom Routes Alongside Auto-CRUD

Custom routes defined in `src/routes/` load before auto-CRUD routes. They take precedence. If you need special logic for one endpoint -- custom validation, side effects, complex queries -- define that route manually. Auto-CRUD handles the rest.

### Introspection

Check which models are registered:

```ruby
registered = Tina4::AutoCrud.models
# [User, Product, Order]
```

---

## 13. Scopes

Scopes are reusable query filters baked into the model. Use the `scope` class method to define them:

```ruby
class BlogPost < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :title
  string_field :status, default: "draft"
  string_field :created_at

  table_name "posts"

  scope :published, "status = ?", ["published"]
  scope :drafts, "status = ?", ["draft"]
end
```

Use them in your routes:

```ruby
Tina4::Router.get("/api/posts/published") do |request, response|
  posts = BlogPost.published
  response.json({ posts: posts.map(&:to_h) })
end

Tina4::Router.get("/api/posts/drafts") do |request, response|
  posts = BlogPost.drafts
  response.json({ posts: posts.map(&:to_h) })
end
```

Scopes keep query logic in the model where it belongs. Route handlers stay thin.

---

## 14. Input Validation

Field definitions carry validation rules. Call `validate` before `save` and the ORM checks every constraint:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name, nullable: false
  string_field :sku, nullable: false
  float_field :price, nullable: false
  string_field :category

  table_name "products"
end
```

```ruby
Tina4::Router.post("/api/products") do |request, response|
  product = Product.new(request.body)

  errors = product.validate
  unless errors.empty?
    return response.json({ errors: errors }, 400)
  end

  product.save
  response.json({ product: product.to_h }, 201)
end
```

If validation fails, `validate` returns a list of error messages:

```json
{
  "errors": [
    "name cannot be null",
    "sku cannot be null",
    "price cannot be null"
  ]
}
```

The ORM validates `nullable` constraints. Fields marked `nullable: false` must have a value before saving. The `save` method also runs `validate_fields` internally -- if validation fails, `save` returns `false` and populates `errors`.

---

## 15. Exercise: Build a Blog

Build a blog with three models: User, Post, and Comment. Use relationships, eager loading, and auto-CRUD.

### Requirements

1. Create three models in `src/orm/`:

   **User** -- `users` table:
   - `id` (integer, primary key)
   - `name` (string)
   - `email` (string)
   - `created_at` (string)
   - Has many posts

   **Post** -- `posts` table:
   - `id` (integer, primary key)
   - `user_id` (integer, foreign key)
   - `title` (string)
   - `body` (string)
   - `published` (boolean, default false)
   - `created_at` (string)
   - Belongs to user, has many comments

   **Comment** -- `comments` table:
   - `id` (integer, primary key)
   - `post_id` (integer, foreign key)
   - `author_name` (string)
   - `body` (string)
   - `created_at` (string)
   - Belongs to post

2. Create migrations for all three tables.

3. Build custom endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/blog/posts` | List published posts with author info (eager load user) |
| `GET` | `/api/blog/posts/{id:int}` | Get a post with author and comments (eager load both) |
| `POST` | `/api/blog/posts/{id:int}/comments` | Add a comment to a post |

4. Enable auto-CRUD on the User model for admin access at `/api/users`.

### Test with:

```bash
# Create a user (via auto-CRUD)
curl -X POST http://localhost:7147/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}'

# Create a post
curl -X POST http://localhost:7147/api/blog/posts \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "title": "My First Post", "body": "Hello world!", "published": true}'

# List posts
curl http://localhost:7147/api/blog/posts

# Add a comment
curl -X POST http://localhost:7147/api/blog/posts/1/comments \
  -H "Content-Type: application/json" \
  -d '{"author_name": "Bob", "body": "Great post!"}'

# Get post with comments
curl http://localhost:7147/api/blog/posts/1
```

---

## 16. Solution

### Models

Create `src/orm/user.rb`:

```ruby
class User < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name
  string_field :email
  string_field :created_at

  table_name "users"

  auto_crud true

  has_many :posts, class_name: "Post", foreign_key: "user_id"
end
```

Create `src/orm/post.rb`:

```ruby
class Post < Tina4::ORM
  integer_field :id, primary_key: true
  integer_field :user_id
  string_field :title
  string_field :body
  boolean_field :published, default: false
  string_field :created_at

  table_name "posts"

  belongs_to :user, class_name: "User", foreign_key: "user_id"
  has_many :comments, class_name: "Comment", foreign_key: "post_id"
end
```

Create `src/orm/comment.rb`:

```ruby
class Comment < Tina4::ORM
  integer_field :id, primary_key: true
  integer_field :post_id
  string_field :author_name
  string_field :body
  string_field :created_at

  table_name "comments"

  belongs_to :post, class_name: "Post", foreign_key: "post_id"
end
```

### Routes

Create `src/routes/blog.rb`:

```ruby
# List published posts with author
Tina4::Router.get("/api/blog/posts") do |request, response|
  posts = Post.select("SELECT * FROM posts WHERE published = ? ORDER BY created_at DESC", [1], include: ["user"])

  results = posts.map(&:to_h)

  response.json({
    posts: results,
    count: results.length
  })
end

# Get a single post with author and comments
Tina4::Router.get("/api/blog/posts/{id:int}") do |request, response|
  post = Post.new
  post.load(request.params["id"])

  if post.id.nil?
    return response.json({ error: "Post not found" }, 404)
  end

  user = post.user
  comments = post.comments

  result = post.to_h
  result[:user] = user ? user.to_h : nil
  result[:comments] = comments.map(&:to_h)
  result[:comment_count] = comments.length

  response.json(result)
end

# Create a post
Tina4::Router.post("/api/blog/posts") do |request, response|
  body = request.body

  if body["title"].nil? || body["body"].nil? || body["user_id"].nil?
    return response.json({ error: "title, body, and user_id are required" }, 400)
  end

  post = Post.new
  post.user_id = body["user_id"].to_i
  post.title = body["title"]
  post.body = body["body"]
  post.published = body["published"] || false
  post.save

  response.json(post.to_h, 201)
end

# Add a comment to a post
Tina4::Router.post("/api/blog/posts/{id:int}/comments") do |request, response|
  post_id = request.params["id"]

  # Verify post exists
  post = Post.new
  post.load(post_id)

  if post.id.nil?
    return response.json({ error: "Post not found" }, 404)
  end

  body = request.body

  if body["author_name"].nil? || body["body"].nil?
    return response.json({ error: "author_name and body are required" }, 400)
  end

  comment = Comment.new
  comment.post_id = post_id
  comment.author_name = body["author_name"]
  comment.body = body["body"]
  comment.save

  response.json(comment.to_h, 201)
end
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

## 17. Field Name Mapping

By default, Tina4 Ruby expects both field names and database columns to use `snake_case`. If your database uses `camelCase` columns (common when sharing a database with a JavaScript or Java backend), enable `auto_map` on your model:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :product_name
  float_field :unit_price

  table_name "products"

  auto_map true
end
```

With `auto_map true`, Tina4 automatically translates between `snake_case` Ruby attributes and `camelCase` database columns (`product_name` maps to `productName`).

You can also use the conversion helpers directly:

```ruby
Tina4.snake_to_camel("product_name")  # => "productName"
Tina4.camel_to_snake("productName")   # => "product_name"
```

---

## 18. Auto-CRUD with `Tina4::CRUD.to_crud`

Beyond the `auto_crud true` declaration on models (section 12), Tina4 provides `Tina4::CRUD.to_crud` for generating a complete HTML CRUD interface -- a searchable, paginated table with create/edit/delete forms -- from a SQL query or ORM model:

```ruby
Tina4::Router.get("/admin/products") do |request, response|
  response.html(Tina4::CRUD.to_crud(request, {
    title: "Manage Products",
    model: Product,
    fields: [:id, :name, :category, :price, :in_stock]
  }))
end
```

You can also use a raw SQL query instead of a model:

```ruby
Tina4::Router.get("/admin/orders") do |request, response|
  response.html(Tina4::CRUD.to_crud(request, {
    title: "Orders",
    sql: "SELECT id, customer_name, total, status FROM orders",
    primary_key: "id"
  }))
end
```

`to_crud` automatically registers the supporting REST API routes (list, get, create, update, delete) for the interface.

---

## 19. Gotchas

### 1. Table Naming Convention

**Problem:** Your model class is `OrderItem` but queries fail because the table does not exist.

**Cause:** Tina4 converts `OrderItem` to `orderitem` (lowercase, no separator). If your table is named `order_item` (snake_case), it will not match.

**Fix:** Set `table_name` explicitly: `table_name "order_item"`.

### 2. Nil Handling

**Problem:** A field that should be nullable causes errors when the value is nil.

**Cause:** Ruby is generally nil-friendly, but the database column might have a NOT NULL constraint.

**Fix:** Ensure your migration allows null values for optional fields. In Ruby, check with `field.nil?` before accessing methods on potentially nil values.

### 3. Relationship Foreign Key Direction

**Problem:** You write `has_many :posts, foreign_key: "id"` and get wrong results.

**Cause:** The foreign key argument is the column on the related table, not the current table. `has_many :posts, foreign_key: "user_id"` means "find posts where posts.user_id = this.id", not "find posts where posts.id = this.user_id".

**Fix:** The foreign key is always on the "many" side. For `has_many`, it is the column on the child table. For `belongs_to`, it is the column on the current table.

### 4. snake_case Mapping

**Problem:** You have a field `user_id` but the database column is `userId`. Queries return nil for this field.

**Cause:** Tina4 Ruby uses `snake_case` for both field names and database columns. If your database uses `camelCase`, the mapping breaks.

**Fix:** Use consistent naming. Ruby fields and database columns should both be `snake_case`. If your column names differ, you may need to adjust them or override the mapping.

### 5. Forgetting save

**Problem:** You set properties on a model but the database does not change.

**Cause:** You forgot to call `model.save`. Setting properties only changes the in-memory object.

**Fix:** Always call `save` after modifying properties that should be persisted.

### 6. Auto-CRUD Endpoint Conflicts

**Problem:** Your custom route at `/api/products/{id}` does not work after enabling auto-CRUD on the Product model.

**Cause:** Both your custom route and the auto-CRUD route match the same path. The first one registered wins.

**Fix:** Custom routes defined in `src/routes/` files are loaded before auto-CRUD routes, so they take precedence. If that is not the behavior you want, use a different path for your custom route (e.g., `/api/shop/products/{id}`).

### 7. select Returns Objects, Not Hashes

**Problem:** You try to use hash syntax (`result["name"]`) on the result of `select` and get an error.

**Cause:** `select` returns an array of model objects, not hashes. Each item is an instance of your model class.

**Fix:** Access properties with dot syntax: `result.name`. Or convert to a hash with `result.to_h`.

---

## QueryBuilder Integration

ORM models provide a `query` method that returns a `QueryBuilder` pre-configured with the model's table name and database connection:

```ruby
# Fluent query builder from ORM
results = User.query
  .select("id", "name", "email")
  .where("active = ?", [true])
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
