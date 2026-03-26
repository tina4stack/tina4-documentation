# Tina4 Documentation

**v2 Documentation** — This repository contains the v2 documentation site for the Tina4 framework (Python, Node.js, PHP, Ruby, Delphi, and tina4-js).

**For v3 documentation, see the [Tina4 Book](https://github.com/tina4stack/tina4-book)** — 5 books covering Python, PHP, Ruby, Node.js, and tina4-js.

**Join the community on [Discord](https://discord.gg/pKPUbNDTRa)**

## How to get running

Install node version 18+. Check all working using the versions

```bash
node -v
npm -v
```

Install the project dependencies (Hint: you can install and use pnpm for all these commands)
```bash
npm install
```

Run VitePress to spin up a local server
```bash
npm run docs:dev
```

Open http://localhost:5173/

## Syncing documentation from tina4-book

The book chapters are sourced from the [tina4-book](https://github.com/tina4stack/tina4-book) repository. To sync:

1. Make sure the `tina4-book` repo is cloned alongside this repo (i.e. `../tina4-book`)
2. Run the sync script:

```bash
npm run docs:sync
```

Or specify a custom path:

```bash
bash scripts/sync-books.sh /path/to/tina4-book
```

The sync script:
- Copies numbered chapter files (e.g. `01-getting-started.md`) from each book into the corresponding docs section
- **Never overwrites** `index.md` (quick reference) or other hand-maintained files
- **Escapes** Twig template syntax (`{{ }}`, `{% %}`) so VitePress/Vue doesn't try to parse them
- Maps: book-0 -> `general/`, book-1 -> `python/`, book-2 -> `php/`, book-3 -> `ruby/`, book-4 -> `nodejs/`, book-5 -> `js/`

After syncing, build to verify:

```bash
npm run docs:build
```

## How to contribute

* Fork the repository, be sure to include the vitepress branch
* In your project, create a branch from the vitepress branch
* Make a pull request from your project/branch into the tina4stack/tina4-documentation vitepress branch.
* Make sure to include an appropriate reviewer

---

## Our Sponsors

**Sponsored with 🩵 by Code Infinity**

[<img src="https://codeinfinity.co.za/wp-content/uploads/2025/09/c8e-logo-github.png" alt="Code Infinity" width="100">](https://codeinfinity.co.za/about-open-source-policy?utm_source=github&utm_medium=website&utm_campaign=opensource_campaign&utm_id=opensource)

*Supporting open source communities <span style="color: #1DC7DE;">•</span> Innovate <span style="color: #1DC7DE;">•</span> Code <span style="color: #1DC7DE;">•</span> Empower*

