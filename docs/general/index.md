# Understanding Tina4 – Quick Reference

::: tip
- Tina4 is The Intelligent Native Application 4ramework — one package, zero config, convention over configuration
- Same API across Python, Node.js, PHP, and Ruby — learn one, know all four
- Routes in `src/routes/`, templates in `src/templates/`, ORM in `src/orm/`, static files in `src/public/`
- Zero runtime dependencies in every language
:::

<nav class="tina4-menu">
    <a href="#philosophy">Philosophy</a> •
    <a href="#installation">Installation</a> •
    <a href="#project-structure">Project Structure</a> •
    <a href="#choosing-a-language">Choosing a Language</a> •
    <a href="#environment-variables">Environment</a>
</nav>

---

## Philosophy

Tina4 follows the AI framework philosophy. One package. One folder structure. Zero configuration files beyond a `.env`. You write your code, drop it in the right folder, and Tina4 discovers it.

---

## Installation

<div v-pre>

Choose your language:

| Language | Install | Start |
|----------|---------|-------|
| **Python** | `pip install tina4_python` | `python -m tina4_python` |
| **Node.js** | `npm i tina4-nodejs` | `npx tina4` |
| **PHP** | `composer require tina4stack/tina4php` | `php -S localhost:7145 index.php` |
| **Ruby** | `gem install tina4-ruby` | `tina4` |

</div>

---

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

---

## Choosing a Language

All four languages share the same conventions:

- **Python** — Best for data science, ML integration, rapid prototyping
- **Node.js** — Best for real-time apps, highest raw throughput, JavaScript everywhere
- **PHP** — Best for shared hosting, WordPress ecosystem, legacy integration
- **Ruby** — Best for developer happiness, clean syntax, rapid development

See [Chapter 3: Choosing Your Language](/general/03-choosing-your-language) for a detailed comparison.

---

## Environment Variables

All configuration lives in a single `.env` file:

```dotenv
# Database
DATABASE_URL=sqlite://app.db

# Server
PORT=7145
DEBUG=true

# Authentication
AUTH_SECRET=your-secret-key
```

See [Chapter 4: Environment Variables](/general/04-environment-variables) for the full reference.
