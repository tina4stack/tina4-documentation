#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Gate: a feature SPEC and its contract FIXTURE cover each other 1:1 (ADR-0098).

Spec-Driven Development (SDD) makes the per-feature spec the human-readable source
of truth, and the contract fixture its executable form. This gate enforces the link
the two promise: every acceptance criterion (`AC-N`) in a spec maps to a real case
in the spec's fixture, and every case in that fixture is claimed by some `AC-N`. A
spec that lists an `AC-N` with no case, points at a case the fixture does not have,
or leaves a fixture case unclaimed, fails the build - so the spec and the executable
contract can never drift (the same enforcement shape as audit-truth / audit-env-coverage).

Adoption is per feature: a feature with NO spec under `plan/v3/specs/` is simply not
gated yet (existing fixtures keep working). When no spec exists at all, the gate
passes with a note - greenfield, nothing to check.

    python3 scripts/audit-spec-coverage.py           # report + exit code
    python3 scripts/audit-spec-coverage.py --strict   # same; explicit
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PLAN = REPO_ROOT / "plan" / "v3"
SPECS_DIR = PLAN / "specs"
FIXTURES_DIR = PLAN / "fixtures"

# Files under specs/ that are scaffolding, not feature specs.
NON_SPEC = {"TEMPLATE.md", "README.md"}

# A spec declares its fixture once: `Fixture: <name>_contract.json` (or a path).
# The TEMPLATE writes it as a bullet (`- Fixture: ...`), so an optional list
# marker is allowed; a bare `Fixture:` line works too.
FIXTURE_RE = re.compile(r"(?mi)^\s*(?:[-*+]\s+)?Fixture:\s*(\S+)\s*$")
# An acceptance-criterion entry: `- **AC-3** ...`. Captures the number.
AC_RE = re.compile(r"\*\*AC-(\d+)\*\*")
# The case list on the SAME line: `Cases: DBA-S01, DBA-S02`.
CASES_RE = re.compile(r"[Cc]ases?:\s*([A-Za-z0-9][\w .,-]*)")


def resolve_fixture(value: str) -> Path | None:
    for cand in (FIXTURES_DIR / value, PLAN / value, REPO_ROOT / value, Path(value)):
        if cand.is_file():
            return cand
    return None


def fixture_case_ids(path: Path) -> set[str]:
    """Every case id the fixture declares (`invariants[].cases[].id`)."""
    data = json.loads(path.read_text(encoding="utf-8"))
    ids: set[str] = set()
    for inv in data.get("invariants", []):
        for case in inv.get("cases") or []:
            if isinstance(case, dict) and case.get("id"):
                ids.add(case["id"])
    return ids


def parse_spec(path: Path) -> tuple[str | None, dict[str, set[str]]]:
    """Return (declared fixture value, {AC-id: {case ids}})."""
    text = path.read_text(encoding="utf-8")
    fm = FIXTURE_RE.search(text)
    fixture = fm.group(1) if fm else None
    acs: dict[str, set[str]] = {}
    for line in text.splitlines():
        m = AC_RE.search(line)
        if not m:
            continue
        ac = f"AC-{m.group(1)}"
        cm = CASES_RE.search(line)
        cases = set()
        if cm:
            cases = {c.strip() for c in cm.group(1).split(",") if c.strip()}
        acs[ac] = acs.get(ac, set()) | cases
    return fixture, acs


def check_spec(path: Path) -> list[str]:
    fails: list[str] = []
    rel = path.relative_to(REPO_ROOT)
    fixture_value, acs = parse_spec(path)

    if not acs:
        return [f"{rel}: no acceptance criteria (expected `**AC-N**` entries)"]
    if not fixture_value:
        return [f"{rel}: no `Fixture:` line - a spec must name its contract fixture"]

    fixture_path = resolve_fixture(fixture_value)
    if fixture_path is None:
        return [f"{rel}: fixture not found: {fixture_value!r}"]

    try:
        case_ids = fixture_case_ids(fixture_path)
    except (OSError, json.JSONDecodeError) as exc:
        return [f"{rel}: cannot read fixture {fixture_value}: {exc}"]

    referenced: set[str] = set()
    for ac, cases in sorted(acs.items()):
        if not cases:
            fails.append(f"{rel}: {ac} lists no cases (add `Cases: <id>, ...`)")
            continue
        for cid in sorted(cases):
            if cid not in case_ids:
                fails.append(f"{rel}: {ac} -> case {cid!r} is not in {fixture_path.name}")
            else:
                referenced.add(cid)

    # Bidirectional: only when the fixture carries case ids (version-2 fixtures).
    if case_ids:
        for cid in sorted(case_ids - referenced):
            fails.append(f"{rel}: fixture case {cid!r} is claimed by no AC-N")
    return fails


def main() -> int:
    if not SPECS_DIR.is_dir():
        print("audit-spec-coverage: no plan/v3/specs/ yet - skipping (nothing to gate).")
        return 0
    specs = sorted(p for p in SPECS_DIR.glob("*.md") if p.name not in NON_SPEC)
    if not specs:
        print("audit-spec-coverage: no feature specs yet - skipping (greenfield).")
        return 0

    all_fails: list[str] = []
    for spec in specs:
        all_fails.extend(check_spec(spec))

    if all_fails:
        print(f"audit-spec-coverage: {len(all_fails)} spec/fixture coverage failure(s) "
              f"across {len(specs)} spec(s):")
        for f in all_fails:
            print(f"   - {f}")
        print("\nEvery AC-N must map to a real fixture case, and every fixture case must "
              "be claimed by an AC-N (ADR-0098).")
        return 1

    print(f"audit-spec-coverage: OK - {len(specs)} spec(s), every AC-N <-> fixture case "
          "covered both ways.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
