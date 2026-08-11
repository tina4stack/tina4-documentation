# Feature 51: Frond runtime

## Identity and status

- Matrix identity: 51 - Frond runtime (expression evaluation + render)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language Frond source (correcting a prior-session doc claiming
  "Node shows an undefined value INLINE (not dropped)" - FALSE; a genuinely undefined variable renders EMPTY
  in all four). Python `frond/engine.py:2052` (`46007c1`); PHP `Tina4/Frond.php:1689` (`ab871934`); Ruby
  `lib/tina4/frond.rb:1341` (`f549923`); Node `packages/frond/src/engine.ts:683` (`1319cf3`).
- Dependencies: the parser/AST (49) or token list; the compiler (50) front-runs the interpreter where present.
- Dependants: every rendered template; filters (52), tags (53), functions (55).
- Existing ADRs: ADR-0004; the 72/72 expression-parity corpus.

- Catalog phase: Frond

## Why this feature exists

The runtime evaluates expressions and walks the template to produce output. The audit questions: how does an
undefined variable render, does a loop variable leak, and what happens when an expression raises. Undefined ->
empty and loop-scope isolation are already at parity in all four; the runtime-error rule is NOT pinned.

## Existing implementation evidence

Universal shape, measured:

- Expression evaluation is a DETECTOR CASCADE in all four (`eval_expr`/`evaluateExpression`/`evalExpr`):
  literal -> collection -> parens -> ternary -> inline-if -> null-coalesce -> concat -> comparison/logical ->
  arithmetic -> filter-pipe -> function/macro -> variable-resolve. (Python `engine.py:820`; PHP
  `Frond.php:1689`; Ruby `frond.rb:1351`; Node `engine.ts:778`.) The compiled path (Python/PHP) routes every
  hole back through this SAME cascade, so compiled and interpreted values match.
- UNDEFINED VARIABLE -> EMPTY string in ALL FOUR: Python `_to_output(None)->""` (`engine.py:2026`); PHP
  `resolveVariable->''` (`Frond.php:2397`); Ruby `nil->""` (`frond.rb:797`); Node `null->""`
  (`engine.ts:2093`). The prior doc's "Node shows INLINE" is FALSE - only a DEFINED non-string value
  (function/object) is `String()`-rendered inline; a truly undefined var is dropped to empty.
- LOOP/MACRO SCOPE is ISOLATED in all four (no leak to the parent): Python copy-on-write `_LoopContext`
  (`engine.py:45`); PHP overlay-on-`$data` with save/restore (`Frond.php:1396-1431`); Ruby COW `LoopContext`
  (`frond.rb:210`); Node `Proxy` overlay (`engine.ts:2737`).
- `render` (file) vs `render_string` (source) are distinct entry points in all four; both build
  `{**globals, **data}`. Dotted lookup + indexing/slicing/method calls supported in all four.
- RUNTIME-ERROR handling is MIXED and not pinned (see the register).

## Public surface contract

`render(template, data)` / `render_string(source, data)` -> string. Undefined -> empty; loop vars scoped;
expression semantics per the shared corpus. The error behaviour is not yet one rule.

## Inputs and outputs

- Input: a template + a data dict. Output: the rendered string.

## Lifecycle and operation graph

1. (Compiled path, Python/PHP) run the compiled callable. 2. Else walk the AST/tokens, evaluating each
expression via the cascade. 3. Undefined -> empty; loop vars in an isolated overlay.

## Configuration and precedence

- Globals merged under data. Auto-escape on (feature 57). No runtime env var.

## Failures, side effects and security

- A benign lookup miss (missing key/index/attr) swallows to empty in all four. But a METHOD that itself raises
  is not uniformly guarded (Python propagates it uncaught, `engine.py:347`); comparisons rescue to false in
  Ruby; arithmetic guards to null in Node. So a template author cannot predict raise-vs-empty. No runtime
  error is positioned. See the register.

## Wire and persistence contract

No wire format; output is the rendered string.

## Providers and substitutability

A future runtime must render undefined as empty, isolate loop scope, follow the shared expression corpus, and
apply ONE pinned (positioned) runtime-error rule.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| RT-UNDEFINED-EMPTY | RESOLVES the prior unverified cell AND corrects a false claim: an undefined variable renders EMPTY in ALL FOUR (`engine.py:2026`, `Frond.php:2397`, `frond.rb:797`, `engine.ts:2093`). The prior doc's "Node shows INLINE (not dropped)" is FALSE - only a DEFINED function/object is `String()`-rendered; a genuinely undefined var is empty. So undefined-handling is already at PARITY. | Ratify undefined -> empty as the contract and gate it (it is already true in all four). |
| RT-ERROR-UNPINNED | UNIVERSAL: the runtime-error rule is MIXED and not pinned - benign lookup misses swallow to empty, but a raising method call propagates uncaught in Python (`engine.py:347`), comparisons rescue to false in Ruby, arithmetic guards to null in Node. No single "raise vs empty" rule, and none is positioned. The prior unverified resolves to "inconsistent across the four". | Pin ONE runtime-error rule (swallow-to-empty, or a POSITIONED runtime error) for a failed lookup/method-call, consistent across the four (positioning depends on LEX-DEC-01). |
| RT-SCOPE-ISOLATED | POSITIVE (do NOT re-flag): loop/macro scope is isolated in all four (COW/overlay/Proxy) - a loop var does not leak to the parent. Not gated by a shared fixture. | Gate scope isolation with a fixture; keep the isolation. |

## Owner decisions

- RT-DEC-01 (proposed): pin the runtime-error rule (RT-ERROR-UNPINNED) across the four, and positioned once
  the lexer carries positions (LEX-DEC-01). Ratify undefined -> empty (RT-UNDEFINED-EMPTY) - already at parity.
- RT-DEC-02 (proposed): gate scope isolation, undefined-empty, and the error rule with the shared corpus (the
  expression corpus is already 72/72; extend it to these runtime behaviours).

## Proposed conformance fixture

A shared fixture (real render): `{{ missing }}` renders empty in all four; a loop var does not leak to the
parent scope; a failing method call follows the ONE pinned rule (RT-DEC-01) identically; the expression corpus
renders identically compiled vs interpreted (with feature 50).

## Integration map

- Consumers: every render. Composes: the parser/AST (49), the compiler (50), filters/tags/functions
  (52/53/55).

## Breaking changes and migration

- Ratifying undefined -> empty changes nothing (already true). Pinning the error rule changes behaviour for
  raising method calls - a correctness/consistency fix, note it.

## Porting capsule

Evaluate expressions with the shared detector cascade (matching the 72/72 corpus), render an undefined
variable as EMPTY (not inline), isolate loop/macro scope so a loop var never leaks to the parent (a
copy-on-write overlay), and apply ONE pinned runtime-error rule for a failed lookup/method-call (positioned,
once the lexer carries positions) - not the current mix of swallow-here, raise-there, rescue-to-false
elsewhere.

## Audit closure checklist

- [x] Boundary and public surface complete (cascade + render x four).
- [x] Lifecycle and producer/consumer edges complete (evaluate -> render).
- [x] Configuration, failure (unpinned error rule) and security rules complete.
- [x] Wire (rendered string) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (undefined->empty all four; scope isolated; error unpinned).
- [x] Owner ambiguities decided (RT-DEC-01 pin error rule, RT-DEC-02 gate).
- [x] Conformance fixture (undefined + scope + error) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
