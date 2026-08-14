# AI Client

One class. Three methods. No provider SDK.
The Tina4 AI client sends chat, completion, embedding, and streaming requests through one provider-neutral API.

This chapter covers the application-facing `Tina4\AI` class. The `tina4 ai` command serves a different purpose: it installs Tina4 skills and context for coding assistants.

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

`AI::complete` sends one user message and returns the response text.

```php
<?php

use Tina4\AI;

$answer = AI::complete("Explain why this query needs an index");
echo $answer;
```

Pass named arguments when one call needs a different model or provider:

```php
$answer = AI::complete(
    "Summarize this incident report",
    provider: "openai",
    model: "gpt-4o-mini",
    temperature: 0.2,
    maxTokens: 300,
    timeout: 20,
);
```

## Hold a chat

`AI::chat` accepts a non-empty list of messages. Each message needs a `system`, `user`, or `assistant` role and string content.

```php
use Tina4\AI;

$response = AI::chat([
    ["role" => "system", "content" => "Answer as a concise database engineer."],
    ["role" => "user", "content" => "When should I use a composite index?"],
]);

echo $response->text;
echo $response->model;
echo $response->usage["total_tokens"];
echo $response->finish_reason;
```

The `ChatResponse` object carries five fields:

| Field | Meaning |
|---|---|
| `text` | Normalized response text |
| `model` | Model reported by the provider |
| `usage` | `prompt_tokens`, `completion_tokens`, and `total_tokens` |
| `finish_reason` | Provider finish reason, or `null` |
| `raw` | Original provider response |

Use `raw` only when you need provider-specific metadata. Keep application logic on the normalized fields so a provider change does not spread through your code.

## Stream text

Set `stream: true` to receive ordered text deltas. The generator yields text only and ignores provider metadata events.

```php
use Tina4\AI;

$chunks = AI::chat(
    [["role" => "user", "content" => "Write a short release announcement."]],
    stream: true,
);

foreach ($chunks as $chunk) {
    echo $chunk;
    flush();
}
```

Tina4 may retry before the first delta arrives. It never retries after yielding text because that could duplicate content the caller has already displayed.

## Create embeddings

`AI::embed` preserves the input shape. One string returns one vector. A list returns one vector per input, in the same order.

```php
use Tina4\AI;

$vector = AI::embed("Tina4 keeps application code small");

$vectors = AI::embed([
    "The router finds a matching handler",
    "The ORM maps a row to a model",
]);
```

Set `TINA4_EMBED_URL` when the embedding service uses a different base URL. Anthropic does not expose embeddings through this contract, so `provider: "anthropic"` raises `AIConfigError`.

## Handle failures

All client failures inherit from `AIError`:

| Error | Meaning |
|---|---|
| `AIConfigError` | Missing key, invalid provider, bad option, or unsupported capability |
| `AIHTTPError` | Provider returned a failing HTTP status or the transport failed |
| `AITimeoutError` | Connection or total request deadline expired |
| `AIParseError` | A successful response did not match the provider contract |

```php
use Tina4\AI;
use Tina4\AIError;

try {
    echo AI::complete("Create a migration plan");
} catch (AIError $error) {
    echo "AI request failed: " . $error->getMessage();
}
```

Hosted providers fail before sending when `TINA4_AI_KEY` is missing. Error text never includes the key, prompt, or provider response body. A failure stays a failure; Tina4 never turns it into an empty answer.

## Timeouts and retries

`TINA4_AI_CONNECT_TIMEOUT` bounds connection setup. `TINA4_AI_TIMEOUT` bounds the whole request, including retries and response reads. `TINA4_AI_MAX_RETRIES` applies only to connection failures, HTTP 429, and HTTP 5xx responses.

Other HTTP 4xx responses and malformed successful responses run once and fail. The client carries transient trouble for a bounded distance, then hands the error back to your code.
