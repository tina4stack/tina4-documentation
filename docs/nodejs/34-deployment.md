# Chapter 33: Deployment

## 1. From Development to Production

The app works on `localhost:7148`. Now it needs to run around the clock on a real server. Handle thousands of concurrent users. Survive restarts. Hold steady on memory. The gap between "works on my machine" and "works in production" is where projects stumble.

This chapter covers everything for a production deployment: environment configuration, build process, Docker packaging, health checks, graceful shutdown, SSL/TLS, scaling, and monitoring.

When you run `tina4 init`, the framework generates a production-ready `Dockerfile` and `.dockerignore` in your project root. The Dockerfile uses a multi-stage build: the first stage installs npm dependencies and the second stage copies only the runtime artifacts into a slim image. You do not need to write a Dockerfile from scratch -- the generated one is a solid starting point.

---

## 2. Production .env Configuration

Development defaults optimize for debugging. Production defaults optimize for performance and security. The first deployment step: configure `.env` for production.

Create a production `.env`:

```bash
# Core
TINA4_DEBUG=false
TINA4_LOG_LEVEL=WARNING
TINA4_PORT=7148

# Database
DATABASE_URL=sqlite:///data/app.db

# Security
CORS_ORIGINS=https://yourdomain.com
TINA4_JWT_SECRET=your-long-random-secret-at-least-32-characters
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
docker run -e TINA4_JWT_SECRET=your-secret -e DATABASE_URL=sqlite:///data/app.db my-app

# Fly.io: set secrets
fly secrets set TINA4_JWT_SECRET=your-secret

# Railway: use the dashboard or CLI
railway variables set TINA4_JWT_SECRET=your-secret
```

---

## 3. Building for Production

```bash
tina4 build
```

```
Building for production...
  Compiled 47 TypeScript files
  Output: dist/
  Size: 245KB
```

Run in production:

```bash
node dist/app.js
```

---

## 4. Docker Deployment

Docker is the most portable deployment path. Your app runs the same way on your laptop, in CI, and on the production server.

### Dockerfile

Create `Dockerfile`:

```dockerfile
FROM node:20-alpine

WORKDIR /app

# Copy dependency files first (for better layer caching)
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY dist/ ./dist/
COPY src/templates/ ./src/templates/
COPY src/public/ ./src/public/
COPY src/migrations/ ./src/migrations/

# Create directories for data and logs
RUN mkdir -p data logs

ENV TINA4_DEBUG=false
ENV TINA4_PORT=7148

EXPOSE 7148

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:7148/health || exit 1

CMD ["node", "dist/app.js"]
```

### .dockerignore

Create `.dockerignore`:

```
.git
.env
node_modules
.claude
data/*.db
logs/*.log
src/
!src/templates/
!src/public/
!src/migrations/
```

### Building and Running

```bash
# Build the image
tina4 build
docker build -t my-tina4-app .

# Run the container
docker run -d \
  --name my-app \
  -p 7148:7148 \
  -e TINA4_JWT_SECRET=your-production-secret \
  -e DATABASE_URL=sqlite:///data/app.db \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  my-tina4-app
```

### Docker Compose

For a complete setup with supporting services, use Docker Compose.

Create `docker-compose.yml`:

```yaml
services:
  app:
    build: .
    ports:
      - "7148:7148"
    environment:
      - TINA4_DEBUG=false
      - TINA4_LOG_LEVEL=WARNING
      - TINA4_JWT_SECRET=${TINA4_JWT_SECRET}
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
      test: ["CMD", "wget", "-qO-", "http://localhost:7148/health"]
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

## 5. Node.js Cluster for Production

For multi-core utilization, Tina4 supports Node.js cluster mode:

```bash
TINA4_CLUSTER=true
TINA4_CLUSTER_WORKERS=4
```

Or set workers to `auto` to match CPU cores:

```bash
TINA4_CLUSTER_WORKERS=auto
```

This spawns multiple worker processes. Each handles requests independently. A worker crashes. The cluster master respawns it. No downtime.

### How Many Workers?

Start with the number of CPU cores on your server. For I/O-heavy applications (database queries, external API calls), double the core count. CPU-bound work benefits less from extra workers.

| CPU Cores | Workers | Use Case |
|-----------|---------|----------|
| 1 | 2 | Small VPS, hobbyist |
| 2 | 4 | Small production app |
| 4 | 8 | Medium production app |
| 8 | 16 | High-traffic app |

---

## 6. Health Checks

Production deployments need a health check endpoint. Load balancers, container orchestrators, and monitoring tools all rely on it to verify the app is running.

Create a health check route:

```typescript
import { Router } from "tina4-nodejs";
import { Database } from "tina4-nodejs/orm";

