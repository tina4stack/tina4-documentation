# Tina4 Node.js -- Quick Reference

> **TINA4 — The Intelligent Native Application 4ramework**
> Simple. Fast. Human. | Built for AI. Built for you.

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
    <a href="#static-websites">Static Websites</a> &bull;
    <a href="#basic-routing">Routing</a> &bull;
    <a href="#middleware">Middleware</a> &bull;
    <a href="#templates">Templates</a> &bull;
    <a href="#session-handling">Sessions</a> &bull;
    <a href="#scss-stylesheets">SCSS</a> &bull;
    <a href="#environments">Environments</a> &bull;
    <a href="#authentication">Authentication</a> &bull;
    <a href="#html-forms-and-tokens">Forms &amp; Tokens</a> &bull;
    <a href="#ajax">AJAX</a> &bull;
    <a href="#swagger">OpenAPI</a> &bull;
    <a href="#databases">Databases</a> &bull;
    <a href="#database-results">Database Results</a> &bull;
    <a href="#migrations">Migrations</a> &bull;
    <a href="#orm">ORM</a> &bull;
    <a href="#crud">CRUD</a> &bull;
    <a href="#consuming-rest-apis">REST Client</a> &bull;
    <a href="#inline-testing">Testing</a> &bull;
    <a href="#services">Services</a> &bull;
    <a href="#websockets">WebSockets</a> &bull;
    <a href="#queues">Queues</a> &bull;
    <a href="#wsdl">WSDL</a> &bull;
    <a href="#localization">Localization</a> &bull;
    <a href="#graphql">GraphQL</a>
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

### Static Websites {#static-websites}

Put `.html` files in `src/templates/` and assets in `src/public/`. The framework serves them without additional configuration.

```html
<!-- src/templates/index.html -->
<h1>Hello Static World</h1>
```

```typescript
import { Router } from "tina4-nodejs";

Router.get("/", async (req, res) => {
    return res.html("index.html");
});
```

[More details](static-website.md) on static website routing.

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

Redirect after a POST:

```typescript
Router.post("/register", async (req, res) => {
    return res.redirect("/welcome");
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

### Sessions {#session-handling}

The default session handler stores data on the file system. Override `TINA4_SESSION_HANDLER` in `.env` to switch backends.

| Handler | Backend | Notes |
|---------|---------|-------|
| `FileSession` (default) | File system | No extra config |
| `RedisSession` | Redis | Set `TINA4_REDIS_URL` |
| `MongoSession` | MongoDB | Set `TINA4_MONGO_URI` |

```env
TINA4_SESSION_HANDLER=RedisSession
TINA4_REDIS_URL=redis://localhost:6379
```

```typescript
import { Router } from "tina4-nodejs";

Router.get("/session/set", async (req, res) => {
    req.session.set("name", "Joe");
    req.session.set("info", { items: ["one", "two", "three"] });
    return res.json({ message: "Session set!" });
});

Router.get("/session/get", async (req, res) => {
    const name = req.session.get("name");
    const info = req.session.get("info");
    return res.json({ name, info });
});

Router.get("/session/clear", async (req, res) => {
    req.session.delete("name");
    return res.json({ message: "Session key removed!" });
});
```

### SCSS Stylesheets {#scss-stylesheets}

Drop `.scss` files in `src/scss/`. The framework compiles them to `src/public/css/` automatically.

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```

Reference the compiled file from your templates:

```html
<link rel="stylesheet" href="/css/main.css">
```

[More details](css.md) on CSS and SCSS.

### Environments {#environments}

The `.env` file holds your project configuration. The framework reads it at startup.

```env
TINA4_DEBUG=true
TINA4_PORT=7148
DATABASE_URL=sqlite:///data/app.db
TINA4_LOG_LEVEL=ALL
API_KEY=ABC1234
```

```typescript
const apiKey = process.env.API_KEY ?? "ABC1234";
```

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

### HTML Forms and Tokens {#html-forms-and-tokens}

Tina4 embeds a CSRF form token into every POST form. The framework validates it on submission.

```html
<!-- src/templates/register.html -->
<form method="POST" action="/register">
    {{ form_token("Register" ~ random()) }}
    <input name="email" type="email">
    <button>Save</button>
</form>
```

```typescript
import { Router } from "tina4-nodejs";

/**
 * @noauth
 */
Router.post("/register", async (req, res) => {
    const email = req.body.email;
    // token validated automatically — proceed with form data
    return res.redirect("/welcome");
});
```

[More details](posting-form-data.md) on form tokens, file uploads, error handling, and disabling auth.

### AJAX and frond.js {#ajax}

Tina4 ships with frond.js, a small zero-dependency JavaScript library for AJAX calls, form submissions, and real-time WebSocket connections.

```html
<script src="/frond.js"></script>

<script>
frond.get("/api/users", (data) => {
    console.log(data);
});

frond.post("/api/save", { name: "Alice" }, (data) => {
    console.log(data);
});
</script>
```

[More details](/general/frond) on available features.

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

