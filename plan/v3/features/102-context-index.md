# Feature 102: Local source and documentation context index

## Identity and status

- Matrix identity: 102 - Local source and documentation context index
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11 on branch `feature/mcp-call-gate` at
  Python `context/__init__.py` (371) + `context/chunker.py` (120), PHP `Tina4/Context.php` (607) +
  `Tina4/ContextChunker.php` (229), Ruby `lib/tina4/context.rb` (406) + `lib/tina4/context/chunker.rb`
  (145), Node `packages/core/src/context/index.ts` (424) + `chunker.ts` (161). No framework was run; the
  four existing test suites are reported, not re-run here.
- Dependencies: SQLite FTS5 (via each language's SQLite binding), the dev MCP server (feature 101, the
  only runtime caller), the dev-reload hook (`POST /__dev/api/reload`).
- Dependants: the `code_search` dev MCP tool; the dev-reload reindex hook. No application-facing route,
  CLI command, or startup path indexes Context.
- Existing ADRs: none. This feature has never had an ADR (see CTX-08).
- Shared fixtures: NONE. `context_contract.json` is owed (CTX-08). The behaviour is proven per-language
  by real, no-mock tests (Python 14, Ruby 16, PHP 15, Node 46 assertions), but no single oracle drives
  all four.
- Upstream: the retrieval core is a hand-port of the proven slice of **neemee (longmem-harness)** -
  `memory_systems.SqliteFTS` + `pipeline.retrieve`'s source-over-tests / definition-first reorderings.
  The standalone package `tina4stack/groundwire` is a SIBLING port of the same neemee slice, not the
  parent (see CTX-01 and the memory correction below).

- Catalog phase: Developer integrations

## Why this feature exists

Context gives a coding assistant a fast, local, offline answer to "where in this project is X?". It
walks your source and docs, chunks each file, folds the text to a normalized token stream, and stores
it in a SQLite FTS5 index. A query returns the top-k matching chunks, ranked so real definitions beat
mentions and source beats tests. It is the fuzzy/semantic complement to the exact structural lookup of
the live API index (feature 103): `api_*` tells you a method's precise signature, Context tells you
which files talk about a concept.

It ships in every language so the dev MCP `code_search` tool behaves the same whichever framework a
developer runs. It is zero-configuration: the index lives under a gitignored `.tina4/context.db`, it is
built lazily on first search, and the dev-reload hook keeps it fresh as files change.

## Boundary

This packet owns the `Context` class and its chunker in each language: the index build (`index_path`,
`index_root`, `reindex_file`), the query (`search`), the persisted FTS5 store, and the two
process-wide factories (`default_context`, `existing_context`). It owns the tokenizer/chunker
(`fold`, `terms`, `light_stem`, `chunk_code`, `chunk_text`).

It does NOT own: the dev MCP server or its authorization gate (feature 101); the live API/reflection
index and `api_*`/`docs_search` tools (feature 103, a different subsystem backed by reflection, not
FTS); the dev-reload transport (`POST /__dev/api/reload`, owned by the dev-admin surface). Context is a
callee of those, never the reverse.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | `tina4_python/context/__init__.py:84` class `Context` + `chunker.py` | `Tina4/Context.php:35` class `Context` + `Tina4/ContextChunker.php:19` | `lib/tina4/context.rb:34` class `Tina4::Context` + `context/chunker.rb:16` | `packages/core/src/context/index.ts:131` class `Context` + `chunker.ts` |
| Storage driver | stdlib `sqlite3` (no dependency) | ext-sqlite3 `\SQLite3` (PHP extension, no composer dep) | `sqlite3 ~> 2.0` gem (declared dependency) | built-in `node:sqlite` `DatabaseSync` (Node >= 22, no dependency) |
| Startup/CLI integration | none - lazy build on first `code_search`; kept fresh by dev-reload | same | same | same |
| Stored/wire format | FTS5 `chunks(cid UNINDEXED, path UNINDEXED, raw UNINDEXED, body)` at `./.tina4/context.db` | identical | identical | identical |
| Return shape | `[{path, score, snippet}]` | `[['path'=>, 'score'=>, 'snippet'=>]]` | `[{path:, score:, snippet:}]` | `SearchHit[] {path, score, snippet}` |
| Existing focused tests | `tests/test_context.py` 14 real | `tests/ContextTest.php` 14 + `ContextReloadReindexTest.php` 1 | `spec/context_spec.rb` 16 real | `test/context.test.ts` 46 assertions / 13 blocks |
| Existing lab baseline | not re-run in this audit | not re-run | not re-run | not re-run |

