# Feature 4: Database write facade and provider conformance

## Identity and status

- Matrix identity: Feature 4, originally named `SQLite adapter + write path`.
- Audit state: **decision-ready; implementation deliberately not started**.
- Original audit: 2026-07-28.
- Adversarial re-audit: 2026-08-10.
- Release boundary: breaking corrections are permitted before 3.14.0.
- Dependencies: Feature 1 typed environment, Feature 3 adapter interface,
  Feature 5 database URL parser and Feature 18 paginated results.
- Dependants: ORM, migrations, sessions, cache, queues, dev-admin and every
  application call to `insert`, `update`, `delete` or `truncate`.
- Existing fixture: four byte-identical copies of
  `write_path_contract.json`, SHA-1
  `7d31ae77e997de78791871f7986614aa509740e5`, executed by all four runtimes.
- Proposed authority: `fixtures/write_path_contract.json` in this repository.

The old packet marked this feature closed after its original 22-case fixture
passed. That status is withdrawn. The fixture proves part of the safe-write
change, but it encodes stale boundaries and misses several four-for-four defects.

## Why this feature exists

A developer should be able to write data through the same small Tina4 surface on
any supported database without constructing dialect SQL, converting framework
results, or risking a silent full-table mutation.

## Boundary

Feature 4 owns the public, engine-neutral write composition performed by the
`Database` facade:

- insert one record or a homogeneous list of records;
- update through an explicit map filter, an SQL fragment plus parameters, or a
  complete primary key extracted from the data;
- delete through an explicit map filter or SQL fragment plus parameters;
- an explicit all-row `truncate` operation;
- safe identifier construction, parameter binding and `DatabaseResult` write
  semantics;
- application-level parity across every database provider.

Feature 3 owns native execution, batching, transactions, connection lifecycle
and catalog access. Feature 18 owns fetch envelopes and pagination. ORM identity,
dirty tracking and model persistence belong to Features 13-17. Provider-specific
connection and catalog mechanisms belong in Feature 4.1-4.7 packets.

CRUD construction is not an adapter capability. Moving it back onto individual
adapters would recreate the drift this feature exists to prevent.

## Existing implementation evidence

### Current fixture baseline

The existing 22 cases are genuinely wired into all four runtimes; each runner
also rejects orphaned fixture cases. Local SQLite results on 2026-08-10 were:

| Framework | Result |
| --- | --- |
| Python | 42 passed across write, path and SQLite type checks |
| PHP | 48 passed; a separate absolute-path set passed 29 |
| Ruby | 61 examples, 0 failures |
| Node | 23 write cases and 14 absolute-path cases passed |

The lab ran as root against real PostgreSQL, MySQL and MSSQL. The write fixture
passed on all four runtimes and all three engines. Ruby emitted transaction-state
warnings on PostgreSQL and MSSQL; those are already recorded by Feature 3 and a
green result may not suppress them.

### Firebird falsifies the closed status

The same fixture was run against the live Firebird service on the lab:

| Framework | Result | Material failures |
| --- | --- | --- |
| Python | 46 passed | none in this run |
| PHP | 24 tests: 2 errors, 8 failures | empty PK introspection; update/delete/truncate report 0 affected rows |
| Ruby | 24 examples, 10 failures | missing/wrong PKs; update/delete/truncate report 0 affected rows |
| Node | 20 passed, 3 failed | truncate reports 1 instead of 2; Firebird-folded PK names compared case-sensitively |

The old Python runner comment saying Firebird hangs is stale. It completed in
0.61 seconds in this run. Firebird is therefore a required provider gate, not an
excluded service.

## Public surface contract

| Concept | Python | PHP | Ruby | Node / another camelCase language |
| --- | --- | --- | --- | --- |
| insert | `insert(table, data)` | `insert($table, $data)` | `insert(table, data)` | `insert(table, data)` |
| update | `update(table, data, filter=None, params=None)` | `update($table, $data, $filter = null, $params = [])` | `update(table, data, filter = nil, params = nil)` | `update(table, data, filter?, params?)` |
| delete | `delete(table, filter, params=None)` | `delete($table, $filter, $params = [])` | `delete(table, filter, params = nil)` | `delete(table, filter, params?)` |
| truncate | `truncate(table)` | `truncate($table)` | `truncate(table)` | `truncate(table)` |
| primary key | `primary_key(table)` | `primaryKey($table)` | `primary_key(table)` | `primaryKey(table)` |

