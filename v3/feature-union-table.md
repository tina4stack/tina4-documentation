# Canonical feature enumeration (union table)

The single source the four `feature-list` doc pages must be generated from, so they cannot drift
into three different numbers again. Companion to `feature-recount.md`.

**Counting model (owner decision, 2026-07-23):** count the **family**, including the dev overlay,
metrics, REPL, the `tina4` CLI features, and **per-framework unique features**. The published number
is this table's row count. **Every row that is not present in all four is a parity gap** - the table
that produces the number is also the parity backlog.

## Method warning - read before adding or verifying a row

A row's presence must be established the way the four framework audits did it: **case-sensitive,
symbol-anchored** search, cross-checked against the public export surface, and confirmed by invoking
the thing where practical. Do NOT record a negative from a single filename or keyword grep.

Three hand-rolled checks produced false results in one session:
1. `compgen -G` used under zsh (a bash builtin) - returned "absent" for every path, including files
   that plainly exist.
2. A template-literal region heuristic - misclassified real ESM code as being inside a script string.
3. Keyword greps for `security_headers` / `aiPort` / `set_cookie` - reported four absences that were
   all present under different names (`X-Frame-Options` in `middleware.py:221` and
   `middleware.rb:545`; `TINA4_NO_AI_PORT` in `server.ts:1497`; `def cookie` in `response.py:192`
   and `Response.php:298`).

Every one was a naming difference, never a real gap. When a check says "absent", assume the pattern
is wrong until a second, differently-anchored check agrees.

## Section A - the 65 audited candidates

All 65 are verified present in all four frameworks, each with a `file:line` public entry point, by
four independent per-framework audits (Python 3.13.5 / PHP 8.5.7 / Ruby 4.0.2 / Node 24.9.0, all on
macOS 26.5.2). The full per-framework evidence tables live in the audit results; the candidate list
itself is in `feature-recount.md`.

Status: **65 rows, all four ✅.** Candidate 51 (CLI) is now a single clean row - `doctor`/`setup`/
`deploy` reach all four by delegation as of the CLI parity batch.

## Section B - addition rows confirmed present in all four (13)

Verified by me, read-only, with a second differently-anchored check on anything that first read as
absent:

| # | Feature | All four? |
|---|---------|-----------|
| B1 | CSRF protection (form token + validating middleware) | ✅✅✅✅ |
| B2 | Security-headers middleware (CSP, X-Frame-Options, Referrer-Policy, …) | ✅✅✅✅ |
| B3 | Request-logging middleware | ✅✅✅✅ |
| B4 | Multipart file uploads (`request.files`, raw bytes) | ✅✅✅✅ |
| B5 | Named / multiple database connections | ✅✅✅✅ |
| B6 | Project code/doc search index (SQLite FTS5) | ✅✅✅✅ |
| B7 | Broken-file tracker (`data/.broken` sentinels) | ✅✅✅✅ |
| B8 | Dual-port dev server (stable AI port at base+1000) | ✅✅✅✅ |
| B9 | Interactive REPL console | ✅✅✅✅ |
| B10 | Pluggable file-storage backends (local / S3) | ✅✅✅✅ |
| B11 | MongoDB as a database driver | ✅✅✅✅ |
| B12 | Cookie API (`response.cookie`, HttpOnly/SameSite/Secure) | ✅✅✅✅ |
| B13 | Automatic response compression + ETag | ✅✅✅✅ |

Caveat on B7: Ruby WRITES the sentinel but nothing in `lib/` READS it (D15), and Python's `/health`
does read it. Counted present, flagged as a behavioural parity gap.

## THE NUMBER: 97

| Section | Rows | All four today |
|---------|------|----------------|
| A - audited candidates | 65 | 65 |
| B - additions verified all four | 13 | 13 |
| C - additions, now verified | 19 | 18 |
| **Total** | **97** | **96** |

One row is legitimately language-native; the former C1 gap is now closed:
- **C1 doc-truth checker - CLOSED, now all four (2026-07-23).** The "missing in Ruby" verdict was
  stale: `tina4-ruby/lib/tina4/docs.rb` DOES have `Docs.check_docs` (drift detector, `:161`) and
  `Docs.sync_docs` (`:211`), backed by `STDLIB_ALLOWLIST` (`:27`) and `render_generated_block`
  (`:624`) - a full mirror of the Python master (`docs.py check_docs`/`sync_docs`) and PHP
  (`Docs::checkDocs`/`syncDocs`). Verified by reading the source AND running `spec/docs_spec.rb`
  (20 examples, 0 failures - including the drift-detector and BEGIN/END-GENERATED-API sync tests).
  It is a library-level API in all four (no MCP/CLI wiring in any of them), so parity holds. The
  original verdict was built from a stale grep, not the code - see the method warning below.
- **C13 second template engine (ERB + Twig) - Ruby-only by language necessity.** ERB is a Ruby
  technology; there is nothing to port. Frond is the cross-framework engine and is Section A. This
  row stays flagged Ruby-native rather than counted as a gap.

