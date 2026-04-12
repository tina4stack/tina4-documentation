# Chapter 6: ORM

## 1. From SQL to Objects

The last chapter was raw SQL. It works. It also gets repetitive. Every insert demands an INSERT statement. Every update demands an UPDATE. Every fetch maps column names to object keys. Over and over.

Tina4's ORM turns database rows into TypeScript objects. Define a model class with fields. The ORM writes the SQL. It stays SQL-first -- you can drop to raw SQL at any moment -- but for the 90% case of CRUD operations, the ORM handles the grunt work.

Picture a blog. Authors, posts, comments. Authors own many posts. Posts own many comments. Comments belong to posts. Modeling these relationships with raw SQL means JOINs and manual foreign key management. The ORM makes this declarative.

---

## 2. Defining a Model

Create a model file in `src/models/`. Every `.ts` file in that directory is auto-loaded at startup.

Create `src/models/Note.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Note extends BaseModel {
  static tableName = "notes";
  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    title:     { type: "string" as const, required: true, maxLength: 200 },
    content:   { type: "string" as const, default: "" },
    category:  { type: "string" as const, default: "general" },
    pinned:    { type: "boolean" as const, default: false },
    createdAt: { type: "datetime" as const },
    updatedAt: { type: "datetime" as const },
  };
}
```

A complete model. Here is what each piece does:

- `static tableName` -- the database table this model maps to. If omitted, the ORM uses the lowercase class name (e.g. `Contact` -> `contact`).
- `primaryKey: true` on a field marks it as the primary key (defaults to `id` if none is specified)
- Each field is a property in the `static fields` object with a config object describing its type and constraints

### Field Types

| Field Type | TypeScript Type | SQL Type | Description |
|-----------|----------------|----------|-------------|
| `"integer"` | `number` | `INTEGER` | Whole numbers |
| `"string"` | `string` | `TEXT` | Text strings |
| `"text"` | `string` | `TEXT` | Long text |
| `"number"` | `number` | `REAL` | Decimal numbers |
| `"boolean"` | `boolean` | `INTEGER` (0/1) | True/False |
| `"datetime"` | `string` | `TEXT` | Date and time |

For foreign keys, use `"integer"`. There is no separate foreign key type -- the relationship is defined through `hasMany`, `hasOne`, and `belongsTo` methods instead.

### Field Options

| Option | Type | Description |
|--------|------|-------------|
| `primaryKey` | `boolean` | Marks this field as the primary key |
| `required` | `boolean` | Field must have a value (not undefined) |
| `default` | any | Default value when not provided |
| `maxLength` | `number` | Maximum string length |
| `minLength` | `number` | Minimum string length |
| `min` | `number` | Minimum numeric value |
| `max` | `number` | Maximum numeric value |
| `choices` | array | Allowed values |
| `autoIncrement` | `boolean` | Auto-incrementing integer |
| `pattern` | `string` | Regex pattern the value must match |

### Field Mapping

When your TypeScript property names do not match the database column names, use `static fieldMapping` to define the translation:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class User extends BaseModel {
  static tableName = "user_accounts";
  static fieldMapping = {
    firstName: "fname",        // TS property -> DB column
    lastName:  "lname",
    emailAddress: "email",
  };

  static fields = {
    id:           { type: "integer" as const, primaryKey: true, autoIncrement: true },
    firstName:    { type: "string" as const, required: true },
    lastName:     { type: "string" as const, required: true },
    emailAddress: { type: "string" as const, required: true },
  };
}
```

With this mapping, `user.firstName` reads from and writes to the `fname` column. The ORM handles the conversion in both directions -- on `findById()`, `save()`, `select()`, and `toDict()`. This is useful with legacy databases or third-party schemas where you cannot rename the columns.

### autoMap and Case Conversion

The `static autoMap = true` flag auto-generates `fieldMapping` entries from camelCase field names to snake_case database column names. Explicit `fieldMapping` entries always take precedence.

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class User extends BaseModel {
  static tableName = "users";
  static autoMap = true;  // firstName -> first_name, lastName -> last_name

  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    firstName: { type: "string" as const, required: true },
    lastName:  { type: "string" as const, required: true },
    email:     { type: "string" as const, required: true },
  };
}
```

Two utility functions handle case conversion directly:

```typescript
import { snakeToCamel, camelToSnake } from "tina4-nodejs/orm";

snakeToCamel("first_name");   // "firstName"
camelToSnake("firstName");    // "first_name"
```