All public write operations return `DatabaseResult`. They never return a driver
cursor, integer, boolean, `success: false` object or per-row result list.

## Inputs and outputs

### Insert

- A record is a non-empty native map from column name to native value.
- A list insert accepts zero or more records. An empty list is a successful no-op
  with `affected_rows = 0` and `last_id = null`.
- Every record in a non-empty list has exactly the same key set. A ragged batch
  throws before the first write; missing values are not silently converted to
  null and do not bypass database defaults.
- An empty record is invalid and throws before SQL generation. Tina4 does not
  guess whether the caller intended `DEFAULT VALUES`.
- A non-empty batch is atomic under the Feature 3 transaction rules.

### Update

- `data` is a non-empty native map.
- An explicit filter is either a non-empty native map or a non-blank SQL fragment
  with its values supplied separately in `params`.
- With no explicit filter, the facade obtains the full ordered primary key. Every
  key component must be present in `data`; partial and absent keys throw before a
  write. Key fields form the filter and are removed from the `SET` list.
- After key extraction, an empty `SET` list is a successful no-op with zero
  affected rows; Tina4 does not issue invalid SQL.
- An explicit filter may intentionally match multiple rows.

### Delete and truncate

- `delete` requires a non-empty map or non-blank SQL fragment plus bound params.
  Missing and empty filters throw before a write.
- `truncate` is the only facade operation whose purpose is removing all rows.
  It guarantees an empty table but does not guarantee identity/sequence reset;
  a migration may use provider-specific DDL when reset semantics are required.

### Filter maps

- Each map entry is joined with `AND` and its value is bound.
- A native null compiles to `IS NULL`, with no bound parameter for that entry.
- Non-null values compile to equality with a bound parameter.
- Map key order cannot change the matched rows.
- More complex predicates use the explicit SQL-fragment escape hatch. Values
  remain parameters; the caller never interpolates them into the fragment.

### Results

- `affected_rows` means rows matched by the completed write, not statements,
  chunks, or only rows whose stored bytes changed. Providers must select native
  driver modes that provide matched-row semantics or normalize them reliably.
- Insert reports a generated scalar in `last_id` only when the same operation and
  connection can report it reliably. A caller-supplied primary key is not a
  generated id and yields null.
- Update, delete and truncate always return `last_id = null`.
- Failure throws and the facade records the cause for `get_error` / `getError`.

## Introspection required by safe writes

`primaryKey` returns every key column in the order declared by the database.
Table-column order is not a substitute. The current Feature 3 descriptor retains
only a boolean and all four SQLite implementations therefore return `(a, b)` for
columns declared with `PRIMARY KEY (b, a)`.

Feature 3 must add the native integer `primary_key_position` /
`primaryKeyPosition`, null for a non-key column. `primaryKey` sorts positive
positions and returns the corresponding names.

Unquoted identifier comparisons follow the provider's case-folding rules.
Firebird may report `ID` for an unquoted `id`; a fixture must not fail on casing
alone. Quoted identifiers preserve exact case. When matching data keys to
introspected unquoted keys, Tina4 compares case-insensitively while retaining the
caller-facing key spelling.

## SQLite provider contract (Feature 4.1)

- The default URL and `:memory:` open SQLite through one registered provider.
- Absolute paths remain absolute; relative paths resolve from the application
  root according to Feature 5.
- Foreign-key enforcement is enabled for every connection.
- File-backed databases request WAL journal mode. An in-memory database may
  report `memory`, because SQLite cannot apply WAL there.
- Busy timeout is 5000 ms on every SQLite implementation. Immediate lock failure
  and an unbounded or 30-second stall are both parity defects.
- Catalog methods return user tables only and exclude `sqlite_%` internal tables.
- Close is idempotent.
- Any valid row-returning SQLite statement, including PRAGMA, can pass through
  `fetchOne`; the facade must not append `LIMIT` blindly.
- Native null, integer, float, text and bytes survive the adapter boundary. Public
  boolean fields are normalized by the framework metadata layer where a schema
  declares them; SQLite itself has no boolean storage class.
