# Chapter 6: API

## Talking to Your Backend

Your frontend renders a list of users. The data lives in a database. Between your signal and that database sits an HTTP request -- and a surprising amount of ceremony. Auth headers. CSRF tokens. Token rotation. Error handling. JSON parsing. In most projects, you install Axios or ky, configure interceptors, and write wrapper functions before you make your first call.

tina4-js includes all of this. One import. No extra packages. If you use a tina4-php or tina4-python backend, auth and CSRF protection wire up with a single configuration flag.

---

## 1. The API Client

The built-in HTTP client wraps `fetch()` with the features you need in every application:

- Automatic `Authorization: Bearer` headers
- Token rotation via `FreshToken` response headers
- CSRF `formToken` injection in POST/PUT/PATCH/DELETE bodies
- Per-request headers and query params
- Request and response interceptors
- JSON parsing by default

```typescript
import { api } from 'tina4js';
```

One import. No Axios. No ky. No dependencies. The API client ships with the framework.

---

## 2. Configuration

Call `api.configure()` once at app startup:

```typescript
api.configure({
  baseUrl: 'https://api.example.com',
  auth: true,
});
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `baseUrl` | `string` | `''` | Prepended to all request paths |
| `auth` | `boolean` | `false` | Enable Bearer token and formToken |
| `tokenKey` | `string` | `'tina4_token'` | localStorage key for the auth token |
| `headers` | `Record<string, string>` | `{}` | Default headers on every request |

A typical setup for a tina4-php backend:

```typescript
api.configure({
  baseUrl: '/api',
  auth: true,
  headers: {
    'Accept': 'application/json',
  },
});
```

During development with Vite, proxy API calls to your backend:

```typescript
// vite.config.ts
export default defineConfig({
  server: {
    proxy: {
      '/api': 'http://localhost:7145',
    },
  },
});
```

---

## 3. Making Requests

### GET

```typescript
const users = await api.get('/users');
```

With query parameters:

```typescript
const users = await api.get('/users', {
  params: { page: 2, limit: 20, search: 'alice' },
});
// Request: GET /users?page=2&limit=20&search=alice
```

Parameters are automatically URL-encoded.

### POST

```typescript
await api.post('/users', {
  name: 'Alice',
  email: 'alice@example.com',
  role: 'editor',
});
```

The body is serialized as JSON. The `Content-Type: application/json` header is added automatically.

### PUT (Full Replace)

```typescript
await api.put('/users/42', {
  name: 'Alice',
  email: 'alice@new-email.com',
  role: 'admin',
});
```

### PATCH (Partial Update)

```typescript
await api.patch('/users/42', {
  role: 'admin',
});
```

### DELETE

```typescript
await api.delete('/users/42');
```

---

## 4. RequestOptions

Every method accepts an optional `RequestOptions` object:

```typescript
interface RequestOptions {
  headers?: Record<string, string>;
  params?: Record<string, string | number | boolean>;
}
```

### Per-Request Headers

```typescript
const data = await api.get('/reports/export', {
  headers: {
    'Accept': 'text/csv',
    'X-Custom': 'value',
  },
});
```

Per-request headers merge with (and override) the default headers from `configure()`.

### Query Params on Any Method

```typescript
await api.post('/search', { query: 'tina4' }, {
  params: { format: 'detailed', lang: 'en' },
});
// POST /search?format=detailed&lang=en
// Body: { "query": "tina4" }
```

---

## 5. Auth Flow

One flag -- `auth: true` -- activates three mechanisms that handle authentication for every request your application makes:

### 1. Bearer Token

Every request includes an `Authorization` header:

```
Authorization: Bearer <token>
```

The token is read from `localStorage` using the `tokenKey` (default: `'tina4_token'`).

### 2. formToken

For POST, PUT, PATCH, and DELETE requests, a `formToken` property is injected into the JSON body:

```typescript
// You send:
await api.post('/users', { name: 'Alice' });

