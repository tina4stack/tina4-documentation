# Chapter 3: HTML Templates

## DOM Without the Framework Tax

Open your browser's DevTools. Inspect a React application. You see a `<div id="root">` containing a tree of elements that a virtual DOM diffing algorithm built for you. Somewhere between your JSX and those elements, a reconciler compared two trees, computed a minimal set of patches, and applied them. For a counter displaying the number 5.

tina4-js skips all of that. The `html` tagged template creates real DOM nodes. It binds signals to specific text nodes and attributes. When a signal changes, that one text node updates. No tree comparison. No patch computation. No framework standing between your data and your DOM.

This chapter covers every binding syntax in the `html` tagged template -- reactive text, reactive blocks, events, boolean attributes, property bindings, and class bindings. You will know which ones update and which ones are static, and you will never fall into the `false`/`null` rendering trap.

---

## 1. What html`` Does

```typescript
import { html } from 'tina4js';

const fragment = html`<h1>Hello, World!</h1>`;
document.body.appendChild(fragment);
```

`html` is a tagged template literal function. It parses your markup once, caches the result, then clones it for each call. The return value is a real `DocumentFragment` -- actual DOM nodes. Not a string. Not a virtual tree. Not an intermediate representation.

No `render()` loop. No reconciliation. No diffing. The template creates DOM, binds signals to specific nodes, and walks away. Updates happen through direct signal subscriptions on individual nodes. The framework is not in the middle of the conversation between your data and your page.

---

## 2. Static Values -- ${value}

Plain values go in as text nodes. Once. Never again.

```typescript
const name = 'Alice';
html`<p>Hello, ${name}</p>`
```

The template evaluates `name`, gets the string `"Alice"`, creates a text node, and inserts it. If `name` changes later, the DOM does not update. It is static.

**Everything is XSS-safe by default.** Values are inserted as text nodes, not HTML:

```typescript
const userInput = '<script>alert("xss")</script>';
html`<p>${userInput}</p>`
// Renders as the literal text: <script>alert("xss")</script>
// NOT executed as HTML
```

You cannot accidentally inject HTML through interpolation. This is by design.

---

## 3. Reactive Text -- ${signal}

Pass a signal directly (not `.value`) to create a reactive text node:

```typescript
import { signal, html } from 'tina4js';

const count = signal(0);

html`<p>Count: ${count}</p>`
```

When `count.value` changes, the text node updates. Nothing else in the DOM moves. The `<p>` element stays. The `"Count: "` text stays. Only the number changes.

This is the most common pattern in tina4-js. One signal. One text node. Live updates forever.

**Critical rule:** Pass the signal, not its value.

```typescript
// WRONG -- static, evaluates once
html`<p>${count.value}</p>`

// RIGHT -- reactive, updates on change
html`<p>${count}</p>`
```

When you write `${count.value}`, JavaScript evaluates `count.value` (gets `0`) and passes the number `0` to the template. The template sees a plain number, not a signal. It creates a static text node.

When you write `${count}`, JavaScript passes the signal object. The template detects it (via `isSignal()`), creates a text node, and subscribes to changes. When the signal updates, the text node updates.

---

## 4. Reactive Blocks -- ${() => expr}

Functions are reactive blocks. The function runs immediately, and re-runs whenever any signal read inside it changes:

```typescript
const show = signal(true);
const name = signal('Alice');

html`
  <div>
    ${() => show.value
      ? html`<p>Hello, ${name}!</p>`
      : null
    }
  </div>
`
```

When `show` or `name` changes, the function re-runs. The previous nodes are removed and new nodes are inserted. This is how you do conditional rendering and lists.

### Conditional Rendering

```typescript
const isLoggedIn = signal(false);

html`
  ${() => isLoggedIn.value
    ? html`<p>Welcome back!</p>`
    : html`<a href="/login">Log in</a>`
  }
`
```

### Lists

```typescript
const items = signal(['Apple', 'Banana', 'Cherry']);

html`
  <ul>
    ${() => items.value.map(item => html`<li>${item}</li>`)}
  </ul>
`
```

When `items` changes, the entire `<ul>` content is replaced. Old nodes out. New nodes in. This is not keyed reconciliation like React -- it is a full swap. For lists under a few hundred items, the browser handles this in under a millisecond. For massive lists, consider a virtualization library.

### Nested Reactivity

Reactive blocks can contain signals:

```typescript
const items = signal([
  { name: signal('Apple'), price: signal(1.50) },
]);

html`
  <ul>
    ${() => items.value.map(item => html`
      <li>${item.name} - $${item.price}</li>
    `)}
  </ul>
`
```

