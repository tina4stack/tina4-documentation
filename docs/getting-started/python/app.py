from tina4_python import App
import importlib.util
import pathlib

app = App()

# 👇 Automatically load all Python route files from src/routes
routes_path = pathlib.Path("src/routes")
for route_file in routes_path.glob("*.py"):
    spec = importlib.util.spec_from_file_location(route_file.stem, route_file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)