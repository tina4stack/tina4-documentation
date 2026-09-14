# Choosing Your Language

Tina4 runs on four languages. Same API. Same project structure. Same template syntax. Same CLI commands. The framework disappears, and what's left is your team, your hosting, and your problem.

This chapter gives you what you need to choose.

---

## Python

**Best for:** Data science teams, ML/AI integration, async-heavy applications, rapid prototyping.

```python
# src/routes/products.py
from tina4_python import get, post

@get("/api/products")
async def list_products(request, response):
    products = Product.select(page=request.query.get("page", 1))
    return response.json(products)

@post("/api/products")
async def create_product(request, response):
    product = Product.create(request.body)
    return response.json(product, 201)
```

### Why Choose Python

**Async-native.** Tina4 Python runs on asyncio. Every route handler is an async function. External API calls, database queries, file processing - async means your server holds thousands of concurrent connections without spawning threads. One event loop. Thousands of requests.

**Data science integration.** Your web application sits next to a machine learning pipeline. Your API endpoint imports pandas, numpy, or scikit-learn directly. No inter-process communication. No REST calls to a separate service. The model runs in the same process as the route handler. Train in a notebook, deploy behind an endpoint.

**The reference implementation.** Tina4 Python was the first v3 framework to reach 100% completion. When the spec is ambiguous, Python's behaviour is canonical. Every other implementation follows its lead.

**Largest general-purpose community.** Python is the most-taught programming language in universities worldwide. Finding Python developers isn't hard - new graduates learn it first, data scientists think in it, and the library set grows faster than any other language.

### Watch Out For

**GIL limitations.** CPU-bound work is single-threaded. The Global Interpreter Lock (GIL) stops Python code from running truly in parallel. Image processing, PDF generation, heavy computation - offload these to background tasks or a queue worker process. The event loop handles I/O. The GIL handles everything else, one thread at a time.

**Deployment overhead.** Python deployment asks for more setup than PHP. Virtual environments, pip dependencies (Tina4 has zero, but your application might not), process managers. Docker smooths this over. Without Docker, plan for systemd units and environment isolation.

**Package naming.** Install with `pip install tina4-python`. The CLI command is `tina4` (it auto-detects the language). The import is `from tina4_python import ...`. Three different names for the same thing. Learn them once.

### Quick Start

```bash
pip install tina4-python
tina4 init python my-project
cd my-project
tina4 serve
```

---

## PHP

**Best for:** Existing PHP teams, shared hosting, CMS-adjacent projects, the widest hosting support on the planet.

```php
<?php
// src/routes/products.php
use Tina4Router;

Router::get("/api/products", function ($request, $response) {
    $products = Product::select(page: $request->query["page"] ?? 1);
    return $response->json($products);
});

Router::post("/api/products", function ($request, $response) {
    $product = Product::create($request->body);
    return $response->json($product, 201);
});
```

### Why Choose PHP

**Hosting is everywhere.** Shared hosting, VPS, dedicated servers, cloud platforms - if it serves the web, it runs PHP. Every major hosting provider supports it. Every $5/month shared plan includes it. When your client's infrastructure isn't negotiable, PHP fits.

**Fastest Tina4.** PHP 8.1+ with JIT compilation makes Tina4 PHP the fastest of the four in raw request throughput. Add OPcache (compiled bytecode caching) and the framework overhead approaches zero. Requests arrive. Responses leave. The interpreter barely warms up.

**Thirty years of libraries.** Database drivers, payment processing, PDF generation, image manipulation - PHP has well-tested libraries for all of it. Tina4 itself has zero dependencies. Your application can still pull in Composer packages when the need is real.

**Monorepo simplicity.** Tina4 PHP v3 is a single Composer package under the `Tina4\` namespace. No split packages. No sub-repositories. One `composer require`. Everything arrives.

**Familiar ground.** PHP was the first server-side language for a generation of web developers. If your team writes PHP, Tina4 speaks their language. The learning curve is the framework, not the language.

### Watch Out For

**No native async.** Standard PHP is synchronous. One request, one thread, start to finish. For WebSocket support and true async behaviour, you need the Swoole or OpenSwoole extension. Most web applications never need this. But if you plan to hold thousands of persistent connections, check that Swoole is available on your hosting platform before you commit.

**Extension management.** PHP database drivers are C extensions: ext-pgsql, ext-mysqli, ext-sqlite3. On some hosting platforms, enabling these needs a support ticket or a PHP recompilation. Check your target platform's available extensions before you choose your database.

**Case sensitivity.** PHP uses `camelCase` for methods: `fetchOne()`, `softDelete()`, `hasMany()`. Coming from Python or Ruby? It's a style adjustment, nothing more. The API is identical in capability - only the casing differs.

### Quick Start

```bash
composer require tina4stack/tina4php
tina4 init php my-project
cd my-project
tina4 serve
```

---

## Ruby

**Best for:** Startups, elegant code, Rails refugees who want less framework and more control.

```ruby
# src/routes/products.rb
get "/api/products" do |request, response|
  products = Product.select(page: request.query["page"] || 1)
  response.json(products)
