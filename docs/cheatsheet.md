# Tina4 Cheatsheet

One page, four frameworks, side by side. Find what you need, copy the column for your language.

> **Verified only.** Every entry on this page has been run green across **all four frameworks** (Python · PHP · Ruby · Node) — not transcribed from docs. Each section notes how it was checked. Sections are added only once they pass that bar, so this page is short on purpose and grows as more is verified.

## Routing {#routing}

> Verified by a live cross-framework code review plus the routing test suites in all four (Python · PHP · Ruby · Node — run green this release): method registration, `{id}` params, and typed-param coercion.

Drop a handler file in `src/routes/` (auto-discovered) and register one per HTTP method:

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Register | `@get("/p")` · `@post` · `@put` · `@patch` · `@delete` | `Router::get("/p", $fn)` · `post` · `put` · `patch` · `delete` | `Tina4::Router.get("/p") { \|req, res\| … }` · `post` · … | `get("/p", h)` · `post` · `put` · `patch` · `del` |
| Path param | `@get("/users/{id}")` | `Router::get("/users/{id}", $fn)` | `Tina4::Router.get("/users/{id}")` | `get("/users/{id}", h)` |
| Typed param | `{id:int}` · `{p:float}` | `{id:int}` · `{p:float}` | `{id:int}` · `{p:float}` | `{id:int}` · `{p:float}` |

- **`{id}` is the param syntax everywhere** — never `:id`. Read it with `request.param("id")` (PHP `$request->params["id"]`, Ruby `params[:id]`, Node `req.params.id`).
- **Typed params arrive coerced** — `{id:int}`/`{id:integer}` → a native integer, `{p:float}`/`{p:number}` → a native float; `string`/`alpha`/`alnum`/`slug`/`uuid`/`path` and an untyped `{id}` stay strings. The type also constrains matching: `/users/abc` → 404 for `{id:int}`. An unknown type name is rejected at registration.
- **Returning data** — `return response(obj)` (Node: `return res.json(obj)`): objects/dicts/arrays → JSON, strings → HTML; ORM models, lists of models, and `DatabaseResult`s auto-serialize to JSON.

---

## Auth {#auth}

> Verified by a live cross-framework code review plus the auth / route-protection suites in all four (Python · PHP · Ruby · Node — run green this release): default protection, opt-out/opt-in, JWT, password hashing.

**GET routes are public; POST / PUT / PATCH / DELETE require a Bearer token by default** — the same convention in every framework. A write request with no valid token gets `401`.

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Open a write route | `@noauth()` | `Router::post(…)->noAuth()` | `Tina4::Router.post(…).no_auth` | `post(…).noAuth()` |
| Protect a GET | `@secured()` | `Router::get(…)->secure()` | `Tina4::Router.get(…).secure` | `get(…).secure()` |
| Issue a JWT | `get_token({"id": 1}, expires_in=60)` | `Auth::getToken(["id"=>1], null, 60)` | `Tina4::Auth.get_token({id: 1}, expires_in: 60)` | `getToken({id: 1}, secret, 60)` |
| Validate a JWT | `valid_token(t)` | `Auth::validToken($t)` | `Tina4::Auth.valid_token(t)` | `validToken(t)` |
| Hash / check password | `Auth.hash_password(pw)` / `Auth.check_password(pw, h)` | `Auth::hashPassword($pw)` / `Auth::checkPassword($pw, $h)` | `Tina4::Auth.hash_password(pw)` / `Tina4::Auth.check_password(pw, h)` | `hashPassword(pw)` / `checkPassword(pw, h)` |

- **JWT expiry is in minutes** (default 60) in all four. `valid_token` returns the decoded **payload** (truthy) on success, `null`/`None` on failure — not a bool.
- A protected route accepts the token from the **`Authorization: Bearer` header, a `formToken` body field, or the session** — checked in that order.
- Passwords hash with **PBKDF2-SHA256** (260 000 iterations, `pbkdf2_sha256$…` format); the check is timing-safe and always takes **`(password, hash)`** in that order.

