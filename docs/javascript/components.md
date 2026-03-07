# Web Components

tina4-js provides `Tina4Element`, a base class for building Web Components with reactive props, scoped styles, and lifecycle hooks.

## Basic Component {#basic}

```ts
import { Tina4Element, html } from 'tina4js';

class HelloWorld extends Tina4Element {
  render() {
    return html`<p>Hello, World!</p>`;
  }
}

customElements.define('hello-world', HelloWorld);
```

```html
<hello-world></hello-world>
```

Every component must:
1. Extend `Tina4Element`
2. Implement `render()` returning an `html` template
3. Be registered with `customElements.define()`

## Props {#props}

Declare reactive props with type coercion using `static props`:

```ts
class UserCard extends Tina4Element {
  static props = {
    name: String,
    age: Number,
    active: Boolean,
  };

  render() {
    return html`
      <div>
        <h2>${this.prop('name')}</h2>
        <p>Age: ${this.prop('age')}</p>
        <p>${() => this.prop('active').value ? 'Active' : 'Inactive'}</p>
      </div>
    `;
  }
}

customElements.define('user-card', UserCard);
```

```html
<user-card name="Andre" age="30" active></user-card>
```

### Prop Types

| Type | HTML attribute | Coercion |
|------|---------------|----------|
| `String` | `name="value"` | Used as-is |
| `Number` | `age="30"` | `Number(value)` |
| `Boolean` | `active` or `active="true"` | Presence = true, absence = false |

### Accessing Props

`this.prop('name')` returns a **signal** — it's reactive and auto-updates when the HTML attribute changes:

```ts
const nameSignal = this.prop('name');
console.log(nameSignal.value); // "Andre"

// In templates, the signal auto-binds:
html`<span>${this.prop('name')}</span>`;
```

## Internal State {#state}

Components can have their own signal state:

```ts
class TogglePanel extends Tina4Element {
  static props = { title: String };
  expanded = signal(false);

  render() {
    return html`
      <div>
        <button @click=${() => this.expanded.value = !this.expanded.value}>
          ${this.prop('title')}
          ${() => this.expanded.value ? '▾' : '▸'}
        </button>
        ${() => this.expanded.value ? html`<slot></slot>` : null}
      </div>
    `;
  }
}

customElements.define('toggle-panel', TogglePanel);
```

```html
<toggle-panel title="Details">
  <p>Hidden content revealed on click</p>
</toggle-panel>
```

## Shadow DOM {#shadow-dom}

By default, components use Shadow DOM for style encapsulation. Override with `static shadow = false`:

```ts
class LightComponent extends Tina4Element {
  static shadow = false; // Renders to light DOM

  render() {
    return html`<p>I inherit parent styles</p>`;
  }
}
```

| Mode | Styles | DOM access |
|------|--------|------------|
| `shadow = true` (default) | Scoped to component | Via shadow root |
| `shadow = false` | Inherits from parent | Direct DOM access |

## Scoped Styles {#styles}

Use `static styles` for CSS scoped to the component (Shadow DOM only):

```ts
class StyledButton extends Tina4Element {
  static styles = `
    :host {
      display: inline-block;
    }
    button {
      padding: 0.5rem 1rem;
      background: #2563eb;
      color: white;
      border: none;
      border-radius: 6px;
      cursor: pointer;
    }
    button:hover {
      background: #1d4ed8;
    }
  `;

  render() {
    return html`<button><slot></slot></button>`;
  }
}

customElements.define('styled-button', StyledButton);
```

```html
<styled-button>Click me</styled-button>
```

::: tip
`:host` targets the component element itself. Styles defined here won't leak out and external styles won't leak in.
:::

## Lifecycle Hooks {#lifecycle}

```ts
class MyWidget extends Tina4Element {
  render() {
    return html`<p>Widget</p>`;
  }

  onMount() {
    // Called when element is added to the DOM
    console.log('Mounted!');
  }

  onUnmount() {
    // Called when element is removed from the DOM
    console.log('Unmounted — clean up here');
  }
}
```

| Hook | When it fires |
|------|---------------|
| `render()` | Once, when first connected to DOM |
| `onMount()` | After render, element is in DOM |
| `onUnmount()` | Element removed from DOM |

## Custom Events {#events}

Emit events to communicate with parent elements:

```ts
class ColorPicker extends Tina4Element {
  render() {
    return html`
      <div>
        <button @click=${() => this.emit('color-change', { color: 'red' })}>Red</button>
        <button @click=${() => this.emit('color-change', { color: 'blue' })}>Blue</button>
      </div>
    `;
  }
}

customElements.define('color-picker', ColorPicker);
```

Listen from a parent:

```ts
html`
  <color-picker @color-change=${(e: CustomEvent) => {
    console.log(e.detail.color); // "red" or "blue"
  }}></color-picker>
`;
```

`this.emit(name, detail)` dispatches a `CustomEvent` with `bubbles: true` and `composed: true` so it crosses Shadow DOM boundaries.

## Slots {#slots}

Use `<slot>` for content projection (Shadow DOM):

```ts
class Card extends Tina4Element {
  static styles = `
    :host { display: block; border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; }
    .header { padding: 1rem; background: #f3f4f6; font-weight: bold; }
    .body { padding: 1rem; }
  `;

  render() {
    return html`
      <div class="header"><slot name="header">Default Header</slot></div>
      <div class="body"><slot></slot></div>
    `;
  }
}

customElements.define('ui-card', Card);
```

```html
<ui-card>
  <span slot="header">My Card Title</span>
  <p>Card content goes here</p>
</ui-card>
```

## Full Example {#full-example}

```ts
import { Tina4Element, html, signal, computed } from 'tina4js';

class ShoppingCart extends Tina4Element {
  static props = { currency: String };
  static styles = `
    :host { display: block; padding: 1rem; }
    .total { font-weight: bold; font-size: 1.25rem; margin-top: 1rem; }
    li { padding: 0.5rem 0; }
    button { cursor: pointer; }
  `;

  items = signal<{ name: string; price: number }[]>([]);
  total = computed(() =>
    this.items.value.reduce((sum, i) => sum + i.price, 0)
  );

  render() {
    const currency = this.prop('currency');
    return html`
      <h2>Cart</h2>
      <ul>
        ${() => this.items.value.map((item, i) => html`
          <li>
            ${item.name} — ${currency}${item.price.toFixed(2)}
            <button @click=${() => {
              this.items.value = this.items.value.filter((_, idx) => idx !== i);
            }}>&times;</button>
          </li>
        `)}
      </ul>
      ${() => this.items.value.length === 0
        ? html`<p>Cart is empty</p>`
        : html`<p class="total">Total: ${currency}${() => this.total.value.toFixed(2)}</p>`
      }
    `;
  }
}

customElements.define('shopping-cart', ShoppingCart);
```
