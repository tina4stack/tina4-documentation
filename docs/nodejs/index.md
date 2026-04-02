# Tina4 Node.js -- Quick Reference

<div v-pre>


::: tip Hot Tips
- Routes go in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
- GET routes are public by default; POST/PUT/PATCH/DELETE require a token
- Return an object from `res.json()` and the framework sets `application/json`
- Use `tina4 serve` to launch the dev server on port 7148
- Node.js 22+ required (uses built-in `node:sqlite`)
:::

<nav class="tina4-menu">
    <a href="#installation">Installation</a> &bull;
    <a href="#basic-routing">Routing</a> &bull;
    <a href="#middleware">Middleware</a> &bull;
    <a href="#templates">Templates</a> &bull;
    <a href="#authentication">Authentication</a> &bull;
    <a href="#databases">Databases</a> &bull;
    <a href="#orm">ORM</a> &bull;
    <a href="#crud">CRUD</a> &bull;
    <a href="#migrations">Migrations</a> &bull;
    <a href="#swagger">OpenAPI</a> &bull;
    <a href="#queues">Queues</a> &bull;
    <a href="#websockets">WebSockets</a>
</nav>

<style>
.tina4-menu {
  background: #2c3e50; color: white; padding: 1rem; border-radius: 8px; margin: 2rem 0; text-align: center; font-size: 1.1rem;
}
.tina4-menu a { color: #1abc9c; text-decoration: none; margin: 0 0.4rem; }
.tina4-menu a:hover { text-decoration: underline; }
</style>

### Installation {#installation}

Four commands. The server starts and your browser shows the result.

```bash
npm install tina4-nodejs
tina4 init my-project
cd my-project
tina4 serve
```

The dev server runs at `http://localhost:7148`. One dependency. No `node-gyp`. No native binaries. SQLite uses Node's built-in `node:sqlite` module.

### Basic Routing {#basic-routing}

The `Router` class maps requests to your code. Define a path. Write a handler. The framework does the rest.

```typescript
import { Router } from "tina4-nodejs";

Router.get("/hello", async (req, res) => {
    return res.json({ message: "Hello, World!" });
});

Router.post("/products", async (req, res) => {
    return res.status(201).json({ name: req.body.name });
});
```

Path parameters use curly braces. Add a type to enforce validation:

```typescript
Router.get("/products/{id:int}", async (req, res) => {
    const id = req.params.id; // number, not string
    return res.json({ product_id: id });
});
```

Group routes that share a prefix. The framework prepends the path:

```typescript
Router.group("/api/v1", (group) => {
    group.get("/users", async (req, res) => {
        return res.json({ users: [] });
    });
    group.post("/users", async (req, res) => {
        return res.status(201).json({ created: true });
    });
});
```

### Middleware {#middleware}

Middleware sits between the request and your handler. It runs before, after, or both.

Function-based middleware receives `req`, `res`, and `next`. Call `next()` to continue. Skip it to block the request.

```typescript
import { Router } from "tina4-nodejs";

function requireApiKey(req, res, next) {
    const key = req.headers["x-api-key"] ?? "";
    if (key !== "my-secret-key") {
        return res.status(401).json({ error: "Invalid API key" });
    }
    next();
}

Router.get("/api/secret", async (req, res) => {
    return res.json({ secret: "The answer is 42" });
}, [requireApiKey]);
```

Class-based middleware uses naming conventions. Methods starting with `before` run before the handler. Methods starting with `after` run after it. Register them with `Router.use()`:

```typescript
import { Router, CorsMiddleware, RequestLogger } from "tina4-nodejs";

Router.use(CorsMiddleware);
Router.use(RequestLogger);
```

Apply middleware to a group and every route inside inherits it:

```typescript
Router.group("/api/admin", (group) => {
    group.get("/dashboard", async (req, res) => {
        return res.json({ page: "admin dashboard" });
    });
}, [requireAuth]);
```

### Template Rendering {#templates}

Place `.html` files in `src/templates/` and static assets in `src/public/`. The Frond engine reads your template, fills in the variables, and delivers clean HTML.

```html
<!-- src/templates/welcome.html -->
<h1>Hello, {{ name }}!</h1>
```

```typescript
import { Router } from "tina4-nodejs";

Router.get("/welcome", async (req, res) => {
    return res.html("welcome.html", { name: "Alice" });
});
```

Frond supports Twig-compatible syntax: loops, conditionals, extends, blocks, includes, and filters. Zero dependencies. Built from scratch.

### Authentication {#authentication}

POST, PUT, PATCH, and DELETE routes require a bearer token by default. GET routes are public unless you mark them otherwise.

Use JSDoc annotations to control access. `@noauth` makes any route public. `@secured` protects a GET route:

```typescript
import { Router } from "tina4-nodejs";

/**
 * @noauth
 */
Router.post("/api/login", async (req, res) => {
    const token = Auth.getToken({ user_id: 42 }, secret);
    return res.json({ token });
});

/**
 * @secured
 */
Router.get("/api/profile", async (req, res) => {
    return res.json({ user: req.user });
});
```

Chain `.secure()` on any route for inline protection. Chain `.cache()` to cache responses:

```typescript
Router.get("/api/account", async (req, res) => {
    return res.json({ account: req.user });
}).secure().cache();
```

### Databases {#databases}

Tina4 defaults to SQLite at `data/app.db`. Set `DATABASE_URL` in `.env` to switch engines. The API stays identical across SQLite, PostgreSQL, MySQL, SQL Server, and Firebird.

```env
# PostgreSQL
DATABASE_URL=postgres://localhost:5432/myapp
# MySQL
DATABASE_URL=mysql://localhost:3306/myapp
```

Access the connection from any route. The database speaks whichever dialect the engine understands:

```typescript
import { Database } from "tina4-nodejs";

const db = Database.getConnection();
const result = await db.fetch("SELECT * FROM users LIMIT 10");
```

### ORM {#orm}

ORM models live in `src/orm/`. Each file maps a class to a table. Define fields, types, and constraints. The ORM handles the rest.

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class Product extends BaseModel {
    static tableName = "products";
    static fields = {
        id: { type: "integer", primaryKey: true, autoIncrement: true },
        name: { type: "string", required: true },
        price: { type: "number", default: 0 },
        inStock: { type: "boolean", default: true },
    };

    id!: number;
    name!: string;
    price: number = 0;
    inStock: boolean = true;
}
```

Property names are `camelCase`. Column names are `snake_case`. Tina4 converts between them: `inStock` maps to `in_stock`.

```typescript
// Create
const product = new Product();
product.name = "Wireless Keyboard";
product.price = 79.99;
await product.save();

// Read
const found = await Product.findById(1);

// Delete
await found.delete();
```

### CRUD {#crud}

The CLI generates a full CRUD route file from your model. One command wires up all five REST endpoints:

```bash
tina4 generate crud Product
```

This creates `src/routes/products.ts` with GET, POST, PUT, PATCH, and DELETE routes. Model, routes, and migration -- all connected, ready to serve.

### Migrations {#migrations}

Generate a timestamped migration file. Write your SQL. Run it. The framework tracks what has run.

```bash
tina4 generate migration create_users_table
```

```sql
-- UP
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
);

