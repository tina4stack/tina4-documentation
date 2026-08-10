# Feature 023: Paginated database and ORM results

## Identity and status

- Matrix identity: 23 — Paginated database and ORM results
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

## Why this feature exists

The retained audit does not yet state the developer problem in one language-neutral sentence.

## Boundary

The retained audit does not yet separate what this feature owns, delegates, and excludes.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

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

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

The audit has not yet traced every producer, discovery, execution, inspection, retry, rollback, and deletion path.

## Configuration and precedence

The audit has not yet fixed argument, environment, project-file, default, and cache timing precedence.

## Failures, side effects and security

The audit has not yet closed every failure boundary, side effect, cleanup rule, and security concern.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

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

Feature 22 recorded five ORM read paths with four different silent caps. Pagination
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

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

## Breaking changes and migration

The audit has not yet turned every parity break into an actionable pre-3.14 migration instruction.

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

## Audit closure checklist

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.

### Parked

Not implemented. Blocked on the Outstanding key-set enumeration and coupled to the
row-cap decision. Order: 6, 4, 5, 3, 13, 14, 15, 16, 17, 18, then 2, 1, 0.

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