## Public surface contract

The four languages expose the same surface, spelled idiomatically. Language-neutral names, with the
idiomatic spelling in parentheses where it differs:

- Constructor `Context(path = "./.tina4/context.db", fts5_check = null)` - `fts5_check` is a test-only
  seam that overrides the FTS5 probe, never an env knob.
- `fts5_available()` (class/static) - true when the runtime SQLite has FTS5.
- `reset()` - drop and recreate the `chunks` table.
- `index_path(file, label = null)` (Python/Ruby `index_path`, PHP/Node `indexPath`) - UPSERT one file,
  returns the chunk-row count.
- `index_root(root)` (`indexRoot`) - walk a tree, UPSERT every eligible file with a root-relative
  label, returns the total.
- `reindex_file(changed_path)` (`reindexFile`) - re-index one changed file against the recorded root,
  or drop it if it was deleted or is no longer eligible.
- `search(query, k = 5)` - return the top-k hits.
- `count()`, `is_empty()` (`isEmpty`/`empty?`), `close()`.
- Factories `default_context(root = null, db = null)` and `existing_context(db = null)` - process-wide
  registry keyed by resolved db path, so the MCP tool and the reload hook share one live index.
- Chunker: `fold(text)`, `light_stem(token)`, `terms(text)`, `chunk_code(text, path = "", max_lines =
  60)`, `chunk_text(text, max_words = 350)`.

The surface is the SAME across all four Tina4 languages. It DIVERGES from the groundwire sibling, which
exposes `ingest`/`ingest_code`/`ingest_repo`, `retrieve`/`ask`, `source_of`, and `save`/`load` (see
CTX-01).

## Inputs and outputs

- `index_path`/`index_root` inputs: filesystem paths. Output: an integer chunk count. Side effect: rows
  written to the FTS5 store.
- `search` input: a free-text query string and an optional `k` (default 5). Output: an ordered list of
  hits, each with exactly three fields:
  - `path` (string) - the stored path, root-relative after `index_root`, else the label or absolute
    path passed to `index_path`.
  - `score` (float/number) - the sign-flipped bm25 rounded to 6 decimals; HIGHER is better.
  - `snippet` (string) - the raw chunk trimmed and truncated to 280 characters with a trailing " ...".
- Ordering: bm25 ascending in SQL (more negative is better), then a stable re-rank: non-test source
  before test-like paths (unless the query itself mentions "test"), then chunks that DEFINE a queried
  symbol before chunks that only mention it, then bm25 position breaks ties.
- Empty, whitespace-only, or stopword-only queries return an empty list in all four. An index with no
  FTS5 support returns an empty list from every method (fail-safe degradation).

## Lifecycle and operation graph

1. First `code_search` call constructs `default_context(root, db)`. The constructor probes FTS5; if
   absent it sets `available = false` and opens no database (every method then no-ops).
2. If the shared index is empty, `default_context` builds it by `index_root(root)` where root is the
   project `src/` when present, else the project root.
3. `index_root` walks the tree (sorted, pruning skip-dirs and dot-dirs), and for each eligible file
   calls `index_path`, which reads the file, chunks it, and does DELETE-by-path then INSERT (an UPSERT).
4. `search` builds a sanitized MATCH expression, pulls a pool of `max(k*3, 15)` bm25-ranked rows,
   applies the source-over-tests / definition-first re-rank, and returns the top k.
5. On each save, the dev-reload hook (`POST /__dev/api/reload`) calls `existing_context()` (never
   creates one) and `reindex_file(changed)` so the shared index stays current without a full rebuild.
6. `reindex_file` re-indexes the file if it is under the recorded root and still eligible, drops its
   rows if it was deleted, and is a no-op before any index exists.

The index is never built at framework startup and never by an application route or CLI command. Its
only runtime entry is the dev MCP `code_search` tool, and its only freshness path is the dev-reload
hook.

## Configuration and precedence

Context reads NO environment variables in any language (verified by grep over each context module).
Every knob is a constructor argument or a compile-time constant:

- Database path: constructor default `./.tina4/context.db`; the process-wide default key is
  `<cwd>/.tina4/context.db`; the live MCP caller passes `<project_root>/.tina4/context.db`.
- Index root: chosen by the MCP caller as `<project_root>/src` when it exists, else the project root.
- Chunk sizing: `max_lines = 60` (code), `max_words = 350` (prose), snippet limit 280, candidate pool
  `max(k*3, 15)`, default `k = 5`. These are literals, identical across the four languages.
