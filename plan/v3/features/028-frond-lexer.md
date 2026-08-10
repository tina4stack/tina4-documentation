# Feature 028: Frond lexer

## Identity and status

- Matrix identity: 28 - tokenize Frond syntax
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-07-28, previously bundled with Features 29-31
- Existing decision: ADR-0009
- Shared historical oracle: `frond_expression_corpus.txt`, 82 cases

The historical audit treated lexer, parser, compiler and runtime as one row.
That is no longer a valid completion shape. Feature 28 owns source tokenization,
token positions, lexical errors, whitespace controls and the token stream
passed to Feature 29. It does not own AST construction, compilation, execution
or filters.

Python was the only port with partially separated Frond units. PHP had two
large files; Ruby and Node each held the whole engine in one file. ADR-0009
therefore requires a removable Frond folder and an explicit lexer unit behind
the unchanged public `Frond` entry point.

The standalone audit must add lexer-specific fixture cases and prove identical
tokens/errors across all current ports before this packet can be called final.