// Actual request body:
{ "name": "Alice", "formToken": "the-current-token" }
```

This is CSRF protection for tina4-php and tina4-python backends. They validate the `formToken` on every write operation.

### 3. FreshToken Rotation

When the server responds with a `FreshToken` header, the client automatically stores it:

```
HTTP/1.1 200 OK
FreshToken: new-jwt-token-here
```

The new token replaces the old one in `localStorage` and is used for subsequent requests. This allows the backend to rotate tokens on every request or on a schedule.

### Login Example

```typescript
import { api, navigate, signal } from 'tina4js';

const loginError = signal<string | null>(null);

async function login(email: string, password: string) {
  try {
    const result = await api.post<{ token: string }>('/auth/login', {
      email,
      password,
    });

    // Store the token (the API client reads it from localStorage)
    localStorage.setItem('tina4_token', result.token);

    navigate('/dashboard');
  } catch (err: any) {
    loginError.value = err.data?.message ?? 'Login failed';
  }
}
```

---

## 6. Error Handling

A 404. A 500. A network timeout. Every API call can fail, and your application needs to handle the failure without crashing. When the server returns a non-2xx status, `api` throws the response object:

```typescript
try {
  await api.get('/users/999');
} catch (err: any) {
  console.log(err.status);  // 404
  console.log(err.data);    // { message: "User not found" }
  console.log(err.ok);      // false
}
```

The thrown object has the `ApiResponse` shape:

```typescript
interface ApiResponse<T = unknown> {
  status: number;
  data: T;
  ok: boolean;
  headers: Headers;
}
```

### Pattern: Centralized Error Handling with Interceptors

```typescript
api.intercept('response', (response) => {
  if (response.status === 401) {
    localStorage.removeItem('tina4_token');
    navigate('/login');
  }
  if (response.status === 403) {
    navigate('/unauthorized');
  }
});
```

---

## 7. Interceptors

Every request passes through a pipeline. Interceptors let you insert logic at two points: before the request leaves and after the response arrives. Add a client version header to every request. Unwrap a response envelope. Log slow calls. Redirect on 401. Interceptors handle all of it in one place.

### Request Interceptor

```typescript
api.intercept('request', (config) => {
  // Add a custom header to every request
  config.headers['X-Client-Version'] = '1.0.0';

  // Add a timestamp
  config.headers['X-Request-Time'] = new Date().toISOString();
});
```

The `config` parameter is a `RequestInit` with a `headers` record. Modify it in place or return a new object.

### Response Interceptor

```typescript
api.intercept('response', (response) => {
  // Log slow requests
  if (response.status === 200) {
    console.log(`API: ${response.status}`);
  }

  // Transform data
  if (response.data && typeof response.data === 'object') {
    // unwrap a common envelope
    const envelope = response.data as any;
    if (envelope.data) {
      return { ...response, data: envelope.data };
    }
  }
});
```

Return a modified response to transform the data before it reaches your application code. Return nothing (or `undefined`) to pass the response through unchanged.

---

## 8. Real Example: CRUD Data Table

A list of users. Add one. Edit one. Delete one. This is the bread and butter of business applications, and it exercises every feature of the API client -- GET for loading, POST for creating, PUT for updating, DELETE for removing, batch for coordinating signal updates:

```typescript
import { signal, computed, html, api, batch } from 'tina4js';

interface User {
  id: number;
  name: string;
  email: string;
}

