# Chapter 20: Deployment

## 1. From Development to Production

The app works on `localhost:7146`. Now it needs to run 24/7 on a real server. Handle 10,000 concurrent users. Survive server restarts. Not leak memory. The gap between "works on my machine" and "works in production" is where most projects stumble.

This chapter covers everything for deploying a Tina4 PHP application: environment configuration, Docker packaging, web server setup, SSL, scaling, monitoring, and graceful shutdown.

---

## 2. Production .env Configuration

Configure your `.env` for production. Development defaults optimize for debugging. Production defaults optimize for performance and security.

Create a production `.env`:

```env
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

Never commit production secrets to version control. The `.env` file is gitignored by default. For deployment, use environment variables from your hosting platform, CI/CD secrets, or a secrets manager.

```bash
# Docker: pass env vars at runtime
docker run -e JWT_SECRET=your-secret -e DATABASE_URL=sqlite:///data/app.db my-app

# Fly.io: set secrets
fly secrets set JWT_SECRET=your-secret

# Railway: use the dashboard or CLI
railway variables set JWT_SECRET=your-secret
```

---

## 3. FrankenPHP Auto-Detection

Tina4 PHP auto-detects FrankenPHP at startup. FrankenPHP is a modern PHP application server built on Caddy:

- Worker mode (keeps PHP in memory between requests)
- Built-in HTTPS with automatic certificate management
- HTTP/2 and HTTP/3 support
- Dramatically better performance than PHP-FPM for long-running applications

### How Auto-Detection Works

When you run `tina4 serve --production`, the CLI checks for FrankenPHP:

1. If `frankenphp` is in your PATH, it uses FrankenPHP in worker mode
2. If not, it falls back to PHP's built-in server with production optimizations

```bash
# With FrankenPHP installed
tina4 serve --production
```

```
  Tina4 PHP v3.0.0
  Server: FrankenPHP (worker mode)
  Workers: 4
  Running at https://0.0.0.0:7146
  TLS: automatic (Let's Encrypt)
```

```bash
# Without FrankenPHP
tina4 serve --production
```

```
  Tina4 PHP v3.0.0
  Server: PHP built-in
  Running at http://0.0.0.0:7146
  Warning: For production, consider FrankenPHP or PHP-FPM + nginx
```

### Installing FrankenPHP

```bash
# macOS
brew install dunglas/tap/frankenphp

# Linux
curl -fsSL https://frankenphp.dev/install.sh | bash

# Docker (no installation needed)
docker pull dunglas/frankenphp
```

---

## 4. Docker Deployment

Docker is the most reliable deployment path. It packages your code, dependencies, and runtime into a single container. Runs identically everywhere.

### Dockerfile

Create `Dockerfile` at the project root:

```dockerfile
FROM dunglas/frankenphp:latest-php8.3-alpine

# Install PHP extensions
RUN install-php-extensions \
    pdo_sqlite \
    mbstring \
    openssl \
    fileinfo

# Set working directory
WORKDIR /app

# Copy Composer files first (for better caching)
COPY composer.json composer.lock ./

# Install dependencies
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer install --no-dev --optimize-autoloader --no-interaction

# Copy application code
COPY . .

# Create required directories
RUN mkdir -p data logs secrets \
    && chown -R www-data:www-data data logs secrets

# Expose port
EXPOSE 7146

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:7146/health || exit 1

# Start the server
CMD ["tina4", "serve", "--production"]
```

### docker-compose.yml

Create `docker-compose.yml`:

```yaml
version: "3.8"

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
      - CORS_ORIGINS=https://yourdomain.com
    volumes:
      - app-data:/app/data
      - app-logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7146/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

volumes:
  app-data:
  app-logs:
```

### Build and Run

```bash
# Build the image
docker build -t my-tina4-app .

# Run it
docker run -d \
  --name my-app \
  -p 7146:7146 \
  -e JWT_SECRET=your-production-secret \
  -v app-data:/app/data \
  my-tina4-app

# Or use docker-compose
docker compose up -d
```

### Verify

```bash
curl http://localhost:7146/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 5,
  "version": "3.0.0",
  "framework": "tina4-php"
}
```

### .dockerignore

Create `.dockerignore` to keep the image small:

```
.git
.env
data/
logs/
secrets/
node_modules/
vendor/
tests/
*.md
.DS_Store
```

---

## 5. PHP-FPM + nginx Configuration

If you prefer a traditional setup without Docker, use PHP-FPM with nginx.

### PHP-FPM Pool Configuration

Create `/etc/php/8.3/fpm/pool.d/tina4.conf`:

```ini
[tina4]
user = www-data
group = www-data
listen = /run/php/tina4.sock
listen.owner = www-data
listen.group = www-data

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 1000

