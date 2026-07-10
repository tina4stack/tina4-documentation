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

---

## 13. Uploading Files (New in 3.13.69)

`upload` posts a `multipart/form-data` body: a file plus optional text fields. Supply the file two ways, so your code never stages a temp file first.

```ruby
api = Tina4::API.new("https://api.example.com", bearer_token: ENV["API_TOKEN"])

# A file on disk. filename: defaults to the basename.
result = api.upload("/avatars", file_path: "/tmp/me.png")

# In-memory bytes. Pass a filename so the server sees a real name.
raw = build_thumbnail            # String of bytes
result = api.upload("/avatars",
  file_bytes: raw,
  filename: "me.png",
  extra_fields: { "user_id" => "42" })   # extra text parts
```

The full signature:

```ruby
api.upload(path, file_path: nil, field_name: "file",
           extra_fields: {}, headers: {},
           file_bytes: nil, filename: nil) -> APIResponse
```

`field_name:` is the form field the file rides under (default `"file"`). `extra_fields:` become additional text parts. `headers:` merge extra per-call headers onto the request. The part's `Content-Type` is guessed from the filename, falling back to `application/octet-stream`.

`upload` returns an `APIResponse`. A missing file, or no source at all, returns a clean error response (`status` is `0`, `error` is set) and never raises. Nothing is sent over the wire.

> **Breaking change in 3.13.69.** `file_path` was the second **positional** argument; it is now a **keyword** (`file_path:`). Update call sites from `api.upload("/path", "/tmp/me.png")` to `api.upload("/path", file_path: "/tmp/me.png")`. This reconciles Ruby with the upload signature the other three frameworks already use.

---

## 14. Streaming Downloads (New in 3.13.69)

`download` streams a GET body straight to disk, 64KB at a time. A large export never buffers whole in memory.

```ruby
result = api.download("/reports/2026.csv", dest_path: "/tmp/2026.csv")

puts "saved to #{result.path}" if result.error.nil?   # /tmp/2026.csv
```

The signature is `download(path, dest_path: nil, params: {})`. It returns an `APIResponse` whose `body` is `nil` (the body went to disk) and whose `path` reader holds the destination. On any error (no dest, an HTTP error status, or a transport failure) `path` is `nil` and no file is written. `status` is `0` on a transport failure.

---

## 15. Testing Your Code: the transport Seam (New in 3.13.69)

The constructor accepts a `transport:` object that fully replaces the `Net::HTTP` call. Point it at your own callable and the code that calls an `API` runs in a unit test with no live server.

```ruby
fake = ->(method, url, headers, body, timeout) {
  { http_code: 200, body: '{"ok":true}', headers: {}, error: nil }
}

api = Tina4::API.new("https://api.example.com", transport: fake)
result = api.get("/health")     # returns the canned response, opens no socket
```

The object must respond to `call(method, url, headers, body, timeout)` and return a Hash shaped like `{ http_code:, body:, headers:, error: }` (string or symbol keys both work).

This seam is for **your** tests, not Tina4's. The framework's own suite never injects a fake transport: it follows the no-mock rule and drives the real network against a real local server. Reach for `transport:` to test the code that calls an `API`, never to stand in for `API` itself.

---

## 16. The Cookie Jar (New in 3.13.69)

Pass `cookies: true` and the client keeps a per-instance, in-memory cookie jar. It reads `Set-Cookie` on each response and replays the accumulated `Cookie` header on the next request, so a session carries across a login and the calls that follow.

```ruby
api = Tina4::API.new("https://api.example.com", cookies: true)

api.post("/login", body: { user: "alice", pass: "secret" })   # server sets a session cookie
api.get("/account")                                            # the cookie is sent automatically
```

The jar is off by default. It keeps only the leading `name=value` of each cookie, it is never persisted, and it is scoped to the instance.

---

## 17. Redirects and Cross-Origin Safety (New in 3.13.69)

`Net::HTTP` does not follow redirects on its own. The client now does, bounded to ten hops. A `301`, `302`, or `303` on a non-`GET`/`HEAD` method becomes a `GET` with the body dropped; `307` and `308` keep the method and body.

On a redirect that crosses to a different origin (a different scheme, host, or port), the client strips the `Authorization` header and the cookie-jar `Cookie` header before following. That strip is a security boundary: without it, a call to `https://api.example.com/login` that redirected to `https://evil.example/` would hand your bearer token and session cookie to a host you never authenticated against. Same-origin redirects keep both headers.

You get this on every verb and on `download`, with nothing to switch on.
