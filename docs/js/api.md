# API – Fetch Client

tina4-js includes a lightweight fetch client (~1.5 KB gzip) that is fully compatible with tina4-php and tina4-python authentication (Bearer token, formToken, FreshToken rotation).

## Configuration {#configure}

```ts
import { api } from 'tina4js';

api.configure({
  baseUrl: '/api',           // Prepended to all request paths
  auth: true,                // Enable Bearer token + formToken
  tokenKey: 'tina4_token',   // localStorage key for the JWT (default)
  headers: {                 // Default headers on every request
    'X-App': 'my-app',
    'Accept-Language': 'en',
  },
});
```

| Option | Default | Description |
|--------|---------|-------------|
| `baseUrl` | `''` | Base URL prepended to all paths |
| `auth` | `false` | Enable authentication headers |
| `tokenKey` | `'tina4_token'` | localStorage key for JWT token |
| `headers` | `{}` | Default headers sent with every request |

## HTTP Methods {#methods}

All methods accept an optional `RequestOptions` object:

```ts
interface RequestOptions {
  headers?: Record<string, string>;   // Per-request headers
  params?: Record<string, string | number | boolean>; // Query string params
}
```

```ts
// GET
const users = await api.get('/users');

// GET with query params → /api/users?role=admin&active=true
const admins = await api.get('/users', {
  params: { role: 'admin', active: true },
});

// GET with custom headers
const data = await api.get('/data', {
  headers: { 'X-Custom': 'value' },
});

// POST with body
const newUser = await api.post('/users', { name: 'Andre', email: 'andre@example.com' });

// POST with body + query params + custom headers
const result = await api.post('/import', formData, {
  params: { format: 'csv' },
  headers: { 'X-Batch-Id': '12345' },
});

// PUT
await api.put('/users/42', { name: 'Updated' });

// PATCH
await api.patch('/users/42', { email: 'new@email.com' });

// DELETE
await api.delete('/users/42');

// DELETE with params
await api.delete('/cache', { params: { older_than: '30d' } });
```

All methods return the parsed response body (JSON object or plain text).

## Query Parameters {#query-params}

Pass `params` in the options to build query strings automatically:

```ts
// Simple params → /api/search?q=tina4&page=1&limit=20
const results = await api.get('/search', {
  params: { q: 'tina4', page: 1, limit: 20 },
});

// Values are URL-encoded automatically
await api.get('/search', {
  params: { q: 'hello world & more' },
});
// → /api/search?q=hello%20world%20%26%20more

// Works with any method
await api.post('/reports', { type: 'monthly' }, {
  params: { format: 'pdf' },
});
```

## Per-Request Headers {#per-request-headers}

Pass `headers` in the options to add or override headers for a single request:

```ts
// Override Content-Type for a single request
await api.post('/upload', binaryData, {
  headers: { 'Content-Type': 'application/octet-stream' },
});

// Add API version header
const v2Data = await api.get('/users', {
  headers: { 'X-API-Version': '2' },
});

// Per-request headers merge with (and override) default headers
api.configure({ headers: { 'X-App': 'my-app' } });
await api.get('/data', { headers: { 'X-App': 'override' } });
// Sends X-App: override (not my-app)
```

## Authentication {#auth}

When `auth: true`, the API client automatically:

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

The API client automatically handles response content types:

| Response Content-Type | Parsing |
|----------------------|---------|
| `application/json` | Parsed as JSON |
| `text/*` | Returned as string |

## Real-World Examples {#examples}

### Login Flow with Token Storage

