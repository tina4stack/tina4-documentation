# Feature 055: Frond functions

## Identity and status

- Matrix identity: 55 - Frond functions
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the globals registry and built-in
  callables in each engine). No framework code changed.
- Dependencies: Feature 49 parser (parses a call), Feature 51 runtime (invokes it), Feature 56
  extensibility (`add_global` registers custom functions)
- Dependants: any template calling `{{ range(5) }}`, `{{ dict(...) }}`, etc.
- Existing ADRs: ADR-0005 (Frond tracks Twig/Jinja2); the data-not-host-casing rule (Feature 52)
- Shared fixtures: `frond_function_corpus` is required
- Catalog phase: Frond template engine

## Why this feature exists

A template calls a function from the template namespace - `{{ range(5) }}`, `{{ dict(a=1) }}`,
`{{ cycler(...) }}` - to build values inline. Because the function names live in a portable
template file, the SAME callable vocabulary must exist and behave identically in all four
languages.

## Boundary

This feature owns the built-in function/global SET (callables available in the template
namespace) and the way a template calls them. It DELEGATES call parsing to Feature 49, invocation
to Feature 51, and the registration mechanics (`add_global`) to Feature 56. A function NAME is
data (snake_case, identical across four); it is distinct from a filter (Feature 52) and a test
(Feature 54).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Registered as | globals (`_globals`/`_class_globals`) | globals | globals | globals |
| Registration API | `add_global` (NOT `add_function`) | `addGlobal` | `add_global` | `addGlobal` |
| Built-in callables | `range`, `dict`, and the Jinja2 set | same | same | same |
| Called as | `{{ range(5) }}` | same | same | same |
| Names | data (snake_case) | data | data | data |

Frond functions are the callable GLOBALS: there is no separate `add_function`; a function is a
global registered via `add_global` and invoked with a call in the template. The built-ins include
`range` and `dict` (and the Jinja2 callable vocabulary). Like filter and test names, function
names are template data and must be identical across the four; the built-in set should be
enumerated LIVE (the Feature 52 lesson) and pinned so `{{ range(5) }}` renders the same everywhere.

## Public surface contract

The built-in function set (snake_case, identical across four) is callable in any template
(`{{ name(args) }}`), matching the Jinja2 callable vocabulary (`range`, `dict`, `cycler`, and the
rest as enumerated). Custom functions are registered as globals via `add_global(name, fn)`
(Feature 56). An unknown function call is a positioned error.

## Inputs and outputs

- Input: a function name and call arguments in the template.
- Output: the function's return value, used in the surrounding expression.
- A built-in like `range(5)` returns an iterable a `{% for %}` can consume; `dict(a=1)` builds a
  mapping.
- An unknown function name is a positioned error, not a silent empty.

## Lifecycle and operation graph

1. Feature 49 parses `name(args)` into a call node.
2. At render, Feature 51 resolves the name in the globals registry (built-in + class + instance).
3. The function is invoked with its arguments and returns a value.
4. The value feeds the surrounding expression (a `{% for %}` over `range`, an interpolation).

## Configuration and precedence

- The built-in function list is a committed fixture read by all four runners.
- `add_global` registers a callable under a snake_case name; a custom global does not silently
  replace a built-in (Feature 56's boundary).
- There is no per-template function configuration.

## Failures, side effects and security

- An unknown function name is a positioned error, so a template typo is found, not silently
  rendered empty.
- A function may have arguments but should be side-effect-free in a template context; under
  sandboxing (Feature 58) a custom global is subject to the sandbox rules (no arbitrary
  callables).
- A built-in like `range` must bound its size where relevant, so `{{ range(huge) }}` cannot be
  used to exhaust memory (a template-DoS consideration).
- The function namespace must not expose a host callable that a template could use to escape the
  sandbox (Feature 58 owns the enforcement; this feature must not add such a global by default).

## Wire and persistence contract

There is no persistence; the contract is the FUNCTION NAME SET as data (snake_case, identical) and
each function's return for given arguments. A template using `{{ range(5) }}` yields the same
values on every framework. The built-in list is a committed fixture.

## Providers and substitutability

The globals registry is a pure data map from name to callable; a future runtime registers the same
snake_case function names bound to callables with the same behaviour, proven by the function
corpus.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| FN-01 | The built-in function set must be identical across four (names are template data); parity not gated. | Enumerate live and gate the same built-in function set (snake_case) in all four. |
| FN-02 | An unknown function call's behaviour (error vs silent empty) is not pinned. | Pin a positioned error for an unknown function; gate it in all four. |
| FN-03 | Function arguments (positional and keyword, e.g. `dict(a=1)`) parity is not gated. | Gate positional and keyword call arguments in all four. |
| FN-04 | A built-in like `range` with a large argument (template-DoS) is not bounded/gated. | Bound or document `range`-style size limits; gate the behaviour. |
| FN-05 | No shared function fixture exists. | Add `frond_function_corpus`. |

## Owner decisions

Proposed for owner ratification:

1. The built-in function set is snake_case and IDENTICAL in all four (function names are template
   data); the set is enumerated live and pinned to the Jinja2 callable vocabulary (ADR-0005).
2. A function is a callable global registered via `add_global`; there is no separate
   `add_function`. An unknown function call is a positioned error.
3. Functions take positional and keyword arguments as Jinja2 does.
4. A size-taking built-in (`range`) is bounded or documented so a template cannot exhaust memory.
5. The built-in function list is a committed fixture read by all four runners.

## Proposed conformance fixture

Add `frond_function_corpus` with stable ids for: each built-in returning the right value
(`range(5)` iterable, `dict(a=1)` mapping); positional and keyword arguments; an unknown function
raising a positioned error; a size-bounded `range`; and `add_global` registering a working custom
function. Every case renders a real template and compares output/error; a pure evaluation needs no
service and runs in all four runners.

## Integration map

- Feature 49 parses calls; Feature 51 invokes; Feature 56 owns `add_global`; Feature 58 sandboxes
  a custom global.
- The function corpus joins the expression, filter, tag and test corpora in the shared Frond
  fixtures.
- Central fixtures, four runners, the CI matrix and the Frond docs update together.

## Breaking changes and migration

- Pinning the function set and the unknown-function error may change a framework that silently
  returned empty; a `Breaking:` note, and a template relying on the silent empty is a latent bug.
- No new functions beyond the pinned Jinja2 vocabulary (ADR-0005).

## Implementation backlog

1. Add `frond_function_corpus` and wire four runners.
2. Enumerate and gate the built-in function set (FN-01) and the unknown-function error (FN-02).
3. Gate call arguments (FN-03), the size-bound (FN-04) and `add_global`.
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the built-in callable globals (snake_case names identical across four, the Jinja2
vocabulary: `range`, `dict`, `cycler`, and the rest), callable as `{{ name(args) }}` with
positional and keyword arguments. Register custom functions as globals via `add_global` (no
separate `add_function`). An unknown function is a positioned error. Bound a size-taking built-in
against template-DoS, and add no sandbox-escaping global by default. Prove the port against the
function corpus.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (FN-01..05).
- [x] Owner ambiguities recorded (5 proposed; the function-names-are-data rule and add_global).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
