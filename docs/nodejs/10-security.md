# Chapter 10: Security

Every route you write is a door. Chapter 7 gave you locks. Chapter 8 gave you guards. Chapter 9 gave you session keys. This chapter ties them together into a defence that works without thinking about it.

Tina4 ships secure by default. POST routes require authentication. CSRF tokens protect forms. Security headers harden every response. The framework does the boring security work so you focus on building features. But you need to understand what it does — and why — so you don't accidentally undo it.

---

## 1. Secure-by-Default Routing

Every POST, PUT, PATCH, and DELETE route requires a valid `Authorization: Bearer` token. No configuration needed. No export to remember. The framework enforces this before your handler runs.

```typescript
// src/routes/api/orders/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    // This handler ONLY runs if the request carries a valid Bearer token.
    // Without one, the framework returns 401 before your code executes.
    return res.status(201).json({ created: true });
}
```

Test it without a token:

```bash
curl -X POST http://localhost:7148/api/orders \
  -H "Content-Type: application/json" \
  -d '{"product": "widget"}'
# 401 Unauthorized
```

Test it with a valid token:

```bash
curl -X POST http://localhost:7148/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -d '{"product": "widget"}'
# 201 Created
```

GET routes are public by default. Anyone can read. Writing requires proof of identity.

### Making a Write Route Public

Some endpoints need to accept unauthenticated writes — webhooks, registration forms, public contact forms. Export `meta` with `noAuth: true`:

```typescript
// src/routes/api/webhooks/stripe/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    // No token required. Stripe can POST here freely.
    return res.json({ received: true });
}
```

### Protecting a GET Route

Admin dashboards, user profiles, account settings — some pages need protection even though they only read data. Export `meta` with `secured: true`:

```typescript
// src/routes/api/admin/users/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { secured: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    // Requires a valid Bearer token, even though it's a GET.
    return res.json({ users: [] });
}
```

### The Rule

| Method | Default | Override |
|--------|---------|----------|
| GET, HEAD, OPTIONS | Public | `{ secured: true }` to protect |
| POST, PUT, PATCH, DELETE | Auth required | `{ noAuth: true }` to open |

One export. One rule. No surprises.

---

## 2. CSRF Protection

Cross-Site Request Forgery tricks a user's browser into submitting a form to your server. The browser sends cookies automatically — including session cookies. Without CSRF protection, an attacker's page can submit forms as your logged-in user.

Tina4 blocks this with form tokens.

### How It Works

1. Your template renders a hidden token using `{{ form_token() }}`.
2. The browser submits the token with the form data.
3. The `CsrfMiddleware` validates the token before the route handler runs.
4. Invalid or missing tokens receive a `403 Forbidden` response.

### The Template

```twig
<form method="POST" action="/api/profile">
    {{ form_token() }}
    <input type="text" name="name" placeholder="Your name">
    <button type="submit">Save</button>
</form>
```

The `{{ form_token() }}` call generates a hidden input field containing a signed JWT. The token is bound to the current session — a token from one session cannot be used in another.

### The Middleware

CSRF protection is on by default. Every POST, PUT, PATCH, and DELETE request must include a valid form token. The middleware checks two places:

1. **Request body** — `req.body.formToken`
2. **Request header** — `X-Form-Token`

If the token is missing or invalid, the middleware returns 403 before your handler runs.

### AJAX Requests

For JavaScript-driven forms, send the token as a header:

```javascript
// frond.min.js handles this automatically via saveForm()
// For manual AJAX, extract the token from the hidden field:
const token = document.querySelector('input[name="formToken"]').value;

fetch("/api/profile", {
    method: "POST",
    headers: {
        "Content-Type": "application/json",
        "X-Form-Token": token
    },
    body: JSON.stringify({ name: "Alice" })
});
```

### Tokens in Query Strings — Blocked

Tokens must never appear in URLs. Query strings are logged in server access logs, browser history, and referrer headers. A token in the URL is a token anyone can steal.

Tina4 rejects any request that carries `formToken` in the query string and logs a warning:

```
CSRF token found in query string — rejected for security.
Use POST body or X-Form-Token header instead.
```

