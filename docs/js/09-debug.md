# Chapter 9: Debug Overlay

## See Everything

A signal changes. A component mounts. A route resolves. An API call returns a 401. You did not see any of it. You open the console, add a `console.log`, refresh, reproduce the bug, read the output, add another `console.log`, refresh again. Twenty minutes pass. The bug was a misspelled signal label.

The debug overlay shows you everything in real time. One import. One keyboard shortcut. Full visibility into your running application.

---

## 1. Enabling the Debug Overlay

```typescript
import 'tina4js/debug';
```

That is the entire setup. One import. The overlay is active.

For production builds, conditionally import it:

```typescript
if (import.meta.env.DEV) {
  import('tina4js/debug');
}
```

Vite tree-shakes the debug module away in production. Zero bytes in your final bundle.

When the debug module loads, you see a console message:

```
[tina4] Debug overlay enabled (Ctrl+Shift+D to toggle)
```

---

## 2. Opening the Overlay

Press **Ctrl+Shift+D** (or **Cmd+Shift+D** on Mac) to toggle the overlay. A panel appears at the bottom of the screen with four tabs: Signals, Components, Routes, and API.

Each tab is a window into a different layer of your application. Together, they replace dozens of `console.log` statements with a live, interactive dashboard.

---

## 3. The Signals Panel

This panel shows every signal in your application:

- **Label** -- the debug label you passed as the second argument to `signal()`
- **Current value** -- the live value, updating in real time
- **Subscriber count** -- how many effects, computed signals, and DOM bindings depend on this signal
- **Update count** -- how many times the value has changed since creation

This is why debug labels matter:

```typescript
// Without label -- shows as "Signal<number>" in the panel
const count = signal(0);

// With label -- shows as "count" in the panel
const count = signal(0, 'count');
```

Add labels to every signal you might need to debug. The cost is zero when the debug module is not imported.

### What to Look For

- **Subscriber count of 0:** This signal is not connected to anything. Either it is unused, or you read `.value` instead of passing the signal directly to a template binding.
- **High update count:** This signal is updating with unusual frequency. Check if you have an effect that writes to it in a loop.
- **Unexpected value:** The signal contains something you did not expect. Trace back to every place that writes to it. The update count tells you how many writes have occurred -- if the count is higher than you expect, something is writing that should not be.

---

## 4. The Components Panel

This panel shows every mounted `Tina4Element`:

- **Tag name** -- the custom element tag (e.g., `app-header`, `user-card`)
- **Mount status** -- whether the component is in the DOM

When a component mounts, it appears in the list. When it unmounts (removed from DOM), it disappears.

### What to Look For

- **Too many instances:** You might be creating components inside a reactive block that re-renders, spawning new elements on every signal change. If you see `user-card` appear 50 times and you only have 10 users, the component is being recreated instead of updated.
- **Missing components:** A component you expected to see is absent. Check two things: does it extend `Tina4Element`, and did you call `customElements.define()` for it? Both must be true for the component to appear in the panel.

---

## 5. The Routes Panel

This panel shows navigation history:

- **Path** -- the URL that was navigated to
- **Pattern** -- the route pattern that matched
- **Params** -- extracted route parameters
- **Duration** -- how long the route handler took to render (ms)

Every navigation (initial load, link click, `navigate()` call, browser back/forward) creates an entry. The history builds up as you use the app, giving you a timeline of every page transition.

### What to Look For

- **Slow routes:** A high `durationMs` value means the route handler is doing expensive work -- a heavy DOM build, a slow API call, or both. Compare durations across routes to find the outliers.
- **Wrong pattern matched:** If a path matched an unexpected pattern, your route registration order might be wrong. The router uses first-match-wins. A broad pattern registered before a specific one swallows the specific route.
- **Guard redirects:** If you see a navigation to a guarded route followed by a redirect to `/login`, the guard is working. If the guarded route renders without a redirect, the guard function has a bug.

---

## 6. The API Panel

This panel shows every HTTP request made through the `api` client:

- **Method and URL** -- GET /users, POST /auth/login, etc.
- **Status code** -- 200, 404, 500, etc.
- **Request headers** -- what was sent
- **Response data** -- what came back

### What to Look For

- **401 responses:** The token might be expired or missing. Check if `auth: true` is configured and the token exists in localStorage.
- **Request body:** Verify that `formToken` is present in POST/PUT/PATCH/DELETE requests when auth is enabled. A missing `formToken` means the API client is not configured for authentication, or the token was cleared.
- **Missing requests:** If an API call is not appearing, the code might be using `fetch()` directly instead of the `api` client. The debug panel tracks only requests that go through `api.get/post/put/patch/delete`.

---

## 7. How It Works Internally

The debug module hooks into the framework at four points:

1. **Signal hooks:** `__debugSignalCreate` and `__debugSignalUpdate` fire when signals are created and updated. These are null in production (tree-shaken away).
2. **Component hooks:** `__debugComponentMount` and `__debugComponentUnmount` fire on connectedCallback/disconnectedCallback.
3. **Route tracking:** The debug module subscribes to `router.on('change', ...)`.
4. **API tracking:** Request and response interceptors register via `api.intercept()`.

All hooks are set to `null` by default. They activate only when `import 'tina4js/debug'` runs. If you never import the debug module, the hooks compile away through tree-shaking. Zero runtime cost in production.

The overlay itself is a Web Component (`<tina4-debug>`) appended to `document.body`. It uses its own Shadow DOM, so its styles never interfere with your application. Your CSS cannot break the overlay. The overlay cannot break your CSS. Complete isolation.

---

## 8. Best Practices

### Always Use Debug Labels

```typescript
// Do this for every signal you care about:
const users = signal<User[]>([], 'users');
const currentPage = signal(1, 'current-page');
const searchQuery = signal('', 'search-query');
const isLoading = signal(false, 'is-loading');
```

When you open the debug panel and see 15 signals, labels are the difference between understanding your app state in seconds and spending minutes cross-referencing source files to figure out which `Signal<string>` is which.

### Import Conditionally

```typescript
// src/main.ts
if (import.meta.env.DEV) {
  import('tina4js/debug');
}
```

Never ship the debug overlay to production. It adds weight and exposes internal state to anyone who opens DevTools.

### Use During Development, Not Just Debugging

Do not wait for a bug to open the debug overlay. Keep it open while you develop. Watch signals update as you click buttons. Watch API requests flow as pages load. Watch routes resolve as you navigate. The overlay builds your intuition for how data moves through your application -- and that intuition is what makes you fast when a bug does appear.

---

## Summary

| What | How |
|---|---|
| Enable | `import 'tina4js/debug'` |
| Conditional | `if (import.meta.env.DEV) import('tina4js/debug')` |
| Toggle | Ctrl+Shift+D |
| Signals panel | Shows label, value, subscribers, update count |
| Components panel | Shows mounted Tina4Element instances |
| Routes panel | Shows navigation history with timing |
| API panel | Shows requests and responses |
| Debug labels | `signal(value, 'label')` |
| Production cost | Zero (tree-shaken away) |
