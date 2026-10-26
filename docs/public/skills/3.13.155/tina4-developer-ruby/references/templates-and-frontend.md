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

Register a value every template can read with `add_global`:

```ruby
engine = Tina4::Frond.new(template_dir: "src/templates")
engine.add_global("app_name", "My App")
```

```twig
<title>{{ app_name }}</title>
```

**`add_global` takes a VALUE, not a lazy callable.** Whatever you pass is stored
as-is and merged into the render context unchanged — Frond never calls it for you
when you name it bare. A lambda or proc is therefore stored uncalled, and in a
condition it is a plain object, which is truthy. So this section shows to
everyone:

```ruby
frond.add_global("admin_only", -> { Access.admin_only? })   # WRONG for {% if %}
```

```twig
{% if admin_only %} ...admin link... {% endif %}   {# always true — admin_only is a Proc #}
```

Verified on tina4-ruby 3.13.x with `add_global("g", -> { false })`: `{% if g %}`
is **true** and only `{% if g() %}` calls it (false). Fixes:

- **Resolve it before you pass it:** `frond.add_global("admin_only", Access.admin_only?)` — a real bool.
- **Or call it in the template:** `{% if admin_only() %}`.
- **Accept either a proc global or a plain bool from the render context:**
  `{% if (admin_only is boolean and admin_only) or admin_only() %}`. A name that
  is not registered, called as `nope()`, renders as false (it does not throw on
  3.13.x), so this form is safe when the global is missing.

**Tests must register the global the way the app does.** A plain bool passed in
the render context (`render(tpl, { "admin_only" => false })`) makes
`{% if admin_only %}` behave correctly, so a test that passes a bool hides the
closure bug that production hits through `add_global`.

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
{{ created | timeago }}            → "3 hours ago"
```

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

### Inline SQL Queries (Frond-unique)

```twig
{% query "SELECT * FROM products WHERE active = ?" params=[true] as products %}
{% for product in products.data %}
    <div>{{ product.name }} — ${{ product.price | number_format(2) }}</div>
{% endfor %}
<p>{{ products.total }} products found</p>
```

### Live Blocks (server-rendered, self-refreshing)

A live block renders on the server for first paint, then re-fetches its own HTML and swaps it in
place. Pick a transport: `poll N` (every N seconds), `sse`, or `ws "path"`. frond.js (already loaded)
wires the marker and morphs the result, so a focused input survives the swap.

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
    {% query "SELECT * FROM popular_posts LIMIT 10" as posts %}
    {% for post in posts.data %}
        <a href="/posts/{{ post.id }}">{{ post.title }}</a>
    {% endfor %}
{% endcache %}
```

## frond.js — Frontend Helper

A lightweight JavaScript library that works with any Tina4 backend. Include it:
```html
<script src="/js/frond.js"></script>
```

### HTTP Requests
```javascript
const users = await Frond.get("/api/users");
await Frond.post("/api/users", { name: "Alice" });
await Frond.put("/api/users/1", { name: "Alice Smith" });
await Frond.delete("/api/users/1");
```

### Forms
```javascript
// saveForm collects inputs, attaches the CSRF form token + Bearer, handles file uploads
saveForm("user-form", "/api/users", "message");
Frond.fillForm("#user-form", { name: "Alice", email: "alice@example.com" });
Frond.resetForm("#user-form");
```

### CRUD Table (auto-generated)
```javascript
Frond.crud({
    target: "#users-table",
    endpoint: "/api/users",
    columns: ["id", "name", "email"],
    searchable: true,
    paginated: true
});
```

### Notifications and Modals
```javascript
Frond.notify("Saved!", "success");
Frond.notify("Error!", "error");
Frond.confirm("Delete this item?").then(ok => { if (ok) { /* delete */ } });
Frond.modal({ title: "Edit User", body: "<form>...</form>" });
```

### Authentication
```javascript
Frond.config({ auth: true });
Frond.setToken(jwt);        // stored in memory; all subsequent requests auto-attach Bearer
```

### WebSocket
```javascript
const ws = Frond.ws("/ws/chat", {
    reconnect: true,
    onMessage: (data) => console.log(data),
});
ws.send({ type: "message", text: "Hello" });
```

## Tina4CSS

Layout and components use **Tina4CSS**, a Bootstrap-compatible drop-in bundled in `src/public/css/`.
Bootstrap muscle memory works (`container`, `row`, `col`, `card`, `btn`, `form-control`, `navbar`,
the `mt-*`/`d-flex` utilities). No CDN, no npm, no Bootstrap/Tailwind. **No inline styles** — put
custom rules in `src/public/css/` and reference them by class.
