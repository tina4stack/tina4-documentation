# Native metrics engine in the tina4 Rust CLI (ADR-0002)

Goal: make `tina4 metrics` a NATIVE conductor command that scans SOURCE directly,
language-agnostic, with NO Tina4 project and NO running framework required —
retiring the forward-to-framework path (and its holes: no frontend coverage,
needs a running framework, Node scanned the built bundle not source).

Repo: tina4stack/tina4 (Rust CLI, crate `tina4`). Branch: `feature/metrics-engine`
off `main`. Built in a linked git worktree because the primary tree had another
session's uncommitted `feature/supervisor-mcp` work (agent.rs + an untracked plan
file) — a worktree keeps the branch in the same `.git` without disturbing that WIP.

## Scope
- [x] Read the Python master reference `tina4-python/tina4_python/dev_admin/metrics.py`
- [x] Add tree-sitter + python/php/ruby/typescript grammars (owner-decided parser)
- [x] New `src/metrics.rs`; wire a native `Metrics` variant into the command enum
      in `src/main.rs` (no longer falls into `Commands::External`)
- [x] Per file: LOC, cyclomatic complexity (McCabe), maintainability index
      (Radon/MS, clamped [0,100]), efferent coupling (imports), function count
- [x] Offenders + severities matching the existing kinds/thresholds
- [x] Flags: `--path DIR|FILE`, `--fail-on warn|error`, `--json`, `--top N`
- [x] Human table + JSON shape match the existing `tina4 metrics` output
- [x] PARITY TEST vs real metrics.py (no mocks) — exact match on real files
- [x] Unit tests (CC, offender rules, fail-on gate, lang detection, multi-language)
- [x] `cargo build` / `cargo test` (x2) / `cargo clippy` all green

## Formula parity (the critical requirement)
Replicated metrics.py EXACTLY so today's `--fail-on` thresholds carry over:
- CC = 1 + decision points. Python set (if/elif/for/while/except/assert/ternary/
  bool-op/comprehension-for/comprehension-if) mapped to the exact tree-sitter node
  kinds. Chained `a and b and c` nests in tree-sitter to the same count ast's
  `len(values)-1` yields; comprehension `for`/`if` clauses counted individually.
- Halstead volume for Python replicates ast.Name/ast.Constant precisely: operand
  identifiers exclude attribute tails, decl names, params, kwarg names, imports,
  global/nonlocal; operators mapped 1:1 (incl. folding `is not`/`not in`, and
  flattening chained same-operator bool-ops for the operator count). Non-Python
  Halstead uses a generic tree-sitter operator/operand classifier (no reference to
  match — MI stays sensible and consistent).
- MI = max(0, min(100, (171 - 5.2 ln V - 0.23 CC - 16.2 ln LOC) * 100/171)); LOC =
  non-blank, non-`#` lines (Python rule byte-for-byte).
- Offender rules mirror metrics.py: complexity CC>10 (warn) / >20 (error), capped
  to the top-15 functions (a faithful port of metrics.py's `[:15]` quirk — flagged
  below); large_file LOC>500 (warn); too_many_functions >20 (warn);
  low_maintainability MI<40 (warn) / <20 (error); untested (info).

### Parity-test result (REAL metrics.py, no mocks)
`metrics::tests::parity_matches_python_master` copies each fixture into a temp dir,
runs the actual `metrics.py` full_analysis via tina4-python's venv, and compares:

| fixture (real tina4-python source) | LOC | total CC | funcs | MI | avg CC |
|---|---|---|---|---|---|
| container/__init__.py — metrics.py | 81 | 14 | 7 | 39.4 | 2.0 |
| container/__init__.py — Rust       | 81 | 14 | 7 | 39.4 | 2.0 |
| dev_admin/metrics.py — metrics.py  | 621 | 181 | 14 | 8.3 | 12.93 |
| dev_admin/metrics.py — Rust        | 621 | 181 | 14 | 8.3 | 12.93 |

Exact match on every metric, incl. MI to the reported 0.1, on both a 104-line and
a 796-line real file. Test tolerance: LOC/CC/functions exact; avg-CC ±0.01; MI ±0.15
(a cross-platform float guard — observed delta 0.0).

## Fixes-for-free (verified)
- Scans real SOURCE, not a built bundle (the Node bundle-scan defect) — it reads
  `.ts`/`.py`/… files directly.
- Works on a frontend: `tina4 metrics --path <tina4-js>/src` → 29 files, 275
  functions, avg MI 47.8, 43 offenders (top: persist() CC 43, startCall() CC 38).
- Works on arbitrary non-framework code with no project (single-file `--path`,
  `/tmp/demo.php`, etc.).

## Languages honestly assessed
- Python: formula parity PROVEN exact against metrics.py.
- PHP / Ruby / TypeScript+JS: same CC McCabe definition applied via each grammar;
  MI uses a generic (non-ast) Halstead. There is no per-language reference to match
  (Python is the only master), so CC/MI for these are internally consistent and
  reasonable but NOT parity-locked to a prior implementation. TS counts arrow
  functions as functions (tina4-js is arrow-heavy) so their complexity is attributed.

## Binary size (owner cares)
- Baseline (main, release): 3,899,904 bytes (~3.72 MB)
- With 4 grammars + tree-sitter (release, opt-level=z, LTO, strip): 9,038,544 bytes (~8.62 MB)
- Delta: +5,138,640 bytes (~+4.9 MB, ~2.3x). Dominated by the C parsers; the
  tree-sitter-typescript crate compiles both TS and TSX (we use only TSX) and
  tree-sitter-php both PHP and PHP-only — no cargo feature to drop the unused half.

## Out of scope (follow-up, not done here)
- Wiring the 4 frameworks' dev-admin bubble-chart / MCP `metrics` tools to call this
  CLI's `--json`, and retiring the 4 per-framework metrics modules (ADR-0002 shape).
- The framework CLIs still expose their own `metrics`; the native one shadows it
  (in dispatch and in `--help`).

## Flag / quirk to surface to the owner
- The `~15` complexity threshold in the task brief was approximate; the code uses
  metrics.py's real thresholds (CC>10 warn, >20 error) so `--fail-on` is unchanged.
- Ported metrics.py's `most_complex_functions[:15]` cap faithfully: only the 15
  most-complex functions can become `complexity` offenders. This is a latent
  metrics.py limitation (a 16th CC-30 function is silently omitted) — replicated for
  parity, worth fixing in BOTH once confirmed with the owner.

## Status: DONE (engine only). Committed on feature/metrics-engine. Not merged, not tagged.
