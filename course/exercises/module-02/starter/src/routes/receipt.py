# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Exercise 2: The Receipt.

Read BRIEF.md first.

Reminders from module 2:
  - request.params holds the path parameter
  - "a,b,c".split(",") gives you ["a", "b", "c"]
  - round(value, 2) rounds to 2 decimal places
  - name things so the next reader does not have to guess
"""
from tina4_python.core.router import get

MENU = {"coffee": 25, "tea": 20, "juice": 30}
VAT_RATE = 0.15


@get("/api/receipt/{order}")
async def receipt(request, response):
    # Your code here.
    #
    # 1. split the order into item names
    # 2. lowercase them so Coffee and coffee match
    # 3. if any item is not on the menu, return a 404
    # 4. add up the prices into a subtotal
    # 5. work out vat and total, both rounded to 2 decimals
    # 6. return items, subtotal, vat and total
    return response({"items": [], "subtotal": 0, "vat": 0, "total": 0})
