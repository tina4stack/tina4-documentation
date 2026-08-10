# Feature 064: Session lifecycle

## Identity and status

- Matrix identity: 64 — Session lifecycle
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: ADR-0021
- Shared fixtures: not yet confirmed

- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously bundled with Feature 63
- Required provider packets: Feature 65 file, Feature 66 Redis, Feature 67
  Valkey, Feature 68 MongoDB, Feature 69 database and Feature 70 memcached

Feature 64 owns session-ID generation/adoption, fixation defense, data
semantics, regeneration/destruction, cookie integration, dirty/save behavior,
backend failure policy and the common provider interface. JWT validation and
request authentication belong to Feature 63.

## Why this feature exists

The retained audit does not yet state the developer problem in one language-neutral sentence.

## Boundary

The retained audit does not yet separate what this feature owns, delegates, and excludes.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Historical evidence retained

The bundled audit reproduced attacker-controlled path traversal through file
session IDs in PHP and Node. It standardized the accepted ID alphabet,
known-session adoption and hashed file names. It also found that a store outage
could be mistaken for an unknown ID and rotate every user's session; the final
rule preserves the supplied ID on transport failure and discards it only when a
healthy store reports a miss.

Open parity gaps remain:

- session entropy was 128 or 256 bits;
- `set()` was lazy in Python/Ruby and eager in PHP/Node;
- `all()` hid four different sets of internal keys;
- Ruby returned the default for a stored `false`;
- invalid HttpOnly config failed open in Python/PHP;
- provider tests and failure behavior were not proven uniformly against live
  backends.

The standalone audit must settle the surface contract first, then give Features
65-70 their own conformance packet and shared fixture report.

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