- FTS5 toggle: none. Availability is detected at runtime, never configured; the `fts5_check` argument
  exists only so a test can drive the degradation path.

The FEATURE's EXPOSURE is gated elsewhere: the dev MCP surface is reachable only when MCP is enabled
(`TINA4_MCP` / `TINA4_DEBUG`) and the caller passes the two-layer authorization gate (feature 101,
MCP-02). Context itself holds no gate.

## Failures, side effects and security

- Missing directory (`index_root` on a path that does not exist): Python returns 0 (os.walk yields
  nothing), PHP returns 0 (`realpath === false` guard). Ruby raises `Errno::ENOENT`, Node throws
  `ENOENT` (both call the directory lister with no guard). This is CTX-02. Every live caller checks
  existence first, so it is latent, but the raw API contract diverges.
- Empty directory: 0 rows, returns 0 - all four.
- Unreadable file: handled in all four - the read is guarded and returns 0 for that file (Python
  `except OSError`, PHP `@file_get_contents === false`, Ruby `rescue SystemCallError`, Node `catch`).
- Huge file: NOT handled in any language (CTX-06). `index_path` reads the whole file into memory before
  chunking; `max_lines`/`max_words` cap per-chunk size, never total bytes or row count. Only `.min.js`
  is excluded by extension.
- Query injection: SAFE in all four. The MATCH expression is built only from `terms()`, which extracts
  `[a-z0-9]+` tokens and discards every FTS5 metacharacter (quote, `*`, `:`, `^`, `-`, `NEAR`,
  parentheses). Each surviving token is double-quoted (and a token can never contain a quote), then
  bound as a parameter (`MATCH ?`), never concatenated. The definition-first regex escapes
  query-derived symbols, so there is no regex injection or ReDoS from the query either.
- FTS5 absent entirely: every method degrades to a safe empty/zero; the constructor opens no database.
  The probe catches a missing SQLite extension too.
- Concurrency guard: Python holds a `threading.Lock`, Ruby a `Mutex`; PHP and Node hold none, each
  documented as intentional for a single-threaded/synchronous runtime (CTX-07, a note, not a defect).
- Write atomicity: PHP brackets `index_path` in BEGIN/COMMIT/ROLLBACK; the others do DELETE-then-INSERT
  and commit inline. All achieve per-file replace-not-append (proven by the UPSERT tests).

## Wire and persistence contract

One SQLite FTS5 virtual table, identical DDL in all four:

```
CREATE VIRTUAL TABLE IF NOT EXISTS chunks
  USING fts5(cid UNINDEXED, path UNINDEXED, raw UNINDEXED, body)
```

- `cid` = `"<path>:<i>"`, the citation id (UNINDEXED).
- `path` = the stored path, the UPSERT key (UNINDEXED).
- `raw` = the original chunk text, the snippet source (UNINDEXED).
- `body` = `fold(chunk)`, the only INDEXED column.

Persistence is the on-disk database file itself at `./.tina4/context.db` (gitignored). There is no
separate serialize/save/load step; writes are incremental per file. `reset()` drops and recreates the
table. The path folder is auto-created. Each language holds one connection for the life of the
`Context`; `close()` releases it.

This DIFFERS from the groundwire sibling, which exposes explicit `save(path)`/`load(path)` and returns
span-merged `(chunk_id, text, score)` tuples rather than a fixed on-disk file and flat `{path, score,
snippet}` hits (CTX-01).

## Providers and substitutability

There is one provider: SQLite FTS5, reached through each language's native binding (stdlib `sqlite3`,
ext-sqlite3, the `sqlite3` gem, built-in `node:sqlite`). The binding is NOT substitutable; the whole
subsystem is defined in terms of FTS5 `bm25()`. The only substitution seam is graceful DEGRADATION: if
FTS5 is not compiled into the runtime, `available` is false and Context becomes a no-op that returns
empty results, so a build without FTS5 disables `code_search` cleanly rather than crashing.

