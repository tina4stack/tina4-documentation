# AI surface map (precursor to the LLM-client feature)

Measured 2026-08-11 from the shipped source, to decide what a first-class "use an LLM from app code"
feature would add. Python master `tina4_python` (`feature/csrf-fail-closed` HEAD `ebbab30`); parity for the
inventoried surfaces confirmed by the feature-101 (MCP), feature-108 (AI-tool integration), and feature-127
(dev-admin) audits, all decision-ready. This is a MAP, not a feature audit; it feeds the design decision for
a new feature (proposed 135) rather than proposing code here.

## The headline

There is NO app-facing LLM client in any of the four frameworks. App code today cannot call an LLM
(`chat` / `complete` / `embed`) through a public framework API. Every AI capability that exists is either a
DEV-only proxy to an external AI server, an AI-tooling integration (skills/MCP), or scaffolding - none is a
library an application route or model can call to get a completion. A grep of the Python master for a public
`chat`/`complete`/`LLMClient`/`OpenAI`/`Anthropic` surface returns nothing.

## Inventory of existing AI surfaces

| # | Surface | What it is | App-facing? | Files (Python) |
| --- | --- | --- | --- | --- |
| 1 | AI-tool integration (feature 108) | Installs the six Tina4 skills + context files (`CLAUDE.md`/`AGENTS.md`/`.mcp.json`) for Claude/Codex/Cursor. Its only network call is `urllib` fetching skill bodies from GitHub raw. | NO (a build/setup step) | `tina4_python/ai/__init__.py` |
| 2 | External-AI-server proxy (dev only) | `/ai/api/chat` forwards the request body VERBATIM to `TINA4_AI_URL` (default `http://localhost:11437/api/chat`); `/vision`, `/embed`, `/rag`, `/image` are URL/health probes to the same external server. Gated behind `TINA4_DEBUG`; used by the dev-admin SPA for chat/FIM. | NO (dev-admin only, verbatim passthrough) | `tina4_python/dev_admin/__init__.py` (`_api_ai_proxy`, `_api_chat`, service probes) |
| 3 | Agent / supervisor proxy (dev only) | `/__dev/api/supervise/{create,sessions,diff,commit,cancel}` + `/__dev/api/execute` proxy to the Rust AGENT server at `port + 2000` (the "Code With Me" coding agent). | NO (dev-admin only) | `dev_admin/__init__.py` (`_proxy_to_supervisor`, `_supervisor_base_url`) |
| 4 | MCP server (feature 101) | Exposes framework tools (database, files, docs, plan, project index) to an AI assistant over `/__dev/mcp`. It lets an EXTERNAL LLM call the framework, not the framework call an LLM. | NO (inbound tools) | `tina4_python/mcp/` |
| 5 | AI context scaffolding | `CLAUDE.md` / `.mcp.json` written by `setup`/`init`/`ai`. Static files, no LLM calls. | NO (scaffold) | `ai/__init__.py`, the CLI |
| 6 | The `tina4-coder` MCP (`tina4_context`/`tina4_code`) | A HOSTED external MCP server for grounding/generating Tina4 code. Not framework runtime code. | NO (external tooling) | (external) |

## Configuration that already exists (but has no app-facing consumer)

All of these point at EXTERNAL servers and are read only by the dev-admin proxy / probes, not by any public
app API:

- `TINA4_AI_URL` (default `http://localhost:11437/api/chat`) - the chat endpoint the dev proxy forwards to.
- `TINA4_AI_MODEL` - a model name, read for display/forwarding.
- `TINA4_EMBED_URL` (default `.../api/embeddings`), `TINA4_VISION_URL`, `TINA4_IMAGE_URL`, `TINA4_RAG_URL` -
  external service URLs surfaced by the dev-admin probes.
- `TINA4_AGENT_PORT` - the Rust agent server port (`port + 2000`).

The default `localhost:11437`/`11438` targets an external OpenAI-compatible local server (Ollama/qwen-class).
So the wire shape the ecosystem already assumes is "an OpenAI-compatible `/api/chat` + `/api/embeddings`".

## Parity note

The inventoried surfaces are parity-consistent across all four frameworks (per the 108/127 audits): the
AI-tool module (`ai/__init__.py`, `Tina4/AI.php`, `lib/tina4/ai.rb`, `packages/core/src/ai.ts`), the
dev-admin AI + agent proxies, and the `TINA4_AI_*` env family all exist in each. And in all four, NONE is an
app-facing LLM client. So the gap is uniform - a client would be a genuinely new, four-language feature, not
a port of something one language already has.

## The gap - what a first-class LLM client would add

A public, app-facing client that a route or model calls directly, for example:

- `Ai.chat(messages, model=..., ...) -> reply` (a chat/completion call)
- `Ai.embed(text) -> vector` (embeddings)
- optional streaming, and a vision/image variant matching the existing `TINA4_VISION_URL`/`TINA4_IMAGE_URL`

with a PROVIDER abstraction over (a) the existing OpenAI-compatible local server (`TINA4_AI_URL`), and (b)
hosted OpenAI / Anthropic; plus config (base URL, model, API key, timeout), retries, and robust JSON
parsing. It would turn the current dev-only verbatim proxy into a real client that also works in production
app code - reusing the `TINA4_AI_URL`/`TINA4_AI_MODEL` conventions already in place so the wire contract does
not change.

## Known design issues to resolve (from the prior LLM-client design)

Carried over so the design does not repeat them:

- `TINA4_AI_TIMEOUT` was overloaded to mean two different things (connect vs total) - the client must define
  one clear timeout contract (or two clearly-named vars).
- JSON parsing of provider responses was fragile - the client needs a robust parser that tolerates the
  shape differences between the OpenAI-compatible local server, OpenAI, and Anthropic (and streaming deltas
  vs a single body).
- Secure-by-default: an API key must never be logged or echoed (the dev-admin `.env` read finding in feature
  127 is a reminder), and the client must fail closed on a missing key rather than silently degrade.

## Recommended next step

Promote this to a decision-ready design for feature 135 (app-facing LLM client): specify the public surface,
the provider abstraction (local OpenAI-compatible + OpenAI + Anthropic), the config contract (resolving the
`TINA4_AI_TIMEOUT` overload), the security rules (key handling, fail-closed), the streaming contract, and a
real no-mock conformance fixture (drive a real local OpenAI-compatible server). Build it once, at parity,
across the four frameworks. Do NOT reuse the dev-admin verbatim proxy as the client - it is dev-gated and
does no provider abstraction, error handling, or key management.
