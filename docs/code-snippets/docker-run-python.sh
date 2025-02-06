### Windows
docker run -v %cd%:/app tina4stack/python:latest poetry init
docker run -v %cd%:/app tina4stack/python:latest poetry add tina4-python
echo import tina4_python > app.py
docker run -v %cd%:/app -p"7145:7145" tina4stack/python:latest python -u app.py 0.0.0.0:7145

### MacOS & Linux
docker run -v $(pwd):/app tina4stack/python:latest poetry init
docker run -v $(pwd):/app tina4stack/python:latest poetry add tina4-python
echo import tina4_python > app.py
docker run -v $(pwd):/app -p"7145:7145" tina4stack/python:latest python -u app.py 0.0.0.0:7145
