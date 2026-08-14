# Feature 135: App-facing LLM client

## Identity and status

- Matrix identity: 135 - App-facing LLM client (`Ai.chat` / `Ai.embed` from application code)
- Audit state: approved for 3.13.101 implementation (GREENFIELD - not yet written in any of the four frameworks)
- Audit note: this is a DESIGN spec, not an audit of shipped code. There is no LLM client today (see
  `plan/v3/AI-SURFACE-MAP.md`, commit `4e78642`): only feature-108 AI-tool integration, a DEV-only
  `/ai/api/chat` verbatim proxy to `TINA4_AI_URL`, the Rust agent proxy, and MCP (inbound tools). The design
  below reuses the existing `TINA4_AI_*` wire conventions so the contract does not change, resolves the
  known issues carried in the prior design (`TINA4_AI_TIMEOUT` overload, fragile JSON parsing), and holds to
  the zero-dependency and secure-by-default mandates. Written 2026-08-11.
- Dependencies: the language stdlib HTTP + JSON only (NO provider SDK - zero-dep mandate); the existing
  `TINA4_AI_*` env family; the framework `Log` (for redacted diagnostics).
- Dependants: application routes, models, and services that want a completion / embedding; optionally the
  dev-admin chat panel (which could be re-pointed at the client instead of its verbatim proxy).
- Governing ADR: ADR-0053 (accepted 2026-08-14); shared fixture: `ai_client_contract.json`.

- Catalog phase: AI (application capability)

## Why this feature exists

A Tina4 application should be able to call an LLM as easily as it calls the database: one import, one method,
a normalized reply. Today it cannot - the only chat path is a dev-gated proxy that forwards bytes verbatim to
an external server, with no provider abstraction, no error handling, and no key management, and it does not
exist in production. This feature adds the missing library: a public `Ai` client that app code calls to get
a chat completion or an embedding, backed by the local OpenAI-compatible server the ecosystem already assumes
or by hosted OpenAI / Anthropic, with one uniform surface and one uniform response.

## Boundary

This packet owns the app-facing client: the `Ai` surface, the provider adapters, the config resolution, the
error taxonomy, response normalization, and streaming. It does NOT own the dev-admin proxy (feature 127, a
separate dev tool), the AI-tool integration (feature 108, skills/context), MCP (feature 101, inbound tools),
or the Rust coding agent (a separate process). It is the OUTBOUND client the framework has been missing.

## Existing surface and the gap

- Existing (per the map): `TINA4_AI_URL` (default `http://localhost:11437/api/chat`, OpenAI-compatible),
  `TINA4_AI_MODEL`, `TINA4_EMBED_URL` (`.../api/embeddings`), `TINA4_VISION_URL`, `TINA4_IMAGE_URL` - all
  read only by the dev-admin proxy/probes; no public app-facing consumer. The assumed wire shape is an
  OpenAI-compatible chat + embeddings API.
- The gap: a public client. Nothing lets a route do `reply = Ai.chat([...])`. This design fills exactly that,
  reusing the env conventions above so no wire contract changes.

## Public surface contract

One client class, `Ai` (Python master; `Ai`/`AI` per language casing). Static/instance methods:

- `Ai.chat(messages, *, model=None, temperature=None, max_tokens=None, stream=False, timeout=None,
  provider=None) -> ChatResponse` - a chat completion. `messages` is a list of `{role, content}`
  (OpenAI-style: `system`/`user`/`assistant`). Returns a normalized `ChatResponse`.
- `Ai.complete(prompt, **opts) -> str` - convenience for a single-turn prompt (wraps `chat` with one `user`
  message, returns `.text`).
- `Ai.embed(text_or_texts, *, model=None) -> list[float] | list[list[float]]` - an embedding (single or
  batch), via `TINA4_EMBED_URL`.