Follow the links for more on [Available Connections](database.md#connections), [Core Methods](database.md#core-methods), [Usage](database.md#usage) and [Full transaction control](database.md#transactions).

### Database Results {#database-results}

```typescript
import { Database } from "tina4-nodejs";

const db = Database.getConnection();
const result = await db.fetch("SELECT * FROM test_record ORDER BY id", 3, 1);

const array     = result.toArray();
const paginated = result.toPaginate();
const csvData   = result.toCsv();
const jsonData  = result.toJson();
```

Looking at detailed [Usage](database.md#usage) will deepen your understanding.

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

### ORM {#orm}

ORM models live in `src/orm/`. Each file maps a class to a table. Define fields, types, and constraints. The ORM handles the rest.

```typescript
import { BaseModel } from "tina4-nodejs/orm";

export class User extends BaseModel {
    static tableName = "users";
    static fields = {
        id:    { type: "integer", primaryKey: true, autoIncrement: true },
        name:  { type: "string", required: true },
        email: { type: "string", required: true },
    };

    id!: number;
    name!: string;
    email!: string;
}
```

Property names are `camelCase`. Column names are `snake_case`. Tina4 converts between them automatically.

```typescript
// Create
const user = new User();
user.name  = "Alice";
user.email = "alice@example.com";
await user.save();

// Read
const found = await User.findById(1);

// Delete
await found.delete();
```

ORM covers more ground than this snippet shows. Study the [Advanced Detail](orm.md) to get the full value.

### CRUD {#crud}

The CLI generates a full CRUD route file from your model. One command wires up all five REST endpoints:

```bash
tina4 generate crud User
```

This creates `src/routes/users.ts` with GET, POST, PUT, PATCH, and DELETE routes. Model, routes, and migration -- all connected, ready to serve.

```typescript
Router.get("/users/dashboard", async (req, res) => {
    const users = await User.select("id, name, email");
    return res.html("users/dashboard.html", { crud: users.toCrud(req) });
});
```

[More details](crud.md) on how CRUD generates its files and where they live.

### Consuming REST APIs {#consuming-rest-apis}

```typescript
import { Api } from "tina4-nodejs";

const api = new Api("https://api.example.com", { authHeader: "Bearer xyz" });
const result = await api.get("/users/42");
console.log(result.body);

// POST with a payload
const created = await api.post("/users", { name: "Alice" });
console.log(created.body);
```

[More details](rest-api.md) on sending POST data, authorization headers, and other controls for outbound API requests.

### Inline Testing {#inline-testing}

```typescript
import { tests, assertEqual, assertRaises } from "tina4-nodejs";

@tests(
    assertEqual([7, 7], 1),
    assertEqual([-1, 1], -1),
    assertRaises(Error, [5, 0]),
)
function divide(a: number, b: number): number {
    if (b === 0) throw new Error("division by zero");
    return a / b;
}
```

Run: `tina4 test`

### Services {#services}

Services are long-running background processes that start with your application. Define a class that extends `Service` and implement the `run()` method.

```typescript
import { Service } from "tina4-nodejs";

export class CleanupService extends Service {
    async run(): Promise<void> {
        setInterval(async () => {
            await db.execute("DELETE FROM sessions WHERE expires_at < NOW()");
        }, 60_000);
    }
}
```

Register it in your app entry point:

```typescript
import { App } from "tina4-nodejs";
import { CleanupService } from "./services/CleanupService";

App.register(CleanupService);
```

### Websockets {#websockets}

Define a WebSocket handler the same way you define an HTTP route. The connection is persistent and bi-directional. No `ws` or `socket.io` required.

```typescript
import { Router } from "tina4-nodejs";

Router.websocket("/ws/chat", (connection, event, data) => {
    if (event === "open") {
        connection.send("Welcome to chat!");
    }
    if (event === "message") {
        connection.send(`Echo: ${data}`);
    }
    if (event === "close") {
        console.log("Client disconnected");
    }
});
```

The callback receives three arguments: `connection` (send messages through it), `event` (`"open"`, `"message"`, or `"close"`), and `data` (the message text). WebSocket runs alongside your HTTP server on the same port.

Have a look at the PubSub example under [WebSockets](websockets.md).

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

### WSDL {#wsdl}

```typescript
import { WSDL, wsdlOperation, wsdlRoute } from "tina4-nodejs";

class Calculator extends WSDL {
    static serviceUrl = "http://localhost:7148/calculator";

    Add(a: number, b: number): object {
        return { Result: a + b };
    }

    SumList(Numbers: number[]): object {
        return {
            Numbers,
            Total: Numbers.reduce((s, n) => s + n, 0),
            Error: null,
        };
    }
}

@wsdlRoute("/calculator")
Router.post("/calculator", async (req, res) => {
    return res.wsdl(new Calculator(req));
});
```

[More Details](wsdl.md) on WSDL configuration and usage.

### GraphQL {#graphql}

Tina4 ships a built-in GraphQL endpoint. Define your schema and resolvers. The framework mounts them at `/graphql`.

```typescript
import { GraphQL } from "tina4-nodejs";

const schema = `
    type User {
        id: Int
        name: String
        email: String
    }

    type Query {
        user(id: Int!): User
        users: [User]
    }
`;

const resolvers = {
    Query: {
        user: async (_: unknown, { id }: { id: number }) => {
            return User.findById(id);
        },
        users: async () => {
            return User.select("*");
        },
    },
};

GraphQL.register({ schema, resolvers });
```

Visit `http://localhost:7148/graphql` to query your API. The GraphiQL playground is available when `TINA4_DEBUG=true`.

[More details](graphql.md) on mutations, subscriptions, and authentication.

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">Back to top</a>
</nav>

</div>
### Localization (i18n) {#localization}

Set `TINA4_LANGUAGE` in `.env` to change the framework language. Supported: `en`, `fr`, `af`.

```env
TINA4_LANGUAGE=af
```

```typescript
import { localize } from "tina4-nodejs";

const _ = localize();
console.log(_("Server stopped.")); // "Bediener gestop." (af)
```

Translations fall back to English for unsupported languages.

```typescript
import { AVAILABLE_LANGUAGES } from "tina4-nodejs";
// ["en", "fr", "af"]
```

