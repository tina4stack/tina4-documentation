# Chapter 36: Upgrading from v2 to v3

## 1. Overview

Tina4 v3 is a ground-up rewrite. The API surface is similar. The internals are completely different.

The three biggest changes:

- **Zero npm dependencies.** v3 uses only Node built-in modules. `node:sqlite` replaces `better-sqlite3`. `node:test` replaces Jest. No `node-gyp`. No native binaries. `npm install` finishes in seconds.
- **TypeScript-first.** All source files are `.ts`. The framework compiles and runs them directly. No separate build step.
- **Naming conventions.** Properties use `camelCase`. Classes use `PascalCase`. The ORM converts between `camelCase` TypeScript properties and `snake_case` database columns automatically.

If your v2 project is small, a fresh `tina4 init` and copying your logic across is faster than an in-place upgrade. If your project is large, this chapter walks through every change systematically.

---

## 2. Package and Installation

### v2

```bash
npm install tina4-nodejs
# Required Node 18+
```

### v3

```bash
npm install tina4-nodejs
# Requires Node 22+
```

Node 22 is required because v3 uses `node:sqlite`, which shipped as a built-in module starting in Node 22. Check your version:

```bash
node --version
# Must be v22.0.0 or higher
```

If you are on an older Node, upgrade first. Everything else depends on it.

---

## 3. Project Structure Changes

### v2 Structure

```
src/
├── app.ts
├── routes/
│   └── *.ts
├── models/
│   └── *.ts
└── views/
    └── *.html
```

### v3 Structure

```
src/
├── routes/
│   └── *.ts
├── orm/
│   └── *.ts
└── templates/
    └── *.html
```

Key differences:

- `models/` is now `orm/`. The directory name reflects what it does.
- `views/` is now `templates/`. Frond loads from `src/templates/`.
- No `app.ts` entry point. v3 auto-discovers all `.ts` files in `src/routes/` and `src/orm/` recursively. Drop a file in. It loads.
- Migrations stay in `migrations/` at the project root. No change there.

### What to Do

1. Rename `src/models/` to `src/orm/`
2. Rename `src/views/` to `src/templates/`
3. Move your route files into `src/routes/` if they are not already there
4. Delete `app.ts` -- v3 does not need it

---

## 4. Routing Changes

### v2 Routing

```typescript
// v2
import { Tina4 } from "tina4-nodejs";

Tina4.get("/hello", (req, res) => {
    res.json({ message: "Hello" });
});
```

### v3 Routing

```typescript
// v3
import { Router } from "tina4-nodejs";

Router.get("/hello", async (req, res) => {
    return res.json({ message: "Hello" });
});
```

What changed:

- `Tina4.get()` becomes `Router.get()`. Same for `post()`, `put()`, `patch()`, `delete()`.
- Handlers must be `async` and must `return` the response. Forgetting `return` produces empty responses.
- Auth defaults: `POST`, `PUT`, `PATCH`, and `DELETE` routes are secured by default. `GET` routes are public. Use `@noauth` in a JSDoc comment to make a write route public. Use `@secured` or `.secure()` to protect a GET route.
- Middleware is referenced by function name as a string, not passed inline.

### v2 Middleware

```typescript
// v2
Tina4.get("/admin", checkAuth, (req, res) => {
    res.json({ page: "admin" });
});
```

### v3 Middleware

```typescript
// v3
Router.get("/admin", async (req, res) => {
    return res.json({ page: "admin" });
}, "checkAuth");
```

The middleware function itself is defined as a named function in any auto-loaded file. Tina4 resolves it by name at runtime.

---

## 5. Database Changes

### Connection Strings

v3 uses the same `DATABASE_URL` environment variable, but the format is standardised:

```bash
# SQLite (default if DATABASE_URL is not set)
DATABASE_URL=sqlite:///data/app.db

# PostgreSQL
DATABASE_URL=postgres://localhost:5432/myapp

# MySQL
DATABASE_URL=mysql://localhost:3306/myapp

# Firebird
DATABASE_URL=firebird://localhost:3050/path/to/database.fdb
```

### SQLite: node:sqlite

v2 used `better-sqlite3` (a native C++ addon). v3 uses `node:sqlite`, which is built into Node 22. No compilation. No platform-specific binaries. If Node runs, the database works.

### Database API

```typescript
// v2
const db = Tina4.getDatabase();
const rows = db.query("SELECT * FROM products");

// v3
import { Database } from "tina4-nodejs/orm";
const db = Database.getConnection();
const rows = await db.fetch("SELECT * FROM products");
```

All v3 database methods are async. `fetch()` returns a `DatabaseResult` object that is iterable and carries metadata (`.records`, `.columns`, `.count`).

### Firebird: Lowercase Column Names

