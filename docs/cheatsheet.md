# Tina4 Cheatsheet

One page, four frameworks, side by side. Find what you need, copy the column for your language.

> **Verified only.** Every entry on this page has been run green across **all four frameworks** (Python · PHP · Ruby · Node), not transcribed from docs. Each section notes how it was checked. Sections are added only once they pass that bar, so this page is short on purpose and grows as more is verified.

## Routing {#routing}

> Verified by a live cross-framework code review plus the routing test suites in all four (Python · PHP · Ruby · Node, run green this release): method registration, `{id}` params, and typed-param coercion.

Drop a handler file in `src/routes/` (auto-discovered) and register one per HTTP method:

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Register | `@get("/p")` · `@post` · `@put` · `@patch` · `@delete` | `Router::get("/p", $fn)` · `post` · `put` · `patch` · `delete` | `Tina4::Router.get("/p") { \|req, res\| ... }` · `post` · ... | `get("/p", h)` · `post` · `put` · `patch` · `del` |
| Path param | `@get("/users/{id}")` | `Router::get("/users/{id}", $fn)` | `Tina4::Router.get("/users/{id}")` | `get("/users/{id}", h)` |
| Typed param | `{id:int}` · `{p:float}` | `{id:int}` · `{p:float}` | `{id:int}` · `{p:float}` | `{id:int}` · `{p:float}` |

- **`{id}` is the param syntax everywhere**, never `:id`. Read it with `request.param("id")` (PHP `$request->params["id"]`, Ruby `params[:id]`, Node `req.params.id`).
- **Typed params arrive coerced:** `{id:int}`/`{id:integer}` → a native integer, `{p:float}`/`{p:number}` → a native float; `string`/`alpha`/`alnum`/`slug`/`uuid`/`path` and an untyped `{id}` stay strings. The type also constrains matching: `/users/abc` → 404 for `{id:int}`. An unknown type name is rejected at registration.
- **Returning data:** `return response(obj)` (Node: `return res.json(obj)`): objects/dicts/arrays → JSON, strings → HTML; ORM models, lists of models, and `DatabaseResult`s auto-serialize to JSON.

---

## Auth {#auth}

> Verified by a live cross-framework code review plus the auth / route-protection suites in all four (Python · PHP · Ruby · Node, run green this release): default protection, opt-out/opt-in, JWT, password hashing.

**GET routes are public; POST / PUT / PATCH / DELETE require a Bearer token by default**, the same convention in every framework. A write request with no valid token gets `401`.

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Open a write route | `@noauth()` | `Router::post(...)->noAuth()` | `Tina4::Router.post(...).no_auth` | `post(...).noAuth()` |
| Protect a GET | `@secured()` | `Router::get(...)->secure()` | `Tina4::Router.get(...).secure` | `get(...).secure()` |
| Issue a JWT | `get_token({"id": 1}, expires_in=60)` | `Auth::getToken(["id"=>1], null, 60)` | `Tina4::Auth.get_token({id: 1}, expires_in: 60)` | `getToken({id: 1}, secret, 60)` |
| Validate a JWT | `valid_token(t)` | `Auth::validToken($t)` | `Tina4::Auth.valid_token(t)` | `validToken(t)` |
| Hash / check password | `Auth.hash_password(pw)` / `Auth.check_password(pw, h)` | `Auth::hashPassword($pw)` / `Auth::checkPassword($pw, $h)` | `Tina4::Auth.hash_password(pw)` / `Tina4::Auth.check_password(pw, h)` | `hashPassword(pw)` / `checkPassword(pw, h)` |

- **JWT expiry is in minutes** (default 60) in all four. `valid_token` returns the decoded **payload** (truthy) on success, `null`/`None` on failure, not a bool.
- A protected route accepts the token from the **`Authorization: Bearer` header, a `formToken` body field, or the session**, checked in that order.
- Passwords hash with **PBKDF2-SHA256** (260 000 iterations, `pbkdf2_sha256$...` format); the check is timing-safe and always takes **`(password, hash)`** in that order.

---

## Session {#session}

> Verified by a live cross-framework code review + the session suites in all four (Python · PHP · Ruby · Node, run green this release), including the database backend on live Firebird 5.0.4.

