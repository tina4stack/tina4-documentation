# Chapter 20: Deployment

## 1. From Development to Production

You have built the app. It runs on `localhost:7148`. Now it needs to run 24/7. Handle thousands of concurrent users. Survive server restarts. Not leak memory.

This chapter covers everything for production deployment.

When you run `tina4 init`, the framework generates a production-ready `Dockerfile` and `.dockerignore` in your project root. The Dockerfile uses a multi-stage build: the first stage installs npm dependencies and the second stage copies only the runtime artifacts into a slim image. You do not need to write a Dockerfile from scratch -- the generated one is a solid starting point that you can customise as needed.

---

## 2. Production .env Configuration

```env
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

### Key Differences

| Setting | Dev | Production |
|---------|-----|------------|
| `TINA4_DEBUG` | `true` | `false` |
| `TINA4_LOG_LEVEL` | `ALL` | `WARNING` |
| `CORS_ORIGINS` | `*` | Your domain |

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

Create `Dockerfile`:

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY dist/ ./dist/
COPY src/templates/ ./src/templates/
COPY src/public/ ./src/public/
COPY src/migrations/ ./src/migrations/

ENV TINA4_DEBUG=false
ENV TINA4_PORT=7148

EXPOSE 7148

CMD ["node", "dist/app.js"]
```

Create `docker-compose.yml`:

```yaml
version: "3.8"

services:
  app:
    build: .
    ports:
      - "7148:7148"
    volumes:
      - app-data:/app/data
      - app-logs:/app/logs
    env_file:
      - .env.production
    restart: unless-stopped

volumes:
  app-data:
  app-logs:
```

Build and run:

```bash
tina4 build
docker compose up -d
```

---

## 5. Node.js Cluster for Production

For multi-core utilization, Tina4 supports Node.js cluster mode:

```env
TINA4_CLUSTER=true
TINA4_CLUSTER_WORKERS=4
```

Or set workers to `auto` to match CPU cores:

```env
TINA4_CLUSTER_WORKERS=auto
```

This spawns multiple worker processes. Each handles requests independently. A worker crashes. The cluster master respawns it. No downtime.

---

## 6. Nginx Reverse Proxy

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:7148;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ws/ {
        proxy_pass http://127.0.0.1:7148;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

---

## 7. SSL with Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

---

## 8. Process Management with systemd

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

## 9. Queue Workers in Production

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

## 10. Health Check and Monitoring

```bash
curl http://localhost:7148/health
```

### Broken File Check

Tina4 watches for a `.broken` file in production. When the file exists, the health check returns `503`. A signal to the load balancer: stop sending traffic.

```bash
touch .broken          # Health check returns 503
# Deploy new code...
rm .broken             # Health check returns 200
```

---

## 11. Zero-Downtime Deployment

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

## 12. Scaling

### Vertical Scaling

Use cluster mode with more workers:

```env
TINA4_CLUSTER=true
TINA4_CLUSTER_WORKERS=8
```

### Horizontal Scaling

Run multiple instances behind a load balancer. Use Redis for shared sessions, cache, and queues:

```env
TINA4_SESSION_HANDLER=redis
TINA4_CACHE_BACKEND=redis
TINA4_QUEUE_BACKEND=rabbitmq
# Or use MongoDB for queues:
# TINA4_QUEUE_BACKEND=mongodb
# TINA4_MONGO_URI=mongodb://user:pass@mongo.internal:27017/tina4
```

---

## 13. Exercise: Deploy TaskFlow to Docker

Dockerize the TaskFlow app from Chapter 21 with Nginx, SSL, and a queue worker.

---

## 14. Solution

```bash
tina4 build
docker compose -f docker-compose.prod.yml up -d
```

---

## 15. Gotchas

### 1. Debug Mode in Production -- Set `TINA4_DEBUG=false`.
### 2. .env in Version Control -- Add to `.gitignore`.
### 3. SQLite in Multi-Instance -- Use PostgreSQL for horizontal scaling.
### 4. WebSocket Behind Load Balancer -- Configure sticky sessions or use Redis pub/sub.
### 5. Memory Leaks -- Monitor with `process.memoryUsage()` and restart workers periodically.
### 6. Missing Migrations -- Always run `tina4 migrate` during deployment.
### 7. Port Conflicts -- Ensure only one process listens on port 7148.
