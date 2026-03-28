# Chapter 9: Sessions & Cookies

## 1. State in a Stateless World

Your e-commerce site needs a shopping cart that survives page reloads, remembers the user's language, and flashes success messages after form submissions. HTTP has no memory. Every request is independent. Sessions and cookies give the server a way to remember who is asking and what they have been doing.

Chapter 7 introduced sessions for authentication. This chapter goes deeper: session backends, flash messages, cookies, remember-me tokens, and security configuration.

---

## 2. How Sessions Work

Sessions are auto-started. Every route handler receives `$request->session` ready to use. No manual setup required.

First visit. No session cookie. Tina4 generates a unique session ID -- a long random string. Stores it in a cookie named `tina4_session` (`HttpOnly`, `SameSite=Lax`). Creates server-side storage keyed by that ID. Every subsequent request carries the cookie. Tina4 looks up the data. Makes it available through `$request->session`.

The flow:

1. Browser sends first request (no session cookie)
2. Tina4 generates session ID: `abc123def456`
3. Tina4 sets cookie: `tina4_session=abc123def456`
4. Tina4 creates empty session storage for `abc123def456`
5. Browser sends second request with cookie `tina4_session=abc123def456`
6. Tina4 loads session data for `abc123def456`
7. Your handler reads and writes `$request->session`
8. Request ends. Tina4 saves updated session data.

The data lives server-side. The browser holds the session ID. Nothing else.

---

## 3. The Session API

Access session data through `$request->session`. It is available in every route handler with zero configuration.

### Full API Reference

| Method | Description |
|--------|-------------|
| `$request->session->set(key, value)` | Store a value |
| `$request->session->get(key, default)` | Retrieve a value (with optional default) |
| `$request->session->delete(key)` | Remove a key |
| `$request->session->has(key)` | Check if a key exists |
| `$request->session->clear()` | Remove all session data |
| `$request->session->destroy()` | Destroy the session entirely |
| `$request->session->save()` | Persist session data (auto-called after response) |
| `$request->session->regenerate()` | Generate a new session ID, preserve data |
| `$request->session->flash(key, value)` | Set flash data (one-time read) |
| `$request->session->getFlash(key)` | Read and remove flash data |
| `$request->session->all()` | Get all session data as an array |

---

## 4. File Sessions (Default)

No configuration needed. Sessions stored in files. Works out of the box.

```php
<?php
use Tina4\Router;

Router::get("/visit-counter", function ($request, $response) {
    $count = ($request->session->get("visit_count", 0)) + 1;
    $request->session->set("visit_count", $count);

    return $response->json([
        "visit_count" => $count,
        "message" => "You have visited this page " . $count . " time" . ($count === 1 ? "" : "s")
    ]);
});
```

```bash
curl http://localhost:7146/visit-counter -c cookies.txt -b cookies.txt
```

```json
{"visit_count":1,"message":"You have visited this page 1 time"}
```

```bash
curl http://localhost:7146/visit-counter -c cookies.txt -b cookies.txt
```

```json
{"visit_count":2,"message":"You have visited this page 2 times"}
```

```bash
curl http://localhost:7146/visit-counter -c cookies.txt -b cookies.txt
```

```json
{"visit_count":3,"message":"You have visited this page 3 times"}
```

The `-c` flag saves cookies. The `-b` flag sends them back. This simulates browser behavior.

File sessions work for single-server deployments. Simplest option. No extra software.

---

## 5. Redis Sessions

Multiple servers behind a load balancer need a shared session store. Redis is the standard choice.

```env
TINA4_SESSION_BACKEND=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
TINA4_SESSION_PASSWORD=your-redis-password
```

That is the only change. Your code stays identical. `$request->session` works the same whether backed by files, Redis, MongoDB, or Valkey. The storage backend is invisible to your handlers.

### Why Redis

- Sessions shared across all server instances
- Sub-millisecond reads and writes
- Built-in key expiry (automatic cleanup)
- No disk I/O

### Redis with a Prefix

Sharing a Redis instance with other applications:

```env
TINA4_SESSION_BACKEND=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
TINA4_SESSION_PREFIX=myapp:sess:
```

---

## 6. MongoDB Sessions

Already running MongoDB:

```env
TINA4_SESSION_BACKEND=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017
TINA4_SESSION_DATABASE=myapp
TINA4_SESSION_COLLECTION=sessions
```

TTL indexes handle expired session cleanup.

