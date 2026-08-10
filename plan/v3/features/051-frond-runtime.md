# Feature 051: Frond runtime

## Identity and status

- Matrix identity: 51 - Frond runtime
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the render/resolve path in each
  engine). No framework code changed.
- Dependencies: Feature 50 (the compiled template/AST), Feature 52 filters, Feature 57 escaping,
  Feature 58 sandboxing, Feature 59 caching (all applied here but owned elsewhere)
- Dependants: every Frond render; `{% live %}` server-render; the compiled-vs-interpreted
  byte-identity invariant (Feature 50)
- Existing ADRs: ADR-0009 (removable Frond folder)
- Shared fixtures: `frond_expression_corpus.txt` (82 cases) plus a render fixture this audit adds
- Catalog phase: Frond template engine

## Why this feature exists

The runtime executes a compiled Frond template against the application context and produces the
rendered bytes - resolving `{{ user.name }}`, running a `{% for %}` scope, calling a macro,
resolving a block override - the same way in all four languages, so the same template and context
render the same output.

## Boundary

This feature owns context lookup (dotted resolution, indexing, slicing, method calls), the loop
and macro SCOPES, template-inheritance state (which block overrides which), macro and block calls,
runtime errors, and the rendered bytes. Filters (Feature 52), auto-escaping (Feature 57),
sandboxing (Feature 58) and caching (Feature 59) are applied here but OWNED by those features.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Context lookup | `_resolve(expr, context)` dotted | dotted | dotted | dotted |
| Indexing/slicing/method calls | yes | yes | yes | yes |
| Loop scope | copy-on-write overlay (perf) | scope | scope | scope |
| Undefined variable | (to confirm - empty?) | (to confirm) | (to confirm) | shown INLINE (not dropped) |
| Inheritance state | extends/block | same | same | same |
| Macro calls | args/defaults | same | aliased macro empty (Feature 50 bug) | same |
| Runtime errors | (to confirm) | (to confirm) | (to confirm) | (to confirm) |
| Render output | bytes | bytes | bytes | bytes |

The runtime resolves a dotted expression against the context (`_resolve`), supporting indexing,
slicing and method calls, and pushes a SCOPE for a loop (Python uses a copy-on-write overlay so a
loop iteration does not clone the whole parent context). The sharpest divergence is UNDEFINED
handling: Node shows an undefined/Symbol/function value INLINE rather than dropping it, so the
runtime's answer to "what does `{{ missing }}` render" must be pinned - empty, a marker, or a
raised error - and made identical, because this is user-visible on every template. Macro calls and
the aliased-macro bug (Feature 50) live here at call time.

## Public surface contract

Behind the unchanged `Frond` entry point, the runtime renders a compiled template against a
context: it resolves `{{ expr }}` (dotted lookup, indexing, slicing, method calls), runs `{% for %}`
and `{% if %}` with correctly-scoped loop variables, resolves `{% extends %}`/`{% block %}`
overrides, and calls macros with their arguments and defaults. An undefined variable resolves to
the pinned value (below); a runtime error (a bad method call) is handled by the pinned rule.

## Inputs and outputs

- Input: the compiled template (Feature 50) and the application context (a map of variables).
- Output: the rendered bytes, byte-identical across the four for the same template and context.
- A loop variable is scoped to its loop and does not leak to the parent context.
- An undefined variable resolves to ONE pinned representation (empty, or a marker) in all four.
- A macro call receives its arguments and defaults; an aliased macro renders its body (not empty).

## Lifecycle and operation graph

1. The runtime walks the compiled template (or calls the compiled function, Feature 50).
2. For each `{{ expr }}`, it resolves the expression against the current scope (dotted lookup,
   indexing, slicing, method call), then applies filters (Feature 52) and escaping (Feature 57).
3. A `{% for %}` pushes a scope with the loop variable(s) (copy-on-write), renders the body per
   item, then pops the scope.
4. `{% extends %}`/`{% block %}` resolve the block override chain; a macro call binds arguments
   and defaults and renders the macro body.
5. An undefined variable or a runtime error is handled by the pinned rule; the rendered bytes are
   returned.

## Configuration and precedence

- The undefined-variable rule is fixed (one representation across the four), not per-template.
- A loop or macro scope shadows the parent for its duration and is popped after; it never leaks.
- Filters/escaping/sandboxing/caching are applied through their features; the runtime invokes
  them in a fixed order (resolve, filter, escape).

## Failures, side effects and security

