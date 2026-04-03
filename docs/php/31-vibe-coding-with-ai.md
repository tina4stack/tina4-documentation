# Chapter 22: Vibe Coding with AI

## Why Tina4 is Built for AI-Assisted Development

Tell your AI assistant: "Add a product catalog with search, pagination, and category filtering." In most frameworks, the AI needs to know which packages to install, which config files to create, which naming conventions to follow, and how to wire everything together. It hallucinates half of it.

With Tina4, the AI reads one file -- `CLAUDE.md` -- and knows everything. Every method signature. Every import path. Every convention. It generates correct, runnable code on the first try because there is one way to do things in Tina4.

This is not accidental. Tina4 was designed from the ground up for AI-assisted development.

---

## The Zero-Dependency Advantage

When an AI generates code for Laravel, it might suggest `use Illuminate\Support\Facades\Cache;` or `use Illuminate\Cache\CacheManager;`. Both exist. Both work differently. The AI guesses.

With Tina4, there is one cache. One queue. One ORM. One template engine. No ambiguity. No alternatives. The AI does not need to ask. It knows.

```php
// There's only one way to cache in Tina4
$cache = cache_get("products");

// There's only one way to queue in Tina4
$queue = new Queue(topic: "emails");
$queue->push(["to" => "user@test.com"]);

// There's only one way to send email in Tina4
$mail = new Messenger();
$mail->send(to: "user@test.com", subject: "Welcome");
```

Zero dependencies means zero confusion for AI.

---

## CLAUDE.md -- The AI's Instruction Manual

Every Tina4 project includes a `CLAUDE.md` file. It tells AI assistants how the framework works:

- Every method signature with parameters and return types
- The project structure convention (src/routes/, src/orm/, src/templates/)
- The .env variable reference
- Code style rules (routes return `$response()`, ORM uses `toArray()`)
- Database connection string formats
- Common gotchas and how to avoid them

Open a Tina4 project in Claude Code, Cursor, or GitHub Copilot. The AI reads this file first and writes correct Tina4 code from the start.

---

## Skills -- Deep Framework Knowledge

Beyond CLAUDE.md, Tina4 ships with three AI skill files:

### tina4-maintainer
For framework maintenance -- porting features between languages, reviewing PRs, running benchmarks, checking parity.

### tina4-developer
For application development -- creating routes, defining models, writing templates, setting up auth, configuring queues.

### tina4-js
For frontend development -- tina4-js signals, Tina4Element components, reactive templates, WebSocket client.

These skills install when AI tools are detected:

```php
// In your project root
AI::installContext('.'); // Detects Claude, Cursor, Copilot, etc.
```

---

## The Convention Advantage

AI thrives on convention. When every Tina4 project follows the same structure, the AI never asks "where should I put this?"

```
src/
  routes/hello.php     → AI knows: this is a route file
  orm/Product.php      → AI knows: this is an ORM model
  templates/home.twig  → AI knows: this is a template
  middleware/Auth.php   → AI knows: this is middleware
```

Tell the AI "add a User model." It creates `src/orm/User.php` with the correct field definitions, the correct namespace, the correct method stubs. Every time.

---

## Real-World Vibe Coding Session

An actual conversation with Claude Code in a Tina4 PHP project:

**You:** "Add a blog with posts and comments. Posts belong to users. Comments belong to posts. I want a REST API and a template page that lists posts."

**Claude Code generates:**

1. `src/orm/Post.php` -- Model with hasMany comments, belongsTo user
2. `src/orm/Comment.php` -- Model with belongsTo post
3. `src/routes/api/posts.php` -- Full CRUD API (list, get, create, update, delete)
4. `src/routes/api/comments.php` -- Nested comments API
5. `src/routes/blog.php` -- Template route for the blog page
6. `src/templates/blog.twig` -- Page with tina4css cards for each post
7. `migrations/20260322_create_posts_and_comments.sql` -- Database schema

All correct. All runnable. First try.

**You:** "Add pagination to the posts list"

**Claude adds** `$request->params['page']` handling and `toArray(page: $page, perPage: 10)` -- because CLAUDE.md told it how Tina4 pagination works.

**You:** "Cache the post list for 5 minutes"

**Claude adds** `cache_get("posts_page_$page")` with `cache_set("posts_page_$page", $data, 300)` -- because it knows the cache API.

**You:** "Send an email when a new comment is posted"

**Claude adds** `$mail = new Messenger(); $mail->send(...)` -- because it knows Messenger reads from .env.

No research. No Stack Overflow. Describe what you want. The AI builds it.

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

The dev dashboard at `/__dev` includes an AI chat tab. Enter your Anthropic or OpenAI API key and chat with Claude/GPT about your code from the browser.

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

6. **Review, do not rewrite** -- The AI's first attempt is usually 90% correct. Tweak the details instead of starting over.

---

## Exercise

Open your Tina4 PHP project in Claude Code (or your preferred AI tool) and try these prompts:

1. "Add a Contact model with name, email, phone, and message fields"
2. "Create a contact form page at /contact with a Twig template using tina4css"
3. "Add an API endpoint that accepts the form submission and saves it to the database"
4. "Send an email notification when a new contact is submitted"
5. "Add rate limiting to the contact form -- max 3 submissions per minute"

Each prompt should generate correct, runnable code on the first try. If it does not, check that CLAUDE.md is in your project root.

---

## Gotchas

1. **No CLAUDE.md?** Run `tina4 init` or `AI::installContext('.')` to generate it
2. **AI suggests wrong import paths?** The CLAUDE.md might be outdated -- regenerate it with `AI::installContext('.', force: true)`
3. **AI hallucinates a package?** Remind it: "Tina4 has zero dependencies, use only built-in features"
4. **AI creates files in wrong location?** Tell it: "Follow the src/routes, src/orm, src/templates convention"
5. **AI code does not run?** Check that routes return `$response->json()` not `echo` -- Tina4 convention matters

---

## The Philosophy

Tina4 is not just compatible with AI coding tools. It was designed to make AI-assisted development effortless.

Convention over configuration means the AI always knows where things go. Zero dependencies means the AI never chooses between packages. A single CLAUDE.md file means the AI has complete framework knowledge. Identical APIs across 4 languages means the AI's knowledge transfers instantly.

The future of web development is collaborative. You describe the intent. The AI writes the code. You review and refine. Tina4 is built for that future.

*The Intelligent Native Application 4ramework. Built for AI. Built for you.*
