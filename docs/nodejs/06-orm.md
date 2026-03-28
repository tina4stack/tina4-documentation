# Chapter 6: ORM

## 1. From SQL to Objects

In Chapter 5 you wrote raw SQL for every operation. It works. It gets tedious. The same `INSERT INTO products (name, price, ...) VALUES (:name, :price, ...)` pattern over and over. The ORM (Object-Relational Mapper) replaces that repetition with TypeScript classes. Define a class. Map it to a table. Call `save()`, `load()`, and `delete()`.

Tina4's ORM is minimal by design. It does not hide SQL. It gives you convenient methods for common operations and steps aside when you need raw queries.

---

## 2. Defining a Model

ORM models live in `src/orm/`. Every `.ts` file in that directory is auto-loaded. Same discovery pattern as route files.

Create `src/orm/Product.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Product extends BaseModel {
    static tableName = "products";
    static primaryKey = "id";

    id!: number;
    name!: string;
    category: string = "Uncategorized";
    price: number = 0.00;
    inStock: boolean = true;
    createdAt!: string;
    updatedAt!: string;
}
```

That is a complete model. Here is what each piece does:

- **Extends `BaseModel`** -- This gives you `save()`, `load()`, `delete()`, `select()`, and other methods.
- **Public properties** -- Each property maps to a database column. The property name is `camelCase` and the column name is `snake_case`. Tina4 converts between them automatically: `inStock` maps to `in_stock`, `createdAt` maps to `created_at`.
- **`static tableName`** -- The database table this model maps to. If you omit it, Tina4 infers it from the class name: `Product` becomes `products`, `OrderItem` becomes `order_items`.
- **`static primaryKey`** -- The primary key column. Defaults to `"id"`.
- **Default values** -- Properties with defaults (like `category = "Uncategorized"`) are used when creating new records.

### Field Mapping

