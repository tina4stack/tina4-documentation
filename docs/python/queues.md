# Queue Usage

::: tip 🔥 Hot Tips
- Default to `litequeue` for local, lightweight queuing—no external services needed.
- For production, configure RabbitMQ, Kafka, or MongoDB backends via `Config` for scalability.
- Always handle callbacks for async delivery/consumption errors.
- Install backends separately: e.g., `uv add litequeue` or `uv add pika` for RabbitMQ.
  :::

## Basic Initialization

Create a queue with default litequeue backend:

```python
from tina4_python.queue import Queue, Config

config = Config()  # Defaults to litequeue with queue.db
queue = Queue(config=config, topic="my-queue")
```

For RabbitMQ (requires running server):

```python
config = Config()
config.queue_type = "rabbitmq"
config.rabbitmq_config = {"host": "localhost", "port": 5672}  # Add username/password if needed
queue = Queue(config=config, topic="my-queue")
```

## Producing Messages

Send a message synchronously:

```python
response = queue.produce("Hello, queue!", user_id="user123")
if isinstance(response, Message):
    print(f"Produced: {response.message_id} with status {response.status}")
else:
    print(f"Error: {response}")
```

With delivery callback:

```python
def delivery_cb(producer, err, msg):
    if err:
        print(f"Delivery error: {err}")
    else:
        print(f"Delivered: {msg.message_id}")

queue.produce("Async message", user_id="user456", delivery_callback=delivery_cb)
```

## Consuming Messages

Consume once (blocking if empty):

```python
def consumer_cb(consumer, err, msg):
    if err:
        print(f"Consume error: {err}")
    else:
        print(f"Consumed: {msg.data} from {msg.user_id} with status {msg.status}")

queue.consume(acknowledge=True, consumer_callback=consumer_cb)
```

Run continuous consumer loop:

```python
from tina4_python.queue import Consumer

consumer = Consumer(queue, consumer_callback=consumer_cb, acknowledge=True)
consumer.run(sleep=0.5)  # Polls every 0.5s; stops on KeyboardInterrupt
```

## Producer/Consumer Wrappers

For decoupled usage:

```python
from tina4_python.queue import Producer, Consumer

producer = Producer(queue, delivery_callback=delivery_cb)
producer.produce("Wrapped produce", user_id="wrapped_user")

# Consumer as above
```

## Multi-Queue Consumer

::: tip 🔥 Hot Tips
- Use the `Consumer` wrapper to poll multiple queues in a single loop.
- Pass a list of `Queue` instances to handle different topics or backends.
- Customize `sleep` for polling frequency; lower values increase responsiveness but CPU usage.
  :::

## Initialization

Create multiple queues and a shared consumer:

```python
from tina4_python.queue import Queue, Config, Consumer

config = Config()  # Shared config, e.g., litequeue backend

queue1 = Queue(config=config, topic="topic-one")
queue2 = Queue(config=config, topic="topic-two")

def consumer_cb(consumer, err, msg):
    if err:
        print(f"Error: {err}")
    else:
        print(f"Consumed from {msg.user_id}: {msg.data}")

consumer = Consumer([queue1, queue2], consumer_callback=consumer_cb, acknowledge=True)
```

## Running the Consumer

Start the loop to consume from all queues:

```python
consumer.run(sleep=0.5)  # Polls every 0.5s; Ctrl+C to stop
```

- The consumer iterates over each queue in sequence per cycle.
- Produce to individual queues as usual; messages are processed via the shared callback.