---

## 7. Valkey Sessions

Valkey is the open-source Redis fork. Wire-compatible. Same client library:

```env
TINA4_SESSION_BACKEND=valkey
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
```

---

## 8. Database Sessions

```env
TINA4_SESSION_BACKEND=database
```

Stores sessions in the `tina4_session` table using your existing database connection (`DATABASE_URL`). The table is auto-created on first use. Works with all 5 database engines (SQLite, PostgreSQL, MySQL, MSSQL, Firebird).

---

## 9. Reading and Writing Session Data

A key-value store. Read and write through `$request->session`:

```php
<?php
use Tina4\Router;

// Write
Router::post("/api/preferences", function ($request, $response) {
    $body = $request->body;

    $request->session->set("language", $body["language"] ?? "en");
    $request->session->set("theme", $body["theme"] ?? "light");
    $request->session->set("items_per_page", (int) ($body["items_per_page"] ?? 20));

    return $response->json([
        "message" => "Preferences saved",
        "preferences" => [
            "language" => $request->session->get("language"),
            "theme" => $request->session->get("theme"),
            "items_per_page" => $request->session->get("items_per_page")
        ]
    ]);
});

// Read
Router::get("/api/preferences", function ($request, $response) {
    return $response->json([
        "language" => $request->session->get("language", "en"),
        "theme" => $request->session->get("theme", "light"),
        "items_per_page" => $request->session->get("items_per_page", 20)
    ]);
});

// Delete a key
Router::delete("/api/preferences/{key}", function ($request, $response) {
    $key = $request->params["key"];
    $request->session->delete($key);

    return $response->json(["message" => "Preference '" . $key . "' removed"]);
});

// Clear everything
Router::post("/api/session/clear", function ($request, $response) {
    $request->session->clear();

    return $response->json(["message" => "Session cleared"]);
});
```

### Storing Complex Data

Sessions hold arrays and nested structures:

```php
Router::post("/api/cart/add", function ($request, $response) {
    $body = $request->body;

    $cart = $request->session->get("cart", []);

    $cart[] = [
        "product_id" => (int) $body["product_id"],
        "name" => $body["name"],
        "price" => (float) $body["price"],
        "quantity" => (int) ($body["quantity"] ?? 1),
        "added_at" => date("c")
    ];

    $request->session->set("cart", $cart);

    $total = array_sum(array_map(
        fn($item) => $item["price"] * $item["quantity"],
        $cart
    ));

    return $response->json([
        "message" => "Added to cart",
        "cart_items" => count($cart),
        "cart_total" => $total
    ]);
});
```

---

## 10. Flash Messages

Session data that lives for one request. Set it before redirecting. Read it on the next request. Gone after that.

The pattern: submit a form, redirect to a success page, show a message that disappears on refresh.

### Setting a Flash Message

```php
<?php
use Tina4\Router;

Router::post("/profile/update", function ($request, $response) {
    $body = $request->body;

    // Update the profile...

    $request->session->flash("message", "Profile updated successfully");
    $request->session->flash("message_type", "success");

    return $response->redirect("/profile");
});
```

### Reading and Clearing

```php
Router::get("/profile", function ($request, $response) {
    $flash_message = $request->session->getFlash("message");
    $flash_type = $request->session->getFlash("message_type") ?? "info";

    return $response->render("profile.html", [
        "user" => ["name" => "Alice", "email" => "alice@example.com"],
        "flash_message" => $flash_message,
        "flash_type" => $flash_type
    ]);
});
```

The `getFlash()` method reads the value and removes it in one step. The next request will not see it.

### In Templates

```html
{% extends "base.html" %}

{% block content %}
    {% if flash_message %}
        <div class="alert alert-{{ flash_type }}">
            {{ flash_message }}
        </div>
    {% endif %}

    <h1>Profile</h1>
    <p>Name: {{ user.name }}</p>
    <p>Email: {{ user.email }}</p>
{% endblock %}
```

The alert appears once. Refresh the page. Gone.

---

## 11. Setting and Reading Cookies

Cookies live in the browser. Unlike sessions, the data is client-side. Use cookies for non-sensitive preferences that should survive session expiry.

### Setting a Cookie

