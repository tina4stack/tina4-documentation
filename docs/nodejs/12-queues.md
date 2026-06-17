# Chapter 12: Queue System

## 1. Do Not Make the User Wait

Your app sends welcome emails on signup. Generates PDF invoices. Resizes uploaded images. Each task takes 2 to 30 seconds. Run them inside the HTTP request and the user stares at a spinner.

Queues move slow work to a background process. The user gets a response in milliseconds. The work still happens -- just not during the request.

Tina4 has a built-in queue system. Works out of the box with a file-based backend. No Redis. No RabbitMQ. No external services.

---

## 2. Why Queues Matter

Without queues: 6530ms response time. With queues: 33ms. Same work done. Different timing.

Queues also deliver retry logic, rate limiting, fault isolation, and horizontal scaling.

---

## 3. File Queue (Default)

The file-based backend is the default. No configuration needed.

### Creating a Queue and Pushing a Job

```typescript
import { Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

// Push a job
queue.push({
    to: "alice@example.com",
    subject: "Order Confirmation",
    body: "Your order #1234 has been confirmed."
});
```

The constructor takes a config object. Pass `topic`, and optionally `backend`, `path`, `maxRetries`, and `retryBackoff`:

```typescript
const queue = new Queue({ topic: "emails", maxRetries: 3, retryBackoff: 30 });
```

A bare string as the first argument selects a backend, not a topic -- `new Queue("rabbitmq")` picks RabbitMQ. Use the config object to set a topic.

### Convenience Method: produce

The `produce` method pushes to a specific topic without creating a separate Queue instance:

```typescript
const queue = new Queue({ topic: "emails" });
queue.produce("invoices", { order_id: 101, format: "pdf" });
```

### Push with Priority

Jobs default to priority 0 (normal). The queue pops the highest-priority job first. Jobs that share a priority pop oldest-first:

```typescript
// Normal priority (default)
queue.push({ to: "alice@example.com", subject: "Newsletter" });

// High priority -- popped before normal jobs
// push(payload, delay, priority) -- delay 0, priority 10
queue.push({ to: "alice@example.com", subject: "Password Reset" }, 0, 10);
```

### Queue Size

Check how many pending jobs are in the queue:

```typescript
const count = queue.size();
```

Pass a status string to count jobs in a specific state. `size()` takes one argument -- the status. Valid statuses are `pending` (the default), `failed` (jobs still retrying), and `dead` (dead letters):

```typescript
const dead = queue.size("dead");
```

---

## 4. Pushing from Route Handlers

```typescript
import { Router, Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

Router.post("/api/register", async (req, res) => {
    const body = req.body;
    const userId = 42;

    queue.push({
        user_id: userId,
        to: body.email,
        name: body.name,
        subject: "Welcome!"
    });

    return res.status(201).json({
        message: "Registration successful. Welcome email will arrive shortly.",
        user_id: userId
    });
});
```

---

## 5. Consuming Jobs

The `consume` method is an **async generator** that yields jobs one at a time. Iterate it with `for await`, not a plain `for` loop -- a plain `for` loop throws because the generator is async. Call `complete` on success and `fail` on failure:

```typescript
import { Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

for await (const job of queue.consume("emails")) {
    try {
        await sendEmail(job.payload.to, job.payload.subject, job.payload.body);
        job.complete();
    } catch (e) {
        job.fail(e.message);
    }
}
```

`consume` runs forever by default. When the queue drains it sleeps for `pollInterval` milliseconds (default 1000) and polls again, so a long-running worker keeps picking up new jobs without any outer loop.

Pass `pollInterval = 0` to drain the queue once and stop. This is the single-pass form -- handy in tests and one-shot scripts:

```typescript
// consume(topic, id, pollInterval) -- 0 means single-pass drain
for await (const job of queue.consume("emails", undefined, 0)) {
    await sendEmail(job.payload.to, job.payload.subject, job.payload.body);
    job.complete();
}
```

### Automatic Retry

`job.fail(reason)` does the retry for you. It records one failed attempt and re-enqueues the job until it has been attempted `maxRetries` times. After that, the job becomes a dead letter. You write a single try/catch -- no manual retry call:

```typescript
// maxRetries defaults to 3, so this job runs at most 3 times before
// it is dead-lettered automatically.
const queue = new Queue({ topic: "emails", maxRetries: 3 });

for await (const job of queue.consume("emails", undefined, 0)) {
    try {
        await sendEmail(job.payload.to, job.payload.subject, job.payload.body);
        job.complete();
    } catch (e) {
        job.fail(e.message);   // re-enqueues automatically, dead-letters when exhausted
    }
}
```

Set `retryBackoff` (seconds) on the queue to delay each automatic re-enqueue. The default is 0 -- retry immediately, so the next poll picks the job straight up:

```typescript
const queue = new Queue({ topic: "emails", maxRetries: 5, retryBackoff: 30 });
```

### Manual Retry with Delay

`job.retry(delaySeconds)` re-queues a job yourself, ignoring the retry limit. Use it when you want explicit control over a single re-attempt rather than the automatic `fail` lifecycle:

```typescript
for await (const job of queue.consume("emails", undefined, 0)) {
    try {
        await sendEmail(job.payload.to, job.payload.subject, job.payload.body);
        job.complete();
    } catch (e) {
        // Re-queue after 30 seconds, regardless of attempt count
        job.retry(30);
    }
}
```

### Manual Pop

For more control, pop a single job:

```typescript
const job = queue.pop();

if (job !== null) {
    try {
        await sendEmail(job.payload.to, job.payload.subject);
        job.complete();
    } catch (e) {
        job.fail(e.message);
    }
}
```

---

## 6. Job Lifecycle

```
push() -> PENDING -> pop()/consume() -> RESERVED -> job.complete() -> COMPLETED
                                                 -> job.fail()
                                                        |
                                          attempts < maxRetries
                                                        |
                                              re-enqueued to PENDING
                                                        |
                                          attempts >= maxRetries
                                                        |
                                                   DEAD LETTER
```

`job.fail()` drives this automatically. Each call increments the attempt count exactly once. While attempts are below `maxRetries`, the job goes back to PENDING (after `retryBackoff` seconds, if set). Once attempts reach `maxRetries`, the job moves to the dead-letter store.

### Job Methods

When you receive a job from `consume` or `pop`, you have these methods:

- `job.complete()` -- mark the job as done. Terminal -- the job was already removed from the queue on pop.
- `job.fail(reason)` -- record a failed attempt. Re-enqueues automatically until `maxRetries` is reached, then dead-letters.
- `job.reject(reason)` -- alias for `fail`.
- `job.retry(delaySeconds)` -- manual re-queue after a delay (in seconds), ignoring the retry limit. The job goes back to PENDING.

### Job Properties

- `job.topic` -- the topic this job belongs to. Useful when consuming from multiple topics.
- `job.attempts` -- how many times this job has been attempted.
- `job.error` -- the last failure reason.

Always call `complete`, `fail`, or `retry` on every job. If you do not, the job stays reserved.

---

## 7. Retry and Dead Letters

### Max Retries

The default `maxRetries` is 3. `job.fail()` re-enqueues the job until its attempt count reaches `maxRetries`, then dead-letters it. Set a different limit on the queue:

```typescript
const queue = new Queue({ topic: "emails", maxRetries: 5 });
```

### Failed vs Dead-Lettered Jobs

`failed()` returns jobs that failed at least once but still have retries left -- they are sitting in the pending queue, waiting for the next poll. `deadLetters()` returns jobs that exhausted their retries:

```typescript
const retrying = queue.failed();       // failed once, still retrying
const exhausted = queue.deadLetters();  // out of retries
```

### Dead Letters

A dead letter is a job that exceeded `maxRetries`. There is no magic dead letter queue -- you retrieve and handle them yourself:

```typescript
const deadJobs = queue.deadLetters();

for (const job of deadJobs) {
    console.log(`Dead job: ${job.id}`);
    console.log(`  Payload: ${JSON.stringify(job.payload)}`);
    console.log(`  Error: ${job.error}`);
}
```

### Reviving Jobs

Move a dead letter back to PENDING. `retry(jobId)` revives one job by ID; `retryFailed()` revives dead letters that are under a raised `maxRetries` limit:

```typescript
// Revive a specific dead letter by ID
queue.retry(jobId);

// Re-queue dead letters that are under the (possibly raised) maxRetries limit
queue.retryFailed();
```

### Purging Jobs

