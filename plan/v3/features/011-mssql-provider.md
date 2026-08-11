# Feature 11: MSSQL provider

## Identity and status

- Matrix identity: 11 - MSSQL provider (`tina4_python/database/mssql.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, FIRST-CLASS in all four, with real interpolation/typing caveats.
  Measured 2026-08-11. Python `database/mssql.py` (`ebbab30`); PHP `MSSQLAdapter.php` (`6faabac5`); Ruby
  `lib/tina4/drivers/mssql_driver.rb` (`6d5b1de`); Node `packages/orm/src/adapters/mssql.ts` (`27cf0f4`).
- Dependencies: the driver - `pymssql` (Python); `ext-sqlsrv` with a PDO `dblib`/FreeTDS fallback (PHP);
  `tiny_tds` (Ruby); `tedious` (Node) - OPTIONAL + lazy.
- Dependants: the ORM, migrations, apps using SQL Server.
- Existing ADRs: none dedicated; issue #262 (CI provisioning), @@TRANCOUNT-balance fix.

- Catalog phase: database

## Why this feature exists

SQL Server has no `RETURNING`, a different pagination syntax, and a batch model where the INSERT and the id
probe run in separate scopes. The provider papers over all three so app/ORM code sees the same write contract
as PostgreSQL.

## Existing implementation evidence

First-class in all four: full method surface. Specifics:

- Last-id via `SCOPE_IDENTITY()` (the INSERT + `SELECT SCOPE_IDENTITY()` batched in one statement so the
  scope is preserved - Ruby `mssql_driver.rb:77`, PHP, Python).
- Pagination: OFFSET/FETCH with an injected `ORDER BY (SELECT NULL)` when none is present (Python, Ruby, Node)
  - the translator ALSO offers `TOP n`, which PHP uses. So the MSSQL pagination strategy DIVERGES across the
  languages (see feature 7).
- Transactions emit no raw `BEGIN` (Python: a @@TRANCOUNT-balance fix; Node: tedious native
  begin/commit/rollback).
- Driver OPTIONAL + lazy: `pymssql` inside `connect()` (Python `mssql.py:39`); PHP dual (`ext-sqlsrv` primary,
  PDO `dblib`/FreeTDS fallback); Ruby `tiny_tds` lazy; Node `tedious` lazy.

## Public surface contract

`Database("mssql://...")` -> the full surface; writes return `DatabaseResult` with the SCOPE_IDENTITY last-id.
Fail-loud.

## Inputs and outputs

- Input: an `mssql://`/`sqlserver://` URL, SQL + params. Output: rows, `DatabaseResult`, or a raised error.

## Lifecycle and operation graph

1. Lazy-import the driver; connect (login_timeout + a watchdog where the driver's own timeout is insufficient
   - Python `call_with_deadline`).
2. Translate SQL (booleans->1/0, pagination), bind params, execute.
3. Strip `RETURNING`; capture `SCOPE_IDENTITY()` in the same batch as the INSERT.

## Configuration and precedence

- The `mssql://` URL. Python adds a connect watchdog (pymssql `login_timeout` measured insufficient).

## Failures, side effects and security

- Fail-loud. Credentials from the URL, redacted. Parameters: bound in Python/PHP (pymssql/PDO); HAND-ROLLED
  string interpolation in Ruby and typed-inference in Node (see the register) - a correctness/safety caveat.

## Wire and persistence contract

TDS via the driver. Last-id is `SCOPE_IDENTITY()`; the write path returns a `DatabaseResult`. Pagination is
OFFSET/FETCH (or TOP in PHP).

## Providers and substitutability

PHP has two legs (`ext-sqlsrv` + PDO dblib); the `ext-sqlsrv` leg is UNVERIFIED on the lab (only pdo_dblib
runs). The others use one driver.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| MSSQL-INTERP-RUBY | Ruby uses HAND-ROLLED string interpolation, not native binds (`mssql_driver.rb:209`): nil->NULL, bool->1/0, Time->quoted ISO8601, String->quote-doubled (correct T-SQL), but any OTHER param type falls through to `param.to_s` UNQUOTED (`:229`) - a bareword in the SQL. A non-string/non-recognized param (e.g. a BigDecimal, a symbol) emits invalid or unintended SQL. | Use tiny_tds parameterized queries, or extend the interpolator to quote/handle every type (and reject unknowns) rather than emitting a bareword. |
| MSSQL-BUFFER-NODE | Node infers the TDS param type from the JS type (`mssql.ts:178`): NVarChar default, else Int/Float/Bit/DateTime - there is NO Buffer/VarBinary path, so a Buffer param binds as NVarChar (corrupting binary writes). Node's batch path also returns NO `lastId` (`:242`), and `affectedRows` is hardcoded `1` on a single insert to dodge tedious double-counting. | Add a Buffer->VarBinary binding; return the last-id on the batch path; derive `affectedRows` from the real rowcount rather than hardcoding. |
| MSSQL-RETURNING-ID | The SCOPE_IDENTITY RETURNING-emulation assumes the PK column is `id` (Python `mssql.py:126`, PHP) - shared with MySQL/Firebird (see feature 10 MYSQL-RETURNING-ID). | Emulate against the real PK column. |
| MSSQL-SQLSRV-UNVERIFIED | PHP's `ext-sqlsrv` leg is not exercised on the lab (only the pdo_dblib/FreeTDS leg runs) - half the PHP MSSQL surface is unproven. | Provision an `ext-sqlsrv` test leg (or document the leg as unverified and pdo_dblib as the supported path). |
| MSSQL-PAGINATION-DIVERGE | The MSSQL pagination strategy diverges: PHP uses `TOP n` (translator), the others OFFSET/FETCH (see feature 7 SQLTRANS-DEAD-DUP). | Pick one strategy across the four. |

## Owner decisions

- MSSQL-DEC-01 (proposed): fix the parameter handling - Ruby's bareword-on-unknown-type
  (MSSQL-INTERP-RUBY) and Node's Buffer->NVarChar (MSSQL-BUFFER-NODE) - so binary and unusual-typed params
  are safe. Highest value.
- MSSQL-DEC-02 (proposed): real-PK RETURNING (MSSQL-RETURNING-ID, shared with MySQL/Firebird); one pagination
  strategy (MSSQL-PAGINATION-DIVERGE); provision or document the `ext-sqlsrv` leg (MSSQL-SQLSRV-UNVERIFIED).

## Proposed conformance fixture

Shared write-path fixture against a real MSSQL (CI-provisioned since #262). Add: a Buffer/binary param
round-trips intact (catches MSSQL-BUFFER-NODE); a non-string/unusual-typed param is bound safely (catches
MSSQL-INTERP-RUBY); a non-`id` PK returns its inserted row; a paginated query returns the right window.

## Integration map

- Consumers: ORM, migrations, the Database facade, the SQL translator (feature 7). Provisioned in CI (#262).

## Breaking changes and migration

- Fixing Buffer binding and unknown-type interpolation changes what such params write (previously
  corrupt/invalid) - a correctness fix. Choosing one pagination strategy may change generated MSSQL - document
  it.

## Implementation backlog

1. MSSQL-DEC-01: safe parameter handling (Ruby unknown-type, Node Buffer->VarBinary), with binary/typed
   regressions.
2. MSSQL-DEC-02: real-PK RETURNING; one pagination strategy; ext-sqlsrv leg.

## Porting capsule

A first-class MSSQL adapter needs: a lazy/optional driver with a connect watchdog (the driver's login_timeout
can be insufficient); `SCOPE_IDENTITY()` last-id batched with the INSERT; RETURNING emulated against the real
PK; one pagination strategy (OFFSET/FETCH with an injected ORDER BY, or TOP - not both); and SAFE parameter
handling for EVERY type including Buffer/binary (bind natively, or a complete quoter that never emits a
bareword). Cover it with the shared write-path fixture against a real SQL Server.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure and security rules complete.
- [x] Wire/type contracts complete.
- [x] Four-language behaviour recorded (SCOPE_IDENTITY; pagination divergence; interpolation/typing caveats).
- [x] Owner ambiguities decided (MSSQL-DEC-01/02).
- [x] Conformance fixture (binary, typed, non-`id` PK, pagination) recorded.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
