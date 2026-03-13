---
title: Routing
---

# Routing {#basic-routing}

::: tip 🔥 Hot Tips
- You **don't need** a class or app instance — just `require "tina4"` and use `Tina4.get`, `Tina4.post`, etc.
- Route handlers receive `|request, response|` as block parameters
- Use type hints: `{id:int}`, `{price:float}`, `{path:path}` — auto-converted
- Save route files in `routes/` → **auto-discovered**, zero config needed
- Return a `Hash` or `Array` and it auto-detects as JSON
- Use `Tina4.group "/prefix"` to group routes with a shared path prefix
:::

The routing system in **Tina4 Ruby** is block-driven, DSL-based, and designed for clarity and speed.
Routes are defined using `Tina4.get`, `Tina4.post`, etc. — no app instance required.

## Core API

```ruby
require "tina4"

Tina4.get    "/path" do |request, response| ... end
Tina4.post   "/path" do |request, response| ... end
Tina4.put    "/path" do |request, response| ... end
Tina4.patch  "/path" do |request, response| ... end
Tina4.delete "/path" do |request, response| ... end
Tina4.any    "/path" do |request, response| ... end   # all methods
```

## Basic Route Definition

```ruby
Tina4.get "/hello" do |request, response|
  response.html "<h1>Hello, Tina4 Ruby!</h1>"
end
```

## Route Parameters (Dynamic Paths) {#dynamic-routing}

```ruby
Tina4.get "/users/{id}" do |request, response|
  response.json({ user_id: request.params["id"] })
end

# With automatic type conversion
Tina4.get "/users/{id:int}" do |request, response|
  id = request.params["id"]  # Already an Integer
  response.json({ user_id: id })
end

# Multiple parameters
Tina4.get "/users/{user_id:int}/posts/{post_id:int}" do |request, response|
  response.json({
    user_id: request.params["user_id"],
    post_id: request.params["post_id"]
  })
end
```

**Supported converters**: `int`, `float`, `string` (default), `path`

## Query Parameters

```ruby
Tina4.get "/search" do |request, response|
  q = request.query_params["q"] || "world"
  page = (request.query_params["page"] || 1).to_i
  response.json({ query: q, page: page })
end
```

## Request Body (POST/PUT/PATCH)

```ruby
Tina4.post "/api/users" do |request, response|
  data = request.json_body          # Parsed JSON body
  raw = request.body                # Raw body string
  form = request.form_data          # Form-encoded data
  response.json({ received: data })
end
```

## Route Groups

```ruby
Tina4.group "/api/v1" do
  get "/users" do |request, response|
    response.json({ users: [] })
  end

  post "/users" do |request, response|
    response.json({ created: true }, 201)
  end
end
# Creates: GET /api/v1/users, POST /api/v1/users
```

Groups support auth too:

```ruby
Tina4.group "/admin", auth: Tina4::Auth.bearer_auth do
  get "/dashboard" do |request, response|
    response.json({ admin: true })
  end
end
```

## Secured Routes

```ruby
Tina4.secure_get "/profile" do |request, response|
  auth = request.env["tina4.auth"]  # JWT payload
  response.json({ user: auth["user_id"] })
end

Tina4.secure_post "/api/data" do |request, response|
  response.json({ saved: true })
end
```

Custom auth handler:

```ruby
my_auth = lambda do |env|
  env["HTTP_X_API_KEY"] == "secret123"
end

Tina4.secure_get "/custom", auth: my_auth do |request, response|
  response.json({ ok: true })
end
```

## Response Helpers

```ruby
response.json({ data: "yes" })                   # application/json
response.json({ error: "nope" }, 400)             # JSON with status
response.html "<h1>Hello</h1>"                    # text/html
response.text "plain text"                        # text/plain
response.xml "<root/>"                            # application/xml
response.csv "a,b\n1,2", filename: "export.csv"  # CSV download
response.redirect "/login"                        # 302 redirect
response.file "uploads/report.pdf"                # serve file
response.file "report.pdf", download: true        # force download
response.render "index.twig", { title: "Home" }   # template
```

## Auto-Detection

If you return a raw value from a block (instead of using `response.*`), Tina4 auto-detects the type:

```ruby
Tina4.get "/api/data" do |request, response|
  { message: "Hello" }    # auto-detected as JSON
end

Tina4.get "/page" do |request, response|
  "<h1>Hello</h1>"        # auto-detected as HTML
end
```

## Auto-Discovery

Tina4 automatically loads route files from:
- `routes/`
- `src/routes/`
- `src/api/`
- `api/`
- `app.rb` (project root)

**Zero manual registration required.**

## Summary Table

| Feature | Syntax Example | Notes |
|---------|---------------|-------|
| Route | `Tina4.get "/path" do \|req, res\| end` | Block-based DSL |
| Path Params | `/users/{id:int}` | Auto-conversion |
| Query Params | `request.query_params["q"]` | Hash-like |
| JSON Body | `request.json_body` | Auto-parsed |
| Middleware | `Tina4.before "/api"` | Pattern matching |
| Secured | `Tina4.secure_get "/path"` | JWT bearer auth |
| Groups | `Tina4.group "/prefix"` | Shared prefix |
| Responses | `.json()` `.html()` `.redirect()` | All via response |
| Auto-discovery | Drop file in `routes/` | No config needed |

::: tip 🔥 Hot Tips
- Use **`response.json`** for API endpoints — status code is optional second arg
- Return a **raw Hash** for auto-detected JSON responses
- Use **`Tina4.group`** for versioned APIs (`/api/v1`, `/api/v2`)
- Route files can be **anywhere** under `routes/` — Tina4 finds them automatically
:::

Happy routing with Tina4 Ruby! 🚀
