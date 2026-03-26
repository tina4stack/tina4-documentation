# Chapter 13: Patterns and Pitfalls

## What We Learned the Hard Way

You push a feature to production. The list does not update when items are added. You stare at the code for ten minutes. The logic is correct. The API returns the right data. The signal receives the value. But the DOM does not move.

Then you see it: `items.value.push(newItem)`. A mutation. No new reference. The signal never fired.

Every pitfall in this chapter was hit by a real developer on a real project. Every pattern was discovered through trial and error. This is the chapter you read before you ship -- and the chapter you return to when something breaks and you cannot figure out why.

---

## 1. When to Use tina4-js

Use tina4-js when:

- **Bundle size matters.** Under 3KB gzipped. Your app loads in under a second on a 3G connection.
- **You want simplicity.** Seven modules. One package. No decisions about state management libraries, routing libraries, or CSS-in-JS solutions.
- **You are building for a tina4 backend.** The API client speaks tina4-php and tina4-python natively -- auth tokens, CSRF protection, and token rotation work without configuration.
- **You want real Web Components.** Components that work outside the framework, in plain HTML, in other frameworks, in any context where custom elements are supported.
- **You are building islands.** Adding interactivity to server-rendered pages without taking over the entire DOM.
- **You are learning.** The entire source code is under 1,000 lines. You can read every module in an afternoon and understand how the framework works at the implementation level.

Use React, Vue, or Svelte when:

- **You need server-side rendering (SSR).** tina4-js is client-side only. If you need the server to render HTML for SEO or initial load performance, use a framework with SSR support.
- **You need a massive ecosystem.** Thousands of third-party components, hooks, plugins, and integrations.
- **Your team already knows React/Vue.** Developer familiarity has real value. Retraining a team has real cost.
- **You need fine-grained list reconciliation.** tina4-js re-renders entire lists when the signal changes. For lists of thousands of items with frequent individual updates, keyed reconciliation (React's virtual DOM, Svelte's each blocks) is the better tool.

Pick the right tool for the job. tina4-js is not trying to replace React. It is trying to replace the 90% of projects that never needed React in the first place.

---

## 2. The New-Reference Rule

This is the most important rule in tina4-js. It trips up everyone -- beginners and experienced developers alike.

Signals use `Object.is()` for change detection. `Object.is()` compares by reference for objects and arrays. If you mutate in place, the reference does not change. The signal does not fire. The DOM does not update. Your code is correct in every way except the one that matters.

```typescript
// These do NOT trigger updates:
items.value.push(newItem);
items.value.splice(0, 1);
items.value.sort();
items.value[0] = 'new';
user.value.name = 'Alice';
config.value.theme = 'dark';

// These DO trigger updates:
items.value = [...items.value, newItem];
items.value = items.value.filter((_, i) => i !== 0);
items.value = [...items.value].sort();
items.value = items.value.map((item, i) => i === 0 ? 'new' : item);
user.value = { ...user.value, name: 'Alice' };
config.value = { ...config.value, theme: 'dark' };
```

The pattern: create a new array or object. The spread operator is your primary tool. Every write to an array or object signal should produce a new reference. No exceptions.

If this feels wasteful, it is not. JavaScript engines optimize short-lived object allocations. The performance cost of spreading an array of 100 items is negligible compared to the debugging cost of a mutation that silently fails.

### Helper Functions

If you find yourself writing the same spread patterns over and over, make helpers:

```typescript
function pushSignal<T>(sig: Signal<T[]>, item: T) {
  sig.value = [...sig.value, item];
}

function removeSignal<T>(sig: Signal<T[]>, index: number) {
  sig.value = sig.value.filter((_, i) => i !== index);
}

function updateSignal<T extends object>(sig: Signal<T>, partial: Partial<T>) {
  sig.value = { ...sig.value, ...partial };
}
```

Three functions. They encode the new-reference rule so you do not have to think about it on every write.

---

## 3. Computed Is Eager, Not Lazy

In some frameworks, computed values are lazy -- they recalculate only when you read them. In tina4-js, computed values are eager. They recalculate the moment a dependency changes.

This means:

```typescript
const expensive = computed(() => {
  // This runs EVERY TIME any dependency changes,
  // even if nobody is reading expensive.value
  return heavyCalculation(data.value);
});
```

If you have an expensive computation that is only needed in certain states:

```typescript
// Instead of computed, use a signal + effect with a guard
const result = signal<Result | null>(null);
const needsResult = signal(false);

effect(() => {
  if (needsResult.value) {
    result.value = heavyCalculation(data.value);
  }
});
```

Or compute on demand without caching:

```typescript
function getExpensiveResult() {
  return heavyCalculation(data.value);
}
```

