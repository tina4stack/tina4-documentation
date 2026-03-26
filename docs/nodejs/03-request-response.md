# Chapter 3: Request & Response

## 1. The Two Objects You Always Get

Every route handler in Tina4 receives two arguments: `req` and `res`. The request tells you what the client sent. The response is how you talk back. Together they are the entire HTTP conversation.

```typescript
import { Router } from "tina4-nodejs";

Router.get("/echo", async (req, res) => {
    return res.json({
        method: req.method,
        path: req.path,
        your_ip: req.ip
    });
});
```

```bash
curl http://localhost:7148/echo
```

```json
{"method":"GET","path":"/echo","your_ip":"127.0.0.1"}
```

The pattern for every route: inspect the request, build the response, return it.

---

## 2. The Request Object

The `req` object gives you everything the client sent. Here is the complete inventory.

### method

The HTTP method as an uppercase string: `"GET"`, `"POST"`, `"PUT"`, `"PATCH"`, or `"DELETE"`.

```typescript
req.method // "GET"
```

### path

The URL path without query parameters:

```typescript
// Request to /api/users?page=2
req.path // "/api/users"
```

### params

Path parameters from the URL pattern (see Chapter 2):

```typescript
// Route: /users/{id}/posts/{postId}
// Request: /users/5/posts/42
req.params.id     // "5" (or 5 if typed as :id:int)
req.params.postId // "42"
```

### query

Query string parameters as an object:

```typescript
// Request: /search?q=keyboard&page=2&sort=price
req.query.q    // "keyboard"
req.query.page // "2"
req.query.sort // "price"
```

### body

The parsed request body. JSON requests produce an object. Form submissions contain form fields:

```typescript
// POST with {"name": "Widget", "price": 9.99}
req.body.name  // "Widget"
req.body.price // 9.99
```

### headers

Request headers as an object. Header names are normalized to lowercase:

```typescript
req.headers["content-type"]  // "application/json"
req.headers["authorization"] // "Bearer eyJhbGci..."
req.headers["x-custom"]      // "my-value"
```

### ip

The client's IP address:

```typescript
req.ip // "127.0.0.1"
```

Tina4 respects `X-Forwarded-For` and `X-Real-IP` headers when behind a reverse proxy.

### cookies

Cookies sent by the client:

```typescript
req.cookies.session_id  // "abc123"
req.cookies.preferences // "dark-mode"
```

### files

Uploaded files (covered in detail in section 7):

```typescript
req.files.avatar // File object with name, type, size, tmpPath
```

### Inspecting the Full Request

A route that dumps everything:

```typescript
import { Router } from "tina4-nodejs";

Router.post("/debug/request", async (req, res) => {
    return res.json({
        method: req.method,
        path: req.path,
        params: req.params,
        query: req.query,
        body: req.body,
        headers: req.headers,
        ip: req.ip,
        cookies: req.cookies
    });
});
```

```bash
curl -X POST "http://localhost:7148/debug/request?page=1" \
  -H "Content-Type: application/json" \
  -H "X-Custom: hello" \
  -d '{"name": "test"}'
```

```json
{
  "method": "POST",
  "path": "/debug/request",
  "params": {},
  "query": {"page": "1"},
  "body": {"name": "test"},
  "headers": {
    "content-type": "application/json",
    "x-custom": "hello",
    "host": "localhost:7148",
    "user-agent": "curl/8.4.0",
    "accept": "*/*",
    "content-length": "16"
  },
  "ip": "127.0.0.1",
  "cookies": {}
}
```

---

## 3. The Response Object

The `res` object is your toolkit for sending data back to the client. Every method returns the response, so you can chain calls.

### json() -- JSON Response

The workhorse for APIs. Pass any object or value and it becomes JSON:

```typescript
return res.json({ name: "Alice", age: 30 });
```

```json
{"name":"Alice","age":30}
```

Chain with `status()` for a custom status code:

```typescript
return res.status(201).json({ id: 7, name: "Widget" });
```

This returns `201 Created` with the JSON body.

### html() -- Template or Raw HTML Response

Render a Frond template with data ([Chapter 4: Templates](04-templates.md) goes deep):

```typescript
return res.html("products.html", {
    products,
    title: "Our Products"
});
```

Or return raw HTML:

```typescript
return res.html("<h1>Hello</h1><p>This is HTML.</p>");
```

Sets `Content-Type: text/html; charset=utf-8`.

### text() -- Plain Text Response

Return plain text:

```typescript
return res.text("Just a plain string.");
```

