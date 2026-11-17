# `tina4` command reference

Every command and flag, grounded in the client's clap definitions (`src/main.rs`, client 3.8.114)
and `tina4 <command> --help`. Reference material — plain tables, no prose voice. If a flag here
disagrees with `tina4 <command> --help` on your installed client, the client is the truth; report the
drift (the First Principle: docs match code).

## `tina4 init [language] <name|path>`
Scaffold a new Tina4 project.
- `LANG` (positional, optional): `python` (`py`), `php`, `ruby` (`rb`), `nodejs` (`node`,
  `typescript`, `ts`), `js` (`tina4js`, `tina4-js`, `frontend` — the tina4-js frontend SPA). Omit it
  and the first installed runtime is used (Python → PHP → Node.js → Ruby) and announced; if the
  first argument is not a language it is taken as the name/path.
- `PATH` (positional): either
  - a **bare project name** (`my-app`) — created inside your configured projects folder (the one
    `tina4 setup` records; `tina4 serve <name>` resolves the same folder). The client prints
    `Creating in your projects folder: <path>`. With no projects folder configured, it lands in the
    current directory; or
  - an **explicit path** — anything containing a separator, starting with `.`, or absolute
    (`./my-app`, `../apps/shop`, `/srv/app`) — used verbatim.
- Examples: `tina4 init python ./my-app` (here), `tina4 init php shop` (projects folder).

## `tina4 serve [project] [options]`
Start the server with file watcher + SCSS compilation. Production server auto-detected.
- `PROJECT` (positional, optional): project name, resolved against the current folder then the
  configured projects folder, and cd'd into before serving.
- `-p, --port <PORT>`: port (default auto per framework — php 7145, python 7146, ruby 7147, nodejs 7148).
- `--host <HOST>`: host address (default `0.0.0.0`).
- `--dev`: force the dev server even if a production server is available.
- `--production`: install and use the best production server for the detected framework.
- `--no-browser`: do not open the browser on startup.
- `--no-reload`: disable the hot-reload signal (sets `TINA4_NO_RELOAD=true`); for stable demos and CI.
- `--no-kill`: opt out of port takeover (sets `TINA4_NO_TAKEOVER`): a busy port is never reclaimed,
  even from this project's own dev server; serve stops instead. Pick another port with `--port`.

## `tina4 metrics [options]`
Native, language-agnostic code-health offenders (ADR-0002). No project/framework required.
- `--path <PATH>`: any supported source dir OR file (default: cwd, auto-detecting `src/` or `packages/*/src`).
- `--fail-on <warn|error>`: exit 1 when any offender is at/above this severity (absolute CI gate).
- `--fail-on-regression`: exit 1 when this scan regressed against the committed `.tina4-metrics.json`
  baseline (new offender file, more offenders, worse worst-case complexity on a still-offending file,
  more duplicated lines). The ratchet gate; no baseline = warns and passes. Independent of `--fail-on`.
- `--json`: machine-readable JSON (dev-admin dashboard shape; always carries `rule_id` and `remedy`).
- `--top <N>`: show only the worst N offenders (default 20).
- `--exclude <GLOB>`: exclude a path glob (repeatable; supports `*`, `**`, `?`).
- `--include-non-production`: include tests/specs/declaration files in the measured source.
- `--no-history`: do not read or write the `.tina4-metrics.json` run-history baseline.
- `--suggest`: print each offender's stable rule id and a suggested refactoring move under its row
  (opt-in; the default table is unchanged).

## `tina4 codeql [options]`
Run CodeQL locally as a pre-push check, matching CI's GitHub "default setup (extended)" scan
(security-extended suite) over JS/TS, Ruby, Python and GitHub Actions. Needs the `codeql` CLI
(`tina4 install codeql`, or `brew install codeql` then `codeql pack download codeql/*-queries`).
The exit code is the finding count, so it gates a pre-push hook.
- `--path <PATH>`: source directory to scan (default: current directory).
- `--language <javascript-typescript|python|ruby|actions>`: language to scan, repeatable (default:
  auto-detected + actions).
- `--no-actions`: skip the GitHub Actions workflow scan.

## `tina4 deploy <target> [options]`
Generate deployment scaffolding.
- `TARGET` (positional): `docker`, `systemd`, `nginx`, `cpanel`.
- `--runtime <RUNTIME>`: PHP runtime for `deploy docker` only — `cli` (default), `fpm`, or `swoole`.
  Ignored for the other languages and targets.
- `--force`: overwrite existing files instead of skipping.

## `tina4 setup [options]`
Guided, menu-driven: install everything + scaffold a ready-to-run project.
- `--dry-run`: show the menu and plan without installing or scaffolding (for testing).
- `--skip-install`: run the real menu + scaffold + CLAUDE.md, but skip system installs.

## `tina4 install <target>`
Install a language runtime or tool. `TARGET`: `python`, `php`, `ruby`, `nodejs`, `tina4-js`, `codeql`,
or `all` (the four runtimes). Note: here `js` means Node.js; `tina4-js` is the frontend framework.

