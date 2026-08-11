# Feature 108: AI coding-tool integration

## Identity and status

- Matrix identity: 108 - AI coding-tool integration (detect AI assistants in a project, install
  Tina4-aware context files, fetch the framework skills)
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11 at Python `ai/__init__.py` (742), PHP
  `Tina4/AI.php` (917), Ruby `lib/tina4/ai.rb` (927), Node `packages/core/src/ai.ts` (1005). The Cursor
  marker-file typo was cross-checked in all four AI_TOOLS lists. Suites reported, not re-run.
- Dependencies: the network (GitHub raw for skills), the framework's own `CLAUDE.md` (bundled context for
  claude-code), and the language's HTTP primitive (urllib / curl / Net::HTTP / a blocking child `fetch`).
- Dependants: the `tina4 ai` CLI command; `tina4 init --ai` scaffolding (Python).
- Existing ADRs: none.
- Shared fixtures: NONE. `ai_contract.json` is owed. Each language has real, no-mock suites (Python ~56,
  PHP ~37, Ruby ~39, Node ~40) that fetch REAL GitHub for the skills test - but with no offline skip, and
  Python's are non-hermetic (write real `~/.claude/skills`, shell real `pip`).

- Catalog phase: Developer integrations

## Why this feature exists

The integration makes a fresh project legible to whatever AI assistant the developer uses. It writes a
Tina4-aware context file in each tool's convention (CLAUDE.md, .cursorrules, AGENTS.md, and so on) so the
assistant understands the framework's routes, ORM, and conventions instead of guessing, and it fetches
the framework's skill packs so the assistant can follow the real patterns. One `tina4 ai` and every
assistant in the repo speaks Tina4.

It is escape-by-convention: re-running it refreshes a marked block rather than duplicating it, and it
degrades gracefully offline (the context files still land even when the skills fetch fails).

## Boundary

This packet owns the AI_TOOLS registry, the per-tool context-file writer with its idempotent marker
merge, the `install_skills` GitHub fetch, and the `generate_context` per-tool guide. It owns the
`tina4 ai` CLI command.

It does NOT own: the skill packs themselves (they live in the framework repos and are fetched); the
framework `CLAUDE.md` (consumed as claude-code's guide); the `tina4-ai` pip package (option 8 shells out
to install it). The module is a callee of the CLI only.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Module | `ai/__init__.py` functions | `class AI` (static) | `module AI` (self methods) | module of functions |
| Public surface | detect-centric: detect_ai, detect_ai_names, status_report, install_context | menu-installer: installAll, installSelected, showMenu | menu-installer: install_all, install_selected, show_menu | menu-installer: installAll, installSelected, showMenu |
| Has detect_ai/status_report | YES | no | no | no |
| Has install_all | no (has install_context) | yes | yes | yes |
| AI_TOOLS | 7 tools | 7 tools | 7 tools | 7 tools |
| cursor context_file | `.cursorules` (typo) | `.cursorules` (typo) | `.cursorules` (typo) | `.cursorules` (typo) |
| Skills HTTP | urllib | curl / file_get_contents | Net::HTTP | blocking child `fetch` |
| `--all` CLI flag | matches bare `all` (broken) | matches bare `all` (broken) | `--all` honored | `--all` honored |
| Focused tests | ~56 real | ~37 real | ~39 real | ~40 real |

## Public surface contract

The intended shared operations: detect which tools a project uses; install a Tina4-aware context file per
tool (idempotently); fetch the framework skills; and generate a per-tool guide. The 7-tool registry
(claude-code, cursor, copilot, windsurf, aider, cline, codex), the context-file-exists detection, the
idempotent marker merge, the `install_skills` fetch, and `generate_context` are identical in shape across
all four.

The named surface diverges (AI-SURFACE): Python exposes `detect_ai`, `detect_ai_names`, `status_report`,
and `install_context(root, tools)`; PHP, Ruby, and Node instead expose `install_all` and a menu flow
(`show_menu` -> `install_selected`) and have NONE of the detect/report functions. So the same feature has
two different public APIs - a "detect and report" one (Python) and a "menu installer" one (the other
three).

