# Plan: Auth & CSRF Parity — Secure by Default

**Date:** 2026-03-25
**Status:** Awaiting approval
**Impact:** Breaking change for PHP, Ruby, Node.js (Python already correct)

---

## 1. The Problem

Python enforces auth on POST/PUT/PATCH/DELETE by default. PHP, Ruby, and Node.js don't — all routes are public unless `.secure()` is called. This is inconsistent and insecure.

Additionally, `formToken` CSRF protection exists (token generation in Frond templates) but is never validated. No middleware checks it.

v2 PHP allowed `formToken` in query params (`?formToken=xxx`) — this leaks tokens via referrer headers, server logs, and browser history. Must be blocked in v3.

## 2. The Standard (Python's Model)

```
GET / HEAD / OPTIONS    → public by default
POST / PUT / PATCH / DELETE → auth required by default

@noauth()  → make a write route public (login, register, webhook)
@secured() → require auth on a GET route (profile, dashboard)
```

## 3. Changes Required

### 3.1 PHP Router — Secure by Default

**File:** `Tina4/Router.php`

- In `dispatch()`, before calling the route handler:
  - If method is POST/PUT/PATCH/DELETE AND route is NOT marked `noAuth`:
    - Check `Authorization: Bearer` header
    - Validate token with `Auth::validToken()`
    - If invalid → return 401
  - If route IS marked `noAuth` → skip auth check
- Add `noAuth()` chainable method on route (sets `'noAuth' => true`)
- Add `@noauth` docblock annotation parsing in Swagger/route registration
- Add `@secured` docblock annotation for GET routes

### 3.2 Ruby Router — Secure by Default

**File:** `lib/tina4/rack_app.rb`

- In request handling, before calling the route handler:
  - If method is POST/PUT/PATCH/DELETE AND `route.auth_required != false`:
    - Check `Authorization: Bearer` header
    - Validate with `Tina4::Auth.valid_token()`
    - If invalid → return 401
- Add `no_auth` chainable method on Route (sets `auth_required = false`)
- Default: write routes have `auth_required = true` unless `no_auth` called

### 3.3 Node.js Router — Secure by Default

**File:** `packages/core/src/server.ts`

- In request handling, before calling the route handler:
  - If method is POST/PUT/PATCH/DELETE AND route `noAuth` is not true:
    - Check `Authorization: Bearer` header
    - Validate with `validToken()`
    - If invalid → return 401
- Add `noAuth()` chainable method on RouteRef (sets `noAuth: true`)
- Default: write routes have `secure: true` unless `noAuth()` called

### 3.4 CSRF Middleware — All 4 Frameworks

**New class:** `CsrfMiddleware` (before_* pattern)

Behaviour:
- **Off by default** — opt-in via `TINA4_CSRF=true` or `Router.use(CsrfMiddleware)`
- Skips GET / HEAD / OPTIONS
- Skips routes marked `@noauth()`
- Skips requests with valid `Authorization: Bearer` header (API clients)
- Checks for token in (priority order):
  1. `request.body["formToken"]` — HTML form POST
  2. `request.headers["X-Form-Token"]` — AJAX/fetch
- Validates token with `Auth.valid_token()` (same JWT secret)
- Returns 403 with `response.error("CSRF_INVALID", "Invalid or missing form token", 403)`
- **NEVER reads from query params** — tokens in URLs are a security risk

### 3.5 formToken Query Param Blocking

All 4 frameworks must explicitly reject formToken in query params:
- If `request.query["formToken"]` exists → log a warning
- Never use it for validation
- Document: "formToken must be sent via POST body or X-Form-Token header, never in URL"

## 4. .env Configuration

```env
# Auth
SECRET=your-secret-key                    # JWT signing key
TINA4_TOKEN_EXPIRES_IN=3600              # Token lifetime in seconds

# CSRF (opt-in)
TINA4_CSRF=true                          # Enable CSRF middleware
TINA4_CSRF_HEADER=X-Form-Token           # Header name for AJAX tokens
TINA4_CSRF_FIELD=formToken               # Form field name
```

