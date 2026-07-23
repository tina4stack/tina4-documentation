#!/usr/bin/env python3
"""
Cross-framework parity test for Tina4 Live Docs.

Spawns each framework's `Docs` module in its own language process,
runs the same query, asserts the results are equivalent modulo
language-specific FQN naming.

Usage:
    python3 plan/v3/tools/docs-parity.py

Exit 0 = parity passes. Non-zero = drift detected.

This is the cross-language sanity check that the in-process unit
tests can't cover — they only verify each language against its own
fixture in its own runtime.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(os.environ.get("REPO_ROOT", "/Users/andrevanzuydam/IdeaProjects"))
PHP_REPO = REPO / "tina4-php"
PY_REPO = REPO / "tina4-python"

# Queries we expect both frameworks to handle equivalently. Each
# query maps to a set of "shape signatures" that any framework's top
# results should produce. A shape signature is `<ClassBaseName>.<method>`
# — namespace-stripped and case-normalised — so we can compare across
# `Tina4\Response::render` vs `tina4_python.core.response.Response.render`.
QUERIES = [
    # query, expected_shape_in_top_5, min_total_hits
    ("render template",   {"response.render"},                 3),
    ("database query",    {"database.fetch", "database.query"}, 3),
    ("Auth getToken",     {"auth.gettoken", "auth.get_token"},  3),
    ("ORM save",          {"orm.save"},                          3),
]


def shape(fqn: str) -> str:
    """Reduce an FQN to `<class>.<method>`, lowercase, namespace-stripped.

    Tina4\\Response::render             →  response.render
    tina4_python.core.response.Response.render  →  response.render
    Tina4\\Database\\Database::fetch    →  database.fetch
    """
    # Strip any leading namespace, keep only the trailing two segments
    # split by `.`, `::`, or `\`.
    parts = re.split(r"[.\\]|::", fqn)
    parts = [p for p in parts if p]
    if len(parts) < 2:
        return fqn.lower()
    return f"{parts[-2]}.{parts[-1]}".lower()


def run_php(query: str, k: int) -> list[dict]:
    """Spawn PHP, build a Docs instance against the framework's own
    repo (no user code), run the query, capture JSON."""
    script = f'''
<?php
require "{PHP_REPO}/vendor/autoload.php";
$docs = new \\Tina4\\Docs("{PHP_REPO}");
$hits = $docs->search({json.dumps(query)}, {k});
echo json_encode($hits);
'''
    r = subprocess.run(
        ["php", "-d", "display_errors=stderr", "-r", script.strip().lstrip("<?php").strip()],
        capture_output=True, text=True, timeout=30,
    )
    if r.returncode != 0:
        print(f"  [PHP ERR] {r.stderr.strip()[:300]}", file=sys.stderr)
        return []
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError as e:
        print(f"  [PHP JSON ERR] {e}: {r.stdout[:200]}", file=sys.stderr)
        return []


def run_python(query: str, k: int) -> list[dict]:
    """Spawn Python, build a Docs instance against its own repo, run
    the query, capture JSON. Empty user dir so we only see framework."""
    script = f'''
import json, sys
sys.path.insert(0, "{PY_REPO}")
from tina4_python.docs import Docs
# Use a freshly-empty user root so only framework hits appear.
import tempfile
with tempfile.TemporaryDirectory() as tmp:
    docs = Docs(project_root=tmp)
    hits = docs.search({json.dumps(query)}, k={k})
    print(json.dumps(hits))
'''
    r = subprocess.run(
        [str(PY_REPO / ".venv" / "bin" / "python"), "-c", script],
        capture_output=True, text=True, timeout=30,
    )
    if r.returncode != 0:
        print(f"  [PY ERR] {r.stderr.strip()[:300]}", file=sys.stderr)
        return []
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError as e:
        print(f"  [PY JSON ERR] {e}: {r.stdout[:200]}", file=sys.stderr)
        return []


def main() -> int:
    print("\nTina4 Live Docs — cross-framework parity\n" + "=" * 50)
    failures = []

    for query, expected, min_hits in QUERIES:
        print(f"\nQuery: {query!r}")

        php_hits = run_php(query, 5)
        py_hits  = run_python(query, 5)

        php_shapes = {shape(h["fqn"]) for h in php_hits if h.get("fqn")}
        py_shapes  = {shape(h["fqn"]) for h in py_hits  if h.get("fqn")}

        print(f"  PHP    top-{len(php_hits)}: {sorted(php_shapes)}")
        print(f"  Python top-{len(py_hits)}: {sorted(py_shapes)}")

        # Assertion 1: both frameworks return hits.
        if len(php_hits) < min_hits or len(py_hits) < min_hits:
            failures.append(
                f"  ✗ {query!r}: PHP={len(php_hits)} hits, Python={len(py_hits)} hits "
                f"(expected ≥ {min_hits})"
            )
            continue

        # Assertion 2: each framework includes at least one shape from
        # the expected set in its top-5. We don't require both to land
        # the SAME shape because Python's class names are snake_case
        # within the FQN structure but the method names match.
        php_match = expected & php_shapes
        py_match  = expected & py_shapes
        if not php_match:
            failures.append(
                f"  ✗ {query!r}: PHP missing expected shape from {expected}; got {php_shapes}"
            )
        if not py_match:
            failures.append(
                f"  ✗ {query!r}: Python missing expected shape from {expected}; got {py_shapes}"
            )

        if php_match and py_match and len(php_hits) >= min_hits and len(py_hits) >= min_hits:
            print(f"  ✓ both frameworks hit {expected & (php_shapes | py_shapes)}")

    print("\n" + "=" * 50)
    if failures:
        print(f"\n{len(failures)} parity failure(s):\n")
        for f in failures:
            print(f)
        return 1
    print("\nAll parity checks passed. Cross-framework Docs are aligned.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
