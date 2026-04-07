# Chapter 21: API Client

## 1. Calling External APIs Without Dependencies

Every app calls external services. Weather APIs. Payment gateways. CRM systems. Shipping providers. The default PHP approach is cURL — verbose, error-prone, and full of boilerplate.

Tina4 provides a built-in `Api` class that wraps cURL with a clean interface. It supports GET, POST, PUT, DELETE, and PATCH with custom headers, basic auth, JSON or form payloads, and timeout control — no Guzzle, no Composer dependencies.

---

## 2. Creating an API Client

```php
<?php
use Tina4\Api;

// Base URL -- all requests are relative to this
$api = new Api('https://api.example.com');
```

The `Api` class stores the base URL and shared configuration. Individual requests specify the path.

---

## 3. sendRequest()

All requests go through `sendRequest()`. It returns an associative array with:

- `status` — HTTP status code (integer)
- `body` — parsed response body (array if JSON, string otherwise)
- `headers` — response headers
- `error` — error message string on failure, `null` on success

```php
<?php
use Tina4\Api;

$api = new Api('https://jsonplaceholder.typicode.com');

// GET request
$result = $api->sendRequest('GET', '/posts/1');

echo $result['status'];        // 200
print_r($result['body']);      // ['id' => 1, 'title' => '...', ...]
```

---

## 4. GET Requests

Fetch a resource:

```php
<?php
use Tina4\Api;

$api = new Api('https://jsonplaceholder.typicode.com');

$result = $api->sendRequest('GET', '/users/1');

if ($result['status'] === 200) {
    $user = $result['body'];
    echo "Name: {$user['name']}\n";
    echo "Email: {$user['email']}\n";
} else {
    echo "Error {$result['status']}: " . ($result['error'] ?? 'Unknown error');
}
```

---

## 5. POST, PUT, PATCH, DELETE

Pass the payload as the fourth argument to `sendRequest()`.

### POST — Create a resource

```php
<?php
use Tina4\Api;

$api = new Api('https://jsonplaceholder.typicode.com');

$result = $api->sendRequest('POST', '/posts', [], [
    'title'  => 'My New Post',
    'body'   => 'This is the content of the post.',
    'userId' => 1
]);

echo $result['status'];              // 201
echo $result['body']['id'];          // 101 (new resource ID)
```

### PUT — Full update

```php
$result = $api->sendRequest('PUT', '/posts/1', [], [
    'id'     => 1,
    'title'  => 'Updated Title',
    'body'   => 'Updated content.',
    'userId' => 1
]);

echo $result['status'];   // 200
```

### PATCH — Partial update

```php
$result = $api->sendRequest('PATCH', '/posts/1', [], [
    'title' => 'Just the title changed'
]);

echo $result['status'];   // 200
```

### DELETE — Remove a resource

```php
$result = $api->sendRequest('DELETE', '/posts/1');

echo $result['status'];   // 200 or 204
```

---

## 6. Query Parameters

Pass query parameters as the third argument:

```php
<?php
use Tina4\Api;

$api = new Api('https://jsonplaceholder.typicode.com');

$result = $api->sendRequest('GET', '/posts', [
    'userId' => 1,
    '_limit' => 5,
    '_sort'  => 'id',
    '_order' => 'desc'
]);

// Resolves to: GET /posts?userId=1&_limit=5&_sort=id&_order=desc

echo count($result['body']);   // 5
```

---

## 7. Custom Headers

Use `addCustomHeaders()` to set headers that apply to all subsequent requests from this client instance.

```php
<?php
use Tina4\Api;

$api = new Api('https://api.stripe.com/v1');

$api->addCustomHeaders([
    'Authorization' => 'Bearer sk_test_YOUR_STRIPE_KEY_HERE',
    'Stripe-Version' => '2023-10-16',
    'Idempotency-Key' => bin2hex(random_bytes(16))
]);

$result = $api->sendRequest('POST', '/payment_intents', [], [
    'amount'   => 2000,   // $20.00 in cents
    'currency' => 'usd',
    'payment_method_types' => ['card']
]);

echo $result['status'];          // 200
echo $result['body']['id'];      // pi_3OWL...
echo $result['body']['status'];  // requires_payment_method
```

---

## 8. Basic Authentication

Use `setUsernamePassword()` for HTTP Basic Auth:

```php
<?php
use Tina4\Api;

$api = new Api('https://api.example.com');
$api->setUsernamePassword('my-api-key', 'my-api-secret');

$result = $api->sendRequest('GET', '/account');

echo $result['body']['plan'];   // 'enterprise'
```

The credentials are Base64-encoded and sent as an `Authorization: Basic ...` header.

---

## 9. Bearer Token Auth

Use a custom header for token-based auth (OAuth2, JWT):

