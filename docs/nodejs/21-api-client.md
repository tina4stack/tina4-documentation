# Chapter 21: API Client

## 1. Calling External APIs Without the Boilerplate

Your application calls a payment gateway. A shipping provider. A weather service. A CRM. Every call needs the same setup: base URL, auth header, error handling, JSON parsing, timeout.

Tina4 provides an `Api` class, a small HTTP client over Node's built-in `node:http`/`node:https` that handles the repetitive parts. It covers GET, POST, PUT, PATCH, and DELETE with JSON serialization, auth headers set once on the instance, and a consistent response format, all with no external dependencies.

---

## 2. The Api Class

Import `Api` from `@tina4/core` and construct an instance:

```typescript
import { Api } from "@tina4/core";

const api = new Api("https://api.example.com/v2");
```

`Api` is a ready-to-use HTTP client. Construct it once. Reuse the instance everywhere.

---

## 3. Configuring the Client

The constructor takes the base URL, an optional `Authorization` header value, and an optional timeout **in seconds** (default 30). Auth and custom headers can also be set after construction:

```typescript
import { Api } from "@tina4/core";

// Positional form: (baseUrl, authHeader, timeoutSeconds)
const api = new Api("https://api.example.com/v2", "", 10 /* seconds */);

api.addHeaders({ "X-App-Version": "1.0.0" });
api.setBearerToken(process.env.TINA4_API_KEY ?? "");

// Or the options-bag form (recommended):
const api2 = new Api("https://api.example.com/v2", {
    bearerToken: process.env.TINA4_API_KEY,
    headers: { "X-App-Version": "1.0.0" },
    timeout: 10,
});
```

| Constructor arg | Default | Description |
|-----------------|---------|-------------|
| `baseUrl` | `""` | Prepended to every request path |
| `authHeaderOrOptions` | `""` | An `Authorization` header value, or an options bag (`bearerToken`, `username`/`password`, `headers`, `timeout`, `verifySsl`) |
| `timeout` | `30` | Request timeout in **seconds** |

Instance setters:

| Method | Description |
|--------|-------------|
| `addHeaders(headers)` | Merge headers sent with every request |
| `setBearerToken(token)` | Set `Authorization: Bearer <token>` |
| `setBasicAuth(user, pass)` | Set HTTP Basic auth |
| `setIgnoreSsl(true)` | Skip TLS verification (dev / self-signed certs only) |

---

## 4. GET Requests

```typescript
import { Api } from "@tina4/core";

const api = new Api("https://api.example.com");
const response = await api.get("/products");

if (response.error === null && response.http_code === 200) {
    const products = response.body as unknown[];
    console.log(`Fetched ${products.length} products`);
} else {
    console.error(`Error ${response.http_code}: ${response.error}`);
}
```

Pass query parameters as a flat object in the second argument:

```typescript
const response = await api.get("/products", {
    category: "Electronics",
    page: "2",
    limit: "20",
});
// Requests: GET /products?category=Electronics&page=2&limit=20
```

Query values are strings (they go straight into the query string).

---

## 5. POST Requests

```typescript
import { Api } from "@tina4/core";

const api = new Api("https://api.example.com");
const response = await api.post("/orders", {
    customerId: 15,
    items: [
        { sku: "KB-001", qty: 1, price: 79.99 },
        { sku: "HDMI-2M", qty: 2, price: 12.99 }
    ],
    shippingAddress: {
        line1: "123 Main St",
        city: "Springfield",
        country: "US"
    }
});

if (response.error === null && response.http_code === 201) {
    const order = response.body as { orderId: string };
    console.log(`Order created: ${order.orderId}`);
} else {
    console.error("Order failed:", response.error ?? response.http_code);
}
```

The body is serialized as JSON automatically. The `Content-Type: application/json` header is set for you (override it with the optional third argument).

---

## 6. PUT and PATCH Requests

```typescript
import { Api } from "@tina4/core";

const api = new Api("https://api.example.com");

// Replace the entire resource
const putResponse = await api.put("/products/42", {
    name: "Wireless Keyboard Pro",
    price: 89.99,
    inStock: true,
    category: "Electronics"
});

// Update specific fields only
const patchResponse = await api.patch("/products/42", {
    price: 74.99
});

if (putResponse.error === null && putResponse.http_code === 200) {
    console.log("Product updated:", putResponse.body);
}
```

---

## 7. DELETE Requests

```typescript
import { Api } from "@tina4/core";

const api = new Api("https://api.example.com");
const response = await api.delete("/products/42");

if (response.http_code === 200 || response.http_code === 204) {
    console.log("Product deleted");
} else if (response.http_code === 404) {
    console.log("Product not found");
} else {
    console.error("Delete failed:", response.error ?? response.http_code);
}
```

---

## 8. Response Format

Every method returns the same `ApiResult` shape:

```typescript
interface ApiResult {
    http_code: number | null;            // HTTP status code, or null if the request never reached the server
    body: unknown;                        // Parsed JSON body, or the raw string if not JSON
    headers: Record<string, string>;      // Response headers
    error: string | null;                 // Non-null on transport failure or timeout
}
```

