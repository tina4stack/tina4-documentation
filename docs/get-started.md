# Getting Started with Tina4

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
Access your app at `http://localhost:7145`

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
Access your app at `http://localhost:7145`