Capability exception: Ruby is the only language that declares an external runtime dependency (the
`sqlite3` gem), because Ruby ships no built-in SQLite. Python (stdlib), PHP (ext-sqlite3), and Node
(built-in `node:sqlite`) add no dependency. This is CTX-05, a posture note, not a defect - the gem is
the idiomatic and only route on Ruby.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CTX-01 | Surface divergence from the designated upstream. All four Tina4 languages AGREE with each other (`index_root`/`search`, flat `{path, score, snippet}`, a fixed `./.tina4/context.db`) but DIVERGE from the groundwire sibling (`ingest_repo`/`retrieve`/`ask`, span-merged `(chunk_id, text, score)` tuples, `save`/`load`, `source_of`, scope filter, answer-reduce). The standing memory says "track groundwire". | This is an OWNER DECISION (CTX-DEC-01). Recommendation: ratify the framework-idiomatic Context surface as intentional - Context indexes YOUR project for `code_search`, it is not a general RAG engine - and record groundwire's extras as explicit non-goals for the in-framework port. The policy "track groundwire" applies to the ALGORITHM slice (fold, chunk, bm25, source-over-tests / definition-first reorder), which IS tracked identically in all four. Capture this in the first Context ADR. |
| CTX-02 | Missing-directory contract splits 2-2. `index_root` on a non-existent path returns 0 in Python and PHP, but RAISES in Ruby (`Errno::ENOENT`) and THROWS in Node (`ENOENT`). Latent - every live caller guards existence first - but the raw API diverges from the Python master. | FIX RUBY and FIX NODE: guard the directory read and return 0, matching the master. Add a named regression in all four (`index_root("does/not/exist") -> 0`, no throw). |
| CTX-03 | `chunk_text` uses NO overlap in all four Tina4 languages; groundwire's `chunk_text` uses `overlap=1`. | No action. This is a deliberate simplification of the ported algorithm slice, consistent across all four. Record it in the ADR as an intentional deviation, not a bug. |
| CTX-04 | `SPECIAL_FILES` set drift: Ruby includes `gemfile`; Python, PHP, and Node do not. | OWNER DECISION (low priority): either add each language's manifest uniformly (`gemfile`, and Python has none to add) or drop it from Ruby. Recommendation: harmless as-is; if unified, add language manifests to all four for symmetry. |
| CTX-05 | Zero-dependency posture differs: Ruby declares the `sqlite3` gem; Python/PHP/Node add no dependency. | No action. Ruby has no built-in SQLite; the gem is the only idiomatic route and is the accepted database-driver exception to the zero-dependency rule. Note it in the ADR. |
| CTX-06 | No file-size cap in any language. A very large eligible file is read whole into memory and fully chunked. | Low-severity hardening for all four: skip a file above a byte ceiling (in the spirit of the existing `.min.js` exclusion), logged not silent. Owner to set the ceiling. |
| CTX-07 | Concurrency guard differs: Python `threading.Lock`, Ruby `Mutex`, PHP none, Node none. | No action. Each choice fits its runtime model and PHP/Node document the omission. Record in the ADR. |
| CTX-08 | No `context_contract.json`, no CONTRACT-MAP row, no ADR. The behaviour is proven per-language but by four separate suites, with no shared oracle. | Add `context_contract.json` (below) and the first Context ADR ratifying CTX-01/03/05/07 and the fixed store. |

Memory correction (recorded for the maintainer): the memory `project_context_tracks_groundwire` frames
groundwire as Context's upstream. The source in all four languages instead names **neemee
(longmem-harness)** as the origin and (in PHP/Ruby/Node) tina4-python as the reference port. Groundwire
and Context are SIBLING descendants of the same neemee slice. The "track groundwire" policy is best
read as "track the neemee algorithm slice that groundwire also packages", which the code does.

## Owner decisions

- CTX-DEC-01 (proposed): RATIFY the Context surface (`index_root`/`search`, flat `{path, score,
  snippet}`, fixed `./.tina4/context.db`) as the intended framework-idiomatic contract, and declare
  groundwire's `ask`/`save`/`load`/`source_of`/scope/span-merge as explicit NON-goals for the
  in-framework port. Track groundwire only for the algorithm slice. Write ADR-00xx.
- CTX-DEC-02 (proposed): ADOPT the Python master's missing-directory behaviour (return 0) as the
  contract; fix Ruby and Node (CTX-02).
- CTX-DEC-03 (proposed): DECIDE the `SPECIAL_FILES` policy (CTX-04) - unify language manifests or leave
  Ruby's `gemfile` as a harmless local addition.
- CTX-DEC-04 (proposed): SET a file-size ceiling for ingest (CTX-06) or accept the unbounded read.

## Proposed conformance fixture

`context_contract.json` - the same corpus and assertions drive a runner in each language against a real
temporary SQLite FTS5 store (no mocks). Cases:

