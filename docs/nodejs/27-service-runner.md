# Chapter 26: Service Runner

## 1. Work That Never Stops

Some tasks run once per request. Some tasks run forever. A cache warmer that refreshes data every 60 seconds. A queue drainer that processes jobs in a loop.

These are background services -- long-running loops that live alongside your HTTP server. They start when the application starts. They stop when the application stops. If they crash, they restart.

Tina4's Service Runner manages background services. Define a service. Register it. The runner handles lifecycle, restart-on-crash, and clean shutdown.

---

## 2. Defining a Service

A service is a class that extends `Service` and implements a `run()` method:

```typescript
import { Service } from "tina4-nodejs";

class CacheWarmer extends Service {
    name = "CacheWarmer";
    interval = 60_000;  // milliseconds between runs

    async run() {
        console.log("Warming cache...");
        await warmProductCache();
        await warmCategoryCache();
        console.log("Cache warm");
    }
}
```

The `run()` method is called once per interval. When it completes, the runner waits `interval` milliseconds before calling it again.

---

## 3. Registering and Starting Services

```typescript
import { ServiceRunner } from "tina4-nodejs";
import { CacheWarmer } from "./services/CacheWarmer";
import { HealthMonitor } from "./services/HealthMonitor";
import { InvoiceScheduler } from "./services/InvoiceScheduler";

const runner = new ServiceRunner();

runner.register(new CacheWarmer());
runner.register(new HealthMonitor());
runner.register(new InvoiceScheduler());

runner.start();
```

`runner.start()` starts all registered services in parallel. Each service gets its own loop. They do not block each other.

---

## 4. Service Lifecycle

```
register() --> IDLE
start()     --> RUNNING --> run() --> wait(interval) --> run() --> ...
stop()      --> STOPPING --> (current run() finishes) --> STOPPED
crash       --> ERROR    --> wait(restartDelay)       --> RUNNING
```

### Stopping a Service

```typescript
// Stop a specific service by name
runner.stop("CacheWarmer");

// Stop all services
runner.stopAll();
```

A stopped service waits for its current `run()` call to complete before shutting down. It does not kill mid-execution.

### Restart on Crash

If `run()` throws an uncaught exception, the runner logs the error and restarts the service after a configurable delay:

```typescript
class UnreliableService extends Service {
    name = "UnreliableService";
    interval = 5_000;
    restartDelay = 10_000;  // Wait 10 seconds before restarting after a crash

    async run() {
        if (Math.random() < 0.2) {
            throw new Error("Random failure (20% chance)");
        }
        await doWork();
    }
}
```

The default `restartDelay` is 5 seconds. Set it higher for services that connect to external systems (avoid hammering a downed dependency).

---

## 5. Service Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | class name | Identifier for logging and `stop()` |
| `interval` | `60_000` | Milliseconds between `run()` calls |
| `restartDelay` | `5_000` | Delay before restarting after a crash |
| `runOnStart` | `true` | Whether to call `run()` immediately on start |
| `maxRestarts` | `Infinity` | Stop restarting after this many crashes |

```typescript
class HourlyReport extends Service {
    name = "HourlyReport";
    interval = 3_600_000;  // 1 hour
    runOnStart = false;    // Wait a full hour before first run
    maxRestarts = 5;       // Give up after 5 consecutive crashes
    restartDelay = 30_000; // Wait 30 seconds between restarts

    async run() {
        await generateHourlyReport();
        await sendReportEmail();
    }
}
```

---

## 6. A Real-World Example: Queue Drainer

A background service that continuously processes a job queue:

```typescript
import { Service, Queue } from "tina4-nodejs";

class EmailQueueDrainer extends Service {
    name = "EmailQueueDrainer";
    interval = 1_000;  // Check every second
    private queue = new Queue({ topic: "emails" });

    async run() {
        const job = this.queue.pop();

        if (job === null) {
            return;  // Nothing to process this tick
        }

        try {
            await sendEmail(job.payload.to, job.payload.subject, job.payload.body);
            job.complete();
        } catch (err) {
            const message = err instanceof Error ? err.message : String(err);
            job.retry(30);  // Retry after 30 seconds
            console.error(`Email job failed: ${message}`);
        }
    }
}
```

The service pops one job per second. Errors do not crash the service -- they call `job.retry()` and the service continues to the next tick.

---

## 7. Health Check Endpoint

Expose service status via an HTTP endpoint:

```typescript
import { Router, ServiceRunner } from "tina4-nodejs";

const runner = new ServiceRunner();

Router.get("/api/health/services", async (req, res) => {
    const status = runner.status();
    return res.json(status);
});
```

```json
{
  "services": [
    {
      "name": "CacheWarmer",
      "state": "RUNNING",
      "lastRun": "2026-04-02T08:00:00.000Z",
      "runs": 48,
      "errors": 0,
      "nextRun": "2026-04-02T08:01:00.000Z"
    },
    {
      "name": "EmailQueueDrainer",
      "state": "RUNNING",
      "lastRun": "2026-04-02T08:00:59.123Z",
      "runs": 2880,
      "errors": 3,
      "nextRun": "2026-04-02T08:01:00.123Z"
    }
  ]
}
```

