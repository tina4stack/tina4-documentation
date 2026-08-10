# Feature 031: Route groups

## Identity and status

- Matrix identity: 31 — Route groups
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: Feature 30 router/dispatch and Feature 32 middleware
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: ADR-0015 and ADR-0019
- Shared fixtures: not yet confirmed

- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously hidden in the 11/12/79 bundle

## Why this feature exists

A route group lets an engineer apply one prefix and one policy chain to a set of
routes without changing how those routes match or dispatch.

## Boundary

Feature 31 owns deterministic prefix joining, nested group composition,
middleware inheritance/order and group-level policy declarations. It does not
own route matching precedence, middleware hook execution or CLI rendering.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Historical evidence retained

The old audit fixed three Python defects: group middleware ran twice, a nested
prefix was dropped, and merely adding middleware disabled the write-route auth
gate. PHP, Ruby and Node were already correct on those measured cases.

Two gaps remained:

- Ruby accepted and displayed `auth_handler:` on a group but dispatch never
  called it, creating a false security declaration.
- Only PHP normalized all leading/trailing slash combinations. Python, Ruby and
  Node could form `/apiusers`, a path without a leading slash or `/api//users`.

Only Python received the historical group regression suite. The standalone
audit must establish one prefix grammar, one inheritance/order formula, an
explicit group-auth decision and a shared nested-group fixture for every
current and future language.

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

No contradiction-free conclusion has been extracted from the retained audit evidence.

## Owner decisions

No new owner decision is recorded in this migrated section. Retained decisions appear below when present.

## Proposed conformance fixture

The audit has not yet produced the complete shared cases and mutation witnesses required for a parity gate.

## Integration map

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

## Breaking changes and migration

The audit has not yet turned every parity break into an actionable pre-3.14 migration instruction.

## Implementation backlog

The audit has not yet produced a dependency-ordered backlog for all current languages and future ports.

## Porting capsule

This packet is not yet sufficient for a clean-room implementation without reading an existing runtime.

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
