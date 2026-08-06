# Chapter 5: DevOps and Deployment

Someone handed you a Tina4 application and asked you to run it. You have never
seen the framework before. This page tells you what you need and nothing else.

Tina4 apps have no runtime dependencies. No package tree to resolve, no native
addons to compile, no build step that fails on a fresh machine. The application
directory and a language runtime are the whole story. That makes deployment
short, and it makes this chapter short with it.

## 1. Know Which Server You Are Running

Every Tina4 app answers HTTP, but the thing underneath differs by language. That
one fact decides most of your deployment.

| Language | HTTP server | Concurrency |
|----------|-------------|-------------|
| Python | asyncio, plus an ASGI entry point | One event loop, or workers under uvicorn / gunicorn / granian |
| PHP | Tina4's own accept loop, php-fpm, or openswoole | Your choice, see below |
| Ruby | WEBrick | Threads |
| Node.js | Native `node:http` | One event loop |

Python, Ruby and Node have one sensible answer each, and `tina4 deploy docker`
generates it:

```bash
tina4 deploy docker
```

The image starts the app with `tina4 serve --production`. Nothing else to pick.

Python has one extra door worth knowing about. The framework exposes an ASGI
entry point, so you can run it under uvicorn, hypercorn or granian and use their
worker models instead of the built-in loop. Reach for that when one event loop
stops being enough.

## 2. PHP Only: Pick a Runtime

PHP is the one language where the process model is your decision, because it has
three real answers rather than one.

| Runtime | What serves the request | Pick it when |
|---------|------------------------|--------------|
| Built-in server | Tina4's own accept loop | You want one process, no front end, nothing to install |
| php-fpm + nginx | A php-fpm worker per request | You want the boring option your ops team already knows |
| openswoole | A resident Swoole worker | Per-request bootstrap is your bottleneck and you will manage resident state |

```bash
tina4 deploy docker                     # built-in server (default)
tina4 deploy docker --runtime fpm       # nginx + php-fpm
tina4 deploy docker --runtime swoole    # openswoole
```

Each writes a Dockerfile and the files that Dockerfile needs. The swoole image
adds `server.php`. The fpm image adds `nginx.fpm.conf` and
`docker-entrypoint.fpm.sh`. Read them, commit them, treat them as yours.

The default image installs `pcntl` and forks a process per request out of the
box, verified by building and running it: twenty requests, twenty pids. Switch
to the worker pool at run time without rebuilding anything:

```bash
docker run -e TINA4_SERVE_WORKERS=8 -p 7145:7145 your-image
```

### php-fpm is the safe default

Every request gets fresh process state. Nothing leaks between requests. A fatal
error in one request cannot poison the next. Your monitoring already understands
it and the failure modes are twenty years old.

The cost is memory. Each worker carries its own copy of the interpreter and the
application.

### The built-in server needs pcntl

This is the one thing that catches people out, and it is silent.

Tina4's own PHP server handles concurrency two ways, and both need the `pcntl`
extension. It forks a request so a slow handler cannot block the others, and
`TINA4_SERVE_WORKERS` pre-forks a pool of long-lived workers. Without `pcntl`,
both stop existing. The server still answers. Nothing logs an error. Every
concurrency setting in your `.env` does nothing at all.

The stock `php:8.4-cli` image ships `posix` and not `pcntl`, so this is the
normal state of a hand-built image rather than an edge case. Check it first:

```bash
php -m | grep -i pcntl
```

The image `tina4 deploy docker` generates installs `pcntl` and fails the build
if it does not load. If you write your own Dockerfile, do the same.

### Forking is the default, so there is nothing to turn on

With `pcntl` present, PHP's built-in server already forks a process per request.
You do not enable it. You only lose it, and there are three ways to do that:

| Cause | What you see | Fix |
|-------|--------------|-----|
| `pcntl` absent | The server answers from one process. No warning | Install `pcntl` |
| `TINA4_SERVE_WORKERS` above 1 | The worker pool runs instead | Leave it at 1 |
| `TINA4_SERVE_FORK=false` | You asked for one process | Remove the line |

`TINA4_DEBUG` does not switch it off. That is deliberate. A slow route should
never freeze your development server, and that is the case forking exists for.

### Ask the server, do not trust the config

The failure here is silent, so check the process table rather than the settings.
Add a route that reports its own pid:

```php
\Tina4\Router::get("/pid", fn($rq, $rs) => $rs((string)getmypid(), 200, "text/plain"));
```

Then count how many processes answer twenty requests:

```bash
for i in $(seq 1 20); do curl -s http://127.0.0.1:7145/pid; echo; done | sort -u | wc -l
```

