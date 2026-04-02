# Chapter 22: Vibe Coding with AI

## Why Tina4 is Built for AI-Assisted Development

Tell your AI assistant: "Add a product catalog with search, pagination, and category filtering." In most frameworks, the AI needs to know which packages to install, which config files to create, which naming conventions to follow, how to wire everything together. It hallucinated half of it.

With Tina4, the AI reads one file -- `CLAUDE.md` -- and knows everything. Every method signature. Every import path. Every convention. It generates correct, runnable code on the first attempt because there is one way to do things in Tina4.

This is not accidental. Tina4 was designed from the ground up for AI-assisted development. Here is why.

---

## The Zero-Dependency Advantage

When an AI writes Rails code, it might suggest `ActiveRecord::Base` or `ApplicationRecord`. Both exist. Both behave differently. It might suggest `render json:` or `respond_to do |format|`. The AI guesses.

Tina4 gives it nothing to guess about. One ORM. One queue. One template engine. One cache. No ambiguity. No alternatives. No "it depends on which gem you installed." The AI knows.

```ruby
# There is only one way to cache in Tina4
cached = Tina4.cache_get("products") || Tina4.cache_set("products", db.fetch("SELECT * FROM products"), 300)

# There is only one way to queue in Tina4
Tina4::Queue.produce("emails", { to: "user@test.com", subject: "Welcome" })

# There is only one way to send email in Tina4
mail = Tina4::Messenger.new
mail.to = "user@test.com"
mail.subject = "Welcome"
mail.send
```

Zero dependencies means zero confusion for AI.

---

## CLAUDE.md -- The AI's Instruction Manual

Every Tina4 project includes a `CLAUDE.md` file that tells AI assistants exactly how the framework works. It contains:

- Every method signature with parameters and return types
- The project structure convention (`src/routes/`, `src/orm/`, `src/templates/`)
- The `.env` variable reference
- Code style rules (routes use `response.json`, ORM uses `to_h`)
- Database connection string formats
- Common gotchas and how to avoid them

When you open a Tina4 project in Claude Code, Cursor, or GitHub Copilot -- the AI reads this file first and immediately understands how to write correct Tina4 code.

---

## Skills -- Deep Framework Knowledge

Beyond CLAUDE.md, Tina4 ships with three AI skill files:

### tina4-maintainer
For framework maintenance -- porting features between languages, reviewing PRs, running benchmarks, checking parity.

### tina4-developer
For application development -- creating routes, defining models, writing templates, setting up auth, configuring queues.

### tina4-js
For frontend development -- tina4-js signals, Tina4Element components, reactive templates, WebSocket client.

---

## The Convention Advantage

AI thrives on convention. When every Tina4 project follows the same structure, the AI never has to ask "where should I put this?"

```
src/
  routes/hello.rb     -> AI knows: this is a route file
  orm/product.rb      -> AI knows: this is an ORM model
  templates/page.html -> AI knows: this is a Frond template
  migrations/         -> AI knows: SQL migration files go here
```

The AI generates code that drops into the right directory with the right naming convention, every time.

---

## Prompt Engineering for Tina4

Here are effective prompts for AI-assisted Tina4 Ruby development:

### Creating a New Feature

```
Add a product catalog to my Tina4 Ruby project:
1. Create a Product model with fields: name, category, price, in_stock
2. Create a migration for the products table
3. Create CRUD routes at /api/products
4. Create a product listing template with category filters
5. Add response caching for the product list (5 minutes)
```

The AI generates all five files with correct Tina4 syntax because it read CLAUDE.md.

### Adding Authentication

```
Add JWT authentication to my Tina4 Ruby project:
1. Create a users table migration with name, email, password_hash, role
2. Create register and login routes at /api/auth/register and /api/auth/login
3. Create auth middleware that validates Bearer tokens
4. Protect the /api/tasks group with auth middleware
5. Use Tina4::Auth.get_token and Tina4::Auth.valid_token
```

### Building a Dashboard

