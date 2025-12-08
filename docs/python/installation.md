# Project Setup
::: tip 🔥 Hot Tips
- Use `uv` for efficient dependency management. 
- Use a good IDE like PyCharm or IntelliJ
:::

## Initialization

Create a new project folder, add Tina4, initialize structure, and start the server:

```bash
uv init <project-name>
cd <project-name>
uv add tina4-python
uv run tina4 init .
uv run tina4 start
```

- `uv init`: Creates the project directory with a virtual environment.
- `uv add`: Installs `tina4-python` as a dependency.
- `tina4 init .`: Sets up Tina4 folders (e.g., `src/routes`, `src/templates`) and files in the current directory.
- `tina4 start`: Launches the development webserver.

## Default Webserver

Access the server at `http://localhost:7145`. Customize the listening address/port as the first argument:

```bash
# Loopback on port 8001
uv run tina4 start 8001

# All interfaces on port 8001
uv run tina4 start 0.0.0.0:8001
```

## Debugging

Debug level defaults to `All` for development. Set `TINA4_DEBUG_LEVEL=Info` environment variable for production to reduce verbosity.
Logs rotate automatically in the `logs/` directory to prevent excessive storage use.

