# Feature 140: Web Push Notifications

## Outcome

Add provider-neutral Web Push delivery for browser subscriptions. The feature
works after the browser is closed, which makes it an outbound notification
integration rather than a WebSocket, SSE, or realtime transport.

The public surface is consistent across Python, PHP, Ruby, and Node.js. The
browser subscription helper lives in tina4-js. The backend modules own VAPID
signing, RFC 8291 payload encryption, delivery, and dead-subscription handling.

## Scope

- [x] Add a `push` module to all four backend frameworks.
- [x] Add a `push` helper to tina4-js for permission and subscription setup.
- [x] Generate and validate P-256 VAPID keys.
- [x] Sign ES256 VAPID JWTs with the correct audience and expiry.
- [x] Encrypt payloads with the `aes128gcm` Web Push content-encoding.
- [x] POST to subscription endpoints with the correct headers.
- [x] Return a stable result envelope for success, retryable failure, and dead
  subscriptions.
- [x] Treat HTTP 404 and 410 as dead subscriptions without hiding the result.
- [x] Read `TINA4_VAPID_PUBLIC`, `TINA4_VAPID_PRIVATE`, and
  `TINA4_VAPID_SUBJECT` through the normal typed environment layer.
- [x] Keep the feature disabled unless explicitly configured.
- [x] Fail loudly when Web Push is configured but the runtime crypto capability
  is unavailable.
- [ ] Add `tina4 feature enable web-push` integration to the unified client.
- [x] Add the Web Push documentation chapters, feature-list entries, and tina4-js usage guidance.
- [ ] Add all relevant AI-skill guidance.
- [ ] Capture metrics before and after the implementation and require no new
  error-severity offenders.

## Placement

Web Push is a standalone outbound integration, alongside Messenger and SSO.
It must not be placed in `realtime`, `websocket`, or `sse`; those modules model
an open connection, while Web Push targets a browser push service for a closed
application.

| Surface | Location |
| --- | --- |
| Python | `tina4_python/push/` |
| PHP | `Tina4/Push.php` |
| Ruby | `lib/tina4/push/` |
| Node.js | `packages/core/src/push.ts`, exported from the existing `@tina4/core` boundary |
| tina4-js | `src/push.ts` (or the existing public client module boundary) |
| Shared plan | `plan/v3/features/140-web-push.md` |
| CLI enablement | Tina4 Rust client feature registry |

## Public contract

The implementation mirrors the existing Messenger-style object surface. Each
language reads the same environment variables in its normal constructor (with
an explicit environment factory where that language already uses one):

```text
Push() / Push.from_env()
Push.generate_keys() / Push.generateVapidKeys()
Push.send(subscription, payload)
```

The subscription shape is the browser-native form:

```json
{
  "endpoint": "https://push.example/…",
  "keys": {
    "p256dh": "…",
    "auth": "…"
  }
}
```

The payload accepts JSON-native values. The result shape is stable across the
four languages:

```json
{
  "ok": true,
  "status": 201,
  "dead": false,
  "retryable": false,
  "endpoint": "https://push.example/…"
}
```

For HTTP 404 or 410:

```json
{
  "ok": false,
  "status": 410,
  "dead": true,
  "retryable": false,
  "endpoint": "https://push.example/…"
}
```

Malformed subscriptions, invalid keys, missing VAPID configuration, and
unsupported capabilities are hard errors with the same error category and
actionable repair message in every language.

## Dependency policy

The core frameworks remain zero third-party runtime dependencies.

| Framework | Crypto path |
| --- | --- |
| Python | Lazy optional `cryptography` capability; no package in core `dependencies` |
| PHP | Existing `ext-openssl` runtime capability; no Composer crypto package |
| Ruby | Existing OpenSSL stdlib/default gem; no new crypto gem |
| Node.js | Built-in `node:crypto` and `fetch`; no npm package |

Python must not import `cryptography` during normal Tina4 import or server boot.
PHP and Ruby must detect missing OpenSSL before calling an undefined primitive.
Node must use the runtime's native APIs and keep provider-specific packages out
of `@tina4/core`.

## Tests — written before implementation

### Shared contract cases