Router.get("/health", async (req, res) => {
    let dbOk = false;

    try {
        const db = Database.getConnection();
        await db.fetchOne("SELECT 1");
        dbOk = true;
    } catch (e) {
        // Database is down
    }

    const status = dbOk ? "ok" : "degraded";
    const statusCode = dbOk ? 200 : 503;

    return res.status(statusCode).json({
        status,
        version: "1.0.0",
        database: dbOk ? "connected" : "disconnected",
        timestamp: new Date().toISOString()
    });
});
```

This endpoint:

- Returns `200` when everything is healthy
- Returns `503` when the database is down (so the load balancer stops routing traffic)
- Includes version information for deployment tracking
- Runs fast (no heavy queries, no authentication)

### Broken File Check

Tina4 watches for a `.broken` file in production. When the file exists, the health check returns `503`. A signal to the load balancer: stop sending traffic.

```bash
touch .broken          # Health check returns 503
# Deploy new code...
rm .broken             # Health check returns 200
```

---

## 7. Graceful Shutdown

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

## 8. Log Rotation

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

## 9. Nginx Reverse Proxy

In production, Tina4 runs behind Nginx. Nginx handles:

- SSL/TLS termination (HTTPS)
- Static file serving (faster than Node.js)
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

    # Static files (served by Nginx, faster than Node.js)
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
        proxy_pass http://127.0.0.1:7148;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }

    # Application
    location / {
        proxy_pass http://127.0.0.1:7148;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 10. SSL/TLS with Let's Encrypt

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
      - TINA4_JWT_SECRET=${TINA4_JWT_SECRET}

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

## 11. Process Management with systemd

Create `/etc/systemd/system/tina4-app.service`:

```ini
[Unit]
Description=Tina4 Node.js Application
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/my-app
ExecStart=/usr/bin/node /var/www/my-app/dist/app.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
EnvironmentFile=/var/www/my-app/.env.production

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable tina4-app
sudo systemctl start tina4-app
sudo systemctl status tina4-app
```

---

## 12. Queue Workers in Production

```ini
[Unit]
Description=Tina4 Queue Worker
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/my-app
ExecStart=/usr/local/bin/tina4 queue:work
Restart=always
RestartSec=5
EnvironmentFile=/var/www/my-app/.env.production

[Install]
WantedBy=multi-user.target
```

---

## 13. Zero-Downtime Deployment

```bash
#!/bin/bash
set -e

cd /var/www/my-app

# Signal load balancer to stop sending traffic
touch .broken
sleep 5

# Pull latest code
git pull origin main

# Install dependencies and build
npm ci --only=production
tina4 build

# Run migrations
tina4 migrate

# Restart the service
sudo systemctl restart tina4-app

# Wait for health check
sleep 2
curl -f http://localhost:7148/health

# Re-enable traffic
rm .broken

