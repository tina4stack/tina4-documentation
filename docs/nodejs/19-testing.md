# Chapter 17: Testing

## 1. Why Tests Matter More Than You Think

Friday afternoon. Your client reported a critical bug. You fix it -- one line. But did that fix break something else? The test suite answers in 2 seconds.

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

Tina4 ships an inline testing framework. No external packages. No Jest configuration. No setup ceremony.

---

## 2. Your First Test

Tina4's testing framework uses a decorator-style pattern. You attach test assertions directly to functions using `tests()`, `assertEqual()`, `assertThrows()`, `assertTrue()`, and `assertFalse()`. Then call `runAllTests()` to execute them all.

Create `tests/basic.ts`:

```typescript
import { tests, assertEqual, assertThrows, assertTrue, assertFalse, runAllTests } from "tina4-nodejs";

// Define a function and attach inline tests
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

// Run all registered tests
runAllTests();
```

Run it:

```bash
npx tsx tests/basic.ts
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

The `tests()` function takes assertion objects and returns a decorator. The decorator wraps the function, registers it in the test registry, and returns the original function unchanged. The function works normally in production code -- the tests are only executed when you call `runAllTests()`.

---

## 3. Assertion Functions

| Function | Description |
|----------|-------------|
| `assertEqual(args, expected)` | Call function with `args` array, expect `expected` return value |
| `assertThrows(ErrorClass, args)` | Call function with `args` array, expect it to throw an instance of `ErrorClass` |
| `assertTrue(args)` | Call function with `args` array, expect a truthy return value |
| `assertFalse(args)` | Call function with `args` array, expect a falsy return value |

Each assertion specifies the arguments to pass and the expected outcome. The `args` parameter is always an array of arguments.

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

---

## 5. Testing with Authentication

```typescript
import { tests, assertEqual, assertTrue, runAllTests } from "tina4-nodejs";
import { Auth } from "tina4-nodejs";

const secret = "test-secret";

const createAndVerifyToken = tests(
    assertTrue([{ userId: 1, role: "admin" }]),
)(function createAndVerifyToken(payload: Record<string, unknown>): boolean {
    const token = Auth.getToken(payload, secret);
    const decoded = Auth.validToken(token, secret);
    return decoded !== null && decoded.userId === payload.userId;
});

const verifyPasswordHash = tests(
    assertTrue(["securePass123"]),
    assertTrue(["another-password"]),
)(function verifyPasswordHash(password: string): boolean {
    const hash = Auth.hashPassword(password);
    return Auth.checkPassword(password, hash);
});

runAllTests();
```

---

## 6. Resetting Tests Between Files

When running tests across multiple files, use `resetTests()` to clear the registry:

```typescript
import { resetTests, tests, assertEqual, runAllTests } from "tina4-nodejs";

// Clear any previously registered tests
resetTests();

// Register and run fresh tests
const multiply = tests(
    assertEqual([3, 4], 12),
    assertEqual([0, 5], 0),
)(function multiply(a: number, b: number): number {
    return a * b;
});

runAllTests();
```

---

## 7. Runner Options

`runAllTests()` accepts an options object:

```typescript
// Quiet mode -- no console output, just returns the results
const results = runAllTests({ quiet: true });
console.log(`${results.passed} passed, ${results.failed} failed`);

// Fail fast -- stop on the first failure
runAllTests({ failfast: true });
```

The returned `TestResults` object contains:

| Property | Type | Description |
|----------|------|-------------|
| `passed` | number | Number of assertions that passed |
| `failed` | number | Number of assertions that failed |
| `errors` | number | Number of unexpected errors |
| `details` | array | Array of `{ name, status, message? }` objects |

---

## 8. Running Tests

The project test runner lives at `test/run-all.ts`. Run all tests with:

```bash
npm test
```

Or run a specific test file directly:

```bash
npx tsx tests/basic.ts
```

---

## 9. Exercise: Write Tests for Utility Functions

Write inline tests for the following functions:

1. A `slugify` function that converts `"Hello World"` to `"hello-world"`
2. A `clamp` function that constrains a number between a min and max
3. A `parsePrice` function that extracts a number from `"$19.99"` and throws on invalid input

---

## 10. Solution

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

## 11. Gotchas

### 1. The `tests()` Decorator Returns the Original Function
The wrapped function works identically in production. Tests only run when you call `runAllTests()`.

### 2. Arguments Are Passed as an Array
`assertEqual([5, 3], 8)` means "call the function with arguments `5` and `3`, expect `8`". The first argument is always an array.

### 3. Named Functions Are Required for Readable Output
Anonymous functions show up as "anonymous" in test output. Use named function expressions.

### 4. Call `resetTests()` Between Separate Test Files
Without resetting, tests from previously imported modules accumulate in the registry.

### 5. `runAllTests()` Returns Results
Use the return value for CI integration: check `results.failed === 0` to determine the exit code.
