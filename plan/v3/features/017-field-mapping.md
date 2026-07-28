# Feature 17: Field mapping (property to column)

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 5. **Planning only.**

**Status: CLOSED.** All four verified - PHP, Python and Ruby by execution, Node from
source.

Feature 13's D4 deferred this decision here: `camelToSnake` (PHP), `auto_map` /
`field_mapping` (Ruby) and `getReverseMapping` (Node) are all the same concept under
three names. This row settles it.

## Files

Inside the ORM base class; measurements are feature 13's.

## What differs: PHP converts, the other three do not

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

## The convergence is accidental, and that is the real finding

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

## Verdict: PROMOTE node (the mechanism), then decide the default

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

## Pattern

**The property name is the column name, unless an explicit map says otherwise.**

1. `field_mapping` / `fieldMapping` exists in all four, empty by default, and
   `get_db_column(prop)` returns `mapping[prop]` or `prop` - Node's line, promoted.
2. **PHP's automatic `camelToSnake` becomes opt-in**, not the default. Keep the
   converter, expose it as a class-level switch
   (`$autoSnakeCase = true`) so an existing PHP app sets one property and keeps its
   schema, and a new one gets the same verbatim default as the other three.
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

## Methodology

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

## Tests to write

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

## Risks

- **Point 2 changes PHP's emitted schema.** Any PHP app calling `createTable()` on a
  camelCase model gets different column names after the change. That is why the
  switch defaults must be considered carefully: defaulting `autoSnakeCase = true` in
  PHP only preserves PHP but keeps the family split; defaulting it `false`
  everywhere unifies the family and breaks PHP. **This one needs the owner's call.**
  My recommendation is `false` everywhere plus a loud migration note, because a
  schema that differs by framework is the more expensive problem - but it is a real
  trade and PHP has the largest installed base of the four.
- Everything else in this row is additive.

## Parked

Not implemented. Blocked on the owner's decision about PHP's default. Order: 6, 4,
5, 3, 13, 14, 15, 16, 17, then 2, 1, 0.
