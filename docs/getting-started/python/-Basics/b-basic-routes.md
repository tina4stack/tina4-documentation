#  **Basic Routing Setup**

<br>

This tutorial will guide you through setting up routing in Tina4 Python. We’ll cover everything from creating basic routes to handling. We’ll also explore more advanced features such as integrating middleware, caching, and handling security tokens, giving you the tools to build a full web application. Database integration is optional for now, and we will focus on setting up the structure first.

<br>

### **Setting Up Your Project for Routing**

<br>

In Tina4 Python, routing is defined using decorators. To manage routes effectively, it’s common to use a dedicated file like `index.py` to organize your routes. Before we start creating routes, let’s make sure they are properly registered in our application

<br>

To include the routes in your Tina4 Python application, add the following import statement in `src/__init__.py`:

<br>

```bash
# src/__init__.py 
from .routes.index import *
```

This statement ensures that all the routes defined in `src/routes/index.py` become available to your app when it starts.

<br>

## **1.Creating Routes**

<br>

Now that the project is set up for routing, let’s begin by creating some basic GET routes and integrating them with the Twig templates we've already created in our practice project.

.


###  **Combining Routes with Twig Templates**

To make our project more dynamic, we will use the existing Twig templates (`base.twig`, `navigation.twig`, `index.twig`, `about-us.twig`) we created earlier and set up routes that render these templates.

<br>

##  **2.Rendering the Home Page**

<br>

Let's start by creating a route for the home page that will use the `index.twig` template. We will pass some static educational content to this template to illustrate how to send data from the route.

```bash
# src/routes/index.py
from tina4_python.Router import get  # Importing the routing decorator to define GET routes
from tina4_python.Template import Template  # Importing the Template class to render Twig templates

# Route for Home Page
@get("/")  # Defining a GET route for the root URL ("/")
async def home(request, response):
    # Creating a dictionary with static content to pass to the template
    content = {
        "title": "Home Page",
        "subtitle": "Learn Tina4 Python with Ease",
        "message": "Welcome to our educational demo of Tina4 Python and Twig!"
    }
    # Rendering the index.twig template with the provided content
    html = Template.render_twig_template("index.twig", content)
    # Returning the rendered HTML as the response
    return response(html)
```

<br>

Save this route in `src/routes/index.py`. This route will render the `index.twig` template when the root URL (`/`) is visited.

<br>

The corresponding `index.twig` file in the `src/templates` directory should display the content. As you can see below, `title`, `subtitle`, and `message` have now been added:

<br>

```bash
{% set title = title if title is defined else "Home Page" %} 
{% extends "base.twig" %}
 
{% block content %} 
	<h1>{{ title }}</h1> 
	{% include "navigation.twig" %} 
	<h2>{{ subtitle if subtitle is defined else "Wonderful Content" }}</h2> 
	<p>{{ message if message is defined else "Here is some content about the page." }}</p> 
{% endblock %}
```

<br>

##  **3.Rendering the About Us Page**

<br>

Next, let’s add a route for the About Us page, which will use the `about-us.twig` template. We will add some descriptive content for the page to display. Add this route to `src/routes/index.py`.

```bash
@get("/about-us") 
async def about_us(request, response):  
		content = { 
		"title": "About Us", 
		"description": "This is the About Us page for the Tina4 Python educational tutorial. Learn how to use routes and templates!" } 
		html = Template.render_twig_template("about-us.twig", content) 
		return response(html)
```

<br>

The corresponding `about-us.twig` file in the `src/templates` directory can display the provided content. As you can see below, `title` and `description` have now been added:


```bash
{% set title = title if title is defined else "About Us" %}  
{% extends "base.twig" %}  
  
{% block content %}  
		<h1>{{ title }}</h1>  
{% include "navigation.twig" %}  
		<h2>Wonderful Content</h2>  
		<p>{{ description if description is defined else "Here is some content about the page." }}</p>  
{% endblock %}
```

<br>

##  **4.Adding Dynamic Content with Route Parameters**

<br>

We can also add dynamic content by using route parameters. Let's create a route that greets the user by their name. Add this route to `src/routes/index.py`.