| Result | Meaning |
|--------|---------|
| 20 | A process per request. Forking is live |
| 1 | One process. Work through the table above |
| N | The pool is running with N workers, not fork per request |

Run it once after any deployment change. This check is how we found that three
benchmark runs had been measuring a single-process server while every
configuration file said otherwise. The settings agreed with each other and
disagreed with reality, and only the process table knew.

### Swoole keeps your application resident

No per-request bootstrap. The app stays in memory between requests, which is
where the speed comes from and where the rules come from too.

Anything the application writes to a static or a global lives for the life of
the worker, not the request. A cache nobody bounded is a leak that grows all
day. Keep `TINA4_DEBUG` false, because the dev toolbar's request log is a static
array that only ever grows.

If none of that appeals, the other two runtimes cannot leak between requests,
because they keep nothing between requests.

#### The Swoole entry point

`tina4 deploy docker --runtime swoole` writes this as `server.php`. It is short
because `App::__invoke()` does the work: hand it a Swoole request, get a Tina4
response back. Your routes, ORM, middleware and templates never know the
difference.

```php
<?php
require __DIR__ . '/vendor/autoload.php';

$app = new \Tina4\App(__DIR__);

$http = new Swoole\Http\Server(
    getenv('TINA4_SWOOLE_HOST') ?: '0.0.0.0',
    (int)(getenv('TINA4_SWOOLE_PORT') ?: 7145)
);

// OpenSwoole 22 removed the procedural swoole_*() helpers. Mainline Swoole
// still has them and has no OpenSwoole\Util. Call either one unguarded and the
// image builds, then the container exits 255 the moment it starts.
$workers = (int)(getenv('TINA4_SWOOLE_WORKERS') ?: 0);
if ($workers <= 0) {
    if (class_exists('OpenSwoole\Util')) {
        $workers = \OpenSwoole\Util::getCPUNum() * 2;
    } elseif (function_exists('swoole_cpu_num')) {
        $workers = swoole_cpu_num() * 2;
    } else {
        $workers = 4;
    }
}

$http->set([
    'worker_num'       => $workers,
    'max_request'      => (int)(getenv('TINA4_SWOOLE_MAX_REQUEST') ?: 10000),
    'enable_coroutine' => true,
]);

$http->on('request', function ($req, $res) use ($app) {
    try {
        $response = $app($req);

        $res->status($response->getStatusCode());

        foreach ($response->getHeaders() as $name => $value) {
            $res->header($name, $value);
        }

        // Cookies are a SEPARATE bag from headers. Skip this loop and every
        // Set-Cookie vanishes, which breaks sessions and logins while every
        // response still returns 200.
        foreach ($response->getCookies() as $name => $cookie) {
            $res->cookie(
                $name, $cookie['value'], $cookie['expires'], $cookie['path'],
                $cookie['domain'], $cookie['secure'], $cookie['httponly'],
                $cookie['samesite']
            );
        }

        $res->end($response->getBody());
    } catch (\Throwable $e) {
        // A throw that escapes here kills the worker and takes every in-flight
        // coroutine with it, so it is contained and logged instead.
        \Tina4\Log::error('Unhandled error in the Swoole handler: ' . $e->getMessage());
        $res->status(500);
        $res->end('Internal Server Error');
    }
});

$http->start();
```

Three details in there earn their place. `max_request` recycles a worker, which
bounds a leak you have not found. The cookie loop exists because
`getCookies()` is separate from `getHeaders()`, and dropping it breaks every
login while every response still says 200. The try/catch exists because an
escaped throw kills the worker.

`TINA4_SWOOLE_WORKERS`, `TINA4_SWOOLE_MAX_REQUEST`, `TINA4_SWOOLE_HOST` and
`TINA4_SWOOLE_PORT` tune it from the environment, so the file itself rarely
needs editing.

## 3. Environment Variables That Matter in Production

Tina4 reads its configuration from the environment. Everything below has a
default that works. These are the ones worth setting on purpose.

### Set these or the app tells you off

```bash
TINA4_DEBUG=false
TINA4_SECRET=<64 hex characters>
```

`TINA4_DEBUG=false` turns off the dev dashboard, the toolbar, the error overlay
and template recompilation. Leave it true in production and you publish your
stack traces.

`TINA4_SECRET` signs your JWTs. Generate it once and keep it:

```bash
openssl rand -hex 32
```

Leave it blank and the framework logs a warning naming the exact command above.
It will not invent one for you outside local development, because a secret that
regenerates on restart invalidates every token you issued.

### Timeouts that stop a hang

```bash
TINA4_DATABASE_CONNECT_TIMEOUT=10    # seconds; 0 waits forever
TINA4_SHUTDOWN_TIMEOUT=30            # seconds to drain before force-close
```

Both work in all four languages.

