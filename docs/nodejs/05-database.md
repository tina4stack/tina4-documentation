# Chapter 5: Database

## 1. From Arrays to Real Data

In Chapters 2 and 3, all your data lived in TypeScript arrays. Server restart. Data gone. That works for learning routing and responses. Real applications need persistent storage.

This chapter covers Tina4's database layer: raw queries, parameterised queries, transactions, schema inspection, helper methods, and migrations.

Tina4 speaks to five database engines: SQLite, PostgreSQL, MySQL, Microsoft SQL Server, and Firebird. The API is identical across all of them. One line in `.env` switches the engine.

---

## 2. Connecting to a Database

### The Default: SQLite

When you scaffold a project with `tina4 init`, Tina4 drops a SQLite database at `data/app.db`. The default `.env` includes:

```bash
TINA4_DEBUG=true
```

With no explicit `DATABASE_URL`, Tina4 defaults to `sqlite:///data/app.db`. That is why the health check at `/health` shows `"database": "connected"` with zero configuration.

SQLite support uses Node's built-in `node:sqlite` module (Node 22+). No native C++ addons are needed. No `node-gyp`. No platform-specific binaries. This is what makes Tina4 Node.js truly zero runtime dependencies -- even the database driver ships with Node itself.

### Connection Strings for Other Databases

Set `DATABASE_URL` in `.env` to use a different engine:

```bash
# SQLite (explicit)
DATABASE_URL=sqlite:///data/app.db

# PostgreSQL
DATABASE_URL=postgres://localhost:5432/myapp

# MySQL
DATABASE_URL=mysql://localhost:3306/myapp

# Microsoft SQL Server
DATABASE_URL=mssql://localhost:1433/myapp

# Firebird
DATABASE_URL=firebird://localhost:3050/path/to/database.fdb
```

The Firebird adapter requires the `node-firebird` package (`npm install node-firebird`). SQL dialect differences are handled automatically: `LIMIT`/`OFFSET` is translated to `ROWS X TO Y`, boolean values are converted to integers, and `ILIKE` is converted to `LOWER() LIKE LOWER()`.

### Separate Credentials

```bash
DATABASE_URL=postgres://localhost:5432/myapp
DATABASE_USERNAME=myuser
DATABASE_PASSWORD=secretpassword
```

### Connection Pooling

For applications that handle many concurrent requests, enable connection pooling by passing a pool size to `Database.create()`:

```typescript
const db = await Database.create("postgres://localhost/mydb", undefined, undefined, 5);
```

The fourth argument controls how many database connections are maintained:

- `0` (the default) -- a single connection is used for all queries
- `N` (where N > 0) -- N connections are created and rotated round-robin across queries

Pooled connections are thread-safe. Each query is dispatched to the next available connection in the pool. This eliminates contention when multiple route handlers query the database simultaneously.

### Verifying the Connection

```bash
curl http://localhost:7148/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 3,
  "version": "3.10.3",
  "framework": "tina4-nodejs"
}
```

---

## 3. Getting the Database Object

In your route handlers, access the database via the `Database` class:

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/test-db", async (req, res) => {
    const db = Database.getConnection();

    const result = await db.fetch("SELECT 1 + 1 AS answer");

    return res.json(result);
});
```

```bash
curl http://localhost:7148/api/test-db
```

```json
{"answer": 2}
```

`Database.getConnection()` returns the active database connection. Call `fetch()`, `execute()`, and `fetchOne()` on this object. All database methods are async. All return Promises.

---

## 4. Raw Queries

### fetch() -- Get Multiple Rows

```typescript
const db = Database.getConnection();

const products = await db.fetch("SELECT * FROM products WHERE price > 50");
```

Each row is a plain object with column names as keys:

```typescript
// products looks like:
[
    { id: 1, name: "Keyboard", price: 79.99 },
    { id: 4, name: "Standing Desk", price: 549.99 }
]
```

### DatabaseResult

`fetch()` returns a `DatabaseResult` object. It behaves like an array but carries extra metadata about the query.

#### Properties

```typescript
const result = await db.fetch("SELECT * FROM users WHERE active = ?", [1]);

