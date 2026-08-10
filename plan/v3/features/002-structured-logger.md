# Feature 2: Structured logger (JSON/text, rotation)

Audited 2026-07-28. Adversarial contract completed 2026-08-09. Part of
`98-feature-audit.md`. **Decision-complete planning only; implementation and
runner wiring wait for the full audit.**

**Status: CONTRACT COMPLETE.** The normative 3.14 plan and 59-case shared
fixture define a clean-room implementation. The earlier focused fixes remain
verified, but current green language suites do not prove the new contract.

## Decisions superseding the plan below (finalized 2026-08-10)

The owner resolved two decisions on 2026-08-10, overriding the "Approved
2026-08-09" choices below.

- **Decision 8 (threshold scope) -> SEPARATE FILE LEVEL, not one threshold.**
  `TINA4_LOG_LEVEL` gates the console only; a new `TINA4_LOG_FILE_LEVEL` (default
  `ALL`) gates the file, preserving the full-detail forensic file. `is_enabled`
  becomes sink-aware. Add `TINA4_LOG_FILE_LEVEL` (string) to the Decision 19
  environment manifest. Supersedes Decision 8 Option 1.

- **Decision 20 (concurrent writers) -> SINGLE FILE, IN-PROCESS LOCK ONLY.** One
  log file guarded by an in-process (thread) lock over size-check + rotate +
  append. Cross-process exclusive locking and stale-lock recovery are removed;
  concurrent PROCESSES writing the same file may interleave, and the contract
  documents per-process files or a log shipper as the answer for that. The
  concurrency fixture witness relaxes from real multi-process to thread
  concurrency plus the documented caveat. Supersedes Decision 20 Option 1.

Everything else in the plan below stands.

## Files

| | path |
| --- | --- |
| python | `tina4_python/debug/__init__.py` |
| php | `Tina4/Log.php` |
| ruby | `lib/tina4/log.rb` |
| node | `packages/core/src/logger.ts` |

## Adversarial re-audit evidence (2026-08-09)

The earlier audit fixed five real defects. It did not cover the full logger
lifecycle. This pass treats those fixes as evidence, not as proof that Feature 2
has a complete contract.

### Exact-HEAD focused baseline

The lab host `nvidia-rtx4500` ran each focused suite as root against the same
HEADs as the local v3 worktrees. Every suite passed:

| Framework | HEAD | Focused result |
| --- | --- | --- |
| Python | `12cc44bb` | 82 passed |
| PHP | `46f96429` | 91 tests, 217 assertions, 2 deprecations |
| Ruby | `25ac783` | 75 examples, 0 failures |
| Node | `96a5050e` | 85 passed, 0 failed |

Those 333 checks form the compatibility baseline. They do not share one answer
key, and each suite omits behavior that another suite assumes.

### Current public surface

| Concept | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| configure | `configure(log_dir=None, level="info", production=False)` | `configure(logDir=null, development=false, minLevel=null)` | `configure(target=nil)` | `configure(string or {logDir, logFile})` |
| event methods | `debug/info/warning/error/critical(message, **context)` | `debug/info/warning/error/critical(message, context)` | `debug/info/warning/error/critical(message, context)` | `debug/info/warning/error/critical(message, data)` plus `warn` alias |
| threshold query | `is_enabled` | `isEnabled` | `enabled?` | `isEnabled` |
| request ID | module `set_request_id/get_request_id` | `setRequestId/getRequestId` | `set_request_id/get_request_id/clear_request_id` | `setRequestId/getRequestId` |
| lifecycle | none | `reset` | `close_file_logger` | `reset` |
| inspection | none | seven getters | `json_mode?`, `log_dir`, `log_file_path` | none |

This is not one language-neutral surface with idiomatic spelling. A new port
cannot tell which operations belong to Tina4 and which ones leaked from a test
helper.

### Measured contradictions

Each probe used a fresh process and real stdout or files under `/tmp`. No mock
or logger introspection supplied the result.

| Contract edge | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Text stdout with `TINA4_DEBUG` unset contains ANSI | yes | no | yes | no |
| Explicit `TINA4_LOG_OUTPUT=stdout` in debug writes files | `tina4.log`, `error.log` | none | none | `tina4.log`, `error.log` |
| Env level changed after first event | keeps snapshot | keeps snapshot | keeps snapshot | changes on next event |
| `configure(file)` beats conflicting `TINA4_LOG_FILE` | no; env filename becomes a child of the argument path | no; env filename replaces argument filename | yes | yes |
| Explicit file creates `error.log` sibling | no | yes | no | no |
| `ROTATE_SIZE=100`, `KEEP=2`, default file after three 180-char events | no rotation | `.1`, `.2` | `.0` | `.1`, `.2` |
| Null, true, false messages | `"null"`, `"true"`, `"false"` | `""`, `"1"`, `""` | `""`, `"true"`, `"false"` | `""`, `"true"`, `"false"` |
| Circular context in JSON mode | raises after prior startup lines | returns success and writes one blank line | raises | raises and creates no file |

All four also turn one message containing a newline into two physical log
lines. The code calls this a single safe line, but the persisted record has no
event boundary. A user-controlled message can forge the next line of a text log.

### Request-correlation failure

Python stores the request ID in `threading.local`. Ruby and Node store it in one
module or class variable. Two interleaved tasks produced `B, B` in all three
frameworks after task A set `A` and task B set `B`. Python's async server shares
one thread across those tasks, so its thread-local value offers no isolation.

The request pipeline makes the gap wider:

- Python sets the incoming or generated ID at each request start, but does not
  clear it in a `finally` block.
- PHP generates one ID in `App::start()` and keeps it for the app lifetime. It
  does not set a new logger ID for each request.
- Ruby creates an error-page ID but never installs a request ID in the logger.
- Node creates a dispatch `requestId` but never installs it in the logger.

A request ID that crosses request boundaries is worse than no ID. It gives an
operator a confident, false trace.

### Configuration and rotation failures

ADR-0041 fixes the authority order: explicit argument, then environment, then
default. Python and PHP apply that rule to the directory but break it for a file
argument. PHP also creates `error.log` beside an explicitly named single file,
while the other three treat that filename as a one-file instruction.

Python converts the byte rotation threshold into whole megabytes on the default
writer. A 100-byte threshold becomes 1 MB, and zero becomes 10 MB. Ruby delegates
to a standard logger whose backup names start at `.0`. PHP and Node use `.1` for
the newest backup. The same `TINA4_LOG_ROTATE_*` values create different files.

