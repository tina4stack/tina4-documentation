# Chapter 37: Complete Feature List

Tina4 PHP ships 45 production-ready features across every layer of a web application. This chapter lists all of them, grouped by category, with a brief description and a PHP snippet for each.

---

## Core HTTP

### 1. Router (GET / POST / PUT / PATCH / DELETE / ANY)

Full HTTP method coverage. Route handlers are plain PHP closures.

```php
use Tina4\Router;

Router::get('/items',           fn($req, $res) => $res->json(['items' => []]));
Router::post('/items',          fn($req, $res) => $res->json(['created' => true], 201));
Router::put('/items/{id:int}',  fn($req, $res) => $res->json(['updated' => true]));
Router::patch('/items/{id:int}',fn($req, $res) => $res->json(['patched'  => true]));
Router::delete('/items/{id:int}',fn($req, $res) => $res->json(['deleted' => true]));
Router::any('/ping',            fn($req, $res) => $res->json(['pong'  => true]));
```

### 2. Path Parameters

Type-safe path segments. `{id:int}`, `{price:float}`, `{name}` (string).

```php
Router::get('/products/{id:int}', function ($req, $res) {
    $id = $req->params['id'];   // integer, validated
    return $res->json(['id' => $id]);
});
```

### 3. Wildcard Routes

Catch-all routes for SPAs, proxies, or custom 404 pages.

```php
Router::get('/app/*', fn($req, $res) => $res->html(file_get_contents('public/index.html')));
```

### 4. Route Grouping

Group related routes under a shared prefix.

```php
use Tina4\RouteGroup;

RouteGroup::prefix('/api/v2', function () {
    Router::get('/users',  fn($req, $res) => $res->json([]));
    Router::post('/users', fn($req, $res) => $res->json([], 201));
});
```

### 5. Route Discovery

Place PHP files in `src/routes/`. Tina4 loads them automatically at startup. No manual require statements.

```
src/
  routes/
    users.php
    orders.php
    products.php
```

### 6. Built-in Server

Zero-config development server. Start with one command.

```bash
tina4 serve
# Listening on http://localhost:7145
```

### 7. Request Object

Full access to method, headers, body, path params, query params, and server vars.

```php
Router::post('/echo', function ($req, $res) {
    return $res->json([
        'method'  => $req->method,
        'body'    => $req->body,
        'params'  => $req->params,
        'headers' => $req->headers
    ]);
});
```

### 8. Response Object

Fluent response builder. JSON, HTML, redirect, file, status codes.

```php
return $res->json(['ok' => true], 200);
return $res->html('<h1>Hello</h1>');
return $res->redirect('/login');
return $res->file('/path/to/report.pdf', 'report.pdf');
```

### 9. Static File Serving

Files in `public/` are served automatically. No route needed.

```
public/
  css/tina4.min.css
  js/tina4.min.js
  images/logo.png
```

### 10. CORS Middleware

Origin-aware CORS. Configurable via environment.

```bash
TINA4_CORS_ORIGINS=https://app.example.com,https://admin.example.com
TINA4_CORS_METHODS=GET,POST,PUT,DELETE
```

### 11. Health Endpoint

Built-in `GET /__health`. Returns `{"status":"ok"}`. Ready for load balancer checks.

```bash
curl http://localhost:7145/__health
# {"status":"ok","version":"3.10.55"}
```

---

## Authentication & Security

### 12. JWT Authentication

Zero-dependency JWT. Sign and verify tokens with a secret from the environment.

```php
use Tina4\Auth;

$token = Auth::generateToken(['user_id' => 42, 'role' => 'admin']);
$payload = Auth::verifyToken($token);
```

### 13. Password Hashing

bcrypt hashing. Hash on registration, verify on login.

```php
use Tina4\Auth;

$hash = Auth::hashPassword('userSecret123');
$ok   = Auth::verifyPassword('userSecret123', $hash);   // true
```

### 14. CSRF Protection

Form token generation and middleware validation.

```php
// In a Frond template:
{{ form_token() }}

// In a route handler (middleware):
Router::post('/form', fn($req, $res) => $res->json(['ok' => true]), 'CSRFMiddleware');
```

### 15. Rate Limiter

