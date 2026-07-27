# Parity feature-gap audit — CLOSED as FALSE POSITIVE (2026-07-25)

## What this was
A cross-framework parity audit (2 tina4-dev agents) produced two "feature-gap"
lists claiming tina4-php and tina4-nodejs were missing CLI features vs the Python
master. The lists were filed via the `tina4_bug` MCP tool (draft links only —
no token, so NO GitHub issues were ever created; `tina4_bug` is report-only with
no comment/close operation). Draft tracker refs: php `daf66d5f55`, node `82add338f4`.

## Verdict: the FEATURE gaps were not real
Verified directly against the actual command + generator registries (not greps):

- **tina4-nodejs** `COMMANDS` (packages/cli/src/bin.ts) registers:
  init, serve, migrate (+migrate:create/status/rollback), routes, test, queue,
  build, generate, seed, metrics, **console**, **ai**, **commands** (with `--json`
  manifest via buildCommandManifest), help.
  `GENERATORS` (packages/cli/src/commands/generate.ts) has ALL 14 targets:
  model, route, **crud** (= "Model + migration + routes + form + view + test"),
  migration, middleware, test, **form**, **view**, auth, service, queue,
  validator, seeder, websocket, listener.
- **tina4-php** `bin/tina4php` has the same full surface (ai, console,
  commands, generate[crud/form/view/...], metrics, ...).
- **doctor / deploy** are NOT per-framework — they live in the shared Rust CLI
  (tina4/src/doctor.rs, tina4/src/deploy.rs) and reach all 4 frameworks via the
  `tina4` binary. PHP's manifest lists them as delegated.
- **doc-truth** = tina4-documentation/scripts/audit-truth.py (a docs-repo CI gate),
  never a per-framework command.

Every item on both lists was already shipped or shared. NOTHING to build.
The earlier "Node is missing console/commands/ai/crud-UI" claim was a thin-grep
artifact (GENERATORS is an object registry; a keyword grep only caught literal
strings). Root-cause lesson: read the dispatch REGISTRY, never infer a CLI
surface from a grep.

## The REAL parity miss is behavioral, not features
The genuine cross-framework drift the audit surfaced (code-traced; live-confirm
pending), all clustered in DB engines with NO live CI coverage:
- Node Firebird `rollback()` silent no-op  (twin of the PHP pdo_firebird bug
  fixed this session; PdoAdapterTrait transactionsNeedAutocommitToggle hook)  [HIGH]
- Node PG `_inTransaction` never set -> batch-in-txn rollback doesn't roll back  [MED-HIGH]
- Firebird/ODBC affectedRows hardcoded; PHP PG update/delete stale affectedRows  [MED]
- MySQL numeric-as-string (both) vs PG native reads  [MED]
- Node Firebird BLOB/JSON read  [suspected]

These are tracked under #312 (Firebird live CI) + the DB behavioral-parity batch.
Why we keep missing them: no-mock tests for those engines SKIP in CI (no service
provisioned), and RequireServicesGate excludes Firebird by design in PHP + Node.
A test that never runs is an invisible hole. Fix that generalizes: wire live CI
for the uncovered engines across all 4 and drop the Firebird exclusion.

## Close-out action
No GitHub issue existed to comment on or close (drafts never posted). Recorded
here + in memory so the false feature-gap list is retired and never re-filed.

## Status: CLOSED (false positive). Real work continues under #312 + DB behavioral batch.
