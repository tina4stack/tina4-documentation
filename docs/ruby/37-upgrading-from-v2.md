# Chapter 36: Upgrading from v2 to v3

## 1. Overview

v3 is a major rewrite. Not a point release with deprecation warnings. A ground-up rebuild with one rule: zero gem dependencies. Everything Tina4 needs -- HTTP server, template engine, ORM, migrations -- ships inside the gem itself. No transitive dependency chains. No version conflicts. No abandoned upstream libraries breaking your build.

Ruby convention wins everywhere. `snake_case` for methods, fields, file names. If you wrote v2 code that followed Ruby idioms, most of it transfers cleanly. If you fought against the conventions, now is the time to fix that.

This chapter walks through every breaking change, shows the v2 way and the v3 way side by side, and ends with a step-by-step checklist.

---

## 2. Package and Installation

### v2

```ruby
# Gemfile
gem "tina4-ruby", "~> 2.0"
```

### v3

```ruby
# Gemfile
gem "tina4-ruby", "~> 3.0"
```

Or install directly:

```bash
gem install tina4-ruby
```

v3 pulls in zero additional gems. The `bundle install` output is short:

```
Fetching tina4-ruby 3.0.0
Installing tina4-ruby 3.0.0
Bundle complete! 1 Gemfile dependency, 1 gem total.
```

One gem. That is it.

---

## 3. Project Structure Changes

### v2 Structure

```
my-app/
  routes/
  models/
  templates/
  migrations/
  app.rb
  .env
```

### v3 Structure

```
my-app/
  src/
    routes/
    orm/
    templates/
  migrations/
  app.rb
  .env
```

Three changes:

1. **Everything moves under `src/`** -- Routes, ORM models, and templates all live inside `src/`. This mirrors the other Tina4 language ports (Python, PHP, Node.js) for cross-language parity.
2. **`models/` becomes `src/orm/`** -- The directory name matches what it does. ORM classes. Not "models" in the MVC sense.
3. **`templates/` moves to `src/templates/`** -- Same Frond/Twig syntax. New location.

The migration is mechanical. Move files, update any hardcoded paths. Tina4 auto-loads everything in `src/` recursively.

```bash
mkdir -p src/routes src/orm src/templates
mv routes/* src/routes/
mv models/* src/orm/
mv templates/* src/templates/
```

---

## 4. Routing Changes

### Basic Syntax

The route registration API is the same:

```ruby
# v2 and v3 -- identical
Tina4::Router.get("/hello") do |request, response|
  response.json({ message: "Hello" })
end
```

No changes here. If your routes worked in v2, they work in v3.

### Auth Defaults

v2 required explicit auth setup on every protected route. v3 flips the default:

```ruby
# v2: no auth unless you add it
Tina4::Router.get("/admin") do |request, response|
  # wide open
end

# v3: auth is on by default for /api/* routes
# To explicitly disable auth on a route:
Tina4::Router.get("/public/data", auth: false) do |request, response|
  response.json({ open: true })
end
```

Routes under `/api/` are protected by default. Pass `auth: false` to opt out.

### Middleware

v3 introduces middleware chaining:

```ruby
Tina4::Router.get("/dashboard", middleware: [:check_session, :log_access]) do |request, response|
  response.json({ page: "dashboard" })
end
```

Define middleware in `src/routes/` or a dedicated file:

```ruby
Tina4::Middleware.define(:check_session) do |request, response|
  unless request.session[:user_id]
    response.json({ error: "Not authenticated" }, 401)
    next false  # halt the chain
  end
  true  # continue
end

Tina4::Middleware.define(:log_access) do |request, response|
  puts "[ACCESS] #{request.method} #{request.path} by user #{request.session[:user_id]}"
  true
end
```

---

## 5. Database Changes

### Connection Format

v2 used constructor-style connections. v3 uses URL format exclusively:

```ruby
# v2
Tina4::Database.new(:sqlite, "data/app.db")
Tina4::Database.new(:postgres, host: "localhost", port: 5432, database: "myapp")

# v3 -- URL format in .env
DATABASE_URL=sqlite:///data/app.db
DATABASE_URL=postgres://localhost:5432/myapp
DATABASE_URL=mysql://user:pass@localhost:3306/myapp
DATABASE_URL=firebird://localhost:3050/myapp
DATABASE_URL=mssql://localhost:1433/myapp
```

One format. All engines. Set it in `.env` and forget about it.

### Firebird Column Names

v2 returned Firebird column names in UPPERCASE (Firebird's default). v3 lowercases them automatically:

```ruby
# v2 Firebird result
{ "FIRST_NAME" => "Andre", "LAST_NAME" => "van Zuydam" }

# v3 Firebird result
{ "first_name" => "Andre", "last_name" => "van Zuydam" }
```

If your v2 code references uppercase Firebird columns, update those references. Search your codebase for any SCREAMING_CASE hash keys coming from Firebird queries.

---

## 6. ORM Changes

### The `auto_map` Flag

v3 adds an `auto_map` flag to ORM models:

```ruby
class Product < Tina4::ORM
  auto_map true

  integer_field :id, primary_key: true
  string_field :product_name
  float_field :unit_price

  table_name "products"
end
```

In Ruby, `auto_map` is a no-op. Ruby already uses `snake_case` natively, so there is nothing to convert. The flag exists for cross-language parity -- the same model definition works identically in Python, PHP, Node.js, and Ruby. If you are porting models between Tina4 languages, keep it set. In a Ruby-only project, you can ignore it.

### Field Mapping

When your database columns do not match Ruby conventions, use `field_mapping`:

```ruby
class LegacyUser < Tina4::ORM
  integer_field :id, primary_key: true
  string_field :first_name
  string_field :email_address

  table_name "tbl_users"

  field_mapping({
    first_name: "FirstName",      # maps snake_case to PascalCase column
    email_address: "EMAIL_ADDR"   # maps to legacy column name
  })
end
```

Your Ruby code uses `snake_case`. The ORM translates to whatever the database column is actually named. No more remembering which columns use which convention.

### Utility Methods

v3 exposes two utility methods for case conversion:

```ruby
Tina4.snake_to_camel("first_name")       # => "firstName"
Tina4.snake_to_camel("first_name", true) # => "FirstName" (PascalCase)
Tina4.camel_to_snake("firstName")        # => "first_name"
Tina4.camel_to_snake("FirstName")        # => "first_name"
```

Useful when building JSON APIs that need `camelCase` output from `snake_case` models, or when consuming external APIs that send `camelCase` data.

---

## 7. Template Engine Changes

### Singleton Pattern

v2 created a new template engine instance per render. v3 uses a singleton:

```ruby
# v2
engine = Tina4::Frond.new
result = engine.render("page.html", { title: "Home" })

# v3 -- singleton, accessed automatically
# In routes, just return a template render:
Tina4::Router.get("/") do |request, response|
  response.html("index.html", { title: "Home", user: current_user })
end
```

The template engine initialises once at startup, caches parsed templates, and reuses them. Faster. Less memory.

### Method Calls on Hash Values

v3 templates support calling methods on Hash values when those values are Procs or lambdas:

```ruby
# Route
Tina4::Router.get("/profile") do |request, response|
  user = {
    name: "Andre",
    t: ->(key) { I18n.translate(key) }  # translation lambda
  }
  response.html("profile.html", { user: user })
end
```

```html
<!-- src/templates/profile.html -->
<h1>{{ user.name }}</h1>
<p>{{ user.t("welcome_message") }}</p>
```

The template engine detects that `user.t` is callable and invokes it with `"welcome_message"` as the argument. This opens up translation helpers, formatting functions, and computed properties directly in templates.

---

## 8. Migration Tracking Table

v2 tracked migrations in a table called `tina4_migrations`. v3 uses the same table name but adds columns for checksum tracking and execution timestamps.

When you start a v3 application against a v2 database, Tina4 detects the old schema and upgrades the tracking table automatically:

```
[MIGRATE] Detected v2 migration tracking table
[MIGRATE] Adding checksum column to tina4_migrations
[MIGRATE] Adding executed_at column to tina4_migrations
[MIGRATE] Upgrade complete -- 12 existing migrations preserved
```

No manual intervention. Your existing migration history is preserved. New migrations run with the enhanced tracking.

If you need to verify the upgrade:

```ruby
result = Tina4.dba.fetch("SELECT * FROM tina4_migrations LIMIT 5")
puts result.to_json
```

Each row now includes `checksum` (SHA256 of the migration SQL) and `executed_at` (timestamp).

---

## 9. New Features in v3

Things that did not exist in v2:

- **Zero gem dependencies** -- The entire framework is self-contained. No Puma, no WEBrick dependency, no ERB.
- **Built-in HTTP server** -- Pure Ruby HTTP server, no external gem needed.
- **Middleware chaining** -- Stack multiple middleware blocks on any route.
- **WebSocket support** -- Native WebSocket handling without ActionCable or Faye.
- **Queue system** -- Background job processing with `Tina4::Queue`.
- **GraphQL endpoint** -- Built-in GraphQL support at `/graphql`.
- **CLI tool** -- `tina4 init`, `tina4 serve`, `tina4 migrate` commands.
- **Health check endpoint** -- `/health` returns server, database, and memory status out of the box.
- **Swagger generation** -- Auto-generated API docs from route annotations.
- **Cross-language parity** -- Same project structure, same ORM API, same template syntax across Python, PHP, Node.js, and Ruby.

---

## 10. Step-by-Step Migration Checklist

Follow this in order. Each step is independent -- commit after each one so you can roll back if something breaks.

### Step 1: Update the Gem

```ruby
# Gemfile
gem "tina4-ruby", "~> 3.0"
```

```bash
bundle update tina4-ruby
```

### Step 2: Restructure Directories

```bash
mkdir -p src/routes src/orm src/templates
mv routes/* src/routes/
mv models/* src/orm/
mv templates/* src/templates/
```

### Step 3: Update `.env`

Switch to URL-format database connection:

```bash
# Old
# DATABASE_TYPE=sqlite
# DATABASE_PATH=data/app.db

# New
DATABASE_URL=sqlite:///data/app.db
```

### Step 4: Update ORM Models

Rename the parent class if it changed, add `field_mapping` for any non-standard column names:

```ruby
# Check each file in src/orm/
class Product < Tina4::ORM
  # Add field_mapping if your DB columns don't match snake_case
  field_mapping({
    product_name: "ProductName"  # only if needed
  })
end
```

### Step 5: Fix Firebird Column References

If you use Firebird, search for uppercase column references:

```bash
grep -rn '[A-Z_]\{2,\}' src/ --include="*.rb"
```

Lowercase them. `row["FIRST_NAME"]` becomes `row["first_name"]`.

### Step 6: Update Template Paths

If any code references template paths directly, update them to `src/templates/`:

```ruby
# v2
response.html("templates/page.html", data)

# v3
response.html("page.html", data)  # resolves from src/templates/ automatically
```

### Step 7: Review Auth on Routes

Check routes under `/api/`. They are now protected by default. Add `auth: false` to any that should be public:

```ruby
Tina4::Router.get("/api/public-data", auth: false) do |request, response|
  response.json({ data: "open" })
end
```

### Step 8: Run Migrations

```bash
tina4 migrate
```

The migration tracking table upgrades automatically. Verify with the health check:

```bash
curl http://localhost:7147/health
```

### Step 9: Test

Run your test suite:

```bash
ruby -Itest test/**/*_test.rb
```

Or if you use the Tina4 test runner:

```bash
tina4 test
```

### Step 10: Clean Up

Remove old empty directories:

```bash
rmdir routes models templates 2>/dev/null
```

Remove any gem dependencies from your `Gemfile` that Tina4 v3 now handles internally (HTTP server gems, template engine gems).

```bash
bundle clean
```

---

That is the full migration. Most applications take under an hour. The biggest time sink is usually Firebird column name casing if you have a large codebase with hardcoded uppercase keys. Everything else is search-and-replace.
