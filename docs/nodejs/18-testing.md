# Chapter 18: Testing

## 1. Why Tests Matter More Than You Think

Friday afternoon. Your client reports a critical bug in production. You fix it -- one line. But did that fix break something else? 47 routes. 12 ORM models. 3 middleware functions. Clicking through every page takes an hour. Running the test suite takes 2 seconds.

```bash
npm test
```

```
Running tests...

  add
    + add([[5, 3]]) == 8
    + add([[null]]) raises Error

  isEven
    + isEven([[4]]) is truthy
    + isEven([[3]]) is falsy

  4 tests: 4 passed, 0 failed, 0 errors
```

Everything still works. Deploy with confidence. Weekend intact.

Tina4 ships an inline testing framework. No external packages. No Jest configuration. No setup ceremony.

---

## 2. Your First Test

Tina4's testing framework uses a decorator-style pattern. Attach test assertions directly to functions using `tests()`, `assertEqual()`, `assertThrows()`, `assertTrue()`, and `assertFalse()`. Then call `runAllTests()` to execute them.

Create `tests/basic.ts`:

```typescript
import { tests, assertEqual, assertThrows, assertTrue, assertFalse, runAllTests } from "tina4-nodejs";

const add = tests(
    assertEqual([5, 3], 8),
    assertEqual([0, 0], 0),
    assertThrows(Error, [null]),
)(function add(a: number, b: number | null = null): number {
    if (b === null) throw new Error("b required");
    return a + b;
});

const isEven = tests(
    assertTrue([4]),
    assertFalse([3]),
)(function isEven(n: number): boolean {
    return n % 2 === 0;
});

runAllTests();
```

Run it:

```bash
tina4 test
```

```
  add
    + add([[5, 3]]) == 8
    + add([[0, 0]]) == 0
    + add([[null]]) raises Error

  isEven
    + isEven([[4]]) is truthy
    + isEven([[3]]) is falsy

  5 tests: 5 passed, 0 failed, 0 errors
```

### How It Works

1. The `tests()` function takes assertion objects and returns a decorator.
2. The decorator wraps the function, registers it in the test registry, and returns the original function unchanged.
3. The function works normally in production code -- tests only execute when you call `runAllTests()`.
4. Named functions produce readable output. Anonymous functions show as "anonymous."

---

## 3. Assertion Functions

| Function | Description |
|----------|-------------|
| `assertEqual(args, expected)` | Call the function with `args` array, expect `expected` as the return value |
| `assertThrows(ErrorClass, args)` | Call the function with `args` array, expect it to throw `ErrorClass` |
| `assertTrue(args)` | Call the function with `args` array, expect a truthy return value |
| `assertFalse(args)` | Call the function with `args` array, expect a falsy return value |

Each assertion specifies the arguments to pass and the expected outcome. The `args` parameter is always an array of arguments.

### assertEqual

```typescript
assertEqual([5, 3], 8)     // Call with 5, 3 -- expect 8
assertEqual(["hello"], 5)  // Call with "hello" -- expect 5
```

### assertThrows

```typescript
assertThrows(Error, [null])         // Expect Error when called with null
assertThrows(TypeError, ["bad"])    // Expect TypeError when called with "bad"
```

### assertTrue / assertFalse

```typescript
assertTrue([4])     // Expect a truthy return value
assertFalse([0])    // Expect a falsy return value
```

---

## 4. Testing Business Logic

```typescript
import { tests, assertEqual, assertThrows, runAllTests } from "tina4-nodejs";

const calculateDiscount = tests(
    assertEqual([100, 10], 90),
    assertEqual([50, 0], 50),
    assertEqual([200, 50], 100),
    assertThrows(Error, [100, -5]),
    assertThrows(Error, [100, 101]),
)(function calculateDiscount(price: number, discountPercent: number): number {
    if (discountPercent < 0 || discountPercent > 100) {
        throw new Error("Discount must be between 0 and 100");
    }
    return price - (price * discountPercent / 100);
});

runAllTests();
```

The function works in production. The tests run only when you call `runAllTests()`.

---

## 5. Testing ORM Models

Test your models by writing functions that exercise create, read, update, and delete:

```typescript
import { tests, assertTrue, assertEqual, runAllTests } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

const testCreateProduct = tests(
    assertTrue([]),
)(function testCreateProduct(): boolean {
    const product = new Product({
        name: "Test Widget",
        category: "Testing",
        price: 19.99,
    });
    product.save();
    return product.id !== undefined && product.id > 0;
});

const testLoadProduct = tests(
    assertTrue([]),
)(function testLoadProduct(): boolean {
    const product = new Product({ name: "Load Test", price: 29.99 });
    product.save();

    const loaded = Product.findById(product.id);
    return loaded !== null && loaded.name === "Load Test";
});

const testUpdateProduct = tests(
    assertTrue([]),
)(function testUpdateProduct(): boolean {
    const product = new Product({ name: "Update Test", price: 10 });
    product.save();

    product.name = "Updated Widget";
    product.price = 15;
    product.save();

    const reloaded = Product.findById(product.id);
    return reloaded !== null && reloaded.name === "Updated Widget" && reloaded.price === 15;
});

const testDeleteProduct = tests(
    assertTrue([]),
)(function testDeleteProduct(): boolean {
    const product = new Product({ name: "Delete Me", price: 5 });
    product.save();
    const id = product.id;

    product.delete();

    const gone = Product.findById(id);
    return gone === null;
});

runAllTests();
```

### Test Database

Use a separate database for tests so development data stays safe:

```env
TINA4_TEST_DATABASE_URL=sqlite:///data/test.db
```

---

## 6. Testing Routes

Write functions that exercise your API endpoints end-to-end:

```typescript
import { tests, assertTrue, assertEqual, runAllTests } from "tina4-nodejs";

const testHealthEndpoint = tests(
    assertTrue([]),
)(function testHealthEndpoint(): boolean {
    // Use the test client to send HTTP requests
    const resp = testClient.get("/health");
    return resp.status === 200 && resp.body.status === "ok";
});

const testCreateProduct = tests(
    assertTrue([]),
)(function testCreateProduct(): boolean {
    const resp = testClient.post("/api/products", {
        name: "Route Test Product",
        category: "Testing",
        price: 42,
    });
    return resp.status === 201 && resp.body.name === "Route Test Product";
});

const testGetNotFound = tests(
    assertTrue([]),
)(function testGetNotFound(): boolean {
    const resp = testClient.get("/api/products/99999");
    return resp.status === 404;
});

runAllTests();
```

---

## 7. Testing Authentication

```typescript
import { tests, assertTrue, runAllTests, Auth } from "tina4-nodejs";

const secret = "test-secret";

const testTokenRoundTrip = tests(
    assertTrue([{ userId: 1, role: "admin" }]),
)(function testTokenRoundTrip(payload: Record<string, unknown>): boolean {
    const token = Auth.getToken(payload, secret);
    const decoded = Auth.validToken(token, secret);
    return decoded !== null && decoded.userId === payload.userId;
});

const testPasswordHash = tests(
    assertTrue(["securePass123"]),
    assertTrue(["another-password"]),
)(function testPasswordHash(password: string): boolean {
    const hash = Auth.hashPassword(password);
    return Auth.checkPassword(password, hash);
});

const testInvalidToken = tests(
    assertTrue([]),
)(function testInvalidToken(): boolean {
    const decoded = Auth.validToken("invalid.token.here", secret);
    return decoded === null;
});

runAllTests();
```

---

## 8. Resetting Tests Between Files

When running tests across multiple files, use `resetTests()` to clear the registry:

```typescript
import { resetTests, tests, assertEqual, runAllTests } from "tina4-nodejs";

resetTests();

const multiply = tests(
    assertEqual([3, 4], 12),
    assertEqual([0, 5], 0),
)(function multiply(a: number, b: number): number {
    return a * b;
});

runAllTests();
```

Without resetting, tests from previously imported modules accumulate in the registry.

---

## 9. Runner Options

`runAllTests()` accepts an options object:

```typescript
// Quiet mode -- no console output, returns results only
const results = runAllTests({ quiet: true });
console.log(`${results.passed} passed, ${results.failed} failed`);

// Fail fast -- stop on the first failure
runAllTests({ failfast: true });
```

The returned `TestResults` object:

| Property | Type | Description |
|----------|------|-------------|
| `passed` | number | Assertions that passed |
| `failed` | number | Assertions that failed |
| `errors` | number | Unexpected errors |
| `details` | array | Array of `{ name, status, message? }` objects |

### CI Integration

Use the return value for CI exit codes:

```typescript
const results = runAllTests();
process.exit(results.failed === 0 ? 0 : 1);
```

---

## 10. Running Tests

### Run All Tests

```bash
npm test
```

This runs `tests/run-all.ts` which discovers and executes all test files.

### Run a Specific Test File

```bash
tina4 test tests/basic.ts
```

### With npm Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "test": "npx tsx tests/run-all.ts",
    "test:products": "npx tsx tests/products.ts",
    "test:auth": "npx tsx tests/auth.ts"
  }
}
```

---

## 11. Testing Best Practices

### Test One Thing Per Function

Each test function should verify one behavior. When it fails, you know exactly what broke.

```typescript
// Good: each function tests one thing
const testCreateReturnsId = tests(
    assertTrue([]),
)(function testCreateReturnsId(): boolean {
    const product = new Product({ name: "Widget", price: 9.99 });
    product.save();
    return product.id > 0;
});

