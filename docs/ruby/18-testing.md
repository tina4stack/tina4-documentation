# Chapter 18: Testing

## 1. Why Tests Matter More Than You Think

Friday afternoon. Your client reports a critical bug in production. You fix it -- one line of code. But did that fix break something else? 47 routes. 12 ORM models. 3 middleware functions. Clicking through every page: an hour. Running the test suite: 2 seconds.

```bash
tina4ruby test
```

```
  Product API
    ✓ creates a product
    ✓ loads a product by id
    ✓ updates a product
    ✓ deletes a product
    ✓ filters products by category

  Authentication
    ✓ logs in with valid credentials
    ✓ rejects invalid password
    ✓ protected route requires token
    ✓ allows access with valid token

  9 tests: 9 passed, 0 failed, 0 errors
```

Everything still passes. Deploy with confidence. Weekend intact.

Tina4 ships an inline testing framework -- no RSpec, no Minitest, no setup ceremony. The `Tina4::Testing` module gives you `describe`/`it` blocks, a full set of `assert_*` helpers, and an in-process HTTP test client. `tina4ruby test` discovers `*_test.rb` and `test_*.rb` files under `tests/`, `test/`, `spec/`, or `src/tests/` and runs them.

---

## 2. Your First Test

Tests live under `tests/`. Files must be named `*_test.rb` or `test_*.rb` -- the runner ignores anything else.

Create `tests/basic_test.rb`:

```ruby
require "tina4"

Tina4::Testing.describe "Basic tests" do
  it "adds two numbers" do
    assert_equal(4, 2 + 2)
  end

  it "concatenates strings" do
    result = "Hello" + " " + "World"
    assert_equal("Hello World", result)
  end

  it "handles nil correctly" do
    value = nil
    assert_nil(value)
  end
end
```

Run it:

```bash
tina4ruby test
```

```
  Basic tests
    ✓ adds two numbers
    ✓ concatenates strings
    ✓ handles nil correctly

  3 tests: 3 passed, 0 failed, 0 errors
```

### How It Works

1. `Tina4::Testing.describe` opens a suite. The block defines the suite's tests.
2. Each `it` registers a single test case. The description string becomes the label printed to the console.
3. Inside an `it` block you call `assert_*` helpers to check behaviour. Any assertion that fails raises `Tina4::Testing::TestFailure` and marks the test as failed.
4. `Tina4::Testing.run_all` runs every registered suite. `tina4ruby test` calls it for you.

---

## 3. Assertion Reference

Every assertion is defined on `Tina4::Testing::TestContext` and available inside `it` blocks. The convention is `assert_<thing>(expected, actual, message = nil)` -- expected first.

### Equality

```ruby
assert_equal(42, result)               # value equality
assert_not_equal(0, result)            # not equal
```

### Nil

```ruby
assert_nil(value)                       # value is nil
assert_not_nil(value)                   # value is not nil
```

### Truthiness

```ruby
assert(condition, "optional message")   # condition is truthy
assert_true(value)                      # value is truthy
assert_false(value)                     # value is falsy
```

### Collections and Strings

```ruby
assert_includes([1, 2, 3], 2)           # collection includes item
assert_match(/@/, "user@example.com")   # string matches pattern
```

### Exceptions

```ruby
assert_raises(ArgumentError) do
  raise ArgumentError, "bad input"
end
```

### JSON / HTTP

```ruby
data = assert_json(response.body)       # parses body, raises on invalid JSON
assert_status(response, 200)            # asserts HTTP status (Rack tuple OR TestResponse)
```

---

## 4. Testing Routes

Tina4's `Tina4::TestClient` issues requests against your registered routes in-process -- no socket, no server, no port. It returns a `Tina4::TestResponse` with `status`, `body`, `headers`, and a `json` helper.

Create `tests/product_test.rb`:

```ruby
require "tina4"

Tina4::Testing.describe "Product API" do
  client = Tina4::TestClient.new

  before_each do
    db = Tina4.database
    db.execute("DELETE FROM products") if db
  end

  it "returns the products list" do
    resp = client.get("/api/products")

    assert_status(resp, 200)

    data = resp.json
    assert_not_nil(data, "Response should be valid JSON")
    assert_includes(data.keys, "products")
    assert(data["products"].is_a?(Array), "products should be an array")
  end

  it "creates a product" do
    resp = client.post("/api/products", json: {
      name: "Test Widget",
      category: "Testing",
      price: 9.99
    })

    assert_status(resp, 201)

    data = resp.json
    assert_equal("Test Widget", data["name"])
    assert_equal(9.99, data["price"])
    assert_not_nil(data["id"], "New product should have an id")
  end

  it "returns 404 for a missing product" do
    resp = client.get("/api/products/99999")

    assert_status(resp, 404)
  end

  it "validates required fields" do
    resp = client.post("/api/products", json: {})

    assert_status(resp, 400)

    data = resp.json
    assert_match(/required/, data["error"])
  end
end
```

### TestClient Methods

`Tina4::TestClient` exposes one method per verb. Every method except `get`/`delete` accepts a `json:` keyword for the request body. Use `headers:` to attach a single hash of HTTP headers.

```ruby
client = Tina4::TestClient.new

# GET — with optional query string and headers
resp = client.get("/api/products")
resp = client.get("/api/products?category=Electronics")
resp = client.get("/api/profile", headers: { "Authorization" => "Bearer #{token}" })

# POST / PUT / PATCH — pass a Ruby hash via `json:`
resp = client.post("/api/products", json: { name: "Widget", price: 9.99 })
resp = client.put("/api/products/1", json: { name: "Updated Widget" })
resp = client.patch("/api/products/1", json: { price: 12.99 })

# DELETE — no body
resp = client.delete("/api/products/1")
```

### TestResponse

```ruby
resp.status         # HTTP status code (200, 201, 404, ...)
resp.body           # raw response body as a String
resp.headers        # response headers as a Hash (lowercased keys)
resp.content_type   # value of the content-type header
resp.json           # JSON.parse(body); returns nil if the body is not valid JSON
resp.text           # alias for body.to_s
```

If you prefer to assert on the raw Rack tuple instead of a `TestResponse`, use the `get`/`post`/`put`/`delete` helpers exposed on the test context -- they return `[status, headers, body_enumerable]` and work with `assert_status` exactly the same way.

---

## 5. Testing ORM Models

Drop into the database directly when you need to verify model behaviour. `before_each` is the right place to truncate tables or seed fixtures.

```ruby
require "tina4"

Tina4::Testing.describe "Product model" do
  before_each do
    db = Tina4.database
    db.execute("DELETE FROM products")
  end

  it "saves and reloads a product" do
    product = Product.new
    product.name = "Test Widget"
    product.category = "Testing"
    product.price = 19.99
    product.save

    assert_not_nil(product.id, "Product should have an id after save")

    loaded = Product.find(product.id)
    assert_equal("Test Widget", loaded.name)
    assert_equal(19.99, loaded.price)
  end

  it "updates a product" do
    product = Product.create(name: "Before", price: 10.0, category: "Testing")
    product.name = "After"
    product.price = 20.0
    product.save

    reloaded = Product.find(product.id)
    assert_equal("After", reloaded.name)
    assert_equal(20.0, reloaded.price)
  end

  it "deletes a product" do
    product = Product.create(name: "Goodbye", price: 5.0, category: "Testing")
    id = product.id

    product.delete

    assert_nil(Product.find(id), "Deleted product should not be findable")
  end

  it "filters by category" do
    Product.create(name: "Phone", category: "Electronics", price: 499.0)
    Product.create(name: "Yoga Mat", category: "Fitness", price: 29.0)

    results = Product.where("category = ?", ["Electronics"])

    assert_equal(1, results.length)
    assert_equal("Phone", results[0].name)
  end
end
```

