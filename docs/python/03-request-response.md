# Chapter 3: Request and Response

## 1. The Two Objects You Use Everywhere

Every route handler receives two arguments: `request` and `response`. The request carries everything the client sent. The response builds what you send back. Master these two objects and you handle any HTTP scenario.

Picture a file-sharing service. A user uploads a document. You validate the file type. You check their session. You return a success JSON or an error page. Every step flows through `request` and `response`.

---

## 2. The Request Object

The `request` object gives you access to every piece of information about the incoming HTTP request.

### request.method

The HTTP method as an uppercase string:

```python
from tina4_python.core.router import get, post

@get("/api/check")
async def check_method(request, response):
    return response.json({"method": request.method})
```

```bash
curl http://localhost:7145/api/check
```

```json
{"method":"GET"}
```

### request.path

The URL path without query parameters:

```python
@get("/api/info")
async def info(request, response):
    return response.json({"path": request.path})
```

```bash
curl "http://localhost:7145/api/info?foo=bar"
```

```json
{"path":"/api/info"}
```

### Path Parameters (Function Arguments)

Path parameters captured from the URL pattern are passed as function arguments. The parameter names in your function signature must match the `{name}` placeholders in the route pattern:

```python
@get("/users/{id:int}/posts/{slug}")
async def user_post(id, slug, request, response):
    return response.json({
        "user_id": id,
        "slug": slug
    })
```

```bash
curl http://localhost:7145/users/5/posts/hello-world
```

```json
{"user_id":5,"slug":"hello-world"}
```

### request.query

Query string parameters as a dictionary:

```python
@get("/search")
async def search(request, response):
    return response.json({
        "q": request.query.get("q", ""),
        "page": int(request.query.get("page", 1)),
        "sort": request.query.get("sort", "relevance")
    })
```

```bash
curl "http://localhost:7145/search?q=laptop&page=2&sort=price"
```

```json
{"q":"laptop","page":2,"sort":"price"}
```

### request.body

The parsed request body. JSON requests become a dictionary. Form submissions contain form fields:

```python
@post("/api/feedback")
async def feedback(request, response):
    name = request.body.get("name", "Anonymous")
    message = request.body.get("message", "")
    rating = request.body.get("rating", 0)

    return response.json({
        "received": {
            "name": name,
            "message": message,
            "rating": rating
        }
    }, 201)
```

```bash
curl -X POST http://localhost:7145/api/feedback \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "message": "Great product!", "rating": 5}'
```

```json
{"received":{"name":"Alice","message":"Great product!","rating":5}}
```

### request.headers

A dictionary of HTTP headers. Header names are case-insensitive:

```python
@get("/api/headers")
async def show_headers(request, response):
    return response.json({
        "content_type": request.headers.get("Content-Type", "not set"),
        "user_agent": request.headers.get("User-Agent", "not set"),
        "accept": request.headers.get("Accept", "not set"),
        "custom": request.headers.get("X-Custom-Header", "not set")
    })
```

```bash
curl http://localhost:7145/api/headers -H "X-Custom-Header: hello-tina4"
```

```json
{"content_type":"not set","user_agent":"curl/8.1.2","accept":"*/*","custom":"hello-tina4"}
```

### request.ip

The client's IP address:

```python
@get("/api/whoami")
async def whoami(request, response):
    return response.json({"ip": request.ip})
```

```bash
curl http://localhost:7145/api/whoami
```

```json
{"ip":"127.0.0.1"}
```

### request.cookies

A dictionary of cookies sent by the client:

```python
@get("/api/cookies")
async def show_cookies(request, response):
    return response.json({
        "cookies": request.cookies,
        "session_id": request.cookies.get("session_id", "none")
    })
```

```bash
curl http://localhost:7145/api/cookies -b "session_id=abc123; theme=dark"
```

```json
{"cookies":{"session_id":"abc123","theme":"dark"},"session_id":"abc123"}
```

