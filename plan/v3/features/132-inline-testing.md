# Feature 132: Inline testing API

## Identity and status

- Matrix identity: 132 - Inline testing API (`tina4_python/Testing.py`; `tina4_python/test/__init__.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature with a UNIVERSAL wiring defect. Measured 2026-08-11 from shipped source
  by four parallel readers (batched with 131). Python `Testing.py` (189) + `test/__init__.py` (432)
  (`feature/csrf-fail-closed` HEAD `ebbab30`); PHP `Tina4/Testing.php` (184) (`feature/mcp-call-gate` HEAD
  `6faabac5`); Ruby `lib/tina4/testing.rb` + `lib/tina4/test.rb` (`feature/mcp-call-gate` HEAD `6d5b1de`);
  Node `packages/core/src/testing.ts` (234) + `test.ts` (247) (`feature/mcp-call-gate` HEAD `27cf0f4`).
- Dependencies: the assertion primitives, the discovery mechanism, and (for the xUnit surface) the
  TestClient (feature 131).
- Dependants: developers who want to write tests next to their code and run `tina4 test`.
- Existing ADRs: none dedicated.

- Catalog phase: developer experience (testing)

## Why this feature exists

Inline testing is a batteries-included promise: write a test beside the code it checks - a `@tests`
decorator on a function, or a small xUnit class - and run them all with `tina4 test`, no external framework
to configure. It lowers the cost of the first test to almost nothing. The promise only holds if `tina4 test`
actually finds and runs those tests - and that is exactly where all four break.

## Boundary

This packet owns the two inline surfaces (the decorator/functional API and the xUnit class) and their
runners. It does NOT own the TestClient (feature 131, which the xUnit surface uses for HTTP) or the external
test frameworks (pytest/PHPUnit) that `tina4 test` sometimes shells out to.

## Existing implementation evidence

Every language ships TWO surfaces plus a `tina4 test` CLI, and the CLI runs the inline runner in NONE of
them. Parity table:

| Axis | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Decorator/functional surface | `@tests` (`Testing.py`) | `@tests` docblock (`Testing.php`) | `tests()` + `describe/it` (`testing.rb`) | `tests()(fn)` (`testing.ts`) |
| xUnit class surface | `Test(unittest.TestCase)` | (PHPUnit) | `Tina4::Test` (`test.rb`) | `Tina4Test` (`test.ts`) |
| xUnit uses the TestClient (131) | YES | n/a | YES | YES |
| What `tina4 test` actually runs | `pytest tests/` | smoke or PHPUnit | `Testing.run_all` only | a file-runner (`tsx <file>`) |
| Inline runner reached by the CLI | NO | NO | partial (ignores xUnit) | NO |
| Exit code / TAP | pytest code / none | none | exit via CLI / none | file-throw exit / none |

- Python: the `@tests` decorator registers into a module-global registry run by `run_all()` - which the CLI
  never calls; `tina4python test` shells out to `pytest tests/`. The xUnit `Test(unittest.TestCase)` IS
  found by pytest (via unittest inheritance), so that surface works - but the CLAUDE.md claim
  `tina4python test # Discovers @tests in src/**/*.py` is FALSE (it scans `tests/`, not `src/`, and never
  touches the decorator registry).
- PHP: `Testing` (the `@tests` docblock API with `discover`/`runAll`) is WHOLLY ORPHANED - nothing in the
  runtime or CLI calls it; `tina4 test` runs the smoke suite or PHPUnit. Its `discover()` also
  `require_once`s every scanned file and `eval()`s the assertion args - safe for a trusted tree, unsafe on
  untrusted input.
- Ruby: `tina4ruby test` DOES run `Tina4::Testing.run_all` (the `describe/it` surface) with a real exit
  code - but it also `load`s `*_test.rb`, which is where a documented `class FooTest < Tina4::Test` lives;
  those subclasses register via `inherited` and are then NEVER RUN (the CLI calls only `Testing.run_all`, not
  `Test.run_all`). So a developer following the documented `Tina4::Test` pattern gets a GREEN run that
  silently ignores their tests.
- Node: `tina4 test` is a FILE runner (`execSync npx tsx <file>` for each file under `test/`), calling
  neither `testing.runAll()` nor `Tina4Test.runAll()`. Worse, `Tina4Test` AUTO-REGISTRATION IS A NO-OP - the
  static registration block is empty (`// Skip the base class itself`) and JS has no `inherited` hook, so
  `class FooTest extends Tina4Test {}` never registers and `Tina4Test.runAll()` finds nothing unless the app
  calls `Tina4Test.register(FooTest)` by hand. Yet the docstring claims "a built-in runner so
  `npx tina4nodejs test` can discover every subclass" and `register`'s doc says "Called automatically via
  extends Tina4Test" - both FALSE against the code.
