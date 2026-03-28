# Chapter 7: Authentication

## 1. Locking the Door

Every endpoint built so far is public. Anyone with the URL can read, create, update, delete. That works for a tutorial. A real application needs to know who is making a request and whether they are allowed.

This chapter covers Tina4's authentication system: JWT tokens, password hashing, middleware-based route protection, CSRF tokens for forms, and session management.

---

## 2. JWT Tokens

Tina4 uses JSON Web Tokens for authentication. A JWT is a signed string containing a payload -- user ID, role, expiry. The server creates it at login. The client sends it with every request. The server verifies it without touching the database.

### Generating a Token

```php
<?php
use Tina4\Auth;

$payload = [
    "user_id" => 42,
    "email" => "alice@example.com",
    "role" => "admin"
];

$token = Auth::getToken($payload, $secret);
```

`getToken()` signs the payload with HS256 (HMAC-SHA256) using the provided secret. The `$secret` parameter is **required**. Returns a JWT string:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo0MiwiZW1haWwiOiJhbGljZUBleGFtcGxlLmNvbSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTcxMTExMjYwMCwiZXhwIjoxNzExMTE2MjAwfQ.abc123signature
```

Three parts separated by dots: header, payload, signature. The signature ensures the token has not been tampered with.

> **Legacy aliases:** `Auth::createToken()` still works as an alias for `Auth::getToken()`. Use the primary name in new code.

### Token Expiry

Tokens expire after 60 minutes by default. Configure in `.env`:

```env
TINA4_TOKEN_LIMIT=60
```

Value in **minutes** (default: 60):

| Value | Duration |
|-------|----------|
| `15` | 15 minutes |
| `60` | 1 hour (default) |
| `1440` | 24 hours |
| `10080` | 7 days |

### Validating a Token

```php
$payload = Auth::validToken($token, $secret);
// Returns the payload array if valid, null if invalid or expired
```

`validToken()` returns the decoded payload on success, not a boolean. This lets you validate and read the token in one step. Returns `null` if the token is invalid or expired.

> **Legacy alias:** `Auth::validateToken()` works the same way.

### Reading the Payload

```php
$payload = Auth::getPayload($token);
```

Returns the decoded payload **without validation** -- it just decodes the token. Note that `getPayload()` takes only the token string -- no secret is needed because it does not verify the signature:

```php
[
    "user_id" => 42,
    "email" => "alice@example.com",
    "role" => "admin",
    "iat" => 1711112600,  // issued at (Unix timestamp)
    "exp" => 1711116200   // expires at (Unix timestamp)
]
```

If the token cannot be decoded: `null`.

> **Important:** `getPayload()` does not verify the signature or check expiry. Use `validToken()` when you need to confirm the token is trustworthy.

### The Secret Key and Algorithm

Tina4 PHP uses **HS256** (HMAC-SHA256) for JWT signing. It uses only the standard library -- zero external dependencies.

Set the secret key in `.env`:

```env
SECRET=my-super-secret-key-at-least-32-chars
```

The `$secret` parameter is **required** on `getToken()` and `validToken()`. Pass it explicitly -- there is no automatic fallback. Read it from your `.env` in your route handler:

```php
$secret = $_ENV["SECRET"] ?? getenv("SECRET");
```

`getPayload()` does not take a secret at all -- it decodes without verifying.

Guard this key. Anyone who has it can forge tokens.

---

## 3. Password Hashing

Passwords in plain text are a breach waiting to happen. Tina4 provides two functions for secure password handling.

### Hashing a Password

```php
use Tina4\Auth;

$hash = Auth::hashPassword("my-secure-password");
// Returns: "$2y$10$abc123...long-hash-string..."
```

Uses PBKDF2 from the standard library -- no external dependencies. Each hash includes a random salt. Hashing the same password twice produces different results.

### Checking a Password

```php
$isCorrect = Auth::checkPassword("my-secure-password", $storedHash);
// true if the password matches
```

### Registration Example

```php
<?php
use Tina4\Router;
use Tina4\Auth;
use Tina4\Database;

