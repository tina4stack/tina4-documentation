from tina4_python.Router import get

@get("/route/name")
async def get_route(request, response):
    return response("Route")