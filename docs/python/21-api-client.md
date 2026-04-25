# Chapter 21: API Client

## 1. Calling External APIs

Every real application talks to something external. A payment processor. A weather service. A shipping carrier. A CRM. You write the HTTP call, parse the response, handle timeouts, retry on failure, add auth headers.

Tina4's `Api` class makes outbound HTTP requests from your server-side code. It returns a consistent response format, handles auth in one line, and supports SSL and timeout configuration — with no extra libraries.

---

## 2. Basic Requests

```python
from tina4_python.api import Api

api = Api()

# GET
result = api.get("https://api.example.com/products")

# POST with JSON body
result = api.post("https://api.example.com/orders", {
    "product_id": 42,
    "quantity": 3
})

# PUT
result = api.put("https://api.example.com/orders/101", {
    "status": "shipped"
})

# PATCH
result = api.patch("https://api.example.com/orders/101", {
    "tracking_number": "1Z999AA10123456784"
})

# DELETE
result = api.delete("https://api.example.com/orders/101")
```

Every method returns the same structure:

```python
{
    "http_code": 200,
    "body": { ... },     # Parsed JSON, or raw string if not JSON
    "headers": { ... },  # Response headers
    "error": None        # None on success, error string on failure
}
```

---

## 3. Reading the Response

```python
from tina4_python.api import Api

api = Api()
result = api.get("https://jsonplaceholder.typicode.com/posts/1")

if result["error"]:
    print(f"Request failed: {result['error']}")
else:
    print(f"Status: {result['http_code']}")
    print(f"Title: {result['body']['title']}")
```

Check `result["error"]` first. If it is `None`, the request succeeded. The HTTP status code is in `result["http_code"]`. The parsed response is in `result["body"]`.

```python
# In a route handler
from tina4_python.core.router import get
from tina4_python.api import Api

@get("/api/posts/{post_id}")
async def proxy_post(request, response):
    api = Api()
    post_id = request.params["post_id"]

    result = api.get(f"https://jsonplaceholder.typicode.com/posts/{post_id}")

    if result["error"]:
        return response({"error": result["error"]}, 502)

    if result["http_code"] == 404:
        return response({"error": "Post not found"}, 404)

    return response(result["body"])
```

---

## 4. Authentication Headers

### Bearer Token

```python
from tina4_python.api import Api

api = Api(bearer_token="eyJhbGciOiJSUzI1NiJ9...")

result = api.get("https://api.example.com/me")
```

The `Authorization: Bearer <token>` header is sent with every request made by this `Api` instance.

### Basic Authentication

```python
api = Api(username="api_user", password="secret123")

result = api.get("https://api.example.com/data")
```

Sends `Authorization: Basic <base64(username:password)>` with every request.

### Custom Headers

```python
api = Api(headers={
    "X-API-Key": "my-api-key-here",
    "X-Client-Version": "1.0.0",
    "Accept": "application/json"
})

result = api.get("https://api.example.com/data")
```

Custom headers are merged with any authentication headers and sent with every request.

### Mixing Auth and Custom Headers

```python
api = Api(
    bearer_token="eyJhbGciOiJSUzI1NiJ9...",
    headers={"X-Request-Source": "tina4-app"}
)
```

---

## 5. SSL Verification and Timeouts

```python
# Disable SSL verification (dev only, never in production)
api = Api(verify_ssl=False)

# Set a 10-second timeout
api = Api(timeout=10)

# Both
api = Api(verify_ssl=False, timeout=5)
```

The default timeout is 30 seconds. The default SSL behaviour is to verify certificates (`verify_ssl=True`).

Never disable SSL verification in production. If an external API has a self-signed certificate, obtain the CA bundle and pass it explicitly, or ask the provider for their CA bundle.

---

## 6. Sending Query Parameters

Pass query parameters as a dictionary to the `params` argument:

```python
api = Api()

result = api.get("https://api.example.com/products", params={
    "category": "Electronics",
    "page": 1,
    "limit": 20,
    "in_stock": True
})
# Requests: GET /products?category=Electronics&page=1&limit=20&in_stock=True
```

---

## 7. Real-World Patterns

### Payment Gateway

```python
import os
from tina4_python.api import Api

class PaymentGateway:
    def __init__(self):
        self.api = Api(
            bearer_token=os.environ["PAYMENT_API_KEY"],
            timeout=15
        )
        self.base = "https://api.payment-provider.com/v1"

    def charge(self, amount_cents, currency, card_token):
        result = self.api.post(f"{self.base}/charges", {
            "amount": amount_cents,
            "currency": currency,
            "source": card_token
        })

        if result["error"]:
            return {"success": False, "error": result["error"]}

        if result["http_code"] not in (200, 201):
            return {
                "success": False,
                "error": result["body"].get("message", "Payment declined")
            }

        return {
            "success": True,
            "charge_id": result["body"]["id"],
            "status": result["body"]["status"]
        }

    def refund(self, charge_id, amount_cents=None):
        body = {"charge": charge_id}
        if amount_cents:
            body["amount"] = amount_cents

        result = self.api.post(f"{self.base}/refunds", body)
        return result["body"]
```

### Weather Service

```python
import os
from tina4_python.api import Api

class WeatherService:
    def __init__(self):
        self.api = Api(timeout=5)
        self.api_key = os.environ["OPENWEATHER_API_KEY"]
        self.base = "https://api.openweathermap.org/data/2.5"

    def get_current(self, city):
        result = self.api.get(f"{self.base}/weather", params={
            "q": city,
            "appid": self.api_key,
            "units": "metric"
        })

        if result["error"] or result["http_code"] != 200:
            return None

        data = result["body"]
        return {
            "city": data["name"],
            "temp_c": data["main"]["temp"],
            "description": data["weather"][0]["description"],
            "humidity": data["main"]["humidity"]
        }
```

