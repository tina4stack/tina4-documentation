# Feature 134: CLI AI-skills installation and refresh

## Identity and status

- Matrix identity: 134 - CLI AI-skills installation and refresh (`tina4 skills`)
- Audit state: decision-ready
- Audit note: NATIVE Rust CLI feature (single binary, no four-language parity). Measured 2026-08-11 from
  shipped source after pulling the CLI to `main` HEAD `cb7ad13` (`tina4` v3.8.69) - the local checkout was 5
  commits behind and DID NOT contain the `Commands::Skills` command, so this audit re-measured against the
  current code. Sources: `tina4/src/main.rs` (`Skills` command at `:145`, dispatch at `:440`, refresh-on-
  update at `:1726-1766`), `tina4/src/setup.rs` (`install_skills` / `install_skills_interactive` + the setup
  menu), `tina4/src/doctor.rs` (per-target currency), and the hosted installers `install-skills.sh` (POSIX
  sh, measured in full) + `install-skills.ps1` (Authenticode-signed).
- Dependencies: `curl` (fetch), the GitHub raw skill sources pinned by `TINA4_SKILLS_REF` (default the
  released tag `3.13.97`), and the per-tool skills homes.
- Dependants: `tina4 setup` (composes it), `tina4 update`/`upgrade` (refreshes it), `tina4 doctor` (reports
  it), and the framework repositories that host the skill bodies.
- Existing ADRs: none dedicated.

- Catalog phase: CLI (native Rust) + hosted installer scripts

## Why this feature exists

A developer using Claude, Codex, or Cursor wants the current Tina4 guidance loaded into that tool with one
command, not a hunt through directories and shell variables. `tina4 skills` installs the six released Tina4
skills into the right user-level directory for the chosen tool, records which release it installed, and -
during a client upgrade - refreshes only the tools the developer already set up. It is the supply line that
keeps an AI assistant's Tina4 knowledge current.

## Boundary

This packet owns the `skills` command, the target->home mapping, the installer scripts, the legacy cleanup,
and the refresh-on-update. It does NOT own `doctor`'s currency classifier (feature 123, which READS the
marker this feature writes), `setup`'s wizard (feature 124, which composes this), or the skill BODIES
(authored in the framework repos). It writes only user-level skills homes - never a project's `CLAUDE.md`,
`AGENTS.md`, or repo-local `.cursor/skills`.

## Existing implementation evidence

