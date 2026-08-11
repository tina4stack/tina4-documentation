# Feature 14: MongoDB SQL-translation provider

## Identity and status

- Matrix identity: 14 - MongoDB SQL-translation provider (`tina4_python/database/mongodb.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, PARTIAL, with a UNIVERSAL data-integrity risk and ZERO functional test
  coverage in all four. Measured 2026-08-11. Python `database/mongodb.py` (765 lines, `ebbab30`); PHP
  `MongoDBAdapter.php` (1282 lines, `6faabac5`); Ruby `lib/tina4/drivers/mongodb_driver.rb` (577 lines,
  `6d5b1de`); Node `packages/orm/src/adapters/mongodb.ts` (`27cf0f4`).
- Dependencies: the driver - `pymongo` (Python); `ext-mongodb` + the `mongodb/mongodb` library (PHP); `mongo`
  gem (Ruby); `mongodb` npm (Node) - OPTIONAL + lazy.
- Dependants: apps addressing MongoDB through SQL (the SQL-over-documents bridge).
- Existing ADRs: none.

- Catalog phase: database

## Why this feature exists

The MongoDB provider lets SQL-oriented app/ORM code target a document store: it translates a SQL subset into
MongoDB queries. That translation is a hand-rolled regex parser in every language (it does NOT use the shared
`SQLTranslator`), and it is where the danger lives - a parser that quietly guesses is a parser that quietly
loses data.

## Existing implementation evidence

Partial in all four, each a bespoke SQL->Mongo translator (~400-770 lines): SELECT (WHERE, ORDER BY, LIMIT,
OFFSET, projection), INSERT/UPDATE/DELETE, CREATE/DROP TABLE->collection. Supported WHERE ops:
`= != <> > >= < <= LIKE/ILIKE IN/NOT IN IS [NOT] NULL AND` (and OR in some). What is missing/dangerous is the
story:

- ZERO functional tests of the parse/CRUD path in ANY language - the ~400-770-line translator is unexercised
  everywhere (the real-Mongo tests that exist are for the QUEUE/SESSION/docstore backends, different code
  paths). Excluded from every adapter-contract ratchet.
- last-insert-id is the Mongo `_id` STRING, not the integer `id` the other engines return (all four); Node
  DROPS `insertedId` entirely (`lastId: undefined`).
- Transactions require a replica set; on a standalone `mongod` they break or no-op (Ruby STUBS
  begin/commit/rollback as empty methods - NO atomicity; Python's `execute_many` opens a txn and thus RAISES
  on standalone).
- No JOIN, no GROUP BY/HAVING, no aggregate functions (COUNT/SUM/MAX yield `[]` in Node/Ruby).
- Driver OPTIONAL + lazy in all four; PHP's guard is INSUFFICIENT (checks `extension_loaded('mongodb')` but
  needs the `\MongoDB\Client` LIBRARY, which is `require-dev` only -> a production `--no-dev` install fatals).

## Public surface contract

`Database("mongodb://...")` -> SQL executed against collections. The contract is weakly held: unsupported SQL
does not error, it guesses (see the register), and the last-id/transaction contracts differ from the SQL
engines.

## Inputs and outputs

- Input: a `mongodb://` URL, a SQL string. Output: documents (as rows), a Mongo `_id` last-id, or - on an
  input the parser cannot handle - a SILENT wrong result (see the register).

## Lifecycle and operation graph

1. Lazy-import the driver; connect (background-dialing client with a connect timeout).
2. Regex-parse the SQL into a Mongo filter/update/pipeline.
3. Execute against the collection; return documents. Unsupported SQL is silently no-op'd or match-all'd (the
   danger).

## Configuration and precedence

- The `mongodb://` (or `pymongo://`) URL. No SQL translation config.

## Failures, side effects and security

- THE data-integrity risk (see the register): an unparseable/unsupported WHERE does not raise - it becomes a
  match-all or a silent no-op, reaching `update_many`/`delete_many`. Combined with zero tests, this is the
  most dangerous provider in the band. Parameters are string-inlined (PHP), an injection surface on the SQL
  path.

## Wire and persistence contract

MongoDB wire via the driver. The "SQL" is a lossy regex projection onto Mongo operators - NOT a faithful SQL
engine. last-id is an ObjectId string.

## Providers and substitutability

One translator per language; no fallback. It is a bridge, not a first-class SQL engine.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| MONGO-MASSWRITE | UNIVERSAL data-integrity risk. An unparseable/unsupported WHERE does not fail - it becomes a match-all or a silent success: Python's `_parse_condition` falls back to `{}` and reaches `update_many({})`/`delete_many({})` (`mongodb.py:217`->`:490`/`:508`) = MASS UPDATE/DELETE of the whole collection; Node SILENTLY returns `{acknowledged:true}`/`[]` on unsupported SQL (`mongodb.ts:353`); Ruby's UPDATE is ALWAYS `update_many`+`$set` (`:73`, never scoped narrower); PHP string-inlines. No test guards any of it. | Make the parser FAIL CLOSED: an unparseable or unsupported WHERE must RAISE, never default to `{}`/match-all/no-op. A DELETE/UPDATE with an empty resolved filter must be rejected unless an explicit "all" is requested. This is the single highest-value fix in the whole DB band (silent data loss). |
| MONGO-ZERO-TESTS | UNIVERSAL: the ~400-770-line parse/CRUD path has ZERO functional tests in any language and is excluded from every adapter-contract ratchet. The provider's core behaviour is entirely unproven. | Add a real-Mongo conformance fixture (below) driving SQL through the adapter; put it in the require-services gate. |
| MONGO-NO-ATOMICITY | Transactions require a replica set; Ruby STUBS begin/commit/rollback as no-ops (no atomicity), Python's `execute_many` RAISES on standalone. So multi-statement writes are non-atomic or broken on a standalone `mongod`. | Detect standalone vs replica-set and either require a replica set for transactional writes (fail loud) or document that writes are non-atomic on standalone - not silently no-op the transaction. |
| MONGO-LASTID | last-id is the ObjectId STRING, not the integer `id` other engines return (all four); Node drops `insertedId` (`lastId: undefined`). Breaks the cross-engine last-id contract. | Return a consistent last-id (the ObjectId is legitimate for Mongo - document it as the contract) and do NOT drop it (Node). |
| MONGO-PHP-GUARD | PHP's driver guard checks `extension_loaded('mongodb')` but the code needs the `\MongoDB\Client` LIBRARY (`require-dev` only) -> a production `--no-dev` install passes the guard then fatals "Class not found". | Guard on `class_exists(\MongoDB\Client::class)`; declare the library as a runtime `suggest`/optional-require, not `require-dev`. |
| MONGO-INJECTION | PHP string-inlines params with backslash-escaping (`MongoDBAdapter.php:1058`), not the SQL-standard doubling and not real binding - a correctness/injection surface on the SQL path. Ruby similarly escapes `'`->`\\'` then re-parses (round-trip corruption of values containing quotes). | Bind values into the Mongo filter as native types (Mongo has no SQL injection - build the filter document directly from parsed values), never string-inline. |

## Owner decisions

- MONGO-DEC-01 (proposed): make the parser FAIL CLOSED (MONGO-MASSWRITE) - an unparseable WHERE raises, an
  empty-filter DELETE/UPDATE is rejected. This prevents silent mass data loss and is the top DB-band fix.
- MONGO-DEC-02 (proposed): add the real-Mongo conformance fixture and gate it (MONGO-ZERO-TESTS) - which
  would have caught MONGO-MASSWRITE.
- MONGO-DEC-03 (proposed): fix transactions/atomicity (MONGO-NO-ATOMICITY), the last-id contract
  (MONGO-LASTID), the PHP guard (MONGO-PHP-GUARD), and native-filter binding (MONGO-INJECTION).

## Proposed conformance fixture

A real MongoDB (require-services-gated, no mocks): SELECT with each supported WHERE op returns the right
docs; an UNSUPPORTED/unparseable WHERE RAISES (catches MONGO-MASSWRITE) rather than match-all/no-op; a
scoped UPDATE/DELETE touches only matching docs (and an empty-filter DELETE is rejected); an insert returns a
stable last-id; a multi-statement write is atomic on a replica set (and fails loud, not silently, on
standalone); a value containing a quote round-trips intact. Run it in CI against a real Mongo.

## Integration map

- Consumers: the ORM/Database facade for apps on MongoDB. Related: the SQL translator (feature 7 - NOT used
  here; this provider has its own parser), feature 4 (the write guard), and the Mongo queue/session backends
  (different code paths, already tested).

## Breaking changes and migration

- Making the parser fail-closed changes behaviour: SQL that silently match-all'd or no-op'd now raises - a
  correctness/safety fix that could surface latent app bugs; document it clearly (it prevents data loss).

## Implementation backlog

1. MONGO-DEC-01: fail-closed parser + empty-filter rejection, all four, with the mass-write regression.
2. MONGO-DEC-02: the real-Mongo conformance fixture in the require-services gate.
3. MONGO-DEC-03: atomicity/standalone handling; last-id contract; PHP guard; native-filter binding.

## Porting capsule

A MongoDB SQL provider needs: a lazy/optional driver with a guard on the actual client CLASS (not just the
extension); a SQL-subset parser that FAILS CLOSED - an unparseable or unsupported WHERE RAISES and an
empty-filter UPDATE/DELETE is rejected (never `{}`/match-all/silent-no-op - that is silent data loss);
native-type filter binding (never string-inlining); a documented last-id contract (the ObjectId, not
dropped); transactions that require a replica set and fail loud on standalone (never a silent no-op); and a
REAL-Mongo conformance fixture in CI - the thing all four lack, which is exactly why they ship dangerous.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure (data-integrity) and security rules complete.
- [x] Wire/type contracts complete (regex projection; ObjectId last-id).
- [x] Four-language behaviour recorded (universal mass-write risk + zero tests; per-lang variants).
- [x] Owner ambiguities decided (MONGO-DEC-01..03).
- [x] Conformance fixture (real Mongo, fail-closed) recorded.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