echo "Deployment complete"
```

---

## 14. Scaling

A single server handles many applications. When traffic outgrows one server, you scale.

### Vertical Scaling

Use cluster mode with more workers:

```bash
TINA4_CLUSTER=true
TINA4_CLUSTER_WORKERS=8
```

### Load Balancing with Nginx

When you run multiple Tina4 instances, Nginx distributes traffic across them:

```nginx
upstream tina4_backend {
    server 127.0.0.1:7148;
    server 127.0.0.1:7149;
    server 127.0.0.1:7150;
    server 127.0.0.1:7151;
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
TINA4_PORT=7148 node dist/app.js &
TINA4_PORT=7149 node dist/app.js &
TINA4_PORT=7150 node dist/app.js &
TINA4_PORT=7151 node dist/app.js &
```

Nginx distributes requests in round-robin order by default. If a backend goes down, Nginx routes traffic to the remaining instances.

### Docker Scaling

With Docker Compose, scale horizontally with a single command:

```bash
docker compose up -d --scale app=4
```

### Horizontal Scaling

Run multiple instances behind a load balancer. Use Redis for shared sessions, cache, and queues:

```bash
TINA4_SESSION_HANDLER=redis
TINA4_CACHE_BACKEND=redis
TINA4_QUEUE_BACKEND=rabbitmq
# Or use MongoDB for queues:
# TINA4_QUEUE_BACKEND=mongodb
# TINA4_MONGO_URI=mongodb://user:pass@mongo.internal:27017/tina4
```

### Scaling Considerations

Scaling introduces shared-state problems. When four instances serve requests, each must agree on the state of the world.

**Sessions:** Store sessions in Redis, not in-memory. Otherwise, a user who logs in on instance 1 appears logged out on instance 2.

**Database:** SQLite handles one writer at a time. Under high load with multiple instances, switch to PostgreSQL or MySQL. If you must use SQLite, enable WAL mode.

**File uploads:** Store uploaded files in shared storage (S3, a mounted volume) -- not the local filesystem of a single container.

**Cache:** Use Redis as the cache backend so all instances share the same cache.

---

## 15. Monitoring

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

The health endpoint from section 6 serves double duty: container orchestrators use it for restart decisions, and uptime monitors use it for alerting.

### Application Performance Monitoring (APM)

Uptime monitoring tells you the app is running. APM tells you how well it performs. APM agents track:

- Request latency (average, p95, p99)
- Database query performance (slow queries, connection pool usage)
- Error rates (which endpoints fail, how often)
- Memory and CPU usage over time

Since Tina4 Node.js runs on standard Node.js, any Node.js APM agent works:

- **Datadog APM**: `npm install dd-trace` and `require('dd-trace').init()` at the top of your app
- **New Relic**: `npm install newrelic` and `require('newrelic')` at the top of your app
- **Elastic APM**: `npm install elastic-apm-node` and configure in your app startup

A basic monitoring stack for a small team: Uptime Robot for availability alerts (free tier covers it), JSON logs shipped to Grafana Loki for debugging, and `docker stats` for resource usage. Add APM when your application serves enough traffic to warrant the cost.

---

## 16. Exercise: Docker Deploy

Deploy a Tina4 Node.js application using Docker.

### Requirements

1. Create a `Dockerfile` that:
   - Uses `node:20-alpine` as the base image
   - Installs production dependencies with `npm ci`
   - Copies the built application code
   - Exposes port 7148
   - Includes a health check
   - Runs the app with `node dist/app.js`

2. Create a `docker-compose.yml` that:
   - Builds and runs the app
   - Starts a Redis container for caching
   - Mounts volumes for data persistence
   - Sets environment variables for production

3. Create a `/health` endpoint that checks database connectivity

4. Build, run, and verify:

```bash
# Build
tina4 build
docker compose build

# Start
docker compose up -d

# Test health
curl http://localhost:7148/health

# Test the app
curl http://localhost:7148/api/products

# View logs
docker compose logs -f app

# Stop
docker compose down
```

### Solution

The Dockerfile and docker-compose.yml are shown in section 4. The health check route is shown in section 6. Combine them in your project, then:

```bash
tina4 build
docker compose up -d --build
```

```
[+] Building 12.3s
[+] Running 2/2
  Container redis    Started
  Container my-app   Started
```

```bash
curl http://localhost:7148/health
```

```json
{
  "status": "ok",
  "version": "1.0.0",
  "database": "connected",
  "timestamp": "2026-03-22T14:30:00.000Z"
}
```

The app runs in production mode with Redis caching, persistent data volumes, automatic restarts, and health monitoring.

---

## 17. Gotchas

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

### 4. Static Files Slow

**Problem:** CSS, JS, and images load slowly in production.

**Cause:** Node.js serves static files. Every static file request goes through the Node.js process.

**Fix:** Serve static files from Nginx (see the Nginx config in section 9). Nginx serves static files from memory-mapped files, which is orders of magnitude faster than Node.js.

### 5. Memory Usage Grows Over Time

**Problem:** The container's memory usage climbs until it crashes with OOM (out of memory).

**Cause:** Memory leaks in the application -- unclosed database connections, growing caches without TTL, accumulating request data in global variables.

**Fix:** Set TTLs on all cache entries. Close database connections properly. Avoid storing request data in module-level variables. Use `docker stats` to monitor memory usage. Set memory limits in Docker Compose: `deploy: {resources: {limits: {memory: 512M}}}`.

### 6. Container Starts Before Database Is Ready

**Problem:** The app crashes on startup because the database is not ready.

**Cause:** Docker Compose starts services in parallel. The app container starts before the database container finishes initializing.

**Fix:** For SQLite, this is not an issue (the file is created automatically). For PostgreSQL or MySQL, use a startup script that waits for the database, or use Docker Compose healthcheck on the database service with `depends_on: {db: {condition: service_healthy}}`.

### 7. SSL Certificate Not Renewing

**Problem:** Your HTTPS certificate expires and the site goes down.

**Cause:** The auto-renewal process (Certbot or Traefik) failed. Common reasons: DNS changes, firewall blocking port 80 for ACME challenges, or the renewal service crashed.

**Fix:** Monitor certificate expiry with an external service. Check renewal logs and verify the renewal timer is active:

```bash
sudo certbot renew --dry-run
sudo systemctl list-timers | grep certbot
```

### 8. Scaled Instances Have Different State

**Problem:** Users see inconsistent data across requests when running multiple app instances.

**Cause:** In-memory sessions and cache are not shared between instances. A user who logs in on instance 1 appears logged out when the load balancer routes the next request to instance 2.

**Fix:** Store sessions in Redis. Use Redis as the cache backend. Store uploaded files in shared storage (S3 or a mounted volume). All instances must read from and write to the same data stores.

### 9. Debug Mode in Production

**Fix:** Set `TINA4_DEBUG=false`.

### 10. .env in Version Control

**Fix:** Add to `.gitignore`.

### 11. Missing Migrations

**Fix:** Always run `tina4 migrate` during deployment.

### 12. Port Conflicts

**Fix:** Ensure only one process listens on port 7148.
