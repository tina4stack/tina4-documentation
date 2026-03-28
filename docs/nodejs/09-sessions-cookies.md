# Chapter 9: Sessions & Cookies

## 1. State in a Stateless World

Your e-commerce site needs a shopping cart that persists across page loads. It remembers the user's language preference. It flashes success messages after form submissions. But HTTP has no memory. Every request arrives fresh. No context. No history.

Sessions and cookies give the server memory. They teach it to remember who is making requests and what they have been doing.

---

## 2. How Sessions Work

Sessions are auto-started. Every route handler receives `req.session` ready to use. No manual setup required.

A user visits your site for the first time. Tina4 generates a unique session ID, stores it in a cookie named `tina4_session` (`HttpOnly`, `SameSite=Lax`) on the user's browser, and creates a server-side storage entry keyed by that ID. Every subsequent request carries the cookie. Tina4 looks up the session data and attaches it to `req.session`.

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
| `req.session.getFlash(key)` | Read and remove flash data |
| `req.session.all()` | Get all session data as an object |

---

## 4. File Sessions (Default)

Tina4 stores sessions in files out of the box. Zero configuration.

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

## 5. Redis Sessions

For production deployments with multiple servers:

```env
TINA4_SESSION_BACKEND=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
TINA4_SESSION_PASSWORD=your-redis-password
```

Your code stays exactly the same. `req.session` works identically.

---

## 6. MongoDB and Valkey Sessions

```env
# MongoDB
TINA4_SESSION_BACKEND=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017

# Valkey
TINA4_SESSION_BACKEND=valkey
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
```

---

## 7. Database Sessions

```env
TINA4_SESSION_BACKEND=database
```

Stores sessions in the `tina4_session` table using your existing database connection (`DATABASE_URL`). The table is auto-created on first use. Works with all 5 database engines (SQLite, PostgreSQL, MySQL, MSSQL, Firebird).

---

## 8. Reading and Writing Session Data

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

Router.post("/api/session/clear", async (req, res) => {
    req.session.clear();
    return res.json({ message: "Session cleared" });
});
```

### Shopping Cart Example

```typescript
Router.post("/api/cart/add", async (req, res) => {
    const body = req.body;

    const cart = req.session.get("cart", []);
    const existingIndex = cart.findIndex(item => item.product_id === parseInt(body.product_id, 10));

    if (existingIndex >= 0) {
        cart[existingIndex].quantity += parseInt(body.quantity ?? "1", 10);
    } else {
        cart.push({
            product_id: parseInt(body.product_id, 10),
            name: body.name,
            price: parseFloat(body.price),
            quantity: parseInt(body.quantity ?? "1", 10)
        });
    }

    req.session.set("cart", cart);

    const total = cart.reduce((sum, item) => sum + item.price * item.quantity, 0);

    return res.json({
        message: "Added to cart",
        cart_items: cart.length,
        cart_total: Math.round(total * 100) / 100
    });
});
```

---

## 9. Flash Messages

Flash messages exist for exactly one read:

```typescript
Router.post("/profile/update", async (req, res) => {
    // Update profile logic here...

    req.session.flash("message", "Profile updated successfully");
    req.session.flash("message_type", "success");

    return res.redirect("/profile");
});

Router.get("/profile", async (req, res) => {
    const flashMessage = req.session.getFlash("message");
    const flashType = req.session.getFlash("message_type") ?? "info";

    return res.html("profile.html", {
        user: { name: "Alice", email: "alice@example.com" },
        flash_message: flashMessage,
        flash_type: flashType
    });
});
```

The `getFlash()` method reads the value and removes it in one step. The next request will not see it.

---

## 10. Setting and Reading Cookies

```typescript
Router.post("/api/set-language", async (req, res) => {
    const language = req.body.language ?? "en";

    return res
        .cookie("language", language, {
            expires: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
            path: "/",
            httpOnly: false,
            secure: false,
            sameSite: "Lax"
        })
        .json({ message: `Language set to ${language}` });
});

