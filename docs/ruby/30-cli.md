# Chapter 19: Tina4 CLI

## 1. Getting a New Developer Up to Speed

Monday morning. New developer joins the team. You hand them the repo URL. By 10am they have a running project, a new database model, CRUD routes, a migration, and a deployment to staging. All from the command line. No documentation hunts. No boilerplate from old projects. The CLI handles the scaffolding.

The Tina4 CLI is a single Rust binary. It manages all four Tina4 frameworks -- PHP, Python, Ruby, Node.js. Commands are identical across languages. Learn the CLI for Ruby, and you know it for PHP.

---

## 2. tina4 init -- Project Scaffolding

You saw this in Chapter 1. Now the details.

```bash
tina4 init my-project
```

```
Creating Tina4 project in ./my-project ...
  Detected language: Ruby (Gemfile)
  Created .env
  Created .env.example
  Created .gitignore
  Created src/routes/
  Created src/orm/
  Created src/migrations/
  Created src/seeds/
  Created src/templates/
  Created src/templates/errors/
  Created src/public/
  Created src/public/js/
  Created src/public/css/
  Created src/public/scss/
  Created src/public/images/
  Created src/public/icons/
  Created src/locales/
  Created data/
  Created logs/
  Created secrets/
  Created tests/

Project created! Next steps:
  cd my-project
  bundle install
  tina4 serve
```

### Language Detection

The CLI detects the language from existing files:

| File Present | Language |
|-------------|----------|
| `Gemfile` | Ruby |
| `composer.json` | PHP |
| `pyproject.toml` or `requirements.txt` | Python |
| `package.json` | Node.js |

If no language-specific file exists, the CLI asks:

```bash
tina4 init my-project
```

```
No language detected. Which language?
  1. PHP
  2. Python
  3. Ruby
  4. Node.js
> 3

Creating Tina4 Ruby project in ./my-project ...
```

### Explicit Language Selection

Skip the prompt by specifying the language:

```bash
tina4 init my-project --lang ruby
```

This creates a Ruby project with `Gemfile`, `app.rb`, and the full directory structure.

### Init into an Existing Directory

Already have a project? Add Tina4 structure:

```bash
cd existing-project
tina4 init .
```

The CLI creates only files and directories that do not exist. It never overwrites.

---

## 3. tina4 serve -- Dev Server

```bash
tina4 serve
```

```
  Tina4 Ruby v3.0.0
  HTTP server running at http://0.0.0.0:7147
  WebSocket server running at ws://0.0.0.0:7147
  Live reload enabled
  Press Ctrl+C to stop
```

`tina4 serve` detects the language and starts the appropriate server. For Ruby, it runs `bundle exec ruby app.rb` with live reload enabled.

### Options

```bash
tina4 serve --port 8080        # Custom port
tina4 serve --host 127.0.0.1   # Bind to localhost only
tina4 serve --production       # Production mode (no live reload, debug off)
```

### Direct Ruby Execution

You can start the server directly:

```bash
bundle exec ruby app.rb
```

This is identical to `tina4 serve` but gives you more control over the Ruby runtime. For production, use Puma:

```bash
bundle exec puma -C config/puma.rb
```

---

## 4. tina4 generate model -- ORM Scaffolding

The `generate model` command creates an ORM model file and a matching migration. One command produces both.

```bash
tina4 generate:model Product
```

```
Created src/orm/product.rb
Created src/migrations/20260322120000_create_products_table.sql
```

The generated model:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true
  created_at: true

  table_name "products"
end
```

The generated migration:

```sql
-- UP
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS products;
```

The model is ready to use. Add your fields and run migrations.

### Adding Fields

Specify fields on the command line:

```bash
tina4 generate:model Product --fields "name:string,price:float,category:string,in_stock:bool"
```

The generated model includes all the fields:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name
  float_field :price
  string_field :category
  boolean_field :in_stock

  table_name "products"
end
```

And the migration:

```sql
-- UP
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL DEFAULT '',
    price REAL NOT NULL DEFAULT 0,
    category TEXT NOT NULL DEFAULT '',
    in_stock INTEGER NOT NULL DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS products;
```

### Field Types

