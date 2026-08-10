# Feature 017: ORM base class

## Identity and status

- Matrix identity: 17 - ORM base class
- Audit state: decision-ready
- Audit note: measured 2026-07-28 (LOC/CC/MI + real-SQLite behaviour probes below); prose
  sections completed from that evidence 2026-08-10. No framework code changed.
- Dependencies: Feature 3 adapter interface (connection, execute, transaction), Feature 5
  write facade, Feature 6 query builder, Feature 7 SQL translator (where `create_table`'s
  dialect branches belong), Feature 18 ORM fields, Feature 16 get_next_id
- Dependants: every domain model extends this class; AutoCrud, the REST layer, migrations
  and any reflection-driven tooling read its field definitions and relationships
- Existing ADRs: the no-aliases rule (D2), ADR-0002 (metrics used for the measurements);
  Feature 20 (soft delete) owns `is_deleted`
- Shared fixtures: `orm_base_contract.json` is required (the D1 behaviour table plus the
  no-alias and structure gates below)

## Why this feature exists

A developer defines a domain model once and gets save, find, validate, serialize and
relationships from a single base class whose observable behavior is identical in all four
languages, so the same model code and the same tests move between them unchanged.

## Boundary

This feature owns the base model: construction from a map or a JSON object, the
fluent-save contract, find and find-or-fail, validate, serialization, and relationship
wiring. It DELEGATES the SQL to Feature 6/7, the connection and transaction to Feature 3,
the id to Feature 16, the field definitions and column mapping to Feature 18, the
validation rules to Feature 19, and soft delete to Feature 20. `create_table`'s dialect
branching is explicitly OUT of scope: it belongs in the Feature 7 translator (D5).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| File | `orm/model.py`, `orm/fields.py` | `Tina4/ORM.php` | `orm.rb`, `field_types.rb` | `orm/src/baseModel.ts` |
| Size (LOC / fns / CC avg) | 1370 / 86 / 4.49 | 1391 / 79 / 4.66 | 839 / 85 / 3.79 | 1028 / 84 / 3.8 |
| Worst function (CC) | `create_table` (41) | `eagerLoad` (35) | `save` (32) | `save` (37) |
| Maintainability index | 7.3 | 0.0 (floor) | 10.0 (best) | 2.4 |
| Behaviour (D1) | fluent save, null-on-miss, []=valid | same | same | same |
| Serialization aliases (D2) | `to_dict`/`to_assoc`/`to_object` + `to_array`/`to_list` | camel equivalents | camel equivalents | `to_h` + 3 more |
| Relationship declaration (D3) | field option + `has_many()` | `hasMany`/`hasOne`/`belongsTo` | DSL | static arrays |

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

Construct with a map or a JSON object string; a list/array raises. `save()` returns the
model instance (not `true`, not a row count) on success and `false` on a write failure,
without raising. `find(pk)` returns the model or null; `find_or_fail(pk)` returns the model
or raises a named error. `validate()` returns a list of messages, empty when valid, and
never raises. Serialization is ONE map method and ONE list method per language after the
cull (`to_dict`/`to_h`, `to_array`, plus `to_json`); every alias is deleted. Relationships
are declared idiomatically per language (D3) but the OUTCOME is identical: declaring a
foreign key wires both sides. `count()` returns the row count.

## Inputs and outputs

- Input to the constructor is a map or a JSON object string; a list/array is rejected with
  a language-native type error (Python `TypeError`, Ruby `ArgumentError`, equivalents in
  PHP and Node).
