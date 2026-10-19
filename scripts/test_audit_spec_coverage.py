#!/usr/bin/env python3
# Copyright (c) 2026 Code Infinity
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Regression tests for audit-spec-coverage.py (ADR-0098).

Run: ``python3 -m pytest scripts/test_audit_spec_coverage.py -q`` (repo root).

Hermetic: a fixture JSON and a spec markdown are synthesized in tmp_path and the
module's roots are monkeypatched, so no real plan/v3 content is touched. They lock
the spec<->fixture coverage contract: every AC-N maps to a real case, and every
fixture case is claimed by an AC-N.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

_HERE = Path(__file__).resolve().parent


def _load():
    spec = importlib.util.spec_from_file_location(
        "audit_spec_coverage", _HERE / "audit-spec-coverage.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


sc = _load()


def _layout(tmp_path: Path, *, fixture_cases, spec_text=None, with_specs_dir=True):
    plan = tmp_path / "plan" / "v3"
    fixtures = plan / "fixtures"
    specs = plan / "specs"
    fixtures.mkdir(parents=True)
    if with_specs_dir:
        specs.mkdir(parents=True)
    if fixture_cases is not None:
        (fixtures / "demo_contract.json").write_text(json.dumps({
            "feature": 99,
            "invariants": [{"id": "grp", "cases": [{"id": c, "name": c} for c in fixture_cases]}],
        }), encoding="utf-8")
    if spec_text is not None:
        (specs / "099-demo.md").write_text(spec_text, encoding="utf-8")
    return plan, fixtures, specs


def _patch(monkeypatch, tmp_path, plan, fixtures, specs):
    monkeypatch.setattr(sc, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(sc, "PLAN", plan)
    monkeypatch.setattr(sc, "FIXTURES_DIR", fixtures)
    monkeypatch.setattr(sc, "SPECS_DIR", specs)


GOOD_SPEC = """# Spec 099: Demo

- Fixture: demo_contract.json

## Acceptance criteria
- **AC-1** — given x, when y, then z. Cases: C1
- **AC-2** — given a, when b, then c. Cases: C2
"""


def test_no_specs_dir_passes(tmp_path, monkeypatch):
    plan, fx, specs = _layout(tmp_path, fixture_cases=["C1"], with_specs_dir=False)
    _patch(monkeypatch, tmp_path, plan, fx, specs)
    assert sc.main() == 0


def test_greenfield_empty_specs_passes(tmp_path, monkeypatch):
    plan, fx, specs = _layout(tmp_path, fixture_cases=["C1"])
    _patch(monkeypatch, tmp_path, plan, fx, specs)
    assert sc.main() == 0


def test_full_coverage_both_ways_passes(tmp_path, monkeypatch):
    plan, fx, specs = _layout(tmp_path, fixture_cases=["C1", "C2"], spec_text=GOOD_SPEC)
    _patch(monkeypatch, tmp_path, plan, fx, specs)
    assert sc.main() == 0


def test_ac_names_missing_case_fails(tmp_path, monkeypatch):
    # AC-2 -> C2, but the fixture only has C1.
    plan, fx, specs = _layout(tmp_path, fixture_cases=["C1"], spec_text=GOOD_SPEC)
    _patch(monkeypatch, tmp_path, plan, fx, specs)
    assert sc.main() == 1


def test_uncovered_fixture_case_fails(tmp_path, monkeypatch):
    # Fixture has C1,C2,C3 but the spec only claims C1,C2 -> C3 is unclaimed.
    plan, fx, specs = _layout(tmp_path, fixture_cases=["C1", "C2", "C3"], spec_text=GOOD_SPEC)
    _patch(monkeypatch, tmp_path, plan, fx, specs)
    assert sc.main() == 1


def test_ac_with_no_cases_fails(tmp_path, monkeypatch):
    spec = "# Spec\n\n- Fixture: demo_contract.json\n\n- **AC-1** — given x, when y, then z.\n"
    plan, fx, specs = _layout(tmp_path, fixture_cases=["C1"], spec_text=spec)
    _patch(monkeypatch, tmp_path, plan, fx, specs)
    assert sc.main() == 1


def test_no_fixture_line_fails(tmp_path, monkeypatch):
    spec = "# Spec\n\n## Acceptance criteria\n- **AC-1** — given x. Cases: C1\n"
    plan, fx, specs = _layout(tmp_path, fixture_cases=["C1"], spec_text=spec)
    _patch(monkeypatch, tmp_path, plan, fx, specs)
    assert sc.main() == 1
