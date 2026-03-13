# Forms & Tokens

::: tip 🔥 Hot Tips
- Access form data via `request.form_data` (Hash)
- Access file uploads via `request.files`
- JSON body is available via `request.json_body`
:::

## Basic Forms

```twig
<!-- templates/register.twig -->
<form method="POST" action="/register">
    <input name="name" placeholder="Name">
    <input name="email" type="email" placeholder="Email">
    <button type="submit">Register</button>
</form>
```

```ruby
Tina4.get "/register" do |request, response|
  response.render("register.twig")
end

Tina4.post "/register" do |request, response|
  name = request.form_data["name"]
  email = request.form_data["email"]
  # Process registration...
  response.redirect "/welcome"
end
```

## JSON API Bodies

```ruby
Tina4.post "/api/users" do |request, response|
  data = request.json_body   # Auto-parsed JSON
  name = data["name"]
  email = data["email"]
  response.json({ created: true, name: name })
end
```

## File Uploads

```twig
<form method="POST" action="/upload" enctype="multipart/form-data">
    <input name="avatar" type="file">
    <button type="submit">Upload</button>
</form>
```

```ruby
Tina4.post "/upload" do |request, response|
  file = request.files["avatar"]
  if file
    File.binwrite("public/uploads/#{file[:filename]}", file[:data])
    response.json({ uploaded: file[:filename] })
  else
    response.json({ error: "No file" }, 400)
  end
end
```

## Error Handling

```ruby
Tina4.post "/api/users" do |request, response|
  data = request.json_body

  if data["name"].nil? || data["name"].empty?
    return response.json({ error: "Name is required" }, 400)
  end

  user = User.create(data)
  if user.persisted?
    response.json(user.to_hash, 201)
  else
    response.json({ errors: user.errors }, 422)
  end
end
```
