# Chapter 9: Sessions & Cookies

## 1. State in a Stateless World

JWT tokens handle APIs. Traditional web applications need more. A shopping cart that persists across pages. A flash message that appears once after a redirect. A "remember me" checkbox on the login form. These features run on sessions and cookies -- server-side state tied to a browser.

Picture an e-commerce site. A customer adds three items to their cart. Navigates to a product page. Comes back to the cart. Without sessions, the cart is empty every time. Sessions give the server memory. Each browser gets its own state, preserved across requests.

Sessions are auto-started. Every route handler receives `req.session` ready to use. No manual setup. No configuration required for the default file backend.

---

## 2. Session Configuration

The default backend is file-based sessions. They work out of the box with no additional dependencies.

To change the backend, set `TINA4_SESSION_BACKEND` in `.env`:

```bash
TINA4_SESSION_BACKEND=file
```

### Available Backends

| Backend | `.env` Value | Package Required | Best For |
|---------|-------------|-----------------|---------|
| File | `file` | None | Development, single server |
| Redis | `redis` | `ioredis` | Production, multi-server |
| MongoDB | `mongodb` | `mongodb` | Production, document stores |
| Valkey | `valkey` | `iovalkey` | Production, Redis alternative |
| Database | `database` | None | Production, using existing DB |

### Redis Configuration

```bash
TINA4_SESSION_BACKEND=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
TINA4_SESSION_PASSWORD=
```

Install the Redis driver:

```bash
npm install ioredis
```

### MongoDB Configuration

```bash
TINA4_SESSION_BACKEND=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017
TINA4_SESSION_DATABASE=tina4_sessions
```

### Valkey Configuration

```bash
TINA4_SESSION_BACKEND=valkey
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
```

### Database Sessions

```bash
TINA4_SESSION_BACKEND=database
```

Stores sessions in the `tina4_session` table using your existing database connection (`DATABASE_URL`). The table is auto-created on first use. Works with all 5 database engines (SQLite, PostgreSQL, MySQL, MSSQL, Firebird).

### Session Lifetime

```bash
TINA4_SESSION_TTL=3600  # 1 hour in seconds (default)
```

### Session Cookie

The session cookie is named `tina4_session`. It is `HttpOnly` and `SameSite=Lax` by default. Tina4 manages it -- you never need to set or read it yourself.

---

## 3. The Session API

Access session data through `req.session`. It is available in every route handler with zero configuration.

### Full API Reference

| Method | Description |
|--------|-------------|
| `req.session.set(key, value)` | Store a value |
| `req.session.get(key, default)` | Retrieve a value (with optional default) |
| `req.session.delete(key)` | Remove a key |
| `req.session.has(key)` | Check if a key exists |
| `req.session.clear()` | Remove all session data |
| `req.session.destroy()` | Destroy the session entirely |
| `req.session.save()` | Persist session data (auto-called after response) |
| `req.session.regenerate()` | Generate a new session ID, preserve data |
| `req.session.flash(key, value)` | Set flash data (one-time read) |
| `req.session.flash(key)` | Read and remove flash data (dual-mode) |
| `req.session.getFlash(key)` | Explicit getter alias for flash(key) |
| `req.session.getSessionId()` | Get current session ID |
| `req.session.cookieHeader()` | Get Set-Cookie header value |
| `req.session.all()` | Get all session data as an object |

---

## 4. Reading and Writing Session Data

### Writing to the Session

```typescript
import { Router } from "tina4-nodejs";

Router.post("/login-form", async (req, res) => {
    // After validating credentials...
    req.session.set("user_id", 42);
    req.session.set("user_name", "Alice");
    req.session.set("role", "admin");
    req.session.set("logged_in", true);

    return res.redirect("/dashboard");
});
```

### Reading from the Session

```typescript
import { Router } from "tina4-nodejs";

Router.get("/dashboard", async (req, res) => {
    if (!req.session.get("logged_in")) {
        return res.redirect("/login");
    }

    return res.html("dashboard.html", {
        user_name: req.session.get("user_name"),
        role: req.session.get("role")
    });
});
```

### Deleting Session Data

