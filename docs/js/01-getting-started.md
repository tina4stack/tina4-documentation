# Chapter 1: Getting Started

## Your First 5 Minutes

A terminal. A single command. A browser tab. In five minutes you will have a running tina4-js project with reactive state, a rendered page, and a dev server with hot reload. The counter on screen will respond to your clicks before you understand why. That is the point -- you ship first, then you learn.

---

## 1. What Is tina4-js

tina4-js is a reactive JavaScript framework with a 1.5KB gzipped core. The full framework ships under 6KB gzipped. Eight modules, each solving one problem:

- **Signals** for reactive state -- no stores, no reducers, no actions
- **Tagged template literals** for DOM rendering -- no JSX, no virtual DOM, no compiler
- **Web Components** for encapsulation -- real custom elements, not a framework abstraction
- **A router** for SPA navigation
- **An HTTP client** built for tina4-php and tina4-python backends
- **WebSocket** with auto-reconnect and signal integration
- **PWA** support with one function call
- **A debug overlay** that shows you everything

One npm package. Zero dependencies. The entire framework weighs less than most favicons.

### What It Is Not

tina4-js is not React. It has no virtual DOM. It does not diff trees. When a signal changes, the exact text node or attribute that depends on it updates. Nothing else moves.

tina4-js is not Angular. No dependency injection. No decorators. No module system. No zone.js.

tina4-js is not a meta-framework. No server-side rendering. No file-based routing. No data loading conventions. It is a client-side framework that does one thing well: build reactive UIs with the smallest possible footprint.

---

## 2. Prerequisites

You need three things. Nothing else.

1. **Node.js 18 or later** -- check with:

```bash
node --version
```

You should see `v18.0.0` or higher.

2. **npm** -- comes with Node.js. Check with:

```bash
npm --version
```

3. **A text editor** -- VS Code, Cursor, Zed, Vim, anything.

---

## 3. Create a Project

The primary way to scaffold is the Tina4 Rust CLI:

```bash
tina4 init js my-app
```

This scaffolds a complete project with TypeScript, Vite, routing, and a sample page.

> **The `tina4` Rust CLI is the unified installer across all Tina4 frameworks**
> (Python, PHP, Ruby, Node.js, JS). For npm-only environments where the
> CLI isn't available, every command has an `npx tina4js …` fallback -- for
> example `npx tina4js create my-app` is equivalent to `tina4 init js my-app`.

Want the optional CSS framework included? The Rust CLI does not yet accept a `--css` flag on `init`, so scaffold first and then add the dependency:

```bash
tina4 init js my-app
```

To add Tina4 CSS, edit `package.json` to add the `tina4-css` dependency, or use the fallback `npx tina4js create my-app --css` which accepts the flag directly. This adds `tina4-css` to your dependencies -- a utility CSS library with reset, grid, buttons, forms, tables, cards, and dark mode built in. More on this in Chapter 10.

Want PWA support from the start? The Rust CLI also does not yet expose a `--pwa` flag on `init`. Scaffold with `tina4 init js my-app` and enable PWA manually (see Chapter 9), or use the fallback `npx tina4js create my-app --pwa` to get the PWA preset directly. You can combine the flags on the fallback: `npx tina4js create my-app --css --pwa`.

Now install and run:

```bash
cd my-app
npm install
npm run dev
```

Open `http://localhost:3000`. A welcome page appears with a counter. Click the minus button. Click the plus button. The number updates. No page reload. No visible delay. That is signals at work -- reactive state flowing from data to DOM without you writing a single line of update logic.

---

## 4. Project Structure

Look at what the CLI created:

```
my-app/
  index.html              # Entry point -- loads src/main.ts
  package.json            # Dependencies: tina4js, vite, typescript
  tsconfig.json           # TypeScript config
  vite.config.ts          # Vite dev server config
  src/
    main.ts               # App entry -- imports routes, starts router
    routes/
      index.ts            # Route definitions
    pages/
      home.ts             # Home page handler
    components/
      app-header.ts       # Example web component
    public/
      css/
        default.css       # Default styles
```

The structure is intentional:

- **`src/routes/`** -- Route definitions. One file per feature or group.
- **`src/pages/`** -- Page handler functions. Each returns a template.
- **`src/components/`** -- Web Components (Tina4Element subclasses).
- **`src/public/`** -- Static assets (CSS, images, fonts).

This is a convention, not a requirement. tina4-js does not care where your files live. But this structure scales. Every tina4-js project looks the same, which matters when you onboard new team members or let AI generate code. Consistency compounds.

---

## 5. The Entry Point

Open `src/main.ts`:

```typescript
import { signal, computed, html, route, router, navigate, api } from 'tina4js';
import './routes/index';

// Configure API (uncomment to connect to tina4-php/python backend)
// api.configure({ baseUrl: '/api', auth: true });

// Start router
router.start({ target: '#root', mode: 'hash' });
```

Three things happen here:

1. **Import everything from one package.** All seven modules export from `tina4js`. No sub-package installs.
2. **Import your routes.** The route file calls `route()` to register paths and handlers.
3. **Start the router.** It finds `#root` in the DOM and renders matched routes into it.

The `mode: 'hash'` means URLs look like `http://localhost:3000/#/about`. For clean URLs without the hash, use `mode: 'history'` -- but you will need server-side URL rewriting in production.