Sets `Content-Type: text/plain; charset=utf-8`.

### redirect() -- Redirect Response

Send the client to a different URL:

```typescript
return res.redirect("/login");
```

This sends a `302 Found` redirect by default. Pass a different status code for permanent redirects:

```typescript
return res.redirect("/new-location", 301);
```

### file() -- File Download Response

Send a file to the client for download:

```typescript
return res.file("/path/to/report.pdf");
```

Tina4 sets the appropriate `Content-Type` based on the file extension and adds a `Content-Disposition` header so the browser downloads the file.

Set a custom filename:

```typescript
return res.file("/path/to/report.pdf", "monthly-report-march-2026.pdf");
```

---

## 4. Status Codes

Every response method chains with `status()`. The most common ones:

| Code | Meaning | When to Use |
|------|---------|-------------|
| `200` | OK | Default. Successful GET, PUT, PATCH. |
| `201` | Created | Successful POST that created a resource. |
| `204` | No Content | Successful DELETE. No body needed. |
| `301` | Moved Permanently | URL has changed forever. |
| `302` | Found | Temporary redirect. |
| `400` | Bad Request | Invalid input from the client. |
| `401` | Unauthorized | Missing or invalid authentication. |
| `403` | Forbidden | Authenticated but not allowed. |
| `404` | Not Found | Resource does not exist. |
| `409` | Conflict | Duplicate or conflicting data. |
| `422` | Unprocessable Entity | Valid JSON but fails business rules. |
| `500` | Internal Server Error | Something broke on the server. |

```typescript
return res.status(201).json({ id: 7, created: true });
```

---

## 5. Custom Headers

Set response headers with the `header()` method:

```typescript
Router.get("/api/data", async (req, res) => {
    return res
        .header("X-Request-Id", crypto.randomUUID())
        .header("X-Rate-Limit-Remaining", "57")
        .header("Cache-Control", "no-cache")
        .json({ data: [1, 2, 3] });
});
```

### CORS Headers

Tina4 handles CORS based on the `CORS_ORIGINS` setting in `.env`. The default `*` allows all origins. For production, lock it down:

```env
CORS_ORIGINS=https://myapp.com,https://admin.myapp.com
```

---

## 6. Cookies

Set cookies on the response:

```typescript
Router.post("/login", async (req, res) => {
    return res
        .cookie("session_id", "abc123xyz", {
            httpOnly: true,
            secure: true,
            sameSite: "Strict",
            maxAge: 3600,
            path: "/"
        })
        .json({ message: "Logged in" });
});
```

Read cookies from the request:

```typescript
Router.get("/profile", async (req, res) => {
    const sessionId = req.cookies.session_id ?? null;

    if (sessionId === null) {
        return res.status(401).json({ error: "Not logged in" });
    }

    return res.json({ session: sessionId });
});
```

Delete a cookie by setting its `maxAge` to `0`:

```typescript
return res
    .cookie("session_id", "", { maxAge: 0, path: "/" })
    .json({ message: "Logged out" });
```

---

## 7. File Uploads

Uploaded files arrive via `req.files`. Each file is an object with metadata and a temporary path.

### Handling a Single File Upload

```typescript
import { Router } from "tina4-nodejs";

Router.post("/api/upload", async (req, res) => {
    if (!req.files?.image) {
        return res.status(400).json({ error: "No file uploaded" });
    }

    const file = req.files.image;

    return res.json({
        name: file.name,
        type: file.type,
        size: file.size,
        tmp_path: file.tmpPath
    });
});
```

```bash
curl -X POST http://localhost:7148/api/upload \
  -F "image=@/path/to/photo.jpg"
```

```json
{
  "name": "photo.jpg",
  "type": "image/jpeg",
  "size": 245760,
  "tmp_path": "/tmp/tina4_upload_abc123"
}
```

### Saving the Uploaded File

