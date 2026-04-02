# Chapter 17: Testing

## 1. Why Tests Matter More Than You Think

Friday afternoon. Your client reports a critical bug in production. You fix it -- one line of code. But did that fix break something else? 47 routes. 12 ORM models. 3 middleware functions. Clicking through every page: an hour. Running the test suite: 2 seconds.

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

Everything still works. You deploy with confidence. Weekend intact.

Tina4 includes an inline testing framework. No external packages. No configuration. Write a test. Run it. Done.

---

## 2. Your First Test

Tests live in the `tests/` directory. Every `.py` file in that directory is auto-discovered when you run `tina4 test`.

Create `tests/test_basic.py`:

```python
from tina4_python.test import Test, assert_equal, assert_true

class BasicTest(Test):

    def test_addition(self):
        assert_equal(2 + 2, 4, "Basic addition should work")

    def test_string_contains(self):
        greeting = "Hello, World!"
        assert_true("World" in greeting, "Greeting should contain 'World'")

    def test_array_length(self):
        items = [1, 2, 3, 4, 5]
        assert_equal(len(items), 5, "List should have 5 items")
```

Run it:

```bash
tina4 test
```

```
Running tests...

  BasicTest
    [PASS] test_addition
    [PASS] test_string_contains
    [PASS] test_array_length

  3 tests, 3 passed, 0 failed (0.02s)
```

### How It Works

1. Your test class extends `Test`.
2. Every method that starts with `test` is a test case. The method name is converted to a readable label: `test_addition` stays as `test_addition`.
3. Inside each test, you call assertion functions to verify behavior.
4. If all assertions pass, the test passes. If any assertion fails, the test fails and you see the failure message.

---

## 3. Assertion Methods

Tina4's testing framework provides these assertion functions:

### assert_equal(actual, expected, message)

Checks that two values are equal.

```python
assert_equal(4, 4, "Should be equal")              # PASS
assert_equal("hello", "hello", "Strings match")    # PASS
assert_equal(4, 5, "Not equal")                     # FAIL
```

### assert_true(value, message)

Checks that a value is truthy.

```python
assert_true(True, "Should be true")                # PASS
assert_true(1, "1 is truthy")                      # PASS
assert_true("yes", "Non-empty string is truthy")   # PASS
assert_true(False, "This fails")                   # FAIL
assert_true(0, "Zero is falsy")                    # FAIL
```

### assert_false(value, message)

Checks that a value is falsy.

```python
assert_false(False, "Should be false")             # PASS
assert_false(0, "Zero is falsy")                   # PASS
assert_false("", "Empty string is falsy")          # PASS
assert_false(True, "This fails")                   # FAIL
```

### assert_raises(callable, exception_class, message)

Checks that a function raises a specific exception.

```python
assert_raises(
    lambda: int("not-a-number"),
    ValueError,
    "Should raise ValueError"
)

assert_raises(
    lambda: 10 / 0,
    ZeroDivisionError,
    "Should raise on division by zero"
)
```

### assert_not_equal(actual, expected, message)

Checks that two values are not equal.

```python
assert_not_equal("hello", "world", "Strings differ")  # PASS
assert_not_equal(4, 4, "Same values")                  # FAIL
```

### assert_none(value, message)

Checks that a value is None.

```python
assert_none(None, "Should be None")     # PASS
assert_none("hello", "Not None")        # FAIL
```

### assert_not_none(value, message)

Checks that a value is not None.

```python
assert_not_none("hello", "Has value")   # PASS
assert_not_none(None, "Is None")        # FAIL
```

---

## 4. Testing ORM Models

Let us test a Product model. The test creates records, loads them, updates them, and deletes them.

Create `tests/test_product.py`:

