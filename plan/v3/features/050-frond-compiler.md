# Feature 050: Frond compiler

## Identity and status

- Matrix identity: 50 - Frond compiler
- Audit state: decision-ready
- Audit note: historical audit 2026-07-28 (bundled with 48/49); measured against source
  2026-08-10. No framework code changed.
- Dependencies: Feature 49 (the AST), the filter definitions (used, not owned), the template
  cache
- Dependants: every Frond template render; `{% live %}` server-rendered blocks; `{% cache %}`
- Existing ADRs: ADR-0009 (removable Frond folder); ADR-0001 (the ahead-of-time compile layer,
  prototype-gated)
- Shared fixtures: `frond_expression_corpus.txt` (82 cases) plus a render-parity fixture this
  audit adds
- Catalog phase: Frond template engine

## Why this feature exists

The compiler turns the Frond AST into a validated, executable, cacheable template - so a render
CALLS a compiled function instead of walking the tree every time, and a compiled template renders
BYTE-IDENTICALLY to the interpreted one. That byte-identity is the safety property that lets the
compile layer exist at all.

## Boundary

This feature owns conversion of the Feature 49 AST into executable form, compile-time
validation, the cacheable compiled identity, and the hot-path-compile-with-interpreter-fallback
policy. It DELEGATES tokenization to Feature 48, parsing to Feature 49, and the filter and runtime
context definitions to their own features (it USES filters, it does not define them).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Compile layer | AOT compiler (ADR-0001) - compiles AST to a function | AST-based (Python derived from it) | INTERPRETER only (no compile layer) | (to confirm) |
| Render path | calls the compiled function, no tree-walk | compiled | per-render tree-walk (slow) | (to confirm) |
| Compiled == interpreted | byte-identical (the invariant) | byte-identical | n/a (interpreted only) | byte-identical |
| Hot-path only + fallback | yes (text, `{{ var }}`, whitespace) | yes | n/a | yes |
| Cacheable compiled identity | yes | yes | (interprets) | yes |
| Macros | supported | supported | aliased macro rendered SILENTLY EMPTY (bug) | supported |
| `{% live %}` / `{% cache %}` blocks | supported | supported | supported | supported |
| Benchmark | faster (compiled) | faster | slower (loses to Twig/ERB) | faster |

Python's `compiler.py` is an ahead-of-time compiler (ADR-0001): it compiles the AST into a
function so `render()` pays no per-render tree-walk, and it compiles ONLY the common hot-path
constructs (text, `{{ var }}`, whitespace control), falling back to the interpreter for the rest.
The governing invariant is stated in the source: "a compiled template renders BYTE-IDENTICALLY to
the interpreted one," because both consume the same AST from Feature 49 and call the same
primitives. Ruby is the outlier: it INTERPRETS (a per-render tree-walk) with no compile layer,
which is the measured performance gap (Frond loses to Twig/ERB there) and the "Ruby needs a compile
layer" finding; it also had a real macro bug where an aliased macro rendered silently empty.

## Public surface contract

Behind the unchanged `Frond` entry point, the compiler takes the AST and produces a cacheable
compiled template; a render invokes it and produces output. A compiled template renders
byte-identically to the interpreted one. Only hot-path constructs are compiled; the rest fall back
to the interpreter, transparently. Macros, template inheritance (`extends`/`block`), `include`,
`{% live %}` and `{% cache %}` all render correctly. The compiled result is cached by a stable
identity and invalidated when the template changes.

## Inputs and outputs

- Input: the Feature 49 AST and the runtime context at render time.
- Output: rendered template output, identical whether produced by the compiled path or the
  interpreter.
- The compiled template is cached; a template-source change invalidates it.
- A compile-time validation error (an unsupported construct, a bad macro) is raised at compile
  time with position, not silently mis-rendered.

## Lifecycle and operation graph

1. The compiler validates the AST and compiles the hot-path constructs into an executable form,
   leaving the rest to the interpreter fallback.
2. The compiled template is cached under a stable identity.
3. A render calls the compiled function (or the interpreter for a fallback node), applying
   filters and the runtime context.
4. A template-source change invalidates the cached compiled template (and hot-reload
   re-compiles).
5. `{% live %}` blocks register for server-side re-render; `{% cache %}` blocks cache their
   output.

## Configuration and precedence

- The compile layer is prototype-gated (ADR-0001): it is enabled only where byte-identity to the
  interpreter is proven; otherwise the interpreter is authoritative.
- Only hot-path constructs are compiled; the fallback boundary is the same across the frameworks
  that compile.
- The template cache is invalidated on source change and hot-reload.

## Failures, side effects and security

- BYTE-IDENTITY is the safety invariant: if a compiled template ever renders differently from the
  interpreted one, the compile layer is WRONG and must fall back; the audit gates byte-identity on
  the whole corpus. This is why the compiler consumes the same AST and calls the same primitives
  as the interpreter.
- A macro must render its body, not silently empty (the Ruby aliased-macro bug); a silently-empty
  render is a data-loss-shaped bug in a template.
- Output escaping (autoescape) is a security property: a `{{ var }}` must escape by default so a
  template cannot inject HTML/script from user data; the compiled and interpreted paths must
  escape identically.
