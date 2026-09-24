# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Exercise 1: The Cafe Menu.

Fill in the function below. Read BRIEF.md first.

Remember:
  - a path parameter arrives in request.params
  - returning a dict sends JSON
  - response(data, status_code) lets you choose the status
"""
from tina4_python.core.router import get

MENU = {"coffee": 25, "tea": 20, "juice": 30}


@get("/api/menu/{item}")
async def menu(request, response):
    # Your code here.
    #
    # 1. read the item the caller asked for
    # 2. treat COFFEE and coffee as the same thing
    # 3. if it is on the menu, send back {"item": ..., "price": ...}
    # 4. if it is not, send back a 404
    return response({"item": None, "price": None})
