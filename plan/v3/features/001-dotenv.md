# Feature 1: DotEnv parser (.env loading)

Audited 2026-07-28; adversarial contract completed 2026-08-09. Part of
`98-feature-audit.md`. **Decision-complete planning only; implementation waits
for the full audit.** The normative 3.14 contract begins at "Vanilla
implementation plan". Earlier verdict/pattern/test sections and the final
"shipped" record are historical evidence and are superseded where they differ.

## Decisions superseding the plan below (finalized 2026-08-10)

The owner resolved Feature 1's remaining open item on 2026-08-10. Where the
"Vanilla implementation plan" and its owner-decision register below differ, THIS
section wins.

**`.env` structured values use STRICT JSON via each language's built-in parser -
no bespoke parser, no references.** `get_env` decodes a `[...]` or `{...}` value
with the language's standard JSON parser (`json.loads` / `JSON.parse` /
`json_decode` / `JSON.parse`) and returns the native sequence or string-keyed map.
Scalar `${VAR}` string interpolation stays. REMOVED from the contract:
bare-identifier references to framework constants (`ENV=[TINA4_LOG_ALL]`),
parentheses-as-tuples, single-quoted strings inside structures, trailing commas,
the reference dependency graph, and cycle detection. Structure depth and duplicate
map keys follow the language JSON parser's own rules, not a Tina4 depth-64 or
duplicate-key contract. This DISSOLVES the Feature 1 <-> Feature 2 constant-registry
seam: Feature 1 no longer reads a framework-constant registry, and Logging no
longer needs to initialize one before dotenv.

Superseded/rewritten below to strict-JSON + JSON-parser error semantics: the
"Structured values" section, the bare-identifier reference rules in "Parser" and
"Typed coercion", owner decisions 7A-7D, 9, 10, 11, 12, 14, 15, 22 and 24, and
conformance cases `ENV-R04`-`R08` and `ENV-N06`-`N11`. Unchanged: scalar typed
coercion (bool/int/float/null and the +/-9007199254740991 integer range),
`${VAR}` interpolation, source precedence, reset ownership and missing-root
bootstrap.

## Files

| | path |
| --- | --- |
| python | `tina4-python/tina4_python/dotenv/__init__.py` |
| php | `tina4-php/Tina4/DotEnv.php`, `tina4-php/Tina4/Env.php` |
| ruby | `tina4-ruby/lib/tina4/env.rb` |
| node | `tina4-nodejs/packages/core/src/dotenv.ts`, `env.ts` |

## Historical measurements

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 113 | 7 | 29 | 4.14 | `load_env` (17) | 33.5 | 2 warn |
| php | 224 | 16 | 58 | 3.62 | `DotEnv.loadEnv` (20) | 32.2 | 3 warn |
| ruby | 176 | 17 | 46 | 2.71 | - | 25.3 | 1 warn |
| node | 144 | 15 | 45 | 3.0 | `parseEnvContent` (13) | 36.8 | 2 warn |

Leanest python (113), simplest per function ruby (2.71), best MI node (36.8),
spread 2.0x. No errors anywhere. By the numbers this feature looks healthy, which
is exactly why the numbers are not the audit.

## Historical differences

Verified by running all four loaders against one identical `.env`, not by reading.
The file:

```
PLAIN=hello
export EXPORTED=shellstyle
QUOTED="double quoted"
SINGLE='single quoted'
HOST=example.com
INTERP=${HOST}/api
WITH_HASH=value # trailing comment
EMPTY=
```

Results:

| line | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| `PLAIN=hello` | `hello` | `hello` | `hello` | `hello` |
| `export EXPORTED=shellstyle` | `shellstyle` | `shellstyle` | **UNSET** | `shellstyle` |
| `QUOTED="double quoted"` | stripped | stripped | stripped | stripped |
| `SINGLE='single quoted'` | stripped | stripped | stripped | stripped |
| `INTERP=${HOST}/api` | `${HOST}/api` | **`example.com/api`** | `${HOST}/api` | `${HOST}/api` |
| `WITH_HASH=value # trailing comment` | `value` | `value` | **`value # trailing comment`** | `value` |
| `EMPTY=` | `''` | `''` | `''` | `''` |

Three divergences, all silent, all in the component that loads every other
setting.

**D1. Ruby drops `export FOO=bar` lines entirely.** Three frameworks accept the
shell-style prefix; Ruby leaves the variable unset and says nothing. Copying a
`.env` out of a shell profile or a deployment script is routine, and on Ruby the
variable simply is not there. The failure then surfaces somewhere unrelated: a
blank `TINA4_SECRET`, a missing database URL, a feature that silently defaults
off.

**D2. PHP is the only framework that interpolates `${VAR}`.** `INTERP=${HOST}/api`
resolves to `example.com/api` on PHP and stays a literal `${HOST}/api` on the
other three. A `.env` written against PHP produces a broken URL string in Python,
Ruby and Node, and the value looks plausible enough to reach a connection attempt
before failing.

**D3. Ruby does not strip trailing comments.** `WITH_HASH=value # trailing
comment` becomes the whole string on Ruby, `value` on the other three. Same class
of failure: the value is wrong, not absent.

**D4. The signatures disagree, three ways.** This is the owner's naming point in
its most literal form:

| | call | argument |
| --- | --- | --- |
| python | `load_env()` | none (cwd) |
| php | `DotEnv::loadEnv($file)` | a FILE path |
| ruby | `Tina4::Env.load_env($dir)` | a DIRECTORY |
| node | `loadEnv()` | none (cwd) |

Passing a directory to PHP raises `RuntimeException: Cannot read file`. Ruby's is
not reachable as `Tina4.load_env` at all (it lives on the nested `Tina4::Env`
module), so the obvious call fails with `NoMethodError` while the other three
work off the top-level name.

