# Chapter 12: Queue System

## 1. Do Not Make the User Wait

Your app sends welcome emails on signup, generates PDF invoices, and resizes uploaded images. Each task takes 2 to 30 seconds. Do them inside the HTTP request and the user stares at a spinner while the server processes. That is a broken experience.

Queues move slow work to a background process. The handler drops a job onto a queue and responds immediately. A separate consumer picks it up. The user sees "Welcome -- check your email." in under 100 milliseconds. The email arrives 5 seconds later.

Tina4 has a built-in queue system. It works out of the box with a file-based backend. No Redis. No RabbitMQ. No external services. Add jobs. Process them.

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

Beyond speed, queues give you:

- **Automatic retries**: The email server is down. The job retries on its own, then lands in dead letters if it keeps failing.
- **Priority**: Password resets jump ahead of newsletters.
- **Fault isolation**: A failed PDF does not crash the signup request.
- **Scaling**: Run more consumers for higher load.

---

## 3. File Queue (Default)

The file-based backend is the default. No configuration needed. The first job creates the queue storage automatically under `data/queue`.

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

You can also use the longer constructor form. The signature is `new Queue($backend, $config, $topic)`:

```php
$queue = new Queue('file', [], 'emails');
```

The `$config` array accepts `path`, `maxRetries`, and `retryBackoff` (covered in section 7):

```php
$queue = new Queue('file', ['maxRetries' => 5, 'retryBackoff' => 10], 'emails');
```

### Convenience Method: produce

The `produce` method pushes to a specific topic without creating a separate Queue instance:

```php
$queue = new Queue(topic: 'emails');
$queue->produce('invoices', ["order_id" => 101, "format" => "pdf"]);
```

### Push with Priority

Jobs default to priority 0 (normal). Higher numbers are popped first. Within the same priority, the oldest job goes first:

```php
// Normal priority (default)
$queue->push(["to" => "alice@example.com", "subject" => "Newsletter"]);

// High priority -- popped before the newsletter above
$queue->push(["to" => "alice@example.com", "subject" => "Password Reset"], priority: 10);
```

### Push with Delay

Pass a delay (in seconds) to hold a job back until the delay elapses:

```php
// Becomes available 60 seconds from now
$queue->push(["to" => "alice@example.com", "subject" => "Reminder"], priority: 0, delay: 60);
```

### Queue Size

Check how many pending messages are in the queue:

```php
$count = $queue->size();
```

Pass a status string to count jobs in a specific state. The file backend tracks three states: `pending`, `failed` (retrying), and `dead` (exhausted retries):

```php
$pending = $queue->size("pending");
$retrying = $queue->size("failed");
$dead = $queue->size("dead");
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
curl -X POST http://localhost:7145/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Registration successful. Welcome email will arrive shortly.",
  "user_id": 42
}
```

The response returns immediately. The email job waits in the queue.

---

## 5. Consuming Jobs

The `consume` method is a generator that yields `Job` objects one at a time. Each `Job` carries the payload and the lifecycle methods you call on it:

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

When a job fails, `$job->fail()` re-queues it automatically and the next iteration picks it up again. After `maxRetries` attempts the job moves to dead letters. You do not call anything manually -- the loop above is the whole retry mechanism. Section 7 covers the lifecycle in detail.

### consume Is a Long-Running Poll

By default `consume` never returns. When the queue drains it sleeps for `pollInterval` seconds (default `1.0`) and polls again, so a worker loop keeps running and waiting for new jobs. That is exactly what you want for a long-lived background worker.

When you want a **single pass** -- drain everything currently queued, then stop -- pass `pollInterval` of `0`. The generator returns as soon as the queue is empty:

```php
// Drain the queue once and stop (useful in tests and one-shot scripts)
foreach ($queue->consume('emails', null, 0) as $job) {
    sendEmail($job->payload['to'], $job->payload['subject'], $job->payload['body']);
    $job->complete();
}
```

The `consume` signature is `consume($topic, $id, $pollInterval, $iterations, $batchSize)`. Pass `$iterations` to stop after a fixed number of jobs, or `$id` to consume one specific job by ID.

### Retry with a Manual Delay

`$job->fail()` already retries automatically. If instead you want to push a job back yourself with a specific cooldown -- regardless of the retry limit -- call `$job->retry($delaySeconds)`:

```php
foreach ($queue->consume('emails') as $job) {
    try {
        sendEmail($job->payload['to'], $job->payload['subject'], $job->payload['body']);
        $job->complete();
    } catch (\Throwable $e) {
        // Manual override: re-queue after 30 seconds (does not consult maxRetries)
        $job->retry(30);
    }
}
```

### Manual Pop

For lower-level control, `pop` returns the next job as a **plain array** (not a `Job` object), or `null` when the queue is empty. Use array access on the payload, and do not call lifecycle methods on it -- the file backend already removed the job from the pending queue when you popped it:

```php
$job = $queue->pop();

if ($job !== null) {
    // $job is an array: ['id' => ..., 'payload' => [...], 'priority' => ..., ...]
    sendEmail($job['payload']['to'], $job['payload']['subject']);
}
```

