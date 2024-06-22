# Static Website with Twig/Jinja

Before you begin understand that we prefer to use a template engine to render HTML.  Not only does this allow us to make reusable pieces of code but it also allows us to
build static pages and cache website efficiently.  All of this is done for you out of the box.  You don't even have to install the renderers. By default any file that is placed
in the templates folder with a `.twig` extension will be rendered.


## Base Template

Create a basic template to inherit your pages from, in the `src/templates/base.twig`.

**base.twig**
```html
<!DOCTYPE html>
<html>
<head>
<title>{{ title }}</title>
</head>
<body>
{% block content %}
{% endblock %}
</body>
</html>
```
>- Notice the use of the `block` and `title` where we can inject content
>- Use the reference documentation to learn and understand Twig templating

## Create a Navigation Page

We will use the navigation on every page 

**navigation.twig**
```html
<nav>
    <a href="/">Home Page</a>
    <a href="/about-us">About Us</a>
</nav>
```

## Reference Documentation & Help

- **TWIG** - [Twig Documentation](https://twig.symfony.com/doc/)
- **Jinja** - [Jinja Documentation](https://jinja.palletsprojects.com/en/3.1.x/)
