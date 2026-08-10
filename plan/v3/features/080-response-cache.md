# Feature 080: HTTP response cache

## Identity and status

- Matrix identity: 80 - HTTP response cache
- Audit state: decision-ready (contract settled by ADR-0020; the per-language RFC 9111 DEPTH is
  measured only at the grep level in this pass - a shared fixture and a full per-directive extraction
  are owed, see RC-80-02/03)
- Audit note: measured from four-language source 2026-08-10 (the response cache middleware in each repo)
  at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. All four reference the
  Authorization/Cache-Control and Vary rules; the exact per-directive parity is not yet gated. No
  framework code changed.
- Dependencies: Feature 72 (the cache backend interface it stores into), the dispatch/response layer
- Dependants: any GET-heavy endpoint using the response cache middleware
- Existing ADRs: ADR-0020 (the response cache follows RFC 9111 as a SHARED cache), ADR-0024 (it selects
  its backend by `TINA4_CACHE_BACKEND`)
- Shared fixtures: NONE dedicated. `cache_contract.json` gates the backend interface the response cache
  stores into, but the RFC 9111 store/lookup rules (ADR-0020) are UNGATED - a `response_cache_contract.
  json` is owed (RC-80-02).
- Catalog phase: Cache

## Why this feature exists

A GET response that is expensive to compute can be cached and replayed. As a SHARED cache (one store
serving many users), it must obey RFC 9111 so it never replays a private, authorized response to a
different caller and never ignores a `Vary` - the correctness rules ADR-0020 ratified.

## Boundary

This feature owns the response-cache MIDDLEWARE: which responses it STORES (the RFC 9111 store-side
rules on `Authorization` and `Cache-Control`), how it keys and looks up (honouring `Vary`), and the
TTL. It DELEGATES the actual storage to the Feature 72 backend interface (selected by
`TINA4_CACHE_BACKEND`). It is distinct from the DB query cache (Feature 72's persistent mode) and the
request-scoped auto-cache.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| References Authorization/Cache-Control rules | yes | yes (denser) | yes | yes (densest) |
| References `Vary` | yes | yes | yes | yes |
| Backend (ADR-0024) | `TINA4_CACHE_BACKEND` | same | same | same |
| Default TTL (`TINA4_CACHE_TTL`) | 60 | 60 | 60 | 60 |
| Per-directive RFC 9111 depth | leaner (source density 5-6) | denser (30) | leaner (5-6) | densest (77) |

All four implement the CORE ADR-0020 rules (they reference `Authorization`, the shared-cache
`Cache-Control` directives, and `Vary`). The concern is DEPTH parity: the source density suggests
Python and Ruby handle fewer `Cache-Control` directives than PHP and Node, so the exact set of stored
vs not-stored responses may diverge. This pass did not extract the per-directive logic (RC-80-03).

## Public surface contract (ADR-0020)

As a SHARED cache:
1. A response to a request carrying `Authorization` is NOT stored, UNLESS the response carries a
   `Cache-Control` directive that permits shared caching (`public`, `s-maxage`, or `must-revalidate`).
   This is store-side only: a response never stored can never be replayed.
2. `Vary` is honoured - the nominated request-header values are recorded with the entry and must match
   on lookup; an absent field matches only an absent field; a response whose `Vary` is `*` is never
   stored.
The middleware caches only GETs, keys by method+path (+ the `Vary` header values), stores for the TTL,
and replays the stored response on a matching lookup.

## Configuration and precedence

`TINA4_CACHE_BACKEND` selects the store (ADR-0024); `TINA4_CACHE_TTL` (default 60s) is the default TTL;
`TINA4_CACHE_MAX_ENTRIES` bounds a memory store. A response's own `Cache-Control` (`s-maxage`,
`max-age`, `no-store`, `private`) governs whether and how long it is stored, per RFC 9111.

## Failures, side effects and security

- THE SHARED-CACHE HAZARD (the reason ADR-0020 exists): replaying a private/authorized response to
  another user is a data-leak. Rule 1 prevents it store-side - an `Authorization` request's response is
  not stored unless explicitly marked shareable. This is the security core and it must hold identically
  in all four (RC-80-01: verify the store-side gate is present and equivalent, not just referenced).
- VARY CORRECTNESS: ignoring `Vary` serves the wrong representation (e.g. a gzip body to an
  identity client, or an English page to a French one). Honouring it - including never storing
  `Vary: *` - is mandatory.
- DEPTH DIVERGENCE (RC-80-03): if Python/Ruby honour fewer `Cache-Control` directives than PHP/Node, a
  response one framework declines to store another framework stores - a parity gap that a shared
  fixture must expose.