### Resolved Feature 1 dependency

The owner resolved the bootstrap boundary on 2026-08-09. Feature 1 now generates:

```dotenv
TINA4_LOG_LEVEL=ALL
```

Feature 1 returns the native string `"ALL"`, which Feature 2 consumes without
conversion. Square brackets retain their general Feature 1 meaning as list
syntax. Framework log constants remain available to application code, but the
generated setting does not depend on a constant registry.

### Shared-fixture result

`fixtures/logger_contract.json` now contains 59 unique language-neutral cases
across eight invariants, with native inputs, exact event outputs, sink bytes,
file trees, errors, reset state and mutation witnesses. Its SHA-1 is
`1aca82f6e0309f17eb11313334abacf2184509c8`. The generic fixture audit reports
all eight invariants as owed and zero broken. This is honest: no framework runner
executes the cases yet. Each future runner must discover every ID exactly once.

## Owner decision register (re-audit)

### Decision 1: Feature 1 must supply one scalar log level

**Approved 2026-08-09: Option 1, plain scalar name.** Feature 1 generates
`TINA4_LOG_LEVEL=ALL`; its native value is the string `"ALL"`. An OS-level value
still has precedence under Feature 1's source rules.

The approved Feature 1 line uses list syntax, but Feature 2 needs one threshold.
Pick the language-neutral value that crosses this boundary.

1. **Plain scalar name (recommended):** change the generated line to
   `TINA4_LOG_LEVEL=ALL`. Keep the framework constants for application code,
   but do not turn one scalar setting into a one-item collection. Feature 2
   accepts `ALL`, `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` and `NONE` as
   case-insensitive scalar names.
2. **One-item native list:** keep `TINA4_LOG_LEVEL=[TINA4_LOG_ALL]` and require
   the logger to unwrap exactly one item. This preserves the approved template
   but gives one logger setting a collection-shaped input that no engineer
   needs.
3. **Special bracket reference:** make `[TINA4_LOG_ALL]` a scalar reference
   instead of a one-item list. This keeps the text but breaks Feature 1's general
   list grammar for the same token shape.

No option changes OS precedence. An OS-level `TINA4_LOG_LEVEL` still beats the
file assignment under Feature 1's approved source rules.

### Decision 2: when configuration becomes stable

**Approved 2026-08-09: Option 1, stable snapshot.** First use or explicit
`configure` resolves one effective configuration. It stays unchanged until
`reset`. Reset closes owned sinks, clears explicit logger state and request
context, and makes the next use resolve configuration again.

Environment changes after logger initialization can either alter live behavior
or wait for an explicit reset. Pick one lifecycle rule for every language.

1. **Stable snapshot (recommended):** resolve the complete effective
   configuration on first use or explicit `configure`, then keep it unchanged.
   `reset` closes owned sinks, clears explicit logger state and request context,
   and makes the next use resolve configuration again. This makes one event use
   one coherent configuration and follows ADR-0041.
2. **Read on every event:** resolve environment-backed settings for each log
   call. A process can change behavior without reset, but one logger instance
   has no stable configuration and concurrent environment changes can divide a
   request across sinks or formats.
3. **Hybrid lifecycle:** keep explicit settings but re-read selected environment
   values per event. This permits live changes for some fields, but every field
   needs a separate timing rule and the public behavior is harder to predict.

### Decision 3: default output format

**Approved 2026-08-09: Option 1, debug-derived format.** Explicit
`TINA4_LOG_FORMAT` selects `text` or `json`. Without it, truthy `TINA4_DEBUG`
selects text; false or absent `TINA4_DEBUG` selects JSON. Every active sink uses
the same selected format.

The logger needs one language-neutral rule when no explicit format has been
configured. This decision selects the format only; ANSI color is a separate
decision.

1. **Debug-derived format (recommended):** an explicit `TINA4_LOG_FORMAT` value
   selects `text` or `json`. Without it, truthy `TINA4_DEBUG` selects text and a
   false or absent value selects JSON. The selected format applies to every
   active sink, so one event has the same representation on stdout and in files.
2. **Text by default:** use text unless `TINA4_LOG_FORMAT=json` is explicit.
   This favors local readability, but an undeclared production environment does
   not receive structured output.
3. **Sink-specific default:** use text on stdout and JSON in files unless each
   sink has an explicit override. This suits different consumers, but one event
   has two representations and needs per-sink format configuration and tests.

### Decision 4: ANSI color boundary

**Approved 2026-08-09: Option 1, interactive text stdout only.** ANSI color is
valid only for text sent to an interactive terminal. JSON, files, pipes and
captured stdout contain no ANSI bytes.

ANSI escape bytes improve interactive text but damage structured records,
redirected output and file searches. Choose where color is valid.

1. **Interactive text stdout only (recommended):** add ANSI color only when the
   selected format is text and stdout is an interactive terminal. JSON, files,
   pipes and captured stdout contain no ANSI bytes. This preserves readable
   terminals and clean machine-consumed output without a new setting.
2. **Every text stdout:** add ANSI color to text written to stdout even when it
   is redirected or captured. Files and JSON remain plain. This keeps current
   Python and Ruby styling but sends terminal control bytes into pipelines and
   test captures.
3. **No framework color:** never emit ANSI bytes. Output is identical across
   terminals, files and pipelines, but interactive development loses level
   highlighting.

### Decision 5: sink selection

**Approved 2026-08-09: Option 1, output selects sinks.** Explicit `stdout`,
`file` or `both` selects exactly those sinks. When absent, stdout is enabled and
file output follows truthy `TINA4_DEBUG`. `TINA4_LOG_FILE` names a file but does
not enable it. Any other output value is a hard configuration error.

**Container clarification, confirmed 2026-08-09:** false or absent
`TINA4_DEBUG` keeps the default at stdout only. Explicit `both` keeps stdout
working in Docker and also enables bounded Tina4-owned files. Docker detection
does not change sink selection.

Rotation belongs to the file sink. When file output is active, every active
framework-owned log file follows the approved rotation contract. When file
output is inactive, the logger must not create, inspect or rotate log files.

`TINA4_LOG_OUTPUT` currently cannot distinguish an absent value from explicit
`stdout` in Python and Node. The four frameworks also disagree on whether a file
path enables file output. Choose one rule for selecting sinks.

