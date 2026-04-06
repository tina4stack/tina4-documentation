# Chapter 18: Testing

## 1. Why Tests Matter More Than You Think

Friday afternoon. Your client reports a critical bug in production. You fix it. One line of code. But did that fix break anything else? You have 47 routes, 12 ORM models, and 3 middleware functions. Manually clicking through every page takes an hour. Running the test suite takes 2 seconds.

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

Everything still works. Deploy with confidence. Enjoy your weekend.

Tina4 includes an inline testing framework. No external packages. No PHPUnit configuration. Write a test. Run it. Done.

---

## 2. Your First Test

Tests live in the `tests/` directory. Every `.php` file there is auto-discovered when you run `tina4 test`.

Create `tests/BasicTest.php`:

```php
<?php
use Tina4\Test;

class BasicTest extends Test
{
    public function testAddition()
    {
        $this->assertEqual(2 + 2, 4, "Basic addition should work");
    }

    public function testStringContains()
    {
        $greeting = "Hello, World!";
        $this->assertTrue(str_contains($greeting, "World"), "Greeting should contain 'World'");
    }

    public function testArrayLength()
    {
        $items = [1, 2, 3, 4, 5];
        $this->assertEqual(count($items), 5, "Array should have 5 items");
    }
}
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

1. Your test class extends `Tina4\Test`.
2. Every method that starts with `test` is a test case. The method name is converted to a readable label: `testAddition` becomes `test_addition`.
3. Inside each test, you call assertion methods to verify behavior.
4. If all assertions pass, the test passes. If any assertion fails, the test fails and you see the failure message.

---

## 3. Assertion Methods

Tina4's Test class provides these assertion methods:

### assertEqual($actual, $expected, $message)

Checks that two values are equal.

```php
$this->assertEqual(4, 4, "Should be equal");              // PASS
$this->assertEqual("hello", "hello", "Strings match");    // PASS
$this->assertEqual(4, 5, "Not equal");                     // FAIL
```

### assertTrue($value, $message)

Checks that a value is truthy.

```php
$this->assertTrue(true, "Should be true");                // PASS
$this->assertTrue(1, "1 is truthy");                      // PASS
$this->assertTrue("yes", "Non-empty string is truthy");   // PASS
$this->assertTrue(false, "This fails");                   // FAIL
$this->assertTrue(0, "Zero is falsy");                    // FAIL
```

### assertFalse($value, $message)

Checks that a value is falsy.

```php
$this->assertFalse(false, "Should be false");             // PASS
$this->assertFalse(0, "Zero is falsy");                   // PASS
$this->assertFalse("", "Empty string is falsy");          // PASS
$this->assertFalse(true, "This fails");                   // FAIL
```

### assertRaises($callable, $exceptionClass, $message)

Checks that a function throws a specific exception.

```php
$this->assertRaises(function () {
    throw new \InvalidArgumentException("Bad input");
}, \InvalidArgumentException::class, "Should throw InvalidArgumentException");

$this->assertRaises(function () {
    $result = 10 / 0;
}, \DivisionByZeroError::class, "Should throw on division by zero");
```

### assertNotEqual($actual, $expected, $message)

Checks that two values are not equal.

```php
$this->assertNotEqual("hello", "world", "Strings differ");  // PASS
$this->assertNotEqual(4, 4, "Same values");                  // FAIL
```

### assertNull($value, $message)

Checks that a value is null.

```php
$this->assertNull(null, "Should be null");     // PASS
$this->assertNull("hello", "Not null");         // FAIL
```

### assertNotNull($value, $message)

Checks that a value is not null.

```php
$this->assertNotNull("hello", "Has value");    // PASS
$this->assertNotNull(null, "Is null");          // FAIL
```

---

## 4. Testing ORM Models

Test a Product model. Create records. Load them. Update them. Delete them.

Create `tests/ProductTest.php`:

```php
<?php
use Tina4\Test;

class ProductTest extends Test
{
    private ?int $testProductId = null;