`TINA4_DATABASE_CONNECT_TIMEOUT` bounds every database connect. An unreachable
host used to hang the application with no error and no ceiling. When the timeout
expires the message names the host, the port, the seconds elapsed and the
variable, so you can act on it without reading a stack trace.

### Limits that bound a hostile request, PHP only

```bash
TINA4_REQUEST_TIMEOUT=30             # seconds of client silence; 0 disables
TINA4_MAX_REQUEST_HEADER=65536       # bytes; answers 431 past this
TINA4_MAX_REQUEST_BODY=10485760      # bytes; answers 413 past this
```

These exist in PHP because PHP's built-in server is the only one that parses
HTTP itself, on a raw socket, with no server underneath to inherit limits from.
The other three sit on something that already has them: Python bounds its header
read at 30 seconds and 64KB through asyncio, Ruby inherits WEBrick's limits, and
Node inherits `node:http` defaults of 60 seconds for headers and 16KB per header
block.

So Python, Ruby and Node are bounded. They are just not bounded by a Tina4
variable you can tune. If you need a specific ceiling on those three, set it on
the server in front of them.

The PHP header cap matches what nginx and Apache allow. The body cap refuses an
oversized upload on its first packet, from the declared `Content-Length`, rather
than buffering all of it and then objecting.

### Worker pool, PHP built-in server only

```bash
TINA4_SERVE_WORKERS=8                # 1 is the default: one process
TINA4_SERVE_MAX_REQUESTS=10000       # recycle a worker after N; 0 never
```

`TINA4_SERVE_WORKERS` pre-forks a pool. The parent binds the socket once, forks
the workers, and supervises them. A worker that dies gets replaced, so the pool
never quietly shrinks.

`TINA4_SERVE_MAX_REQUESTS` recycles a worker after it has served its quota. It
bounds the damage from a leak you have not found yet. Treat it as a safety net,
not a licence.

The pool refuses to start when `TINA4_DEBUG` is true, and says so in the log.
The dev dashboard, hot reload and the WebSocket registry are all per-process, so
a pool in development would show you one worker's traffic and reload one
worker's code. That reads as a framework bug, so the framework declines.

## 4. Health Checks

Every Tina4 app answers a health check with no configuration:

```bash
curl http://localhost:7145/__health
```

```json
{"status": "ok"}
```

`/health` works too and always will. It is registered as a permanent alias, so a
probe written years ago keeps working when someone sets a custom path.

Point your load balancer, your Docker `HEALTHCHECK` and your Kubernetes
readiness probe at `/__health`. Set `TINA4_HEALTH_PATH` if you need it somewhere
else.

## 5. Graceful Shutdown

Send `SIGTERM` and Tina4 stops accepting first, then drains.

A connection arriving after the signal gets a clean connection refused rather
than an accept followed by a reset. Requests already in flight run to completion
and write their whole response. `TINA4_SHUTDOWN_TIMEOUT` bounds the drain and
defaults to 30 seconds.

That default is not arbitrary. It matches Kubernetes'
`terminationGracePeriodSeconds`, so the two agree out of the box:

```yaml
spec:
  terminationGracePeriodSeconds: 30
  containers:
    - name: app
      env:
        - name: TINA4_SHUTDOWN_TIMEOUT
          value: "30"
```

Raise both together if your requests run long. Raise one alone and Kubernetes
kills the pod while Tina4 is still politely draining.

## 6. Logging

Containers log to stdout, and Tina4 does this without being asked.

With `TINA4_LOG_OUTPUT` unset, stdout is always on and the log file is written
only in development. Your production container writes no file, bloats no
writable layer, and hands every line to your log driver. That is the
twelve-factor behaviour and it is the default.

```bash
TINA4_LOG_LEVEL=INFO                 # DEBUG | INFO | WARNING | ERROR | CRITICAL
TINA4_LOG_FORMAT=json                # text is the default
```

Set `TINA4_LOG_FORMAT=json` when a log aggregator is parsing the stream. Text
stays the default everywhere, because a human reading `docker logs` is the more
common case and JSON makes that worse.

## 7. A Checklist

Before the first deploy:

- `TINA4_DEBUG=false`
- `TINA4_SECRET` set to 64 hex characters from `openssl rand -hex 32`
- `php -m | grep pcntl` returns something, if you run PHP's built-in server
- Health probe points at `/__health`
- `TINA4_SHUTDOWN_TIMEOUT` matches your orchestrator's grace period
- Database credentials arrive as environment variables, not in a committed `.env`
- `TINA4_DATABASE_CONNECT_TIMEOUT` set, so a database outage fails instead of hangs

Seven lines. Work through them once and the application runs the way its author
intended, which is the only thing anyone deploying someone else's code actually
wants.
