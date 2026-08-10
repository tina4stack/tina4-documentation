# Feature 017: ORM base class

## Identity and status

- Matrix identity: 17 — ORM base class
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

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 1. **Planning only.**

**Status: CLOSED.**

### Files

| | path |
| --- | --- |
| python | `tina4_python/orm/model.py`, `orm/fields.py` |
| php | `Tina4/ORM.php` |
| ruby | `lib/tina4/orm.rb`, `lib/tina4/field_types.rb` |
| node | `packages/orm/src/baseModel.ts` |

### Measurements

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 1370 | 86 | 386 | 4.49 | `create_table` (**41**) | 7.3 | **7 error**, 4 warn |
| php | 1391 | 79 | 368 | 4.66 | `eagerLoad` (**35**) | **0.0** | 2 error, 10 warn |
| ruby | 839 | 85 | 322 | 3.79 | `save` (**32**) | 10.0 | 3 error, 4 warn |
| node | 1028 | 84 | 319 | 3.8 | `save` (**37**) | 2.4 | 4 error, 5 warn |

**The most degraded file set in the audit.** Four functions above CC 30, PHP's
maintainability index at literal 0.0, seven scanner errors in Python. Ruby leads
all three metrics again (leanest 839, simplest 3.79, best MI 10.0) at a 1.7x spread.

And the worst function is a **different** one in three of four: Python's is
`create_table`, PHP's is `eagerLoad`, Ruby's and Node's are `save`. Each framework
grew its own god-method in the same class.

### Note for feature 19 (soft delete)

`01-FEATURE-MATRIX.md` names feature 19 "Soft delete (**deleted_at**, restore,
withTrashed)". The column is `is_deleted` (INTEGER 0/1) in all four - every
CLAUDE.md says so explicitly, and Python's says "There is no `deleted_at` column".
So the feature matrix itself carries a stale name for the row. Fix it when feature 19 is audited; recorded here so it is not lost.

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

### What differs

**D1. The behavioural contract is already identical, and that is the good news.**
Same model, same operations, real SQLite, Python and Ruby side by side:

| | python | ruby |
| --- | --- | --- |
| `save()` returns | the model instance (`is self? True`) | the model instance (`is self? true`) |
| serialise | `{'id': 1, 'name': 'alice'}` | `{id: 1, name: "alice"}` |
| `find(1)` | the model | the model |
| `find(999)` | `None` | `nil` |
| `validate()` on a valid model | `[]` | `[]` |
| constructor with a list/array | raises `TypeError` | raises `ArgumentError` |
| `count()` | 1 | 1 |

That is the fluent-save contract, the null-on-miss contract, the empty-list-means-
valid contract and the reject-a-list constructor, all agreeing. Ruby's symbol keys
versus Python's string keys is category 3 - both serialise to the same JSON. This
row is not a behavioural rescue; it is a structural one.

**D2. Every framework ships three names for one serialisation.** Per the CLAUDE.md
files, `to_assoc` and `to_object` are documented aliases of `to_dict`, and `to_list`
is a documented alias of `to_array`:

| framework | dict form | array form |
| --- | --- | --- |
| python | `to_dict`, `to_assoc`, `to_object` | `to_array`, `to_list` |
| php | `toDict`, `toAssoc`, `toObject` | `toArray`, `toList` |
| node | `toDict`, `toAssoc`, `toObject` | `toArray`, `toList` |
| ruby | `to_h` (+ `to_hash`, `to_dict`, `to_object` per docs) | `to_array`, `to_list` |

Five to six methods doing two jobs, in all four. The no-aliases rule is explicit:
rename the primary, never keep an alias for parity. This is the same violation as
Node's `Log.warn`, at four times the scale, and it is pure surface bloat - every
one of those names is another thing to document, test and keep in step.

**D3. Relationships are declared four different ways.**

