# Feature 009: PostgreSQL provider

## Identity and status

- Matrix identity: 9 — PostgreSQL provider
- Audit state: decision-ready
- Dependencies: Feature 3 adapter interface, Feature 4 URL parser, Feature 5 write
  facade, Feature 7 SQL translator
- Dependants: migrations, ORM, pagination, sessions/cache/queue when backed by PostgreSQL
- Existing ADRs: ADR-0044 (batch/first-row primitives); the connect-timeout contract
  ("bound a third-party call") applies here
- Shared fixtures: `write_path_contract.json`; a `postgresql_contract.json` is required
- Catalog phase: Database providers
- Audit note: measured from four-language source; no framework code changed

## Why this feature exists

PostgreSQL gives a Tina4 application a production SQL database whose observable behavior
is interchangeable with SQLite and the other providers, so the same application code and
the same tests run against it without change.

## Boundary

This provider owns PostgreSQL connection construction (host, port, database, user,
password and a bounded connect), native value binding and round-trip, generated-id
capture, catalog queries and lifecycle. Feature 3 owns the adapter capabilities, Feature
4 parses the URL, Feature 5 composes CRUD, and Feature 7 supplies the placeholder style
and any dialect rewrite. Identifier quoting stays on the adapter.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Primary implementation | stdlib driver, `PARAM_MARKER = "%s"` | native `pg_connect` + tested `PdoPostgresAdapter` fallback | registered `PostgresDriver` over `PG.connect`/`exec_params` | `pg` `Client`, async |
| Placeholder to driver | `?` -> `%s` | `?` -> PDO `:named` | `?` -> `$1,$2` | `?` -> `$1,$2` |
| INSERT id capture | `INSERT ... RETURNING *` | `RETURNING *` | `RETURNING *` | `RETURNING *` |
| Non-RETURNING write id fallback | `SELECT lastval()`, SAVEPOINT-guarded | `lastval()`, SAVEPOINT-guarded | leans on RETURNING | leans on RETURNING |
| Connect timeout | libpq `connect_timeout` kwarg | `PDO::ATTR_TIMEOUT` (never DSN keyword) | `PG.connect(connect_timeout:)`, skipped if URL sets it | `Client` timeout option |
| UUID PK generated id | via RETURNING (string) | via RETURNING (string) | via RETURNING (string) | via RETURNING (36-char string) |
| Last id type | int or string | numeric string | int or string | int or bigint or string |

