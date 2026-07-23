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
| C - additions, now verified | 19 | 17 |
| **Total** | **97** | **95** |

Two rows are not yet all-four:
- **C1 doc-truth checker - MISSING IN RUBY.** Real, confirmed gap. PHP has `Docs::checkDocs`
  (`Tina4/Docs.php:291`) + `syncDocs` (`:364`); Python and Node have equivalents; `tina4-ruby/lib/
  tina4/docs.rb` has no check/verify/audit/sync method at all. **Owner directive 2026-07-23: a
  feature missing in one framework must be BUILT there so all four match.** Queued to port.
- **C13 second template engine (ERB + Twig) - Ruby-only by language necessity.** ERB is a Ruby
  technology; there is nothing to port. Frond is the cross-framework engine and is Section A. This
  row stays flagged Ruby-native rather than counted as a gap.

So: **97 rows, 95 at full parity, 1 gap to close (C1 -> 96), 1 legitimately language-native.**

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

Each was reported by the audit of ONE framework, which only proves it there. They are NOT yet
countable at family level. Needs the Section-A method applied to the other three.

Request logging aside, these came from PHP (19 reported), Ruby (8) and Node (15) with heavy overlap
already folded into Section B. What remains distinct:

| # | Feature | Reported in | Needs checking in |
|---|---------|-------------|-------------------|
| C1 | Doc-truth checker (`checkDocs`/`syncDocs`) | PHP | py, rb, node |
| C2 | File / attachment responses (`Response::file()`) | PHP | py, rb, node |
| C3 | Queue job handle (explicit ack/nack object) | PHP | py, rb, node |
| C4 | Swagger security-scheme + schema registry | PHP | py, rb, node |
| C5 | Credential-safe database URL parser (redacted logging) | PHP | py, rb, node |
| C6 | Docker image build command | PHP, Node | py, rb |
| C7 | Route table inspector (`routes` command) | PHP | py, rb, node |
| C8 | Self-describing CLI manifest (`commands --json`) | PHP | py, rb, node |
| C9 | Realtime chat domain models (workspace/channel/message/attachment) | PHP | py, rb, node |
| C10 | Firebird PDO fallback adapter | PHP | py, rb, node (may be PHP-unique) |
| C11 | Legacy env-var migration checker | PHP | py, rb, node |
| C12 | Instant HTML CRUD UI (searchable, paginated, modals) | Ruby | py, php, node |
| C13 | Second template engine (ERB + Twig) + route `template:` | Ruby | py, php, node (may be Ruby-unique) |
| C14 | Secure-by-default write routes | Node | py, php, rb |
| C15 | Template auto-routing + SPA index + landing page | Node | py, php, rb |
| C16 | HTTP/1.1 method conformance (auto-HEAD, OPTIONS, 405+Allow) | Node | py, php, rb |
| C17 | Code generators (model/route/crud/migration/…) | Node | py, php, rb |
| C18 | Built-in Tina4 CSS bundle | Python | php, rb, node |
| C19 | In-dashboard AI agent + supervised edit sessions | Python | php, rb, node |

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
