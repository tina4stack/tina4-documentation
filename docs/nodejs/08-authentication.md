# Chapter 7: Authentication

## 1. Locking the Door

Every endpoint you have built so far is public. Anyone with the URL can read, create, update, and delete data. Fine for a tutorial. Unacceptable in production.

A real application needs identity. Who is making this request? And are they allowed to make it?

This chapter covers Tina4's authentication system: JWT tokens, password hashing, middleware-based route protection, CSRF tokens for forms, and session management.

---

## 2. JWT Tokens

Tina4 uses JSON Web Tokens (JWT) for authentication. A JWT is a signed string carrying a payload -- a user ID, a role, whatever you need. The server creates the token at login. The client sends it with every request. The server verifies it without touching the database.

### Generating a Token

```typescript
import { Auth } from "tina4-nodejs";

const payload = {
    user_id: 42,
    email: "alice@example.com",
    role: "admin"
};

const token = Auth.getToken(payload, secret);
```

`getToken()` signs the payload with HS256 (HMAC-SHA256) and returns a JWT string like:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjo0MiwiZW1haWwiOiJhbGljZUBleGFtcGxlLmNvbSIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTcxMTExMjYwMCwiZXhwIjoxNzExMTE2MjAwfQ.abc123signature
```

The token has three parts separated by dots: header, payload, and signature. The signature ensures the token has not been tampered with.

The `secret` parameter is required -- pass your secret key directly or read it from the `SECRET` env var.

> **Legacy aliases:** `Auth.getToken()` and the standalone `getToken()` function still work. Use the primary name in new code.

### Token Expiry

Pass the expiry time as the third argument to `getToken()` in **seconds**:

```typescript
const token = Auth.getToken(payload, secret, 3600); // 1 hour (default)
```

| Value | Duration |
|-------|----------|
| `900` | 15 minutes |
| `3600` | 1 hour (default) |
| `86400` | 24 hours |
| `604800` | 7 days |

You can also configure the default expiry in `.env`:

```env
TINA4_JWT_EXPIRY=86400
```

The value is in seconds. `86400` is 24 hours.

### Validating a Token

```typescript
const payload = Auth.validToken(token, secret);
// Returns the payload object if valid, null if invalid or expired
```

`validToken()` returns the decoded payload on success, not a boolean. This lets you validate and read the token in one step. Returns `null` if the token is invalid or expired.

> **Legacy alias:** `Auth.validateToken()` and the standalone `validToken()` function work the same way.

### Reading the Payload

```typescript
const payload = Auth.getPayload(token);
```

Returns the decoded payload **without validation** -- it just decodes the token:

```typescript
{
    user_id: 42,
    email: "alice@example.com",
    role: "admin",
    iat: 1711112600,  // issued at (Unix timestamp)
    exp: 1711116200   // expires at (Unix timestamp)
}
```

If the token cannot be decoded, `getPayload()` returns `null`.

> **Important:** `getPayload()` does not verify the signature or check expiry. Use `validToken()` when you need to confirm the token is trustworthy.

### The Secret Key and Algorithm

Tina4 Node.js uses **HS256** (HMAC-SHA256) for JWT signing. It uses only the standard library -- zero external dependencies.

Set the secret key in `.env`:

```env
SECRET=my-super-secret-key-at-least-32-chars
```

The `secret` parameter on `getToken()` and `validToken()` is optional -- if omitted, Tina4 reads from the `SECRET` env var. If neither is set, Tina4 falls back to generating a random key at `secrets/jwt.key` on first run. Setting `SECRET` explicitly is recommended for production so all server instances share the same key.

Keep this key secret. If someone gets it, they can forge tokens.

---

## 3. Password Hashing

Plain text passwords are a breach waiting to happen. Tina4 provides two functions for secure password handling.

### Hashing a Password

```typescript
import { Auth } from "tina4-nodejs";

const hash = await Auth.hashPassword("my-secure-password");
```

Uses PBKDF2 from the standard library -- no external dependencies. Each hash includes a random salt, so hashing the same password twice produces different results.

### Checking a Password

```typescript
const isCorrect = await Auth.checkPassword("my-secure-password", storedHash);
// Returns true if the password matches the hash
```

### Registration Example

```typescript
import { Router, Auth } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