```python
from tina4_python.test import Test, assert_equal, assert_true, assert_not_none

class ProductTest(Test):

    def test_create_product(self):
        product = Product()
        product.name = "Test Widget"
        product.category = "Testing"
        product.price = 19.99
        product.in_stock = True
        product.save()

        assert_not_none(product.id, "Product should have an ID after save")
        assert_true(product.id > 0, "Product ID should be positive")

    def test_load_product(self):
        product = Product()
        product.name = "Load Test Widget"
        product.category = "Testing"
        product.price = 29.99
        product.save()

        loaded = Product.find(product.id)

        assert_equal(loaded.name, "Load Test Widget", "Name should match")
        assert_equal(loaded.category, "Testing", "Category should match")
        assert_equal(loaded.price, 29.99, "Price should match")

    def test_update_product(self):
        product = Product()
        product.name = "Update Test Widget"
        product.price = 10.00
        product.save()

        product_id = product.id

        product.name = "Updated Widget"
        product.price = 15.00
        product.save()

        reloaded = Product.find(product_id)

        assert_equal(reloaded.name, "Updated Widget", "Name should be updated")
        assert_equal(reloaded.price, 15.00, "Price should be updated")

    def test_delete_product(self):
        product = Product()
        product.name = "Delete Me"
        product.price = 5.00
        product.save()

        product_id = product.id
        product.delete()

        gone = Product.find(product_id)

        assert_true(gone is None, "Deleted product should not be loadable")

    def test_select_with_filter(self):
        p1 = Product()
        p1.name = "Filter Test A"
        p1.category = "FilterCat"
        p1.price = 10.00
        p1.save()

        p2 = Product()
        p2.name = "Filter Test B"
        p2.category = "FilterCat"
        p2.price = 20.00
        p2.save()

        products, count = Product.where("category = ?", ["FilterCat"])

        assert_true(len(products) >= 2, "Should find at least 2 FilterCat products")

        names = [p.name for p in products]
        assert_true("Filter Test A" in names, "Should include Filter Test A")
        assert_true("Filter Test B" in names, "Should include Filter Test B")
```

Run it:

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
    [PASS] test_select_with_filter

  5 tests, 5 passed, 0 failed (0.18s)
```

### Test Database

By default, `tina4 test` uses a separate test database so your development data is not affected. The test database is created at `data/test.db` (SQLite) and is reset before each test run. If you want to use a different database for tests, set it in `.env`:

```env
TINA4_TEST_DATABASE_URL=sqlite:///data/test.db
```

---

## 5. Testing Routes

Tina4 provides a test client for making HTTP requests to your routes without starting a server.

Create `tests/test_routes.py`:

```python
from tina4_python.test import Test, assert_equal, assert_true, assert_not_none
import json

class RouteTest(Test):

    def test_health_endpoint(self):
        resp = self.get("/health")

        assert_equal(resp.status_code, 200, "Health check should return 200")

        body = json.loads(resp.body)
        assert_equal(body["status"], "ok", "Status should be 'ok'")
        assert_not_none(body.get("version"), "Should include version")

    def test_get_products(self):
        resp = self.get("/api/products")

        assert_equal(resp.status_code, 200, "Should return 200")

        body = json.loads(resp.body)
        assert_true("data" in body or "products" in body, "Should contain product data")

    def test_create_product(self):
        resp = self.post("/api/products", {
            "name": "Route Test Product",
            "category": "Testing",
            "price": 42.00
        })

        assert_equal(resp.status_code, 201, "Should return 201 Created")

        body = json.loads(resp.body)
        assert_equal(body["name"], "Route Test Product", "Name should match")
        assert_equal(body["price"], 42.00, "Price should match")

    def test_get_product_not_found(self):
        resp = self.get("/api/products/99999")

        assert_equal(resp.status_code, 404, "Should return 404 for missing product")

    def test_create_product_validation(self):
        resp = self.post("/api/products", {})

        assert_equal(resp.status_code, 400, "Should return 400 for empty body")

    def test_delete_product(self):
        # Create a product first
        create_resp = self.post("/api/products", {
            "name": "To Be Deleted",
            "price": 1.00
        })
        body = json.loads(create_resp.body)
        product_id = body["id"]

        # Delete it
        delete_resp = self.delete(f"/api/products/{product_id}")
        assert_equal(delete_resp.status_code, 204, "Should return 204 No Content")

        # Verify it is gone
        get_resp = self.get(f"/api/products/{product_id}")
        assert_equal(get_resp.status_code, 404, "Should return 404 after deletion")
```

### Test Client Methods

The test client provides methods for all HTTP verbs:

```python
# GET request
resp = self.get("/api/products")

# GET with query parameters
resp = self.get("/api/products?category=Electronics&page=2")

# POST with JSON body
resp = self.post("/api/products", {"name": "Widget", "price": 9.99})

# PUT with JSON body
resp = self.put("/api/products/1", {"name": "Updated Widget"})

