# Tina4 Node.js -- Quick Reference

::: tip 🔥 Hot Tips
- Routes go in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
- GET routes are public by default; POST/PUT/PATCH/DELETE require a token
- Return an object from `response()` and the framework auto-sets `application/json`
- Use `tina4 start` to launch the dev server on port 7145
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
tina4 start
```

### Basic Routing {#basic-routing}

Define a path. Write a handler. The framework maps requests to your code.

```javascript
import { get, post } from "tina4-nodejs";

get("/", async (request, response) => {
    return response("<h1>Hello Tina4 Node.js</h1>");
});

post("/api", async (request, response) => {
    return response({ data: request.params });
});
```

### Middleware {#middleware}

Middleware runs before and after your route handlers. Use it for logging, auth checks, or request transformation.

```javascript
import { get, middleware } from "tina4-nodejs";

class LogMiddleware {
    static beforeRequest(request, response) {
        console.log("Before:", request.url);
        return [request, response];
    }

    static afterRequest(request, response) {
        console.log("After:", request.url);
        return [request, response];
    }
}

middleware(LogMiddleware);

get("/protected", async (request, response) => {
    return response("Protected route");
});
```

### Template Rendering {#templates}

Place `.twig` files in `./src/templates` and static assets in `./src/public`. The engine reads your template, fills in the variables, and delivers clean HTML.

```twig
<!-- src/templates/index.twig -->
<h1>Hello {{name}}</h1>
```

```javascript
import { get } from "tina4-nodejs";

get("/", async (request, response) => {
    return response.render("index.twig", { name: "World!" });
});
```

### Authentication {#authentication}

POST, PUT, PATCH, and DELETE routes require a bearer token by default. Pass `Authorization: Bearer API_KEY` in your request headers. Check `.env` for the default `API_KEY`.

```javascript
import { get, post, noAuth, secured } from "tina4-nodejs";

post("/login", noAuth(), async (request, response) => {
    return response("Logged in");
});

get("/protected", secured(), async (request, response) => {
    return response("Welcome!");
});
```

### Databases {#databases}

One line connects to your database. The `fetch` method returns results with built-in pagination.

```javascript
import { Database } from "tina4-nodejs";

const dba = new Database("sqlite3:data.db");
const result = await dba.fetch("SELECT * FROM users", { limit: 10 });
```

### ORM {#orm}

Define your model as a class. Fields map to columns. The ORM handles create, read, update, and delete.

```javascript
import { ORM, IntegerField, StringField } from "tina4-nodejs";

class User extends ORM {
    id = IntegerField({ primaryKey: true, autoIncrement: true });
    name = StringField();
}

await new User({ name: "Alice" }).save();

const user = new User();
await user.load("id = ?", [1]);
```

### CRUD {#crud}

One method generates a full CRUD interface from your ORM model. Bind it to a template and the grid renders itself.

```javascript
import { get } from "tina4-nodejs";

get("/users/dashboard", async (request, response) => {
    const users = new User().select("id, name, email");
    return response.render("users/dashboard.twig", { crud: users.toCrud(request) });
});
```

### Migrations {#migrations}

Create a migration file with the CLI. Write your SQL. Run the migration. The framework tracks what has run.

```bash
tina4 migrate:create create_users_table
```

```sql
-- migrations/00001_create_users_table.sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
);
```

```bash
tina4 migrate
```

### OpenAPI and Swagger UI {#swagger}

Add a `description` to your route. Visit `http://localhost:7145/swagger`. Your API documentation appears, ready to share.

```javascript
import { get, description } from "tina4-nodejs";

get("/users", description("Get all users"), async (request, response) => {
    return response(new User().select("*"));
});
```

### Queues {#queues}

Produce messages to a topic. Consume them asynchronously. The queue handles retries and ordering.

```javascript
import { Queue, Producer, Consumer } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });
new Producer(queue).produce({ to: "alice@example.com", subject: "Welcome" });

const consumer = new Consumer(queue);
for await (const msg of consumer.messages()) {
    console.log(msg.data);
}
```

### WebSockets {#websockets}

Open a connection. Listen for messages. Send responses. The WebSocket handles the protocol, the handshake, and the keepalive.

```javascript
import { get, WebSocket } from "tina4-nodejs";

get("/ws/chat", async (request, response) => {
    const ws = await new WebSocket(request).connection();
    ws.on("message", async (data) => {
        await ws.send(`Echo: ${data}`);
    });
    return response("");
});
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">Back to top</a>
</nav>
