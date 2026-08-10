# Feature 003: Database adapter interface

## Identity and status

- Matrix identity: 3 — Database adapter interface
- Audit state: decision-ready
- Audit note: Contract complete; implementation and runner rewiring owed
- Dependencies: Feature 1 typed environment, Feature 5 write result and safe
  filters, Feature 4 database URL parsing, Feature 24 paginated results.
- Dependants: every SQL/ORM/migration/session/cache/queue consumer.
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

- Original audit: 2026-07-28.
- Adversarial re-audit: 2026-08-10.
- Branch context: v3 staging, targeting the 3.14.0 stability boundary.
- Decision: ADR-0044.
- Authoritative fixture: `fixtures/adapter_contract.json`. Copying it into every
  framework and replacing the superseded structural runners is implementation
  work, deliberately deferred until the audit phase closes.

Breaking changes are permitted before 3.14.0. This packet is planning and
contract data only. It does not authorize framework implementation changes.

## Why this feature exists

A developer or a new language implementer needs one small, explicit contract
that makes every database engine interchangeable without converting Tina4
results, guessing optional capabilities, or reading another runtime.

## Boundary

The adapter owns only behavior that genuinely varies by database engine or
driver:

- connection lifecycle and canonical engine identity;
- statement execution, batch execution, row fetching and first-row fetching;
- transaction state and the effective autocommit policy;
- engine catalog introspection.

The facade owns application-facing composition:

- `insert`, `update`, `delete` and `truncate` SQL construction;
- safe filter rules from Feature 5;
- query translation, pagination and count probes;
- query caching and cache invalidation;
- connection-pool selection and transaction pinning;
- facade error state and convenience methods such as `fetchAll`.

The adapter does not own URL parsing, ORM models, migrations, DDL builders,
cache providers or language-independent SQL builders.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Re-audit result

The old audit selected fourteen required methods, but excluded `executeMany`
and `fetchOne` as facade conveniences. That conclusion is superseded.

`executeMany` owns work that cannot be reconstructed safely above an adapter:
one physical connection, native batching, transaction ownership, rollback,
affected-row accounting and generated identifiers. Project measurements for a
500-row PostgreSQL insert were 9848 ms row-by-row versus 15.8 ms batched, with
measured gains of 625x on PostgreSQL, 216x on MySQL and 121x on MSSQL.

`fetchOne` is also a primitive. Deriving it from the public paginated `fetch`
path can trigger a count probe and build a result envelope only to discard it.
Drivers already expose a native first-row operation. The public facade should
delegate to that operation and return the native record or null.

The final contract still has fourteen capabilities, but it removes the two
diagnostic methods that duplicate existing channels:

- `lastInsertId` is not a second call. `execute` and `executeMany` return the
  generated id in `DatabaseResult.last_id` / `lastId`.
- `error` is not an adapter return path. A failed database operation throws.
  The public facade records the cause for `get_error` / `getError` before
  rethrowing it.

### Exact-HEAD evidence

The lab host `nvidia-rtx4500` ran focused suites as root against the same v3
HEADs as the local repositories.

| Framework | HEAD | Focused lab result |
| --- | --- | --- |
| Python | `12cc44bb` | 18 passed |
| PHP | `46f96429` | 16 tests, 58 assertions |
| Ruby | `25ac783` | 37 examples, 0 failures |
| Node | `96a5050e` | 18 structural + 38 batch + 6 facade transaction checks passed |

The live batch paths covered SQLite, PostgreSQL, MySQL and MSSQL. The green
structural tests do not validate the claimed boundary: they read the same JSON
that states `executeMany` and `fetchOne` are absent, then assert that statement.
They do not compare the JSON to the declared interfaces, where both methods are
present in Python, PHP and Node.

Ruby's live MSSQL batch checks also emitted repeated warnings that a standalone
autocommit tried to COMMIT without a matching BEGIN. The rows and assertions
were correct, but an expected success path must not produce transaction-failure
warnings.

### Transaction and batch rules

- Autocommit is on by default.
- `TINA4_AUTOCOMMIT=false` selects strict manual durability.
- An explicit transaction pins one physical adapter/connection for every
  operation until the matching commit or rollback.
- A standalone `executeMany` under autocommit owns one transaction: begin once,
  execute all parameter sets, commit once; any failure rolls back the owned
  transaction and throws.
- `executeMany` inside an explicit transaction joins it. It never begins,
  commits or rolls back the caller's transaction. On failure it throws and the
  caller retains responsibility for rollback.
- A pool never rotates adapters inside a transaction or batch.
- Expected native autocommit states do not log COMMIT-without-BEGIN warnings.
- A provider unable to guarantee atomic batch writes must reject the operation
  before the first write or require a deployment mode that can. It may not
  silently provide partial durability. This is material for standalone MongoDB
  deployments without transaction support.