Remove jobs by status. `purge()` accepts `pending`, `failed`, and `dead`:

```typescript
queue.purge("pending");
queue.purge("dead");
```

---

## 8. Switching Backends

Switching backends is a config change, not a code change. Two variables do the work. `TINA4_QUEUE_BACKEND` picks the backend. `TINA4_QUEUE_URL` points it at the broker:

```bash
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://guest:guest@localhost:5672/
```

`TINA4_QUEUE_URL` is the one connection variable. It is identical across every Tina4 framework -- Python, PHP, Ruby, and Node.js all read the same var, so a `.env` written for one runs unchanged on another. Each backend parses the URL into the settings it needs.

Per-backend variables (`TINA4_RABBITMQ_*`, `TINA4_KAFKA_*`, `TINA4_MONGO_*`) still work. They are **optional overrides**: set one and it wins over the matching field from `TINA4_QUEUE_URL`. The precedence for every field is: the specific per-backend variable, then the value from `TINA4_QUEUE_URL`, then the built-in default.

### Default: File

```bash
# No config needed -- file is the default
# Optionally set a custom storage path (defaults to data/queue)
TINA4_QUEUE_PATH=data/queue
```

The file backend ignores `TINA4_QUEUE_URL` -- it stores jobs on disk, not over a broker connection.

### RabbitMQ

Lead with `TINA4_QUEUE_URL` as an AMQP URL. Tina4 parses it into host, port, username, password, and vhost:

```bash
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://guest:guest@localhost:5672/   # host/port/user/pass/vhost
```

The URL format is `amqp://[user:pass@]host:port[/vhost]`. The vhost is the path segment after the port -- `amqp://localhost:5672/orders` sets the vhost to `/orders`.

The per-backend variables are optional overrides for individual fields:

```bash
TINA4_RABBITMQ_HOST=localhost      # override; default: localhost
TINA4_RABBITMQ_PORT=5672           # override; default: 5672
TINA4_RABBITMQ_USERNAME=guest      # override; default: guest
TINA4_RABBITMQ_PASSWORD=guest      # override; default: guest
TINA4_RABBITMQ_VHOST=/             # override; default: /
```

### Kafka

`TINA4_QUEUE_URL` is the broker list. A leading `kafka://` is stripped if present; otherwise the value is used as-is:

```bash
TINA4_QUEUE_BACKEND=kafka
TINA4_QUEUE_URL=localhost:9092                     # or kafka://broker1:9092,broker2:9092
TINA4_KAFKA_GROUP_ID=tina4_consumer_group          # default: tina4_consumer_group
```

`TINA4_KAFKA_BROKERS` is the optional override -- set it and it wins over `TINA4_QUEUE_URL`:

```bash
TINA4_KAFKA_BROKERS=localhost:9092                 # override; default: localhost:9092
```

### MongoDB

`TINA4_QUEUE_URL` is the connection URI:

```bash
TINA4_QUEUE_BACKEND=mongodb
TINA4_QUEUE_URL=mongodb://user:pass@localhost:27017
TINA4_MONGO_DB=tina4               # default: tina4
TINA4_MONGO_COLLECTION=tina4_queue # default: tina4_queue
```

The overrides: `TINA4_MONGO_URI` is a full URI that wins over `TINA4_QUEUE_URL`. The individual field variables build a URI when no URI is set at all:

```bash
TINA4_MONGO_URI=mongodb://user:pass@localhost:27017  # override; wins over TINA4_QUEUE_URL
TINA4_MONGO_HOST=localhost         # used only when no URI is set; default: localhost
TINA4_MONGO_PORT=27017             # used only when no URI is set; default: 27017
TINA4_MONGO_USERNAME=              # optional
TINA4_MONGO_PASSWORD=              # optional
```

Install the MongoDB driver:

```bash
npm install mongodb
```

Your code stays identical. Same `queue.push()` and `queue.consume()` calls. The backend is an implementation detail.

---

## 9. Multiple Jobs from One Action

```typescript
import { Router, Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

Router.post("/api/orders", async (req, res) => {
    const orderId = 101;

    queue.push({ order_id: orderId, to: req.body.email, subject: "Order Confirmation" });
    queue.produce("invoices", { order_id: orderId, format: "pdf" });
    queue.produce("inventory", { items: req.body.items });
    queue.produce("warehouse", { order_id: orderId, shipping_address: req.body.shipping_address });

    return res.status(201).json({ message: "Order placed successfully", order_id: orderId });
});
```

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
| `POST` | `/api/emails/retry` | Re-queue dead letters under a raised limit |