Per-IP or per-user request throttling. Configured via middleware.

```php
Router::post('/api/login', fn($req, $res) => $res->json([]), 'RateLimit:10:60');
// Max 10 requests per 60 seconds
```

### 16. Security Headers

Adds `X-Frame-Options`, `X-Content-Type-Options`, `Strict-Transport-Security`, and `Content-Security-Policy` headers.

```php
Router::get('/secure', fn($req, $res) => $res->json(['data' => []]), 'SecurityHeaders');
```

### 17. Validator

Built-in input validation. Rules for required, type, length, pattern.

```php
use Tina4\Validator;

$v = new Validator($request->body);
$v->required('email')->email();
$v->required('password')->minLength(8);

if (!$v->passes()) {
    return $response->json(['errors' => $v->errors()], 422);
}
```

---

## Database

### 18. URL-Based Multi-Driver Connection

One connection string covers SQLite, PostgreSQL, MySQL, MSSQL, Firebird, MongoDB, and ODBC.

```php
use Tina4\Database;

$db = new Database('sqlite:./data/app.db');
$db = new Database('pgsql://user:pass@host:5432/dbname');
$db = new Database('mysql://user:pass@host:3306/dbname');
```

### 19. Query Execution

`execute()`, `fetchOne()`, `fetchAll()` with named parameters.

```php
$db->execute("INSERT INTO products (name, price) VALUES (:name, :price)",
    ['name' => 'Widget', 'price' => 9.99]);

$product = $db->fetchOne("SELECT * FROM products WHERE id = :id", ['id' => 1]);
$all     = $db->fetchAll("SELECT * FROM products WHERE active = 1");
```

### 20. Query Caching

Cache identical queries. Controlled by environment.

```bash
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=300
```

### 21. Race-Safe Sequence (get_next_id)

Atomic ID generation without race conditions. Safe for concurrent workers.

```php
$nextId = $db->getNextId('orders');
```

### 22. Transactions

Explicit transaction control. Autocommit is off unless the environment overrides it.

```php
$db->beginTransaction();
try {
    $db->execute("UPDATE accounts SET balance = balance - :amt WHERE id = :id", ['amt' => 100, 'id' => 1]);
    $db->execute("UPDATE accounts SET balance = balance + :amt WHERE id = :id", ['amt' => 100, 'id' => 2]);
    $db->commit();
} catch (\Throwable $e) {
    $db->rollback();
    throw $e;
}
```

---

## ORM

### 23. Active Record

Models map to tables. `save()`, `load()`, `delete()`.

```php
use Tina4\ORM;

class Product extends ORM {
    public int $id = 0;
    public string $name = '';
    public float $price = 0.0;
    public bool $active = true;
}

$p = new Product();
$p->name = 'Keyboard';
$p->price = 79.99;
$p->save();

$found = (new Product())->load(['id' => 1]);
```

### 24. QueryBuilder

Fluent SQL construction. Chainable methods.

```php
$results = (new Product())
    ->query()
    ->where('active', '=', 1)
    ->where('price', '<', 100)
    ->orderBy('name', 'ASC')
    ->limit(20)
    ->get();
```

### 25. Relationships

`hasMany`, `hasOne`, `belongsTo` declared on model classes.

```php
class Order extends ORM {
    public function items(): array {
        return $this->hasMany(OrderItem::class, 'order_id');
    }
}

$order = (new Order())->load(['id' => 1]);
$items = $order->items();
```

### 26. AutoCRUD

Generate REST endpoints from a model in one line.

```php
Product::autoCrud('/api/products');
// GET    /api/products       — list
// GET    /api/products/{id}  — fetch
// POST   /api/products       — create
// PUT    /api/products/{id}  — update
// DELETE /api/products/{id}  — delete
```

### 27. Soft Delete

Mark records as deleted without removing them from the database.

```php
class Order extends ORM {
    protected bool $softDelete = true;
}

$order->delete();                // Sets deleted_at, not removed
$active = (new Order())->all();  // Excludes soft-deleted rows
```

---

## Template Engine (Frond)

### 28. Twig-Compatible Syntax

Block inheritance, includes, loops, conditions, filters.

