# Chapter 25: DI Container

## 1. Stop Constructing Dependencies Inside Your Code

```python
@post("/api/orders")
async def create_order(request, response):
    db = Database.get_connection()      # tight coupling
    mailer = Messenger()                # constructed inline
    payments = PaymentGateway(          # hardcoded config
        api_key=os.environ["PAYMENT_KEY"]
    )
    ...
```

Every route constructs its own dependencies. Testing requires monkey-patching or mocking at the module level. Swapping the payment gateway means touching every route that uses it.

A DI container inverts this. You register services once. You retrieve them by name. The container handles construction, caching, and lifecycle. Tests register mock versions. Production registers real ones.

---

## 2. The Container Class

```python
from tina4_python.container import Container

container = Container()
```

The `Container` is a lightweight registry. It does not scan files, read XML, or require annotations on your classes. You register explicitly. You retrieve explicitly.

---

## 3. register() — Transient Services

A transient service creates a new instance every time `get()` is called:

```python
from tina4_python.container import Container

container = Container()

# Register a factory function
container.register("logger", lambda: Logger(level="INFO"))

# Each call creates a fresh instance
logger1 = container.get("logger")
logger2 = container.get("logger")

assert logger1 is not logger2  # Different objects
```

Use transient registration for services that must not share state: request-scoped objects, things with per-use configuration, test fakes.

---

## 4. singleton() — Cached Services

A singleton creates the instance once and returns the same object on every subsequent call:

```python
import os
from tina4_python.container import Container
from tina4_python.api import Api

container = Container()

# Register a singleton factory
container.singleton("payment_gateway", lambda: Api(
    bearer_token=os.environ["PAYMENT_API_KEY"],
    timeout=15
))

# Both calls return the exact same object
gw1 = container.get("payment_gateway")
gw2 = container.get("payment_gateway")

assert gw1 is gw2  # Same object
```

Use singleton registration for: database connections, HTTP clients, configuration objects, external service adapters.

---

## 5. get() and has()

```python
# Retrieve a service
service = container.get("payment_gateway")

# Check before retrieving
if container.has("email_service"):
    mailer = container.get("email_service")
    mailer.send(...)
```

`get()` raises `KeyError` if the service is not registered. `has()` lets you check first, or use it to provide a default:

```python
mailer = container.get("email_service") if container.has("email_service") else None
```

---

## 6. reset()

Clear the singleton cache without removing registrations. Useful in tests to force fresh construction:

```python
container.singleton("db", lambda: Database.connect())

# In tests: reset between test cases so each gets a clean DB
container.reset()

db = container.get("db")  # New connection created
```

`reset()` clears all cached singletons. Transient registrations are unaffected (they never cache). Call `reset()` in test teardown to prevent state from leaking between tests.

---

## 7. Building a Service Container for Your App

Define your container in one place:

```python
# src/services.py
import os
from tina4_python.container import Container
from tina4_python.api import Api

container = Container()

# Database connection (singleton -- one connection reused)
container.singleton("db", lambda: Database.get_connection())

# Payment gateway (singleton -- one client, shared config)
container.singleton("payments", lambda: Api(
    bearer_token=os.environ["PAYMENT_API_KEY"],
    timeout=15
))

# Email service (singleton)
container.singleton("mailer", lambda: Api(
    bearer_token=os.environ["SENDGRID_API_KEY"]
))

# Request logger (transient -- new instance per use)
container.register("request_logger", lambda: RequestLogger(
    level=os.environ.get("LOG_LEVEL", "INFO")
))
```

Import `container` wherever you need it:

```python
# src/routes/orders.py
from src.services import container

@post("/api/orders")
async def create_order(request, response):
    payments = container.get("payments")
    mailer = container.get("mailer")
    ...
```

---

## 8. Testing with the Container

Swap implementations for tests without changing any route code:

```python
# tests/test_orders.py
import pytest
from src.services import container

class MockPaymentGateway:
    def post(self, url, body):
        return {
            "http_code": 200,
            "body": {"charge_id": "ch_test_001", "status": "succeeded"},
            "headers": {},
            "error": None
        }

class MockMailer:
    def __init__(self):
        self.sent = []

    def post(self, url, body):
        self.sent.append(body)
        return {"http_code": 200, "body": {"id": "msg_001"}, "headers": {}, "error": None}


@pytest.fixture(autouse=True)
def reset_container():
    # Clear singleton cache before each test
    container.reset()
    yield
    container.reset()


def test_create_order_success(client):
    mock_mailer = MockMailer()

    # Override with test doubles
    container.singleton("payments", lambda: MockPaymentGateway())
    container.singleton("mailer", lambda: mock_mailer)

    resp = client.post("/api/orders", json={
        "customer_id": 1,
        "items": [{"product_id": "KB-001", "quantity": 1, "price": 79.99}],
        "email": "alice@example.com"
    })

    assert resp.status_code == 201
    assert resp.json()["order_id"] is not None
    assert len(mock_mailer.sent) == 1  # Confirmation email was sent
```

The route code never changes. The container is the only seam.

---

