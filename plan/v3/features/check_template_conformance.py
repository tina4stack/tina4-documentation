#!/usr/bin/env python3
"""Check that every numbered feature packet follows FEATURE-TEMPLATE.md."""

from __future__ import annotations

import re
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "FEATURE-TEMPLATE.md"
NUMBERED_PACKET = re.compile(r"^[0-9]+(?:-[0-9]+)?-.*\.md$")
CATALOG = ROOT.parent / "FEATURE-CATALOG.json"
IDENTITY_FIELDS = (
    "Matrix identity",
    "Audit state",
    "Dependencies",
    "Dependants",
    "Existing ADRs",
    "Shared fixtures",
)
CHECKLIST_ITEMS = (
    "Boundary and public surface complete.",
    "Lifecycle and every producer/consumer edge complete.",
    "Configuration, failure, side-effect and security rules complete.",
    "Wire/storage and provider contracts complete.",
    "Existing-language contradictions recorded.",
    "Owner ambiguities decided and recorded.",
    "Proposed shared cases and mutation witnesses complete.",
    "Integration map and breaking migrations complete.",
    "Implementation backlog dependency-ordered.",
    "Porting capsule is clean-room sufficient.",
)
EVIDENCE_ROWS = (
    "Public surface",
    "Startup/CLI integration",
    "Stored/wire format",
    "Existing focused tests",
    "Existing lab baseline",
)
AUDIT_STATES = {
    "queued",
    "auditing",
    "decision-ready",
    "implementation-ready",
    "stable",
}


def h2_headings(path: Path) -> list[str]:
    return [
        line[3:].strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.startswith("## ")
    ]


def h2_sections(path: Path) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            current = line[3:].strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    return {heading: "\n".join(lines).strip() for heading, lines in sections.items()}


def main() -> int:
    required = h2_headings(TEMPLATE)
    failures: list[str] = []

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["features"]
    expected = {
        f'{feature["id"]:03d}-{feature["slug"]}.md': feature
        for feature in catalog
    }
    if [feature["id"] for feature in catalog] != list(range(1, len(catalog) + 1)):
        failures.append("FEATURE-CATALOG.json: identifiers are not contiguous from 1")

    actual_files = {
        path.name for path in ROOT.glob("[0-9]*.md") if NUMBERED_PACKET.match(path.name)
    }
    missing_files = sorted(set(expected) - actual_files)
    extra_files = sorted(actual_files - set(expected))
    if missing_files:
        failures.append(f"catalog packets missing={missing_files}")
    if extra_files:
        failures.append(f"numbered packets outside catalog={extra_files}")

    for path in sorted(ROOT.glob("*.md")):
        if not NUMBERED_PACKET.match(path.name):
            continue

        actual = h2_headings(path)
        if actual != required:
            missing = [heading for heading in required if heading not in actual]
            extra = [heading for heading in actual if heading not in required]
            failures.append(
                f"{path.name}: heading order/schema mismatch; "
                f"missing={missing or 'none'}; extra={extra or 'none'}"
            )
            continue

        sections = h2_sections(path)
        feature = expected.get(path.name)
        if feature:
            title = path.read_text(encoding="utf-8").splitlines()[0]
            wanted_title = f'# Feature {feature["id"]:03d}: {feature["name"]}'
            if title != wanted_title:
                failures.append(
                    f"{path.name}: title mismatch; expected={wanted_title!r}; actual={title!r}"
                )
        empty = [heading for heading in required if not sections.get(heading, "").strip()]
        if empty:
            failures.append(f"{path.name}: empty canonical sections={empty}")

        identity = sections["Identity and status"]
        missing_fields = [
            field for field in IDENTITY_FIELDS if f"- {field}:" not in identity
        ]
        if missing_fields:
            failures.append(
                f"{path.name}: missing identity fields={missing_fields}"
            )
        if feature:
            wanted_identity = f'- Matrix identity: {feature["id"]} — {feature["name"]}'
            if wanted_identity not in identity:
                failures.append(
                    f"{path.name}: catalog identity mismatch; expected={wanted_identity!r}"
                )
        state_match = re.search(r"^- Audit state:\s*(.+)$", identity, flags=re.M)
        if not state_match or state_match.group(1).strip() not in AUDIT_STATES:
            actual_state = state_match.group(1).strip() if state_match else "missing"
            failures.append(
                f"{path.name}: invalid audit state={actual_state!r}; "
                f"allowed={sorted(AUDIT_STATES)}"
            )

        evidence = sections["Existing implementation evidence"]
        if "| Evidence | Python | PHP | Ruby | Node |" not in evidence:
            failures.append(f"{path.name}: missing canonical evidence table")
        missing_evidence_rows = [
            row for row in EVIDENCE_ROWS if f"| {row} |" not in evidence
        ]
        if missing_evidence_rows:
            failures.append(
                f"{path.name}: missing canonical evidence rows={missing_evidence_rows}"
            )

        closure = sections["Audit closure checklist"]
        missing_checks = [item for item in CHECKLIST_ITEMS if item not in closure]
        if missing_checks:
            failures.append(
                f"{path.name}: missing canonical closure checks={missing_checks}"
            )

    if failures:
        print("Feature-template conformance: FAIL")
        print("\n".join(failures))
        return 1

    print("Feature-template conformance: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
