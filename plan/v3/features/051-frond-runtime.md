# Feature 051: Frond runtime

## Identity and status

- Matrix identity: 51 — Frond runtime
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: ADR-0009
- Shared fixtures: `frond_expression_corpus.txt`, 82 cases

- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-07-28, previously bundled with Features 48-49

## Why this feature exists

The runtime executes compiled Frond templates against application context and
returns deterministic rendered bytes.

## Boundary

Feature 51 owns context lookup, scopes, inheritance state, macro and block calls,
runtime errors and rendered bytes. Filters, escaping, sandboxing and caches keep
their own numbered contracts.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Startup/CLI integration | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Stored/wire format | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing focused tests | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing lab baseline | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |

The audit has not yet recorded implementation evidence in the canonical cross-language table.

The historical audit found the largest Frond complexity in runtime evaluation,
including Node's `evalVarInner` at cyclomatic complexity 74.

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
