---
outline: deep
---

<div v-pre>

# Static Websites with Frond (Twig) Templates

Tina4 renders templates from `src/templates/pages/` and matches them to URLs by filename. Put `index.twig` in `src/templates/pages/`. It serves at `/`. Put `cars.twig` next to it. It serves at `/cars`. No routes needed: Tina4 reads the directory and does the wiring.

Only files inside `pages/` auto-route. Shared templates outside it (`base.twig`, partials, layouts, `errors/`) are render-only (`response.render(...)`) and never served from a URL. Files whose name starts with `_` (e.g. `_partial.twig`) stay private. Turn the whole feature off with `TINA4_TEMPLATE_ROUTING=off`.

Routes always take precedence. If you define a route for `/cars`, the route handler runs. If you don't, the `pages/cars.twig` template renders.

## Quick Start

```bash
tina4 init python mysite    # or: tina4 init php mysite
cd mysite
tina4 serve
```

Open http://localhost:7145. The landing page renders from `src/templates/pages/index.twig`.

## Project Structure

```
mysite/
  .env
  src/
    templates/
      base.twig          # Shared layout - render-only, never auto-served
      pages/
        index.twig       # /
        about.twig       # /about
        products.twig    # /products
    public/
      css/
        tina4.min.css    # Ships with Tina4 - no CDN needed
    scss/
      main.scss          # Your custom SCSS - auto-compiles to public/css/
```

## Step 1: Base Layout

Every page shares a layout. Define it once in `base.twig`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}My Site{% endblock %}</title>
    <link rel="stylesheet" href="/css/tina4.min.css">
</head>
<body>
    <nav class="navbar navbar-dark">
        <div class="container">
            <a href="/" class="navbar-brand">My Site</a>
            <div class="navbar-nav">
                <a href="/" class="nav-link">Home</a>
                <a href="/about" class="nav-link">About</a>
                <a href="/products" class="nav-link">Products</a>
            </div>
        </div>
    </nav>

    <div class="container mt-4">
        {% block content %}{% endblock %}
    </div>

    <footer class="container mt-4 mb-4 text-muted text-center">
        Built with Tina4
    </footer>

    <script src="/js/tina4.min.js"></script>
    <script src="/js/frond.min.js"></script>
</body>
</html>
```

The `tina4.min.css` and `tina4.min.js` files ship with the framework. No external CDN. No npm install. They're there when you scaffold.

## Step 2: Page Templates

Each page extends the base and fills in the content block.

**pages/index.twig** (serves at `/`):

```html
{% extends "base.twig" %}

{% block title %}Home{% endblock %}

{% block content %}
    <h1>Welcome</h1>
    <p>This page renders from a template. No route handler needed.</p>
{% endblock %}
```

**pages/about.twig** (serves at `/about`):

```html
{% extends "base.twig" %}

{% block title %}About{% endblock %}

{% block content %}
    <div class="card">
        <div class="card-body">
            <h2>About Us</h2>
            <p>We build things with Tina4.</p>
        </div>
    </div>
{% endblock %}
```

**pages/products.twig** (serves at `/products`):

```html
{% extends "base.twig" %}

{% block title %}Products{% endblock %}

{% block content %}
    <h2>Products</h2>
    <div class="row">
        <div class="col-md-4">
            <div class="card mb-3">
                <div class="card-body">
                    <h5 class="card-title">Widget</h5>
                    <p>A fine widget.</p>
                    <span class="badge badge-primary">$9.99</span>
                </div>
            </div>
        </div>
    </div>
{% endblock %}
```

Save the files. The browser reloads. Three pages, zero route definitions.

## Step 3: Add Styling with SCSS

Create `src/scss/main.scss`. Tina4 compiles it to `src/public/css/main.css` automatically:

```scss
$brand-color: #2c3e50;

body {
    font-family: system-ui, sans-serif;
}

.navbar {
    background: $brand-color;
}
```

Link it in your base template:

```html
<link rel="stylesheet" href="/css/tina4.min.css">
<link rel="stylesheet" href="/css/main.css">
```

SCSS compiles on startup and on file change (hot reload in dev mode). No Webpack, no Vite, no build step.

## When to Add Routes

Templates handle static content. When you need:

- **Database queries** - define a route, query the DB, pass data to the template
- **Form handling** - define a POST route
- **Authentication** - define routes with middleware
- **API endpoints** - define routes that return JSON

```python
# Python
@get("/products")
async def products(request, response):
    items = Product.all()
    return response.render("pages/products.twig", {"products": items})
```

```php
// PHP
Router::get("/products", function ($request, $response) {
    $products = (new Product())->select("*");
    return $response->render("pages/products.twig", ["products" => $products]);
});
```

The route takes over. The auto-rendered template steps aside.

</div>
