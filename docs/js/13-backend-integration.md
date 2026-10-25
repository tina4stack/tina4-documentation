# Backend Integration

## The Full Stack

Your frontend fetches data. Your backend serves it. Between them sits authentication, CSRF protection, token rotation, and the question every team asks: how do we wire these two together without it becoming a mess?

This chapter answers that question. You will connect tina4-js to tina4-php and tina4-python backends, follow the auth flow from login to token expiry, build for backend embedding, and add interactive islands to server-rendered pages.

---

## 1. The Tina4 Stack

tina4-js was built to pair with tina4-php and tina4-python. The API client speaks their protocol:

- `Authorization: Bearer <token>` on every request when auth is enabled
- `formToken` injected into POST/PUT/PATCH/DELETE bodies for CSRF protection
- `FreshToken` response header read for token rotation
- JSON in, JSON out

But tina4-js works with any backend that sends JSON and accepts Bearer tokens. The API client is a `fetch()` wrapper with opinions. If your backend follows REST conventions, tina4-js connects to it without modification.

---

## 2. tina4-js + tina4-php

### Setup

Backend (tina4-php):

```bash
tina4 init php my-backend
cd my-backend
tina4 serve
# Running on http://localhost:7145
```

Frontend (tina4-js):

```bash
tina4 init js my-frontend
cd my-frontend
```

> In npm-only environments where the `tina4` Rust CLI isn't available, the fallback is `npx tina4js create my-frontend`.

tina4-js builds on esbuild, whose dev server does not proxy. The simplest integration is the **integrated build**: `tina4js build --target php` (or `--target python`) bundles the frontend straight into the backend's `src/public/js/` and generates `index.twig`, so the backend serves both the app and the API from one origin - no proxy, no CORS.

```bash
tina4 serve            # backend + built frontend, one origin
# or, during frontend development:
npm run dev            # tina4js dev (esbuild) on http://localhost:3000
```

Configure the API client:

```typescript
// src/main.ts
import { api, router } from 'tina4js';
import './routes/index';

api.configure({
  baseUrl: '/api',
  auth: true,
});

router.start({ target: '#root', mode: 'history' });
```

With the integrated build (`tina4js build --target php`) the backend serves the app, so `api.get('/users')` is a same-origin request and no CORS headers are needed. If you instead run a SEPARATE frontend dev server (`npm run dev`), point `baseUrl` at the backend (`http://localhost:7145/api`) and enable CORS there - every Tina4 backend ships a CORS middleware.

### tina4-php Routes

```php
// src/routes/users.php
\Tina4\Get::add("/api/users", function(\Tina4\Response $response) {
    $users = (new User())->select("*")->asArray();
    return $response($users);
});

\Tina4\Post::add("/api/users", function(\Tina4\Response $response, \Tina4\Request $request) {
    $user = new User();
    $user->name = $request->data->name;
    $user->email = $request->data->email;
    $user->save();
    return $response($user->asArray());
});
```

### tina4-js Frontend

```typescript
// src/routes/users.ts
import { route, html, signal, api } from 'tina4js';

route('/users', async () => {
  const users = signal<any[]>([]);
  users.value = await api.get('/users');

  return html`
    <h1>Users</h1>
    <ul>
      ${() => users.value.map(u => html`<li>${u.name} (${u.email})</li>`)}
    </ul>
  `;
});
```

The backend defines the endpoints. The frontend consumes them. The proxy bridges the ports during development. In production, they share the same origin.

---

## 3. tina4-js + tina4-python

### Setup

Backend (tina4-python):

```bash
tina4 init python my-backend
cd my-backend
tina4 serve
# Running on http://localhost:7146
```

The API configuration is identical to the PHP setup. For the Python backend, use `tina4js build --target python` (same origin), or point `baseUrl` at `http://localhost:7146/api` and enable CORS there for a separate dev server.

### tina4-python Routes

```python
# src/routes/users.py
from tina4_python import get, post

@get("/api/users")
async def get_users(request, response):
    users = User().select("*").as_list()
    return response(users)

@post("/api/users")
async def create_user(request, response):
    user = User()
    user.name = request.body.get("name")
    user.email = request.body.get("email")
    user.save()
    return response(user.as_dict())
```

The frontend code is the same whether the backend runs PHP or Python. The API client does not care what language processes the request. It sends JSON. It receives JSON. The language behind the endpoint is invisible to the browser.

