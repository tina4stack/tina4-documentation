# Tina4 CLI reference

The Tina4 client is one signed binary for Python, PHP, Ruby, Node.js, and
tina4-js. It creates projects, starts servers, manages local tooling, and
measures source code without loading a framework runtime.

## Install the client

macOS and Linux:

```bash
curl -fsSL https://tina4.com/install.sh | sh
```

Windows PowerShell:

```powershell
irm https://tina4.com/install.ps1 | iex
```

Check the installed version:

```bash
tina4 --version
```

## Command map

| Command | Purpose |
| --- | --- |
| `tina4 setup` | Run guided setup and create a ready-to-run project. |
| `tina4 init` | Create a project for Python, PHP, Ruby, Node.js, or tina4-js. |
| `tina4 serve` | Start the detected framework with file watching and SCSS compilation. |
| `tina4 doctor` | Report installed runtimes, package managers, and Tina4 tools. |
| `tina4 install` | Install a supported language runtime. |
| `tina4 scss` | Compile SCSS into CSS. |
| `tina4 build` | Build production front-end assets. |
| `tina4 deploy` | Generate Docker, systemd, nginx, or cPanel deployment files. |
| `tina4 env` | Inspect, migrate, and synchronize environment variables. |
| `tina4 metrics` | Measure production source and rank code-health findings. |
| `tina4 ai` | Detect coding assistants and install Tina4 context. |
| `tina4 skills` | Install current Tina4 skills for Claude, Codex, Cursor, or all three. |
| `tina4 docs` | Download framework documentation into `.tina4-docs/`. |
| `tina4 books` | Download the matching Tina4 book. |
| `tina4 update` | Update the signed client and refresh installed skills. |

Run `tina4 <command> --help` for the command's current arguments and options.

## Start a project

One command creates the project. One command runs it.

```bash
tina4 init python my-app
cd my-app
tina4 serve
```

Replace `python` with `php`, `ruby`, `nodejs`, or `js`. The `js` option creates
a tina4-js front-end project.

`tina4 serve` detects the framework from the project files. You can also name a
configured project from another directory:

```bash
tina4 serve my-app
```

Common server options:

| Option | Purpose |
| --- | --- |
| `-p, --port <PORT>` | Override the framework's default port. |
| `--host <HOST>` | Bind to another address. The default is `0.0.0.0`. |
| `--dev` | Force the development server. |
| `--production` | Install and use the preferred production server. |
| `--no-browser` | Do not open a browser after startup. |
| `--no-reload` | Disable the file watcher's reload signal. |

## Measure code health

`tina4 metrics` reads source files directly. It does not start the application
or import the framework. One native engine applies the same formulas to Python,
PHP, Ruby, TypeScript/JavaScript, and Rust.

Run it from a project:

```bash
tina4 metrics
```

Scan an explicit source directory and show the ten highest-ranked findings:

```bash
tina4 metrics --path src --top 10
```

The report measures lines of code, cyclomatic complexity, maintainability,
coupling, function count, duplicate blocks, and test-reference evidence. It
reports evidence that a test refers to a source file. It does not claim that
the test ran, passed, or covered each branch.

### Metrics options

| Option | Purpose |
| --- | --- |
| `--path <PATH>` | Scan one directory or file. Without it, the client detects the source root. |
| `--top <N>` | Limit the displayed ranked list. The default is 20. Totals stay unchanged. |
| `--json` | Emit the machine contract used by dev-admin and CI. |
| `--fail-on warn` | Exit with code 1 for warning or error findings. |
| `--fail-on error` | Exit with code 1 for error findings. |
| `--exclude <GLOB>` | Exclude a path. Repeat the option for more paths. |
| `--include-non-production` | Include tests, specs, and declaration files. |

Production scans ignore conventional tests, specs, generated bundles, minified
assets, declarations, dependencies, build output, caches, and version-control
data. Use explicit exclusions for project-specific production trees:

```bash
tina4 metrics --exclude '**/dev_admin/**' --exclude '**/gallery/**'
```

### CI gate

Use JSON for stored reports and `--fail-on` for the gate:

```bash
tina4 metrics --json --fail-on error > metrics.json
```

`--top` changes presentation only. It never hides a finding from the exit gate.
Informational `no_test_reference` findings do not fail warning or error gates.

### Reading offender totals

An offender is one finding, not one file. A file can carry several findings:
high function complexity, excessive size, low maintainability, duplication, and
too many functions. Count unique file names when you need the size of the
refactoring worklist. Count findings when you need the gate pressure.

## Manage environment variables

The client can list the variables that source code uses, generate
`.env.example`, synchronize missing entries, and migrate legacy unprefixed
names.

```bash
tina4 env --list
tina4 env --example
tina4 env --sync
tina4 env --migrate
```

Migration creates `.env.bak` before it writes the canonical `TINA4_*` names.
Use `--yes` to skip confirmation in CI.

## Keep tools current

```bash
tina4 update
tina4 skills all
tina4 doctor
```

The update command refreshes the signed binary and installed Tina4 skills. The
doctor command then shows which runtimes and framework clients are ready.