## Inputs and outputs

- Detect input: a project root. Output (Python): a list of tools each tagged installed/not. The other
  three have no aggregate detector; they check per tool via `is_installed`.
- Install input: a root and a selection (tool names in Python's `install_context`; menu numbers or "all"
  in `install_selected`/`install_all`). Output: the list of tools whose context file was written.
- `install_skills` input: a root and optional targets. Output: the list of skills whose `SKILL.md`
  downloaded. It writes to the project `.claude/skills` AND `~/.claude/skills` by default.
- Context-file content: a tool-specific framework guide (written on fresh install or migration) plus a
  shared skill block (refreshed on every run, between markers).

## Lifecycle and operation graph

1. `is_installed` checks whether a tool's context file exists (config_dir is never consulted).
2. Install resolves the selection to tools; for each, `write_or_merge` either writes fresh (guide +
   block), refreshes the marked block in place (idempotent), migrates an old pre-v3.13.9 framework dump,
   or appends the block to user content.
3. For claude-code, install additionally fetches the skills (`install_skills`) into project + home.
4. `install_skills` fetches each skill's `SKILL.md` and reference files from
   `raw.githubusercontent.com/tina4stack/<repo>/<ref>/.claude/skills`, where `<ref>` is
   `TINA4_SKILLS_REF` else the framework version else `main`; a failure skips that skill without raising.

## Configuration and precedence

- `TINA4_SKILLS_REF` - the skills release tag, else the framework version, else `main`. The only env var
  read in all four.
- Global skills dir: `~/.claude/skills` (HOME/USERPROFILE).
- No other configuration. Escaping/merge behaviour is unconditional.

## Failures, side effects and security

- AI-CURSOR-TYPO (universal functional bug): every language's `cursor` entry sets `context_file` to
  `.cursorules` (single medial `r`). Cursor reads `.cursorrules` (double `r`), so the written file is
  never picked up - Cursor integration is silently broken in all four, and every language's tests assert
  the typo, so it is load-bearing.
- Network offline: handled by degrade in all four - the skills fetch returns null/empty and the skill is
  skipped, the context files are still written, nothing raises. But a skill is counted "installed" as
  long as its `SKILL.md` landed, even if its reference files failed (AI-INSTALLED-OPTIMISTIC, universal).
  Empty `references/` directories are created before the fetch, so even a total offline run litters
  `.claude/skills/<skill>/references/` (Python/Ruby confirmed).
- Non-hermetic tests (Python, sharpest): several Python tests install claude-code, which transitively
  fetches REAL GitHub and writes the developer's REAL `~/.claude/skills`, and the "all" path shells
  `pip install --upgrade tina4-ai`. The dedicated network test isolates via explicit targets; the others
  do not. In all four the network test has NO offline skip, so it turns red (not skipped) when GitHub is
  unreachable.
- Unknown input: Python's `install_context` RAISES `ValueError` on an unknown tool name, but
  `install_selected` silently ignores an unknown number (asymmetric); `generate_context` on an unknown
  name falls back (Python to a universal string, PHP to cursor, Ruby/Node to claude-code - AI-DEFAULT).
- No security surface beyond the network fetch (HTTPS with a 15s timeout and cert verification in all
  four) and writing files under the project and `~/.claude`.

## Wire and persistence contract

The persisted artifacts are the per-tool context files and the fetched skill files under `.claude/skills`
(project + home). The context file carries a marked block (`<!-- tina4-skills:start -->` ...
`<!-- tina4-skills:end -->` for markdown, `# tina4-skills:start` ... for rule files) that is replaced,
not duplicated, on re-run. The fetch URL shape
(`raw.githubusercontent.com/tina4stack/<repo>/<ref>/.claude/skills/<skill>/SKILL.md`) and the ref
resolution are identical across the four.

## Providers and substitutability

