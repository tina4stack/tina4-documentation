# API – Fetch Wrapper

tina4-js includes a lightweight fetch wrapper that is fully compatible with tina4-php and tina4-python authentication (Bearer token, formToken, FreshToken rotation).

## Configuration {#configure}

```ts
import { api } from 'tina4js';

api.configure({
  baseUrl: '/api',           // Prepended to all request paths
  auth: true,                // Enable Bearer token + formToken
  tokenKey: 'tina4_token',   // localStorage key for the JWT (default)
});
```

| Option | Default | Description |
|--------|---------|-------------|
| `baseUrl` | `''` | Base URL prepended to all paths |
| `auth` | `false` | Enable authentication headers |
| `tokenKey` | `'tina4_token'` | localStorage key for JWT token |

## HTTP Methods {#methods}

```ts
// GET
const users = await api.get('/users');

// POST
const newUser = await api.post('/users', { name: 'Andre' });

// PUT
await api.put('/users/42', { name: 'Updated' });

// PATCH
await api.patch('/users/42', { email: 'new@email.com' });

// DELETE
await api.delete('/users/42');
```

All methods return the parsed response body (JSON object or plain text).

## Path Parameters {#path-params}

Use `{param}` placeholders in paths — matching tina4-php/python route syntax:

```ts
// Replaces {id} with 42 → GET /api/users/42
const user = await api.get('/users/{id}', { id: 42 });

// Multiple params → GET /api/posts/2024/my-slug
const post = await api.get('/posts/{year}/{slug}', {
  year: 2024,
  slug: 'my-slug',
});
```

## Authentication {#auth}

When `auth: true`, the API wrapper automatically:

1. **Bearer token** — reads from `localStorage` and adds `Authorization: Bearer <token>` to every request
2. **formToken** — injects the token into POST/PUT/PATCH/DELETE request bodies as `formToken`
3. **Token rotation** — if the response includes a `FreshToken` header, the stored token is updated

```ts
// Configure auth
api.configure({ baseUrl: '/api', auth: true });

// Set token (usually after login)
localStorage.setItem('tina4_token', 'your-jwt-here');

// All requests now include Authorization header
const data = await api.get('/protected');

// POST body automatically includes formToken
await api.post('/items', { name: 'thing' });
// Actually sends: { name: 'thing', formToken: 'your-jwt-here' }
```

### Auth Flow (tina4-php/python Compatible)

```
Browser                          tina4 Backend
  │                                    │
  │  POST /api/login                   │
  │  { email, password }               │
  │ ──────────────────────────────────►│
  │                                    │
  │  200 OK                            │
  │  FreshToken: eyJ...                │
  │  { success: true }                 │
  │ ◄──────────────────────────────────│
  │                                    │
  │  (token saved to localStorage)     │
  │                                    │
  │  GET /api/data                     │
  │  Authorization: Bearer eyJ...      │
  │ ──────────────────────────────────►│
  │                                    │
  │  200 OK                            │
  │  FreshToken: eyK... (rotated)      │
  │  { data: [...] }                   │
  │ ◄──────────────────────────────────│
```

## Error Handling {#errors}

Non-2xx responses throw an error object:

```ts
try {
  await api.get('/missing');
} catch (err) {
  console.log(err.status);   // 404
  console.log(err.data);     // { error: 'Not found' }
  console.log(err.ok);       // false
  console.log(err.headers);  // Response headers
}
```

## Interceptors {#interceptors}

Add middleware for requests and responses:

### Request Interceptors

```ts
api.intercept('request', (config) => {
  config.headers['X-Custom'] = 'my-value';
  config.headers['Accept-Language'] = 'en-US';
  return config;
});
```

### Response Interceptors

```ts
api.intercept('response', (response) => {
  if (response.status === 401) {
    navigate('/login');
  }
  return response;
});
```

### Multiple Interceptors

Interceptors are chained in order:

```ts
api.intercept('request', (config) => {
  config.headers['X-First'] = '1';
  return config;
});

api.intercept('request', (config) => {
  config.headers['X-Second'] = '2';
  return config;
});

// Both headers are set on every request
```

## Content Type Handling {#content-type}

The API wrapper automatically handles response content types:

| Response Content-Type | Parsing |
|----------------------|---------|
| `application/json` | Parsed as JSON |
| `text/*` | Returned as string |

## Full Example {#full-example}

```ts
import { api, signal, html, navigate } from 'tina4js';

// Configure
api.configure({ baseUrl: '/api', auth: true });

// Add auth redirect interceptor
api.intercept('response', (res) => {
  if (res.status === 401) navigate('/login');
  return res;
});

// State
const users = signal<any[]>([]);
const loading = signal(false);

// Fetch and display
async function loadUsers() {
  loading.value = true;
  try {
    users.value = await api.get('/users');
  } catch (err) {
    console.error('Failed:', err);
  } finally {
    loading.value = false;
  }
}

const view = html`
  <div>
    <button @click=${loadUsers}>
      ${() => loading.value ? 'Loading...' : 'Load Users'}
    </button>
    <ul>
      ${() => users.value.map(u =>
        html`<li>${u.name} (${u.email})</li>`
      )}
    </ul>
  </div>
`;
```