    public function testCreateProduct()
    {
        $product = new Product();
        $product->name = "Test Widget";
        $product->category = "Testing";
        $product->price = 19.99;
        $product->inStock = true;
        $product->save();

        $this->assertNotNull($product->id, "Product should have an ID after save");
        $this->assertTrue($product->id > 0, "Product ID should be positive");

        $this->testProductId = $product->id;
    }

    public function testLoadProduct()
    {
        // Create a product to load
        $product = new Product();
        $product->name = "Load Test Widget";
        $product->category = "Testing";
        $product->price = 29.99;
        $product->save();

        // Load it back
        $loaded = new Product();
        $loaded->load($product->id);

        $this->assertEqual($loaded->name, "Load Test Widget", "Name should match");
        $this->assertEqual($loaded->category, "Testing", "Category should match");
        $this->assertEqual($loaded->price, 29.99, "Price should match");
        $this->assertTrue($loaded->inStock, "Should be in stock by default");
    }

    public function testUpdateProduct()
    {
        $product = new Product();
        $product->name = "Update Test Widget";
        $product->price = 10.00;
        $product->save();

        $id = $product->id;

        // Update it
        $product->name = "Updated Widget";
        $product->price = 15.00;
        $product->save();

        // Reload and verify
        $reloaded = new Product();
        $reloaded->load($id);

        $this->assertEqual($reloaded->name, "Updated Widget", "Name should be updated");
        $this->assertEqual($reloaded->price, 15.00, "Price should be updated");
    }

    public function testDeleteProduct()
    {
        $product = new Product();
        $product->name = "Delete Me";
        $product->price = 5.00;
        $product->save();

        $id = $product->id;
        $product->delete();

        // Try to load the deleted product
        $gone = new Product();
        $gone->load($id);

        $this->assertTrue(empty($gone->id), "Deleted product should not be loadable");
    }

    public function testSelectWithFilter()
    {
        // Create products in different categories
        $p1 = new Product();
        $p1->name = "Filter Test A";
        $p1->category = "FilterCat";
        $p1->price = 10.00;
        $p1->save();

        $p2 = new Product();
        $p2->name = "Filter Test B";
        $p2->category = "FilterCat";
        $p2->price = 20.00;
        $p2->save();

        $p3 = new Product();
        $p3->name = "Other Product";
        $p3->category = "Other";
        $p3->price = 30.00;
        $p3->save();

        // Query by category
        $product = new Product();
        $results = $product->select("*", "category = :cat", ["cat" => "FilterCat"]);

        $this->assertTrue(count($results) >= 2, "Should find at least 2 FilterCat products");

        $names = array_map(fn($p) => $p->name, $results);
        $this->assertTrue(in_array("Filter Test A", $names), "Should include Filter Test A");
        $this->assertTrue(in_array("Filter Test B", $names), "Should include Filter Test B");
    }
}
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

```bash
TINA4_TEST_DATABASE_URL=sqlite:///data/test.db
```

---

## 5. Testing Routes

Tina4 provides a test client for HTTP requests to your routes. No server needed.

Create `tests/RouteTest.php`:

```php
<?php
use Tina4\Test;

class RouteTest extends Test
{
    public function testHealthEndpoint()
    {
        $response = $this->get("/health");

        $this->assertEqual($response->statusCode, 200, "Health check should return 200");

        $body = json_decode($response->body, true);
        $this->assertEqual($body["status"], "ok", "Status should be 'ok'");
        $this->assertNotNull($body["version"], "Should include version");
    }

    public function testGetProducts()
    {
        $response = $this->get("/api/products");

        $this->assertEqual($response->statusCode, 200, "Should return 200");

        $body = json_decode($response->body, true);
        $this->assertTrue(isset($body["data"]) || isset($body["products"]), "Should contain product data");
    }

    public function testCreateProduct()
    {
        $response = $this->post("/api/products", [
            "name" => "Route Test Product",
            "category" => "Testing",
            "price" => 42.00
        ]);

        $this->assertEqual($response->statusCode, 201, "Should return 201 Created");

        $body = json_decode($response->body, true);
        $this->assertEqual($body["name"], "Route Test Product", "Name should match");
        $this->assertEqual($body["price"], 42.00, "Price should match");
    }

    public function testGetProductNotFound()
    {
        $response = $this->get("/api/products/99999");

        $this->assertEqual($response->statusCode, 404, "Should return 404 for missing product");
    }

    public function testCreateProductValidation()
    {
        $response = $this->post("/api/products", []);

        $this->assertEqual($response->statusCode, 400, "Should return 400 for empty body");
    }

    public function testDeleteProduct()
    {
        // Create a product first
        $createResponse = $this->post("/api/products", [
            "name" => "To Be Deleted",
            "price" => 1.00
        ]);
        $body = json_decode($createResponse->body, true);
        $id = $body["id"];

        // Delete it
        $deleteResponse = $this->delete("/api/products/" . $id);
        $this->assertEqual($deleteResponse->statusCode, 204, "Should return 204 No Content");

        // Verify it is gone
        $getResponse = $this->get("/api/products/" . $id);
        $this->assertEqual($getResponse->statusCode, 404, "Should return 404 after deletion");
    }
}
```

### Test Client Methods

The test client provides methods for all HTTP verbs:

```php
// GET request
$response = $this->get("/api/products");

// GET with query parameters
$response = $this->get("/api/products?category=Electronics&page=2");

// POST with JSON body
$response = $this->post("/api/products", ["name" => "Widget", "price" => 9.99]);

// PUT with JSON body
$response = $this->put("/api/products/1", ["name" => "Updated Widget"]);

// PATCH with JSON body
$response = $this->patch("/api/products/1", ["price" => 12.99]);

// DELETE
$response = $this->delete("/api/products/1");

// Request with custom headers
$response = $this->get("/api/profile", [
    "Authorization" => "Bearer eyJhbGciOiJIUzI1NiIs..."
]);
```

### Response Object

The response object has these properties:

```php
$response->statusCode;   // HTTP status code (200, 201, 404, etc.)
$response->body;         // Response body as a string
$response->headers;      // Response headers as an associative array
$response->contentType;  // Content-Type header value
```

---

## 6. Testing Authentication

Create `tests/AuthTest.php`:

```php
<?php
use Tina4\Test;

class AuthTest extends Test
{
    private ?string $token = null;

    public function testLoginWithValidCredentials()
    {
        $response = $this->post("/api/auth/login", [
            "email" => "admin@example.com",
            "password" => "correct-password"
        ]);

        $this->assertEqual($response->statusCode, 200, "Login should succeed");

        $body = json_decode($response->body, true);
        $this->assertNotNull($body["token"], "Should return a JWT token");
        $this->assertTrue(strlen($body["token"]) > 50, "Token should be a substantial string");

        $this->token = $body["token"];
    }

    public function testLoginWithInvalidPassword()
    {
        $response = $this->post("/api/auth/login", [
            "email" => "admin@example.com",
            "password" => "wrong-password"
        ]);

        $this->assertEqual($response->statusCode, 401, "Should reject invalid password");
    }

    public function testLoginWithMissingFields()
    {
        $response = $this->post("/api/auth/login", [
            "email" => "admin@example.com"
        ]);

        $this->assertTrue(
            $response->statusCode === 400 || $response->statusCode === 401,
            "Should reject missing password"
        );
    }

    public function testProtectedRouteWithoutToken()
    {
        $response = $this->get("/api/profile");

        $this->assertEqual($response->statusCode, 401, "Should reject unauthenticated request");
    }

    public function testProtectedRouteWithValidToken()
    {
        // Login first to get a token
        $loginResponse = $this->post("/api/auth/login", [
            "email" => "admin@example.com",
            "password" => "correct-password"
        ]);
        $loginBody = json_decode($loginResponse->body, true);
        $token = $loginBody["token"];

        // Access protected route with token
        $response = $this->get("/api/profile", [
            "Authorization" => "Bearer " . $token
        ]);

        $this->assertEqual($response->statusCode, 200, "Should allow authenticated request");

        $body = json_decode($response->body, true);
        $this->assertEqual($body["user"]["email"], "admin@example.com", "Should return user data");
    }

    public function testProtectedRouteWithInvalidToken()
    {
        $response = $this->get("/api/profile", [
            "Authorization" => "Bearer invalid.token.here"
        ]);

        $this->assertEqual($response->statusCode, 401, "Should reject invalid token");
    }
}
```