**D5. Capability sets differ beyond the parse.** Ruby is alone in offering typed
getters (`Env.bool`, `Env.int`, `Env.float`, `Env.str`) and
`check_legacy_env_vars!`. Python is alone in handling multiline values. Node and
Python expose `require_env`/`requireEnv`; Ruby's public list does not.

## Historical verdict: SYNTHESISE

Decided on **correctness**. Two of the three divergences are silent wrong-value or
missing-value bugs in Ruby, and the third is a PHP-only capability that makes a
PHP-authored `.env` unportable. Neither "promote Ruby" nor "promote PHP" is right:
Ruby has the best code shape (lowest CC per function) and the worst parser;
PHP has the richest parser and the heaviest code.

Take the **parser behaviour from the union of Python and Node** (they agree on
every line above, and Node has the best MI), add **PHP's `${VAR}` interpolation**
to all four, and keep **Ruby's typed getters** by promoting them everywhere.

## Superseded 2026-07 pattern

**One parser, one behaviour table, four language-idiomatic names.**

Parsing rules, in order, identical in all four:

1. Skip blank lines and lines whose first non-space character is `#`.
2. Strip a leading `export ` (one or more spaces) before the key. Shell-style
   lines are valid input, not an error.
3. Split on the first `=` only. A key with no `=` is skipped with a warning
   naming the line number, never silently.
4. Trim whitespace around the key. Reject a key that is not
   `[A-Za-z_][A-Za-z0-9_]*` with a warning naming the line.
5. Value handling, in this order:
   - a fully double-quoted value keeps its interior verbatim, minus the quotes,
     and processes `\n`, `\t`, `\\` escapes;
   - a fully single-quoted value keeps its interior verbatim, minus the quotes,
     with NO escape processing and NO interpolation (shell semantics);
   - an unquoted value is truncated at the first ` #` (space-hash), then trimmed.
6. `${VAR}` interpolation runs on unquoted and double-quoted values only, against
   already-loaded keys plus the real environment, with an unresolved name left
   literal and warned about once.
7. Precedence is real environment, then `.env.local`, then `.env`, first-wins.
   An empty value is a value: `EMPTY=` sets the empty string, it does not unset.

Surface, per the owner's rule (same names, language-idiomatic casing, same
outcome):

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| load | `load_env(root=None)` | `DotEnv::loadEnv($root = null)` | `Tina4.load_env(root = nil)` | `loadEnv(root?)` |
| get | `get_env(k, default=None)` | `Env::getEnv($k, $d = null)` | `Tina4.get_env(k, default: nil)` | `getEnv(k, d?)` |
| require | `require_env(k)` | `Env::requireEnv($k)` | `Tina4.require_env(k)` | `requireEnv(k)` |
| has | `has_env(k)` | `Env::hasEnv($k)` | `Tina4.has_env?(k)` | `hasEnv(k)` |
| all | `all_env()` | `Env::allEnv()` | `Tina4.all_env` | `allEnv()` |
| reset | `reset_env()` | `Env::resetEnv()` | `Tina4.reset_env` | `resetEnv()` |
| truthy | `is_truthy(v)` | `Env::isTruthy($v)` | `Tina4.truthy?(v)` | `isTruthy(v)` |
| typed | `env_bool/int/float/str` | `Env::bool/int/float/str` | `Tina4.env_bool/...` | `envBool/envInt/...` |

Two contract points in that table:

- **`load` takes a ROOT DIRECTORY in all four, or nothing.** PHP's file-path
  argument is the odd one out and it is the one that throws. A file-path overload
  may stay, but the directory form must exist and must be the documented one.
- **Every helper is reachable from the top-level namespace** (`Tina4.load_env`,
  not only `Tina4::Env.load_env`), because the other three are, and an obvious
  call that raises `NoMethodError` is a parity defect.

## Historical implementation methodology

1. Build the shared behaviour fixture FIRST: one `.env` file, committed once, plus
   one expected-values table. Same bytes, one answer key, all four frameworks read
   it. This is the pattern that worked for the Frond expression corpus.
2. Write the tests below in all four against the fixture. Confirm the expected
   failures: Ruby red on export/comment, three red on interpolation.
3. Fix Ruby's parser (export prefix, trailing comment). Smallest change, biggest
   correctness win, and Ruby's function shape is already the best of the four so
   there is nothing to restructure.
4. Add `${VAR}` interpolation to Python, Ruby and Node, ported from PHP's
   `interpolate`. Single-quoted values must be exempt.
5. Reconcile the signatures: add the directory form to PHP, expose the top-level
   Ruby aliases, add the missing `require_env` to Ruby.
