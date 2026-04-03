# Tina4 PHP -- Quick Reference

> **TINA4 — The Intelligent Native Application 4ramework**
> Simple. Fast. Human. | Built for AI. Built for you.

<div v-pre>


::: tip Hot Tips
- Routes go in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
- GET routes are public by default; POST/PUT/PATCH/DELETE require a token
- `$response->json()` returns JSON with the correct headers -- no manual config
- Run `tina4 serve` to start the dev server on port 7146
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
    <a href="#websockets">Websockets</a> &bull;
    <a href="#queues">Queues</a> &bull;
    <a href="#wsdl">WSDL</a> &bull;
    <a href="#graphql">GraphQL</a> &bull;
    <a href="#localization">Localization</a> &bull;
    <a href="#html-builder">HTML Builder</a> &bull;
    <a href="#events">Events</a> &bull;
    <a href="#logging">Logging</a> &bull;
    <a href="#response-cache">Response Cache</a> &bull;
    <a href="#health">Health</a> &bull;
    <a href="#container">DI Container</a> &bull;
    <a href="#error-overlay">Error Overlay</a> &bull;
    <a href="#dev-admin">Dev Admin</a> &bull;
    <a href="#cli">CLI</a> &bull;
    <a href="#mcp">MCP Server</a> &bull;
    <a href="#fakedata">FakeData</a>
</nav>

<style>
.tina4-menu {
  background: #2c3e50; color: white; padding: 1rem; border-radius: 8px; margin: 2rem 0; text-align: center; font-size: 1.1rem;
}
.tina4-menu a { color: #1abc9c; text-decoration: none; margin: 0 0.4rem; }
.tina4-menu a:hover { text-decoration: underline; }
</style>

### Installation {#installation}

```bash
tina4 init php my-project
cd my-project
composer install
tina4 serve
```
[More details](installation.md) on project setup and configuration options.

### Static Websites {#static-websites}

Drop `.html` or `.twig` files in `./src/templates`. Put assets in `./src/public`.

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```
[More details](static-website.md) on static website routing.

### Basic Routing {#basic-routing}

```php
<?php
use Tina4\Router;

Router::get("/", function ($request, $response) {
    return $response->json(["message" => "Hello Tina4 PHP"]);
});

// POST requires a formToken or Bearer auth
Router::post("/api/items", function ($request, $response) {
    return $response->json(["data" => $request->body], 201);
});

// Dynamic path parameters
Router::get("/users/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    return $response->json(["user_id" => $id]);
});
```
Follow the links for [basic routing](basic-routing.md#basic-routing), [dynamic routing](basic-routing.md#dynamic-routing) with variables, and [different response types](basic-routing.md#response-options).

### Middleware {#middleware}

The v3 middleware system uses class-based middleware with `before*`/`after*` static methods.

```php
<?php
use Tina4\Request;
use Tina4\Response;

class AuthMiddleware
{
    public static function beforeAuth(Request $request, Response $response): array
    {
        if (!$request->bearerToken()) {
            return [$request, $response->json(["error" => "Unauthorized"], 401)];
        }
        return [$request, $response];
    }
}
```

Register middleware globally or attach it to a single route.

```php
<?php
use Tina4\Middleware;
use Tina4\Router;

// Global -- runs on every request
Middleware::use(AuthMiddleware::class);

// Per-route -- third argument
Router::get("/api/secret", function ($request, $response) {
    return $response->json(["secret" => "The answer is 42"]);
}, "requireApiKey");
```
Follow the links for more on [middleware declaration](middleware.md#declare), [linking to routes](middleware.md#routes), [middleware chaining](middleware.md#chaining), and [middleware with dynamic routes](middleware.md#dynamic).

### Template Rendering {#templates}

Templates live in `./src/templates`. The framework uses Frond -- a Twig-compatible engine built from scratch. Call `$response->render()` and pass your data.

```twig
<!-- src/templates/hello.html -->
<h1>Hello {{ name }}</h1>
```

```php
<?php
use Tina4\Router;

