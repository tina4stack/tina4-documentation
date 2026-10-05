# Authentication & Services (Ruby)

## OpenID Connect SSO

Configure SSO in `.env`. The issuer drives discovery; do not build provider-specific adapters.

```ini
TINA4_SSO_ISSUER=https://identity.example.com/realms/my-app
TINA4_SSO_CLIENT_ID=my-app
TINA4_SSO_CLIENT_SECRET=replace-me
TINA4_SSO_REDIRECT_URI=https://app.example.com/auth/callback
TINA4_SSO_SCOPES=["openid", "profile", "email"]
TINA4_SSO_VERIFY=introspection
```

When configured, Tina4 mounts `GET /auth/login`, `GET /auth/callback`, and
`POST /auth/logout`. A route collision stops startup. Existing secured routes receive the
normalized identity through `request.user`; provider tokens stay inside reserved Session data.

```ruby
sso = Tina4::Sso.from_issuer
identity = sso.identity(request.session)
```

Use a provider recipe only to find its standards-based issuer and client settings. The runtime API
stays provider-neutral. In 3.13.104, introspection is the supported verification mode; `jwks` fails
during configuration until the application supplies a cryptography capability.

## JWT Authentication

All auth lives on the `Tina4::Auth` module. Ruby method names are snake_case.

### Setup

Set your secret in `.env`:
```env
TINA4_SECRET=a-long-random-string-here
```

Generate a strong secret with `openssl rand -hex 32`. In local dev (`TINA4_DEBUG=true`) a per-machine
secret is generated into `.env.local` automatically; in CI/production a blank secret triggers a loud
warning and JWT signing is insecure — always set `TINA4_SECRET` before serving traffic.

### The login route mints a token (public)

A write route is secure by default. Login must be public, so clear **both** auth gates:
`Tina4.post(..., auth: false)` (removes the bearer auth_handler) **and** `.no_auth` (clears the
write-method `auth_required` flag).

```ruby
# src/routes/auth.rb
Tina4.post("/api/login", auth: false) do |request, response|
  user = User.where("email = ?", [request.body["email"]]).first
  unless user && Tina4::Auth.check_password(request.body["password"], user.password)
    next response.json({ error: "Invalid credentials" }, 401)
  end
  token = Tina4::Auth.get_token({ "user_id" => user.id, "email" => user.email })
  response.json({ token: token })
end.no_auth
```

`get_token(payload, expires_in: 60, secret: nil)` returns a signed JWT (`expires_in` is in minutes).

### Protecting routes

POST/PUT/PATCH/DELETE are already protected (401 without a valid `Bearer` token). Inside a protected
handler, read the verified payload with `authenticate_request`:

```ruby
Tina4.post "/api/orders" do |request, response|
  auth = Tina4::Auth.authenticate_request(request.headers)   # verified payload Hash, or nil
  next response.json({ error: "Unauthorized" }, 401) unless auth
  order = Order.create({ **request.body, "user_id" => auth["user_id"] })
  response.json(order.to_h, 201)
end
```

To protect a **GET** route (public by default), register it with `Tina4.secure_get` instead of
`Tina4.get`, or attach an auth middleware.

Other `Tina4::Auth` helpers:
```ruby
Tina4::Auth.valid_token(token)      # => decoded payload Hash on success, nil on failure
Tina4::Auth.get_payload(token)      # decode WITHOUT verifying (read claims only)
Tina4::Auth.refresh_token(token)    # re-issue a fresh token if the current one is valid
```

### API-key auth

`authenticate_request` also accepts a static API key (timing-safe compared against `TINA4_API_KEY`).
To validate one directly, pass the expected value as the **keyword** `expected:`:

```ruby
Tina4::Auth.validate_api_key(provided_key, expected: ENV["TINA4_API_KEY"])
# expected: defaults to ENV["TINA4_API_KEY"] when omitted
```

### Password Hashing

```ruby
hashed  = Tina4::Auth.hash_password("mypassword")             # pbkdf2_sha256$...
matches = Tina4::Auth.check_password("mypassword", hashed)    # => true / false
```

`check_password(password, hash)` — plaintext first, stored hash second — timing-safe.

## Auth footguns

