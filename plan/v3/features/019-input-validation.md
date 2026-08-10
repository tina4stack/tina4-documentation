# Feature 019: Input and request validation

## Identity and status

- Matrix identity: 19 - Input and request validation
- Audit state: decision-ready
- Audit note: measured 2026-07-28, verdict REVISED by execution 2026-07-30; prose sections
  completed from that evidence 2026-08-10. No framework code changed.
- Dependencies: Feature 17 ORM base class (`validate()` lives on the model), Feature 18 ORM
  fields (the constraint options are declared there)
- Dependants: every route that builds a model from request input and returns a 400 with the
  messages; AutoCrud; the four CLAUDE.md docs that show the collect-then-inspect pattern
- Existing ADRs: the no-aliases rule (the `nullable`->`required` rename), the inverted-flag
  lesson from Feature 2 (`production` vs `development`)
- Shared fixtures: `validation_contract.json` is required; it is pure in-memory (no DB), the
  cheapest suite in the audit, and its cross-framework message case is the point

## Why this feature exists

A developer builds a model from request input, calls `validate()`, and returns a 400 with
the collected messages when it is not empty. That one pattern must work identically in all
four. Today PHP validates nothing, Python raises before `validate()` is reached, and Ruby
checks only nullability, so the same route returns a 400, a 500, or silently accepts bad
input depending on the language.

## Boundary

This feature owns `validate()`, the constraint vocabulary (`required`, `min_length`,
`max_length`, `min`, `max`, `pattern`), and the message format. It DELEGATES field
declaration to Feature 18 and the model itself to Feature 17. A TYPE error (assigning a dict
to an integer field) is a programming error and stays a raise; a CONSTRAINT violation is user
input and is always collected, never raised. The DDL sizing hint `length` is out of scope for
validation; it sizes the column only.

## Existing implementation evidence

| Evidence (verified by execution 2026-07-30) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `validate()` mechanism | SPLIT: length/type raise, rest collect | NONE - `return []` stub (ORM.php:1440) | nullability only | full, collect-only |
| Constraint vocabulary | full (options exist) | full in docs, NONE in code | `nullable:` only | full |
| Raises at assignment | YES (D1) | no | no | no |
| Over-long value on a route | 500 (unhandled) | silently accepted | silently accepted | 400 with message |
| Result shape | list of messages | always `[]` | list (nullability) | `string[]` "<field> <msg>" |
| Verdict role | P1 (stop raising) | GAP (build it) | build vocabulary + rename | REFERENCE (promote) |

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 8 (last). **Planning only.**

**Status: CLOSED, VERDICT REVISED.** All four verified by execution (2026-07-30).
PHP's `validate()` is a stub that returns `[]`, so the parked SYNTHESISE verdict was
leaning on an implementation that does not exist. Now PROMOTE node + GAP (php) +
P1 (python). See Outstanding below.

## Public surface contract

`validate()` returns a list of message strings, empty when the model is valid, and never
raises for a constraint violation. The constraint vocabulary is `required`, `min_length`,
`max_length`, `min`, `max`, `pattern`, declared on the field (Feature 18) with identical
option names in all four (Ruby's `nullable: false` is RENAMED to `required: true`, not
aliased). The DDL sizing hint `length` is a separate option that never validates. Each
message is formatted `"<field>: <what was wrong>"`.

## Inputs and outputs

- Input: a model whose fields declare constraints, populated from request input.
- Output: a list of strings, one per violated constraint, empty when valid. Never null,
  never `false`, never a raised exception for a constraint.
- A single bad value can produce one message; an empty model produces one `required` message
  per missing field.
- Message text is stable and identical across the four for the same bad model (the
  cross-framework fixture pins the strings).

## Lifecycle and operation graph

1. A route builds a model from request input; construction stores values and does NOT raise
   for a constraint violation (an over-long value is stored, to be reported by `validate()`).
2. Construction MAY raise only for a type error the value cannot survive (a dict assigned to
   an integer field) -- a programming error, not user input.
3. `validate()` walks the field constraints and collects every violation into the list.
4. The caller returns a 400 with the list when it is non-empty, or proceeds when it is empty.

## Configuration and precedence

- The constraint options are declared per field; there is no environment variable.
- `length` (DDL size) and `max_length` (validation) are distinct options; a column can be
  `VARCHAR(255)` while the value is capped at 50.
- `nullable` is removed in favour of `required` (inverted polarity); the old option name is
  REJECTED with a clear error, never silently reinterpreted.

## Failures, side effects and security

- SECURITY: `validate()` that returns `[]` unconditionally (PHP today) means every model
  following the documented `errors = validate()` pattern silently ACCEPTS invalid input.
  This is a shipped-but-absent feature and the sharpest gap in the audit; validation must
  actually check.
