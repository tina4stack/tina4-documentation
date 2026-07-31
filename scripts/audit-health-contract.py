#!/usr/bin/env python3
"""Verify the health contract fixture describes reality.

plan/v3/fixtures/health_contract.json is the ONE answer key for feature 8: the
liveness/readiness split, the four-key body, the path alias rule, and the
registration rule, each naming the suite and the case names that prove it.

A fixture nobody checks is a wish. This asserts, for every invariant:

  * the named suite FILE exists in each named repo;
  * every named CASE appears in that file.

Case names are compared loosely - snake_case, camelCase and PHP's testPascal
form all normalise to the same key - because the suites carry the same names in
each language's own idiom.

Entries under "specified_not_built" are deliberately NOT checked for suites;
they are the record of what ADR-0014 specified and left for later. They are
listed in the output so the outstanding work stays visible instead of silently
becoming permanent.

Exit 1 on any mismatch, so this can gate CI.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPOS = ROOT.parent
FIXTURE = ROOT / "plan" / "v3" / "fixtures" / "health_contract.json"
REPO_DIRS = {
    "ruby": REPOS / "tina4-ruby",
    "python": REPOS / "tina4-python",
    "php": REPOS / "tina4-php",
    "nodejs": REPOS / "tina4-nodejs",
}


def normalise(name: str) -> str:
    """Reduce a case name to comparable letters: 'a HEAD on a 404' -> 'aheadona404'."""
    return re.sub(r"[^a-z0-9]", "", name.lower())


def main() -> int:
    fixture = json.loads(FIXTURE.read_text())
    problems: list[str] = []
    checked = 0

    for invariant in fixture["invariants"]:
        for framework, suite in invariant["suites"].items():
            repo = REPO_DIRS.get(framework)
            if repo is None:
                problems.append(f"{invariant['id']}: unknown framework {framework!r}")
                continue
            if not repo.is_dir():
                problems.append(f"{invariant['id']}: repo missing for {framework} ({repo})")
                continue

            path = repo / suite
            if not path.is_file():
                problems.append(f"{invariant['id']}/{framework}: suite not found: {suite}")
                continue

            haystack = normalise(path.read_text(encoding="utf-8"))
            for case in invariant["cases"]:
                checked += 1
                if normalise(case) not in haystack:
                    problems.append(
                        f"{invariant['id']}/{framework}: case missing from {suite}: {case!r}"
                    )

    body = fixture["body"]
    print(
        f"health contract: {len(fixture['invariants'])} invariants, "
        f"{checked} (case x framework) pairs checked; "
        f"body keys {body['keys']}"
    )

    outstanding = fixture.get("specified_not_built", [])
    if outstanding:
        print(f"\n{len(outstanding)} specified and NOT built (ADR-0014):")
        for item in outstanding:
            print(f"  - {item['id']}: {item['status']}")

    if problems:
        print(f"\n{len(problems)} PROBLEM(S):")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
