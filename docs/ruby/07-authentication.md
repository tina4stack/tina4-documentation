# Chapter 7: Authentication

## 1. Locking the Door

Every endpoint you have built is public. Anyone with the URL can read, create, update, and delete data. Fine for a tutorial. Reckless for production. A real application needs to know who is making a request and whether they have permission.

This chapter covers Tina4's authentication system. JWT tokens. Password hashing. Middleware-based route protection. CSRF tokens for forms. Session management.

---

## 2. JWT Tokens

Tina4 uses JSON Web Tokens (JWT) for authentication. A JWT is a signed string containing a payload -- user ID, role, whatever you need. The server mints the token at login. The client sends it with every request. The server verifies it without touching the database.

### Generating a Token

```ruby
payload = {
  user_id: 42,
  email: "alice@example.com",
  role: "admin"
}

token = Tina4::Auth.get_token(payload)
```

`get_token` signs the payload and returns a JWT string like:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo0MiwiZW1haWwiOiJhbGljZUBleGFtcGxlLmNvbSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTcxMTExMjYwMCwiZXhwIjoxNzExMTE2MjAwfQ.abc123signature
```

The token has three parts separated by dots: header, payload, and signature. The signature ensures the token has not been tampered with.

> **Legacy aliases:** `Tina4::Auth.create_token` still works as an alias for `Tina4::Auth.get_token`. Use the primary name in new code.

### Token Expiry

By default, tokens expire after 1 hour (3600 seconds). Configure the expiry when generating the token:

```ruby
# Default: 1 hour
token = Tina4::Auth.get_token(payload)

# Custom: 24 hours
token = Tina4::Auth.get_token(payload, expires_in: 86400)

# Custom: 7 days
token = Tina4::Auth.get_token(payload, expires_in: 604800)
```

The `expires_in` value is in **seconds**. Common settings:

| Value | Duration |
|-------|----------|
| `900` | 15 minutes |
| `3600` | 1 hour (default) |
| `86400` | 24 hours |
| `604800` | 7 days |

### Validating a Token

```ruby
payload = Tina4::Auth.valid_token(token)
# Returns the payload hash if valid, nil if invalid or expired
```

`valid_token` returns the decoded payload on success, not a boolean. This lets you validate and read the token in one step. Returns `nil` if the token is invalid or expired.

> **Legacy alias:** `Tina4::Auth.validate_token` works the same way.

### Reading the Payload

```ruby
payload = Tina4::Auth.get_payload(token)
```

Returns the decoded payload hash **without validation** -- it just decodes the token:

```ruby
{
  "user_id" => 42,
  "email" => "alice@example.com",
  "role" => "admin",
  "iat" => 1711112600,  # issued at (Unix timestamp)
  "exp" => 1711116200   # expires at (Unix timestamp)
}
```

If the token cannot be decoded, `get_payload` returns `nil`.

> **Important:** `get_payload` does not verify the signature or check expiry. Use `valid_token` when you need to confirm the token is trustworthy.

### The Secret Key and Algorithm

Tina4 Ruby supports two JWT algorithms, auto-detected based on your configuration:

- **HS256** (HMAC-SHA256) -- set `SECRET` in `.env`. Uses the standard library. Zero dependencies.
- **RS256** (RSA) -- RSA keys are auto-generated in the `.keys/` folder. Requires the `jwt` gem (included by default).

```env
# .env -- HS256 mode (recommended, simplest setup)
SECRET=my-super-secret-key-at-least-32-chars
```

If `SECRET` is set and no RSA keys exist in `.keys/`, Tina4 uses HS256. If RSA keys exist in `.keys/` instead, Tina4 uses RS256. If neither is configured, Tina4 auto-generates RSA keys in `.keys/` on first run.

Keep this key secret. If someone gets it, they can forge tokens.

---

## 3. Password Hashing

Plain text passwords are a security breach waiting to happen. Tina4 provides two methods for secure password handling:

### Hashing a Password

```ruby
hash = Tina4::Auth.hash_password("my-secure-password")
# Returns: "$2a$12$abc123...long-hash-string..."
```

This uses BCrypt (via the `bcrypt` gem, included by default). Each hash includes a random salt, so hashing the same password twice produces different results.

### Checking a Password

```ruby
is_correct = Tina4::Auth.check_password("my-secure-password", stored_hash)
# Returns true if the password matches the hash
```

### Registration Example

```ruby
# @noauth
Tina4::Router.post("/api/register") do |request, response|
  body = request.body

  # Validate input
  if body["name"].nil? || body["email"].nil? || body["password"].nil?
    return response.json({ error: "Name, email, and password are required" }, 400)
  end

  if body["password"].length < 8
    return response.json({ error: "Password must be at least 8 characters" }, 400)
  end

  db = Tina4.database

  # Check if email already exists
  existing = db.fetch_one("SELECT id FROM users WHERE email = ?", [body["email"]])
  unless existing.nil?
    return response.json({ error: "Email already registered" }, 409)
  end

  # Hash the password
  password_hash = Tina4::Auth.hash_password(body["password"])

  # Create the user
  db.execute(
    "INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)",
    [body["name"], body["email"], password_hash]
  )

  user = db.fetch_one("SELECT id, name, email FROM users WHERE id = last_insert_rowid()")

  response.json({
    message: "Registration successful",
    user: user
  }, 201)