## Public surface contract

### Required adapter capabilities

Every adapter implements all fourteen. None is optional. Method spelling follows
the host language, but concepts and behavior do not change.

| Contract | Capabilities | Why it belongs on the adapter |
| --- | --- | --- |
| Connection | `connect`, `close`, `getDatabaseType` | Native handshake, cleanup and engine identity |
| Execution | `execute`, `executeMany`, `fetch`, `fetchOne` | Driver binding, cursor/result handling and native batching |
| Transaction | `startTransaction`, `commit`, `rollback`, `autocommit` | Native transaction state and durability |
| Introspection | `getTables`, `getColumns`, `tableExists` | Engine catalogs differ |

Canonical language mappings:

| Concept | Python | PHP | Ruby | Node / another camelCase language |
| --- | --- | --- | --- | --- |
| connect | `connect` | `connect` | `connect` | `connect` |
| database type | `get_database_type` | `getDatabaseType` | `get_database_type` | `getDatabaseType` |
| execute many | `execute_many` | `executeMany` | `execute_many` | `executeMany` |
| fetch one | `fetch_one` | `fetchOne` | `fetch_one` | `fetchOne` |
| start transaction | `start_transaction` | `startTransaction` | `start_transaction` | `startTransaction` |
| table exists | `table_exists` | `tableExists` | `table_exists?` | `tableExists` |

`open` may remain a temporary pre-3.14 migration alias for `connect`, but the
3.14 contract and new ports expose `connect`. Compatibility aliases are not
part of the clean-room formula and must be removed or explicitly deprecated
before the stability boundary.

`autocommit` is a readable and writable native boolean capability. A host
language may express it as a property or through idiomatic accessors; the
behavioral contract does not require a method-shaped API.

### Public database facade

The public `Database` surface includes:

- `execute(sql, params)`;
- `executeMany(sql, parameter_sets)`;
- `fetch(sql, params, limit, offset)`;
- `fetchOne(sql, params)`;
- `fetchAll(sql, params)`;
- `insert`, `update`, `delete`, `truncate`;
- transaction and introspection operations.

The facade delegates `executeMany` and `fetchOne` to the adapter selected or
pinned for the current operation. It does not reimplement either by looping over
`execute` or by unwrapping paginated `fetch`.

## Inputs and outputs

### Parameter binding

- SQL and parameter values are separate inputs. User values are never
  concatenated into SQL.
- `params` defaults to an empty native list.
- `parameter_sets` is a native list of native parameter lists.
- Boolean values are bound using the engine's accepted native representation
  without changing the public value.
- A ragged parameter set or binding-count mismatch throws before a partial
  durable batch can be reported as success.

### `execute`

- Returns the shared `DatabaseResult`, never a bare boolean, integer, driver
  result or `success: false` object.
- `affected_rows` / `affectedRows` is an integer greater than or equal to zero.
- `last_id` / `lastId` is the generated scalar id or null. It is populated on
  the same connection and statement lifecycle as the write.
- Result-set statements may also populate the result records defined by the
  shared result contract.
- Driver failure is thrown and recorded by the facade; it is never converted to
  false or an empty success result.

### `executeMany`

- Takes one statement and zero or more parameter sets.
- Returns one aggregate `DatabaseResult`, not an integer and not a per-row
  result array.
- Empty input is a successful no-op with `affected_rows = 0` and `last_id =
  null`; it opens no transaction and performs no write.
- `affected_rows` is the total number of rows affected, not the number of chunks
  or statements issued.
- `last_id` is the last generated id when the engine can report it reliably,
  otherwise null. It is never guessed from an unrelated connection.
- Chunking or native multi-row SQL is an invisible optimization. It cannot
  change result fields, row order, atomicity or error behavior.

### `fetch`

- The adapter returns a native list of records and preserves native value types.
- Adapter no-row success returns an empty native list, never null.
- The public facade wraps those records in the shared `DatabaseResult` and owns
  pagination, the true-total count and cache behavior defined by Feature 24.
- A bad statement throws; it never becomes an empty successful result.

### `fetchOne`

- Returns one native record/map or null.
- It performs the driver's first-row operation without a pagination count
  probe and without building a public pagination envelope.
- If more than one row matches, it returns the first row in the database's
  result order. Tina4 does not invent an order.
- Native database value types are preserved.
- A bad statement throws and is distinguishable from a valid no-row result.

### Introspection

`getColumns` returns native records with the canonical concepts `name`, `type`,
`nullable`, `default` and `primary_key` / `primaryKey`. Missing tables return an
empty list only where the engine reports a normal no-match; a catalog error
throws. `getTables` returns native strings. `tableExists` returns a native
boolean.

## Lifecycle and operation graph

