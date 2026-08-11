# Feature 130: Dynamic framework version

## Identity and status

- Matrix identity: 130 - Dynamic framework version (`tina4_python/__init__.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, wide quality spread. Measured 2026-08-11 from shipped source by four
  parallel readers (batched with 128 and 129). Python `tina4_python/__init__.py` (`feature/csrf-fail-closed`
  HEAD `ebbab30`, pyproject `3.13.97`); PHP `Tina4/App.php` + `bin/tina4php` + `Tina4/Bootstrap/MCP.php`
  (`feature/mcp-call-gate` HEAD `6faabac5`); Ruby `lib/tina4/version.rb` + `tina4ruby.gemspec`
  (`feature/mcp-call-gate` HEAD `6d5b1de`); Node `packages/core/src/server.ts` + `devAdmin.ts` + the CLI
  (`feature/mcp-call-gate` HEAD `27cf0f4`). All report `3.13.97` in a clean monorepo/checkout.
- Dependencies: the package manifest (pyproject / composer.json / gemspec / package.json) and/or a version
  literal, plus `importlib.metadata` (Python) and `lsof`-free file reads.
- Dependants: the health endpoint, the boot banner, the dev dashboard, the update-check, the MCP server
  info, the CLI `--version`/manifest, the error overlay, and the docs generator.
- Existing ADRs: none dedicated.

- Catalog phase: developer experience (release plumbing)

## Why this feature exists

Every surface that reports "what version am I" - the health JSON, the banner, the dashboard, the MCP
handshake, the CLI - should report the SAME version, and that version should match the package a user
installed. The feature is the resolver that answers "what version am I", and its whole job is to have ONE
answer.

## Boundary

This packet owns the version resolver and the surfaces that report the FRAMEWORK version. It does NOT own
the user application's version (a different value the MCP `system_info` tool reports) or the MCP protocol
version.

## Existing implementation evidence

Ranked cleanest to messiest - the four diverge sharply on how many sources of truth exist:

| Backend | Source of truth | Resolver | Drift risk |
| --- | --- | --- | --- |
| Ruby | `Tina4::VERSION` const (`version.rb:4`) | gemspec `require`s the const + `spec.version = Tina4::VERSION` | NONE - runtime and gem cannot diverge |
| Python | `pyproject.toml [project].version` | `_resolve_version()`: pyproject -> `importlib.metadata` -> floor literal; all surfaces import the one `__version__` | LOW - one derived value; floor literal locked to pyproject by a test |
| Node | `package.json` | FOUR independent readers (`server.ts` fixed-depth-3, `devAdmin.ts` two-path, CLI walk-up, MCP reads the user project) | LATENT - `server.ts`'s fixed-depth reader can return `"0.0.0"` in a relocated/published layout while other surfaces read the real version |
| PHP | claimed `App::$VERSION`; actually THREE sources | `App::$VERSION` literal; CLI `tina4FrameworkVersion()` reads composer/installed.json; MCP `serverInfo` default `"1.0.0"` | ACTIVE - in a git checkout: CLI `0.0.0`, MCP `serverInfo` `1.0.0`, app `3.13.97` |

- Ruby and Python are the reference: one source, every surface derives from it, and a REAL test locks the
  derived value to the manifest (Ruby loads the actual gemspec and asserts `spec.version == Tina4::VERSION`;
  Python asserts `__version__ == pyproject` and that the floor literal tracks pyproject).
- Node reads `package.json` everywhere (consistent in the monorepo), but through four different readers with
  three fallback sentinels; `server.ts`'s `readPackageVersion()` is a fixed `../../../package.json` with no
  fallback, so a published layout where that path misses silently yields `"0.0.0"` on the banner/health
  while the dashboard/CLI still read the real version.
- PHP is the outlier: `App::$VERSION` is a hardcoded `3.13.97` for the app surfaces, but the CLI
  `commands --json`/`--version` reads composer metadata (`0.0.0` in a checkout with no `version` key and no
  self-entry in `installed.json`), and the MCP `serverInfo` reports the constructor default `1.0.0`. A stale
  docblock (`bin/tina4php:561`) claims the CLI "mirrors `App::resolveVersion()`" - a method that no longer
  exists.

## Public surface contract

The framework version reported by health, the banner, the dashboard, the MCP `serverInfo`, and the CLI
`--version`/manifest. Contract (as it SHOULD be, met by Ruby/Python): all surfaces report one value equal to
the published package version.

## Inputs and outputs

- Input: the package manifest and/or a version literal (and `importlib.metadata` in Python). Output: a
  version string, consumed by every "what version am I" surface.

## Lifecycle and operation graph

1. At import/boot, resolve the version (read the manifest / const).
2. Every surface reads that resolved value. (In PHP and Node, several surfaces resolve independently -
   that is the defect.)

## Configuration and precedence

- No env configuration. The precedence is internal to each resolver (Python: pyproject > metadata > floor;
  Node `server.ts`: fixed path only; PHP: three separate sources).

## Failures, side effects and security

- No security surface. The failure mode is version DRIFT - a surface reporting a version that differs from
  the package or from its siblings. PHP exhibits real drift in a checkout (three values); Node has a latent
  split in a relocated layout. Ruby/Python cannot drift between surfaces.
- None of the four stamp a version into an HTTP `User-Agent` on the framework's own HTTP client (verified
  absent) - a minor, optional gap.

## Wire and persistence contract

No persisted state. The "wire" is the version string in the health JSON, the MCP `serverInfo`, and the CLI
manifest. The contract those consumers rely on is that the string is correct and consistent.

## Providers and substitutability

No provider abstraction. The manifest format is the only substitution axis (pyproject / composer / gemspec /
package.json).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| VERSION-MULTI-SOURCE | PHP has THREE version sources that DRIFT: `App::$VERSION` = `3.13.97` (app surfaces), the CLI `tina4FrameworkVersion()` = `0.0.0` in a git checkout (composer.json has no `version`, `installed.json` has no self-entry), and MCP `serverInfo` = `1.0.0` (constructor default). A stale docblock (`bin/tina4php:561`) claims the CLI mirrors a deleted `App::resolveVersion()`. Node has a LATENT version of the same problem: four independent `package.json` readers, one of which (`server.ts`, fixed depth-3, no fallback) can return `"0.0.0"` in a published layout while the dashboard/CLI read the real version. | Adopt the Ruby/Python model: ONE resolver, and every surface (health, banner, dashboard, MCP `serverInfo`, CLI) reads it. In PHP, feed the CLI manifest and the MCP `serverInfo` from `App::$VERSION`; delete the stale docblock and the reference to the removed method. In Node, give `server.ts` the same fallback/walk-up the CLI and devAdmin readers have (or a single shared reader). |
| VERSION-DRIFT-TEST-GAP | The existing version tests only lock the literal/const against the DOCS (CLAUDE.md) or the manifest for ONE surface. Nothing asserts that the CLI, the MCP `serverInfo`, the app, and the published tag/package version all agree (PHP), nor that `server.ts`'s reader returns the real version from a non-monorepo layout (Node). So the drift above is not regression-locked. | Add a cross-source test: assert the app version == the CLI manifest version == the MCP `serverInfo` version == the published package/tag version, in PHP and Node. Ruby's gemspec-comparison test and Python's floor-tracks-pyproject test are the model. |
| VERSION-NO-UA | None of the four stamp the framework version into the HTTP client's `User-Agent` (verified absent in all four). | Optional/low: add a `Tina4/<version>` User-Agent to the HTTP client if outbound version visibility is wanted. Not required. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** Owner call: ADD a `Tina4/<version>` User-Agent to the outbound HTTP client in all four (VERSION-DEC-03 = yes). VERSION-DEC-01 (single-resolver convergence PHP+Node) and VERSION-DEC-02 (cross-source drift test) ride as fixes. See [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) (Batch 5). Next phase: implementation in all four with real (no-mock) tests.

- VERSION-DEC-01 (proposed): converge PHP and Node on a single-resolver model (the Ruby/Python pattern) so
  every surface reports one version (VERSION-MULTI-SOURCE); delete PHP's stale docblock + deleted-method
  reference.
- VERSION-DEC-02 (proposed): add the cross-source drift test in PHP and Node (VERSION-DRIFT-TEST-GAP).
- VERSION-DEC-03 (proposed, low): decide whether to add a version-stamped User-Agent (VERSION-NO-UA).

## Proposed conformance fixture

A per-language test (Ruby/Python already have the shape): assert the runtime framework version equals the
package manifest version (and, in a release, the git tag); assert every reporting surface (health, banner,
dashboard, MCP `serverInfo`, CLI manifest) returns that same value. In PHP, additionally assert the CLI
`tina4FrameworkVersion()` and the MCP `serverInfo` equal `App::$VERSION`. In Node, additionally assert
`server.ts readPackageVersion()` returns the real version from a relocated layout (not `"0.0.0"`).

## Integration map

- Resolver: `__init__.py _resolve_version` (Python) / `version.rb` const + gemspec (Ruby) / `App::$VERSION`
  (PHP) / the four `package.json` readers (Node).
- Consumers: health, banner, dashboard, update-check, MCP `serverInfo` + `system_info`, CLI `--version` /
  `commands --json`, error overlay, docs generator, AI skills ref.

## Breaking changes and migration

- Converging PHP/Node on one resolver changes the value some surfaces report (e.g. the PHP CLI would report
  `3.13.97` instead of `0.0.0` in a checkout). That is a correctness fix; document it. No user-facing
  migration.

## Implementation backlog

1. VERSION-DEC-01: single-resolver convergence in PHP (feed CLI + MCP `serverInfo` from `App::$VERSION`;
   delete the stale docblock) and Node (`server.ts` gets a fallback/walk-up or a shared reader).
2. VERSION-DEC-02: the cross-source drift test in PHP and Node.
3. VERSION-DEC-03: decide the User-Agent question.

## Porting capsule

A clean-room reimplementation needs ONE source of truth for the framework version and one resolver that
every surface reads - the Ruby model (a const the package manifest also consumes) or the Python model (the
manifest is the truth, a resolver derives it with a manifest -> installed-metadata -> floor fallback). Never
let the CLI, the MCP handshake, and the app resolve the version independently (the PHP trap: `0.0.0` /
`1.0.0` / `3.13.97` at once). Lock it with a test that compares the runtime version to the actual package
manifest AND across every reporting surface. Keep no stale docblocks referencing removed resolvers.

## Audit closure checklist

- [x] Boundary and public surface complete (the resolver + the reporting surfaces x four).
- [x] Lifecycle and every producer/consumer edge complete (resolve at boot; every surface reads it).
- [x] Configuration, failure (drift), side-effect and security rules complete.
- [x] Wire/storage (version in health/MCP/CLI) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (Ruby/Python clean, Node latent split, PHP three-way
  drift).
- [x] Owner ambiguities decided and recorded (VERSION-DEC-01..03 proposed).
- [x] Proposed conformance fixture (cross-source + manifest equality) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