A common use case is Firebird or Oracle, which store column names in uppercase:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Account extends BaseModel {
  static tableName    = "ACCOUNTS";
  static fieldMapping: Record<string, string> = {
    accountNo:   "ACCOUNTNO",
    storeName:   "STORENAME",
    creditLimit: "CREDITLIMIT",
  };

  static fields = {
    accountNo:   { type: "string" as const },
    storeName:   { type: "string" as const },
    creditLimit: { type: "number" as const, default: 0 },
  };
}
```

TypeScript code uses clean camelCase names (`account.accountNo`, `account.creditLimit`). The ORM maps them to the uppercase DB columns automatically.

### getDbColumn and getDbData

Two helpers expose the fieldMapping in custom code:

```typescript
// Get the DB column name for a JS property
const col = Account.getDbColumn("accountNo");   // "ACCOUNTNO"

// Get all instance fields using DB column names as keys
const data = account.getDbData();
// { ACCOUNTNO: "A001", STORENAME: "Main Store", CREDITLIMIT: 5000 }
```

These are used internally by `save()` and `createTable()`, but available for custom queries.

### find() vs where() -- naming convention

The two query methods have a deliberate difference in how they handle column names:

- **`find(filterObj)`** uses **TypeScript property names**. The ORM translates them via `fieldMapping`.
- **`where(sql)`** uses **raw DB column names** in the SQL string. No translation is applied.

```typescript
// find() -- use TS property names (fieldMapping applied)
const accounts = Account.find({ accountNo: "A001" });   // translates to ACCOUNTNO = ?

// where() -- use DB column names directly in the SQL
const accounts2 = Account.where("ACCOUNTNO = ?", ["A001"]);  // raw SQL, no translation
```

This means `find()` is portable across database engines, while `where()` gives you full control of the SQL.

---

## 3. createTable -- Schema from Models

You can create the database table directly from your model definition:

```typescript
Note.createTable();
```

This generates and runs the CREATE TABLE SQL based on your field definitions. It is good for development and testing. For production, use migrations (Chapter 5) for version-controlled schema changes.

If the table already exists, `createTable()` does nothing.

---

## 4. CRUD Operations

### save -- Create or Update

```typescript
// src/routes/api/notes/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Note from "../../models/Note.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const body = req.body as Record<string, unknown>;

  const note = new Note();
  note.title = body.title;
  note.content = body.content ?? "";
  note.category = body.category ?? "general";
  note.pinned = body.pinned ?? false;
  note.save();

  res.json({ message: "Note created", note: note.toDict() }, 201);
}
```

`save()` detects whether the record is new (INSERT) or existing (UPDATE) based on whether the primary key has a value. It returns `this` on success for chaining. It returns `false` on failure.

### create -- Build and Save in One Step

When you have a data object ready, `create()` builds the model and saves it in one call:

```typescript
const note = Note.create({
  title: "Quick Note",
  content: "Created in one step",
  category: "general",
});
```

### findById -- Fetch One Record by Primary Key

```typescript
// src/routes/api/notes/[id]/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Note from "../../../models/Note.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const note = Note.findById(req.params.id);

  if (note === null) {
    return res.json({ error: "Note not found" }, 404);
  }

  res.json(note.toDict());
}
```

`findById()` takes a primary key value and returns a model instance, or `null` if no row matches. If soft delete is enabled, it excludes soft-deleted records.

Use `findOrFail()` when you want an Error thrown instead of `null`:

```typescript
const note = Note.findOrFail(id);  // Throws Error if not found
```

### find -- Query by Filter Dict

The `find()` method accepts an object of column-value pairs and returns an array of matching records:

```typescript
// Find all notes in the "work" category
const workNotes = Note.find({ category: "work" });

// Find with pagination and ordering
const recent = Note.find({ pinned: true }, 10, 0, "created_at DESC");

// Find all records (no filter)
const allNotes = Note.find();
```

The full signature is `find(filter?, limit?, offset?, orderBy?, include?)`.

### where -- Query with SQL Conditions

For more complex queries, `where()` takes a SQL WHERE clause with `?` placeholders:

```typescript
const notes = Note.where("category = ?", ["work"]);
```

### delete -- Remove a Record

```typescript
// src/routes/api/notes/[id]/delete.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Note from "../../../models/Note.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const note = Note.findById(req.params.id);

  if (note === null) {
    return res.json({ error: "Note not found" }, 404);
  }

  note.delete();

  res.json(null, 204);
}
```

### Listing Records

```typescript
// src/routes/api/notes/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Note from "../../models/Note.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const category = req.query.category;

  let notes;
  if (category) {
    notes = Note.where("category = ?", [category]);
  } else {
    notes = Note.all();
  }

  res.json({
    notes: notes.map((n) => n.toDict()),
    count: notes.length,
  });
}
```

`where()` takes a WHERE clause with `?` placeholders and an array of parameters. It returns an array of model instances. `all()` fetches all records. Both support pagination:

```typescript
// With pagination
const notes = Note.where("category = ?", ["work"], 20, 40);

