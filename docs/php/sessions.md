# Sessions
::: tip 🔥 Hot Tips
- Tina4 sessions support three backends: **database**, **Redis**, and **Memcached**
- The database backend works with any Tina4 database driver (SQLite, MySQL, PostgreSQL, Firebird, etc.)
- The session table is created automatically on first use -- no migrations needed
- Redis and Memcached backends handle expiry via TTL, so no garbage collection overhead
  :::

## Installation {#installation}

```bash
composer require tina4stack/tina4php-session
```

Depending on your chosen backend, you may also need:

```bash
# For database sessions (pick your driver)
composer require tina4stack/tina4php-sqlite3
composer require tina4stack/tina4php-mysql

# For Redis sessions — requires ext-redis
# For Memcached sessions — requires ext-memcached
```

## SessionConfig Options {#config}

All session behaviour is controlled through the `SessionConfig` class:

| Property          | Type      | Default            | Description                                                  |
|-------------------|-----------|--------------------|--------------------------------------------------------------|
| `sessionType`     | `string`  | `'database'`       | Backend type: `'database'`, `'redis'`, or `'memcached'`      |
| `database`        | `?object` | `null`             | A Tina4 database driver instance (required for `database`)   |
| `tableName`       | `string`  | `'tina4_sessions'` | Table name for database-backed sessions                      |
| `lifetime`        | `int`     | `1440`             | Session lifetime in seconds (24 minutes, matches php.ini)    |
| `redisConfig`     | `?array`  | `null`             | Redis connection: `['host', 'port', 'auth']`                 |
| `memcachedConfig` | `?array`  | `null`             | Memcached connection: `['host', 'port']`                     |

## Database Backend {#database}

The database backend stores sessions in a SQL table and works with any Tina4 database driver. The table is created automatically when the session is first opened.

```php
global $DBA;
$DBA = new \Tina4\DataSQLite3("mydb.db");

$config = new \Tina4\SessionConfig();
$config->sessionType = 'database';
$config->database = $DBA;
// $config->tableName = 'tina4_sessions'; // optional, this is the default

\Tina4\SessionHandler::start($config);

// Use sessions normally
$_SESSION['user'] = 'Andre';
```

### Auto-Table Creation {#auto-table}

On first `open()`, the `DatabaseSession` backend checks whether the session table exists using the driver's `tableExists()` method. If missing, it creates:

```sql
CREATE TABLE tina4_sessions (
    session_id VARCHAR(128) PRIMARY KEY,
    data TEXT,
    last_accessed INTEGER
)
```

Garbage collection removes rows where `last_accessed` is older than the configured lifetime.

## Redis Backend {#redis}

Redis sessions require the `ext-redis` PHP extension. Session keys are stored with the prefix `tina4:session:` and expire automatically via Redis TTL.

```php
$config = new \Tina4\SessionConfig();
$config->sessionType = 'redis';
$config->redisConfig = [
    'host' => '127.0.0.1',
    'port' => 6379,
    'auth' => null, // set password if needed
];
$config->lifetime = 3600; // 1 hour

\Tina4\SessionHandler::start($config);

$_SESSION['token'] = bin2hex(random_bytes(16));
```

## Memcached Backend {#memcached}

Memcached sessions require the `ext-memcached` PHP extension. Like Redis, keys use the `tina4:session:` prefix and TTL handles expiry.

```php
$config = new \Tina4\SessionConfig();
$config->sessionType = 'memcached';
$config->memcachedConfig = [
    'host' => '127.0.0.1',
    'port' => 11211,
];

\Tina4\SessionHandler::start($config);

$_SESSION['cart'] = ['item1', 'item2'];
```

## Putting It Together {#usage}

A typical setup in your `index.php`:

```php
<?php
require_once 'vendor/autoload.php';

global $DBA;
$DBA = new \Tina4\DataSQLite3("sessions.db");

$config = new \Tina4\SessionConfig();
$config->sessionType = 'database';
$config->database = $DBA;
$config->lifetime = 7200; // 2 hours

\Tina4\SessionHandler::start($config);

echo new \Tina4\Tina4Php();
```

After `SessionHandler::start()`, PHP's built-in `$_SESSION` superglobal works as expected. The handler registers itself via `session_set_save_handler()` and calls `session_start()` if no session is active.

## Switching Backends {#switching}

Because all three backends share the same `SessionConfig` entry point, switching is a one-line change:

```php
$config->sessionType = 'redis'; // or 'memcached', or 'database'
```

Set the matching connection property (`database`, `redisConfig`, or `memcachedConfig`) and the handler takes care of the rest. An `InvalidArgumentException` is thrown if the required connection property is missing.