# PATCH with JSON body
resp = self.patch("/api/products/1", {"price": 12.99})

# DELETE
resp = self.delete("/api/products/1")

# Request with custom headers
resp = self.get("/api/profile", headers={
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIs..."
})
```

### Response Object

The response object has these properties:

```python
resp.status_code   # HTTP status code (200, 201, 404, etc.)
resp.body          # Response body as a string
resp.headers       # Response headers as a dict
resp.content_type  # Content-Type header value
```

---

## 6. Testing Authentication

Create `tests/test_auth.py`:

```python
from tina4_python.test import Test, assert_equal, assert_true, assert_not_none
import json

class AuthTest(Test):

    def test_login_with_valid_credentials(self):
        resp = self.post("/api/auth/login", {
            "email": "admin@example.com",
            "password": "correct-password"
        })

        assert_equal(resp.status_code, 200, "Login should succeed")

        body = json.loads(resp.body)
        assert_not_none(body.get("token"), "Should return a JWT token")
        assert_true(len(body["token"]) > 50, "Token should be a substantial string")

    def test_login_with_invalid_password(self):
        resp = self.post("/api/auth/login", {
            "email": "admin@example.com",
            "password": "wrong-password"
        })

        assert_equal(resp.status_code, 401, "Should reject invalid password")

    def test_login_with_missing_fields(self):
        resp = self.post("/api/auth/login", {
            "email": "admin@example.com"
        })

        assert_true(
            resp.status_code in (400, 401),
            "Should reject missing password"
        )

    def test_protected_route_without_token(self):
        resp = self.get("/api/profile")

        assert_equal(resp.status_code, 401, "Should reject unauthenticated request")

    def test_protected_route_with_valid_token(self):
        # Login first to get a token
        login_resp = self.post("/api/auth/login", {
            "email": "admin@example.com",
            "password": "correct-password"
        })
        login_body = json.loads(login_resp.body)
        token = login_body["token"]

        # Access protected route with token
        resp = self.get("/api/profile", headers={
            "Authorization": f"Bearer {token}"
        })

        assert_equal(resp.status_code, 200, "Should allow authenticated request")

        body = json.loads(resp.body)
        assert_equal(body["user"]["email"], "admin@example.com", "Should return user data")

    def test_protected_route_with_invalid_token(self):
        resp = self.get("/api/profile", headers={
            "Authorization": "Bearer invalid.token.here"
        })

        assert_equal(resp.status_code, 401, "Should reject invalid token")
```

---

## 7. Setup and Teardown

Use `set_up()` and `tear_down()` methods to run code before and after each test:

```python
from tina4_python.test import Test, assert_equal, assert_not_none
import time

class UserTest(Test):

    def set_up(self):
        # Runs before each test
        user = User()
        user.name = "Test User"
        user.email = f"test-{int(time.time())}@example.com"
        user.save()
        self.user_id = user.id

    def tear_down(self):
        # Runs after each test
        if self.user_id:
            user = User.find(self.user_id)
            if user:
                user.delete()

    def test_user_exists(self):
        user = User.find(self.user_id)
        assert_not_none(user.id, "User should exist")
        assert_equal(user.name, "Test User", "Name should match")

    def test_update_user(self):
        user = User.find(self.user_id)
        user.name = "Updated Name"
        user.save()

        reloaded = User.find(self.user_id)
        assert_equal(reloaded.name, "Updated Name", "Name should be updated")
```

`set_up()` runs before every test method, and `tear_down()` runs after every test method, regardless of whether the test passed or failed. This keeps tests isolated -- each test starts with a clean state.

---

## 8. Running Tests

### Run All Tests

```bash
tina4 test
```

### Run a Specific Test File

```bash
tina4 test --file tests/test_product.py
```

### Run a Specific Test Method

```bash
tina4 test --file tests/test_product.py --method test_create_product
```

### Verbose Output

```bash
tina4 test --verbose
```

```
Running tests...

  ProductTest
    [PASS] test_create_product (0.03s)
      assert_not_none: Product should have an ID after save
      assert_true: Product ID should be positive
    [PASS] test_load_product (0.02s)
      assert_equal: Name should match
      assert_equal: Category should match
      assert_equal: Price should match
    [PASS] test_update_product (0.04s)
      assert_equal: Name should be updated
      assert_equal: Price should be updated
    [PASS] test_delete_product (0.02s)
      assert_true: Deleted product should not be loadable
    [PASS] test_select_with_filter (0.05s)
      assert_true: Should find at least 2 FilterCat products
      assert_true: Should include Filter Test A
      assert_true: Should include Filter Test B

  5 tests, 5 passed, 0 failed (0.16s)
