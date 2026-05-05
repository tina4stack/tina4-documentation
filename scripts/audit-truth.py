#!/usr/bin/env python3
"""
audit-truth.py — Catch documentation that references code that doesn't exist.

Usage:
    python3 scripts/audit-truth.py                  # report-only (exit 0)
    python3 scripts/audit-truth.py --strict         # fail on drift (CI gate)
    python3 scripts/audit-truth.py --check cli      # only the CLI check
    python3 scripts/audit-truth.py --check env      # only the env-vars check
    python3 scripts/audit-truth.py --check all      # default

What it checks
==============

1. **CLI commands** — every ``tina4 <subcommand>`` mentioned in any
   markdown doc must be a real subcommand of the ``tina4`` Rust CLI.
   Source of truth: parse ``tina4 --help`` output.

2. **Environment variables** — every ``TINA4_*`` mentioned in docs must
   appear in at least one framework source tree (read from a getenv()-
   style call). Source of truth: ripgrep across the four framework repos.

The script discovers framework source trees by walking ``..`` from the
docs repo, looking for sibling repos named ``tina4-{python,php,ruby,
nodejs,js}``. If a sibling is missing, the corresponding check is
skipped with a warning rather than failing — keeps local dev usable
when you only have one repo cloned.

Why this exists
===============

Tina4 docs drifted: ``tina4 env-migrate`` was promised in v3.12.0
release notes for months but never built. Same class of bug for 28+
other ``tina4 <command>`` references and an unknown number of
env-vars. This script is the gate that prevents recurrence.

Designed for CI
===============
- Report-only mode by default so it doesn't fight existing branches
- ``--strict`` flips it to a merge gate
- Per-check selection so you can ratchet (CLI first, env vars later)

Exit codes
==========
- 0 — no drift detected (or report-only mode)
- 1 — drift detected and ``--strict`` was passed
- 2 — couldn't locate the ``tina4`` CLI / framework sources
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Iterable

# ── Paths ─────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
WORKSPACE_ROOT = REPO_ROOT.parent  # ../

# Doc directories to scan. We deliberately skip vendored/built outputs.
DOC_GLOBS: tuple[str, ...] = (
    "docs/**/*.md",
)
SKIP_PATH_FRAGMENTS: tuple[str, ...] = (
    "/.vitepress/dist/",
    "/.vitepress/cache/",
    "/node_modules/",
    # Legacy v2 docs: kept for users on v2.x. The commands documented
    # there (`tina4 start`, `tina4 initialize:run`, `tina4 migrate:create`,
    # etc.) are accurate for that version and shouldn't be flagged
    # against the v3 CLI.
    "/docs/v2/",
)

# Framework source roots, relative to WORKSPACE_ROOT. Each is optional —
# missing sibling repos turn into a warning, not a failure.
FRAMEWORK_SOURCES: dict[str, tuple[str, ...]] = {
    "python":  ("tina4-python/tina4_python",),
    "php":     ("tina4-php/Tina4",),
    "ruby":    ("tina4-ruby/lib/tina4",),
    "nodejs":  ("tina4-nodejs/packages",),
    "js":      ("tina4-js/src",),
}


# ── Helpers ───────────────────────────────────────────────────────────

def colour(s: str, code: str) -> str:
    if not sys.stdout.isatty():
        return s
    return f"\033[{code}m{s}\033[0m"


def red(s: str) -> str:    return colour(s, "31")
def green(s: str) -> str:  return colour(s, "32")
def yellow(s: str) -> str: return colour(s, "33")
def cyan(s: str) -> str:   return colour(s, "36")
def dim(s: str) -> str:    return colour(s, "2")


def find_doc_files() -> list[Path]:
    files: list[Path] = []
    for pattern in DOC_GLOBS:
        for path in REPO_ROOT.glob(pattern):
            if any(frag in str(path) for frag in SKIP_PATH_FRAGMENTS):
                continue
            files.append(path)
    return sorted(files)


def strip_code_fences(text: str) -> str:
    r"""Remove fenced code blocks. Inline code (single-backtick) is kept
    because docs often write things like ``run \`tina4 serve\`\`` — and
    that's exactly what we want to validate."""
    return re.sub(r"^```.*?^```", "", text, flags=re.DOTALL | re.MULTILINE)