- Streaming: `Ai.chat(..., stream=True)` returns an iterator/async-generator of text deltas.
- Extensions (later, matching the existing URLs): `Ai.vision(...)` / `Ai.image(...)`. Not in the MVP.

`ChatResponse` normalizes every provider to `{text, model, usage: {prompt_tokens, completion_tokens,
total_tokens}, finish_reason, raw}`.

Naming decision (AILLM-DEC-01): the app-facing client is `Ai` (matching the `TINA4_AI_*` env). Feature-108's
CLI-facing install functions keep their current home; the app client is a distinct class so the two do not
collide.

## Inputs and outputs

- Input: messages/prompt/text, optional per-call overrides (model, temperature, max_tokens, stream, timeout,
  provider), and the `TINA4_AI_*` config. Output: a `ChatResponse` (or a delta stream, or an embedding
  vector). Errors are raised as a typed `AiError` (never a raw provider blob).

## Lifecycle and operation graph

1. Resolve config (provider, base URL, model, key, timeouts) from the per-call args then env then defaults.
2. Build the provider-specific request (headers, body) for `local` / `openai` / `anthropic`.
3. Send over stdlib HTTP with the connect + total timeouts set; on a transient pre-response failure, retry
   with bounded backoff.
4. Parse + normalize the provider response (or the SSE delta stream) into `ChatResponse` (or yielded deltas).
5. Raise a typed error on config/timeout/HTTP/parse failure, with the API key redacted everywhere.

## Configuration and precedence

Per-call arg > env > default. Env (reusing the existing family, adding the missing pieces):

- `TINA4_AI_PROVIDER` = `local` | `openai` | `anthropic` (default `local`, or inferred from the URL/host).
- `TINA4_AI_URL` (base; default `http://localhost:11437` OpenAI-compatible). `TINA4_EMBED_URL` /
  `TINA4_VISION_URL` / `TINA4_IMAGE_URL` for those capabilities.
- `TINA4_AI_MODEL` (default model).
- `TINA4_AI_KEY` (API key; required for `openai`/`anthropic`, unused for a keyless `local`).
- TIMEOUTS (resolving the overload - AILLM-DEC-03): `TINA4_AI_TIMEOUT` = the TOTAL request timeout in
  seconds (default e.g. 60); `TINA4_AI_CONNECT_TIMEOUT` = the connect timeout (default e.g. 10). The old
  design overloaded one var for both - this defines each with one clear meaning.
- `TINA4_AI_MAX_RETRIES` (default e.g. 2; transient only).

## Failures, side effects and security

Security is the load-bearing part of this feature:

- KEY HANDLING: `TINA4_AI_KEY` is read from env only, NEVER logged, NEVER echoed in an error message, and
  NEVER surfaced by any dev endpoint. (Feature 127 found the dev overlay/file endpoints can leak `.env`;
  the client must not add another leak - redact the key in every log line and error, and it must never enter
  the request-inspector or the error overlay.)
- FAIL CLOSED: a provider that requires a key (`openai`/`anthropic`) with no `TINA4_AI_KEY` raises
  `AiConfigError` immediately - it never sends an unauthenticated request or silently degrades.
- TLS: certificate verification ON by default; an opt-out (if any) is explicit and per-call, mirroring the
  `send_request` SSL policy (never a silent global ignore).
- TIMEOUTS ALWAYS SET: both connect and total, so a call can never hang unbounded.
- RETRIES: bounded (`TINA4_AI_MAX_RETRIES`), with backoff, ONLY on transient pre-response failures (connect
  error, timeout-before-first-byte, HTTP 429 honouring `Retry-After`, 5xx). NEVER retry after streaming has
  begun, and never retry a call that may have already had a side effect at the provider.
- NO PROMPT/RESPONSE AT INFO: prompts and completions may carry PII; they are not logged at INFO. Only a
  redacted DEBUG line (or nothing) - configurable, off by default.

## Wire and persistence contract

No persisted state. The wire contract is per provider, normalized to `ChatResponse`:

- `local` / `openai`: `POST <url>/chat/completions` (or the configured path) with `{model, messages,
  temperature, max_tokens, stream}` + `Authorization: Bearer <key>` (openai); response
  `{choices: [{message: {content}, finish_reason}], usage}`; SSE `data:` deltas when streaming.
- `anthropic`: `POST /v1/messages` with `{model, max_tokens, messages}` + `x-api-key` + `anthropic-version`;
  response `{content: [{text}], stop_reason, usage: {input_tokens, output_tokens}}`; its own event stream.
- The normalizer maps all three (and their streaming forms) into the one `ChatResponse` shape. This is where
  the old "fragile JSON parsing" is fixed: a tolerant per-provider parser with explicit handling of missing
  fields, error bodies, and streaming deltas - never an assumption that a field exists.

## Providers and substitutability

Three provider adapters behind one interface (build_request + parse_response + parse_stream): `local` (the
OpenAI-compatible server, default), `openai`, `anthropic`. Adding a provider = one adapter + a
`TINA4_AI_PROVIDER` value. Each adapter is a small pure mapper; the transport (stdlib HTTP) and the retry/
timeout/error machinery are shared. ZERO new dependencies (AILLM-DEC-06): hand-rolled HTTP + JSON per
language (`urllib`/`Net::HTTP`/`fetch`/PHP streams), NOT the openai/anthropic SDKs - the same discipline the
rest of the framework holds.

## Design decisions (the owner calls to finish)

| ID | Decision | Proposed resolution |
| --- | --- | --- |
| AILLM-DEC-01 | The public surface + name. | `Ai` client class with `chat` / `complete` / `embed` (+ `vision`/`image` later); a normalized `ChatResponse`. Distinct from feature-108's install functions. |
| AILLM-DEC-02 | The provider set + selection. | `local` (default) + `openai` + `anthropic`, selected by `TINA4_AI_PROVIDER` (or inferred from the URL). One adapter each. |
| AILLM-DEC-03 | The timeout contract (resolve the overload). | `TINA4_AI_TIMEOUT` = total; `TINA4_AI_CONNECT_TIMEOUT` = connect. Both always set. One clear meaning each. |
| AILLM-DEC-04 | Security posture. | Key from env only, never logged/echoed/inspected; fail-closed on a missing required key; TLS on; bounded transient-only retries; no prompt/response at INFO. |
| AILLM-DEC-05 | Streaming contract. | `stream=True` yields uniform text deltas parsed per provider; NEVER retry once a stream has started. |
| AILLM-DEC-06 | Dependencies. | Zero: hand-rolled HTTP + JSON per language; no provider SDK. |
| AILLM-DEC-07 | Conformance fixture (no mocks). | A REAL local HTTP server (a socket server returning provider-shaped JSON: success, 429+Retry-After, 500, malformed body, SSE stream, connect-timeout) driving the real client over real sockets; plus a `REQUIRE_SERVICES`-gated real-provider smoke (a live OpenAI-compatible server). No in-process doubles of the client's collaborator. |
| AILLM-DEC-08 | Parity + order. | Build the Python master first (it owns internal API design), lock the contract with the fixture, then port PHP/Ruby/Node to the identical surface + env + response shape. |

## Owner decisions

- AILLM-DEC-01..08 were approved for 3.13.101 and ratified by ADR-0053 on 2026-08-14.
- `embed` is included in 3.13.101. `vision` and `image` are deferred.
- The unimplemented tina4-python#109 `Llm.ask`/`ask_json` proposal does not create a second public API.

## Proposed conformance fixture

A shared, per-language fixture driving a REAL local HTTP server (no client doubles):

1. Happy path: a chat call against a socket server returning an OpenAI-shaped body -> `ChatResponse.text`
   matches; usage parsed.
2. Anthropic shape: the same call against an Anthropic-shaped body normalizes identically.
3. Streaming: `stream=True` against an SSE server yields the concatenated deltas equal to the non-streaming
   text.