Each `${item.name}` is a reactive text node. If you change `items.value[0].name.value = 'Pear'`, only that text node updates. The list does not re-render.

---

## 5. DocumentFragments and Arrays

You can nest templates and pass arrays:

```typescript
const header = html`<h1>Title</h1>`;
const items = ['one', 'two', 'three'];

html`
  ${header}
  <ul>
    ${items.map(i => html`<li>${i}</li>`)}
  </ul>
`
```

`DocumentFragment` values are inserted directly. Arrays are flattened -- each item is converted to nodes.

---

## 6. Event Handlers -- @event

The `@` prefix binds event listeners:

```typescript
html`
  <button @click=${() => console.log('clicked!')}>Click me</button>
  <input @input=${(e: Event) => console.log((e.target as HTMLInputElement).value)} />
  <form @submit=${(e: Event) => {
    e.preventDefault();
    handleSubmit();
  }}>
    ...
  </form>
`
```

Any DOM event works. `@click`. `@input`. `@change`. `@submit`. `@keydown`. `@mouseenter`. `@focus`. `@blur`. If the browser fires it, tina4-js can bind it.

### Auto-Batching

Since v1.0.9, all event handlers are automatically wrapped in `batch()`. This means you can write to multiple signals in one handler and only get one DOM update:

```typescript
html`
  <button @click=${() => {
    firstName.value = 'Bob';
    lastName.value = 'Jones';
    age.value = 30;
  }}>Update All</button>
`
// Three signal writes, one DOM update
```

You do not need explicit `batch()` inside event handlers. It happens automatically.

---

## 7. Boolean Attributes -- ?attr

A button should be disabled while a form submits. A div should be hidden until data loads. A checkbox should be checked when a task is done. HTML boolean attributes -- `disabled`, `hidden`, `checked`, `readonly`, `required` -- need the `?` prefix:

```typescript
const isDisabled = signal(false);
const isHidden = signal(true);

html`
  <button ?disabled=${isDisabled}>Submit</button>
  <div ?hidden=${isHidden}>Secret content</div>
`
```

When the value is truthy, the attribute is added (e.g., `<button disabled>`). When falsy, the attribute is removed entirely.

Without the `?` prefix, you get a string attribute:

```typescript
// WRONG -- sets disabled="false" (which is still disabled!)
html`<button disabled=${isDisabled}>Submit</button>`

// RIGHT -- adds/removes the disabled attribute
html`<button ?disabled=${isDisabled}>Submit</button>`
```

This distinction catches everyone at least once. In HTML, `<button disabled="false">` is still disabled. The attribute exists. The browser does not read its value. The `?` prefix solves this by adding or removing the attribute entirely -- present means true, absent means false.

Boolean attributes accept signals, functions, and computed values:

```typescript
// Signal
html`<button ?disabled=${isDisabled}>Submit</button>`

// Function
html`<button ?disabled=${() => items.value.length === 0}>Submit</button>`

// Computed
const canSubmit = computed(() => name.value.length > 0);
html`<button ?disabled=${() => !canSubmit.value}>Submit</button>`
```

---

## 8. Property Bindings -- .prop

The `.` prefix sets DOM properties (not HTML attributes):

```typescript
const inputValue = signal('hello');

html`
  <input .value=${inputValue} />
  <div .innerHTML=${html`<strong>Bold text</strong>`} />
`
```

**`.value`** is the most common property binding. It sets the input's `value` property directly, which is different from the `value` attribute (the attribute is the initial value; the property is the current value).

**`.innerHTML`** is how you inject raw HTML. This is the only way to render HTML strings or inline SVG in tina4-js:

```typescript
const svgIcon = '<svg viewBox="0 0 24 24"><path d="M12 2L2 22h20L12 2z"/></svg>';

// WRONG -- renders as escaped text
html`<div>${svgIcon}</div>`
// Shows: <svg viewBox="0 0 24 24">...

// RIGHT -- renders as HTML
html`<div .innerHTML=${svgIcon}></div>`
// Shows the actual SVG triangle
```

**Warning:** `.innerHTML` bypasses XSS protection. Only use it with trusted content. Never pass user input to `.innerHTML`.

When a signal is passed to a property binding, it updates reactively:

```typescript
const content = signal('<em>Loading...</em>');

html`<div .innerHTML=${content}></div>`

// Later:
content.value = '<em>Done!</em>';
// The div's innerHTML updates
```

---

## 9. Dynamic Attributes -- attr=${value}

Regular attributes accept signals and functions for reactive updates:

```typescript
const color = signal('red');
const className = signal('active');

html`
  <div class=${className} style=${() => `color: ${color.value}`}>
    Styled text
  </div>