| framework | declaration |
| --- | --- |
| python | `ForeignKeyField(to=Author, related_name="posts")` on the field, plus imperative `has_many()` |
| php | `hasMany()` / `hasOne()` / `belongsTo()` methods |
| ruby | `has_many :posts, class_name:` DSL, plus `foreign_key_field :user_id, references: User` |
| node | `static hasMany = [{model, foreignKey}]` arrays, plus `type: "foreignKey", references: "Author"` in `static fields` |

Node is the outlier in kind: relationships are **static data**, not method calls.
That is defensible and arguably the cleanest of the four, but it means the same
concept is a field option in Python, a class-level DSL in Ruby, a method in PHP and
a static array in Node. A developer moving between them re-learns the concept every
time. The *outcome* to converge on is the one all four already agree about:
declaring a foreign key auto-wires both sides.

**D4. Each framework has private helpers the others lack, and some are load-bearing.**
PHP alone has `fill`, `markAsExisting`, `getFieldDefinitions`, `camelToSnake` /
`snakeToCamel`, `resolveFkValue`, `defaultForeignKey`. Ruby alone has `from_hash`,
`auto_map`, `field_mapping`, `persisted?`, `soft_delete_field`, `auto_crud`,
`singularize`. Node alone has `getReverseMapping`, `registerModel`, `setAdapter`.
Some are genuine capability gaps (Ruby's `persisted?` answers a question the other
three cannot; PHP's `getFieldDefinitions` is what makes reflection-driven tooling
possible), and some are the same idea under three names (`camelToSnake` /
`auto_map` / `getReverseMapping` are all property-to-column mapping - which is
feature 17 and gets decided there).

**D5. Four god-methods, four different ones.** `create_table` 41, `eagerLoad` 35,
`save` 37 and 32. Each is doing dialect branching, relationship walking or field
iteration inline. This is the same disease as feature 30's dispatch and feature 2's
`configure`, and it is why PHP's MI reads 0.0.

### Verdict: PROMOTE ruby on structure, UNIFORM on behaviour

Decided on **LOC and CC**, because correctness is already settled (D1).

Ruby is the leanest, simplest-per-function and most maintainable of the four while
implementing the same contract, so its structure is the model. It is also the only
one whose worst function is under 33.

Nothing to promote on behaviour - all four agree, and that agreement is worth
locking in with tests before any structural work starts, exactly as feature 30 does.

D2 (the alias sprawl) and D5 (the god-methods) are the work. Both are category 4.

### Risks

- **D2 is breaking and wide.** Every removed alias is a call site somewhere,
  including in the docs and the four skills. The `Breaking:` entry must list all of
  them, and the docs pass has to run in the same release.
- **D5 depends on feature 3.** Splitting `create_table` before the translator
  consolidation means moving the dialect code twice.
- **Do not touch D1.** The behaviour is right in all four; the temptation during a
  structural split is to "improve" a return value. The contract suite exists to
  make that impossible.

## Owner decisions

No new owner decision is recorded in this migrated section. Retained decisions appear below when present.

## Proposed conformance fixture

### Tests to write

Real SQLite, one model defined identically in all four. No mocks.

| pair | positive | negative |
| --- | --- | --- |
| fluent save | `save_returns_the_model_instance` - identity, not a truthy value | `save_does_not_return_true_or_the_row_count` |
| failed save | `save_returns_false_when_the_write_fails` | `a_failed_save_does_not_raise_and_does_not_return_the_model` |
| miss is null | `find_returns_null_for_a_missing_primary_key` | `find_does_not_return_an_empty_model_for_a_miss` |
| find or fail | `find_or_fail_raises_a_named_error_for_a_miss` | `find_or_fail_does_not_return_null` |
| constructor | `constructor_accepts_a_map_and_a_json_object_string` | `constructor_raises_on_a_list` - all four, the shape already verified |
| validation | `validate_returns_an_empty_list_for_a_valid_model` | `validate_returns_one_message_per_broken_rule_and_never_raises` |
| serialisation | `to_dict_returns_every_declared_field` | `no_framework_exposes_an_alias_for_to_dict_or_to_array` - kills D2 permanently |
| relationships | `declaring_a_foreign_key_wires_both_sides` | `the_has_many_name_defaults_to_the_declaring_class_pluralised` |
| structure | `no_orm_method_exceeds_complexity_twelve` - asserted from `tina4 metrics --json` | `create_table_declares_no_dialect_branch` - the D5/feature-3 boundary |
| cross-framework | `all_four_serialise_the_same_model_to_the_same_json` - one committed fixture | `no_framework_emits_a_field_the_others_lack` |