const testCreateSetsDefaults = tests(
    assertTrue([]),
)(function testCreateSetsDefaults(): boolean {
    const product = new Product({ name: "Widget", price: 9.99 });
    product.save();
    return product.category === "Uncategorized";
});
```

### Use Named Functions for Readable Output

```typescript
// Good: readable test names
const testLoginRejects = tests(assertTrue([]))(
    function testLoginRejectsInvalidPassword(): boolean { /* ... */ }
);

// Bad: anonymous function
const test = tests(assertTrue([]))(
    () => { /* shows as "anonymous" in output */ }
);
```

### Isolate Tests

Each test should create its own data. Never depend on data from another test or from the development database.

```typescript
// Good: creates its own data
function testDeleteProduct(): boolean {
    const product = new Product({ name: "Temporary", price: 1 });
    product.save();
    product.delete();
    return Product.findById(product.id) === null;
}

// Bad: depends on external state
function testDeleteProduct(): boolean {
    const product = Product.findById(1); // Assumes ID 1 exists
    product.delete();
    return true;
}
```

### Use Unique Values

Prevent unique constraint failures by generating unique data:

```typescript
function testCreateUser(): boolean {
    const email = `test-${Date.now()}@example.com`;
    const user = new User({ name: "Test User", email });
    user.save();
    return user.id > 0;
}
```

---

## 12. Failed Test Output

When a test fails, the output shows exactly what went wrong:

```
  calculateDiscount
    + calculateDiscount([[100, 10]]) == 90
    - calculateDiscount([[200, 50]]) == 100
      Expected: 100
      Got: 150
    + calculateDiscount([[100, -5]]) raises Error

  3 tests: 2 passed, 1 failed, 0 errors
```

The failure message shows the function name, the arguments, what was expected, and what was received. Find the line. Fix the logic. Run again.

---

## 13. Exercise: Write Tests for Utility Functions

Write inline tests for the following functions:

1. A `slugify` function that converts `"Hello World"` to `"hello-world"`
2. A `clamp` function that constrains a number between a min and max
3. A `parsePrice` function that extracts a number from `"$19.99"` and throws on invalid input

---

## 14. Solution

```typescript
import { tests, assertEqual, assertThrows, runAllTests } from "tina4-nodejs";

const slugify = tests(
    assertEqual(["Hello World"], "hello-world"),
    assertEqual(["  Multiple   Spaces  "], "multiple-spaces"),
    assertEqual(["UPPERCASE"], "uppercase"),
    assertEqual(["already-slugged"], "already-slugged"),
)(function slugify(input: string): string {
    return input.trim().toLowerCase().replace(/\s+/g, "-");
});

const clamp = tests(
    assertEqual([5, 0, 10], 5),
    assertEqual([-5, 0, 10], 0),
    assertEqual([15, 0, 10], 10),
    assertEqual([0, 0, 0], 0),
)(function clamp(value: number, min: number, max: number): number {
    return Math.min(Math.max(value, min), max);
});

const parsePrice = tests(
    assertEqual(["$19.99"], 19.99),
    assertEqual(["$0.50"], 0.5),
    assertThrows(Error, ["not-a-price"]),
    assertThrows(Error, [""]),
)(function parsePrice(input: string): number {
    const match = input.match(/\$?([\d.]+)/);
    if (!match) throw new Error("Invalid price format");
    const value = parseFloat(match[1]);
    if (isNaN(value)) throw new Error("Invalid price format");
    return value;
});

runAllTests();
```

---

## 15. Gotchas

### 1. The `tests()` Decorator Returns the Original Function

The wrapped function works identically in production. Tests only run when you call `runAllTests()`. You can use the decorated function in your application code without side effects.

### 2. Arguments Are Passed as an Array

`assertEqual([5, 3], 8)` means "call the function with arguments `5` and `3`, expect `8`." The first argument is always an array.

### 3. Named Functions Are Required for Readable Output

Anonymous functions show up as "anonymous" in test output. Use named function expressions: `function testCreateProduct() {}` not `() => {}`.

### 4. Call `resetTests()` Between Separate Test Files

Without resetting, tests from previously imported modules accumulate in the registry. Each test file should call `resetTests()` at the top.

### 5. `runAllTests()` Returns Results

Use the return value for CI integration. Check `results.failed === 0` to determine the exit code. Without this, your CI pipeline passes even when tests fail.

### 6. Database State Carries Between Tests

**Problem:** A test fails because a previous test left data in the database.

**Fix:** Each test should create its own data and clean up after itself. Use a separate test database. Reset it before each test run.

### 7. Async Functions Need Special Handling

**Problem:** You test an async function but the test finishes before the Promise resolves.

**Fix:** Wrap async operations in a synchronous test function that blocks on the result. Or structure your test to validate the return value of the resolved Promise.
