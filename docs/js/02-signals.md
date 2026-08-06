# Chapter 2: Signals

## Reactive State Without the Drama

A variable changes. The DOM does not. You write `document.getElementById('counter').textContent = count` in twelve places. You miss one. The bug report arrives on Friday afternoon.

Signals end this. A signal is a reactive value. Change it, and everything that depends on it -- text nodes, attributes, computed values, side effects -- updates. You never write update logic again.

This chapter covers the entire reactivity system in tina4-js: creating signals, deriving values, running side effects, batching updates, and avoiding the mistakes that trip up every new user.

---

## 1. What Is a Signal

A signal is a reactive value. When it changes, everything that depends on it updates.

```typescript
import { signal } from 'tina4js';

const count = signal(0);

// Read
console.log(count.value); // 0

// Write
count.value = 5;
console.log(count.value); // 5
```

That is the entire API for basic signals. `.value` to read. `.value =` to write. Nothing else.

When you write a new value, every subscriber -- effects, computed signals, DOM bindings -- fires. Not eventually. Not on the next tick. Synchronously, right now.

### The Three Forms: Read This Before Anything Else

This is the rule that decides whether your UI updates. Everything else in this chapter is detail; this is the part you cannot skip. When you put a signal into an `html` template, there are **three forms**, and they are not interchangeable:

```typescript
const count = signal(0);

html`<p>${count}</p>`              // ✅ REACTIVE - pass the signal itself
html`<p>${() => count.value * 2}</p>`  // ✅ REACTIVE - wrap an expression in a function
html`<p>${count.value}</p>`        // ❌ STATIC - renders "0" once, never updates again
```

| You write | The template receives | Behaviour |
|-----------|----------------------|-----------|
| `${count}` | the signal object | Reactive text node, updates on every change |
| `${() => count.value > 5}` | a function | Reactive block, re-runs on change; use for expressions, conditionals, lists |
| `${count.value}` | a plain number | Static, evaluated once, frozen forever |

Why? `${count.value}` is evaluated by JavaScript **before** the template ever sees it. The template gets the number `0`, a dead value with no way to know when `count` changes. `${count}` hands the template the live signal, so it can subscribe. `${() => ...}` hands it a function it can re-run.

**If your UI renders once and never updates, you almost certainly wrote `${signal.value}` where you needed `${signal}` or `${() => ...}`.** This one mistake accounts for the large majority of "my signal isn't working" reports. Burn the three forms into memory now and the rest of this chapter is easy.

> The same split shows up in attributes and properties (`${signal}` is reactive, `${signal.value}` is frozen), covered fully in the next chapter. The principle never changes: **pass the signal, or pass a function. Never pass `.value` into a template.**

---

## 2. Why Object.is() Matters

Signals use `Object.is()` to decide if a value changed. If the new value is the same as the old value by `Object.is()`, nothing happens. No subscribers fire. No DOM updates.

This matters for objects and arrays:

```typescript
const items = signal(['apple', 'banana']);

// WRONG -- mutating in place, same reference, no update
items.value.push('cherry');
// Object.is(oldArray, newArray) === true -- nothing happens!

// RIGHT -- new array reference
items.value = [...items.value, 'cherry'];
// Object.is(oldArray, newArray) === false -- subscribers fire!
```

Same rule for objects:

```typescript
const user = signal({ name: 'Alice', age: 30 });

// WRONG -- mutating in place
user.value.age = 31;

// RIGHT -- new object reference
user.value = { ...user.value, age: 31 };
```

This is the single most common mistake in tina4-js. UI not updating? Check this first. New reference, or mutation in place?

The rule fits on an index card: **always assign a new value to `.value`.** Spread arrays. Spread objects. Never mutate.

---

## 3. computed() -- Derived State

A shopping cart has items. Each item has a price and a quantity. The total is derived from those values. You do not store the total -- you compute it. When an item changes, the total recalculates.

That is what `computed()` does. It derives a value from other signals and keeps it current.

```typescript
import { signal, computed } from 'tina4js';

const price = signal(10);
const quantity = signal(3);
const total = computed(() => price.value * quantity.value);

console.log(total.value); // 30

price.value = 20;
console.log(total.value); // 60
```

The function you pass to `computed()` runs immediately and then re-runs whenever any signal it reads changes. tina4-js tracks which signals were read inside the function -- you do not need to declare dependencies manually.

### Computed Is Eager, Not Lazy

This is different from some other frameworks. In tina4-js, `computed()` re-evaluates as soon as a dependency changes, not when you read `.value`. This means:

- Computed values are always up to date
- There is no stale-read problem
- But unnecessary computeds do cost CPU

If you have an expensive computation that is only needed sometimes, do not put it in a computed. Use an effect with a conditional instead.

### Computed Is Read-Only