end
```

```bash
curl -X POST http://localhost:7147/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Registration successful",
  "user": {"id": 1, "name": "Alice", "email": "alice@example.com"}
}
```

---

## 4. The Login Flow

Here is the complete login flow: the client sends credentials, the server validates them, and returns a JWT token.

```ruby
# @noauth
Tina4::Router.post("/api/login") do |request, response|
  body = request.body

  if body["email"].nil? || body["password"].nil?
    return response.json({ error: "Email and password are required" }, 400)
  end

  db = Tina4.database

  # Find the user
  user = db.fetch_one(
    "SELECT id, name, email, password_hash FROM users WHERE email = ?",
    [body["email"]]
  )

  if user.nil?
    return response.json({ error: "Invalid email or password" }, 401)
  end

  # Check the password
  unless Tina4::Auth.check_password(body["password"], user["password_hash"])
    return response.json({ error: "Invalid email or password" }, 401)
  end

  # Generate a token
  token = Tina4::Auth.get_token({
    user_id: user["id"],
    email: user["email"],
    name: user["name"]
  })

  response.json({
    message: "Login successful",
    token: token,
    user: {
      id: user["id"],
      name: user["name"],
      email: user["email"]
    }
  })
end
```

Notice the `@noauth` comment. The login endpoint must be public -- you cannot require a token to get a token.

```bash
curl -X POST http://localhost:7147/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com"
  }
}
```

The client stores this token (in localStorage, a cookie, or memory) and sends it with subsequent requests.

---

## 5. Using Tokens in Requests

The client sends the token in the `Authorization` header with the `Bearer` prefix:

```bash
curl http://localhost:7147/api/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 6. Protecting Routes

### Auth Middleware

Create a reusable auth middleware:

```ruby
def auth_middleware(request, response, next_handler)
  auth_header = request.headers["Authorization"] || ""

  if auth_header.empty? || !auth_header.start_with?("Bearer ")
    return response.json({ error: "Authorization header required" }, 401)
  end

  token = auth_header.sub("Bearer ", "")

  payload = Tina4::Auth.valid_token(token)
  if payload.nil?
    return response.json({ error: "Invalid or expired token" }, 401)
  end

  request.user = payload  # Attach user data to the request

  next_handler.call(request, response)
end
```

### Applying Middleware to Routes

```ruby
Tina4::Router.get("/api/profile", middleware: "auth_middleware") do |request, response|
  response.json({
    user_id: request.user["user_id"],
    email: request.user["email"],
    name: request.user["name"]
  })
end
```

```bash
# Without token -- 401
curl http://localhost:7147/api/profile
```

```json
{"error":"Authorization header required"}
```

```bash
# With valid token -- 200
curl http://localhost:7147/api/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

```json
{
  "user_id": 1,
  "email": "alice@example.com",
  "name": "Alice"
}
```

### Applying Middleware to a Group

```ruby
Tina4::Router.group("/api/admin", middleware: "auth_middleware") do

  Tina4::Router.get("/stats") do |request, response|
    response.json({ active_users: 42 })
  end

  Tina4::Router.get("/logs") do |request, response|
    response.json({ logs: [] })
  end

