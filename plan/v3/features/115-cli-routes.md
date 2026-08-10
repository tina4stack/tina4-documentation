# Feature 115: CLI route inspection

## Identity and status

- Matrix identity: 115 — CLI route inspection
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: Feature 31 router/dispatch and Feature 32 route groups
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: ADR-0015 follow-on for visible resolution order
- Shared fixtures: not yet confirmed

- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously hidden in the 11/12/79 bundle

## Why this feature exists

An engineer needs one command that shows the effective route table in the same
order the router will resolve it.

## Boundary

Feature 115 owns application boot and discovery for inspection, human and
machine output, route order, middleware/auth visibility and CLI exit behavior.
Matching belongs to Feature 31 and group composition belongs to Feature 32.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Historical evidence retained

| Port | Historical source | Boots app | Preserves order | `--json` |
| --- | --- | --- | --- | --- |
| Python | `Router.get_routes()` after importing `app` | partial | yes | no |
| PHP | nonexistent `Router::list()` | attempted | no | no |
| Ruby | `Tina4::Router.routes` after `initialize!` | yes | yes | no |
| Node | filesystem scan of `src/routes` | no | no | no |

The PHP command fatally called a method that did not exist. Python omitted
auto-discovered route files, Node omitted programmatic routes and sorted by path
instead of resolution order, and none displayed middleware. No port had a
behavioral command test; manifest checks proved only that the command name
existed.

The standalone audit must define one route-table record, exact order, boot
failure behavior, `--json` report and real generated/programmatic/grouped route
fixtures before this feature can be final.

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