### Skipping CSRF Validation

Three scenarios skip CSRF checks automatically:

1. **GET, HEAD, OPTIONS** — Safe methods don't modify state.
2. **Routes with `noAuth: true`** — Public write endpoints don't need CSRF (they have no session to protect).
3. **Requests with a valid Bearer token** — API clients authenticate with tokens, not cookies. CSRF only matters for cookie-based sessions.

### Disabling CSRF Globally

For internal microservices behind a firewall — where no browser ever touches the API — you can disable CSRF entirely:

```env
TINA4_CSRF=false
```

Leave it enabled for anything a browser can reach. The cost is one hidden field per form. The protection is worth it.

---

## 3. Session-Bound Tokens

A form token alone prevents cross-site forgery. But what if someone steals a token from a form? Session binding stops them.

When `{{ form_token() }}` generates a token, it embeds the current session ID in the JWT payload. The CSRF middleware checks that the session ID in the token matches the session ID of the request. A token stolen from one session cannot be replayed in another.

This happens automatically. No configuration. No extra code.

### How Stolen Tokens Fail

1. Attacker visits your site, gets a form token for session `abc-123`.
2. Attacker sends that token from their own session `xyz-789`.
3. The middleware compares: `abc-123 != xyz-789` — rejected with 403.

The token is cryptographically valid. But it belongs to the wrong session. The binding catches it.

---

## 4. Security Headers

Every response from Tina4 carries security headers. The `SecurityHeadersMiddleware` injects them before the response reaches the browser. No opt-in required.

| Header | Default Value | Purpose |
|--------|---------------|---------|
| `X-Frame-Options` | `SAMEORIGIN` | Prevents clickjacking — your pages cannot be embedded in iframes on other domains. |
| `X-Content-Type-Options` | `nosniff` | Stops browsers from guessing content types. A script is a script, not HTML. |
| `Content-Security-Policy` | `default-src 'self'` | Controls which resources the browser loads. Blocks inline scripts from injected HTML. |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limits referrer data sent to external sites. Protects internal URLs from leaking. |
| `X-XSS-Protection` | `0` | Disabled. Modern CSP replaces this legacy header. Keeping it on can introduce vulnerabilities. |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disables browser APIs your app does not need. |

### HSTS — Enforcing HTTPS

Strict Transport Security tells the browser to always use HTTPS. Disabled by default (it breaks local development on HTTP). Enable it in production:

```env
TINA4_HSTS=31536000
```

This sets a one-year HSTS policy with `includeSubDomains`. Once a browser sees this header, it refuses to connect over HTTP — even if the user types `http://`.

### Customising Headers

Override any header via environment variables:

```env
TINA4_FRAME_OPTIONS=DENY
TINA4_CSP=default-src 'self'; script-src 'self' https://cdn.example.com
TINA4_REFERRER_POLICY=no-referrer
TINA4_PERMISSIONS_POLICY=camera=(), microphone=(), geolocation=(), payment=()
```

---

## 5. SameSite Cookies

Session cookies control who can send them. The `SameSite` attribute tells the browser when to include the cookie in requests.

| Value | Behaviour |
|-------|-----------|
| `Strict` | Cookie sent only on same-site requests. Even clicking a link from email to your site won't include the cookie. The user must navigate directly. |
| `Lax` | Cookie sent on same-site requests and top-level navigations (clicking a link). Not sent on cross-site AJAX or form POSTs from other domains. |
| `None` | Cookie sent on all requests, including cross-site. Requires `Secure` flag (HTTPS only). |

Tina4 defaults to `Lax`. This blocks cross-site form submissions (CSRF) while allowing normal link navigation. Users click a link to your site from an email — they stay logged in. An attacker's page submits a hidden form — the cookie is withheld.

For most applications, `Lax` is the right choice. Change it only if you understand the trade-offs.

---

## 6. Login Flow — Complete Example

Authentication, sessions, tokens, and security converge in the login flow. Here is a complete implementation.

### The Login Route

