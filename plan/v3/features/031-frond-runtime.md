# Feature 031: Frond runtime

## Identity and status

- Matrix identity: 31 - execute compiled Frond templates with context
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-07-28, previously bundled with Features 28-30
- Existing decision: ADR-0009
- Shared historical oracle: `frond_expression_corpus.txt`, 82 cases

Feature 31 owns execution of Feature 30 output: context lookup, scopes,
inheritance state, macro/block calls, runtime errors and rendered bytes. Filters,
escaping, sandboxing and caches keep their own numbered contracts.

The historical audit measured the largest Frond complexity in runtime-like
evaluation paths, including Node's `evalVarInner` at cyclomatic complexity 74.
The standalone audit must establish observable runtime behavior and resource
bounds before structural or performance work begins.