### request.files

For multipart file uploads, `request.files` holds the uploaded files:

```python
@post("/api/upload")
async def upload(request, response):
    if "document" not in request.files:
        return response.json({"error": "No file uploaded"}, 400)

    file = request.files["document"]

    return response.json({
        "filename": file.filename,
        "content_type": file.content_type,
        "size": len(file.content)
    })
```

```bash
curl -X POST http://localhost:7145/api/upload \
  -F "document=@report.pdf"
```

```json
{"filename":"report.pdf","content_type":"application/pdf","size":45231}
```

To save the file to disk:

```python
@post("/api/upload/save")
async def upload_and_save(request, response):
    if "photo" not in request.files:
        return response.json({"error": "No photo uploaded"}, 400)

    file = request.files["photo"]

    # Validate file type
    allowed = ["image/jpeg", "image/png", "image/webp"]
    if file.content_type not in allowed:
        return response.json({"error": f"File type {file.content_type} not allowed"}, 400)

    # Save to public directory
    import os
    save_path = os.path.join("src", "public", "images", file.filename)
    with open(save_path, "wb") as f:
        f.write(file.content)

    return response.json({
        "message": "Photo uploaded",
        "url": f"/images/{file.filename}"
    }, 201)
```

---

## 3. The Response Object

The `response` object builds HTTP responses. Every route handler must return one.

### response.json()

Return JSON data with an optional status code:

```python
@get("/api/users")
async def users(request, response):
    users = [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"}
    ]
    return response.json({"users": users, "count": len(users)})

@post("/api/users")
async def create_user(request, response):
    # 201 Created
    return response.json({"id": 3, "name": request.body["name"]}, 201)

@get("/api/error")
async def error_example(request, response):
    # 400 Bad Request
    return response.json({"error": "Something went wrong"}, 400)
```

### response.html()

Return raw HTML:

```python
@get("/welcome")
async def welcome(request, response):
    return response.html("""
        <!DOCTYPE html>
        <html>
        <body>
            <h1>Welcome to My Store</h1>
            <p>Browse our <a href="/products">products</a>.</p>
        </body>
        </html>
    """)
```

### response.text()

Return plain text:

```python
@get("/robots.txt")
async def robots(request, response):
    return response.text("User-agent: *\nAllow: /")
```

### response.render()

Render a Frond template with data ([Chapter 4: Templates](04-templates.md) goes deep):

```python
@get("/dashboard")
async def dashboard(request, response):
    return response.render("dashboard.html", {
        "user_name": "Alice",
        "notifications": 3,
        "recent_orders": [
            {"id": 101, "total": 59.99},
            {"id": 102, "total": 124.50}
        ]
    })
```

### response.redirect()

Redirect the client to another URL:

```python
@get("/old-page")
async def old_page(request, response):
    return response.redirect("/new-page")

@post("/api/logout")
async def logout(request, response):
    # 303 See Other -- redirect after POST
    return response.redirect("/login", 303)

@get("/moved")
async def moved(request, response):
    # 301 Permanent redirect
    return response.redirect("/new-location", 301)
```

The default status code for `redirect()` is `302 Found` (temporary redirect).

### response.file()

Send a file as the response:

```python
@get("/download/report")
async def download_report(request, response):
    return response.file("data/reports/monthly-report.pdf")
```

Tina4 auto-detects the content type from the file extension. The browser displays or downloads the file based on content type.

To force a download (instead of inline display):

```python
@get("/download/data")
async def download_data(request, response):
    return response.file("data/export.csv", download=True, filename="sales-data.csv")
```

### Setting Status Codes

Every response method accepts an optional status code as the second argument:

```python
# 200 OK (default)
return response.json({"ok": True})

# 201 Created
return response.json({"id": 1}, 201)

# 204 No Content
return response.json(None, 204)

# 400 Bad Request
return response.json({"error": "Invalid input"}, 400)

# 401 Unauthorized
return response.json({"error": "Login required"}, 401)

# 403 Forbidden
return response.json({"error": "Not allowed"}, 403)

# 404 Not Found
return response.json({"error": "Not found"}, 404)

# 500 Internal Server Error
return response.json({"error": "Server error"}, 500)
```

### Setting Response Headers

Add custom headers:

```python
@get("/api/data")
async def data_with_headers(request, response):
    return response.header("X-Custom-Header", "my-value") \
                   .header("X-Request-Id", "abc-123") \
                   .json({"data": [1, 2, 3]})
```

```bash
curl -i http://localhost:7145/api/data
```

```
HTTP/1.1 200 OK
Content-Type: application/json
X-Custom-Header: my-value
X-Request-Id: abc-123

{"data":[1,2,3]}
```

### Setting Cookies

Set cookies on the response:

```python
@post("/api/login")
async def login(request, response):
    # Set a session cookie
    return response.cookie("session_id", "abc123", {
        "httponly": True,
        "secure": True,
        "max_age": 3600,
        "path": "/"
    }).json({"message": "Logged in"})

@post("/api/logout")
async def logout(request, response):
    # Delete a cookie by setting max_age to 0
    return response.cookie("session_id", "", {
        "max_age": 0,
        "path": "/"
    }).json({"message": "Logged out"})
```

Cookie options:

| Option | Type | Description |
|--------|------|-------------|
| `httponly` | bool | Cookie not accessible via JavaScript |
| `secure` | bool | Cookie only sent over HTTPS |
| `max_age` | int | Lifetime in seconds (0 = delete) |
| `path` | string | URL path scope |
| `domain` | string | Domain scope |
| `samesite` | string | "Strict", "Lax", or "None" |

---

## 4. Input Validation

Tina4 includes a `Validator` class for declarative input validation. Chain rules together and check the result. If validation fails, use `response.error()` to return a structured error envelope.

### The Validator Class

```python
from tina4_python.validator import Validator

@post("/api/users")
async def create_user(request, response):
    v = Validator(request.body)
    v.required("name").required("email").email("email").min_length("name", 2)

    if not v.is_valid():
        return response.error("VALIDATION_FAILED", v.errors()[0]["message"], 400)

    # proceed with valid data
```

The `Validator` accepts the request body (a dictionary) and provides chainable methods:

| Method | Description |
|--------|-------------|
| `required(field)` | Field must be present and non-empty |
| `email(field)` | Field must be a valid email address |
| `min_length(field, n)` | Field must have at least `n` characters |
| `max_length(field, n)` | Field must have at most `n` characters |
| `numeric(field)` | Field must be a number |
| `in_list(field, values)` | Field must be one of the allowed values |

Call `v.is_valid()` to check all rules. Call `v.errors()` to get the list of validation failures, each with a `field` and `message` key.

### The Error Response Envelope

`response.error()` returns a consistent JSON error envelope:

```python
return response.error("VALIDATION_FAILED", "Name is required", 400)
```

This produces:

```json
{"error": true, "code": "VALIDATION_FAILED", "message": "Name is required", "status": 400}
```

The three arguments are: an error code string, a human-readable message, and the HTTP status code. Use this pattern across your API for consistent error handling. Clients can check `error: true` and switch on the `code` field.

---

## 5. Real-World Example: File Upload with Validation

A complete file upload endpoint that validates type, size, and returns appropriate errors:

```python
from tina4_python.core.router import post
import os
import uuid

UPLOAD_DIR = "src/public/uploads"
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "application/pdf": ".pdf"
}

@post("/api/files/upload")
async def upload_file(request, response):
    if "file" not in request.files:
        return response.json({"error": "No file provided. Send a file with field name 'file'"}, 400)

    file = request.files["file"]

    # Check file type
    if file.content_type not in ALLOWED_TYPES:
        return response.json({
            "error": f"File type '{file.content_type}' not allowed",
            "allowed": list(ALLOWED_TYPES.keys())
        }, 400)

    # Check file size
    if len(file.content) > MAX_FILE_SIZE:
        return response.json({
            "error": f"File too large. Maximum size is {MAX_FILE_SIZE // (1024 * 1024)} MB",
            "size": len(file.content)
        }, 400)

    # Generate a unique filename
    ext = ALLOWED_TYPES[file.content_type]
    unique_name = f"{uuid.uuid4().hex}{ext}"

    # Save the file
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    save_path = os.path.join(UPLOAD_DIR, unique_name)
    with open(save_path, "wb") as f:
        f.write(file.content)

    return response.json({
        "message": "File uploaded successfully",
        "file": {
            "original_name": file.filename,
            "saved_as": unique_name,
            "url": f"/uploads/{unique_name}",
            "size": len(file.content),
            "content_type": file.content_type
        }
    }, 201)
```

```bash
curl -X POST http://localhost:7145/api/files/upload \
  -F "file=@photo.jpg"
```

```json
{
  "message": "File uploaded successfully",
  "file": {
    "original_name": "photo.jpg",
    "saved_as": "a1b2c3d4e5f6.jpg",
    "url": "/uploads/a1b2c3d4e5f6.jpg",
    "size": 245760,
    "content_type": "image/jpeg"
  }
}
```

---

## 6. Exercise: Build a Contact Form API

Build an API that processes contact form submissions with full validation.

### Requirements

Create `src/routes/contact.py` with these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/contact` | Submit a contact form. Validate all fields. Return 201 on success. |
| `GET` | `/api/contact/submissions` | List all submissions. Support `?status=` filter. |

The contact form body should include: `name` (required, 2-100 chars), `email` (required, must contain @), `subject` (required), `message` (required, 10+ chars), `urgency` (optional, one of "low", "medium", "high", default "medium").

Validation rules:
- Return 400 with an `errors` list if any field is invalid
- Store submissions in a Python list with an auto-incremented ID and timestamp
- Each submission has a `status` of "new"

### Test with:

```bash
# Valid submission
curl -X POST http://localhost:7145/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "subject": "Question", "message": "I have a question about your product pricing.", "urgency": "high"}'

# Invalid submission (missing fields, short message)
curl -X POST http://localhost:7145/api/contact \
  -H "Content-Type: application/json" \
  -d '{"name": "A", "email": "bad-email", "message": "Short"}'

# List all
curl http://localhost:7145/api/contact/submissions

# Filter by status
curl "http://localhost:7145/api/contact/submissions?status=new"
```

---

## 7. Solution

```python
from tina4_python.core.router import get, post
from datetime import datetime

submissions = []
next_id = 1


@post("/api/contact")
async def submit_contact(request, response):
    global next_id
    body = request.body
    errors = []

    # Validate name
    name = body.get("name", "")
    if not name:
        errors.append("Name is required")
    elif len(name) < 2 or len(name) > 100:
        errors.append("Name must be between 2 and 100 characters")

    # Validate email
    email = body.get("email", "")
    if not email:
        errors.append("Email is required")
    elif "@" not in email:
        errors.append("Email must contain @")

    # Validate subject
    subject = body.get("subject", "")
    if not subject:
        errors.append("Subject is required")

    # Validate message
    message = body.get("message", "")
    if not message:
        errors.append("Message is required")
    elif len(message) < 10:
        errors.append("Message must be at least 10 characters")

    # Validate urgency
    urgency = body.get("urgency", "medium")
    if urgency not in ("low", "medium", "high"):
        errors.append("Urgency must be one of: low, medium, high")

    if errors:
        return response.json({"errors": errors}, 400)

    submission = {
        "id": next_id,
        "name": name,
        "email": email,
        "subject": subject,
        "message": message,
        "urgency": urgency,
        "status": "new",
        "created_at": datetime.now().isoformat()
    }
    next_id += 1
    submissions.append(submission)

    return response.json({
        "message": "Contact form submitted successfully",
        "submission": submission
    }, 201)