```typescript
const total = computed(() => price.value * quantity.value);

total.value = 100; // throws Error: '[tina4] computed signals are read-only'
```

If you need a writable derived value, use a signal and an effect.

---

## 4. effect() -- Side Effects

An effect runs a function immediately, then re-runs it whenever any signal it reads changes.

```typescript
import { signal, effect } from 'tina4js';

const name = signal('World');

const dispose = effect(() => {
  console.log(`Hello, ${name.value}!`);
});
// logs: "Hello, World!"

name.value = 'Tina4';
// logs: "Hello, Tina4!"
```

Effects bridge reactive state to the outside world. Logging. DOM manipulation. Network requests. Analytics. Anything that needs to happen when data changes -- effects handle it.

### Disposing Effects

`effect()` returns a dispose function. Call it to stop the effect from running:

```typescript
const dispose = effect(() => {
  document.title = `Count: ${count.value}`;
});

// Later, when you are done:
dispose();

count.value = 99; // effect does NOT run
```

This matters for cleanup. Component unmounts. Route changes. Without disposal, effects keep running -- memory leaks and ghost updates accumulate. The router handles this for you: effects created during route rendering are disposed when the route changes. More on that in Chapter 5.

### Auto-Tracking

You do not tell tina4-js which signals an effect depends on. It figures it out by running the function and seeing which `.value` getters are called:

```typescript
const a = signal(1);
const b = signal(2);
const showB = signal(true);

effect(() => {
  if (showB.value) {
    console.log(a.value + b.value);
  } else {
    console.log(a.value);
  }
});
```

When `showB` is `true`, the effect tracks `showB`, `a`, and `b`. When `showB` becomes `false`, on the next run it only reads `showB` and `a` -- so changes to `b` no longer trigger the effect. The dependency set is dynamic.

### Re-subscription on Re-run

Every time an effect re-runs, it unsubscribes from all previous signals and re-subscribes to whatever it reads this time. This is automatic. You do not need to manage subscriptions.

---

## 5. batch() -- Grouping Updates

Picture a form with a first name field and a last name field. A greeting effect reads both. Without batching, updating both fields fires the effect twice -- once with stale data, once with correct data. The user sees a flicker. The console logs an intermediate state that never should have existed.

```typescript
const first = signal('Alice');
const last = signal('Smith');

effect(() => {
  console.log(`${first.value} ${last.value}`);
});
// logs: "Alice Smith"

first.value = 'Bob';   // logs: "Bob Smith"
last.value = 'Jones';  // logs: "Bob Jones"
```

That is two effect runs. With `batch()`, you get one:

```typescript
import { batch } from 'tina4js';

batch(() => {
  first.value = 'Bob';
  last.value = 'Jones';
});
// logs: "Bob Jones" -- once
```

Inside a batch, signal writes are deferred. Subscribers are queued and only fire once when the batch completes.

### When Do You Need batch()?

Since v1.0.9, **event handlers in templates are automatically batched.** So this already only triggers one update:

```typescript
html`
  <button @click=${() => {
    first.value = 'Bob';
    last.value = 'Jones';
  }}>Update</button>
`
```

You need explicit `batch()` only when writing to multiple signals outside event handlers:

- `setTimeout` or `setInterval` callbacks
- `fetch().then()` handlers
- WebSocket message handlers
- Any async code

Inside a template event handler, batching is free. Everywhere else, wrap your writes.

---

## 6. peek() -- Read Without Tracking

An effect tracks every signal it reads. But sometimes you need a value without creating a dependency. You want to read a configuration signal once, not re-run the effect every time the config changes. That is what `peek()` does:

```typescript
const count = signal(0);
const multiplier = signal(2);

effect(() => {
  // Tracks count, but NOT multiplier
  console.log(count.value * multiplier.peek());
});

count.value = 5;      // effect runs
multiplier.value = 3; // effect does NOT run
```

`peek()` returns the current value without registering the read. The effect does not re-run when `multiplier` changes.

This is useful for:

- Reading config values that rarely change
- Avoiding infinite loops when an effect writes to a signal it also reads
- Performance optimization -- skipping unnecessary re-runs

---

## 7. Sharing Signals Across Files -- The Store Pattern

A signal created in one component file is local to that file. To share state across your app -- the logged-in user, the shopping cart, the theme -- you put signals in their own module and import them wherever you need them. That module is your store. There is no `createStore()`, no provider, no context wrapper. **A signal that is exported from a module IS global state.**

### One file, all your app-wide signals

