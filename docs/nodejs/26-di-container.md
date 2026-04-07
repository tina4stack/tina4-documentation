# Chapter 25: DI Container

## 1. Stop Passing Dependencies Through Every Function Call

Your database connection, email client, cache client, payment gateway, and logger are needed in dozens of places. You could import them all directly. You could pass them as function parameters. Both approaches make testing hard and create tight coupling.

Dependency injection (DI) separates what you need from how you get it. A container holds instances. You register once. You resolve anywhere. Tests swap implementations without touching production code.

Tina4's `Container` class is a lightweight DI container. Register classes or factories. Resolve by name. Singleton or transient. No reflection magic, no decorators required unless you want them.

---

## 2. The Container Class

```typescript
import { Container } from "tina4-nodejs";
```

`Container` is a class you instantiate. You can have multiple containers for different subsystems, or use a single application-wide container.

---

## 3. Registering a Service

`register()` stores a factory function or class constructor under a name:

```typescript
import { Container } from "tina4-nodejs";

const container = new Container();

// Register a factory function
container.register("logger", () => ({
    info: (msg: string) => console.log(`[INFO] ${msg}`),
    error: (msg: string) => console.error(`[ERROR] ${msg}`)
}));

// Register a class constructor
class EmailService {
    send(to: string, subject: string, body: string) {
        console.log(`Sending "${subject}" to ${to}`);
    }
}

container.register("email", () => new EmailService());
```

Every call to `container.get("email")` invokes the factory and returns a new instance by default.

---

## 4. Singleton Registration

Use `singleton()` to register a service that is only instantiated once. Every call to `get()` returns the same instance:

```typescript
import { Container } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

const container = new Container();

// Database connections are expensive -- only create one
container.singleton("db", () => {
    return Database.getConnection();
});

// Both calls return the exact same connection object
const db1 = container.get("db");
const db2 = container.get("db");
console.log(db1 === db2);  // true
```

Use `singleton` for: database connections, cache clients, API clients, configuration objects. Use `register` (transient) for: request-scoped services, services with per-call state.

---

## 5. Resolving Services with get()

```typescript
const logger = container.get<Logger>("logger");
logger.info("Application started");

const email = container.get<EmailService>("email");
email.send("alice@example.com", "Welcome!", "Thanks for signing up.");
```

Provide a type parameter for TypeScript type safety. The container returns `unknown` without one; with a type parameter it returns the typed instance.

---

## 6. Checking Registration with has()

```typescript
if (container.has("payment")) {
    const payment = container.get("payment");
    // ...
} else {
    console.warn("Payment service not registered");
}
```

`has()` returns `true` if a name is registered, regardless of whether the service has been instantiated yet.

---

## 7. Resetting the Container

Remove all registrations, useful in tests:

```typescript
// Remove a specific registration
container.unregister("email");

// Clear everything
container.reset();
```

After `reset()`, any call to `get()` throws until services are re-registered.

---

## 8. Services That Depend on Other Services

Factories receive the container as an argument, enabling nested resolution:

```typescript
import { Container } from "tina4-nodejs";

const container = new Container();

container.singleton("config", () => ({
    smtpHost: process.env.TINA4_MAIL_SMTP_HOST ?? "localhost",
    smtpPort: parseInt(process.env.TINA4_MAIL_SMTP_PORT ?? "587")
}));

container.singleton("mailer", (c) => {
    const config = c.get<{ smtpHost: string; smtpPort: number }>("config");
    return new SMTPMailer(config.smtpHost, config.smtpPort);
});

container.singleton("notifier", (c) => {
    const mailer = c.get<SMTPMailer>("mailer");
    return new NotificationService(mailer);
});

// All dependencies resolved automatically
const notifier = container.get<NotificationService>("notifier");
```

---

## 9. Application-Wide Container Pattern

Expose a single container instance from a module so it can be imported anywhere:

`src/container.ts`:

```typescript
import { Container } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";
import { Messenger } from "tina4-nodejs";
import { Log } from "tina4-nodejs";

export const app = new Container();

app.singleton("db", () => Database.getConnection());

app.singleton("mailer", () => new Messenger());

app.singleton("log", () => Log);

app.register("orderService", (c) => {
    return new OrderService(
        c.get("db"),
        c.get("mailer"),
        c.get("log")
    );
});
```

`src/routes/orders.ts`:

```typescript
import { Router } from "tina4-nodejs";
import { app } from "../container";

Router.post("/api/orders", async (req, res) => {
    const orderService = app.get<OrderService>("orderService");
    const result = await orderService.place(req.body);
    return res.status(201).json(result);
});
```

