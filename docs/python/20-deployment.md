# Chapter 20: Deployment

## 1. From Development to Production

The app works on `localhost:7145`. Now it needs to run 24/7 on a real server. Handle 10,000 concurrent users. Survive server restarts. Not leak memory. The gap between "works on my machine" and "works in production" is where projects stumble.

This chapter covers everything for a production deployment: environment configuration, ASGI server setup, Docker packaging, health checks, graceful shutdown, log rotation, and scaling.

---

## 2. Production .env Configuration

The first step is configuring your `.env` for production. Development defaults are optimized for debugging. Production defaults are optimized for performance and security.

Create a production `.env`:

```env
# Core
TINA4_DEBUG=false
TINA4_LOG_LEVEL=WARNING
TINA4_PORT=7145

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

Tina4 Python auto-detects ASGI servers at startup. ASGI servers provide production-grade performance with:

- Multiple worker processes
- Async request handling
- Graceful shutdown
- Better error recovery

### How Auto-Detection Works

When you run `uv run python app.py` or `tina4 serve --production`, Tina4 checks for installed ASGI servers:

1. If `uvicorn` is installed, it uses uvicorn with optimal settings
2. If `hypercorn` is installed, it uses hypercorn
3. If neither is installed, it falls back to the built-in development server

```bash
# Install uvicorn for production
uv add uvicorn
```

```bash
# With uvicorn installed
uv run python app.py
```

```
  Tina4 Python v3.0.0
  Server: uvicorn (4 workers)
  Running at http://0.0.0.0:7145
```

```bash
# Without uvicorn
uv run python app.py
```

```
  Tina4 Python v3.0.0
  Server: built-in (development)
  Running at http://0.0.0.0:7145
  WARNING: Do not use the built-in server in production
```

### Uvicorn Configuration

You can fine-tune uvicorn through environment variables:

```env
TINA4_WORKERS=4
TINA4_WORKER_TIMEOUT=30
TINA4_KEEP_ALIVE=5
```

Or pass options directly:

```bash
uvicorn app:app --workers 4 --host 0.0.0.0 --port 7145
```

### How Many Workers?

A good starting point is `(2 * CPU cores) + 1`:

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

### Dockerfile

Create `Dockerfile`:

```dockerfile
FROM python:3.12-slim

# Install uv for fast package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy dependency files first (for better layer caching)
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-dev

# Copy application code
COPY . .

# Create directories for data and logs
RUN mkdir -p data logs

# Expose port
EXPOSE 7145

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:7145/health || exit 1

