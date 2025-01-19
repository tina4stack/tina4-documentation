# Installation

This assumes you have python3 or above installed. You can find the python downloads [here](https://www.python.org/downloads/).
We recommend using the relevant package managers for your operating system if you're unsure what to download and install.

## Installing Poetry

We recommend allowing Poetry to manage your virtual environments for you.
Python virtual environment allows you to build and test different configurations of python without destroying your main system.
It may take some effort to understand how this works however it makes replicating your development environment and solutions on different computers.

```cmd
pip install poetry
```

Installing `tina4_python` is easy with poetry.

```cmd
poetry init
poetry add tina4_python
```

If you decide not to use poetry which is definitely not recommended, you can install `tina4_python` using pip.

```cmd
pip install tina4_python
```

## Setting up the `app.py`

After this all that is required is an `app.py` file in the root of your project with the following line of code:

```python title="app.py"
import tina4_python
```

You could also do the following:

```cmd
echo import tina4_python > app.py
```

Next to initialize your project you run the `app.py` and it will initialize the default application layout for you
and run a webservice.  We run our python project using poetry.

```cmd
poetry run python app.py
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