```typescript
// src/routes/api/login/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import { getToken, checkPassword } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    const email: string = req.body.email || "";
    const password: string = req.body.password || "";

    if (!email || !password) {
        return res.status(400).json({ error: "Email and password required" });
    }

    // Look up user (replace with your database query)
    const user = await db.fetchOne(
        "SELECT id, email, password_hash, role FROM users WHERE email = ?",
        [email]
    );

    if (!user) {
        return res.status(401).json({ error: "Invalid credentials" });
    }

    // Verify password
    if (!checkPassword(password, user.password_hash)) {
        return res.status(401).json({ error: "Invalid credentials" });
    }

    // Generate token with user claims
    const secret = process.env.SECRET || "tina4-default-secret";
    const token: string = getToken({
        sub: user.id,
        email: user.email,
        role: user.role,
    }, secret);

    // Store user in session
    req.session.set("user_id", user.id);
    req.session.set("email", user.email);
    req.session.set("role", user.role);

    return res.json({
        token,
        user: { id: user.id, email: user.email },
    });
}
```

The `meta.noAuth` flag opens this route to unauthenticated requests. The handler validates credentials and issues a token. The session stores the user identity for server-side lookups.

### The Login Form

```twig
{% extends "base.twig" %}
{% block content %}
<div class="container mt-5" style="max-width: 400px;">
    <h2>Login</h2>
    <form id="loginForm">
        {{ form_token() }}
        <div class="mb-3">
            <label for="email">Email</label>
            <input type="email" name="email" id="email" class="form-control"
                   placeholder="you@example.com" required>
        </div>
        <div class="mb-3">
            <label for="password">Password</label>
            <input type="password" name="password" id="password" class="form-control"
                   placeholder="Your password" required>
        </div>
        <button type="button" class="btn btn-primary w-100"
                onclick="saveForm('loginForm', '/api/login', 'loginMsg', handleLogin)">
            Sign In
        </button>
        <div id="loginMsg" class="mt-3"></div>
    </form>
</div>

<script>
function handleLogin(result) {
    if (result.token) {
        localStorage.setItem("token", result.token);
        window.location.href = "/dashboard";
    }
}
</script>
{% endblock %}
```

### Protected Pages — Checking the Session

```typescript
// src/routes/dashboard/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const userId: string | undefined = req.session.get("user_id");

    if (!userId) {
        return res.redirect("/login");
    }

    return res.render("dashboard.twig", {
        email: req.session.get("email"),
        role: req.session.get("role"),
    });
}
```

### Logout — Destroying the Session

```typescript
// src/routes/api/logout/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    req.session.destroy();
    return res.json({ logged_out: true });
}
```

---

## 7. Handling Expired Sessions

Sessions expire. Tokens expire. The user clicks a link and finds themselves staring at a broken page or a cryptic error. A good security implementation handles expiry gracefully.

### The Pattern: Redirect to Login, Then Back

When a session expires mid-use, the user should:

1. See a login page — not an error.
2. Log in again.
3. Land on the page they were trying to reach — not the home page.

```typescript
// src/routes/account/settings/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    const userId: string | undefined = req.session.get("user_id");

    if (!userId) {
        // Remember where they wanted to go
        const returnUrl: string = encodeURIComponent(req.url);
        return res.redirect(`/login?redirect=${returnUrl}`);
    }

    return res.render("settings.twig", { user_id: userId });
}
```

The login handler reads the `redirect` parameter after successful authentication:

```typescript
// src/routes/api/login/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import { getToken, checkPassword } from "tina4-nodejs";

export const meta = { noAuth: true };

export default async function (req: Tina4Request, res: Tina4Response) {
    // ... validate credentials ...

    const redirectUrl: string = req.params.redirect || "/dashboard";

    return res.json({
        token,
        redirect: redirectUrl,
    });
}
```

The login form JavaScript redirects to the saved URL:

```javascript
function handleLogin(result) {
    if (result.token) {
        localStorage.setItem("token", result.token);
        window.location.href = result.redirect || "/dashboard";
    }
}
```

### Token Refresh

Tokens expire based on `TINA4_TOKEN_LIMIT` (default: 60 minutes). The `frond.min.js` frontend library handles token refresh automatically — every response includes a `FreshToken` header with a new token. The client stores it and uses it for the next request.

