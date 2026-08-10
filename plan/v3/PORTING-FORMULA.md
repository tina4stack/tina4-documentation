# Tina4 language implementation formula

Owner decision, 2026-08-08: the feature audit must produce enough
language-neutral information to implement Tina4 in another language without
reverse-engineering any of the four existing implementations.

## The formula

```
new Tina4 implementation
  = language runtime shell
  + sum(audited feature contract packets)
  + shared conformance runner
  + required provider integrations
  + packaging, CLI and documentation surface
```

The four existing frameworks are evidence used to discover the contract. They
are not the specification another implementation must copy. Once an audit row
closes, its contract packet must be sufficient without reading Python, PHP,
Ruby or Node source.

The direction is deliberately bidirectional:

```
four implementations -> audit evidence -> language-neutral contract packet
language-neutral contract packet -> conformance runner -> every implementation
```

The packet used to build a new language is therefore the same oracle used to
detect parity drift in Python, PHP, Ruby, Node and every later implementation.
No existing runtime is permanently the reference implementation.

## The useful-value principle

Tina4 owns the conversion work when it has enough information to do that work
safely and consistently. A public framework boundary returns the value an
engineer can use immediately, not an encoded transport or storage
representation that every caller must decode again.

If ordinary application code repeatedly has to parse, cast, unwrap or reshape a
value returned by Tina4, the framework boundary is incomplete. Keep an explicit
raw escape hatch where the representation itself matters, but make the ordinary
path native, predictable and ready to use. This is the operational form of
Tina4's existing "gets out of the way" and human-and-AI simplicity principles.

## Decision authority

The audit may settle a rule when standards, security, data integrity or measured
cross-language behavior produce one clear answer. When two or more defensible
rules remain, the auditor must not silently promote one implementation. Record:

- the exact decision question;
- the observable alternatives;
- compatibility, safety and implementation consequences of each; and
- the current behavior of every implementation.

The owner then chooses the Tina4 rule. That decision is recorded in an ADR,
encoded in the shared fixture, added to the porting capsule and enforced against
all languages. An unresolved owner decision keeps the feature open.

## 3.14.0 stabilization boundary

Tina4 3.14.0 is the target stable release. The audit is authorized to make
breaking changes before 3.14.0 whenever they are needed for parity, correctness,
security, simplicity or a coherent new-language contract. Pre-stable behavior is
evidence, not a compatibility obligation.

This permits removing or renaming APIs, changing defaults, correcting return and
error shapes, changing generated artefacts, and deleting contradictory legacy
paths. It does not permit an undocumented break: every change must have an ADR
where a choice was involved, executable conformance coverage, an explicit
`Breaking:` release entry and an actionable migration instruction.

Compatibility aliases are not the default before 3.14. They retain two names or
two behaviors for one concept and make the porting contract ambiguous. Keep one
only when the owner explicitly decides that it is part of the stable contract.

At 3.14.0, the audited language-neutral packets and their fixtures become the
stable behavioral baseline for every current and future language.

## Audit-first sequencing

Complete the full feature audit before implementing fixes. The audit phase may
read source, run existing tests and real-system probes, measure behavior, settle
rules, design fixtures and record a dependency-ordered backlog. It does not edit
framework code or add implementation tests.

This prevents an early fix from hardening a local decision before later features
reveal a conflicting lifecycle, wire shape or shared abstraction. Once every
feature has a decision-ready contract packet, implementation proceeds in
dependency order, adds the shared fixtures and mutation witnesses, and validates
all languages against the complete contract.

## One contract packet per feature

Every audited feature must leave these ten implementation inputs:

1. **Purpose and boundary** — what the feature owns, what it delegates, and what
   is explicitly outside its scope.
2. **Public surface** — constructors, functions, methods, properties, CLI
   commands, environment variables and endpoints. The concept name is fixed;
   only language-idiomatic casing and unavoidable type syntax may vary.
3. **Inputs and outputs** — canonical types, required/optional fields, defaults,
   nullability, ordering and exact serialized shapes.
