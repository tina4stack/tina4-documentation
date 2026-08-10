# Documentation Verification Test Plan — section-by-section, 4 frameworks, live PostgreSQL

**Goal.** Go through the documentation *section by section* (book chapter = section) and, for each, take the documented code sample(s) for **all four frameworks** (Python, PHP, Ruby, Node.js), run them in a real running app against a **PostgreSQL** database, and answer one question per cell:

> **Could a developer, following only the docs, get this working — and does it behave exactly as the docs claim?**

This is stronger than the static symbol audit already completed (which proved the documented symbols *exist*). Here we prove the documented samples *run and produce the documented result*, and we flag where the docs are **insufficient** (missing a step, wrong output, missing prerequisite, silent divergence between frameworks).

---

## 1. Success criteria & scoring

Each section × framework cell gets one verdict:

| Verdict | Meaning |
|---|---|
| **PASS** | Documented sample runs as written and output matches the doc's claim. |
| **FAIL-CODE** | Sample is faithful to the doc but the framework misbehaves (a real bug). |
| **GAP-DOC** | Sample doesn't work as written *because the doc is insufficient/wrong* — missing import, missing setup step, wrong output shown, undocumented prerequisite. |
| **DIVERGE** | Works, but behaves differently from the other frameworks where the docs imply parity. |
| **N/A** | Feature legitimately not applicable to this framework (documented as such). |