```typescript
// src/store.ts
import { signal, computed } from 'tina4js';

// ── Auth ──────────────────────────────────────────────
export const user      = signal<User | null>(null);
export const authToken = signal('');

// ── Cart ──────────────────────────────────────────────
export const cart = signal<CartItem[]>([]);

// ── UI state ──────────────────────────────────────────
export const theme   = signal<'light' | 'dark'>('light');
export const sidebar = signal(false);

// ── Derived state -- computed signals belong here too ─
export const isLoggedIn = computed(() => user.value !== null);
export const cartCount  = computed(() => cart.value.length);
export const cartTotal  = computed(() =>
    cart.value.reduce((sum, i) => sum + i.price * i.qty, 0)
);
```

That is the entire store. Every `export const` is a piece of global state. Computed signals go here too -- derived state your whole app reads.

### Import and read in any component

```typescript
// src/components/Navbar.ts
import { html } from 'tina4js';
import { user, isLoggedIn, cartCount } from '../store';

export const Navbar = () => html`
    <nav>
        <a href="/cart">Cart (${cartCount})</a>
        ${() => isLoggedIn.value
            ? html`<span>Hi, ${user}</span>`
            : html`<a href="/login">Log in</a>`}
    </nav>`;
```

### Import and write from a different component

```typescript
// src/components/ProductCard.ts
import { html } from 'tina4js';
import { cart } from '../store';

export const ProductCard = (product: Product) => html`
    <button @click=${() => {
        cart.value = [...cart.value, { ...product, qty: 1 }];
    }}>Add to cart</button>`;
```

`ProductCard` writes `cart.value`. `Navbar` read `cartCount` (which reads `cart`). The `Cart (N)` text node updates -- across two files, automatically.

### Why it works

ES modules are singletons. Every file that does `import { cart } from '../store'` gets a reference to the **exact same signal object** -- the module is evaluated once and cached. Write to it from anywhere, every reader updates. That is your entire state-management layer.

### The rules

| Do | Don't |
|----|-------|
| Keep app-wide signals in `src/store.ts` | Scatter `signal()` calls across component files |
| `import { cart } from '../store'` everywhere | `const myCart = signal(cart.value)` -- that is a disconnected **copy**, not the shared signal |
| Put `computed()` derived state in the store too | Recompute the same derivation in five components |
| Keep component-local state inside the component | Promote every signal to global "just in case" |

A form's draft fields, a dropdown's open/closed state -- those stay as `signal()` *inside* the component function. Only state that genuinely spans components belongs in `store.ts`.

> **One signal, one source of truth.** The most common store mistake is "copying" a signal -- `signal(user.value)` in a second file. That reads the value once and creates a brand-new, disconnected signal. Always import the original.

---

## 8. Debug Labels

Signals accept an optional second argument -- a debug label:

```typescript
const count = signal(0, 'count');
const username = signal('', 'username');
const items = signal([], 'cart-items');
```

Labels do nothing in production. In the debug overlay (Chapter 11), labels appear in the Signals panel. Instead of staring at `Signal<number>` with value `7` and wondering which signal that is, you see `count: 7`. That difference matters at 2 AM when something is not updating.

Add labels to every signal you might need to debug. The overhead is zero when the debug module is not imported.

---

## 9. isSignal() -- Type Check

```typescript
import { isSignal } from 'tina4js';

const count = signal(0);

isSignal(count);     // true
isSignal(42);        // false
isSignal(null);      // false
isSignal({ value: 1 }); // false -- must be a real tina4 signal
```

Useful when writing utilities that accept either a signal or a plain value.

---

## 10. Common Mistakes

### Mistake 1: Reading .value in Templates

```typescript
// WRONG -- evaluates once, never updates
html`<p>${count.value}</p>`

// RIGHT -- pass the signal directly
html`<p>${count}</p>`

// RIGHT -- use a function for expressions
html`<p>${() => count.value * 2}</p>`
```

When you write `${count.value}`, JavaScript evaluates `count.value` before the template function sees it. The template gets the number `0`, not the signal. It cannot subscribe to changes.

When you write `${count}`, the template receives the signal object. It creates a text node and subscribes to changes. The DOM updates automatically.

### Mistake 2: Mutating in Place

```typescript
// WRONG
items.value.push(newItem);

// RIGHT
items.value = [...items.value, newItem];
```

Covered above, but it is worth repeating. This is the number one bug in tina4-js applications.

### Mistake 3: Creating Effects in Loops

```typescript
// WRONG -- creates a new effect every time the list re-renders
html`${() => items.value.map(item => {
  effect(() => console.log(item));  // leaks!
  return html`<div>${item}</div>`;
})}`
```

Effects created inside reactive blocks are fine -- the router and html renderer handle cleanup. But manually creating effects in a loop that runs inside a reactive function will leak unless you dispose them. Let the template engine handle reactivity. Use `${signal}` and `${() => expr}` instead of manual effects for DOM updates.

### Mistake 4: Forgetting That false Renders as Text

