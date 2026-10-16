# Feature 141: Metrics rule IDs, refactoring suggestions, and dashboard infraction overlay

## Outcome

`tina4 metrics` today reports a code-health symptom - a `kind`, a `severity`, a
`score` - and stops. It does not name the problem, it does not say what to do,
and the dev-admin bubble chart colours a file without saying what is wrong with
it. This feature adds a stable identification and suggestion layer on top of the
measurement that already exists, without touching the measurement's contract.

Three tiers, each a strict refinement of the one above:

- **kind** - the family (`complexity`, `duplication`, `large_file`,
  `low_maintainability`, `too_many_functions`, `no_test_reference`). The broad
  bucket, unchanged, still emitted.
- **rule id** - a stable, never-recycled identifier (CWE-style) for the SPECIFIC
  detector inside a kind. The extra layer: it says not just "this is complex"
  but why, and the why selects the remedy.
- **remedy** - the deterministic, language-agnostic structural refactoring that
  rule points at. The CLI suggests the MOVE (extract, unify, split, invert a
  dependency), never a named design pattern - naming a pattern needs the code's
  intent, which a metric does not carry, so that judgement stays in the
  maintainer agent, not the native scanner.

The same rule ids surface in two faces: the CLI (for CI, via `--json` and a new
`--suggest`) and the dev-admin dashboard (for the eye, as an infraction overlay
on the existing bubble chart). One catalogue, two readers.

It stays inside ADR-0002: native, rule-based, language-agnostic, no LLM, no
running framework required.

## Data path (ground truth - read before scoping)

Everything that COMPUTES metrics is Rust. The `tina4` CLI is the only engine
(ADR-0002). Each framework ships a THIN adapter (`metrics.rb` in Ruby, the
`devAdmin`/`DevAdmin`/`dev_admin` equivalent in Node/PHP/Python, ADR-0054) whose
whole job is to `Open3`-shell out to the `tina4` binary (`metrics --path <p>
--json`), parse the JSON, and RESHAPE it for the dashboard. There is no
language-side metric computation and no fallback: a missing/stale CLI is a 503
naming the install command, never zeros that read as a healthy codebase.

The reshape is lossy on purpose. Ruby's `full_analysis` forwards `summary` +
`file_metrics` + `most_complex_functions` (first 15) + `dependency_graph`, and
DROPS `offenders` entirely. Confirmed: no adapter forwards `offenders`, and the
dashboard bundle never references the token - the bubbles are coloured from
`file_metrics` (`loc`, `avg_complexity`, `has_referencing_test`, `dep_count`),
not from infractions.

Consequence: there is NO front-end-only slice. The infraction data is not in the
dashboard payload today, so the overlay depends on the Rust engine emitting it
AND on every thin adapter being taught to forward it. The dashboard stays a pure
renderer; it cannot invent what the engine did not send.

## Scope

### Slice A - rule engine in the Rust `tina4` client (source of truth, first) - SHIPPED

- [x] Freeze the rule catalogue (below) with one-line remedies; ranges reserved
  by category so growth never renumbers. (`rule_for(kind, loc)` in
  `tina4/src/metrics.rs`, pinned by `rule_for_is_the_frozen_catalogue`.)
- [x] Emit `rule_id` and `remedy` on each offender in `--json` (additive;
  `kind`/`severity`/`score`/`detail` stay exactly as they are).
- [x] Add `--suggest`: print the remedy under each row. Default human table
  stays byte-identical (opt-in).
- [x] `complexity` discriminated from EXISTING data (the function's own line
  count): `TINA4-M001` long method vs `TINA4-M002` dense logic - neither is a
  synonym for its kind.
- [x] A published rule id is a contract: retire with a tombstone, never repoint
  the number. (The frozen-catalogue test fails on any repoint.)
