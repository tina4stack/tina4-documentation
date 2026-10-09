# Feature port: Crud.to_crud (server-rendered HTML CRUD page) → Python / PHP / Node

> **REDESIGN 2026-10-08 (ADR-0094) — supersedes the string-building design below.**
> The earlier recovered ports (Python/PHP/Node commits in reflog) built the UI by
> string concatenation and re-implemented sql-mode write routes. Per the maintainer:
> `to_crud` is now a **frontend over AutoCrud** — it registers NO backend routes
> (AutoCrud owns all five: GET list, GET/{id}, POST, PUT, DELETE), requires a
> `model:`, takes an optional `sql:` listing query inferred from the model when
> omitted, and renders from **overridable Frond templates** (`crud/page`,
> `crud/table`, `crud/form`, `crud/modals`; app overrides via its own `templates/`,
> same app-first-then-gem resolution as the error pages). Zero inline `style=`/`on*=`;
> one nonce'd `<script>` wires actions via `data-crud-action` + delegated listeners.
> **Sequence:** redesign the Ruby master + ADR-0094 → maintainer signs off on the
> live render → port the new design to Py/PHP/Node (the reflog commits are a
> starting point, reworked). The sections below are the OLD design, kept for the
> CSP wiring vocabulary only.


Reference (the master, already CSP-clean): `tina4-ruby/lib/tina4/crud.rb`
(`module Tina4::Crud` — `to_crud`, `generate_table`, `generate_form`).

ADR-0004 (best implementation prevails, parity flows both ways): Ruby grew a
first-class HTML CRUD-page generator the other three never got. Port it so all
four have it at parity. `AutoCrud` (REST) is unchanged and already at parity; this
adds the *HTML page* on top, reusing AutoCrud for model-mode route registration.

## The contract (identical behaviour; idiomatic names per language)

Public surface — a `Crud` type alongside the existing `AutoCrud`:
| | Python | PHP | Ruby (ref) | Node |
|-|--------|-----|------------|------|
| entry | `Crud.to_crud(request, options)` | `Crud::toCrud($request, $options)` | `Crud.to_crud(request, options)` | `Crud.toCrud(request, options)` |
| table | `Crud.generate_table(records, table_name=, primary_key=, editable=True)` | `Crud::generateTable(...)` | `generate_table` | `Crud.generateTable(...)` |
| form | `Crud.generate_form(fields, action=, method=, table_name=)` | `Crud::generateForm(...)` | `generate_form` | `Crud.generateForm(...)` |

Options (single-word keys identical; multi-word keys idiomatic — `primary_key`
py/ruby, `primaryKey` php/node):
- `sql` OR `model` (one required; neither → raise/throw a clear error)
- `title` (default "CRUD"), `primary_key`/`primaryKey` (default "id"),
  `prefix` (default "/api"), `limit` (default 10)

Behaviour (match the Ruby master exactly):
1. Resolve `table_name` + `columns` from the model (field definitions) or by
   parsing the SQL SELECT list + FROM (reuse the Ruby `extract_table_name` /
   `extract_columns` logic).
2. Read pagination (`page>=1`, `limit`, `offset`), `search`, `sort`, `sort_dir`
   from the request query.
3. **Safe sort (ADR-0069):** `sort` reaches ORDER BY only as a column the source
   itself declares (a model's declared field resolved to its DB column, or a
   column of the SQL query's own result set); anything else falls back to the pk.
   It is a rendered page, not an API — a bad sort is silently ignored, never an error.
4. Search: LIKE `%term%` across the string/text columns (model) or all result
   columns (sql). Count total for pagination.
5. **Register the supporting REST routes idempotently.** model mode → reuse the
   framework's own `AutoCrud.register` + route generation. sql mode → register
   basic SQL-backed POST (create) / PUT `{id}` (update) / DELETE `{id}` with the
   write body allow-listed against the table's REAL columns (ADR-0069 /
   CRUD-DEC-02: unknown keys dropped, `is_deleted` never client-writable, the pk
   stripped on update). Track registered tables so a second call is a no-op.
6. Render a full HTML page: nonce'd `<style>`, a search form, a sortable table
   (header sort links carry the next sort_dir), rows with Edit/Delete buttons, a
   pagination control, a create modal, an edit modal, a delete-confirm modal, and
   a nonce'd `<script>` with the JS (fetch-based create/edit/delete + modal show/hide).
7. `generate_table` renders a standalone editable table fragment
   (contenteditable cells + Save/Delete per row) plus its own nonce'd `<script>`.

