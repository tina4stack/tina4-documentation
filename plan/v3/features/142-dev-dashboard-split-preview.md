# Feature 142: Dev dashboard - split preview, live editor, scaffold

## Outcome

The developer dashboard (`/__dev`) becomes a usable IDE surface: a split view
with the code editor on the left and a LIVE preview of the running project on the
right, where editing code updates the preview AND any open editor tab, while the
dashboard shell itself never does a disruptive full reload. The preview emulates
devices (mobile/tablet framed, desktop fills), detaches to its own window, and
the scaffold tools expose every generator the framework has, plus a Frond base
template + page generator.

Built and perfected in **Python first** (this doc is the spec); then PHP, Ruby
and Node reach parity. Some pieces are the SHARED `tina4-dev-admin` SPA bundle
(one change, all frameworks); others are per-framework `dev_admin` + CLI code
that must be ported.

## Where each piece lives (read before porting)

| Piece | Home | Parity model |
|---|---|---|
| The split page (`/__dev/split`) + the Dashboard-link change | each framework's `dev_admin` (Python: `tina4_python/dev_admin/__init__.py` `split_view_html()` + `toolbar_js()`; PHP `DevAdmin.php`; Ruby `dev_admin.rb`; Node `devAdmin.ts`) + the route in each server | PORT per framework |
| Editor disk-resync (open tabs reflect disk) | SHARED bundle `tina4-dev-admin/src/components/Editor.ts` | build once -> deploy to all four `public/js` |
| Scaffold panel data-driven (show all generators) | SHARED bundle `tina4-dev-admin/src/components/Editor.ts` + each framework's `/__dev/api/scaffold` list endpoint | bundle once + per-framework list endpoint |
| `generate page` / `generate base` | each framework's CLI generators (Python `tina4_python/cli/__init__.py` GENERATORS) | PORT per framework |
| The 2s reload-loop fix (`--no-history` + watcher ignore) | 4 adapters + Rust `tina4/src/watcher.rs` | ALREADY DONE (PRs below) |

## Status: In Progress - Python on the :7150 test env, mostly UNCOMMITTED

## Scope

### A. The 2-second reload loop (DONE, committed, PR'd)
- [x] Dashboard metrics scan wrote `.tina4-metrics.json` every scan -> the watcher
  reloaded the page -> re-scan -> a ~2s loop. Fixed: all four adapters pass
  `--no-history`; the Rust watcher ignores `.tina4-metrics.json` (+ regression
  test, mutation-proven). Proven live.
- PRs: tina4-python#210, tina4-php#292, tina4-ruby#117, tina4-nodejs#129,
  tina4 (CLI)#67.

### B. Split view + replace-the-overlay (Python, PR#211)
- [x] `GET /__dev/split` serves a plain split page: left `<iframe src="/__dev">`
  (dashboard/editor), right the live app preview. A plain page, not an app page,
  so no toolbar is injected and the container NEVER reloads.
- [x] The Dashboard toolbar link navigates to `/__dev/split` instead of building
  the in-app iframe overlay (the old overlay let the app-page reload nuke the
  dashboard - root cause of "the dashboard refreshes all the time").
- [x] Each pane keeps its own reload behaviour: the `/__dev` SPA refreshes
  gently; the app preview reloads itself on change. The shell stays put.

### C. Preview device frame + controls (Python, PR#211)
- [x] Device emulation: `mobile` (390x844) and `tablet` (820x1180) render inside
  a rounded bezel on a LIGHT backdrop, `overflow:hidden` so content is contained
  (not chopped); `desktop` FILLS the preview block (no bezel, no scaling).
- [x] Device toggle (fixed: a CSS size-transition was tainting the scale
  measurement -> "clicking did nothing"; removed it + reset transform before
  measuring). Default `desktop`. A live `WxH` dimensions readout.
- [x] Pop out: opens the SELECTED view in its own window sized to the device, to
  drag to another screen.
- [x] Resizable gutter between editor and preview (passes mouse over iframes
  while dragging).
- [x] Hide/show as ICON toggles - Files / Editor / Preview - independent. Files
  and Editor are separate sections inside the left SPA iframe (`#editor-sidebar`
  vs `.editor-main`), so hiding the editor KEEPS the file nav; the left pane
  shrinks to the nav width (250px) with no empty gap.

### D. Editor disk-resync (shared bundle, PR tina4-dev-admin#3)
- [x] On a file change, an open tab with NO unsaved edits adopts the disk
  content (caret preserved); a tab WITH unsaved edits is never clobbered and the
  tab flags a `changed on disk` conflict. Fixes "files are not refreshing in my
  editor" without losing unsaved work. `tina4-dev-admin/src/components/Editor.ts`
  `resyncOpenFilesFromDisk()`. Built + deployed to Python `public/js` only so far.
