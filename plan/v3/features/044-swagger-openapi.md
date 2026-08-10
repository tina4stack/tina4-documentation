# Feature 044: Swagger and OpenAPI

## Identity and status

- Matrix identity: 44 — Swagger and OpenAPI
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: Feature 1 configuration, Feature 29 responses and Feature 30 routes
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: see retained evidence and the central decision index
- Shared fixtures: not yet confirmed

- Current state: reopened / queued for a standalone 3.14 audit
- Evidence outside the old 32: Layer-2 contract map with 10 invariants

## Why this feature exists

An engineer needs one generated API contract and one optional Swagger UI that
describe the routes the application will dispatch.

## Boundary

Feature 44 owns OpenAPI document generation, route/schema/security metadata,
the configured description and the enable/serve policy for Swagger UI. Routes
belong to Feature 30 and response delivery belongs to Feature 29.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Startup/CLI integration | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Stored/wire format | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing focused tests | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing lab baseline | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |

The audit has not yet recorded implementation evidence in the canonical cross-language table.

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
