# Feature 054: Frond expression tests

## Identity and status

- Matrix identity: 54 - Frond expression tests
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the `is` test operator and the
  `_tests` registry in each engine). No framework code changed.
- Dependencies: Feature 49 parser (parses `is`/`is not`), Feature 51 runtime (applies the test),
  Feature 56 extensibility (`add_test`)
- Dependants: any template using `{{ x is defined }}` and similar
- Existing ADRs: ADR-0005 (Frond tracks Twig/Jinja2); the data-not-host-casing rule (Feature 52)
- Shared fixtures: `frond_test_corpus` is required
- Catalog phase: Frond template engine

## Why this feature exists

A template asks a boolean question about a value with the `is` operator: `{{ x is defined }}`,
`{{ n is even }}`, `{{ list is empty }}`. Because the test names live in a portable template file,
the SAME test vocabulary must exist and behave identically in all four languages.

## Boundary

This feature owns the `is`/`is not` test operator and the built-in TEST registry (named boolean
functions), plus the `add_test` registration API. It DELEGATES parsing of `is` to Feature 49, the
apply-at-render to Feature 51, and custom-test extensibility mechanics to Feature 56. A test NAME
is data (snake_case, identical across four); the registration API keeps host casing.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `is` test operator | yes | yes | yes | yes |
| Built-in tests | `defined` (`v is not None`) and others | same set | same set | same set |
| Test registry | `_tests` (instance) + `_class_tests` (class) | same shape | same | same |
| `is not` negation | yes | yes | yes | yes |
| `add_test(name, fn)` | yes | yes | yes | yes |
| Test names | data (snake_case) | data | data | data |

The `is` operator applies a named boolean test from a registry - Python's `_tests` (merged with
`_class_tests` for class-level registration and `add_test` for custom tests), with built-ins such
as `defined` (`v is not None`). Like filter names (Feature 52), TEST names are template data and
must be identical across the four; the exact built-in set should be enumerated LIVE (the Feature
52 lesson: a grep of test-looking names is noise) and pinned so a `{{ x is even }}` renders the
same everywhere.

## Public surface contract

The `is` and `is not` operators apply a named test: `{{ value is test }}` yields a boolean. The
built-in test set (snake_case, identical across four) includes the Jinja2 vocabulary (`defined`,
`none`, `even`, `odd`, `empty`, `iterable`, `number`, `string`, `mapping`, `sameas`,
`divisibleby`, and the rest as enumerated). `add_test(name, fn)` (host casing) registers a custom
test under a snake_case name.

## Inputs and outputs

- Input: a value and a test name (and any test argument, e.g. `is divisibleby(3)`).
- Output: a boolean; `is not` negates it.
- An unknown test name is a positioned error, not a silent false.
- A custom test registered via `add_test` is applied like a built-in.

## Lifecycle and operation graph

1. Feature 49 parses `value is [not] test(args)` into the AST.
2. At render, Feature 51 resolves the test name in the registry (built-in + class + instance).
3. The test runs on the value with any argument and returns a boolean; `is not` negates it.
4. The boolean feeds the surrounding expression (typically an `{% if %}`).

## Configuration and precedence

- The built-in test list is a committed fixture read by all four runners.
- `add_test` registers under a snake_case name; a custom test does not silently replace a
  built-in (Feature 56's boundary).
- There is no per-template test configuration.

## Failures, side effects and security

- An unknown test name is a positioned error, so a template typo (`{{ x is defiend }}`) is found,
  not silently rendered false.
- A test is a pure boolean predicate over its value; it must not mutate the value or have a side
  effect, so `{% if x is even %}` is safe to evaluate.
- Under sandboxing (Feature 58), a custom test runs subject to the sandbox rules.
- `is not` binds correctly (negation of the test result, not of the value).

## Wire and persistence contract

There is no persistence; the contract is the TEST NAME SET as data (snake_case, identical) and the
boolean each test returns for a given value. A template using `{{ x is defined }}` yields the same
result on every framework. The built-in list is a committed fixture.

## Providers and substitutability

The test registry is a pure data map from name to predicate; a future runtime registers the same
snake_case test names bound to predicates with the same results, proven by the test corpus.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| TS-01 | The built-in test set must be identical across four (test names are template data); parity not gated. | Enumerate the built-in tests live and gate the same set (snake_case) in all four. |
| TS-02 | An unknown test name's behaviour (error vs silent false) is not pinned. | Pin a positioned error for an unknown test; gate it in all four. |
| TS-03 | `is not` negation and test arguments (`is divisibleby(3)`) parity are not gated. | Gate `is not` and argument-taking tests in all four. |
| TS-04 | `add_test` (and the class-vs-instance registry) parity is not gated. | Gate that `add_test` registers a working custom test that does not replace a built-in, in all four. |
| TS-05 | No shared test fixture exists. | Add `frond_test_corpus`. |

## Owner decisions

Proposed for owner ratification:

1. The built-in test set is snake_case and IDENTICAL in all four (test names are template data,
   like filter names); the set is enumerated live and pinned.
2. `is` and `is not` are supported; an unknown test is a positioned error, not a silent false.
3. Tests take arguments where Jinja2 does (`is divisibleby(n)`, `is sameas(y)`).
4. `add_test(name, fn)` registers a custom test under a snake_case name; it does not silently
   replace a built-in.
5. The built-in test list is a committed fixture read by all four runners.

## Proposed conformance fixture

Add `frond_test_corpus` with stable ids for: each built-in test returning the right boolean for a
value; `is not` negating correctly; an argument-taking test (`is divisibleby(3)`); an unknown test
raising a positioned error; and `add_test` registering a working custom test that does not replace
a built-in. Every case renders a real template and compares the boolean/error; a pure evaluation
needs no service and runs in all four runners.

## Integration map

- Feature 49 parses `is`; Feature 51 applies the test; Feature 56 owns `add_test` mechanics;
  Feature 58 sandboxes a custom test.
- The test corpus joins the expression, filter and tag corpora in the shared Frond fixtures.
- Central fixtures, four runners, the CI matrix and the Frond docs update together.

## Breaking changes and migration

- Pinning the test set and the unknown-test error may change a framework that silently returned
  false for an unknown test; a `Breaking:` note, and a template relying on the silent false is a
  latent bug.
- No new tests beyond the pinned Jinja2 set (ADR-0005).

## Implementation backlog

1. Add `frond_test_corpus` and wire four runners.
2. Enumerate and gate the built-in test set (TS-01) and the unknown-test error (TS-02) in all
   four.
3. Gate `is not`, argument tests (TS-03) and `add_test` (TS-04).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the `is`/`is not` operator over a registry of named boolean tests (built-in + class +
instance), snake_case names identical across four, matching the Jinja2 vocabulary (`defined`,
`even`, `odd`, `none`, `empty`, `iterable`, `divisibleby`, `sameas`, and the rest). An unknown
test is a positioned error. `add_test(name, fn)` registers a custom test that does not replace a
built-in. Keep tests pure (no mutation). Prove the port against the test corpus, including `is not`
and an argument-taking test.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (TS-01..05).
- [x] Owner ambiguities recorded (5 proposed; the test-names-are-data rule and unknown-test error).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
