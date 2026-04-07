# Chapter 13: Events

## 1. Decouple With Events

Your user registration handler validates input, creates the account, sends a welcome email, creates an activity log entry, and notifies an analytics service. Seven responsibilities crammed into one method. Adding an eighth means editing that method again.

Events decouple producers from consumers. The registration handler fires `user.registered`. Any number of listeners react to it — email, analytics, logging — without the handler knowing they exist. Adding a new reaction is adding a new listener.

Tina4's event system is in-process, synchronous by default, and zero dependency. No broker, no serialization, no network.

---

## 2. Basic Usage

### Registering a Listener

```ruby
Tina4::Events.on("user.registered") do |payload|
  puts "Welcome #{payload[:name]}!"
end
```

### Emitting an Event

```ruby
Tina4::Events.emit("user.registered", {
  id: 42,
  name: "Alice",
  email: "alice@example.com"
})
```

Output:

```
Welcome Alice!
```

Listeners receive whatever hash you pass to `emit`. Use symbol keys consistently.

---

## 3. Multiple Listeners

Register as many listeners as you like for the same event. All fire in registration order by default.

```ruby
Tina4::Events.on("order.placed") do |payload|
  puts "Sending confirmation email to #{payload[:email]}"
end

Tina4::Events.on("order.placed") do |payload|
  puts "Reserving inventory for order ##{payload[:order_id]}"
end

Tina4::Events.on("order.placed") do |payload|
  puts "Notifying warehouse for shipping"
end

Tina4::Events.emit("order.placed", {
  order_id: 101,
  email: "alice@example.com",
  items: [{ sku: "KB-100", qty: 1 }]
})
```

Output:

```
Sending confirmation email to alice@example.com
Reserving inventory for order #101
Notifying warehouse for shipping
```

---

## 4. Priority

Control listener order with `priority`. Higher numbers run first.

```ruby
Tina4::Events.on("payment.received", priority: 10) do |payload|
  puts "FRAUD CHECK first (priority 10)"
end

Tina4::Events.on("payment.received", priority: 5) do |payload|
  puts "Fulfill order second (priority 5)"
end

Tina4::Events.on("payment.received", priority: 1) do |payload|
  puts "Send receipt last (priority 1)"
end

Tina4::Events.emit("payment.received", { order_id: 201, amount: 99.99 })
```

Output:

```
FRAUD CHECK first (priority 10)
Fulfill order second (priority 5)
Send receipt last (priority 1)
```

Default priority is `0`. Listeners with the same priority run in registration order.

---

## 5. Once: Fire a Listener One Time

`once` registers a listener that fires exactly once and then removes itself.

```ruby
Tina4::Events.once("app.started") do |payload|
  puts "App started at #{payload[:time]} -- this fires only once"
end

Tina4::Events.emit("app.started", { time: Time.now.utc.iso8601 })
Tina4::Events.emit("app.started", { time: Time.now.utc.iso8601 })
```

Output:

```
App started at 2026-04-02T09:00:00Z -- this fires only once
```

The second emit produces no output. The listener is gone after the first call.

Use `once` for initialization tasks, welcome messages, or any logic that must run exactly one time.

---

## 6. off: Remove a Listener

To remove a specific listener, keep a reference to the block.

```ruby
logger = Tina4::Events.on("request.received") do |payload|
  puts "Request: #{payload[:method]} #{payload[:path]}"
end

Tina4::Events.emit("request.received", { method: "GET", path: "/api/users" })

# Remove the listener
Tina4::Events.off("request.received", logger)

Tina4::Events.emit("request.received", { method: "POST", path: "/api/users" })
```

Output:

```
Request: GET /api/users
```

The second emit fires no listener -- it was removed.

---

## 7. clear: Remove All Listeners

Remove all listeners for an event, or all listeners for all events.

```ruby
# Clear listeners for a specific event
Tina4::Events.clear("order.placed")

# Clear all listeners for all events
Tina4::Events.clear
```

Use `clear` in tests to avoid listener bleed between test cases.

```ruby
RSpec.describe "Order processing" do
  after(:each) { Tina4::Events.clear }

  it "sends confirmation email" do
    received = []
    Tina4::Events.on("order.placed") { |p| received << p[:email] }
    Tina4::Events.emit("order.placed", { email: "alice@example.com" })
    expect(received).to eq(["alice@example.com"])
  end
end
```

---

## 8. Events in Route Handlers

Wire events into your HTTP layer to keep handlers thin.

```ruby
# src/routes/orders.rb

# @noauth
Tina4::Router.post("/api/orders") do |request, response|
  body = request.body

  order = {
    id: rand(1000..9999),
    email: body["email"],
    items: body["items"],
    total: body["total"]
  }

  Tina4::Events.emit("order.placed", order)

  response.json({ message: "Order received", order_id: order[:id] }, 201)
end
```

```ruby
# src/listeners/order_listeners.rb

Tina4::Events.on("order.placed") do |order|
  puts "Email: Confirmation sent to #{order[:email]}"
end

Tina4::Events.on("order.placed") do |order|
  puts "Inventory: #{order[:items].length} item type(s) reserved"
end

Tina4::Events.on("order.placed", priority: 10) do |order|
  puts "Audit: Order #{order[:id]} logged"
end
```

```bash
curl -X POST http://localhost:7147/api/orders \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","items":[{"sku":"KB-100","qty":1}],"total":79.99}'
```

```json
{ "message": "Order received", "order_id": 5823 }
```

Server output:

```
Audit: Order 5823 logged
Email: Confirmation sent to alice@example.com
Inventory: 1 item type(s) reserved
```

---

## 9. Listing Registered Events

Inspect what listeners are registered.

```ruby
Tina4::Events.listeners("order.placed").each do |listener|
  puts "Priority #{listener[:priority]}"
end
```

---

## 10. Gotchas

### 1. Listeners run synchronously

Events are in-process and synchronous. If a listener takes 3 seconds, `emit` blocks for 3 seconds. For slow work, push to a queue inside the listener instead of doing the work directly.

```ruby
Tina4::Events.on("order.placed") do |order|
  queue = Tina4::Queue.new(topic: "emails")
  queue.push({ to: order[:email], subject: "Order Confirmation" })
end
```

### 2. Exceptions in listeners

If a listener raises an exception, subsequent listeners for the same event do not run. Wrap listener logic in `rescue` when reliability matters.

```ruby
Tina4::Events.on("payment.received") do |payload|
  begin
    process_payment(payload)
  rescue => e
    puts "Payment listener error: #{e.message}"
  end
end
```

### 3. clear in tests

Always call `Tina4::Events.clear` in `after(:each)` blocks. Listeners registered in one test persist into the next unless explicitly removed.

### 4. once is not thread-safe by design

`once` is intended for single-threaded initialization sequences. Do not use it in concurrent request handlers -- the listener may fire multiple times before the first call completes removal.