Tina4 Ruby is **secure by default**: `GET`/`HEAD`/`OPTIONS` are public, and
`POST`/`PUT`/`PATCH`/`DELETE` already require a `Bearer` token — the framework returns **401
automatically** when it's missing. Verified against `lib/tina4/router.rb` and `lib/tina4/auth.rb`.
Get these wrong and you either ship an unauthenticated write or fight phantom 401s.

### An unexpected 401 means "authenticate the request", not "open the route"

**`.no_auth` / `auth: false` are a LAST RESORT.** When a write route returns 401 in dev or from a
client, the fix is almost always to **send the Bearer token** the route legitimately requires — not
to strip its auth. A 401 on `POST /orders` means the request arrived without a valid token;
authenticate it (`Authorization: Bearer <token>`), don't bypass the guard.

Reserve opening a write route for endpoints that are *genuinely* public — login, register,
health-check, inbound webhooks — and clear **both** write gates (a write registered with
`Tina4.post` is protected by (1) a bearer `auth_handler` and (2) the router's `auth_required`
flag):

```ruby
# login is public — clear BOTH gates: auth: false (drop the handler) + .no_auth (clear the flag)
Tina4.post("/api/login", auth: false) do |request, response|
  # ...validate credentials, mint a token...
end.no_auth
```

* **Never blanket `.no_auth` to silence 401s.** Slapping it on every write route that returns 401
  doesn't "fix auth" — it **ships unauthenticated writes**. If you do open a route, the handler MUST
  still authenticate another way (a webhook validated by signature, a SOAP/WS-Security endpoint
  validating credentials inside the handler, or an explicitly anonymous read API).
* **Never make public** something that writes data, costs money, returns another user's data,
  uploads a file, or is an admin action *without* its own check.

### `swagger_meta` security documents a route — it does NOT enforce

The real gate is the **method default + the route's `auth_handler`** (and `.no_auth` / `auth: false`
to opt out). A route's `swagger_meta: { security: … }` only annotates the **OpenAPI spec** — it
**never changes enforcement** (`swagger.rb:316` checks `route.auth_required || route.auth_handler` for the *actual* security
requirement; `swagger_meta[:security]` just overrides what Swagger *displays*). So documenting
`security` on a public-by-default `GET` leaves the route open while Swagger *claims* it's secured —
the worst kind of drift.

```ruby
# To actually protect a GET (public by default), register it as a secured route —
# NOT by adding swagger_meta security:
Tina4.secure_get("/reports") do |request, response|   # real gate: requires a valid token
  # ...
end
```

* **Breaks:** relying on `swagger_meta: { security: "bearerAuth" }` alone to protect a `GET` — the
  route stays open, only the docs change.

## Sessions

Configure the backend in `.env`:
```env
TINA4_SESSION_BACKEND=file    # file, redis, valkey, mongodb, memcached, database (aliases: filesystem, mongo, memcache, db)
```

`request.session` supports both `get`/`set` and `[]`/`[]=`:

```ruby
Tina4.post("/login", auth: false) do |request, response|
  # ...after validating credentials...
  request.session.set("user_id", user.id)      # or request.session["user_id"] = user.id
  response.redirect("/dashboard")
end.no_auth

Tina4.get "/dashboard" do |request, response|
  user_id = request.session.get("user_id")      # or request.session["user_id"]
  next response.redirect("/login") unless user_id
  response.render("dashboard.twig", { user: User.find_by_id(user_id) })
end

Tina4.get "/logout" do |request, response|
  request.session.clear
  response.redirect("/")
end
```

## Queue System

For background jobs — sending emails, processing uploads, external API calls. Create a queue with
`Tina4::Queue.new(topic: "...")`.

### Producing

```ruby
Tina4.post "/orders" do |request, response|
  order = Order.create(request.body)
  Tina4::Queue.new(topic: "order-emails").push({
    "order_id" => order.id,
    "email"    => request.body["email"],
    "type"     => "confirmation"
  })
  response.json(order.to_h, 201)
end
```

`push(payload, priority: 0, delay_seconds: 0)` — higher `priority` runs first; `delay_seconds` defers
the job. There's also `produce(topic, payload, priority:, delay_seconds:)`.

### Consuming (background worker)

