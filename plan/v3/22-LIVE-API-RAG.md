# Plan 22 — Tina4 Live Docs (Live API RAG)

> **Foundational principle:** the running framework IS the RAG.
> Static documentation is a generated snapshot, never the source of
> truth. AI coding tools (Claude Code, Cursor, Copilot, our own
> dev-admin) query the live framework for ground truth on the
> framework's API AND the user's own project surface.
>
> **Approach:** test-first, parallel PHP + Python. Spec frozen before
> code. Tests written against the spec; implementations made to pass
> them. Ruby + Node port afterwards from the same test corpus.

## Architecture (one paragraph)

Each Tina4 framework gains a `Docs` module that walks its own public
classes via stdlib reflection and exposes the result alongside the
existing `ProjectIndex` (user code) via:

- HTTP endpoints under `/__dev/api/docs/*` (auto-enabled with
  `TINA4_DEBUG=true`, same gate as the rest of dev-admin).
- MCP tools (`docs_search`, `docs_class`, `docs_method`) registered
  on the in-process MCP server.
- A `tina4 docs sync` CLI command that regenerates the
  `<!-- BEGIN GENERATED API -->` / `<!-- END GENERATED API -->`
  marked sections of `CLAUDE.md` and produces a `PROJECT.md` for
  the user's own code.

Every result carries a `source` tag — `framework` or `user` — so a
client can filter or rank as needed.

## Endpoint contract (frozen — tests live against this)

### `GET /__dev/api/docs/search?q=<query>&k=<int>&source=<framework|user|all>`

Free-text search over the merged framework + user index.

**Response (200):**
```json
{
  "ok": true,
  "query": "render template",
  "results": [
    {
      "source": "framework",
      "kind":   "method",
      "fqn":    "Tina4\\Response::render",
      "signature": "render(string $templateName, array $data = [], int $status = 200, string $templateDir = 'src/templates'): self",
      "summary":   "Render a Twig template via Frond.",
      "file":      "Tina4/Response.php",
      "line":      600,
      "version":   "3.11.30",
      "score":     0.91
    }
  ],
  "took_ms": 4
}
```

`kind` ∈ `class | method | function | property | route | template`.
`source = framework` for code under the framework's vendor dir,
`source = user` for code under the project's `src/` (or framework-
specific equivalent).

### `GET /__dev/api/docs/class?name=<fqn>`

Full reflection of a single class.

**Response (200):**
```json
{
  "ok": true,
  "class": {
    "fqn": "Tina4\\Response",
    "kind": "class",
    "file": "Tina4/Response.php",
    "summary": "HTTP response builder.",
    "source": "framework",
    "version": "3.11.30",
    "methods": [ {...}, ... ],
    "properties": [ {...}, ... ]
  }
}
```

**Response (404):** `{"ok": false, "error": "class not found: Foo"}`.

### `GET /__dev/api/docs/method?class=<fqn>&name=<method>`

Single method spec. Same envelope, fields:
`name | params | return | summary | docblock | file | line | visibility | static | source | version`.

### `GET /__dev/api/docs/openapi`

OpenAPI 3.0 spec generated from registered routes + controller
signatures. Already partly served by `Tina4\Swagger` — this endpoint
is a thin alias plus the `paths` section enriched with `Docs`-extracted
prose. Out of scope for v0; documented here for future phases.

### `GET /__dev/api/docs/index?source=<framework|user|all>`

Returns a flat index — fqn, kind, file, line — for every entity. Used
by `tina4 docs sync` and by clients that want to bulk-fetch.

## MCP tool contract

Naming distinguishes from the existing `docs_*` tools (which search
prose markdown — book chapters, CLAUDE.md, conceptual docs). Live
API RAG uses an `api_*` prefix so AI tools can pick the right one
for the question type:

- `api_search(q, k=5, source="all")` — search the live API
  reflection (framework + user code). Returns the same shape as the
  HTTP endpoint's `results` field.
- `api_class(name)` — full class spec (live reflection).
- `api_method(class, name)` — single method spec (live reflection).

Existing `docs_search` / `docs_section` / `docs_list` stay as-is —
they answer "explain queues conceptually" type questions from the
book. `api_*` answers "what's the signature of `Response::render`?"
The two are complementary, not competing.

## Source tagging rule

| Path matches | source |
|---|---|
| `Tina4/`, `tina4_python/`, `lib/tina4/`, `packages/core/src/`, `vendor/tina4stack/*` | `framework` |
| `src/` (project root), or whatever the project's PSR-4 root resolves to | `user` |
| Anything else | `vendor` (excluded from results unless `source=vendor` explicitly) |