### Test database isolation

By default, the framework uses whatever `TINA4_DATABASE_URL` points at. To keep tests off your development data, point them at a dedicated SQLite file:

```bash
# .env.test
TINA4_DATABASE_URL=sqlite:///data/test.db
TINA4_DEBUG=false
```

Load it explicitly in your test bootstrap, or set `TINA4_ENV=test` and have your app pick the matching `.env.test` at startup.

---

## 6. Testing Authentication

Auth flows are easy to test because `TestClient` works in-process -- there is no JWT round-trip over the wire.

```ruby
require "tina4"

Tina4::Testing.describe "Authentication" do
  client = Tina4::TestClient.new

  before_each do
    User.where("email = ?", ["test@example.com"]).each(&:delete)

    client.post("/api/auth/register", json: {
      name: "Test User",
      email: "test@example.com",
      password: "SecurePass123!"
    })
  end

  it "logs in with valid credentials" do
    resp = client.post("/api/auth/login", json: {
      email: "test@example.com",
      password: "SecurePass123!"
    })

    assert_status(resp, 200)

    body = resp.json
    assert_not_nil(body["token"], "Should return a JWT token")
    assert(body["token"].length > 50, "Token should be substantial")
  end

  it "rejects an invalid password" do
    resp = client.post("/api/auth/login", json: {
      email: "test@example.com",
      password: "wrong-password"
    })

    assert_status(resp, 401)
    assert_match(/invalid/i, resp.json["error"])
  end

  it "protects routes without a token" do
    resp = client.get("/api/profile")

    assert_status(resp, 401)
  end

  it "allows access with a valid token" do
    login = client.post("/api/auth/login", json: {
      email: "test@example.com",
      password: "SecurePass123!"
    })
    token = login.json["token"]

    resp = client.get("/api/profile", headers: {
      "Authorization" => "Bearer #{token}"
    })

    assert_status(resp, 200)
    assert_equal("test@example.com", resp.json["email"])
  end
end
```

---

## 7. Setup and Teardown

`before_each` runs before every test in the suite. `after_each` runs after every test, even on failure. Use them to create fixtures and clean up state:

```ruby
Tina4::Testing.describe "User Management" do
  client = Tina4::TestClient.new
  user_id = nil

  before_each do
    user = User.new(name: "Test User", email: "fixture@example.com")
    user.save
    user_id = user.id
  end

  after_each do
    User.find(user_id)&.delete if user_id
  end

  it "loads the user" do
    loaded = User.find(user_id)
    assert_equal("Test User", loaded.name)
  end

  it "updates the user" do
    user = User.find(user_id)
    user.name = "Updated Name"
    user.save

    reloaded = User.find(user_id)
    assert_equal("Updated Name", reloaded.name)
  end
end
```

There is no per-suite hook. If you need one-off setup that applies to every test, do it at the top of the file before `describe`, or accept the cost of running it in `before_each`.

---

## 8. Running Tests

```bash
# Run every discovered test file
tina4ruby test
```

The runner walks `tests/`, `test/`, `spec/`, and `src/tests/` (in that order) and loads every `*_test.rb` and `test_*.rb` file it finds. Inline tests declared inside route files are picked up automatically because `tina4ruby test` also loads `routes/`.

Output uses ANSI colours: green checks for passes, red crosses for failures, and yellow bangs for unexpected exceptions. Exit code is non-zero if any test fails or errors -- perfect for CI.

```
  Product API
    ✓ returns the products list
    ✓ creates a product
    ✗ returns 404 for a missing product: Expected status 404, got 200
    ✓ validates required fields

  4 tests: 3 passed, 1 failed, 0 errors
```

The failure line shows the suite name, the test description, and the assertion message. Find the line. Fix the logic. Run again.

### Embedding the runner in your own scripts

