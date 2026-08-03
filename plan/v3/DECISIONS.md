# Tina4 Decision Log (ADRs)

The durable record of architecture/API decisions across all four frameworks: WHAT we
decided, WHEN, and — the part that gets lost over months — WHY, and which alternatives we
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
| ADR-0014 | [A middleware's return value is the contract; response state is a legacy path](decisions/ADR-0014.md) | Accepted |
| ADR-0015 | [Route precedence - does a specific route beat a catch-all?](decisions/ADR-0015.md) | Accepted |
| ADR-0016 | [Liveness is process-only; readiness is a separate endpoint](decisions/ADR-0016.md) | Accepted |
| ADR-0017 | [Graceful shutdown - drain in-flight requests, bounded, exit 0](decisions/ADR-0017.md) | Accepted |
| ADR-0018 | [CORS denies by default, and never pairs the wildcard with credentials](decisions/ADR-0018.md) | Accepted |
| ADR-0019 | [The rate limiter keys on the socket peer, and middleware never opens a gate](decisions/ADR-0019.md) | Accepted |
| ADR-0020 | [The shared response cache obeys RFC 9111 on Authorization and Vary](decisions/ADR-0020.md) | Accepted |
| ADR-0021 | [A session id is opaque, and an unverified credential is not an auth result](decisions/ADR-0021.md) | Accepted |
| ADR-0022 | [The queue promises at-least-once, and each backend keeps that promise the way its protocol allows](decisions/ADR-0022.md) | Accepted |
| ADR-0023 | [The queue ack surface is job-centric, and a dead letter is a QUEUE](decisions/ADR-0023.md) | Accepted |
| ADR-0024 | [The swap must work - a provider is an env var, never a code change](decisions/ADR-0024.md) | Accepted |
| ADR-0025 | [The DocStore fallback imitates the driver - it is never the driver's job to imitate us](decisions/ADR-0025.md) | Proposed |
