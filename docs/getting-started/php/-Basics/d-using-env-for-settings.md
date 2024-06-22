# Environment variable setup using .env files

Below is an example of the default `.env` file with some additional settings.  It is recommended that you set debug off in production.

## Example of .env file
```dotenv
[Project Settings]
VERSION=1.0.0
TINA4_DEBUG=true
# Set the debug level in the next line
TINA4_DEBUG_LEVEL=[TINA4_LOG_ALL]
# Items in square brackets are section headers
[Open API]
SWAGGER_TITLE=Tina4 Project
SWAGGER_DESCRIPTION=Edit your .env file to change this description
SWAGGER_VERSION=1.0.0
[OPEN AI API]
API_KEY=290021ABFEE2233CDEF
[FILES]
FILE_PATH=/home/files
[LISTS]
FRUIT=["apples", "oranges", "pears"]
VEGETABLES=["potatoes", "leeks", "carrots"]
```

## Accessing the .env variables

Any of the above settings can be accessed using the `$_ENV` global.

```php

$fruit = $_ENV["FRUIT"];
$vegetables = $_ENV["VEGETABLES"];

```

## Different environments

In order to have different environments you can set the ENVIRONMENT variable from your terminal before running the application.

### Windows
```cmd
set ENVIRONMENT="development"
```

### MacOS & Linux
```bash
export ENVIRONMENT="development"
```

The above implies that the following file `.env.development` will be used for the project.

>- Don't save your production .env in your git repo