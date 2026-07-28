# Feature 19: Result / ORM caching (in-memory, TTL)

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 2, row 7. **Planning only.**

**Status: CLOSED.** Ruby's absence and Python's behaviour verified by execution; PHP
and Node signatures read from source.

## Files

`cached()` lives on the ORM base class; the query cache itself is in the DB layer.

## What differs

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

## Verdict: GAP (Ruby) plus a SYNTHESISE on observability

Decided on **correctness for D2**, then the gap.

Nothing to promote on the ORM `cached()` mechanism itself - the three that have it
agree closely (same argument order, same 60-second TTL default, same 20-row limit
default, which incidentally matches the scope default from feature 16). Ruby simply
needs it, from parts it already owns.

The real work is D2: one cache-reporting surface that sees every cache. That is
category 4 - no runtime prevents any framework from reporting its own caches.

## Pattern

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

## Methodology

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

## Tests to write

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

## Risks

- **The layered `cache_stats()` shape is breaking.** The dev-admin dashboard and the
  MCP metrics tool both read the flat keys; they change in the same commit or the
  dashboard shows nothing. `Breaking:` entry plus a migration note.
- **Ruby gaining `cached()` is purely additive** and can land first, independently.
- **Do not "fix" D3 by making the ORM cache flush on write.** That would silently
  change what an explicit `cached(sql, ttl=60)` call means, and it is the behaviour a
  caller asked for. Document it; do not remove it.

## Parked

Not implemented. Ruby's gap can go early and independently; the `cache_stats()`
reshape is coupled to the dev-admin and MCP consumers. Order: 6, 4, 5, 3, 13, 14, 15,
16, 17, 18, 19, then 2, 1, 0.
