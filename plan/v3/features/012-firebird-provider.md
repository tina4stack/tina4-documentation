# Feature 012: Firebird provider

## Identity and status

- Matrix identity: 12 - Firebird provider
- Audit state: decision-ready
- Dependencies: Feature 3 adapter interface, Feature 4 URL parser, Feature 5 write facade,
  Feature 7 SQL translator (ROWS/FIRST-SKIP rewrite, `MAX_BIND_PARAMS = 0`)
- Dependants: migrations, ORM, pagination, Firebird-backed session/cache/queue
- Existing ADRs: ADR-0044 (batch/first-row primitives, `connect` canonical name); the
  connect-timeout contract applies and is CURRENTLY UNMET here (FB-02)
- Shared fixtures: `write_path_contract.json`; a `firebird_contract.json` is required
- Catalog phase: Database providers
- Open issues: statement-leak parity (task 56), node-firebird SRP flakiness (task 60), PHP
  ORM vs real FB5 (issue 132); the PHP IBASE_WAIT hang (issue 55) and column-case (task 59)
  are fixed but need parity proof
- Audit note: measured from four-language source; no framework code changed

## Why this feature exists

Firebird gives a Tina4 application an embedded-or-server SQL database whose behavior stays
interchangeable with the other providers. Firebird is the strictest engine on identifier
case, generated ids and connection bounding, so it exposes contract gaps the other
providers hide.

## Boundary

This provider owns Firebird connection construction, native binding and round-trip,
generated-id capture, catalog queries and lifecycle. Feature 3 owns the adapter
capabilities, Feature 4 parses the URL, Feature 5 composes CRUD, and Feature 7 rewrites
`LIMIT`/`OFFSET` to `ROWS m TO n` (or `FIRST/SKIP`) and sets the zero bind-collapse ceiling.
Identifier quoting (double quotes, case-sensitive) stays on the adapter.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Driver | `fdb`/`firebird-driver` | `interbase`/`pdo_firebird` | `fb` | `node-firebird` |
| Placeholder | `?` | `?` | `?` | `?` |
| INSERT id capture | `INSERT ... RETURNING` | `INSERT ... RETURNING` | driver id, no RETURNING | driver id, no RETURNING |
| Row limiting | `ROWS`/`FIRST SKIP` | `ROWS` | `ROWS` | `ROWS` |
| Identifier case | maps UPPERCASE -> lowercase | maps (issue 132) | maps (task 59) | maps in `baseModel` |
| Connect bound | timeout referenced | IBASE_WAIT fixed (issue 55) | timeout referenced | SRP login flaky ~12% (task 60) |
| Batch collapse | none (`MAX_BIND_PARAMS = 0`) | none | none | none |

Firebird supports `INSERT ... RETURNING`, and Python and PHP use it to capture the
generated id; Ruby and Node instead read the driver's own last-id and do not emit
RETURNING (FB-01). Firebird stores an unquoted identifier in UPPERCASE, so every port maps
column names to the Python master's lowercase (FB-05). Firebird has no cheap multi-row
`VALUES`, so `MAX_BIND_PARAMS = 0` keeps a batch per-row rather than collapsing it. The PHP
rollback path and `IBASE_WAIT` hang were fixed with live CI; that is regression evidence,
not full parity evidence.

## Public surface contract

The provider implements the Feature 3 adapter interface with no extra public surface:
connection (`connect`, `close`, `getDatabaseType` -> `firebird`), execution (`execute`,
`executeMany`, `fetch`, `fetchOne`), transactions and introspection. Construction takes
Feature 4's resolved connection parameters.

## Inputs and outputs

- Native types round-trip: `INTEGER`/`BIGINT`, `NUMERIC`/`DECIMAL`, `DOUBLE PRECISION`,
  `VARCHAR`/`CHAR`/`BLOB SUB_TYPE TEXT`, `BLOB` as raw bytes, and `TIMESTAMP`/`DATE`/`TIME`.
  Firebird has no native boolean before 3.0; a boolean maps to the engine's boolean on 3.0+
  and to a small integer below it.
- `execute` on an INSERT returns a `DatabaseResult` carrying the generated id from
  RETURNING (Python/PHP) or the driver's last id (Ruby/Node) -- these must converge.
- Column names in a result are lowercased to match the Python master, hiding Firebird's
  UPPERCASE storage.
- `getColumns` returns the Feature 3 descriptor including the PK ordinal; `getTables`
  returns user tables and excludes `RDB$` system tables.
- Binding preserves parameter order; a null keyed-map value compiles to `IS NULL`.

## Lifecycle and operation graph

1. Feature 4 resolves the `firebird:`/`fb:` URL to host, port/path, database, credentials.
2. `connect` opens the connection; the connect MUST be bounded (FB-02) so an unreachable
   server cannot hang forever.
3. A write captures the generated id (converging on RETURNING); a batch stays per-row.
4. Transactions bracket through the native mode; `autocommit` reflects and sets it; a
   prepared statement is closed after use so handles do not leak (FB-04).
5. `close` releases the connection and is idempotent; catalog inspection never mutates.

## Configuration and precedence

