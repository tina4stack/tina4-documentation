# Queues with Producers and Consumers

Tina4 has a light-weight queue mechanism built in using the `litequeue` library which uses an Sqlite3 database as the container for the queue.
For most single instance use cases this is sufficient but if you need to load balance or scale your queue mechanism  need to consider other mechanisms.
We provide default support for `kafka` and `rabbitmq`

## Basic Queue with Litequeue


### Configuration
We start with a queue configuration

```python
from tina4_python.Queue import Config, Queue, Producer, Consumer

config = Config()
config.litequeue_database_name = "test_queue.db"
# config.queue_type = "litequeue,rabbitmq,kafka"
``` 

### Queue and Producer
We initialize the queue and create a producer. Producers are used to produce information and publish it to a queue.

```python
queue = Queue(config, topic="some-queue")
producer = Producer(queue)

# produce some data

producer.produce({"event": "create_log", "log_info": "This is an example of a producer creating a log event"})
```

### Consumer

Typically, our consumer will run in a separate thread / or file or even different application. We need to use the same configuration to initialize the queue.
The consumer has a call_back to process the messages from the queue. The example below is of a manual acknowledgement which is the most complicated form we support.

```python
from tina4_python.Queue import Config, Queue, Consumer

config = Config()
config.litequeue_database_name = "test_queue.db"
# config.queue_type = "litequeue,rabbitmq,kafka"

def queue_message(queue, err, data):
    # We have set acknowledge to false on our consumer so we have to manually acknowledge the message
    if data is not None and data.status == 1:
        queue.done(data.message_id)
        
    print("RESULT", err, data)

queue = Queue(config, topic="some-queue")


# Run a consumer with one-second sleep cycles with manual acknowledgement
consumer = Consumer(queue, queue_message, acknowledge=False)
consumer.run(1)
```

## Rabbitmq Queue

You need to install a Rabbit MQ library and this assumes you have RabbitMQ running successfully.

```bash
poetry add pika
```

### Configuration

The configuration would be as below and you can add extra config keys depending on what is needed.

```python
config = Config()
config.queue_type = "rabbitmq"
config.rabbitmq_config = {"host": "localhost", "port": 5672}
```

## Kafka Queue

You need to install a Kafka library and this assumes you have Kafka running successfully.

```bash
poetry add confluent-kafka
```

### Configuration

The configuration would be as below and you can add extra config keys depending on what is needed.

```python
config = Config()
config.queue_type = "kafka"

# producer minimal config
config.kafka_config  = {
    # User-specific properties that you must set
    'bootstrap.servers': 'localhost:9092',
}

# consumer minimal config
config.kafka_config  = {
    # User-specific properties that you must set
    'bootstrap.servers': 'localhost:9092',
    'group.id': 'default-queue',
    'auto.offset.reset': 'earliest'
}

```