/**
 * @noauth
 */
Router.post("/api/register", async (req, res) => {
    const body = req.body;

    // Validate input
    if (!body.name || !body.email || !body.password) {
        return res.status(400).json({ error: "Name, email, and password are required" });
    }

    if (body.password.length < 8) {
        return res.status(400).json({ error: "Password must be at least 8 characters" });
    }

    const db = Database.getConnection();

    // Check if email already exists
    const existing = await db.fetchOne("SELECT id FROM users WHERE email = :email", { email: body.email });
    if (existing !== null) {
        return res.status(409).json({ error: "Email already registered" });
    }

    // Hash the password
    const passwordHash = await Auth.hashPassword(body.password);

    // Create the user
    await db.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :hash)",
        { name: body.name, email: body.email, hash: passwordHash }
    );

    const user = await db.fetchOne("SELECT id, name, email FROM users WHERE id = last_insert_rowid()");

    return res.status(201).json({ message: "Registration successful", user });
});
```

```bash
curl -X POST http://localhost:7148/api/register \
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

```typescript
import { Router, Auth } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

/**
 * @noauth
 */
Router.post("/api/login", async (req, res) => {
    const body = req.body;

    if (!body.email || !body.password) {
        return res.status(400).json({ error: "Email and password are required" });
    }

    const db = Database.getConnection();

    // Find the user
    const user = await db.fetchOne(
        "SELECT id, name, email, password_hash FROM users WHERE email = :email",
        { email: body.email }
    );

    if (user === null) {
        return res.status(401).json({ error: "Invalid email or password" });
    }

    // Check the password
    if (!(await Auth.checkPassword(body.password, user.password_hash))) {
        return res.status(401).json({ error: "Invalid email or password" });
    }

    // Generate a token
    const secret = process.env.SECRET || "tina4-default-secret";
    const token = Auth.getToken({
        user_id: user.id,
        email: user.email,
        name: user.name
    }, secret);

    return res.json({
        message: "Login successful",
        token,
        user: { id: user.id, name: user.name, email: user.email }
    });
});
```

Notice `@noauth` in the JSDoc comment. The login endpoint must be public. You cannot require a token to get a token.

```bash
curl -X POST http://localhost:7148/api/login \
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
curl http://localhost:7148/api/profile \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

Or in frontend JavaScript:

```typescript
// Frontend JavaScript
const response = await fetch("/api/profile", {
    headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
    },
});
```

The token travels in the `Authorization` header with the `Bearer` prefix. The middleware extracts it, verifies it, and populates `req.user` with the decoded payload.

---

## 6. Protecting Routes

### Auth Middleware

Create a reusable auth middleware:

```typescript
import { Auth } from "tina4-nodejs";

function authMiddleware(req, res, next) {
    const authHeader = req.headers["authorization"] ?? "";

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res({ error: "Authorization header required" }, 401);
        return;
    }

    const token = authHeader.substring(7);  // Remove "Bearer " prefix
    const secret = process.env.SECRET || "tina4-default-secret";

    const payload = Auth.validToken(token, secret);
    if (payload === null) {
        res({ error: "Invalid or expired token" }, 401);
        return;
    }

    (req as any).user = payload;  // Attach user data to the request

    next();
}
```

### Applying Middleware to Routes

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/profile", async (req, res) => {
    return res.json({
        user_id: (req as any).user.user_id,
        email: (req as any).user.email,
        name: (req as any).user.name
    });
}, [authMiddleware]);
```

```bash
# Without token -- 401
curl http://localhost:7148/api/profile
```

```json
{"error":"Authorization header required"}
```

```bash
# With valid token -- 200
curl http://localhost:7148/api/profile \
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

```typescript
import { Router } from "tina4-nodejs";

