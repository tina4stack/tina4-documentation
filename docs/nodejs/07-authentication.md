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

`getToken()` signs the payload with HS256 (HMAC-SHA256) and returns a JWT string. The `secret` parameter is optional -- if omitted, Tina4 reads from the `SECRET` env var.

> **Legacy aliases:** `Auth.getToken()` and the standalone `getToken()` function still work. Use the primary name in new code.

### Token Expiry

Configure in `.env`:

```env
TINA4_TOKEN_EXPIRES_IN=60
```

The value is in **minutes**:

| Value | Duration |
|-------|----------|
| `15` | 15 minutes |
| `60` | 1 hour (default) |
| `1440` | 24 hours |
| `10080` | 7 days |

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
// Returns: { user_id: 42, email: "alice@example.com", role: "admin", iat: ..., exp: ... }
```

Returns the decoded payload **without validation** -- it just decodes the token. Returns `null` if the token cannot be decoded.

> **Important:** `getPayload()` does not verify the signature or check expiry. Use `validToken()` when you need to confirm the token is trustworthy.

### The Secret Key and Algorithm

Tina4 Node.js uses **HS256** (HMAC-SHA256) for JWT signing. It uses only the standard library -- zero external dependencies.

Set the secret key in `.env`:

```env
SECRET=my-super-secret-key-at-least-32-chars
```

The `secret` parameter on `getToken()` and `validToken()` is optional -- if omitted, Tina4 reads from the `SECRET` env var. If neither is set, Tina4 falls back to generating a random key at `secrets/jwt.key` on first run.

---

## 3. Password Hashing

Plain text passwords are a breach waiting to happen.

### Hashing a Password

```typescript
import { Auth } from "tina4-nodejs";

const hash = await Auth.hashPassword("my-secure-password");
```

Uses PBKDF2 from the standard library -- no external dependencies.

### Checking a Password

```typescript
const isCorrect = await Auth.checkPassword("my-secure-password", storedHash);
```

### Registration Example

```typescript
import { Router, Auth, Database } from "tina4-nodejs";

Router.post("/api/register", async (req, res) => {
    const body = req.body;

    if (!body.name || !body.email || !body.password) {
        return res.status(400).json({ error: "Name, email, and password are required" });
    }

    if (body.password.length < 8) {
        return res.status(400).json({ error: "Password must be at least 8 characters" });
    }

    const db = Database.getConnection();

    const existing = await db.fetchOne("SELECT id FROM users WHERE email = :email", { email: body.email });
    if (existing !== null) {
        return res.status(409).json({ error: "Email already registered" });
    }

    const passwordHash = await Auth.hashPassword(body.password);

    await db.execute(
        "INSERT INTO users (name, email, password_hash) VALUES (:name, :email, :hash)",
        { name: body.name, email: body.email, hash: passwordHash }
    );

    const user = await db.fetchOne("SELECT id, name, email FROM users WHERE id = last_insert_rowid()");

    return res.status(201).json({ message: "Registration successful", user });
});
```

---

## 4. The Login Flow

```typescript
import { Router, Auth, Database } from "tina4-nodejs";

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
        "SELECT id, name, email, password_hash FROM users WHERE email = :email",
        { email: body.email }
    );

    if (user === null) {
        return res.status(401).json({ error: "Invalid email or password" });
    }

    if (!(await Auth.checkPassword(body.password, user.password_hash))) {
        return res.status(401).json({ error: "Invalid email or password" });
    }

    const token = Auth.getToken({
        user_id: user.id,
        email: user.email,
        name: user.name
    });

    return res.json({
        message: "Login successful",
        token,
        user: { id: user.id, name: user.name, email: user.email }
    });
});
```

---

## 5. Protecting Routes

### Auth Middleware

```typescript
import { Auth } from "tina4-nodejs";

async function authMiddleware(req, res, next) {
    const authHeader = req.headers["authorization"] ?? "";

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({ error: "Authorization header required" });
    }

    const token = authHeader.substring(7);

    const payload = Auth.validToken(token);
    if (payload === null) {
        return res.status(401).json({ error: "Invalid or expired token" });
    }

    req.user = payload;

    return next(req, res);
}
```

### Applying Middleware

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/profile", async (req, res) => {
    return res.json({
        user_id: req.user.user_id,
        email: req.user.email,
        name: req.user.name
    });
}, "authMiddleware");
```