- Positive: index a small tree with a definition file and a test file that both mention a symbol;
  assert the DEFINITION ranks first (definition-first + source-over-tests).
- Positive: index a `.md` doc as prose and a `.py`/`.php`/`.rb`/`.ts` file as code; assert both are
  searchable and code chunks carry the `# file:` header token.
- Result shape: every hit has exactly `path`, `score`, `snippet`; scores are descending; `snippet`
  is <= 280 chars.
- UPSERT: index a file, change it, re-index; assert the new content is found, the old is gone, and
  `count()` did not grow (replace-not-append).
- Skip rules: place files under `vendor/`, `node_modules/`, `__pycache__/`, a dot-dir, and a `.min.js`;
  assert none are indexed.
- Missing directory (CTX-02 witness): `index_root("does/not/exist")` returns 0 and does NOT throw in
  all four (fails on current Ruby and Node until fixed).
- Empty / whitespace / stopword query returns an empty list.
- Injection witness: a query containing `" OR x MATCH y; --` returns without error and matches only its
  alphanumeric tokens.
- Degradation: with the `fts5_check` seam forced false, every method no-ops and returns empty/zero.
- Mutation witnesses: removing the definition-first pass reorders the first case; removing the
  skip-dir prune indexes vendor files; removing the missing-dir guard (once added) re-throws.

## Integration map

- Exports: each language exports `Context`, `default_context`, `existing_context` (Node also
  `fts5_supported` and `_shared_contexts` through the package barrel; the chunker functions stay
  internal in Node, importable in the others).
- Startup: none. Context is never built at boot.
- Request lifecycle: none. No application route touches Context.
- Dev MCP: the `code_search` tool (feature 101) is the only runtime reader. It builds or reuses the
  shared index and calls `search`. It is authorization-gated by the two-layer MCP gate.
- Dev-reload: the `POST /__dev/api/reload` handler calls `existing_context().reindex_file(changed)` to
  keep the shared index fresh; failures are logged and never break reload.
- Scaffolders, status tools, generated consumers: none.
- Documentation: this feature currently has no dedicated docs page; the `code_search` tool is the
  user-visible surface. A short docs note belongs with the dev MCP tooling, not a public API page,
  because Context has no application-facing surface.

## Breaking changes and migration

- CTX-02 fix (Ruby, Node): changing `index_root` on a missing directory from "throw" to "return 0" is a
  behaviour change, but the only callers already guard existence, so no real consumer breaks. Ship with
  the named regression. Not a public-API break for applications (Context is dev-only).
- CTX-06 (size cap): additive and opt-out by ceiling; a previously-indexed oversized file would stop
  being indexed. Log the skip so the change is visible.
- No wire/storage change is proposed; the `chunks` table stays identical, so existing `.tina4/context.db`
  files remain valid.

## Implementation backlog

Dependency-ordered:

1. Write the first Context ADR ratifying CTX-DEC-01 (idiomatic surface, groundwire extras are
   non-goals, algorithm-slice tracking), CTX-03, CTX-05, CTX-07, and the fixed FTS5 store.
2. Fix CTX-02 in Ruby and Node (guard the missing directory, return 0) with a named regression in all
   four.
3. Author `context_contract.json` and a runner per language; flip owed to proven; add the CONTRACT-MAP
   row.
4. Decide and apply CTX-04 (SPECIAL_FILES) and CTX-06 (size ceiling) per the owner decisions.
5. Update the memory `project_context_tracks_groundwire` to record the neemee lineage and the
   surface-vs-algorithm distinction.

## Porting capsule

A clean-room implementation needs: the `Context` surface above; the FTS5 `chunks` DDL; the fold
(lowercase, strip diacritics via NFKD-to-ASCII, split camelCase, join comma-grouped numbers), `terms`
(`[a-z0-9]+`), and `light_stem` (strip one trailing `s`, never `ss`/`us`/`is`) tokenizer; the code
chunker (split on the top-level boundary regex, pack to 60 lines, prepend `# file: <path>`); the prose
chunker (sentence-split, pack to 350 words, no overlap); the extension/skip/special sets; the query
path (sanitized OR-of-quoted-tokens MATCH, bm25 pool of `max(k*3,15)`, source-over-tests then
definition-first re-rank, sign-flipped 6dp score, 280-char snippet); the process-wide registry keyed by
resolved db path; and fail-safe FTS5-absent degradation. The missing-directory contract is "return 0".
This packet is now sufficient for a clean-room implementation.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
