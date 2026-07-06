# Tina4 JavaScript - Quick Reference

::: tip 🔥 Sub-3KB core, reactive framework

* Signals for state, `html` tagged templates for rendering, Web Components for reuse
* Client-side routing with `{param}` syntax matching tina4-php/python
* Fetch API wrapper with Bearer + formToken auth compatible with tina4 backends
* PWA support with runtime manifest and service worker generation
* Tree-shakeable: import only what you need
:::

[Installation](index.md#installation) • [Signals](index.md#signals) • [HTML Templates](index.md#html-templates) • [Components](index.md#components) • [Routing](index.md#routing) • [API](index.md#api) • [WebSocket](index.md#websocket) • [SSE](index.md#sse) • [Storage](index.md#storage) • [PWA](index.md#pwa) • [Debug](index.md#debug) • [Backend Integration](index.md#backend-integration) • [Bundle Size](index.md#bundle-size)

### Installation <a href="#installation" id="installation"></a>

```bash
npx tina4js create my-app
cd my-app
npm install
npm run dev
```

[More details](01-getting-started.md) on project setup, CLI options, and PWA scaffolding.

### Signals <a href="#signals" id="signals"></a>

```ts
import { signal, computed, effect, batch } from 'tina4js';

const count = signal(0);
const doubled = computed(() => count.value * 2);

effect(() => console.log(`Count: ${count.value}`));

count.value = 5;        // triggers effect → "Count: 5"
console.log(doubled.value); // 10

// Batch multiple updates into one notification
batch(() => { count.value = 10; count.value = 20; });
```

[More details](02-signals.md) on reactive state, computed values, effects, and batching.

### HTML Templates <a href="#html-templates" id="html-templates"></a>

```ts
import { signal, html } from 'tina4js';

const name = signal('World');

const view = html`
  <div>
    <h1>Hello, ${name}!</h1>
    <input @input=${(e: Event) => {
      name.value = (e.target as HTMLInputElement).value;
    }}>
    <button @click=${() => { name.value = 'World'; }}>Reset</button>
  </div>
`;

document.getElementById('root')!.appendChild(view);
```

[More details](03-html-templates.md) on template syntax, event handlers, boolean attributes, conditionals, and lists.

### Components <a href="#components" id="components"></a>

```ts
import { Tina4Element, html, signal } from 'tina4js';

class MyCounter extends Tina4Element {
  static props = { label: String };
  static styles = `:host { display: block; }`;

  count = signal(0);

  render() {
    return html`
      <div>
        <span>${this.prop('label')}: ${this.count}</span>
        <button @click=${() => this.count.value++}>+</button>
      </div>
    `;
  }

  onMount() { console.log('Connected!'); }
  onUnmount() { console.log('Removed!'); }
}

customElements.define('my-counter', MyCounter);
```

```html
<my-counter label="Clicks"></my-counter>
```

[More details](04-components.md) on props, Shadow DOM, styles, lifecycle hooks, and events.

### Routing <a href="#routing" id="routing"></a>

```ts
import { route, router, navigate, html } from 'tina4js';

route('/', () => html`<h1>Home</h1>`);
route('/user/{id}', ({ id }) => html`<h1>User ${id}</h1>`);
route('/admin', {
  guard: () => isLoggedIn() || '/login',
  handler: () => html`<h1>Admin</h1>`
});
route('*', () => html`<h1>404</h1>`);

router.start({ target: '#root', mode: 'history' });

// Navigate programmatically
navigate('/user/42');
```

[More details](05-routing.md) on hash vs history mode, route params, guards, and change events.

### API <a href="#api" id="api"></a>

```ts
import { api } from 'tina4js';

api.configure({ baseUrl: '/api', auth: true });

const users = await api.get('/users');
const user  = await api.get('/users/42');
await api.post('/users', { name: 'Andre' });
await api.put('/users/42', { name: 'Updated' });
await api.delete('/users/42');
```

[More details](06-api.md) on configuration, authentication, token rotation, interceptors, and error handling.

### WebSocket <a href="#websocket" id="websocket"></a>

```ts
import { ws } from 'tina4js';

const socket = ws.connect('/ws/chat');   // status & connected are signals - bind them in templates

const view = html`
  <div>Status: ${socket.status}</div>
  ${() => socket.connected.value ? html`<span>● live</span>` : html`<span>○ reconnecting...</span>`}
`;

socket.on('message', (msg) => console.log(msg));
socket.send({ type: 'hello' });
```

Auto-reconnect with exponential backoff; `status`/`connected` are signals, so the UI reacts to the connection state with no extra wiring. [More details](07-websocket.md).

### SSE / Streaming <a href="#sse" id="sse"></a>

```ts
import { sse } from 'tina4js';

const stream = sse.connect('/events', { json: true });   // Server-Sent Events / NDJSON
stream.on('data', (row) => append(row));
```

Same signal-driven status + auto-reconnect shape as `ws`, for one-way server push and NDJSON. [More details](08-sse-streaming.md).

### PWA <a href="#pwa" id="pwa"></a>

```ts
import { pwa } from 'tina4js';

pwa.register({
  name: 'My App',
  shortName: 'App',
  themeColor: '#1a1a2e',
  cacheStrategy: 'network-first',  // or 'cache-first', 'stale-while-revalidate'
  precache: ['/', '/css/styles.css'],
  offlineRoute: '/offline',
});
```

[More details](10-pwa.md) on manifest generation, service worker strategies, and offline support.

### Storage <a href="#storage" id="storage"></a>

```ts
import { signal } from 'tina4js';
import { persist, clearPersistedKeys } from 'tina4js/storage';

const theme = persist(signal('light'), { key: 'theme' });   // survives reloads, syncs across tabs
theme.value = 'dark';                                        // written to localStorage automatically

clearPersistedKeys(['theme']);                               // remove on logout
```

`persist` backs a signal with `localStorage`: versioned, migratable, and synced across tabs. **Never store secrets, tokens, or personal data**: `localStorage` is readable by any script on the page (XSS), so it is for UI preferences and non-sensitive view state only; keep auth tokens in memory or an httpOnly cookie.

### Debug <a href="#debug" id="debug"></a>

```ts
// Enable the dev overlay (Ctrl+Shift+D to toggle). Dev only - tree-shaken from production.
if (import.meta.env.DEV) import('tina4js/debug');
```

A side-effect import that mounts an overlay tracking live signals, mounted components, route changes, and API calls. Never ship it to production. [More details](11-debug.md).

### Backend Integration <a href="#backend-integration" id="backend-integration"></a>

#### With tina4-php

```bash
npx tina4js build --target php
# Outputs JS to src/public/js/
# Generates src/templates/pages/index.twig
```

The build drops your SPA's entry point at `src/templates/pages/index.twig`. Tina4's auto-routing serves it at `/`, with no env var or route needed. If your build emits a static `index.html` instead, drop it at `src/public/index.html` and Tina4 auto-serves it at `/` too (since v3.11.33).

#### With tina4-python

```bash
npx tina4js build --target python
# Outputs JS to src/public/js/
# Generates src/templates/pages/index.twig
```

Same auto-routing: `src/templates/pages/*.twig` becomes the page tree under `/`. Set `TINA4_TEMPLATE_ROUTING=off` if you want explicit routes only. [More details](13-backend-integration.md) on embedding in tina4-php/python, auth flow, and server-side state injection.

### Bundle Size <a href="#bundle-size" id="bundle-size"></a>

**What your app actually downloads.** tina4-js is code-split: a bundler ships one shared reactive-core chunk plus only the modules you import. These are real deduplicated bundles (esbuild `--minify`, then compressed), measured on macOS, v1.2.7; brotli is what most CDNs serve:

| Your app imports                               | gzip        | brotli      |
| ---------------------------------------------- | ----------- | ----------- |
| Core only (signals + `html` + components)      | 2.30 KB     | 2.05 KB     |
| **Core + Router** (typical SPA)                | **3.14 KB** | **2.78 KB** |
| + API                                          | 4.00 KB     | 3.54 KB     |
| + WebSocket + SSE                              | 5.32 KB     | 4.73 KB     |
| **Everything** (+ Storage + PWA, **no Debug**) | **7.52 KB** | **6.68 KB** |

Marginal cost per feature is small (gzip): Router **+0.8 KB**, API **+0.9 KB**, WebSocket + SSE **+1.3 KB**. **Debug is a separate dev-only entry** (`import 'tina4js/debug'`, \~5 KB gzip): guard it behind `import.meta.env.DEV` so your production bundler drops it entirely.

```ts
// Import from sub-paths to help the bundler tree-shake:
import { signal, html } from 'tina4js/core';
import { route, router } from 'tina4js/router';
import { api } from 'tina4js/api';
import { ws } from 'tina4js/ws';
import { sse } from 'tina4js/sse';
import { persist } from 'tina4js/storage';
import { pwa } from 'tina4js/pwa';
```

> **Don't add up the published `dist/*.es.js` file sizes.** Each looks standalone, but the reactive core lives in one shared chunk that the others import, so summing the files counts core several times over (and includes the dev-only debug overlay). The table above is what actually ships.

[↑ Back to top](index.md)

***

## 📕 Download the book

[**tina4-js: The 1.5KB Reactive Core** (PDF)](https://github.com/tina4stack/tina4-documentation/blob/main/pdfs/Tina4-Javascript-Developer.pdf): full reference, printable, with clickable table of contents and PDF outline. Regenerated with every release.
