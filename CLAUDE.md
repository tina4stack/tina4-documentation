# Tina4 Documentation

Documentation site for the Tina4 framework. See https://tina4.com for the live site.

## Build

- Framework: tina4press (the tina4-js static site generator; config in `tina4press.config.mjs`). NOT VitePress - `docs:build` runs `tina4press build`.
- Branch: `main` (active development + deploy branch)
- Package manager: `pnpm` (v10.24.0)
- Install: `pnpm install`
- Dev server: `pnpm docs:dev`
- Build: `pnpm docs:build`
- Preview: `pnpm docs:preview`

## Writing Style

- **Always use the `andres-writing-voice` skill** when writing or editing documentation prose. It is the source of truth for how the Tina4 docs read. (It replaces the old content-writer rubric, which targeted a tighter, more neutral register that fought the voice.)
- **ASCII punctuation only. NEVER use em dashes.** No em/en dash (use a comma, a colon, parentheses, or a spaced hyphen ` - `), no smart/curly quotes (use straight `'` `"`), no ellipsis character (use `...`). Smart quotes inside code samples break copy-paste. `scripts/audit-truth.py --strict` enforces this as a CI gate. The voice already fits: it uses the spaced hyphen and a plain `...` to close, never an em dash.
- **Flesch 62-72** for ordinary prose; technical explanation may run 55-62. Measure, do not estimate.
- **Trace, do not define.** In technical prose, narrate what the system will do to a request as it moves - future tense, conditional branches (if the path is virtual, if auth passes) - never a definition, never an analogy.
- **Give at least one object, machine or room a will of its own** per page of prose. The router listens. The welcome page greets you. The engine turns it on by itself.
- **Contractions on, British spelling.** isn't, doesn't, it's; colour, recognise, behaviour; no one, somebody, amongst, towards. Never the Americanism (color, behavior, catalog).
- **Expand every acronym on first use** with the short form in brackets, then use the short form: Cross-Site Request Forgery (CSRF). Bare API/HTTP/JSON/SQL are fine.
- **Never sell.** State what the thing does, show the evidence, stop. No call to action in body prose, no competitor comparison. Close by handing off, not concluding.
- **Reference material stays plain.** Method tables, signature lists, env-var tables and code examples are NOT voice-passed - they take bullets and figures. The voice governs the framing and concept prose, not the API reference.
- Code examples stay untouched. Only the surrounding prose is rewritten.

## Code Principles

- **DRY** — Shared concepts go in `docs/general/`, framework-specific details in their own section
- **Separation of Concerns** — Each page covers one topic. Cross-framework features in `general/`, language-specific in `python/`, `php/`, `ruby/`, etc.
- **No inline styles** in documentation examples — use tina4-css classes only
- **All links and references** should point to https://tina4.com
- Markdown files in `docs/`
- Code examples should be framework-agnostic where possible

## Documentation Structure

```
docs/
  index.md                # Landing page
  get-started.md          # Getting started guide
  comparisons.md          # Framework comparisons
  general/                # Cross-framework topics
    tina4-css.md            # tina4-css documentation
    css.md                  # CSS guide
    static-website.md       # Static site generation
    tina4helper.md          # Helper utilities
  python/                 # Python-specific (19 pages)
    installation.md, basic-routing.md, database.md, orm.md,
    crud.md, rest-api.md, middleware.md, migrations.md,
    swagger.md, graphql.md, queues.md, websockets.md, wsdl.md ...
  php/                    # PHP-specific (24 pages)
    installation.md, basic-routing.md, database.md, orm.md,
    crud.md, rest-api.md, middleware.md, migrations.md,
    swagger.md, graphql.md, queues.md, wsdl.md, services.md,
    sessions.md, caching.md, localization.md, tests.md, threads.md ...
  ruby/                   # Ruby-specific (17 pages)
    installation.md, basic-routing.md, database.md, orm.md,
    crud.md, rest-api.md, middleware.md, migrations.md,
    swagger.md, graphql.md, queues.md ...
  delphi/                 # Delphi-specific (8 pages)
    installation.md, core.md, html-pages.md, html-render.md,
    json-adapter.md, rest-client.md, twig.md ...
  js/                     # JavaScript (tina4-js) — index + gallery + 16 numbered chapters
    index.md, gallery.md, 01-getting-started.md, 02-signals.md,
    03-html-templates.md, 04-components.md, 05-routing.md, 06-api.md,
    07-websocket.md, 08-sse-streaming.md, 09-graphql.md, 10-pwa.md,
    11-debug.md, 12-tina4-css.md, 13-backend-integration.md,
    14-building-a-complete-app.md, 15-patterns-and-pitfalls.md,
    16-vibe-coding-with-ai.md
    # (renamed from javascript/ in 2026-03 to dodge mod_security 403s)
  public/                 # Static assets
```

## Links

- Website: https://tina4.com
- GitHub: https://github.com/tina4stack/tina4-documentation

## First Principle: Documentation Matches Code Reality

**This rule overrides everything else in this file.**

Every command, env var, method, class, or feature mentioned in any
documentation file (`*.md` in this repo, or any tina4-book chapter,
or `tina4-documentation/docs/`) MUST exist in code. No exceptions.
No "we'll build it later" entries. No Laravel/Rails-style commands
that look right but don't exist. No env vars that the framework
doesn't actually read.

When you add a doc reference, add the implementation in the same PR.
When you remove a feature, remove every doc reference in the same PR.
When you find drift, fix it both ways: build the real thing OR delete
the doc.

The `tina4-documentation/scripts/audit-truth.py` script is the source
of truth. It runs as a CI gate (`audit-truth.yml`) on every PR — the
build fails on CLI drift. Run it locally before pushing if you've
touched docs:

```bash
cd /path/to/tina4-documentation
python3 scripts/audit-truth.py --strict
```

If you're unsure whether something exists, run `tina4 <command> --help`
or grep the framework source. Don't guess.
