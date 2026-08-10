# Feature 029: Frond parser

## Identity and status

- Matrix identity: 29 - build a Frond abstract syntax tree
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-07-28, previously bundled with Features 28, 30 and 31
- Existing decision: ADR-0009
- Shared historical oracle: `frond_expression_corpus.txt`, 82 cases

Feature 29 owns the deterministic conversion from Feature 28 tokens into an
AST, including precedence, nesting, source spans and parse errors. It does not
own tokenization, executable generation, runtime context or filters.

The historical bundle found that only Python exposed a recognizable parser
boundary. PHP, Ruby and Node mixed parsing with compilation or evaluation. The
3.14 audit must define one language-neutral AST contract and adversarial parse
fixture before any structural parity claim is accepted.