Router::post("/api/register", function ($request, $response) {
    $body = $request->body;

    if (empty($body["name"]) || empty($body["email"]) || empty($body["password"])) {
        return $response->json(["error" => "Name, email, and password are required"], 400);
    }

    if (strlen($body["password"]) < 8) {
        return $response->json(["error" => "Password must be at least 8 characters"], 400);
    }

    $db = Database::getConnection();

    $existing = $db->fetchOne("SELECT id FROM users WHERE email = :email", ["email" => $body["email"]]);
    if ($existing !== null) {
        return $response->json(["error" => "Email already registered"], 409);
    }

    $passwordHash = Auth::hashPassword($body["password"]);

    $db->execute(
        "INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :hash)",
        [
            "name" => $body["name"],
            "email" => $body["email"],
            "hash" => $passwordHash
        ]
    );

    $user = $db->fetchOne("SELECT id, name, email FROM users WHERE id = last_insert_rowid()");

    return $response->json([
        "message" => "Registration successful",
        "user" => $user
    ], 201);
});
```

```bash
curl -X POST http://localhost:7146/api/register \
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

Client sends credentials. Server validates them. Server returns a JWT.

```php
<?php
use Tina4\Router;
use Tina4\Auth;
use Tina4\Database;

/**
 * @noauth
 */
Router::post("/api/login", function ($request, $response) {
    $body = $request->body;

    if (empty($body["email"]) || empty($body["password"])) {
        return $response->json(["error" => "Email and password are required"], 400);
    }

    $db = Database::getConnection();

    $user = $db->fetchOne(
        "SELECT id, name, email, password_hash FROM users WHERE email = :email",
        ["email" => $body["email"]]
    );

    if ($user === null) {
        return $response->json(["error" => "Invalid email or password"], 401);
    }

    if (!Auth::checkPassword($body["password"], $user["password_hash"])) {
        return $response->json(["error" => "Invalid email or password"], 401);
    }

    $token = Auth::getToken([
        "user_id" => $user["id"],
        "email" => $user["email"],
        "name" => $user["name"]
    ]);

    return $response->json([
        "message" => "Login successful",
        "token" => $token,
        "user" => [
            "id" => $user["id"],
            "name" => $user["name"],
            "email" => $user["email"]
        ]
    ]);
});
```

The `@noauth` annotation is critical. The login endpoint must be public. You cannot require a token to get a token.

```bash
curl -X POST http://localhost:7146/api/login \
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

The client stores the token and sends it with subsequent requests.

---

## 5. Using Tokens in Requests

The token travels in the `Authorization` header with the `Bearer` prefix:

```bash
curl http://localhost:7146/api/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 6. Protecting Routes

### Auth Middleware

A reusable gate:

```php
<?php
use Tina4\Auth;

function authMiddleware($request, $response, $next) {
    $authHeader = $request->header("Authorization") ?? "";

    if (empty($authHeader) || !str_starts_with($authHeader, "Bearer ")) {
        return $response->json(["error" => "Authorization header required"], 401);
    }

    $token = substr($authHeader, 7); // Remove "Bearer " prefix

    $payload = Auth::validToken($token);
    if ($payload === null) {
        return $response->json(["error" => "Invalid or expired token"], 401);
    }

    $request->user = $payload; // Attach user data to the request

    return $next($request, $response);
}
```

### Applying Middleware to Routes

```php
<?php
use Tina4\Router;

Router::get("/api/profile", function ($request, $response) {
    return $response->json([
        "user_id" => $request->user["user_id"],
        "email" => $request->user["email"],
        "name" => $request->user["name"]
    ]);
}, "authMiddleware");
```

```bash
# Without token -- 401
curl http://localhost:7146/api/profile
```

```json
{"error":"Authorization header required"}
```

```bash
# With valid token -- 200
curl http://localhost:7146/api/profile \
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

```php
Router::group("/api/admin", function () {

    Router::get("/stats", function ($request, $response) {
        return $response->json(["active_users" => 42]);
    });

    Router::get("/logs", function ($request, $response) {
        return $response->json(["logs" => []]);
    });

}, "authMiddleware");
```

Every route in the group requires a valid token.

---

## 7. @noauth and @secured Decorators

Two decorators for route-level authentication control. Introduced in Chapter 2. Here they are in context.

### @noauth -- Skip Authentication

Public endpoints that bypass global or group-level auth:

```php
/**
 * @noauth
 */
Router::get("/api/public/health", function ($request, $response) {
    return $response->json(["status" => "ok"]);
});

/**
 * @noauth
 */
Router::post("/api/login", function ($request, $response) {
    // Login logic
});

/**
 * @noauth
 */
Router::post("/api/register", function ($request, $response) {
    // Registration logic
});
```

### @secured -- Require Authentication for GET Routes

POST, PUT, PATCH, DELETE are secured by default. GET is public. Use `@secured` to protect a GET route:

```php
/**
 * @secured
 */