Router.group("/api/admin", [authMiddleware], (router) => {

    router.get("/stats", async (req, res) => {
        return res.json({ active_users: 42 });
    });

    router.get("/logs", async (req, res) => {
        return res.json({ logs: [] });
    });

});
```

Every route in the group requires a valid token.

---

## 7. @noauth and @secured Decorators

These JSDoc annotations control authentication at the route level.

### @noauth -- Skip Authentication

Use `@noauth` for public endpoints that should bypass any global or group-level auth:

```typescript
import { Router } from "tina4-nodejs";

/**
 * @noauth
 */
Router.get("/api/public/health", async (req, res) => {
    return res.json({ status: "ok" });
});

/**
 * @noauth
 */
Router.post("/api/login", async (req, res) => {
    // Login logic
});

/**
 * @noauth
 */
Router.post("/api/register", async (req, res) => {
    // Registration logic
});
```

### @secured -- Require Authentication for GET Routes

By default, POST, PUT, PATCH, and DELETE routes are considered secured. GET routes are public. Use `@secured` to explicitly protect a GET route:

```typescript
import { Router } from "tina4-nodejs";

/**
 * @secured
 */
Router.get("/api/me", async (req, res) => {
    // This GET route requires authentication
    return res.json((req as any).user);
});
```

### Role-Based Authorization

Combine auth middleware with role checks:

```typescript
import { Auth } from "tina4-nodejs";

function requireRole(role: string) {
    return function (req, res, next) {
        const authHeader = req.headers["authorization"] ?? "";
        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            res({ error: "Authorization required" }, 401);
            return;
        }

        const token = authHeader.substring(7);
        const secret = process.env.SECRET || "tina4-default-secret";
        const payload = Auth.validToken(token, secret);
        if (payload === null) {
            res({ error: "Invalid or expired token" }, 401);
            return;
        }

        if ((payload.role ?? "") !== role) {
            res({ error: `Forbidden. Required role: ${role}` }, 403);
            return;
        }

        (req as any).user = payload;
        next();
    };
}
```

Use it as middleware:

```typescript
import { Router } from "tina4-nodejs";

Router.delete("/api/users/:id", async (req, res) => {
    // Only admins can delete users
    return res.json({ deleted: true });
}, [requireRole("admin")]);
```

---

## 8. CSRF Protection

Traditional form-based applications (not SPAs) need CSRF protection. Cross-Site Request Forgery attacks trick a user's browser into submitting a form to your server. The browser sends cookies automatically -- the attacker rides on the user's session.

CSRF tokens stop this. Each form gets a unique token. When the form submits, the server checks the token. If it does not match, the request is rejected.

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

```typescript
import { Router, Auth } from "tina4-nodejs";

Router.post("/profile/update", async (req, res) => {
    // Validate CSRF token
    if (!Auth.validateFormToken(req.body._token ?? "")) {
        return res.status(403).json({ error: "Invalid form token. Please refresh and try again." });
    }

    // Process the form...
    return res.redirect("/profile");
});
```

The CSRF token is tied to the session and expires after a single use. A malicious site cannot forge a form submission because it cannot guess the token.

### CSRF Middleware

For automatic validation on all POST/PUT/DELETE requests, use the CSRF middleware:

```typescript
import { csrfMiddleware } from "tina4-nodejs";

// Apply globally to all form-based routes
Router.post("/profile/update", async (req, res) => {
    // CSRF validation happens automatically
    return res.redirect("/profile");
}, [csrfMiddleware]);
```

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

Access session data via `req.session`:

```typescript
import { Router } from "tina4-nodejs";

Router.post("/login-form", async (req, res) => {
    // After validating credentials...
    req.session.userId = 42;
    req.session.userName = "Alice";
    req.session.loggedIn = true;

    return res.redirect("/dashboard");
});

Router.get("/dashboard", async (req, res) => {
    if (!req.session.loggedIn) {
        return res.redirect("/login");
    }

    return res.html("dashboard.html", {
        userName: req.session.userName
    });
});