result.records;      // [{ id: 1, name: "Alice" }, { id: 2, name: "Bob" }]
result.columns;      // ["id", "name", "email", "active"]
result.count;        // total number of matching rows
result.limit;        // query limit (if set)
result.offset;       // query offset (if set)
```

#### Iteration

A `DatabaseResult` is iterable. Use it directly in `for...of`:

```typescript
for (const user of result) {
    console.log(user.name);
}
```

#### Index Access

Access rows by index like a regular array:

```typescript
const firstUser = result[0];
```

#### Countable

The `length` property works on the result:

```typescript
console.log(result.length); // number of records in this result set
```

#### Conversion Methods

```typescript
result.toJson();      // JSON string of all records
result.toCsv();       // CSV string with column headers
result.toArray();     // plain array of objects
result.toPaginate();  // { records: [...], count: 42, limit: 10, offset: 0 }
```

`toPaginate()` is designed for building paginated API responses. It bundles the records with the total count, limit, and offset in a single object.

#### Schema Metadata with columnInfo()

`columnInfo()` returns detailed metadata about the columns in the result set. The data is lazy-loaded -- it only queries the database schema when you call the method for the first time:

```typescript
const info = await result.columnInfo();
// [
//     { name: "id", type: "INTEGER", size: null, decimals: null, nullable: false, primaryKey: true },
//     { name: "name", type: "TEXT", size: null, decimals: null, nullable: false, primaryKey: false },
//     { name: "email", type: "TEXT", size: 255, decimals: null, nullable: true, primaryKey: false },
//     ...
// ]
```

Each column entry contains:

| Field | Description |
|-------|-------------|
| `name` | Column name |
| `type` | Database type (e.g. `INTEGER`, `TEXT`, `REAL`) |
| `size` | Maximum size (or `null` if not applicable) |
| `decimals` | Decimal places (or `null`) |
| `nullable` | Whether the column allows `NULL` |
| `primaryKey` | Whether the column is part of the primary key |

This is useful for building dynamic forms, generating documentation, or validating data before insert.

### fetchOne() -- Get a Single Row

```typescript
const product = await db.fetchOne("SELECT * FROM products WHERE id = 1");
// Returns: { id: 1, name: "Keyboard", price: 79.99 }
```

If no row matches, `fetchOne()` returns `null`.

### execute() -- Run a Statement

For INSERT, UPDATE, DELETE, and DDL statements that do not return rows:

```typescript
await db.execute("INSERT INTO products (name, price) VALUES ('Widget', 9.99)");
await db.execute("UPDATE products SET price = 89.99 WHERE id = 1");
await db.execute("DELETE FROM products WHERE id = 5");
await db.execute("CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, message TEXT, created_at TEXT)");
```

### Full Example: A Simple Query Route

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/products", async (req, res) => {
    const db = Database.getConnection();

    const products = await db.fetch("SELECT * FROM products ORDER BY name");

    return res.json({
        products,
        count: products.length
    });
});
```

---

## 5. Parameterised Queries

Never concatenate user input into SQL strings. That door leads to SQL injection:

```typescript
// NEVER do this:
await db.fetch(`SELECT * FROM products WHERE name = '${userInput}'`);
```

Instead, use parameterised queries:

```typescript
const db = Database.getConnection();

// Named parameters
const product = await db.fetchOne(
    "SELECT * FROM products WHERE id = :id",
    { id: 42 }
);

// Positional parameters
const products = await db.fetch(
    "SELECT * FROM products WHERE price BETWEEN ? AND ? ORDER BY price",
    [10.00, 100.00]
);
```

