# Tina4 Cheatsheet

One page, four frameworks, side by side. Find what you need, copy the column for your language.

> **Verified only.** Every entry on this page has been run green across **all four frameworks** (Python · PHP · Ruby · Node) — not transcribed from docs. Each section notes how it was checked. Sections are added only once they pass that bar, so this page is short on purpose and grows as more is verified.

## Database

> Verified live on PostgreSQL across all four (connection pool round-robin run, this release).

| | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| Connect | `Database("postgres://…")` | `Database::create("postgres://…")` | `Tina4::Database.new("postgres://…")` | `await initDatabase({url})` |
| Run a write | `db.execute("INSERT …")` | `$db->execute("INSERT …")` | `db.execute("INSERT …")` | `await db.execute("INSERT …")` |
| One row | `db.fetch_one(sql)` | `$db->fetchOne(sql)` | `db.fetch_one(sql)` | `await db.fetchOne(sql)` |
| Transaction | `db.start_transaction()` … `db.commit()` / `db.rollback()` | `$db->startTransaction()` … `$db->commit()` / `$db->rollback()` | `db.start_transaction` … `db.commit` / `db.rollback` | `await db.startTransaction()` … `await db.commit()` / `await db.rollback()` |

A standalone write auto-commits on its own connection (so it's durable and visible across a pooled connection); an explicit transaction stays atomic. Set `TINA4_AUTOCOMMIT=false` for strict manual-commit mode.

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

These are written and being checked live across all four before they land here: routing & auth defaults · request/response · ORM models & CRUD · QueryBuilder · relationships · migrations · sessions · middleware · caching · queues · websockets · swagger · graphql · events · i18n · logging · DI · fakedata · CLI.

## 📕 Download the book

The full Tina4 book covers every framework in depth. [Get it here](https://tina4.com).
