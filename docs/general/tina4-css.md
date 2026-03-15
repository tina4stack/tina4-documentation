# Tina4 CSS

Tina4 CSS is a lightweight, responsive CSS framework (~24KB minified) that ships built-in with every Tina4 framework — Python, Ruby, PHP, and JavaScript. It provides Bootstrap-compatible class names so you can build responsive UIs with zero external CDN dependencies.

## What's Included

| Component | Classes |
|-----------|---------|
| **Grid** | `.container`, `.row`, `.col-*`, responsive breakpoints (`sm`, `md`, `lg`, `xl`, `xxl`) |
| **Buttons** | `.btn`, `.btn-primary`, `.btn-outline-*`, `.btn-sm`, `.btn-lg`, `.btn-block` |
| **Forms** | `.form-group`, `.form-control`, `.form-label`, `.form-check`, validation states |
| **Cards** | `.card`, `.card-header`, `.card-body`, `.card-footer`, `.card-title` |
| **Navigation** | `.navbar`, `.navbar-dark`, `.navbar-light`, `.navbar-expand-*`, `.nav-link`, `.breadcrumb` |
| **Modals** | `.modal`, `.modal-dialog`, `.modal-content`, `.modal-header`, `.modal-body`, `.modal-footer` |
| **Alerts** | `.alert`, `.alert-success`, `.alert-danger`, `.alert-dismissible` |
| **Tables** | `.table`, `.table-striped`, `.table-hover`, `.table-bordered` |
| **Badges** | `.badge`, `.badge-primary`, `.badge-pill` |
| **Typography** | Headings, `.lead`, `blockquote`, `code`, `kbd`, lists |
| **Utilities** | Display, flex, spacing, text, colors, borders, shadows, position, visibility |

## Usage

Tina4 CSS ships with every Tina4 framework. Your `base.twig` template should include:

```twig
<link rel="stylesheet" href="/css/tina4.min.css">
<link rel="stylesheet" href="/css/default.css">
<script src="/js/tina4.js"></script>
<script src="/js/tina4helper.js"></script>
```

::: info
`tina4.js` provides JavaScript for modals, dismissible alerts, and navbar toggling — replacing the need for Bootstrap's JavaScript bundle.
:::

## Grid System

A 12-column flexbox grid with 5 responsive breakpoints:

```html
<div class="container">
  <div class="row">
    <div class="col-12 col-md-6 col-lg-4">Column 1</div>
    <div class="col-12 col-md-6 col-lg-4">Column 2</div>
    <div class="col-12 col-md-6 col-lg-4">Column 3</div>
  </div>
</div>
```

| Breakpoint | Class | Min Width |
|------------|-------|-----------|
| Small | `col-sm-*` | 576px |
| Medium | `col-md-*` | 768px |
| Large | `col-lg-*` | 992px |
| Extra Large | `col-xl-*` | 1200px |
| XXL | `col-xxl-*` | 1400px |

## Buttons

```html
<button class="btn btn-primary">Primary</button>
<button class="btn btn-outline-danger">Outline</button>
<button class="btn btn-success btn-lg">Large</button>
<button class="btn btn-dark btn-block">Full Width</button>
```

## Forms

```html
<div class="form-group">
  <label class="form-label">Email</label>
  <input type="email" class="form-control" placeholder="you@example.com">
</div>
<div class="form-check">
  <input class="form-check-input" type="checkbox" id="terms">
  <label class="form-check-label" for="terms">Accept terms</label>
</div>
```

## Cards

```html
<div class="card">
  <div class="card-header">Featured</div>
  <div class="card-body">
    <h5 class="card-title">Card Title</h5>
    <p class="card-text">Content goes here.</p>
    <a href="#" class="btn btn-primary">Action</a>
  </div>
</div>
```

## Modals

Modals work with `tina4.js` — no Bootstrap JavaScript needed:

```html
<!-- Trigger -->
<button class="btn btn-primary" data-t4-toggle="modal" data-t4-target="#myModal">
  Open Modal
</button>

<!-- Modal -->
<div class="modal" id="myModal">
  <div class="modal-dialog">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Title</h5>
        <button class="btn-close" data-t4-dismiss="modal">&times;</button>
      </div>
      <div class="modal-body">
        <p>Modal content.</p>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" data-t4-dismiss="modal">Close</button>
        <button class="btn btn-primary">Save</button>
      </div>
    </div>
  </div>
</div>
```

### Programmatic Modal API

```javascript
// Open
tina4.modal.open("#myModal");

// Close
tina4.modal.close("#myModal");
```

