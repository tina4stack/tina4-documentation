# Chapter 26: Service Runner

## 1. Work That Runs Forever

Some work does not fit inside an HTTP request. A heartbeat that pings a health check endpoint every 30 seconds. A metrics collector that samples memory usage every minute. A subscription renewal job that runs at midnight. A queue consumer that processes jobs continuously.

These are background services: long-running processes that start with the app and run until it stops.

Tina4's Service Runner manages background services. Register a service with a name and a block. The runner starts it in a background thread. The service runs for the lifetime of the app. If it crashes, the runner restarts it.

---

## 2. Defining a Service

```ruby
Tina4::ServiceRunner.register("heartbeat") do
  loop do
    Tina4::Log.info("Heartbeat", status: "alive", time: Time.now.utc.iso8601)
    sleep 30
  end
end
```

The block runs in a background thread. The `loop` keeps it alive. `sleep 30` yields control between iterations.

---

## 3. Starting All Services

```ruby
Tina4::ServiceRunner.start_all
```

Call this once, typically in your app startup file after route definitions. All registered services start in background threads.

```ruby
# config/app.rb

require_relative "../src/routes/api"
require_relative "../src/services/background"

Tina4::ServiceRunner.start_all
```

---

## 4. Starting a Single Service

```ruby
Tina4::ServiceRunner.start("heartbeat")
```

Useful for starting services conditionally based on environment or configuration.

---

## 5. Stopping Services

```ruby
# Stop a specific service
Tina4::ServiceRunner.stop("heartbeat")

# Stop all running services
Tina4::ServiceRunner.stop_all
```

`stop` signals the thread to terminate. The runner waits for the thread to finish its current iteration before stopping.

---

## 6. Checking Service Status

```ruby
Tina4::ServiceRunner.running?("heartbeat")
# => true or false

Tina4::ServiceRunner.status
# => { "heartbeat" => :running, "metrics" => :stopped, "queue_consumer" => :running }
```

---

## 7. Automatic Restart on Failure

If a service crashes, the runner restarts it with an exponential backoff delay.

```ruby
Tina4::ServiceRunner.register("unreliable_service") do
  loop do
    begin
      do_something_that_might_fail
      sleep 10
    rescue => e
      Tina4::Log.error("Service error", service: "unreliable_service", error: e.message)
      # re-raise to trigger restart, or rescue and continue
      raise
    end
  end
end
```

If the block raises, the runner logs the error, waits (1s, 2s, 4s... up to 60s), then restarts the service.

Set `max_restarts` to cap automatic restarts:

```ruby
Tina4::ServiceRunner.register("payment_sync", max_restarts: 5) do
  # ...
end
```

After 5 restarts, the service is marked as `:failed` and not restarted again.

---

## 8. Queue Consumer Service

The most common background service: processing a queue continuously.

```ruby
Tina4::ServiceRunner.register("email_consumer") do
  queue = Tina4::Queue.new(topic: "emails")

  loop do
    job = queue.pop

    if job.nil?
      sleep 2  # No jobs -- wait before polling again
      next
    end

    begin
      payload = job.payload
      send_email(payload[:to], payload[:subject], payload[:body])
      job.complete

      Tina4::Log.info("Email sent", to: payload[:to], subject: payload[:subject])
    rescue => e
      job.fail(e.message)
      Tina4::Log.error("Email failed", to: payload[:to], error: e.message)
    end
  end
end
```

---

## 9. Scheduled Task Service

Run a task on a schedule using a service with sleep-based timing.

```ruby
Tina4::ServiceRunner.register("daily_report") do
  loop do
    now = Time.now

    # Run at 08:00 every day
    if now.hour == 8 && now.min == 0
      Tina4::Log.info("Generating daily report")

      db = Tina4::Container.resolve(:database)
      rows = db.query("SELECT COUNT(*) as orders FROM orders WHERE DATE(created_at) = DATE('now')")

      Tina4::Log.info("Daily report complete", orders_today: rows.first["orders"])

      sleep 61  # Skip past the current minute to avoid re-running
    else
      sleep 30  # Check every 30 seconds
    end
  end
end
```

---

## 10. Metrics Collector Service

```ruby
Tina4::ServiceRunner.register("metrics_collector") do
  loop do
    mem_mb = `ps -o rss= -p #{Process.pid}`.strip.to_i / 1024

    Tina4::Log.info("Metrics",
      memory_mb:  mem_mb,
      pid:        Process.pid,
      threads:    Thread.list.count
    )

    sleep 60
  end
end
```

---

## 11. Listing Registered Services

```ruby
Tina4::ServiceRunner.services.each do |name, info|
  puts "#{name}: #{info[:status]}"
end
```

Output:

```
heartbeat: running
email_consumer: running
daily_report: running
metrics_collector: running
```

---

## 12. Shutdown Hooks

Register cleanup logic that runs when a service is stopped.

```ruby
Tina4::ServiceRunner.register("database_sync") do |service|
  db = Tina4::Container.resolve(:database)

  service.on_stop do
    Tina4::Log.info("Database sync shutting down -- flushing pending writes")
    db.flush
  end

  loop do
    sync_records(db)
    sleep 5
  end
end
```

---

## 13. Gotchas

### 1. Services share the main process

Background services run in threads, not separate processes. A runaway service that consumes 100% CPU affects the HTTP server running in the same process. Keep service work lightweight or move heavy computation to separate processes via the queue system.

### 2. sleep is required in loops

A `loop` with no `sleep` spins the CPU at 100%. Always `sleep` between iterations.

### 3. Thread safety

Services share memory with the main thread. Access shared mutable state (global variables, class variables, shared caches) through a mutex.

```ruby
COUNTER_MUTEX = Mutex.new
COUNTER = { value: 0 }

Tina4::ServiceRunner.register("counter_service") do
  loop do
    COUNTER_MUTEX.synchronize { COUNTER[:value] += 1 }
    sleep 1
  end
end
```

### 4. stop_all on shutdown

In production, call `Tina4::ServiceRunner.stop_all` in a signal trap to cleanly shut down services before the process exits.

```ruby
trap("SIGTERM") do
  Tina4::ServiceRunner.stop_all
  exit 0
end
```
