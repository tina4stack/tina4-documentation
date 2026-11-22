# Templates & Frontend (Ruby)

## Frond Templates

Tina4 uses Frond, a Twig-compatible template engine. Templates go in `src/templates/`. The template
syntax is identical across every Tina4 language; only how you render them from a route is Ruby.

### Rendering

From a route, render + respond with `response.render`:
```ruby
Tina4.get "/" do |request, response|
  response.render("index.twig", {
    title: "My App",
    users: User.all.map(&:to_h)
  })
end
```

Need the rendered HTML as a String (e.g. to build an email body)? Use `Tina4::Template.render` or a
`Tina4::Frond` instance:
```ruby
html = Tina4::Template.render("index.twig", { title: "My App" })
# or
html = Tina4::Frond.new(template_dir: "src/templates").render("index.twig", data)
```

### Globals (values available in every template)

Register a global on the engine that `response.render` uses, at boot (e.g. in `app.rb`):

```ruby
Tina4.get_frond.add_global("app_name", "My App")   # the shared render engine
```

```twig
<title>{{ app_name }}</title>
```

Do not register on a throwaway `Tina4::Frond.new(...)` — that instance is discarded and no page ever
sees the global. The class form `Tina4::Frond.add_global(...)` goes into a class registry that is
copied into each engine **when the engine is constructed** (ADR-0052), so it reaches the shared
engine only if it runs before the first render builds it. **`Tina4.template_global(...)` /
`Tina4::Template.add_global(...)` do not reach `response.render` at all** (verified on v3: a value
registered there renders empty) — use `Tina4.get_frond.add_global`.

**A zero-argument lambda/proc global is called for you (ADR-0085).** Naming it bare in an
expression invokes it once and uses its return value, so this works as written:

```ruby
Tina4.get_frond.add_global("admin_only", -> { Access.admin_only? })
```

```twig
{% if admin_only %} ...admin link... {% endif %}   {# calls admin_only — false hides it #}
```

Verified on tina4-ruby v3: `add_global("g", -> { false })` makes `{% if g %}` false; `{% if g() %}`
still calls it explicitly. A lambda that declares parameters is NOT auto-called — call it with its
arguments (`{{ greet(name) }}`). Objects and plain values are used as-is.

### Basic Syntax

```twig
{# Output variables #}
<h1>{{ title }}</h1>
<p>{{ user.name }}</p>
<p>{{ user.email | upper }}</p>

{# Conditionals #}
{% if user.is_active %}
    <span class="badge-green">Active</span>
{% else %}
    <span class="badge-red">Inactive</span>
{% endif %}

{# Loops #}
{% for user in users %}
    <div>{{ loop.index }}. {{ user.name }}</div>
{% else %}
    <p>No users found.</p>
{% endfor %}

{# Template inheritance #}
{% extends "base.twig" %}
{% block content %}
    <h1>Page Title</h1>
{% endblock %}
```

### Useful Filters

```twig
{{ name | upper }}                 → UPPERCASE
{{ name | lower }}                 → lowercase
{{ name | capitalize }}            → First letter cap
{{ text | truncate(100) }}         → Truncate
{{ list | join(", ") }}            → Join array
{{ value | default("N/A") }}       → Default if null
{{ html | raw }}                   → No auto-escaping
{{ price | number_format(2) }}     → 1,234.56
{{ date | date("Y-m-d") }}         → Formatted date
{{ text | slug }}                  → url-friendly-slug
```

There is no `timeago` filter — compute the label in the route, or register your own filter.

All filter names use **snake_case**. Register a custom filter in Ruby:
```ruby
Tina4::Frond.new.add_filter("shout") { |value| value.to_s.upcase + "!" }
```

### Includes and Macros

```twig
{% include "partials/header.twig" %}
{% include "partials/card.twig" with {"title": "Hello"} %}

{% macro input(name, value, type) %}
    <input type="{{ type | default('text') }}" name="{{ name }}" value="{{ value }}">
{% endmacro %}

{% import "macros/forms.twig" as forms %}
{{ forms.input("email", "", "email") }}
```

### Data comes from the route (there is no `{% query %}` tag)

Frond has no SQL tag — an unknown tag such as `{% query %}` raises `Frond: unknown tag "query"`.
Fetch in the route and pass the rows in:

```ruby
Tina4::Router.get("/products") do |request, response|
  products = Tina4.database.fetch("SELECT * FROM products WHERE active = ?", [1]).to_a
  response.render("products.twig", { products: products })
end
```

