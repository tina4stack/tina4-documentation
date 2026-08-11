# Feature 48: Frond lexer

## Identity and status

- Matrix identity: 48 - Frond lexer (tokenization)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language Frond source (correcting a prior-session doc whose
  unverified cells and "trim is a parse concern" claim did not hold). NO language has a distinct lexer
  MODULE - tokenization is embedded. Python `frond/parser.py:57` (`46007c1`); PHP `Tina4/Frond.php:458`
  (`ab871934`); Ruby `lib/tina4/frond.rb:78` (`f549923`); Node `packages/frond/src/engine.ts:358`
  (`1319cf3`). (All HEADs are docs-only commits atop the measured framework code.)
- Dependencies: none (the front of the pipeline).
- Dependants: the parser (49), the compiler (50), the runtime (51).
- Existing ADRs: ADR-0004 (best implementation prevails).

- Catalog phase: Frond

## Why this feature exists

The lexer turns template source into tokens. The audit questions: is there a real lexer stage, do tokens
carry source positions (so errors can point at a line), and is tokenization quote-aware. The answers are no,
no, and no - uniformly. This feature is a set of shared gaps, not a divergence.

## Existing implementation evidence

Universal shape, measured in all four:

- NO distinct lexer module: tokenization is an embedded function/method (Python regex in `parser.py`; PHP a
  `strpos` scan in `Frond.php`; Ruby a regex in `frond.rb`; Node a regex in `engine.ts`).
- Tokens are 2-element `[type, rawString]` (PHP adds `lstrip`/`rstrip` flags); kinds are TEXT / VAR (`{{ }}`) /
  BLOCK (`{% %}`) / COMMENT (`{# #}`). The prior docs call the VAR kind "OUTPUT". NO token carries a source
  position (line/col), and there is NO EOF token, in any language.
- `{% raw %}` is extracted BEFORE tokenizing (regex) and restored as literal TEXT in all four.
- Whitespace-control markers (`-`) are recognized in all four, but the TRIM is applied at DIFFERENT stages:
  Python in the parser (`_apply_whitespace_control`), PHP in the LEXER (`applyWhitespaceControl` inside
  `tokenize`), Ruby and Node inline at RENDER (`stripTag`). So the prior "trim is a parse concern" is true
  only for Python.
- The tokenizer is NOT quote-aware in any language (non-greedy regex in py/ruby/node, `strpos` in php), so a
  `%}` or `}}` inside a quoted string within a tag mis-terminates it. An unterminated delimiter becomes
  literal TEXT with no error.

## Public surface contract

Internal: source -> a token list. There is no public lexer API. The tokens feed the parser/interpreter.

## Inputs and outputs

- Input: template source. Output: a flat token list `[type, value]` (no positions, no EOF).

## Lifecycle and operation graph

1. Extract `{% raw %}` to placeholders. 2. Scan for `{{`/`{%`/`{#` delimiters. 3. Emit TEXT/VAR/BLOCK/COMMENT
tokens. 4. (PHP) apply whitespace trim here; (Python) later in the parser; (Ruby/Node) at render.

## Configuration and precedence

- None. No env var.

## Failures, side effects and security

- An unterminated delimiter or a delimiter inside a quoted string mis-tokenizes with NO error and NO position
  (see the register). No security surface of its own (but the parser/runtime inherit the missing positions).

## Wire and persistence contract

No wire/persistence. The token list is in-memory and (for templates) cached downstream (feature 59).

## Providers and substitutability

A future runtime should decide whether to build a real lexer (positions + EOF) - see the register - and keep
tokenization quote-aware.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| LEX-NO-POSITIONS | UNIVERSAL: tokens carry NO source position (line/col) and there is NO EOF token in any language (Python tuples `parser.py:51`; PHP arrays `Frond.php:530`; Ruby tuples `frond.rb:602`; Node tuples `engine.ts:274`). So NO lexical/parse/runtime error can ever be POSITIONED - the prior docs' "positioned error" contract is unbuildable on this token shape. The unverified positions cells resolve to ABSENT. | Decide (LEX-DEC-01): add source positions (line/col) to tokens + an EOF token in all four, so errors can point at a line - the foundation for the parser's positioned-error contract (49) and a real compiler (50). |
| LEX-STRING-DELIMITER | UNIVERSAL: the tokenizer is NOT quote-aware - a `%}`/`}}` inside a quoted string in a tag (e.g. `{% if x == "%}" %}`) mis-terminates the tag (non-greedy regex py/ruby/node, `strpos` php `Frond.php:538`). | Make the tag scan quote-aware in all four. |
| LEX-UNTERMINATED-SILENT | UNIVERSAL: an unterminated `{{`/`{%` becomes literal TEXT with no error and no position, in all four. | Raise a positioned lexical error on an unterminated delimiter (depends on LEX-NO-POSITIONS). |
| LEX-TRIM-STAGE-DIVERGE | The whitespace-trim STAGE diverges: Python parser, PHP lexer, Ruby/Node inline-at-render. The prior doc's "trim is a parse concern" holds only for Python. | Unify the trim stage across the four (a lexer or parser stage, once). |
| LEX-NO-MODULE | UNIVERSAL, by design: no distinct lexer MODULE - tokenization is embedded (in the parser file for Python, the engine for PHP/Ruby/Node). Not a defect, but it means "the lexer" is not a separable unit today. | Decide whether to extract a real lexer stage (with LEX-DEC-01) or document that tokenization is embedded. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- LEX-DEC-01 (proposed): decide whether Frond gets a REAL lexer stage - tokens with source positions (line/col)
  and an EOF token - so lexical, parse (49), and runtime (51) errors can be POSITIONED (today none can, in any
  language). This pairs with the owner's compiler decision (50): a positioned token stream makes a real
  compiler and real diagnostics worthwhile.
- LEX-DEC-02 (proposed): make the tokenizer quote-aware (LEX-STRING-DELIMITER), raise on an unterminated
  delimiter (LEX-UNTERMINATED-SILENT), and unify the whitespace-trim stage (LEX-TRIM-STAGE-DIVERGE), all four.

## Proposed conformance fixture

A shared fixture: a `{% if x == "%}" %}` tokenizes correctly (catches LEX-STRING-DELIMITER); an unterminated
`{{` raises a positioned error (after LEX-DEC-01); whitespace-control trims identically across the four.

## Integration map

- Consumers: the parser (49) / interpreter (51). Composes: nothing upstream.

## Breaking changes and migration

- Adding positions is additive to the token shape (internal). Making the scan quote-aware and raising on
  unterminated delimiters changes behaviour for currently-mis-tokenized templates - a correctness fix, note it.

## Porting capsule

Tokenize template source into TEXT/VAR/BLOCK/COMMENT tokens, extracting `{% raw %}` first. Carry a source
position (line/col) on every token and emit an EOF token (none of the four do this today - it is the
foundation for positioned errors and a real compiler). Make the tag scan quote-aware (a `%}` inside a string
must not terminate the tag). Apply whitespace-control trim at ONE agreed stage. Raise a positioned error on an
unterminated delimiter, not silent TEXT.

## Audit closure checklist

- [x] Boundary and public surface complete (embedded tokenizer x four).
- [x] Lifecycle and producer/consumer edges complete (raw-extract -> scan -> emit).
- [x] Configuration (none), failure (unterminated/quote-blind) and security rules complete.
- [x] Wire (token list) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (no positions/EOF anywhere; trim-stage diverges).
- [x] Owner ambiguities decided (LEX-DEC-01 positions/lexer, LEX-DEC-02 quote-aware/unify).
- [x] Conformance fixture (quote-aware + positioned error) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
