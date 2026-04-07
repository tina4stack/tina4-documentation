# Chapter 12: Queues

## 1. Not Everything Should Happen Right Now

Some tasks are too slow for an HTTP request. Sending an email: 2 seconds. Generating a PDF report: 10 seconds. Processing a large CSV upload: a minute. Run these inside a route handler and the user stares at a spinner. Or the request times out.

Queues solve this. Push a message describing the work. A separate worker picks it up and does the job in the background. The user gets an instant response: "Your report is being generated."

Picture a store that sends order confirmations, generates invoices, and syncs inventory with a warehouse. None of these should block checkout. Each one becomes a queue message. A worker processes it on its own schedule.

---

## 2. Queue Configuration

Tina4 Python includes a built-in queue that requires zero additional setup. The default backend is file-based.

### Default (File Queue)

The file queue works out of the box with no extra configuration:

```bash
# No TINA4_QUEUE_BACKEND needed -- file is the default
```

The first time you push a message, Tina4 automatically creates the queue storage.

### Switching to RabbitMQ

When your application outgrows the file queue (millions of messages, multiple services, pub/sub patterns), switch to RabbitMQ:

```bash
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://user:pass@localhost:5672
```

Install the client library:

```bash
uv add pika
```

### Switching to Kafka

For stream processing, event sourcing, or very high throughput:

```bash
TINA4_QUEUE_BACKEND=kafka
TINA4_QUEUE_URL=localhost:9092
```

Install the client library:

```bash
uv add confluent-kafka
```

### Switching to MongoDB

```bash
TINA4_QUEUE_BACKEND=mongodb
TINA4_QUEUE_URL=mongodb://user:pass@localhost:27017/tina4
```

Install the driver:

```bash
uv add pymongo
```

The key point: your code stays the same. The `Queue` class, `push`, `pop`, and `consume` work identically whether the backend is file, RabbitMQ, Kafka, or MongoDB. The backend is configured via environment variables.

---

## 3. Creating a Queue and Pushing Messages

```python
from tina4_python.queue import Queue

queue = Queue(topic="emails")

# Push a message
message_id = queue.push({
    "to": "alice@example.com",
    "subject": "Order Confirmation",
    "body": "Your order #1234 has been confirmed."
})
```

The `topic` argument names the queue. The payload is any dictionary that can be serialized to JSON.

> **Backend configuration:** The queue backend is selected via environment variables, not constructor parameters. Set `TINA4_QUEUE_BACKEND` to `file` (default), `rabbitmq`, `kafka`, or `mongodb`. For the file backend, the `TINA4_QUEUE_PATH` environment variable controls the storage directory (default: data/queue). See Section 2 and Section 8 for full details.

### Convenience Method: produce

The `produce` method pushes to a specific topic without creating a separate Queue instance:

```python
queue = Queue(topic="emails")
queue.produce("invoices", {"order_id": 101, "format": "pdf"})
```

### Queue Size

Check how many pending messages are in the queue:

```python
count = queue.size()
```

---

## 4. Consuming Messages

### The consume Pattern

The `consume` method is a generator that yields jobs one at a time. Each job must be explicitly completed or failed:

```python
from tina4_python.queue import Queue

queue = Queue(topic="emails")

for job in queue.consume("emails"):
    try:
        send_email(job.payload["to"], job.payload["subject"], job.payload["body"])
        job.complete()
    except Exception as e:
        job.fail(str(e))
```

You can also filter by job ID:

```python
for job in queue.consume("emails", id="specific-job-id"):
    # Process only the job with that ID
    job.complete()
```

### Manual Pop

For more control, pop a single message:

```python
job = queue.pop()

if job is not None:
    try:
        send_email(job.payload["to"], job.payload["subject"])
        job.complete()
    except Exception as e:
        job.fail(str(e))
```

---

## 5. Job Lifecycle

A job moves through these statuses:

```
push() -> PENDING -> pop()/consume() -> RESERVED -> job.complete() -> COMPLETED
                                                  -> job.fail()    -> FAILED
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

- `job.complete()` -- mark the job as done
- `job.fail(reason)` -- mark the job as failed with a reason string
- `job.reject(reason)` -- alias for `fail`

Always call one of these. If you do not, the job stays reserved.

---

## 6. Retry and Dead Letters

### Max Retries

The `Queue` constructor accepts a `max_retries` parameter (default: 3). When a job's attempt count reaches `max_retries`, `retry_failed()` skips it.

```python
queue = Queue(topic="emails", max_retries=5)
```

### Retrying Failed Jobs

```python
# Retry a specific job by ID
queue.retry(job_id)

# Retry all failed jobs (skips those that exceeded max_retries)
queue.retry_failed()
```

### Dead Letters

Jobs that have exceeded `max_retries` are dead letters. There is no magic dead letter queue -- you retrieve and handle them yourself:

```python
dead_jobs = queue.dead_letters()

for job in dead_jobs:
    print(f"Dead job: {job.id}")
    print(f"  Payload: {job.data}")
    print(f"  Error: {job.error}")
```

### Purging Jobs

Remove jobs by status:

```python
queue.purge("completed")
queue.purge("failed")
```

---

## 7. Queue in Route Handlers

The most common pattern is pushing messages from route handlers:

```python
from tina4_python.router import get, post
from tina4_python.queue import Queue

queue = Queue(topic="emails")

@post("/api/orders")
async def create_order(request, response):
    body = request.body

    # Create the order in the database
    order_id = 101  # Simulated

    # Send confirmation email
    queue.push({
        "type": "order_confirmation",
        "to": body["email"],
        "order_id": order_id,
        "total": body["total"]
    })

    # Generate invoice on a different topic
    queue.produce("invoices", {
        "order_id": order_id,
        "format": "pdf"
    })

    # Sync with warehouse on a different topic
    queue.produce("warehouse_sync", {
        "order_id": order_id,
        "items": body["items"]
    })

    return response.json({
        "message": "Order created",
        "order_id": order_id
    }, 201)
```

The user gets an instant response. The email, invoice, and warehouse sync happen in the background.

---

## 8. Switching Backends via .env

Switching backends is a config change, not a code change.

### Development: File (default)

```bash
# No config needed -- file is the default
```

### Production: RabbitMQ

```bash
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://user:pass@rabbitmq.internal:5672
```

### High-Scale Production: Kafka

```bash
TINA4_QUEUE_BACKEND=kafka
TINA4_QUEUE_URL=kafka-1:9092,kafka-2:9092,kafka-3:9092
```

### Production: MongoDB

```bash
TINA4_QUEUE_BACKEND=mongodb
TINA4_QUEUE_URL=mongodb://user:pass@mongo.internal:27017/tina4
```

Your queue code does not change at all. The same `queue.push()` and `queue.consume()` calls work with every backend.

---

## 9. Produce and Consume Across Topics

The `Queue` class provides `produce()` and `consume()` methods for cross-topic messaging:

```python
from tina4_python.queue import Queue

queue = Queue(topic="default")

# Produce onto a specific topic
queue.produce("emails", {"to": "alice@example.com", "subject": "Hello"})

# Consume from a specific topic
for job in queue.consume("emails"):
    process(job)
    job.complete()
```

The `produce()` method pushes a job onto any named topic. The `consume()` method yields all available jobs from a topic as a generator.

---

## 10. Exercise: Build an Email Queue

Build an email queue system that sends emails in the background, including failure handling.

### Requirements

1. Create these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/emails/send` | Queue an email for sending |
| `GET` | `/api/emails/queue` | List pending email count |
| `GET` | `/api/emails/dead` | List dead letter jobs |
| `POST` | `/api/emails/retry` | Retry all failed jobs |

2. The email payload should include: `to` (required), `subject` (required), `body` (required)

3. Create a consumer that processes the queue, simulating occasional failures

4. When an email to a specific address fails repeatedly, it should end up in dead letters

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

# Retry failed
curl -X POST http://localhost:7145/api/emails/retry
```

---

## 11. Solution

Create `src/routes/email_queue.py`:

```python
from tina4_python.router import get, post
from tina4_python.queue import Queue

