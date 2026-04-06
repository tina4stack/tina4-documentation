# Chapter 3: Request & Response

## 1. The Two Objects You Use Everywhere

Every route handler receives two arguments: `request` and `response`. The request carries what the client sent. The response builds what you send back. These two objects handle every HTTP scenario you will face.

A file-sharing service shows the pattern. A user uploads a document. You validate the file type. You check the session. You return success JSON or an error page. Every step flows through `request` and `response`.

```ruby
Tina4::Router.get("/echo") do |request, response|
  response.json({
    method: request.method,
    path: request.path,
    your_ip: request.ip
  })
end
```

```bash
curl http://localhost:7147/echo
```

```json
{"method":"GET","path":"/echo","your_ip":"127.0.0.1"}
```

The pattern holds for every route: inspect the request, build the response, return it.

---

## 2. The Request Object

The `request` object opens every piece of the incoming HTTP request. Headers, body, cookies, files, IP address -- all accessible through named properties.

### method

The HTTP method arrives as an uppercase string:

```ruby
Tina4::Router.get("/api/check") do |request, response|
  response.json({ method: request.method })
end
```

```bash
curl http://localhost:7147/api/check
```

```json
{"method":"GET"}
```

### path

The URL path strips query parameters:

```ruby
# Request to /api/users?page=2
request.path # "/api/users"
```

### params

Path parameters from the URL pattern (see Chapter 2). The parameter names match the `{name}` placeholders in the route:

```ruby
# Route: /users/{id}/posts/{post_id}
# Request: /users/5/posts/42
request.params["id"]      # "5" (or 5 if typed as {id:int})
request.params["post_id"] # "42"
```

### query

Query string parameters live in the same `params` hash:

```ruby
# Request: /search?q=keyboard&page=2&sort=price
request.params["q"]    # "keyboard"
request.params["page"] # "2"
request.params["sort"] # "price"
```

### body

The parsed request body. JSON requests become a hash. Form submissions contain the form fields. GET requests produce `nil`:

```ruby
# POST with {"name": "Widget", "price": 9.99}
request.body["name"]  # "Widget"
request.body["price"] # 9.99
```

### headers

Request headers as a hash. Header names keep their original casing:

```ruby
request.headers["Content-Type"]  # "application/json"
request.headers["Authorization"] # "Bearer eyJhbGci..."
request.headers["X-Custom"]      # "my-value"
```

### ip

The client's IP address. Tina4 respects `X-Forwarded-For` and `X-Real-IP` headers behind a reverse proxy:

```ruby
request.ip # "127.0.0.1"
```

### cookies

A hash of cookies the client sent:

```ruby
request.cookies["session_id"]  # "abc123"
request.cookies["preferences"] # "dark-mode"
```

### files

Uploaded files (section 7 covers the details):

```ruby
request.files["avatar"] # File object with name, type, size, tmp_path
```

### Inspecting the Full Request

A route that dumps everything:

```ruby
Tina4::Router.post("/debug/request") do |request, response|
  response.json({
    method: request.method,
    path: request.path,
    params: request.params,
    query: request.params,
    body: request.body,
    headers: request.headers,
    ip: request.ip,
    cookies: request.cookies
  })
end
```

```bash
curl -X POST "http://localhost:7147/debug/request?page=1" \
  -H "Content-Type: application/json" \
  -H "X-Custom: hello" \
  -d '{"name": "test"}'
```

```json
{
  "method": "POST",
  "path": "/debug/request",
  "params": {},
  "query": {"page": "1"},
  "body": {"name": "test"},
  "headers": {
    "Content-Type": "application/json",
    "X-Custom": "hello",
    "Host": "localhost:7147",
    "User-Agent": "curl/8.4.0",
    "Accept": "*/*",
    "Content-Length": "16"
  },
  "ip": "127.0.0.1",
  "cookies": {}
}
```

---

## 3. The Response Object

The `response` object builds HTTP responses. Every route handler must return one. Methods chain, so you can set headers, cookies, and content in a single expression.

### json -- JSON Response

