# Feature 008: SQLite provider

## Identity and status

- Matrix identity: 8 - SQLite provider
- Audit state: decision-ready
- Audit note: Decision-ready; implementation deliberately not started
- Dependencies: Features 3, 4 and 5.
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: proposed `write_path_contract.json` and
  `sqlite_contract.json` in `plan/v3/fixtures`.

- Parent: Feature 5 database write facade and provider conformance.
- Re-audited: 2026-08-10.

## Why this feature exists

SQLite gives every Tina4 application a zero-configuration database whose public
behavior is still interchangeable with a deployed SQL provider.

## Boundary

This packet owns SQLite connection construction, file/memory paths, pragmas,
native value binding, catalog queries and lifecycle. Feature 3 owns the adapter
capabilities. Feature 5 owns CRUD composition. Feature 4 owns URL parsing.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Startup/CLI integration | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Stored/wire format | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing focused tests | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing lab baseline | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Primary implementation | stdlib `sqlite3` | `ext-sqlite3` with tested PDO fallback | registered `Drivers::SqliteDriver` | built-in `node:sqlite` |
| Extra implementation | none | deliberate fallback | stale exported `Adapters::Sqlite3Adapter` | none |
| Busy timeout measured | 30000 ms | 5000 ms | 0 ms | 0 ms |
| Foreign keys measured | enabled | enabled | enabled | enabled |
| User tables after AUTOINCREMENT table | includes `sqlite_sequence` | excludes internal table | excludes internal table | excludes internal table |
| Double close | succeeds | succeeds | succeeds | throws |
| Reversed composite PK declaration | returns table order | returns table order | returns table order | returns table order |
| Null map filter | matches zero rows | matches zero rows | matches zero rows | matches zero rows |

Focused local suites were green before these adversarial probes: Python 42,
PHP 48, Ruby 61 and Node 23 write-contract cases, plus provider-specific path
checks. The green baseline is retained as regression evidence but is not parity
evidence for the rows above.

## Public surface contract

The SQLite provider implements the Feature 3 adapter interface; it exposes no public
surface of its own beyond construction. Every language provides the same adapter
capabilities, selected from a `sqlite:` URL by the registry:

- connection: `connect`, `close`, `getDatabaseType` (returns `sqlite`);
- execution: `execute`, `executeMany`, `fetch`, `fetchOne`;
- transaction: `startTransaction`, `commit`, `rollback`, `autocommit`;
- introspection: `getTables`, `getColumns`, `tableExists`.

Names follow each language's Feature 3 spelling (snake_case in Python/Ruby, camelCase in
PHP/Node). Identifier quoting stays on the adapter (`quote_identifier`), because SQLite's
`"..."`/`[...]` rules are its own. The provider adds no query methods; a query is built by
Feature 6 and executed through these primitives. The only construction input is the
resolved target (`:memory:` or a filesystem path) that Feature 4 hands it.

## Inputs and outputs

- SQLite's five storage classes cross the adapter boundary as native values: NULL as
  null/nil/None, INTEGER as a native integer, REAL as a native float, TEXT as a string,
  and BLOB as native bytes. SQLite's dynamic typing is not disguised as a native boolean;
  a 0/1 column reads back as an integer.
- `fetch` returns a native list of record maps; `fetchOne` returns one record map or
  null. `execute` returns a `DatabaseResult` (write result), `executeMany` one aggregate
  `DatabaseResult`.
- `getColumns` returns the Feature 3 descriptor per column, including name, declared type,
  nullability, default, and the SQLite `pk` ordinal exposed as
  `primary_key_position`/`primaryKeyPosition`. `primaryKey` returns the key columns sorted
  by positive ordinal, so a reversed composite-key declaration preserves declared order.
- `getTables` returns application/user tables only, excluding every `sqlite_%` internal
  table (including `sqlite_sequence`, which an AUTOINCREMENT table creates).
- Binding preserves parameter order; a null in a keyed map compiles to `IS NULL` (a
  Feature 5 builder rule), not `= NULL` which matches zero rows.

## Lifecycle and operation graph

1. Feature 4 parses the `sqlite:` URL and hands the provider a resolved target
   (`:memory:` or an absolute/relative path already resolved against the app root).
2. `connect` opens exactly that target through the host's maintained SQLite binding,
   then, before any application SQL: enables foreign-key enforcement, sets the busy
   timeout, and requests WAL for a file-backed database (in-memory reports `memory`).
