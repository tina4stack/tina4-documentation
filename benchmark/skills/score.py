#!/usr/bin/env python3
"""
Vanilla-vs-skills benchmark for Tina4 — scoring step.

Reads the completions run.py saved under results/ and scores each on three
axes (no API calls, re-runnable for free):

  idiom        markers showing correct Tina4 usage are present (higher = better)
  hallucinated patterns proving the model reached for Flask/FastAPI/etc. or
               invented APIs (LOWER = better — this is the skill's whole job)
  loc          lines inside fenced code blocks (lower = leaner, ponytail-style)

Reports per-task and overall medians for the vanilla vs skills arms, so you
can see whether the skill actually changes behaviour and by how much.

Usage:  python score.py
"""
import json
import re
import statistics
from pathlib import Path

HERE = Path(__file__).resolve().parent
FENCE = re.compile(r"```[a-zA-Z0-9_+-]*\n(.*?)```", re.DOTALL)


def loc(text: str) -> int:
    return sum(
        len([ln for ln in block.splitlines() if ln.strip()])
        for block in FENCE.findall(text)
    )


def count(text: str, needles: list[str]) -> int:
    low = text.lower()
    return sum(low.count(n.lower()) for n in needles)


def med(xs: list[float]) -> float:
    return round(statistics.median(xs), 1) if xs else 0.0


def main() -> None:
    spec = json.loads((HERE / "tasks.json").read_text(encoding="utf-8"))
    tasks = {t["id"]: t for t in spec["tasks"]}
    results = HERE / "results"
    if not results.exists() or not any(results.glob("*.md")):
        raise SystemExit("No results/ yet — run run.py first.")

    # arm -> metric -> list of per-completion values
    agg: dict[str, dict[str, list[float]]] = {
        "vanilla": {"idiom": [], "halluc": [], "loc": []},
        "skills": {"idiom": [], "halluc": [], "loc": []},
    }

    print(f"{'task':24} {'arm':8} {'idiom':>6} {'halluc':>7} {'loc':>5}")
    print("-" * 54)
    for tid, task in tasks.items():
        for arm in ("vanilla", "skills"):
            files = sorted(results.glob(f"{tid}-{arm}-*.md"))
            if not files:
                continue
            idi, hal, lc = [], [], []
            for f in files:
                t = f.read_text(encoding="utf-8")
                if t.startswith("__ERROR__"):
                    continue
                idi.append(count(t, task["idiom"]))
                hal.append(count(t, task["halluc"]))
                lc.append(loc(t))
            agg[arm]["idiom"] += idi
            agg[arm]["halluc"] += hal
            agg[arm]["loc"] += lc
            print(f"{tid:24} {arm:8} {med(idi):>6} {med(hal):>7} {med(lc):>5}")
        print()

    print("=" * 54)
    print(f"{'OVERALL (median)':24} {'arm':8} {'idiom':>6} {'halluc':>7} {'loc':>5}")
    print("-" * 54)
    for arm in ("vanilla", "skills"):
        print(
            f"{'':24} {arm:8} "
            f"{med(agg[arm]['idiom']):>6} {med(agg[arm]['halluc']):>7} {med(agg[arm]['loc']):>5}"
        )
    print()
    print("Read: skills should RAISE idiom, DROP halluc toward 0, and usually lower loc.")
    print("If halluc doesn't fall, the skill isn't changing behaviour — that's the finding.")


if __name__ == "__main__":
    main()
