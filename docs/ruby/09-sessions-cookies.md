# Chapter 9: Sessions & Cookies

## 1. State in a Stateless World

Your e-commerce site needs a shopping cart that persists across page loads. A language preference that sticks. Flash messages after form submissions. But HTTP is stateless. Every request arrives with no memory of what came before. Sessions and cookies give the server a way to remember.

Chapter 8 introduced sessions for authentication. This chapter goes deeper. Session backends. Flash messages. Cookies. Remember-me tokens. Security configuration.

---

## 2. How Sessions Work

Sessions are auto-started. Every route handler receives `request.session` ready to use. No manual setup required.

When a user visits your site for the first time, Tina4 generates a unique session ID (a long random string), stores it in a cookie named `tina4_session` (`HttpOnly`, `SameSite=Lax`) on the user's browser, and creates a server-side storage entry keyed by that ID. On every subsequent request, the browser sends the cookie, Tina4 looks up the session data, and makes it available via `request.session`.

The flow looks like this:

1. Browser sends first request (no session cookie)
2. Tina4 generates session ID: `abc123def456`
3. Tina4 sets cookie: `tina4_session=abc123def456`
4. Tina4 creates empty session storage for `abc123def456`
5. Browser sends second request with cookie `tina4_session=abc123def456`
6. Tina4 loads session data for `abc123def456`
7. Your route handler reads and writes `request.session`
8. At the end of the request, Tina4 saves the updated session data

The session data is stored server-side. The browser only has the session ID -- it never sees the actual data.

---

## 3. The Session API

Access session data through `request.session`. It is available in every route handler with zero configuration.

### Full API Reference

| Method | Description |
|--------|-------------|
| `request.session.set(key, value)` | Store a value |
| `request.session.get(key, default)` | Retrieve a value (with optional default) |
| `request.session.delete(key)` | Remove a key |
| `request.session.has?(key)` | Check if a key exists |
| `request.session.clear` | Remove all session data |
| `request.session.destroy` | Destroy the session entirely |
| `request.session.save` | Persist session data (auto-called after response) |
| `request.session.regenerate` | Generate a new session ID, preserve data |
| `request.session.flash(key, value)` | Set flash data (one-time read) |
| `request.session.flash(key)` | Read and remove flash data |
| `request.session.all` | Get all session data as a hash |

---

## 4. File Sessions (Default)

Out of the box, Tina4 stores sessions in files. No configuration needed.

```ruby
Tina4::Router.get("/visit-counter") do |request, response|
  count = (request.session.get("visit_count", 0)) + 1
  request.session.set("visit_count", count)

  response.json({
    visit_count: count,
    message: "You have visited this page #{count} time#{count == 1 ? '' : 's'}"
  })
end
```

```bash
curl http://localhost:7147/visit-counter -c cookies.txt -b cookies.txt
```

```json
{"visit_count":1,"message":"You have visited this page 1 time"}
```

```bash
curl http://localhost:7147/visit-counter -c cookies.txt -b cookies.txt
```

```json
{"visit_count":2,"message":"You have visited this page 2 times"}
```

The `-c cookies.txt` flag tells curl to save cookies to a file, and `-b cookies.txt` tells it to send them back. This simulates how a browser works.

---

## 5. Redis Sessions

For production deployments with multiple servers (behind a load balancer), you need a shared session store. Redis is the most common choice.

```bash
TINA4_SESSION_BACKEND=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
TINA4_SESSION_PASSWORD=your-redis-password
```

That is the only change. Your code stays exactly the same. `request.session` works identically whether sessions are stored in files, Redis, MongoDB, or Valkey.

---

## 6. MongoDB Sessions

```bash
TINA4_SESSION_BACKEND=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017
TINA4_SESSION_DATABASE=myapp
TINA4_SESSION_COLLECTION=sessions
```

---

## 7. Valkey Sessions

```bash
TINA4_SESSION_BACKEND=valkey
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
```

---

## 8. Database Sessions

```bash
TINA4_SESSION_BACKEND=database
```

Stores sessions in the `tina4_session` table using your existing database connection (`DATABASE_URL`). The table is auto-created on first use. Works with all 5 database engines (SQLite, PostgreSQL, MySQL, MSSQL, Firebird).

---