### A Safe Search Endpoint

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/products/search", async (req, res) => {
    const db = Database.getConnection();

    const q = req.query.q ?? "";
    const maxPrice = parseFloat(req.query.max_price ?? "99999");

    if (!q) {
        return res.status(400).json({ error: "Query parameter 'q' is required" });
    }

    const products = await db.fetch(
        "SELECT * FROM products WHERE name LIKE :query AND price <= :maxPrice ORDER BY name",
        { query: `%${q}%`, maxPrice }
    );

    return res.json({
        query: q,
        max_price: maxPrice,
        results: products,
        count: products.length
    });
});
```

```bash
curl "http://localhost:7148/api/products/search?q=key&max_price=100"
```

```json
{
  "query": "key",
  "max_price": 100,
  "results": [
    {"id": 1, "name": "Wireless Keyboard", "price": 79.99, "in_stock": 1}
  ],
  "count": 1
}
```

---

## 6. Transactions

When you need multiple operations to succeed or fail together, use transactions:

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.post("/api/orders", async (req, res) => {
    const db = Database.getConnection();
    const body = req.body;

    try {
        await db.startTransaction();

        await db.execute(
            "INSERT INTO orders (customer_id, total, status) VALUES (:customerId, :total, 'pending')",
            { customerId: body.customer_id, total: body.total }
        );

        const order = await db.fetchOne("SELECT last_insert_rowid() AS id");
        const orderId = order.id;

        for (const item of body.items) {
            await db.execute(
                "INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (:orderId, :productId, :qty, :price)",
                {
                    orderId,
                    productId: item.product_id,
                    qty: item.quantity,
                    price: item.price
                }
            );

            await db.execute(
                "UPDATE products SET stock = stock - :qty WHERE id = :productId",
                { qty: item.quantity, productId: item.product_id }
            );
        }

        await db.commit();

        return res.status(201).json({ order_id: orderId, status: "created" });
    } catch (e) {
        await db.rollback();
        return res.status(500).json({ error: `Order failed: ${e.message}` });
    }
});
```

---

## 7. Schema Inspection

### getTables()

```typescript
const db = Database.getConnection();
const tables = await db.getTables();
// Returns: ["orders", "order_items", "products", "users"]
```

### getColumns()

```typescript
const columns = await db.getColumns("products");
// Returns: [
//     { name: "id", type: "INTEGER", nullable: false, primary: true },
//     { name: "name", type: "TEXT", nullable: false, primary: false },
//     ...
// ]
```

### tableExists()

```typescript
if (await db.tableExists("products")) {
    // Table exists, safe to query
}
```

### getDatabaseType()

Identify the connected database engine at runtime:

```typescript
const dbType = db.getDatabaseType();
// Returns: "sqlite", "postgresql", "mysql", or "mssql"
```

Useful when you need database-specific SQL syntax or want to display the engine in a status page.

### Schema Info Endpoint

Combine schema inspection methods to build an introspection API:

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/schema", async (req, res) => {
    const db = Database.getConnection();

    const tables = await db.getTables();
    const schema: Record<string, any> = {};

    for (const table of tables) {
        schema[table] = await db.getColumns(table);
    }

    return res.json({
        database_type: db.getDatabaseType(),
        tables: schema,
        table_count: tables.length,
    });
});
```

This endpoint returns the full database schema -- every table and every column with its type and constraints. Useful for debugging, admin dashboards, and auto-generating documentation.

---

## 8. FakeData Seeder

Tina4 includes a `FakeData` generator for populating tables with realistic test data:

```typescript
import { FakeData } from "tina4-nodejs";

const fake = new FakeData();

fake.name();       // "Alice Johnson"
fake.email();      // "alice.johnson@example.com"
fake.phone();      // "+1-555-0142"
fake.address();    // "742 Evergreen Terrace, Springfield"
fake.company();    // "Acme Corp"
fake.sentence();   // "The quick brown fox jumps over the lazy dog."
fake.paragraph();  // Multiple sentences of lorem text
fake.number(1, 100);   // Random integer between 1 and 100
fake.decimal(0, 1000); // Random decimal
fake.boolean();    // true or false
fake.date("2024-01-01", "2026-12-31"); // Random date in range
fake.uuid();       // "a1b2c3d4-e5f6-..."
```

### Seeding a Table

```typescript
import { Database } from "tina4-nodejs/orm";
import { FakeData } from "tina4-nodejs";

