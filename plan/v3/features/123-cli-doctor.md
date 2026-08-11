# Feature 123: CLI doctor (native environment health check)

## Identity and status

- Matrix identity: 123 - `tina4 doctor` (check installed languages/tools, ports, and AI-skills currency)
- Audit state: decision-ready
- Audit note: NATIVE Rust command, strictly READ-ONLY. Measured 2026-08-11 from `tina4/src/doctor.rs`
  (dispatched at `main.rs:256`) and the CLI `CLAUDE.md`. Not a four-language feature.
- Dependencies: `which` (tool detection), the platform, `~/.claude/skills/.tina4-skills-ref` marker, and
  the installer's published ref (`https://tina4.com/install-skills.sh`).
- Dependants: developers diagnosing a broken setup; a quick pre-work check.
- Existing ADRs: none dedicated.

- Catalog phase: CLI (native Rust)

## Why this feature exists

`tina4 doctor` answers "why isn't this working?" without guesswork: it reports which language runtimes and
tools are installed, whether the default ports are free, and whether the globally-installed Tina4 AI
skills are current. It is strictly read-only - it reports and suggests, it never installs or edits
anything - so running it can never make a broken setup worse.

## Boundary

This packet owns the doctor checks: runtime/tool detection, port checks, and the AI-skills currency
classifier. It does NOT install anything (that is `install`/`setup`) and it NEVER touches a project's
`CLAUDE.md` or `.env`.

## Existing implementation evidence

- Dispatch: `main.rs:256` `Commands::Doctor => doctor::run()`.
- Checks (per the CLI `CLAUDE.md`): installed languages/tools; the default ports (php 7145 / python 7146 /
  ruby 7147 / node 7148) in use or free; and AI-skills currency.
- AI-skills currency: `install-skills.sh`/`.ps1` record the installed ref in a GLOBAL marker
  `~/.claude/skills/.tina4-skills-ref`; `doctor` reads it, fetches the current pinned ref from the same
  installer (so "latest" equals what a refresh would install), and reports current / update-available /
  offline / not-recorded. Read-only (curl for the ref, no HTTP-client dependency), only ever reads
  `~/.claude/skills`. The classifier + ref parser are pure and unit-tested.

## Public surface contract

`tina4 doctor` prints a health report: languages/tools present, ports free/busy, and skills currency. No
flags documented; no mutation. The output is human-readable; a `--json` form is not documented (a
machine-readable form would help CI/pre-flight).

## Inputs and outputs

- Input: the local machine (installed tools, ports), the global skills marker, and the network (to fetch
  the current ref). Output: a printed report with a suggested refresh command when skills are stale.

## Lifecycle and operation graph

1. Detect language runtimes and tools (`which`).
2. Check the default ports.
3. Read `~/.claude/skills/.tina4-skills-ref`, fetch the current ref, classify (current / update-available
   / offline / not-recorded), and print the report + a suggested refresh.

## Configuration and precedence

- None. Doctor reads the environment; it takes no flags or env configuration.

## Failures, side effects and security

- Strictly READ-ONLY: no installs, no edits, never touches a project `CLAUDE.md`. The strongest safety
  property of the command.
- Offline: the skills-currency check degrades to an "offline" classification rather than failing (it curls
  the ref; a failure is reported, not fatal).
- No security surface (it inspects the developer's own machine).

## Wire and persistence contract

No persisted state. It READS the `~/.claude/skills/.tina4-skills-ref` marker (written by the installer)
and fetches the installer's pinned ref. The classifier + ref parser are pure functions (unit-tested).

## Providers and substitutability

No provider abstraction; the checks are hardcoded (the supported runtimes, the default ports, the skills
marker). Adding a check means adding to `doctor.rs`.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| DOCTOR-JSON | `doctor` has no documented `--json`, so CI/pre-flight tooling cannot consume its result programmatically. | Low priority: add a `--json` form (languages, ports, skills-currency status) for automation, matching `metrics --json`. |
| DOCTOR-NETWORK | The skills-currency check makes a network call (curl the ref). Confirm it has a short timeout so `doctor` never hangs on a slow/blocked network (the "offline" path should trip quickly). | Verify the curl has a bounded timeout; if not, add one. |

## Owner decisions

- DOCTOR-DEC-01 (proposed, low priority): add `--json` and confirm the network-check timeout.

## Proposed conformance fixture

Native Rust tests (the classifier + ref parser are already unit-tested): assert the skills-currency
classifier returns current / update-available / offline / not-recorded for the corresponding marker+ref
inputs; assert the port check reports busy/free correctly against a bound socket; and (once added) assert
`--json` emits the report shape. All read-only, no mutation.

## Integration map

- Dispatch: `main.rs` `Commands::Doctor` -> `doctor.rs`.
- Reads: the installed tools, the default ports, `~/.claude/skills/.tina4-skills-ref`, the installer ref.
- Related: `install`/`setup` (the mutating counterparts), the AI-skills feature (feature 108, the ref
  marker).

## Breaking changes and migration

- Adding `--json` is additive. No behaviour change to the read-only report.

## Implementation backlog

1. Add `--json` (DOCTOR-JSON) for automation.
2. Confirm the skills-currency network timeout (DOCTOR-NETWORK).

## Porting capsule

`tina4 doctor` is one native Rust command; nothing to port across frameworks. A clean-room
reimplementation needs: runtime/tool detection (`which`), a default-port check, and a skills-currency
classifier that reads the global marker, fetches the installer's pinned ref (bounded timeout, offline-
safe), and reports current/update-available/offline/not-recorded - all strictly read-only, never touching
a project's files.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Native single-implementation behaviour recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
