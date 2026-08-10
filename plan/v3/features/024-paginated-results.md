# Feature 024: Paginated database and ORM results

## Identity and status

- Matrix identity: 24 - Paginated database and ORM results
- Audit state: decision-ready
- Audit note: measured 2026-07-30 and RE-MEASURED 2026-08-05 against a real 250-row table.
  The RE-OPENED section below is AUTHORITATIVE and supersedes the earlier SYNTHESISE verdict
  and its argument-form porting capsule. Prose sections completed 2026-08-10. No framework
  code changed.
- Dependencies: `DatabaseResult` in each framework, Feature 3 adapter (the COUNT probe),
  Feature 6 query builder (the limit/offset that define the page)
- Dependants: every REST/CRUD/ORM endpoint that returns a paginated envelope; tina4-js
  frontends that read the envelope; the REST/CRUD/ORM doc chapters in all four sections
- Existing ADRs: this feature FORCES the systemic row-cap decision (a paginate envelope is
  only honest if `total` is a true total) - one dedicated ADR spanning Features 5, 21, 22, 23,
  24; ADR-0043 already fixed the AutoCrud REST list envelope to a canonical key set
- Shared fixtures: `pagination_contract.json` is required; every case uses more rows than one
  page so the arithmetic and the honest-total are observable

## Why this feature exists

A developer fetches one page of a large result and gets back an envelope that says which page
it is, how many rows match in total, and how many pages there are - the same envelope, telling
the truth, in all four languages. Today the envelope diverges four ways and, worse, lies:
against a 250-row table, two of the four report `total = 20` because they count the returned
page instead of the whole result.

## Boundary

This feature owns the paginated envelope: `toPaginate()` on a `DatabaseResult`, the derived
`page`/`per_page`/`total_pages`, and the true `total`. It DELEGATES the actual read (the
`limit`/`offset` that define the page) to Feature 6 and the COUNT probe for `total` to Feature
3. It does NOT re-slice rows: the envelope reports the query that was run, it does not run a
new one. The row-cap that makes `total` honest is the systemic decision it shares with
Features 5, 21, 22 and 23.

## Existing implementation evidence

| Evidence (250-row table, limit=20 offset=40, i.e. page 3 of 13) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `page` reported | 1 (wrong) | 3 (correct) | 3 | 1 (wrong) |
| `total` reported | 250 (correct) | 250 (correct) | 20 (wrong) | 20 (wrong) |
| `total_pages` | 13 | 13 | 1 (wrong) | 2 (wrong) |
| records returned | 20 | 20 | 0 (wrong) | 10 (wrong) |
| `.count` source | COUNT probe (true) | COUNT probe (true) | rows returned | rows returned |
| `page` derived from offset | no (defaults 1) | YES (`floor(offset/limit)+1`) | yes | no (defaults 1) |
| key count | 10 | 10 | 12 (+has_next/prev) | 13 (+perPage) |
| Signature | `to_paginate(page, per_page)` | `toPaginate()` (no args) | `to_paginate(page:, per_page:)` | `toPaginate(page, perPage)` |

Only PHP is correct on all five values, because it derives every field from the result it
holds rather than from caller-supplied arguments. Ruby and Node populate `.count` (and thus
`total`) with the number of ROWS RETURNED, so the envelope launders a truncation into a fact.
Ruby and Node also re-slice `records` by the ABSOLUTE offset against an array that is already
just that page, so Ruby returns nothing (offset 40 into a 20-element array) and Node returns 10
of 20. Three duplicate key pairs (`records`/`data`, `total`/`count`, `total_pages`/`totalPages`)
are universal; Node alone adds a fourth page-size spelling (`perPage`).

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 6. **Planning only.**

**Status: CLOSED.** All four key sets enumerated by execution (2026-07-30). The
source reading undercounted Node by four keys and mis-read PHP twice; see
Outstanding below.

The matrix calls this row "standardized format". It is not standardized.

### Files

`DatabaseResult` in each framework:

| | path |
| --- | --- |
| python | `tina4_python/database/adapter.py` |
| php | `Tina4/Database/DatabaseResult.php` |
| ruby | `lib/tina4/database_result.rb` |
| node | `packages/orm/src/databaseResult.ts` |

## Public surface contract

`toPaginate()` takes NO arguments in all four (PHP's shape, promoted). It reports the query
that was already run: to read page 3, the caller FETCHES page 3 (`limit=20, offset=40`) and
calls `toPaginate()` on that `DatabaseResult`. An argument form is rejected: a `DatabaseResult`
holds no connection, so `to_paginate(page: 6)` could only re-slice rows already in memory and
would then report `total_pages = 13` for pages it can never reach. Passing an argument RAISES
(PHP silently swallows extra arguments today, which is exactly why the divergence survived a
release); this follows the audit's removed-parameter rule -- a hard error, never a silent
reinterpretation. The method name follows each language's convention (`to_paginate` /
`toPaginate`); the payload does not.

## Inputs and outputs

- Input: a `DatabaseResult` carrying the rows of one page plus the `limit`/`offset` that
  produced them, and a true `total` from a COUNT probe over the filter. No caller arguments.
- Output: the envelope below - `records`, `total`, `page`, `per_page`, `total_pages`,
  `limit`, `offset` - as snake_case JSON keys, identical in all four.
- `records` are the rows the query returned, VERBATIM, never re-sliced.
- `total` is the full matching count, never the page length and never a capped read.
- `page` is 1-based and derived (`floor(offset / limit) + 1`); `total_pages` is
  `ceil(total / per_page)`; `per_page` is the query's `limit`.

## Lifecycle and operation graph

1. The caller runs a query with a `limit` and `offset` for the desired page (Feature 6).
2. The `DatabaseResult` obtains the true `total` from a `COUNT(*)` over the same filter
   (Feature 3), independent of the returned page length.
3. `toPaginate()` derives `per_page` from the query's `limit`, `page` from
   `floor(offset / limit) + 1`, and `total_pages` from `ceil(total / per_page)`.
4. It returns the envelope with `records` verbatim; it never issues a second read and never
   re-slices the array it already holds.

## Configuration and precedence

- There is no argument and no environment variable: the envelope is a pure function of the
  `DatabaseResult`. This is the point - a pure function of the result cannot lie about it.
- The page size is whatever `limit` the caller applied; there is no separate default page
  size in the method, because the method does not run the query.
- `total`'s honesty depends on the systemic row-cap decision: the read feeding the result
  must be bounded ONLY by the page's `limit`, never by a hidden default cap.

## Failures, side effects and security

- `total` MUST come from a `COUNT(*)` over the filter, never from the length of the returned
  page and never from a capped read. Otherwise the envelope launders a truncation into a fact:
  a 250-row table read under a silent 100-cap reports `total = 100`, `total_pages = 5`, both
  wrong in a way that looks authoritative.
- `records` are returned verbatim; re-slicing by absolute offset (Ruby, Node) drops rows or
  returns none for a valid page.
- Passing an argument RAISES rather than being silently ignored.
- `toPaginate()` has no side effects: it reads the result and returns the envelope, touching
  no database (the COUNT probe happened at fetch time, not here).

## Wire and persistence contract

The envelope is the wire contract, and a JSON key is data, not a language surface - it does not
change spelling by host language. The canonical keys are snake_case in all four:

```
{
  "records":     [ ... ],   the rows the query returned, verbatim
  "total":       250,       the true matching total (COUNT probe), never rows returned
  "page":        3,         1-based, floor(offset / limit) + 1
  "per_page":    20,        the query's limit
  "total_pages": 13,        ceil(total / per_page)
  "limit":       20,        the SQL limit actually applied
  "offset":      40         the SQL offset actually applied
}
```

`data`, `count`, `totalPages`, `per_page`-vs-`perPage` and the other duplicate spellings are
DELETED from the payload. Whether `has_next`/`has_prev` join the canonical set is the one open
sub-decision below (they are pure derivations of `page` and `total_pages`).

