# Chapter 25: DI Container

## 1. The Problem with Global State

Without dependency injection, your route handlers create their own service instances:

```php
Router::post('/api/orders', function ($request, $response) {
    $db    = new Database(getenv('DATABASE_URL'));
    $mailer = new Mailer(getenv('SMTP_HOST'), getenv('SMTP_PORT'));
    $logger = new Logger('/var/log/app.log');
    // ...
});
```

Every handler creates fresh instances. Configuration is duplicated. Testing requires mocking at the class level. The code is tightly coupled to concrete implementations.

Dependency injection inverts this. You register services once. The container creates and manages them. Handlers receive what they need without knowing how it was constructed.

Tina4 provides a built-in `Container` class. No Reflection-based auto-wiring complexity. Register factories. Retrieve by name. Singletons for shared instances.

---

## 2. Creating a Container

```php
<?php
use Tina4\Container;

$container = new Container();
```

The container is an empty registry. Register services into it. Retrieve them by name.

---

## 3. register() — Transient Services

`register()` stores a factory callable. Each call to `get()` invokes the factory and returns a new instance.

```php
<?php
use Tina4\Container;

$container = new Container();

// Register a factory for a database connection
$container->register('db', function () {
    return new \Tina4\Database(getenv('DATABASE_URL'));
});

// Register a logger
$container->register('logger', function () {
    return new \Psr\Log\NullLogger();
});

// Each get() creates a new instance
$db1 = $container->get('db');
$db2 = $container->get('db');

var_dump($db1 === $db2);   // bool(false) -- different instances
```

Use transient services when you need isolated instances per request or per operation.

---

## 4. singleton() — Shared Instances

`singleton()` stores a factory that runs once. Every call to `get()` returns the same instance.

```php
<?php
use Tina4\Container;

$container = new Container();

// Register as singleton -- created once, reused everywhere
$container->singleton('mailer', function () {
    $mailer = new \Tina4\Messenger();
    $mailer->setHost(getenv('SMTP_HOST'));
    $mailer->setPort((int) getenv('SMTP_PORT'));
    $mailer->setUsername(getenv('SMTP_USER'));
    $mailer->setPassword(getenv('SMTP_PASS'));
    return $mailer;
});

$container->singleton('cache', function () {
    return new \Tina4\Cache(backend: getenv('TINA4_CACHE_BACKEND', 'memory'));
});

// Same instance every time
$m1 = $container->get('mailer');
$m2 = $container->get('mailer');

var_dump($m1 === $m2);   // bool(true) -- same instance
```

Use singletons for services that are expensive to create (database pools, HTTP clients, email configuration) or must share state (caches, event buses).

---

## 5. get() and has()

`get()` retrieves a service by name. `has()` checks existence before retrieving.

```php
<?php
use Tina4\Container;

$container = new Container();
$container->singleton('db', fn() => new \Tina4\Database(getenv('DATABASE_URL')));

// Check before retrieving
if ($container->has('db')) {
    $db = $container->get('db');
}

// Throws \Tina4\ContainerException if name not registered
try {
    $missing = $container->get('nonexistent');
} catch (\Tina4\ContainerException $e) {
    echo $e->getMessage();  // "Service 'nonexistent' is not registered"
}
```

---

## 6. Services Depending on Other Services

Factories receive the container instance as their argument. Use it to resolve dependencies:

```php
<?php
use Tina4\Container;

$container = new Container();

$container->singleton('logger', function () {
    return new \Tina4\Debug();
});

$container->singleton('db', function () {
    return new \Tina4\Database(getenv('DATABASE_URL'));
});

// OrderService depends on db and logger
$container->singleton('order_service', function () use ($container) {
    return new OrderService(
        db:     $container->get('db'),
        logger: $container->get('logger')
    );
});

class OrderService {
    public function __construct(
        private \Tina4\Database $db,
        private \Tina4\Debug $logger
    ) {}

    public function createOrder(array $data): array {
        $this->logger->message("Creating order", TINA4_LOG_INFO, $data);
        // $this->db->execute(...);
        return ['id' => rand(1000, 9999), ...$data];
    }
}

$orders = $container->get('order_service');
$order  = $orders->createOrder(['customer' => 'Alice', 'total' => 59.99]);
```

