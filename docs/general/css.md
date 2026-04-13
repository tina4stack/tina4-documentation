---
outline: deep
---

<div v-pre>

# Adding CSS with SCSS

Tina4 compiles SCSS to CSS with zero configuration. Drop `.scss` files in `src/scss/`. They compile to `src/public/css/` on server start and on every file save in dev mode.

No Webpack. No Vite. No PostCSS config. No build step.

## Project Structure

```
mysite/
  src/
    scss/
      _variables.scss       # Shared variables (partial — not compiled alone)
      main.scss             # Your styles — compiles to public/css/main.css
    public/
      css/
        tina4.min.css       # Ships with Tina4 (24KB, Bootstrap-compatible)
        main.css            # Your compiled output
```

## Quick Start

```bash
tina4 init python mysite
cd mysite
```

Create `src/scss/main.scss`:

```scss
$brand: #2c3e50;
$accent: #3498db;

body {
    font-family: system-ui, -apple-system, sans-serif;
    color: #333;
}

.hero {
    background: $brand;
    color: white;
    padding: 4rem 2rem;
    text-align: center;

    h1 {
        font-size: 2.5rem;
        margin-bottom: 1rem;
    }

    .btn {
        background: $accent;
        color: white;
        padding: 0.75rem 2rem;
        border: none;
        border-radius: 0.25rem;
        font-size: 1rem;
        cursor: pointer;

        &:hover {
            background: darken($accent, 10%);
        }
    }
}
```

Start the server:

```bash
tina4 serve
```

The CLI compiles `main.scss` to `src/public/css/main.css` and prints:

```
+ src/scss/main.scss -> src/public/css/main.css
+ Compiled 1 SCSS file
```

Link it in your template:

```html
<link rel="stylesheet" href="/css/tina4.min.css">
<link rel="stylesheet" href="/css/main.css">
```

## Partials

Files starting with `_` are partials. They get imported by other SCSS files but don't compile on their own.

```scss
// src/scss/_variables.scss
$brand: #2c3e50;
$font-stack: system-ui, sans-serif;
$radius: 0.5rem;
```

```scss
// src/scss/main.scss
@import 'variables';

.card {
    border-radius: $radius;
    font-family: $font-stack;
}
```

One output file: `main.css`. Clean imports, no duplication.

## tina4-css

Every Tina4 project ships with `tina4.min.css` — a 24KB CSS framework with Bootstrap-compatible class names. No CDN, no npm install.

| Component | Classes |
|-----------|---------|
| Grid | `.container`, `.row`, `.col-*`, responsive breakpoints |
| Buttons | `.btn`, `.btn-primary`, `.btn-outline-*`, `.btn-sm`, `.btn-lg` |
| Forms | `.form-group`, `.form-control`, `.form-label` |
| Cards | `.card`, `.card-body`, `.card-header`, `.card-footer` |
| Navigation | `.navbar`, `.navbar-dark`, `.nav-link` |
| Tables | `.table`, `.table-striped`, `.table-hover` |
| Alerts | `.alert`, `.alert-success`, `.alert-danger` |
| Badges | `.badge`, `.badge-primary` |
| Utilities | `.mt-4`, `.mb-3`, `.text-center`, `.d-flex`, `.justify-content-between` |

Use tina4-css as your base. Add your own SCSS on top for custom branding.

```html
<!-- Base framework -->
<link rel="stylesheet" href="/css/tina4.min.css">
<!-- Your custom styles -->
<link rel="stylesheet" href="/css/main.css">
```

## Hot Reload

In dev mode (`TINA4_DEBUG=true`), the server watches `src/scss/` for changes. Edit a `.scss` file, save it, and the browser reloads with the new CSS. No manual compile step.

## Production

The compiled CSS lives in `src/public/css/`. Commit it to source control. In production, the server serves the pre-compiled file directly — no runtime compilation overhead.

For deployment, the compiled CSS is just a static file. Any CDN, reverse proxy, or static host can serve it.

</div>
