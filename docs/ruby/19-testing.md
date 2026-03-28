# Chapter 17: Testing

## 1. Why Tests Matter More Than You Think

Friday afternoon. Your client reports a critical bug in production. You fix it -- one line of code. But did that fix break something else? You have 47 routes, 12 ORM models, and 3 middleware functions. Click through every page? An hour. Run the test suite? 2 seconds.

```bash
tina4 test
```

```
Running tests...

  ProductTest
    [PASS] test_create_product
    [PASS] test_load_product
    [PASS] test_update_product
    [PASS] test_delete_product
    [PASS] test_list_products_with_filter

  AuthTest
    [PASS] test_login_with_valid_credentials
    [PASS] test_login_with_invalid_password
    [PASS] test_protected_route_without_token
    [PASS] test_protected_route_with_valid_token

  9 tests, 9 passed, 0 failed (0.34s)
```

Everything passes. You deploy with confidence. Weekend intact.

Tina4 uses RSpec for testing. Tests live in `tests/`. Every `_spec.rb` file is auto-discovered when you run `tina4 test`.

---

## 2. Your First Test

Create `tests/basic_spec.rb`:

```ruby
require "tina4"

RSpec.describe "Basic tests" do
  it "adds two numbers" do
    expect(2 + 2).to eq(4)
  end

  it "concatenates strings" do
    result = "Hello" + " " + "World"
    expect(result).to eq("Hello World")
  end

  it "handles nil correctly" do
    value = nil
    expect(value).to be_nil
  end
end
```

Run it:

```bash
tina4 test
```

```
Running tests...

  Basic tests
    [PASS] adds two numbers
    [PASS] concatenates strings
    [PASS] handles nil correctly

  3 tests, 3 passed, 0 failed (0.01s)
```

You can also use `bundle exec rspec` directly:

```bash
bundle exec rspec tests/
```

---

## 3. Testing Routes

The `Tina4::TestClient` lets you make HTTP requests to your routes without starting a server:

```ruby
require "tina4"

RSpec.describe "Product API" do
  let(:client) { Tina4::TestClient.new }

  it "returns products list" do
    result = client.get("/api/products")

    expect(result.status).to eq(200)

    data = result.json
    expect(data).to have_key("products")
    expect(data["products"]).to be_an(Array)
  end

  it "creates a product" do
    result = client.post("/api/products", {
      name: "Test Widget",
      category: "Test",
      price: 9.99
    })

    expect(result.status).to eq(201)

    data = result.json
    expect(data["name"]).to eq("Test Widget")
    expect(data["price"]).to eq(9.99)
    expect(data["id"]).not_to be_nil
  end

  it "returns 404 for missing product" do
    result = client.get("/api/products/99999")

    expect(result.status).to eq(404)

    data = result.json
    expect(data["error"]).to eq("Product not found")
  end

  it "validates required fields" do
    result = client.post("/api/products", {})

    expect(result.status).to eq(400)

    data = result.json
    expect(data["error"]).to include("required")
  end
end
```

### TestClient Methods

```ruby
client = Tina4::TestClient.new

# GET request
result = client.get("/api/products")
result = client.get("/api/products?category=Electronics")

# POST request with JSON body
result = client.post("/api/products", { name: "Widget", price: 9.99 })

# PUT request
result = client.put("/api/products/1", { name: "Updated Widget" })

# DELETE request
result = client.delete("/api/products/1")

# With custom headers
result = client.get("/api/profile", headers: { "Authorization" => "Bearer #{token}" })
```

### TestResult Properties

```ruby
result.status      # HTTP status code (200, 201, 404, etc.)
result.json        # Parsed JSON body as a hash
result.body        # Raw response body as a string
result.headers     # Response headers hash
```

---

## 4. Testing ORM Models