end

post "/api/products" do |request, response|
  product = Product.create(request.body)
  response.json(product, 201)
end
```

### Why Choose Ruby

**Elegant syntax.** Ruby was designed to make programmers happy, and it shows. Route definitions read as English. Blocks feel natural. The DSL is clean. Code written in Tina4 Ruby looks the way you think about it.

**Rails without the weight.** You've built Rails applications, and somewhere along the way you spent more time working around the framework than with it. Tina4 Ruby keeps the parts you valued - convention over configuration, migrations, ORM, template engine - and drops the parts you didn't. No massive dependency tree. No opaque internals. No 15-minute boot on a large codebase.

**Startup velocity.** Ruby's expressiveness means less code for the same job. Fewer lines. Fewer files. Faster iteration. For a team that has to ship and adjust, Ruby shrinks the distance between an idea and production.

**Strong testing culture.** The Ruby community treats testing as a first-class concern. Tina4 Ruby fits Ruby's testing tools, and the framework itself carries 2,333 tests. Testing isn't an afterthought here. It's the foundation.

### Watch Out For

**Smaller hosting pool.** Ruby hosting is less common than PHP. Shared hosting with Ruby support is rare. Plan on a VPS, a container platform, or a PaaS - Heroku, Render, Fly.io. The options exist, they're just not everywhere.

**Performance.** Ruby isn't the fastest language. For raw throughput, PHP and Node.js outrun it. For most web applications, Ruby is fast enough. But if you're building a high-traffic API that has to serve thousands of requests a second on one instance, benchmark your actual workload first. Don't assume.

**Smaller talent pool.** Ruby developers are harder to find than Python or JavaScript developers. The community is passionate but compact. If you're scaling a team, fold the hiring timeline into the decision.

### Quick Start

```bash
gem install tina4ruby
tina4 init ruby my-project
cd my-project
tina4 serve
```

---

## Node.js

**Best for:** JavaScript/TypeScript teams, file-based routing, real-time applications, highest raw throughput.

```typescript
// src/routes/api/products/index.ts
export default function handler(request, response) {
    const products = Product.select({ page: request.query.page || 1 });
    return response.json(products);
}