```

Verbose mode shows each assertion within each test, along with timing information.

### Failed Test Output

When a test fails, you see exactly what went wrong:

```
  ProductTest
    [PASS] test_create_product
    [FAIL] test_load_product
      assert_equal FAILED: Name should match
        Expected: "Load Test Widget"
        Actual:   "Wrong Name"
        File: tests/test_product.py:34
    [PASS] test_update_product

  3 tests, 2 passed, 1 failed (0.12s)
```

The failure message shows the assertion that failed, what was expected, what was actually received, and the file and line number.

---

## 9. pytest Integration

If your team already uses pytest, Tina4 tests can run alongside it. Install pytest:

```bash
uv add --dev pytest
```

Create `pyproject.toml` test configuration:

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["*Test"]
python_functions = ["test_*"]
```

Tina4's `Test` class is compatible with pytest. Your test files work with both `tina4 test` and `pytest` without modification.

```bash
tina4 test
```

```
========================= test session starts ==========================
collected 5 items

tests/test_product.py .....                                       [100%]

========================= 5 passed in 0.34s ============================
```

### Code Coverage

With pytest, you can generate code coverage reports:

```bash
uv add --dev pytest-cov
tina4 test --cov=src --cov-report=term
```

```
---------- coverage: ... ----------
Name                      Stmts   Miss  Cover
---------------------------------------------
src/routes/products.py       45      5    89%
src/orm/product.py           28      0   100%
src/middleware/auth.py        32      8    75%
---------------------------------------------
TOTAL                       105     13    88%
```

For HTML coverage reports:

```bash
tina4 test --cov=src --cov-report=html
```

Open `htmlcov/index.html` in your browser to see a visual breakdown of which lines are covered by tests.

---

## 10. Testing Best Practices

### Test One Thing Per Test

Each test method should verify one behavior. If it fails, you know exactly what broke.

```python
# Good: each test verifies one thing
def test_create_product_returns_201(self):
    resp = self.post("/api/products", {"name": "Widget", "price": 9.99})
    assert_equal(resp.status_code, 201, "Should return 201")

def test_create_product_returns_created_product(self):
    resp = self.post("/api/products", {"name": "Widget", "price": 9.99})
    body = json.loads(resp.body)
    assert_equal(body["name"], "Widget", "Should return the product name")

# Avoid: testing multiple unrelated things
def test_everything(self):
    # Creates, reads, updates, deletes, checks auth, validates input...
    # When this fails, you don't know which part broke
    pass
```

### Use Descriptive Assertion Messages

```python
# Good: tells you what went wrong
assert_equal(user.name, "Alice", "User name should be 'Alice' after creation")

# Bad: unhelpful when it fails
assert_equal(user.name, "Alice", "Failed")
```

### Isolate Tests

Each test should create its own data and clean up after itself. Never depend on data from another test or from the development database.

```python
# Good: creates its own data
def test_delete_product(self):
    product = Product()
    product.name = "Temporary"
    product.price = 1.00
    product.save()

    product.delete()

    check = Product.find(product.id)
    assert_true(check is None, "Product should be deleted")

# Bad: depends on data from another test or the dev database
def test_delete_product(self):
    product = Product.find(1)  # Assumes product with ID 1 exists
    product.delete()
```

---

## 11. Exercise: Test a User Model and Authentication Flow

Write a complete test suite for a User model and authentication system.

### Requirements

Create `tests/test_user_model.py` with these tests:

1. **test_create_user** -- Create a user with name, email. Verify the user gets an ID and all fields are correct.
2. **test_duplicate_email** -- Try to create two users with the same email. Verify the second one raises an exception or returns an error.
3. **test_update_user** -- Create a user, update their name, reload and verify.
4. **test_delete_user** -- Create a user, delete them, verify they cannot be loaded.
5. **test_select_users** -- Create 3 users, query all, verify count is at least 3.

Create `tests/test_auth_flow.py` with these tests:

