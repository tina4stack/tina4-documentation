# Tina4 JavaScript – Quick Reference

::: tip Sub-3KB reactive framework
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
    <a href="#pwa">PWA</a> •
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
npx tina4 create my-app
cd my-app
npm install
npm run dev
```
[More details](installation.md) on project setup, CLI options, and PWA scaffolding.

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
[More details](signals.md) on reactive state, computed values, effects, and batching.

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
[More details](html-templates.md) on template syntax, event handlers, boolean attributes, conditionals, and lists.

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
[More details](components.md) on props, Shadow DOM, styles, lifecycle hooks, and events.

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
[More details](routing.md) on hash vs history mode, route params, guards, and change events.

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
[More details](api.md) on configuration, authentication, token rotation, interceptors, and error handling.

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
[More details](pwa.md) on manifest generation, service worker strategies, and offline support.

### Backend Integration {#backend-integration}

#### With tina4-php
```bash
npx tina4 build --target php
# Outputs JS to src/public/js/
# Generates src/templates/index.twig
```
```env
TINA4_APP_DOCUMENT_ROOT=src/public
TINA4_APP_INDEX=../templates/index.twig
```

#### With tina4-python
```bash
npx tina4 build --target python
# Outputs JS to src/public/js/
# Generates src/templates/index.twig + src/routes/spa.py
```
[More details](backend-integration.md) on embedding in tina4-php/python, auth flow, and server-side state injection.

### Bundle Size {#bundle-size}

| Module | Raw | Gzipped |
|--------|-----|---------|
| Core (signals + html + component) | 4.6 KB | 1.51 KB |
| Router | 0.14 KB | 0.12 KB |
| API | 3.5 KB | 1.49 KB |
| PWA | 3.0 KB | 1.16 KB |
| WebSocket | 2.3 KB | 0.91 KB |
| Debug | 16.2 KB | 5.11 KB |
| **Full framework** | **3.3 KB** | **1.36 KB** |

Tree-shakeable — import only what you need:
```ts
import { signal, html } from 'tina4js/core';     // 1.51 KB gzip
import { route, router } from 'tina4js/router';   // 0.12 KB gzip
import { api } from 'tina4js/api';                 // 1.49 KB gzip
import { pwa } from 'tina4js/pwa';                 // 1.16 KB gzip
import { ws } from 'tina4js/ws';                   // 0.91 KB gzip
import 'tina4js/debug';                            // 5.11 KB gzip (dev only)
```

<nav class="tina4-menu" style="margin-top: 3rem; font-size: 0.9rem; opacity: 0.8;">
  <a href="#">↑ Back to top</a>
</nav>