4. Transient retry: a server that returns 429+`Retry-After` once then 200 succeeds within
   `TINA4_AI_MAX_RETRIES`; a 500-always server exhausts retries and raises `AiHTTPError`.
5. Timeout: a slow server trips `TINA4_AI_TIMEOUT` and raises `AiTimeoutError` (bounded, no hang).
6. Fail-closed: `provider=openai` with no `TINA4_AI_KEY` raises `AiConfigError` and sends NOTHING.
7. Key redaction: a forced `AiHTTPError` and any DEBUG log line contain NO substring of the key.
8. Malformed body: a non-JSON / missing-field response raises `AiParseError`, not a crash.
9. `REQUIRE_SERVICES=ollama`-gated: a real local OpenAI-compatible server returns a real completion.

## Integration map

- Consumers: application routes/models/services (`Ai.chat`/`embed`); optionally re-point the dev-admin chat
  panel at the client (so dev + app share one path) - but the client itself is app-facing and works in
  production, unlike the dev proxy.
- Config: the `TINA4_AI_*` env family (reused + the new timeout/provider/key vars).
- Related: feature 108 (AI-tool integration, unrelated install path), feature 101 (MCP, inbound), feature
  127 (the dev proxy this REPLACES for app use; and its `.env`-leak finding informs the key-redaction rule).

## Breaking changes and migration

- Additive: a new public client. The only contract touched is the `TINA4_AI_*` env family, extended (not
  changed) - existing `TINA4_AI_URL`/`_MODEL` keep their meaning; `TINA4_AI_TIMEOUT` is given ONE clear
  meaning (total) which the prior fragile design lacked (document it as the definition, not a change).

## Implementation backlog

1. Python master: the `Ai` client (chat/complete/embed), the three provider adapters, config resolution, the
   error taxonomy, response + stream normalization, secure key handling.
2. The no-mock fixture (real local HTTP server) covering the nine cases above; lock the contract.
3. Port to PHP, Ruby, Node at identical surface/env/response; run the shared fixture against all four.
4. Optional follow-up: `vision`/`image`; re-point the dev-admin chat panel at the client.

## Porting capsule

A clean-room build needs: one `Ai` client (`chat`/`complete`/`embed`, streaming) returning a normalized
`ChatResponse`; three provider adapters (local OpenAI-compatible default + OpenAI + Anthropic) behind one
interface, transport-shared; config resolved per-call > env > default with a CLEAR dual-timeout contract
(`TINA4_AI_TIMEOUT` total, `TINA4_AI_CONNECT_TIMEOUT` connect); secure-by-default key handling (env only,
never logged/echoed/inspected, fail-closed on a missing required key, TLS on, transient-only bounded
retries, no PII at INFO); a tolerant per-provider JSON/SSE normalizer that never assumes a field; ZERO new
dependencies (hand-rolled HTTP + JSON); and a real-server no-mock fixture. Build Python first, lock the
contract, then port to identical surfaces. Do NOT reuse the dev-admin verbatim proxy as the client - it is
dev-gated and does none of this.

## Audit closure checklist

- [x] Boundary and public surface complete (the `Ai` client + `ChatResponse`).
- [x] Lifecycle and every producer/consumer edge complete (resolve -> build -> send -> normalize -> raise).
- [x] Configuration, failure, side-effect and security rules complete (key handling, fail-closed, timeouts,
  retries, no-PII).
- [x] Wire/persistence (the three provider shapes + the normalizer) and provider contracts complete.
- [x] Greenfield design + the gap it fills recorded (points at AI-SURFACE-MAP.md).
- [x] Owner ambiguities decided and recorded (AILLM-DEC-01..08 + the MVP-scope open question).
- [x] Proposed conformance fixture (nine real-server cases) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered (Python first, fixture, then port).
- [x] Porting capsule sufficient.