For custom AJAX code, read the header yourself:

```javascript
const res = await fetch("/api/data", {
    headers: { "Authorization": "Bearer " + localStorage.getItem("token") }
});

const freshToken = res.headers.get("FreshToken");
if (freshToken) {
    localStorage.setItem("token", freshToken);
}
```

---

## 8. Rate Limiting

Brute-force login attempts. Credential stuffing. API abuse. Rate limiting stops all of them.

Tina4 includes a sliding-window rate limiter that tracks requests per IP address. It activates automatically.

```env
TINA4_RATE_LIMIT=100
TINA4_RATE_WINDOW=60
```

One hundred requests per sixty seconds per IP. Exceed the limit and the server returns `429 Too Many Requests` with headers telling the client when to retry:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 45
```

For login routes, consider a stricter limit:

```typescript
// src/routes/api/login/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";
import { getToken, checkPassword } from "tina4-nodejs";

export const meta = { noAuth: true };

// Simple in-memory rate limiter for login
const loginAttempts: Map<string, { count: number; resetAt: number }> = new Map();

export default async function (req: Tina4Request, res: Tina4Response) {
    const ip: string = req.ip;
    const now: number = Date.now();
    const windowMs: number = 60_000; // 60 seconds
    const maxAttempts: number = 5;

    // Check rate limit
    const entry = loginAttempts.get(ip);
    if (entry && now < entry.resetAt) {
        if (entry.count >= maxAttempts) {
            const retryAfter: number = Math.ceil((entry.resetAt - now) / 1000);
            return res.status(429).json({
                error: "Too many login attempts",
                retry_after: retryAfter,
            });
        }
        entry.count++;
    } else {
        loginAttempts.set(ip, { count: 1, resetAt: now + windowMs });
    }

    // ... login logic ...
}
```

---

## 9. CORS and Credentials

When your frontend runs on a different origin than your API (common in development), CORS controls whether the browser sends cookies and auth headers.

Tina4 handles CORS automatically. The relevant security settings:

```env
TINA4_CORS_ORIGINS=*
TINA4_CORS_CREDENTIALS=true
```

Two rules to remember:

1. **`TINA4_CORS_ORIGINS=*` with `TINA4_CORS_CREDENTIALS=true`** is invalid per the CORS spec. Tina4 handles this — when origin is `*`, the credentials header is not sent. But in production, list your actual origins.

2. **Cookies need `SameSite=None; Secure`** for true cross-origin requests. If your API is on `api.example.com` and your frontend is on `app.example.com`, the default `Lax` cookie works because they share the same registrable domain. Different domains need `SameSite=None`.

Production CORS:

```env
TINA4_CORS_ORIGINS=https://app.example.com,https://admin.example.com
TINA4_CORS_CREDENTIALS=true
```

---

## 10. Security Checklist

Before you deploy, verify:

- [ ] `SECRET` is set to a long, random string — not the default.
- [ ] `TINA4_DEBUG=false` in production.
- [ ] `TINA4_HSTS=31536000` if serving over HTTPS.
- [ ] `TINA4_CORS_ORIGINS` lists your actual domains — not `*`.
- [ ] `TINA4_CSRF=true` (the default) for any browser-facing application.
- [ ] Login route uses `noAuth: true` and validates credentials before issuing tokens.
- [ ] Session is regenerated after login (prevents session fixation).
- [ ] Passwords are hashed with `hashPassword()` — never stored in plain text.
- [ ] File uploads are validated and size-limited (`TINA4_MAX_UPLOAD_SIZE`).
- [ ] Rate limiting is active on login and registration routes.
- [ ] Expired sessions redirect to login with a return URL.

---

## Gotchas

### 1. "My POST route returns 401 but I didn't add auth"

**Cause:** Tina4 requires authentication on all write routes by default.

**Fix:** Export `meta` with `noAuth: true` if the endpoint should be public. Otherwise, send a valid Bearer token with the request.

### 2. "CSRF validation fails on AJAX requests"

**Cause:** The form token is not included in the request.

**Fix:** Send the token as an `X-Form-Token` header. If using `frond.min.js`, call `saveForm()` — it handles tokens automatically.

### 3. "I disabled CSRF but forms still fail"

**Cause:** The route still requires Bearer auth (separate from CSRF). CSRF and auth are independent checks.

**Fix:** Either send a Bearer token or export `meta` with `noAuth: true` on the route.

### 4. "My Content-Security-Policy blocks inline scripts"

**Cause:** The default CSP is `default-src 'self'`, which blocks inline `<script>` tags and `onclick` handlers.

**Fix:** Move scripts to external `.js` files (the right approach) or relax the CSP:

```env
TINA4_CSP=default-src 'self'; script-src 'self' 'unsafe-inline'
```

Prefer external scripts. Inline scripts are an XSS vector.

### 5. "User stays logged in after session expires"

**Cause:** The frontend stores a JWT in localStorage. The token is still valid even after the session is destroyed server-side.

**Fix:** Check the session on every page load. If the session is gone, redirect to login regardless of the token. Tokens authenticate API calls; sessions track server-side state. Both must be valid.

---

## Exercise: Secure Contact Form

Build a public contact form that:

1. Does not require login (`noAuth: true`).
2. Validates CSRF tokens (form includes `{{ form_token() }}`).
3. Rate-limits submissions to 3 per minute per IP.
4. Stores messages in the database.
5. Returns a success message.

### Solution

```typescript
// src/routes/contact/get.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export default async function (req: Tina4Request, res: Tina4Response) {
    return res.render("contact.twig", { title: "Contact Us" });
}
```

```typescript
// src/routes/api/contact/post.ts
import type { Tina4Request, Tina4Response } from "tina4-nodejs";

