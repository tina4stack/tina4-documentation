#!/usr/bin/env python3
"""Per-feature code-health harness for the 98-feature audit.

PLANNING TOOL ONLY. It measures; it never edits a framework.

Given one feature and the file(s) that implement it in each of the four
frameworks, it reports LOC, total and average cyclomatic complexity, the
maintainability index, function count, and every offender the native scanner
flags. That is the objective half of the audit (LOC / CC / MI). The judgement
half (SOLID, DRY, best-implementation) is written by hand against the source,
because no scanner can tell you which of four designs is the right one.

Measurement engine: `tina4 metrics --json`, the native language-agnostic scanner
(ADR-0002). Python, PHP, Ruby, TypeScript and JS all go through the same engine,
so the four numbers are comparable -- a per-language tool per language would not
be. Numbers are reported for whatever paths you name, so name the files that
genuinely implement the feature and nothing else: point it at a barrel file and
you measure the barrel.

Usage:
    ./feature-audit.py <feature-name> \
        --python  tina4-python/tina4_python/queue/__init__.py \
        --php     tina4-php/Tina4/Queue.php \
        --ruby    tina4-ruby/lib/tina4/queue.rb \
        --node    tina4-nodejs/packages/core/src/queue.ts

    ./feature-audit.py --spec features.json     # batch mode, see SPEC FORMAT

Repeat a flag to measure several files as one feature:
    --python a.py --python b.py

SPEC FORMAT (batch mode) -- a JSON list, one object per feature:
    [{"name": "Queue", "python": ["..."], "php": ["..."],
      "ruby": ["..."], "node": ["..."]}]
A missing or empty list for a framework is reported as "absent", which is itself
an audit finding: a feature counted as shipped in all four that no file
implements is a parity gap, not a row.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

# Repo root: this file lives at <root>/tina4-documentation/plan/v3/, so every
# path in a spec can be written relative to the root the way a human reads it
# ("tina4-python/..."), independent of the caller's cwd.
ROOT = Path(__file__).resolve().parents[3]

FRAMEWORKS = ("python", "php", "ruby", "node")


def measure(paths: list[str]) -> dict:
    """Aggregate `tina4 metrics --json` over one framework's files for a feature.

    Complexity sums (a feature spread over three files is as complex as its
    parts) while maintainability is LOC-weighted -- averaging a 900-line file
    with a 20-line file as equals would flatter the big one, and the big one is
    what a maintainer has to read.
    """
    files: list[dict] = []
    offenders: list[dict] = []
    missing: list[str] = []

    for rel in paths:
        target = ROOT / rel
        if not target.exists():
            missing.append(rel)
            continue
        proc = subprocess.run(
            ["tina4", "metrics", "--json", "--path", str(target), "--top", "50"],
            capture_output=True, text=True,
        )
        if proc.returncode not in (0, 1):  # 1 is the --fail-on gate, not an error
            missing.append(f"{rel} (scanner exit {proc.returncode}: {proc.stderr.strip()[:120]})")
            continue
        try:
            data = json.loads(proc.stdout)
        except json.JSONDecodeError:
            missing.append(f"{rel} (unparseable scanner output)")
            continue
        for fm in data.get("file_metrics", []):
            fm = dict(fm)
            fm["path"] = rel
            files.append(fm)
        for off in data.get("offenders", []):
            off = dict(off)
            off["file"] = rel
            offenders.append(off)

    if not files:
        return {"absent": True, "missing": missing}

    loc = sum(f.get("loc", 0) for f in files)
    complexity = sum(f.get("complexity", 0) for f in files)
    functions = sum(f.get("functions", 0) for f in files)
    weighted_mi = (
        sum(f.get("maintainability", 0) * f.get("loc", 0) for f in files) / loc
        if loc else 0.0
    )
    return {
        "absent": False,
        "missing": missing,
        "files": len(files),
        "loc": loc,
        "complexity": complexity,
        "avg_complexity": round(complexity / functions, 2) if functions else 0.0,
        "functions": functions,
        "maintainability": round(weighted_mi, 1),
        "worst_function": max(
            (o for o in offenders if o.get("kind") == "complexity"),
            key=lambda o: o.get("score", 0), default=None,
        ),
        "errors": sum(1 for o in offenders if o.get("severity") == "error"),
        "warns": sum(1 for o in offenders if o.get("severity") == "warn"),
        "offenders": sorted(offenders, key=lambda o: -o.get("score", 0)),
    }


def audit(feature: str, paths: dict[str, list[str]]) -> dict:
    return {"feature": feature,
            "frameworks": {fw: measure(paths.get(fw) or []) for fw in FRAMEWORKS}}


def render(result: dict) -> str:
    """One markdown block per feature: the comparison table, then the offenders."""
    out = [f"### {result['feature']}", ""]
    out.append("| | LOC | fns | CC total | CC avg | worst fn | MI | flags |")
    out.append("| --- | --- | --- | --- | --- | --- | --- | --- |")

    for fw in FRAMEWORKS:
        m = result["frameworks"][fw]
        if m["absent"]:
            note = "; ".join(m["missing"]) or "no path given"
            out.append(f"| {fw} | ABSENT | - | - | - | - | - | {note} |")
            continue
        worst = m["worst_function"]
        worst_txt = "-"
        if worst:
            detail = worst.get("detail", "")
            name = detail.split(" - ")[0].split(" — ")[0].strip() or "?"
            worst_txt = f"{name} ({int(worst.get('score', 0))})"
        flags = []
        if m["errors"]:
            flags.append(f"{m['errors']} error")
        if m["warns"]:
            flags.append(f"{m['warns']} warn")
        out.append(
            f"| {fw} | {m['loc']} | {m['functions']} | {m['complexity']} | "
            f"{m['avg_complexity']} | {worst_txt} | {m['maintainability']} | "
            f"{', '.join(flags) or 'clean'} |"
        )

    present = {fw: m for fw, m in result["frameworks"].items() if not m["absent"]}
    if len(present) > 1:
        leanest = min(present.items(), key=lambda kv: kv[1]["loc"])
        simplest = min(present.items(), key=lambda kv: kv[1]["avg_complexity"])
        most_maintainable = max(present.items(), key=lambda kv: kv[1]["maintainability"])
        spread = leanest[1]["loc"] and (
            max(m["loc"] for m in present.values()) / leanest[1]["loc"]
        )
        out += ["", f"leanest: **{leanest[0]}** ({leanest[1]['loc']} LOC), "
                    f"simplest per function: **{simplest[0]}** "
                    f"({simplest[1]['avg_complexity']}), "
                    f"most maintainable: **{most_maintainable[0]}** "
                    f"({most_maintainable[1]['maintainability']}), "
                    f"LOC spread: **{spread:.1f}x**"]
    return "\n".join(out) + "\n"


def main() -> int:
    if not shutil.which("tina4"):
        print("tina4 CLI not on PATH -- the scanner IS the measurement engine", file=sys.stderr)
        return 2

    ap = argparse.ArgumentParser(description="Per-feature code-health audit harness")
    ap.add_argument("feature", nargs="?", help="feature name")
    ap.add_argument("--spec", help="JSON file of features (batch mode)")
    ap.add_argument("--json", action="store_true", help="emit raw JSON instead of markdown")
    for fw in FRAMEWORKS:
        ap.add_argument(f"--{fw}", action="append", default=[], metavar="PATH")
    args = ap.parse_args()

    if args.spec:
        specs = json.loads(Path(args.spec).read_text())
    elif args.feature:
        specs = [{"name": args.feature,
                  **{fw: getattr(args, fw) for fw in FRAMEWORKS}}]
    else:
        ap.error("give a feature name (with --python/--php/--ruby/--node) or --spec")

    results = [audit(s["name"], {fw: s.get(fw, []) for fw in FRAMEWORKS}) for s in specs]

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for r in results:
            print(render(r))
    return 0


if __name__ == "__main__":
    sys.exit(main())
