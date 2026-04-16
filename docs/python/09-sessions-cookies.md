# Chapter 9: Sessions and Cookies

## 1. Remembering Your Users

JWT tokens handle APIs. Traditional web applications need more. A shopping cart that persists across pages. A flash message that appears once after a redirect. A "remember me" checkbox on the login form. These features run on sessions and cookies -- server-side state tied to a browser.

Picture an e-commerce site. A customer adds three items to their cart. Navigates to a product page. Comes back to the cart. Without sessions, the cart is empty every time. Sessions give the server memory. Each browser gets its own state, preserved across requests.

Sessions are auto-started. Every route handler receives `request.session` ready to use. No manual setup. No configuration required for the default file backend.

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
| Redis | `redis` | `redis` | Production, multi-server |
| MongoDB | `mongodb` | `pymongo` | Production, document stores |
| Valkey | `valkey` | `valkey` | Production, Redis alternative |
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
uv add redis
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

Stores sessions in the `tina4_session` table using your existing database connection (`DATABASE_URL`). The table is auto-created on first use.

### Session Lifetime

```bash
TINA4_SESSION_TTL=3600  # 1 hour in seconds (default)
```

### Session Cookie

The session cookie is named `tina4_session`. It is `HttpOnly` and `SameSite=Lax` by default. Tina4 manages it automatically -- you never need to set or read it yourself.

---

## 3. The Session API

Access session data through `request.session`. It is available in every route handler with zero configuration.

### Full API Reference

| Method | Description |
|--------|-------------|
| `request.session.set(key, value)` | Store a value |
| `request.session.get(key, default)` | Retrieve a value (with optional default) |
| `request.session.delete(key)` | Remove a key |
| `request.session.has(key)` | Check if a key exists |
| `request.session.clear()` | Remove all session data |
| `request.session.destroy()` | Destroy the session entirely |
| `request.session.save()` | Persist session data (auto-called after response) |
| `request.session.regenerate()` | Generate a new session ID, preserve data |
| `request.session.flash(key, value)` | Set flash data (one-time read) |
| `request.session.flash(key)` | Read and remove flash data |
| `request.session.all()` | Get all session data as a dictionary |

---

## 4. Reading and Writing Session Data

### Writing to the Session

```python
from tina4_python.core.router import post

@post("/login-form")
async def login_form(request, response):
    # After validating credentials...
    request.session.set("user_id", 42)
    request.session.set("user_name", "Alice")
    request.session.set("role", "admin")
    request.session.set("logged_in", True)

    return response.redirect("/dashboard")
```

### Reading from the Session

```python
from tina4_python.core.router import get

@get("/dashboard")
async def dashboard(request, response):
    if not request.session.get("logged_in"):
        return response.redirect("/login")

    return response.render("dashboard.html", {
        "user_name": request.session.get("user_name"),
        "role": request.session.get("role")
    })
```

### Deleting Session Data

```python
# Delete a single key
request.session.delete("temp_data")

# Clear all session data (logout)
@post("/logout")
async def logout(request, response):
    request.session.clear()
    return response.redirect("/login")
```

### Checking if a Key Exists

```python
if request.session.has("user_id"):
    user_id = request.session.get("user_id")
else:
    user_id = None

# Or use .get() with a default
user_id = request.session.get("user_id", None)
```

### Getting All Session Data

```python
all_data = request.session.all()
```

---

## 5. Flash Messages

Flash messages are session values that exist for exactly one read. Set them before a redirect. Read them on the next request. They vanish automatically after being read.

### Setting a Flash Message

```python
@post("/api/contact")
async def submit_contact(request, response):
    # Process the form...

    request.session.flash("message", "Your message has been sent!")
    request.session.flash("message_type", "success")

    return response.redirect("/contact")
```

### Reading a Flash Message

```python
@get("/contact")
async def contact_page(request, response):
    flash_message = request.session.flash("message")
    flash_type = request.session.flash("message_type") or "info"

    return response.render("contact.html", {
        "flash_message": flash_message,
        "flash_type": flash_type
    })
```

