# Feature 143: AI harness - local model server, registration, dev-admin assist

## Outcome

A developer runs a local model on their own machine, registers a free profile,
and the AI harness then appears inside dev-admin: paste a screen image to a Frond
template, tweak a template with vision of the preview, assist on a file (ORM <->
CRUD stubs), and fill scaffold stubs. The model runs locally (private, free); the
registered Tina4 services unlock the harness. The model is NEVER embedded in the
Rust binary - the binary points at a local server.

## Components

| # | Component | Home | Status |
|---|---|---|---|
| A | Local AI server - a Tina4 app (no FastAPI/Flask), vendored engine (MLX / CUDA / CPU), noauth, :11437. Speaks the **Ollama-native protocol**: `/api/chat` (messages, `think` on/off, inline `images` vision, NDJSON `stream`, `<think>` split) and `/api/generate` (incl. **`raw:true` untemplated** FIM/exact prompts) - plus the original `/generate` `/describe` `/health` `/info` `/memory`. STRAIGHT PASS-THROUGH: messages + options go to the model as sent, NO prompting/system-injection/defaults in the stack (engine got a `raw_prompt` kwarg) | `tina4-documentation/examples/ai-server/` | DONE + VERIFIED live: chat/think/vision/stream, caller system prompt reaches the model, `raw` gives a true continuation - all through the gateway to the Tina4 model, and Ollama interchangeable |
| B | Hosted installer - `curl -fsSL https://tina4.com/ai-server.sh \| sh` downloads the bundle and runs it (install deps -> download model -> `tina4 serve`) | `tina4-documentation/docs/public/ai-server.sh` + `ai-server.tar.gz` (+ `scripts/pack-ai-server.sh`) | DONE, verified (extract + boot) |
| C | Rust CLI auth - `tina4 login` / `register` / `whoami` / `logout` via GitHub, against profile.tina4.com; file-based token store. PLUS the portal device-grant routes (`/api/cli/auth/start`, `/poll`, `/cli`, `/cli/approve`) | `tina4` (`src/auth.rs`) + profile-portal (`aatos/aatos-code/profile-portal`) | DONE + VERIFIED END-TO-END: real CLI `tina4 login` drove the live portal (local SQLite) through approve -> token -> `whoami`, 202/200/410 all correct, token minted the same way as `/api/token`. Prod deploy of the routes = commit to aatos -> CI image -> Flux |
| D | **`tina4 ai serve`** - the local LLM GATEWAY (axum, `src/ai_gateway.rs`): the single door dev-admin talks to. Registration-gated; fails fast unless signed-in AND a backend answers HTTP; wildcard `/api/*` proxy; streams the reply; auto-detects backend (ai-server :11437 -> Ollama :11434, `TINA4_AI_BACKEND_URL` override); idempotent singleton on :11435 | `tina4` (Rust CLI) | DONE + VERIFIED: both fail-fast paths exit 1; happy path streams **vision + thinking** through to Ollama live; `x-tina4-ai-backend` tags the backend. axum cost **+0.41 MB** (12.35 -> 12.76 MB). ai-server `/api/chat` adapter still owed for the Tina4-model backend |
| D2 | dev-admin repointed OFF the model, onto the gateway: every AI default (`TINA4_AI_URL`/vision/embed/image, the proxy, the plan generator) now defaults to `:11435`, in ALL FOUR frameworks | each `dev_admin`/`plan` | DONE. App-facing `Ai` client (`AI.php`/`ai_client.rb`/`aiClient.ts`/`client.py`) still defaults to :11437 - a separate app-code surface, left by design (open: route apps through the gateway too?) |
| E | dev-admin shows the harness ONLY when (server port 11437/Ollama 11434 open) AND (registered); a dashboard **"Activate local AI"** button runs the detect -> register-if-needed -> toggle-on flow and shows status | each framework's `dev_admin` + SPA bundle | TODO; the latest shared SPA bundle (911648 b, commit 8e8e47e) is now deployed to ALL FOUR frameworks (was Python-only) as the base for the button; port probe is a plain TCP/health check |
| F | The four capabilities: image->Frond, preview-vision + click-to-element, ORM/CRUD stub-fill, scaffold-fill | SPA `tina4-dev-admin` + each `dev_admin` | TODO (the actual harness) |

## Decisions (settled)

