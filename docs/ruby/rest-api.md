# Consuming REST APIs

::: tip 🔥 Hot Tips
- `Tina4::API` is a thin HTTP client for calling external APIs
- Supports GET, POST, PUT, PATCH, DELETE
- Auto-parses JSON responses
- Pass custom auth headers easily
:::

## Basic Usage

```ruby
require "tina4"

api = Tina4::API.new("https://api.example.com")

# GET
result = api.get("/users")
puts result.body          # Parsed response body
puts result.status_code   # HTTP status code
puts result.headers       # Response headers

# POST with JSON body
result = api.post("/users", body: { name: "Alice", email: "alice@example.com" })

# PUT
result = api.put("/users/1", body: { name: "Alice Updated" })

# DELETE
result = api.delete("/users/1")
```

## Authentication

```ruby
# Bearer token
api = Tina4::API.new("https://api.example.com", auth_header: "Bearer my-token")

# Custom headers
api = Tina4::API.new("https://api.example.com", headers: {
  "X-API-Key" => "secret123",
  "Accept" => "application/json"
})
```

## APIResponse Object

Every API call returns a `Tina4::APIResponse`:

| Property | Type | Description |
|----------|------|-------------|
| `body` | `String/Hash` | Response body (auto-parsed if JSON) |
| `status_code` | `Integer` | HTTP status code |
| `headers` | `Hash` | Response headers |
| `success?` | `Boolean` | `true` if status 2xx |

```ruby
result = api.get("/users/42")

if result.success?
  user = result.body
  puts user["name"]
else
  puts "Error: #{result.status_code}"
end
```

## Using in Routes

```ruby
Tina4.get "/api/weather/{city}" do |request, response|
  api = Tina4::API.new("https://wttr.in")
  result = api.get("/#{request.params['city']}?format=j1")

  if result.success?
    response.json(result.body)
  else
    response.json({ error: "Weather service unavailable" }, 502)
  end
end
```