export const meta = { noAuth: true };

// Simple in-memory rate limiter for contact submissions
const submissions: Map<string, { count: number; resetAt: number }> = new Map();

export default async function (req: Tina4Request, res: Tina4Response) {
    // Rate limit: 3 submissions per 60 seconds per IP
    const ip: string = req.ip;
    const now: number = Date.now();
    const windowMs: number = 60_000;
    const maxSubmissions: number = 3;

    const entry = submissions.get(ip);
    if (entry && now < entry.resetAt) {
        if (entry.count >= maxSubmissions) {
            return res.status(429).json({ error: "Too many submissions. Try again later." });
        }
        entry.count++;
    } else {
        submissions.set(ip, { count: 1, resetAt: now + windowMs });
    }

    const name: string = (req.body.name || "").trim();
    const email: string = (req.body.email || "").trim();
    const message: string = (req.body.message || "").trim();

    if (!name || !email || !message) {
        return res.status(400).json({ error: "All fields are required" });
    }

    await db.insert("contact_messages", {
        name,
        email,
        message,
    });
    await db.commit();

    return res.json({ success: true, message: "Thank you for your message" });
}
```

```twig
{# src/templates/contact.twig #}
{% extends "base.twig" %}
{% block title %}Contact Us{% endblock %}
{% block content %}
<div class="container mt-5" style="max-width: 500px;">
    <h2>{{ title }}</h2>
    <form id="contactForm">
        {{ form_token() }}
        <div class="mb-3">
            <label for="name">Name</label>
            <input type="text" name="name" id="name" class="form-control"
                   placeholder="Jane Smith" required>
        </div>
        <div class="mb-3">
            <label for="email">Email</label>
            <input type="email" name="email" id="email" class="form-control"
                   placeholder="jane@example.com" required>
        </div>
        <div class="mb-3">
            <label for="message">Message</label>
            <textarea name="message" id="message" class="form-control" rows="4"
                      placeholder="How can we help?" required></textarea>
        </div>
        <button type="button" class="btn btn-primary"
                onclick="saveForm('contactForm', '/api/contact', 'contactMsg')">
            Send Message
        </button>
        <div id="contactMsg" class="mt-3"></div>
    </form>
</div>
{% endblock %}
```

The form is public. The CSRF token is present. The `noAuth: true` export opens the route. The middleware validates the token. The database stores the message. The user sees confirmation.

Five moving parts. Zero security holes. The framework handles the rest.