Services are composed through the container. Each service is unaware of how its dependencies were built.

---

## 7. Binding a Container to Route Handlers

Pass the container into your route handlers via `use`:

```php
<?php
use Tina4\Router;
use Tina4\Container;

// Bootstrap container in app.php or index.php
$container = new Container();

$container->singleton('db', fn() => new \Tina4\Database(getenv('DATABASE_URL')));

$container->singleton('order_service', function () use ($container) {
    return new OrderService($container->get('db'));
});

// Route uses the container
Router::post('/api/orders', function ($request, $response) use ($container) {
    $orderService = $container->get('order_service');
    $body = $request->body;

    $order = $orderService->createOrder([
        'customer' => $body['customer'],
        'items'    => $body['items'],
        'total'    => $body['total']
    ]);

    return $response->json(['order' => $order], 201);
});

Router::get('/api/orders/{id:int}', function ($request, $response) use ($container) {
    $orderService = $container->get('order_service');
    $order = $orderService->findOrder($request->params['id']);

    if ($order === null) {
        return $response->json(['error' => 'Order not found'], 404);
    }

    return $response->json(['order' => $order]);
});
```

---

## 8. reset() — Testing

`reset()` clears all registrations. Use it between test cases to prevent state leakage:

```php
<?php
use Tina4\Container;

// In your test setUp
$container = new Container();
$container->singleton('db', fn() => new MockDatabase());

// Run the test
$service = $container->get('db');
assert($service instanceof MockDatabase);

// Tear down
$container->reset();

// Container is empty again
assert($container->has('db') === false);
```

---

## 9. A Full App Bootstrap

`src/bootstrap.php` — all services registered in one place:

```php
<?php
use Tina4\Container;

$container = new Container();

// Infrastructure
$container->singleton('db', function () {
    return new \Tina4\Database(getenv('DATABASE_URL'));
});

$container->singleton('cache', function () {
    return new \Tina4\Cache(getenv('TINA4_CACHE_BACKEND') ?: 'memory');
});

$container->singleton('queue', function () {
    return new \Tina4\Queue(topic: 'default');
});

$container->singleton('mailer', function () {
    $m = new \Tina4\Messenger();
    $m->setHost(getenv('SMTP_HOST'));
    return $m;
});

// Domain services
$container->singleton('user_service', function () use ($container) {
    return new UserService(
        db:     $container->get('db'),
        mailer: $container->get('mailer'),
        cache:  $container->get('cache')
    );
});

$container->singleton('order_service', function () use ($container) {
    return new OrderService(
        db:    $container->get('db'),
        queue: $container->get('queue')
    );
});

return $container;
```

In `index.php`:

```php
$container = require 'src/bootstrap.php';

// Pass to all routes
require 'src/routes/users.php';
require 'src/routes/orders.php';
```

---

## 10. Gotchas

### 1. Circular dependencies

**Problem:** Service A depends on B, and B depends on A. The container loops forever.

**Cause:** A circular dependency in your service graph.

**Fix:** Introduce a third service that both A and B depend on, or restructure to break the cycle. The container does not detect cycles automatically — you will see a PHP stack overflow.

### 2. Forgetting to use singleton for stateful services

**Problem:** Two calls to `$container->get('mailer')` produce two SMTP connections.

**Cause:** Registered with `register()` instead of `singleton()`.

**Fix:** Use `singleton()` for any service where a single shared instance is correct. Use `register()` only when you explicitly need a new instance each time.

### 3. Not resetting between tests

**Problem:** A singleton registered in test A bleeds into test B.

**Cause:** Tests share the same container instance without calling `reset()`.

**Fix:** Create a fresh `new Container()` or call `$container->reset()` in `setUp()` in each test class.

### 4. Storing request-scoped data in a singleton

**Problem:** User A's request data appears in User B's response.

**Cause:** A singleton service stores per-request state (current user, request context) on the instance itself.

**Fix:** Singletons must be stateless or explicitly scoped. Pass per-request data as method arguments rather than storing it on the service instance.