```ruby
require "tina4"

# Load whichever test files you want, then:
results = Tina4::Testing.run_all(quiet: false, failfast: false)
exit(results[:failed] > 0 || results[:errors] > 0 ? 1 : 0)
```

`run_all` returns a hash with `:passed`, `:failed`, `:errors`, and a `:tests` array of `{ name:, status:, suite:, message: }` entries. Pass `quiet: true` to suppress console output and inspect the hash directly. Pass `failfast: true` to stop at the first failure.

---

## 9. Testing Best Practices

### Test one thing per `it`

Each test should verify one behaviour. When it fails, you know exactly what broke.

```ruby
# Good — each test verifies one thing
it "returns 201 on create" do
  resp = client.post("/api/products", json: { name: "Widget", price: 9.99 })
  assert_status(resp, 201)
end

it "returns the created product" do
  resp = client.post("/api/products", json: { name: "Widget", price: 9.99 })
  assert_equal("Widget", resp.json["name"])
end

# Bad — testing five things in one block
it "does everything" do
  # Creates, reads, updates, deletes, checks auth, validates input ...
  # When this fails you have no idea which step broke.
end
```

### Use descriptive test names

```ruby
# Good
it "returns 404 when the product does not exist"

# Bad
it "works"
```

### Isolate tests

Each test should create its own data and clean up after itself. Never depend on rows left behind by another test.

```ruby
# Good
it "deletes a product" do
  product = Product.create(name: "Temporary", price: 1.0)
  product.delete
  assert_nil(Product.find(product.id))
end
```

### Generate unique values

Avoid `UNIQUE` constraint failures by mixing in a random or time-based suffix:

```ruby
require "securerandom"

it "registers a user" do
  email = "test-#{SecureRandom.hex(4)}@example.com"
  resp = client.post("/api/auth/register", json: {
    name: "Test", email: email, password: "Pass1234!"
  })
  assert_status(resp, 201)
end
```

### Compare floats with tolerance

`assert_equal(9.99, product.price)` can fail when SQLite hands back `9.990000000000001`. When the engine is fussy, use a manual tolerance:

```ruby
diff = (product.price - 9.99).abs
assert(diff < 0.01, "Expected ~9.99, got #{product.price}")
```

---

## 10. Exercise: Write Tests for a Notes API

Write a test suite for the Notes API from Chapter 5.

### Requirements

Cover these scenarios:

1. Create a note with valid data (201)
2. Reject a note with a missing title (400)
3. List all notes (200)
4. Get a note by id (200)
5. Return 404 for a non-existent note
6. Update a note (200)
7. Delete a note (204)
8. Search notes by content
9. Filter notes by tag

---

## 11. Solution

Create `tests/notes_test.rb`:

```ruby
require "tina4"

Tina4::Testing.describe "Notes API" do
  client = Tina4::TestClient.new

  before_each do
    db = Tina4.database
    db.execute("DELETE FROM notes")
  end

  it "creates a note with valid data" do
    resp = client.post("/api/notes", json: {
      title: "Test Note",
      content: "This is a test",
      tag: "testing"
    })

    assert_status(resp, 201)

    body = resp.json
    assert_equal("Test Note", body["title"])
    assert_equal("testing", body["tag"])
    assert_not_nil(body["id"])
  end

  it "rejects a note with a missing title" do
    resp = client.post("/api/notes", json: { content: "No title here" })

    assert_status(resp, 400)
    assert_match(/title/i, resp.json["error"])
  end

  it "lists all notes" do
    client.post("/api/notes", json: { title: "Note 1", content: "Content 1" })
    client.post("/api/notes", json: { title: "Note 2", content: "Content 2" })

    resp = client.get("/api/notes")

    assert_status(resp, 200)
    assert_equal(2, resp.json["notes"].length)
  end

  it "gets a note by id" do
    created = client.post("/api/notes", json: { title: "Find Me", content: "Here I am" })
    id = created.json["id"]

    resp = client.get("/api/notes/#{id}")

    assert_status(resp, 200)
    assert_equal("Find Me", resp.json["title"])
  end

  it "returns 404 for a non-existent note" do
    resp = client.get("/api/notes/99999")
    assert_status(resp, 404)
  end

  it "updates a note" do
    created = client.post("/api/notes", json: { title: "Original", content: "Original content" })
    id = created.json["id"]

    resp = client.put("/api/notes/#{id}", json: { title: "Updated", content: "Updated content" })

    assert_status(resp, 200)
    assert_equal("Updated", resp.json["title"])
  end

  it "deletes a note" do
    created = client.post("/api/notes", json: { title: "Delete Me", content: "Goodbye" })
    id = created.json["id"]

    resp = client.delete("/api/notes/#{id}")
    assert_status(resp, 204)

    assert_status(client.get("/api/notes/#{id}"), 404)
  end

  it "searches notes by content" do
    client.post("/api/notes", json: { title: "Shopping", content: "Buy milk and eggs" })
    client.post("/api/notes", json: { title: "Work", content: "Finish the report" })

    resp = client.get("/api/notes?search=milk")

    assert_status(resp, 200)
    assert_equal(1, resp.json["notes"].length)
    assert_equal("Shopping", resp.json["notes"][0]["title"])
  end

  it "filters notes by tag" do
    client.post("/api/notes", json: { title: "Personal", content: "Content", tag: "personal" })
    client.post("/api/notes", json: { title: "Work", content: "Content", tag: "work" })

    resp = client.get("/api/notes?tag=personal")

    assert_status(resp, 200)
    assert_equal(1, resp.json["notes"].length)
    assert_equal("Personal", resp.json["notes"][0]["title"])
  end
end
```

---

## 12. Gotchas

### 1. Files must be named correctly

**Problem:** Your tests don't run.

**Cause:** The runner only loads `*_test.rb` and `test_*.rb`. A file called `notes_spec.rb` will be skipped.

**Fix:** Rename to `notes_test.rb` or `test_notes.rb`.

### 2. Database state carries between tests

**Problem:** A test passes alone but fails when the whole suite runs.

**Fix:** Truncate tables in `before_each` or use unique values per test (UUID/timestamp suffix on emails, etc.).

### 3. `TestClient` doesn't start a real server

**Problem:** External services (SMTP, Redis, third-party APIs) are not available in tests.

**Fix:** `TestClient` matches routes and runs handlers in-process. Mock out anything that crosses the network boundary, or use the dev mailbox / fake queue backends shipped with the framework.

### 4. Argument order on equality assertions

**Problem:** The failure message reads "Expected: 200, got: 404" but you wanted to compare the other way around.

**Fix:** The Tina4 convention is `assert_equal(expected, actual)` -- expected first, like Minitest. Keep the order consistent across your suite.

### 5. Floating point comparisons

**Problem:** `assert_equal(9.99, product.price)` fails with `9.990000000000001`.

**Fix:** Compare against a tolerance with `assert(diff < 0.01, ...)` as shown above, or store currency as integer cents.

### 6. Tests can't find your models

**Problem:** `NameError: uninitialized constant Product` when the test loads.

**Cause:** Routes and ORM models are normally loaded by the server boot path. `tina4ruby test` calls `Tina4.initialize!(Dir.pwd)` followed by route discovery, but a model file that isn't `require`d anywhere won't load on its own.

**Fix:** Either `require_relative "../src/orm/product"` at the top of the test file, or move the model into the autoloaded `src/orm/` directory.

### 7. Tests pass locally but fail in CI

**Problem:** All green on your machine, red in CI.

**Cause:** Different Ruby version, missing env vars, different SQLite version, time-dependent assertions.

**Fix:** Pin the Ruby version in CI (`.ruby-version`), commit `.env.test` if it contains no secrets, and avoid asserting on wall-clock time or random values.
