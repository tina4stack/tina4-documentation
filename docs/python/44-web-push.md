# Web Push Notifications

Web Push is a standalone outbound integration, separate from WebSocket, SSE,
and realtime features. A browser subscription can receive an encrypted message
after the page is closed.

## Configuration and capability

```bash
TINA4_WEB_PUSH=true
TINA4_VAPID_SUBJECT=mailto:ops@example.com
TINA4_VAPID_PUBLIC=your-base64url-public-key
TINA4_VAPID_PRIVATE=your-base64url-private-key
```

The Python standard library does not provide P-256 ECDH or ES256. Select the
optional capability when the project enables Web Push:

```bash
pip install tina4-python[push]
```

The core package remains zero-dependency. If Web Push is configured without the
capability, Tina4 fails with an actionable error when the sender is used.

## Browser subscription

Use `push.subscribe()` from tina4-js with the public VAPID key, then persist the
returned `endpoint`, `keys.p256dh`, and `keys.auth` for the user. A service
worker must be registered first.

## Server delivery

```python
from tina4_python import Push

sender = Push()  # reads TINA4_VAPID_* from the environment
result = sender.send(subscription, {
    "title": "Order ready",
    "body": "Order 123 is ready for collection",
})

if result.dead:
    # Remove the subscription after HTTP 404 or 410.
    pass
```

The implementation uses `cryptography` only for the selected capability and
stdlib HTTP. It produces RFC 8291 `aes128gcm` payloads and VAPID ES256 tokens.
The result exposes `ok`, `status`, `dead`, `retryable`, `endpoint`, and the
response body. HTTP 404/410 are dead subscriptions; 408, 429, and 5xx are
retryable.
