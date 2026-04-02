# Chapter 7: Authentication

## 1. Locking the Door

Every endpoint built so far is public. Anyone with the URL can read, create, update, and delete data. Fine for a tutorial. Unacceptable for production.

A real application needs to know two things: who is making the request, and whether they are allowed to make it. This chapter covers Tina4's authentication system. JWT tokens. Password hashing. Middleware-based route protection. CSRF tokens for forms. Session management.

---

## 2. JWT Tokens

Tina4 uses JSON Web Tokens (JWT) for authentication. A JWT is a signed string carrying a payload -- user ID, role, expiry. The server mints the token at login. The client sends it with every request. The server verifies the signature without touching the database.

### Generating a Token

```python
from tina4_python.auth import Auth

payload = {
    "user_id": 42,
    "email": "alice@example.com",
    "role": "admin"
}

token = Auth.get_token(payload)
```

`get_token()` signs the payload with HS256 (HMAC-SHA256) and returns a JWT string like:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo0MiwiZW1haWwiOiJhbGljZUBleGFtcGxlLmNvbSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTcxMTExMjYwMCwiZXhwIjoxNzExMTE2MjAwfQ.abc123signature
```

The token has three parts separated by dots: header, payload, and signature. The signature ensures the token has not been tampered with.

### Token Expiry

By default, tokens expire after 60 minutes. Configure this in `.env`:

```env
TINA4_TOKEN_EXPIRES_IN=60
```

The value is in **minutes**. Common settings:

| Value | Duration |
|-------|----------|
| `15` | 15 minutes |
| `60` | 1 hour (default) |
| `1440` | 24 hours |
| `10080` | 7 days |

### Validating a Token

```python
payload = Auth.valid_token(token)
# Returns the payload dict if the token is valid, None if invalid or expired
```

`valid_token()` returns the decoded payload on success, not a boolean. This lets you validate and read the token in one step. Returns `None` if the token is invalid or expired.

### Reading the Payload

```python
payload = Auth.get_payload(token)
```

Returns the decoded payload dictionary **without validation** -- it just decodes the token:

```python
{
    "user_id": 42,
    "email": "alice@example.com",
    "role": "admin",
    "iat": 1711112600,  # issued at (Unix timestamp)
    "exp": 1711116200   # expires at (Unix timestamp)
}
```

If the token cannot be decoded, `get_payload()` returns `None`.

> **Important:** `get_payload()` does not verify the signature or check expiry. Use `valid_token()` when you need to confirm the token is trustworthy.

### The Secret Key and Algorithm

Tina4 Python uses **HS256** (HMAC-SHA256) for JWT signing. It uses only the standard library -- zero external dependencies.

Set the secret key in `.env`:

```env
SECRET=my-super-secret-key-at-least-32-chars
```

If no `SECRET` is set, Tina4 falls back to generating a random key at `secrets/jwt.key` on first run. Setting `SECRET` explicitly is recommended for production so all server instances share the same key.

Keep this key secret. If someone gets it, they can forge tokens.

---

## 3. Password Hashing

Plain-text passwords are a liability. Tina4 provides two functions for secure password handling:

### Hashing a Password

```python
from tina4_python.auth import Auth

hashed = Auth.hash_password("my-secure-password")
# Returns: "$2b$12$abc123...long-hash-string..."
```

Uses PBKDF2 from the standard library -- no external dependencies. Each hash includes a random salt, so hashing the same password twice produces different results.

### Checking a Password

```python
is_correct = Auth.check_password("my-secure-password", stored_hash)
# Returns True if the password matches the hash
```

### Registration Example

```python
from tina4_python.core.router import post, noauth
from tina4_python.auth import Auth
from tina4_python.database.connection import Database