- A constraint violation is collectable user input and must NEVER become a 500; Python's
  raise-at-assignment (D1) turns the documented 400 into a 500 and is a P1.
- A type error (dict into an integer field) still raises, because it is a programming error;
  it is not returned as a validation message.
- `validate()` has no side effects: it reads the model and returns messages, touching no
  database and no external state.

## Wire and persistence contract

There is no persistence; the wire contract is the MESSAGE SET. For one model with one set of
bad values, all four produce the same list of messages, so a 400 body reads the same
regardless of language. That message fixture is the artifact that turns four divergent
behaviours into one contract.

## Providers and substitutability

Validation is pure in-memory and engine-agnostic; it needs no database and no provider. A
future runtime implements `validate()` with the same vocabulary and the same message strings
and passes the same fixture.

## Contradictions and defects

### What differs

**D1. Python enforces length by RAISING at assignment, not by returning a validation
error.** Verified - a model with `StringField(required=True, max_length=5)`, then
constructed with a 12-character value:

```
ValueError: Field 'name': maximum length is 5, got 12
```

The exception fires during construction. `validate()` is never reached. So Python has
**two enforcement mechanisms with different shapes**: length and type constraints
raise at assignment, while `required` and the rest are collected by `validate()` into
a list.

That matters for the documented usage. Every CLAUDE.md shows the collect-then-inspect
pattern:

```
errors = model.validate()      # -> list of messages, empty means valid
```

A route that follows it, builds a model from `request.body` and then calls
`validate()` to return a 400 with the messages **never gets the chance** - the
constructor already threw, and an unhandled `ValueError` becomes a 500 instead of a
validation response. The documented pattern works for some constraints and is
bypassed by others, with no indication which is which.

**D2. Ruby's `validate` checks nullability and nothing else.** Read from source:

```ruby
def validate
  errors = []
  self.class.field_definitions.each do |name, opts|
    if !opts[:nullable] && value.nil? && !opts[:auto_increment] && !opts[:default]
      errors << "#{name} cannot be null"
    end
  end
  errors
end
```

One rule. No length, no min, no max, no pattern. A Ruby model declaring
`string_field :name, length: 5` accepts a 500-character name and `validate` returns
`[]`. The `length:` option is a **DDL hint only** - it sizes the column and never
validates the value.

**D3. Ruby's field vocabulary is different, and one option is inverted.**

| constraint | python | ruby |
| --- | --- | --- |
| must be present | `required=True` | **`nullable: false`** |
| maximum length | `max_length=5` | **`length: 5`** (DDL only) |
| minimum length | `min_length=2` | **absent** |
| numeric bounds | `min_value` / `max_value` | **absent** |
| pattern | `pattern=...` | **absent** |

Ruby's full field DSL, read from source, accepts only
`(name, length:, primary_key:, auto_increment:, nullable:, default:, precision:, scale:)`.
There is no vocabulary for a value constraint beyond nullability.

`required: true` versus `nullable: false` is the same inverted-flag defect as feature 2's `production` versus `development`: one concept, two spellings, opposite polarity.
A developer porting a model between the two has to remember to flip it, and the code
runs either way.

**D4. So "validation from field definitions" means four different things.** PHP and
Node both document the fuller option set (`required`, `minLength`, `maxLength`, `min`,
`max`, `pattern`), and Node has a dedicated `validation.ts`. Python has the options
but splits enforcement across a raise and a list. Ruby has one rule and no
vocabulary. The matrix row claims a feature that only partly exists in two of four.

### Verdict: SYNTHESISE, leaning on PHP/Node's option set

Decided on **correctness of the contract**, with D1 as the decisive point.

Nobody is fully right. PHP and Node have the right option vocabulary. Python has the
options and the wrong enforcement split. Ruby has neither the vocabulary nor the
checks. Nothing to promote wholesale.

The decisive issue is D1, because it makes the documented pattern unreliable rather
than merely incomplete: a framework that raises where its own docs say it collects
turns a 400 into a 500.

All category 4. Every language can collect errors into a list.

### Risks

- **Python's change is breaking.** Any code relying on the constructor raising as a
  guard stops getting an exception. `Breaking:` entry, and worth a release-note
  callout because it silently changes control flow rather than failing loudly.
- **Ruby's `nullable` to `required` rename is breaking for every model** that
  declares it. This is the second inverted-flag rename in the audit (feature 2 was
  the first), and the same mitigation applies: reject the old option name with a
  clear error rather than silently reinterpreting it. A silent polarity flip is the
  worst possible failure mode.
- Ruby gaining five constraints is additive and safe on its own.