Usage in a route:

```python
from tina4_python.core.router import get

weather = WeatherService()

@get("/api/weather/{city}")
async def get_weather(request, response):
    city = request.params["city"]
    data = weather.get_current(city)

    if data is None:
        return response({"error": "Weather data unavailable"}, 502)

    return response(data)
```

---

## 8. Retry Logic

For transient failures, add retry logic around `Api` calls:

```python
import time
from tina4_python.api import Api
from tina4_python.debug import Log

def api_get_with_retry(url, max_retries=3, backoff=1.0, **kwargs):
    api = Api(**kwargs)
    last_error = None

    for attempt in range(1, max_retries + 1):
        result = api.get(url)

        if not result["error"] and result["http_code"] < 500:
            return result

        last_error = result["error"] or f"HTTP {result['http_code']}"
        Log.warning("API call failed, retrying", url=url, attempt=attempt, error=last_error)

        if attempt < max_retries:
            time.sleep(backoff * attempt)

    Log.error("API call failed after retries", url=url, error=last_error)
    return {"http_code": 0, "body": None, "headers": {}, "error": last_error}
```

---

## 9. Exercise: Weather Dashboard API

Build a route that fetches weather for multiple cities and returns a dashboard-ready response.

### Requirements

1. Create `GET /api/dashboard/weather` that:
   - Accepts a `cities` query parameter (comma-separated)
   - Calls a mock weather API for each city
   - Returns aggregated results
   - Returns 502 if any city fails

2. Use proper error checking on every API call

3. Add a 5-second timeout and Bearer token auth

### Test with:

```bash
curl "http://localhost:7146/api/dashboard/weather?cities=London,Berlin,Tokyo"
```

---

## 10. Solution

Create `src/routes/weather_dashboard.py`:

```python
from tina4_python.core.router import get
from tina4_python.api import Api
from tina4_python.debug import Log

# Simulate a weather API with mock data
MOCK_WEATHER = {
    "london": {"city": "London", "temp_c": 12.3, "description": "Cloudy", "humidity": 78},
    "berlin": {"city": "Berlin", "temp_c": 8.1, "description": "Clear", "humidity": 55},
    "tokyo": {"city": "Tokyo", "temp_c": 18.7, "description": "Partly cloudy", "humidity": 65},
    "paris": {"city": "Paris", "temp_c": 14.0, "description": "Rainy", "humidity": 82},
}

def fetch_weather(city_name):
    # In production this would be a real API call:
    # api = Api(bearer_token=os.environ["WEATHER_API_KEY"], timeout=5)
    # return api.get(f"https://api.weather.com/v1/current?city={city_name}")

    key = city_name.lower().strip()
    data = MOCK_WEATHER.get(key)
    if data is None:
        return {"http_code": 404, "body": None, "headers": {}, "error": f"City not found: {city_name}"}
    return {"http_code": 200, "body": data, "headers": {}, "error": None}


@get("/api/dashboard/weather")
async def weather_dashboard(request, response):
    cities_param = request.params.get("cities", "")

    if not cities_param:
        return response({"error": "Provide at least one city via ?cities=City1,City2"}, 400)

    cities = [c.strip() for c in cities_param.split(",") if c.strip()]
    results = []
    errors = []

    for city in cities:
        Log.debug("Fetching weather", city=city)
        result = fetch_weather(city)

        if result["error"]:
            Log.warning("Weather fetch failed", city=city, error=result["error"])
            errors.append({"city": city, "error": result["error"]})
        else:
            results.append(result["body"])

    if errors:
        return response({
            "error": "One or more cities could not be fetched",
            "failed": errors,
            "succeeded": results
        }, 502)

    return response({
        "cities": results,
        "count": len(results)
    })
```

```bash
curl "http://localhost:7146/api/dashboard/weather?cities=London,Berlin,Tokyo"
```

```json
{
  "cities": [
    {"city": "London", "temp_c": 12.3, "description": "Cloudy", "humidity": 78},
    {"city": "Berlin", "temp_c": 8.1, "description": "Clear", "humidity": 55},
    {"city": "Tokyo", "temp_c": 18.7, "description": "Partly cloudy", "humidity": 65}
  ],
  "count": 3
}
```

---

## 11. Gotchas

### 1. Not checking result["error"]

**Problem:** Code accesses `result["body"]["id"]` but the request timed out, so `body` is `None`.

**Fix:** Always check `result["error"]` before accessing `result["body"]`. Treat any non-None error as a failure.

### 2. Using verify_ssl=False in production

**Problem:** A man-in-the-middle intercepts requests to a payment gateway because SSL verification is disabled.

**Fix:** Only use `verify_ssl=False` against local services or during development. Never disable SSL for external APIs.

### 3. No timeout set for slow external APIs

**Problem:** An external API hangs for 90 seconds. Your route handler blocks for 90 seconds. All workers are eventually held waiting.

**Fix:** Always set `timeout` to a sensible value (5–15 seconds for most external APIs). Return a 502 or 504 to the caller if the external API does not respond in time.

### 4. Hardcoding API keys

**Problem:** `api = Api(bearer_token="sk-live-abc123...")` exposes the key in source control.

**Fix:** Read credentials from environment variables: `bearer_token=os.environ["PAYMENT_API_KEY"]`. Never hardcode secrets.