function usersPage() {
  const users = signal<User[]>([], 'users');
  const loading = signal(true, 'users-loading');
  const editingId = signal<number | null>(null);
  const editName = signal('');
  const editEmail = signal('');

  // Load users
  async function loadUsers() {
    loading.value = true;
    try {
      const data = await api.get<User[]>('/users');
      users.value = data;
    } finally {
      loading.value = false;
    }
  }

  // Create
  async function createUser(name: string, email: string) {
    const newUser = await api.post<User>('/users', { name, email });
    users.value = [...users.value, newUser];
  }

  // Update
  async function updateUser(id: number) {
    const updated = await api.put<User>(`/users/${id}`, {
      name: editName.value,
      email: editEmail.value,
    });
    batch(() => {
      users.value = users.value.map(u => u.id === id ? updated : u);
      editingId.value = null;
    });
  }

  // Delete
  async function deleteUser(id: number) {
    await api.delete(`/users/${id}`);
    users.value = users.value.filter(u => u.id !== id);
  }

  // Start editing
  function startEdit(user: User) {
    batch(() => {
      editingId.value = user.id;
      editName.value = user.name;
      editEmail.value = user.email;
    });
  }

  // Initial load
  loadUsers();

  return html`
    <div>
      <h1>Users</h1>

      ${() => loading.value
        ? html`<p>Loading...</p>`
        : html`
            <table>
              <thead>
                <tr><th>Name</th><th>Email</th><th>Actions</th></tr>
              </thead>
              <tbody>
                ${() => users.value.map(user => html`
                  <tr>
                    ${() => editingId.value === user.id
                      ? html`
                          <td>
                            <input .value=${editName}
                              @input=${(e: Event) => { editName.value = (e.target as HTMLInputElement).value; }} />
                          </td>
                          <td>
                            <input .value=${editEmail}
                              @input=${(e: Event) => { editEmail.value = (e.target as HTMLInputElement).value; }} />
                          </td>
                          <td>
                            <button @click=${() => updateUser(user.id)}>Save</button>
                            <button @click=${() => { editingId.value = null; }}>Cancel</button>
                          </td>
                        `
                      : html`
                          <td>${user.name}</td>
                          <td>${user.email}</td>
                          <td>
                            <button @click=${() => startEdit(user)}>Edit</button>
                            <button @click=${() => deleteUser(user.id)}>Delete</button>
                          </td>
                        `
                    }
                  </tr>
                `)}
              </tbody>
            </table>
          `
      }

      <h2>Add User</h2>
      <form @submit=${(e: Event) => {
        e.preventDefault();
        const form = e.target as HTMLFormElement;
        const formData = new FormData(form);
        createUser(formData.get('name') as string, formData.get('email') as string);
        form.reset();
      }}>
        <input name="name" placeholder="Name" required />
        <input name="email" type="email" placeholder="Email" required />
        <button type="submit">Add</button>
      </form>
    </div>
  `;
}
```

---

## 9. File Upload

The API client sends JSON by default. Files are not JSON. For file uploads, use `fetch()` with the same base URL and auth token. The browser sets the correct `Content-Type` with multipart boundaries -- do not set it yourself:

```typescript
async function uploadFile(file: File) {
  const formData = new FormData();
  formData.append('file', file);

  const token = localStorage.getItem('tina4_token');

  const response = await fetch('/api/upload', {
    method: 'POST',
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: formData, // Do NOT set Content-Type -- browser sets it with boundary
  });

  return response.json();
}
```

Use in a template:

```typescript
html`
  <input type="file" @change=${(e: Event) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (file) uploadFile(file);
  }} />
`
```

---

## Summary

| What | How |
|---|---|
| Configure | `api.configure({ baseUrl, auth, tokenKey, headers })` |
| GET | `api.get(path, options?)` |
| POST | `api.post(path, body?, options?)` |
| PUT | `api.put(path, body?, options?)` |
| PATCH | `api.patch(path, body?, options?)` |
| DELETE | `api.delete(path, options?)` |
| Query params | `{ params: { key: value } }` |
| Per-request headers | `{ headers: { key: value } }` |
| Auth token | Automatic Bearer header when `auth: true` |
| Token rotation | Automatic via FreshToken response header |
| CSRF protection | Automatic formToken in POST/PUT/PATCH/DELETE |
| Error handling | Non-2xx throws `ApiResponse` |
| Request interceptor | `api.intercept('request', fn)` |
| Response interceptor | `api.intercept('response', fn)` |
