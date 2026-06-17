# Chapter 12: Queue System

## 1. Do Not Make the User Wait

Your app sends welcome emails on signup. Generates PDF invoices. Resizes uploaded images. Each task takes 2 to 30 seconds. Run them inside the HTTP request and the user stares at a spinner while the server grinds through email delivery, invoice rendering, and image resizing.

Queues move slow work to a background process. The HTTP handler drops a job onto a queue and responds to the user in under 100 milliseconds. A separate consumer picks up the job and does the work at its own pace. The user sees "Welcome! Check your email." The email arrives 5 seconds later.

Tina4's queue system works out of the box with a file-based backend. No Redis. No RabbitMQ. No external services. Add jobs and process them.

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

6.5 seconds becomes 33 milliseconds. The user feels the difference.

---

## 3. File Queue (Default)

The file-based backend is the default. No configuration needed.

### Creating a Queue and Pushing a Job

```ruby
queue = Tina4::Queue.new(topic: "emails")

# Push a job -- returns the Job that was queued
job = queue.push({
  to: "alice@example.com",
  subject: "Order Confirmation",
  body: "Your order #1234 has been confirmed."
})

puts job.id  # the generated job id
```

`push` returns a `Tina4::Job`, not an integer. Read `job.id` when you need the identifier.

### Convenience Method: produce

The `produce` method pushes to a specific topic without creating a separate Queue instance. It also returns the `Job`:

```ruby
queue = Tina4::Queue.new(topic: "emails")
queue.produce("invoices", { order_id: 101, format: "pdf" })
```

### Push with Priority

Jobs default to priority 0 (normal). The queue pops the highest priority first, and breaks ties oldest-first:

```ruby
# Normal priority (default)
queue.push({ to: "alice@example.com", subject: "Newsletter" })

# High priority -- popped before normal jobs
queue.push({ to: "alice@example.com", subject: "Password Reset" }, priority: 10)
```

### Delaying a Job

Pass `delay_seconds` to hold a job back. It stays invisible to consumers until the delay elapses:

```ruby
# Becomes available 60 seconds from now
queue.push({ to: "alice@example.com", subject: "Reminder" }, delay_seconds: 60)
```

### Queue Size

Check how many pending messages are in the queue:

```ruby
count = queue.size
```

Pass a status keyword to count jobs in a specific state. `"failed"` and `"dead"` both count jobs in the dead-letter store:

```ruby
dead = queue.size(status: "dead")
```

---

## 4. Pushing from Route Handlers

```ruby
Tina4::Router.post("/api/register") do |request, response|
  body = request.body

  user_id = 42 # Simulated

  queue = Tina4::Queue.new(topic: "emails")

  queue.push({
    user_id: user_id,
    to: body["email"],
    name: body["name"],
    subject: "Welcome!"
  })

  response.json({
    message: "Registration successful. Welcome email will arrive shortly.",
    user_id: user_id
  }, 201)
end
```

```bash
curl -X POST http://localhost:7147/api/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com", "password": "securePass123"}'
```

```json
{
  "message": "Registration successful. Welcome email will arrive shortly.",
  "user_id": 42
}
```

---

## 5. Consuming Jobs

The `consume` method yields jobs one at a time via a block. Each job must be explicitly completed or failed:

```ruby
queue = Tina4::Queue.new(topic: "emails")

queue.consume("emails") do |job|
  begin
    send_email(job.payload[:to], job.payload[:subject], job.payload[:body])
    job.complete
  rescue => e
    job.fail(e.message)
  end
end
```

`consume` polls forever by default. When the queue is empty it sleeps for `poll_interval` seconds (default 1.0) and polls again. To drain the queue once and stop, pass `poll_interval: 0`. To stop after a set number of jobs, pass `iterations:`.

### Automatic Retry

When you call `job.fail(reason)`, the queue handles the retry for you. It increments the job's attempt count and puts the job straight back onto the pending queue. The next `pop` or `consume` iteration picks it up again. Once a job has been attempted `max_retries` times, the queue stops retrying and moves it to the dead-letter store.

