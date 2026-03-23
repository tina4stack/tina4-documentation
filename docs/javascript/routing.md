# Client-Side Routing

tina4-js includes a lightweight client-side router with hash and history mode, route parameters using `{param}` syntax (matching tina4-php/python conventions), and route guards.

## Defining Routes {#defining}

```ts
import { route, router, html } from 'tina4js';

// Static route
route('/', () => html`<h1>Home</h1>`);

// Route with parameters
route('/user/{id}', ({ id }) => html`<h1>User ${id}</h1>`);

// Multiple parameters
route('/blog/{year}/{slug}', ({ year, slug }) =>
  html`<h1>${slug} (${year})</h1>`
);

// Wildcard (404 catch-all)
route('*', () => html`<h1>Page Not Found</h1>`);
```

Route handlers receive a `params` object with the matched parameter values.

## Starting the Router {#starting}

```ts
router.start({
  target: '#root',     // CSS selector for mount point (required)
  mode: 'history',     // 'history' (default) or 'hash'
});
```

| Option | Default | Description |
|--------|---------|-------------|
| `target` | *(required)* | CSS selector of the DOM element to render into |
| `mode` | `'history'` | `'history'` uses HTML5 History API, `'hash'` uses `#/path` |

### Hash Mode vs History Mode

**Hash mode** (`/#/path`) — works everywhere, no server configuration needed:
```
http://myapp.com/#/
http://myapp.com/#/user/42
```

**History mode** (`/path`) — clean URLs, requires server-side fallback:
```
http://myapp.com/
http://myapp.com/user/42
```

::: tip
Use hash mode for standalone apps and when embedding in tina4-php/python. Use history mode only when your server is configured to serve `index.html` for all routes.
:::

## Programmatic Navigation {#navigate}

```ts
import { navigate } from 'tina4js';

navigate('/user/42');
navigate('/');
navigate('/login');
```

### Link Interception

In history mode, the router automatically intercepts `<a>` clicks for same-origin links — no need for special link components:

```ts
html`<a href="/about">About</a>`; // SPA navigation, no page reload
```

Links are **not** intercepted when:
- The `<a>` has `target="_blank"` or `download`
- The `<a>` has `rel="external"`
- A modifier key is held (Ctrl, Cmd, Shift, Alt)
- The href is to a different origin

## Route Guards {#guards}

Guards run before a route renders. They can allow, redirect, or block navigation:

```ts
import { route, html } from 'tina4js';

// Guard that redirects
route('/admin', {
  guard: () => {
    if (isLoggedIn()) return true;    // allow
    return '/login';                   // redirect to /login
  },
  handler: () => html`<h1>Admin Panel</h1>`,
});

// Guard that blocks
route('/private', {
  guard: () => hasAccess(),           // true = allow, false = block
  handler: () => html`<p>Private</p>`,
});
```

| Guard return | Behavior |
|-------------|----------|
| `true` | Allow — render the route |
| `false` | Block — nothing renders |
| `string` (path) | Redirect to that path |

## Route Change Events {#events}

Listen for route changes:

```ts
const unsubscribe = router.on('change', ({ path, params, pattern, durationMs }) => {
  console.log(`Navigated to: ${path}`);
  // Track page views, update title, etc.
});

// Stop listening
unsubscribe();
```

## String Content {#string-content}

Route handlers can return an `html` template, a DOM Node, or a plain string:

```ts
route('/text', () => 'Just a plain text page');
route('/node', () => {
  const div = document.createElement('div');
  div.textContent = 'Created manually';
  return div;
});
route('/template', () => html`<p>Template</p>`);
```

## Route Priority {#priority}

Routes are matched in the order they are defined. More specific routes should come before wildcards:

```ts
route('/', homePage);                  // exact match first
route('/user/{id}', userPage);         // parameterized
route('/user/{id}/posts', postsPage);  // more specific
route('*', notFoundPage);             // wildcard last
```

## Full Example {#full-example}

```ts
import { route, router, navigate, html, signal } from 'tina4js';

// State
const loggedIn = signal(false);

// Routes
route('/', () => html`
  <h1>Home</h1>
  <nav>
    <a href="/dashboard">Dashboard</a>
    <a href="/about">About</a>
  </nav>
`);

route('/login', () => html`
  <h1>Login</h1>
  <button @click=${() => {
    loggedIn.value = true;
    navigate('/dashboard');
  }}>Log In</button>
`);

route('/dashboard', {
  guard: () => loggedIn.value || '/login',
  handler: () => html`
    <h1>Dashboard</h1>
    <p>Welcome back!</p>
    <button @click=${() => {
      loggedIn.value = false;
      navigate('/');
    }}>Log Out</button>
  `,
});

route('/about', () => html`
  <h1>About</h1>
  <p>Built with tina4-js</p>
  <a href="/">Home</a>
`);

route('*', () => html`
  <h1>404</h1>
  <a href="/">Go Home</a>
`);

// Start
router.start({ target: '#root', mode: 'history' });
```