---

## 7. Setup and Teardown

Use `setUp()` and `tearDown()` methods to run code before and after each test:

```php
<?php
use Tina4\Test;

class UserTest extends Test
{
    private ?int $userId = null;

    public function setUp(): void
    {
        // Runs before each test
        $user = new User();
        $user->name = "Test User";
        $user->email = "test-" . time() . "@example.com";
        $user->save();
        $this->userId = $user->id;
    }

    public function tearDown(): void
    {
        // Runs after each test
        if ($this->userId) {
            $user = new User();
            $user->load($this->userId);
            if (!empty($user->id)) {
                $user->delete();
            }
        }
    }

    public function testUserExists()
    {
        $user = new User();
        $user->load($this->userId);
        $this->assertNotNull($user->id, "User should exist");
        $this->assertEqual($user->name, "Test User", "Name should match");
    }

    public function testUpdateUser()
    {
        $user = new User();
        $user->load($this->userId);
        $user->name = "Updated Name";
        $user->save();

        $reloaded = new User();
        $reloaded->load($this->userId);
        $this->assertEqual($reloaded->name, "Updated Name", "Name should be updated");
    }
}
```

`setUp()` runs before every test method. `tearDown()` runs after every test method. Pass or fail, the cleanup runs. Each test starts with a clean state.

---

## 8. Running Tests

### Run All Tests

```bash
tina4 test
```

### Run a Specific Test File

```bash
tina4 test --file tests/ProductTest.php
```

### Run a Specific Test Method

```bash
tina4 test --file tests/ProductTest.php --method testCreateProduct
```

### Verbose Output

```bash
tina4 test --verbose
```

```
Running tests...

  ProductTest
    [PASS] test_create_product (0.03s)
      assertEqual: Product should have an ID after save
      assertTrue: Product ID should be positive
    [PASS] test_load_product (0.02s)
      assertEqual: Name should match
      assertEqual: Category should match
      assertEqual: Price should match
      assertTrue: Should be in stock by default
    [PASS] test_update_product (0.04s)
      assertEqual: Name should be updated
      assertEqual: Price should be updated
    [PASS] test_delete_product (0.02s)
      assertTrue: Deleted product should not be loadable
    [PASS] test_select_with_filter (0.05s)
      assertTrue: Should find at least 2 FilterCat products
      assertTrue: Should include Filter Test A
      assertTrue: Should include Filter Test B

  5 tests, 5 passed, 0 failed (0.16s)
```

Verbose mode shows each assertion within each test, along with timing information.

### Failed Test Output

When a test fails, you see exactly what went wrong:

```
  ProductTest
    [PASS] test_create_product
    [FAIL] test_load_product
      assertEqual FAILED: Name should match
        Expected: "Load Test Widget"
        Actual:   "Wrong Name"
        File: tests/ProductTest.php:34
    [PASS] test_update_product

  3 tests, 2 passed, 1 failed (0.12s)
```

The failure message shows the assertion that failed, what was expected, what was actually received, and the file and line number.

---

## 9. PHPUnit Integration

If your team already uses PHPUnit, Tina4 tests can run alongside it. Install PHPUnit via Composer:

```bash
composer require --dev phpunit/phpunit
```

Create `phpunit.xml` at the project root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit bootstrap="vendor/autoload.php"
         colors="true"
         stopOnFailure="false">
    <testsuites>
        <testsuite name="Application">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
</phpunit>
```

Tina4's `Test` class is compatible with PHPUnit. Your test files work with both `tina4 test` and `vendor/bin/phpunit` without modification.

```bash
vendor/bin/phpunit
```

```
PHPUnit 10.5.0 by Sebastian Bergmann and contributors.

.....                                                              5 / 5 (100%)

