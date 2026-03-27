# Chapter 22: Vibe Coding with AI

## Why Tina4 is Built for AI-Assisted Development

Tell your AI assistant: "Add a product catalog with search, pagination, and category filtering." In most frameworks, the AI needs to know which packages to install, which config files to create, which naming conventions to follow, and how to wire everything together. It hallucinates half of it.

With Tina4, the AI reads one file -- `CLAUDE.md` -- and knows everything. Every method signature. Every import path. Every convention. It generates correct, runnable code on the first try because there is only one way to do things in Tina4.

This is not accidental. Tina4 was built from the ground up as the best framework for AI-assisted development.

---

## The Zero-Dependency Advantage

When an AI generates code for Express, it might suggest `express-session` or `cookie-session` or `connect-redis`. All exist. All work differently. The AI guesses.

With Tina4, there is one cache. One queue. One ORM. One template engine. No ambiguity. No alternatives. No "it depends on which package you installed."

```typescript
// There is only one way to cache in Tina4
const data = await cacheGet("products");

// There is only one way to queue in Tina4
await Queue.produce("emails", { to: "user@test.com" });

// There is only one way to send email in Tina4
const mail = new Messenger();
await mail.send("user@test.com", "Welcome", "<h1>Welcome!</h1>");
```

Zero dependencies means zero confusion for AI.

---

## CLAUDE.md -- The AI's Instruction Manual

Every Tina4 project includes a `CLAUDE.md` file that tells AI assistants exactly how the framework works:

- Every method signature with parameters and return types
- The project structure convention (`src/routes/`, `src/orm/`, `src/templates/`)
- The `.env` variable reference
- Code style rules (routes use `async (req, res) =>`, ORM uses `toDict()`)
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

AI thrives on convention. Every Tina4 project follows the same structure. The AI never asks "where should I put this?"

```
src/
  routes/hello.ts       → AI knows: this is a route file
  orm/Product.ts        → AI knows: this is an ORM model
  templates/home.twig   → AI knows: this is a template
```

Tell the AI "add a User model" and it creates `src/orm/User.ts` with the correct class definition, the correct imports, and the correct property types. Every time.

---

## Real-World Vibe Coding Session

Here is an actual conversation with Claude Code in a Tina4 Node.js project:

**You:** "Add a blog with posts and comments. Posts belong to users. Comments belong to posts. I want a REST API and a template page that lists posts."

**Claude Code generates:**

1. `src/orm/Post.ts` -- Model with belongsTo User, hasMany Comments
2. `src/orm/Comment.ts` -- Model with belongsTo Post
3. `src/routes/api/posts.ts` -- Full CRUD API
4. `src/routes/api/comments.ts` -- Nested comments API
5. `src/routes/blog.ts` -- Template route for the blog page
6. `src/templates/blog.twig` -- Page with tina4css cards for each post
7. `src/migrations/20260322_create_posts_and_comments.sql` -- Database schema

All correct. All runnable. First try.

**You:** "Add pagination to the posts list"

**Claude adds** `req.query.page` handling and proper offset calculation -- because CLAUDE.md told it exactly how Tina4 pagination works.

**You:** "Cache the post list for 5 minutes"

**Claude adds** `cacheGet("posts_page_" + page)` with `cacheSet("posts_page_" + page, data, 300)` -- because it knows the cache API.

**You:** "Send an email when a new comment is posted"

**Claude adds** `const mail = new Messenger(); await mail.send(...)` -- because it knows Messenger reads from `.env`.

No research. No Stack Overflow. No "which package should I use?" Describe what you want. The AI builds it.

---

## TypeScript-Specific Advantages

TypeScript makes AI coding even more reliable:

```typescript
// The AI knows the exact types
import { Router, Database, Auth, Queue, Messenger, cacheGet, cacheSet } from "tina4-nodejs";
import { BaseModel } from "tina4-nodejs";

// Type declarations guide the AI
export class Product extends BaseModel {
    static tableName = "products";
    static primaryKey = "id";
    static hasMany = [{ model: "Review", foreignKey: "product_id" }];

    id!: number;
    name!: string;
    price: number = 0;
    inStock: boolean = true;
}

// The AI generates type-safe route handlers
Router.get("/api/products/{id:int}", async (req, res) => {
    const product = new Product();
    await product.load(req.params.id);
    return product.id ? res.json(product.toDict()) : res.status(404).json({ error: "Not found" });
});
```

TypeScript's type system is a guardrail. It prevents the AI from generating code that fails at runtime. Property types, method signatures, and return types steer the AI toward correct code.

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

Run `tina4 doctor` to see which tools are detected.

---

## The AI Chat in Dev Dashboard

The dev dashboard at `/__dev` includes an AI chat tab. Enter your API key. Chat with Claude or GPT about your code directly from the browser.

The AI has full context of your Tina4 project. Ask it anything:

- "Why is my /api/users route returning 500?"
- "How do I add WebSocket support?"
- "Write a migration to add an avatar column to users"

---

## Tips for Effective Vibe Coding with Tina4

1. **Be specific about what you want** -- "Add a product API with search by name and price range" works better than "add products"

2. **Let the AI use tina4 generate** -- "Run tina4 generate model Product then add price and category fields"

3. **Reference the .env** -- "Configure the queue to use RabbitMQ" -- the AI knows to update .env

4. **Ask for tests** -- "Write tests for the Product API" -- the AI uses Tina4's inline testing

5. **Review, don't rewrite** -- The AI's first attempt is usually 90% correct. Tweak the details.

---

## Exercise

Open your Tina4 Node.js project in Claude Code (or your preferred AI tool) and try these prompts:

1. "Add a Contact model with name, email, phone, and message fields"
2. "Create a contact form page at /contact with a Twig template using tina4css"
3. "Add an API endpoint that accepts the form submission and saves it to the database"
4. "Send an email notification when a new contact is submitted"
5. "Add rate limiting to the contact form -- max 3 submissions per minute"

Each prompt should generate correct, runnable TypeScript code on the first try.

---

## Gotchas

1. **No CLAUDE.md?** Run `tina4 init` or `tina4 doctor` to generate it
2. **AI suggests wrong import paths?** The CLAUDE.md might be outdated -- regenerate it
3. **AI hallucinates a package?** Remind it: "Tina4 has zero dependencies, use only built-in features"
4. **AI creates files in wrong location?** Tell it: "Follow the src/routes, src/orm, src/templates convention"
5. **AI code doesn't run?** Check that routes return `res.json()` not just `console.log()` -- Tina4 convention matters
6. **AI uses Express patterns?** Remind it: "This is Tina4, not Express. Import from tina4-nodejs."
7. **AI forgets await?** All Tina4 database and ORM methods are async and need await

---

## The Philosophy

Tina4 was not retrofitted for AI coding tools. It was designed for them from the ground up.

Convention over configuration means the AI knows where things go. Zero dependencies means the AI never chooses between packages. A single CLAUDE.md file means the AI has complete framework knowledge. Identical APIs across 4 languages means that knowledge transfers instantly.

You describe the intent. The AI writes the code. You review and refine. Tina4 is the ground the partnership stands on.

*This is not a framework. This is a partnership.*