# Run the application
CMD ["uv", "run", "python", "app.py"]
```

### .dockerignore

Create `.dockerignore`:

```
.git
.env
__pycache__
*.pyc
.pytest_cache
htmlcov
.claude
node_modules
data/*.db
logs/*.log
.venv
```

### Building and Running

```bash
# Build the image
docker build -t my-tina4-app .

# Run the container
docker run -d \
  --name my-app \
  -p 7145:7145 \
  -e JWT_SECRET=your-production-secret \
  -e DATABASE_URL=sqlite:///data/app.db \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  my-tina4-app
```

### Docker Compose

For a complete setup with the app and supporting services, use Docker Compose.

Create `docker-compose.yml`:

```yaml
services:
  app:
    build: .
    ports:
      - "7145:7145"
    environment:
      - TINA4_DEBUG=false
      - TINA4_LOG_LEVEL=WARNING
      - JWT_SECRET=${JWT_SECRET}
      - DATABASE_URL=sqlite:///data/app.db
      - TINA4_CACHE_BACKEND=redis
      - TINA4_CACHE_HOST=redis
    volumes:
      - app-data:/app/data
      - app-logs:/app/logs
    depends_on:
      - redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7145/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    restart: unless-stopped

volumes:
  app-data:
  app-logs:
  redis-data:
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

Production deployments need a health check endpoint so load balancers, container orchestrators, and monitoring tools can verify the app is running.

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

```env
TINA4_SHUTDOWN_TIMEOUT=30
```

If active requests do not finish within the timeout, they are terminated forcefully. Set this based on your longest expected request time. For most applications, 30 seconds is generous.

### Docker Stop Grace Period

Docker sends `SIGTERM`, waits for the grace period, then sends `SIGKILL`. Match the Docker grace period to your shutdown timeout:

```yaml
services:
  app:
    stop_grace_period: 30s
```

---

## 7. Log Rotation

In production, logs grow indefinitely unless rotated. Tina4 writes logs to `logs/app.log` and `logs/error.log`.

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
        proxy_pass http://127.0.0.1:7145;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }

    # Application
    location / {
        proxy_pass http://127.0.0.1:7145;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 9. Exercise: Docker Deploy

Deploy a Tina4 Python application using Docker.

### Requirements

1. Create a `Dockerfile` that:
   - Uses `python:3.12-slim` as the base image
   - Installs dependencies with `uv`
   - Copies the application code
   - Exposes port 7145
   - Includes a health check
   - Runs the app with `uv run python app.py`

2. Create a `docker-compose.yml` that:
   - Builds and runs the app
   - Starts a Redis container for caching
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
curl http://localhost:7145/health

# Test the app
curl http://localhost:7145/api/products

# View logs
docker compose logs -f app

# Stop
docker compose down
```

### Solution

The Dockerfile and docker-compose.yml are shown in sections 4 above. The health check route is shown in section 5. Combine them all in your project, then:

```bash
docker compose up -d --build
```

```
[+] Building 12.3s
[+] Running 2/2
  ✔ Container redis    Started
  ✔ Container my-app   Started
```

```bash
curl http://localhost:7145/health
```

```json
{
  "status": "ok",
  "version": "1.0.0",
  "database": "connected",
  "timestamp": "2026-03-22T14:30:00+00:00"
}
```

The app is running in production mode, with Redis caching, persistent data volumes, automatic restarts, and health monitoring.

---

## 10. Gotchas

### 1. .env Not Loaded in Docker

**Problem:** Environment variables from `.env` are not available in the container.

**Cause:** Docker does not automatically read `.env` files. The `.env` file is in `.dockerignore` (as it should be -- never ship secrets in the image).

**Fix:** Pass environment variables via `docker run -e`, `docker-compose.yml` environment section, or an `env_file` directive. For secrets, use Docker secrets or your platform's secret management.

### 2. SQLite Database Lost on Container Restart

**Problem:** All data disappears when the container restarts.

**Cause:** The SQLite database file is inside the container. When the container is recreated, the file is lost.

**Fix:** Mount a volume for the data directory: `-v $(pwd)/data:/app/data`. In Docker Compose, use a named volume: `volumes: [app-data:/app/data]`.

### 3. WebSocket Connections Drop Behind Nginx

**Problem:** WebSocket connections fail or drop immediately when behind Nginx.

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

**Cause:** Python is serving static files. Every static file request goes through the Python process, which is much slower than a dedicated web server.

**Fix:** Serve static files from Nginx (see the Nginx config in section 8). Nginx serves static files from memory-mapped files, which is orders of magnitude faster than Python.

### 6. Memory Usage Grows Over Time

**Problem:** The container's memory usage increases steadily until it crashes with OOM (out of memory).

**Cause:** Memory leaks in your application -- unclosed database connections, growing caches without TTL, accumulating request data in global variables.

**Fix:** Set TTLs on all cache entries. Close database connections properly. Avoid storing request data in module-level variables. Use `docker stats` to monitor memory usage. Set memory limits in Docker Compose: `deploy: {resources: {limits: {memory: 512M}}}`.

### 7. Container Starts Before Database Is Ready

**Problem:** The app crashes on startup because the database is not ready yet.

**Cause:** Docker Compose starts services in parallel. The app container starts before the database container is fully initialized.

**Fix:** For SQLite, this is not an issue (the file is created automatically). For PostgreSQL or MySQL, use a startup script that waits for the database, or use Docker Compose `healthcheck` on the database service with `depends_on: {db: {condition: service_healthy}}`.
