# Feature 060: Frond fragment caching

## Identity and status

- Matrix identity: 60 - Frond fragment caching
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the `{% cache %}` block and the
  fragment store in each engine). No framework code changed.
- Dependencies: Feature 53 tags (`{% cache %}`), Feature 51 runtime (renders the fragment), the
  cache store
- Dependants: any template caching an expensive fragment (a sidebar, a rendered list)
- Existing ADRs: ADR-0009 (removable Frond folder); the query-cache env conventions
- Shared fixtures: `frond_fragment_cache_contract.json` is required
- Catalog phase: Frond template engine

## Why this feature exists

A template fragment can be expensive to render (a menu built from the database, a computed table).
`{% cache "key" ttl %}...{% endcache %}` renders it once, stores the OUTPUT under a key, and reuses
it until the TTL expires - the same way in all four, so a cached page behaves identically wherever
it is served.

## Boundary

This feature owns the `{% cache "key" ttl %}` block, the fragment STORE (key to rendered output
plus expiry), and the TTL policy. It DELEGATES the tag parsing to Feature 53, the render of the
body to Feature 51, and (if a shared backend is chosen) the store to the cache subsystem. It is
distinct from Feature 59, which caches the COMPILED template, not rendered output.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Syntax | `{% cache "key" ttl %}...{% endcache %}` | same | same | same |
| Store | `_fragment_cache: key -> (output, expires_at)` | same shape | same | same |
| TTL source | `TINA4_TEMPLATE_CACHE_TTL` (default 0 = permanent) | same | same | same |
| Per-block TTL | the second arg overrides the env default | same | same | same |
| Store scope | per-INSTANCE dict (per-process) | per-process | per-process | per-process |
| Invalidation | TTL expiry only (no content-change bust) | same | same | same |

The `{% cache %}` block renders its body once and stores the rendered OUTPUT under the key with an
expiry (`_fragment_cache: key -> (output, expires_at)`). The TTL comes from
`TINA4_TEMPLATE_CACHE_TTL`, defaulting to 0 which means PERMANENT (no expiry), overridable by the
block's second argument. Two things stand out: the default of 0 = permanent means a fragment
caches FOREVER unless a TTL is given (a staleness footgun), and the store is a per-INSTANCE dict,
so in a multi-worker deployment each worker has its OWN fragment cache - a cache warm on one worker
does not help another, and they can serve different cached content.

## Public surface contract

`{% cache "key" ttl %}...{% endcache %}` renders the body on the first encounter for that key,
stores the output, and serves the stored output until the TTL expires (0 = permanent). The TTL is
the block's second argument, defaulting to `TINA4_TEMPLATE_CACHE_TTL`. The key is a string; two
blocks with the same key share the entry. Identical across the four.

## Inputs and outputs

- Input: a cache key, an optional TTL (else the env default), and the block body plus context.
- Output: the rendered body on a miss (and stored); the stored output on a hit within the TTL.
- A per-block TTL overrides the env default; TTL 0 means the fragment never expires.
- Two `{% cache %}` blocks with the same key share the cached output.

## Lifecycle and operation graph

1. The runtime encounters `{% cache "key" ttl %}`; it looks up the key in the fragment store.
2. A hit within the TTL (or a permanent 0-TTL entry) returns the stored output without rendering
   the body.
3. A miss (or an expired entry) renders the body, stores `(output, now + ttl)`, and returns it.
4. There is no content-change invalidation: a permanent entry persists until the process ends or
   the key changes.

## Configuration and precedence

- Per-block TTL (second argument) overrides `TINA4_TEMPLATE_CACHE_TTL`, which defaults to 0
  (permanent). The default-permanent behaviour is the staleness footgun to weigh.
- The store is per-process by default (a dict); a shared backend (for cross-worker consistency)
  is a consideration.
- The key namespace is flat; two blocks with the same key collide by design.

## Failures, side effects and security

- STALENESS: a 0-TTL (permanent) fragment never expires and is NOT invalidated by a content
  change, so an edit to the cached content is not reflected until the process restarts or the key
  changes. The default of 0 = permanent makes this the DEFAULT behaviour; the audit should weigh a
  saner default or a loud note.
- MULTI-WORKER INCONSISTENCY: a per-instance store means workers cache independently, so two
  requests can see different cached fragments; a shared backend fixes it but adds a dependency.
