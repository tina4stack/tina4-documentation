# Feature 135 implementation: App-facing AI client (3.13.101)

Outcome: 3.13.101 ships one production-capable, zero-dependency `Ai` client at parity across Python, PHP, Ruby, and Node.js, with chat, completion, embeddings, and streaming. Vision and image generation remain deferred.

## Scope

- [ ] Accept ADR-0053 and add the shared `ai_client_contract.json` fixture.
- [ ] Build a real local HTTP conformance server shared by all four runners.
- [ ] Implement the Python reference: `Ai.chat`, `Ai.complete`, `Ai.embed`, provider adapters, normalized responses, streaming, configuration, retries, timeouts, and errors.
- [ ] Port the proven contract to PHP with idiomatic spelling only where the language requires it.
- [ ] Port the proven contract to Ruby with idiomatic spelling only where the language requires it.
- [ ] Port the proven contract to Node.js/TypeScript with idiomatic spelling only where the language requires it.
- [ ] Export the public API and document identical `.env` configuration in every framework.
- [ ] Update feature 135, the feature matrix, contract map, release notes, and versions for 3.13.101.
- [ ] Close tina4-python#109 only after the released four-way contract supersedes its narrower proposal.
- [ ] Commit approved work in each repository with the Tina4 co-author trailer.
- [ ] Tag and publish 3.13.101 only after the clean-room lab gate is green in all four frameworks.

## Parity

| Contract | Python | PHP | Ruby | Node.js |
|---|---:|---:|---:|---:|
| Public `Ai` API | ❌ | ❌ | ❌ | ❌ |
| OpenAI-compatible local/OpenAI adapter | ❌ | ❌ | ❌ | ❌ |
| Anthropic adapter | ❌ | ❌ | ❌ | ❌ |
| Normalized `ChatResponse` | ❌ | ❌ | ❌ | ❌ |
| Single and batch embeddings | ❌ | ❌ | ❌ | ❌ |
| Streaming text deltas | ❌ | ❌ | ❌ | ❌ |
| Env/override precedence and key safety | ❌ | ❌ | ❌ | ❌ |
| Timeout and retry contract | ❌ | ❌ | ❌ | ❌ |

## Tests

- [ ] Write every language runner before its implementation and prove it fails for the missing feature.
- [ ] Real socket: OpenAI-compatible chat normalizes text, model, usage, finish reason, and raw response.
- [ ] Real socket: Anthropic chat normalizes to the same response shape.
- [ ] Real socket: `complete` returns only normalized text and uses a single user message.
- [ ] Real socket: single and batch embeddings preserve input cardinality and numeric vectors.
- [ ] Real socket: OpenAI-compatible and Anthropic streams yield only ordered text deltas.
- [ ] Real socket: 429 honours `Retry-After`; transient 5xx retries are bounded; non-transient 4xx is not retried.
- [ ] Real socket: no retry occurs after the first streamed delta.
- [ ] Real socket: connect and total timeouts have distinct, bounded failure paths.
- [ ] Real socket: hosted providers with no key fail before sending; local provider works without a key.
- [ ] Captured request/log/error text never exposes the API key, prompt, or response body.
- [ ] Malformed JSON, malformed SSE, and missing provider fields fail consistently and never fabricate success.
- [ ] Per-call configuration overrides env, which overrides defaults.
- [ ] Mutation-proof every invariant, restore the mutation, and rerun the named suite.
- [ ] Run each full framework suite locally, then all four on the Linux lab as root with required services.

## Bugs

- [ ] None discovered yet.

## Commits

- Pending.

## Status: In Progress
