from tina4_python.Router import get

@get("/")
async def home(request, response):
    return response("Hello from Tina4!")

from tina4_python.Router import get

@get("/route/name")
async def get_route(request, response):
    return response("Route")