## Ranking algorithm (v0)

No embeddings. No external models. Pure substring + token overlap:

1. Split query into lowercase tokens (whitespace + camelCase split).
2. For each indexed entity, score = sum of:
   - 5 if exact-match (case-insensitive) on `name`
   - 3 if any query token is a prefix of `name`
   - 2 per query token found in `summary`
   - 1 per query token found in `docblock` body
3. Boost by 1.2x if `source = user` (their own code is more relevant
   to "how do I do X in MY project?").
4. Top-K returned.

Sub-millisecond on a project with <1000 entities. Acceptable for the
target user.

## Storage / refresh — three tiers, three cadences

The "live" promise applies to user code. Vendor + framework code is
effectively static between dependency updates — re-reflecting it on
every server boot is waste. Three buckets, three refresh strategies:

| Bucket | What | Refresh trigger | Persistence |
|---|---|---|---|
| **User code** | `src/` (or framework PSR-4 root) | Live: mtime change of any watched file | In-memory only, rebuild on demand. ProjectIndex already does this |
| **Framework code** | `Tina4/`, `tina4_python/`, `lib/tina4/`, `packages/core/src/` — the running framework's own classes | Cache key = framework's installed-version + commit hash. Invalidate on framework upgrade | Disk cache: `.tina4/docs-cache/framework-<version>-<hash>.json` |
| **Vendor code** | `vendor/*` (PHP), `.venv/lib/...` (Python), `gems/...` (Ruby), `node_modules/*` (Node) — third-party libraries | Cache key = lock-file hash (`composer.lock` / `uv.lock` / `Gemfile.lock` / `package-lock.json`) | Disk cache: `.tina4/docs-cache/vendor-<lockhash>.json`. Re-built when lock file mtime changes |

### Cache invalidation rule

On every `tina4 serve` boot AND every first-request-of-the-minute:

1. Hash the framework's `composer.json`/`pyproject.toml`/`Gemfile`/`package.json` + lock file.
2. Compare to the stored cache key.
3. Match → load JSON cache from disk (typically <5ms).
4. Mismatch → re-reflect, write fresh cache, log "rebuilt vendor index — composer.lock changed".

User code is never cached on disk — it's too volatile and the
in-memory rebuild is cheap.

### Cache directory layout

```
.tina4/docs-cache/
├── framework-3.11.30-7b15868.json     # tina4-php's own classes, current version
├── vendor-c8a5d23f.json               # everything in vendor/*, keyed by composer.lock hash
└── meta.json                           # bookkeeping: last build time, hashes
```

Cache is .gitignored. First-run rebuild is the slowest call; after
that, vendor dimensions are zero-cost to query.

## Insights — beyond signatures

The Live RAG returns **insight**, not just reflection. An AI tool
asking "what calls `Database::execute`?" or "is `Auth::getToken()`
deprecated?" should get a real answer.

Insights computed during the index build:

| Insight | Source | Use case |
|---|---|---|
| **Call graph** — what calls X, what does X call | Static analysis of the AST (PHP-Parser / `ast` / `Prism` / `ts-morph` — all stdlib or already-vendored) | "Who depends on this method? Safe to delete?" |
| **Inheritance graph** — subclasses, supertypes, traits/mixins | Reflection | "What extends `\\Tina4\\ORM`?" |
| **Deprecation flags** — `@deprecated` docblock, `[Obsolete]` attribute, etc. | Docblock parse | "Is this method deprecated? What replaces it?" |
| **Since-version annotations** — `@since 3.11.22` | Docblock parse | "Is this method available on the user's framework version?" |
| **Test coverage flag** | Read from coverage report file if present | "Has this been tested? Confidence to refactor?" |
| **Visibility + nullability** | Reflection | Already returned in basic spec |
| **Examples** — extracted code blocks from the docblock | Docblock parse | "Show me how to use this method" |
| **Used-by-routes** — for handlers, which URL pattern dispatches them | Router introspection | "Which route serves /contact?" |

Returned in the per-method response under an `insights` field:

```json
{
  "fqn": "Tina4\\Database\\Database::execute",
  "signature": "execute(string $sql, array $params = []): bool|DatabaseResult",
  "summary": "Run a write SQL statement.",
  "insights": {
    "callers": [
      {"fqn": "Tina4\\ORM::save", "file": "Tina4/ORM.php", "line": 423},
      {"fqn": "App\\Routes\\Contact::store", "file": "src/routes/contact.php", "line": 17}
    ],
    "calls":   [
      {"fqn": "Tina4\\Database\\DatabaseAdapter::execute"}
    ],
    "deprecated":   false,
    "since":        "3.0.0",
    "tested":       true,
    "examples":     [
      "$db->execute('INSERT INTO users (name) VALUES (?)', ['Alice']);"
    ]
  }
}
```