```twig
{% extends "layout.html" %}
{% block content %}
  {% for product in products %}
    <p>{{ product.name }} — {{ product.price | number_format(2) }}</p>
  {% endfor %}
{% endblock %}
```

### 29. Custom Filters and Functions

Extend Frond with PHP callables.

```php
use Tina4\Frond;

Frond::addFilter('currency', fn($amount, $symbol = '$') => $symbol . number_format($amount, 2));
```

```twig
{{ product.price | currency('€') }}
```

### 30. Fragment Caching

Cache template fragments to avoid re-rendering.

```twig
{% cache 'featured-products' 300 %}
  {% for p in featured %}
    <div class="card">{{ p.name }}</div>
  {% endfor %}
{% endcache %}
```

---

## APIs and Protocols

### 31. API Client

Call external APIs. No Guzzle. No Composer.

```php
use Tina4\Api;

$api = new Api('https://api.example.com');
$api->addCustomHeaders(['Authorization' => 'Bearer ' . getenv('API_TOKEN')]);
$result = $api->sendRequest('GET', '/resources');
```

### 32. Swagger / OpenAPI

Auto-generate API docs from PHPDoc annotations.

```php
/**
 * @route GET /api/products
 * @summary List all products
 * @response 200 array of products
 */
Router::get('/api/products', fn($req, $res) => $res->json([]));
```

Visit `/__swagger` to view the interactive docs.

### 33. GraphQL

Zero-dependency GraphQL engine. Type definitions and resolvers in PHP.

```php
use Tina4\GraphQL;

GraphQL::type('Product', ['id' => 'Int', 'name' => 'String', 'price' => 'Float']);
GraphQL::query('products', 'Product', fn() => getAllProducts());
GraphQL::mount('/graphql');
```

### 34. WebSocket

Real-time bidirectional communication. Backplane for multi-server scale.

```php
use Tina4\WebSocket;

WebSocket::on('message', function ($client, $message) {
    WebSocket::broadcast(['type' => 'chat', 'text' => $message]);
});
```

### 35. SSE / Streaming

Server-Sent Events for real-time data push. Pass a generator callable to `response->stream()`.

```php
Router::get('/events', function ($req, $res) {
    $res->stream(function () {
        while (true) {
            yield "data: " . json_encode(['time' => date('c')]) . "\n\n";
            sleep(1);
        }
    });
});
```

### 36. WSDL / SOAP

Auto-generate WSDL from annotated PHP classes.

```php
use Tina4\WSDL;

class PaymentService extends WSDL {
    /** @wsdl_operation */
    public function Charge(float $amount, string $currency): string {
        return 'txn_' . uniqid();
    }
}

Router::soap('/payment', new PaymentService());
```

---

## Real-time and Messaging

### 37. Messenger (Email)

SMTP email with attachments. Configurable via environment.

```php
use Tina4\Messenger;

Messenger::send(
    to:      'alice@example.com',
    subject: 'Your Order',
    body:    'Order #1234 has shipped.'
);
```

---

## Queue

### 38. Queue System

File, RabbitMQ, Kafka, and MongoDB backends. Same API for all.

```php
use Tina4\Queue;

$queue = new Queue(topic: 'emails');
$queue->push(['to' => 'alice@example.com', 'subject' => 'Hi']);

foreach ($queue->consume('emails') as $job) {
    sendEmail($job->payload);
    $job->complete();
}
```

---

## Sessions

### 39. Session Handlers

File, database, Redis, Valkey, and MongoDB backends.

```bash
TINA4_SESSION_HANDLER=redis
TINA4_SESSION_HOST=localhost
TINA4_SESSION_TTL=3600
```

```php
use Tina4\Session;

Session::set('user_id', 42);
$id = Session::get('user_id');
Session::destroy();
```

---

## Infrastructure

### 40. Migrations

Versioned database schema migrations. Run via CLI.

```bash
tina4 migrate
tina4 migrate --rollback
```

```php
// migrations/0001_create_products.php
return [
    'up'   => "CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price REAL)",
    'down' => "DROP TABLE products"
];
```

### 41. Localization (I18n)

JSON locale files. Dot-notation keys. Interpolation. Fallback.