@post("/api/register")
@noauth()
async def register(request, response):
    body = request.body

    # Validate input
    if not body.get("name") or not body.get("email") or not body.get("password"):
        return response.json({"error": "Name, email, and password are required"}, 400)

    if len(body["password"]) < 8:
        return response.json({"error": "Password must be at least 8 characters"}, 400)

    db = Database()

    # Check if email already exists
    existing = db.fetch_one("SELECT id FROM users WHERE email = ?", [body["email"]])
    if existing is not None:
        return response.json({"error": "Email already registered"}, 409)

    # Hash the password
    password_hash = Auth.hash_password(body["password"])

    # Create the user
    result = db.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)",
        [body["name"], body["email"], password_hash]
    )

    user = db.fetch_one("SELECT id, name, email FROM users WHERE id = ?", [result.last_id])

    return response.json({
        "message": "Registration successful",
        "user": user
    }, 201)
```

```bash
curl -X POST http://localhost:7145/api/register \
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

The complete login flow. Client sends credentials. Server validates them. Server returns a JWT token.

```python
from tina4_python.core.router import post, noauth
from tina4_python.auth import Auth
from tina4_python.database.connection import Database

@post("/api/login")
@noauth()
async def login(request, response):
    body = request.body

    if not body.get("email") or not body.get("password"):
        return response.json({"error": "Email and password are required"}, 400)

    db = Database()

    # Find the user
    user = db.fetch_one(
        "SELECT id, name, email, password_hash FROM users WHERE email = ?",
        [body["email"]]
    )

    if user is None:
        return response.json({"error": "Invalid email or password"}, 401)

    # Check the password
    if not Auth.check_password(body["password"], user["password_hash"]):
        return response.json({"error": "Invalid email or password"}, 401)

    # Generate a token
    token = Auth.get_token({
        "user_id": user["id"],
        "email": user["email"],
        "name": user["name"]
    })

    return response.json({
        "message": "Login successful",
        "token": token,
        "user": {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"]
        }
    })
```

Notice `@noauth`. The login endpoint must be public. You cannot require a token to get a token.

```bash
curl -X POST http://localhost:7145/api/login \
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
curl http://localhost:7145/api/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 6. Protecting Routes

### Auth Middleware

Create a reusable auth middleware:

```python
from tina4_python.auth import Auth

async def auth_middleware(request, response, next_handler):
    auth_header = request.headers.get("Authorization", "")

    if not auth_header or not auth_header.startswith("Bearer "):
        return response.json({"error": "Authorization header required"}, 401)

    token = auth_header[7:]  # Remove "Bearer " prefix

    payload = Auth.valid_token(token)
    if payload is None:
        return response.json({"error": "Invalid or expired token"}, 401)

    request.user = payload  # Attach user data to the request

    return await next_handler(request, response)
```

### Applying Middleware to Routes

```python
from tina4_python.core.router import get, middleware

@get("/api/profile")
@middleware(auth_middleware)
async def profile(request, response):
    return response.json({
        "user_id": request.user["user_id"],
        "email": request.user["email"],
        "name": request.user["name"]
    })
```

```bash
# Without token -- 401
curl http://localhost:7145/api/profile
```

```json
{"error":"Authorization header required"}
```

```bash
# With valid token -- 200
curl http://localhost:7145/api/profile \
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

```python
from tina4_python.core.router import get, group, middleware

@group("/api/admin")
@middleware(auth_middleware)
def admin_routes():

    @get("/stats")
    async def admin_stats(request, response):
        return response.json({"active_users": 42})

    @get("/logs")
    async def admin_logs(request, response):
        return response.json({"logs": []})
```

Every route in the group requires a valid token.

---

## 7. @noauth and @secured Decorators

As introduced in Chapter 2, these decorators control authentication at the route level.

### @noauth -- Skip Authentication

Use `@noauth` for public endpoints that should bypass any global or group-level auth:

```python
from tina4_python.core.router import get, post, noauth

@get("/api/public/health")
@noauth()
async def health(request, response):
    return response.json({"status": "ok"})

@post("/api/login")
@noauth()
async def login(request, response):
    # Login logic
    pass

@post("/api/register")
@noauth()
async def register(request, response):
    # Registration logic
    pass
```

### @secured -- Require Authentication for GET Routes

