# Installation

This assumes you have python3 or above installed. You can find the python downloads [here](https://www.python.org/downloads/).
We recommend using the relevant package managers for your operating system if you're unsure what to download and install.


## Using UV for Project Setup

 We recommend using [UV](https://docs.astral.sh/uv/) as your package manager and virtual environment tool.
 UV is a fast, modern replacement for tools like `pip`, `virtualenv`, and `poetry`.It simplifies dependency management and speeds up installs dramatically.

Install UV:

```bash
pip install uv
```

Create a virtual environment and install `tina_4python`:

```bash
uv venv       # Create a virtual environment
uv pip install tina4_python
```

Optional (if supported): You can also use UV’s `add` command:
```bash
uv add tina4_python
```

If you decide not to use UV which is less recommended, you can install `tina4_python` using `pip`.

```bash
pip install tina4_python
```

## Setting up the `app.py`

After installation, create an `app.py` file in the root of your project with the following content:

```python title="app.py"
import tina4_python
```
Alternatively, use the command line to create the file with UTF-8 encoding:

```bash
Set-Content -Path app.py -Value 'import tina4_python' -Encoding utf8


```

For macOS/Linux:

```bash
echo import tina4_python > app.py
```

To initialize your project and run the default Tina4 web application, use:

```bash
uv run app.py
```

## Folder structure and layout

You should have a webservice running at [http://localhost:7145](http://localhost:7145) and the following folder structure would have been created:

**Project Folder**

- secrets
- migrations (create if needed)
- src
      - app : `classes go here`
      - orm : `database ORM classes go here`
      - public : `any public files to be served - treated as /`
        - css
        - images
        - js
        - swagger
      - routes : `routing logic goes here`
      - scss: `scss files go here and are compiled to public/css`
      - templates : ` jinja2/twig templates go here`
        - errors : ` error pages for 404 & 403 go here and can be customized `
