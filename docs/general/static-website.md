# Static Websites with Twig Templates

::: tip 🔥 Hot Tips
- Twig template handling comes with Tina4 out of the box, no configuration needed.
- First get to know Twig or Jinja2 by reading the documentation on their respective websites
- Use `{% extends .. %}` and `{% include .. %}` to simplify your pages and reuse functionality.
:::

Tina4 automatically renders templates from `src/templates`, matching routes with the filenames. For example, `index.twig` serves at `/`, and `cars.twig` at `/cars`. 

It is important to note that routes will take precedence over templates.

## Prerequisites
- Tina4 Python or PHP installed (see [Getting Started](/get-started)).
- Project structure (auto-created when initialize the project):
  ```
  myproject/
  ├── src/
  │   └── templates/      # Auto-rendered Twig files
  │       ├── base.twig   # Shared layout
  │       └── index.twig  # Home page (/ route)
  │       └── cars.twig  # Home page (/cars route)
  ```

## Step 1: Create the Base Layout (base.twig)
Define common elements in `./src/templates/base.twig`. This acts as the parent template for inheritance.

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
Add files like `./src/templates/index.twig` (auto-served at `/`) and `./src/templates/cars.twig` (at `/cars`). Each extends the base.

**index.twig**:
```twig
{% extends "base.twig" %}

{% block title %}Home Page{% endblock %}

{% block content %}
    <h2>Hello, World!</h2>
    <p>Explore our static site built with Tina4 and Twig—fast, simple, and auto-rendered.</p>
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