2. The email payload should include: `to` (required), `subject` (required), `body` (required)

3. Create a consumer that processes the queue, simulating occasional failures

### Test with:

```bash
curl -X POST http://localhost:7148/api/emails/send \
  -H "Content-Type: application/json" \
  -d '{"to": "alice@example.com", "subject": "Welcome!", "body": "Thanks for signing up."}'

curl http://localhost:7148/api/emails/queue

curl http://localhost:7148/api/emails/dead

curl -X POST http://localhost:7148/api/emails/retry
```

---

## 11. Solution

Create `src/routes/emailQueue.ts`:

```typescript
import { Router, Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

/**
 * @noauth
 */
Router.post("/api/emails/send", async (req, res) => {
    const body = req.body;

    const errors: string[] = [];
    if (!body.to) errors.push("'to' is required");
    if (!body.subject) errors.push("'subject' is required");
    if (!body.body) errors.push("'body' is required");

    if (errors.length > 0) {
        return res.status(400).json({ errors });
    }

    const messageId = queue.push({
        to: body.to,
        subject: body.subject,
        body: body.body
    });

    return res.status(201).json({
        message: "Email queued for sending",
        message_id: messageId
    });
});

Router.get("/api/emails/queue", async (req, res) => {
    const count = queue.size();
    return res.json({ pending: count });
});

Router.get("/api/emails/dead", async (req, res) => {
    const deadJobs = queue.deadLetters();
    const items = deadJobs.map((job) => ({
        id: job.id,
        payload: job.payload,
        error: job.error
    }));
    return res.json({ dead_letters: items, count: items.length });
});

Router.post("/api/emails/retry", async (req, res) => {
    queue.retryFailed();
    return res.json({ message: "Dead letters re-queued for retry" });
});
```

Create a separate consumer file `src/workers/emailWorker.ts`:

```typescript
import { Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

for await (const job of queue.consume("emails")) {
    const payload = job.payload;

    console.log(`Sending email to ${payload.to}...`);
    console.log(`  Subject: ${payload.subject}`);

    try {
        // Simulate sending (replace with real email logic)
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // Simulate failure for a specific address
        if (payload.to === "bad@example.com") {
            throw new Error("SMTP connection refused");
        }

        console.log(`  Email sent to ${payload.to} successfully!`);
        job.complete();

    } catch (e) {
        console.log(`  Failed: ${e.message}`);
        job.fail(e.message);
    }
}
```

`job.fail()` re-enqueues the `bad@example.com` job automatically. After it has been attempted three times (the default `maxRetries`), `queue.deadLetters()` returns it. The `/api/emails/dead` endpoint shows it. You investigate, raise `maxRetries`, and call `/api/emails/retry` to re-queue.

---

## 12. Gotchas

### 1. Use `for await`, not `for`

**Fix:** `consume` is an async generator. Iterate it with `for await (const job of queue.consume(...))`. A plain `for` loop throws "is not iterable".

### 2. Always call complete or fail

**Fix:** Always call `job.complete()` on success and `job.fail(reason)` on failure. If you forget, the job stays reserved forever.

### 3. consume runs forever

**Fix:** The default `pollInterval` makes `consume` poll forever, even when the queue is empty -- that is what a worker wants. For a single-pass drain (tests, scripts), pass `pollInterval = 0`: `queue.consume(topic, undefined, 0)`.

### 4. Worker not picking up jobs

**Fix:** Make sure the consumer is running. Check that the topic in `queue.push()` matches the topic in `queue.consume()`.

### 5. Payload must be JSON-serializable

**Fix:** Only pass simple data types. Pass IDs, not full objects.

### 6. Dead letters pile up

**Fix:** Monitor `queue.deadLetters()` and set up alerts. Investigate root causes, then raise `maxRetries` and call `queue.retryFailed()`, or `queue.purge("dead")`.

### 7. File backend for production

**Fix:** For multiple workers, switch to RabbitMQ, Kafka, or MongoDB via `TINA4_QUEUE_BACKEND`.