For most computed values -- filtering lists, calculating totals, deriving display strings -- eagerness is fine. The recalculation takes microseconds. You only need to worry about this when the computation involves heavy iteration, network-dependent data, or large dataset transformations. If the computed function takes more than a millisecond, consider guarding it.

---

## 4. Event Handler Auto-Batching

Since v1.0.9, all `@event` handlers in templates are wrapped in `batch()` for you. This means:

```typescript
html`
  <button @click=${() => {
    a.value = 1;
    b.value = 2;
    c.value = 3;
  }}>Update</button>
`
// One DOM update, not three
```

You do NOT need to wrap event handlers in `batch()`. It happens behind the scenes.

But this applies only to handlers registered with the `@event` syntax in `html` templates. If you add event listeners through other means, you need explicit batching:

```typescript
// Manual addEventListener -- NOT auto-batched
element.addEventListener('click', () => {
  batch(() => {
    a.value = 1;
    b.value = 2;
  });
});
```

The same applies to:

- `setTimeout` / `setInterval` callbacks
- `fetch().then()` handlers
- WebSocket `on('message')` handlers
- `Promise` handlers
- `requestAnimationFrame` callbacks

Any code that runs outside the `@event` handler context needs explicit `batch()` when writing to multiple signals. When in doubt, wrap in `batch()`. Batching an already-batched operation is harmless -- batches nest without side effects.

---

## 5. Effect Cleanup on Route Navigation

When the router navigates to a new route, it disposes all effects that were created during the previous route's handler execution. This is automatic and prevents memory leaks.

But it only disposes **effects**. It does not clean up:

- `setInterval` / `setTimeout` timers
- Manual `addEventListener` calls
- WebSocket connections
- Third-party library instances

For those, use a component with `onUnmount()`:

```typescript
class LiveWidget extends Tina4Element {
  private interval = 0;
  private socket: ManagedSocket | null = null;

  onMount() {
    this.interval = window.setInterval(() => { /* ... */ }, 1000);
    this.socket = ws.connect('wss://...');
  }

  onUnmount() {
    clearInterval(this.interval);
    this.socket?.close();
  }

  render() { /* ... */ }
}
```

When the route changes and this component leaves the DOM, `onUnmount()` fires. The timer stops. The socket closes. No lingering connections. No phantom intervals ticking in the background.

The rule: if you create it in a component, destroy it in `onUnmount()`. If you create it in a route handler, put it in a component so `onUnmount()` can reach it.

---

## 6. Do Not Mix addEventListener Inside Reactive Blocks

```typescript
// WRONG -- adds a new listener every time count changes
html`
  ${() => {
    document.addEventListener('keydown', handleKey); // LEAK!
    return html`<p>Count: ${count.value}</p>`;
  }}
`
```

Every time the reactive block re-runs, a new event listener is added. The old ones are never removed. After ten signal updates, ten listeners fire on every keypress. After a hundred updates, a hundred listeners fire.

Instead:

```typescript
// RIGHT -- add the listener once, outside the template
document.addEventListener('keydown', handleKey);

html`<p>${count}</p>`
```

Or use a component:

```typescript
class KeyHandler extends Tina4Element {
  private handler = (e: KeyboardEvent) => { /* ... */ };

  onMount() {
    document.addEventListener('keydown', this.handler);
  }

  onUnmount() {
    document.removeEventListener('keydown', this.handler);
  }

  render() { return html`<slot></slot>`; }
}
```

The component adds the listener once on mount and removes it on unmount. Clean lifecycle. No leaks. No accumulation.

---

## 7. The false/null Rendering Trap

This is covered in Chapter 3 but deserves repetition because it causes subtle bugs that pass code review:

```typescript
// WRONG -- renders "false" as text when show is false
html`${show.value && html`<div>Content</div>`}`

// RIGHT -- returns null for nothing
html`${() => show.value ? html`<div>Content</div>` : null}`
```

The `&&` pattern comes from React JSX, where `false` is a rendering no-op. In tina4-js, `false` converts to the text `"false"` and displays on screen. The word "false" appears in your UI. Always use ternary. Always return `null` for "render nothing."

The same trap applies to zero:

```typescript
// WRONG -- shows "0" when count is zero
html`${count.value && html`<p>${count.value} items</p>`}`

// RIGHT
html`${() => count.value > 0 ? html`<p>${count.value} items</p>` : null}`
```

`0 && anything` evaluates to `0`, which renders as the text `"0"`. A zero appears in your UI with no context. The ternary with an explicit comparison avoids both traps.

---

## 8. Signal Scope and Lifetime

Signals live until they are garbage collected. If nothing references a signal, the runtime cleans it up. But if an effect or DOM binding holds a reference, the signal stays alive.

### Avoid Global Signals for Temporary State

```typescript
// BAD -- these signals live forever
const formName = signal('');
const formEmail = signal('');

route('/users/new', () => {
  return html`<input .value=${formName} ... />`;
});
```