```typescript
import { Router } from "tina4-nodejs";
import { rename, mkdir } from "fs/promises";
import { existsSync } from "fs";
import { join, extname } from "path";
import { randomUUID } from "crypto";

Router.post("/api/upload", async (req, res) => {
    if (!req.files?.image) {
        return res.status(400).json({ error: "No file uploaded" });
    }

    const file = req.files.image;

    // Validate file type
    const allowedTypes = ["image/jpeg", "image/png", "image/gif", "image/webp"];
    if (!allowedTypes.includes(file.type)) {
        return res.status(400).json({ error: "Invalid file type. Allowed: JPEG, PNG, GIF, WebP" });
    }

    // Validate file size (max 5MB)
    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) {
        return res.status(400).json({ error: "File too large. Maximum size: 5MB" });
    }

    // Generate a unique filename
    const ext = extname(file.name);
    const filename = `img_${randomUUID()}${ext}`;
    const uploadDir = join(process.cwd(), "src/public/uploads");
    const destination = join(uploadDir, filename);

    if (!existsSync(uploadDir)) {
        await mkdir(uploadDir, { recursive: true });
    }

    await rename(file.tmpPath, destination);

    return res.status(201).json({
        message: "File uploaded successfully",
        filename,
        url: `/uploads/${filename}`,
        size: file.size
    });
});
```

---

## 8. File Downloads

Send files to the client using `res.file()`:

```typescript
import { Router } from "tina4-nodejs";
import { existsSync } from "fs";
import { join } from "path";

Router.get("/api/reports/{filename}", async (req, res) => {
    const filename = req.params.filename;
    const filepath = join(process.cwd(), "data/reports", filename);

    if (!existsSync(filepath)) {
        return res.status(404).json({ error: "Report not found" });
    }

    return res.file(filepath);
});
```

To force a specific download filename:

```typescript
return res.file(filepath, "Q1-2026-Sales-Report.pdf");
```

---

## 9. Content Negotiation

Check the `Accept` header to return different formats:

```typescript
import { Router } from "tina4-nodejs";

Router.get("/api/products/{id:int}", async (req, res) => {
    const id = req.params.id;
    const product = { id, name: "Wireless Keyboard", price: 79.99 };

    const accept = req.headers["accept"] ?? "application/json";

    if (accept.includes("text/html")) {
        return res.html("product-detail.html", { product });
    }

    if (accept.includes("text/plain")) {
        return res.text(`Product #${id}: ${product.name} - $${product.price}`);
    }

    return res.json(product);
});
```

---

## 10. Input Validation

Tina4 includes a `Validator` class for declarative input validation. Chain rules together and check the result. If validation fails, use `res.error()` to return a structured error envelope.

### The Validator Class

```typescript
import { Validator } from "tina4-nodejs";

Router.post("/api/users", (req, res) => {
    const v = new Validator(req.body);
    v.required("name").required("email").email("email").minLength("name", 2);

    if (!v.isValid()) {
        return res.error("VALIDATION_FAILED", v.errors()[0].message, 400);
    }

    // proceed with valid data
});
```

The `Validator` accepts the request body (an object) and provides chainable methods:

| Method | Description |
|--------|-------------|
| `required(field)` | Field must be present and non-empty |
| `email(field)` | Field must be a valid email address |
| `minLength(field, n)` | Field must have at least `n` characters |
| `maxLength(field, n)` | Field must have at most `n` characters |
| `numeric(field)` | Field must be a number |
| `inList(field, values)` | Field must be one of the allowed values |

Call `v.isValid()` to check all rules. Call `v.errors()` to get the array of failures, each with a `field` and `message` property.

### The Error Response Envelope

`res.error()` returns a consistent JSON error envelope:

```typescript
return res.error("VALIDATION_FAILED", "Name is required", 400);
```

This produces:

```json
{"error": true, "code": "VALIDATION_FAILED", "message": "Name is required", "status": 400}
```

The three arguments are: an error code string, a human-readable message, and the HTTP status code. Use this pattern across your API for consistent error handling.

### Upload Size Limits

Tina4 enforces a maximum upload size via the `TINA4_MAX_UPLOAD_SIZE` environment variable. The value is in bytes. The default is `10485760` (10 MB).

```env
TINA4_MAX_UPLOAD_SIZE=10485760
```

If a client sends a file larger than this limit, Tina4 returns a `413 Payload Too Large` response before your handler runs. To allow larger uploads, increase the value in `.env`:

```env
TINA4_MAX_UPLOAD_SIZE=52428800
```

This sets the limit to 50 MB.

---

## 11. Exercise: Build an Image Upload API

Build an API that handles image uploads and serves them back.

### Requirements

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/images` | Upload an image. Validate type and size. Return the image URL. |
| `GET` | `/api/images/{filename}` | Return the uploaded image file. Return 404 if not found. |

Rules:

1. Accept JPEG, PNG, and WebP files only
2. Maximum file size: 2MB
3. Save files to `src/public/uploads/` with a unique filename
4. Return the original filename, the saved filename, file size in KB, and the URL
5. The GET endpoint should serve the file directly (not JSON)

