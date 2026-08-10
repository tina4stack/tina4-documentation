# Feature 056: Frond extensibility API

## Identity and status

- Matrix identity: 56 - Frond extensibility API
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (`add_filter`/`add_global`/`add_test`
  and the class-vs-instance registries in each engine). No framework code changed.
- Dependencies: Feature 52 filters, Feature 54 tests, Feature 55 functions (the registries these
  extend), Feature 58 sandboxing (constrains a custom extension)
- Dependants: any application registering a custom filter, test or function for its templates
- Existing ADRs: ADR-0005 (Frond tracks Twig/Jinja2); the no-aliases and data-not-host-casing
  rules (Feature 52)
- Shared fixtures: `frond_extensibility_contract.json` is required
- Catalog phase: Frond template engine

## Why this feature exists

An application extends the template vocabulary with its own filter, test or function -
`add_filter("money", ...)`, `add_test("admin", ...)`, `add_global("now", ...)` - and it must work
the same way in all four languages, whether registered once for the whole app (class-level) or per
render (instance-level).

## Boundary

This feature owns the three extension points (`add_filter`, `add_test`, `add_global` for
functions), the class-versus-instance registration semantics, and the replace-versus-augment rule
for a name that collides with a built-in. It DELEGATES the behaviour of a filter/test/function to
Features 52/54/55 and the safety of running a custom extension to Feature 58.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `add_filter` | yes | `addFilter` | yes | `addFilter` |
| `add_test` | yes | `addTest` | yes | `addTest` |
| `add_global` (functions) | yes | `addGlobal` | yes | `addGlobal` |
| Class-level registry | `_class_filters`/`_class_tests`/`_class_globals` | same | same | same |
| Instance-level registry | `_filters`/`_tests`/`_globals` | same | same | same |
| Works as class AND instance method | yes ("must work BOTH") | yes | yes | yes |
| Replace a built-in | (to confirm - silent?) | (to confirm) | (to confirm) | (to confirm) |

The extensibility API is three registration methods - `add_filter`, `add_test`, `add_global` -
each writing to a registry that exists at BOTH the class level (`_class_*`, shared by every Frond
instance) and the instance level (`_*`, per render). The Python source states the requirement that
`add_filter`/`add_global`/`add_test` "must work BOTH as" a class method (register globally) and an
instance method (register for one Frond). The one behaviour to pin is what happens when a custom
name collides with a built-in: replace silently, augment, or error.

## Public surface contract

`add_filter(name, fn)`, `add_test(name, fn)` and `add_global(name, value_or_fn)` register a custom
filter, test or callable global under a snake_case name (host casing on the method, snake_case on
the name). Called on the Frond CLASS, the registration is shared by every instance; called on an
INSTANCE, it applies to that render only. Instance registrations shadow class registrations for
that instance. A collision with a built-in is handled by the pinned rule (below).

## Inputs and outputs

- Input: a name (snake_case) and a function/value.
- Output: the extension is available in templates rendered by that scope (class-wide or
  instance).
- A class-level registration is visible to all Frond instances; an instance-level one only to
  that instance.
- Registering under a built-in name replaces/augments/errors per the pinned rule, not silently by
  accident.

## Lifecycle and operation graph

1. `add_filter`/`add_test`/`add_global` writes the name to the class or instance registry
   depending on the receiver.
2. At render, name resolution checks instance registry, then class registry, then built-ins (a
   fixed precedence), so an instance extension shadows a class one, which shadows a built-in only
   if the pinned rule allows.
3. The custom extension runs in the template context, subject to sandboxing (Feature 58).

## Configuration and precedence

- Resolution precedence: instance registry, then class registry, then built-in - fixed and
  identical across four.
- The name is snake_case (template data); the registration method keeps host casing.
- A collision with a built-in follows the pinned rule (recommend: allowed but explicit, not a
  silent surprise).

## Failures, side effects and security

- SANDBOXING: a custom filter/test/global runs code in the render; under sandboxing (Feature 58)
  it is subject to the sandbox rules, so an extension cannot be an escape hatch out of the
  sandbox. This is the security surface of extensibility.
