# Project Setup
::: tip 🔥 Hot Tips
- Use `bundler` for dependency management
- Use a good IDE like RubyMine, VS Code, or Cursor
- Ruby 3.1+ recommended
:::

## Initialization

Create a new project with the CLI:

```bash
gem install tina4
tina4 init my-project
cd my-project
bundle install
tina4 start
```

- `gem install tina4`: Installs the Tina4 gem globally.
- `tina4 init my-project`: Creates project structure with folders (`routes/`, `templates/`, `public/`, `migrations/`) and starter files.
- `bundle install`: Installs dependencies from the generated `Gemfile`.
- `tina4 start`: Launches the development web server.

## Project Structure

```
my-project/
├── app.rb              # Main entry point with routes
├── Gemfile             # Ruby dependencies
├── .env                # Environment variables
├── .gitignore
├── routes/             # Auto-discovered route files
├── templates/          # Twig template files
│   └── base.twig       # Base layout template
├── public/             # Static assets (CSS, JS, images)
│   ├── css/
│   ├── js/
│   └── images/
├── migrations/         # SQL migration files
├── src/                # Additional application code
└── logs/               # Auto-rotating log files
```

## Default Webserver

Access the server at `http://localhost:7145`. Customize the listening address/port:

```bash
# Custom port
tina4 start --port 8001

# All interfaces on port 8001
tina4 start --host 0.0.0.0 --port 8001

# Development mode with auto-reload
tina4 start --dev
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `tina4 init [name]` | Initialize a new project |
| `tina4 start` | Start the web server |
| `tina4 migrate` | Run pending migrations |
| `tina4 migrate --create name` | Create a new migration |
| `tina4 test` | Run inline tests |
| `tina4 routes` | List all registered routes |
| `tina4 console` | Start an interactive Ruby console |
| `tina4 version` | Show Tina4 version |

## Debugging

Debug level defaults to `ALL` for development. Set `TINA4_DEBUG_LEVEL=Info` in `.env` for production.
Logs rotate automatically in the `logs/` directory.
