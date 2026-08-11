# Feature 50: Frond compiler

## Identity and status

- Matrix identity: 50 - Frond compiler (AOT)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language Frond source, and CARRIES AN OWNER DECISION (Andre,
  2026-08-11): all four languages get a Frond compiler. Ground truth: Python + PHP have a REAL AOT compiler;
  Ruby + Node have NONE (interpreters). The prior doc's provenance ("Python derived from PHP") is BACKWARDS
  and its Node "faster (compiled)" cell is fabricated. Python `frond/compiler.py:81` (`46007c1`); PHP
  `Tina4/FrondCompiler.php:70` (a PORT of the Python master, `FrondCompiler.php:11`) (`ab871934`); Ruby - NO
  compiler (`f549923`); Node - NO compiler (`engine.ts`, no `new Function`/`eval`) (`1319cf3`).
- Dependencies: the parser/AST (49) - a compiler needs a tree to compile.
- Dependants: the runtime (51) - the compiled path front-runs the interpreter.
- Existing ADRs: ADR-0001 (AOT compile layer), ADR-0004 (best implementation prevails).

- Catalog phase: Frond

## Why this feature exists

A compiler turns the parsed template into native host code so the VM runs it, instead of walking a tree per
render. Python and PHP do this; Ruby and Node interpret. The owner has decided all four should have a compiler
- a parity/architecture decision (uniform pipeline across the four), made with eyes open that Node is already
fast without one and Ruby is the slow outlier.

## Existing implementation evidence

Measured, an architectural divergence the owner has now resolved toward parity:

- PYTHON - REAL AOT compiler (`compiler.py:81-110`): emits Python source (`def _rendered(engine, ctx): ...`),
  `compile()` + `exec()` into a callable; every value-producing hole calls the interpreter's OWN primitives
  (`engine._eval_var`, `_eval_comparison`, ...) so output is byte-identical; unsupported constructs raise
  `_Unsupported` and the whole template falls back to the interpreter; compiled callables cached
  (`_compiled_fn`); compilation skipped under sandbox.
- PHP - REAL AOT compiler (`FrondCompiler.php:70`): a PORT OF the Python master (`FrondCompiler.php:11-12`);
  emits PHP source, `eval()` into a `\Closure::bind($fn, null, Frond::class)` that calls `$engine->...`
  primitives per hole; hot-path `text/output/set/if/for`, else returns null -> interpreter fallback; cached
  (`$compiledFn`, memoises even the null outcome); disabled under sandbox.
- RUBY - NO compiler. Pure interpreter (`render_tokens` `frond.rb:777`); caches TOKENS + an expr-form memo
  that still calls the real evaluators. No AOT.
- NODE - NO compiler. Interpreter over cached TOKENS (`engine.ts:2069`); no `new Function`/`eval`/`vm`
  (grep-confirmed); "compiled"/"compiledStrings" hold token lists, not functions. Fast because V8 interprets
  the token walk quickly.
- The compiled==interpreted byte-identity invariant (Python + PHP) is a design property (shared primitives +
  a twinned output-coercion `_tostr`/`_to_output`), NOT gated by a running fixture.

## Public surface contract

Internal: (Python/PHP) parse -> compile -> run the compiled callable, falling back to the interpreter for the
unsupported subset; (Ruby/Node) parse-and-interpret. Public render output must be identical whether compiled
or interpreted.

## Inputs and outputs

- Input: the AST (Python/PHP). Output: a compiled callable (or null -> interpreter). Ruby/Node: no compile
  step today.

## Lifecycle and operation graph

1. (Python/PHP) AST -> emit host source for the hot-path subset -> compile/eval -> cache the callable. 2. At
render: run the compiled callable if present, else interpret. 3. (Ruby/Node) interpret the token list.

## Configuration and precedence

- Compilation is disabled under sandbox (Python/PHP). Dev keys the compiled artifact by content so an edit
  recompiles. No public env var.

## Failures, side effects and security

- A codegen/compile error returns null and falls back to the interpreter, so a render is never broken by the
  compiler (Python/PHP). The compiler `exec`/`eval`s source it GENERATED from template nodes (not user input),
  so it is not an injection surface - but a Ruby/Node port must keep that property (generate from the parsed
  tree, never from raw template text).

## Wire and persistence contract

The compiled callable is in-memory, cached (feature 59). No wire format. Byte-identity to the interpreter is
the contract.

## Providers and substitutability