There is no pluggable provider. The tool registry is fixed (7 tools), and the skills source is fixed
(GitHub raw). The only substitution seam is the HTTP transport, which is language-native (urllib / curl /
Net::HTTP / a blocking child `fetch`) and not injectable - the network tests hit real GitHub because
there is no transport seam and mocks are disallowed.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| AI-CURSOR-TYPO | UNIVERSAL functional bug (all four): the `cursor` `context_file` is `.cursorules` (missing the second `r`). Cursor reads `.cursorrules`, so the written context is never loaded - Cursor integration is silently dead framework-wide. Every language's tests assert the typo. | FIX all four: change `.cursorules` to `.cursorrules` in the AI_TOOLS list AND update the tests that bless the typo. Add a regression asserting the real Cursor filename. (Consider also emitting `.cursor/rules/*.mdc`, Cursor's newer convention, but the filename fix is the minimum.) |
| AI-SURFACE | The public surface diverges 1-vs-3. Python exposes `detect_ai`, `detect_ai_names`, `status_report`, `install_context`; PHP/Ruby/Node expose `install_all` and the menu flow with NONE of the detect/report functions. Same feature, two APIs. | OWNER DECISION (AI-DEC-02). Recommendation: unify on the full set - add `detect_ai` / `detect_ai_names` / `status_report` (cheap wrappers over `is_installed` + the registry) to PHP/Ruby/Node, and add `install_all` to Python (or keep `install_context(tools=None)` as its equivalent and alias it). A consistent surface matters because this feature's whole job is to be discovered by tooling. |
| AI-CLI-FLAG | The `tina4 ai` usage advertises `[--all]` in all four, but Python and PHP match the BARE word `all` (`args[0] == "all"`), so `tina4 ai --all` silently drops to the interactive menu; Ruby and Node honor `--all`. | FIX Python and PHP to honor `--all` (accept both `--all` and bare `all`). Node additionally documents a `--force` flag in its help that the handler never reads (a stale no-op since the installer became non-destructive) - remove it from the help. |
| AI-PY-ALL | Python only: `__all__` lists `install_all`, which does not exist, so `from tina4_python.ai import *` raises `AttributeError`; it also omits the real `detect_ai` / `status_report` / `install_context` / `install_skills`. | FIX Python: correct `__all__` to the real exported names. Tie to AI-DEC-02 (if `install_all` is added, the name becomes real). |
| AI-PY-WHEEL | Python only: `generate_context("claude-code")` reads the repo-root `CLAUDE.md`, which sits OUTSIDE the `tina4_python` package, so an installed pip wheel does not ship it and claude-code silently falls back to a much shorter generic string. Dev checkouts and installed users get different context. | FIX Python: bundle the framework guide inside the package (or ship `CLAUDE.md` as package data) so installed users get the full guide. The other three ship `CLAUDE.md` at the framework root that IS in the package, so they are unaffected. |
| AI-DEAD-COMMANDS | Python: `_install_claude_skills` copies from `templates/ai/claude-commands/`, which does not exist in the tree, so the "Claude commands" install is a permanent silent no-op despite the docstring. | Verify across all four; remove the dead path or ship the templates it expects. |
| AI-TEST-HYGIENE | The network test has no offline skip in any language (red offline). Python's other tests are non-hermetic: they fetch real GitHub and write the real `~/.claude/skills` and shell `pip install` on every run. | OWNER DECISION (AI-DEC-04): isolate the tests to a temp home (pass explicit targets / redirect HOME) so they never mutate the developer's machine, and add a "skip if GitHub unreachable" guard to the network test (a real reachability check, not a mock) so offline runs skip rather than fail. |
| AI-DEFAULT | `generate_context` on an unknown tool name falls back differently: Python to a universal string, PHP to cursor, Ruby/Node to claude-code. | Low priority. Pick one fallback (claude-code is the natural default) uniformly. |
| AI-FIXTURE | No `ai_contract.json`, no CONTRACT-MAP row, no ADR. Four real suites but a divergent surface and a shared functional bug. | Add `ai_contract.json` (below) and the first AI-integration ADR once the surface and Cursor filename are fixed. |

