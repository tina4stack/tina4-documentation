# Feature 049: Frond parser

## Identity and status

- Matrix identity: 49 - Frond parser
- Audit state: decision-ready
- Audit note: historical audit 2026-07-28 (bundled with 48/50); measured against source
  2026-08-10. No framework code changed.
- Dependencies: Feature 48 (lexer token stream), Feature 50 (compiler consumes the AST)
- Dependants: Feature 50 compiler, every Frond template render
- Existing ADRs: ADR-0009 (removable Frond folder, explicit modules behind the unchanged
  `Frond` entry); ADR-0005 (Frond tracks Twig and Jinja2)
- Shared fixtures: `frond_expression_corpus.txt` (82 expression cases) plus a statement/AST-level
  fixture this audit adds
- Catalog phase: Frond template engine

## Why this feature exists

The parser turns the lexer's token stream into one portable Frond syntax tree - text nodes,
output nodes with a parsed expression, and block nodes with `if`/`for`/`set`/`include`/`extends`/
`macro`/`block` structure - so the compiler (Feature 50) renders the same output from the same
tree in all four languages.

## Boundary

This feature owns deterministic conversion from Feature 48 tokens into an AST: expression
precedence, statement nesting, the if/for body GROUPING, applying the whitespace TRIM the lexer
recognized, source spans, and parse errors. It DELEGATES tokenization to Feature 48 and executable
generation, runtime context and filters to Feature 50. The AST is the single source of grouping;
the compiler must not re-derive it.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Clean parser boundary | YES (`parser.py`) | NO (mixes parse + compile) | NO (mixes parse + eval) | NO (mixes parse + eval) |
| AST grouping (if/for bodies) | in the parser | duplicated in compiler (DRY bug, fixed) | mixed | mixed |
| Whitespace trim | applied in parser (`_apply_whitespace_control`) | mixed | mixed | mixed |
| Expression precedence | corpus-driven | corpus-driven | corpus-driven | corpus-driven |
| Expression corpus parity | high (72+/82) | high | high | high |
| Source spans on nodes | (to confirm) | (to confirm) | (to confirm) | (to confirm) |
| Parse errors (mismatched tags) | loud | (to confirm) | (to confirm) | (to confirm) |

Only Python exposes a recognizable parser boundary; PHP, Ruby and Node mix parsing with
compilation or evaluation, so ADR-0009's explicit-module requirement is unmet in three of four.
The Python `parser.py` owns the if/for body GROUPING and the whitespace-trim application - and a
historical bug had the COMPILER hold "a second, hand-synchronised copy of that same grouping,"
which is exactly the DRY hazard the parser boundary removes: the AST must be the ONE place the
grouping lives. Expression parsing is driven by the shared `frond_expression_corpus.txt` (82
cases, high parity), covering operator precedence, filters (`|`) and the Twig/Jinja2 expression
grammar (ADR-0005).

## Public surface contract

The parser (behind the unchanged `Frond` entry point) takes the lexer's token stream and produces
an AST: TEXT nodes, OUTPUT nodes carrying a parsed expression (with precedence), and BLOCK nodes
for the supported tags with their grouped bodies and branches. The whitespace trim recognized by
the lexer is applied to adjacent TEXT here. A mismatched or unknown tag, or an expression syntax
error, is a positioned parse error.

## Inputs and outputs

- Input: the Feature 48 token stream (with whitespace-control flags and source positions).
- Output: an AST whose nodes carry source spans; OUTPUT node expressions are fully parsed
  (precedence, filters); BLOCK nodes carry grouped bodies (an `if`'s branches, a `for`'s body).
- The whitespace trim is applied to adjacent TEXT nodes exactly once, here (not in the compiler).
- Malformed input is preserved as a defined AST (a malformed `{% for %}` becomes a node that
  renders its body inline once), not silently repaired.

## Lifecycle and operation graph

1. The parser consumes tokens in order, building TEXT/OUTPUT/BLOCK nodes.
2. For a block tag, it GROUPS the following tokens into the tag's body/branches (an `if`'s
   `elif`/`else`, a `for`'s body up to `endfor`) - once, in the AST.
3. It applies the whitespace trim the lexer flagged to the adjacent TEXT nodes.
4. It parses each OUTPUT expression with operator precedence and filters.
5. It attaches source spans (from the token positions) to each node and raises a positioned
   parse error for a mismatched/unknown tag or a bad expression.

## Configuration and precedence

- The supported tags and the expression grammar track Twig/Jinja2 (ADR-0005): `if`/`for`/`set`/
  `include`/`extends`/`block`/`macro`/`raw`, operator precedence, and `|` filters.
- The AST grouping is the single source; the compiler consumes it without re-deriving.
- There is no per-template parser configuration.

## Failures, side effects and security

- A mismatched tag (`{% if %}` with no `{% endif %}`), an unknown tag, or an expression syntax
  error is a POSITIONED parse error, using the token's source span, so a template author can find
  it.
