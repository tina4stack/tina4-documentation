# Feature 011: MSSQL provider

## Identity and status

- Matrix identity: 11 - MSSQL (SQL Server) provider
- Audit state: decision-ready
- Dependencies: Feature 3 adapter interface, Feature 4 URL parser, Feature 5 write facade,
  Feature 7 SQL translator (TOP/OFFSET rewrite, `MAX_BIND_PARAMS = 2100`)
- Dependants: migrations, ORM, pagination, MSSQL-backed session/cache/queue
- Existing ADRs: ADR-0044 (batch/first-row primitives, `connect` canonical name); the
  connect-timeout contract applies
- Shared fixtures: `write_path_contract.json`; a `mssql_contract.json` is required
- Catalog phase: Database providers
- Audit note: measured from four-language source; no framework code changed

## Why this feature exists

SQL Server gives a Tina4 application an enterprise SQL database whose behavior stays
interchangeable with the other providers, so the same application code and tests run
against it unchanged.

## Boundary

This provider owns MSSQL connection construction, native binding and round-trip,
generated-id capture, catalog queries and lifecycle. Feature 3 owns the adapter
capabilities, Feature 4 parses the URL, Feature 5 composes CRUD, and Feature 7 rewrites
`LIMIT`/`OFFSET` to `TOP`/`OFFSET ... FETCH NEXT` and enforces the 2100-parameter ceiling.
Identifier quoting (`[brackets]`) stays on the adapter.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Driver | `pyodbc`/`pymssql` | `sqlsrv`/`pdo_sqlsrv` | `tiny_tds` | `tedious` |
| Placeholder to driver | `?` -> `%s` | `?` (mixed `@p`/`:named`) | `?` | `?` -> `@p0,@p1` |
| Row limiting | `TOP` / `OFFSET ... FETCH NEXT` | same | `OFFSET ... FETCH NEXT` | `TOP` / `OFFSET ... FETCH` |
| Identifier quote | `[bracket]` | `[bracket]` | `[bracket]` | `[bracket]` |
| Generated id | IDENTITY capture after INSERT | IDENTITY capture | IDENTITY capture | IDENTITY capture, `_lastInsertId` |
| Connect timeout | driver timeout | driver timeout | driver timeout | tedious timeout |
| Bind ceiling | 2100 (Feature 7) | 2100 | 2100 | 2100 |

MSSQL has no `LIMIT`; Feature 7 rewrites a limit-only query to `SELECT TOP n` and a
limit-with-offset to `OFFSET n ROWS FETCH NEXT m ROWS ONLY`. The generated id comes from
SQL Server's IDENTITY mechanism captured after the INSERT; the exact keyword
(`SCOPE_IDENTITY()` versus `OUTPUT INSERTED`) is an implementation detail the fixture must
pin identically across the four. Focused suites were green before the parity probes; that
baseline is regression evidence only.

## Public surface contract

The provider implements the Feature 3 adapter interface with no extra public surface:
connection (`connect`, `close`, `getDatabaseType` -> `mssql`), execution (`execute`,
`executeMany`, `fetch`, `fetchOne`), transactions and introspection. Construction takes
Feature 4's resolved connection parameters.

## Inputs and outputs

- Native types round-trip: `INT`/`BIGINT`, `DECIMAL`/`NUMERIC`, `FLOAT`, `BIT` as a
  boolean, `NVARCHAR`/`VARCHAR`/`NTEXT`, `VARBINARY` as raw bytes, `DATETIME2`/
  `DATETIMEOFFSET`, and `UNIQUEIDENTIFIER` as a string.
- `execute` on an INSERT returns a `DatabaseResult` carrying the IDENTITY value; a UUID
  primary key (`UNIQUEIDENTIFIER`) is returned as a string.
- `affected_rows` reports the rows the statement changed, consistent with the other
  engines.
- `getColumns` returns the Feature 3 descriptor including the PK ordinal; `getTables`
  returns user tables and excludes system schemas.
- Binding preserves parameter order; a null keyed-map value compiles to `IS NULL`.

## Lifecycle and operation graph

1. Feature 4 resolves the `mssql:`/`sqlserver:` URL to host, port, database, credentials.
2. `connect` opens the connection with a bounded connect timeout.
3. A write captures the IDENTITY value; a paginated read is rewritten to `TOP`/`OFFSET ...
   FETCH NEXT` by Feature 7.
4. Transactions bracket through the native mode; `autocommit` reflects and sets it.
5. `close` releases the connection and is idempotent; catalog inspection never mutates.

## Configuration and precedence

