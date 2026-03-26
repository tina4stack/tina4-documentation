# Chapter 3: Request & Response

## 1. The Two Objects You Always Get

Every route handler receives two arguments. `$request` tells you what the client sent. `$response` is how you send something back. Together they are the entire HTTP conversation.

```php
<?php
use Tina4Router;

Router::get("/echo", function ($request, $response) {
    return $response->json([
        "method" => $request->method,
        "path" => $request->path,
        "your_ip" => $request->ip
    ]);
});
```

```bash
curl http://localhost:7146/echo
```

```json
{"method":"GET","path":"/echo","your_ip":"127.0.0.1"}
```

The pattern never changes. Inspect the request. Build the response. Return it.

---

## 2. The Request Object

The `$request` object carries everything the client sent. Here is the full inventory.

### method

The HTTP method as an uppercase string: `"GET"`, `"POST"`, `"PUT"`, `"PATCH"`, or `"DELETE"`.

```php
$request->method // "GET"
```

### path

The URL path, stripped of query parameters:

```php
// Request to /api/users?page=2
$request->path // "/api/users"
```

### params

Path parameters captured from the URL pattern (see Chapter 2):

```php
// Route: /users/{id}/posts/{postId}
// Request: /users/5/posts/42
$request->params["id"]     // "5" (or 5 if typed as {id:int})
$request->params["postId"] // "42"
```

### query

Query string parameters. An associative array:

```php
// Request: /search?q=keyboard&page=2&sort=price
$request->query["q"]    // "keyboard"
$request->query["page"] // "2"
$request->query["sort"] // "price"
```

### body

The parsed request body. JSON requests become associative arrays. Form submissions contain form fields:

```php
// POST with {"name": "Widget", "price": 9.99}
$request->body["name"]  // "Widget"
$request->body["price"] // 9.99
```

### headers

Request headers as an associative array. Original casing preserved:

```php
$request->headers["Content-Type"]  // "application/json"
$request->headers["Authorization"] // "Bearer eyJhbGci..."
$request->headers["X-Custom"]      // "my-value"
```

### ip

The client's IP address:

```php
$request->ip // "127.0.0.1"
```

Tina4 respects `X-Forwarded-For` and `X-Real-IP` headers behind a reverse proxy.

### cookies

Cookies the client sent:

```php
$request->cookies["session_id"]  // "abc123"
$request->cookies["preferences"] // "dark-mode"
```

### files

Uploaded files (section 7 covers this in detail):

```php
$request->files["avatar"] // File object with name, type, size, tmpPath
```

### Inspecting the Full Request

A diagnostic route that dumps everything:

```php
<?php
use Tina4Router;

Router::post("/debug/request", function ($request, $response) {
    return $response->json([
        "method" => $request->method,
        "path" => $request->path,
        "params" => $request->params,
        "query" => $request->query,
        "body" => $request->body,
        "headers" => $request->headers,
        "ip" => $request->ip,
        "cookies" => $request->cookies
    ]);
});
```

```bash
curl -X POST "http://localhost:7146/debug/request?page=1" \
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
    "Content-Type": "application/json",
    "X-Custom": "hello",
    "Host": "localhost:7146",
    "User-Agent": "curl/8.4.0",
    "Accept": "*/*",
    "Content-Length": "16"
  },
  "ip": "127.0.0.1",
  "cookies": {}
}
```

---

## 3. The Response Object

The `$response` object builds what goes back to the client. Every method returns the response, so calls chain.

### json() -- JSON Response

The workhorse for APIs. Pass an array and it becomes JSON:

```php
return $response->json(["name" => "Alice", "age" => 30]);
```

```json
{"name":"Alice","age":30}
```

Second argument sets the status code:

```php
return $response->json(["id" => 7, "name" => "Widget"], 201);
```

`201 Created` with the JSON body.

### html() -- Raw HTML Response

Return HTML directly:

```php
return $response->html("<h1>Hello</h1><p>This is HTML.</p>");
```

Sets `Content-Type: text/html; charset=utf-8`.

### text() -- Plain Text Response

```php
return $response->text("Just a plain string.");
```

Sets `Content-Type: text/plain; charset=utf-8`.

### render() -- Template Response

Render a Frond template with data ([Chapter 4: Templates](04-templates.md) goes deep):

