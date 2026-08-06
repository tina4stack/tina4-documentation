# Chapter 15: Structured Logging

## 1. Stop Using error_log

`error_log("Something happened")` works. It also produces an unreadable wall of text in production. Searching for a specific error across 500,000 lines of plain text is painful. Correlating a log line with a request, a user, and a timestamp is manual detective work.

Structured logging writes JSON. Every log entry is a machine-readable object with a timestamp, level, message, and whatever context you attach. Log aggregators (Datadog, Grafana Loki, AWS CloudWatch, Papertrail) can query, filter, and alert on structured logs.

Tina4 provides `Tina4\Log` for structured logging. Each level has its own method: `Log::debug()`, `Log::info()`, `Log::warning()`, `Log::error()`, `Log::critical()`. Output is JSON by default. Zero external packages.

The historical `Tina4\Debug::message()` API still works as a compatibility shim that forwards to `Tina4\Log`; use it if you're upgrading from a v3.12.x codebase. New code should use the level-specific `Log` methods.

---

## 2. Log Levels

Tina4 has five log levels, each with its own `Log` method:

| Method | When to use |
|--------|-------------|
| `Log::debug($msg, $context)` | Verbose detail for development |
| `Log::info($msg, $context)` | Normal operations, confirmations |
| `Log::warning($msg, $context)` | Something unexpected but recoverable |
| `Log::error($msg, $context)` | A failure that needs attention |
| `Log::critical($msg, $context)` | System is failing. Immediate action required |

Higher levels are always visible. Lower levels are filtered by `TINA4_LOG_LEVEL`.

---

## 3. Basic Logging

```php
<?php
use Tina4\Log;

Log::info("Application started");
Log::debug("Cache miss for key: product:42");
Log::warning("Payment gateway responded slowly");
Log::error("Database query failed");
Log::critical("Out of disk space");
```

Output (JSON format):

```json
{"timestamp":"2026-04-02T14:30:01Z","level":"INFO","message":"Application started"}
{"timestamp":"2026-04-02T14:30:01Z","level":"DEBUG","message":"Cache miss for key: product:42"}
{"timestamp":"2026-04-02T14:30:01Z","level":"WARNING","message":"Payment gateway responded slowly"}
{"timestamp":"2026-04-02T14:30:01Z","level":"ERROR","message":"Database query failed"}
{"timestamp":"2026-04-02T14:30:01Z","level":"CRITICAL","message":"Out of disk space"}
```

Each line is a complete JSON object. One per log entry.

---

## 4. Log Level Filtering

Set the minimum log level via environment variable. Only messages at or above that level appear in the output.

```bash
# .env
TINA4_LOG_LEVEL=WARNING
```

With this setting:

```php
<?php
use Tina4\Log;

Log::debug("Detailed SQL query");        // Suppressed
Log::info("User logged in");             // Suppressed
Log::warning("Slow query detected");     // Appears
Log::error("Auth service unreachable");  // Appears
Log::critical("Disk full");              // Appears
```

Recommended levels by environment:

| Environment | TINA4_LOG_LEVEL |
|-------------|-----------------|
| Development | `DEBUG` |
| Staging | `INFO` |
| Production | `WARNING` |

---

## 5. Logging with Context

Pass a context array as the second argument. Context values are merged into the JSON log entry.

```php
<?php
use Tina4\Log;

Log::info("User login attempt", [
    'user_id'    => 42,
    'email'      => 'alice@example.com',
    'ip'         => '203.0.113.5',
    'user_agent' => 'Mozilla/5.0 ...'
]);
```

Output:

```json
{
  "timestamp": "2026-04-02T14:30:01Z",
  "level": "INFO",
  "message": "User login attempt",
  "user_id": 42,
  "email": "alice@example.com",
  "ip": "203.0.113.5",
  "user_agent": "Mozilla/5.0 ..."
}
```

Context makes log lines searchable: `level:INFO AND user_id:42` finds every action by that user.

---

## 6. Logging in Route Handlers

Log the lifecycle of an HTTP request. Incoming requests, decisions made, and outcomes:

```php
<?php
use Tina4\Router;
use Tina4\Log;

Router::post('/api/payments', function ($request, $response) {
    $body = $request->body;

    Log::info("Payment request received", [
        'amount'   => $body['amount'] ?? null,
        'currency' => $body['currency'] ?? 'USD',
        'ip'       => $request->server['REMOTE_ADDR'] ?? null
    ]);

    if (empty($body['amount']) || $body['amount'] <= 0) {
        Log::warning("Payment rejected: invalid amount", [
            'amount' => $body['amount'] ?? 'missing'
        ]);
        return $response->json(['error' => 'Invalid payment amount'], 400);
    }

    // Simulate payment processing
    $success = true;
    $transactionId = 'txn_' . uniqid();

    if ($success) {
        Log::info("Payment processed successfully", [
            'transaction_id' => $transactionId,
            'amount'         => $body['amount'],
            'currency'       => $body['currency'] ?? 'USD'
        ]);
        return $response->json(['transaction_id' => $transactionId], 201);
    } else {
        Log::error("Payment gateway failure", [
            'amount'   => $body['amount'],
            'gateway'  => 'stripe',
            'reason'   => 'Gateway timeout'
        ]);
        return $response->json(['error' => 'Payment failed'], 502);
    }
});
```

