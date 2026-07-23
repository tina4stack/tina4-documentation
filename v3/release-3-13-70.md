# Release 3.13.70 — coordinated all-4 patch

## Goal
Fix the Node consumer-install import break (#32 cluster) plus a cross-framework
correctness batch (ORM NULL-for-unset, Swagger decorator stacking, Firebird
charset regression), ship as one coordinated 3.13.70. Python-master-first, real
no-mock tests, local-merge-no-PR, tag to publish.

## Scope
### A. Node import fix (Node-only, independent) — issue #32
- [ ] Rewrite EVERY bare `@tina4/*` specifier (static value, `await import()`, and `import type`) in packages/{core,orm,swagger}/src to RELATIVE paths so the published tarball is self-contained. Fixes: `/orm` subpath crash, `response.render()`/Frond (core `await import("@tina4/frond")`), lazy `@tina4/orm` (cache/mcp/devAdmin), orm's own `@tina4/core`, ai.ts self-import, and consumer `tsc` (type imports).
- [ ] Declare `mongodb`/`pg`/`redis`/`@aws-sdk/client-s3`/`@aws-sdk/s3-request-presigner` as `optionalDependencies` (lazy DB/storage drivers).
- [ ] REAL regression test: `npm pack` -> install tarball into a temp dir -> import `.`, `/orm`, `/frond`, `/swagger` AND exercise `response.render()`; assert all resolve. (The gap that let #32 ship.)

### B. ORM: NULL-for-unset breaks NOT NULL DEFAULT (all 4) — php #165, engine-agnostic
- [ ] Python-master FIRST: does Python insert() emit explicit NULL for unset/None columns, or omit them? Decide correct semantics (omit unset columns so DB DEFAULT applies; keep explicit NULL only when the caller set it to None). [[feedback_python_master_governance]] — if Python is also wrong, FIX master; if PHP diverged, PHP mirrors Python.
- [ ] Real test: NOT NULL DEFAULT column left unset inserts successfully (default applies); explicit None still writes NULL. All 4.

### C. Swagger stacked-decorator metadata loss (all 4) — python #59
- [ ] Python-master: decorators accumulate `_swagger_*` (functools.wraps + copy pre-existing, or set on the underlying handler). Verify PHP/Ruby/Node analog.
- [ ] Real test: @summary+@description+@tags stacked -> all present in the spec.

### D. Firebird charset regression (all 4) — php #160
- [ ] Master contract: `?charset=` URL param + `TINA4_DATABASE_CHARSET` env (default UTF8, non-breaking). Read in the Firebird adapter connect path.
- [ ] Check ALL 4 Firebird adapters for the hardcoded UTF8; apply the override where present. Reported/verified on PHP (double-encode of UTF-8-under-NONE).

### E. Investigate (fold in only if it is a real gap) — python #57
- [ ] db.execute() silently neither raised nor persisted a bool->int type mismatch (PG), table stayed empty. Verify against current execute-raises contract; if a distinct swallow path exists, fix loud + test. Else document why it is already covered.

## Cross-cutting
- [ ] Version bump 3.13.70 all 4 (done centrally at the end, not per-worker) + CLAUDE.md counts.
- [ ] Docs: Api chapter already covers upload/etc; add nothing unless behaviour changes. Release notes 3.13.70 (Breaking? #165 is a fix not a break; #160 non-breaking; #32 fix).
- [ ] Independent verification (re-run all 4 suites at HEAD myself); pack-install repro of #32.
- [ ] Merge local to v3, tag 3.13.70, publish, verify registries live; comment on #32/#165/#59/#160/#57 (reporters close).

## Waves
- Wave 1 (parallel, 1 writer/repo): Worker A = tina4-nodejs import fix (A). Worker B = tina4-python master (B+C+D-python + E investigation).
- Wave 2 (after B lands, the master contracts known): mirror B/C/D to PHP, Ruby, Node (Node mirror after Worker A merges).
- Wave 3: central version bump + verify + tag 3.13.70 + publish + docs/notes.

## Status: SHIPPED 2026-07-11

3.13.70 live on all 5 registry artifacts (PyPI tina4-python, Packagist
tina4stack/tina4php, RubyGems tina4 + tina4ruby, npm tina4-nodejs). Docs
(Jenkins) + book pushed; docs:build + audit-truth --strict green first.
Payload: Node import #32, ORM NULL-for-unset #165, Swagger stacked-metadata #59
(PHP-only real fix; Python/Ruby already correct + locked in; Node fine),
Firebird charset #160, Api mirrors (from 3.13.69), dev-MCP tool fixes x4,
seed_table wire-shape parity. Independent verification: Python conformance 7/7 +
suite 3474/0, PHP conformance 3/48 + suite 3761/0, Ruby conformance 4/0, Node
committed-HEAD typecheck 0 + conformance 72/0 (verified in an isolated worktree,
clean of an unrelated uncommitted devAdmin.ts change belonging to the
docs/migrate-create-summary workstream). Commented (not closed) on
tina4-nodejs#32, tina4-php#165, tina4-php#160, tina4-python#59. Skipped the
stray #57 (unrelated / already closed). install-skills not bumped (no skill
change).
