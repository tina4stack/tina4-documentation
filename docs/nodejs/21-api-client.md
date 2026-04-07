# Chapter 21: API Client

## 1. Calling External APIs Without the Boilerplate

Your application calls a payment gateway. A shipping provider. A weather service. A CRM. Every call needs the same setup: base URL, auth header, error handling, JSON parsing, timeout.

Tina4 provides an `api` singleton — a preconfigured HTTP client that handles the repetitive parts. It covers GET, POST, PUT, and DELETE with JSON serialization, auth headers set once at configure time, and a consistent response format, all with no external dependencies.

---

## 2. The api Singleton

Import `api` from `@tina4/core`:

```typescript
import { api } from "@tina4/core";
```

`api` is a ready-to-use HTTP client. Configure it once. Use it everywhere.

---

## 3. Configuring the Client

Set the base URL and default headers before making requests. Do this at startup in `src/index.ts` or a dedicated `src/services/http.ts` file:

```typescript
import { api } from "@tina4/core";

api.configure({
    baseUrl: "https://api.example.com/v2",
    headers: {
        "Authorization": `Bearer ${process.env.API_KEY}`,
        "X-App-Version": "1.0.0"
    },
    timeout: 10000  // 10 seconds
});
```

| Option | Default | Description |
|--------|---------|-------------|
| `baseUrl` | `""` | Prepended to every request path |
| `headers` | `{}` | Sent with every request |
| `timeout` | `30000` | Request timeout in milliseconds |

---

## 4. GET Requests

```typescript
import { api } from "@tina4/core";

const response = await api.get("/products");

if (response.ok) {
    const products = response.data;
    console.log(`Fetched ${products.length} products`);
} else {
    console.error(`Error ${response.status}: ${response.error}`);
}
```

Pass query parameters as the second argument:

```typescript
const response = await api.get("/products", {
    params: { category: "Electronics", page: 2, limit: 20 }
});
// Requests: GET /products?category=Electronics&page=2&limit=20
```

---

## 5. POST Requests

```typescript
import { api } from "@tina4/core";

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

if (response.ok) {
    console.log(`Order created: ${response.data.orderId}`);
} else {
    console.error("Order failed:", response.error);
}
```

The body is serialized as JSON automatically. The `Content-Type: application/json` header is set for you.

---

## 6. PUT and PATCH Requests

```typescript
import { api } from "@tina4/core";

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

if (putResponse.ok) {
    console.log("Product updated:", putResponse.data);
}
```

---

## 7. DELETE Requests

```typescript
import { api } from "@tina4/core";

const response = await api.delete("/products/42");

if (response.ok) {
    console.log("Product deleted");
} else if (response.status === 404) {
    console.log("Product not found");
} else {
    console.error("Delete failed:", response.error);
}
```

---

## 8. Response Format

Every method returns the same response shape:

```typescript
interface ApiResponse<T = unknown> {
    ok: boolean;          // true if status 200-299
    status: number;       // HTTP status code
    data: T;              // Parsed JSON body (on success)
    error: string | null; // Error message (on failure)
    headers: Record<string, string>;
}
```

Check `response.ok` before using `response.data`. On failure, `response.error` contains the error message and `response.data` may be `null`.

```typescript
const response = await api.get("/products/999");

if (!response.ok) {
    if (response.status === 404) {
        return res.status(404).json({ error: "Product not found upstream" });
    }
    return res.status(502).json({ error: "Upstream service error" });
}

return res.json(response.data);
```

---

## 9. Per-Request Headers

Override or extend headers for a specific request:

```typescript
import { api } from "@tina4/core";

// Override the Authorization header for this request only
const response = await api.get("/admin/users", {
    headers: {
        "Authorization": `Bearer ${adminToken}`,
        "X-Request-Id": requestId
    }
});
```

Per-request headers are merged with the configured defaults. The per-request value wins on conflict.

---

## 10. Using api Inside Route Handlers

Proxy or transform external API calls inside your routes:

```typescript
import { Router } from "tina4-nodejs";
import { api } from "@tina4/core";

api.configure({
    baseUrl: "https://api.openweathermap.org/data/2.5",
    headers: { "Accept": "application/json" }
});

Router.get("/api/weather/{city}", async (req, res) => {
    const city = req.params.city;

    const response = await api.get("/weather", {
        params: {
            q: city,
            appid: process.env.OPENWEATHER_API_KEY,
            units: "metric"
        }
    });

    if (!response.ok) {
        return res.status(response.status).json({
            error: `Weather service error: ${response.error}`
        });
    }

    const weather = response.data as {
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

Build a route that fetches a GitHub user profile via the `api` client and returns a simplified version.

### Requirements

1. Configure `api` with `https://api.github.com` as the base URL and a `User-Agent` header (GitHub requires one)
2. Create a `GET /api/github/{username}` route that fetches the user's public profile
3. Return only: `login`, `name`, `public_repos`, `followers`, `following`, `bio`, and `avatar_url`
4. Return `404` with a message if the GitHub user does not exist

### Test with:

```bash
curl http://localhost:7145/api/github/torvalds
curl http://localhost:7145/api/github/this-user-does-not-exist-xyzabc
```

---

## 12. Solution

`src/services/github.ts`:

```typescript
import { api } from "@tina4/core";

api.configure({
    baseUrl: "https://api.github.com",
    headers: {
        "User-Agent": "tina4-book-example/1.0",
        "Accept": "application/vnd.github+json"
    },
    timeout: 8000
});
```

`src/routes/github.ts`:

```typescript
import { Router } from "tina4-nodejs";
import { api } from "@tina4/core";
import "../services/github";

interface GitHubUser {
    login: string;
    name: string | null;
    bio: string | null;
    public_repos: number;
    followers: number;
    following: number;
    avatar_url: string;
}

Router.get("/api/github/{username}", async (req, res) => {
    const { username } = req.params;

    const response = await api.get<GitHubUser>(`/users/${username}`);

    if (!response.ok) {
        if (response.status === 404) {
            return res.status(404).json({ error: `GitHub user '${username}' not found` });
        }
        return res.status(502).json({ error: "GitHub API error", detail: response.error });
    }

    const user = response.data;

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
curl http://localhost:7145/api/github/torvalds
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

### 1. Configure before first use

`api.configure()` must be called before any request is made. If a module imports `api` and immediately calls `api.get()` at module load time before `configure()` runs, the request goes to an empty base URL.

**Fix:** Call `api.configure()` in your app entry point (`src/index.ts`) before importing any service modules that use `api`.

### 2. Swallowing upstream errors

Checking only `response.ok` hides the status code. A `401` and a `503` both set `ok: false`, but require different handling.

**Fix:** Always check `response.status` for error branches. A `401` means your API key is wrong. A `503` means the service is down. Treat them differently.

### 3. Timeout not set

The default timeout is 30 seconds. If the upstream API hangs, your route handler hangs too, holding a connection open.

**Fix:** Set an explicit timeout appropriate for your service SLA. For real-time endpoints, 5-10 seconds is usually the right upper bound.

### 4. Sending secrets in URLs

Appending API keys as query parameters (e.g., `?apikey=secret`) logs the key to access logs.

**Fix:** Pass secrets in headers (`Authorization`, `X-API-Key`). Configure them once with `api.configure({ headers: { ... } })`.
