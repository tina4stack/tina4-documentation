# Routes & API Development (Ruby)

## Creating Routes

Drop a file in `src/routes/` and it's auto-discovered. No registration needed. Register routes with
the top-level **`Tina4.get` / `Tina4.post` / `Tina4.put` / `Tina4.patch` / `Tina4.delete`** DSL (or
the equivalent `Tina4::Router.get` / `.post` / …). Each takes a block with `|request, response|`.

> **There is NO bare `get "/x" do ... end`.** A top-level `get`/`post` is not defined — you must
> qualify it as `Tina4.get` / `Tina4.post` (or `Tina4::Router.get` / `Tina4::Router.post`). A bare
> `get "/x" do ... end` raises `NoMethodError`.

```ruby
# src/routes/hello.rb
Tina4.get "/hello" do |request, response|
  response.text "Hello World"
end

Tina4.get "/users/{id}" do |request, response|
  user = User.find(request.params[:id])         # find is a CLASS method
  if user
    response.json(user.to_h)
  else
    response.json({ error: "User not found" }, Tina4::HTTP_NOT_FOUND)
  end
end

# Write routes are secure by default (bearer token required). This one is a
# public create for demo purposes, so both auth gates are cleared.
Tina4.post("/users", auth: false) do |request, response|
  user = User.create(request.body)              # request.body is a parsed Hash (String keys)
  response.json(user.to_h, Tina4::HTTP_CREATED) # 201
end.no_auth

Tina4.put "/users/{id}" do |request, response|
  user = User.find(request.params[:id])
  next response.json({ error: "Not found" }, Tina4::HTTP_NOT_FOUND) unless user
  user.name = request.body["name"]
  user.save
  response.json(user.to_h)
end

Tina4.delete "/users/{id}" do |request, response|
  user = User.find(request.params[:id])
  user&.delete
  response.status(204)          # 204 No Content
end
```

Status codes: pass an Integer as the second argument to `response.json` / `response.text` /
`response.html`, or use the `Tina4::HTTP_*` constants (`HTTP_OK` 200, `HTTP_CREATED` 201,
`HTTP_NO_CONTENT` 204, `HTTP_BAD_REQUEST` 400, `HTTP_UNAUTHORIZED` 401, `HTTP_FORBIDDEN` 403,
`HTTP_NOT_FOUND` 404, `HTTP_SERVER_ERROR` 500). Note: the 500 constant is `HTTP_SERVER_ERROR` —
there is no `HTTP_INTERNAL_SERVER_ERROR`.

## Smart Response Types

The framework infers what you want. Inside a handler, either **return** a value or **call** a
`response.*` method:

- Return a **Hash/Array** → JSON response (`Content-Type: application/json`)
- Return a **String** → HTML if it starts with `<`, otherwise plain text
- Return an **Integer** → status code only
- `response.json(data, status = 200)` → JSON (serialises ORM models, Arrays of models, and
  `DatabaseResult` automatically)
- `response.text(content, status = 200)` → `text/plain`
- `response.html(content, status = 200)` → `text/html`
- `response.render("template.twig", data)` → Frond template rendering
- `response.redirect("/path")` → HTTP redirect (302)
- `response.file("path/to/file", download: true)` → file download
- `response.status(code)` → chainable status setter (`response.status(204)`)

Every `response.*` method returns `self`, so calls chain: `response.status(201).json(user.to_h)`.

## Path & Query Parameters

Path params use `{name}` syntax (optionally typed: `{id:int}`, `{slug:slug}`, `{uid:uuid}`).
`request.params` is an **indifferent-access** Hash — read a param with either a Symbol or a String
key. `request.body` (the parsed JSON/form body) uses **String** keys.

```ruby
Tina4.get "/users/{id}/posts/{post_id}" do |request, response|
  user_id = request.params[:id]          # Symbol key (indifferent access)
  post_id = request.params["post_id"]    # String key also works
  # ...
end

# GET /search?q=hello&page=2
Tina4.get "/search" do |request, response|
  query = request.params[:q] || ""
  page  = (request.params[:page] || "1").to_i
  # request.query is the query string as a Hash; request.body is the parsed body.
end
```

