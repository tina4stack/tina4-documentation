# Feature 19: Input and request validation

## Identity and status

- Matrix identity: 19 - Input and request validation (`tina4_python/validator/__init__.py`;
  `tina4_python/orm/fields.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature with two distinct validators, divergent richness, and real test gaps.
  Measured 2026-08-11. Python `validator/__init__.py:25` + `orm/fields.py:70` (`ebbab30`); PHP
  `Tina4/Validator.php:30` + `Tina4/ORM.php:1551` (`6faabac5`); Ruby `lib/tina4/validator.rb:22` + `orm.rb:994`
  (`6d5b1de`); Node `packages/orm/src/validation.ts:8` (`27cf0f4`).
- Dependencies: the field system (feature 18), the base model (17), AutoCrud (27, Node wires the request
  validator).
- Dependants: every save (ORM validation), route handlers (the request-body validator).
- Existing ADRs: none dedicated.

- Catalog phase: ORM / HTTP

## Why this feature exists

Two things need validating: an incoming request body (a route wants to reject bad input) and a model before
it hits the database (a save should not write an invalid row). Tina4 has BOTH - and the two are separate
mechanisms in all four languages, with different richness and very different test coverage.

## Existing implementation evidence

Two validators per language, universally:

- Request-body `Validator` - a chainable rule builder (`required`/`email`/`min_length`/`max_length`/
  `integer`/`min`/`max`/`in_list`/`regex`, then `errors()`/`is_valid()`). Advisory: the caller inspects it
  and decides. It is AUTO-WIRED only in Node (AutoCrud POST calls it -> HTTP 422); in Python/PHP/Ruby it is
  a manual route-layer helper.
- ORM field validation - runs ON SAVE and is ENFORCED (an invalid model returns `false` without touching the
  driver, all four). Its RICHNESS diverges: Python and Node are RICH (required + type coercion + min/max
  length + min/max value + regex + choices/json/fk); PHP is medium (required/minLength/maxLength/min/max/
  pattern via a `$fields` overlay); Ruby is NULL-ONLY (`string_field length:` is declared but never enforced
  on save).

## Public surface contract

`Validator` (chainable, advisory) for request bodies; `Model.validate()` (enforced on save, returns
errors/false) for models. Contract: an invalid model never reaches the driver; a request validator reports
errors for the caller to act on (or, in Node's AutoCrud, a 422).

## Inputs and outputs

- Input: a request body + rules (Validator), or a model's field values (ORM). Output: an errors list / a
  boolean; or a refused save (`false` + `last_error`).

## Lifecycle and operation graph

1. Request: build a Validator, chain rules, check `is_valid()` (manual, except Node's AutoCrud POST).
2. Save: `validate()` runs first; on any error, set `last_error`, log, return `false` without a DB write.

## Configuration and precedence

- None. Rules are declared inline (Validator) or as field constraints (ORM).

## Failures, side effects and security

- The failure mode is a validation GAP: input that should be rejected is written (Ruby's null-only ORM
  validation; Node's AutoCrud PUT with no validation) or a validator that is entirely untested (Python's
  placeholder tests). See the register.

## Wire and persistence contract

No persisted state. The contract is: `validate()` gates the write; the request Validator's error shape is
`[{field, message}]` (or strings).

## Providers and substitutability

No provider abstraction; rules are fixed methods.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| VALID-PY-UNTESTED | Python's request-body `Validator` (9 rule methods, 169 lines) is BEHAVIORALLY UNTESTED: `tests/test_data_validator.py` and `tests/test_form_validator.py` are each a 2-line `assert True` PLACEHOLDER (named as if they cover it), and the only other reference greps the generated scaffold source string. So `required/email/min_length/max_length/integer/min/max/in_list/regex` have ZERO positive or negative coverage - worse than a skip (two green stubs that look like coverage). | Replace the placeholders with real pos+neg tests for every Validator rule. This is a `feedback_lock_in_tests` / no-mock-necessary-not-sufficient violation. |
| VALID-RUBY-NULLONLY | Ruby's ORM `validate()` checks NULL-ONLY - `string_field length:`, type, and format are declared but NEVER enforced on save (Python/PHP/Node enforce more). So a Ruby model saves an over-length or wrong-format value that the other three reject. Ruby's Validator rules `max_length/max/in_list/regex` are also untested, and a dead `validate_fields` re-implements the null-check with zero callers. | Bring Ruby's ORM `validate()` up to the shared richness (length/type/format), test the Validator rules, and delete the dead `validate_fields`. |
| VALID-NODE-PUT-NOVALIDATE | Node's AutoCrud PUT (update) performs NO request-body validation at all - only POST (create) calls `validate()`. So an update can write type/length/pattern/required-violating data that a create would reject. Also the validator's `isUpdate` partial-update mode is wired into NO framework write path (`save()` always passes `isUpdate=false`, enforcing `required` even on updates). | Validate the AutoCrud PUT body (call `validate(body, fields, isUpdate=true)`); wire the partial-update mode so updates do not spuriously require unrelated fields. |
| VALID-TWO-MESSAGES | The two validators emit DIFFERENT message strings for the same rule (PHP: ORM `"name: is required"` vs Validator `"name is required"`; similar colon/no-colon splits elsewhere), both claiming "Node reference vocabulary". A client keying on one wording will not match the other. | Unify the message vocabulary across the request Validator and the ORM validator (one canonical wording). |
| VALID-PHP-ENFORCE-UNTESTED | PHP's validate-on-save ENFORCEMENT path (`ORM.php:609-617`, "an invalid model never reaches the driver, save() returns false") has NO test - `validate()` is tested only in isolation; no test declares `$fields` AND calls `save()`. | Add a test that a `$fields`-constrained PHP model with invalid data returns false from `save()` and writes nothing. |

## Owner decisions

- VALID-DEC-01 (proposed): fix the untested validators - replace Python's placeholder tests
  (VALID-PY-UNTESTED), test PHP's enforcement path (VALID-PHP-ENFORCE-UNTESTED), and Ruby's Validator rules
  (VALID-RUBY-NULLONLY). Highest value - these are unproven controls.
- VALID-DEC-02 (proposed): close the enforcement gaps - Ruby's null-only ORM validation
  (VALID-RUBY-NULLONLY) and Node's AutoCrud PUT (VALID-NODE-PUT-NOVALIDATE); unify the message vocabulary
  (VALID-TWO-MESSAGES).

## Proposed conformance fixture

A shared fixture: every request-Validator rule has a pos+neg case (catches VALID-PY-UNTESTED); a
constraint-violating model returns `false` from `save()` and writes nothing in all four (catches
VALID-PHP-ENFORCE-UNTESTED and VALID-RUBY-NULLONLY); an AutoCrud PUT with invalid data is rejected (catches
VALID-NODE-PUT-NOVALIDATE); the two validators emit the same message for the same rule.

## Integration map

- Consumers: route handlers (Validator), every save (ORM validate), AutoCrud (27, Node wires POST). Composes
  the field constraints (18).

## Breaking changes and migration

- Enforcing Ruby length/format and validating the Node PUT changes behaviour (previously-accepted input now
  rejected) - a correctness fix; document it. Unifying messages changes error strings - document it.

## Implementation backlog

1. VALID-DEC-01: real tests for the untested validators (Python placeholders, PHP enforcement, Ruby rules).
2. VALID-DEC-02: Ruby richer ORM validation; Node AutoCrud PUT validation; unified message vocabulary.

## Porting capsule

Validation needs TWO surfaces kept consistent: a request-body validator (chainable rules, a clear error
shape) and an ORM field validator that runs ON SAVE and refuses the write (returns false, writes nothing).
Both must be REAL-tested (no `assert True` placeholders), the ORM validator must enforce the same richness in
every language (not null-only), create AND update paths must both validate (AutoCrud PUT included), and the
two validators must speak one message vocabulary.

## Audit closure checklist

- [x] Boundary and public surface complete (the two validators x four).
- [x] Lifecycle and producer/consumer edges complete (request check, validate-on-save).
- [x] Configuration, failure (validation gaps) and security rules complete.
- [x] Wire (error shape) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (richness, wiring, test gaps).
- [x] Owner ambiguities decided (VALID-DEC-01/02).
- [x] Conformance fixture (per-rule + enforcement + PUT) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