6. Promote the typed getters (Ruby's) to the other three, and
   `check_legacy_env_vars!` if the audit of that feature agrees.
7. Re-measure. The target is no regression in MI and no new offender; this feature
   is currently the healthiest in the batch and must stay that way.

Order: Ruby first (it holds both correctness bugs), then Python, Node, PHP.

## Superseded 2026-07 test proposal

Identical names in all four, driven off the shared fixture. Real files on disk in
a temp directory, real process environment; no mocks (a `.env` is a file, so the
real dependency is trivially available).

| pair | positive | negative |
| --- | --- | --- |
| export prefix | `load_env_reads_an_export_prefixed_line` - `export FOO=bar` sets `FOO=bar` | `load_env_does_not_silently_skip_an_export_line` - `FOO` is never unset after loading a file that declares it |
| trailing comment | `load_env_strips_a_trailing_comment_from_an_unquoted_value` - `value # x` yields `value` | `load_env_does_not_keep_the_comment_in_the_value` - the loaded value contains no `#` |
| quoted values | `load_env_keeps_a_hash_inside_a_quoted_value` - `"a # b"` yields `a # b` | `load_env_does_not_truncate_a_quoted_value_at_a_hash` |
| interpolation | `load_env_expands_a_dollar_brace_reference` - `${HOST}/api` yields `example.com/api` | `load_env_does_not_expand_inside_single_quotes` - `'${HOST}'` stays literal |
| unresolved ref | `load_env_leaves_an_unknown_reference_literal` | `load_env_warns_once_about_an_unknown_reference` - it is never silent |
| precedence | `env_local_overrides_env` and `real_environment_overrides_both` | `load_env_does_not_overwrite_an_existing_process_variable` |
| empty value | `load_env_sets_an_empty_string_for_a_bare_equals` | `load_env_does_not_unset_a_key_declared_empty` |
| malformed line | `load_env_warns_on_a_line_with_no_equals` | `load_env_does_not_abort_the_whole_file_on_one_bad_line` |
| surface | `load_env_accepts_a_root_directory` - all four | `load_env_is_reachable_from_the_top_level_namespace` - the obvious call does not raise |
| fixture parity | `all_four_frameworks_agree_on_the_fixture` - the committed expected-values table matches | `no_framework_has_a_key_the_others_lack` |

The last pair is the one that keeps this closed. A shared fixture plus one answer
key means the next divergence is a failing test in one framework rather than a
silent difference nobody runs both halves of.

## Historical risks

- **D2 (interpolation) is a behaviour change on three frameworks.** A `.env`
  containing a literal `${...}` that today survives as a literal will start
  expanding. That is a `Breaking:` changelog entry with a migration note: escape
  it as `$${...}` or single-quote the value.
- **D1 and D3 are pure bug fixes on Ruby** and need no breaking note: nothing
  depends on a variable being silently missing, and nothing depends on a comment
  being part of a value.

## 2026-08-08 adversarial re-audit: RE-OPENED

The parser corpus remains byte-identical and its named parser cases remain
valuable, but the feature is not closed. The stronger producer-to-consumer pass
found five contradictions outside those green cases:

1. **Present-empty requirement:** Python implements `require_env` with
   `if not os.environ.get(k)`, so `EMPTY=` raises as missing. PHP, Ruby and Node
   check key presence and return the empty string. This contradicts this plan's
   own rule that an empty value is set, not absent.
2. **Project bootstrap regressed in three languages:** Ruby `load_env(root)`
   calls `create_default_env` when `.env` is absent. Python, PHP and Node return
   an empty map instead. Owner decision 2026-08-08: **Ruby's creation behavior
   is correct; Python and PHP used to do this.** Promote missing-root bootstrap
   to all four. This decides the side effect, not the exact generated contents:
   Ruby's time-derived MD5 API key must still be audited against Tina4's security
   contract rather than copied blindly.
3. **Two boolean answers in one runtime:** the public DotEnv truthiness table is
   `true/1/yes/on`, but typed `Env.bool` in Python, PHP and Node still carries
   the retired `y/t/n/f` table. For example, `is_truthy("y")` is false while
   `Env.bool(NAME)` is true in those runtimes. Ruby is the only implementation
   that actually uses one table.
4. **Unknown bool plus default:** Python/PHP/Node return the caller's default for
   a present unknown token, while Ruby classifies any present non-truthy token
   false. Thus `MAYBE=perhaps` with default true produces true in three and
   false in Ruby. The shared corpus already says `maybe` is falsy.
5. **Node accepts numeric prefixes:** Node uses `Number.parseInt` and
   `Number.parseFloat`, which accept `12px` as 12 and `1.5seconds` as 1.5.
   Python's `int/float`, PHP's validators, and Ruby's `Integer/Float` reject the
   whole malformed token and return the default.

These escaped because `dotenv_corpus.json` exercises `is_truthy` but not the
typed `Env.bool` consumer, no requirement case feeds it `EMPTY=`, no common case
loads an entirely empty root and checks the generated filesystem afterward, and the typed
number suites cover wholly invalid strings but not valid prefixes with junk
suffixes. Green method-level tests did not check that adjacent public methods
gave the same answer.

Required closure evidence now includes shared cases for all five contradictions,
the empty-root filesystem assertion, mutation witnesses, and exact-HEAD lab
focused/full runs with zero skips.

## Normative vanilla implementation plan for `.env` (3.14)

This is the language-neutral plan. Another Tina4 implementation must be able to
build Feature 1 from this section without reading an existing runtime.

### Purpose and boundary

Feature 1 bootstraps project configuration, parses `.env` files into the process
environment, exposes consistent lookup/coercion helpers, and owns the precedence
and reset rules. It does not mint authentication secrets: the Auth feature owns
the cryptographically-random development `TINA4_SECRET` in `.env.local`.

### Public concepts

| Concept | Vanilla contract |
| --- | --- |
| `load_env(target?, override=false)` | Load a project root (canonical) or one explicitly named file; return the effective native values declared by the selected source(s). |
| `get_env(key, default=null)` | Return the present value as a ready-to-use native scalar, sequence or map; use the default only when absent. Empty is present. |
| `require_env(...keys)` | Return all requested native values; if any key is absent, raise one catchable configuration error naming every absent key. Empty is present. |
| `has_env(key)` | Test key presence, not truthiness or non-emptiness. |
| `all_env()` | Return a copy of the complete current environment using the same native conversion as `get_env`. |
| `reset_env()` | Restore the exact environment state that existed before this loader changed it. Never delete an ambient value merely because a file mentioned it. |
| `is_truthy(value)` | True only for `true`, `1`, `yes`, `on`, case-insensitive after trim. Everything else is false. |
| `Env.bool/int/float/str` | Explicit coercion or raw-string escape hatches using the same presence and truthiness rules; never a second boolean table. |

Names use language-idiomatic casing only. These concepts must be reachable from
the framework's ordinary one-package import/namespace; an internal parser module
is allowed, but it is not the only public route.

### Target resolution

1. An explicit function argument wins over environment configuration.
2. With no argument, a non-empty `TINA4_ENV_FILE` selects the main file.
   Relative paths resolve against the project root/current working directory.
   Its `.env.local` sibling remains the higher-priority local source.
3. With neither, the current working directory is the project root and `.env`
   is the main file.
4. An existing directory is always a project root. A file is always a single
   source and does not implicitly load siblings.
5. Ruby-only `ENVIRONMENT -> .env.<name>` selection is retired; one canonical
   selector (`TINA4_ENV_FILE`) is simpler and already exists everywhere.

An explicitly selected file that does not exist is a hard configuration
failure (owner decision 2026-08-09). Raise the catchable configuration error and
stop the load/startup operation. Returning an empty result would tell the
developer that requested configuration was loaded when it was not. Only the
missing canonical `.env` of an existing project root is bootstrapped.

Startup, CLI, workers and migration commands call the root form once. They do not
reimplement file ordering or call the loader twice.

### Missing-root bootstrap

When a project root exists but its main `.env` does not, create it atomically and
then load it. Never create `.env.local` merely because it is absent. Never
overwrite an existing file, including under concurrent startup.

Canonical safe default content (owner-approved 2026-08-09, with the scalar
logger level confirmed during the Feature 2 audit):

```dotenv
# Tina4 project settings
PROJECT_NAME="My Project"
TINA4_DEBUG=true
TINA4_LOCALE=en
TINA4_LOG_LEVEL=ALL
TINA4_SWAGGER_ENABLED=false
TINA4_SWAGGER_VERSION=1.0.0
TINA4_SWAGGER_DESCRIPTION="Edit your .env file to change this description"
```

Do not generate `TINA4_API_KEY`, `TINA4_SECRET`, legacy `API_KEY` or legacy
`SECRET` here. An unset API key disables static-key authentication; a generated
key silently enables it. Auth separately mints a cryptographically-random local
JWT secret only in development and persists it to gitignored `.env.local`.
Ruby's current time-derived MD5 API key is therefore not promoted.

Where supported, create the file owner-readable/writable only. A write failure is
a configuration error naming the path; the loader must not claim an empty
successful load after bootstrap failed.

### Source precedence and override

File precedence is invariant: `.env.local` always beats `.env`.

The complete order is:

| Mode | Highest to lowest precedence |
| --- | --- |
| `override=false` | pre-load process environment > `.env.local` > `.env` |
| `override=true` | `.env.local` > `.env` > pre-load process environment |

`override=true` changes only the relationship between the selected file set and
the pre-load process value; it never lets `.env` overwrite `.env.local`. A
lower-priority source never overwrites a value already supplied by a
higher-priority source.

Within one file, the first declaration wins. The returned map must equal the
value actually visible in the process environment; it may never report
`.env.local` while the process is running on `.env`.

### Parser

Process UTF-8 text as follows:

1. Decode as strict UTF-8. Accept and remove one UTF-8 BOM only at the
   beginning of the file. Invalid UTF-8 is a hard configuration failure naming
   the file and byte offset (owner decision 2026-08-09); byte replacement and
   locale-dependent decoding are forbidden.
2. Split CRLF or LF into physical lines. There is no backslash continuation.
   A structured value beginning with `[`, `(` or `{` may span physical lines
   until its quote-aware delimiters balance (owner decision 2026-08-09).
3. Skip blank lines and lines whose first non-space character is `#`.
4. Accept and ignore a standalone non-empty section header such as
   `[Project Settings]`, with surrounding whitespace and an optional trailing
   comment (owner correction 2026-08-09). It is organizational only, creates no
   value and does not change the namespace of following keys. An unclosed or
   otherwise malformed header remains an error.
5. Accept `export` followed by whitespace, then parse the remainder normally.
6. Split on the first `=`. Trim the key and require
   `[A-Za-z_][A-Za-z0-9_]*`. Every nonblank, noncomment physical line must be a
   valid assignment (owner decision 2026-08-09); a missing `=`, invalid key,
   malformed header or malformed `export` form is a hard configuration failure.
   Keys and references are exact and case-sensitive on every platform (owner
   decision 2026-08-09). If the host process environment cannot represent two
   case-distinct keys, that collision is a hard failure rather than a merge.
7. `KEY=` sets an empty string.
8. Single quotes are verbatim: no escape processing or interpolation.
9. Double quotes process `\n`, `\r`, `\t`, `\"` and `\\`, then interpolate.
10. Unquoted values end at the first whitespace-`#`, are right-trimmed, then
   interpolate.
11. A quote must close. After a closing quote, only whitespace and an optional
    comment are valid. A malformed quoted assignment is a hard configuration
    failure (owner decision 2026-08-09), not a skipped line or retained string.
12. `${NAME}` resolves through the complete effective assignment dependency
    graph after source precedence is applied. Forward and cross-file references
    are valid (owner decision 2026-08-09). A name absent from the graph,
    pre-load process environment and applicable framework constants is a hard
    configuration failure; it never becomes empty or remains unresolved.
13. A duplicate key within one physical file is a hard configuration failure
    naming both declaration lines (owner decision 2026-08-09). This is distinct
    from the same key appearing in `.env.local` and `.env`, where source
    precedence selects the effective value.

Inside a multiline structured value, line breaks are whitespace and comments
are not recognized. Only whitespace and an optional comment may follow the
complete outer closing delimiter. An unclosed or mismatched delimiter reports
the assignment's starting line and the physical line where parsing failed.

Dollar escaping is `$$ -> $` (owner decision 2026-08-09). Interpolation scans
after applying that escape, but an escaped dollar is protected from that scan,
so `$${NAME}` produces the literal `${NAME}` rather than `$` plus an expanded
reference. Single-quoted values remain entirely literal.

Interpolation always produces text. Native scalar references use canonical
lowercase `true`, `false` and `null` plus the portable decimal representation
for numbers. Native sequences and maps use compact canonical JSON with map keys
in source insertion order (owner decision 2026-08-09); no runtime may use its
language-specific collection-to-string representation.

Warnings go to stderr before logging is available and include the real path,
physical line number and reason. The loader never labels every custom file
`.env` in diagnostics.

Parsing is transactional. Resolve, read, parse and validate the complete
selected source set before mutating the process environment. Any hard parse
failure installs none of that load's assignments; it cannot leave the process
partially configured.

### Typed coercion

`get_env` is the ordinary application boundary and performs native conversion.
After interpolation, it resolves values in this order:

1. a quoted dotenv value is a string, even when its content resembles another
   type;
2. unquoted `true/yes/on` and `false/no/off` become booleans,
   case-insensitively (owner decision 2026-08-09); `1` and `0` remain integers;
3. unquoted `null` becomes the language's null value case-insensitively (owner
   decision 2026-08-09), while `none`, `nil` and quoted tokens remain strings and
   `has_env` remains true;
