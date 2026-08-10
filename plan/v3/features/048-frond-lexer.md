# Feature 048: Frond lexer

## Identity and status

- Matrix identity: 48 - Frond lexer
- Audit state: decision-ready
- Audit note: historical audit 2026-07-28 (bundled with 49-50); measured against source
  2026-08-10. No framework code changed.
- Dependencies: the Frond source template; Feature 49 (parser) consumes the token stream
- Dependants: Feature 49 parser, Feature 50 compiler, every Frond template render
- Existing ADRs: ADR-0009 (one folder per feature so Frond is removable, and an explicit lexer
  behind the unchanged public `Frond` entry point)
- Shared fixtures: `frond_expression_corpus.txt` (82 expression cases) plus a token-level
  fixture this audit adds
- Catalog phase: Frond template engine

## Why this feature exists

The lexer turns Frond template source into one portable token stream - text, output, block,
comment - with the whitespace-control markers recognized and useful source positions, so the
parser (Feature 49) builds the same AST from the same tokens in all four languages.

## Boundary

This feature owns tokenization: splitting source into TEXT / OUTPUT (`{{ }}`) / BLOCK (`{% %}`) /
COMMENT (`{# #}`) tokens, extracting `{% raw %}` content first as literal, RECOGNIZING the
whitespace-control markers (`{{-`, `-}}`, `{%-`, `-%}`) and recording them on each token, source
positions, and lexical errors. It DELEGATES AST construction, the actual whitespace TRIM, and
everything downstream to Feature 49; it owns recognizing the markers, not applying them.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Frond location | `frond/` folder (parser/compiler/engine) | `Frond.php` + `FrondCompiler.php` | `frond.rb` (one file) | `frond/` package (`engine.ts` one file) |
| Explicit lexer module | NO (embedded in parser) | NO | NO | NO (embedded in engine) |
| Tokenizer | regex | regex | regex | `TOKEN_RE` regex (reference) |
| Token kinds | TEXT, OUTPUT `{{ }}`, BLOCK `{% %}`, COMMENT `{# #}` | same | same | same |
| Raw blocks | `{% raw %}...{% endraw %}` extracted before tokenizing | same | same | same |
| Whitespace-control markers | `{{-`/`-}}`/`{%-`/`-%}` recognized; trim is a PARSE concern | same | same | same |
| Source positions (line/col) | (to confirm - regex tokenizer) | (to confirm) | (to confirm) | (to confirm) |

There is NO standalone lexer module in any framework yet: tokenization is embedded (Python in
`parser.py`, Node in `engine.ts`, Ruby in the one-file `frond.rb`, PHP in `Frond`/`FrondCompiler`).
The tokenizer is REGEX-based - Node's `TOKEN_RE` matches `{%-? ... -?%}`, `{{-? ... -?}}` and
`{# ... #}`, with everything else TEXT, and `{% raw %}` blocks extracted first so their content is
literal. Whitespace control is recognized by the lexer (the `-` markers) but the actual trim is a
parse concern (Python: `_apply_whitespace_control` on TEXT nodes). ADR-0009 requires the Frond
folder to be removable and an EXPLICIT lexer behind the unchanged `Frond` entry point, so
extracting the embedded tokenizer into a real lexer module - producing one agreed token stream -
is the structural work this audit specifies.

## Public surface contract

The lexer (behind the unchanged `Frond` entry point) takes source and produces a token stream:
each token is a kind (TEXT, OUTPUT, BLOCK, COMMENT, plus EOF), its raw text, its whitespace-
control flags (leading `-`, trailing `-`), and its source position (line/column). `{% raw %}`
content is one TEXT token. A malformed delimiter produces a positioned lexical error.

## Inputs and outputs

- Input: the Frond source string.
- Output: an ordered token stream ending in EOF; each token carries kind, text, whitespace-
  control flags, and a source position.
- OUTPUT tokens hold the `{{ ... }}` inner expression text (parsed later); BLOCK tokens hold the
  `{% ... %}` inner tag text; COMMENT tokens are dropped or preserved per the pinned rule.
- Malformed input is PRESERVED, not fixed (a malformed `{% for %}` is tokenized as encountered),
  matching the engine's preserve-not-fix rule.

## Lifecycle and operation graph

1. `{% raw %}...{% endraw %}` blocks are extracted first; their content becomes literal TEXT.
2. The remaining source is scanned by the tokenizer: each `{{ }}`/`{% %}`/`{# #}` becomes an
   OUTPUT/BLOCK/COMMENT token, and the runs between them become TEXT tokens.
3. Each delimiter's whitespace-control markers (`-`) are recorded on the token; the trim itself
   is applied later by Feature 49.
4. Each token is stamped with its source position for the parser's error messages.
5. The stream, ending in EOF, is passed to Feature 49.

## Configuration and precedence

- The delimiters are fixed (`{{ }}`, `{% %}`, `{# #}`) and the whitespace-control marker is `-`,
  matching Twig/Jinja2 (ADR-0005).
- `{% raw %}` extraction runs before tokenization, so a `{{ }}` inside a raw block is literal.
- There is no per-template lexer configuration.

## Failures, side effects and security