@get("/api/contact/submissions")
async def list_submissions(request, response):
    status = request.query.get("status")

    if status:
        filtered = [s for s in submissions if s["status"] == status]
        return response.json({"submissions": filtered, "count": len(filtered)})

    return response.json({"submissions": submissions, "count": len(submissions)})
```

**Valid submission output:**

```json
{
  "message": "Contact form submitted successfully",
  "submission": {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com",
    "subject": "Question",
    "message": "I have a question about your product pricing.",
    "urgency": "high",
    "status": "new",
    "created_at": "2026-03-22T14:30:00.000000"
  }
}
```

(Status: `201 Created`)

**Invalid submission output:**

```json
{
  "errors": [
    "Name must be between 2 and 100 characters",
    "Email must contain @",
    "Subject is required",
    "Message must be at least 10 characters"
  ]
}
```

(Status: `400 Bad Request`)

---

## 8. Gotchas

### 1. request.body is None for GET requests

**Problem:** Accessing `request.body` in a GET handler returns `None` or an empty dict.

**Cause:** GET requests carry no body by convention. Browsers and curl do not send one.

**Fix:** Use `request.query` for GET parameters. The body is only populated for POST, PUT, and PATCH requests.

### 2. Forgetting to parse Content-Type

**Problem:** `request.body` is an empty dictionary even though you sent JSON.

**Cause:** You did not set `Content-Type: application/json` in your request. Without it, Tina4 does not parse the body as JSON.

**Fix:** Include `-H "Content-Type: application/json"` when sending JSON via curl. In JavaScript fetch, set `headers: {"Content-Type": "application/json"}`.

### 3. File upload with wrong field name

**Problem:** `request.files["photo"]` raises a `KeyError`.

**Cause:** The form field name does not match the key you look up.

**Fix:** Check that the form uses `<input type="file" name="photo">` and curl uses `-F "photo=@file.jpg"`. The string after `-F` must match the key in `request.files`.

### 4. response.redirect() in AJAX calls

**Problem:** Your JavaScript `fetch()` call gets a redirect response but the browser does not navigate.

**Cause:** `fetch()` follows redirects silently and returns the final response. It does not trigger browser navigation.

**Fix:** For AJAX calls, return a JSON response with the redirect URL and handle navigation in JavaScript: `window.location.href = data.redirect_url`. Use `response.redirect()` only for traditional form submissions and browser navigation.

### 5. Cookie not being set

**Problem:** You called `response.cookie()` but the cookie does not appear in the browser.

**Cause:** If you set `secure: True`, the cookie is only sent over HTTPS. On `http://localhost`, the browser ignores it.

**Fix:** During development on HTTP, set `"secure": False`. Enable `"secure": True` only in production where HTTPS is configured.

### 6. Large file uploads fail silently

**Problem:** Uploading a large file results in an empty `request.files` dictionary or a 413 error.

**Cause:** The default maximum upload size may be smaller than your file.

**Fix:** Set `TINA4_MAX_UPLOAD_SIZE` in your `.env` file (value in bytes). For 50 MB: `TINA4_MAX_UPLOAD_SIZE=52428800`.

### 7. Chaining response methods in wrong order

**Problem:** Setting headers or cookies after calling `response.json()` has no effect.

**Cause:** `response.json()` finalizes and returns the response. Anything after it is too late.

**Fix:** Chain headers and cookies before the final response method:

```python
# Correct
return response.header("X-Custom", "value").cookie("token", "abc").json({"ok": True})

# Wrong -- header is set after json() already returned
result = response.json({"ok": True})
response.header("X-Custom", "value")  # Too late
return result
```
