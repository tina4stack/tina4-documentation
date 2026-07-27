# 3.13.52 - Dev Mailbox panel (captured emails in dev admin)

Status: SCOPED, targeted for 3.13.52 (after 3.13.51 MCP Streamable HTTP ships).

## Goal

When you send mail during local development, capture a copy to disk instead of
hitting SMTP, and browse those captured emails in a dev-admin tab that sits
next to Database and GraphQL. Testing an email flow becomes: send it, click the
Email tab, read what would have gone out. No mail server, no waiting.

## What already exists (do not rebuild)

Most of the plumbing is already in the Python master. The work is surfacing it
in the UI and reaching parity - not building from zero.

- `DevMailbox` (Python `tina4_python/messenger/__init__.py`): in dev mode
  (`TINA4_DEBUG=true`) `Messenger` captures each sent message to
  `data/mailbox/outbox/<id>.json` instead of sending via SMTP. Directory is
  overridable with `TINA4_MAILBOX_DIR` (default `data/mailbox`). It already has
  `inbox()`, `read()`, `seed()`, `clear()`, `count()`, `unread_count()`.
- Dev-admin API endpoints already mounted (Python):
  `GET /__dev/api/mailbox`, `GET /__dev/api/mailbox/read`,
  `POST /__dev/api/mailbox/seed`, `POST /__dev/api/mailbox/clear`, plus a
  `MessageLog` feed at `GET /__dev/api/messages`.
- The status endpoint already reports `mailbox` count, so the dashboard knows
  how many captured messages exist.

So the storage location the user asked for already exists: `data/mailbox/`
under the project (gitignore it like `data/queue/`).

## The actual gaps

1. **No dedicated dev-admin tab.** The API is live but there is no Email panel
   in the SPA the way there is for Database and GraphQL. This is the headline
   ask.
2. **Parity unknown / uneven.** Need to confirm PHP / Ruby / Node each: (a)
   capture to `data/mailbox/outbox` in dev by default, (b) expose the same four
   `/__dev/api/mailbox*` endpoints, (c) use the same on-disk JSON shape so one
   SPA panel works against all four.
3. **Disk capture must be the dev default, verified.** Confirm `send()` routes
   to the local mailbox when `TINA4_DEBUG` is truthy (and NOT in production)
   across all four. A real send in dev must never touch SMTP.
4. **Gitignore + example hygiene.** `data/mailbox/` should be gitignored in the
   scaffold and examples (the Python example currently tracks some outbox JSON
   - clean that up, mirror the `data/queue/` ignore).

## Proposed shape (Python master, then mirror)

- **On-disk record** (already close; lock it as the contract): one JSON file per
  message under `data/mailbox/outbox/`, fields: `id`, `type`, `to`, `cc`, `bcc`,
  `from`, `subject`, `body` (html), `text` (plain alt), `attachments`
  (name + size + mime, content base64), `headers`, `created_at`, `read`.
- **API contract** (identical across 4):
  - `GET /__dev/api/mailbox?folder=outbox&limit=&offset=` -> list + totals + unread
  - `GET /__dev/api/mailbox/read?id=` -> full message (marks read)
  - `POST /__dev/api/mailbox/seed {count}` -> generate fake messages (demo)
  - `POST /__dev/api/mailbox/clear {folder?}` -> delete captured mail
- **SPA Email tab** (in the dev-admin bundle, shared across all 4 via tina4-css):
  a message list (from, subject, time, read/unread) + a reading pane rendering
  the HTML body in a sandboxed iframe, a raw/headers toggle, attachment list,
  and Seed / Clear buttons. Mirror the Database tab's layout so it feels native.
- **Env**: `TINA4_MAILBOX_DIR` (default `data/mailbox`), capture auto-on when
  `TINA4_DEBUG` truthy; optional `TINA4_MAILBOX=off` escape hatch to force real
  SMTP in dev if someone needs it.

## Task breakdown (for the 3.13.52 branch)

1. Python master: confirm/settle the on-disk record + the four endpoints; add
   any missing field (text alt, attachments) and a real no-mock test that sends
   through `Messenger` in dev and asserts the JSON file lands + the API returns
   it. Gitignore `data/mailbox/`.
2. SPA: add the Email tab to the dev-admin bundle (source in tina4-css /
   dev-admin bundle), wired to the four endpoints, HTML body in a sandboxed
   iframe. Rebuild + propagate the bundle (same discipline as the IIFE bundle).
3. PHP / Ruby / Node parity: same capture-in-dev default, same four endpoints,
   same JSON shape; real no-mock tests per framework (send in dev -> file on
   disk -> endpoint returns it).
4. Cross-framework verify (independent), docs via content-writer (a short
   "Dev mailbox" section in the messaging chapter + release notes across the 8
   doc files), CLAUDE.md messaging note in all 4.
5. Release 3.13.52 lockstep.

## Open questions to confirm during build

- Does the dev-admin SPA already have a hidden/partial mailbox view we can
  finish, or is it net-new? (API exists; UI presence unconfirmed.)
- Node/Ruby/PHP: do they already capture to `data/mailbox/outbox` with the same
  JSON shape, or do their Messenger equivalents differ? (Parity audit is step 3.)