Firebird stores column names in uppercase by default. v3 normalises them to lowercase in query results. If your v2 code accesses `row.FIRST_NAME`, change it to `row.first_name`.

---

## 6. ORM Changes

### Class Definition

```typescript
// v2
import { BaseModel } from "tina4-nodejs/orm";

export class Product extends BaseModel {
    tableName = "products";
    primaryKey = "id";

    id: number;
    name: string;
    price: number;
}

// v3
import { BaseModel } from "tina4-nodejs/orm";

export class Product extends BaseModel {
    static tableName = "products";
    static primaryKey = "id";

    id!: number;
    name!: string;
    price: number = 0.00;
    inStock: boolean = true;
    createdAt!: string;
}
```

Changes:

- `tableName` and `primaryKey` are now `static` properties.
- Properties use `camelCase`. The ORM maps them to `snake_case` columns automatically: `inStock` maps to `in_stock`, `createdAt` maps to `created_at`.
- Use `!:` for required fields and `= value` for defaults.

### Auto-Mapping with `autoMap`

v3 introduces `static autoMap = true`. When enabled, the ORM auto-generates `fieldMapping` entries from your camelCase property names to snake_case database column names. You do not need to write them by hand.

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Customer extends BaseModel {
    static tableName = "customers";
    static primaryKey = "id";
    static autoMap = true;

    id!: number;
    firstName!: string;    // auto-maps to "first_name"
    lastName!: string;     // auto-maps to "last_name"
    emailAddress!: string; // auto-maps to "email_address"
    createdAt!: string;    // auto-maps to "created_at"
}
```

No `fieldMapping` needed. The ORM inspects the property names, converts them with `camelToSnake()`, and builds the mapping at runtime.

### Explicit fieldMapping Takes Precedence

If a column does not follow the snake_case convention (legacy databases, third-party schemas), add an explicit `fieldMapping` entry. It overrides the auto-generated mapping for that field:

```typescript
export class User extends BaseModel {
    static tableName = "user_accounts";
    static primaryKey = "id";
    static autoMap = true;
    static fieldMapping = {
        firstName: "fname",     // overrides auto-map ("first_name" → "fname")
        lastName: "lname",      // overrides auto-map ("last_name" → "lname")
    };

    id!: number;
    firstName!: string;    // maps to "fname" (explicit)
    lastName!: string;     // maps to "lname" (explicit)
    emailAddress!: string; // maps to "email_address" (auto-mapped)
}
```

Explicit entries win. Auto-mapped entries fill in the rest.

### Utility Functions

v3 exports `snakeToCamel()` and `camelToSnake()` for use in your own code:

```typescript
import { snakeToCamel, camelToSnake } from "tina4-nodejs/orm";

snakeToCamel("first_name");   // "firstName"
snakeToCamel("created_at");   // "createdAt"

camelToSnake("firstName");    // "first_name"
camelToSnake("createdAt");    // "created_at"
```

### Output Methods

- `toDict()` returns `snake_case` keys (matching database columns). Use for API responses.
- `toObject()` returns `camelCase` keys (matching TypeScript properties). Use internally.

---

## 7. Template Engine Changes

Templates still use Frond with the same Twig-compatible syntax. Two things changed.

### Cached Instances

v3 caches compiled Frond template instances. The first render compiles the template. Subsequent renders reuse the compiled version. No code change needed on your side -- it happens automatically. Expect faster response times on template-heavy pages.

### Method Calls on Object Values

v3 adds the ability to call methods on object values inside templates, with arguments:

```html
<!-- v2: not possible -->