| CLI Type | Ruby Field | SQLite Column |
|----------|-----------|---------------|
| `string` | `string_field` | `TEXT` |
| `int` | `integer_field` | `INTEGER` |
| `float` | `float_field` | `REAL` |
| `bool` | `boolean_field` | `INTEGER` |
| `text` | `text_field` | `TEXT` |
| `date` | `string_field` | `TEXT` |

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--fields` | Comma-separated field definitions | `--fields "name:string,price:float"` |
| `--auto-crud` | Enable auto-CRUD on the model | `--auto-crud` |
| `--soft-delete` | Add soft delete support | `--soft-delete` |
| `--no-migration` | Skip migration generation | `--no-migration` |
| `--with-route` | Also generate a CRUD route file | `--with-route` |

---

## 5. tina4 generate route -- CRUD Route Scaffolding

The `generate route` command creates a complete CRUD route file with all five REST endpoints. It reads the model's properties and builds routes with proper type casting and nil checks.

```bash
tina4 generate:route products
```

```
Created src/routes/products.rb
```

The generated route file:

```ruby
Tina4::Router.get("/api/products") do |request, response|
  page = (request.params["page"] || 1).to_i
  per_page = (request.params["per_page"] || 20).to_i
  offset = (page - 1) * per_page

  products, total = Product.where("1=1", [], limit: per_page, offset: offset)
  results = products.map(&:to_hash)

  response.json({
    data: results,
    page: page,
    per_page: per_page,
    count: results.length
  })
end

Tina4::Router.get("/api/products/{product_id:int}") do |request, response|
  product = Product.find(request.params["product_id"])

  if product.nil?
    return response.json({ error: "Product not found" }, 404)
  end

  response.json(product.to_hash)
end

Tina4::Router.post("/api/products") do |request, response|
  body = request.body

  product = Product.new
  product.name = body["name"] || ""
  product.price = (body["price"] || 0).to_f
  product.category = body["category"] || ""
  product.in_stock = body["in_stock"] ? true : false
  product.save

  response.json(product.to_hash, 201)
end

Tina4::Router.put("/api/products/{product_id:int}") do |request, response|
  product = Product.find(request.params["product_id"])

  if product.nil?
    return response.json({ error: "Product not found" }, 404)
  end

  body = request.body
  product.name = body["name"] if body.key?("name")
  product.price = body["price"].to_f if body.key?("price")
  product.category = body["category"] if body.key?("category")
  product.in_stock = body["in_stock"] if body.key?("in_stock")
  product.save

  response.json(product.to_hash)
end

Tina4::Router.delete("/api/products/{product_id:int}") do |request, response|
  product = Product.find(request.params["product_id"])

  if product.nil?
    return response.json({ error: "Product not found" }, 404)
  end

  product.delete
  response.json(nil, 204)
end
```

The generator reads the model's properties and creates routes with type casting and nil checks. Customize the generated code. It is regular Ruby, not magic.

### Options

| Flag | Description | Example |
|------|-------------|---------|
| `--prefix` | Custom route prefix (default: `/api`) | `--prefix /api/v2` |
| `--middleware` | Add middleware to all routes | `--middleware auth_middleware` |

---

## 6. tina4 generate migration -- Migration Scaffolding

The `generate migration` command creates a timestamped migration file with `UP` and `DOWN` sections. The timestamp ensures migrations run in order.

```bash
tina4 generate:migration add_category_to_products
```

```
Created src/migrations/20260322120500_add_category_to_products.sql
```

The generated file:

```sql
-- UP
-- Add your forward migration SQL here


-- DOWN
-- Add your rollback migration SQL here

```

Fill in the SQL:

```sql
-- UP
ALTER TABLE products ADD COLUMN category TEXT DEFAULT '';

-- DOWN
ALTER TABLE products DROP COLUMN category;
```

The timestamp prefix (`20260322120500`) ensures migrations run in order. Each migration runs once. The framework tracks which ones have been applied.

---

## 7. tina4 generate middleware -- Middleware Scaffolding

The `generate middleware` command creates a middleware file with the correct signature.

```bash
tina4 generate:middleware rate_limit
```

```
Created src/middleware/rate_limit.rb
```

The generated file:

```ruby
# Rate limit middleware
Tina4.middleware do |request, response, next_handler|
  # Add your middleware logic here

  # Continue to the next middleware or route handler
  next_handler.call(request, response)

  # Or return early to block the request:
  # response.json({ error: "Rate limit exceeded" }, 429)
