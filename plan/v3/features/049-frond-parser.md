# Feature 49: Frond parser

## Identity and status

- Matrix identity: 49 - Frond parser (AST construction)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language Frond source (correcting a prior-session doc that
  claimed "parse errors (mismatched tags): loud" and "trim once in the parser" - both false for most
  languages). Python + PHP build a real AST; Ruby + Node have NO AST (parse-and-render in one pass). Python
  `frond/parser.py:415` (`46007c1`); PHP `Tina4/Frond.php:595` (`ab871934`); Ruby `lib/tina4/frond.rb:777`
  (render_tokens, no AST) (`f549923`); Node `packages/frond/src/engine.ts:2069` (renderTokens, no AST)
  (`1319cf3`).
- Dependencies: the lexer/tokenizer (48).
- Dependants: the compiler (50), the runtime (51).
- Existing ADRs: ADR-0004 (best implementation prevails).

- Catalog phase: Frond

## Why this feature exists

The parser turns tokens into a structure the renderer/compiler can execute. The audit question is whether
that structure is a real AST (built once) or re-derived at render. It is split: Python and PHP build an AST;
Ruby and Node walk the flat token list and re-derive `if`/`for` grouping on EVERY render. The owner has
decided all four get a compiler (feature 50) - which requires a parse tree to compile from, so Ruby and Node
will need a real parser stage.

## Existing implementation evidence

Architectural divergence, measured:

- PYTHON: a genuine AST of `@dataclass(slots=True)` nodes (`parser.py:170-351`, ~18 node types); `if`/`for`
  body grouping and whitespace trim decided ONCE in the parser; the compiler consumes the AST without
  re-deriving grouping (the old duplicate `_collect_if`/`_collect_for` was deleted - `compiler.py:19-22`).
- PHP: a nested-array AST (`parse()` `Frond.php:595`, node `type` tags `text`/`output`/`if`/`for`/...);
  grouping in the parser; whitespace trim in the LEXER (not the parser); the compiler reuses the AST grouping.
- RUBY: NO AST. `render_tokens` (`frond.rb:777`) walks the flat token list and re-derives `if`/`for` grouping
  inline at render (`handle_if` scans forward). The file comment (`frond.rb:742`) self-documents the absence
  of an AST.
- NODE: NO AST. `renderTokens` (`engine.ts:2069`) interleaves parse and eval; `if`/`for` grouping is
  re-derived at render on every render (`handleIf`/`handleFor` scan forward).
- NO language carries a source SPAN on a node. Parse errors are asymmetric: an UNKNOWN tag RAISES in all four;
  an UNCLOSED/mismatched `if`/`for` is SILENTLY swallowed (best-effort render) in all four; neither is
  positioned.

## Public surface contract

Internal: tokens -> (Python/PHP) an AST / (Ruby/Node) a rendered string. No public parser API.

## Inputs and outputs

- Input: the token list. Output: an AST (Python/PHP) or direct render (Ruby/Node).

## Lifecycle and operation graph

1. (Python/PHP) parse tokens -> AST (group if/for bodies, resolve extends/block markers). 2. (Ruby/Node) walk
tokens, grouping inline at render.

## Configuration and precedence

- None.

## Failures, side effects and security

- An unclosed `{% if %}`/`{% for %}` renders best-effort with NO error (all four). Only an unknown tag raises.
  No positions anywhere.

## Wire and persistence contract

The AST (Python/PHP) or token list (Ruby/Node) is cached downstream (feature 59). No wire format.

## Providers and substitutability

The owner's compiler decision (50) requires a parse tree in all four; Ruby and Node need a parser/AST stage
added (Python/PHP are the reference).

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| PARSE-AST-DIVERGENCE | Python and PHP build a real AST (grouping decided ONCE at parse - `parser.py:170`, `Frond.php:595`); Ruby and Node have NO AST and re-derive `if`/`for` grouping at RENDER on EVERY render (`frond.rb:777`, `engine.ts:2069`). So "the Frond parser" is a different thing across the four, and the render-time re-derivation is a repeated cost. The owner has decided all four get a compiler (50), which must compile FROM a parse tree - so Ruby and Node need a real parser stage. | Add a parser/AST stage to Ruby and Node so all four parse to a tree that BOTH the interpreter and the compiler consume (grouping decided once). Python + PHP are the reference. |
| PARSE-UNCLOSED-SILENT | UNIVERSAL: an unclosed/mismatched `{% if %}`/`{% for %}` is SILENTLY swallowed (best-effort render), not a loud error, in all four (Python `parser.py:40-44`; PHP `Frond.php:750`; Ruby `frond.rb:1861`; Node `engine.ts:2559`). The prior doc's "parse errors (mismatched tags): loud" is FALSE - only UNKNOWN tags are loud. | Raise a POSITIONED error on an unclosed/mismatched tag in all four (depends on LEX-DEC-01 positions). |
| PARSE-NO-SPANS | UNIVERSAL: no node/token carries a source span, so even where a parse error is raised (unknown tag) it has NO position. | Add spans (with LEX-DEC-01) so parse errors point at a line. |
| PARSE-WHITESPACE-STAGE | The prior doc says trim happens "once, in the parser"; true only for Python. PHP trims in the lexer; Ruby/Node at render. | Unify the trim stage (cross-ref LEX-TRIM-STAGE-DIVERGE). |

## Owner decisions

- PARSE-DEC-01 (proposed, shaped by the owner's compiler decision on 50): give Ruby and Node a real
  parser/AST stage so all four parse to ONE tree that both the interpreter and the (owner-decided) compiler
  consume, with `if`/`for` grouping decided once rather than re-derived per render. Python + PHP are the
  reference. This is a prerequisite for a Ruby/Node compiler.
- PARSE-DEC-02 (proposed): raise a POSITIONED error on an unclosed/mismatched tag (PARSE-UNCLOSED-SILENT), not
  silent best-effort, in all four (depends on LEX-DEC-01).

## Proposed conformance fixture

A shared fixture: the same template parses to an equivalent structure and renders identically in all four; an
unclosed `{% if %}` raises a positioned error (after PARSE-DEC-02) rather than silently swallowing the rest;
`if`/`for` grouping is stable.

## Integration map

- Consumers: the compiler (50), the runtime (51). Composes: the lexer (48).

## Breaking changes and migration

- Adding a parser/AST stage to Ruby/Node is an internal architecture change (behaviour-preserving if done
  right) enabling the compiler. Raising on unclosed tags changes behaviour for malformed templates - a
  correctness fix.

## Porting capsule

Parse tokens into a real AST (a tree of typed nodes) - decide `if`/`for` grouping and whitespace trim ONCE, at
parse, not re-derived per render (the Ruby/Node gap). Carry a source span on each node (with the lexer's
positions). Raise a positioned error on an unclosed/mismatched tag. The AST must be what BOTH the interpreter
and the compiler (owner-decided for all four) consume.

## Audit closure checklist

- [x] Boundary and public surface complete (AST py/php; no-AST ruby/node).
- [x] Lifecycle and producer/consumer edges complete (tokens -> AST/render).
- [x] Configuration (none), failure (unclosed-silent) and security rules complete.
- [x] Wire (AST/token list) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (AST divergence; unclosed-silent; no spans).
- [x] Owner ambiguities decided (PARSE-DEC-01 add parser to ruby/node, PARSE-DEC-02 positioned errors).
- [x] Conformance fixture (parse parity + positioned error) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