By default, POST, PUT, PATCH, and DELETE routes are considered secured. GET routes are public. Use `@secured` to explicitly protect a GET route:

```python
from tina4_python.core.router import get, secured

@get("/api/me")
@secured()
async def me(request, response):
    # This GET route requires authentication
    return response.json(request.user)
```

### Role-Based Authorization

Combine auth middleware with role checks:

```python
from tina4_python.auth import Auth

def require_role(role):
    async def role_middleware(request, response, next_handler):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header or not auth_header.startswith("Bearer "):
            return response.json({"error": "Authorization required"}, 401)

        token = auth_header[7:]
        payload = Auth.valid_token(token)
        if payload is None:
            return response.json({"error": "Invalid or expired token"}, 401)

        if payload.get("role") != role:
            return response.json({"error": f"Forbidden. Required role: {role}"}, 403)

        request.user = payload
        return await next_handler(request, response)

    return role_middleware
```

Use it as middleware:

```python
from tina4_python.core.router import delete as delete_route, middleware

@delete_route("/api/users/{id:int}")
@middleware(require_role("admin"))
async def delete_user(request, response):
    # Only admins can delete users
    return response.json({"deleted": True})
```

---

## 8. CSRF Protection

Traditional form-based applications (not SPAs) need CSRF protection. Tina4 provides it through form tokens.

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

```python
from tina4_python.core.router import post
from tina4_python.auth import Auth

@post("/profile/update")
async def update_profile(request, response):
    # Validate CSRF token
    if not Auth.validate_form_token(request.body.get("_token", "")):
        return response.json({"error": "Invalid form token. Please refresh and try again."}, 403)

    # Process the form...
    return response.redirect("/profile")
```

The CSRF token is tied to the session and expires after a single use. A malicious site cannot forge a form submission because it cannot guess the token.

> **Note (3.10.9):** Form token validation internally uses `Auth.valid_token_static()`, a classmethod that does not require an `Auth` instance. Earlier versions incorrectly called the instance method, which could fail when no request context was available. If you validate form tokens manually, prefer `Auth.valid_token_static(token)` for reliability.

### When to Use CSRF Tokens

Use CSRF tokens for:
- HTML forms submitted by browsers
- Any POST/PUT/DELETE from server-rendered pages

You do not need CSRF tokens for:
- API endpoints that use JWT (the Bearer token already proves the request is intentional)
- Single-page applications that use `fetch()` with custom headers

---

## 9. Sessions

Tina4 supports server-side sessions for storing per-user state between requests. JWTs handle API authentication. Sessions handle stateful web pages. Both work side by side.

### Session Configuration

Set the session backend in `.env`:

```env
# File-based sessions (default)
TINA4_SESSION_BACKEND=file

# Redis
TINA4_SESSION_BACKEND=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379

# MongoDB
TINA4_SESSION_BACKEND=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017

# Valkey
TINA4_SESSION_BACKEND=valkey
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
```

File-based sessions work out of the box. No extra dependencies. For production deployments with multiple servers, use Redis or Valkey so sessions are shared across instances.

### Using Sessions

Access session data via `request.session`:

```python
from tina4_python.core.router import get, post

@post("/login-form")
async def login_form(request, response):
    # After validating credentials...
    request.session["user_id"] = 42
    request.session["user_name"] = "Alice"
    request.session["logged_in"] = True

    return response.redirect("/dashboard")

@get("/dashboard")
async def dashboard(request, response):
    if not request.session.get("logged_in"):
        return response.redirect("/login")

    return response.render("dashboard.html", {
        "user_name": request.session["user_name"]
    })

@post("/logout")
async def logout(request, response):
    # Clear all session data
    request.session.clear()

    return response.redirect("/login")
```

### Session Options

