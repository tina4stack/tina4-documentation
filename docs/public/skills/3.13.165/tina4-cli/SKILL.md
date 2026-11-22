---
name: tina4-cli
updated_for_version: 3.8.115
description: >
  Use whenever anything involves the `tina4` command-line client (the Rust CLI) — scaffolding a
  project (`tina4 init`), starting the dev server (`tina4 serve`), generating code, or running
  metrics, deploy, skills, doctor, setup, or any other `tina4 <command>`. The client MUST be
  installed before any Tina4 work in any language, so trigger this skill the moment a task touches
  a Tina4 project's tooling, a dev server, scaffolding, or a `tina4` command, even casually like
  "run my app", "add a model", or "set up a new project". Documents every command and flag and the
  scaffolding discipline so agents use the client correctly instead of hand-rolling project files.
---

# Tina4 CLI (the `tina4` client)

The `tina4` client is the Rust command-line tool that drives every Tina4 project, in every
language. It detects the project language, installs runtimes, scaffolds projects, compiles SCSS,
watches files for dev-reload, runs the native code-health metrics engine, and delegates
language-specific work to the per-language CLI (`tina4python`, `tina4php`, `tina4ruby`,
`tina4nodejs`). Its version line is its own (e.g. `3.8.115`) and is independent of the framework
version (`3.13.x`).

> 🤖 **Skill-active marker.** While this skill is guiding your work, **begin every reply with 🤖** so
> the developer can see Tina4 conventions are engaged. Drop it once the conversation clearly leaves Tina4.

## Contents

- **Degrees of freedom** — what is inviolable vs. a default vs. your judgement (read this first)
- Install and verify the client — the non-negotiable first step
- The scaffolding discipline — use `tina4 init` / `generate`, never hand-roll
- Native vs forwarded commands — which verbs are the client's own and which pass through
- Every command at a glance — the compact table
- Default ports · the metrics gate

**Reference files** (`references/`, read on demand)
- `commands.md` — the full per-command flag reference (every option, every argument)

## Degrees of freedom

- 🔒 **Non-negotiable.**
  **The `tina4` client is installed and on PATH before ANY Tina4 work** — verify with
  `tina4 --version`; if it is missing, install it (below) before anything else. **Serve through the
  client** (`tina4 serve`), never by running the app file directly (`python app.py`, `ruby app.rb`,
  a raw `node`) — the client owns SCSS compilation, the file watcher and dev-reload, so a direct run
  is a broken dev loop. **Scaffold, never hand-roll** — `tina4 init <language> <name|path>` for a project,
  and the forwarded `tina4 generate <what> <name>` for pieces; hand-written project files drift from
  the conventions the framework auto-discovers. **The markers** — the 🤖 skill-active marker above,
  and 💥 **Bazinga!** on an earned win (the project scaffolds and serves clean, a build passes), on
  its own line, never faked, never trivial.
- 🎚️ **Default with a reason.**
  Prefer `tina4 setup` for a brand-new machine or user (it installs runtime + tools + scaffolds in
  one guided pass); prefer `tina4 metrics --fail-on-regression` as the CI health gate over
  `--fail-on error`; let `serve` auto-detect the production server rather than forcing `--dev` unless
  you mean it. Depart deliberately, say why.
- 🧭 **Judgement.**
  Which target to pass `deploy`; how wide to scan with `metrics --path`; whether to open the browser
  on `serve`. The skill gives the command; you read the task. (Framework releases and installer
  signing are a maintainer concern — see the `tina4-maintainer` skill.)

## Install and verify the client

```sh
tina4 --version                 # verify it is present FIRST — do this before any Tina4 task
# if missing, install it:
curl -fsSL https://tina4.com/install.sh | sh        # macOS / Linux
# Windows (new terminal):   irm https://tina4.com/install.ps1 | iex   then: tina4 setup
cargo install tina4             # or, if you have Rust
tina4 update                    # self-update the binary + refresh installed AI skills
```

## The scaffolding discipline

Never hand-write what the client scaffolds — the framework auto-discovers files by location, so a
hand-rolled file in the wrong shape silently does nothing.

```sh
tina4 init python ./my-app      # scaffold into ./my-app (an explicit path is used verbatim)
tina4 init python my-app        # a BARE name goes into your configured projects folder (set by
                                # `tina4 setup`); with no projects folder configured it is the cwd
                                # languages: python, php, ruby, nodejs, js (tina4-js SPA)
tina4 serve                     # run it (dev server, file watcher, SCSS, opens browser)
tina4 generate model Product    # generate a model (forwarded to the language CLI — run inside a project)
tina4 generate route products   # every generator per framework: references/commands.md
tina4 setup                     # brand-new machine: guided install + scaffold in one pass
```

