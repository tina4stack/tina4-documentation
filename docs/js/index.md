# Tina4 JavaScript – Quick Reference

::: tip 🔥 Sub-3KB core, reactive framework
- Signals for state, `html` tagged templates for rendering, Web Components for reuse
- Client-side routing with `{param}` syntax matching tina4-php/python
- Fetch API wrapper with Bearer + formToken auth compatible with tina4 backends
- PWA support with runtime manifest and service worker generation
- Tree-shakeable: import only what you need
  :::

<nav class="tina4-menu">
    <a href="#installation">Installation</a> •
    <a href="#signals">Signals</a> •
    <a href="#html-templates">HTML Templates</a> •
    <a href="#components">Components</a> •
    <a href="#routing">Routing</a> •
    <a href="#api">API</a> •
    <a href="#websocket">WebSocket</a> •
    <a href="#sse">SSE</a> •
    <a href="#storage">Storage</a> •
    <a href="#pwa">PWA</a> •
    <a href="#debug">Debug</a> •
    <a href="#backend-integration">Backend Integration</a> •
    <a href="#bundle-size">Bundle Size</a>
</nav>

<style>
.tina4-menu {
  background: #2c3e50; color: white; padding: 1rem; border-radius: 8px; margin: 2rem 0; text-align: center; font-size: 1.1rem;
}
.tina4-menu a { color: #1abc9c; text-decoration: none; margin: 0 0.4rem; }
.tina4-menu a:hover { text-decoration: underline; }
</style>

### Installation {#installation}

```bash
npx tina4js create my-app
cd my-app
npm install
npm run dev
```
[More details](01-getting-started.md) on project setup, CLI options, and PWA scaffolding.

### Signals {#signals}

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

### HTML Templates {#html-templates}

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

### Components {#components}

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

### Routing {#routing}

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

### API {#api}

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

### WebSocket {#websocket}

```ts
import { ws } from 'tina4js';

const socket = ws.connect('/ws/chat');   // status & connected are signals — bind them in templates

const view = html`
  <div>Status: ${socket.status}</div>
  ${() => socket.connected.value ? html`<span>● live</span>` : html`<span>○ reconnecting…</span>`}
`;

socket.on('message', (msg) => console.log(msg));
socket.send({ type: 'hello' });
```
Auto-reconnect with exponential backoff; `status`/`connected` are signals, so the UI reacts to the connection state with no extra wiring. [More details](07-websocket.md).

### SSE / Streaming {#sse}

```ts
import { sse } from 'tina4js';

const stream = sse.connect('/events', { json: true });   // Server-Sent Events / NDJSON
stream.on('data', (row) => append(row));
```
Same signal-driven status + auto-reconnect shape as `ws`, for one-way server push and NDJSON. [More details](08-sse-streaming.md).

### PWA {#pwa}

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

### Storage {#storage}

```ts
import { signal } from 'tina4js';
import { persist, clearPersistedKeys } from 'tina4js/storage';

const theme = persist(signal('light'), { key: 'theme' });   // survives reloads, syncs across tabs
theme.value = 'dark';                                        // written to localStorage automatically

clearPersistedKeys(['theme']);                               // remove on logout
```

`persist` backs a signal with `localStorage` — versioned, migratable, and synced across tabs. **Never store secrets, tokens, or personal data**: `localStorage` is readable by any script on the page (XSS), so it is for UI preferences and non-sensitive view state only — keep auth tokens in memory or an httpOnly cookie.

### Debug {#debug}

```ts
// Enable the dev overlay (Ctrl+Shift+D to toggle). Dev only — tree-shaken from production.
if (import.meta.env.DEV) import('tina4js/debug');
```

A side-effect import that mounts an overlay tracking live signals, mounted components, route changes, and API calls. Never ship it to production. [More details](11-debug.md).

### Backend Integration {#backend-integration}

#### With tina4-php
```bash
npx tina4js build --target php
# Outputs JS to src/public/js/
# Generates src/templates/pages/index.twig
```

The build drops your SPA's entry point at `src/templates/pages/index.twig`. Tina4's auto-routing serves it at `/` — no env var or route needed. If your build emits a static `index.html` instead, drop it at `src/public/index.html` and Tina4 auto-serves it at `/` too (since v3.11.33).

#### With tina4-python
```bash
npx tina4js build --target python
# Outputs JS to src/public/js/
# Generates src/templates/pages/index.twig
```

Same auto-routing — `src/templates/pages/*.twig` becomes the page tree under `/`. Set `TINA4_TEMPLATE_ROUTING=off` if you want explicit routes only.
[More details](13-backend-integration.md) on embedding in tina4-php/python, auth flow, and server-side state injection.

### Bundle Size {#bundle-size}

| Module | Raw | Gzipped |
|--------|-----|---------|
| Core (signals + html + component) | 4.59 KB | 1.49 KB |
| Router | 0.14 KB | 0.12 KB |
| API | 6.12 KB | 2.27 KB |
| WebSocket | 2.20 KB | 0.89 KB |
| SSE / NDJSON | 3.34 KB | 1.30 KB |
| Storage (persist) | 4.33 KB | 1.66 KB |
| PWA | 3.06 KB | 1.16 KB |
| Debug (dev only) | 15.9 KB | 5.01 KB |

Measured on macOS, tina4-js v1.2.7 — per-module ES bundles. The six production modules are budget-asserted by `npm run test:size`; Storage and Debug were measured via gzip on the built bundle. **Debug is dev-only and tree-shaken from production.** Tree-shakeable — import only what you use; most apps ship just Core + Router (~1.6 KB gzip):

```ts
import { signal, html } from 'tina4js/core';     // 1.33 KB gzip
import { route, router } from 'tina4js/router';   // 0.12 KB gzip
import { api } from 'tina4js/api';                 // 1.49 KB gzip
import { pwa } from 'tina4js/pwa';                 // 1.09 KB gzip
import { ws } from 'tina4js/ws';                   // 0.91 KB gzip
import { sse } from 'tina4js/sse';                 // 1.30 KB gzip
import 'tina4js/debug';                            // 4.76 KB gzip (dev only, tree-shaken from prod)
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">↑ Back to top</a>
</nav>


---

## 📕 Download the book

[**tina4-js — The 1.5KB Reactive Core** (PDF)](/pdfs/Tina4-Javascript-Developer.pdf) — full reference, printable, with clickable table of contents and PDF outline. Regenerated with every release.