// Fetch all with pagination -- all() takes an optional where clause string
const notes2 = Note.all("category = ?", ["work"]);

// SQL-first query -- full control over the SQL
const notes3 = Note.select(
  "SELECT * FROM notes WHERE pinned = ? ORDER BY created_at DESC",
  [1],
);
```

### selectOne -- Fetch a Single Record by SQL

When you need exactly one record from a custom SQL query:

```typescript
const note = Note.selectOne("SELECT * FROM notes WHERE slug = ?", ["my-note"]);
```

Returns a model instance or `null`.

### load -- Populate an Existing Instance

The `load()` method fills an existing model instance from the database:

```typescript
const note = new Note();
note.id = 42;
note.load();  // Loads data for id=42

// Or with a filter string
const note2 = new Note();
note2.load("slug = ?", ["my-note"]);
```

Returns `true` if a record was found, `false` otherwise.

### count -- Count Records

```typescript
const total = Note.count();
const workCount = Note.count("category = ?", ["work"]);
```

Respects soft delete -- only counts non-deleted records.

---

## 5. toDict, toJson, and Other Serialisation

### toDict

Convert a model instance to a plain object:

```typescript
const note = Note.findById(1);

const data = note.toDict();
// { id: 1, title: "Shopping List", content: "Milk, eggs", category: "personal", pinned: false, createdAt: "2026-03-22 14:30:00", updatedAt: "2026-03-22 14:30:00" }
```

The `include` parameter adds relationship data to the output (see Eager Loading below). Pass an array of relationship names:

```typescript
// Include relationships in the output
const data = note.toDict(["comments"]);
```

### toJson

Convert directly to a JSON string:

```typescript
const jsonString = note.toJson();
// '{"id":1,"title":"Shopping List",...}'
```

### Other Serialisation Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `toDict(include?)` | `Record<string, unknown>` | Primary dict method with optional relationship includes |
| `toAssoc(include?)` | `Record<string, unknown>` | Alias for `toDict()` |
| `toObject()` | `Record<string, unknown>` | Alias for `toDict()` |
| `toJson(include?)` | `string` | JSON string |
| `toArray()` | `unknown[]` | Flat array of values (no keys) |
| `toList()` | `unknown[]` | Alias for `toArray()` |

---

## 6. Relationships

### foreignKey Field Type — Auto-Wired Relationships

Declaring a field with `type: "foreignKey"` and a `references` model name automatically wires both sides of the relationship. The declaring model gets a `belongsTo` entry (the column name with `_id` stripped → the association name), and the referenced model gets a `hasMany` entry (the declaring model's table name, or whatever you pass via `relatedName`).

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class User extends BaseModel {
    static tableName = "users";
    static fields = {
        id:   { type: "integer", primaryKey: true, autoIncrement: true },
        name: { type: "string", required: true },
    };
}

export class Post extends BaseModel {
    static tableName = "posts";
    static fields = {
        id:      { type: "integer", primaryKey: true, autoIncrement: true },
        title:   { type: "string", required: true },
        // Auto-wires Post.belongsTo User and User.hasMany Post
        user_id: { type: "foreignKey", references: "User" },
    };
}
```

With just the `foreignKey` field, both sides are accessible:

```typescript
const post = Post.findById(1);
const user = post.belongsTo(User, "user_id");
console.log(user?.name);     // "Alice"

// Or via toDict with include
const postData = post.toDict(["user"]);

const alice = User.findById(1);
const posts = alice.hasMany(Post, "user_id");
posts.forEach(p => console.log(p.title));
```

For a custom `hasMany` key, pass `relatedName`:

```typescript
user_id: { type: "foreignKey", references: "User", relatedName: "blog_posts" }
// User.hasMany entry will use "blog_posts" instead of the default
```

Models must be registered via `BaseModel.registerModel("User", User)` before eager loading can resolve the reference by name.

### hasMany

An author has many posts:

Create `src/models/Author.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Author extends BaseModel {
  static tableName = "authors";
  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    name:      { type: "string" as const, required: true },
    email:     { type: "string" as const, required: true },
    bio:       { type: "string" as const, default: "" },
    createdAt: { type: "datetime" as const },
  };
}
```

Create `src/models/BlogPost.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class BlogPost extends BaseModel {
  static tableName = "posts";
  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    authorId:  { type: "integer" as const, required: true },
    title:     { type: "string" as const, required: true, maxLength: 300 },
    slug:      { type: "string" as const, required: true },
    content:   { type: "string" as const, default: "" },
    status:    { type: "string" as const, default: "draft", choices: ["draft", "published", "archived"] },
    createdAt: { type: "datetime" as const },
    updatedAt: { type: "datetime" as const },
  };
}
```