## Wire and persistence contract

A stored entry is the response (status, headers, body) plus the recorded `Vary` header values, under a
key of method+path(+Vary), in the Feature 72 backend (JSON-serialized). The observable contract: an
`Authorization` GET is not replayed to an anonymous caller unless marked shareable; a `Vary`-nominated
header change misses; the entry expires after its TTL.

## Providers and substitutability

The response cache stores into any Feature 72 backend (memory default, or redis/file/... for a shared
cache). The RFC 9111 rules are backend-agnostic; the store is pluggable.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RC-80-01 | All four REFERENCE the ADR-0020 store-side gate (`Authorization` + shareable-`Cache-Control`) and `Vary`, but this pass verified only their presence (grep), not that the gate is equivalent. The security-critical rule must be confirmed identical. | Extract the store-side gate in all four and confirm an `Authorization` GET without a shareable directive is NOT stored in every framework. |
| RC-80-02 | There is NO `response_cache_contract.json`; the RFC 9111 rules (ADR-0020) are ratified but ungated - the one cache-cluster contract not covered by a fixture. | Add `response_cache_contract.json` and wire four runners over real requests. |
| RC-80-03 | Source density suggests Python/Ruby honour fewer `Cache-Control` directives than PHP/Node; the exact stored-vs-not set may diverge. | Extract the per-directive logic in all four; pin the directive set (`public`/`s-maxage`/`must-revalidate`/`no-store`/`private`/`max-age`) and gate it. |

## Owner decisions

Proposed for owner ratification:

1. GATE ADR-0020 (RC-80-02): add `response_cache_contract.json` so the ratified RFC 9111 rules are
   proven in all four, not just decided. This is the one cache-cluster contract still ungated.
2. CONFIRM THE SECURITY GATE (RC-80-01) and PIN THE DIRECTIVE SET (RC-80-03): a follow-on extraction
   confirms the `Authorization`-not-stored gate is equivalent and pins which `Cache-Control` directives
   every framework honours, so the stored-vs-not decision is identical.

## Proposed conformance fixture

Add `response_cache_contract.json` driving four runners over REAL requests to a real server (no
doubles): an `Authorization` GET with no shareable directive is NOT replayed to an anonymous caller; the
same with `Cache-Control: public` IS shareable; a `Vary: Accept-Encoding` entry misses when the header
differs and hits when it matches; a `Vary: *` response is never stored; `no-store`/`private` are not
stored; `s-maxage`/`max-age` set the lifetime. Each case sends real HTTP and inspects the replay.

## Integration map

- Feature 72 provides the backend the response cache stores into; the dispatch layer feeds it requests.
- ADR-0020 governs the RFC 9111 rules; `response_cache_contract.json` (owed) gates them.
- The response-cache docs describe the shared-cache rules and the env vars.

## Breaking changes and migration

- Pinning the directive set (RC-80-03) may change what a leaner framework stores (Python/Ruby may begin
  honouring a directive they ignored, or stop storing something they should not have) - a correctness
  change, `Breaking:` only where a response's cacheability changes.

## Implementation backlog

1. Extract the RFC 9111 store/lookup logic in all four (close RC-80-01, RC-80-03).
2. Add `response_cache_contract.json` and wire four runners over real requests (RC-80-02).
3. Pin the directive set; fix any divergence so the stored-vs-not decision is identical.
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the response cache as an RFC 9111 SHARED cache (ADR-0020): cache only GETs; do NOT store a
response to an `Authorization` request unless it carries `public`/`s-maxage`/`must-revalidate`; honour
`Vary` (record the nominated header values, match on lookup, never store `Vary: *`); respect
`no-store`/`private` (do not store) and `s-maxage`/`max-age` (lifetime). Store into the Feature 72
backend selected by `TINA4_CACHE_BACKEND`, default TTL `TINA4_CACHE_TTL`. Prove the port with the
`response_cache_contract.json` cases over real requests: authorized-not-replayed, public-shareable,
Vary-miss/hit, Vary-* not-stored, no-store/private not-stored.

## Audit closure checklist

- [x] Boundary and public surface complete (RFC 9111 store/lookup + backend delegation).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (shared-cache hazard, Vary).
- [x] Wire/storage and provider contracts complete (entry shape, backend delegation).
- [~] Existing-language contradictions recorded (RC-80-01..03; per-directive DEPTH verified only at
  grep level - a follow-on extraction is scoped as owed work, not silently assumed).
- [x] Owner ambiguities recorded (2 proposed; gating ADR-0020 and confirming the security gate).
- [x] Proposed shared cases and mutation witnesses complete (`response_cache_contract.json` over real requests).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