```typescript
// Delete a single key
req.session.delete("temp_data");

// Clear all session data (logout)
Router.post("/logout", async (req, res) => {
    req.session.clear();
    return res.redirect("/login");
});
```

### Checking if a Key Exists

```typescript
if (req.session.has("user_id")) {
    const userId = req.session.get("user_id");
} else {
    const userId = null;
}

// Or use .get() with a default
const userId = req.session.get("user_id", null);
```

### Getting All Session Data

```typescript
const allData = req.session.all();
```

### Preferences Example

```typescript
import { Router } from "tina4-nodejs";

Router.post("/api/preferences", async (req, res) => {
    const body = req.body;

    req.session.set("language", body.language ?? "en");
    req.session.set("theme", body.theme ?? "light");
    req.session.set("items_per_page", parseInt(body.items_per_page ?? "20", 10));

    return res.json({
        message: "Preferences saved",
        preferences: {
            language: req.session.get("language"),
            theme: req.session.get("theme"),
            items_per_page: req.session.get("items_per_page")
        }
    });
});

Router.get("/api/preferences", async (req, res) => {
    return res.json({
        language: req.session.get("language", "en"),
        theme: req.session.get("theme", "light"),
        items_per_page: req.session.get("items_per_page", 20)
    });
});
```

### Visit Counter Example

```typescript
import { Router } from "tina4-nodejs";

Router.get("/visit-counter", async (req, res) => {
    const count = (req.session.get("visit_count", 0)) + 1;
    req.session.set("visit_count", count);

    return res.json({
        visit_count: count,
        message: `You have visited this page ${count} time${count === 1 ? "" : "s"}`
    });
});
```

```bash
curl http://localhost:7148/visit-counter -c cookies.txt -b cookies.txt
```

```json
{"visit_count":1,"message":"You have visited this page 1 time"}
```

---

## 5. Flash Messages

Flash messages are session values that exist for exactly one read. Set them before a redirect. Read them on the next request. They vanish after being read.

### Setting a Flash Message

```typescript
import { Router } from "tina4-nodejs";

Router.post("/api/contact", async (req, res) => {
    // Process the form...

    req.session.flash("message", "Your message has been sent!");
    req.session.flash("message_type", "success");

    return res.redirect("/contact");
});
```

### Reading a Flash Message

Flash is dual-mode: `flash(key, value)` sets, `flash(key)` gets and removes. `getFlash()` is an explicit alias.

```typescript
Router.get("/contact", async (req, res) => {
    const flashMessage = req.session.flash("message");       // get + auto-remove
    const flashType = req.session.flash("message_type") ?? "info";

    return res.html("contact.html", {
        flash_message: flashMessage,
        flash_type: flashType
    });
});
```

The `getFlash()` method reads the value and removes it in one step. The next time the user visits `/contact`, the flash message will be gone.

### Flash Messages in Templates

```html
{% if flash_message %}
    <div class="alert alert-{{ flash_type }}">
        {{ flash_message }}
    </div>
{% endif %}
```

---

## 6. Cookies

Cookies are small data fragments stored in the browser. Unlike sessions, cookies travel with every request and are visible to JavaScript (unless `httpOnly` is set).

### Setting a Cookie

```typescript
import { Router } from "tina4-nodejs";

Router.post("/preferences", async (req, res) => {
    const theme = req.body.theme ?? "light";
    const language = req.body.language ?? "en";

    return res
        .cookie("theme", theme, {
            maxAge: 365 * 24 * 60 * 60 * 1000,  // 1 year in milliseconds
            path: "/",
            sameSite: "Lax"
        })
        .cookie("language", language, {
            maxAge: 365 * 24 * 60 * 60 * 1000,
            path: "/",
            sameSite: "Lax"
        })
        .json({ message: "Preferences saved" });
});
```

### Reading a Cookie

```typescript
import { Router } from "tina4-nodejs";

Router.get("/", async (req, res) => {
    const theme = req.cookies.theme ?? "light";
    const language = req.cookies.language ?? "en";

    return res.html("home.html", {
        theme,
        language
    });
});
```

### Deleting a Cookie

Set `maxAge` to 0:

```typescript
Router.post("/clear-preferences", async (req, res) => {
    return res
        .cookie("theme", "", { maxAge: 0, path: "/" })
        .cookie("language", "", { maxAge: 0, path: "/" })
        .json({ message: "Preferences cleared" });
});
```

