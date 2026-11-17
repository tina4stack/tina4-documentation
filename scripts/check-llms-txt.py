#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Check docs/public/llms.txt against the llmstxt.org specification.

The spec fixes the order of an llms.txt file:

  1. an optional byte-order mark;
  2. an H1 with the project name (the only required part);
  3. a blockquote with a short summary;
  4. zero or more free-form sections of any markdown EXCEPT headings
     (paragraphs, lists, code blocks);
  5. zero or more H2 sections that hold ONLY file lists, one item per line:
     ``- [name](url)``, optionally followed by ``: notes``. An H2 titled
     ``Optional`` holds links an agent may skip.

This script enforces that order, and that the file carries at least one link.
It also bans the punctuation the rest of the docs ban (scripts/audit-truth.py):
em and en dashes, smart quotes and the ellipsis character.

Every violation is printed with its line number and the script exits 1.

Zero dependencies.

    python3 scripts/check-llms-txt.py                  # docs/public/llms.txt
    python3 scripts/check-llms-txt.py path/to/llms.txt
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

DEFAULT = Path(__file__).resolve().parents[1] / "docs" / "public" / "llms.txt"

FENCE = re.compile(r"^\s*(```|~~~)")
ATX = re.compile(r"^ {0,3}(#{1,6})(?:\s|$)")
SETEXT = re.compile(r"^ {0,3}(=+|-+)\s*$")
LINK_ITEM = re.compile(r"^- \[[^\]\n]+\]\([^)\s]+\)(?:: .+)?$")
BANNED = re.compile("[\u2013\u2014\u2018\u2019\u201a\u201b\u201c\u201d\u201e\u201f\u2026\u2032\u2033]")


def check(text: str) -> tuple[list[tuple[int, str]], int]:
    """Return ([(line, message), ...], link count) for one llms.txt."""
    errors: list[tuple[int, str]] = []
    lines = text.lstrip("\ufeff").splitlines()

    # Classify every line once: inside a code fence or not.
    in_fence = False
    fenced: list[bool] = []
    for line in lines:
        if FENCE.match(line):
            fenced.append(True)
            in_fence = not in_fence
            continue
        fenced.append(in_fence)
    if in_fence:
        errors.append((len(lines), "a code fence is never closed"))

    def heading(i: int) -> int:
        """Heading level of line i (0 when it is not a heading). A setext
        underline counts against the text line above it."""
        if fenced[i]:
            return 0
        match = ATX.match(lines[i])
        if match:
            return len(match.group(1))
        nxt = i + 1
        if (nxt < len(lines) and not fenced[nxt] and lines[i].strip()
                and SETEXT.match(lines[nxt]) and not lines[i].lstrip().startswith(("-", "*", ">"))):
            return 1 if lines[nxt].strip().startswith("=") else 2
        return 0

    for number, line in enumerate(lines, 1):
        hit = BANNED.search(line)
        if hit:
            errors.append((number, f"banned character U+{ord(hit.group()):04X}; use ASCII"))

    # 1-2. The first non-blank line is the H1.
    i = 0
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines):
        return [(1, "the file is empty")], 0
    if not (heading(i) == 1 and ATX.match(lines[i])):
        errors.append((i + 1, "the file must start with an H1 (`# Project name`)"))
    elif not lines[i][1:].strip():
        errors.append((i + 1, "the H1 has no project name"))
    i += 1

    # 3. A blockquote summary right after the H1 (blank lines allowed).
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines) or not lines[i].startswith(">"):
        errors.append((min(i + 1, len(lines)), "a `> summary` blockquote must follow the H1"))

    # 4. Free-form zone: anything but a heading, up to the first H2.
    first_h2 = None
    for j in range(i, len(lines)):
        level = heading(j)
        if level == 2 and ATX.match(lines[j]):
            first_h2 = j
            break
        if level:
            errors.append((j + 1, f"heading (H{level}) before the file-list sections; the "
                                  "free-form part may hold any markdown except headings"))

    # 5. H2 sections: nothing but `- [name](url): notes` items and blank lines.
    links = 0
    if first_h2 is not None:
        section_has_items = False
        section_line = first_h2
        for j in range(first_h2, len(lines)):
            line = lines[j]
            level = heading(j)
            if level == 2 and ATX.match(line):
                if j != first_h2 and not section_has_items:
                    errors.append((section_line + 1, "H2 section has no links"))
                if not line[2:].strip():
                    errors.append((j + 1, "H2 has no title"))
                section_has_items, section_line = False, j
                continue
            if not line.strip():
                continue
            if level:
                errors.append((j + 1, f"H{level} inside the file-list sections; only H2 is allowed"))
            elif LINK_ITEM.match(line):
                links += 1
                section_has_items = True
            else:
                errors.append((j + 1, "H2 sections may hold only `- [name](url)` or "
                                      "`- [name](url): notes` list items"))
        if not section_has_items:
            errors.append((section_line + 1, "H2 section has no links"))

    if links == 0:
        errors.append((len(lines), "no `- [name](url)` links; an llms.txt is a map of links"))
    return sorted(errors), links


def main(argv: list[str]) -> int:
    path = Path(argv[1]) if len(argv) > 1 else DEFAULT
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        print(f"check-llms-txt: cannot read {path}: {error}", file=sys.stderr)
        return 2
    errors, links = check(text)
    for number, message in errors:
        print(f"{path}:{number}: {message}")
    if errors:
        print(f"check-llms-txt: {len(errors)} violation(s) of the llmstxt.org spec, {links} link(s)")
        return 1
    print(f"check-llms-txt: {path.name} follows the llmstxt.org spec ({links} links)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
