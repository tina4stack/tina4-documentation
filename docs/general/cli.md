# Tina4 CLI Reference

The Tina4 CLI is a single binary that manages all four backend languages. It detects your project language, manages runtimes, compiles SCSS, watches files for dev-reload, and delegates to the language-specific CLI.

## Installation

**macOS (Homebrew):**

```bash
brew install tina4stack/tap/tina4
```

**Linux / macOS (install script):**

```bash
curl -fsSL https://raw.githubusercontent.com/tina4stack/tina4/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/tina4stack/tina4/main/install.ps1 | iex
```

Verify:

```bash
tina4 --version
```

---

All available commands:

```
Usage: tina4 <COMMAND>

Commands:
  doctor    Check installed languages and tools
  install   Install a language runtime (python, php, ruby, nodejs)
  init      Scaffold a new Tina4 project: tina4 init <language> <path>
  serve     Start the server with file watcher and SCSS compilation
  scss      Compile SCSS files from src/scss/ to src/public/css/
  migrate   Run database migrations (delegates to language CLI)
  test      Run tests (delegates to language CLI)
  routes    List registered routes (delegates to language CLI)
  generate  Generate scaffolding: model, route, migration, middleware
  ai        Detect AI coding tools and install framework context/skills
  upgrade   Upgrade a v2 Tina4 project to v3 structure
  update    Self-update the tina4 binary
  books     Download the Tina4 book into the current directory
```

## Commands

### tina4 doctor

Check which languages and tools are installed on your machine.

```bash
tina4 doctor
```

Example output:

```
Tina4 Doctor — Environment Check

  Language     Status     Version              Pkg Mgr      Version
  ──────────────────────────────────────────────────────────────────────
  Python       ✓          3.13.5               ✓ uv         0.8.19
  PHP          ✓          8.5.4                ✓ composer   2.9.5
  Ruby         ✓          4.0.1                ✓ bundler    4.0.8
  Node.js      ✓          24.9.0               ✓ npm        11.6.0

  Tina4 CLIs
  ──────────────────────────────────────────────────────────────────────
  ✓ tina4python      Python       installed
  ✓ tina4php         PHP          installed
  ✓ tina4ruby        Ruby         installed
  ✓ tina4nodejs      Node.js      installed
```

Shows installed languages, their versions, package managers, and whether the language-specific Tina4 CLIs are available.

---

### tina4 install

Install a language runtime.

```bash
tina4 install <language>
```

| Argument | Description |
|----------|-------------|
| `python` | Install Python runtime |
| `php` | Install PHP runtime |
| `ruby` | Install Ruby runtime |
| `nodejs` | Install Node.js runtime |

---

### tina4 init

Scaffold a new Tina4 project.

```bash
tina4 init <language> <path>
```

| Argument | Description |
|----------|-------------|
| `language` | `python`, `php`, `ruby`, or `nodejs` |
| `path` | Project directory (absolute or relative) |

Creates the standard Tina4 project structure:

```
my-app/
  src/
    routes/        # Route handlers
    orm/           # ORM models
    templates/     # Twig templates
    public/        # Static files (CSS, JS, images)
    scss/          # SCSS source files
  migrations/      # Database migration files
  .env             # Environment variables
```

---

### tina4 serve

Start the development server with file watcher and SCSS compilation.

```bash
tina4 serve [options]
```

| Option | Description |
|--------|-------------|
| `-p, --port <PORT>` | Port number. Defaults: Python 7145, PHP 7146, Ruby 7147, Node.js 7148 |
| `--host <HOST>` | Host address (default: 0.0.0.0) |
| `--dev` | Force dev server even if a production server is available |
| `--production` | Install and use the best production server for the detected language |

The CLI auto-detects your project language from the project files. It watches for file changes, recompiles SCSS, and reloads the server.

Production servers per language:
- **Python**: Hypercorn (ASGI)
- **PHP**: Tina4's built-in server
- **Ruby**: Puma
- **Node.js**: Node's built-in HTTP server

---

### tina4 scss

Compile SCSS files to CSS.

```bash
tina4 scss [options]
```

| Option | Description |
|--------|-------------|
| `-i, --input <DIR>` | Input directory (default: `src/scss`) |
| `-o, --output <DIR>` | Output directory (default: `src/public/css`) |
| `-m, --minify` | Minify the output |
| `-w, --watch` | Watch for changes and recompile |

---

### tina4 migrate

Run database migrations. Delegates to the language-specific CLI.

```bash
tina4 migrate                          # Run pending migrations
tina4 migrate --create <description>   # Create a new migration file
```

| Option | Description |
|--------|-------------|
| `--create <NAME>` | Create a new migration file with this description |

Migration files are created in the `migrations/` directory with sequential numbering.

---

### tina4 test

Run tests. Delegates to the language-specific CLI.

```bash
tina4 test
```

---

### tina4 routes

List all registered routes. Delegates to the language-specific CLI.

```bash
tina4 routes
```

Shows the HTTP method, path, and handler for every route in your project.

---

### tina4 generate

Generate scaffolding for common project components.

```bash
tina4 generate <what> <name>
```

| Argument | Description |
|----------|-------------|
| `model` | Generate an ORM model class |
| `route` | Generate a route file |
| `migration` | Generate a migration file |
| `middleware` | Generate a middleware class |

Examples:

```bash
tina4 generate model User
tina4 generate route api/products
tina4 generate migration create_users_table
tina4 generate middleware AuthCheck
```

---

### tina4 ai

Detect AI coding tools and install framework context files.

```bash
tina4 ai [options]
```

| Option | Description |
|--------|-------------|
| `--all` | Install context for ALL known AI tools (not just detected ones) |
| `--force` | Overwrite existing context files |

This detects tools like Claude Code, Cursor, GitHub Copilot, and installs CLAUDE.md, .cursorrules, or other context files that help AI assistants understand your Tina4 project.

---

### tina4 upgrade

Upgrade a v2 Tina4 project to the v3 structure.

```bash
tina4 upgrade
```

Restructures your project to follow the v3 conventions (src/routes, src/orm, src/templates, etc.).

---

### tina4 update

Self-update the tina4 binary to the latest version.

```bash
tina4 update
```

---

### tina4 books

Download the Tina4 book into the current directory.

```bash
tina4 books
```

Downloads the complete documentation book for your detected language.

---

## Environment Variables

The `.env` file in your project root configures the framework:

```bash
PROJECT_NAME="My Project"
VERSION=1.0.0
TINA4_DEBUG_LEVEL=ALL
DATABASE_NAME=sqlite3:data.db
TINA4_SECRET=your-secret-key
TINA4_LOCALE=en
```

All Tina4 frameworks read from the same `.env` format. The `tina4 init` command creates a default `.env` with sensible values.