```typescript
// WRONG -- if condition is false, renders the TEXT "false"
html`${showDetails && html`<div>Details here</div>`}`

// RIGHT -- use a ternary
html`${() => showDetails.value ? html`<div>Details here</div>` : null}`
```

In JavaScript, `false && anything` evaluates to `false`. The template receives the boolean `false` and renders it as the string `"false"`. Use the ternary pattern. Always.

---

## 11. Putting It Together -- A Todo List

Signals. Computed. Effects. Batch. Here they are, working together in a complete todo application:

```typescript
import { signal, computed, effect, batch, html } from 'tina4js';

function todoApp() {
  const items = signal<{ text: string; done: boolean }[]>([], 'todo-items');
  const input = signal('', 'todo-input');
  const filter = signal<'all' | 'active' | 'done'>('all', 'todo-filter');

  const filtered = computed(() => {
    const list = items.value;
    if (filter.value === 'active') return list.filter(i => !i.done);
    if (filter.value === 'done') return list.filter(i => i.done);
    return list;
  });

  const remaining = computed(() =>
    items.value.filter(i => !i.done).length
  );

  // Side effect: update document title
  effect(() => {
    document.title = `Todos (${remaining.value} left)`;
  });

  const addItem = () => {
    const text = input.value.trim();
    if (!text) return;
    batch(() => {
      items.value = [...items.value, { text, done: false }];
      input.value = '';
    });
  };

  const toggleItem = (index: number) => {
    items.value = items.value.map((item, i) =>
      i === index ? { ...item, done: !item.done } : item
    );
  };

  const removeItem = (index: number) => {
    items.value = items.value.filter((_, i) => i !== index);
  };

  return html`
    <div>
      <h1>Todos</h1>

      <form @submit=${(e: Event) => { e.preventDefault(); addItem(); }}>
        <input
          type="text"
          placeholder="What needs to be done?"
          .value=${input}
          @input=${(e: Event) => { input.value = (e.target as HTMLInputElement).value; }}
        />
        <button type="submit">Add</button>
      </form>

      <div>
        <button @click=${() => filter.value = 'all'}>All</button>
        <button @click=${() => filter.value = 'active'}>Active</button>
        <button @click=${() => filter.value = 'done'}>Done</button>
      </div>

      <ul>
        ${() => filtered.value.map((item, index) => html`
          <li>
            <input
              type="checkbox"
              @click=${() => toggleItem(index)}
              ?checked=${item.done}
            />
            <span style="${item.done ? 'text-decoration: line-through' : ''}">${item.text}</span>
            <button @click=${() => removeItem(index)}>x</button>
          </li>
        `)}
      </ul>

      <p>${remaining} items left</p>
    </div>
  `;
}
```

Every concept from this chapter is present:

- `items`, `input`, and `filter` are signals with debug labels -- visible in the overlay
- `filtered` and `remaining` are computed -- they recalculate when `items` or `filter` change
- `effect()` syncs the document title as a side effect
- `batch()` groups the add-and-clear into one update
- The list uses `${() => filtered.value.map(...)}` -- a reactive block that re-renders when `filtered` changes
- New references everywhere: `map()` returns a new array, `filter()` returns a new array, the spread creates new objects

No mutation. No manual DOM updates. No event bus. Signals handle all of it.

---

## Persisting Signals Across Refreshes

A signal lives in memory. Refresh the page and it forgets. For values the user picked themselves -- theme, sidebar state, the last filter, a draft reply -- forgetting is rude. Wrap the signal with `persist()` and its value reads from `localStorage` on creation and writes back on every change.

```typescript
import { signal } from 'tina4js';
import { persist } from 'tina4js/storage';

const theme = persist(signal('light'), { key: 'theme' });
theme.value = 'dark';   // saved. Survives a refresh.
```

That is the whole idea. The full reference -- the never-store dangers list, every option, cross-tab sync, version migration, and the logout wipe -- lives in its own chapter: **[Persistent Signals](02-storage.md)**.
---

## Summary

| Concept | API | Purpose |
|---|---|---|
| Signal | `signal(value, label?)` | Reactive value |
| Read | `sig.value` | Get current value (tracks dependency) |
| Write | `sig.value = x` | Set value (notifies subscribers) |
| Computed | `computed(() => expr)` | Derived read-only signal |
| Effect | `effect(() => { ... })` | Side effect, returns dispose function |
| Batch | `batch(() => { ... })` | Group writes, one notification pass |
| Peek | `sig.peek()` | Read without tracking |
| Check | `isSignal(x)` | Returns true for tina4 signals |
| Label | `signal(0, 'name')` | Debug overlay identification |
| Persist | `persist(sig, { key })` from `tina4js/storage` | Survives a page refresh. Never for credentials. |
| Clear | `clearPersistedKeys(['k1', 'k2'])` | Wipe a list of keys, e.g. on logout |
