# Frond template precompilation — ahead-of-time prototype (ADR-0001, part 1, Python master)

## Goal
Prove the ahead-of-time pipeline on the highest-value, best-proven slice: compile a Frond template
ONCE into a native Python callable (the Jinja2 model), cache it by path+mtime, and make
render() just CALL the compiled function — eliminating per-render parsing / tree-walking.
Behaviour-identical. Python MASTER only. This is a PROOF, not a ship: if it doesn't beat
the current render path or the suite regresses, revert and say so honestly.

Anchor: ADR-0001 (plan/v3/DECISIONS.md). Dev visibility stays intact (recompile on mtime in
dev); prod-writing a compiled .py + checksum is a LATER part (out of scope here).

## Approach (incremental codegen + interpreted fallback = behaviour-safe)
- Keep the existing tokenizer/parser (`tina4_python/frond/engine.py`) — it produces the
  node tree. Do NOT rewrite parsing.
- Add a codegen pass: walk the parsed tree ONCE and emit Python source for a function
  `def _rendered(ctx, filters, escape): ...` that appends to a buffer and returns the
  string. `compile()` it, cache the callable keyed by (template identity + mtime), reusing
  the existing mtime/token-cache bounding pattern.
- Compile the COMMON hot-path constructs first: text, `{{ var }}` / dotted paths, filter
  pipes `|`, `if/elif/else`, `for` (+ loop vars), `set`, autoescape/`raw`. For ANY
  construct not yet compiled (extends/block, include, macro, cache-block, tests, exotic
  whitespace control), **fall back to the existing interpreted renderer for that template**
  — so the full suite stays green from day one and the win shows on the common templates.
- A compile error must fall back to interpreted (never break a render). Log at debug only.

## Constraints (non-negotiable)
- **No mocks.** Real render, real pytest. The full Frond suite (~361 template tests) is the
  behaviour guard — a precompiled template must render byte-identically to interpreted.
- Behaviour-identical: not one rendered byte changes. Prove via the suite.
- **Branch off v3.** Commit ONLY the frond files (engine.py + any new frond/*.py + tests).
  Leave the pre-existing dirty working-tree changes (`.claude/skills/...`, `uv.lock`) ALONE
  — they are not part of this work (the previous Frond worker correctly did the same).
- Do NOT merge, do NOT tag. Owner + independent verification gate that.
- One worker in this tree only.

## Measurement (accountable — measure, don't assert)
- Run `benchmarks/carbon_benchmarks.py template` on v3 BASELINE first (record p50 + mean
  ops/sec), then AFTER. Report both; only a real, suite-green improvement counts.
- Profile a steady-state render to show per-render parse/tree-walk calls collapse to ~0 on
  compiled templates (like the expr-cache profile showed 8.58M _find_outside_quotes -> 0).
- If Carbonah is on PATH, report SCI before/after too.

## Relationship to feature/frond-expr-cache (afe65cc / 96bc780, unmerged, +33% p50)
Precompilation likely SUPERSEDES the expr-cache opt: a compiled template bakes in the
resolved expression structure, so the per-expr scanning the expr-cache branch optimized is
gone entirely. Branch off v3 (clean baseline, WITHOUT expr-cache) and measure precompile vs
that baseline. Report whether precompile alone meets/beats the expr-cache branch's numbers
(baseline ~1,563 mean / ~1,814 p50 -> expr-cache ~2,135 mean / ~2,418 p50). Owner decides
the expr-cache branch's fate from the result — do NOT merge either here.

## Scope checklist
- [x] Read engine.py: tokenizer/parser, the render tree-walk, the token/mtime cache infra.
- [x] Add codegen for the common constructs + interpreted fallback for the rest + compile cache.
      (New `tina4_python/frond/compiler.py`; engine `_get_compiled` + `compile_key` threaded
      through render/render_string/_execute_cached/_execute_with_source; `_compiled_fn` cache.)
- [x] Full `pytest tests/` GREEN, run TWICE at the exact HEAD 6ac5086 (3,719 passed, 114 skipped,
      0 failed both runs). + 35 new lock-in tests in tests/test_frond_precompile.py.
- [x] Bench template category BEFORE (v3) vs AFTER; profile parse-call collapse; Carbonah SCI.
- [x] Branch feature/frond-precompile off v3 (ef55af7); commit frond files only (6ac5086).
      NOT merged, NOT tagged.

## Results (macOS, CPython 3.13.5, template category)
| variant                                   | p50 ops/sec | mean ops/sec | vs baseline p50 |
|-------------------------------------------|-------------|--------------|-----------------|
| baseline v3 (ef55af7)                     | ~1,820      | ~1,683       | —               |
| **precompile alone (Stage 1, committed)** | **~2,010**  | **~1,916**   | **+10% / +14%** |
| expr-cache alone (re-measured here)       | ~2,417      | ~2,293       | +33% / +36%     |
| precompile + expr-cache (experiment)      | ~2,823      | ~2,717       | +55% / +61%     |

Profiler (3,000 steady-state renders), precompile alone: `_render_tokens` 66,000 -> 0,
`_strip_tag` 543,000 -> 0, `_handle_for`/`_handle_if` 3,000 -> 0, `_tokenize` 0 (cached),
`compiled path used: True`. Expression scanning UNCHANGED (`_find_outside_quotes` stays
8,580,000) — precompile removes the STRUCTURAL tree-walk, not the per-expression scan.
Carbonah SCI (region ZA, modelled/noisy): AFTER < BEFORE in all pairs, grade A+ held.

## Verdict on "does precompile supersede the expr-cache branch?"
NO — precompile ALONE (structural AOT) does NOT meet or beat expr-cache (2,010 vs 2,417 p50).
The plan's hypothesis is refuted by measurement + profile: the two optimise DISJOINT costs and
are COMPLEMENTARY. precompile collapses the token tree-walk (`_render_tokens`/`_strip_tag`/
`_handle_*` -> 0); expr-cache collapses per-expression operator scanning (`_find_outside_quotes`
8.58M -> 0). Stacking both is the biggest win (~2,823 p50, +55%), beating either alone and with
BOTH cost classes at 0 in the profile. Recommendation: keep the expr-cache branch and land both;
precompile does not subsume it. A future "part 2" full expression-AOT (codegen'ing expression
resolution instead of reusing `_eval_var`/`_eval_expr`) could fold expr-cache's win into the
compiled artifact, but that is a much larger reimplementation than this proof.

## Status: Prototype complete (Python master). Committed on feature/frond-precompile @ 6ac5086.
Not merged, not tagged — owner gate. Pre-existing dirty tree (.claude/skills/..., uv.lock,
benchmarks/comparison_report.json) left untouched as instructed.