The workhorse for APIs. Pass any hash or value and it becomes JSON:

```ruby
response.json({ name: "Alice", age: 30 })
```

```json
{"name":"Alice","age":30}
```

Pass a status code as the second argument:

```ruby
response.json({ id: 7, name: "Widget" }, 201)
```

Returns `201 Created` with the JSON body.

### html -- Raw HTML Response

Return an HTML string:

```ruby
response.html("<h1>Hello</h1><p>This is HTML.</p>")
```

Sets `Content-Type: text/html; charset=utf-8`.

### text -- Plain Text Response

Return plain text:

```ruby
response.text("Just a plain string.")
```

Sets `Content-Type: text/plain; charset=utf-8`.

### render -- Template Response

Render a Frond template with data ([Chapter 4: Templates](04-templates.md) goes deep):

```ruby
response.render("products.html", {
  products: products,
  title: "Our Products"
})
```

Tina4 finds the template in `src/templates/`, renders it, returns the HTML.

### redirect -- Redirect Response

Send the client elsewhere:

```ruby
response.redirect("/login")
```

Sends a `302 Found` by default. Pass a different status for permanent redirects:

```ruby
response.redirect("/new-location", 301)
```

### file -- File Download Response

Send a file for download:

```ruby
response.file("/path/to/report.pdf")
```

Tina4 sets the right `Content-Type` from the file extension and adds `Content-Disposition` so the browser downloads instead of displaying.

Custom filename:

```ruby
response.file("/path/to/report.pdf", "monthly-report-march-2026.pdf")
```

This sets the `Content-Disposition: attachment` header with your chosen filename.

### xml -- XML Response

Return XML content:

```ruby
Tina4::Router.get("/api/feed") do |request, response|
  response.xml("<feed><entry><title>Hello</title></entry></feed>")
end
```

Sets `Content-Type: application/xml; charset=utf-8`.

### error -- Error Envelope

Return a structured error response:

```ruby
Tina4::Router.post("/api/things") do |request, response|
  response.error("VALIDATION_FAILED", "Name is required", 400)
end
```

This produces:

```json
{"error":true,"code":"VALIDATION_FAILED","message":"Name is required","status":400}
```

Three arguments: an error code string, a human-readable message, and the HTTP status code. Clients check `error: true` and switch on the `code` field. Use this pattern across your API for consistent error handling.

---

## 4. Status Codes

Every response method accepts a status code. The ones you will use most:

| Code | Meaning | When to Use |
|------|---------|-------------|
| `200` | OK | Default. Successful GET, PUT, PATCH. |
| `201` | Created | Successful POST that created a resource. |
| `204` | No Content | Successful DELETE. No body needed. |
| `301` | Moved Permanently | URL has permanently changed. |
| `302` | Found | Temporary redirect. |
| `400` | Bad Request | Invalid input from the client. |
| `401` | Unauthorized | Missing or invalid authentication. |
| `403` | Forbidden | Authenticated but not allowed. |
| `404` | Not Found | Resource does not exist. |
| `409` | Conflict | Duplicate or conflicting data. Two users claim the same username. |
| `413` | Payload Too Large | Body exceeds `TINA4_MAX_UPLOAD_SIZE`. |
| `422` | Unprocessable Entity | Valid JSON but fails business rules. The data parses but the logic rejects it. |
| `500` | Internal Server Error | Something broke on the server. |

Set the status with chaining:

```ruby
response.status(201).json({ id: 7, created: true })
```

Equivalent to `response.json({ id: 7, created: true }, 201)`. Some developers prefer the chained form.

---

## 5. Custom Headers

Add custom headers with the `header` method. Chain calls before the final response:

```ruby
Tina4::Router.get("/api/data") do |request, response|
  response
    .header("X-Request-Id", SecureRandom.hex(8))
    .header("X-Rate-Limit-Remaining", "57")
    .header("Cache-Control", "no-cache")
    .json({ data: [1, 2, 3] })
end
```

```bash
curl -v http://localhost:7147/api/data 2>&1 | grep "< X-"
```