Time: 00:00.340, Memory: 8.00 MB

OK (5 tests, 12 assertions)
```

### Code Coverage

With PHPUnit, you can generate code coverage reports:

```bash
vendor/bin/phpunit --coverage-text
```

```
Code Coverage Report:
  Summary:
    Classes:  60.00% (3/5)
    Methods:  75.00% (15/20)
    Lines:    82.14% (115/140)

  Product
    Methods:  100.00% ( 5/ 5)   Lines: 100.00% ( 28/ 28)
  User
    Methods:  66.67% ( 4/ 6)   Lines:  78.95% ( 30/ 38)
```

For HTML coverage reports:

```bash
vendor/bin/phpunit --coverage-html coverage/
```

Open `coverage/index.html` in your browser to see a visual breakdown of which lines are covered by tests.

Note: Code coverage requires the Xdebug or PCOV extension. Install one of them:

```bash
# Xdebug
pecl install xdebug

# PCOV (faster for coverage only)
pecl install pcov
```

---

## 10. Testing Best Practices

### Test One Thing Per Test

Each test method verifies one behavior. When it fails, you know what broke.

```php
// Good: each test verifies one thing
public function testCreateProductReturns201()
{
    $response = $this->post("/api/products", ["name" => "Widget", "price" => 9.99]);
    $this->assertEqual($response->statusCode, 201, "Should return 201");
}

public function testCreateProductReturnsCreatedProduct()
{
    $response = $this->post("/api/products", ["name" => "Widget", "price" => 9.99]);
    $body = json_decode($response->body, true);
    $this->assertEqual($body["name"], "Widget", "Should return the product name");
}

// Avoid: testing multiple unrelated things
public function testEverything()
{
    // Creates, reads, updates, deletes, checks auth, validates input...
    // When this fails, you don't know which part broke
}
```

### Use Descriptive Assertion Messages

```php
// Good: tells you what went wrong
$this->assertEqual($user->name, "Alice", "User name should be 'Alice' after creation");

// Bad: unhelpful when it fails
$this->assertEqual($user->name, "Alice", "Failed");
```

### Isolate Tests

Each test creates its own data and cleans up after itself. Never depend on data from another test or from the development database.

```php
// Good: creates its own data
public function testDeleteProduct()
{
    $product = new Product();
    $product->name = "Temporary";
    $product->price = 1.00;
    $product->save();

    $product->delete();

    $check = new Product();
    $check->load($product->id);
    $this->assertTrue(empty($check->id), "Product should be deleted");
}

// Bad: depends on data from another test or the dev database
public function testDeleteProduct()
{
    $product = new Product();
    $product->load(1);  // Assumes product with ID 1 exists
    $product->delete();
}
```

---

## 11. Exercise: Test a User Model and Authentication Flow

Write a complete test suite for a User model and authentication system.

### Requirements

Create `tests/UserModelTest.php` with these tests:

1. **testCreateUser** -- Create a user with name, email. Verify the user gets an ID and all fields are correct.
2. **testDuplicateEmail** -- Try to create two users with the same email. Verify the second one raises an exception or returns an error.
3. **testUpdateUser** -- Create a user, update their name, reload and verify.
4. **testDeleteUser** -- Create a user, delete them, verify they cannot be loaded.
5. **testSelectUsers** -- Create 3 users, query all, verify count is at least 3.

Create `tests/AuthFlowTest.php` with these tests:

1. **testRegisterNewUser** -- POST to `/api/auth/register` with name, email, password. Verify 201 status.
2. **testRegisterDuplicateEmail** -- Register the same email twice. Verify the second returns 409 Conflict.
3. **testLoginSuccess** -- Login with correct credentials. Verify you get a JWT token.
4. **testLoginFailure** -- Login with wrong password. Verify 401 status.
5. **testAccessProtectedRoute** -- Use the token from login to access `/api/profile`. Verify 200 status and correct user data.
6. **testAccessWithExpiredToken** -- Use a manually crafted expired token. Verify 401 status.

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

### tests/UserModelTest.php

```php
<?php
use Tina4\Test;

