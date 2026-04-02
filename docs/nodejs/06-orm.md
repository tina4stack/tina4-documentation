# Chapter 6: ORM

## 1. From SQL to Objects

Chapter 5 had you writing raw SQL for every operation. It works. It gets tedious. The same `INSERT INTO products (name, price, ...) VALUES (:name, :price, ...)` pattern over and over. The ORM replaces that repetition with TypeScript classes. Define a class. Map it to a table. Call `save()`, `findById()`, and `delete()`.

Tina4's ORM does not hide SQL. It handles the common operations -- create, read, update, delete -- and steps aside when you need raw queries. You always have `Database.getConnection()` for the hard stuff.

---

## 2. Defining a Model

ORM models live in `src/orm/`. Every `.ts` file in that directory is auto-loaded at startup. Same discovery pattern as route files.

Create `src/orm/Product.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Product extends BaseModel {
    static tableName = "products";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        name: { type: "string", required: true },
        category: { type: "string", default: "Uncategorized" },
        price: { type: "number", default: 0 },
        inStock: { type: "boolean", default: true },
        createdAt: { type: "datetime" },
        updatedAt: { type: "datetime" },
    };

    id!: number;
    name!: string;
    category: string = "Uncategorized";
    price: number = 0;
    inStock: boolean = true;
    createdAt!: string;
    updatedAt!: string;
}
```

Here is what each piece does:

- **Extends `BaseModel`** -- Gives you `save()`, `findById()`, `findAll()`, `delete()`, `toDict()`, and other methods.
- **`static fields`** -- Declares field types, constraints, and defaults. The ORM uses this for validation, auto-CRUD, and `createTable()`.
- **`static tableName`** -- The database table this model maps to. If you omit it, Tina4 uses the lowercase class name: `Product` becomes `product`. Set `ORM_PLURAL_TABLE_NAMES=true` in `.env` to get plural names (`product` → `products`).
- **TypeScript properties** -- Each property maps to a database column. Property names are `camelCase`; column names are `snake_case`. Tina4 converts between them automatically: `inStock` maps to `in_stock`, `createdAt` maps to `created_at`.
- **Default values** -- Properties with defaults (like `category = "Uncategorized"`) apply when creating new records.

### Field Definitions

The `fields` object describes each column. Every field supports these options:

| Option | Type | Description |
|--------|------|-------------|
| `type` | string | `"integer"`, `"string"`, `"text"`, `"number"`, `"boolean"`, `"datetime"` |
| `primaryKey` | boolean | Marks this field as the primary key |
| `autoIncrement` | boolean | Auto-increments on insert |
| `required` | boolean | Fails validation if missing |
| `default` | any | Default value for new records |
| `minLength` | number | Minimum string length (strings only) |
| `maxLength` | number | Maximum string length (strings only) |
| `min` | number | Minimum value (numbers only) |
| `max` | number | Maximum value (numbers only) |
| `pattern` | string | Regex pattern the value must match (strings only) |

### Field Mapping

When your TypeScript property names do not match the database column names, use `fieldMapping` to define the translation:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class User extends BaseModel {
    static tableName = "user_accounts";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        firstName: { type: "string", required: true },
        lastName: { type: "string", required: true },
        emailAddress: { type: "string", required: true },
    };
    static fieldMapping = {
        firstName: "fname",
        lastName: "lname",
        emailAddress: "email",
    };

    id!: number;
    firstName!: string;
    lastName!: string;
    emailAddress!: string;
}
```

With this mapping, `user.firstName` reads from and writes to the `fname` column. The ORM handles the conversion in both directions -- on `findById()`, `save()`, `findAll()`, `toDict()`, and `toObject()`. This takes priority over the default `camelCase` to `snake_case` conversion. Useful when working with legacy databases where you cannot rename columns.

### Automatic Field Mapping with autoMap

If your database columns follow `snake_case` and your TypeScript properties follow `camelCase`, skip writing `fieldMapping`. Set `static autoMap = true` and Tina4 generates the mapping:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Order extends BaseModel {
    static tableName = "orders";
    static autoMap = true;
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        customerName: { type: "string" },
        orderTotal: { type: "number" },
        createdAt: { type: "datetime" },
    };

    id!: number;
    customerName!: string;   // maps to customer_name
    orderTotal!: number;     // maps to order_total
    createdAt!: string;      // maps to created_at
}
```

