# Tina4 Ruby - Quick Reference

::: tip 🔥 Hot Tips

* Route files live in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
* GET routes are public by default; POST/PUT/PATCH/DELETE require a token (use `@noauth` to override)
* Return a `Hash` or `Array` from a route block and it auto-detects as JSON
* Run `tina4 serve` to launch the dev server on port 7147
* Chain `.secure` or `.cache` on any route for auth and caching
:::

[Installation](index.md#installation) • [Static Websites](index.md#static-websites) • [Routing](index.md#basic-routing) • [Middleware](index.md#middleware) • [Templates](index.md#templates) • [Sessions](index.md#session-handling) • [SCSS](index.md#scss-stylesheets) • [Environments](index.md#environments) • [Authentication](index.md#authentication) • [Forms & Tokens](index.md#html-forms-and-tokens) • [AJAX](index.md#ajax) • [OpenAPI](index.md#swagger) • [Databases](index.md#databases) • [Database Results](index.md#database-results) • [Migrations](index.md#migrations) • [ORM](index.md#orm) • [CRUD](index.md#crud) • [REST Client](index.md#consuming-rest-apis) • [Testing](index.md#inline-testing) • [Services](index.md#services) • [Websockets](index.md#websockets) • [Queues](index.md#queues) • [WSDL](index.md#wsdl) • [GraphQL](index.md#graphql) • [Localization](index.md#localization) • [HTML Builder](index.md#html-builder) • [Events](index.md#events) • [Logging](index.md#logging) • [Cache](index.md#response-cache) • [Health](index.md#health) • [DI Container](index.md#container) • [Error Overlay](index.md#error-overlay) • [Dev Admin](index.md#dev-admin) • [CLI](index.md#cli) • [MCP](index.md#mcp) • [FakeData](index.md#fakedata)

### Installation <a href="#installation" id="installation"></a>

```bash
# Install the tina4 CLI once. Windows: irm https://tina4.com/install.ps1 | iex
curl -fsSL https://tina4.com/install.sh | sh

tina4 init ruby my-app
cd my-app
tina4 serve
```

The server starts on port 7147. One gem. No dependency tree. [More details](01-getting-started.md) on project setup and customization.

### Static Websites <a href="#static-websites" id="static-websites"></a>

Put `.html` templates in `./src/templates` and assets in `./src/public`.

```html
<!-- src/templates/index.html -->
<h1>Hello Static World</h1>
```

[More details](04-templates.md) on static website routing.

### Basic Routing <a href="#basic-routing" id="basic-routing"></a>

```ruby
Tina4::Router.get("/") do |request, response|
  response.html "<h1>Hello Tina4 Ruby</h1>"
end

Tina4::Router.post("/api/items") do |request, response|
  name = request.body["name"] || ""
  response.json({ name: name }, 201)
end

Tina4::Router.get("/users/{id:int}") do |request, response|
  id = request.params[:id]
  response.json({ user_id: id })
end
```

Drop route files in `src/routes/`. Tina4 discovers them at startup. Follow the links for [basic routing](02-routing.md) and [dynamic routing](02-routing.md) with typed parameters.

### Middleware <a href="#middleware" id="middleware"></a>

```ruby
log_request = lambda do |request, response, next_handler|
  $stderr.puts "#{request.method} #{request.path}"
  next_handler.call(request, response)
end

Tina4::Router.get("/api/data", middleware: "log_request") do |request, response|
  response.json({ data: [1, 2, 3] })
end

# Apply middleware to a group
Tina4::Router.group("/api/admin", middleware: "require_auth") do
  Tina4::Router.get("/dashboard") do |request, response|
    response.json({ page: "admin dashboard" })
  end
end
```

Follow the links for more on [Middleware Declaration](10-middleware-security.md) and [Pattern Matching](10-middleware-security.md).

### Template Rendering <a href="#templates" id="templates"></a>

Put `.html` templates in `./src/templates` and assets in `./src/public`.

```html
<!-- src/templates/greeting.html -->
<h1>Hello {{ name }}</h1>
```

```ruby
Tina4::Router.get("/") do |request, response|
  response.render("greeting.html", { name: "World" })
end
```

### Sessions <a href="#session-handling" id="session-handling"></a>

Sessions start on their own. Every route handler receives `request.session` ready to use.

```ruby
Tina4::Router.get("/session/set") do |request, response|
  request.session.set("name", "Joe")
  request.session.set("info", { list: ["one", "two", "three"] })
  response.text "Session set."
end

Tina4::Router.get("/session/get") do |request, response|
  name = request.session.get("name", "Guest")
  info = request.session.get("info", {})
  response.json({ name: name, info: info })
end
```

### SCSS Stylesheets <a href="#scss-stylesheets" id="scss-stylesheets"></a>

Drop files in `./src/public/scss`, Tina4 compiles them to `./src/public/css`.

```scss
// src/public/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```

[More details](17-frontend.md) on CSS and SCSS.

### Environments <a href="#environments" id="environments"></a>

The `.env` file sits at the project root. Tina4 reads it at startup.

```
TINA4_DEBUG=true
TINA4_PORT=7147
TINA4_DATABASE_URL=sqlite:///data/app.db
TINA4_LOG_LEVEL=ALL
TINA4_API_KEY=ABC1234
```

```ruby
api_key = ENV["TINA4_API_KEY"] || "ABC1234"
```

Access env vars programmatically:

```ruby
Tina4::Env.load_env                          # Load .env file (auto on server start)
Tina4::Env.get_env("TINA4_DATABASE_URL")           # Get value or nil
Tina4::Env.get_env("PORT", "7147")           # Get value with default
Tina4::Env.has_env?("TINA4_DEBUG")           # true if set
Tina4::Env.require_env!("TINA4_DATABASE_URL")      # Raises KeyError if missing
Tina4::Env.truthy?(ENV["TINA4_DEBUG"])       # true for "true", "1", "yes"
```

### Authentication <a href="#authentication" id="authentication"></a>

Tina4 uses JWT tokens. Keys auto-generate in `.keys/`. GET routes are public. POST/PUT/PATCH/DELETE require a bearer token by default.

```ruby
# Public login route
Tina4::Router.post("/login") do |request, response|
  token = Tina4::Auth.get_token({ user_id: 1, role: "admin" })
  response.json({ token: token })
end

# Secured GET route (chain .secure)
Tina4::Router.get("/api/profile") do |request, response|
  response.json({ user: request.user })
end.secure

# Or use the @secured decorator
# @secured
Tina4::Router.get("/api/account") do |request, response|
  response.json({ account: request.user })
end
```

### HTML Forms and Tokens <a href="#html-forms-and-tokens" id="html-forms-and-tokens"></a>

```html
<form method="POST" action="/register">
    <input name="email">
    <button>Save</button>
</form>
```

[More details](03-request-response.md) on posting form data.

### AJAX and frond.js <a href="#ajax" id="ajax"></a>

Tina4 ships with frond.js, a zero-dependency JavaScript library for AJAX calls, form submissions, and real-time WebSocket connections.

[More details](https://github.com/tina4stack/tina4-documentation/blob/main/general/frond.md) on available features.

### OpenAPI and Swagger UI <a href="#swagger" id="swagger"></a>

Visit `http://localhost:7147/swagger`, available when `TINA4_DEBUG=true`.

```ruby
# List all users
# @description Returns all registered users
# @tags Users
# @query int $page Page number (default: 1)
Tina4::Router.get("/api/users") do |request, response|
  response.json({ users: [] })
end
```

Follow the links for more on [Configuration](20-swagger.md), [Usage](20-swagger.md) and [Metadata](20-swagger.md).

### Databases <a href="#databases" id="databases"></a>

```ruby
# Configured via .env (default: sqlite:///data/app.db)
# Or create a connection in code:
db = Tina4::Database.new("sqlite://app.db")
db = Tina4::Database.new("postgres://localhost:5432/myapp", pool: 5)
```

Follow the links for more on [Available Connections](05-database.md), [Core Methods](05-database.md), [Usage](05-database.md) and [Transactions](05-database.md).

### Database Results <a href="#database-results" id="database-results"></a>

```ruby
result = db.fetch("SELECT * FROM users", [], limit: 3, skip: 1)

array = result.to_a        # Array of hashes
json  = result.to_json     # JSON string
csv   = result.to_csv      # CSV string
```

Looking at detailed [Usage](05-database.md) will deepen your understanding.

### Migrations <a href="#migrations" id="migrations"></a>

```bash
tina4 migrate --create create_users_table
```

```sql
-- src/migrations/20260313120000_create_users_table.sql
CREATE TABLE users (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT
);
```

```bash
tina4 migrate
```

[Migrations](05-database.md) have rollback support and status tracking.

### ORM <a href="#orm" id="orm"></a>

ORM models live in `src/orm/`. Tina4 auto-loads every `.rb` file in that directory.

```ruby
class User < Tina4::ORM
  integer_field :id, primary_key: true
  string_field  :name
  string_field  :email

  table_name "users"
end

user = User.new
user.name = "Alice"
user.email = "alice@example.com"
user.save

found = User.find(1)
found.name = "Alice Wonder"
found.save
```

The ORM handles insert-or-update in a single `save` call. See the [Advanced Detail](06-orm.md) for the full picture.

### CRUD <a href="#crud" id="crud"></a>

```ruby
Tina4::Router.get("/users/dashboard") do |request, response|
  users = User.all
  response.render("users/dashboard.html", { users: users })
end
```

[More details](19-scaffolding.md) on how CRUD works.

### Consuming REST APIs <a href="#consuming-rest-apis" id="consuming-rest-apis"></a>

```ruby
api = Tina4::API.new("https://api.example.com", auth_header: "Bearer xyz")
result = api.get("/users/42")
puts result.body
```

[More details](21-api-client.md) on POST bodies, authorization headers, and API responses.

### Inline Testing <a href="#inline-testing" id="inline-testing"></a>

Tina4 uses RSpec. Tests live in `tests/`. Every `_spec.rb` file is auto-discovered.

```ruby
require "tina4"

RSpec.describe "Math operations" do
  it "adds numbers" do
    expect(2 + 2).to eq(4)
  end
end
```

Run: `tina4 test`

### Services <a href="#services" id="services"></a>

```ruby
class CacheWarmer < Tina4::Service
  def run
    Tina4::Log.info("Warming cache...")
    # Your background work here
    sleep 60
  end
end

Tina4::ServiceRunner.register(CacheWarmer.new)
Tina4::ServiceRunner.start_all
```

### Websockets <a href="#websockets" id="websockets"></a>

Define WebSocket handlers the same way you define HTTP routes. The handler receives three arguments: `connection`, `event`, and `data`.

```ruby
Tina4::Router.websocket "/ws/echo" do |connection, event, data|
  if event == :message
    connection.send("Echo: #{data}")
  end
end
```

### Queues <a href="#queues" id="queues"></a>

The file-based backend works out of the box. No Redis. No RabbitMQ.

```ruby
queue = Tina4::Queue.new(topic: "emails")

queue.push({
  to: "alice@example.com",
  subject: "Welcome",
  body: "Your account is ready."
})
```

### WSDL <a href="#wsdl" id="wsdl"></a>

```ruby
class Calculator < Tina4::WSDL
  service_url "http://localhost:7147/calculator"

  def add(a, b)
    { result: a + b }
  end
end
```

### GraphQL <a href="#graphql" id="graphql"></a>

Tina4 includes a built-in GraphQL engine. No external gems.

```ruby
schema = Tina4::GraphQLSchema.new
gql = Tina4::GraphQL.new(schema)
gql.register_route  # POST /graphql, GET /graphql (playground)
```

POST queries to `/graphql`, or visit it in a browser for the GraphiQL IDE.

```graphql
{ users(limit: 5) { id name email } }
```

[Full details](22-graphql.md) on manual schema definition, mutations, variables, fragments, and programmatic usage.

### Localization (i18n) <a href="#localization" id="localization"></a>

Set `TINA4_LOCALE` in `.env` to change the framework language.

```ruby
puts Tina4.t("server_stopped")  # "Server stopped." (en)
```

[Back to top](index.md)

### HTML Builder <a href="#html-builder" id="html-builder"></a>

```ruby
el = Tina4::HtmlElement.new("div", { class: "card" }, ["Hello"])
el.to_s  # => '<div class="card">Hello</div>'

# Nesting with call
card = Tina4::HtmlElement.new("div").call(
  { class: "card" },
  Tina4::HtmlElement.new("h2").call("Title"),
  Tina4::HtmlElement.new("p").call("Content"),
)

# Helper methods
include Tina4::HtmlHelpers
html = _div({ class: "card" }, _h1("Title"), _p("Description"))
```

### Events <a href="#events" id="events"></a>

```ruby
# Subscribe to an event
Tina4::Events.on("user.created") do |payload|
  puts "New user: #{payload[:name]}"
end

# Subscribe once - auto-removes after first fire
Tina4::Events.once("app.boot") do |payload|
  puts "App booted at #{payload[:time]}"
end

# Emit an event anywhere in the app
Tina4::Events.emit("user.created", { name: "Alice", id: 42 })
```

Events are synchronous by default. Emit inside a service to run them off the request thread.

### Logging <a href="#logging" id="logging"></a>

```ruby
Tina4::Log.info("Server ready on port 7147")
Tina4::Log.debug("Params: #{request.params.inspect}")
Tina4::Log.warning("Deprecated method called")
Tina4::Log.error("Database connection failed")
```

Set `TINA4_LOG_LEVEL=ALL` in `.env` to see every level. Production default is `INFO`. Log output goes to stdout and to `logs/tina4.log`.

### Response Cache <a href="#response-cache" id="response-cache"></a>

```ruby
# Cache for 60 seconds (default)
Tina4::Router.get("/api/products") do |request, response|
  response.json({ products: Product.all })
end.cache

# Custom TTL in seconds
Tina4::Router.get("/api/summary") do |request, response|
  response.json({ total: Order.count })
end.cache(300)

# Cache is keyed on method + path + query string.
# Clear all cached responses:
Tina4::Cache.flush
```

### Health Endpoint <a href="#health" id="health"></a>

Tina4 registers `/health` automatically. No setup needed.

```bash
curl http://localhost:7147/health
```

```json
{ "status": "ok", "uptime": 142, "version": "3.10.20" }
```

The response includes framework version, uptime in seconds, and database connectivity when a `TINA4_DATABASE_URL` is configured. Use this endpoint for container liveness and readiness probes.

### DI Container <a href="#container" id="container"></a>

```ruby
# Register a service by name
Tina4::Container.register(:mailer) { Mailer.new(ENV["TINA4_MAIL_HOST"]) }

# Register a singleton (resolved once, reused everywhere)
Tina4::Container.register(:config, singleton: true) { AppConfig.load }

# Resolve anywhere in the app
mailer = Tina4::Container.resolve(:mailer)
mailer.send_welcome(user)
```

Registrations are lazy: the block runs on first `.resolve`. Singletons cache the result for the lifetime of the process.

### Error Overlay <a href="#error-overlay" id="error-overlay"></a>

When `TINA4_DEBUG=true`, unhandled exceptions render an in-browser overlay.

```
TINA4_DEBUG=true
```

The overlay shows the exception class, message, and a syntax-highlighted stack trace with source lines. It replaces the default HTML error page only in debug mode. In production the framework returns a plain `500` response and writes the full trace to the log.

### Dev Admin <a href="#dev-admin" id="dev-admin"></a>

```
http://localhost:7147/__dev
```

The `/__dev` dashboard is available when `TINA4_DEBUG=true`. It lists every registered route (method, path, middleware, auth), active services, queue depths, and recent log lines. No configuration needed: visit the URL after `tina4 serve` starts.

### CLI Commands <a href="#cli" id="cli"></a>

```bash
tina4 init ruby my-project   # Scaffold a new Ruby project
tina4 serve                  # Start dev server (port 7147, live reload)
tina4 serve --port 8080      # Custom port
tina4 migrate                # Run pending SQL migrations
tina4 migrate --create name  # Generate a timestamped migration file
tina4 test                   # Run the RSpec test suite
tina4 build                  # Compile SCSS, bundle assets for production
tina4 routes                 # Print all registered routes to stdout
```

### MCP Server <a href="#mcp" id="mcp"></a>

Tina4 starts an MCP (Model Context Protocol) server automatically when `TINA4_DEBUG=true`.

```
http://localhost:7147/__mcp
```

```ruby
# Register a custom MCP tool
Tina4::MCP.register_tool("get_user") do |params|
  user = User.find(params["id"].to_i)
  { id: user.id, name: user.name }
end
```

AI agents connect to `/__mcp` and discover routes, ORM models, and registered tools. Disable with `TINA4_MCP=false` in `.env`.

### FakeData <a href="#fakedata" id="fakedata"></a>

```ruby
fake = Tina4::FakeData.new

puts fake.name          # "Liam Torres"
puts fake.email         # "liam.torres@example.com"
puts fake.phone         # "+1-555-0147"
puts fake.address       # "12 Elm Street, Springfield"
puts fake.company       # "Bright Horizon Ltd"
puts fake.paragraph     # Lorem-style filler text
puts fake.integer(1, 100) # Random integer between 1 and 100
puts fake.uuid          # "a3f1c2d4-..."

# Seed for reproducible data
fake = Tina4::FakeData.new(seed: 42)
```

Use `FakeData` in tests and migrations to generate consistent fixture data without external gems.

***

## 📕 Download the book

[**Tina4 for Ruby Developers** (PDF)](https://github.com/tina4stack/tina4-documentation/blob/main/pdfs/Tina4-for-Ruby-Developers.pdf): full reference, printable, with clickable table of contents and PDF outline. Regenerated with every release.
