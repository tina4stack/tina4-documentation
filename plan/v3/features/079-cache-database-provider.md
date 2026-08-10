# Feature 079: Database cache provider

## Identity and status

- Matrix identity: 79 - Database cache provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the database backend in each cache module)
  at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: Feature 72 (interface), the Database/ORM layer, a SQL engine
- Dependants: any deployment on `TINA4_CACHE_BACKEND=database` (or `TINA4_DB_CACHE_BACKEND=database`)
- Existing ADRs: ADR-0024 (interface), ADR-0032 (sweep returns a real count - the SQL table cannot
  self-expire), ADR-0028 (the database backend follows the configured connection)
- Shared fixtures: `cache_contract.json` (8/8 PROVEN) exercises the database backend against a live SQL
  engine.
- Catalog phase: Cache (providers)

## Why this feature exists

A deployment that already has a SQL database can use it as a shared cache with no extra service. The
backend keeps a `tina4_cache` table, stores each entry with an `expires_at`, and - because SQL has no
native TTL - is the one networked backend whose `sweep()` returns a REAL count (it must delete expired
rows itself).

## Boundary

This feature owns the database cache backend's `get`/`set`/`delete`/`clear`/`sweep`/`available?`: the
`tina4_cache` table, the auto-create, the parameter-bound SQL, and the read-time expiry. It DELEGATES
selection and fallback to Feature 72 and the engine drivers to the Database layer. It is the cache
sibling of the session database provider (Feature 70).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Table | `tina4_cache` | same | same | same |
| Auto-create on first use (`available?` probe) | `CREATE TABLE` | `CREATE TABLE IF NOT EXISTS` | per-engine | per-engine |
| Works on sqlite/pg/mysql | yes | yes | yes | yes |
| Works on MSSQL / Firebird | see DB-79-01 (softened by fallback) | see DB-79-01 | (untested) | (untested) |
| Parameter-bound SQL | yes | yes | yes | yes |
| Cached null (envelope) | HIT | HIT | HIT | HIT |
| `clear()` | `DELETE FROM tina4_cache` | same | same | same |
| `sweep()` returns a real count | yes | yes | yes | yes |

The database cache backend is at parity and proven for the interface invariants. It is the one
networked backend where `sweep()` reclaims (SQL cannot self-expire), and it is the one that inherits the
session database provider's DDL portability question (Feature 70) - softened here because a failed
`CREATE TABLE` makes `available?` false and the factory falls back to file, rather than crashing.

## Public surface contract

`get(key) -> value | miss` (`SELECT value, expires_at ... WHERE key = ?`, unwrap the envelope, a stored
null is a HIT; a past `expires_at` is a miss); `set(key, value, ttl)` (upsert `{key, value,
expires_at}`); `delete(key)` (`DELETE ... WHERE key = ?`); `clear()` (`DELETE FROM tina4_cache`);
`sweep() -> evicted` (`DELETE ... WHERE expires_at > 0 AND expires_at < ?`, return the count). Every
query binds the key.

## Configuration and precedence

`TINA4_CACHE_URL` (a SQL URL, falling back to `TINA4_DATABASE_URL`). The backend follows the configured
connection (ADR-0028). The constructor resolves config only; the connection and the `CREATE TABLE`
happen on first use inside the `available?` probe, so a DDL failure degrades to file rather than
raising.

## Failures, side effects and security

- INJECTION is closed: every statement binds the key; the only interpolated token is the constant table
  name.
- SWEEP RECLAIMS (ADR-0032): unlike the server-expiring backends, the SQL table cannot self-expire, so
  `sweep()` runs a real DELETE and returns the count - the interface's one networked backend that does.
- DDL PORTABILITY (DB-79-01, shared with Feature 70): the cache `tina4_cache` DDL inherits the same
  engine question as the session `tina4_session` DDL - Python's generic DDL (`TEXT`/`DOUBLE PRECISION`)
  and PHP's `CREATE TABLE IF NOT EXISTS` do not work on MSSQL/Firebird. Here the failure is SOFTER: a
  failed `CREATE TABLE` makes `available?` false and the cache degrades to FILE (Feature 72), rather
  than crashing like the session backend. But it means the database cache backend SILENTLY does not
  work on MSSQL/Firebird (it runs on file while the operator believes it is on the database).