---

## Request {#request}

> Verified by a live cross-framework code review + the request test suites in all four (Python · PHP · Ruby · Node — run green this release).

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Parsed body | `request.body` | `$request->body` | `request.body` | `req.body` |
| Query param | `request.query["q"]` | `$request->query["q"]` | `request.query["q"]` | `req.query.q` |
| Header (any case) | `request.headers["Content-Type"]` | `$request->headers["Content-Type"]` | `request.headers["Content-Type"]` | `req.headers["content-type"]` |
| Cookie | `request.cookies["sid"]` | `$request->cookies["sid"]` | `request.cookies["sid"]` | `req.cookies.sid` |
| Uploaded file | `request.files["doc"]["content"]` | `$request->files["doc"]["content"]` | `request.files["doc"]["content"]` | `req.files.doc.content` |

- **Body is the parsed payload** — a JSON or form-urlencoded POST becomes a dict/array/hash. (For the raw string, Ruby exposes `request.body_raw`.)
- **`request.query` is the query string only** — route params like `{id}` come from the path (see Routing). Headers are **case-insensitive** in every framework.
- **Uploaded files are raw bytes, never base64** — each entry has `filename`, `type`, `content` (the bytes), `size`.

---

## Response {#response}

> Verified by a live cross-framework code review + the response / SSE test suites in all four (Python · PHP · Ruby · Node — run green this release).

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| JSON (+ status) | `return response(data, 201)` | `return $response($data, 201)` | `response.json(data, 201)` | `return res.json(data, 201)` |
| Redirect | `response.redirect(url)` | `$response->redirect($url)` | `response.redirect(url)` | `res.redirect(url)` |
| Serve a file | `response.file(path)` | `$response->file($path)` | `response.file(path)` | `res.file(path)` |
| Stream / SSE | `response.stream(gen)` | `$response->stream($gen)` | `response.stream(gen)` | `res.stream(gen)` |
| Custom header | `response.add_header(k, v)` | `$response->header(k, v)` | `response.add_header(k, v)` | `res.addHeader(k, v)` |

- **Send through the response object** — objects/dicts/arrays → JSON, strings → HTML; ORM models, lists of models, and `DatabaseResult`s auto-serialize. Always call `response(...)` / `res.json(...)`: it works in all four (PHP and Ruby also serialize a bare `return [...]`, but the explicit call is portable).
- `response(data, 201)` sets the status; **redirect** defaults to 302; **file** auto-detects the MIME type and returns 404 if the file is missing; **stream** sends an SSE-ready `text/event-stream` — pass a generator.

---

## Database

> Verified live on PostgreSQL across all four (connection pool round-robin run, this release).

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Connect | `Database("postgres://…")` | `Database::create("postgres://…")` | `Tina4::Database.new("postgres://…")` | `await initDatabase({url})` |
| Write, params | `db.execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` | `$db->execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` | `db.execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` | `await db.execute("INSERT INTO t (a, b) VALUES (?, ?)", [1, "x"])` |
| One row, params | `db.fetch_one("SELECT * FROM t WHERE id = ?", [1])` | `$db->fetchOne("SELECT * FROM t WHERE id = ?", [1])` | `db.fetch_one("SELECT * FROM t WHERE id = ?", [1])` | `await db.fetchOne("SELECT * FROM t WHERE id = ?", [1])` |
| Transaction | `db.start_transaction()` … `db.commit()` / `db.rollback()` | `$db->startTransaction()` … `$db->commit()` / `$db->rollback()` | `db.start_transaction` … `db.commit` / `db.rollback` | `await db.startTransaction()` … `await db.commit()` / `await db.rollback()` |