- Malformed input is preserved as a defined AST, not repaired, so the compiler makes the same
  decision on the same input (the engine's preserve-not-fix rule).
- The parser is pure over its tokens (no I/O, no runtime context); it must not evaluate an
  expression or read a variable - that is the compiler's job, and mixing them is the boundary bug
  in three of four.
- Precedence and grouping must be deterministic; the corpus gates that the same expression parses
  to the same tree everywhere, so a template cannot render differently by language.

## Wire and persistence contract

There is no persistence; the AST is the internal contract between the parser and Feature 50. Its
shape (node kinds, grouped bodies, parsed expressions, source spans) is identical across the four
- the precondition for identical rendering.

## Providers and substitutability

The parser is pure and engine-agnostic. A future runtime parses the same tokens into the same AST
with the same precedence, grouping and spans, behind the same `Frond` entry point.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| PS-01 | Only Python has a clean parser boundary; PHP/Ruby/Node mix parse with compile/eval, against ADR-0009. | Extract an explicit parser module in all four, producing one agreed AST behind the `Frond` entry. |
| PS-02 | The if/for grouping was duplicated in the compiler (DRY bug). | The AST is the SINGLE source of grouping; gate that the compiler does not re-derive it. |
| PS-03 | Whitespace-trim application (recognized by the lexer) must happen once, in the parser. | Gate the trim on adjacent TEXT once in all four. |
| PS-04 | Expression precedence/filters parity is corpus-driven but the corpus is not a gated parser fixture across four. | Gate the full `frond_expression_corpus.txt` parsing to one tree in all four. |
| PS-05 | Source spans on AST nodes (for compile/render errors) are not gated. | Gate spans on nodes in all four. |
| PS-06 | Parse errors (mismatched/unknown tag, bad expression) and their positions are not gated. | Gate a positioned parse error for each in all four. |
| PS-07 | No statement/AST-level fixture (the corpus is expression-level). | Add a statement-level fixture alongside the corpus. |

## Owner decisions

Proposed for owner ratification:

1. An explicit parser module is extracted in all four (ADR-0009), behind the unchanged `Frond`
   entry point; it produces one agreed AST from the lexer tokens.
2. The AST is the SINGLE source of if/for grouping; the compiler consumes it and never
   re-derives the grouping (closing the historical DRY bug).
3. The parser applies the whitespace trim the lexer recognized, once, to adjacent TEXT.
4. Expression parsing follows the shared corpus (precedence, filters, Twig/Jinja2 grammar,
   ADR-0005); the same expression parses to the same tree in all four.
5. Nodes carry source spans; a mismatched/unknown tag or a bad expression is a positioned parse
   error; malformed input is preserved as a defined AST, not repaired.

## Proposed conformance fixture

Add a statement/AST-level fixture (with `frond_expression_corpus.txt`) with stable ids for: the
full expression corpus parsing to one tree; nested `if`/`for` grouping into the correct bodies
and branches; the whitespace trim applied once; source spans on nodes; a mismatched `{% if %}`
raising a positioned parse error; an unknown tag raising a positioned error; and a malformed tag
preserved as the defined AST. Every case parses real tokens and compares the tree; a pure-logic
parser needs no service, and the corpus runs in all four runners.

## Integration map

- Feature 48 feeds tokens; the parser feeds the AST to Feature 50; the public `Frond` entry is
  unchanged (ADR-0009).
- The statement-level fixture joins the expression corpus in the shared Frond fixtures.
- Central fixtures, four runners, the CI matrix and the Frond docs update together.

## Breaking changes and migration

- Extracting the parser and removing the compiler's duplicate grouping is internal (behind the
  unchanged `Frond` entry); no template breaks. A template relying on a grouping inconsistency
  between parser and compiler renders consistently after - a fix, noted in the release note.
- The AST is an internal contract; no application depends on it directly.

## Implementation backlog

1. Add the statement-level fixture and wire four runners with the full expression corpus.
2. Extract an explicit parser module in PHP/Ruby/Node (PS-01), behind the `Frond` entry.
3. Make the AST the single grouping source; remove the compiler's copy (PS-02).
4. Gate the whitespace trim (PS-03), the corpus parse (PS-04), source spans (PS-05) and parse
   errors (PS-06) in all four.
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a parser that consumes the lexer tokens into an AST: TEXT nodes, OUTPUT nodes with a
precedence-parsed expression (filters included), and BLOCK nodes whose bodies/branches are grouped
ONCE here. Apply the whitespace trim the lexer flagged to adjacent TEXT. Attach source spans, and
raise a positioned parse error for a mismatched/unknown tag or a bad expression; preserve
malformed input as a defined AST. Stay pure (no evaluation, no context) and behind the unchanged
`Frond` entry point. Prove the port against the expression corpus and the statement fixture.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (PS-01..07).
- [x] Owner ambiguities recorded (5 proposed; the explicit-parser extraction and single-grouping are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
