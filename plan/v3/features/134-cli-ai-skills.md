# Feature 134: CLI AI-skills installation and refresh

## Identity and status

- Matrix identity: 134 - CLI AI-skills installation and refresh
- Audit state: implementation-ready (`tina4` v3.8.69)
- Dependencies: GitHub raw skill sources pinned by `TINA4_SKILLS_REF`; local AI-tool skills directories
- Dependants: `tina4 setup`, `tina4 update` / `tina4 upgrade`, `tina4 doctor`, and the Tina4 framework repositories
- Existing ADRs: none
- Shared fixtures: Rust unit tests for menu mapping and installed-target detection

## Why this feature exists

Developers need one clear way to install current Tina4 guidance for the coding tool they use, without shell-specific environment variables or manual copies.

## Boundary

This native Rust-client feature installs the six released Tina4 skills into a selected user-level directory, reports their currency, and refreshes already-installed targets during a client upgrade. It does not write project files during a global refresh and does not install third-party AI applications.

## Public surface contract

`tina4 skills` opens a menu with Claude, Codex, Cursor, and all-three choices. Automation may pass a target directly: `tina4 skills claude`, `tina4 skills codex`, `tina4 skills cursor`, or `tina4 skills all`.

`tina4 update` and its `tina4 upgrade` alias refresh only locations that already contain a Tina4 skill. If all three are present, the client uses the single `all` installer target. This avoids enabling an AI tool the developer did not choose.

## Inputs and outputs

| Target | User-level skills directory |
| --- | --- |
| Claude | `~/.claude/skills` |
| Codex | `~/.agents/skills` |
| Cursor | `~/.cursor/skills` |

Each installation contains `tina4-developer-python`, `tina4-developer-php`, `tina4-developer-ruby`, `tina4-developer-nodejs`, `tina4-js`, and `tina4-maintainer`, plus the `.tina4-skills-ref` marker. The installer removes only the superseded `tina4-developer` directory.

## Lifecycle and side effects

1. The client prompts for a target or accepts an explicit target.
2. The hosted installer downloads complete skill bodies from the pinned framework release into a temporary directory.
3. It replaces only Tina4-owned skill directories in the selected destination and records the installed release ref.
4. `tina4 doctor` reports each location as current, stale, missing, or legacy without writing anything.
5. A later client update refreshes every target where Tina4 skills already exist.

## Failure, safety and migration rules

- A failed skills refresh never invalidates a successful client update.
- Global refreshes never modify project `CLAUDE.md`, `AGENTS.md`, or `.cursor/skills` entrypoints.
- Existing users migrate by running `tina4 skills`; the installer removes the legacy generic developer skill and records the new ref.
- The PowerShell installer is Authenticode-signed at release finalization. Its signature must be renewed whenever the script changes.

## Integration map

| Consumer | Integration |
| --- | --- |
| `tina4 setup` | Supports Claude, Codex, Cursor, or all three; all writes both `CLAUDE.md` and `AGENTS.md` in new projects. |
| `tina4 update` / `upgrade` | Refreshes installed skill targets after the client update check. |
| `tina4 doctor` | Reports Claude, Codex, and Cursor skill currency and legacy residue. |
| Framework repos | Track `.cursor/skills` entrypoints alongside canonical `.claude/skills` bundles. |
| Documentation | Explains the menu-driven installation flow and global paths. |

## Verification

- `setup::tests::skills_menu_maps_each_supported_target`
- `setup::tests::all_ai_choice_round_trips_in_setup_config`
- `installed_skills_refreshes_only_existing_targets`
- `cargo test`: 286 passed, 2 intentional ignored live tests on Windows.
- `cargo build --release`: passed on Windows.
