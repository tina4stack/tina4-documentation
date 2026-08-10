# Feature 008: SQLite provider

## Identity and status

- Matrix identity: 8 — SQLite provider
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

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

The audit has not yet traced every producer, discovery, execution, inspection, retry, rollback, and deletion path.

## Configuration and precedence

The audit has not yet fixed argument, environment, project-file, default, and cache timing precedence.

## Failures, side effects and security

- SQL values are always bound.
- Only the trusted builder quotes identifiers.
- A lock timeout, malformed file, read-only write, invalid statement or failed
  pragma throws and is recorded at the facade.
- Failed connection setup closes any partially opened handle.
- Every test owns a temporary file/directory and closes its handle before cleanup.
- The provider never enables arbitrary native extension loading by default.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

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

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

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

The audit has not yet produced a dependency-ordered backlog for all current languages and future ports.

## Porting capsule

Use the host's maintained SQLite binding. Open exactly the resolved target,
enable foreign keys, set a five-second busy timeout, request WAL for file-backed
connections, bind every value, expose native records, preserve catalog PK
ordinals, hide `sqlite_%`, implement the Feature 3 primitives and make lifecycle
operations idempotent. Run the shared Feature 5 and SQLite fixtures against real
memory and temporary-file databases.

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

- [x] Boundary, configuration, lifecycle and failure rules drafted.
- [x] Existing contradictions measured in all four runtimes.
- [ ] Parent Feature 5 owner decisions approved or amended.
- [ ] Central SQLite fixture materialized.
- [ ] Implementation and all four runners completed after the audit phase.
