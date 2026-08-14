# Feature 56: Frond extensibility API

## Identity and status

- Matrix identity: 56 - Frond extensibility (add_filter / add_global / add_test)
- Audit state: implemented and lab-proven on `feature/release3.13.100`
- Audit note: the 2026-08-11 audit found that instance registration leaked into the class registry in all
  four frameworks. ADR-0052 resolved the contradiction on 2026-08-14: class calls are process-global and
  instance calls are local. Implemented by Python `ecf66e6`, PHP `f6fb7f23`, Ruby `ad4e696`, and Node
  `e10b830`; Ruby Docs ranking parity followed in `bb1e8d6`.
- Dependencies: the runtime (51).
- Dependants: apps registering custom filters/globals/tests.
- Existing ADRs: ADR-0004, ADR-0052.

- Catalog phase: Frond

## Why this feature exists

Apps extend Frond with custom filters, globals (functions), and tests. The API is callable on the class and
on an instance in all four languages. ADR-0052 now makes the call target define scope: class calls are
process-global; instance calls stay local. Resolution remains a flattened snapshot created at construction.

## Existing implementation evidence

Universal, measured after ADR-0052 implementation:

- `add_filter`/`add_global`/`add_test` (PHP `addFilter`/... via `__call`/`__callStatic`) exist in all four and
  work as BOTH a class method and an instance method (Python `_ClassOrInstanceMethod` descriptor
  `engine.py:1509`; PHP magic methods `Frond.php:390`; Ruby class+instance `frond.rb:401`/`:426`; Node static +
  instance `engine.ts:1670`/`:1791`). POSITIVE.
- An instance registration writes only the instance map in all four. A later instance does not inherit it.
- A class registration writes the class registry. Every instance constructed afterward inherits it.
- Resolution is FLATTENED at construction: the instance seeds `builtins`, then merges the class registry, then
  instance-writes overwrite - a SINGLE map is read at render (not a live instance->class->builtin cascade).
  Consequence: a CLASS-level registration made AFTER an instance exists is invisible to that instance.
- Replacing a built-in is a SILENT overwrite (no warn/error) in all four. A class-level reset
  (`clear_registry`) exists in all four. Functions are callable globals (no separate `functions` API).

## Public surface contract

`add_filter(name, fn)` / `add_global(name, value)` / `add_test(name, fn)`, callable on the class or an
instance. The call target defines scope under ADR-0052.

## Inputs and outputs

- Input: a name + a callable/value. Output: a class registration is available to future instances; an
  instance registration is available only to that instance.

## Lifecycle and operation graph

1. A class call writes the class registry; an instance call writes only that instance map.
2. A new instance drains the class registry into its own map at construction. 3. Render reads the flattened map.

## Configuration and precedence

- Effective precedence is instance > class > builtin by OVERWRITE ORDER at construction, not a live lookup.
No env var.

## Failures, side effects and security

- A built-in replaced silently (e.g. `add_filter("e", ...)` shadows escape) - a footgun with no signal.

## Wire and persistence contract

No wire/persistence; registries are in-memory (process-global via the class registry).

## Providers and substitutability

A future runtime must implement class calls as process-global and instance calls as local while keeping the
class+instance dual API. Whether to signal a built-in override remains a separate owner decision.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| EX-INSTANCE-LEAKS-CLASS | Fixed in all four under ADR-0052. Instance filter/global/test calls no longer write the class registry. | Proven by `frond_extensibility_contract.json`. |
| EX-RESOLUTION-FLATTENED | UNIVERSAL: resolution is NOT a live instance->class->builtin cascade; the three tiers are FLATTENED into one instance map at CONSTRUCTION. A class-level registration made AFTER an instance exists is invisible to that instance. The prior doc's "checks instance, then class, then built-in (fixed precedence)" mis-describes the mechanism in all four. | Correct the doc to the flattened-at-construct model (or implement a real live cascade if that is the desired contract). |
| EX-REPLACE-BUILTIN-SILENT | UNIVERSAL (resolves the prior unverified (silent?)): replacing a built-in filter/test/global is a SILENT overwrite, no warn/error, in all four. | Warn (or document) on a built-in override. |
| EX-CLASS+INSTANCE-DUAL | POSITIVE (do NOT re-flag): the three methods work as BOTH class and instance methods in all four, via a descriptor / magic methods / dual declaration. | Keep; gate it. |

## Owner decisions

> **RATIFIED 2026-08-14 - OWNER-DECIDED.** EX-DEC-01 is recorded by ADR-0052. A class call is process-global; an instance call is instance-local, identically in all four frameworks.

- EX-DEC-01 (decided, ADR-0052): class registration is process-global; instance registration is instance-local.
- EX-DEC-02 (pending): warn on a built-in override (EX-REPLACE-BUILTIN-SILENT) or document it. The
  flattened-at-construction resolution model is now documented independently of this decision.

## Proposed conformance fixture

The shared fixture proves that registration on one Frond instance does not affect a second instance, while
class registration reaches later instances. It covers `add_filter`/`add_global`/`add_test` identically in all
four. Built-in replacement remains outside this fixture until EX-DEC-02 is decided.

## Integration map

- Consumers: apps with custom filters/globals/tests. Composes: the runtime (51), filters (52), tests (54),
  functions (55).

## Breaking changes and migration

- Making instance registrations local changes behaviour for code relying on the former leak; each framework
  carries a `Breaking:` entry and the release documentation includes the migration. Warning on a built-in
  override would be additive.

## Porting capsule

Provide `add_filter`/`add_global`/`add_test` callable as BOTH class and instance methods. Class calls write a
process-global registry inherited at construction; instance calls write only that instance. Resolve names
from one map (builtins < class < instance). The built-in override signal remains a separate decision.

## Audit closure checklist

- [x] Boundary and public surface complete (add_filter/global/test x four).
- [x] Lifecycle and producer/consumer edges complete (register -> drain -> render).
- [x] Configuration (precedence), failure (silent override) and security rules complete.
- [x] Wire (in-memory registries) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (instance-local scope; flattened resolution).
- [x] EX-DEC-01 scope decided and implemented through ADR-0052.
- [ ] EX-DEC-02 built-in override signal remains a separate owner decision.
- [x] Conformance fixture (instance-isolation + dual-callable) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