Heavy insights (call graph) computed once at index build, cached
with the rest. User-code insights re-computed on mtime change.

## Tests (write FIRST — both PHP and Python in parallel)

Each test runs against a fresh framework instance booted in a temp
project that has a known shape (one user model, one user route, one
user template). The harness asserts both framework and user surfaces
appear in results.

### Test corpus (shared between PHP and Python — same names, same shape)

| Test | What it asserts |
|---|---|
| `test_search_finds_framework_render` | Searching "render template" returns a hit for `Response::render` (framework) in top 3 |
| `test_search_finds_user_model` | Searching "User" returns the user's `User` model from `src/orm/User.*` (source=user) in top 3 |
| `test_search_source_filter` | `source=framework` excludes user code; `source=user` excludes framework |
| `test_class_endpoint_returns_full_method_list` | `/docs/class?name=Tina4\Response` returns every public method, with signature, file, line |
| `test_class_endpoint_404` | Unknown class returns `ok: false` with status 404 |
| `test_method_endpoint_returns_signature` | `/docs/method?class=Tina4\Response&name=render` returns signature, params, return type, docblock |
| `test_user_class_appears_in_class_endpoint` | User's `\\App\\Models\\User` (or namespace equivalent) is reflectable via the same endpoint |
| `test_index_endpoint_lists_all` | `/docs/index` returns at least N framework entries + the user's surface |
| `test_mcp_docs_search_matches_http` | MCP `docs_search` returns the same hits as HTTP `/docs/search` for the same query |
| `test_mcp_docs_method_matches_http` | Same for `docs_method` |
| `test_index_refreshes_on_user_file_change` | Touch `src/orm/User.*`, add a new public method, immediate next search returns it |
| `test_drift_detector_finds_doc_inconsistency` | If `CLAUDE.md` has a fenced example referencing a method that doesn't exist, `tina4 docs check` exits non-zero with the offending line |
| `test_sync_overwrites_marked_section` | `tina4 docs sync` rewrites only the `<!-- BEGIN GEN -->` block of `CLAUDE.md`, leaves prose untouched |
| `test_search_response_under_50ms` | End-to-end search (HTTP → reflection → results) completes in < 50ms on a small project |
| `test_no_private_methods_in_default_search` | Methods marked `private` / `protected` (or `_underscore` Python convention) excluded unless `include_private=true` query param set |
| `test_no_vendor_third_party_in_results` | A class under `vendor/some-other-lib/*` doesn't show up |

**16 tests. Same names. Same assertions. Different language.** PHP
tests live in `tests/DocsTest.php`. Python tests in
`tests/test_docs.py`. Both fail until the impl lands.

## Implementation order

1. **Freeze the spec** (this document) — no changes to the contract
   above without redlining the design doc.
2. **Write the test files** in PHP and Python simultaneously. Both
   fail. Commit them on a `live-docs` branch.
3. **PHP impl** — `Tina4\Docs` module + endpoints + MCP wiring.
   Tests go green. Manual smoke against the `/tmp/tina4-supervisor-test`
   project: open `/__dev/api/docs/search?q=render` → see PHP's
   `Response::render` AND any `src/orm/User.php` the user has.
4. **Python impl** — same shape, `inspect` + `ast`. Tests go green.
5. **Cross-framework parity test** — boot both, hit both, assert
   identical (or compatible) responses. Passes.
6. **Ruby + Node ports** — done as a follow-up plan, against the
   same 16 tests translated to RSpec / vitest.
7. **CI gate added** — every PR runs the test suite + `tina4 docs
   check` for drift.

## Known divergences (post-implementation)

Discovered during cross-framework parity testing — tracked here so
they don't get re-discovered later.

- **Ranker — class-token vs method-name weight.** Query `"ORM save"`:
  Python surfaces `ORM.save` in top-5; PHP surfaces `session.save`,
  `seedOrm`, `tina4.ORM`, `app.shutdown`, `fromOrm`. PHP's ranker
  over-weights class-name token matches relative to Python's. Both
  follow the spec's letter (5/3/2/1 tiers) but the spec under-defines
  how to break ties when "ORM" matches a class name AND "save" matches
  a method name on a different class. Tighten the spec post-Step-2 —
  exact method-name match should win over class-token accumulation.
