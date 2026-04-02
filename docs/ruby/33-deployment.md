# Chapter 20: Deployment

## 1. From Development to Production

The app works on `localhost:7147`. Now it needs to run around the clock on a real server. Handle thousands of concurrent users. Survive restarts. Hold steady on memory. The gap between "works on my machine" and "works in production" is where projects stumble.

This chapter covers everything for a production deployment: environment configuration, Puma server setup, Docker packaging, health checks, graceful shutdown, SSL/TLS, scaling, and monitoring.

When you run `tina4 init`, the framework generates a production-ready `Dockerfile` and `.dockerignore` in your project root. The Dockerfile uses a multi-stage build: the first stage installs gem dependencies and the second stage copies only the runtime artifacts into a slim image. You do not need to write a Dockerfile from scratch -- the generated one is a solid starting point.

---

## 2. Production .env Configuration

Development defaults optimize for debugging. Production defaults optimize for performance and security. The first deployment step: configure `.env` for production.

Create a production `.env`:

```env
# Core
TINA4_DEBUG=false
TINA4_LOG_LEVEL=WARNING
TINA4_PORT=7147

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

## 3. Puma Configuration

Puma is the production server for Tina4 Ruby. It runs multiple worker processes, handles concurrent requests, and supports graceful shutdown.

Create `config/puma.rb`:

```ruby
# Port
port ENV.fetch("TINA4_PORT", 7147)

# Workers (processes) -- set to number of CPU cores
workers ENV.fetch("WEB_CONCURRENCY", 2)

# Threads per worker
threads_count = ENV.fetch("TINA4_MAX_THREADS", 5)
threads threads_count, threads_count

# Environment
environment ENV.fetch("RACK_ENV", "production")

# Preload app for faster worker boot
preload_app!

# PID file
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Logging
stdout_redirect "logs/puma.stdout.log", "logs/puma.stderr.log", true

# Worker timeout
worker_timeout 60

# Graceful shutdown
on_worker_boot do
  # Reconnect to database after fork
  Tina4::Database.reconnect
end
```

Start with Puma:

```bash
bundle exec puma -C config/puma.rb
```

### How Many Workers?

Start with `(2 * CPU cores) + 1`:

| CPU Cores | Workers | Use Case |
|-----------|---------|----------|
| 1 | 3 | Small VPS, hobbyist |
| 2 | 5 | Small production app |
| 4 | 9 | Medium production app |
| 8 | 17 | High-traffic app |

The built-in WEBrick server is for development only. It handles one request at a time. Always use Puma in production.

---

## 4. Docker Deployment

Docker is the most portable deployment path. Your app runs the same way on your laptop, in CI, and on the production server.

### Dockerfile

```dockerfile
FROM ruby:3.3-slim

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install gems (copy lock file for better layer caching)
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p data logs secrets tmp/pids

# Expose port
EXPOSE 7147

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:7147/health || exit 1

# Start with Puma
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### .dockerignore

```
.git
.env
*.gem
.bundle
tmp
log
data/*.db
logs/*.log
.claude
node_modules
spec
```

### Docker Compose

For a complete setup with supporting services:

```yaml
services:
  app:
    build: .
    ports:
      - "7147:7147"
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
      test: ["CMD", "curl", "-f", "http://localhost:7147/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  worker:
    build: .
    command: tina4 queue:work
    environment:
      - DATABASE_URL=sqlite:///data/app.db
    volumes:
      - app-data:/app/data
    depends_on:
      - app
    restart: unless-stopped

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

### Building and Running

```bash
# Build the image
docker compose build

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

```ruby
Tina4::Router.get("/health") do |request, response|
  db = Tina4.database
  db_ok = false

  begin
    db.fetch_one("SELECT 1")
    db_ok = true
  rescue => e
    # Database is down
  end

  status = db_ok ? "ok" : "degraded"
  status_code = db_ok ? 200 : 503

  response.json({
    status: status,
    version: "1.0.0",
    framework: "tina4-ruby",
    database: db_ok ? "connected" : "disconnected",
    ruby_version: RUBY_VERSION,
    uptime_seconds: (Time.now - $start_time).to_i,
    memory_mb: ((`ps -o rss= -p #{Process.pid}`.to_i) / 1024.0).round(1),
    pid: Process.pid,
    timestamp: Time.now.utc.iso8601
  }, status_code)
end
```

This endpoint:

- Returns `200` when everything is healthy
- Returns `503` when the database is down (so the load balancer stops routing traffic)
- Includes version information for deployment tracking
- Runs fast (no heavy queries, no authentication)

For graceful shutdown, create a `.broken` file in the project root to make the health check return a failure status. Wait for the load balancer to drain traffic, then restart the server.

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

### Docker Stop Grace Period

Docker sends `SIGTERM`, waits for the grace period, then sends `SIGKILL`. Match the Docker grace period to your shutdown timeout:

```yaml
services:
  app:
    stop_grace_period: 30s
```

### Graceful Restart Pattern

```bash
# Signal the load balancer to stop routing traffic
touch .broken

