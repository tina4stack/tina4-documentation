# Feature 9: PostgreSQL provider

## Identity and status

- Matrix identity: 9 - PostgreSQL provider (`tina4_python/database/postgres.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, FIRST-CLASS in all four (the reference write path). Measured 2026-08-11.
  Python `database/postgres.py` (`ebbab30`); PHP `PostgresAdapter.php` + `PdoPostgresAdapter` (`6faabac5`);
  Ruby `lib/tina4/drivers/postgres_driver.rb` (`6d5b1de`); Node `packages/orm/src/adapters/postgres.ts`
  (`27cf0f4`).
- Dependencies: the native driver (`psycopg2` / `ext-pgsql` + PDO `pdo_pgsql` fallback / `pg` gem / `pg` npm)
  - an OPTIONAL, lazy dependency (the framework installs and boots without it).
- Dependants: the ORM, migrations, the Database facade, apps using PostgreSQL.
- Existing ADRs: none dedicated; issues #38 (aborted-txn heal), #256 (UUID/string PK), #40 (percent guard).

- Catalog phase: database

## Why this feature exists

PostgreSQL is Tina4's production-grade reference engine. It is the adapter that most exercises the write
contract - native `RETURNING`, real last-insert-id, transactions, blob decoding, PK introspection - and the
one the write-path fixtures use as the oracle. Its behaviour defines what "first-class" means for the other
five providers.

## Existing implementation evidence

First-class in all four with a full method surface: connect/close, execute/fetch/fetch_one, execute_many
(atomic), insert/update/delete, begin/commit/rollback, table_exists/get_tables/get_columns, last_insert_id.
Distinctive hardening (present across the languages, richest in Python):

- Native `RETURNING *` for insert; PK introspection via a real LEFT JOIN; blob (bytea) already bytes/Buffer.
- Last-insert-id from `RETURNING`, else a `lastval()` probe wrapped in a SAVEPOINT so an aborted transaction
  survives (Python `postgres.py:340`, Ruby `postgres_driver.rb:158`, issue #38).
- Type coercion: Python decodes memoryview blobs; Node registers int8/numeric parsers (>2^53 precision caveat
  documented); Ruby sets `PG::BasicTypeMapForResults` + text decoders for uuid/json to suppress warnings.
- Percent-substitution guard (Python `_safe_execute`, issue #40); double-LIMIT guard; idle-in-transaction
  close. UUID/string PK handled (issue #256).
- Driver is OPTIONAL + lazy: Python `psycopg2` imported inside `connect()` (`postgres.py:255`); PHP native
  `ext-pgsql` with a silent PDO `pdo_pgsql` fallback; Ruby `pg` lazy `require` with `rescue LoadError`; Node
  `pg` via lazy `createRequire`. All raise an actionable error when absent.

## Public surface contract

`Database("postgresql://...")` (or the ORM) -> the full adapter surface. Writes return the canonical
`DatabaseResult` with `last_id`, reads return rows with native types. Fail-loud: a failed fetch/execute
raises (the reference the other adapters are measured against).

## Inputs and outputs

- Input: a `postgresql://` URL (+ optional SSL/schema), SQL + bound params. Output: rows (native-typed),
  `DatabaseResult` with `last_id`/affected, or a raised error.

## Lifecycle and operation graph

1. Lazy-import the driver; connect (URL-parsed creds, optional SSL).
2. Translate the canonical SQL (mostly a no-op for PG - it is close to the canonical), bind params (`$1`/`%s`
   per language), execute.
3. Insert returns via `RETURNING *`; else probe `lastval()` under a SAVEPOINT. Transactions wrap
   execute_many atomically.

## Configuration and precedence

- The `postgresql://` URL (host/port/db/user/password/sslmode/schema). No PG-specific env beyond the URL.

## Failures, side effects and security

- Fail-loud (the reference): a failed execute/fetch raises `DatabaseException`. Aborted-transaction healing
  (savepoint) prevents a poisoned connection. Credentials come from the URL and are redacted in
  logs/errors (feature 4). Parameters are bound (no injection). Idle-in-transaction connections are closed.

## Wire and persistence contract

Standard PostgreSQL wire via the driver. `RETURNING *` is the last-id contract; the write path returns a
`DatabaseResult` (feature 5). Type coercion (int8/numeric/uuid/json/bytea) is the read contract.

## Providers and substitutability

PHP has a silent PDO fallback (`PdoPostgresAdapter`) when `ext-pgsql` is absent; the others use one driver.
Otherwise identical behaviour.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| PG-CONTRACT-DRIFT | Shared with all providers: the declared adapter interface/contract does not match what the driver implements or what the contract test asserts (Python 12/14 excludes insert/update/delete by design; PHP 18-method interface vs a 14-method test floor; Ruby 14-method CONTRACT with 5 methods no driver implements; Node's sync interface is satisfied by throwing stubs + undeclared `*Async` twins). The contract test proves method PRESENCE, not behaviour. | Reconcile the declared interface with the real method set per language, and make the contract test boot a real adapter and assert behaviour (it already does for PG via the write-path fixtures - generalise). See the ODBC/Mongo packets where this drift hides real gaps. |
| PG-PRECISION | Node coerces int8/numeric to JS Number (`postgres.ts:51`), losing precision above 2^53 (documented). | Document; offer a BigInt/string option for large numerics if needed. Low priority (documented). |

PostgreSQL itself has no correctness defect found - it is the healthy reference. The register records the
cross-provider contract drift (which bites the weak providers) and the one Node numeric caveat.

## Owner decisions

- PG-DEC-01 (proposed): treat PostgreSQL as the write-path oracle and reconcile the adapter contract test to
  assert behaviour (not just method presence) using PG as the model (PG-CONTRACT-DRIFT) - this is what
  exposes the ODBC/Mongo gaps.

## Proposed conformance fixture

PostgreSQL is already the oracle in the shared write-path/batch fixtures (real PG, no mocks, gated in the
require-services CI). Keep it; add the large-numeric precision case for Node.

## Integration map

- Consumers: the ORM, migrations (feature 15), the Database facade (feature 5), the SQL translator
  (feature 7, near-no-op for PG). Related: race-safe sequences (feature 16).

## Breaking changes and migration

- None. Reconciling the contract test is internal.

## Implementation backlog

1. PG-DEC-01: make the adapter-contract test assert behaviour (PG as model), all four.
2. Document/handle Node large-numeric precision.

## Porting capsule

A first-class PostgreSQL adapter needs: a lazy/optional driver import; URL-parsed connect with SSL; native
`RETURNING *` for last-id with a SAVEPOINT-wrapped `lastval()` fallback that survives an aborted transaction;
real PK introspection (LEFT JOIN); native type coercion (int8/numeric/uuid/json/bytea) with a documented
large-numeric policy; fail-loud errors; and coverage by the shared write-path fixture against a real PG.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure and security rules complete.
- [x] Wire/type contracts complete.
- [x] Four-language behaviour recorded (first-class all four; PHP PDO fallback; Node precision caveat).
- [x] Owner ambiguities decided (PG-DEC-01).
- [x] Conformance fixture (the existing oracle) recorded.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