env[DATABASE_URL] = sqlite:///var/www/tina4-app/data/app.db
env[JWT_SECRET] = your-production-secret
env[TINA4_DEBUG] = false
env[TINA4_LOG_LEVEL] = WARNING
```

### nginx Configuration

Create `/etc/nginx/sites-available/tina4`:

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www/tina4-app/src/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Static files
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # All other requests go to Tina4
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP processing
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/tina4.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # Block access to sensitive files
    location ~ /\.(env|git|htaccess) {
        deny all;
    }

    location ~ ^/(data|logs|secrets|vendor)/ {
        deny all;
    }
}
```

Enable the site and restart:

```bash
sudo ln -s /etc/nginx/sites-available/tina4 /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm
```

---

## 6. Health Check Endpoint

Tina4 includes a built-in health check endpoint at `/health`:

```bash
curl http://localhost:7146/health
```

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 3600,
  "version": "3.0.0",
  "framework": "tina4-php"
}
```

If the database is disconnected or the application is in a bad state, the health check returns a non-200 status:

```json
{
  "status": "error",
  "database": "disconnected",
  "error": "Could not connect to database",
  "uptime_seconds": 3600,
  "version": "3.0.0",
  "framework": "tina4-php"
}
```

Use this endpoint for:

- **Docker HEALTHCHECK** (shown in the Dockerfile above)
- **Load balancer health checks** (AWS ALB, nginx upstream, HAProxy)
- **Monitoring tools** (Uptime Robot, Pingdom, custom scripts)
- **Kubernetes liveness and readiness probes**

### Custom Health Checks

You can extend the health check to include your own checks:

```php
<?php
use Tina4Router;

Router::get("/health/detailed", function ($request, $response) {
    $checks = [
        "database" => false,
        "cache" => false,
        "disk_space" => false
    ];

    // Check database
    try {
        $product = new Product();
        $product->select("count(*) as cnt");
        $checks["database"] = true;
    } catch (\Exception $e) {
        // Database check failed
    }

    // Check disk space
    $freeBytes = disk_free_space("/");
    $checks["disk_space"] = $freeBytes > 100 * 1024 * 1024; // 100MB minimum

    $allOk = !in_array(false, $checks);

    return $response->json([
        "status" => $allOk ? "ok" : "degraded",
        "checks" => $checks,
        "free_disk_mb" => round($freeBytes / 1024 / 1024)
    ], $allOk ? 200 : 503);
});
```

---

## 7. Graceful Shutdown

When a container or process receives SIGTERM, Tina4 handles it gracefully:

1. Stops accepting new connections
2. Finishes processing in-flight requests (up to a configurable timeout)
3. Closes database connections cleanly
4. Flushes logs
5. Exits with status code 0

No data corruption. No dropped requests during deployments.

### Shutdown Timeout

Set the maximum time to wait for in-flight requests in `.env`:

```env
TINA4_SHUTDOWN_TIMEOUT=30
```

If requests are still processing after 30 seconds, the server force-kills them and exits. The default is 30 seconds, which is enough for most applications.

### Docker Stop Behavior

Docker sends SIGTERM, waits 10 seconds (by default), then sends SIGKILL. Match the Docker timeout to your shutdown timeout:

```yaml
services:
  app:
    stop_grace_period: 35s   # Slightly more than TINA4_SHUTDOWN_TIMEOUT
```

---

## 8. Log Rotation

In production, log files grow without limit unless rotated. Tina4 writes to `logs/app.log`.

### Using logrotate (Linux)

Create `/etc/logrotate.d/tina4`:

```
/var/www/tina4-app/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 640 www-data www-data
    postrotate
        # Tina4 re-opens log files automatically
    endscript
}
```

This rotates logs daily, keeps 14 days of compressed history, and creates new log files with the correct permissions.

### Docker Logging

In Docker, application logs go to stdout/stderr by default. Configure Docker's logging driver to manage rotation:

```yaml
services:
  app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
```

This keeps a maximum of 50MB of logs (5 files of 10MB each).

---

## 9. Environment-Specific Configuration

Use different `.env` files for different environments:

```
.env                    # Development (gitignored)
.env.example            # Template (committed to git)
.env.staging            # Staging config (gitignored)
.env.production         # Production config (gitignored)
```

### Loading a Specific .env File

Set the `TINA4_ENV_FILE` environment variable before starting:

```bash
# Staging
TINA4_ENV_FILE=.env.staging tina4 serve