## CSP — clean from the first line (default-src 'self', ADR-0088)
A CSP nonce authorises a `<script>`/`<style>` ELEMENT but NEVER an inline `on*=`
attribute. So, exactly as the Ruby master now does:
- Every `<style>`/`<script>` carries `nonce="…"` from the framework's accessor:
  Python `tina4_python.core.csp.current_csp_nonce()`, PHP
  `Tina4\Csp::currentCspNonce()`, Node `currentCspNonce()` (from `core/src/csp.ts`).
- **ZERO inline `on*=` attributes.** Buttons carry `data-crud-action`
  (create/edit/delete/save/close/confirm-delete) + `data-id` / `data-crud-mode`
  / `data-crud-modal`; inline-edit buttons carry `data-crud-inline` + `data-table`
  / `data-id`; forms carry `data-crud-form`. One delegated `click` listener and one
  delegated `submit` listener in the nonce'd `<script>` dispatch them (copy the
  shape from `tina4-ruby/lib/tina4/crud.rb` `build_crud_javascript` /
  `inline_crud_javascript`). Interpolated values go through the framework's HTML
  escaper (Ruby uses `Frond.escape_html`; the old onclick interpolated raw — do NOT
  reintroduce that).

## Tests (real, no mocks, positive + negative) — mirror `tina4-ruby/spec/crud_csp_onclick_spec.rb`
Real SQLite on disk + a real Request object + the real Crud generator:
- `to_crud` (model mode) renders the seeded rows and the modals.
- `to_crud` registers the REST routes (assert the routes exist on the Router).
- Search / sort / pagination narrow/vary the output against real data.
- **Zero inline `on*=` attributes** (regex `\son[a-z]+\s*=\s*["']`), buttons wired
  via `data-crud-action` + a delegated `addEventListener` in a nonce'd `<script>`;
  mutation-proven (restoring an onclick turns it red).
- `generate_table` fragment: zero on*=, Save/Delete via `data-crud-inline`.

## Parity (all verified at HEAD; side-by-side token diff done)
| Feature | Python | PHP | Ruby | Node |
|---------|--------|-----|------|------|
| Crud.to_crud HTML page | ✅ 032005ee | ✅ 1a94e9fe | ✅ (master) | ✅ cd77ea7 |
| generate_table / generate_form | ✅ | ✅ | ✅ | ✅ |
| CSP-clean (no on*=, no inline style=) | ✅ | ✅ | ✅ aaf8c85 | ✅ |
| fragment helpers escape values (XSS) | ✅ | ✅ | ✅ aaf8c85 | ✅ |
| real no-mock test (mutation-proven) | ✅ 46 | ✅ 56 | ✅ 51 | ✅ 52 |
| data-crud-action vocab {create,edit,delete,save,close,confirm-delete} | ✅ | ✅ | ✅ | ✅ |

Idiomatic divergences (accepted, ADR-0004): method casing (`to_crud` py/rb vs
`toCrud` php/node), option key casing (`primary_key` py/rb vs `primaryKey`
php/node), and **Node `toCrud` returns `Promise<string>`** (its pg/mysql/mssql
adapters are async-only; a sync return would be SQLite-only). generate_table /
generate_form stay sync everywhere.

Reconciliation (parity flows both ways): the ports revealed the Ruby master was
weaker in two places, now fixed in aaf8c85 — fragment helpers escaped, search-form
inline `style=` moved to a nonce'd class. A third suspected gap (unauthenticated
sql-mode writes) was a FALSE ALARM: `Tina4::Route` auth-gates POST/PUT/PATCH/DELETE
by default, so Ruby already matched the ports.

## Branch / sequencing
- Build on `fix/csp-nonce-inline` in each repo (the CSP nonce accessor lives there,
  NOT yet on v3). The port ships with / after the CSP nonce work.
- Also retire or complete Python's orphan `components/crud.twig` (its
  `nice_label`/`detect_image`/`RANDOM`/`formToken` helpers are unregistered) — the
  new `Crud` class is the real generator; the twig should not masquerade as one.
- Commits: `Signed-off-by:` (DCO gate) + `Co-Authored-By: Claude Opus 4.8` +
  `Co-Authored-By: Tina4`. PR to v3, do not merge.

## Status: Complete (all four at parity, verified at HEAD). NOT pushed — awaiting
## maintainer decision on sequencing vs the in-flight CSP-nonce work (csp modules
## live only on fix/csp-nonce-inline, not yet on v3). PR to v3, do not merge.