- [ ] Compute the DISCRIMINATING sub-metrics for the FINER complexity rules -
  nesting depth, branch/arm count, parameter count - so deep-nesting,
  fat-conditional and long-parameter-list get their own NEW `M0xx` numbers
  (additive, no repoint). Deferred: the AST walk does not produce these yet,
  and a rule id that cannot be told apart from `TINA4-M002` would be a synonym.
- [ ] Severity becomes a per-rule property, overridable. Deferred: severity is
  still computed inline per kind; the `--fail-on`/`--fail-on-regression` exit
  codes (0 pass, 1 tripped) are unchanged either way.

### Slice B - teach the four thin adapters to forward `offenders`

- [ ] Extend each framework's dev-admin metrics adapter (`full_analysis` and the
  Node/PHP/Python equivalents) to forward the `offenders` array the engine
  already emits, keyed by path, with the new `rule_id`/`remedy` fields intact.
- [ ] Add `offenders` to the key-validation the adapter enforces, so a stale CLI
  that omits it is caught (503) rather than silently rendering no badges.
- [ ] This is the genuine cross-framework slice: four small adapter changes at
  parity, same reshape contract in each.

### Slice C - dashboard infraction overlay (shared bundle)

- [ ] In the shared dev-admin bundle, group the now-forwarded `offenders` by
  path and join each to its bubble in `#metrics-chart` (the `jQ` renderer).
- [ ] A bubble with offenders wears a count badge ringed by its worst severity
  (error red, warn amber, info muted), so it announces itself before hover.
- [ ] `#metrics-hover-info` shows the worst rule id + count on hover.
- [ ] `#metrics-detail` lists the full set on click, each row
  `TINA4-M003 . fat conditional . render_tokens:1156` with its remedy line.
- [ ] A rule-id filter lights up only the bubbles carrying that rule across the
  whole tree.
- [ ] Do NOT double-count `no_test_reference`: the no-test term is already ~40%
  of the bubble COLOUR (`d(L)`), so either drop it from the colour or mark its
  badge "already shown".
- [ ] Rebuild the bundle into all four frameworks' `public/js`.

### Cross-cutting

- [ ] Shared contract fixture `fixtures/metrics_rule_ids_contract.json` pinning,
  for a known offending source sample, the exact `(kind, rule_id, remedy)` each
  detector emits - the same bytes drive the dashboard join test and the CLI
  test.
- [ ] A rule-code reference doc (one anchor per code) in
  `tina4-documentation/docs/`.
- [ ] `tina4 metrics` self-scan shows no new error-severity offender from the
  rule-engine code itself.

## Rule catalogue - FROZEN AND SHIPPED (slice A)

These are the ids the engine emits today, pinned by `rule_for_is_the_frozen_catalogue`
in `tina4/src/metrics.rs`. They are a published contract: never repoint a number.

| Code | kind | Discriminator (data today) | Remedy it points at |
|---|---|---|---|
| `TINA4-M001` | complexity | function `loc` >= 50 (long method) | extract cohesive steps into named methods |
| `TINA4-M002` | complexity | function `loc` < 50 (dense logic) | guard clauses, or a dispatch table / polymorphism |
| `TINA4-D010` | duplication | repeated blocks (known coordinates) | unify the copies into one shared helper |
| `TINA4-S020` | large_file | LOC over threshold | split the file by responsibility |
| `TINA4-S021` | too_many_functions | function count over threshold | group into cohesive units / a separate module |
| `TINA4-S022` | low_maintainability | MI floor + avg complexity gate | reduce size + branching; usually a split |
| `TINA4-C101` | no_test_reference | file has no referencing test | add a referencing test (coverage, not a refactor) |
| `TINA4-U901` | unparsed | engine could not read the file | update the CLI / check the file - it was NOT measured |

Ranges: `M0xx` per-function complexity/structure, `D0xx` duplication, `S0xx`
file-level size/structure, `C1xx` coverage, `U9xx` tooling.

