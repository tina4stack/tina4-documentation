# Task: nodejs#32/#353 — exports map points at .ts source, unimportable under plain node

## Goal
Make `import "tina4-nodejs"` and `import "tina4-nodejs/orm"` (and `/swagger`, `/frond`)
work from an installed consumer app under PLAIN node (no tsx). Node-only (npm
packaging); no cross-framework parity (PHP/Ruby/Python have no exports map).

## Root cause (verified)
Root `package.json` `exports` map points every subpath at `.ts` SOURCE:
  ".": "./packages/core/src/index.ts", "./orm": ".../orm/src/index.ts", ...
`exports` wins over `main`, so a consumer resolves a `.ts` file plain node cannot run
-> ERR_UNKNOWN_FILE_EXTENSION / parse error. Reported on 3.13.70, live on 3.13.85.

## Verified facts (this session)
- Each workspace already builds to `packages/<pkg>/dist/index.js` via esbuild
  (`--bundle --platform=node --format=esm --packages=external`), and the bundle is
  SELF-CONTAINED: all four `dist/index.js` import cleanly under plain node
  (core 253 exports, orm 97, swagger 6, frond 1). The relative cross-package dynamic
  imports (`import("../../orm/src/index.js")` in mcp/response/cache/devAdmin) are
  bundled INLINE by esbuild, so there are no dangling cross-package specifiers.
- `dist/*.d.ts` is NEVER emitted (build is esbuild-only; `prepublishOnly` = `npm run
  build` = esbuild). So the pre-existing `types` pointing at `dist/index.d.ts` would
  have been dangling; root `types` actually points at `src/index.ts` (a real file).
- `files[]` already ships both `packages/*/dist/**` and `packages/*/src/**`.

## Fix (minimal, correct)
Conditional exports: `types` -> `.ts` source (TS tooling reads .ts directly, same as
today), runtime `import`/`default` -> built `dist/*.js`. No esbuild/tsc change.
  ".":         { types: core/src/index.ts,    import+default: core/dist/index.js }
  "./orm":     { types: orm/src/index.ts,      import+default: orm/dist/index.js }
  "./swagger": { types: swagger/src/index.ts,  import+default: swagger/dist/index.js }
  "./frond":   { types: frond/src/engine.ts,   import+default: frond/dist/index.js }
(frond runtime = dist/index.js, the built barrel re-exporting Frond from engine.)

## Verification (no-mock)
- [ ] `npm run build` (all workspaces) -> dist present
- [ ] `npm pack` -> install the tarball into a CLEAN temp app -> `node` (plain, no tsx)
      `import("tina4-nodejs")`, `/orm`, `/swagger`, `/frond` all load. THE real
      consumer repro from the issue.
- [ ] Lock-in test in the repo suite: import each built dist under plain node and
      assert key exports (BaseModel from /orm, etc.). Fails against a .ts-pointing map.
- [ ] `npm run typecheck` green; relevant suite green.

## FINDING (2026-07-25): fix is correct for consumers, but NOT committable as a one-liner
The exports->dist repoint is directionally correct and PROVEN for real consumers:
- npm pack -> install into a clean app -> `import "tina4-nodejs"[/orm|/swagger|/frond]`
  under PLAIN node all load with the right exports (manual end-to-end test).