The owner decision makes the compiler a required, uniform layer. Ruby and Node must build one (Python + PHP
are the reference; PHP is the port pattern to follow).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CP-COMPILER-DIVERGENCE | Python and PHP have a REAL AOT compiler (`compiler.py:81`, `FrondCompiler.php:70`); Ruby and Node have NONE (interpreters). So "the Frond compiler" exists in only two of four. The prior doc's provenance cell ("PHP AST-based, Python derived from it") is BACKWARDS - PHP's `FrondCompiler` is a PORT OF the Python master (`FrondCompiler.php:11`). | OWNER-DECIDED (CP-DEC-01): build a compiler for Ruby and Node matching Python + PHP. Requires the parser/AST stage (PARSE-DEC-01). |
| CP-NODE-FABRICATED | The prior doc's Node cells "Hot-path only + fallback: yes" (`:39`) and "Benchmark: faster (compiled)" (`:43`) are FALSE - Node has NO compiler and no hot-path/fallback split; its speed is V8 interpreting a token walk. The "compiled" attribution is fabricated (same class as the HTTP-band fabrications). | Correct the doc; the Node "compiled" cells describe a machine Node does not have (until CP-DEC-01 builds one). |
| CP-BYTE-IDENTITY-UNTESTED | The compiled==interpreted byte-identity invariant (Python + PHP) is a design property (shared primitives + twinned coercion) but is NOT gated by a running fixture in any language. | Gate byte-identity with a real fixture; when Ruby/Node get compilers, the fixture must prove it for all four. |
| CP-COMPILE-SUBSET | The compiled subset is `text`/`output`/`set`/`if`/`for` (Python + PHP); everything else (extends/block/include/macro/from-import/cache/live/spaceless/autoescape) falls back to the interpreter. A Ruby/Node compiler must at least match this subset + the fallback boundary. | Define the canonical compilable subset + fallback contract for all four; build Ruby/Node to it. |
| CP-PROD-CACHE-STALE | The compiled/token cache never mtime-invalidates in production (cross-ref feature 59). | See feature 59 (CACHE-DEC). |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- CP-DEC-01 (OWNER-DECIDED, Andre, 2026-08-11): ALL FOUR languages get a Frond compiler. Ruby and Node build
  an AOT compiler matching Python + PHP: emit NATIVE HOST SOURCE that reuses the interpreter's own primitives
  per hole (so output is byte-identical), a hot-path subset with interpreter FALLBACK for unsupported
  constructs, the compiled artifact cached and disabled under sandbox, generated only from the parsed tree
  (never raw text). This requires the parser/AST stage first (PARSE-DEC-01 for Ruby/Node). RATIONALE: this is
  a PARITY/architecture decision (one uniform pipeline across the four), NOT a throughput one - the
  measurement showed Node is already V8-fast without a compiler and Ruby is the slow outlier; the owner has
  chosen the uniform compiled architecture regardless. (Supersedes the prior measurement-only recommendation
  in [[project_frond_compile_parity]].)
- CP-DEC-02 (proposed): gate the compiled==interpreted byte-identity invariant with a real fixture across all
  four (CP-BYTE-IDENTITY-UNTESTED); correct the provenance (PHP is a port of the Python master) and drop the
  fabricated Node "compiled" benchmark cell (CP-NODE-FABRICATED).

## Proposed conformance fixture

A shared fixture (real render): for every template in the corpus, the COMPILED render is byte-identical to the
INTERPRETED render, in all four (after CP-DEC-01 builds the Ruby/Node compilers); an unsupported construct
falls back cleanly; a sandboxed engine never compiles.

## Integration map

- Consumers: the runtime (51). Composes: the parser/AST (49), the cache (59). Reference: Python master +
  the PHP port.

## Breaking changes and migration

- Building Ruby/Node compilers is a large additive framework change (behaviour-preserving if byte-identity
  holds). It changes performance characteristics; keep the interpreter as the fallback and the correctness
  reference.

## Porting capsule

A Frond compiler (owner-decided for all four) emits NATIVE host source from the parsed AST, compiles it to a
callable, and runs it in place of the tree-walk - but every value-producing hole must call the SAME primitives
the interpreter uses, so a compiled template renders BYTE-IDENTICALLY to the interpreted one. Compile only a
hot-path subset (text/output/set/if/for) and FALL BACK to the interpreter for everything else; cache the
compiled callable; disable compilation under sandbox; generate source only from the parsed tree, never from
raw template text. Python is the master, PHP is the port to follow.

## Audit closure checklist

- [x] Boundary and public surface complete (compiler py/php; none ruby/node).
- [x] Lifecycle and producer/consumer edges complete (parse -> compile -> run/fallback).
- [x] Configuration (sandbox-disable), failure (fallback) and security (generate-from-tree) rules complete.
- [x] Wire (compiled callable, byte-identity) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (real compiler py/php; none ruby/node; provenance corrected).
- [x] Owner ambiguities decided (CP-DEC-01 OWNER: all four get a compiler; CP-DEC-02 gate byte-identity).
- [x] Conformance fixture (byte-identity across four) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
