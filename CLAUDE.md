# Tina4 Documentation

Documentation site for the Tina4 framework. See https://tina4.com for the live site.

## Build

- Framework: VitePress
- Branch: `main` (active development + deploy branch)
- Package manager: `pnpm` (v10.24.0)
- Install: `pnpm install`
- Dev server: `pnpm docs:dev`
- Build: `pnpm docs:build`
- Preview: `pnpm docs:preview`

## Writing Style

- **Always use the `content-writer` skill** when writing or editing documentation prose
- Active voice, no adverbs, no buzzwords — plain English
- Personify technology, use fragment chains, end sections strong
- Flesch reading ease target: 50 (±5)
- Keep subject and verb within 3 words of each other
- Code examples stay untouched — only rewrite surrounding prose

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
  javascript/             # JavaScript-specific (9 pages)
    installation.md, routing.md, components.md, api.md,
    html-templates.md, signals.md, pwa.md ...
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