Calling `request.session.flash(key)` with only a key reads the value and removes it in one step. The next time the user visits `/contact`, the flash message will be gone.

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

```python
from tina4_python.core.router import post

@post("/preferences")
async def save_preferences(request, response):
    theme = request.body.get("theme", "light")
    language = request.body.get("language", "en")

    return response.cookie("theme", theme, {
        "max_age": 365 * 24 * 60 * 60,  # 1 year
        "path": "/",
        "samesite": "Lax"
    }).cookie("language", language, {
        "max_age": 365 * 24 * 60 * 60,
        "path": "/",
        "samesite": "Lax"
    }).json({"message": "Preferences saved"})
```

### Reading a Cookie

```python
from tina4_python.core.router import get

@get("/")
async def home(request, response):
    theme = request.cookies.get("theme", "light")
    language = request.cookies.get("language", "en")

    return response.render("home.html", {
        "theme": theme,
        "language": language
    })
```

### Deleting a Cookie

Set `max_age` to 0:

```python
@post("/clear-preferences")
async def clear_preferences(request, response):
    return response.cookie("theme", "", {"max_age": 0, "path": "/"}) \
                   .cookie("language", "", {"max_age": 0, "path": "/"}) \
                   .json({"message": "Preferences cleared"})
```

### Cookie Options

| Option | Type | Description |
|--------|------|-------------|
| `max_age` | int | Lifetime in seconds. 0 = delete. Omit = session cookie (deleted when browser closes). |
| `path` | str | URL path scope. `/` means the whole site. `/admin` means only under `/admin`. |
| `domain` | str | Domain scope. `.example.com` includes subdomains. |
| `secure` | bool | Only send over HTTPS. Always `True` in production. |
| `httponly` | bool | Not accessible via JavaScript. Use for session cookies. |
| `samesite` | str | `"Strict"`, `"Lax"`, or `"None"`. Controls cross-site sending. |

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

```python
from tina4_python.core.router import post
from tina4_python.auth import Auth, get_token
from tina4_python.database.connection import Database

@post("/login-form")
async def login_form(request, response):
    body = request.body
    db = Database()

    user = db.fetch_one(
        "SELECT id, name, email, password_hash FROM users WHERE email = ?",
        [body.get("email")]
    )

    if user is None or not Auth.check_password(body.get("password", ""), user["password_hash"]):
        request.session.flash("message", "Invalid email or password")
        request.session.flash("message_type", "error")
        return response.redirect("/login")

    # Set session data
    request.session.set("user_id", user["id"])
    request.session.set("user_name", user["name"])
    request.session.set("logged_in", True)

    # Handle "remember me"
    remember = body.get("remember_me") == "on"

    if remember:
        # Generate a long-lived token
        remember_token = get_token({"user_id": user["id"]})

        # Store it in a cookie that lasts 30 days
        return response.cookie("remember_token", remember_token, {
            "max_age": 30 * 24 * 60 * 60,
            "httponly": True,
            "secure": True,
            "path": "/",
            "samesite": "Lax"
        }).redirect("/dashboard")

    return response.redirect("/dashboard")
```

Then, on every page load, check for the remember token if the session has expired:

```python
async def remember_me_middleware(request, response, next_handler):
    if not request.session.get("logged_in"):
        remember_token = request.cookies.get("remember_token")

        if remember_token and Auth.valid_token(remember_token):
            payload = Auth.get_payload(remember_token)
            db = Database()
            user = db.fetch_one(
                "SELECT id, name FROM users WHERE id = ?",
                [payload["user_id"]]
            )

            if user:
                request.session.set("user_id", user["id"])
                request.session.set("user_name", user["name"])
                request.session.set("logged_in", True)

    return await next_handler(request, response)
```

---

## 8. Session Security

### Regenerate Session ID After Login

To prevent session fixation attacks, regenerate the session ID after login:

```python
@post("/login-form")
async def login_form(request, response):
    # After validating credentials...

    # Regenerate session ID (prevents session fixation)
    request.session.regenerate()

    request.session.set("user_id", user["id"])
    request.session.set("logged_in", True)

    return response.redirect("/dashboard")
```

