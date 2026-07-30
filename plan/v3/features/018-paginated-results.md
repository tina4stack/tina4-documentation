# Feature 18: Paginated results (standardized format)

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 6. **Planning only.**

**Status: CLOSED.** All four key sets enumerated by execution (2026-07-30). The
source reading undercounted Node by four keys and mis-read PHP twice; see
Outstanding below.

The matrix calls this row "standardized format". It is not standardized.

## Files

`DatabaseResult` in each framework:

| | path |
| --- | --- |
| python | `tina4_python/database/adapter.py` |
| php | `Tina4/Database/DatabaseResult.php` |
| ruby | `lib/tina4/database_result.rb` |
| node | `packages/orm/src/databaseResult.ts` |

## What differs

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

This is feature 13's alias sprawl again, and here it is worse. An alias method
(`to_assoc` for `to_dict`) is a developer-facing convenience that costs a line of
docs. A duplicated key is in **every API response**: it inflates the payload, and it
forces every consumer to guess which spelling is canonical. A client written against
`totalPages` breaks the day someone tidies the dict; a client written against
`total_pages` breaks the other day.

**D3. There is no agreed key set.** Python has ten keys, Node nine, PHP's grep
surfaced `total_pages`, Ruby's is unprobed. Nothing in the framework family declares
what a paginated response looks like, which is exactly what the matrix row claims
this feature provides.

## Outstanding: CLOSED by execution (2026-07-30)

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

## Verdict: SYNTHESISE

Decided on **correctness of the wire contract**.

Nobody wins. Python has the most complete data and the worst duplication. Node has
the same duplication with a different page size. PHP cannot paginate through its own
paginate method. Ruby defaults to nil, meaning the caller must always supply both.

All category 4. Nothing about a JSON key name is runtime-forced.

## Pattern

**One paginated envelope, seven keys, no duplicates, one page size.**

```
{
  "records":     [ ... ],   the rows, always this key
  "total":       25,        total matching rows, ignoring pagination
  "page":        1,         1-based
  "per_page":    20,        rows per page
  "total_pages": 2,         ceil(total / per_page)
  "limit":       20,        the SQL limit actually applied
  "offset":      0          the SQL offset actually applied
}
```

Decisions inside that envelope, each killing a divergence:

1. **`records`, not `data`.** `records` is what `DatabaseResult` already exposes as a
   property in all four, so the envelope matches the object. `data` is deleted.
2. **`total`, not `count`.** `count` is ambiguous - it reads as "count in this page".
   `total` cannot. `count` is deleted from the envelope; `DatabaseResult.count` stays
   as a property because it means something different there.
3. **snake_case keys in the JSON, in all four.** This is the wire format, not a
   language surface: a JSON key is data, and data does not change spelling by host
   language. `totalPages` and `perPage` are deleted. The **method** name still follows
   each language's convention (`to_paginate` / `toPaginate`) - that is the surface
   table's job; the **payload** does not.
4. **One default page size: 20.** Python's, because it is the only one of the four
   that is both specified and not 10 - and 10 is small enough that it doubles the
   round trips for no benefit. PHP gains parameters, Ruby gains defaults, Node's 10
   becomes 20.
5. **`page` is 1-based everywhere**, and `limit`/`offset` report what was actually
   applied so a caller can see the translation rather than infer it.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| paginate | `to_paginate(page=1, per_page=20)` | `toPaginate($page = 1, $perPage = 20)` | `to_paginate(page: 1, per_page: 20)` | `toPaginate(page = 1, perPage = 20)` |
| envelope keys | identical snake_case in all four | | | |

## The row-cap decision this row forces

Feature 16 recorded five ORM read paths with four different silent caps. Pagination
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

## Methodology

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

## Tests to write

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

## Risks

- **Deleting `data`, `count`, `totalPages` and `perPage` is breaking for any API
  consumer**, including tina4-js frontends reading these envelopes. `Breaking:` entry
  plus a migration note listing every removed key and its replacement.
- **The doc blast radius is large** - the paginated shape appears in the REST, CRUD
  and ORM chapters of four doc sections. The docs pass ships in the same release or
  the First Principle is violated the moment this lands.
- **Node's page size change (10 to 20)** doubles the default payload. Worth stating
  in the release note; it is the right trade for consistency but it is a visible one.

## Parked

Not implemented. Blocked on the Outstanding key-set enumeration and coupled to the
row-cap decision. Order: 6, 4, 5, 3, 13, 14, 15, 16, 17, 18, then 2, 1, 0.
