# Unified Tina4 Client Onboarding

**Outcome:** Every shipped Tina4 skill and public onboarding page uses the unified `tina4` client as the canonical way to create and start projects, with tina4-js scaffolding and generators prominent and executable.

## Scope

- [x] Make `tina4 init <language> <project>` the first project-creation command in every framework skill.
- [x] Make `tina4 serve` the only primary project-start command in every framework skill and onboarding page.
- [x] Add a scaffold-first quick start to the tina4-js skill.
- [x] Make tina4-js page and component generators prominent in the skill and package CLI help.
- [x] Synchronize Claude, Codex, and Cursor skill copies from their canonical sources.
- [x] Correct the JavaScript book and public Get Started page.
- [x] Synchronize book sources into the documentation site.

## Parity

| Framework | Unified init | Unified serve | Resource scaffolding | Skill mirrors |
|---|---:|---:|---:|---:|
| Python | [x] | [x] | [x] | [x] |
| PHP | [x] | [x] | [x] | [x] |
| Ruby | [x] | [x] | [x] | [x] |
| Node.js | [x] | [x] | [x] | [x] |
| tina4-js | [x] | [x] | [x] | [x] |

## Tests

- [x] Add executable tina4-js CLI help/create regression coverage.
- [x] Add a non-network unified tina4-js scaffold regression gate.
- [x] Run each affected framework's skill validation.
- [x] Run the real unified and package tina4-js scaffolders in temporary directories.
- [x] Run documentation truth, link, and build gates.

## Bugs

- [x] tina4-js package scaffolder pinned obsolete `tina4js` 1.0.7 (`9a2bdb7`).
- [x] Unified client tina4-js scaffolder pinned obsolete `tina4js` 1.5.1 (`7da1887`).
- [x] tina4-js package CLI implemented `generate` but omitted it from help (`9a2bdb7`).
- [x] Public Get Started made `npx tina4js` and `npm run dev` the JavaScript default.
- [x] Skill copies had drifted between Claude, Codex, and Cursor.

## Commits

- `7da1887` - unified client scaffolds tina4-js 1.5.2 and carries a regression gate.
- `9a2bdb7` - tina4-js CLI, tests, and skill use the unified workflow.
- `7093020` - Python and shared frontend skills synchronized.
- `2463041a` - PHP and shared frontend skills synchronized.
- `8b202bc` - Ruby and shared frontend skills synchronized.
- `985884c` - Node.js and shared frontend skills synchronized.
- `bfaceb6` - books use the unified client for project startup.
- `75e8f05` - PHP and JavaScript book PDFs rebuilt and visually verified.

## Status: Complete
