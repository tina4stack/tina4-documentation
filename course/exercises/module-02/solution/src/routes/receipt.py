"""Exercise 2 reference solution.

One of several correct shapes. The grader checks behaviour, so a student who
gets there differently scores the same.

Note the names. MENU and VAT_RATE are capitals because they are set once and
never change. ordered_items says what it holds and that it holds more than one.
subtotal, vat and total are the words a person would use at a till, which is
the right vocabulary because that is the domain this code lives in.
"""
from tina4_python.core.router import get

MENU = {"coffee": 25, "tea": 20, "juice": 30}
VAT_RATE = 0.15


@get("/api/receipt/{order}")
async def receipt(request, response):
    ordered_items = [name.strip().lower()
                     for name in request.params["order"].split(",")]

    unknown = [name for name in ordered_items if name not in MENU]
    if unknown:
        return response({"error": "not on the menu", "unknown": unknown}, 404)

    subtotal = 0
    for item in ordered_items:
        subtotal = subtotal + MENU[item]

    vat = round(subtotal * VAT_RATE, 2)
    total = round(subtotal + vat, 2)

    return response({
        "items": ordered_items,
        "subtotal": subtotal,
        "vat": vat,
        "total": total,
    })