Router.post("/logout", async (req, res) => {
    // Clear all session data
    req.session = {};

    return res.redirect("/login");
});
```

Sessions complement JWT tokens. Use JWT for stateless API authentication. Use sessions for traditional web applications with server-rendered pages.

### Session Options

```env
TINA4_SESSION_LIFETIME=3600       # Session lifetime in seconds (default: 3600)
TINA4_SESSION_NAME=tina4_session  # Cookie name for the session ID
```

---

## 10. Token Refresh

Tokens expire. When they do, `Auth.validToken()` returns `null` and the middleware rejects the request with a `401`. The user must log in again -- unless you implement token refresh.

A refresh endpoint issues a new token before the current one expires:

```typescript
import { Router, Auth } from "tina4-nodejs";

Router.post("/api/auth/refresh", async (req, res) => {
    // req.user is populated by auth middleware
    const secret = process.env.SECRET || "tina4-default-secret";
    const newToken = Auth.getToken({
        user_id: req.user.user_id,
        email: req.user.email,
        role: req.user.role,
    }, secret);

    return res.json({ token: newToken });
}, [authMiddleware]);
```

The frontend can call this endpoint periodically to keep the session alive without requiring re-login. A common pattern: a short-lived access token (15 minutes) paired with a long-lived refresh token (7 days). The refresh token can mint new access tokens without re-entering credentials.

---

## 11. Exercise: Build Login, Register, and Profile

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

3. Create auth middleware that extracts the user from the JWT and attaches it to `req.user`.

### Test with:

```bash
# Register
curl -X POST http://localhost:7148/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'

# Login
curl -X POST http://localhost:7148/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "password": "securePass123"}'

# Save the token from login response, then:

# Get profile
curl http://localhost:7148/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# Update profile
curl -X PUT http://localhost:7148/api/profile \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Smith"}'

# Change password
curl -X PUT http://localhost:7148/api/profile/password \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"current_password": "securePass123", "new_password": "evenMoreSecure456"}'

# Try with no token (should fail)
curl http://localhost:7148/api/profile
```

---

## 12. Solution

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

Create `src/routes/auth.ts`:

```typescript
import { Router, Auth } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";


function authMiddleware(req, res, next) {
    const authHeader = req.headers["authorization"] ?? "";

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res({ error: "Authorization required. Send: Authorization: Bearer <token>" }, 401);
        return;
    }

    const token = authHeader.substring(7);
    const secret = process.env.SECRET || "tina4-default-secret";

    const payload = Auth.validToken(token, secret);
    if (payload === null) {
        res({ error: "Invalid or expired token. Please login again." }, 401);
        return;
    }

    req.user = payload;

    next();
}


/**
 * @noauth
 */
Router.post("/api/register", async (req, res) => {
    const body = req.body;
    const errors: string[] = [];

    if (!body.name) errors.push("Name is required");
    if (!body.email) errors.push("Email is required");
    if (!body.password) errors.push("Password is required");
    else if (body.password.length < 8) errors.push("Password must be at least 8 characters");

    if (errors.length > 0) {
        return res.status(400).json({ errors });
    }

    const db = Database.getConnection();

    const existing = await db.fetchOne("SELECT id FROM users WHERE email = :email", { email: body.email });
    if (existing !== null) {
        return res.status(409).json({ error: "Email already registered" });
    }

    const hash = await Auth.hashPassword(body.password);

    await db.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :hash)",
        { name: body.name, email: body.email, hash }
    );

    const user = await db.fetchOne("SELECT id, name, email, role, created_at FROM users WHERE id = last_insert_rowid()");

    return res.status(201).json({ message: "Registration successful", user });
});


/**
 * @noauth
 */
Router.post("/api/login", async (req, res) => {
    const body = req.body;

    if (!body.email || !body.password) {
        return res.status(400).json({ error: "Email and password are required" });
    }

    const db = Database.getConnection();

    const user = await db.fetchOne(
        "SELECT id, name, email, password_hash, role FROM users WHERE email = :email",
        { email: body.email }
    );

    if (user === null || !(await Auth.checkPassword(body.password, user.password_hash))) {
        return res.status(401).json({ error: "Invalid email or password" });
    }

    const secret = process.env.SECRET || "tina4-default-secret";
    const token = Auth.getToken({
        user_id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
    }, secret);

    return res.json({
        message: "Login successful",
        token,
        user: { id: user.id, name: user.name, email: user.email, role: user.role }
    });
});