```php
<?php
use Tina4\Router;

Router::post("/api/set-language", function ($request, $response) {
    $language = $request->body["language"] ?? "en";

    $response->setCookie("language", $language, [
        "expires" => time() + (365 * 24 * 60 * 60),  // 1 year
        "path" => "/",
        "httpOnly" => false,  // JavaScript can read it
        "secure" => false,    // true in production
        "sameSite" => "Lax"
    ]);

    return $response->json(["message" => "Language set to " . $language]);
});
```

### Reading a Cookie

```php
Router::get("/api/get-language", function ($request, $response) {
    $language = $request->cookies["language"] ?? "en";

    return $response->json(["language" => $language]);
});
```

### Deleting a Cookie

Set expiry in the past:

```php
Router::post("/api/clear-language", function ($request, $response) {
    $response->setCookie("language", "", [
        "expires" => time() - 3600,
        "path" => "/"
    ]);

    return $response->json(["message" => "Language cookie cleared"]);
});
```

### When to Use Cookies vs Sessions

| Use Cookies For | Use Sessions For |
|-----------------|------------------|
| Language preference | Shopping cart contents |
| Theme (light/dark) | Authentication state |
| "Remember this device" flag | Flash messages |
| Analytics consent | Form wizard progress |
| Non-sensitive, long-lived data | Sensitive, short-lived data |

---

## 12. Remember Me Functionality

A long-lived cookie re-authenticates users after their session expires.

```php
<?php
use Tina4\Router;
use Tina4\Auth;
use Tina4\Database;

/**
 * @noauth
 */
Router::post("/login", function ($request, $response) {
    $body = $request->body;
    $db = Database::getConnection();

    $user = $db->fetchOne(
        "SELECT id, name, email, password_hash FROM users WHERE email = :email",
        ["email" => $body["email"]]
    );

    if ($user === null || !Auth::checkPassword($body["password"], $user["password_hash"])) {
        return $response->json(["error" => "Invalid email or password"], 401);
    }

    $request->session->set("user_id", $user["id"]);
    $request->session->set("user_name", $user["name"]);

    if (!empty($body["remember_me"])) {
        $rememberToken = bin2hex(random_bytes(32));

        // Store hashed token in database
        $db->execute(
            "UPDATE users SET remember_token = :token WHERE id = :id",
            ["token" => hash("sha256", $rememberToken), "id" => $user["id"]]
        );

        // Set long-lived cookie with unhashed token
        $response->setCookie("remember_me", $rememberToken, [
            "expires" => time() + (30 * 24 * 60 * 60),  // 30 days
            "path" => "/",
            "httpOnly" => true,
            "secure" => true,
            "sameSite" => "Lax"
        ]);
    }

    return $response->json([
        "message" => "Login successful",
        "user" => ["id" => $user["id"], "name" => $user["name"]]
    ]);
});
```

The middleware that checks the cookie:

```php
<?php
use Tina4\Database;

function rememberMeMiddleware($request, $response, $next) {
    if ($request->session->has("user_id")) {
        return $next($request, $response);
    }

    $rememberToken = $request->cookies["remember_me"] ?? "";

    if (empty($rememberToken)) {
        return $next($request, $response);
    }

    $db = Database::getConnection();
    $hashedToken = hash("sha256", $rememberToken);

    $user = $db->fetchOne(
        "SELECT id, name, email FROM users WHERE remember_token = :token",
        ["token" => $hashedToken]
    );

    if ($user !== null) {
        $request->session->set("user_id", $user["id"]);
        $request->session->set("user_name", $user["name"]);
    }

    return $next($request, $response);
}
```

The flow:

1. User logs in with "remember me" checked
2. Server stores a hashed token in the database. Sets the raw token in a cookie.
3. Session expires.
4. User returns. Session empty. Cookie still present.
5. Middleware finds the cookie. Looks up the hashed token. Restores the session.
6. User is logged in again. No credentials entered.

The database holds the hash. The cookie holds the raw token. If the database is breached, the attacker gets hashes. They cannot forge the cookie.

---

## 13. Session Security

### Configuration Options

```env
TINA4_SESSION_TTL=3600            # Expires after 1 hour of inactivity
TINA4_SESSION_SECURE=true         # HTTPS only
TINA4_SESSION_HTTPONLY=true       # JavaScript cannot access the cookie (default)
TINA4_SESSION_SAMESITE=Lax        # CSRF protection (default)
```

### httpOnly

`TINA4_SESSION_HTTPONLY=true` (default) makes the session cookie invisible to JavaScript. XSS attacks cannot steal the session ID. Almost never a reason to set this to `false`.