end
```

Every route in the group requires a valid token.

---

## 7. @noauth and @secured Decorators

As introduced in Chapter 2, these decorators control authentication at the route level.

### @noauth -- Skip Authentication

Use `@noauth` for public endpoints that should bypass any global or group-level auth:

```ruby
# @noauth
Tina4::Router.get("/api/public/health") do |request, response|
  response.json({ status: "ok" })
end

# @noauth
Tina4::Router.post("/api/login") do |request, response|
  # Login logic
end

# @noauth
Tina4::Router.post("/api/register") do |request, response|
  # Registration logic
end
```

### @secured -- Require Authentication for GET Routes

By default, POST, PUT, PATCH, and DELETE routes are considered secured. GET routes are public. Use `@secured` to explicitly protect a GET route:

```ruby
# @secured
Tina4::Router.get("/api/me") do |request, response|
  # This GET route requires authentication
  response.json(request.user)
end
```

### Role-Based Authorization

Combine auth middleware with role checks:

```ruby
def require_role(role)
  lambda do |request, response, next_handler|
    # First check authentication
    auth_header = request.headers["Authorization"] || ""
    if auth_header.empty? || !auth_header.start_with?("Bearer ")
      return response.json({ error: "Authorization required" }, 401)
    end

    token = auth_header.sub("Bearer ", "")
    payload = Tina4::Auth.valid_token(token)
    if payload.nil?
      return response.json({ error: "Invalid or expired token" }, 401)
    end

    # Check role
    if (payload["role"] || "") != role
      return response.json({ error: "Forbidden. Required role: #{role}" }, 403)
    end

    request.user = payload
    next_handler.call(request, response)
  end
end
```

---

## 8. CSRF Protection

For traditional form-based applications (not SPAs), Tina4 provides CSRF protection with form tokens.

### Generating a Token

In your template, include the CSRF token in every form:

```html
<form method="POST" action="/profile/update">
    {{ form_token() }}

    <div class="form-group">
        <label for="name">Name</label>
        <input type="text" name="name" id="name" value="{{ user.name }}">
    </div>

    <button type="submit">Update Profile</button>
</form>
```

`{{ form_token() }}` renders a hidden input field:

```html
<input type="hidden" name="_token" value="abc123randomtoken456">
```

### Validating the Token

In your route handler, check the token:

```ruby
Tina4::Router.post("/profile/update") do |request, response|
  # Validate CSRF token
  unless Tina4::Auth.validate_form_token(request.body["_token"] || "")
    return response.json({ error: "Invalid form token. Please refresh and try again." }, 403)
  end

  # Process the form...
  response.redirect("/profile")
end
```

---

## 9. Sessions

Tina4 supports server-side sessions for storing per-user state between requests. Sessions work alongside JWT tokens -- use JWTs for API authentication and sessions for stateful web pages.

### Using Sessions

Access session data via `request.session`:

```ruby
Tina4::Router.post("/login-form") do |request, response|
  # After validating credentials...
  request.session["user_id"] = 42
  request.session["user_name"] = "Alice"
  request.session["logged_in"] = true

  response.redirect("/dashboard")
end

Tina4::Router.get("/dashboard") do |request, response|
  if request.session["logged_in"].nil?
    return response.redirect("/login")
  end

  response.render("dashboard.html", {
    user_name: request.session["user_name"]
  })
end

Tina4::Router.post("/logout") do |request, response|
  # Clear all session data
  request.session.clear

  response.redirect("/login")
end
```

---

## 10. Exercise: Build Login, Register, and Profile

Build a complete authentication system with registration, login, profile viewing, and password changing.

### Requirements

1. Create a `users` table migration with: `id`, `name`, `email` (unique), `password_hash`, `role` (default "user"), `created_at`

2. Build these endpoints:

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/register` | @noauth | Create an account. Validate name, email, password (min 8 chars). |
| `POST` | `/api/login` | @noauth | Login. Return JWT token. |
| `GET` | `/api/profile` | secured | Get current user's profile from token. |
| `PUT` | `/api/profile` | secured | Update name and email. |
| `PUT` | `/api/profile/password` | secured | Change password. Require current password. |

3. Create auth middleware that extracts the user from the JWT and attaches it to `request.user`.

### Test with:

```bash
# Register
curl -X POST http://localhost:7147/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'

# Login
curl -X POST http://localhost:7147/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securePass123"}'

# Save the token from login response, then:

# Get profile
curl http://localhost:7147/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# Update profile
curl -X PUT http://localhost:7147/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith"}'

# Change password
curl -X PUT http://localhost:7147/api/profile/password \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"current_password": "securePass123", "new_password": "evenMoreSecure456"}'

# Try with no token (should fail)
curl http://localhost:7147/api/profile
```

