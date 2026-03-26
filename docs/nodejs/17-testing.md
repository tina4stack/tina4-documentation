# Chapter 17: Testing

## 1. Why Tests Matter More Than You Think

Friday afternoon. Your client reported a critical bug. You fix it -- one line. But did that fix break something else? The test suite answers in 2 seconds.

```bash
npm test
```

```
Running tests...

  ProductTest
    [PASS] test_create_product
    [PASS] test_load_product
    [PASS] test_update_product
    [PASS] test_delete_product

  AuthTest
    [PASS] test_login_with_valid_credentials
    [PASS] test_login_with_invalid_password
    [PASS] test_protected_route_without_token

  7 tests, 7 passed, 0 failed (0.34s)
```

Tina4 ships an inline testing framework. No external packages. No Jest configuration. No setup ceremony.

---

## 2. Your First Test

Tests live in the `tests/` directory. The test runner is `tests/run-all.ts`.

Create `tests/BasicTest.ts`:

```typescript
import { Test } from "tina4-nodejs";

export class BasicTest extends Test {
    async testAddition() {
        this.assertEqual(2 + 2, 4, "Basic addition should work");
    }

    async testStringConcatenation() {
        const result = "Hello" + " " + "World";
        this.assertEqual(result, "Hello World", "String concatenation should work");
    }

    async testArrayLength() {
        const items = [1, 2, 3];
        this.assertEqual(items.length, 3, "Array should have 3 items");
    }

    async testBooleanLogic() {
        this.assertTrue(true, "true should be true");
        this.assertFalse(false, "false should be false");
    }
}
```

Run it:

```bash
npm test
```

```
Running tests...

  BasicTest
    [PASS] testAddition
    [PASS] testStringConcatenation
    [PASS] testArrayLength
    [PASS] testBooleanLogic

  4 tests, 4 passed, 0 failed (0.01s)
```

---

## 3. Assertion Methods

| Method | Description |
|--------|-------------|
| `assertEqual(actual, expected, message)` | Values are equal |
| `assertNotEqual(actual, expected, message)` | Values are not equal |
| `assertTrue(value, message)` | Value is truthy |
| `assertFalse(value, message)` | Value is falsy |
| `assertNull(value, message)` | Value is null |
| `assertNotNull(value, message)` | Value is not null |
| `assertContains(haystack, needle, message)` | String or array contains value |
| `assertThrows(fn, message)` | Function throws an error |

---

## 4. Testing Routes with testGet() and testPost()

```typescript
import { Test } from "tina4-nodejs";

export class ProductApiTest extends Test {
    async testListProducts() {
        const response = await this.testGet("/api/products");

        this.assertEqual(response.status, 200, "Should return 200");
        this.assertNotNull(response.body.products, "Should have products array");
    }

    async testCreateProduct() {
        const response = await this.testPost("/api/products", {
            name: "Test Widget",
            category: "Testing",
            price: 9.99
        });

        this.assertEqual(response.status, 201, "Should return 201");
        this.assertEqual(response.body.name, "Test Widget", "Name should match");
        this.assertEqual(response.body.price, 9.99, "Price should match");
    }

    async testGetProductNotFound() {
        const response = await this.testGet("/api/products/99999");

        this.assertEqual(response.status, 404, "Should return 404");
        this.assertContains(response.body.error, "not found", "Error message should mention not found");
    }

    async testCreateProductValidation() {
        const response = await this.testPost("/api/products", {});

        this.assertEqual(response.status, 400, "Should return 400 for missing name");
    }
}
```

---

## 5. Testing with Authentication

```typescript
import { Test, Auth } from "tina4-nodejs";

export class AuthTest extends Test {
    private token: string = "";

    async setup() {
        // Register and login to get a token
        await this.testPost("/api/register", {
            name: "Test User",
            email: "test@example.com",
            password: "securePass123"
        });

        const loginResponse = await this.testPost("/api/login", {
            email: "test@example.com",
            password: "securePass123"
        });

        this.token = loginResponse.body.token;
    }

    async testProfileWithToken() {
        const response = await this.testGet("/api/profile", {
            headers: { Authorization: `Bearer ${this.token}` }
        });

        this.assertEqual(response.status, 200, "Should return 200 with valid token");
        this.assertEqual(response.body.email, "test@example.com", "Should return correct email");
    }

    async testProfileWithoutToken() {
        const response = await this.testGet("/api/profile");

        this.assertEqual(response.status, 401, "Should return 401 without token");
    }
}
```

