#!/usr/bin/env python3
"""Regression tests for audit-truth.py — the doc<->code truth gate.

Run: ``python3 -m pytest scripts/test_audit_truth.py -q`` (from the repo root).

These lock in the fix for the class of bug where the CLI check trusted
whatever ``tina4`` binary happened to be on PATH. An old global install
(e.g. 3.8.25) predates recently added commands, so real docs for
``tina4 setup`` / ``tina4 metrics`` were reported as fake. The gate must
derive its grammar from a binary built from the CLI SOURCE, and must
still flag genuinely-fake commands (no blanket whitelist).

The tests are hermetic: they synthesize fake ``tina4`` binaries and a
fake CLI source repo, so no cargo build or real install is required.
"""
from __future__ import annotations

import importlib.util
import os
import stat
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent


def _load():
    spec = importlib.util.spec_from_file_location("audit_truth", _HERE / "audit-truth.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


at = _load()


# A stand-in for the tina4 CLI. Responds to `--version`, `--help`, and
# `<cmd> --help` so both real_cli_grammar() and _binary_version() work.
# `commands` controls which subcommands the fake advertises, so a test can
# model a fresh CLI (has setup/metrics) or a stale one (does not).
def _fake_tina4(path: Path, version: str, commands: list[str]) -> Path:
    cmd_block = "\n".join(f"  {c}\n          {c} does a thing" for c in commands)
    body = f'''#!/usr/bin/env python3
import sys
args = sys.argv[1:]
if args == ["--version"]:
    print("tina4 {version}"); sys.exit(0)
if args == ["--help"]:
    print("""Usage: tina4 <COMMAND>

Commands:
{cmd_block}
  help
          Print this message

Options:
  -h, --help  Print help
"""); sys.exit(0)
if len(args) == 2 and args[1] == "--help":
    cmd = args[0]
    if cmd == "setup":
        print("""Usage: tina4 setup [OPTIONS]

Options:
      --dry-run       Preview only
      --skip-install  Scaffold, no installs
  -h, --help          Print help
"""); sys.exit(0)
    if cmd == "init":
        print("""Usage: tina4 init [LANG] [PATH]

Arguments:
  [LANG]  Language
  [PATH]  Project dir
"""); sys.exit(0)
    print(f"Usage: tina4 {{cmd}} [ARGS]...\\n\\nOptions:\\n  -h, --help  Print help\\n"); sys.exit(0)
sys.exit(2)
'''
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IRWXU)
    return path


def _fake_cli_repo(root: Path, version: str, built_binary: Path | None) -> Path:
    """Create a sibling-style ../tina4 with a Cargo.toml and, optionally, a
    prebuilt target/release/tina4."""
    root.mkdir(parents=True, exist_ok=True)
    (root / "Cargo.toml").write_text(
        f'[package]\nname = "tina4"\nversion = "{version}"\nedition = "2021"\n\n'
        f'[dependencies]\nclap = {{ version = "4" }}\n',
        encoding="utf-8",
    )
    if built_binary is not None:
        rel = root / "target" / "release"
        rel.mkdir(parents=True, exist_ok=True)
        _fake_tina4(rel / "tina4", version, ["serve", "init", "setup", "metrics", "generate"])
    return root


# ── Helper unit tests ─────────────────────────────────────────────────

def test_semver_parsing():
    assert at._semver("tina4 3.8.53") == (3, 8, 53)
    assert at._semver("v3.10.0-rc.2") == (3, 10, 0)
    assert at._semver("no version here") is None


def test_source_version_reads_package_table_not_deps(tmp_path, monkeypatch):
    repo = _fake_cli_repo(tmp_path / "tina4", "3.8.53", built_binary=None)
    monkeypatch.setattr(at, "CLI_REPO", repo)
    # Must read the [package] version (3.8.53), NOT the clap dep "4".
    assert at._cli_source_version() == (3, 8, 53)


