# Chapter 10: tina4-css

## Optional Styling

You build a prototype. The HTML is clean. The logic works. But the buttons look like 1998, the form inputs differ between Chrome and Safari, and the layout breaks on mobile. You reach for a CSS framework. It pulls in 300KB of utility classes you will never use.

tina4-css is the alternative. One stylesheet. Good defaults. Drop it in and your app looks professional. Override what you want, ignore the rest. And if you already have your own CSS -- skip this chapter entirely.

---

## 1. What Is tina4-css

tina4-css is a standalone CSS library. It is not part of tina4-js. It is a separate npm package that gives you:

- A CSS reset
- A responsive grid system
- Styled buttons, forms, tables, cards, badges, alerts
- Navigation components
- Modal dialogs
- Pagination
- A dark theme

The library is designed to look good with zero configuration. No theme files. No customization wizard. No build-time compilation. One file, and your app has a consistent, polished appearance across every browser.

---

## 2. Installation

### With the CLI

```bash
npx tina4 create my-app --css
```

This adds `tina4-css` to `package.json` and includes the stylesheet link in `index.html`. One flag. Done.

### Manual Installation

```bash
npm install tina4-css
```

Then include it in your `index.html`:

```html
<link rel="stylesheet" href="/node_modules/tina4-css/dist/tina4.min.css">
```

Or import it in your main TypeScript file (if your bundler supports CSS imports):

```typescript
import 'tina4-css/dist/tina4.min.css';
```

---

## 3. The Reset

tina4-css includes a modern CSS reset. It:

- Removes default margins and padding
- Sets `box-sizing: border-box` on everything
- Uses system fonts
- Sets sensible defaults for headings, links, lists, and form elements

Every browser ships with different default styles. A `<button>` in Chrome looks different from a `<button>` in Firefox looks different from a `<button>` in Safari. The reset eliminates these differences. Your app starts from a clean, predictable baseline.

---

## 4. Grid System

A responsive grid based on CSS Grid:

```html
<div class="grid grid-cols-3 gap-4">
  <div>Column 1</div>
  <div>Column 2</div>
  <div>Column 3</div>
</div>
```

Responsive variants:

```html
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
  <div>Item 1</div>
  <div>Item 2</div>
  <div>Item 3</div>
  <div>Item 4</div>
</div>
```

This renders 1 column on mobile, 2 on medium screens, and 4 on large screens. The layout adapts to the viewport. No JavaScript. No resize listeners. Pure CSS breakpoints.

---

## 5. Buttons

```html
<button class="btn">Default</button>
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-danger">Danger</button>
<button class="btn btn-outline">Outline</button>
<button class="btn btn-sm">Small</button>
<button class="btn btn-lg">Large</button>
```

Using with tina4-js:

```typescript
html`
  <button class="btn btn-primary" @click=${handleClick}>
    Save
  </button>
  <button
    class="btn btn-danger"
    @click=${handleDelete}
    ?disabled=${isDeleting}
  >
    ${() => isDeleting.value ? 'Deleting...' : 'Delete'}
  </button>
`
```

The `?disabled` binding and the reactive text work with tina4-css classes without conflict. The framework handles the DOM. The stylesheet handles the appearance. Each stays in its lane.

---

## 6. Forms

tina4-css styles form elements to look consistent across browsers:

```html
<form>
  <div class="form-group">
    <label>Name</label>
    <input type="text" class="form-control" placeholder="Enter name">
  </div>
  <div class="form-group">
    <label>Email</label>
    <input type="email" class="form-control" placeholder="Enter email">
  </div>
  <div class="form-group">
    <label>Role</label>
    <select class="form-control">
      <option>Admin</option>
      <option>Editor</option>
      <option>Viewer</option>
    </select>
  </div>
  <div class="form-group">
    <label>Notes</label>
    <textarea class="form-control" rows="3"></textarea>
  </div>
  <button type="submit" class="btn btn-primary">Submit</button>
</form>
```

With tina4-js signals:

```typescript
const name = signal('');
const email = signal('');

html`
  <form @submit=${(e: Event) => { e.preventDefault(); handleSubmit(); }}>
    <div class="form-group">
      <label>Name</label>
      <input
        type="text"
        class="form-control"
        .value=${name}
        @input=${(e: Event) => { name.value = (e.target as HTMLInputElement).value; }}
      />
    </div>
    <div class="form-group">
      <label>Email</label>
      <input
        type="email"
        class="form-control"
        .value=${email}
        @input=${(e: Event) => { email.value = (e.target as HTMLInputElement).value; }}
      />
    </div>
    <button type="submit" class="btn btn-primary">Save</button>
  </form>
`
```

The `.value` binding keeps the input synchronized with the signal. The `form-control` class keeps the input looking good. Signal-driven forms with polished styling -- no extra libraries required.

---

## 7. Tables

```html
<table class="table">
  <thead>
    <tr>
      <th>Name</th>
      <th>Email</th>
      <th>Role</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Alice</td>
      <td>alice@example.com</td>
      <td>Admin</td>
    </tr>
  </tbody>
</table>
```

Variants:

```html
<table class="table table-striped">...</table>
<table class="table table-hover">...</table>
```

With reactive data:

```typescript
const users = signal<User[]>([]);

html`
  <table class="table table-striped">
    <thead>
      <tr><th>Name</th><th>Email</th><th>Actions</th></tr>
    </thead>
    <tbody>
      ${() => users.value.map(user => html`
        <tr>
          <td>${user.name}</td>
          <td>${user.email}</td>
          <td>
            <button class="btn btn-sm" @click=${() => editUser(user)}>Edit</button>
          </td>
        </tr>
      `)}
    </tbody>
  </table>
`
```

The table re-renders when the `users` signal changes. Striped rows. Hover highlights. Edit buttons on every row. A data table with ten lines of template code.

---

## 8. Cards

```html
<div class="card">
  <div class="card-header">Card Title</div>
  <div class="card-body">
    <p>Card content goes here.</p>
  </div>
  <div class="card-footer">
    <button class="btn btn-primary">Action</button>
  </div>
</div>
```

Card grid:

```typescript
html`
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    ${() => products.value.map(product => html`
      <div class="card">
        <div class="card-body">
          <h3>${product.name}</h3>
          <p>$${product.price}</p>
        </div>
        <div class="card-footer">
          <button class="btn btn-primary btn-sm" @click=${() => addToCart(product)}>
            Add to Cart
          </button>
        </div>
      </div>
    `)}
  </div>
`
```

Three columns on desktop. One column on mobile. Each card has a body and a footer. The grid, the cards, and the reactive list all compose without friction.

---

## 9. Badges and Alerts

### Badges

```html
<span class="badge">Default</span>
<span class="badge badge-primary">Primary</span>
<span class="badge badge-success">Success</span>
<span class="badge badge-danger">Danger</span>
<span class="badge badge-warning">Warning</span>
```

### Alerts

```html
<div class="alert alert-info">This is an informational message.</div>
<div class="alert alert-success">Operation completed.</div>
<div class="alert alert-warning">Please check your input.</div>
<div class="alert alert-danger">Something went wrong.</div>
```

Reactive alerts:

```typescript
const error = signal<string | null>(null);

html`
  ${() => error.value
    ? html`<div class="alert alert-danger">${error}</div>`
    : null
  }
`
```

The alert appears when the error signal has a value. It vanishes when the error clears. No show/hide logic. No CSS transitions to manage. Set the signal. The DOM follows.

---

## 10. Navigation

```html
<nav class="navbar">
  <a class="navbar-brand" href="/">My App</a>
  <div class="navbar-nav">
    <a class="nav-link active" href="/">Home</a>
    <a class="nav-link" href="/about">About</a>
    <a class="nav-link" href="/contact">Contact</a>
  </div>
</nav>
```

With active route tracking:

```typescript
const currentPath = signal('/');
router.on('change', ({ path }) => { currentPath.value = path; });

html`
  <nav class="navbar">
    <a class="navbar-brand" href="/">My App</a>
    <div class="navbar-nav">
      <a class=${() => `nav-link ${currentPath.value === '/' ? 'active' : ''}`} href="/">Home</a>
      <a class=${() => `nav-link ${currentPath.value === '/about' ? 'active' : ''}`} href="/about">About</a>
    </div>
  </nav>
