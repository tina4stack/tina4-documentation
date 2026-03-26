# Chapter 5: Routing

## Navigation Without the Router Library

A user clicks "Dashboard." The page goes white. A full HTML document loads from the server. The CSS re-parses. The JavaScript re-executes. The user waits.

Single-page applications fix this. The browser stays on one HTML page. JavaScript swaps content in and out. The URL changes, but the page never reloads. Navigation feels instant because it is -- only the content that changed gets replaced.

tina4-js gives you this in about 20 lines of routing code. Parameterized routes. Guards that protect pages. A 404 catch-all. Programmatic navigation. No separate router library to install.

---

## 1. How Routing Works

The tina4-js router follows three steps:

1. You call `route(pattern, handler)` to register paths
2. You call `router.start({ target, mode })` to start listening
3. When the URL changes, the router finds the matching route, calls the handler, and renders the result into the target element

No file-based routing. No dynamic imports by convention. No data loaders. You register routes with explicit calls, and the router invokes your handler function when the URL matches.

---

## 2. Registering Routes

```typescript
import { route, html } from 'tina4js';

route('/', () => html`<h1>Home</h1>`);
route('/about', () => html`<h1>About</h1>`);
route('/contact', () => html`<h1>Contact</h1>`);
```

**Pattern is always the first argument.** This is a convention across all tina4 frameworks. Do not swap the arguments.

The handler is a function that returns content. It can return:

- A `DocumentFragment` (from `html` tagged templates)
- A `Node` (any DOM node)
- A `string` (set as innerHTML)
- A `Promise` that resolves to any of the above (async routes)

---

## 3. Route Parameters

Use `{param}` syntax in patterns to capture URL segments:

```typescript
route('/users/{id}', ({ id }) => {
  return html`<h1>User ${id}</h1>`;
});

route('/posts/{year}/{slug}', ({ year, slug }) => {
  return html`<h1>${slug} (${year})</h1>`;
});
```

Parameters are extracted from the URL and passed to the handler as a `Record<string, string>`. All values are strings -- cast them yourself if you need numbers:

```typescript
route('/products/{id}', ({ id }) => {
  const productId = parseInt(id, 10);
  return html`<product-detail id="${productId}"></product-detail>`;
});
```

### How Matching Works

The router converts `{param}` to `([^/]+)` regex groups:

- `/users/{id}` matches `/users/42`, `/users/alice`, `/users/abc-123`
- `/posts/{year}/{slug}` matches `/posts/2024/my-post`
- It does not match `/users/` (trailing slash, no id) or `/users/42/edit` (extra segment)

Routes are checked in registration order. The first match wins. Put specific routes before general ones.

---

## 4. The Wildcard -- 404 Routes

```typescript
route('*', () => html`
  <div>
    <h1>404</h1>
    <p>Page not found.</p>
    <a href="/">Go home</a>
  </div>
`);
```

The `*` pattern matches any path. Register it last so it only catches URLs that no other route matched.

---

## 5. Route Guards

A user types `/admin` into the address bar. They are not logged in. They should never see that page. Without guards, the handler runs, the admin panel renders, and your application has a security hole.

Guards protect routes. A guard runs before the handler. It can:

- Return `true` to allow navigation
- Return `false` to block navigation (nothing happens)
- Return a string to redirect to that path

```typescript
import { route, html, signal, computed } from 'tina4js';

const token = signal<string | null>(null);
const isLoggedIn = computed(() => token.value !== null);

// Protected route
route('/dashboard', {
  guard: () => isLoggedIn.value || '/login',
  handler: () => html`<h1>Dashboard</h1>`,
});

// Login page
route('/login', () => {
  return html`
    <div>
      <h1>Login</h1>
      <button @click=${() => { token.value = 'abc123'; }}>
        Log In
      </button>
    </div>
  `;
});
```

When a user navigates to `/dashboard`:

1. The guard runs: `isLoggedIn.value || '/login'`
2. If `isLoggedIn` is `true`, the guard returns `true` and the handler renders
3. If `isLoggedIn` is `false`, `false || '/login'` returns `'/login'` -- the router redirects

The redirect uses `navigate(path, { replace: true })`, so the protected URL does not appear in browser history. The user cannot press Back to get to the guarded page.

### Admin Guard Pattern

