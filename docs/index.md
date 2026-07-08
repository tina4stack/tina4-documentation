---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "Tina4"
  text: "Documentation"
  tagline: One framework, four languages, fifty-five features, zero runtime dependencies.
  image:
    src: '/images/tina4-animated.svg'
  actions:
    - theme: brand
      text: Get Started
      link: get-started.md
    - theme: alt
      text: tina4-js
      link: /js/index.md
    - theme: alt
      text: Python
      link: /python/index.md
    - theme: alt
      text: Node.js
      link: /nodejs/index.md
    - theme: alt
      text: PHP
      link: /php/index.md
    - theme: alt
      text: Ruby
      link: /ruby/index.md
    - theme: alt
      text: Delphi
      link: /delphi/index.md
    - theme: alt
      text: Comparisons
      link: /comparisons.md


---

## What's new

**v3.13.56 (2026-07-08)** - [full notes](/python/36-releases.md)

The AI skills now tell your assistant how to report themselves when they drift. Every skill, and every project context file the installer writes (CLAUDE.md, .cursorules, copilot-instructions, and the rest), carries one line: if Tina4 behaves differently from the skill, that is a bug in the skill, so tell the developer and report it at [tina4.com/report-a-skill](/report-a-skill). This release also corrects the skills themselves (ORM soft-delete now names the real `is_deleted` column, the tina4-js persistence reference ships with the skill, and the per-framework copies are back in sync). The framework runtime is unchanged; refresh your skills with `curl -fsSL https://tina4.com/install-skills.sh | sh`.

**v3.13.55 (2026-07-07)** - [full notes](/python/36-releases.md)

The `tina4_migration` bookkeeping table now uses one schema on every framework and every engine: an auto-increment `id`, a unique `migration_name`, a `description`, a `batch`, an `executed_at` timestamp, and a `passed` flag. The auto-increment and column types follow the engine (`AUTOINCREMENT` on SQLite, `SERIAL` on PostgreSQL, `AUTO_INCREMENT` on MySQL, `IDENTITY(1,1)` on SQL Server, a generator on Firebird). Existing installs upgrade in place: the runner adds `migration_name`, copies the old name column across (`migration_id` in Python, `migration` in PHP, `name` in Node; Ruby already matched), and no already-applied migration re-runs. Shipped across all four frameworks.

**v3.13.54 (2026-07-07)** - [full notes](/python/36-releases.md)

Migrations now honour the Firebird `SET TERM` directive. A trigger or stored procedure whose body ends its inner statements with a semicolon used to split apart on that punctuation and fail; wrapping it in `SET TERM` switches the active terminator so the whole block travels as one statement, and the directive itself never reaches the engine. PHP and Ruby also repair the Firebird v2 to v3 migration-tracking upgrade, which read column names in the wrong case and re-ran every applied migration. Shipped across all four frameworks.

**v3.13.53 (2026-07-06)** - A model field can now hold a JSON document. Declare it (`JSONField` in Python, an `array`-typed property in PHP, `json_field` in Ruby, `{ type: "json" }` in Node) and the ORM stores an object or array in a JSON column: JSONB on PostgreSQL, JSON on MySQL, NVARCHAR(MAX) on SQL Server, a text BLOB on Firebird, and TEXT on SQLite. It encodes to JSON on write and decodes back to native data on read, so the attribute is never a raw string, and a value that cannot be encoded makes `save()` fail loud instead of writing a half-formed row.

**Recent releases (v3.13.40 - v3.13.52)** - Frond gained live blocks (`{% live %}` regions that render on the server and refresh over polling, Server-Sent Events, or a WebSocket you own); `pgsql://` returned as a PostgreSQL connection scheme; the built-in SCSS compiler learned the colour functions (`rgba(#hex, a)`, `rgb()`, `mix()`, `lighten()`, `darken()`); the dev MCP server moved to the current Streamable HTTP transport over a single `/__dev/mcp` endpoint, with the legacy HTTP+SSE handshake kept for older clients; Swagger gained per-route security and reusable component schemas; queues were unified on one lifecycle across all four frameworks, with a reservation and visibility timeout so a dead consumer never strands a job; the test suite moved onto real services (no mocks) and caught a batch of live database, broker, and Firebird bugs; and i18n was hardened with partial interpolation that never throws.

**Highlights since v3.12.3** - the v3.13 line unified the cache backend (memory, file, redis, valkey, memcached, mongodb, database), gave queues a full lifecycle (priority pop, retry backoff, automatic dead-lettering), added a request-scoped query cache, shipped live dev tooling over WebSocket and a Streamable HTTP `/__dev/mcp` endpoint, hardened the ORM and database layer to fail loud, and ran a broad security pass. See the [full release notes](/python/36-releases.md) for every version.

## How Tina4 reads

Pick a language. Each book stands on its own: you can read Python cover-to-cover, then pick up the PHP book later and recognise every pattern.

- **[Understanding Tina4](/general/index.md)** - Architecture, philosophy, the four-language promise. Read this first if you want the why.
- **[Python](/python/index.md)** - The reference implementation. Every feature lands here first.
- **[Node.js](/nodejs/index.md)** - TypeScript-first, native `node:http`, file-based routing, ESM-only.
- **[PHP](/php/index.md)** - PHP 8.5, `stream_select` server, zero composer deps in core.
- **[Ruby](/ruby/index.md)** - Rack 3, Puma in production, WEBrick in dev.
- **[tina4-js](/js/index.md)** - The 1.5 KB reactive frontend. Signals, Web Components, router, API client, WebSocket, PWA, SSE.
- **[Delphi](/delphi/index.md)** - FireMonkey cross-platform, FireDAC, REST client, and Twig templates.

Every book has a printable PDF with a clickable table of contents. Every chapter stays in sync with the code: release notes, version numbers, and example output are regenerated with every point release.

<FeaturesGrid />
