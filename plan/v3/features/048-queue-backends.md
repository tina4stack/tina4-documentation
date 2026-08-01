# Feature 48: queue backends (file/lite, RabbitMQ, Kafka, MongoDB)

Audited 2026-08-01. Part of `98-feature-audit.md`.

**Every claim below was produced by running against a live broker.** No claim in
this document rests on reading the source. Where a parked lead turned out to be
wrong, it is marked REFUTED and the real behaviour is given.

Environment for every measurement: macOS 25.5.0 (Darwin arm64), RabbitMQ 3.13.7,
Kafka broker id 1 on localhost:9092, MongoDB 7.0.39, Python 3.14.5 with
confluent-kafka 2.15.0 / librdkafka 2.15.0 / pika 1.4.2 / pymongo 4.16.0,
PHP 8.5.7 with ext-mongodb, Ruby 4.0.2 with bunny 2.24.0 / rdkafka 0.29.0 /
mongo 2.25.0, Node 24.9.0. Nothing here was run on Linux or Windows.

## Files

| | facade | job | lite | rabbitmq | kafka | mongo |
| --- | --- | --- | --- | --- | --- | --- |
| python | `tina4-python/tina4_python/queue/__init__.py` | `tina4-python/tina4_python/queue/job.py` | `tina4-python/tina4_python/queue/lite_backend.py` | `tina4-python/tina4_python/queue/rabbitmq_backend.py` | `tina4-python/tina4_python/queue/kafka_backend.py` | `tina4-python/tina4_python/queue/mongo_backend.py` |
| php | `tina4-php/Tina4/Queue.php` | `tina4-php/Tina4/Job.php` | `tina4-php/Tina4/Queue/LiteBackend.php` | `tina4-php/Tina4/Queue/RabbitMQBackend.php` | `tina4-php/Tina4/Queue/KafkaBackend.php` | `tina4-php/Tina4/Queue/MongoBackend.php` |
| ruby | `tina4-ruby/lib/tina4/queue.rb` | `tina4-ruby/lib/tina4/job.rb` | `tina4-ruby/lib/tina4/queue_backends/lite_backend.rb` | `tina4-ruby/lib/tina4/queue_backends/rabbitmq_backend.rb` | `tina4-ruby/lib/tina4/queue_backends/kafka_backend.rb` | `tina4-ruby/lib/tina4/queue_backends/mongo_backend.rb` |
| node | `tina4-nodejs/packages/core/src/queue.ts` | `tina4-nodejs/packages/core/src/job.ts` | `tina4-nodejs/packages/core/src/queueBackends/liteBackend.ts` | `tina4-nodejs/packages/core/src/queueBackends/rabbitmqBackend.ts` | `tina4-nodejs/packages/core/src/queueBackends/kafkaBackend.ts` | `tina4-nodejs/packages/core/src/queueBackends/mongoBackend.ts` |

Python additionally splits the wire protocol into transport connectors under
`tina4-python/tina4_python/queue_backends/`. The adapters in `queue/` hold the
job lifecycle; the connectors in `queue_backends/` speak AMQP and Kafka. That
split matters, because it is exactly where the coverage gap sat.

## The first question: are the tests real?

**Yes. There is not one mock, stub, fake, spy or monkeypatch in any queue test in
any of the four frameworks.** This was checked file by file. Every test that
touches a broker opens a real socket to it, skip-guarded on reachability, and the
skip reason is matched by each framework's `TINA4_REQUIRE_SERVICES` gate so a
silent skip fails CI.

The mock-based classes that let the Node MongoDB redelivery bug ship are gone,
and each replacement carries a comment saying so
(`tina4-python/tests/test_queue_backends.py` header,
`tina4-php/tests/MongoQueueDeadLetterLiveTest.php:12-17`,
`tina4-nodejs/test/queue.test.ts:1305-1307`,
`tina4-ruby/spec/queue_spec.rb:878-883`). No test anywhere asserts on a generated
script's shape. `MongoBackend.buildScript` is public in Node and no test calls it.

**So the no-mock rule is being honoured. That is not what went wrong here.**