1. **Output selects sinks (recommended):** explicit `stdout`, `file` or `both`
   selects exactly those sinks. When the variable is absent, stdout is enabled
   and file output is enabled only when `TINA4_DEBUG` is truthy. A configured
   `TINA4_LOG_FILE` names the file but does not enable its sink. Any other output
   value is a hard configuration error. This keeps selection separate from
   destination and makes explicit `stdout` reliable.
2. **A file path forces file output:** use the same three output values and
   debug-derived default, but make `TINA4_LOG_FILE` enable file output even when
   output is absent or explicitly `stdout`. This favors a supplied path over the
   sink selector and makes `stdout` mean more than one thing.
3. **Stdout-only default:** explicit `stdout`, `file` or `both` selects exactly
   those sinks; when absent, enable stdout only in every environment. This is
   the smallest default but removes automatic development log files.

### Decision 6: rotation threshold and backup names

**Approved 2026-08-09: Option 1, predict the next record with bounded
retention.** Rotation uses positive byte limits, `.1` is the newest backup, and
retention is finite. Zero or invalid size values and negative or invalid backup
counts are hard configuration errors. There is no unlimited-growth mode.

The rotation settings need byte-exact behavior that does not depend on a
language's standard logging library. The owner added a governing requirement on
2026-08-09: framework-owned logs must never have an unlimited-growth mode.

1. **Predict the next record with bounded retention (recommended):**
   `TINA4_LOG_ROTATE_SIZE` is a positive byte limit. Before appending a complete
   encoded record, rotate a non-empty current file when its size plus that
   record would exceed the limit. Number backups as `.1` newest through `.N`
   oldest, where `N` is the non-negative `TINA4_LOG_ROTATE_KEEP`; zero keeps only
   the current bounded file. Apply the rule independently to each active log
   file. Zero, negative and invalid sizes, and negative or invalid retention
   counts, are hard configuration errors. There is no disabled or unlimited
   mode. Defaults are 10 MiB and five backups. The next decision defines an
   event larger than the cap.
2. **Rotate on the next write:** rotate before a write only when the current file
   has already reached the limit. This also keeps records whole, but a file may
   exceed its configured limit by one normal record. Size remains mandatory and
   positive.
3. **Use each runtime's native rotation:** keep the same settings but accept each
   standard library's trigger point and backup names. This uses less framework
   code but preserves the measured `.0` versus `.1` and byte-unit differences.

### Decision 7: an event larger than the file cap

**Selected 2026-08-09 under the owner's consistency rule: Option 1, bounded
replacement record.** An oversized event is replaced by one bounded valid
record with its level, timestamp, original byte count, SHA-256 digest and a
truncation marker. The original bytes are not written and the ordinary logging
call does not crash the application.

A single serialized event can exceed `TINA4_LOG_ROTATE_SIZE`. Writing it in full
would break the bounded-disk guarantee. Choose the loss behavior explicitly.

1. **Bounded replacement record (recommended):** require a rotation size of at
   least 1024 bytes. If one encoded event exceeds the cap, do not write its
   original bytes. Write one valid text or JSON record within the cap containing
   the original level and timestamp, `truncated=true`, the original byte count,
   its SHA-256 digest and a fixed overflow message. This retains proof of the
   dropped event without risking an unbounded file. The ordinary logging call
   does not crash the application.
2. **Truncate the original fields:** preserve as much message and context as can
   fit, add truncation metadata, and write a valid record. This retains more
   content but requires a byte-aware, format-aware truncation algorithm whose
   result can differ around Unicode and nested structures.
3. **Drop and warn on stderr:** omit the file record and send a short diagnostic
   to stderr. This keeps the file bounded, but repeated oversized events can
   fill Docker's captured stderr and the file contains no witness of the loss.

### Decision 8: threshold scope

**Approved 2026-08-09: Option 1, one threshold for every sink.**
`TINA4_LOG_LEVEL` filters an event before routing. Stdout, the main file and any
secondary file therefore receive the same selected levels. `is_enabled` reports
whether the logger will emit that level to its active sinks. Docker does not
disable stdout when file output is also active.

All four current implementations and project memory agree that
`TINA4_LOG_LEVEL` filters stdout only while the main file records every level.
That preserves full forensic detail, but the setting's name does not reveal its
limited scope and `is_enabled` reports only console visibility. This conflicts
with the simple, no-hidden-behavior principle, so it requires an owner ruling.

1. **One threshold for every sink (recommended for clarity):**
   `TINA4_LOG_LEVEL` filters the event before any sink receives it.
   `is_enabled` answers whether the event will be emitted anywhere. A developer
   gets the same level behavior on stdout and in files.
2. **Keep stdout-only filtering:** `TINA4_LOG_LEVEL` and `is_enabled` govern
   stdout. The main file records every level whenever its sink is active. This
   preserves the current four-language rule and complete file detail, but keeps
   the setting's sink-specific meaning implicit.
3. **Name separate thresholds:** `TINA4_LOG_LEVEL` governs stdout and a new
   `TINA4_LOG_FILE_LEVEL` governs files, defaulting to `ALL`. This preserves the
   current forensic default and makes it explicit, at the cost of another
   setting and a two-answer `is_enabled` API.

### Decision 9: severity ladder and invalid levels

**Selected 2026-08-09 under the owner's consistency rule.** The ordered levels
are `ALL`, `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`, `NONE`.
Configuration is case-insensitive and normalizes to uppercase. `ALL` emits every
event and `NONE` emits none. Event methods remain `debug`, `info`, `warning`,
`error` and `critical` with language-idiomatic casing. There is no `warn` alias.
An unknown configured level is a hard configuration error; it never falls back.

This preserves the five-level rule already shared by all four frameworks,
removes Node's prohibited alias, and follows Feature 1's approved scalar value.

### Decision 10: default file layout and the secondary threshold

**Approved 2026-08-09: Option 1, warning and above.** A directory destination
owns `tina4.log` for every event that passes the global threshold and
`error.log` for passing `WARNING`, `ERROR` and `CRITICAL` events. An explicitly
named file owns only that file. All owned files use bounded rotation.

Three frameworks treat an explicitly named file as one destination, while PHP
also creates a sibling `error.log`. The consistent path rule is therefore
settled: a directory destination owns `tina4.log` and `error.log`; an explicitly
named file owns only that file. Every owned file uses the same global level and
bounded rotation rules.

The remaining threshold for the directory-owned `error.log` contradicts the
earlier audit text:

1. **Warning and above:** write `WARNING`, `ERROR` and `CRITICAL`. This is the
   current behavior in all four frameworks and the stored project rule.
