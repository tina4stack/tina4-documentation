# Tina4 Python -- Quick Reference

<div v-pre>


::: tip Hot Tips
- Routes go in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
- GET routes are public by default; POST/PUT/PATCH/DELETE require a token
- Return a `dict` from `response()` and the framework sets `application/json`
- Run `tina4 serve` to start the dev server on port 7145
  :::

<nav class="tina4-menu">
    <a href="#installation">Installation</a> •
    <a href="#static-websites">Static Websites</a> •
    <a href="#basic-routing">Routing</a> •
    <a href="#middleware">Middleware</a> •
    <a href="#templates">Templates</a> •
    <a href="#session-handling">Sessions</a> •
    <a href="#scss-stylesheets">SCSS</a> •
    <a href="#environments">Environments</a> •
    <a href="#authentication">Authentication</a> •
    <a href="#html-forms-and-tokens">Forms & Tokens</a> •
    <a href="#ajax">AJAX</a> •
    <a href="#swagger">OpenAPI</a> •
    <a href="#databases">Databases</a> •
    <a href="#database-results">Database Results</a> •
    <a href="#migrations">Migrations</a> •
    <a href="#orm">ORM</a> •
    <a href="#crud">CRUD</a> •
    <a href="#consuming-rest-apis">REST Client</a> •
    <a href="#inline-testing">Testing</a> •
    <a href="#services">Services</a> •
    <a href="#websockets">Websockets</a>
    <a href="#threads">Threads</a> •
    <a href="#queues">Queues</a> •
    <a href="#wsdl">WSDL</a> •
    <a href="#localization">Localization</a>

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
pip install tina4-python
tina4 init my-project
cd my-project
tina4 serve
```

The CLI scaffolds your project, installs one package, and starts the server. No dependency tree. No version conflicts. Your browser opens to `http://localhost:7145` and the welcome page greets you.

[More details](installation.md) on project setup and customization.

### Static Websites {#static-websites}

Put `.twig` files in `./src/templates` and assets in `./src/public`. The framework serves them without additional configuration.

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```
[More details](static-website.md) on static website routing.

### Basic Routing {#basic-routing}

The `@app` decorators register routes. Each handler receives `request` and `response`. Path parameters arrive as function arguments.

```python
@app.get("/")
async def get_home(request, response):
    return response("<h1>Hello Tina4 Python</h1>")

# POST requires a formToken in the body or Bearer auth
@app.post("/api")
async def post_api(request, response):
    return response({"data": request.body})

# Redirect after a POST
@app.post("/register")
async def post_register(request, response):
    return response.redirect("/welcome")
```
Follow the links for [basic routing](basic-routing.md#basic-routing) and [dynamic routing](basic-routing.md#dynamic-routing) with variables.

### Middleware

Middleware runs before and after your route handler. Define a class with static methods, then attach it with the `@middleware` decorator.

```python
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
@app.get("/middleware")
async def get_middleware(request, response):
    return response("Route") # Before[Before / After Something]Route[Before / After Something]After
```
Follow the links for more on [Middleware Declaration](middleware.md#declare) and [Linking to Routes](middleware.md#routes).

### Template Rendering {#templates}

Put `.twig` files in `./src/templates` and assets in `./src/public`. The template engine reads your layout, fills in the variables, and delivers clean HTML.

```twig
<!-- src/templates/index.twig -->
<h1>Hello {{name}}</h1>
```

```python
@app.get("/")
async def get_home(request, response):
    return response.render("index.twig", {"name": "World!"})
