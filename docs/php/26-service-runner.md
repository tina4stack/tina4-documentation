# Chapter 26: Service Runner

## 1. Work That Runs Outside HTTP Requests

Not everything fits in an HTTP request. Queue consumers. Scheduled jobs. Report generators. Cache warmers. WebSocket heartbeat monitors. These run continuously in the background, independent of web traffic.

Tina4's service runner provides a pattern for long-running background workers. They start with the application, restart on failure, and shut down cleanly.

---

## 2. The Service Interface

A background service implements a simple contract: a `run()` method that loops indefinitely, and a `stop()` method that signals it to exit.

```php
<?php
use Tina4\Service;

class EmailQueueWorker extends Service
{
    private bool $running = true;
    private \Tina4\Queue $queue;

    public function __construct()
    {
        $this->queue = new \Tina4\Queue(topic: 'emails');
    }

    public function run(): void
    {
        echo "[EmailQueueWorker] Starting...\n";

        while ($this->running) {
            $job = $this->queue->pop();

            if ($job === null) {
                // No jobs pending -- sleep and check again
                sleep(1);
                continue;
            }

            try {
                $this->processEmail($job->payload);
                $job->complete();
                echo "[EmailQueueWorker] Email sent to {$job->payload['to']}\n";
            } catch (\Throwable $e) {
                $job->fail($e->getMessage());
                echo "[EmailQueueWorker] Failed: {$e->getMessage()}\n";
            }
        }

        echo "[EmailQueueWorker] Stopped.\n";
    }

    public function stop(): void
    {
        $this->running = false;
    }

    private function processEmail(array $payload): void
    {
        // Actual email sending logic here
        // \Tina4\Messenger::send($payload['to'], $payload['subject'], $payload['body']);
        echo "  Sending: {$payload['subject']} -> {$payload['to']}\n";
    }
}
```

---

## 3. Registering and Starting Services

```php
<?php
use Tina4\ServiceRunner;

$runner = new ServiceRunner();

// Register services
$runner->add(new EmailQueueWorker());
$runner->add(new ReportGenerator());
$runner->add(new CacheWarmer());

// Start all services
$runner->start();
```

`start()` launches each service in its own process or thread (depending on the platform). Services run concurrently and independently.

---

## 4. A Report Generator Service

```php
<?php
use Tina4\Service;

class ReportGenerator extends Service
{
    private bool $running = true;

    public function run(): void
    {
        echo "[ReportGenerator] Starting...\n";

        while ($this->running) {
            $now = new \DateTimeImmutable();
            $hour = (int) $now->format('G');

            // Generate daily summary at 02:00
            if ($hour === 2 && (int) $now->format('i') === 0) {
                $this->generateDailySummary($now->format('Y-m-d'));
                sleep(61); // Prevent double-trigger within the same minute
                continue;
            }

            sleep(30); // Check every 30 seconds
        }

        echo "[ReportGenerator] Stopped.\n";
    }

    public function stop(): void
    {
        $this->running = false;
    }

    private function generateDailySummary(string $date): void
    {
        echo "[ReportGenerator] Generating summary for {$date}...\n";
        // Build and email/store the report
    }
}
```

---

## 5. A Cache Warmer Service

Pre-populate the cache at startup and refresh it before it expires:

```php
<?php
use Tina4\Service;
use function Tina4\cache_set;

class CacheWarmer extends Service
{
    private bool $running = true;
    private int $ttl = 300;         // 5 minutes
    private int $refreshBefore = 60; // Refresh 60 seconds before expiry

    public function run(): void
    {
        echo "[CacheWarmer] Starting...\n";

        // Warm on start
        $this->warmAll();

        while ($this->running) {
            // Refresh $refreshBefore seconds before expiry
            sleep($this->ttl - $this->refreshBefore);
            $this->warmAll();
        }

        echo "[CacheWarmer] Stopped.\n";
    }

    public function stop(): void
    {
        $this->running = false;
    }

    private function warmAll(): void
    {
        echo "[CacheWarmer] Warming cache...\n";

        $db = new \Tina4\Database(getenv('DATABASE_URL'));

        $categories = $db->fetchAll("SELECT * FROM categories ORDER BY name");
        cache_set('categories:all', $categories, $this->ttl);

        $featured = $db->fetchAll(
            "SELECT * FROM products WHERE featured = 1 ORDER BY rank LIMIT 20"
        );
        cache_set('products:featured', $featured, $this->ttl);

        echo "[CacheWarmer] Cache warmed (" . count($categories) . " categories, " . count($featured) . " featured products)\n";
    }
}
```

