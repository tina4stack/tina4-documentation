# Web Push Notifications

Web Push is a standalone outbound integration, alongside Messenger and SSO.
It is not a WebSocket, SSE, or realtime transport: a browser push service can
deliver after the page has closed.

## Configuration

```bash
TINA4_WEB_PUSH=true
TINA4_VAPID_SUBJECT=mailto:ops@example.com
TINA4_VAPID_PUBLIC=your-base64url-public-key
TINA4_VAPID_PRIVATE=your-base64url-private-key
```

The private key stays on the server. Setting `TINA4_WEB_PUSH=false` disables
the feature. A configured but incomplete or mismatched key pair fails loudly.
Ruby uses its existing OpenSSL stdlib/default gem and adds no JWT or Web Push
gem.

## Browser subscription

After registering a service worker, use `push.subscribe()` from tina4-js with
the public VAPID key. Persist the returned `endpoint`, `keys.p256dh`, and
`keys.auth` values for the signed-in user.

## Server delivery

```ruby
sender = Tina4::Push.new
result = sender.send(subscription, {
  "title" => "Order ready",
  "body" => "Order 123 is ready for collection"
})

Tina4::Push.generate_vapid_keys # one-time key generation

if result["dead"]
  # Remove the subscription after HTTP 404 or 410.
end
```

Delivery uses OpenSSL for P-256 ECDH, AES-GCM, and VAPID ES256 signing. The
result includes `ok`, `status`, `dead`, `retryable`, `endpoint`, and the push
service response. HTTP 404/410 are dead subscriptions; 408, 429, and 5xx are
retryable.