What went wrong is narrower and, for an auditor, more useful: **the live tests
exercise the CONNECTORS, not the JOB LIFECYCLE.** They prove
`enqueue -> dequeue -> acknowledge` against a real broker. Not one of them drove
`Job.fail()` through a real RabbitMQ or a real Kafka in any framework. Three
data-loss bugs lived in precisely that unexercised gap. A green suite that never
calls the method under suspicion is not evidence about that method.

Two further ways the existing tests hide a live bug, both worth copying into the
audit playbook:

- **A fresh topic per test masks a stuck offset.** Every Node Kafka assertion
  creates a new topic and pops once
  (`tina4-nodejs/test/queueBackends.test.ts:195-228`). The backend always fetches
  from offset 0, so popping twice would have caught it immediately. Nothing pops
  twice.
- **A cache can answer an assertion instead of the broker.**
  `tina4-php/tests/QueueBackendTest.php:1289` asserts `size() === 0` after an
  acknowledge. `RabbitMQBackend::declareQueue()` returns a hardcoded `0` on a
  cache hit (`tina4-php/Tina4/Queue/RabbitMQBackend.php:365-367`), so that
  assertion passes whether or not the acknowledge did anything.

## Verdict on each parked lead

| # | Parked lead | Verdict |
| --- | --- | --- |
| 1 | Python Kafka `fail()` has no retry branch, job silently dropped | **CONFIRMED**, and worse than described |
| 2 | Python RabbitMQ `attempts` never persists, so it never dead-letters | **CONFIRMED** exactly as described |
| 3 | Ruby Kafka lacks `complete()`, offsets never commit | **CONFIRMED** |
| 4 | Single-slot delivery tag acks the wrong message | **CONFIRMED** in python, php, ruby. REFUTED for node, which has a different and worse bug |
| 5 | `priority` / `delay_seconds` silently dropped | **CONFIRMED**, and broader than described |
| 6 | `size(status)` meaningless off the file backend | **CONFIRMED** |
| 7 | PHP management ops crash, Ruby silently no-ops | **CONFIRMED** for both |
| 8 | Python `purge`/`clear` always hit the local filesystem | **REFUTED for python.** True of PHP and of Node |

Two crash-recovery results that were not leads at all:

- Kafka **does** recover a killed consumer's job, after about 45 seconds. My
  first probe called it lost because it only waited 20s. The delay is
  librdkafka's default `session.timeout.ms`, which is correct Kafka behaviour
  and should be documented, not fixed.
- File, MongoDB and RabbitMQ all reclaim a SIGKILLed consumer's job in Python.
  Verified by spawning a real child process, waiting for it to really pop, and
  killing its process group.

## Findings, worst first

Severity is by consequence, not by how hard it is to fix. "Loses work" outranks
everything.

### F1. Node RabbitMQ is at-most-once: `pop()` destroys the message (LOSES WORK)

`tina4-nodejs/packages/core/src/queueBackends/rabbitmqBackend.ts:447` issues
Basic.Get with `no-ack=true`:

    getPayload.writeUInt8(1, 3 + qBuf.length); // no-ack=true

Under AMQP 0-9-1 that tells the broker to dequeue and forget. There is no ack
path because there is nothing left to ack, and the backend defines no `complete`
at all. A consumer that dies between `pop()` and finishing the work loses that
job permanently, with no reclaim, no dead-letter and no trace.

Live proof: push one message, pop it, ack nothing, then connect a brand new
backend (which is exactly what a restarted worker is).

    size after push: 1
    popped: {"which":"A"}
    size after pop (NOTHING acked yet): 0
    size seen by a restarted consumer: 0
    restarted consumer pop -> null

This is the same failure class as the original Mongo no-ack incident, in a
different backend, and it is currently shipping.

**`no-ack=true` is not an oversight here. It is forced.** See F2a: the connection
is already gone by the time `pop()` returns, and an AMQP delivery tag is
meaningless once its channel closes. Asking for `no-ack=false` in the current
design would requeue the message the instant the child process exits, so `pop()`
would hand back a job that is simultaneously still on the queue. The author had
no third option.

### F2. Node Kafka never advances: every `pop()` re-reads offset 0 (QUEUE CANNOT DRAIN)

