# Deployment Recipes (Ruby)

Tina4 Ruby apps deploy via Docker using a **multi-stage `ruby:3.3-alpine` build**. The dev server and
the container both listen on port **7147**. Never guess at Docker configuration — use the recipes
below.

## App Dockerfile (canonical)

This is the tina4-ruby project's own multi-stage Dockerfile — build gems in a builder stage, copy the
installed bundle and app into a lean runtime image:

```dockerfile
# === Build Stage ===
FROM ruby:3.3-alpine AS builder

# Build dependencies for native gem extensions
RUN apk add --no-cache build-base libffi-dev gcompat

WORKDIR /app

# Copy dependency definition first (layer caching)
COPY Gemfile Gemfile.lock* ./

# Install gems (skip dev/test)
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# === Runtime Stage ===
FROM ruby:3.3-alpine

# Runtime packages only
RUN apk add --no-cache libffi gcompat

WORKDIR /app

# Copy installed gems + app from the builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

EXPOSE 7147

# Swagger defaults (override via env in compose/k8s)
ENV SWAGGER_TITLE="Tina4 API"
ENV SWAGGER_VERSION="0.1.0"
ENV SWAGGER_DESCRIPTION="Auto-generated API documentation"

# Bind on all interfaces so the container is reachable
CMD ["bundle", "exec", "tina4ruby", "start", "-p", "7147", "-h", "0.0.0.0"]
```

### .dockerignore

```
.git
.bundle
vendor/bundle
log
logs
tmp
data/*.db
data/*.db-wal
data/*.db-shm
spec
.env.local
.DS_Store
```

### Build and Run

```bash
docker build -t my-app .
docker run -d -p 7147:7147 -v $(pwd)/data:/app/data my-app
```

## Database Drivers

SQLite works out of the box (`sqlite3` gem). For other databases, add the gem to your `Gemfile` and
the required Alpine system libraries to the builder stage:

| Database   | Gem                | Alpine build deps                       |
|------------|--------------------|-----------------------------------------|
| PostgreSQL | `pg`               | `postgresql-dev` (runtime: `libpq`)     |
| MySQL      | `mysql2`           | `mariadb-dev` (runtime: `mariadb-connector-c`) |
| SQL Server | `tiny_tds`         | `freetds-dev` (runtime: `freetds`)      |
| Firebird   | `fb` / ODBC        | `firebird-dev` + client libs            |

Example — adding PostgreSQL:
```dockerfile
FROM ruby:3.3-alpine AS builder
RUN apk add --no-cache build-base libffi-dev gcompat postgresql-dev
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN bundle config set --local without 'development test' && bundle install --jobs 4 --retry 3
COPY . .

FROM ruby:3.3-alpine
RUN apk add --no-cache libffi gcompat libpq          # runtime lib for pg
WORKDIR /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app
EXPOSE 7147
CMD ["bundle", "exec", "tina4ruby", "start", "-p", "7147", "-h", "0.0.0.0"]
```

Add `gem "pg"` to the `Gemfile` and set `TINA4_DATABASE_URL=postgresql://user:pass@host:5432/db`.

## Docker Compose

```yaml
services:
  app:
    build: .
    ports:
      - "7147:7147"
    environment:
      - TINA4_DEBUG=false
      - TINA4_OVERRIDE_CLIENT=true          # bypass the CLI managed-mode guard in a container
      - TINA4_SECRET=${TINA4_SECRET}
      - TINA4_DATABASE_URL=sqlite:/app/data/app.db
    volumes:
      - app-data:/app/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:7147/health"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  app-data:
```

## Environment Variables

Pass secrets at runtime, never bake them into the image:

```bash
docker run -d \
  -p 7147:7147 \
  -e TINA4_SECRET=your-secret \
  -e TINA4_DATABASE_URL=sqlite:/app/data/app.db \
  -e TINA4_DEBUG=false \
  -e TINA4_OVERRIDE_CLIENT=true \
  -v $(pwd)/data:/app/data \
  my-app
```

### Key Environment Variables for Docker

| Variable | Purpose |
|----------|---------|
| `TINA4_OVERRIDE_CLIENT` | Set `true` to bypass the CLI managed-mode guard (required in Docker/CI) |
| `TINA4_DEBUG` | `false` in production — disables the debug overlay and dev secret generation |
| `TINA4_SECRET` | JWT signing secret — **must** be set in production (blank = insecure) |
| `TINA4_DATABASE_URL` | Database connection string |
| `TINA4_PORT` / `PORT` | Listen port (default 7147) |

## Production Checklist

1. Use the multi-stage `ruby:3.3-alpine` Dockerfile above; run with `bundle exec tina4ruby start`.
2. Mount a volume for `/app/data` (SQLite database, sessions, queue).
3. Set `TINA4_DEBUG=false` and `TINA4_OVERRIDE_CLIENT=true`.
4. Pass `TINA4_SECRET` via the environment (not committed in the image). Generate with
   `openssl rand -hex 32`.
5. Health check hits `/health` (Kubernetes/compose probe).
6. Configure a Docker restart policy (`unless-stopped` or `always`).
7. Set up log rotation via the Docker logging driver.
8. Put a reverse proxy (nginx/Traefik) in front for SSL termination.