end
```

Reference the middleware in route definitions:

```ruby
Tina4::Router.get("/api/data", middleware: ["rate_limit"]) do |request, response|
  response.json({ data: "protected" })
end
```

---

## 8. Generate All at Once

Combine flags to generate multiple files in a single command:

```bash
tina4 generate:crud Product
```

```
Created src/orm/product.rb
Created src/routes/products.rb
Created src/migrations/20260322120000_create_products_table.sql
```

Model. CRUD routes. Migration. All wired together. Ready to use.

---

## 9. tina4 doctor -- Health Check

The `doctor` command checks your project for common issues:

```bash
tina4 doctor
```

```
Tina4 Doctor -- Checking your project...

  [OK] Ruby 3.3.0 detected
  [OK] Bundler found
  [OK] tina4 gem installed (v3.0.0)
  [OK] .env file exists
  [OK] Database connection: sqlite:///data/app.db
  [OK] Database is accessible
  [OK] src/routes/ directory exists (3 route files)
  [OK] src/orm/ directory exists (2 model files)
  [OK] src/templates/ directory exists (5 templates)
  [OK] src/public/ directory exists (static files served)
  [OK] tests/ directory exists (4 test files)
  [WARN] No migrations found in src/migrations/
  [OK] AI context: Claude Code detected, CLAUDE.md present
  [OK] .gitignore includes .env, data/, logs/

  12 checks passed, 1 warning, 0 errors
```

Doctor checks:

- Ruby version and package manager
- Tina4 gem installation and version
- `.env` file existence and critical variables
- Database connectivity
- Directory structure
- Missing files or configurations
- AI tool context files
- Git configuration

The warnings give actionable advice. If your database is not configured, it tells you exactly what to add to `.env`.

---

## 10. tina4 test -- Running Tests

```bash
tina4 test
```

```
Running tests...

  ProductSpec
    [PASS] creates a product
    [PASS] loads a product

  2 tests, 2 passed, 0 failed (0.12s)
```

This runs all tests in the `tests/` directory. See Chapter 17 for full testing documentation.

### Test Options

```bash
tina4 test tests/product_spec.rb             # Specific file
tina4 test --verbose                          # Verbose output
tina4 test --coverage                         # Generate coverage report
```

---

## 11. tina4 routes -- Route Listing

See all registered routes in your project:

```bash
tina4 routes
```

```
Registered Routes:

  Method  Path                          Handler              Middleware        Auth
  ------  --------------------------    -------------------  ----------------  --------
  GET     /health                       health_check         -                 public
  GET     /api/products                 list_products        ResponseCache     public
  GET     /api/products/{id:int}        get_product          -                 public
  POST    /api/products                 create_product       auth_middleware   secured
  PUT     /api/products/{id:int}        update_product       auth_middleware   secured
  DELETE  /api/products/{id:int}        delete_product       auth_middleware   secured
  GET     /admin                        admin_dashboard      -                 public

  7 routes registered
```

This is useful for verifying that your routes are registered and for finding the handler for a specific URL.

### Filtering

```bash
tina4 routes --method POST          # Filter by HTTP method
tina4 routes --filter products      # Filter by path pattern
tina4 routes --middleware auth      # Filter by middleware
```

When debugging routing issues, check here first. If a route does not match, `tina4 routes` shows whether it was registered and what middleware is attached.

---

## 12. tina4 migrate -- Database Migrations

Run pending migrations:

```bash
tina4 migrate
```

```
Running migrations...
  [UP] 20260322000100_create_users_table.sql
  [UP] 20260322000200_create_products_table.sql
  [UP] 20260322000300_add_category_to_products.sql

  3 migrations applied
```

### Rollback

```bash
tina4 migrate:rollback
```

```
Rolling back last migration...
  [DOWN] 20260322000300_add_category_to_products.sql

  1 migration rolled back