## Owner decisions

Proposed for owner ratification (the execution evidence forces each):

1. `validate()` COLLECTS every constraint violation into a list and never raises for a
   constraint; a valid model returns an empty list. This is the contract in all four.
2. PROMOTE Node as the reference (the only complete, collect-only implementation with the
   full vocabulary).
3. PHP is a GAP to build: replace the `return []` stub with real checks. This is the
   sharpest finding -- a shipped, documented feature that validates nothing -- and should be
   treated as the highest-priority defect in this feature.
4. Python stops raising a constraint at assignment and collects instead (D1, P1). Breaking:
   code relying on the raise as a guard loses it; needs a `Breaking:` entry and a release
   callout because it silently changes control flow.
5. Ruby gains the five missing constraints AND renames `nullable: false` to `required: true`
   (inverted polarity), rejecting the old option name with a clear error -- never a silent
   polarity flip.
6. One message format `"<field>: <what was wrong>"` and one option vocabulary
   (`required`, `min_length`, `max_length`, `min`, `max`, `pattern`); `length` stays a
   DDL-only sizing hint distinct from `max_length`.

### Outstanding: CLOSED by execution (2026-07-30), and it CHANGES the verdict

Probed with a model declaring every constraint the docs claim, then constructed with
a value violating each one, then constructed empty so `required` must fire.

**PHP validates nothing. `ORM::validate()` is a stub.**

```php
// Tina4/ORM.php:1440
public function validate(): array
{
    return [];
}
```

That is the only `validate()` in the ORM, and `ORM.php` contains no occurrence of
`minLength`, `maxLength`, `pattern` or any other constraint check. Confirmed by
execution:

```
PHP validate() on a model violating length, min, max and pattern : array ( )
PHP validate() on a completely empty model (required must fire)  : array ( )
```

**Node implements the documented contract in full, and is the only framework that
does.** Real messages, collected not raised:

```
name  = "aaaaaaaaaaaa" (maxLength 5) -> "name must be at most 5 characters"
age   = 999            (max 65)      -> "age must be at most 65"
email = "not-an-email" (pattern)     -> "email does not match required pattern"
empty model                          -> "name is required"
assignment of an over-length value   -> no raise; the value is stored
```

Node returns `string[]` shaped `"<field> <message>"`; internally `validation.ts`
carries `{field, message}` objects and `BaseModel.validate()` flattens them.

#### The corrected picture

| | mechanism | vocabulary | raises at assignment |
| --- | --- | --- | --- |
| python | **split**: length/type raise, the rest collect | full | **yes (D1)** |
| php | **none - `return []`** | none in code; full in docs | no |
| ruby | nullability only | `nullable:` only | no |
| node | full, collect-only | full | no |

**This overturns the verdict recorded below.** It was written as "SYNTHESISE, leaning
on PHP/Node's option set" on the strength of PHP and Node both *documenting* the fuller
vocabulary. PHP implements none of it. There is nothing to synthesise from PHP, so the
row is:

**Revised verdict: PROMOTE node, plus GAP (php) and a P1 (python).**

- **node** is the reference: the full option set, collected into a list, no raise.
- **php is a GAP, and the sharpest kind**: a feature the matrix counts as shipped,
  with a documented option vocabulary, backed by a method that returns an empty array.
  Every PHP model that follows the documented `errors = model->validate()` pattern
  has been silently accepting invalid input.
- **python's D1 stays a P1** for the reason already recorded: it raises where its own
  docs say it collects, so a route following the documented pattern returns 500
  instead of 400.
- **ruby needs the vocabulary built**, and `nullable: false` reconciled with
  `required: true` (the inverted-flag defect from feature 2).

This is the second time in this audit that a verdict formed from documentation
disagreed with the code (the first was the messenger pilot). Both were caught by
running it.

## Proposed conformance fixture

### Tests to write

Pure in-memory - no DB needed to validate a model, which makes these the cheapest
tests in the audit.

| pair | positive | negative |
| --- | --- | --- |
| collect, never raise | `an_over_long_value_is_reported_by_validate` | `constructing_a_model_with_a_bad_value_does_not_raise` - the exact Python reproduction |
| every constraint | `validate_reports_required_min_length_max_length_min_max_and_pattern` | `no_constraint_is_silently_unchecked` - the Ruby reproduction |
| length vs max_length | `a_ddl_length_hint_does_not_validate_the_value` | `max_length_validates_and_length_does_not` |
| polarity | `required_true_means_the_field_must_be_present` | `no_framework_spells_the_same_constraint_with_inverted_polarity` - kills `nullable: false` |
| message format | `every_message_starts_with_the_field_name` | `no_message_omits_which_field_failed` |
| all-clear | `a_valid_model_validates_to_an_empty_list` | `validate_never_returns_null_or_false_for_a_valid_model` |
| type errors still raise | `assigning_a_dict_to_an_integer_field_raises` | `a_type_error_is_not_returned_as_a_validation_message` |
| cross-framework | `all_four_produce_the_same_messages_for_the_same_bad_model` - one fixture | `no_framework_reports_a_violation_the_others_miss` |