## Providers and substitutability

The envelope is engine-agnostic: `toPaginate()` is arithmetic over a `DatabaseResult`, and the
`total` COUNT probe is a standard `SELECT COUNT(*)` any provider answers. The same page fetch
against any engine yields the same envelope.

## Contradictions and defects

### What differs

**D1. The signature differs four ways, including one that takes no arguments.**

| | signature | default page size |
| --- | --- | --- |
| python | `to_paginate(page: int = 1, per_page: int = 20)` | **20** |
| php | `toPaginate(): array` | **none - no arguments at all** |
| ruby | `to_paginate(page: nil, per_page: nil)` | **nil** |
| node | `toPaginate(page = 1, perPage = 10)` | **10** |

Four answers to "how many rows is a page": 20, unspecified, nil, 10. And PHP's
takes **no arguments**, so a caller cannot ask PHP for page 3 through this method at
all - the paginate call that works in the other three does not compile in PHP.

**D2. Python emits the same value under two spellings, in the wire format.**
Verified - 25 rows, `to_paginate()` with defaults:

```
keys -> ['count', 'data', 'limit', 'offset', 'page', 'per_page',
         'records', 'total', 'totalPages', 'total_pages']

count: 25   total: 25          <- same number, two keys
data: [...] records: [...]     <- same rows, two keys
totalPages: 2  total_pages: 2  <- same number, camelCase AND snake_case
```

Ten keys carrying seven distinct facts. `totalPages` and `total_pages` both appear in
a **Python** dict, which means the JSON an API returns has the same integer twice
under two spellings.

Node has the same disease with two of the three pairs: `records` and `data`, `total`
and `count`, plus `perPage`.

This is feature 16's alias sprawl again, and here it is worse. An alias method
(`to_assoc` for `to_dict`) is a developer-facing convenience that costs a line of
docs. A duplicated key is in **every API response**: it inflates the payload, and it
forces every consumer to guess which spelling is canonical. A client written against
`totalPages` breaks the day someone tidies the dict; a client written against
`total_pages` breaks the other day.

**D3. There is no agreed key set.** Python has ten keys, Node nine, PHP's grep
surfaced `total_pages`, Ruby's is unprobed. Nothing in the framework family declares
what a paginated response looks like, which is exactly what the matrix row claims
this feature provides.

### Verdict: SYNTHESISE

> SUPERSEDED by the RE-OPENED 2026-08-05 section at the end of this document. This verdict and
> its argument-form contract were formed before the envelope was measured for whether it tells
> the truth. The canonical contract is `toPaginate()` with NO arguments, PROMOTE PHP, `total`
> from a real `COUNT(*)`. The analysis below is retained as the record of how the finding
> evolved, not as the contract.

Decided on **correctness of the wire contract**.

Nobody wins. Python has the most complete data and the worst duplication. Node has
the same duplication with a different page size. PHP cannot paginate through its own
paginate method. Ruby defaults to nil, meaning the caller must always supply both.

All category 4. Nothing about a JSON key name is runtime-forced.

### Risks

- **Deleting `data`, `count`, `totalPages` and `perPage` is breaking for any API
  consumer**, including tina4-js frontends reading these envelopes. `Breaking:` entry
  plus a migration note listing every removed key and its replacement.
- **The doc blast radius is large** - the paginated shape appears in the REST, CRUD
  and ORM chapters of four doc sections. The docs pass ships in the same release or
  the First Principle is violated the moment this lands.
- **Node's page size change (10 to 20)** doubles the default payload. Worth stating
  in the release note; it is the right trade for consistency but it is a visible one.

## Owner decisions

Proposed for owner ratification (the RE-OPENED 2026-08-05 measurement is the authority; it
supersedes the earlier SYNTHESISE verdict retained below):

1. `toPaginate()` takes NO arguments in all four (PROMOTE PHP). The caller fetches the page it
   wants and paginates that result. An argument RAISES, never silently swallowed.