Explicit `fieldMapping` entries always take priority over `autoMap`. Use both when most columns follow the convention but a few do not.

### Utility Exports: snakeToCamel and camelToSnake

The ORM package exports two helper functions for case conversion:

```typescript
import { snakeToCamel, camelToSnake } from "tina4-nodejs/orm";

snakeToCamel("created_at");   // "createdAt"
camelToSnake("createdAt");    // "created_at"
```

These are the same functions the ORM uses internally. Useful when building dynamic queries or transforming API payloads.

---

## 3. Field Types

| TypeScript Type | Database Type (SQLite) | Database Type (PostgreSQL) | Notes |
|-----------------|----------------------|---------------------------|-------|
| `number` | INTEGER or REAL | INTEGER or DOUBLE PRECISION | Whole or decimal numbers |
| `string` | TEXT | VARCHAR(255) | Text fields |
| `boolean` | INTEGER | BOOLEAN | SQLite stores as 0/1 |
| `string \| null` | TEXT (nullable) | VARCHAR(255) NULL | Nullable fields |

### Nullable Fields

```typescript
description: string | null = null;
discount: number | null = null;
```

---

## 4. Creating and Saving Records

### save() -- Insert or Update

The `save()` method inserts a new record or updates an existing one:

```typescript
import { Router } from "tina4-nodejs";
import { Product } from "../orm/Product";

Router.post("/api/products", async (req, res) => {
    const body = req.body;

    const product = new Product();
    product.name = body.name;
    product.category = body.category ?? "Uncategorized";
    product.price = parseFloat(body.price ?? 0);
    product.inStock = Boolean(body.in_stock ?? true);
    product.save();

    return res.status(201).json(product.toDict());
});
```

```bash
curl -X POST http://localhost:7148/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Wireless Keyboard", "category": "Electronics", "price": 79.99}'
```

```json
{
  "id": 1,
  "name": "Wireless Keyboard",
  "category": "Electronics",
  "price": 79.99,
  "inStock": true,
  "createdAt": "2026-03-22 14:30:00"
}
```

### Constructor Shorthand

Pass an object to the constructor to set all fields at once:

```typescript
const product = new Product({
    name: "Standing Desk",
    category: "Furniture",
    price: 549.99,
});
product.save();
```

### toDict(), toObject(), toJson()

Three output formats:

```typescript
product.toDict();    // Plain object with field names as keys
product.toObject();  // Alias for toDict()
product.toJson();    // JSON string
product.toArray();   // Array of values
product.toList();    // Alias for toArray()
```

Use `toDict()` for API responses. Use `toJson()` when you need a string.

### Updating an Existing Record

When `id` is set, `save()` performs an UPDATE:

```typescript
Router.put("/api/products/{id:int}", async (req, res) => {
    const product = Product.findById(req.params.id);

    if (!product) {
        return res.status(404).json({ error: "Product not found" });
    }

    const body = req.body;
    product.name = body.name ?? product.name;
    product.price = parseFloat(body.price ?? product.price);
    product.category = body.category ?? product.category;
    product.save();

    return res.json(product.toDict());
});
```

---

## 5. Loading Records

### findById() -- Get by Primary Key

```typescript
const product = Product.findById(42);

if (!product) {
    // Product with ID 42 not found
}
```

`findById()` returns the model instance or `null` if no record matches.

### findOrFail() -- Get or Throw

```typescript
try {
    const product = Product.findOrFail(42);
    // product is guaranteed to exist
} catch (e) {
    // Throws Error: "products: record with id 42 not found"
}
```

### findAll() -- Get Multiple Records

```typescript
// All products
const all = Product.findAll();

// With a WHERE clause
const electronics = Product.findAll("category = ?", ["Electronics"]);
```

### Eager Loading with findById and findAll

Pass an `include` array to load relationships in the same call:

```typescript
const user = User.findById(1, ["posts"]);

const users = User.findAll(undefined, undefined, ["posts", "posts.comments"]);
```

This runs two queries instead of N+1. Section 9 covers eager loading in depth.

---

## 6. Deleting Records

```typescript
Router.delete("/api/products/{id:int}", async (req, res) => {
    const product = Product.findById(req.params.id);

    if (!product) {
        return res.status(404).json({ error: "Product not found" });
    }

    product.delete();

    return res.status(204).json(null);
});
```

---

