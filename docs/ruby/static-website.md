# Static Website

::: tip 🔥 Hot Tips
- Put `.twig` templates in `templates/`
- Put static assets (CSS, JS, images) in `public/`
- Tina4 serves `public/` files automatically — no route needed
:::

## Template Files

Create `.twig` files in the `templates/` directory:

```twig
<!-- templates/index.twig -->
<!DOCTYPE html>
<html>
<head>
    <title>My Site</title>
    <link href="/css/style.css" rel="stylesheet">
</head>
<body>
    <h1>Welcome to My Site</h1>
    <p>Built with Tina4 Ruby</p>
</body>
</html>
```

## Static Assets

Files in `public/` are served automatically:

```
public/
├── css/
│   └── style.css
├── js/
│   └── app.js
└── images/
    └── logo.png
```

Access via:
- `/css/style.css`
- `/js/app.js`
- `/images/logo.png`

## Template Inheritance

Use Twig-style extends and blocks for layouts:

```twig
<!-- templates/base.twig -->
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}My Site{% endblock %}</title>
    {% block head %}{% endblock %}
</head>
<body>
    <nav>{% block nav %}{% endblock %}</nav>
    <main>{% block content %}{% endblock %}</main>
    {% block scripts %}{% endblock %}
</body>
</html>
```

```twig
<!-- templates/about.twig -->
{% extends "base.twig" %}
{% block title %}About Us{% endblock %}
{% block content %}
<h1>About Us</h1>
<p>We love Tina4!</p>
{% endblock %}
```

Serve it:

```ruby
Tina4.get "/about" do |request, response|
  response.render("about.twig")
end
```
