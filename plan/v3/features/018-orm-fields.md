# Feature 18: ORM fields and column mapping

## Identity and status

- Matrix identity: 18 - ORM fields and column mapping (`tina4_python/orm/fields.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature with a STRUCTURAL divergence in the field-declaration model. Measured
  2026-08-11. Python `orm/fields.py:18` (field OBJECTS, `ebbab30`); PHP reflection on typed properties
  (`Tina4/ORM.php:2087` `logicalTypeFor`, `6faabac5`); Ruby DSL class-methods (`lib/tina4/field_types.rb`,
  `6d5b1de`); Node declarative `FieldDefinition` objects (`packages/orm/src/types.ts:1`, `27cf0f4`).
- Dependencies: the base model (feature 17), validation (feature 19), the DDL builder (`create_table`).
- Dependants: every model column, migrations DDL, the seeder, instance loading (26).
- Existing ADRs: none dedicated; the orm-gaps memory (callable defaults + natural-key).

- Catalog phase: ORM

## Why this feature exists

A field declares a column's type, default, constraints, and DB name. It drives the DDL, the write coercion,
and the read hydration. How a developer DECLARES a field is the ORM's most visible surface - and it is
exactly where the four frameworks diverge structurally.

## Existing implementation evidence

The field-DECLARATION model is different in each language (the headline finding):

- Python (the master): real FIELD OBJECTS - `class Field` + `IntegerField`/`StringField`/`BooleanField`/
  `FloatField`/`DateTimeField`/`TextField`/`BlobField`/`NumericField` (a factory) + `class JSONField` +
  `ForeignKeyField` (which auto-wires `belongs_to` + `has_many`).
- PHP: NO field objects - a field is a declared typed public property; its logical type is inferred by
  reflection (`logicalTypeFor` -> int/float/bool/datetime/json/string). JSON = an `array`-typed property.
- Ruby: NO field objects - DSL class-methods (`integer_field`, `string_field`, `json_field`,
  `foreign_key_field`) that register a symbol-typed Hash (`{type: :integer, ...}`).
- Node: NO field objects - a declarative `FieldDefinition` object with a `type` string union
  (`"integer"|"json"|...`).

Shared behaviour on top of the divergent declaration:

- Column mapping: `field_mapping` (prop -> db column) + `autoMap` (camel<->snake). PHP/Node auto-map;
  Ruby's `auto_map` is deliberately INERT (Ruby is snake_case-native).
- Callable defaults: SUPPORTED in Python (`_resolve_default`), Ruby (per-instance + Marshal deep-copy), and
  Node (`structuredClone`) - resolved per instance, dropped from DDL. NOT supported in PHP (reflection
  statics only) - the one gap.
- Coercion on WRITE is JSON-only in PHP/Ruby/Node (JSON serialized, scalars pass through); Python runs the
  full `Field.validate()` on both write and read (feature 26). DDL is engine-aware (JSON -> JSONB/JSON/
  NVARCHAR(MAX)/TEXT/BLOB SUB_TYPE TEXT).

## Public surface contract

Declare fields (objects / typed properties / DSL / declarative objects), optionally `field_mapping`. The
contract is: a field maps to a column with a type, an optional default (including callable), and JSON round-
trips to a native object.

## Inputs and outputs

- Input: field declarations + values. Output: DDL column types, coerced write values (JSON serialized), and
  hydrated read values (JSON parsed).

## Lifecycle and operation graph

1. Declare fields; the metaclass/reflection/DSL collects them.
2. On construct: seed defaults (callable resolved per-instance).
3. On save: map prop -> column, JSON-serialize json fields.
4. On `create_table`: emit engine-aware DDL (callable defaults dropped).

## Configuration and precedence

- `field_mapping` overrides the auto-map; `TINA4_ORM_PLURAL_TABLE_NAMES` (table only). No field-specific env.

## Failures, side effects and security

- JSON serialization fail-loud (a non-serializable value -> `save()` returns false + logged, all four). No
  security surface.

## Wire and persistence contract

Field -> column (name via mapping, type via the declaration). JSON is the one type with an explicit
serialize/parse contract in all four; other scalars rely on the driver's typing.

## Providers and substitutability

The DDL type per engine is the substitution axis (engine-aware). No plugin abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| FIELD-MODEL-DIVERGENCE | STRUCTURAL: the field-declaration surface is different in all four - Python real field OBJECTS (`IntegerField(...)`), PHP reflection on typed properties, Ruby DSL class-methods, Node declarative `{type}` objects. A model written for one is not portable to another, and a 5th-language port has no single canonical model to follow. | OWNER DECISION: pick the canonical field-declaration model for the framework (Python's field objects are the master's; the other three chose non-object idioms). Either bless the divergence as intentional per-language idiom and document it, or converge. This is the biggest ORM parity call. |
| FIELD-CALLABLE-DEFAULT-PHP | Callable defaults are supported in Python/Ruby/Node (resolved per-instance, dropped from DDL) but NOT in PHP (defaults come from reflection statics only). A `default = () => uuid()` style default is impossible in PHP. | Add callable/closure default support to PHP (resolve per-instance, drop from DDL) - closes the one parity gap in this feature. |
| FIELD-ENGINE-DDL-MOCK | Python's cross-engine DDL type mapping (MySQL `BOOLEAN`, MSSQL `BIT`, Firebird `INTEGER`) is covered ONLY by a MOCK test (`test_orm_v3_13_11::test_engine_dispatch` monkeypatches `execute`/`get_database_type` and asserts the SQL STRING) - a no-mock-rule violation; only PostgreSQL DDL is verified for real. | Convert to real-engine DDL tests (create the table on real MySQL/MSSQL/Firebird and assert the column type), gated in the require-services CI. |
| FIELD-DECIMAL-PRECISION | `NumericField`/`FloatField` map to a floating type (REAL) in all four - no Decimal-backed numeric. Ruby additionally DROPS `decimal_field`'s declared `precision`/`scale` (it emits `REAL`, so `DECIMAL(12,4)` silently becomes floating) - the options are stored but never emitted. | Emit `DECIMAL(p,s)` for `decimal_field` (Ruby) and consider a Decimal-backed numeric type for money; document the float default. |
| FIELD-PHP-DATETIME-HEURISTIC | PHP infers `datetime` from a NAME heuristic `/(_at$|date|time)/i` that matches substrings, so `updated_by` (contains "date"), `runtime`, `downtime` are misclassified as datetime in DDL/seeding. Untested false-positive path. | Anchor the heuristic (or require an explicit type) so a substring match does not misclassify; add a false-positive test. |
| FIELD-FK-RELATEDNAME-RUBY | Ruby's `foreign_key_field` auto-`related_name` uses naive lowercase + "s" (`Category` -> `has_many :categorys`), while the hand-written `has_many` uses the smart `singularize`. Cosmetic accessor-name defect. | Use the smart pluralizer for the FK auto-wire too. |

## Owner decisions

- FIELD-DEC-01 (proposed): decide the canonical field-declaration model (FIELD-MODEL-DIVERGENCE) - the
  defining ORM parity call - and add PHP callable defaults (FIELD-CALLABLE-DEFAULT-PHP).
- FIELD-DEC-02 (proposed): convert the Python engine-DDL test to real engines (FIELD-ENGINE-DDL-MOCK); fix
  the Ruby decimal precision (FIELD-DECIMAL-PRECISION) and the PHP datetime heuristic
  (FIELD-PHP-DATETIME-HEURISTIC) and the Ruby FK related-name (FIELD-FK-RELATEDNAME-RUBY).

## Proposed conformance fixture

A shared fixture (real engines, no mocks): each field type round-trips (write coercion -> DDL column ->
read hydration) - JSON to a native object, a callable default resolved per-instance and NOT in the DDL, a
`decimal_field` producing a real `DECIMAL(p,s)` column, and the engine-specific DDL types created on real
MySQL/MSSQL/Firebird (not a mock). Run it across all four (and, once decided, assert the canonical
declaration model).

## Integration map

- Consumers: the base model (17), `create_table` DDL, migrations (15), the seeder (28), instance loading
  (26), validation (19). The FK field wires relationships (21).

## Breaking changes and migration

- Adding PHP callable defaults is additive. Fixing the Ruby decimal DDL changes generated DDL (a real
  `DECIMAL` column) - document it. Converging the field model (if chosen) is a breaking API change - version
  it.

## Implementation backlog

1. FIELD-DEC-01: the canonical-field-model decision + PHP callable defaults.
2. FIELD-DEC-02: real-engine DDL tests; Ruby decimal precision; PHP datetime heuristic; Ruby FK name.

## Porting capsule

A field system needs: a field-DECLARATION model (the framework must pick ONE canonical form - the master's
field objects, or a documented per-language idiom); a type per field driving engine-aware DDL; callable
defaults resolved PER INSTANCE and DROPPED from DDL (all four should support this - PHP is the gap); a
`field_mapping`/auto-map for prop<->column; JSON round-trip to a native object (the one type with an explicit
serialize/parse contract); a real `DECIMAL(p,s)` for decimal fields; and REAL-engine DDL tests, not mocks.

## Audit closure checklist

- [x] Boundary and public surface complete (the field declaration model x four).
- [x] Lifecycle and producer/consumer edges complete (declare -> default -> DDL -> coerce).
- [x] Configuration, failure and security rules complete.
- [x] Wire/persistence (field<->column, JSON) and provider (engine DDL) contracts complete.
- [x] Four-language behaviour + the structural divergence recorded.
- [x] Owner ambiguities decided (FIELD-DEC-01/02).
- [x] Conformance fixture (real-engine round-trip) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
