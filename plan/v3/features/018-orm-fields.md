# Feature 018: ORM fields and column mapping

## Identity and status

- Matrix identity: 18 - ORM fields and column mapping
- Audit state: decision-ready
- Audit note: measured 2026-07-28 by execution (PHP/Python/Ruby) and source (Node); prose
  sections completed from that evidence 2026-08-10. No framework code changed.
- Dependencies: Feature 17 ORM base class (the fields live on it), Feature 15 migrations
  (`create_table` uses the mapped columns), the four scaffolders
- Dependants: every domain model's schema, migrations, AutoCrud, and any doc example that
  names a column
- Existing ADRs: ADR-0008 (PHP `autoSnakeCase` defaults to `false`, decided 2026-07-28 -
  the central decision for this feature, already RATIFIED)
- Shared fixtures: `orm_fields_contract.json` is required; the cross-framework "same model,
  same columns" case is the whole point

## Why this feature exists

A model's property names must map to the SAME database columns in all four languages, so one
migration, one shared database, or one documented column works everywhere. Today PHP rewrites
`firstName` to `first_name` and the other three keep it verbatim, so the same model produces
two different schemas.

## Boundary

This feature owns the property-to-column mapping: the explicit `field_mapping`, the
`get_db_column`/`get_property` resolvers, the `auto_snake_case` switch, and the
`camel_to_snake`/`snake_to_camel` helpers. It DELEGATES the model itself to Feature 17, the
DDL emission to Feature 15 migrations, and the generated model source to the scaffolders. It
does not own field TYPES (that is the field-definition part of Feature 17/18's base).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `firstName` becomes | `firstName` (verbatim) | `first_name` (auto) | `firstName` (verbatim) | `firstName` (verbatim) |
| Mechanism | none - property IS column | automatic `camelToSnake` | `field_mapping` empty default | `fieldMapping[prop] ?? prop` |
| Can it be turned off | n/a | NO (the outlier) | yes (opt-in map) | yes (opt-in map) |
| Verified by | execution | execution | execution | source |
| Idiomatic column | `first_name` (snake habit) | `first_name` | `first_name` | `firstName` (camel habit, outlier) |
| Resolver present | none | `getDbColumn` | none named | `getDbColumn` |

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 5. **Planning only.**

**Status: CLOSED.** All four verified - PHP, Python and Ruby by execution, Node from
source.

Feature 17's D4 deferred this decision here: `camelToSnake` (PHP), `auto_map` /
`field_mapping` (Ruby) and `getReverseMapping` (Node) are all the same concept under
three names. This row settles it.

### Files

Inside the ORM base class; measurements are feature 16's.

## Public surface contract

Four names per language, one concept each (full spelling table in the porting capsule):
`field_mapping` (an explicit property-to-column map, empty by default), `get_db_column(prop)`
(resolve a property to its column, returning the mapped value or the property verbatim),
`get_property(column)` (the reverse, resolving one column to its property), `auto_snake_case`
(a switch, default `false` per ADR-0008), and the public helpers `camel_to_snake` /
`snake_to_camel`. Node's `getReverseMapping()` becomes `getProperty(column)`; Ruby's
`auto_map` is removed (it named a mechanism, not a concept).

## Inputs and outputs

- Input: a declared property name; optionally an explicit `field_mapping` entry and the
  `auto_snake_case` switch.
- Output (default): the column name equals the property name, verbatim, in all four.
- Output (explicit map): `field_mapping[prop]` wins over every other rule.
- Output (`auto_snake_case = true`): a camelCase property yields a snake_case column; an
  already-snake name is left unchanged (idempotent).
- `get_db_column` and `get_property` round-trip: the property resolves to a column and back.

## Lifecycle and operation graph

1. A model declares properties (Feature 17); this feature resolves each to a column via
   `field_mapping[prop]`, else the `auto_snake_case` conversion when on, else verbatim.
2. On write, the property-to-column mapping names the columns in the INSERT/UPDATE.
3. On read, `get_property(column)` maps each returned column back to its property so a
   column with no matching property is surfaced, never silently dropped.
4. `create_table` (Feature 15) emits the mapped column names; the scaffolders generate
   snake_case columns in the model source a developer reads.

## Configuration and precedence

- Precedence for a property's column: explicit `field_mapping` entry, then
  `auto_snake_case` conversion (when `true`), then the verbatim property name.
- `auto_snake_case` defaults to `false` in all four (ADR-0008); PHP keeps its converter but
  it is now opt-in.
- There is no environment variable; mapping is declared on the model.

## Failures, side effects and security

- A column returned by the database that has no matching property does NOT silently vanish
  on read; the resolver surfaces it.
- `get_db_column` does not invent a column the table lacks.
- The mapping operates on trusted schema identifiers, not request input; identifier quoting
  stays with the trusted builder.
- Changing `auto_snake_case`'s default is the one behaviour change (PHP), handled as a
  breaking migration below.

## Wire and persistence contract

The persisted contract is the COLUMN SET: the same model definition emits the same columns in
all four. That is exactly what accidental convergence does not guarantee today (Node's
idiomatic camelCase is the outlier), and it is what the cross-framework fixture pins. A
generated migration or a shared database then works across every language.

## Providers and substitutability

Column mapping sits above the provider layer, so it is engine-agnostic: the same property
resolves to the same column regardless of SQLite, PostgreSQL, MySQL, MSSQL or Firebird
underneath. The one interaction is Firebird's UPPERCASE identifier storage (Feature 12),
which is a provider-level case-fold, separate from this property-to-column mapping.

## Contradictions and defects

### What differs: PHP converts, the other three do not

Same model in each - `id`, `firstName`, `emailAddress` - then create the table and
read the real schema back:

| | `firstName` becomes | mechanism |
| --- | --- | --- |
| **php** | **`first_name`** | automatic `camelToSnake` on every property |
| python | `firstName` | none - the property name IS the column |
| ruby | `firstName` | none - `field_mapping` is `{}` by default |
| node | `firstName` | `fieldMapping[prop] ?? prop` - explicit map, verbatim fallback |

PHP, verified:

```
COLS: ["id","first_name","email_address"]
ROW:  {"id":1,"first_name":"ann","email_address":"a@b.c"}
getDbColumn('firstName') -> first_name
```

Python, verified:

```
COLS: ['id', 'firstName', 'emailAddress']
ROW:  {'id': 1, 'firstName': 'ann', 'emailAddress': 'a@b.c'}
get_db_column(firstName) -> firstName
```

Ruby, verified - and it proves the mapping is opt-in rather than automatic:

```
COLS: ["id", "firstName", "email_address"]     <- both spellings survive verbatim
field_mapping: {}
```

Ruby wrote `firstName` AND `email_address` exactly as declared, side by side in one
table. Node's source confirms the same contract: `getDbColumn(prop)` returns
`this.fieldMapping[prop] ?? prop`.

**So the same model definition produces two different schemas.** A shared database,
a migration written once, or a doc example that works on PHP breaks on the other
three, and vice versa. Core Principle 6 puts project structure and conventions in
the must-be-identical column; a column name is more load-bearing than either.

### The convergence is accidental, and that is the real finding

In practice the drift is usually invisible, because each language's idiomatic
property naming happens to land on the same column:

| | a developer writes | column they get |
| --- | --- | --- |
| php | `firstName` (camelCase is idiomatic PHP) | `first_name` |
| python | `first_name` (snake_case is idiomatic Python) | `first_name` |
| ruby | `first_name` (snake_case is idiomatic Ruby) | `first_name` |
| node | `firstName` (camelCase is idiomatic JS)... | **`firstName`** |

Three of the four converge on `first_name` when the developer follows convention.
Node does not - idiomatic JS naming produces a camelCase column, so Node is the one
framework whose natural style yields a schema the other three would not.

And nothing enforces any of it. A Python developer may legally write `firstName` and
get a `firstName` column; a PHP developer cannot get a `firstName` column at all.
The parity holds by habit, not by contract, which is exactly the class of thing this
audit exists to convert into a rule.

### Verdict: PROMOTE node (the mechanism), then decide the default

Decided on **SOLID and explicitness**.

Node has the cleanest mechanism: `fieldMapping[prop] ?? prop` is one line, opt-in,
and does nothing surprising. Ruby has the same shape with an empty default. Python
has no mechanism at all, which is the same observable behaviour with no escape
hatch. PHP's automatic conversion is the outlier, and it is the one that cannot be
turned off.

PHP's conversion is not wrong in itself - snake_case columns are good practice, and
`getDbColumn()` makes it inspectable. It is wrong that it is **unilateral**: three
frameworks take the property name verbatim and one rewrites it, so the framework
family cannot agree on a schema.

All category 4. Every language can do either behaviour.

### Risks

- **Point 2 changes PHP's emitted schema, deliberately.** The owner chose
  `autoSnakeCase = false` everywhere (ADR-0008), so any PHP app calling
  `createTable()` on a camelCase model emits different column names after this
  change. The cost is real and falls on the framework with the largest installed
  base; it is accepted because a schema that differs by framework is the more
  expensive problem and it compounds with time. Mitigations, all required:
  a `Breaking:` changelog entry, a migration note, and the one-line opt-back-in
  (`$autoSnakeCase = true`) stated prominently in both.
- Everything else in this row is additive.

## Owner decisions

1. RATIFIED (ADR-0008, 2026-07-28): PHP's automatic `camelToSnake` becomes opt-in and
   `auto_snake_case` defaults to `false` in all four. This is the one decision that already
   has an owner sign-off; the rest below are proposed derivations of it.
2. Proposed: the property name IS the column name by default, in all four (promote Node's
   `fieldMapping[prop] ?? prop`, give Python the mechanism it lacks, align Ruby and Node
   names).
3. Proposed: `camel_to_snake` / `snake_to_camel` become PUBLIC helpers in all four, so a
   developer who wants snake_case columns opts in anywhere, not only in PHP.
4. Proposed: the four scaffolders GENERATE snake_case column names, so the convention lives
   in code a developer reads, not in a silent rewrite.
5. Proposed naming: Node's `getReverseMapping()` becomes `getProperty(column)`; Ruby's
   `auto_map` is removed.

## Proposed conformance fixture

### Tests to write

Real SQLite, one model with a camelCase property and a snake_case property in the
same class - the shape that proved Ruby's behaviour.

| pair | positive | negative |
| --- | --- | --- |
| verbatim default | `a_property_name_is_the_column_name_by_default` | `no_framework_rewrites_a_property_name_without_being_asked` - the PHP reproduction |
| mixed spellings | `a_camel_and_a_snake_property_both_survive_verbatim` | `neither_spelling_is_normalised_to_the_other` |
| explicit map | `field_mapping_overrides_the_column_for_a_mapped_property` | `an_unmapped_property_is_not_affected_by_the_map` |
| resolve both ways | `get_db_column_and_get_property_round_trip` | `get_db_column_does_not_return_a_column_the_table_lacks` |
| opt-in conversion | `auto_snake_case_true_converts_camel_properties` | `auto_snake_case_false_leaves_them_verbatim` |
| helpers | `camel_to_snake_and_snake_to_camel_round_trip` | `camel_to_snake_leaves_an_already_snake_name_unchanged` |
| cross-framework | `all_four_emit_the_same_columns_for_the_same_model` - one committed fixture | `no_framework_emits_a_column_the_others_lack` |
| read path | `a_row_read_back_populates_the_declared_property` | `a_column_with_no_matching_property_does_not_silently_vanish` |

The cross-framework pair is the whole point: the schema fixture is the artifact that
turns accidental convergence into an enforced contract.

## Integration map

- Feature 17's base model carries the fields; this mapping resolves them to columns.
- Feature 15 `create_table` emits the mapped columns; the four scaffolders generate the
  model source (and, after this change, snake_case columns).
- AutoCrud and the REST layer read columns through the resolvers; any doc example that names
  a column depends on the emitted column set being identical across languages.
- Central fixtures, four runners, the CI matrix, release notes, the ORM docs and the four
  scaffolders update together.

## Breaking changes and migration

- PHP `createTable()` on a camelCase model emits DIFFERENT column names after ADR-0008: a
  `firstName` property now yields a `firstName` column, not `first_name`. This falls on the
  framework with the largest installed base and is accepted because a schema that differs by
  framework is the more expensive, compounding problem.
- Required mitigations, all in the same release: a `Breaking:` changelog entry, a migration
  note, and the one-line opt-back-in stated prominently in both -- an existing PHP app sets
  `$autoSnakeCase = true` to keep its current schema.
- Everything else in this feature is additive (new helpers, new resolvers, scaffolder
  output).

## Implementation backlog

### Methodology

1. Write the tests below in all four. Expect red: PHP on the verbatim default, three
   frameworks on the missing `auto_snake_case` switch and the missing public helper.
2. **PHP first**, because it holds the only behaviour change. Add the switch,
   default it off, and add a `Breaking:` entry - this changes the schema PHP's
   `createTable()` emits.
3. Add `field_mapping` plus `get_db_column` / `get_property` to Python (it has
   neither) and align Ruby's and Node's names.
4. Promote the `camel_to_snake` / `snake_to_camel` helpers to all four.
5. Update the four scaffolders to emit snake_case columns.
6. Re-measure - this row should move no complexity numbers; it is surface work.

## Porting capsule

### Pattern

**The property name is the column name, unless an explicit map says otherwise.**

1. `field_mapping` / `fieldMapping` exists in all four, empty by default, and
   `get_db_column(prop)` returns `mapping[prop]` or `prop` - Node's line, promoted.
2. **PHP's automatic `camelToSnake` becomes opt-in and defaults to `false`** (owner
   decision, 2026-07-28, recorded as ADR-0008). Keep the converter, expose it as
   `$autoSnakeCase`, default off. An existing PHP app sets one property to keep its
   schema; a new one gets the same verbatim default as the other three.
