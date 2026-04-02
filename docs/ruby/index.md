# Tina4 Ruby -- Quick Reference

<div v-pre>


::: tip Hot Tips
- Route files live in `src/routes/`, templates in `src/templates/`, static files in `src/public/`
- GET routes are public by default; POST/PUT/PATCH/DELETE require a token (use `@noauth` to override)
- Return a `Hash` or `Array` from a route block and it auto-detects as JSON
- Run `tina4 serve` to launch the dev server on port 7147
- Chain `.secure` or `.cache` on any route for auth and caching
:::

<nav class="tina4-menu">
    <a href="#installation">Installation</a> •
    <a href="#static-websites">Static Websites</a> •
    <a href="#basic-routing">Routing</a> •
    <a href="#middleware">Middleware</a> •
    <a href="#templates">Templates</a> •
    <a href="#session-handling">Sessions</a> •
    <a href="#scss-stylesheets">SCSS</a> •
    <a href="#environments">Environments</a> •
    <a href="#authentication">Authentication</a> •
    <a href="#html-forms-and-tokens">Forms & Tokens</a> •
    <a href="#ajax">AJAX</a> •
    <a href="#swagger">OpenAPI</a> •
    <a href="#databases">Databases</a> •
    <a href="#database-results">Database Results</a> •
    <a href="#migrations">Migrations</a> •
    <a href="#orm">ORM</a> •
    <a href="#crud">CRUD</a> •
    <a href="#consuming-rest-apis">REST Client</a> •
    <a href="#inline-testing">Testing</a> •
    <a href="#websockets">Websockets</a> •
    <a href="#queues">Queues</a> •
    <a href="#graphql">GraphQL</a> •
    <a href="#wsdl">WSDL</a> •
    <a href="#localization">Localization</a>
</nav>

<style>
.tina4-menu {
  background: #2c3e50; color: white; padding: 1rem; border-radius: 8px; margin: 2rem 0; text-align: center; font-size: 1.1rem;
}
.tina4-menu a { color: #1abc9c; text-decoration: none; margin: 0 0.4rem; }
.tina4-menu a:hover { text-decoration: underline; }
</style>

### Installation {#installation}

```bash
gem install tina4ruby
tina4 init my-project
cd my-project
bundle install
tina4 serve
```
The server starts on port 7147. One gem. No dependency tree. [More details](installation.md) on project setup and customization.

### Static Websites {#static-websites}
Put `.html` templates in `./src/templates` and assets in `./src/public`.

```html
<!-- src/templates/index.html -->
<h1>Hello Static World</h1>
```
[More details](static-website.md) on static website routing.

### Basic Routing {#basic-routing}

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
Drop route files in `src/routes/`. Tina4 discovers them at startup. Follow the links for [basic routing](basic-routing.md#basic-routing) and [dynamic routing](basic-routing.md#dynamic-routing) with typed parameters.

### Middleware {#middleware}

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
Follow the links for more on [Middleware Declaration](middleware.md#declare) and [Pattern Matching](middleware.md#patterns).

### Template Rendering {#templates}

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

### Sessions {#session-handling}

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

### SCSS Stylesheets {#scss-stylesheets}

Drop files in `./src/public/scss` -- Tina4 compiles them to `./src/public/css`.

```scss
// src/public/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```
[More details](css.md) on CSS and SCSS.

### Environments {#environments}

The `.env` file sits at the project root. Tina4 reads it at startup.

```
TINA4_DEBUG=true
TINA4_PORT=7147
DATABASE_URL=sqlite:///data/app.db
TINA4_LOG_LEVEL=ALL
API_KEY=ABC1234
```

```ruby
api_key = ENV["API_KEY"] || "ABC1234"
```

### Authentication {#authentication}

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

### HTML Forms and Tokens {#html-forms-and-tokens}

```html
<form method="POST" action="/register">
    <input name="email">
    <button>Save</button>
</form>
```
[More details](posting-form-data.md) on posting form data.

### AJAX and frond.js {#ajax}

Tina4 ships with frond.js -- a zero-dependency JavaScript library for AJAX calls, form submissions, and real-time WebSocket connections.

[More details](/general/frond) on available features.

### OpenAPI and Swagger UI {#swagger}

Visit `http://localhost:7147/swagger` -- available when `TINA4_DEBUG=true`.

```ruby
# List all users
# @description Returns all registered users
# @tags Users
# @query int $page Page number (default: 1)
Tina4::Router.get("/api/users") do |request, response|
  response.json({ users: [] })
end
```
Follow the links for more on [Configuration](swagger.md#config), [Usage](swagger.md#usage) and [Metadata](swagger.md#metadata).

### Databases {#databases}

```ruby
# Configured via .env (default: sqlite:///data/app.db)
# Or create a connection in code:
db = Tina4::Database.new("sqlite://app.db")
db = Tina4::Database.new("postgres://localhost:5432/myapp", pool: 5)
```
Follow the links for more on [Available Connections](database.md#connections), [Core Methods](database.md#core-methods), [Usage](database.md#usage) and [Transactions](database.md#transactions).

### Database Results {#database-results}
```ruby
result = db.fetch("SELECT * FROM users", [], limit: 3, skip: 1)

array = result.to_a        # Array of hashes
json  = result.to_json     # JSON string
csv   = result.to_csv      # CSV string
```
Looking at detailed [Usage](database.md#usage) will deepen your understanding.

### Migrations {#migrations}

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
[Migrations](migrations.md) have rollback support and status tracking.

### ORM {#orm}

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
The ORM handles insert-or-update in a single `save` call. See the [Advanced Detail](orm.md) for the full picture.

### CRUD {#crud}

```ruby
Tina4::Router.get("/users/dashboard") do |request, response|
  users = User.all
  response.render("users/dashboard.html", { users: users })
end
```
[More details](crud.md) on how CRUD works.

### Consuming REST APIs {#consuming-rest-apis}

```ruby
api = Tina4::API.new("https://api.example.com", auth_header: "Bearer xyz")
result = api.get("/users/42")
puts result.body
```
[More details](rest-api.md) on POST bodies, authorization headers, and API responses.

### Inline Testing {#inline-testing}

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

### Websockets {#websockets}

Define WebSocket handlers the same way you define HTTP routes. The handler receives three arguments: `connection`, `event`, and `data`.

```ruby
Tina4::Router.websocket "/ws/echo" do |connection, event, data|
  if event == :message
    connection.send("Echo: #{data}")
  end
end
```

### Queues {#queues}

The file-based backend works out of the box. No Redis. No RabbitMQ.

```ruby
queue = Tina4::Queue.new(topic: "emails")

queue.push({
  to: "alice@example.com",
  subject: "Welcome",
  body: "Your account is ready."
})
```

### GraphQL {#graphql}

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

[Full details](graphql.md) on manual schema definition, mutations, variables, fragments, and programmatic usage.

### WSDL {#wsdl}

```ruby
class Calculator < Tina4::WSDL
  service_url "http://localhost:7147/calculator"

  def add(a, b)
    { result: a + b }
  end
end
```

### Localization (i18n) {#localization}

Set `TINA4_LANGUAGE` in `.env` to change the framework language.

```ruby
puts Tina4.t("server_stopped")  # "Server stopped." (en)
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">Back to top</a>
</nav>

</div>