## 9. Reading and Writing Session Data

Session data is a simple key-value store. You read and write it through `request.session`:

```ruby
# Write to session
Tina4::Router.post("/api/preferences") do |request, response|
  body = request.body

  request.session.set("language", body["language"] || "en")
  request.session.set("theme", body["theme"] || "light")
  request.session.set("items_per_page", (body["items_per_page"] || 20).to_i)

  response.json({
    message: "Preferences saved",
    preferences: {
      language: request.session.get("language"),
      theme: request.session.get("theme"),
      items_per_page: request.session.get("items_per_page")
    }
  })
end

# Read from session
Tina4::Router.get("/api/preferences") do |request, response|
  response.json({
    language: request.session.get("language", "en"),
    theme: request.session.get("theme", "light"),
    items_per_page: request.session.get("items_per_page", 20)
  })
end

# Delete a specific key
Tina4::Router.delete("/api/preferences/{key}") do |request, response|
  key = request.params["key"]
  request.session.delete(key)

  response.json({ message: "Preference '#{key}' removed" })
end

# Clear all session data
Tina4::Router.post("/api/session/clear") do |request, response|
  request.session.clear

  response.json({ message: "Session cleared" })
end
```

### Storing Complex Data

Sessions can hold arrays and nested structures:

```ruby
Tina4::Router.post("/api/cart/add") do |request, response|
  body = request.body

  cart = request.session.get("cart", [])

  cart << {
    product_id: body["product_id"].to_i,
    name: body["name"],
    price: body["price"].to_f,
    quantity: (body["quantity"] || 1).to_i,
    added_at: Time.now.iso8601
  }

  request.session.set("cart", cart)

  total = cart.sum { |item| item[:price] * item[:quantity] }

  response.json({
    message: "Added to cart",
    cart_items: cart.length,
    cart_total: total
  })
end
```

---

## 10. Flash Messages

Flash messages are session data that lives for one request. Set a flash before redirecting. The next request reads it. Then it vanishes.

### Setting a Flash Message

```ruby
Tina4::Router.post("/profile/update") do |request, response|
  body = request.body

  # Update the profile (database logic here)

  request.session.flash("message", "Profile updated successfully")
  request.session.flash("message_type", "success")

  response.redirect("/profile")
end
```

### Reading and Clearing Flash Messages

```ruby
Tina4::Router.get("/profile") do |request, response|
  flash_message = request.session.flash("message")
  flash_type = request.session.flash("message_type") || "info"

  response.render("profile.html", {
    user: { name: "Alice", email: "alice@example.com" },
    flash_message: flash_message,
    flash_type: flash_type
  })
end
```

Calling `request.session.flash(key)` with only a key reads the value and removes it in one step.

### Using Flash Messages in Templates

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

---

## 11. Setting and Reading Cookies

Cookies are small pieces of data stored in the browser. Unlike sessions, the data is stored client-side.

### Setting a Cookie

```ruby
Tina4::Router.post("/api/set-language") do |request, response|
  language = request.body["language"] || "en"

  response.cookie("language", language, {
    expires: Time.now + (365 * 24 * 60 * 60),  # 1 year
    path: "/",
    http_only: false,
    secure: false,
    same_site: "Lax"
  })

  response.json({ message: "Language set to #{language}" })
end
```

### Reading a Cookie

```ruby
Tina4::Router.get("/api/get-language") do |request, response|
  language = request.cookies["language"] || "en"

  response.json({ language: language })
end
```

### Deleting a Cookie

```ruby
Tina4::Router.post("/api/clear-language") do |request, response|
  response.cookie("language", "", {
    expires: Time.now - 3600,
    path: "/"
  })

  response.json({ message: "Language cookie cleared" })
end
```

### When to Use Cookies vs Sessions

| Use Cookies For | Use Sessions For |
|-----------------|------------------|
| Language preference | Shopping cart contents |
| Theme preference (light/dark) | User authentication state |
| "Remember this device" flag | Flash messages |
| Analytics tracking consent | Form wizard progress |
| Non-sensitive, long-lived data | Sensitive, short-lived data |

---

## 12. Remember Me Functionality

The "remember me" pattern uses a long-lived cookie to re-authenticate users after their session expires.