Auto-started. Every route handler gets `request.session` ready, no setup for the default file backend.

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Read a value | `request.session.get("user")` | `$request->session->get("user")` | `request.session.get("user")` | `req.session.get("user")` |
| Write a value | `request.session.set("user", data)` | `$request->session->set("user", $data)` | `request.session.set("user", data)` | `req.session.set("user", data)` |
| New id after login | `request.session.regenerate()` | `$request->session->regenerate()` | `request.session.regenerate` | `req.session.regenerate()` |
| Off-request, by id | `Session().start(sid)` | `(new Session())->start($sid)` | `Tina4::Session.new({}).start(sid)` | `new Session().start(sid)` |

- **There is no global session, by design.** A session is keyed to the browser's cookie, so `request.session` is always the current visitor's and never anyone else's; a process-wide session would leak one user's data into another's request. Off a request, rebuild it from a known session id (last row). A background task carries no session, so pass it the user id or session id when you enqueue it.
- **Token-auth trap:** a client that sends an `Authorization: Bearer` token and no session cookie gets a fresh, empty session every request, so writing to it saves nothing that survives. There the token is the identity: read it with `Auth.authenticate_request(headers)` instead of storing on the session.
- **The class lives at `session`, not `core.session`.** To construct one off-request, import it: `from tina4_python.session import Session` (Python), `use Tina4\Session;` (PHP), `Tina4::Session` (Ruby, no import), `import { Session } from "tina4-nodejs"` (Node). There is no `tina4_python.core.session` and no global `session` object.
- Pick the backend with `TINA4_SESSION_BACKEND` (`file` default, `redis`, `valkey`, `mongodb`, `memcached`, `database`). `save()` is auto-called after the response; call it yourself only when you write off-request. Call `regenerate()` right after login to defeat session fixation.

---

## Background tasks {#background}

> Periodic work in the server event loop, no threads and no extra processes. Registering returns a stop-handle in all four; a task carries no request, so it has no session or current user.

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Register a task | `background(job, interval=2.0)` | `$app->background($job, 2.0)` | `Tina4::Background.register(interval: 2.0) { job }` | `background(job, 2)` |
| Stop it | `task.stop()` | `$handle->stop()` | `Tina4::Background.stop_task(task)` | `task.stop()` |

```python
# Python: the import path is core.server, not tina4_python.background
from tina4_python.core.server import background

task = background(lambda: drain_queue(), interval=2.0)   # runs every 2 seconds
task.stop()                                              # ends and deregisters it
```

- **Import it from `core.server`, not `tina4_python.background`.** Python: `from tina4_python.core.server import background`. Node: `import { background } from "tina4-nodejs"`. PHP and Ruby need no import: `$app->background(...)` is a method on your `App`, and Ruby calls `Tina4::Background.register`. There is no `tina4_python.background` module.
- **The interval is seconds** (a float), and the callback takes no arguments. Use background for periodic in-process work (a health poll, a queue drain, a simulator). Never use a raw thread or a separate process; the handle stops and deregisters the task cleanly on shutdown.
- **A background task has no request**, so it has no `request.session` and no current user. Pass it the user id or session id it needs when you register it (see Session).

---

## Request {#request}

> Verified by a live cross-framework code review + the request test suites in all four (Python · PHP · Ruby · Node, run green this release).

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Parsed body | `request.body` | `$request->body` | `request.body` | `req.body` |
| Query param | `request.query["q"]` | `$request->query["q"]` | `request.query["q"]` | `req.query.q` |
| Header (any case) | `request.headers["Content-Type"]` | `$request->headers["Content-Type"]` | `request.headers["Content-Type"]` | `req.headers["content-type"]` |
| Cookie | `request.cookies["sid"]` | `$request->cookies["sid"]` | `request.cookies["sid"]` | `req.cookies.sid` |
| Uploaded file | `request.files["doc"]["content"]` | `$request->files["doc"]["content"]` | `request.files["doc"]["content"]` | `req.files.doc.content` |

- **Body is the parsed payload:** a JSON or form-urlencoded POST becomes a dict/array/hash. (For the raw string, Ruby exposes `request.body_raw`.)
- **`request.query` is the query string only:** route params like `{id}` come from the path (see Routing). Headers are **case-insensitive** in every framework.
- **Uploaded files are raw bytes, never base64:** each entry has `filename`, `type`, `content` (the bytes), `size`.

---

## Response {#response}

