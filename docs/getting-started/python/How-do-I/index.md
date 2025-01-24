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

### How do I get hot code reloading

Make sure jurigged is installed as a dev dependency in your project
```bash
poetry add jurigged --group dev
```

### How do I export the Poetry packages to requirements.txt

```bash
poetry add poetry-plugin-export
poetry export -f requirements.txt --output requirements.txt
```

### How do I run Tina4 under hypercorn, uvicorn or other similar webserver

```python title="app.py"
# change the import
from tina4_python import app
```

```bash
pip install hypercorn
hypercorn app:app

or 

poetry add hypercorn
poetry run hypercorn app:app
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