```
< X-Request-Id: 65f3a7b8c1234567
< X-Rate-Limit-Remaining: 57
```

Convention: `Title-Case` for custom headers, prefixed with `X-`.

### CORS Headers

Tina4 handles CORS based on the `CORS_ORIGINS` setting in `.env`. The default `*` allows all origins. For production, restrict:

```bash
CORS_ORIGINS=https://myapp.com,https://admin.myapp.com
```

Manual override when needed:

```ruby
response
  .header("Access-Control-Allow-Origin", "https://myapp.com")
  .header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")
  .header("Access-Control-Allow-Headers", "Content-Type, Authorization")
  .json({ data: "value" })
```

---

## 6. Cookies

Set cookies on the response:

```ruby
Tina4::Router.post("/login") do |request, response|
  # After validating credentials...
  response
    .cookie("session_id", "abc123xyz", {
      http_only: true,
      secure: true,
      same_site: "Strict",
      max_age: 3600,       # 1 hour in seconds
      path: "/"
    })
    .json({ message: "Logged in" })
end
```

Cookie options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `http_only` | bool | `false` | JavaScript cannot access it |
| `secure` | bool | `false` | Only sent over HTTPS |
| `same_site` | string | `"Lax"` | `"Strict"`, `"Lax"`, or `"None"` |
| `max_age` | int | session | Lifetime in seconds |
| `path` | string | `"/"` | URL path scope |
| `domain` | string | current | Domain scope |

Read cookies from the request:

```ruby
Tina4::Router.get("/profile") do |request, response|
  session_id = request.cookies["session_id"]

  if session_id.nil?
    return response.json({ error: "Not logged in" }, 401)
  end

  response.json({ session: session_id })
end
```

Delete a cookie by setting `max_age` to `0`:

```ruby
response
  .cookie("session_id", "", { max_age: 0, path: "/" })
  .json({ message: "Logged out" })
```

---

## 7. File Uploads

Uploaded files live in `request.files`. Each file object holds metadata and a temporary path.

### Handling a Single File Upload

```ruby
Tina4::Router.post("/api/upload") do |request, response|
  if request.files["image"].nil?
    return response.json({ error: "No file uploaded" }, 400)
  end

  file = request.files["image"]

  response.json({
    name: file.name,        # "photo.jpg"
    type: file.type,        # "image/jpeg"
    size: file.size,        # 245760 (bytes)
    tmp_path: file.tmp_path # Temporary file location
  })
end
```

Test with curl:

```bash
curl -X POST http://localhost:7147/api/upload \
  -F "image=@/path/to/photo.jpg"
```

```json
{
  "name": "photo.jpg",
  "type": "image/jpeg",
  "size": 245760,
  "tmp_path": "/tmp/tina4_upload_abc123"
}
```

### Saving the Uploaded File

The uploaded file sits in a temporary location. Move it to a permanent path:

```ruby
Tina4::Router.post("/api/upload") do |request, response|
  if request.files["image"].nil?
    return response.json({ error: "No file uploaded" }, 400)
  end

  file = request.files["image"]

  # Validate file type
  allowed_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
  unless allowed_types.include?(file.type)
    return response.json({ error: "Invalid file type. Allowed: JPEG, PNG, GIF, WebP" }, 400)
  end

  # Validate file size (max 5MB)
  max_size = 5 * 1024 * 1024
  if file.size > max_size
    return response.json({ error: "File too large. Maximum size: 5MB" }, 400)
  end

  # Generate a unique filename
  extension = File.extname(file.name)
  filename = "img_#{SecureRandom.hex(8)}#{extension}"
  upload_dir = File.join(__dir__, "../../public/uploads")
  destination = File.join(upload_dir, filename)

  # Ensure the uploads directory exists
  FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)

  # Move the file
  FileUtils.mv(file.tmp_path, destination)

  response.json({
    message: "File uploaded successfully",
    filename: filename,
    url: "/uploads/#{filename}",
    size: file.size
  }, 201)
end
```

```bash
curl -X POST http://localhost:7147/api/upload \
  -F "image=@/path/to/photo.jpg"
```

