# Caching

::: tip Hot Tips
- Caching is **off by default** — flip one `.env` setting to enable it
- Built on [PhpFastCache](https://www.phpfastcache.com/) using the filesystem driver
- ORM queries, route responses, and Twig templates are all cached automatically once enabled
- Use `@no-cache` / `@cache` annotations to override caching per route
  :::

## Overview

Tina4 ships with a caching layer powered by **PhpFastCache**. When enabled, three things happen automatically:

1. **ORM query results** are cached so repeated `load()` / `select()` calls skip the database.
2. **Route responses** are stored and served from cache on subsequent requests.
3. **Twig templates** are compiled once and reused from the `./cache` directory.

The cache files live in a `cache/` folder at the root of your project.

## Enabling caching

Open (or create) the `.env` file in your project root and set:

```ini
[Project Settings]
TINA4_CACHE_ON=true
```

When the application boots it reads this value. If `TINA4_CACHE_ON` is `true`, Tina4 creates a PhpFastCache `files` instance pointed at `{TINA4_DOCUMENT_ROOT}/cache`.

To turn caching off again, set the value back to `false` — no code changes required.

## Manual caching with `Cache::set()` and `Cache::get()`

The `\Tina4\Cache` class gives you direct access to the cache store.

### Storing a value

```php
$cache = new \Tina4\Cache();

// Cache a string for 120 seconds
$cache->set("my-key", "hello world", 120);

// Cache an array for the default 60 seconds
$cache->set("user-list", $users);
```

**Signature:**
```php
public function set(string $keyName, mixed $value, int $expires = 60): bool
```

Returns `true` on success, `false` if the cache backend is not available.

### Retrieving a value

```php
$cache = new \Tina4\Cache();

$value = $cache->get("my-key");

if ($value === null) {
    // cache miss — fetch from the source
}
```

**Signature:**
```php
public function get(string $keyName): mixed
```

Returns the cached data, or `null` on a miss.

### Practical example

```php
\Tina4\Get::add("/api/products", function (\Tina4\Response $response) {
    $cache = new \Tina4\Cache();
    $products = $cache->get("all-products");

    if ($products === null) {
        global $DBA;
        $products = $DBA->fetch("select * from product")->asArray();
        $cache->set("all-products", $products, 300); // cache for 5 minutes
    }

    return $response($products, HTTP_OK, APPLICATION_JSON);
});
```

## ORM query caching

The `\Tina4\ORMCache` class is used internally by the ORM. When `TINA4_CACHE_ON` is `true`:

- Every `load()` call checks the cache first using a key derived from the SQL:
  `"orm" . md5($sqlStatement)`
- On a cache hit the database is skipped entirely.
- On a cache miss the query runs and the result is stored for **60 seconds**.
- Any `save()` or `delete()` invalidates the relevant cache entry by setting it to `null`.

When `TINA4_CACHE_ON` is `false`, `ORMCache::get()` always returns `null` and `ORMCache::set()` is a no-op, so the ORM falls through to the database every time.

You do not need to interact with `ORMCache` directly — the ORM handles it automatically.

## Route response caching

When caching is enabled, the Router caches the full response (content, HTTP code, headers, content type) for every matched route.

### How it works

1. A request comes in and the Router looks for a cached response using the key:
   `"url_" . md5($url . $method)`
2. If a cached entry exists it is returned immediately — the route callback is never executed.
3. If there is no cache entry, the route runs normally and the response is cached for **360 seconds** (6 minutes).

### Per-route control with annotations

You can override the global setting on individual routes using doc-block annotations:

```php
/**
 * This route is always cached, even if TINA4_CACHE_ON is false
 * @cache
 */
\Tina4\Get::add("/api/cached-data", function (\Tina4\Response $response) {
    return $response(["data" => "this will be cached"]);
});
```

```php
/**
 * This route is never cached, even if TINA4_CACHE_ON is true
 * @no-cache
 */
\Tina4\Get::add("/api/live-data", function (\Tina4\Response $response) {
    return $response(["timestamp" => time()]);
});
```

### Debug mode bypass

When `TINA4_DEBUG` is `true`, `.twig` files and anything under `/public/` are **not** served from cache. This lets you iterate on templates without clearing cache constantly.

## Twig template caching

When `TINA4_CACHE_ON` is `true`, the Twig environment is created with compiled template caching:

```php
// Internally Tina4 does:
$twig = new Environment($twigLoader, ["debug" => TINA4_DEBUG, "cache" => "./cache"]);
```

Compiled templates are stored in `./cache` and reused until the source `.twig` file changes or the cache is cleared.

When caching is off, Twig recompiles templates on every request.

## Clearing the cache

Tina4 exposes a built-in route to wipe the cache directory:

```
GET /cache/clear
```

This deletes everything inside `./cache` and returns `"OK"`.

You can also clear it manually:

```bash
rm -rf ./cache/*
```

## Cache key patterns

| Layer       | Key format                          | Default TTL |
|-------------|-------------------------------------|-------------|
| Manual      | Any string you choose               | 60 seconds  |
| ORM queries | `"orm" . md5($sql)`                 | 60 seconds  |
| Route responses | `"url_" . md5($url . $method)`  | 360 seconds |
| Twig templates | Managed by Twig (filesystem)     | Until source changes |

## Configuration via `.env`

The full set of cache-related settings in your `.env`:

```ini
[Project Settings]
TINA4_CACHE_ON=true    # Enable or disable all caching (default: false)
TINA4_DEBUG=false      # When true, Twig/public file caching is bypassed
```

The cache backend is always the **filesystem driver** pointed at `{TINA4_DOCUMENT_ROOT}/cache`. No additional configuration (Redis, Memcached, etc.) is needed.