---

## 12. Solution

Create `src/routes/images.ts`:

```typescript
import { Router } from "tina4-nodejs";
import { rename, mkdir } from "fs/promises";
import { existsSync } from "fs";
import { join, extname } from "path";
import { randomUUID } from "crypto";

Router.post("/api/images", async (req, res) => {
    if (!req.files?.image) {
        return res.status(400).json({ error: "No image file provided. Use field name 'image'." });
    }

    const file = req.files.image;

    const allowedTypes = ["image/jpeg", "image/png", "image/webp"];
    if (!allowedTypes.includes(file.type)) {
        return res.status(400).json({
            error: "Invalid file type",
            received: file.type,
            allowed: allowedTypes
        });
    }

    const maxSize = 2 * 1024 * 1024;
    if (file.size > maxSize) {
        return res.status(400).json({
            error: "File too large",
            size_bytes: file.size,
            max_bytes: maxSize
        });
    }

    const ext = extname(file.name).toLowerCase();
    const savedName = `img_${randomUUID()}${ext}`;
    const uploadDir = join(process.cwd(), "src/public/uploads");
    const destination = join(uploadDir, savedName);

    if (!existsSync(uploadDir)) {
        await mkdir(uploadDir, { recursive: true });
    }

    await rename(file.tmpPath, destination);

    return res.status(201).json({
        message: "Image uploaded successfully",
        original_name: file.name,
        saved_name: savedName,
        size_kb: Math.round(file.size / 1024 * 10) / 10,
        type: file.type,
        url: `/uploads/${savedName}`
    });
});

Router.get("/api/images/{filename}", async (req, res) => {
    const filename = req.params.filename;

    if (filename.includes("..") || filename.includes("/")) {
        return res.status(400).json({ error: "Invalid filename" });
    }

    const filepath = join(process.cwd(), "src/public/uploads", filename);

    if (!existsSync(filepath)) {
        return res.status(404).json({ error: "Image not found", filename });
    }

    return res.file(filepath);
});
```

**Expected output for upload:**

```json
{
  "message": "Image uploaded successfully",
  "original_name": "photo.jpg",
  "saved_name": "img_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg",
  "size_kb": 240.0,
  "type": "image/jpeg",
  "url": "/uploads/img_a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg"
}
```

(Status: `201 Created`)

---

## 13. Gotchas

### 1. Forgetting `return`

**Problem:** Your handler runs (log output appears) but the browser shows an empty response or a 500 error.

**Cause:** You wrote `res.json({...})` without `return`.

**Fix:** Write `return res.json({...})`. The response object must be returned from the handler for Tina4 to send it.

### 2. Body Is Undefined for JSON Requests

**Problem:** `req.body` is `undefined` or empty even though you are sending JSON.

**Cause:** Missing `Content-Type: application/json` header. Without it, Tina4 does not parse the body as JSON.

**Fix:** Include `-H "Content-Type: application/json"` when sending JSON with curl. In frontend JavaScript, `fetch()` with `JSON.stringify()` requires `headers: {"Content-Type": "application/json"}`.

### 3. File Uploads Return Empty

**Problem:** `req.files` is empty even though you are uploading a file.

**Cause:** The form is not using `enctype="multipart/form-data"`, or the curl command uses `-d` instead of `-F`.

**Fix:** For HTML forms, use `<form enctype="multipart/form-data">`. For curl, use `-F "field=@file.jpg"` (with `@`), not `-d`.

### 4. Redirect Loops

**Problem:** The browser shows "too many redirects" or hangs.

**Cause:** Route A redirects to route B, which redirects back to route A.

**Fix:** Trace the redirect chain in the browser's network inspector. Break the cycle.

### 5. Cookie Not Set

**Problem:** You called `res.cookie(...)` but the browser does not show the cookie.

**Cause:** `secure: true` means the cookie travels only over HTTPS. Local development uses `http://localhost`. The cookie is dropped.

**Fix:** Set `secure: false` during development.

### 6. Large Request Body Rejected

**Problem:** POST requests with large bodies return a 413 error.

**Cause:** The request body exceeds the configured maximum size.

**Fix:** Increase `TINA4_MAX_BODY_SIZE` in `.env`. The default is `10mb`.

### 7. Headers Are Lowercase in Node.js

**Problem:** `req.headers["Content-Type"]` is `undefined` even though the header was sent.

**Cause:** Node.js normalizes all header names to lowercase.

**Fix:** Use lowercase header names: `req.headers["content-type"]`.