"Documentation sufficient" = the cell is PASS using **only** what the chapter shows (plus the chapter's own getting-started). Any extra knowledge needed → GAP-DOC, with the missing piece recorded.

---

## 2. Environment architecture

**One PostgreSQL 16 container, four isolated databases** (clean blast radius per framework):

```
docker run -d --name tina4-doctest-pg \
  -e POSTGRES_USER=tina4 -e POSTGRES_PASSWORD=$PGPASS -e POSTGRES_DB=tina4 \
  -p 5432:5432 postgres:16
# then create per-framework DBs: tina4_py, tina4_php, tina4_rb, tina4_node
```

**Four scaffolded apps** (one per framework), each via the real `tina4 init` so we exercise the documented bootstrap, each pinned to its own DB + port:

| Framework | Scaffold | Port | `TINA4_DATABASE_URL` | Runtime |
|---|---|---|---|---|
| Python | `tina4 init python` | 7101 | `postgresql://tina4:$PGPASS@localhost:5432/tina4_py` | 3.14 + `uv` (psycopg2 extra) |
| PHP | `tina4 init php` | 7102 | `postgres://tina4:$PGPASS@localhost:5432/tina4_php` | 8.5 + ext-pgsql |
| Ruby | `tina4 init ruby` | 7103 | `postgres://tina4:$PGPASS@localhost:5432/tina4_rb` | 4.0 + `pg` gem |
| Node | `tina4 init node` | 7104 | `postgres://tina4:$PGPASS@localhost:5432/tina4_node` | 24 + `pg` |

Apps run under the installed-from-registry framework versions (Python 3.13.15, others 3.13.14) so we test **what users actually get**, not the working tree — with a noted option to re-point at local checkouts if we want to test unreleased fixes.

**Harness.** A small per-section driver: drop the documented sample into the app (a route, model, migration, or standalone script), start the server / run the script, exercise it (HTTP request via `curl`/Api, or read stdout), capture actual output, diff against the doc's claimed output, record the verdict. Servers are started/stopped per section group to keep state clean.

---

## 3. Section inventory — everything we test

38 chapters (Ruby/Node omit `37-upgrading-from-v2`). Grouped by test tier. "PG" = exercises PostgreSQL directly.

### Tier 1 — Database / PostgreSQL-backed (the core of this audit)

| # | Chapter | What we run & verify | PG |
|---|---|---|---|
| 05 | Database | connect via `TINA4_DATABASE_URL`; `execute`/`fetch`/`fetch_one`/`insert`/`update`/`delete`; `start_transaction`/`commit`/`rollback`; `table_exists`/`get_tables`/`get_columns`; `get_next_id`; **#51: confirm reads don't leave `idle in transaction`** (Python) | ✅ |
| 06 | ORM | model def; `save`/`find`/`where`/`all`/`select`/`count`; soft-delete; relationships (`has_many`/`belongs_to`/foreign keys + eager load); `to_dict`/`to_json` | ✅ |
| 07 | Query Builder | `fromTable`/`select`/`join`/`leftJoin`/`where`/`groupBy`/`having`/`orderBy`/`limit`/`get`/`first`/`count`; `toMongo` shape | ✅ |
| 09 | Sessions & Cookies | file backend + **database session backend → PG**; set/get/flash/regenerate/destroy | ✅ |
| 12 | Queues | `push`/`pop`/`consume`/`size`/`retry`/`dead_letters` (file backend default; note PG/DB option) | ◑ |
| 19 | Scaffolding & Migrations | `migrate`, `create_migration`, `ORM.create_table` against PG; CRUD generator; engine-specific DDL (SERIAL) | ✅ |
| 20 | Swagger / OpenAPI | spec generated from routes + ORM models (reads schema) | ◑ |

### Tier 2 — HTTP / runtime (app server; some touch PG)

| # | Chapter | What we run & verify |
|---|---|---|
| 02 | Routing | `{id}`/`{id:int}`/catch-all params; method routes; groups |
| 03 | Request/Response | `request.body`/`params`/`headers`/`files`/`cookies`; `response()` json/html/status/redirect/`xml`/`stream` |
| 04 | Templates (Frond) | `render`/inheritance/`include`/filters/globals; `form_token` |
| 08 | Authentication | `getToken`/`validToken`/`getPayload`/`refreshToken`; password hash/check; route auth defaults (`noauth`/`secured`) |
| 10 | Middleware & Security | `before_*`/`after_*` chain; CORS; rate limiter; CSRF/form token |
| 11 | Caching | response cache middleware + `cache_get`/`cache_set`/`cache_stats`/`clear_cache` |
| 13 | Events | `on`/`once`/`emit`/`off`/`listeners`/`events`/`clear` (+ priority order) |
| 14 | Localization | translation lookup, interpolation, locale switch, fallback |
| 15 | Logging | `Log.debug/info/warning/error`; level filtering via `TINA4_LOG_LEVEL`; stdout |
| 16 | Email | dev mailbox capture / SMTP send |
| 18 | Testing | inline test framework: assertions + run-all; HTTP test client |
| 21 | API Client | `Api` class GET/POST/etc against a local endpoint; result shape |
| 22 | GraphQL | schema from ORM; query/mutation/variables; GraphiQL endpoint |
| 23 | WebSocket | connect/echo/broadcast; rooms |
| 24 | SSE | `response.stream()` event stream |
| 25 | WSDL / SOAP | `?wsdl` generation; SOAP POST invoke |
| 26 | DI Container | `register`/`singleton`/`get`/`has`/`reset` |
| 27 | Service Runner | background/periodic service registration + lifecycle |

### Tier 3 — Tooling / conceptual (doc-accuracy check, lighter runtime)

| # | Chapter | Check |
|---|---|---|
| 01 | Getting Started | the scaffold-and-run flow actually works (this is also our env setup) |
| 17 | Frontend (tina4-js) | browser/JS — separate harness; verify documented signals/html/api snippets load (out of PG scope) |
| 28 | MCP Dev Tools | `/__dev` MCP tools start on `TINA4_DEBUG`; documented tool list matches |
| 29 | Custom MCP Servers | `McpServer`/`mcp_tool`/`mcp_resource` developer API |
| 30 | Dev Tools | dev toolbar / dashboard / inspectors present in debug mode |
| 31 | CLI | every documented `tina4 <cmd>` runs (already gate-verified; re-run key ones) |
| 32 | Vibe Coding w/ AI | `ai` detect/install context commands run |
| 33 | Environment Variables | documented `TINA4_*` actually read (gate-verified; spot-run a few) |
| 34 | Deployment | Dockerfile/.dockerignore generated; production server flag |
| 36 | Releases | release notes accuracy (informational) |
| 37 | Upgrading from v2 | (Python/PHP only) — informational |
| 38 | Feature List | every claimed feature maps to a tested section |

**Rough cell count:** ~30 runnable sections × 4 frameworks ≈ **120 sample executions**, plus Tier-3 checks.

---

## 4. Execution phases (top-to-bottom)

1. **Phase 0 — Stand up.** PG container + 4 DBs; scaffold + boot all 4 apps; confirm each serves `/` and connects to PG. (Gates everything; if `tina4 init` or PG connect fails, that's finding #1.)
2. **Phase 1 — Tier 1 (DB/PG).** Chapters 05→07, 09, 12, 19, 20. Highest value; PG is the throughline.
3. **Phase 2 — Tier 2 (HTTP).** Chapters 02–04, 08, 10–11, 13–16, 18, 21–27.
4. **Phase 3 — Tier 3 (tooling/docs).** Chapters 01, 17, 28–34, 36–38.
5. **Phase 4 — Synthesize.** Side-by-side matrix + per-finding doc-sufficiency report; fix doc gaps (doc-side) and file real bugs.

Each section is done across all 4 frameworks before moving to the next (true side-by-side), so divergences surface immediately.

---

## 5. Deliverable

A results matrix (one row per chapter, four framework columns + verdict + notes) plus a findings log:

```
| Ch | Feature        | Python | PHP | Ruby | Node | Doc-sufficient? | Notes / gap |
|----|----------------|--------|-----|------|------|-----------------|-------------|
| 05 | Database CRUD  | PASS   | PASS| PASS | PASS | yes             | …           |
| 06 | ORM relations  | PASS   | GAP | PASS | FAIL | PHP: missing…   | …           |
```

Maintained as `DOC-VERIFICATION-RESULTS.md` (live, updated per section), with each GAP-DOC/FAIL-CODE linked to the exact chapter line and a proposed fix.

---

## 6. Decisions needed before Phase 0

- **PG**: Docker `postgres:16`, one container, four databases — OK? (Alternative: schemas in one DB.)
- **Versions under test**: registry-installed (what users get) vs local checkouts (includes unreleased fixes). Recommend **registry** for a true doc audit.
- **Scope**: all ~30 runnable sections, or start with Tier 1 (DB/PG) and expand? 
- **tina4-js (ch17) frontend**: include via a browser harness, or mark out-of-scope for this PG-focused pass?
- **Orchestration**: this is ~120 runs — run sequentially, or fan out with multi-agent orchestration (opt-in) to do framework columns in parallel per section?