```php
return $response->render("products.html", [
    "products" => $products,
    "title" => "Our Products"
]);
```

Tina4 looks in `src/templates/`, renders, returns the HTML.

### redirect() -- Redirect Response

Send the client elsewhere:

```php
return $response->redirect("/login");
```

`302 Found` by default. For permanent redirects:

```php
return $response->redirect("/new-location", 301);
```

### file() -- File Download Response

Send a file for download:

```php
return $response->file("/path/to/report.pdf");
```

Tina4 sets the correct `Content-Type` from the file extension and adds `Content-Disposition` so the browser downloads instead of displaying.

Custom filename:

```php
return $response->file("/path/to/report.pdf", "monthly-report-march-2026.pdf");
```

---

## 4. Status Codes

Every response method accepts a status code. The ones you will use most:

| Code | Meaning | When to Use |
|------|---------|-------------|
| `200` | OK | Default. Successful GET, PUT, PATCH. |
| `201` | Created | Successful POST that created a resource. |
| `204` | No Content | Successful DELETE. No body needed. |
| `301` | Moved Permanently | URL has permanently changed. |
| `302` | Found | Temporary redirect. |
| `400` | Bad Request | Invalid input from the client. |
| `401` | Unauthorized | Missing or invalid authentication. |
| `403` | Forbidden | Authenticated but not allowed. |
| `404` | Not Found | Resource does not exist. |
| `409` | Conflict | Duplicate or conflicting data. |
| `422` | Unprocessable Entity | Valid JSON but fails business rules. |
| `500` | Internal Server Error | Something broke on the server. |

You can also chain `status()` explicitly:

```php
return $response->status(201)->json(["id" => 7, "created" => true]);
```

Equivalent to `$response->json(["id" => 7, "created" => true], 201)`. Some developers find the chain clearer.

---

## 5. Custom Headers

Set response headers with `header()`:

```php
Router::get("/api/data", function ($request, $response) {
    return $response
        ->header("X-Request-Id", uniqid())
        ->header("X-Rate-Limit-Remaining", "57")
        ->header("Cache-Control", "no-cache")
        ->json(["data" => [1, 2, 3]]);
});
```

```bash
curl -v http://localhost:7146/api/data 2>&1 | grep "< X-"
```

```
< X-Request-Id: 65f3a7b8c1234
< X-Rate-Limit-Remaining: 57
```

Convention: `Title-Case` for custom headers. Prefix with `X-`.

### CORS Headers

Tina4 handles CORS based on `CORS_ORIGINS` in `.env`. The default `*` allows all origins. For production, restrict:

```env
CORS_ORIGINS=https://myapp.com,https://admin.myapp.com
```

Manual CORS headers are rarely needed, but available:

```php
return $response
    ->header("Access-Control-Allow-Origin", "https://myapp.com")
    ->header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")
    ->header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    ->json(["data" => "value"]);
```

---

## 6. Cookies

Set cookies on the response:

```php
Router::post("/login", function ($request, $response) {
    // After validating credentials...
    return $response
        ->cookie("session_id", "abc123xyz", [
            "httpOnly" => true,
            "secure" => true,
            "sameSite" => "Strict",
            "maxAge" => 3600,       // 1 hour in seconds
            "path" => "/"
        ])
        ->json(["message" => "Logged in"]);
});
```

Cookie options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `httpOnly` | bool | `false` | Invisible to JavaScript |
| `secure` | bool | `false` | HTTPS only |
| `sameSite` | string | `"Lax"` | `"Strict"`, `"Lax"`, or `"None"` |
| `maxAge` | int | session | Lifetime in seconds |
| `path` | string | `"/"` | URL path scope |
| `domain` | string | current | Domain scope |

Read cookies from the request:

```php
Router::get("/profile", function ($request, $response) {
    $sessionId = $request->cookies["session_id"] ?? null;

    if ($sessionId === null) {
        return $response->json(["error" => "Not logged in"], 401);
    }

    return $response->json(["session" => $sessionId]);
});
```

Delete a cookie by setting `maxAge` to `0`:

```php
return $response
    ->cookie("session_id", "", ["maxAge" => 0, "path" => "/"])
    ->json(["message" => "Logged out"]);
```

---

## 7. File Uploads

Uploaded files arrive via `$request->files`. Each file is an object with metadata and a temporary path.