```json
{
  "message": "File uploaded successfully",
  "filename": "img_a1b2c3d4e5f6a7b8.jpg",
  "url": "/uploads/img_a1b2c3d4e5f6a7b8.jpg",
  "size": 245760
}
```

The file now lives at `http://localhost:7147/uploads/img_a1b2c3d4e5f6a7b8.jpg`.

### Handling Multiple Files

When the HTML form uses `multiple` or you have multiple file inputs:

```ruby
Tina4::Router.post("/api/upload-many") do |request, response|
  results = []

  request.files.each do |key, file|
    extension = File.extname(file.name)
    filename = "file_#{SecureRandom.hex(8)}#{extension}"
    upload_dir = File.join(__dir__, "../../public/uploads")
    destination = File.join(upload_dir, filename)

    FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)
    FileUtils.mv(file.tmp_path, destination)

    results << {
      original_name: file.name,
      saved_as: filename,
      url: "/uploads/#{filename}"
    }
  end

  response.json({ uploaded: results, count: results.length }, 201)
end
```

---

## 8. File Downloads

Send files with `response.file`:

```ruby
Tina4::Router.get("/api/reports/{filename}") do |request, response|
  filename = request.params["filename"]
  filepath = File.join(__dir__, "../../data/reports", filename)

  unless File.exist?(filepath)
    return response.json({ error: "Report not found" }, 404)
  end

  response.file(filepath)
end
```

The browser downloads the file. Tina4 detects the MIME type from the extension and sets the right headers.

Force a specific download filename:

```ruby
response.file(filepath, "Q1-2026-Sales-Report.pdf")
```

---

## 9. Content Negotiation

The same endpoint can return different formats based on what the client asks for. Check the `Accept` header:

```ruby
Tina4::Router.get("/api/products/{id:int}") do |request, response|
  id = request.params["id"]
  product = {
    id: id,
    name: "Wireless Keyboard",
    price: 79.99
  }

  accept = request.headers["Accept"] || "application/json"

  if accept.include?("text/html")
    response.render("product-detail.html", { product: product })
  elsif accept.include?("text/plain")
    text = "Product ##{id}: #{product[:name]} - $#{product[:price]}"
    response.text(text)
  else
    # Default to JSON
    response.json(product)
  end
end
```

```bash
# JSON (default)
curl http://localhost:7147/api/products/1
```

```json
{"id":1,"name":"Wireless Keyboard","price":79.99}
```

```bash
# Plain text
curl http://localhost:7147/api/products/1 -H "Accept: text/plain"
```

```
Product #1: Wireless Keyboard - $79.99
```

```bash
# HTML (renders the template)
curl http://localhost:7147/api/products/1 -H "Accept: text/html"
```

```html
<!DOCTYPE html>
<html>...rendered template...</html>
```

---

## 10. Input Validation

Tina4 ships a `Validator` class for declarative input validation. Chain rules together, then check the result. If validation fails, `response.error` returns a structured error envelope (see section 3).

### The Validator Class

```ruby
Tina4::Router.post "/api/users" do |request, response|
  v = Tina4::Validator.new(request.body)
  v.required("name").required("email").email("email").min_length("name", 2)

  unless v.valid?
    return response.error("VALIDATION_FAILED", v.errors.first[:message], 400)
  end

  # proceed with valid data
end
```

The `Validator` accepts the request body (a hash) and provides chainable methods:

| Method | Description |
|--------|-------------|
| `required(field)` | Field must be present and non-empty |
| `email(field)` | Field must be a valid email address |
| `min_length(field, n)` | Field must have at least `n` characters |
| `max_length(field, n)` | Field must have at most `n` characters |
| `numeric(field)` | Field must be a number |
| `in_list(field, values)` | Field must be one of the allowed values |

Call `v.valid?` to check all rules. Call `v.errors` to get the list of failures, each with a `:field` and `:message` key.

### The Error Response Envelope

`response.error` returns a consistent JSON error envelope:

```ruby
response.error("VALIDATION_FAILED", "Name is required", 400)
```

This produces:

```json
{"error": true, "code": "VALIDATION_FAILED", "message": "Name is required", "status": 400}
```

The three arguments are: an error code string, a human-readable message, and the HTTP status code. Use this pattern across your API for consistent error handling.

### Upload Size Limits

Tina4 enforces a maximum upload size through the `TINA4_MAX_UPLOAD_SIZE` environment variable. The value is in bytes. The default is `10485760` (10 MB).

```bash
TINA4_MAX_UPLOAD_SIZE=10485760
```

When a client sends a body larger than this limit, Tina4 returns a `413 Payload Too Large` response before your handler runs. The check fires before body parsing begins. Your route code never executes.

To allow 50 MB uploads, set this in your `.env` file:

```bash
TINA4_MAX_UPLOAD_SIZE=52428800
```

Calculate the value by multiplying: megabytes times 1,048,576. For 25 MB, that is `26214400`. For 100 MB, `104857600`. Choose the smallest limit that covers your use case. Large limits invite abuse.

---

## 11. Exercise: Build an Image Upload API

Build an API that handles image uploads and serves them back.

### Requirements

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/images` | Upload an image. Validate type and size. Return the image URL. |
| `GET` | `/api/images/{filename}` | Return the uploaded image file. Return 404 if not found. |

Rules:

1. Accept JPEG, PNG, and WebP only
2. Maximum file size: 2MB
3. Save files to `src/public/uploads/` with a unique filename
4. Return original filename, saved filename, file size in KB, and the URL
5. The GET endpoint serves the file (not JSON)

### Test with:

```bash
# Upload
curl -X POST http://localhost:7147/api/images \
  -F "image=@/path/to/photo.jpg"

# Download
curl http://localhost:7147/api/images/img_a1b2c3d4e5f6a7b8.jpg --output downloaded.jpg
```

---

## 12. Solution

Create `src/routes/images.rb`:

```ruby
require "securerandom"
require "fileutils"

Tina4::Router.post("/api/images") do |request, response|
  # Check if a file was uploaded
  if request.files["image"].nil?
    return response.json({ error: "No image file provided. Use field name 'image'." }, 400)
  end

  file = request.files["image"]

  # Validate file type
  allowed_types = ["image/jpeg", "image/png", "image/webp"]
  unless allowed_types.include?(file.type)
    return response.json({
      error: "Invalid file type",
      received: file.type,
      allowed: allowed_types
    }, 400)
  end

  # Validate file size (max 2MB)
  max_size = 2 * 1024 * 1024
  if file.size > max_size
    return response.json({
      error: "File too large",
      size_bytes: file.size,
      max_bytes: max_size
    }, 400)
  end

  # Generate unique filename preserving extension
  extension = File.extname(file.name).downcase
  saved_name = "img_#{SecureRandom.hex(8)}#{extension}"
  upload_dir = File.join(__dir__, "../../public/uploads")
  destination = File.join(upload_dir, saved_name)

  # Create uploads directory if it does not exist
  FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)

  # Move the uploaded file
  FileUtils.mv(file.tmp_path, destination)

  response.json({
    message: "Image uploaded successfully",
    original_name: file.name,
    saved_name: saved_name,
    size_kb: (file.size / 1024.0).round(1),
    type: file.type,
    url: "/uploads/#{saved_name}"
  }, 201)
end

Tina4::Router.get("/api/images/{filename}") do |request, response|
  filename = request.params["filename"]

  # Prevent directory traversal
  if filename.include?("..") || filename.include?("/")
    return response.json({ error: "Invalid filename" }, 400)
  end

  filepath = File.join(__dir__, "../../public/uploads", filename)

  unless File.exist?(filepath)
    return response.json({ error: "Image not found", filename: filename }, 404)
  end

  response.file(filepath)