When your TypeScript property names do not match the database column names, use `fieldMapping` to define the translation:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class User extends BaseModel {
    static tableName = "user_accounts";
    static primaryKey = "id";
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

With this mapping, `user.firstName` reads from and writes to the `fname` column in the database. The ORM handles the conversion in both directions -- on `load()`, `save()`, `select()`, `toDict()`, and `toObject()`. This takes priority over the default `camelCase` to `snake_case` conversion. Useful when working with legacy databases or third-party schemas where you cannot rename the columns.

### Automatic Field Mapping with autoMap

If your database columns follow `snake_case` and your TypeScript properties follow `camelCase`, you can skip writing `fieldMapping` entirely. Set `static autoMap = true` and Tina4 generates the mapping for you:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Order extends BaseModel {
    static tableName = "orders";
    static primaryKey = "id";
    static autoMap = true;

    id!: number;
    customerName!: string;   // maps to customer_name
    orderTotal!: number;     // maps to order_total
    createdAt!: string;      // maps to created_at
}
```

Explicit `fieldMapping` entries always take priority over `autoMap`. Use both together when most columns follow the convention but a few do not.

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

Use TypeScript type declarations on your properties:

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
    await product.save();

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
  "in_stock": true,
  "created_at": "2026-03-22 14:30:00",
  "updated_at": "2026-03-22 14:30:00"
}
```

### toDict() and toObject()

`toDict()` returns the model data as a plain object with `snake_case` keys -- matching the database column names. `toObject()` returns `camelCase` keys -- matching the TypeScript property names. Use `toDict()` for API responses. Use `toObject()` for internal TypeScript usage.

### Updating an Existing Record

When `id` is already set, `save()` performs an UPDATE:

```typescript
Router.put("/api/products/{id:int}", async (req, res) => {
    const product = new Product();
    await product.load(req.params.id);

    if (!product.id) {
        return res.status(404).json({ error: "Product not found" });
    }

    const body = req.body;
    product.name = body.name ?? product.name;
    product.price = parseFloat(body.price ?? product.price);
    product.category = body.category ?? product.category;
    await product.save();

    return res.json(product.toDict());
});
```

---

## 5. Loading Records

### load() -- Get by Primary Key

```typescript
const product = new Product();
await product.load(42);

if (!product.id) {
    // Product with ID 42 not found
}
```

---

## 6. Deleting Records

```typescript
Router.delete("/api/products/{id:int}", async (req, res) => {
    const product = new Product();
    await product.load(req.params.id);

    if (!product.id) {
        return res.status(404).json({ error: "Product not found" });
    }

    await product.delete();

    return res.status(204).json(null);
});
```

---

## 7. Querying with select()

### Basic Select

```typescript
const product = new Product();
const products = await product.select("*");
```

### Filtering

```typescript
const product = new Product();

const electronics = await product.select("*", "category = :category", { category: "Electronics" });

const affordable = await product.select("*", "price < :maxPrice AND in_stock = :inStock", {
    maxPrice: 100,
    inStock: 1
});
```

### Ordering and Pagination

```typescript
const product = new Product();
const sorted = await product.select("*", "", {}, "price DESC");

const page = 1;
const perPage = 10;
const offset = (page - 1) * perPage;
const products = await product.select("*", "", {}, "name ASC", perPage, offset);
```

### A Full List Endpoint with Filters

```typescript
import { Router } from "tina4-nodejs";
import { Product } from "../orm/Product";

Router.get("/api/products", async (req, res) => {
    const product = new Product();

    const category = req.query.category ?? "";
    const page = parseInt(req.query.page ?? "1", 10);
    const perPage = parseInt(req.query.per_page ?? "20", 10);
    const sort = req.query.sort ?? "name";
    const order = (req.query.order ?? "ASC").toUpperCase();

    const conditions: string[] = [];
    const params: Record<string, any> = {};

    if (category) {
        conditions.push("category = :category");
        params.category = category;
    }

    const filter = conditions.join(" AND ");
    const allowedSorts = ["name", "price", "category", "created_at"];
    const safeSort = allowedSorts.includes(sort) ? sort : "name";
    const safeOrder = order === "DESC" ? "DESC" : "ASC";
    const offset = (page - 1) * perPage;

    const products = await product.select("*", filter, params, `${safeSort} ${safeOrder}`, perPage, offset);

    const results = products.map(p => p.toDict());

    return res.json({
        products: results,
        page,
        per_page: perPage,
        count: results.length
    });
});
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
    static primaryKey = "id";
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
    static primaryKey = "id";
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

### Using Relationships

```typescript
Router.get("/api/users/{id:int}", async (req, res) => {
    const user = new User();
    await user.load(req.params.id);

    if (!user.id) {
        return res.status(404).json({ error: "User not found" });
    }

    const posts = await user.posts();

    return res.json({
        user: user.toDict(),
        posts: posts.map(p => p.toDict()),
        post_count: posts.length
    });
});
```

---

## 9. Eager Loading

The N+1 query problem kills performance. Eager loading stops it cold:

```typescript
const user = new User();
const users = await user.select("*", "", {}, "name ASC", 20, 0, ["posts"]);
```

The seventh argument is an array of relationship names to include. This runs just 2 queries.

### Nested Eager Loading

```typescript
const user = new User();
const users = await user.select("*", "", {}, "", 0, 0, ["posts", "posts.comments"]);
```

---

## 10. Soft Delete

If your model has a `deletedAt` property, Tina4 supports soft delete:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Post extends BaseModel {
    static tableName = "posts";
    static primaryKey = "id";
    static softDelete = true;

    id!: number;
    title!: string;
    body!: string;
    deletedAt: string | null = null;
}
```

With `softDelete = true`:

- `post.delete()` sets `deleted_at` to the current timestamp instead of deleting the row
- `select()` automatically excludes soft-deleted rows
- `post.forceDelete()` permanently removes the row

---

## 11. Auto-CRUD

Add `static autoCrud = true` and Tina4 generates REST endpoints for you:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Product extends BaseModel {
    static tableName = "products";
    static primaryKey = "id";
    static autoCrud = true;

    id!: number;
    name!: string;
    category: string = "Uncategorized";
    price: number = 0.00;
    inStock: boolean = true;
}
```

This automatically registers:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/products` | List all with pagination |
| `GET` | `/api/products/{id}` | Get one by ID |
| `POST` | `/api/products` | Create a new record |
| `PUT` | `/api/products/{id}` | Update a record |
| `DELETE` | `/api/products/{id}` | Delete a record |

---

## 12. Exercise: Build a Blog

Build a blog with three models: User, Post, and Comment. Use relationships, eager loading, and auto-CRUD.

### Requirements

1. Create three models: User (with autoCrud), Post (belongsTo User, hasMany Comments), Comment (belongsTo Post)
2. Create migrations for all three tables
3. Build custom endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/blog/posts` | List published posts with author info |
| `GET` | `/api/blog/posts/{id:int}` | Get a post with author and comments |
| `POST` | `/api/blog/posts/{id:int}/comments` | Add a comment to a post |

---

## 13. Solution

### Models

Create `src/orm/User.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class User extends BaseModel {
    static tableName = "users";
    static primaryKey = "id";
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
    static primaryKey = "id";
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
    static primaryKey = "id";
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
import { Post } from "../orm/Post";
import { Comment } from "../orm/Comment";

Router.get("/api/blog/posts", async (req, res) => {
    const post = new Post();
    const posts = await post.select("*", "published = :published", { published: 1 }, "created_at DESC", 0, 0, ["user"]);

    return res.json({
        posts: posts.map(p => p.toDict()),
        count: posts.length
    });
});

Router.get("/api/blog/posts/{id:int}", async (req, res) => {
    const post = new Post();
    await post.load(req.params.id);

    if (!post.id) {
        return res.status(404).json({ error: "Post not found" });
    }

    const user = await post.user();
    const comments = await post.comments();

    const result = post.toDict();
    result.user = user ? user.toDict() : null;
    result.comments = comments.map(c => c.toDict());
    result.comment_count = comments.length;

    return res.json(result);
});

Router.post("/api/blog/posts", async (req, res) => {
    const body = req.body;

    if (!body.title || !body.body || !body.user_id) {
        return res.status(400).json({ error: "title, body, and user_id are required" });
    }

    const post = new Post();
    post.userId = parseInt(body.user_id, 10);
    post.title = body.title;
    post.body = body.body;
    post.published = Boolean(body.published ?? false);
    await post.save();

    return res.status(201).json(post.toDict());
});

Router.post("/api/blog/posts/{id:int}/comments", async (req, res) => {
    const postId = req.params.id;

    const post = new Post();
    await post.load(postId);

    if (!post.id) {
        return res.status(404).json({ error: "Post not found" });
    }

    const body = req.body;

    if (!body.author_name || !body.body) {
        return res.status(400).json({ error: "author_name and body are required" });
    }

    const comment = new Comment();
    comment.postId = postId;
    comment.authorName = body.author_name;
    comment.body = body.body;
    await comment.save();

    return res.status(201).json(comment.toDict());
});
```

---

## 14. Gotchas

### 1. Table Naming Convention

**Problem:** Your model class is `OrderItem` but queries fail because the table does not exist.

**Cause:** Tina4 converts `OrderItem` to `order_items`. If your table is named differently, it will not match.

**Fix:** Set `static tableName = "order_item"` explicitly.

### 2. Relationship Foreign Key Direction

**Problem:** `hasMany` with the wrong foreign key gives wrong results.

**Cause:** The foreign key is the column on the related table, not the current table.

**Fix:** For `hasMany`, the foreign key is on the child table. For `belongsTo`, it is on the current table.

### 3. camelCase to snake_case Mapping

**Problem:** Property `userId` does not map to column `user_id`.

**Fix:** Tina4 automatically converts between `camelCase` and `snake_case`. Ensure your database columns use `snake_case`.

### 4. Forgetting save()

**Problem:** You set properties but the database does not change.

**Fix:** Always call `await product.save()` after modifying properties.

### 5. Forgetting await

**Problem:** `product.save()` returns a Promise but data is not persisted.

**Fix:** Always `await` ORM methods: `await product.save()`, `await product.load(id)`, `await product.select(...)`.

### 6. select() Returns Model Instances, Not Plain Objects

**Problem:** You try to use `result.name` and it works, but JSON serialization misses some fields.

**Fix:** Use `result.toDict()` or `result.toObject()` to convert to a plain object for JSON responses.

### 7. Auto-CRUD Endpoint Conflicts

**Problem:** Your custom route at `/api/products/:id` conflicts with auto-CRUD.

**Fix:** Custom routes defined in `src/routes/` take precedence over auto-CRUD routes.