- The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` (default 10) mapped to the
  driver's timeout, with a caller-set URL value winning.
- Connection identity comes only from Feature 4. There are no other MSSQL-specific
  environment variables.

## Failures, side effects and security

- Values are always bound; identifiers are quoted with `[brackets]` by the trusted builder
  only. A closing bracket inside an identifier is escaped (`]]`).
- The bind ceiling is 2100; Feature 7 rejects or splits a statement that would exceed it
  rather than letting SQL Server truncate.
- The connect is bounded, so an unreachable host fails within the timeout naming host,
  port, elapsed seconds and the timeout variable.
- A driver error throws and retains SQL Server's cause; it never becomes an empty read or
  a false write result.

## Wire and persistence contract

Communication is the TDS protocol through the host driver. Values round-trip as their
native types; `VARBINARY` is raw bytes, `BIT` is a boolean, `DATETIMEOFFSET` preserves the
instant. The generated id is the IDENTITY value. The `TOP`/`OFFSET ... FETCH NEXT` rewrite
and `?`-to-driver placeholder conversion change only tokens, never parameter count or
order.

## Providers and substitutability

Each language uses its host's maintained TDS driver and converts the builder's `?` to the
driver style (`@p` for tedious, native `?` elsewhere). A future runtime satisfies the same
fixture with its own driver.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MS-01 | The IDENTITY-capture keyword is not pinned (`SCOPE_IDENTITY()` vs `OUTPUT INSERTED`); a wrong choice returns another session's id or fails inside a trigger. | Pin one capture mechanism proven correct under a trigger in all four. |
| MS-02 | The `TOP`/`OFFSET ... FETCH NEXT` rewrite differs in usage counts across ports; an ORDER-BY-less `OFFSET` is invalid on SQL Server. | Prove limit-only, limit+offset and offset-without-order-by in all four. |
| MS-03 | Placeholder style diverges (`%s`/mixed/`?`/`@p`), which is per-driver, but is not pinned by a fixture. | Cover placeholder conversion, including bracket-escaping, in the fixture. |
| MS-04 | Connect-timeout is mapped per driver; the bound and URL-wins rule must be uniform. | One measured bound; gate an unreachable-host timeout. |
| MS-05 | No shared MSSQL fixture exists. | Add `mssql_contract.json`. |
| MS-06 | The 2100-parameter ceiling handling (reject vs split) is not proven identical. | Gate a >2100-parameter statement's outcome in all four. |

## Owner decisions

1. One IDENTITY-capture mechanism is canonical in all four and is proven correct under a
   trigger (a naive `@@IDENTITY` is rejected because a trigger corrupts it).
2. Feature 7 owns the `TOP`/`OFFSET ... FETCH NEXT` rewrite; an offset read always carries
   an ORDER BY.
3. The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` with a URL value winning.
4. `BIT` is a boolean and `UNIQUEIDENTIFIER` is a string across the boundary.
5. The 2100-parameter ceiling has one outcome (Feature 7) proven in all four.

## Proposed conformance fixture

Add `mssql_contract.json` (with `write_path_contract.json`) with stable ids for: bounded
connect and unreachable-host timeout; IDENTITY capture on a plain INSERT and under a
trigger; a UNIQUEIDENTIFIER PK returned as a string; limit-only (`TOP`), limit+offset
(`FETCH NEXT`) and offset-without-order-by; `VARBINARY` and `BIT` round-trip; a >2100
parameter statement; bracket-identifier escaping; `getTables`/`getColumns` PK ordinal.
Every behavioral case uses the live lab SQL Server; no mock can claim conformance.

## Integration map

- The registry selects this provider from `mssql:`/`sqlserver:`; the factory constructs it
  with Feature 4's parameters.
- Feature 5 composes CRUD; Feature 6 builds SQL; Feature 7 owns the TOP/OFFSET rewrite,
  bracket quoting and the bind ceiling.
- Migrations, ORM, pagination and any MSSQL-backed session/cache/queue consume the adapter.
- Central fixtures, four runners, CI matrix, release notes and docs update together.

## Breaking changes and migration

- The IDENTITY-capture mechanism converges; an application relying on a trigger keeps a
  correct last id.
- No application SQL changes; corrections are provider-internal.

## Implementation backlog

1. Add `mssql_contract.json` and wire four runners against the live lab SQL Server.
2. Pin one IDENTITY-capture mechanism; gate the under-a-trigger case.
3. Prove the TOP/OFFSET/FETCH rewrite (including offset-without-order-by) in all four.
4. Gate the 2100-parameter outcome and bracket-escaping.
5. Unify the connect-timeout bound and URL-wins rule; gate an unreachable host.
6. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Use the host's maintained TDS driver. Open the resolved target with a bounded connect
timeout, bind every value with the driver placeholder, capture the IDENTITY value with a
trigger-safe mechanism, and let Feature 7 rewrite limits to `TOP`/`OFFSET ... FETCH NEXT`.
Quote identifiers with `[brackets]` (escaping `]]`), return `BIT` as boolean and
`UNIQUEIDENTIFIER` as string, honor the 2100-parameter ceiling, and make lifecycle
idempotent. Prove the port against the live lab SQL Server with the shared fixtures.

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