---

## 6. Graceful Shutdown

Signal handling lets your service exit cleanly when the server receives SIGTERM (e.g., during a deployment):

```php
<?php
use Tina4\Service;

class RobustWorker extends Service
{
    private bool $running = true;

    public function run(): void
    {
        // Register signal handlers
        if (function_exists('pcntl_signal')) {
            pcntl_signal(SIGTERM, function () {
                echo "[RobustWorker] SIGTERM received, stopping...\n";
                $this->stop();
            });

            pcntl_signal(SIGINT, function () {
                echo "[RobustWorker] SIGINT received, stopping...\n";
                $this->stop();
            });
        }

        echo "[RobustWorker] Running...\n";

        while ($this->running) {
            if (function_exists('pcntl_signal_dispatch')) {
                pcntl_signal_dispatch();
            }

            $this->doWork();
            sleep(5);
        }

        echo "[RobustWorker] Graceful shutdown complete.\n";
    }

    public function stop(): void
    {
        $this->running = false;
    }

    private function doWork(): void
    {
        // Business logic here
    }
}
```

---

## 7. Running Services as a Standalone Script

For simple deployments, run services directly as a PHP CLI script:

**`src/workers/run.php`:**

```php
<?php
require __DIR__ . '/../../vendor/autoload.php';

use Tina4\ServiceRunner;

$runner = new ServiceRunner();
$runner->add(new EmailQueueWorker());
$runner->add(new ReportGenerator());
$runner->start();
```

Run it:

```bash
php src/workers/run.php
```

Keep it alive with a process manager. With Supervisor:

```ini
[program:tina4-workers]
command=php /var/www/app/src/workers/run.php
directory=/var/www/app
autostart=true
autorestart=true
stderr_logfile=/var/log/tina4-workers.err.log
stdout_logfile=/var/log/tina4-workers.out.log
user=www-data
```

With systemd:

```ini
[Unit]
Description=Tina4 Background Workers
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/app
ExecStart=/usr/bin/php src/workers/run.php
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## 8. Running with Docker

```dockerfile
FROM php:8.3-cli

WORKDIR /app
COPY . .
RUN composer install --no-dev

CMD ["php", "src/workers/run.php"]
```

```yaml
# docker-compose.yml (excerpt)
services:
  web:
    build: .
    command: php -S 0.0.0.0:7146 index.php

  workers:
    build: .
    command: php src/workers/run.php
    environment:
      - DATABASE_URL=sqlite:./data/app.db
      - SMTP_HOST=mailhog
    depends_on:
      - db
```

The web service and workers service share the same image. They run independently.

---

## 9. Gotchas

### 1. Services blocking each other

**Problem:** Two services are registered but only the first one runs. The second never starts.

**Cause:** The first service's `run()` method blocks the main thread forever. The second service never gets control.

**Fix:** Either use `ServiceRunner` with proper multi-process support (each service in its own process), or run each service in a separate PHP process. Do not put multiple blocking loops in the same process without concurrency support.

### 2. Memory leak in long-running workers

**Problem:** The worker process grows in memory until the server runs out.

**Cause:** Variables accumulate in the loop. Large result sets are never freed.

**Fix:** `unset()` large variables inside the loop. Call `gc_collect_cycles()` periodically. Keep loop iterations small — process one job at a time, not thousands.

### 3. Database connection dropped

**Problem:** The worker fails after several hours with "server has gone away" or "connection lost."

**Cause:** The database server closes idle connections. The worker holds a connection for hours and then tries to use a dead connection.

**Fix:** Reconnect on failure. Wrap your database calls in a try/catch. On `PDOException` matching "gone away" or "connection lost," create a new connection and retry.

### 4. Not logging worker errors

**Problem:** The worker silently fails. Nothing appears in logs. Jobs pile up.

**Cause:** Exceptions inside `processEmail()` or `doWork()` are caught by a bare catch block that does nothing.

**Fix:** Always log exceptions inside the worker loop using `Debug::message()`. At minimum, log the error and continue to the next job.