3. `camel_to_snake` / `snake_to_camel` become **public helpers in all four**, so a
   developer who wants snake_case columns from camelCase properties can opt in
   anywhere rather than only in PHP.
4. **The scaffolders generate snake_case column names in all four**, which is where
   the convention belongs - in the generated code a developer reads, not in a silent
   rewrite they cannot see.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| explicit map | `field_mapping = {}` | `$fieldMapping = []` | `field_mapping` | `static fieldMapping = {}` |
| resolve one | `get_db_column(prop)` | `getDbColumn($prop)` | `get_db_column(prop)` | `getDbColumn(prop)` |
| reverse | `get_property(column)` | `getProperty($column)` | `get_property(column)` | `getProperty(column)` |
| auto snake | `auto_snake_case = False` | `$autoSnakeCase = false` | `auto_snake_case = false` | `static autoSnakeCase = false` |
| helper | `camel_to_snake(s)` | `camelToSnake($s)` | `camel_to_snake(s)` | `camelToSnake(s)` |

Two naming decisions in that table: Node's `getReverseMapping()` (returns the whole
inverted map) becomes `getProperty(column)` (resolves one), matching the shape of
`getDbColumn`; and Ruby's `auto_map` goes, since it named a mechanism rather than a
concept.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (PHP auto-converts, three verbatim).
- [x] Owner ambiguities recorded (ADR-0008 ratified; 4 derived proposals).
- [x] Proposed shared cases and mutation witnesses complete (cross-framework column set).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready and the central decision RATIFIED (ADR-0008: `auto_snake_case` default
`false`). Verified by execution in PHP/Python/Ruby and source in Node. The IMPLEMENTATION
(PHP switch, Python's missing resolvers, public helpers, scaffolder snake_case) is the build
phase and is NOT done. No longer blocked. Decision-ready is not built.