- [ ] Optional: refresh the file TREE for new/deleted files (deferred).

### E. Scaffold section data-driven + new generators (Python DONE, uncommitted->PR)
- [x] The scaffold list + run endpoints are DATA-DRIVEN from the CLI GENERATORS
  registry, so every generator appears and runs (Python had 4 hardcoded; now
  17: model, route, base, page, crud, migration, middleware, test, form, view,
  auth, service, queue, validator, seeder, websocket, listener).
- [x] The dashboard panel is a DROPDOWN + name input + Generate (not a button
  grid). The name field hides for no-name generators; each shows its summary.
  (shared bundle)
- [x] `generate base` - base.twig + index page (extends base) + `/` route +
  pages/ folder. `generate page <name>` - pages/<name>.twig extends base + its
  route; auto-creates pages/ and bootstraps base. `base` is a no-name generator.
- [x] A newly scaffolded file is surfaced into its folder with a SURGICAL reveal
  (expand + re-fetch just the path's folders), not a full tree refresh - fixes
  "the scaffolded file didn't show up immediately". (shared bundle)
- [x] Eye icon on previewable files (pages/*.twig, public/*.html): clicking
  drives the split's preview iframe to the rendered route, else a window.
  (shared bundle)

### F. Silent empty-SCSS compile (TODO, small, CLI-only)
- [ ] A selector-less SCSS rule compiles to EMPTY output but reports
  "compiled successfully" - warn on empty output / a rule with no selector.
  `tina4/src/scss.rs`.

## Parity

| Piece | Python | PHP | Ruby | Node |
|---|---|---|---|---|
| A. reload-loop fix | PR#210 | PR#292 | PR#117 | PR#129 |
| B. split view + link | [x] (uncommitted) | [ ] | [ ] | [ ] |
| C. device frame + controls | [x] (uncommitted) | [ ] | [ ] | [ ] |
| D. editor disk-resync (shared bundle) | [x] built+deployed | shared | shared | shared |
| E. scaffold data-driven + form | [x] (PR#211) | [ ] | [ ] | [ ] |
| E. page/base generators | [x] (PR#211) | [ ] | [ ] | [ ] |
| E. eye-to-preview + reveal (shared bundle) | [x] | shared | shared | shared |
| F. SCSS empty-warn (CLI) | n/a | n/a | n/a | n/a |

## Tests (write real, no-mock; verify on the lab)
- [ ] `/__dev/split` serves the split (both panes); the Dashboard link points at it.
- [ ] Editing a file updates the preview; the editor shell does not full-reload.
- [ ] Editor resync: clean buffer adopts disk; dirty buffer keeps edits + flags
  conflict (mutation: a buffer with edits must never be overwritten). Verified
  live in the browser on :7150.
- [ ] Device toggle switches size/dim/active reliably; desktop fills; pop-out
  opens a sized window.
- [ ] `generate page X` makes `pages/X.twig` extending base + a route; a second
  page reuses the SAME base; `pages/` auto-created; base bootstrapped if absent.
- [ ] The scaffold panel lists every generator the framework reports.

## Notes / decisions
- The split page carries NO CSP (it is a `/__dev` page), so its layout CSS/JS are
  inline - fine, and the app preview iframe keeps its own strict CSP.
- Reaching into the left iframe for the Files/Editor toggles works because both
  are same-origin; it couples to the SPA's `#editor-sidebar` / `.editor-main`
  element ids - keep those stable, or the toggles no-op (null-safe).
- The reload-loop fix (A) and the editor resync (D) together are what make the
  dashboard usable while an AI agent edits code: the agent's writes refresh the
  preview and any clean open tab, and never stomp unsaved work.
- SCAFFOLDING PER LANGUAGE (owner's note): a framework COULD expose different
  generators later - the panel is data-driven from each framework's own
  GENERATORS, so divergence is handled automatically. For now all four carry the
  SAME set; parity = give PHP/Ruby/Node the identical generators (incl.
  base/page) so their lists match Python's.
- The eye maps a page template to its route by the pages/ convention
  (pages/<name>.twig -> /<name>, index -> /). A page generated by `generate page`
  always matches, since it writes both the template and that route.

## Commits
- A (reload loop): PRs tina4-python#210, tina4-php#292, tina4-ruby#117,
  tina4-nodejs#129, tina4 (CLI)#67.
- B/C/E (Python framework: split view, data-driven scaffold, page/base
  generators): tina4-python#211 (538807a6).
- D/E (shared SPA bundle: disk-resync, scaffold form, eye-to-preview, reveal):
  tina4-dev-admin#3.

## Status: In Progress - Python shipped to PR; parity (PHP/Ruby/Node) next