2. **Error and above:** write `ERROR` and `CRITICAL`. This matches the file name
   and the earlier Feature 2 audit pattern.
3. **No secondary file:** write every selected event only to `tina4.log`. This
   removes duplicate bytes but also removes the focused operational file.

### Decision 11: one call produces one physical line

**Selected 2026-08-09 under the owner's consistency rule.** Each accepted log
call writes exactly one LF-terminated physical line to each selected sink. Text
format escapes backslash first, then carriage return as `\r` and line feed as
`\n`. JSON uses its encoder's equivalent escapes. No event may inject a second
physical record, and output uses LF on every operating system.

This closes the measured four-language newline injection defect and makes line
count a reliable event count.

### Decision 12: request correlation lifecycle

**Selected 2026-08-09 under the owner's consistency rule.** Request IDs live in
request, task or async-local context, never process-global or plain
thread-local state. The request pipeline installs the resolved ID before the
first request log and clears it in `finally` after the last request log. An
overlapping request cannot read another request's ID. CLI and background work
may install and clear an explicit ID through the same public methods.

The logger does not decide whether to trust or generate an incoming request ID;
the Request feature owns that policy. Logging consumes the resolved string and
omits the field when no request scope has installed one.

### Decision 13: sink write failures

**Selected 2026-08-09 under the owner's consistency rule.** Configuration
errors fail before logging starts. After configuration succeeds, an ordinary
sink write failure does not crash application work. The logger disables the
failed sink for the current configuration snapshot and emits at most one short,
non-recursive diagnostic to another active sink. `TINA4_LOG_STRICT=true` instead
raises one catchable logging error with the failed sink and operation. `reset`
allows the next configuration snapshot to retry the sink.

This preserves the established default and strict-mode project rule while
preventing a failing sink from producing an unbounded diagnostic loop.

### Decision 14: native message and context normalization

**Selected 2026-08-09 under the owner's consistency rule.** Logging accepts the
shared native value domain without making application code convert values first:
string, null, boolean, finite number, sequence and string-keyed map. A message
string stays a string; other message values use compact JSON spelling, including
`null`, `true` and `false`. Context normalizes recursively and remains a native
map in JSON output. Sequence order is preserved; map keys are sorted by their
UTF-8 byte sequence at every depth so the same value produces the same bytes in
every language.

Valid UTF-8 bytes decode as text. Invalid bytes become a bounded marker with the
byte count and SHA-256 digest. A repeated reference becomes the string
`"[Circular]"`. A non-finite number or value outside the shared native domain
becomes a bounded `"[Unsupported]"` marker. Normalization never calls arbitrary
application stringification hooks and never raises during ordinary logging.

This closes the measured null, boolean and circular-reference differences while
keeping the logger safe around application objects.

### Decision 15: canonical event representation

**Selected 2026-08-09 under the owner's consistency rule.** Every event is
normalized once before routing. Its timestamp is UTC RFC 3339 with exactly
milliseconds and a `Z` suffix. Its level is uppercase.

JSON uses one compact object and this key order:

1. `timestamp`
2. `level`
3. `message`
4. `request_id`, when installed
5. `function`, when caller capture is enabled and resolved
6. `context`, when the normalized map is non-empty

Text uses `TIMESTAMP [LEVEL   ]`, with the uppercase level right-padded to eight
characters, followed by optional `[request_id]` and `[function]`, the message,
and compact JSON context when non-empty. Both formats use the same normalized
values and the one-physical-line rule.

### Decision 16: caller capture

**Selected 2026-08-09 under the owner's consistency rule.** Caller capture is
off by default. Truthy `TINA4_LOG_FUNC` enables it for both formats and every
sink. The logger walks past its own public and private frames and records the
first application function as `function`. If no application frame can be
resolved, the field is omitted. Caller inspection must not make a log call fail.

### Decision 17: explicit configuration surface

**Selected 2026-08-09 under the owner's consistency rule.** Every language
offers one `configure` operation with language-idiomatic named options for
`log_dir`, `log_file`, `level`, `format`, `output`, `rotate_size`, `rotate_keep`
and `strict`. Omitted options read their matching environment setting and then
their framework default. An explicit option beats environment, which beats the
default, as required by ADR-0041. Bootstrap must not pass invented explicit
defaults.

Directory and file are separate concepts; no extension or filesystem-existence
heuristic guesses what one path means. A relative file resolves below the
effective log directory. An absolute file remains absolute. Supplying a file
selects a single file destination but does not enable the file sink. With no
file, the directory destination owns `tina4.log` and `error.log` under Decision
10. Invalid types and values fail configuration before a sink opens.

### Decision 18: reset and observable configuration

**Selected 2026-08-09 under the owner's consistency rule.** Every language
exports language-idiomatic forms of `configure`, `reset`, `is_enabled`,
`set_request_id`, `get_request_id` and `clear_request_id`, plus the five event
methods. `reset` closes and flushes owned handles, clears the stable snapshot and
request context, and is harmless when repeated. The next call resolves a fresh
snapshot.

One `configuration` operation returns a defensive native map of the effective
snapshot, including resolved paths and enabled sinks. It initializes the logger
if needed. This replaces language-specific collections of getters and gives
tests and engineers one ready-to-use shape. No `warn`, production-polarity,
`json_mode`, or file-writer aliases remain in the 3.14 public surface.

### Decision 19: environment manifest and removed spellings

**Selected 2026-08-09 under the owner's consistency rule.** Feature 2 reads only
these logger settings, plus `TINA4_DEBUG` for the approved defaults:

| Setting | Native type | Meaning |
| --- | --- | --- |
| `TINA4_LOG_LEVEL` | string | global severity threshold |
| `TINA4_LOG_FORMAT` | string | `text` or `json` |
| `TINA4_LOG_OUTPUT` | string | `stdout`, `file` or `both` |
| `TINA4_LOG_DIR` | string | directory destination |
| `TINA4_LOG_FILE` | string | optional single-file destination |
| `TINA4_LOG_ROTATE_SIZE` | integer | positive bytes per current file |
| `TINA4_LOG_ROTATE_KEEP` | integer | non-negative backup count |
| `TINA4_LOG_STRICT` | boolean | raise on sink failures |
| `TINA4_LOG_FUNC` | boolean | include application function |

Files always append within their bounded rotation contract. The destructive
`TINA4_LOG_APPEND=false` startup truncation option is removed. A developer who
needs a clean file must perform that explicit operation outside logger startup.