4. a full-token integer within `-(2^53-1)` through `2^53-1` becomes an integer;
5. a full-token finite decimal/scientific number becomes a float;
6. valid `[...]` or `(...)` becomes the language's sequence type, resolving
   every unquoted identifier through environment-then-framework-constant lookup;
7. valid `{...}` becomes the language's string-keyed map type;
8. everything else remains a string, including the empty string.

The loader retains minimal type metadata for quoted file values because the
operating-system environment cannot retain quote intent. It also records the
raw string used to produce that value. If application code later changes the
process value, stale metadata is ignored and the new value is inferred. This
preserves `PORT="7145"` as a deliberate string without making process-environment
storage non-standard.

The owner-approved portable decimal grammar accepts optional `+`/`-`, leading
zeros as decimal, `.5`, `1.`, and scientific notation such as `-2.5E-4`. The
entire token must match. Hexadecimal, binary, octal interpretation, numeric
separators, grouping commas, `NaN`, infinity and numeric prefixes are not native
numbers. The same spelling rules apply to structured numeric elements.

- `Env.bool`: the default applies only when the variable is absent. For a
  present value, `true/1/yes/on` is true and everything else is false.
- `Env.int`: trim, require the entire token to be a base-10 signed integer, and
  reject values outside the owner-approved cross-language safe integer range,
  `-9007199254740991` through `9007199254740991`. No prefix parses (`12px`) and
  no float-to-int coercion. Automatic `get_env` preserves an out-of-range
  integer token as a string; explicit `Env.int` warns and returns its default.