- A real consumer using ONE dist instance (initDatabase + model + save + read from
  `tina4-nodejs/orm`) works: adapter shared. The core<->orm split is bridged because
  initDatabase publishes `globalThis.__tina4_db` (which core reads) AND binds its own
  orm-instance module adapter (which that instance's models read).

BUT it breaks `test/cli.test.ts` scaffolding-matrix (100/0 -> 42/1, then 98/2 after
aligning initDatabase). Root cause: the matrix runs an ARTIFICIAL monorepo env that
mixes SRC framework internals (Router/Events/`_resetRouteDiscovery`/discoverRoutes
imported via `../packages/*/src`) with the scaffolded consumer code that resolves the
PUBLIC package specifier (-> dist). Pre-fix, exports->src matched the internals (one
instance); dist creates a src/dist SPLIT of three module-level singletons:
  1. orm adapter  -> fixed by importing initDatabase from `tina4-nodejs/orm` (dist).
  2. core Router   \ NOT globalThis-bridged; scaffolded routes register on dist-core,
  3. core Events   / the test inspects src-core -> "not registered on the REAL bus".
Fully reconciling needs EITHER exposing internal test hooks (`_resetRouteDiscovery`)
through the public exports (a smell) OR forcing the in-repo scaffold to resolve to SRC
at runtime (a custom loader/resolve hook). Both are real work, not a safe quick edit.

`packInstall.test` also silently depends on the current state: it packs+installs and
runs its consumer UNDER tsx, which resolves the `.ts` exports fine, so it passed even
with the broken map AND needs no built dist in CI. exports->dist would require dist in
the tarball -> a build-before-pack (CI test.yml has no build; `prepare` covers
`npm install` but not a stale-source `npm test`).

## RECOMMENDATION (owner decision)
Ship exports->dist together with, in ONE change:
- `pretest: npm run build` (fresh dist for every `npm test`; CI already builds via
  `prepare` on `npm install`).
- Reconcile cli.test: make the scaffolding-matrix resolve consistently. Cleanest is a
  runtime resolve hook mapping `tina4-nodejs`(+/orm) -> src for the in-repo scaffold, so
  the whole test env is single-instance src (matches the author's original intent and
  needs no public-API leakage). Alternative: route ALL the test's framework symbols
  through the package specifier (dist) and re-export the few internal hooks it uses.
- Add the packageExports lock-in test (contract: runtime condition is dist .js, not .ts;
  + built dist loads under plain node). Draft written + verified this session (20/0 on
  the fix, 4/4 FAIL on the old .ts map), then reverted with the rest.
- Node changelog entry (documentation + book), drafted + verified this session, reverted.

## SHIPPED (owner said "a" = do the full coordinated fix). Committed on v3/main, NOT pushed:
- tina4-nodejs 0d8d56c (v3): exports map -> conditional (types->src, import/default->dist)
  + `pretest: npm run build` + `test/packageExports.test.ts` lock-in + cli.test made
  fully dist-consistent.
- tina4-documentation a77e9bd + tina4-book a793e88 (main): Unreleased changelog entry.

### How cli.test was reconciled (the hard part)
The scaffolding-matrix places its temp project INSIDE the repo, so Node SELF-RESOLVES
`tina4-nodejs`[/orm] via the repo package `exports` (-> dist). A node_modules shim in
the temp dir does NOT win (self-reference precedes node_modules). So the test was made
to resolve its OWN framework symbols through the SAME published specifier (dist):
`Router/TestClient/getToken/discoverRoutes/Events/ServiceRunner` from `tina4-nodejs`,
`initDatabase/FakeData` from `tina4-nodejs/orm`, and `defaultRouter` from `tina4-nodejs`
(the ws-registration check). All are already public. The one src-internal,
`_resetRouteDiscovery()`, was DROPPED (not exposed publicly): run-all spawns each test
file in its own process, so the discovery cache is empty at the single scan. Result:
ONE dist instance drives the whole matrix -> DB adapter + Router + Events all shared.

### Verification (no-mock)
- Full `npm test` (pretest builds dist): 5731 passed / 0 failed across 181 files +
  vitest 44/44. `npm run typecheck` green. `pnpm docs:build` green; audit-truth green.
- packageExports.test: 20/0 on the fix, 4/4 FAIL against the old .ts map (regression
  guard proven). Manual end-to-end (npm pack -> clean install -> plain-node import of
  all 4 subpaths) proven earlier this session.

## Status: DONE (committed v3/main, not pushed). Ships in the next release (owner-gated
## version + push). #32 stays OPEN on GitHub until released (no "fixed" comment posted yet).