All four converged on `INSERT ... RETURNING *` to read the generated id, because a UUID
primary key (`gen_random_uuid()`) has no sequence and `SELECT lastval()` returns the
wrong value or raises. Python and PHP retain a `lastval()` probe for a non-RETURNING
write, wrapped in a SAVEPOINT so a no-sequence error cannot abort the surrounding
transaction (issue #38). Python additionally captures `cursor.rowcount` BEFORE the
lastval/SAVEPOINT probes run, because those probes' own `execute()` calls were clobbering
`rowcount` and a no-RETURNING INSERT was reporting `affected_rows = 0`. Node fixed a
filter-normalization bug where `truncate()`'s `1 = 1` was rewritten to `WHERE "0" = $1
AND "1" = $2` and failed with `column "0" does not exist`.

Focused suites were green before the parity probes above; that baseline is regression
evidence, not parity evidence.

## Public surface contract

The provider implements the Feature 3 adapter interface with no extra public surface:
connection (`connect`, `close`, `getDatabaseType` -> `postgres`), execution (`execute`,
`executeMany`, `fetch`, `fetchOne`), transactions (`startTransaction`, `commit`,
`rollback`, `autocommit`) and introspection (`getTables`, `getColumns`, `tableExists`).
Construction takes the connection parameters Feature 4 resolved. A query is built by
Feature 6 and executed through these primitives.

## Inputs and outputs

- Native types cross the boundary as native values: integer, numeric/decimal, real,
  boolean (a real PostgreSQL boolean, not disguised), text, `bytea` as raw bytes,
  `timestamptz`/`timestamp`, `json`/`jsonb`, `uuid` and arrays. The provider does not
  reinterpret a stored type.
- `execute` on an INSERT returns a `DatabaseResult` carrying the generated id from
  `RETURNING *`; `get_last_id` is a native integer OR a string (a UUID or a numeric
  string), because a serial id and a UUID id are both valid.
- `getColumns` returns the Feature 3 descriptor including name, type, nullability, default
  and the primary-key ordinal (`primary_key_position`/`primaryKeyPosition`), read from
  `information_schema`/`pg_catalog`.
- `getTables` returns user tables from the public (and configured) schema, excluding
  PostgreSQL system catalogs.
- Binding preserves parameter order; a null keyed-map value compiles to `IS NULL`.

## Lifecycle and operation graph

1. Feature 4 resolves the `postgres:`/`postgresql:` URL to host, port, database, user and
   password.
2. `connect` opens the connection with a bounded connect timeout (below); a failed setup
   closes any partial handle.
3. A write runs with `RETURNING *` to capture the generated id; a non-RETURNING write
   falls back to a SAVEPOINT-guarded `lastval()` (Python/PHP) so a no-sequence table
   cannot abort the transaction.
4. `affected_rows` is read from the write cursor before any id probe runs.
5. Transactions bracket through the native BEGIN/COMMIT/ROLLBACK; `autocommit` reflects
   and sets the mode.
6. `close` releases the connection; catalog inspection never mutates.

## Configuration and precedence

- The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` (default 10 seconds), mapped
  to each driver's native mechanism: libpq `connect_timeout` (Python/Ruby), PDO
  `ATTR_TIMEOUT` (PHP), the `pg` client option (Node). An explicit `connect_timeout` the
  caller sets in the URL wins and is not overridden. PHP deliberately uses
  `PDO::ATTR_TIMEOUT` rather than a DSN `connect_timeout` keyword, because pdo_pgsql
  appends its own keyword and the last one wins, which would silently ignore a DSN value.
- All connection identity (host, port, database, credentials) comes from Feature 4; the
  provider invents nothing. There are no other PostgreSQL-specific environment variables.

## Failures, side effects and security

- Values are always bound (`%s`/`:named`/`$N` per driver, converted from `?`); identifiers
  are quoted only by the trusted builder.
- The connect is bounded, so an unreachable host fails within the timeout with a
  diagnostic naming the host, port, elapsed seconds and the timeout variable, rather than
  hanging.
- A `lastval()` probe runs inside a SAVEPOINT so its no-sequence error is contained and
  never aborts the caller's transaction.
- A driver error throws and retains PostgreSQL's cause; it never becomes an empty read or
  a false write result.
- A partially opened connection is closed on setup failure.

## Wire and persistence contract

Communication is the PostgreSQL wire protocol through the host driver. Values round-trip
as their native PostgreSQL types; `bytea` is raw bytes both ways, `timestamptz` preserves
the instant, `json`/`jsonb` round-trip as native structures, and arrays and `uuid` are
native. The generated id from `RETURNING *` is preserved as-is (a numeric string or a
36-character UUID string, never coerced). Parameter order is preserved through the
placeholder conversion; the conversion changes only the placeholder token.

## Providers and substitutability

PHP's native `pg_connect` implementation and its `PdoPostgresAdapter` fallback are one
provider family selected by whether `ext-pgsql` is present; both run the same cases. Each
language converts the builder's `?` to its driver's placeholder style through the shared
Feature 7 rule and supplies its own identifier quoting. A future runtime uses its host's
maintained PostgreSQL client and satisfies the same fixture.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| PG-01 | The non-RETURNING-write id fallback diverges: Python/PHP probe `lastval()` (SAVEPOINT-guarded), Ruby/Node rely on the RETURNING path only. A raw non-RETURNING INSERT could report a different `get_last_id` across ports. | Define one fallback: RETURNING is canonical, and the SAVEPOINT `lastval()` probe is the shared fallback for a write without RETURNING in all four. |
| PG-02 | `affected_rows` for a no-RETURNING INSERT was zero in Python until `rowcount` was captured before the id probes. The same clobbering must be proven absent in the other three. | Measure and gate `affected_rows` for RETURNING and no-RETURNING writes in all four. |
| PG-03 | Node's `truncate()`/`1 = 1` filter was normalized to positional columns (`column "0" does not exist`); the fix must be parity. | Prove the string-filter path (`1 = 1`, raw WHERE) in all four, not just Node. |
| PG-04 | Connect-timeout is mapped four different ways with two documented override gotchas (PHP DSN keyword, Ruby URL-set skip). | One measured bound with the same default and the same URL-wins rule; gate an unreachable-host timeout. |
| PG-05 | No shared PostgreSQL fixture exists; `write_path_contract.json` covers generic writes but not RETURNING, `bytea`, arrays, `jsonb`, catalog and connect-timeout. | Add `postgresql_contract.json` with PostgreSQL-specific cases. |
| PG-06 | PHP carries two implementations (native + PDO); parity between them is not gated. | Run the same fixture through both PHP implementations. |

## Owner decisions

1. `INSERT ... RETURNING *` is the canonical generated-id capture in all four, because it
   is correct for both serial and UUID primary keys.
2. The SAVEPOINT-guarded `lastval()` probe is the shared fallback for a write that carries
   no RETURNING clause, present in all four, so a raw INSERT reports the same last id
   everywhere and a no-sequence table never aborts the transaction.
3. `get_last_id` returns a native integer or a string; a UUID id is a string and is never
   coerced to a number.
4. The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` mapped to each driver's
   native mechanism, with a caller-set URL `connect_timeout` winning.
5. PHP's native and PDO PostgreSQL implementations are one provider family and pass the
   same fixture.
6. Native PostgreSQL types (boolean, `bytea`, `jsonb`, arrays, `uuid`, `timestamptz`)
   cross the boundary as native values and are never disguised or stringified.

## Proposed conformance fixture

Add `postgresql_contract.json` (plus the shared `write_path_contract.json`) with stable
ids for: connect with a bounded timeout and an unreachable-host timeout; a serial-PK
INSERT reading the id via RETURNING; a UUID-PK INSERT reading the 36-char id; a
non-RETURNING INSERT reading `lastval()` under a SAVEPOINT with a no-sequence table not
aborting; `affected_rows` for RETURNING and no-RETURNING writes; `bytea` round-trip;
`jsonb`, array and `timestamptz` round-trip; a real PostgreSQL boolean; a `1 = 1` /
truncate string filter; `getTables` excluding system catalogs; `getColumns` PK ordinal;
and PHP native-vs-PDO parity. Every behavioral case uses the live lab PostgreSQL; no mock
can claim provider conformance.

## Integration map

- The registry selects this provider from a `postgres:`/`postgresql:` scheme; the factory
  constructs it with Feature 4's parameters.
- Feature 5 composes CRUD; Feature 6 builds SQL; Feature 7 supplies placeholder style and
  the `SERIAL`/`AUTOINCREMENT` DDL rewrite.
- Migrations, ORM, pagination and any PostgreSQL-backed session/cache/queue consume the
  adapter; `get_next_id` uses PostgreSQL sequences.
- The central fixtures, four runners, CI matrix, release notes and database documentation
  update together.

## Breaking changes and migration

- The non-RETURNING-write id fallback converges (PG-01); a raw INSERT's `get_last_id`
  becomes consistent across ports.
- No application SQL changes; these are provider-internal corrections proven by the new
  fixture.

## Implementation backlog

1. Add `postgresql_contract.json` and wire four runners against the live lab PostgreSQL.
2. Converge the non-RETURNING id fallback (SAVEPOINT `lastval()`) in all four.
3. Gate `affected_rows` for RETURNING and no-RETURNING writes.
4. Prove the string-filter/truncate path in all four.
5. Unify the connect-timeout bound and the URL-wins rule; gate an unreachable-host case.
6. Run PHP native and PDO through the same fixture.
7. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Use the host's maintained PostgreSQL client. Open the resolved target with a bounded
connect timeout, bind every value with the driver's placeholder style, capture the
generated id via `INSERT ... RETURNING *`, keep a SAVEPOINT-guarded `lastval()` fallback
for a non-RETURNING write, and return native values (boolean, `bytea` bytes, `jsonb`,
arrays, `uuid`, `timestamptz`) unchanged. Expose the Feature 3 primitives, preserve the PK
ordinal, exclude system catalogs, make lifecycle idempotent, and never coerce a UUID id to
a number. Prove the port against the live lab PostgreSQL with the shared fixtures.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities recorded (6 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
