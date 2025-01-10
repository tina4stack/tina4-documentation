# Basic routing

Unlike PHP the python routes need you to manually include the files that you add.
We do this in the `__init__.py` file under the `src` folder.

Consider we have a file called `src/routes/api.py`, we would need to import it in `src/__init__.py`:

```python title="src/__init__.py"
# Start your project here

from .routes import api
```

## Get route

Inside `api.py` we can add our first `GET` route:

```python title="src/routes/api.py"
from tina4_python.Router import get


@get("/hello/world")
async def hello_world(request, response):
    return response("Hello World!")
```

## Get & Post route

We need to import the required libraries as this is how python language works. We can add a post route as follows:

```python title="src/routes/api.py"
from tina4_python.Router import get, post


@get("/hello/world")
async def get_hello_world(request, response):
    return response("Hello World!")

@post("/hello/world")
async def post_hello_world(request, response):
    return response("Hello World!")
```

## Example of plain routing

Tina4 allows you to simple print out of the defined routing method, we don't recommend doing this but it is useful for debugging sometimes.

```python title="src/routes/api.py"
from tina4_python.Router import get


@get("/hello/world")
async def get_hello_world(request, response):
    print("Hello World!")


```

## Passing back dictionaries and lists

Tina4 supports this out of the box, so you can just put a dictionary or list as part of the response.

```python title="src/routes/api.py"
from tina4_python.Router import get


@get("/hello/world")
async def get_hello_world(request, response):
    return response([{"name": "Tina4"}])


```