2. `total` is the true matching count from a `COUNT(*)` probe over the filter, in all four.
   Ruby and Node currently report rows-returned; fixing this reaches into the adapters and is
   BREAKING for anyone reading `.count` as a page-row count. This is the deep half and the
   reason this is a separate implementation pass, not a patch to four methods.
3. `page` is derived `floor(offset / limit) + 1`; `records` are verbatim, never re-sliced;
   `per_page` is the query's `limit`; `total_pages` is `ceil(total / per_page)`.
4. One canonical snake_case key set in the JSON payload: `records`, `total`, `page`,
   `per_page`, `total_pages`, `limit`, `offset`. Drop `data`, `count`, `totalPages`, `perPage`
   and every other duplicate spelling. This is BREAKING for any API consumer (including
   tina4-js frontends); the `Breaking:` entry names every removed key and its replacement, and
   the REST/CRUD/ORM doc chapters change in the SAME release.
5. OPEN sub-decision: whether `has_next`/`has_prev` (present in Ruby and Node) join the
   canonical set. They are pure derivations of `page` and `total_pages`. Recommendation: DROP
   them for a minimal, honest envelope (a client derives them trivially); the owner may keep
   them on the 2-of-4 precedent. Decide once so all four match.
6. This feature FORCES the systemic row-cap decision: take it as unbounded-by-default with
   pagination the only thing that limits rows, so `total` cannot be laundered. This is where
   the cap decision stops being a preference and becomes a correctness requirement.

### Outstanding: CLOSED by execution (2026-07-30)

All four key sets enumerated under identical conditions: 25 rows, default paging,
`to_paginate()` / `toPaginate()` with no arguments, keys sorted.

| | keys | default page size | rows returned |
| --- | --- | --- | --- |
| python | 10 | 20 | 20 |
| php | 10 | **100** | 25 (no slicing) |
| ruby | 12 | 10 | 10 |
| node | **13** | 10 | 10 |

```
python (10): count, data, limit, offset, page, per_page, records, total,
             totalPages, total_pages
php    (10): count, data, limit, offset, page, per_page, records, total,
             totalPages, total_pages
ruby   (12): the same 10, plus has_next, has_prev
node   (13): the same 12, plus perPage
```

**The grep was wrong in both directions, and this is why the item existed.**

- **PHP's key set is identical to Python's**, not the single `total_pages` the grep
  suggested. PHP is not the outlier on keys at all.
- **Node has 13 keys, not the nine recorded above from source reading.** It carries
  `has_next` / `has_prev` like Ruby AND a fourth spelling of page size: `limit`,
  `per_page` and `perPage` all appear in one response object, all `10`. Node is the
  worst offender, not Python.
- **PHP's default page size is 100, not "none".** `toPaginate()` takes no arguments,
  so it derives page and per_page from the `DatabaseResult`'s own `limit` / `offset`,
  and that limit defaults to 100. The "no default" reading was a signature reading,
  not a behaviour reading.
- **PHP does not slice.** With `limit` 100 and 25 rows it returns all 25 under a
  `per_page` of 100. The other three slice to their page size. So PHP's response is
  self-consistent but its page size is 10x Ruby/Node and 5x Python.

**Three duplicate pairs are universal**: `records`/`data`, `count`/`total`,
`totalPages`/`total_pages` appear in all four. That is not a Python defect as D2
implied; it is the shared inheritance, and any canonical set has to drop one of each.

Canonical set therefore resolves to: the 7 distinct facts (`records`, `count`,
`limit`, `offset`, `page`, `total_pages`, plus `has_next`/`has_prev` as the genuine
2-of-4 addition worth keeping), with `data`, `total`, `totalPages`, `per_page` and
`perPage` dropped as aliases. Page size: one number across all four, and the
`Breaking:` note has to name it because every framework changes.

### The row-cap decision this row forces

