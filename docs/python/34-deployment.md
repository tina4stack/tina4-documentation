# Chapter 33: Deployment

## 1. From Development to Production

The app works on `localhost:7146`. Now it needs to run around the clock on a real server. Handle thousands of concurrent users. Survive restarts. Hold steady on memory. The gap between "works on my machine" and "works in production" is where projects stumble.

This chapter covers everything for a production deployment: environment configuration, ASGI server setup, Docker packaging, health checks, graceful shutdown, SSL/TLS, scaling, and monitoring.

When you run `tina4 init`, the framework generates a production-ready `Dockerfile` and `.dockerignore` in your project root. The Dockerfile uses a multi-stage build: the first stage installs dependencies and the second stage copies only runtime artifacts into a slim image. You do not need to write a Dockerfile from scratch -- the generated one is a solid starting point.

---

## 2. Production .env Configuration

Development defaults optimize for debugging. Production defaults optimize for performance and security. The first deployment step: configure `.env` for production.

Create a production `.env`:

```bash
# Core
TINA4_DEBUG=false
TINA4_LOG_LEVEL=WARNING
TINA4_PORT=7146

# Database
DATABASE_URL=sqlite:///data/app.db

# Security
CORS_ORIGINS=https://yourdomain.com
JWT_SECRET=your-long-random-secret-at-least-32-characters
TINA4_RATE_LIMIT=120

# Performance
TINA4_CACHE_TEMPLATES=true
TINA4_MINIFY_HTML=true

```

### Key Differences from Development

| Setting | Development | Production | Why |
|---------|------------|------------|-----|
| `TINA4_DEBUG` | `true` | `false` | Hides stack traces, disables toolbar |
| `TINA4_LOG_LEVEL` | `ALL` | `WARNING` | Reduces log noise |
| `CORS_ORIGINS` | `*` | Your domain | Prevents cross-origin abuse |
| `TINA4_CACHE_TEMPLATES` | `false` | `true` | Caches compiled templates |
| `TINA4_MINIFY_HTML` | `false` | `true` | Reduces response size |

### Sensitive Values

Production secrets never go into version control. The `.env` file is gitignored by default. For deployment, use environment variables from your hosting platform, CI/CD secrets, or a secrets manager.

```bash
# Docker: pass env vars at runtime
docker run -e JWT_SECRET=your-secret -e DATABASE_URL=sqlite:///data/app.db my-app

# Fly.io: set secrets
fly secrets set JWT_SECRET=your-secret

# Railway: use the dashboard or CLI
railway variables set JWT_SECRET=your-secret
```

---

## 3. ASGI Server Auto-Detection

Tina4 Python auto-detects ASGI servers at startup. ASGI servers deliver production-grade performance:

- Multiple worker processes
- Async request handling
- Graceful shutdown
- Better error recovery

### How Auto-Detection Works

When you run `tina4 serve` or `tina4 serve --production`, Tina4 checks for installed ASGI servers:

1. If `uvicorn` is installed, the framework uses uvicorn with optimal settings
2. If `hypercorn` is installed, the framework uses hypercorn
3. If neither is installed, the framework falls back to the built-in development server

```bash
# Install uvicorn for production
uv add uvicorn
```

```bash
# With uvicorn installed
tina4 serve
```

```
  Tina4 Python v3.0.0
  Server: uvicorn (4 workers)
  Running at http://0.0.0.0:7146
```

```bash
# Without uvicorn
tina4 serve
```

```
  Tina4 Python v3.0.0
  Server: built-in (development)
  Running at http://0.0.0.0:7146
  WARNING: Do not use the built-in server in production
```

### Uvicorn Configuration

Fine-tune uvicorn through environment variables:

```bash
TINA4_WORKERS=4
TINA4_WORKER_TIMEOUT=30
TINA4_KEEP_ALIVE=5
```

Or pass options directly:

```bash
uvicorn app:app --workers 4 --host 0.0.0.0 --port 7146
```

### How Many Workers?

Start with `(2 * CPU cores) + 1`:

