# Building a Static Website with Twig in Tina4

Tina4 simplifies static website creation through its built-in Twig templating engine, automatically rendering templates from `src/templates` at matching routes—no explicit routing needed. For example, `index.twig` serves at `/`, and `cars.twig` at `/cars`. This auto-rendering mirrors Flask's blueprint simplicity or FastAPI's minimalism, but with Twig's powerful inheritance for layouts, macros, and filters. Perfect for landing pages, blogs, or docs sites, it enables SSG-like output with Python's ease and hot-reloading for dev speed.

## Why Auto-Rendered Twig in Tina4?
- **Effortless Routing**: Templates map directly to URLs, reducing code—like Hugo's file-based routing but dynamic.
- **Template Inheritance**: Build reusable layouts (e.g., base with header/footer) for consistent sites, akin to Jinja in Flask.
- **Static-Friendly**: Render to HTML on-the-fly; export for hosting on Netlify/GitHub Pages via a build script.
- **SEO Boost**: Clean, semantic HTML with metadata, supporting fast loads and search visibility.

## Prerequisites
- Tina4 Python or PHP installed (see [Getting Started](/get-started)).
- Project structure (auto-created when you open the project in your browser for the first time):
  ```
  myproject/
  ├── src/
  │   └── templates/      # Auto-rendered Twig files
  │       ├── base.twig   # Shared layout
  │       └── index.twig  # Home page (/ route)
  │       └── cars.twig  # Home page (/cars route)
  └── static/             # CSS, JS, images (served automatically)
  ```

## Step 1: Create the Base Layout (base.twig)
Define common elements in `src/templates/base.twig`. This acts as the parent template for inheritance.

```twig
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}My Static Site{% endblock %}</title>
    <link rel="stylesheet" href="/css/default.css">  {# Link to static assets #}
</head>
<body>
    <header>
        <h1>Welcome to My Site</h1>
        <nav>
            <a href="/">Home</a>
            <a href="/cars">Cars</a>  {# Link to other auto-rendered pages #}
        </nav>
    </header>
    <main>
        {% block content %}{% endblock %}  {# Content block for child templates #}
    </main>
    <footer>
        <p>&copy; {{ "now"|date("Y") }} Your Name</p>  {# Dynamic year with Twig filter #}
    </footer>
</body>
</html>
```

## Step 2: Create Page Templates
Add files like `src/templates/index.twig` (auto-served at `/`) and `src/templates/cars.twig` (at `/cars`). Each extends the base.

**index.twig**:
```twig
{% extends "base.twig" %}

{% block title %}Home Page{% endblock %}

{% block content %}
    <h2>Hello, World!</h2>
    <p>Explore our static site built with Tina4 Python and Twig—fast, simple, and auto-rendered.</p>
{% endblock %}
```

**cars.twig**:
```twig
{% extends "base.twig" %}

{% block title %}Cars Section{% endblock %}

{% block content %}
    <h2>Our Cars</h2>
    <ul>
        <li>Model: Tesla Roadster</li>
        <li>Model: Ford Mustang</li>
    </ul>
{% endblock %}
```

- **Auto-Rendering**: No routes in `app.py` or `index.php` —Tina4 detects and renders `.twig` files at paths matching their names (minus extension).

## Step 3: Serve and Develop
Run `python app.py` or `composer start` —access at `http://localhost:7145/` (index) or `/cars`.


## Advanced Tips
- **Multi-Page Sites**: Add more `.twig` files (e.g., `about.twig` → `/about`)—scales like Jekyll.
- **Data Injection**: Pass variables via custom routes if needed, overriding auto-render.
- **Comparisons**: Faster setup than Flask (no route decorators for basics); secure like Twig in Symfony.
- **Deployment**: Static exports suit Vercel; full ASGI for interactive elements.

This approach gets you a polished static site in moments, embodying Tina4's lightweight ethos—try it and scale effortlessly! For deeper Twig syntax, see [Twig Docs](https://twig.symfony.com/) or [Jinja Docs](https://jinja.palletsprojects.com/en/stable/) .



