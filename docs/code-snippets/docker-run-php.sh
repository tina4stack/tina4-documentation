### Windows
docker run -v %cd%:/app tina4stack/php:latest composer require tina4stack/tina4php
docker run -v %cd%:/app tina4stack/php:latest composer exec tina4 initialize:run
docker run -v %cd%:/app -p7145:7145 tina4stack/php:latest composer start


### MacOS & Linux
docker run -v $(pwd):/app tina4stack/php:latest composer require tina4stack/tina4php
docker run -v $(pwd):/app tina4stack/php:latest composer exec tina4 initialize:run
docker run -v $(pwd):/app -p7145:7145 tina4stack/php:latest composer start