- PHP may keep its tested `ext-sqlite3` / `pdo_sqlite` fallback family. They are
  two native implementations of one provider contract.
- Ruby has one registered SQLite driver. Its separately exported legacy
  `Adapters::Sqlite3Adapter` is removed rather than maintained as a second,
  contradictory implementation.

Node keeps the zero-dependency `node:sqlite` provider and raises its supported
runtime from the inaccurate `>=22.0.0` claim to `>=24.15.0`. Node added the API
in 22.5, unflagged it in 22.13, added the required native timeout option in 24.0,
and promoted it to release-candidate stability in 24.15. The 24.x line is LTS.
This is a pre-3.14 breaking runtime correction, not a silent best-effort import.

Official reference:
<https://nodejs.org/download/release/latest-v24.x/docs/api/sqlite.html>.

## Contradictions and defects

| ID | Finding | Required correction |
| --- | --- | --- |
| DBW-01 | Current fixture is copied into four repos, calls itself Feature 3 and predates the Feature 3 boundary | Centralize the v3 answer key here; runners consume identical copies and enforce all IDs |
| DBW-02 | Null map filters generate `column = NULL` in all four SQLite paths and mutate zero rows | Compile null as `IS NULL` |
| DBW-03 | Reversed composite PK declaration order is lost in all four | Add PK ordinal to Feature 3 descriptors and preserve declared order |
| DBW-04 | Python returns `sqlite_sequence` from `get_tables`; the other three exclude it | Return user tables only |
| DBW-05 | Node throws on a second SQLite `close()` | Make close idempotent |
| DBW-06 | Ruby `fetch_one("PRAGMA busy_timeout")` appends `LIMIT 1` and produces invalid SQL | Delegate to the adapter first-row primitive without blind rewriting |
| DBW-07 | Python/PHP/Ruby/Node SQLite busy timeouts are 30000/5000/0/0 ms | Converge on 5000 ms |
| DBW-08 | Ruby exports an unused legacy SQLite adapter alongside its registered driver | Remove the legacy implementation and export |
| DBW-09 | Ragged inserts either throw late or silently write null instead of a database default | Validate homogeneous keys before the first write |
| DBW-10 | Existing explicit-ID case permits a set or null `last_id` | Generated-only `last_id`; split generated and explicit-ID cases |
| DBW-11 | Firebird write parity is red in PHP, Ruby and Node | Fix provider introspection and affected-row accounting; add a mandatory live gate |
| DBW-12 | Ruby PostgreSQL/MSSQL success paths emit transaction warnings | Resolve under Feature 3; Feature 4 gate also rejects warnings |
| DBW-13 | Node claims `>=22.0.0`, where `node:sqlite` does not exist until 22.5 and is flagged until 22.13 | Raise the declared and tested minimum to Node 24.15 |

## Owner decisions

The following rules are derived from the approved Tina4 principles and are
recorded as the recommended audit result, pending owner review:

1. CRUD composition stays on the public facade; adapters expose Feature 3
   primitives only.
2. Invalid or ambiguous writes fail before touching the database.
3. Null map filters mean SQL `IS NULL`.
4. Batch records must have identical keys and the batch is atomic.
5. Empty records fail; empty record lists are successful no-ops.
6. Affected rows means matched rows across providers.
7. Primary-key order is declared-key order and becomes descriptor data.
8. SQLite uses a 5000 ms busy timeout, foreign keys and file-backed WAL.
9. `getTables` lists user tables, not provider internals.
10. Node uses built-in SQLite and requires Node 24.15 or newer.
11. `truncate` empties the table but does not promise sequence reset.

Changing one of these decisions changes the shared fixture. The packet remains
decision-ready, not contract-complete, until the owner accepts or changes them.

## Proposed conformance fixture

The central replacement fixture must assign stable IDs and cover at least these
invariant groups. Each runtime discovers every ID exactly once and fails on
unknown, missing or duplicate IDs.

