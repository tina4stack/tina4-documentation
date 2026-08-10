# Feature 007: SQL translator

## Identity and status

- Matrix identity: 7 - SQL translator
- Audit state: decision-ready
- Dependencies: Feature 3 - Database adapter interface; Feature 6 - Query builder
- Dependants: Features 8-14 database providers, Feature 15 migrations, Feature 17 ORM
  base class, Feature 24 paginated results
- Existing ADRs: ADR-0044 governs batch and first-row execution as adapter primitives;
  no SQL-translator-specific ADR exists
- Shared fixtures: `batch_write_contract.json` (byte-identical in all four); a SQL
  translation fixture is required
- Catalog phase: Database and providers
- Audit note: measured from four-language source; no framework code changed

## Why this feature exists

The translator gives every database provider one small set of stateless SQL rewrites so
dialect rules live in exactly one place instead of being copied into each provider and
into application queries. A provider calls the rules its dialect needs; the rules are
pure string and parameter transforms with no database contact.

## Boundary

Feature 7 owns the shared dialect rewrites, the engine-alias table, the per-engine
bind-parameter ceilings, the safe multi-row batch-insert construction, and the
generated-id normalization that collapsing a batch requires. It owns pagination
rewriting (LIMIT to Firebird `ROWS` and MSSQL `TOP`), placeholder-style conversion,
`||` concatenation, boolean literals, `ILIKE` and `AUTOINCREMENT` DDL.

Feature 6 constructs the query. Feature 3 executes it. Each provider decides which
rewrites its dialect needs and owns its own identifier quoting (`quote_identifier` stays
on the adapter, because quoting genuinely differs per engine and a shared version would
flatten the Firebird override). Query result caching is NOT a translation concern and is
owned by the cache feature, not by this module.

The translator holds no state and performs no I/O. Every rule is a pure function of its
input, so the rules are checkable without a database and the live-engine runners prove
the rewritten SQL still lands correctly.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | `tina4_python/database/sql_translator.py` | `Tina4/SQLTranslator.php` | `lib/tina4/sql_translator.rb` | `packages/orm/src/sqlTranslator.ts` |
| Core rewrites | 7 static methods | 7 static methods | 7 module methods | 7 static methods |
| Batch machinery | `build_batch_inserts`, `batch_last_id` | `buildBatchInserts`, `batchLastId` | `build_batch_inserts`, `batch_last_id` | `buildBatchInserts`, `batchLastId` |
| Shared constants | `MAX_BIND_PARAMS`, `ENGINE_ALIASES`, `FIRST_ID_ENGINES` | same three | same three | same three |
| RETURNING inspection | batch guard only | `hasReturning` + `extractReturning` | batch guard only | `parseReturning` |
| Named -> positional | no | `namedToPositional` | no | no |
| Dialect dispatcher | no | `translate(sql, dialect)` | no | no |
| Function-mapping registry | no | `registerFunction`/`applyFunctionMappings` | no | no |
| Query cache in this module | re-exports `Cache` as `QueryCache` | full cache (get/set/remember/sweep/clear/size/ttl) | `query_key` only | a `QueryCache` class in the same file |
| Existing focused tests | `tests/test_sql_translation.py` | `tests/SQLTranslatorTest.php` | `spec/sql_translator_spec.rb` | `test/sqlTranslator.test.ts` |

The core rewrites and the batch machinery are aligned. The three constants agree because
the byte-identical `batch_write_contract.json` fixture is their source: `MAX_BIND_PARAMS`
is sqlite 999, postgres 65535, mysql 65535, mssql 2100, and 0 (never collapse) for
firebird, odbc and mongodb; `ENGINE_ALIASES` maps postgresql/pgsql to postgres, sqlite3
to sqlite, sqlserver/sqlsrv to mssql and mariadb to mysql; `FIRST_ID_ENGINES` is mysql
alone. `batch_last_id` exists because a single multi-row INSERT reports the FIRST
generated id on MySQL while a row-at-a-time loop reported the last; verified live (a
3-row insert reports 1 while `MAX(id)` is 3), and the ids are consecutive so the last is
`first + rows - 1`.

The surface above the core is where the four diverge, and the divergence is the audit.

## Public surface contract

Every language exposes the same core rewrites and batch machinery. Names are idiomatic;
behavior is identical. Each takes SQL (and where noted an engine name or style) and
returns rewritten SQL or a batch plan; none touches a database.

