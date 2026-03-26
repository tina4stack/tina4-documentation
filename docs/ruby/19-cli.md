# Chapter 19: CLI & Scaffolding

## 1. Getting a New Developer Up to Speed

Monday morning. New developer joins the team. You hand them the repo URL. By 10am they have a running project, a new database model, CRUD routes, a migration, and a deployment to staging. All from the command line. No documentation hunts. No boilerplate from old projects. The CLI handles the scaffolding.

The Tina4 CLI is a single Rust binary. It manages all four Tina4 frameworks -- PHP, Python, Ruby, Node.js. Commands are identical across languages. Learn the CLI for Ruby, and you know it for PHP.

---

## 2. tina4 init -- Project Scaffolding

```bash
tina4 init my-project
```

### Language Detection

The CLI detects the language from the directory contents:

| File Found | Language Detected |
|------------|------------------|
| `Gemfile` | Ruby |
| `composer.json` | PHP |
| `requirements.txt` or `pyproject.toml` | Python |
| `package.json` | Node.js |

If no language-specific file exists, the CLI asks which language to use.

### Specifying Language Explicitly

```bash
tina4 init my-project --lang ruby
```

---

## 3. tina4 serve -- Dev Server

```bash
tina4 serve
```

```
  Tina4 Ruby v3.0.0
  Server running at http://0.0.0.0:7147
  Debug mode: ON
  Database: sqlite:///data/app.db
  Press Ctrl+C to stop
```

### Options

```bash
tina4 serve --port 8080        # Custom port
tina4 serve --host 0.0.0.0     # Listen on all interfaces
tina4 serve --no-reload        # Disable live reload
```

The dev server uses WEBrick by default. For production, use Puma:

```bash
bundle exec puma -C config/puma.rb
```

Or start with `bundle exec ruby app.rb` which starts the built-in server.

---

## 4. tina4 routes -- Route Listing

```bash
tina4 routes
```

```
Method   Path                          Middleware          Auth
------   ----                          ----------          ----
GET      /api/products                 -                   public
POST     /api/products                 -                   secured
GET      /api/products/{id:int}        -                   public
PUT      /api/products/{id:int}        -                   secured
DELETE   /api/products/{id:int}        -                   secured
GET      /api/users                    auth_middleware      public
```

### Filtering

```bash
tina4 routes --method POST
tina4 routes --filter products
tina4 routes --filter admin
```

---

## 5. tina4 migrate -- Database Migrations

```bash
# Create a new migration
tina4 migrate:create create_products_table

# Run pending migrations
tina4 migrate

# Check migration status
tina4 migrate:status

# Roll back the last migration
tina4 migrate:rollback

# Roll back all migrations
tina4 migrate:reset

# Roll back and re-run all migrations
tina4 migrate:fresh
```

---

## 6. tina4 generate -- Code Generation

### Generate a Model

```bash
tina4 generate:model Product
```

Creates `src/orm/product.rb`:

```ruby
class Product < Tina4::ORM
  integer_field :id, primary_key: true
  # Add your fields here

  table_name "products"
end
```

### Generate a Route

```bash
tina4 generate:route products
```

Creates `src/routes/products.rb` with CRUD route stubs:

```ruby
Tina4::Router.get("/api/products") do |request, response|
  # TODO: implement
  response.json({ products: [] })
end

Tina4::Router.get("/api/products/{id:int}") do |request, response|
  # TODO: implement
  response.json({ id: request.params["id"] })
end

Tina4::Router.post("/api/products") do |request, response|
  # TODO: implement
  response.json({ created: true }, 201)
end

Tina4::Router.put("/api/products/{id:int}") do |request, response|
  # TODO: implement
  response.json({ updated: true })
end

Tina4::Router.delete("/api/products/{id:int}") do |request, response|
  # TODO: implement
  response.json(nil, 204)
end
```

### Generate a Migration

```bash
tina4 generate:migration create_products_table
```

Creates `src/migrations/TIMESTAMP_create_products_table.sql`.

### Generate All Three at Once

