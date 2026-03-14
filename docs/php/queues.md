# Queues {#queues}

Tina4's queue module provides a multi-backend message queue system with a unified API. It supports **LiteQueue** (SQLite), **MongoDB**, **RabbitMQ**, and **Kafka** backends out of the box.

::: tip Hot tips!
- LiteQueue uses SQLite and requires no external services — perfect for development and single-machine deployments
- All backends share the same `Queue`, `Producer`, and `Consumer` API
- Messages are consumed via PHP generators for memory efficiency
:::

## Installation {#installation}

```bash
composer require tina4stack/tina4php-queue
```

For specific backends, install the relevant extensions or libraries:

| Backend | Requirement |
|---------|-------------|
| LiteQueue | `ext-sqlite3` (included by default) |
| MongoDB | `composer require mongodb/mongodb` |
| RabbitMQ | `composer require php-amqplib/php-amqplib` |
| Kafka | `ext-rdkafka` PHP extension |

## Quick Start {#quick-start}

```php
use Tina4\Queue;

// Create a queue (defaults to LiteQueue with SQLite)
$queue = new Queue(topic: 'my-events');

// Produce a message
$queue->produce('Hello World', userId: 'user123');

// Consume messages
foreach ($queue->consume() as $message) {
    echo $message->data;       // "Hello World"
    echo $message->userId;     // "user123"
    echo $message->messageId;  // UUID7
    echo $message->topic;      // "my-events"
}
```

## Configuration {#configuration}

Use `QueueConfig` to configure the backend and connection settings:

```php
use Tina4\QueueConfig;

$config = new QueueConfig();
$config->queueType = 'litequeue';  // litequeue, mongo-queue, rabbitmq, kafka
$config->prefix = 'myapp_';       // Prefix for topic names
$config->pollInterval = 0.1;      // Base polling interval (seconds)
$config->maxBackoff = 5.0;        // Max exponential backoff (seconds)
```

| Property | Default | Description |
|----------|---------|-------------|
| `queueType` | `'litequeue'` | Backend: `litequeue`, `mongo-queue`, `rabbitmq`, `kafka` |
| `litequeueDatabaseName` | `'queue.db'` | SQLite database file path |
| `prefix` | `''` | Prefix for topic/table/collection names |
| `pollInterval` | `0.1` | Base polling interval in seconds |
| `maxBackoff` | `5.0` | Maximum exponential backoff in seconds |
| `kafkaConfig` | `null` | Kafka connection config array |
| `rabbitmqConfig` | `null` | RabbitMQ connection config array |
| `mongoQueueConfig` | `null` | MongoDB connection config array |
| `rabbitmqQueue` | `'default-queue'` | RabbitMQ queue name |

## Backends {#backends}

### LiteQueue (SQLite) {#litequeue}

The default backend. No external services needed.

```php
$config = new QueueConfig();
$config->queueType = 'litequeue';
$config->litequeueDatabaseName = 'my-queue.db';

$queue = new Queue($config, topic: 'tasks');
```

Messages are stored in an SQLite table per topic with atomic transactions.

### MongoDB {#mongodb}

```php
$config = new QueueConfig();
$config->queueType = 'mongo-queue';
$config->mongoQueueConfig = [
    'host' => 'localhost',
    'port' => 27017,
    'username' => 'user',     // optional
    'password' => 'pass'      // optional
];

$queue = new Queue($config, topic: 'orders');
```

Messages are stored in a `{prefix}_{topic}` collection in the `queue` database. Consumption uses `findOneAndUpdate()` for atomic message reservation.

### RabbitMQ {#rabbitmq}

```php
$config = new QueueConfig();
$config->queueType = 'rabbitmq';
$config->rabbitmqConfig = [
    'host' => 'localhost',
    'port' => 5672,
    'user' => 'guest',
    'password' => 'guest'
];

$queue = new Queue($config, topic: 'notifications');
```

Uses persistent message delivery, topic exchanges, and QOS-based batching.

### Kafka {#kafka}

```php
$config = new QueueConfig();
$config->queueType = 'kafka';
$config->kafkaConfig = [
    'bootstrap.servers' => 'kafka1:9092,kafka2:9092'
];

$queue = new Queue($config, topic: 'logs');
```

Requires the `ext-rdkafka` PHP extension. Consumer group ID defaults to `{prefix}default-queue`.

## Producer {#producer}

The `Producer` class wraps `Queue` with delivery callbacks and exception handling:

```php
use Tina4\{Queue, Producer, QueueException};

$queue = new Queue(topic: 'tasks');

$producer = new Producer($queue, function($backend, ?Exception $error, $response) {
    if ($error) {
        error_log("Delivery failed: " . $error->getMessage());
    }
});

try {
    $msg = $producer->produce('Process order #123', userId: 'admin');
    echo "Sent: " . $msg->messageId;
} catch (QueueException $e) {
    echo "Error: " . $e->getMessage();
}
```

## Consumer {#consumer}

The `Consumer` class supports consuming from one or multiple queues in round-robin fashion:

### Single Queue

```php
use Tina4\{Queue, Consumer};

$queue = new Queue(topic: 'tasks');
$consumer = new Consumer($queue);

// Generator-based (recommended)
foreach ($consumer->messages() as $message) {
    echo "Processing: " . $message->data;
}

// Or blocking callback
$consumer->runForever(function($msg) {
    echo "Got: " . $msg->data;
});
```

### Multiple Queues (Round-Robin)

```php
$emails = new Queue(topic: 'emails');
$notifications = new Queue(topic: 'notifications');

$consumer = new Consumer([$emails, $notifications], acknowledge: true);

foreach ($consumer->messages() as $message) {
    echo "Topic: {$message->topic}, Data: {$message->data}";
}
```

The consumer distributes load fairly across all queues and automatically sleeps with backoff when queues are empty.

## QueueMessage {#message}

Every consumed message is a `QueueMessage` object with read-only properties:

| Property | Type | Description |
|----------|------|-------------|
| `messageId` | `string` | Unique UUID7 identifier |
| `data` | `string` | Message payload |
| `userId` | `?string` | Associated user ID |
| `status` | `int` | 0=pending, 1=processing, 2=acknowledged |
| `timestamp` | `int` | Nanosecond timestamp when created |
| `deliveryTag` | `mixed` | Backend-specific delivery identifier |
| `topic` | `string` | Topic/queue name |

## Acknowledgment {#acknowledgment}

By default, messages are auto-acknowledged on consumption. To handle acknowledgment manually:

```php
// Auto-acknowledge (default)
foreach ($queue->consume(acknowledge: true) as $msg) {
    // Message is acknowledged as soon as it's yielded
}

// Manual acknowledgment
foreach ($queue->consume(acknowledge: false) as $msg) {
    // Process the message first
    processMessage($msg);
    // Then acknowledge (backend-specific)
}
```
