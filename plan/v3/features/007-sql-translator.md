# Feature 7: SQL translator

## Identity and status

- Matrix identity: 7 - SQL translator (`tina4_python/database/sql_translator.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature. Measured 2026-08-11 from shipped source by four parallel readers.
  Python `database/sql_translator.py:19` (`feature/csrf-fail-closed` HEAD `ebbab30`); PHP
  `Tina4/SQLTranslator.php:14` (`feature/mcp-call-gate` HEAD `6faabac5`); Ruby `lib/tina4/sql_translator.rb:18`
  (`6d5b1de`); Node `packages/orm/src/sqlTranslator.ts:23` (`27cf0f4`).
- Dependencies: none (pure string transforms + a hash for the query-cache key).
- Dependants: the six SQL providers (features 9-14) which call it to adapt the canonical SQL to their
  dialect; the batch-insert collapse; the ORM `create_table` DDL (autoincrement).
- Existing ADRs: none dedicated.

- Catalog phase: database

## Why this feature exists

Tina4 writes one canonical, SQLite-flavoured SQL and lets each engine adapter translate it to its dialect,
so app and ORM code stays portable. The translator is that shared rulebook: LIMIT/OFFSET shapes, boolean
literals, string concatenation, autoincrement syntax, placeholder styles, and the batch-insert collapse.
Get it right and one query runs everywhere; get it wrong and it silently emits invalid SQL on an engine the
developer never tested against.

## Existing implementation evidence

All four ship a static `SQLTranslator` with the same rule set, canonical input = SQLite/ANSI (`?`
placeholders, `AUTOINCREMENT`, `LIMIT/OFFSET`, `||`, `TRUE/FALSE`, `ILIKE`). The transforms: `limit_to_rows`
(Firebird `ROWS x TO y`), `limit_to_top` (MSSQL `TOP n`), `boolean_to_int`, `concat_pipes_to_func`
(`||`->`CONCAT`), `auto_increment_syntax` (per-engine), `placeholder_style`, `ilike_to_like`, and
`build_batch_inserts` (row-at-a-time -> chunked multi-row VALUES, with per-engine `MAX_BIND_PARAMS`).

A key architectural divergence: Python, PHP, and Node WIRE the translator into each adapter's execute/fetch
path; Ruby's drivers largely BYPASS it (see the register) and own their own dialect handling.

## Public surface contract

`SQLTranslator` static methods that take SQL (+ an engine string) and return transformed SQL, plus
`build_batch_inserts` and a `query_key`/cache-key hash. No instance state. Identifier quoting is deliberately
NOT here (it lives on each adapter); UPSERT/ON CONFLICT and date/time functions are deliberately NOT
translated (portability by omission).

## Inputs and outputs

- Input: canonical SQL, the target engine, and (for batch) the rows. Output: dialect SQL, or a collapsed
  multi-row INSERT, or a cache key.

## Lifecycle and operation graph

1. An adapter (or the ORM) calls the translator with the canonical SQL + its engine.
2. The translator applies the rules that engine needs (placeholders, limit shape, autoincrement, booleans,
   concat, ilike).
3. `build_batch_inserts` collapses a row-at-a-time INSERT into chunked VALUES, refusing to collapse anything
   containing `RETURNING`/`ON CONFLICT`/`ON DUPLICATE KEY`.

## Configuration and precedence

- No configuration. `MAX_BIND_PARAMS` per engine (sqlite 999, pg/mysql 65535, mssql 2100, firebird/odbc/mongo
  0 = never collapse) governs the batch chunking.

## Failures, side effects and security

- No side effects (pure string work). The risk is CORRECTNESS: a transform that emits invalid or wrong SQL
  for an engine the developer did not test. Two such bugs are universal (see the register). No SQL-injection
  surface of its own (parameters are bound by the adapters), except where an adapter string-inlines params
  (MongoDB/MSSQL in some languages - covered in their own packets).

## Wire and persistence contract

No persisted state. The contract is the dialect SQL it emits; the batch-collapse output must be semantically
identical to the row-at-a-time form.

## Providers and substitutability

The engine string selects the rule subset; adding an engine means adding its cases. No plugin abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SQLTRANS-CONCAT-MANGLE | UNIVERSAL correctness bug in all four: `concat_pipes_to_func`/`concatPipesToFunc` splits the ENTIRE statement on `||` and wraps the whole thing in `CONCAT(...)` - `SELECT a \|\| b FROM t` becomes `CONCAT(SELECT a, b FROM t)`, invalid SQL. It runs on EVERY MySQL/MSSQL statement in Python (`mysql.py:245`/`mssql.py:299`), PHP (`SQLTranslator.php:597`), and Node (`mysql.ts:132`/`mssql.ts:157`); in Ruby it is present but currently dead (unwired). Every language's test covers only the bare-expression case, so the bug is unguarded. | Rewrite the concat transform to operate on `\|\|` only OUTSIDE string literals and only within expression contexts (reuse the existing literal-scrubber - Python `_scrub_sql_text`, Node `scrubSqlText`), or drop it and require `CONCAT` in canonical SQL. Add a regression with a real `SELECT a \|\| b FROM t` asserting valid dialect SQL. Fix once, port to all four. |
| SQLTRANS-LITERAL-REWRITE | UNIVERSAL: `boolean_to_int` and `ilike_to_like` rewrite matches INSIDE string literals (`WHERE name = 'TRUE'` -> `'1'`), and `ilike_to_like`'s `\S+`/greedy capture truncates a multi-word LIKE pattern. None reuse the literal-scrubber the codebase already has. (Python's `named_to_positional` and PHP's `namedToPositional` DO skip literals - inconsistent within the same file.) | Route every literal-sensitive transform through the scrubber (mask literals/comments, transform, restore), matching the placeholder transform that already does it. |
| SQLTRANS-RUBY-UNWIRED | Ruby DIVERGES: 6 of 10 translator methods (`limit_to_rows`, `limit_to_top`, `concat_pipes_to_func`, `boolean_to_int`, `ilike_to_like`, `placeholder_style`) have ZERO runtime callers - the Ruby drivers each own their dialect handling (Firebird `SELECT FIRST/SKIP`, MSSQL `OFFSET/FETCH`, per-driver placeholders). Only `auto_increment_syntax` + `build_batch_inserts` are live, and `query_key` is duplicated in `cache.rb`. So Ruby's translator is largely vestigial, exercised only by its own unit specs. | Decide: either wire Ruby's drivers through the translator (parity with py/php/node, one dialect source) OR delete the dead methods and treat per-driver dialect handling as the Ruby design (and remove them from the shared "translator" contract). Do not leave a documented API that nothing calls. |
| SQLTRANS-DEAD-DUP | UNIVERSAL dead/duplicated code: `limit_to_top` is dead in Python (it uses OFFSET/FETCH) but live in PHP (TOP); `batch_last_id` has no caller (MySQL re-implements the first-id+rowcount math inline); Node's `placeholder_style` is dead (adapters roll their own `convertPlaceholders`). | Remove the dead methods or wire them; de-duplicate the batch-last-id math to the one helper. Note the MSSQL pagination DIVERGENCE (TOP vs OFFSET/FETCH) and pick one. |
| SQLTRANS-AUTOINC-BIGINT | The PostgreSQL autoincrement transform only special-cases `INTEGER PRIMARY KEY AUTOINCREMENT`; a `BIGINT ... AUTOINCREMENT` just has the keyword stripped, yielding a plain `BIGINT` with no sequence (no `BIGSERIAL`). Confirmed Python + PHP. | Handle BIGINT (and reordered DDL) in the autoincrement transform, or document that only `INTEGER PRIMARY KEY AUTOINCREMENT` is portable. |
| SQLTRANS-NO-UPSERT-DATETIME | No UPSERT/ON CONFLICT and no date/time-function translation in any language (portability by omission). The batch-collapse correctly REFUSES to collapse `RETURNING`/`ON CONFLICT`/`ON DUPLICATE` batches (good, all four). | Document the omission (CLAUDE.md already warns off `NOW()`/`GETDATE()`); consider a portable `upsert` helper if cross-engine upsert is wanted. No code change required. |
| SQLTRANS-TEST-COUNT | The CARBONAH report claims "SQL Translation: 54 tests" but the real counts are PHP 44 (or 59 with named-to-positional) and Ruby 42 - the tracker number matches nothing. Ties to the feature-133 CARBONAH-REPORT-INCONSISTENT finding. | Regenerate the report count from the real suites (see feature 133). No translator change. |

## Owner decisions

- SQLTRANS-DEC-01 (proposed): fix the concat mangle + the literal-rewrite (SQLTRANS-CONCAT-MANGLE +
  SQLTRANS-LITERAL-REWRITE) via the existing literal-scrubber, in all four, with real full-statement
  regressions. Highest value - these emit invalid/wrong SQL today.
- SQLTRANS-DEC-02 (proposed): resolve the Ruby unwiring and the dead/duplicated code (SQLTRANS-RUBY-UNWIRED +
  SQLTRANS-DEAD-DUP) - one dialect source per language, no dead public API, one MSSQL pagination strategy.
- SQLTRANS-DEC-03 (proposed, low): BIGINT autoincrement + document the UPSERT/date-time omission.

## Implementation (3.13.99) - RATIFIED + SHIPPED

Proven by `fixtures/sqltranslator_contract.json` (2 invariants, proven all four against real MySQL +
PostgreSQL, no mocks, mutation-proved). See CONTRACT-MAP.md.

- **SQLTRANS-DEC-01 (data-corruption fix, all four).** concat/bool/ilike are now LITERAL-SAFE: each masks
  string literals / quoted identifiers / comments to opaque tokens, rewrites the masked SQL, then restores
  the tokens (Python `SQLTranslator._mask_literals`, PHP `maskLiterals`, Ruby `mask_literals`, Node
  `maskLiterals`). concat rewrites ONLY the `||` operand chain, never the whole statement, so
  `SELECT a || b FROM t` -> `SELECT CONCAT(a, b) FROM t` and `WHERE data = 'a||b'` is left untouched. The
  multi-word ILIKE pattern that the old greedy `\S+` truncated now survives whole.
- **SQLTRANS-DEC-02 (Ruby unwiring + dead code).** concat/ilike are WIRED into the MySQL query path in Ruby
  (`Drivers::MysqlDriver#translate_dialect`, called from `execute_query`/`execute`) and PHP
  (`MySQLAdapter::translateDialect`, called from `query`/`execute`), matching the already-wired Python
  (`_translate_sql`) and Node (`translateSql`) adapters - so a portable `||`/`ILIKE` query RUNS on real
  MySQL in all four. Ruby's dead-and-wrong `limit_to_rows`, `limit_to_top`, `placeholder_style` were
  DELETED (the Ruby drivers own pagination via `SELECT FIRST/SKIP` + `OFFSET ... FETCH` and placeholders
  via `?`/`$1`; the translator helpers emitted an inferior shape that nothing called), and the duplicate
  `SQLTranslator.query_key` was removed (the live `Tina4::QueryCache.query_key` is the single source). The
  MSSQL-pagination unification named in SQLTRANS-DEAD-DUP (Node `TOP` vs the drivers' `OFFSET/FETCH`) is a
  larger cross-cutting change and is NOT bundled here - it stays a tracked follow-up so this feature stays
  shippable and verified. Firebird/MSSQL wiring for PHP/Ruby (parity with Python/Node's existing wiring)
  is likewise a follow-up: the fix + the fixture are engine-agnostic and MySQL+PostgreSQL exercise every
  code path.
- **SQLTRANS-DEC-03 (BIGINT autoincrement + documented omissions).** `BIGINT PRIMARY KEY AUTOINCREMENT`
  now translates to a real 64-bit auto-increment column: PostgreSQL `BIGSERIAL`, MySQL
  `BIGINT ... AUTO_INCREMENT`, MSSQL `BIGINT ... IDENTITY(1,1)` (INTEGER stays `SERIAL` / `INT AUTO_INCREMENT`
  / `INT IDENTITY`). Before the fix the PostgreSQL branch matched only `INTEGER PRIMARY KEY AUTOINCREMENT`
  and a BIGINT merely had the keyword stripped, leaving a plain BIGINT primary key with no sequence.

  **UPSERT and date/time functions are deliberately NOT translated (portability by omission).** There is
  no `ON CONFLICT` / `ON DUPLICATE KEY` / `MERGE` translation and no `NOW()`/`GETDATE()`/`CURRENT_TIMESTAMP`
  translation in any language - the shapes differ too much across engines to translate safely, and the
  batch-collapse correctly REFUSES to collapse a `RETURNING`/`ON CONFLICT`/`ON DUPLICATE` batch (all four).
  Portable app code writes engine-neutral SQL and reaches for a per-engine escape hatch (or a future
  dedicated `upsert` helper) when it needs conflict handling; CLAUDE.md already warns app authors off
  `NOW()`/`GETDATE()` in migrations. This omission is intentional and requires no code change.

## Proposed conformance fixture

A shared per-language fixture (the pure-function tests already exist - extend them): assert
`SELECT a \|\| b FROM t` translates to VALID MySQL/MSSQL (catches the concat mangle); a boolean/ilike inside a
string literal is NOT rewritten; a multi-word ILIKE pattern survives; `BIGINT ... AUTOINCREMENT` yields a
sequence-backed column; and the batch-collapse output is semantically identical to the row-at-a-time INSERT
and refuses RETURNING/ON CONFLICT. Run the same fixture across all four so the dialect output matches.

## Integration map

- Consumers: the six providers (9-14) via their `translate`/`_translate_sql`, the batch-insert path, and the
  ORM `create_table` DDL (autoincrement). Related: the query-cache key (feature 25) reuses the hash.

## Breaking changes and migration

- Fixing the concat/literal transforms changes the emitted SQL for statements that were previously mangled -
  those were producing invalid SQL, so this is a correctness fix; document it. Removing dead methods is
  internal. Choosing one MSSQL pagination strategy may change generated SQL for MSSQL - document it.

## Implementation backlog

1. SQLTRANS-DEC-01: literal-safe concat + bool/ilike, all four, with full-statement regressions.
2. SQLTRANS-DEC-02: Ruby wiring decision + dead-code removal + one MSSQL pagination strategy.
3. SQLTRANS-DEC-03: BIGINT autoincrement; document UPSERT/date-time omission; fix the report count.

## Porting capsule

A clean-room translator needs literal-safe transforms (mask string literals + comments before any regex
rewrite - the codebase already has the scrubber; USE it for every transform), a single wiring model (every
adapter goes through the translator, or none do - do not ship dead public methods), one MSSQL pagination
strategy, autoincrement that handles BIGINT, and a batch-collapse that refuses RETURNING/ON CONFLICT/ON
DUPLICATE. Test with FULL statements, not bare expressions - the concat bug hides behind expression-only
tests in all four today.

## Audit closure checklist

- [x] Boundary and public surface complete (the transform set x four).
- [x] Lifecycle and every producer/consumer edge complete (adapters, batch, DDL).
- [x] Configuration, failure (correctness) and security rules complete.
- [x] Wire (dialect SQL) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (concat mangle universal, Ruby unwired, MSSQL
  pagination).
- [x] Owner ambiguities decided and recorded (SQLTRANS-DEC-01..03).
- [x] Proposed conformance fixture (full-statement) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
