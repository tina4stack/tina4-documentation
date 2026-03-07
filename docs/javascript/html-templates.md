# HTML Templates

The `html` tagged template literal is the rendering engine of tina4-js. It returns **real DOM nodes** (not virtual DOM) and automatically creates reactive bindings for signals.

## Basic Usage {#basic}

```ts
import { html } from 'tina4js';

const view = html`
  <div>
    <h1>Hello World</h1>
    <p>This returns a DocumentFragment</p>
  </div>
`;

document.getElementById('root')!.appendChild(view);
```

`html` returns a `DocumentFragment` — a lightweight container for DOM nodes that can be appended directly to the document.

## Interpolation {#interpolation}

### Static Values

```ts
const name = 'Andre';
const age = 30;

html`<p>${name} is ${age} years old</p>`;
```

### Signals (Reactive)

Signals interpolated directly auto-update the DOM when their value changes:

```ts
import { signal, html } from 'tina4js';

const count = signal(0);

// The <span> text updates automatically
html`<span>${count}</span>`;

count.value = 42; // DOM now shows "42"
```

### Dynamic Expressions

Use a function for conditional or computed content:

```ts
const score = signal(0);

html`<span>${() => score.value >= 50 ? 'Pass' : 'Fail'}</span>`;
```

### Null and Undefined

`null` and `undefined` render as empty text (nothing visible):

```ts
html`<p>${null}</p>`;      // renders: <p></p>
html`<p>${undefined}</p>`;  // renders: <p></p>
```

## Event Handlers {#events}

Use the `@` prefix to bind event handlers:

```ts
html`
  <button @click=${() => console.log('clicked!')}>Click me</button>
  <input @input=${(e: Event) => {
    const value = (e.target as HTMLInputElement).value;
    console.log(value);
  }}>
  <form @submit=${(e: Event) => {
    e.preventDefault();
    handleSubmit();
  }}>
`;
```

Any DOM event works: `@click`, `@input`, `@change`, `@keydown`, `@submit`, `@mouseover`, etc.

## Boolean Attributes {#boolean-attrs}

Use the `?` prefix for boolean attributes that should be toggled:

```ts
const disabled = signal(false);
const checked = signal(true);

html`
  <button ?disabled=${disabled}>Submit</button>
  <input type="checkbox" ?checked=${checked}>
`;

disabled.value = true;  // adds disabled attribute
disabled.value = false; // removes disabled attribute
```

## Reactive Attributes {#reactive-attrs}

Signal values in attributes auto-update:

```ts
const cls = signal('active');
const href = signal('/home');

html`
  <div class="${cls}">Styled</div>
  <a href="${href}">Link</a>
`;

cls.value = 'inactive'; // class updates
```

## Conditional Rendering {#conditionals}

Use a function that returns `html` or `null`:

```ts
const loggedIn = signal(false);

html`
  <div>
    ${() => loggedIn.value
      ? html`<p>Welcome back!</p><button @click=${() => { loggedIn.value = false; }}>Logout</button>`
      : html`<button @click=${() => { loggedIn.value = true; }}>Login</button>`
    }
  </div>
`;
```

When the signal changes, the DOM region is replaced automatically.

## List Rendering {#lists}

Use a function that maps to an array of templates:

```ts
const items = signal(['Apple', 'Banana', 'Cherry']);

html`
  <ul>
    ${() => items.value.map(item =>
      html`<li>${item}</li>`
    )}
  </ul>
`;

// Add an item — list re-renders
items.value = [...items.value, 'Date'];
```

### With Keys (Index-Based)

```ts
const todos = signal([
  { id: 1, text: 'Buy milk', done: false },
  { id: 2, text: 'Walk dog', done: true },
]);

html`
  <ul>
    ${() => todos.value.map(todo =>
      html`
        <li>
          <input type="checkbox" ?checked=${todo.done}>
          ${todo.text}
        </li>
      `
    )}
  </ul>
`;
```

## Nested Templates {#nested}

Templates compose naturally:

```ts
function header(title: string) {
  return html`<header><h1>${title}</h1></header>`;
}

function footer() {
  return html`<footer><p>Built with tina4-js</p></footer>`;
}

const page = html`
  <div>
    ${header('My App')}
    <main><p>Content here</p></main>
    ${footer()}
  </div>
`;
```

## Arrays of Templates {#arrays}

Arrays of `html` results are flattened automatically:

```ts
const buttons = ['Save', 'Cancel', 'Delete'].map(label =>
  html`<button>${label}</button>`
);

html`<div class="toolbar">${buttons}</div>`;
```

## Template Caching {#caching}

Templates are cached by their static string parts. This means identical template structures reuse the same parsed HTML, making repeated rendering efficient:

```ts
// These share the same cached template structure
for (let i = 0; i < 100; i++) {
  html`<li>${items[i]}</li>`;
}
```

## XSS Prevention {#xss}

String values are automatically text-escaped. Interpolated strings never create HTML elements:

```ts
const userInput = '<script>alert("xss")</script>';
html`<p>${userInput}</p>`;
// Renders: <p>&lt;script&gt;alert("xss")&lt;/script&gt;</p>
```

Only `html` tagged templates create actual DOM elements.

## Summary {#summary}

| Syntax | Purpose | Example |
|--------|---------|---------|
| `${value}` | Static interpolation | `${name}` |
| `${signal}` | Reactive text | `${count}` |
| `${() => expr}` | Dynamic expression | `${() => show.value ? 'Yes' : 'No'}` |
| `@event=${fn}` | Event handler | `@click=${handler}` |
| `?attr=${bool}` | Boolean attribute | `?disabled=${isDisabled}` |
| `attr="${signal}"` | Reactive attribute | `class="${cls}"` |