`error` is non-null only on a transport-level failure (connection refused, DNS, timeout). An HTTP error *response* (e.g. 404, 500) still arrives with `error: null`, so inspect `http_code` to branch on it.

```typescript
const response = await api.get("/products/999");

if (response.error !== null) {
    // Never reached the server
    return res.status(502).json({ error: "Upstream unreachable" });
}

if (response.http_code === 404) {
    return res.status(404).json({ error: "Product not found upstream" });
}
if (response.http_code !== 200) {
    return res.status(502).json({ error: "Upstream service error" });
}

return res.json(response.body);
```

---

## 9. Per-Request Content Type and Generic Requests

`post`/`put`/`patch` take an optional third argument to override the content type, and `sendRequest()` lets you issue any method:

```typescript
import { Api } from "@tina4/core";

const api = new Api("https://api.example.com");

// Send a non-JSON body
await api.post("/upload", "<xml/>", "application/xml");

// Any HTTP method
const options = await api.sendRequest("OPTIONS", "/users");
```

Headers configured with `addHeaders()` / `setBearerToken()` are sent on every request from that instance. For different auth, construct a second `Api` instance.

---

## 10. Using Api Inside Route Handlers

Proxy or transform external API calls inside your routes. Construct the client once at module load and reuse it:

```typescript
import { get } from "@tina4/core";
import { Api } from "@tina4/core";

const weatherApi = new Api("https://api.openweathermap.org/data/2.5");
weatherApi.addHeaders({ "Accept": "application/json" });

get("/api/weather/{city}", async (req, res) => {
    const city = req.params.city;

    const response = await weatherApi.get("/weather", {
        q: city,
        appid: process.env.OPENWEATHER_API_KEY ?? "",
        units: "metric"
    });

    if (response.error !== null || response.http_code !== 200) {
        return res.status(502).json({
            error: `Weather service error: ${response.error ?? response.http_code}`
        });
    }

    const weather = response.body as {
        name: string;
        main: { temp: number; humidity: number };
        weather: { description: string }[];
    };

    return res.json({
        city: weather.name,
        temperature: weather.main.temp,
        humidity: weather.main.humidity,
        description: weather.weather[0]?.description ?? "unknown"
    });
});
```

---

## 11. Exercise: GitHub User Profile Proxy

Build a route that fetches a GitHub user profile via an `Api` client and returns a simplified version.

### Requirements

1. Construct an `Api` with `https://api.github.com` as the base URL and a `User-Agent` header (GitHub requires one)
2. Create a `GET /api/github/{username}` route that fetches the user's public profile
3. Return only: `login`, `name`, `public_repos`, `followers`, `following`, `bio`, and `avatar_url`
4. Return `404` with a message if the GitHub user does not exist

### Test with:

```bash
curl http://localhost:7148/api/github/torvalds
curl http://localhost:7148/api/github/this-user-does-not-exist-xyzabc
```

---

## 12. Solution

`src/services/github.ts`:

```typescript
import { Api } from "@tina4/core";

export const githubApi = new Api("https://api.github.com", "", 8 /* seconds */);
githubApi.addHeaders({
    "User-Agent": "tina4-book-example/1.0",
    "Accept": "application/vnd.github+json"
});
```

`src/routes/github.ts`:

```typescript
import { get } from "@tina4/core";
import { githubApi } from "../services/github";

interface GitHubUser {
    login: string;
    name: string | null;
    bio: string | null;
    public_repos: number;
    followers: number;
    following: number;
    avatar_url: string;
}

get("/api/github/{username}", async (req, res) => {
    const { username } = req.params;

    const response = await githubApi.get(`/users/${username}`);

    if (response.error !== null) {
        return res.status(502).json({ error: "GitHub API unreachable", detail: response.error });
    }
    if (response.http_code === 404) {
        return res.status(404).json({ error: `GitHub user '${username}' not found` });
    }
    if (response.http_code !== 200) {
        return res.status(502).json({ error: "GitHub API error", detail: response.http_code });
    }

    const user = response.body as GitHubUser;

    return res.json({
        login: user.login,
        name: user.name,
        bio: user.bio,
        public_repos: user.public_repos,
        followers: user.followers,
        following: user.following,
        avatar_url: user.avatar_url
    });
});
```

```bash
curl http://localhost:7148/api/github/torvalds
```

```json
{
  "login": "torvalds",
  "name": "Linus Torvalds",
  "bio": null,
  "public_repos": 7,
  "followers": 234156,
  "following": 0,
  "avatar_url": "https://avatars.githubusercontent.com/u/1024025?v=4"
}
```

---

## 13. Gotchas

### 1. `http_code` vs `error`

`error` is set only when the request never reaches the server (timeout, connection refused). A `404` or `503` *response* arrives with `error: null`, so branch on `http_code` for those.

