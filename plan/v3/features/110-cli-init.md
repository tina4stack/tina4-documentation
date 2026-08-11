# Feature 110: CLI init (project scaffolding)

## Identity and status

- Matrix identity: 110 - `tina4 init <language> <path>` (scaffold a new project)
- Audit state: decision-ready
- Audit note: this is a CLI feature - a SINGLE Rust implementation in the `tina4` binary, not a
  four-language parity feature. Measured 2026-08-11 from `tina4/src/init.rs` (1481 lines) and the CLI
  `CLAUDE.md`. There is no cross-language divergence to measure; the parity axis is instead the
  CONSISTENCY of the five scaffold OUTPUTS (python, php, ruby, nodejs, tina4js) the one command produces.
- Dependencies: `which` (runtime detection), the platform package managers it drives (brew / composer /
  gem / npm / uv), and `tina4 serve` (offered at the end). No framework runtime.
- Dependants: every new Tina4 project starts here; `tina4 setup` drives `init` with `TINA4_INIT_NO_SERVE`.
- Existing ADRs: none dedicated.
- Shared fixtures: NONE. One Rust unit test (`scaffold_binds_a_default_sqlite_database`).

- Catalog phase: CLI (single Rust binary, subcommand)

## Why this feature exists

`tina4 init` turns an empty directory into a running Tina4 project in one command. It checks the language
runtime and package manager (installing them if it can), creates the directory tree, writes the scaffold
files directly, installs dependencies, and offers to start the dev server. The goal is a new developer
going from nothing to a served page without reading a setup guide.

It scaffolds five targets from one binary: the four backend frameworks (python, php, ruby, nodejs) and
the tina4-js frontend SPA. Each gets a working entry point, a dependency manifest, a `.gitignore`, and -
for backends - a zero-config SQLite `.env` so the first request does not 500 on "no database bound".

## Boundary

This packet owns the `init` subcommand: language resolution (including the alias map), the
runtime/package-manager checks, the directory tree, the per-target scaffold file sets, the dependency
install, and the closing serve prompt. It writes files directly - it does NOT delegate scaffolding to the
framework CLIs (contrast `generate`, which does delegate).

It does NOT own: `tina4 serve` (called at the end); `tina4 setup` (the guided wizard that calls `init`);
the framework runtimes it installs. The scaffold file CONTENTS reference each framework's real entry API
(`asgi()`/`run()`, `$app->handle()`, `Tina4.run!`, `startServer()`) but the command owns only the
scaffolding, not those APIs.

## Existing implementation evidence

Single implementation: `tina4/src/init.rs`, dispatched from `main.rs:272`
(`Commands::Init { lang, path } => init::run(...)`). Flow (`init_project`, `init.rs:157`):

| Step | Function | Behavior |
| --- | --- | --- |
| Resolve language | `run` / `prompt_language` | alias map; interactive pick if omitted; exit if none installed |
| 1. Runtime check | `check_runtime` | brew-install on macOS / point to download URL / exit 1 if missing |
| 2. Package manager | `check_package_manager` | uv (curl-pipe install) / composer / bundler / npm |
| 3. Create dir | `create_project_dir` | create, or reuse an existing dir with a warning |
| 4. Scaffold | `scaffold_project` + `scaffold_<lang>` | write dirs + files directly (no delegation) |
| 5. Install deps | `install_deps` | uv sync / composer install / bundle install / npm install (non-fatal) |
| 6. Serve | serve prompt | offer `tina4 serve` unless `TINA4_INIT_NO_SERVE` |

Per-target scaffold outputs (backend common dirs `src/{routes,orm,templates,public/{css,js,images},scss}`
+ `migrations,data,logs`; tina4js `src/{components,routes,pages,public/css}` + `tests`):

- python: `app.py` (ASGI `app = asgi()` + `run()` under `__main__`), `.gitignore`, `pyproject.toml`.
- php: `index.php` (`$app->handle()`), `.gitignore`, `composer.json`, `.htaccess`, `nginx.conf.example`.
- ruby: `app.rb` (`Tina4.run!`), `.gitignore`, `Gemfile`.
- nodejs: `app.ts` (`startServer()`), `.gitignore`, `package.json`, `tsconfig.json`.
- tina4js: full SPA (`package.json`, `vite.config.ts`, `index.html`, `src/main.ts`, routes/pages/
  components, `default.css`, a real `tests/signals.test.ts` gate).

