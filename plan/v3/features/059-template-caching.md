# Feature 059: Frond template caching

## Identity and status

- Matrix identity: 59 - Frond template caching
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the compiled-template cache in each
  engine). No framework code changed.
- Dependencies: Feature 50 compiler (what is cached), Feature 51 runtime, the template source
- Dependants: every repeated render of the same template
- Existing ADRs: ADR-0001 (the compile layer); ADR-0009 (removable Frond folder)
- Shared fixtures: `frond_template_cache_contract.json` is required
- Catalog phase: Frond template engine

## Why this feature exists

Compiling a template is work; doing it on every render is wasteful. Template caching keeps the
compiled template so a repeated render reuses it - and invalidates it when the source changes so a
developer's edit is picked up. It must behave the same way in all four, including the memory bound
and the invalidation.

## Boundary

This feature owns the compiled-template cache: its key, its memory BOUND, and its invalidation on
source change (and hot-reload). It DELEGATES compilation to Feature 50 and the render to Feature
51. It is NOT the fragment cache (`{% cache %}`, Feature 60), which caches rendered OUTPUT rather
than the compiled template.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Compiled-template cache | `@lru_cache(maxsize=1024)` (bounded) | cache | cache | cache |
| Memory bound | 1024 (LRU) | (to confirm) | (to confirm - memoization) | (to confirm) |
| Key | template content/path | same | same | same |
| Invalidation on source change | yes | yes | memoized stale (Feature 50 bug) | yes |
| Hot-reload re-compile | yes | yes | (to confirm) | yes |

Python bounds the compiled-template cache with `@lru_cache(maxsize=1024)`, so a long-running
process caching many templates cannot grow without limit. The memory bound and the invalidation
are the two things to gate: a cache that never invalidates serves a stale compiled template after
an edit (the Ruby memoization-staleness class from Feature 50), and an unbounded cache leaks memory
over a process's life.

## Public surface contract

Template caching is automatic and internal: a compiled template is cached under a stable key and
reused on the next render, up to a bounded size (LRU eviction). A change to the template source
invalidates its cached entry, and hot-reload re-compiles. There is no public API beyond the
render; the cache is transparent.

## Inputs and outputs

- Input: a template (source or path) and, on re-render, whether its source changed.
- Output: the compiled template - from cache on a hit, freshly compiled on a miss or after an
  invalidation.
- The cache is bounded; the least-recently-used entries are evicted under pressure.
- An edited template misses the cache (invalidated) and recompiles.

## Lifecycle and operation graph

1. A render looks up the compiled template by key; a hit returns the cached compiled form.
2. A miss compiles (Feature 50), stores under the key (evicting LRU if at the bound), and returns
   it.
3. A source change (mtime or content) invalidates the entry; the next render recompiles.
4. Hot-reload (dev) invalidates and recompiles on change so a developer sees edits immediately.

## Configuration and precedence

- The cache size is bounded (Python 1024 LRU); the same bound applies in all four.
- Invalidation is by source change; a stale entry is never served after an edit.
- In production the cache persists for the process; hot-reload applies in dev.

## Failures, side effects and security

- STALENESS: a cache that does not invalidate on source change serves an old compiled template
  after an edit (the Ruby memoization bug); invalidation is mandatory.
- MEMORY: the cache is bounded (LRU), so a process caching many distinct templates cannot exhaust
  memory; an unbounded cache is a slow leak.
- The cache holds compiled templates, not user data; it is per-process and carries no
  cross-request confidentiality concern.
- A cache key collision (two templates hashing to one key) would render the wrong template; the
  key must be collision-safe.

## Wire and persistence contract

There is no external persistence; the compiled-template cache is an in-process, bounded, keyed
store. The observable contract is that a repeated render is faster and byte-identical to a fresh
compile, and an edited template recompiles. Behaviour is identical across the four.

## Providers and substitutability

The cache is engine-agnostic (an LRU or bounded map). A future runtime caches compiled templates
under a stable key with a memory bound and source-change invalidation.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| TC-01 | The memory bound (Python LRU 1024) is not proven identical; an unbounded cache leaks. | Pin one bound and gate that the cache does not grow without limit in all four. |
| TC-02 | Invalidation on source change is not gated (Ruby memoization staleness, Feature 50). | Gate that an edited template recompiles in all four. |
| TC-03 | The cache key's collision-safety is not gated. | Gate that two distinct templates do not share a cache entry in all four. |
| TC-04 | Hot-reload re-compile parity is not gated. | Gate that a dev-mode edit is picked up on the next render in all four. |
| TC-05 | No shared fixture exists. | Add `frond_template_cache_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. The compiled-template cache is BOUNDED (recommend the Python LRU 1024) in all four; it never
   grows without limit.
2. A source change (mtime or content) invalidates the cached entry; a stale compiled template is
   never served after an edit.
3. The cache key is collision-safe; two distinct templates never share an entry.
4. Hot-reload re-compiles on a dev-mode edit; production caches for the process life.
5. The cache is transparent (no public API) and holds compiled templates only.

## Proposed conformance fixture

Add `frond_template_cache_contract.json` with stable ids for: a repeated render hitting the cache
(byte-identical, no recompile); an edited template invalidating and recompiling; the cache
respecting its bound under many distinct templates (LRU eviction, no unbounded growth); two
distinct templates not colliding; and a hot-reload edit picked up. Every case renders real
templates and observes cache behaviour; a pure render needs no service and runs in all four
runners.

## Integration map

- Feature 50 compiles what is cached; Feature 51 renders from it; Feature 60 is the separate
  fragment cache; hot-reload ties to the dev server.
- Central fixtures, four runners, the CI matrix and the Frond performance docs update together.

## Breaking changes and migration

- Pinning the bound and invalidation is internal; no template breaks. Fixing the Ruby memoization
  staleness (Feature 50) is a correctness fix a stale template relied on being a bug.
- No public API change.

## Implementation backlog

1. Add `frond_template_cache_contract.json` and wire four runners.
2. Pin and gate the memory bound (TC-01) and source-change invalidation (TC-02) in all four.
3. Gate key collision-safety (TC-03) and hot-reload (TC-04).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Cache the compiled template under a stable, collision-safe key in a bounded store (an LRU of ~1024
or equivalent), returning the cached compiled form on a hit and compiling on a miss. Invalidate the
entry on a source change (mtime or content) so an edit recompiles, and re-compile on a hot-reload
in dev. Keep it transparent (no public API) and per-process. Prove the port with a repeated-render
hit, an edit-invalidation, and a bounded-growth case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (TC-01..05).
- [x] Owner ambiguities recorded (5 proposed; the bound and invalidation are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