```php
use Tina4\I18n;

$i18n = new I18n('src/locales', defaultLocale: 'en');
$i18n->setLocale('de');
echo $i18n->t('welcome', ['name' => 'Alice']);
// Willkommen, Alice!
```

### 42. Events (Observer Pattern)

`on()`, `once()`, `off()`, `emit()`. Priority dispatch.

```php
use Tina4\Events;

Events::on('order.placed', fn($data) => sendConfirmation($data['email']), 10);
Events::emit('order.placed', ['email' => 'alice@example.com', 'total' => 59.99]);
```

### 43. Structured Logging

Log levels. JSON output. Context fields. Env-controlled level filter.

```php
use Tina4\Debug;

Debug::message("Payment failed", TINA4_LOG_ERROR, [
    'user_id'   => 42,
    'amount'    => 99.00,
    'gateway'   => 'stripe',
    'error_code' => 'insufficient_funds'
]);
```

### 44. DI Container

`register()`, `singleton()`, `get()`, `has()`, `reset()`.

```php
use Tina4\Container;

$container = new Container();
$container->singleton('db', fn() => new \Tina4\Database(getenv('DATABASE_URL')));
$db = $container->get('db');
```

### 45. Service Runner

Long-running background workers. Supervisor and systemd compatible.

```php
use Tina4\ServiceRunner;
use Tina4\Service;

class HeartbeatWorker extends Service {
    public function run(): void {
        while (true) {
            echo "heartbeat\n";
            sleep(60);
        }
    }
    public function stop(): void {}
}

$runner = new ServiceRunner();
$runner->add(new HeartbeatWorker());
$runner->start();
```

---

## Summary Table

| # | Feature | Category |
|---|---------|----------|
| 1 | Router (GET/POST/PUT/PATCH/DELETE/ANY) | Core HTTP |
| 2 | Path parameters ({id:int}, {price:float}) | Core HTTP |
| 3 | Wildcard routes | Core HTTP |
| 4 | Route grouping | Core HTTP |
| 5 | Route discovery (auto-load src/) | Core HTTP |
| 6 | Built-in server | Core HTTP |
| 7 | Request object | Core HTTP |
| 8 | Response object | Core HTTP |
| 9 | Static file serving | Core HTTP |
| 10 | CORS middleware | Core HTTP |
| 11 | Health endpoint | Core HTTP |
| 12 | JWT authentication | Auth & Security |
| 13 | Password hashing | Auth & Security |
| 14 | CSRF protection | Auth & Security |
| 15 | Rate limiter | Auth & Security |
| 16 | Security headers | Auth & Security |
| 17 | Validator | Auth & Security |
| 18 | URL-based multi-driver connection | Database |
| 19 | Query execution | Database |
| 20 | Query caching | Database |
| 21 | Race-safe sequence (get_next_id) | Database |
| 22 | Transactions | Database |
| 23 | Active Record ORM | ORM |
| 24 | QueryBuilder | ORM |
| 25 | Relationships (hasMany/hasOne/belongsTo) | ORM |
| 26 | AutoCRUD | ORM |
| 27 | Soft delete | ORM |
| 28 | Frond template engine (Twig-compatible) | Templates |
| 29 | Custom filters and functions | Templates |
| 30 | Fragment caching | Templates |
| 31 | API client (zero-dep) | APIs & Protocols |
| 32 | Swagger / OpenAPI | APIs & Protocols |
| 33 | GraphQL engine | APIs & Protocols |
| 34 | WebSocket server | APIs & Protocols |
| 35 | SSE / Streaming (response.stream) | APIs & Protocols |
| 36 | WSDL / SOAP server | APIs & Protocols |
| 37 | Messenger (email) | Messaging |
| 38 | Queue system (4 backends) | Queue |
| 39 | Session handlers (5 backends) | Sessions |
| 40 | Migrations | Infrastructure |
| 41 | Localization (I18n) | Infrastructure |
| 42 | Events (observer pattern) | Infrastructure |
| 43 | Structured logging | Infrastructure |
| 44 | DI Container | Infrastructure |
| 45 | Service Runner | Infrastructure |

All 45 features are at 100% parity across Tina4 PHP, Python, Ruby, and Node.js.