### Destroy a Session

To completely destroy a session (not just clear its data):

```python
@post("/logout")
async def logout(request, response):
    request.session.destroy()
    return response.redirect("/login")
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

2. The cart is stored in the session via `request.session.set("cart", [...])`
3. Each cart item has: `product_id`, `name`, `price`, `quantity`
4. Adding an existing product increments its quantity
5. The cart page shows items, quantities, line totals, and a grand total
6. Use flash messages for feedback ("Item added", "Cart cleared", etc.)

Use this product data for validation:

```python
PRODUCTS = {
    1: {"name": "Wireless Keyboard", "price": 79.99},
    2: {"name": "USB-C Hub", "price": 49.99},
    3: {"name": "Monitor Stand", "price": 129.99},
    4: {"name": "Mechanical Mouse", "price": 59.99},
    5: {"name": "Desk Lamp", "price": 39.99}
}
```

### Test with:

```bash
# Add items
curl -X POST http://localhost:7145/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 2}' \
  -c cookies.txt -b cookies.txt

curl -X POST http://localhost:7145/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 3, "quantity": 1}' \
  -c cookies.txt -b cookies.txt

# View cart
curl http://localhost:7145/cart/api -b cookies.txt

# Update quantity
curl -X POST http://localhost:7145/cart/update \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 3}' \
  -c cookies.txt -b cookies.txt

# Remove item
curl -X POST http://localhost:7145/cart/remove \
  -H "Content-Type: application/json" \
  -d '{"product_id": 3}' \
  -c cookies.txt -b cookies.txt

# Clear cart
curl -X POST http://localhost:7145/cart/clear -c cookies.txt -b cookies.txt
```

---

## 10. Solution

Create `src/routes/cart.py`:

```python
from tina4_python.core.router import get, post

PRODUCTS = {
    1: {"name": "Wireless Keyboard", "price": 79.99},
    2: {"name": "USB-C Hub", "price": 49.99},
    3: {"name": "Monitor Stand", "price": 129.99},
    4: {"name": "Mechanical Mouse", "price": 59.99},
    5: {"name": "Desk Lamp", "price": 39.99}
}


def get_cart(session):
    return session.get("cart", [])


def save_cart(session, cart):
    session.set("cart", cart)


def calculate_totals(cart):
    for item in cart:
        item["line_total"] = round(item["price"] * item["quantity"], 2)
    grand_total = round(sum(item["line_total"] for item in cart), 2)
    return cart, grand_total


@get("/cart")
async def view_cart(request, response):
    cart = get_cart(request.session)
    cart, grand_total = calculate_totals(cart)
    flash_message = request.session.flash("message")
    flash_type = request.session.flash("message_type") or "info"

    return response.render("cart.html", {
        "cart": cart,
        "grand_total": grand_total,
        "item_count": sum(item["quantity"] for item in cart),
        "flash_message": flash_message,
        "flash_type": flash_type
    })


@get("/cart/api")
async def cart_api(request, response):
    cart = get_cart(request.session)
    cart, grand_total = calculate_totals(cart)

    return response.json({
        "cart": cart,
        "grand_total": grand_total,
        "item_count": sum(item["quantity"] for item in cart)
    })


@post("/cart/add")
async def add_to_cart(request, response):
    body = request.body
    product_id = body.get("product_id")
    quantity = int(body.get("quantity", 1))

    if product_id not in PRODUCTS:
        return response.json({"error": "Product not found"}, 404)

    if quantity < 1:
        return response.json({"error": "Quantity must be at least 1"}, 400)

    product = PRODUCTS[product_id]
    cart = get_cart(request.session)

    # Check if product already in cart
    for item in cart:
        if item["product_id"] == product_id:
            item["quantity"] += quantity
            save_cart(request.session, cart)
            request.session.flash("message", f"Updated {product['name']} quantity")
            request.session.flash("message_type", "success")
            return response.json({"message": f"Updated {product['name']} quantity", "cart": cart})

    # Add new item
    cart.append({
        "product_id": product_id,
        "name": product["name"],
        "price": product["price"],
        "quantity": quantity
    })
    save_cart(request.session, cart)

    request.session.flash("message", f"Added {product['name']} to cart")
    request.session.flash("message_type", "success")

    return response.json({"message": f"Added {product['name']}", "cart": cart}, 201)