def test_real_env_vars_uses_stable_ripgrep_flags(tmp_path, monkeypatch):
    """Ripgrep 15 treats ``-h`` as help, so the audit must use long flags."""
    rg = at.shutil.which("rg")
    if rg is None:
        pytest.skip("ripgrep is not installed")

    framework = tmp_path / "framework"
    framework.mkdir()
    (framework / "config.py").write_text(
        'debug = "TINA4_DEBUG"\nai_key = "TINA4_AI_KEY"\n',
        encoding="utf-8",
    )
    monkeypatch.setattr(at, "WORKSPACE_ROOT", tmp_path)
    monkeypatch.setattr(at, "FRAMEWORK_SOURCES", {"test": ("framework",)})
    monkeypatch.setattr(
        at.shutil,
        "which",
        lambda name: rg if name == "rg" else None,
    )

    found, notes = at.real_env_vars()
    assert notes == []
    assert found == {"TINA4_DEBUG", "TINA4_AI_KEY"}


def test_doc_env_mentions_ignores_bracketed_framework_constants(tmp_path, monkeypatch):
    page = tmp_path / "environment.md"
    page.write_text(
        "TINA4_LOG_LEVEL=[TINA4_LOG_ALL]\nTINA4_AI_KEY=secret\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(at, "find_doc_files", lambda: [page])

    mentions = at.doc_env_mentions()
    assert set(mentions) == {"TINA4_LOG_LEVEL", "TINA4_AI_KEY"}


def test_onboarding_flags_wrong_packages_legacy_commands_links_and_js_port(
        tmp_path, monkeypatch):
    page = tmp_path / "docs" / "js" / "13-backend-integration.md"
    page.parent.mkdir(parents=True)
    page.write_text(
        "composer require tina4/tina4-php\n"
        "tina4ruby generate model Product\n"
        "https://github.com/tina4stack/tina4-documentation/blob/main/js/index.md\n"
        "tina4 create demo --php\n"
        "port: 3000\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(at, "find_doc_files", lambda: [page])
    monkeypatch.setattr(at, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(at, "_tina4js_scaffold_port", lambda: 5173)

    drift, lines = at.check_onboarding()
    assert drift == 5, "\n".join(lines)


def test_onboarding_accepts_unified_current_workflow(tmp_path, monkeypatch):
    page = tmp_path / "docs" / "js" / "01-getting-started.md"
    page.parent.mkdir(parents=True)
    page.write_text(
        "tina4 init js my-app\ntina4 serve\nhttp://localhost:5173\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(at, "find_doc_files", lambda: [page])
    monkeypatch.setattr(at, "REPO_ROOT", tmp_path)
    monkeypatch.setattr(at, "_tina4js_scaffold_port", lambda: 5173)

    drift, lines = at.check_onboarding()
    assert drift == 0, "\n".join(lines)


# ── The core regression: resolver must not trust a stale PATH binary ──

def test_resolver_prefers_sibling_build_over_stale_path(tmp_path, monkeypatch):
    # A fresh source repo (3.9.0) WITH a build, and a stale binary on PATH (3.8.25).
    repo = _fake_cli_repo(tmp_path / "tina4", "3.9.0", built_binary=True)
    stale = _fake_tina4(tmp_path / "path_tina4", "3.8.25", ["serve", "init"])  # no setup/metrics
    monkeypatch.setattr(at, "CLI_REPO", repo)
    monkeypatch.setattr(at.shutil, "which",
                        lambda name: str(stale) if name == "tina4" else None)
    monkeypatch.delenv("TINA4_CLI_BIN", raising=False)

    resolved, _notes = at._resolve_cli_binary()
    assert resolved == str(repo / "target" / "release" / "tina4"), \
        "resolver must prefer the source build over a stale PATH binary"

    top, _second = at.real_cli_grammar(resolved)
    assert {"setup", "metrics"} <= top


def test_env_override_wins(tmp_path, monkeypatch):
    repo = _fake_cli_repo(tmp_path / "tina4", "3.9.0", built_binary=True)
    override = _fake_tina4(tmp_path / "override_tina4", "9.9.9", ["serve", "custom"])
    monkeypatch.setattr(at, "CLI_REPO", repo)
    monkeypatch.setenv("TINA4_CLI_BIN", str(override))
    resolved, _notes = at._resolve_cli_binary()
    assert resolved == str(override)


# ── End-to-end: check_cli against fresh vs stale grammar ──────────────

def test_setup_and_metrics_pass_against_fresh_cli(tmp_path, monkeypatch):
    """The exact bug: `tina4 setup`, `tina4 setup --dry-run` and
    `tina4 metrics` must NOT be flagged when the CLI actually has them."""
    repo = _fake_cli_repo(tmp_path / "tina4", "3.9.0", built_binary=True)
    monkeypatch.setattr(at, "CLI_REPO", repo)
    monkeypatch.setattr(at.shutil, "which", lambda name: None)
    monkeypatch.delenv("TINA4_CLI_BIN", raising=False)
    monkeypatch.setattr(at, "doc_cli_mentions", lambda: {
        ("setup", None): [at.REPO_ROOT / "docs/get-started.md"],
        ("setup", "--dry-run"): [at.REPO_ROOT / "docs/get-started.md"],
        ("metrics", None): [at.REPO_ROOT / "docs/index.md"],
    })
    drift, lines = at.check_cli()
    assert drift == 0, "\n".join(lines)


def test_fake_command_is_still_flagged(tmp_path, monkeypatch):
    """No blanket whitelist: a command the CLI does NOT have is still drift."""
    repo = _fake_cli_repo(tmp_path / "tina4", "3.9.0", built_binary=True)
    monkeypatch.setattr(at, "CLI_REPO", repo)
    monkeypatch.setattr(at.shutil, "which", lambda name: None)
    monkeypatch.delenv("TINA4_CLI_BIN", raising=False)
    monkeypatch.setattr(at, "doc_cli_mentions", lambda: {
        ("env-migrate", None): [at.REPO_ROOT / "docs/index.md"],  # never real
    })
    drift, lines = at.check_cli()
    assert drift == 1, "\n".join(lines)


def test_framework_colon_subcommand_is_forwarded(tmp_path, monkeypatch):
    repo = _fake_cli_repo(tmp_path / "tina4", "3.9.0", built_binary=True)
    monkeypatch.setattr(at, "CLI_REPO", repo)
    monkeypatch.setattr(at.shutil, "which", lambda name: None)
    monkeypatch.delenv("TINA4_CLI_BIN", raising=False)
    monkeypatch.setattr(at, "doc_cli_mentions", lambda: {
        ("migrate:status", None): [at.REPO_ROOT / "docs/database.md"],
        ("migrate:rollback", None): [at.REPO_ROOT / "docs/database.md"],
    })
    drift, lines = at.check_cli()
    assert drift == 0, "\n".join(lines)


# ── Integration: the real sibling repo, if present, has zero CLI drift ─

def test_real_repo_has_no_cli_drift():
    """When the real ../tina4 source is a sibling (as in CI, which builds
    it), the actual docs must have zero CLI drift. Skips when the CLI repo
    isn't cloned/built locally."""
    binary, _notes = at._resolve_cli_binary()
    if binary is None or at.real_cli_grammar(binary) is None:
        pytest.skip("no tina4 CLI available (../tina4 not cloned/built)")
    # Only meaningful when the grammar came from a real build, not a random
    # PATH binary that could be stale.
    if not (at.CLI_REPO / "Cargo.toml").exists():
        pytest.skip("../tina4 source repo not present")
    drift, lines = at.check_cli()
    assert drift == 0, "real docs have CLI drift:\n" + "\n".join(lines)