### secure

`TINA4_SESSION_SECURE=true` restricts the cookie to HTTPS connections. Set to `true` in production. During development with `http://localhost`, set to `false` or the browser will not send the cookie.

### sameSite

Controls cross-site cookie behavior:

| Value | Behavior |
|-------|----------|
| `Strict` | Never sent with cross-site requests. Safest. Breaks some flows (clicking links from email). |
| `Lax` | Sent with top-level navigations (clicking links) but not cross-site API calls. Good default. |
| `None` | Always sent. Requires `secure=true`. Only for cross-site cookie access. |

### Session Regeneration

After login, regenerate the session ID to prevent session fixation attacks:

```php
Router::post("/login", function ($request, $response) {
    // Validate credentials...

    $request->session->regenerate();

    $request->session->set("user_id", $user["id"]);

    return $response->redirect("/dashboard");
});
```

Session fixation: attacker sets a known session ID on the victim's browser before login. After login, the attacker uses that same ID. Regeneration invalidates the old ID.

### Destroy a Session

To completely destroy a session (not just clear its data):

```php
Router::post("/logout", function ($request, $response) {
    $request->session->destroy();
    return $response->redirect("/login");
});
```

---

## 14. Exercise: Build a Shopping Cart with Session Storage

A cart stored entirely in session data. No database.

### Requirements

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/cart/add` | Add item. Body: `{"product_id": 1, "name": "Widget", "price": 9.99, "quantity": 2}` |
| `GET` | `/api/cart` | View cart. Items, quantities, subtotals, total. |
| `PUT` | `/api/cart/{product_id:int}` | Update quantity. Body: `{"quantity": 3}`. Remove if 0. |
| `DELETE` | `/api/cart/{product_id:int}` | Remove item. |
| `DELETE` | `/api/cart` | Clear cart. |

### Business Rules

1. Adding an existing product increments quantity instead of duplicating
2. Total calculated dynamically
3. Full cart state returned after every operation

### Test with:

```bash
# Add first item
curl -X POST http://localhost:7146/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "name": "Wireless Keyboard", "price": 79.99, "quantity": 1}' \
  -c cookies.txt -b cookies.txt

# Add second item
curl -X POST http://localhost:7146/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 2, "name": "USB-C Hub", "price": 49.99, "quantity": 2}' \
  -c cookies.txt -b cookies.txt

# Add more of item 1 (increments, no duplicate)
curl -X POST http://localhost:7146/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "name": "Wireless Keyboard", "price": 79.99, "quantity": 1}' \
  -c cookies.txt -b cookies.txt

# View cart
curl http://localhost:7146/api/cart -b cookies.txt

# Update quantity
curl -X PUT http://localhost:7146/api/cart/2 \
  -H "Content-Type: application/json" \
  -d '{"quantity": 5}' \
  -c cookies.txt -b cookies.txt

# Remove item
curl -X DELETE http://localhost:7146/api/cart/1 -b cookies.txt -c cookies.txt

# Clear cart
curl -X DELETE http://localhost:7146/api/cart -b cookies.txt -c cookies.txt
```

---

## 15. Solution

Create `src/routes/cart.php`:

```php
<?php
use Tina4\Router;

function getCart($session) {
    return $session->get("cart", []);
}

function cartResponse($cart) {
    $total = 0;
    $itemCount = 0;
    $items = [];

    foreach ($cart as $item) {
        $subtotal = $item["price"] * $item["quantity"];
        $total += $subtotal;
        $itemCount += $item["quantity"];
        $items[] = array_merge($item, ["subtotal" => $subtotal]);
    }

    return [
        "items" => $items,
        "item_count" => $itemCount,
        "unique_items" => count($cart),
        "total" => round($total, 2)
    ];
}

Router::post("/api/cart/add", function ($request, $response) {
    $body = $request->body;

    if (empty($body["product_id"]) || empty($body["name"]) || !isset($body["price"])) {
        return $response->json(["error" => "product_id, name, and price are required"], 400);
    }

    $cart = getCart($request->session);
    $productId = (int) $body["product_id"];
    $quantity = (int) ($body["quantity"] ?? 1);
    $found = false;

    foreach ($cart as $index => $item) {
        if ($item["product_id"] === $productId) {
            $cart[$index]["quantity"] += $quantity;
            $found = true;
            break;
        }
    }

    if (!$found) {
        $cart[] = [
            "product_id" => $productId,
            "name" => $body["name"],
            "price" => (float) $body["price"],
            "quantity" => $quantity
        ];
    }

    $request->session->set("cart", $cart);

    return $response->json(cartResponse($cart));
});