```ruby
# @noauth
Tina4::Router.post("/login") do |request, response|
  body = request.body
  db = Tina4.database

  user = db.fetch_one(
    "SELECT id, name, email, password_hash FROM users WHERE email = ?",
    [body["email"]]
  )

  if user.nil? || !Tina4::Auth.check_password(body["password"], user["password_hash"])
    return response.json({ error: "Invalid email or password" }, 401)
  end

  request.session.set("user_id", user["id"])
  request.session.set("user_name", user["name"])

  if body["remember_me"]
    remember_token = SecureRandom.hex(32)

    db.execute(
      "UPDATE users SET remember_token = ? WHERE id = ?",
      [Digest::SHA256.hexdigest(remember_token), user["id"]]
    )

    response.cookie("remember_me", remember_token, {
      expires: Time.now + (30 * 24 * 60 * 60),  # 30 days
      path: "/",
      http_only: true,
      secure: true,
      same_site: "Lax"
    })
  end

  response.json({
    message: "Login successful",
    user: { id: user["id"], name: user["name"] }
  })
end
```

---

## 13. Session Security

### Configuration Options

```bash
TINA4_SESSION_TTL=3600
TINA4_SESSION_SAMESITE=Lax
```

`TINA4_SESSION_SAMESITE` controls cross-site cookie behavior:

| Value | Behavior |
|-------|----------|
| `Strict` | Never sent with cross-site requests. Safest. Breaks some flows (clicking links from email). |
| `Lax` | Sent with top-level navigations (clicking links) but not cross-site API calls. Good default. |
| `None` | Always sent. Requires `TINA4_SESSION_SECURE=true`. Only for cross-site cookie access. |

### Session Regeneration

After a user logs in, regenerate the session ID to prevent session fixation attacks:

```ruby
Tina4::Router.post("/login") do |request, response|
  # Validate credentials...

  request.session.regenerate

  request.session.set("user_id", user["id"])

  response.redirect("/dashboard")
end
```

### Destroy a Session

To completely destroy a session (not just clear its data):

```ruby
Tina4::Router.post("/logout") do |request, response|
  request.session.destroy
  response.redirect("/login")
end
```

---

## 14. Exercise: Build a Shopping Cart with Session Storage

Build a shopping cart that stores items in the session. No database needed -- the cart lives entirely in session data.

### Requirements

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/cart/add` | Add an item to the cart. Body: `{"product_id": 1, "name": "Widget", "price": 9.99, "quantity": 2}` |
| `GET` | `/api/cart` | View the cart. Show items, quantities, item subtotals, and cart total. |
| `PUT` | `/api/cart/{product_id:int}` | Update quantity. Body: `{"quantity": 3}`. Remove item if quantity is 0. |
| `DELETE` | `/api/cart/{product_id:int}` | Remove an item from the cart. |
| `DELETE` | `/api/cart` | Clear the entire cart. |

### Business Rules

1. If adding a product that already exists in the cart, increment the quantity instead of adding a duplicate
2. Cart total should be calculated dynamically
3. Return the full cart state after every operation

### Test with:

```bash
# Add first item
curl -X POST http://localhost:7147/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "name": "Wireless Keyboard", "price": 79.99, "quantity": 1}' \
  -c cookies.txt -b cookies.txt

# Add second item
curl -X POST http://localhost:7147/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{"product_id": 2, "name": "USB-C Hub", "price": 49.99, "quantity": 2}' \
  -c cookies.txt -b cookies.txt

# View cart
curl http://localhost:7147/api/cart -b cookies.txt

# Clear cart
curl -X DELETE http://localhost:7147/api/cart -b cookies.txt -c cookies.txt
```

---

## 15. Solution

Create `src/routes/cart.rb`:

```ruby
def get_cart(session)
  session.get("cart", [])
end

def cart_response(cart)
  total = 0.0
  item_count = 0
  items = []

  cart.each do |item|
    subtotal = item[:price] * item[:quantity]
    total += subtotal
    item_count += item[:quantity]
    items << item.merge(subtotal: subtotal)
  end

  {
    items: items,
    item_count: item_count,
    unique_items: cart.length,
    total: total.round(2)
  }
end