### Handling a Single File Upload

```php
<?php
use Tina4Router;

Router::post("/api/upload", function ($request, $response) {
    if (empty($request->files["image"])) {
        return $response->json(["error" => "No file uploaded"], 400);
    }

    $file = $request->files["image"];

    return $response->json([
        "name" => $file->name,        // "photo.jpg"
        "type" => $file->type,        // "image/jpeg"
        "size" => $file->size,        // 245760 (bytes)
        "tmp_path" => $file->tmpPath  // Temporary file location
    ]);
});
```

```bash
curl -X POST http://localhost:7146/api/upload \
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

The file sits in a temporary location. Move it somewhere permanent:

```php
<?php
use Tina4Router;

Router::post("/api/upload", function ($request, $response) {
    if (empty($request->files["image"])) {
        return $response->json(["error" => "No file uploaded"], 400);
    }

    $file = $request->files["image"];

    // Validate file type
    $allowedTypes = ["image/jpeg", "image/png", "image/gif", "image/webp"];
    if (!in_array($file->type, $allowedTypes)) {
        return $response->json(["error" => "Invalid file type. Allowed: JPEG, PNG, GIF, WebP"], 400);
    }

    // Validate file size (max 5MB)
    $maxSize = 5 * 1024 * 1024;
    if ($file->size > $maxSize) {
        return $response->json(["error" => "File too large. Maximum size: 5MB"], 400);
    }

    // Generate a unique filename
    $extension = pathinfo($file->name, PATHINFO_EXTENSION);
    $filename = uniqid("img_") . "." . $extension;
    $destination = __DIR__ . "/../../public/uploads/" . $filename;

    // Ensure the uploads directory exists
    if (!is_dir(dirname($destination))) {
        mkdir(dirname($destination), 0755, true);
    }

    // Move the file
    rename($file->tmpPath, $destination);

    return $response->json([
        "message" => "File uploaded successfully",
        "filename" => $filename,
        "url" => "/uploads/" . $filename,
        "size" => $file->size
    ], 201);
});
```

```bash
curl -X POST http://localhost:7146/api/upload \
  -F "image=@/path/to/photo.jpg"
```

```json
{
  "message": "File uploaded successfully",
  "filename": "img_65f3a7b8c1234.jpg",
  "url": "/uploads/img_65f3a7b8c1234.jpg",
  "size": 245760
}
```

The file is now available at `http://localhost:7146/uploads/img_65f3a7b8c1234.jpg`.

### Handling Multiple Files

When the form uses `multiple` or has multiple file inputs:

```php
Router::post("/api/upload-many", function ($request, $response) {
    $results = [];

    foreach ($request->files as $key => $file) {
        $extension = pathinfo($file->name, PATHINFO_EXTENSION);
        $filename = uniqid("file_") . "." . $extension;
        $destination = __DIR__ . "/../../public/uploads/" . $filename;

        if (!is_dir(dirname($destination))) {
            mkdir(dirname($destination), 0755, true);
        }

        rename($file->tmpPath, $destination);

        $results[] = [
            "original_name" => $file->name,
            "saved_as" => $filename,
            "url" => "/uploads/" . $filename
        ];
    }

    return $response->json(["uploaded" => $results, "count" => count($results)], 201);
});
```

---

## 8. File Downloads

Send files to the client with `$response->file()`:

```php
<?php
use Tina4Router;

Router::get("/api/reports/{filename}", function ($request, $response) {
    $filename = $request->params["filename"];
    $filepath = __DIR__ . "/../../data/reports/" . $filename;

    if (!file_exists($filepath)) {
        return $response->json(["error" => "Report not found"], 404);
    }

    return $response->file($filepath);
});
```

The browser downloads the file. Tina4 detects the MIME type from the extension and sets headers accordingly.

Force a specific download filename:

```php
return $response->file($filepath, "Q1-2026-Sales-Report.pdf");
```

---

## 9. Content Negotiation

One endpoint. Multiple formats. Check the `Accept` header:

```php
<?php
use Tina4Router;

Router::get("/api/products/{id:int}", function ($request, $response) {
    $id = $request->params["id"];
    $product = [
        "id" => $id,
        "name" => "Wireless Keyboard",
        "price" => 79.99
    ];

    $accept = $request->headers["Accept"] ?? "application/json";

    if (strpos($accept, "text/html") !== false) {
        return $response->render("product-detail.html", ["product" => $product]);
    }

    if (strpos($accept, "text/plain") !== false) {
        $text = "Product #" . $id . ": " . $product["name"] . " - $" . $product["price"];
        return $response->text($text);
    }

    // Default: JSON
    return $response->json($product);
});
```

```bash
# JSON (default)
curl http://localhost:7146/api/products/1
```

```json
{"id":1,"name":"Wireless Keyboard","price":79.99}
```

```bash
# Plain text
curl http://localhost:7146/api/products/1 -H "Accept: text/plain"
```

```
Product #1: Wireless Keyboard - $79.99
```

```bash
# HTML (renders the template)
curl http://localhost:7146/api/products/1 -H "Accept: text/html"
```

```html
<!DOCTYPE html>
<html>...rendered template...</html>
```

---

## 10. Input Validation

Tina4 includes a `Validator` class for declarative input validation. Chain rules together and check the result. If validation fails, use `$response->sendError()` to return a structured error envelope.

### The Validator Class

```php
use Tina4\Validator;

Router::post("/api/users", function ($request, $response) {
    $v = new Validator($request->body);
    $v->required("name")->required("email")->email("email")->minLength("name", 2);

    if (!$v->isValid()) {
        return $response->sendError("VALIDATION_FAILED", $v->errors()[0]["message"], 400);
    }

    // proceed with valid data
});
```

The `Validator` accepts the request body (an associative array) and provides chainable methods:

| Method | Description |
|--------|-------------|
| `required(field)` | Field must be present and non-empty |
| `email(field)` | Field must be a valid email address |
| `minLength(field, n)` | Field must have at least `n` characters |
| `maxLength(field, n)` | Field must have at most `n` characters |
| `numeric(field)` | Field must be a number |
| `inList(field, values)` | Field must be one of the allowed values |

Call `$v->isValid()` to check all rules. Call `$v->errors()` to get the list of failures, each with a `field` and `message` key.

### The Error Response Envelope

`$response->sendError()` returns a consistent JSON error envelope:

```php
return $response->sendError("VALIDATION_FAILED", "Name is required", 400);
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

Two endpoints. Upload images and serve them back.

### Requirements

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/images` | Upload an image. Validate type and size. Return the image URL. |
| `GET` | `/api/images/{filename}` | Return the uploaded image file. 404 if not found. |

Rules:

1. Accept JPEG, PNG, and WebP only
2. Maximum file size: 2MB
3. Save to `src/public/uploads/` with a unique filename
4. Return original filename, saved filename, file size in KB, and URL
5. The GET endpoint serves the raw file, not JSON

### Test with:

```bash
# Upload
curl -X POST http://localhost:7146/api/images \
  -F "image=@/path/to/photo.jpg"

# Download
curl http://localhost:7146/api/images/img_65f3a7b8c1234.jpg --output downloaded.jpg
```

---

## 12. Solution

Create `src/routes/images.php`:

```php
<?php
use Tina4Router;

Router::post("/api/images", function ($request, $response) {
    // Check if a file was uploaded
    if (empty($request->files["image"])) {
        return $response->json(["error" => "No image file provided. Use field name 'image'."], 400);
    }

    $file = $request->files["image"];

    // Validate file type
    $allowedTypes = ["image/jpeg", "image/png", "image/webp"];
    if (!in_array($file->type, $allowedTypes)) {
        return $response->json([
            "error" => "Invalid file type",
            "received" => $file->type,
            "allowed" => $allowedTypes
        ], 400);
    }

    // Validate file size (max 2MB)
    $maxSize = 2 * 1024 * 1024;
    if ($file->size > $maxSize) {
        return $response->json([
            "error" => "File too large",
            "size_bytes" => $file->size,
            "max_bytes" => $maxSize
        ], 400);
    }

    // Generate unique filename preserving extension
    $extension = pathinfo($file->name, PATHINFO_EXTENSION);
    $savedName = uniqid("img_") . "." . strtolower($extension);
    $uploadDir = __DIR__ . "/../../public/uploads";
    $destination = $uploadDir . "/" . $savedName;

    // Create uploads directory if it does not exist
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    // Move the uploaded file
    rename($file->tmpPath, $destination);

    return $response->json([
        "message" => "Image uploaded successfully",
        "original_name" => $file->name,
        "saved_name" => $savedName,
        "size_kb" => round($file->size / 1024, 1),
        "type" => $file->type,
        "url" => "/uploads/" . $savedName
    ], 201);
});

Router::get("/api/images/{filename}", function ($request, $response) {
    $filename = $request->params["filename"];

    // Prevent directory traversal
    if (strpos($filename, "..") !== false || strpos($filename, "/") !== false) {
        return $response->json(["error" => "Invalid filename"], 400);
    }

    $filepath = __DIR__ . "/../../public/uploads/" . $filename;

    if (!file_exists($filepath)) {
        return $response->json(["error" => "Image not found", "filename" => $filename], 404);
    }

    return $response->file($filepath);
});
```