Router::get("/api/me", function ($request, $response) {
    return $response->json($request->user);
});
```

### Role-Based Authorization

Combine auth middleware with role checks:

```php
<?php
use Tina4\Auth;

function requireRole($role) {
    return function ($request, $response, $next) use ($role) {
        $authHeader = $request->header("Authorization") ?? "";
        if (empty($authHeader) || !str_starts_with($authHeader, "Bearer ")) {
            return $response->json(["error" => "Authorization required"], 401);
        }

        $token = substr($authHeader, 7);
        $payload = Auth::validToken($token);
        if ($payload === null) {
            return $response->json(["error" => "Invalid or expired token"], 401);
        }

        if (($payload["role"] ?? "") !== $role) {
            return $response->json(["error" => "Forbidden. Required role: " . $role], 403);
        }

        $request->user = $payload;
        return $next($request, $response);
    };
}
```

`requireRole()` returns a closure. Register the returned function as middleware:

```php
$adminOnly = requireRole("admin");

Router::delete("/api/users/{id:int}", function ($request, $response) {
    return $response->json(["deleted" => true]);
}, $adminOnly);
```

---

## 8. CSRF Protection

For traditional form-based applications (not SPAs), Tina4 provides CSRF protection.

### Generating a Token

Include the CSRF token in every form:

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

`{{ form_token() }}` renders a hidden input:

```html
<input type="hidden" name="_token" value="abc123randomtoken456">
```

### Validating the Token

```php
<?php
use Tina4\Router;
use Tina4\Auth;

Router::post("/profile/update", function ($request, $response) {
    if (!Auth::validateFormToken($request->body["_token"] ?? "")) {
        return $response->json(["error" => "Invalid form token. Please refresh and try again."], 403);
    }

    // Process the form...
    return $response->redirect("/profile");
});
```

The token is tied to the user's session and expires after one use. A malicious site cannot forge it.

### When to Use CSRF Tokens

Use them for:
- HTML forms submitted by browsers
- POST/PUT/DELETE from server-rendered pages

Skip them for:
- API endpoints using JWT (the Bearer token proves intent)
- SPAs using `fetch()` with custom headers (the `Authorization` header cannot be set by cross-origin forms)

---

## 9. Sessions

Server-side sessions store per-user state between requests. Use JWTs for API authentication. Use sessions for stateful web pages.

### Session Configuration

Set the backend in `.env`:

```env
# File-based sessions (default)
TINA4_SESSION_DRIVER=file

# Redis
TINA4_SESSION_DRIVER=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379

# MongoDB
TINA4_SESSION_DRIVER=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017

# Valkey
TINA4_SESSION_DRIVER=valkey
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
```

File sessions work out of the box. Redis or Valkey for multi-server production deployments where sessions must be shared across instances.

### Using Sessions

Access session data through `$request->session`:

```php
<?php
use Tina4\Router;

Router::post("/login-form", function ($request, $response) {
    // After validating credentials...
    $request->session["user_id"] = 42;
    $request->session["user_name"] = "Alice";
    $request->session["logged_in"] = true;

    return $response->redirect("/dashboard");
});

Router::get("/dashboard", function ($request, $response) {
    if (empty($request->session["logged_in"])) {
        return $response->redirect("/login");
    }

    return $response->render("dashboard.html", [
        "user_name" => $request->session["user_name"]
    ]);
});

Router::post("/logout", function ($request, $response) {
    $request->session = [];

    return $response->redirect("/login");
});
```

### Session Options

```env
TINA4_SESSION_LIFETIME=3600       # Expires after 1 hour of inactivity
TINA4_SESSION_NAME=tina4_session  # Cookie name for the session ID
```

---

## 10. Exercise: Build Login, Register, and Profile

A complete authentication system. Registration, login, profile viewing, password changing.

### Requirements

1. Create a `users` table migration: `id`, `name`, `email` (unique), `password_hash`, `role` (default "user"), `created_at`

2. Build these endpoints:

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/register` | @noauth | Create account. Validate name, email, password (min 8 chars). |
| `POST` | `/api/login` | @noauth | Login. Return JWT. |
| `GET` | `/api/profile` | secured | Get profile from token. |
| `PUT` | `/api/profile` | secured | Update name and email. |
| `PUT` | `/api/profile/password` | secured | Change password. Require current password. |

