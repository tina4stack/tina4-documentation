# Project Structure

The following is a brief overview of the installed folder layout.  The layout only gets installed if no src folder is present in your working folder.

- `index.php` or `app.py` - application entry points
- `composer.json` or `pyproject.toml` - package management
- `composer.lock` or `poetry.lock` - package lock
- `.env` - environment variables
- **migrations** - database migrations are run from the route
- **src** - core source folder
  - **app** - place services or helper classes here 
  - **routes** - routing scripts and route declarations 
  - **orm** - place ORM classes here
  - **public** - public assets
    - **js** - javascript files
    - **css** - destination of compiled scss
  - **scss** - source scss files which are compiled to `public/css`
  - **services** - service classes 
  - **templates** - twig/jinja templates