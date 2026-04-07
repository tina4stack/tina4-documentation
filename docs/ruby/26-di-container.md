# Chapter 25: Dependency Injection Container

## 1. The Problem With Hard Dependencies

Your route handler creates a `Tina4::Database` instance directly. Your mailer instantiates its SMTP connection inline. Your PDF generator calls `Tina4::Api.new(...)` inside the method body.

Hard dependencies make code hard to test (you cannot swap the real database for a fake one), hard to reconfigure (the connection string is buried in 12 files), and hard to share (every caller creates its own instance instead of sharing one).

A DI container is a registry. You register services by name once. Everything that needs a service asks the container for it by name. Tests register fake implementations. Production registers real ones.

---

## 2. Registering a Service

```ruby
Tina4::Container.register(:database) do
  Tina4::Database.new(ENV["DATABASE_URL"])
end
```

The block is a factory. It runs the first time the service is resolved (lazy initialization). The result is cached and reused for every subsequent resolve.

### Registering Multiple Services

```ruby
Tina4::Container.register(:database) do
  Tina4::Database.new(ENV["DATABASE_URL"])
end

Tina4::Container.register(:cache) do
  Tina4::Cache.new(backend: :memory)
end

Tina4::Container.register(:stripe) do
  Tina4::Api.new("https://api.stripe.com", {
    "Authorization"  => "Bearer #{ENV['STRIPE_SECRET_KEY']}",
    "Content-Type"   => "application/json",
    "Stripe-Version" => "2024-11-20"
  })
end

Tina4::Container.register(:mailer) do
  Tina4::Mailer.new(
    host:     ENV["SMTP_HOST"],
    port:     ENV["SMTP_PORT"].to_i,
    username: ENV["SMTP_USER"],
    password: ENV["SMTP_PASS"]
  )
end
```

---

## 3. Resolving a Service

```ruby
db = Tina4::Container.resolve(:database)
users = db.query("SELECT * FROM users")
```

The first `resolve` call runs the factory block and caches the result. Every subsequent call returns the same instance.

---

## 4. Checking Registration

```ruby
if Tina4::Container.registered?(:cache)
  cache = Tina4::Container.resolve(:cache)
  cached = cache.get("products:list")
end
```

---

## 5. Using Services in Route Handlers

```ruby
# @noauth
Tina4::Router.get("/api/users") do |request, response|
  db = Tina4::Container.resolve(:database)

  users = db.query("SELECT id, name, email FROM users")

  response.json({ users: users, count: users.length })
end

Tina4::Router.post("/api/orders") do |request, response|
  body   = request.body
  db     = Tina4::Container.resolve(:database)
  mailer = Tina4::Container.resolve(:mailer)
  stripe = Tina4::Container.resolve(:stripe)

  result = stripe.post("/v1/payment_intents", body: {
    amount:   (body["total"].to_f * 100).to_i,
    currency: "usd"
  })

  unless result.success?
    next response.json({ error: "Payment failed" }, 402)
  end

  order_id = db.execute(
    "INSERT INTO orders (email, total, payment_intent) VALUES (?, ?, ?)",
    body["email"], body["total"], result.body["id"]
  )

  mailer.send(
    to:      body["email"],
    subject: "Order Confirmation",
    body:    "Your order ##{order_id} has been placed."
  )

  response.json({ order_id: order_id }, 201)
end
```

---

## 6. clear!: Reset the Container

Remove all registered services and their cached instances.

```ruby
Tina4::Container.clear!
```

Use `clear!` in tests to start fresh between test cases and register test doubles.

---

## 7. Testing With the Container

Swap real services for fakes in tests without changing production code.

```ruby
# test/test_orders.rb
require "minitest/autorun"

class FakeMailer
  attr_reader :sent

  def initialize
    @sent = []
  end

  def send(opts)
    @sent << opts
  end
end

class FakeStripe
  def post(path, body:)
    OpenStruct.new(
      success?: true,
      body: { "id" => "pi_test_123" }
    )
  end
end

class FakeDatabase
  def execute(sql, *args)
    42  # Simulated insert returning an ID
  end
end

class OrderTest < Minitest::Test
  def setup
    Tina4::Container.clear!
    @mailer = FakeMailer.new

    Tina4::Container.register(:database) { FakeDatabase.new }
    Tina4::Container.register(:mailer)   { @mailer }
    Tina4::Container.register(:stripe)   { FakeStripe.new }
  end

  def teardown
    Tina4::Container.clear!
  end

  def test_order_sends_confirmation_email
    # Simulate a POST /api/orders request
    # ...route invocation logic...

    assert_equal 1, @mailer.sent.length
    assert_equal "Order Confirmation", @mailer.sent.first[:subject]
  end
end
```

No real database, no real Stripe, no real email -- the test runs in milliseconds and never touches external services.

---

## 8. Service Dependencies

A factory block can resolve other services from the container.

```ruby
Tina4::Container.register(:order_service) do
  db     = Tina4::Container.resolve(:database)
  mailer = Tina4::Container.resolve(:mailer)
  stripe = Tina4::Container.resolve(:stripe)

  OrderService.new(db: db, mailer: mailer, stripe: stripe)
end
```

```ruby
class OrderService
  def initialize(db:, mailer:, stripe:)
    @db     = db
    @mailer = mailer
    @stripe = stripe
  end

  def place(email:, total:)
    result = @stripe.post("/v1/payment_intents", body: {
      amount: (total * 100).to_i, currency: "usd"
    })

    raise "Payment failed" unless result.success?

    order_id = @db.execute(
      "INSERT INTO orders (email, total) VALUES (?, ?)", email, total
    )

    @mailer.send(to: email, subject: "Order ##{order_id} confirmed")

    order_id
  end
end
```

```ruby
Tina4::Router.post("/api/orders") do |request, response|
  body    = request.body
  service = Tina4::Container.resolve(:order_service)

  order_id = service.place(email: body["email"], total: body["total"].to_f)
  response.json({ order_id: order_id }, 201)
rescue => e
  response.json({ error: e.message }, 500)
end
```

The route handler has one job: parse the request, delegate to the service, return the response.

---

## 9. Gotchas

### 1. clear! drops cached instances

`clear!` removes the factory registration and the cached instance. Any subsequent `resolve` after `clear!` raises unless you re-register.

### 2. Singletons by default

The container caches the first resolved instance. If your service is not thread-safe, wrapping it in a mutex or using a new instance per request is safer.

### 3. Circular dependencies cause infinite loops

If service A resolves B, and B resolves A during factory execution, the container loops forever. Restructure to break the cycle.

### 4. Registration order matters

A factory block that resolves `:database` runs when it is first resolved, not when it is registered. Registration order does not matter. Resolution order does.