---

## 10. Testing with the DI Container

Swap real services for test doubles without touching production code:

```typescript
import { Container } from "tina4-nodejs";

// Production container
import { app } from "../src/container";

// In tests: override specific services
beforeEach(() => {
    app.unregister("mailer");
    app.singleton("mailer", () => ({
        send: async () => ({ success: true, messageId: "test-123" })
    }));
});

afterEach(() => {
    // Restore after each test
    app.unregister("mailer");
    app.singleton("mailer", () => new Messenger());
});
```

The test installs a no-op mailer. Route handlers use `app.get("mailer")` — they never know the difference.

---

## 11. Exercise: Build a Service Container for a Store API

Wire together a product store API using the DI container.

### Requirements

1. Register three singletons: `productRepo` (in-memory data), `priceService` (computes discounts), and `logger` (structured logging)
2. Register a transient `productService` that depends on all three
3. Create a `GET /api/store/{id}` route that uses `productService` to fetch a product with its discounted price

### Test with:

```bash
curl http://localhost:7145/api/store/1
curl http://localhost:7145/api/store/99  # should return 404
```

---

## 12. Solution

`src/store/container.ts`:

```typescript
import { Container, Log } from "tina4-nodejs";

export const store = new Container();

// Repository: source of truth
store.singleton("productRepo", () => ({
    findById: (id: number) => {
        const products = [
            { id: 1, name: "Wireless Keyboard", basePrice: 79.99, category: "Electronics" },
            { id: 2, name: "Yoga Mat", basePrice: 29.99, category: "Fitness" },
            { id: 3, name: "Standing Desk", basePrice: 549.99, category: "Electronics" }
        ];
        return products.find(p => p.id === id) ?? null;
    },
    findAll: () => []
}));

// Price service: applies category discounts
store.singleton("priceService", () => ({
    calculate: (basePrice: number, category: string) => {
        const discounts: Record<string, number> = { Electronics: 0.05, Fitness: 0.10 };
        const discount = discounts[category] ?? 0;
        return {
            original: basePrice,
            discount: parseFloat((basePrice * discount).toFixed(2)),
            final: parseFloat((basePrice * (1 - discount)).toFixed(2))
        };
    }
}));

// Logger singleton
store.singleton("logger", () => Log);

// Product service: transient, depends on repo and price service
store.register("productService", (c) => {
    const repo = c.get<ReturnType<typeof createProductRepo>>("productRepo");
    const pricing = c.get<ReturnType<typeof createPriceService>>("priceService");
    const log = c.get<typeof Log>("logger");

    return {
        getById: (id: number) => {
            log.debug("ProductService.getById", { id });
            const product = repo.findById(id);
            if (!product) return null;
            const price = pricing.calculate(product.basePrice, product.category);
            return { ...product, price };
        }
    };
});

// Type helpers (not real -- illustrative)
function createProductRepo() { return {} as any; }
function createPriceService() { return {} as any; }
```

`src/routes/store.ts`:

```typescript
import { Router } from "tina4-nodejs";
import { store } from "../store/container";

Router.get("/api/store/{id:int}", async (req, res) => {
    const id = req.params.id;
    const productService = store.get<{ getById: (id: number) => unknown }>("productService");
    const product = productService.getById(id);

    if (!product) {
        return res.status(404).json({ error: `Product ${id} not found` });
    }

    return res.json(product);
});
```

---

## 13. Gotchas

### 1. Registering after first get()

If you call `get("db")` before `register("db", ...)`, the container throws. There is no lazy fallback.

**Fix:** Register all services at application startup before any code calls `get()`. Keep all registrations in one file (`src/container.ts`) that is imported first.

### 2. Circular dependencies

`serviceA` depends on `serviceB`, which depends on `serviceA`. The container will recurse infinitely and crash.

**Fix:** Circular dependencies indicate a design problem. Extract shared logic into a third service that neither depends on the other.

### 3. Singletons holding stale state

A singleton database connection created at startup may become invalid if the database server restarts. Every `get()` returns the same dead connection.

**Fix:** Implement reconnect logic inside the singleton service, not outside it. The container manages the lifecycle; the service manages its own health.

### 4. Over-registering transient services

Registering everything as transient creates a new instance on every `get()` call, including heavyweight services with connection pools.

**Fix:** Use `singleton()` for anything that is expensive to create or that holds persistent state. Use `register()` only for services that must be fresh per request.
