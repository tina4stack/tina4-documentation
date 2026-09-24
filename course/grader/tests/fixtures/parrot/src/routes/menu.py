# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
