# Chapter 20: Deployment

## 1. From Development to Production

The app works on `localhost:7147`. Now it needs to run 24/7 on a real server. Handle 10,000 concurrent users. Survive restarts. Hold steady on memory. The gap between "works on my machine" and "works in production" is where most projects stumble.

This chapter covers everything for a production deployment. Environment configuration. Docker packaging. Web server setup. SSL. Scaling. Monitoring. Graceful shutdown.

When you run `tina4 init`, the framework generates a production-ready `Dockerfile` and `.dockerignore` in your project root. The Dockerfile uses a multi-stage build: the first stage installs gem dependencies and the second stage copies only the runtime artifacts into a slim image. You do not need to write a Dockerfile from scratch -- the generated one is a solid starting point that you can customise as needed.

---

## 2. Production .env Configuration

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

---

## 3. Docker Deployment

### Dockerfile

```dockerfile
FROM ruby:3.3-slim

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p data logs secrets

# Run migrations
RUN tina4 migrate 2>/dev/null || true

# Expose port
EXPOSE 7147

# Start with Puma for production
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### docker-compose.yml

```yaml
version: "3.8"

services:
  app:
    build: .
    ports:
      - "7147:7147"
    volumes:
      - app-data:/app/data
      - app-logs:/app/logs
      - app-secrets:/app/secrets
    env_file:
      - .env.production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7147/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  worker:
    build: .
    command: tina4 queue:work
    volumes:
      - app-data:/app/data
    env_file:
      - .env.production
    restart: unless-stopped
    depends_on:
      - app

volumes:
  app-data:
  app-logs:
  app-secrets:
```

### Build and Run

```bash
docker compose build
docker compose up -d
docker compose logs -f app
```

---

## 4. Puma Configuration

Create `config/puma.rb`:

```ruby
# Puma configuration for production

# Port
port ENV.fetch("TINA4_PORT", 7147)

# Workers (processes) -- set to number of CPU cores
workers ENV.fetch("WEB_CONCURRENCY", 2)

# Threads per worker
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
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

---

## 5. Nginx Reverse Proxy

Create `config/nginx.conf`:

```nginx
upstream tina4_app {
    server 127.0.0.1:7147;
}

server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Static files
    location /css/ {
        root /app/src/public;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /js/ {
        root /app/src/public;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /images/ {
        root /app/src/public;
        expires 30d;
    }

    # WebSocket
    location /ws/ {
        proxy_pass http://tina4_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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

## 6. SSL with Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

Certbot automatically configures Nginx with SSL and sets up auto-renewal.

---

## 7. Process Management with systemd

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

## 8. Graceful Shutdown

Tina4 handles graceful shutdown automatically. When it receives a `SIGTERM`:

1. Stops accepting new connections
2. Waits for in-flight requests to complete (up to 30 seconds)
3. Closes database connections
4. Shuts down cleanly

For the health check pattern:

```bash
# Create .broken file to signal the load balancer
touch .broken

# Wait for health checks to fail and traffic to drain
sleep 30

# Restart the application
sudo systemctl restart tina4-app

# Remove the .broken file
rm .broken
```

---

## 9. Monitoring

### Health Check

```bash
curl http://localhost:7147/health
```

### Log Monitoring

```bash
tail -f logs/app.log
tail -f logs/puma.stdout.log
```

### Prometheus Metrics

Enable metrics in `.env`:

```env
TINA4_METRICS=true
```

Metrics are available at `/metrics` in Prometheus format:

```bash
curl http://localhost:7147/metrics
```

---

## 10. Scaling

### Horizontal Scaling with Multiple Workers

In `config/puma.rb`:

```ruby
workers ENV.fetch("WEB_CONCURRENCY", 4)
threads 5, 5
```

### Scaling with Docker Compose

```bash
docker compose up -d --scale app=4
```

### Scaling Queue Workers

```bash
docker compose up -d --scale worker=3
```

---

## 11. Exercise: Deploy to Docker

Deploy your TaskFlow application to Docker with:

1. A production `.env`
2. A Dockerfile
3. A docker-compose.yml with app and worker services
4. Health check configuration

### Test with:

```bash
docker compose build
docker compose up -d
curl http://localhost:7147/health
curl http://localhost:7147/api/products
docker compose logs -f
docker compose down
```

---

## 12. Solution

Create `.env.production`, `Dockerfile`, and `docker-compose.yml` as shown in sections 2, 3, and 4 above. Then:

```bash
docker compose build
docker compose up -d
```

Verify:

```bash
curl http://localhost:7147/health
```

```json
{"status":"ok","database":"connected","version":"3.0.0","framework":"tina4-ruby"}
```

---

## 13. Gotchas

### 1. Database File Not Persisted

**Problem:** Data disappears after Docker container restarts.

**Fix:** Mount the `data/` directory as a Docker volume.

### 2. .env Not Loaded in Docker

**Problem:** Environment variables are not set inside the container.

**Fix:** Use `env_file: .env.production` in docker-compose.yml, not `COPY .env .`.

### 3. WebSocket Not Working Behind Nginx

**Problem:** WebSocket connections fail behind Nginx.

**Fix:** Add `proxy_set_header Upgrade $http_upgrade` and `proxy_set_header Connection "upgrade"` to the Nginx config.

### 4. Puma Workers Not Reconnecting to Database

**Problem:** Database errors after Puma forks worker processes.

**Fix:** Use `on_worker_boot` in Puma config to reconnect: `Tina4::Database.reconnect`.

### 5. SSL Certificate Renewal Fails

**Problem:** Let's Encrypt certificate expires because auto-renewal failed.

**Fix:** Run `sudo certbot renew --dry-run` to test renewal. Set up a cron job: `0 3 * * * certbot renew`.

### 6. Memory Grows Over Time

**Problem:** The application's memory usage increases steadily.

**Fix:** Set Puma's `worker_timeout` and restart workers periodically with `workers_max_requests 1000`.

### 7. Queue Worker Stops Processing

**Problem:** The queue worker stops processing jobs silently.

**Fix:** Use `Restart=always` in systemd. Monitor the worker with health checks. Set up alerting on dead letter queue growth.