3. Create auth middleware that extracts the user from the JWT and attaches it to `$request->user`.

### Test with:

```bash
# Register
curl -X POST http://localhost:7146/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'

# Login
curl -X POST http://localhost:7146/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securePass123"}'

# Save the token, then:

# Get profile
curl http://localhost:7146/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# Update profile
curl -X PUT http://localhost:7146/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith"}'

# Change password
curl -X PUT http://localhost:7146/api/profile/password \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"current_password": "securePass123", "new_password": "evenMoreSecure456"}'

# No token (should fail)
curl http://localhost:7146/api/profile
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

```bash
tina4 migrate
```

### Middleware

Create `src/routes/middleware.php`:

```php
<?php
use Tina4\Auth;

function authMiddleware($request, $response, $next) {
    $authHeader = $request->header("Authorization") ?? "";

    if (empty($authHeader) || !str_starts_with($authHeader, "Bearer ")) {
        return $response->json(["error" => "Authorization required. Send: Authorization: Bearer <token>"], 401);
    }

    $token = substr($authHeader, 7);

    $payload = Auth::validToken($token);
    if ($payload === null) {
        return $response->json(["error" => "Invalid or expired token. Please login again."], 401);
    }

    $request->user = $payload;

    return $next($request, $response);
}
```

### Routes

Create `src/routes/auth.php`:

```php
<?php
use Tina4\Router;
use Tina4\Auth;
use Tina4\Database;

/**
 * @noauth
 */
Router::post("/api/register", function ($request, $response) {
    $body = $request->body;

    $errors = [];
    if (empty($body["name"])) $errors[] = "Name is required";
    if (empty($body["email"])) $errors[] = "Email is required";
    if (empty($body["password"])) {
        $errors[] = "Password is required";
    } elseif (strlen($body["password"]) < 8) {
        $errors[] = "Password must be at least 8 characters";
    }

    if (!empty($errors)) {
        return $response->json(["errors" => $errors], 400);
    }

    $db = Database::getConnection();

    $existing = $db->fetchOne("SELECT id FROM users WHERE email = :email", ["email" => $body["email"]]);
    if ($existing !== null) {
        return $response->json(["error" => "Email already registered"], 409);
    }

    $hash = Auth::hashPassword($body["password"]);

    $db->execute(
        "INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :hash)",
        ["name" => $body["name"], "email" => $body["email"], "hash" => $hash]
    );

    $user = $db->fetchOne("SELECT id, name, email, role, created_at FROM users WHERE id = last_insert_rowid()");

    return $response->json(["message" => "Registration successful", "user" => $user], 201);
});

/**
 * @noauth
 */
Router::post("/api/login", function ($request, $response) {
    $body = $request->body;

    if (empty($body["email"]) || empty($body["password"])) {
        return $response->json(["error" => "Email and password are required"], 400);
    }

    $db = Database::getConnection();

    $user = $db->fetchOne(
        "SELECT id, name, email, password_hash, role FROM users WHERE email = :email",
        ["email" => $body["email"]]
    );

    if ($user === null || !Auth::checkPassword($body["password"], $user["password_hash"])) {
        return $response->json(["error" => "Invalid email or password"], 401);
    }

    $token = Auth::getToken([
        "user_id" => $user["id"],
        "email" => $user["email"],
        "name" => $user["name"],
        "role" => $user["role"]
    ]);

    return $response->json([
        "message" => "Login successful",
        "token" => $token,
        "user" => ["id" => $user["id"], "name" => $user["name"], "email" => $user["email"], "role" => $user["role"]]
    ]);
});

Router::get("/api/profile", function ($request, $response) {
    $db = Database::getConnection();

    $user = $db->fetchOne(
        "SELECT id, name, email, role, created_at FROM users WHERE id = :id",
        ["id" => $request->user["user_id"]]
    );

    if ($user === null) {
        return $response->json(["error" => "User not found"], 404);
    }

    return $response->json($user);
}, "authMiddleware");

