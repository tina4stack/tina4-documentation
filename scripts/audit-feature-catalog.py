#!/usr/bin/env python3
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
    "same 97 features",
    "four identical frameworks",
    "Every feature below is present in all four",
    "Every feature is backed by real tests in all four",
    "single package per language, with zero runtime dependencies",
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

    print(
        f"Feature catalog: {len(features)} contiguous entries, "
        f"{len(packet_ids)} packets, 4 public pages aligned"
    )


if __name__ == "__main__":
    main()
