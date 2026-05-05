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
