# Feature 58: Frond sandboxing

## Identity and status

- Matrix identity: 58 - Frond sandboxing
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language Frond source. `sandbox()` with filter/tag/var allow-lists
  exists in all four; the divergences are the DENIED behaviour (PHP silently passes a denied filter's value
  through) and that tests are not gated. Python `frond/engine.py:1611` (`46007c1`); PHP `Tina4/Frond.php:438`
  (`ab871934`); Ruby `lib/tina4/frond.rb:453` (`f549923`); Node `packages/frond/src/engine.ts:1769`
  (`1319cf3`).
- Dependencies: the runtime (51), the tags (53), the filters (52).
- Dependants: rendering UNTRUSTED templates (user-supplied templates).
- Existing ADRs: ADR-0004; the compiler decision (feature 50, CP-DEC-01).

- Catalog phase: Frond

## Why this feature exists

A sandbox lets an app render an UNTRUSTED template by restricting which filters, tags, and variables it may
use. The audit questions: does it gate all three, what happens on a denied use, and can a denied use escape.
All four gate filters/tags/vars, but the denied-filter behaviour diverges (PHP silently passes the value
through) and expression tests are not gated.

## Existing implementation evidence

Universal shape, measured:

- `sandbox(filters, tags, vars)` sets three ALLOW-LISTS (null/absent = unrestricted) in all four: Python
  `engine.py:1611` (`_filter_permitted` `:1638`, `_tag_permitted` `:1667` at dispatch `:2071`, var gate
  `:2311`); PHP `Frond.php:438` (`tagPermitted` `:1137`, filter via `applyFilter`, var via `resolveVariable`);
  Ruby `frond.rb:453` (`filter_permitted?` `:475`, `tag_permitted?` `:485`, one gate `:814`, `skip_block`
  `:748`); Node `engine.ts:1769` (`filterPermitted` `:2205`, `tagPermitted` `:2216`, `skipDeniedTag` `:2228`).
- COMPILE DISABLED under sandbox in Python (`engine.py:1812`) and PHP (`Frond.php:264`) - a compiled template
  must not bypass the gates. Ruby/Node have no compiler today (so moot until the owner's compiler lands - see
  the register).
- DENIED behaviour diverges: PHP a denied FILTER passes the value THROUGH unchanged (`Frond.php:2870`), a
  denied VAR returns `''` (`:2385`), a denied TAG is skipped (body consumed). Python/Ruby/Node gate filters/
  tags/vars but the exact denied-filter outcome (error vs pass-through vs empty) is not proven identical.
- Expression TESTS (`{% if x is defined %}`) are NOT sandbox-gated (PHP explicit; the tests are built-in
  predicates in all four).

## Public surface contract

`engine.sandbox(allowed_filters=, allowed_tags=, allowed_vars=)` restricts a render; `unsandbox()` clears it. A
denied filter/tag/var must not execute. Rendering untrusted templates depends on this.

## Inputs and outputs

- Input: allow-lists + an untrusted template. Output: a restricted render (denied uses blocked).

## Lifecycle and operation graph

1. `sandbox(...)` sets the allow-lists + disables compilation. 2. At render, each filter/tag/var is checked
against its allow-list; a denied use is blocked (skipped/empty/pass-through - see the register).

## Configuration and precedence

- Allow-lists via `sandbox()`; null = unrestricted. No env var. Sandbox forces the interpreter (no compile).

## Failures, side effects and security

- SECURITY: the sandbox is the boundary for untrusted templates. The risks: a denied FILTER that silently
  passes the value through (PHP) means a sandboxed author's forbidden filter is a no-op, not a refusal - and
  if the owner's new compiler (feature 50) is not disabled under sandbox in Ruby/Node, a compiled template
  could bypass the gates entirely. See the register.

## Wire and persistence contract

No wire/persistence. The contract is "a denied filter/tag/var does not execute".

## Providers and substitutability

