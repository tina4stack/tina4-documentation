# Chapter 13: Events

## 1. Decouple Everything with Events

Your order route creates an order, sends a confirmation email, deducts inventory, and notifies the warehouse. Six hundred lines of intertwined logic. Add a new requirement — loyalty points — and you are touching the order route again.

Events flip this around. The order route fires `order.placed` and walks away. An email handler responds. An inventory handler responds. A warehouse handler responds. A loyalty handler responds. None of them know about each other, and the order route knows about none of them.

Tina4's event system is synchronous by default and supports async via `emit_async`. No broker required.

---

## 2. Registering Handlers with @on

```python
from tina4_python.core.events import on, emit

@on("user.created")
def welcome_email(payload):
    print(f"Sending welcome email to {payload['email']}")

@on("user.created")
def create_profile(payload):
    print(f"Creating profile for {payload['user_id']}")
```

Register as many handlers as you need for the same event. They all run when the event fires.

---

## 3. Firing Events with emit

```python
from tina4_python.core.router import post
from tina4_python.core.events import emit

@post("/api/users")
async def register_user(request, response):
    body = request.body

    user = {
        "user_id": 42,
        "email": body["email"],
        "name": body["name"]
    }

    # Fire the event -- all registered handlers run now
    emit("user.created", user)

    return response({"message": "User created", "user_id": user["user_id"]}, 201)
```

```bash
curl -X POST http://localhost:7145/api/users \
  -H "Content-Type: application/json" \
  -d '{"email": "alice@example.com", "name": "Alice"}'
```

Output in the server log:

```
Sending welcome email to alice@example.com
Creating profile for 42
```

---

## 4. One-Time Handlers with @once

A handler registered with `once` fires exactly once and then automatically unregisters itself:

```python
from tina4_python.core.events import once, emit

@once("app.started")
def run_migrations(payload):
    print("Running database migrations...")

emit("app.started", {})   # Runs run_migrations
emit("app.started", {})   # Does nothing -- handler was removed
```

Useful for initialisation tasks, first-visit tracking, or features that should only trigger once per session.

---

## 5. Removing Handlers with off

Remove a handler by function reference:

```python
from tina4_python.core.events import on, off, emit

def log_purchase(payload):
    print(f"Purchase logged: {payload['order_id']}")

on("order.placed", log_purchase)

emit("order.placed", {"order_id": 101})  # Handler runs

off("order.placed", log_purchase)

emit("order.placed", {"order_id": 102})  # Handler does not run
```

---

## 6. Priority Ordering

When multiple handlers listen to the same event, you control which one runs first using the `priority` parameter. Lower numbers run first. Default priority is `10`.

```python
from tina4_python.core.events import on, emit

@on("order.placed", priority=1)
def validate_stock(payload):
    print(f"[priority 1] Validating stock for order {payload['order_id']}")

@on("order.placed", priority=5)
def charge_payment(payload):
    print(f"[priority 5] Charging payment for order {payload['order_id']}")

@on("order.placed", priority=10)
def send_confirmation(payload):
    print(f"[priority 10] Sending confirmation for order {payload['order_id']}")

emit("order.placed", {"order_id": 200})
```

Output:

```
[priority 1] Validating stock for order 200
[priority 5] Charging payment for order 200
[priority 10] Sending confirmation for order 200
```

Stock is validated before payment is charged, payment is charged before the confirmation email goes out.

---

## 7. Async Event Support with emit_async

For handlers that do I/O — sending HTTP requests, writing to a database, publishing to a message broker — use `emit_async` with async handlers:

```python
import asyncio
from tina4_python.core.events import on, emit_async

@on("order.placed")
async def notify_warehouse(payload):
    # Simulate async HTTP call to warehouse API
    await asyncio.sleep(0.1)
    print(f"Warehouse notified for order {payload['order_id']}")

@on("order.placed")
async def update_analytics(payload):
    await asyncio.sleep(0.05)
    print(f"Analytics updated for order {payload['order_id']}")
```

Call `emit_async` from an async route handler:

```python
from tina4_python.core.router import post
from tina4_python.core.events import emit_async

@post("/api/orders")
async def create_order(request, response):
    body = request.body

    order = {
        "order_id": 300,
        "customer_id": body["customer_id"],
        "total": body["total"],
        "items": body["items"]
    }

    # All async handlers run concurrently
    await emit_async("order.placed", order)

    return response({"message": "Order placed", "order_id": order["order_id"]}, 201)
```

`emit_async` gathers all async handlers and runs them concurrently using `asyncio.gather`. Synchronous handlers registered on the same event run first (in priority order), then all async handlers run in parallel.

---

## 8. Real-World Pattern: Order Pipeline

A realistic e-commerce order with five independent concerns:

```python
from tina4_python.core.events import on, emit_async

@on("order.placed", priority=1)
def reserve_stock(payload):
    print(f"Reserving {len(payload['items'])} items")

@on("order.placed", priority=2)
def charge_customer(payload):
    print(f"Charging ${payload['total']} to customer {payload['customer_id']}")

@on("order.placed", priority=5)
async def send_confirmation_email(payload):
    import asyncio
    await asyncio.sleep(0)  # Yield to event loop
    print(f"Confirmation sent to {payload['email']}")

@on("order.placed", priority=5)
async def sync_warehouse(payload):
    import asyncio
    await asyncio.sleep(0)
    print(f"Warehouse sync queued for order {payload['order_id']}")

@on("order.placed", priority=10)
def award_loyalty_points(payload):
    points = int(payload['total'] * 10)
    print(f"Awarding {points} loyalty points to customer {payload['customer_id']}")
```

The order route:

```python
from tina4_python.core.router import post
from tina4_python.core.events import emit_async

@post("/api/orders")
async def place_order(request, response):
    body = request.body

    order = {
        "order_id": 301,
        "customer_id": body["customer_id"],
        "email": body["email"],
        "total": body["total"],
        "items": body["items"]
    }

    await emit_async("order.placed", order)

    return response({"order_id": order["order_id"], "status": "placed"}, 201)
```

Adding loyalty points or a fraud check means adding a new `@on` handler. The route file never changes.

---

## 9. Exercise: User Lifecycle Events

Build a user registration flow using events.

### Requirements

1. Create a `POST /api/register` endpoint that:
   - Accepts `email`, `name`, `password`
   - Emits `user.created` with `{user_id, email, name}`
   - Returns `{"user_id": ..., "status": "created"}`

2. Register three handlers for `user.created`:
   - Priority 1: log the event with timestamp
   - Priority 2: simulate sending a welcome email
   - Priority 5: simulate creating a default profile

3. Create a `POST /api/users/{user_id}/deactivate` endpoint that emits `user.deactivated`

4. Register a one-time handler for `app.ready` that prints a startup message

### Test with:

```bash
# Register a user
curl -X POST http://localhost:7145/api/register \
  -H "Content-Type: application/json" \
  -d '{"email": "bob@example.com", "name": "Bob", "password": "secret"}'

# Deactivate a user
curl -X POST http://localhost:7145/api/users/42/deactivate
```

---

## 10. Solution

Create `src/routes/user_events.py`:

```python
from datetime import datetime, timezone
from tina4_python.core.router import post
from tina4_python.core.events import on, once, emit, emit_async


@once("app.ready")
def on_app_ready(payload):
    print(f"[{datetime.now(timezone.utc).isoformat()}] Application ready.")


@on("user.created", priority=1)
def log_user_created(payload):
    print(f"[{datetime.now(timezone.utc).isoformat()}] user.created: {payload['email']}")


@on("user.created", priority=2)
def send_welcome_email(payload):
    print(f"Welcome email dispatched to {payload['email']}")


@on("user.created", priority=5)
def create_default_profile(payload):
    print(f"Default profile created for user {payload['user_id']}")


@on("user.deactivated")
def log_deactivation(payload):
    print(f"User {payload['user_id']} deactivated at {datetime.now(timezone.utc).isoformat()}")


@post("/api/register")
async def register_user(request, response):
    body = request.body

    if not body.get("email") or not body.get("name"):
        return response({"error": "email and name are required"}, 400)

    user = {
        "user_id": 42,
        "email": body["email"],
        "name": body["name"]
    }

    emit("user.created", user)

    return response({"user_id": user["user_id"], "status": "created"}, 201)


@post("/api/users/{user_id}/deactivate")
async def deactivate_user(request, response):
    user_id = request.params["user_id"]

    emit("user.deactivated", {"user_id": user_id})

    return response({"user_id": user_id, "status": "deactivated"})
```

Fire the app ready event once on startup in `src/app.py`:

```python
from tina4_python.core.events import emit
emit("app.ready", {})
```

---

## 11. Gotchas

### 1. Emitting from a sync context with async handlers

**Problem:** `emit()` is called from a synchronous function but some handlers are `async def`. They will not run.

**Fix:** Use `emit_async()` from an async context for events that have async handlers. Synchronous handlers always run regardless of which emit variant you use.

### 2. Handler order is non-deterministic at equal priority

**Problem:** Two handlers at `priority=5` run in a different order than expected.

**Fix:** Give them distinct priority values. Priority uniqueness within an event gives you guaranteed ordering.

### 3. Forgetting once fires exactly once

**Problem:** An initialisation handler registered with `@once` does not run on the second app start during hot reload.

**Fix:** `@once` handlers remove themselves after firing. For handlers that must run every startup, use `@on` instead.

### 4. Mutating the payload in a handler

**Problem:** A high-priority handler modifies the payload dict and downstream handlers see the mutated version.

**Fix:** This is intentional and useful (e.g., adding `payment_id` to the payload before the confirmation handler runs). If you want to prevent mutation, pass `payload.copy()` or use a frozen data structure.