```php
<?php
use Tina4\Api;

// Step 1: Get an access token
$authApi = new Api('https://auth.example.com');
$tokenResult = $authApi->sendRequest('POST', '/oauth/token', [], [
    'grant_type'    => 'client_credentials',
    'client_id'     => getenv('CLIENT_ID'),
    'client_secret' => getenv('CLIENT_SECRET')
]);

$accessToken = $tokenResult['body']['access_token'];

// Step 2: Use the token for API calls
$api = new Api('https://api.example.com');
$api->addCustomHeaders([
    'Authorization' => "Bearer {$accessToken}",
    'Accept'        => 'application/json'
]);

$result = $api->sendRequest('GET', '/resources');
```

---

## 10. Error Handling

Always check `status` before accessing `body`. Handle network errors via `error`:

```php
<?php
use Tina4\Api;

function fetchUser(int $id): ?array {
    $api = new Api('https://api.example.com');
    $result = $api->sendRequest('GET', "/users/{$id}");

    // Network or cURL failure
    if ($result['error'] !== null) {
        error_log("API network error: {$result['error']}");
        return null;
    }

    // HTTP error responses
    if ($result['status'] === 404) {
        return null;   // Not found -- expected, return null
    }

    if ($result['status'] === 429) {
        // Rate limited -- retry after delay
        sleep((int) ($result['headers']['Retry-After'] ?? 5));
        return fetchUser($id);  // Retry once
    }

    if ($result['status'] >= 500) {
        error_log("API server error {$result['status']} for user {$id}");
        throw new \RuntimeException("External API unavailable");
    }

    if ($result['status'] !== 200) {
        error_log("Unexpected status {$result['status']}");
        return null;
    }

    return $result['body'];
}
```

---

## 11. Calling External APIs from Routes

Wrap the `Api` client in route handlers to build aggregator or proxy endpoints:

```php
<?php
use Tina4\Router;
use Tina4\Api;

/**
 * @noauth
 */
Router::get('/api/weather/{city}', function ($request, $response) {
    $city = $request->params['city'];
    $apiKey = getenv('OPENWEATHER_API_KEY');

    $api = new Api('https://api.openweathermap.org/data/2.5');

    $result = $api->sendRequest('GET', '/weather', [
        'q'     => $city,
        'appid' => $apiKey,
        'units' => 'metric'
    ]);

    if ($result['status'] === 404) {
        return $response->json(['error' => "City '{$city}' not found"], 404);
    }

    if ($result['status'] !== 200) {
        return $response->json(['error' => 'Weather service unavailable'], 502);
    }

    $weather = $result['body'];

    return $response->json([
        'city'        => $weather['name'],
        'country'     => $weather['sys']['country'],
        'temperature' => $weather['main']['temp'],
        'description' => $weather['weather'][0]['description'],
        'humidity'    => $weather['main']['humidity'],
        'wind_speed'  => $weather['wind']['speed']
    ]);
});
```

```bash
curl http://localhost:7146/api/weather/London
```

```json
{
  "city": "London",
  "country": "GB",
  "temperature": 12.5,
  "description": "overcast clouds",
  "humidity": 81,
  "wind_speed": 5.2
}
```

---

## 12. Exercise: GitHub API Proxy

Build a proxy that fetches GitHub repository information.

### Requirements

1. Create these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/github/{owner}/{repo}` | Repo details (stars, forks, description) |
| `GET` | `/api/github/{owner}/{repo}/releases` | Latest 5 releases |

2. Use the GitHub public API at `https://api.github.com`
3. Set the required `User-Agent` header (GitHub rejects requests without it)
4. Handle 404 gracefully

### Test with:

```bash
curl http://localhost:7146/api/github/tina4/tina4-python
curl http://localhost:7146/api/github/tina4/tina4-python/releases
curl http://localhost:7146/api/github/nobody/nonexistent-repo
```

---

## 13. Gotchas

### 1. No timeout set

**Problem:** A slow external API hangs your request for 30+ seconds.

**Cause:** cURL default timeout is 0 (infinite wait).

**Fix:** Pass a timeout in the options: `$api->sendRequest('GET', '/path', [], [], ['timeout' => 5])`. Always set a reasonable timeout for external calls.

### 2. Not checking status before accessing body

**Problem:** Code crashes with "Undefined index" when the body is an error message, not the expected structure.

**Cause:** The API returned a 4xx/5xx error. The body is an error object, not the expected resource.

**Fix:** Always check `$result['status']` before accessing `$result['body']`.

### 3. Credentials in source code

**Problem:** API keys and secrets are committed to the repository.

**Cause:** Credentials hard-coded in the `Api` instantiation call.

**Fix:** Always read credentials from environment variables: `getenv('API_KEY')`. Never commit `.env` files.

### 4. Not handling rate limits

**Problem:** After many requests, the API returns 429 and all subsequent calls fail.

**Cause:** No rate limit detection or backoff logic.

**Fix:** Check for `status === 429`, read `Retry-After` from the response headers, and sleep before retrying.