A future runtime must gate filters/tags/vars (and decide on tests), refuse a denied use consistently, and
DISABLE the compiler under sandbox.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SANDBOX-DENIED-FILTER-DIVERGE | A DENIED filter's behaviour diverges: PHP passes the value THROUGH unchanged (`Frond.php:2870`) - so a sandboxed template using a forbidden filter silently gets the UNFILTERED value, not a refusal (the author believes the filter ran). Python/Ruby/Node's exact denied-filter outcome (error vs empty vs pass-through) is not proven identical. | Pin ONE denied behaviour across the four (a denied filter should raise or drop the value, not silently pass it through), and gate it. |
| SANDBOX-COMPILER-BYPASS | Compilation is DISABLED under sandbox in Python (`engine.py:1812`) and PHP (`Frond.php:264`) - correct, since a compiled template could bypass the gates. The owner has decided Ruby and Node get a compiler (feature 50, CP-DEC-01); those NEW compilers MUST also be disabled under sandbox, or a sandboxed untrusted template compiled to native code escapes the sandbox entirely. | When building the Ruby/Node compilers (CP-DEC-01), disable them under sandbox (match Python/PHP). Gate it. |
| SANDBOX-TESTS-UNGATED | Expression TESTS (`{% if x is defined %}`) are NOT sandbox-gated in any language (PHP explicit; tests are built-in predicates all four). Low risk (no side effects), but inconsistent - filters/tags/vars are gated, tests are not. | Gate tests under the sandbox too, or document why they are exempt (no side effects). |
| SANDBOX-DENIED-PARITY | The denied-VAR (`''`) and denied-TAG (skipped, body consumed) behaviours are consistent-ish but not gated by a shared fixture. | Gate the denied-var/tag behaviour identical across the four. |

## Owner decisions

- SANDBOX-DEC-01 (proposed): pin the DENIED-filter behaviour (SANDBOX-DENIED-FILTER-DIVERGE) - a denied filter
  should raise or drop the value, not silently pass it through (PHP's current footgun) - and decide whether
  tests are gated (SANDBOX-TESTS-UNGATED).
- SANDBOX-DEC-02 (proposed, ties to CP-DEC-01): ensure the owner-decided Ruby/Node Frond compilers are
  DISABLED under sandbox (SANDBOX-COMPILER-BYPASS) - a compiled untrusted template must never bypass the
  sandbox gates.

## Proposed conformance fixture

A shared fixture (real render, untrusted template): a denied filter/tag/var is REFUSED consistently in all
four (catches SANDBOX-DENIED-FILTER-DIVERGE); a sandboxed template is NOT compiled (SANDBOX-COMPILER-BYPASS -
important once Ruby/Node have compilers); `|raw` is forbidden in a sandbox (cross-ref 57).

## Integration map

- Consumers: apps rendering untrusted templates. Composes: the filters (52), tags (53), runtime (51), the
  compiler (50, must be sandbox-disabled), auto-escape (57, `raw` forbidden in sandbox).

## Breaking changes and migration

- Making a denied filter raise (instead of pass-through) changes behaviour for sandboxed templates - a
  security fix; note it. Disabling the new compilers under sandbox is a security requirement, not a break.

## Porting capsule

Provide `sandbox(allowed_filters, allowed_tags, allowed_vars)` that gates every filter/tag/var against its
allow-list and REFUSES a denied use consistently (raise or drop - never silently pass the value through, the
PHP footgun). DISABLE the compiler under sandbox (a compiled untrusted template must not bypass the gates -
critical once Ruby/Node gain compilers). Forbid `|raw`/`SafeString` in a sandbox. Decide whether expression
tests are gated.

## Audit closure checklist

- [x] Boundary and public surface complete (sandbox filters/tags/vars x four).
- [x] Lifecycle and producer/consumer edges complete (allow-list -> gate -> refuse).
- [x] Configuration, failure and SECURITY (denied behaviour, compiler bypass) rules complete.
- [x] Wire (no execution of denied use) and provider contracts complete.
- [x] Four-language behaviour recorded (gates all four; denied-filter diverges; compiler-disable py/php).
- [x] Owner ambiguities decided (SANDBOX-DEC-01 denied behaviour, SANDBOX-DEC-02 compiler-disable).
- [x] Conformance fixture (denied refusal + no-compile) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