## 7. QueryBuilder -- Fluent Queries

Every model exposes a fluent `query()` method for complex queries:

```typescript
// Chain conditions
const results = Product.query()
    .where("category = ?", ["Electronics"])
    .where("price < ?", [100])
    .orderBy("price DESC")
    .limit(10)
    .get();
```

### Available Methods

| Method | Description |
|--------|-------------|
| `.where(sql, params)` | Add a WHERE condition |
| `.orderBy(clause)` | Set ORDER BY |
| `.limit(n)` | Set LIMIT |
| `.offset(n)` | Set OFFSET |
| `.get()` | Execute and return results |

### A Full List Endpoint with Filters

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/products", async (req, res) => {
    const category = req.query.category ?? "";
    const page = parseInt(req.query.page ?? "1", 10);
    const perPage = parseInt(req.query.per_page ?? "20", 10);
    const sort = req.query.sort ?? "name";
    const order = (req.query.order ?? "ASC").toUpperCase();

    const allowedSorts = ["name", "price", "category", "created_at"];
    const safeSort = allowedSorts.includes(sort) ? sort : "name";
    const safeOrder = order === "DESC" ? "DESC" : "ASC";

    let qb = Product.query().orderBy(`${safeSort} ${safeOrder}`)
        .limit(perPage).offset((page - 1) * perPage);

    if (category) {
        qb = qb.where("category = ?", [category]);
    }

    const products = qb.get();

    return res.json({
        products: products.map(p => p.toDict()),
        page,
        per_page: perPage,
        count: products.length,
    });
});
```

### Raw SQL with select()

When the QueryBuilder is not enough, use `select()` for raw SQL:

```typescript
const results = Product.select(
    "SELECT p.*, c.name as category_name FROM products p JOIN categories c ON p.category_id = c.id WHERE p.price > ?",
    [50]
);
```

---

## 8. Relationships

### hasMany -- One-to-Many

A user has many posts. Define the relationship as a static property:

Create `src/orm/User.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class User extends BaseModel {
    static tableName = "users";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        name: { type: "string", required: true },
        email: { type: "string", required: true },
        createdAt: { type: "datetime" },
    };
    static hasMany = [
        { model: "Post", foreignKey: "user_id" }
    ];

    id!: number;
    name!: string;
    email!: string;
    createdAt!: string;
}
```

Create `src/orm/Post.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Post extends BaseModel {
    static tableName = "posts";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        userId: { type: "integer", required: true },
        title: { type: "string", required: true },
        body: { type: "text" },
        published: { type: "boolean", default: false },
        createdAt: { type: "datetime" },
    };
    static belongsTo = [
        { model: "User", foreignKey: "user_id" }
    ];
    static hasMany = [
        { model: "Comment", foreignKey: "post_id" }
    ];

    id!: number;
    userId!: number;
    title!: string;
    body!: string;
    published: boolean = false;
    createdAt!: string;
}
```

### hasOne -- One-to-One

A user has one profile. The foreign key lives on the profile table:

```typescript
export class User extends BaseModel {
    static tableName = "users";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        name: { type: "string", required: true },
    };
    static hasOne = [
        { model: "Profile", foreignKey: "user_id" }
    ];

    id!: number;
    name!: string;
}

export class Profile extends BaseModel {
    static tableName = "profiles";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        userId: { type: "integer", required: true },
        bio: { type: "text" },
        avatarUrl: { type: "string" },
    };
    static belongsTo = [
        { model: "User", foreignKey: "user_id" }
    ];

    id!: number;
    userId!: number;
    bio!: string;
    avatarUrl!: string;
}
```

`hasOne` returns a single model instance (or `null`). `hasMany` returns an array.

### belongsTo -- Inverse Relationship

`belongsTo` goes on the child model. The foreign key column lives on the child's table:

```typescript
// Post belongs to User
static belongsTo = [
    { model: "User", foreignKey: "user_id" }
];

// Comment belongs to Post
static belongsTo = [
    { model: "Post", foreignKey: "post_id" }
];
```

### Using Relationships

Load related models with instance methods:

```typescript
Router.get("/api/users/{id:int}", async (req, res) => {
    const user = User.findById(req.params.id);

    if (!user) {
        return res.status(404).json({ error: "User not found" });
    }

    // Use toDict with include for nested output
    return res.json(user.toDict(["posts"]));
});
```

### toDict with include

Pass relationship names to `toDict()` to include related data:

```typescript
const user = User.findById(1);

