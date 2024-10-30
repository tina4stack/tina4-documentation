# Static Website with Twig/Jinja

##   **1. Adding Twig Templates**
### **Creating a Basic Template (`base.twig`)**

A base template can be used to define the common layout of your pages, which makes maintaining a consistent design easier. Create a file named `base.twig` in the `src/templates` folder.

```bash
<!-- src/templates/base.twig -->
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

In `base.twig`, the `{% block content %}` tag defines a section that child templates can override. The `{{ title }}` variable will be used to set the page's title dynamically.


## **2. Adding Navigation (`navigation.twig`)**

Since navigation is a common part of multiple pages, create a reusable navigation bar. This template will be included in other pages as needed.


```bash
<!-- src/templates/navigation.twig -->
<nav>
    <a href="/">Home Page</a>
    <a href="/about-us">About Us</a>
</nav>
```

## **3. Creating Dynamic Pages**

###  **Home Page (`index.twig`)**

The home page (`index.twig`) extends `base.twig` and includes `navigation.twig` to create a consistent layout. The title is set using a Twig/Jinja2 variable.


```bash
<!-- src/templates/index.twig -->
{% set title = "Home Page" %}
{% extends "base.twig" %}

{% block content %}
<h1>{{ title }}</h1>
{% include "navigation.twig" %}
<h2>Wonderful Content</h2>
<p>Here is some content about the page</p>
{% endblock %}
```

### **About Us Page (`about-us.twig`)**

The About Us page (`about-us.twig`) is structured similarly to the home page. It also extends `base.twig` and includes `navigation.twig`


```bash
<!-- src/templates/about-us.twig -->
{% set title = "About Us" %}
{% extends "base.twig" %}

{% block content %}
<h1>{{ title }}</h1>
{% include "navigation.twig" %}
<h2>Wonderful Content</h2>
<p>Here is some content about the page</p>
{% endblock %}
```
##  **4. Static Website and Caching**

One of the benefits of using Tina4 with Twig templating is the ability to build efficient static pages and cache website content automatically.

All Twig files in the `src/templates` directory are rendered out of the box without needing to install extra renderers. This helps with building reusable pieces of code and improves the site's performance by caching static HTML files.


##  **5. Final Project Structure**

After following these steps, your project should have a structure similar to this:

    project-folder/ 
    			├── src/ 
    				│ └── templates/ 
    							│├── base.twig 
    							│├── index.twig 
    							│├── about-us.twig 
    							│└── navigation.twig 
    			├── app.py 
    			└── other project files...




## Reference Documentation & Help

- **TWIG** - [Twig Documentation](https://twig.symfony.com/doc/)
- **Jinja** - [Jinja Documentation](https://jinja.palletsprojects.com/en/3.1.x/)

## Hot Tips
>- Notice the use of the `block` and `title` where we can inject content
>- Use the reference documentation to learn and understand Twig templating