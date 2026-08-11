# Feature 59: Frond template caching

## Identity and status

- Matrix identity: 59 - Frond template caching
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language Frond source (correcting a prior-session doc claiming a
  "compiled-template cache `@lru_cache(maxsize=1024)`, bound 1024 (LRU), same in all four" - FABRICATED; NO
  language has a 1024-LRU template cache). Python's template caches are UNBOUNDED; PHP/Ruby/Node cap a
  token/template cache at 256 insertion-order. Prod NEVER invalidates on source change in any language. Python
  `frond/engine.py:1571` (`46007c1`); PHP `Tina4/Frond.php:145` (`ab871934`); Ruby `lib/tina4/frond.rb:207`
  (`f549923`); Node `packages/frond/src/engine.ts:333` (`1319cf3`).
- Dependencies: the parser (49) / compiler (50) - what is cached.
- Dependants: every repeated render; production throughput.
- Existing ADRs: ADR-0004; ADR-0001 (AOT).

- Catalog phase: Frond

## Why this feature exists

Caching the parsed/compiled template avoids re-tokenizing and re-parsing on every render. The audit questions:
what is cached, is the cache bounded, and does it invalidate when the template file changes. The answers: a
token/AST/compiled artifact; bounded inconsistently (Python unbounded, the others 256); and NO - production
never invalidates on an on-disk edit, in any language.

## Existing implementation evidence

Measured, and it diverges:

- Python: the template caches (`_compiled`, `_compiled_strings`, `_compiled_fn`) are plain UNBOUNDED dicts
  (`engine.py:1571-1581`). The `@lru_cache(maxsize=1024)` in the file is on EXPRESSION helpers
  (`_split_dotted`, `_split_on_pipe`, `_expr_descriptor`), NOT templates.
- PHP: `$compiled`/`$compiledStrings`/`$compiledFn` bound at `TEMPLATE_CACHE_MAX = 256`, INSERTION-ORDER
  eviction (explicitly "not true LRU", `Frond.php:145,310-335`); the `{% cache %}` FRAGMENT store is UNBOUNDED.
- Ruby: token cache bound 256 FIFO-half-drop (`frond.rb:207,574`); the expr-form memo 2048; but three
  per-expression memos (`@filter_chain_cache`/`@resolve_cache`/`@dotted_split_cache`) are UNBOUNDED
  (`frond.rb:311-316`).
- Node: token cache bound 256 insertion-order (`engine.ts:333,347`); the `{% cache %}` FRAGMENT store is
  UNBOUNDED (`engine.ts:1715`).
- UNIVERSAL: production NEVER invalidates on source change - the file mtime is STORED but never COMPARED
  (Python `:1729` comment unimplemented; PHP `Frond.php:216`; Ruby `frond.rb:365`; Node
  `engine.ts:1840-1849`). Freshness is TTL-only (`TINA4_TEMPLATE_CACHE_TTL`, default 0 = forever) or the
  `TINA4_DEBUG` dev bypass (which re-reads every render). Keys: template NAME/path for files, `md5(source)`
  for strings.

## Public surface contract

Repeated renders of the same template reuse the cached artifact. `TINA4_TEMPLATE_CACHE_TTL` bounds staleness;
`TINA4_DEBUG` bypasses the cache. The cache should be bounded and should pick up an edited template - today
neither holds uniformly.

## Inputs and outputs

- Input: a template name/source. Output: the cached token/AST/compiled artifact (or a fresh parse in dev).

## Lifecycle and operation graph

1. Render -> cache miss -> tokenize/parse/(compile) -> store keyed by name/md5. 2. Render -> cache hit ->
reuse (prod) / re-read (dev). 3. Eviction: 256 half-drop (PHP/Ruby/Node) or never (Python).

## Configuration and precedence

- `TINA4_TEMPLATE_CACHE_TTL` (default 0 = forever); `TINA4_DEBUG` bypasses. No cache-size env var.

## Failures, side effects and security

- A long-running production worker serves a STALE template after an on-disk edit (no mtime compare) unless a
  TTL is set. Python's unbounded template caches leak memory over a process's life when many distinct
  templates/strings are rendered. The fragment cache is unbounded and collides on a shared key. See the
  register.

## Wire and persistence contract

In-memory, per-instance. No wire format. The invalidation contract SHOULD be "an edited template is re-read" -
met only in dev today.

## Providers and substitutability