```

### Sessions {#session-handling}

The default session handler stores data on the file system. Override `TINA4_SESSION_HANDLER` in `.env` to switch backends.

| Handler | Backend | Required package |
|---------|---------|-----------------|
| `SessionFileHandler` (default) | File system | -- |
| `SessionRedisHandler` | Redis | `redis` |
| `SessionValkeyHandler` | Valkey | `valkey` |
| `SessionMongoHandler` | MongoDB | `pymongo` |

```dotenv
TINA4_SESSION_HANDLER=SessionMongoHandler
TINA4_SESSION_MONGO_HOST=localhost
TINA4_SESSION_MONGO_PORT=27017
TINA4_SESSION_MONGO_URI=
TINA4_SESSION_MONGO_USERNAME=
TINA4_SESSION_MONGO_PASSWORD=
TINA4_SESSION_MONGO_DB=tina4_sessions
TINA4_SESSION_MONGO_COLLECTION=sessions
```

```python
@app.get("/session/set")
async def get_session_set(request, response):
    request.session.set("name", "Joe")
    request.session.set("info", {"info": ["one", "two", "three"]})
    return response("Session Set!")


@app.get("/session/get")
async def get_session_get(request, response):
    name = request.session.get("name")
    info = request.session.get("info")
    return response({"name": name, "info": info})


@app.get("/session/clear")
async def get_session_clear(request, response):
    request.session.delete("name")
    return response("Session key removed!")
```

### SCSS Stylesheets {#scss-stylesheets}

Drop `.scss` files in `./src/scss`. The framework compiles them to `./src/public/css`.

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```
[More details](css.md) on css and scss.

### Environments {#environments}

The `.env` file holds your project configuration. The framework reads it at startup.

```
TINA4_DEBUG=true
TINA4_PORT=7145
DATABASE_URL=sqlite:///data/app.db
TINA4_LOG_LEVEL=ALL
API_KEY=ABC1234
```

```python
import os

api_key = os.getenv("API_KEY", "ABC1234")
```

### Authentication {#authentication}

POST, PUT, PATCH, and DELETE routes require a Bearer token by default. Pass `Authorization: Bearer API_KEY` in the request header. Use `@noauth` to open a route to everyone. Use `@secured` to lock a GET route behind authentication.

```python
from tina4_python.Auth import Auth

@app.post("/login")
@noauth
async def login(request, response):
    token = Auth.get_token({"user_id": 1, "role": "admin"})
    return response({"token": token})

@app.get("/protected")
@secured
async def secret(request, response):
    return response("Welcome!")

@app.get("/verify")
async def verify(request, response):
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    payload = Auth.valid_token(token)
    return response({"valid": payload is not None})
```

### HTML Forms and Tokens {#html-forms-and-tokens}