3. A partially opened handle is closed if setup fails; `connect` is idempotent and hides
   no second connection.
4. `execute`/`fetch`/`fetchOne`/`executeMany` run statements; a lock waits up to the busy
   timeout, then throws.
5. Transactions bracket through `startTransaction`/`commit`/`rollback`; `autocommit`
   reflects and sets the native mode.
6. `close` releases the handle and is idempotent (a second close is a safe no-op in every
   language, including Node).

There is no retry policy beyond the busy-timeout wait; a deletion is an ordinary
statement. Catalog inspection (`getTables`/`getColumns`/`tableExists`) reads SQLite's
schema tables and never mutates.

## Configuration and precedence

- The busy timeout defaults to 5000 ms and is overridable by `TINA4_SQLITE_BUSY_TIMEOUT`
  (the Feature 5 SQLite decision). Today it diverges (Python 30000, PHP 5000, Ruby 0,
  Node 0) and converges to 5000.
- Foreign-key enforcement is always on; it is not configurable off (a silent-off would
  make cross-provider behavior diverge).
- WAL is requested for file-backed connections; an in-memory database keeps its native
  journal mode and may report `memory`.
- Native extension loading is disabled and has no enabling env var in 3.14; a future
  security-reviewed configuration is the only path to enable it.
- The path comes only from Feature 4's resolution; the provider never prefixes, rewrites
  or invents a path. There are no other environment variables or project files.

## Failures, side effects and security

- SQL values are always bound.
- Only the trusted builder quotes identifiers.
- A lock timeout, malformed file, read-only write, invalid statement or failed
  pragma throws and is recorded at the facade.
- Failed connection setup closes any partially opened handle.
- Every test owns a temporary file/directory and closes its handle before cleanup.
- The provider never enables arbitrary native extension loading by default.

## Wire and persistence contract

SQLite is embedded, so there is no network wire format; the persistence contract is the
on-disk/in-memory storage and how values round-trip. Values are stored by SQLite storage
class and read back as the native type above. Text is UTF-8. SQLite has no native
date/time or boolean type, so a timestamp is stored and returned as the application's
chosen TEXT/INTEGER shape and a flag as an integer; the provider does not invent a
conversion. A file-backed database in WAL mode carries the standard `-wal`/`-shm`
sidecar files, which are the database's, not the provider's, to manage. Identifiers are
quoted only by the trusted builder; values are always bound, never interpolated. A
database file written by one language's provider is byte-compatible with every other,
because all four use the host's standard SQLite library over the same file format.

## Providers and substitutability

### Provider contract

- `:memory:` creates an isolated in-memory database.
- An absolute filesystem path is not prefixed or rewritten. A relative path is
  resolved by Feature 4 before the provider receives it.
- A missing parent directory fails with a useful path diagnostic; the adapter
  does not silently create an unrelated database elsewhere.
- Foreign-key enforcement is enabled on every connection before application SQL.
- File-backed databases request WAL. In-memory databases may report `memory`,
  because WAL cannot apply to them.
- Busy timeout is 5000 ms. Lock contention waits up to that bound and then throws;
  it is neither an immediate failure nor an indefinite retry policy.
- Extension loading is disabled unless a future explicit security-reviewed
  configuration enables it.
- `getTables` returns application/user tables only and excludes `sqlite_%`.
- `getColumns` supplies Feature 3 descriptor fields including the SQLite `pk`
  ordinal as `primary_key_position` / `primaryKeyPosition`.
- `primaryKey` sorts positive ordinals, preserving declared key order.
- Missing tables produce the normal empty catalog result; catalog SQL failures
  throw.
- `connect` is idempotent and does not hide a second connection. `close` is
  idempotent.
- `fetchOne` accepts every valid row-returning SQLite statement, including
  PRAGMA, without blindly appending pagination SQL.
- Null, integer, real, text and bytes cross the adapter boundary as native values.
  SQLite storage-class behavior is not disguised as a native boolean type.
- Driver errors throw and retain SQLite's cause; they do not become empty reads
  or false write results.

PHP's two implementations are one provider family and run the same cases. Ruby's
legacy adapter is removed so only the registry-selected driver is public.

Node uses `node:sqlite` with `timeout: 5000` and declares Node `>=24.15.0`. The
old `>=22.0.0` floor predates the API (22.5), its unflagged availability (22.13),
the timeout option (24.0) and release-candidate status (24.15). Official Node
reference:
<https://nodejs.org/download/release/latest-v24.x/docs/api/sqlite.html>.