So the consumer loop below retries a failing job up to `max_retries` times on its own, then dead-letters it. No manual `retry_failed` call is needed:

```ruby
# Retry each failed job up to 3 times, then dead-letter it
queue = Tina4::Queue.new(topic: "emails", max_retries: 3)

queue.consume("emails") do |job|
  begin
    send_email(job.payload[:to], job.payload[:subject], job.payload[:body])
    job.complete
  rescue => e
    job.fail(e.message)  # auto re-enqueues until attempts == max_retries
  end
end
```

### Retry Backoff

By default a failed job is retried on the very next poll. To wait before the next attempt, set `retry_backoff` (in seconds) when you create the queue:

```ruby
# Wait 30 seconds before each retry
queue = Tina4::Queue.new(topic: "emails", max_retries: 3, retry_backoff: 30)
```

### Manual Retry with Delay

`job.retry` is a manual override, distinct from the automatic `fail` path. It always re-queues the job regardless of the retry limit and increments the attempt count. The job already carries its queue reference from `pop`/`consume`, so you only pass the delay:

```ruby
queue.consume("emails") do |job|
  begin
    send_email(job.payload[:to], job.payload[:subject], job.payload[:body])
    job.complete
  rescue => e
    # Re-queue this job to run again 30 seconds from now
    job.retry(delay_seconds: 30)
  end
end
```

### Manual Pop

For more control, pop a single message. `pop` returns the highest-priority available job, or `nil` when the queue is empty:

```ruby
job = queue.pop

unless job.nil?
  begin
    send_email(job.payload[:to], job.payload[:subject])
    job.complete
  rescue => e
    job.fail(e.message)
  end
end
```

### Pop a Specific Job by ID

Pull one known job out of the pending queue with `pop_by_id`. It returns the matching `Job` (claimed from the queue) or `nil` if no pending job has that id:

```ruby
job = queue.pop_by_id("abc-123")
job.complete if job
```

`consume` accepts the same lookup via `id:` -- it processes that single job and returns:

```ruby
queue.consume("emails", id: "abc-123") do |job|
  send_email(job.payload[:to], job.payload[:subject])
  job.complete
end
```

---

## 6. Job Lifecycle

Every job moves through these states:

```
push -> PENDING -> pop/consume -> RESERVED -> job.complete -> COMPLETED (terminal)
                                           -> job.fail     -> attempts += 1
                                                                |
                                              attempts < max_retries
                                                                |
                                                             PENDING (auto re-queue)
                                                                |
                                              attempts >= max_retries
                                                                |
                                                           DEAD LETTER
```

`job.fail` does the bookkeeping automatically: it re-queues the job while it still has retries left, and moves it to the dead-letter store once it has been attempted `max_retries` times.

### Job Methods

When you receive a job from `consume` or `pop`, you have these methods:

- `job.complete` -- mark the job as done. Terminal; the job is removed.
- `job.fail(reason)` -- record a failed attempt with a reason string. Auto re-queues while retries remain, then dead-letters.
- `job.reject(reason)` -- alias for `fail`.
- `job.retry(delay_seconds: 0)` -- manual override. Re-queue the job after an optional delay (in seconds), regardless of the retry limit.

### Job Properties

- `job.id` -- the generated job id.
- `job.payload` -- the data you pushed.
- `job.topic` -- the topic this job belongs to. Useful when consuming from multiple topics.
- `job.attempts` -- how many times the job has been attempted.
- `job.error` -- the reason from the last `fail`/`reject`.

Always call `complete`, `fail`, or `retry` on every job. If you do not, the job stays reserved.

---

## 7. Retry and Dead Letters

### Max Retries

The default `max_retries` is 3. When a job's attempt count reaches `max_retries`, the queue stops retrying it and moves it to the dead-letter store. Set the limit when you create the queue.

### Inspecting Retrying Jobs

`failed` returns the jobs that have failed at least once but are still being retried (attempts above zero, under `max_retries`). These jobs live in the pending queue and will be picked up again automatically. `failed` returns an array of **Hashes**, so use string keys:

