# Feature 006: Query builder

## Identity and status

- Matrix identity: 6 — Query builder
- Audit state: decision-ready
- Dependencies: Feature 3 — Database adapter interface; Feature 5 — Database facade and safe writes; Feature 24 — Paginated database and ORM results
- Dependants: Feature 14 — MongoDB SQL-translation provider; Feature 17 — ORM base class; Feature 98 — Realtime collaboration
- Existing ADRs: ADR-0043 governs `DatabaseResult.count`; no Query Builder-specific ADR exists
- Shared fixtures: `query_builder_contract.json` proposed; existing ORM contract suites cover no silent limit and no raw MongoDB `$where`

- Catalog phase: Database and providers
- Audit note: Decisions prepared from four-language source and focused local baselines; no framework code changed

## Why this feature exists

The builder gives an engineer one fluent path from a table name to a database result. It builds a portable `SELECT`, keeps values in bound parameters, and hands execution to the database layer.

The API stays small. Select. Filter. Join. Group. Sort. Fetch. Each language spells the methods in its native style, but every chain means the same thing.

## Boundary

This feature owns fluent `SELECT` construction and the `toMongo` representation generated from that state. It owns these operations:

- factory creation from a table and optional database;
- column selection;
- `AND` and `OR` conditions with positional parameters;
- inner and left joins;
- grouping and `HAVING`;
- ordering;
- execution limit and offset;
- SQL inspection;
- `get`, `first`, `count` and `exists` execution helpers; and
- conversion of the supported subset into MongoDB query options.

Feature 7 owns SQL dialect rewriting, placeholder conversion, pagination rewriting and batch-insert construction. Feature 3 owns adapter execution. Feature 5 owns facade result normalization. Feature 24 owns `DatabaseResult` and pagination metadata. ORM models expose this builder but do not redefine it.

The builder constructs `SELECT` statements only. Insert, update, delete and batch execution do not belong here.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | `tina4_python/query_builder/__init__.py` | `Tina4/QueryBuilder.php` | `lib/tina4/query_builder.rb` | `packages/orm/src/queryBuilder.ts` |
| Startup/CLI integration | `Model.query()` binds the model table and database | `ORM::query()` binds the model table and database | `ORM.query` binds the model table and database | `BaseModel.query()` binds the model table and adapter; package exports `QueryBuilder` |
| Stored/wire format | SQL string, ordered parameters, `DatabaseResult`, native Mongo query document | Same concepts; a raw adapter can still make `get()` return an array | Same concepts and `DatabaseResult` | Same concepts; async execution returns `DatabaseResult` |
| Existing focused tests | 63 local checks passed across `test_query_builder.py` and `test_orm_contracts.py` | 69 local checks passed across `QueryBuilderTest.php` and `OrmContractsTest.php` | 79 local examples passed across `query_builder_spec.rb` and `orm_contracts_spec.rb` | 123 focused checks passed across query-builder, result-shape and ORM-contract runners |
| Existing lab baseline | Not run for this audit | Not run for this audit | Not run for this audit | Not run for this audit |

All four implementations expose the same core chain. They also share two established rules: `get()` has no silent 100-row limit, and `toMongo` rejects an unsupported condition instead of emitting raw `$where` JavaScript.

## Public surface contract

| Neutral operation | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Create | `QueryBuilder.from_table(table, db=None)` | `QueryBuilder::fromTable($table, $db = null)` | `QueryBuilder.from_table(table, db: nil)` | `QueryBuilder.fromTable(table, db?)` |
| Select | `select(*columns)` | `select(...$columns)` | `select(*columns)` | `select(...columns)` |
| Add `AND` | `where(condition, params=None)` | `where($condition, $params=[])` | `where(condition, params=[])` | `where(condition, params=[])` |
| Add `OR` | `or_where(...)` | `orWhere(...)` | `or_where(...)` | `orWhere(...)` |
| Inner join | `join(table, on_clause)` | `join($table, $on)` | `join(table, on_clause)` | `join(table, onClause)` |
| Left join | `left_join(...)` | `leftJoin(...)` | `left_join(...)` | `leftJoin(...)` |
| Group | `group_by(column)` | `groupBy($column)` | `group_by(column)` | `groupBy(column)` |
| Having | `having(expression, params=None)` | `having($expression, $params=[])` | `having(expression, params=[])` | `having(expression, params=[])` |
| Order | `order_by(expression)` | `orderBy($expression)` | `order_by(expression)` | `orderBy(expression)` |
| Page execution | `limit(count, offset=None)` | `limit($count, $offset=null)` | `limit(count, offset=nil)` | `limit(count, offset?)` |
| Inspect SQL | `to_sql()` | `toSql()` | `to_sql` | `toSql()` |
| Execute all | `get()` | `get()` | `get` | `await get()` |
| Execute one | `first()` | `first()` | `first` | `await first()` |
| Count | `count()` | `count()` | `count` | `await count()` |
| Presence | `exists()` | `exists()` | `exists?` | `await exists()` |
| Mongo options | `to_mongo()` | `toMongo()` | `to_mongo` | `toMongo()` |

