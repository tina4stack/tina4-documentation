# Feature 013: ODBC provider

## Identity and status

- Matrix identity: 13 - ODBC provider
- Audit state: decision-ready
- Dependencies: Feature 3 adapter interface, Feature 4 URL parser, Feature 5 write facade,
  Feature 7 SQL translator (`MAX_BIND_PARAMS = 0`)
- Dependants: any application pointed at a database reached only through ODBC
- Existing ADRs: ADR-0044 (batch/first-row primitives, `connect` canonical name); the
  connect-timeout contract applies
- Shared fixtures: `write_path_contract.json`; an `odbc_contract.json` is required
- Catalog phase: Database providers
- Audit note: measured from four-language source; no framework code changed

## Why this feature exists

ODBC is the escape hatch. When a database has no first-class Tina4 provider, an ODBC driver
reaches it through a DSN or a connection string. The trade is real: ODBC is a
lowest-common-denominator provider and cannot know the target dialect, so it guarantees
less than a native provider.

## Boundary

This provider owns the ODBC connection (DSN or `DRIVER=...` connection string), value
binding over `?` placeholders, generic execution and whatever catalog the ODBC driver
exposes. It deliberately does NOT own dialect rewriting: because `getDatabaseType` is
`odbc` and the real engine is unknown, Feature 7 cannot apply an engine-specific
`LIMIT`/`TOP`/`ROWS` rewrite. The application owns dialect-correct SQL when it chooses ODBC.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Driver | `pyodbc` | `odbc`/`pdo_odbc` | `ruby-odbc` | `odbc` package |
| Connection | DSN or `DRIVER=...` string | DSN or connection string | DSN or connection string | DSN or connection string |
| Placeholder | `?` | `?` | `?` | `?` |
| `getDatabaseType` | `odbc` | `odbc` | `odbc` | `odbc` |
| Dialect rewrite | none (unknown engine) | none | none | none |
| Batch collapse | none (`MAX_BIND_PARAMS = 0`) | none | none | none |
| Source size | 224 lines | 415 lines | 226 lines | 443 lines |

All four report `getDatabaseType` as `odbc`, so no downstream code can select a dialect
rewrite. Each uses standard `?` placeholders and passes SQL through to the driver mostly
unchanged. The catalog (`getTables`/`getColumns`) reflects whatever the ODBC driver's
metadata calls return, which varies by target. Focused suites were green before the parity
probes; that baseline is regression evidence only.

## Public surface contract

The provider implements the Feature 3 adapter interface: connection (`connect`, `close`,
`getDatabaseType` -> `odbc`), execution (`execute`, `executeMany`, `fetch`, `fetchOne`),
transactions and introspection. The public surface matches the other providers; the
GUARANTEES behind it are weaker and are stated below.

## Inputs and outputs

- Values bind over `?` and round-trip as whatever the ODBC driver maps them to; the
  provider does not reinterpret a driver-returned type.
- `execute` on an INSERT returns a `DatabaseResult`; the generated id is only as reliable
  as the underlying driver's last-id call, which some ODBC targets do not support.
- `getColumns`/`getTables` return the driver's catalog metadata, best-effort, and may omit
  the PK ordinal when the target does not report it.
- Binding preserves parameter order; a null keyed-map value compiles to `IS NULL`.

## Lifecycle and operation graph

1. Feature 4 resolves the `odbc:` URL (or the application supplies a DSN / connection
   string).
2. `connect` opens the ODBC connection with a bounded connect timeout.
3. Execution passes SQL to the driver; no engine-specific rewrite is applied.
4. Transactions bracket through the driver's mode when it supports them; `autocommit`
   reflects and sets it.
5. `close` releases the connection and is idempotent.

## Configuration and precedence