---

## 4. Authentication End-to-End

Here is the complete auth flow, from login to token expiry, in five steps.

### Step 1: Login

The frontend sends credentials:

```typescript
const result = await api.post<{ token: string }>('/api/auth/login', {
  email: 'alice@example.com',
  password: 'secret',
});
localStorage.setItem('tina4_token', result.token);
```

The backend validates and returns a JWT:

```php
// tina4-php
\Tina4\Post::add("/api/auth/login", function($response, $request) {
    $user = (new User())->find("email = '{$request->data->email}'");
    if ($user && password_verify($request->data->password, $user->password)) {
        $token = \Tina4\Auth::generateToken(["userId" => $user->id]);
        return $response(["token" => $token]);
    }
    return $response(["error" => "Invalid credentials"], 401);
});
```

### Step 2: Authenticated Requests

With `auth: true`, every request now includes:

```
Authorization: Bearer <the-jwt-token>
```

For POST/PUT/PATCH/DELETE, the body also includes:

```json
{ "name": "Alice", "formToken": "<the-jwt-token>" }
```

The backend validates both the header and the body token. Two layers of verification. The header proves identity. The body token prevents CSRF.

### Step 3: Token Rotation

Tokens expire. The backend can issue a fresh token on any response by sending a `FreshToken` header:

```php
$freshToken = \Tina4\Auth::generateToken(["userId" => $user->id]);
$response->addHeader("FreshToken", $freshToken);
return $response($data);
```

The API client stores the fresh token in localStorage. The next request uses the new token. The user never sees a login prompt as long as they stay active. Token rotation happens in the background, invisible and automatic.

### Step 4: Route Guards

Protect frontend routes:

```typescript
import { signal, computed } from 'tina4js';

const token = signal<string | null>(
  localStorage.getItem('tina4_token'),
  'auth-token'
);

const isLoggedIn = computed(() => token.value !== null);

route('/dashboard', {
  guard: () => isLoggedIn.value || '/login',
  handler: dashboardPage,
});
```

The guard runs before the route handler. If `isLoggedIn` is false, the router redirects to `/login`. The dashboard page never renders. The handler never executes. Guards are the frontend's first line of defense.

### Step 5: 401 Handling

If the token expires and rotation did not happen, the backend returns 401. Handle it with a global interceptor:

```typescript
api.intercept('response', (response) => {
  if (response.status === 401) {
    localStorage.removeItem('tina4_token');
    token.value = null;
    navigate('/login', { replace: true });
  }
});
```

Token gone. Signal cleared. User redirected. One interceptor handles every 401 across every API call in the application. No per-request error handling needed.

---

## 5. Building for Backend Embedding

When your tina4-js app is served by a tina4-php or tina4-python backend (not a separate frontend server), you build the JavaScript bundle and place it where the backend serves static files.

### Build

```bash
# bundle straight into the backend (recommended):
npm run build:php        # or: npm run build:python
# or a standalone bundle in dist/main.js:
npm run build
```

`tina4js build --target php|python` writes the bundle to `src/public/js/` and generates `src/templates/index.twig` that loads it - no manual copy, no bundler config to point at the backend. The plain `npm run build` emits `dist/main.js` for a standalone static deploy.

### The CLI Build Command

The tina4 CLI has a build command with target support:

```bash
npx tina4js build --target php
npx tina4js build --target python
```

This builds and places the output in the conventional location for each backend framework. One command. The files land where the backend expects them.

### Backend Template

The backend serves an HTML page that loads the tina4-js bundle:

```html
<!-- tina4-php: src/templates/index.twig -->
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My App</title>
  <link rel="stylesheet" href="/js/style.css">
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/js/main.js"></script>
</body>
</html>
```

The backend renders this template. The browser loads the JavaScript. The tina4-js router takes over. From the user's perspective, it is a single application. From the developer's perspective, it is two codebases that meet at the HTML page.

---

## 6. Islands Architecture

Most of this book assumes you are building a single-page application where tina4-js controls the entire page. Islands architecture flips that model. The server renders the page. tina4-js controls small, specific sections -- islands of interactivity in a sea of static HTML.

This approach works when:

- You have existing server-rendered pages and want to add interactivity without rewriting them
- You want fast initial loads with progressive enhancement
- SEO matters and you need server-rendered content that search engines can index

