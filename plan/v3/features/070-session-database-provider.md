# Feature 070: Database session provider

## Identity and status

- Matrix identity: 70 - Database session provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the database session handler in each repo)
  at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: Feature 65 (lifecycle), the Database/ORM layer, a SQL engine
- Dependants: any deployment setting `TINA4_SESSION_BACKEND=database`
- Existing ADRs: ADR-0021 (no-constructor-IO, degrade), ADR-0027 (`ttl<=0` = default), ADR-0028 (the
  database backend follows the configured connection on every engine)
- Shared fixtures: `session_contract.json` PROVES ttl-honoured, no-constructor-IO, loud-then-degrade,
  every-backend-works-on-every-engine and zero-dep-fallback for this backend - and its
  `every-backend-works-on-every-engine-it-claims` narrative already records PHP's MSSQL DDL as
  "MEASURED AND OPEN". This packet audits the database-specific contract.
- Catalog phase: Sessions (providers)

## Why this feature exists

A deployment that already has a SQL database can store sessions in it, with no extra service. The
handler keeps a `tina4_session` table, follows the app's configured connection on every engine
(ADR-0028), and expires rows by a stored `expires_at` - the same way in all four.

## Boundary

This feature owns the database backend's `read`/`write`/`destroy`/`gc`: the table schema, the
auto-create, the connection resolution, the parameter-bound SQL, the JSON serialization, and the
read-time expiry. It DELEGATES the lifecycle to Feature 65 and the actual engine drivers to the
Database layer.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Table / columns | `tina4_session` (`session_id`, `data`, `expires_at`) | same | same | same |
| DDL strategy | ONE generic statement | per-engine map | per-engine map | per-engine map |
| Works on sqlite/pg/mysql | yes | yes | yes | yes |
| Works on MSSQL | NO (invalid DDL) | NO (`CREATE TABLE IF NOT EXISTS`) | yes | yes |
| Works on Firebird | NO (no Firebird DDL) | untested | untested | untested |
| Follows configured connection (ADR-0028) | ORM connection object | `TINA4_DATABASE_URL` env | ORM connection object | `TINA4_DATABASE_URL` env |
| Concurrent-create race guard | NO | yes | yes | yes (idempotent DDL) |
| Parameter-bound SQL | yes | yes | yes | yes |
| `ttl<=0` -> default | in handler | in handler | in handler | in Session |

The table name, columns, JSON serialization, read-time `expires_at` expiry, explicit-only `gc`, no-
constructor-IO and handler-raises-so-Session-degrades are all at parity. The serious divergences are
in the DDL: Python cannot create the table on MSSQL or Firebird, and PHP cannot on MSSQL.

## Public surface contract

`read(id) -> data | empty` (`SELECT data, expires_at ... WHERE session_id = ?`, JSON-decode `data`,
empty on a miss or a past `expires_at` - which is deleted); `write(id, data, ttl=0)` (upsert as
SELECT-then-UPDATE-or-INSERT, `expires_at` an absolute deadline, `ttl<=0` resolving to
`TINA4_SESSION_TTL`); `destroy(id)` (`DELETE ... WHERE session_id = ?`); `gc()` (`DELETE ... WHERE
expires_at > 0 AND expires_at < ?`). Every query binds `session_id` (no interpolation).

## Configuration and precedence

The backend follows the configured connection (ADR-0028). But "the configured connection" is resolved
two ways (DB-04): Python and Ruby inject the ORM's resolved connection object (so an in-process
`bind_database(...)` override is honoured); PHP and Node re-derive from `TINA4_DATABASE_URL` (ignoring
a programmatic ORM binding that differs from the env). `TINA4_SESSION_TTL` (3600) is the write-time
default. The constructor resolves config only; the connection opens and the table is created on first
use (ADR-0021).

## Failures, side effects and security

- INJECTION is closed: every statement binds `session_id`; the only interpolated token is the constant
  table name. The cookie value can never be SQL-injected.
- NO-CONSTRUCTOR-IO holds (ADR-0021, proven): the constructor resolves the path/config only; the
  connection and the `CREATE TABLE` happen on first use.