Router::get("/", function ($request, $response) {
    return $response->render("hello.html", ["name" => "World"]);
});
```

### Sessions {#session-handling}

Sessions start by default in the `Auth` constructor.

### SCSS Stylesheets {#scss-stylesheets}

Drop files in `./src/scss`. The framework compiles them to `./src/public/css`.

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```
[More details](css.md) on CSS and SCSS.

### Environments {#environments}

The default development environment lives in `.env`.

```
[Project Settings]
VERSION=1.0.0
TINA4_DEBUG=true
TINA4_DEBUG_LEVEL=[TINA4_LOG_ALL]
TINA4_CACHE_ON=false
DATABASE_URL=sqlite:///data/app.db
[Open API]
SWAGGER_TITLE=Tina4 Project
SWAGGER_DESCRIPTION=Edit your .env file to change this description
SWAGGER_VERSION=1.0.0
```
Access environment variables through the `$_ENV` superglobal.
```php
$title = $_ENV["SWAGGER_TITLE"];
```

### Authentication {#authentication}

POST, PUT, PATCH, and DELETE routes are secured by default. GET routes stay public unless you mark them otherwise.

```php
<?php
use Tina4\Router;

// @secured marks a GET route as protected
/**
 * @secured
 */
Router::get("/api/profile", function ($request, $response) {
    return $response->json(["user" => $request->user]);
});

// Or use the chainable ->secure() method
Router::get("/api/account", function ($request, $response) {
    return $response->json(["account" => $request->user]);
})->secure();
```

Generate and validate tokens with the `Auth` class.

```php
use Tina4\Auth;

$token = Auth::getToken(["userId" => 1, "role" => "admin"]);
$payload = Auth::validToken($token);
```

### HTML Forms and Tokens {#html-forms-and-tokens}

