# Feature 122: CLI command discovery and help (commands --json)

## Identity and status

- Matrix identity: 122 - the `commands --json` self-describing protocol + `tina4 --help` rendering
- Audit state: decision-ready
- Audit note: a TWO-SIDED feature: a Rust consumer (`tina4/src/manifest.rs`) and a per-framework producer
  (`<framework-cli> commands --json`). This is the mechanism that lets the one Rust binary discover and
  render each framework's real command set without hardcoding it. Measured 2026-08-11 from
  `tina4/src/manifest.rs` and the four framework CLIs (Python `cli/__init__.py` command registry, PHP/
  Ruby/Node equivalents). The protocol JSON is documented as "Identical across Python, PHP, Ruby, and
  Node" (`manifest.rs:37`).
- Dependencies: `detect::detect_language`, each framework CLI's `commands` command.
- Dependants: `tina4 --help` (renders the discovered commands), the whole delegation model.

- Catalog phase: CLI (protocol: Rust consumer + framework producer)

## Why this feature exists

The Rust CLI cannot hardcode every framework's command set - each framework adds its own generators,
subcommands, and flags, and they evolve independently. So each framework CLI SELF-DESCRIBES: `<cli>
commands --json` emits a manifest of its commands (name, summary, subcommands, usage), and the Rust CLI
reads it to render `tina4 --help` accurately. Crucially, forwarding is BLIND: even if the manifest is
missing or stale, `tina4 <cmd>` still forwards to the framework, which rejects an unknown - so a manifest
miss can never break a real command (`manifest.rs:9`).

## Boundary

This packet owns the protocol (the JSON shape), the Rust consumer (fetch + cache + render), and the
per-framework `commands` producer's contract. It does NOT own the individual commands it describes (each
is its own feature) - it owns how they are DISCOVERED and DISPLAYED.

## Existing implementation evidence

- Consumer: `manifest.rs` spawns `<framework-cli> commands --json` (`manifest.rs:95`), parses the manifest
  (`manifest.rs:37`), caches it at `.tina4/commands.json` (gitignored, keyed by a hash, `manifest.rs:12,
  64`), and renders it in `tina4 --help`. On a parse miss it degrades (blind forward).
- Producer: each framework CLI exposes `commands` emitting the JSON. Python's registry (the `_COMMANDS`/
  generators dict at `cli/__init__.py:3242-3269`) is the source that Python's `commands --json` serializes;
  PHP/Ruby/Node have their equivalents. The example manifest in the tests (`manifest.rs:272`) shows the
  shape: `{"framework":"php","version":"3.0.0","commands":[{"name":"generate","summary":"Scaffold",
  "subcommands":["model","crud"]}, ...]}`.

## Public surface contract

Producer: `<framework-cli> commands --json` -> `{framework, version, commands: [{name, summary, usage?,
subcommands?}]}`. Consumer: `tina4 --help` renders the framework name, version, and the discovered
commands; `tina4 <cmd>` forwards (blind if not in the manifest). The JSON shape is intended to be
byte-compatible across the four (COMMANDS-PARITY).

## Inputs and outputs

- Input: the detected framework CLI. Output: the parsed manifest (cached), and the rendered `--help`.
- The cache key is a hash (of the CLI version/path) so a framework upgrade invalidates it.

## Lifecycle and operation graph

1. `tina4 --help` -> detect language -> read `.tina4/commands.json` (cache) or spawn `<cli> commands
   --json` and cache it.
2. Render the discovered commands.
3. `tina4 <cmd>` for a non-clap command -> forward to `<cli> <cmd>` regardless of the manifest (blind).

The blind forward is the robustness guarantee: the manifest is a DISPLAY aid, never a gate.

## Configuration and precedence

- The cache lives at `.tina4/commands.json` (gitignored). No env configuration.

## Failures, side effects and security

- A manifest fetch/parse failure degrades to a blind forward (no command breaks) and a generic help - the
  correct fail-open for a discovery aid.
- Spawning `<cli> commands --json` runs the framework CLI (a side effect: it boots the framework's CLI
  layer). Confirm `commands` is cheap (no full app boot) so `--help` is fast.
- No security surface (it lists the developer's own commands).

## Wire and persistence contract

The manifest JSON shape is the contract: `{framework, version, commands:[{name, summary, usage?,
subcommands?}]}`. It is cached at `.tina4/commands.json`, keyed by a hash. The shape must be identical
across the four (COMMANDS-PARITY) or `tina4 --help` renders unevenly.

## Providers and substitutability

The provider is the detected framework CLI's `commands` command. The protocol is the substitution seam:
any framework that emits the manifest shape is discoverable.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| COMMANDS-PARITY | The manifest shape and the command SET it lists should be identical across the four framework CLIs so `tina4 --help` renders the same commands everywhere. Given the per-command parity gaps found (migrate subcommands, generator set, queue subcommands), the manifests almost certainly differ. | Fix the underlying per-command parity (features 112/118/120), which makes the manifests converge. Add a fixture that diffs the four `commands --json` outputs for the shared command set. |
| COMMANDS-COST | Confirm `<cli> commands --json` is cheap (does not boot the full app), so `tina4 --help` stays fast; the cache mitigates repeat calls but the first call must be quick. | Verify; if a framework's `commands` boots the app, make it a pure registry dump. |
| COMMANDS-CACHE | The cache key is a hash; confirm it invalidates on a framework upgrade (version change) so `--help` never shows stale commands after `uv add`/`composer update`. | Verify the key includes the framework version; add a test. |

## Owner decisions

- COMMANDS-DEC-01 (proposed): converge the four `commands --json` manifests (via the per-command parity
  fixes) and add a manifest-diff fixture.

## Proposed conformance fixture

A protocol fixture: for a scaffolded project per language, run `<framework-cli> commands --json`, assert
it parses to `{framework, version, commands:[...]}`, assert the shared command set (migrate/seed/test/
routes/queue/generate/console/build/metrics) is present with the same names, and assert the cache
invalidates on a version bump. The per-command SUBCOMMAND parity is covered by those commands' fixtures.

## Integration map

- Consumer: `manifest.rs` -> `tina4 --help`.
- Producer: each framework CLI's `commands` command (serializes its registry).
- Enables: the whole delegation model (112-120) and blind forward.

## Breaking changes and migration

- Converging the manifests changes what `tina4 --help` lists on some frameworks (adding missing commands)
  - additive.

## Implementation backlog

1. Add a `commands --json` manifest-diff fixture across the four.
2. Verify `commands` is a cheap registry dump (COMMANDS-COST) and the cache invalidates on version
   (COMMANDS-CACHE).
3. Converge the manifests via the per-command parity fixes (112/118/120).

## Porting capsule

The Rust consumer needs: spawn `<cli> commands --json`, parse `{framework, version, commands:[{name,
summary, usage?, subcommands?}]}`, cache at `.tina4/commands.json` keyed by a version hash, render in
`--help`, and always forward blind so a manifest miss never breaks a command. Each framework CLI needs a
`commands` command that emits that exact shape from a pure command registry (no app boot).

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Protocol parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
