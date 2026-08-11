# Feature 124: CLI setup (guided onboarding wizard)

## Identity and status

- Matrix identity: 124 - `tina4 setup` (guided: language + AI tool + projects folder + name, then install
  + scaffold + optionally serve)
- Audit state: decision-ready
- Audit note: NATIVE Rust command, the most complex in the CLI. Measured 2026-08-11 from `tina4/src/setup.rs`
  (dispatched at `main.rs:258`) and the CLI `CLAUDE.md` (which documents the Windows elevation saga in
  depth), plus the `project_tina4_setup_wizard` memory (a bare-Mac no-CLT path is untested).
- Dependencies: the platform package managers (Chocolatey / Homebrew), git, the AI-skills installer, the
  AI tool (Claude Desktop / Claude Code), `tina4 init` (scaffolding, via `TINA4_INIT_NO_SERVE`), and
  `tina4 serve`.
- Dependants: new / non-terminal users; the primary onboarding path.
- Existing ADRs: none dedicated; the Windows elevation design is documented in the CLI `CLAUDE.md`.

- Catalog phase: CLI (native Rust)

## Why this feature exists

`tina4 setup` takes a brand-new user from nothing to a running project with an AI assistant wired in. It
asks four questions (language, AI tool, projects folder, project name), installs whatever is missing
(runtime, git, skills, AI tool) via the platform package manager, scaffolds the project with its own
`CLAUDE.md` and `.mcp.json`, and offers to start it. It is the turnkey path for people who do not live in
a terminal.

## Boundary

This packet owns the wizard: the menu, the install orchestration (elevation on Windows), the scaffold
call (delegates to `init`), the AI-tool wiring (`CLAUDE.md`, `.mcp.json`, launching Claude Desktop/Code),
and the closing serve. It does NOT own `init`'s scaffolding internals (feature 110), `serve` (feature
111), or the AI-skills fetch (feature 108) - it composes them.

## Existing implementation evidence

- Dispatch: `main.rs:258` `Commands::Setup { dry_run, skip_install, elevated, lang, ai, projects_dir,
  name }`.
- Menu: `choose_language` / `choose_ai` / `choose_projects_dir` / name, run in the user's console FIRST
  (per the CLI `CLAUDE.md`), then installs.
- Installs: runtime/git/skills/AI tool via Chocolatey (Windows) / Homebrew (macOS). Scaffolds via `init`
  (with `TINA4_INIT_NO_SERVE`), writes a project `CLAUDE.md` + a per-project `.mcp.json`
  (`write_project_mcp_json`, wiring Claude Code to `/__dev/mcp`).
- AI default: Claude Desktop (option 1); Claude Code (option 2); "none". Desktop/none path ends with a
  "Start it now?" prompt (`tina4 serve` + open app + launch Desktop via its resolved launcher, never bare
  `claude` on PATH). Claude Code path launches a seeded session (`claude "<FIRST_PROMPT>"`).
- Windows elevation: the menu runs in-console first; `elevate_for_install()` is called only AFTER the
  answers are collected; answers pass to the elevated re-run via env (`TINA4_SETUP_ELEVATED` +
  `TINA4_SETUP_LANG/_AI/_DIR/_NAME`); `pause_if_elevated()` holds the window. A stdin-TTY guard
  (`io::stdin().is_terminal()`) prints "Setup is interactive - open a new terminal and run: tina4 setup"
  and exits 0 (not a scary failure) for a non-interactive stdin; `--dry-run`/`--skip-install`/the elevated
  re-run are exempt.
- Flags: `--dry-run` (preview only), `--skip-install` (scaffold, no installs).

## Public surface contract

`tina4 setup [--dry-run] [--skip-install]` (plus the internal `--elevated`/`--lang`/`--ai`/`--projects-dir`
/`--name` used by the elevated re-run). Interactive by default; `--dry-run` previews the plan;
`--skip-install` scaffolds without installing anything. macOS runs single-console; Windows elevates only
the Chocolatey install.

## Inputs and outputs

- Input: the four menu answers (or the passed env on the elevated re-run), the platform, and the flags.
- Output: installed tools (unless `--skip-install`), a scaffolded project with `CLAUDE.md` + `.mcp.json`,
  and either a running server + launched AI tool or next-step instructions.

## Lifecycle and operation graph

1. Guard stdin (non-interactive -> instruct + exit 0, unless dry-run/skip/elevated).
2. Run the menu in the user's console (language / AI / folder / name).
3. Install missing tools (elevate only for the Chocolatey install on Windows, passing the answers via env).
4. Scaffold the project (`init` with `TINA4_INIT_NO_SERVE`), write `CLAUDE.md` + `.mcp.json`.
5. Desktop/none: "Start it now?" -> `serve` + open app + launch Desktop. Claude Code: launch a seeded
   session.

## Configuration and precedence

- Flags (`--dry-run`, `--skip-install`) and the internal elevation env vars. The AI default is Claude
  Desktop. No `TINA4_*` runtime configuration (setup is a one-time bootstrap).

## Failures, side effects and security

- SIGNIFICANT side effects: installs software (Chocolatey/Homebrew), writes a project, wires an AI tool,
  and launches an app. `--dry-run`/`--skip-install` are the escape hatches; the stdin-TTY guard prevents
  the "drops to the prompt" non-interactive failure (a real, fixed Windows symptom).
