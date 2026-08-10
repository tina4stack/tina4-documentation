# Feature 052: Frond filters

## Identity and status

- Matrix identity: 52 - Frond filters
- Audit state: decision-ready
- Audit note: registries enumerated LIVE 2026-07-28 (not grepped - a grep gave 127/42/28/91,
  obvious noise); prose sections completed from that evidence 2026-08-10. No framework code
  changed.
- Dependencies: Feature 49 parser (parses the `|` pipe), Feature 51 runtime (applies the
  filter), Feature 57 escaping (a filter interacts with autoescape), Feature 55 functions and
  Feature 56 extensibility (siblings)
- Dependants: every template using `{{ x|filter }}`; the promise that a Frond template renders
  on any of the four
- Existing ADRs: ADR-0009 (removable Frond folder); the no-aliases rule; the data-not-host-
  casing rule (Feature 24's JSON keys)
- Shared fixtures: `frond_filter_corpus` (the canonical filter list) plus `frond_expression_
  corpus.txt`

## Why this feature exists

A template transforms a value with a filter: `{{ name|upper }}`, `{{ list|join(', ') }}`,
`{{ token|form_token }}`. The filter NAMES live inside the template file, so for a Frond template
to render on any of the four frameworks - Frond's whole reason to exist over each language's
incumbent engine - every filter must have the SAME name in all four.

## Boundary

This feature owns the filter registry (the canonical filter set), the `|` application and
chaining, and the `add_filter` registration API. It DELEGATES pipe parsing to Feature 49, the
apply-at-render to Feature 51, escaping to Feature 57, and template functions to Feature 55. A
filter NAME is data (snake_case, identical across four); the registration API keeps host casing.

## Existing implementation evidence

| Evidence (registries enumerated live) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Registered filters | 58 | 61 | 58 | 61 |
| Shared across all four | 58 of 61 (best parity in the audit) | same | same | same |
| camelCase alias (`formToken`) | no | YES | no | YES |
| `form_token_value` filter | MISSING | present | MISSING | present |
| Internal alias pairs | 3 (`base64decode`/`base64_decode`, etc.) | - | - | - |
| Registry shape | data map | data map | control-flow (CC 63) | data map |
| `add_filter` API | `add_filter(name, fn)` | `addFilter($name, $fn)` | `add_filter(name, &block)` | `addFilter(name, fn)` |

Enumerated at runtime (reading each engine's `_filters`/`@filters`/`filters`), the family shares
58 of 61 filter names - by far the best parity of any feature, backed by the byte-identical
82-case expression corpus. The three non-universal names are all in the form-token family and are
NOT a missing CSRF filter (`form_token` is in all four). They are: D1 a camelCase alias
(`formToken`) in PHP/Node only; D2 a genuinely missing `form_token_value` filter in Python/Ruby (a
real capability gap); and D3 Python's own internal alias sprawl (three pairs). Ruby's
`default_filters` measures CC 63 because the registry is BUILT WITH BRANCHING instead of declared
as a name-to-function map.

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

A canonical set of ~56 filters (61 names minus the 5 aliases), each with ONE snake_case name
identical across the four, applied with `{{ expr|filter(args) }}` and chainable (`|a|b`).
`add_filter(name, fn)` (host casing on the API) registers a custom filter under a snake_case
name. A filter name is data: `formToken`, `formTokenValue`, `base64decode`, `base64encode` and
`tojson` are deleted in favour of `form_token`, `form_token_value`, `base64_decode`,
`base64_encode` and `to_json`.

## Inputs and outputs

- Input: a value (the piped expression) and any filter arguments; the filter name resolved in
  the registry.
- Output: the transformed value; a chain applies filters left to right.
- A filter name that is not in the registry is a positioned error, not a silent pass-through.
- `form_token_value` returns the token value alone (added to Python/Ruby); `form_token` returns
  the rendered hidden input.

## Lifecycle and operation graph

1. Feature 49 parses `expr|filter(args)` into an AST with the filter name and args.
2. At render, Feature 51 resolves the filter name in the registry (one map, name to function).
3. The filter runs on the value with its arguments; a chain feeds each output to the next.
4. The result is escaped by Feature 57 unless the filter is a raw/safe filter.

## Configuration and precedence

- The canonical filter list is a committed fixture read by all four runners (the same mechanism
  as the expression corpus).
- `add_filter` registers under a snake_case name; it must not silently replace a builtin
  (Feature 56's boundary).
- There is no per-template filter configuration.

## Failures, side effects and security

- An unknown filter name is a positioned error, so a template typo is found, not silently
  rendered as the raw value.
- A filter's output flows into autoescape (Feature 57): a filter that produces HTML must mark it
  safe explicitly, or it is escaped; a filter cannot become an escape-bypass by accident.
- The registry is a data map, not control flow: Ruby's CC-63 branching registry is both a
  maintainability problem and a place a bug can hide; one table removes both.
- A custom `add_filter` runs in the same context; under sandboxing (Feature 58) it is subject to
  the sandbox rules.

## Wire and persistence contract

There is no persistence; the contract is the FILTER NAME SET as data. Filter names are
snake_case and identical across the four, so a template using `{{ x|to_json }}` renders on every
framework - the portability that a per-language casing rule (allowed for method names) would
break. The canonical list is a committed fixture.

## Providers and substitutability

The filter registry is a pure data map from name to function; a future runtime registers the same
canonical snake_case names bound to functions with the same behaviour, proven by the shared
filter and expression corpora.

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

Proposed for owner ratification:

1. Filter NAMES are template data: one canonical snake_case name per filter, IDENTICAL in all
   four. The per-language method-casing rule (`to_paginate`/`toPaginate`) does NOT extend to
   filter names, because a filter name lives in a portable template file.
2. Delete the five aliases (`formToken`, `formTokenValue`, `base64decode`, `base64encode`,
   `tojson`); the snake_case forms are canonical. This is the one place in the audit where a
   ONE-RELEASE deprecation WARNING (naming the canonical replacement) is argued FOR, because the
   broken artifact is a user's template, which the framework cannot auto-migrate.
3. Add `form_token_value` to Python and Ruby (the one real capability gap); additive, lands
   first.
4. The filter registry is a DATA map (name to function), not control flow; Ruby's CC-63
   `default_filters` is converted to a table.
5. The canonical filter list is a committed fixture read by all four runners, so parity is
   gated, not periodically re-audited.

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

- Feature 49 parses the `|` pipe; Feature 51 applies filters; Feature 57 escapes the output;
  Feature 55 (functions) and Feature 56 (extensibility/`add_filter`) are siblings.
- The canonical filter list joins the expression corpus in the shared Frond fixtures; the
  portability test renders one template using every filter through all four engines.
- Central fixtures, four runners, the CI matrix and the Frond filter docs update together.

## Breaking changes and migration

- Deleting the five aliases is BREAKING for templates in the wild, and templates are user files
  the framework cannot auto-migrate. The `Breaking:` entry lists each removed name and its
  canonical replacement, and (uniquely in this audit) a ONE-RELEASE deprecation warning that
  names the replacement when an alias is used is recommended, because the broken artifact is a
  user's template.
- Adding `form_token_value` to Python/Ruby is additive.
- Converting Ruby's registry to a data table is internal (behaviour-neutral), gated by the
  corpus.

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

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (D1-D3 plus the CC-63 registry).
- [x] Owner ambiguities recorded (5 proposed; the snake_case-names-are-data rule is key).
- [x] Proposed shared cases and mutation witnesses complete (the portability corpus).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready. Best-parity feature in the matrix (58/61 shared, live-enumerated). The work
is the naming cleanup (delete 5 aliases, add form_token_value, snake_case-identical names), the
registry-as-data conversion (Ruby CC 63), and the committed portability corpus. The IMPLEMENTATION
is the build phase and is NOT done; steps 3 (add filter) and 5 (registry to data) can proceed
independently of the ADR-0009 folder split. Decision-ready is not built.