```python
import multiprocessing
workers = (2 * multiprocessing.cpu_count()) + 1
```

| CPU Cores | Workers | Use Case |
|-----------|---------|----------|
| 1 | 3 | Small VPS, hobbyist |
| 2 | 5 | Small production app |
| 4 | 9 | Medium production app |
| 8 | 17 | High-traffic app |

---

## 4. Docker Deployment

Docker is the most portable deployment path. Your app runs the same way on your laptop, in CI, and on the production server.

### Official Base Image

Tina4 Python provides an official Docker Hub base image: `tina4stack/tina4-python:v3`. It is a lean, Alpine-based image (~56MB) with Python 3.13, SQLite, and the Tina4 framework pre-installed. Your app Dockerfile extends it and adds only your application code.

The base image includes these environment variables pre-configured:
- `TINA4_OVERRIDE_CLIENT=true` — bypasses the CLI guard for Docker
- `TINA4_DEBUG=false` — production mode by default
- `PYTHONUNBUFFERED=1` — ensures logs appear in `docker logs`
- `TINA4_NO_BROWSER=true` — prevents browser auto-open attempts
- `HOST=0.0.0.0` and `PORT=7146` — server binds to all interfaces

### Dockerfile

Create `Dockerfile`:

```dockerfile
FROM tina4stack/tina4-python:v3
WORKDIR /app

# Copy application code
COPY app.py .
COPY .env .
COPY migrations/ migrations/
COPY src/ src/

# Create data directories for SQLite, sessions, queue, and mailbox
RUN mkdir -p data data/sessions data/queue data/mailbox

EXPOSE 7146
CMD ["python", "app.py"]
```

That is the entire Dockerfile. The base image handles Python, dependencies, and framework setup.

### .dockerignore

Create `.dockerignore`:

```
.venv
__pycache__
*.pyc
data/
tests/
.tina4/
.DS_Store
*.db
*.db-wal
*.db-shm
logs/
.git
.env.development
.pytest_cache
htmlcov
.claude
```

### Building and Running

```bash
# Build the image
docker build -t my-tina4-app .

# Run the container
docker run -d \
  --name my-app \
  -p 7146:7146 \
  -e JWT_SECRET=your-production-secret \
  -e DATABASE_URL=sqlite:///data/app.db \
  -v $(pwd)/data:/app/data \
  my-tina4-app
```

### Adding Database Drivers

The base image ships with SQLite only. To use PostgreSQL, MySQL, MSSQL, or Firebird, install the driver in your Dockerfile.

**PostgreSQL:**

```dockerfile
FROM tina4stack/tina4-python:v3
WORKDIR /app
RUN python -m pip install --no-cache-dir psycopg2-binary
COPY app.py .
COPY .env .
COPY migrations/ migrations/
COPY src/ src/
RUN mkdir -p data data/sessions data/queue data/mailbox
EXPOSE 7146
CMD ["python", "app.py"]
```

**MySQL:**

```dockerfile
FROM tina4stack/tina4-python:v3
WORKDIR /app
RUN apk add --no-cache mariadb-connector-c-dev && \
    python -m pip install --no-cache-dir mysqlclient
COPY app.py .
COPY .env .
COPY migrations/ migrations/
COPY src/ src/
RUN mkdir -p data data/sessions data/queue data/mailbox
EXPOSE 7146
CMD ["python", "app.py"]
```

**MSSQL:**

```dockerfile
FROM tina4stack/tina4-python:v3
WORKDIR /app
RUN apk add --no-cache unixodbc-dev freetds-dev && \
    python -m pip install --no-cache-dir pymssql
COPY app.py .
COPY .env .
COPY migrations/ migrations/
COPY src/ src/
RUN mkdir -p data data/sessions data/queue data/mailbox
EXPOSE 7146
CMD ["python", "app.py"]
```

**Firebird:**

