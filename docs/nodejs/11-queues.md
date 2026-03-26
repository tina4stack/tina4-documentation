# Chapter 11: Queue System

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

### Convenience Method: produce

The `produce` method pushes to a specific topic without creating a separate Queue instance:

```typescript
const queue = new Queue({ topic: "emails" });
queue.produce("invoices", { order_id: 101, format: "pdf" });
```

### Queue Size

Check how many pending messages are in the queue:

```typescript
const count = queue.size();
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

The `consume` method is a generator that yields jobs one at a time. Each job must be explicitly completed or failed:

```typescript
import { Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

for (const job of queue.consume("emails")) {
    try {
        await sendEmail(job.payload.to, job.payload.subject, job.payload.body);
        job.complete();
    } catch (e) {
        job.fail(e.message);
    }
}
```

### Manual Pop

For more control, pop a single message:

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
                                                 -> job.fail()     -> FAILED
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

## 7. Retry and Dead Letters

### Max Retries

The default `max_retries` is 3. When a job's attempt count reaches `max_retries`, `retryFailed()` skips it.

### Retrying Failed Jobs

```typescript
// Retry a specific job by ID
queue.retry(jobId);

// Retry all failed jobs (skips those that exceeded max_retries)
queue.retryFailed();
```

### Dead Letters

Jobs that have exceeded `max_retries` are dead letters. There is no magic dead letter queue -- you retrieve and handle them yourself:

```typescript
const deadJobs = queue.deadLetters();

for (const job of deadJobs) {
    console.log(`Dead job: ${job.id}`);
    console.log(`  Payload: ${JSON.stringify(job.payload)}`);
    console.log(`  Error: ${job.error}`);
}
```

### Purging Jobs

Remove jobs by status:

```typescript
queue.purge("completed");
queue.purge("failed");
```

---

## 8. Switching Backends

Switching backends is a config change, not a code change.

### Default: File

```env
# No config needed -- file is the default
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
| `POST` | `/api/emails/retry` | Retry all failed jobs |

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
    return res.json({ message: "Failed emails re-queued for retry" });
});
```

Create a separate consumer file `src/workers/emailWorker.ts`:

```typescript
import { Queue } from "tina4-nodejs";

const queue = new Queue({ topic: "emails" });

for (const job of queue.consume("emails")) {
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

After the consumer has retried a job to `bad@example.com` three times, `queue.deadLetters()` returns that job. The `/api/emails/dead` endpoint shows it. You investigate, fix the address, and call `/api/emails/retry` to re-queue.

---

## 12. Gotchas

### 1. Always call complete or fail

**Fix:** Always call `job.complete()` on success and `job.fail(reason)` on failure. If you forget, the job stays reserved forever.

### 2. Worker not picking up messages

**Fix:** Make sure the consumer is running. Check that the topic in `queue.push()` matches the topic in `queue.consume()`.

### 3. Payload must be JSON-serializable

**Fix:** Only pass simple data types. Pass IDs, not full objects.

### 4. Dead letters pile up

**Fix:** Monitor `queue.deadLetters()` and set up alerts. Investigate root causes, then call `queue.retryFailed()` or `queue.purge("failed")`.

### 5. File backend for production

**Fix:** For multiple workers, switch to RabbitMQ, Kafka, or MongoDB via `TINA4_QUEUE_BACKEND`.

### 6. Consumer returns nothing

**Fix:** The consume pattern requires explicit `job.complete()` / `job.fail()` calls. Do not rely on return values.
