# Swagger & Swagger UI {#config}

::: tip 🔥 Hot Tips
- Visit `/swagger` to see the interactive Swagger UI
- Visit `/swagger.json` for the raw OpenAPI 3.0.3 spec
- Add metadata via `swagger_meta:` on any route
:::

Tina4 Ruby auto-generates OpenAPI 3.0.3 documentation from your registered routes.

## Configuration {#configuration}

Set environment variables in `.env`:

```env
SWAGGER_TITLE=My API
SWAGGER_DESCRIPTION=Auto-generated API documentation
SWAGGER_VERSION=1.0.0
SWAGGER_CONTACT=Tina4 Team
SWAGGER_CONTACT_URL=https://tina4.com
SWAGGER_CONTACT_EMAIL=support@tina4.com
```

## Usage {#usage}

Simply define routes — they appear in Swagger automatically:

```ruby
Tina4.get "/api/users" do |request, response|
  response.json({ users: [] })
end
```

## Adding Metadata {#metadata}

Use the `swagger_meta:` keyword to enrich your API docs:

```ruby
Tina4.get "/api/users", swagger_meta: {
  description: "Retrieve all users",
  summary: "List users",
  tags: ["Users"],
  params: { page: "Page number", limit: "Items per page" },
  example_response: { users: [{ id: 1, name: "Alice" }] }
} do |request, response|
  response.json({ users: [] })
end
```

### POST/PUT with Request Body

```ruby
Tina4.post "/api/users", swagger_meta: {
  description: "Create a new user",
  tags: ["Users"],
  secure: true,
  example: { name: "Alice", email: "alice@example.com" },
  example_response: { id: 1, name: "Alice", status: "active" }
} do |request, response|
  user = User.create(request.json_body)
  response.json(user.to_hash, 201)
end
```

## Metadata Options

| Key | Type | Description |
|-----|------|-------------|
| `description` | `String` | Detailed description of the endpoint |
| `summary` | `String` | Short one-line summary |
| `tags` | `Array` | Grouping tags for Swagger UI |
| `params` | `Hash` | Query parameter descriptions |
| `example` | `Hash` | Request body example (POST/PUT/PATCH) |
| `example_response` | `Hash` | Response body example |
| `secure` | `Boolean` | Marks route as requiring auth |

## Secured Routes in Swagger

Secured routes automatically show a lock icon and 401 response:

```ruby
Tina4.secure_get "/api/profile", swagger_meta: {
  description: "Get current user profile",
  secure: true
} do |request, response|
  response.json({ user: "authenticated" })
end
```