```typescript
const user = signal<{ role: string } | null>(null);

route('/admin', {
  guard: () => {
    if (!user.value) return '/login';
    if (user.value.role !== 'admin') return '/unauthorized';
    return true;
  },
  handler: () => html`<admin-panel></admin-panel>`,
});
```

---

## 6. Starting the Router

```typescript
import { router } from 'tina4js';

router.start({
  target: '#root',
  mode: 'history',
});
```

### target

A CSS selector for the element where route content renders. The router finds this element with `document.querySelector()`. If the element does not exist, the router throws.

```html
<body>
  <nav>...</nav>
  <main id="root"></main>  <!-- routes render here -->
  <footer>...</footer>
</body>
```

### mode

Two options:

| Mode | URLs | Requires |
|---|---|---|
| `'history'` | `/about`, `/users/42` | Server-side URL rewriting |
| `'hash'` | `/#/about`, `/#/users/42` | Nothing -- works everywhere |

**Hash mode** is the default in scaffolded projects. URLs carry a `#` prefix. No server configuration needed. Works on static hosts, GitHub Pages, S3, anywhere you can drop files.

**History mode** gives clean URLs without the hash. But the server must return `index.html` for all routes. When a user bookmarks `https://myapp.com/users/42` and loads it, the server needs to serve the SPA -- not search for a `/users/42` file that does not exist.

Vite dev server handles this automatically. For production, configure your web server:

```nginx
# Nginx
location / {
  try_files $uri /index.html;
}
```

```apache
# Apache (.htaccess)
RewriteEngine On
RewriteRule ^index\.html$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
```

---

## 7. Programmatic Navigation

```typescript
import { navigate } from 'tina4js';

// Push to history (user can press Back)
navigate('/dashboard');

// Replace current history entry (no Back)
navigate('/login', { replace: true });
```

Use `navigate()` in event handlers, after API calls, in guards -- anywhere you need to move the user to a different page.

```typescript
const handleLogin = async () => {
  const success = await api.post('/auth/login', credentials);
  if (success) {
    navigate('/dashboard');
  }
};
```

### Link Interception

The router automatically intercepts clicks on `<a>` tags with same-origin `href` attributes. You do not need a special `<Link>` component:

```typescript
html`<a href="/about">About</a>`
// Clicking this navigates without a page reload
```

The router ignores:

- Links with `target="_blank"` or any `target` attribute
- Links with the `download` attribute
- Links with `rel="external"`
- Modified clicks (Ctrl+click, Cmd+click, Shift+click, Alt+click)
- Links to different origins (external URLs)

---

## 8. Route Change Events

Listen for navigation events:

```typescript
import { router } from 'tina4js';

const unsubscribe = router.on('change', ({ path, params, pattern, durationMs }) => {
  console.log(`Navigated to ${path} (matched ${pattern}) in ${durationMs}ms`);
  console.log('Params:', params);
});

// Later, to stop listening:
unsubscribe();
```

The change event includes:

| Property | Type | Description |
|---|---|---|
| `path` | `string` | The current URL path |
| `params` | `Record<string, string>` | Extracted route parameters |
| `pattern` | `string` | The matched route pattern |
| `durationMs` | `number` | Time to render the route (ms) |

Use this for analytics, breadcrumbs, active nav highlighting, or debugging:

```typescript
// Analytics
router.on('change', ({ path }) => {
  analytics.pageView(path);
});

// Active nav highlighting
const currentPath = signal('/');
router.on('change', ({ path }) => {
  currentPath.value = path;
});

html`
  <nav>
    <a href="/" class=${() => currentPath.value === '/' ? 'active' : ''}>Home</a>
    <a href="/about" class=${() => currentPath.value === '/about' ? 'active' : ''}>About</a>
  </nav>
`
```

---

## 9. Async Routes

A user profile page needs data from the server. You cannot render the page until the data arrives. Route handlers can be async -- the router awaits the result before rendering:

```typescript
route('/users/{id}', async ({ id }) => {
  const user = await api.get(`/users/${id}`);
  return html`
    <div>
      <h1>${user.name}</h1>
      <p>${user.email}</p>
    </div>
  `;
});
```

If the user navigates away before the async handler resolves, the stale result is discarded. The router tracks a version counter and renders only if the version matches. No race conditions. No stale data flashing on screen.

