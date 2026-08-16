# Tina4 Decision Log (ADRs)

The durable record of architecture/API decisions across all four frameworks: WHAT we
decided, WHEN, and (the part that gets lost over months) WHY, and which alternatives we
rejected at the time. Search this before changing a contract. You may not silently
re-decide a logged decision: supersede its ADR explicitly (new entry, mark the old
`Superseded by ADR-NNNN`).

Conventions:
- **One FILE per decision**: `plan/v3/decisions/ADR-NNNN.md`. This file is the INDEX.
  The number is the filename, so two parallel branches can never collide on one line -
  the failure that produced a four-way conflict on 2026-08-01 (see ADR-0019..0022).
- ID `ADR-NNNN` (zero-padded, monotonic). Claim the number AND create the file up front.
- Anchor it in the code: a `tina4: ADR-NNNN` comment at the decision site, and the
  lock-in/regression test names the ADR ID. That makes "why is this a bool?" one grep.
- Status: Proposed | Accepted | Prototype-gated | Superseded | Rejected.

---

## Index

| ID | Decision | Status |
| --- | --- | --- |
| ADR-0001 | [Introduce an ahead-of-time "compile" layer across all four frameworks](decisions/ADR-0001.md) | Prototype-gated |
| ADR-0002 | [Metrics engine moves into the tina4 Rust CLI (language-agnostic)](decisions/ADR-0002.md) | Prototype-gated |
| ADR-0003 | [Program order: template compile + Frond parity first, THEN the maintainability sweep, THEN the rest of the compile layer](decisions/ADR-0003.md) | Accepted |
| ADR-0004 | [Best implementation prevails: parity flows BOTH ways, and audits rank quality](decisions/ADR-0004.md) | Accepted |
| ADR-0005 | [Frond tracks Twig and Jinja2, not Blade: fragment/push/stack/switch are dropped](decisions/ADR-0005.md) | Accepted |
| ADR-0006 | [We own only OUR Dockerfiles; competitor images are official/community, cited](decisions/ADR-0006.md) | Accepted |
| ADR-0007 | [Base images stay on official runtime images; we do not compile a runtime to shrink one](decisions/ADR-0007.md) | Accepted |
| ADR-0008 | [A property name is a column name: no framework rewrites it silently](decisions/ADR-0008.md) | Accepted |
| ADR-0009 | [One folder per feature, in all four frameworks, so a feature can be deleted](decisions/ADR-0009.md) | Accepted |
| ADR-0010 | [Routes beat files - static assets resolve AFTER route matching](decisions/ADR-0010.md) | Accepted |
| ADR-0011 | [HEAD keeps its per-runtime mechanism - outcome parity, not mechanism parity](decisions/ADR-0011.md) | Accepted |
| ADR-0012 | [Settle a contract against real-world frameworks, not internal precedent](decisions/ADR-0012.md) | Accepted |
| ADR-0013 | [A CORS preflight carries Allow (RFC 9110 s9.3.7 conformance)](decisions/ADR-0013.md) | Accepted |
| ADR-0014 | [A middleware's return value is the contract; response state is a legacy path](decisions/ADR-0014.md) (result-table clause superseded by ADR-0045) | Accepted |
| ADR-0015 | [Route precedence - does a specific route beat a catch-all?](decisions/ADR-0015.md) | Accepted |
| ADR-0016 | [Liveness is process-only; readiness is a separate endpoint](decisions/ADR-0016.md) (clauses superseded by ADR-0046) | Accepted |
| ADR-0017 | [Graceful shutdown - drain in-flight requests, bounded, exit 0](decisions/ADR-0017.md) (clauses superseded by ADR-0047) | Accepted |
| ADR-0018 | [CORS denies by default, and never pairs the wildcard with credentials](decisions/ADR-0018.md) (enforcement clauses superseded by ADR-0048) | Accepted |
| ADR-0019 | [The rate limiter keys on the socket peer, and middleware never opens a gate](decisions/ADR-0019.md) (clauses superseded by ADR-0049 and ADR-0050) | Accepted |
| ADR-0020 | [The shared response cache obeys RFC 9111 on Authorization and Vary](decisions/ADR-0020.md) | Accepted |
| ADR-0021 | [A session id is opaque, and an unverified credential is not an auth result](decisions/ADR-0021.md) | Accepted |
| ADR-0022 | [The queue promises at-least-once, and each backend keeps that promise the way its protocol allows](decisions/ADR-0022.md) | Accepted |
| ADR-0023 | [The queue ack surface is job-centric, and a dead letter is a QUEUE](decisions/ADR-0023.md) | Accepted |
| ADR-0024 | [The swap must work - a provider is an env var, never a code change](decisions/ADR-0024.md) | Accepted |
| ADR-0025 | [The DocStore fallback imitates the driver - it is never the driver's job to imitate us](decisions/ADR-0025.md) | Accepted |
| ADR-0026 | [The document store is named for the CATEGORY, never for one of its backends](decisions/ADR-0026.md) | Accepted |
| ADR-0030 | [A query-cache key names the DATABASE it came from](decisions/ADR-0030.md) | Accepted |
| ADR-0031 | [memcached invalidates by NAMESPACE GENERATION, and redis clears by SCAN](decisions/ADR-0031.md) | Accepted |
| ADR-0032 | [sweep() returns entries EVICTED, and a server-expiring provider honestly returns 0](decisions/ADR-0032.md) | Accepted |
| ADR-0037 | [The no-skip gate is a deny-list, not a two-axis allow-list](decisions/ADR-0037.md) | Proposed |
| ADR-0038 | [One canonical TINA4_TEST_* set, enforced by a gate](decisions/ADR-0038.md) | Accepted |
| ADR-0039 | [Defend, report, then replace. Never fork a dependency.](decisions/ADR-0039.md) | Accepted |
| ADR-0040 | [Ruby's file queue adopts the canonical store layout](decisions/ADR-0040.md) | Accepted |
| ADR-0041 | [An explicit argument always beats the environment](decisions/ADR-0041.md) | Accepted |
| ADR-0042 | [The messenger uid is the IMAP UID, never a sequence number](decisions/ADR-0042.md) | Accepted |
| ADR-0043 | [The paginate envelope is seven snake_case keys, derived from the query](decisions/ADR-0043.md) | Accepted |
| ADR-0044 | [Batch and first-row execution are adapter primitives](decisions/ADR-0044.md) | Accepted |
| ADR-0045 | [Middleware before/after hooks use phase-specific result tables](decisions/ADR-0045.md) (supersedes ADR-0014 clause) | Proposed |
| ADR-0046 | [Health owns a system-route tier, monotonic uptime and readiness](decisions/ADR-0046.md) (supersedes ADR-0016 clauses) | Proposed |
| ADR-0047 | [Graceful shutdown: six-state machine, bounded drain + cleanup reserve](decisions/ADR-0047.md) (supersedes ADR-0017 clauses) | Proposed |
| ADR-0048 | [CORS wildcard-credentials fails startup; per-origin warnings bounded](decisions/ADR-0048.md) (supersedes ADR-0018 clauses) | Proposed |
| ADR-0049 | [Rate limiting on by default, token bucket, canonical-IP keyed](decisions/ADR-0049.md) (supersedes ADR-0019 clauses) | Proposed |
| ADR-0050 | [One buffered response, strict recursive JSON, explicit representation types](decisions/ADR-0050.md) (supersedes ADR-0019 clauses) | Proposed |
| ADR-0051 | [Systemic ORM row-cap: unbounded reads, pagination the only limiter](decisions/ADR-0051.md) (net-new; consolidates Features 5/21/22/23/24 row-cap clauses) | Proposed |
| ADR-0052 | [Frond extension registration scope follows the call target](decisions/ADR-0052.md) (resolves Feature 56 EX-DEC-01) | Accepted |
| ADR-0053 | [One zero-dependency app-facing AI client contract](decisions/ADR-0053.md) (resolves Feature 135) | Accepted |
| ADR-0054 | [Frameworks consume metrics; the native CLI owns metrics](decisions/ADR-0054.md) (completes ADR-0002) | Accepted |
| ADR-0055 | [Metrics measures production code and reports evidence honestly](decisions/ADR-0055.md) (resolves Feature 121) | Accepted |

### 3.14 re-audit supersessions (Proposed, pending build-phase acceptance)

ADR-0045..0048 are the feature re-audit decisions taken 2026-08-10. Each supersedes
only the named clauses of its predecessor; the predecessors otherwise stay in force.
When each is Accepted in the build phase, flip the superseded predecessor's file to
carry a `Superseded (in part) by ADR-004N` marker.

| New | Supersedes | Predecessor keeps |
| --- | --- | --- |
| ADR-0045 | ADR-0014 "same table on every hook" | return-value-is-the-contract core |
| ADR-0046 | ADR-0016 system-route/uptime/readiness/path/header clauses | liveness/readiness split |
| ADR-0047 | ADR-0017 state-machine/deadline/validation/hook/worker clauses | drain-bounded-exit-0 intent |
| ADR-0048 | ADR-0018 wildcard-credentials fallback + per-origin warning | deny-by-default, 204-on-denial, allow-list Vary |
| ADR-0049 | ADR-0019 skip-and-log malformed trusted-proxy | socket-peer keying + trusted-proxy allow-list, middleware-never-opens-a-gate |
| ADR-0050 | ADR-0019 response-type status/429 clauses | routing-surface security intent (rate-limiter clauses -> ADR-0049) |
