# Getting Started with Tina4

Kickstart your web development journey with Tina4—a lightweight, ASGI-compliant toolkit for Python (and PHP) that rivals the simplicity of Flask or FastAPI. Get up and running in minutes with zero boilerplate, hot-reloading, and built-in features like routing, templating, and Swagger docs. Whether you're building APIs, real-time apps, or full-stack sites, Tina4 makes it effortless.

## Python Setup

Install and initialize your project with these quick commands from your terminal:

```bash
# Install the package
pip install tina4-python jurigged

# Create a new project
tina4 init myproject

# Navigate into your project
cd myproject

# Launch the development server (with hot-reloading enabled)
python -m jurigged app.py
```

Your app will be live at `http://localhost:7145`—try editing files and watch changes reload instantly! For production, deploy with any ASGI server like Hypercorn or Uvicorn.

## PHP Setup

Set up a Tina4 PHP project just as easily, inspired by Laravel's elegance but with a lighter footprint:

```bash
# Create a new project directory
mkdir myproject

# Navigate into your project
cd myproject

# Install the Tina4 PHP package
composer require tina4stack/tina4php

# Initialize the project structure
composer exec tina4 initialize:run

# Start the built-in server
composer start
```

Access your app at `http://localhost:7145`. Enjoy seamless routing, Twig templating, and database integrations right out of the box—perfect for rapid prototyping or scalable apps.
