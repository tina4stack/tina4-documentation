"""Exercise 1 reference solution.

One of several correct shapes. The grader checks behaviour, not style, so a
student who reaches the same answers by a different route scores the same.
"""
from tina4_python.core.router import get

MENU = {"coffee": 25, "tea": 20, "juice": 30}


@get("/api/menu/{item}")
async def menu(request, response):
    item = request.params["item"].lower()

    if item not in MENU:
        return response({"error": "not on the menu", "item": item}, 404)

    return response({"item": item, "price": MENU[item]})
