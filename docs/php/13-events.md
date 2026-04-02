# Chapter 13: Events

## 1. Decouple Your Code

A user registers. You need to send a welcome email, create a default profile, assign a free trial, and log the event. Without events, your registration handler does all of it directly. It grows. It imports five different services. It becomes impossible to test in isolation.

Events invert that. The registration handler emits one event: `user.registered`. Five listeners respond to it independently. Each listener is small, single-purpose, and testable on its own. Adding a sixth action means adding one new listener. No changes to the registration handler.

Tina4 has a built-in events system. No external message broker. No configuration. Zero dependencies.

---

## 2. Listening for Events

Register a listener with `Events::on()`. The listener fires every time the event is emitted.

```php
<?php
use Tina4\Events;

Events::on('user.registered', function (array $data): void {
    echo "Send welcome email to: {$data['email']}\n";
});

Events::on('user.registered', function (array $data): void {
    echo "Create default profile for user {$data['id']}\n";
});
```

Multiple listeners on the same event all run. Registration order is the default execution order.

---

## 3. Emitting Events

Emit an event with `Events::emit()`. Every registered listener for that event fires synchronously in registration order.

```php
<?php
use Tina4\Events;

// Register listeners (usually done at app boot)
Events::on('user.registered', function (array $data): void {
    echo "Welcome email -> {$data['email']}\n";
});

Events::on('user.registered', function (array $data): void {
    echo "Default profile -> user {$data['id']}\n";
});

Events::on('user.registered', function (array $data): void {
    echo "Free trial started for {$data['name']}\n";
});

// Emit the event (usually done inside a route handler or service)
Events::emit('user.registered', [
    'id'    => 42,
    'name'  => 'Alice',
    'email' => 'alice@example.com',
    'plan'  => 'free'
]);
```

Output:

```
Welcome email -> alice@example.com
Default profile -> user 42
Free trial started for Alice
```

All three listeners ran. The emitter does not know they exist.

---

## 4. One-Shot Listeners with once()

`Events::once()` registers a listener that fires exactly once, then removes itself.

```php
<?php
use Tina4\Events;

// This listener fires on the first emit only
Events::once('app.boot', function (): void {
    echo "Database connection pool initialized\n";
});

Events::emit('app.boot');   // Fires: "Database connection pool initialized"
Events::emit('app.boot');   // Nothing -- listener was already removed
Events::emit('app.boot');   // Nothing
```

Useful for one-time initialization, cache warmup, or any setup that must run exactly once regardless of how many times the event fires.

---

## 5. Removing Listeners with off()

`Events::off()` removes a specific listener or all listeners for an event.

```php
<?php
use Tina4\Events;

$auditListener = function (array $data): void {
    echo "Audit log: order {$data['id']} placed\n";
};

// Register
Events::on('order.placed', $auditListener);

// Works
Events::emit('order.placed', ['id' => 101]);
// Output: Audit log: order 101 placed

// Remove this specific listener
Events::off('order.placed', $auditListener);

// Listener no longer fires
Events::emit('order.placed', ['id' => 102]);
// Output: (nothing)
```

Remove all listeners for an event:

```php
Events::off('order.placed');
```

After this call, `Events::emit('order.placed', ...)` fires nothing.

---

## 6. Priority

Listeners with a higher priority run before those with lower priority. Default priority is 0. Pass priority as the third argument to `Events::on()`.

```php
<?php
use Tina4\Events;

Events::on('payment.received', function (array $data): void {
    echo "3. Send receipt email\n";
}, 0);   // Priority 0 -- runs third

Events::on('payment.received', function (array $data): void {
    echo "1. Record payment in ledger\n";
}, 10);  // Priority 10 -- runs first

Events::on('payment.received', function (array $data): void {
    echo "2. Update subscription status\n";
}, 5);   // Priority 5 -- runs second

Events::emit('payment.received', ['amount' => 99.00, 'currency' => 'USD']);
```

Output:

```
1. Record payment in ledger
2. Update subscription status
3. Send receipt email
```

Higher number = higher priority = runs earlier.

---

## 7. Events in Route Handlers

The typical pattern: emit events from route handlers, define listeners in a separate boot file.

**`src/boot/events.php`** — register all listeners at startup:

```php
<?php
use Tina4\Events;

// User events
Events::on('user.registered', function (array $data): void {
    // Send welcome email via Messenger
    \Tina4\Messenger::send(
        to: $data['email'],
        subject: 'Welcome to the app!',
        body: "Hi {$data['name']}, your account is ready."
    );
});

Events::on('user.registered', function (array $data): void {
    // Queue a follow-up drip email for day 3
    $queue = new \Tina4\Queue(topic: 'drip-emails');
    $queue->push([
        'user_id'   => $data['id'],
        'template'  => 'day3-followup',
        'send_at'   => time() + (3 * 86400)
    ]);
});

// Order events
Events::on('order.completed', function (array $data): void {
    error_log("[order] completed: #{$data['id']} total={$data['total']}");
});
```

**`src/routes/users.php`** — emit from the route handler:

```php
<?php
use Tina4\Router;
use Tina4\Events;

Router::post('/api/users/register', function ($request, $response) {
    $body = $request->body;

    if (empty($body['email']) || empty($body['name'])) {
        return $response->json(['error' => 'email and name are required'], 400);
    }

    // Create user (simplified)
    $user = [
        'id'    => rand(1000, 9999),
        'name'  => $body['name'],
        'email' => $body['email'],
        'plan'  => $body['plan'] ?? 'free'
    ];

    // Emit — listeners handle the rest
    Events::emit('user.registered', $user);

    return $response->json([
        'message' => 'Registration successful',
        'user_id' => $user['id']
    ], 201);
});
```