```

### Migration Table Auto-Upgrade

If your project was created with an earlier version of Tina4, the `tina4_migration` tracking table may use the older v2 schema. Running `tina4 migrate` detects the old layout and adds the missing `migration_id`, `batch`, and `executed_at` columns, backfilling existing data. No manual intervention needed.

### Status

```bash
tina4 migrate:status
```

```
Migration Status:

  Status    Migration
  --------  -----------------------------------------
  Applied   20260322000100_create_users_table.sql
  Applied   20260322000200_create_products_table.sql
  Applied   20260322000300_add_category_to_products.sql
  Pending   20260322000400_create_orders_table.sql

  3 applied, 1 pending
```

### Other Migration Commands

```bash
tina4 migrate:reset        # Roll back all migrations
tina4 migrate:fresh        # Roll back and re-run all migrations
```

---

## 13. tina4 queue -- Queue Management

```bash
tina4 queue:work                     # Start processing all queues
tina4 queue:work --queue emails      # Process specific queue
tina4 queue:dead                     # View dead letter queue
tina4 queue:retry 42                 # Retry a dead letter job
tina4 queue:retry --all              # Retry all dead letter jobs
tina4 queue:clear --older-than 7d    # Clear old dead letter jobs
tina4 queue:stats                    # Show queue statistics
```

---

## 14. tina4 build -- Build Commands

```bash
tina4 build:css                      # Compile SCSS to CSS
tina4 build:js                       # Bundle and minify JavaScript
tina4 build                          # Run all build steps
```

---

## 15. tina4 deploy -- Deployment

```bash
tina4 deploy:docker                  # Generate Dockerfile and docker-compose.yml
tina4 deploy:systemd                 # Generate systemd service file
tina4 deploy:nginx                   # Generate Nginx config
```

---

## 16. Environment-Specific Commands

```bash
tina4 serve --env production         # Use .env.production
tina4 migrate --env test             # Run migrations on test database
tina4 test --env test                # Run tests with test environment
```

---

## 17. Exercise: Scaffold a Feature in 5 Commands

Scaffold a complete "Customer" feature from scratch using only CLI commands.

### Requirements

Starting from an existing Tina4 Ruby project, run 5 commands to create:

1. A Customer ORM model with name, email, phone, and company fields
2. A CRUD route file with all five REST endpoints
3. A migration that creates the customers table
4. Run the migration to create the table
5. Run the doctor to verify everything

### Expected Commands

```bash
# 1. Generate the model with route and migration
tina4 generate:crud Customer

# 2. Edit the model to add fields (manual step)
# Add fields to src/orm/customer.rb

# 3. Edit the migration to add columns (manual step)
# Add columns to the migration file

# 4. Run the migration
tina4 migrate

# 5. Run the doctor to verify everything is set up
tina4 doctor
```

---

## 18. Solution

**Command 1:** Generate everything:

```bash
tina4 generate:crud Customer
```

**Command 2:** Edit `src/orm/customer.rb`:

```ruby
class Customer < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :name
  string_field :email
  string_field :phone
  string_field :company

  table_name "customers"
end
```

**Command 3:** Edit the migration file:

```sql
-- UP
CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    company TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_email ON customers(email);

-- DOWN
DROP TABLE IF EXISTS customers;
```

**Command 4:** Run the migration:

```bash
tina4 migrate
```

```
Running migrations...
  [UP] 20260322120000_create_customers_table.sql

  1 migration applied
```

**Command 5:** Verify with doctor:

```bash
tina4 doctor
```

```
  [OK] src/orm/ directory exists (3 model files)
  [OK] src/routes/ directory exists (4 route files)
  [OK] Database connection: sqlite:///data/app.db
  ...
```

Now test the API:

```bash
curl -X POST http://localhost:7147/api/customers \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Corp", "email": "alice@corp.com", "phone": "+1-555-0100", "company": "Alice Corp"}'
```

```json
{
  "id": 1,
  "name": "Alice Corp",
  "email": "alice@corp.com",
  "phone": "+1-555-0100",
  "company": "Alice Corp",
  "created_at": "2026-03-22 12:00:00"
}
```

From zero to a working CRUD API. Five commands. Under two minutes.

---

## 19. Gotchas

### 1. tina4 Command Not Found

**Problem:** Running `tina4` gives "command not found".

**Cause:** The Tina4 CLI is not installed or not in your PATH.

**Fix:** Install the CLI: `curl -fsSL https://tina4.com/install.sh | sh`. Verify with `tina4 --version`. If installed but not found, add the installation directory to your PATH:

```bash
echo 'export PATH="$HOME/.tina4/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### 2. Wrong Language Detected

**Problem:** `tina4 init` creates a PHP project instead of Ruby.

**Cause:** A `composer.json` file exists in the directory from a previous project.

**Fix:** Use explicit language selection: `tina4 init my-project --lang ruby`. Or delete the conflicting language file before running `init`.

### 3. Generated Files Overwrite Existing Code

**Problem:** Running `tina4 generate:route products` overwrites your custom route file.

**Cause:** The generate command creates files at fixed paths.

**Fix:** The CLI warns you before overwriting. Check if the file exists first. If you need to regenerate, rename the existing file: `mv src/routes/products.rb src/routes/products_backup.rb`.

### 4. Migration Order Issues

**Problem:** A migration fails because it references a table that does not exist yet.

**Cause:** Migration files run in alphabetical (timestamp) order. If migration B depends on a table created by migration A, but A has a later timestamp, B runs first and fails.

**Fix:** Use consistent timestamps. The `tina4 generate:migration` command uses the current timestamp. Generate migrations in order to ensure correct execution. If you need to fix ordering, rename the migration files to adjust their timestamps.

### 5. tina4 serve Uses Wrong Port

**Problem:** `tina4 serve` starts on port 7145 but you need port 8080.

**Cause:** The default port for Ruby is 7147 unless overridden.

**Fix:** Set it in `.env`: `TINA4_PORT=8080`. Or pass it as a flag: `tina4 serve --port 8080`. The `.env` value takes precedence over the default. The command-line flag overrides everything.

### 6. Doctor Shows False Warnings

**Problem:** `tina4 doctor` warns about missing migrations, but your project does not use migrations.

**Cause:** Doctor checks for common conventions. It warns about missing migrations regardless of your approach.

**Fix:** These are warnings, not errors. Ignore warnings that do not apply to your project. Doctor is a guide, not a gatekeeper.

### 7. Model Name Must Be PascalCase

**Problem:** `tina4 generate:model order_item` creates a model class named `order_item` which is not valid Ruby convention.

**Cause:** The CLI uses the argument as-is for the class name.

**Fix:** Use PascalCase for model names: `tina4 generate:model OrderItem`. The CLI converts it to snake_case for the table name (`order_items`).

### 8. build:css Fails

**Problem:** `tina4 build:css` fails with "sass not found".

**Cause:** The Sass compiler is not installed.

**Fix:** Install it: `gem install sass` or `npm install -g sass`.

### 9. deploy:docker Generates Wrong Dockerfile

**Problem:** The generated Dockerfile uses PHP instead of Ruby.

**Cause:** The CLI cannot detect the language without a `Gemfile`.

**Fix:** Make sure your project has a `Gemfile` so the CLI detects Ruby. Or use `tina4 deploy:docker --lang ruby`.

---

## 20. Documentation

```bash
tina4 docs      # Download framework-specific book chapters to .tina4-docs/
tina4 books     # Download the complete Tina4 book (all languages) to tina4-book/
```

`tina4 docs` detects your project language and downloads only the relevant chapters. The documentation is available in Markdown format, optimised for AI tools and local reference.

---

## 21. Test Port (Dual-Port Development)

When `TINA4_DEBUG=true`, Tina4 automatically starts a second HTTP server on `port + 1000`:

- **Main port** (e.g. 7147) — hot-reload enabled, for AI dev tools
- **Test port** (e.g. 8147) — stable, no hot-reload, for user testing

This prevents the browser from refreshing mid-test when AI tools edit files.

| Setting | Effect |
|---------|--------|
| `TINA4_NO_AI_PORT=true` | Disables the test port entirely |
| `TINA4_NO_RELOAD=true` | Disables hot-reload on the main port too |
| `--no-reload` | CLI flag equivalent of TINA4_NO_RELOAD |