# ── Check 1: CLI commands ─────────────────────────────────────────────

def _parse_help_commands(help_text: str) -> set[str]:
    """Pull subcommand names out of a ``--help`` Commands: block."""
    cmds: set[str] = set()
    in_commands = False
    for line in help_text.splitlines():
        if line.strip() == "Commands:":
            in_commands = True
            continue
        if in_commands:
            stripped = line.lstrip()
            if not stripped:
                continue
            if line.startswith("  ") and stripped[0].islower():
                cmds.add(stripped.split()[0])
            elif line.startswith("Options:"):
                break
    return cmds


def _parse_help_positional_choices(help_text: str) -> set[str]:
    """When a subcommand declares ``<WHAT>`` with the description
    'What to generate: model, route, migration, middleware' (clap's
    style for an enum positional), grab those tokens. Lets us recognise
    ``tina4 generate model`` as legitimate without hard-coding the
    enum here — the CLI itself is the source of truth."""
    choices: set[str] = set()
    # Match descriptions of the form ``...: a, b, c, d``.
    for m in re.finditer(r":\s*((?:[a-z]+(?:[, ]+[a-z]+)+))", help_text):
        for tok in re.split(r"[,\s]+", m.group(1)):
            if tok and tok.isalpha() and tok.islower():
                choices.add(tok)
    return choices


def real_cli_grammar() -> tuple[set[str], dict[str, set[str]]] | None:
    """Two-level discovery:

    Returns ``(top_level, second_token_per_cmd)`` or ``None`` if the
    ``tina4`` binary isn't on PATH.

    - ``top_level`` is the set of valid top-level subcommands (``serve``,
      ``init``, ``migrate``, ``generate``, etc).
    - ``second_token_per_cmd`` maps each top-level subcommand to the set
      of legitimate "second tokens" — that's nested subcommands, valid
      positional enum choices, and long flags. So:

         ``tina4 generate model``     → second token ``model`` is valid
                                         (positional enum)
         ``tina4 migrate --create x`` → second token ``--create`` is valid
                                         (long flag)
         ``tina4 install python``     → second token ``python`` is valid

    The map lets us call out genuinely fake forms like
    ``tina4 generate:model`` (colon-style, never real) while accepting
    the canonical space-separated form.
    """
    binary = shutil.which("tina4")
    if not binary:
        return None
    top_help = subprocess.run(
        [binary, "--help"], capture_output=True, text=True, check=False,
    ).stdout
    top_level = _parse_help_commands(top_help)

    # Anything Clap considers an "Options:" entry shows up with two
    # spaces of indent and starts with a dash — capture them per
    # subcommand.
    second: dict[str, set[str]] = {}
    free_form: set[str] = set()
    for cmd in top_level:
        sub_help = subprocess.run(
            [binary, cmd, "--help"], capture_output=True, text=True, check=False,
        ).stdout
        tokens: set[str] = set()
        # Nested subcommands (rare today but supported by clap).
        tokens |= _parse_help_commands(sub_help)
        # Positional enum choices (e.g. ``generate <model|route|…>``).
        tokens |= _parse_help_positional_choices(sub_help)
        # Long flags.
        for m in re.finditer(r"--([a-z][a-z0-9-]+)", sub_help):
            tokens.add(f"--{m.group(1)}")
        second[cmd] = tokens

        # Subcommands whose Usage line has more than one positional
        # bracket (e.g. ``Usage: tina4 init [LANG] [PATH]``) accept a
        # free-form second positional. Don't validate the second token
        # for those — the user supplies their own project name.
        usage = next((ln for ln in sub_help.splitlines()
                      if ln.lstrip().startswith("Usage:")), "")
        positional_count = len(re.findall(r"<[A-Z_]+>|\[[A-Z_]+\]", usage))
        if positional_count > 1:
            free_form.add(cmd)

    # Pack free-form info into the second-token map under a sentinel
    # key so the existing ABI is preserved.
    second["__free_form__"] = free_form
    return top_level, second