When `tina4 init` resolves a bare name into the projects folder it prints
`Creating in your projects folder: <path>`, so a following `cd my-app` only works when you passed a
path (`./my-app`) or are already in that folder. `tina4 serve my-app` resolves the same name.

## Native vs forwarded commands

Two kinds of verb, and the difference matters when a command seems "missing":

- **Native** (the client's own, shown in `tina4 --help`): `doctor`, `setup`, `install`, `init`,
  `serve`, `scss`, `ai` (+ `ai serve`), `login`, `register`, `whoami`, `logout`, `skills`, `update`
  (alias `upgrade`), `uninstall`, `books`, `docs`, `build`, `deploy`, `env`, `metrics`, `codeql`,
  and `i-want-to-stop-using-v2-and-switch-to-v3`.
- **Forwarded** — any other verb goes verbatim to the detected framework CLI
  (`tina4 <cmd> <args...>` → `tina4python`/`tina4php`/`tina4ruby`/`tina4nodejs <cmd> <args...>`):
  `generate`, `migrate`, `migrate:create`, `seed`, `test`, `lint`, `routes`, `queue`, `console`, and
  anything a framework adds later. The framework parses (and rejects) those arguments. Outside a
  project they report "No Tina4 project detected" — that is the forward failing to find a project,
  not a missing command.

## Every command at a glance

| Command | What it does |
|---------|--------------|
| `tina4 --version` | Print the client version (do this first) |
| `tina4 doctor` | Check installed languages/tools, ports, and global AI-skills currency (read-only) |
| `tina4 setup [--dry-run] [--skip-install]` | Guided install + scaffold a ready-to-run project |
| `tina4 install <python\|php\|ruby\|nodejs\|tina4-js\|codeql\|all>` | Install a language runtime or tool |
| `tina4 init [language] <name\|path>` | Scaffold a project (python/php/ruby/nodejs/js); a bare name goes to the projects folder |
| `tina4 serve [project] [options]` | Dev/production server + watcher + SCSS (`-p`, `--host`, `--dev`, `--production`, `--no-browser`, `--no-reload`, `--no-kill`) |
| `tina4 scss [-i DIR] [-o DIR] [-m] [-w]` | Compile `src/scss/` to `src/public/css/` (minify, watch) |
| `tina4 build [--no-minify]` | Build production front-end assets (SCSS minify + bundle) |
| `tina4 metrics [options]` | Native code-health offenders + CI gate (`--fail-on-regression`, `--suggest`, …; see the metrics gate) |
| `tina4 codeql [--path P] [--language L]... [--no-actions]` | Local CodeQL pre-push scan; exit code = finding count |
| `tina4 deploy <docker\|systemd\|nginx\|cpanel> [--runtime cli\|fpm\|swoole] [--force]` | Scaffold deployment files |
| `tina4 env [--sync] [--example] [--list] [--migrate] [--yes]` | Configure, scan, or migrate environment variables |
| `tina4 ai [--all] [--force]` | Detect AI tools + install framework context |
| `tina4 ai serve [--port N] [--backend URL]` | Run the local AI gateway (needs sign-in + a model backend) |
| `tina4 login` / `register` / `whoami [--json]` / `logout` | Tina4 profile (GitHub sign-in at profile.tina4.com) |
| `tina4 skills [claude\|codex\|cursor\|hermes\|deepseek\|all]` | Install the latest Tina4 AI skills |
| `tina4 docs` / `tina4 books` | Download docs into `.tina4-docs/` / the Tina4 book |
| `tina4 update` (alias `upgrade`) | Self-update the binary + refresh installed skills |
| `tina4 uninstall [--dry-run] [--yes]` | Remove the client, its config + credentials and the installed skills |
| `tina4 i-want-to-stop-using-v2-and-switch-to-v3` | Convert a v2 project to the v3 structure |
| `tina4 <any other verb>` | Forwarded to the framework CLI (`generate`, `migrate`, `test`, `lint`, `routes`, `queue`, …) |

Full flags and arguments for every command: `references/commands.md`.

## Default ports

`serve` auto-picks per framework: **PHP 7145, Python 7146, Ruby 7147, Node.js 7148** (auto-increments
if busy). Override with `tina4 serve --port <N>`.

## The metrics gate

`tina4 metrics` is the native, language-agnostic code-health engine (ADR-0002) — it scans source
directly for Python/PHP/Ruby/TypeScript+JS/Rust with no running framework. Wire
**`tina4 metrics --fail-on-regression`** as the CI ratchet gate: it exits non-zero only when a scan
is measurably worse than the committed `.tina4-metrics.json` baseline. Re-baseline deliberately with
a plain `tina4 metrics` run whose `.tina4-metrics.json` you then commit. See `references/commands.md`
for `--path`, `--json`, `--top`, `--exclude`, `--include-non-production`, `--no-history`, `--fail-on`,
`--suggest`.