Router::put("/api/profile", function ($request, $response) {
    $db = Database::getConnection();
    $body = $request->body;
    $userId = $request->user["user_id"];

    if (!empty($body["email"])) {
        $existing = $db->fetchOne(
            "SELECT id FROM users WHERE email = :email AND id != :id",
            ["email" => $body["email"], "id" => $userId]
        );
        if ($existing !== null) {
            return $response->json(["error" => "Email already in use by another account"], 409);
        }
    }

    $current = $db->fetchOne("SELECT * FROM users WHERE id = :id", ["id" => $userId]);

    $db->execute(
        "UPDATE users SET name = :name, email = :email WHERE id = :id",
        ["name" => $body["name"] ?? $current["name"], "email" => $body["email"] ?? $current["email"], "id" => $userId]
    );

    $updated = $db->fetchOne("SELECT id, name, email, role, created_at FROM users WHERE id = :id", ["id" => $userId]);

    return $response->json(["message" => "Profile updated", "user" => $updated]);
}, "authMiddleware");

Router::put("/api/profile/password", function ($request, $response) {
    $db = Database::getConnection();
    $body = $request->body;
    $userId = $request->user["user_id"];

    if (empty($body["current_password"]) || empty($body["new_password"])) {
        return $response->json(["error" => "Current password and new password are required"], 400);
    }

    if (strlen($body["new_password"]) < 8) {
        return $response->json(["error" => "New password must be at least 8 characters"], 400);
    }

    $user = $db->fetchOne("SELECT password_hash FROM users WHERE id = :id", ["id" => $userId]);

    if (!Auth::checkPassword($body["current_password"], $user["password_hash"])) {
        return $response->json(["error" => "Current password is incorrect"], 401);
    }

    $newHash = Auth::hashPassword($body["new_password"]);

    $db->execute("UPDATE users SET password_hash = :hash WHERE id = :id", ["hash" => $newHash, "id" => $userId]);

    return $response->json(["message" => "Password changed successfully"]);
}, "authMiddleware");
```

**Expected output for register:** `201 Created` with user data.

**Expected output for login:** `200 OK` with token and user data.

**Expected output for profile without token:** `401 Unauthorized`.

**Expected output for profile with token:** `200 OK` with user data.

**Expected output for wrong current password:** `401 Unauthorized`.

**Expected output for successful password change:** `{"message":"Password changed successfully"}`.

---

## 12. Gotchas

### 1. Token Expiry Confusion

**Problem:** Tokens that worked yesterday return 401 today.

**Cause:** Default lifetime is 60 minutes (`TINA4_TOKEN_LIMIT=60`). After that, the token is invalid.

**Fix:** Issue a new token at login. For long-lived sessions, use refresh tokens: a short-lived access token (15 minutes) paired with a long-lived refresh token (7 days).

### 2. Secret Key Management

**Problem:** Tokens from one server fail on another. Or tokens stop working after deployment.

**Cause:** Each server generated its own `secrets/jwt.key`. Or the key was regenerated during deployment.

**Fix:** Set `SECRET` in `.env` and use the same value across all servers. Store it in your secrets manager. Not in version control. Key change invalidates all tokens. Users must log in again.

### 3. CORS with Authentication

**Problem:** Frontend requests with `Authorization` header fail with CORS error, even with `CORS_ORIGINS=*`.

**Cause:** The browser sends a preflight `OPTIONS` request. The server must respond with CORS headers including `Access-Control-Allow-Headers: Authorization`.

**Fix:** Tina4 handles preflight requests. Verify `CORS_ORIGINS` is set. Check that middleware is not overriding CORS headers.

### 4. Storing Tokens in localStorage

**Problem:** Token stolen via XSS because it lived in `localStorage`.

**Cause:** Any JavaScript on the page reads `localStorage`, including injected scripts.

**Fix:** Use `httpOnly` cookies when possible -- invisible to JavaScript. For SPAs that must use `localStorage`, enforce strict Content Security Policy headers. Sanitize all input.

### 5. Forgetting @noauth on Login

**Problem:** Login endpoint returns 401. Cannot log in.

**Cause:** Global auth middleware blocks the login endpoint. You need a token to get a token. A catch-22.

**Fix:** Add `@noauth` to login and register routes.

### 6. Password Hash Column Too Short

**Problem:** Registration fails with a database error about truncation.

**Cause:** PBKDF2 hashes can be long. `VARCHAR(50)` truncates them.

**Fix:** Use `TEXT` for the password hash column. Or at minimum `VARCHAR(255)`.

### 7. Token in URL Query Parameters

**Problem:** Tokens in URLs like `/api/profile?token=eyJ...` leak through browser history, server logs, and Referer headers.

**Fix:** Always send tokens in the `Authorization` header. The only exception: WebSocket connections where the upgrade request cannot carry custom headers. Use a short-lived token for that case.