---

## 6. Testing ORM Models

```typescript
import { Test } from "tina4-nodejs";
import { Product } from "../src/orm/Product";

export class ProductModelTest extends Test {
    async testCreateAndLoad() {
        const product = new Product();
        product.name = "Test Product";
        product.price = 29.99;
        product.category = "Testing";
        await product.save();

        this.assertNotNull(product.id, "Should have an ID after save");

        const loaded = new Product();
        await loaded.load(product.id);

        this.assertEqual(loaded.name, "Test Product", "Name should match");
        this.assertEqual(loaded.price, 29.99, "Price should match");

        await product.delete();
    }

    async testSoftDelete() {
        const product = new Product();
        product.name = "Deletable";
        product.price = 1.00;
        await product.save();
        const id = product.id;

        await product.delete();

        const loaded = new Product();
        await loaded.load(id);
        this.assertNull(loaded.id, "Soft-deleted product should not be loadable");
    }
}
```

---

## 7. Test Database Isolation

Tina4 creates a test database (`data/test.db`) when running tests. Each test class gets a clean database. No leftover data from previous runs.

```env
# In .env.test (optional)
DATABASE_URL=sqlite:///data/test.db
```

---

## 8. Setup and Teardown

```typescript
export class MyTest extends Test {
    async setup() {
        // Runs before each test
    }

    async teardown() {
        // Runs after each test
    }

    async setupOnce() {
        // Runs once before all tests in this class
    }

    async teardownOnce() {
        // Runs once after all tests in this class
    }
}
```

---

## 9. Running Specific Tests

```bash
npm test -- --filter ProductTest
npm test -- --filter testCreateProduct
```

---

## 10. Exercise: Write Tests for a Notes API

Write a test class that covers: creating a note, listing notes, getting a single note, updating a note, deleting a note, and validation errors.

---

## 11. Solution

```typescript
import { Test } from "tina4-nodejs";

export class NotesApiTest extends Test {
    private noteId: number = 0;

    async testCreateNote() {
        const response = await this.testPost("/api/notes", {
            title: "Test Note",
            content: "This is a test note",
            tag: "testing"
        });
        this.assertEqual(response.status, 201);
        this.assertEqual(response.body.title, "Test Note");
        this.noteId = response.body.id;
    }

    async testListNotes() {
        const response = await this.testGet("/api/notes");
        this.assertEqual(response.status, 200);
        this.assertTrue(response.body.count >= 1, "Should have at least one note");
    }

    async testGetNote() {
        const response = await this.testGet(`/api/notes/${this.noteId}`);
        this.assertEqual(response.status, 200);
        this.assertEqual(response.body.title, "Test Note");
    }

    async testUpdateNote() {
        const response = await this.testPut(`/api/notes/${this.noteId}`, {
            title: "Updated Note"
        });
        this.assertEqual(response.status, 200);
        this.assertEqual(response.body.title, "Updated Note");
    }

    async testDeleteNote() {
        const response = await this.testDelete(`/api/notes/${this.noteId}`);
        this.assertEqual(response.status, 204);
    }

    async testCreateNoteValidation() {
        const response = await this.testPost("/api/notes", {});
        this.assertEqual(response.status, 400);
        this.assertNotNull(response.body.errors);
    }

    async testGetNotFound() {
        const response = await this.testGet("/api/notes/99999");
        this.assertEqual(response.status, 404);
    }
}
```

---

## 12. Gotchas

### 1. Tests Must Extend Test Class -- `export class MyTest extends Test`.
### 2. Test Methods Must Start with "test" -- `testCreateProduct`, not `createProductTest`.
### 3. All Tests Are Async -- Use `async` and `await` for all test methods.
### 4. Test Order Is Not Guaranteed -- Do not depend on test execution order.
### 5. Database State Leaks Between Tests -- Use `setup()` and `teardown()` to clean up.
### 6. Missing Assertions -- A test without assertions passes silently. Always assert.
### 7. Test Files Must Export Classes -- `export class MyTest extends Test`, not a default export.
