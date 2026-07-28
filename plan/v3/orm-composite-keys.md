# Plan: composite primary keys in the ORM

Scoped 2026-07-28 at the owner's request, from a report of repeated trouble with
multi-column primary keys. Follows the write-path P1
(`features/004-sqlite-adapter.md`), which made the **raw** write path
composite-safe and left the ORM single-key.

**Status: SCOPED, not started.** No code written.

## The problem, stated once

A composite primary key is **declarable** today and **not honoured**. Nothing
warns you. Every keyed operation silently uses one column, and `create_table()`
emits DDL that a database rejects.

Verified in all four:

| framework | resolver | returns |
| --- | --- | --- |
| python | `_get_pk()` (`orm/model.py:361`) | first field with `primary_key`, else `"id"` |
| node | `getPkField()` (`baseModel.ts:341`) | `.find(...)` first match, else `"id"` |
| ruby | `primary_key_field` (`orm.rb:246,286,371`) | one symbol, callers default to `:id` |
| php | `public string $primaryKey = 'id'` (`ORM.php:34`) | a **single string**, declared not resolved |

PHP is the odd one out on declaration: the other three flag the key on the field,
PHP names it on the model. That matters for the fix shape, below.

**`create_table()` emits `PRIMARY KEY` per column in all four** (Python
`model.py:1020`, Ruby `orm.rb:459`, Node `baseModel.ts:1050`, PHP equivalent), so
two flagged fields produce two `PRIMARY KEY` clauses. SQLite rejects that
outright with "table has more than one primary key"; the others vary.

So the failure is not one bug, it is a single assumption threaded through every
keyed path.

## What breaks, per call site

Traced, not guessed. Python line numbers; the other three mirror them.

| path | site | what goes wrong |
| --- | --- | --- |
| `save()` insert-vs-update | `model.py:419-497` | decides on one key having a value, so a half-populated composite key picks the wrong branch |
| `save()` update | `model.py:476-478` | `WHERE first_col = ?` matches **every row** sharing that value |
| `delete()` soft | `model.py:557-565` | same WHERE, so it soft-deletes a whole group |
| `delete()` hard | `model.py:568` | deletes a whole group |
| `force_delete()` | `model.py:582-589` | same |
| `restore()` | `model.py:606-610` | same |
| `find` / `find_by_id` / `find_or_fail` / `exists` | `model.py:729` (PHP), all four | take one scalar, so a composite row is unaddressable |
| `create_table()` | `model.py:1020` | invalid DDL |
| relationships | `orm.rb:286`, `baseModel.ts` | `related_pk` is one column, so a join to a composite parent is wrong |
| AutoCrud | `autoCrud.ts:130`, `crud/__init__.py:55` | REST route is `/{id}`, one path segment for an N-part key |

The write-path fix already protects the **raw** `db.update` / `db.delete` calls
underneath: a partial key now raises there. So the current worst case is an ORM
call that raises from the layer below rather than corrupting data. That is luck,
not design, and it is why this is P2 rather than P1.

## Scope: what this plan does and does not do

Naming what is **out** matters more than what is in, because a half-built
composite-key feature is worse than an honest refusal.

### In scope