- **Doc method `params` / `return` empty in PHP.** Token-based parser
  populates `signature` correctly but doesn't decompose params/return
  into structured fields. Tests don't require it. Consider switching
  to `ReflectionMethod` for accuracy after autoload-stability is
  confirmed (token-parser was chosen specifically to avoid stale
  user-class state on rebuild — needs care if we switch).

## Out of scope for v0

- Embeddings / semantic ranking (substring is good enough — measured
  against real test queries before considering an upgrade).
- AI-tool config writers (`tina4 docs ai-config`) — separate plan.
- OpenAPI generation enrichment — already half-shipped via Swagger.
- Documenting *prose* (book chapters, conceptual docs) — that stays
  with `tina4-rag`. We only do API + project surface here.

## Verification before release

`pre-release-smoke.py` gains four checks:

1. `/__dev/api/docs/search?q=render` returns ≥1 framework hit.
2. `/__dev/api/docs/class?name=Tina4\Response` (or framework
   equivalent) returns the class spec with at least 5 methods.
3. `/__dev/api/docs/method?class=Tina4\Response&name=render` returns
   a non-empty signature.
4. `tina4 docs check` exits 0 (no drift between live and committed
   `CLAUDE.md`).

All four green = ship-ready for the framework that just changed. No
exceptions, no "PHP first ship later".

## Naming + user-visible surface (intentionally minimal)

The end-user runs **`tina4 serve`** and that's it. Live Docs auto-on
when `TINA4_DEBUG=true`. No flags, no subcommands, no config files
the user needs to author. Anything else is internal plumbing or
maintainer-only.

| Surface | Audience | Name |
|---|---|---|
| Module (per framework) | internal | `Tina4\Docs` / `tina4_python.docs` / `Tina4::Docs` / `@tina4/core/docs` |
| HTTP endpoint root | clients (AI tools, dev-admin) | `/__dev/api/docs/` |
| MCP tool prefix | clients | `docs_*` |
| Auto-discovery file | written by framework, read by AI tools | `.tina4/mcp.json` (MCP standard) — generated on first `tina4 serve`, gitignored |
| Public well-known doc | clients without MCP | `/__dev/api/docs/.well-known.json` — schema + endpoint list |
| `tina4 serve` | users | Boots framework + auto-serves Live Docs in debug mode |
| `tina4 docs` | users | Unchanged — downloads static book chapters into `.tina4-docs/` |
| `tina4 docs sync` | maintainers / CI only | Regenerates static `<!-- BEGIN GEN -->` blocks of `CLAUDE.md`. Hidden from `--help`. Used in CI's drift gate. |

Dropped (over-engineering): `tina4 docs serve`, `tina4 docs search`,
`tina4 docs check`, `tina4 docs ai-config`. None of these add value
the users actually want — `tina4 serve` already serves docs, search
goes via the AI tool itself, drift-check runs in CI, AI-config
auto-writes via the MCP discovery file.

## Auto-discovery file (written on first `tina4 serve` in debug)

When `tina4 serve` boots a project for the first time in debug mode,
the framework writes (idempotently — no-op if up to date):

`.tina4/mcp.json`:
```json
{
  "mcpServers": {
    "tina4-live-docs": {
      "url": "http://localhost:7145/__dev/api/mcp",
      "description": "Live API docs for this Tina4 project (framework + user code)"
    }
  }
}
```

`.gitignore` (auto-amended on first write — append-only):
```
.tina4/
```

The framework checks if `.gitignore` already excludes `.tina4/`
before adding the line, so we don't duplicate. Users who explicitly
want to commit the MCP config can remove the gitignore entry.

This is the entire AI-tool integration story. Modern MCP-aware
tools (Claude Code, Cursor with MCP support) discover the local
server automatically. Older tools either keep working without
ground-truth integration, or the user manually pastes the URL into
their config — same as today.

## Decisions for the user before we start

1. **16 tests enough?** Anything important missing from the test
   corpus above? Add now, not after impl.
2. **Source tags `framework | user | vendor` enough?** Or do we want
   a fourth bucket (e.g. `gallery` for built-in examples)?
3. **`include_private` opt-in via query param?** Some users will
   want to introspect their own private methods; reasonable to allow.
4. **Cap on response size?** Currently no limit — a class with 200
   methods returns all 200. Should there be a `?limit=` on the class
   endpoint?
5. **Should `docs_search` also surface routes (registered URL
   patterns), not just classes/methods?** I'd argue yes — "where's
   the route for /contact?" is a common AI question. Routes table
   already exists in the framework.

Once decisions are locked, I write the test files (parallel PHP +
Python), commit them red, then we kick off the implementation.