## Public surface contract

`tina4 init <language> <path>`. The language alias map (`init.rs:16,50-58`): `python`/`py`,
`php`, `ruby`/`rb`, `nodejs`/`node`/`typescript`/`ts` (all the backend Node target), and
`js`/`tina4js`/`tina4-js`/`frontend` (the tina4-js SPA). Note `js` maps to the FRONTEND, not the Node
backend - a deliberate choice documented in code and in `print_usage`. With no language, `init` detects
installed runtimes and prompts; with no path, it errors with usage. A non-interactive stdin (EOF) exits
rather than hanging.

## Inputs and outputs

- Input: a language (or interactive pick) and a target path. Environment: `TINA4_INIT_NO_SERVE` suppresses
  the closing serve prompt.
- Output: a scaffolded project directory, dependencies installed (best-effort), and either a running
  server or next-step instructions. Every backend `.env` binds `TINA4_DATABASE_URL=sqlite:///app.db`.
- Side effects beyond the target dir: it may install a runtime (brew) and a package manager (uv via
  `curl | sh`), and it runs the package manager's install in the new project.

## Lifecycle and operation graph

The six steps above run in sequence; any hard failure in steps 1-3 exits the process (with an actionable
message), step 5 is non-fatal (prints "run it manually later"), and step 6 either serves in-process
(`crate::handle_serve`) or prints instructions. `create_project_dir` reuses an existing directory rather
than refusing it, and `write_file` skips any file that already exists (so a re-run does not overwrite) -
which is also the cause of INIT-05.

## Configuration and precedence

- `TINA4_INIT_NO_SERVE` (presence) - skip the closing serve prompt (set by `tina4 setup`).
- The scaffolded `.env` sets `TINA4_DEBUG=true`, `TINA4_LOG_LEVEL=ALL`, and the SQLite URL for backends.
- No other configuration. The runtime/package-manager choices are hardcoded per language.

## Failures, side effects and security

- INIT-05 (real bug): a PHP scaffold never gets its intended `.env`. `scaffold_project` writes the common
  `.env` (`init.rs:585`) for every backend, then `scaffold_php` writes `.env` again (`init.rs:686`) with
  `SECRET=change-me-in-production`; but `write_file` skips a file that already exists (`init.rs:1429`), so
  the second write is a no-op. The PHP project ends up with the common `.env` (no `SECRET`, with
  `TINA4_LOG_LEVEL=ALL`), NOT the PHP-specific one. The code comment claims it "overrides the shared
  template for PHP" - false. The one test only asserts `sqlite:` is present (true either way), so it does
  not catch it.
- Software install as a side effect: `init` can `brew install` a runtime (python/php/ruby/node) and
  installs uv by piping a remote script to a shell (`curl -LsSf https://astral.sh/uv/install.sh | sh`,
  `init.rs:445`). This is the intended turnkey behavior, but `tina4 init` installing system software (and
  a curl-to-shell) is a significant, possibly surprising, side effect worth a docs note and a
  `--no-install` escape hatch.
- `write_file` skip-if-exists makes a re-run non-destructive (good) but means a corrupt/partial file is
  never repaired by re-running `init` (a user must delete it first).
- No secret handling beyond the (dead) PHP `SECRET` line; the framework generates a dev secret when none
  is set, so INIT-05 is not a security hole, just missing intended scaffold config.

## Wire and persistence contract

The output is a set of files on disk. There is no manifest and no persisted state beyond the scaffold.
The scaffold contents pin dependency versions: backends reference the framework at `^3.0`/`>=3.1.0`, but
tina4js pins specific tool versions (`vite ^8.2.0`, `vitest ^4.1.10`, `tina4js ^1.5.1`) that can drift
from current releases since the CLI is versioned independently (3.8.x).

## Providers and substitutability