When the user navigates away and comes back, `formName` still holds the old value. The form is pre-filled with stale data. The user did not expect that.

```typescript
// GOOD -- signals scoped to the route handler
route('/users/new', () => {
  const formName = signal('');
  const formEmail = signal('');

  return html`<input .value=${formName} ... />`;
});
```

Each visit creates fresh signals. The old ones are garbage collected when the route changes and effects are disposed. The form starts empty every time.

### Use Global Signals for Shared State

```typescript
// store.ts -- these SHOULD be global
export const user = signal<User | null>(null, 'user');
export const token = signal<string | null>(null, 'token');
export const theme = signal<'light' | 'dark'>('light', 'theme');
```

Global signals are appropriate for state that persists across route changes: authentication, user preferences, cart contents, notification counts. The distinction is simple: if the data should survive navigation, make it global. If the data belongs to a single page visit, scope it to the route handler.

---

## 9. Debugging Techniques

### Add Labels to Every Signal

```typescript
const count = signal(0, 'count');         // DO THIS
const count = signal(0);                    // NOT THIS
```

When you open the debug overlay and see 20 unnamed signals, you will spend more time figuring out which signal is which than fixing the bug you came to investigate.

### Check Subscriber Counts

In the debug overlay, a signal with 0 subscribers is either:

- Unused (remove it)
- Bound incorrectly (`${count.value}` instead of `${count}`)

A signal with an unexpectedly high subscriber count might be referenced in a reactive block that re-runs often, creating new subscriptions each time. The subscriber count is the fastest way to spot a binding error or a subscription leak.

### Use effect() for Debugging

```typescript
effect(() => {
  console.log('User changed:', user.value);
  console.log('Token changed:', token.value);
});
```

This logs whenever `user` or `token` changes. It captures every write, from every source, in chronological order. Remove it before shipping -- but while debugging, it is more reliable than breakpoints because it shows you the data flow without pausing execution.

---

## 10. Performance Patterns

### Keep Lists Reasonable

tina4-js re-renders entire lists when the signal changes. For lists under 200 items, the re-render takes under a millisecond. For larger lists:

- Paginate on the server (return 20 items per page, not 10,000)
- Use virtual scrolling (a separate library that renders only visible rows)
- Keep the visible list small with filtering and pagination

### Avoid Unnecessary Computed

```typescript
// UNNECESSARY -- computed with one dependency that transforms a value
const upperName = computed(() => name.value.toUpperCase());

// SIMPLER -- just use a function in the template
html`<p>${() => name.value.toUpperCase()}</p>`
```

Use computed when multiple parts of your app need the derived value. Use inline functions when only one template needs it. A computed signal adds a subscription, a cached value, and a node in the dependency graph. An inline function adds a function call. For single-use derivations, the function is the lighter tool.

### Batch Async Results

```typescript
// Multiple signal writes from an API response
const data = await api.get('/dashboard');
batch(() => {
  users.value = data.users;
  stats.value = data.stats;
  lastUpdated.value = new Date().toISOString();
});
```

Without batch, each assignment triggers a separate DOM update. Three writes, three re-renders. With batch, three writes, one re-render. The difference is invisible for two signals. It is visible for ten.

---

## 11. Common Error Messages

### "[tina4] computed signals are read-only"

You tried to write to a computed signal. Computed values are derived -- they calculate from source signals. Write to the source signals instead, and the computed value updates on its own.

### "[tina4] WebSocket is not connected"

You called `socket.send()` when the socket was not open. Check `socket.connected.value` before sending, or queue messages and flush them when the `status` signal changes to `'open'`.

### "[tina4] Router target '...' not found in DOM"

The CSS selector you passed to `router.start({ target })` does not match any element. The element must exist in your HTML before `router.start()` runs. If you are using a component that renders the target element, make sure the component mounts before the router starts.

### "[tina4] Prop '...' not declared in static props"

You called `this.prop('name')` but did not declare `name` in the component's `static props` object. The framework requires prop declarations so it can set up attribute observation. Add the prop to the static object and the error disappears.

---

## Summary

| Pitfall | Fix |
|---|---|
| Mutating arrays/objects in place | Always create new references (spread) |
| `${count.value}` in templates | Use `${count}` (pass the signal) |
| `${condition && html\`...\`}` | Use ternary: `${() => cond ? html\`...\` : null}` |
| addEventListener in reactive blocks | Add listeners once, outside templates |
| No cleanup for timers/sockets | Use `onUnmount()` in components |
| Expensive computed | Guard with a condition or compute on demand |
| Unnamed signals | Always add debug labels |
| Multiple writes without batch | Wrap async signal writes in `batch()` |
| Global signals for form state | Scope signals to route handlers or components |
