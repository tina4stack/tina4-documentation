# Feature 56: Frond extensibility API

## Identity and status

- Matrix identity: 56 - Frond extensibility (add_filter / add_global / add_test)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language Frond source (correcting a prior-session doc claiming
  an instance registration is "that render only / NOT visible to another instance" - FALSE in all four; an
  instance registration ALSO writes the class registry and leaks to future instances). Python
  `frond/engine.py:1688` (`46007c1`); PHP `Tina4/Frond.php:390` (`ab871934`); Ruby `lib/tina4/frond.rb:401`
  (`f549923`); Node `packages/frond/src/engine.ts:1670` (`1319cf3`).
- Dependencies: the runtime (51).
- Dependants: apps registering custom filters/globals/tests.
- Existing ADRs: ADR-0004.

- Catalog phase: Frond

## Why this feature exists

Apps extend Frond with custom filters, globals (functions), and tests. The audit questions: is the API the
same, does an instance registration stay local, and how does a name collision resolve. The API is at parity
(class AND instance callable), but an instance registration LEAKS to the class registry in all four (not
local), and "resolution" is a flattened snapshot, not the documented live cascade.

## Existing implementation evidence

Universal, measured:

- `add_filter`/`add_global`/`add_test` (PHP `addFilter`/... via `__call`/`__callStatic`) exist in all four and
  work as BOTH a class method and an instance method (Python `_ClassOrInstanceMethod` descriptor
  `engine.py:1509`; PHP magic methods `Frond.php:390`; Ruby class+instance `frond.rb:401`/`:426`; Node static +
  instance `engine.ts:1670`/`:1791`). POSITIVE.
- An INSTANCE registration ALSO writes the CLASS registry in all four: Python `engine.py:1699`
  (`cls._class_filters[name]=fn` then instance); PHP `Frond.php:396` (`self::$classFilters` then `$this`);
  Ruby `frond.rb:427` (`self.class.add_filter` then `@filters`); Node `engine.ts:1792` (`Frond.classFilters.set`
  then `this.filters`). So an instance registration is INHERITED by every future `new Frond()` - it is NOT
  local.
- Resolution is FLATTENED at construction: the instance seeds `builtins`, then merges the class registry, then
  instance-writes overwrite - a SINGLE map is read at render (not a live instance->class->builtin cascade).
  Consequence: a CLASS-level registration made AFTER an instance exists is invisible to that instance.
- Replacing a built-in is a SILENT overwrite (no warn/error) in all four. A class-level reset
  (`clear_registry`) exists in all four. Functions are callable globals (no separate `functions` API).

## Public surface contract

`add_filter(name, fn)` / `add_global(name, value)` / `add_test(name, fn)`, callable on the class or an
instance. The documented contract SHOULD say whether an instance registration is local or process-global -
today it is process-global (leaks to the class registry).

## Inputs and outputs

- Input: a name + a callable/value. Output: the extension is available to renders (and, today, to all future
  instances).

## Lifecycle and operation graph

1. Register (class or instance) -> writes the class registry (+ the instance map if called on an instance).
2. A new instance drains the class registry into its own map at construction. 3. Render reads the flattened
map.

## Configuration and precedence

- Effective precedence is instance > class > builtin by OVERWRITE ORDER at construction, not a live lookup.
No env var.

## Failures, side effects and security

- A built-in replaced silently (e.g. `add_filter("e", ...)` shadows escape) - a footgun with no signal. An
  instance registration polluting the process-global class registry breaks test isolation and surprises a
  second instance. See the register.

## Wire and persistence contract

No wire/persistence; registries are in-memory (process-global via the class registry).

## Providers and substitutability

A future runtime must decide instance-local vs process-global registration and keep the class+instance dual
API, and it should signal a built-in override.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| EX-INSTANCE-LEAKS-CLASS | UNIVERSAL: an INSTANCE `add_filter`/`add_global`/`add_test` ALSO writes the CLASS registry in all four (`engine.py:1699`, `Frond.php:396`, `frond.rb:427`, `engine.ts:1792`), so it is inherited by every FUTURE instance - it is NOT local. The prior doc's "an instance registration applies to that render only / NOT visible to another instance" is FALSE in all four. This pollutes the process-global registry (breaks test isolation; a second instance silently inherits another's filters). | Decide (EX-DEC-01): make an instance registration instance-LOCAL (do not write the class registry), or document that ALL registrations are process-global. Same choice in all four. |
| EX-RESOLUTION-FLATTENED | UNIVERSAL: resolution is NOT a live instance->class->builtin cascade; the three tiers are FLATTENED into one instance map at CONSTRUCTION. A class-level registration made AFTER an instance exists is invisible to that instance. The prior doc's "checks instance, then class, then built-in (fixed precedence)" mis-describes the mechanism in all four. | Correct the doc to the flattened-at-construct model (or implement a real live cascade if that is the desired contract). |
| EX-REPLACE-BUILTIN-SILENT | UNIVERSAL (resolves the prior unverified (silent?)): replacing a built-in filter/test/global is a SILENT overwrite, no warn/error, in all four. | Warn (or document) on a built-in override. |
| EX-CLASS+INSTANCE-DUAL | POSITIVE (do NOT re-flag): the three methods work as BOTH class and instance methods in all four, via a descriptor / magic methods / dual declaration. | Keep; gate it. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- EX-DEC-01 (proposed): decide the registration-SCOPE contract (EX-INSTANCE-LEAKS-CLASS) - instance-local vs
  process-global. Today an instance registration leaks to the class registry in all four, polluting the
  process (a real test-isolation + surprise hazard). Pick one and apply it in all four.
- EX-DEC-02 (proposed): warn on a built-in override (EX-REPLACE-BUILTIN-SILENT) or document it; correct the
  resolution model to flattened-at-construct (EX-RESOLUTION-FLATTENED).

## Proposed conformance fixture

A shared fixture: registering a filter on ONE Frond instance does or does not affect a SECOND instance
(pinning EX-DEC-01) - identically in all four; `add_filter`/`add_global`/`add_test` work as class AND instance
methods; replacing a built-in behaves per EX-DEC-02.

## Integration map

- Consumers: apps with custom filters/globals/tests. Composes: the runtime (51), filters (52), tests (54),
  functions (55).

## Breaking changes and migration

- Making instance registrations local (if chosen) changes behaviour for code relying on the leak - a
  `Breaking:` entry with the migration. Warning on a built-in override is additive.

## Porting capsule

Provide `add_filter`/`add_global`/`add_test` callable as BOTH class and instance methods. Decide ONE
registration scope - instance-local (do not write the class registry) or process-global - and apply it
uniformly; today all four leak an instance registration into the process-global class registry, which breaks
test isolation. Resolve names from one map (builtins < class < instance) and SIGNAL a built-in override rather
than silently replacing it.

## Audit closure checklist

- [x] Boundary and public surface complete (add_filter/global/test x four).
- [x] Lifecycle and producer/consumer edges complete (register -> drain -> render).
- [x] Configuration (precedence), failure (silent override) and security rules complete.
- [x] Wire (in-memory registries) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (instance leaks to class in all four; flattened resolution).
- [x] Owner ambiguities decided (EX-DEC-01 scope, EX-DEC-02 override signal).
- [x] Conformance fixture (instance-isolation + dual-callable) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