// src/routes/api/products/index.post.ts
export default function handler(request, response) {
    const product = Product.create(request.body);
    return response.json(product, 201);
}
```

### Why Choose Node.js

**One language everywhere.** Frontend and backend. Same developers. Same language. Same tooling. No context switching. A React component and its API endpoint live in one mental model. JavaScript runs on both sides of the wire.

**File-based routing.** Tina4 Node.js maps file paths to URL paths. A file at `src/routes/api/products/[id].ts` handles `/api/products/42`. The filesystem is the routing table. If you've used Next.js, it's already muscle memory.

**Highest raw throughput.** Node.js on V8 handles the most requests a second of the four. For APIs that serve JSON and move data, Node.js sets the highest ceiling. The event loop was built for I/O.

**TypeScript from the ground up.** Tina4 Node.js is written in TypeScript. Full type safety. Autocompletion in every editor. Compile-time error checking. Bugs surface before the server starts, not after.

**WebSocket native.** Node.js handles WebSocket connections with no extra extension. Real-time features - chat, live dashboards, push notifications - work out of the box. No Swoole. No extra gems. The runtime carries it.

### Watch Out For

**Async complexity.** Modern async/await syntax is clean. The tooling underneath isn't always. Unhandled promise rejections, callback-style legacy APIs, a blocked event loop - these traps are real. If your team is new to async JavaScript, expect a learning curve. The syntax is simple. The debugging isn't.

**Single-threaded for user code.** Node.js runs your code on one thread. CPU-heavy work blocks the event loop. Image processing, PDF generation, complex calculations - offload these to worker threads, or queue them for background processing. The event loop handles I/O brilliantly. It handles computation poorly.

**Dependency gravity.** The Node.js ecosystem pulls toward micro-dependencies. Tina4 itself has zero core dependencies. Your application's other packages might drag in hundreds of transitive ones. Be deliberate about what enters your `node_modules`. Every `npm install` is a decision. Treat it as one.

### Quick Start

```bash
npm install tina4-nodejs
tina4 init nodejs my-project
cd my-project
tina4 serve
```

---

## Comparison Table

| Factor | Python | PHP | Ruby | Node.js |
|--------|--------|-----|------|---------|
| **Install** | `pip install tina4-python` | `composer require tina4stack/tina4php` | `gem install tina4ruby` | `npm install tina4-nodejs` |
| **CLI** | `tina4` | `tina4` | `tina4` | `tina4` |
| **Naming** | `snake_case` | `camelCase` | `snake_case` | `camelCase` |
| **Async** | Native (asyncio) | Swoole extension | Rack-based | Native (event loop) |
| **Hosting** | VPS, containers, PaaS | Everywhere | VPS, containers, PaaS | VPS, containers, PaaS |
| **Raw speed** | Good | Very good (JIT) | Adequate | Best |
| **Test count** | 2,112 | 2,220 | 2,333 | 2,646 |
| **Best for** | Data/ML teams | Web agencies, existing PHP | Startups, clean code | JS/TS full-stack teams |
| **WebSocket** | Native async | Swoole required | Rack hijack / Puma | Native |
| **Routing style** | Decorator-based | Static method calls | DSL blocks | File-based + decorators |
| **Learning curve** | Low (if you know Python) | Low (if you know PHP) | Low (if you know Ruby) | Low (if you know JS/TS) |
| **Framework LOC** | ~26,000 | ~35,000 | ~24,000 | ~32,000 |
| **Docker image** | ~60MB | ~50MB | ~70MB | ~40MB |
| **Community size** | Largest (general) | Largest (web-specific) | Smallest | Large |
| **Shared hosting** | Rare | Universal | Rare | Rare |
| **Package manager** | pip | Composer | RubyGems | npm |

---

## Switching Languages

All four implementations share the same skeleton. Switching languages isn't a rewrite, it's a translation.

Five things transfer without a single change:

1. `src/templates/` - Frond syntax is identical. Every template works on every backend.
2. `.env` - Same variables. Same defaults. Same priority chain.
3. `src/migrations/` - Same SQL. The database doesn't care what language talks to it.
4. `src/public/` - Same static files. CSS, JavaScript, images. Untouched.
5. `frond.js` frontend code - Same API. The backend language is invisible to the browser.

Three things need translation:

1. `src/routes/` - Route handlers rewritten in the new language's syntax.
2. `src/orm/` - Model definitions rewritten in the new language's class system.
3. `tests/` - Test files rewritten for the new language's test framework.

The framework knowledge transfers whole. The project structure stays. The templates stay. The migrations stay. The configuration stays. You translate your business logic, and nothing else.

---

## How to Decide

Five questions. Answer them in order. Stop at the first clear answer.

1. **What does your team already know?** Use that language. The Tina4 learning curve is the same across all four. The learning curve for a new programming language isn't. Don't add two learning curves when one will do.

2. **Where are you deploying?** Shared hosting means PHP. Containers mean anything. Serverless platforms - check which runtimes they support before you write code.

3. **What sits next to the web app?** ML models mean Python. A React or Vue frontend team means Node.js. An existing PHP codebase means PHP. The web application is rarely the only software in the system. Choose the language that fits the neighbourhood.

4. **How many concurrent connections do you need?** Chat applications, live dashboards, thousands of WebSocket connections - use Python or Node.js for native async. PHP needs Swoole. Ruby handles moderate concurrency with Puma. Know your ceiling before you build.

5. **Does raw performance matter?** For most applications, all four are fast enough. The framework overhead is sub-millisecond in every language. The bottleneck is your database queries, not your router. But if you need 10,000+ requests a second on one instance, benchmark your actual workload. Numbers on paper aren't numbers in production.

If none of these gives a clear answer, use Python. It's the reference implementation. It has the largest general-purpose community. It's the most-taught language in the world. When all else is equal, start where the most help is.