| Neutral operation | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| LIMIT/OFFSET -> Firebird ROWS | `limit_to_rows(sql)` | `limitToRows($sql)` | `limit_to_rows(sql)` | `limitToRows(sql)` |
| LIMIT -> MSSQL TOP | `limit_to_top(sql)` | `limitToTop($sql)` | `limit_to_top(sql)` | `limitToTop(sql)` |
| `\|\|` -> CONCAT() | `concat_pipes_to_func(sql)` | `concatPipesToFunc($sql)` | `concat_pipes_to_func(sql)` | `concatPipesToFunc(sql)` |
| TRUE/FALSE -> 1/0 | `boolean_to_int(sql)` | `booleanToInt($sql)` | `boolean_to_int(sql)` | `booleanToInt(sql)` |
| ILIKE -> LOWER LIKE LOWER | `ilike_to_like(sql)` | `ilikeToLike($sql)` | `ilike_to_like(sql)` | `ilikeToLike(sql)` |
| AUTOINCREMENT per engine | `auto_increment_syntax(sql, engine)` | `autoIncrementSyntax($sql, $dialect)` | `auto_increment_syntax(sql, engine)` | `autoIncrementSyntax(sql, engine)` |
| `?` -> engine placeholder | `placeholder_style(sql, style)` | `placeholderStyle($sql, $style)` | `placeholder_style(sql, style)` | `placeholderStyle(sql, style)` |
| Collapse INSERT batch | `build_batch_inserts(sql, rows, engine)` | `buildBatchInserts(...)` | `build_batch_inserts(...)` | `buildBatchInserts(...)` |
| Normalize batch last id | `batch_last_id(id, rows, engine)` | `batchLastId(...)` | `batch_last_id(...)` | `batchLastId(...)` |
| Bind-param ceiling | `MAX_BIND_PARAMS` | `MAX_BIND_PARAMS` | `MAX_BIND_PARAMS` | `MAX_BIND_PARAMS` |
| Engine aliases | `ENGINE_ALIASES` | `ENGINE_ALIASES` | `ENGINE_ALIASES` | `ENGINE_ALIASES` |
| First-id engines | `FIRST_ID_ENGINES` | `FIRST_ID_ENGINES` | `FIRST_ID_ENGINES` | `FIRST_ID_ENGINES` |

The methods that exist in only one or two ports are NOT yet contract and are decided
below: a RETURNING inspector (`extractReturning`/`parseReturning`), named-to-positional
conversion (`namedToPositional`), a dialect dispatcher (`translate`), and a
function-mapping registry (`registerFunction`). The embedded query cache is removed from
this module entirely.

## Inputs and outputs

- Input is a SQL string with `?` placeholders and, where the rule needs it, a native
  engine name or a placeholder style. Rewrites preserve every caller fragment verbatim
  except the specific token they translate.
- `placeholder_style` accepts `?` (unchanged), `%s` (MySQL/PostgreSQL) or a `:` prefix
  (numbered `:1, :2, ...` for Firebird/Oracle). Placeholder order is preserved exactly.
- `build_batch_inserts(sql, rows, engine)` returns a list of `(sql, params)` statements
  to run instead of the per-row loop, or an EMPTY list meaning "not collapsible, keep
  looping". Empty is always a correct answer, so anything unrecognized falls back to the
  existing loop rather than guessing.
- `batch_last_id(reported_id, rows_in_chunk, engine)` returns the LAST row's id, adjusting
  only on `FIRST_ID_ENGINES`.
- Engine names are normalized through `ENGINE_ALIASES` before any cap or first-id lookup;
  without this, a provider reporting `postgresql` misses the `postgres` cap and the
  collapse silently does nothing on the engine with the largest win.

## Lifecycle and operation graph

1. A provider or the batch-write path receives constructed SQL and native parameters.
2. It normalizes the engine name through `ENGINE_ALIASES`.
3. It applies the rewrites its dialect needs (Firebird `ROWS`, MSSQL `TOP`, boolean and
   `||` and `ILIKE` where the engine lacks them, DDL `AUTOINCREMENT` on create-table).
4. It converts placeholders to the engine style.
5. For a multi-row INSERT it calls `build_batch_inserts`; a non-empty result replaces the
   loop, and after execution `batch_last_id` restores the last-row id contract.
6. The rewritten SQL and parameters go to Feature 3 for execution. The translator keeps
   no state between calls.

The rules compose in any order that a dialect needs; they are individually idempotent on
already-correct SQL (a statement with no LIMIT is returned unchanged).

## Configuration and precedence

The translator reads no environment variables or project files. Its only tables are the
three shared constants, which are code, not configuration:

- `MAX_BIND_PARAMS` sets the hard per-statement bind ceiling per engine. Zero means
  "never collapse a batch on this engine" (Firebird has no multi-row VALUES; ODBC's real
  ceiling depends on the driver behind it, so emitting SQL it cannot parse to save a
  round-trip is not a trade worth making).
