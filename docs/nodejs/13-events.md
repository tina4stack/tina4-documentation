# Chapter 13: Events System

## 1. Decouple Without Wiring Everything Together

Your user registers. You need to send a welcome email, create a default profile, log the signup, and update analytics. You could call all four functions from the signup handler. But now the signup handler knows about email, profiles, logging, and analytics. Change any of them and you're touching the handler.

Events decouple the action from the reaction. The signup handler emits `user.registered`. Anything that cares about that event subscribes to it. The handler knows nothing about what happens next.

Tina4 ships a built-in event bus. Zero external dependencies. Synchronous listeners, priority ordering, one-shot listeners, and cleanup.

---

## 2. Listening for Events

Register a listener with `Events.on()`:

```typescript
import { Events } from "tina4-nodejs";

Events.on("user.registered", (payload) => {
    console.log(`New user: ${payload.name} (${payload.email})`);
});
```

The listener runs every time `user.registered` is emitted. The `payload` is whatever object was passed to `emit()`.

---

## 3. Emitting Events

Trigger all listeners for an event with `Events.emit()`:

```typescript
import { Router, Events } from "tina4-nodejs";

Router.post("/api/register", async (req, res) => {
    const body = req.body;

    // ... create the user in the database ...
    const userId = 42;

    Events.emit("user.registered", {
        id: userId,
        name: body.name,
        email: body.email,
        registeredAt: new Date().toISOString()
    });

    return res.status(201).json({ message: "Registration complete", user_id: userId });
});
```

All registered listeners for `user.registered` run immediately, in priority order, before `emit()` returns.

---

## 4. One-Shot Listeners with once()

A listener registered with `Events.once()` fires exactly one time and then removes itself:

```typescript
import { Events } from "tina4-nodejs";

// Fires the first time "server.ready" is emitted, then never again
Events.once("server.ready", () => {
    console.log("Server is up -- warming the cache");
    warmCache();
});
```

Useful for initialisation tasks, first-run setup, or integration tests that need to wait for a single event.

---

## 5. Priority

When multiple listeners are registered for the same event, priority controls the order they run. Higher priority runs first. Default priority is `0`.

```typescript
import { Events } from "tina4-nodejs";

// Runs third (lowest priority)
Events.on("order.placed", (payload) => {
    console.log("Analytics: recording order");
}, 0);

// Runs first (highest priority)
Events.on("order.placed", (payload) => {
    console.log("Inventory: reserving stock");
}, 20);

// Runs second
Events.on("order.placed", (payload) => {
    console.log("Email: sending confirmation");
}, 10);

Events.emit("order.placed", { orderId: 101, total: 249.99 });
// Output:
// Inventory: reserving stock
// Email: sending confirmation
// Analytics: recording order
```

Priority is specified as the third argument to `on()`.

---

## 6. Removing Listeners with off()

Remove a specific listener by passing the same function reference used in `on()`:

```typescript
import { Events } from "tina4-nodejs";

function onUserLogin(payload: { userId: number }) {
    console.log(`User ${payload.userId} logged in`);
}

// Register
Events.on("user.login", onUserLogin);

// Later, remove it
Events.off("user.login", onUserLogin);

// This emit does nothing -- the listener was removed
Events.emit("user.login", { userId: 99 });
```

Note: arrow functions assigned to variables work the same way as long as you pass the same reference.

---

## 7. Clearing All Listeners with clear()

Remove every listener for a given event (or all events):

```typescript
import { Events } from "tina4-nodejs";

// Clear listeners for a specific event
Events.clear("user.registered");

// Clear all listeners for all events
Events.clear();
```

Useful in tests to reset state between test cases, or in long-running processes to tear down a subsystem cleanly.

---

## 8. Listing Active Listeners

Inspect registered listeners for debugging:

```typescript
import { Events } from "tina4-nodejs";

const listeners = Events.listeners("order.placed");
console.log(`${listeners.length} listeners for order.placed`);
```

---

## 9. Organising Events in a Real Application

Keep all event subscriptions in one place so they are easy to audit. Create `src/events/index.ts`:

```typescript
import { Events } from "tina4-nodejs";
import { sendWelcomeEmail } from "../services/email";
import { createDefaultProfile } from "../services/profile";
import { trackSignup } from "../services/analytics";
import { logUserEvent } from "../services/logging";

// user.registered
Events.on("user.registered", async (payload) => {
    await sendWelcomeEmail(payload.email, payload.name);
}, 10);

Events.on("user.registered", async (payload) => {
    await createDefaultProfile(payload.id);
}, 5);

Events.on("user.registered", (payload) => {
    trackSignup(payload.id, payload.registeredAt);
}, 1);

Events.on("user.registered", (payload) => {
    logUserEvent("signup", payload.id);
}, 0);
```

Then import this file in `src/index.ts` so listeners are registered before any requests arrive:

```typescript
import "./events/index";
import { Tina4 } from "tina4-nodejs";

const app = new Tina4();
app.start();
```

---

## 10. Exercise: Order Processing Pipeline

Build an order processing pipeline using events.

### Requirements

1. Create a `POST /api/orders` endpoint that emits `order.placed` with order data
2. Register three listeners for `order.placed`:
   - Priority 20: validate and reserve inventory
   - Priority 10: send confirmation email (simulated)
   - Priority 0: record in analytics (simulated)
3. Create a `GET /api/orders/events` endpoint that returns the current listener count for `order.placed`

### Test with:

```bash
curl -X POST http://localhost:7148/api/orders \
  -H "Content-Type: application/json" \
  -d '{"items": [{"sku": "KB-001", "qty": 2}], "email": "alice@example.com"}'

curl http://localhost:7148/api/orders/events
```

---

## 11. Solution

Create `src/events/orders.ts`:

```typescript
import { Events } from "tina4-nodejs";

Events.on("order.placed", (payload) => {
    console.log(`[Inventory] Reserving stock for order ${payload.orderId}`);
    for (const item of payload.items) {
        console.log(`  - SKU ${item.sku}: qty ${item.qty}`);
    }
}, 20);

Events.on("order.placed", (payload) => {
    console.log(`[Email] Sending confirmation to ${payload.email} for order ${payload.orderId}`);
}, 10);

Events.on("order.placed", (payload) => {
    console.log(`[Analytics] Recording order ${payload.orderId} — total $${payload.total}`);
}, 0);
```

Create `src/routes/orders.ts`:

```typescript
import { Router, Events } from "tina4-nodejs";

let orderCounter = 1000;

Router.post("/api/orders", async (req, res) => {
    const body = req.body;

    if (!body.items || body.items.length === 0) {
        return res.status(400).json({ error: "Order must contain at least one item" });
    }

    const orderId = ++orderCounter;
    const total = body.items.reduce((sum: number, item: { qty: number; price?: number }) => {
        return sum + (item.qty * (item.price ?? 9.99));
    }, 0);

    Events.emit("order.placed", {
        orderId,
        items: body.items,
        email: body.email,
        total: parseFloat(total.toFixed(2)),
        placedAt: new Date().toISOString()
    });

    return res.status(201).json({
        message: "Order placed",
        order_id: orderId,
        total
    });
});

Router.get("/api/orders/events", async (req, res) => {
    const count = Events.listeners("order.placed").length;
    return res.json({ event: "order.placed", listener_count: count });
});
```

In `src/index.ts`, import the events file before starting the server:

```typescript
import "./events/orders";
import { Tina4 } from "tina4-nodejs";

const app = new Tina4();
app.start();
```

---

## 12. Gotchas

### 1. Async listeners are not awaited

`Events.emit()` is synchronous. If a listener is `async`, the promise is not awaited. Long async work belongs in a queue, not an event listener.

**Fix:** For truly async fire-and-forget tasks, use `Queue`. For synchronous side effects, use events. If you must use async listeners, handle errors inside them -- unhandled rejections in event listeners are silent.

### 2. Same function reference required for off()

`Events.off("event", fn)` only works if `fn` is the exact same reference registered with `on()`.

**Fix:** Store named functions in variables. Arrow functions defined inline cannot be removed because each definition creates a new reference.

### 3. Listeners persist across requests

Events registered at module load time persist for the lifetime of the process. Registering listeners inside a route handler creates duplicates on every request.

**Fix:** Register listeners once, at startup, in a dedicated events file.

### 4. Forgetting to import the events file

Listeners registered in a file that is never imported do not exist.

**Fix:** Explicitly import your events file in `src/index.ts`. A missing import is a silent failure -- no error, no listeners, no side effects.