---

## 8. Integrating with the Application

Register services in your main entry point so they start alongside the HTTP server:

```typescript
import { Tina4 } from "tina4-nodejs";
import { ServiceRunner } from "tina4-nodejs";
import { CacheWarmer } from "./services/CacheWarmer";
import { EmailQueueDrainer } from "./services/EmailQueueDrainer";
import { HealthMonitor } from "./services/HealthMonitor";
import "./routes/index";

const runner = new ServiceRunner();
runner.register(new CacheWarmer());
runner.register(new EmailQueueDrainer());
runner.register(new HealthMonitor());

const app = new Tina4();

app.start(() => {
    // Start background services after the server is up
    runner.start();
    console.log("HTTP server and background services started");
});

// Clean shutdown: stop services before the process exits
process.on("SIGTERM", () => {
    runner.stopAll();
    process.exit(0);
});

process.on("SIGINT", () => {
    runner.stopAll();
    process.exit(0);
});
```

---

## 9. Exercise: Daily Report Service

Build a background service that generates a daily sales summary every 24 hours.

### Requirements

1. Create a `DailySalesReport` service with a 24-hour interval
2. The service should compute: total orders, total revenue, and top-selling category (use in-memory mock data)
3. Log the report with `Log.info()` and optionally store it
4. Expose a `GET /api/reports/last` endpoint that returns the most recent report

### Test by setting the interval to 5 seconds so you can see it run:

```bash
# Start the server and watch the console for report logs
# After 5 seconds:
curl http://localhost:7148/api/reports/last
```

---

## 10. Solution

`src/services/DailySalesReport.ts`:

```typescript
import { Service, Log } from "tina4-nodejs";

interface SalesReport {
    generatedAt: string;
    totalOrders: number;
    totalRevenue: number;
    topCategory: string;
}

const MOCK_ORDERS = [
    { id: 1, category: "Electronics", total: 79.99 },
    { id: 2, category: "Fitness", total: 29.99 },
    { id: 3, category: "Electronics", total: 549.99 },
    { id: 4, category: "Kitchen", total: 49.99 },
    { id: 5, category: "Electronics", total: 39.99 },
    { id: 6, category: "Fitness", total: 14.99 }
];

export let lastReport: SalesReport | null = null;

export class DailySalesReport extends Service {
    name = "DailySalesReport";
    interval = 86_400_000;  // 24 hours (use 5000 for testing)

    async run() {
        const totalOrders = MOCK_ORDERS.length;
        const totalRevenue = MOCK_ORDERS.reduce((sum, o) => sum + o.total, 0);

        const categoryCounts: Record<string, number> = {};
        for (const order of MOCK_ORDERS) {
            categoryCounts[order.category] = (categoryCounts[order.category] ?? 0) + 1;
        }

        const topCategory = Object.entries(categoryCounts)
            .sort((a, b) => b[1] - a[1])[0]?.[0] ?? "None";

        lastReport = {
            generatedAt: new Date().toISOString(),
            totalOrders,
            totalRevenue: parseFloat(totalRevenue.toFixed(2)),
            topCategory
        };

        Log.info("Daily sales report generated", {
            totalOrders,
            totalRevenue: lastReport.totalRevenue,
            topCategory
        });
    }
}
```

`src/routes/reports.ts`:

```typescript
import { Router } from "tina4-nodejs";
import { lastReport } from "../services/DailySalesReport";

Router.get("/api/reports/last", async (req, res) => {
    if (!lastReport) {
        return res.status(404).json({ error: "No report generated yet" });
    }
    return res.json(lastReport);
});
```

`src/index.ts`:

```typescript
import { Tina4, ServiceRunner } from "tina4-nodejs";
import { DailySalesReport } from "./services/DailySalesReport";
import "./routes/reports";

const runner = new ServiceRunner();
runner.register(new DailySalesReport());

const app = new Tina4();
app.start(() => {
    runner.start();
});
```

---

## 11. Gotchas

### 1. Services run immediately by default

If `runOnStart` is `true` (the default), `run()` is called as soon as `runner.start()` is invoked. For services that depend on a warm database or a running HTTP server, this can fail.

**Fix:** Set `runOnStart = false` if the service needs the application to be fully up. Or start the runner inside the `app.start()` callback, which fires after the server is ready.

### 2. Uncaught exceptions outside run() crash the process

If an exception escapes your `run()` method without being caught, the runner catches it and restarts the service. But an unhandled promise rejection at the top level of your service class bypasses the runner's error handling entirely.

**Fix:** Wrap the entire body of `run()` in try/catch. Never let async errors escape.

### 3. interval is wall-clock delay between runs, not between start times

If `run()` takes 45 seconds and `interval` is 60 seconds, the service runs every 105 seconds -- not every 60. This is intentional: no overlapping runs.

**Fix:** If you need wall-clock scheduling (exactly at :00 each minute), compute the time until the next scheduled run and use that as a dynamic interval.

### 4. Services do not share state safely

Two services reading and writing the same global variable without synchronization can produce inconsistent data.

**Fix:** Use a shared service (e.g., a singleton from the DI container) as the data layer. Services interact through it, not directly through shared globals.
