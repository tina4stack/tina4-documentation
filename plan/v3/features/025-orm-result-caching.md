# Feature 025: ORM result caching

## Identity and status

- Matrix identity: 25 - ORM result caching
- Audit state: decision-ready
- Audit note: measured 2026-07-28 (Ruby's absence and Python's behaviour by execution, PHP/
  Node by source); prose sections completed 2026-08-10. No framework code changed.
- Dependencies: Feature 17 ORM base class (`cached()` lives there), the `QueryCache` component
  in the DB layer (the store), the DB query cache (`TINA4_AUTO_CACHING`/`TINA4_DB_CACHE`, a
  separate cache layer this reports)
- Dependants: the dev-admin dashboard and the MCP metrics tool (both read `cache_stats()`);
  the ORM chapter of all four doc sections
- Existing ADRs: the query-cache env split (`TINA4_AUTO_CACHING` vs `TINA4_DB_CACHE`)
- Shared fixtures: `orm_cache_contract.json` is required; its cases mutate BEHIND the cache so
  the staleness window and the observability bug are observable

## Why this feature exists

A developer caches an ORM query's result for a TTL window so a hot read stops re-hitting the
database, and asks one tool which caches are live and how each one invalidates. Today Ruby has
no ORM cache at all, and the one introspection tool reports `off` while a cache is actively
serving stale rows.

## Boundary

This feature owns `cached()` on the ORM (a TTL-windowed cached read) and the cache-reporting
surface (`cache_stats()`, `clear_cache()`) that must see EVERY cache layer. It DELEGATES the
actual store to the `QueryCache` component. The DB-level query cache
(`TINA4_AUTO_CACHING`/`TINA4_DB_CACHE`) is a SEPARATE layer with its own flush-on-write policy;
this feature does not own it but must REPORT it alongside the ORM cache.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| ORM `cached()` present | yes | yes | NO (D1) | yes |
| `QueryCache` component exists | yes | yes | yes (unused by ORM) | yes |
| `cached()` signature | `cached(sql, params, ttl=60, limit=20, offset=0)` | same + `include` | absent | `cached(sql, params?, ttl?, limit?, offset?)` |
| `cache_stats()` sees the ORM cache | NO (reports off while live -- D2) | no | n/a | no |
| Independent cache layers | DB query cache + ORM cache | same | DB cache only | same |
| DB query cache invalidation | flush on any write | same | same | same |
| ORM `cached()` invalidation | TTL expiry only (D3) | TTL only | n/a | TTL only |

Ruby is the only framework missing ORM caching, yet it SHIPS a `QueryCache` class
(`lib/tina4/cache.rb`, with TTL, tagging and `remember`) that is simply never wired into the
ORM -- the cheapest gap in the audit: connect an existing, tested component to an existing call
site. In the three that have it, `cached()` works (Python verified: a second call inside the
TTL served a stale 3-row result after a 4th row landed), but `cache_stats()` reports
`enabled: False, mode: off, hits: 0` for a live cache, because there are TWO independent caches
and `cache_stats()` reports only the DB one.

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 7. **Planning only.**

**Status: CLOSED.** Ruby's absence and Python's behaviour verified by execution; PHP
and Node signatures read from source.

### Files

`cached()` lives on the ORM base class; the query cache itself is in the DB layer.

## Public surface contract

`cached(sql, params=[], ttl=60, limit=20, offset=0)` runs a query and caches its rows for
`ttl` seconds, returning the cached rows on a repeat call inside the window. `cache_stats()`
returns a per-LAYER report (every cache, not one flattened blob), each layer declaring its
`invalidates_on_write` policy. `clear_cache()` empties EVERY layer and returns what it cleared.
The three signatures already agree (same order, `ttl=60`, `limit=20`); Ruby gains them from its
existing `QueryCache`.

## Inputs and outputs

- `cached()` input: a SQL string, bound params, a TTL, and a limit/offset; output: the rows,
  served from cache within the TTL and re-queried after it.
- `cache_stats()` output: a map keyed by layer (`query`, `orm`, `response`), each with
  `enabled`, `mode`, `hits`, `misses`, `size`, `ttl`, `backend` and `invalidates_on_write`.
- `clear_cache()` output: what was cleared per layer.
- A live cache NEVER reports `enabled: false` (the D2 bug).

## Lifecycle and operation graph

