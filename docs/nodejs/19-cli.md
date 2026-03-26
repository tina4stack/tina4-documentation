# Chapter 19: CLI & Scaffolding

## 1. Getting a New Developer Up to Speed

A new developer joins your team. You hand them the repo URL. By 10am they have a running project, a new database model, CRUD routes, a migration, and a deployment to staging. All from the command line.

The Tina4 CLI is a single Rust binary. It manages all four Tina4 frameworks: PHP, Python, Ruby, and Node.js. Same commands across all languages.

---

## 2. tina4 init -- Project Scaffolding

```bash
tina4 init my-project
```

```
Creating Tina4 project in ./my-project ...
  Detected language: Node.js (package.json)
  Created .env
  Created .env.example
  Created .gitignore
  Created src/routes/
  Created src/orm/
  Created src/migrations/
  Created src/seeds/
  Created src/templates/
  Created src/public/
  Created data/
  Created logs/
  Created secrets/
  Created tests/

Project created! Next steps:
  cd my-project
  npm install
  tina4 serve
```

### Language Detection

The CLI detects the language from the project directory:

| File Found | Language |
|------------|----------|
| `package.json` | Node.js |
| `composer.json` | PHP |
| `pyproject.toml` | Python |
| `Gemfile` | Ruby |

---

## 3. tina4 serve -- Dev Server

```bash
tina4 serve
```

```
  Tina4 Node.js v3.0.0
  Server running at http://0.0.0.0:7148
  Debug mode: ON
  Live reload: ON
```

Options:

```bash
tina4 serve --port 8080
tina4 serve --host 127.0.0.1
tina4 serve --no-reload
```

---

## 4. tina4 generate -- Code Generation

### Generate a Model

```bash
tina4 generate model Product
```

Creates `src/orm/Product.ts`:

```typescript
import { BaseModel } from "tina4-nodejs";

export class Product extends BaseModel {
    static tableName = "products";
    static primaryKey = "id";

    id!: number;
    createdAt!: string;
    updatedAt!: string;
}
```

### Generate a Route

```bash
tina4 generate route products
```

Creates `src/routes/products.ts` with GET, POST, PUT, DELETE stubs.

### Generate a Migration

```bash
tina4 generate migration create_products_table
```

Creates `src/migrations/20260322143000_create_products_table.sql`.

### Generate a Test

```bash
tina4 generate test ProductTest
```

Creates `tests/ProductTest.ts` with test stubs.

---

## 5. tina4 migrate -- Database Migrations

```bash
tina4 migrate              # Apply pending migrations
tina4 migrate:status       # Show migration status
tina4 migrate:rollback     # Roll back last migration
tina4 migrate:create NAME  # Create a new migration
```

---

## 6. tina4 routes -- Route Listing

```bash
tina4 routes
tina4 routes --method POST
tina4 routes --filter users
```

---

## 7. tina4 queue -- Queue Management

```bash
tina4 queue:work                        # Start processing jobs
tina4 queue:work --queue send-email     # Process specific queue
tina4 queue:dead                        # List dead letter jobs
tina4 queue:retry 42                    # Retry a dead job
tina4 queue:clear --older-than 7d       # Clear old dead jobs
```

---

## 8. tina4 test -- Running Tests

```bash
tina4 test                      # Run all tests
tina4 test --filter ProductTest # Run specific test class
```

Or use npm:

```bash
npm test
```

This runs `tests/run-all.ts` which discovers and executes all test classes.

---

## 9. tina4 doctor -- System Check

```bash
tina4 doctor
```

```
System Check
  Node.js: v20.11.1 [OK]
  npm: 10.2.4 [OK]
  tsx: 4.7.0 [OK]
  SQLite: 3.43.0 [OK]
  .env: found [OK]
  Database: connected [OK]
  AI tools detected:
    Claude Code: .claude/ [FOUND]
    Cursor: .cursor/ [NOT FOUND]
```

---

## 10. tina4 build -- Production Build

```bash
tina4 build
```

Compiles TypeScript to JavaScript. Bundles for production. Optimizes:

```
Building for production...
  Compiled 47 TypeScript files
  Output: dist/
  Size: 245KB

Ready for deployment:
  node dist/app.js
```

---

## 11. Custom CLI Commands

Create custom commands by adding files to `src/commands/`:

```typescript
// src/commands/seed-products.ts
import { Command, Database } from "tina4-nodejs";

export default class SeedProducts extends Command {
    static command = "seed:products";
    static description = "Seed the database with sample products";

    async run() {
        const db = Database.getConnection();

        const products = [
            { name: "Keyboard", price: 79.99 },
            { name: "Mouse", price: 29.99 },
            { name: "Monitor", price: 399.99 }
        ];

        for (const p of products) {
            await db.execute(
                "INSERT INTO products (name, price) VALUES (:name, :price)",
                p
            );
        }

        console.log(`Seeded ${products.length} products`);
    }
}
```

Run it:

```bash
tina4 seed:products
```

---

## 12. Exercise: Scaffold a Blog Project

Use the CLI to scaffold a complete blog project from scratch.

### Requirements

1. Initialize a new project called `my-blog`
2. Generate models: User, Post, Comment
3. Generate migrations for each model
4. Generate routes for posts and comments
5. Run migrations
6. Generate tests for the Post API
7. Run the test suite

---

## 13. Solution

```bash
tina4 init my-blog
cd my-blog
npm install

tina4 generate model User
tina4 generate model Post
tina4 generate model Comment

tina4 generate migration create_users_table
tina4 generate migration create_posts_table
tina4 generate migration create_comments_table

# Edit migrations to add columns, then:
tina4 migrate

tina4 generate route posts
tina4 generate route comments

tina4 generate test PostApiTest

npm test

tina4 serve
```

---

## 14. Gotchas

### 1. CLI Not Found -- Install with `brew install tina4stack/tap/tina4`.
### 2. Wrong Language Detected -- Ensure `package.json` exists.
### 3. Generate Overwrites Existing Files -- Check before generating.
### 4. Migration Already Applied -- Create new migrations for changes.
### 5. Custom Command Not Found -- Place in `src/commands/`.
### 6. Build Fails -- Check TypeScript errors with `npx tsc --noEmit`.
### 7. Port Conflict -- Use `tina4 serve --port 8080`.
