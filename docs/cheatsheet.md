# Tina4 Cheatsheet

One page, four frameworks, side by side. Find what you need, copy the column for your language. Frond templates are the same everywhere — they get one shared section, not four columns.

> **Format preview** — this is a prototype covering a few sections plus the full Frond reference. The remaining sections (auth, sessions, caching, queues, websockets, swagger, graphql, events, and the rest) follow the same shape once the layout is locked.

## Install & run

| Task | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Add the framework | `uv add tina4-python` | `composer require tina4stack/tina4php` | `bundle add tina4ruby` | `npm i tina4-nodejs` |
| Scaffold a project | `tina4 init python .` | `tina4 init php .` | `tina4 init ruby .` | `tina4 init node .` |
| Dev server | `tina4 serve` | `composer start` | `tina4ruby serve` | `npx tina4nodejs serve` |
| Run migrations | `tina4 migrate` | `composer tina4 migrate` | `tina4ruby migrate` | `npx tina4nodejs migrate` |
| Default port | `7145` | `7145` | `7147` | `7148` |

## Static pages

Drop files in the public folder and they're served at `/` — no route needed.

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Public assets dir | `src/public/` | `src/public/` | `public/` | `src/public/` |
| SCSS (auto-compiled) | `src/scss/` → `public/css/` | `src/scss/` → `public/css/` | `scss/` → `public/css/` | `src/scss/` → `public/css/` |

## Pages — drop-in templates {#pages}

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

## Routing

| Operation | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| GET | `@get("/users")` | `Router::get("/users", $fn)` | `Tina4.get("/users")` | `get("/users", h)` |
| POST | `@post("/users")` | `Router::post("/users", $fn)` | `Tina4.post("/users")` | `post("/users", h)` |
| Path param (int) | `@get("/u/{id:int}")` | `Router::get("/u/{id}", $fn)` | `Tina4.get("/u/{id:int}")` | `get("/u/{id}", h)` |
| Catch-all | `@get("/files/*")` | `Router::get("/files/{path}")` | `Tina4.get("/files/*path")` | `get("/files/{...path}")` |
| Make a write public | `@noauth()` | `->noCache()` *(see auth)* | `Tina4.secure_post` opts | `.secure()` toggles |
| Protect a GET | `@secured()` | `->secure()` | `Tina4.secure_get` | `.secure()` |

Auth defaults are identical across all four: **GET is public, write verbs (POST/PUT/PATCH/DELETE) require a Bearer token.**

## Request & response

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Parsed body | `request.body` | `$request->body` | `request.body` | `req.body` |
| Query params | `request.query` | `$request->query` | `request.params` | `req.query` |
| JSON response | `return response(data)` | `return $response(data)` | `response.json(data)` | `res.json(data)` |
| Status code | `response(data, 201)` | `$response(data, 201)` | `response.json(data, 201)` | `res.json(data, 201)` |
| Render a template | `response.render("p.twig", d)` | `$response->render("p.twig", d)` | `response.render("p.twig", d)` | `res.render("p.twig", d)` |
| Redirect | `response.redirect("/x")` | `$response->redirect("/x")` | `response.redirect("/x")` | `res.redirect("/x")` |

Return a model, a list of models, or a query result straight from a route — it auto-serializes to JSON in every framework.

## Database & ORM

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Connect | `Database("postgres://…")` | `Database::create("postgres://…")` | `Tina4::Database.new("postgres://…")` | `await initDatabase({url})` |
| Bind ORM (default) | `bind_database(db)` | `ORM::bindDatabase($db)` | `Tina4.bind_database(db)` | `bindDatabase(adapter)` |
| Raw fetch | `db.fetch(sql, params)` | `$db->fetch($sql, $params)` | `db.fetch(sql, params)` | `db.fetch(sql, params)` |
| One row | `db.fetch_one(sql)` | `$db->fetchOne($sql)` | `db.fetch_one(sql)` | `db.fetchOne(sql)` |
| Find by id | `User.find(1)` | `(new User)->findById(1)` | `User.find(1)` | `User.find(1)` |
| Create + save | `User(data).save()` | `(new User($data))->save()` | `User.new(data).save` | `new User(data).save()` |
| Transaction | `db.start_transaction()` … `db.commit()` | `$db->startTransaction()` … `$db->commit()` | `db.start_transaction` … `db.commit` | `await db.startTransaction()` … `await db.commit()` |

> Standalone writes auto-commit on their own connection (pool-safe); explicit transactions stay atomic. Set `TINA4_AUTOCOMMIT=false` for strict manual-commit mode.

---

## Frond templates {#frond}

Frond is Tina4's built-in Twig/Jinja-compatible engine. **The template syntax below is identical in all four frameworks** — only the host call to render or extend it differs (table at the end).

### Output & filters

```twig
{{ name }}                          {# variable #}
{{ name | upper }}                  {# filter #}
{{ price | default(0) }}            {# fallback for undefined/None #}
{{ "%.2f" | format(total) }}        {# number formatting #}
{{ "hello " ~ name }}               {# string concatenation (~, not +) #}
{{ user.email | e }}                {# HTML-escape #}
{{ html | raw }}                    {# unescaped output (also: | safe) #}
```

### Conditionals & loops

```twig
{% if balance > 0 %}In credit{% elif balance == 0 %}Even{% else %}Owing{% endif %}

{{ count != 1 ? 's' : '' }}         {# ternary #}
{{ 's' if count != 1 else '' }}     {# Python-style ternary also works #}

{% for item in items %}
  {{ loop.index }}. {{ item.name }}{% if loop.last %} (last){% endif %}
{% endfor %}
```

`loop.index` (1-based), `loop.index0`, `loop.first`, `loop.last`, `loop.length`.

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

### Custom tests

```twig
{% if balance is positive %}…{% endif %}   {# after registering a "positive" test #}
```

### The only part that differs — the host call

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Render in a route | `response.render("p.twig", d)` | `$response->render("p.twig", d)` | `response.render("p.twig", d)` | `res.render("p.twig", d)` |
| Render directly | `Frond().render("p.twig", d)` | `(new Frond)->render("p.twig", d)` | `Tina4::Frond.new.render("p.twig", d)` | `new Frond().render("p.twig", d)` |
| Add a filter | `Frond.add_filter("money", fn)` | `Frond::addFilter("money", $fn)` | `frond.add_filter("money"){…}` | `frond.addFilter("money", fn)` |
| Add a global | `Frond.add_global("APP", v)` | `Frond::addGlobal("APP", v)` | `frond.add_global("APP", v)` | `frond.addGlobal("APP", v)` |
| Add a test | `Frond.add_test("even", fn)` | `Frond::addTest("even", $fn)` | `frond.add_test("even"){…}` | `frond.addTest("even", fn)` |

## 📕 Download the book

The full Tina4 book covers every framework in depth. [Get it here](https://tina4.com).
