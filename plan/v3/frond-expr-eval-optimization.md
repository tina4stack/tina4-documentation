# Frond template render optimization — memoize per-expression structural parse

## Why (measured, this session)
Carbonah green baseline (Python master, arm64): Template Rendering = **1,563 p50 ops/sec**
— ~10x slower than every other non-DB category (JSON 802k, plaintext 6.75M). Template
render is pure CPU, so cutting it is a direct energy win (Carbonah A+ guard).

cProfile of the render hot path (3000 renders of the 20-item bench template):
- `_eval_expr` (engine.py:592) — 315k calls, 2.539s cumulative (biggest)
- `_find_outside_quotes` (475) — **8,580,000 calls**, 0.541s
- operator-scan genexpr (589) — 2,583,000 calls
- `_find_ternary` (222) — 309k calls
Tokens ARE cached (tokenizing is ~1.9% of a render). The waste is that `_eval_expr`
RE-SCANS the same invariant expression strings (`item.name | upper`, `loop.even ?
'even' : 'odd'`, `item.price | number_format(2)`, ...) on every render AND every loop
iteration — operator detection, ternary split, filter split — all redone each time.

## The optimization (structure is invariant; only values change)
Memoize the per-expression STRUCTURAL analysis keyed by the expression string:
which top-level operator (if any) the expr splits on and where (`~`, comparisons,
`??`, arithmetic, ternary `?:`, pipe `|`), array-literal detection, filter-chain
split — the parts computed by `_find_outside_quotes`/`_find_ternary`/the operator
genexpr. First `_eval_expr(expr)` computes + caches a small descriptor; later calls
skip straight to VALUE resolution against `context`. Value lookups + filter
application still run every call (values change) — only the string-scanning collapses
to a dict lookup.

Constraints on the cache:
- Key = the expr string (+ a flag for whether a filter applier is threaded, since
  that changes whether the pipe step runs). The descriptor MUST be render-independent
  (no context values baked in) — that is the correctness invariant.
- Bounded (avoid unbounded growth on dynamically-built expr strings): a simple size
  cap / LRU, mirroring how the token cache is bounded.
- Behaviour identical — this is a pure speed change. The full Frond suite is the guard.

## Scope (Python master FIRST; mirror after it is proven)
- [ ] Read engine.py _eval_expr (592), _find_outside_quotes (475), _find_ternary (222),
      the operator-scan, and the existing token-cache infra (reuse its bounding pattern).
- [ ] Add the expression-descriptor cache; route _eval_expr through it. No behaviour change.
- [ ] Full `pytest tests/` GREEN (the whole suite — Frond has extensive coverage; this is
      the correctness guard, no-mock). Re-run; don't trust the first pass.
- [ ] Re-run the SAME carbon bench (`python benchmarks/carbon_benchmarks.py`) and report
      Template Rendering ops/sec BEFORE (1,563) vs AFTER. Only a real, suite-green
      improvement counts — if it doesn't move or the suite regresses, revert and say so.
- [ ] Re-profile to confirm _find_outside_quotes call count dropped (the 8.58M -> ~tokens).
- [ ] Branch feature/frond-expr-cache off v3. Commit. Do NOT merge/tag (owner gates).
- [ ] Parity: this is a Python-master change; the PHP/Ruby/Node Frond engines have the
      same re-scan shape — mirror AFTER master proven (separate task; Node waits for the
      executeMany worker to clear that tree).

## Constraints
- No mocks. Real render, real pytest. feedback_no_mock_testing, feedback_independent_verification.
- Behaviour-identical: the optimization must not change a single rendered byte. Prove via the suite.
- Carbonah at every step (feedback_carbonah): measure before AND after, report both.
- Python is master; mirror the proven design to PHP/Ruby/Node after.

## Status: In Progress (Python master)
