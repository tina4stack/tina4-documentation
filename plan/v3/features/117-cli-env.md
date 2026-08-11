# Feature 117: CLI env (native environment management)

## Identity and status

- Matrix identity: 117 - `tina4 env [--sync|--example|--list|--migrate [--yes]]`
- Audit state: decision-ready
- Audit note: NATIVE Rust command (not delegated). Scans the project SOURCE for env-var references, so it
  is language-agnostic (one implementation covers all four frameworks). Measured 2026-08-11 from
  `tina4/src/main.rs:187-211,455` (`Commands::Env`), `tina4/src/env_config.rs` (`run` :487, `scan_env_vars`,
  `known_vars`, `write_env_example`), and `tina4/src/env_migrate.rs` (`legacy_env_vars` :22, `run` :67).
- Dependencies: `known_vars()` (the canonical env-var registry with defaults/descriptions), the project
  `.env`/source tree. No framework runtime.
- Dependants: developers keeping `.env` in sync; upgrades from pre-3.x un-prefixed env vars.
- Existing ADRs: relates to the TINA4_* uniformity work (`known_vars()` is the truth) and ADR-0041
  (env precedence).

- Catalog phase: CLI (native Rust)

## Why this feature exists

`tina4 env` keeps a project's environment configuration correct without hand-editing `.env`. `--list`
shows every `TINA4_*` variable the code uses (with its default and description); `--example` regenerates
`.env.example`; `--sync` scans the source and adds any missing variable to `.env` with its default; and
`--migrate` renames legacy un-prefixed variables (`DATABASE_URL`, `SECRET`, `SMTP_*`, ...) to their
`TINA4_*` canonical names, backing up `.env` first. Because it scans source (not a running app), it works
the same across all four frameworks.

## Boundary

This packet owns the `env` command: the source scan, the `known_vars()` registry, the `.env`/`.env.example`
read/write, and the legacy migration map. It does NOT own how the framework READS env vars at runtime
(the DotEnv/typed-env feature) - it manages the `.env` FILE, not the loading.

## Existing implementation evidence

- Dispatch: `main.rs:455` `Commands::Env { sync, example, list, migrate, yes }` -> `env_migrate::run(yes)`
  when `--migrate`, else `env_config::run(sync, example, list)`.
- `--list`: `scan_env_vars(".")` finds used vars; each is described from `known_vars()` (name, default,
  description) or labelled "custom variable" (`env_config.rs:494-512`).
- `--example`: `write_env_example(".env.example")`.
- `--sync`: scan, add any missing var to `.env` with its `known_vars()` default, regenerate the example
  (`env_config.rs:527-556`).
- `--migrate`: `env_migrate::legacy_env_vars()` maps ~20+ legacy names to `TINA4_*` (e.g. `DATABASE_URL`
  -> `TINA4_DATABASE_URL`, `SMTP_*` -> `TINA4_MAIL_*`, `IMAP_*` -> `TINA4_MAIL_IMAP_*`, `HOST_NAME`,
  `SWAGGER_*`, `ORM_PLURAL_TABLE_NAMES`), writing a `.env.bak` backup first (`env_migrate.rs:22-67`).

## Public surface contract

`tina4 env` (interactive), `--sync` (non-interactive scan+add), `--example` (write `.env.example`),
`--list` (print used vars + descriptions), `--migrate` (rename legacy vars, `.env.bak` backup),
`--yes` (skip prompts, for CI with `--migrate`). Native and language-agnostic.

## Inputs and outputs

- Input: the project's source (scanned for `TINA4_*` references), the existing `.env`, and `known_vars()`.
- Output: an updated `.env` and/or `.env.example`, a printed list, or a migrated `.env` (with `.env.bak`).

## Lifecycle and operation graph

1. `--list`/`--example`/`--sync` -> `env_config::run` scans source, consults `known_vars()`, reads/writes
   `.env`/`.env.example`.
2. `--migrate` -> `env_migrate::run` backs up `.env`, rewrites legacy names to `TINA4_*` per the map,
   optionally without prompts (`--yes`).

## Configuration and precedence

- No env configuration of its own. `known_vars()` is the compile-time registry of every canonical
  variable, its default, and description - the single source the command relies on being current.

## Failures, side effects and security

- WRITES `.env`/`.env.example` (a side effect the developer initiates). `--migrate` backs up to `.env.bak`
  first (good), but confirm it does not lose a value if a legacy AND its canonical both exist.
