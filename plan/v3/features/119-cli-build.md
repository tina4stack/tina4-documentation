# Feature 119: CLI build (delegated asset/container build)

## Identity and status

- Matrix identity: 119 - `tina4 build [--no-minify]` (build assets / compile for the project)
- Audit state: decision-ready
- Audit note: DELEGATED CLI command with a Rust-side flag. `Commands::Build { no_minify }`
  (`main.rs:165,439`) forwards to the framework CLI via `delegate_command(vec!["build"])` (`main.rs:450`).
  The build STEPS (SCSS compile, TS build, asset bundling, minify) are per-framework. Measured 2026-08-11
  from `tina4/src/main.rs` and the framework CLIs (PHP `bin/tina4php:1435` `case 'build'`; Python/Ruby/
  Node build entries).
- Dependencies: `detect::detect_language`, the framework CLI, the asset toolchain (grass/SCSS, tsc, etc.).
- Dependants: production deploys; `tina4 deploy` (docker images).

- Catalog phase: CLI (delegated to the framework CLI, Rust flag)

## Why this feature exists

`tina4 build` produces the production artifacts a project needs before deploy: compiled SCSS, bundled/
minified JS, a TypeScript build. `--no-minify` produces readable output for debugging. It forwards to the
framework CLI, which owns the per-language build steps.

## Boundary

This packet owns the delegation, the `--no-minify` flag, and the build-parity question. It does NOT own
the individual build steps (SCSS via grass, `tsc`, asset bundling) or the deploy packaging (feature 125).

## Existing implementation evidence

- Rust: `Commands::Build { no_minify }` (`main.rs:439`) -> `delegate_command(vec!["build"])`
  (`main.rs:450`). CONFIRM whether `--no-minify` is forwarded to the framework CLI (the delegate call
  shown passes only `build`) - if it is dropped, `--no-minify` is a no-op (BUILD-FLAG).
- Framework CLI: PHP `case 'build'` (`bin/tina4php:1435`); Python/Ruby/Node build entries.

## Public surface contract

`tina4 build [--no-minify]`. The build STEPS are the framework's; the parity question (BUILD-PARITY) is
whether every framework's `build` does the equivalent (compile SCSS at minimum; TS build for Node;
asset minify unless `--no-minify`).

## Inputs and outputs

- Input: the project's source (SCSS, TS, assets) and the `--no-minify` flag. Output: build artifacts
  (compiled CSS, dist/); exit code propagated.

## Lifecycle and operation graph

1. `tina4 build [--no-minify]` -> detect language -> `<framework-cli> build [...]`.
2. The framework runs its build (SCSS -> CSS, TS -> JS, minify), writing artifacts.

## Configuration and precedence

- None at the CLI layer beyond `--no-minify`. Build config is the framework's (tsconfig, SCSS paths).

## Failures, side effects and security

- Writes build artifacts. Exit code propagated so a failed build fails a deploy pipeline.
- BUILD-FLAG: if `--no-minify` is not forwarded to the framework CLI, it silently does nothing.

## Wire and persistence contract

Artifacts on disk (compiled CSS, dist/). No manifest.

## Providers and substitutability

The provider is the framework CLI's build. Substitution is language detection. (Note the CLI compiles SCSS
natively via grass during `serve`; `build` is the framework's production build.)

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| BUILD-FLAG | The `Commands::Build` dispatch forwards `delegate_command(vec!["build"])` without the `--no-minify` flag (per the code shown). If the flag is not passed through, `tina4 build --no-minify` is a no-op. | Confirm and, if dropped, forward `--no-minify` to the framework CLI (or handle minify in the Rust step). Add a test that `--no-minify` produces unminified output. |
| BUILD-PARITY | Confirm every framework's `build` does the equivalent set (SCSS compile at minimum; TS build for Node; minify honoring `--no-minify`), so `tina4 build` is uniform. | Standardize the build contract across the four framework CLIs; add to the CLI-command parity fixture. |
| BUILD-DOC | `tina4 build` is not listed in the CLI `CLAUDE.md` commands section (which lists setup/init/serve/doctor/install/generate/migrate/test/routes/metrics/scss/ai/deploy/update). A real command missing from the docs violates the "docs match code" first principle. | Add `build` (and `env`, similarly missing) to the CLI `CLAUDE.md` command list. |

## Owner decisions

- BUILD-DEC-01 (proposed): confirm/forward `--no-minify`; standardize the build contract; document the
  command.

## Proposed conformance fixture

Part of the CLI-command parity fixture: for a scaffolded project with SCSS (and, for Node, TS), assert
`tina4 build` produces the compiled artifacts, and `--no-minify` produces unminified output, identically
across the frameworks that have assets to build.

## Integration map

- Dispatch: `main.rs` `Commands::Build` -> `delegate_command` -> framework CLI `build`.
- Consumers: `tina4 deploy` (docker), production pipelines.
- Toolchain: grass/SCSS, tsc, framework bundlers.

## Breaking changes and migration

- Forwarding `--no-minify` (if currently dropped) changes its behaviour from no-op to real - additive/
  fixing.

## Implementation backlog

1. Confirm/forward `--no-minify` (BUILD-FLAG) with a test.
2. Standardize the build contract across the four (BUILD-PARITY).
3. Add `build` + `env` to the CLI `CLAUDE.md` command list (BUILD-DOC).

## Porting capsule

Nothing to port in the Rust CLI beyond forwarding the flag. Each framework CLI needs a `build` that
compiles SCSS (and TS for Node), bundles/minifies assets, and honors `--no-minify`. The Rust dispatch
must forward the flag and propagate the exit code.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Delegation + flag + build parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
