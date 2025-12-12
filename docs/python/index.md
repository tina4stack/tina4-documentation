# Tina4 Python – Quick Reference

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
    <a href="#inline-testing">Testing</a> •
    <a href="#wsdl">WSDL</a> •
    <a href="#consuming-rest-apis">REST Client</a>
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
tina4 start
```

### Static Websites {#static-websites}
<!-- tina4php also allows .html perhaps consider for tina4python -->
Put `.twig` files in `./src/templates` • assets in `./src/public`

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```

### Basic Routing {#basic-routing}

```python
from tina4_python import get, post

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

### Template Rendering {#templates}

Put `.twig` files in `./src/templates` • assets in `./src/public`

```twig
<!-- src/templates/index.twig -->
<h1>Hello {{name}}</h1>
```

```python
from tina4_python import get, post

@get("/")
async def get_home(request, response):
    return response.render("index.twig", {"name": "World!"})

```

### Sessions {#session-handling}

The default session handling is SessionFileHandler, override `TINA4_SESSION_HANDLER` in .env

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

### SCSS Stylesheets {#scss-stylesheets}

Drop in `./src/scss` → auto-compiled to `./src/public/css`

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```

### Environments {#environments}
Default development environment can be found in `.env`
```
PROJECT_NAME="My Project"
VERSION=1.0.0
TINA4_LANGUAGE=en
TINA4_DEBUG_LEVEL=ALL
API_KEY=ABC1234
TINA4_TOKEN_LIMIT=1
DATABASE_NAME=sqlite3:test.db
```

```python
import os

api_key = os.getenv("API_KEY", "ABC1234")
```

### Authentication {#authentication}

Pass `Authorization: Bearer API_KEY` to secured routes in requests. See `.env` for default `API_KEY`.
```python
from tina4_python import get, post, noauth, secured

@post("/login")
@noauth()
async def login(request, response):
    return response("Logged in", cookies={"session": "abc123"})

@get("/protected")
@secured()
async def secret(request, response):
    return f"Hi {request.cookies.get('username', 'guest')}!"
```

### HTML Forms and Tokens {#html-forms-and-tokens}

```twig
<form method="POST" action="/register">
    {{ ("Register" ~ RANDOM()) | form_token }}
    <input name="email">
    <button>Save</button>
</form>
```

### AJAX and tina4helper.js {#ajax}

Tina4 ships with a small javascript library, in the bin folder, to assist with the heavy lifting of ajax calls.

[More details](tina4helper.md) on available features.

### OpenAPI and Swagger UI {#swagger}

Visit `http://localhost:7145/swagger`

```python
@get("/users", "Get all users")
async def users(request, response):
    """Returns all users"""
    return response(User().select("*"))
```

### Databases {#databases}

```python
from tina4_python.Database import Database

# dba = Database("<driver>:<hostname>/<port>:database_name", username, password)
dba = Database("sqlite3:data.db") 
```

### Database Results {#database-results}
<!-- @todo there are probably a number of parity issues to look at, and also how we document this. For example in php asResult is actually an SQL function. Perhaps this is not an issue. -->
```python
result = dba.fetch("select * from test_record order by id", limit=3, skip=1)

alist = result.to_list()
array = result.to_array()
dictionary = result.to_dict()
paginated = result.to_paginate()
csv = result.to_csv()
json = result.to_json()

```

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

### ORM {#orm}

```python
from tina4_python import ORM


class User(ORM):
    table_name = "users"


User({"name": "Alice"}).save()
User().load("id = ?", 1)
```

### CRUD {#crud}

```python
@get("/users/dashboard")
async def dashboard(request, response):
    users = User().select("id, name, email")
    return response.render("users/dashboard.twig", {"crud": users.to_crud(request)})
```

```twig
{{ crud }}
```

### Inline Testing {#inline-testing}

```python
from tina4python import tests


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

### Consuming REST APIs {#consuming-rest-apis}

```python
from tina4_python import Api

api = Api("https://api.example.com", auth_header="Bearer xyz")
result = api.get("/users/42")
print(result["body"])
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">↑ Back to top</a>
</nav>
