# Feature 16: Race-safe database sequences (get_next_id)

## Identity and status

- Matrix identity: 16 - Race-safe database sequences (`tina4_python/database/__init__.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, a SOUND core design with a universal race hole in one fallback and a
  broken Mongo path. Measured 2026-08-11. Python `database/connection.py:1301` (`ebbab30`); PHP
  `Tina4/Database/Database.php:1384` (`6faabac5`); Ruby `lib/tina4/database.rb:1177` (`6d5b1de`); Node
  `packages/orm/src/database.ts:1377` (`27cf0f4`).
- Dependencies: the DB adapters (a pinned connection), engine-native sequences/generators, and a portable
  `tina4_sequences` table.
- Dependants: the ORM (allocating a primary key before insert), any code needing a portable next id.
- Existing ADRs: none dedicated.

- Catalog phase: database

## Why this feature exists

The ORM needs a primary-key value before it inserts a row, portably across engines that generate ids very
differently (PostgreSQL sequences, Firebird generators, MySQL auto-increment, SQL Server identity, MongoDB
ObjectIds). `get_next_id` is the one call that returns the next id safely - and "safely" means under
concurrency, which is where a naive `MAX(id)+1` loses. The design deliberately removed `MAX+1`; the audit
confirms that, and finds where the safety still leaks.

## Existing implementation evidence

SOUND shared design in all four: `get_next_id(table, pk_column="id", generator_name=None)` pins ONE
connection and returns an ATOMIC increment - never `MAX+1` at return time (`MAX(pk)` is used only as a
one-time seed). Per engine:

- PostgreSQL: `nextval('<table>_<pk>_seq')` (reuses the real SERIAL sequence; auto-creates seeded from
  `MAX+1` if missing) - atomic.
- Firebird: `GEN_ID(GEN_<TABLE>_ID, 1)` - atomic.
- MySQL: `UPDATE tina4_sequences SET current_value = LAST_INSERT_ID(current_value + 1)` + `SELECT
  LAST_INSERT_ID()` on the pinned connection - per-connection atomic.
- MSSQL: single `UPDATE tina4_sequences SET current_value = current_value + 1 OUTPUT inserted.current_value`
  - atomic.
- SQLite: an atomic increment under a write lock - the MECHANISM diverges but all are safe (PHP `BEGIN
  IMMEDIATE` takes the file write-lock up front = cross-process; Python/Ruby a process Mutex + `UPDATE ...
  RETURNING`; Node a synchronous `node:sqlite` burst).

The portable `tina4_sequences(seq_name PK, current_value)` table backs the SQLite/MySQL/MSSQL/fallback paths.
The design (atomic, `MAX+1` removed, PG sequence name matching the SERIAL column's own sequence) is correct -
credit where due.

## Public surface contract

`db.get_next_id(table, pk_column="id", generator_name=None) -> int` returns the next id, allocated atomically.
The contract is uniqueness under concurrency.

## Inputs and outputs

- Input: the table, the PK column, an optional generator/sequence name. Output: the next integer id (or an
  ObjectId string on Mongo, where present).

## Lifecycle and operation graph

1. Pin one connection/adapter.
2. Dispatch by engine: native sequence/generator (PG/Firebird), or the `tina4_sequences` atomic increment
   (SQLite/MySQL/MSSQL), or the generic fallback (see the register).
3. Seed from `MAX(pk)` once (insert-if-absent); return the atomic increment.

## Configuration and precedence

- None. The sequence/generator/table names are derived from the table + PK column.

## Failures, side effects and security

- Side effect: creates the `tina4_sequences` row / a native sequence/generator on first use. The failure
  mode is a DUPLICATE id under concurrency on the non-atomic paths (the generic fallback and Mongo - see the
  register). Identifiers are string-interpolated into SQL (table/pk/seq names, not user input) - a footgun,
  not an injection.

## Wire and persistence contract

Native sequences/generators, or the `tina4_sequences` table. The contract is a strictly increasing, unique id
per (table, pk).

## Providers and substitutability

Per-engine dispatch; the `tina4_sequences` table is the portable fallback. Adding an engine means an atomic
path or it falls to the racy generic fallback.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| NEXTID-GENERIC-TOCTOU | UNIVERSAL: the generic fallback (`_sequence_next_generic`/`sequenceNextGeneric`) does `UPDATE ... +1` then a SEPARATE `SELECT current_value`, with NO lock / `FOR UPDATE` - a genuine TOCTOU where two concurrent callers read the same post-both-increment value and return a DUPLICATE id. It is reachable in all four via the PostgreSQL FIRST-USE race (two concurrent callers both `CREATE SEQUENCE`; the loser's error is swallowed and it falls through to this generic path) and for ODBC/other/Mongo engines. | Make the fallback atomic (a `SELECT ... FOR UPDATE` under an explicit transaction, or an atomic `UPDATE ... RETURNING`/`OUTPUT` where the engine supports it). Fix the PG first-use race (create the sequence idempotently, or serialize first-create) so the loser does not fall to the racy path. |
| NEXTID-MONGO-BROKEN | Mongo `get_next_id` is broken or dangerous in ALL four, each differently: Python and PHP have a dedicated `findOneAndUpdate($inc)` (atomic), but PHP's swallows ANY error and `return 1` (`Database.php:1540`) - a DUPLICATE-PK collision with an existing row; Ruby has NO Mongo path at all (a Mongo DB falls to the relational generic path, inapplicable); Node also has no dedicated path and falls to the generic SQL path, where `parseSql`'s SET-clause parser matches only `col = ?`/literal and NOT `current_value + 1`, so the increment is SILENTLY DROPPED (empty `$set`, the value never advances -> duplicate ids) and un-indexed seed rows accumulate. NONE has a Mongo next-id test. | Give Mongo one correct, tested atomic path in all four (`findOneAndUpdate({seq}, {$inc:{current_value:1}}, {upsert, returnAfter})` with a unique index on `seq_name`); PHP must not `return 1` on error (raise); Ruby/Node must not fall to the relational generic path. |
| NEXTID-SQLITE-ONLY-TESTS | UNIVERSAL: concurrency is proven ONLY on SQLite in all four (PHP a 60-way `pcntl_fork` cross-process test, Python/Ruby 100 threads, Node 100 `Promise.allSettled` - which cannot even interleave a synchronous `node:sqlite` burst). There is NO real concurrency test for PostgreSQL-native, MySQL `LAST_INSERT_ID`, MSSQL `OUTPUT`, the generic fallback, or Mongo in ANY language - the cross-engine race-safety claim is asserted by construction only. Given "zero doubles still shipped 3 data-loss bugs", this is the highest-value gap. | Add a real, gated concurrency test per engine (N concurrent callers -> N distinct contiguous ids) for PostgreSQL, MySQL, MSSQL, and Mongo, plus a test that the generic fallback DOES produce a duplicate (proving the finding) before it is fixed. |
| NEXTID-PG-FIRSTUSE | The PostgreSQL first-use bootstrap has a race in all four: concurrent first callers both attempt `CREATE SEQUENCE`; the loser falls to the racy generic path (NEXTID-GENERIC-TOCTOU) and can draw a duplicate during that window. Narrow (first-creation burst only) but real and untested. | Create the sequence idempotently (`CREATE SEQUENCE IF NOT EXISTS`) or serialize the first-create so the loser retries `nextval` rather than falling to the generic path. |
| NEXTID-MYSQL-POOLING | Node: MySQL's per-connection `LAST_INSERT_ID` safety depends on connection pooling; with a single shared connection, two concurrent async callers interleave at the `await` between the UPDATE and the `SELECT LAST_INSERT_ID()`. | Document the pooling assumption, or make the MySQL path a single atomic statement that does not depend on a per-connection session var across an await. |

## Owner decisions

- NEXTID-DEC-01 (proposed): make the generic fallback atomic and fix the PostgreSQL first-use race
  (NEXTID-GENERIC-TOCTOU + NEXTID-PG-FIRSTUSE) - these are the real duplicate-id windows.
- NEXTID-DEC-02 (proposed): give Mongo one correct, tested atomic next-id in all four and remove PHP's
  `return 1`-on-error (NEXTID-MONGO-BROKEN).
- NEXTID-DEC-03 (proposed): add per-engine concurrency tests (NEXTID-SQLITE-ONLY-TESTS) - the coverage that
  would prove (or disprove) every atomic-by-construction claim.

## Proposed conformance fixture

A real, gated concurrency fixture per engine (no mocks): N concurrent callers to `get_next_id` return N
DISTINCT contiguous ids on SQLite (exists), PostgreSQL, MySQL, MSSQL, and Mongo; a test that the generic
fallback and the PG first-use race CAN duplicate (red before the fix, green after); and a Mongo test that the
increment actually advances (catches the Node dropped-`+1` and the PHP `return 1`). Gate the real-engine parts
in the require-services CI.

## Integration map

- Consumers: the ORM (PK allocation before insert), apps. Related: the DB providers (9-14, whose native
  sequence/generator this uses) and feature 5 (the Database facade / pinned connection / transactions).

## Breaking changes and migration

- Fixing the generic fallback and the Mongo path changes behaviour only in the duplicate-producing windows
  (a correctness/data-integrity fix) - document it.

## Implementation backlog

1. NEXTID-DEC-01: atomic generic fallback + idempotent PG sequence create (fix the TOCTOU + first-use race),
   with a proving test.
2. NEXTID-DEC-02: one correct tested Mongo next-id in all four; remove PHP `return 1`.
3. NEXTID-DEC-03: per-engine concurrency tests (PG/MySQL/MSSQL/Mongo).

## Porting capsule

A race-safe `get_next_id` needs: NEVER `MAX+1` at return time (seed only); a native atomic path per engine
(`nextval`/`GEN_ID`/`LAST_INSERT_ID`/`OUTPUT`/an atomic `UPDATE ... RETURNING`); a portable `tina4_sequences`
table for engines without one; an ATOMIC fallback (`SELECT ... FOR UPDATE` or `RETURNING` - never a separate
`UPDATE` then `SELECT`, which is a TOCTOU); an idempotent first-create for the native sequence (so a
concurrent first-use loser does not fall to the racy path); one correct atomic Mongo path
(`findOneAndUpdate($inc)` with a unique `seq_name` index, never `return 1` on error); and a REAL per-engine
concurrency test (N callers -> N distinct ids) - not SQLite-only, the gap that leaves every other engine's
safety unproven.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete (pin, dispatch, seed, atomic increment).
- [x] Configuration, failure (duplicate id) and security rules complete.
- [x] Wire/persistence (native sequences + `tina4_sequences`) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (generic TOCTOU universal; Mongo broken 4 ways;
  SQLite-only tests).
- [x] Owner ambiguities decided (NEXTID-DEC-01..03).
- [x] Conformance fixture (per-engine concurrency) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