- `Env.float`: trim, require the entire decimal/scientific token, and return only
  finite values. Reject prefixes, `NaN` and positive/negative infinity.
- `Env.str`: return the raw string unchanged, including surrounding whitespace
  and the empty string.
- Invalid numeric input warns and returns the caller's default; it never raises.

### Structured values

The owner requires the dotenv surface to understand structured literals such
as:

```dotenv
VAR=["VAR", "MOO", 1, 2]
VAR=("VAR", "MOO", 1, 2)
VAR={"key": "value"}
```

This must be implemented with a small data parser, never a language `eval`, so
the same input cannot execute code and has the same meaning in every runtime.
The operating-system process environment still stores the post-interpolation
text because process environments are string-only. `get_env`, `require_env`,
`all_env` and the return value from `load_env` decode it into the language's
native sequence or string-keyed map before returning it to application code.

The portable base is JSON's value grammar for numbers, booleans, null, nested
sequences and nested maps. Structured strings accept both quote styles (owner
decision 2026-08-09): single-quoted strings are verbatim; double-quoted strings
process the defined escapes and interpolation. Map keys must be quoted strings
using either style (owner decision 2026-08-09); a bare map key is invalid and is
never treated as text or as a reference. A duplicate map key is invalid and
fails the complete load rather than selecting a first or last value (owner
decision 2026-08-09). Double-quoted map keys process escapes and interpolation;
single-quoted keys are verbatim, and duplicate detection runs after key
resolution (owner decision 2026-08-09). Parentheses are a Tina4 alias for a
sequence because PHP, JavaScript and Ruby have no portable tuple type. Square
brackets and parentheses therefore produce the same semantic value at every
nesting level (owner decision 2026-08-09).

One trailing comma is allowed immediately before a closing `]`, `)` or `}` at
every nesting level (owner decision 2026-08-09). It does not add an empty
element. A missing comma, two separators without a value, or any other separator
error is a hard configuration failure.

Numeric elements inside a structure must satisfy the same portable integer and
finite-float rules as top-level native conversion. An out-of-range integer,
non-finite float or overflowing exponent is a hard configuration failure (owner
decision 2026-08-09). It is never silently converted to a string or a
language-specific numeric type. A top-level out-of-range integer remains a raw
string because no structured numeric intent was declared.

Native structure nesting and combined environment/framework-constant reference
resolution share a portable maximum depth of 64 (owner decision 2026-08-09).
Depth 64 succeeds; depth 65 is a catchable configuration error and fails a load
transactionally. Implementations may use an iterative parser, but may not expose
their language runtime's incidental recursion limit as Tina4 behavior.

