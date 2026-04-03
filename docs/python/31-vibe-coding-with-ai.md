# Chapter 31: Vibe Coding with AI

## Why Tina4 is Built for AI-Assisted Development

Tell your AI assistant: "Add a product catalog with search, pagination, and category filtering." In most frameworks, the AI needs to guess which packages to install, which config files to create, which naming conventions to follow. It hallucinates half of it.

With Tina4, the AI reads one file -- `CLAUDE.md` -- and knows everything. Every method signature. Every import path. Every convention. It generates correct, runnable code on the first try because there is only one way to do things in Tina4.

This is not accidental. Tina4 was designed from the ground up for AI-assisted development.

---

## The Zero-Dependency Advantage

When an AI generates code for Django, it might suggest `from django.core.cache import cache` or `from django.views.decorators.cache import cache_page`. Both exist. Both work differently. The AI guesses.

Tina4 eliminates the guesswork. One cache. One queue. One ORM. One template engine. No ambiguity. No alternatives. No "it depends on which package you installed." The AI knows.

```python
# There is only one way to cache in Tina4
from tina4_python.cache import cache_get
products = cache_get("products")

# There is only one way to queue in Tina4
from tina4_python.queue import Queue
queue = Queue(topic="emails")
queue.push({"to": "user@test.com"})

# There is only one way to send email in Tina4
from tina4_python.messenger import Messenger
mailer = Messenger()
mailer.send(to="user@test.com", subject="Welcome", body="Hello!")
```

Zero dependencies means zero confusion for AI.

---

## CLAUDE.md -- The AI's Instruction Manual

Every Tina4 project includes a `CLAUDE.md` file that tells AI assistants exactly how the framework works. It contains:

- Every method signature with parameters and return types
- The project structure convention (src/routes/, src/orm/, src/templates/)
- The .env variable reference
- Code style rules (routes return `response()`, ORM uses `to_dict()`)
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

These skills are automatically installed when AI tools are detected:

```python
# In your project root
AI.install_context(".")  # Detects Claude, Cursor, Copilot, etc.
```

---

## The Convention Advantage

AI thrives on convention. Every Tina4 project follows the same structure. The AI never asks "where should I put this?"

```
src/
  routes/hello.py       -> AI knows: this is a route file
  orm/product.py        -> AI knows: this is an ORM model
  templates/home.html   -> AI knows: this is a template
  middleware/auth.py     -> AI knows: this is middleware
```

Tell the AI "add a User model" and it creates `src/orm/user.py` with the correct field definitions, the correct class structure, and the correct method stubs. Every time.

---

## Real-World Vibe Coding Session

Here is an actual conversation with Claude Code in a Tina4 Python project:

**You:** "Add a blog with posts and comments. Posts belong to users. Comments belong to posts. I want a REST API and a template page that lists posts."

**Claude Code generates:**

1. `src/orm/post.py` -- Model with relationships to user and comments
2. `src/orm/comment.py` -- Model with relationship to post
3. `src/routes/api/posts.py` -- Full CRUD API (list, get, create, update, delete)
4. `src/routes/api/comments.py` -- Nested comments API
5. `src/routes/blog.py` -- Template route for the blog page
6. `src/templates/blog.html` -- Page with tina4css cards for each post
7. `src/migrations/20260322_create_posts_and_comments.sql` -- Database schema

All correct. All runnable. First try.

**You:** "Add pagination to the posts list"

**Claude adds** `request.params.get("page", 1)` handling and `to_dict()` with limit/offset -- because CLAUDE.md told it exactly how Tina4 pagination works.

**You:** "Cache the post list for 5 minutes"

**Claude adds** `cache_get(f"posts_page_{page}")` with `cache_set(f"posts_page_{page}", data, ttl=300)` -- because it knows the cache API.

**You:** "Send an email when a new comment is posted"

**Claude adds** `mailer = Messenger(); mailer.send(...)` -- because it knows Messenger reads from .env.

No research. No Stack Overflow. No package debates. Describe the intent. The AI builds it.

---

## Python-Specific Patterns the AI Knows

The CLAUDE.md file teaches AI assistants the correct Python patterns for Tina4:

### Route Decorators

```python
from tina4_python.core.router import get, post, put, delete, template

@get("/api/products")
async def list_products(request, response):
    products = Product().select("*")
    return response({"products": [p.to_dict() for p in products]})

@post("/api/products")
async def create_product(request, response):
    body = request.body
    product = Product()
    product.name = body["name"]
    product.price = body["price"]
    product.save()
    return response(product.to_dict(), 201)
```

### Template Rendering

```python
@get("/products")
async def products_page(request, response):
    products = Product().select("*", order_by="name ASC")
    return response(template("products.html", products=[p.to_dict() for p in products]))
```

### Middleware Attachment

```python
@get("/api/profile", middleware=["auth_middleware"])
async def get_profile(request, response):
    user = User.find(request.user_id)
    return response(user.safe_dict()) if user else response({"error": "User not found"}, 404)
```

### WebSocket Handlers

```python
from tina4_python.core.router import websocket

@websocket("/ws/updates")
async def updates_handler(connection, event, data):
    if event == "message":
        await connection.broadcast(data)
```

The AI generates all of these patterns correctly because CLAUDE.md specifies:

- Handlers are always `async def`
- Route handlers always receive `(request, response)`
- WebSocket handlers always receive `(connection, event, data)`
- Responses use `response()` with the data as the first argument
- Templates use `template("name.html", **kwargs)`

---

## Supported AI Tools

Tina4 auto-detects and installs context for:

| Tool | Detection | Context installed |
|------|-----------|------------------|
| Claude Code | `.claude/` directory | CLAUDE.md + skills |
| Cursor | `.cursor/` directory | .cursorrules |
| GitHub Copilot | `.github/copilot/` | instructions.md |
| Windsurf | `.windsurfrules` file | .windsurfrules |
| Aider | `.aider.conf.yml` | .aider.conf.yml |
| Cline | `.cline/` directory | .clinerules |
| OpenAI Codex | `.codex/` directory | instructions.md |

Run `tina4 doctor` to see which tools are detected in your project.

---

## The AI Chat in Dev Dashboard

The dev dashboard at `/__dev` includes an AI chat tab. Enter your Anthropic or OpenAI API key and chat with Claude/GPT about your code directly from the browser.

The AI has full context of your Tina4 project -- routes, models, templates, configuration. Ask it:

- "Why is my /api/users route returning 500?"
- "How do I add WebSocket support?"
- "Write a migration to add an 'avatar' column to users"

The "Ask about this error" button on the error overlay sends the full stack trace and source code to the AI for instant debugging.

---

## Tips for Effective Vibe Coding with Tina4

1. **Be specific about what you want** -- "Add a product API with search by name and price range" works better than "add products"

2. **Let the AI use tina4 generate** -- "Run tina4 generate model Product then add price and category fields" gives the AI a starting point

3. **Reference the .env** -- "Configure the queue to use RabbitMQ" -- the AI knows to update .env with `TINA4_QUEUE_BACKEND=rabbitmq`

4. **Ask for tests** -- "Write tests for the Product API" -- the AI uses Tina4's inline testing framework

5. **Ask for the gallery** -- "Deploy the auth gallery example" -- the AI clicks Try It and you have a working JWT demo

6. **Review, don't rewrite** -- The AI's first attempt is usually 90% correct. Tweak the details instead of starting over.

---

## Exercise

Open your Tina4 Python project in Claude Code (or your preferred AI tool) and try these prompts:

1. "Add a Contact model with name, email, phone, and message fields"
2. "Create a contact form page at /contact with an HTML template using tina4css"
3. "Add an API endpoint that accepts the form submission and saves it to the database"
4. "Send an email notification when a new contact is submitted"
5. "Add rate limiting to the contact form -- max 3 submissions per minute"

Each prompt should generate correct, runnable code on the first try. If it does not, check that CLAUDE.md is in your project root.

---

## Gotchas

### 1. No CLAUDE.md?

**Problem:** The AI generates incorrect import paths or uses wrong API patterns.

**Fix:** Run `tina4 init` or `AI.install_context(".")` to generate the CLAUDE.md file. This gives the AI complete framework knowledge.

### 2. AI Suggests Wrong Import Paths

**Problem:** The AI writes `from tina4 import Router` instead of `from tina4_python.core.router import get`.

**Fix:** The CLAUDE.md might be outdated. Regenerate it with `AI.install_context(".", force=True)`. Check that the file includes the correct import paths for Python.

### 3. AI Hallucinates a Package

**Problem:** The AI suggests `pip install tina4-cache-redis` or similar packages that do not exist.

**Fix:** Remind it: "Tina4 has zero dependencies. Use only built-in features." Everything -- caching, queues, email, WebSocket, GraphQL -- is part of the framework.

### 4. AI Creates Files in Wrong Location

**Problem:** The AI creates routes in `routes/` instead of `src/routes/`.

**Fix:** Tell it: "Follow the src/routes, src/orm, src/templates convention." The CLAUDE.md file specifies this, but some AI tools need a reminder.

### 5. AI Code Does Not Run

**Problem:** The generated code has syntax errors or does not follow Tina4 patterns.

**Fix:** Check that route handlers use `async def` and return `response()`. Check that ORM models extend `ORM`. Check that templates use `template()` for rendering. These are the most common mistakes.

### 6. AI Uses Synchronous Code

**Problem:** The AI generates `def handler(request, response)` instead of `async def handler(request, response)`.

**Fix:** All Tina4 Python route handlers must be `async def`. Tell the AI: "All handlers are async in Tina4 Python."

### 7. AI Suggests Flask/Django Patterns

**Problem:** The AI writes `@app.route("/products")` or `return JsonResponse(data)`.

**Fix:** The AI is falling back to its general Python web framework knowledge. Point it to CLAUDE.md: "Read the CLAUDE.md file for Tina4 Python patterns. Do not use Flask or Django patterns."

---

## The Philosophy

Tina4 was not made compatible with AI coding tools. It was designed for them.

Convention over configuration: the AI knows where things go. Zero dependencies: the AI never chooses between packages. A single CLAUDE.md: the AI has complete framework knowledge. Identical APIs across 4 languages: the AI's knowledge transfers instantly.

You describe the intent. The AI writes the code. You review and refine. That is the workflow Tina4 was built for.

*The Intelligent Native Application 4ramework. Built for AI. Built for you.*