Now use `hasMany` to get an author's posts:

```typescript
// src/routes/api/authors/[id]/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Author from "../../../models/Author.js";
import BlogPost from "../../../models/BlogPost.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const author = Author.findById(req.params.id);

  if (author === null) {
    return res.json({ error: "Author not found" }, 404);
  }

  const posts = author.hasMany(BlogPost, "author_id");

  const data = author.toDict();
  data.posts = posts.map((p) => p.toDict());

  res.json(data);
}
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

`hasMany()` accepts an optional `limit` and `offset` for pagination: `author.hasMany(BlogPost, "author_id", 10, 0)`.

### hasOne

A user has one profile:

```typescript
const profile = user.hasOne(Profile, "user_id");
```

Returns a single model instance or `null`.

### belongsTo

A post belongs to an author:

```typescript
// src/routes/api/posts/[id]/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Author from "../../../models/Author.js";
import BlogPost from "../../../models/BlogPost.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const post = BlogPost.findById(req.params.id);

  if (post === null) {
    return res.json({ error: "Post not found" }, 404);
  }

  const author = post.belongsTo(Author, "author_id");

  const data = post.toDict();
  data.author = author ? author.toDict() : null;

  res.json(data);
}
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

---

## 7. Eager Loading

Calling relationship methods inside a loop creates the N+1 problem. Load 10 authors. Call `hasMany(BlogPost, "author_id")` for each one. That fires 11 queries -- 1 for authors, 10 for posts. The page drags.

The `include` parameter on `all()`, `where()`, `findById()`, and `selectOne()` solves this. It eager-loads relationships in bulk.

Eager loading requires two things: declarative relationship definitions on the model, and model registration.

### Declarative Relationships

Define relationships as static arrays on your model class:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Author extends BaseModel {
  static tableName = "authors";
  static hasMany = [{ model: "BlogPost", foreignKey: "author_id" }];
  static fields = {
    id:    { type: "integer" as const, primaryKey: true, autoIncrement: true },
    name:  { type: "string" as const, required: true },
    email: { type: "string" as const, required: true },
    bio:   { type: "string" as const, default: "" },
  };
}
```

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class BlogPost extends BaseModel {
  static tableName = "posts";
  static belongsTo = [{ model: "Author", foreignKey: "author_id" }];
  static hasMany = [{ model: "Comment", foreignKey: "post_id" }];
  static fields = {
    id:       { type: "integer" as const, primaryKey: true, autoIncrement: true },
    authorId: { type: "integer" as const, required: true },
    title:    { type: "string" as const, required: true },
    status:   { type: "string" as const, default: "draft" },
  };
}
```

Register the models so eager loading can resolve them by name:

```typescript
BaseModel.registerModel("Author", Author);
BaseModel.registerModel("BlogPost", BlogPost);
BaseModel.registerModel("Comment", Comment);
```

Now use `include` to eager-load:

```typescript
// Eager load posts when fetching all authors
const authors = Author.all(undefined, undefined, ["posts"]);

// Eager load author and comments when finding a single post
const post = BlogPost.findById(1, ["author", "comments"]);
```

Without eager loading, 10 authors and their posts cost 11 queries. With eager loading: 2 queries. That is the difference between a fast page and a slow one.

### Nested Eager Loading

Dot notation loads multiple levels deep:

```typescript
// Load authors, their posts, and each post's comments
const authors = Author.all(undefined, undefined, ["posts", "posts.comments"]);
```

Authors, their posts, and each post's comments. Three queries total instead of hundreds.

### toDict with Nested Includes

When eager loading is active, `toDict(include)` embeds the related data:

```typescript
const post = BlogPost.findById(1, ["author", "comments"]);
const data = post.toDict(["author", "comments"]);
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

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Task extends BaseModel {
  static tableName = "tasks";
  static softDelete = true;  // Enable soft delete

  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    title:     { type: "string" as const, required: true },
    completed: { type: "boolean" as const, default: false },
    isDeleted: { type: "integer" as const, default: 0 },  // Required for soft delete (0 = active, 1 = deleted)
    createdAt: { type: "string" as const },
  };
}
```

When `static softDelete = true`, the ORM changes its behaviour:

- `task.delete()` sets `is_deleted` to `1` instead of running a DELETE query
- `Task.all()`, `Task.where()`, and `Task.findById()` filter out records where `is_deleted = 1`
- `task.restore()` sets `is_deleted` back to `0` and makes the record visible again
- `task.forceDelete()` permanently removes the row from the database
- `Task.withTrashed()` includes soft-deleted records in query results