# Add item to cart
Tina4::Router.post("/api/cart/add") do |request, response|
  body = request.body

  if body["product_id"].nil? || body["name"].nil? || body["price"].nil?
    return response.json({ error: "product_id, name, and price are required" }, 400)
  end

  cart = get_cart(request.session)
  product_id = body["product_id"].to_i
  quantity = (body["quantity"] || 1).to_i

  existing = cart.find { |item| item[:product_id] == product_id }

  if existing
    existing[:quantity] += quantity
  else
    cart << {
      product_id: product_id,
      name: body["name"],
      price: body["price"].to_f,
      quantity: quantity
    }
  end

  request.session.set("cart", cart)

  response.json(cart_response(cart))
end

# View cart
Tina4::Router.get("/api/cart") do |request, response|
  cart = get_cart(request.session)
  response.json(cart_response(cart))
end

# Update quantity
Tina4::Router.put("/api/cart/{product_id:int}") do |request, response|
  product_id = request.params["product_id"]
  quantity = (request.body["quantity"] || 0).to_i
  cart = get_cart(request.session)

  index = cart.index { |item| item[:product_id] == product_id }

  if index.nil?
    return response.json({ error: "Product not in cart" }, 404)
  end

  if quantity <= 0
    cart.delete_at(index)
  else
    cart[index][:quantity] = quantity
  end

  request.session.set("cart", cart)

  response.json(cart_response(cart))
end

# Remove item
Tina4::Router.delete("/api/cart/{product_id:int}") do |request, response|
  product_id = request.params["product_id"]
  cart = get_cart(request.session)

  index = cart.index { |item| item[:product_id] == product_id }

  if index.nil?
    return response.json({ error: "Product not in cart" }, 404)
  end

  cart.delete_at(index)
  request.session.set("cart", cart)

  response.json(cart_response(cart))
end

# Clear cart
Tina4::Router.delete("/api/cart") do |request, response|
  request.session.set("cart", [])

  response.json(cart_response([]))
end
```

**Expected output after adding two items:**

```json
{
  "items": [
    {"product_id": 1, "name": "Wireless Keyboard", "price": 79.99, "quantity": 1, "subtotal": 79.99},
    {"product_id": 2, "name": "USB-C Hub", "price": 49.99, "quantity": 2, "subtotal": 99.98}
  ],
  "item_count": 3,
  "unique_items": 2,
  "total": 179.97
}
```

---

## 16. Gotchas

### 1. Sessions Do Not Work with curl Without Cookie Flags

**Problem:** Each curl request sees an empty session, as if it is a new user.

**Cause:** curl does not automatically save or send cookies.

**Fix:** Use `-c cookies.txt -b cookies.txt` with curl.

### 2. Session Data Disappears After Server Restart

**Problem:** All session data is gone after restarting the dev server.

**Cause:** File sessions stored in the system temp directory may be cleared on restart.

**Fix:** Set `TINA4_SESSION_PATH` to a persistent directory. For production, use Redis or Valkey.

### 3. Session Cookie Not Sent Over HTTP in Production

**Problem:** Sessions work locally but not in production.

**Cause:** `TINA4_SESSION_SECURE=true` means the cookie is only sent over HTTPS.

**Fix:** Ensure your reverse proxy sets `X-Forwarded-Proto: https`, or set `TINA4_SESSION_SECURE=false` for HTTP.

### 4. Flash Messages Show Twice

**Problem:** The flash message appears, then appears again on the next page load.

**Cause:** You read the flash message but did not clear it from the session.

**Fix:** Use `request.session.flash("message")` to read flash data. It reads and deletes in one step. Do not use `request.session.get()` for flash messages.

### 5. Large Session Data Causes Slow Requests

**Problem:** Pages load slowly and performance degrades over time.

**Cause:** You are storing large amounts of data in the session.

**Fix:** Keep session data small. Store IDs and references, not entire objects.

### 6. Remember Me Token Not Invalidated on Password Change

**Problem:** After a user changes their password, their "remember me" cookies on other devices still work.

**Cause:** The remember-me token in the database was not cleared when the password changed.

**Fix:** Clear the `remember_token` column whenever the password is updated.

### 7. Session Fixation

**Problem:** An attacker can hijack a user's session by setting a known session ID before the user logs in.

**Cause:** The session ID is not regenerated after login.

**Fix:** Call `request.session.regenerate` after successful login.