```ruby
require "tina4"

RSpec.describe Product do
  before(:each) do
    db = Tina4.database
    db.execute("DELETE FROM products")
  end

  it "creates and saves a product" do
    product = Product.new
    product.name = "Test Product"
    product.price = 29.99
    product.category = "Testing"
    product.save

    expect(product.id).not_to be_nil
    expect(product.name).to eq("Test Product")
  end

  it "loads a product by ID" do
    product = Product.new
    product.name = "Load Test"
    product.price = 19.99
    product.save

    loaded = Product.new
    loaded.load(product.id)

    expect(loaded.name).to eq("Load Test")
    expect(loaded.price).to eq(19.99)
  end

  it "updates a product" do
    product = Product.new
    product.name = "Before Update"
    product.price = 10.00
    product.save

    product.name = "After Update"
    product.price = 20.00
    product.save

    loaded = Product.new
    loaded.load(product.id)

    expect(loaded.name).to eq("After Update")
    expect(loaded.price).to eq(20.00)
  end

  it "deletes a product" do
    product = Product.new
    product.name = "To Delete"
    product.price = 5.00
    product.save

    id = product.id
    product.delete

    loaded = Product.new
    loaded.load(id)

    expect(loaded.id).to be_nil
  end

  it "selects products with filter" do
    product = Product.new

    p1 = Product.new
    p1.name = "Electronics Item"
    p1.category = "Electronics"
    p1.price = 99.99
    p1.save

    p2 = Product.new
    p2.name = "Fitness Item"
    p2.category = "Fitness"
    p2.price = 29.99
    p2.save

    results = Product.where("category = ?", ["Electronics"])

    expect(results.length).to eq(1)
    expect(results[0].name).to eq("Electronics Item")
  end
end
```

---

## 5. Testing Authentication

```ruby
require "tina4"

RSpec.describe "Authentication" do
  let(:client) { Tina4::TestClient.new }

  before(:each) do
    # Register a test user
    client.post("/api/register", {
      name: "Test User",
      email: "test@example.com",
      password: "securePass123"
    })
  end

  it "logs in with valid credentials" do
    result = client.post("/api/login", {
      email: "test@example.com",
      password: "securePass123"
    })

    expect(result.status).to eq(200)
    expect(result.json).to have_key("token")
    expect(result.json["user"]["email"]).to eq("test@example.com")
  end

  it "rejects invalid password" do
    result = client.post("/api/login", {
      email: "test@example.com",
      password: "wrongPassword"
    })

    expect(result.status).to eq(401)
    expect(result.json["error"]).to include("Invalid")
  end

  it "protects routes without token" do
    result = client.get("/api/profile")

    expect(result.status).to eq(401)
  end

  it "allows access with valid token" do
    login = client.post("/api/login", {
      email: "test@example.com",
      password: "securePass123"
    })

    token = login.json["token"]

    result = client.get("/api/profile", headers: {
      "Authorization" => "Bearer #{token}"
    })

    expect(result.status).to eq(200)
    expect(result.json["email"]).to eq("test@example.com")
  end
end
```

---

## 6. Test Database Isolation

Use a separate test database to avoid polluting development data:

```env
# .env.test
DATABASE_URL=sqlite:///data/test.db
TINA4_DEBUG=false
```

In your test helper:

```ruby
# tests/spec_helper.rb
ENV["TINA4_ENV"] = "test"
require "tina4"

RSpec.configure do |config|
  config.before(:suite) do
    # Run migrations on test database
    system("tina4 migrate --env test")
  end

  config.after(:suite) do
    # Clean up test database
    File.delete("data/test.db") if File.exist?("data/test.db")
  end
end
```

---

## 7. Running Tests

```bash
# Run all tests
tina4 test

# Run a specific test file
tina4 test tests/product_spec.rb

# Run with verbose output
tina4 test --verbose

# Using RSpec directly
bundle exec rspec tests/
bundle exec rspec tests/product_spec.rb
bundle exec rspec tests/ --format documentation
```

---

## 8. Exercise: Write Tests for a Notes API

Write a comprehensive test suite for the Notes API from Chapter 5.

### Requirements

Test these scenarios:

1. Create a note with valid data (201)
2. Create a note with missing title (400)
3. List all notes (200)
4. Get a note by ID (200)
5. Get a non-existent note (404)
6. Update a note (200)
7. Delete a note (204)
8. Search notes by content
9. Filter notes by tag

---

## 9. Solution

Create `tests/notes_spec.rb`:

```ruby
require "tina4"

RSpec.describe "Notes API" do
  let(:client) { Tina4::TestClient.new }

  before(:each) do
    db = Tina4.database
    db.execute("DELETE FROM notes")
  end

  it "creates a note with valid data" do
    result = client.post("/api/notes", {
      title: "Test Note",
      content: "This is a test",
      tag: "testing"
    })

    expect(result.status).to eq(201)
    expect(result.json["title"]).to eq("Test Note")
    expect(result.json["tag"]).to eq("testing")
    expect(result.json["id"]).not_to be_nil
  end

  it "rejects note with missing title" do
    result = client.post("/api/notes", {
      content: "No title here"
    })

    expect(result.status).to eq(400)
    expect(result.json["errors"]).to include("Title is required")
  end

  it "lists all notes" do
    client.post("/api/notes", { title: "Note 1", content: "Content 1" })
    client.post("/api/notes", { title: "Note 2", content: "Content 2" })

    result = client.get("/api/notes")

    expect(result.status).to eq(200)
    expect(result.json["count"]).to eq(2)
    expect(result.json["notes"].length).to eq(2)
  end

  it "gets a note by ID" do
    created = client.post("/api/notes", { title: "Find Me", content: "Here I am" })
    id = created.json["id"]

    result = client.get("/api/notes/#{id}")

    expect(result.status).to eq(200)
    expect(result.json["title"]).to eq("Find Me")
  end

  it "returns 404 for non-existent note" do
    result = client.get("/api/notes/99999")

    expect(result.status).to eq(404)
  end

  it "updates a note" do
    created = client.post("/api/notes", { title: "Original", content: "Original content" })
    id = created.json["id"]

    result = client.put("/api/notes/#{id}", { title: "Updated", content: "Updated content" })

    expect(result.status).to eq(200)
    expect(result.json["title"]).to eq("Updated")
  end

  it "deletes a note" do
    created = client.post("/api/notes", { title: "Delete Me", content: "Goodbye" })
    id = created.json["id"]

    result = client.delete("/api/notes/#{id}")

    expect(result.status).to eq(204)

    get_result = client.get("/api/notes/#{id}")
    expect(get_result.status).to eq(404)
  end

  it "searches notes by content" do
    client.post("/api/notes", { title: "Shopping", content: "Buy milk and eggs" })
    client.post("/api/notes", { title: "Work", content: "Finish the report" })

    result = client.get("/api/notes?search=milk")

    expect(result.status).to eq(200)
    expect(result.json["count"]).to eq(1)
    expect(result.json["notes"][0]["title"]).to eq("Shopping")
  end

  it "filters notes by tag" do
    client.post("/api/notes", { title: "Personal", content: "Content", tag: "personal" })
    client.post("/api/notes", { title: "Work", content: "Content", tag: "work" })

    result = client.get("/api/notes?tag=personal")

    expect(result.status).to eq(200)
    expect(result.json["count"]).to eq(1)
    expect(result.json["notes"][0]["title"]).to eq("Personal")
  end
end
```

---

## 10. Gotchas

### 1. Tests Share Database State

**Problem:** Tests pass individually but fail when run together.

**Fix:** Clean up in `before(:each)` blocks. Delete test data before each test.

### 2. TestClient Does Not Start a Real Server

**Problem:** External services (SMTP, Redis) are not available in tests.

**Fix:** Mock external services or use test doubles. The TestClient simulates HTTP requests without network I/O.

### 3. Test Order Dependency

**Problem:** Test B depends on data created by Test A.

**Fix:** Each test should set up its own data. Use `before(:each)` blocks to create required state.

### 4. Database Migrations Not Applied

**Problem:** Tests fail with "table does not exist" errors.

**Fix:** Run `tina4 migrate` before running tests, or add migration logic to your test setup.

### 5. Token Expired During Test

**Problem:** Auth tests fail intermittently with "token expired".

**Fix:** Set a long JWT expiry for tests: `TINA4_JWT_EXPIRY=86400` in `.env.test`.

### 6. Floating Point Comparison

**Problem:** `expect(product.price).to eq(9.99)` fails with `9.990000000000001`.

**Fix:** Use `be_within` for floating point: `expect(product.price).to be_within(0.01).of(9.99)`.

### 7. Test Output Too Verbose

**Problem:** Test output includes log messages from the application.

**Fix:** Set `TINA4_LOG_LEVEL=ERROR` in `.env.test` to suppress info and debug logs.