::: tip Bootstrap Compatibility
`data-bs-toggle`, `data-bs-target`, and `data-bs-dismiss` attributes also work — so existing Bootstrap templates migrate seamlessly.
:::

## Navigation

```html
<nav class="navbar navbar-expand-lg navbar-dark bg-dark">
  <div class="container">
    <a class="navbar-brand" href="/">My App</a>
    <button class="navbar-toggler" data-t4-toggle="collapse" data-t4-target="#navContent">
      &#9776;
    </button>
    <div class="navbar-collapse collapse" id="navContent">
      <ul class="navbar-nav">
        <li class="nav-item"><a class="nav-link active" href="/">Home</a></li>
        <li class="nav-item"><a class="nav-link" href="/about">About</a></li>
      </ul>
    </div>
  </div>
</nav>
```

## Alerts

```html
<div class="alert alert-success">Operation successful!</div>
<div class="alert alert-danger alert-dismissible">
  Error occurred.
  <button class="btn-close" data-t4-dismiss="alert">&times;</button>
</div>
```

## Tables

```html
<table class="table table-striped table-hover">
  <thead><tr><th>Name</th><th>Email</th></tr></thead>
  <tbody><tr><td>Andre</td><td>andre@example.com</td></tr></tbody>
</table>
```

## Utility Classes

| Category | Classes |
|----------|---------|
| **Display** | `.d-none`, `.d-block`, `.d-flex`, `.d-inline`, `.d-inline-block`, `.d-grid` |
| **Flex** | `.flex-row`, `.flex-column`, `.flex-wrap`, `.justify-content-*`, `.align-items-*` |
| **Spacing** | `.m-{0-5}`, `.p-{0-5}`, `.mt-*`, `.mb-*`, `.ms-*`, `.me-*`, `.mx-auto` |
| **Text** | `.text-start`, `.text-center`, `.text-end`, `.text-uppercase`, `.fw-bold`, `.fs-{1-6}` |
| **Colors** | `.text-primary`, `.text-danger`, `.bg-success`, `.bg-warning`, etc. |
| **Borders** | `.border`, `.border-0`, `.rounded`, `.rounded-pill`, `.rounded-circle` |
| **Shadows** | `.shadow-sm`, `.shadow`, `.shadow-lg`, `.shadow-none` |
| **Size** | `.w-25`, `.w-50`, `.w-75`, `.w-100`, `.h-*`, `.mw-100` |
| **Images** | `.img-fluid`, `.img-thumbnail` |
| **Position** | `.position-relative`, `.position-absolute`, `.position-fixed`, `.position-sticky` |
| **Responsive** | `.d-md-none`, `.d-lg-flex`, `.col-sm-6`, `.col-md-4`, `.col-lg-3` |

## Theming

Create a custom theme by overriding SCSS variables before importing tina4:

```scss
// src/scss/theme.scss

$primary:   #e74c3c;
$secondary: #2c3e50;
$success:   #27ae60;
$danger:    #c0392b;
$warning:   #f39c12;
$info:      #3498db;

$font-family-base: 'Inter', sans-serif;
$border-radius: 0.5rem;

@import 'tina4css/tina4';
```

All variables use `!default` so your overrides take priority.

## CSS Custom Properties

All design tokens are available as CSS custom properties for runtime theming:

```css
:root {
  --t4-primary: #4a90d9;
  --t4-secondary: #6c757d;
  --t4-font-family: system-ui, ...;
  --t4-border-radius: 0.25rem;
  --t4-shadow: 0 0.5rem 1rem rgba(0,0,0,0.15);
}
```

## Migrating from Bootstrap

Tina4 CSS uses the same class names as Bootstrap 5, so migration is straightforward:

1. Replace Bootstrap CDN links with local tina4 files
2. Replace `bootstrap.bundle.min.js` with `tina4.js`
3. Change `data-bs-*` attributes to `data-t4-*` (optional — `data-bs-*` still works)
4. Remove any Bootstrap Icons CDN (or keep them — they're independent)

::: warning
Tina4 CSS does not include JavaScript-heavy components like dropdowns, popovers, tooltips, or carousels. If you need these, add them as standalone micro-libraries.
:::

## Size Comparison

| Framework | Minified CSS | JavaScript |
|-----------|-------------|------------|
| **Tina4 CSS** | ~24KB | ~3KB |
| Bootstrap 5 | ~227KB | ~80KB |
| Tailwind CSS | ~300KB+ | — |

Tina4 CSS delivers 90% of Bootstrap's utility at 10% of the size.