The removed `TINA4_LOG_MAX_SIZE`, `TINA4_LOG_KEEP`, `TINA4_LOG_APPEND`,
`TINA4_DEBUG_LEVEL` and `TINA4_LOG_CRITICAL` settings cause a hard configuration
error with their replacement or removal message. Legacy bracket level spellings
such as `[TINA4_LOG_ERROR]` are invalid; use scalar `ERROR`. Framework severity
constants remain application-code constants and are not extra environment
settings.

### Decision 20: concurrent file writers

**Selected 2026-08-09 under the owner's consistency rule.** Append, size check,
rotation and retention cleanup form one exclusive operation per destination
across threads and processes. The implementation uses standard filesystem
primitives only and leaves no unbounded family of lock or backup files. A
crashed writer's stale lock is recoverable after a bounded interval. Waiting for
the lock is also bounded and follows the ordinary or strict sink-failure policy
when it expires.

The current file and `.1` through `.N` are the only retained data files for one
destination. A concurrent writer must not split an event, overwrite another
event, reset a rotated file, or increase the retention count. Fixture witnesses
must use real concurrent processes, not only threads or mocked writers.

### Decision 21: framework defaults without environment

**Selected 2026-08-09 under the owner's consistency rule.** When neither an
explicit option nor environment setting supplies a value, the snapshot uses:

| Concept | Default |
| --- | --- |
| level | `INFO` |
| format | JSON because absent `TINA4_DEBUG` is false |
| output | stdout only |
| log directory | `logs` below the project root |
| named log file | absent, so directory layout applies if file output is later selected |
| rotation size | 10 MiB (`10485760` bytes) |
| rotation backups | `5` |
| strict sink errors | `false` |
| caller capture | `false` |

Feature 1's generated development file explicitly sets `TINA4_DEBUG=true` and
`TINA4_LOG_LEVEL=ALL`, so a bootstrapped development project receives text and
all five levels. The framework defaults remain safe for a process that logs
before project bootstrap.

### Decision 22: console stream and event bound

**Selected 2026-08-09 under the owner's consistency rule.** When stdout is an
active sink, every passing level writes to stdout and flushes the complete line
before the call returns. Severity does not reroute application events to stderr.
This keeps `docker logs`, shell capture and parity tests on one stream.

One stdout record is limited to 8192 encoded UTF-8 bytes. A larger event uses
the same valid bounded replacement shape as Decision 7, calculated from the
original normalized event. The logger never cuts serialized JSON or a UTF-8
code point. Event frequency and Docker's captured-log retention remain the
container platform's responsibility.

### Decision 23: call completion and input ownership

**Selected 2026-08-09 under the owner's consistency rule.** Event methods
return the language's ordinary void value. Before returning, the logger
normalizes the message and a defensive snapshot of context, applies the global
threshold, and completes each selected synchronous sink write or its failure
policy. Later mutation of caller-owned lists or maps cannot alter an event.

There is no hidden background queue, worker or flush delay in the core logger.
This makes shutdown, tests and short CLI commands deterministic without another
dependency or lifecycle service.

### Decision 24: process lifecycle

**Selected 2026-08-09 under the owner's consistency rule.** Graceful shutdown
calls `reset` after the last application shutdown log. Normal process-exit hooks
may perform a best-effort close but must not emit new events. After a process
fork, the child discards inherited handles, locks and request context, then
resolves a fresh configuration snapshot on first use. The parent snapshot stays
unchanged.

### Decision 25: public errors

**Selected 2026-08-09 under the owner's consistency rule.** Invalid settings
raise one catchable logger configuration error naming the setting, supplied
value and accepted domain. Invalid public method arguments raise a catchable
argument error. Strict sink failures raise one catchable logger write error
naming the sink and operation. No branch terminates the process directly.

Ordinary non-strict sink failures follow Decision 13. Native-value
normalization and caller inspection use their bounded markers or omission rules
instead of raising.

## Normative vanilla implementation plan for structured logging (3.14)

This section is the clean-room contract. A new language implementation must be
possible from this section and the shared fixture without reading another Tina4
runtime. Historical evidence below explains why the rules exist but cannot
override them.

### 1. Purpose and ownership boundary

Feature 2 accepts native application values, creates one normalized event,
filters it once, and routes it to bounded stdout and file sinks. It owns logger
configuration, formatting, request-ID consumption, file rotation, sink failure
policy and reset.

Feature 1 owns environment loading and native conversion. The Request feature
owns request-ID trust and generation. Application bootstrap owns project-root
discovery and calls the logger without invented defaults. Graceful Shutdown owns
the final call to `reset`. Docker or another process supervisor owns retention
of captured stdout.

### 2. Public surface

Use language-idiomatic casing for these concepts and no aliases:

| Concept | Contract |
| --- | --- |
| `configure` | named options: `log_dir`, `log_file`, `level`, `format`, `output`, `rotate_size`, `rotate_keep`, `strict` |
| event methods | `debug`, `info`, `warning`, `error`, `critical`; message plus optional native context map |
| `is_enabled` | true when the supplied valid level passes the global threshold and at least one sink is active |
| request context | `set_request_id`, `get_request_id`, `clear_request_id` |
| `configuration` | defensive native map of the effective stable snapshot |
| `reset` | flush, close, clear snapshot and request context; repeated calls are safe |

Event methods return the ordinary void value. Configuration and reset do not
terminate the process. Remove `warn`, production/development polarity flags,
individual configuration getters and writer-specific close aliases.

### 3. Constants, vocabulary and defaults

The severity order is:

```text
ALL < DEBUG < INFO < WARNING < ERROR < CRITICAL < NONE
```

`ALL` and `NONE` are thresholds, not event methods. Level, format and output
configuration is case-insensitive and stored in canonical lowercase or
uppercase form as appropriate. Unknown tokens fail configuration.

With no explicit option and no environment value, use `INFO`, JSON, stdout,
`<project-root>/logs`, directory file layout, 10485760 rotation bytes, five
backups, non-strict writes and caller capture off. Feature 1's generated
development configuration explicitly changes the level to `ALL`, format through
`TINA4_DEBUG=true`, and file default through that same debug value.

### 4. Configuration algorithm

On explicit `configure`, first event use, `is_enabled`, or `configuration`:

1. For each field, resolve explicit argument, then Feature 1 native environment
   value, then the default. Do not write resolved values back to the environment.
