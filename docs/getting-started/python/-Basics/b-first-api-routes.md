# Basic routing

Unlike PHP the python routes need you to manually include the files that you add.
We do this in the `__init__.py` file under the `src` folder.

Consider we have a file called `src/routes/api.py`, we would need to import it in `src/__init__.py`:

```python
# Start your project here

from .routes import api
```

Inside `api.py` we can add our first `GET` route:

```python
from tina4_python.Router import get


@get("/hello/world")
async def hello_world(request, response):
    return response("Hello World!")
```

We need to import the required libraries as this is how python language works. We can add a post route as follows:

```python
from tina4_python.Router import get, post


@get("/hello/world")
async def get_hello_world(request, response):
    return response("Hello World!")

@post("/hello/world")
async def post_hello_world(request, response):
    return response("Hello World!")
```