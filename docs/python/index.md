# Tina4 Python - Quick Reference

::: tip 🔥 Hot Tips

* Routes go in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
* GET routes are public by default; POST/PUT/PATCH/DELETE require a token
* Return a `dict` from `response()` and the framework sets `application/json`
* Run `tina4 serve` to start the dev server on port 7146
:::

[Installation](index.md#installation) • [Static Websites](index.md#static-websites) • [Routing](index.md#basic-routing) • [Middleware](index.md#middleware) • [Templates](index.md#templates) • [Sessions](index.md#session-handling) • [SCSS](index.md#scss-stylesheets) • [Environments](index.md#environments) • [Authentication](index.md#authentication) • [Forms & Tokens](index.md#html-forms-and-tokens) • [AJAX](index.md#ajax) • [OpenAPI](index.md#swagger) • [Databases](index.md#databases) • [Database Results](index.md#database-results) • [Migrations](index.md#migrations) • [ORM](index.md#orm) • [CRUD](index.md#crud) • [REST Client](index.md#consuming-rest-apis) • [Testing](index.md#inline-testing) • [Services](index.md#services) • [Websockets](index.md#websockets) • [Queues](index.md#queues) • [WSDL](index.md#wsdl) • [GraphQL](index.md#graphql) • [Localization](index.md#localization) • [HTML Builder](index.md#html-builder) • [Events](index.md#events) • [Logging](index.md#logging) • [Cache](index.md#response-cache) • [Health](index.md#health) • [DI Container](index.md#container) • [Error Overlay](index.md#error-overlay) • [Dev Admin](index.md#dev-admin) • [CLI](index.md#cli) • [MCP](index.md#mcp) • [FakeData](index.md#fakedata)

### Installation <a href="#installation" id="installation"></a>

```bash
# Install the tina4 CLI once. Windows: irm https://tina4.com/install.ps1 | iex
curl -fsSL https://tina4.com/install.sh | sh

tina4 init python my-app
cd my-app
tina4 serve
```

The CLI scaffolds your project, installs the dependencies, and starts the server. No dependency tree. No version conflicts. Your browser opens to `http://localhost:7146` and the welcome page greets you.

[More details](01-getting-started.md) on project setup and customization.

### Static Websites <a href="#static-websites" id="static-websites"></a>

Put `.twig` files in `./src/templates` and assets in `./src/public`. The framework serves them without additional configuration.

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```

[More details](04-templates.md) on static website routing.

### Basic Routing <a href="#basic-routing" id="basic-routing"></a>

Import the route decorators from `tina4_python`. Each handler receives `request` and `response`. Path parameters arrive as function arguments.

```python
from tina4_python import get, post

@get("/")
async def get_home(request, response):
    return response("<h1>Hello Tina4 Python</h1>")

# POST requires a formToken in the body or Bearer auth
@post("/api")
async def post_api(request, response):
    return response({"data": request.body})

# Redirect after a POST
@post("/register")
async def post_register(request, response):
    return response.redirect("/welcome")
```

Follow the links for [basic routing](02-routing.md) and [dynamic routing](02-routing.md) with variables.

### Middleware

Middleware runs before and after your route handler. Define a class with static methods, then attach it with the `@middleware` decorator.

```python
from tina4_python import get, middleware

class RunSomething:

    @staticmethod
    def before_something(request, response):
        response.content += "Before"
        return request, response

    @staticmethod
    def after_something(request, response):
        response.content += "After"
        return request, response

    @staticmethod
    def before_and_after_something(request, response):
        response.content += "[Before / After Something]"
        return request, response

@middleware(RunSomething)
@get("/middleware")
async def get_middleware(request, response):
    return response("Route") # Before[Before / After Something]Route[Before / After Something]After
```

Follow the links for more on [Middleware Declaration](10-middleware-security.md) and [Linking to Routes](10-middleware-security.md#routes).

### Template Rendering <a href="#templates" id="templates"></a>

Put `.twig` files in `./src/templates` and assets in `./src/public`. The template engine reads your layout, fills in the variables, and delivers clean HTML.

```twig
<!-- src/templates/index.twig -->
<h1>Hello {{name}}</h1>
```

```python
from tina4_python import get

@get("/")
async def get_home(request, response):
    return response.render("index.twig", {"name": "World!"})
```

### Sessions <a href="#session-handling" id="session-handling"></a>

The default session handler stores data on the file system. Override `TINA4_SESSION_BACKEND` in `.env` to switch backends.

| Handler                        | Backend     | Required package |
| ------------------------------ | ----------- | ---------------- |
| `SessionFileHandler` (default) | File system | --               |
| `SessionRedisHandler`          | Redis       | `redis`          |
| `SessionValkeyHandler`         | Valkey      | `valkey`         |
| `SessionMongoHandler`          | MongoDB     | `pymongo`        |

```bash
TINA4_SESSION_BACKEND=SessionMongoHandler
TINA4_SESSION_MONGO_HOST=localhost
TINA4_SESSION_MONGO_PORT=27017
TINA4_SESSION_MONGO_URI=
TINA4_SESSION_MONGO_USERNAME=
TINA4_SESSION_MONGO_PASSWORD=
TINA4_SESSION_MONGO_DB=tina4_sessions
TINA4_SESSION_MONGO_COLLECTION=sessions
```

```python
from tina4_python import get

@get("/session/set")
async def get_session_set(request, response):
    request.session.set("name", "Joe")
    request.session.set("info", {"info": ["one", "two", "three"]})
    return response("Session Set!")


@get("/session/get")
async def get_session_get(request, response):
    name = request.session.get("name")
    info = request.session.get("info")
    return response({"name": name, "info": info})


@get("/session/clear")
async def get_session_clear(request, response):
    request.session.delete("name")
    return response("Session key removed!")
```

### SCSS Stylesheets <a href="#scss-stylesheets" id="scss-stylesheets"></a>

Drop `.scss` files in `./src/scss`. The framework compiles them to `./src/public/css`.

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```

[More details](17-frontend.md) on css and scss.

### Environments <a href="#environments" id="environments"></a>

The `.env` file holds your project configuration. The framework reads it at startup.

```
TINA4_DEBUG=true
TINA4_PORT=7145
TINA4_DATABASE_URL=sqlite:///data/app.db
TINA4_LOG_LEVEL=ALL
TINA4_API_KEY=ABC1234
```

```python
import os

api_key = os.getenv("TINA4_API_KEY", "ABC1234")
```

Access env vars programmatically:

```python
from tina4_python.dotenv import load_env, get_env, has_env, require_env, is_truthy

load_env()                          # Load .env file (auto on server start)
get_env("TINA4_DATABASE_URL")             # Get value or None
get_env("PORT", "7145")             # Get value with default
has_env("TINA4_DEBUG")              # True if set
require_env("TINA4_DATABASE_URL")         # Raises if missing
is_truthy(get_env("TINA4_DEBUG"))   # True for "true", "1", "yes"
```

### Authentication <a href="#authentication" id="authentication"></a>

POST, PUT, PATCH, and DELETE routes require a Bearer token by default. Pass `Authorization: Bearer TINA4_API_KEY` in the request header. Use `@noauth()` to open a route to everyone. Use `@secured()` to lock a GET route behind authentication.

```python
from tina4_python import get, post, noauth, secured
from tina4_python.auth import Auth

@post("/login")
@noauth()
async def login(request, response):
    token = Auth.get_token({"user_id": 1, "role": "admin"})
    return response({"token": token})

@get("/protected")
@secured()
async def secret(request, response):
    return response("Welcome!")

@get("/verify")
async def verify(request, response):
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    payload = Auth.valid_token(token)
    return response({"valid": payload is not None})
```

### HTML Forms and Tokens <a href="#html-forms-and-tokens" id="html-forms-and-tokens"></a>

```twig
<form method="POST" action="/register">
    {{ ("Register" ~ RANDOM()) | form_token }}
    <input name="email">
    <button>Save</button>
</form>
```

[More details](03-request-response.md) on posting form data, [basic form handling](03-request-response.md), how to [generate form tokens](03-request-response.md), dealing with [file uploads](03-request-response.md), [returning errors](03-request-response.md), [disabling route auth](03-request-response.md) and a [full login example](03-request-response.md).

### AJAX and frond.js <a href="#ajax" id="ajax"></a>

Tina4 ships with frond.js, a small zero-dependency JavaScript library for AJAX calls, form submissions, and real-time WebSocket connections.

[More details](https://github.com/tina4stack/tina4-documentation/blob/main/general/frond.md) on available features.

### OpenAPI and Swagger UI <a href="#swagger" id="swagger"></a>

Visit `http://localhost:7145/swagger`. Decorated routes appear in the Swagger UI without manual annotation.

```python
from tina4_python import get
from tina4_python.swagger import description

@get("/users")
@description("Get all users")
async def users(request, response):
    return response(User().select("*"))
```

Follow the links for more on [Configuration](20-swagger.md), [Usage](20-swagger.md) and [Decorators](20-swagger.md).

### Databases <a href="#databases" id="databases"></a>

```python
from tina4_python.database import Database

# dba = Database("<driver>:<hostname>/<port>:database_name", username, password)
dba = Database("sqlite3:data.db")
```

The adapter speaks PostgreSQL, MySQL, and SQLite. It translates your queries into whichever dialect the database understands.

Follow the links for more on [Available Connections](05-database.md), [Core Methods](05-database.md), [Usage](05-database.md) and [Full transaction control](05-database.md).

### Database Results <a href="#database-results" id="database-results"></a>

```python
result = dba.fetch("select * from test_record order by id", limit=3, offset=1)

array = result.to_array()
paginated = result.to_paginate()
csv_data = result.to_csv()
json_data = result.to_json()
```

Looking at detailed [Usage](05-database.md) will deepen your understanding.

### Migrations <a href="#migrations" id="migrations"></a>

```bash
tina4 migrate:create create_users_table
```

```sql
-- migrations/00001_create_users_table.sql
CREATE TABLE users
(
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
);
```

```bash
tina4 migrate
```

[Migrations](05-database.md) have limitations worth knowing before you use them at scale.

### ORM <a href="#orm" id="orm"></a>

```python
from tina4_python.orm import ORM, IntegerField, StringField

class User(ORM):
    id   = IntegerField(primary_key=True, auto_increment=True)
    name = StringField()

User({"name": "Alice"}).save()

user = User()
user.load("id = ?", [1])
```

ORM covers more ground than this snippet shows. Study the [Advanced Detail](06-orm.md) to get the full value.

### CRUD <a href="#crud" id="crud"></a>

```python
from tina4_python import get

@get("/users/dashboard")
async def dashboard(request, response):
    users = User().select("id, name, email")
    return response.render("users/dashboard.twig", {"crud": users.to_crud(request)})
```

```twig
{{ crud }}
```

[More details](19-scaffolding.md) on how CRUD generates its files and where they live.

### Consuming REST APIs <a href="#consuming-rest-apis" id="consuming-rest-apis"></a>

```python
from tina4_python import Api

api = Api("https://api.example.com", auth_header="Bearer xyz")
result = api.get("/users/42")
print(result["body"])
```

[More details](21-api-client.md) on sending POST data, authorization headers, and other controls for outbound API requests.

### Inline Testing <a href="#inline-testing" id="inline-testing"></a>

```python
from tina4_python import tests

@tests(
    assert_equal((7, 7), 1),
    assert_equal((-1, 1), -1),
    assert_raises(ZeroDivisionError, (5, 0)),
)
def divide(a: int, b: int) -> float:
    if b == 0:
        raise ZeroDivisionError("division by zero")
    return a / b
```

Run: `tina4 test`

### Services <a href="#services" id="services"></a>

Due to the nature of Python, services are not necessary.

### Websockets <a href="#websockets" id="websockets"></a>

WebSocket support is built in. No extra dependencies. Define a handler with the `@websocket` decorator, and the framework manages the connection alongside your HTTP routes on the same port.

```python
from tina4_python import websocket

@websocket("/ws/chat")
async def chat_ws(connection, event, data):
    if event == "message":
        await connection.send(f"Echo: {data}")
```

Have a look at the PubSub example under [Websockets](23-websocket.md).

### Queues <a href="#queues" id="queues"></a>

Supports litequeue (default/SQLite), RabbitMQ, Kafka, and MongoDB backends. The queue system uses `produce()` and `consume()` directly, with no separate Producer or Consumer classes.

```python
from tina4_python.queue import Queue

# Produce a message
queue = Queue(topic="emails")
queue.produce("emails", {"to": "alice@example.com", "subject": "Welcome"})

# Consume messages
for job in queue.consume("emails"):
    print(job.payload)
```

[Full details](12-queues.md) on backend configuration, batching, multi-queue consumers, and error handling.

### WSDL <a href="#wsdl" id="wsdl"></a>

Subclass `WSDL` and decorate each operation with `@wsdl_operation`, giving the return shape. Drop the file in `src/routes/` and the framework serves the SOAP endpoint plus its generated WSDL.

```python
from typing import List
from tina4_python.wsdl import WSDL, wsdl_operation


class Calculator(WSDL):

    @wsdl_operation({"Result": int})
    def Add(self, a: int, b: int):
        return {"Result": a + b}

    @wsdl_operation({"Numbers": List[int], "Total": int})
    def SumList(self, Numbers: List[int]):
        return {"Numbers": Numbers, "Total": sum(Numbers)}
```

[More Details](25-wsdl-soap.md) on WSDL configuration and usage.

### GraphQL <a href="#graphql" id="graphql"></a>

```python
from tina4_python.graphql import GraphQL

schema = """
type Query {
    hello(name: String!): String
    users: [User]
}

type User {
    id: Int
    name: String
    email: String
}
"""

resolvers = {
    "hello": lambda info, name: f"Hello, {name}!",
    "users": lambda info: db.fetch("SELECT * FROM users").records,
}

graphql = GraphQL(schema, resolvers)
```

Register the endpoint:

```python
from tina4_python import post, noauth

@post("/graphql")
@noauth()
async def handle_graphql(request, response):
    result = graphql.execute(request.body.get("query", ""))
    return response(result)
```

GraphiQL UI available at `/__dev/graphql` in debug mode.

### Localization (i18n) <a href="#localization" id="localization"></a>

Translation files live in `src/locales/` as JSON. Create an `I18n` instance with a locale directory and a default locale, switch languages at runtime, and translate keys with `t()`.

```python
from tina4_python.i18n import I18n

i18n = I18n(locale_dir="src/locales", default_locale="en")

i18n.set_locale("af")          # switch language
i18n.t("welcome_message")      # translated string for the active locale
i18n.t("greeting", name="Ada") # with interpolation
```

Missing keys fall back to the default locale.

[Back to top](index.md)

### HTML Builder <a href="#html-builder" id="html-builder"></a>

```python
from tina4_python.HtmlElement import HTMLElement, add_html_helpers

el = HTMLElement("div", {"class": "card"}, ["Hello"])
str(el)  # <div class="card">Hello</div>

# Nesting
page = HTMLElement("div")(
    HTMLElement("h1")("Title"),
    HTMLElement("p")("Content"),
)

# Helper functions
add_html_helpers(globals())
html = _div({"class": "card"},
    _h1("Title"),
    _p("Description"),
    _a({"href": "/more"}, "Read more"),
)
```

### Events <a href="#events" id="events"></a>

```python
from tina4_python.core.events import on, emit, once, off

@on("user.created")
def send_welcome(user):
    print(f"Welcome {user['name']}!")

@once("app.ready")
def on_ready():
    print("Started!")

emit("user.created", {"name": "Alice"})
```

### Logging <a href="#logging" id="logging"></a>

```python
from tina4_python.debug import Log

Log.info("Server started")
Log.debug("Request received", path="/api/users")
Log.warning("Slow query", duration_ms=450)
Log.error("Connection failed", host="db.example.com")
```

Set `TINA4_LOG_LEVEL` in `.env`: `ALL`, `DEBUG`, `INFO`, `WARNING`, `ERROR`.

### Response Cache <a href="#response-cache" id="response-cache"></a>

```python
from tina4_python.core.router import get, cached

@cached(max_age=120)
@get("/api/products")
async def products(request, response):
    return response(expensive_query())
```

### Health Endpoint <a href="#health" id="health"></a>

Built-in at `/health`. Returns `{"status": "ok", "uptime": 123.4}`. Configure with `TINA4_HEALTH_PATH` env var.

### DI Container <a href="#container" id="container"></a>

```python
from tina4_python.container import Container

container = Container()
container.singleton("db", lambda: Database("sqlite:///app.db"))
container.register("mailer", lambda: MailService())
db = container.get("db")
```

### Error Overlay <a href="#error-overlay" id="error-overlay"></a>

Automatic in debug mode. Shows syntax-highlighted stack trace with source context. Set `TINA4_DEBUG=true` in `.env`.

### Dev Admin <a href="#dev-admin" id="dev-admin"></a>

Available at `/__dev` in debug mode. Includes route inspector, database tab, request capture, metrics bubble chart, gallery examples, dev mailbox.

### CLI Commands <a href="#cli" id="cli"></a>

```bash
tina4 init python my-app    # Scaffold project
tina4 serve                  # Start dev server
tina4 serve --production     # Production mode
tina4 doctor                 # Check environment
tina4 env                    # Configure .env
tina4 docs                   # Download documentation
tina4 generate model User    # Generate scaffolding
tina4 migrate                # Run migrations
tina4 test                   # Run tests
tina4 ai                     # Install AI context
```

### MCP Server <a href="#mcp" id="mcp"></a>

Auto-starts on `/__mcp` in debug mode. Exposes 24 dev tools via JSON-RPC 2.0 over SSE. Works with Claude Code, Cursor, and other MCP clients.

### FakeData <a href="#fakedata" id="fakedata"></a>

```python
from tina4_python.seeder import FakeData

fake = FakeData()
fake.name()      # "Alice Johnson"
fake.email()     # "alice@example.com"
fake.phone()     # "+1-555-0123"
fake.sentence()  # "The quick brown fox..."
fake.integer()   # 4821
```

***

## 📕 Download the book

[**Tina4 for Python Developers** (PDF)](/pdfs/Tina4-for-Python-Developers.pdf): full reference, printable, with clickable table of contents and PDF outline. Regenerated with every release.
