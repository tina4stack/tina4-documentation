# Feature 010: MySQL provider

## Identity and status

- Matrix identity: 10 — MySQL provider
- Audit state: decision-ready
- Dependencies: Feature 3 adapter interface, Feature 4 URL parser, Feature 5 write facade
  (decision A: affected_rows = matched rows), Feature 7 SQL translator (batch, FIRST_ID)
- Dependants: migrations, ORM, pagination, MySQL-backed session/cache/queue
- Existing ADRs: ADR-0044 (batch/first-row primitives, `connect` canonical name); the
  connect-timeout contract applies
- Shared fixtures: `write_path_contract.json`, `batch_write_contract.json`; a
  `mysql_contract.json` is required
- Catalog phase: Database providers
- Audit note: measured from four-language source; no framework code changed

## Why this feature exists

MySQL (and MariaDB) give a Tina4 application a widely deployed SQL database whose behavior
stays interchangeable with the other providers, so the same application code and tests run
against it unchanged.

## Boundary

This provider owns MySQL connection construction, native binding and round-trip,
generated-id capture, catalog queries and lifecycle. Feature 3 owns the adapter
capabilities, Feature 4 parses the URL, Feature 5 composes CRUD (and fixed matched-rows
semantics), and Feature 7 supplies placeholder style, the `AUTO_INCREMENT` DDL rewrite,
the bind-parameter ceiling and the first-id batch normalization. Identifier quoting
(backticks) stays on the adapter.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Driver | stdlib/connector | `mysqli` (`MySQLAdapter`) | `mysql2` (`MysqlDriver`) | `mysql2` |
| Placeholder to driver | `?` -> `%s` | `?` native | `?` native | `?` native |
| RETURNING | none (MySQL has none) | none | none | none |
| Generated id | driver `lastrowid` | `mysqli` insert id | `last_insert_id` | result `insertId` |
| Multi-row batch last id | FIRST id -> normalized via Feature 7 `batch_last_id` | same | same | same |
| Connect timeout | driver `connect_timeout` | driver option | mysql2 `connect_timeout` | mysql2 option |
| Identifier quote | backtick | backtick | backtick | backtick |
| Lifecycle name | `connect`/`close` | `open`/`close` (see MY-06) | `connect`/`close` | `connect`/`close` |

MySQL has no `RETURNING`, so the generated id comes from the driver's native last-insert
API, not a SELECT. MySQL's `LAST_INSERT_ID` reports the FIRST id of a multi-row INSERT, so
Feature 7's `FIRST_ID_ENGINES` lists mysql and `batch_last_id` restores the last-row id as
`first + rows - 1` when a batch is collapsed. Focused suites were green before the parity
probes; that baseline is regression evidence only.

## Public surface contract

The provider implements the Feature 3 adapter interface with no extra public surface:
connection (`connect`, `close`, `getDatabaseType` -> `mysql`), execution (`execute`,
`executeMany`, `fetch`, `fetchOne`), transactions and introspection. Construction takes
Feature 4's resolved connection parameters.

## Inputs and outputs

- Native types round-trip: integer, decimal/numeric, double, `DATETIME`/`TIMESTAMP`,
  `VARCHAR`/`TEXT`, `BLOB` as raw bytes, and `JSON` as a native structure. A tinyint(1)
  reads back as an integer; MySQL has no separate boolean type.
- `execute` on an INSERT returns a `DatabaseResult` carrying the driver's generated id;
  after a collapsed multi-row batch the id is normalized to the LAST row.
- `affected_rows` reports MATCHED rows (MySQL `CLIENT_FOUND_ROWS`), so a same-value UPDATE
  reports 1, matching Feature 5 decision A and the other engines.
- `getColumns` returns the Feature 3 descriptor including the PK ordinal; `getTables`
  returns user tables from the connected schema.
- Binding preserves parameter order; a null keyed-map value compiles to `IS NULL`.

## Lifecycle and operation graph

1. Feature 4 resolves the `mysql:`/`mariadb:` URL to host, port, database, credentials.
2. `connect` opens the connection with a bounded connect timeout and requests
   `CLIENT_FOUND_ROWS` so affected-row counts are matched, not changed.
3. A write captures the driver's generated id; a collapsed batch normalizes the last id
   through Feature 7.
4. Transactions bracket through the native mode; `autocommit` reflects and sets it.
5. `close` releases the connection and is idempotent; catalog inspection never mutates.

## Configuration and precedence