class UserModelTest extends Test
{
    public function testCreateUser()
    {
        $user = new User();
        $user->name = "Test User";
        $user->email = "testuser-" . uniqid() . "@example.com";
        $user->save();

        $this->assertNotNull($user->id, "User should have an ID after save");
        $this->assertEqual($user->name, "Test User", "Name should match");
        $this->assertTrue(str_contains($user->email, "@example.com"), "Email should be set");
    }

    public function testDuplicateEmail()
    {
        $email = "duplicate-" . uniqid() . "@example.com";

        $user1 = new User();
        $user1->name = "First User";
        $user1->email = $email;
        $user1->save();

        $this->assertRaises(function () use ($email) {
            $user2 = new User();
            $user2->name = "Second User";
            $user2->email = $email;
            $user2->save();
        }, \Exception::class, "Should reject duplicate email");
    }

    public function testUpdateUser()
    {
        $user = new User();
        $user->name = "Original Name";
        $user->email = "update-" . uniqid() . "@example.com";
        $user->save();

        $id = $user->id;
        $user->name = "New Name";
        $user->save();

        $reloaded = new User();
        $reloaded->load($id);
        $this->assertEqual($reloaded->name, "New Name", "Name should be updated");
    }

    public function testDeleteUser()
    {
        $user = new User();
        $user->name = "Delete Me";
        $user->email = "delete-" . uniqid() . "@example.com";
        $user->save();

        $id = $user->id;
        $user->delete();

        $gone = new User();
        $gone->load($id);
        $this->assertTrue(empty($gone->id), "Deleted user should not exist");
    }

    public function testSelectUsers()
    {
        for ($i = 0; $i < 3; $i++) {
            $user = new User();
            $user->name = "Select Test User " . $i;
            $user->email = "select-test-" . $i . "-" . uniqid() . "@example.com";
            $user->save();
        }

        $user = new User();
        $results = $user->select("*");

        $this->assertTrue(count($results) >= 3, "Should have at least 3 users");
    }
}
```

### tests/AuthFlowTest.php

```php
<?php
use Tina4\Test;

class AuthFlowTest extends Test
{
    private string $testEmail;
    private string $testPassword = "SecurePassword123!";

    public function setUp(): void
    {
        $this->testEmail = "auth-test-" . uniqid() . "@example.com";
    }

    public function testRegisterNewUser()
    {
        $response = $this->post("/api/auth/register", [
            "name" => "Auth Test User",
            "email" => $this->testEmail,
            "password" => $this->testPassword
        ]);

        $this->assertEqual($response->statusCode, 201, "Registration should return 201");

        $body = json_decode($response->body, true);
        $this->assertEqual($body["name"], "Auth Test User", "Should return user name");
        $this->assertNotNull($body["id"], "Should return user ID");
    }

    public function testRegisterDuplicateEmail()
    {
        $email = "dup-" . uniqid() . "@example.com";

        // Register first time
        $this->post("/api/auth/register", [
            "name" => "First",
            "email" => $email,
            "password" => $this->testPassword
        ]);

        // Register again with same email
        $response = $this->post("/api/auth/register", [
            "name" => "Second",
            "email" => $email,
            "password" => $this->testPassword
        ]);

        $this->assertEqual($response->statusCode, 409, "Duplicate email should return 409");
    }

    public function testLoginSuccess()
    {
        $email = "login-" . uniqid() . "@example.com";

        // Register
        $this->post("/api/auth/register", [
            "name" => "Login User",
            "email" => $email,
            "password" => $this->testPassword
        ]);

        // Login
        $response = $this->post("/api/auth/login", [
            "email" => $email,
            "password" => $this->testPassword
        ]);

        $this->assertEqual($response->statusCode, 200, "Login should return 200");

        $body = json_decode($response->body, true);
        $this->assertNotNull($body["token"], "Should return a token");
    }

    public function testLoginFailure()
    {
        $response = $this->post("/api/auth/login", [
            "email" => "nobody@example.com",
            "password" => "wrong"
        ]);

        $this->assertEqual($response->statusCode, 401, "Invalid login should return 401");
    }

