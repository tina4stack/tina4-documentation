# Understanding Tina4 - Quick Reference

::: tip 🔥 Hot Tips

* Tina4 is The Intelligent Native Application 4ramework: one package, zero config, convention over configuration
* Same API across Python, Node.js, PHP, and Ruby: learn one, know all four
* Routes in `src/routes/`, templates in `src/templates/`, ORM in `src/orm/`, static files in `src/public/`
* Zero runtime dependencies in every language
:::

[Philosophy](index.md#philosophy) • [Installation](index.md#installation) • [Project Structure](index.md#project-structure) • [Choosing a Language](index.md#choosing-a-language) • [Environment](index.md#environment-variables)

***

## Philosophy

Tina4 follows the AI framework philosophy. One package. One folder structure. Zero configuration files beyond a `.env`. You write your code, drop it in the right folder, and Tina4 discovers it.

***

## Installation

Choose your language:

| Language    | Scaffold                   | Run           |
| ----------- | -------------------------- | ------------- |
| **Python**  | `tina4 init python my-app` | `tina4 serve` |
| **Node.js** | `tina4 init nodejs my-app` | `tina4 serve` |
| **PHP**     | `tina4 init php my-app`    | `tina4 serve` |
| **Ruby**    | `tina4 init ruby my-app`   | `tina4 serve` |

***

## Project Structure

Every Tina4 project follows the same layout regardless of language:

```
project/
  .env                  # Environment configuration
  src/
    routes/             # API endpoints and page routes
    templates/          # Frond/Twig templates
    orm/                # Database models
    services/           # Background services
    migrations/         # Database migrations
  src/public/           # Static assets (CSS, JS, images)
```

***

## Choosing a Language

All four languages share the same conventions:

* **Python** - Best for data science, ML integration, rapid prototyping
* **Node.js** - Best for real-time apps, async I/O, one language across browser and server
* **PHP** - Best for broad hosting reach, JIT-compiled speed, mature library set
* **Ruby** - Best for developer happiness, clean syntax, rapid development

See [Chapter 3: Choosing Your Language](https://github.com/tina4stack/tina4-documentation/blob/main/general/03-choosing-your-language.md) for a detailed comparison.

***

## Environment Variables

All configuration lives in a single `.env` file:

```bash
# Database
TINA4_DATABASE_URL=sqlite://app.db

# Server
PORT=7145
DEBUG=true

# Authentication
TINA4_SECRET=your-secret-key
```

See [Chapter 4: Environment Variables](https://github.com/tina4stack/tina4-documentation/blob/main/general/04-environment-variables.md) for the full reference.

***

## 📕 Download the book

[**Understanding Tina4** (PDF)](https://github.com/tina4stack/tina4-documentation/blob/main/pdfs/Understanding-Tina4.pdf): full reference, printable, with clickable table of contents and PDF outline. Regenerated with every release.