### Deleting and Restoring

```typescript
// Soft delete -- sets is_deleted = 1, row stays in the database
const task = Task.findById(1);
task.delete();

// Restore -- sets is_deleted = 0, record is visible again
task.restore();

// Permanently delete -- removes the row, no recovery possible
task.forceDelete();
```

`restore()` is the inverse of `delete()`. It sets `is_deleted` back to `0` and commits the change. The record reappears in all standard queries.

### Including Soft-Deleted Records

Standard queries (`all()`, `where()`, `findById()`) exclude soft-deleted records. When you need to see everything -- for admin dashboards, audit logs, or data recovery -- use `withTrashed()`:

```typescript
// All tasks, including soft-deleted ones
const allTasks = Task.withTrashed();

// Soft-deleted tasks matching a condition
const deletedTasks = Task.withTrashed("completed = ?", [1]);
```

`withTrashed()` accepts the same filter parameters as `where()`: `withTrashed(conditions?, params?, limit?, offset?)`. The only difference: it ignores the `is_deleted` filter that standard queries apply.

### Counting with Soft Delete

The `count()` method respects soft delete. It only counts non-deleted records:

```typescript
const activeCount = Task.count();
const activeWork = Task.count("category = ?", ["work"]);
```

### When to Use Soft Delete

Soft delete suits data that users might want to recover -- emails, documents, user accounts. It also serves audit requirements where regulations demand retention. For temporary data (sessions, cache entries, logs), hard delete keeps the table lean.

---

## 9. Auto-CRUD

Writing the same five REST endpoints for every model gets tedious. Auto-CRUD generates them from your model class. Define the model. Set the flag. Five routes appear.

### The autoCrud Flag

Set `static autoCrud = true` on your model class:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Note extends BaseModel {
  static tableName = "notes";
  static autoCrud = true;  // Generates REST endpoints automatically

  static fields = {
    id:      { type: "integer" as const, primaryKey: true, autoIncrement: true },
    title:   { type: "string" as const, required: true },
    content: { type: "string" as const, default: "" },
  };
}
```

When the ORM discovers this model at startup, it registers CRUD routes. Five routes appear.

### Manual Registration

You can also register routes explicitly using `generateCrudRoutes()`:

```typescript
import { generateCrudRoutes } from "tina4-nodejs/orm";
```

Both approaches produce the same result:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all with filtering and pagination |
| `GET` | `/api/notes/{id}` | Get one by primary key |
| `POST` | `/api/notes` | Create a new record |
| `PUT` | `/api/notes/{id}` | Update a record |
| `DELETE` | `/api/notes/{id}` | Delete a record |

The endpoint prefix derives from the table name. The `notes` table becomes `/api/notes`.

### What the Generated Routes Do

**GET /api/notes** returns paginated results with filtering and sorting:

```bash
curl "http://localhost:7148/api/notes?limit=10&page=1"
```

```json
{
  "records": [...],
  "data": [...],
  "total": 42,
  "count": 42,
  "limit": 10,
  "page": 1,
  "perPage": 10,
  "totalPages": 5
}
```

The list endpoint supports query parameters:
- `?filter[field]=value` -- filter by field value
- `?sort=-name` -- sort by field (prefix `-` for descending)
- `?page=2&limit=10` -- pagination

**POST /api/notes** validates input before saving:

```bash
curl -X POST http://localhost:7148/api/notes \
  -H "Content-Type: application/json" \
  -d '{"title": "New Note", "content": "Created via auto-CRUD"}'
```

If validation fails (for example, a required field is missing), the endpoint returns a 422 with error details:

```json
{"error": "Validation failed", "statusCode": 422, "errors": ["title: This field is required"]}
```

**DELETE /api/notes/1** respects soft delete. If the model has `static softDelete = true`, the record is marked deleted instead of removed.

### Custom Routes Alongside Auto-CRUD

Custom routes defined in `src/routes/` load before auto-CRUD routes. They take precedence. If you need special logic for one endpoint (custom validation, side effects, complex queries), define that route as a file. Auto-CRUD handles the rest.

### Table Filter

The `static tableFilter` property adds a permanent WHERE condition to all auto-CRUD queries:

```typescript
export default class ActiveUser extends BaseModel {
  static tableName = "users";
  static tableFilter = "active = 1";
  static autoCrud = true;
  // ...
}
```

Every auto-CRUD query for this model appends `AND active = 1`.

---

## 10. Scopes

Scopes are reusable query filters baked into the model. In TypeScript, you can define them as static methods:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class BlogPost extends BaseModel {
  static tableName = "posts";
  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    title:     { type: "string" as const, required: true },
    status:    { type: "string" as const, default: "draft" },
    createdAt: { type: "datetime" as const },
  };

  static published() {
    return this.where("status = ?", ["published"]);
  }

  static drafts() {
    return this.where("status = ?", ["draft"]);
  }

  static recent(days = 7) {
    return this.where(
      "created_at > datetime('now', ?)",
      [`-${days} days`],
    );
  }
}
```

