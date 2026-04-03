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

# Push a job
queue.push({
  to: "alice@example.com",
  subject: "Order Confirmation",
  body: "Your order #1234 has been confirmed."
})
```

### Convenience Method: produce

The `produce` method pushes to a specific topic without creating a separate Queue instance:

```ruby
queue = Tina4::Queue.new(topic: "emails")
queue.produce("invoices", { order_id: 101, format: "pdf" })
```

### Push with Priority

Jobs default to priority 0 (normal). Higher numbers are popped first:

```ruby
# Normal priority (default)
queue.push({ to: "alice@example.com", subject: "Newsletter" })

# High priority -- processed before normal jobs
queue.push({ to: "alice@example.com", subject: "Password Reset" }, priority: 10)
```

### Queue Size

Check how many pending messages are in the queue:

```ruby
count = queue.size
```

Pass a status keyword to count jobs in a specific state:

```ruby
failed = queue.size(status: "failed")
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

### Retry with Delay

If a job fails but you want to retry it after a cooldown instead of marking it as failed:

```ruby
queue.consume("emails") do |job|
  begin
    send_email(job.payload[:to], job.payload[:subject], job.payload[:body])
    job.complete
  rescue => e
    # Retry after 30 seconds instead of failing immediately
    job.retry(queue: queue, delay_seconds: 30)
  end
end
```

### Manual Pop

For more control, pop a single message:

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

---

## 6. Job Lifecycle

Every job moves through states:

```
push -> PENDING -> pop/consume -> RESERVED -> job.complete -> COMPLETED
                                           -> job.fail     -> FAILED
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

- `job.complete` -- mark the job as done
- `job.fail(reason)` -- mark the job as failed with a reason string
- `job.reject(reason)` -- alias for `fail`
- `job.retry(queue: queue, delay_seconds: 30)` -- re-queue the job after a delay (in seconds). The job goes back to PENDING after the delay elapses. You must pass the `queue` reference.

### Job Properties

- `job.topic` -- the topic this job belongs to. Useful when consuming from multiple topics.

Always call `complete`, `fail`, or `retry` on every job. If you do not, the job stays reserved.

---

## 7. Retry and Dead Letters

### Max Retries

The default `max_retries` is 3. When a job's attempt count reaches `max_retries`, `retry_failed` skips it.

### Retrying Failed Jobs

```ruby
# Retry all failed jobs (skips those that exceeded max_retries)
queue.retry_failed
```

### Dead Letters

Jobs that have exceeded `max_retries` are dead letters. There is no magic dead letter queue -- you retrieve and handle them yourself:

```ruby
dead_jobs = queue.dead_letters

dead_jobs.each do |job|
  puts "Dead job: #{job.id}"
  puts "  Payload: #{job.payload}"
  puts "  Error: #{job.error}"
end
```

### Purging Jobs

Remove jobs by status:

```ruby
queue.purge("completed")
queue.purge("failed")
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
| `POST` | `/api/emails/retry` | Retry all failed jobs |

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

  message_id = queue.push({
    to: body["to"],
    subject: body["subject"],
    body: body["body"]
  })

  response.json({
    message: "Email queued for sending",
    message_id: message_id
  }, 201)
end

Tina4::Router.get("/api/emails/queue") do |request, response|
  count = queue.size
  response.json({ pending: count })
end

Tina4::Router.get("/api/emails/dead") do |request, response|
  dead_jobs = queue.dead_letters
  items = dead_jobs.map do |job|
    { id: job.id, payload: job.payload, error: job.error }
  end
  response.json({ dead_letters: items, count: items.length })
end

Tina4::Router.post("/api/emails/retry") do |request, response|
  queue.retry_failed
  response.json({ message: "Failed emails re-queued for retry" })
end
```

Create a separate consumer file `src/workers/email_worker.rb`:

```ruby
queue = Tina4::Queue.new(topic: "emails")

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

After the consumer has retried a job to `bad@example.com` three times, `queue.dead_letters` returns that job. The `/api/emails/dead` endpoint shows it. You investigate, fix the address, and call `/api/emails/retry` to re-queue.

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

**Cause:** Failed jobs that exceed `max_retries` become dead letters but are never cleaned up.

**Fix:** Monitor dead letters with `queue.dead_letters`. Set up an alert when the count exceeds a threshold. Investigate, fix, then call `queue.retry_failed` or `queue.purge("failed")`.

### 5. File backend for production

**Problem:** Multiple workers cause contention on the file backend.

**Cause:** The file backend is designed for single-worker setups.

**Fix:** For production with multiple workers, switch to RabbitMQ, Kafka, or MongoDB via the `TINA4_QUEUE_BACKEND` environment variable.

### 6. Consumer block returns nothing useful

**Problem:** Jobs are processed but the system does not track completion.

**Cause:** Your consumer block does not call `job.complete`. Without an explicit call, the job stays reserved.

**Fix:** Always call `job.complete` when the job succeeds and `job.fail(reason)` when it fails.