Feature 23 recorded five ORM read paths with four different silent caps. Pagination
is the reason the decision cannot be deferred: **a paginate envelope is only honest
if `total` is the true total.**

If `Model.all` silently caps at 100 and a table has 250 rows, then `total` is 100 and
`total_pages` is 5 - both wrong, and wrong in a way that looks authoritative. The
envelope launders a truncation into a fact. So:

- `total` MUST come from a `COUNT(*)` over the filter, never from the length of the
  returned page, and never from a capped read.
- Every read path feeding a paginated response must be uncapped, or the cap must be
  the page size itself and nothing else.

That is the argument for **unbounded-by-default with explicit pagination**, and this
row is where it stops being a preference and becomes a correctness requirement.
Recommendation to the owner: take the cap decision as unbounded, and let pagination
be the only thing that limits rows.

## Proposed conformance fixture

### Tests to write

Real SQLite, 25 rows - more than one page, so the arithmetic is observable.

| pair | positive | negative |
| --- | --- | --- |
| envelope shape | `paginate_returns_exactly_the_seven_agreed_keys` | `paginate_emits_no_duplicate_key_for_the_same_value` - the Python reproduction |
| key casing | `every_envelope_key_is_snake_case` | `no_envelope_key_is_camel_case` - kills `totalPages` and `perPage` |
| page size | `the_default_page_size_is_twenty_in_all_four` | `no_framework_defaults_to_a_different_page_size` |
| parameters | `paginate_accepts_a_page_and_a_page_size` | `paginate_is_not_argumentless` - the PHP reproduction |
| arithmetic | `total_pages_is_the_ceiling_of_total_over_per_page`, `page_two_returns_the_next_slice` | `page_two_does_not_repeat_page_one_rows` |
| honest total | `total_is_the_full_matching_count_not_the_page_length` | `total_is_not_capped_by_a_default_read_limit` - the cap-decision reproduction |
| edges | `an_empty_result_paginates_to_zero_total_and_one_page` | `a_page_beyond_the_last_returns_no_rows_and_does_not_raise` |
| cross-framework | `all_four_emit_the_same_envelope_for_the_same_data` - one committed fixture | `no_framework_emits_a_key_the_others_lack` |

The honest-total pair is the one that matters most: it is the test that fails today
if any read path in the chain silently truncates, which makes it the enforcement
mechanism for the cap decision rather than a note in a plan.

## Integration map

- `DatabaseResult` in each framework hosts `toPaginate()`; Feature 3's adapter supplies the
  COUNT probe for `total`; Feature 6 supplies the `limit`/`offset` that define the page.
- Every REST/CRUD/ORM endpoint that returns a paginated list emits this envelope; tina4-js
  frontends read it, so the key cull is a client-visible breaking change.
- The systemic row-cap decision spans Features 5, 21, 22, 23 and 24; `total`'s honesty is the
  enforcement point, so the shared fixture's honest-total case gates the whole cap decision.
- The paginated shape appears in the REST and CRUD chapters of all four doc sections; every
  example changes with the key cull (First Principle: docs ship in the same release).

## Breaking changes and migration

- The key cull removes `data`, `count`, `totalPages`, `perPage` (and any other duplicate) from
  the payload. `Breaking:` entry naming each removed key and its canonical replacement
  (`data` -> `records`, `count` -> `total`, `totalPages` -> `total_pages`, `perPage` ->
  `per_page`). A tina4-js frontend reading the old key updates in the same release.
- `.count` becoming the true total in Ruby and Node is breaking for any caller reading it as a
  page-row count.
- `toPaginate()` becoming argument-rejecting is breaking for a Python/Ruby/Node caller passing
  `page`/`per_page`; the migration is to fetch the desired page and paginate that result.
- Node's effective page size changes as a consequence (it no longer re-slices to 10); state it
  in the release note.

## Implementation backlog

### Methodology

1. Close the Outstanding item - enumerate all four key sets by execution.
2. Build the committed envelope fixture: 25 rows, one expected JSON payload, read by
   all four suites. Same bytes, one answer key.
