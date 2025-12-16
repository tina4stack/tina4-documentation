# Queue Usage

::: tip 🔥 Hot Tips
- Default to `litequeue` for local, lightweight queuing—no external services needed.
- For production, configure RabbitMQ, Kafka, or mongo-queue-service backends via `Config`.
- Handle delivery errors in callbacks (especially for Kafka/RabbitMQ).
- Install backends separately: e.g., `uv add litequeue`, `uv add pika` for RabbitMQ, `uv add confluent-kafka` for Kafka, `uv add mongo-queue pymongo` for Mongo.
- Use `prefix` in `Config` for namespacing topics/queues across environments.
  :::

## Basic Initialization

Create a queue with default litequeue backend:

```python
from tina4_python.Queue import Queue, Config

config = Config()  # Defaults to litequeue with 'queue.db'
queue = Queue(config=config, topic="my-queue")
```

For RabbitMQ:

```python
config = Config()
config.queue_type = "rabbitmq"
config.rabbitmq_config = {
    "host": "localhost",
    "port": 5672,
    "username": "guest",  # Optional
    "password": "guest"
}
queue = Queue(config=config, topic="my-queue")
```

For Mongo (mongo-queue-service):

```python
config = Config()
config.queue_type = "mongo-queue-service"
config.mongo_queue_config = {
    "host": "localhost",
    "port": 27017
    # username/password if needed
}
queue = Queue(config=config, topic="my-queue")
```

For Kafka:

```python
config = Config()
config.queue_type = "kafka"
config.kafka_config = {
    "bootstrap.servers": "localhost:9092",
    "group.id": "my-group"
}
queue = Queue(config=config, topic="my-queue")
```

## Producing Messages

Synchronous produce (returns Message or Exception):

```python
from tina4_python.Queue import Message

response = queue.produce("Hello, queue!", user_id="user123")

if isinstance(response, Message):
    print(f"Produced ID: {response.message_id}, data: {response.data}")
else:
    print(f"Error: {response}")
```

With delivery callback (async confirm for supported backends):

```python
def delivery_callback(producer, err, msg):
    if err:
        print(f"Delivery failed: {err}")
    else:
        print(f"Delivered ID: {msg.message_id}")

queue.produce("Async message", user_id="user456", delivery_callback=delivery_callback)
```

Note: Kafka produce is async-only and returns None (callback always used).

## Consuming Messages

`consume()` returns a generator yielding messages:

```python
for msg in queue.consume(acknowledge=True):
    print(f"Consumed: {msg.data} (user_id: {msg.user_id}, status: {msg.status})")
    # Process msg here; ack happens immediately if acknowledge=True
```

Single pull (non-blocking on empty):

```python
gen = queue.consume(acknowledge=True)
try:
    msg = next(gen)
    print(msg.data)
except StopIteration:
    print("No message available")
```

## Producer Wrapper

Decoupled producer:

```python
from tina4_python.Queue import Producer

producer = Producer(queue, delivery_callback=delivery_callback)
response = producer.produce("Wrapped message", user_id="wrapped_user")
```

## Continuous Consumer

Use `Consumer` wrapper for polling single or multiple queues:

```python
from tina4_python.Queue import Consumer

consumer = Consumer(queue, acknowledge=True, poll_interval=0.5)

for msg in consumer.messages():
    print(f"Received: {msg.data}")
    # Process indefinitely; Ctrl+C to stop
```

Or blocking run (logs by default, customize as needed):

```python
consumer.run_forever()  # Logs received messages
```

## Multi-Queue Consumer

::: tip 🔥 Hot Tips
- `Consumer` supports list of queues (mixed backends/topics).
- Polls sequentially; adjust `poll_interval` for latency vs CPU.
- Shared processing logic via one loop.
  :::

```python
queue1 = Queue(config=config, topic="topic-one")
queue2 = Queue(config=config, topic="topic-two")

consumer = Consumer([queue1, queue2], acknowledge=True, poll_interval=0.5)

for msg in consumer.messages():
    print(f"From {msg.topic if hasattr(msg, 'topic') else 'unknown'}: {msg.data}")
```

## Error Handling Example

```python
try:
    queue.produce(None)  # Raises Exception
except Exception as e:
    print(f"Produce error: {e}")

# Empty consume yields nothing
for msg in queue.consume():
    pass  # No messages -> loop exits immediately
```

## Prefix Namespacing

```python
config.prefix = "dev"
queue = Queue(config=config, topic="my-queue")  # Internal name: "dev_my-queue"
print(queue.get_prefix())  # "dev_"
```