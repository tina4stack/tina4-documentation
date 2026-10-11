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

### Slice A - rule engine in the Rust `tina4` client (source of truth, first)

- [ ] Compute the DISCRIMINATING sub-metrics a kind needs to fan into rules -
  for `complexity`: nesting depth, raw method length, branch/arm count,
  parameter count. Without these a rule id is a synonym for the kind and adds
  nothing; this is the real work.
- [ ] Freeze the rule catalogue (below) with one-line remedies; ranges reserved
  by category so growth never renumbers.
- [ ] Emit `rule_id` and `remedy` on each offender in `--json` (additive;
  `kind`/`severity`/`score`/`detail` stay exactly as they are).
- [ ] Add `--suggest`: print `remedy[rule_id]` in the human table.
- [ ] Severity becomes a per-rule property, overridable; the existing
  `--fail-on`/`--fail-on-regression` exit codes (0 pass, 1 tripped) are
  unchanged.
- [ ] A published rule id is a contract: retire with a tombstone, never repoint
  the number.

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

## Proposed rule catalogue (frozen on first ship, never recycled)

| Code | kind | Discriminator | Remedy it points at |
|---|---|---|---|
| `TINA4-M001` | complexity | deep nesting | invert with guard clauses, extract the inner block |
| `TINA4-M002` | duplication | repeated blocks (known coordinates) | unify the N copies into one helper |
| `TINA4-M003` | complexity | fat conditional / big switch | dispatch table or polymorphism |
| `TINA4-M004` | complexity | long method (raw length) | extract methods |
| `TINA4-M005` | complexity | long parameter list | introduce a parameter object |
| `TINA4-M010` | large_file | LOC over threshold | split the file by responsibility |
| `TINA4-M011` | low_maintainability | maintainability index floor | reduce size + branching; usually a split |
| `TINA4-M012` | too_many_functions | function count over threshold | group into cohesive units / separate module |
| `TINA4-C101` | no_test_reference | file has no referencing test | add a referencing test (coverage, not a refactor - different range on purpose) |

`M0xx` = structure/refactor, `C1xx` = coverage. New detectors take the next free
number in range.

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
| rule ids + remedies in `--json` (Slice A) | n/a | n/a | n/a | n/a | [ ] |
| `--suggest` (Slice A) | n/a | n/a | n/a | n/a | [ ] |
| adapter forwards `offenders` (Slice B) | [ ] | [ ] | [ ] | [ ] | n/a |
| dashboard overlay, shared bundle (Slice C) | [ ] | [ ] | [ ] | [ ] | n/a |
| contract fixture proven | [ ] | [ ] | [ ] | [ ] | [ ] |

## Tests (written first, real - no mocks, positive + negative)

- [ ] Scanner emits `TINA4-M003` (not `M004`) for a function whose score is
  driven by a fat switch, and `M005` for one driven by parameter count - the
  discriminator actually discriminates (negative: a plain long method is `M004`,
  never `M003`).
- [ ] `--json` carries `rule_id` + `remedy`; a consumer reading only
  `kind`/`severity`/`score` still works (back-compat).
- [ ] `--suggest` prints the remedy string keyed to the id; absent the flag the
  table is byte-identical to today.
- [ ] A retired id is never reused (fixture asserts the tombstone).
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

- (hash  description - one line per landed change)

## Status: Planned