Use them in your routes:

```typescript
// src/routes/api/posts/published/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import BlogPost from "../../../models/BlogPost.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const posts = BlogPost.published();
  res.json({ posts: posts.map((p) => p.toDict()) });
}
```

You can also register scopes dynamically with the `scope()` static method:

```typescript
BlogPost.scope("active", "status != ?", ["archived"]);

// Now call it (cast needed since it's dynamically added):
const activePosts = (BlogPost as any).active();

// With limit and offset:
const activePosts2 = (BlogPost as any).active(10, 5);
```

`scope()` returns void. It registers a method on the class that calls `where()` with the given filter. The registered method accepts optional `limit` and `offset` parameters.

Scopes keep query logic in the model where it belongs. Route handlers stay thin.

---

## 11. Input Validation

Field definitions carry validation rules. Call `validate()` before `save()` and the ORM checks every constraint:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Product extends BaseModel {
  static tableName = "products";
  static fields = {
    id:       { type: "integer" as const, primaryKey: true, autoIncrement: true },
    name:     { type: "string" as const, required: true, minLength: 2, maxLength: 200 },
    sku:      { type: "string" as const, required: true, pattern: "^[A-Z]{2}-\\d{4}$" },  // e.g., EL-1234
    price:    { type: "number" as const, required: true, min: 0.01, max: 999999.99 },
    category: { type: "string" as const, choices: ["Electronics", "Kitchen", "Office", "Fitness"] },
  };
}
```

```typescript
// src/routes/api/products/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Product from "../../models/Product.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const body = req.body as Record<string, unknown>;

  const product = new Product();
  product.name = body.name;
  product.sku = body.sku;
  product.price = body.price;
  product.category = body.category;

  const errors = product.validate();
  if (errors.length > 0) {
    return res.json({ errors }, 400);
  }

  product.save();
  res.json({ product: product.toDict() }, 201);
}
```

If validation fails, `validate()` returns an array of error strings:

```json
{
  "errors": [
    "name Must be at least 2 characters",
    "sku Must match pattern ^[A-Z]{2}-\\d{4}$",
    "price Must be at least 0.01",
    "category Must be one of: Electronics, Kitchen, Office, Fitness"
  ]
}
```

---

## 12. Exercise: Build a Blog with Relationships

Build a blog API with authors, posts, and comments.

### Requirements

1. Create these models:

**Author:** `id`, `name` (required), `email` (required), `bio`, `createdAt`

**BlogPost:** `id`, `authorId` (integer foreign key), `title` (required, max 300), `slug` (required), `content`, `status` (choices: draft/published/archived, default draft), `createdAt`, `updatedAt`

**Comment:** `id`, `postId` (integer foreign key), `authorName` (required), `authorEmail` (required), `body` (required, min 5 chars), `createdAt`

2. Build these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/authors` | Create an author |
| `GET` | `/api/authors/{id}` | Get author with their posts |
| `POST` | `/api/posts` | Create a post (requires authorId) |
| `GET` | `/api/posts` | List published posts with author info |
| `GET` | `/api/posts/{id}` | Get post with author and comments |
| `POST` | `/api/posts/{id}/comments` | Add comment to a post |

---

## 13. Solution

Create `src/models/Author.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Author extends BaseModel {
  static tableName = "authors";
  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    name:      { type: "string" as const, required: true, minLength: 2 },
    email:     { type: "string" as const, required: true },
    bio:       { type: "string" as const, default: "" },
    createdAt: { type: "datetime" as const },
  };
}
```

Create `src/models/BlogPost.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class BlogPost extends BaseModel {
  static tableName = "posts";
  static fields = {
    id:        { type: "integer" as const, primaryKey: true, autoIncrement: true },
    authorId:  { type: "integer" as const, required: true },
    title:     { type: "string" as const, required: true, maxLength: 300 },
    slug:      { type: "string" as const, required: true },
    content:   { type: "string" as const, default: "" },
    status:    { type: "string" as const, default: "draft", choices: ["draft", "published", "archived"] },
    createdAt: { type: "datetime" as const },
    updatedAt: { type: "datetime" as const },
  };

  static published() {
    return this.where("status = ?", ["published"]);
  }
}
```

