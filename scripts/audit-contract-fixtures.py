#!/usr/bin/env python3
"""Verify every contract fixture describes reality, and report what is owed.

ADR-0024 rule 6: a pluggable subsystem's contract is machine-checked by a SHARED
FIXTURE plus ONE CHECKER SCRIPT - not a runner per framework. This is that one
script, for every ``plan/v3/fixtures/*_contract.json``.

WHY ONE GENERIC CHECKER AND NOT FOUR MORE
    audit-dispatch-contract.py and audit-health-contract.py were written per
    subsystem. Adding four more of those to cover queue/session/cache/docstore
    would be ~400 lines to check a shape that is identical in all six files.
    ADR-0024's own "as little code as possible" clause says the cost of holding a
    subsystem to the contract should be one JSON file and one entry in an
    EXISTING checker. So this walks the whole fixtures directory instead.

WHAT IT ASSERTS, per invariant:

  * PROVEN  - the invariant names a suite file and case names. The suite must
              exist in every framework it names, and every case must appear in
              that file. A case that was named and has since VANISHED is a
              FAILURE: someone deleted or renamed a test that a written contract
              depends on, which is precisely how the buried SQLiteLimitDedupTest
              went unnoticed for months.

  * OWED    - the invariant declares a rule with no cases yet. Reported loudly
              and counted, but does NOT fail the build. A fixture written the
              day the contract is agreed would otherwise put CI red until every
              test exists, and a permanently-red gate is a gate somebody
              disables. The ledger is the point: this prints exactly what is
              unproven, so it cannot be quietly forgotten.

Case names are compared loosely - snake_case, camelCase and PHP's testPascal
form all normalise to the same key - because the four suites deliberately carry
the same names in each language's own idiom.

Exit 1 on a broken invariant. Exit 0 with a loud OWED report otherwise, so this
can gate CI from the day a contract is written.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPOS = ROOT.parent
FIXTURE_DIR = ROOT / "plan" / "v3" / "fixtures"
REPO_DIRS = {
    "ruby": REPOS / "tina4-ruby",
    "python": REPOS / "tina4-python",
    "php": REPOS / "tina4-php",
    "nodejs": REPOS / "tina4-nodejs",
}


def normalise(name: str) -> str:
    """snake_case, camelCase and testPascalCase collapse to one comparable key.

    The four suites carry the same case names in each language's own idiom on
    purpose, so a literal comparison would report parity failures that are
    really spelling differences.
    """
    name = re.sub(r"^test[_ ]?", "", name, flags=re.IGNORECASE)
    return re.sub(r"[^a-z0-9]", "", name.lower())


def check_fixture(path: pathlib.Path) -> tuple[list[str], int, int]:
    """Return (failures, proven_count, owed_count) for one fixture."""
    data = json.loads(path.read_text(encoding="utf-8"))
    failures: list[str] = []
    proven = owed = 0

    for inv in data.get("invariants", []):
        inv_id = inv.get("id", "<unnamed>")
        suites = inv.get("suites") or {}
        cases = inv.get("cases") or []

        if not suites or not cases:
            owed += 1
            continue

        proven += 1
        for framework, rel in suites.items():
            repo = REPO_DIRS.get(framework)
            if repo is None:
                failures.append(f"{path.name} :: {inv_id} :: unknown framework '{framework}'")
                continue

            suite = repo / rel
            if not suite.exists():
                failures.append(f"{path.name} :: {inv_id} :: {framework} suite missing: {rel}")
                continue

            body = normalise(suite.read_text(encoding="utf-8", errors="ignore"))
            for case in cases:
                if normalise(case) not in body:
                    failures.append(
                        f"{path.name} :: {inv_id} :: {framework} :: case not found in {rel}: {case!r}"
                    )

    return failures, proven, owed


def main() -> int:
    fixtures = sorted(FIXTURE_DIR.glob("*_contract.json"))
    if not fixtures:
        print(f"no contract fixtures found under {FIXTURE_DIR}", file=sys.stderr)
        return 1

    all_failures: list[str] = []
    total_proven = total_owed = 0
    print(f"contract fixtures: {len(fixtures)}\n")

    for path in fixtures:
        failures, proven, owed = check_fixture(path)
        all_failures.extend(failures)
        total_proven += proven
        total_owed += owed
        state = "FAIL" if failures else ("owed" if owed else "ok")
        print(f"  {state:4}  {path.name:26} proven {proven:>2}   owed {owed:>2}")

    if total_owed:
        print(f"\nOWED - declared and not yet proven ({total_owed} invariants):")
        for path in fixtures:
            data = json.loads(path.read_text(encoding="utf-8"))
            for inv in data.get("invariants", []):
                if not (inv.get("suites") and inv.get("cases")):
                    print(f"  {path.stem.replace('_contract',''):10} {inv.get('id')}")
        print(
            "\n  An owed invariant is a written rule with nothing proving it. It does not\n"
            "  fail this check - a fixture written the day a contract is agreed would\n"
            "  otherwise hold CI red until every test exists, and a permanently-red gate\n"
            "  gets disabled. It IS counted here so it cannot be quietly forgotten."
        )

    if all_failures:
        print(f"\nBROKEN ({len(all_failures)}):")
        for f in all_failures:
            print(f"  - {f}")
        print("\n  A named case that has vanished means a test a written contract depends on\n"
              "  was deleted or renamed. Restore it, or amend the fixture deliberately.")
        return 1

    print(f"\n✓ {total_proven} invariants proven, {total_owed} owed, 0 broken")
    return 0


if __name__ == "__main__":
    sys.exit(main())