1. **test_register_new_user** -- POST to `/api/auth/register` with name, email, password. Verify 201 status.
2. **test_register_duplicate_email** -- Register the same email twice. Verify the second returns 409 Conflict.
3. **test_login_success** -- Login with correct credentials. Verify you get a JWT token.
4. **test_login_failure** -- Login with wrong password. Verify 401 status.
5. **test_access_protected_route** -- Use the token from login to access `/api/profile`. Verify 200 status and correct user data.
6. **test_access_with_expired_token** -- Use a manually crafted expired token. Verify 401 status.

### Expected output:

```bash
tina4 test
```

```
Running tests...

  UserModelTest
    [PASS] test_create_user
    [PASS] test_duplicate_email
    [PASS] test_update_user
    [PASS] test_delete_user
    [PASS] test_select_users

  AuthFlowTest
    [PASS] test_register_new_user
    [PASS] test_register_duplicate_email
    [PASS] test_login_success
    [PASS] test_login_failure
    [PASS] test_access_protected_route
    [PASS] test_access_with_expired_token

  11 tests, 11 passed, 0 failed (0.52s)
```

---

## 12. Solution

### tests/test_user_model.py

```python
import uuid
from tina4_python.test import Test, assert_equal, assert_true, assert_not_none, assert_raises

class UserModelTest(Test):

    def test_create_user(self):
        user = User()
        user.name = "Test User"
        user.email = f"testuser-{uuid.uuid4().hex[:8]}@example.com"
        user.save()

        assert_not_none(user.id, "User should have an ID after save")
        assert_equal(user.name, "Test User", "Name should match")
        assert_true("@example.com" in user.email, "Email should be set")

    def test_duplicate_email(self):
        email = f"duplicate-{uuid.uuid4().hex[:8]}@example.com"

        user1 = User()
        user1.name = "First User"
        user1.email = email
        user1.save()

        def create_duplicate():
            user2 = User()
            user2.name = "Second User"
            user2.email = email
            user2.save()

        assert_raises(create_duplicate, Exception, "Should reject duplicate email")

    def test_update_user(self):
        user = User()
        user.name = "Original Name"
        user.email = f"update-{uuid.uuid4().hex[:8]}@example.com"
        user.save()

        user_id = user.id
        user.name = "New Name"
        user.save()

        reloaded = User.find(user_id)
        assert_equal(reloaded.name, "New Name", "Name should be updated")

    def test_delete_user(self):
        user = User()
        user.name = "Delete Me"
        user.email = f"delete-{uuid.uuid4().hex[:8]}@example.com"
        user.save()

        user_id = user.id
        user.delete()

        gone = User.find(user_id)
        assert_true(gone is None, "Deleted user should not exist")

    def test_select_users(self):
        for i in range(3):
            user = User()
            user.name = f"Select Test User {i}"
            user.email = f"select-test-{i}-{uuid.uuid4().hex[:8]}@example.com"
            user.save()

        users, count = User.where("1=1")

        assert_true(len(users) >= 3, "Should have at least 3 users")
```

### tests/test_auth_flow.py

