# Chapter 8: PWA

## Make It Installable

A user opens your app on their phone. They tap "Add to Home Screen." The app icon appears next to Instagram and WhatsApp. They open it on the subway with no signal, and it loads. Every page they visited before -- cached and waiting.

You built that with one function call.

---

## 1. What pwa.register() Does

```typescript
import { pwa } from 'tina4js';

pwa.register({
  name: 'My App',
  shortName: 'MyApp',
  themeColor: '#1a1a2e',
  cacheStrategy: 'network-first',
  precache: ['/', '/src/public/css/default.css'],
});
```

That one call does three things:

1. **Generates a web manifest** and injects it as a `<link rel="manifest">` in the document head
2. **Sets the theme-color** meta tag
3. **Generates and registers a service worker** with your chosen caching strategy

No build step. No config files. No `manifest.json` to maintain. Everything is generated at runtime from the config you pass.

---

## 2. Configuration

```typescript
interface PWAConfig {
  name: string;                    // App name (shown in install prompt)
  shortName?: string;              // Short name (shown on home screen)
  themeColor?: string;             // Browser chrome color (default: '#000000')
  backgroundColor?: string;        // Splash screen background (default: '#ffffff')
  display?: 'standalone' | 'fullscreen' | 'minimal-ui' | 'browser';
  icon?: string;                   // Path to app icon
  cacheStrategy?: 'cache-first' | 'network-first' | 'stale-while-revalidate';
  precache?: string[];             // URLs to cache on install
  offlineRoute?: string;           // Fallback URL when offline and cache misses
}
```

### Required

| Option | Description |
|---|---|
| `name` | The full app name. Shown in the browser's install prompt and app switcher. |

### Optional

| Option | Default | Description |
|---|---|---|
| `shortName` | Same as `name` | Shown on the home screen icon. Keep it short. |
| `themeColor` | `'#000000'` | Colors the browser chrome (address bar, status bar). |
| `backgroundColor` | `'#ffffff'` | Splash screen background while the app loads. |
| `display` | `'standalone'` | How the app looks when installed. `standalone` hides the browser chrome. |
| `icon` | none | Path to your app icon. Used for both 192x192 and 512x512 sizes. |
| `cacheStrategy` | `'network-first'` | How the service worker handles fetch requests. |
| `precache` | `[]` | URLs to download and cache on service worker install. |
| `offlineRoute` | none | URL to serve when the user is offline and the request is not in the cache. |

---

## 3. Cache Strategies

The cache strategy determines what happens when the browser makes a network request. Three options. Each fits a different kind of application.

### network-first (default)

The service worker tries the network. If the network fails, it falls back to the cache.

```typescript
pwa.register({
  name: 'My App',
  cacheStrategy: 'network-first',
});
```

Best for apps where fresh data matters: news sites, dashboards, anything with content that changes by the hour.

How it works:
1. Fetch from network
2. If successful, cache the response and return it
3. If network fails, return cached version
4. If nothing cached, show offline fallback

### cache-first

The service worker checks the cache first. It goes to the network only on a cache miss.

```typescript
pwa.register({
  name: 'My App',
  cacheStrategy: 'cache-first',
});
```

Best for apps with stable content: documentation sites, reference apps, tools that should work in airplane mode.

How it works:
1. Check cache
2. If cached, return immediately (fast!)
3. If not cached, fetch from network, cache it, return it
4. If network fails and not cached, show offline fallback

### stale-while-revalidate

The service worker returns the cached version now and updates the cache in the background. The user sees content in milliseconds. The next visit gets the fresh version.

```typescript
pwa.register({
  name: 'My App',
  cacheStrategy: 'stale-while-revalidate',
});
```

Best for apps where speed matters but data should stay current: social feeds, product catalogs, wikis.

How it works:
1. If cached, return cached version now
2. In the background, fetch from network and update the cache
3. Next visit gets the updated version
4. If nothing cached, fetch from network

---

## 4. Precaching

Precache critical assets so they are available on the first offline visit -- before the user has navigated to them:

```typescript
pwa.register({
  name: 'My App',
  cacheStrategy: 'network-first',
  precache: [
    '/',
    '/src/public/css/default.css',
    '/src/public/images/logo.png',
  ],
});
```

The service worker fetches and caches these URLs at install time. The user does not need to visit them first.

