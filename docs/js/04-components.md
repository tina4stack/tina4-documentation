# Chapter 4: Components

## Web Components That Don't Suck

You build a button component in React. It works in React. You build one in Vue. It works in Vue. You build one in Angular. It works in Angular. Three frameworks. Three components. Same button.

Web Components solve this. One component. Every framework. Every page. Every context. The browser itself is the runtime.

The problem is that raw Web Components are verbose. Boilerplate for observed attributes. Manual attribute-to-property reflection. No reactive rendering. `Tina4Element` strips all of that away. You get reactive props, scoped styles, and template rendering -- with the full portability of native Web Components underneath.

---

## 1. What Are Tina4 Components

A Tina4 component is a Web Component. A real one. It extends `HTMLElement`, registers with `customElements.define()`, and works anywhere the browser runs. Drop it in a React app. Drop it in a static HTML page. Drop it in a WordPress theme. No framework runtime required to consume it.

`Tina4Element` adds three things on top of native Web Components:

1. **Reactive props** -- attributes become signals
2. **Scoped styles** -- CSS that cannot leak in or out (via Shadow DOM)
3. **Template rendering** -- your `render()` method returns `html` tagged templates

Everything else is standard Web Components. No magic. No hidden state. No framework lock-in.

---

## 2. Your First Component

```typescript
import { Tina4Element, html } from 'tina4js';

class GreetingCard extends Tina4Element {
  static props = { name: String };

  render() {
    return html`
      <div class="card">
        <h2>Hello, ${this.prop('name')}!</h2>
        <p>Welcome to tina4-js.</p>
      </div>
    `;
  }
}

customElements.define('greeting-card', GreetingCard);
```

Use it in HTML:

```html
<greeting-card name="Alice"></greeting-card>
```

Or in a template:

```typescript
html`<greeting-card name="Alice"></greeting-card>`
```

Change the attribute and the component updates:

```typescript
document.querySelector('greeting-card')!.setAttribute('name', 'Bob');
// The heading updates to "Hello, Bob!"
```

---

## 3. static props -- Declaring Reactive Props

The `static props` object declares which attributes the component observes. Each key is an attribute name, and the value is a type constructor:

```typescript
class UserCard extends Tina4Element {
  static props = {
    name: String,
    age: Number,
    active: Boolean,
  };

  render() {
    return html`
      <div>
        <h3>${this.prop('name')}</h3>
        <p>Age: ${this.prop('age')}</p>
        <p>${() => this.prop<boolean>('active').value ? 'Active' : 'Inactive'}</p>
      </div>
    `;
  }
}
```

### Type Coercion

HTML attributes are always strings. tina4-js coerces them based on the type you declare:

| Type | Coercion Rule | Example |
|---|---|---|
| `String` | Attribute value as-is, or `''` if absent | `name="Alice"` -> `'Alice'` |
| `Number` | `Number(value)`, or `0` if absent | `age="30"` -> `30` |
| `Boolean` | `true` if attribute exists, `false` if absent | `active` -> `true`, no attribute -> `false` |

Boolean props follow the HTML convention: the attribute's presence means `true`, its absence means `false`. The attribute value does not matter.

```html
<user-card name="Alice" age="30" active></user-card>
```

- `name` -> `'Alice'` (String)
- `age` -> `30` (Number)
- `active` -> `true` (Boolean, attribute is present)

```html
<user-card name="Bob" age="25"></user-card>
```

- `active` -> `false` (Boolean, attribute is absent)

---

## 4. this.prop(name) -- Reading Props

`this.prop('name')` returns a **signal** for the named prop. This means you can:

1. **Drop it in a template** for reactive rendering:

```typescript
html`<span>${this.prop('name')}</span>`
```

2. **Read its value** in methods:

```typescript
const currentName = this.prop<string>('name').value;
```

3. **Use it in computed/effects:**

```typescript
const greeting = computed(() => `Hello, ${this.prop<string>('name').value}!`);
```

When the HTML attribute changes (via `setAttribute` or from a parent template), the prop signal updates and everything that depends on it re-renders.

---

## 5. static styles -- Scoped CSS

