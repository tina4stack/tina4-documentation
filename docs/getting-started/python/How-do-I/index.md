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