```ruby
Tina4::Queue.new(topic: "order-emails").consume do |job|
  send_order_email(job.payload)
  job.complete            # ack; use job.fail("reason") to nack, job.retry to requeue
end
```

`consume(topic = nil, id: nil, poll_interval: 1.0, iterations: 0, batch_size: 1)` loops and yields each `Job`.
A `Job` exposes `payload`, `topic`, `attempts`, and `complete` / `fail(reason)` / `retry`. For a
single controlled pass use `process(max_jobs:, batch_size:) { |job| ... }`.

## Email (Messenger)

```ruby
Tina4.post "/contact", auth: false do |request, response|
  Tina4::Messenger.new.send(
    to: request.body["email"],
    subject: "Thanks for reaching out",
    body: "<h1>We received your message</h1>",
    html: true                          # note: html:, not is_html:
  )
  response.json({ status: "sent" })
end.no_auth
```

`send(to:, subject:, body:, html: false, cc: [], bcc: [], ...)` — all keyword arguments.

## WebSocket

Register a WebSocket route with `Tina4.websocket`. The handler block receives
`(connection, event, data)` where `event` is `:open`, `:message`, or `:close` and `data` is the
String payload for `:message`.

```ruby
# Server — public by default; use Tina4.secure_websocket (or .secure) to require a JWT on upgrade
Tina4.websocket "/ws/chat" do |connection, event, data|
  case event
  when :open
    connection.send("welcome")
  when :message
    connection.broadcast(data)         # send to all connected clients
  when :close
    # cleanup
  end
end
```

```javascript
// Client (frond.js)
const ws = Frond.ws("/ws/chat", {
  reconnect: true,
  onMessage: (data) => { document.getElementById("messages").innerHTML += `<p>${data}</p>`; }
});
document.getElementById("send").onclick = () => ws.send(document.getElementById("input").value);
```

## GraphQL

Auto-generate a GraphQL API from your ORM models:

```ruby
gql = Tina4::GraphQL.new
gql.auto_register(User, Post)
gql.register_route("/graphql")     # GET = GraphiQL IDE, POST = queries
```

Decorator-free resolvers register on the schema:
```ruby
Tina4::GraphQL.resolve("Query", "userByEmail") do |root, args, ctx|
  User.where("email = ?", [args["email"]]).first
end
```

Visit `/graphql` in the browser for the GraphiQL IDE.

## Events

Decouple app logic with events on `Tina4::Events`:

```ruby
Tina4::Events.on("user.created") do |data|
  Tina4::Messenger.new.send(to: data["email"], subject: "Welcome!", body: "...")
end

Tina4::Events.on("user.created") do |data|
  Settings.create({ "user_id" => data["id"], "theme" => "light" })
end

# Fire the event:
Tina4.post "/register", auth: false do |request, response|
  user = User.create(request.body)
  Tina4::Events.emit("user.created", { "id" => user.id, "email" => user.email })
  response.json(user.to_h, 201)
end.no_auth
```

`on(event, priority: 0, &block)` — higher priority runs first. `emit(event, *args)` fires all
listeners; `emit_async` runs them off the request path.

## i18n / Localization

Translation files go in `src/locales/` as JSON:
```json
// src/locales/en.json
{ "welcome": "Welcome, {name}!", "logout": "Sign out" }
```

Set the language in `.env` (`TINA4_LOCALE=en`). In code: `Tina4.t("welcome", name: user.name)`. In
templates:
```twig
{{ "welcome" | trans({"name": user.name}) }}
{{ "logout" | trans }}
```

## Caching

Built-in, zero-dep caching. Two classes cover the surface: `Tina4::QueryCache`
(`lib/tina4/cache.rb:13`) is the in-memory TTL/tagged store; `Tina4::ResponseCache`
(`lib/tina4/response_cache.rb:39`) is the GET-response middleware. Module-level
API for direct KV use: `Tina4.cache_get / cache_set / cache_delete / cache_stats
/ clear_cache` (`lib/tina4/response_cache.rb:191, 220, 235, 242, 256`). There is
no `Tina4::Cache` class — writing `Tina4::Cache.new(...)` raises `NameError`.
Use `{% cache %}` blocks in templates (see
`templates-and-frontend.md`), or the cache API in code for expensive operations.
