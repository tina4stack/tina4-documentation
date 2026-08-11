# Feature 120: CLI generate (delegated code-scaffolding command)

## Identity and status

- Matrix identity: 120 - `tina4 generate <what> <name> [options]` (scaffold a model / route / migration /
  middleware / test / queue / service / listener)
- Audit state: decision-ready
- Audit note: DELEGATED CLI command. The Rust binary forwards to the framework CLI; the generator
  TEMPLATES are per-framework. Measured 2026-08-11 from `tina4/src/main.rs` (`delegate_command`),
  `tina4/src/agent.rs` (the setup-flow generate helper), and the four framework CLIs (Python
  `cli/__init__.py:3269` `generate` with `GENERATORS`, plus `_gen_*` handlers; Node `bin.ts:399`; PHP
  `bin/tina4php:1442`; Ruby `lib/tina4/cli.rb`).
- Dependencies: `detect::detect_language`, the framework CLI, the per-framework scaffold templates.
- Dependants: developers scaffolding resources; the gallery/AutoCrud flows.

- Catalog phase: CLI (delegated to the framework CLI)

## Why this feature exists

`tina4 generate model User` (and route / migration / middleware / test / queue / service / listener)
writes a correct, convention-following scaffold so a developer does not hand-write boilerplate. It
forwards to the framework CLI, which owns the templates for that language.

## Boundary

This packet owns the delegation and the generator-SET parity question (does every framework offer the
same generators?). It does NOT own the individual scaffold templates (each is per-framework and their
correctness is the framework's concern), nor the subsystems they scaffold (ORM, router, migration,
queue, service runner, events).

## Existing implementation evidence

- Rust forward: `tina4 generate <what> <name>` -> `delegate_command` -> `<framework-cli> generate <what>
  <name>` (the setup helper `agent.rs:6395-6398` maps node -> `npx tina4nodejs generate`, php -> `php
  tina4php generate`, ruby -> `tina4ruby generate`, python -> `tina4python generate`).
- Python `GENERATORS` (`cli/__init__.py:3269` + the `_gen_*` handlers at ~:3242-3247): model, route,
  migration, middleware, test, queue, service, listener (each a handler + usage + summary).
- Node `generate` (`bin.ts:399`); PHP `case 'generate'` (`bin/tina4php:1442`, with nested `generate test/
  queue`); Ruby `generate`.

## Public surface contract

`tina4 generate <what> <name> [options]`, where `<what>` is one of the generators. The GENERATOR SET is
the parity axis (CLI-GEN-PARITY): Python documents model, route, migration, middleware, test, queue,
service, listener; the other three should offer the same set with the same option flags (e.g.
`generate test <name> [--model Name]`). A generator present in one framework but not another means
`tina4 generate <that>` fails on the missing one.

## Inputs and outputs

- Input: the generator kind, a name, and options. Output: one or more scaffold files written by the
  framework, plus a printed summary; exit code propagated.

## Lifecycle and operation graph

1. `tina4 generate <what> <name>` -> detect language -> `<framework-cli> generate <what> <name>`.
2. The framework resolves the generator, renders its template(s) with the name, and writes the file(s)
   (a model in `src/orm/`, a route in `src/routes/`, a migration in `migrations/`, a service in
   `src/services/`, a listener in `src/listeners/`, ...).

## Configuration and precedence

- None at the CLI layer. Generators follow the framework's directory conventions.

## Failures, side effects and security

- Writes files (a side effect the developer initiates). Confirm generators refuse to overwrite an
  existing file (or write it safely) rather than clobbering.
- A generator missing in one framework surfaces as a raw framework-CLI error (CLI-GEN-PARITY).
- No security surface.

## Wire and persistence contract

The output is scaffold files on disk. The templates and their contents are per-framework; their
correctness (do they reference the real framework API?) ties to the "docs/scaffold matches code" first
principle - a generated file must import/use APIs that actually exist.

## Providers and substitutability

The provider is the detected framework CLI and its template set. Substitution is language detection.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CLI-GEN-PARITY | The GENERATOR SET (and option flags) must be identical across the four framework CLIs so `tina4 generate <what>` works everywhere. Python documents model/route/migration/middleware/test/queue/service/listener; confirm PHP/Ruby/Node offer the same set (PHP nests `generate test`/`generate queue`; Node/Ruby TBD). A missing generator is a hard failure on that framework. | OWNER DECISION: define the canonical generator set + option flags, and ensure all four framework CLIs implement it. Add a CLI-command parity fixture that runs every generator on every language. |
| CLI-GEN-TEMPLATE-TRUTH | Each generated scaffold must reference APIs that exist in that framework (the first-principle "scaffold matches code"). A stale template scaffolds a phantom API. | Add a per-framework test that generates each kind and imports/loads the result (or type-checks it), so a template drift is caught. (This is per-framework, not a CLI change.) |
| CLI-GEN-OVERWRITE | Confirm generators do not silently clobber an existing file (the INIT-05 class of bug); they should refuse or write safely. | Verify per framework; add a refuse-if-exists (or `--force`) contract to the parity fixture. |

## Owner decisions

- CLI-GEN-DEC-01 (proposed): ratify the canonical generator set + flags; implement in all four.

## Proposed conformance fixture

Part of the CLI-command parity fixture: for a scaffolded project per language, run each generator
(`tina4 generate model/route/migration/middleware/test/queue/service/listener <name>`) and assert the
expected file(s) are written to the right directory, that a re-run does not clobber (or requires
`--force`), and (per framework) that the generated file loads/type-checks against the real API.

## Integration map

- Dispatch: `main.rs` -> `delegate_command` -> framework CLI `generate`.
- Protocol: `commands --json` (feature 122) advertises the generator subcommands.
- Templates: per-framework; the subsystems they scaffold are their own features.

## Breaking changes and migration

- Adding missing generators is additive; renaming a generator or its flags is a documented CLI change.

## Implementation backlog

1. Ratify the canonical generator set + flags (CLI-GEN-DEC-01) and implement missing ones per framework.
2. Add the generator parity fixture (every generator on every language).
3. Add per-framework template-truth and refuse-if-exists checks.

## Porting capsule

Nothing to port in the Rust CLI (forward). Each framework CLI needs a `generate` command exposing the
canonical generator set (model/route/migration/middleware/test/queue/service/listener) with matching
flags, templates that reference the real framework API, and a refuse-if-exists (or `--force`) writer. The
Rust forward detects the language and propagates the exit code.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Delegation + generator-set parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