### Cookie Options

| Option | Type | Description |
|--------|------|-------------|
| `maxAge` | number | Lifetime in milliseconds. 0 = delete. Omit = session cookie (deleted when browser closes). |
| `expires` | Date | Expiry date. `maxAge` is preferred -- it is simpler and more predictable. |
| `path` | string | URL path scope. `/` means the whole site. `/admin` means only under `/admin`. |
| `domain` | string | Domain scope. `.example.com` includes subdomains. |
| `secure` | boolean | Only send over HTTPS. Always `true` in production. |
| `httpOnly` | boolean | Not accessible via JavaScript. Use for session cookies. |
| `sameSite` | string | `"Strict"`, `"Lax"`, or `"None"`. Controls cross-site sending. |

### When to Use Cookies vs Sessions

| Use Case | Use Cookies | Use Sessions |
|----------|------------|-------------|
| User preferences (theme, language) | Yes | No |
| Shopping cart | No | Yes |
| Authentication state | No (use JWT in header) | Yes (for form-based auth) |
| Flash messages | No | Yes |
| Tracking consent | Yes | No |
| Sensitive data (user ID, role) | No | Yes |

The rule: sensitive data or data the client should not see goes in sessions. Non-sensitive data that should persist beyond session expiry goes in cookies.

---

## 7. Remember Me

The "remember me" pattern extends the session lifetime when the user checks a box on the login form:

```typescript
import { Router } from "tina4-nodejs";

Router.post("/login", async (req, res) => {
    const { email, password, remember } = req.body;

    // Validate credentials...
    const user = await authenticateUser(email, password);
    if (!user) {
        req.session.flash("message", "Invalid email or password");
        req.session.flash("message_type", "error");
        return res.redirect("/login");
    }

    // Regenerate session ID (prevents session fixation)
    req.session.regenerate();

    // Set session data
    req.session.set("user_id", user.id);
    req.session.set("user_name", user.name);
    req.session.set("logged_in", true);

    // Handle "remember me"
    if (remember) {
        // Generate a long-lived token
        const Auth = require("tina4-nodejs").Auth;
        const rememberToken = Auth.getToken({ user_id: user.id });

        // Store it in a cookie that lasts 30 days
        return res
            .cookie("remember_token", rememberToken, {
                maxAge: 30 * 24 * 60 * 60 * 1000,
                httpOnly: true,
                secure: true,
                path: "/",
                sameSite: "Lax"
            })
            .redirect("/dashboard");
    }

    return res.redirect("/dashboard");
});
```

Then, on every page load, check for the remember token if the session has expired:

```typescript
async function rememberMeMiddleware(req, res, nextHandler) {
    if (!req.session.get("logged_in")) {
        const rememberToken = req.cookies.remember_token;

        if (rememberToken && Auth.validToken(rememberToken)) {
            const payload = Auth.getPayload(rememberToken);
            const db = new Database();
            const user = await db.fetchOne(
                "SELECT id, name FROM users WHERE id = ?",
                [payload.user_id]
            );

            if (user) {
                req.session.set("user_id", user.id);
                req.session.set("user_name", user.name);
                req.session.set("logged_in", true);
            }
        }
    }

    return await nextHandler(req, res);
}
```

The form:

```html
<form method="POST" action="/login">
    {{ form_token() }}
    <div class="form-group">
        <label for="email">Email</label>
        <input type="email" id="email" name="email" class="form-control" required>
    </div>
    <div class="form-group">
        <label for="password">Password</label>
        <input type="password" id="password" name="password" class="form-control" required>
    </div>
    <div class="form-check">
        <input type="checkbox" id="remember" name="remember" value="1" class="form-check-input">
        <label for="remember" class="form-check-label">Remember me for 30 days</label>
    </div>
    <button type="submit" class="btn btn-primary">Login</button>
</form>
```

Without the checkbox, the session uses the default TTL (1 hour). With the checkbox, the remember token cookie persists for 30 days. The server controls the duration -- the client cannot extend it.

---

## 8. Session Security

### Regenerate Session ID After Login

To prevent session fixation attacks, regenerate the session ID after login:

```typescript
Router.post("/login-form", async (req, res) => {
    // After validating credentials...

    // Regenerate session ID (prevents session fixation)
    req.session.regenerate();

    req.session.set("user_id", user.id);
    req.session.set("logged_in", true);

    return res.redirect("/dashboard");
});
```

### Destroy a Session

To destroy a session entirely (not just clear its data):

```typescript
Router.post("/logout", async (req, res) => {
    req.session.destroy();
    return res.redirect("/login");
});
```

### Secure Cookie Settings

The session cookie (`tina4_session`) is `HttpOnly` and `SameSite=Lax` by default. For production, ensure HTTPS:

```bash
TINA4_SESSION_SECURE=true     # Only send over HTTPS
TINA4_SESSION_HTTPONLY=true   # Not accessible via JavaScript (default)
TINA4_SESSION_SAMESITE=Lax   # Prevent CSRF via cross-site requests (default)
```

`TINA4_SESSION_SAMESITE` controls cross-site cookie behavior:

| Value | Behavior |
|-------|----------|
| `Strict` | Never sent with cross-site requests. Safest. Breaks some flows (clicking links from email). |
| `Lax` | Sent with top-level navigations (clicking links) but not cross-site API calls. Good default. |
| `None` | Always sent. Requires `TINA4_SESSION_SECURE=true`. Only for cross-site cookie access. |

### Session Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_BACKEND` | `file` | Storage backend: `file`, `redis`, `mongodb`, `valkey`, `database` |
| `TINA4_SESSION_TTL` | `3600` | Session lifetime in seconds |
| `TINA4_SESSION_HOST` | `localhost` | Host for Redis/MongoDB/Valkey |
| `TINA4_SESSION_PORT` | `6379` | Port for Redis/MongoDB/Valkey |
| `TINA4_SESSION_PASSWORD` | (none) | Password for Redis/Valkey |
| `TINA4_SESSION_SECURE` | `false` | Cookie sent only over HTTPS |
| `TINA4_SESSION_HTTPONLY` | `true` | Cookie inaccessible to JavaScript |
| `TINA4_SESSION_SAMESITE` | `Lax` | Cross-site cookie policy |

---

## 9. Exercise: Build a Shopping Cart

Build a shopping cart using sessions.

### Requirements

1. Create these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/cart` | View cart contents (rendered HTML page) |
| `POST` | `/cart/add` | Add an item to the cart |
| `POST` | `/cart/update` | Update item quantity |
| `POST` | `/cart/remove` | Remove an item from the cart |
| `POST` | `/cart/clear` | Clear the entire cart |
| `GET` | `/cart/api` | Get cart as JSON (for AJAX) |

2. The cart is stored in the session via `req.session.set("cart", [...])`
3. Each cart item has: `product_id`, `name`, `price`, `quantity`
4. Adding an existing product increments its quantity
5. The cart page shows items, quantities, line totals, and a grand total
6. Use flash messages for feedback ("Item added", "Cart cleared", etc.)

Use this product data for validation:

```typescript
const PRODUCTS: Record<number, { name: string; price: number }> = {
    1: { name: "Wireless Keyboard", price: 79.99 },
    2: { name: "USB-C Hub", price: 49.99 },
    3: { name: "Monitor Stand", price: 129.99 },
    4: { name: "Mechanical Mouse", price: 59.99 },
    5: { name: "Desk Lamp", price: 39.99 }
};
```

### Test with:

```bash
# Add items
curl -X POST http://localhost:7148/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 2}' \
  -c cookies.txt -b cookies.txt

curl -X POST http://localhost:7148/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 3, "quantity": 1}' \
  -c cookies.txt -b cookies.txt

# View cart
curl http://localhost:7148/cart/api -b cookies.txt

# Update quantity
curl -X POST http://localhost:7148/cart/update \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 3}' \
  -c cookies.txt -b cookies.txt

# Remove item
curl -X POST http://localhost:7148/cart/remove \
  -H "Content-Type: application/json" \
  -d '{"product_id": 3}' \
  -c cookies.txt -b cookies.txt

