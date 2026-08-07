# Settled shape: Swagger, Migrations, Messenger parity for 3.13.96

Every open divergence, decided. One agent per repository implements this; the
decisions live here so four workers cannot make four different choices.

All statements below were MEASURED 2026-08-06 against real servers and a live
GreenMail, not read off the source. Where a framework is named as "right", it is
the one whose behaviour every other framework moves to.

**Ground rules for every item.** No mocks. Write the failing test first and
confirm it is red for the right reason. Prove each fix with a mutation. Run the
framework's full suite on the lab before reporting done. If an item turns out to
be wrong, say so and stop rather than forcing the stated shape.

---

## Swagger

### S1. The document must validate

Add a test that fetches `/swagger/openapi.json` from a real server and validates
it against the OpenAPI version it declares. A validator is a TEST dependency
only; the framework stays zero-dependency.

Measured: python VALID, php INVALID, ruby VALID, node INVALID. The two invalid
cases are already fixed (php `5a4f838d`, node `f217a5e`), so this test locks in
the repair and catches the next one. It is the single invariant that would have
caught both on its own.

App under test must carry: a public GET, a secured write, a path param, a typed
path param, a catch-all, and one ORM model.

### S2. `components.schemas` keyed by MODEL CLASS NAME

Measured, one model, four answers:

    python  keys ['Item']   properties + required:['name']      <- RIGHT
    php     keys ['Item']   properties, NO required array
    ruby    keys <NONE>     no schemas at all; body degrades to {"type":"object"}
    node    keys ['items']  keyed by tableName

**Python is right.** The class name is the type name a generated client wants,
and `required` is what makes the schema worth having.

- **php** — derive `required` from column nullability in `Swagger::modelSchema`
- **ruby** — emit `components.schemas` at all; `model_schema` exists at
  `lib/tina4/swagger.rb` and nothing on the AutoCrud path populates it
- **node** — key by class name, not `tableName` (`generator.ts`)

### S3. `servers[0].url` is `/`, `info.version` defaults to `1.0.0`

Measured defaults:

    info.version      python 1.0.0   php 1.0.0   ruby 3.13.95   node 0.0.1
    servers[0].url    python http://localhost:7145   php same   ruby /   node /

**Ruby and Node are right on `servers`**: `/` is correct under any port, host or
reverse proxy. Python and PHP hard-code 7145, which is measurably wrong off that
port - a PHP server bound to 7146 advertised 7145, so Swagger UI "Try it out"
posts to the wrong place.

**Python and PHP are right on `version`**: `1.0.0` is the app's version, not the
framework's. Ruby reporting `3.13.95` makes an undocumented app claim API
v3.13.95.

- **python, php** — `servers[0].url` defaults to `/`
- **ruby** — `info.version` defaults to `1.0.0`
- **node** — `info.version` defaults to `1.0.0`
- all four — `info.description` defaults to the empty string

`TINA4_SWAGGER_SERVERS` and `TINA4_SWAGGER_VERSION` still override.

### S4. Every documented `TINA4_SWAGGER_*` var is read

Measured: 15 of 17 matched everywhere. **php** alone ignores
`TINA4_SWAGGER_CONTACT_TEAM` and `TINA4_SWAGGER_CONTACT_URL`, so its
`info.contact` carried only the email. Both are documented in the root and
per-framework CLAUDE.md, so this is drift under the repo's own First Principle.

- **php** — read both, emitting `info.contact.name` and `info.contact.url`

### S5. One response set on an undecorated route

Measured:

    GET   python ["200"]  php ["200"]        ruby ["200","400","401","404","500"]  node ["200"]
    POST  python ["200"]  php ["200","401"]  ruby (same five)                      node ["201","401","422"]

**Settled: `200` for an undecorated route, plus `401` when and only when the
route is documented as secured.** Ruby claiming a public GET can return 401, and
Node claiming 422, are both fiction - nothing in the framework produces them.

- **ruby** — drop `default_responses`; emit `200`, and `401` on a secured route
- **node** — drop the unconditional `422`; keep `201` only if the route really
  answers 201, otherwise `200`
- **php** — already correct

### S6. `operationId` never collides

Measured on `/__health` versus `/health`:

    python get___health / get_health    php same     <- RIGHT, distinct
    ruby   get_health / get_health_2    node same    <- collapse, then suffix

**Python and PHP are right**: preserve leading underscores so two distinct paths
produce two distinct ids. `operationId` is a generated client's METHOD NAME, and
with the collapse, which endpoint gets `_2` depends on registration order.

- **ruby, node** — preserve underscores from the path when building the id

### S7. Only the application is documented

Measured internal paths documented: python 3, php 13, ruby 3, node 3. **php**
additionally publishes `/`, `/ai`, `/ai/api/chat`, `/embed`, `/image`,
`/image/v1/images/generations`, `/rag`, `/vision`, `/__feedback/api/turn` and
`/__feedback/widget.js`.

- **php** — exclude the framework's own service routes. Extend the shared
  exclusion beyond `/swagger` + `/__dev` to cover `/__feedback` and the AI/RAG
  service prefixes, and apply the SAME list in all four so the rule is shared
  rather than per-framework.

---

## Migrations

### M1. Complete the audit that has not been done

`kind` and the `createMigration` TypeError are fixed. Sequencing is verified at
parity. NOTHING ELSE HAS BEEN MEASURED SIDE BY SIDE. Do that first, against a
real SQLite database in each framework, and report before fixing:

- the `tina4_migration` tracking-table schema. All four CLAUDE.md files claim an
  identical column set (`id, migration_name VARCHAR(500) UNIQUE, description,
  batch, executed_at, passed`). VERIFY it rather than trusting four documents
  that were written by copying each other.
