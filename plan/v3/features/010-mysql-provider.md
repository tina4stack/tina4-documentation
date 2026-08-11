# Feature 10: MySQL provider

## Identity and status

- Matrix identity: 10 - MySQL provider (`tina4_python/database/mysql.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, FIRST-CLASS in all four. Measured 2026-08-11. Python `database/mysql.py`
  (`ebbab30`); PHP `MySQLAdapter.php` (`6faabac5`); Ruby `lib/tina4/drivers/mysql_driver.rb` (`6d5b1de`);
  Node `packages/orm/src/adapters/mysql.ts` (`27cf0f4`).
- Dependencies: the native driver (`mysql.connector` / `ext-mysqli` / `mysql2` gem / `mysql2` npm) - OPTIONAL
  + lazy.
- Dependants: the ORM, migrations, apps using MySQL/MariaDB.
- Existing ADRs: none dedicated; issue #262 (CI provisioning).

- Catalog phase: database

## Why this feature exists

MySQL/MariaDB is the second reference SQL engine. Its adapter carries two MySQL-specific quirks the framework
must paper over: MySQL has no `RETURNING`, and its driver reports the FIRST id of a multi-row insert (not the
last). The provider hides both so app/ORM code sees the same write contract as PostgreSQL.

## Existing implementation evidence

First-class in all four: full method surface (connect/close, execute/fetch, insert/update/delete via the
shared CRUD path, transactions, table_exists/get_tables/get_columns, last_insert_id, affected_rows). Key
specifics:

- `localhost` -> `127.0.0.1` rewrite when a port is given, to force TCP over the mysqli/mysql2 Unix-socket
  trap (PHP `MySQLAdapter`, Ruby `mysql_driver.rb:43`).
- No `RETURNING`: it is stripped and last-id emulated. `SQLTranslator.FIRST_ID_ENGINES = ['mysql']` marks
  MySQL as reporting the FIRST batch id; the provider normalizes to last via first-id + rowcount - 1.
- `get_columns` uses `DESCRIBE`, PK from `Key == 'PRI'`.
- Driver OPTIONAL + lazy: `mysql.connector` inside `connect()` (Python `mysql.py:38`); `ext-mysqli` guarded
  (PHP); `mysql2` lazy `require` (Ruby `:26`) / lazy `createRequire` (Node).

## Public surface contract

`Database("mysql://...")` -> the full adapter surface; writes return `DatabaseResult` with a normalized
last-id; reads return rows. Fail-loud on the main query (the last-id probe runs on a fresh cursor and never
masks the real error).

## Inputs and outputs

- Input: a `mysql://` URL, SQL + bound params. Output: rows, `DatabaseResult` (with the normalized last-id),
  or a raised error.

## Lifecycle and operation graph

1. Lazy-import the driver; connect (rewrite localhost->127 when a port is present).
2. Translate SQL (placeholders `?`->`%s`, ilike/concat per the translator - note the concat bug, feature 7),
   bind, execute.
3. Strip `RETURNING`, capture `lastrowid`; for a multi-row insert, normalize first-id -> last-id.

## Configuration and precedence

- The `mysql://` URL (host/port/db/user/password/charset). No MySQL-specific env beyond the URL.

## Failures, side effects and security

- Fail-loud on the main query. Parameters bound. Credentials from the URL, redacted in logs.

## Wire and persistence contract

Standard MySQL protocol. Last-id is the emulated first+rowcount-1 value; the write path returns a
`DatabaseResult`. `DESCRIBE`-based column introspection is the schema read.

## Providers and substitutability

No PDO fallback (PHP uses `ext-mysqli` directly). One driver per language.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| MYSQL-RETURNING-ID | The RETURNING emulation assumes the primary-key column is literally `id` (Python `mysql.py:107`, PHP, MSSQL/Firebird share the pattern). A model whose PK is not `id` gets a wrong/empty returned row. | Read the real PK column (the adapter already introspects it via `DESCRIBE`) and emulate RETURNING against that column, not a hardcoded `id`. Fix once, apply to MySQL/MSSQL/Firebird. |
| MYSQL-DESCRIBE-UNPARAM | Python's `get_columns` builds `"DESCRIBE " + table` by string concatenation - unparameterized and unquoted (`mysql.py:218`), inconsistent with the parameterized `information_schema` queries elsewhere. The table name is framework-supplied (not user input) so it is not an injection today, but it is a footgun and a parity inconsistency. | Use a parameterized/quoted introspection query (as the other adapters do), or quote the identifier. |
| MYSQL-BATCH-ID-DUP | The first->last id normalization is re-implemented inline in each language (Python `mysql.py:100`, Ruby `mysql_driver.rb:118`) instead of calling the shared `batch_last_id` helper (which is otherwise dead - see feature 7). | De-duplicate onto the one helper (or delete the helper). |
| MYSQL-CONTRACT-DRIFT | Shared adapter-contract drift (see feature 9). | See PG-DEC-01. |

## Owner decisions

- MYSQL-DEC-01 (proposed): fix the `id`-hardcoded RETURNING emulation to use the real PK column
  (MYSQL-RETURNING-ID), across MySQL/MSSQL/Firebird. Highest value (silent wrong-row on non-`id` PKs).
- MYSQL-DEC-02 (proposed, low): parameterize/quote the `DESCRIBE` introspection (MYSQL-DESCRIBE-UNPARAM) and
  de-duplicate the batch-id math (MYSQL-BATCH-ID-DUP).

## Proposed conformance fixture

Covered by the shared write-path/batch fixtures against a real MySQL (CI-provisioned since #262). Add: a
model with a non-`id` PK round-trips its inserted row correctly (catches MYSQL-RETURNING-ID); a multi-row
insert returns the LAST id.

## Integration map

- Consumers: ORM, migrations, the Database facade, the SQL translator (feature 7). Provisioned in CI (#262).

## Breaking changes and migration

- Fixing the non-`id` PK RETURNING changes the returned row for such models (previously wrong/empty) - a
  correctness fix; document it.

## Implementation backlog

1. MYSQL-DEC-01: real-PK RETURNING emulation (MySQL/MSSQL/Firebird) with a non-`id`-PK regression.
2. MYSQL-DEC-02: parameterize DESCRIBE; de-duplicate batch-id math.

## Porting capsule

A first-class MySQL adapter needs: a lazy/optional driver; a localhost->127.0.0.1 rewrite to force TCP;
RETURNING stripped and last-id emulated AGAINST THE REAL PK COLUMN (not hardcoded `id`); first-id->last-id
normalization for multi-row inserts (one shared helper); parameterized introspection; fail-loud main query;
and coverage by the shared write-path fixture against a real MySQL.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure and security rules complete.
- [x] Wire/type contracts complete.
- [x] Four-language behaviour recorded (first-class; localhost rewrite; FIRST_ID quirk).
- [x] Owner ambiguities decided (MYSQL-DEC-01/02).
- [x] Conformance fixture (non-`id` PK) recorded.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
