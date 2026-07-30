# Feature 1: DotEnv parser (.env loading)

Audited 2026-07-28. Part of `98-feature-audit.md`. **Planning only.**

## Files

| | path |
| --- | --- |
| python | `tina4-python/tina4_python/dotenv/__init__.py` |
| php | `tina4-php/Tina4/DotEnv.php`, `tina4-php/Tina4/Env.php` |
| ruby | `tina4-ruby/lib/tina4/env.rb` |
| node | `tina4-nodejs/packages/core/src/dotenv.ts`, `env.ts` |

## Measurements

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 113 | 7 | 29 | 4.14 | `load_env` (17) | 33.5 | 2 warn |
| php | 224 | 16 | 58 | 3.62 | `DotEnv.loadEnv` (20) | 32.2 | 3 warn |
| ruby | 176 | 17 | 46 | 2.71 | - | 25.3 | 1 warn |
| node | 144 | 15 | 45 | 3.0 | `parseEnvContent` (13) | 36.8 | 2 warn |

Leanest python (113), simplest per function ruby (2.71), best MI node (36.8),
spread 2.0x. No errors anywhere. By the numbers this feature looks healthy, which
is exactly why the numbers are not the audit.

## What differs

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

## Verdict: SYNTHESISE

Decided on **correctness**. Two of the three divergences are silent wrong-value or
missing-value bugs in Ruby, and the third is a PHP-only capability that makes a
PHP-authored `.env` unportable. Neither "promote Ruby" nor "promote PHP" is right:
Ruby has the best code shape (lowest CC per function) and the worst parser;
PHP has the richest parser and the heaviest code.

Take the **parser behaviour from the union of Python and Node** (they agree on
every line above, and Node has the best MI), add **PHP's `${VAR}` interpolation**
to all four, and keep **Ruby's typed getters** by promoting them everywhere.

## Pattern

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

## Methodology

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

## Tests to write

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

## Risks

- **D2 (interpolation) is a behaviour change on three frameworks.** A `.env`
  containing a literal `${...}` that today survives as a literal will start
  expanding. That is a `Breaking:` changelog entry with a migration note: escape
  it as `$${...}` or single-quote the value.
- **D1 and D3 are pure bug fixes on Ruby** and need no breaking note: nothing
  depends on a variable being silently missing, and nothing depends on a comment
  being part of a value.

## SHIPPED all four (2026-07-30)

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
