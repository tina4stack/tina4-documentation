# CSS / SCSS

::: tip 🔥 Hot Tips
- Drop `.scss` files in `src/scss/` → auto-compiled to `public/css/`
- Static CSS goes directly in `public/css/`
- Start with `--dev` flag to enable auto-compilation
:::

## Static CSS

Place CSS files in `public/css/` and reference them from templates:

```twig
<link href="/css/style.css" rel="stylesheet">
```

## SCSS Support

Create `.scss` files in `src/scss/`. When running in dev mode, they auto-compile:

```bash
tina4 start --dev
```

### Example

```scss
// src/scss/main.scss
$primary: #2c3e50;
$accent: #1abc9c;

body {
  font-family: system-ui, sans-serif;
  background: $primary;
  color: white;
}

.btn-accent {
  background: $accent;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  color: white;

  &:hover {
    background: darken($accent, 10%);
  }
}
```

Compiled output goes to `public/css/main.css`.

## In Templates

```twig
{% extends "base.twig" %}
{% block head %}
<link href="/css/main.css" rel="stylesheet">
{% endblock %}
```
