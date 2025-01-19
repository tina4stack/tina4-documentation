# Manual Control of the Webservice

Tina4 automatically creates a webservice on prot 7145, sometimes you need to run on a different port and manually control the start of the webservice.
This is achieved by running the application with a stop param

## Running the application with "stop"

Below is the standard command to run the tina4 application

```bash
poetry run python app.py stop
```

## Example under NGINX with Phusion Passenger

The following is a recipe to run a tina4 application under NGINX with Phusion Passenger

```python title="app.py"
import tina4_python
import sys

# start other threaded services here before starting the main app

# default port is 8080 otherwise we get the port from the NGINX param
default_port = 8080

# poetry run python app.py stop $PORT
if len(sys.argv) > 2:
    default_port = int(sys.argv[2])


tina4_python.run_web_server("0.0.0.0", default_port)
```


```conf title="webapp.conf"
server {
    listen 80;
    server_name localhost;
    root /home/app/webapp/src/public;

    # The following deploys your Ruby/Python/Node.js/Meteor app on Passenger.

    # Not familiar with Passenger, and used (G)Unicorn/Thin/Puma/pure Node before?
    # Yes, this is all you need to deploy on Passenger! All the reverse proxying,
    # socket setup, process management, etc are all taken care automatically for
    # you! Learn more at https://www.phusionpassenger.com/.
    passenger_enabled on;
    passenger_user app;

    passenger_python /usr/bin/python3.12;
    passenger_app_type wsgi;
    passenger_app_root /home/app/webapp;
    passenger_app_start_command "poetry run jurigged app.py stop $PORT";

    # Nginx has a default limit of 1 MB for request bodies, which also applies
    # to file uploads. The following line enables uploads of up to 50 MB:
    client_max_body_size 50M;
}
```

## Docker solution 

```Dockerfile title="Dockerfile"
FROM phusion/passenger-python312

# Allow poetry installations without prompting
ENV POETRY_NO_INTERACTION=1

# Enable nginx
RUN rm -f /etc/service/nginx/down

# Get rid of the default nginx site
RUN rm /etc/nginx/sites-enabled/default

# Add our webapp.conf
ADD ./webapp.conf /etc/nginx/sites-enabled/webapp.conf

# This copies your web app with the correct ownership when you want to deploy
# COPY --chown=app:app . /home/app/webapp
USER app

RUN curl -sSL https://install.python-poetry.org | python3.12 -

USER root

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /home/app/webapp/

```

### Example of running poetry installations in the docker

Use the following docker-compose file which exposes the whole project tp the `/home/app/webapp` folder

!!! note "This assumes you have the following files in your project source folder:"
    - app.py
    - Dockerfile
    - webapp.conf


```DockerCompose title="docker-compose.yml"
services:
  api:
    container_name: "tina4-api"
    restart: always
    build:
      context: .
      dockerfile: ./Dockerfile
    volumes:
      - ".:/home/app/webapp/"
    ports:
      - "8080:80"
```

### Running the docker

```bash
docker compose up
```

### Installing modules using poetry

```bash
docker exec -u app -it tina4-api /home/app/.local/bin/poetry add tina4_python
```
OR if you have an existing `pyproject.toml`
```bash
docker exec -u app -it tina4-api /home/app/.local/bin/poetry install
```

### Restarting the service inside the docker

Create the tmp folder in your project root.
```bash
mkdir tmp
```

Restart the service
```
docker exec -u app -it tina4-api touch /home/app/tmp/restart.txt
```

!!! tip "Hot Tips"
    - The docker can be accessed on http://localhost:8080
    - The docker runs NGINX which has Phusion passenger keeping the Python application running correctly on a random port
    - You don't need to run the docker environment to develop the application however this allows you to test an application destined for Docker deployment or Kubernetes

