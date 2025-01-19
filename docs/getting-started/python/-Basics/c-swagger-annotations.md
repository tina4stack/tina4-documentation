# Swagger Annotations

Swagger is a great UI to quickly document your APIs.  Tina4 makes it easy to do this documentation easily.

## Default Swagger route

The default is `/swagger` but can be overridden by setting a variable in the `.env`.  We assume that basic auth is working by default and that you will use a `formToken` or `API_KEY` to authenticate when route is secure.
Post, Put & Delete routes are secured by default with `formToken`.

```dotenv title=".env"
SWAGGER_ROUTE=/my/swagger
SWAGGER_TITLE=My Swagger
SWAGGER_VERSION=1.0.0
SWAGGER_DESCRIPTION=Some long desription about what this API does
```

## Annotating routes

You can annotate your routes using the following:

```python title="src/routes/example.py"
from tina4_python.Router import post
from tina4_python.Swagger import description, secure, summary, example, tags, params

@post("/hello/world")
@description("Some swagger description")
@summary("Some swagger summary")
@example({"id": 1, "name": "Test"}) # example of object to pass to the route
@tags(["hello", "world"])
@secure() # must be authenticated by formToken or API_KEY
async def hello_world(request, response):  #(request, response)
    print(request.params)
```