```bash
curl -X POST http://localhost:7146/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}'
```

```json
{
  "message": "Registration successful",
  "user_id": 4721
}
```

The route handler responds immediately. The listeners handle the rest.

---

## 8. Checking Registered Listeners

Inspect which events have listeners (useful in tests and during development):

```php
<?php
use Tina4\Events;

Events::on('order.placed', function (): void {});
Events::on('order.placed', function (): void {});
Events::on('payment.failed', function (): void {});

$count = Events::count('order.placed');     // 2
$all   = Events::listeners();               // ['order.placed' => [...], 'payment.failed' => [...]]
$has   = Events::hasListeners('order.placed'); // true
```

In tests, reset all events between test cases:

```php
Events::reset();
```

---

## 9. Exercise: Order Lifecycle Events

Build an order system where each state change emits an event and multiple listeners respond.

### Requirements

1. Define listeners for: `order.created`, `order.paid`, `order.shipped`
2. Create these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/orders` | Create order, emit `order.created` |
| `POST` | `/api/orders/{id}/pay` | Mark paid, emit `order.paid` |
| `POST` | `/api/orders/{id}/ship` | Mark shipped, emit `order.shipped` |

3. Each event should have at least two listeners (e.g., logging + notification)

### Test with:

```bash
curl -X POST http://localhost:7146/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customer": "Alice", "items": ["Widget A", "Widget B"], "total": 59.98}'

curl -X POST http://localhost:7146/api/orders/1001/pay
curl -X POST http://localhost:7146/api/orders/1001/ship
```

---

## 10. Solution

**`src/boot/order-events.php`:**

```php
<?php
use Tina4\Events;

Events::on('order.created', function (array $order): void {
    error_log("[order] created #{$order['id']} for {$order['customer']}");
}, 10);

Events::on('order.created', function (array $order): void {
    // Notify warehouse
    error_log("[warehouse] new order #{$order['id']} -> " . implode(', ', $order['items']));
}, 5);

Events::on('order.paid', function (array $order): void {
    error_log("[payment] received for order #{$order['id']} — \${$order['total']}");
}, 10);

Events::on('order.paid', function (array $order): void {
    // Trigger fulfillment
    error_log("[fulfillment] queue pick-and-pack for order #{$order['id']}");
}, 5);

Events::on('order.shipped', function (array $order): void {
    error_log("[shipping] order #{$order['id']} dispatched -> {$order['customer']}");
}, 10);

Events::on('order.shipped', function (array $order): void {
    // Send tracking email
    error_log("[email] tracking notification sent for order #{$order['id']}");
}, 5);
```

**`src/routes/orders.php`:**

```php
<?php
use Tina4\Router;
use Tina4\Events;

$orders = [];

Router::post('/api/orders', function ($request, $response) use (&$orders) {
    $body = $request->body;
    $order = [
        'id'       => rand(1000, 9999),
        'customer' => $body['customer'] ?? 'Unknown',
        'items'    => $body['items'] ?? [],
        'total'    => $body['total'] ?? 0,
        'status'   => 'created'
    ];
    $orders[$order['id']] = $order;
    Events::emit('order.created', $order);
    return $response->json(['message' => 'Order created', 'order' => $order], 201);
});

Router::post('/api/orders/{id:int}/pay', function ($request, $response) use (&$orders) {
    $id = $request->params['id'];
    if (!isset($orders[$id])) {
        return $response->json(['error' => 'Order not found'], 404);
    }
    $orders[$id]['status'] = 'paid';
    Events::emit('order.paid', $orders[$id]);
    return $response->json(['message' => 'Order marked as paid', 'order' => $orders[$id]]);
});

Router::post('/api/orders/{id:int}/ship', function ($request, $response) use (&$orders) {
    $id = $request->params['id'];
    if (!isset($orders[$id])) {
        return $response->json(['error' => 'Order not found'], 404);
    }
    $orders[$id]['status'] = 'shipped';
    Events::emit('order.shipped', $orders[$id]);
    return $response->json(['message' => 'Order shipped', 'order' => $orders[$id]]);
});
```

---

## 11. Gotchas

### 1. Listeners fire synchronously

**Problem:** A slow listener blocks the HTTP response.

**Cause:** `Events::emit()` runs all listeners in the same thread before returning. A listener that takes 2 seconds delays the response by 2 seconds.

**Fix:** For slow work (emails, PDF generation), push to a queue inside the listener instead of doing the work inline.

### 2. Uncaught exceptions in listeners crash the emit

**Problem:** One bad listener prevents the remaining listeners from running.

**Cause:** An exception propagates up from the listener and aborts the emit loop.

**Fix:** Wrap listener bodies in try/catch, or register a global error handler on the event system. At minimum, log the error and continue.

### 3. Forgetting to reset in tests

**Problem:** Tests interfere with each other because a listener registered in test A fires during test B.

**Cause:** Events are global state. Listeners accumulate across tests.

**Fix:** Call `Events::reset()` in your test `setUp` or `tearDown` method.

### 4. Using closures with off()

**Problem:** `Events::off('event', $listener)` does not remove the listener.

**Cause:** You registered an anonymous closure inline and are trying to pass a different closure reference to `off()`.

**Fix:** Assign the closure to a named variable before registering it, then pass that same variable to `off()`.