```dockerfile
FROM tina4stack/tina4-python:v3
WORKDIR /app
# Pure Python driver — no system dependencies needed
RUN python -m pip install --no-cache-dir firebird-driver
COPY app.py .
COPY .env .
COPY migrations/ migrations/
COPY src/ src/
RUN mkdir -p data data/sessions data/queue data/mailbox
EXPOSE 7146
CMD ["python", "app.py"]
```

### Docker Compose

For a complete setup with supporting services, use Docker Compose.

Create `docker-compose.yml`:

```yaml
services:
  app:
    build: .
    ports:
      - "7146:7146"
    environment:
      - TINA4_DEBUG=false
      - TINA4_LOG_LEVEL=WARNING
      - JWT_SECRET=${JWT_SECRET}
      - DATABASE_URL=sqlite:///data/app.db
    volumes:
      - app-data:/app/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:7146/health')"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  app-data:
```

```bash
# Start everything
docker compose up -d

# View logs
docker compose logs -f app

# Stop everything
docker compose down
```

---

## 5. Health Checks

Production deployments need a health check endpoint. Load balancers, container orchestrators, and monitoring tools all rely on it to verify the app is running.

Create a health check route:

```python
from datetime import datetime, timezone
from tina4_python.core.router import get

@get("/health")
async def health_check(request, response):
    db = Database.get_connection()
    db_ok = False

    try:
        db.fetch_one("SELECT 1")
        db_ok = True
    except Exception:
        pass

    status = "ok" if db_ok else "degraded"
    status_code = 200 if db_ok else 503

    return response({
        "status": status,
        "version": "1.0.0",
        "database": "connected" if db_ok else "disconnected",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }, status_code)
```

This endpoint:

- Returns `200` when everything is healthy
- Returns `503` when the database is down (so the load balancer stops routing traffic)
- Includes version information for deployment tracking
- Runs fast (no heavy queries, no authentication)

---

## 6. Graceful Shutdown

Deploy a new version. The old process must stop. Graceful shutdown finishes active requests before terminating.

Tina4 handles this when it receives a `SIGTERM` signal (the standard shutdown signal from Docker, Kubernetes, and systemd):

1. Stop accepting new connections
2. Wait for active requests to complete (up to 30 seconds)
3. Close database connections
4. Flush logs
5. Exit

### Configuring Shutdown Timeout

```bash
TINA4_SHUTDOWN_TIMEOUT=30
```

If active requests do not finish within the timeout, the server terminates them. Set this based on your longest expected request time. For most applications, 30 seconds is generous.

### Docker Stop Grace Period

Docker sends `SIGTERM`, waits for the grace period, then sends `SIGKILL`. Match the Docker grace period to your shutdown timeout:

```yaml
services:
  app:
    stop_grace_period: 30s
```

---

## 7. Log Rotation

In production, logs grow without limit unless rotated. Tina4 writes logs to `logs/app.log` and `logs/error.log`.

### Using logrotate (Linux)

Create `/etc/logrotate.d/tina4`:

```
/app/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data www-data
    postrotate
        kill -USR1 $(cat /app/tina4.pid) 2>/dev/null || true
    endscript
}
```

This rotates logs daily, keeps 14 days of history, and compresses old logs. The `USR1` signal tells Tina4 to reopen its log files after rotation.

### Docker Logging

Docker captures stdout/stderr automatically. Configure log rotation in the Docker daemon or compose file:

```yaml
services:
  app:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"
```

This keeps at most 50MB of logs (5 files of 10MB each).

---

## 8. Reverse Proxy with Nginx

In production, Tina4 runs behind Nginx. Nginx handles:

- SSL/TLS termination (HTTPS)
- Static file serving (faster than Python)
- Request buffering
- Rate limiting
- WebSocket proxying

