# Chapter 9: Sessions & Cookies

## 1. State in a Stateless World

Your e-commerce site needs a shopping cart that persists across page loads. A language preference that sticks. Flash messages after form submissions. But HTTP is stateless. Every request arrives with no memory of what came before. Sessions and cookies give the server a way to remember.

Chapter 7 introduced sessions for authentication. This chapter goes deeper. Session backends. Flash messages. Cookies. Remember-me tokens. Security configuration.

---

## 2. How Sessions Work

When a user visits your site for the first time, Tina4 generates a unique session ID (a long random string), stores it in a cookie on the user's browser, and creates a server-side storage entry keyed by that ID. On every subsequent request, the browser sends the cookie, Tina4 looks up the session data, and makes it available via `request.session`.

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

## 3. File Sessions (Default)

Out of the box, Tina4 stores sessions in files. No configuration needed.

```ruby
Tina4::Router.get("/visit-counter") do |request, response|
  count = (request.session["visit_count"] || 0) + 1
  request.session["visit_count"] = count

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

## 4. Redis Sessions

For production deployments with multiple servers (behind a load balancer), you need a shared session store. Redis is the most common choice.

```env
TINA4_SESSION_HANDLER=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=6379
TINA4_SESSION_PASSWORD=your-redis-password
```

That is the only change. Your code stays exactly the same. `request.session` works identically whether sessions are stored in files, Redis, MongoDB, or Valkey.

---

## 5. MongoDB Sessions

```env
TINA4_SESSION_HANDLER=mongodb
TINA4_SESSION_HOST=localhost
TINA4_SESSION_PORT=27017
TINA4_SESSION_DATABASE=myapp
TINA4_SESSION_COLLECTION=sessions
```

---

## 6. Valkey Sessions

```env
TINA4_SESSION_HANDLER=valkey
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

Session data is a simple key-value store. You read and write it through `request.session`:

```ruby
# Write to session
Tina4::Router.post("/api/preferences") do |request, response|
  body = request.body

  request.session["language"] = body["language"] || "en"
  request.session["theme"] = body["theme"] || "light"
  request.session["items_per_page"] = (body["items_per_page"] || 20).to_i

  response.json({
    message: "Preferences saved",
    preferences: {
      language: request.session["language"],
      theme: request.session["theme"],
      items_per_page: request.session["items_per_page"]
    }
  })
end

# Read from session
Tina4::Router.get("/api/preferences") do |request, response|
  response.json({
    language: request.session["language"] || "en",
    theme: request.session["theme"] || "light",
    items_per_page: request.session["items_per_page"] || 20
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

  request.session["cart"] ||= []

  cart = request.session["cart"]

  cart << {
    product_id: body["product_id"].to_i,
    name: body["name"],
    price: body["price"].to_f,
    quantity: (body["quantity"] || 1).to_i,
    added_at: Time.now.iso8601
  }

  request.session["cart"] = cart

  total = cart.sum { |item| item[:price] * item[:quantity] }

  response.json({
    message: "Added to cart",
    cart_items: cart.length,
    cart_total: total
  })
end
```

---

## 8. Flash Messages

Flash messages are session data that lives for one request. Set a flash before redirecting. The next request reads it. Then it vanishes.

### Setting a Flash Message

```ruby
Tina4::Router.post("/profile/update") do |request, response|
  body = request.body

  # Update the profile (database logic here)

  request.session["_flash"] = {
    type: "success",
    message: "Profile updated successfully"
  }

  response.redirect("/profile")
end
```

### Reading and Clearing Flash Messages

```ruby
Tina4::Router.get("/profile") do |request, response|
  flash = request.session["_flash"]
  request.session.delete("_flash")

  response.render("profile.html", {
    user: { name: "Alice", email: "alice@example.com" },
    flash: flash
  })
end
```

### Using Flash Messages in Templates

```html
{% extends "base.html" %}

{% block content %}
    {% if flash %}
        <div class="alert alert-{{ flash.type }}">
            {{ flash.message }}
        </div>
    {% endif %}

    <h1>Profile</h1>
    <p>Name: {{ user.name }}</p>
    <p>Email: {{ user.email }}</p>
{% endblock %}
```

---

## 9. Setting and Reading Cookies

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

## 10. Remember Me Functionality

The "remember me" pattern uses a long-lived cookie to re-authenticate users after their session expires.

```ruby
# @noauth
Tina4::Router.post("/login") do |request, response|
  body = request.body
  db = Tina4::Database.connection

  user = db.fetch_one(
    "SELECT id, name, email, password_hash FROM users WHERE email = :email",
    { email: body["email"] }
  )

  if user.nil? || !Tina4::Auth.check_password(body["password"], user["password_hash"])
    return response.json({ error: "Invalid email or password" }, 401)
  end

  request.session["user_id"] = user["id"]
  request.session["user_name"] = user["name"]

  if body["remember_me"]
    remember_token = SecureRandom.hex(32)

    db.execute(
      "UPDATE users SET remember_token = :token WHERE id = :id",
      { token: Digest::SHA256.hexdigest(remember_token), id: user["id"] }
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

## 11. Session Security

### Configuration Options

```env
TINA4_SESSION_LIFETIME=3600
TINA4_SESSION_NAME=tina4_session
TINA4_SESSION_SECURE=true
TINA4_SESSION_HTTPONLY=true
TINA4_SESSION_SAMESITE=Lax
```

### Session Regeneration

After a user logs in, regenerate the session ID to prevent session fixation attacks:

```ruby
Tina4::Router.post("/login") do |request, response|
  # Validate credentials...

  request.session_regenerate

  request.session["user_id"] = user["id"]

  response.redirect("/dashboard")
end
```

---

## 12. Exercise: Build a Shopping Cart with Session Storage

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

## 13. Solution

Create `src/routes/cart.rb`:

```ruby
def get_cart(session)
  session["cart"] || []
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

  request.session["cart"] = cart

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

  request.session["cart"] = cart

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
  request.session["cart"] = cart

  response.json(cart_response(cart))
end

# Clear cart
Tina4::Router.delete("/api/cart") do |request, response|
  request.session["cart"] = []

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

## 14. Gotchas

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

**Fix:** Always clear the flash message immediately after reading it: `request.session.delete("_flash")`.

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

**Fix:** Call `request.session_regenerate` after successful login.
