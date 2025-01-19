# Middleware with Routes

Often an application needs to modify or monitor what is happening before and after when a route has been called.  To this end a middleware layer is helpful.
You can define a class with methods to handle what happens. 

!!! Note "Methods should be named and prefixed as below"
    - `before_` - Triggers before a route has been hit
    - `after_` - Triggers after a route has been hit
    - `before_and_after_` - Triggers both before and after a route has been hit

## Example of a simple "MiddleWare"

In this example we are using the events triggered to modify headers and content. The routes annotated by this middle ware will have their content 
modified.  The example below also implies one can use it for securing CORS and authentication purposes.

```python title="src/app/MiddleWare.py"
class MiddleWare:

    @staticmethod
    def before_route(request, response):
        response.headers['Tina4-Control-Allow-Origin-Before'] = '*'
        response.content = "Before"
        return request, response

    @staticmethod
    def before_something_else(request, response):
        response.headers['Tina4-Control-Allow-Origin-Before-Something-Else'] = '*'
        response.content = "Before"
        return request, response
    
    @staticmethod
    def after_route(request, response):
        response.headers['Tina4-Control-Allow-Origin-After'] = '*'
        response.content += "MEH"
        return request, response

    @staticmethod
    def before_and_after_route(request, response):
        response.content += "Before After"
        response.headers['Tina4-Control-Allow-Origin-BEFORE_AFTER'] = '*'
        return request, response
```

## Annotating the routes

The following examples apply to the middle ware above, we can also be specific about which events should fire otherwise the events will just be fired
according to the naming conventions.

```python
# import the middleware annotation 
from tina4_python.Router import get, middleware

# import our custom middleware class, it could have been called something else as well
from src.app.MiddleWare import MiddleWare

# Generic middleware set to fire before_route, after_route and before_and_after
@middleware(MiddleWare)
@get("/test/redirect")
async def redirect(request, response):
    return response.redirect("/hello/world")

# This middle ware will fire the before_and_after method only
@middleware(MiddleWare, ["before_and_after_route"])
@get("/system/roles/data")
async def system_roles(request, response):
    print("roles ggg")

    return response("OK")
```

!!! tip "Hot Tips"
    - Make sure your middleware annotation is before the route annotation
    - Middleware routes always have a `request` and `response` variable