```text
Database factory -> parse URL (Feature 4) -> construct adapter -> connect
  -> facade chooses one adapter
     -> explicit transaction: pin adapter until commit/rollback
     -> standalone operation: use selected adapter under autocommit policy
  -> execute/fetch/introspect
  -> normalize to Tina4 native result shapes
  -> close idempotently
```

`connect` either establishes a usable connection or throws a diagnostic that
names the engine and endpoint without credentials. Calling `connect` on an
already-connected adapter does not create a second hidden connection. `close`
is idempotent and releases native statements, transactions and sockets owned by
the adapter.

## Configuration and precedence

The facade resolves database configuration in this order:

1. explicit constructor/factory arguments;
2. typed environment returned by Feature 1;
3. framework defaults.

The adapter receives resolved native values. It does not parse `.env` itself.
`TINA4_AUTOCOMMIT` is a native boolean by the time it reaches the adapter.
Credentials are never returned by `getDatabaseType`, cache identity, logs or
errors.

## Failures, side effects and security

- Missing required methods prevent an adapter from being registered or opened.
- There are no optional contract members and no `respond_to?`, `method_exists`
  or TypeScript `?` guards for required capabilities.
- SQL errors, connection errors, transaction errors and binding errors throw.
- The facade records the last failure for `get_error` / `getError`, then
  rethrows the original or a cause-preserving framework exception.
- Failed reads are not cached as empty results. Failed writes invalidate no
  success state and are never reported as successful.
- Parameter binding is mandatory. Identifier quoting is performed only by the
  trusted SQL builder/translator, never by interpolating a user value.
- Error text and logs redact passwords, tokens and URL user-info.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The contract applies to SQLite, PostgreSQL, MySQL/MariaDB, MSSQL, Firebird,
MongoDB and ODBC adapters. Each provider runs the same language-neutral cases
against a real engine. A driver package that is unavailable must fail the
no-skip service gate on the lab; it is not a green conformance result.

Engine-specific mechanisms are allowed. Observable types, transaction ownership,
atomicity and failure boundaries are not.

## Contradictions and defects

### Current contradictions and required changes

| Area | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Declared boundary | Fat base still includes CRUD; `connect` spelling | Interface still includes `query` + CRUD and omits two required declarations | Lean module excludes `execute_many` and `fetch_one`; several methods remain facade fallbacks | Fat sync interface includes CRUD/DDL and optional members |
| `executeMany` result | Aggregate `DatabaseResult` | Adapter integer/union, facade integer | Aggregate `DatabaseResult` at facade | Adapter `{totalAffected}`, facade per-row array |
| `fetchOne` | Adapter + facade | Adapter + facade | Facade/driver query path, not required contract | Adapter + facade, split sync/async |
| Failure type | Mostly raises | Union/bool signatures permit silent failure | Raises, but expected MSSQL autocommit produces warnings | Several adapter CRUD methods return `success:false`; sync stubs deliberately throw for async engines |
| Contract runner | Checks JSON floors, not actual boundary | Same | Same | Same plus allows optional members |

The previous fixture's statement that `executeMany` and `fetchOne` must not be
on an adapter is therefore both architecturally wrong and contradicted by the
code it claims to describe.

## Owner decisions

Recorded from the 2026-08-10 review:

1. The public framework must expose `fetchOne` and `executeMany` or batch.
2. The audit may choose the consistent design without presenting artificial
   options, and should ask only when project knowledge contradicts it.
3. The audit finishes before framework coding.

ADR-0044 records the resulting boundary: both operations are required adapter
primitives and public facade methods; diagnostic accessors leave the adapter.

### Decisions superseding the plan below (finalized 2026-08-10)

The owner settled Feature 3's two open items on 2026-08-10.

- **MongoDB is a FIRST-CLASS SQL adapter**, not scoped out. `MongoDBAdapter`
  implements the full 14-method contract, so the adapter contract OWNS SQL->Mongo
  translation (prior art: `QueryBuilder.toMongo()`). Three sub-points the contract
  must still nail (owed): what `getColumns` returns for a schemaless store (sampled
  documents vs the ORM model), the expected Mongo result for each SQL conformance
  case, and that Mongo transactions require a replica set. The provider list
  (SQLite/PostgreSQL/MySQL/MSSQL/Firebird/MongoDB/ODBC) stands.

- **Node is async to the public surface.** One async adapter contract: the Node
  adapter AND the public `Database`/ORM surface are asynchronous; consumers await.
  Concepts stay identical to the other three (same 14 capabilities); Node returns
  the language's async form. The current sync/async split and the sync stubs that
  throw "Use ...Async" are removed. Documented Node-specific breaking change.

