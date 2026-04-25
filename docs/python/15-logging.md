# Chapter 15: Structured Logging

## 1. Stop Using print()

`print("user logged in")` gets the job done in development. In production, it produces an undated, unlabelled stream of text with no severity, no context, and no way to filter. A crash at 3am gives you nothing useful.

Structured logging adds timestamps, levels, and machine-readable output to every message. Set the level in `.env`. Rotate logs by size. Write to a file. Filter by severity. Tina4's `Log` class does all of this without configuration beyond a single environment variable.

---

## 2. Basic Usage

```python
from tina4_python.debug import Log

Log.info("Application started")
Log.debug("Request received", path="/api/users", method="GET")
Log.warning("Rate limit approaching", remaining=10)
Log.error("Database connection failed", host="db.internal", port=5432)
```

Output:

```
2026-04-02 09:14:01 [INFO]    Application started
2026-04-02 09:14:01 [DEBUG]   Request received path=/api/users method=GET
2026-04-02 09:14:01 [WARNING] Rate limit approaching remaining=10
2026-04-02 09:14:01 [ERROR]   Database connection failed host=db.internal port=5432
```

Every message includes a UTC timestamp and level. Keyword arguments become structured key-value pairs appended to the message.

---

## 3. Log Levels

There are five levels, in ascending severity:

| Level | Method | When to Use |
|-------|--------|-------------|
| `ALL` | — | All levels (used only as a filter setting) |
| `DEBUG` | `Log.debug()` | Verbose diagnostic data; development only |
| `INFO` | `Log.info()` | Normal operational events |
| `WARNING` | `Log.warning()` | Unexpected conditions that are not errors |
| `ERROR` | `Log.error()` | Failures that need investigation |

Setting `TINA4_LOG_LEVEL=WARNING` suppresses `DEBUG` and `INFO` messages. Only warnings and errors reach the log file.

---

## 4. The TINA4_LOG_LEVEL Environment Variable

```bash
# Development: see everything
TINA4_LOG_LEVEL=ALL

# Staging: see info and above
TINA4_LOG_LEVEL=INFO

# Production: warnings and errors only
TINA4_LOG_LEVEL=WARNING
```

The level is read at startup. Changing it requires a server restart (or, if you implement a reload endpoint, a signal to the process).

---

## 5. Logging in Route Handlers

```python
from tina4_python.core.router import get, post
from tina4_python.debug import Log

@post("/api/orders")
async def create_order(request, response):
    body = request.body

    Log.info("Order creation started", customer_id=body.get("customer_id"))

    if not body.get("items"):
        Log.warning("Order rejected: no items", customer_id=body.get("customer_id"))
        return response({"error": "At least one item is required"}, 400)

    try:
        # Simulate order processing
        order_id = 1001
        total = sum(item.get("price", 0) for item in body["items"])

        Log.info("Order created", order_id=order_id, total=total, item_count=len(body["items"]))

        return response({"order_id": order_id, "total": total}, 201)

    except Exception as exc:
        Log.error("Order creation failed", error=str(exc), customer_id=body.get("customer_id"))
        return response({"error": "Internal server error"}, 500)
```

Log structured data alongside the message. When something goes wrong you can grep or filter by `order_id`, `customer_id`, or `error` without parsing free-form text.

---

## 6. File Output and Log Rotation

Write logs to a file:

```bash
TINA4_LOG_FILE=logs/app.log
```

Tina4 creates the file (and the `logs/` directory) if it does not exist. Logs are written to both the file and stdout.

Enable rotation by size:

```bash
TINA4_LOG_FILE=logs/app.log
TINA4_LOG_MAX_BYTES=10485760
TINA4_LOG_BACKUP_COUNT=5
```

`TINA4_LOG_MAX_BYTES=10485760` rotates the log file when it reaches 10 MB. `TINA4_LOG_BACKUP_COUNT=5` keeps the five most recent rotated files before deleting the oldest. These settings cap total log storage at roughly 50 MB.

Rotated files are named `app.log.1`, `app.log.2`, and so on.

---

## 7. Logging Exceptions

Log a full exception with stack trace using `Log.error` and Python's `traceback` module:

```python
import traceback
from tina4_python.debug import Log

try:
    result = 1 / 0
except Exception as exc:
    Log.error(
        "Unhandled exception",
        error=str(exc),
        traceback=traceback.format_exc()
    )
```

Output:

```
2026-04-02 09:14:01 [ERROR] Unhandled exception error=division by zero traceback=Traceback (most recent call last):
  File "src/routes/orders.py", line 34, in create_order
    result = 1 / 0
ZeroDivisionError: division by zero
```

The full stack trace is attached as a structured field. Log aggregators can extract, index, and alert on it.

---

## 8. Request Logging Middleware

Log every incoming request automatically:

```python
from tina4_python.debug import Log

async def request_logger(request, response, next_handler):
    import time
    start = time.monotonic()
    result = await next_handler(request, response)
    elapsed = round((time.monotonic() - start) * 1000, 2)

    Log.info(
        "Request completed",
        method=request.method,
        path=request.url,
        status=getattr(result, "status_code", 200),
        duration_ms=elapsed
    )

    return result
```

Register it globally in your app:

```python
from tina4_python.core.router import use
use(request_logger)
```

Every request now produces a structured log line:

```
2026-04-02 09:14:01 [INFO] Request completed method=POST path=/api/orders status=201 duration_ms=14.3
2026-04-02 09:14:02 [INFO] Request completed method=GET path=/api/users status=200 duration_ms=2.1
```

Filter by path, method, or status code in any log aggregation tool.

---

## 9. Log Levels by Environment

A typical multi-environment setup:

```bash
# .env.development
TINA4_LOG_LEVEL=ALL
TINA4_LOG_FILE=

# .env.staging
TINA4_LOG_LEVEL=INFO
TINA4_LOG_FILE=logs/staging.log
TINA4_LOG_MAX_BYTES=10485760
TINA4_LOG_BACKUP_COUNT=3

# .env.production
TINA4_LOG_LEVEL=WARNING
TINA4_LOG_FILE=logs/app.log
TINA4_LOG_MAX_BYTES=52428800
TINA4_LOG_BACKUP_COUNT=10
```

Development logs everything to stdout. Staging logs info and above to a rotating file. Production only logs warnings and errors to a large rotating file kept for 10 rotations.

---

## 10. Exercise: Add Logging to an Order API

Add structured logging to an order management API.

### Requirements

1. Create `POST /api/shop/orders` that:
   - Logs the start of each request with `customer_id`
   - Logs validation failures at `WARNING` level
   - Logs successful orders at `INFO` level with `order_id`, `total`, `item_count`
   - Logs any exceptions at `ERROR` level with full error context

2. Create `GET /api/shop/orders/{order_id}` that:
   - Logs cache hits and misses at `DEBUG` level
   - Logs 404s at `WARNING` level

3. Set up the request logging middleware globally

### Test with:

```bash
# Valid order
curl -X POST http://localhost:7146/api/shop/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "items": [{"name": "Keyboard", "price": 79.99}]}'

# Invalid order (no items)
curl -X POST http://localhost:7146/api/shop/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_id": 1}'

# Get order
curl http://localhost:7146/api/shop/orders/1001
```

---

## 11. Solution

Create `src/routes/shop_orders.py`:

```python
import traceback
from tina4_python.core.router import get, post
from tina4_python.debug import Log
from tina4_python.cache import cache_get, cache_set

ORDER_STORE = {}
NEXT_ORDER_ID = 1001


@post("/api/shop/orders")
async def create_shop_order(request, response):
    body = request.body
    customer_id = body.get("customer_id")

    Log.info("Order creation started", customer_id=customer_id)

    if not body.get("items"):
        Log.warning("Order rejected: missing items", customer_id=customer_id)
        return response({"error": "At least one item is required"}, 400)

    if not customer_id:
        Log.warning("Order rejected: missing customer_id")
        return response({"error": "customer_id is required"}, 400)

    try:
        global NEXT_ORDER_ID
        order_id = NEXT_ORDER_ID
        NEXT_ORDER_ID += 1

        items = body["items"]
        total = round(sum(item.get("price", 0) for item in items), 2)

        order = {
            "order_id": order_id,
            "customer_id": customer_id,
            "items": items,
            "total": total,
            "status": "placed"
        }
        ORDER_STORE[order_id] = order
        cache_set(f"order:{order_id}", order, ttl=300)

        Log.info(
            "Order created",
            order_id=order_id,
            customer_id=customer_id,
            total=total,
            item_count=len(items)
        )

        return response(order, 201)

    except Exception as exc:
        Log.error(
            "Order creation failed",
            customer_id=customer_id,
            error=str(exc),
            traceback=traceback.format_exc()
        )
        return response({"error": "Internal server error"}, 500)


@get("/api/shop/orders/{order_id}")
async def get_shop_order(request, response):
    order_id = int(request.params["order_id"])

    cached = cache_get(f"order:{order_id}")
    if cached:
        Log.debug("Order cache hit", order_id=order_id)
        return response(cached)

    Log.debug("Order cache miss", order_id=order_id)

    order = ORDER_STORE.get(order_id)
    if order is None:
        Log.warning("Order not found", order_id=order_id)
        return response({"error": "Order not found"}, 404)

    cache_set(f"order:{order_id}", order, ttl=300)
    return response(order)
```

---

## 12. Gotchas

### 1. DEBUG logs flooding production

**Problem:** Hundreds of debug messages per second fill the log file and slow the server.

**Fix:** Set `TINA4_LOG_LEVEL=WARNING` in production. Debug calls are no-ops when the level is above `DEBUG`.

### 2. Logging sensitive data

**Problem:** `Log.info("User logged in", password=request.body["password"])` writes passwords to the log file.

**Fix:** Never log passwords, tokens, card numbers, or PII. Log identifiers and metadata only: `Log.info("User logged in", user_id=user["id"])`.

### 3. Log file grows without rotation

**Problem:** `TINA4_LOG_FILE` is set but `TINA4_LOG_MAX_BYTES` is not. The log file grows until the disk is full.

**Fix:** Always set `TINA4_LOG_MAX_BYTES` and `TINA4_LOG_BACKUP_COUNT` alongside `TINA4_LOG_FILE` in production.

### 4. Forgetting to log exceptions

**Problem:** A route returns 500 but there is no log entry explaining why.

**Fix:** Wrap the handler body in `try/except`. Log the exception with `Log.error(..., error=str(exc), traceback=traceback.format_exc())` before returning the 500 response.
