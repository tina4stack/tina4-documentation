# Docker

Using a docker you can be up and working within seconds. Pay attention to how the ports and directories are exposed in the docker.

## PHP
### Windows

```cmd
docker run -v %cd%:/app tina4stack/php:latest composer require tina4stack/tina4php
docker run -v %cd%:/app tina4stack/php:latest composer exec tina4 initialize:run
docker run -v %cd%:/app -p7145:7145 tina4stack/php:latest composer start
```

### MacOS & Linux

```bash
docker run -v $(pwd):/app tina4stack/php:latest composer require tina4stack/tina4php
docker run -v $(pwd):/app tina4stack/php:latest composer exec tina4 initialize:run
docker run -v $(pwd):/app -p7145:7145 tina4stack/php:latest composer start
```
#### Additional Docker Commands

```bash
#Get the PHP version
docker run tina4stack/php -v

#Get a list of PHP modules
docker run tina4stack/php -m

#Run a different PHP version
docker run tina4stack/php:7.4 -v
docker run tina4stack/php:8.1 -v

#Run a script with the PHP docker
docker run tina4stack/php test.php
```

### Composer

If your composer is configured and installed correctly then you can do the following in the terminal from your project root

```bash
composer require tina4stack/tina4php
composer exec tina4 initialize:run
composer start
```

## Python

### Windows
```cmd
docker run -v %cd%:/app tina4stack/python:latest poetry init
docker run -v %cd%:/app tina4stack/python:latest poetry add tina4-python
```
Create an application entry point as `app.py` with the following contents
```app.py
import tina4_python
```
Run the application, notice that the webserver needs to run on `0.0.0.0`
```
docker run -v %cd%:/app -p"7145:7145" tina4stack/python:latest python -u app.py 0.0.0.0:7145
```

### MacOS & Linux
```bash
docker run -v $(pwd):/app tina4stack/python:latest poetry init
docker run -v $(pwd):/app tina4stack/python:latest poetry add tina4-python
```
Create an application entry point as `app.py` with the following contents
```bash title="app.py"
import tina4_python
```
Run the application, notice that the webserver needs to run on `0.0.0.0`
```
docker run -v $(pwd):/app -p"7145:7145" tina4stack/python:latest python -u app.py 0.0.0.0:7145
```