// Include posts
user.toDict(["posts"]);

// Include posts and their comments (dot notation)
user.toDict(["posts", "posts.comments"]);
```

The result nests related objects inside the output:

```json
{
  "id": 1,
  "name": "Alice",
  "email": "alice@example.com",
  "posts": [
    {
      "id": 10,
      "title": "First Post",
      "comments": [
        { "id": 100, "body": "Great post!" }
      ]
    }
  ]
}
```

---

## 9. Eager Loading

The N+1 query problem kills performance. Load 20 users, then load posts for each user -- that is 21 queries. Eager loading runs 2 queries regardless of result count.

### With findAll

```typescript
const users = User.findAll(undefined, undefined, ["posts"]);
```

The third argument is an array of relationship names to include.

### Nested Eager Loading

```typescript
const users = User.findAll(undefined, undefined, ["posts", "posts.comments"]);
```

Dot notation loads nested relationships. This runs 3 queries: one for users, one for posts, one for comments.

---

## 10. Soft Delete

Enable soft delete with `static softDelete = true`. The model needs an `is_deleted` column (integer, default 0) in the database:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Post extends BaseModel {
    static tableName = "posts";
    static softDelete = true;
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        title: { type: "string", required: true },
        body: { type: "text" },
    };

    id!: number;
    title!: string;
    body!: string;
}
```

With `softDelete = true`:

- `post.delete()` sets `is_deleted = 1` instead of removing the row
- `findAll()` and `findById()` exclude soft-deleted records automatically
- `post.forceDelete()` permanently removes the row from the database

### Restoring Soft-Deleted Records

Bring a record back from the dead:

```typescript
// Find a deleted record (must bypass the soft delete filter)
const deleted = Post.withTrashed("id = ?", [42]);

if (deleted.length > 0) {
    deleted[0].restore();
    // is_deleted is now 0, record appears in normal queries again
}
```

`restore()` only works on models with `softDelete = true`. It sets `is_deleted = 0` and the record reappears in normal queries.

### Querying Including Deleted Records

```typescript
// All records, including soft-deleted ones
const all = Post.withTrashed();

// Filtered, including soft-deleted
const filtered = Post.withTrashed("category = ?", ["News"]);

// With limit and offset
const paged = Post.withTrashed(undefined, undefined, 20, 0);
```

### Table Filter

Restrict all queries on a model with `tableFilter`. This filter applies automatically to every `findAll()`, `findById()`, and `count()` call:

```typescript
export class ActiveProduct extends BaseModel {
    static tableName = "products";
    static tableFilter = "status = 'active'";
    // ...
}
```

Every query against `ActiveProduct` includes `WHERE status = 'active'`. The filter combines with soft delete and any explicit WHERE clauses you add.

---

## 11. createTable() -- Schema from Model

Generate the database table directly from the model's field definitions:

```typescript
Product.createTable();
```

The method reads `static fields` and builds a `CREATE TABLE IF NOT EXISTS` statement. It maps field types to SQL types:

| Field Type | SQLite | PostgreSQL |
|-----------|--------|------------|
| `integer` | INTEGER | INTEGER |
| `string` | TEXT | TEXT |
| `text` | TEXT | TEXT |
| `number` | REAL | REAL |
| `boolean` | INTEGER | INTEGER |
| `datetime` | TEXT | TEXT |

If the table already exists, `createTable()` does nothing.

Use this for quick prototyping and test setup. For production schema changes, use migrations (Chapter 8).

---

## 12. Input Validation

The ORM validates data against the `fields` definition. Call `validate()` on any model instance:

```typescript
const product = new Product();
product.name = "";
product.price = -5;

const errors = product.validate();
// ["name is required", "price must be at least 0"]
```

### Validation in Routes

```typescript
Router.post("/api/products", async (req, res) => {
    const product = new Product(req.body);
    const errors = product.validate();

    if (errors.length > 0) {
        return res.status(400).json({ errors });
    }

    product.save();
    return res.status(201).json(product.toDict());
});
```

### Validation Rules Reference

| Rule | Field Type | Example |
|------|-----------|---------|
| `required` | all | `required: true` |
| `minLength` | string | `minLength: 3` |
| `maxLength` | string | `maxLength: 255` |
| `min` | number | `min: 0` |
| `max` | number | `max: 10000` |
| `pattern` | string | `pattern: "^[a-z]+$"` |