```
Create an admin dashboard for my Tina4 Ruby project:
1. Create a GET /admin route that renders a dashboard template
2. The dashboard shows: total users, total products, recent orders
3. Use tina4css for styling (cards, tables, grid)
4. Use frond.js for AJAX data loading
5. Cache the dashboard stats for 60 seconds
```

### Adding WebSocket

```
Add a real-time notification system to my Tina4 Ruby project:
1. Create a WebSocket endpoint at /ws/notifications/{user_id}
2. When a task is assigned, push a notification via WebSocket
3. Include a JavaScript snippet that connects and shows browser notifications
4. Auto-reconnect on disconnect
```

---

## The Ruby Advantage for AI

Ruby's expressiveness makes AI-generated code particularly clean:

### Block Syntax

```ruby
Tina4::Router.get("/api/products") do |request, response|
  products = Tina4.cache_get("products:all")
  if products.nil?
    db = Tina4.database
    products = db.fetch("SELECT * FROM products ORDER BY name")
    Tina4.cache_set("products:all", products, 300)
  end

  response.json({ products: products, count: products.length })
end
```

The block syntax is unambiguous. The AI knows exactly where the route handler starts and ends. No curly brace confusion, no indentation ambiguity.

### Hash Syntax

```ruby
response.json({
  user: { id: user.id, name: user.name, email: user.email },
  tasks: tasks.map(&:to_h),
  stats: { total: total, completed: completed }
})
```

Ruby's symbol-key hash syntax (`name:` instead of `"name" =>`) is concise and consistent. The AI generates clean, idiomatic Ruby.

### Enumerable Methods

```ruby
# Filter products
electronics = products.select { |p| p[:category] == "Electronics" }

# Transform data
names = products.map { |p| p[:name] }

# Aggregate
total = items.sum { |item| item[:price] * item[:quantity] }

# Count with condition
featured_count = products.count { |p| p[:featured] }
```

These are the Ruby idioms the AI knows and uses. No external libraries, no complex method chains -- just Ruby.

---

## Vibe Coding Workflow

The "vibe coding" workflow with AI and Tina4 looks like this:

### 1. Describe What You Want

Tell the AI what you need in plain English. Be specific about the data model, the endpoints, and the behavior.

### 2. Review the Generated Code

The AI generates the routes, models, migrations, and templates. Review them for correctness and completeness.

### 3. Run and Test

```bash
tina4 migrate
tina4 serve
```

Test the endpoints with curl or the Swagger UI. If something is wrong, tell the AI what needs to change.

### 4. Iterate

"The product list should be paginated. Add page and per_page query parameters." The AI updates the code.

### 5. Deploy

```bash
docker compose build
docker compose up -d
```

From idea to production in minutes, not days.

---

## Real-World Example: Building an API in 5 Minutes

Here is a real conversation with an AI assistant:

**You:** "Add a blog to my Tina4 Ruby app. Posts with title, body, published flag, and user_id. CRUD API at /api/posts. Only published posts should be visible to anonymous users. Authors can see their own drafts."

**AI generates:**

1. `src/migrations/20260322_create_posts_table.sql` -- the migration
2. `src/orm/post.rb` -- the model with fields and relationships
3. `src/routes/posts.rb` -- CRUD routes with authentication and filtering
4. `tests/posts_spec.rb` -- RSpec tests for all scenarios

All using correct Tina4 conventions:

```ruby
Tina4::Router.get("/api/posts") do |request, response|
  db = Tina4.database

  # Check if user is authenticated (optional)
  user_id = nil
  auth_header = request.headers["Authorization"] || ""
  if auth_header.start_with?("Bearer ")
    token = auth_header.sub("Bearer ", "")
    if Tina4::Auth.valid_token(token)
      payload = Tina4::Auth.get_payload(token)
      user_id = payload["user_id"]
    end
  end

  if user_id
    # Authenticated: show published + own drafts
    posts = db.fetch(
      "SELECT * FROM posts WHERE published = 1 OR user_id = :user_id ORDER BY created_at DESC",
      { user_id: user_id }
    )
  else
    # Anonymous: show published only
    posts = db.fetch("SELECT * FROM posts WHERE published = 1 ORDER BY created_at DESC")
  end

  response.json({ posts: posts, count: posts.length })
end
```