```bash
# Route for Greeting Page
@get("/hello/{name}")  # This is a dynamic route. The decorator registers the route for GET requests at `/hello/{name}`, where `{name}` is a placeholder that can be replaced with any value, such as `/hello/John`.
async def greet(request, response):
    # Extract the name parameter from the route
    name = request.params['name']  # Extracts the value of `{name}` from the URL. For instance, if the user visits `/hello/John`, `name` will be `"John"`.

    # Creating a dictionary with static content to pass to the template
    content = {
        "title": "Greeting Page",
        "message": f"Hello, {name}! Welcome to this demonstration of dynamic routing!"  # This creates a personalized message using the value of `name` (e.g., "Hello, John!").
    }

    # Rendering the Twig template 'greet.twig' and passing the content dictionary to it
    html = Template.render_twig_template("greet.twig", content)

    # Returning the rendered HTML as the response
    return response(html)

```

<br>

Now, create a new Twig file named `greet.twig` in the `src/templates` directory. This file will display a personalized greeting using the `name` variable passed from the route

```bash
# Route for Greeting Page 
<!-- src/templates/greet.twig --> 
{% set title = title if title is defined else "Greeting Page" %} 
{% extends "base.twig" %} 
{% block content %}
	 <h1>{{ message }}</h1> 
{% include "navigation.twig" %} 
{% endblock %}
```

<br>

The `greet.twig` template uses the `message` variable passed from the route to display a personalized greeting. The `title` is also set dynamically, and the navigation link is included using `navigation.twig`.

<br>

**Example and Navigation Update**

<br>

To make it easier for users to try out the dynamic route, we will update our navigation to include an example link to the greeting page. Update the `navigation.twig` file to include a link to `/hello/John`:


<br>

```bash
<!-- src/templates/navigation.twig -->
 <nav> 
	 <a href="/">Home Page</a>
	 <a href="/about-us">About Us</a> 
	 <a href="/hello/John">Greet John</a> 
 </nav>
```

<br>

Adding this link to the navigation menu allows users to easily try out dynamic content without manually typing in the URL. This improves usability for testing and demonstration purposes

<br>

With this update, users can easily click the link to greet “John,” which will navigate to `/hello/John` and display:

<br>

```bash
Hello, John! Welcome to this demonstration of dynamic routing!
```

<br>

Users can also manually enter other names by changing the URL to `/hello/{name}`, for example `/hello/Alice` to greet “Alice."

<br>

You can experiment by changing the greeting message or adding additional parameters to customize the experience further. For instance, add a `/hello/{name}/{age}` route to greet users by both name and age.

<br>

##  **5.Handling Request Data (Simplified Introduction)**

<br>

Tina4 Python provides an easy way to access request data. Here are a few common attributes:

- `request.params`: Get parameters from the route, as we used in the `/hello/{name}` example.
- `request.body`: Access data sent in form submissions or via API requests.

**Example of Handling Request Data**

<br>

```bash
@get("/info/{name}/{age}") 
async def user_info(request, response):
 	name = request.params['name'] 
 	age = request.params['age'] 
 	message = f"Hello, {name}! You are {age} years old." 
 	return response(message)
```

<br>

This route allows users to visit `/info/John/30` and get a response like:

<br>


```bash
Hello, John! You are 30 years old.
```

**Note:** In this section, we introduced how to access route parameters and request data, such as `request.params` and `request.body`. In the next tutorial, we will explore more advanced use cases with practical, hands-on examples where you can implement and test these features yourself.

<br>

##  **6.Summary**

<br>

In this tutorial, we’ve learned how to:

- Set up a basic routing structure.
- Render views using Twig templates.
- Create dynamic content using route parameters.
- Update navigation to improve usability
- Handle request data like route parameters.


The next steps will build on this foundation by introducing advanced routing techniques, form submissions, and security measures

<br>

###  **What's Next?**

<br>

In the next section, we will be exploring more advanced routing features and security measures. Specifically, we will:

1. **Integrate POST, PUT, PATCH, and DELETE Methods**: Learn how to handle form submissions and implement different HTTP methods to modify resources.
2. **Implement Security Tokens**: Understand how to use **CSRF tokens** for secure form submissions and **authorization tokens** to protect certain routes.
3. **Middleware and Caching**: Learn how to add middleware for processing requests and implement caching for better performance.

For now, we've introduced some basic features of handling request data and customizing responses. In future tutorials, we will revisit these features in more detail with practical examples for you to test out.