const db = Database.getConnection();
const fake = new FakeData();

for (let i = 0; i < 50; i++) {
    db.execute(
        "INSERT INTO users (name, email, company) VALUES (:name, :email, :company)",
        {
            name: fake.name(),
            email: fake.email(),
            company: fake.company(),
        }
    );
}

console.log("Seeded 50 users");
```

Run it as a script:

```bash
npx tsx scripts/seed-users.ts
```

FakeData generates consistent-looking data without external packages. Use it for development, demos, and test setup.

---

## 9. Batch Operations with executeMany()

Insert or update many rows efficiently:

```typescript
const db = Database.getConnection();

const products = [
    { name: "Widget A", price: 9.99 },
    { name: "Widget B", price: 14.99 },
    { name: "Widget C", price: 19.99 },
    { name: "Widget D", price: 24.99 }
];

await db.executeMany(
    "INSERT INTO products (name, price) VALUES (:name, :price)",
    products
);
```

---

## 10. Helper Methods: insert(), update(), delete()

### insert()

```typescript
const db = Database.getConnection();

await db.insert("products", {
    name: "Wireless Mouse",
    price: 34.99,
    in_stock: 1
});

// Insert multiple rows
await db.insert("products", [
    { name: "USB Cable", price: 9.99, in_stock: 1 },
    { name: "HDMI Cable", price: 14.99, in_stock: 1 }
]);
```

### update()

```typescript
await db.update("products", { price: 39.99, in_stock: 1 }, "id = :id", { id: 7 });
```

### delete()

```typescript
await db.delete("products", "id = :id", { id: 7 });
```

---

## 11. Migrations

Migrations are versioned SQL scripts. They evolve your database schema over time. Each migration runs once. Never again.

### File Naming

Tina4 supports two naming patterns for migration files:

- **Sequential:** `000001_create_products.sql`
- **Timestamp:** `YYYYMMDDHHMMSS_create_products.sql`

Both patterns sort correctly. Tina4 uses BigInt comparison internally, so you can mix them in the same project without issues.

### Generating a Migration

```bash
tina4 generate migration create_products_table
```

This creates two files in the `migrations/` folder:

```
migrations/20260324120000_create_products_table.sql
migrations/20260324120000_create_products_table.down.sql
```

The first file is the forward (up) migration. The second is the down migration used for rollbacks. Edit each one separately.

**Forward migration** (`20260324120000_create_products_table.sql`):

```sql
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Uncategorized',
    price REAL NOT NULL DEFAULT 0.00,
    in_stock INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**Down migration** (`20260324120000_create_products_table.down.sql`):

```sql
DROP TABLE IF EXISTS products;
```

Down migrations are optional. If you skip them, rollback will warn you but still remove the tracking record.

### Running Migrations

```bash
tina4 migrate
# or
tina4nodejs migrate
```

Each run increments a batch number. Every migration applied during that run belongs to the same batch. This matters for rollback.

### Checking Status

```bash
tina4nodejs migrate:status
```

This shows which migrations have been applied and which are still pending.

### Rolling Back

```bash
tina4nodejs migrate:rollback
```

Rollback undoes the entire last batch. It finds each migration in the batch, runs its `.down.sql` file, and removes the tracking record. If a `.down.sql` file is missing, rollback warns but still cleans up the tracking entry.

### The Tracking Table

Tina4 creates a `tina4_migration` table automatically. It has these columns:

| Column | Purpose |
|--------|---------|
| `id` | Auto-incrementing primary key |
| `description` | The migration filename |
| `content` | Full SQL text of the migration (for audit) |
| `passed` | Whether the migration ran successfully |
| `batch` | Which batch this migration belongs to |
| `run_at` | When the migration was applied |

### Advanced SQL Splitting

Migration files can contain multiple statements. Tina4 splits them on semicolons, but it is smart about edge cases:

- **`$$` delimited blocks** for PostgreSQL stored procedures and functions
- **`//` blocks** for procedure definitions
- **`/* */` block comments** are preserved
- **`--` line comments** are preserved

This means you can write PostgreSQL stored procedures in your migration files without Tina4 breaking on internal semicolons.

---

## 12. Query Caching

Enable query caching in `.env`:

```bash
TINA4_DB_CACHE=true
```

Identical queries with identical parameters return cached results. The cache invalidates itself when you call `execute()`, `insert()`, `update()`, or `delete()` on the same table.

```typescript
// Force a fresh query (bypass cache)
const products = await db.fetch("SELECT * FROM products", [], { noCache: true });

// Clear the entire cache
await db.clearCache();
```

---

## 13. Exercise: Build a Notes App

Build a notes application backed by SQLite. Create the database table via a migration and build a full CRUD API.

### Requirements

1. Create a migration for a `notes` table with: `id`, `title`, `content`, `tag`, `created_at`, `updated_at`

2. Build these API endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/notes` | List all notes. Support `?tag=` and `?search=` filters. |
| `GET` | `/api/notes/{id:int}` | Get a single note. 404 if not found. |
| `POST` | `/api/notes` | Create a note. Validate title and content are not empty. |
| `PUT` | `/api/notes/{id:int}` | Update a note. 404 if not found. |
| `DELETE` | `/api/notes/{id:int}` | Delete a note. 204 on success, 404 if not found. |

---

## 14. Solution

### Migration

Generate the migration files:

```bash
tina4 generate migration create_notes_table
```

Edit `migrations/20260324120000_create_notes_table.sql`:

```sql
CREATE TABLE notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tag TEXT NOT NULL DEFAULT 'general',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

Edit `migrations/20260324120000_create_notes_table.down.sql`:

```sql
DROP TABLE IF EXISTS notes;
```

```bash
tina4 migrate
```

### Routes

Create `src/routes/notes.ts`:

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/api/notes", async (req, res) => {
    const db = Database.getConnection();
    const tag = req.query.tag ?? "";
    const search = req.query.search ?? "";

    let sql = "SELECT * FROM notes";
    const params: Record<string, any> = {};
    const conditions: string[] = [];

    if (tag) {
        conditions.push("tag = :tag");
        params.tag = tag;
    }

    if (search) {
        conditions.push("(title LIKE :search OR content LIKE :search)");
        params.search = `%${search}%`;
    }

    if (conditions.length > 0) {
        sql += " WHERE " + conditions.join(" AND ");
    }

    sql += " ORDER BY updated_at DESC";

    const notes = await db.fetch(sql, params);

    return res.json({ notes, count: notes.length });
});

Router.get("/api/notes/{id:int}", async (req, res) => {
    const db = Database.getConnection();
    const id = req.params.id;

    const note = await db.fetchOne("SELECT * FROM notes WHERE id = :id", { id });

    if (note === null) {
        return res.status(404).json({ error: "Note not found", id });
    }

    return res.json(note);
});

Router.post("/api/notes", async (req, res) => {
    const db = Database.getConnection();
    const body = req.body;

    const errors: string[] = [];
    if (!body.title) errors.push("Title is required");
    if (!body.content) errors.push("Content is required");

    if (errors.length > 0) {
        return res.status(400).json({ errors });
    }

    await db.execute(
        "INSERT INTO notes (title, content, tag) VALUES (:title, :content, :tag)",
        {
            title: body.title,
            content: body.content,
            tag: body.tag ?? "general"
        }
    );

    const note = await db.fetchOne("SELECT * FROM notes WHERE id = last_insert_rowid()");

    return res.status(201).json(note);
});