Router.get("/api/profile", async (req, res) => {
    const db = Database.getConnection();

    const user = await db.fetchOne(
        "SELECT id, name, email, role, created_at FROM users WHERE id = :id",
        { id: req.user.user_id }
    );

    if (user === null) {
        return res.status(404).json({ error: "User not found" });
    }

    return res.json(user);
}, [authMiddleware]);


Router.put("/api/profile", async (req, res) => {
    const db = Database.getConnection();
    const body = req.body;
    const userId = req.user.user_id;

    // Check if the new email is already taken by another account
    if (body.email) {
        const existing = await db.fetchOne(
            "SELECT id FROM users WHERE email = :email AND id != :id",
            { email: body.email, id: userId }
        );
        if (existing !== null) {
            return res.status(409).json({ error: "Email already in use by another account" });
        }
    }

    const current = await db.fetchOne("SELECT * FROM users WHERE id = :id", { id: userId });

    await db.execute(
        "UPDATE users SET name = :name, email = :email WHERE id = :id",
        { name: body.name ?? current.name, email: body.email ?? current.email, id: userId }
    );

    const updated = await db.fetchOne(
        "SELECT id, name, email, role, created_at FROM users WHERE id = :id",
        { id: userId }
    );

    return res.json({ message: "Profile updated", user: updated });
}, [authMiddleware]);


Router.put("/api/profile/password", async (req, res) => {
    const db = Database.getConnection();
    const body = req.body;
    const userId = req.user.user_id;

    if (!body.current_password || !body.new_password) {
        return res.status(400).json({ error: "Current password and new password are required" });
    }

    if (body.new_password.length < 8) {
        return res.status(400).json({ error: "New password must be at least 8 characters" });
    }

    const user = await db.fetchOne("SELECT password_hash FROM users WHERE id = :id", { id: userId });

    if (!(await Auth.checkPassword(body.current_password, user.password_hash))) {
        return res.status(401).json({ error: "Current password is incorrect" });
    }

    const newHash = await Auth.hashPassword(body.new_password);
    await db.execute("UPDATE users SET password_hash = :hash WHERE id = :id", { hash: newHash, id: userId });

    return res.json({ message: "Password changed successfully" });
}, [authMiddleware]);
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

## 13. Gotchas

### 1. Token Expiry Confusion

**Problem:** Tokens that worked yesterday now return 401.

**Cause:** The default token lifetime is 1 hour (3600 seconds). After that, the token is invalid even if the signature is correct.

**Fix:** Issue a new token at login. If your application needs long-lived sessions, use refresh tokens: a short-lived access token (15 minutes) paired with a long-lived refresh token (7 days) that can be used to get a new access token without re-entering credentials.

### 2. Secret Key Management

**Problem:** Tokens generated on one server are invalid on another, or tokens stop working after a deployment.

**Cause:** Each server generated its own random `secrets/jwt.key` file. Or the key file was deleted or regenerated during deployment.

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

**Fix:** Add `@noauth` in a JSDoc comment above your login and register routes. Without it, users cannot authenticate because authentication is required to authenticate -- a catch-22.

### 6. Password Hash Column Too Short

**Problem:** Registration fails with a database error about the password hash being too long.

**Cause:** PBKDF2 hashes can be long. If your `password_hash` column is defined as `VARCHAR(50)`, it gets truncated.

**Fix:** Use `TEXT` for the password hash column, or at minimum `VARCHAR(255)`. Never constrain the hash length.

### 7. Token in URL Query Parameters

**Problem:** Tokens in URLs like `/api/profile?token=eyJ...` leak through browser history, server logs, and the Referer header.

**Cause:** Query parameters are visible in many places where headers are not.

**Fix:** Always send tokens in the `Authorization` header, never in the URL. The only exception is WebSocket connections, where the initial HTTP upgrade request cannot carry custom headers -- use a short-lived token for that case.
