# Feature 007: SQL translator

## Identity and status

- Matrix identity: 7 — SQL translator
- Audit state: queued
- Dependencies: Feature 3 — Database adapter interface
- Dependants: database providers, migrations, ORM, batch writes and pagination
- Existing ADRs: see the central decision index
- Shared fixtures: `batch_write_contract.json`; SQL translation fixture required

- Catalog phase: Database and providers

## Why this feature exists

The translator gives each database provider a small set of shared, stateless SQL rewrites. It keeps dialect rules out of application queries and provider lifecycle code.

## Boundary

This packet owns the public SQL translation helpers, engine aliases, safe pagination rewrites, parameter normalization and batch-insert construction. Feature 6 owns fluent query construction. Each database provider owns the decision to apply a translation.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | `tina4_python/database/sql_translator.py` | `Tina4/SQLTranslator.php` | `lib/tina4/sql_translator.rb` | `packages/orm/src/sqlTranslator.ts` |
| Startup/CLI integration | Imported by database and ORM code | Imported by providers and ORM | Imported by database and ORM | Exported from `@tina4/orm` |
| Stored/wire format | SQL and parameter transforms | SQL and parameter transforms | SQL and parameter transforms | SQL and parameter transforms |
| Existing focused tests | `tests/test_sql_translation.py`; batch fixture tests | `tests/SQLTranslatorTest.php`; named parameter and batch tests | `spec/sql_translator_spec.rb`; batch fixture tests | `test/sqlTranslator.test.ts`; batch fixture tests |
| Existing lab baseline | Not yet run for this standalone packet | Not yet run | Not yet run | Not yet run |

## Public surface contract

The standalone audit must inventory every translator operation and assign each helper to this feature or its provider.

## Inputs and outputs

The audit must fix SQL, parameter, engine-name and batch result shapes without merging this contract back into Query Builder.

## Lifecycle and operation graph

The audit must trace each provider, ORM, migration, pagination and batch-write call site.

## Configuration and precedence

The audit must define engine aliases, parameter ceilings and provider overrides.

## Failures, side effects and security

The audit must prove that translation rejects unsafe or ambiguous SQL instead of changing its meaning.

## Wire and persistence contract

The output is executable SQL plus native parameters. The audit must preserve placeholder order and statement meaning.

## Providers and substitutability

Every SQL provider must apply the same shared rule where its dialect needs that rule. Provider-specific quoting stays with the provider.

## Contradictions and defects

This module was incorrectly bundled with Query Builder in the first flat catalogue. Its detailed cross-language contradiction register remains open.

## Owner decisions

- SQL Translator owns a separate whole-number feature.
- Query Builder constructs a query; SQL Translator rewrites that query for a database dialect.

## Proposed conformance fixture

Reuse `batch_write_contract.json`. Add a shared fixture for pagination, placeholders, comments, quoted text, engine aliases and malformed input.

## Integration map

Map public exports, every provider call site, ORM DDL, pagination and batch execution.

## Breaking changes and migration

The catalogue split changes the former Feature 8 and later identifiers by one. It does not change framework code.

## Implementation backlog

The standalone audit must produce the backlog before implementation begins.

## Porting capsule

This packet is not yet sufficient for a clean-room implementation.

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