Form tokens protect POST routes from cross-site forgery. Add one with a Twig filter.
```twig
<form method="POST" action="/process-form">
    {{ "emailForm" | formToken }}
    <input name="email">
    <button>Save</button>
</form>
```
The filter renders a hidden input with a signed JWT.
```html
<form method="POST" action="/process-form">
    <input type="hidden" name="formToken" value="ey...">
    <input name="email">
    <button>Save</button>
</form>
```
[More details](posting-form-data.md) on posting form data, [securing routes](posting-form-data.md#secure-routes), [Tina4 tokens](posting-form-data.md#form-tokens), [uploading files](posting-form-data.md#upload-files), [handling errors](posting-form-data.md#handle-errors), and a [full login example](posting-form-data.md#login-example).

### AJAX and frond.js {#ajax}

Tina4 ships with frond.js -- a small zero-dependency JavaScript library for AJAX calls, form submissions, and real-time WebSocket connections.

[More details](/general/frond) on available features.

### OpenAPI and Swagger UI {#swagger}

Swagger is built in and lives at `/swagger`. The `@description` annotation registers a route in the documentation.

```php
<?php
use Tina4\Router;

/**
 * @description Returns all users
 */
Router::get("/users", function ($request, $response) {
    return $response->json((new User())->select("*"));
});
```
Follow the links for more on [configuration](swagger.md#config), [annotations](swagger.md#annotations), and [usage](swagger.md#usage).

### Databases {#databases}

Set `DATABASE_URL` in `.env`. The framework reads it at startup and opens the connection.

```env
DATABASE_URL=sqlite:///data/app.db
DATABASE_URL=postgres://localhost:5432/myapp
DATABASE_URL=mysql://localhost:3306/myapp
DATABASE_URL=firebird://localhost:3050/path/to/database.fdb
```

Access the connection through the `Database` class.

```php
<?php
use Tina4\Database;

$db = Database::getConnection();
$result = $db->fetch("SELECT * FROM products WHERE price > ?", [50]);
```
Follow the links for more on [available connections](database.md#connections), [core methods](database.md#core-methods), [usage](database.md#usage), [examples](database.md#examples), and [transaction control](database.md#transactions).

### Database Results {#database-results}

Fetch a single row or a paginated set. The database returns a `DatabaseResult` object that converts to arrays or objects.

```php
$db = Database::getConnection();

$row = $db->fetchOne("SELECT * FROM products WHERE id = 1");

// fetch($sql, $params, $noOfRecords, $offset)
$result = $db->fetch("SELECT * FROM products ORDER BY name", [], 10, 0);
```
Dig into the [usage guide](database.md#usage) and [examples](database.md#examples) for deeper coverage.

### Migrations {#migrations}

The CLI manages migrations. Create one, add your SQL, then run it.

```bash
tina4 migrate:create my-first-migration
```

Run all pending migrations in one command.

```bash
tina4 migrate
```

More details on [migrations](migrations.md), their [creation](migrations.md#creation), [running](migrations.md#running) them, and [integration with ORM](migrations.md#orm).

### ORM {#orm}

Once your migrations have created the tables, ORM models map PHP classes to database rows.

```php
<?php
use Tina4\ORM;

class User extends ORM
{
    public string $tableName = "users";
    public string $primaryKey = "id";

    public int $id;
    public string $email;
}

$user = new User(["email" => "alice@example.com"]);
$user->save();
$user = (new User())->load("id = ?", [1]);
```
ORM covers a lot of ground. Study the [full reference](orm.md) to get the most from it.

### CRUD {#crud}

One line of code generates a working CRUD system -- screens, routes, and all.

```php
(new User())->generateCrud("/my-crud-templates");
```
[More details](crud.md) on how CRUD works and where it puts the generated files.

### Consuming REST APIs {#consuming-rest-apis}

Pull data from an external API in a single call.

```php
$api = (new \Tina4\Api("https://api.example.com"))->sendRequest("/my-route", "GET");
```
[More details](rest-api.md) on sending POST bodies, authorization headers, and other controls.

### Inline Testing {#inline-testing}

Tina4 lets you add tests to functions without setting up a test suite.

```php
/**
 * @tests
 * assert(2, 5) == 7, "2+5 not equal 7"
 */
public function addTwoNumbers($number1, $number2)
{
    return $number1 + $number2;
}
```
Run the tests from the CLI.
```bash
tina4 test
```
[Limitations](tests.md) and further reading on the testing system.

### Services {#services}

Create a process class. The service runner picks it up and executes it on schedule.

```php
class MyProcess extends \Tina4\Process
{
    public function canRun(): bool
    {
        return true;
    }

    public function run(): void
    {
        // Your work goes here
    }
}
```
Register the process with the service.
```php
$service = new \Tina4\Service();
$service->addProcess(new MyProcess("Unique Process Name"));
```

[Further reading](services.md) on services. Study them alongside [threads](threads.md) for the full picture.

### Websockets {#websockets}

```php
Router::websocket("/ws/chat/{room}", function ($connection, $event, $data) {
    match ($event) {
        "open" => $connection->send("Welcome to room " . $connection->params["room"]),
        "message" => $connection->broadcast($data),
        "close" => null,
    };
});
```

### Queues {#queues}

Tina4 includes a queue system with multiple backends: LiteQueue (SQLite), MongoDB, RabbitMQ, and Kafka. Install `tina4stack/tina4php-queue` and use a single API for producing and consuming messages.

```php
use Tina4\Queue;

$queue = new Queue(topic: 'my-events');
$queue->produce('Hello World', userId: 'user123');

foreach ($queue->consume() as $message) {
    echo $message->data;
}
```

[More details](queues.md) on queues, their backends, and configuration.

### WSDL {#wsdl}

Define your WSDL service as a class. Tina4 handles the XML, the WSDL generation, and the SOAP envelope.

```php
class Calculator extends \Tina4\WSDL {
    protected array $returnSchemas = [
        "Add" => ["Result" => "int"],
    ];

    public function Add(int $a, int $b): array {
        return ["Result" => $a + $b];
    }
}
```
Wire it to a route.
```php
<?php
use Tina4\Router;

Router::any("/calculator", function ($request, $response) {
    $calculator = new Calculator($request);
    $handle = $calculator->handle();
    return $response->xml($handle);
});
```
[More details](wsdl.md) on WSDL services.

### GraphQL {#graphql}

```php
use Tina4\GraphQL;

\$schema = <<<GQL
type Query {
    hello(name: String!): String
    users: [User]
}

type User {
    id: Int
    name: String
    email: String
}
GQL;

\$resolvers = [
    "hello" => fn(\$args) => "Hello, " . \$args["name"] . "!",
    "users" => fn() => \$db->fetch("SELECT * FROM users")->toArray(),
];

\$graphql = new GraphQL(\$schema, \$resolvers);
```

Register the endpoint:

```php
Router::post("/graphql", function (\$request, \$response) use (\$graphql) {
    \$result = \$graphql->execute(\$request->body["query"] ?? "");
    return \$response->json(\$result);
})->noAuth();
```

GraphiQL UI available at `/__dev/graphql` in debug mode.

### Localization (i18n) {#localization}

Set `TINA4_LOCALE=en` in `.env`. Place JSON files in `src/locales/`:

```json
// src/locales/en.json
{ "greeting": "Hello, {name}!" }
```

```php
$i18n = new I18n();
$i18n->t("greeting", ["name" => "Alice"]);  // "Hello, Alice!"

// Switch locale
$i18n->setLocale("fr");
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">Back to top</a>
</nav>


### HTML Builder {#html-builder}

```php
$el = new HtmlElement("div", ["class" => "card"], ["Hello"]);
echo $el; // <div class="card">Hello</div>

// Nesting
$card = new HtmlElement("div", ["class" => "card"], [
    new HtmlElement("h2", [], ["Title"]),
    new HtmlElement("p", [], ["Content"]),
]);

// Helper functions
extract(HtmlElement::helpers());
echo $_div(["class" => "card"], $_h1("Title"), $_p("Description"));
```

### Events {#events}

Register listeners and fire them anywhere in the application.

```php
use Tina4\Events;

// Register a listener
Events::on("user.registered", function (array $payload): void {
    echo "New user: " . $payload["email"];
});

// Fire once -- listener is removed after first call
Events::once("app.boot", function (): void {
    echo "Booted!";
});

// Emit an event
Events::emit("user.registered", ["email" => "alice@example.com"]);
```

Multiple listeners can bind to the same event. They run in registration order.

### Logging {#logging}

Write log messages through the `Debug` class. The level is controlled by `TINA4_LOG_LEVEL` in `.env`.

```php
use Tina4\Debug;

Debug::message("Starting import", TINA4_LOG_INFO);
Debug::message("Query took 2.3s", TINA4_LOG_WARNING);
Debug::message("Connection failed", TINA4_LOG_ERROR);
```

```env
# .env
TINA4_LOG_LEVEL=TINA4_LOG_ALL    # DEBUG | INFO | WARNING | ERROR | NONE
```

Log output goes to `src/logs/` by default. Set `TINA4_LOG_PATH` to change the destination.

### Response Cache {#response-cache}

Chain `->cache()` onto any route handler to store the response. Subsequent requests within the TTL skip the handler entirely.

```php
use Tina4\Router;

Router::get("/api/products", function ($request, $response) {
    $db = \Tina4\Database::getConnection();
    return $response->json($db->fetch("SELECT * FROM products")->toArray());
})->cache(300); // cache for 300 seconds

// Cache with a custom key
Router::get("/api/report/{year}", function ($request, $response) {
    return $response->json(buildReport($request->params["year"]));
})->cache(3600, "report-" . date("Y"));
```

Set `TINA4_CACHE_ON=true` in `.env` to activate caching globally.

### Health Endpoint {#health}

Tina4 exposes a built-in health check at `/health`. No setup required.

```bash
curl http://localhost:7146/health
```

```json
{
  "status": "ok",
  "uptime": 142,
  "memory_mb": 12.4,
  "php": "8.3.0",
  "tina4": "3.10.20"
}
```

Add custom checks by registering a `health.check` event listener.

```php
use Tina4\Events;

Events::on("health.check", function (array &$report): void {
    $report["db"] = \Tina4\Database::getConnection()->ping() ? "ok" : "fail";
});
```

### DI Container {#container}

Register services once and resolve them anywhere. Singletons share one instance across the request lifecycle.

```php
use Tina4\Container;

// Bind a factory
Container::register("mailer", fn() => new Mailer($_ENV["SMTP_HOST"]));

// Bind a singleton
Container::singleton("db", fn() => \Tina4\Database::getConnection());

// Resolve
$mailer = Container::get("mailer");
$db     = Container::get("db");
```

Route handlers receive resolved dependencies automatically when type-hinted parameter names match registered keys.

### Error Overlay {#error-overlay}

When `TINA4_DEBUG=true`, unhandled exceptions render an interactive overlay in the browser instead of a blank 500 page. The overlay shows the stack trace, request details, and the source file at the point of failure. No configuration needed — it activates automatically.

```env
# .env
TINA4_DEBUG=true
```

In production set `TINA4_DEBUG=false`. Errors log to `src/logs/` and return a plain `500` response.

### Dev Admin {#dev-admin}

Point a browser at `/__dev` while the dev server is running to open the admin dashboard.

```bash
tina4 serve
# open http://localhost:7146/__dev
```

The dashboard surfaces routes, registered middleware, environment variables, recent log entries, active queue workers, and the GraphiQL interface. It is disabled automatically when `TINA4_DEBUG=false`.

### CLI Commands {#cli}

```bash
# Scaffold a new project
tina4 init php my-project

# Start the dev server (default port 7146)
tina4 serve

# Start on a custom port
tina4 serve --port 8080

# Run inline tests
tina4 test

# Create a migration
tina4 migrate:create add-users-table

# Run all pending migrations
tina4 migrate

# Rollback the last migration
tina4 migrate:rollback

# Generate CRUD for a model
tina4 crud User
```

### MCP Server {#mcp}

Tina4 ships an MCP (Model Context Protocol) server that starts automatically when `TINA4_DEBUG=true`. AI assistants connect to it to inspect routes, models, and data without leaving the editor.

```env
# .env
TINA4_DEBUG=true
TINA4_MCP_PORT=7147   # optional override, defaults to main port + 1
```

```bash
# Verify the server is running
curl http://localhost:7147/mcp/manifest
```

The manifest lists every route, ORM model, and migration. Disable it in production by setting `TINA4_DEBUG=false`.

### FakeData {#fakedata}

Generate realistic test data without an internet connection. `FakeData` ships with Tina4 — no extra packages required.

```php
use Tina4\FakeData;

$fake = new FakeData();

echo $fake->name();          // "Alice Johnson"
echo $fake->email();         // "alice.johnson@example.com"
echo $fake->phone();         // "+1-555-0123"
echo $fake->address();       // "42 Maple Street, Springfield"
echo $fake->company();       // "Acme Corp"
echo $fake->lorem(10);       // 10 words of placeholder text
echo $fake->integer(1, 100); // random int between 1 and 100
echo $fake->uuid();          // "f47ac10b-58cc-4372-a567-0e02b2c3d479"

// Seed for reproducible output
$fake = new FakeData(seed: 42);
```

Use `FakeData` inside migrations, seeders, or test fixtures.

</div>
