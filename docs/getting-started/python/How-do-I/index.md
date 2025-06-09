# Questions & Answers

The following collection of Questions and Answers should make you more efficient in using the framework!

### Create a simple Get route

```python
from tina4_python.Router import get

@get("/route/name")
async def get_route(request, response):
    return response("Route")
```

### Redirect

```python
from tina4_python.Router import get

@get("/route/name")
async def get_route(request, response):
    return response.redirect("/login")
```


### Create a simple Post route

```python
from tina4_python.Router import post

@post("/route/name")
async def post_route(request, response):
    return response("Route")
```

### Render a Jinja2/Twig template

```python
from tina4_python.Router import get
from tina4_python.Template import Template

@get("/render/template")
async def get_render_template(request, response):
    
    html = Template.render_twig_template("template.twig", data={}) 
    return response(html)
```

### Annotate routes for OpenAPI

```python
from tina4_python.Router import post
from tina4_python.Swagger import  description, summary, example, tags, secure
@post("/api/{name}")
@description("Some description")
@summary("Some summary")
@example({"id": 1, "name": "Test"})
@tags(["user", "admin"])
@secure()
async def post_route(request, response): 
   
    return response("OK")
```

### How do I get hot code reloading?

Use Jurigged during development to watch for code changes and reload your app automatically.

### Installing Jurigged with `uv`

1. Initialize your project (only once)

```bash
uv init
```

2. Add Jurigged as a development dependency

```bash
uv add --dev jurigged
```

3. Run your app with hot reload

```bash
uv run -m jurigged app.py

```
reload watches for code changes and reloads the server automatically.

# How do I deploy the application for production?

Before deploying your app to production, make sure you install only production dependencies by running:

```bash
uv sync --no-dev

```

### How do I run Tina4 under hypercorn, uvicorn or other ASGI servers?
Expose the ASGI `app` in `app.py`:
```python title="app.py"
# change the import
from tina4_python import app
```

Then install and run with:
```bash
uv pip install hypercorn
hypercorn app:app
```

### How do implement logging in my application

```python
from tina4_python import Debug

Debug.info("This is information")
Debug.debug("This is debugging")
Debug.error("This is an error")
Debug.warning("This is a warning")
```

### How do I get a fresh formToken for my form

```twig
{{  ("SomeValue"~RANDOM()) | formToken }}
```

### How do I manipulate the DatabaseResult set with a method/ function filter

```python
def change_me(record):
    record["value"] = "Something Else"
    return record

result = dba.fetch("select * from users")
print (result.to_list(change_me))

```