# Clear cart
curl -X POST http://localhost:7148/cart/clear -c cookies.txt -b cookies.txt
```

---

## 10. Solution

Create `src/routes/cart.ts`:

```typescript
import { Router } from "tina4-nodejs";

const PRODUCTS: Record<number, { name: string; price: number }> = {
    1: { name: "Wireless Keyboard", price: 79.99 },
    2: { name: "USB-C Hub", price: 49.99 },
    3: { name: "Monitor Stand", price: 129.99 },
    4: { name: "Mechanical Mouse", price: 59.99 },
    5: { name: "Desk Lamp", price: 39.99 }
};


function getCart(session: any): any[] {
    return session.get("cart", []);
}


function saveCart(session: any, cart: any[]): void {
    session.set("cart", cart);
}


function calculateTotals(cart: any[]): { cart: any[]; grandTotal: number } {
    for (const item of cart) {
        item.line_total = Math.round(item.price * item.quantity * 100) / 100;
    }
    const grandTotal = Math.round(
        cart.reduce((sum, item) => sum + item.line_total, 0) * 100
    ) / 100;
    return { cart, grandTotal };
}


Router.get("/cart", async (req, res) => {
    const cart = getCart(req.session);
    const { grandTotal } = calculateTotals(cart);
    const flashMessage = req.session.getFlash("message");
    const flashType = req.session.getFlash("message_type") ?? "info";

    return res.html("cart.html", {
        cart,
        grand_total: grandTotal,
        item_count: cart.reduce((sum, item) => sum + item.quantity, 0),
        flash_message: flashMessage,
        flash_type: flashType
    });
});


Router.get("/cart/api", async (req, res) => {
    const cart = getCart(req.session);
    const { grandTotal } = calculateTotals(cart);

    return res.json({
        cart,
        grand_total: grandTotal,
        item_count: cart.reduce((sum, item) => sum + item.quantity, 0)
    });
});


Router.post("/cart/add", async (req, res) => {
    const body = req.body;
    const productId = parseInt(body.product_id, 10);
    const quantity = parseInt(body.quantity ?? "1", 10);

    if (!PRODUCTS[productId]) {
        return res.status(404).json({ error: "Product not found" });
    }

    if (quantity < 1) {
        return res.status(400).json({ error: "Quantity must be at least 1" });
    }

    const product = PRODUCTS[productId];
    const cart = getCart(req.session);

    // Check if product already in cart
    const existing = cart.find(item => item.product_id === productId);
    if (existing) {
        existing.quantity += quantity;
        saveCart(req.session, cart);
        req.session.flash("message", `Updated ${product.name} quantity`);
        req.session.flash("message_type", "success");
        return res.json({ message: `Updated ${product.name} quantity`, cart });
    }

    // Add new item
    cart.push({
        product_id: productId,
        name: product.name,
        price: product.price,
        quantity
    });
    saveCart(req.session, cart);

    req.session.flash("message", `Added ${product.name} to cart`);
    req.session.flash("message_type", "success");

    return res.status(201).json({ message: `Added ${product.name}`, cart });
});


Router.post("/cart/update", async (req, res) => {
    const body = req.body;
    const productId = parseInt(body.product_id, 10);
    const quantity = parseInt(body.quantity ?? "1", 10);

    const cart = getCart(req.session);
    const index = cart.findIndex(item => item.product_id === productId);

    if (index === -1) {
        return res.status(404).json({ error: "Product not in cart" });
    }

    if (quantity < 1) {
        const removed = cart[index];
        cart.splice(index, 1);
        req.session.flash("message", `Removed ${removed.name} from cart`);
    } else {
        cart[index].quantity = quantity;
        req.session.flash("message", `Updated ${cart[index].name} quantity to ${quantity}`);
    }

    req.session.flash("message_type", "success");
    saveCart(req.session, cart);
    return res.json({ message: "Cart updated", cart });
});


Router.post("/cart/remove", async (req, res) => {
    const productId = parseInt(req.body.product_id, 10);
    const cart = getCart(req.session);
    const index = cart.findIndex(item => item.product_id === productId);

    if (index === -1) {
        return res.status(404).json({ error: "Product not in cart" });
    }

    const removed = cart[index];
    cart.splice(index, 1);
    saveCart(req.session, cart);

    req.session.flash("message", `Removed ${removed.name} from cart`);
    req.session.flash("message_type", "success");

    return res.json({ message: `Removed ${removed.name}`, cart });
});