```env
TINA4_SESSION_LIFETIME=3600       # Session lifetime in seconds (default: 3600)
TINA4_SESSION_NAME=tina4_session  # Cookie name for the session ID
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
curl -X POST http://localhost:7145/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'

# Login
curl -X POST http://localhost:7145/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securePass123"}'

# Save the token from login response, then:

# Get profile
curl http://localhost:7145/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# Update profile
curl -X PUT http://localhost:7145/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith"}'

# Change password
curl -X PUT http://localhost:7145/api/profile/password \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"current_password": "securePass123", "new_password": "evenMoreSecure456"}'

# Try with no token (should fail)
curl http://localhost:7145/api/profile
```

---

## 11. Solution

### Migration

Create `src/migrations/20260322160000_create_users_table.sql`:

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

```bash
tina4 migrate
```

### Routes

Create `src/routes/auth.py`:

```python
from tina4_python.core.router import get, post, put, noauth, middleware
from tina4_python.auth import Auth
from tina4_python.database.connection import Database


async def auth_middleware(request, response, next_handler):
    auth_header = request.headers.get("Authorization", "")

    if not auth_header or not auth_header.startswith("Bearer "):
        return response.json({"error": "Authorization required. Send: Authorization: Bearer <token>"}, 401)

    token = auth_header[7:]

    payload = Auth.valid_token(token)
    if payload is None:
        return response.json({"error": "Invalid or expired token. Please login again."}, 401)

    request.user = payload

    return await next_handler(request, response)


@post("/api/register")
@noauth()
async def register(request, response):
    body = request.body

    errors = []
    if not body.get("name"):
        errors.append("Name is required")
    if not body.get("email"):
        errors.append("Email is required")
    if not body.get("password"):
        errors.append("Password is required")
    elif len(body["password"]) < 8:
        errors.append("Password must be at least 8 characters")

    if errors:
        return response.json({"errors": errors}, 400)

    db = Database()

    existing = db.fetch_one("SELECT id FROM users WHERE email = ?", [body["email"]])
    if existing is not None:
        return response.json({"error": "Email already registered"}, 409)

    password_hash = Auth.hash_password(body["password"])

    result = db.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)",
        [body["name"], body["email"], password_hash]
    )

    user = db.fetch_one("SELECT id, name, email, role, created_at FROM users WHERE id = ?", [result.last_id])

    return response.json({"message": "Registration successful", "user": user}, 201)


@post("/api/login")
@noauth()
async def login(request, response):
    body = request.body

    if not body.get("email") or not body.get("password"):
        return response.json({"error": "Email and password are required"}, 400)

    db = Database()

    user = db.fetch_one(
        "SELECT id, name, email, password_hash, role FROM users WHERE email = ?",
        [body["email"]]
    )

    if user is None or not Auth.check_password(body["password"], user["password_hash"]):
        return response.json({"error": "Invalid email or password"}, 401)

    token = Auth.get_token({
        "user_id": user["id"],
        "email": user["email"],
        "name": user["name"],
        "role": user["role"]
    })

    return response.json({
        "message": "Login successful",
        "token": token,
        "user": {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"],
            "role": user["role"]
        }
    })


@get("/api/profile")
@middleware(auth_middleware)
async def get_profile(request, response):
    db = Database()

    user = db.fetch_one(
        "SELECT id, name, email, role, created_at FROM users WHERE id = ?",
        [request.user["user_id"]]
    )

    if user is None:
        return response.json({"error": "User not found"}, 404)

    return response.json(user)


@put("/api/profile")
@middleware(auth_middleware)
async def update_profile(request, response):
    db = Database()
    body = request.body
    user_id = request.user["user_id"]

    if body.get("email"):
        existing = db.fetch_one(
            "SELECT id FROM users WHERE email = ? AND id != ?",
            [body["email"], user_id]
        )
        if existing is not None:
            return response.json({"error": "Email already in use by another account"}, 409)

    current = db.fetch_one("SELECT * FROM users WHERE id = ?", [user_id])

    db.execute(
        "UPDATE users SET name = ?, email = ? WHERE id = ?",
        [body.get("name", current["name"]), body.get("email", current["email"]), user_id]
    )

    updated = db.fetch_one(
        "SELECT id, name, email, role, created_at FROM users WHERE id = ?",
        [user_id]
    )

    return response.json({"message": "Profile updated", "user": updated})


@put("/api/profile/password")
@middleware(auth_middleware)
async def change_password(request, response):
    db = Database()
    body = request.body
    user_id = request.user["user_id"]

    if not body.get("current_password") or not body.get("new_password"):
        return response.json({"error": "Current password and new password are required"}, 400)

    if len(body["new_password"]) < 8:
        return response.json({"error": "New password must be at least 8 characters"}, 400)

    user = db.fetch_one("SELECT password_hash FROM users WHERE id = ?", [user_id])

    if not Auth.check_password(body["current_password"], user["password_hash"]):
        return response.json({"error": "Current password is incorrect"}, 401)

    new_hash = Auth.hash_password(body["new_password"])

    db.execute(
        "UPDATE users SET password_hash = ? WHERE id = ?",
        [new_hash, user_id]
    )

    return response.json({"message": "Password changed successfully"})
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

---

## 12. Gotchas

### 1. Token expiry confusion

**Problem:** Tokens that worked yesterday now return 401.

**Cause:** The default token lifetime is 60 minutes (`TINA4_TOKEN_EXPIRES_IN=60`). After that, the token is invalid even if the signature is correct.

**Fix:** Issue a new token at login. If your application needs long-lived sessions, use refresh tokens: a short-lived access token (15 minutes) paired with a long-lived refresh token (7 days) that can be used to get a new access token without re-entering credentials.

### 2. Secret key management

**Problem:** Tokens generated on one server are invalid on another, or tokens stop working after a deployment.

**Cause:** Each server generated its own random `secrets/jwt.key` file. Or the key file was deleted/regenerated during deployment.

**Fix:** Set `SECRET` in `.env` explicitly and use the same value across all servers. Store it in your deployment secrets manager (not in version control). If the key changes, all existing tokens become invalid and users must log in again.

### 3. CORS with authentication

**Problem:** Frontend requests with the `Authorization` header fail with a CORS error, even though `CORS_ORIGINS=*` is set.

**Cause:** When the browser sends an `Authorization` header, it first sends a preflight `OPTIONS` request. The server must respond to the OPTIONS request with the correct CORS headers, including `Access-Control-Allow-Headers: Authorization`.

**Fix:** Tina4 handles preflight requests automatically. Make sure `CORS_ORIGINS` is set correctly. If it is still failing, check that you are not overriding CORS headers in middleware.

### 4. Storing tokens in localStorage

**Problem:** Your token is stolen via an XSS attack because it was stored in `localStorage`.

**Cause:** Any JavaScript on the page can read `localStorage`, including injected scripts from an XSS vulnerability.

**Fix:** Store tokens in `httpOnly` cookies when possible -- they cannot be accessed by JavaScript. For SPAs that must use `localStorage`, implement strict Content Security Policy headers and sanitize all user input.

### 5. Forgetting @noauth on login

**Problem:** Your login endpoint returns 401 -- you cannot log in because the endpoint requires authentication.

**Cause:** If you have global auth middleware, the login endpoint needs the `@noauth` decorator to bypass it.

**Fix:** Add `@noauth` to your login and register routes. Without it, users cannot authenticate because authentication is required to authenticate -- a catch-22.

### 6. Password hash column too short

**Problem:** Registration fails with a database error about the password hash being too long.

**Cause:** PBKDF2 hashes can be long. If your `password_hash` column is defined as `VARCHAR(50)`, it gets truncated.

**Fix:** Use `TEXT` for the password hash column, or at minimum `VARCHAR(255)`. Never constrain the hash length.

### 7. Token in URL query parameters

**Problem:** Tokens in URLs like `/api/profile?token=eyJ...` leak through browser history, server logs, and the Referer header.

**Cause:** Query parameters are visible in many places where headers are not.

**Fix:** Always send tokens in the `Authorization` header, never in the URL. The only exception is WebSocket connections, where the initial HTTP upgrade request cannot carry custom headers -- use a short-lived token for that case.