The `no_framework_exposes_an_alias` pair is the one that matters most long-term: an
alias deleted without a test guarding the deletion comes back the first time
somebody wants a convenience name.

## Integration map

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

## Breaking changes and migration

The audit has not yet turned every parity break into an actionable pre-3.14 migration instruction.

## Implementation backlog

### Methodology

1. **Lock the behaviour first.** The D1 contract is currently correct in all four
   and undefended - no test asserts that `save()` returns the instance in all four,
   or that a list constructor raises in all four. Write the contract suite below and
   get it GREEN before touching structure. Same safety argument as feature 30.
2. **Delete the aliases (D2).** Mechanical, and it shrinks the surface before the
   harder work. Breaking, so it needs a `Breaking:` entry naming every removed
   name. Do this second because every later step touches fewer methods afterwards.
3. **Split the god-methods (D5)**, one per commit, re-running the contract suite
   after each. Ruby first (already the best structure, so the smallest diff proves
   the pattern), then Node, Python, PHP last - PHP has the most to gain (MI 0.0)
   and the most to break.
4. `create_table`'s dialect branches move to `SQLTranslator`, which requires
   **feature 3 to land first**.
5. Re-measure. Target: no method above CC 12 in any framework, PHP's MI off the
   floor, and no regression in Ruby.

## Porting capsule

### Pattern

**One serialiser pair, one relationship concept, no method above CC 12.**

Serialisation, after the cull:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| to a map | `to_dict(include=None)` | `toDict($include = null)` | `to_h(include: nil)` | `toDict(include?)` |
| to a list of values | `to_array()` | `toArray()` | `to_array` | `toArray()` |
| to JSON | `to_json(include=None)` | `toJson($include = null)` | `to_json(include: nil)` | `toJson(include?)` |

`to_assoc`, `to_object`, `to_list`, `to_hash` are **deleted**, not deprecated. Ruby
keeps `to_h` as its primary because that is the Ruby convention for a map
conversion (category 3), and `to_dict` goes; the other three keep `toDict`/`to_dict`.
That is one name per language per concept, three concepts, twelve names instead of
the current twenty-plus.

Relationships: keep each language's idiomatic declaration (category 3) but make the
**outcome** identical and testable - declaring a foreign key wires `belongs_to` on
the declaring model and `has_many` on the referenced model, with the has-many name
defaulting to the declaring class lowercased plus `s` and overridable by one named
option. That default is already agreed and already shipped in all four; the plan's
job is to lock it with the tests below rather than change it.

Structure: every method under CC 12, which means splitting the four god-methods:

- `create_table` (Python 41) - split per engine. The dialect branching belongs in
  the `SQLTranslator` that feature 3 is already consolidating, not in the ORM.
- `eagerLoad` (PHP 35) - split into `resolveRelationship`, `batchLoad`,
  `attachResults`. Three named steps instead of one walk.
- `save` (Node 37, Ruby 32) - split into `validateBeforeSave`, `buildWriteData`,
  `insertOrUpdate`, `refreshFromWrite`. The insert-versus-update decision is the
  branch worth naming.

Same discipline as feature 30, and it depends on feature 3 landing first because the
dialect helpers have to have somewhere to go.

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

Not implemented. Sequenced after feature 3 (which gives `create_table`'s dialect
branches a home). Full order now: 6, 4, 5, 3, 13, then 2, 1, 0.