Router::get("/api/cart", function ($request, $response) {
    $cart = getCart($request->session);
    return $response->json(cartResponse($cart));
});

Router::put("/api/cart/{product_id:int}", function ($request, $response) {
    $productId = $request->params["product_id"];
    $quantity = (int) ($request->body["quantity"] ?? 0);
    $cart = getCart($request->session);
    $found = false;

    foreach ($cart as $index => $item) {
        if ($item["product_id"] === $productId) {
            if ($quantity <= 0) {
                array_splice($cart, $index, 1);
            } else {
                $cart[$index]["quantity"] = $quantity;
            }
            $found = true;
            break;
        }
    }

    if (!$found) {
        return $response->json(["error" => "Product not in cart"], 404);
    }

    $request->session->set("cart", $cart);

    return $response->json(cartResponse($cart));
});

Router::delete("/api/cart/{product_id:int}", function ($request, $response) {
    $productId = $request->params["product_id"];
    $cart = getCart($request->session);
    $found = false;

    foreach ($cart as $index => $item) {
        if ($item["product_id"] === $productId) {
            array_splice($cart, $index, 1);
            $found = true;
            break;
        }
    }

    if (!$found) {
        return $response->json(["error" => "Product not in cart"], 404);
    }

    $request->session->set("cart", $cart);

    return $response->json(cartResponse($cart));
});

Router::delete("/api/cart", function ($request, $response) {
    $request->session->set("cart", []);

    return $response->json(cartResponse([]));
});
```

**After adding two items and adding more of item 1:**

```json
{
  "items": [
    {"product_id": 1, "name": "Wireless Keyboard", "price": 79.99, "quantity": 2, "subtotal": 159.98},
    {"product_id": 2, "name": "USB-C Hub", "price": 49.99, "quantity": 2, "subtotal": 99.98}
  ],
  "item_count": 4,
  "unique_items": 2,
  "total": 259.96
}
```

Keyboard has `quantity: 2` (1 + 1). Not two separate entries.

**After clearing:**

```json
{"items":[],"item_count":0,"unique_items":0,"total":0}
```

---

## 16. Gotchas

### 1. Sessions Do Not Work with curl Without Cookie Flags

**Problem:** Every curl request sees an empty session.

**Cause:** curl does not save or send cookies by default.

**Fix:** Use `-c cookies.txt -b cookies.txt`. Browsers handle this automatically.

### 2. Session Data Disappears After Server Restart

**Problem:** All session data gone.

**Cause:** File sessions in the temp directory. Cleared on restart.

**Fix:** Set `TINA4_SESSION_PATH` to a persistent directory. For production, use Redis or Valkey.

### 3. Session Cookie Not Sent in Production

**Problem:** Sessions work locally. Fail in production.

**Cause:** `TINA4_SESSION_SECURE=true` but the app sees HTTP (behind a proxy that terminates SSL).

**Fix:** Ensure the reverse proxy sets `X-Forwarded-Proto: https`. Or verify the connection is HTTPS end-to-end.

### 4. Flash Messages Show Twice

**Problem:** Flash message appears. Appears again on the next page.

**Cause:** Read it but did not clear it.

**Fix:** Use `$request->session->getFlash("message")` instead of `$request->session->get()`. The `getFlash()` method reads and deletes in one step.

### 5. Large Session Data Causes Slow Requests

**Problem:** Pages load slowly. Performance degrades over time.

**Cause:** Storing too much in the session. Entire result sets. File contents. Large arrays. Session data serializes and deserializes on every request.

**Fix:** Keep sessions small. Store IDs and references. Not entire objects.

### 6. Remember Me Token Not Invalidated on Password Change

**Problem:** After password change, other devices still logged in.

**Cause:** Remember token not cleared.

**Fix:** Clear the token on password change: `$db->execute("UPDATE users SET remember_token = NULL WHERE id = :id", ["id" => $userId])`. Forces all devices to re-authenticate.

### 7. Session Fixation

**Problem:** Attacker hijacks a session by setting a known ID before login.

**Cause:** Session ID not regenerated after authentication.

**Fix:** Call `$request->session->regenerate()` after login. New ID. Old one useless.
