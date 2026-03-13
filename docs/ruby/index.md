# Tina4 Ruby – Quick Reference

::: tip 🔥 Hot Tips
- Routes go in `routes/`, templates in `templates/`, static files in `public/`
- GET routes are public by default; use `secure_get`, `secure_post` etc. to require auth
- Return a `Hash` or `Array` from a route block and it auto-detects as JSON
- Run `tina4 start` to launch the dev server on port 7145
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
gem install tina4
tina4 init my-project
cd my-project
bundle install
tina4 start
```
[More details](installation.md) around project setup and customizations.

### Static Websites {#static-websites}
Put `.twig` files in `./templates` • assets in `./public`

```twig
<!-- templates/index.twig -->
<h1>Hello Static World</h1>
```
[More details](static-website.md) on static website routing.

### Basic Routing {#basic-routing}

```ruby
require "tina4"

Tina4.get "/" do |request, response|
  response.html "<h1>Hello Tina4 Ruby</h1>"
end

# POST requires Bearer auth by default
Tina4.post "/api" do |request, response|
  response.json({ data: request.params })
end

# Redirect after post
Tina4.post "/register" do |request, response|
  response.redirect "/welcome"
end
```
Follow the links for [basic routing](basic-routing.md#basic-routing) and [dynamic routing](basic-routing.md#dynamic-routing) with variables.

### Middleware {#middleware}

```ruby
Tina4.before "/api" do |request, response|
  # Runs before any route matching /api*
  Tina4::Debug.info("API request: #{request.path}")
end

Tina4.after do |request, response|
  # Runs after every route
  response.headers["X-Powered-By"] = "Tina4 Ruby"
end
```
Follow the links for more on [Middleware Declaration](middleware.md#declare) and [Pattern Matching](middleware.md#patterns).

### Template Rendering {#templates}

Put `.twig` files in `./templates` • assets in `./public`

```twig
<!-- templates/index.twig -->
<h1>Hello {{ name }}</h1>
```

```ruby
Tina4.get "/" do |request, response|
  response.render("index.twig", { name: "World!" })
end
```

### Sessions {#session-handling}

The default session handler is `FileHandler`. Override `SESSION_HANDLER` in `.env`.

| Handler | Backend | Required gem |
|---------|---------|-------------|
| `:file` (default) | File system | — |
| `:redis` | Redis | `redis` |
| `:mongo` | MongoDB | `mongo` |

```ruby
Tina4.get "/session/set" do |request, response|
  request.session["name"] = "Joe"
  request.session["info"] = { list: ["one", "two", "three"] }
  response.text "Session Set!"
end

Tina4.get "/session/get" do |request, response|
  name = request.session["name"]
  info = request.session["info"]
  response.json({ name: name, info: info })
end
```

### SCSS Stylesheets {#scss-stylesheets}

Drop in `./src/scss` → auto-compiled to `./public/css`

```scss
// src/scss/main.scss
$primary: #2c3e50;
body {
  background: $primary;
  color: white;
}
```
[More details](css.md) on CSS and SCSS.

### Environments {#environments}
Default development environment can be found in `.env`
```
PROJECT_NAME="My Project"
VERSION=1.0.0
TINA4_DEBUG_LEVEL=ALL
API_KEY=ABC1234
DATABASE_URL=sqlite3:data.db
```

```ruby
api_key = ENV["API_KEY"] || "ABC1234"
```

### Authentication {#authentication}

Pass `Authorization: Bearer <token>` to secured routes. JWT RS256 keys auto-generated in `.keys/`.

```ruby
# Public route
Tina4.get "/login" do |request, response|
  token = Tina4::Auth.generate_token({ "user_id" => 1 })
  response.json({ token: token })
end

# Secured route (requires Bearer token)
Tina4.secure_get "/profile" do |request, response|
  response.json({ message: "Welcome!" })
end
```

### HTML Forms and Tokens {#html-forms-and-tokens}

```twig
<form method="POST" action="/register">
    <input name="email">
    <button>Save</button>
</form>
```
[More details](posting-form-data.md) on posting form data.

### AJAX and tina4helper.js {#ajax}

Tina4 ships with a small javascript library to assist with AJAX calls.

[More details](tina4helper.md) on available features.

### OpenAPI and Swagger UI {#swagger}

Visit `http://localhost:7145/swagger`

```ruby
Tina4.get "/users", swagger_meta: { description: "Get all users" } do |request, response|
  response.json({ users: [] })
end
```
Follow the links for more on [Configuration](swagger.md#config), [Usage](swagger.md#usage) and [Metadata](swagger.md#metadata).

### Databases {#databases}

```ruby
# db = Tina4::Database.new("<connection_string>")
db = Tina4::Database.new("sqlite3:data.db")
```
Follow the links for more on [Available Connections](database.md#connections), [Core Methods](database.md#core-methods), [Usage](database.md#usage) and [Transactions](database.md#transactions).

### Database Results {#database-results}
```ruby
result = db.fetch("SELECT * FROM users", [], limit: 3, skip: 1)

array = result.to_a        # Array of hashes
json = result.to_json       # JSON string
csv = result.to_csv         # CSV string
```
Looking at detailed [Usage](database.md#usage) will improve deeper understanding.

### Migrations {#migrations}

```bash
tina4 migrate --create create_users_table
```

```sql
-- migrations/20260313120000_create_users_table.sql
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

```ruby
class User < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field  :name
  string_field  :email
end

User.create(name: "Alice", email: "alice@example.com")

user = User.find(1)
user.name = "Alice Wonder"
user.save
```
ORM functionality is extensive — see the [Advanced Detail](orm.md) for the full picture.

### CRUD {#crud}

```ruby
Tina4.get "/users/dashboard" do |request, response|
  users = User.all
  response.render("users/dashboard.twig", { users: users })
end
```
[More details](crud.md) on how CRUD works.

### Consuming REST APIs {#consuming-rest-apis}

```ruby
api = Tina4::API.new("https://api.example.com", auth_header: "Bearer xyz")
result = api.get("/users/42")
puts result.body
```
[More details](rest-api.md) are available on POST bodies, authorization headers, and API responses.

### Inline Testing {#inline-testing}

```ruby
Tina4.describe "Math operations" do
  it "adds numbers" do
    assert_equal 4, 2 + 2
  end
end
```

Run: `tina4 test`

### Websockets {#websockets}

```ruby
Tina4.get "/ws/chat" do |request, response|
  ws = Tina4::Websocket.new(request)
  ws.on_message do |data|
    ws.send("Echo: #{data}")
  end
  ws.start
end
```

### Queues {#queues}

Supports litequeue (default/SQLite), RabbitMQ, and Kafka backends.

```ruby
queue = Tina4::Queue.new(topic: "emails")
Tina4::Producer.new(queue).produce({ to: "alice@example.com", subject: "Welcome" })

consumer = Tina4::Consumer.new(queue)
consumer.each do |msg|
  puts msg.data
end
```

### WSDL {#wsdl}

```ruby
class Calculator < Tina4::WSDL
  service_url "http://localhost:7145/calculator"

  def add(a, b)
    { result: a + b }
  end
end
```

### Localization (i18n) {#localization}

Set `TINA4_LANGUAGE` in `.env` to change framework language.

```ruby
puts Tina4.t("server_stopped")  # "Server stopped." (en)
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">↑ Back to top</a>
</nav>