2. Validate every field before creating directories, opening files or changing
   the active snapshot. A failed reconfiguration leaves the earlier snapshot
   usable and unchanged.
3. Derive format: explicit `text` or `json`; otherwise text when
   `TINA4_DEBUG` is true and JSON when false or absent.
4. Derive sinks: explicit `stdout`, `file` or `both` selects exactly those
   sinks. If absent, enable stdout and enable files only when `TINA4_DEBUG` is
   true. A file name never enables a sink.
5. Resolve a relative log directory below the application project root. Resolve
   a relative log file below the effective directory. Preserve an absolute file
   path. No path-shape heuristic is allowed.
6. If no file is named, file mode owns `tina4.log` and `error.log`. If a file is
   named, file mode owns only that file.
7. Build the new immutable snapshot, open its selected sinks, then replace the
   old snapshot and close old handles. Never expose a half-configured snapshot.

Accepted settings and types are exactly those in Decision 19. Size is an integer
from 1024 bytes upward. Backup count is a non-negative integer. Booleans are
native booleans from Feature 1, not private truth-token parsing. Paths must be
non-empty strings without NUL. `configuration` returns a deep copy containing
canonical values, absolute resolved paths and final sink booleans.

### 5. Event algorithm

For every event method:

1. Resolve the stable snapshot if absent.
2. Validate the fixed method level and apply the one global threshold. Return
   immediately when filtered or when no sink is active.
3. Capture one UTC timestamp, request ID and optional application function.
4. Normalize the message and a defensive context copy through the shared native
   normalization rules. Never retain caller-owned mutable data.
5. Build one canonical event and encode it once for the selected format.
6. Escape line-breaking and terminal control input so the event is one physical
   LF-terminated line. JSON must remain valid JSON.
7. Replace an oversized event separately for each sink limit, using the original
   canonical encoded record as the digest input.
8. Write the completed record synchronously to every selected destination and
   apply the sink failure policy. Return only after those writes finish.

All stdout and file destinations receive the same levels. `error.log` receives
the passing subset at `WARNING` and above. File mode never disables stdout when
output is `both`, including inside Docker.

### 6. Native normalization and formats

The shared native domain is string, null, boolean, finite number, sequence and
string-keyed map. Preserve sequence order and sort map keys recursively by UTF-8
bytes. Render message null and booleans as `null`, `true` and `false`; render
non-string messages as compact JSON text. Context remains a map in JSON output
and compact JSON text in text output.

Valid UTF-8 bytes decode to text. Invalid bytes become a marker containing their
length and SHA-256 digest. Replace a repeated reference with `"[Circular]"` and
an unsupported value with `"[Unsupported]"`. Do not invoke arbitrary application
stringification code. Escape backslash, CR and LF in that order for text and use
equivalent JSON escaping. Strip other C0 controls and DEL from text values.

The JSON object key order is `timestamp`, `level`, `message`, optional
`request_id`, optional `function`, optional non-empty `context`. Encode compact
UTF-8 and append one LF. Text is:

```text
TIMESTAMP [LEVEL   ] [optional-request-id] [optional-function] message {optional-context}
```

Right-pad the uppercase level to eight characters. Omit absent optional
segments without leaving doubled spaces. Add ANSI color only around text sent
to an interactive stdout terminal. Never color JSON, files, pipes or captured
stdout.

### 7. Bounded sinks and rotation

Stdout accepts at most 8192 encoded bytes per record and flushes each line. All
levels use stdout, not stderr. Docker retains and rotates captured output; Tina4
does not create a production file unless file output is selected.

For each owned file, hold one cross-thread and cross-process exclusive lock over
the size check, rotation and append:

1. Encode the complete record including LF.
2. If it exceeds the sink limit, replace it with the bounded overflow record.
3. When the non-empty current file plus record would exceed the configured
   size, delete `.N`, shift `.N-1` through `.1` upward, then move the current
   file to `.1`. With retention zero, discard the old current file.
4. Append the complete record to the current file and flush it before releasing
   the lock.

Exact equality does not rotate. `.1` is newest and `.N` oldest. The current file
and configured backups are the only retained data files. Every owned file rotates
independently. There is no disabled rotation or startup truncation mode.

An overflow replacement is valid in the selected format and fits within 1024
bytes. It keeps the original timestamp and level, replaces the message with the
fixed overflow message, omits request/function data, and supplies context keys
`truncated=true`, `original_bytes` and lowercase hexadecimal `sha256`. Digest
and byte count cover the original canonical record including its LF.

### 8. Correlation, reset and process boundaries

Store request IDs in request, task or async-local context. The request pipeline
installs the resolved string before its first log and clears it in `finally`
after its last log. Parallel requests cannot observe each other's IDs. CLI and
background work use the same install and clear operations.

`reset` flushes and closes handles, clears the configuration snapshot and clears
the current execution context's request ID. Graceful shutdown calls it after the
last application shutdown event. A forked child discards inherited logger state
and resolves its own snapshot. No core background writer or delayed flush exists.

### 9. Error taxonomy

Use three catchable categories with language-idiomatic concrete classes:

| Category | Trigger | Required detail |
| --- | --- | --- |
| configuration | invalid setting, removed setting, inaccessible selected sink during configuration | setting or sink, supplied value when safe, accepted domain or failed operation |
| argument | invalid public method argument | method, argument and accepted domain |
| write | selected sink fails after configuration and strict mode is true | sink path/name and failed operation |

In non-strict mode, disable a failed sink for the current snapshot and emit at
most one bounded, non-recursive diagnostic through another active sink. If no
sink remains, return normally. `reset` permits a later retry. Never silently
fall back on malformed configuration.

### 10. Shared parity fixture and implementation order

Create byte-identical `logger_contract.json` copies in the standard fixture
directory of every framework. Each case has a unique ID and language-neutral
`given`, `when`, `then`, `error` and mutation `witness`. Runners must enumerate
every ID exactly once and fail on a missing executor, duplicate, skip, pending
case or unexpected file.

The fixture must cover at least:

- every level against every threshold and active sink combination;
- explicit argument, environment and default precedence for every setting;
- debug-derived format/output and explicit overrides;
- exact JSON/text bytes, ANSI TTY boundary and LF-only records;
- null, booleans, numbers, maps, sequences, Unicode, binary, circular and
  unsupported values;