queue = Queue(topic="emails", max_retries=3)


@post("/api/emails/send")
async def queue_email(request, response):
    body = request.body

    errors = []
    if not body.get("to"):
        errors.append("'to' is required")
    if not body.get("subject"):
        errors.append("'subject' is required")
    if not body.get("body"):
        errors.append("'body' is required")

    if errors:
        return response.json({"errors": errors}, 400)

    message_id = queue.push({
        "to": body["to"],
        "subject": body["subject"],
        "body": body["body"]
    })

    return response.json({
        "message": "Email queued for sending",
        "message_id": message_id
    }, 201)


@get("/api/emails/queue")
async def email_queue_size(request, response):
    count = queue.size()
    return response.json({"pending": count})


@get("/api/emails/dead")
async def email_dead_letters(request, response):
    dead = queue.dead_letters()
    items = []
    for job in dead:
        items.append({
            "id": job.id,
            "payload": job.data,
            "error": job.error
        })
    return response.json({"dead_letters": items, "count": len(items)})


@post("/api/emails/retry")
async def retry_failed_emails(request, response):
    queue.retry_failed()
    return response.json({"message": "Failed emails re-queued for retry"})
```

Create a separate consumer file `src/workers/email_worker.py`:

```python
from tina4_python.queue import Queue
import time

queue = Queue(topic="emails", max_retries=3)

for job in queue.consume("emails"):
    payload = job.data

    print(f"Sending email to {payload['to']}...")
    print(f"  Subject: {payload['subject']}")
    print(f"  Body: {payload['body'][:50]}...")

    try:
        # Simulate sending (replace with real email logic)
        time.sleep(1)

        # Simulate failure for a specific address
        if payload["to"] == "bad@example.com":
            raise Exception("SMTP connection refused")

        print(f"  Email sent to {payload['to']} successfully!")
        job.complete()

    except Exception as e:
        print(f"  Failed: {e}")
        job.fail(str(e))
```

After the consumer has retried a job to `bad@example.com` three times, `queue.dead_letters()` returns that job. The `/api/emails/dead` endpoint shows it. You investigate, fix the address, and call `/api/emails/retry` to re-queue.

---

## 12. Gotchas

### 1. Always call complete or fail

**Problem:** Jobs stay in reserved status forever.

**Cause:** Your consumer does not call `job.complete()` or `job.fail()`. The job stays reserved and is never released.

**Fix:** Always call one of `job.complete()`, `job.fail(reason)`, or `job.reject(reason)` in your consumer loop.

### 2. Worker not picking up messages

**Problem:** Messages are pushed but nothing happens.

**Cause:** No consumer process is running, or the consumer is listening on a different topic.

**Fix:** Make sure the consumer is running. Check that the topic name in `queue.push()` matches the topic name in `queue.consume()`.

### 3. Payload too large

**Problem:** Pushing a message with a large payload is slow.

**Cause:** The payload is serialized to JSON and stored in the backend. Very large payloads slow down the queue.

**Fix:** Keep payloads small. Store files on disk or in object storage and put the file path in the payload. Payloads should be metadata, not data.

### 4. Dead letters pile up

**Problem:** Dead letters accumulate and nobody notices.

**Cause:** Failed jobs that exceed `max_retries` become dead letters but are never cleaned up.

**Fix:** Monitor dead letters with `queue.dead_letters()`. Set up an alert when the count exceeds a threshold. Investigate the root cause, fix it, then call `queue.retry_failed()` or `queue.purge("failed")`.

### 5. File backend for production

**Problem:** Multiple workers cause contention on file-based queue storage.

**Cause:** File-based storage supports one writer at a time.

**Fix:** For production with multiple workers, switch to RabbitMQ, Kafka, or MongoDB via the `TINA4_QUEUE_BACKEND` environment variable. The file backend is fine for development and single-worker setups.

### 6. Environment-specific topic collision

**Problem:** Development and staging environments process each other's messages.

**Cause:** Both environments use the same backend and the same topic names.

**Fix:** Use separate backends per environment, or prefix topic names with the environment: `Queue(topic="dev_emails")`.
