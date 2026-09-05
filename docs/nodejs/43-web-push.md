# Web Push Notifications

Web Push is a standalone outbound integration. It is not a WebSocket, SSE, or
realtime transport: the browser can receive a notification after the page and
application have closed. Tina4 sends to the browser subscription; the browser
service worker displays the notification.

## Configuration

Generate one VAPID key pair and keep the private key on the server:

```bash
TINA4_WEB_PUSH=true
TINA4_VAPID_SUBJECT=mailto:ops@example.com
TINA4_VAPID_PUBLIC=your-base64url-public-key
TINA4_VAPID_PRIVATE=your-base64url-private-key
```

`TINA4_WEB_PUSH=false` disables the feature explicitly. A configured but
incomplete or mismatched key pair fails immediately. Never send the private
key to the browser or commit it to source control.

## Browser subscription

The tina4-js helper requests permission and returns the browser-native shape:

```ts
import { push } from 'tina4js/push';

const subscription = await push.subscribe({
  applicationServerKey: import.meta.env.VITE_TINA4_VAPID_PUBLIC,
});
await fetch('/api/push-subscriptions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(subscription),
});
```

A service worker must be registered before subscribing. Store the returned
`endpoint`, `keys.p256dh`, and `keys.auth` for the signed-in user.

## Server delivery

```ts
import { Push } from '@tina4/core';

const sender = new Push();
const result = await sender.send(subscription, {
  title: 'Order ready',
  body: 'Order 123 is ready for collection',
});

if (result.dead) {
  // Remove the subscription after HTTP 404 or 410.
}
```

The sender uses native Node crypto and `fetch`; no web-push npm package is
required. Payloads use RFC 8291 `aes128gcm` encryption and VAPID ES256. The
result always includes `ok`, `status`, `dead`, `retryable`, `endpoint`, and the
push-service response. HTTP 404/410 are dead subscriptions; 408, 429, and 5xx
responses are retryable.
