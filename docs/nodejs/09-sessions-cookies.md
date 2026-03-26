# Chapter 9: Sessions & Cookies

## 1. State in a Stateless World

Your e-commerce site needs a shopping cart that persists across page loads. It remembers the user's language preference. It flashes success messages after form submissions. But HTTP has no memory. Every request arrives fresh. No context. No history.

Sessions and cookies give the server memory. They teach it to remember who is making requests and what they have been doing.

---

## 2. How Sessions Work

A user visits your site for the first time. Tina4 generates a unique session ID, stores it in a cookie on the user's browser, and creates a server-side storage entry keyed by that ID. Every subsequent request carries the cookie. Tina4 looks up the session data and attaches it to `req.session`.

---

## 3. File Sessions (Default)

Tina4 stores sessions in files out of the box. Zero configuration.

```typescript
import { Router } from "tina4-nodejs";

Router.get("/visit-counter", async (req, res) => {
    const count = (req.session.visit_count ?? 0) + 1;
    req.session.visit_count = count;

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

## 4. Redis Sessions

For production deployments with multiple servers:

```env
TINA4_SESSION_HANDLER=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
TINA4_SESSION_PASSWORD=your-redis-password
```

Your code stays exactly the same. `req.session` works identically.

---

## 5. MongoDB and Valkey Sessions

```env
# MongoDB
TINA4_SESSION_HANDLER=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017

# Valkey
TINA4_SESSION_HANDLER=valkey
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
```

---

## 6. Database Sessions

```env
TINA4_SESSION_BACKEND=database
```

Stores sessions in the `tina4_session` table using your existing database connection (`DATABASE_URL`). The table is auto-created on first use. Works with all 5 database engines (SQLite, PostgreSQL, MySQL, MSSQL, Firebird).

---

## 7. Reading and Writing Session Data

```typescript
import { Router } from "tina4-nodejs";

Router.post("/api/preferences", async (req, res) => {
    const body = req.body;

    req.session.language = body.language ?? "en";
    req.session.theme = body.theme ?? "light";
    req.session.items_per_page = parseInt(body.items_per_page ?? "20", 10);

    return res.json({
        message: "Preferences saved",
        preferences: {
            language: req.session.language,
            theme: req.session.theme,
            items_per_page: req.session.items_per_page
        }
    });
});

Router.get("/api/preferences", async (req, res) => {
    return res.json({
        language: req.session.language ?? "en",
        theme: req.session.theme ?? "light",
        items_per_page: req.session.items_per_page ?? 20
    });
});

Router.post("/api/session/clear", async (req, res) => {
    req.session = {};
    return res.json({ message: "Session cleared" });
});
```

### Shopping Cart Example

```typescript
Router.post("/api/cart/add", async (req, res) => {
    const body = req.body;

    if (!req.session.cart) {
        req.session.cart = [];
    }

    const cart = req.session.cart;
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

    req.session.cart = cart;

    const total = cart.reduce((sum, item) => sum + item.price * item.quantity, 0);

    return res.json({
        message: "Added to cart",
        cart_items: cart.length,
        cart_total: Math.round(total * 100) / 100
    });
});
```

---

## 7. Flash Messages

Flash messages exist for exactly one request:

```typescript
Router.post("/profile/update", async (req, res) => {
    // Update profile logic here...

    req.session._flash = {
        type: "success",
        message: "Profile updated successfully"
    };

    return res.redirect("/profile");
});

Router.get("/profile", async (req, res) => {
    const flash = req.session._flash ?? null;
    delete req.session._flash;

    return res.html("profile.html", {
        user: { name: "Alice", email: "alice@example.com" },
        flash
    });
});
```

---

## 8. Setting and Reading Cookies

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

## 9. Session Security

```env
TINA4_SESSION_LIFETIME=3600
TINA4_SESSION_NAME=tina4_session
TINA4_SESSION_SECURE=true
TINA4_SESSION_HTTPONLY=true
TINA4_SESSION_SAMESITE=Lax
```

### Session Regeneration

After login, regenerate the session ID to prevent session fixation:

```typescript
Router.post("/login", async (req, res) => {
    // Validate credentials...
    req.sessionRegenerate();
    req.session.user_id = user.id;
    return res.redirect("/dashboard");
});
```

---

## 10. Exercise: Build a Shopping Cart with Session Storage

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

## 11. Solution

Create `src/routes/cart.ts`:

```typescript
import { Router } from "tina4-nodejs";

function getCart(session: any): any[] {
    return session.cart ?? [];
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

    req.session.cart = cart;
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

    req.session.cart = cart;
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
    req.session.cart = cart;
    return res.json(cartResponse(cart));
});

Router.delete("/api/cart", async (req, res) => {
    req.session.cart = [];
    return res.json(cartResponse([]));
});
```

---

## 12. Gotchas

### 1. Sessions Do Not Work with curl Without Cookie Flags

**Fix:** Use `-c cookies.txt -b cookies.txt` with curl.

### 2. Session Data Disappears After Server Restart

**Fix:** Use Redis for production. Set `TINA4_SESSION_PATH` for persistent file sessions.

### 3. Session Cookie Not Sent Over HTTP in Production

**Fix:** Ensure `TINA4_SESSION_SECURE` matches your actual protocol.

### 4. Flash Messages Show Twice

**Fix:** Always clear the flash message immediately after reading: `delete req.session._flash`.

### 5. Large Session Data Causes Slow Requests

**Fix:** Keep session data small. Store IDs, not entire objects.

### 6. Remember Me Token Not Invalidated on Password Change

**Fix:** Clear `remember_token` when the password changes.

### 7. Session Fixation

**Fix:** Call `req.sessionRegenerate()` after successful login.
