# Chapter 21: API Client

## 1. Talking to Other Services

Your app does not live in isolation. It calls payment gateways, weather APIs, shipping providers, CRM platforms, and internal microservices. Each call needs a base URL, auth headers, timeout handling, and response parsing.

Tina4's API client handles that boilerplate. One configured instance gives you clean `get`, `post`, `put`, and `delete` calls with a consistent response format and no external gem required.

---

## 2. Creating a Client

```ruby
client = Tina4::Api.new("https://api.example.com")
```

All requests use this base URL. Paths are appended to it.

### With Default Headers

```ruby
client = Tina4::Api.new("https://api.example.com", {
  "Content-Type" => "application/json",
  "Accept"       => "application/json"
})
```

Headers set here are sent with every request.

---

## 3. GET Requests

```ruby
result = client.get("/products")

if result.success?
  puts result.body.inspect
else
  puts "Error #{result.status}: #{result.body}"
end
```

### With Query Parameters

```ruby
result = client.get("/products", params: { category: "keyboards", in_stock: true })
# Requests: GET /products?category=keyboards&in_stock=true
```

### Response Object

Every call returns a response object with:

- `result.success?` -- true if HTTP status is 2xx
- `result.status` -- integer HTTP status code
- `result.body` -- parsed JSON (Hash or Array) or raw string
- `result.headers` -- response headers Hash

---

## 4. POST Requests

```ruby
result = client.post("/orders", body: {
  email: "alice@example.com",
  items: [{ sku: "KB-100", qty: 1 }],
  total: 79.99
})

if result.success?
  order_id = result.body["id"]
  puts "Order created: #{order_id}"
else
  puts "Failed: #{result.body["message"]}"
end
```

The body is serialized to JSON automatically. The `Content-Type: application/json` header is set if not already present.

---

## 5. PUT Requests

```ruby
result = client.put("/orders/101", body: {
  status: "shipped",
  tracking_number: "1Z999AA10123456784"
})

puts result.success? ? "Updated" : "Failed: #{result.status}"
```

---

## 6. DELETE Requests

```ruby
result = client.delete("/orders/101")

if result.success?
  puts "Order deleted"
else
  puts "Delete failed: #{result.status}"
end
```

---

## 7. Authentication Headers

### Bearer Token

```ruby
client = Tina4::Api.new("https://api.example.com", {
  "Authorization" => "Bearer #{ENV['API_TOKEN']}",
  "Content-Type"  => "application/json"
})
```

### API Key Header

```ruby
client = Tina4::Api.new("https://api.stripe.com", {
  "Authorization" => "Bearer #{ENV['STRIPE_SECRET_KEY']}",
  "Stripe-Version" => "2024-11-20"
})
```

### Basic Auth

```ruby
require "base64"

credentials = Base64.strict_encode64("#{ENV['API_USER']}:#{ENV['API_PASS']}")

client = Tina4::Api.new("https://api.example.com", {
  "Authorization" => "Basic #{credentials}"
})
```

### Per-Request Header Override

Pass headers directly on a single call to override or extend the defaults:

```ruby
result = client.get("/admin/users", headers: {
  "X-Admin-Token" => "secret-admin-key"
})
```

---

## 8. Timeouts

```ruby
client = Tina4::Api.new("https://api.slow.com", {}, timeout: 10)
# Raises Tina4::ApiTimeout after 10 seconds with no response
```

Default timeout is 30 seconds.

---

## 9. Using the Client in Route Handlers

```ruby
# @noauth
Tina4::Router.get("/api/weather") do |request, response|
  city = request.params["city"] || "London"

  weather_client = Tina4::Api.new("https://api.openweathermap.org", {
    "Accept" => "application/json"
  })

  result = weather_client.get("/data/2.5/weather", params: {
    q:     city,
    appid: ENV["OPENWEATHER_API_KEY"],
    units: "metric"
  })

  if result.success?
    data = result.body
    response.json({
      city:        data["name"],
      temperature: data.dig("main", "temp"),
      description: data.dig("weather", 0, "description")
    })
  else
    response.json({ error: "Weather data unavailable" }, 502)
  end
end
```

```bash
curl "http://localhost:7147/api/weather?city=Paris"
```

```json
{
  "city": "Paris",
  "temperature": 14.3,
  "description": "partly cloudy"
}
```

---

## 10. Shared Client Instances

Define shared clients once and reuse them across routes.

```ruby
# src/clients/stripe.rb
STRIPE = Tina4::Api.new("https://api.stripe.com", {
  "Authorization"  => "Bearer #{ENV['STRIPE_SECRET_KEY']}",
  "Content-Type"   => "application/json",
  "Stripe-Version" => "2024-11-20"
})

# src/routes/payments.rb
Tina4::Router.post("/api/checkout") do |request, response|
  body = request.body

  result = STRIPE.post("/v1/payment_intents", body: {
    amount:   (body["total"].to_f * 100).to_i,
    currency: "usd",
    metadata: { order_id: body["order_id"] }
  })

  if result.success?
    response.json({ client_secret: result.body["client_secret"] }, 201)
  else
    Tina4::Log.error("Stripe error", status: result.status, error: result.body["error"]["message"])
    response.json({ error: "Payment failed" }, 502)
  end
end
```

---

## 11. Error Handling

```ruby
begin
  result = client.get("/products")

  case result.status
  when 200..299
    process(result.body)
  when 401
    raise "Unauthorized -- check API credentials"
  when 429
    Tina4::Log.warning("Rate limited", retry_after: result.headers["Retry-After"])
  when 500..599
    raise "Remote server error: #{result.status}"
  end

rescue Tina4::ApiTimeout => e
  Tina4::Log.error("API request timed out", error: e.message)
rescue => e
  Tina4::Log.error("API request failed", error: e.message)
end
```

---

## 12. Gotchas

### 1. Never hard-code credentials

Always read tokens from environment variables. Hard-coded credentials end up in version control.

### 2. Check success? before reading body

`result.body` on a 4xx or 5xx response contains the error payload, not the data you expect.

### 3. Timeout is per-request

A shared client instance with `timeout: 5` applies that timeout to every request. Override per call if some endpoints are slower than others.

### 4. Base URL trailing slash

`Tina4::Api.new("https://api.example.com/")` with a trailing slash and `client.get("/products")` with a leading slash double up to `https://api.example.com//products`. Use a base URL without a trailing slash.