- Port **11437** for the local AI server - NOT Ollama's 11434, so Ollama runs
  alongside, and it is already the dev-admin `TINA4_AI_URL` default, so a project
  reaches it with the least config.
- The inference engine is **vendored** into the example (`lib/ai_engine/`), a
  snapshot of the tina4-harness model code - the server clones nothing, and we do
  NOT clone andrevanzuydam/tina4-harness.
- Tina4 serves it; no FastAPI, no Flask. The built-in asyncio server is pinned on.
- Routes are `noauth` (a local server, no login to reach the model). A signing
  secret is still needed to boot, so setup generates one into `.env.local`.
- Auth uses **GitHub** as the mechanism; the registration portal is
  profile.tina4.com (already referenced by `TINA4_MCP_TOKEN`).

## Auth contract (DEFINED here; profile.tina4.com must implement to match)

Chosen flow: **browser handoff + poll** (like `gh`/`vercel`). profile.tina4.com
owns the GitHub OAuth app and signs the user in server-side; the CLI never holds a
client secret. GitHub is the identity; profile.tina4.com mints the Tina4 token.

CLI building blocks (already in the binary): reqwest (async) + serde + tokio; HOME
resolved as in `doctor.rs`; browser opened by shelling out (`open` / `xdg-open` /
`cmd /c start`); no new crate needed. Base URL overridable via `TINA4_PROFILE_URL`
(default `https://profile.tina4.com`).

- `POST /api/cli/auth/start` body `{ "mode": "login" | "register" }` ->
  `{ request_id, verification_uri, user_code, poll_interval, expires_in }`.
- CLI opens `verification_uri`, prints it + `user_code` as a fallback.
- `POST /api/cli/auth/poll` body `{ request_id }` -> `202 { "status": "pending" }`
  until the user finishes, then `200 { token, login, profile_url }`; `410` on expiry.
- Token stored at `~/.config/tina4/credentials.json` (mode 0600;
  `%APPDATA%\tina4` on Windows): `{ token, login, profile_url }`.
- `tina4 whoami` reads it (add `--json` for dev-admin to call); `tina4 logout`
  deletes it.

**Status:** the CLI side is BUILT (`src/auth.rs`, commands wired in `main.rs`):
`cargo build` clean, 5 pure unit tests pass (config-dir resolution, credentials
round-trip, start-response defaults, done-payload parse, `TINA4_PROFILE_URL`
override), and the non-network paths are proven on the built binary -
`whoami`/`whoami --json` (exit 1, `{"authenticated":false}`), `logout`, and a
`login` against an unreachable portal failing gracefully (exit 1). The ONLY
unproven path is the happy-path handshake, which needs profile.tina4.com's two
routes to exist. Nothing is claimed green there until they do.

## dev-admin gate (E) uses the same token + an Activate button

The harness shows in dev-admin only when BOTH hold: a probe of `:11437` (or Ollama
`:11434`) answers, AND `tina4 whoami --json` reports a valid profile. Both are
cheap, local checks; neither blocks the dashboard when absent.

The dashboard carries an **"Activate local AI"** button. Pressed, it:
1. probes the local model port; if nothing answers, it shows the one-line install
   (`curl ... ai-server.sh | sh`, or "start Ollama") and keeps the button amber;
2. checks `tina4 whoami`; if not registered, it opens the `tina4 login` flow (or
   links profile.tina4.com) and waits;
3. once both pass, flips the harness panel on (green) for this project.

The button is the single, obvious entry point - no .env editing to "reach" the
server. It lives in the shared SPA so all four frameworks get it at once.

## Streaming is unbroken end to end (Python verified)

The dev-admin proxy (`_api_ai_proxy`) no longer forces `stream:false`/buffers. It
now honours the caller's `stream` flag and RELAYS the gateway's NDJSON line by
line (urllib read on a worker thread -> async queue -> `response.stream`), since
the built-in asyncio server chunks reliably. VERIFIED: 212 frames arriving
progressively (first @0.05s, last @1.22s) model -> gateway -> proxy -> client.
PARITY OWED: `tina4-php/Tina4/DevAdmin.php` still forces `stream:false`
(`:1406`); Ruby/Node proxies to re-check and match.

## The dev-admin <-> tina4-client protocol (standardized)