The validator skips primary key fields on insert and skips missing fields on update. A field with `required: true` that arrives as `undefined`, `null`, or `""` fails validation.

---

## 13. Scopes -- Reusable Query Filters

Scopes are named query shortcuts. Instead of repeating the same WHERE clause, define it once:

```typescript
// Active products (in_stock = 1)
const active = Product.scope("active", "in_stock = ?", [1]);

// Expensive products (price > 100)
const expensive = Product.scope("expensive", "price > ?", [100]);

// Products in a category
const electronics = Product.scope("byCategory", "category = ?", ["Electronics"]);
```

Scopes respect soft delete and table filters. They compose with existing conditions.

---

## 14. count() -- Counting Records

```typescript
const total = Product.count();
const electronics = Product.count("category = ?", ["Electronics"]);
const inStock = Product.count("in_stock = ?", [1]);
```

`count()` respects soft delete and table filters.

---

## 15. Auto-CRUD

Add `static autoCrud = true` to the model definition and Tina4 generates REST endpoints for you. No route file needed.

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Product extends BaseModel {
    static tableName = "products";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        name: { type: "string", required: true },
        category: { type: "string", default: "Uncategorized" },
        price: { type: "number", default: 0, min: 0 },
        inStock: { type: "boolean", default: true },
    };
    // This single line generates all CRUD routes
    static autoCrud = true;

    id!: number;
    name!: string;
    category: string = "Uncategorized";
    price: number = 0;
    inStock: boolean = true;
}
```

This registers five routes:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List with filtering and pagination |
| `GET` | `/api/products/{id}` | Get one by ID |
| `POST` | `/api/products` | Create a new record |
| `PUT` | `/api/products/{id}` | Update a record |
| `DELETE` | `/api/products/{id}` | Delete a record |

### Auto-CRUD Features

The generated list endpoint supports query parameters:

```
GET /api/products?page=1&limit=20&sort=price&order=desc&category=Electronics
```

Response format:

```json
{
  "data": [...],
  "meta": {
    "total": 42,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

The generated routes validate input against the `fields` definition. A `POST` with missing required fields returns a `400` error. Soft delete works automatically -- `DELETE` sets `is_deleted = 1` when `softDelete` is enabled.

### When to Use Auto-CRUD

Use it for admin panels, internal tools, and prototypes. For production APIs that need custom logic (authorization checks, notifications, cache invalidation), write your own routes. Custom routes in `src/routes/` take priority over auto-CRUD routes.

---

## 16. Multiple Databases

Models can connect to different databases. Set `static _db` to a named connection:

```typescript
export class Analytics extends BaseModel {
    static tableName = "page_views";
    static _db = "analytics";
    // ...
}
```

Configure the connection in `.env`:

```env
DATABASE_URL=sqlite:///data/app.db
DATABASE_URL_ANALYTICS=sqlite:///data/analytics.db
```

The default connection uses `DATABASE_URL`. Named connections use `DATABASE_URL_<NAME>` (uppercase).

---

## 17. Exercise: Build a Blog

Build a blog with three models: User, Post, and Comment. Use relationships, eager loading, soft delete, and validation.

### Requirements

1. Create three models:
   - `User` with auto-CRUD, hasMany Posts
   - `Post` with belongsTo User, hasMany Comments, soft delete, validation (title required, min 3 chars)
   - `Comment` with belongsTo Post, validation (body required)
2. Create migrations for all three tables
3. Build custom endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/blog/posts` | List published posts with author info |
| `GET` | `/api/blog/posts/{id:int}` | Get a post with author and comments |
| `POST` | `/api/blog/posts/{id:int}/comments` | Add a comment (with validation) |

---

## 18. Solution

### Models

Create `src/orm/User.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class User extends BaseModel {
    static tableName = "users";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        name: { type: "string", required: true },
        email: { type: "string", required: true },
        createdAt: { type: "datetime" },
    };
    static autoCrud = true;
    static hasMany = [{ model: "Post", foreignKey: "user_id" }];

    id!: number;
    name!: string;
    email!: string;
    createdAt!: string;
}
```

Create `src/orm/Post.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Post extends BaseModel {
    static tableName = "posts";
    static softDelete = true;
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        userId: { type: "integer", required: true },
        title: { type: "string", required: true, minLength: 3 },
        body: { type: "text" },
        published: { type: "boolean", default: false },
        createdAt: { type: "datetime" },
    };
    static belongsTo = [{ model: "User", foreignKey: "user_id" }];
    static hasMany = [{ model: "Comment", foreignKey: "post_id" }];

    id!: number;
    userId!: number;
    title!: string;
    body!: string;
    published: boolean = false;
    createdAt!: string;
}
```

Create `src/orm/Comment.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Comment extends BaseModel {
    static tableName = "comments";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        postId: { type: "integer", required: true },
        authorName: { type: "string", required: true },
        body: { type: "text", required: true },
        createdAt: { type: "datetime" },
    };
    static belongsTo = [{ model: "Post", foreignKey: "post_id" }];

    id!: number;
    postId!: number;
    authorName!: string;
    body!: string;
    createdAt!: string;
}
```

### Routes

Create `src/routes/blog.ts`:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/blog/posts", async (req, res) => {
    const posts = Post.findAll("published = ?", [1], ["user"]);

    return res.json({
        posts: posts.map(p => p.toDict(["user"])),
        count: posts.length,
    });
});

Router.get("/api/blog/posts/{id:int}", async (req, res) => {
    const post = Post.findById(req.params.id, ["user", "comments"]);

    if (!post) {
        return res.status(404).json({ error: "Post not found" });
    }

    return res.json(post.toDict(["user", "comments"]));
});

Router.post("/api/blog/posts/{id:int}/comments", async (req, res) => {
    const post = Post.findById(req.params.id);

    if (!post) {
        return res.status(404).json({ error: "Post not found" });
    }

    const comment = new Comment(req.body);
    comment.postId = req.params.id;

    const errors = comment.validate();
    if (errors.length > 0) {
        return res.status(400).json({ errors });
    }

    comment.save();

    return res.status(201).json(comment.toDict());
});
```

