# AI Client

One class. Three methods. No provider SDK.
The Tina4 AI client sends chat, completion, embedding, and streaming requests through one provider-neutral API.

This chapter covers the application-facing `Tina4::Ai` class. The `tina4 ai` command serves a different purpose: it installs Tina4 skills and context for coding assistants.

## Configure a provider

The client supports `local`, `openai`, and `anthropic`. Local mode targets an OpenAI-compatible endpoint and needs no API key.

```ini
TINA4_AI_PROVIDER=local
TINA4_AI_URL=http://localhost:11437
TINA4_AI_MODEL=llama3.2
TINA4_AI_TIMEOUT=60
TINA4_AI_CONNECT_TIMEOUT=10
TINA4_AI_MAX_RETRIES=2
```

Use the hosted OpenAI service by changing three values:

```ini
TINA4_AI_PROVIDER=openai
TINA4_AI_URL=https://api.openai.com/v1
TINA4_AI_MODEL=gpt-4o-mini
TINA4_AI_KEY=your-api-key
```

Anthropic uses the same keys:

```ini
TINA4_AI_PROVIDER=anthropic
TINA4_AI_URL=https://api.anthropic.com/v1
TINA4_AI_MODEL=claude-3-5-haiku-latest
TINA4_AI_KEY=your-api-key
```

An explicit method argument wins over the environment. The environment wins over the built-in default. This lets one request use another model without changing the rest of the process.

## Complete one prompt

`Tina4::Ai.complete` sends one user message and returns the response text.

```ruby
require "tina4"

answer = Tina4::Ai.complete("Explain why this query needs an index")
puts answer
```

Pass keyword arguments when one call needs a different model or provider:

```ruby
answer = Tina4::Ai.complete(
  "Summarize this incident report",
  provider: "openai",
  model: "gpt-4o-mini",
  temperature: 0.2,
  max_tokens: 300,
  timeout: 20
)
```

## Hold a chat

`Tina4::Ai.chat` accepts a non-empty list of messages. Each message needs a `system`, `user`, or `assistant` role and string content.

```ruby
require "tina4"

response = Tina4::Ai.chat([
  { role: "system", content: "Answer as a concise database engineer." },
  { role: "user", content: "When should I use a composite index?" }
])

puts response.text
puts response.model
puts response.usage["total_tokens"]
puts response.finish_reason
```

The `ChatResponse` object carries five fields:

| Field | Meaning |
|---|---|
| `text` | Normalized response text |
| `model` | Model reported by the provider |
| `usage` | `prompt_tokens`, `completion_tokens`, and `total_tokens` |
| `finish_reason` | Provider finish reason, or `nil` |
| `raw` | Original provider response |

Use `raw` only when you need provider-specific metadata. Keep application logic on the normalized fields so a provider change does not spread through your code.

## Stream text

Set `stream: true` to receive ordered text deltas. The enumerator yields text only and ignores provider metadata events.

```ruby
require "tina4"

chunks = Tina4::Ai.chat(
  [{ role: "user", content: "Write a short release announcement." }],
  stream: true
)

chunks.each do |chunk|
  print chunk
  $stdout.flush
end
```

Tina4 may retry before the first delta arrives. It never retries after yielding text because that could duplicate content the caller has already displayed.

## Create embeddings

`Tina4::Ai.embed` preserves the input shape. One string returns one vector. A list returns one vector per input, in the same order.

```ruby
require "tina4"

vector = Tina4::Ai.embed("Tina4 keeps application code small")

vectors = Tina4::Ai.embed([
  "The router finds a matching handler",
  "The ORM maps a row to a model"
])
```

Set `TINA4_EMBED_URL` when the embedding service uses a different base URL. Anthropic does not expose embeddings through this contract, so `provider: "anthropic"` raises `Tina4::AiConfigError`.

## Handle failures

All client failures inherit from `Tina4::AiError`:

| Error | Meaning |
|---|---|
| `Tina4::AiConfigError` | Missing key, invalid provider, bad option, or unsupported capability |
| `Tina4::AiHTTPError` | Provider returned a failing HTTP status or the transport failed |
| `Tina4::AiTimeoutError` | Connection or total request deadline expired |
| `Tina4::AiParseError` | A successful response did not match the provider contract |

```ruby
require "tina4"

begin
  puts Tina4::Ai.complete("Create a migration plan")
rescue Tina4::AiError => error
  warn "AI request failed: #{error.message}"
end
```

Hosted providers fail before sending when `TINA4_AI_KEY` is missing. Error text never includes the key, prompt, or provider response body. A failure stays a failure; Tina4 never turns it into an empty answer.

## Timeouts and retries

`TINA4_AI_CONNECT_TIMEOUT` bounds connection setup. `TINA4_AI_TIMEOUT` bounds the whole request, including retries and response reads. `TINA4_AI_MAX_RETRIES` applies only to connection failures, HTTP 429, and HTTP 5xx responses.

Other HTTP 4xx responses and malformed successful responses run once and fail. The client carries transient trouble for a bounded distance, then hands the error back to your code.
