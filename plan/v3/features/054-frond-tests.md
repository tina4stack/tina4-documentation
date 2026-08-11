# Feature 54: Frond expression tests

## Identity and status

- Matrix identity: 54 - Frond expression tests (`{% if x is defined %}` / `is empty` / `is odd`)
- Audit state: decision-ready
- Audit note: measured 2026-08-11 from four-language Frond source. The test VOCABULARY is at FULL PARITY -
  an identical 11-test set in all four (a rare clean parity); only body-level coercion edges differ. Python
  `frond/engine.py:946` (`46007c1`); PHP `Tina4/Frond.php:3026` (`ab871934`); Ruby `lib/tina4/frond.rb:1742`
  (`f549923`); Node `packages/frond/src/engine.ts:1093` (`1319cf3`).
- Dependencies: the runtime (51), extensibility (56, `add_test`).
- Dependants: `{% if x is ... %}` conditions.
- Existing ADRs: the 72/72 expression-parity corpus.

- Catalog phase: Frond

## Why this feature exists

An expression test is a `is`/`is not` predicate (`{% if x is defined %}`). The audit question is vocabulary
parity - and here it is FULL: the same 11 tests exist in all four. Only a couple of coercion edges (PHP's
`even`/`odd` on a string) differ within the identical set.

## Existing implementation evidence

Measured, all four:

- The `is`/`is not` operator is matched by a dedicated regex and routed to a test evaluator; the built-in test
  set is IDENTICAL in all four: `defined`, `empty`, `null`, `none`, `even`, `odd`, `iterable`, `string`,
  `number`, `boolean`, and `divisible by(n)` (11 tests). No test exists in some languages only. POSITIVE - a
  rare full-vocabulary parity.
- `add_test`/`addTest` overrides a built-in of the same name in all four (feature 56).
- Body-level coercion edges differ within the identical vocabulary: PHP casts `(int)` in `even`/`odd`
  (`Frond.php:3053`), so `"4" is even` is TRUE in PHP but FALSE in py/ruby/node (which require a real integer);
  PHP's `string` test rejects a `RAW_MARKER`-tagged (SafeString/raw) value; PHP folds `""` into `null`/`none`
  while the others keep `null` strictly nil/None/undefined; `empty` edges around `0`/`false` differ slightly.

## Public surface contract

`{% if x is <test> %}` / `{% if x is not <test> %}` with the shared 11-test vocabulary; a custom test via
`add_test`. Behaviour should be identical (it is, except the coercion edges).

## Inputs and outputs

- Input: a value + a test name (+ `divisible by(n)`'s arg). Output: a boolean.

## Lifecycle and operation graph

1. Match `is`/`is not`. 2. Look up the test (custom overrides built-in). 3. Apply the predicate; negate for
`is not`.

## Configuration and precedence

- None. Custom tests shadow built-ins.

## Failures, side effects and security

- No security surface. The only divergences are coercion edges (see the register). No positioned error (the
  Frond no-positions gap, feature 48).

## Wire and persistence contract

The boolean result. No persisted state.

## Providers and substitutability

A future runtime must ship the same 11 tests with identical coercion behaviour.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| TEST-VOCAB-PARITY | POSITIVE (do NOT re-flag): the test vocabulary is at FULL PARITY - the identical 11-test set (`defined`/`empty`/`null`/`none`/`even`/`odd`/`iterable`/`string`/`number`/`boolean`/`divisible by(n)`) exists in all four. A rare clean parity. | Keep; gate it with the corpus so it stays at parity. |
| TEST-EVEN-ODD-COERCE | PHP casts `(int)` in `even`/`odd` (`Frond.php:3053`), so `"4" is even` is TRUE in PHP but FALSE in Python/Ruby/Node (which require a real integer). A behavioural edge within the identical vocabulary. | Pin the `even`/`odd` coercion (real-integer-only, the 3-of-4 majority) across the four. |
| TEST-EMPTY-NULL-EDGES | Minor edges differ: PHP folds `""` into `null`/`none` (`Frond.php:3059`) while the others keep `null` strictly nil/None/undefined; `empty` differs around `0`/`false` (Python `not v`, PHP `empty()`, Ruby explicit `== 0 || == false`, Node array/object special-case); PHP's `string` test rejects a raw-marked value. | Pin the `null`/`empty`/`string` edge behaviour across the four. |

## Owner decisions

- TEST-DEC-01 (proposed): pin the `even`/`odd` coercion (TEST-EVEN-ODD-COERCE) and the `null`/`empty`/`string`
  edges (TEST-EMPTY-NULL-EDGES) so the identical vocabulary also behaves identically; gate with the corpus.
  Note the full-vocabulary parity is a POSITIVE to preserve.

## Proposed conformance fixture

A shared fixture (the expression corpus, extended): each of the 11 tests returns the same boolean across the
four for the same input; `"4" is even` agrees (catches TEST-EVEN-ODD-COERCE); `"" is null` and `0 is empty`
agree; a custom `add_test` overrides a built-in.

## Integration map

- Consumers: `{% if x is ... %}`. Composes: the runtime (51), extensibility (56, custom tests). The 72/72
  corpus covers expression behaviour.

## Breaking changes and migration

- Pinning the `even`/`odd`/`null` edges changes behaviour for those inputs in the outlier (PHP) - a
  consistency fix; note it.

## Porting capsule

Ship the 11 shared tests (`defined`/`empty`/`null`/`none`/`even`/`odd`/`iterable`/`string`/`number`/`boolean`/
`divisible by(n)`) with IDENTICAL coercion - `even`/`odd` require a real integer (do not int-cast a string),
`null` is strictly nil/None/undefined, `empty` handles `0`/`false` the agreed way. Support `is`/`is not` and a
custom `add_test` that shadows a built-in.

## Audit closure checklist

- [x] Boundary and public surface complete (11 tests x four).
- [x] Lifecycle and producer/consumer edges complete (match -> lookup -> apply).
- [x] Configuration, failure and security rules complete.
- [x] Wire (boolean) and provider contracts complete.
- [x] Four-language behaviour recorded (full vocabulary parity; coercion edges).
- [x] Owner ambiguities decided (TEST-DEC-01 coercion/edges).
- [x] Conformance fixture (test parity + edges) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