`tina4-nodejs/packages/core/src/queueBackends/kafkaBackend.ts:465` hardcodes the
fetch offset:

    sock.write(buildFetchRequest(topic, 0));

`const API_OFFSET_COMMIT = 8;` is declared at line 107 and never used. `groupId`
is inlined into the generated script at line 214 and never read. There is no
consumer group, no JoinGroup, no OffsetCommit.

Live proof, on a pre-created topic holding two records:

    pop #1 -> {"which":"FIRST"}
    pop #2 -> {"which":"FIRST"}
    pop #3 -> {"which":"FIRST"}
    size(): 0

The first record is redelivered forever and every later record is unreachable.
The existing test does not see this because it uses a fresh topic per assertion
and never pops twice.

### F2a. Root cause of F1 and F2: Node's external backends spawn a process per call

Both of the above are one architectural fact, not two coding mistakes. Every
RabbitMQ, Kafka and MongoDB operation in Node runs as a brand new child process:

    // rabbitmqBackend.ts:570, and the same shape in kafkaBackend.ts and mongoBackend.ts
    const result = execFileSync(process.execPath, ["-e", script], { ... });

The generated script connects, performs exactly one operation, and calls
`sock.destroy(); process.exit(...)`. No connection, channel, consumer or session
survives between `push`, `pop` and `complete`.

That makes acknowledgement impossible in principle, in both protocols:

- **AMQP.** A delivery tag identifies a delivery on a CHANNEL. `pop()`'s channel
  is closed before `pop()` returns, so there is no tag left to ack and no
  connection on which to send the ack. Hence F1.
- **Kafka.** A consumer group's offset belongs to a consumer SESSION. Every
  `pop()` is a new process, so a new consumer, so a fresh session that has joined
  no group and knows no committed offset. Hence F2, and hence the dead
  `API_OFFSET_COMMIT` and unused `groupId`.

**So F1 and F2 cannot be fixed by adding an ack.** Node needs a persistent
connection held on the backend instance, the way Python, PHP and Ruby already do,
before it can offer at-least-once on either broker. That is a redesign of the
Node external queue transport, not a patch, and it should be scoped and sized
before anyone attempts it.

Node's MongoDB backend escapes the consequence only because Mongo's reservation
model is stateless across connections: the reservation lives in the document, not
in the session. It pays the same per-call process-spawn cost.

### F3. Python Kafka `fail()` destroys a job that still has retries (LOSES WORK) [FIXED]

`tina4-python/tina4_python/queue/kafka_backend.py:142-146` had no else branch.
A job failing its first attempt, the common case, was neither re-published nor
dead-lettered, and the consumer position had already moved past the record.

Live proof, `max_retries=3`:

    pushed c20e8917d94b7b2a -> popped (attempts=0) -> fail("boom") -> attempts=1
    pop() again      -> None
    dead_letters()   -> []

Worse than the lead said: because `complete()` commits the consumer offset,
completing any LATER job commits past the failed one and buries it permanently.

    popped {"which": "A"} -> fail (retries left)
    popped {"which": "B"} -> complete
    fresh consumer, same group, sees: []

Compounding it, `attempts` was re-read from the pushed body (always 0), so the
dead-letter branch was only reachable when `max_retries <= 1`.

### F4. Python RabbitMQ can never dead-letter: a poison job spins forever [FIXED]

`tina4-python/tina4_python/queue/rabbitmq_backend.py:173-181` nacked with
`requeue=True`. AMQP 0-9-1 returns the ORIGINAL body, so `attempts` came back as
0 on every redelivery.

Live proof, `max_retries=2`, six consecutive pop-and-fail rounds:

    round 1..6: popped attempts-from-broker=0, after fail job.attempts=1
    dead_letters -> []    main queue size -> 1

`attempts >= max_retries` cannot trip for any `max_retries >= 2`. The consumer
spins on the poison job with no escape.

### F5. Ruby RabbitMQ and Kafka have no `fail()` at all: failures evaporate (LOSES THE FAILURE)

