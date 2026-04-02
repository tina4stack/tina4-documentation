# Chapter 15: Structured Logging

## 1. Stop Using error_log

`error_log("Something happened")` works. It also produces an unreadable wall of text in production. Searching for a specific error across 500,000 lines of plain text is painful. Correlating a log line with a request, a user, and a timestamp is manual detective work.

Structured logging writes JSON. Every log entry is a machine-readable object with a timestamp, level, message, and whatever context you attach. Log aggregators (Datadog, Grafana Loki, AWS CloudWatch, Papertrail) can query, filter, and alert on structured logs.

Tina4 provides `Debug::message()` for structured logging. It uses PHP's standard log infrastructure. No external packages.

---

## 2. Log Levels

Tina4 defines five log levels as constants:

| Constant | Value | When to use |
|----------|-------|-------------|
| `TINA4_LOG_DEBUG` | `'DEBUG'` | Verbose detail for development |
| `TINA4_LOG_INFO` | `'INFO'` | Normal operations, confirmations |
| `TINA4_LOG_WARNING` | `'WARNING'` | Something unexpected but recoverable |
| `TINA4_LOG_ERROR` | `'ERROR'` | A failure that needs attention |
| `TINA4_LOG_CRITICAL` | `'CRITICAL'` | System is failing. Immediate action required |

Higher levels are always visible. Lower levels are filtered by `TINA4_LOG_LEVEL`.

---

## 3. Basic Logging

```php
<?php
use Tina4\Debug;

Debug::message("Application started", TINA4_LOG_INFO);
Debug::message("Cache miss for key: product:42", TINA4_LOG_DEBUG);
Debug::message("Payment gateway responded slowly", TINA4_LOG_WARNING);
Debug::message("Database query failed", TINA4_LOG_ERROR);
Debug::message("Out of disk space", TINA4_LOG_CRITICAL);
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

```env
# .env
TINA4_LOG_LEVEL=WARNING
```

With this setting:

```php
<?php
use Tina4\Debug;

Debug::message("Detailed SQL query", TINA4_LOG_DEBUG);    // Suppressed
Debug::message("User logged in", TINA4_LOG_INFO);         // Suppressed
Debug::message("Slow query detected", TINA4_LOG_WARNING); // Appears
Debug::message("Auth service unreachable", TINA4_LOG_ERROR);   // Appears
Debug::message("Disk full", TINA4_LOG_CRITICAL);               // Appears
```

Recommended levels by environment:

| Environment | TINA4_LOG_LEVEL |
|-------------|-----------------|
| Development | `DEBUG` |
| Staging | `INFO` |
| Production | `WARNING` |

---

## 5. Logging with Context

Pass a context array as the third argument. Context values are merged into the JSON log entry.

```php
<?php
use Tina4\Debug;

Debug::message("User login attempt", TINA4_LOG_INFO, [
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
use Tina4\Debug;

Router::post('/api/payments', function ($request, $response) {
    $body = $request->body;

    Debug::message("Payment request received", TINA4_LOG_INFO, [
        'amount'   => $body['amount'] ?? null,
        'currency' => $body['currency'] ?? 'USD',
        'ip'       => $request->server['REMOTE_ADDR'] ?? null
    ]);

    if (empty($body['amount']) || $body['amount'] <= 0) {
        Debug::message("Payment rejected: invalid amount", TINA4_LOG_WARNING, [
            'amount' => $body['amount'] ?? 'missing'
        ]);
        return $response->json(['error' => 'Invalid payment amount'], 400);
    }

    // Simulate payment processing
    $success = true;
    $transactionId = 'txn_' . uniqid();

    if ($success) {
        Debug::message("Payment processed successfully", TINA4_LOG_INFO, [
            'transaction_id' => $transactionId,
            'amount'         => $body['amount'],
            'currency'       => $body['currency'] ?? 'USD'
        ]);
        return $response->json(['transaction_id' => $transactionId], 201);
    } else {
        Debug::message("Payment gateway failure", TINA4_LOG_ERROR, [
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
use Tina4\Debug;

function processOrder(array $order): array {
    try {
        // Simulate work that might fail
        if (empty($order['items'])) {
            throw new \InvalidArgumentException("Order must have at least one item");
        }

        return ['status' => 'processed', 'order_id' => $order['id']];

    } catch (\InvalidArgumentException $e) {
        Debug::message("Order validation failed", TINA4_LOG_WARNING, [
            'order_id' => $order['id'] ?? null,
            'error'    => $e->getMessage()
        ]);
        throw $e;

    } catch (\Throwable $e) {
        Debug::message("Unexpected error processing order", TINA4_LOG_ERROR, [
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
use Tina4\Debug;

Router::any('*', function ($request, $response) {
    // Generate a request ID and attach to all logs in this request
    $requestId = bin2hex(random_bytes(8));
    $GLOBALS['request_id'] = $requestId;

    Debug::message("Request started", TINA4_LOG_DEBUG, [
        'request_id' => $requestId,
        'method'     => $request->method,
        'path'       => $request->server['REQUEST_URI'] ?? '/'
    ]);

    return null; // Pass through to the real handler
}, 'next');

function logWithRequest(string $message, string $level, array $ctx = []): void {
    Debug::message($message, $level, array_merge(
        ['request_id' => $GLOBALS['request_id'] ?? 'none'],
        $ctx
    ));
}
```

With request correlation, a single `grep "request_id:a3f8c1d2"` finds every log line for one HTTP request.

---

## 9. Performance Logging

Log slow operations automatically. Time your expensive calls:

```php
<?php
use Tina4\Debug;

function timedQuery(callable $query, string $label, float $warnThresholdMs = 100): mixed {
    $start = microtime(true);
    $result = $query();
    $durationMs = (microtime(true) - $start) * 1000;

    $level = $durationMs > $warnThresholdMs ? TINA4_LOG_WARNING : TINA4_LOG_DEBUG;

    Debug::message("Query timing: {$label}", $level, [
        'label'       => $label,
        'duration_ms' => round($durationMs, 2),
        'threshold_ms' => $warnThresholdMs,
        'slow'        => $durationMs > $warnThresholdMs
    ]);

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

```env
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
Debug::message("User updated", TINA4_LOG_INFO, [
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
