# Session Handling

Sessions are critical in keeping state in traditional web applications. Sessions variables are stored on the server primarily with 
a cookie variable as reference in the browser to keep the link between the website and the server.
Python doesn't have session handling by default in its basic web server offering, and you would have to implement this yourself. 

## The Session object.

The session object is exposed through the request made to an annotated end point.  You use the `get` and `set` methods to assign values to your session.
A simple use case would be to authenticate a user and then keep a session open while they are browsing the site.  Sessions are terminated to the website the moment
the browser closes.

```python

request.session.set('my-key', 'my-value')
request.session.set('user', {"username": "Tina4", "email": "test@test.com"})

for pair in request.session:
    print(pair)

```

```twig title="index.twig"
{% dump({{request.session}}) %}

{% set user = request.session.get("user") %}
{{ user.username }}
{{ user.email }}
```

## Example of using a session

Consider the following end points, you can open each in a separate browser tab to see how it works. If you hit up the set session end point, then hit up the get session end point.
See how the session value persists across the tabs.

```python title="src/routes/session-example.py"
@get("/session/set")
async def session_set(request, response):
    request.session.set("name", "Tina")
    request.session.set("user", {"name": "Tina", "email": "test@email.com", "date_created": datetime.now()})
    print("session set")

@get("/session/get")
async def session_get(request, response):
    print(request.session.get("name"), request.session.get("user"))
    print("session output")
```