@post("/cart/update")
async def update_cart(request, response):
    body = request.body
    product_id = body.get("product_id")
    quantity = int(body.get("quantity", 1))

    cart = get_cart(request.session)

    for item in cart:
        if item["product_id"] == product_id:
            if quantity < 1:
                cart.remove(item)
                request.session.flash("message", f"Removed {item['name']} from cart")
            else:
                item["quantity"] = quantity
                request.session.flash("message", f"Updated {item['name']} quantity to {quantity}")
            request.session.flash("message_type", "success")
            save_cart(request.session, cart)
            return response.json({"message": "Cart updated", "cart": cart})

    return response.json({"error": "Product not in cart"}, 404)


@post("/cart/remove")
async def remove_from_cart(request, response):
    product_id = request.body.get("product_id")
    cart = get_cart(request.session)

    for item in cart:
        if item["product_id"] == product_id:
            cart.remove(item)
            save_cart(request.session, cart)
            request.session.flash("message", f"Removed {item['name']} from cart")
            request.session.flash("message_type", "success")
            return response.json({"message": f"Removed {item['name']}", "cart": cart})

    return response.json({"error": "Product not in cart"}, 404)


@post("/cart/clear")
async def clear_cart(request, response):
    save_cart(request.session, [])
    request.session.flash("message", "Cart cleared")
    request.session.flash("message_type", "info")
    return response.json({"message": "Cart cleared", "cart": []})
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

**Problem:** Storing a Python object (like a datetime or a custom class) in the session causes an error.

**Cause:** Sessions are serialized to JSON (or pickled). Complex Python objects cannot be serialized directly.

**Fix:** Convert objects to strings or dictionaries before storing: `request.session.set("login_time", datetime.now().isoformat())`.

### 3. Cookie not sent on cross-origin requests

**Problem:** Your frontend at `http://localhost:3000` calls your API at `http://localhost:7145`, but cookies are not included.

**Cause:** Browsers do not send cookies cross-origin by default. You need both CORS configuration and explicit `credentials: "include"` in fetch.

**Fix:** Set `CORS_CREDENTIALS=true` in `.env` and use `fetch(url, { credentials: "include" })` in JavaScript. Also set `CORS_ORIGINS` to the specific frontend origin (not `*` -- wildcard does not work with credentials).

### 4. File-based sessions on multi-server deployments

**Problem:** A user is logged in on server A but logged out on server B.

**Cause:** File-based sessions are stored on the local filesystem. Each server has its own session files.

**Fix:** Switch to Redis, Valkey, MongoDB, or database-backed sessions so all servers share the same session store.

### 5. Session cookie overwritten by another app

**Problem:** Your session keeps getting reset even though you set it correctly.

**Cause:** Another application on the same domain uses the same session cookie name.

**Fix:** The session cookie name (`tina4_session`) is managed by Tina4. If you need to change it, set `TINA4_SESSION_NAME=myapp_session` in `.env`.

### 6. Secure cookies on localhost

**Problem:** Setting `"secure": True` on a cookie means it never gets sent during development.

**Cause:** Secure cookies are only sent over HTTPS. `http://localhost` is not HTTPS.

**Fix:** Do not set `"secure": True` during development. Use environment-based configuration: `"secure": os.getenv("TINA4_DEBUG") != "true"`.

### 7. Flash messages shown twice

**Problem:** A flash message appears on the page, but when you refresh, it shows again.

**Cause:** You read the flash message but did not remove it. Using `request.session.get()` reads without deleting.

**Fix:** Use `request.session.flash("message")` to read flash data. It reads and deletes in one step. Do not use `request.session.get()` for flash messages.