```bash
tina4 generate:crud Product
```

Creates the model, migration, and route file for a complete CRUD resource.

---

## 7. tina4 test -- Running Tests

```bash
tina4 test                           # Run all tests
tina4 test tests/product_spec.rb     # Run a specific file
tina4 test --verbose                 # Verbose output
tina4 test --coverage                # Generate coverage report
```

---

## 8. tina4 queue -- Queue Management

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

## 9. tina4 build -- Build Commands

```bash
tina4 build:css                      # Compile SCSS to CSS
tina4 build:js                       # Bundle and minify JavaScript
tina4 build                          # Run all build steps
```

---

## 10. tina4 deploy -- Deployment

```bash
tina4 deploy:docker                  # Generate Dockerfile and docker-compose.yml
tina4 deploy:systemd                 # Generate systemd service file
tina4 deploy:nginx                   # Generate Nginx config
```

---

## 11. Environment-Specific Commands

```bash
tina4 serve --env production         # Use .env.production
tina4 migrate --env test             # Run migrations on test database
tina4 test --env test                # Run tests with test environment
```

---

## 12. Exercise: Scaffold a Complete Project

Using only the CLI, scaffold a project called `taskflow` with:

1. A `User` model and migration
2. A `Task` model and migration
3. CRUD routes for both
4. Run the migrations
5. Start the server

### Test with:

```bash
tina4 init taskflow --lang ruby
cd taskflow
tina4 generate:crud User
tina4 generate:crud Task
tina4 migrate
tina4 serve
```

Then verify the routes:

```bash
tina4 routes
```

---

## 13. Solution

```bash
tina4 init taskflow --lang ruby
cd taskflow
bundle install

# Generate User CRUD
tina4 generate:crud User

# Generate Task CRUD
tina4 generate:crud Task

# Edit the generated migrations to add fields...
# Edit the generated models to add fields...

# Run migrations
tina4 migrate

# Start the server
tina4 serve
```

After editing, verify:

```bash
tina4 routes
```

```
Method   Path                     Middleware   Auth
------   ----                     ----------   ----
GET      /api/users               -            public
POST     /api/users               -            secured
GET      /api/users/{id:int}      -            public
PUT      /api/users/{id:int}      -            secured
DELETE   /api/users/{id:int}      -            secured
GET      /api/tasks               -            public
POST     /api/tasks               -            secured
GET      /api/tasks/{id:int}      -            public
PUT      /api/tasks/{id:int}      -            secured
DELETE   /api/tasks/{id:int}      -            secured
```

---

## 14. Gotchas

### 1. CLI Not Found

**Problem:** `tina4: command not found`.

**Fix:** Install the CLI with `brew install tina4stack/tap/tina4` or the install script.

### 2. Wrong Language Detected

**Problem:** The CLI detects PHP when you wanted Ruby.

**Fix:** Use `--lang ruby` to force the language.

### 3. Migration Timestamp Collisions

**Problem:** Two migrations created in the same second have the same timestamp.

**Fix:** Wait a second between `migrate:create` calls, or rename the file manually.

### 4. generate:crud Overwrites Existing Files

**Problem:** Running `generate:crud Product` again overwrites your customized files.

**Fix:** The generator checks for existing files and skips them by default. If you force overwrite with `--force`, your changes will be lost. Use version control.

### 5. serve Uses Wrong Port

**Problem:** `tina4 serve` starts on port 7146 instead of 7147.

**Fix:** Ruby uses port 7147 by default. If it starts on a different port, check your `.env` file for `TINA4_PORT`.

### 6. build:css Fails

**Problem:** `tina4 build:css` fails with "sass not found".

**Fix:** Install the Sass compiler: `gem install sass` or `npm install -g sass`.

### 7. deploy:docker Generates PHP Dockerfile

**Problem:** The generated Dockerfile uses PHP instead of Ruby.

**Fix:** Make sure your project has a `Gemfile` so the CLI detects Ruby. Or use `tina4 deploy:docker --lang ruby`.