Router.put("/api/notes/{id:int}", async (req, res) => {
    const db = Database.getConnection();
    const id = req.params.id;
    const body = req.body;

    const existing = await db.fetchOne("SELECT * FROM notes WHERE id = :id", { id });

    if (existing === null) {
        return res.status(404).json({ error: "Note not found", id });
    }

    await db.execute(
        "UPDATE notes SET title = :title, content = :content, tag = :tag, updated_at = CURRENT_TIMESTAMP WHERE id = :id",
        {
            title: body.title ?? existing.title,
            content: body.content ?? existing.content,
            tag: body.tag ?? existing.tag,
            id
        }
    );

    const note = await db.fetchOne("SELECT * FROM notes WHERE id = :id", { id });

    return res.json(note);
});

Router.delete("/api/notes/{id:int}", async (req, res) => {
    const db = Database.getConnection();
    const id = req.params.id;

    const existing = await db.fetchOne("SELECT * FROM notes WHERE id = :id", { id });

    if (existing === null) {
        return res.status(404).json({ error: "Note not found", id });
    }

    await db.execute("DELETE FROM notes WHERE id = :id", { id });

    return res.status(204).json(null);
});
```

**Expected output for create (Status: `201 Created`):**

```json
{
  "id": 1,
  "title": "Shopping List",
  "content": "Milk, eggs, bread",
  "tag": "personal",
  "created_at": "2026-03-22 14:30:00",
  "updated_at": "2026-03-22 14:30:00"
}
```

---

## 15. Gotchas

### 1. Forgetting await

**Problem:** Database operations return `Promise {<pending>}` instead of results.

**Cause:** You forgot to `await` the database call. All Tina4 database methods are async.

**Fix:** Always `await` database calls: `const result = await db.fetch(...)`.

### 2. Connection String Formats

**Problem:** The database will not connect.

**Cause:** Each database engine expects a specific URL format. A common mistake is omitting the port.

**Fix:** Always include the port. Default ports: PostgreSQL 5432, MySQL 3306, MSSQL 1433, Firebird 3050.

### 3. SQLite File Paths

**Problem:** SQLite creates a new empty database instead of using the existing one.

**Cause:** Use three slashes for a relative path: `sqlite:///data/app.db`. Four slashes for absolute: `sqlite:////var/data/app.db`.

### 4. Parameterised Queries with LIKE

**Problem:** `WHERE name LIKE '%:q%'` does not work.

**Cause:** Parameters inside quotes are literal text, not placeholders.

**Fix:** Include the `%` in the parameter value: `{ q: "%" + search + "%" }`. The SQL should be `WHERE name LIKE :q`.

### 5. Boolean Values in SQLite

**Problem:** SQLite stores booleans as integers (1 and 0).

**Fix:** Cast in your TypeScript code: `inStock: Boolean(row.in_stock)`.

### 6. Migration Already Applied

**Problem:** You edited a migration file and ran `tina4 migrate` again, but nothing changed.

**Cause:** Once applied, a migration will not run again.

**Fix:** Create a new migration for schema changes. Do not edit applied migrations. If you need to undo, run `tina4nodejs migrate:rollback` first, then fix the migration and re-run.

### 8. Down Migration Missing on Rollback

**Problem:** You ran `tina4nodejs migrate:rollback` but the table was not dropped.

**Cause:** The `.down.sql` file is missing. Rollback removes the tracking record but cannot undo the schema change without it.

**Fix:** Always generate migrations with `tina4 generate migration`, which creates both files. If you created the migration manually, add the `.down.sql` file before you need to roll back.

### 7. fetch() Returns Empty Array, Not Null

**Problem:** You check `if (result === null)` but it never matches when the table is empty.

**Cause:** `fetch()` always returns an array. Only `fetchOne()` returns `null`.

**Fix:** Check with `if (result.length === 0)`.
