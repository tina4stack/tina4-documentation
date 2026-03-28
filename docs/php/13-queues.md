# Chapter 11: Queue System

## 1. Do Not Make the User Wait

Your app sends welcome emails on signup, generates PDF invoices, and resizes uploaded images. Each task takes 2 to 30 seconds. Do them inside the HTTP request and the user stares at a spinner while the server processes. That is a broken experience.

Queues move slow work to a background process. The handler drops a job onto a queue and responds immediately. A separate consumer picks it up. The user sees "Welcome -- check your email." in under 100 milliseconds. The email arrives 5 seconds later.

Tina4 has a built-in queue system. Works out of the box with a file-based backend. No Redis. No RabbitMQ. No external services. Add jobs. Process them.

---

## 2. Why Queues Matter

Without queues:

```
User clicks "Sign Up"
  -> Server validates input (10ms)
  -> Server creates user in database (20ms)
  -> Server sends welcome email (3000ms)
  -> Server generates PDF welcome kit (2000ms)
  -> Server resizes avatar (1500ms)
  -> User sees response (6530ms later)
```

With queues:

```
User clicks "Sign Up"
  -> Server validates input (10ms)
  -> Server creates user in database (20ms)
  -> Server queues: send welcome email (1ms)
  -> Server queues: generate PDF (1ms)
  -> Server queues: resize avatar (1ms)
  -> User sees response (33ms later)

Meanwhile, in the background:
  -> Consumer sends welcome email
  -> Consumer generates PDF
  -> Consumer resizes avatar
```

6.5 seconds becomes 33 milliseconds. The work still happens. Just not during the HTTP request.

Beyond speed, queues provide:

- **Retry logic**: Email server down. Job retries automatically.
- **Rate limiting**: Process at a controlled pace. Do not overwhelm external services.
- **Fault isolation**: A failed PDF does not crash the signup request.
- **Scaling**: More consumers for higher load.

---

## 3. File Queue (Default)

The file-based backend is the default. No configuration needed. First job creates the queue storage automatically.

### Creating a Queue and Pushing a Job

```php
<?php
use Tina4\Queue;

$queue = new Queue(topic: 'emails');

// Push a job
$queue->push([
    "to" => "alice@example.com",
    "subject" => "Order Confirmation",
    "body" => "Your order #1234 has been confirmed."
]);
```

You can also use the longer constructor form:

```php
$queue = new Queue('file', [], 'emails');
```

### Convenience Method: produce

The `produce` method pushes to a specific topic without creating a separate Queue instance:

```php
$queue = new Queue(topic: 'emails');
$queue->produce('invoices', ["order_id" => 101, "format" => "pdf"]);
```

### Push with Priority

Jobs default to priority 0 (normal). Higher numbers are popped first:

```php
// Normal priority (default)
$queue->push(["to" => "alice@example.com", "subject" => "Newsletter"]);

// High priority -- processed before normal jobs
$queue->push(["to" => "alice@example.com", "subject" => "Password Reset"], priority: 10);
```

### Queue Size

Check how many pending messages are in the queue:

```php
$count = $queue->size();
```

Pass a status string to count jobs in a specific state:

```php
$failed = $queue->size("failed");
$completed = $queue->size("completed");
$reserved = $queue->size("reserved");
```

---

## 4. Pushing from Route Handlers

The most common pattern is pushing messages from route handlers:

```php
<?php
use Tina4\Router;
use Tina4\Queue;

Router::post("/api/register", function ($request, $response) {
    $body = $request->body;

    // Create the user (database logic)
    $userId = 42; // Simulated

    $queue = new Queue(topic: 'emails');

    // Queue a welcome email
    $queue->push([
        "user_id" => $userId,
        "to" => $body["email"],
        "name" => $body["name"],
        "subject" => "Welcome!"
    ]);

    return $response->json([
        "message" => "Registration successful. Welcome email will arrive shortly.",
        "user_id" => $userId
    ], 201);
});
```

```bash
curl -X POST http://localhost:7146/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Registration successful. Welcome email will arrive shortly.",
  "user_id": 42
}
```

Response returns immediately. The email job waits in the queue.

---

## 5. Consuming Jobs

The `consume` method is a generator that yields jobs one at a time. Each job must be explicitly completed or failed:

```php
<?php
use Tina4\Queue;

$queue = new Queue(topic: 'emails');

foreach ($queue->consume('emails') as $job) {
    try {
        sendEmail($job->payload['to'], $job->payload['subject'], $job->payload['body']);
        $job->complete();
    } catch (\Throwable $e) {
        $job->fail($e->getMessage());
    }
}
```

### Retry with Delay

If a job fails but you want to retry it after a cooldown instead of marking it as failed:

```php
foreach ($queue->consume('emails') as $job) {
    try {
        sendEmail($job->payload['to'], $job->payload['subject'], $job->payload['body']);
        $job->complete();
    } catch (\Throwable $e) {
        // Retry after 30 seconds instead of failing immediately
        $job->retry(30);
    }
}
```

### Manual Pop

For more control, pop a single message:

```php
$job = $queue->pop();

if ($job !== null) {
    try {
        sendEmail($job->payload['to'], $job->payload['subject']);
        $job->complete();
    } catch (\Throwable $e) {
        $job->fail($e->getMessage());
    }
}
```

---

## 6. Job Lifecycle

Every job moves through states:

```
push() -> PENDING -> pop()/consume() -> RESERVED -> $job->complete() -> COMPLETED
                                                 -> $job->fail()     -> FAILED
                                                                          |
                                                                    retry (manual)
                                                                          |
                                                                       PENDING
                                                                          |
                                                                max retries exceeded
                                                                          |
                                                                     DEAD LETTER
```

### Job Methods

When you receive a job from `consume` or `pop`, you have three methods:

- `$job->complete()` -- mark the job as done
- `$job->fail($reason)` -- mark the job as failed with a reason string
- `$job->reject($reason)` -- alias for `fail`
- `$job->retry($delaySeconds)` -- re-queue the job after a delay (in seconds). The job goes back to PENDING after the delay elapses.

### Job Properties

- `$job->topic` -- the topic this job belongs to. Useful when consuming from multiple topics.

Always call `complete`, `fail`, or `retry` on every job. If you do not, the job stays reserved.

---

## 7. Retry and Dead Letters

### Max Retries

The default `max_retries` is 3. When a job's attempt count reaches `max_retries`, `retryFailed()` skips it.

### Retrying Failed Jobs

```php
// Retry a specific job by ID
$queue->retry($jobId);

// Retry all failed jobs (skips those that exceeded max_retries)
$queue->retryFailed();
```

### Dead Letters

Jobs that have exceeded `max_retries` are dead letters. There is no magic dead letter queue -- you retrieve and handle them yourself:

```php
$deadJobs = $queue->deadLetters();

foreach ($deadJobs as $job) {
    error_log("Dead job: " . $job->id);
    error_log("  Payload: " . json_encode($job->payload));
    error_log("  Error: " . $job->error);
}
```

### Purging Jobs

Remove jobs by status:

```php
$queue->purge("completed");
$queue->purge("failed");
```

---

## 8. Producing Multiple Jobs

One action. Multiple background tasks:

```php
<?php
use Tina4\Router;
use Tina4\Queue;

Router::post("/api/orders", function ($request, $response) {
    $body = $request->body;

    $orderId = 101;
    $queue = new Queue(topic: 'emails');

    $queue->push([
        "order_id" => $orderId,
        "to" => $body["email"],
        "subject" => "Order Confirmation"
    ]);

    $queue->produce("invoices", [
        "order_id" => $orderId,
        "format" => "pdf"
    ]);

    $queue->produce("inventory", [
        "items" => $body["items"]
    ]);

    $queue->produce("warehouse", [
        "order_id" => $orderId,
        "shipping_address" => $body["shipping_address"]
    ]);

    return $response->json([
        "message" => "Order placed successfully",
        "order_id" => $orderId
    ], 201);
});
```

Four jobs queued in under 5 milliseconds. Instant response.

---

## 9. Switching Backends

Switching backends is a config change, not a code change.

### Default: File

```env
# No config needed -- file is the default
# Optionally set a custom storage path (defaults to ./queue)
TINA4_QUEUE_PATH=./data/queue
```

### RabbitMQ

```env
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://user:pass@localhost:5672
```

### Kafka

```env
TINA4_QUEUE_BACKEND=kafka
TINA4_QUEUE_URL=localhost:9092
```

### MongoDB

```env
TINA4_QUEUE_BACKEND=mongodb
TINA4_QUEUE_URL=mongodb://user:pass@localhost:27017/tina4
```

Your queue code does not change at all. The same `$queue->push()` and `$queue->consume()` calls work with every backend.

---

## 10. Exercise: Build an Email Queue

Build a queue-based email system with failure handling.

### Requirements

1. Create these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/emails/send` | Queue an email for sending |
| `GET` | `/api/emails/queue` | Show pending email count |
| `GET` | `/api/emails/dead` | List dead letter jobs |
| `POST` | `/api/emails/retry` | Retry all failed jobs |

2. The email payload should include: `to` (required), `subject` (required), `body` (required)

3. Create a consumer that processes the queue, simulating occasional failures

4. When an email fails repeatedly, it should end up in dead letters

### Test with:

```bash
# Queue an email
curl -X POST http://localhost:7146/api/emails/send \
  -H "Content-Type: application/json" \
  -d '{"to": "alice@example.com", "subject": "Welcome!", "body": "Thanks for signing up."}'