4. **Lifecycle/state machine** — valid states and the complete producer ->
   discover -> execute -> inspect -> retry/rollback/delete operation graph.
   Every artefact one operation creates must be consumable by the next.
5. **Precedence and configuration** — explicit argument, runtime environment,
   project file and default ordering, including when values are read and whether
   they are cached.
6. **Failure and side-effect policy** — error categories, return/raise boundary,
   logging, atomicity, idempotency, cleanup and which operations may write,
   delete, connect, spawn or terminate.
7. **Wire and persistence contract** — protocols, HTTP status/headers, database
   schema, filenames, encodings, timestamps and compatibility rules. These must
   be language-neutral and interoperable across implementations.
8. **Provider contract** — the interface and substitutability rules for every
   database, cache, queue, mail or other backend, including unavailable-provider
   behavior.
9. **Executable conformance cases** — one shared data fixture containing the
   positive, negative, malformed, stale, duplicate and partial-state cases,
   plus expected outcomes. Framework-specific copies must be byte-identical or
   generated from one canonical source.
10. **Integration map** — package exports, server startup hook, request lifecycle,
    CLI registration, scaffolder output, diagnostics/status, documentation and
    release migration notes.

Each feature plan ends with a **Porting capsule** containing those ten items or
links to their authoritative fixture/ADR/spec sections. A capsule containing
phrases such as "works like Python" or "copy the PHP implementation" is
incomplete.

## One feature, one file

Every feature and every numbered variant member owns one Markdown contract
packet under `features/`, using `FEATURE-TEMPLATE.md`. A combined audit may share
evidence, but it may not replace the individual files. Component bundles such as
11/12/79, 28-31 and 41/42 must be split as their rows are re-audited. Variant
members such as 4.1-4.7 each receive their own packet because substitutability can
fail in one provider while the group appears green.

Retired numbers receive a short tombstone packet pointing to the replacement;
they are never reused. This preserves old audit, issue and release references.
The contract map indexes every packet and is invalid if an active or retired
feature identity has no file.

## Implementation order for a new language

1. Build the package layout, public namespace, error base types, canonical
   framework-constant registry, configuration bootstrap, logging bootstrap and
   test entry point. Constants referenced by configuration must exist before
   dotenv parsing in every language.
2. Add the shared conformance runner before feature code. It must report every
   discovered contract case and fail on unknown, missing, duplicated or skipped
   cases.
3. Implement features in dependency order recorded in the feature matrix, not
   numeric order where those differ.
4. For each feature, implement the public surface and state machine directly
   from its contract packet, then run its shared fixture.
5. Add real provider integrations and run the identical application cases on
   the lab. A mock can aid unit development but cannot satisfy conformance.
6. Wire the feature into startup, CLI, scaffolding, status/doctor and docs; prove
   that generated artefacts are discoverable and executable.
7. Run focused contracts, the complete suite and cross-language interoperability
   cases at the exact release HEAD with required services enabled and zero skips.

## Acceptance equation

```
feature implemented
  = surface complete
  AND state transitions complete
  AND shared cases discovered exactly once
  AND positive and negative cases pass
  AND mutation witness fails for the intended reason
  AND real providers pass with zero skips
  AND startup/CLI/docs agree
  AND full suite passes
```

A new language reaches Tina4 parity only when every required feature packet
satisfies that equation. Matching class names or reaching a green language-only
suite is not parity.

The same equation is run against every existing language after any packet or
fixture change. A contract update is incomplete until all affected runtimes
either conform or are explicitly recorded as failing/open; a green result in one
language never redefines the rule by itself.

## Audit completion criterion

The current audit is complete only when:

- every feature has a language-neutral porting capsule;
- the dependency order between feature packets is explicit;
- all shared fixtures can be consumed by a new runner without framework-specific
  knowledge;
- boot, CLI, packaging, project generation and release behavior are specified in
  addition to library APIs; and
- a clean-room implementation can be built from these artifacts without reading
  an existing framework's source.

The clean-room test is the final test of the audit itself: if an implementer must
ask which current language to copy, the audit has not yet produced the formula.
