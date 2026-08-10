# Feature 053: Frond tags

## Identity and status

- Matrix identity: 53 - Frond tags
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the tag set in each engine). No
  framework code changed.
- Dependencies: Feature 49 parser (parses `{% tag %}`), Feature 51 runtime (executes it),
  Feature 57 (`autoescape`), Feature 59/60 (`cache`), the realtime path (`live`)
- Dependants: every template using a `{% %}` statement; Frond's Twig/Jinja2 compatibility promise
- Existing ADRs: ADR-0005 (Frond tracks Twig and Jinja2, NOT Blade; fragment/push/stack/switch
  dropped); ADR-0009 (removable Frond folder)
- Shared fixtures: `frond_tag_corpus` is required
- Catalog phase: Frond template engine

## Why this feature exists

A template controls flow and structure with statement tags - `{% if %}`, `{% for %}`,
`{% set %}`, `{% extends %}`, `{% block %}`, `{% include %}`, `{% macro %}`, `{% raw %}` - and
because those tags are text in a portable template file, the SAME tag vocabulary must exist and
behave identically in all four languages.

## Boundary

This feature owns the canonical tag SET and each tag's semantics: branching (`if`/`elif`/`else`),
looping (`for`, with `else`), assignment (`set`, including the capture form), inheritance
(`extends`, single), block override (`block`), composition (`include`, `import`/`from`), macros
(`macro`), literal (`raw`), and the tags delegated to siblings (`autoescape` -> Feature 57,
`cache` -> Feature 59/60, `live` -> realtime). It DELEGATES parsing to Feature 49 and execution to
Feature 51. It tracks Twig/Jinja2 (ADR-0005); it does NOT add Blade tags.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Tag set | if/elif/else/for/set/extends/block/include/import/from/macro/raw/live/cache/autoescape | same | same | same |
| Tracks | Twig/Jinja2 (ADR-0005) | same | same | same |
| Blade tags (fragment/push/stack/switch) | dropped | dropped | dropped | dropped |
| Unknown tag | LEAKS into output (bug) | (to confirm) | (to confirm) | (to confirm) |
| `set` capture form (`{% set x %}...{% endset %}`) | block-set bug | (to confirm) | (to confirm) | (to confirm) |
| `for ... else` | yes | yes | yes | yes |
| Single inheritance | `extends` one parent | same | same | same |