- `ENGINE_ALIASES` is the single source of engine-name normalization; a provider must
  route its self-reported name through it before any lookup.
- `FIRST_ID_ENGINES` lists the engines whose multi-row INSERT reports the first generated
  id. A provider override may extend a rewrite, but must not fork these tables.

## Failures, side effects and security

Translation must reject or decline rather than change a statement's meaning:

- `build_batch_inserts` returns empty (declines to collapse) when the statement carries
  `RETURNING`, `ON CONFLICT` or `ON DUPLICATE KEY` (a collapsed statement returns N rows
  where the caller expects one, and conflict arbitration changes once rows share a
  statement), when any VALUES slot is not a bare `?` (a `now()` repeated inside one
  statement is not the same write as `now()` evaluated per statement), when row widths
  disagree, or when the per-chunk row count would be below two.
- Rewrites operate on trusted SQL fragments and never quote or reinterpret a value;
  values stay in bound parameters.
- `concat_pipes_to_func` must not corrupt a string literal that itself contains `||`; the
  current naive split is a defect (SQLT-06). No rule may split, drop or reorder text
  inside a quoted literal or a comment.
- The module performs no I/O, opens no connection and logs nothing; a translation error
  surfaces to the calling provider, which owns the failure.

## Wire and persistence contract

The output is executable SQL plus native parameters in unchanged order. `WHERE`
parameters precede `HAVING` parameters, and a batch chunk flattens its rows' parameters
in row order. A placeholder-style conversion changes the placeholder token only, never
the count or order of parameters. A collapsed batch produces one statement per chunk of
`floor(cap / columns)` rows, each carrying that chunk's flattened parameters.

## Providers and substitutability

Every SQL provider applies the same shared rule where its dialect needs that rule and
supplies its own identifier quoting. A provider may not reimplement a rewrite locally or
carry its own copy of the three constants. A future engine adds its cap, aliases and any
needed rewrite to the shared tables rather than to provider code. The MongoDB provider
consumes none of these SQL rewrites; it translates through Feature 6's `toMongo`.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| SQLT-01 | A query cache is embedded in the SQL translator, differently in each port: PHP carries a full cache (`setCacheTtl`/`cacheGet`/`cacheSet`/`remember`/`cacheSweep`/`cacheClear`/`cacheSize`), Node ships a `QueryCache` class in the same file, Python re-exports the core `Cache`, Ruby exposes only `query_key`. Caching is not a translation concern. | Remove caching from the translator; the cache feature owns it. Keep the translator stateless. |
| SQLT-02 | PHP exposes ~8 methods the others lack (`namedToPositional`, `hasReturning`, `extractReturning`, `registerFunction`, `applyFunctionMappings`, `clearFunctions`, `translate`), so the public surface is not parity. | Decide which belong to the contract; add to all four or remove from PHP. |
| SQLT-03 | RETURNING inspection diverges: PHP `hasReturning`/`extractReturning`, Node `parseReturning`, Python/Ruby have only the batch guard. | One canonical RETURNING helper in all four, or none exposed. |
| SQLT-04 | Named-to-positional parameter conversion is PHP-only, so named parameters are supported on one framework and not the others. | Decide named-parameter support: all four or none. |
| SQLT-05 | A `translate(sql, dialect)` dispatcher exists only in PHP; the other three require the provider to call individual rewrites. | Decide whether one dispatcher is the contract or providers compose rules explicitly. |
| SQLT-06 | `concat_pipes_to_func` splits on `\|\|` without protecting string literals, so a literal containing `\|\|` is mis-split. | Rewrite must be literal- and comment-safe; add adversarial fixtures. |
| SQLT-07 | The batch fixture is byte-identical, but the CORE rewrites (limit/top/concat/boolean/ilike/autoincrement/placeholder) have no shared fixture. | Add a SQL-translation fixture covering every rewrite with positive, negative and edge cases. |

## Owner decisions

The audit proposes these decisions as one contract:

1. The SQL translator is stateless string and parameter transforms. It holds no cache and
   no per-call state.
2. Query result caching leaves this module entirely and is owned by the cache feature.
   PHP's cache methods, Node's in-file `QueryCache` class and Python's `QueryCache`
   re-export are removed from the translator surface.
3. The shared contract is the seven core rewrites plus `build_batch_inserts`,
   `batch_last_id`, and the three constants `MAX_BIND_PARAMS`, `ENGINE_ALIASES`,
   `FIRST_ID_ENGINES`, byte-aligned across all four.
4. RETURNING inspection is one canonical helper (`parse_returning` returning the stripped
   SQL and the column list) in all four, replacing PHP's two-method and Node's
   single-method spellings.
