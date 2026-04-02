# Chapter 3: Request and Response

## 1. The Two Objects You Use Everywhere

Every route handler receives two arguments: `request` and `response`. The request carries what the client sent. The response builds what you send back. These two objects handle every HTTP scenario you will face.

A file-sharing service demonstrates the pattern. A user uploads a document. You validate the file type. You check the session. You return success JSON or an error page. Every step flows through `request` and `response`.

---

## 2. The Request Object

The `request` object opens every piece of the incoming HTTP request. Headers, body, cookies, files, IP address -- all accessible through named properties.

### request.method

The HTTP method arrives as an uppercase string:

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

The URL path strips query parameters:

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

Path parameters captured from the URL pattern arrive as function arguments. The parameter names in your function signature must match the `{name}` placeholders in the route pattern:

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

### request.params

Query string parameters live in a dictionary. Each key holds a single value unless the same key appears multiple times -- then Tina4 stores a list:

```python
@get("/search")
async def search(request, response):
    return response.json({
        "q": request.params.get("q", ""),
        "page": int(request.params.get("page", 1)),
        "sort": request.params.get("sort", "relevance")
    })
```

```bash
curl "http://localhost:7145/search?q=laptop&page=2&sort=price"
```

```json
{"q":"laptop","page":2,"sort":"price"}
```

### request.body

The parsed request body. JSON requests become a dictionary. Form submissions contain form fields. GET requests produce `None`:

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

A dictionary of HTTP headers. Tina4 normalizes header names to lowercase:

```python
@get("/api/headers")
async def show_headers(request, response):
    return response.json({
        "content_type": request.headers.get("content-type", "not set"),
        "user_agent": request.headers.get("user-agent", "not set"),
        "accept": request.headers.get("accept", "not set"),
        "custom": request.headers.get("x-custom-header", "not set")
    })
```

```bash
curl http://localhost:7145/api/headers -H "X-Custom-Header: hello-tina4"
```

```json
{"content_type":"not set","user_agent":"curl/8.1.2","accept":"*/*","custom":"hello-tina4"}
```

### request.ip

The client's IP address. Tina4 respects `X-Forwarded-For` and `X-Real-IP` headers behind a reverse proxy:

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

A dictionary of cookies the client sent:

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

For multipart file uploads, `request.files` holds the uploaded files. Each file is a dictionary with four keys: `filename`, `type`, `content` (raw bytes), and `size` (in bytes):

```python
@post("/api/upload")
async def upload(request, response):
    if "document" not in request.files:
        return response.json({"error": "No file uploaded"}, 400)

    file = request.files["document"]

    return response.json({
        "filename": file["filename"],
        "content_type": file["type"],
        "size": file["size"]
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
    if file["type"] not in allowed:
        return response.json({"error": f"File type {file['type']} not allowed"}, 400)

    # Save to public directory
    import os
    save_path = os.path.join("src", "public", "images", file["filename"])
    with open(save_path, "wb") as f:
        f.write(file["content"])

    return response.json({
        "message": "Photo uploaded",
        "url": f"/images/{file['filename']}"
    }, 201)
```

### Handling Multiple File Uploads

When a form sends multiple files, each file field name maps to one entry in `request.files`. Use distinct field names for each file input:

```python
@post("/api/upload-many")
async def upload_many(request, response):
    results = []

    for key, file in request.files.items():
        if not isinstance(file, dict) or "filename" not in file:
            continue

        ext = os.path.splitext(file["filename"])[1]
        unique_name = f"{uuid.uuid4().hex}{ext}"
        save_path = os.path.join("src", "public", "uploads", unique_name)

        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        with open(save_path, "wb") as f:
            f.write(file["content"])

        results.append({
            "original_name": file["filename"],
            "saved_as": unique_name,
            "url": f"/uploads/{unique_name}"
        })

    if not results:
        return response.json({"error": "No files uploaded"}, 400)

    return response.json({"uploaded": results, "count": len(results)}, 201)
```

```bash
curl -X POST http://localhost:7145/api/upload-many \
  -F "photo=@sunset.jpg" \
  -F "document=@invoice.pdf" \
  -F "avatar=@profile.png"
```