```ts
import { api, signal, html, navigate } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

// Redirect on 401
api.intercept('response', (res) => {
  if (res.status === 401) navigate('/login');
  return res;
});

const email = signal('');
const password = signal('');
const error = signal('');
const loading = signal(false);

async function login() {
  loading.value = true;
  error.value = '';
  try {
    const result = await api.post('/login', {
      email: email.value,
      password: password.value,
    });
    // Token is auto-saved via FreshToken header
    navigate('/dashboard');
  } catch (err) {
    error.value = err.data?.message || 'Login failed';
  } finally {
    loading.value = false;
  }
}

const view = html`
  <form @submit=${(e) => { e.preventDefault(); login(); }}>
    <input type="email" .value=${email}
           @input=${(e) => { email.value = e.target.value; }}
           placeholder="Email">
    <input type="password" .value=${password}
           @input=${(e) => { password.value = e.target.value; }}
           placeholder="Password">
    ${() => error.value ? html`<p class="error">${error}</p>` : null}
    <button ?disabled=${() => loading.value}>
      ${() => loading.value ? 'Logging in...' : 'Login'}
    </button>
  </form>
`;
```

### CRUD Data Table with Search and Pagination

```ts
import { api, signal, computed, effect, html } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

const users = signal([]);
const search = signal('');
const page = signal(1);
const totalPages = signal(1);
const loading = signal(false);

// Fetch users whenever search or page changes
effect(() => {
  const q = search.value;
  const p = page.value;
  loading.value = true;

  api.get('/users', {
    params: { q, page: p, limit: 20 },
  }).then(res => {
    users.value = res.data;
    totalPages.value = res.totalPages;
    loading.value = false;
  });
});

async function deleteUser(id) {
  if (!confirm('Delete this user?')) return;
  await api.delete(`/users/${id}`);
  // Refresh list
  users.value = users.value.filter(u => u.id !== id);
}

const view = html`
  <div>
    <input placeholder="Search users..."
           @input=${(e) => { search.value = e.target.value; page.value = 1; }}>

    ${() => loading.value
      ? html`<p>Loading...</p>`
      : html`<table>
          <thead><tr><th>Name</th><th>Email</th><th></th></tr></thead>
          <tbody>
            ${() => users.value.map(u => html`
              <tr>
                <td>${u.name}</td>
                <td>${u.email}</td>
                <td><button @click=${() => deleteUser(u.id)}>Delete</button></td>
              </tr>
            `)}
          </tbody>
        </table>`
    }

    <div class="pagination">
      <button ?disabled=${() => page.value <= 1}
              @click=${() => { page.value--; }}>Prev</button>
      <span>${page} / ${totalPages}</span>
      <button ?disabled=${() => page.value >= totalPages.value}
              @click=${() => { page.value++; }}>Next</button>
    </div>
  </div>
`;
```

### File Upload with Progress Headers

```ts
const file = signal(null);
const uploading = signal(false);

async function upload() {
  if (!file.value) return;
  uploading.value = true;
  const formData = new FormData();
  formData.append('file', file.value);

  try {
    const result = await api.post('/upload', formData, {
      headers: { 'X-Upload-Name': file.value.name },
    });
    alert('Uploaded: ' + result.url);
  } catch (err) {
    alert('Upload failed: ' + err.data?.message);
  } finally {
    uploading.value = false;
  }
}

const view = html`
  <div>
    <input type="file" @change=${(e) => { file.value = e.target.files[0]; }}>
    <button @click=${upload} ?disabled=${() => !file.value || uploading.value}>
      ${() => uploading.value ? 'Uploading...' : 'Upload'}
    </button>
  </div>
`;
```

### Dashboard with Polling

```ts
import { api, signal, effect, html } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

const stats = signal({ users: 0, orders: 0, revenue: 0 });

// Poll every 30 seconds
async function fetchStats() {
  try {
    stats.value = await api.get('/dashboard/stats');
  } catch (err) {
    console.error('Stats fetch failed:', err);
  }
}

fetchStats(); // initial load
setInterval(fetchStats, 30000);

const view = html`
  <div class="dashboard">
    <div class="card">
      <h3>Users</h3>
      <span>${() => stats.value.users}</span>
    </div>
    <div class="card">
      <h3>Orders</h3>
      <span>${() => stats.value.orders}</span>
    </div>
    <div class="card">
      <h3>Revenue</h3>
      <span>${() => '$' + stats.value.revenue.toLocaleString()}</span>
    </div>
  </div>
`;
```