Create `src/models/Comment.ts`:

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export default class Comment extends BaseModel {
  static tableName = "comments";
  static fields = {
    id:          { type: "integer" as const, primaryKey: true, autoIncrement: true },
    postId:      { type: "integer" as const, required: true },
    authorName:  { type: "string" as const, required: true },
    authorEmail: { type: "string" as const, required: true },
    body:        { type: "string" as const, required: true, minLength: 5 },
    createdAt:   { type: "datetime" as const },
  };
}
```

Create `src/routes/api/authors/post.ts`:

```typescript
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Author from "../../../models/Author.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const body = req.body as Record<string, unknown>;

  const author = new Author();
  author.name = body.name;
  author.email = body.email;
  author.bio = body.bio ?? "";

  const errors = author.validate();
  if (errors.length > 0) {
    return res.json({ errors }, 400);
  }

  author.save();
  res.json({ author: author.toDict() }, 201);
}
```

Create `src/routes/api/authors/[id]/get.ts`:

```typescript
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Author from "../../../../models/Author.js";
import BlogPost from "../../../../models/BlogPost.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const author = Author.findById(req.params.id);

  if (author === null) {
    return res.json({ error: "Author not found" }, 404);
  }

  const posts = BlogPost.where("author_id = ?", [author.id]);

  const data = author.toDict();
  data.posts = posts.map((p) => p.toDict());

  res.json(data);
}
```

Create `src/routes/api/posts/post.ts`:

```typescript
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Author from "../../../models/Author.js";
import BlogPost from "../../../models/BlogPost.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const body = req.body as Record<string, unknown>;

  // Verify author exists
  const author = Author.findById(body.authorId);
  if (author === null) {
    return res.json({ error: "Author not found" }, 404);
  }

  const post = new BlogPost();
  post.authorId = body.authorId;
  post.title = body.title;
  post.slug = body.slug;
  post.content = body.content ?? "";
  post.status = body.status ?? "draft";

  const errors = post.validate();
  if (errors.length > 0) {
    return res.json({ errors }, 400);
  }

  post.save();
  res.json({ post: post.toDict() }, 201);
}
```

Create `src/routes/api/posts/get.ts`:

```typescript
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Author from "../../../models/Author.js";
import BlogPost from "../../../models/BlogPost.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const posts = BlogPost.published();
  const data = [];

  for (const p of posts) {
    const postDict = p.toDict();
    const author = p.belongsTo(Author, "author_id");
    postDict.author = author ? author.toDict() : null;
    data.push(postDict);
  }

  res.json({ posts: data, count: data.length });
}
```

Create `src/routes/api/posts/[id]/get.ts`:

```typescript
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import Author from "../../../../models/Author.js";
import BlogPost from "../../../../models/BlogPost.js";
import Comment from "../../../../models/Comment.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const post = BlogPost.findById(req.params.id);

  if (post === null) {
    return res.json({ error: "Post not found" }, 404);
  }

  const author = post.belongsTo(Author, "author_id");
  const comments = post.hasMany(Comment, "post_id");

  const data = post.toDict();
  data.author = author ? author.toDict() : null;
  data.comments = comments.map((c) => c.toDict());
  data.commentCount = comments.length;

  res.json(data);
}
```

Create `src/routes/api/posts/[id]/comments/post.ts`:

```typescript
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import BlogPost from "../../../../../models/BlogPost.js";
import Comment from "../../../../../models/Comment.js";

