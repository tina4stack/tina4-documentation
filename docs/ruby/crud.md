# CRUD

::: tip 🔥 Hot Tips
- Combine ORM models with routes for instant REST APIs
- Use `response.render` with templates for server-rendered CRUD
- Return `to_hash` from ORM instances for JSON APIs
:::

## JSON API CRUD

Build a full REST API in minutes:

```ruby
require "tina4"

class User < Tina4::ORM
  integer_field :id, primary_key: true, auto_increment: true
  string_field :name
  string_field :email
end

# List all
Tina4.get "/api/users" do |request, response|
  users = User.all(limit: 50)
  response.json(users.map(&:to_hash))
end

# Get one
Tina4.get "/api/users/{id:int}" do |request, response|
  user = User.find(request.params["id"])
  user ? response.json(user.to_hash) : response.json({ error: "Not found" }, 404)
end

# Create
Tina4.post "/api/users" do |request, response|
  user = User.create(request.json_body)
  if user.persisted?
    response.json(user.to_hash, 201)
  else
    response.json({ errors: user.errors }, 422)
  end
end

# Update
Tina4.put "/api/users/{id:int}" do |request, response|
  user = User.find(request.params["id"])
  return response.json({ error: "Not found" }, 404) unless user

  request.json_body.each { |k, v| user.send("#{k}=", v) if user.respond_to?("#{k}=") }
  user.save
  response.json(user.to_hash)
end

# Delete
Tina4.delete "/api/users/{id:int}" do |request, response|
  user = User.find(request.params["id"])
  return response.json({ error: "Not found" }, 404) unless user

  user.delete
  response.json({ deleted: true })
end
```

## Template-Based CRUD

Render with Twig templates for server-side HTML:

```ruby
Tina4.get "/users" do |request, response|
  users = User.all
  response.render("users/index.twig", { users: users.map(&:to_hash) })
end

Tina4.get "/users/{id:int}" do |request, response|
  user = User.find(request.params["id"])
  response.render("users/show.twig", { user: user.to_hash })
end
```

```twig
<!-- templates/users/index.twig -->
{% extends "base.twig" %}
{% block content %}
<table class="table">
  <tr><th>ID</th><th>Name</th><th>Email</th></tr>
  {% for user in users %}
  <tr>
    <td>{{ user.id }}</td>
    <td>{{ user.name }}</td>
    <td>{{ user.email }}</td>
  </tr>
  {% endfor %}
</table>
{% endblock %}
```

## Secured CRUD

Protect write operations with JWT authentication:

```ruby
# Public read
Tina4.get "/api/users" do |request, response|
  response.json(User.all.map(&:to_hash))
end

# Protected write
Tina4.secure_post "/api/users" do |request, response|
  user = User.create(request.json_body)
  response.json(user.to_hash, 201)
end

Tina4.secure_delete "/api/users/{id:int}" do |request, response|
  User.find(request.params["id"])&.delete
  response.json({ deleted: true })
end
```