`
```

When `className` changes, the `class` attribute updates. When `color` changes, the `style` attribute updates.

### Reactive Classes

```typescript
const isActive = signal(true);

// Simple string signal
const cls = signal('btn btn-primary');
html`<button class=${cls}>Click</button>`

// Function-based
html`<div class=${() => isActive.value ? 'tab active' : 'tab'}>Tab</div>`
```

---

## 10. The false/null/undefined Trap

You will hit this. Everyone does. Here are the rules:

```typescript
${false}      // Renders the TEXT "false"
${true}       // Renders the TEXT "true"
${0}          // Renders the TEXT "0"
${null}       // Renders nothing (empty)
${undefined}  // Renders nothing (empty)
```

Only `null` and `undefined` render as nothing. `false`, `true`, and `0` are all converted to text.

This means the common React pattern does not work:

```typescript
// WRONG -- if show is false, renders the text "false"
html`${show.value && html`<p>Content</p>`}`

// RIGHT -- use a ternary, return null for "nothing"
html`${() => show.value ? html`<p>Content</p>` : null}`
```

The `&&` pattern is dangerous because `false && anything` evaluates to `false`, which the template renders as the string `"false"`. The ternary is the safe path. `null` is the empty output. Burn this pattern into memory: `condition ? content : null`.

---

## 11. Template Caching

The `html` tag caches parsed templates by the identity of the template strings array. The first call parses the HTML and creates a `<template>` element. Subsequent calls with the same template literal clone the cached template and bind fresh values.

This means:

- Templates in loops are only parsed once
- Cloning a `<template>` is fast (browser-native)
- The overhead per render is binding, not parsing

You do not need to do anything to benefit from this. It is automatic.

---

## 12. Putting It All Together

Static text. Reactive text. Reactive blocks. Event handlers. Boolean attributes. Property bindings. Conditional rendering. Here they all are, working together in a login form:

```typescript
import { signal, computed, html } from 'tina4js';

function loginForm() {
  const email = signal('');
  const password = signal('');
  const loading = signal(false);
  const error = signal<string | null>(null);

  const isValid = computed(() =>
    email.value.includes('@') && password.value.length >= 8
  );

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    loading.value = true;
    error.value = null;

    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email.value,
          password: password.value,
        }),
      });

      if (!response.ok) throw new Error('Invalid credentials');
      // handle success...
    } catch (err) {
      error.value = (err as Error).message;
    } finally {
      loading.value = false;
    }
  };

  return html`
    <form @submit=${handleSubmit}>
      <h2>Login</h2>

      ${() => error.value
        ? html`<p style="color: red">${error}</p>`
        : null
      }

      <label>
        Email
        <input
          type="email"
          .value=${email}
          @input=${(e: Event) => { email.value = (e.target as HTMLInputElement).value; }}
          ?disabled=${loading}
        />
      </label>

      <label>
        Password
        <input
          type="password"
          .value=${password}
          @input=${(e: Event) => { password.value = (e.target as HTMLInputElement).value; }}
          ?disabled=${loading}
        />
      </label>

      <button
        type="submit"
        ?disabled=${() => !isValid.value || loading.value}
      >
        ${() => loading.value ? 'Logging in...' : 'Login'}
      </button>
    </form>
  `;
}
```

Every binding type from this chapter appears in this form:

- **`.value=${email}`** -- property binding keeps the input's DOM property in sync with the signal
- **`@input`** -- event handler updates the signal when the user types
- **`?disabled=${loading}`** -- boolean attribute toggles from a signal
- **`?disabled=${() => !isValid.value || loading.value}`** -- boolean attribute from a function
- **`${() => loading.value ? 'Logging in...' : 'Login'}`** -- reactive text block swaps the button label
- **`${() => error.value ? html\`...\` : null}`** -- conditional rendering with the ternary pattern

One template. Six binding types. Zero manual DOM updates. The template engine handles every transition between states, and the form responds the moment data changes.

---

## Summary

| Syntax | What it does | Reactive? |
|---|---|---|
| `${value}` | Static text node, XSS-safe | No |
| `${signal}` | Reactive text node | Yes |
| `${() => expr}` | Reactive block (conditionals, lists) | Yes |
| `${fragment}` | Insert DocumentFragment | No |
| `${array}` | Render each item | No |
| `@click=${fn}` | Event listener (auto-batched) | - |
| `?disabled=${x}` | Boolean attribute (add/remove) | If signal/function |
| `.value=${x}` | DOM property binding | If signal |
| `.innerHTML=${x}` | Raw HTML injection | If signal |
| `class=${x}` | Regular attribute | If signal/function |
