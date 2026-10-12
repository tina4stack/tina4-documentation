#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Gate the numbered feature catalog and its four public feature pages."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "plan" / "v3"
CATALOG = PLAN / "FEATURE-CATALOG.json"
MATRIX = PLAN / "01-FEATURE-MATRIX.md"
PUBLIC_PAGES = (
    ROOT / "docs" / "python" / "38-feature-list.md",
    ROOT / "docs" / "php" / "38-feature-list.md",
    ROOT / "docs" / "ruby" / "37-feature-list.md",
    ROOT / "docs" / "nodejs" / "37-feature-list.md",
)
ACTIVE_FACT_PAGES = PUBLIC_PAGES + (
    ROOT / "docs" / "general" / "01-what-is-tina4.md",
    ROOT / "docs" / "python" / "01-getting-started.md",
    ROOT / "docs" / "php" / "01-getting-started.md",
    ROOT / "docs" / "ruby" / "01-getting-started.md",
    ROOT / "docs" / "nodejs" / "01-getting-started.md",
)
CATALOG_ROW = re.compile(r"^\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*$", re.MULTILINE)
STALE_CLAIMS = (
    "97 built-in features",
    "98 built-in features",
    "98 features",
    "same 98 features",
    "137 features",
    "138 features",
    "54 features",
    "same 97 features",
    "four identical frameworks",
    "Every feature below is present in all four",
    "Every feature is backed by real tests in all four",
    "single package per language, with zero runtime dependencies",
)

# Public-facing surfaces that state Tina4's TOTAL built-in count in prose. The
# catalog checks above cover the four feature-list pages; these are the map/prose
# surfaces that drifted (llms.txt said 97, comparisons.md said 44) precisely
# because nothing scanned them. They are gated here so the total cannot rot again.
EVERGREEN_TOTAL_PAGES = (
    ROOT / "docs" / "public" / "llms.txt",
    ROOT / "docs" / "comparisons.md",
)
# Counts that have been stated as the Tina4 TOTAL and were wrong. A byte size like
# "142 B" never matches (the phrase carries "features"/"built-in"), and a curated
# comparison subset ("44 features compared") is deliberately NOT blocked.
WRONG_TOTAL_PHRASES = (
    "78 features", "97 features", "97 built-in", "98 features", "98 built-in",
    "108 features", "137 features", "138 features", "142 features",
)


def fail(message: str) -> None:
    raise SystemExit(f"FEATURE FACT ERROR: {message}")


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    features = data.get("features", [])
    expected_ids = list(range(1, len(features) + 1))
    ids = [feature.get("id") for feature in features]
    if ids != expected_ids:
        fail(f"catalog IDs must be contiguous 1-{len(features)}; found {ids}")

    packet_ids = sorted(
        int(match.group(1))
        for packet in (PLAN / "features").glob("[0-9][0-9][0-9]-*.md")
        if (match := re.match(r"^(\d{3})-", packet.name))
    )
    if packet_ids != expected_ids:
        fail(f"feature packet IDs must be contiguous 1-{len(features)}; found {packet_ids}")

    names = [feature.get("name") for feature in features]
    slugs = [feature.get("slug") for feature in features]
    if len(names) != len(set(names)):
        fail("catalog names are not unique")
    if len(slugs) != len(set(slugs)):
        fail("catalog slugs are not unique")

    matrix = MATRIX.read_text(encoding="utf-8")
    for feature in features:
        packet = PLAN / feature["packet"]
        if not packet.is_file():
            fail(f"Feature {feature['id']} packet is missing: {packet}")
        needle = f'| {feature["id"]} | [{feature["name"]}]({feature["packet"]}) |'
        if matrix.count(needle) != 1:
            fail(f"Feature {feature['id']} must appear once in the active matrix")

    expected_rows = [(feature["id"], feature["name"]) for feature in features]
    for page in PUBLIC_PAGES:
        if not page.is_file():
            fail(f"public feature page is missing: {page}")
        rows = [(int(number), name.strip()) for number, name in CATALOG_ROW.findall(
            page.read_text(encoding="utf-8")
        )]
        if sorted(rows) != expected_rows or len(rows) != len(set(rows)):
            fail(
                f"{page.relative_to(ROOT)} does not match all "
                f"{len(features)} catalog entries"
            )

    for page in ACTIVE_FACT_PAGES:
        text = page.read_text(encoding="utf-8")
        for claim in STALE_CLAIMS:
            if claim in text:
                fail(f"{page.relative_to(ROOT)} contains stale claim: {claim!r}")

    expected_total = str(len(features))
    for page in EVERGREEN_TOTAL_PAGES:
        if not page.is_file():
            fail(f"evergreen total page is missing: {page}")
        # Collapse whitespace so a count that wraps across a line ("140\nbuilt-in")
        # is matched the same as the inline form - the phrases below use spaces.
        text = re.sub(r"\s+", " ", page.read_text(encoding="utf-8"))
        for phrase in WRONG_TOTAL_PHRASES:
            if phrase in text:
                fail(
                    f"{page.relative_to(ROOT)} states a wrong feature total: "
                    f"{phrase!r} (the catalog has {expected_total})"
                )
        if not any(
            f"{expected_total} {suffix}" in text
            for suffix in ("built-in", "built-ins", "features", "cataloged")
        ):
            fail(
                f"{page.relative_to(ROOT)} never states the correct total of "
                f"{expected_total} features"
            )

    print(
        f"Feature catalog: {len(features)} contiguous entries, "
        f"{len(packet_ids)} packets, 4 public pages aligned, "
        f"{len(EVERGREEN_TOTAL_PAGES)} evergreen totals at {expected_total}"
    )


if __name__ == "__main__":
    main()
