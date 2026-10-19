#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Regression tests for audit-env-coverage.py - the code->doc env gate.

Run: ``python3 -m pytest scripts/test_audit_env_coverage.py -q`` (repo root).

These lock in the behaviour that was hard to get right:

- a user-facing ``TINA4_*`` the framework reads but the docs never name
  FAILS the build (that is the whole point of the gate);
- a documented one passes;
- the INTERNAL allow-list and the ``TINA4_TEST_`` prefix are exempt;
- a quoted ``TINA4_*`` that is NOT an env access - a table name, a label -
  does NOT count as a read, so it never forces a phantom doc entry (the
  regex over-matched this way in the first draft);
- no sibling framework checkout => skip + pass (docs-only CI job).

The tests are hermetic: they synthesize a framework source tree and a
docs tree in tmp_path and monkeypatch the module's roots, so no real
repo checkout is required.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

_HERE = Path(__file__).resolve().parent


def _load():
    spec = importlib.util.spec_from_file_location(
        "audit_env_coverage", _HERE / "audit-env-coverage.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ec = _load()


def _workspace(tmp_path: Path, code: str, docs: str) -> None:
    """Lay out a fake workspace: <tmp>/fw/*.py (code) + <tmp>/repo/docs/*.md."""
    fw = tmp_path / "fw"
    fw.mkdir()
    (fw / "server.py").write_text(code, encoding="utf-8")
    repo = tmp_path / "repo"
    docs_dir = repo / "docs"
    docs_dir.mkdir(parents=True)
    (docs_dir / "env.md").write_text(docs, encoding="utf-8")


def _patch(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(ec, "WORKSPACE_ROOT", tmp_path)
    monkeypatch.setattr(ec, "FRAMEWORK_SOURCES", {"test": ("fw", (".py",))})
    monkeypatch.setattr(ec, "DOCS_ROOT", tmp_path / "repo" / "docs")


def test_undocumented_user_var_fails(tmp_path, monkeypatch):
    _workspace(
        tmp_path,
        code='x = os.environ.get("TINA4_SECRET_KNOB", "")\n',
        docs="# Env\n\nNothing here names it.\n",
    )
    _patch(monkeypatch, tmp_path)
    assert ec.main() == 1


def test_documented_user_var_passes(tmp_path, monkeypatch):
    _workspace(
        tmp_path,
        code='x = os.environ.get("TINA4_SECRET_KNOB", "")\n',
        docs="# Env\n\n| `TINA4_SECRET_KNOB` | _(empty)_ | A knob. |\n",
    )
    _patch(monkeypatch, tmp_path)
    assert ec.main() == 0


def test_internal_var_is_exempt(tmp_path, monkeypatch):
    # An INTERNAL var read in code but absent from docs must not fail.
    internal = next(iter(ec.INTERNAL))
    _workspace(
        tmp_path,
        code=f'x = os.environ.get("{internal}")\n',
        docs="# Env\n\nNo mention of the internal var.\n",
    )
    _patch(monkeypatch, tmp_path)
    assert ec.main() == 0


def test_test_prefix_is_exempt(tmp_path, monkeypatch):
    _workspace(
        tmp_path,
        code='x = os.environ.get("TINA4_TEST_REDIS_URL")\n',
        docs="# Env\n\nNo mention.\n",
    )
    _patch(monkeypatch, tmp_path)
    assert ec.main() == 0


def test_non_env_string_is_not_a_read(tmp_path, monkeypatch):
    # A quoted TINA4_* that is a table name / label, NOT an env accessor,
    # must not be treated as a read - so it never forces a doc entry.
    _workspace(
        tmp_path,
        code='table = "TINA4_SESSION_STORE"\nlabel = "TINA4_TOTAL"\n',
        docs="# Env\n\nNeither name appears.\n",
    )
    _patch(monkeypatch, tmp_path)
    assert ec.main() == 0


def test_node_process_env_dot_access_is_a_read(tmp_path, monkeypatch):
    # node reads vars unquoted as a property: process.env.TINA4_FOO
    fw = tmp_path / "fw"
    fw.mkdir()
    (fw / "response.ts").write_text(
        "const n = parseFloat(process.env.TINA4_SSE_HEARTBEAT ?? '15');\n",
        encoding="utf-8",
    )
    repo = tmp_path / "repo"
    (repo / "docs").mkdir(parents=True)
    (repo / "docs" / "env.md").write_text("# Env\n\nUndocumented.\n", encoding="utf-8")
    monkeypatch.setattr(ec, "WORKSPACE_ROOT", tmp_path)
    monkeypatch.setattr(ec, "FRAMEWORK_SOURCES", {"node": ("fw", (".ts",))})
    monkeypatch.setattr(ec, "DOCS_ROOT", repo / "docs")
    assert ec.main() == 1


def test_no_siblings_skips_and_passes(tmp_path, monkeypatch):
    # A docs-only CI job with no framework checkout must warn + pass, not fail.
    monkeypatch.setattr(ec, "WORKSPACE_ROOT", tmp_path)
    monkeypatch.setattr(ec, "FRAMEWORK_SOURCES", {"absent": ("does-not-exist", (".py",))})
    monkeypatch.setattr(ec, "DOCS_ROOT", tmp_path / "repo" / "docs")
    assert ec.main() == 0
