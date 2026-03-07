# Signals – Reactive State

Signals are the core reactive primitive in tina4-js. A signal holds a value that, when changed, automatically updates any computed values, effects, or DOM bindings that depend on it.

## Creating Signals {#creating}

```ts
import { signal } from 'tina4js';

const count = signal(0);
const name = signal('Andre');
const items = signal<string[]>([]);
const user = signal<{ name: string; age: number } | null>(null);
```

## Reading and Writing {#read-write}

Access and update via `.value`:

```ts
const count = signal(0);

// Read
console.log(count.value); // 0

// Write — triggers reactive updates
count.value = 5;

// Read without tracking (won't create dependency)
console.log(count.peek()); // 5
```

::: tip
`.peek()` reads the current value without subscribing. Useful inside effects when you need a value but don't want to re-run when it changes.
:::

## Computed Values {#computed}

Derived state that auto-updates when dependencies change:

```ts
import { signal, computed } from 'tina4js';

const price = signal(100);
const taxRate = signal(0.15);

const tax = computed(() => price.value * taxRate.value);
const total = computed(() => price.value + tax.value);

console.log(total.value); // 115

price.value = 200;
console.log(total.value); // 230
```

Computed values are:
- **Read-only** — you cannot set `.value` on a computed
- **Lazy** — only recalculated when read after a dependency changes
- **Chainable** — computed values can depend on other computed values

## Effects {#effects}

Side effects that run whenever their dependencies change:

```ts
import { signal, effect } from 'tina4js';

const count = signal(0);

const dispose = effect(() => {
  console.log(`Count is now: ${count.value}`);
});
// Logs: "Count is now: 0"

count.value = 5;
// Logs: "Count is now: 5"

// Stop the effect
dispose();

count.value = 10; // No log — effect was disposed
```

Effects are used internally by the `html` template system to keep the DOM in sync. You rarely need to create effects manually.

## Batching {#batching}

Multiple signal updates normally trigger one notification each. Use `batch()` to defer notifications until all updates are complete:

```ts
import { signal, effect, batch } from 'tina4js';

const first = signal('John');
const last = signal('Doe');

effect(() => {
  console.log(`${first.value} ${last.value}`);
});
// Logs: "John Doe"

// Without batch — effect runs twice
first.value = 'Jane';  // Logs: "Jane Doe"
last.value = 'Smith';  // Logs: "Jane Smith"

// With batch — effect runs once
batch(() => {
  first.value = 'Bob';
  last.value = 'Jones';
});
// Logs: "Bob Jones" (only once)
```

Batches can be nested — notifications flush when the outermost batch completes.

## Equality Check {#equality}

Signals use `Object.is()` for equality. Setting the same value doesn't trigger updates:

```ts
const count = signal(0);
count.value = 0; // No notification — same value
```

For objects and arrays, you need a new reference to trigger updates:

```ts
const items = signal(['a', 'b']);

// This does NOT trigger updates (same reference):
items.value.push('c'); // ❌

// This does:
items.value = [...items.value, 'c']; // ✓
```

## Detecting Signals {#detecting}

```ts
import { signal, isSignal } from 'tina4js';

const count = signal(0);
isSignal(count);    // true
isSignal(42);       // false
isSignal('hello');  // false
```

## Signals in Templates {#in-templates}

Signals integrate directly with `html` tagged templates — no `.value` needed in the template:

```ts
import { signal, html } from 'tina4js';

const count = signal(0);

// Signal interpolated directly — auto-updates the DOM
const view = html`<span>${count}</span>`;

count.value = 42; // <span> now shows "42"
```

For dynamic expressions, use a function:

```ts
const show = signal(true);

html`${() => show.value ? html`<p>Visible</p>` : null}`;
```

See [HTML Templates](html-templates.md) for full template syntax.

## Patterns {#patterns}

### Store Pattern

Centralize state in a store file:

```ts
// src/store.ts
import { signal, computed } from 'tina4js';

export const todos = signal<Todo[]>([]);
export const filter = signal<'all' | 'active' | 'completed'>('all');

export const filtered = computed(() => {
  if (filter.value === 'active') return todos.value.filter(t => !t.done);
  if (filter.value === 'completed') return todos.value.filter(t => t.done);
  return todos.value;
});

export function addTodo(text: string) {
  todos.value = [...todos.value, { id: Date.now(), text, done: false }];
}
```

### Loading State

```ts
const loading = signal(false);
const data = signal<User[]>([]);
const error = signal<string | null>(null);

async function fetchUsers() {
  loading.value = true;
  error.value = null;
  try {
    data.value = await api.get('/users');
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}
```