The collect-never-raise pair is the one that changes behaviour a user sees: it is the
difference between a 400 with a useful body and a 500.

## Integration map

- Route handlers build a model from request input and call `validate()` to return a 400;
  this is the most common validation consumer.
- Feature 18 declares the constraint options on the field; Feature 17 hosts `validate()`.
- AutoCrud validates before a write; the four CLAUDE.md docs show the collect-then-inspect
  pattern and must match the corrected behaviour.
- Central fixtures, four runners, the CI matrix, release notes and the ORM/validation docs
  update together (the docs currently describe a pattern PHP does not implement).

## Breaking changes and migration

- Python: `validate()`-related construction no longer raises for a constraint; a route that
  relied on the constructor raising as a guard must call `validate()` instead. `Breaking:`
  entry plus a release-note callout, because it silently changes control flow from a 500 to
  a collectable 400.
- Ruby: `nullable: false` becomes `required: true` (inverted). The old option name is
  rejected with a clear error, never silently reinterpreted -- a silent polarity flip is the
  worst possible failure mode. `Breaking:` entry; every Ruby model declaring `nullable`
  migrates.
- PHP and Node: message wording aligns; PHP additionally gains the real checks (a fix, not a
  break, since the old behaviour validated nothing).

## Implementation backlog

### Methodology

1. Close the Outstanding item first - the canonical message strings come from
   whichever of PHP/Node already has the best ones.
2. Build the shared message fixture: one model, one set of bad values, one expected
   message list, read by all four suites.
3. Write the tests below. Expect red in all four: Python on the raise, Ruby on five
   missing constraints plus the rename, PHP and Node on message wording.
4. **Python first** - D1 is the correctness bug and the smallest change: stop raising
   on a constraint, collect instead. It is also breaking, so it needs its own
   `Breaking:` entry (code that relies on the raise as a guard exists).
5. **Ruby second** - the largest build: five constraints plus the `nullable` to
   `required` rename, which is breaking for every Ruby model that declares
   `nullable: false`.
6. PHP and Node: align message wording only.

## Porting capsule

### Pattern

**`validate()` collects every constraint violation. Constructing a model never
raises for a constraint violation.**

1. **Assignment does not raise on a constraint.** Setting an over-long value stores
   it and `validate()` reports it. A raise is reserved for a **type** error the value
   cannot survive (assigning a dict to an integer field), which is a programming
   error, not user input. User input is always collectable.
2. **One option vocabulary in all four**, from PHP and Node's set:
   `required`, `min_length`, `max_length`, `min`, `max`, `pattern`.
   Ruby gains all six. `nullable` is **renamed** to `required` with inverted meaning,
   not aliased - per the no-aliases rule, and because keeping both spellings of an
   inverted flag is the worst outcome.
3. **`length` stays as the DDL sizing hint** and is distinct from `max_length`, which
   validates. Ruby currently conflates them; separating them is what lets a column be
   `VARCHAR(255)` while the value is capped at 50.
4. **One message format**, so a 400 body reads the same from any framework:
   `"<field>: <what was wrong>"` - `"name: maximum length is 5, got 12"`,
   `"email: is required"`, `"age: must be at least 18"`.
5. **`validate()` returns a list of strings and never raises.** Empty means valid.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| validate | `validate() -> list[str]` | `validate(): array` | `validate` | `validate(): string[]` |
| required | `required=True` | `'required' => true` | `required: true` | `required: true` |
| max length | `max_length=5` | `'maxLength' => 5` | `max_length: 5` | `maxLength: 5` |
| DDL size | `length=255` | `'length' => 255` | `length: 255` | `length: 255` |

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (D1-D4 plus the PHP-stub finding).
- [x] Owner ambiguities recorded (6 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete (pure in-memory message fixture).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready, verdict REVISED by execution (2026-07-30): PROMOTE Node, GAP (PHP
`validate()` is a `return []` stub -- shipped but absent), P1 (Python raises where its docs
collect), Ruby needs the vocabulary built plus the `nullable`->`required` rename. The
IMPLEMENTATION is the build phase and is NOT done. The PHP gap is a live correctness/security
issue on the shipping branch (silent accept of invalid input), so it should lead the build.
Decision-ready is not built.