**Expected output for upload:**

```json
{
  "message": "Image uploaded successfully",
  "original_name": "photo.jpg",
  "saved_name": "img_65f3a7b8c1234.jpg",
  "size_kb": 240.0,
  "type": "image/jpeg",
  "url": "/uploads/img_65f3a7b8c1234.jpg"
}
```

(Status: `201 Created`)

**Expected output for invalid type:**

```json
{
  "error": "Invalid file type",
  "received": "application/pdf",
  "allowed": ["image/jpeg", "image/png", "image/webp"]
}
```

(Status: `400 Bad Request`)

**Expected output for file too large:**

```json
{
  "error": "File too large",
  "size_bytes": 5242880,
  "max_bytes": 2097152
}
```

(Status: `400 Bad Request`)

**The GET endpoint** returns the raw image file with the correct `Content-Type` header. The browser displays it directly. Curl with `--output` saves it to disk.

---

## 13. Gotchas

### 1. Forgetting `return`

**Problem:** The handler runs (log output confirms it) but the browser gets an empty response or 500.

**Cause:** `$response->json([...])` without `return`. The response object builds the reply but nobody sends it.

**Fix:** `return $response->json([...])`. Always.

### 2. Body Is Null for JSON Requests

**Problem:** `$request->body` is `null` or empty despite sending JSON.

**Cause:** Missing `Content-Type: application/json` header. Without it, Tina4 does not parse the body as JSON.

**Fix:** Include `-H "Content-Type: application/json"` with curl. In JavaScript `fetch()`, set `headers: {"Content-Type": "application/json"}`.

### 3. Content-Type Mismatch

**Problem:** `$response->json()` returns HTML, or `$response->html()` returns plain text.

**Cause:** A middleware or error handler overwrites the response. Or you returned a string instead of using a response method.

**Fix:** Use `$response->json(...)`, `$response->html(...)`, or another response method. Never `echo` -- it bypasses the response object.

### 4. File Uploads Return Empty

**Problem:** `$request->files` is empty despite uploading a file.

**Cause:** The form lacks `enctype="multipart/form-data"`, or curl uses `-d` instead of `-F`.

**Fix:** HTML forms: `<form enctype="multipart/form-data">`. Curl: `-F "field=@file.jpg"` (with `@`), not `-d`.

### 5. Redirect Loops

**Problem:** The browser shows "too many redirects."

**Cause:** Route A redirects to Route B. Route B redirects back to Route A. Common with login guards: `/login` redirects to `/dashboard`, `/dashboard` redirects to `/login` because the user is not authenticated.

**Fix:** Trace the redirect chain in your browser's network inspector. Make sure the auth check does not redirect authenticated users away from pages they should access.

### 6. Cookie Not Set

**Problem:** `$response->cookie(...)` runs but the browser shows no cookie.

**Cause:** `secure` is `true`. The cookie only travels over HTTPS. Local development uses `http://localhost`. The cookie is silently dropped.

**Fix:** Set `"secure" => false` during development. Or use `"secure" => ($_ENV["TINA4_DEBUG"] ?? "false") !== "true"` to auto-switch.

### 7. Large Request Body Rejected

**Problem:** POST requests with large bodies return 413.

**Cause:** Request body exceeds the configured maximum.

**Fix:** Increase `TINA4_MAX_BODY_SIZE` in `.env`. Default is `10mb`. For file upload endpoints, you may need `50mb` or more:

```env
TINA4_MAX_BODY_SIZE=50mb
```
