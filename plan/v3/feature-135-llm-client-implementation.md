# Feature 135 implementation: App-facing AI client (3.13.101)

Outcome: 3.13.101 ships one production-capable, zero-dependency `Ai` client at parity across Python, PHP, Ruby, and Node.js, with chat, completion, embeddings, and streaming. Vision and image generation remain deferred.

## Scope

- [x] Accept ADR-0053 and add the shared `ai_client_contract.json` fixture.
- [x] Build one real local socket conformance server per runner, driven by the shared contract.
- [x] Implement the Python reference: `Ai.chat`, `Ai.complete`, `Ai.embed`, provider adapters, normalized responses, streaming, configuration, retries, timeouts, and errors.
- [x] Port the proven contract to PHP with idiomatic spelling only where the language requires it.
- [x] Port the proven contract to Ruby with idiomatic spelling only where the language requires it.
- [x] Port the proven contract to Node.js/TypeScript with idiomatic spelling only where the language requires it.
- [x] Export the public API and document identical `.env` configuration in every framework.
- [x] Update feature 135, the feature matrix, contract map, release notes, and versions for 3.13.101.
- [ ] Close tina4-python#109 only after the released four-way contract supersedes its narrower proposal.
- [x] Commit approved work in each repository with the Tina4 co-author trailer.
- [ ] Tag and publish 3.13.101 only after the clean-room lab gate is green in all four frameworks.

## Parity

| Contract | Python | PHP | Ruby | Node.js |
|---|---:|---:|---:|---:|
| Public `Ai` API | ✅ | ✅ | ✅ | ✅ |
| OpenAI-compatible local/OpenAI adapter | ✅ | ✅ | ✅ | ✅ |
| Anthropic adapter | ✅ | ✅ | ✅ | ✅ |
| Normalized `ChatResponse` | ✅ | ✅ | ✅ | ✅ |
| Single and batch embeddings | ✅ | ✅ | ✅ | ✅ |
| Streaming text deltas | ✅ | ✅ | ✅ | ✅ |
| Env/override precedence and key safety | ✅ | ✅ | ✅ | ✅ |
| Timeout and retry contract | ✅ | ✅ | ✅ | ✅ |

## Tests

- [x] Write every language runner before its implementation and prove it fails for the missing feature.
- [x] Real socket: OpenAI-compatible chat normalizes text, model, usage, finish reason, and raw response.
- [x] Real socket: Anthropic chat normalizes to the same response shape.
- [x] Real socket: `complete` returns only normalized text and uses a single user message.
- [x] Real socket: single and batch embeddings preserve input cardinality and numeric vectors.
- [x] Real socket: OpenAI-compatible and Anthropic streams yield only ordered text deltas.
- [x] Real socket: 429 honours `Retry-After`; transient 5xx retries are bounded; non-transient 4xx is not retried.
- [x] Real socket: no retry occurs after the first streamed delta.
- [x] Real socket: connect and total timeouts have distinct, bounded failure paths.
- [x] Real socket: hosted providers with no key fail before sending; local provider works without a key.
- [x] Captured request/log/error text never exposes the API key, prompt, or response body.
- [x] Malformed JSON, malformed SSE, and missing provider fields fail consistently and never fabricate success.
- [x] Per-call configuration overrides env, which overrides defaults.
- [x] Mutation-proof every invariant, restore the mutation, and rerun the named suite (40/40 red, then all four restored green).
- [x] Run focused suites locally, then all four full suites on the Linux lab as root with required services.

### Linux release gate (2026-08-14)

| Framework | Exact commit | Result |
| --- | --- | --- |
| Python 3.13.3 | `a0e9cff` | 5,516 passed, 11 skipped, 0 failed |
| PHP 8.3.6 | `fa9af870` | 5,443 tests, 19,070 assertions, 0 failures, 10 skipped |
| Ruby 3.2.3 | `45df537` | 5,449 examples, 0 failures, 10 pending (ODBC DSN absent) |
| Node.js 24.18.0 | `69ba401` | 8,422 passed, 0 failed, 11 skipped (ODBC DSN absent); typecheck green |

## Bugs

- [x] PHP's case-insensitive class names collided with the existing developer installer. Renamed the installer to `AITools`; the app-facing client owns `AI`.
- [x] PHP 8.5 returned an empty TLS-wrapper error after a real handshake deadline. Classify the timeout from elapsed deadline evidence.
- [x] All four stream readers accepted EOF without `[DONE]`. They now fail loud and never retry after yielding a delta.

## Commits

- `8ab5bd7` documentation — approve Feature 135 and ADR-0053.
- `46a9234` Python — AI client plus native metrics handoff.
- `a0e9cff` Python — update the dev-admin handler count after removing the census route.
- `fa9af870` PHP — AI client plus native metrics handoff.
- `45df537` Ruby — AI client plus native metrics handoff.
- `69ba401` Node — AI client plus native metrics handoff.

## Status: Release-ready — exact-HEAD Linux gates green; tag and issue closure remain.
