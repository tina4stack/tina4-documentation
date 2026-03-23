# Progressive Web App (PWA)

tina4-js generates the web app manifest and service worker at runtime — no build step required for PWA support.

## Quick Start {#quickstart}

```ts
import { pwa } from 'tina4js';

pwa.register({
  name: 'My App',
  shortName: 'App',
  themeColor: '#1a1a2e',
});
```

This automatically:
1. Generates a `manifest.json` and injects it as a `<link>` tag
2. Sets the `<meta name="theme-color">` tag
3. Generates and registers a service worker

## Configuration {#config}

```ts
pwa.register({
  name: 'My App',                        // Full app name
  shortName: 'App',                      // Short name for home screen
  themeColor: '#1a1a2e',                 // Theme color
  backgroundColor: '#ffffff',             // Splash screen background
  display: 'standalone',                  // Display mode
  icon: '/icon-512.png',                  // App icon path
  cacheStrategy: 'network-first',        // Caching strategy
  precache: ['/', '/css/styles.css'],    // URLs to cache on install
  offlineRoute: '/offline',              // Fallback when offline
});
```

| Option | Default | Description |
|--------|---------|-------------|
| `name` | *required* | Full application name |
| `shortName` | Same as `name` | Short name for home screen |
| `themeColor` | `'#000000'` | Browser theme color |
| `backgroundColor` | `'#ffffff'` | Splash screen background |
| `display` | `'standalone'` | `standalone`, `fullscreen`, `minimal-ui`, `browser` |
| `icon` | — | Path to app icon (generates 192x192 and 512x512 entries) |
| `cacheStrategy` | `'network-first'` | Service worker caching strategy |
| `precache` | `[]` | URLs to cache immediately on install |
| `offlineRoute` | — | URL to serve when offline and no cache available |

## Cache Strategies {#strategies}

### Network First (default)

Tries the network first, falls back to cache. Best for dynamic content:

```ts
pwa.register({
  name: 'My App',
  cacheStrategy: 'network-first',
});
```

```
Request → Network → Success → Cache + Return
                  → Fail    → Return from Cache
```

### Cache First

Serves from cache first, fetches from network in background. Best for static assets:

```ts
pwa.register({
  name: 'My App',
  cacheStrategy: 'cache-first',
});
```

```
Request → Cache → Hit  → Return cached
               → Miss → Fetch from Network → Cache + Return
```

### Stale While Revalidate

Returns cached version immediately, updates cache in background. Best balance of speed and freshness:

```ts
pwa.register({
  name: 'My App',
  cacheStrategy: 'stale-while-revalidate',
});
```

```
Request → Return from Cache (stale)
        → Fetch from Network (background) → Update Cache
```

## Precaching {#precache}

Specify URLs to cache during service worker installation:

```ts
pwa.register({
  name: 'My App',
  precache: [
    '/',
    '/css/styles.css',
    '/js/app.js',
    '/images/logo.svg',
  ],
});
```

These resources will be available offline immediately after the service worker installs.

## Offline Fallback {#offline}

Provide a fallback page for when the user is offline and the requested page isn't cached:

```ts
pwa.register({
  name: 'My App',
  offlineRoute: '/offline',
  precache: ['/offline'],  // Make sure the offline page is cached
});
```

## Manifest Generation {#manifest}

You can generate the manifest JSON directly for custom use:

```ts
const manifest = pwa.generateManifest({
  name: 'My App',
  shortName: 'App',
  themeColor: '#123456',
  backgroundColor: '#ffffff',
  display: 'standalone',
  icon: '/icon.png',
});

console.log(manifest);
// {
//   name: 'My App',
//   short_name: 'App',
//   start_url: '/',
//   display: 'standalone',
//   background_color: '#ffffff',
//   theme_color: '#123456',
//   icons: [
//     { src: '/icon.png', sizes: '192x192', type: 'image/png' },
//     { src: '/icon.png', sizes: '512x512', type: 'image/png' },
//   ]
// }
```

## Service Worker Generation {#sw}

Generate the service worker code string for custom registration:

```ts
const swCode = pwa.generateServiceWorker({
  name: 'My App',
  cacheStrategy: 'cache-first',
  precache: ['/'],
  offlineRoute: '/offline',
});

// swCode is a JavaScript string you can register manually
```

## Scaffolding with PWA {#scaffold}

The CLI creates PWA-ready projects:

```bash
npx tina4 create my-app --pwa
```

This generates `src/main.ts` with PWA registration already configured.

## How It Works {#how-it-works}

tina4-js uses Blob URLs to avoid file generation:

1. **Manifest**: Generated as a JSON object, converted to a Blob URL, injected as `<link rel="manifest">`
2. **Service Worker**: Generated as a JavaScript string, converted to a Blob URL, registered via `navigator.serviceWorker.register()`
3. **Theme Color**: Injected or updated as `<meta name="theme-color">`

This means no build step or static files are needed — everything is created at runtime.