One wire format across the whole chain: **Ollama-native `/api/*` over HTTP**
(`{model, messages, stream, options}`, `images:[b64]` inline, NDJSON stream back).
dev-admin speaks it to the gateway; the gateway speaks it to the backend. So
dev-admin holds NO model endpoint and no model-specific logic - it just talks to
`:11435`. Swapping Ollama for the Tina4 model server (or a shared vLLM) is a
backend change behind the gateway, invisible to dev-admin. The gateway tags each
reply with `x-tina4-ai-backend` so the dashboard can show which model answered.

## Deployment tiers (single vs shared) - concurrency is the axis

The model backend is swappable behind one contract (`/api/chat`, and OpenAI
`/v1/chat/completions`), so dev-admin changes tier by changing `TINA4_AI_URL`, not
code:

- **Per-developer, local:** MLX (Apple Silicon) or Ollama (Windows). Generation is
  effectively ONE at a time (MLX serializes on a lock; Ollama's parallelism is low
  by default). Tiny VRAM, reachable on an ordinary laptop. This is the tested tier.
- **Shared / team server:** **vLLM** on Linux + NVIDIA (or WSL2). Its continuous
  batching + PagedAttention run many concurrent sequences (`--max-num-seqs`,
  tensor-parallel across GPUs), so one box serves many developers/projects at high
  AGGREGATE throughput instead of a queue. This is the concurrency ("threads") tier
  and what "multiple Tina4 projects share one server" wants at scale. vLLM is
  Linux/NVIDIA only - not native Windows, CPU-only on a Mac - so it is a shared-box
  role, never the per-laptop one.

## Windows falls back to Ollama (one contract everywhere)

vLLM can't run natively on Windows (Triton + NCCL are Linux-only, wheels are
manylinux, workers assume fork), so Windows uses **Ollama** - native, GPU-auto,
one-click. To keep dev-admin's code path identical on every OS, the local LLM is
reached by ONE contract, Ollama's `/api/chat` (which dev-admin's `TINA4_AI_URL`
already defaults to):

- macOS / Linux: the Tina4 `ai-server` on `:11437`, which should also expose an
  **Ollama-compatible `/api/chat`** (alongside `/generate`), so it is a drop-in
  for Ollama.
- Windows: Ollama on `:11434`. dev-admin just points `TINA4_AI_URL` there.

### Model defaults (measured on Apple Silicon, this machine)

| Model | Runtime | VRAM | Speed | vision+thinking |
|---|---|---|---|---|
| Qwen3.8-2B-Distill (2B, 4-bit) | MLX/Metal | ~1.7 GB | 212 tok/s | yes |
| qwen3-vl:2b (num_ctx 4096) | Ollama | ~2.0 GB | 191 tok/s | yes |
| qwen3-vl:4b (num_ctx 4096) | Ollama | 3.5 GB | 104 tok/s | yes |
| qwen3-vl:4b (num_ctx 32k, default) | Ollama | 8.0 GB | 104 tok/s | yes |

Defaults: Apple Silicon/Linux -> the MLX distill; Windows -> **Ollama
`qwen3-vl:2b` with `num_ctx=4096`** (~2 GB, keeps vision+thinking). The 32k default
context is what blows Ollama's VRAM up to 8 GB, so the harness pins a modest
context.

**Reach over marginal quality (owner's call).** The SMALL distill is the default
because ~2-3 GB VRAM runs on an ordinary laptop. A larger model (qwen3-vl:4b and
up) gives better answers but is out of reach for most computers, so it is an
OPTIONAL upgrade a capable machine can select - never a requirement. Flagship
distill verified end to end: thinking (a `<think>` block then the answer), vision
(reads an image), 211 tok/s, 1.6 GB weights / 2.7 GB peak with an image.

So the fallback is a URL swap, not a second code path. The port probe in (E)
becomes "is `:11437` open, else is `:11434` (Ollama) open?". Open task: add the
`/api/chat` (and optionally OpenAI `/v1/chat/completions`) adapter route to the
ai-server so the Tina4 server and Ollama are interchangeable. Verifiable on macOS
now; this is the next concrete, testable step.

## Parity

| Piece | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| E. dev-admin harness gate | [ ] | [ ] | [ ] | [ ] |
| F. capabilities (shared SPA + adapters) | [ ] | [ ] | [ ] | [ ] |

(A and B are framework-agnostic, in tina4-documentation. C and D are the Rust CLI.)

## Status: A + B shipped to the docs repo (uncommitted); C blocked on the auth contract
