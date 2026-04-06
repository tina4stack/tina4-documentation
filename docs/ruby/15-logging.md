# Chapter 15: Structured Logging

## 1. puts Is Not a Logging Strategy

`puts` dumps raw text to stdout. No timestamps. No severity levels. No structured fields. Searching through 50,000 lines of `puts` output for a production error at 2:47 AM is the pain that structured logging prevents.

Structured logging records every entry as a consistent, parseable event: timestamp, level, message, and any additional fields you provide. Log aggregators (Datadog, Elastic, CloudWatch) can filter, group, and alert on structured logs automatically. Plain text output cannot.

Tina4's logger writes structured entries, supports configurable levels, and is available everywhere in your app.

---

## 2. Log Levels

Five levels, in order of increasing severity:

| Level | Method | When to use |
|-------|--------|-------------|
| DEBUG | `Tina4::Log.debug` | Detailed trace — request internals, query params, timings |
| INFO | `Tina4::Log.info` | Normal operations — request received, user logged in |
| WARNING | `Tina4::Log.warning` | Something unexpected but recoverable — deprecated API called |
| ERROR | `Tina4::Log.error` | Something broke but the app is still running |
| FATAL | `Tina4::Log.fatal` | Unrecoverable error — app cannot continue |

---

## 3. Basic Usage

```ruby
Tina4::Log.debug("Cache miss", key: "products:list")
Tina4::Log.info("User logged in", user_id: 42, email: "alice@example.com")
Tina4::Log.warning("Deprecated endpoint called", path: "/api/v1/products")
Tina4::Log.error("Database query failed", table: "orders", error: "connection timeout")
Tina4::Log.fatal("Out of memory -- shutting down")
```

Output (text format):

```
[2026-04-02 09:00:01 UTC] DEBUG  Cache miss | key=products:list
[2026-04-02 09:00:02 UTC] INFO   User logged in | user_id=42 email=alice@example.com
[2026-04-02 09:00:03 UTC] WARN   Deprecated endpoint called | path=/api/v1/products
[2026-04-02 09:00:04 UTC] ERROR  Database query failed | table=orders error=connection timeout
[2026-04-02 09:00:05 UTC] FATAL  Out of memory -- shutting down
```

Each entry has a timestamp, level, message, and any keyword arguments you passed as structured fields.

---

## 4. Controlling the Log Level

Set the minimum log level via the `TINA4_LOG_LEVEL` environment variable. Entries below this level are silently dropped.

```bash
TINA4_LOG_LEVEL=info
```

Valid values (case-insensitive): `debug`, `info`, `warning`, `error`, `fatal`.

With `TINA4_LOG_LEVEL=info`, `Tina4::Log.debug(...)` calls produce no output. With `TINA4_LOG_LEVEL=error`, only `error` and `fatal` entries appear.

Default is `info` in production and `debug` in development (detected via `TINA4_ENV`).

---

## 5. Setting the Level in Code

```ruby
Tina4::Log.level = :debug
Tina4::Log.level = :info
Tina4::Log.level = :warning
Tina4::Log.level = :error
Tina4::Log.level = :fatal
```

The environment variable takes precedence over the in-code setting at startup. Changing it at runtime affects all subsequent log calls.

---

## 6. Logging in Route Handlers

```ruby
Tina4::Router.get("/api/products/:id") do |request, response|
  id = request.params["id"].to_i

  Tina4::Log.debug("Product lookup", product_id: id)

  product = Product.find(id)

  if product.nil?
    Tina4::Log.warning("Product not found", product_id: id)
    next response.json({ error: "Product not found" }, 404)
  end

  Tina4::Log.info("Product retrieved", product_id: id, name: product.name)
  response.json({ product: product.to_h })
end
```

---

## 7. Logging Errors with Exceptions

Pass the exception message as a structured field.

```ruby
Tina4::Router.post("/api/orders") do |request, response|
  begin
    body = request.body
    order = create_order(body)

    Tina4::Log.info("Order created", order_id: order[:id], total: order[:total])
    response.json({ order_id: order[:id] }, 201)

  rescue ArgumentError => e
    Tina4::Log.warning("Invalid order payload", error: e.message)
    response.json({ error: e.message }, 400)

  rescue => e
    Tina4::Log.error("Order creation failed",
      error: e.message,
      backtrace: e.backtrace.first(3).join(" | ")
    )
    response.json({ error: "Internal server error" }, 500)
  end
end
```

---

## 8. Request Logging Middleware

Add the `RequestLogger` middleware to log every inbound request automatically.

```ruby
Tina4::Router.get("/api/users", middleware: ["RequestLogger"]) do |request, response|
  response.json({ users: [] })
end
```

The middleware logs:

```
[2026-04-02 09:01:00 UTC] INFO  Request | method=GET path=/api/users ip=127.0.0.1
[2026-04-02 09:01:00 UTC] INFO  Response | method=GET path=/api/users status=200 duration_ms=4
```

Apply it globally via config to log every route:

```ruby
# config/app.rb
Tina4::Config.middleware = ["RequestLogger"]
```

---

## 9. JSON Output Format

For log aggregators, switch to JSON output:

```bash
TINA4_LOG_FORMAT=json
```

The same calls now produce:

```json
{"timestamp":"2026-04-02T09:00:02Z","level":"INFO","message":"User logged in","user_id":42,"email":"alice@example.com"}
{"timestamp":"2026-04-02T09:00:04Z","level":"ERROR","message":"Database query failed","table":"orders","error":"connection timeout"}
```

One JSON object per line. Compatible with Datadog, Elastic, CloudWatch, and any log drain that understands NDJSON.

---

## 10. Writing to a File

```bash
TINA4_LOG_FILE=logs/app.log
```

The logger writes to the file and to stdout simultaneously. Log rotation is handled by the OS log rotation tool (logrotate on Linux, newsyslog on macOS).

---

## 11. Checking the Current Level

```ruby
if Tina4::Log.debug?
  # Build expensive debug payload only if debug logging is active
  Tina4::Log.debug("Query plan", plan: db.explain(query).inspect)
end
```

Available predicates: `debug?`, `info?`, `warning?`, `error?`, `fatal?`.

---

## 12. Gotchas

### 1. Never log passwords or tokens

```ruby
# Wrong
Tina4::Log.info("Login attempt", password: params["password"])

# Right
Tina4::Log.info("Login attempt", email: params["email"])
```

### 2. Avoid string interpolation in the message

```ruby
# Slower -- builds the string even if the level is filtered
Tina4::Log.debug("User #{user.id} loaded #{records.count} records")

# Faster -- fields are only serialized if the level passes
Tina4::Log.debug("Records loaded", user_id: user.id, count: records.count)
```

### 3. DEBUG in production floods logs

Set `TINA4_LOG_LEVEL=info` in production. Debug output at scale produces millions of lines per hour and obscures real errors.

### 4. fatal does not exit

`Tina4::Log.fatal(...)` logs at the fatal level but does not call `exit`. Call `abort` or `Process.exit(1)` explicitly after logging an unrecoverable condition.