5. Named-to-positional conversion becomes the contract in all four OR is removed from PHP.
   Given `?` is already the portable placeholder everywhere, the recommendation is to
   remove it unless a provider genuinely needs named binds.
6. A dialect dispatcher is NOT the contract: providers compose the specific rewrites they
   need, because a single `translate(dialect)` hides which rules ran and each provider
   already knows its dialect. PHP's `translate` is removed.
7. The function-mapping registry (`registerFunction`) is out of scope for 3.14; a custom
   SQL-function mapping is a later, ADR-gated extension, not a translator method that only
   one framework carries.
8. `concat_pipes_to_func` must never alter text inside a quoted string literal or comment.

## Proposed conformance fixture

Reuse `batch_write_contract.json` for the batch machinery and add
`sql_translation_contract.json` covering every core rewrite. Required positive cases:

- LIMIT and LIMIT/OFFSET to Firebird `ROWS a TO b`, and to MSSQL `TOP n`;
- `\|\|` concatenation to `CONCAT(...)`, including a literal that contains `\|\|`;
- TRUE/FALSE to 1/0 respecting word boundaries;
- ILIKE to `LOWER(col) LIKE LOWER(val)`;
- `AUTOINCREMENT` to `AUTO_INCREMENT` (mysql), `SERIAL` (postgres), `IDENTITY(1,1)`
  (mssql) and stripped (firebird);
- `?` to `%s` and to numbered `:1, :2` with order preserved;
- engine-alias normalization for every alias;
- batch collapse chunking at each engine cap and the `first + rows - 1` last-id.

Required negative and mutation-witness cases:

- a statement with no LIMIT/boolean/ILIKE returned unchanged (idempotent);
- batch declined for RETURNING, ON CONFLICT, ON DUPLICATE KEY, a non-`?` VALUES slot,
  ragged row widths and a below-two chunk;
- a `\|\|` inside a quoted literal left untouched;
- an aliased engine name resolving to the correct cap (the silent-miss regression);
- MySQL first-id normalization applied, and NOT applied on postgres/mssql/sqlite;
- removal of the query cache from the translator surface (mutation: a cache method
  reappearing on the translator fails the surface gate).

## Integration map

- Every SQL provider (Features 8-13) imports the rewrites its dialect needs and the three
  constants; none carries its own copy.
- The batch-write path in Feature 5 calls `build_batch_inserts` and `batch_last_id`.
- Feature 6 hands constructed SQL and parameters that these rules rewrite.
- Feature 15 migrations use `auto_increment_syntax` for cross-engine DDL.
- Feature 24 pagination relies on the `ROWS`/`TOP` rewrites for Firebird and MSSQL.
- The cache feature owns query caching that this module currently misplaces.
- Documentation and scaffolders reference the neutral rewrite names.

## Breaking changes and migration

- The query cache is removed from the SQL translator in all four; callers using
  `SQLTranslator.cacheGet`/`remember`/`QueryCache` move to the cache feature's API.
- PHP loses `translate`, `namedToPositional` (unless retained by decision 5), and the
  function-mapping registry from the translator surface.
- RETURNING inspection converges on `parse_returning`; callers of `hasReturning`/
  `extractReturning`/`parseReturning` adopt it.
- `concat_pipes_to_func` becomes literal-safe; a query that previously mis-translated a
  `\|\|` inside a literal now translates correctly.
- No application SQL changes; these are internal provider-facing corrections.

## Implementation backlog

1. Add `sql_translation_contract.json` and four thin runners for the core rewrites.
2. Remove query caching from the translator in all four; point callers at the cache
   feature.
3. Converge RETURNING inspection on one `parse_returning` helper.
4. Settle named-to-positional (remove or add-to-all) and remove the PHP-only `translate`
   dispatcher and function registry.
5. Make `concat_pipes_to_func` literal- and comment-safe with adversarial fixtures.
6. Confirm the three constants stay byte-aligned with `batch_write_contract.json`.
7. Run the fixture locally and on the root lab against every live engine.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a stateless module of pure SQL and parameter transforms. Provide the seven core
rewrites (Firebird `ROWS`, MSSQL `TOP`, `||` to `CONCAT`, boolean to int, ILIKE to
LOWER-LIKE, per-engine `AUTOINCREMENT`, placeholder style), the batch collapse and
last-id normalization, and the three shared constants byte-aligned with the fixture.
Normalize every engine name through `ENGINE_ALIASES` before any lookup. Never quote a
value, never alter text inside a literal or comment, and decline (return empty) rather
than change meaning. Hold no cache and no state. Prove the port with the shared fixture
and the live-engine batch runners; the runner adapts names only, never behavior.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities recorded (8 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
