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

The first time you push a message, Tina4 creates the queue storage.

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
TINA4_KAFKA_BROKERS=localhost:9092
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

> **Backend configuration:** The queue backend is selected via environment variables, not constructor parameters. Set `TINA4_QUEUE_BACKEND` to `file` (default), `rabbitmq`, `kafka`, or `mongodb`. For the file backend, the `TINA4_QUEUE_PATH` environment variable controls the storage directory (default: data/queue). See Section 2 and Section 9 for full details.

### Priority and Delay

`push` accepts two optional arguments:

```python
# Higher priority is processed first
queue.push({"to": "vip@example.com", "subject": "Urgent"}, priority=10)

# Hold the job for 60 seconds before it becomes available
queue.push({"to": "later@example.com", "subject": "Reminder"}, delay_seconds=60)
```

`priority` defaults to `0`. `pop` and `consume` return the highest-priority job first; ties break oldest-first. See Section 5.

`delay_seconds` defaults to `0`. The file backend honors the delay; the job stays hidden until the time arrives. External brokers (RabbitMQ, Kafka, MongoDB) manage their own delivery timing.

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

The `consume` method is a generator that yields jobs one at a time. It polls the queue continuously and sleeps when empty, so you need no outer loop. Each job must be explicitly completed or failed:

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

This loop runs forever, processing jobs as they arrive. To drain the queue once and stop when it is empty, pass `poll_interval=0`:

```python
for job in queue.consume("emails", poll_interval=0):
    process(job)
    job.complete()
```

You can also stop after a fixed number of jobs with `iterations`:

```python
for job in queue.consume("emails", iterations=5):
    process(job)
    job.complete()
```

### Consume a Single Job by ID

Pass `job_id` to process one specific job. It yields that job once, then returns:

```python
for job in queue.consume("emails", job_id="specific-job-id"):
    process(job)
    job.complete()
```

### Manual Pop

For full control, pop a single message. `pop` returns the highest-priority available job, or `None` when the queue is empty:

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

## 5. Priority Ordering

`pop` and `consume` do not return jobs in plain insert order. They return the **highest-priority** available job first. When two jobs share the same priority, the **older** one wins.

```python
queue = Queue(topic="tasks")

queue.push({"label": "normal"})                 # priority 0
queue.push({"label": "urgent"}, priority=10)    # priority 10
queue.push({"label": "also normal"})            # priority 0

queue.pop().payload["label"]   # "urgent"        (highest priority)
queue.pop().payload["label"]   # "normal"        (oldest of the priority-0 pair)
queue.pop().payload["label"]   # "also normal"
```

A delayed job (pushed with `delay_seconds`) stays hidden until its time arrives, regardless of priority.

Priority ordering is enforced by the file backend. External brokers store the priority on each message but follow their own delivery semantics.

---

## 6. Job Lifecycle

A job moves through these statuses:

```
push() -> PENDING -> pop()/consume() -> job.complete() -> done (removed)
                                      -> job.fail()     -> attempts += 1
                                                              |
                                            attempts < max_retries
                                                              |
                                                  re-enqueued -> PENDING
                                                              |
                                           attempts >= max_retries
                                                              |
                                                         DEAD LETTER
```

### Job Methods

When you receive a job from `consume` or `pop`, you have these methods:

- `job.complete()` -- mark the job as done. Terminal: the job is removed and never comes back.
- `job.fail(reason)` -- record a failed attempt. Increments `attempts` and either re-enqueues the job or dead-letters it (see Section 7).
- `job.reject(reason)` -- alias for `fail`.
- `job.retry(delay_seconds=0)` -- manually re-queue the job, optionally after a delay. Bypasses the retry limit.

Read the payload with `job.payload`. The fields `job.id`, `job.attempts`, and `job.error` are also available.

Always call `complete()` or `fail()`. If you call neither, the job has already left the queue (it was claimed on pop) and will not be retried.

---

## 7. Automatic Retry and Dead Letters

### How Retry Works

`job.fail()` does the retry bookkeeping for you. Each call increments the job's `attempts` count. While `attempts` is below `max_retries`, the job is automatically re-enqueued, so the next `pop()` or `consume()` picks it up again. Once `attempts` reaches `max_retries`, the job moves to the dead-letter store.

This means a normal `consume` loop retries failed jobs on its own. No manual `retry_failed()` call is needed:

```python
queue = Queue(topic="emails", max_retries=3)

for job in queue.consume("emails"):
    try:
        send_email(job.payload)
        job.complete()
    except Exception as e:
        job.fail(str(e))   # retried up to 3 times, then dead-lettered
```

With `max_retries=3`, a job that keeps failing is attempted 3 times. On the third failure it lands in dead letters.

### Retry Backoff

By default a failed job is re-enqueued immediately and the next loop iteration retries it. To space retries out, pass `retry_backoff` (in seconds) to the constructor:

```python
queue = Queue(topic="emails", max_retries=5, retry_backoff=30)
```

Now each automatic re-enqueue holds the job for 30 seconds before it becomes available again. `retry_backoff` applies to the file backend.

### Configuring Max Retries

The `Queue` constructor accepts `max_retries` (default: 3):

```python
queue = Queue(topic="emails", max_retries=5)
```

### Inspecting Failed and Dead Jobs

Two methods let you see where jobs are in the retry cycle:

```python
# Jobs that failed at least once but are still being retried
# (0 < attempts < max_retries)
retrying = queue.failed()

# Jobs that exhausted their retries (attempts >= max_retries)
dead_jobs = queue.dead_letters()
```