---

## 11. Solution

### Migration

Create `src/migrations/20260322160000_create_auth_users_table.sql`:

```sql
-- UP
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- DOWN
DROP TABLE IF EXISTS users;
```

### Middleware

Create `src/routes/middleware.rb`:

```ruby
def auth_middleware(request, response, next_handler)
  auth_header = request.headers["Authorization"] || ""

  if auth_header.empty? || !auth_header.start_with?("Bearer ")
    return response.json({ error: "Authorization required. Send: Authorization: Bearer <token>" }, 401)
  end

  token = auth_header.sub("Bearer ", "")

  payload = Tina4::Auth.valid_token(token)
  if payload.nil?
    return response.json({ error: "Invalid or expired token. Please login again." }, 401)
  end

  request.user = payload

  next_handler.call(request, response)
end
```

### Routes

Create `src/routes/auth.rb`:

```ruby
# @noauth
Tina4::Router.post("/api/register") do |request, response|
  body = request.body

  errors = []
  errors << "Name is required" if body["name"].nil? || body["name"].empty?
  errors << "Email is required" if body["email"].nil? || body["email"].empty?
  if body["password"].nil? || body["password"].empty?
    errors << "Password is required"
  elsif body["password"].length < 8
    errors << "Password must be at least 8 characters"
  end

  unless errors.empty?
    return response.json({ errors: errors }, 400)
  end

  db = Tina4.database

  existing = db.fetch_one("SELECT id FROM users WHERE email = ?", [body["email"]])
  unless existing.nil?
    return response.json({ error: "Email already registered" }, 409)
  end

  hash = Tina4::Auth.hash_password(body["password"])

  db.execute(
    "INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)",
    [body["name"], body["email"], hash]
  )

  user = db.fetch_one("SELECT id, name, email, role, created_at FROM users WHERE id = last_insert_rowid()")

  response.json({ message: "Registration successful", user: user }, 201)
end

# @noauth
Tina4::Router.post("/api/login") do |request, response|
  body = request.body

  if body["email"].nil? || body["password"].nil?
    return response.json({ error: "Email and password are required" }, 400)
  end

  db = Tina4.database

  user = db.fetch_one(
    "SELECT id, name, email, password_hash, role FROM users WHERE email = ?",
    [body["email"]]
  )

  if user.nil? || !Tina4::Auth.check_password(body["password"], user["password_hash"])
    return response.json({ error: "Invalid email or password" }, 401)
  end

  token = Tina4::Auth.get_token({
    user_id: user["id"],
    email: user["email"],
    name: user["name"],
    role: user["role"]
  })

  response.json({
    message: "Login successful",
    token: token,
    user: { id: user["id"], name: user["name"], email: user["email"], role: user["role"] }
  })
end

# Get current user profile
Tina4::Router.get("/api/profile", middleware: "auth_middleware") do |request, response|
  db = Tina4.database

  user = db.fetch_one(
    "SELECT id, name, email, role, created_at FROM users WHERE id = ?",
    [request.user["user_id"]]
  )

  if user.nil?
    return response.json({ error: "User not found" }, 404)
  end

  response.json(user)
end

# Update profile
Tina4::Router.put("/api/profile", middleware: "auth_middleware") do |request, response|
  db = Tina4.database
  body = request.body
  user_id = request.user["user_id"]

  if body["email"]
    existing = db.fetch_one(
      "SELECT id FROM users WHERE email = ? AND id != ?",
      [body["email"], user_id]
    )
    unless existing.nil?
      return response.json({ error: "Email already in use by another account" }, 409)
    end
  end

  current = db.fetch_one("SELECT * FROM users WHERE id = ?", [user_id])

  db.execute(
    "UPDATE users SET name = ?, email = ? WHERE id = ?",
    [body["name"] || current["name"], body["email"] || current["email"], user_id]
  )

  updated = db.fetch_one(
    "SELECT id, name, email, role, created_at FROM users WHERE id = ?",
    [user_id]
  )

  response.json({ message: "Profile updated", user: updated })
end

# Change password
Tina4::Router.put("/api/profile/password", middleware: "auth_middleware") do |request, response|
  db = Tina4.database
  body = request.body
  user_id = request.user["user_id"]

  if body["current_password"].nil? || body["new_password"].nil?
    return response.json({ error: "Current password and new password are required" }, 400)
  end

  if body["new_password"].length < 8
    return response.json({ error: "New password must be at least 8 characters" }, 400)
  end

  user = db.fetch_one("SELECT password_hash FROM users WHERE id = ?", [user_id])

  unless Tina4::Auth.check_password(body["current_password"], user["password_hash"])
    return response.json({ error: "Current password is incorrect" }, 401)
  end

  new_hash = Tina4::Auth.hash_password(body["new_password"])

  db.execute(
    "UPDATE users SET password_hash = ? WHERE id = ?",
    [new_hash, user_id]
  )

  response.json({ message: "Password changed successfully" })
end
```