<!-- v3: call methods with arguments -->
<p>{{ user.t("greeting_key") }}</p>
<p>{{ product.formatPrice("USD") }}</p>
<p>{{ order.statusLabel() }}</p>
```

The object passed to the template must have the method defined. Frond calls it and outputs the return value. Arguments are passed as literals (strings, numbers, booleans).

---

## 8. Migration Tracking Table

v2 used a migration tracking table (sometimes named `tina4_migrations` or a similar variant). v3 uses a table named `tina4_migration` with a specific schema:

| Column | Purpose |
|--------|---------|
| `id` | Auto-incrementing primary key |
| `description` | Migration filename |
| `content` | Full SQL text (for audit) |
| `passed` | Whether it ran successfully |
| `batch` | Batch number for rollback grouping |
| `run_at` | Timestamp |

When v3 starts and detects a v2 tracking table, it auto-upgrades the table structure. Your existing migration history is preserved. Already-applied migrations will not run again.

No manual intervention required. Run `tina4 migrate` and v3 handles the rest.

---

## 9. New Features in v3

Things you get by upgrading that did not exist in v2:

- **File-based routing.** The file path becomes the URL. `src/routes/api/products/get.ts` handles `GET /api/products`.
- **Typed path parameters.** `{id:int}`, `{price:float}`, `{slug:alpha}`, `{filepath:path}`.
- **Route chaining.** `.secure()` and `.cache()` on any route.
- **Auto-CRUD.** `static autoCrud = true` on a model generates full REST endpoints.
- **Soft delete.** `static softDelete = true` with `deletedAt` field.
- **Eager loading.** Pass relationship names to `select()` to avoid N+1 queries.
- **Connection pooling.** Pass a pool size to `Database.create()`.
- **DatabaseResult.** Iterable results with `.toPaginate()`, `.toCsv()`, `.toJson()`, `.columnInfo()`.
- **Query builder.** Fluent API for building queries without raw SQL.
- **Batch rollback.** `migrate:rollback` undoes an entire batch, not just one migration.
- **GraphQL support.** Built-in GraphQL endpoint generation from ORM models.
- **WebSocket support.** Native WebSocket server and client.
- **Queue system.** Background job processing.

---

## 10. Step-by-Step Migration Checklist

Follow this order. Each step builds on the previous one.

### 1. Upgrade Node

```bash
node --version
# If below v22, upgrade
nvm install 22
nvm use 22
```

### 2. Update package.json

```bash
npm install tina4-nodejs@latest
```

Remove any Tina4-related dependencies that are no longer needed (`better-sqlite3`, `pg`, etc. -- v3 bundles its own drivers or uses Node built-ins).

### 3. Rename Directories

```bash
mv src/models src/orm
mv src/views src/templates
```

### 4. Update Imports

Find and replace across your codebase:

| v2 | v3 |
|----|-----|
| `import { Tina4 } from "tina4-nodejs"` | `import { Router } from "tina4-nodejs"` and `import { Database } from "tina4-nodejs/orm"` |
| `Tina4.get(...)` | `Router.get(...)` |
| `Tina4.post(...)` | `Router.post(...)` |
| `Tina4.getDatabase()` | `Database.getConnection()` |
| `db.query(...)` | `await db.fetch(...)` |

### 5. Make Route Handlers Async and Return Responses

```typescript
// Before
Router.get("/hello", (req, res) => {
    res.json({ message: "Hello" });
});

// After
Router.get("/hello", async (req, res) => {
    return res.json({ message: "Hello" });
});
```

### 6. Update ORM Models

- Make `tableName` and `primaryKey` static
- Rename properties to camelCase
- Add `static autoMap = true` if you want automatic field mapping
- Add explicit `fieldMapping` only for columns that do not follow snake_case

### 7. Update Database Calls

- Add `await` to all database operations
- Replace `db.query()` with `db.fetch()`, `db.fetchOne()`, or `db.execute()`
- Update Firebird column references from uppercase to lowercase

### 8. Update Template References

- Move templates from `src/views/` to `src/templates/`
- Update any `res.html()` calls if the path changed
- Template syntax (Frond/Twig) is unchanged -- no edits needed there

### 9. Run Migrations

```bash
tina4 migrate
```

v3 auto-upgrades the tracking table. Existing migrations are preserved.

### 10. Test

```bash
tina4 serve
```

Hit every endpoint. Check every page. The framework runs `node:test` for unit tests:

```bash
tina4 test
```

### 11. Remove Dead Code

- Delete `app.ts` if it exists
- Remove any manual server startup code -- v3 handles it
- Remove `node_modules` and reinstall cleanly:

```bash
rm -rf node_modules package-lock.json
npm install
```

---

## Gotchas

### 1. Node Version Too Low

**Problem:** `Error: Cannot find module 'node:sqlite'`

**Cause:** You are running Node 20 or earlier.

**Fix:** Upgrade to Node 22+.

### 2. Missing Return in Route Handlers

**Problem:** Routes return empty responses or 500 errors.

**Cause:** v3 requires `return res.json(...)`. v2 was more forgiving.

**Fix:** Add `return` before every `res.json()`, `res.html()`, and `res.status()` call.

### 3. Sync Database Calls

**Problem:** Database queries return `Promise {<pending>}`.

**Cause:** v3 database methods are all async. v2 had some sync methods.

**Fix:** Add `await` to every `db.fetch()`, `db.execute()`, `db.fetchOne()`, and ORM method.

### 4. Uppercase Firebird Columns

**Problem:** `row.FIRST_NAME` is `undefined`.

**Cause:** v3 normalises Firebird column names to lowercase.

**Fix:** Change to `row.first_name`.

### 5. Middleware Passed as Function Reference

**Problem:** Inline middleware functions cause errors.

**Cause:** v3 resolves middleware by function name (string), not by reference.

**Fix:** Define middleware as a named function and pass the name: `"checkAuth"`, not `checkAuth`.