```python
import uuid
import json
from tina4_python.test import Test, assert_equal, assert_true, assert_not_none

class AuthFlowTest(Test):

    def set_up(self):
        self.test_email = f"auth-test-{uuid.uuid4().hex[:8]}@example.com"
        self.test_password = "SecurePassword123!"

    def test_register_new_user(self):
        resp = self.post("/api/auth/register", {
            "name": "Auth Test User",
            "email": self.test_email,
            "password": self.test_password
        })

        assert_equal(resp.status_code, 201, "Registration should return 201")

        body = json.loads(resp.body)
        assert_equal(body["name"], "Auth Test User", "Should return user name")
        assert_not_none(body.get("id"), "Should return user ID")

    def test_register_duplicate_email(self):
        email = f"dup-{uuid.uuid4().hex[:8]}@example.com"

        self.post("/api/auth/register", {
            "name": "First",
            "email": email,
            "password": self.test_password
        })

        resp = self.post("/api/auth/register", {
            "name": "Second",
            "email": email,
            "password": self.test_password
        })

        assert_equal(resp.status_code, 409, "Duplicate email should return 409")

    def test_login_success(self):
        email = f"login-{uuid.uuid4().hex[:8]}@example.com"

        self.post("/api/auth/register", {
            "name": "Login User",
            "email": email,
            "password": self.test_password
        })

        resp = self.post("/api/auth/login", {
            "email": email,
            "password": self.test_password
        })

        assert_equal(resp.status_code, 200, "Login should return 200")

        body = json.loads(resp.body)
        assert_not_none(body.get("token"), "Should return a token")

    def test_login_failure(self):
        resp = self.post("/api/auth/login", {
            "email": "nobody@example.com",
            "password": "wrong"
        })

        assert_equal(resp.status_code, 401, "Invalid login should return 401")

    def test_access_protected_route(self):
        email = f"profile-{uuid.uuid4().hex[:8]}@example.com"

        self.post("/api/auth/register", {
            "name": "Profile User",
            "email": email,
            "password": self.test_password
        })

        login_resp = self.post("/api/auth/login", {
            "email": email,
            "password": self.test_password
        })

        token = json.loads(login_resp.body)["token"]

        resp = self.get("/api/profile", headers={
            "Authorization": f"Bearer {token}"
        })

        assert_equal(resp.status_code, 200, "Should allow access with valid token")

        body = json.loads(resp.body)
        assert_equal(body["user"]["email"], email, "Should return correct user")

    def test_access_with_expired_token(self):
        resp = self.get("/api/profile", headers={
            "Authorization": "Bearer expired.invalid.token"
        })

        assert_equal(resp.status_code, 401, "Should reject invalid token")
```

---

## 13. Gotchas

### 1. Tests Run in Order

**Problem:** Test B depends on data created in Test A, but sometimes Test B fails.

**Cause:** While tests within a class run in the order they are defined, test classes may run in any order. If Test B depends on Test A being in a different class, this is fragile.

**Fix:** Each test should create its own data. Never depend on another test's side effects. Use `set_up()` to create the data each test needs.

### 2. Test Database vs Development Database

**Problem:** Running tests deletes your development data.

**Cause:** Tests are running against the same database as your development server.

**Fix:** Tina4 uses a separate test database by default (`data/test.db`). If your tests are modifying development data, check that `TINA4_TEST_DATABASE_URL` is set correctly in `.env`, or that you are running `tina4 test` (not executing test files manually with `python`).

### 3. Unique Constraint Failures

**Problem:** Tests fail with "UNIQUE constraint failed" on the email field.

**Cause:** Previous test runs left data in the test database, or two tests create records with the same email.

**Fix:** Use `uuid.uuid4().hex[:8]` or `int(time.time())` to generate unique values in tests:

```python
user.email = f"test-{uuid.uuid4().hex[:8]}@example.com"
```

### 4. Test Method Not Discovered

**Problem:** You wrote a test method but it does not appear in the output.

**Cause:** The method name does not start with `test`. Tina4 only runs methods that begin with `test` (case-sensitive).

**Fix:** Rename the method to start with `test`: `test_create_product`, `test_login_failure`, etc.

### 5. Assertion Arguments Reversed

**Problem:** The failure message shows "Expected: 404, Actual: 200" but that seems backward.

**Cause:** You passed the arguments in the wrong order. `assert_equal(actual, expected)` -- actual comes first, expected comes second.

**Fix:** Follow the convention: `assert_equal(resp.status_code, 200, "message")`. The first argument is what you got, the second is what you expected.

### 6. Cannot Test Routes That Require Authentication Setup

**Problem:** Tests for protected routes fail because the authentication middleware expects a database table or JWT secret that does not exist in the test environment.

**Cause:** The test database is empty -- it does not have the users table or the JWT secret is not configured.

**Fix:** Use `set_up()` to create the necessary data:

```python
def set_up(self):
    user = User()
    user.create_table()

    user.name = "Test Admin"
    user.email = "admin@test.com"
    user.password_hash = hash_password("password")
    user.save()
```

### 7. Tests Pass Locally but Fail in CI

**Problem:** All tests pass on your machine but fail in continuous integration.

**Cause:** The CI environment may have a different Python version, missing packages, or different filesystem permissions. Also, tests that depend on time or random values can be flaky.

**Fix:** Make tests deterministic. Avoid relying on the current time, filesystem state, or external services. If you must test time-dependent behavior, mock the clock or use fixed timestamps. Check that your CI environment matches your local Python version and has all required packages.