| Group | Required cases and mutation witnesses |
| --- | --- |
| `DBW-I` insert | generated ID, explicit ID null, empty list no-op, empty map error, homogeneous batch, ragged batch preflight, duplicate-key rollback; fresh-connection row count |
| `DBW-U` update | explicit map, SQL+params, extracted single/composite PK, reversed PK order, partial/missing key error, empty SET no-op, multi-row filter; untouched sibling rows |
| `DBW-D` delete/truncate | both filter forms, missing/empty filter errors, explicit truncate, no sequence-reset promise; fresh-connection rows |
| `DBW-F` filters | string, integer, boolean and null values; injection payload remains data; SQL trace plus durable rows |
| `DBW-R` results | matched affected rows including same-value update, generated-only last ID, no stale ID, facade error state; second connection |
| `DBW-T` transactions | standalone commit, explicit rollback, mid-batch failure rollback, no success-path warnings; fresh connection and captured logs |
| `DBW-P` providers | SQLite plus live PostgreSQL, MySQL, MSSQL and Firebird; no service skip on the lab |
| `SQL-*` SQLite | memory/file path, FK, WAL exception in memory, 5000 ms lock timeout, user-table catalog, PK ordinals, native types, PRAGMA fetchOne, idempotent close |

MongoDB and ODBC cannot be declared green by this SQL-shaped fixture alone.
Their Feature 4.6 and 4.7 packets must map the same application invariants onto
real provider operations and explicitly record any unsupported capability. A
provider exception is contract data, not a skipped test.

## Integration map

Implementation must update these together after the audit phase closes:

- the central fixture and four fail-closed runners;
- public `Database` facade and shared SQL builder;
- Feature 3 column descriptor and every provider catalog query;
- every registered SQL provider, cache wrapper and connection pool;
- Ruby exports and Node runtime/package metadata;
- ORM, migration, session, cache and queue callers that depend on write results;
- lab service gate for SQLite, PostgreSQL, MySQL, MSSQL and Firebird;
- framework documentation, release notes and the 3.14 migration guide.

## Breaking changes and migration

- Ragged batches and empty records that previously wrote null or produced invalid
  SQL now throw. Pass complete, homogeneous records.
- Map filters containing null now match SQL nulls. Use an explicit SQL fragment
  when a different predicate is intended.
- `affected_rows` converges on matched rows; callers must not use it as a test for
  whether stored bytes changed.
- Caller-supplied IDs no longer appear as generated `last_id` values.
- Internal SQLite tables disappear from `getTables`.
- Ruby's legacy SQLite adapter export is removed; construct `Database` or use the
  registered driver.
- Tina4 Node requires Node 24.15 or newer for the built-in SQLite contract.

## Implementation backlog

1. Approve or amend the eleven owner decisions.
2. Amend Feature 3 with primary-key position and generate the new central fixture.
3. Rewire all four runners to the central v3 cases without framework changes.
4. Capture the expected red matrix on local SQLite and all live lab providers.
5. Correct the shared facade/filter builder first.
6. Correct SQLite lifecycle, catalog and runtime gaps in all four.
7. Correct Firebird introspection and affected-row accounting.
8. Audit and implement Feature 4.2-4.7 provider packets independently.
9. Run the complete no-skip provider matrix and only then mark Feature 4 stable.

## Porting capsule

A new language implements Feature 3 first. It then builds one public write facade
that validates records and filters before SQL generation, quotes only trusted
identifiers, binds every value, extracts an ordered complete primary key for
filterless updates, delegates execution and batching once, returns the shared
`DatabaseResult`, and throws while preserving the engine cause. Every SQL provider
must pass the same application cases against a real engine. SQLite additionally
enables foreign keys, requests file WAL, waits at most five seconds on a lock,
hides internal tables, preserves key ordinals and closes idempotently.

The implementer uses this packet, Feature 3, the provider packet and the central
fixture. Reading another Tina4 runtime is neither required nor authoritative.

## Audit closure checklist

- [x] Boundary and public surface drafted.
- [x] Lifecycle, inputs, outputs, failures and mutation witnesses drafted.
- [x] Existing-language and live-provider contradictions recorded.
- [ ] Owner decisions approved or amended.
- [ ] Central replacement fixture materialized after decisions.
- [ ] Feature 4.1-4.7 provider packets completed.
- [x] Integration and breaking migrations identified.
- [x] Porting capsule is clean-room sufficient for the parent write contract.