- `migrate()` return shape on success and on a failed file
- `rollback()` semantics: how many batches by default, what it returns
- `status()` output shape and key names
- whether a failed file stops the run in all four
- the up/down file pairing for both `sql` and `code` kinds

### M2. Write `migration_contract.json`

One invariant per divergence found, in the shape of
`plan/v3/fixtures/queue_contract.json`, plus a runner per framework. Mark
proven only where a suite exists in ALL FOUR.

---

## Messenger

The IMAP read path. `uid` semantics, uid type and page order are fixed. These
remain, all measured.

### G1. `inbox` and `read` are callable POSITIONALLY

    inbox("INBOX", 10, 0)   ruby -> ArgumentError (keyword-only)
    read(uid, "INBOX")      ruby -> ArgumentError

- **ruby** — accept positional arguments; keep the keyword form working. Node
  was changed to folder-first in 3.13.95 to satisfy a contract Ruby cannot
  satisfy at all, so this closes a loop that has already caused churn.

### G2. A missing UID reads as null

Measured: python `{}`, php `null`, ruby `nil`, node `null`. Both are falsy in
Python so it hid, but `result is None` gets the wrong answer and JSON carries
`{}` where the others carry `null`.

- **python** — return `None`

### G3. `snippet` is decoded text, or the field does not exist

Measured: python returns raw base64 (`Ym9keSBvZiBQMw==`) because it fetches
`BODY.PEEK[TEXT]<0.200>` and never decodes. Node returns `""` ALWAYS because it
fetches header fields only, so the field is structurally unpopulatable. PHP and
Ruby do not have the field.

**Settled: all four emit `snippet`, as decoded, transfer-decoded, tag-stripped
plain text, truncated to 200 characters.**

- **python** — decode it
- **node** — fetch the body text it needs
- **php, ruby** — add the field

### G4. One `inbox()` item shape

Only FOUR fields are common to all four today. **Settled shape**, every
framework, exactly these keys:

    uid       string, the real IMAP UID
    subject   string
    from      string
    to        string
    date      string, ISO-8601
    snippet   string
    seen      boolean

- **php** — add `to`; drop `msgno`/`flagged`/`size`
- **ruby** — rename `read` to `seen`; return `from`/`to` as STRINGS, not arrays
  of `{name,email}`; drop `flags`/`size`
- **python, php, ruby, node** — emit `date` as ISO-8601 (only Python does today)

### G5. One `read()` item shape

Three body-field conventions today: `body_text`/`body_html` (python, php),
`body`/`html` (ruby), `bodyText`/`bodyHtml` (node).

**Settled: each framework uses ITS OWN idiomatic casing of the same concept
names** - `body_text`/`body_html` in python/php/ruby, `bodyText`/`bodyHtml` in
node. That is the house rule for field naming (ADR-0008, idiomatic casing), so
the CONCEPTS must match even though the spelling does not.

- **ruby** — rename `body`/`html` to `body_text`/`body_html`
- **ruby, node** — return `attachments` (both return none today)
- **php, ruby** — return `headers`

### G6. One `send()` result shape

    python  {success, error, message_id}   message_id EMPTY on a real send
                                            adds dev:true on the capture path
    php     {success, message, id}
    ruby    {success, message, id}
    node    {success, message, id}         omits id on failure

**PHP and Ruby are right.** Settled: `{success, message, id}` on BOTH paths in
all four. On success `id` is the real Message-ID; on failure the keys are
present with null values. No path-specific extra keys.

- **python** — rename `error` to `message`, `message_id` to `id`; populate `id`
  from the real Message-ID; drop the capture-only `dev` key
- **node** — include `id: null` on failure

### G7. Every method exists everywhere, under one name

Measured: `mark_unread` and `send_template` are Python-only; `delete` exists in
two of four under two names (`delete` / `deleteMessage`).

- **php, ruby, node** — add `mark_unread` and `send_template` in their idiomatic
  casing
- **all four** — one concept name for delete: `delete` in python/php/ruby,
  `delete` in node too (rename `deleteMessage`, keep the old name as a
  deprecated alias for one release)

### G8. `TINA4_MAIL_IMAP_USERNAME` / `_PASSWORD` are honoured

Measured with an IMAP account separate from the SMTP one: node read the right
mailbox (0 messages), python/php/ruby read the SMTP one (2 messages). Both vars
are documented in all four `.env.example` files and allow-listed by all four env
guards, and read by Node only. Three frameworks silently authenticate to the
wrong account.

- **python, php, ruby** — read both, falling back to `TINA4_MAIL_USERNAME` /
  `_PASSWORD` when unset

### G9. Every env-read setting is constructor-settable

- **python, php** — add an `imap_encryption` constructor parameter; explicit
  beats env (ADR-0041)

### G10. Pin what already passes

Two rules hold in all four today and nothing gates them. Write the tests:

- read methods RAISE `MessengerConnectionError` on a real connection failure
  (measured against a genuinely closed port), while `send()` returns a result
- the capture gate: capture with no SMTP host, send with one, `TINA4_DEBUG` does
  NOT suppress sending, `TINA4_MAIL_CAPTURE=true` forces capture

### G11. Write `messenger_contract.json` proofs

The fixture exists with 14 invariants, all owed. Move each to proven as its
suite lands in all four.

---

## Reporting

Per repository: what you changed, the mutation that proves each test, the full
suite result from the lab with its exit code, and anything you found that is not
on this list. If a decision above turns out to be wrong when measured, say so
and stop - do not force it.