- In all four, the two surfaces export the SAME assertion names with INCOMPATIBLE signatures (e.g. the
  builder `assert_equal(args_tuple, expected)` vs the xUnit `assert_equal(actual, expected, message)`), so
  importing from the wrong module silently changes call semantics.

## Public surface contract

Two surfaces per language: a decorator/functional API (`@tests`/`tests()` + `assert_equal`/`assert_raises`/
`assert_true`/`assert_false` builders + `run_all`/`reset`) and an xUnit class (`Test`/`Tina4Test` with
`test*` methods, positional assertions, `set_up`/`tear_down`, and HTTP via the TestClient). The intended
contract - `tina4 test` discovers and runs both - is NOT met.

## Inputs and outputs

- Input: functions annotated with `@tests`, or xUnit subclasses with `test*` methods. Output: a pass/fail/
  error tally printed with ANSI markers; a process exit code only where the CLI happens to provide one.

## Lifecycle and operation graph

1. Declare tests (decorator or subclass).
2. Discover them - intended via `tina4 test`, actually via pytest (Python), PHPUnit/smoke (PHP), only the
   `describe/it` surface (Ruby), or a file-runner (Node).
3. Run and report - the inline `run_all` is reached only when a discovered file calls it itself.

## Configuration and precedence

- No `TINA4_*` gate for either surface. Python/PHP/Ruby/Node each hardcode discovery directories or shell
  out to an external runner. The decorator registry is process-global (a source of order-coupling - see the
  register).

## Failures, side effects and security

- The failure mode is a FALSE GREEN: `tina4 test` can report success while running zero of a developer's
  inline or xUnit tests (Node and Ruby silently ignore xUnit subclasses; Python ignores the `@tests`
  registry; PHP ignores `Testing` entirely). PHP's `discover()` adds a real side effect: it executes
  arbitrary code from every file it scans (`require_once` + `eval`), so it must never be pointed at
  untrusted input.

## Wire and persistence contract

No persisted state (a process-global registry). No TAP output in any language; exit codes are incidental.

## Providers and substitutability

No provider abstraction. The xUnit surface substitutes its HTTP via the TestClient (feature 131).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| INLINE-ORPHANED-RUNNER | In all four, `tina4 test` does NOT run the inline framework's own runner over a discovered set. Python runs `pytest tests/` (the `@tests` `run_all` is never called; CLAUDE.md's "discovers @tests in src/" is false); PHP runs smoke/PHPUnit (`Testing` wholly orphaned); Ruby runs only `Testing.run_all` and silently ignores `Tina4::Test` subclasses; Node runs a file-runner and calls neither `runAll`. So the advertised inline-testing flow does not work, and a green `tina4 test` can execute zero inline/xUnit tests. | Decide ONE story per framework and wire it: either make `tina4 test` discover and run both surfaces (scan the documented dirs, register subclasses, call the inline runner with a real exit code and optional TAP), or drop the surface the CLI cannot run and fix the docs. Whatever is chosen, `tina4 test` must actually run what the docs say it runs. |
| INLINE-SILENT-IGNORE | Node's `Tina4Test` auto-registration is a NO-OP (empty static block; no `inherited` hook) while its docstring claims subclasses auto-register; Ruby registers `Tina4::Test` subclasses via `inherited` but the CLI never runs them. Both yield a GREEN run that ignores the developer's xUnit tests. The parity tests sidestep this (they call per-class `.run()`, never `runAll`/`register`), so a green suite does not prove discovery works. | Wire real auto-discovery (Node: an explicit `register` call in a documented base-class pattern, or a discovery scan; Ruby: have the CLI run `Test.run_all` too) and add a test that `tina4 test` on a project with ONE xUnit subclass actually runs it (asserts count >= 1, and fails if it is silently skipped). |
| INLINE-NAME-COLLISION | In all four, the decorator/functional surface and the xUnit surface export the SAME assertion names with INCOMPATIBLE signatures (`assert_equal(args, expected)` builder vs `assert_equal(actual, expected, message)` xUnit; `assert_raises(exc, args)` vs `assert_raises(callable, exc, message)`). Importing from the wrong module silently changes semantics with no error. | Rename one surface's builders (e.g. `expect_equal`/`equals` for the descriptor builders) or namespace them, so the two cannot be confused. Document the split clearly. |
| INLINE-NO-EXITCODE-TAP | The inline `run_all` returns a dict and prints ANSI but sets no process exit code and emits no TAP in any language, so it cannot gate CI on its own (only the surfaces that ride pytest/the CLI get an exit code). | Give `run_all` an exit-code path and optional TAP output so the inline runner is CI-gatable standalone. |
| INLINE-PHP-EVAL | PHP's `Testing::discover()` `require_once`s every `*.php` under the scanned path and `eval()`s the `@tests` argument expressions - arbitrary code execution from any scanned file. | Restrict discovery to an explicit tests directory and parse assertion args without `eval` (or accept only literal args), so scanning cannot execute untrusted code. |
| INLINE-GLOBAL-REGISTRY | The decorator registry is process-global; Python's `test_testing.py::test_inline_testing_framework` asserts `== 11 passed` by walking it WITHOUT clearing first, so any other module registering `@tests` would break the count - order-coupled global state. | Snapshot/restore or namespace the registry in tests; assert on a filtered subset rather than the global total. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** Owner call: wire ONE inline-testing surface (the decorator/`@tests` model) with a real exit code + discovery so `tina4 test` works end-to-end (INLINE-DEC-01); resolve the assertion name collision, REMOVE PHP's `eval`/blanket `require_once` (arbitrary code execution), and de-couple the global registry in tests (INLINE-DEC-02). See [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) (Batch 5). Next phase: implementation in all four with real (no-mock) tests.