`failed()` returns plain dicts. `dead_letters()` returns `Job` objects, so you can iterate them like any other job:

```python
for job in queue.dead_letters():
    print(f"Dead job: {job.id}")
    print(f"  Payload: {job.payload}")
    print(f"  Attempts: {job.attempts}")
    print(f"  Error: {job.error}")
```

### Reviving Dead Letters

Auto-retry stops at the dead-letter store. To put dead jobs back on the queue, do it explicitly:

```python
# Re-queue every dead-letter job
queue.retry()

# Re-queue one specific job by ID
queue.retry(job_id)

# Re-queue dead jobs that are still under the retry limit
queue.retry_failed()
```

### Counting and Purging by Status

`size` and `purge` accept a status: `pending`, `failed`, or `dead`.

```python
queue.size("pending")    # jobs waiting to be processed
queue.size("dead")       # dead-letter jobs

queue.purge("pending")   # drop everything still waiting
queue.purge("dead")      # clear the dead-letter store
```

---

## 8. Queue in Route Handlers

The most common pattern is pushing messages from route handlers:

```python
from tina4_python.core.router import get, post
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

## 9. Switching Backends via .env

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
TINA4_KAFKA_BROKERS=kafka-1:9092,kafka-2:9092,kafka-3:9092
```

### Production: MongoDB

```bash
TINA4_QUEUE_BACKEND=mongodb
TINA4_QUEUE_URL=mongodb://user:pass@mongo.internal:27017/tina4
```

### Environment variables the queue reads

| Variable | Used by | Purpose |
|----------|---------|---------|
| `TINA4_QUEUE_BACKEND` | all | Selects the backend: `file` (default), `rabbitmq`, `kafka`, `mongodb` |
| `TINA4_QUEUE_PATH` | file | Storage directory for the file backend (default: `data/queue`) |
| `TINA4_QUEUE_URL` | rabbitmq, mongodb, kafka | Connection URL for the broker |
| `TINA4_KAFKA_BROKERS` | kafka | Comma-separated broker list (overrides `TINA4_QUEUE_URL`) |

Your queue code does not change at all. The same `queue.push()` and `queue.consume()` calls work with every backend.

---

## 10. Produce and Consume Across Topics

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

The `produce()` method pushes a job onto any named topic. The `consume()` method yields available jobs from a topic as a generator.

---

## 11. Exercise: Build an Email Queue

Build an email queue system that sends emails in the background, including failure handling.

### Requirements

1. Create these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/emails/send` | Queue an email for sending |
| `GET` | `/api/emails/queue` | List pending email count |
| `GET` | `/api/emails/dead` | List dead letter jobs |
| `POST` | `/api/emails/retry` | Revive dead-letter jobs |

2. The email payload should include: `to` (required), `subject` (required), `body` (required)

3. Create a consumer that processes the queue, simulating occasional failures

4. When an email to a specific address fails repeatedly, it should end up in dead letters

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

# Revive dead letters
curl -X POST http://localhost:7146/api/emails/retry
```

---

## 12. Solution

Create `src/routes/email_queue.py`:

```python
from tina4_python.core.router import get, post
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
    items = []
    for job in queue.dead_letters():
        items.append({
            "id": job.id,
            "payload": job.payload,
            "attempts": job.attempts,
            "error": job.error
        })
    return response.json({"dead_letters": items, "count": len(items)})


@post("/api/emails/retry")
async def retry_dead_emails(request, response):
    queue.retry()
    return response.json({"message": "Dead-letter emails re-queued"})
```

Create a separate consumer file `src/workers/email_worker.py`:

```python
from tina4_python.queue import Queue
import time

queue = Queue(topic="emails", max_retries=3)

for job in queue.consume("emails"):
    payload = job.payload

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

The consumer loop retries on its own. A job to `bad@example.com` fails, gets re-enqueued, and is retried. After three attempts `queue.dead_letters()` returns it and the `/api/emails/dead` endpoint shows it. You investigate, fix the address, and call `/api/emails/retry` to put it back on the queue.

---

## 13. Gotchas

### 1. Always call complete or fail

**Problem:** A failed job is never retried, or you lose track of it.

**Cause:** Your consumer does not call `job.complete()` or `job.fail()`. The job was claimed on pop, so it has already left the pending queue; without `fail()` it is neither retried nor dead-lettered.

**Fix:** Always call one of `job.complete()`, `job.fail(reason)`, or `job.reject(reason)` in your consumer loop. `fail()` handles the retry and dead-letter bookkeeping for you.

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

**Cause:** Jobs that exhaust `max_retries` become dead letters and stay there until you act.

**Fix:** Monitor dead letters with `queue.dead_letters()` or `queue.size("dead")`. Set up an alert when the count exceeds a threshold. Investigate the root cause, fix it, then call `queue.retry()` to revive them or `queue.purge("dead")` to clear them.

### 5. File backend for production

**Problem:** Multiple workers cause contention on file-based queue storage.

**Cause:** File-based storage supports one writer at a time.

**Fix:** For production with multiple workers, switch to RabbitMQ, Kafka, or MongoDB via the `TINA4_QUEUE_BACKEND` environment variable. The file backend is fine for development and single-worker setups.

### 6. Environment-specific topic collision

**Problem:** Development and staging environments process each other's messages.

**Cause:** Both environments use the same backend and the same topic names.

**Fix:** Use separate backends per environment, or prefix topic names with the environment: `Queue(topic="dev_emails")`.