The static factory is the portable constructor. A language may expose its native constructor, but portable examples and fixtures must use the factory.

Every builder method mutates the same builder and returns that instance. `select()` with no columns leaves the current selection unchanged. The first condition ignores its stored connector because a SQL `WHERE` clause cannot begin with `AND` or `OR`.

## Inputs and outputs

- `table`, columns, conditions, join clauses, group expressions and order expressions are non-empty strings.
- Conditions and `HAVING` use `?` placeholders. Parameters remain native values and retain call order.
- `limit` and `offset` are integers greater than or equal to zero. An offset exists only as the second argument to `limit`.
- Omitting `limit` means no row cap. The framework must never invent a default limit.
- `toSql` returns SQL only. It does not append limit or offset because the adapter owns portable pagination.
- `get` returns a `DatabaseResult` in every language, whether the builder received a facade or a raw adapter.
- `first` returns one native row mapping or `null`/`nil` when no row matches.
- `count` returns a native integer. It ignores the current selected columns but preserves every filter, join, group, `HAVING` and parameter.
- `exists` returns a native boolean.
- Node uses promises because its database API is asynchronous. The result after awaiting it matches the other languages.

Raw SQL fragments remain raw. The builder must never quote a column expression or alter a condition behind the engineer's back. Values belong in parameters; identifiers and expressions come from trusted application code.

## Lifecycle and operation graph