-- DOWN
DROP TABLE users;
```

```bash
tina4 migrate
```

Roll back with `tina4 migrate --down`. Check status with `tina4 migrate --status`. Each migration has UP and DOWN sections, so every change is reversible.

### OpenAPI and Swagger UI {#swagger}

Add JSDoc annotations to your routes. Visit `http://localhost:7148/swagger`. Your API documentation appears, interactive and ready to share.

```typescript
import { Router } from "tina4-nodejs";

/**
 * List all products
 * @description Returns all products in the catalog
 * @tags Products
 */
Router.get("/api/products", async (req, res) => {
    return res.json({ products: [] });
});
```

Swagger runs when `TINA4_DEBUG=true`. Set `TINA4_SWAGGER=true` in `.env` to expose it in production. The raw spec lives at `/swagger/json` -- standard OpenAPI 3.0, compatible with every tool in the OpenAPI world.

### Queues {#queues}

Push slow work to the background. The user gets a response in milliseconds. The work still happens -- just not during the request.

```typescript
import { Router, Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

Router.post("/api/register", async (req, res) => {
    queue.push({
        to: req.body.email,
        subject: "Welcome!"
    });
    return res.status(201).json({ message: "Registered" });
});
```

Consume jobs with the generator. Each job must be completed or failed:

```typescript
for (const job of queue.consume("emails")) {
    try {
        await sendEmail(job.payload.to, job.payload.subject);
        job.complete();
    } catch (e) {
        job.fail(e.message);
    }
}
```

No Redis. No RabbitMQ. The file-based backend works out of the box.

### WebSockets {#websockets}

Define a WebSocket handler the same way you define an HTTP route. The connection is persistent and bi-directional. No `ws` or `socket.io` required.

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/echo", (connection, event, data) => {
    if (event === "message") {
        connection.send(`Echo: ${data}`);
    }
});
```

The callback receives three arguments: `connection` (send messages through it), `event` (`"open"`, `"message"`, or `"close"`), and `data` (the message text). WebSocket runs alongside your HTTP server on the same port.

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">Back to top</a>
</nav>

</div>