### Role-Based Authorization

```typescript
function requireRole(role: string) {
    return async function (req, res, next) {
        const authHeader = req.headers["authorization"] ?? "";
        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            return res.status(401).json({ error: "Authorization required" });
        }

        const token = authHeader.substring(7);
        const payload = Auth.validToken(token);
        if (payload === null) {
            return res.status(401).json({ error: "Invalid or expired token" });
        }

        if ((payload.role ?? "") !== role) {
            return res.status(403).json({ error: `Forbidden. Required role: ${role}` });
        }

        req.user = payload;
        return next(req, res);
    };
}
```

---

## 6. CSRF Protection

For form-based applications, include a CSRF token in every form:

```html
<form method="POST" action="/profile/update">
    {{ form_token() }}
    <input type="text" name="name" value="{{ user.name }}">
    <button type="submit">Update Profile</button>
</form>
```

Validate in the handler:

```typescript
Router.post("/profile/update", async (req, res) => {
    if (!Auth.validateFormToken(req.body._token ?? "")) {
        return res.status(403).json({ error: "Invalid form token" });
    }

    return res.redirect("/profile");
});
```

---

## 7. Exercise: Build Login, Register, and Profile

Build a complete authentication system with registration, login, profile viewing, and password changing.

### Requirements

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/register` | @noauth | Create an account |
| `POST` | `/api/login` | @noauth | Login, return JWT |
| `GET` | `/api/profile` | secured | Get current user profile |
| `PUT` | `/api/profile` | secured | Update name and email |
| `PUT` | `/api/profile/password` | secured | Change password |

---

## 8. Solution

Create `src/routes/auth.ts`:

```typescript
import { Router, Auth, Database } from "tina4-nodejs";

async function authMiddleware(req, res, next) {
    const authHeader = req.headers["authorization"] ?? "";
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({ error: "Authorization required. Send: Authorization: Bearer <token>" });
    }
    const token = authHeader.substring(7);
    const payload = Auth.validToken(token);
    if (payload === null) {
        return res.status(401).json({ error: "Invalid or expired token. Please login again." });
    }
    req.user = payload;
    return next(req, res);
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

    const token = Auth.getToken({
        user_id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
    });

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
}, "authMiddleware");

Router.put("/api/profile", async (req, res) => {
    const db = Database.getConnection();
    const body = req.body;
    const userId = req.user.user_id;

    const current = await db.fetchOne("SELECT * FROM users WHERE id = :id", { id: userId });

    await db.execute(
        "UPDATE users SET name = :name, email = :email WHERE id = :id",
        { name: body.name ?? current.name, email: body.email ?? current.email, id: userId }
    );

    const updated = await db.fetchOne("SELECT id, name, email, role, created_at FROM users WHERE id = :id", { id: userId });

    return res.json({ message: "Profile updated", user: updated });
}, "authMiddleware");

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
}, "authMiddleware");
```

---

## 9. Gotchas

### 1. Token Expiry Confusion

**Problem:** Tokens that worked yesterday now return 401.

**Fix:** The default lifetime is 60 minutes (`TINA4_TOKEN_EXPIRES_IN=60`). Issue new tokens at login. Use refresh tokens for long-lived sessions.

### 2. Secret Key Management

**Problem:** Tokens generated on one server are invalid on another.

**Fix:** Set `SECRET` explicitly in `.env` and use the same value across all servers.

### 3. CORS with Authentication

**Problem:** Frontend requests with the `Authorization` header fail with a CORS error.

**Fix:** Tina4 handles preflight requests automatically. Make sure `CORS_ORIGINS` is set correctly.

### 4. Storing Tokens in localStorage

**Problem:** Token stolen via XSS.

**Fix:** Store tokens in `httpOnly` cookies when possible.

### 5. Forgetting @noauth on Login

**Problem:** Login endpoint returns 401.

**Fix:** Add `@noauth` to login and register routes.

### 6. Password Hash Column Too Short

**Problem:** Registration fails because the hash is truncated.

**Fix:** PBKDF2 hashes can be long. Use `TEXT` for the password hash column, not `VARCHAR(50)`.

### 7. Token in URL Query Parameters

**Problem:** Tokens in URLs leak through browser history and server logs.

**Fix:** Always send tokens in the `Authorization` header, never in the URL.
