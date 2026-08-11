# Feature 24: Paginated database and ORM results

## Identity and status

- Matrix identity: 24 - Paginated database and ORM results (`tina4_python/database/__init__.py`;
  `tina4_python/orm/model.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, STRONG parity (ADR-0043 7-key envelope), one page-clamp divergence.
  Measured 2026-08-11. Python `database/adapter.py:266` `to_paginate` (`ebbab30`); PHP
  `Tina4/Database/DatabaseResult.php:314` (`6faabac5`); Ruby `lib/tina4/database_result.rb:132` (`6d5b1de`);
  Node `packages/orm/src/databaseResult.ts:129` (`27cf0f4`).
- Dependencies: the DB facade `fetch` (LIMIT/OFFSET pushdown + COUNT probe), AutoCrud (27).
- Dependants: every paginated list; the AutoCrud REST list.
- Existing ADRs: ADR-0043 (the canonical 7-key list envelope).

- Catalog phase: database / ORM

## Why this feature exists

A REST list needs a consistent, honest pagination envelope: the rows, the TRUE total (not the page size), the
page math, all pushed down to the DB. ADR-0043 fixed the shape to 7 keys after a bug where in-memory
re-slicing lied about `total_pages`.

## Existing implementation evidence

Universal, and exactly to ADR-0043 in all four:

- `to_paginate()` returns the 7 keys `records, total, page, per_page, total_pages, limit, offset` (with
  `limit == per_page`), never re-slicing `records`. `total` is the query's TRUE COUNT probe (`SELECT COUNT(*)
  FROM (sql)`), never `len(records)`.
- DB-LEVEL pushdown: `db.fetch(sql, params, limit, offset)` applies engine LIMIT/OFFSET and runs the COUNT
  probe. Pagination is not in-memory.
- `to_paginate()` takes NO arguments - any argument raises (the issue-#106 fix that removed the lying
  in-memory re-slice). ORM model reads return plain arrays; the envelope is a `DatabaseResult`/AutoCrud
  concept.

Divergence: `page < 1` handling (see the register).

## Public surface contract

`result.to_paginate()` -> the 7-key envelope. The AutoCrud list handler builds it from `?page`/`?per_page`/
`?limit`/`?offset`. Contract: `total` is a true COUNT, `records` is never re-sliced, and the envelope shape is
exactly ADR-0043.

## Inputs and outputs

- Input: a `DatabaseResult` (rows + count + limit + offset). Output: the 7-key dict/object.

## Lifecycle and operation graph

1. `db.fetch` runs the limited SQL + a COUNT probe -> a `DatabaseResult`.
2. `to_paginate()` derives page/per_page/total_pages from count/limit/offset (no re-slice).

## Configuration and precedence

- The list handler reads `?page`/`?per_page`/`?limit`/`?offset` (+ `?filter[]`/`?sort`); default per_page/limit
  10.

## Failures, side effects and security

- No security surface of its own. The risk is `page < 1` producing a negative offset (see the register) and an
  uncapped `?limit` (Node).

## Wire and persistence contract

The 7-key envelope IS the wire contract (ADR-0043); `total` is the DB COUNT.

## Providers and substitutability

The LIMIT/OFFSET pushdown is per-engine (feature 9-14); `to_paginate` only describes.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| PAGE-NEGATIVE-OFFSET | `page < 1` is NOT clamped in Python, Ruby, and Node: `offset = (page - 1) * per_page`, so `page=0` yields a NEGATIVE offset handed to the driver - which ERRORS on PostgreSQL and is silently treated as 0 on SQLite (a portability footgun), and the envelope can report `page: 0`. PHP alone CLAMPS `page <= 1` to offset 0. | Clamp `page` to `>= 1` (and `offset >= 0`) in the list handler in Python/Ruby/Node, matching PHP. |
| PAGE-NO-MAX-LIMIT | Node's AutoCrud list honours `?limit=1000000` verbatim - no maximum-page-size cap - so a client can request the whole table in one query (a resource footgun). | Cap the per-page size (a sane max) in the list handler; confirm the other three. |
| PAGE-LIMIT-EQ-PERPAGE | The envelope ships `limit == per_page` (the same integer under two keys) in all four - which contradicts Ruby's own file comment ("the same integer never ships twice under two names"). It is the ADR-0043 shape, but the redundancy is intentional-yet-self-contradicting per the doc. | Cosmetic: reconcile the doc comment with the ADR-0043 shape (both keys are intended); no behaviour change. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- PAGE-DEC-01 (proposed): clamp `page >= 1` in Python/Ruby/Node (PAGE-NEGATIVE-OFFSET) - the real bug (a PG
  500 / silent-wrong on SQLite) - and cap the max per-page size (PAGE-NO-MAX-LIMIT).

## Proposed conformance fixture

The shared pagination fixture (real DB, already strong - 250 rows, page N, true COUNT, exact 7 keys, raises on
any `to_paginate` arg). Add: `page=0` returns page 1 (clamped, not a negative offset); `?limit=huge` is capped.

## Integration map

- Consumers: the AutoCrud list (27), any paginated finder. Composes: the DB pushdown (9-14), the DatabaseResult
  (feature 5).

## Breaking changes and migration

- Clamping `page` changes behaviour only for `page < 1` (previously a driver error / silent-wrong) - a
  correctness fix. Capping the limit changes behaviour for over-large requests - document it.

## Porting capsule

Pagination needs: DB-LEVEL LIMIT/OFFSET pushdown with a TRUE COUNT probe for `total` (never `len(records)`); a
`to_paginate()` that returns exactly the ADR-0043 7 keys and NEVER re-slices in memory (raise on any argument
- the lying-envelope bug); `page` clamped to `>= 1` (no negative offset - a PG error / silent-wrong on
SQLite); and a maximum per-page cap so a client cannot request the whole table.

## Audit closure checklist

- [x] Boundary and public surface complete (the 7-key envelope x four).
- [x] Lifecycle and producer/consumer edges complete (fetch -> count probe -> derive).
- [x] Configuration, failure (negative offset) and security rules complete.
- [x] Wire (ADR-0043 7 keys) and provider (pushdown) contracts complete.
- [x] Four-language behaviour recorded (strong parity; page-clamp divergence).
- [x] Owner ambiguities decided (PAGE-DEC-01).
- [x] Conformance fixture (page=0, max-limit) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
