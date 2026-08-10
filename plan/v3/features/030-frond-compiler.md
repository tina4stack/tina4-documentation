# Feature 030: Frond compiler

## Identity and status

- Matrix identity: 30 - compile a Frond AST to executable form
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-07-28, previously bundled with Features 28, 29 and 31
- Existing decision: ADR-0009
- Shared historical oracle: `frond_expression_corpus.txt`, 82 cases

Feature 30 owns conversion of the Feature 29 AST into the language's executable
template representation. It owns compile-time validation and cacheable compiled
identity, but not tokenization, parsing, runtime context or filter definitions.

The historical bundle found a partial compiler boundary in Python and PHP and
no clean boundary in Ruby or Node. The standalone audit must pin compilation
errors, stable output identity and the interface consumed by Feature 31 before
the four implementations are reorganized.