## `tina4 scss [options]`
Compile SCSS.
- `-i, --input <DIR>`: input directory (default `src/scss`).
- `-o, --output <DIR>`: output directory (default `src/public/css`).
- `-m, --minify`: minify the output.
- `-w, --watch`: watch for changes.

## `tina4 build [--no-minify]`
Build production front-end assets (SCSS minify + bundle). `--no-minify` disables minification.

## `tina4 env [options]`
Configure environment variables (interactive by default).
- `--sync`: just scan and sync — no prompts.
- `--example`: only generate `.env.example`.
- `--list`: list all env vars the project uses.
- `--migrate`: migrate legacy un-prefixed vars (`DATABASE_URL`, `SECRET`, `SMTP_*`, `IMAP_*`,
  `HOST_NAME`, `SWAGGER_*`, `ORM_*`) to their `TINA4_*` names; writes a `.env.bak` backup first.
- `--yes`: skip confirmation prompts (use with `--migrate` in CI scripts).

## `tina4 ai [options]` / `tina4 ai serve`
Detect AI coding tools and install framework context/skills.
- `--all`: install context for ALL known tools, not just detected ones.
- `--force`: overwrite existing context files.
- `tina4 ai serve [--port <N>] [--backend <URL>]`: run the local AI gateway (registration-gated,
  streams, falls back to Ollama). Port default 11435; backend default auto-detects ai-server :11437
  then Ollama :11434. Fails fast unless you are signed in AND a model backend answers.

## `tina4 login` / `tina4 register` / `tina4 whoami` / `tina4 logout`
Tina4 profile at profile.tina4.com.
- `login`: sign in with GitHub (the first login creates the profile).
- `register`: open sign-up, then sign in with GitHub.
- `whoami [--json]`: show the signed-in profile (`--json` for tooling / dev-admin).
- `logout`: sign out and remove the stored credentials.

## `tina4 skills [target]`
Install the latest Tina4 AI skills. `TARGET`: `claude` (`~/.claude/skills`), `codex` (`~/.agents/skills`), `cursor` (`~/.cursor/skills`), `hermes` (`~/.hermes/skills`), `deepseek` (`~/.agents/skills`, the same folder as `codex`), or `all` (each folder written once). Omit for a menu.

## `tina4 doctor`
Check installed languages/tools, ports, and global AI-skills currency. Strictly read-only — reports
and suggests a refresh, writes nothing, never touches a project CLAUDE.md.

## `tina4 docs` / `tina4 books`
`docs` downloads framework docs into `.tina4-docs/`; `books` downloads the Tina4 book into the cwd.

## `tina4 update` (alias `tina4 upgrade`)
Self-update the binary and refresh installed Tina4 AI skills.

## `tina4 uninstall [options]`
Remove everything the client put on this machine: config + credentials, the installed Tina4 AI
skills, and the binary. Lists exactly what it will touch and asks first; offers to clean this
project's `.tina4/` too.
- `--dry-run`: show what would be removed without removing anything.
- `--yes`: do not prompt (for scripts).

## `tina4 i-want-to-stop-using-v2-and-switch-to-v3`
Convert a Tina4 project from the v2 structure to v3.

## Forwarded verbs (run inside a project)
Any verb the client does not own is forwarded verbatim to the detected framework CLI —
`tina4 <cmd> <args...>` → `tina4python` / `tina4php` / `tina4ruby` / `tina4nodejs <cmd> <args...>`.
The framework owns argument parsing and rejects unknowns. Common ones: `migrate`, `migrate:create`,
`seed`, `test`, `lint [--fix]`, `routes`, `queue`, `console`, `generate`. `tina4 lint` runs the
project's own linter if it has one (ruff / rubocop / eslint / phpcs), else the runtime's zero-dep
syntax check — it installs nothing.

### `tina4 generate <what> <name> [options]`
The generator list belongs to each framework CLI (run `tina4 generate` with no arguments for the
installed list). As of framework 3.13.x:

| Framework | Generators |
|-----------|-----------|
| PHP, Ruby, Node.js (15) | `model`, `route`, `crud`, `migration`, `middleware`, `test`, `form`, `view`, `auth`, `service`, `queue`, `validator`, `seeder`, `websocket`, `listener` |
| Python (17) | the same 15, plus `base` (Frond base template + index page) and `page` (a page extending `base.twig`) |

Shared options: `--fields "name:string,price:float"`, `--table-name <name>`, `--model <Name>`,
`--public` (open a generated route's writes; secure by default), `--every 5m` / `--cron "..."`
(service schedule), `--json` (resolution envelope) and `--dry-run` (plan, write nothing) — which
generators honour the last two varies by framework; `tina4 generate` lists the options. `auth`
takes no name.

Outside a project these report "No Tina4 project detected" — the forward found no project, not a
missing command.
