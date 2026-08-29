# Module 1: The Request and the Answer

**Level 1: Make It Work** | Code gate 30, comprehension gate 70

---

## 1. The Idea

Two computers. One asks a question. The other sends back an answer.

That is the whole of the web. Everything else is decoration on top of it. When you open a
browser and type an address, your computer sends a short message across the network that
means "give me the thing at this address." Somewhere a machine is listening. It reads the
question, works out what you want, and sends something back. Your browser draws whatever
arrived.

The question is called a **request**. The answer is called a **response**. The machine
listening is called a **server**, and by the end of this module you will have written one.

Here is the part that surprises people. A server is not a special kind of computer. It is
an ordinary program that does not exit. It starts, it waits, and when a request arrives it
runs a little bit of your code and sends back whatever your code returned. Your laptop can
be a server. It is about to be.

The code you write today is a function that answers a question. That is genuinely it.

---

## 2. Build It

Make a folder and step into it.

```bash
mkdir first-server
cd first-server
pip install tina4-python
```

Create one file, `src/routes/greeting.py`:

```python
from tina4_python.core.router import get


@get("/hello")
async def say_hello(request, response):
    return response("Hello from your first server")
```

Create `app.py` next to it:

```python
from tina4_python import Tina4

Tina4().run()
```

Start it:

```bash
tina4python serve
```

Open `http://localhost:7145/hello` in a browser. Your text is on the screen. You wrote a
server.

### Read it back, line by line

`from tina4_python.core.router import get` brings in a tool called `get`. It teaches your
function how to be reachable from a browser.

`@get("/hello")` is a **decorator**. It sits above a function and changes what that function
is. This one says: when a request arrives asking for `/hello`, run the function below me.
The `/hello` part is the **path**, the bit of the address after the domain name.

`async def say_hello(request, response):` defines the function. It receives two things. The
`request` holds everything the caller sent. The `response` is how you send something back.
Ignore `async` for now. It matters in module 14 and not before.

`return response("Hello from your first server")` builds the answer and hands it back.

Four lines. One of them is an import.

### Now make it answer differently

Change the file:

```python
from tina4_python.core.router import get


@get("/hello/{name}")
async def say_hello(request, response):
    return response(f"Hello, {request.params['name']}")
```

Visit `http://localhost:7145/hello/Andre`. Then `/hello/Sipho`. Then your own name.

The curly braces in `{name}` mark a **path parameter**, a slot in the address. Whatever the
caller puts there arrives in `request.params` under the key `name`. The address stopped
being a fixed label and became an input.

### Send data instead of text

```python
from tina4_python.core.router import get


@get("/api/hello/{name}")
async def say_hello(request, response):
    return response({"greeting": "Hello", "name": request.params["name"]})
```

Visit `/api/hello/Andre` and you get this:

```json
{"greeting": "Hello", "name": "Andre"}
```

You returned a Python dictionary and it arrived as JSON. Tina4 saw a dictionary, decided
you meant data rather than words, and set the content type accordingly. Text is for people.
JSON is for programs. You just wrote both, and the only thing that changed was the shape of
what you returned.

---

## 3. The Principle

What you built is a **client-server** system, and the rules it follows are written down.
HTTP is a contract, defined in RFC 9110, and both sides agreed to it long before you
arrived.

The contract says a request carries a **method** and a **path**. The method is the verb.
`GET` means "give me something," and it promises not to change anything on the server.
`POST` means "here is something new." `DELETE` means what it says. That promise attached to
`GET` is the important one, and it is why `@get` is the safe decorator to start with.

The contract also says a response carries a **status code**. `200` means it worked. `404`
means the thing you asked for is not here. `500` means the server broke while trying. You
returned no status code above and got `200`, because Tina4 fills in the common case.

Three things make this contract worth learning once:

**It is universal.** Every web framework in every language implements the same contract.
The syntax below changes. The contract does not.

**It is stateless.** Each request arrives knowing nothing about the last one. The server
does not remember you between requests. That sounds like a limitation and it is the reason
the web scales to billions of people. Any server can answer any request, because no server
is holding your history.

**It is inspectable.** Every request and response is text you can read. Nothing is hidden.

---

## 4. Elsewhere

The same four lines in three other frameworks:

```python
# Flask
@app.route("/hello/<name>")
def say_hello(name):
    return f"Hello, {name}"
```

```javascript
// Express
app.get("/hello/:name", (req, res) => {
  res.send(`Hello, ${req.params.name}`);
});
```

```ruby
# Rails, config/routes.rb
get "/hello/:name", to: "greetings#say_hello"
```

Look at what stayed the same. A path with a slot in it. A function that runs when that path
is requested. A value returned to the caller. The marker for the slot moves around (`{name}`,
`<name>`, `:name`) and Rails insists on declaring routes in a separate file, but the shape
is identical.

Learn the shape and you can read all four. That is why this module leads the course.

---

## 5. When Not To

HTTP is the right answer most of the time. Here is where it is the wrong one.

**When the server needs to speak first.** HTTP only lets the client ask. The server cannot
start a conversation. For a chat application, a live scoreboard or a notification, the
client would have to ask "anything new?" over and over, which wastes work and still arrives
late. That is what WebSocket exists for, and Tina4 has one built in. Module 23 covers it.

**When the work takes longer than a person will wait.** A request that runs for four minutes
holds a connection open, and something in the middle will give up before you finish. Video
processing and bulk imports belong on a queue. Module 20.

**When there is no network.** Two functions in the same program should call each other
directly. Wrapping an internal call in HTTP so it looks tidy adds serialisation, a network
hop and a new failure mode, and buys nothing.

Notice the shape of all three. The question is never "is HTTP good." It is "does this
situation match what HTTP is for." That question is the actual skill, and it applies to
every tool in this course.

---

## 6. Check Yourself

Your exercise is in `exercises/module-01/`. Read `BRIEF.md` and follow it.

You will build a small endpoint, then answer four written questions. The code is worth 30.
The written answers are worth 70, and they are marked on whether you understood what you
built, not on whether you can repeat this chapter. Copying sentences from above scores zero.
The examiner is looking for your reasoning in your own words.

One piece of advice before you start. Answer the written questions **after** you have the
code working and **before** you look anything up. Your own explanation, even a clumsy one,
is worth more than a polished one you borrowed.