```json
{
  "uploaded": [
    {"original_name": "sunset.jpg", "saved_as": "a1b2c3d4.jpg", "url": "/uploads/a1b2c3d4.jpg"},
    {"original_name": "invoice.pdf", "saved_as": "e5f6a7b8.pdf", "url": "/uploads/e5f6a7b8.pdf"},
    {"original_name": "profile.png", "saved_as": "c9d0e1f2.png", "url": "/uploads/c9d0e1f2.png"}
  ],
  "count": 3
}
```

The HTML form uses distinct `name` attributes for each file input. Each field name becomes a key in `request.files`.

### Upload Size Limits

Tina4 enforces a maximum upload size through the `TINA4_MAX_UPLOAD_SIZE` environment variable. The value is in bytes. The default is `10485760` (10 MB).

```env
TINA4_MAX_UPLOAD_SIZE=10485760
```

When a client sends a body larger than this limit, Tina4 raises a `PayloadTooLarge` exception and returns a `413 Payload Too Large` response. Your handler never runs. The check fires before body parsing begins.

To allow 50 MB uploads, set this in your `.env` file:

```env
TINA4_MAX_UPLOAD_SIZE=52428800
```

Calculate the value by multiplying: megabytes times 1,048,576. For 25 MB, that is `26214400`. For 100 MB, `104857600`. Choose the smallest limit that covers your use case. Large limits invite abuse.

---

## 3. The Response Object

The `response` object builds HTTP responses. Every route handler must return one. Methods chain, so you can set headers, cookies, and content in a single expression.

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

Render a Frond template with data ([Chapter 4: Templates](04-templates.md) covers the engine in full):

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

Send the client to another URL:

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

The default status code is `302 Found` (temporary redirect).

### response.file()

Send a file as the response:

```python
@get("/download/report")
async def download_report(request, response):
    return response.file("data/reports/monthly-report.pdf")
```

Tina4 auto-detects the content type from the file extension. The browser displays or downloads based on the MIME type.

To force a download instead of inline display, pass a `download_name`:

```python
@get("/download/data")
async def download_data(request, response):
    return response.file("data/export.csv", download_name="sales-data.csv")
```

This sets the `Content-Disposition: attachment` header with your chosen filename.

### response.xml()

Return XML content:

```python
@get("/api/feed")
async def feed(request, response):
    return response.xml("<feed><entry><title>Hello</title></entry></feed>")
```

### response.error()

Return a structured error envelope:

```python
@post("/api/things")
async def create_thing(request, response):
    return response.error("VALIDATION_FAILED", "Name is required", 400)
```

This produces:

```json
{"error":true,"code":"VALIDATION_FAILED","message":"Name is required","status":400}
```

Three arguments: an error code string, a human-readable message, and the HTTP status code. Clients check `error: true` and switch on the `code` field.

---

## 4. Status Codes

Every response method accepts a status code. Here are the codes you will use most:

| Code | Meaning | When to Use |
|------|---------|-------------|
| `200` | OK | Default. Successful GET, PUT, PATCH. |
| `201` | Created | Successful POST that created a resource. |
| `204` | No Content | Successful DELETE. No body needed. |
| `301` | Moved Permanently | URL has changed forever. |
| `302` | Found | Temporary redirect. |
| `400` | Bad Request | Invalid input from the client. |
| `401` | Unauthorized | Missing or invalid authentication. |
| `403` | Forbidden | Authenticated but not permitted. |
| `404` | Not Found | Resource does not exist. |
| `409` | Conflict | Duplicate or conflicting data. Two users claim the same username. |
| `413` | Payload Too Large | Body exceeds `TINA4_MAX_UPLOAD_SIZE`. |
| `422` | Unprocessable Entity | Valid JSON but fails business rules. The data parses but the logic rejects it. |
| `500` | Internal Server Error | Something broke on the server. |

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

# 409 Conflict
return response.json({"error": "Username already taken"}, 409)

# 422 Unprocessable Entity
return response.json({"error": "Start date must precede end date"}, 422)