Router.get("/api/get-language", async (req, res) => {
    const language = req.cookies.language ?? "en";
    return res.json({ language });
});
```

### When to Use Cookies vs Sessions

| Use Cookies For | Use Sessions For |
|-----------------|------------------|
| Language preference | Shopping cart contents |
| Theme preference (light/dark) | User authentication state |
| "Remember this device" flag | Flash messages |
| Non-sensitive, long-lived data | Sensitive, short-lived data |

---

## 11. Session Security

```env
TINA4_SESSION_TTL=3600
TINA4_SESSION_SECURE=true
TINA4_SESSION_HTTPONLY=true
TINA4_SESSION_SAMESITE=Lax
```

`TINA4_SESSION_SAMESITE` controls cross-site cookie behavior:

| Value | Behavior |
|-------|----------|
| `Strict` | Never sent with cross-site requests. Safest. Breaks some flows (clicking links from email). |
| `Lax` | Sent with top-level navigations (clicking links) but not cross-site API calls. Good default. |
| `None` | Always sent. Requires `TINA4_SESSION_SECURE=true`. Only for cross-site cookie access. |

### Session Regeneration

After login, regenerate the session ID to prevent session fixation:

```typescript
Router.post("/login", async (req, res) => {
    // Validate credentials...
    req.session.regenerate();
    req.session.set("user_id", user.id);
    return res.redirect("/dashboard");
});
```

### Destroy a Session

To completely destroy a session (not just clear its data):

```typescript
Router.post("/logout", async (req, res) => {
    req.session.destroy();
    return res.redirect("/login");
});
```

---

## 12. Exercise: Build a Shopping Cart with Session Storage

Build a shopping cart stored entirely in session data.

### Requirements

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/cart/add` | Add an item to the cart |
| `GET` | `/api/cart` | View the cart with totals |
| `PUT` | `/api/cart/{product_id:int}` | Update quantity (0 removes) |
| `DELETE` | `/api/cart/{product_id:int}` | Remove an item |
| `DELETE` | `/api/cart` | Clear the cart |

---

## 13. Solution

Create `src/routes/cart.ts`:

```typescript
import { Router } from "tina4-nodejs";

function getCart(session: any): any[] {
    return session.get("cart", []);
}

function cartResponse(cart: any[]) {
    let total = 0;
    let itemCount = 0;
    const items = cart.map(item => {
        const subtotal = item.price * item.quantity;
        total += subtotal;
        itemCount += item.quantity;
        return { ...item, subtotal: Math.round(subtotal * 100) / 100 };
    });

    return {
        items,
        item_count: itemCount,
        unique_items: cart.length,
        total: Math.round(total * 100) / 100
    };
}

Router.post("/api/cart/add", async (req, res) => {
    const body = req.body;
    if (!body.product_id || !body.name || body.price === undefined) {
        return res.status(400).json({ error: "product_id, name, and price are required" });
    }

    const cart = getCart(req.session);
    const productId = parseInt(body.product_id, 10);
    const quantity = parseInt(body.quantity ?? "1", 10);
    const existingIndex = cart.findIndex(item => item.product_id === productId);

    if (existingIndex >= 0) {
        cart[existingIndex].quantity += quantity;
    } else {
        cart.push({
            product_id: productId,
            name: body.name,
            price: parseFloat(body.price),
            quantity
        });
    }

    req.session.set("cart", cart);
    return res.json(cartResponse(cart));
});

Router.get("/api/cart", async (req, res) => {
    return res.json(cartResponse(getCart(req.session)));
});

Router.put("/api/cart/{product_id:int}", async (req, res) => {
    const productId = req.params.product_id;
    const quantity = parseInt(req.body.quantity ?? "0", 10);
    const cart = getCart(req.session);
    const index = cart.findIndex(item => item.product_id === productId);

    if (index === -1) {
        return res.status(404).json({ error: "Product not in cart" });
    }

    if (quantity <= 0) {
        cart.splice(index, 1);
    } else {
        cart[index].quantity = quantity;
    }

    req.session.set("cart", cart);
    return res.json(cartResponse(cart));
});

Router.delete("/api/cart/{product_id:int}", async (req, res) => {
    const productId = req.params.product_id;
    const cart = getCart(req.session);
    const index = cart.findIndex(item => item.product_id === productId);

    if (index === -1) {
        return res.status(404).json({ error: "Product not in cart" });
    }

    cart.splice(index, 1);
    req.session.set("cart", cart);
    return res.json(cartResponse(cart));
});

Router.delete("/api/cart", async (req, res) => {
    req.session.set("cart", []);
    return res.json(cartResponse([]));
});
```

---

## 14. Gotchas

### 1. Sessions Do Not Work with curl Without Cookie Flags

**Fix:** Use `-c cookies.txt -b cookies.txt` with curl.

### 2. Session Data Disappears After Server Restart

**Fix:** Use Redis for production. Set `TINA4_SESSION_PATH` for persistent file sessions.

### 3. Session Cookie Not Sent Over HTTP in Production

**Fix:** Ensure `TINA4_SESSION_SECURE` matches your actual protocol.

### 4. Flash Messages Show Twice

**Fix:** Use `req.session.getFlash("message")` to read flash data. It reads and deletes in one step. Do not use `req.session.get()` for flash messages.

### 5. Large Session Data Causes Slow Requests

**Fix:** Keep session data small. Store IDs, not entire objects.

### 6. Remember Me Token Not Invalidated on Password Change

**Fix:** Clear `remember_token` when the password changes.

### 7. Session Fixation

**Fix:** Call `req.session.regenerate()` after successful login.