## Owner decisions

- AI-DEC-01 (proposed): fix the Cursor filename (`.cursorrules`) in all four and the tests that bless it.
- AI-DEC-02 (proposed): unify the public surface (detect/report + install_all everywhere).
- AI-DEC-03 (proposed): honor `--all` in Python and PHP; drop Node's phantom `--force` help.
- AI-DEC-04 (proposed): fix the Python-specific bugs (`__all__`, wheel `CLAUDE.md`, dead commands) and the
  test hygiene (temp home, offline skip) in all four.

## Proposed conformance fixture

`ai_contract.json` - the same scripted install per language against a temp project + temp home (no
mocks; the network case pinned to a real ref, skipped only on a real reachability failure). Cases:

- AI_TOOLS: exactly 7 tools with the ratified context files (cursor is `.cursorrules`, the AI-CURSOR-TYPO
  witness - fails on all four today).
- Detection: a tool with its context file present is installed; a config_dir alone is not.
- Idempotent merge: install, then re-install; the second run is a no-op (no duplicate block).
- Migration: an old pre-v3.13.9 framework header is replaced.
- Append: user content is preserved and the block is appended.
- Skills fetch (pinned ref, real GitHub, skip-if-unreachable): SKILL.md lands in project AND home.
- Unknown tool: name raises (or is reported), and `generate_context` falls back to the ratified default.
- Surface: `detect_ai` / `status_report` / `install_all` exist and behave identically (per AI-DEC-02).

## Integration map

- Exports: each language exports the registry and the install/generate functions (Python also the
  detect/report set; the others also `install_all`).
- CLI: `tina4 ai [--all]` (interactive menu otherwise); Python also `tina4 init --ai`.
- Skills: fetched from the framework repos on GitHub; claude-code install pulls them into project + home.
- Documentation: the CLAUDE.md AI sections and each CLI help advertise `[--all]` (broken in Python/PHP)
  and, in Node, `--force` (a no-op); reconcile with the fixes.

## Breaking changes and migration

- AI-CURSOR-TYPO fix: the Cursor context file moves from `.cursorules` to `.cursorrules`. Existing users
  have a stale `.cursorules` that was never read anyway; the fix simply starts writing the correct file.
  Document that the old file can be deleted.
- AI-SURFACE unification: additive (new functions), non-breaking.
- AI-CLI-FLAG: `--all` starting to work is additive (bare `all` keeps working).
- AI-PY-WHEEL: installed users start getting the full guide - an improvement, not a break.

## Implementation backlog

Dependency-ordered:

1. Fix AI-CURSOR-TYPO in all four (list + tests) and write the first AI-integration ADR.
2. Settle AI-DEC-02 and unify the surface (detect/report + install_all everywhere).
3. Fix AI-CLI-FLAG (Python/PHP `--all`, Node help) and the Python-specific bugs (AI-PY-ALL, AI-PY-WHEEL,
   AI-DEAD-COMMANDS).
4. Fix test hygiene: temp home + offline-skip for the network test in all four.
5. Author `ai_contract.json` and a runner per language; flip owed to proven; add the CONTRACT-MAP row.

## Porting capsule

A clean-room implementation needs: the fixed 7-tool registry (with `.cursorrules`, not `.cursorules`);
`is_installed` by context-file existence; an idempotent marker merge (`tina4-skills:start/end`, HTML
comments for markdown and hash comments for rule files) with the four branches (fresh, refresh-in-place,
migrate-old-dump, append); `install_skills` fetching `SKILL.md` + references from
`raw.githubusercontent.com/tina4stack/<repo>/<ref>/.claude/skills` (ref = `TINA4_SKILLS_REF` else version
else `main`) into project and home, degrading on failure; `generate_context` returning the bundled
framework guide for claude-code and per-tool guides otherwise; a `tina4 ai [--all]` CLI honoring both
`--all` and bare `all`; and the unified detect/report + install surface. This packet is sufficient for a
clean-room implementation once AI-DEC-01/02 are settled.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