If you need the convenient `Job` object with `->payload`, `->complete()`, and `->fail()`, use `consume` instead. To grab several jobs at once, `popBatch($count)` returns an array of job arrays (highest priority first).

---

## 6. The Job Object

`consume` yields `Job` objects. Here are the methods and properties you use.

### Job Methods

- `$job->complete()` -- mark the job as done. Terminal -- the job is finished and gone.
- `$job->fail($reason)` -- record a failed attempt. Increments `attempts`, stores the error, and **automatically re-queues** the job while retries remain, or moves it to dead letters once they are exhausted.
- `$job->reject($reason)` -- alias for `fail`.
- `$job->retry($delaySeconds)` -- a manual override that always re-queues the job after the delay, regardless of the retry limit. Use this when you want to schedule a retry yourself rather than rely on the automatic path.

### Job Properties

- `$job->payload` -- the data you pushed.
- `$job->topic` -- the topic this job belongs to. Useful when consuming from multiple topics.
- `$job->priority` -- the job's priority.
- `$job->attempts` -- how many times this job has been attempted.
- `$job->id` -- the unique job ID.
- `$job->error` -- the last failure reason, if any.

You can also call `$job->toArray()`, `$job->toHash()`, or `$job->toJson()` to serialize a job.

---

## 7. Automatic Retry and Dead Letters

This is the part the queue handles for you. When a `Job` from `consume` fails, you do not schedule the retry -- `$job->fail()` does.

### How the Lifecycle Works

Every job moves through these states:

```
push() -> PENDING -> consume() yields Job -> $job->complete() -> done (removed)
                                          -> $job->fail()
                                                 |
                                       attempts < maxRetries ?
                                          |              |
                                         yes             no
                                          |              |
                          re-queued to PENDING      DEAD LETTER
                          (after retryBackoff)   (deadLetters() returns it)
```

When you call `$job->fail()`:

1. `attempts` is incremented and the error is stored.
2. If `attempts` is still **below** `maxRetries`, the job is re-queued to PENDING (after the `retryBackoff` delay, if set). The next `consume`/`pop` picks it up again.
3. Once `attempts` reaches `maxRetries`, the job is moved to the dead-letter store, where `deadLetters()` returns it.

So a `consume` loop that calls `$job->fail($e)` in its `catch` block retries each job `maxRetries` times on its own, then dead-letters it. **There is no manual `retryFailed()` step in this path.**

### maxRetries

The default `maxRetries` is 3. Override it in the constructor config:

```php
$queue = new Queue('file', ['maxRetries' => 5], 'emails');
```

### retryBackoff

`retryBackoff` (in seconds) delays the automatic re-enqueue after a failure. With `0` (the default), a failed job is available again on the very next poll. Set it to space retries out -- handy when an external service needs time to recover:

```php
// Failed jobs wait 10 seconds before becoming available to retry again
$queue = new Queue('file', ['maxRetries' => 5, 'retryBackoff' => 10], 'emails');
```

### Inspecting Retrying and Dead Jobs

These management methods operate on the file backend's store:

- `$queue->failed()` returns jobs that have failed at least once but are **still being retried** (`0 < attempts < maxRetries`). They live in the pending queue.
- `$queue->deadLetters()` returns jobs that **exhausted their retries** (`attempts >= maxRetries`).

```php
$deadJobs = $queue->deadLetters();

foreach ($deadJobs as $job) {
    // Items from deadLetters() are arrays, not Job objects
    error_log("Dead job: " . $job['id']);
    error_log("  Payload: " . json_encode($job['payload']));
    error_log("  Error: " . ($job['error'] ?? ''));
}
```

### Manually Reviving Jobs

Beyond the automatic path, you can revive jobs by hand:

```php
// Revive a specific dead-letter job by ID (always re-queues it)
$queue->retry($jobId);

// Revive all dead-letter jobs
$queue->retry();

// Re-queue failed jobs that are still under maxRetries
$queue->retryFailed();
```

### Purging Jobs

Remove jobs by status. `purge` accepts `pending`, `failed`, and `dead`, and returns the number removed:

```php
$queue->purge("dead");      // clear the dead-letter store
$queue->purge("failed");    // clear retrying jobs
$queue->purge("pending");   // clear the pending queue
```

`$queue->clear()` is a shortcut that removes all pending jobs and returns the count.

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

Switching backends is a config change, not a code change. The file backend handles the retry and dead-letter lifecycle described above; external brokers (RabbitMQ, Kafka, MongoDB) manage their own delivery and retry semantics.

### Default: File

```bash
# No config needed -- file is the default
# Optionally set a custom storage path (defaults to data/queue)
TINA4_QUEUE_PATH=./data/queue
```

### RabbitMQ

```bash
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://user:pass@localhost:5672
```

### Kafka

```bash
TINA4_QUEUE_BACKEND=kafka
TINA4_QUEUE_URL=kafka://localhost:9092
```

### MongoDB