- The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` (default 10) mapped to the
  ODBC connect timeout, with a caller-set value winning.
- Connection identity comes from Feature 4 or an explicit DSN/connection string. There are
  no other ODBC-specific environment variables.

## Failures, side effects and security

- Values are always bound (`?`); the application owns identifier quoting because the target
  dialect is unknown.
- The connect is bounded, so an unreachable target fails within the timeout naming the DSN,
  elapsed seconds and the timeout variable.
- A driver error throws and retains the ODBC SQLSTATE; it never becomes an empty read or a
  false write result.
- The provider states its reduced guarantees so an application does not assume dialect
  rewriting, last-id support or a PK ordinal it did not verify.

## Wire and persistence contract

Communication is the ODBC call-level interface through the host driver. Type mapping,
last-id support, transaction support and catalog completeness are all the target driver's,
not Tina4's. The provider guarantees only the Feature 3 surface, `?` binding, parameter
order and a bounded connect.

## Providers and substitutability

ODBC IS the substitutability layer for engines without a native provider. Its guarantees
are the intersection of every ODBC target, which is why it does less. A native provider is
always preferred when one exists.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| OD-01 | `getDatabaseType` is `odbc`, so Feature 7 cannot rewrite `LIMIT`/pagination for the real engine; a portable pagination query can fail on the target. | Document that ODBC does not rewrite dialect; require the application to supply dialect-correct SQL, and prove a bounded set (e.g. an ODBC-to-Postgres DSN) in the fixture. |
| OD-02 | Generated-id reliability depends on the target; some ODBC drivers have no last-id. | State last-id as best-effort; the fixture proves it against a known target and asserts a clear failure otherwise. |
| OD-03 | Catalog completeness (PK ordinal, types) varies by driver. | State catalog as best-effort; the fixture proves the known-target case. |
| OD-04 | Connect-timeout mapping to the ODBC layer is not proven uniform. | One measured bound; gate an unreachable-DSN timeout. |
| OD-05 | No shared ODBC fixture exists. | Add `odbc_contract.json` against a known ODBC target. |

## Owner decisions

1. ODBC is a reduced-guarantee provider: it binds values, preserves order, bounds the
   connect and exposes the Feature 3 surface, but does NOT rewrite dialect. This is stated,
   not hidden.
2. The application supplies dialect-correct SQL and identifier quoting when it chooses ODBC.
3. Last-id and catalog completeness are best-effort and documented as target-dependent.
4. The fixture proves ODBC against one known target (an ODBC-to-Postgres or ODBC-to-MSSQL
   DSN on the lab), because "every ODBC target" cannot be enumerated.

## Proposed conformance fixture

Add `odbc_contract.json` (with `write_path_contract.json`) against a known lab ODBC target
with stable ids for: a bounded connect and an unreachable-DSN timeout; a bound-parameter
INSERT and SELECT preserving order; last-id where the target supports it and a clear
failure where it does not; `getTables`/`getColumns` best-effort metadata; and a confirmation
that no dialect rewrite is applied. Every behavioral case uses a live lab ODBC target; no
mock can claim conformance.

## Integration map

- The registry selects this provider from `odbc:` or an explicit DSN/connection string.
- Feature 5 composes CRUD; Feature 6 builds SQL; Feature 7 applies NO engine rewrite here.
- Applications choose ODBC only when no native provider exists; native is always preferred.
- Central fixtures, four runners, CI matrix, release notes and docs update together.

## Breaking changes and migration

- None to application SQL. The audit makes ODBC's reduced guarantees explicit rather than
  implied, so an application relying on dialect rewriting learns it must supply correct SQL.

## Implementation backlog

1. Add `odbc_contract.json` against a known lab ODBC target and wire four runners.
2. Prove bound-parameter round-trip, best-effort last-id and catalog, and no-rewrite.
3. Unify the connect-timeout bound; gate an unreachable-DSN timeout.
4. Document the reduced-guarantee contract in the database docs.
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Use the host's ODBC bridge over `?` placeholders. Open a DSN or `DRIVER=...` connection
with a bounded connect timeout, bind every value, preserve parameter order, and pass SQL
through WITHOUT an engine-specific rewrite (the target dialect is unknown). Expose the
Feature 3 surface, report `getDatabaseType` as `odbc`, treat last-id and catalog as
best-effort, and make lifecycle idempotent. Prove the port against one known ODBC target.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities recorded (4 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
