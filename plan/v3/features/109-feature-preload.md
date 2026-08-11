# Feature 109: Lazy feature loading and preload manifest

## Identity and status

- Matrix identity: 109 - Lazy feature loading and preload manifest (load only what an app uses; keep dev
  tooling out of production)
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11. The lazy-loading half shipped on v3
  (2026-07-24, task #345); the manifest half is a design (`plan/v3/feature-preload-manifest.md`) with a
  partial Python read-hook. Verified the shipped mechanisms: Python `__init__.py:95/157/170`
  (`_LAZY` + PEP 562 `__getattr__` + `__dir__`), Ruby `lib/tina4.rb` (60 `autoload`s), Node
  `packages/core/package.json` exports map + 13 dynamic `await import()` in `server.ts`, PHP `App.php`
  boot-wiring gates (`DevAdmin::register`/`Swagger::register` behind enable checks).
- Dependencies: every optional subsystem (ORM, GraphQL, WSDL, Queue, Cache, Session, Messenger, MQTT,
  DocStore, Swagger, WebSocket, ...) and the dev tooling (DevAdmin, MCP, error overlay).
- Dependants: production boot time and memory footprint; the "dev tooling never in production" guarantee.
- Existing ADRs: none dedicated; the owner decision is recorded in the task-#345 landing (see below).
- Shared fixtures: NONE. A cross-language "loaded-modules" lock-in is owed (an app using only {orm,
  graphql} must NOT load {wsdl, mqtt, messenger, devadmin, mcp} in production).

- Catalog phase: Developer internals

## Why this feature exists

Tina4 ships around 98 features. Loading all of them at import/require time makes a production app that
uses six of them pay the memory and boot cost of all 98 - and, worse, loads the dev dashboard and MCP
server in production. This feature makes the runtime footprint match the app: load core always, load an
optional subsystem only when it is referenced, and never load dev tooling in production.

It is two halves. The lazy-loading half (shipped) makes each optional subsystem load on first use through
the language's own idiom. The manifest half (designed) adds a generated `.tina4/preload.json` so a
production deploy eager-loads exactly the listed features - and only the one selected backend per
pluggable subsystem - with a first-run dependency check.

## Boundary

This packet owns the load STRATEGY: which subsystems load eagerly vs on demand, the dev-vs-production
gate, and (designed) the preload manifest plus its discovery pass and `tina4 preload` CLI command.

It does NOT own the subsystems themselves (each is its own feature); it owns only WHEN they load. It does
not change any subsystem's public API - a lazily-loaded ORM behaves identically to an eager one; only the
import timing differs.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Lazy mechanism | PEP 562 module `__getattr__` + `_LAZY` map | PSR-4 (already per-class lazy) + boot-wiring gates | `Module#autoload` (already used for DB drivers) | `exports` map + dynamic `import()`; some eager (spec limit) |
| Where | `tina4_python/__init__.py:95,157,170` | `Tina4/App.php` (register gates) | `lib/tina4.rb` (60 autoloads) | `packages/core/package.json`, `server.ts` |
| Measured payoff (task #345) | 79.0 -> 40.9ms import, 48 -> 17 modules | test-only (nothing defended it before) | -22.5ms, -29 files per boot | documented + pinned (ESM eager exception) |
| Dev tooling gated out of prod | yes | yes (register gates) | yes | yes |
| Manifest (`.tina4/preload.json`) | partial read-hook | not built | not built | not built |
| Cross-language loaded-modules lock-in | owed | owed | owed | owed |

## Public surface contract

There is little public API; the contract is behavioural. The uniform concept across all four: (1) a small
always-loaded CORE (router, request, response, server, env/config, log, events, container); (2) DEV-ONLY
subsystems (DevAdmin, MCP, error overlay, gallery, docs_search) that load only when `TINA4_DEBUG` is
truthy / not `--production`; (3) OPTIONAL subsystems that load on first reference. A referenced optional
subsystem resolves transparently - the caller cannot tell it was lazy.

The mechanism is deliberately NOT uniform (see the owner decision): each language uses its own idiom.
Python exposes lazy attributes through `__getattr__` and reports them in `__dir__`; Ruby uses `autoload`;
Node uses the package exports map plus dynamic `import()`; PHP relies on PSR-4 for classes and gates the
boot-time WIRING of optional/dev subsystems.

## Inputs and outputs

- Input: which subsystems the app references (implicitly, by importing/using them) plus the dev/production
  mode.
- Output: only those subsystems (plus core) are loaded; dev tooling is absent in production.
- The designed manifest adds an explicit input (`.tina4/preload.json` listing features + the one backend
  per pluggable subsystem) and an output (a dependency-check result: each used feature's driver/extension
  is installed, else a fail with an actionable message).

## Lifecycle and operation graph

Shipped (lazy):
1. Import/require the framework: only core loads eagerly.
2. First reference to an optional subsystem triggers its load (Python `__getattr__`, Ruby `autoload`
   constant resolution, Node dynamic `import()`, PHP PSR-4 class autoload).
3. Boot wires dev tooling only when not in production.

Designed (manifest):
1. `tina4 preload` (or the first `tina4 serve --production` with no manifest) static-scans
   `src/{routes,orm,services,app}` for subsystem references, reads `.env` for backend selections, checks
   each used driver/extension is installed, and writes `.tina4/preload.json`.
2. Production boot reads the manifest and eager-loads exactly the listed features + core (no first-request
   latency), only the one selected backend per subsystem, and no dev tooling.
3. The manifest auto-invalidates when the `src` hash changes.

## Configuration and precedence

- `TINA4_DEBUG` / `--production` gate the dev tooling (dev loads everything on demand and ignores any
  manifest).
- The designed manifest reads backend selections from `.env` (`TINA4_CACHE_BACKEND`,
  `TINA4_SESSION_BACKEND`, `TINA4_QUEUE_BACKEND`, `TINA4_DATABASE_URL` scheme) so only the chosen driver
  loads.
- No other configuration for the shipped lazy half.

## Failures, side effects and security

- PL-01 (the shipped PHP lesson): PHP early-binds unconditional top-level functions and interfaces at
  COMPILE time. So a file that declares free functions (in composer's eager `autoload.files`) and also
  sits at the PSR-4 path for a same-named class it does NOT declare gets a SECOND plain include when that
  class is referenced (e.g. by `class_exists('Tina4\MCP')` feature-detection), and the re-declaration is
  a fatal that fires during compile - a runtime `if (function_exists(...)) return;` guard cannot stop it.
  Four of five `autoload.files` entries were affected. The fix was structural (a file cannot defend
  itself here); this is a permanent footgun for anyone adding a free-function file. Documented, not
  guardable at runtime.
- PL-02 (the shipped Node exception): ESM re-exports are eager by spec, so a barrel that re-exports a
  subsystem loads it; `orm`/`swagger` are not fully lean in Node. This was recorded and pinned rather
  than papered over, and Node uses dynamic `import()` where it can.
- No security surface change from lazy loading itself. The security-relevant part is the dev-tooling gate:
  DevAdmin/MCP must not load in production - which ties to the MCP-02 and API-01 findings (a dev surface
  reachable in production is the threat those address).
- A lazily-loaded subsystem that fails to import surfaces the import error on first use rather than at
  boot - a deferred failure mode. The designed manifest's dependency check moves that failure back to
  deploy time (fail fast with an actionable message).

## Wire and persistence contract

The shipped lazy half has no persisted artifact. The designed manifest persists `.tina4/preload.json`
(committable for reproducible deploys) carrying `tina4_version`, `generated_at`, `src_hash`, `features`,
`backends` (the one driver per subsystem), and `dependencies_ok`. The format is intended to be identical
across all four frameworks.

## Providers and substitutability

The substitution axis is the loading mechanism, and it is INTENTIONALLY language-idiomatic (PEP 562 /
autoload / exports+import / PSR-4). There is no shared implementation and none is wanted; the shared
thing is the behaviour (lean production boot) and, once built, the manifest format. No dependency is
added.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| PL-MANIFEST | The preload manifest (`.tina4/preload.json` + `tina4 preload` CLI + discovery + dependency check + manifest-driven production boot) is DESIGNED but not built. Python has a partial read-hook; there is no `tina4 preload` CLI command, no discovery pass, and no cross-language parity. | OWNER DECISION (go/no-go on the design). If go: implement Python-master-first per the design doc, mirror to the other three, add the `tina4 preload` Rust CLI command, and the loaded-modules lock-in test per framework. If defer: record it as a post-3.14 item and keep the shipped lazy half. |
| PL-01 | PHP compile-time early-binding footgun (above): a new free-function file at a class's PSR-4 path re-declares fatally on class reference, un-guardable at runtime. | Documented lesson; keep the structural arrangement. Add a maintainer note (a free-function file must not share a PSR-4 class path) and a test that references each `autoload.files` class name to catch a regression. |
| PL-02 | Node ESM eager re-export: `orm`/`swagger` are not fully lean because ESM barrels load on import. | Accept the spec-level exception (recorded and pinned). Where a subsystem is genuinely optional, move it behind dynamic `import()` (as swagger partly is); otherwise document that Node's floor is higher than the other three. |
| PL-LOCKIN | No cross-language loaded-modules lock-in exists. Nothing proves that a production app using only {orm, graphql} does NOT load {wsdl, mqtt, messenger, devadmin, mcp}. | Add the lock-in per framework asserting the not-loaded set via loaded-modules introspection (`sys.modules` / `$LOADED_FEATURES` / `get_declared_classes` / `require.cache`), and lift it into the shared fixture once the manifest lands. |

## Owner decisions

- PL-DEC-01 (already made, recorded here): behavioural parity via each language's own idiom, with Node's
  ESM-eager exception recorded rather than papered over. The lazy half shipped on this basis (task #345).
- PL-DEC-02 (proposed): go/no-go on building the preload manifest + `tina4 preload` for 3.14, or defer it
  post-3.14.

## Proposed conformance fixture

A loaded-modules lock-in per language (no mocks; a real minimal app booted in production mode):

- Build a fixture app that references only {orm, graphql}.
- Boot it in production mode (dev tooling off).
- Assert via loaded-modules introspection that orm and graphql ARE loaded and that wsdl, mqtt, messenger,
  devadmin, and mcp are NOT.
- Assert the dev tooling (DevAdmin, MCP) is absent in production and present in dev.
- (Manifest, once built) Assert that with a `.tina4/preload.json` listing {orm, session:file} only those
  plus core load, and that a missing driver fails discovery with an actionable message.

## Integration map

- Framework boot: reads the dev/production mode to gate dev tooling; (designed) reads `.tina4/preload.json`
  in production.
- CLI: (designed) `tina4 preload` runs discovery + dependency check + writes the manifest; `tina4 serve
  --production` runs discovery on first run.
- Every optional subsystem and the dev tooling are the loaded/not-loaded targets.
- Documentation: the design lives in `plan/v3/feature-preload-manifest.md`; the shipped lazy mechanisms
  are noted in each framework's CLAUDE.md loading section.

## Breaking changes and migration

- The shipped lazy half is behaviour-preserving: a referenced subsystem loads exactly as before, only
  later. No public API change.
- The designed manifest is additive: without a manifest, production boots lazy (plus a warn); with one, it
  boots lean. Committing `.tina4/preload.json` makes a deploy reproducible.
- PL-01's structural fix already shipped; the only migration is the maintainer rule for new
  free-function files.

## Implementation backlog

Dependency-ordered:

1. Add the loaded-modules lock-in per framework (PL-LOCKIN) to pin the shipped lazy behaviour.
2. Settle PL-DEC-02 (manifest go/no-go). If go: build the manifest read/write + discovery + dependency
   check Python-first, mirror to PHP/Ruby/Node, and add the `tina4 preload` Rust CLI command.
3. Add the PHP `autoload.files` class-reference regression (PL-01) and the maintainer note.
4. Author the shared loaded-modules fixture once the manifest format is real; add the CONTRACT-MAP row.

## Porting capsule

A clean-room implementation needs: a three-tier split (core always; dev-only gated on debug/production;
optional on-demand); the language's idiomatic deferral (module `__getattr__` / `autoload` / dynamic
`import()` / PSR-4) so an optional subsystem loads transparently on first reference; boot-time gates so
dev tooling never loads in production; and (per the design) a `.tina4/preload.json` reader that
eager-loads exactly the listed features + the one selected backend per subsystem, with a discovery pass
and dependency check that fails fast on a missing driver. The behaviour (lean production boot, dev tooling
absent) is the contract; the mechanism is idiomatic. This packet is sufficient for a clean-room
implementation of the shipped lazy half; the manifest half awaits PL-DEC-02.

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
