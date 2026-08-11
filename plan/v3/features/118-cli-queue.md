# Feature 118: CLI queue (delegated queue-management command)

## Identity and status

- Matrix identity: 118 - `tina4 queue <work|stats|retry|clear> [topic]`
- Audit state: decision-ready
- Audit note: DELEGATED CLI command. The Rust binary forwards to the framework CLI; the queue ENGINE
  (backends, visibility timeout, lifecycle, dead-letters) is a SEPARATE, already-audited feature (matrix
  089-093, queue cluster). Measured 2026-08-11 from `tina4/src/main.rs` (`delegate_command`) and the four
  framework CLIs (Python `cli/__init__.py:3266` `queue` with subcommands work/stats/retry/clear; PHP
  `bin/tina4php:1428`; Node `bin.ts:388`; Ruby `lib/tina4/cli.rb`).
- Dependencies: `detect::detect_language`, the framework CLI, the queue subsystem.
- Dependants: developers running a worker; operators managing jobs.

- Catalog phase: CLI (delegated to the framework CLI)

## Why this feature exists

`tina4 queue work` runs a worker that drains a topic; `stats` reports pending/reserved/completed counts;
`retry` re-queues failed jobs; `clear` purges. It forwards to the framework CLI, which drives the queue
engine.

## Boundary

This packet owns the delegation and the subcommand-parity question. It does NOT own the queue engine
(backends file/RabbitMQ/Kafka/MongoDB, visibility timeout, dead-letters) - that is the queue subsystem
(features 089-093), which has its own open findings (e.g. the dev-admin lists-a-different-store-than-it-
counts bug in py/php/rb).

## Existing implementation evidence

- Rust forward: `tina4 queue ...` -> `delegate_command` -> `<framework-cli> queue ...`, exit code
  propagated (PHP checks `vendor/`; PHP also has queue subcommands `case 'queue'` at
  `bin/tina4php:1428,1497`).
- Framework CLI: Python `queue` with `_QUEUE_SUBCOMMANDS` = work/stats/retry/clear
  (`cli/__init__.py:3266`); Node `queue` (`bin.ts:388`, its own worker-discovery reading
  `TINA4_SERVICE_DIR`); PHP/Ruby queue entries.

## Public surface contract

`tina4 queue <work|stats|retry|clear> [topic]`. `work` blocks (a long-running worker); `stats`/`retry`/
`clear` are one-shot. The subcommand SET should be identical across the four (CLI-QUEUE-PARITY).

## Inputs and outputs

- Input: the subcommand, an optional topic, and the queue backend from `.env`. Output: forwarded from the
  framework CLI (worker log for `work`; counts for `stats`; exit code propagated).

## Lifecycle and operation graph

1. `tina4 queue work [topic]` -> detect language -> `<framework-cli> queue work [topic]`.
2. The framework resolves the backend, discovers the consumer (per `TINA4_SERVICE_DIR` in Node), and
   runs the consume loop; `stats`/`retry`/`clear` operate on the backend and return.

The queue semantics (visibility timeout, ack, dead-letters) are the engine's; the CLI is a pass-through.

## Configuration and precedence

- Backend via `.env` (`TINA4_QUEUE_BACKEND` and friends), consumer discovery via `TINA4_SERVICE_DIR` -
  read by the framework, not the CLI.

## Failures, side effects and security

- `work` is long-running; its clean shutdown depends on the framework's signal handling (and, when run
  under `tina4 serve`, the CLI's process-group kill). Confirm `tina4 queue work` (standalone) shuts down
  cleanly on SIGTERM.
- `clear` and `retry` MUTATE the queue store; like `seed`, there is no CLI-level production guard.
- The queue engine's known bugs (089-093) surface through this command but are owned there.

## Wire and persistence contract

The CLI persists nothing; the engine persists jobs in the configured backend. `stats` output format
should be uniform across the four (CLI-QUEUE-PARITY) - note the engine bug where dev-admin lists a
different store than it counts (py/php/rb), which can make `stats` misleading.

## Providers and substitutability

The provider is the detected framework CLI plus the queue backend (file/RabbitMQ/Kafka/MongoDB), which is
the engine's substitution axis.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CLI-QUEUE-PARITY | Confirm the four framework CLIs expose the same `queue` subcommand set (work/stats/retry/clear) with the same `stats` output shape, so `tina4 queue <x>` is uniform. | Standardize the subcommand set + `stats` schema across the four framework CLIs; fold into the CLI-command parity fixture. |
| CLI-QUEUE-ENGINE | The queue engine's open findings (visibility timeout, Node Mongo no-ack, and the dev-admin lists-vs-counts mismatch) surface through `tina4 queue`, but are owned by features 089-093. | No action here; track under the queue subsystem. Ensure `stats` reflects the ACTUAL store, not a different one (the 089-093 bug). |
| CLI-QUEUE-SHUTDOWN | Confirm `tina4 queue work` (run standalone, not under `serve`) drains and shuts down cleanly on SIGTERM in all four. | Verify; if a framework's standalone worker does not drain on signal, fix in the queue subsystem. |

## Owner decisions

- CLI-QUEUE-DEC-01 (proposed): standardize the subcommand set + `stats` schema across the four.

## Proposed conformance fixture

Part of the CLI-command parity fixture: with a file-backed queue and a known consumer, assert
`tina4 queue stats` reports the same schema across the four, `retry`/`clear` mutate as expected, and
`work` drains and exits on signal. The engine's own contract (089-093) is separate.

## Integration map

- Dispatch: `main.rs` -> `delegate_command` -> framework CLI `queue`.
- Protocol: `commands --json` (feature 122).
- Engine: the queue subsystem (features 089-093).

## Breaking changes and migration

- Standardizing the `stats` schema is a cosmetic output change to document; subcommand additions are
  additive.

## Implementation backlog

1. Standardize the `queue` subcommand set + `stats` schema across the four framework CLIs.
2. Verify standalone `work` clean shutdown; fix in the engine if needed.
3. Add the queue entry to the CLI-command parity fixture.

## Porting capsule

Nothing to port in the Rust CLI (forward). Each framework CLI needs a `queue` command with
work/stats/retry/clear subcommands over the queue engine, a uniform `stats` schema, and a `work` loop
that drains on signal. The Rust forward detects the language and propagates the exit code.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Delegation + subcommand parity recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed test cases complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
