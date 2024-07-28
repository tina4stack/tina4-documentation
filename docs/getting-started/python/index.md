# Installation

This assumes you have python3 or above installed. You can find the python downloads [here](https://www.python.org/downloads/).
We recommend using the relevant package managers for your operating system if you're unsure what to download and install.

## Introduction to python virtual environments

The python virtual environment allows you to build and test different configurations of python without destroying your main system.
It may take some effort to understand how this works however it makes replicating your development environment and solutions on different computers.

The virtual environment works from within a folder on your project and should be added to your `.gitignore`

Below are the commands you can run in your project folder to activate a virtual environment:

*Windows*
```cmd
python -m venv .venv
.\.venv\Scripts\activate
```

*MacOs/Linux*
```bash
python3 -m venv .venv
source ./.venv/bin/activate
```

After you have activated your python virtual environment you can install the poetry package manager.
A package manager is a good way to maintain dependencies on your projects.  Poetry makes it practical to 
manage and deploy your projects.  You can read all about it [here](https://python-poetry.org)

On your virtual environment you can install poetry using pip and then initialize your project

```cmd
pip install poetry
poetry init
```

Installing `tina4_python` is easy with poetry.

```cmd
poetry add tina4_python
```

If you decide not to use poetry which is definitely not recommended, you can install `tina4_python` using pip.

```cmd
pip install tina4_python
```

After this all that is required is an `app.py` file in the root of your project with the following line of code:

**app.py**
```python
import tina4_python
```

You could also do the following:

```cmd
echo "import tina4_python" > app.py
```

Next to initialize your project you run the `app.py` and it will initialize the default application layout for you
and run a webservice.  We run our python project using poetry.

```cmd
poetry run python app.py
```

You should have a webservice running at [http://localhost:7145](http://localhost:7145) and the following folder structure would have been created:

- secrets
- src
  - app
  - orm
  - public
    - css
    - images
    - js
    - swagger
  - routes
  - scss
  - templates
    - errors