Always use `?` placeholders with a params array — every adapter translates `?` to the engine's native style (`$1`, `%s`, `?`). Never string-interpolate user input. A standalone write auto-commits on its own connection (durable + visible across a pooled connection); an explicit transaction stays atomic. Set `TINA4_AUTOCOMMIT=false` for strict manual-commit mode.

## Pages — drop-in templates {#pages}

> Verified by the landing-page / template-routing test suites in all four (Python 43, PHP 44, Ruby 45, Node 55 — run green this release).

Drop a `.twig` (or `.html`) file into `src/templates/pages/` and it serves at the matching URL — no route needed. Same convention in all four frameworks.

| File | URL |
|---|---|
| `src/templates/pages/index.twig` | `/` |
| `src/templates/pages/cars.twig` | `/cars` |
| `src/templates/pages/admin/users.twig` | `/admin/users` |

- **Only `pages/` auto-routes** — `base.twig`, partials, layouts, and `errors/` live in `src/templates/` outside `pages/` and are render-only (`response.render(...)`), never URL-exposed.
- **`_`-prefixed files are private** — `pages/_partial.twig` won't serve.
- **An explicit route always wins** over a same-path template.
- **Toggle:** `TINA4_TEMPLATE_ROUTING=off` (default on). Dev re-reads the directory each request; production caches the lookup at boot.

---

## Frond templates {#frond}

> Verified by a 50-case cross-engine harness (identical templates rendered through all four engines → identical output) plus a host-API check, this release. Frond is Tina4's built-in Twig/Jinja-compatible engine. **The template syntax below is identical in all four frameworks** — only the host call to render or extend it differs (table at the end).

### Output & filters

```twig
{{ name }}                          {# variable #}
{{ name | upper }}                  {# filter #}
{{ price | default(0) }}            {# fallback for undefined/None #}
{{ "%.2f" | format(total) }}        {# printf-style formatting #}
{{ "hello " ~ name }}               {# string concatenation (~, not +) #}
{{ user.email | e }}                {# HTML-escape (single — never double) #}
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

{# macros/forms.twig — macros do NOT inherit context, pass vars explicitly #}
{% macro field(name, label) %}<label>{{ label }}<input name="{{ name }}"></label>{% endmacro %}
{% from "macros/forms.twig" import field %}
{{ field("email", "Email") }}
```

### Set, comments, whitespace, raw, cache

```twig
{% set total = price * qty %}
{# this is a comment — not rendered #}
{%- if trim -%}no surrounding whitespace{%- endif -%}
{% raw %}{{ this is output literally }}{% endraw %}
{% cache "sidebar" 300 %}…expensive fragment cached 300s…{% endcache %}
```

### Forms & tokens

```twig
<form>
  {{ form_token() }}
  <input name="email" class="form-control" placeholder="you@example.com">
  <button onclick="saveForm('myForm', '/api/users', 'msg')">Save</button>
</form>
```

### The only part that differs — the host call

```python
# Python                         # PHP                                # Ruby                                # Node
frond.render("p.twig", d)        $frond->render("p.twig", d)          frond.render("p.twig", d)             frond.render("p.twig", d)
frond.add_filter("money", fn)    $frond->addFilter("money", $fn)      frond.add_filter("money"){ |v| … }    frond.addFilter("money", fn)
frond.add_global("APP", v)       $frond->addGlobal("APP", v)          frond.add_global("APP", v)            frond.addGlobal("APP", v)
frond.add_test("positive", fn)   $frond->addTest("positive", $fn)     frond.add_test("positive"){ |v| … }   frond.addTest("positive", fn)
```

From a route, `response.render("pages/x.twig", data)` (PHP `$response->render`, Node `res.render`) renders a template with data.

---

## Coming as verified

These are written and being checked live across all four before they land here: ORM models & CRUD · QueryBuilder · relationships · migrations · sessions · middleware · caching · queues · websockets · swagger · graphql · events · i18n · logging · DI · fakedata · CLI.

## 📕 Download the book

The full Tina4 book covers every framework in depth. [Get it here](https://tina4.com).