- MEMORY: the fragment store is unbounded unless capped; a template caching many distinct keys
  grows the store - a bound or eviction is worth pinning.
- A cache key derived from user input could let a user poison or read another user's fragment; the
  key must be author-controlled, not built from untrusted request data without care.

## Wire and persistence contract

There is no external persistence by default; the fragment store is an in-process map from key to
`(output, expires_at)`. The observable contract is that a cached fragment is served identically
within its TTL. If a shared backend is adopted, the stored shape (key, output, expiry) is the same
across the four.

## Providers and substitutability

The fragment store is a keyed map with expiry; a future runtime implements the same `{% cache %}`
block with the same TTL semantics. A shared backend (Redis) substitutes the per-process dict for
cross-worker consistency, behind the same block surface.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| FC-01 | The default TTL is 0 = permanent, so a fragment caches forever with no content-change invalidation (staleness footgun). | Decide: keep permanent-default (documented loudly) or pick a saner default TTL; gate the chosen behaviour. |
| FC-02 | The store is per-INSTANCE/per-process, so workers cache independently and can serve different content. | Decide: keep per-process (documented) or offer a shared backend; gate the chosen semantics. |
| FC-03 | The fragment store is unbounded unless capped; a memory leak over many keys. | Pin a bound/eviction and gate that the store does not grow without limit. |
| FC-04 | The `{% cache %}` syntax, key sharing and per-block TTL override are not gated as parity. | Gate the block, key sharing and TTL override in all four. |
| FC-05 | A key built from untrusted input is a poisoning/read surface. | Document that a cache key must be author-controlled; gate that a user-data key is not the default pattern. |
| FC-06 | No shared fixture exists. | Add `frond_fragment_cache_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. `{% cache "key" ttl %}` renders once and serves the stored output until the TTL, identical in
   all four; a per-block TTL overrides `TINA4_TEMPLATE_CACHE_TTL`.
2. Decide the default TTL: keep 0 = permanent (documented loudly as a staleness footgun) or pick a
   saner default; the current silent-forever default is the risk.
3. Decide the store scope: per-process (documented as not cross-worker) or a shared backend for
   consistency; pin one and gate it.
4. Bound the fragment store (or evict) so it cannot leak memory over many keys.
5. A cache key is author-controlled; deriving it from untrusted request data is documented as a
   poisoning/read hazard.

## Proposed conformance fixture

Add `frond_fragment_cache_contract.json` with stable ids for: a `{% cache %}` block rendering once
and serving the stored output on a second encounter; a per-block TTL expiring and re-rendering;
two blocks with the same key sharing the entry; a permanent (0-TTL) entry persisting; the store
respecting its bound over many keys; and the documented multi-worker/scope behaviour. Every case
renders real templates and observes the cache; a pure render needs no service (a shared-backend
case uses the real backend, no mock).

## Integration map

- Feature 53 parses `{% cache %}`; Feature 51 renders the body; the cache subsystem backs a shared
  store if chosen; Feature 59 is the separate compiled-template cache.
- The `TINA4_TEMPLATE_CACHE_TTL` variable follows the env conventions; the docs describe the
  staleness and multi-worker behaviour.
- Central fixtures, four runners, the CI matrix and the Frond caching docs update together.

## Breaking changes and migration

- Changing the default TTL from permanent (if chosen) changes what a `{% cache %}` block without a
  TTL does; a `Breaking:` note, and it is a staleness fix. A shared-backend option is additive.
- Bounding the store is internal; no template breaks.

## Implementation backlog

1. Add `frond_fragment_cache_contract.json` and wire four runners (plus a real shared backend if
   chosen).
2. Decide and gate the default-TTL (FC-01) and the store-scope (FC-02) behaviour.
3. Bound the store (FC-03) and gate the block/key/TTL semantics (FC-04).
4. Document the key-from-untrusted-input hazard (FC-05).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement `{% cache "key" ttl %}...{% endcache %}`: on first encounter render the body and store
`(output, now + ttl)` under the key; on a later encounter within the TTL serve the stored output.
Read the TTL from the block or `TINA4_TEMPLATE_CACHE_TTL`; apply the pinned default. Bound the
store, document the per-process (or provide a shared) scope, and require an author-controlled key.
Prove the port with a render-once/serve-stored case, a TTL expiry, and a same-key share.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (FC-01..06; permanent-default and multi-worker).
- [x] Owner ambiguities recorded (5 proposed; the default-TTL and store-scope are the key calls).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