export default async function (req: Tina4Request, res: Tina4Response) {
  const post = BlogPost.findById(req.params.id);

  if (post === null) {
    return res.json({ error: "Post not found" }, 404);
  }

  const body = req.body as Record<string, unknown>;

  const comment = new Comment();
  comment.postId = req.params.id;
  comment.authorName = body.authorName;
  comment.authorEmail = body.authorEmail;
  comment.body = body.body;

  const errors = comment.validate();
  if (errors.length > 0) {
    return res.json({ errors }, 400);
  }

  comment.save();
  res.json({ comment: comment.toDict() }, 201);
}
```

---

## 14. Gotchas

### 1. Forgetting to call save()

**Problem:** You set properties on a model but the database does not change.

**Cause:** Setting `note.title = "New Title"` only changes the TypeScript object. The database remains unchanged until you call `note.save()`.

**Fix:** Call `save()` after modifying properties. Check the return value -- `save()` returns `this` on success and `false` on failure.

### 2. findById() returns null

**Problem:** You call `Note.findById(id)` but get `null` instead of a note object.

**Cause:** `findById()` returns `null` when no row matches the given primary key. If soft delete is enabled, `findById()` also excludes soft-deleted records.

**Fix:** Check for `null` after `findById()`: `if (note === null) return res.json({error: "Not found"}, 404)`. Use `findOrFail()` if you want an Error thrown instead.

### 3. find() vs findById()

**Problem:** You call `Note.find(42)` expecting a single record, but get unexpected results.

**Cause:** `find()` takes a filter object (`find({ id: 42 })`), not a bare primary key value. For single-record lookups by primary key, use `findById(42)`.

**Fix:** Use `findById(id)` for primary key lookups. Use `find({ column: value })` for filter-based queries.

### 4. all() not findAll()

**Problem:** You call `Note.findAll()` and get an error.

**Cause:** The method is `all()`, not `findAll()`. There is no `findAll()` method on BaseModel.

**Fix:** Use `Note.all()` to fetch all records.

### 5. toDict() includes everything

**Problem:** `user.toDict()` includes `passwordHash` in the API response.

**Cause:** `toDict()` includes all fields by default.

**Fix:** Build the response object manually, omitting sensitive fields: `{ id: user.id, name: user.name, email: user.email }`. Or create a helper method on your model class that returns only safe fields.

### 6. Validation only runs on validate()

**Problem:** You call `save()` without calling `validate()` first, and invalid data gets into the database.

**Cause:** `save()` does not validate. This is by design -- sometimes you need to save partial data or bypass validation for bulk operations.

**Fix:** Call `const errors = model.validate()` before `save()` in your route handlers. Or create a helper method that validates and saves in one step.

### 7. Foreign key not enforced

**Problem:** You save a post with `authorId = 999` and it succeeds, even though no author with ID 999 exists.

**Cause:** SQLite does not enforce foreign key constraints by default. The ORM defines the relationship through `hasMany`/`belongsTo` methods, but the database itself may not enforce it.

**Fix:** Enable SQLite foreign keys with `PRAGMA foreign_keys = ON;` in a migration, or validate the foreign key in your route handler before saving.

### 8. N+1 query problem

**Problem:** Listing 100 authors with their posts runs 101 queries (1 for authors + 100 for posts), and the page loads slowly.

**Cause:** You call `author.hasMany(BlogPost, "author_id")` inside a loop for each author.

**Fix:** Use eager loading with the `include` parameter on `all()`, `where()`, or `findById()`. Define declarative relationships on the model and register models with `BaseModel.registerModel()`.

### 9. Auto-CRUD endpoint conflicts

**Problem:** Custom route at `/api/notes/{id}` stops working after enabling auto-CRUD for the Note model.

**Cause:** Both routes match the same path. The first registered route wins.

**Fix:** Custom routes in `src/routes/` load before auto-CRUD routes. They take precedence. If you want different behaviour, use a different path for the custom route.

### 10. Soft-deleted records appearing in queries

**Problem:** You soft-deleted a record, but queries still return it.

**Cause:** Soft delete requires the `static softDelete = true` flag on the model class and an `is_deleted` column in the database (integer, 0 or 1). Without both, soft delete is inactive.

**Fix:** Verify both the `static softDelete = true` flag and the `is_deleted` column exist. The column stores `0` for active records and `1` for deleted ones.

---

## 15. QueryBuilder Integration

ORM models provide a `query()` static method that returns a `QueryBuilder` pre-configured with the model's table name and database connection. This gives you a fluent API for building complex queries without writing raw SQL:

```typescript
// Fluent query builder from ORM
const results = User.query()
  .select("id", "name", "email")
  .where("active = ?", [1])
  .orderBy("name")
  .limit(50)
  .get();

// First matching record
const user = User.query()
  .where("email = ?", ["alice@example.com"])
  .first();

// Count
const total = User.query()
  .where("role = ?", ["admin"])
  .count();

// Check existence
const exists = User.query()
  .where("email = ?", ["test@example.com"])
  .exists();
```

The `limit()` method accepts count and an optional offset: `limit(10, 20)`. There is no separate `offset()` method.

Note that `get()` returns plain objects, not model instances. Use `findById()`, `find()`, `all()`, or `where()` when you need model instances with `save()`, `delete()`, and relationship methods.

See the [QueryBuilder chapter](07-query-builder.md) for the full fluent API including joins, grouping, having, and MongoDB support.

### Multiple Database Connections

A model can target a named database connection using `static _db`:

```typescript
export default class AuditLog extends BaseModel {
  static tableName = "audit_logs";
  static _db = "secondary";  // Uses the "secondary" named adapter
  static fields = {
    id:    { type: "integer" as const, primaryKey: true, autoIncrement: true },
    event: { type: "string" as const, required: true },
  };
}
```

Register the named adapter at startup with `initDatabase()`.