The AI knows:
- `Tina4::Router.get` for routes
- `request.headers["Authorization"]` for the token
- `Tina4::Auth.valid_token` and `Tina4::Auth.get_payload` for JWT
- `db.fetch` with named parameters for queries
- `response.json` for JSON responses

It did not hallucinate. It did not guess. It read CLAUDE.md and wrote correct code.

---

## Why This Matters

Traditional development: write every line, look up every API, debug every typo. A simple CRUD feature takes an hour.

Vibe coding with Tina4: describe what you want. The AI generates correct code. You review and deploy. The same feature takes 5 minutes.

The insight: AI can only be as good as the framework it targets. A framework with 200 gems, 15 configuration files, and 3 ways to do everything gives the AI too many choices. A framework with zero dependencies, one way to do everything, and a complete reference in CLAUDE.md gives the AI exactly what it needs.

Every Tina4 design decision -- zero deps, convention over configuration, identical API across 4 languages, CLAUDE.md -- exists to make AI-assisted development work.

You bring the ideas. The AI brings the implementation. Tina4 is the bridge.

---

## Exercise: Vibe-Code a Feature

Open your Tina4 Ruby project with an AI assistant (Claude Code, Cursor, or Copilot) and try this prompt:

```
Add a comment system to my blog:
1. Create a comments table with post_id, author_name, body, created_at
2. Create a Comment model with belongs_to :post relationship
3. Add POST /api/posts/{id}/comments to add a comment
4. Add GET /api/posts/{id}/comments to list comments
5. Modify GET /api/posts/{id} to include comments
6. Add RSpec tests for the comment endpoints
```

Verify the AI generates:
- A migration file in `src/migrations/`
- A model file in `src/orm/`
- Route handlers in `src/routes/`
- Test file in `tests/`

Run `tina4 migrate && tina4 test` to verify everything works.

---

## Gotchas

### 1. AI Generates Rails Syntax Instead of Tina4

**Problem:** The AI writes `render json:` instead of `response.json`.

**Cause:** The AI defaulted to Rails conventions.

**Fix:** Make sure CLAUDE.md is in your project root. Mention "Tina4 Ruby" explicitly in your prompt.

### 2. AI Invents Non-Existent Methods

**Problem:** The AI calls `Tina4::Router.resource` which does not exist.

**Cause:** The AI hallucinated a method from another framework.

**Fix:** Review generated code against the CLAUDE.md reference. Ask the AI to only use methods documented in CLAUDE.md.

### 3. AI Generates Tests That Do Not Match the Implementation

**Problem:** Tests reference endpoints or response formats that differ from the actual routes.

**Fix:** Generate routes first, then ask the AI to generate tests that match the existing routes.

### 4. AI Forgets to Run Migrations

**Problem:** The app crashes because the table does not exist.

**Fix:** Always run `tina4 migrate` after generating migrations. Include it in your prompts: "...and tell me the commands to run."

### 5. AI Uses require Instead of Auto-Loading

**Problem:** The AI adds `require_relative "../orm/product"` at the top of route files.

**Cause:** Ruby convention is to require files explicitly, but Tina4 auto-loads everything in `src/routes/` and `src/orm/`.

**Fix:** Remove the require statements. Tina4 handles loading automatically.

### 6. AI Generates Over-Engineered Solutions

**Problem:** The AI creates service objects, repository patterns, and dependency injection for a simple CRUD feature.

**Fix:** Tell the AI: "Keep it simple. Use Tina4's built-in features only. No extra abstractions." Tina4's philosophy is simplicity -- the AI should follow it.

### 7. AI Does Not Know About to_h

**Problem:** The AI serializes model objects with `to_json` instead of `to_h`.

**Fix:** Tina4 ORM objects use `to_h` (Ruby idiom for hash conversion) followed by `response.json`. The CLAUDE.md file documents this pattern.
