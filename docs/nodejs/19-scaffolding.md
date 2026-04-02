# Scaffolding

One command. Six files. A working CRUD feature with routes, templates, tests, and Swagger docs -- ready to run.

That is Tina4's scaffolding system. It generates the boilerplate you write by hand in every project: models, migrations, routes, forms, views, and tests. You describe what you want. The generators produce it.

---

## The CRUD Generator

This is the generator most developers reach for first. It creates everything a feature needs in one shot.

```bash
tina4nodejs generate crud Product --fields "name:string,price:float"
```

That single command creates six files:

| # | File | Purpose |
|---|------|---------|
| 1 | `src/orm/Product.ts` | ORM model with typed fields |
| 2 | `migrations/20260401_create_product.sql` | UP migration (CREATE TABLE) |
| 3 | `migrations/20260401_create_product.down.sql` | DOWN migration (DROP TABLE) |
| 4 | `src/routes/products.ts` | CRUD routes with Swagger annotations |
| 5 | `src/templates/products/form.html` | Form template with typed inputs and `form_token` |
| 6 | `src/templates/products/view.html` | List and detail templates |
| 7 | `test/products.test.ts` | Test stubs for all CRUD operations |

### What Each File Contains

The **model** maps the `product` table to a TypeScript class:

```typescript
import { ORM } from "tina4-nodejs";

export class Product extends ORM {
  tableName = "product";

  id?: number;
  name?: string;
  price?: number;
  createdAt?: string;
  updatedAt?: string;
}
```

The **migration** creates the table:

```sql
-- migrations/20260401_create_product.sql
CREATE TABLE product (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(255),
    price FLOAT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

The **down migration** reverses it:

```sql
-- migrations/20260401_create_product.down.sql
DROP TABLE IF EXISTS product;
```

The **routes** file wires up five endpoints with Swagger docs:

```typescript
import { get, post, put, del } from "tina4-nodejs";
import { Product } from "../orm/Product";

get("/api/products", "List all products", async (request, response) => {
  const products = await new Product().select();
  return response(products);
});

get("/api/products/:id", "Get a product by ID", async (request, response) => {
  const product = new Product();
  product.id = request.params.id;
  await product.load();
  return response(product);
});

post("/api/products", "Create a product", async (request, response) => {
  const product = new Product(request.body);
  await product.save();
  return response(product, 201);
});

put("/api/products/:id", "Update a product", async (request, response) => {
  const product = new Product(request.body);
  product.id = request.params.id;
  await product.save();
  return response(product);
});

del("/api/products/:id", "Delete a product", async (request, response) => {
  const product = new Product();
  product.id = request.params.id;
  await product.delete();
  return response(null, 204);
});
```

The **form template** renders typed inputs with CSRF protection:

```html
<form method="POST" action="/api/products">
    <input type="hidden" name="form_token" value="{{ form_token }}">
    <label>Name</label>
    <input type="text" name="name" required>
    <label>Price</label>
    <input type="number" step="0.01" name="price" required>
    <button type="submit">Save</button>
</form>
```

The **test file** stubs out CRUD assertions using the built-in test runner:

```typescript
import { describe, it } from "node:test";
import assert from "node:assert";
import { App } from "tina4-nodejs";

const client = new App().testClient();

describe("Products API", () => {
  it("creates a product", async () => {
    const response = await client.post("/api/products", { name: "Widget", price: 9.99 });
    assert.strictEqual(response.statusCode, 201);
  });

  it("lists products", async () => {
    const response = await client.get("/api/products");
    assert.strictEqual(response.statusCode, 200);
  });

  it("gets a product", async () => {
    const response = await client.get("/api/products/1");
    assert.strictEqual(response.statusCode, 200);
  });

  it("updates a product", async () => {
    const response = await client.put("/api/products/1", { name: "Updated Widget" });
    assert.strictEqual(response.statusCode, 200);
  });

  it("deletes a product", async () => {
    const response = await client.delete("/api/products/1");
    assert.strictEqual(response.statusCode, 204);
  });
});
```

### Run It

After generating, run the migration and start the server:

```bash
tina4nodejs migrate
tina4nodejs serve
```

Open Swagger UI at `http://localhost:7148/swagger` and test every endpoint. The scaffolded code works out of the box.

---

## Individual Generators

The CRUD generator calls several smaller generators under the hood. You can call each one directly when you need a single piece.

### Model

```bash
tina4nodejs generate model Product --fields "name:string,price:float"
```

Creates three files: the ORM model (`src/orm/Product.ts`), the UP migration, and the DOWN migration. No routes, no templates, no tests.

### Route

```bash
tina4nodejs generate route products --model Product
```

Creates one file: `src/routes/products.ts` with CRUD endpoints and Swagger annotations. The model must exist first.

### Migration

```bash
tina4nodejs generate migration add_category_to_product
```

Creates two files: `migrations/20260401_add_category_to_product.sql` and `migrations/20260401_add_category_to_product.down.sql`. Both are empty stubs. You write the SQL.

### Middleware

```bash
tina4nodejs generate middleware AuthLog
```

Creates one file with before and after stubs:

```typescript
import { middleware } from "tina4-nodejs";

middleware("AuthLogBefore", "before", async (request) => {
  console.log(`Request: ${request.method} ${request.url}`);
  return request;
});

middleware("AuthLogAfter", "after", async (request, response) => {
  console.log(`Response: ${response.statusCode}`);
  return response;
});
```

### Test

```bash
tina4nodejs generate test products --model Product
```

Creates one file: `test/products.test.ts` with CRUD stubs using the built-in test runner.

