# Tina4 v3.0 — Plan Index

> **Last updated:** 2026-04-03
> **Current release:** v3.10.67 | tina4-js v1.0.15

> **Spec backbone:** [CONTRACT-MAP.md](CONTRACT-MAP.md) is the live map from every
> audited feature to its machine-checked contract fixture, ADRs, and
> proven-in-all-four status - the seed of a future formal language spec. Keep it
> synced with the audit ([98-feature-audit.md](98-feature-audit.md)) and the
> contract auditor. The status figures below are from 2026-04-03 and are stale;
> CONTRACT-MAP carries the current fixture counts.
>
> **New-language target:** [PORTING-FORMULA.md](PORTING-FORMULA.md) defines the
> clean-room output required from the audit: enough surface, lifecycle, wire,
> failure, fixture and integration detail to implement Tina4 in another language
> without copying an existing runtime.
>
> **Release target:** 3.14.0 is the stable-contract boundary. Correctness and
> parity may require breaking any earlier 3.x behavior; every such break is
> fixture-proven and carries an explicit migration path.

## Status

| Framework | Completeness | Tests | Zero-dep core |
|-----------|:---:|:---:|:---:|
| **Python** | **100%** | 2,149 passing | Yes |
| **PHP** | **100%** | ~2,200 passing | Yes |
| **Ruby** | **100%** | 2,400 passing | Yes |
| **Node.js** | **100%** | 2,580 passing | Yes |
| **tina4-js** | **100%** | 238 passing | Yes |

**Grand total: ~9,567 tests across all frameworks.** All 4 backends at full feature parity. Zero third-party dependencies.

## The Four Frameworks
1. **tina4-php** — PHP 8.2+
2. **tina4-nodejs** — Node.js 20+ / TypeScript
3. **tina4-python** — Python 3.10+
4. **tina4-ruby** — Ruby 3.2+

## Core Philosophy
- **Zero third-party dependencies** — every core feature built from scratch
- **Full feature parity** — same features across all four languages
- **SQL-first ORM** — embrace SQL, paginate and cache results
- **Security first** — auto-escaping, input validation, no arbitrary code execution
- **DX is the top priority** — identical debug overlays, identical test coverage, seamless cross-platform
- **Monorepo development** — build uniform, split out when stable

## Plan Documents

| # | Document | Description |
|---|----------|-------------|
| 00 | [VISION.md](00-VISION.md) | Mission, principles, lessons from other frameworks |
| 01 | [FEATURE-MATRIX.md](01-FEATURE-MATRIX.md) | What exists vs what's missing per framework (**updated**) |
| 02 | [FROND-FEATURES-DECISION.md](02-FROND-FEATURES-DECISION.md) | Full Frond template engine feature set for approval |
| 02b | [FROND-SPEC.md](02-FROND-SPEC.md) | Frond syntax reference and API specification |
| 03 | [TINA4HELPER-SPEC.md](03-TINA4HELPER-SPEC.md) | frond.js unified frontend helper specification |
| 04 | [ARCHITECTURE.md](04-ARCHITECTURE.md) | Monorepo structure, zero-dep strategy, contracts, debug overlay |
| 05 | [GAMEPLAN-PYTHON.md](05-GAMEPLAN-PYTHON.md) | tina4-python v3 — **100% complete** (73/73 tasks) |
| 06 | [GAMEPLAN-PHP.md](06-GAMEPLAN-PHP.md) | tina4-php v3 implementation gameplan (73 tasks) |
| 07 | [GAMEPLAN-RUBY.md](07-GAMEPLAN-RUBY.md) | tina4-ruby v3 implementation gameplan (74 tasks) |
| 08 | [GAMEPLAN-NODEJS.md](08-GAMEPLAN-NODEJS.md) | tina4-nodejs v3 implementation gameplan (75 tasks) |
| 09 | [AI-REFERENCE-SPEC.md](09-AI-REFERENCE-SPEC.md) | CLAUDE.md / llm.txt content — full paradigm reference for AI assistants |
| 10 | [EXAMPLES-AND-DOCS.md](10-EXAMPLES-AND-DOCS.md) | Real-world examples (identical across all four) + README requirements |
| 11 | [QUEUE-SPEC.md](11-QUEUE-SPEC.md) | Queue system: DB core + RabbitMQ/Kafka extensions |
| 12 | [BENCHMARKS-SPEC.md](12-BENCHMARKS-SPEC.md) | Benchmark suite: 9 categories (incl. Carbonah carbon ranking), top 10 frameworks per language |
| 13 | [CONSOLE-AND-ERROR-HANDLING.md](13-CONSOLE-AND-ERROR-HANDLING.md) | Backend console, global exception handler, .broken file system, health check integration |
| 14 | [WEBSOCKET-SPEC.md](14-WEBSOCKET-SPEC.md) | Zero-dep RFC 6455 WebSocket: frame protocol, connection manager, live block integration |
| 15 | [DEPLOYMENT-SPEC.md](15-DEPLOYMENT-SPEC.md) | Dev vs prod servers, Docker (40-80MB), K8s, CLI build/stage/deploy |
| 16 | [DEV-WORKFLOW.md](16-DEV-WORKFLOW.md) | Development → Staging → Production best practices and CLI workflow |
| 17 | [TINA4PRESS.md](17-TINA4PRESS.md) | VitePress-style docs site generator built on tina4-js, powers tina4.com |
| 99 | [PORTING-FORMULA.md](PORTING-FORMULA.md) | Clean-room formula and acceptance gates for implementing Tina4 in another language |
| 99b | [features/FEATURE-TEMPLATE.md](features/FEATURE-TEMPLATE.md) | Required one-feature/one-file contract and porting packet schema |
| 99c | [AUDITED-FEATURE-REAUDIT-TABLE.md](AUDITED-FEATURE-REAUDIT-TABLE.md) | Table of every feature the audit file actually records as historically audited |