# Wait for health checks to fail and traffic to drain
sleep 30

# Restart the application
sudo systemctl restart tina4-app

# Remove the signal file
rm .broken
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
    create 0640 deploy deploy
    postrotate
        kill -USR1 $(cat /app/tmp/pids/server.pid) 2>/dev/null || true
    endscript
}
```

This rotates logs daily, keeps 14 days of history, and compresses old logs. The `USR1` signal tells Puma to reopen its log files after rotation.

### Docker Logging

Docker captures stdout/stderr automatically. Configure log rotation in the compose file:

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
- Static file serving (faster than Ruby)
- Request buffering
- Rate limiting
- WebSocket proxying

Create `/etc/nginx/sites-available/my-app`:

```nginx
upstream tina4_app {
    server 127.0.0.1:7147;
}

server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Static files (served by Nginx, faster than Ruby)
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
        proxy_pass http://tina4_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # Application
    location / {
        proxy_pass http://tina4_app;
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

Certificates expire. Even with auto-renewal, things go wrong. Set up monitoring:

```bash
# Check certificate expiry manually
echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Verify Certbot timer is active
sudo systemctl list-timers | grep certbot
```

Use an external monitoring service (Uptime Robot, Better Uptime) that checks certificate expiry and alerts you 14 days before it expires.

---

## 10. Process Management with systemd

Create `/etc/systemd/system/tina4-app.service`:

```ini
[Unit]
Description=Tina4 Ruby Application
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/app
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=5
Environment=RACK_ENV=production

[Install]
WantedBy=multi-user.target
```

Create `/etc/systemd/system/tina4-worker.service`:

```ini
[Unit]
Description=Tina4 Queue Worker
After=network.target tina4-app.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/app
ExecStart=/usr/local/bin/tina4 queue:work
Restart=always
RestartSec=5
Environment=RACK_ENV=production

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable tina4-app tina4-worker
sudo systemctl start tina4-app tina4-worker
sudo systemctl status tina4-app
```

---

## 11. Scaling

A single server handles many applications. When traffic outgrows one server, you scale.

### Multiple Workers

Puma runs multiple worker processes. Configure the count in `config/puma.rb`:

```ruby
workers ENV.fetch("WEB_CONCURRENCY", 4)
threads 5, 5
```

Start with the number of CPU cores on your server. For I/O-heavy applications (database queries, external API calls), double the core count. CPU-bound work benefits less from extra workers.

### Load Balancing with Nginx

When you run multiple Tina4 instances, Nginx distributes traffic across them:

```nginx
upstream tina4_backend {
    server 127.0.0.1:7147;
    server 127.0.0.1:7148;
    server 127.0.0.1:7149;
    server 127.0.0.1:7150;
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

Start four instances on different ports:

```bash
TINA4_PORT=7147 bundle exec puma -C config/puma.rb &
TINA4_PORT=7148 bundle exec puma -C config/puma.rb &
TINA4_PORT=7149 bundle exec puma -C config/puma.rb &
TINA4_PORT=7150 bundle exec puma -C config/puma.rb &
```

### Docker Scaling

With Docker Compose, scale horizontally:

```bash
docker compose up -d --scale app=4
```

### Scaling Considerations

Scaling introduces shared-state problems. When four instances serve requests, each must agree on the state of the world.

**Sessions:** Store sessions in Redis, not in-memory. Otherwise, a user who logs in on instance 1 appears logged out on instance 2.

**Database:** SQLite handles one writer at a time. Under high load with multiple instances, switch to PostgreSQL or MySQL. If you must use SQLite, enable WAL mode.

**File uploads:** Store uploaded files in shared storage (S3, a mounted volume) -- not the local filesystem of a single container.

**Cache:** Use Redis as the cache backend so all instances share the same cache.

---

## 12. Monitoring

Your app runs in production. You need to know when it breaks, slows down, or runs out of resources.

### Log Aggregation

Switch to JSON-formatted logs for production. Structured logs feed into aggregation services:

```env
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

### Prometheus Metrics

Enable metrics in `.env`:

```env
TINA4_METRICS=true
```

Metrics are available at `/metrics` in Prometheus format:

```bash
curl http://localhost:7147/metrics
```

### Uptime Monitoring

Point an external monitoring service at your health endpoint:

```
https://yourdomain.com/health
```

Services like Uptime Robot, Pingdom, or Better Uptime ping this endpoint every 30-60 seconds. When it stops responding or returns a non-200 status, you receive an alert.

### Application Performance Monitoring (APM)

Uptime monitoring tells you the app is running. APM tells you how well it performs. APM agents track:

- Request latency (average, p95, p99)
- Database query performance (slow queries, connection pool usage)
- Error rates (which endpoints fail, how often)
- Memory and CPU usage over time

A basic monitoring stack for a small team: Uptime Robot for availability alerts (free tier covers it), JSON logs shipped to Grafana Loki for debugging, and `docker stats` for resource usage. Add APM when your application serves enough traffic to warrant the cost.

---

## 13. Exercise: Docker Deploy

Deploy a Tina4 Ruby application using Docker.

### Requirements

1. Create a `Dockerfile` that:
   - Uses `ruby:3.3-slim` as the base image
   - Installs dependencies with `bundle`
   - Copies the application code
   - Exposes port 7147
   - Includes a health check
   - Runs the app with Puma

2. Create a `docker-compose.yml` that:
   - Builds and runs the app
   - Starts a Redis container for caching
   - Starts a queue worker
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
curl http://localhost:7147/health

# Test the app
curl http://localhost:7147/api/products

# View logs
docker compose logs -f app

# Stop
docker compose down
```

---

## 14. Solution

The Dockerfile, docker-compose.yml, and Puma config are shown in sections 3 and 4. The health check route is shown in section 5. Combine them in your project, then:

```bash
docker compose up -d --build
```

```
[+] Building 18.4s
[+] Running 3/3
  Container redis     Started
  Container my-app    Started
  Container worker    Started
```

```bash
curl http://localhost:7147/health
```

```json
{
  "status": "ok",
  "version": "1.0.0",
  "framework": "tina4-ruby",
  "database": "connected",
  "timestamp": "2026-03-22T14:30:00+00:00"
}
```

The app runs in production mode with Redis caching, persistent data volumes, a queue worker, automatic restarts, and health monitoring.

---

## 15. Gotchas

### 1. .env Not Loaded in Docker

**Problem:** Environment variables from `.env` are not available in the container.

**Cause:** Docker does not read `.env` files automatically. The `.env` file belongs in `.dockerignore` (never ship secrets in the image).

**Fix:** Pass environment variables via `docker run -e`, the `environment` section in `docker-compose.yml`, or an `env_file` directive. For secrets, use Docker secrets or your platform's secret management.

### 2. SQLite Database Lost on Container Restart

**Problem:** All data disappears when the container restarts.

**Cause:** The SQLite database file sits inside the container. When the container is recreated, the file is gone.

**Fix:** Mount a volume for the data directory: `-v $(pwd)/data:/app/data`. In Docker Compose, use a named volume: `volumes: [app-data:/app/data]`.

### 3. WebSocket Connections Drop Behind Nginx

**Problem:** WebSocket connections fail or drop behind Nginx.

**Cause:** Nginx does not proxy WebSocket by default. It treats the upgrade request as a regular HTTP request.

**Fix:** Add WebSocket proxy headers in your Nginx config:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400;
```

### 4. Puma Workers Not Reconnecting to Database

**Problem:** Database errors after Puma forks worker processes.

**Cause:** Puma forks the master process to create workers. The forked processes inherit the parent's database connection, which is invalid after fork.

**Fix:** Use `on_worker_boot` in Puma config to reconnect:

```ruby
on_worker_boot do
  Tina4::Database.reconnect
end
```

### 5. Built-in Server Used in Production

**Problem:** The server handles one request at a time and performance is terrible.

**Cause:** WEBrick (the built-in server) is single-threaded. It is for development only.

**Fix:** Use Puma in production: `bundle exec puma -C config/puma.rb`.

### 6. Static Files Slow

**Problem:** CSS, JS, and images load slowly in production.

**Cause:** Ruby serves static files. Every static file request goes through the Ruby process.

**Fix:** Serve static files from Nginx (see the Nginx config in section 8). Nginx serves static files from memory-mapped files, orders of magnitude faster than Ruby.

### 7. Memory Usage Grows Over Time

**Problem:** The container's memory usage climbs until it crashes with OOM (out of memory).

**Cause:** Memory leaks -- unclosed database connections, growing caches without TTL, accumulating data in global variables.

**Fix:** Set TTLs on all cache entries. Close database connections. Avoid storing request data in module-level variables. Use `docker stats` to monitor memory. Set memory limits in Docker Compose: `deploy: {resources: {limits: {memory: 512M}}}`. Set Puma's `worker_timeout` and consider periodic worker restarts.

### 8. SSL Certificate Not Renewing

**Problem:** Your HTTPS certificate expires and the site goes down.

**Cause:** The auto-renewal process failed. Common reasons: DNS changes, firewall blocking port 80 for ACME challenges, or the renewal service crashed.

**Fix:** Monitor certificate expiry with an external service. Check renewal logs:

```bash
sudo certbot renew --dry-run
sudo systemctl list-timers | grep certbot
```

### 9. Scaled Instances Have Different State

**Problem:** Users see inconsistent data across requests when running multiple app instances.

**Cause:** In-memory sessions and cache are not shared between instances. A user who logs in on instance 1 appears logged out when the load balancer routes the next request to instance 2.

**Fix:** Store sessions in Redis. Use Redis as the cache backend. Store uploaded files in shared storage (S3 or a mounted volume). All instances must read from and write to the same data stores.

### 10. Queue Worker Stops Processing

**Problem:** The queue worker stops processing jobs without error messages.

**Cause:** The worker process crashed or was killed by OOM.

**Fix:** Use `Restart=always` in systemd. Monitor the worker with health checks. Set up alerting on dead letter queue growth.
