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

**v3.13.51 (2026-07-03)** - [full notes](/python/36-releases.md)

The built-in dev MCP server now speaks the current MCP Streamable HTTP transport, so Claude Code and today's MCP clients connect over a single `/__dev/mcp` endpoint out of the box. The legacy HTTP+SSE handshake stays for older clients. This release also fixes three Firebird issues (parameterized DML, NULL binding, migrations calling `execute`) and repairs migration recording on a `tina4_migration` table upgraded in place from the old v2 layout.

**Recent releases (v3.13.40 - v3.13.50)** - Swagger gained per-route security and reusable component schemas; queues were unified on one lifecycle across all four frameworks, with a reservation and visibility timeout so a dead consumer never strands a job; the test suite moved onto real services (no mocks) and caught a batch of live database and broker bugs; i18n was hardened with partial interpolation that never throws; the tina4-js runtime bundle was refreshed; and a Ruby fix made integer primary-key path parameters match on SQLite.

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