There is no provider abstraction; each language's scaffold and toolchain is hardcoded. The substitution
seam is the language argument (five targets). Adding a target means a new `scaffold_<lang>` plus alias-map
and check entries.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| INIT-05 | The PHP-specific `.env` (with `SECRET=change-me-in-production`) is never written: the common `.env` is written first and `write_file` skips-if-exists, so `scaffold_php`'s `.env` write is a silent no-op. The "overrides the shared template for PHP" comment is false, and no test catches it (the sqlite assertion passes either way). | FIX: either write the PHP `.env` before the common one, or have the common step skip PHP, or make `write_file` accept an overwrite flag for this case. Add a regression asserting the PHP `.env` contains `SECRET=`. |
| INIT-INSTALL | `tina4 init` installs system software as a side effect (brew install a runtime; `curl | sh` for uv) without an opt-out. Turnkey by design, but surprising and a curl-to-shell. | Add a `--no-install` flag (and honor a CI/non-interactive default) that checks-and-instructs instead of installing; document the install behavior in `tina4 init --help`. |
| INIT-JS-ALIAS | `js` maps to the tina4-js FRONTEND, not the Node backend (which is `nodejs`/`node`/`ts`). Deliberate and documented, but a real footgun for someone expecting `js` = JavaScript backend. | No code change; keep the documented mapping and ensure `--help` and the docs state it prominently (they do in `print_usage`). |
| INIT-JS-PINS | The tina4js scaffold pins specific tool versions (vite/vitest/tina4js) that can go stale as the CLI ships independently. | Low priority: source the pins from a single place (or loosen to caret ranges) and add a release check that the pinned versions are current. |
| INIT-TESTS | Only one unit test (the sqlite `.env` bind). No coverage for the alias map, the interactive prompt, the runtime/package-manager install branches, the serve prompt, or INIT-05. | Add unit tests for the alias resolution and the scaffold file SET per target (names present), and the INIT-05 regression. The install/serve branches can stay manual (they touch the system). |

## Owner decisions

- INIT-DEC-01 (proposed): fix INIT-05 (PHP `.env`) - a clear bug.
- INIT-DEC-02 (proposed): add `--no-install` and document the auto-install/curl-to-shell side effect.
- INIT-DEC-03 (proposed): keep the `js`-is-frontend mapping (documented), or rename to reduce the
  footgun.

## Proposed conformance fixture

A Rust integration test per target (no mocks; a real temp dir, `TINA4_INIT_NO_SERVE` set, skip the
install step): assert the expected file SET exists for each of python/php/ruby/nodejs/tina4js; assert
every backend `.env` binds SQLite AND that the PHP `.env` contains `SECRET=` (INIT-05 witness, fails
today); assert `write_file` skip-if-exists leaves a pre-existing file untouched; assert an unknown
language exits non-zero with usage.

## Integration map

- Dispatch: `main.rs` `Commands::Init`.
- Calls: `check_runtime`/`check_package_manager` (system installers), `crate::handle_serve` (step 6).
- Called by: `tina4 setup` (with `TINA4_INIT_NO_SERVE`).
- Documentation: the CLI `CLAUDE.md` `tina4 init` line and `print_usage`; the framework docs' getting-
  started pages should match the scaffold entry points.

## Breaking changes and migration

- INIT-05 fix changes what a new PHP project's `.env` contains (it gains `SECRET`). Existing projects are
  unaffected (init is non-destructive). No migration.
- A `--no-install` flag is additive.

## Implementation backlog

1. Fix INIT-05 (PHP `.env`) with a regression test.
2. Add `--no-install` + document the install/curl-to-shell side effect.
3. Add the per-target scaffold file-set integration tests.
4. Decide INIT-JS-ALIAS (keep documented) and de-duplicate/loosen the tina4js version pins.

## Porting capsule

`tina4 init` is a single Rust command; there is nothing to port across languages. A clean-room
reimplementation needs: the alias map (python/py, php, ruby/rb, nodejs/node/typescript/ts, and
js/tina4js/tina4-js/frontend -> frontend); interactive language detection with a non-interactive exit;
runtime + package-manager checks with an opt-out; the per-target directory trees and scaffold file sets
above; a skip-if-exists writer that does NOT defeat an intended per-target override (the INIT-05 lesson);
a best-effort dependency install; and a closing serve prompt gated by `TINA4_INIT_NO_SERVE`.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Single-implementation consistency (five scaffold targets) recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases and the INIT-05 witness complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule (clean-room reimplementation) sufficient.
