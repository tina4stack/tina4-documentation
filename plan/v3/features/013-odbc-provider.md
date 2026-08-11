# Feature 13: ODBC provider

## Identity and status

- Matrix identity: 13 - ODBC provider (`tina4_python/database/odbc.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, PARTIAL and essentially UNVERIFIED in all four (the weakest SQL
  provider). Measured 2026-08-11. Python `database/odbc.py` (`ebbab30`); PHP `ODBCAdapter.php` (`6faabac5`);
  Ruby `lib/tina4/drivers/odbc_driver.rb` (`6d5b1de`); Node `packages/orm/src/adapters/odbc.ts` (`27cf0f4`).
- Dependencies: the driver - `pyodbc` (Python); PDO `pdo_odbc` (PHP); `ruby-odbc` (Ruby); `odbc` (Node) -
  OPTIONAL + lazy, plus a system ODBC manager (unixODBC). Declared NOWHERE in Node/Ruby manifests.
- Dependants: apps connecting to an ODBC data source (the generic escape hatch).
- Existing ADRs: none.

- Catalog phase: database

## Why this feature exists

ODBC is the generic fallback - "connect to anything with an ODBC driver." That generality is also its
weakness: there is no single dialect, no reliable metadata, and (critically) no live ODBC service in CI or
the lab, so it is the one SQL provider whose query/CRUD paths are never exercised against a real source in any
language. This packet records that it ships essentially unproven.

## Existing implementation evidence

Partial in all four: connect/close, execute/fetch, transactions, tables/columns, and a pass-through
`_translate_sql` (no dialect translation). What is MISSING or broken is the story:

- NO functional tests against a real ODBC source in ANY language (Python `conftest.py:57` "there is no ODBC
  service"; PHP `ODBCAdapter.php:87` "NOT verified on the lab box"; Ruby no live spec; Node no
  `TINA4_TEST_ODBC*`). Only structural/contract-shape tests exist.
- PK introspection STUBBED to `primary_key: false` in ALL FOUR (Python `odbc.py:214`, PHP `:314`, Ruby
  `:209`, Node `:359`) - the same defect PG/MySQL/Firebird FIXED. Because feature 4's filterless-write guard
  reads `primary_key`, a PK-keyed `update(table, data)` with no explicit filter cannot introspect the PK on
  ODBC.
- `affected_rows` is absent (PHP/Ruby/Node) or unreliable; `last_insert_id` is nil/`PDO::lastInsertId`
  (unreliable for many ODBC targets).
- Driver OPTIONAL + lazy in all four, but the DEPENDENCY METADATA is worst here: `odbc` is declared in no
  Node/Ruby manifest at all (discoverable only via the throw message).

## Public surface contract

`Database("odbc://...")` -> execute/fetch/transactions/introspection, pass-through SQL. In practice the
contract is weakly held (swallowed errors, stubbed PK, no real last-id) - see the register.

## Inputs and outputs

- Input: an ODBC connection string, SQL + params. Output: rows (or a swallowed empty result on error in
  PHP/Ruby), a stubbed schema, an unreliable last-id.

## Lifecycle and operation graph

1. Lazy-import the driver; connect (from the connection string).
2. Pass SQL through unchanged (no dialect translation); bind, execute.
3. Return rows; introspection returns columns with `primary_key: false`.

## Configuration and precedence

- The ODBC connection string / DSN. (Python IGNORES the username/password params - see the register.)

## Failures, side effects and security

- FAIL-LOUD DIVERGENCE: `execute`/`executeMany` raise, but `fetch`/`fetchOne`/`query` SWALLOW errors to an
  empty result in PHP (`:182`/`:204`/`:132`) and elsewhere - contrary to the framework's fail-loud fetch
  contract (PostgreSQL raises). A real query error is hidden as "no rows".
- Untested: the CRUD path is never run against a real ODBC source, so these are latent, not observed.

## Wire and persistence contract

Whatever the ODBC driver speaks (pass-through). No reliable last-id or PK contract.

## Providers and substitutability

One ODBC layer per language; the underlying DBMS is opaque. No fallback.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| ODBC-UNTESTED | UNIVERSAL: the ODBC query/CRUD path is NEVER exercised against a real ODBC source in any language (no live service in CI or lab). Only structural/contract-shape tests exist. So every finding below is latent, and the provider ships unproven. | Provision a real ODBC source in CI (e.g. unixODBC + a SQLite or PostgreSQL ODBC driver) and run the shared write-path fixture through it. This alone would surface the bugs below. If ODBC is not going to be provisioned, mark it EXPERIMENTAL/unsupported rather than first-looking. |
| ODBC-PK-STUB | UNIVERSAL: `get_columns` hardcodes `primary_key: false` in all four - the same defect the SQL adapters fixed. Feature 4's filterless-write guard reads `primary_key`, so a PK-keyed `update(table, data)` throws (or writes wrong) on ODBC. | Query the ODBC catalog for PKs (`SQLPrimaryKeys`), or document that ODBC requires an explicit filter for updates. |
| ODBC-PY-QUIRKS | Python-specific: `execute()` runs `SELECT @@IDENTITY AS id` after EVERY statement (`odbc.py:103`) - a SQL-Server-ism baked into a GENERIC adapter that errors (swallowed) on any non-SQL-Server source and runs pointlessly on DDL/UPDATE/DELETE; and `connect()` IGNORES the `username`/`password` params (`:48`), reading only the raw connection string. | Remove the `@@IDENTITY` assumption (make last-id opt-in / driver-aware); honour username/password. |
| ODBC-NODE-QUIRKS | Node-specific: `updateAsync` has NO string-WHERE branch (`odbc.ts:257`) so a string filter is walked with `Object.keys` -> `["0","1"...]` (the exact bug the other adapters guard against); `executeManyAsync` has NO transaction owns-guard (`:192`), so nested in a caller's transaction its `commit` commits the OUTER transaction early. | Add the string-WHERE branch and the owns-guard to match pg/mysql/mssql. |
| ODBC-FAILLOUD | PHP/Ruby: `fetch`/`fetchOne`/`query` SWALLOW errors to empty while `execute` raises - a fail-loud contract divergence that hides real errors as "no rows". | Make fetch fail-loud like the SQL adapters. |
| ODBC-METADATA | Node/Ruby declare the driver in NO manifest (discoverable only via the throw message); missing `affected_rows` (PHP/Ruby/Node). | Declare the driver as an optional dependency; return a real affected count or document its absence. |

## Owner decisions

- ODBC-DEC-01 (proposed): provision a real ODBC source in CI and run the shared write-path fixture through it
  (ODBC-UNTESTED) - this is the single highest-value action; it converts every latent finding below into a
  caught bug. If ODBC will not be provisioned, mark it experimental.
- ODBC-DEC-02 (proposed): fix the PK stub (ODBC-PK-STUB), the Python `@@IDENTITY`/ignored-credentials
  (ODBC-PY-QUIRKS), the Node string-WHERE/owns-guard (ODBC-NODE-QUIRKS), and the fail-loud fetch
  (ODBC-FAILLOUD) - all surfaced by the fixture once ODBC-DEC-01 lands.

## Proposed conformance fixture

The shared write-path fixture run against a REAL ODBC source (unixODBC + a driver for SQLite/PostgreSQL):
insert/update/delete/fetch round-trip; a PK-keyed `update(table, data)` with no explicit filter works
(catches ODBC-PK-STUB); a failing query RAISES (catches ODBC-FAILLOUD); a string-WHERE update works (catches
ODBC-NODE-QUIRKS); a nested transaction is not committed early (owns-guard). No mocks - a real ODBC source.

## Integration map

- Consumers: the ORM/Database facade for apps on an ODBC data source. Related: feature 4 (the filterless-write
  guard that the PK stub breaks), feature 7 (pass-through - no translation).

## Breaking changes and migration

- Fixing the PK stub and fail-loud fetch changes behaviour (updates that silently failed now work; hidden
  errors now raise) - correctness fixes; document them.

## Implementation backlog

1. ODBC-DEC-01: provision a real ODBC source in CI + run the shared fixture.
2. ODBC-DEC-02: PK catalog query; remove the `@@IDENTITY`/credential bugs; add the Node string-WHERE + owns-
   guard; fail-loud fetch; declare the driver.

## Porting capsule

An ODBC adapter needs: a lazy/optional driver (DECLARED in the manifest); pass-through SQL (no dialect); a
REAL PK query (`SQLPrimaryKeys`, not a `false` stub - feature 4's write guard depends on it); fail-loud fetch
matching the SQL adapters; a string-WHERE branch and a transaction owns-guard on the batch path; honoured
credentials; no engine-specific assumption baked in (no `@@IDENTITY`); and - the thing all four lack - a REAL
ODBC source in CI running the shared write-path fixture. Do not ship an ODBC adapter that has never connected
to an ODBC source.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure (fail-loud divergence) and security rules complete.
- [x] Wire/type contracts complete (pass-through; stubbed PK/last-id).
- [x] Four-language behaviour recorded (universal untested + PK-stub; per-lang quirks).
- [x] Owner ambiguities decided (ODBC-DEC-01/02).
- [x] Conformance fixture (real ODBC source) recorded.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