1. `cached(sql, params, ttl)` computes a key from the SQL and params and checks the store.
2. A hit inside the TTL returns the cached rows without touching the database (it will serve
   stale rows if a write landed behind it -- that is the opt-in-to-staleness contract).
3. A miss runs the query, stores the rows under the key with the TTL, and returns them.
4. TTL expiry evicts the entry; the ORM cache does NOT flush on write (D3), unlike the DB
   query cache.
5. `cache_stats()` reports every layer's live counters; `clear_cache()` empties them all.

## Configuration and precedence

- The DB query cache is off by default and enabled by `TINA4_AUTO_CACHING`/`TINA4_DB_CACHE`;
  it flushes on any write (which is why it is opt-in: a read-after-write in one request would
  otherwise serve pre-write state).
- The ORM `cached()` cache is active whenever called, with a default `ttl=60` and `limit=20`,
  and invalidates on TTL expiry only.
- These two policies are DIFFERENT by design and must be documented, not silently unified.

## Failures, side effects and security

- OBSERVABILITY: `cache_stats()` must never report `off` while a cache is serving. The current
  behaviour (a live ORM cache reported as `enabled: false`) sends a developer chasing stale
  data everywhere except the cache that is causing it -- the one tool built to answer the
  question answers it wrongly.
- The ORM cache serving stale rows within its TTL is intended (an explicit `cached(ttl=60)`
  call accepts 60 seconds of staleness); it must NOT be "fixed" by making it flush on write,
  which would silently change what the caller asked for.
- A cache key is derived from the SQL and bound params; params are values, not concatenated,
  so a cache lookup carries no injection.
- `clear_cache()` is the escape hatch: one call empties every layer.

## Wire and persistence contract

The reported shape is the contract. `cache_stats()` returns one object per layer:

```
{
  "query":    {"enabled": false, "mode": "off", "hits": 0,  "misses": 0, "size": 0, "ttl": 5,  "backend": "memory", "invalidates_on_write": true},
  "orm":      {"enabled": true,  "mode": "ttl", "hits": 12, "misses": 3, "size": 4, "ttl": 60, "backend": "memory", "invalidates_on_write": false},
  "response": { ... }
}
```

`invalidates_on_write` is the field that makes the two-cache policy difference answerable
without reading source; it is a fact about the layer, so it lives in the layer's stats.

## Providers and substitutability

The cache backend (memory, Redis, and so on) is pluggable behind `QueryCache`; the reporting
and the `cached()`/`clear_cache()` surface are backend-agnostic. A future runtime wires its own
`QueryCache` equivalent to the same ORM surface and reports the same layered stats.

## Contradictions and defects

### What differs

**D1. Ruby has no ORM-level caching at all. Verified by execution:**

```
C.respond_to?(:cached)      -> false
C.respond_to?(:clear_cache) -> false
```

`grep -c 'QueryCache|query_cache' lib/tina4/orm.rb` returns **0** - Ruby's ORM never
references the query cache. The only cache-ish method is `clear_rel_cache`, which is
the relationship cache and a different thing.

The other three all have it:

| | signature |
| --- | --- |
| python | `cached(cls, sql, params=None, ttl=60, limit=20, offset=0)` |
| php | `cached(string $sql, array $params = [], int $ttl = 60, int $limit = 20, int $offset = 0, ?array $include = null)` |
| node | `static async cached<T extends BaseModel>(...)` |
| **ruby** | **absent** |

Ruby **does** ship a `QueryCache` class (`lib/tina4/cache.rb`, with TTL, tagging and
`remember`) - it is simply never wired into the ORM. So the building block exists and
is unused from the place that needs it, which makes this the cheapest gap in the
audit to close: wire an existing, tested component to an existing call site.

**D2. Python's `cached()` works, and `cache_stats()` cannot see it.** Verified - three
rows, `cached()`, then an INSERT behind the cache, then `cached()` again:

```
1st cached()                  -> 3 rows
2nd cached() after an INSERT  -> 3 rows      (cache hit, correctly serving the TTL window)
db.cache_stats()              -> {'enabled': False, 'mode': 'off', 'hits': 0,
                                  'misses': 0, 'size': 0, 'ttl': 5, 'backend': 'memory'}
```

The cache is demonstrably live - it served a stale 3-row result after a 4th row
landed - and the framework's only cache introspection surface reports
`enabled: False, mode: off, hits: 0, size: 0`.

