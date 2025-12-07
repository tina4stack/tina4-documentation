# Posting Forms

If you're used to posting forms in the traditional manner to the web service, pay attention to the following:

* All `POST`, `PUT`, `PATCH`, and `DELETE` requests are **secured by default**
* You **must** pass a `formToken` input value to be validated (CSRF protection)

Tina4 Python makes this **simple and automatic** — no manual validation required in your routes.

::: tip Secure by Default
Tina4 generates a unique, signed token per session and validates it on every write request.  
Invalid tokens return a `403 Forbidden` automatically.
:::

## 1. Basic Form Handling

### Route Setup

```python
from tina4_python import get, post

@get("/contact")
async def contact_form(request, response):
    return response.render("contact.twig")

@post("/contact")
async def submit_contact(request, response):
    # Token already validated → proceed safely!
    name = request.body.get("name", "")
    email = request.body.get("email", "")
    message = request.body.get("message", "")

    # Process: save to DB, send email, etc.
    # await send_email(email, message)

    return response.redirect("/thanks?success=true")
```

### Template (Twig/Jinja)

```twig
<!-- templates/contact.twig -->
<form method="POST" action="/contact">
    {{ form_token() }}  <!-- Auto-generates <input name="formToken" value="..."> -->
    <div>
        <label for="name">Name</label>
        <input type="text" id="name" name="name" placeholder="Your name" required>
    </div>
    <div>
        <label for="email">Email</label>
        <input type="email" id="email" name="email" placeholder="your@email.com" required>
    </div>
    <div>
        <label for="message">Message</label>
        <textarea id="message" name="message" rows="5" required></textarea>
    </div>
    <button type="submit">Send Message</button>
</form>
```

## 2. Generating Form Tokens: Three Ways

There are **three ways** to get a `formToken` in Tina4 Python (aligned with PHP for consistency):

### A. Using the Global Function `form_token()`

Pass optional context for better security (e.g., page-specific tokens).

```twig
<!-- templates/login.twig -->
<form name="login" method="POST" action="/login">
    <input type="text" name="username" placeholder="Username" required>
    
    {% set token = form_token({"page": "Login"}) %}
    <input type="hidden" name="formToken" value="{{ token }}">
    
    <button type="submit">Login</button>
</form>
```

### B. Using the Filter `| form_token`

Append `~RANDOM()` to refresh the token on each render (prevents replay attacks).

```twig
<!-- templates/register.twig -->
<form name="register" method="POST" action="/register">
    <input type="password" name="password" placeholder="Password" required>
    
    {{ ("Register" ~ RANDOM()) | form_token }}
    <!-- Outputs: <input type="hidden" name="formToken" value="fresh_token_here"> -->
    
    <button type="submit">Register</button>
</form>
```

### C. From Response Headers (`FreshToken`)

For AJAX or meta tags — grab from the `X-Fresh-Token` header.

```twig
<!-- In your base layout -->
<meta name="fresh-token" content="{{ request.headers.get('FreshToken', '') }}">
```

```javascript
// In JS
const token = document.querySelector('meta[name="fresh-token"]').content;
fetch('/api/save', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer '+ token },
    body: JSON.stringify({ data: 'value' })
});
```

## 3. File Uploads with Forms

Add `enctype="multipart/form-data"` and handle via `request.files`.

```twig
<form method="POST" action="/upload" enctype="multipart/form-data">
    {{ form_token() }}
    
    <input type="file" name="avatar" accept="image/*" multiple>
    <button type="submit">Upload Files</button>
</form>
```

```python
@post("/upload")
async def handle_upload(request, response):
    files = request.files.getlist("avatar")  # List for multiple
    for file in files:
        await file.save(f"public/uploads/{file.filename}")
    
    return response("Files uploaded!")
```

## 4. Validation & Error Handling

Return errors and old input on failure.

```python
@post("/register")
async def register_user(request, response):
    errors = {}
    data = request.body

    if not data.get("email"):
        errors["email"] = "Email is required"

    if len(data.get("password", "")) < 8:
        errors["password"] = "Password must be at least 8 characters"

    if errors:
        return response.render("register.twig", {
            "errors": errors,
            "old": data  # Repopulate form
        })

    # Success
    return response.redirect("/dashboard")
```

In Twig:

```twig
<input type="email" name="email" value="{{ old.email|e if old else '' }}" required>
{% if errors.email %}
    <span class="error">{{ errors.email }}</span>
{% endif %}
```

## 5. Disabling Protection (`@noauth()`)

**Rarely needed** — only for public webhooks.

```python
@post("/webhook/payment")
@noauth()  # Skips token validation
async def payment_webhook(request, response):
    payload = request.body
    # Process without token
    return response("Received")
```

::: warning Security Warning
Use `@noauth()` **only** for non-user endpoints like webhooks.  
Never on login/register forms!
:::

## Example: Full Login Flow

### Route

```python
@get("/login")
async def login_page(request, response):
    return response.render("login.twig")

@post("/login")
async def process_login(request, response):
    username = request.body["username"]
    password = request.body["password"]
    
    if await validate_user(username, password):
        request.session["user"] = username
        return response.redirect("/dashboard")
    
    return response.render("login.twig", {"error": "Invalid credentials"})
```

### Template

```twig
<form method="POST" action="/login">
    {{ form_token() }}
    
    {% if error %}
        <p class="error">{{ error }}</p>
    {% endif %}
    
    <input type="text" name="username" value="{{ old.username|e if old else '' }}" required>
    <input type="password" name="password" required>
    
    <button>Login</button>
</form>
```

## Hot Tips

::: tip Form Best Practices
- Append `~RANDOM()` to filters for dynamic tokens
- Redirect after successful POST (Post/Redirect/Get pattern)
- Use `request.body` for form data, `request.params` for query
- `@noauth()` only for trusted public endpoints
- Tokens auto-refresh via `FreshToken` header
  :::