- DEGRADE: a connect/read failure RAISES so Feature 65 degrades; strict mode re-raises.
- PYTHON DDL BREAKS ON MSSQL AND FIREBIRD (DB-01): Python ships ONE generic statement
  (`session_id VARCHAR(255)`... actually `TEXT PRIMARY KEY` historically; `data TEXT`; `expires_at
  DOUBLE PRECISION`) - the exact statement PHP/Ruby/Node REPLACED with per-engine maps because `TEXT`
  is rejected by Firebird and deprecated on SQL Server and `DOUBLE PRECISION` is invalid T-SQL. So
  Python's database session backend cannot create its table on MSSQL or Firebird - it does not work
  there at all. (This inverts the usual Python-master expectation; the other three are ahead.)
- PHP MSSQL DDL INVALID (DB-02): PHP emits `CREATE TABLE IF NOT EXISTS` unconditionally, which is not
  T-SQL, so MSSQL fails with "Incorrect syntax near tina4_session". Recorded MEASURED AND OPEN in
  session_contract.json: the fix is ~14 characters but it also changes concurrent-first-use behaviour
  on sqlite/pg/mysql (engine idempotency becomes a raise for the race loser), so it needs 4-way parity
  work, not a lone edit.
- FIREBIRD UNTESTED (DB-03): PHP/Ruby/Node ship Firebird DDL but do not claim it works end-to-end;
  Python has no Firebird DDL at all. No framework proves the database session backend on Firebird.

## Wire and persistence contract

A session is a row `(session_id, data, expires_at)` in `tina4_session`, `data` a JSON string,
`expires_at` an absolute deadline (0 = never). The table name and columns are identical in all four,
so a row written by one framework reads in another (on an engine where all four can create the table).
There are no `created`/`accessed` columns; those live inside the JSON `data` (`_created`/`_accessed`).

## Providers and substitutability

The database backend is selected by `TINA4_SESSION_BACKEND=database` (ADR-0024) and rides the app's
own Database layer, so it works on every engine that layer supports (ADR-0028) - modulo the DDL gaps
above. It is the backend that most directly reuses existing infrastructure (no new service).

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| DB-01 | Python's single generic DDL (`TEXT`, `DOUBLE PRECISION`) cannot create the table on MSSQL or Firebird - the database session backend does not work there. PHP/Ruby/Node use per-engine DDL maps. | Give Python a per-engine DDL map (port the proven PHP/Ruby/Node maps); gate the table creates on MSSQL. Python converges onto the other three here. |
| DB-02 | PHP emits `CREATE TABLE IF NOT EXISTS` (invalid T-SQL) so MSSQL fails; recorded MEASURED AND OPEN. The fix changes concurrent-first-use behaviour on other engines, so it is 4-way work. | Remove the clause on MSSQL (guarded by `tableExists`) and settle the concurrent-first-use race policy in all four. |
| DB-03 | The database session backend is untested on Firebird in all four (Python has no Firebird DDL; the others ship it but do not claim it). | Provision Firebird for the session fixture and prove (or fix) the backend on Firebird in all four. |
| DB-04 | ADR-0028 "the configured connection" is the ORM connection OBJECT in Python/Ruby but the `TINA4_DATABASE_URL` env in PHP/Node; a programmatic `bind_database(...)` that differs from the env is honoured by two and ignored by two. | Pin ONE resolution (recommend the ORM connection object, so an in-process binding is honoured) in all four. |
| DB-05 | Python auto-create has no concurrent-create race guard (`table_exists()` then bare `CREATE`); PHP/Ruby/Node guard the race. | Add the create-then-recheck guard to Python. |
| DB-06 | Python reads `row["expires_at"]`/`row["data"]` only (no upper-case handling); Node/PHP/Ruby read case-insensitively (pg lowercases, Firebird uppercases). | Read the columns case-insensitively in Python (moot until DB-01 lets Python reach Firebird, but a latent bug on any upper-casing engine). |

## Owner decisions