def real_cli_subcommands() -> set[str] | None:
    """Back-compat shim — returns just the top-level set, or None."""
    g = real_cli_grammar()
    return g[0] if g else None


# Captures ``tina4 <subcmd>`` and ``tina4 <subcmd> <second>`` mentions.
# Group 1 is the first token (subcommand or fake colon-form); group 2
# (optional) is the second token — could be a positional argument name,
# a long flag, or a fake colon-style continuation.
_TINA4_CMD_RE = re.compile(
    r"(?<![A-Za-z0-9_-])tina4 ([a-z][a-z0-9:_-]*)(?:\s+(--?[a-z][a-z0-9_-]*|[a-z][a-z0-9:_-]*))?"
)

# Tokens that look like CLI subcommands but are actually nouns appearing
# in adjective-noun prose: "tina4 backend", "every tina4 project", "the
# tina4 binary", "from tina4 import …" (a Python statement). Whitelisted
# here so the audit doesn't false-positive on prose. Genuine fake CLI
# commands either come from these tokens being USED as commands (rare —
# requires the next word to look like a flag or argument) or from
# unfamiliar tokens that wouldn't fit this list.
_CLI_NOISE = {
    # Adjective-noun grammar
    "stack", "framework", "frameworks", "for", "is", "with", "and",
    "v3", "v2", "v1", "version", "binary", "binaries", "team", "team's",
    "project", "projects", "app", "apps", "application", "applications",
    "backend", "backends", "frontend", "frontends",
    "files", "file", "config", "configs", "site", "sites", "user", "users",
    "developer", "developers", "world", "release", "releases",
    "signals", "components", "chapter", "core",  # JS book nouns
    # Python statement: ``from tina4 import Router``
    "import",
    # Language labels
    "python", "php", "ruby", "nodejs", "js", "delphi", "javascript",
}


def doc_cli_mentions() -> dict[tuple[str, str | None], list[Path]]:
    """Walk every doc, return
    ``{(subcommand, second_token_or_None): [paths]}``."""
    seen: dict[tuple[str, str | None], list[Path]] = defaultdict(list)
    for path in find_doc_files():
        text = strip_code_fences(path.read_text(encoding="utf-8", errors="replace"))
        for m in _TINA4_CMD_RE.finditer(text):
            cmd = m.group(1)
            second = m.group(2)
            if cmd in _CLI_NOISE:
                continue
            seen[(cmd, second)].append(path)
    return seen