### How It Works

1. The backend renders the full HTML page
2. tina4-js components hydrate specific sections
3. Each component is independent -- it manages its own state and DOM

### Example: Adding a Live Search to a Server-Rendered Page

The server renders the page:

```html
<!-- Server-rendered page -->
<div class="product-listing">
  <h1>Products</h1>

  <!-- This island becomes interactive -->
  <product-search api-url="/api/products"></product-search>

  <!-- This stays static -->
  <footer>Copyright 2024</footer>
</div>

<script type="module">
  import { Tina4Element, html, signal, api } from 'tina4js';

  class ProductSearch extends Tina4Element {
    static props = { 'api-url': String };
    static shadow = false;

    render() {
      const query = signal('');
      const results = signal<any[]>([]);

      const search = async () => {
        if (query.value.length < 2) return;
        results.value = await api.get(
          this.prop<string>('api-url').value,
          { params: { q: query.value } }
        );
      };

      return html`
        <div>
          <input
            type="search"
            placeholder="Search products..."
            @input=${(e: Event) => {
              query.value = (e.target as HTMLInputElement).value;
              search();
            }}
          />
          <ul>
            ${() => results.value.map(p => html`
              <li>${p.name} - $${p.price}</li>
            `)}
          </ul>
        </div>
      `;
    }
  }

  customElements.define('product-search', ProductSearch);
</script>
```

The server sends HTML. The browser parses it. When it reaches the `<product-search>` tag, the custom element activates. The search input becomes live. The rest of the page stays static. The server did the heavy lifting. tina4-js added the interactivity.

### Multiple Islands

Each island is a separate component. They do not need to know about each other:

```html
<body>
  <!-- Island 1: Live search -->
  <product-search></product-search>

  <!-- Static server-rendered content -->
  <section class="featured">
    <h2>Featured Products</h2>
    <!-- server-rendered list -->
  </section>

  <!-- Island 2: Shopping cart -->
  <cart-widget></cart-widget>

  <!-- Island 3: Notification bell -->
  <notification-bell user-id="42"></notification-bell>
</body>
```

Each component self-initializes when the browser parses its tag. No router needed. No app shell. No bootstrapping ceremony. Place the tags where you want interactivity. The components wake up on their own.

### Shared State Between Islands

If islands need to share state, use the store pattern from Chapter 4:

```typescript
// store.ts
export const cart = signal<CartItem[]>([], 'cart');
export const cartCount = computed(() => cart.value.length);
```

Both `product-search` (add to cart) and `cart-widget` (display cart) import from the same store. When a user adds an item through the search island, the cart count updates in the cart widget. Two components. One signal. Synchronized without either knowing the other exists.

---

## 7. Development Workflow

### Separate Frontend and Backend

Best for larger projects with dedicated frontend and backend teams.

```
my-project/
  frontend/      # tina4-js project
    src/
    package.json
  backend/       # tina4-php or tina4-python
    src/
```

The frontend dev server runs on `localhost:3000` (esbuild). The backend runs on `localhost:7145`. In dev the backend's CORS middleware allows the cross-origin API calls; for production the frontend builds into the backend (one origin). Each team works in its own directory, its own repository, its own deployment pipeline.

### Embedded Frontend

Best for smaller projects or when one team owns both layers.

```
my-project/
  src/
    routes/        # Backend routes
    templates/     # Backend templates
    orm/           # Backend ORM models
    public/
      js/          # Built tina4-js output goes here
  frontend/        # tina4-js source
    src/
    package.json
```

One repository. One deployment. `tina4js build --target php|python` builds the frontend into the backend's public directory (`src/public/js/`). The backend serves everything. For a team of one or two developers, this is the fastest path from code to production.

---

## Summary

| What | How |
|---|---|
| Dev API access | integrated build (one origin) or CORS on the backend |
| Configure API | `api.configure({ baseUrl: '/api', auth: true })` |
| Auth token | Stored in localStorage, auto-sent as Bearer |
| CSRF token | Auto-injected as `formToken` in request bodies |
| Token rotation | Automatic via `FreshToken` response header |
| 401 handling | Response interceptor redirects to login |
| Build for backend | `npx tina4js build --target php` or `--target python` |
| Islands | Use `Tina4Element` components in server-rendered HTML |
| Shared state | Export signals from a store module |