- FALLBACK: a failed create or an unreachable engine degrades to file at selection time.

## Wire and persistence contract

An entry is a row `(key, value, expires_at)` in `tina4_cache`, `value` an envelope so a stored null
round-trips. `sweep()`/`clear()` delete expired/all rows. The table name and columns are uniform; a row
written by one framework reads in another on an engine where all four create the table.

## Providers and substitutability

Selected by `TINA4_CACHE_BACKEND=database` (ADR-0024), riding the app's Database layer (ADR-0028). It is
the cache analog of the session database provider (Feature 70); the DDL portability fix lands together,
though the cache side degrades to file where the session side crashes.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| DB-79-01 | The cache `tina4_cache` DDL inherits Feature 70's engine gaps - Python's generic DDL and PHP's `CREATE TABLE IF NOT EXISTS` do not work on MSSQL/Firebird, so the database cache backend silently falls back to file there (rather than crashing). | Give Python a per-engine DDL map and fix PHP's MSSQL DDL (resolve together with Feature 70 DB-01/DB-02), so the database cache backend actually works on MSSQL/Firebird instead of silently degrading. |
| DB-79-02 | The ADR-0028 connection-resolution split (ORM object in Python/Ruby vs `TINA4_DATABASE_URL` env in PHP/Node - Feature 70 DB-04) applies to the cache database backend too. | Pin one resolution (recommend the ORM connection object) consistent with Feature 70. |

The database cache backend is otherwise proven parity on the interface invariants (bound SQL,
sweep-count, cached-null, clear).

## Owner decisions

Proposed for owner ratification:

1. DDL PORTABILITY (DB-79-01): resolve together with the session database provider (Feature 70) - per-
   engine DDL in Python, MSSQL DDL in PHP - so the database cache backend works on MSSQL/Firebird
   rather than silently degrading to file.
2. ADR-0028 RESOLUTION (DB-79-02): pin the ORM connection object, consistent with Feature 70.

## Proposed conformance fixture

`cache_contract.json` already gates the database backend for every interface invariant. Add the
missing-engine cases (shared with Feature 70): the `tina4_cache` table is created and an entry
round-trips on MSSQL and Firebird in all four (rather than silently degrading to file), re-read out of
band to prove the backend is the database, not the file fallback.

## Integration map

- Feature 72 selects and probes this backend; Feature 70 is the session database sibling; the DDL fix
  lands together.
- `cache_contract.json` proves it against a live SQL engine; the MSSQL/Firebird cases are added there.
- ADR-0028 governs the connection-follows-config rule.

## Breaking changes and migration

- DB-79-01 makes the backend work on MSSQL/Firebird where it silently fell back to file; additive (a
  deployment that thought it was on the database now really is). No cache data breaks.

## Implementation backlog

1. Resolve DB-79-01/DB-79-02 alongside Feature 70 (per-engine DDL in Python, MSSQL DDL in PHP, ADR-0028
   resolution).
2. Add the MSSQL/Firebird cases to `cache_contract.json` (asserting the backend is the DB, not file).
3. Run locally and on the root lab; the CONTRACT-MAP row stays proven.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the database cache backend: keep a `tina4_cache` table (`key`, `value`, `expires_at`) created
on first use with a PER-ENGINE DDL map (never one generic statement), following the app's configured
connection (ADR-0028). `get` selects by a bound key and unwraps the envelope (a stored null is a hit; a
past `expires_at` is a miss); `set` upserts with an absolute `expires_at`; `delete` deletes by a bound
key; `clear` is `DELETE FROM tina4_cache`; `sweep` deletes expired rows and returns the count (the SQL
table cannot self-expire). Prove the port on sqlite, postgres, mysql, MSSQL AND Firebird - and that a
DDL failure degrades to file rather than crashing.

## Audit closure checklist

- [x] Boundary and public surface complete (table, bound SQL, sweep-reclaim, clear).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (injection, DDL portability, fallback).
- [x] Wire/storage and provider contracts complete (table/columns, envelope, expires_at).
- [x] Existing-language contradictions recorded (DB-79-01/02, shared with Feature 70).
- [x] Owner ambiguities recorded (2 proposed; per-engine DDL and the ADR-0028 resolution).
- [x] Proposed shared cases and mutation witnesses complete (real MSSQL + Firebird, anti-fallback guard).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
