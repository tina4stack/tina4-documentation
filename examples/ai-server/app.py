# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
"""Tina4 entry point for the local AI server.

``tina4 serve`` launches this; ``run()`` auto-discovers ``src/routes/`` and the AI
routes register themselves. There is nothing else to wire - Tina4 is the server.
"""
from tina4_python.core import run

if __name__ == "__main__":
    run()