**Expected output for register:**

```json
{
  "message": "Registration successful",
  "user": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com",
    "role": "user",
    "created_at": "2026-03-22 16:00:00"
  }
}
```

(Status: `201 Created`)

**Expected output for profile without token:**

```json
{"error":"Authorization required. Send: Authorization: Bearer <token>"}
```

(Status: `401 Unauthorized`)

**Expected output for successful password change:**

```json
{"message":"Password changed successfully"}
```

---

## 12. Gotchas

### 1. Token Expiry Confusion

**Problem:** Tokens that worked yesterday now return 401.

**Cause:** The default token lifetime is 1 hour (3600 seconds). After that, the token is invalid even if the signature is correct.

**Fix:** Issue a new token at login. If your application needs long-lived sessions, use refresh tokens: a short-lived access token (15 minutes) paired with a long-lived refresh token (7 days) that can be used to get a new access token without re-entering credentials.

### 2. Secret Key Management

**Problem:** Tokens generated on one server are invalid on another, or tokens stop working after a deployment.

**Cause:** Each server generated its own RSA keys in `.keys/`. Or the key files were deleted/regenerated during deployment.

**Fix:** Set `SECRET` in `.env` explicitly and use the same value across all servers. Store it in your deployment secrets manager (not in version control). If the key changes, all existing tokens become invalid and users must log in again.

### 3. CORS with Authentication

**Problem:** Frontend requests with the `Authorization` header fail with a CORS error, even though `CORS_ORIGINS=*` is set.

**Cause:** When the browser sends an `Authorization` header, it first sends a preflight `OPTIONS` request. The server must respond to the OPTIONS request with the correct CORS headers, including `Access-Control-Allow-Headers: Authorization`.

**Fix:** Tina4 handles preflight requests automatically. Make sure `CORS_ORIGINS` is set correctly. If it is still failing, check that you are not overriding CORS headers in middleware.

### 4. Storing Tokens in localStorage

**Problem:** Your token is stolen via an XSS attack because it was stored in `localStorage`.

**Cause:** Any JavaScript on the page can read `localStorage`, including injected scripts from an XSS vulnerability.

**Fix:** Store tokens in `httpOnly` cookies when possible -- they cannot be accessed by JavaScript. For SPAs that must use `localStorage`, implement strict Content Security Policy headers and sanitize all user input.

### 5. Forgetting @noauth on Login

**Problem:** Your login endpoint returns 401 -- you cannot log in because the endpoint requires authentication.

**Cause:** If you have global auth middleware, the login endpoint needs the `@noauth` annotation to bypass it.

**Fix:** Add `# @noauth` before your login and register routes. Without it, users cannot authenticate because authentication is required to authenticate -- a catch-22.

### 6. Password Hash Column Too Short

**Problem:** Registration fails with a database error about the password hash being too long.

**Cause:** BCrypt/PBKDF2 hashes can be long. If your `password_hash` column is defined as `VARCHAR(50)`, it gets truncated.

**Fix:** Use `TEXT` for the password hash column, or at minimum `VARCHAR(255)`. Never constrain the hash length.

### 7. Token in URL Query Parameters

**Problem:** Tokens in URLs like `/api/profile?token=eyJ...` leak through browser history, server logs, and the Referer header.

**Cause:** Query parameters are visible in many places where headers are not.

**Fix:** Always send tokens in the `Authorization` header, never in the URL. The only exception is WebSocket connections, where the initial HTTP upgrade request cannot carry custom headers -- use a short-lived token for that case.