```typescript
class StatusBadge extends Tina4Element {
  static props = { status: String };

  static styles = `
    :host {
      display: inline-block;
    }
    .badge {
      padding: 0.25rem 0.75rem;
      border-radius: 999px;
      font-size: 0.75rem;
      font-weight: 600;
      text-transform: uppercase;
    }
    .badge.active { background: #dcfce7; color: #166534; }
    .badge.inactive { background: #fee2e2; color: #991b1b; }
    .badge.pending { background: #fef3c7; color: #92400e; }
  `;

  render() {
    return html`
      <span class=${() => `badge ${this.prop<string>('status').value}`}>
        ${this.prop('status')}
      </span>
    `;
  }
}

customElements.define('status-badge', StatusBadge);
```

Styles are injected into the Shadow DOM `<style>` tag. They are completely scoped:

- `.badge` inside this component does not affect any `.badge` outside it
- External CSS does not affect elements inside this component
- The `:host` selector targets the component element itself

### The :host Selector

`:host` is a Shadow DOM feature. It selects the component's outer element (the custom element tag). Use it to set `display`, `margin`, `padding`, and other box-model properties:

```css
:host {
  display: block;
  margin-bottom: 1rem;
}
```

Without `:host { display: block }`, custom elements default to `display: inline`, which often causes unexpected layout behavior.

---

## 6. static shadow -- Light DOM vs Shadow DOM

By default, components use Shadow DOM (`static shadow = true`). Shadow DOM provides style encapsulation but has tradeoffs:

- **Shadow DOM (default):** Styles are scoped. External CSS cannot reach inside. Good for reusable components.
- **Light DOM:** No style encapsulation. Component renders directly into the page DOM. External CSS applies normally.

To use light DOM:

```typescript
class PageSection extends Tina4Element {
  static shadow = false;
  static props = { title: String };

  render() {
    return html`
      <section>
        <h2>${this.prop('title')}</h2>
        <slot></slot>
      </section>
    `;
  }
}
```

When `shadow` is `false`:

- `static styles` is ignored (no Shadow DOM to scope them)
- The component renders its content directly as children of the custom element
- Global CSS applies to the component's internal elements
- This is useful for layout components that need to inherit page styles

---

## 7. this.emit() -- Custom Events

Props flow down. Events flow up. A parent tells a child what to display through attributes. The child tells the parent what happened through custom events. This is the same pattern React uses with callbacks and Vue uses with `$emit` -- but here it is native DOM events, and they work across framework boundaries.

```typescript
class TodoItem extends Tina4Element {
  static props = { text: String, done: Boolean };

  render() {
    return html`
      <li>
        <input
          type="checkbox"
          ?checked=${this.prop('done')}
          @change=${() => this.emit('toggle')}
        />
        <span>${this.prop('text')}</span>
        <button @click=${() => this.emit('remove')}>x</button>
      </li>
    `;
  }
}

customElements.define('todo-item', TodoItem);
```

Listen for the event in the parent:

```typescript
html`
  <todo-item
    text="Buy milk"
    done
    @toggle=${() => toggleItem(0)}
    @remove=${() => removeItem(0)}
  ></todo-item>
`
```

### Passing Data with Events

```typescript
this.emit('select', { detail: { id: 42, name: 'Alice' } });
```

Listen for it:

```typescript
html`
  <user-list @select=${(e: CustomEvent) => {
    console.log(e.detail.id);   // 42
    console.log(e.detail.name); // 'Alice'
  }}></user-list>
`
```

Events are dispatched with `bubbles: true` and `composed: true` by default, so they cross Shadow DOM boundaries and bubble up the tree. You can listen for them anywhere above the component.

---

## 8. Lifecycle Hooks

Tina4Element provides two lifecycle hooks:

### onMount()

Called after the component's first render. Use it for setup that needs DOM access:

```typescript
class ChartWidget extends Tina4Element {
  static props = { data: String };

  onMount() {
    // DOM is ready, shadow root has content
    console.log('Chart mounted');
    // Initialize third-party library, set up intervals, etc.
  }

  render() {
    return html`<canvas id="chart"></canvas>`;
  }
}
```

### onUnmount()

Called when the component is removed from the DOM. Use it for cleanup:

```typescript
class LiveClock extends Tina4Element {
  private intervalId = 0;

  onMount() {
    this.intervalId = window.setInterval(() => {
      this.requestUpdate();
    }, 1000);
  }

  onUnmount() {
    clearInterval(this.intervalId);
  }

  render() {
    return html`<span>${new Date().toLocaleTimeString()}</span>`;
  }
}
```

Timers. Event listeners. WebSocket connections. Anything that outlives the DOM needs cleanup here. If you create it in `onMount()`, destroy it in `onUnmount()`. No exceptions.

---

## 9. Composing Components

Components compose naturally. Build small, focused components and combine them:

```typescript
// status-badge.ts
class StatusBadge extends Tina4Element {
  static props = { status: String };
  static styles = `
    :host { display: inline-block; }
    span { padding: 0.2rem 0.5rem; border-radius: 4px; font-size: 0.75rem; }
    .online { background: #dcfce7; color: #166534; }
    .offline { background: #fee2e2; color: #991b1b; }
  `;

  render() {
    return html`<span class=${this.prop('status')}>${this.prop('status')}</span>`;
  }
}
customElements.define('status-badge', StatusBadge);

// user-row.ts
class UserRow extends Tina4Element {
  static props = { name: String, email: String, status: String };
  static styles = `
    :host { display: flex; align-items: center; gap: 1rem; padding: 0.5rem 0; }
    .name { font-weight: 600; }
    .email { color: #6b7280; }
  `;

  render() {
    return html`
      <span class="name">${this.prop('name')}</span>
      <span class="email">${this.prop('email')}</span>
      <status-badge status=${this.prop('status')}></status-badge>
    `;
  }
}
customElements.define('user-row', UserRow);
```

Use in a page:

```typescript
html`
  <div>
    <user-row name="Alice" email="alice@test.com" status="online"></user-row>
    <user-row name="Bob" email="bob@test.com" status="offline"></user-row>
  </div>
`
```

---

## 10. The Store Pattern -- Shared Signals

A nav bar needs to know who is logged in. A dashboard needs the same data. A settings page can change it. Three components, one piece of state.

In React, you reach for Context or Redux. In Vue, you reach for Pinia. In tina4-js, you export signals from a module. That is it. No store library. No provider components. No boilerplate.

```typescript
// store.ts
import { signal, computed } from 'tina4js';

export const user = signal<{ name: string; role: string } | null>(null, 'current-user');
export const isLoggedIn = computed(() => user.value !== null);
export const isAdmin = computed(() => user.value?.role === 'admin');

export function login(name: string, role: string) {
  user.value = { name, role };
}

export function logout() {
  user.value = null;
}
```

Any component can import and use these signals:

```typescript
// nav-bar.ts
import { Tina4Element, html } from 'tina4js';
import { user, isLoggedIn, logout } from '../store';

class NavBar extends Tina4Element {
  static styles = `
    :host { display: flex; justify-content: space-between; padding: 1rem; }
    button { cursor: pointer; }
  `;

  render() {
    return html`
      <span>My App</span>
      <div>
        ${() => isLoggedIn.value
          ? html`
              <span>Welcome, ${user}!</span>
              <button @click=${() => logout()}>Logout</button>
            `
          : html`<a href="/login">Login</a>`
        }
      </div>
    `;
  }
}
customElements.define('nav-bar', NavBar);
```

No boilerplate. No providers. No context wrappers. No `mapStateToProps`. Signals are values. Import them. Use them. Every component that imports the same signal shares the same state, and every one of them updates when that state changes.

---

## 11. Complete Example -- A Card Component

```typescript
import { Tina4Element, html, signal } from 'tina4js';

class ProductCard extends Tina4Element {
  static props = {
    name: String,
    price: Number,
    image: String,
    instock: Boolean,
  };

  static styles = `
    :host { display: block; border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; }
    img { width: 100%; height: 200px; object-fit: cover; }
    .content { padding: 1rem; }
    h3 { margin: 0 0 0.5rem; }
    .price { font-size: 1.25rem; font-weight: 700; color: #059669; }
    .out-of-stock { color: #dc2626; font-size: 0.875rem; }
    button {
      width: 100%; padding: 0.75rem; border: none; border-radius: 4px;
      background: #2563eb; color: white; font-size: 1rem; cursor: pointer;
      margin-top: 0.5rem;
    }
    button:disabled { background: #9ca3af; cursor: not-allowed; }
  `;

  render() {
    const quantity = signal(1);

    return html`
      <img src=${this.prop('image')} alt=${this.prop('name')} />
      <div class="content">
        <h3>${this.prop('name')}</h3>
        <p class="price">$${this.prop('price')}</p>

        ${() => this.prop<boolean>('instock').value
          ? html`
              <div>
                <button @click=${() => { if (quantity.value > 1) quantity.value--; }}>-</button>
                <span>${quantity}</span>
                <button @click=${() => quantity.value++}>+</button>
              </div>
              <button @click=${() => {
                this.emit('add-to-cart', {
                  detail: {
                    name: this.prop<string>('name').value,
                    quantity: quantity.value,
                  },
                });
              }}>Add to Cart</button>
            `
          : html`<p class="out-of-stock">Out of Stock</p>`
        }
      </div>
    `;
  }
}

customElements.define('product-card', ProductCard);
```

Use it:

```typescript
html`
  <product-card
    name="Wireless Mouse"
    price="29"
    image="/images/mouse.jpg"
    instock
    @add-to-cart=${(e: CustomEvent) => {
      console.log(`Added ${e.detail.quantity}x ${e.detail.name}`);
    }}
  ></product-card>
`
```

---

## Summary

| Feature | How |
|---|---|
| Define a component | `class X extends Tina4Element` |
| Declare props | `static props = { name: String }` |
| Read a prop | `this.prop('name')` returns a signal |
| Scoped styles | `static styles = '...'` |
| Light DOM mode | `static shadow = false` |
| Fire events | `this.emit('name', { detail })` |
| After first render | `onMount()` |
| Before removal | `onUnmount()` |
| Register tag | `customElements.define('tag-name', Class)` |
| Shared state | Export signals from a module |