- A secret in `.env` is not printed by `--list` in a way that leaks it beyond the local file (confirm
  `--list` shows names/defaults, not the developer's actual secret values - the code descriptions come
  from `known_vars()`, not the `.env` values, which is correct).
- ENV-KNOWNVARS: `--list`/`--sync` accuracy depends on `known_vars()` being current. A new framework
  `TINA4_*` var missing from `known_vars()` shows as "custom variable" with no default, and `--sync` adds
  it with an empty default - so a stale registry degrades the command silently.

## Wire and persistence contract

The artifacts are `.env`, `.env.example`, and `.env.bak`. The `known_vars()` registry and the
`legacy_env_vars()` map are the compile-time contracts; both must track the frameworks' actual env vars.

## Providers and substitutability

There is no provider; the command is one native Rust implementation that scans source, so it behaves
identically across the four frameworks (the strength of doing it natively rather than delegating). The
only substitution is the project's language, which the scanner is agnostic to (it matches `TINA4_*`
string references regardless of language syntax).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| ENV-DOC | `tina4 env` is NOT listed in the CLI `CLAUDE.md` commands section (which omits `env` and `build`). A real, native command missing from the docs violates the "docs match code" first principle and the `audit-truth.py` gate. | Add `tina4 env` (with its flags) and `tina4 build` to the CLI `CLAUDE.md` command list. |
| ENV-KNOWNVARS | The command's usefulness depends on `known_vars()` and `legacy_env_vars()` staying current with the frameworks' actual env vars. A new `TINA4_*` var not in `known_vars()` is shown as "custom" with no default; a new legacy alias not in the migration map is not migrated. | Add a release check (or a test) that diffs `known_vars()` against the frameworks' documented env vars, so the registry cannot drift. Ties to the env-uniformity work. |
| ENV-MIGRATE-COLLISION | Confirm `--migrate` handles the case where both a legacy name AND its canonical target exist in `.env` (do not silently overwrite the canonical with the legacy value). | Verify; on a collision, keep the canonical value and warn, or prompt (unless `--yes`). Add a test for the collision case. |
| ENV-SCAN-COVERAGE | Confirm `scan_env_vars` catches `TINA4_*` references in all four languages' idioms (`os.environ`/`getenv`/`$_ENV`/`process.env`/`ENV[]`), or, if it matches the literal `TINA4_*` string, that no framework reads a var via a computed name the scanner cannot see. | Verify the scanner's coverage; add a fixture project per language with a known set of used vars and assert `--list` finds them all. |

## Owner decisions

- ENV-DEC-01 (proposed): document `env` (and `build`); add the `known_vars()`/legacy-map currency check.

## Proposed conformance fixture

Native Rust tests (no framework needed): a fixture project referencing a known set of `TINA4_*` vars in
each language's idiom; assert `tina4 env --list` finds them all with descriptions; `--sync` adds the
missing ones with correct defaults; `--example` writes them; `--migrate` renames a legacy `.env`
correctly, writes `.env.bak`, and handles a legacy+canonical collision without data loss.

## Integration map

- Dispatch: `main.rs` `Commands::Env` -> `env_config::run` / `env_migrate::run`.
- Registry: `known_vars()` (the canonical env-var truth), `legacy_env_vars()` (the migration map).
- Related: the DotEnv/typed-env feature (runtime loading), ADR-0041 (env precedence).

## Breaking changes and migration

- `--migrate` is the migration tool itself (legacy -> `TINA4_*`); it is additive and backs up first.
- Documenting the command is a docs fix.

## Implementation backlog

1. Document `env` + `build` in the CLI `CLAUDE.md` (ENV-DOC / BUILD-DOC).
2. Add the `known_vars()`/legacy-map currency check (ENV-KNOWNVARS).
3. Add the migration-collision handling + test (ENV-MIGRATE-COLLISION).
4. Add the scan-coverage fixture per language (ENV-SCAN-COVERAGE).

## Porting capsule

`tina4 env` is one native Rust command; there is nothing to port across languages. A clean-room
reimplementation needs: a source scanner that finds `TINA4_*` references (language-agnostic), a canonical
registry (name, default, description) that must track the frameworks' env vars, `.env`/`.env.example`
read/write with a merge-missing `--sync`, and a legacy->canonical migration map with a `.env.bak` backup
and collision-safe renaming.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and registry contracts complete.
- [x] Native single-implementation behaviour recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
