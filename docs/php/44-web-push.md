# Web Push Notifications

Web Push is a standalone outbound integration. It is deliberately separate
from WebSocket, SSE, and realtime: delivery is handled by the browser push
service and can happen after the application page closes.

## Configuration

```bash
TINA4_WEB_PUSH=true
TINA4_VAPID_SUBJECT=mailto:ops@example.com
TINA4_VAPID_PUBLIC=your-base64url-public-key
TINA4_VAPID_PRIVATE=your-base64url-private-key
```

Keep the private key on the server. `TINA4_WEB_PUSH=false` disables delivery;
an incomplete or mismatched configured key pair fails loudly. PHP uses the
existing `ext-openssl` capability and adds no Composer crypto package.

## Browser subscription

Register a service worker, then use `push.subscribe()` from tina4-js with the
public VAPID key. Send the returned browser-native subscription to an
authenticated application endpoint and store its `endpoint`, `keys.p256dh`,
and `keys.auth` values.

## Server delivery

```php
use Tina4\Push;

$sender = new Push();
$result = $sender->send($subscription, [
    'title' => 'Order ready',
    'body' => 'Order 123 is ready for collection',
]);

if ($result['dead']) {
    // Remove the subscription after HTTP 404 or 410.
}
```

Tina4 uses OpenSSL for P-256 ECDH, AES-GCM, and VAPID ES256 signing. The
result includes `ok`, `status`, `dead`, `retryable`, `endpoint`, and the push
service response. HTTP 404/410 are dead subscriptions; 408, 429, and 5xx are
retryable.
