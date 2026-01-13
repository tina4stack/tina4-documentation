# Getting Started with Tina4

## Python 3.12 > 

From your project folder install and initialize your project with these quick commands from your terminal:
```bash
# Install the package
pip install tina4-python jurigged
# Create a new project
tina4 init .
# Launch the development server (with hot-reloading enabled)
python -m jurigged app.py
```
Access your app at `http://localhost:7145`

Take a deeper dive into the [documentation](/python/index.md)

## PHP 8.0 >
Set up a Tina4 PHP project just as easily, inspired by Laravel's elegance but with a lighter footprint:
```bash
# Install the Tina4 PHP package
composer require tina4stack/tina4php
# Initialize the project structure
composer exec tina4 initialize:run
# Start the built-in server
composer start
```
Access your app at `http://localhost:7145`

Take a deeper dive into the [documentation](/php/index.md)