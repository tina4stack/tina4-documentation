# Backend Integration

tina4-js is designed to embed seamlessly inside tina4-php and tina4-python projects. The CLI can build your frontend directly into the backend's directory structure.

## Build Targets {#targets}

### Standalone SPA

```bash
npx tina4 build
```

Outputs to `dist/` — deploy as a static site on any web server.

### tina4-php

```bash
npx tina4 build --target php
```

**What it does:**
1. Builds JS to `src/public/js/`
2. Generates `src/templates/index.twig` from your `index.html`
3. Adds a server-side state injection point to the template

**Directory result:**
```
your-tina4-php-project/
├── .env
├── src/
│   ├── public/
│   │   └── js/
│   │       └── tina4.es.js       ← built frontend
│   └── templates/
│       └── index.twig            ← generated template
```

**Required `.env` settings:**
```env
TINA4_APP_DOCUMENT_ROOT=src/public
TINA4_APP_INDEX=../templates/index.twig
```

### tina4-python

```bash
npx tina4 build --target python
```

**What it does:**
1. Builds JS to `src/public/js/`
2. Generates `src/templates/index.twig`
3. Generates `src/routes/spa.py` — a catch-all route for SPA client-side routing

**Directory result:**
```
your-tina4-python-project/
├── .env
├── src/
│   ├── public/
│   │   └── js/
│   │       └── tina4.es.js
│   ├── routes/
│   │   └── spa.py                ← catch-all route
│   └── templates/
│       └── index.twig
```

**Generated catch-all route (`spa.py`):**
```python
from tina4_python import get
from tina4_python.Template import Template

@get("/{path:path}")
async def spa_catchall(path, request, response):
    """Catch-all for SPA client-side routing"""
    return response(Template.render_twig_template(
        "index.twig", {"request": request}
    ))
```

## Server-Side State Injection {#state-injection}

The generated `index.twig` template includes a state injection point:

```html
<script>
  window.__TINA4_STATE__ = {{ initialState | json_encode | raw }};
</script>
```

Pass initial state from your backend:

**PHP:**
```php
<?php
$initialState = [
    'user' => ['name' => 'Andre', 'role' => 'admin'],
    'config' => ['theme' => 'dark'],
];
```

**Python:**
```python
initial_state = {
    "user": {"name": "Andre", "role": "admin"},
    "config": {"theme": "dark"},
}
```

**Read in JavaScript:**
```ts
import { signal } from 'tina4js';

const serverState = (window as any).__TINA4_STATE__ || {};
const user = signal(serverState.user || null);
const config = signal(serverState.config || {});
```

## Authentication Flow {#auth-flow}

tina4-js API wrapper uses the same auth protocol as tina4-php and tina4-python:

| Feature | How it works |
|---------|-------------|
| **Bearer token** | Sent as `Authorization: Bearer <token>` on every request |
| **formToken** | Injected into POST/PUT/PATCH/DELETE body |
| **Token rotation** | `FreshToken` response header updates the stored token |
| **Storage** | `localStorage` with configurable key (default: `tina4_token`) |

### Login Example

```ts
import { api, navigate } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

async function login(email: string, password: string) {
  try {
    const result = await api.post('/login', { email, password });
    // FreshToken header auto-saves the JWT to localStorage
    navigate('/dashboard');
  } catch (err) {
    console.error('Login failed:', err);
  }
}
```

### Auth Interceptor

```ts
api.intercept('response', (res) => {
  if (res.status === 401) {
    localStorage.removeItem('tina4_token');
    navigate('/login');
  }
  return res;
});
```

## Development Proxy {#proxy}

During development, proxy API calls to your tina4 backend:

```ts
// vite.config.ts
import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 3000,
    proxy: {
      '/api': 'http://localhost:7145',  // tina4-php/python default port
    },
  },
});
```

This lets your frontend dev server (port 3000) forward `/api/*` requests to the tina4 backend (port 7145).

## Deployment Modes {#modes}

| Mode | Description | Use case |
|------|-------------|----------|
| **Standalone SPA** | Static files in `dist/` | CDN, static hosting |
| **Embedded in PHP** | JS in `src/public/js/`, Twig template | Full-stack PHP app |
| **Embedded in Python** | JS in `src/public/js/`, Twig + catch-all route | Full-stack Python app |
| **Islands** | Import tina4-js components into server-rendered pages | Progressive enhancement |

### Islands Mode

You can use tina4-js components inside existing server-rendered pages without a full SPA:

```html
<!-- Server-rendered page (Twig/Jinja2) -->
<h1>Server-rendered content</h1>

<!-- Island of interactivity -->
<script type="module">
  import { signal, html } from '/js/tina4.es.js';

  const count = signal(0);
  const counter = html`
    <button @click=${() => count.value++}>Clicks: ${count}</button>
  `;
  document.getElementById('counter-island').appendChild(counter);
</script>

<div id="counter-island"></div>
```