`
```

The `active` class moves to the current link as the user navigates. The navbar highlights where you are without a single line of imperative DOM manipulation.

---

## 11. Modals

```html
<div class="modal" id="myModal">
  <div class="modal-dialog">
    <div class="modal-header">
      <h3>Confirm Action</h3>
    </div>
    <div class="modal-body">
      <p>Are you sure?</p>
    </div>
    <div class="modal-footer">
      <button class="btn">Cancel</button>
      <button class="btn btn-danger">Delete</button>
    </div>
  </div>
</div>
```

Control with a signal:

```typescript
const showModal = signal(false);

html`
  ${() => showModal.value
    ? html`
        <div class="modal active">
          <div class="modal-dialog">
            <div class="modal-header">
              <h3>Confirm Delete</h3>
            </div>
            <div class="modal-body">
              <p>This action cannot be undone.</p>
            </div>
            <div class="modal-footer">
              <button class="btn" @click=${() => { showModal.value = false; }}>Cancel</button>
              <button class="btn btn-danger" @click=${() => { doDelete(); showModal.value = false; }}>
                Delete
              </button>
            </div>
          </div>
        </div>
      `
    : null
  }
`
```

One signal. One boolean. The modal exists in the DOM when the signal is true and vanishes when it is false. No jQuery. No imperative show/hide methods. The template is the single source of truth for what appears on screen.

---

## 12. Dark Theme

tina4-css includes a dark theme. Activate it by toggling a class on the `<html>` element:

```typescript
const darkMode = signal(false);

effect(() => {
  document.documentElement.classList.toggle('dark', darkMode.value);
});

html`
  <button @click=${() => { darkMode.value = !darkMode.value; }}>
    ${() => darkMode.value ? 'Light Mode' : 'Dark Mode'}
  </button>
`
```

All tina4-css components adapt to dark mode -- backgrounds, text colors, borders, form elements, cards, tables, alerts. One class toggles the entire palette. You write the toggle. tina4-css handles every surface.

---

## 13. Using with Shadow DOM Components

Shadow DOM components do not inherit external CSS. If you use `Tina4Element` with Shadow DOM (the default), tina4-css classes will not work inside the component. The Shadow DOM boundary blocks them.

Two options:

### Option 1: Light DOM

```typescript
class MyPage extends Tina4Element {
  static shadow = false; // External CSS applies

  render() {
    return html`
      <div class="card">
        <div class="card-body">
          <h3>This uses tina4-css</h3>
        </div>
      </div>
    `;
  }
}
```

### Option 2: Import CSS into Shadow DOM

```typescript
class MyComponent extends Tina4Element {
  static styles = `
    @import url('/node_modules/tina4-css/dist/tina4.min.css');
    /* Additional component styles */
  `;

  render() {
    return html`<button class="btn btn-primary">Works!</button>`;
  }
}
```

For most applications, the best balance is light DOM for pages (where tina4-css classes apply) and Shadow DOM for reusable widgets (where encapsulation matters). Pages get the full stylesheet. Widgets get isolation.

---

## Summary

| Component | Class |
|---|---|
| Buttons | `btn`, `btn-primary`, `btn-secondary`, `btn-danger`, `btn-outline`, `btn-sm`, `btn-lg` |
| Forms | `form-group`, `form-control` |
| Tables | `table`, `table-striped`, `table-hover` |
| Cards | `card`, `card-header`, `card-body`, `card-footer` |
| Badges | `badge`, `badge-primary`, `badge-success`, `badge-danger`, `badge-warning` |
| Alerts | `alert`, `alert-info`, `alert-success`, `alert-warning`, `alert-danger` |
| Navigation | `navbar`, `navbar-brand`, `navbar-nav`, `nav-link`, `active` |
| Modals | `modal`, `modal-dialog`, `modal-header`, `modal-body`, `modal-footer`, `active` |
| Grid | `grid`, `grid-cols-{n}`, `md:grid-cols-{n}`, `lg:grid-cols-{n}`, `gap-{n}` |
| Dark mode | Add `dark` class to `<html>` |
| Pagination | `pagination` |