end
```

**Expected output for upload:**

```json
{
  "message": "Image uploaded successfully",
  "original_name": "photo.jpg",
  "saved_name": "img_a1b2c3d4e5f6a7b8.jpg",
  "size_kb": 240.0,
  "type": "image/jpeg",
  "url": "/uploads/img_a1b2c3d4e5f6a7b8.jpg"
}
```

(Status: `201 Created`)

**Expected output for invalid type:**

```json
{
  "error": "Invalid file type",
  "received": "application/pdf",
  "allowed": ["image/jpeg", "image/png", "image/webp"]
}
```

(Status: `400 Bad Request`)

**Expected output for file too large:**

```json
{
  "error": "File too large",
  "size_bytes": 5242880,
  "max_bytes": 2097152
}
```

(Status: `400 Bad Request`)

**The GET endpoint** returns the raw image file with the correct `Content-Type` header. The browser displays it. Curl with `--output` saves it to disk.

---

## 13. Gotchas

### 1. Forgetting the response method

**Problem:** Handler runs (log output confirms it) but the browser gets an empty response or 500 error.

**Cause:** No call to `response.json`, `response.html`, or another response method. Ruby returns the last expression in a block, but if it is not a response, Tina4 has nothing to send.

**Fix:** End every handler with a response method call.

### 2. request.body is nil for GET requests

**Problem:** Accessing `request.body` in a GET handler returns `nil`.

**Cause:** GET requests carry no body. Browsers and curl send none by convention.

**Fix:** Use `request.params` for GET parameters. The body populates only for POST, PUT, and PATCH requests.

### 3. Body is nil for JSON requests

**Problem:** `request.body` is `nil` or empty even though you sent JSON.

**Cause:** Missing `Content-Type: application/json` header. Without it, Tina4 does not parse the body as JSON.

**Fix:** Include `-H "Content-Type: application/json"` with curl. In frontend JavaScript, `fetch()` with `JSON.stringify()` needs `headers: {"Content-Type": "application/json"}`.

### 4. Content-Type Mismatch

**Problem:** `response.json` sends HTML, or `response.html` sends plain text.

**Cause:** A middleware or error handler is overwriting the response. Or you used `puts` instead of a response method.

**Fix:** Use `response.json(...)`, `response.html(...)`, or another response method. `puts` bypasses the response object entirely.

### 5. File Uploads Return Empty

**Problem:** `request.files` is empty despite uploading a file.

**Cause:** The form lacks `enctype="multipart/form-data"`, or curl uses `-d` instead of `-F`.

**Fix:** HTML forms need `<form enctype="multipart/form-data">`. Curl needs `-F "field=@file.jpg"` (with `@`), not `-d`.

### 6. Redirect Loops

**Problem:** The browser shows "too many redirects" or hangs.

**Cause:** A route redirects to another route, which redirects back. Example: `/login` redirects to `/dashboard`, and `/dashboard` redirects to `/login` because the user is not authenticated.

**Fix:** Trace the redirect chain with the browser's network inspector. Make sure auth checks do not redirect authenticated users away from pages they can access.

### 7. Cookie Not Set

**Problem:** `response.cookie(...)` was called but the browser shows no cookie.

**Cause:** `secure: true` means the cookie travels over HTTPS only. Local development uses `http://localhost`, so the cookie is dropped.

**Fix:** Set `secure: false` during development, or use `secure: ENV["TINA4_DEBUG"] != "true"` to auto-switch.

### 8. Large Request Body Rejected

**Problem:** POST requests with large bodies return 413.

**Cause:** The body exceeds the configured maximum size.

**Fix:** Increase `TINA4_MAX_BODY_SIZE` in `.env`. Default is `10mb`. For file uploads, you may need `50mb` or more:

```bash
TINA4_MAX_BODY_SIZE=50mb
```

### 9. Chaining Response Methods in Wrong Order

**Problem:** Headers or cookies set after calling `response.json` have no effect.

**Cause:** `response.json` finalizes and returns the response object. Calling methods on a separate line after the return is dead code.

**Fix:** Chain headers and cookies before the final response method:

```ruby
# Correct
response
  .header("X-Custom", "value")
  .cookie("token", "abc", { http_only: true })
  .json({ ok: true })

# Wrong -- header is set after json already returned
result = response.json({ ok: true })
response.header("X-Custom", "value")  # Too late
result
```
