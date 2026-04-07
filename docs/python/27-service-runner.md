# Chapter 26: Service Runner

## 1. Work That Never Stops

Some tasks run on a schedule. Some run indefinitely. A queue worker that drains emails. A cache warmer that refreshes product data every five minutes. These are background services — long-lived processes that run alongside the web server but are not tied to any HTTP request.

Tina4's service runner gives these tasks a consistent start/stop lifecycle. Register services. Start them. Stop them gracefully. They run in background threads so they do not block the web server.

---

## 2. A Basic Background Service

A service is any class with a `run()` method. Start it with the runner and it executes in the background:

```python
import time
from tina4_python.service import ServiceRunner

class HeartbeatService:
    def __init__(self, interval=30):
        self.interval = interval
        self.running = False

    def run(self):
        self.running = True
        while self.running:
            print(f"Heartbeat at {time.strftime('%H:%M:%S')}")
            time.sleep(self.interval)

    def stop(self):
        self.running = False


runner = ServiceRunner()
runner.register("heartbeat", HeartbeatService(interval=30))
runner.start()
```

`runner.start()` launches all registered services in background threads and returns immediately. The web server keeps handling requests. The heartbeat ticks every 30 seconds.

---

## 3. Start / Stop Lifecycle

Every service implements `run()` and `stop()`. The runner calls `run()` in a thread when started and `stop()` when shutting down.

```python
import threading
import time
from tina4_python.service import ServiceRunner

class PollingService:
    def __init__(self, poll_url, interval=60):
        self.poll_url = poll_url
        self.interval = interval
        self._running = threading.Event()

    def run(self):
        self._running.set()
        while self._running.is_set():
            try:
                self._poll()
            except Exception as exc:
                print(f"Poll failed: {exc}")

            # Wait for interval or until stop() clears the event
            self._running.wait(timeout=self.interval)

    def stop(self):
        self._running.clear()

    def _poll(self):
        from tina4_python.api import Api
        api = Api(timeout=10)
        result = api.get(self.poll_url)
        if result["http_code"] == 200:
            print(f"Poll ok: {result['body']}")
        else:
            print(f"Poll error: {result['http_code']}")
```

Using `threading.Event` instead of a boolean for the stop signal is safer: `wait(timeout=n)` wakes up immediately when the event is cleared, so `stop()` takes effect within milliseconds rather than waiting for the next sleep to expire.

---

## 4. Queue Worker Service

The most common background service is a queue worker:

```python
import time
from tina4_python.service import ServiceRunner
from tina4_python.queue import Queue
from tina4_python.debug import Log


class EmailWorker:
    def __init__(self):
        self.queue = Queue(topic="emails", max_retries=3)
        self._running = False

    def run(self):
        self._running = True
        Log.info("Email worker started")

        while self._running:
            job = self.queue.pop()

            if job is None:
                # No pending jobs -- wait briefly before checking again
                time.sleep(1)
                continue

            try:
                self._send_email(job.payload)
                job.complete()
                Log.info("Email sent", to=job.payload["to"])
            except Exception as exc:
                job.fail(str(exc))
                Log.warning("Email failed", to=job.payload.get("to"), error=str(exc))

    def stop(self):
        self._running = False
        Log.info("Email worker stopped")

    def _send_email(self, payload):
        # Replace with real email logic
        import time
        time.sleep(0.1)  # Simulate sending
        if payload.get("to") == "bounce@example.com":
            raise RuntimeError("Recipient address rejected")


# Register and start
runner = ServiceRunner()
runner.register("email_worker", EmailWorker())
runner.start()
```

---

## 5. Scheduled Task Service

Run a function on a fixed schedule:

```python
import time
import threading
from tina4_python.service import ServiceRunner
from tina4_python.debug import Log


class ScheduledTask:
    def __init__(self, name, task_fn, interval_seconds):
        self.name = name
        self.task_fn = task_fn
        self.interval = interval_seconds
        self._stop_event = threading.Event()

    def run(self):
        Log.info("Scheduled task started", task=self.name, interval=self.interval)
        while not self._stop_event.is_set():
            try:
                self.task_fn()
            except Exception as exc:
                Log.error("Scheduled task failed", task=self.name, error=str(exc))
            self._stop_event.wait(timeout=self.interval)

    def stop(self):
        self._stop_event.set()
        Log.info("Scheduled task stopped", task=self.name)


def warm_cache():
    from tina4_python.cache import cache_set
    Log.debug("Cache warming started")
    # Fetch expensive data and pre-populate the cache
    cache_set("featured_products", fetch_featured_products(), ttl=300)
    Log.debug("Cache warming complete")

def fetch_featured_products():
    return [
        {"id": 1, "name": "Wireless Keyboard", "price": 79.99},
        {"id": 2, "name": "USB-C Hub", "price": 49.99}
    ]


runner = ServiceRunner()
runner.register("cache_warmer", ScheduledTask("cache_warmer", warm_cache, interval_seconds=240))
runner.start()
```

