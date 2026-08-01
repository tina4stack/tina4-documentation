# Feature 48: queue backends - PARKED, source mapping only

**Status: NOT AUDITED. This file is a preserved source map, not a finding set.**

Nothing here has been verified against a running broker. Every line below came
from READING the source, and this project's own rule is that reading is not
measurement - the Mongo no-ack bug that shipped for two releases was invisible
to exactly this kind of inspection. Treat every entry as a lead to confirm, not
a result to cite.

Written down because the mapping cost a lot of tokens and would otherwise be
redone from scratch. The audit itself is still owed.

## Why this feature is worth doing properly

The Node MongoDB queue re-delivered every completed job - no ack path at all -
and survived two releases because its tests asserted the generated script's
SHAPE and never ran pop -> complete -> no-redelivery against a real Mongo. One
live run caught it in minutes. That incident is the origin of the project's
absolute no-mock rule.

**So the first task is not behaviour: it is to establish whether the CURRENT
tests exercise real brokers, in every framework.** A queue test still asserting
against a double is a finding in its own right.

## Leads to confirm, worst first

Each of these is a source reading. None is proven.

### Python - Kafka `fail()` appears to have no retry branch

`tina4_python/queue/kafka_backend.py:142-146` reads as:

    def fail(self, job, error=""):
        job.attempts += 1
        if job.attempts >= self._max_retries:
            ... dead_letter ...

with no `else`. If that is what it does, then when a job still has retries left
- the common case - `fail()` does nothing at all: no re-publish, no offset
rewind, no nack. The consumer position has already advanced past the record, so
the job would be silently dropped and never retried.

Compounding it: `attempts` is read back from the message body
(`queue/kafka_backend.py:38`), which is always the pushed `0`, so the
dead-letter branch may only be reachable when `max_retries <= 1`.

**Confirm by:** pushing a job on a real Kafka, failing it once with
`max_retries` above 1, and looking for it afterwards.

### Python - RabbitMQ attempts may never persist, so it may never dead-letter

`basic_nack(requeue=True)` returns the ORIGINAL unmodified body to the queue.
`attempts` lives only in that body and in the transient in-memory `Job`
(`queue/rabbitmq_backend.py:64` reads `result.get("attempts", 0)`). If so,
`attempts >= max_retries` can never trip and a persistently failing job is
redelivered forever.

**Confirm by:** failing the same job more times than `max_retries` against a
real broker and checking whether anything reaches the dead-letter queue.

### Ruby - Kafka appears to have no `complete`, so offsets may never commit

`Job#complete` guards on `respond_to?(:complete)` (`lib/tina4/job.rb:75`). The
Ruby Kafka backend does not appear to define one - its only commit path is
`acknowledge` (`queue_backends/kafka_backend.rb:111-113`), which nothing in
`lib/` calls. With `enable.auto.commit => "false"`, that would mean no offset is
ever committed through the public API and every consumed message is redelivered
on restart or rebalance.

RabbitMQ has a `complete` (`rabbitmq_backend.rb:56-61`) added for exactly this
reason. Kafka may simply not have received the same fix.

**Confirm by:** consuming, completing, restarting the consumer, and seeing
whether the message comes back.

### All four - the single-slot delivery tag

RabbitMQ stores one `@last_delivery_tag` / `_last_delivery_tag` rather than a
per-message map (php `RabbitMQBackend.php:41`, ruby `rabbitmq_backend.rb:46`,
python `queue_backends/rabbitmq_backend.py:94`). Kafka does the same with
`_last_message`. Two pops before an ack would overwrite it, so completing job A
could ack job B. `pop_batch` falls back to sequential `dequeue` on these
backends, which is precisely that pattern.

**Confirm by:** popping two, completing the first, and checking which one the
broker considers acknowledged.

### Cross-cutting: `priority` and `delay_seconds` may be silently dropped

The reading suggests both are accepted and discarded on the three external
backends in PHP and Ruby, and `delay_seconds` on Mongo in Python - stored in the
body but never used as a sort key or a visibility gate. Silent acceptance of an
argument that does nothing is the same disease as `TINA4_CORS_CREDENTIALS` in
Node.

### Cross-cutting: `size(status)` may be meaningless off the file backend

Reading suggests `size()` ignores its status argument for external backends and
returns 0 or a wrong count - Kafka hardcoded to 0 in Python and PHP, Ruby's
Kafka lacking the method entirely (which would raise `NoMethodError` through an
unguarded call at `queue.rb:222`), and PHP's RabbitMQ returning 0 after the
first call because `declareQueue` caches.

### Cross-cutting: management ops may crash or silently no-op

PHP's `Queue::failed()`, `deadLetters()`, `retryFailed()` and `retry()` call
methods that do not appear to exist on the RabbitMQ and Kafka backends, which
would be a runtime `Error`. Ruby guards the same calls with `respond_to?` and so
would degrade silently to `0`/`[]`/`false` instead. Neither is right, and they
are not even wrong in the same way.

Python's `purge`/`clear` appear to always hit the local filesystem regardless of
the configured backend.

## Method note for whoever takes this

Live brokers were confirmed reachable locally when this was parked, so the
no-mock requirement is satisfiable - there is no excuse to skip.

Crash recovery must be tested by actually killing a consumer between `pop()` and
`complete()`, not by simulating it. Kill the process GROUP unconditionally in an
`ensure`/`finally`, since this work deliberately leaves consumers dead.

**ADR-0022** is reserved for this feature.

## Reserved, not decided

No decision has been taken. AMQP 0-9-1's ack model and Kafka's offset-commit
model are the authorities to weigh under ADR-0012, and where a backend genuinely
cannot offer the same guarantee that difference should be RECORDED rather than
forced into false uniformity.