**That is an observability bug, and it is the expensive kind.** The failure it
enables: a developer sees stale data, checks `cache_stats()` to find out whether
caching is involved, reads `off`, and rules caching out. The one tool built to answer
the question answers it wrongly. Every minute spent looking elsewhere is caused by
the tool.

The cause is that there are **two independent caches** and `cache_stats()` reports
only one:

| cache | default | invalidation | reported by `cache_stats()` |
| --- | --- | --- | --- |
| DB query cache (`TINA4_AUTO_CACHING` / `TINA4_DB_CACHE`) | off | flushes on any write | **yes** |
| ORM `cached()` | on whenever called | **TTL expiry only** | **no** |

**D3. The two caches have different invalidation policies, and the difference is
undocumented.** The DB-level request cache flushes on any write - that is its
documented contract, and it is why it was made opt-in (a read-after-write in one
request would otherwise serve pre-write state). The ORM `cached()` cache does not
flush on write; it holds until TTL. So the framework's answer to "does a write
invalidate the cache" is yes for one cache and no for the other, and nothing says so.

Both behaviours are defensible in isolation - an explicit `cached(sql, ttl=60)` call
arguably means "I accept 60 seconds of staleness". But a developer cannot reason
about it without knowing there are two caches, and `cache_stats()` actively hides the
second.

### Verdict: GAP (Ruby) plus a SYNTHESISE on observability

Decided on **correctness for D2**, then the gap.

Nothing to promote on the ORM `cached()` mechanism itself - the three that have it
agree closely (same argument order, same 60-second TTL default, same 20-row limit
default, which incidentally matches the scope default from feature 22). Ruby simply
needs it, from parts it already owns.

The real work is D2: one cache-reporting surface that sees every cache. That is
category 4 - no runtime prevents any framework from reporting its own caches.

### Risks

- **The layered `cache_stats()` shape is breaking.** The dev-admin dashboard and the
  MCP metrics tool both read the flat keys; they change in the same commit or the
  dashboard shows nothing. `Breaking:` entry plus a migration note.
- **Ruby gaining `cached()` is purely additive** and can land first, independently.
- **Do not "fix" D3 by making the ORM cache flush on write.** That would silently
  change what an explicit `cached(sql, ttl=60)` call means, and it is the behaviour a
  caller asked for. Document it; do not remove it.

## Owner decisions

Proposed for owner ratification:

1. Ruby gains `cached()` and `clear_cache()` by wiring its EXISTING `QueryCache` (TTL, tagging,
   `remember`) to the ORM, matching the other three signatures exactly. Purely additive, the
   cheapest change here, lands first.
2. `cache_stats()` reports EVERY cache layer, keyed by layer, so a live cache can never read as
   `off`. Breaking: the dev-admin dashboard and the MCP metrics tool read the flat keys and
   change in the SAME commit.
3. Each layer declares `invalidates_on_write`, so the two-cache policy difference is answerable
   without reading source.
4. `clear_cache()` clears every layer and reports what it cleared.
5. The ORM cache's TTL-only invalidation is DOCUMENTED as intentional (on the method and in the
   ORM chapter of all four doc sections); it is NOT changed to flush-on-write, because an
   explicit `cached()` call opts into staleness and that is the deal.

## Proposed conformance fixture

### Tests to write

Real SQLite. The staleness window is the whole point, so these mutate behind the
cache deliberately.

| pair | positive | negative |
| --- | --- | --- |
| Ruby's gap | `every_framework_exposes_cached_on_the_orm` | `no_framework_is_missing_the_cached_method` - the Ruby reproduction |
| it caches | `a_second_cached_call_inside_the_ttl_returns_the_cached_rows` | `a_second_cached_call_does_not_re_query_inside_the_ttl` |
| TTL expiry | `a_cached_call_after_the_ttl_returns_fresh_rows` | `a_cached_result_does_not_outlive_its_ttl` |
| observability | `cache_stats_reports_a_live_orm_cache_as_enabled` | `cache_stats_never_reports_off_while_a_cache_is_serving` - the exact D2 reproduction |
| layered stats | `cache_stats_reports_every_layer_separately` | `no_layer_is_missing_from_cache_stats` |
| policy is stated | `each_layer_declares_invalidates_on_write` | `the_orm_layer_declares_it_does_not_invalidate_on_write` - locks D3 as intentional |
| clear | `clear_cache_empties_every_layer` | `clear_cache_does_not_leave_a_layer_populated` |
| cross-framework | `all_four_report_the_same_cache_stats_shape` | `no_framework_reports_a_key_the_others_lack` |