## 9. Full Example: Order Route with DI

```python
# src/routes/orders_di.py
from tina4_python.core.router import post
from tina4_python.debug import Log
from src.services import container


@post("/api/di/orders")
async def create_order_di(request, response):
    body = request.body

    if not body.get("customer_id") or not body.get("items"):
        return response({"error": "customer_id and items are required"}, 400)

    payments = container.get("payments")
    mailer = container.get("mailer")

    total = round(sum(item.get("price", 0) * item.get("quantity", 1) for item in body["items"]), 2)

    # Charge payment
    charge_result = payments.post("https://api.payment-provider.com/v1/charges", {
        "amount": int(total * 100),
        "currency": "usd"
    })

    if charge_result["error"] or charge_result["http_code"] not in (200, 201):
        Log.error("Payment failed", customer_id=body["customer_id"], total=total)
        return response({"error": "Payment failed"}, 402)

    charge_id = charge_result["body"]["charge_id"]
    order_id = f"ORD-{body['customer_id']}-{charge_id}"

    # Send confirmation
    mailer.post("https://api.sendgrid.com/v3/mail/send", {
        "to": body.get("email"),
        "subject": f"Order Confirmation {order_id}",
        "body": f"Your order of ${total} has been confirmed."
    })

    Log.info("Order created", order_id=order_id, total=total)

    return response({
        "order_id": order_id,
        "total": total,
        "charge_id": charge_id
    }, 201)
```

---

## 10. Exercise: Configurable Notification Service

Build a notification service that can switch between email and SMS providers via the container.

### Requirements

1. Define two notifier classes: `EmailNotifier` and `SmsNotifier`, each with a `send(to, message)` method
2. Register the active notifier as `"notifier"` in the container (controlled by a `NOTIFIER` env var)
3. Create `POST /api/notify` that retrieves `"notifier"` from the container and sends a message
4. Write a test that registers a mock notifier and verifies messages are sent

### Test with:

```bash
# Set NOTIFIER=email or NOTIFIER=sms in .env
curl -X POST http://localhost:7145/api/notify \
  -H "Content-Type: application/json" \
  -d '{"to": "alice@example.com", "message": "Your order has shipped!"}'
```

---

## 11. Solution

```python
# src/notifiers.py
import os

class EmailNotifier:
    def send(self, to, message):
        print(f"[EMAIL] To: {to} | Message: {message}")
        return {"channel": "email", "to": to}

class SmsNotifier:
    def send(self, to, message):
        print(f"[SMS] To: {to} | Message: {message}")
        return {"channel": "sms", "to": to}

def make_notifier():
    channel = os.environ.get("NOTIFIER", "email")
    if channel == "sms":
        return SmsNotifier()
    return EmailNotifier()
```

```python
# src/services.py (additions)
from src.notifiers import make_notifier
container.singleton("notifier", make_notifier)
```

```python
# src/routes/notify.py
from tina4_python.core.router import post
from src.services import container

@post("/api/notify")
async def notify(request, response):
    body = request.body

    if not body.get("to") or not body.get("message"):
        return response({"error": "to and message are required"}, 400)

    notifier = container.get("notifier")
    result = notifier.send(body["to"], body["message"])

    return response({"sent": True, **result})
```

```python
# tests/test_notify.py
from src.services import container

class MockNotifier:
    def __init__(self):
        self.messages = []
    def send(self, to, message):
        self.messages.append({"to": to, "message": message})
        return {"channel": "mock", "to": to}

def test_notify_sends_message(client):
    mock = MockNotifier()
    container.reset()
    container.singleton("notifier", lambda: mock)

    resp = client.post("/api/notify", json={"to": "bob@example.com", "message": "Hello!"})

    assert resp.status_code == 200
    assert mock.messages[0]["to"] == "bob@example.com"
    container.reset()
```

---

## 12. Gotchas

### 1. Mutable singleton shared across requests

**Problem:** A singleton holds per-request state and leaks it between concurrent requests.

**Fix:** Use `register()` (transient) for anything that holds request-specific state. Singletons should be stateless or thread-safe.

### 2. reset() removes singleton cache but not registrations

**Problem:** After `container.reset()`, calling `container.has("payments")` still returns `True` but the next `get()` creates a new instance.

**Fix:** This is correct behaviour. `reset()` only clears the cache. The factory function is still registered and will run again on the next `get()`. Use `reset()` deliberately in test teardown.

### 3. Circular dependencies

**Problem:** Service A's factory calls `container.get("B")` and B's factory calls `container.get("A")`. Both hang or raise a recursion error.

**Fix:** Restructure so that dependencies are one-directional. Extract shared logic into a third service that neither A nor B depends back upon.

### 4. Importing container before .env is loaded

**Problem:** `container.singleton("payments", lambda: Api(bearer_token=os.environ["PAYMENT_KEY"]))` raises `KeyError` because `.env` has not been loaded yet.

**Fix:** Tina4 loads `.env` before importing route files. If you initialise the container in a module that is imported before startup, use a lambda (lazy factory) so `os.environ` is not accessed until `get()` is called.
