# Installation Guide for Tina4 Python

Tina4 Python is a lightweight ASGI toolkit for web apps, APIs, and real-time services—prioritizing simplicity like Flask with async capabilities akin to FastAPI. This guide focuses on UV for fast, efficient setup (handling virtual environments and dependencies), with alternatives like pip and Poetry. UV streamlines workflows, similar to how Rye or Hatch enhance modern Python projects.

## Prerequisites
- **Python Version**: 3.8+ (3.10+ recommended for async performance).
- **UV Installation**: Install globally via `pip install uv` (or from [official docs](https://docs.astral.sh/uv/) for Rust-based speed).
- **Optional**: For Poetry, install via `pip install poetry`.

UV creates isolated environments automatically, reducing boilerplate compared to manual `venv` in Flask setups.

## Recommended: Installation with UV
UV is ideal for quick, reproducible environments—faster than pip, with automatic venv management like Poetry but lighter.

1. **Initialize the Project Environment**:
   ```bash
   uv init myproject  # Creates pyproject.toml, sets up venv automatically
   cd myproject
   ```

2. **Add Tina4**:
   ```bash
   uv add tina4-python  # Installs tina4-python and locks dependencies
   ```

3. **Initialize and Start the Project**:
   ```bash
   uv run tina4 init .  # Scaffolds app.py, templates/, etc. in current folder
   uv run tina4 start   # Launches dev server at http://localhost:7145 with hot-reloading
   ```

This mirrors FastAPI's `uvicorn main:app --reload` but with Tina4's minimalism. UV ensures deps are pinned in `uv.lock` for consistency.

## Alternative: Installation with pip
For basic setups without UV:

```bash
python -m venv .venv
source .venv/bin/activate  # Or .venv\Scripts\activate on Windows
pip install tina4-python
tina4 init myproject
cd myproject
python app.py
```

## Alternative: Installation with Poetry
For declarative management like npm in Node.js:

1. Initialize:
   ```bash
   poetry new myproject
   cd myproject
   ```

2. Add and Install:
   ```bash
   poetry add tina4-python
   poetry install
   ```

3. Run Commands:
   ```bash
   poetry run tina4 init .
   poetry run tina4 start
   ```

Poetry's `poetry.lock` ensures reproducibility, akin to FastAPI's dependency pinning.

## Verification
Access `http://localhost:7145/`. Edit `app.py` to test routing—changes hot-reload via Jurigged. You will need to install jurigged manually: `uv pip install jurigged` or add to dev dependencies `uv add jurigged --group=dev`. 

This UV-centric approach minimizes steps, promoting rapid iteration like leading micro-frameworks. Explore [Basic Routing](basic-routing.md) for routing examples.
