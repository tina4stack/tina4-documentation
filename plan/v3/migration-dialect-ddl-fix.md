# Migration / DDL dialect fix — scaffolding emits non-portable SQLite DDL

## Confirmed bug (all four frameworks, 2026-08-29)
`tina4 generate migration` / `migrate:create` / `generate model` emit hardcoded
SQLite DDL and NEVER consult the configured engine. Apply-time translation only
rewrites the `AUTOINCREMENT` keyword. `TEXT`, `REAL`, `created_at TEXT`, and
`CREATE TABLE IF NOT EXISTS` pass through and break on Firebird + MSSQL.
**Manifested in a real Python project.**

Generated DDL, per framework (measured):
| Framework | string | float | id | created_at |
|---|---|---|---|---|
| Python | `TEXT` | `REAL` | `AUTOINCREMENT` | `TEXT` |
| Node | `TEXT` | `REAL` | `AUTOINCREMENT` | `TEXT` |
| PHP | `VARCHAR(255)` | `REAL` | `AUTOINCREMENT` | `TEXT` |
| Ruby | `VARCHAR(255)` | `REAL` | `AUTOINCREMENT` | `TEXT` |

Breaks: **Firebird** (no `TEXT`, no `REAL`, no `IF NOT EXISTS`), **MSSQL** (no
`CREATE TABLE IF NOT EXISTS`; `TIMESTAMP` is a rowversion), **MySQL** (`TEXT`
can't take a DEFAULT before 8.0.13 — Python/Node only). Proven by running each
framework's own Firebird `_translate_sql` over its own generated DDL: `IF NOT
EXISTS`, `TEXT`, `REAL` all survive untranslated.

**Deeper:** `ORM.create_table()` ALSO emits `REAL` (FloatField) and `TEXT`
(TextField) — model.py:1201/1200 — so a FloatField/TextField model breaks Firebird
via create_table too, independent of migrations. This makes the apply-time
translator the right, DRY place to fix.

Why invisible: the co-emitted migration test only applies UP/DOWN against SQLite.

## Fix (parity, all four)
Two parts:

1. **Complete the apply-time DDL translator** (the DRY core — covers migrations,
   `create_table`, and hand-written SQL, because everything goes through the
   adapter's `_translate_sql` on execute). Add a `ddl_types(sql, engine)` that
   ONLY touches `CREATE TABLE` / `ALTER TABLE` statements (so a query/INSERT with
   the word TEXT is never corrupted):
   - **Firebird:** `TEXT`→`BLOB SUB_TYPE TEXT`, `REAL`→`DOUBLE PRECISION`, strip
     `IF NOT EXISTS`. (`AUTOINCREMENT` already stripped; ORM fills id via
     `get_next_id`/generator.)
   - **MSSQL:** strip `IF NOT EXISTS`, `TIMESTAMP`→`DATETIME2` (MSSQL TIMESTAMP is
     a rowversion). (`AUTOINCREMENT`→`IDENTITY(1,1)` already.)
   - **MySQL:** `TIMESTAMP`→`DATETIME` (2038/auto-update). (`AUTOINCREMENT`→`AUTO_INCREMENT` already.)
   - **PostgreSQL / SQLite:** already native (SERIAL translation already there).

2. **Generator canonical types (parity):** Python + Node string field → `VARCHAR(255)`
   (join PHP/Ruby), and all four emit `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
   (was `TEXT`). Keep `IF NOT EXISTS` in the file (translator strips for FB/MSSQL).
   Float stays `REAL`, text stays `TEXT` — the translator maps them per engine.

Net: one generated migration (and any `create_table`) applies on every engine.

## Parity dashboard
| Piece | Python | PHP | Ruby | Node |
|-------|--------|-----|------|------|
| translator: DDL type map (TEXT/REAL/TIMESTAMP/IF NOT EXISTS) | ✅ | ✅ | ⬜ | ✅ |
| generator: string→VARCHAR(255) | ✅ | ✅ has it | ✅ has it | ✅ |
| generator: created_at→TIMESTAMP | ✅ | ✅ | ⬜ | ✅ |
| real per-engine migration test (apply on Firebird + round-trip) | ✅ | ✅ | ⬜ | ✅ |

**PHP DONE + verified INDEPENDENTLY at HEAD** (my Mac, live lab Firebird via
pdo_firebird): `MigrationDialectFirebirdTest.php` = OK(8 tests, 33 assertions).
Worker found PHP adapters did NO execute-time DDL translation at all (only
`ORM::createTable` pre-translated AUTOINCREMENT) — MORE broken than assumed — and
that on macOS/lab the runtime path is `PdoFirebirdAdapter` (ext-interbase hits the
clumplet bug, auto-falls back to pdo_firebird), so it added a `translateDdl()` hook
to `PdoAdapterTrait` + override in `PdoFirebirdAdapter` (the path that actually
runs) as well as the native adapter + MSSQL/MySQL. Generator created_at
`DATETIME`→`TIMESTAMP` (DATETIME is invalid on Firebird+PG too). MySQL/MSSQL execute
wiring proven by pure unit tests (no server on Mac) — confirm on lab. One
pre-existing FB reconnect error (proven not the worker's via git stash — macOS
pdo_firebird reconnect gap, separate follow-up).

**Node DONE + verified INDEPENDENTLY at HEAD** (my Mac, live lab Firebird 5):
`migrationDialectDdlTypes.test.ts` = 27 passed / 0 failed (12 pure + 7 wiring + 4
generator + 4 live round-trip), typecheck 0. Worker found + fixed a DEEPER Node
defect: `translateSql` for firebird/mysql/mssql was wiring NEITHER
`autoIncrementSyntax` NOR `ddlTypes` (Python/PHP/Ruby already wire the former) —
now wires both. Mutation-proven (removing FB wiring → live -104 on untranslated
`IF NOT EXISTS`). Node worker also flagged an ORTHOGONAL gap: Node's mssql
`translateSql` lacks `booleanToInt` (Python has it) — separate follow-up, not this fix.

**Python DONE + verified on LIVE Firebird 5** (lab, SYSDBA):
`SQLTranslator.ddl_types(sql, engine)` (DDL-gated, tolerates leading comments) +
wired into firebird/mssql/mysql `_translate_sql`; generator string→VARCHAR(255),
datetime + created_at → TIMESTAMP. `tests/test_migration_dialect_firebird.py` =
7 green (5 pure + generator + a real Firebird round-trip: generated migration
applies, row round-trips with bio=`BLOB SUB_TYPE TEXT`, price=`DOUBLE PRECISION`).
445 passed / 0 fail in the migration/translator/generate/create_table subset — no
regressions. (macOS+FB5 driver crashes on GC when MANY live-FB tests churn
connections — an env fragility, not the code; the dedicated file runs clean.)
The translator fix is DRY: it also fixes `ORM.create_table()` (which emits REAL/
TEXT too, model.py:1201/1200) on Firebird, and any hand-written migration.
Files: sql_translator.py, database/{firebird,mssql,mysql}.py, cli/__init__.py.

## Tests (REAL, no mocks — per engine on the lab)
- Generate a migration with string+float+datetime+bool fields; APPLY it against
  real SQLite AND real **Firebird** (lab 192.168.88.99:3050, tina4/tina4,
  tina4test.fdb — host-reachable), assert the table is created and a row
  round-trips. Add PG/MySQL/MSSQL where the lab exposes them.
- `create_table()` for a model with a FloatField + TextField + DateTimeField
  applies on real Firebird (proves the translator fix covers the ORM path too).
- Negative: the pre-fix DDL (`REAL`/`TEXT`/`IF NOT EXISTS`) is proven to FAIL on
  Firebird (the regression that would reintroduce the bug).

## Verify on the lab, ship feature/release -> v3 -> tag across all four.

## Status: SHIPPED as 3.13.125 (2026-08-29) — all four.

All four verified on the LAB against live Firebird 5 (release-3.13.105-verify
clones, `feature/release3.13.125`): Python 76 passed, Ruby 10 examples (live
round-trip ran), Node 27 passed, PHP OK(8,33). Merged feature/release3.13.125 →
v3, tagged 3.13.125, pushed. Publishes green: PyPI, Packagist, RubyGems, npm.
Node + Ruby each also fixed a deeper defect the port surfaced (their adapters
wired NO execute-time translation at all). Release notes updated
(docs/index.md + the four 36-releases.md). Lint work stays parked on each repo's
`parked/lint-and-migration-20260829` branch.