- SETUP-WINDOWS-UNVERIFIED (known gap): the real Windows UAC elevation path is UNVERIFIED - Wine cannot
  exercise real UAC, so the elevate-only-the-install design is tested only under Wine (which false-
  positives admin via `net session`). It needs confirmation on a real Windows box (the CLI `CLAUDE.md`
  lists the exact checks).
- SETUP-BARE-MAC (known gap): the bare-Mac no-Command-Line-Tools path is untested (per the setup-wizard
  memory) - a fresh Mac without CLT may not have `brew`/`git` and the flow's behaviour there is unproven.
- Security: setup runs the AI tool via its RESOLVED launcher (never bare `claude` on PATH) and passes a
  first prompt; the installs come from the platform package managers and the tina4 installer (the
  curl-to-shell caveat from `init` applies). No credential handling.

## Wire and persistence contract

The artifacts are the scaffolded project, its `CLAUDE.md`, and its per-project `.mcp.json` (wiring Claude
Code to the live `/__dev/mcp` at the language's port). The elevation env vars are the transient
answer-passing contract between the user-console run and the elevated re-run.

## Providers and substitutability

The substitution axes are the language (five init targets), the AI tool (Desktop / Code / none), and the
platform package manager (Chocolatey / Homebrew). Each is a branch; there is no plugin abstraction.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SETUP-WINDOWS-UNVERIFIED | The real Windows UAC elevation path (elevate only the Chocolatey install, pass answers via env, hold the window) is verified only under Wine, which cannot exercise real UAC and false-positives admin. The production elevation is UNPROVEN. | Verify on a real Windows box against the CLI `CLAUDE.md` checklist (menu shows in-console before UAC; `is_admin_windows()` reports non-admin correctly; the elevated re-run skips the menu and uses the passed answers). Until then, treat Windows setup as provisional. |
| SETUP-BARE-MAC | The bare-Mac (no Command Line Tools) path is untested; a fresh Mac may lack `brew`/`git` and the flow's fallback is unproven. | Test on a fresh Mac (or a CLT-stripped environment); ensure the flow detects a missing CLT and instructs clearly rather than failing opaquely. |
| SETUP-COMPLEXITY | `setup` composes install + scaffold + AI-wiring + platform-specific elevation - the CLI's highest-surface command, hard to test end-to-end and easy to regress (the Windows "drops to prompt" was one such regression). | Keep the pure pieces unit-tested (the menu resolution, the answer env round-trip, the stdin-TTY guard) and maintain the documented manual verification matrix (macOS single-console, Windows elevated, `--dry-run`, `--skip-install`). |

## Owner decisions

- SETUP-DEC-01 (proposed): schedule the real-Windows and bare-Mac verifications; keep Windows setup marked
  provisional until confirmed.

## Proposed conformance fixture

Native Rust tests for the deterministic pieces: the menu answer -> plan resolution; the elevation env
round-trip (`TINA4_SETUP_*` set -> the elevated instance skips the menu and uses them); the stdin-TTY
guard (non-interactive -> exit 0 with the instruction, but `--dry-run`/`--skip-install`/`--elevated`
exempt); and `--dry-run` prints the plan without installing. The install/elevate/serve paths stay
manually verified per the documented matrix (they touch the system and real UAC).

## Integration map

- Dispatch: `main.rs` `Commands::Setup` -> `setup.rs`.
- Composes: `init` (scaffold, `TINA4_INIT_NO_SERVE`), `serve` (start), the AI-skills installer (feature
  108), the AI tool launcher, `write_project_mcp_json` (Claude Code wiring).
- Documentation: the CLI `CLAUDE.md` setup section (the reference for the elevation design + the manual
  checklist).

## Breaking changes and migration

- Setup is a bootstrap; changes affect new-project onboarding, not existing projects. The Windows
  verification may surface fixes, not a documented migration.

## Implementation backlog

1. Verify the real-Windows UAC path (SETUP-WINDOWS-UNVERIFIED) against the CLI `CLAUDE.md` checklist.
2. Test + harden the bare-Mac no-CLT path (SETUP-BARE-MAC).
3. Keep the pure-piece unit tests + the documented manual matrix (SETUP-COMPLEXITY).

## Porting capsule

`tina4 setup` is one native Rust command; nothing to port across frameworks. A clean-room
reimplementation needs: a four-question menu run in the user's console FIRST; platform installs (Homebrew
/ Chocolatey) with elevation scoped to ONLY the install (pass answers to the elevated re-run via env);
`init` scaffolding with the serve prompt suppressed; a project `CLAUDE.md` + `.mcp.json` wiring the AI
tool to `/__dev/mcp`; a stdin-TTY guard that exits 0 with instructions when non-interactive; `--dry-run`/
`--skip-install`; and an AI-tool launch via a resolved path (never a bare PATH lookup). Verify the real-
UAC and bare-Mac paths on real machines - the two paths a VM/Wine cannot prove.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage (scaffold, .mcp.json, elevation env) and provider contracts complete.
- [x] Native single-implementation behaviour + known unverified paths recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases (pure pieces) + manual matrix complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
