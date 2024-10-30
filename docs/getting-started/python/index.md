# Installation

This assumes you have Python 3 or above installed. You can find Python downloads [here](https://www.python.org/downloads/). We recommend using the appropriate package managers for your operating system if you're unsure what to download and install.


### **Install Poetry**

Poetry is a package manager that helps manage project dependencies. Install it by running:

```bash
curl -sSL https://install.python-poetry.org | python3 -
```


For Windows, use:
```bash
(Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | py -
```

Then add the following path to your system PATH:
```bash
%APPDATA%\pypoetry\venv\Scripts
```

[//]: # (### **Install Jurigged &#40;for Hot Reloading&#41;**)

[//]: # (Jurigged enables hot reloading while developing your Tina4 Python project:)

[//]: # ()
[//]: # (```bash)

[//]: # (pip install jurigged)

[//]: # (```)

## **Introduction to Python Virtual Environments**


The Python virtual environment allows you to build and test different configurations without affecting your main system. Though it may take some effort to understand initially, using a virtual environment ensures that you can easily replicate your development environment on different computers, maintaining consistency.


The virtual environment operates within a project folder and should be added to your `.gitignore` file. Below are the commands to create and activate a virtual environment within your project folder:


 **Windows**

```bash
python -m venv .venv
.\.venv\Scripts\activate
```

 **MacOS/Linux**

```bash
python3 -m venv .venv
source ./.venv/bin/activate
```



## **Initialize a Poetry Project**

After activating your Python virtual environment, initialize a Poetry project in your current folder:

```bash
poetry init
```

Alternatively, if you want to create a new project folder from scratch, you can do the following:

1. Create a new project:

```bash
poetry new project-name 
```

2. Navigate to the project folder:

```bash
cd project-name
```

3. Add the necessary dependencies:


```bash
poetry add tina4_python 
poetry add jurigged
```

## **Running Tina4 Python**


Create an entry point for Tina4 called `app.py` in the root of your project folder and add the following content:

```bash
from tina4_python import *
```

Alternatively, you can create the file using this command:


```bash
echo "from tina4_python import *" > app.py
```

To initialize your project, run `app.py` to create the default application layout and start a web service. Below are different ways to run your Tina4 Python server:


### **Normal Server**

```bash
poetry run python app.py
```


### **Server with Hot Reloading**

```bash
poetry run jurigged app.py
```

### **Server on a Specific Port**

```bash
poetry run python app.py 7777
```

### **Server without Auto Start**

```bash
poetry run python app.py manual
```

### **Server with Alternate Language (e.g., French)**


```bash
poetry run python app.py fr
```

## **Project Structure and Overview**

The basic Tina4 Python project uses an autoloader methodology from the `src` folder. All necessary source folders are created there, and they are run from `__init__.py`.

If you are developing on Tina4, make sure to copy the `public` folder from `tina4_python` into `src` to use its assets properly.

Once initialized, you should have a web service running at [http://localhost:7145](http://localhost:7145). The following folder structure will also be created:



-   secrets
-   src
-   app
-   orm
-   public
    -   css
    -   images
    -   js
    -   swagger
-   routes
-   scss
-   templates
    -   errors



This structure provides a foundation to start building your application, including directories for routes, templates, and static assets.


### **Installation without Poetry**

If you choose not to use Poetry (which is not recommended), you can alternatively install Tina4 Python using `pip`:


```bash
pip install tina4_python 
pip install jurigged
```

After this, create an `app.py` file with the following content:

```bash
import tina4_python
```

Run the server using:

```bash
python app.py
```