3. Write the tests below. Expect red everywhere: on the duplicate keys, on PHP's
   missing parameters, on Node's page size, on Ruby's nil defaults.
4. **PHP first** - it needs parameters added, which is the only structural change.
   Then Node (page size plus key cull), Python (key cull), Ruby (defaults).
5. Take the cap decision (above) and make `total` a real `COUNT(*)` in all four.
6. Docs: the paginated shape appears in the REST and CRUD chapters of all four doc
   sections. Every example changes.

## Porting capsule

### Pattern

**One paginated envelope, seven snake_case keys, derived from the result - no arguments.**

This capsule reflects the RE-OPENED 2026-08-05 contract; it supersedes the earlier
argument-form sketch (a `DatabaseResult` holds no connection, so an argument form can only
re-slice memory and misreport `total_pages`).

```
{
  "records":     [ ... ],   the rows the query returned, VERBATIM, never re-sliced
  "total":       250,       true matching total from a COUNT(*) probe, NEVER rows returned
  "page":        3,         1-based, floor(offset / limit) + 1
  "per_page":    20,        the query's limit
  "total_pages": 13,        ceil(total / per_page)
  "limit":       20,        the SQL limit actually applied
  "offset":      40         the SQL offset actually applied
}
```

Rules, each killing a divergence:

1. **`toPaginate()` takes no arguments.** It reports the query that was run. To read page 3,
   fetch page 3 (`limit=20, offset=40`) and paginate that result. Passing an argument RAISES.
2. **`total` is a true `COUNT(*)` over the filter**, never the length of `records` and never a
   capped read. This is the field Ruby and Node get wrong today, and it is the one that makes
   the envelope honest.
3. **`records`, not `data`; `total`, not `count`.** `records` matches the `DatabaseResult`
   property; `count` is ambiguous ("count in this page"). `data` and the payload `count` are
   deleted. `DatabaseResult.count` may stay as a property because it means something else
   there.
4. **snake_case keys in the JSON, in all four.** A JSON key is data; it does not change
   spelling by host language. `totalPages`, `perPage` and every other duplicate are deleted.
   The METHOD name still follows each language's convention (`to_paginate` / `toPaginate`).
5. **`page` is derived from the offset** (`floor(offset / limit) + 1`), never defaulted to 1;
   `records` are verbatim, never re-sliced by an absolute offset.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| paginate | `to_paginate()` | `toPaginate()` | `to_paginate()` | `toPaginate()` |
| passing an argument | raises | raises | raises | raises |
| envelope keys | identical snake_case in all four | | | |

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (measured page-3 divergence, all four).
- [x] Owner ambiguities recorded (6 proposed; has_next/has_prev is the one open sub-decision).
- [x] Proposed shared cases and mutation witnesses complete (each fails today somewhere).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient (no-argument form).

### State

AUDIT decision-ready on the RE-OPENED 2026-08-05 contract (the authority; the earlier
SYNTHESISE verdict is superseded and retained only as record). The canonical envelope is
`toPaginate()` with no arguments, PROMOTE PHP, `total` from a real `COUNT(*)`, seven snake_case
keys. The IMPLEMENTATION is a SEPARATE pass, not a patch: making `.count` the true total in
Ruby and Node reaches into the adapters and is breaking. It is coupled to the systemic row-cap
decision (Features 5, 21, 22, 23, 24) and blocks on that one ADR. Decision-ready is not built.

---

### RE-OPENED 2026-08-05: measured, and it is worse than parked

The progress row in `98-feature-audit.md` read **"closed, 0 open"** while this plan
read **"Parked. Not implemented."** Both cannot be true. The row was closed on the
strength of ENUMERATING the four key sets, which unblocked this plan rather than
implementing it, and the envelope was never checked for whether it tells the truth.

#### The measurement

One query, all four frameworks, against a real 250-row SQLite table:
`SELECT * FROM t` with `limit=20, offset=40`. That is page 3 of 13 by inspection.

