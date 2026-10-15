#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Every USER-FACING ``TINA4_*`` env var the framework reads must be documented.

``audit-truth.py`` gates the other direction - a ``TINA4_*`` NAMED in the docs
must exist in code - but nothing caught a var that shipped in code and was never
documented. Those misses accumulate silently across releases (COOP, the Kafka
SASL settings, the memcached-session settings and the API timeouts all drifted
in undocumented). This gate closes the gap: it reads the real env-var names out
of the framework source and fails if a user-facing one is absent from the docs.

Source resolution mirrors audit-truth: the framework repos are siblings of this
one (``../tina4-python`` ...). Env vars are a cross-framework contract, so the
union of whatever siblings are present is the canonical set. When NO sibling is
checked out (a pure docs-only CI job) the gate warns and passes - it is a
local / lab / release-prep gate, exactly like audit-truth's framework-source
checks. Internal / dev-only vars are listed in INTERNAL below and never required.

    python3 scripts/audit-env-coverage.py          # report + exit code
    python3 scripts/audit-env-coverage.py --strict  # same; explicit
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKSPACE_ROOT = REPO_ROOT.parent

# Sibling framework source roots (same set audit-truth uses) + file suffixes.
FRAMEWORK_SOURCES = {
    "python": ("tina4-python/tina4_python", (".py",)),
    "php":    ("tina4-php/Tina4", (".php",)),
    "ruby":   ("tina4-ruby/lib/tina4", (".rb",)),
    "nodejs": ("tina4-nodejs/packages", (".ts",)),
}

DOCS_ROOT = REPO_ROOT / "docs"
SKIP_DOC_FRAGMENTS = ("/v2/", "/.vitepress/", "/public/llms-full.txt")

# A TINA4_* name read as an ENVIRONMENT VARIABLE - i.e. quoted and sitting right
# after an env accessor (os.environ.get / getenv / DotEnv::getEnv / Tina4.get_env
# / ENV[ / process.env[), or node's unquoted process.env.TINA4_X. Matching ONLY
# in that context stops a plain string literal that merely starts with TINA4_
# (a DB table name like 'TINA4_SESSION', a label like "TINA4_TOTAL") from being
# mistaken for an env var. An f-string prefix (f"TINA4_SESSION_{x}") has no
# closing quote after the name and never matches either.
CODE_RE = re.compile(
    r"(?:environ|getenv|getEnv|get_env|has_env\??|env_bool|env_int|env_float|"
    r"env_str|requireEnv|require_env|process\.env|ENV)\b[^\n;]{0,40}?"
    r"['\"](TINA4_[A-Z0-9_]+)['\"]"
)
# node also reads them unquoted as a property: process.env.TINA4_FOO
CODE_RE_DOT = re.compile(r"process\.env\.(TINA4_[A-Z0-9_]+)")
DOC_RE = re.compile(r"TINA4_[A-Z0-9_]+")

# Test-harness vars (point the suite at live services) are never user docs.
TEST_PREFIX = "TINA4_TEST_"

# Internal / developer / test-harness vars that are deliberately NOT user docs.
# Keep this list TIGHT and justified - it is the only way to silence the gate.
INTERNAL = {
    "TINA4_CLI_DELEGATED",     # set by the Rust client when it forwards to the lang CLI
    "TINA4_SETUP_ELEVATED",    # internal UAC re-launch flag (Windows setup)
    "TINA4_LIBCRYPTO",         # test/CI override for the libcrypto path
    "TINA4_NOTEBOOK",          # dev-admin notebook internal flag
    "TINA4_FEEDBACK_DEV_USER", # dev-only feedback-widget allowlist
    "TINA4_SEMGREP_CONFIG",    # internal codeql/semgrep wiring
    "TINA4_OVERRIDE_CLIENT",   # documented elsewhere; embedding escape hatch
    "TINA4_REQUIRE_SERVICES",  # the test suite's service gate
    "TINA4_REQUIRE_OIDC",      # the test suite's OIDC gate
}


def _resolve_sources() -> list[tuple[str, Path, tuple[str, ...]]]:
    out = []
    for lang, (rel, suffixes) in FRAMEWORK_SOURCES.items():
        p = WORKSPACE_ROOT / rel
        if p.is_dir():
            out.append((lang, p, suffixes))
    return out


# Directory names and filename patterns that mark NON-production code. Matched
# on exact path PARTS (not a substring) so a legit dir like ``testing_utils`` or
# a tmp path such as ``test_foo0/`` is not swept up - only a real ``tests`` /
# ``spec`` tree or an obvious test file is skipped.
SKIP_PARTS = frozenset(
    {"test", "tests", "spec", "specs", "__tests__", "node_modules", ".venv", "dist", "build"}
)
SKIP_NAME_SUFFIXES = (
    ".test.ts", ".spec.ts", ".test.js", ".spec.js", "_spec.rb", "_test.rb", "Test.php",
)


def _code_env_vars(root: Path, suffixes: tuple[str, ...]) -> set[str]:
    found: set[str] = set()
    for suffix in suffixes:
        for f in root.rglob(f"*{suffix}"):
            if set(f.parts) & SKIP_PARTS:
                continue
            if f.name.startswith("test_") or f.name.endswith(SKIP_NAME_SUFFIXES):
                continue
            try:
                text = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            found |= set(CODE_RE.findall(text))
            found |= set(CODE_RE_DOT.findall(text))
    return found


def _documented() -> set[str]:
    found: set[str] = set()
    for f in DOCS_ROOT.rglob("*.md"):
        if any(frag in f.as_posix() for frag in SKIP_DOC_FRAGMENTS):
            continue
        try:
            found |= set(DOC_RE.findall(f.read_text(encoding="utf-8", errors="ignore")))
        except OSError:
            continue
    return found


def main() -> int:
    sources = _resolve_sources()
    if not sources:
        print("audit-env-coverage: no sibling framework repo checked out - "
              "skipping (local / lab / release-prep gate).")
        return 0

    code: set[str] = set()
    for _lang, root, suffixes in sources:
        code |= _code_env_vars(root, suffixes)

    documented = _documented()
    missing = sorted(
        v for v in code
        if v not in documented and v not in INTERNAL and not v.startswith(TEST_PREFIX)
    )

    checked = ", ".join(lang for lang, _r, _s in sources)
    if missing:
        print(f"audit-env-coverage: {len(missing)} user-facing TINA4_* env var(s) "
              f"are read in code ({checked}) but NOT documented:")
        for v in missing:
            print(f"   - {v}")
        print("\nDocument each (a docs page that NAMES the var), or - only if it is "
              "genuinely internal - add it to INTERNAL in this script with a reason.")
        return 1

    print(f"audit-env-coverage: OK - every user-facing TINA4_* env var in "
          f"{len(code)} read across [{checked}] is documented "
          f"({len(INTERNAL)} internal vars exempt).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
