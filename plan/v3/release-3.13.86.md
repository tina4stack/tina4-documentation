# Release 3.13.86 (all 4 frameworks + docs)

## Scope (commits on v3 since 3.13.85 tag)
Ships everything merged to v3 since 3.13.85. Highlights:
- **Breaking (DB write result):** db.insert/update/delete return a DatabaseResult in
  all 4. PHP was bool, Ruby was Hash -> now DatabaseResult. Node field-name rename
  rowsAffected->affectedRows, lastInsertId->lastId. (owner-approved unification)
- **nodejs#32:** exports map runtime -> built dist (importable under plain node) + pretest build.
- Benchmarks: 9-category carbon suites + competitor comparisons + timing fixes (all 4).
- perf(frond): quote-scanner early-bail (2.5x Node / 9.4x Python render).
- dev-admin: rebuilt SPA bundle + cold-start retry + duplicate-bundle dedup (all 4).
- Python: orm quote-identifiers + reserved-word generate guard + hot-reload stale-route
  retire + PEP 562 lazy subsystem imports. Ruby: fetch hydration hoist (#355/#359) +
  autoload. Node: DB-methods-async docs (#354).

## Version: 3.13.85 -> 3.13.86

### Version-source files (bump 3.13.85 -> 3.13.86)
- python:  pyproject.toml, llms.txt, CLAUDE.md (x2), AGENTS.md, CONVENTIONS.md
- php:     llms.txt, CLAUDE.md
- ruby:    lib/tina4/version.rb, llms.txt, CLAUDE.md (x2)
- node:    package.json, packages/core/package.json, packages/cli/package.json, llms.txt, CLAUDE.md (x2)
(+ each repo CHANGELOG.md gets a new 3.13.86 entry; README/copilot-instructions checked for stale ver.)

### Release notes
- documentation + book /*/36-releases.md: the "Unreleased" entries (write-result +
  Node exports) -> promote to "## 3.13.86 (2026-07-25)"; add benchmarks/perf/dev-admin lines.
- documentation#37 env-var doc already committed (a77e9bd) — rides this docs push.

## Gates (in order)
- [ ] Node full suite green (DONE this session: 5731/0 + vitest 44/44 + typecheck).
- [ ] Python / PHP / Ruby full suites — local where services allow; CI authoritative.
- [ ] pnpm docs:build GREEN + audit-truth --strict GREEN (MANDATORY before docs push).
- [ ] Commit version bumps on each v3 (local).
- [ ] Push v3 x4 -> CI green (authoritative gate for service-dependent suites).
- [ ] Push docs main (Jenkins deploys tina4.com) — only after docs:build green.
- [ ] Tag 3.13.86 x4, push tags -> CI publishes PyPI / Packagist / RubyGems / npm.
      IRREVERSIBLE — only after CI green on the pushed v3.

## Notes / traps (from prior releases)
- npm publishes ROOT tina4-nodejs; Ruby ships tina4 + tina4ruby; Packagist = tina4stack/tina4php.
- PHP version is tag-driven (composer.json may carry no version field).
- Registries lag: PyPI info.version lags, use /pypi/<pkg>/<ver>/json 200 to confirm.
- Publish = push the TAG (CI does the publish); local npm/pypi 401 is a red herring.
- Untracked benchmarks/comparison_report.json in python — do NOT commit.

## CI results (v3 push, HEAD version-bump commits)
- Python 2141ea3: Tests GREEN. Ruby 89a8564: GREEN. Node bc0e746: GREEN.
- PHP ef088762: Tests **RED** (4 failures) — CI's full MySQL/MSSQL/Postgres stack caught
  what the local partial-service phpunit could not (independent-verification lesson).
  Failures were all in the write-result change:
    1-2) BatchInsertTest MySQL/MSSQL batch: assertTrue($ok) on a now-DatabaseResult object
         (=== true fails). Result was correct (affectedRows=3). Stale assertion.
    3)   BatchInsertTest MSSQL single: assertSame(1, affectedRows) but wrapper returned 0 —
         PG/MSSQL adapters don't surface a rowcount on the single-insert path. REAL gap.
    4)   PostgresUuidPkTest: assertTrue($ok) on a DatabaseResult. Stale assertion.
- FIX (php c85d6501): Database::writeResult() floors a single insert's affectedRows at 1
  (minAffected param; update/delete pass 0; batch unaffected) — matches the documented
  contract + Python master (adapters read the real rowcount of 1). Fixed the 3 stale
  assertions (assert affectedRows===3 / lastId non-empty). Full local phpunit OK
  (3990, 0 fail, 110 gated-skips). Re-pushed v3; CI re-running on c85d6501.
- PARITY: PHP was the outlier (its PG/MSSQL adapters didn't surface the count); Python/
  Ruby/Node already reported 1 (green). The floor brings PHP INTO parity, not away.

## Status: SHIPPED (2026-07-25)
- All 4 v3 branches CI-green (python 2141ea3 · php c85d6501 · ruby 89a8564 · node bc0e746).
- Tag 3.13.86 pushed x4 -> publish.yml SUCCESS on all: PyPI / Packagist / RubyGems / npm.
- Registries confirmed live: PyPI 200, RubyGems 3.13.86, npm 200, Packagist 3.13.86.
- Docs main pushed (c8ac65d..8c207f7). Book main: remote had a bot PDF-regen commit
  (391d64d) ahead of local -> the piped push masked a non-fast-forward reject; reconciled
  by rebasing the 4 release-note commits onto it (no file overlap: bot touched *.pdf, mine
  touched 36-releases.md) and re-pushed unpiped (391d64d..c032bc5). Both now in sync.
- LESSON (again): the "piped git push masks a rejected push" trap fired on the book push;
  the trailing `push exit: 0` was the pipe, not git. Always push unpiped, then verify with
  `git log origin/main..HEAD` empty in BOTH directions.

## Known pre-existing (NOT touched this release)
- CHANGELOG.md in all 4 repos is drifted since ~3.13.82 (still lists 3.13.84/85 content;
  python says "current tagged release is 3.13.84"). The file's own header defers to the
  docs release notes as authoritative (which ARE updated). Reconciling CHANGELOG.md is a
  separate cleanup, deliberately out of scope here to avoid release risk.
