# Feature 115: CLI routes (delegated route-inspection command)

## Identity and status

- Matrix identity: 115 - `tina4 routes` (list the project's registered routes)
- Audit state: decision-ready
- Audit note: DELEGATED CLI command. The Rust binary forwards to the framework CLI, which boots the app
  far enough to discover routes and prints them. Measured 2026-08-11 from `tina4/src/main.rs`
  (`delegate_command`) and the four framework CLIs (Python `cli/__init__.py:3264`, PHP
  `bin/tina4php:1355`, Node `bin.ts:379`, Ruby `lib/tina4/cli.rb`).
- Dependencies: `detect::detect_language`, the framework CLI, the router (route discovery).
- Dependants: developers inspecting their route table; debugging 404s.
- Existing ADRs: none dedicated.

- Catalog phase: CLI (delegated to the framework CLI)

## Why this feature exists

`tina4 routes` prints the registered routes (method, path, handler) so a developer can see what the app
exposes without reading every route file. It forwards to the framework CLI, which runs route
auto-discovery and formats the table.

## Boundary

This packet owns the delegation and the output-parity question (does every framework print the same route
table shape?). It does NOT own the router or route discovery (a separate feature).

## Existing implementation evidence

- Rust forward: `tina4 routes` -> `delegate_command` -> `<framework-cli> routes`, exit code propagated.
- Framework CLI entries: Python `routes` (`cli/__init__.py:3264`), PHP `case 'routes'`
  (`bin/tina4php:1355`), Node `routes` (`bin.ts:379`), Ruby `routes`. All four expose it.

## Public surface contract

`tina4 routes` lists routes. No documented subcommands or flags at the CLI layer. The output columns
(method, path, handler, auth) are the framework's; whether the four print the same columns in the same
order is the parity question (CLI-ROUTES-FORMAT).

## Inputs and outputs

- Input: the project's route files. Output: a printed route table and exit 0, forwarded from the
  framework CLI. Route discovery requires the framework to import the route files (a side effect: any
  import-time code runs).

## Lifecycle and operation graph

1. `tina4 routes` -> detect language -> `<framework-cli> routes`.
2. The framework runs auto-discovery over `src/routes/`, collects the registered routes, and prints them.

## Configuration and precedence

- None at the CLI layer. The framework reads its own route directory convention.

## Failures, side effects and security

- Route discovery imports the route files, so any module-level side effect executes (the same caveat as
  the framework's own startup). This is inherent to a reflection-based route list.
- No security surface; it prints the developer's own routes.

## Wire and persistence contract

No persisted state. The output is a formatted table (human-readable). There is no `--json` documented at
the CLI layer (confirm; a machine-readable form would help tooling).

## Providers and substitutability

The provider is the detected framework CLI. Substitution is language detection.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CLI-ROUTES-FORMAT | Confirm the four framework `routes` commands print the same columns (method, path, handler, auth flag) in the same order, so `tina4 routes` output is uniform. Divergent columns make cross-framework tooling and docs harder. | Standardize the route-table columns across the four framework CLIs; add a `--json` form for tooling. |
| CLI-ROUTES-IMPORT | Listing routes imports the route files (module-level side effects run). Inherent, but a route file that does real work at import (opens a DB, hits the network) makes `tina4 routes` slow or side-effectful. | Document that route files should be side-effect-free at import (the framework already leans this way); no code change. |

## Owner decisions

- CLI-ROUTES-DEC-01 (proposed): standardize the route-table columns + add `--json` across the four.

## Proposed conformance fixture

Part of the CLI-command parity fixture: a scaffolded project per language with two known routes; assert
`tina4 routes` lists both with the same columns/order across the four, and (once added) that `--json`
returns the same schema.

## Integration map

- Dispatch: `main.rs` -> `delegate_command` -> framework CLI `routes`.
- Protocol: `commands --json` (feature 122).
- Router: route discovery (separate feature).

## Breaking changes and migration

- Standardizing columns / adding `--json` is additive; a column reorder is a cosmetic output change to
  document.

## Implementation backlog

1. Standardize the route-table columns and add `--json` across the four framework CLIs.
2. Add the routes entry to the CLI-command parity fixture.

## Porting capsule

Nothing to port in the Rust CLI (forward). Each framework CLI needs a `routes` command that runs route
discovery and prints a uniform table (method, path, handler, auth) plus an optional `--json`. The Rust
forward detects the language and propagates the exit code.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Delegation + output parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