### Loading States

For a better user experience, show a loading indicator:

```typescript
route('/users/{id}', async ({ id }) => {
  const loading = signal(true);
  const user = signal<any>(null);

  // Show loading immediately
  const view = html`
    <div>
      ${() => loading.value
        ? html`<p>Loading...</p>`
        : html`
            <h1>${() => user.value?.name}</h1>
            <p>${() => user.value?.email}</p>
          `
      }
    </div>
  `;

  // Fetch in background
  api.get(`/users/${id}`).then(data => {
    user.value = data;
    loading.value = false;
  });

  return view;
});
```

---

## 10. Effect Cleanup on Route Change

You create a signal and an effect on one route. The user navigates away. Without cleanup, that effect keeps running -- updating state for a page that no longer exists, consuming memory for nodes that have been removed from the DOM.

The router handles this. When a route changes, effects created during the previous route's rendering are disposed. No memory leaks. No ghost updates.

```typescript
route('/live', () => {
  const count = signal(0);

  // This effect is automatically cleaned up when the user navigates away
  effect(() => {
    const interval = setInterval(() => {
      count.value++;
    }, 1000);

    // But setInterval is NOT cleaned up automatically -- you need to handle that
  });

  return html`<p>Count: ${count}</p>`;
});
```

The router disposes the effect (unsubscribes from signals), but it cannot clean up timers, event listeners, or other resources you created outside the signal system. For those, use `onUnmount()` in a component, or track cleanup manually. The rule: if the router did not create it, the router cannot destroy it.

---

## 11. Complete Example -- Multi-Page App

```typescript
// src/store.ts
import { signal, computed } from 'tina4js';

export const token = signal<string | null>(null, 'auth-token');
export const isLoggedIn = computed(() => token.value !== null);

// src/routes/index.ts
import { route, navigate, html, signal } from 'tina4js';
import { token, isLoggedIn } from '../store';

// Public routes
route('/', () => html`
  <div>
    <h1>Home</h1>
    <nav>
      <a href="/about">About</a>
      ${() => isLoggedIn.value
        ? html`<a href="/dashboard">Dashboard</a>`
        : html`<a href="/login">Login</a>`
      }
    </nav>
  </div>
`);

route('/about', () => html`
  <div>
    <h1>About</h1>
    <a href="/">Back</a>
  </div>
`);

// Login
route('/login', () => {
  const email = signal('');
  const password = signal('');

  return html`
    <div>
      <h1>Login</h1>
      <form @submit=${(e: Event) => {
        e.preventDefault();
        // Fake login
        token.value = 'fake-jwt-token';
        navigate('/dashboard');
      }}>
        <input
          type="email"
          placeholder="Email"
          @input=${(e: Event) => { email.value = (e.target as HTMLInputElement).value; }}
        />
        <input
          type="password"
          placeholder="Password"
          @input=${(e: Event) => { password.value = (e.target as HTMLInputElement).value; }}
        />
        <button type="submit">Login</button>
      </form>
    </div>
  `;
});

// Protected routes
route('/dashboard', {
  guard: () => isLoggedIn.value || '/login',
  handler: () => html`
    <div>
      <h1>Dashboard</h1>
      <p>You are logged in.</p>
      <button @click=${() => {
        token.value = null;
        navigate('/');
      }}>Logout</button>
    </div>
  `,
});

// 404
route('*', () => html`
  <div>
    <h1>404</h1>
    <a href="/">Go home</a>
  </div>
`);

// src/main.ts
import { router } from 'tina4js';
import './routes/index';

router.start({ target: '#root', mode: 'hash' });
```

---

## Summary

| What | How |
|---|---|
| Register route | `route(pattern, handler)` |
| Route params | `route('/users/{id}', ({ id }) => ...)` |
| Guard | `route('/x', { guard: () => bool\|string, handler })` |
| Wildcard/404 | `route('*', handler)` |
| Start router | `router.start({ target: '#root', mode: 'history' })` |
| Navigate | `navigate('/path')` |
| Replace (no back) | `navigate('/path', { replace: true })` |
| Listen for changes | `router.on('change', ({ path, params, pattern, durationMs }) => ...)` |
| Async routes | Handler returns a `Promise` |
| Link interception | Automatic for same-origin `<a href>` |