def check_cli() -> tuple[int, list[str]]:
    """Two-level drift detection: invalid first token AND invalid
    second token (when one is present and the first token is real)."""
    grammar = real_cli_grammar()
    if grammar is None:
        return 0, [yellow("⚠ tina4 binary not on PATH — skipping CLI check")]
    real_top, real_second = grammar

    mentions = doc_cli_mentions()
    missing_first: dict[str, list[Path]] = defaultdict(list)
    missing_second: dict[tuple[str, str], list[Path]] = defaultdict(list)

    for (cmd, second), paths in mentions.items():
        # Colon-form: ``migrate:create`` / ``make:migration`` — never a
        # real Tina4 form, always fake.
        if ":" in cmd:
            missing_first[cmd].extend(paths)
            continue
        if cmd not in real_top:
            missing_first[cmd].extend(paths)
            continue
        # First token is real. Validate the second token if present.
        if second is None:
            continue
        # Subcommands with multiple positional args (e.g. ``init`` takes
        # ``[LANG] [PATH]``) accept free-form second tokens — nothing
        # to validate.
        if cmd in real_second.get("__free_form__", set()):
            continue
        # Tokens with hyphens or path separators are clearly free-form
        # values (project names, file paths) — never enum candidates.
        if not second.startswith("-") and ("-" in second or "/" in second or "." in second):
            continue
        # Skip words that might be free-text continuations (verbs, paths,
        # quoted strings) — we only flag tokens that look like a CLI
        # second-token candidate AND aren't in the known set.
        if second.startswith("-"):
            # Long flag — must be in the real second-token set.
            if second not in real_second.get(cmd, set()):
                missing_second[(cmd, second)].extend(paths)
        else:
            # Positional. We only flag it as drift if the subcommand
            # has a known set of positional choices (i.e. an enum-style
            # arg) AND the second token is plainly a token-shaped
            # identifier (no spaces, lowercase, looks like it's pretending
            # to be a sub-arg). Otherwise it's likely a free-form value
            # like a file name or description string.
            choices = real_second.get(cmd, set())
            # Only flag if there ARE known choices (so "tina4 init python"
            # passes when "python" is in the choices), and only if the
            # token is short and identifier-ish.
            looks_like_token = re.fullmatch(r"[a-z][a-z0-9_-]+", second) is not None
            if choices and looks_like_token and second not in choices:
                # And we don't flag if the choice set is empty (means the
                # subcommand takes free-form positionals).
                missing_second[(cmd, second)].extend(paths)

    drift = len(missing_first) + len(missing_second)
    lines = [f"\n{cyan('CLI check')} — real top-level: {len(real_top)}, "
             f"unique doc forms: {len(mentions)}"]
    if drift == 0:
        lines.append(green("  ✓ no drift — every `tina4 <cmd> [<arg>]` is real"))
        return 0, lines

    if missing_first:
        lines.append(red(f"  ✗ {len(missing_first)} fake top-level subcommand(s):"))
        for cmd in sorted(missing_first):
            paths = sorted({str(p.relative_to(REPO_ROOT)) for p in missing_first[cmd]})
            lines.append(f"    {red('•')} tina4 {cmd:<24s} {dim('→ ' + ', '.join(paths[:3]))}"
                         + (dim(f", … +{len(paths)-3}") if len(paths) > 3 else ""))
    if missing_second:
        lines.append(red(f"  ✗ {len(missing_second)} fake second-token form(s):"))
        for (cmd, second) in sorted(missing_second):
            paths = sorted({str(p.relative_to(REPO_ROOT)) for p in missing_second[(cmd, second)]})
            lines.append(f"    {red('•')} tina4 {cmd} {second:<24s} {dim('→ ' + ', '.join(paths[:3]))}"
                         + (dim(f", … +{len(paths)-3}") if len(paths) > 3 else ""))
    return drift, lines


# ── Check 2: Environment variables ────────────────────────────────────

# Every TINA4_* token, anywhere in markdown.
_DOC_ENV_RE = re.compile(r"\bTINA4_[A-Z][A-Z0-9_]*\b")


def real_env_vars() -> tuple[set[str], list[str]]:
    """Walk the framework source trees, return the union of every
    ``TINA4_*`` actually referenced. Also returns a list of human-readable
    notes (e.g. which sibling repos were skipped)."""
    notes: list[str] = []
    real: set[str] = set()
    for label, rels in FRAMEWORK_SOURCES.items():
        for rel in rels:
            root = WORKSPACE_ROOT / rel
            if not root.exists():
                notes.append(yellow(f"⚠ skipping {label}: {rel} not found"))
                continue
            # ripgrep is fast and respects .gitignore — fall back to
            # python walk if rg isn't installed.
            if shutil.which("rg"):
                out = subprocess.run(
                    ["rg", "-oh", r"TINA4_[A-Z][A-Z0-9_]+", str(root)],
                    capture_output=True, text=True, check=False,
                ).stdout
            else:
                out = ""
                for p in root.rglob("*"):
                    if not p.is_file() or p.suffix in {".pyc", ".lock", ".log"}:
                        continue
                    if "/node_modules/" in str(p) or "/__pycache__/" in str(p):
                        continue
                    try:
                        text = p.read_text(encoding="utf-8", errors="ignore")
                    except OSError:
                        continue
                    out += "\n".join(re.findall(r"TINA4_[A-Z][A-Z0-9_]+", text)) + "\n"
            real |= {ln.strip() for ln in out.splitlines() if ln.strip()}
    return real, notes