The `cache_stats_never_reports_off_while_a_cache_is_serving` pair is the one worth
the whole row. It is a test that fails today, in three frameworks, on a question a
developer will actually ask under pressure.

## Integration map

- Feature 17's base model hosts `cached()`/`clear_cache()`; the `QueryCache` component is the
  store; the DB query cache (`TINA4_AUTO_CACHING`) is the second reported layer.
- The dev-admin dashboard and the MCP metrics tool both consume `cache_stats()`, so the layered
  reshape changes them in the same commit.
- The response cache (a third layer) is reported under the same `cache_stats()` surface.
- Central fixtures, four runners, the CI matrix, release notes and the ORM cache docs update
  together.

## Breaking changes and migration

- `cache_stats()` moves from a flat blob to a per-layer map. `Breaking:` entry plus a migration
  note; the dev-admin dashboard and the MCP metrics tool update in the same release or they
  show nothing.
- Ruby gaining `cached()`/`clear_cache()` is purely additive.
- No change to the cached-read behaviour itself; the TTL-only policy is documented, not
  altered.

## Implementation backlog

### Methodology

1. Write the tests below in all four. Expect red: Ruby on everything, and all four
   on the layered `cache_stats()` shape.
2. **Ruby first** - it is the cheapest and most valuable change in this row: wire
   `QueryCache` to the ORM behind `cached()` / `clear_cache`, matching the existing
   three signatures exactly. No new component, no new dependency.
3. Change `cache_stats()` to the layered shape in all four. Breaking for anyone
   reading the flat keys, including the dev-admin dashboard and the MCP metrics tool -
   both consume this, so both change in the same commit.
4. Add `invalidates_on_write` per layer.
5. Make `clear_cache()` clear every layer and report what it cleared.
6. Document the TTL-only policy on the method and in four doc sections.

## Porting capsule

### Pattern

**Every cache is visible from one place, and each declares its invalidation policy.**

1. **`cache_stats()` reports every layer**, keyed by layer, not one flattened blob:

```
{
  "query":  {"enabled": false, "mode": "off",  "hits": 0,  "misses": 0, "size": 0,  "ttl": 5,  "backend": "memory", "invalidates_on_write": true},
  "orm":    {"enabled": true,  "mode": "ttl",  "hits": 12, "misses": 3, "size": 4,  "ttl": 60, "backend": "memory", "invalidates_on_write": false},
  "response": {...}
}
```

   `invalidates_on_write` is the field that makes D3 answerable without reading
   source. It is a fact about the layer, so it belongs in the layer's stats.

2. **`clear_cache()` clears every layer** and returns what it cleared, so a
   developer who wants a clean slate does not have to know how many caches exist.
3. **Ruby gains `cached()` and `clear_cache()`**, wiring the existing `QueryCache`
   (which already has TTL, tagging and `remember`) to the ORM. Same signature and
   the same defaults as the other three.
4. **The ORM cache's TTL-only invalidation is documented as intentional**, on the
   method and in the ORM chapter of all four doc sections. An explicit `cached()`
   call opts into staleness; that is the deal, and it has to be stated where the
   call is made.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| cached read | `cached(sql, params=None, ttl=60, limit=20, offset=0)` | `cached($sql, $params = [], $ttl = 60, $limit = 20, $offset = 0)` | `cached(sql, params: [], ttl: 60, limit: 20, offset: 0)` | `cached(sql, params?, ttl?, limit?, offset?)` |
| clear all layers | `clear_cache()` | `clearCache()` | `clear_cache` | `clearCache()` |
| stats, all layers | `cache_stats()` | `cacheStats()` | `cache_stats` | `cacheStats()` |

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (D1 Ruby gap, D2 observability, D3 policy).
- [x] Owner ambiguities recorded (5 proposed; the genuine calls await owner ratification).
- [x] Proposed shared cases and mutation witnesses complete (mutate behind the cache).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready. GAP verdict for Ruby (no ORM cache, but the `QueryCache` component
already exists unused -- wire it) plus a SYNTHESISE on observability (one layered
`cache_stats()` that sees every cache; the current `off`-while-live report is the expensive
bug). The IMPLEMENTATION is the build phase and is NOT done: Ruby's wiring is additive and
lands first; the `cache_stats()` reshape is breaking (dev-admin + MCP consumers). Decision-
ready is not built.