## 5. Migration Guide (v2 → v3)

### What Changed

| v2 Behaviour | v3 Behaviour |
|-------------|-------------|
| All routes public by default | GET public, POST/PUT/PATCH/DELETE require auth |
| `formToken` accepted in query params | Query params BLOCKED — body or header only |
| No CSRF validation | Opt-in CSRF middleware validates formToken |
| `@secure` annotation required | Write routes secure by default |

### How to Upgrade

**Step 1: Add `@noauth()` to public write routes**

These routes need `@noauth()` because they're public POST endpoints:
```
POST /api/login         → @noauth()
POST /api/register      → @noauth()
POST /api/forgot-password → @noauth()
POST /api/webhook       → @noauth()
POST /api/contact-form  → @noauth()
```

**Step 2: Remove `@secure` from write routes**

Write routes are now secure by default. Remove explicit `@secure` / `.secure()`:
```
# Before (v2)
Router::post("/api/users", fn() => ...)->secure();

# After (v3) — secure by default, no annotation needed
Router::post("/api/users", fn() => ...);
```

**Step 3: Move formToken from query params to body**

```html
<!-- WRONG (v2 — leaked in URL) -->
<a href="/api/delete-user?formToken={{ token }}">Delete</a>

<!-- RIGHT (v3 — in form body) -->
<form method="POST" action="/api/delete-user">
    {{ form_token() }}
    <button type="submit">Delete</button>
</form>
```

**Step 4: Update AJAX calls**

```javascript
// WRONG (v2)
fetch("/api/users?formToken=" + token, { method: "POST" });

// RIGHT (v3)
fetch("/api/users", {
    method: "POST",
    headers: { "X-Form-Token": token },
    body: JSON.stringify(data)
});
```

**Step 5: Enable CSRF (optional)**

Add to `.env`:
```
TINA4_CSRF=true
```

## 6. Implementation Order

1. PHP: `->noAuth()` + `@noauth` docblock + default auth on writes
2. Ruby: `.no_auth` + default auth on writes
3. Node.js: `.noAuth()` + default auth on writes
4. CSRF middleware: all 4 frameworks
5. formToken query param warning: all 4 frameworks
6. Update books: ch07 (auth), ch08 (middleware)
7. Update MIGRATE.md in Python and PHP repos
8. Tests: auth enforcement, noauth bypass, CSRF validation
9. Release 3.9.x

## 7. Files Affected

### PHP
- `Tina4/Router.php` — noAuth(), default auth, @noauth parsing
- `Tina4/Middleware/CsrfMiddleware.php` — NEW
- `Tina4/Swagger.php` — parse @noauth annotation

### Ruby
- `lib/tina4/router.rb` — no_auth, default auth_required
- `lib/tina4/rack_app.rb` — auth enforcement
- `lib/tina4/middleware.rb` — CsrfMiddleware class

### Node.js
- `packages/core/src/router.ts` — noAuth(), default secure
- `packages/core/src/server.ts` — auth enforcement
- `packages/core/src/middleware.ts` — CsrfMiddleware class

### Python (verify only)
- `tina4_python/core/middleware.py` — add CsrfMiddleware
- Verify existing auth enforcement is correct

### Books
- All 4 ch07 (authentication)
- All 4 ch08 (middleware)
- PHP MIGRATE.md
- Python MIGRATE.md

### Tests
- Auth enforcement on POST without token → 401
- Auth enforcement on POST with valid token → 200
- @noauth() bypasses auth → 200
- @secured() on GET requires auth → 401
- CSRF with valid formToken in body → 200
- CSRF with valid X-Form-Token header → 200
- CSRF with formToken in query param → 403 (rejected)
- CSRF with missing token → 403
- CSRF with Bearer auth → skips CSRF check
- CSRF disabled by default → no check
