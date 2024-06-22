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

## Create the Home Page

The home page we name `index.twig` so this file is loaded first on the webserver. Notice how we include the `navigation.twig` and set the title variable.

**index.twig**
```html
{% set title="Home Page" %}
{%  extends "base.twig" %}
{% block content %}
<h1> {{ title }}</h1>
{%  include "navigation.twig" %}
<h2>Wonderful Content</h2>
<p>
    Here is some content about the page
</p>
{% endblock %}
```

## Create the About Us Page

The about us page we name `about-us.twig` so this file will be loaded when we hit up `/about-us` route on the webserver.

**about-us.twig**
```html
{% set title="About Us" %}
{%  extends "base.twig" %}
{% block content %}
<h1> {{ title }}</h1>
{%  include "navigation.twig" %}
<h2>Wonderful Content</h2>
<p>
    Here is some content about the page
</p>
{% endblock %}
```


## Reference Documentation & Help

- **TWIG** - [Twig Documentation](https://twig.symfony.com/doc/)
- **Jinja** - [Jinja Documentation](https://jinja.palletsprojects.com/en/3.1.x/)