    public function testAccessProtectedRoute()
    {
        $email = "profile-" . uniqid() . "@example.com";

        // Register and login
        $this->post("/api/auth/register", [
            "name" => "Profile User",
            "email" => $email,
            "password" => $this->testPassword
        ]);

        $loginResponse = $this->post("/api/auth/login", [
            "email" => $email,
            "password" => $this->testPassword
        ]);

        $token = json_decode($loginResponse->body, true)["token"];

        // Access protected route
        $response = $this->get("/api/profile", [
            "Authorization" => "Bearer " . $token
        ]);

        $this->assertEqual($response->statusCode, 200, "Should allow access with valid token");

        $body = json_decode($response->body, true);
        $this->assertEqual($body["user"]["email"], $email, "Should return correct user");
    }

    public function testAccessWithExpiredToken()
    {
        $response = $this->get("/api/profile", [
            "Authorization" => "Bearer expired.invalid.token"
        ]);

        $this->assertEqual($response->statusCode, 401, "Should reject invalid token");
    }
}
```

---

## 13. Gotchas

### 1. Tests Run in Order

**Problem:** Test B depends on data created in Test A, but sometimes Test B fails.

**Cause:** While tests within a class run in the order they are defined, test classes may run in any order. If Test B depends on Test A being in a different class, this is fragile.

**Fix:** Each test should create its own data. Never depend on another test's side effects. Use `setUp()` to create the data each test needs.

### 2. Test Database vs Development Database

**Problem:** Running tests deletes your development data.

**Cause:** Tests are running against the same database as your development server.

**Fix:** Tina4 uses a separate test database by default (`data/test.db`). If your tests are modifying development data, check that `TINA4_TEST_DATABASE_URL` is set correctly in `.env`, or that you are running `tina4 test` (not executing test files manually).

### 3. Unique Constraint Failures

**Problem:** Tests fail with "UNIQUE constraint failed" on the email field.

**Cause:** Previous test runs left data in the test database, or two tests create records with the same email.

**Fix:** Use `uniqid()` or `time()` to generate unique values in tests:

```php
$user->email = "test-" . uniqid() . "@example.com";
```

### 4. Test Method Not Discovered

**Problem:** You wrote a test method but it does not appear in the output.

**Cause:** The method name does not start with `test`. Tina4 only runs methods that begin with `test` (case-sensitive).

**Fix:** Rename the method to start with `test`: `testCreateProduct`, `testLoginFailure`, etc.

### 5. Assertion Arguments Reversed

**Problem:** The failure message shows "Expected: 404, Actual: 200" but that seems backward.

**Cause:** You passed the arguments in the wrong order. `assertEqual($actual, $expected)` -- actual comes first, expected comes second.

**Fix:** Follow the convention: `$this->assertEqual($response->statusCode, 200, "message")`. The first argument is what you got, the second is what you expected.

### 6. Cannot Test Routes That Require Authentication Setup

**Problem:** Tests for protected routes fail because the authentication middleware expects a database table or JWT secret that does not exist in the test environment.

**Cause:** The test database is empty -- it does not have the users table or the JWT secret is not configured.

**Fix:** Use `setUp()` to create the necessary data:

```php
public function setUp(): void
{
    // Create the users table if it does not exist
    $user = new User();
    $user->createTable();

    // Create a test user
    $user->name = "Test Admin";
    $user->email = "admin@test.com";
    $user->passwordHash = password_hash("password", PASSWORD_DEFAULT);
    $user->save();
}
```

### 7. Tests Pass Locally but Fail in CI

**Problem:** All tests pass on your machine but fail in continuous integration.

**Cause:** The CI environment may have a different PHP version, missing extensions, or different filesystem permissions. Also, tests that depend on time or random values can be flaky.

**Fix:** Make tests deterministic. Avoid relying on the current time, filesystem state, or external services. If you must test time-dependent behavior, mock the clock or use fixed timestamps. Check that your CI environment matches your local PHP version and has all required extensions.