Create `/etc/nginx/sites-available/my-app`:

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Static files (served by Nginx, faster than Python)
    location /css/ {
        alias /app/src/public/css/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /js/ {
        alias /app/src/public/js/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /images/ {
        alias /app/src/public/images/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # WebSocket upgrade
    location /ws/ {
        proxy_pass http://127.0.0.1:7146;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }

    # Application
    location / {
        proxy_pass http://127.0.0.1:7146;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 9. SSL/TLS with Let's Encrypt

HTTPS is non-negotiable in production. Let's Encrypt provides free SSL certificates with automatic renewal.

### With Nginx and Certbot

Install Certbot:

```bash
sudo apt install certbot python3-certbot-nginx
```

Obtain a certificate:

```bash
sudo certbot --nginx -d yourdomain.com
```

Certbot modifies your Nginx configuration to include SSL settings and sets up automatic renewal. Verify auto-renewal works:

```bash
sudo certbot renew --dry-run
```

Certbot renews certificates 30 days before expiry. The renewal runs via a systemd timer or cron job that Certbot creates during installation.

### With Docker (Using Traefik as Reverse Proxy)

Traefik handles SSL termination and automatic certificate provisioning. Add it to your Docker Compose setup:

```yaml
services:
  reverse-proxy:
    image: traefik:v3.0
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=you@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt

  app:
    build: .
    labels:
      - "traefik.http.routers.app.rule=Host(`yourdomain.com`)"
      - "traefik.http.routers.app.tls=true"
      - "traefik.http.routers.app.tls.certresolver=letsencrypt"
    environment:
      - TINA4_DEBUG=false
      - JWT_SECRET=${JWT_SECRET}

volumes:
  letsencrypt:
```

Traefik detects your app container through Docker labels, provisions a certificate from Let's Encrypt, and handles all HTTPS traffic. No Nginx configuration needed.

### Certificate Monitoring

Certificates expire. Even with auto-renewal, things go wrong -- DNS changes, firewall rules blocking port 80 for ACME challenges, or a crashed renewal service. Set up monitoring:

```bash
# Check certificate expiry manually
echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Verify Certbot timer is active
sudo systemctl list-timers | grep certbot
```

Use an external monitoring service (Uptime Robot, Better Uptime) that checks certificate expiry and alerts you 14 days before it expires.

---

## 10. Scaling

A single server handles many applications. When traffic outgrows one server, you scale.

### Multiple Workers

Uvicorn runs multiple worker processes by default. Configure the count in `.env`:

```bash
TINA4_WORKERS=4
```

Start with the number of CPU cores on your server. For I/O-heavy applications (database queries, external API calls), double or quadruple the core count. CPU-bound work benefits less from extra workers.

### Load Balancing with Nginx

When you run multiple Tina4 instances, Nginx distributes traffic across them:

```nginx
upstream tina4_backend {
    server 127.0.0.1:7146;
    server 127.0.0.1:7246;
    server 127.0.0.1:7346;
    server 127.0.0.1:7446;
}

server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://tina4_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Start four instances on different ports. The framework refuses to start without the Rust CLI unless `TINA4_OVERRIDE_CLIENT=true`, so for a multi-process setup either set that override or run each instance through `tina4 serve --port`:

```bash
TINA4_PORT=7146 tina4 serve --port 7146 &
TINA4_PORT=7246 tina4 serve --port 7246 &
TINA4_PORT=7346 tina4 serve --port 7346 &
TINA4_PORT=7446 tina4 serve --port 7446 &
```

Nginx distributes requests in round-robin order by default. If a backend goes down, Nginx routes traffic to the remaining instances.

### Docker Scaling

With Docker Compose, scale horizontally with a single command:

```bash
docker compose up -d --scale app=4
```

This starts four containers. Place a load balancer (Traefik, Nginx, or a cloud load balancer) in front of them:

```yaml
services:
  reverse-proxy:
    image: traefik:v3.0
    command:
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  app:
    build: .
    labels:
      - "traefik.http.routers.app.rule=Host(`yourdomain.com`)"
    environment:
      - TINA4_DEBUG=false
      - DATABASE_URL=sqlite:///data/app.db
    volumes:
      - app-data:/app/data

volumes:
  app-data:
```

### Scaling Considerations

Scaling introduces shared-state problems. When four instances serve requests, each must agree on the state of the world.

**Sessions:** Store sessions in Redis, not in-memory. Otherwise, a user who logs in on instance 1 appears logged out on instance 2.

**Database:** SQLite handles one writer at a time. Under high load with multiple instances, switch to PostgreSQL or MySQL. If you must use SQLite, enable WAL mode.

**File uploads:** Store uploaded files in shared storage (S3, a mounted volume) -- not the local filesystem of a single container.

**Cache:** Use Redis as the cache backend so all instances share the same cache.

---

## 11. Monitoring

Your app runs in production. You need to know when it breaks, slows down, or runs out of resources.

### Log Aggregation

Switch to JSON-formatted logs for production. Structured logs feed into aggregation services:

```bash
TINA4_LOG_FORMAT=json
```

Example JSON log entry:

```json
{
  "timestamp": "2026-03-22T14:30:00.123Z",
  "level": "WARNING",
  "message": "Rate limit exceeded",
  "request_id": "req-abc123",
  "ip": "203.0.113.42",
  "path": "/api/products",
  "method": "GET"
}
```

Services that ingest JSON logs:

| Service | Strengths |
|---------|-----------|
| Grafana Loki | Open source, pairs with Grafana dashboards |
| Elastic Stack (ELK) | Full-text search across logs |
| Datadog | Managed service, correlates logs with metrics |
| AWS CloudWatch | Native for AWS deployments |

Docker makes log aggregation straightforward. Configure the logging driver to send container output to your chosen service:

```yaml
services:
  app:
    logging:
      driver: "fluentd"
      options:
        fluentd-address: "localhost:24224"
        tag: "tina4.app"
```

### Uptime Monitoring

Point an external monitoring service at your health endpoint:

```
https://yourdomain.com/health
```

Services like Uptime Robot, Pingdom, or Better Uptime ping this endpoint every 30-60 seconds. When it stops responding or returns a non-200 status, you receive an alert via email, SMS, or Slack.

The health endpoint from section 5 serves double duty: container orchestrators use it for restart decisions, and uptime monitors use it for alerting.

### Application Performance Monitoring (APM)

Uptime monitoring tells you the app is running. APM tells you how well it performs. APM agents track:

- Request latency (average, p95, p99)
- Database query performance (slow queries, connection pool usage)
- Error rates (which endpoints fail, how often)
- Memory and CPU usage over time

Since Tina4 Python runs on standard Python, any Python APM agent works:

- **Datadog APM**: `uv add ddtrace` and run with `TINA4_OVERRIDE_CLIENT=true ddtrace-run uv run tina4 serve` (the override is required because APM wrappers spawn Python directly rather than going through the Rust CLI)
- **New Relic**: `uv add newrelic` and run with `TINA4_OVERRIDE_CLIENT=true newrelic-admin run-program uv run tina4 serve`
- **Elastic APM**: `uv add elastic-apm` and configure in your app startup, then `TINA4_OVERRIDE_CLIENT=true tina4 serve --production`

A basic monitoring stack for a small team: Uptime Robot for availability alerts (free tier covers it), JSON logs shipped to Grafana Loki for debugging, and `docker stats` for resource usage. Add APM when your application serves enough traffic to warrant the cost.

---

## 12. Exercise: Docker Deploy

Deploy a Tina4 Python application using Docker.

### Requirements

1. Create a `Dockerfile` that:
   - Uses `tina4stack/tina4-python:v3` as the base image
   - Copies the application code
   - Creates data directories
   - Exposes port 7146

2. Create a `docker-compose.yml` that:
   - Builds and runs the app
   - Mounts volumes for data persistence
   - Sets environment variables for production

3. Create a `/health` endpoint that checks database connectivity

4. Build, run, and verify:

```bash
# Build
docker compose build

# Start
docker compose up -d

# Test health
curl http://localhost:7146/health

# Test the app
curl http://localhost:7146/api/products

# View logs
docker compose logs -f app

# Stop
docker compose down
```

### Solution

The Dockerfile and docker-compose.yml are shown in section 4. The health check route is shown in section 5. Combine them in your project, then:

```bash
docker compose up -d --build
```

```
[+] Building 4.2s
[+] Running 1/1
  Container my-app   Started
```

```bash
curl http://localhost:7146/health
```

```json
{
  "status": "ok",
  "version": "1.0.0",
  "database": "connected",
  "timestamp": "2026-03-22T14:30:00+00:00"
}
```

The app runs in production mode with persistent data volumes, automatic restarts, and health monitoring.

---

## 13. Gotchas

### 1. .env Not Loaded in Docker

**Problem:** Environment variables from `.env` are not available in the container.

**Cause:** Docker does not read `.env` files automatically. The `.env` file belongs in `.dockerignore` (never ship secrets in the image).

**Fix:** Pass environment variables via `docker run -e`, the `environment` section in `docker-compose.yml`, or an `env_file` directive. For secrets, use Docker secrets or your platform's secret management.

### 2. SQLite Database Lost on Container Restart

**Problem:** All data disappears when the container restarts.

**Cause:** The SQLite database file sits inside the container. When the container is recreated, the file is gone.

**Fix:** Mount a volume for the data directory: `-v $(pwd)/data:/app/data`. In Docker Compose, use a named volume: `volumes: [app-data:/app/data]`.

### 3. WebSocket Connections Drop Behind Nginx

**Problem:** WebSocket connections fail or drop immediately behind Nginx.

**Cause:** Nginx does not proxy WebSocket by default. It treats the upgrade request as a regular HTTP request.

**Fix:** Add WebSocket proxy headers in your Nginx config:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400;
```

### 4. Built-in Server Used in Production

**Problem:** The server logs show "WARNING: Do not use the built-in server in production".

**Cause:** No ASGI server (uvicorn or hypercorn) is installed. The built-in server is single-threaded and not designed for production load.

**Fix:** Install uvicorn: `uv add uvicorn`. Tina4 auto-detects it and uses it with multiple workers.

### 5. Static Files Slow

**Problem:** CSS, JS, and images load slowly in production.

**Cause:** Python serves static files. Every static file request goes through the Python process.

**Fix:** Serve static files from Nginx (see the Nginx config in section 8). Nginx serves static files from memory-mapped files, which is orders of magnitude faster than Python.

### 6. Memory Usage Grows Over Time

**Problem:** The container's memory usage climbs until it crashes with OOM (out of memory).

**Cause:** Memory leaks in the application -- unclosed database connections, growing caches without TTL, accumulating request data in global variables.

**Fix:** Set TTLs on all cache entries. Close database connections properly. Avoid storing request data in module-level variables. Use `docker stats` to monitor memory usage. Set memory limits in Docker Compose: `deploy: {resources: {limits: {memory: 512M}}}`.

### 7. Container Starts Before Database Is Ready

**Problem:** The app crashes on startup because the database is not ready.

**Cause:** Docker Compose starts services in parallel. The app container starts before the database container finishes initializing.

**Fix:** For SQLite, this is not an issue (the file is created automatically). For PostgreSQL or MySQL, use a startup script that waits for the database, or use Docker Compose healthcheck on the database service with `depends_on: {db: {condition: service_healthy}}`.

### 8. SSL Certificate Not Renewing

**Problem:** Your HTTPS certificate expires and the site goes down.

**Cause:** The auto-renewal process (Certbot or Traefik) failed. Common reasons: DNS changes, firewall blocking port 80 for ACME challenges, or the renewal service crashed.

**Fix:** Monitor certificate expiry with an external service. Check renewal logs and verify the renewal timer is active:

```bash
sudo certbot renew --dry-run
sudo systemctl list-timers | grep certbot
```

### 9. Scaled Instances Have Different State

**Problem:** Users see inconsistent data across requests when running multiple app instances.

**Cause:** In-memory sessions and cache are not shared between instances. A user who logs in on instance 1 appears logged out when the load balancer routes the next request to instance 2.

**Fix:** Store sessions in Redis. Use Redis as the cache backend. Store uploaded files in shared storage (S3 or a mounted volume). All instances must read from and write to the same data stores.