> Verified by a live cross-framework code review + the response / SSE test suites in all four (Python · PHP · Ruby · Node, run green this release).

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| JSON (+ status) | `return response(data, 201)` | `return $response($data, 201)` | `response.json(data, 201)` | `return res.json(data, 201)` |
| Redirect | `response.redirect(url)` | `$response->redirect($url)` | `response.redirect(url)` | `res.redirect(url)` |
| Serve a file | `response.file(path)` | `$response->file($path)` | `response.file(path)` | `res.file(path)` |
| Stream / SSE | `response.stream(gen)` | `$response->stream($gen)` | `response.stream(gen)` | `res.stream(gen)` |
| Custom header | `response.add_header(k, v)` | `$response->header(k, v)` | `response.add_header(k, v)` | `res.addHeader(k, v)` |

- **Send through the response object:** objects/dicts/arrays → JSON, strings → HTML; ORM models, lists of models, and `DatabaseResult`s auto-serialize. Always call `response(...)` / `res.json(...)`: it works in all four (PHP and Ruby also serialize a bare `return [...]`, but the explicit call is portable).
- `response(data, 201)` sets the status; **redirect** defaults to 302; **file** auto-detects the MIME type and returns 404 if the file is missing; **stream** sends an SSE-ready `text/event-stream`, so pass a generator.

---

## Database

> Verified live on PostgreSQL across all four (connection pool round-robin run, this release).

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Connect | `Database("postgres://...")` | `Database::create("postgres://...")` | `Tina4::Database.new("postgres://...")` | `await initDatabase({url})` |
| Write, params | `db.execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` | `$db->execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` | `db.execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` | `await db.execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` |
| One row, params | `db.fetch_one("SELECT * FROM t WHERE id = ?", [1])` | `$db->fetchOne("SELECT * FROM t WHERE id = ?", [1])` | `db.fetch_one("SELECT * FROM t WHERE id = ?", [1])` | `await db.fetchOne("SELECT * FROM t WHERE id = ?", [1])` |
| Transaction | `db.start_transaction()` ... `db.commit()` / `db.rollback()` | `$db->startTransaction()` ... `$db->commit()` / `$db->rollback()` | `db.start_transaction` ... `db.commit` / `db.rollback` | `await db.startTransaction()` ... `await db.commit()` / `await db.rollback()` |

Always use `?` placeholders with a params array: every adapter translates `?` to the engine's native style (`$1`, `%s`, `?`). Never string-interpolate user input. A standalone write auto-commits on its own connection (durable + visible across a pooled connection); an explicit transaction stays atomic. Set `TINA4_AUTOCOMMIT=false` for strict manual-commit mode.

## Graph Database

> New in 3.13.111. Proven live across all four on Ultipa, Neo4j, Memgraph and ArangoDB. The engine driver is an optional, lazy-loaded dependency, so the core stays zero-dependency.

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Connect | `GraphDatabase.create("neo4j://host:7687", username="u", password="p")` | `GraphDatabase::create("neo4j://host:7687", "u", "p")` | `Tina4::GraphDatabase.create("neo4j://host:7687", username: "u", password: "p")` | `await GraphDatabase.create("neo4j://host:7687", {username, password})` |
| From env | `GraphDatabase.from_env()` | `GraphDatabase::fromEnv()` | `Tina4::GraphDatabase.from_env` | `await GraphDatabase.fromEnv()` |
| Add node | `g.add_node("Person", {"name": "Alice"})` | `$g->addNode("Person", ["name" => "Alice"])` | `g.add_node("Person", { "name" => "Alice" })` | `await g.addNode("Person", {name: "Alice"})` |
| Add edge | `g.add_edge(a.id, b.id, "KNOWS", {"since": 2020})` | `$g->addEdge($a->id, $b->id, "KNOWS", ["since" => 2020])` | `g.add_edge(a.id, b.id, "KNOWS", { "since" => 2020 })` | `await g.addEdge(a.id, b.id, "KNOWS", {since: 2020})` |
| Neighbors | `g.neighbors(a.id, direction="out", edge_type="KNOWS", limit=50)` | `$g->neighbors($a->id, "out", "KNOWS", 50)` | `g.neighbors(a.id, direction: "out", edge_type: "KNOWS", limit: 50)` | `await g.neighbors(a.id, {direction: "out", edgeType: "KNOWS", limit: 50})` |
| Traverse | `g.traverse(a.id, depth=3, direction="out", edge_type="KNOWS")` | `$g->traverse($a->id, 3, "out", "KNOWS")` | `g.traverse(a.id, depth: 3, direction: "out", edge_type: "KNOWS")` | `await g.traverse(a.id, {depth: 3, direction: "out", edgeType: "KNOWS"})` |
| Raw query | `g.query("MATCH (n) RETURN n", params)` | `$g->query("MATCH (n) RETURN n", $params)` | `g.query("MATCH (n) RETURN n", params)` | `await g.query("MATCH (n) RETURN n", params)` |