Typed params (`{id:int}`) are cast: an `int`/`integer` param arrives as an Integer, a `float`/`number`
as a Float. An unknown type name raises `ArgumentError` at route registration (a typo can't silently
match everything). A bare `*` or `*path` segment is a catch-all: `request.params["*"]` /
`request.params[:path]`.

## Middleware

Cross-cutting concerns (auth, logging) come in two Ruby forms.

**Class-based (global)** — define static `before_*` / `after_*` methods returning
`[request, response]`; halt by returning a response with a 4xx status or a literal `false`:

```ruby
# src/middleware/auth_check.rb
class AuthCheck
  def self.before_auth(request, response)
    token = request.headers["authorization"]
    return [request, response.json({ error: "Unauthorized" }, 401)] unless token
    [request, response]
  end
end

Tina4::Router.use(AuthCheck)   # register globally
```

**Block-based (global, path-scoped)** with `Tina4.before` / `Tina4.after`:

```ruby
Tina4.before("/admin/*") do |request, response|
  # runs before any /admin/* route
end
```

**Per-route middleware** — pass classes via `middleware:` on the registration, or chain `.middleware`:

```ruby
Tina4::Router.get("/protected", middleware: [AuthCheck]) do |request, response|
  response.json({ secret: "data" })
end
# `middleware:` is on `Tina4::Router.get` (`lib/tina4/router.rb:476`), NOT on the
# `Tina4.get` shortcut (`lib/tina4.rb:678` — signature is
# `(path, auth: nil, swagger_meta: {}, &block)`). Passing `middleware:` to the
# shortcut raises `ArgumentError: unknown keyword: :middleware`.

# or chain:
Tina4::Router.get("/protected") { |request, response| response.json({ ok: true }) }.middleware(AuthCheck)
```

> Middleware is **additive** — attaching middleware NEVER turns off the secure-by-default auth on a
> write route. To make a write route public you must explicitly call `.no_auth` (and pass
> `auth: false` when registered via `Tina4.post`).

## Route Groups

```ruby
Tina4::Router.group("/api/v1") do
  get("/users")  { |request, response| response.json(User.all) }
  post("/users") { |request, response| response.json(User.create(request.body).to_h, 201) }
end
```

`Tina4.group(prefix, auth: handler)` applies an auth handler to the whole group.

## Swagger / OpenAPI

Auto-generated at `/swagger`. Add per-route metadata via the `swagger_meta:` keyword:

```ruby
Tina4.get "/users", swagger_meta: {
  summary: "List all active users",
  tags: ["Users"],
  description: "Returns every active user"
} do |request, response|
  response.json(User.where("is_active = ?", [1]).map(&:to_h))
end
```

## CSRF / Form Token Protection

All state-changing browser forms must include a CSRF token. In a Frond template:

```twig
<form method="post" action="/contact">
    {{ form_token() }}
    <input type="text" name="name">
    <button type="submit">Send</button>
</form>
```

`{{ form_token() }}` renders a hidden `<input name="formToken" value="…">`. `frond.js`'s
`saveForm` attaches the token automatically for AJAX submissions.

**CSRF validation is OFF by default** — it is opt-in. `Tina4::CsrfMiddleware`
(`lib/tina4/middleware.rb:601`) is NOT attached to the pipeline unless
`TINA4_CSRF` is truthy (`middleware.rb:603`). To enable it:

```env
TINA4_CSRF=true
TINA4_SECRET=your-long-random-secret   # required — the middleware fails closed without it
```

Or attach it explicitly in `app.rb` / `config.rb`:

```ruby
Tina4::Router.use(Tina4::CsrfMiddleware)
```

Once enabled it validates `formToken` on every state-changing request and returns
`403 CSRF_INVALID` on a missing / invalid / expired token. Until you enable it
your forms submit without any CSRF check.

**Never skip CSRF protection on browser forms — enable it.**

## CORS

Built-in. Configure via `.env`, or add headers per response:
`response.add_cors_headers(origin: "https://app.example.com", credentials: true)`.

## Rate Limiting

Built-in via `Tina4::RateLimiter` (in `lib/tina4/rate_limiter.rb`). Sensible defaults need no config;
`RateLimiter#check(ip)` performs the check and returns a 429 when exceeded, and `before_rate_limit`
runs before it as middleware.