```bash
TINA4_QUEUE_BACKEND=mongodb
TINA4_QUEUE_URL=mongodb://user:pass@localhost:27017/tina4
```

`TINA4_QUEUE_BACKEND` selects the backend, `TINA4_QUEUE_PATH` sets the file backend's storage directory, and `TINA4_QUEUE_URL` carries the connection string for rabbitmq, kafka, and mongodb. Your queue code does not change -- the same `$queue->push()` and `$queue->consume()` calls work with every backend.

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
| `POST` | `/api/emails/retry` | Revive dead-letter jobs |

2. The email payload should include: `to` (required), `subject` (required), `body` (required)

3. Create a consumer that processes the queue, simulating occasional failures

4. When an email fails repeatedly, it should end up in dead letters

### Test with:

```bash
# Queue an email
curl -X POST http://localhost:7145/api/emails/send \
  -H "Content-Type: application/json" \
  -d '{"to": "alice@example.com", "subject": "Welcome!", "body": "Thanks for signing up."}'

# Check queue size
curl http://localhost:7145/api/emails/queue

# Check dead letters
curl http://localhost:7145/api/emails/dead

# Revive dead letters
curl -X POST http://localhost:7145/api/emails/retry
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
            "id" => $job["id"],
            "payload" => $job["payload"],
            "error" => $job["error"] ?? null
        ];
    }
    return $response->json(["dead_letters" => $items, "count" => count($items)]);
});

Router::post("/api/emails/retry", function ($request, $response) use ($queue) {
    // Revive every dead-letter job back to the pending queue
    $queue->retry();
    return $response->json(["message" => "Dead-letter emails re-queued"]);
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
        // Automatic retry -> dead-letter. No manual re-queue needed.
        $job->fail($e->getMessage());
    }
}
```

The consumer calls `$job->fail()` whenever an email fails. The queue re-queues that job automatically, so the same worker retries it on its next pass. After `maxRetries` attempts (3 by default) the job to `bad@example.com` lands in dead letters, where `$queue->deadLetters()` returns it. The `/api/emails/dead` endpoint shows it. You investigate, fix the address, and call `/api/emails/retry` to revive it.

> The consumer above is a long-running poll -- it keeps waiting for new jobs and never returns on its own. Run it as a dedicated worker process. For a one-shot drain (for example in a test), use `$queue->consume('emails', null, 0)`.

---

## 12. Gotchas

### 1. consume runs forever by default

**Problem:** Your script calls `consume` and never reaches the code after the loop.

**Cause:** `consume` is a long-running poll. With the default `pollInterval` of `1.0`, it sleeps and keeps polling when the queue is empty -- it does not return.

**Fix:** That is correct for a background worker. For a single-pass drain (tests, one-shot jobs), pass `pollInterval` of `0`: `$queue->consume('emails', null, 0)`.

### 2. Calling complete or fail on a pop() result

**Problem:** `$job->complete()` or `$job->payload` errors after `pop()`.

**Cause:** `pop()` returns a plain **array**, not a `Job` object. There is no `->payload` property and no lifecycle methods on it.

**Fix:** Use array access (`$job['payload']`) for `pop()` results, and do not call `complete()`/`fail()` -- the job is already removed from the pending queue. If you want `Job` objects with lifecycle methods, use `consume` instead.

### 3. Letting jobs fail silently

**Problem:** Jobs that error are lost instead of retried.

**Cause:** Your consumer catches the exception but never calls `$job->fail()`, so the queue never records the failure or schedules a retry.

**Fix:** In a `consume` loop, call `$job->complete()` on success and `$job->fail($reason)` on failure. `fail()` is what drives the automatic retry -> dead-letter lifecycle.

### 4. Worker not picking up messages

**Problem:** Messages are pushed but nothing happens.

**Cause:** No consumer process is running, or the consumer is listening on a different topic.

**Fix:** Make sure the consumer is running. Check that the topic name in `$queue->push()` matches the topic in `$queue->consume()`.

### 5. Payload must be JSON-serializable

**Problem:** Your payload comes back wrong or empty.

**Cause:** You passed an object, database connection, file handle, or other non-serializable value. Jobs are stored as JSON.

**Fix:** Payload must contain only simple types: strings, numbers, booleans, and arrays of these. Pass IDs, not objects. The consumer looks up records by ID.

### 6. Dead letters pile up

**Problem:** Dead letters accumulate and nobody notices.

**Cause:** Jobs that exhaust `maxRetries` become dead letters and stay there until you act on them.

**Fix:** Monitor dead letters with `$queue->deadLetters()` or `$queue->size("dead")`. Alert when the count crosses a threshold. Fix the root cause, then `$queue->retry()` to revive them or `$queue->purge("dead")` to clear them.

### 7. File backend for production

**Problem:** Many workers contend on the file backend.

**Cause:** The file backend is designed for single-worker setups.

**Fix:** For production with multiple workers, switch to RabbitMQ, Kafka, or MongoDB via the `TINA4_QUEUE_BACKEND` environment variable.