Proposed for owner ratification:

1. PYTHON PER-ENGINE DDL (DB-01): Python adopts a per-engine DDL map so the database session backend
   works on MSSQL and Firebird like the other three. This is the clearest "the best implementation
   prevails, both ways" case (ADR-0004): Python converges onto PHP/Ruby/Node.
2. MSSQL CREATE-TABLE + CONCURRENT-CREATE (DB-02, DB-05): remove the invalid `IF NOT EXISTS` on MSSQL,
   add Python's race guard, and pin ONE concurrent-first-use policy across the four.
3. FIREBIRD (DB-03): provision Firebird for the session fixture and prove or fix the backend there in
   all four - no framework claims it today.
4. ADR-0028 RESOLUTION (DB-04): pin the ORM connection object as "the configured connection" so an
   in-process `bind_database` override is honoured uniformly.

## Proposed conformance fixture

Extend `session_contract.json` (its `every-backend-works-on-every-engine` invariant already covers
sqlite/pg/mysql) with the two missing engines driving four runners against a REAL MSSQL and a REAL
Firebird (no doubles): the table is created and a session round-trips on MSSQL and on Firebird in all
four; a programmatic `bind_database` override is followed (DB-04); two concurrent first-creates both
succeed (DB-05); and an upper-casing engine's column names read correctly (DB-06). Every case re-reads
out of band on a second connection so a silent demotion to a local file cannot fake a pass (the
anti-demotion guard ADR-0028 keeps).

## Integration map

- Feature 65 calls `read`/`write`/`destroy`/`gc`; the SQL and the connection are the Database layer's.
- `session_contract.json` proves the shared invariants and records PHP's MSSQL DDL as OPEN.
- ADR-0028 governs the connection-follows-config rule; the session docs describe the schema and env.

## Breaking changes and migration

- DB-01/DB-02 make the backend work on MSSQL/Firebird where it did not; additive (a deployment that
  could not use it now can). No existing session breaks.
- DB-04 pinning the ORM-object resolution changes PHP/Node to honour an in-process binding; a
  deployment that relied on the env-only behaviour is unaffected unless it set both differently.
  `Breaking:` only in that edge.

## Implementation backlog

1. Provision MSSQL + Firebird for the session fixture; add the two-engine cases and wire four runners.
2. Port a per-engine DDL map into Python (DB-01); fix PHP MSSQL `CREATE TABLE` + the concurrent race
   (DB-02, DB-05); pin the ADR-0028 resolution (DB-04); case-insensitive column reads in Python (DB-06).
3. Prove or fix the backend on Firebird in all four (DB-03).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the database backend: keep a `tina4_session` table (`session_id`, `data`, `expires_at`)
created on first use with a PER-ENGINE DDL map (never one generic statement - `TEXT`/`DOUBLE
PRECISION` break MSSQL and Firebird), guarded against a concurrent first-create. Follow the app's
configured connection object on every engine (ADR-0028), never a hardcoded sqlite file. `read` selects
by a bound `session_id` and JSON-decodes `data` (empty on a miss or a past `expires_at`, which is
deleted); `write` upserts with an absolute `expires_at` (`ttl<=0` -> `TINA4_SESSION_TTL`, 0 = never);
`destroy` deletes by a bound id; `gc` deletes expired rows. Read columns case-insensitively. Raise on
failure so the lifecycle degrades. Prove the port on sqlite, postgres, mysql, MSSQL AND Firebird.

## Audit closure checklist

- [x] Boundary and public surface complete (schema, read/write/destroy/gc, connection resolution).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (injection, no-constructor-IO, DDL).
- [x] Wire/storage and provider contracts complete (table/columns parity, JSON, expires_at).
- [x] Existing-language contradictions recorded (DB-01..06; Python-MSSQL/Firebird and PHP-MSSQL are real defects).
- [x] Owner ambiguities recorded (4 proposed; the per-engine DDL and the ADR-0028 resolution are key).
- [x] Proposed shared cases and mutation witnesses complete (real MSSQL + Firebird, anti-demotion guard).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
