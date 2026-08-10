# Feature 052: Frond filters

## Identity and status

- Matrix identity: 52 — Frond filters
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

## Why this feature exists

The retained audit does not yet state the developer problem in one language-neutral sentence.

## Boundary

The retained audit does not yet separate what this feature owns, delegates, and excludes.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 3, row 5. **Planning only.**

**Status: CLOSED.** All four registries enumerated at runtime, not grepped.

### Method note, because the first attempt was wrong

My first pass grepped the engine files for filter-looking names and produced 127 / 42 /
28 / 91 candidates - a spread so wild it was obviously the grep, not the frameworks. I
discarded those numbers without reporting them and instantiated each engine instead,
reading its live filter registry (`_filters`, `@filters`, `filters`).

The real counts are close and the grep was noise. Recording it because it is the fourth
time in this audit that a grep nearly became a finding, and the enumeration took one
command more.

### The registries, enumerated live

| | filters |
| --- | --- |
| python | **58** |
| ruby | **58** |
| php | **61** |
| node | **61** |

**61 distinct names across the family, and 58 are present in all four.** That is by far
the best parity of any feature audited - Phase 2 rows routinely diverged on half their
surface. Backed by the byte-identical 82-case expression corpus (Features 48-50), filter
*behaviour* is in good shape.

### Why D1 matters more than its size suggests

A filter name is not a host-language API surface. It is **text inside a template file**,
and a Frond template is authored once and expected to render on any of the four
frameworks - that portability is close to Frond's whole reason for existing over each
language's incumbent engine.

So a filter name is the same class of thing as feature 23's JSON keys: **data, and data
does not change spelling by host language.** A template containing
`{{ token|formToken }}` renders on PHP and Node and fails on Python and Ruby. The
surface-table rule that lets `to_paginate` and `toPaginate` coexist as *method* names
does not extend here, and this row is where that boundary needs stating.

The same argument condemns D3: `{{ x|tojson }}` and `{{ x|to_json }}` both working means
two spellings of one filter are now load-bearing in somebody's templates, and neither is
canonical.

## Public surface contract

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

The audit has not yet traced every producer, discovery, execution, inspection, retry, rollback, and deletion path.

## Configuration and precedence

The audit has not yet fixed argument, environment, project-file, default, and cache timing precedence.

## Failures, side effects and security

The audit has not yet closed every failure boundary, side effect, cleanup rule, and security concern.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

## Contradictions and defects

### What differs: three names, and neither is what it first looked like

The three that are not universal are all in the form-token family, so my first reading
was "the CSRF filter is missing in Python and Ruby". **That reading was wrong**, and
checking it was worth the extra command:

| | form/token filters |
| --- | --- |
| python | `form_token` |
| ruby | `form_token` |
| php | `form_token`, `formToken`, `form_token_value`, `formTokenValue` |
| node | `form_token`, `formToken`, `form_token_value`, `formTokenValue` |

`form_token` is present in **all four**. The CSRF filter is fine. What actually differs
is two separate things:

**D1. `formToken` is a camelCase alias of `form_token`, in PHP and Node only.** Same
filter, second spelling, two frameworks.

**D2. `form_token_value` (plus its camelCase twin) is a genuinely missing filter** in
Python and Ruby. It returns the token value alone rather than the rendered hidden
input - a real capability gap, small but real.

**D3. Alias sprawl inside a single framework.** Python's own registry carries three
pairs that are the same filter twice:

```
base64_decode  <->  base64decode
base64_encode  <->  base64encode
to_json        <->  tojson
```

### Verdict: SYNTHESISE

Decided on **template portability**, with DRY as the secondary axis.

PHP and Node have the fuller capability (D2) and the alias clutter (D1). Python and Ruby
are cleaner on naming and short one filter. Python carries its own internal sprawl (D3).
Nothing to promote wholesale.

All category 4. Nothing about a filter name is runtime-forced - a template is text.

### Risks

