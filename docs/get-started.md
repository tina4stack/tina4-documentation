# Getting Started with Tina4

Pick your language. Run the commands. Your app starts in under a minute.

## JavaScript (tina4-js)

A reactive frontend in four lines. Signals handle state. Web Components handle structure. The whole framework weighs under 3KB.

```bash
npx tina4 create my-app
cd my-app
npm install
npm run dev
```
Access your app at `http://localhost:5173`

Take a deeper dive into the [documentation](/js/index.md)

## Python 3.12+

Install the package, scaffold the project, start the server. Hot-reloading watches your files and rebuilds on every save.

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

## Node.js 22+

Zero runtime dependencies. No native addons, no node-gyp. TypeScript works out of the box.

```bash
# Install the package
npm install tina4-nodejs
# Create a new project
tina4 init my-project
cd my-project
# Launch the development server
tina4 start
```
Access your app at `http://localhost:7145`

Take a deeper dive into the [documentation](/nodejs/index.md)

## Ruby 3.1+

ORM, migrations, and Twig templating included. One gem gives you the full stack.

```bash
gem install tina4ruby
tina4 init my-project
cd my-project
bundle install
tina4 start
```
Access your app at `http://localhost:7145`

Take a deeper dive into the [documentation](/ruby/index.md)

## PHP 8.0+

Composer pulls the package. The CLI scaffolds the project. The built-in server handles the rest.

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

## Delphi 10.4+

Design-time components for FireMonkey. Drop them on your form, configure in the Object Inspector, compile and run.

```bash
# Clone the repository
git clone https://github.com/tina4stack/tina4delphi.git
# Open the Tina4DelphiProject project group in the IDE
# Build and install Tina4Delphi (runtime package)
# Build and install Tina4DelphiDesign (design-time package)
# Components appear in the "Tina4" tool palette
```

Take a deeper dive into the [documentation](/delphi/index.md)