- **`getColumns` descriptor gains `primary_key_position` / `primaryKeyPosition`**
  (amendment from Feature 5's Decision 7, 2026-08-10): null for non-key columns;
  `primaryKey()` sorts by it and returns declared key order, so a composite
  `PRIMARY KEY (b, a)` stays `(b, a)` instead of collapsing to table-column order.

Everything else in the plan below stands.

## Proposed conformance fixture

### Shared conformance fixture

The central `fixtures/adapter_contract.json` defines 40 cases across eight owed
invariant groups. Its SHA-1 is
`42468149fa21d64e293c7447c96a4a06235300c8`.

1. exact required boundary and no optional capabilities;
2. facade delegation without facade reimplementation;
3. native `fetchOne` result and error semantics;
4. aggregate `executeMany` result semantics;
5. standalone and nested transaction ownership;
6. result types and fail-loud behavior;
7. connection lifecycle and introspection;
8. real-provider substitutability and mutation witnesses.

Every framework runner must discover every case ID exactly once. A structural
reflection check is necessary but not sufficient. Each behavioral invariant
names an out-of-band witness such as a fresh connection, server row count,
transaction probe or deliberate old-code mutation.

## Integration map

Implementation must update all of these together:

- adapter interface/base/module/type declaration;
- every built-in adapter and cache wrapper;
- database factory and registry validation;
- public `Database` facade;
- connection pool and transaction pinning;
- ORM write paths and migrations;
- dev-admin and MCP database tools;
- generated type declarations/package exports;
- shared fixtures and four fail-closed runners;
- framework docs, release notes and 3.14 migration notes.

## Breaking changes and migration

- Adapter authors add `executeMany`, `fetchOne`, `getDatabaseType` and
  `autocommit` where missing, and implement the idiomatic async form in Node.
- Adapter authors expose canonical `connect`; a temporary `open` alias must be
  removed or explicitly deprecated before 3.14.0.
- Adapter `fetch` returns a native record list; the public facade, not the
  adapter, constructs the paginated `DatabaseResult`.
- Adapter `executeMany` return values change from integer, `{totalAffected}` or
  per-row array to the shared aggregate `DatabaseResult`.
- Adapter `execute` changes from boolean/unknown/driver result unions to
  `DatabaseResult`.
- `query`, adapter CRUD, adapter DDL, `lastInsertId` and adapter `error` leave
  the required interface. Public CRUD remains on `Database`.
- Node adapter calls become consistently asynchronous; sync methods that only
  say "Use ...Async" are removed from the contract.
- Required optional members become hard requirements or move above the adapter.
- Callers read generated ids from the operation result rather than performing a
  second adapter `lastInsertId` call.

No removed name is silently reinterpreted. Any temporary alias needs an explicit
deprecation and removal point before 3.14.0.

## Implementation backlog

1. Wire new fail-closed runners to every fixture case and capture the expected
   red baseline at the four exact HEADs.
2. Define the shared `DatabaseResult` adapter signatures and registration-time
   completeness check.
3. Implement Python boundary cleanup and remove facade/adapter duplicated CRUD.
4. Implement PHP interface cleanup, uniform result types and direct delegation.
5. Implement Ruby required `execute_many` / `fetch_one` primitives and remove
   fallback/feature-detection paths; fix expected autocommit warnings.
6. Replace Node's sync/async split with one async adapter contract, normalize
   batch results and make the facade delegate.
7. Run SQLite plus live PostgreSQL, MySQL, MSSQL, Firebird, MongoDB and ODBC
   where provisioned. A configured service may not skip.
8. Run deliberate mutations: remove a required method, restore Node per-row
   results, force a nested batch commit, swallow a bad fetch, scatter a batch
   across pool connections and disable atomicity.
9. Run all four full suites on the lab at the implementation HEADs.
10. Add the 3.14 breaking migration guide and flip each fixture invariant from
    owed to proven only after all four runners pass.

## Porting capsule

A new language implements Feature 3 without reading another runtime:

1. Define the fourteen required adapter capabilities above with no optionals.
2. Define the shared native `DatabaseResult` and record shapes.
3. Implement one real SQLite adapter first.
4. Build the public facade so `executeMany` and `fetchOne` delegate directly.
5. Add explicit adapter registration that rejects incomplete implementations.
6. Add one-connection transaction pinning and the autocommit rules.
7. Add PostgreSQL or another network adapter to prove the interface is not
   SQLite-specific.
8. Run every shared fixture case against real engines.
9. Prove the negative mutations fail.
10. Only then expose the adapter through ORM, migration, cache and tooling
    integrations.

## Audit closure checklist

- [ ] Wire/storage and provider contracts complete.
- [ ] Owner ambiguities decided and recorded.

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Provider and transaction behavior complete.
- [x] Existing-language contradictions recorded.
- [x] Owner direction recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

**Audit conclusion:** Feature 3 is contract-complete and implementation-red. It
must not be described as shipped or parity-complete until the new behavioral
fixture is executed by all four runners on real providers.
