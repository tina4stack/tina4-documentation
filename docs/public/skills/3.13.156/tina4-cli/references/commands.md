# `tina4` command reference

Every command and flag, grounded in `tina4 <command> --help` (client 3.8.95). Reference material —
plain tables, no prose voice. If a flag here disagrees with `tina4 <command> --help` on your
installed client, the client is the truth; report the drift (the First Principle: docs match code).

## `tina4 init <language> <path>`
Scaffold a new Tina4 project.
- `LANG` (positional): `python`, `php`, `ruby`, `nodejs`, `js` (tina4-js frontend SPA).
- `PATH` (positional): project directory, absolute or relative.
- Example: `tina4 init python ./my-app`. Note it is `<language> <path>`, NOT `<language> <name>`.

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

## `tina4 metrics [options]`
Native, language-agnostic code-health offenders (ADR-0002). No project/framework required.
- `--path <PATH>`: any supported source dir OR file (default: cwd, auto-detecting `src/` or `packages/*/src`).
- `--fail-on <warn|error>`: exit 1 when any offender is at/above this severity (absolute CI gate).
- `--fail-on-regression`: exit 1 when this scan regressed against the committed `.tina4-metrics.json`
  baseline (new offender file, more offenders, worse worst-case complexity on a still-offending file,
  more duplicated lines). The ratchet gate; no baseline = warns and passes. Independent of `--fail-on`.
- `--json`: machine-readable JSON (dev-admin dashboard shape).
- `--top <N>`: show only the worst N offenders (default 20).
- `--exclude <GLOB>`: exclude a path glob (repeatable; supports `*`, `**`, `?`).
- `--include-non-production`: include tests/specs/declaration files in the measured source.
- `--no-history`: do not read or write the `.tina4-metrics.json` run-history baseline.

## `tina4 deploy <target> [options]`
Generate deployment scaffolding.
- `TARGET` (positional): `docker`, `systemd`, `nginx`, `cpanel`.
- `--runtime <RUNTIME>`: PHP runtime for `deploy docker` only — `cli` (default), `fpm`, or `swoole`.
  Ignored (and refused) for other languages/targets.
- `--force`: overwrite existing files instead of skipping.

## `tina4 setup [options]`
Guided, menu-driven: install everything + scaffold a ready-to-run project.
- `--dry-run`: show the menu and plan without installing or scaffolding (for testing).
- `--skip-install`: run the real menu + scaffold + CLAUDE.md, but skip system installs.

## `tina4 install <lang>`
Install a language runtime. `LANG`: `python`, `php`, `ruby`, `nodejs`.

## `tina4 skills [target]`
Install the latest Tina4 AI skills. `TARGET`: `claude`, `codex`, `cursor`, or `all`. Omit for a menu.

## `tina4 ai [options]`
Detect AI coding tools and install framework context/skills.
- `--all`: install context for ALL known tools, not just detected ones.
- `--force`: overwrite existing context files.

## `tina4 doctor`
Check installed languages/tools, ports, and global AI-skills currency. Strictly read-only — reports
and suggests a refresh, writes nothing, never touches a project CLAUDE.md.

## `tina4 scss`
Compile SCSS from `src/scss/` to `src/public/css/`.

## `tina4 build`
Build production front-end assets (SCSS minify + bundle).

## `tina4 env`
Configure environment variables interactively.

## `tina4 docs` / `tina4 books`
`docs` downloads framework docs into `.tina4-docs/`; `books` downloads the Tina4 book into the cwd.

## `tina4 update`
Self-update the binary and refresh installed Tina4 AI skills.

## `tina4 i-want-to-stop-using-v2-and-switch-to-v3`
Convert a Tina4 project from the v2 structure to v3.

## Forwarded verbs (delegate to the per-language CLI; run inside a project)
Not shown in `tina4 --help`; they forward to `tina4python` / `tina4php` / `tina4ruby` / `tina4nodejs`:
- `tina4 generate <model|route|migration|middleware> <name>`
- `tina4 migrate`
- `tina4 test`
- `tina4 lint [--fix]`
- `tina4 routes`

Outside a project these report "No Tina4 project detected" — the forward found no project, not a
missing command.
