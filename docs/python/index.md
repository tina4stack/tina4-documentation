# Tina4 Python – Quick Reference

### Installation
```bash
pip install tina4-python
tina4-python initialize my-project
cd my-project
python index.py
```

### Static Websites
Put files with `.twig` extension in `./src/template` or images and other assets in `./src/public` → instantly served.

```twig
<!-- src/templates/index.twig -->
<h1>Hello Static World</h1>
```

### SCSS Stylesheets
Drop files in `./src/scss` → auto-compiled to `./src/public/css`.

```scss
// ./src/scss/main.scss
$primary: #2c3e50;
body { background: $primary; color: white; }
```

### Environments

Available with `os.getenv("ENVIRONMENT_VAR", "DEFAULT_VALUE")` or `os.environ["ENVIRONMENT_VAR"]`

```
# .env
DEBUG=True
ENVIRONMENT=development
DB_TYPE=sqlite
DB_NAME=./app.db
```

```python
import os
api_key = os.environ["SOME_VALUE"]
api_key = os.getenv("SOME_VALUE", "SOME_DEFAULT")
```

### Basic Routing
```python
from tina4_python import get, post

@get("/")
async def home(request, response):
    return response("<h1>Hello Tina4 Python</h1>")

@post("/api")
async def api(request, response):
    return response({"data": request.params})
```

### Authentication
```python
from tina4_python import get, post, noauth, secured

@post("/login")
@noauth() # make auth not needed
async def login(request, response):
    return response("Not secure at all!")

@get("/protected")
@secured()
async def secret(request, response):
    return f"Welcome {request.params["username"]}!"
```

### HTML Forms and Tokens
```twig
<!-- ./src/templates/form.twig -->
<form method="POST" action="/register">
    {{ ("Register" ~ RANDOM()) | form_token }}
    <input name="email" type="email" placeholder="Enter email" >
    <button>Save</button>
</form>
```

### Swagger
Visit `http://localhost:7145/swagger` – auto-generated.

```python
@get("/users")
async def users(request, response):
    """Returns all users"""
    return response(User().select("*"))
```

### Databases
```python
from tina4_python.Database import Database
db = Database(os.getenv("DATABASE_PATH"), os.getenv("USERNAME"), os.getenv("PASSWORD"))  # reads values from .env
```

### Migrations
```bash
tina4 migrate:create create_users_table # creates an sql file in ./migrations on project route 
```
```python
# migrations/00001_create_users_table.py
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
)
```
```bash
tina4 migrate
```

### ORM
```python
from tina4_python import ORM

class User(ORM):
    table_name = "users"

user = User({"name": "Alice"}).save() # saves Alice to database
user.load("id = ?", [1]) # load user
```

### CRUD
Any `DatabaseResult` can become a CRUD rendered environment

```python
@get("/users/dashboard")
async def users(request, response):
    from ..orm import Users
    users = Users().select(
        "id, first_name, last_name, email, is_current", limit=1000,
        order_by="date_created desc")

    return response.render("user/dashboard.twig", {"user_crud": users.to_crud(request, {"card_view": True})})
```

```twig
<!-- .src/templates/users/dashboard.twig -->
<h1> Users </h1>
{{ user_crud }}
```

### Consuming REST APIs
```python
from tina4_python import Api

# Initialize client
api = Api(
    base_url="https://api.example.com/v1",
    auth_header="Authorization: Bearer xyz123"
)

# Simple GET
result = api.send_request("/users/42")
print(result["http_code"])  # → 200
print(result["body"])       # → parsed JSON dict/list
```
