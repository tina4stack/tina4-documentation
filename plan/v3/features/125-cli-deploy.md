# Feature 125: CLI deploy (native deployment scaffolding)

## Identity and status

- Matrix identity: 125 - `tina4 deploy <target> [--runtime R] [--force]`
- Audit state: decision-ready
- Audit note: NATIVE Rust command. Generates deployment scaffolding (Docker, systemd, nginx, cpanel).
  Measured 2026-08-11 from `tina4/src/deploy.rs` (dispatched at `main.rs:453` `Commands::Deploy { target,
  runtime, force }`) and the CLI `CLAUDE.md`. Not a four-language feature (it writes deploy files for the
  detected project).
- Dependencies: `detect::detect_language` (to pick the right base image/runtime), the target templates.
- Dependants: users deploying to Docker/systemd/nginx/cpanel.
- Existing ADRs: none dedicated.

- Catalog phase: CLI (native Rust)

## Why this feature exists

`tina4 deploy docker` writes a Dockerfile (and companions) tuned to the project's language and, for PHP,
its server runtime. It saves a developer from hand-writing a correct container/nginx/systemd config,
picking the right base image, front controller, and process model. Targets: docker, systemd, nginx,
cpanel.

## Boundary

This packet owns the `deploy` command: the target scaffolders and their companion files, the
`--runtime` selection (PHP), and the refuse-on-invalid-combination rules. It does NOT own the container
build itself (`build`, feature 119) or the running server.

## Existing implementation evidence

- Dispatch: `main.rs:453` `Commands::Deploy { target, runtime, force } => deploy::run(&target,
  runtime.as_deref(), force)`.
- Targets (per the CLI `CLAUDE.md`): docker, systemd, nginx, cpanel.
- `--runtime` is PHP-only and selects the Docker image's server: `cli` (default, the framework's own
  forking server), `fpm` (nginx + php-fpm, fresh process state per request), or `swoole` (openswoole,
  app stays resident). Each writes its own companions: `server.php` for swoole, `nginx.fpm.conf` +
  `docker-entrypoint.fpm.sh` for fpm.
- `--runtime` on a non-PHP project is REFUSED, not ignored (a good fail-loud).

## Public surface contract

`tina4 deploy <target> [--runtime cli|fpm|swoole] [--force]`. `--force` overwrites existing deploy files.
`--runtime` is valid only for PHP + docker; on any other project it is refused. The generated files match
the project's language.

## Inputs and outputs

- Input: the target, the (PHP) runtime, `--force`, and the detected language. Output: deploy scaffolding
  files (Dockerfile, systemd unit, nginx conf, cpanel config, plus runtime companions).

## Lifecycle and operation graph

1. Detect the language; validate the target and the `--runtime`/language combination (refuse
   `--runtime` on non-PHP).
2. Render the target's template(s) for the language (and the PHP runtime companions).
3. Write the files (refusing to overwrite unless `--force`).

## Configuration and precedence

- Flags only (`--runtime`, `--force`). No env. The base image / server model is derived from the language
  and runtime.

## Failures, side effects and security

- Writes deploy files. `--force` gates overwrite (so a re-run does not clobber a customized Dockerfile
  silently) - the correct default, and the opposite of the INIT-05 skip-if-exists lesson (deploy REFUSES
  without force rather than silently skipping; confirm which).
- `--runtime` on a non-PHP project is REFUSED (fail-loud), not silently ignored - good.
- Security-relevant defaults: the generated nginx/htaccess should block sensitive files (`.env`,
  `secrets/`, `src/routes`) - the PHP `init` scaffold already does this; confirm the DEPLOY nginx/fpm
  configs do too (a deploy config that serves `.env` is a real exposure).

## Wire and persistence contract

The artifacts are deploy config files (Dockerfile, `server.php`, `nginx.fpm.conf`,
`docker-entrypoint.fpm.sh`, systemd unit, cpanel config). Their contents are the contract; they must
reference the project's real entry point and block sensitive paths.

## Providers and substitutability

The substitution axis is the target (docker/systemd/nginx/cpanel) and, for PHP+docker, the runtime
(cli/fpm/swoole). Each is a template. Adding a target/runtime means a new template + the validation rule.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| DEPLOY-SECURITY | Confirm the generated nginx/fpm/cpanel configs BLOCK sensitive files (`.env`, `secrets/`, `src/routes|orm|app|templates`) - the `init` scaffold's nginx.conf.example does, so the deploy templates should match. A deploy config that serves `.env` is a real exposure. | Verify each deploy target's config denies the sensitive paths; add a test that greps the generated config for the deny rules. |
| DEPLOY-OVERWRITE | Confirm the overwrite behaviour: `--force` overwrites, and WITHOUT `--force` deploy REFUSES (fails loud) rather than silently skipping (the INIT-05 anti-pattern). | Verify; ensure a no-force re-run over existing files errors with a message, not a silent no-op. |
| DEPLOY-PARITY | Non-PHP projects have fewer runtime options (Python/Node/Ruby have one server model each). Confirm `tina4 deploy docker` produces a correct, secure image for all four languages (not just PHP's three runtimes). | Verify the non-PHP Docker templates are current (correct base image, entry point, production server) and secure. |

## Owner decisions

- DEPLOY-DEC-01 (proposed): verify the deploy configs block sensitive files (DEPLOY-SECURITY) and the
  overwrite is fail-loud (DEPLOY-OVERWRITE).

## Proposed conformance fixture

Native Rust tests: for each language, `tina4 deploy docker` writes a Dockerfile referencing the real entry
point; the generated nginx/fpm config denies `.env`/`secrets/`/`src/routes`; `--runtime` on a non-PHP
project is refused; a no-`--force` re-run over existing files errors; and PHP's cli/fpm/swoole each write
their documented companions.

## Integration map

- Dispatch: `main.rs` `Commands::Deploy` -> `deploy.rs`.
- Consumes: the detected language, the target/runtime templates.
- Related: `build` (feature 119, builds the artifacts the image ships), the PHP `init` scaffold (the
  nginx/htaccess security baseline to match).

## Breaking changes and migration

- Tightening a deploy template's security (adding deny rules) changes the generated file - document it;
  existing deployments are unaffected until regenerated.

## Implementation backlog

1. Verify + fix the deploy configs' sensitive-file blocking (DEPLOY-SECURITY).
2. Confirm the overwrite is fail-loud (DEPLOY-OVERWRITE).
3. Verify the non-PHP Docker templates are current and secure (DEPLOY-PARITY).

## Porting capsule

`tina4 deploy` is one native Rust command; nothing to port across frameworks. A clean-room
reimplementation needs: language detection to pick the base image/entry point; target scaffolders
(docker/systemd/nginx/cpanel) whose configs reference the real entry point and DENY sensitive paths
(`.env`, `secrets/`, source dirs); a PHP-only `--runtime` (cli/fpm/swoole) with its companion files;
refusal of `--runtime` on non-PHP; and `--force`-gated overwrite that fails loud without the flag.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage (generated configs) and provider contracts complete.
- [x] Native single-implementation behaviour recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases (security deny rules, overwrite, non-PHP images) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