Tina4 adds one deliberate extension inside a structured value: an unquoted
identifier is a reference. Resolve it first from the effective environment and
then from the Tina4 language constants initialized by the framework before
dotenv loading. An OS-level value, or an earlier effective dotenv assignment,
therefore overrides the framework constant according to the ordinary precedence
rules. A quoted identifier is always a literal string:

```dotenv
ENV=[TINA4_LOG_ALL]     # environment value, else framework constant
ENV=["TINA4_LOG_ALL"]   # one literal string
```

References use the same complete effective assignment graph as interpolation.
Parse all selected sources, choose collision winners by precedence, and then
resolve the graph, so forward references and `.env.local` references to
lower-priority `.env` values work (owner decision 2026-08-09). A pre-load
process value participates according to `override`; if the effective environment
lookup misses, the initialized framework constant of the same name is the
fallback. A name missing from every source makes the containing assignment
invalid; it never degrades into identifier text. The diagnostic names the file,
line, assignment and missing name. The invalid assignment is a hard
configuration failure.

Reference resolution tracks the active chain. A cycle is a catchable
configuration error containing the complete chain, for example
`VALUE -> A -> B -> A` (owner decision 2026-08-09). During loading it fails the
transaction without mutation; direct `get_env` access to a cyclic pre-load
environment value raises the same error rather than returning raw text, null or
an empty collection.

Feature 1 consumes the initialized constant registry; it does not own the log
constant values. The Logging feature must define the canonical cross-language
`TINA4_LOG_*` constants and make them available before dotenv parsing. The
current implementations do not yet satisfy that lifecycle uniformly: PHP
defines several language constants, Ruby recognizes bracketed names inside its
logger, and Python and Node do not expose the same initialized constant set.

`Env.str` is the explicit raw-string escape hatch when application code needs
the representation rather than the native value.

Every structured result returned by `get_env`, `require_env`, `all_env` or
`load_env` is an independent native value (owner decision 2026-08-09). Mutating
it cannot change the process-environment string, loader metadata, another
returned result or a later read. Implementations may cache an immutable parsed
form internally only if they return a deep copy at the public boundary.

### Reset ownership

Before the first mutation of a key, record whether it existed and its exact old
value. `reset_env()` restores that snapshot and removes only keys that did not
exist before the loader created them. Calling reset repeatedly is harmless.

Keys that lost precedence and were never mutated are not owned by the loader.
This rule covers `override=true`: an overridden ambient value is restored rather
than deleted.

### Operation graph

```
initialize framework constants
  -> resolve target
  -> bootstrap missing root main file
  -> read and parse the complete local/main source set
  -> apply source precedence
  -> resolve interpolation/reference dependency graph
  -> mutate process environment
  -> typed and untyped consumers
  -> reset restores pre-load state
```

Every startup and CLI consumer uses this graph. No consumer maintains a private
truthiness table or a second `.env` ordering implementation.

### Conformance specification

The byte-identical shared `dotenv_corpus.json` now carries the versioned
`contract_3_14` answer key in all current framework fixture directories. The
legacy top-level fields remain temporarily for the 3.13 runners. A dedicated
fail-closed 3.14 runner in every framework now discovers each contract ID exactly
once and dispatches it through a per-case executor registry. An absent executor
is a failure, never a skip, pending result or silent pass. The registries remain
empty until Feature 1 implementation begins, so the wired contract baseline is
intentionally red rather than falsely claiming conformance.
Inputs include file bytes, pre-load environment, initialized constants, target,
override mode and operation. Outputs include native return values, raw process
values, files created, diagnostics, error category and post-reset state.

