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

Python's standard library ships no P-256 or ES256, so Tina4 borrows them from the
operating system. On a Linux server it calls the system OpenSSL (`libcrypto`)
straight through, the same platform crypto the PHP, Ruby and Node frameworks lean
on, so the server needs nothing installed.

A development Mac or Windows box can't always reach a safe OpenSSL: macOS ships
LibreSSL, which refuses to load this way, and Windows carries no system OpenSSL at
all. There Tina4 falls back to the `cryptography` package, so install it while you
develop:

```bash
pip install tina4-python[push]
```

`TINA4_PUSH_BACKEND` pins the choice when you want it fixed: `libcrypto`,
`cryptography`, or `auto` (the default, which prefers `libcrypto`). Either backend
writes the same bytes, so a push signed on your laptop and one signed on the server
look identical on the wire. Configure Web Push without a usable backend and the
sender fails with an actionable error the moment it runs.

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

The sender speaks stdlib HTTP and hands the crypto to whichever backend loaded. It
produces RFC 8291 `aes128gcm` payloads and VAPID ES256 tokens. The result exposes
`ok`, `status`, `dead`, `retryable`, `endpoint`, and the response body. HTTP
404/410 are dead subscriptions; 408, 429, and 5xx are retryable.