- [x] VAPID key generation returns a valid P-256 public/private pair.
- [x] Public-key encoding round-trips through the browser subscription shape.
- [x] VAPID JWT has the expected `aud`, `sub`, `exp`, and ES256 signature.
- [x] RFC 8291 encryption decrypts to the original payload (Node reference test).
- [x] Invalid subscription keys fail before network delivery.
- [x] Missing VAPID configuration fails with an actionable error.
- [x] Missing Python crypto capability fails only when Web Push is used.
- [x] HTTP 201 returns `ok=true`.
- [x] HTTP 404 and 410 return `dead=true`.
- [x] Other 4xx/5xx responses preserve status and classify retryability.
- [x] No test uses a fake crypto implementation or fake framework adapter.

Deterministic RFC vectors use fixed ephemeral keys and salt. Live delivery
tests do not compare ciphertext bytes because Web Push encryption is randomized;
they verify the decrypted payload and real HTTP response handling.

### Client and feature-manager cases

- [ ] `tina4 feature list` includes Web Push and its capability requirements.
- [ ] `tina4 feature enable web-push` is idempotent.
- [ ] The manifest is stable, sorted, and atomic on failure.
- [ ] `tina4 feature status web-push --json` distinguishes ready and missing.
- [ ] `tina4 feature disable web-push` removes selection without uninstalling
  unrelated packages.
- [ ] tina4-js requests permission, subscribes with the VAPID public key, and
  returns the browser-native subscription object.

### Metrics regression gate

Before changing framework code, record the exact examples-excluded core scan
for all four repositories with the published Tina4 Metrics binary. After each
backend lands, rerun the same command and store the JSON result in the feature
audit. The gate requires:

- [x] zero refused files;
- [x] zero new error-severity offenders in the new push modules;
- [x] no increase in total warning/duplication debt after the final refactor;
- [x] the new push modules appear in the scanned source set;
- [x] metrics history records the before/after change;
- [ ] the affected framework tests and the shared contract are green.

Metrics findings caused by generated browser bundles, tests, examples, or
third-party dependencies remain excluded by explicit switches, never by a
hard-coded path inside the tool.

## Documentation and skills

- [x] Add a Web Push chapter to the Tina4 documentation site.
- [x] Add Web Push to the four backend feature lists and navigation.
- [x] Add the tina4-js subscription example and service-worker requirements.
- [x] Document VAPID environment variables and secret handling.
- [ ] Document `tina4 feature enable web-push` and `feature status` first.
- [ ] Explain the Python optional capability without making it the primary
  installation instruction.
- [ ] Update `tina4-maintainer` with the placement, parity, and metrics gate.
- [ ] Update `tina4-architect` with the configuration-first choice.
- [ ] Update all four backend developer skills with the native API shape and
  capability failure rules.
- [ ] Update `tina4-js` with permission, service-worker, and subscription use.
- [ ] Synchronize Claude, Codex, and Cursor skill copies.
- [ ] Run documentation truth, link, build, and skill-install checks.

## Implementation order

1. Ratify the Feature 140 contract and add the shared fixture skeleton.
2. Add the Tina4 client feature registry and manifest support.
3. Implement the Node native crypto path as the reference for protocol shape.
4. Port the protocol and result envelope to PHP and Ruby using OpenSSL.
5. Add Python's lazy optional crypto adapter.
6. Add the tina4-js browser helper and service-worker documentation.
7. Run focused tests and the exact metrics baseline after each backend.
8. Run the all-framework lab gate, update docs and skills, and commit.

## Acceptance criteria

- The same code-level Web Push contract passes in all four backends.
- A clean Tina4 project still boots without Web Push or any new package.
- A selected project uses only the required runtime capability for its language.
- A configured but unavailable backend fails loudly and consistently.
- The feature manager is the only documented installation path.
- The metrics scan shows no new error-level offenders and records its history.
- All affected code, docs, skills, and audit records are committed before any
  release decision.

## Commits

- `b4bae6e` — Node.js native backend implementation and RFC 8291 contract tests
- `351342c` — Python optional-crypto backend implementation and contract tests
- `e55a6da4` — PHP OpenSSL backend implementation
- `9b62a34` — Ruby OpenSSL backend implementation
- `2cc7625` — tina4-js browser subscription helper and package export
- `726567a` — Node metrics-clean delivery split and history refresh
- `96c98aa` — Python metrics-clean delivery split and history refresh
- `010509ce` — PHP metrics-clean delivery split and history refresh
- `fe10b68` — Ruby metrics-clean delivery split and history refresh

## Status: Implementation complete — documentation is in place; feature-manager integration, skills, shared fixture, and lab release gate pending