- UNDEFINED: `{{ missing }}` must resolve to ONE pinned value in all four; Node showing it inline
  while another renders empty is a visible divergence and, if the marker echoes attacker input, a
  minor injection surface. Pin it (recommend empty, matching Jinja2's default Undefined).
- SCOPE LEAK: a loop or macro variable must not leak to the parent context; a leak would corrupt a
  later render or expose one iteration's value to another.
- A runtime error (a method that raises, a non-callable called) is handled by the pinned rule
  (raise with position, or render empty) - never a partial or silently-wrong template.
- The runtime applies escaping (Feature 57) on output; it must not be bypassable by a resolution
  path (an attribute that returns pre-escaped or raw content).
- Byte-identity (Feature 50): the runtime's output must match the compiled path exactly.

## Wire and persistence contract

There is no persistence; the output is the rendered bytes. The contract is that the same compiled
template and context render the same bytes across the four, and identically between the compiled
and interpreted paths (Feature 50).

## Providers and substitutability

The runtime is engine-agnostic over the compiled template and context. A future runtime resolves
the same lookups, scopes, inheritance and macro calls with the same undefined rule and the same
byte output.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RT-01 | Undefined-variable handling diverges (Node shows it inline; others to confirm). | Pin ONE undefined representation (recommend empty) in all four; gate `{{ missing }}`. |
| RT-02 | Context lookup (dotted, indexing, slicing, method calls) parity is corpus-driven but not gated as a render fixture. | Gate the resolution corpus rendering identically in all four. |
| RT-03 | Loop/macro scope isolation (no leak to the parent) is not gated. | Gate that a loop/macro variable does not leak to the parent context in all four. |
| RT-04 | Inheritance/block override resolution is not gated. | Gate `{% extends %}`/`{% block %}` override rendering in all four. |
| RT-05 | Macro calls (args/defaults, aliased macro) are not gated; the aliased-macro bug (Feature 50) lives here. | Gate macro invocation and aliased-macro body rendering in all four. |
| RT-06 | Runtime-error handling (raise vs empty) is not pinned or gated. | Pin the rule and gate a raising method call and a non-callable call in all four. |
| RT-07 | No render-level fixture (the corpus is expression-level). | Add a render fixture over templates+contexts. |

## Owner decisions

Proposed for owner ratification:

1. An undefined variable resolves to ONE pinned representation in all four (recommend empty,
   matching Jinja2's default Undefined); Node stops showing it inline.
2. Loop and macro scopes are isolated: a scoped variable never leaks to the parent context.
3. Macro calls bind arguments and defaults and render the macro body (including an aliased
   macro); the silently-empty render is a defect.
4. A runtime error is handled by one pinned rule (recommend a positioned raise for a real error,
   empty for a benign undefined) in all four.
5. The runtime applies resolve -> filter -> escape in a fixed order, and its output is
   byte-identical to the compiled path (Feature 50).

## Proposed conformance fixture

Add a render fixture with stable ids for: `{{ user.name }}` dotted resolution, indexing, slicing
and a method call; `{{ missing }}` rendering the pinned undefined value; a `{% for %}` loop
variable NOT leaking to the parent; `{% extends %}`/`{% block %}` override rendering; a macro
call with defaults and an aliased macro rendering its body; a raising method call handled by the
pinned rule; and byte-identity to the compiled path. Every case renders a real template with a
real context and compares bytes; a pure render needs no service and runs in all four runners.

## Integration map

- Feature 50 supplies the compiled template; Feature 52 (filters), 57 (escaping) and 58
  (sandboxing) are applied here; Feature 59 caches the render.
- `{% live %}` blocks re-render through this runtime on the server.
- Central fixtures, four runners, the CI matrix and the Frond docs update together.

## Breaking changes and migration

- Pinning the undefined representation changes what one framework renders for `{{ missing }}`
  (Node's inline value becomes empty); a `Breaking:` note, and a template relying on the inline
  value is itself a latent bug.
- Fixing the aliased-macro-empty render (Feature 50) is a correctness fix.

## Implementation backlog

1. Add the render fixture and wire four runners over templates+contexts.
2. Pin and gate the undefined rule (RT-01) and scope isolation (RT-03) in all four.
3. Gate the resolution corpus (RT-02), inheritance (RT-04), macro calls (RT-05) and runtime
   errors (RT-06).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a runtime that renders a compiled template against a context: resolve `{{ expr }}`
(dotted lookup, indexing, slicing, method calls), push copy-on-write scopes for loops and macros
(no leak to the parent), resolve `{% extends %}`/`{% block %}` overrides, and call macros with
arguments and defaults (aliased macros render their body). Resolve an undefined variable to the
pinned empty value, handle a runtime error by the pinned rule, and apply resolve -> filter ->
escape in order. Keep the output byte-identical to the compiled path. Prove the port with the
render fixture.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (RT-01..07).
- [x] Owner ambiguities recorded (5 proposed; the undefined rule and scope isolation are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