The URL scheme picks the engine: `ultipa://` (GQL), `neo4j://` / `memgraph://` / `bolt://` (Bolt/Cypher, one adapter), `arango://` (AQL). The portable core (`add_node` / `add_edge` / `get_node` / `update_node` / `delete_node` / `neighbors` / `traverse`) works identically on every engine; `query` and `execute` pass native statements straight through. Configure with `TINA4_GRAPH_URL` and `TINA4_GRAPH_CONNECT_TIMEOUT`.

## Pages: drop-in templates {#pages}

> Verified by the landing-page / template-routing test suites in all four (Python 43, PHP 44, Ruby 45, Node 55, run green this release).

Drop a `.twig` (or `.html`) file into `src/templates/pages/` and it serves at the matching URL, no route needed. Same convention in all four frameworks.

| File | URL |
|---|---|
| `src/templates/pages/index.twig` | `/` |
| `src/templates/pages/cars.twig` | `/cars` |
| `src/templates/pages/admin/users.twig` | `/admin/users` |

- **Only `pages/` auto-routes:** `base.twig`, partials, layouts, and `errors/` live in `src/templates/` outside `pages/` and are render-only (`response.render(...)`), never URL-exposed.
- **`_`-prefixed files are private:** `pages/_partial.twig` won't serve.
- **An explicit route always wins** over a same-path template.
- **Toggle:** `TINA4_TEMPLATE_ROUTING=off` (default on). Dev re-reads the directory each request; production caches the lookup at boot.

---

## Frond templates {#frond}

> Verified by a 50-case cross-engine harness (identical templates rendered through all four engines → identical output) plus a host-API check, this release. Frond is Tina4's built-in Twig/Jinja-compatible engine. **The template syntax below is identical in all four frameworks**, only the host call to render or extend it differs (table at the end).

### Output & filters

```twig
{{ name }}                          {# variable #}
{{ name | upper }}                  {# filter #}
{{ price | default(0) }}            {# fallback for undefined/None #}
{{ "%.2f" | format(total) }}        {# printf-style formatting #}
{{ "hello " ~ name }}               {# string concatenation (~, not +) #}
{{ user.email | e }}                {# HTML-escape (single - never double) #}
{{ html | raw }}                    {# unescaped output (also: | safe) #}
```

Verified filters: `upper` `lower` `length` `trim` `capitalize` `title` `default` `format` `e`/`escape` `raw`/`safe` `json_encode` `replace` `join` `first` `last` `reverse` `sort` `abs` `round` `striptags` `slice` `nl2br` `url_encode`.

### Conditionals & loops

```twig
{% if balance > 0 %}In credit{% elif balance == 0 %}Even{% else %}Owing{% endif %}

{{ count != 1 ? 's' : '' }}         {# ternary #}
{{ 's' if count != 1 else '' }}     {# Python-style ternary also works #}

{% for item in items %}
  {{ loop.index }}. {{ item.name }}{% if loop.last %} (last){% endif %}
{% endfor %}
```

`loop.index` (1-based), `loop.index0`, `loop.first`, `loop.last`, `loop.length`. Tests: `is defined` · `is even` · `is odd` · `is null` · plus any you register with `add_test`.

### Inheritance, includes & macros

```twig
{# base.twig #}
<title>{% block title %}Tina4{% endblock %}</title>
{% block content %}{% endblock %}

{# page.twig #}
{% extends "base.twig" %}
{% block content %}{% include "partials/nav.twig" %}{% endblock %}

{# macros/forms.twig - macros do NOT inherit context, pass vars explicitly #}
{% macro field(name, label) %}<label>{{ label }}<input name="{{ name }}"></label>{% endmacro %}
{% from "macros/forms.twig" import field %}
{{ field("email", "Email") }}
```