| ID | Witness | Required outcome |
| --- | --- | --- |
| `ENV-T01` | Existing root without `.env` | Atomically create and load the exact approved template; create no secret and no `.env.local`. |
| `ENV-T02` | Existing root with `.env` | Never rewrite the file; return its effective native values. |
| `ENV-T03` | Missing explicit file | Raise configuration error naming the resolved path; create nothing; mutate nothing. |
| `ENV-T04` | Missing/unreadable root or bootstrap write failure | Raise configuration error naming the path and operation; never report an empty success. |
| `ENV-T05` | `TINA4_ENV_FILE` relative/absolute | Resolve relative to project root; treat it as main source and its local sibling as higher priority. |
| `ENV-T06` | Explicit existing file argument | Load that file only; do not discover a sibling `.env.local`. |
| `ENV-T07` | Two concurrent missing-root loads | Exactly one complete template exists; neither caller observes partial bytes or truncates a winner. |
| `ENV-P01` | Ambient/local/main collision, `override=false` | Ambient wins; otherwise local wins main. Returned native value and raw process value agree. |
| `ENV-P02` | Ambient/local/main collision, `override=true` | Local wins main, and selected files win ambient. Main never overwrites local. |
| `ENV-P03` | Same key twice in one file | Hard failure names both lines; complete source-set transaction remains unchanged. |
| `ENV-P04` | Same key in local and main | Not a duplicate error; precedence selects one effective assignment. |
| `ENV-P05` | Local forward-reference to main | Resolve through the effective dependency graph after precedence. |
| `ENV-S01` | UTF-8 BOM plus CRLF | Remove one leading BOM and parse CRLF exactly as LF. |
| `ENV-S02` | Invalid UTF-8 | Hard failure names file and byte offset; no mutation. |
| `ENV-S03` | Blank/comment/header/export | Ignore blanks, comments and valid section headers; accept `export KEY=value`. |
| `ENV-S04` | Missing `=`, invalid key/header/export | Hard failure names physical line and reason. |
| `ENV-S05` | Empty/single/double/unquoted values | Preserve empty; single is verbatim; double applies approved escapes/interpolation; unquoted applies comment rule. |
| `ENV-S06` | Unclosed quote or junk after quote | Hard failure; no assignment from the source set is installed. |
| `ENV-S07` | Balanced multiline structure | Consume through the balanced outer delimiter; newlines are whitespace; trailing outside comment is allowed. |
| `ENV-S08` | Comment marker inside structure | It is data only inside a quoted string; an unquoted internal comment token is invalid. |
| `ENV-R01` | Backward, forward and cross-file `${NAME}` | Resolve all through the effective dependency graph. |
| `ENV-R02` | `$${NAME}` and single-quoted `${NAME}` | Return literal `${NAME}` with no lookup. |
| `ENV-R03` | Missing unescaped `${NAME}` | Hard failure names the missing name and referring assignment. |
| `ENV-R04` | Bare structured name with ambient and constant | Effective environment wins initialized framework constant. |
| `ENV-R05` | Bare structured name with constant only | Resolve the native framework constant. |
| `ENV-R06` | Bare name missing everywhere | Hard failure; never convert identifier to text. |
| `ENV-R07` | Circular pre-load references | Catchable error contains the complete cycle; load/direct read returns no invented value. |
| `ENV-R08` | Depth 64 and 65 | Depth 64 succeeds; depth 65 fails with the depth and assignment named. |
| `ENV-N01` | Unquoted boolean/null words | Case-insensitive approved words return booleans/null; `1`/`0` return integers; `none`/`nil` remain strings. |
| `ENV-N02` | Quoted typed-looking tokens | `"true"`, `'null'`, `"7145"` remain strings, including after a later read. |
| `ENV-N03` | Decimal spellings | Accept sign, decimal leading zeros, `.5`, `1.` and exponent; reject numeric prefixes, hex/binary/separators/commas as native numbers. |
| `ENV-N04` | Integer boundaries | `+/-9007199254740991` are integers; larger top-level integer tokens are strings; explicit integer coercion warns/defaults. |
| `ENV-N05` | Non-finite/overflow float | Top-level automatic lookup leaves it a string; explicit float coercion warns/defaults. |
| `ENV-N06` | Lists, parentheses, maps and nesting | Return equivalent native sequences for both delimiters and insertion-ordered string-keyed maps. |
| `ENV-N07` | Single/double structured strings and keys | Single is verbatim; double escapes/interpolates; post-resolution duplicate map keys hard-fail. |
| `ENV-N08` | One trailing comma | Accept at every nesting level without adding an element; missing/repeated separators hard-fail. |
| `ENV-N09` | Non-portable structured number | Hard failure; never coerce the element to text or a language-specific number. |
| `ENV-N10` | Collection interpolation | Emit compact canonical JSON; scalars use canonical lowercase/null/decimal text. |
| `ENV-N11` | Mutate returned list/map | Later reads and all other returned values remain unchanged. |
| `ENV-A01` | Present empty and absent with default | Empty is present and returned; only absence returns the caller's default. |
| `ENV-A02` | `require_env` with several absent keys | One catchable error lists every absent key; present empty is not absent. |
| `ENV-A03` | `all_env` | Complete environment copy, same native conversion, no shared mutable values. |
| `ENV-A04` | Reset created/ambient/overridden keys | Remove loader-created keys and restore exact original ambient strings and presence. Repeated reset is harmless. |
| `ENV-A05` | Failed load after successful load | Preserve the earlier successful state and its reset snapshot exactly. |
| `ENV-I01` | Server/CLI/worker/migration startup | Each invokes the root operation once; no private ordering or parser path. |
| `ENV-I02` | Boolean framework consumers | Every consumer agrees with the single `is_truthy` table; no private token set. |

Mutation witnesses must independently prove atomicity, precedence, native type,
diagnostic location, defensive copy and reset restoration. A case that checks
only the returned map is insufficient; it must also inspect the real process
environment and filesystem where applicable.

Fixture-staging verification on the lab (`nvidia-rtx4500`, 2026-08-09), run as
root with fixture SHA-1 `51f1ec315fe157d3f7fb7f62052dd0985595383e`:

- Python legacy runner: 90 passed;
- PHP legacy runner: 20 tests, 49 assertions passed;
- Ruby legacy runner: 38 examples, 0 failures;
- Node legacy runner: 68 passed, 0 failed.

This proves the additive versioned fixture remains parseable and does not break
the 3.13 runners. It does **not** claim 3.14 conformance because those runners
consume only the legacy top-level fields.

Fail-closed runner verification on the same lab and date, using the same staged
fixture, proved that every language discovers all 46 contract cases and refuses
to pass an unimplemented executor:

- Python: 48 collected, 2 metadata checks passed, 46 named executor failures;
- PHP: 48 tests, 50 assertions, 46 named executor failures;
- Ruby: 48 examples, 46 named executor failures;
- Node: 4 harness checks passed, 46 named executor failures.

All four commands exited nonzero as required. This is the expected-red
implementation baseline: replacing a missing executor with its behavioral test
and implementation is the only path to green. The lab fixture files and runner
files were restored after the run; all four clones had an empty tracked status
and the original fixture SHA-1
`2673df7b22ae81ba3d5ec077085c6a3b165e43b1`.

### Porting capsule

1. **Purpose and boundary:** bootstrap project configuration, resolve and parse
   dotenv sources, expose ready-to-use native values and restore owned process
   mutations. Auth owns secret generation; Logging owns `TINA4_LOG_*` values.
2. **Public surface:** `load_env`, `get_env`, `require_env`, `has_env`,
   `all_env`, `reset_env`, `is_truthy`, and explicit `Env.bool/int/float/str`
   coercion/raw helpers, exported through the ordinary Tina4 package namespace.
3. **Inputs and outputs:** UTF-8 files and string-only process values enter; the
   public boundary returns independent native strings, booleans, nulls, portable
   numbers, sequences and insertion-ordered string-keyed maps under the grammar
   and range rules above.