- embedded CR/LF/control input and defensive context copies;
- directory layout, named-file layout and warning-plus duplication;
- exact-boundary, predictive, zero-retention, oversized and concurrent rotation;
- strict/non-strict directory, open, append, flush, lock and rotation failures;
- overlapping requests, `finally` cleanup, CLI context, reset, reconfigure and
  fork behavior;
- removed names and malformed values failing before filesystem mutation.

Implementation order for another language:

1. Define error classes, constants, configuration schema and immutable snapshot.
2. Implement resolution and validation without opening sinks.
3. Implement request-local state and native normalization.
4. Implement canonical event encoding and bounded overflow replacement.
5. Implement stdout, locked file append and deterministic rotation.
6. Implement public methods, reset, failure policy and process hooks.
7. Wire every shared fixture row fail-closed, then add runtime-specific tests
   only for language mechanics that do not change public behavior.

The implementation is conformant only when the shared fixture, focused legacy
tests, full framework suite and real multi-process file probes all pass with zero
skips.

## Measurements

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 337 | 25 | 77 | 3.08 | `Log.configure` (16) | 18.7 | 1 error, 2 warn |
| php | 334 | 26 | 81 | 3.12 | `Log.configure` (23) | 17.7 | 2 error, 1 warn |
| ruby | 235 | 26 | 93 | 3.58 | `configure` (22) | 21.5 | 1 error, 2 warn |
| node | 250 | 21 | 80 | 3.81 | `callerName` (16) | 20.7 | 6 warn |

Tightest spread in the audit so far: 1.4x LOC, CC average within 0.7 of each
other. `configure` is the worst function in three of four, which is the shape of
the problem below - all the env resolution piles into one method.

## What differs

Five levels emitted through each framework with `TINA4_DEBUG=true`, same message,
same configured directory.

**D1. PHP emits JSON in development. The other three emit human-readable text.**

```
python  2026-07-28T12:35:23.058Z [INFO   ] msg-info          (coloured)
ruby    2026-07-28T12:35:35.541Z [INFO   ] msg-info          (coloured)
node    2026-07-28T12:35:55.403Z [INFO    ] msg-info         (coloured)
php     {"timestamp":"2026-07-28T12:35:35.154Z","level":"INFO","message":"msg-info"}
```

Core Principle 6 states the rule: "same JSON structure in production, same
human-readable format in dev". PHP breaks the dev half. A developer tailing a PHP
dev log reads JSON while the same app in Python reads as text.

**D2. Node pads the level to 8 characters; Python and Ruby pad to 7.**
`[INFO    ]` versus `[INFO   ]`. Trivial to look at, not trivial in effect: any
log-shipping regex, column split, or grep tuned on one framework's output is off
by one character on another. And Python's own `[CRITICAL]` (8 chars, unpadded)
breaks its own 7-wide column, so Python is internally inconsistent too.

**D3. Ruby writes one log file where Python and PHP write two.**

| | files written (dev) |
| --- | --- |
| python | `tina4.log` + `error.log` |
| php | `tina4.log` + `error.log` |
| ruby | `logs/tina4.log` only - **no `error.log`** |
| node | `tina4.log` only - **no `error.log`** |

Half the family splits errors into their own file and half does not. Anyone whose
alerting tails `error.log` gets silence on Ruby and Node.

**D4. `configure()` has four different signatures, and one pair is inverted.**

| | signature | first arg means |
| --- | --- | --- |
| python | `configure(log_dir="logs", level="info", production=False)` | log directory |
| php | `configure($logDir='logs', $development=false, $minLevel=INFO)` | log directory |
| ruby | `configure(root_dir=Dir.pwd)` | **project root** (appends `logs/`) |
| node | `configure({logDir?, logFile?})` | **options object** |

Three problems in one table:

- Ruby takes a project ROOT and derives `logs/` from it; Python and PHP take the
  log DIRECTORY itself. The identical call `configure("/app")` puts logs in
  `/app/logs/` on Ruby and in `/app/` on Python and PHP. Exactly the
  file-versus-directory class that feature 1 found in `loadEnv`.
- **Python's third parameter is `production` and PHP's second is `development` -
  the same concept with opposite polarity.** `configure(dir, true)` means
  "development" in PHP; the nearest Python equivalent means "production". A port
  from one to the other inverts the behaviour and still runs.
- Node's `configure()` only writes two env vars and accepts no level at all, so
  passing a plain string (the shape the other three take) silently does nothing.
  My first probe did exactly that and produced no log file - my error, but the
  silence is the framework's.

**D5. Node ships `warn` as an alias for `warning`.** From the source: "Backwards-
compat alias for warning()". The no-aliases rule says rename the primary, never
add an alias for parity - and `tina4-nodejs/CLAUDE.md` uses `Log.warn(...)` in its
background-task example, so the docs teach the alias rather than the canonical
name.

**D6. The rest of the surface disagrees on names and on what exists.**

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| threshold check | `is_enabled` | `isEnabled` | `enabled?` | `isEnabled` |
| shut down / reset | `close` | `reset` | `close_file_logger` | (none) |
| clear request id | (none) | (none) | `clear_request_id` | (none) |
| config introspection | (none) | 7 getters: `logDir`, `logFile`, `rotateSize`, `rotateKeep`, `stdoutEnabled`, `fileOutputEnabled`, `isHumanReadable` | `json_mode?`, `production?` | (none) |

Ruby's `enabled?` is correct Ruby (a predicate takes `?`), so that one is category
3 and the surface table absorbs it. `close` versus `reset` versus
`close_file_logger` versus nothing is category 4 - the same concept, three names
and one absence. PHP's seven introspection getters are a real capability the other
three lack, and they are what makes PHP's logger testable without reading a file.

## Verdict: SYNTHESISE

Decided on **correctness for D1 and D3, then SOLID for the `configure` shape.**

Nobody wins. Python and Ruby have the right dev format; PHP has the right
introspection surface and the wrong dev format; Ruby has the leanest code and the
missing `error.log`; Node has the alias, the odd padding, and a `configure` that
cannot set a level.

Every divergence here is category 4. Nothing about JSON-in-dev, an 8-wide pad, a
missing `error.log`, or an inverted boolean is forced by a runtime.

## Pattern

**One format table, one file layout, one `configure` signature.**

Output format, exactly:

- **Dev** (`TINA4_DEBUG` truthy, or `TINA4_LOG_FORMAT=text`):
  `TIMESTAMP [LEVEL] message`, level **left-padded to 8** so `CRITICAL` fits
  without breaking the column, ANSI colour per level (green info, yellow warning,
  red error, magenta critical, dim debug).