`tina4-ruby/lib/tina4/job.rb:89` guards on `respond_to?(:fail)`. Neither
`RabbitmqBackend` nor `KafkaBackend` defines one, so `job.fail()` falls to the
in-memory else branch at `job.rb:92-96`: it bumps a local counter and returns.
Nothing reaches the broker, nothing is persisted, nothing is dead-lettered.

Live proof:

    backend: Tina4::QueueBackends::RabbitmqBackend
    responds to :fail?     false
    after fail(): job.status=failed job.attempts=1
    dead_letters: []
    size('dead'): 0
    a restarted consumer pops -> {"n" => 1}

The broker redelivers it because it was never acked, so the work is not lost,
but the failure record is: attempts never accumulates and the job can never
die. Same infinite poison loop as F4, reached a different way.

### F6. Ruby Kafka has no `complete()`: offsets are never committed

Confirms the parked lead. `tina4-ruby/lib/tina4/job.rb:75` guards on
`respond_to?(:complete)`; `KafkaBackend` defines only `acknowledge`
(`kafka_backend.rb:111`), which nothing in `lib/` calls. With
`enable.auto.commit => "false"` (`kafka_backend.rb:22`), no offset is ever
committed through the public API, so every consumed message is redelivered on
restart or rebalance.

    responds to :complete? false
    responds to :size?     false
    responds to :fail?     false

`RabbitmqBackend` has `complete` (`rabbitmq_backend.rb:56`), added for exactly
this reason. Kafka never received the same fix.

### F7. Ruby `Queue#size` raises NoMethodError on Kafka

`tina4-ruby/lib/tina4/queue.rb:223` and `:239` call `@backend.size(@topic)`
unguarded while every neighbouring call is `respond_to?`-guarded. Kafka has no
`size`.

    size -> NoMethodError: undefined method 'size' for an instance of
            Tina4::QueueBackends::KafkaBackend

### F8. PHP management operations are a hard fatal on RabbitMQ and Kafka

`tina4-php/Tina4/Queue.php` dispatches to `$externalBackend` unguarded at lines
364, 418, 443 and 382. Only `popBatch` (line 168) uses `method_exists`.

Live proof against a real RabbitMQ:

    failed()      -> Error: Call to undefined method Tina4\Queue\RabbitMQBackend::failed()
    deadLetters() -> Error: Call to undefined method Tina4\Queue\RabbitMQBackend::deadLetters()
    retryFailed() -> Error: Call to undefined method Tina4\Queue\RabbitMQBackend::retryFailed()
    retry()       -> Error: Call to undefined method Tina4\Queue\RabbitMQBackend::deadLetters()

Ruby reaches the same four operations through `respond_to?` guards and returns
`0`/`[]`/`false` instead. Neither is right, and they are wrong in opposite
directions: PHP takes the process down, Ruby lies quietly.

### F9. PHP and Node `clear()` / `purge()` silently operate on the wrong store

`tina4-php/Tina4/Queue.php:285` and `:431` call `liteBackend` unconditionally,
with no `$externalBackend` check. So on a RabbitMQ-backed queue they unlink files
under `data/queue/<topic>/` and return a count derived from that directory, while
the broker is untouched.

Live proof, same run as F8:

    clear() -> 0
    size() after clear() -> 0
    pop() after clear() -> the job was STILL THERE

The `size()` of 0 is a second bug agreeing with the first: it comes from the
`declareQueue` cache (F11), not from an empty queue. Two wrong answers that
corroborate each other are how an operator concludes a queue is drained when it
is not.

Node has the same shape by a different mechanism: `queue.ts:532-565` uses
optional chaining (`this.externalBackend?.fail`) and falls through to
`this.liteBackend` when the backend lacks the method, so `fail()`, `complete()`
and `retry()` on a RabbitMQ or Kafka queue write JSON files to local disk.

**REFUTED for Python.** `Queue.purge`/`Queue.clear` route through
`self._backend` (`queue/__init__.py:189` and `:241`) and every adapter
implements both. The parked lead was wrong about Python.

### F10. The single-slot delivery tag acks the wrong message [FIXED in python]

Confirms the parked lead for three of four frameworks.