**Fix:** Check `response.error` first for transport failures, then check `response.http_code` for HTTP-level branches.

### 2. Timeout is in seconds

The constructor's third argument is **seconds**, not milliseconds: `new Api(url, "", 10)` is a 10-second timeout. The default is 30 seconds.

**Fix:** Set an explicit timeout appropriate for your service SLA. For real-time endpoints, 5-10 seconds is usually the right upper bound.

### 3. Reuse the instance

Constructing a new `Api` for every request re-applies headers each time and adds noise.

**Fix:** Construct one `Api` per upstream service at module load, configure its headers once, and reuse it.

### 4. Sending secrets in URLs

Appending API keys as query parameters (e.g., `?apikey=secret`) logs the key to access logs.

**Fix:** Pass secrets in headers. Use `api.setBearerToken(token)` or `api.addHeaders({ "X-API-Key": key })` once on the instance.

---

## 14. Uploading Files (New in 3.13.69)

`upload()` posts a `multipart/form-data` body: a file plus optional text fields. You supply the file two ways through an options object, so your code never stages a temp file first.

```typescript
import { Api } from "@tina4/core";

const api = new Api("https://api.example.com", { bearerToken: process.env.API_TOKEN });

// A file on disk. filename defaults to the basename.
await api.upload("/avatars", { filePath: "/tmp/me.png" });

// In-memory bytes (Buffer or string). Pass a filename so the server sees a real name.
const raw = await buildThumbnail();          // Buffer
await api.upload("/avatars", {
    fileBytes: raw,
    filename: "me.png",
    extraFields: { user_id: "42" },          // extra text parts
});
```

The options object accepts `filePath`, `fieldName` (default `"file"`), `extraFields`, `headers`, `fileBytes`, and `filename`. The part's `Content-Type` is guessed from the filename, falling back to `application/octet-stream`.

`upload()` returns the standard `ApiResult` (`http_code`, `body`, `headers`, `error`). A missing file, or no source at all, resolves to a clean error result and never throws:

```typescript
const result = await api.upload("/avatars", { filePath: "/tmp/gone.png" });
// { http_code: null, body: null, headers: {}, error: "file not found: /tmp/gone.png" }
```

---

## 15. Streaming Downloads (New in 3.13.69)

`download()` streams a GET body straight to disk, 64KB at a time. A large export never buffers whole in memory.

```typescript
const result = await api.download("/reports/2026.csv", "/tmp/2026.csv", { q: "2026" });

if (result.error === null) {
    console.log("saved to", result.path);   // /tmp/2026.csv
}
```

The signature is `download(path, destPath, params?)`. The result has no `body` field. The body went to disk. It carries `http_code`, `headers`, `error`, and `path`. On success `path` is your `destPath`; on any error (no dest, an HTTP error status, or a transport failure) `path` is `null` and no file is written.

---

## 16. Testing Your Code: the transport Seam (New in 3.13.69)

The options bag accepts a `transport` function that fully replaces the `node:http`/`node:https` call. Point it at your own function and the code that calls an `Api` runs in a unit test with no live server.

```typescript
const api = new Api("https://api.example.com", {
    transport: async (method, url, headers, body, timeout) =>
        ({ http_code: 200, body: { ok: true }, headers: {}, error: null }),
});

const result = await api.get("/health");   // returns the canned result, opens no socket
```

The function signature is `(method, url, headers, body, timeout) => ApiResult`. It may be sync or async and returns the standard result shape.

This seam is for **your** tests, not Tina4's. The framework's own suite never injects a fake transport: it follows the no-mock rule and drives the real network against a real local server. Reach for `transport` to test the code that calls an `Api`, never to stand in for `Api` itself.

---

## 17. The Cookie Jar (New in 3.13.69)

Set `cookies: true` and the client keeps a per-instance, in-memory cookie jar. It reads `Set-Cookie` on each response and replays the accumulated `Cookie` header on the next request, so a session carries across a login and the calls that follow.

```typescript
const api = new Api("https://api.example.com", { cookies: true });

await api.post("/login", { user: "alice", pass: "secret" });   // server sets a session cookie
await api.get("/account");                                      // the cookie is sent automatically
```

The jar is off by default. It keeps only the leading `name=value` of each cookie, it is never persisted, and it is scoped to the instance.

---

## 18. Redirects and Cross-Origin Safety (New in 3.13.69)

Bare `node:http`/`node:https` does not follow redirects. The client now does, bounded to ten hops. A `301`, `302`, or `303` on a body-bearing method becomes a `GET` with the body dropped (matching urllib); `307` and `308` keep the method and body.

On a redirect that crosses to a different origin (a different scheme, host, or port), the client strips the `Authorization` header and the cookie-jar `Cookie` header before following. That strip is a security boundary: without it, a call to `https://api.example.com/login` that redirected to `https://evil.example/` would hand your bearer token and session cookie to a host you never authenticated against. Same-origin redirects keep both headers.

You get this on every verb, on `upload()`, and on `download()`, with nothing to switch on.