# 500 Internal Server Error
return response.json({"error": "Server error"}, 500)
```

You can also chain the status with `response.status()`:

```python
return response.status(201).json({"id": 7, "created": True})
```

---

## 5. Content Negotiation

One endpoint can return different formats. The client declares what it wants through the `Accept` header. Your handler inspects that header and picks the right response method:

```python
@get("/api/products/{id:int}")
async def product_detail(id, request, response):
    product = {
        "id": id,
        "name": "Wireless Keyboard",
        "price": 79.99
    }

    accept = request.headers.get("accept", "application/json")

    if "text/html" in accept:
        return response.render("product-detail.html", {"product": product})
    elif "text/plain" in accept:
        text = f"Product #{id}: {product['name']} - ${product['price']}"
        return response.text(text)
    elif "application/xml" in accept:
        xml = f'<product><id>{id}</id><name>{product["name"]}</name><price>{product["price"]}</price></product>'
        return response.xml(xml)
    else:
        return response.json(product)
```

```bash
# JSON (default)
curl http://localhost:7145/api/products/1
```

```json
{"id":1,"name":"Wireless Keyboard","price":79.99}
```

```bash
# Plain text
curl http://localhost:7145/api/products/1 -H "Accept: text/plain"
```

```
Product #1: Wireless Keyboard - $79.99
```

```bash
# HTML (renders the template)
curl http://localhost:7145/api/products/1 -H "Accept: text/html"
```

```html
<!DOCTYPE html>
<html>...rendered template...</html>
```

The pattern: check `request.headers.get("accept")`, match against known MIME types, fall back to JSON. Most API clients send `application/json` or `*/*`. Browsers send `text/html`. The same route serves both.

---

## 6. Custom Headers and Cookies

### Setting Response Headers

Add custom headers with the `header` method. Chain calls before the final response:

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
    return response.cookie("session_id", "abc123",
        path="/",
        max_age=3600,
        http_only=True,
        secure=True,
        same_site="Lax"
    ).json({"message": "Logged in"})

@post("/api/logout")
async def logout(request, response):
    # Delete a cookie by setting max_age to 0
    return response.cookie("session_id", "",
        path="/",
        max_age=0
    ).json({"message": "Logged out"})
```

Cookie keyword arguments:

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `path` | str | `"/"` | URL path scope |
| `max_age` | int | `3600` | Lifetime in seconds (0 deletes the cookie) |
| `http_only` | bool | `True` | JavaScript cannot access the cookie |
| `secure` | bool | `False` | Cookie travels over HTTPS only |
| `same_site` | str | `"Lax"` | `"Strict"`, `"Lax"`, or `"None"` |

---

## 7. Input Validation

Tina4 ships a `Validator` class for declarative input validation. Chain rules together, then check the result.

### The Validator Class

```python
from tina4_python.validator import Validator

@post("/api/users")
async def create_user(request, response):
    v = Validator(request.body)
    v.required("name", "email").email("email").min_length("name", 2)

    if not v.is_valid():
        return response.error("VALIDATION_FAILED", v.errors()[0]["message"], 400)

    # proceed with valid data
```

The `Validator` accepts the request body (a dictionary) and provides chainable methods:

| Method | Description |
|--------|-------------|
| `required(*fields)` | Fields must be present and non-empty |
| `email(field)` | Field must be a valid email address |
| `min_length(field, n)` | Field must have at least `n` characters |
| `max_length(field, n)` | Field must have at most `n` characters |
| `integer(field)` | Field must be an integer |
| `min(field, n)` | Numeric field must be >= `n` |
| `max(field, n)` | Numeric field must be <= `n` |
| `in_list(field, values)` | Field must be one of the allowed values |
| `regex(field, pattern)` | Field must match the regular expression |

Call `v.is_valid()` to check all rules. Call `v.errors()` to get the list of validation failures -- each entry holds a `field` and `message` key.

Note that `required()` accepts multiple field names in one call: `v.required("name", "email", "subject")`. This validates all three fields in a single statement.

---

## 8. Real-World Example: File Upload with Validation

A complete file upload endpoint. It validates type and size, generates a unique filename, and returns the URL:

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
    if file["type"] not in ALLOWED_TYPES:
        return response.json({
            "error": f"File type '{file['type']}' not allowed",
            "allowed": list(ALLOWED_TYPES.keys())
        }, 400)

    # Check file size
    if file["size"] > MAX_FILE_SIZE:
        return response.json({
            "error": f"File too large. Maximum size is {MAX_FILE_SIZE // (1024 * 1024)} MB",
            "size": file["size"]
        }, 400)

    # Generate a unique filename
    ext = ALLOWED_TYPES[file["type"]]
    unique_name = f"{uuid.uuid4().hex}{ext}"

    # Save the file
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    save_path = os.path.join(UPLOAD_DIR, unique_name)
    with open(save_path, "wb") as f:
        f.write(file["content"])

    return response.json({
        "message": "File uploaded successfully",
        "file": {
            "original_name": file["filename"],
            "saved_as": unique_name,
            "url": f"/uploads/{unique_name}",
            "size": file["size"],
            "content_type": file["type"]
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

## 9. Exercise: Build a Contact Form API

Build an API that processes contact form submissions with full validation.

### Requirements

Create `src/routes/contact.py` with these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/contact` | Submit a contact form. Validate all fields. Return 201 on success. |
| `GET` | `/api/contact/submissions` | List all submissions. Support `?status=` filter. |

The contact form body must include: `name` (required, 2-100 chars), `email` (required, must contain @), `subject` (required), `message` (required, 10+ chars), `urgency` (optional, one of "low", "medium", "high", default "medium").

Validation rules:
- Return 400 with an `errors` list if any field fails
- Store submissions in a Python list with an auto-incremented ID and timestamp
- Each submission starts with a `status` of "new"

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

## 10. Solution

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
    status = request.params.get("status")

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

## 11. Gotchas

### 1. request.body is None for GET requests

**Problem:** Accessing `request.body` in a GET handler returns `None`.

**Cause:** GET requests carry no body. Browsers and curl send none by convention.

**Fix:** Use `request.params` for GET parameters. The body populates only for POST, PUT, and PATCH requests.

### 2. Forgetting the Content-Type header

**Problem:** `request.body` is empty even though you sent JSON.

**Cause:** The `Content-Type: application/json` header is missing. Without it, Tina4 does not parse the body as JSON.

**Fix:** Include `-H "Content-Type: application/json"` in your curl command. In JavaScript `fetch()`, set `headers: {"Content-Type": "application/json"}`.

### 3. File upload with wrong field name

**Problem:** `request.files["photo"]` raises a `KeyError`.

**Cause:** The form field name does not match the key you look up.

**Fix:** Check that the form uses `<input type="file" name="photo">` and curl uses `-F "photo=@file.jpg"`. The string after `-F` must match the key in `request.files`.

### 4. response.redirect() in AJAX calls

**Problem:** Your JavaScript `fetch()` call receives a redirect response, but the browser does not navigate.

**Cause:** `fetch()` follows redirects silently. It returns the final response. It does not trigger browser navigation.

**Fix:** For AJAX calls, return JSON with a redirect URL. Handle navigation in JavaScript: `window.location.href = data.redirect_url`. Use `response.redirect()` only for traditional form submissions and browser navigation.

### 5. Cookie not being set

**Problem:** You called `response.cookie()` but the cookie does not appear in the browser.

**Cause:** Setting `secure=True` restricts the cookie to HTTPS. On `http://localhost`, the browser drops it.

**Fix:** During development on HTTP, use `secure=False` (the default). Enable `secure=True` only in production with HTTPS configured.

### 6. Large file uploads fail

**Problem:** Uploading a large file returns a 413 error or empty `request.files`.

**Cause:** The file exceeds `TINA4_MAX_UPLOAD_SIZE`. The default limit is 10 MB (10,485,760 bytes).

**Fix:** Set `TINA4_MAX_UPLOAD_SIZE` in your `.env` file. For 50 MB: `TINA4_MAX_UPLOAD_SIZE=52428800`. The check happens before your handler runs -- there is nothing to catch in your route code.

### 7. Chaining response methods in wrong order

**Problem:** Headers or cookies set after calling `response.json()` have no effect.

**Cause:** `response.json()` finalizes and returns the response object. Calling methods on a separate line after the return is dead code.

**Fix:** Chain headers and cookies before the final response method:

```python
# Correct
return response.header("X-Custom", "value").cookie("token", "abc").json({"ok": True})

# Wrong -- header is set after json() already returned
result = response.json({"ok": True})
response.header("X-Custom", "value")  # Too late
return result
```

### 8. Header names are lowercase

**Problem:** `request.headers.get("Content-Type")` returns `None` even though the header exists.

**Cause:** Tina4 normalizes all header names to lowercase during parsing. The ASGI protocol delivers them this way.

**Fix:** Use lowercase keys: `request.headers.get("content-type")`. This applies to all headers -- `"authorization"`, `"user-agent"`, `"x-custom-header"`.