- The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` (default 10) mapped to the
  driver's `connect_timeout`, with a caller-set URL value winning.
- `CLIENT_FOUND_ROWS` is enabled on every connection so affected rows are matched rows;
  this is not configurable off (it would diverge affected-row semantics from the other
  engines).
- Connection identity comes only from Feature 4. There are no other MySQL-specific
  environment variables.

## Failures, side effects and security

- Values are always bound; identifiers are quoted with backticks by the trusted builder
  only.
- The connect is bounded, so an unreachable host fails within the timeout naming host,
  port, elapsed seconds and the timeout variable.
- A driver error throws and retains MySQL's cause; it never becomes an empty read or a
  false write result.
- A partial connection is closed on setup failure.

## Wire and persistence contract

Communication is the MySQL client protocol through the host driver. Values round-trip as
their native types; `BLOB` is raw bytes, `JSON` round-trips as a native structure,
`DATETIME` preserves the value. The generated id is the driver's last-insert value,
normalized to the last row after a collapsed batch. Backtick identifier quoting and
`?`-to-driver placeholder conversion change only the token, never parameter count or order.

## Providers and substitutability

MariaDB is served by the same provider (Feature 7 aliases `mariadb` to `mysql`). Each
language uses its host's maintained MySQL client and converts the builder's `?` to its
driver style. A future runtime satisfies the same fixture with its own client.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MY-01 | The provider must apply Feature 7's `batch_last_id` after a collapsed multi-row INSERT, because MySQL's `LAST_INSERT_ID` reports the first id; a provider that returns the raw first id after a batch is wrong. | Prove last-row id after a collapsed batch in all four. |
| MY-02 | `affected_rows` must be matched rows via `CLIENT_FOUND_ROWS` (Feature 5 decision A); a connection without it reports changed rows and a same-value UPDATE returns 0. | Enable `CLIENT_FOUND_ROWS` on every connection in all four and gate the same-value-UPDATE-returns-1 case. |
| MY-03 | Placeholder style diverges (Python `%s`, others `?`), which is per-driver and correct, but is not pinned by a fixture. | Cover placeholder conversion in the fixture. |
| MY-04 | Connect-timeout is mapped per driver; the bound and URL-wins rule must be uniform. | One measured bound; gate an unreachable-host timeout. |
| MY-05 | No shared MySQL fixture exists. | Add `mysql_contract.json` with MySQL-specific cases. |
| MY-06 | PHP's adapter exposes `open()` as its lifecycle entry; ADR-0044 makes `connect` the canonical name. | Confirm the public lifecycle is `connect`/`close` in all four (rename or wrap PHP `open`). |

## Owner decisions

1. The generated id is the driver's native last-insert value; after a collapsed multi-row
   INSERT it is normalized to the last row via Feature 7's `batch_last_id`.
2. `affected_rows` is matched rows via `CLIENT_FOUND_ROWS`, always enabled, so a same-value
   UPDATE reports 1 (Feature 5 decision A).
3. The connect is bounded by `TINA4_DATABASE_CONNECT_TIMEOUT` with a URL value winning.
4. The public lifecycle is `connect`/`close` in every language (ADR-0044); an internal
   `open` is wrapped, not exposed.
5. Native MySQL types (BLOB bytes, JSON, DATETIME) round-trip as native values; a
   tinyint(1) reads back as an integer, not a disguised boolean.

## Proposed conformance fixture

Add `mysql_contract.json` (with `write_path_contract.json` and `batch_write_contract.json`)
with stable ids for: bounded connect and unreachable-host timeout; AUTO_INCREMENT id
capture; last-row id after a collapsed multi-row batch; `affected_rows` matched-rows on a
same-value UPDATE; BLOB and JSON round-trip; tinyint(1) as integer; `getTables`/`getColumns`
PK ordinal; and MariaDB served by the same provider. Every behavioral case uses the live
lab MySQL; no mock can claim conformance.

## Integration map

- The registry selects this provider from `mysql:`/`mariadb:`; the factory constructs it
  with Feature 4's parameters.
- Feature 5 composes CRUD and owns matched-rows semantics; Feature 6 builds SQL; Feature 7
  supplies placeholder style, `AUTO_INCREMENT` DDL, the bind ceiling and `batch_last_id`.
- Migrations, ORM, pagination and any MySQL-backed session/cache/queue consume the adapter;
  `get_next_id` uses the `tina4_sequences` table on MySQL.
- Central fixtures, four runners, CI matrix, release notes and docs update together.

## Breaking changes and migration

- `affected_rows` becomes matched rows everywhere; an application relying on the old
  changed-rows count for a same-value UPDATE sees 1 instead of 0.
- PHP's public lifecycle standardizes on `connect`/`close`.
- No application SQL changes otherwise; corrections are provider-internal.

## Implementation backlog

1. Add `mysql_contract.json` and wire four runners against the live lab MySQL.
2. Enable `CLIENT_FOUND_ROWS` in all four; gate the same-value-UPDATE case.
3. Prove last-row id after a collapsed batch (Feature 7 `batch_last_id`) in all four.
4. Standardize the public lifecycle on `connect`/`close` (PHP `open`).
5. Unify the connect-timeout bound and URL-wins rule; gate an unreachable host.
6. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Use the host's maintained MySQL client. Open the resolved target with a bounded connect
timeout and `CLIENT_FOUND_ROWS`, bind every value with the driver placeholder, capture the
native generated id (normalizing a collapsed batch to the last row), and return native
values (BLOB bytes, JSON, DATETIME). Expose the Feature 3 primitives as `connect`/`close`
and the rest, quote identifiers with backticks, preserve the PK ordinal, and make lifecycle
idempotent. Prove the port against the live lab MySQL with the shared fixtures.

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