- A registration under a built-in name must NOT silently and surprisingly replace a security-
  relevant built-in (an escape filter); the pinned rule makes any override deliberate.
- Class-level registration is process-global state; it must be reset cleanly (the `_class_*`
  clear) so one app or test does not leak an extension into another.
- The name is snake_case data; a camelCase or aliased registration reintroduces the Feature 52
  divergence and is rejected.

## Wire and persistence contract

There is no persistence; the contract is the three registration methods, the class-vs-instance
semantics, and the resolution precedence, identical across the four. A custom extension registered
the same way behaves the same way on every framework.

## Providers and substitutability

The extension API is a uniform surface over the filter/test/global registries. A future runtime
exposes the same three methods with the same class/instance semantics and the same precedence.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| EX-01 | The class-vs-instance duality (register globally or per render) and the resolution precedence are not gated as parity. | Gate class-level and instance-level registration and the instance-shadows-class-shadows-builtin precedence in all four. |
| EX-02 | The built-in collision rule (replace/augment/error) is not pinned. | Pin the rule; gate that registering under a built-in name follows it (not a silent surprise), in all four. |
| EX-03 | A custom extension's sandbox interaction is not gated. | Gate that a custom filter/test/global runs subject to the sandbox (Feature 58) in all four. |
| EX-04 | Class-level state cleanup (`_class_*` clear) is not gated; a leak across apps/tests. | Gate that class-level registrations reset cleanly in all four. |
| EX-05 | The three methods and their snake_case name rule are not gated. | Gate `add_filter`/`add_test`/`add_global` registering a snake_case-named working extension. |
| EX-06 | No shared fixture exists. | Add `frond_extensibility_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. The three extension points are `add_filter`, `add_test`, `add_global` (functions), uniform in
   all four; the method keeps host casing, the registered name is snake_case.
2. Registration works BOTH class-level (shared by every Frond instance) and instance-level (that
   render only); resolution is instance, then class, then built-in.
3. A collision with a built-in follows one pinned rule (recommend: allowed but explicit - a
   deliberate override, optionally warned - never a silent replace of a security-relevant
   built-in).
4. A custom extension runs subject to sandboxing (Feature 58); extensibility is not a sandbox
   escape.
5. Class-level registrations reset cleanly (`_class_*` clear), so no leak across apps or tests.

## Proposed conformance fixture

Add `frond_extensibility_contract.json` with stable ids for: `add_filter`/`add_test`/`add_global`
registering a working extension; a class-level registration visible to a new instance and an
instance-level one NOT visible to another instance; the resolution precedence (instance shadows
class shadows built-in); a built-in-name collision following the pinned rule; a custom extension
subject to the sandbox; and a class-level reset not leaking. Every case renders a real template
through the real registries; a pure evaluation needs no service and runs in all four runners.

## Integration map

- Features 52/54/55 own the filter/test/function behaviour; this feature is their shared
  registration API; Feature 58 constrains a custom extension.
- The extensibility fixture joins the Frond corpora in the shared fixtures.
- Central fixtures, four runners, the CI matrix and the Frond extensibility docs update together.

## Breaking changes and migration

- Pinning the collision rule and the snake_case name requirement may reject a camelCase or
  built-in-shadowing registration a framework accepted; a `Breaking:` note. It is a
  consistency/security correction.
- No change to the three method names.

## Implementation backlog

1. Add `frond_extensibility_contract.json` and wire four runners.
2. Gate the class/instance duality and precedence (EX-01) and the collision rule (EX-02).
3. Gate the sandbox interaction (EX-03), class-level cleanup (EX-04) and the three methods (EX-05).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Expose `add_filter(name, fn)`, `add_test(name, fn)` and `add_global(name, value_or_fn)`, each
writing to a class-level registry (shared) or an instance-level registry (per render) depending on
the receiver. Resolve names instance, then class, then built-in. Enforce a snake_case name, apply
the pinned built-in-collision rule, run a custom extension subject to sandboxing (Feature 58), and
reset class-level state cleanly. Prove the port against the extensibility fixture.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (EX-01..06).
- [x] Owner ambiguities recorded (5 proposed; the class/instance duality and collision rule).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