---

## 6. Your First Signal

Open `src/pages/home.ts`:

```typescript
import { signal, computed, html } from 'tina4js';

export function homePage() {
  const count = signal(0);
  const doubled = computed(() => count.value * 2);

  return html`
    <div class="page">
      <h1>Welcome</h1>

      <div class="counter">
        <button @click=${() => count.value--}>-</button>
        <span>${count}</span>
        <button @click=${() => count.value++}>+</button>
      </div>
      <p class="muted">Doubled: ${doubled}</p>
    </div>
  `;
}
```

Four things happen in this code. Each one is a core concept you will use in every tina4-js application.

**`signal(0)`** creates a reactive value. Read it with `count.value`. Write it with `count.value = 5`. When you write, everything that depends on it updates. Not eventually. Not on the next tick. Right now.

**`computed(() => count.value * 2)`** creates a derived signal. It reads `count.value` inside the function, so tina4-js knows to recompute whenever `count` changes. You cannot write to a computed -- it is read-only.

**`html\`...\``** is a tagged template literal. It returns a real `DocumentFragment` -- actual DOM nodes, not a string, not a virtual tree. When you put `${count}` in the template, tina4-js creates a text node that updates in place when `count` changes. No diffing. No reconciliation. Direct DOM mutation.

**`@click=${() => count.value--}`** adds a click event listener. The `@` prefix means "event handler." Since v1.0.9, event handlers are wrapped in `batch()`, so multiple signal writes inside one handler trigger one update.

---

## 7. Your First Route

Open `src/routes/index.ts`:

```typescript
import { route, html } from 'tina4js';
import { homePage } from '../pages/home';

// Home
route('/', homePage);

// About
route('/about', () => html`
  <div class="page">
    <h1>About</h1>
    <p>Built with tina4-js.</p>
    <a href="/">Back home</a>
  </div>
`);

// 404
route('*', () => html`
  <div class="page">
    <h1>404</h1>
    <p>Page not found.</p>
    <a href="/">Go home</a>
  </div>
`);
```

**`route(pattern, handler)`** -- pattern is always the first argument. The handler is a function that returns a template. The router calls it when the URL matches.

**`route('*', handler)`** -- the wildcard catches any URL that no other route matched. Put it last.

Links work automatically. The router intercepts clicks on `<a>` tags that point to same-origin paths and navigates without a page reload. You do not need a special `<Link>` component.

---

## 8. Adding a Component

Open `src/components/app-header.ts`:

```typescript
import { Tina4Element, html } from 'tina4js';

class AppHeader extends Tina4Element {
  static props = { title: String };
  static styles = `
    :host { display: block; padding: 1rem 0; border-bottom: 1px solid #e5e7eb; }
    h1 { margin: 0; font-size: 1.5rem; }
    nav { display: flex; gap: 1rem; margin-top: 0.5rem; }
    a { color: #2563eb; text-decoration: none; }
  `;

  render() {
    return html`
      <h1>${this.prop('title')}</h1>
      <nav>
        <a href="/">Home</a>
        <a href="/about">About</a>
      </nav>
    `;
  }
}

customElements.define('app-header', AppHeader);
```

Then use it in any template:

```typescript
html`
  <app-header title="My App"></app-header>
  <div class="content">...</div>
`
```

**`static props`** declares reactive attributes. When the `title` attribute changes, the component re-renders that part.

**`static styles`** scopes CSS to the component via Shadow DOM. Your styles cannot leak out. External styles cannot leak in.

**`this.prop('title')`** returns a signal for the `title` prop. Drop it in the template and it updates reactively.

**`customElements.define()`** registers the tag name. Use a hyphenated name -- that is a Web Components requirement, not a tina4-js thing.

---

## 9. The Build

Development is done. Time to ship:

```bash
npm run build
```

Vite bundles everything into `dist/`. The tina4-js runtime adds under 6KB to your bundle. Your entire app -- framework, routes, components, everything -- will likely be smaller than React's runtime alone.

To preview the production build:

```bash
npm run preview
```

---

## 10. What Just Happened

Five minutes. One command to scaffold. One command to install. One command to run. And you covered:

1. Reactive state with `signal()`
2. Derived state with `computed()`
3. DOM rendering with `html` tagged templates
4. Event handling with `@click`
5. A web component with `Tina4Element`
6. Client-side routing with `route()` and `router.start()`
7. A production build with Vite

The rest of this book goes deep on each of these. But you already have a working app. You already have a production build. Everything from here is precision and power.

---

## Summary

| What | How |
|---|---|
| Create project | `tina4 init js my-app` (fallback: `npx tina4js create my-app`) |
| With CSS framework | `tina4 init js my-app` + add `tina4-css` dep (fallback: `npx tina4js create my-app --css`) |
| With PWA | `tina4 init js my-app` + enable PWA manually (fallback: `npx tina4js create my-app --pwa`) |
| Dev server | `npm run dev` |
| Production build | `npm run build` |
| Reactive state | `signal(initialValue)` |
| Derived state | `computed(() => expression)` |
| DOM rendering | `` html`<p>${signal}</p>` `` |
| Event handling | `@click=${handler}` |
| Components | `class X extends Tina4Element` |
| Routes | `route(pattern, handler)` |
| Start router | `router.start({ target, mode })` |