Router.post("/cart/clear", async (req, res) => {
    saveCart(req.session, []);
    req.session.flash("message", "Cart cleared");
    req.session.flash("message_type", "info");
    return res.json({ message: "Cart cleared", cart: [] });
});
```

**Expected output for cart API after adding items:**

```json
{
  "cart": [
    {"product_id": 1, "name": "Wireless Keyboard", "price": 79.99, "quantity": 2, "line_total": 159.98},
    {"product_id": 3, "name": "Monitor Stand", "price": 129.99, "quantity": 1, "line_total": 129.99}
  ],
  "grand_total": 289.97,
  "item_count": 3
}
```

---

## 11. Gotchas

### 1. Session lost between requests

**Problem:** Data you stored in the session is gone on the next request.

**Cause:** The session cookie is not being sent back by the client. This happens when using curl without `-c cookies.txt -b cookies.txt`, or when the browser blocks cookies.

**Fix:** For curl testing, use `-c cookies.txt -b cookies.txt` to save and send cookies. In the browser, make sure cookies are not blocked for your site.

### 2. Session data is not JSON-serializable

**Problem:** Storing a JavaScript object with circular references or class instances in the session causes an error.

**Cause:** Sessions are serialized to JSON. Objects with circular references, `Map`, `Set`, `Date`, or custom class instances cannot be serialized directly.

**Fix:** Convert objects to plain values before storing. For dates: `req.session.set("login_time", new Date().toISOString())`. For maps: convert to a plain object with `Object.fromEntries(myMap)`.

### 3. Cookie not sent on cross-origin requests

**Problem:** Your frontend at `http://localhost:3000` calls your API at `http://localhost:7148`, but cookies are not included.

**Cause:** Browsers do not send cookies cross-origin by default. You need both CORS configuration and explicit `credentials: "include"` in fetch.

**Fix:** Set `CORS_CREDENTIALS=true` in `.env` and use `fetch(url, { credentials: "include" })` in your frontend JavaScript. Also set `CORS_ORIGINS` to the specific frontend origin (not `*` -- wildcard does not work with credentials).

### 4. File-based sessions on multi-server deployments

**Problem:** A user is logged in on server A but logged out on server B.

**Cause:** File-based sessions are stored on the local filesystem. Each server has its own session files.

**Fix:** Switch to Redis, Valkey, MongoDB, or database-backed sessions so all servers share the same session store.

### 5. Session cookie overwritten by another app

**Problem:** Your session keeps getting reset even though you set it correctly.

**Cause:** Another application on the same domain uses the same session cookie name.

**Fix:** The session cookie name (`tina4_session`) is managed by Tina4. If you need to change it, set `TINA4_SESSION_NAME=myapp_session` in `.env`.

### 6. Secure cookies on localhost

**Problem:** Setting `secure: true` on a cookie means it never gets sent during development.

**Cause:** Secure cookies are only sent over HTTPS. `http://localhost` is not HTTPS.

**Fix:** Do not set `secure: true` during development. Use environment-based configuration: `secure: process.env.TINA4_DEBUG !== "true"`.

### 7. Flash messages shown twice

**Problem:** A flash message appears on the page, but when you refresh, it shows again.

**Cause:** You read the flash message but did not remove it. Using `req.session.get()` reads without deleting.

**Fix:** Use `req.session.getFlash("message")` to read flash data. It reads and deletes in one step. Do not use `req.session.get()` for flash messages.

### 8. Session data disappears after server restart

**Problem:** All sessions vanish when you restart the Node.js process.

**Cause:** File-based sessions may be stored in a temporary directory that gets cleared on restart, or in-memory state was lost.

**Fix:** Use Redis or database sessions for production. For file sessions, set `TINA4_SESSION_PATH` to a persistent directory.

### 9. Large session data causes slow requests

**Problem:** Pages load slower than expected. Session reads and writes take visible time.

**Cause:** You stored large objects in the session -- full user profiles, query results, or file contents.

**Fix:** Keep session data small. Store IDs, not entire objects. Look up the full data from the database when you need it.