- **Production** (default when `TINA4_DEBUG` is falsy, or
  `TINA4_LOG_FORMAT=json`): one JSON object per line with keys in this order:
  `timestamp`, `level`, `message`, `request_id`, `caller`, `context`. Absent
  values are omitted, never emitted as null.
- Timestamps are UTC ISO-8601 with milliseconds and a `Z` suffix in both modes.

Eight, not seven, because it is the only width that fits every level name. Python
and Ruby move by one character; Node is already correct.

File layout, identical everywhere: `<log_dir>/tina4.log` for every level, plus
`<log_dir>/error.log` for `error` and `critical` only. Ruby and Node gain the
split. The dev-gating rule already agreed in 3.13.39 stands: stdout always on, the
file written only when `TINA4_DEBUG` is truthy, unless `TINA4_LOG_OUTPUT` or an
explicit `TINA4_LOG_FILE` forces it.

Surface table:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| configure | `configure(log_dir=None, level=None, production=None)` | `configure($logDir = null, $level = null, $production = null)` | `configure(log_dir: nil, level: nil, production: nil)` | `configure({logDir?, level?, production?})` |
| debug/info/warning/error/critical | snake | camel | snake | camel |
| threshold | `is_enabled(level)` | `isEnabled($level)` | `enabled?(level)` | `isEnabled(level)` |
| request id | `set_request_id` / `get_request_id` / `clear_request_id` | `setRequestId` / `getRequestId` / `clearRequestId` | `set_request_id` / `get_request_id` / `clear_request_id` | `setRequestId` / `getRequestId` / `clearRequestId` |
| shut down | `close()` | `close()` | `close()` | `close()` |
| introspection | `log_dir()`, `log_file()`, `rotate_size()`, `rotate_keep()`, `stdout_enabled()`, `file_output_enabled()`, `human_readable()` | camelCase equivalents | snake_case equivalents | camelCase equivalents |

Four decisions in that table:

1. **`log_dir` is the LOG DIRECTORY in all four.** Ruby's root-plus-`logs/`
   behaviour goes. Breaking for Ruby callers passing a project root.
2. **The flag is `production`, never `development`.** One polarity, matching
   Python. PHP's `$development` is renamed, not aliased, and inverting it is a
   `Breaking:` entry with a loud migration note - a silent polarity flip is the
   worst possible failure mode for a config change.
3. **`configure` accepts a level in all four.** Node currently cannot set one.
4. **`close()` everywhere**, replacing `reset` / `close_file_logger` / nothing.
   And **`warn` is deleted** from Node, with the CLAUDE.md example corrected to
   `warning`.

PHP's seven introspection getters are promoted to all four, because they are what
lets the tests below assert configuration without parsing a file.

## Methodology

1. Build the shared format fixture first: a committed table of
   (level, message, mode) to expected line, one file, read by all four suites.
   Timestamps normalised out, the way the Frond render-corpus normalises `0x`
   addresses.
2. Write the tests below in all four. Expect red: PHP on dev format, Python and
   Ruby on the 8-wide pad, Ruby and Node on `error.log`, Ruby on `log_dir`
   semantics, Node on `warn` and on `configure` accepting a level.
3. **Ruby first** (leanest, and it holds two of the divergences), then Node, then
   Python, then PHP last - PHP's `configure` has the highest CC (23) and its
   format change is the largest behavioural move.
4. While in `configure`, split it. It is the worst function in three of four for
   the same reason: env resolution, directory setup, level parsing, format
   selection and rotation config in one method. Target: `resolve_output()`,
   `resolve_level()`, `resolve_format()`, `resolve_rotation()`, each under CC 10,
   with `configure` calling them in order. Same stage-list discipline as feature 6,
   at a much smaller scale.
5. Re-measure. Every `configure` under CC 10; MI improved in all four.

## Tests to write

Real files in a temp directory, real stdout captured. A log file is a file, so
there is nothing to mock.

| pair | positive | negative |
| --- | --- | --- |
| dev format | `dev_mode_emits_human_readable_text` | `dev_mode_does_not_emit_json` - the PHP reproduction |
| prod format | `production_mode_emits_one_json_object_per_line` | `production_mode_does_not_emit_ansi_colour` |
| level column | `every_level_name_fits_the_padded_column` - all five, same width | `no_level_breaks_the_column_alignment` - Python's CRITICAL reproduction |
| level order | `critical_is_the_highest_severity` | `critical_is_not_treated_as_an_error_alias` |
| threshold | `a_level_below_the_threshold_is_suppressed` | `a_level_at_or_above_the_threshold_is_never_suppressed` |
| error file | `error_and_critical_are_written_to_error_log` | `info_is_not_written_to_error_log` - Ruby/Node reproduction |
| log dir | `configure_treats_its_argument_as_the_log_directory` | `configure_does_not_append_a_logs_subdirectory` - Ruby reproduction |
| flag polarity | `production_true_selects_json` | `production_true_does_not_select_text` - catches an inverted flag |
| dev gating | `no_log_file_is_written_when_debug_is_falsy`, `an_explicit_log_file_forces_a_file_in_production` | `stdout_is_never_disabled` |
| surface | `configure_accepts_a_level` - all four | `no_framework_exposes_an_alias_for_a_level_method` - kills Node's `warn` |
| fixture parity | `all_four_frameworks_match_the_format_fixture` | `no_framework_emits_a_field_the_others_lack` |

The format-fixture pair is the one that closes this permanently. Four independent
format strings drifted to two pads and two formats precisely because no test ever
compared one framework's output line to another's.

## Risks

- **D4's flag polarity is the dangerous change.** Renaming PHP's `$development` to
  `$production` inverts the meaning of an existing positional argument. Any PHP
  caller passing `true` flips from dev to production output. This needs the
  loudest migration note in the batch, and it is worth considering a hard error on
  the old argument name rather than a silent reinterpretation.
- **D1 changes what PHP dev logs look like.** Cosmetic to a human, breaking to any
  tooling that parses PHP dev logs as JSON. `Breaking:` entry.
- **D3 creates a new file** on Ruby and Node. Harmless, but worth a note for
  anyone with log-rotation config.
- Everything else is additive.

## Parked

Not implemented. Recommend mid-queue: no data loss and no security exposure, but
it is cheap (1.4x spread, small files) and it removes a whole class of "why does
the log look different here" friction. Do it after features 6 and 4.