RESERVED for the AST-sub-metric follow-up (the second Slice A checkbox), each a
NEW number that refines the `M002` dense bucket without repointing it:
deep-nesting, fat-conditional (switch), and long-parameter-list. They ship only
once the walk computes nesting depth, arm count and parameter count.

(The earlier draft of this table proposed different numbers - M001=deep nesting,
an `M0xx` range for file rules - before grounding in the engine: `FunctionInfo`
carries only `complexity` + `loc`, so only the long-method/dense split is
honest today. The shipped table above is the authority; the code and its test
agree with it.)

## Placement

The catalogue, the sub-metrics, and the `--json`/`--suggest` surface live in the
Rust `tina4` client (`tina4/src`, the metrics scanner) - it is the only engine,
so landing it there is one implementation for all four. The `offenders`
forwarding lives in each framework's thin dev-admin adapter (`metrics.rb` and
its Node/PHP/Python siblings) - four small parity changes. The overlay lives in
the shared dev-admin bundle each framework serves from `public/js`. The
named-DESIGN-pattern suggestion deliberately does NOT live in the CLI - it needs
intent the metric lacks and stays in the maintainer agent.

## Parity

| Surface | Python | PHP | Ruby | Node | Rust CLI |
|---|---|---|---|---|---|
| rule ids + remedies in `--json` (Slice A) | n/a | n/a | n/a | n/a | [x] |
| `--suggest` (Slice A) | n/a | n/a | n/a | n/a | [x] |
| adapter forwards `offenders` (Slice B) | [ ] | [ ] | [ ] | [ ] | n/a |
| dashboard overlay, shared bundle (Slice C) | [ ] | [ ] | [ ] | [ ] | n/a |
| contract fixture proven | [ ] | [ ] | [ ] | [ ] | [ ] |

## Tests (written first, real - no mocks, positive + negative)

- [x] `complexity` splits `TINA4-M001` (long method) vs `TINA4-M002` (dense) by
  the function's `loc`; a long method is never `M002` and vice versa, boundary
  pinned at 50 (`complexity_splits_into_long_method_vs_dense_logic_by_loc`).
- [x] Each file-level kind maps to its stable id - S020/S021/S022/C101 - and
  duplication to D010 (`each_file_level_kind_maps_to_its_stable_rule_id`,
  `duplication_offender_carries_its_rule_id`).
- [x] The frozen catalogue is pinned so a repoint fails
  (`rule_for_is_the_frozen_catalogue`); mutation-proven (repoint M001 -> red).
- [x] `--json` carries `rule_id` + `remedy`; a consumer reading only
  `kind`/`severity`/`score` still works (back-compat - additive fields).
- [x] `--suggest` prints the remedy under each row; absent the flag the table is
  byte-identical (end-to-end smoke verified).
- [ ] Finer complexity codes discriminate (deep nesting vs fat switch vs param
  count) - deferred with the AST sub-metrics.
- [ ] A retired id is never reused (fixture asserts the tombstone) - no retired
  ids yet; add with the first retirement.
- [ ] Each thin adapter forwards `offenders` with `rule_id`/`remedy` intact
  against a REAL `tina4` CLI on PATH (negative: a CLI build that omits
  `offenders` makes the adapter 503, not render an empty overlay).
- [ ] Dashboard: an offender on `frond.rb` renders a badge on the `frond.rb`
  bubble and lists its rule ids in `#metrics-detail`; a file with no offender
  gets no badge (negative).
- [ ] `no_test_reference` is surfaced once, not twice (colour OR badge).

## Bugs

- [ ] (log here as [ ], tick when a real test proves it fixed)

## Commits

- aeea057  tina4 (CLI) feature/metrics-rule-ids-141: rule ids + remedies on every
  offender, `--suggest`; `rule_for(kind, loc)` frozen catalogue; 5 tests,
  mutation-proven; full cargo suite 310 passed. (PR tina4stack/tina4#66)

## Status: In Progress - Slice A shipped (PR tina4stack/tina4#66); Slice B (adapters) + Slice C (dashboard overlay) pending