1. **Declaration.** Multiple fields flagged `primary_key` in Python, Ruby and
   Node. PHP's `$primaryKey` widens to `string|array` (`['order_id',
   'product_id']`), keeping the string form working.
2. **Resolver returns an ordered list** in all four, mirroring `primary_key()` on
   the Database facade, which already does this. Declaration order is the key
   order.
3. **Every keyed write uses every key column**: `save()`, `delete()`,
   `force_delete()`, `restore()`. A **partial** key raises and names the missing
   columns, exactly as the raw write path now does.
4. **`save()` decides insert-vs-update on the whole key being present**, not on
   one column.
5. **Lookups take a map**: `find`, `find_by_id`, `find_or_fail`, `exists`.
6. **`create_table()` emits one table-level clause**: `PRIMARY KEY (order_id,
   product_id)`, replacing the per-column append.
7. **`auto_increment` plus a composite key is rejected loudly** at class
   definition. SQLite requires an auto-increment column to be the sole
   `INTEGER PRIMARY KEY`; the combination is a modelling error, and a clear error
   beats DDL that fails at first use.
8. **Lock-in tests in all four**, positive and negative, against real SQLite.

### Out of scope, deliberately

- **Multi-column foreign keys and relationships to a composite parent.**
  `has_many` / `belongs_to` / `foreign_key_field` join on one column. Supporting a
  composite parent means a composite FK declaration and a multi-column join
  condition. Real work, its own plan. **A composite-key model can still be the
  child** in a relationship (its own FK to a single-key parent is unaffected),
  which covers the common `order_items` case.
- **AutoCrud REST routes for composite-key models.** `/api/order_items/{id}` has
  one path segment for an N-part key, and inventing a delimiter (`1-5`? `1,5`?)
  is a URL design decision, not an implementation detail.
  **Recommendation: AutoCrud REFUSES to generate CRUD for a composite-key model,
  with an error naming the model and pointing at hand-written routes.** That is
  the honest behaviour and it is a small change. Generating a route that can only
  ever address part of a key is the thing to avoid.
- **Swagger schema and path parameters** for the same reason.
- **`get_next_id()` for composite keys.** A sequence per table assumes one
  surrogate key. Out.

## Surface table

The design decision worth arguing: **a map, not a positional tuple.**

`find([1, 5])` silently depends on field declaration order, so reordering two
field declarations changes what the call means with no error. A map is
order-independent and self-documenting. The scalar form stays for single-key
models, which is nearly every model.

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| declare (field-level) | `primary_key=True` on each | - | `primary_key: true` on each | `primaryKey: true` on each |
| declare (model-level) | - | `$primaryKey = ['order_id','product_id']` | - | - |
| resolve | `_get_pk() -> list[str]` | `primaryKeyColumns(): array` | `primary_key_fields -> Array` | `getPkFields(): string[]` |
| find, composite | `find({"order_id": 1, "product_id": 5})` | `findById(['order_id' => 1, 'product_id' => 5])` | `find(order_id: 1, product_id: 5)` | `find({ order_id: 1, product_id: 5 })` |
| find, single (unchanged) | `find(1)` | `findById(1)` | `find(1)` | `find(1)` |

Ruby takes keyword arguments because that is its idiom for a named set; it also
accepts a hash. Category 3 (runtime-idiomatic), outcome identical.

## Methodology

1. **Write the tests first, all four, and confirm red.** The fixture is the same
   `order_items (order_id, product_id, qty)` table the write-path fix already
   uses, so the shape is proven.
2. **Resolver first, in isolation.** Change `_get_pk` and friends to return a
   list and fix every call site to consume a list. This is mechanical and it is
   where the compiler and the type checker help most (Node and PHP will flag call
   sites; Python and Ruby will not, so grep every use).
3. **`create_table()` DDL next**, because without it no composite-key test can
   even build its table through the ORM.
4. **Then the write paths** (`save`, `delete`, `force_delete`, `restore`), then
   the lookups.
5. **Then the two loud refusals**: `auto_increment` + composite, and AutoCrud.
6. **Python first** to settle the shape, then Ruby, Node, PHP. Not because Python
   is master, but because it is the one whose call sites are already fully traced
   above.
7. Re-run all four full suites. A model in the existing suites that declares two
   PK fields by accident would surface here as a new error, and that is a finding.

## Tests to write

Real SQLite. The single-key pairs guard against a regression in the 99 percent
case while the composite pairs add the new behaviour.

| pair | positive | negative |
| --- | --- | --- |
| resolver | `the_resolver_returns_every_key_column_in_declaration_order` | `no_composite_key_collapses_to_its_first_column` |
| single-key unaffected | `a_single_key_model_still_resolves_and_saves` | `the_composite_change_does_not_alter_single_key_behaviour` |
| DDL | `create_table_emits_one_table_level_primary_key_clause` | `create_table_never_emits_two_primary_key_clauses` |
| insert | `saving_a_new_composite_keyed_row_inserts_it` | `saving_with_a_partial_key_raises_and_names_the_missing_columns` |
| update | `saving_an_existing_composite_keyed_row_updates_exactly_that_row` | `an_update_never_touches_a_sibling_row_sharing_the_first_key_column` |
| insert-vs-update | `save_updates_when_the_whole_key_matches_an_existing_row` | `save_does_not_insert_a_duplicate_when_the_whole_key_exists` |
| delete | `deleting_a_composite_keyed_row_removes_exactly_that_row` | `a_delete_never_removes_a_sibling_row` |
| soft delete | `soft_delete_and_restore_target_one_composite_row` | `restore_never_restores_a_whole_key_group` |
| lookup | `find_accepts_a_map_of_key_values` | `find_with_a_partial_key_raises_rather_than_returning_a_sibling` |
| order independence | `find_is_order_independent_across_the_key_map` | `reordering_field_declarations_does_not_change_what_find_means` |
| loud refusals | `auto_increment_with_a_composite_key_raises_at_class_definition` | `autocrud_refuses_a_composite_key_model_with_a_named_error` |
| cross-framework | `all_four_produce_the_same_rows_for_the_same_composite_operations` | `no_framework_addresses_a_composite_row_the_others_cannot` |

`an_update_never_touches_a_sibling_row_sharing_the_first_key_column` is the one
to write first. It is the whole bug in one assertion, and it fails in all four
today.

## Risks

- **The resolver return-type change touches every keyed path**, and in Python and
  Ruby nothing will tell you when you miss one. Grep every call site before
  changing the signature, and expect the full suite to be the real gate.
- **A model in an existing suite may already declare two PK fields by accident**
  and currently "work" because only the first is used. That model starts raising.
  Each one is a finding, not a test to relax.
- **`save()`'s insert-vs-update decision is behaviour a user can already depend
  on.** Widening it to the whole key is correct but it is a behaviour change for
  any model where a second field happens to carry `primary_key`.
- **AutoCrud refusing to generate routes is breaking** for anyone who has a
  composite-key model and is currently getting silently-broken CRUD endpoints.
  That is the point, and it needs a `Breaking:` note naming the alternative.
- **Not a security issue and not data-loss-on-arrival**, because the raw write
  path now raises underneath. That is what makes this P2 and schedulable, rather
  than something to rush.

## Open decisions for the owner

1. **AutoCrud: refuse, or invent a route shape?** My recommendation is refuse
   loudly. If you would rather it generate something, the URL shape is your call
   (`/{order_id}/{product_id}` is the honest one; a delimited single segment is
   more compact and worse to debug).
2. **PHP declaration: widen `$primaryKey` to `string|array`, or move PHP to
   field-level flags like the other three?** Widening is smaller and
   non-breaking. Moving is more consistent with the other three and is a bigger
   change to PHP's ORM. I lean widening, and recording the divergence.
3. **Priority.** This is P2. It sits behind the sandbox P1 (feature 38) and does
   not block the rest of the audit.