1. The factory records a table and optional database.
2. Fluent calls append state in call order and return the same builder.
3. `toSql` emits clauses in SQL order: `SELECT`, `FROM`, joins, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`.
4. `get`, `first`, `count` and `exists` resolve the database before execution.
5. An explicitly supplied database wins. Otherwise, the builder uses the framework's active database. If neither exists, execution fails.
6. `get` sends SQL, parameters, limit and offset through the database layer. The layer returns a normalized `DatabaseResult`.
7. `first` fetches one row without changing builder state.
8. `count` replaces the projection for its count SQL, restores the projection before I/O, and returns the count alias without changing later `toSql` output.
9. `exists` derives its boolean from `count`.
10. `toMongo` performs no database I/O. It validates and converts the supported builder state into driver-ready native options.

The builder is mutable and not safe to share across concurrent requests or tasks. Each query starts with a new builder.

## Configuration and precedence

The feature has no environment variables or project files.

Database precedence is fixed:

1. the database passed to the factory;
2. the database bound by `Model.query()`;
3. the framework's active default database; then
4. a loud no-database failure.

PHP currently stops after step 2 for standalone builders, while Python, Ruby and Node can discover the active database. PHP must gain the same fallback.

The selected provider controls placeholder translation, pagination syntax, identifier quoting and execution. Query Builder must not inspect the engine or apply SQL dialect rules.

## Failures, side effects and security

Construction and inspection perform no I/O. Execution delegates database side effects to Feature 3. A `SELECT` may still trigger provider effects such as connection opening, logging, metrics or transaction participation.

The framework must fail before execution when the table is blank, an expression is blank, limit or offset is negative, or a parameter shape cannot satisfy the declared placeholders. It must preserve the provider's failure as the cause when the database rejects otherwise valid input.

The API accepts raw identifier and expression fragments. Engineers must not place request values inside those fragments. Shared examples must bind every value. The builder does not claim to make untrusted table names, column names, joins or order expressions safe.

`toMongo` must fail when it cannot preserve meaning. It must never:

- emit raw `$where` JavaScript;
- ignore joins, grouping or `HAVING`;
- turn a function or alias into a projection field;
- invent a missing parameter;
- discard an extra parameter;
- accept an unknown sort direction; or
- reorder mixed `AND` and `OR` conditions.

## Wire and persistence contract

The SQL contract uses one space between generated clauses and `, ` between repeated columns, groups and order expressions. It preserves each caller-supplied fragment verbatim within that structure.

The parameter sequence is all `WHERE` parameters in condition order, followed by all `HAVING` parameters in expression order. The adapter may translate placeholders but may not reorder values incorrectly.

The neutral `toMongo` document can contain:

- `filter`: a MongoDB filter document;
- `projection`: an ordered field-to-`1` mapping;
- `sort`: an ordered field-to-`1` or `-1` mapping;
- `limit`: a non-negative integer; and
- `skip`: a non-negative integer.

Each language returns the native shape its MongoDB driver accepts. Python may use ordered `(field, direction)` pairs for `sort`; PHP, Ruby and Node use insertion-ordered mappings. The semantic order must match.

Supported filter forms are `=`, `!=`, `<>`, `>`, `>=`, `<`, `<=`, `LIKE`, `IN (?)`, `NOT IN (?)`, `IS NULL` and `IS NOT NULL`. Field names in this subset are simple identifiers. `LIKE` keeps the established case-insensitive MongoDB behavior but must escape regex metacharacters before converting `%` and `_`.

`IS NULL` matches an explicit null and a missing MongoDB field because neither carries a value. `IS NOT NULL` requires the field to exist and contain a non-null value.

## Providers and substitutability

SQL providers consume `toSql`, positional parameters, limit and offset. They may translate syntax through Feature 7. They may not change the builder's result types.

The MongoDB SQL-translation provider consumes `toMongo`. This is a capability-limited translation, not a promise that arbitrary SQL maps to MongoDB. Unsupported state fails with the offending clause or operation in the error.

Provider substitution must preserve:

- selected fields and aliases supported by that provider;
- condition order and boolean precedence;
- bound parameter values and nulls;
- row order;
- unlimited versus explicitly limited execution;
- offset semantics;
- `DatabaseResult` metadata; and
- empty-result shapes.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| QB-01 | The first flat catalogue bundled Query Builder with the independent SQL Translator module. | SQL Translator becomes Feature 7; later IDs shift by one before 3.14. |
| QB-02 | PHP standalone execution cannot fall back to the active framework database. | Apply the shared database precedence rule. |
| QB-03 | PHP can return a raw adapter array from `get`; the other public path returns `DatabaseResult`. | Normalize `get` to `DatabaseResult` for every accepted database object. |
| QB-04 | `toMongo` ignores joins, groups and `HAVING`. | Reject unsupported state before returning a document. |
| QB-05 | Mixed `AND`/`OR` conversion groups all `AND` conditions together and can change SQL precedence. | Build the exact boolean tree or reject a sequence that cannot be preserved. |
| QB-06 | Missing Mongo parameters become `null`, `[]` or an empty string; extra parameters disappear. | Require exact parameter consumption and fail with the condition named. |
| QB-07 | Mongo `IS NULL` currently checks only for a missing field and does not match an explicit null. | Implement the decided null rule and cover both explicit-null and missing-field witnesses. |
| QB-08 | Mongo `LIKE` substitutes `%` and `_` without escaping regex metacharacters. | Escape the input, then translate SQL wildcards. |
| QB-09 | Mongo projection accepts functions and aliases as field names; sort accepts unknown directions as ascending. | Validate the supported subset and fail on unsupported expressions. |
| QB-10 | Blank fragments and negative page values reach malformed SQL or provider-specific behavior. | Validate language-neutral invariants at the builder boundary. |
| QB-11 | Existing suites repeat broad examples but have no byte-identical shared Query Builder fixture. | Add one fixture and thin runners in every language. |

## Owner decisions

- One public module gets one whole-number feature. SQL Translator is not part of Query Builder.
- Query Builder is a mutable fluent `SELECT` builder. It does not own writes or dialect translation.
- Method names follow each language's conventions; behavior and result types do not vary.
- An explicit database wins, then a model-bound database, then the active framework database.
- Inspection works without a database. Execution without any resolvable database fails outright.
- `get` always returns `DatabaseResult`; engineers do not normalize adapter-specific shapes themselves.
- No implicit row limit exists.
- Limit and offset stay outside `toSql` and pass through the database execution contract.
- Raw expressions remain possible for trusted code. Parameters carry data values.
- `toMongo` supports a declared subset and fails on everything else. Silent semantic loss is forbidden.
- The Mongo result uses driver-native containers while preserving one neutral semantic shape.
- Current Mongo `LIKE` remains case-insensitive for compatibility, with correct regex escaping.
- Mongo `IS NULL` matches explicit null and a missing field. `IS NOT NULL` requires an existing, non-null field.

## Proposed conformance fixture

Create `language-port/fixtures/query_builder_contract.json`. Each case contains initial table state, an ordered operation list and one expected result or error.

Required positive cases:

- default `SELECT *` and explicit columns;
- empty `select()` retaining the current projection;
- repeated `where`, first `orWhere`, mixed joins, groups, `HAVING` and order expressions;
- SQL and parameter order from a full chain;
- no implicit limit over 150 rows;
- explicit limit and offset;
- `DatabaseResult` shape, true total and empty result;
- `first`, `count` and `exists` native return types;
- count preserving the original projection;
- explicit, model-bound and default database resolution;
- every supported Mongo comparison;
- conflicting-field conditions that require `$and`;
- mixed boolean precedence;
- projection and multi-field sort order; and
- explicit Mongo null and missing-field witnesses.

Required negative and mutation-witness cases:

- blank table and blank expressions;
- negative limit or offset;
- missing and extra parameters;
- execution with no database;
- unsupported Mongo condition;
- Mongo join, group or `HAVING` state;
- projection functions and aliases in Mongo mode;
- unknown sort direction;
- a `LIKE` value containing `.`, `*`, `[`, `%` and `_`;
- removal of the no-silent-limit rule;
- return of a raw row array from `get`; and
- emission of raw `$where`.

The fixture compares normalized values, not language spelling. It records ordered maps as arrays of key-value pairs where JSON object ordering would hide a defect.

## Integration map

- Python: `Model.query()` imports and binds `QueryBuilder`; the database facade and adapters execute it.
- PHP: `ORM::query()` binds it; Realtime also creates it directly; raw adapters and the facade expose different current `get` shapes.
- Ruby: `ORM.query` binds it; the builder can use `Tina4.database` as its fallback.
- Node: `BaseModel.query()` binds it; `@tina4/orm` exports it; adapter helpers normalize async execution.
- Feature 14 consumes `toMongo` for MongoDB SQL translation.
- Feature 24 defines the result and pagination metadata returned by `get`.
- Documentation and generated language examples must use the static factory and native method spelling.

No CLI command or environment variable owns Query Builder configuration.

## Breaking changes and migration

- The catalogue inserts SQL Translator at Feature 7. The former Features 7–132 become Features 8–133.
- PHP `get()` callers that use a raw adapter must read the normalized `DatabaseResult` surface instead of `['data']`.
- Invalid limits, offsets, blank fragments and parameter mismatches will fail earlier.
- `toMongo` will reject chains it previously truncated without warning. Callers must express supported filters or use the MongoDB provider API directly.
- Mongo null and `LIKE` results may change where the old translation returned the wrong set.

These are permitted 3.14 corrections. Migration notes must show each language's native `DatabaseResult` access.

## Implementation backlog

1. Add the shared Query Builder fixture and four thin runners.
2. Add invariant validation for strings, page values and Mongo parameter consumption.
3. Normalize every `get` path to `DatabaseResult`, starting with PHP raw adapters.
4. Align active database fallback, starting with PHP.
5. Make Mongo conversion reject joins, grouping, `HAVING`, invalid projection and invalid sort state.
6. Preserve SQL boolean precedence in Mongo filters or reject unsupported sequences.
7. Fix Mongo null handling and escape `LIKE` patterns.
8. Add result-shape, failure and mutation witnesses to every runner.
9. Run the fixture locally and on the root lab runners for every language.
10. Publish the breaking migration examples and then mark the feature implementation-ready.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a mutable fluent `SELECT` builder with one static factory. Store columns, joins, conditions, groups, `HAVING`, order, parameters, limit and offset in call order. Return the same builder from every fluent method.

Emit SQL in standard clause order. Keep limit and offset out of the SQL string and pass them to the database layer. Resolve an explicit database first, then a model-bound database, then the active framework database. Fail when execution has no database.

Return `DatabaseResult` from `get`, one native row or null from `first`, an integer from `count`, and a boolean from `exists`. Apply no implicit row cap. Preserve the builder after inspection and execution.

Translate only the declared Mongo subset. Return driver-ready native containers with the neutral `filter`, `projection`, `sort`, `limit` and `skip` meaning. Preserve boolean precedence and parameter order. Reject every state whose meaning cannot survive translation. Never emit `$where` and never ignore part of the chain.

Prove the port with the shared fixture. The runner adapts names and async syntax only; it may not adapt behavior.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