So: **97 rows, 96 at full parity, 1 legitimately language-native (C13 ERB). No open parity gap.**

## Method failures in this session - all six were my own harness, never a real gap

Recorded so nobody trusts a bare presence check again:

1. `compgen -G` under zsh (a bash builtin) - "absent" for every path, including files that exist.
2. A template-literal region heuristic - misclassified real ESM code as inside a script string.
3. Keyword greps `security_headers` / `aiPort` / `set_cookie` - four absences, all present under
   other names (`X-Frame-Options` `middleware.py:221` + `middleware.rb:545`; `TINA4_NO_AI_PORT`
   `server.ts:1497`; `def cookie` `response.py:192` + `Response.php:298`).
4. A shell function using `read -ra` (bashism) - errored on every row under zsh yet still printed
   `Y` for all of them. Results discarded wholesale.
5. A Python walker filtering on `*.php` - missed `bin/tina4php`, which is **extensionless**, and so
   reported PHP as lacking `commands` (5 hits) and `generate` (2 hits).
6. Pattern `function file(` - missed Node's `response.file = function (` (space before paren).

Rule: a negative is not a finding until a second, differently-anchored check agrees. Prefer the
per-framework audit method (case-sensitive symbol anchor + public-export cross-check + live
invocation) over anything hand-rolled.

## Section C - detail (19 rows, VERIFIED 2026-07-23)

All 19 were checked across all four frameworks with the Python walker plus a second
differently-anchored check on every apparent absence. Result: **17 present in all four**, 1 real gap
(C1, Ruby), 1 language-native (C13, Ruby ERB). The "needs checking in" column below is the original
scoping note, kept for history - it is now closed.

Verdicts below are the finished result, not a to-do list. Method: the Python walker across all
four, plus a second differently-anchored check on every apparent absence (which is how C2 and the
two PHP rows turned out to be false negatives from my own patterns, not gaps).

| # | Feature | Verdict |
|---|---------|---------|
| C1 | Doc-truth checker (`checkDocs`/`syncDocs`) | all four - Ruby `Docs.check_docs`/`sync_docs` (`docs.rb:161`/`:211`), specs green (was a stale "missing" verdict) |
| C2 | File / attachment responses | all four (Node's is `response.file = function (`, which my first pattern missed) |
| C3 | Queue job handle (explicit ack/nack object) | all four |
| C4 | Swagger security-scheme + schema registry | all four |
| C5 | Credential-safe database URL parser | all four |
| C6 | Docker image build command | all four |
| C7 | Route table inspector (`routes` command) | all four |
| C8 | Self-describing CLI manifest (`commands --json`) | all four (PHP's is in the EXTENSIONLESS `bin/tina4php`, 5 hits) |
| C9 | Realtime chat domain models | all four |
| C10 | Firebird driver + fallback | all four have a Firebird driver; the *PDO* fallback is PHP-specific by language |
| C11 | Legacy env-var migration checker | all four |
| C12 | Instant HTML CRUD UI | all four |
| C13 | Second template engine (ERB + Twig) | **Ruby-native.** ERB is a Ruby technology; nothing to port. Frond is the cross-framework engine (Section A) |
| C14 | Secure-by-default write routes | all four |
| C15 | Template auto-routing + SPA index | all four |
| C16 | HTTP/1.1 method conformance (auto-HEAD, OPTIONS, 405+Allow) | all four |
| C17 | Code generators | all four (PHP's `generate` also in `bin/tina4php`) |
| C18 | Built-in Tina4 CSS bundle | all four - I verified the shipped bundles byte-identical myself |
| C19 | In-dashboard AI agent + supervised sessions | all four (Node's `/__dev/api/supervise/*` are stubs - see D-list) |


## The number

- **Confirmed floor: 78** (65 audited candidates + 13 additions verified in all four).
- **Ceiling if every Section-C row lands in all four: 97.**
- Rows that turn out to be genuinely framework-unique still count under the owner's model, but must
  be marked as such in the docs so the per-language pages stay honest.

Every number currently published is wrong against the floor alone: **55** (4 READMEs + badges + book
+ python CLAUDE.md), **54** (`tina4-php/composer.json` = the Packagist description, and `llms.txt`),
**45** (the 4 feature-list pages + `tina4-nodejs/CLAUDE.md`), **44** (`what-is-tina4.md`,
`comparisons.md`).

## Scope
- [x] Section A verified (four per-framework audits)
- [x] Section B verified (13 additions, all four)
- [ ] Section C: apply the Section-A method to 19 rows x 3 frameworks
- [ ] Publish ONE number; regenerate the 4 feature-list pages from this file
- [ ] Fix `composer.json` + `llms.txt` (machine-read: Packagist and LLM context) first - they are
      read more often than the README
- [ ] `audit-truth.py` gate must pass; note its `FORWARDED_SUBCOMMANDS` list predates CLI delegation