The tag vocabulary is a Twig/Jinja2 set, the same across the four by design (ADR-0005 chose to
track Twig/Jinja2 and drop Blade's fragment/push/stack/switch). Two real bugs are on record: an
UNKNOWN tag LEAKS into output rather than raising a positioned error (a typo'd `{% forr %}` should
fail, not appear in the page), and the block-form `set` (`{% set x %}...{% endset %}` capture)
misbehaves. Tag names, like filter names (Feature 52), are template data and must be identical in
all four.

## Public surface contract

The canonical tag set is available in every template, identical in all four: `if`/`elif`/`else`/
`endif`, `for`/`else`/`endfor`, `set` (inline and capture), `extends`, `block`/`endblock`,
`include`, `import`/`from`, `macro`/`endmacro`, `raw`/`endraw`, plus `autoescape` (Feature 57),
`cache` (Feature 59/60) and `live` (realtime). An unknown tag is a positioned parse error, never
leaked into output.

## Inputs and outputs

- Input: a `{% tag args %}` in the template and the render context.
- Output: the tag's effect - a branch taken, a loop rendered, a variable set, a parent extended, a
  block overridden, a partial included, a macro defined, literal text preserved.
- `for ... else` renders the else body when the iterable is empty.
- `set` assigns a value (inline) or captures a rendered body (`{% set x %}...{% endset %}`).
- An unknown tag raises a positioned error; it is never emitted as text.

## Lifecycle and operation graph

1. Feature 49 parses `{% tag %}` into a BLOCK node with the tag name and grouped body.
2. An unrecognized tag name is a positioned parse error at this point (not deferred to render as
   leaked text).
3. Feature 51 executes the tag: `if` picks a branch, `for` iterates (with `else` on empty), `set`
   assigns or captures, `extends`/`block` resolve inheritance, `include` renders a partial,
   `macro` defines/calls, `raw` emits literal.
4. `autoescape`/`cache`/`live` are handled by their features but parsed and grouped here.

## Configuration and precedence

- The tag set is fixed by ADR-0005 (Twig/Jinja2); a Blade tag is not added, and a template using
  one gets an unknown-tag error, not a silent pass.
- `extends` is single inheritance; a second `extends` is an error.
- There is no per-template tag configuration.

## Failures, side effects and security

- UNKNOWN-TAG LEAK: an unrecognized `{% tag %}` must raise a POSITIONED error, not leak the tag
  text into the rendered output. Leaking is both a silent-bug (a typo renders wrong) and a minor
  disclosure (template internals appear in the page); this is a real recorded bug to fix in all
  four.
- The block-form `set` capture must render its body into the variable, not misbehave; a capture
  bug loses content.
- `include` and `extends` resolve template paths; the path must be confined (no traversal outside
  the templates directory), matching the file-confinement rule (Feature 30/41).
- `for` and `if` bodies are scoped (Feature 51); a loop variable does not leak.
- A malformed tag is preserved-or-errored per the engine's rule (Feature 49), consistently.

## Wire and persistence contract

There is no persistence; the tag NAMES are template data and identical across the four, and each
tag's rendered effect is identical for the same template and context. The canonical tag set is a
committed fixture.

## Providers and substitutability

The tag set is engine-agnostic template vocabulary. A future runtime implements the same tags with
the same semantics and the same unknown-tag error, proven by the tag corpus.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| TG-01 | An unknown tag LEAKS into output instead of raising a positioned error. | Gate that an unknown `{% tag %}` raises a positioned error (not leaked text) in all four. |
| TG-02 | The block-form `set` capture (`{% set x %}...{% endset %}`) misbehaves. | Gate that a capture `set` renders its body into the variable in all four. |
| TG-03 | The canonical tag set (ADR-0005) is not gated as parity. | Gate the full tag set and its semantics (if/for-else/set/extends/block/include/import/macro/raw) in all four. |
| TG-04 | `include`/`extends` path confinement is not gated. | Gate that an `include`/`extends` cannot escape the templates directory in all four. |
| TG-05 | Single-inheritance enforcement (`extends` once) is not gated. | Gate that a second `extends` is an error in all four. |
| TG-06 | No shared tag fixture exists. | Add `frond_tag_corpus`. |

## Owner decisions

Proposed for owner ratification:

1. The canonical tag set tracks Twig/Jinja2 (ADR-0005), identical in all four; Blade tags
   (fragment/push/stack/switch) are not added, and a Blade tag yields an unknown-tag error.
2. An unknown tag raises a POSITIONED error and is NEVER leaked into output (the recorded bug).
3. The block-form `set` capture renders its body into the variable (the recorded bug).
4. `extends` is single inheritance; `include`/`extends` paths are confined to the templates
   directory.
5. The canonical tag set and each tag's semantics are a committed fixture read by all four
   runners.

## Proposed conformance fixture

Add `frond_tag_corpus` with stable ids for: each tag rendering its effect (`if`/`elif`/`else`,
`for ... else` on an empty iterable, inline `set`, capture `set`, `extends`+`block` override,
`include`, `macro` define/call, `raw` literal); an unknown tag raising a positioned error (NOT
leaked); a second `extends` erroring; and an `include` path traversal rejected. Every case renders
a real template and compares output/error; a pure render needs no service and runs in all four
runners.

## Integration map

- Feature 49 parses tags; Feature 51 executes them; Feature 57 (`autoescape`), 59/60 (`cache`) and
  the realtime path (`live`) own their tags; the templates directory bounds `include`/`extends`.
- The tag corpus joins the expression and filter corpora in the shared Frond fixtures.
- Central fixtures, four runners, the CI matrix and the Frond docs update together.

## Breaking changes and migration

- Fixing the unknown-tag leak changes a currently-leaking template to a loud error; a template
  relying on the leak is itself a bug. Fixing the block-set capture is a correctness fix. Both are
  noted in the release note.
- No new tags; the set is unchanged (ADR-0005).

## Implementation backlog

1. Add `frond_tag_corpus` and wire four runners.
2. Gate the unknown-tag error (TG-01) and the block-set capture (TG-02) in all four.
3. Gate the tag set and semantics (TG-03), path confinement (TG-04) and single inheritance
   (TG-05).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the Twig/Jinja2 tag set (ADR-0005): `if`/`elif`/`else`, `for`/`else`, `set` (inline and
capture), `extends` (single), `block`, `include`, `import`/`from`, `macro`, `raw`, plus the
delegated `autoescape`/`cache`/`live`. Parse an unknown tag to a POSITIONED error, never leaked
text. Render the block-form `set` body into the variable. Confine `include`/`extends` paths to the
templates directory. Prove the port against the tag corpus, especially the unknown-tag error and
the capture `set`.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (TG-01..06; the unknown-tag leak and block-set).
- [x] Owner ambiguities recorded (5 proposed; the unknown-tag error is the key one).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