### Form

```bash
tina4nodejs generate form Product --fields "name:string,price:float"
```

Creates one file: `src/templates/products/form.html` with typed inputs and `form_token`.

### View

```bash
tina4nodejs generate view Product --fields "name:string,price:float"
```

Creates two templates: a list view and a detail view in `src/templates/products/`.

### CRUD

```bash
tina4nodejs generate crud Product --fields "name:string,price:float"
```

Shorthand for running all generators at once: model, migration, route, form, view, and test.

### Auth

```bash
tina4nodejs generate auth
```

Generates the full authentication scaffold: User model, migrations, login/register/logout routes, templates, and tests.

---

## AutoCRUD

AutoCRUD automatically generates REST API endpoints from your ORM models:

- `GET /api/{table}` — List with pagination (`?limit=10&offset=0`)
- `GET /api/{table}/{id}` — Get single record
- `POST /api/{table}` — Create record
- `PUT /api/{table}/{id}` — Update record
- `DELETE /api/{table}/{id}` — Delete record

### Usage

```typescript
// AutoCRUD routes are auto-generated from discovered models
// Models in src/models/ get REST endpoints at /api/{tableName}
```

Place your ORM models in `src/models/` and the framework discovers and mounts all five standard endpoints automatically — no route files needed.

---

## The Auth Generator

Authentication needs more than one file. The auth generator creates seven:

```bash
tina4nodejs generate auth
```

| # | File | Purpose |
|---|------|---------|
| 1 | `src/orm/User.ts` | User model with hashed password field |
| 2 | `migrations/20260401_create_user.sql` | UP migration |
| 3 | `migrations/20260401_create_user.down.sql` | DOWN migration |
| 4 | `src/routes/auth.ts` | Login, register, logout routes |
| 5 | `src/templates/auth/login.html` | Login form |
| 6 | `src/templates/auth/register.html` | Registration form |
| 7 | `test/auth.test.ts` | Auth flow tests |

The generated routes handle password hashing, JWT token creation, and session management. The templates include CSRF tokens. The tests cover registration, login, invalid credentials, and logout.

Run the migration, start the server, and you have working auth:

```bash
tina4nodejs migrate
tina4nodejs serve
```

---

## Field Types

Generators accept these field types. Each type maps to a specific column type in migrations, input type in forms, and display format in views.

| Field Type | Migration Column | Form Input | View Display |
|------------|-----------------|------------|--------------|
| `string` | `VARCHAR(255)` | `<input type="text">` | Plain text |
| `int` | `INTEGER` | `<input type="number">` | Number |
| `float` | `FLOAT` | `<input type="number" step="0.01">` | Decimal |
| `bool` | `BOOLEAN` | `<input type="checkbox">` | Yes / No |
| `text` | `TEXT` | `<textarea>` | Paragraph |
| `datetime` | `DATETIME` | `<input type="datetime-local">` | Formatted date |
| `blob` | `BLOB` | `<input type="file">` | Download link |

### Table Naming Convention

Tina4 uses singular table names. The model name `Product` maps to the table `product`. The model name `OrderItem` maps to `order_item`. The generator handles the conversion.

---

## Combining Generators

Sometimes you want a model with routes but no form. Or a model with a migration but no test. The `--with` flags let you compose:

```bash
tina4nodejs generate model Product --fields "name:string,price:float" --with-route --with-migration
```

Available flags:

| Flag | Adds |
|------|------|
| `--with-route` | CRUD route file |
| `--with-migration` | Migration files (included by default with model) |
| `--with-test` | Test file |
| `--with-form` | Form template |
| `--with-view` | View templates |

The `generate crud` command is equivalent to using all `--with` flags at once.

---

## Exercise: Scaffold a Blog

Build a blog with three resources using generators.

**Step 1:** Generate the auth system.

```bash
tina4nodejs generate auth
```

**Step 2:** Scaffold the Post resource.

```bash
tina4nodejs generate crud Post --fields "title:string,body:text,published:bool"
```

**Step 3:** Scaffold the Category resource.

```bash
tina4nodejs generate crud Category --fields "name:string,description:text"
```

**Step 4:** Add a migration to link posts to categories.

```bash
tina4nodejs generate migration add_category_id_to_post
```

Edit the migration to add the foreign key:

```sql
ALTER TABLE post ADD COLUMN category_id INTEGER REFERENCES category(id);
```

**Step 5:** Run all migrations and start the server.

```bash
tina4nodejs migrate
tina4nodejs serve
```

You now have a working blog with authentication, posts, categories, and Swagger documentation. Total commands: five. Total hand-written SQL: one line.

---

## Gotchas

### Generators Do Not Overwrite

If a file exists, the generator skips it and prints a warning. This protects your edits. To regenerate, delete the file first.

### Run Migrate After Generate

The model generator creates migration files. Those files do nothing until you run `tina4nodejs migrate`. Generate and migrate are separate steps by design.

### File Naming Matters

The generator derives file names from the model name. `Product` becomes `Product.ts` for the model and `products.ts` for routes. Do not rename generated files unless you update all imports.

### Field Changes Need New Migrations

Changing `--fields` and re-running the generator does not update existing migrations. Create a new migration with `generate migration` and write the ALTER TABLE by hand.

### Singular Table Names

Tina4 uses singular table names: `product`, not `products`. The route paths use plural (`/api/products`), but the table stays singular. The generator handles this split.

### npx Alternative

If `tina4nodejs` is not in your PATH, use `npx`:

```bash
npx tina4nodejs generate crud Product --fields "name:string,price:float"
```

All generator commands work the same way through npx.