---

## 7. Logging Exceptions

Log exceptions with full context. Include the message, file, line, and trace:

```php
<?php
use Tina4\Log;

function processOrder(array $order): array {
    try {
        // Simulate work that might fail
        if (empty($order['items'])) {
            throw new \InvalidArgumentException("Order must have at least one item");
        }

        return ['status' => 'processed', 'order_id' => $order['id']];

    } catch (\InvalidArgumentException $e) {
        Log::warning("Order validation failed", [
            'order_id' => $order['id'] ?? null,
            'error'    => $e->getMessage()
        ]);
        throw $e;

    } catch (\Throwable $e) {
        Log::error("Unexpected error processing order", [
            'order_id' => $order['id'] ?? null,
            'error'    => $e->getMessage(),
            'file'     => $e->getFile(),
            'line'     => $e->getLine(),
            'trace'    => $e->getTraceAsString()
        ]);
        throw $e;
    }
}
```

---

## 8. Request Correlation

Attach a request ID to every log message within a request. All log lines from the same request share one ID. This lets you filter a full request trace from thousands of concurrent requests.

```php
<?php
use Tina4\Router;
use Tina4\Log;

Router::any('*', function ($request, $response) {
    // Generate a request ID and attach to all logs in this request
    $requestId = bin2hex(random_bytes(8));
    $GLOBALS['request_id'] = $requestId;

    Log::debug("Request started", [
        'request_id' => $requestId,
        'method'     => $request->method,
        'path'       => $request->server['REQUEST_URI'] ?? '/'
    ]);

    return null; // Pass through to the real handler
}, 'next');

function logWithRequest(string $level, string $message, array $ctx = []): void {
    $merged = array_merge(['request_id' => $GLOBALS['request_id'] ?? 'none'], $ctx);
    Log::{$level}($message, $merged);
}
```

With request correlation, a single `grep "request_id:a3f8c1d2"` finds every log line for one HTTP request.

---

## 9. Performance Logging

Log slow operations automatically. Time your expensive calls:

```php
<?php
use Tina4\Log;

function timedQuery(callable $query, string $label, float $warnThresholdMs = 100): mixed {
    $start = microtime(true);
    $result = $query();
    $durationMs = (microtime(true) - $start) * 1000;

    $context = [
        'label'        => $label,
        'duration_ms'  => round($durationMs, 2),
        'threshold_ms' => $warnThresholdMs,
        'slow'         => $durationMs > $warnThresholdMs,
    ];

    if ($durationMs > $warnThresholdMs) {
        Log::warning("Query timing: {$label}", $context);
    } else {
        Log::debug("Query timing: {$label}", $context);
    }

    return $result;
}

// Usage
$products = timedQuery(
    fn() => fetchAllProducts(),
    'fetchAllProducts',
    warnThresholdMs: 50
);
```

Any query slower than 50ms emits a `WARNING`. All others emit `DEBUG` and are suppressed in production.

---

## 10. Environment Configuration

```bash
# Minimum level to log (DEBUG | INFO | WARNING | ERROR | CRITICAL)
TINA4_LOG_LEVEL=WARNING

# Log output destination (stderr | stdout | file)
TINA4_LOG_OUTPUT=stderr

# Log file path (only used when TINA4_LOG_OUTPUT=file)
TINA4_LOG_FILE=./logs/app.log

# Log format (json | text)
TINA4_LOG_FORMAT=json
```

In development, use `DEBUG` level with `text` format for human-readable output. In production, use `WARNING` or `ERROR` level with `json` format for log aggregators.

---

## 11. Gotchas

### 1. Logging sensitive data

**Problem:** User passwords and payment card numbers appear in log files.

**Cause:** You logged the entire request body without filtering.

**Fix:** Never log raw `$request->body` or `$_POST`. Explicitly list the fields you want to log, excluding sensitive ones:

```php
Log::info("User updated", [
    'user_id' => $body['id'],
    'email'   => $body['email'],
    // NOT: 'password' => $body['password']
]);
```

### 2. Logging too much in production

**Problem:** Log volume is enormous. Storage costs spike. Log aggregator rate limits trigger.

**Cause:** `TINA4_LOG_LEVEL=DEBUG` in production logs every cache miss, DB query, and template render.

**Fix:** Set `TINA4_LOG_LEVEL=WARNING` in production. Use `DEBUG` only in development.

### 3. Forgetting to log errors before rethrowing

**Problem:** A caught exception is rethrown but never logged. It disappears silently or appears only in a generic error handler with no context.

**Fix:** Always log before rethrowing. The context (order ID, user ID, inputs) is available inside the catch block. It is gone by the time the exception reaches the top-level handler.
