# Tina4 Python - Quick Reference

::: tip 🔥 Hot Tips

* Routes go in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
* GET routes are public by default; POST/PUT/PATCH/DELETE require a token
* Return a `dict` from `response()` and the framework auto-sets `application/json`
* Use `uv run tina4 start` to launch the dev server on port 7145 :::

[Installation](index.md#installation) • [Static Websites](index.md#static-websites) • [Routing](index.md#basic-routing) • [Middleware](index.md#middleware) • [Templates](index.md#templates) • [Sessions](index.md#session-handling) • [SCSS](index.md#scss-stylesheets) • [Environments](index.md#environments) • [Authentication](index.md#authentication) • [Forms & Tokens](index.md#html-forms-and-tokens) • [AJAX](index.md#ajax) • [OpenAPI](index.md#swagger) • [Databases](index.md#databases) • [Database Results](index.md#database-results) • [Migrations](index.md#migrations) • [ORM](index.md#orm) • [CRUD](index.md#crud) • [REST Client](index.md#consuming-rest-apis) • [Testing](index.md#inline-testing) • [Services](index.md#services) • [Websockets](index.md#websockets) [Threads](index.md#threads) • [Queues](index.md#queues) • [WSDL](index.md#wsdl) • [Localization](index.md#localization)

### Installation <a href="#installation" id="installation"></a>

```bash
pip install tina4-python
tina4 init my-project
cd my-project
tina4 start
```

[More details](installation.md) around project setup and some customizations.

### Static Websites <a href="#static-websites" id="static-websites"></a>

Put `.twig` files in `./src/templates` • assets in `./src/public`

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```

[More details](static-website.md) on static website routing.

### Basic Routing <a href="#basic-routing" id="basic-routing"></a>

```python
from tina4_python.Router import get, post

@get("/")
async def get_home(request, response):
    return response("<h1>Hello Tina4 Python</h1>")

# post requires a formToken in body or Bearer auth
@post("/api")
async def post_api(request, response):
    return response({"data": request.params})

# redirect after post
@post("/register")
async def post_register(request, response):
    return response.redirect("/welcome")
```

Follow the links for [basic routing](basic-routing.md#basic-routing) and [dynamic routing](basic-routing.md#dynamic-routing) with variables.

### Middleware

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
@get("/middleware")
async def get_middleware(request, response):
    return response("Route") # Before[Before / After Something]Route[Before / After Something]After
```

Follow the links for more on [Middleware Declaration](middleware.md#declare) and [Linking to Routes](middleware.md#routes).

### Template Rendering <a href="#templates" id="templates"></a>

Put `.twig` files in `./src/templates` • assets in `./src/public`

```twig
<!-- src/templates/index.twig -->
<h1>Hello {{name}}</h1>
```

```python
from tina4_python.Router import get

@get("/")
async def get_home(request, response):
    return response.render("index.twig", {"name": "World!"})
```

### Sessions <a href="#session-handling" id="session-handling"></a>

The default session handling is SessionFileHandler, override `TINA4_SESSION_HANDLER` in `.env`

| Handler                        | Backend     | Required package |
| ------------------------------ | ----------- | ---------------- |
| `SessionFileHandler` (default) | File system | -                |
| `SessionRedisHandler`          | Redis       | `redis`          |
| `SessionValkeyHandler`         | Valkey      | `valkey`         |
| `SessionMongoHandler`          | MongoDB     | `pymongo`        |

```bash
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
@get("/session/set")
async def get_session_set(request, response):
    request.session.set("name", "Joe")
    request.session.set("info", {"info": ["one", "two", "three"]})
    return response("Session Set!")


@get("/session/get")
async def get_session_set(request, response):
    name = request.session.get("name")
    info = request.session.get("info")

    return response({"name": name, "info": info})

```

### SCSS Stylesheets <a href="#scss-stylesheets" id="scss-stylesheets"></a>

Drop in `./src/scss` → auto-compiled to `./src/public/css`

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```

[More details](css.md) on css and scss.

### Environments <a href="#environments" id="environments"></a>

Default development environment can be found in `.env`

```
PROJECT_NAME="My Project"
VERSION=1.0.0
TINA4_LOCALE=en
TINA4_DEBUG_LEVEL=ALL
TINA4_API_KEY=ABC1234
TINA4_TOKEN_LIMIT=1
DATABASE_NAME=sqlite3:test.db
```

```python
import os

api_key = os.getenv("TINA4_API_KEY", "ABC1234")
```

### Authentication <a href="#authentication" id="authentication"></a>

Pass `Authorization: Bearer TINA4_API_KEY` to secured routes in requests. See `.env` for default `TINA4_API_KEY`.

```python
from tina4_python.Router import get, post, noauth, secured

@post("/login")
@noauth()
async def login(request, response):
    return response("Logged in")

@get("/protected")
@secured()
async def secret(request, response):
    return response("Welcome!")
```

### HTML Forms and Tokens <a href="#html-forms-and-tokens" id="html-forms-and-tokens"></a>

```twig
<form method="POST" action="/register">
    {{ ("Register" ~ RANDOM()) | form_token }}
    <input name="email">
    <button>Save</button>
</form>
```

[More details](posting-form-data.md) on posting form data, [basic form handling](https://github.com/tina4stack/tina4-documentation/blob/main/docs/v2/python/posting-form-data/README.md#basic-forms), how to [generate form tokens](https://github.com/tina4stack/tina4-documentation/blob/main/docs/v2/python/posting-form-data/README.md#form-tokens), dealing with [file uploads](https://github.com/tina4stack/tina4-documentation/blob/main/docs/v2/python/posting-form-data/README.md#file-uploads), [returning errors](https://github.com/tina4stack/tina4-documentation/blob/main/docs/v2/python/posting-form-data/README.md#error-handling), [disabling route auth](https://github.com/tina4stack/tina4-documentation/blob/main/docs/v2/python/posting-form-data/README.md#disabling-auth) and a [full login example](https://github.com/tina4stack/tina4-documentation/blob/main/docs/v2/python/posting-form-data/README.md#full-example).

### AJAX and tina4helper.js <a href="#ajax" id="ajax"></a>

Tina4 ships with a small javascript library, in the bin folder, to assist with the heavy lifting of ajax calls.

[More details](tina4helper.md) on available features.

### OpenAPI and Swagger UI <a href="#swagger" id="swagger"></a>

Visit `http://localhost:7145/swagger`

```python
from tina4_python.Router import get
from tina4_python import description

@get("/users")
@description("Get all users")
async def users(request, response):
    return response(User().select("*"))
```

Follow the links for more on [Configuration](swagger.md#config), [Usage](swagger.md#usage) and [Decorators](swagger.md#decorators).

### Databases <a href="#databases" id="databases"></a>

```python
from tina4_python.Database import Database

# dba = Database("<driver>:<hostname>/<port>:database_name", username, password)
dba = Database("sqlite3:data.db") 
```

Follow the links for more on [Available Connections](database.md#connections), [Core Methods](database.md#core-methods), [Usage](database.md#usage) and [Full transaction control](database.md#transactions).

### Database Results <a href="#database-results" id="database-results"></a>

```python
result = dba.fetch("select * from test_record order by id", limit=3, skip=1)

array = result.to_array()
paginated = result.to_paginate()
csv_data = result.to_csv()
json_data = result.to_json()
```

Looking at detailed [Usage](database.md#usage) will improve deeper understanding.

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

[Migrations](migrations.md) do have some limitations and considerations when used extensively.

### ORM <a href="#orm" id="orm"></a>

```python
from tina4_python.ORM import ORM, IntegerField, StringField

class User(ORM):
    id   = IntegerField(primary_key=True, auto_increment=True)
    name = StringField()

User({"name": "Alice"}).save()

user = User()
user.load("id = ?", [1])
```

ORM functionality is quite extensive and needs more study of the [Advanced Detail](orm.md) to get the full value from ORM.

### CRUD <a href="#crud" id="crud"></a>

```python
@get("/users/dashboard")
async def dashboard(request, response):
    users = User().select("id, name, email")
    return response.render("users/dashboard.twig", {"crud": users.to_crud(request)})
```

```twig
{{ crud }}
```

[More details](crud.md) on how CRUD works, where it puts the generated files is worth some investigation.

### Consuming REST APIs <a href="#consuming-rest-apis" id="consuming-rest-apis"></a>

```python
from tina4_python import Api

api = Api("https://api.example.com", auth_header="Bearer xyz")
result = api.get("/users/42")
print(result["body"])
```

[More details](rest-api.md) are available on sending a post data body, authorizations and other finer controls of sending api requests.

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

Due to the nature of python, services are not necessary.

### Websockets <a href="#websockets" id="websockets"></a>

Requires `simple-websocket`, add with `uv add simple-websocket`

```python
from tina4_python.Websocket import Websocket

@get("/ws/chat")
async def chat_ws(request, response):
    ws = await Websocket(request).connection()
    try:
        while True:
            data = await ws.receive()
            await ws.send(f"Echo: {data}")
    finally:
        await ws.close()
    return response("")
```

Have a look at out PubSub example under [Websockets](websockets.md)

### Threads <a href="#threads" id="threads"></a>

Due to the nature of python, threads are not necessary.

### Queues <a href="#queues" id="queues"></a>

Supports litequeue (default/SQLite), RabbitMQ, Kafka, and MongoDB backends.

```python
from tina4_python.Queue import Queue, Producer, Consumer

# Produce a message
queue = Queue(topic="emails")
Producer(queue).produce({"to": "alice@example.com", "subject": "Welcome"})

# Consume messages
consumer = Consumer(queue)
for msg in consumer.messages():
    print(msg.data)
```

[Full details](queues.md) on backend configuration, batching, multi-queue consumers, and error handling.

### WSDL <a href="#wsdl" id="wsdl"></a>

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

[More Details](wsdl.md) are available for WSDL

### Localization (i18n) <a href="#localization" id="localization"></a>

Set `TINA4_LOCALE` in `.env` to change framework language. Supported: `en`, `fr`, `af`.

```python
from tina4_python.Localization import localize

_ = localize()
print(_("Server stopped."))  # "Bediener gestop." (af)
```

Translations use Python's `gettext` module. Falls back to English for unsupported languages.

```python
from tina4_python.Localization import AVAILABLE_LANGUAGES
# ['en', 'fr', 'af']
```

[↑ Back to top](index.md)