## Key Decisions Made
- Template engine name: **Frond** (twig-like, zero-dep, identical syntax across all four)
- Frontend: **tina4-js** (1.5KB core gzipped, signals, Web Components, routing, PWA)
- Brand: **TINA4 — The Intelligent Native Application 4ramework**
- Naming: Same concept names, language-idiomatic casing (snake_case for Python/Ruby, camelCase for PHP/Node.js)
- Scope: Full feature parity — every feature in all four frameworks
- Testing: Same positive AND negative test specs, implemented in each language
- Debug overlay: Shared HTML/CSS/JS, identical appearance across all backends
- Databases: SQLite, Firebird, MySQL, MSSQL, PostgreSQL, MongoDB, ODBC — all 7 across all 4 frameworks
- Sessions: File (dev), Redis, Valkey, MongoDB, Database — all 5 across all 4 frameworks
- WebSocket: All four frameworks with zero-dep RFC 6455 implementation
- Queue: Database-backed, zero third-party dependencies
- File uploads: Raw bytes across all frameworks (no base64 encoding)
- ORM load(): Instance method, selectOne params, returns bool
- Rust CLI: Unified `tina4` binary dispatches to all 4 framework runtimes

## Recent Progress (2026-04-03)

### v3.10.67 (current)
- **BREAKING: Python request.files raw bytes** — removed base64 encoding, matches PHP/Ruby/Node
- **load() standardized** — instance method, selectOne params, returns bool (all 4 frameworks)
- **api.upload()** added to tina4-js v1.0.15 — multipart FormData with Bearer token auth
- **File upload standard** — documented in all CLAUDE.md files and skill
- **CLAUDE.md ORM stubs rewritten** — all method signatures match actual API
- **tina4-js skill** — critical input binding warning, routing docs (`{param}` not `:param`)

### v3.10.66
- **Metrics file detail fix** — clicking bubbles in framework scanning mode resolves paths via scan root tracking

### v3.10.65
- **Metrics 3-stage test detection** — filename, path, and content matching
- **Metrics framework mode** — scans framework source with correct relative paths
- **tina4 console** — interactive REPL across all 4 frameworks
- **tina4 env** — interactive environment configuration (Rust CLI v3.8.4)
- **Brand update** — "TINA4 — The Intelligent Native Application 4ramework" across all repos
- **Quick references** — 36 sections per framework, DotEnv API documented
- **37 chapters** — 7 new (Events, Localization, Logging, API Client, WSDL/SOAP, DI Container, Service Runner)
- **MongoDB + ODBC adapters** across all 4 frameworks
- **Route groups** — nested route prefixing
- **Imperative relationships** — query_has_one/many/belongs_to for ad-hoc queries
- **Pagination standardized** — limit/offset primary, merged dual-key response
- **Port kill-and-take-over** on startup
- **Dual test port** — port+1000 for stable user testing while AI hot-reloads main port
- **Dynamic versioning** — PHP reads from composer metadata, Node from package.json
- **Packagist v2 API** — version checker uses repo.packagist.org
- **@noauth docblock** — PHP parses callback docblocks at route registration
- **HtmlElement builder** — programmatic HTML generation across all frameworks
- **Landing page redesign** — emoji icons, accurate 1.5KB size claim, Frond (Twig), Code Infinity footer

### Documentation
- **VitePress site** — 37 chapters per language, 6 language sections (Python, PHP, Ruby, Node, JS, Delphi)
- **tina4-book** — 5 books with release notes, feature lists, quick references
- **Frond (Twig) alignment** — all headings/nav updated from "Twig" to "Frond (Twig)"
- **Input binding warning** — critical danger callout in Ch3 + Ch13 for tina4-js
- **File upload docs** — standard documented in all CLAUDE.md files and skill

## What's Next
1. **Archive 29 old repos** — 19 v2 split packages + 10 legacy repos
2. **npm publish automation** — sync npm package version with releases
3. **tina4-js v2** — consider built-in FormData detection in api.post()
4. **Carbonah green benchmarking** — benchmark at every step, not just end