---

## 19. Gotchas

### 1. Table Naming Convention

**Problem:** Your model class is `OrderItem` but queries fail because the table does not exist.

**Cause:** Tina4 converts `OrderItem` to `order_items`. If your table is named differently, no match.

**Fix:** Set `static tableName = "order_item"` explicitly.

### 2. Relationship Foreign Key Direction

**Problem:** `hasMany` with the wrong foreign key produces wrong results.

**Cause:** The foreign key is the column on the related table, not the current table.

**Fix:** For `hasMany` and `hasOne`, the foreign key is on the child table. For `belongsTo`, the foreign key is on the current table.

### 3. camelCase to snake_case Mapping

**Problem:** Property `userId` does not map to column `user_id`.

**Fix:** Tina4 converts between `camelCase` and `snake_case` automatically. Ensure your database columns use `snake_case`. For non-standard columns, use `fieldMapping`.

### 4. Forgetting save()

**Problem:** You set properties but the database does not change.

**Fix:** Always call `product.save()` after modifying properties.

### 5. findById Returns null, Not an Empty Model

**Problem:** You call `Product.findById(99)` and try to access `.name` but get a null reference error.

**Fix:** `findById()` returns `null` when no record matches. Check the return value before accessing properties.

### 6. select() Returns Model Instances, Not Plain Objects

**Problem:** JSON serialization misses some fields.

**Fix:** Use `result.toDict()` to convert to a plain object for JSON responses.

### 7. Auto-CRUD Endpoint Conflicts

**Problem:** Your custom route at `/api/products/{id}` conflicts with auto-CRUD.

**Fix:** Custom routes defined in `src/routes/` take precedence over auto-CRUD routes.

### 8. Validation Runs on Model Data, Not Request Body

**Problem:** You call `product.validate()` before setting properties and get no errors.

**Fix:** Set the model's properties first (or pass data to the constructor), then call `validate()`. The validator checks the model's current field values against the `fields` definition.

### 9. restore() Fails on Non-Soft-Delete Models

**Problem:** Calling `restore()` on a model without `softDelete = true` throws an error.

**Fix:** Only use `restore()` on models with `static softDelete = true`. The method throws: "restore() is only available on models with softDelete enabled."

### 10. createTable() Does Not Run Migrations

**Problem:** You call `createTable()` but your migration history does not reflect the change.

**Fix:** `createTable()` executes raw DDL. It does not register in the migration system. Use it for prototyping and tests. For production, use migration files.