4. **Lifecycle/state machine:** initialize constants -> resolve target ->
   bootstrap canonical root file -> parse all sources -> apply precedence ->
   resolve dependency graph -> atomically mutate -> serve native reads -> reset
   exact pre-load state. A process-wide loader lock protects snapshot/mutation.
5. **Precedence and configuration:** explicit argument > `TINA4_ENV_FILE` >
   current root for target selection. `override=false`: ambient > local > main.
   `override=true`: local > main > ambient. Environment beats framework
   constants during reference resolution.
6. **Failure and side effects:** one catchable DotEnv/configuration error
   category with path/line/reason fields. Missing explicit targets, malformed
   syntax/data, missing/cyclic/deep references, invalid UTF-8 and IO failures are
   hard and transactional. Only missing canonical root `.env` may be created.
7. **Wire and persistence contract:** UTF-8, optional single leading BOM,
   LF/CRLF, approved exact scaffold bytes, owner-only permissions where
   supported, atomic no-overwrite creation, raw strings in the OS environment
   and canonical JSON only for textual collection interpolation.
8. **Provider contract:** no third-party parser/provider. Filesystem must supply
   atomic exclusive creation and real-path diagnostics; process environment must
   be wrapped to enforce exact key identity, snapshot and restoration.
9. **Executable conformance:** the shared `dotenv_corpus.json` section
   `contract_3_14` contains `ENV-T01` through `ENV-I02` above. Every runner
   discovers every ID exactly once, uses real temporary files/process state and
   supplies mutation witnesses.
10. **Integration map:** framework constants initialize before DotEnv; server,
    CLI, workers and migrations call the root loader once; package exports expose
    the complete API; scaffold output is the approved template; diagnostics work
    before Logging; 3.14 migration notes name native-return, strict-failure,
    precedence, structured grammar and reset changes.

### Owner decisions: settled 2026-08-09

| Decision | Settled rule |
| --- | --- |
| 1 | Generate the exact seven-value non-secret canonical template. |
| 2 | A missing explicitly selected file is a hard failure; only canonical root `.env` bootstraps. |
| 3 | Malformed quoted syntax hard-fails the complete transaction. |
| 4 | `$$ -> $`; escaped dollars do not interpolate. |
| 5 | Native integer range is `+/-9007199254740991`; larger top-level tokens remain strings. |
| 6 | Invalid UTF-8 hard-fails; one leading BOM is accepted. |
| 7A | Structured strings accept single-verbatim and double-processed quotes. |
| 7B | Map keys must be quoted strings. |
| 7C | `[]` and `()` are equivalent sequences at every nesting level. |
| 7D | Balanced structures may span physical lines without backslashes. |
| 8 | Every malformed structured assignment hard-fails transactionally. |
| 9 | Duplicate map keys hard-fail. |
| 10 | Non-portable structured numbers hard-fail. |
| 11 | Circular references hard-fail and report the complete chain. |
| 12 | Structure/reference depth 64 succeeds; depth 65 fails. |
| 13 | Missing unescaped `${NAME}` interpolation hard-fails. |
| 14 | One trailing comma is allowed at every structured nesting level. |
| 15 | Text interpolation serializes collections as compact canonical JSON. |
| 16 | Unquoted boolean words are case-insensitive; `1`/`0` remain integers. |
| 17 | Unquoted `null` is case-insensitive; `none`/`nil` remain strings. |
| 18 | Human-friendly portable signed decimal grammar applies everywhere. |
| 19 | Invalid assignment lines hard-fail; valid standalone section headers are allowed and ignored. |
| 20 | Duplicate assignments within one file hard-fail; cross-file collisions use precedence. |
| 21 | Keys/references are case-sensitive; unrepresentable host collisions fail. |
| 22 | Double-quoted map keys interpolate; single-quoted keys are literal. |
| 23 | Every returned structure is an independent native value. |
| 24 | Resolve the complete effective dependency graph, including forward and cross-file references. |

There are no unresolved owner choices in Feature 1.

## Historical shipped record (2026-07-30; superseded by normative 3.14 contract)

D2 was applied to all four rather than removed from PHP, per the owner's
go-ahead. All four now agree on every line of the shared fixture.

Parser convergence landed first, the named test pairs followed:

- **Ruby's two silent bugs**: `export FOO=bar` dropped the variable entirely,
  and a trailing comment stayed inside the value.
- **`${VAR}` interpolation added to Python, Ruby and Node** (Breaking). Single
  quotes are the documented escape for a literal `${...}` and the migration path.
- **PHP's unresolved reference resolved to the EMPTY STRING**, so
  `URL=${DB_HOST}/db` with a typo silently became `/db`. PHP was the framework
  the other three adopted interpolation from, and this was the half nobody had
  exercised.
- **PHP accepted any non-empty key**, so `1BAD=x` set a variable named `1BAD`
  that no shell could export and no other framework would have created. Caught
  by the shared fixture, after the parser work was already "done".

`dotenv_corpus.json` is byte-identical in all four
(`tests/fixtures/`, `spec/fixtures/`, `test/fixtures/`). The .env CONTENT lives
in it too rather than in a sibling file: one file means one thing to keep in
sync, and a fixture whose input and expectations can drift apart is not an
answer key. Real files in a temp directory, real process environment, nothing
mocked. Python 32, PHP 18, Ruby 31, Node 35.

**Still open from this row:** the surface reconciliation (step 5 of the
methodology). `load_env` takes a FILE path in Python, PHP and Node and a
DIRECTORY in Ruby, and Ruby's helpers are only reachable as `Tina4::Env.*`
rather than `Tina4.*`. The parser behaviour is uniform; the call shape is not.