- The connect MUST be bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` (default 10). This is
  currently unmet: a Firebird connect to an unreachable host hangs past the bound (FB-02).
- Connection identity comes only from Feature 4. There are no other Firebird-specific
  environment variables.

## Failures, side effects and security

- Values are always bound (`?`); identifiers are quoted with double quotes by the trusted
  builder only.
- A prepared statement is released after execution; an unreleased handle exhausts the
  server's statement pool over time (FB-04).
- The connect must fail within the timeout naming host, port, elapsed seconds and the
  timeout variable; today it can hang (FB-02).
- A driver error throws and retains Firebird's cause; it never becomes an empty read or a
  false write result.

## Wire and persistence contract

Communication is the Firebird wire protocol through the host driver. Values round-trip as
their native types; `BLOB` is raw bytes, `TIMESTAMP` preserves the value, and identifiers
round-trip case-folded to lowercase in results. The generated id comes from RETURNING.
The `ROWS`/`FIRST SKIP` rewrite and per-row batching change only SQL shape, never
parameter order.

## Providers and substitutability

Each language uses its host's Firebird driver over `?` placeholders. PHP carries a native
`interbase` path and a `pdo_firebird` fallback as one family. A future runtime satisfies
the same fixture with its own driver, including the bounded connect.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| FB-01 | INSERT id capture diverges: Python/PHP use `RETURNING`, Ruby/Node read the driver last-id. A UUID or trigger-assigned PK returns a different value across ports. | Converge on `INSERT ... RETURNING` in all four. |
| FB-02 | The connect is NOT bounded: an unreachable Firebird host hangs past `TINA4_DATABASE_CONNECT_TIMEOUT`. This is an open defect on the shipping branch. | Bound the connect (a watchdog if the driver cannot) and gate an unreachable-host timeout in all four. |
| FB-03 | node-firebird SRP login fails intermittently (~12%) against Firebird 5. | Reproduce and fix the SRP handshake so connect is deterministic. |
| FB-04 | Statement-handle leak parity is unverified in Python, Ruby and Node. | Prove a prepared statement is released after use in all four (a long loop must not exhaust the pool). |
| FB-05 | Identifier case-folding (UPPERCASE storage -> lowercase result) is fixed per-port but not gated as parity. | Gate a mixed-case column read returning the Python master's lowercase in all four. |
| FB-06 | Boolean handling differs between Firebird versions (native 3.0+ vs integer below). | Pin one boolean representation the fixture proves on the lab Firebird version. |
| FB-07 | PHP ORM behavior against a real Firebird 5 (issue 132) is not fully closed. | Run the ORM fixture against live FB5 in PHP. |
| FB-08 | No shared Firebird fixture exists. | Add `firebird_contract.json`. |

## Owner decisions

1. `INSERT ... RETURNING` is the canonical generated-id capture in all four (converging
   Ruby and Node onto it), because a generator/trigger PK is otherwise wrong.
2. The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT`; if a driver cannot bound its
   own login, the provider wraps it in a watchdog so an unreachable host fails within the
   bound. FB-02 blocks provider sign-off.
3. A prepared statement is always released after execution; leak-freedom is gated.
4. Result column names are lowercased to the Python master in all four.
5. `MAX_BIND_PARAMS = 0` keeps a Firebird batch per-row; there is no VALUES collapse.

## Proposed conformance fixture

Add `firebird_contract.json` (with `write_path_contract.json`) with stable ids for: a
bounded connect and an unreachable-host timeout that RETURNS (not hangs); `INSERT ...
RETURNING` id capture including a trigger-assigned PK; a mixed-case column read returning
lowercase; a `ROWS`/`FIRST SKIP` paginated read; `BLOB` round-trip; a boolean on the lab
Firebird version; a long insert loop proving no statement-handle leak; `getTables`
excluding `RDB$` system tables; `getColumns` PK ordinal. Every behavioral case uses the
live lab Firebird 5; no mock can claim conformance, and FB-02/FB-03 must be proven against
a real unreachable host and a real SRP login.

## Integration map

- The registry selects this provider from `firebird:`/`fb:`; the factory constructs it with
  Feature 4's parameters.
- Feature 5 composes CRUD; Feature 6 builds SQL; Feature 7 owns the ROWS/FIRST-SKIP rewrite,
  double-quote quoting and the zero bind-collapse ceiling.
- Migrations, ORM, pagination and any Firebird-backed session/cache/queue consume the
  adapter; `get_next_id` uses a Firebird generator.
- Central fixtures, four runners, CI matrix, release notes and docs update together.

## Breaking changes and migration

- Ruby and Node move to `INSERT ... RETURNING`; a generator/trigger PK now returns the
  correct id.
- The connect becomes bounded; an application pointed at a dead host now fails fast instead
  of hanging.
- No application SQL changes; corrections are provider-internal.

## Implementation backlog

1. Add `firebird_contract.json` and wire four runners against the live lab Firebird 5.
2. Bound the connect (watchdog if needed); gate an unreachable-host timeout (FB-02).
3. Fix node-firebird SRP flakiness (FB-03).
4. Converge INSERT id capture on RETURNING in Ruby and Node (FB-01).
5. Gate statement-leak-freedom (FB-04) and column-case parity (FB-05).
6. Run the ORM fixture against live FB5 in PHP (FB-07).
7. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Use the host's Firebird driver over `?` placeholders. Bound the connect (wrap the login in
a watchdog if the driver will not honor a timeout), capture the generated id with `INSERT
... RETURNING`, release every prepared statement after use, and lowercase result column
names to the Python master. Quote identifiers with double quotes, exclude `RDB$` system
tables, keep a batch per-row (`MAX_BIND_PARAMS = 0`), and make lifecycle idempotent. Prove
the port against a live Firebird 5, including a real unreachable-host timeout that returns.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