```ruby
retrying = queue.failed

retrying.each do |job|
  puts "Retrying job: #{job["id"]} (attempt #{job["attempts"]})"
  puts "  Last error: #{job["error"]}"
end
```

### Dead Letters

Jobs that exhausted `max_retries` are dead letters. `dead_letters` returns an array of **Hashes** -- access fields with string keys:

```ruby
dead_jobs = queue.dead_letters

dead_jobs.each do |job|
  puts "Dead job: #{job["id"]}"
  puts "  Payload: #{job["payload"]}"
  puts "  Error: #{job["error"]}"
end
```

### Reviving Dead Letters

`retry_failed` revives dead-letter jobs (those still under `max_retries`) back to the pending queue and returns the count re-queued. To revive one specific dead-letter job by id, use `queue.retry(job_id)`:

```ruby
# Revive every eligible dead letter
queue.retry_failed

# Revive one specific dead-letter job
queue.retry("abc-123")
```

### Purging Jobs

Remove jobs by status. `"failed"` and `"dead"` remove from the dead-letter store; `"pending"` removes matching jobs from the pending queue:

```ruby
queue.purge("dead")
queue.purge("pending")
```

---

## 8. Producing Multiple Jobs

Sometimes a single action triggers multiple background tasks:

```ruby
Tina4::Router.post("/api/orders") do |request, response|
  body = request.body
  order_id = 101

  queue = Tina4::Queue.new(topic: "emails")

  queue.push({
    order_id: order_id,
    to: body["email"],
    subject: "Order Confirmation"
  })

  queue.produce("invoices", {
    order_id: order_id,
    format: "pdf"
  })

  queue.produce("inventory", {
    items: body["items"]
  })

  queue.produce("warehouse", {
    order_id: order_id,
    shipping_address: body["shipping_address"]
  })

  response.json({
    message: "Order placed successfully",
    order_id: order_id
  }, 201)
end
```

Four jobs are queued in under 5 milliseconds. The user gets an instant response.

---

## 9. Switching Backends

Switching backends is a config change, not a code change.

### Default: File

```bash
# No config needed -- file is the default.
# Jobs are stored as JSON files under ./.queue in the working directory.
```

To store jobs somewhere else, pass a `dir:` option to the backend rather than an environment variable:

```ruby
backend = Tina4::QueueBackends::LiteBackend.new(dir: "./data/queue")
queue = Tina4::Queue.new(topic: "emails", backend: backend)
```

### RabbitMQ

```bash
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://user:pass@localhost:5672
```

### Kafka

```bash
TINA4_QUEUE_BACKEND=kafka
TINA4_QUEUE_URL=localhost:9092
```

### MongoDB

```bash
TINA4_QUEUE_BACKEND=mongodb
TINA4_QUEUE_URL=mongodb://user:pass@localhost:27017/tina4
```

Install the MongoDB driver:

```bash
gem install mongo
```

Your code does not change. The same `queue.push` and `queue.consume` calls work with every backend.

---

## 10. Separate Producer and Consumer Patterns

Use separate `Tina4::Queue` instances in different files or services for clarity:

```ruby
# Producer side (e.g., in a route handler)
queue = Tina4::Queue.new(topic: "emails")
queue.push({ to: "alice@example.com", subject: "Hello" })

# Consumer side (e.g., in a worker script)
queue = Tina4::Queue.new(topic: "emails")
queue.consume("emails") do |job|
  process(job)
  job.complete
end
```

The same `Tina4::Queue` class handles both producing and consuming. Separate instances in different files make intent clearer.

---

## 11. Exercise: Build an Email Queue

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

### Test with:

```bash
curl -X POST http://localhost:7147/api/emails/send \
  -H "Content-Type: application/json" \
  -d '{"to": "alice@example.com", "subject": "Welcome!", "body": "Thanks for signing up."}'

curl http://localhost:7147/api/emails/queue

curl http://localhost:7147/api/emails/dead

curl -X POST http://localhost:7147/api/emails/retry
```

---

## 12. Solution

Create `src/routes/email_queue.rb`:

```ruby
queue = Tina4::Queue.new(topic: "emails")

# @noauth
Tina4::Router.post("/api/emails/send") do |request, response|
  body = request.body

  errors = []
  errors << "'to' is required" if body["to"].nil? || body["to"].empty?
  errors << "'subject' is required" if body["subject"].nil? || body["subject"].empty?
  errors << "'body' is required" if body["body"].nil? || body["body"].empty?

  unless errors.empty?
    return response.json({ errors: errors }, 400)
  end

  job = queue.push({
    to: body["to"],
    subject: body["subject"],
    body: body["body"]
  })

  response.json({
    message: "Email queued for sending",
    job_id: job.id
  }, 201)
end

Tina4::Router.get("/api/emails/queue") do |request, response|
  count = queue.size
  response.json({ pending: count })
end

Tina4::Router.get("/api/emails/dead") do |request, response|
  dead_jobs = queue.dead_letters
  items = dead_jobs.map do |job|
    { id: job["id"], payload: job["payload"], error: job["error"] }
  end
  response.json({ dead_letters: items, count: items.length })
end

Tina4::Router.post("/api/emails/retry") do |request, response|
  queue.retry_failed
  response.json({ message: "Dead-letter emails re-queued" })
end
```

Create a separate consumer file `src/workers/email_worker.rb`:

```ruby
queue = Tina4::Queue.new(topic: "emails", max_retries: 3)

queue.consume("emails") do |job|
  payload = job.payload

  puts "Sending email to #{payload[:to]}..."
  puts "  Subject: #{payload[:subject]}"

  begin
    # Simulate sending (replace with real email logic)
    sleep(1)

    # Simulate failure for a specific address
    if payload[:to] == "bad@example.com"
      raise "SMTP connection refused"
    end

    puts "  Email sent to #{payload[:to]} successfully!"
    job.complete

  rescue => e
    puts "  Failed: #{e.message}"
    job.fail(e.message)
  end
end
```

The consumer retries a failing job to `bad@example.com` automatically. After `max_retries` attempts, `queue.dead_letters` returns that job, and the `/api/emails/dead` endpoint shows it. You investigate, fix the address, and call `/api/emails/retry` to revive it.

---

## 13. Gotchas

### 1. Always call complete or fail

**Problem:** Jobs stay in reserved status forever.

**Cause:** Your consumer block does not call `job.complete` or `job.fail`. The job stays reserved and is never released.

**Fix:** Always call one of `job.complete`, `job.fail(reason)`, or `job.reject(reason)` in your consumer block.

### 2. Worker not picking up messages

**Problem:** Messages are pushed but nothing happens.

**Cause:** No consumer process is running, or the consumer is listening on a different topic.

**Fix:** Make sure the consumer is running. Check that the topic name in `queue.push` matches the topic in `queue.consume`.

### 3. Payload must be serializable

**Problem:** `queue.push` throws an error.

**Cause:** You passed a non-serializable object (database connection, file handle, etc.).

**Fix:** Only pass simple data types in the payload. If you need to reference a database record, pass the ID. The consumer looks up records by ID.

### 4. Dead letters pile up

**Problem:** Dead letters accumulate and nobody notices.

**Cause:** Jobs that exhaust `max_retries` become dead letters but are never cleaned up.

**Fix:** Monitor dead letters with `queue.dead_letters`. Set up an alert when the count exceeds a threshold. Investigate, fix, then call `queue.retry_failed` or `queue.purge("dead")`.

### 5. File backend for production

**Problem:** Multiple workers cause contention on the file backend.

**Cause:** The file backend is designed for single-worker setups.

**Fix:** For production with multiple workers, switch to RabbitMQ, Kafka, or MongoDB via the `TINA4_QUEUE_BACKEND` environment variable.

### 6. dead_letters and failed return Hashes

**Problem:** `job.id` or `job.payload` raises `NoMethodError` when iterating `dead_letters` or `failed`.

**Cause:** `dead_letters` and `failed` return arrays of Hashes, not `Job` objects.

**Fix:** Use string keys: `job["id"]`, `job["payload"]`, `job["error"]`, `job["attempts"]`.