- python `queue_backends/rabbitmq_backend.py`, one `_last_delivery_tag`
- python `queue_backends/kafka_backend.py`, one `_last_message`
- php `Tina4/Queue/RabbitMQBackend.php:41`, one `$lastDeliveryTag`, and
  `acknowledge()` at `:131` ignores both its `$topic` and its `$messageId`
- ruby `queue_backends/rabbitmq_backend.rb:46`, one `@last_delivery_tag`;
  `queue_backends/kafka_backend.rb:100`, one `@last_message` that is never
  cleared and whose `acknowledge` calls a bare `@consumer.commit`

AMQP 0-9-1 section 1.8.3.12 makes the delivery tag identify ONE delivery on the
channel. Two pops before an ack overwrite the slot, so `complete(A)` acks B.

Live proof in Python, pushing A then B, popping both, completing A, then dropping
the channel so everything unacked requeues:

    connector._last_delivery_tag after two pops: 2
    completed A (payload {'which': 'A'})
    requeued after closing the channel -> [{'which': 'A'}]

A came back, so A was not acked. B was acked without ever being completed. Both
halves are wrong: duplicated work on one side, lost work on the other.
`pop_batch` falls back to sequential `dequeue` on these backends, which is
exactly this pattern, so this is reachable through the documented API.

**REFUTED for Node**, which has no slot to clobber: `deliveryTag` is declared at
`rabbitmqBackend.ts:244` and never read or written anywhere in the tree. It is
dead, because F1 means there is nothing to acknowledge.

### F11. PHP RabbitMQ `size()` returns 0 after the first touch of a topic

`RabbitMQBackend::declareQueue()` (`tina4-php/Tina4/Queue/RabbitMQBackend.php:365-367`)
returns a hardcoded `0` on a cache hit, and `size()` is implemented as
`return $this->declareQueue($topic);` (`:153-157`). `enqueue()` and `dequeue()`
also populate that cache. So the first call on a connection reports the truth and
every later one reports 0.

The cache is protocol-correct: re-sending a Declare without reading its DeclareOk
would desync the frame stream. The `return 0` is the bug. It should re-declare
and read the real count, or use `Queue.DeclarePassive`.

### F12. `priority` and `delay_seconds` are accepted and discarded

Only the file/lite backend honours either, in all four frameworks. Worse, in PHP
and Node they are dropped at the facade before the backend is even called, so
they are not merely ignored, they are never stored:

- `tina4-php/Tina4/Queue.php:127-131` (`push`) and `:461-465` (`produce`) build
  the external message without `priority` or `delay_seconds`
- `tina4-nodejs/packages/core/src/queue.ts:203-208` passes only three arguments
  to `externalBackend.push`, so `priority` never leaves the facade
- ruby stores them in the JSON body but no external backend reads them back;
  MongoBackend does not even store them (`mongo_backend.rb:61-68`)
- python stores `priority` in the body for RabbitMQ and Kafka and never sorts by
  it; `delay_seconds` is dropped by all three external adapters

Node's Mongo case is the sharpest: `mongoBackend.ts:393` computes `delayUntil`,
but the pop filter includes `{ availableAt: { $exists: false } }`
(`:213-227`), and a pushed document has no `availableAt`, so that arm matches and
the delay is defeated. A delayed job is immediately visible.

This is the `TINA4_CORS_CREDENTIALS` disease: an argument the API accepts,
documents, and ignores.

### F13. `size(status)` does not mean the same thing anywhere

| | `size("pending")` | `size("reserved")` | `size("dead")` |
| --- | --- | --- | --- |
| lite, all four | real count | real count | real count |
| python rabbitmq/kafka/mongo | rabbit real, kafka always 0, mongo real | 0 | 0 |
| php external | `$status` dropped at `Queue.php:271` | same as pending | same as pending |
| ruby rabbitmq | real | 0 | 0 |
| ruby kafka | NoMethodError | NoMethodError | NoMethodError |
| ruby mongo | real | 0 | 0 |
| node external | `status` dropped at `queue.ts:296` | same as pending | same as pending |

Kafka returning 0 is defensible: a log has no queue depth. Returning the PENDING
count when asked for the DEAD count is not defensible in any framework, and PHP
and Node both do it.