- INLINE-DEC-01 (proposed): pick and wire ONE inline-testing story per framework so `tina4 test` actually
  discovers and runs the advertised tests with a real exit code (INLINE-ORPHANED-RUNNER +
  INLINE-SILENT-IGNORE + INLINE-NO-EXITCODE-TAP), and fix the CLAUDE.md/docstring claims to match. This is
  the headline decision - the feature is advertised but does not work end-to-end anywhere.
- INLINE-DEC-02 (proposed): resolve the name collision (INLINE-NAME-COLLISION), remove PHP's `eval`/blanket
  `require_once` (INLINE-PHP-EVAL), and de-couple the global registry in tests (INLINE-GLOBAL-REGISTRY).

## Proposed conformance fixture

The one test that would have caught the whole class of defect: a real `tina4 test` run (child process) on a
tiny project containing ONE `@tests`-annotated function AND ONE xUnit subclass asserts BOTH ran (tally >= 2)
and that a deliberately failing inline test makes `tina4 test` exit non-zero. Plus: the name-collision guard
(importing the two `assert_equal`s and asserting their signatures differ as documented); and, for PHP, that
`discover()` does not execute code outside the tests directory.

## Integration map

- Surfaces: `Testing`/`testing.ts`/`testing.rb` (decorator) and `Test`/`Tina4Test`/`test.rb` (xUnit, HTTP
  via feature 131).
- CLI: `tina4 test` -> pytest (Python) / smoke or PHPUnit (PHP) / `Testing.run_all` (Ruby) / a file-runner
  (Node).
- Related: feature 131 (the TestClient the xUnit surface uses), and the CARBONAH report which counts "Inline
  Testing" as a passing module (it counts the self-tests, not an end-to-end `tina4 test` run).

## Breaking changes and migration

- Wiring the runner (or dropping a surface) changes what `tina4 test` does - document it clearly, since a
  developer's previously-"green" run may now actually run (and possibly fail) their tests. That is the
  correctness fix. Renaming builders is a breaking API change for anyone using the descriptor surface -
  version it.

## Implementation backlog

1. INLINE-DEC-01: wire `tina4 test` to the chosen surface(s) with a real exit code + discovery, fix the
   docs, add the "both surfaces run" conformance test.
2. INLINE-DEC-02: rename/namespace the colliding assertions, remove PHP's `eval`/blanket require, de-couple
   the global registry.

## Porting capsule

Inline testing needs ONE coherent story: pick a surface (a decorator, an xUnit class, or both), and make
`tina4 test` actually DISCOVER and RUN it with a real non-zero-on-failure exit code (and ideally TAP). Never
ship a runner whose auto-discovery is a no-op behind a docstring that claims it works, and never let
`tina4 test` report green while running zero of the developer's tests. Keep the assertion names
non-colliding across surfaces, never `eval` scanned code, and de-couple any global registry from test
ordering. Prove it end-to-end: a real `tina4 test` on a one-test project must run that one test.

## Audit closure checklist

- [x] Boundary and public surface complete (two surfaces x four).
- [x] Lifecycle and every producer/consumer edge complete (declare -> discover -> run, and where each
  breaks).
- [x] Configuration, failure (false green), side-effect (PHP eval) and security rules complete.
- [x] Wire/storage (global registry, no TAP) and provider contracts complete.
- [x] Four-language behaviour + divergences recorded (each CLI's actual runner, Node/Ruby silent ignore).
- [x] Owner ambiguities decided and recorded (INLINE-DEC-01/02 proposed).
- [x] Proposed conformance fixture (real `tina4 test` runs both surfaces) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