Precache your:
- HTML entry point (`/`)
- CSS files
- Critical images (logo, icons)
- Fonts

Do not precache:
- API responses (they change)
- Large files (waste bandwidth)
- User-specific content

The line between "precache" and "do not precache" is simple: if the asset is the same for every user and changes with deployments, precache it. If it varies per user or changes between requests, let the cache strategy handle it at runtime.

---

## 5. Offline Route

When the user is offline and requests a URL that is not in the cache, the service worker needs somewhere to redirect. That is the offline route:

```typescript
pwa.register({
  name: 'My App',
  offlineRoute: '/offline.html',
  precache: ['/offline.html'],
});
```

Precache the offline route. If you skip this step, the fallback page itself will not be available when the user needs it most.

A simple offline page:

```html
<!-- public/offline.html -->
<!DOCTYPE html>
<html>
<head><title>Offline</title></head>
<body>
  <h1>You are offline</h1>
  <p>Check your connection and try again.</p>
</body>
</html>
```

---

## 6. The Generated Manifest

`pwa.register()` generates a manifest like this:

```json
{
  "name": "My App",
  "short_name": "MyApp",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#1a1a2e",
  "icons": [
    { "src": "/icon.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

It is injected as a Blob URL in a `<link rel="manifest">` tag. You do not need to create or maintain a `manifest.json` file.

### Build-Time Generation

If you prefer a static manifest file (for CDN caching or server inspection), use the generation methods:

```typescript
import { pwa } from 'tina4js';

const config = {
  name: 'My App',
  shortName: 'MyApp',
  themeColor: '#1a1a2e',
  icon: '/icon.png',
  cacheStrategy: 'network-first',
  precache: ['/', '/styles.css'],
};

// Get manifest as an object
const manifest = pwa.generateManifest(config);
// Write to file in your build script

// Get service worker as a string
const swCode = pwa.generateServiceWorker(config);
// Write to file: fs.writeFileSync('dist/sw.js', swCode);
```

Runtime generation works for most projects. Build-time generation is there when your deployment pipeline demands static files.

---

## 7. Complete Example

```typescript
// src/main.ts
import { router, api } from 'tina4js';
import { pwa } from 'tina4js';
import './routes/index';

// Configure API
api.configure({ baseUrl: '/api', auth: true });

// Register PWA
pwa.register({
  name: 'Task Manager',
  shortName: 'Tasks',
  themeColor: '#2563eb',
  backgroundColor: '#f8fafc',
  display: 'standalone',
  icon: '/icon-512.png',
  cacheStrategy: 'network-first',
  precache: [
    '/',
    '/src/public/css/default.css',
    '/icon-512.png',
  ],
  offlineRoute: '/offline',
});

// Start router
router.start({ target: '#root', mode: 'history' });
```

When a user visits this app on a mobile browser, they see an "Add to Home Screen" prompt (if the browser supports it). After installing, the app launches without browser chrome, uses the blue theme color, and works offline for any cached page. The gap between "web app" and "native app" disappears -- and you closed it with twelve lines of configuration.

---

## 8. Tips

**Icons:** Provide at least one 512x512 PNG icon. Some browsers refuse to show the install prompt without it.

**HTTPS required:** Service workers only work over HTTPS (or localhost for development). Vite's dev server handles this for you.

**Testing:** In Chrome DevTools, use Application > Service Workers to see the registered service worker, and Application > Cache Storage to inspect cached assets. Use the Network panel's "Offline" checkbox to test offline behavior.

**Updating:** When you change your app and redeploy, the service worker detects the change and updates. The `skipWaiting()` call in the generated service worker ensures the new version activates without waiting for the user to close all tabs.

**Scope:** The service worker registers at the root scope. It intercepts all GET requests from your domain. Every fetch passes through your chosen cache strategy.

---

## Summary

| What | How |
|---|---|
| Register PWA | `pwa.register(config)` |
| App name | `name: 'My App'` |
| Theme color | `themeColor: '#hex'` |
| Cache strategy | `cacheStrategy: 'network-first' \| 'cache-first' \| 'stale-while-revalidate'` |
| Precache URLs | `precache: ['/path1', '/path2']` |
| Offline fallback | `offlineRoute: '/offline'` |
| Build manifest | `pwa.generateManifest(config)` |
| Build service worker | `pwa.generateServiceWorker(config)` |