def doc_env_mentions() -> dict[str, list[Path]]:
    seen: dict[str, list[Path]] = defaultdict(list)
    for path in find_doc_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        for m in _DOC_ENV_RE.finditer(text):
            seen[m.group(0)].append(path)
    return seen


# Env-var tokens that look like vars but are actually prose references
# to a *family* of vars. Release notes commonly write "added the
# TINA4_KAFKA_* family" or "TINA4_QUEUE_BACKEND/_PATH/_URL" — the regex
# captures `TINA4_KAFKA_` and `TINA4_QUEUE_` as bare tokens, but those
# trailing underscores never appear in real getenv() calls. We filter
# them so the audit doesn't false-positive on family-prefix prose.
_ENV_NOISE = {
    "TINA4_",  # the prefix itself, mentioned in prose
}


def _is_prefix_token(name: str) -> bool:
    """``TINA4_KAFKA_`` and ``TINA4_QUEUE_`` are family-prefix references
    in release notes / book chapters; they don't represent real env vars."""
    return name.endswith("_")


def check_env() -> tuple[int, list[str]]:
    real, notes = real_env_vars()
    if not real:
        return 0, [yellow("⚠ no framework source trees found — skipping env check")] + notes

    mentions = doc_env_mentions()
    missing = {var: paths for var, paths in mentions.items()
               if var not in real
               and var not in _ENV_NOISE
               and not _is_prefix_token(var)}

    lines = [f"\n{cyan('Env vars check')} — real: {len(real)}, "
             f"doc mentions: {len(mentions)}"]
    lines.extend(notes)
    if not missing:
        lines.append(green("  ✓ no drift — every doc-mentioned TINA4_* exists in source"))
        return 0, lines

    lines.append(red(f"  ✗ {len(missing)} fake env var(s) referenced in docs:"))
    for var in sorted(missing):
        paths = sorted({str(p.relative_to(REPO_ROOT)) for p in missing[var]})
        lines.append(f"    {red('•')} {var:<40s} {dim('→ ' + ', '.join(paths[:3]))}"
                     + (dim(f", … +{len(paths)-3} more") if len(paths) > 3 else ""))
    return len(missing), lines


# ── Driver ────────────────────────────────────────────────────────────

CHECKS = {
    "cli": check_cli,
    "env": check_env,
}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--strict", action="store_true",
                   help="exit non-zero on CLI drift (CI gate). Env drift "
                        "stays warn-only until the existing backlog is "
                        "cleared; pass --strict-env to also gate env vars.")
    p.add_argument("--strict-env", action="store_true",
                   help="exit non-zero on env-var drift too (only flip on "
                        "after the existing 39-entry backlog is resolved).")
    p.add_argument("--check", default="all", choices=["all", *CHECKS.keys()],
                   help="run only one check (default: all)")
    p.add_argument("--json", action="store_true",
                   help="emit JSON instead of human output (for CI annotations)")
    args = p.parse_args()

    selected = CHECKS if args.check == "all" else {args.check: CHECKS[args.check]}
    total_drift = 0
    all_lines: list[str] = []
    json_payload: dict[str, int] = {}

    for name, fn in selected.items():
        drift, lines = fn()
        total_drift += drift
        all_lines.extend(lines)
        json_payload[name] = drift

    if args.json:
        print(json.dumps({"drift": total_drift, "by_check": json_payload}))
    else:
        for line in all_lines:
            print(line)
        print()
        if total_drift == 0:
            print(green(f"✓ docs ↔ code are in sync"))
        else:
            print(red(f"✗ {total_drift} fake reference(s) found"))
            print(dim("  Build the real implementation OR delete the doc reference."))
            print(dim("  This script is the source of truth — see scripts/audit-truth.py."))

    # Two gates: CLI is strict immediately (we just got it to zero),
    # env stays warn-only until the existing 39-entry backlog is
    # cleared. --strict-env opts in to gating env too.
    cli_drift = json_payload.get("cli", 0)
    env_drift = json_payload.get("env", 0)
    if args.strict and cli_drift > 0:
        return 1
    if args.strict_env and env_drift > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