```twig
{% for product in products %}
    <div>{{ product.name }} — ${{ product.price | number_format(2) }}</div>
{% endfor %}
```

### Live Blocks (server-rendered, self-refreshing)

A live block renders on the server for first paint, then re-fetches its own HTML and swaps it in
place. Pick a transport: **`poll N`** (every N seconds) or **`ws "path"`** for live updates. `sse` is
parsed but frond.js only paints it once (it warns "sse transport is not wired yet (v1 supports poll
and ws)") — use `poll` or `ws`. frond.js (already loaded) wires the marker and morphs the result,
so a focused input survives the swap.

```twig
{# Poll every 5 seconds #}
{% live "cart" poll 5 %}
    <strong>{{ count }}</strong> items
{% endlive %}

{# WebSocket - the server pushes updates #}
{% live "chat" ws "/ws/chat" %}
    {% for msg in messages %}<div>{{ msg.user }}: {{ msg.text }}</div>{% endfor %}
{% endlive %}
```

Supply the data with a provider registered by name. It runs on every refresh with the live request,
so auth re-applies each time (an unauthenticated caller never sees another user's data):

```ruby
Tina4::Frond.live_source("cart") do |request|
  { count: cart_count(request), items: cart_items(request) }
end
```

For a `ws` block, push a fresh render the instant data changes with
`Tina4::Frond.push_live("cart", { count: 3 })`.

### Cache Blocks

```twig
{% cache "sidebar" 300 %}
    {# cached for 300 seconds — fetch `posts` in the route and pass it in #}
    {% for post in posts %}
        <a href="/posts/{{ post.id }}">{{ post.title }}</a>
    {% endfor %}
{% endcache %}
```

## frond.js — Frontend Helper

A lightweight JavaScript library that ships with every Tina4 backend at `/js/frond.js`. It exposes a
global `frond` object, auto-attaches the current `Authorization: Bearer` token to every request, and
rotates it from any `FreshToken` response header. Include it:
```html
<script src="/js/frond.js"></script>
```

### HTTP + injecting HTML
```javascript
// Low-level request — auto-sends the bearer token; parses JSON responses.
frond.request("/api/users", {
    method: "POST",
    body: { name: "Alice" },              // object -> JSON body
    onSuccess: (data, status) => console.log(data),
    onError:   (status) => console.warn("failed", status),
});

// GET a partial and inject its HTML into an element:
frond.load("/users/list", "usersTable");

// POST data and inject the response HTML into a target element:
frond.post("/api/users", { name: "Alice" }, "message");
```

### Forms
```javascript
// Collect a form's fields (fills the formToken automatically) into a FormData:
const data = frond.form.collect("userForm");

// Collect + POST + inject the response into a target element (default: "message"):
frond.form.submit("userForm", "/api/users", "message");

// Load an edit/create/delete form into a target element:
frond.form.show("edit", "/users/1/edit", "form");
```

### Auth token
```javascript
frond.token = jwt;      // set the bearer token; all subsequent requests attach it
const current = frond.token;
```

### Messages, popups, GraphQL
```javascript
frond.message("Saved!", "success");                 // renders into the #message element
frond.popup("/preview", "Preview", 800, 600);       // centred popup window
frond.graphql("/graphql", "{ users { id name } }", {}, (res) => console.log(res.data));
```

### WebSocket / SSE (auto-reconnect)
```javascript
const ws = frond.ws("/ws/chat", {
    onOpen: () => console.log("connected"),   // options: onOpen/onClose/onError, reconnect settings
});
ws.on("message", (data) => console.log(data));  // messages arrive via .on("message"), not an option
ws.send({ type: "message", text: "Hello" });

const stream = frond.sse("/events");
stream.on("message", (data) => console.log(data));
```

Live blocks in templates are wired automatically by `frond.live` on `DOMContentLoaded` — you don't
call it yourself.

## Tina4CSS

Layout and components use **Tina4CSS**, a Bootstrap-compatible drop-in bundled in `src/public/css/`.
Bootstrap muscle memory works (`container`, `row`, `col`, `card`, `btn`, `form-control`, `navbar`,
the `mt-*`/`d-flex` utilities). No CDN, no npm, no Bootstrap/Tailwind. **No inline styles** — put
custom rules in `src/public/css/` and reference them by class.