- **Deleting five filter aliases is breaking for templates in the wild**, and templates
  are user files the framework cannot migrate automatically. This needs the loudest kind
  of migration note, and it is worth considering a one-release deprecation warning that
  names the canonical replacement when an alias is used - the only place in this audit
  where I would argue *for* a transition period rather than a clean break, because the
  broken artifact is a user's template rather than their code.
- **Registry-to-data is mechanical but touches all 58 filters** in each framework. The
  expression corpus is the safety net and it already exists.
- Adding `form_token_value` is additive and safe.

## Owner decisions

No new owner decision is recorded in this migrated section. Retained decisions appear below when present.

## Proposed conformance fixture

### Tests to write

Pure in-memory: instantiate the engine, read the registry, render a string. No I/O.

| pair | positive | negative |
| --- | --- | --- |
| canonical set | `every_framework_registers_the_canonical_filter_list` | `no_framework_registers_a_filter_the_others_lack` - the `form_token_value` reproduction |
| no aliases | `each_filter_has_exactly_one_registered_name` | `no_filter_is_registered_under_a_second_spelling` - the D1/D3 reproduction |
| casing | `every_filter_name_is_snake_case` | `no_filter_name_is_camel_case` - kills `formToken` |
| portability | `a_template_using_every_canonical_filter_renders_in_all_four` | `a_template_that_renders_on_one_framework_never_fails_on_another` |
| registry is data | `the_filter_registry_is_a_map_from_name_to_function` | `the_filter_registry_declares_no_control_flow` - the Ruby CC 63 reproduction |
| extensibility | `add_filter_registers_a_working_custom_filter` | `add_filter_does_not_silently_replace_a_builtin` (feature 55's boundary) |

The portability pair is the one worth the row: it is a single template exercising all 56
filters, rendered by all four engines, compared to one expected output. That is the
artifact that makes "a Frond template runs anywhere" a tested claim rather than an
aspiration.

## Integration map

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

## Breaking changes and migration

The audit has not yet turned every parity break into an actionable pre-3.14 migration instruction.

## Implementation backlog

### Methodology

1. Commit the canonical filter-name fixture (61 names minus the 5 aliases = **56
   canonical filters**, pending the owner's read of the delete list).
2. Write the tests below in all four. Expect red on the alias assertions in PHP, Node
   and Python, and on `form_token_value` in Python and Ruby.
3. Add `form_token_value` to Python and Ruby. Additive, lands first, independently.
4. Delete the five aliases. Breaking for any template using them - `Breaking:` entry
   listing each removed name and its canonical replacement.
5. Convert the registry to a data table in all four, Ruby first (CC 63 is the biggest
   single win available in Phase 3 and the change is mechanical).
6. Re-measure. Ruby's `default_filters` should drop from 63 to near zero.

## Porting capsule

### Pattern

**One canonical snake_case name per filter, in all four, and no aliases.**

1. **Filter names are snake_case everywhere.** They live in template text, so they do
   not follow host-language casing. `formToken`, `formTokenValue`, `base64decode`,
   `base64encode` and `tojson` are **deleted**; `form_token`, `form_token_value`,
   `base64_decode`, `base64_encode` and `to_json` are canonical.
2. **`form_token_value` is added to Python and Ruby** - the one real capability gap.
3. **The filter registry is data, not control flow.** This is the Features 48-50 finding
   arriving here: Ruby's `default_filters` measures CC **63** because the registry is
   built with branching instead of declared as a map. One table, name to function.
4. **The canonical list is a committed fixture**, one file, read by all four suites -
   the same mechanism the expression corpus already uses. That is what makes filter
   parity checkable rather than periodically re-audited.

Surface table - the registration API keeps host casing, the filter names do not:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| register | `add_filter(name, fn)` | `addFilter($name, $fn)` | `add_filter(name, &block)` | `addFilter(name, fn)` |
| filter names | snake_case, identical in all four | | | |

## Audit closure checklist

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.

### Parked

Not implemented. Steps 3 and 5 can proceed independently of the ADR-0009 folder split;
step 5 is easier after it. Order unchanged.