| | page | per_page | total | total_pages | records returned | keys |
| --- | --- | --- | --- | --- | --- | --- |
| Python | **1** | 20 | 250 | 13 | 20 | 10 |
| PHP | 3 | 20 | 250 | 13 | 20 | 10 |
| Ruby | 3 | 20 | **20** | **1** | **0** | 12 |
| Node | **1** | **10** | **20** | **2** | **10** | 13 |

**Only PHP is correct on all five values.** Ruby returns ZERO records for a valid
page-3 fetch. Node re-slices a 20-row page down to 10 and calls it page 1 of 2.

#### Two root causes, both cross-framework

1. **`.count` means two different things.** Python and PHP populate it from a
   separate COUNT probe over the filter, so it is the TRUE total (250). Ruby and
   Node populate it with the number of ROWS RETURNED (20). The envelope's `total`
   is therefore 250 in two frameworks and 20 in the other two, for one query. This
   is the exact failure this plan already names: the envelope launders a truncation
   into a fact, and it does it in half the family.

2. **`page` is derived only in PHP.** PHP computes `floor(offset / limit) + 1`.
   Python and Node default `page = 1` and ignore the offset entirely, so every
   offset fetch is mislabelled as the first page.

A third, smaller one: Ruby and Node re-slice `records` by the ABSOLUTE offset
against an array that is already just that page, which is why Ruby returns nothing
(offset 40 into a 20-element array) and Node returns 10 of 20.

#### Verdict: PROMOTE php. Decided on correctness.

Not on LOC or structure. PHP is the only implementation that reports the query it
actually ran, and it is the only one that cannot lie, because it derives every
field from the result rather than from caller-supplied arguments.

#### The pattern

`toPaginate()` takes **NO arguments** in all four.

```
per_page    = the query's limit
page        = floor(offset / limit) + 1
total       = the true total for the filter (COUNT probe), NEVER rows returned
total_pages = ceil(total / per_page)
records     = the rows the query returned, VERBATIM, never re-sliced
```

To read page 3, FETCH page 3 (`limit=20, offset=40`) and call `toPaginate()` on
that result. An argument form cannot be honest here: a `DatabaseResult` holds no
connection, so `to_paginate(page: 6)` can only re-slice rows already in memory. It
then reports `total_pages = 13` for pages it can never reach. That is why the
arguments go rather than get fixed.

**Passing an argument must RAISE, not be ignored.** PHP silently swallows extra
arguments today, and that silence is precisely why the divergence survived a
release: a caller porting Python code to PHP gets no signal at all. This follows
the audit's own inverted-flag rule - a removed parameter gets a hard error, never a
silent reinterpretation.

#### Owed before this can close

- `.count` must mean the true total in Ruby and Node. This is the deep half: it
  reaches into the adapters, it is BREAKING for anyone reading `.count` as a row
  count, and it is the reason this is a separate implementation pass rather than a
  patch to the four `toPaginate` methods.
- One key set. Still divergent at py 10, php 10, ruby 12, node 13 (`has_next` /
  `has_prev` in Ruby and Node, `perPage` camelCase in Node alone).

#### Tests (named, positive and negative, the same set in all four)

Each must FAIL against today's code in at least one framework before the fix.

- `paginate_page_is_derived_from_the_offset` - a `limit=20 offset=40` fetch reports
  page 3. FAILS today in Python and Node (both report 1).
- `paginate_total_is_the_true_total_not_rows_returned` - 250-row table, 20-row
  page, `total == 250`. FAILS today in Ruby and Node (both report 20).
- `paginate_records_are_the_rows_the_query_returned` - the envelope carries all 20
  rows. FAILS today in Ruby (0 rows) and Node (10 rows).
- `paginate_takes_no_arguments` - passing one RAISES. FAILS today in all four.
- `paginate_key_set_is_identical_in_all_four` - the shared fixture asserts one key
  list. FAILS today in Ruby and Node.

No mocks: a real SQLite table with a known row count is a real dependency.