# Production
TINA4_ENV_FILE=.env.production tina4 serve --production
```

In Docker, pass environment variables directly:

```bash
docker run -e TINA4_DEBUG=false -e JWT_SECRET=xxx my-app
```

Environment variables set via `docker run -e` or `docker-compose environment:` take precedence over `.env` file values. This lets you use a generic `.env` file in the image and override specific values at runtime.

---

## 10. SSL/TLS with Let's Encrypt

### With FrankenPHP (Automatic)

FrankenPHP handles SSL automatically. Just set your domain:

```env
TINA4_HOST=yourdomain.com
```

FrankenPHP uses Let's Encrypt to provision and renew certificates automatically. No manual configuration needed.

### With nginx (Manual)

Install Certbot:

```bash
sudo apt install certbot python3-certbot-nginx
```

Obtain a certificate:

```bash
sudo certbot --nginx -d yourdomain.com
```

Certbot modifies your nginx configuration to include SSL settings and sets up automatic renewal. Verify auto-renewal:

```bash
sudo certbot renew --dry-run
```

### With Docker (Using a Reverse Proxy)

Use Traefik or Caddy as a reverse proxy in front of your Tina4 container:

```yaml
version: "3.8"

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

---

## 11. Scaling

### Multiple Workers

FrankenPHP runs multiple worker threads by default. Configure the count in `.env`:

```env
TINA4_WORKERS=4
```

A good starting point is the number of CPU cores on your server. For I/O-heavy applications (database queries, API calls), you can go higher -- 2x to 4x the core count.

### Load Balancing with nginx

If you run multiple Tina4 instances, use nginx as a load balancer:

```nginx
upstream tina4_backend {
    server 127.0.0.1:7146;
    server 127.0.0.1:7146;
    server 127.0.0.1:7147;
    server 127.0.0.1:7148;
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
TINA4_PORT=7146 tina4 serve --production &
TINA4_PORT=7146 tina4 serve --production &
TINA4_PORT=7147 tina4 serve --production &
TINA4_PORT=7148 tina4 serve --production &
```

### Docker Scaling

With Docker Compose, scale horizontally:

```bash
docker compose up -d --scale app=4
```

Use a load balancer (Traefik, nginx, or a cloud load balancer) in front of the containers.

---

## 12. Monitoring

### Log Aggregation

In production, send logs to a centralized service:

```env
TINA4_LOG_FORMAT=json
```

JSON-formatted logs can be ingested by services like:

- Elastic Stack (ELK)
- Grafana Loki
- Datadog
- AWS CloudWatch

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

### Uptime Monitoring

Point an external monitoring service at your health endpoint:

```
https://yourdomain.com/health
```

Services like Uptime Robot, Pingdom, or Better Uptime will ping this endpoint every 30-60 seconds and alert you if it stops responding or returns a non-200 status.

### Application Performance Monitoring (APM)

For deeper insights, add APM instrumentation. Since Tina4 is standard PHP, any PHP APM agent works:

- New Relic APM
- Datadog APM
- Elastic APM

These agents track request latency, database query performance, error rates, and memory usage automatically.

---

## 13. Exercise: Deploy a Tina4 PHP App with Docker

Deploy the task management application you have been building throughout this book.

### Requirements

1. Create a `Dockerfile` that:
   - Uses FrankenPHP as the base image
   - Installs Composer and dependencies
   - Copies the application code
   - Exposes port 7146
   - Includes a health check
   - Starts the server in production mode

2. Create a `docker-compose.yml` that:
   - Builds and runs the application
   - Maps port 7146
   - Uses environment variables for secrets
   - Persists the database and logs via volumes
   - Includes restart policy

3. Create a production `.env.production` with:
   - Debug mode off
   - Warning-level logging
   - Template caching enabled
   - Appropriate CORS settings

4. Build and run the container.

5. Verify the health check works.

6. Verify you can create and list products through the containerized API.

### Test with:

```bash
# Build
docker compose build

# Start
docker compose up -d

# Health check
curl http://localhost:7146/health

# Create a product
curl -X POST http://localhost:7146/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Docker Widget", "price": 19.99}'

# List products
curl http://localhost:7146/api/products

# View logs
docker compose logs app

# Stop
docker compose down
```

---

## 14. Solution

### Dockerfile

```dockerfile
FROM dunglas/frankenphp:latest-php8.3-alpine

RUN install-php-extensions \
    pdo_sqlite \
    mbstring \
    openssl \
    fileinfo

WORKDIR /app

COPY composer.json composer.lock ./
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer install --no-dev --optimize-autoloader --no-interaction

COPY . .

RUN mkdir -p data logs secrets \
    && chown -R www-data:www-data data logs secrets

EXPOSE 7146

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:7146/health || exit 1

CMD ["tina4", "serve", "--production"]
```

### docker-compose.yml