---

## 6. Multiple Services

Register as many services as you need:

```python
from tina4_python.service import ServiceRunner

runner = ServiceRunner()
runner.register("email_worker", EmailWorker())
runner.register("sms_worker", SmsWorker())
runner.register("cache_warmer", ScheduledTask("cache_warmer", warm_cache, 240))
runner.register("health_check", PollingService("https://api.internal/health", 30))

runner.start()
print("All services started")
```

All four services start concurrently. Each runs in its own thread.

---

## 7. Stopping Services Gracefully

Stop all services at once:

```python
runner.stop()
```

`stop()` calls `stop()` on each registered service and waits for their threads to finish. Use this in your application shutdown handler:

```python
import signal

def shutdown_handler(signum, frame):
    print("Shutting down services...")
    runner.stop()
    print("All services stopped.")

signal.signal(signal.SIGTERM, shutdown_handler)
signal.signal(signal.SIGINT, shutdown_handler)
```

Stop a single service by name:

```python
runner.stop_service("cache_warmer")
```

---

## 8. Integrating with the App

Start the runner in your `src/app.py`:

```python
# src/app.py
from tina4_python.tina4 import Tina4
from src.worker_services import runner

app = Tina4()

@app.on_startup
def start_services():
    runner.start()

@app.on_shutdown
def stop_services():
    runner.stop()
```

---

## 9. Exercise: Cache-Warming Background Service

Build a background service that keeps a product cache warm.

### Requirements

1. Create a `ProductCacheWarmer` service that:
   - Runs every 60 seconds
   - Fetches the top 20 products
   - Stores them in cache with a 120-second TTL
   - Logs a summary each time it runs

2. Create a `GET /api/products/featured` route that:
   - Returns products from cache (never hits the "database" directly)
   - Returns a 503 if the cache is not yet warm

3. Register the service with the runner and start it on app startup

### Test with:

```bash
# Before the cache warms (first 60 seconds)
curl http://localhost:7145/api/products/featured
# 503 Service Unavailable -- cache not ready

# After the cache warmer runs
curl http://localhost:7145/api/products/featured
# 200 OK with product list
```

---

## 10. Solution

```python
# src/workers/product_cache_warmer.py
import threading
from tina4_python.cache import cache_set
from tina4_python.debug import Log


FEATURED_PRODUCTS = [
    {"id": i, "name": f"Product {i}", "price": round(9.99 * i, 2)}
    for i in range(1, 21)
]


class ProductCacheWarmer:
    def __init__(self, interval=60):
        self.interval = interval
        self._stop_event = threading.Event()

    def run(self):
        Log.info("ProductCacheWarmer started", interval=self.interval)
        while not self._stop_event.is_set():
            self._warm()
            self._stop_event.wait(timeout=self.interval)

    def stop(self):
        self._stop_event.set()
        Log.info("ProductCacheWarmer stopped")

    def _warm(self):
        products = FEATURED_PRODUCTS[:20]
        cache_set("products:featured", products, ttl=120)
        Log.info("Cache warmed", product_count=len(products))
```

```python
# src/routes/featured_products.py
from tina4_python.core.router import get
from tina4_python.cache import cache_get


@get("/api/products/featured")
async def featured_products(request, response):
    products = cache_get("products:featured")

    if products is None:
        return response(
            {"error": "Service warming up, please retry in a moment"},
            503
        )

    return response({"products": products, "count": len(products)})
```

```python
# src/app.py (startup integration)
from tina4_python.service import ServiceRunner
from src.workers.product_cache_warmer import ProductCacheWarmer

runner = ServiceRunner()
runner.register("product_cache_warmer", ProductCacheWarmer(interval=60))
runner.start()
```

---

## 11. Gotchas

### 1. Blocking the main thread

**Problem:** `runner.start()` blocks because a service's `run()` calls `runner.start()` again recursively, or a service does not return from `run()`.

**Fix:** `run()` must contain the loop internally. `runner.start()` is non-blocking — it launches threads and returns. Each service owns its own loop.

### 2. No stop() method

**Problem:** `runner.stop()` raises `AttributeError` because the service class does not implement `stop()`.

**Fix:** Always implement `stop()`. Set a flag or clear a threading event that the `run()` loop checks.

### 3. Exceptions crashing the service thread

**Problem:** An unhandled exception in `run()` kills the thread. The service stops silently.

**Fix:** Wrap the loop body in `try/except`. Log the error and continue. Only exit the loop on a stop signal.

### 4. Service starts before .env is loaded

**Problem:** A service reads an environment variable at construction time, before Tina4 loads `.env`.

**Fix:** Read environment variables inside `run()` or `_warm()`, not in `__init__`. Or use a factory pattern: construct the service inside an `on_startup` hook, after `.env` is loaded.