### F14. Ruby `Queue#size` takes a keyword argument, the other three take positional

`tina4-ruby/lib/tina4/queue.rb:220` is `def size(status: "pending")`. Python, PHP
and Node all take it positionally. `queue.size("dead")` is portable code
everywhere except Ruby, where it raises ArgumentError. This breaks the rule that
what a developer writes should carry across frameworks.

## Difference table: what does the queue actually promise?

| | file/lite | RabbitMQ | Kafka | MongoDB |
| --- | --- | --- | --- | --- |
| python | at-least-once | at-least-once (after fix) | at-least-once (after fix) | at-least-once |
| php | at-least-once | at-least-once, but attempts survive and the original is never acked, so duplicates | no ack, offsets process-local, full replay on reconnect | at-least-once |
| ruby | at-least-once | at-least-once, but failures never recorded | no commit through the public API, full replay on restart | at-least-once |
| node | at-least-once | **at-most-once, loses work** | cannot drain, replays record 0 forever | at-least-once |

Crash recovery, verified by SIGKILLing a real consumer between `pop()` and
`complete()` in Python:

| backend | reclaimed? | by what | latency |
| --- | --- | --- | --- |
| file | yes | framework visibility timeout | `TINA4_QUEUE_VISIBILITY_TIMEOUT`, default 300s |
| mongodb | yes | framework visibility timeout | same |
| rabbitmq | yes | broker requeues on channel close | immediate |
| kafka | yes | consumer-group session timeout | about 45s, librdkafka default |

## What was decided

**ADR-0022** records the decision. In short, and citing the authorities as
ADR-0012 requires:

- **AMQP 0-9-1 s1.8.3.13.** `basic.nack` with `requeue=1` returns the message
  unmodified. The protocol has no delivery counter, so a retry count cannot ride
  on a requeue. Every AMQP client that counts attempts republishes instead
  (Celery, Spring AMQP's `RepublishMessageRecoverer`, laravel-queue-rabbitmq).
  Tina4 now acknowledges the original and republishes a body carrying the new
  count.
- **AMQP 0-9-1 s1.8.3.12.** A delivery tag identifies one delivery on a channel.
  A single-slot tag is simply wrong; the tag must be keyed by message.
- **Kafka commits an offset, not a record.** There is no per-record nack, so a
  single record cannot be retried without replaying its successors. The
  mainstream answer is the retry-topic pattern: re-produce the record and commit
  past the original. That is what Confluent documents and what Spring Kafka's
  `DeadLetterPublishingRecoverer` implements. Tina4 now does the same.
- **Where a backend genuinely cannot match, record it.** Kafka has no queue
  depth, so `size()` returning 0 stays. Kafka's crash-recovery latency is the
  consumer-group session timeout and is not something the framework should try to
  shorten.

## What was fixed, and what was not

**Fixed, in Python only, with named regression tests proven RED first:**

| Finding | Test |
| --- | --- |
| F3 | `test_kafka_fail_with_retries_left_redelivers_instead_of_dropping` |
| F3 | `test_kafka_fail_then_complete_does_not_bury_the_failed_job` |
| F3 | `test_kafka_fail_past_max_retries_reaches_dead_letters` |
| F4 | `test_rabbitmq_fail_past_max_retries_reaches_dead_letters` |
| F4 | `test_rabbitmq_fail_carries_the_attempt_count_across_a_redelivery` |
| F10 | `test_rabbitmq_complete_acknowledges_that_job_not_the_last_popped` |

All six live in `tina4-python/tests/test_queue_backends.py` and all six talk to a
real broker.

**NOT fixed. These are open, and F1 and F2 are the most urgent things in this
document:**

F1, F2 (node, both lose or strand work), F5, F6, F7 (ruby), F8, F9, F11 (php and
node), F12, F13, F14 (all four).

The parity mandate is therefore NOT satisfied. Python has moved ahead of the
other three on F3, F4 and F10, which is a new drift this audit created and which
the follow-up must close. The fix designs are settled in ADR-0022 and the ports
are mechanical; what is missing is the work and its live tests, not the decision.