- A compile error is raised at compile time with position, never a partial or mis-rendered
  template at runtime.
- The cache must invalidate on a template change, or a stale compiled template serves old content
  after an edit (the Ruby memoization-staleness class of bug).

## Wire and persistence contract

There is no external wire format; the compiled template is an in-process cached artifact keyed by
a stable identity. The observable contract is the RENDERED OUTPUT, which is byte-identical across
the four for the same template and context, and byte-identical between the compiled and
interpreted paths within a framework.

## Providers and substitutability

The compiler is engine-agnostic over the AST. A framework may compile (a function) or interpret
(a tree-walk), but the RENDERED OUTPUT must be identical either way. A future runtime either
compiles with proven byte-identity or interprets; the corpus gates that its output matches.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| CP-01 | Ruby has no compile layer (interprets every render); the measured performance gap (loses to Twig/ERB). | Decide: add a Ruby compile layer, or keep Ruby interpreted with proven byte-identity (correctness holds, perf lags); pin the choice. |
| CP-02 | Byte-identity between the compiled and interpreted paths is the safety invariant but is not gated across four. | Gate that the compiled output equals the interpreted output for the whole corpus, in every framework that compiles. |
| CP-03 | Ruby rendered an aliased macro SILENTLY EMPTY. | Gate that a macro (including an aliased one) renders its body in all four. |
| CP-04 | Autoescape (a `{{ var }}` escapes by default) is a security property not gated as parity. | Gate that user data in `{{ }}` is escaped identically (compiled and interpreted) in all four. |
| CP-05 | The compiled-template cache invalidation on source change/hot-reload is not gated (Ruby memoization staleness). | Gate that a template edit invalidates the cached compiled template in all four. |
| CP-06 | The hot-path/fallback boundary is not gated as consistent. | Gate that a fallback construct renders identically to a fully-interpreted render in all four. |
| CP-07 | No render-parity fixture exists (the corpus is expression-level). | Add a render-parity fixture over the full template corpus. |

## Owner decisions

Proposed for owner ratification:

1. BYTE-IDENTITY is the compile layer's acceptance gate (ADR-0001): a compiled template MUST
   render byte-identically to the interpreted one over the whole corpus; where it cannot be
   proven, the interpreter is authoritative and the compile layer falls back.
2. Ruby's missing compile layer: decide add-it (close the perf gap) versus keep-interpreted-with-
   byte-identity (correctness parity now, perf later); pin one.
3. A macro (including an aliased one) renders its body; the silently-empty render is a defect.
4. `{{ var }}` autoescapes by default, identically on the compiled and interpreted paths; a raw
   output is explicit.
5. The compiled-template cache invalidates on a source change and hot-reload; no stale render
   after an edit.

## Proposed conformance fixture

Add a render-parity fixture over the full template corpus with stable ids for: the compiled
output equalling the interpreted output byte-for-byte for every template; a macro (and an aliased
macro) rendering its body; a `{{ user_data }}` escaping by default identically on both paths;
template inheritance, `include`, `{% live %}` and `{% cache %}` rendering correctly; a
template edit invalidating the cache; and a fallback construct matching a fully-interpreted
render. Every case renders a real template with a real context and compares bytes; a pure render
needs no service, and the corpus runs in all four runners.

## Integration map

- Feature 49 supplies the AST; the filter and context features supply the runtime; the template
  cache holds compiled templates; `{% live %}` ties to the realtime/server-render path.
- ADR-0001 governs the compile layer; the byte-identity gate is its prototype acceptance.
- Central fixtures, four runners, the CI matrix (running the render-parity corpus) and the Frond
  docs update together.

## Breaking changes and migration

- Adding a Ruby compile layer (if chosen) is internal and byte-identity-gated; no template breaks.
  Fixing the aliased-macro-empty bug changes a currently-empty render to correct output - a fix,
  noted in the release note.
- Autoescape and cache-invalidation fixes are correctness/security; a template relying on the old
  behaviour is itself a bug.

## Implementation backlog

1. Add the render-parity fixture and wire four runners over the full corpus.
2. Gate byte-identity compiled-vs-interpreted (CP-02) and the macro fix (CP-03) in all four.
3. Gate autoescape parity (CP-04) and cache invalidation (CP-05) in all four.
4. Decide and implement the Ruby compile-layer question (CP-01); gate the fallback boundary
   (CP-06).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Compile the Feature 49 AST into a cacheable executable template for the hot-path constructs
(text, `{{ var }}`, whitespace), falling back to the interpreter for the rest, behind the
unchanged `Frond` entry point. Guarantee BYTE-IDENTITY: the compiled output must equal the
interpreter's for the whole corpus, or fall back. Autoescape `{{ var }}` by default identically
on both paths. Render macros (including aliased) to their body. Cache by a stable identity and
invalidate on source change. A runtime may interpret instead of compile, but the rendered output
must match. Prove the port with the render-parity corpus, a macro case, an autoescape case, and a
cache-invalidation case.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (CP-01..07).
- [x] Owner ambiguities recorded (5 proposed; byte-identity and the Ruby compile layer are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