# Check queue size
curl http://localhost:7146/api/emails/queue

# Check dead letters
curl http://localhost:7146/api/emails/dead

# Retry failed
curl -X POST http://localhost:7146/api/emails/retry
```

---

## 11. Solution

Create `src/routes/email-queue.php`:

```php
<?php
use Tina4\Router;
use Tina4\Queue;

$queue = new Queue(topic: 'emails');

/**
 * @noauth
 */
Router::post("/api/emails/send", function ($request, $response) use ($queue) {
    $body = $request->body;

    $errors = [];
    if (empty($body["to"])) $errors[] = "'to' is required";
    if (empty($body["subject"])) $errors[] = "'subject' is required";
    if (empty($body["body"])) $errors[] = "'body' is required";

    if (!empty($errors)) {
        return $response->json(["errors" => $errors], 400);
    }

    $messageId = $queue->push([
        "to" => $body["to"],
        "subject" => $body["subject"],
        "body" => $body["body"]
    ]);

    return $response->json([
        "message" => "Email queued for sending",
        "message_id" => $messageId
    ], 201);
});

Router::get("/api/emails/queue", function ($request, $response) use ($queue) {
    $count = $queue->size();
    return $response->json(["pending" => $count]);
});

Router::get("/api/emails/dead", function ($request, $response) use ($queue) {
    $deadJobs = $queue->deadLetters();
    $items = [];
    foreach ($deadJobs as $job) {
        $items[] = [
            "id" => $job->id,
            "payload" => $job->payload,
            "error" => $job->error
        ];
    }
    return $response->json(["dead_letters" => $items, "count" => count($items)]);
});

Router::post("/api/emails/retry", function ($request, $response) use ($queue) {
    $queue->retryFailed();
    return $response->json(["message" => "Failed emails re-queued for retry"]);
});
```

Create a separate consumer file `src/workers/email_worker.php`:

```php
<?php
use Tina4\Queue;

$queue = new Queue(topic: 'emails');

foreach ($queue->consume('emails') as $job) {
    $payload = $job->payload;

    echo "Sending email to {$payload['to']}...\n";
    echo "  Subject: {$payload['subject']}\n";

    try {
        // Simulate sending (replace with real email logic)
        sleep(1);

        // Simulate failure for a specific address
        if ($payload['to'] === 'bad@example.com') {
            throw new \RuntimeException("SMTP connection refused");
        }

        echo "  Email sent to {$payload['to']} successfully!\n";
        $job->complete();

    } catch (\Throwable $e) {
        echo "  Failed: {$e->getMessage()}\n";
        $job->fail($e->getMessage());
    }
}
```

After the consumer has retried a job to `bad@example.com` three times, `$queue->deadLetters()` returns that job. The `/api/emails/dead` endpoint shows it. You investigate, fix the address, and call `/api/emails/retry` to re-queue.

---

## 12. Gotchas

### 1. Always call complete or fail

**Problem:** Jobs stay in reserved status forever.

**Cause:** Your consumer does not call `$job->complete()` or `$job->fail()`. The job stays reserved and is never released.

**Fix:** Always call one of `$job->complete()`, `$job->fail($reason)`, or `$job->reject($reason)` in your consumer loop.

### 2. Worker not picking up messages

**Problem:** Messages are pushed but nothing happens.

**Cause:** No consumer process is running, or the consumer is listening on a different topic.

**Fix:** Make sure the consumer is running. Check that the topic name in `$queue->push()` matches the topic in `$queue->consume()`.

### 3. Payload must be JSON-serializable

**Problem:** `$queue->push()` throws a serialization error.

**Cause:** You passed an object, database connection, file handle, or other non-serializable value.

**Fix:** Payload must contain only simple types: strings, numbers, booleans, arrays of these. Pass IDs, not objects. The consumer looks up records by ID.

### 4. Dead letters pile up

**Problem:** Dead letters accumulate and nobody notices.

**Cause:** Failed jobs that exceed `max_retries` become dead letters but are never cleaned up.

**Fix:** Monitor dead letters with `$queue->deadLetters()`. Set up an alert when the count exceeds a threshold. Investigate the root cause, fix it, then call `$queue->retryFailed()` or `$queue->purge("failed")`.

### 5. File backend for production

**Problem:** Multiple workers cause contention on the file backend.

**Cause:** The file backend is designed for single-worker setups.

**Fix:** For production with multiple workers, switch to RabbitMQ, Kafka, or MongoDB via the `TINA4_QUEUE_BACKEND` environment variable.

### 6. Consumer returns nothing

**Problem:** Jobs process but immediately fail.

**Cause:** You forgot to call `$job->complete()`. Without it, the job stays reserved or is treated as failed.

**Fix:** Always call `$job->complete()` on success and `$job->fail($reason)` on failure. Do not rely on return values.
