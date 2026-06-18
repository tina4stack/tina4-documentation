#!/usr/bin/env python3
"""
Vanilla-vs-skills benchmark for Tina4 — generation step.

For each task in tasks.json, ask a model to produce code TWICE:
  - vanilla arm: the bare prompt, no Tina4 skill in context
  - skills  arm: the same prompt, with the tina4-developer SKILL.md prepended
                 as a system prompt (exactly how the skill reaches the model)

Saves every completion under results/<task>-<arm>-<run>.md. Scoring is a
separate step (score.py) so you can re-score without re-spending on the API.

Zero third-party deps — stdlib urllib only, matching Tina4's ethos.

Setup:
  export ANTHROPIC_API_KEY=sk-ant-...     # required
Usage:
  python run.py                            # default model, 5 runs/arm
  python run.py --model claude-haiku-4-5-20251001 --runs 10
  python run.py --skill ../../path/to/SKILL.md   # override the skill file
"""
import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
API_URL = "https://api.anthropic.com/v1/messages"

# Default skill = the Python tina4-developer skill, resolved relative to a
# sibling checkout of the framework repos. Override with --skill.
DEFAULT_SKILL_CANDIDATES = [
    HERE / "../../../tina4-python/.claude/skills/tina4-developer/SKILL.md",
    HERE / "../../../tina4-php/.claude/skills/tina4-developer/SKILL.md",
]


def resolve_skill(arg: str | None) -> Path:
    if arg:
        p = Path(arg)
        if not p.exists():
            sys.exit(f"skill file not found: {p}")
        return p
    for c in DEFAULT_SKILL_CANDIDATES:
        if c.exists():
            return c.resolve()
    sys.exit("Could not find a tina4-developer SKILL.md — pass --skill <path>.")


def call(model: str, api_key: str, system: str | None, prompt: str) -> str:
    body = {
        "model": model,
        "max_tokens": 2048,
        "messages": [{"role": "user", "content": prompt}],
    }
    if system:
        body["system"] = system
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode(),
        headers={
            "content-type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.loads(r.read())
    return "".join(block.get("text", "") for block in data.get("content", []))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="claude-sonnet-4-6")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--skill", default=None)
    args = ap.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        sys.exit("Set ANTHROPIC_API_KEY first (this harness calls the Anthropic API).")

    skill_path = resolve_skill(args.skill)
    skill_text = skill_path.read_text(encoding="utf-8")
    tasks = json.loads((HERE / "tasks.json").read_text(encoding="utf-8"))["tasks"]

    out = HERE / "results"
    out.mkdir(exist_ok=True)
    print(f"model={args.model} runs={args.runs} skill={skill_path.name}")

    for task in tasks:
        for arm, system in (("vanilla", None), ("skills", skill_text)):
            for run in range(1, args.runs + 1):
                try:
                    text = call(args.model, api_key, system, task["prompt"])
                except Exception as e:  # network / API error — record and move on
                    text = f"__ERROR__ {e}"
                f = out / f"{task['id']}-{arm}-{run}.md"
                f.write_text(text, encoding="utf-8")
                print(f"  {task['id']:22} {arm:7} run {run}/{args.runs}  ({len(text)} chars)")

    print(f"\nWrote completions to {out}.  Now run:  python score.py")


if __name__ == "__main__":
    main()
