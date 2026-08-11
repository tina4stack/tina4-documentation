# Feature 55: Frond functions

## Identity and status

- Matrix identity: 55 - Frond functions (callable globals: `{{ range(1,10) }}`, `{{ dump(x) }}`,
  `{{ form_token() }}`)
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language Frond source. A "function" is a callable global (no
  separate API); the shared set is small, and `range()` is a PHP-only built-in. Python `frond/engine.py:1594`
  (`46007c1`); PHP `Tina4/Frond.php:3439` (`ab871934`); Ruby `lib/tina4/frond.rb:2821` (`f549923`); Node
  `packages/frond/src/engine.ts:1750` (`1319cf3`).
- Dependencies: the runtime (51, the expression cascade), extensibility (56, `add_global`).
- Dependants: `{{ fn(args) }}` calls.
- Existing ADRs: none dedicated.

- Catalog phase: Frond

## Why this feature exists

A template can call a function (`{{ range(1,10) }}`). In Frond a function is just a CALLABLE registered as a
global and invoked through the expression cascade - there is no separate function API. The audit question is
which built-in functions exist. The shared set is `form_token*`/`dump`; `range()` diverges (PHP only).

## Existing implementation evidence

Measured, all four:

- Functions == CALLABLE GLOBALS: `add_global(name, callable)` registers a function; the globals map is merged
  into the render context, and the expression cascade detects `name(args)` via `FUNC_CALL_RE`
  (`^([\w.]+)\s*\((.*)?\)$`), evaluates the args, and invokes the callable. No distinct function API in any
  language.
- Shared built-in function globals in all four: `form_token()`, `formTokenValue()`, `form_token_value()`,
  `dump()`.
- DIVERGENCES: `range(a, b[, step])` is a HARDCODED built-in in PHP ONLY (`Frond.php:2330`) - Python/Ruby/Node
  register no `range` global, so `{{ range(1, 10) }}` works in PHP and resolves to null/empty in the other
  three. The camelCase `formToken()` global is PHP + Node only (Python/Ruby have `form_token`/`formTokenValue`/
  `form_token_value`/`dump` but not `formToken`). Dotted `obj.method(...)` call resolution is present in
  Python/PHP/Node but FLAT-only in Ruby (`eval_function_call` does `context[fn_name]` only, `frond.rb:1587`).

## Public surface contract

`{{ fn(args) }}` calls a callable global; `add_global` registers a custom function. The built-in function
vocabulary should be shared (it mostly is, except `range` and the camelCase form-token global).

## Inputs and outputs

- Input: a function name + args. Output: the call result.

## Lifecycle and operation graph

1. The cascade detects `name(args)`. 2. Evaluate the args. 3. Look up the callable in globals (then a var
resolve). 4. Invoke it.

## Configuration and precedence

- None. Custom globals shadow built-ins.

## Failures, side effects and security

- An unresolved function call resolves to null/empty (not an error) - so `{{ range(1,10) }}` silently produces
  nothing in py/ruby/node. No security surface (globals are app-registered). See the register.

## Wire and persistence contract

The call result. No persisted state.

## Providers and substitutability

A future runtime must expose functions as callable globals, share the built-in set (incl. `range`), and
resolve dotted `obj.method()` calls.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| FUNC-RANGE-PHP-ONLY | `range(a, b[, step])` is a HARDCODED built-in in PHP ONLY (`Frond.php:2330`); Python/Ruby/Node register no `range` global, so `{{ range(1, 10) }}` works in PHP and silently resolves to null/empty in the other three. The single largest function-vocabulary divergence. | Add `range` (and any agreed built-in functions) as a global in Python/Ruby/Node, or document it PHP-only; gate the shared set. |
| FUNC-FORMTOKEN-CAMEL-GAP | The camelCase `formToken()` global is PHP + Node only; Python/Ruby register `form_token`/`formTokenValue`/`form_token_value`/`dump` but NOT `formToken`. So `{{ formToken() }}` returns the hidden input in PHP/Node and is an unresolved call (null/empty) in Python/Ruby. Mirrors the filter alias gap (52). | Register the same form-token global aliases across the four (or standardise on snake_case). |
| FUNC-RUBY-DOTTED-CALL | Dotted `obj.method(...)` call resolution is present in Python/PHP/Node but FLAT-only in Ruby (`eval_function_call` does `context[fn_name]` only, `frond.rb:1587`; Ruby routes dotted MACRO keys separately). So a template calling `obj.method(...)` on a plain object works in three languages and not Ruby. | Add dotted object-method call resolution to Ruby's `eval_function_call`. |
| FUNC-NO-SEPARATE-API | POSITIVE (do NOT re-flag): functions are callable globals via `add_global` in all four - no separate function API is needed, and the `FUNC_CALL_RE` detection is uniform. | Keep; document that functions == callable globals. |

## Owner decisions

- FUNC-DEC-01 (proposed): decide `range()` (FUNC-RANGE-PHP-ONLY) - add it as a global in Python/Ruby/Node, or
  document PHP-only - and agree the shared built-in function set; gate it.
- FUNC-DEC-02 (proposed): reconcile the camelCase `formToken` global (FUNC-FORMTOKEN-CAMEL-GAP) and add Ruby's
  dotted-call resolution (FUNC-RUBY-DOTTED-CALL).

## Proposed conformance fixture

A shared fixture: `{{ dump(x) }}` and `{{ form_token() }}` render in all four; `{{ range(1,3) }}` produces the
same result across the four (after FUNC-DEC-01); `{{ obj.method(1) }}` resolves in all four (catches
FUNC-RUBY-DOTTED-CALL); a custom `add_global` callable is invokable.

## Integration map

- Consumers: `{{ fn(args) }}` calls. Composes: the runtime (51, the cascade), extensibility (56,
  `add_global`). Related: the form-token helpers (37/52).

## Breaking changes and migration

- Adding `range`/`formToken` globals to the languages that lack them is additive. Adding Ruby's dotted-call
  resolution is additive.

## Porting capsule

Expose functions as CALLABLE GLOBALS (register via `add_global`, invoke through the expression cascade's
`FUNC_CALL_RE` - no separate function API). Ship the agreed shared built-in set (`form_token*`, `dump`, and
`range` - the PHP-only gap) with consistent names (snake vs camel), and resolve dotted `obj.method(...)` calls
(the Ruby flat-only gap). An unresolved call should follow the runtime's error rule (feature 51), not silently
vanish where a built-in was expected.

## Audit closure checklist

- [x] Boundary and public surface complete (callable globals x four).
- [x] Lifecycle and producer/consumer edges complete (detect -> eval args -> invoke).
- [x] Configuration, failure and security rules complete.
- [x] Wire (call result) and provider contracts complete.
- [x] Four-language behaviour recorded (shared globals; range PHP-only; Ruby dotted-call gap).
- [x] Owner ambiguities decided (FUNC-DEC-01 range/set, FUNC-DEC-02 formToken/dotted).
- [x] Conformance fixture (function parity + dotted call) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
