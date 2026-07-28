# Feature 2: Structured logger (JSON/text, rotation)

Audited 2026-07-28. Part of `98-feature-audit.md`. **Planning only.**

**Status: CLOSED.** All four verified by execution.

## Files

| | path |
| --- | --- |
| python | `tina4_python/debug/__init__.py` |
| php | `Tina4/Log.php` |
| ruby | `lib/tina4/log.rb` |
| node | `packages/core/src/logger.ts` |

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