A future runtime must bound the template cache (agreed size + policy), invalidate on source change in prod, and
bound the fragment cache.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CACHE-LRU-FABRICATED | The prior doc's "compiled-template cache `@lru_cache(maxsize=1024)`, bound 1024 (LRU), same in all four" is FABRICATED - NO language has a 1024-LRU template cache. Python's template caches are UNBOUNDED dicts (`engine.py:1571`); the 1024 `lru_cache` is on EXPRESSION helpers, not templates. PHP/Ruby/Node use a 256 INSERTION-ORDER (not LRU) cache. Same fabrication class as the HTTP band (a number lifted from an unrelated site). | Correct the doc; pin one real bound + policy (CACHE-DEC-01). |
| CACHE-PYTHON-UNBOUNDED | Python's template caches (`_compiled`/`_compiled_strings`/`_compiled_fn`) are UNBOUNDED - a long-running process rendering many DISTINCT named templates or `render_string` sources grows memory without limit. PHP/Ruby/Node cap at 256. Python is the leak outlier. | Bound Python's template caches to the agreed size (CACHE-DEC-01). |
| CACHE-PROD-STALE | UNIVERSAL: production NEVER invalidates on source change - the file mtime is STORED but never COMPARED in all four (`engine.py:1729` comment unimplemented, `Frond.php:216`, `frond.rb:365`, `engine.ts:1840`). A prod worker serves a STALE template after an on-disk edit unless `TINA4_TEMPLATE_CACHE_TTL>0`. | Compare the stored mtime (or a content hash) so a prod worker picks up an edited template, in all four (the mtime is already stored - just read it). |
| CACHE-FRAGMENT-UNBOUNDED | UNIVERSAL: the `{% cache key ttl %}` FRAGMENT store is UNBOUNDED in all four (distinct keys grow it without limit), and a SHARED key collides (last writer wins). | Bound the fragment cache; make a shared-key collision safe (or documented). |
| CACHE-BOUND-DIVERGE | The template/token cache bound diverges: Python unbounded; PHP/Ruby/Node 256 insertion-order (Ruby also has 3 UNBOUNDED per-expression memos, `frond.rb:311-316`). Not "same in all four". | Agree one bound + policy across the four; bound Ruby's per-expression memos. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- CACHE-DEC-01 (proposed): pin ONE template-cache bound + eviction policy across the four (CACHE-LRU-FABRICATED,
  CACHE-BOUND-DIVERGE) - bound Python's currently-UNBOUNDED template caches (CACHE-PYTHON-UNBOUNDED), agree the
  size and policy (256 insertion-order is the de-facto majority; or a real LRU), and bound the fragment cache
  (CACHE-FRAGMENT-UNBOUNDED) + Ruby's three unbounded memos.
- CACHE-DEC-02 (proposed): fix production staleness (CACHE-PROD-STALE) - COMPARE the already-stored mtime (or a
  content hash) so a prod worker picks up an edited template, in all four.

## Proposed conformance fixture

A shared fixture: rendering N+1 distinct templates evicts to a bounded size in ALL four (catches
CACHE-PYTHON-UNBOUNDED); an on-disk edit to a cached template is picked up on the next render WITHOUT
`TINA4_DEBUG` (catches CACHE-PROD-STALE); the fragment cache is bounded and a shared-key reuse is safe.

## Integration map

- Consumers: every repeated render. Composes: the parser (49), the compiler (50). `TINA4_TEMPLATE_CACHE_TTL` +
  `TINA4_DEBUG` gate it.

## Breaking changes and migration

- Bounding Python's cache changes memory behaviour (a fix). Invalidating on mtime changes prod behaviour
  (edited templates now refresh) - a correctness fix; note it (a worker that relied on the permanent cache).

## Porting capsule

Cache the parsed/compiled template keyed by name (files) or content md5 (strings), BOUNDED to one agreed size +
policy across the four (Python's unbounded dicts are the leak to avoid). In production, COMPARE the stored file
mtime (or a content hash) so an edited template is re-read - do not serve a permanently stale template. Bound
the `{% cache %}` fragment store too, and make a shared fragment key safe. Keep the `TINA4_DEBUG` re-read-every-
render dev path.

## Audit closure checklist

- [x] Boundary and public surface complete (template + fragment cache x four).
- [x] Lifecycle and producer/consumer edges complete (miss -> store -> hit/evict).
- [x] Configuration (TTL/DEBUG), failure (stale/unbounded) and security rules complete.
- [x] Wire (in-memory cache) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (python unbounded; others 256; prod never invalidates).
- [x] Owner ambiguities decided (CACHE-DEC-01 bound, CACHE-DEC-02 invalidate).
- [x] Conformance fixture (bound + prod-invalidation) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