```yaml
version: "3.8"

services:
  app:
    build: .
    ports:
      - "7146:7146"
    environment:
      - TINA4_DEBUG=false
      - TINA4_LOG_LEVEL=WARNING
      - TINA4_CACHE_TEMPLATES=true
      - JWT_SECRET=change-this-to-a-real-secret
      - DATABASE_URL=sqlite:///data/app.db
      - CORS_ORIGINS=http://localhost:7146
    volumes:
      - app-data:/app/data
      - app-logs:/app/logs
    restart: unless-stopped
    stop_grace_period: 35s

volumes:
  app-data:
  app-logs:
```

### .env.production

```env
TINA4_DEBUG=false
TINA4_LOG_LEVEL=WARNING
TINA4_CACHE_TEMPLATES=true
TINA4_MINIFY_HTML=true
TINA4_RATE_LIMIT=120
CORS_ORIGINS=https://yourdomain.com
```

**Expected output for health check:**

```json
{
  "status": "ok",
  "database": "connected",
  "uptime_seconds": 8,
  "version": "3.0.0",
  "framework": "tina4-php"
}
```

**Expected output for creating a product:**

```json
{
  "id": 1,
  "name": "Docker Widget",
  "price": 19.99,
  "in_stock": true,
  "created_at": "2026-03-22 14:30:00",
  "updated_at": "2026-03-22 14:30:00"
}
```

---

## 15. Gotchas

### 1. SQLite Concurrency in Production

**Problem:** Under high load, SQLite throws "database is locked" errors.

**Cause:** SQLite uses file-level locking. Multiple concurrent writes block each other.

**Fix:** For low-to-medium traffic (under 100 concurrent users), SQLite works fine. For higher traffic, switch to PostgreSQL or MySQL:

```env
DATABASE_URL=postgres://user:pass@localhost:5432/myapp
```

If you must use SQLite under load, enable WAL mode by adding this to your application startup:

```php
$db = Tina4\Database::getConnection();
$db->exec("PRAGMA journal_mode=WAL");
```

### 2. Data Volume Not Persisted

**Problem:** You restart the Docker container and the database is empty.

**Cause:** The `data/` directory is inside the container. When the container is recreated, the data is lost.

**Fix:** Use a Docker volume to persist the data directory, as shown in the docker-compose.yml above:

```yaml
volumes:
  - app-data:/app/data
```

### 3. .env File Not Loaded in Docker

**Problem:** Environment variables from `.env` are not available in the container.

**Cause:** Docker does not automatically load `.env` files inside the container. The `.env` file is for the host machine (used by `docker compose`).

**Fix:** Pass environment variables via the `environment:` section in `docker-compose.yml`, or use `env_file:`:

```yaml
services:
  app:
    env_file:
      - .env.production
```

### 4. Permission Denied on data/ Directory

**Problem:** The application cannot write to `data/` or `logs/` inside the container.

**Cause:** The directories were created by root during the Docker build, but the application runs as `www-data`.

**Fix:** Add `chown` to your Dockerfile:

```dockerfile
RUN mkdir -p data logs secrets \
    && chown -R www-data:www-data data logs secrets
```

### 5. Health Check Fails During Startup

**Problem:** The container restarts in a loop because the health check fails before the application is ready.

**Cause:** The health check starts immediately, but the application needs a few seconds to initialize.

**Fix:** Use `start_period` in the health check to give the application time to start:

```dockerfile
HEALTHCHECK --start-period=10s --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:7146/health || exit 1
```

The `start-period` tells Docker to ignore health check failures during the first 10 seconds.

### 6. CORS Errors in Production

**Problem:** Your frontend gets "No 'Access-Control-Allow-Origin' header" errors.

**Cause:** `CORS_ORIGINS` is set to `*` in development but to a specific domain in production. If your frontend is served from a different domain or port, CORS blocks the requests.

**Fix:** Set `CORS_ORIGINS` to include all domains that need access:

```env
CORS_ORIGINS=https://yourdomain.com,https://admin.yourdomain.com
```

### 7. SSL Certificate Not Renewing

**Problem:** Your HTTPS certificate expires and the site goes down.

**Cause:** The auto-renewal process (Certbot or FrankenPHP) failed silently. Common reasons: DNS changes, firewall blocking port 80 (needed for ACME challenge), or the renewal service crashed.

**Fix:** Set up monitoring for certificate expiry. Use a tool like `ssl-cert-check` or an online service that alerts you before the certificate expires. Check renewal logs:

```bash
# Certbot
sudo certbot renew --dry-run

# Check crontab for renewal
sudo systemctl list-timers | grep certbot
```

For FrankenPHP, ensure port 80 and 443 are accessible from the internet for ACME challenges.
