# Feature 140: Web Push

Web Push is a standalone outbound integration. It is not WebSocket, Server-Sent Events, or a realtime backplane.

Enable it with configuration:

```env
TINA4_WEB_PUSH=true
TINA4_VAPID_SUBJECT=mailto:ops@example.com
TINA4_VAPID_PUBLIC=<base64url P-256 public key>
TINA4_VAPID_PRIVATE=<base64url P-256 private key>
```

Ruby uses its OpenSSL standard-library capability. When Web Push is configured without OpenSSL or complete keys, it fails loudly.

```ruby
sender = Tina4::Push.new # reads TINA4_VAPID_* from the environment
result = sender.send(subscription, { "title" => "Order ready", "body" => "Order 123 is ready" })
```

The sender produces VAPID ES256 authorization and RFC 8291 `aes128gcm` payloads. The result exposes `ok`, `status`, `dead`, `retryable`, `endpoint`, and `response`; HTTP 404/410 are dead subscriptions, while 408, 429, and 5xx are retryable.
