# Getting Started with Tina4

One CLI runs all languages. Install it once, then `init` and `serve` in Python, Node.js, PHP, or Ruby.

## Install the Tina4 CLI

```bash
# macOS (Homebrew)
brew install tina4stack/tap/tina4

# Linux / macOS (install script)
curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/tina4stack/tina4/main/install.ps1 | iex
```

Verify the installation:

```bash
tina4 --version
```

## Check Your Environment

Run `tina4 doctor` to see which languages and package managers are available:

```bash
tina4 doctor
```

This shows installed languages (Python, PHP, Ruby, Node.js), their versions, and whether the package managers (uv, composer, bundler, npm) are ready. If a language is missing, install it with:

```bash
tina4 install python    # or php, ruby, nodejs
```

## Create a Project

Pick a language. Scaffold a project. Start the server. Three commands.

### Python

```bash
tina4 init python my-app
cd my-app
tina4 serve
```

Access your app at `http://localhost:7145`

Take a deeper dive into the [documentation](/python/index.md)

### Node.js

```bash
tina4 init nodejs my-app
cd my-app
tina4 serve
```

Access your app at `http://localhost:7148`

Take a deeper dive into the [documentation](/nodejs/index.md)

### PHP

```bash
tina4 init php my-app
cd my-app
tina4 serve
```

Access your app at `http://localhost:7146`

Take a deeper dive into the [documentation](/php/index.md)

### Ruby

```bash
tina4 init ruby my-app
cd my-app
tina4 serve
```

Access your app at `http://localhost:7147`

Take a deeper dive into the [documentation](/ruby/index.md)

## JavaScript (tina4-js)

The frontend framework runs separately from the backend. Scaffold it with npx:

```bash
npx tina4js create my-app
cd my-app
npm install
npm run dev
```

Access your app at `http://localhost:5173`

Take a deeper dive into the [documentation](/js/index.md)

## Delphi 10.4+

Design-time components for FireMonkey. Clone the repo, build and install the packages in your IDE.

```bash
git clone https://github.com/tina4stack/tina4delphi.git
# Open Tina4DelphiProject in the Delphi IDE
# Build and install Tina4Delphi (runtime package)
# Build and install Tina4DelphiDesign (design-time package)
# Components appear in the "Tina4" tool palette
```

Take a deeper dive into the [documentation](/delphi/index.md)

## Common CLI Commands

Once inside a project, the `tina4` CLI detects your language and delegates:

```bash
tina4 serve                  # Start dev server with file watcher and SCSS compilation
tina4 serve --production     # Use the best production server for your language
tina4 migrate                # Run database migrations
tina4 routes                 # List all registered routes
tina4 test                   # Run tests
tina4 generate model User    # Scaffold a model
tina4 generate route api     # Scaffold a route file
tina4 generate migration create_users  # Create a migration
tina4 ai                     # Install AI context files (CLAUDE.md, etc.)
tina4 books                  # Download the Tina4 book into your project
```