- A lexical error (an unterminated `{{`/`{%`/`{#`) is reported with its source position, not
  swallowed; a positionless error makes a template bug unfindable.
- Malformed input is preserved as tokens, not silently repaired, so the parser and compiler make
  the same decision on the same input.
- The lexer is pure over its input (no I/O, no state leak between templates); a regex tokenizer
  must not mis-tokenize a delimiter inside a string literal (a `{{ }}` inside a `{% %}` string),
  which is the classic regex-lexer hazard to gate.
- Source positions must be accurate; a global-regex tokenizer that loses line/column would give
  the parser wrong positions - the audit gates positions on multi-line input.

## Wire and persistence contract

There is no persistence; the token stream is the internal contract between the lexer and Feature
49. Its shape (kind, text, whitespace flags, position) is identical across the four, so the same
source yields the same tokens everywhere - the precondition for the same AST and the same render.

## Providers and substitutability

The lexer is pure and engine-agnostic. A future runtime tokenizes the same delimiters into the
same token kinds with the same whitespace-control recognition and the same positions, behind the
same `Frond` entry point.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| LEX-01 | No explicit lexer module exists; tokenization is embedded, against ADR-0009's removable-folder + explicit-lexer requirement. | Extract an explicit lexer module in the Frond folder in all four, producing one agreed token stream, behind the unchanged `Frond` entry point. |
| LEX-02 | The tokenizer is regex-based and its exact behaviour (delimiters, raw-first, whitespace markers) is not gated as parity. | Gate the token stream (kinds, text, whitespace flags) for a shared token-level corpus in all four. |
| LEX-03 | Source positions (line/column) may be lost by a global-regex tokenizer; not gated. | Gate accurate line/column on multi-line source in all four. |
| LEX-04 | A delimiter inside a string within a `{% %}` (a regex-lexer hazard) may mis-tokenize; not gated. | Gate that a `{{`/`%}` inside a quoted string is not mis-tokenized in all four. |
| LEX-05 | Lexical errors (unterminated delimiter) and their positions are not gated. | Gate a positioned lexical error for an unterminated delimiter in all four. |
| LEX-06 | No token-level fixture exists (the 82-case corpus is expression-level). | Add a token-level fixture alongside `frond_expression_corpus.txt`. |

## Owner decisions

Proposed for owner ratification:

1. An explicit lexer module is extracted into the removable Frond folder in all four (ADR-0009),
   behind the unchanged public `Frond` entry point; it produces one agreed token stream.
2. The token kinds are TEXT, OUTPUT (`{{ }}`), BLOCK (`{% %}`), COMMENT (`{# #}`) and EOF, with
   `{% raw %}` content as one literal TEXT token, matching Twig/Jinja2 (ADR-0005).
3. The lexer RECOGNIZES the whitespace-control markers (`-`) and records them on the token; the
   parser (Feature 49) applies the trim.
4. Every token carries an accurate source position (line/column) for the parser's error
   messages.
5. Malformed input is preserved as tokens (not repaired); an unterminated delimiter is a
   positioned lexical error.

## Proposed conformance fixture

Add a token-level fixture (alongside `frond_expression_corpus.txt`) with stable ids for:
tokenizing text/output/block/comment into the right kinds; `{% raw %}` content as one literal
TEXT token; whitespace-control markers recorded on the token; accurate line/column on multi-line
source; a delimiter inside a quoted string NOT mis-tokenized; and an unterminated delimiter
raising a positioned lexical error. Every case tokenizes real source and compares the stream; a
pure-logic lexer needs no service, but the corpus is shared across all four runners.

## Integration map

- The lexer feeds Feature 49 (parser), which feeds Feature 50 (compiler); the public `Frond`
  entry point is unchanged (ADR-0009).
- The token-level fixture joins the expression corpus in the shared Frond fixtures.
- Central fixtures, four runners, the CI matrix and the Frond docs update together.

## Breaking changes and migration

- Extracting the lexer is internal (behind the unchanged `Frond` entry point); no template
  breaks. A template relying on a mis-tokenization bug (a delimiter in a string) changes to the
  correct behaviour - a fix, noted in the release note.
- The token stream is an internal contract; no application depends on it directly.

## Implementation backlog

1. Add the token-level fixture and wire four runners.
2. Extract an explicit lexer module in each Frond folder (LEX-01), behind the `Frond` entry.
3. Gate the token stream (LEX-02), source positions (LEX-03), string-delimiter safety (LEX-04)
   and lexical errors (LEX-05) in all four.
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement a lexer that scans Frond source into a token stream: extract `{% raw %}` content as
literal TEXT first, then tokenize `{{ }}`/`{% %}`/`{# #}` into OUTPUT/BLOCK/COMMENT and the runs
between into TEXT, ending in EOF. Record the whitespace-control markers (`-`) on each token
(the trim is the parser's), stamp each token with an accurate line/column, and raise a positioned
error for an unterminated delimiter. Do not mis-tokenize a delimiter inside a quoted string. Keep
it pure and behind the unchanged `Frond` entry point (ADR-0009). Prove the port against the
token-level fixture.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (LEX-01..06).
- [x] Owner ambiguities recorded (5 proposed; the explicit-lexer extraction and positions are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
