# Setting up a Project

## CLI Scaffolding {#cli}

The fastest way to start is with the tina4 CLI:

```bash
npx tina4 create my-app
cd my-app
npm install
npm run dev
```

This creates a ready-to-go project with:
- Vite dev server with HMR
- TypeScript configuration
- A reactive counter page
- Hash-based routing (/, /about, 404)
- An `AppHeader` web component
- Default CSS styles
- TINA4.md AI context file

### With PWA Support

```bash
npx tina4 create my-app --pwa
```

Adds service worker registration and manifest generation to your project.

## Project Structure {#structure}

```
my-app/
├── index.html              Entry point
├── package.json
├── tsconfig.json
├── vite.config.ts
├── TINA4.md                AI context file
├── src/
│   ├── main.ts             App bootstrap
│   ├── components/         Web components
│   │   └── app-header.ts
│   ├── pages/              Page functions
│   │   └── home.ts
│   ├── routes/             Route definitions
│   │   └── index.ts
│   └── public/             Static assets
│       └── css/
│           └── default.css
```

## File Conventions {#conventions}

| Type | Location | Naming |
|------|----------|--------|
| Components | `src/components/` | `kebab-case.ts` |
| Pages | `src/pages/` | `kebab-case.ts` |
| Routes | `src/routes/` | `index.ts` |
| Styles | `src/public/css/` | Any `.css` |
| Static assets | `src/public/` | Any |

## Manual Setup {#manual}

If you prefer to set things up yourself:

```bash
mkdir my-app && cd my-app
npm init -y
npm install tina4js
npm install -D vite typescript
```

Create `index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My App</title>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.ts"></script>
</body>
</html>
```

Create `src/main.ts`:
```ts
import { signal, html, route, router } from 'tina4js';

route('/', () => {
  const count = signal(0);
  return html`
    <button @click=${() => count.value++}>
      Clicks: ${count}
    </button>
  `;
});

router.start({ target: '#root', mode: 'hash' });
```

Create `tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"]
  },
  "include": ["src/**/*.ts"]
}
```

## NPM Scripts {#scripts}

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  }
}
```

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server with HMR |
| `npm run build` | Production build to `dist/` |
| `npm run preview` | Preview production build locally |

## CLI Commands {#cli-commands}

| Command | Description |
|---------|-------------|
| `tina4 create <name>` | Scaffold a new project |
| `tina4 create <name> --pwa` | Scaffold with PWA support |
| `tina4 dev` | Start Vite dev server |
| `tina4 build` | Production build to `dist/` |
| `tina4 build --target php` | Build for tina4-php embedding |
| `tina4 build --target python` | Build for tina4-python embedding |

## Proxy API Calls in Development {#proxy}

When developing against a tina4-php or tina4-python backend, add a proxy to `vite.config.ts`:

```ts
import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 3000,
    proxy: {
      '/api': 'http://localhost:7145'
    }
  }
});
```

This forwards all `/api/*` requests to your tina4 backend during development.