- `save()` outputs the model instance (identity, verified `save() is self`) or `false`.
- `find` outputs the model or the language null (`None`/`nil`/`null`); never an empty model.
- `validate` outputs an empty list for a valid model and one message per broken rule.
- Serialization outputs the SAME JSON in all four for the same model (Ruby's symbol keys
  versus Python's string keys collapse to identical JSON); every declared field appears.

## Lifecycle and operation graph

1. Construct: accept a map or JSON object, hydrate declared fields, reject a list.
2. Save: validate, decide insert-versus-update (the branch worth naming), write, then
   refresh the instance from the write result (the generated id from Feature 16/providers).
3. Find: build the SELECT, return the hydrated model or null.
4. Relationships: declaring a foreign key wires `belongs_to` on the declaring model and
   `has_many` on the referenced model, with the has-many name defaulting to the declaring
   class lowercased plus `s`, overridable by one named option; eager-load resolves,
   batch-loads and attaches (the three named steps that replace the `eagerLoad` walk).
5. Serialize: project declared fields to a map/list/JSON.

## Configuration and precedence

- Model metadata (table name, primary key, field definitions, relationships) is declared on
  the class; there is no environment variable and no runtime precedence chain.
- An explicit relationship name option beats the pluralized default.

## Failures, side effects and security

- A failed save returns `false` and does not raise and does not return the model, so a
  caller can branch on the write outcome without a try/catch.
- `validate()` never raises; a broken rule is a message, not an exception.
- A list constructor raises rather than silently building a malformed model.
- Values reach the database only through the bound write facade (Feature 5); the base model
  never concatenates a value into SQL.

## Wire and persistence contract

The persisted shape is the model's declared fields mapped to columns (Feature 18 owns the
property-to-column mapping). The serialized wire shape is the same JSON across all four for
the same model; the cross-framework fixture pins that byte-for-byte. A generated id is read
back into the instance after save.

## Providers and substitutability

The base model runs over any Feature 3 adapter; its behavior (D1) is identical regardless of
the engine underneath. Ruby's structure is the reference to port to (the verdict below); a
future runtime implements the same public surface and passes the same behaviour fixture.

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

Proposed for owner ratification (the D1-D5 measurement forces each):

1. LOCK the behaviour (D1) with the contract suite before any structural work: fluent save
   returns the instance, find returns null on a miss, validate returns an empty list when
   valid, a list constructor raises. All four already agree; the tests defend it.
2. DELETE the serialization aliases (D2), not deprecate them: keep one map method
   (`to_dict`, and `to_h` in Ruby by convention), `to_array`, and `to_json`; remove
   `to_assoc`, `to_object`, `to_list`, `to_hash`. Breaking, with an entry naming every
   removed name across code, docs and the four skills.
3. Keep each language's idiomatic relationship DECLARATION (D3, category 3) but make the
   OUTCOME identical and tested: a foreign key wires both sides, has-many name defaults to
   the pluralized declaring class.
4. PROMOTE Ruby's structure (D5): every method under CC 12; split the four god-methods
   (`create_table`, `eagerLoad`, `save`) into named steps. `create_table`'s dialect
   branches move to the Feature 7 translator, so this step sequences AFTER Feature 3/7.
5. Verdict: UNIFORM on behaviour, PROMOTE Ruby on structure, decided on LOC and CC because
   correctness is already settled.

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

- Every domain model in an application extends this base class; it is the most widely
  consumed public surface in the framework.
- AutoCrud and the REST layer read its field definitions and relationships; migrations use
  its schema; reflection-driven tooling depends on `getFieldDefinitions`-style access.
- Feature 18 supplies fields and column mapping; Feature 19 supplies validation rules;
  Feature 20 supplies soft delete; Feature 7 will receive `create_table`'s dialect code.
- Central fixtures, four runners, the CI matrix, release notes, the ORM docs and the four
  Tina4 skills update together (the alias removal touches the skills).

## Breaking changes and migration

- Alias removal (D2): `to_assoc`, `to_object`, `to_list`, and Ruby `to_hash`/`to_dict` are
  DELETED. The `Breaking:` changelog entry must list every removed name, and the docs pass
  plus the four skills update in the SAME release, because each name is a call site
  somewhere. Migration: replace with `to_dict`/`to_h`, `to_array`, `to_json`.
- The structural god-method split (D5) is internal and not breaking, but sequences AFTER
  Feature 3/7 so `create_table`'s dialect branches have a home in the translator.
- Behaviour (D1) does not change; the contract suite exists to make an accidental change
  during the structural split impossible.

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

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (D1-D5).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete (the fixture table above).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready: measured (the most degraded file set in the matrix), D1-D5 recorded,
5 decisions proposed, contract fixture specified. The IMPLEMENTATION (lock D1, delete
aliases D2, split the god-methods D5) is the build phase and is NOT done. The `create_table`
dialect split depends on Feature 7 landing first, so the structural work sequences after the
Database phase. Decision-ready is not built.
