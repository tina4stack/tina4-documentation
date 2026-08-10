# Feature 048: Frond lexer

## Identity and status

- Matrix identity: 48 — Frond lexer
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: ADR-0009
- Shared fixtures: `frond_expression_corpus.txt`, 82 cases

- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-07-28, previously bundled with Features 49-50

## Why this feature exists

The lexer turns Frond source into one portable token stream with useful source
positions and lexical errors.

## Boundary

Feature 48 owns source tokenization, token positions, lexical errors, whitespace
controls and the token stream passed to Feature 49. It does not own AST
construction, compilation, execution or filters.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Startup/CLI integration | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Stored/wire format | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing focused tests | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |
| Existing lab baseline | Not yet extracted | Not yet extracted | Not yet extracted | Not yet extracted |

The audit has not yet recorded implementation evidence in the canonical cross-language table.

Python was the only port with partially separated Frond units. PHP had two
large files; Ruby and Node each held the whole engine in one file. ADR-0009
requires a removable Frond folder and an explicit lexer behind the unchanged
public `Frond` entry point.

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
