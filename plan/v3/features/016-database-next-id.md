# Feature 016: Race-safe database sequences

## Identity and status

- Matrix identity: 16 - Race-safe database sequences
- Audit state: decision-ready
- Dependencies: Feature 3 adapter interface (execute, fetchOne, transaction, table_exists),
  Feature 5 write facade, the seven providers (008-014) for the native mechanisms
- Dependants: the ORM (an insert without a native auto-id calls this), any application code
  that needs a gap-free-ish id before insert
- Existing ADRs: the connection-pinning and no-autocommit rules apply
- Shared fixtures: `sequences_contract.json` is required, and it MUST include a real
  concurrency case
- Catalog phase: Database
- Audit note: measured from four-language source; no framework code changed

## Why this feature exists

Two requests insert into the same table at the same instant. The old pattern reads
`SELECT MAX(id)` and adds one; both read the same maximum and collide on the primary key.
This feature replaces that race with an atomic next-id, so concurrent callers can never
receive the same value.

## Boundary

This feature owns `get_next_id(table, pk_column, generator_name)`: the per-engine strategy
that returns the next id, the `tina4_sequences` fallback table, the seed-from-MAX rule, and
the single-adapter pinning that keeps seed and increment on one connection. Feature 3 owns
the connection and transaction primitives; the providers own their native sequence and
generator SQL.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Entry point | `_sequence_next` via get-next-id | `sequenceNext` | `get_next_id` | `sequenceNext` via `getNextId` |
| PostgreSQL | native `nextval`, auto-create | native `nextval` | native `nextval`, auto-create | native `nextval` (fixed #255) |
| Firebird | `GEN_ID(gen, 1)`, auto-create | `GEN_ID` | `GEN_ID(gen, 1)`, auto-create | `GEN_ID` |
| SQLite/MySQL/MSSQL | atomic `tina4_sequences` | atomic `tina4_sequences` | atomic `tina4_sequences` | atomic `tina4_sequences` |
| Seed a new row | `MAX(pk)` best-effort, 0 if empty | `sequenceSeedValue` MAX(pk) | MAX(pk) | `sequenceSeedValue` MAX(pk) |
| Adapter pinning | one adapter for seed+increment | same | same | one adapter (pin) |
| Engine-branch bug | - | - | - | took SQLite branch on PG (#255, fixed) |

All four converge on the SAME strategy, documented most fully in the Ruby source: try the
native mechanism first (Postgres `nextval`, Firebird `GEN_ID`), auto-creating the sequence
or generator if it is missing, and fall back to an atomic UPDATE on a shared
`tina4_sequences` table for SQLite, MySQL and MSSQL. A new sequence row is seeded from
`SELECT MAX(pk)` so a sequence created for a populated table does not restart at 1 and
collide. The seed and the increment are pinned to a single adapter so a connection pool
cannot split them. Node carried a real defect (#255) where `getNextId` took the SQLite
table branch on PostgreSQL and hit the non-existent `tina4_sequences` table instead of the
native sequence; it is fixed, and the fix must be gated as parity.

## Public surface contract

`get_next_id(table, pk_column="id", generator_name=None)` (snake case in Python and Ruby;
`getNextId(table, pkColumn, generatorName)` camel case in PHP and Node) returns the next
integer id for the table, race-safe under concurrency. `generator_name` overrides the
derived sequence/generator name. The `tina4_sequences` table (`seq_name`, `current_value`)
and the per-engine helpers are internal, not public surface.

## Inputs and outputs

- Input: a table name, a primary-key column (default `id`), and an optional explicit
  sequence/generator name.
- Output: a native integer strictly greater than every id already handed out for that
  sequence, and greater than `MAX(pk)` at seed time.
- The value is monotonically increasing per sequence; it does NOT guarantee zero gaps
  (a rolled-back transaction may consume a value, exactly like a native sequence).
- On a table with no rows, the first value is 1; on a populated table adopting a sequence,
  the first value is `MAX(pk) + 1`.

## Lifecycle and operation graph

1. `get_next_id` derives the sequence name from the table (or takes `generator_name`) and
   pins a single adapter for the whole operation.
2. On PostgreSQL it calls `nextval`, auto-creating the sequence if it does not exist; on
   Firebird it calls `GEN_ID(gen, 1)`, auto-creating the generator.
3. On SQLite, MySQL and MSSQL it ensures `tina4_sequences`, seeds the row from `MAX(pk)` if
   new, and atomically increments (`UPDATE ... current_value = current_value + 1`) then
   reads the value back, using the engine's atomic idiom.
4. The increment runs in its own transaction unless already inside one, so it neither
   dangles nor double-brackets a caller's transaction.
5. The returned value is used as the primary key for the pending insert.

## Configuration and precedence

- An explicit `generator_name` beats the derived name.
- There is no environment variable; the strategy is chosen by `getDatabaseType`, so the
  branch MUST match the real engine (the #255 class of bug is a mis-branch).
- The `tina4_sequences` table name is fixed.

## Failures, side effects and security

- The whole point is atomicity: under concurrent callers no two values are equal. A
  non-atomic increment (a read then a separate write) is a defect even when it passes a
  single-threaded test.
- The seed read and the increment share one pinned adapter; a pool that split them across
  connections would reintroduce the race.
- A vanished sequence row mid-increment raises a clear error (`sequence row vanished
  mid-increment`) rather than returning a wrong id.
- Auto-creating a Postgres sequence or Firebird generator is idempotent and safe to race.
- The table name and column come from trusted schema, not request input.

## Wire and persistence contract

The `tina4_sequences` table has `seq_name` and `current_value`; a value is applied when the
atomic UPDATE commits. On Postgres and Firebird the state lives in the native sequence or
generator, not the table. The two mechanisms MUST hand out the same guarantee: strictly
increasing, never-duplicated values.

## Providers and substitutability

Postgres and Firebird use their native, already-atomic mechanisms; SQLite, MySQL and MSSQL
use the shared table with an engine-atomic UPDATE. A future runtime picks native where the
engine offers one and the shared table otherwise, and proves the same concurrency guarantee.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| SEQ-01 | The race-safety CLAIM is only as good as its proof; a single-threaded test cannot show atomicity. | The fixture MUST run many concurrent callers against each real engine and assert every returned id is distinct. |
| SEQ-02 | Node mis-branched on PostgreSQL (#255): it hit `tina4_sequences` instead of the native sequence. Parity of engine-branch selection is unproven for the others. | Gate that each engine takes its correct branch (native for PG/Firebird, table for SQLite/MySQL/MSSQL) in all four. |
| SEQ-03 | Seed-from-MAX correctness (a populated table adopting a sequence must start above MAX) is not gated. | Gate first-value = MAX(pk)+1 on a populated table in all four. |
| SEQ-04 | Adapter pinning under a real connection pool is asserted in comments but not gated. | Gate seed+increment on one connection under a pool in all four. |
| SEQ-05 | Behaviour inside an existing transaction (own-transaction vs join) differs per engine helper. | Gate get_next_id called inside a caller transaction: it must not dangle or double-commit. |
| SEQ-06 | Auto-create of the PG sequence / Firebird generator when missing is not gated as parity. | Gate the missing-sequence auto-create path in all four. |
| SEQ-07 | No shared sequences fixture exists. | Add `sequences_contract.json`. |

## Owner decisions

1. `get_next_id` is race-safe by contract, and race-safety is proven only by a real
   concurrency test against each engine (no single-threaded test satisfies this).
2. The strategy is native-first (Postgres `nextval`, Firebird `GEN_ID`, both auto-created)
   and shared-table atomic for SQLite, MySQL and MSSQL; the engine-branch must match
   `getDatabaseType` (closing the #255 class).
3. A new sequence seeds from `MAX(pk)`, so adopting a sequence on a populated table starts
   above the existing maximum.
4. Seed and increment are pinned to one adapter; a pool never splits them.
5. Values are strictly increasing but not gap-free, exactly like a native sequence; a
   rolled-back transaction may consume a value.

## Proposed conformance fixture

Add `sequences_contract.json` with stable ids for: a single next-id on an empty table (=1);
first next-id on a populated table (= MAX(pk)+1); auto-create of a missing PG sequence and
Firebird generator; get_next_id inside a caller transaction (no dangle, no double-commit);
and THE core case: N concurrent callers (real threads or processes) against SQLite, MySQL,
MSSQL, PostgreSQL and Firebird, asserting all N returned ids are distinct and the count
matches. The concurrency case runs against the live lab engines; a mock cannot prove
atomicity and is explicitly forbidden here.

## Integration map

- The ORM calls `get_next_id` when inserting into a table whose engine has no usable native
  auto-id for the chosen strategy.
- Feature 3's transaction primitives bracket the atomic increment; the providers supply the
  native sequence/generator SQL.
- Central fixtures, four runners, the CI matrix (which must run the concurrency case),
  release notes and the database docs update together.

## Breaking changes and migration

- None to the public signature. The audit hardens the race-safety guarantee and gates the
  engine-branch selection; an application already calling `get_next_id` sees the same call
  with a proven guarantee.

## Implementation backlog

1. Add `sequences_contract.json`, including the concurrent-callers case, and wire four
   fail-closed runners against the live lab engines.
2. Gate the concurrency guarantee (SEQ-01) on SQLite, MySQL, MSSQL, PostgreSQL, Firebird.
3. Gate engine-branch selection (SEQ-02), seed-from-MAX (SEQ-03), pinning (SEQ-04),
   in-transaction behaviour (SEQ-05) and auto-create (SEQ-06) in all four.
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `get_next_id(table, pk_column="id", generator_name=None)`. Pin one connection for
the whole call. Try the engine's native mechanism first (Postgres `nextval`, Firebird
`GEN_ID`), auto-creating it if missing; otherwise ensure `tina4_sequences`, seed a new row
from `MAX(pk)`, and atomically increment then read. Own the increment's transaction only
when not already inside one. Return a strictly increasing integer. Prove atomicity with a
real concurrent-callers test against every engine, never a mock and never a single thread.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (the #255 mis-branch and the atomicity-proof gap).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete (concurrency case is mandatory).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