```twig
<form method="POST" action="/register">
    {{ ("Register" ~ RANDOM()) | form_token }}
    <input name="email">
    <button>Save</button>
</form>
```
[More details](posting-form-data.md) on posting form data, [basic form handling](posting-form-data#basic-forms), how to [generate form tokens](posting-form-data#form-tokens),
dealing with [file uploads](posting-form-data#file-uploads), [returning errors](posting-form-data#error-handling), [disabling route auth](posting-form-data#disabling-auth)
and a [full login example](posting-form-data#full-example).

### AJAX and frond.js {#ajax}

Tina4 ships with frond.js, a small zero-dependency JavaScript library for AJAX calls, form submissions, and real-time WebSocket connections.

[More details](/general/frond) on available features.

### OpenAPI and Swagger UI {#swagger}

Visit `http://localhost:7145/swagger`. Decorated routes appear in the Swagger UI without manual annotation.

```python
from tina4_python import description

@app.get("/users")
@description("Get all users")
async def users(request, response):
    return response(User().select("*"))
```
Follow the links for more on [Configuration](swagger.md#config), [Usage](swagger.md#usage) and [Decorators](swagger.md#decorators).

### Databases {#databases}

```python
from tina4_python.Database import Database

# dba = Database("<driver>:<hostname>/<port>:database_name", username, password)
dba = Database("sqlite3:data.db")
```
The adapter speaks PostgreSQL, MySQL, and SQLite. It translates your queries into whichever dialect the database understands.

Follow the links for more on [Available Connections](database.md#connections), [Core Methods](database.md#core-methods), [Usage](database.md#usage) and [Full transaction control](database.md#transactions).

### Database Results {#database-results}

```python
result = dba.fetch("select * from test_record order by id", limit=3, offset=1)

array = result.to_array()
paginated = result.to_paginate()
csv_data = result.to_csv()
json_data = result.to_json()
```
Looking at detailed [Usage](database.md#usage) will deepen your understanding.

### Migrations {#migrations}

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
[Migrations](migrations.md) have limitations worth knowing before you use them at scale.

### ORM {#orm}

```python
from tina4_python.ORM import ORM, IntegerField, StringField

class User(ORM):
    id   = IntegerField(primary_key=True, auto_increment=True)
    name = StringField()

User({"name": "Alice"}).save()

user = User()
user.load("id = ?", [1])
```
ORM covers more ground than this snippet shows. Study the [Advanced Detail](orm.md) to get the full value.

### CRUD {#crud}

```python
@app.get("/users/dashboard")
async def dashboard(request, response):
    users = User().select("id, name, email")
    return response.render("users/dashboard.twig", {"crud": users.to_crud(request)})
```

```twig
{{ crud }}
```
[More details](crud.md) on how CRUD generates its files and where they live.

### Consuming REST APIs {#consuming-rest-apis}

```python
from tina4_python import Api

api = Api("https://api.example.com", auth_header="Bearer xyz")
result = api.get("/users/42")
print(result["body"])
```
[More details](rest-api.md) on sending POST data, authorization headers, and other controls for outbound API requests.

### Inline Testing {#inline-testing}

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

### Services {#services}

Due to the nature of Python, services are not necessary.

### Websockets {#websockets}

WebSocket support is built in. No extra dependencies. Define a handler with the `@app.websocket` decorator, and the framework manages the connection alongside your HTTP routes on the same port.

```python
@app.websocket("/ws/chat")
async def chat_ws(connection, event, data):
    if event == "message":
        await connection.send(f"Echo: {data}")
```
Have a look at the PubSub example under [Websockets](websockets.md).

### Queues {#queues}

Supports litequeue (default/SQLite), RabbitMQ, Kafka, and MongoDB backends. The queue system uses `produce()` and `consume()` directly -- no separate Producer or Consumer classes.

```python
from tina4_python.Queue import Queue

# Produce a message
queue = Queue(topic="emails")
queue.produce("emails", {"to": "alice@example.com", "subject": "Welcome"})

# Consume messages
for job in queue.consume("emails"):
    print(job.payload)
```

[Full details](queues.md) on backend configuration, batching, multi-queue consumers, and error handling.

### WSDL {#wsdl}

```python
from tina4_python.WSDL import WSDL, wsdl_operation
from typing import List


class Calculator(WSDL):
    SERVICE_URL = "http://localhost:7145/calculator"

    def Add(self, a: int, b: int):
        return {"Result": a + b}

    def SumList(self, Numbers: List[int]):
        return {
            "Numbers": Numbers,
            "Total": sum(Numbers),
            "Error": None
        }


@wsdl("/calculator")
async def wsdl_cis(request, response):
    return response.wsdl(Calculator(request))

```
[More Details](wsdl.md) on WSDL configuration and usage.

### GraphQL {#graphql}

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
@post("/graphql")
@noauth()
async def handle_graphql(request, response):
    result = graphql.execute(request.body.get("query", ""))
    return response(result)
```

GraphiQL UI available at `/__dev/graphql` in debug mode.

### Localization (i18n) {#localization}

Set `TINA4_LANGUAGE` in `.env` to change the framework language. Supported: `en`, `fr`, `af`.

```python
from tina4_python.Localization import localize

_ = localize()
print(_("Server stopped."))  # "Bediener gestop." (af)
```

Translations use Python's `gettext` module. The framework falls back to English for unsupported languages.

```python
from tina4_python.Localization import AVAILABLE_LANGUAGES
# ['en', 'fr', 'af']
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">Back to top</a>
</nav>

</div>