### Set, comments, whitespace, raw, cache

```twig
{% set total = price * qty %}
{# this is a comment - not rendered #}
{%- if trim -%}no surrounding whitespace{%- endif -%}
{% raw %}{{ this is output literally }}{% endraw %}
{% cache "sidebar" 300 %}...expensive fragment cached 300s...{% endcache %}
```

### Forms & tokens

```twig
<form>
  {{ form_token() }}
  <input name="email" class="form-control" placeholder="you@example.com">
  <button onclick="saveForm('myForm', '/api/users', 'msg')">Save</button>
</form>
```

### The only part that differs: the host call

```python
# Python                         # PHP                                # Ruby                                # Node
frond.render("p.twig", d)        $frond->render("p.twig", d)          frond.render("p.twig", d)             frond.render("p.twig", d)
frond.add_filter("money", fn)    $frond->addFilter("money", $fn)      frond.add_filter("money"){ |v| ... }    frond.addFilter("money", fn)
frond.add_global("APP", v)       $frond->addGlobal("APP", v)          frond.add_global("APP", v)            frond.addGlobal("APP", v)
frond.add_test("positive", fn)   $frond->addTest("positive", $fn)     frond.add_test("positive"){ |v| ... }   frond.addTest("positive", fn)
```

From a route, `response.render("pages/x.twig", data)` (PHP `$response->render`, Node `res.render`) renders a template with data.

---

## MCP servers {#mcp}

> Verified by running each framework's MCP suite green on the lab this release (Python 82 · PHP 121 · Ruby 102 · Node 7 files, 0 failures) against the real `McpServer` over its real transport, no mocks: server creation, tool and resource registration, the `tools/call` JSON-RPC round-trip, and the security gate.

Expose your own application logic to an AI assistant. Register tools and resources on a path, mount it, point Claude Code at the endpoint. Same concept in all four, idiomatic names per language.

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Create a server | `McpServer("/crm/mcp", name="CRM")` | `new McpServer("/crm/mcp", name: "CRM")` | `Tina4::McpServer.new("/crm/mcp", name: "CRM")` | `new McpServer("/crm/mcp", "CRM")` |
| Register a tool | `@mcp_tool("find", server=mcp)` | `#[McpTool("find", server: "crm")]` | `Tina4.mcp_tool("find", server: mcp) { \|a\| ... }` | `mcpTool("find", "desc", mcp, [params])(fn)` |
| Register a resource | `@mcp_resource("crm://p", server=mcp)` | `#[McpResource("crm://p", server: "crm")]` | `Tina4.mcp_resource("crm://p", server: mcp) { ... }` | `mcpResource("crm://p", "desc", "application/json", mcp)(fn)` |
| Mount the routes | `mcp.register_routes(router)` | `$mcp->registerRoutes($router)` | `mcp.register_routes` | `mcp.registerRoutes(router)` |

- **The signature is the schema.** Python and PHP read the function or method type hints; Ruby and Node take an explicit params list (`{name, type, default}`). A parameter with a default is optional, every other one is required, and an assistant cannot call a tool whose types it cannot see, so type every one.
- **Return structured data**, a dict, a row, a list, never a preformatted string. The server wraps it as MCP content and lets the assistant format it for the user.
- **The endpoints are born with the server.** `POST /crm/mcp` speaks Streamable HTTP (send JSON-RPC, read the reply inline; `initialize` hands back an `Mcp-Session-Id`), with legacy `POST /crm/mcp/message` and `GET /crm/mcp/sse` for older clients. In PHP the `server:` argument is the server's string handle, not the object.
- **Public by default, so secure anything past localhost.** Protect the MCP path with the same auth you use on routes (secured routes or middleware), or check the bearer token inside the tool. Keep one server per domain (`/crm/mcp`, `/accounting/mcp`) and one focused query per tool. Full guide: the Custom MCP Servers chapter for your language, linked from [Build with AI](/build-with-ai).

---

## Coming as verified

These are written and being checked live across all four before they land here: ORM models & CRUD · QueryBuilder · relationships · migrations · middleware · caching · queues · websockets · swagger · graphql · events · i18n · logging · DI · fakedata · CLI.

## 📕 Download the book

The full Tina4 book covers every framework in depth. [Get it here](https://tina4.com).