- Command: `main.rs:145` `Skills { target: Option<String> }` (help: "Install the latest Tina4 AI skills for
  Claude, Codex, Cursor, or all"); dispatch `main.rs:440-448` -> `setup::install_skills(&target)` (explicit)
  or `setup::install_skills_interactive()` (menu when omitted); exit code 2 on failure.
- Targets -> homes (installer `install-skills.sh:28-37`): `claude` -> `~/.claude/skills`, `codex` ->
  `~/.agents/skills`, `cursor` -> `~/.cursor/skills`, `all` -> all three; an unknown target errors and exits
  2.
- The six skills (`install-skills.sh:88-94`): `tina4-developer-python/php/ruby/nodejs` (each with the shared
  `DEV_REFS` reference set including `ai-coder-rule-path.svg`), plus `tina4-js` and `tina4-maintainer`
  (canonical copies served from `tina4-python`). Each skill's `SKILL.md` + `references/` are fetched via
  `curl -fsSL` from `raw.githubusercontent.com/tina4stack/<repo>/<ref>/.claude/skills`.
- Reproducibility: the skill CONTENT is pinned to a released tag - `ref="${TINA4_SKILLS_REF:-3.13.97}"`
  (`:23`) - not a moving branch, so an install is reproducible.
- Atomicity: downloads go into a `mktemp -d` stage with a `trap 'rm -rf' EXIT`; nothing is published unless
  every download succeeds (`set -eu` + `curl -f`). `publish_skills` (`:54-74`) replaces each skill dir
  atomically (`cp` to `.<skill>.tina4-new`, `rm` old, `mv` into place) and writes `.tina4-skills-ref` last.
- Legacy cleanup: `LEGACY_SKILLS="tina4-developer"` (`:80`) - only the superseded generic developer skill is
  removed, nothing else.
- Refresh-on-update: `tina4 update`/`upgrade` (`main.rs:154-156`, refresh at `:1726-1766`) enumerates the
  three homes and refreshes ONLY those that already contain a Tina4 skill; a failed skills refresh never
  fails the client update ("the client update is still complete"). If all three are present it uses the
  single `all` target.
- Cross-platform: `install-skills.ps1` mirrors the sh installer for Windows and is Authenticode-signed at
  release finalization; the sh header documents the POSIX-sh discipline (a past `set -o pipefail` + bash
  arrays break killed the documented `curl | sh` on dash while surviving on macOS).

## Public surface contract

`tina4 skills [claude|codex|cursor|all]` - an interactive menu when the target is omitted, or a direct
target for automation. The hosted one-liners set `TINA4_SKILLS_TARGET` and pipe the script into `sh`/
PowerShell. `tina4 update` (alias `upgrade`) refreshes already-installed targets. The install writes the
six skills + the `.tina4-skills-ref` marker into the chosen home(s) and nothing else.

## Inputs and outputs

- Input: the target (arg or menu), `TINA4_SKILLS_REF` (override the pinned tag), `TINA4_SKILLS_TARGET` (for
  the piped script), and the network (GitHub raw). Output: the six skill directories + the ref marker in
  each selected home; a printed summary. Exit 2 on an unknown target or a failed install.

## Lifecycle and operation graph

1. Resolve the target (explicit or menu).
2. Fetch each skill's `SKILL.md` + references into a staging tempdir (all-or-nothing under `set -e`).
3. For each destination home: remove the legacy `tina4-developer`, atomically replace each of the six skill
   dirs, write `.tina4-skills-ref`.
4. `doctor` later reads the marker and reports currency (read-only). A client `update` refreshes every home
   that already has a Tina4 skill.

## Configuration and precedence

- `TINA4_SKILLS_TARGET` selects the target for the piped script; the CLI passes the arg/menu choice.
  `TINA4_SKILLS_REF` overrides the pinned tag (default `3.13.97`). No other configuration.

## Failures, side effects and security

- Side effect: writes user-level skills homes only (never project files). The refresh-on-update is
  conservative - it only touches homes that already opted in, so an update never enables a tool the
  developer did not choose.
- Supply chain (the security axis): the install is `curl | sh` of a hosted script that then `curl`s skill
  bodies from GitHub raw. The skill CONTENT is tag-pinned (good), and the staging design makes a failed
  download leave the destination untouched (good). See the register for the residual gaps (the sh installer
  is fetched from a moving branch and is unsigned/unchecksummed, unlike the signed ps1).
- Safety property: a failed skills refresh never invalidates a successful client update (`main.rs:1758`).

## Wire and persistence contract

The persisted artifacts are the six skill directories and the `.tina4-skills-ref` marker (the release tag)
in each home. The marker is the contract `doctor` reads to classify currency (current / update-available /
offline / not-recorded). The wire contract is the GitHub raw layout
`tina4stack/<repo>/<ref>/.claude/skills/<skill>/{SKILL.md,references/*}`.

## Providers and substitutability

The substitution axes are the target tool (claude/codex/cursor/all -> the three homes) and the ref
(`TINA4_SKILLS_REF`). Adding a tool means a new case in both installers + a new home in `doctor`. The two
installers (sh + ps1) are parallel implementations that must stay in lockstep.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SKILLS-INSTALLER-UNPINNED | The documented sh one-liner fetches `install-skills.sh` from the `main` branch (a MOVING ref) and the script is unsigned and unchecksummed, while the PowerShell installer IS Authenticode-signed - an asymmetric supply-chain posture. The skill CONTENT is tag-pinned, but the installer SCRIPT itself and the fetched skill files have no integrity check beyond TLS. | Serve the installer from the pinned/stable `tina4.com/install-skills.sh` mirror (the same URL `doctor` already trusts) rather than `raw.githubusercontent.com/.../main/...`, and bring the sh path to signing/checksum parity with the ps1 (publish `SHA256SUMS`, verify before executing) per the install-hardening standard. |
| SKILLS-CURRENCY-ORACLE | `doctor`'s "current vs update-available" is defined by the ref in the LIVE hosted `install-skills.sh`, so currency tracks whatever `main` pins right now, not a stable release. A pin bump on `main` flips every installed developer to "update-available" immediately. | Decide the oracle: track the latest RELEASE tag (stable) or keep it on `main` (bleeding edge). Document the choice; if release-tracking, have `doctor` compare against the newest published tag, not `main`'s script. |
| SKILLS-INSTALLER-PARITY | The sh and ps1 installers are parallel hand-maintained implementations that MUST install the identical target set, the same six skills, the same legacy cleanup, and the same ref. The history proves the risk (the `pipefail`/bash-array break made the sh path install NOTHING on dash while macOS + ps1 were fine - invisible to Mac testers). There is no automated check that the two agree. | Add a parity test/CI check that parses both installers and asserts identical targets, skill lists, reference sets, legacy-skill list, and default ref - so a change to one that is not mirrored in the other fails the build. |
| SKILLS-NO-UNINSTALL | There is no `tina4 skills remove`/uninstall; only the legacy `tina4-developer` is auto-removed. A developer who stops using a tool has no CLI path to remove the installed skills from that home. | Low priority: add a `tina4 skills remove <target>` (delete the six Tina4-owned skill dirs + the marker for that home), so the feature is symmetric. |
| SKILLS-PARTIAL-PUBLISH | `publish_skills` is atomic PER skill but not transactional ACROSS the six; a failure partway through publishing (e.g. disk full after skill 3) leaves a mixed set and no updated marker. A re-run fixes it and `doctor` would flag the stale/missing marker, so the blast radius is small - but it is a non-atomic multi-file write. | Low priority: stage the full destination set and swap once (or write the marker only after all six succeed, which it already does - so `doctor` catches the partial). Document that a re-run is the recovery. |

## Owner decisions

- SKILLS-DEC-01 (proposed): harden the sh install path to match the ps1 - serve from the pinned
  `tina4.com` mirror and add checksum/signature verification (SKILLS-INSTALLER-UNPINNED). Highest value; it
  closes the supply-chain asymmetry.
- SKILLS-DEC-02 (proposed): decide and document the `doctor` currency oracle (release tag vs `main`)
  (SKILLS-CURRENCY-ORACLE).
- SKILLS-DEC-03 (proposed): add the sh/ps1 installer-parity check (SKILLS-INSTALLER-PARITY); optionally a
  `skills remove` (SKILLS-NO-UNINSTALL).

## Proposed conformance fixture

The existing Rust unit tests are the base (menu mapping -> target, `all` round-trips through setup config,
installed-target refresh touches only existing homes). Add: an installer-PARITY test (sh and ps1 agree on
targets/skills/references/legacy/ref); a supply-chain test (the resolved installer URL is the pinned mirror,
not `main`; and, once added, a checksum verify step is present); and a `doctor` classifier test (marker +
fetched ref -> current / update-available / offline / not-recorded) - the last already exists per feature
123.

## Integration map

| Consumer | Integration |
| --- | --- |
| `tina4 setup` (124) | Offers Claude / Codex / Cursor / all; installs the skills and, for a new project, writes `CLAUDE.md` + `AGENTS.md`. |
| `tina4 update` / `upgrade` | Refreshes installed skill targets after the client self-update (`main.rs:1726-1766`); a refresh failure never fails the update. |
| `tina4 doctor` (123) | Reads `.tina4-skills-ref` per home and reports Claude / Codex / Cursor currency + legacy residue, read-only. |
| Framework repos | Host the skill bodies under `.claude/skills/<skill>` at each release tag; also track `.cursor/skills` entrypoints. |
| install-skills.sh / .ps1 | The two hosted installers (POSIX sh + signed PowerShell) that do the actual fetch + publish. |

## Breaking changes and migration

- Existing users migrate by running `tina4 skills` (or a client `update`): the installer removes the legacy
  `tina4-developer` skill and records the new ref. Hardening the installer URL/signing (SKILLS-DEC-01)
  changes where the script is fetched from, not what it installs - transparent to users. Adding
  `skills remove` is additive.

## Implementation backlog

1. SKILLS-DEC-01: serve the installer from the pinned mirror + add checksum/signature verification on the sh
   path (supply-chain parity with ps1).
2. SKILLS-DEC-03: the sh/ps1 installer-parity CI check.
3. SKILLS-DEC-02: fix/document the `doctor` currency oracle (release tag vs main).
4. SKILLS-NO-UNINSTALL: optional `tina4 skills remove`.

## Porting capsule

`tina4 skills` is one native Rust command plus two hosted installer scripts; there is nothing to port across
the frameworks (they only HOST the skill bodies). A clean-room reimplementation needs: a target->home map
(claude/codex/cursor/all -> `~/.claude/skills`, `~/.agents/skills`, `~/.cursor/skills`); a TAG-PINNED fetch
of each skill's `SKILL.md` + references into a staging area (all-or-nothing); an atomic per-skill replace
plus a `.tina4-skills-ref` marker; a scoped legacy cleanup (only the superseded skill); a refresh-on-update
that touches only already-installed homes and never fails the client update; and cross-platform installers
kept in lockstep by a parity check. Fetch the installer itself from a pinned, signed/checksummed mirror -
not a moving branch - and keep the currency oracle and the installed ref on the same, documented reference.

## Audit closure checklist

- [x] Boundary and public surface complete (the `skills` command + the two installers).
- [x] Lifecycle and every producer/consumer edge complete (resolve -> stage -> publish -> marker; setup/
  update/doctor edges).
- [x] Configuration, failure, side-effect and security (supply-chain) rules complete.
- [x] Wire/storage (skill dirs + ref marker + GitHub raw layout) and provider contracts complete.
- [x] Native single-implementation behaviour + the sh/ps1 parity requirement recorded.
- [x] Owner ambiguities decided and recorded (SKILLS-DEC-01..03 proposed).
- [x] Proposed test cases (installer parity, supply-chain, doctor classifier) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