## Contradictions and defects

### Contradictions and required changes

1. Converge busy timeout to 5000 ms.
2. Exclude SQLite internal tables in Python.
3. Preserve primary-key ordinals in all four.
4. Compile null map filters in the Feature 5 builder as `IS NULL`.
5. Make Node close idempotent.
6. Stop Ruby `fetch_one` from appending `LIMIT` to PRAGMA.
7. Remove Ruby's stale second SQLite implementation and export.
8. Raise Tina4 Node's declared/tested minimum runtime to 24.15.

## Owner decisions

No new owner decision is recorded in this migrated section. Retained decisions appear below when present.

## Proposed conformance fixture

The provider fixture requires stable IDs for:

- memory open, absolute path and relative-path handoff;
- parent-path failure;
- foreign-key enforcement;
- file WAL and the documented memory-mode exception;
- measured five-second lock timeout with bounded tolerance;
- internal-table exclusion;
- single and reversed composite PK ordinals;
- integer, real, text, null and binary binding/round trip;
- valid PRAGMA through `fetchOne`;
- bad SQL and read-only write failures;
- double connect and double close lifecycle;
- PHP native/PDO parity and one Ruby registry implementation;
- Node minimum-version and built-in-module checks.

Each behavioral case uses a real temporary SQLite database. No adapter mock can
claim provider conformance.

## Integration map

- The adapter registry selects this provider from a `sqlite:`/`sqlite3:` scheme; the
  database factory constructs it with Feature 4's resolved target.
- Feature 5's write facade composes CRUD onto the adapter primitives; Feature 6 builds the
  SQL; Feature 7 supplies the `AUTOINCREMENT` DDL rewrite and placeholder style.
- `getColumns`/`primaryKey` feed the Feature 3 descriptor to migrations, the ORM and
  `getColumns` consumers; the `pk` ordinal reaches them as `primary_key_position`.
- `get_next_id` sequence support (the `tina4_sequences` table) is created on first use for
  SQLite.
- CLI `migrate`/`doctor`/`generate`, the central `write_path_contract.json` and
  `sqlite_contract.json` fixtures, the four runners, release notes and the database
  documentation all reference this provider and update together.
- Node's package `engines` declares the runtime floor; the framework CI matrix runs
  SQLite on every language.

## Breaking changes and migration

### Integration and migration

Update the adapter registry, factory, catalog descriptor, public facade, Ruby
exports, Node `engines`, framework CI matrix, central fixtures, four runners,
release notes and database documentation together.

Migration effects:

- Python callers no longer see `sqlite_sequence` in `get_tables()`.
- Node users upgrade to Node 24.15 or newer.
- Ruby callers importing the legacy adapter construct the public `Database` or
  use the registered driver.
- Lock conflicts may now wait up to five seconds consistently.

## Implementation backlog

1. Materialize `sqlite_contract.json` and wire the four runners against real memory and
   temporary-file databases.
2. Converge the busy timeout to 5000 ms with the `TINA4_SQLITE_BUSY_TIMEOUT` override in
   all four.
3. Exclude `sqlite_%` internal tables in Python's `getTables`.
4. Preserve primary-key ordinals (`primary_key_position`) in all four, including reversed
   composite keys.
5. Make Node's `close` idempotent (it currently throws on a second close).
6. Stop Ruby's `fetch_one` from appending `LIMIT` to a PRAGMA statement.
7. Remove Ruby's stale second SQLite implementation and its export; keep only the
   registry-selected driver.
8. Raise Tina4 Node's declared and tested minimum runtime to 24.15.
9. Compile null keyed-map filters as `IS NULL` in the Feature 5 builder.
10. Run the fixture locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Use the host's maintained SQLite binding. Open exactly the resolved target,
enable foreign keys, set a five-second busy timeout, request WAL for file-backed
connections, bind every value, expose native records, preserve catalog PK
ordinals, hide `sqlite_%`, implement the Feature 3 primitives and make lifecycle
operations idempotent. Run the shared Feature 5 and SQLite fixtures against real
memory and temporary-file databases.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities recorded (no new decision; inherits Feature 5's, which are ratified).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

- [x] Boundary, configuration, lifecycle and failure rules drafted.
- [x] Existing contradictions measured in all four runtimes.
- [x] Parent Feature 5 owner decisions ratified (2026-08-10).
- [ ] Central SQLite fixture materialized (build phase).
- [ ] Implementation and all four runners completed after the audit phase (build phase).
